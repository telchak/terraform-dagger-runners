locals {
  # Sorted list of versions (lexicographic — works for Dagger's 0.x.y scheme).
  sorted_versions = sort(var.dagger_versions)

  # The overall latest version is the last element after sorting.
  latest_version = local.sorted_versions[length(local.sorted_versions) - 1]

  # Group versions by their minor component (e.g. "0.19").
  # For each minor group, the latest patch is the last after sorting.
  minor_groups = {
    for v in var.dagger_versions :
    join(".", slice(split(".", v), 0, 2)) => v...
  }
  minor_latest = {
    for minor, versions in local.minor_groups :
    minor => sort(versions)[length(versions) - 1]
  }

  # Compute the minor version for any version string.
  version_to_minor = {
    for v in var.dagger_versions :
    v => join(".", slice(split(".", v), 0, 2))
  }

  # DaemonSet: host path where the Dagger Helm chart exposes the engine socket.
  # Pattern: /run/dagger-<helm-release-name>-dagger-helm
  engine_host_socket_path = {
    for v in var.dagger_versions :
    v => "/run/dagger-dagger-engine-v${replace(v, ".", "-")}-dagger-helm"
  }

  # Engine connection string per version.
  # DaemonSet: Unix socket via hostPath mount (node-local).
  # StatefulSet: kube-pod:// protocol via Kubernetes API (cross-node).
  engine_runner_host = {
    for v in var.dagger_versions :
    v => (
      var.engine_mode == "daemonset"
      ? "unix:///run/dagger/engine.sock"
      : "kube-pod://dagger-engine-v${replace(v, ".", "-")}-dagger-helm-engine-0?namespace=${var.namespace}"
    )
  }

  # --- Exact version sets ---
  # Each version gets its own runner scale set: runs-on: dagger-v0.19.5
  exact_sets = {
    for v in var.dagger_versions : "dagger-v${replace(v, ".", "-")}" => {
      name               = "dagger-v${replace(v, ".", "-")}"
      label              = "dagger-v${v}"
      engine_image       = "registry.dagger.io/engine:v${v}"
      minor              = local.version_to_minor[v]
      engine_socket_path = local.engine_host_socket_path[v]
      engine_runner_host = local.engine_runner_host[v]
      is_alias           = false
    }
  }

  # --- Minor alias sets ---
  # For each minor group, create a runs-on: dagger-v0.19 alias pointing
  # to the latest patch in that group. Skipped when the minor version
  # string equals the exact version (e.g. user specified "0.19" directly).
  minor_alias_sets = {
    for minor, v in local.minor_latest :
    "dagger-v${replace(minor, ".", "-")}-alias" => {
      name               = "dagger-v${replace(minor, ".", "-")}-alias"
      label              = "dagger-v${minor}"
      engine_image       = "registry.dagger.io/engine:v${v}"
      minor              = minor
      engine_socket_path = local.engine_host_socket_path[v]
      engine_runner_host = local.engine_runner_host[v]
      is_alias           = true
    }
    if minor != v # skip when the version has no patch component
  }

  # --- Latest alias ---
  # runs-on: dagger-latest always points to the newest Dagger engine.
  latest_alias_set = {
    "dagger-latest" = {
      name               = "dagger-latest"
      label              = "dagger-latest"
      engine_image       = "registry.dagger.io/engine:v${local.latest_version}"
      minor              = local.version_to_minor[local.latest_version]
      engine_socket_path = local.engine_host_socket_path[local.latest_version]
      engine_runner_host = local.engine_runner_host[local.latest_version]
      is_alias           = true
    }
  }

  # Base runner sets: exact + minor aliases + latest alias (before size expansion).
  _base_runner_sets = merge(local.exact_sets, local.minor_alias_sets, local.latest_alias_set)

  # --- Size template expansion ---
  # When runner_size_templates is defined, create one runner scale set per
  # base label x size template. Labels get a size suffix:
  #   dagger-v0.19.5-large, dagger-v0.19-large, dagger-latest-large
  _sized_runner_sets = merge([
    for size_name, size_config in var.runner_size_templates : {
      for key, base in local._base_runner_sets :
      (size_name != "" ? "${key}-${size_name}" : key) => {
        name               = size_name != "" ? "${base.name}-${size_name}" : base.name
        label              = size_name != "" ? "${base.label}-${size_name}" : base.label
        engine_image       = base.engine_image
        minor              = base.minor
        engine_socket_path = base.engine_socket_path
        engine_runner_host = base.engine_runner_host
        is_alias           = base.is_alias
        runner_requests    = size_config.runner_requests
        runner_limits      = size_config.runner_limits
      }
    }
  ]...)

  # Without templates, use base sets with no resource constraints.
  _unsized_runner_sets = {
    for key, base in local._base_runner_sets :
    key => {
      name               = base.name
      label              = base.label
      engine_image       = base.engine_image
      minor              = base.minor
      engine_socket_path = base.engine_socket_path
      engine_runner_host = base.engine_runner_host
      is_alias           = base.is_alias
      runner_requests    = {}
      runner_limits      = {}
    }
  }

  # Final set used by CI platform modules.
  runner_sets = length(var.runner_size_templates) > 0 ? local._sized_runner_sets : local._unsized_runner_sets
}

