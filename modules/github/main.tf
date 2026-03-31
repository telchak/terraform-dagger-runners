locals {
  # GitHub App secret: use an existing secret or create one.
  create_gh_secret = var.gh_app_existing_secret_name == ""
  gh_secret_name   = local.create_gh_secret ? kubernetes_secret.gh_app_pre_defined_secret[0].metadata[0].name : var.gh_app_existing_secret_name

  # Alias min runners: falls back to min_runners when not explicitly set.
  effective_alias_min_runners = var.alias_min_runners != null ? var.alias_min_runners : var.min_runners
}

/*****************************************
  Kubernetes Namespaces

  Both namespaces are labelled "privileged"
  because the Dagger engine requires
  privileged pods, hostPath volumes, and
  elevated capabilities (CAP_ALL).
  Without this, PodSecurity admission
  (enabled by default since K8s 1.25)
  blocks engine pod creation.
 *****************************************/
resource "kubernetes_namespace" "arc_systems" {
  metadata {
    name = var.arc_systems_namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "kubernetes_namespace" "arc_runners" {
  metadata {
    name = var.arc_runners_namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }

  depends_on = [helm_release.arc]
}

/*****************************************
  Dagger Engine (root module)
 *****************************************/
module "dagger-engine" {
  source = "../.."

  namespace = kubernetes_namespace.arc_runners.metadata[0].name

  dagger_versions                     = var.dagger_versions
  dagger_cloud_token                  = var.dagger_cloud_token
  engine_mode                         = var.engine_mode
  dagger_engine_requests              = var.dagger_engine_requests
  persistent_cache_size               = var.persistent_cache_size
  persistent_cache_storage_class_name = var.persistent_cache_storage_class_name
  runner_size_templates               = var.runner_size_templates
  enable_vpa                          = var.enable_vpa
  vpa_update_mode                     = var.vpa_update_mode
}

/*****************************************
  GitHub App Secret
 *****************************************/
resource "kubernetes_secret" "gh_app_pre_defined_secret" {
  count = local.create_gh_secret ? 1 : 0

  metadata {
    name      = var.gh_app_pre_defined_secret_name
    namespace = kubernetes_namespace.arc_runners.metadata[0].name
  }
  data = {
    github_app_id              = var.gh_app_id
    github_app_installation_id = var.gh_app_installation_id
    github_app_private_key     = var.gh_app_private_key
  }
}

/*****************************************
  ARC Controller (Operator)
 *****************************************/
resource "helm_release" "arc" {
  name      = "arc"
  namespace = kubernetes_namespace.arc_systems.metadata[0].name
  chart     = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller"
  version   = var.arc_controller_version
  wait      = true
  values = concat(
    [file("${path.module}/../../manifests/github/arc-controller-helm-values.yaml.tftpl")],
    var.arc_controller_values,
  )
}

/*****************************************
  ARC Runner Scale Sets
  One per Dagger version (unsized) or
  per version x size template (sized).

  DaemonSet mode:
    Runners mount the engine Unix socket via
    hostPath. Lightweight — no engine sidecar.

  StatefulSet mode:
    Runners connect to the engine pod via
    kube-pod:// protocol. No volume mounts
    needed. Uses a ServiceAccount with RBAC
    for pods/exec access.
 *****************************************/
resource "helm_release" "dagger_runner_sets" {
  for_each  = module.dagger-engine.runner_sets
  name      = each.value.name
  namespace = kubernetes_namespace.arc_runners.metadata[0].name
  chart     = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"
  version   = var.arc_runners_version

  set = [
    {
      name  = "githubConfigSecret"
      value = local.gh_secret_name
    },
    {
      name  = "githubConfigUrl"
      value = var.gh_config_url
    },
    {
      name  = "runnerScaleSetName"
      value = each.value.label
    },
    {
      name  = "minRunners"
      value = tostring(each.value.is_alias ? local.effective_alias_min_runners : var.min_runners)
    },
    {
      name  = "maxRunners"
      value = tostring(var.max_runners)
    },
  ]

  values = [
    templatefile("${path.module}/../../manifests/github/runner-pod-template.yaml.tftpl", {
      kubectl_image                  = var.kubectl_image
      runner_image                   = var.runner_image
      image_pull_policy              = endswith(var.runner_image, ":latest") ? "Always" : "IfNotPresent"
      engine_mode                    = module.dagger-engine.engine_mode
      engine_runner_host             = each.value.engine_runner_host
      engine_socket_path             = each.value.engine_socket_path
      dagger_cloud_token_secret_name = module.dagger-engine.dagger_cloud_token_secret_name
      service_account_name           = module.dagger-engine.dagger_runner_service_account_name
      runner_requests                = each.value.runner_requests
      runner_limits                  = each.value.runner_limits
    }),
  ]

  depends_on = [
    helm_release.arc,
    module.dagger-engine,
    kubernetes_secret.gh_app_pre_defined_secret,
  ]
}

/*****************************************
  Failed Pod Cleanup CronJob
  Deletes pods in Failed state on a schedule
  so ARC can recreate them.
 *****************************************/
resource "kubernetes_service_account" "pod_cleanup" {
  count = var.enable_failed_pod_cleanup ? 1 : 0

  metadata {
    name      = "pod-cleanup"
    namespace = kubernetes_namespace.arc_runners.metadata[0].name
  }
}

resource "kubernetes_role" "pod_cleanup" {
  count = var.enable_failed_pod_cleanup ? 1 : 0

  metadata {
    name      = "pod-cleanup"
    namespace = kubernetes_namespace.arc_runners.metadata[0].name
  }
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["list", "delete"]
  }
}

resource "kubernetes_role_binding" "pod_cleanup" {
  count = var.enable_failed_pod_cleanup ? 1 : 0

  metadata {
    name      = "pod-cleanup"
    namespace = kubernetes_namespace.arc_runners.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.pod_cleanup[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.pod_cleanup[0].metadata[0].name
    namespace = kubernetes_namespace.arc_runners.metadata[0].name
  }
}

resource "kubernetes_cron_job_v1" "pod_cleanup" {
  count = var.enable_failed_pod_cleanup ? 1 : 0

  metadata {
    name      = "failed-pod-cleanup"
    namespace = kubernetes_namespace.arc_runners.metadata[0].name
  }
  spec {
    schedule = var.failed_pod_cleanup_schedule
    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            service_account_name = kubernetes_service_account.pod_cleanup[0].metadata[0].name
            container {
              name    = "cleanup"
              image   = var.kubectl_image
              command = ["sh", "-c", "kubectl delete pods --field-selector=status.phase=Failed -n ${var.arc_runners_namespace} --ignore-not-found"]
            }
            restart_policy = "OnFailure"
          }
        }
      }
    }
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 1
  }
}