/*****************************************
  Optional Dagger Cloud Secret
  Injected as DAGGER_CLOUD_TOKEN on runner
  pods for SDK telemetry and tracing.
 *****************************************/
resource "kubernetes_secret" "dagger_cloud_token" {
  count = var.dagger_cloud_token != "" ? 1 : 0

  metadata {
    name      = "dagger-cloud-token"
    namespace = var.namespace
  }
  data = {
    token = var.dagger_cloud_token
  }
}

/*****************************************
  Dagger Engine

  Deployed via the official Dagger Helm chart.
  One release per Dagger version.

  DaemonSet mode:
    One engine per node. Cache at hostPath
    /var/lib/dagger-<release> (ephemeral).
    Socket at hostPath /run/dagger-<release>.
    Runners connect via Unix socket mount.

  StatefulSet mode:
    One engine per version (replicas=1).
    Cache on a PVC (persistent, managed by the
    Helm chart via volumeClaimTemplates).
    Runners connect via kube-pod:// protocol.

  Dagger Cloud (complementary):
    When dagger_cloud_token is set, Magicache is
    enabled on the engine for distributed caching.
 *****************************************/
resource "helm_release" "dagger_engine" {
  for_each  = toset(var.dagger_versions)
  name      = "dagger-engine-v${replace(each.value, ".", "-")}"
  namespace = var.namespace
  chart     = "oci://registry.dagger.io/dagger-helm"
  version   = each.value

  values = [
    templatefile("${path.module}/manifests/dagger-engine-helm-values.yaml.tftpl", {
      engine_kind           = var.engine_mode == "daemonset" ? "DaemonSet" : "StatefulSet"
      engine_mode           = var.engine_mode
      engine_image          = "registry.dagger.io/engine:v${each.value}"
      cpu_request           = var.dagger_engine_requests.cpu
      memory_request        = var.dagger_engine_requests.memory
      persistent_cache_size = var.persistent_cache_size
      storage_class_name    = var.persistent_cache_storage_class_name
      dagger_cloud_token    = var.dagger_cloud_token
    }),
  ]
}

/*****************************************
  Vertical Pod Autoscaler (recommendation only)
  Observes actual resource usage of the Dagger
  engine and recommends optimal requests.
  Check recommendations:
    kubectl describe vpa dagger-engine-vpa -n <namespace>
 *****************************************/
resource "kubectl_manifest" "dagger_engine_vpa" {
  for_each = var.enable_vpa ? toset(var.dagger_versions) : toset([])

  yaml_body = templatefile("${path.module}/manifests/dagger-engine-vpa.yaml.tftpl", {
    vpa_name    = "dagger-engine-v${replace(each.value, ".", "-")}-vpa"
    namespace   = var.namespace
    target_kind = var.engine_mode == "daemonset" ? "DaemonSet" : "StatefulSet"
    target_name = "dagger-engine-v${replace(each.value, ".", "-")}-dagger-helm-engine"
    update_mode = var.vpa_update_mode
  })

  depends_on = [helm_release.dagger_engine]
}

/*****************************************
  RBAC for StatefulSet Mode
  Runner pods need pods/exec permission to
  connect to the Dagger engine via the
  kube-pod:// protocol.
 *****************************************/
resource "kubernetes_service_account" "dagger_runner" {
  count = var.engine_mode == "statefulset" ? 1 : 0

  metadata {
    name      = "dagger-runner"
    namespace = var.namespace
  }
}

resource "kubernetes_role" "dagger_engine_access" {
  count = var.engine_mode == "statefulset" ? 1 : 0

  metadata {
    name      = "dagger-engine-access"
    namespace = var.namespace
  }
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["create", "get"]
  }
}

resource "kubernetes_role_binding" "dagger_engine_access" {
  count = var.engine_mode == "statefulset" ? 1 : 0

  metadata {
    name      = "dagger-engine-access"
    namespace = var.namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.dagger_engine_access[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.dagger_runner[0].metadata[0].name
    namespace = var.namespace
  }
}
