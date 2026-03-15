# Terraform Dagger Runners

Terraform module that deploys [Dagger](https://dagger.io) engines on Kubernetes — CI-agnostic and cloud-agnostic.

The repository is organized in three layers:

| Layer | Path | Responsibility |
|-------|------|---------------|
| **Engine** (root) | `/` | Dagger engine deployment (Helm, VPA, RBAC, secrets). CI-agnostic, cloud-agnostic. |
| **CI platform** | `modules/github/` | GitHub Actions runners via ARC. Calls root for engine. |
| **Cloud** | `modules/github/gke/` | GKE cluster provisioning. Calls CI platform module. |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  modules/github/gke/          (Cloud layer)                 │
│  GKE cluster, network, node pool                            │
│                                                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  modules/github/           (CI platform layer)         │ │
│  │  ARC controller, runner scale sets, pod cleanup        │ │
│  │                                                        │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │  /                      (Engine layer — root)    │  │ │
│  │  │  Dagger Helm releases, VPA, RBAC, cloud token    │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Create a new GKE cluster with GitHub runners

Use `modules/github/gke/` when you want the module to provision everything: GKE cluster, networking, ARC controller, runner scale sets, and Dagger engines.

```hcl
module "dagger-runners" {
  source = "github.com/telchak/terraform-dagger-runners//modules/github/gke?ref=v0.1.0"

  # GCP
  project_id     = "my-project"
  region         = "us-central1"
  create_network = true
  machine_type   = "n2-standard-4"   # 4 vCPU, 16 GB RAM
  disk_size_gb   = 100
  min_node_count = 1
  max_node_count = 4
  spot           = true

  # GitHub App authentication — required for ARC.
  # https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/authenticating-to-the-github-api
  gh_app_id              = var.gh_app_id
  gh_app_installation_id = var.gh_app_installation_id
  gh_app_private_key     = var.gh_app_private_key
  gh_config_url          = "https://github.com/my-org"

  # Dagger
  dagger_versions = ["0.20.0"]
  min_runners     = 0   # scale-to-zero when idle
  max_runners     = 10

  # StatefulSet mode: persistent PVC cache, Spot-safe.
  engine_mode                         = "statefulset"
  persistent_cache_size               = "100Gi"
  persistent_cache_storage_class_name = "premium-rwo"

  # Runner pod resources (see Sizing Guide below).
  runner_size_templates = {
    "" = {
      runner_requests = { cpu = "50m", memory = "256Mi" }
      runner_limits   = {}
    }
  }
}
```

### Deploy onto an existing Kubernetes cluster

Use `modules/github/` when you already have a Kubernetes cluster (GKE, EKS, AKS, on-premise, k3s, etc.). You must configure the `kubernetes` and `helm` providers to point to your cluster.

```hcl
module "dagger-runners" {
  source = "github.com/telchak/terraform-dagger-runners//modules/github?ref=v0.1.0"

  # GitHub App authentication — required for ARC.
  gh_app_id              = var.gh_app_id
  gh_app_installation_id = var.gh_app_installation_id
  gh_app_private_key     = var.gh_app_private_key
  gh_config_url          = "https://github.com/my-org"

  # Dagger
  dagger_versions = ["0.20.0"]
  min_runners     = 0
  max_runners     = 10

  # DaemonSet mode (default): simplest setup, ephemeral cache per node.
  # No PVC needed — works on any cluster without a StorageClass.
  engine_mode = "daemonset"
}
```

To use **StatefulSet mode** with persistent cache, the cluster needs a StorageClass that supports `ReadWriteOnce`. Leave `persistent_cache_storage_class_name` empty to use the cluster's default StorageClass, or set it explicitly:

```hcl
module "dagger-runners" {
  source = "github.com/telchak/terraform-dagger-runners//modules/github?ref=v0.1.0"

  gh_app_id              = var.gh_app_id
  gh_app_installation_id = var.gh_app_installation_id
  gh_app_private_key     = var.gh_app_private_key
  gh_config_url          = "https://github.com/my-org"

  dagger_versions = ["0.20.0"]
  min_runners     = 0
  max_runners     = 10

  # StatefulSet mode with persistent cache.
  engine_mode       = "statefulset"
  persistent_cache_size = "100Gi"

  # Explicit StorageClass (pick one for your environment):
  #   GKE:         "premium-rwo" (SSD) or "standard-rwo" (HDD)
  #   EKS:         "gp3"
  #   AKS:         "managed-premium" (SSD) or "managed" (HDD)
  #   On-premise:  "longhorn", "rook-ceph-block", "nfs-client", etc.
  #   Empty:       uses the cluster's default StorageClass
  persistent_cache_storage_class_name = ""

  # Runner pod resources (see Sizing Guide below).
  runner_size_templates = {
    "" = {
      runner_requests = { cpu = "50m", memory = "256Mi" }
      runner_limits   = {}
    }
  }
}
```

### Engine only (CI-agnostic)

Use the root module when integrating with a CI platform not yet supported as a submodule (e.g. GitLab, Bitbucket, Jenkins). It deploys only the Dagger engine — no runners, no CI controller. You are responsible for creating runner pods that connect to the engine.

```hcl
module "dagger-engine" {
  source = "github.com/telchak/terraform-dagger-runners?ref=v0.1.0"

  # The namespace must already exist.
  namespace = "my-ci-runners"

  dagger_versions = ["0.20.0"]
  engine_mode     = "statefulset"

  persistent_cache_size               = "100Gi"
  persistent_cache_storage_class_name = ""  # uses cluster default
}
```

The module outputs everything your CI platform integration needs:

| Output | Description |
|--------|-------------|
| `runner_sets` | Map of runner set definitions (name, label, engine connection string, socket path, etc.) |
| `engine_mode` | `daemonset` or `statefulset` — determines how runners connect to the engine |
| `dagger_runner_service_account_name` | ServiceAccount for runner pods (StatefulSet mode, for `kube-pod://` RBAC) |
| `dagger_cloud_token_secret_name` | Kubernetes secret name to mount as `DAGGER_CLOUD_TOKEN` env var |
| `namespace` | Namespace where the engine is deployed |

Your runner pods need to set `_EXPERIMENTAL_DAGGER_RUNNER_HOST` to the `engine_runner_host` value from `runner_sets` to connect to the correct engine. In StatefulSet mode, they also need the ServiceAccount and kubectl binary for the `kube-pod://` protocol.

## Sizing Guide

Runner pods are lightweight — they only run the GitHub Actions runner process. The Dagger engine runs separately (DaemonSet or StatefulSet) and is shared by all runners. This means you need to size two things independently: the **nodes** and the **runner pods**.

### Node sizing (GKE)

The table below shows recommended GKE machine types. The minimum viable node is 2 vCPU / 8 GB RAM. Larger nodes are more cost-efficient because they amortize the overhead of system pods (kube-dns, kube-proxy, ARC controller, Dagger engine) across more runner pods.

| Machine type | vCPU | RAM | Max runners per node | Best for |
|-------------|------|-----|---------------------|----------|
| `e2-standard-2` | 2 | 8 GB | ~5 | Dev/test, low concurrency |
| `n2-standard-4` | 4 | 16 GB | ~15 | Small teams, moderate CI load |
| `n2-standard-8` | 8 | 32 GB | ~30 | Medium teams, multi-version |
| `n2-standard-16` | 16 | 64 GB | ~50+ | Large teams, high concurrency |

> **Note:** "Max runners per node" assumes runner pods request 50m CPU / 256Mi memory and accounts for ~1.5 vCPU / 2 GB overhead for system pods + Dagger engine. Actual capacity depends on your workload.

### Runner pod sizing

Runner pods are I/O-bound (waiting on the Dagger engine), not CPU/memory-bound. Observed usage is typically ~30m CPU / ~230Mi memory per runner. Setting explicit requests improves scheduling predictability and avoids BestEffort QoS eviction.

| Size | CPU request | Memory request | Use case |
|------|------------|----------------|----------|
| Default | 50m | 256Mi | Most workloads — lightweight runner connecting to shared engine |
| Large | 250m | 512Mi | Runners that do non-trivial work outside of Dagger (e.g. heavy `actions/checkout`, local compilation) |

**Example with size templates:**

```hcl
runner_size_templates = {
  # Default size (no suffix): runs-on: dagger-v0.20
  "" = {
    runner_requests = { cpu = "50m", memory = "256Mi" }
    runner_limits   = {}
  }
  # Large size (suffix): runs-on: dagger-v0.20-large
  large = {
    runner_requests = { cpu = "250m", memory = "512Mi" }
    runner_limits   = { cpu = "1", memory = "1Gi" }
  }
}
```

### Dagger engine sizing

The engine defaults to requesting 250m CPU / 12 GB memory. The high memory request is intentional — the engine's BuildKit cache is memory-mapped, and memory pressure causes cache eviction which slows builds significantly.

| Concurrency | Engine CPU request | Engine memory request | Notes |
|-------------|-------------------|----------------------|-------|
| 1-5 runners | 250m (default) | 12Gi (default) | Engine bursts to ~1 core under load |
| 5-30 runners | 250m | 12Gi | Engine bursts to ~2-3 cores; scheduler only needs modest requests |
| 30+ runners | 500m | 16Gi | Consider increasing if builds show CPU throttling |

> **Tip:** Enable VPA (`enable_vpa = true`) to get actual resource usage recommendations from the Vertical Pod Autoscaler, then tune requests based on real data.

### Recommended configurations

| Scenario | Node type | Nodes | Runners | Engine mode | Runner requests |
|----------|-----------|-------|---------|-------------|----------------|
| Solo developer | `e2-standard-2` | 1 | 1-5 | daemonset | 50m / 256Mi |
| Small team (5-10 devs) | `n2-standard-4` | 1-2 | 5-15 | statefulset | 50m / 256Mi |
| Medium team (10-30 devs) | `n2-standard-8` | 2-4 | 10-30 | statefulset | 50m / 256Mi |
| Large team / monorepo | `n2-standard-16` | 2-4 | 30-50+ | statefulset | 50m / 256Mi |

For all StatefulSet configurations, use Spot instances (`spot = true`) to reduce costs — the PVC cache survives node preemptions.

## Caching Strategies

The module supports three caching strategies. Strategies 1 and 2 are mutually exclusive (set via `engine_mode`). Strategy 3 is complementary and can be combined with either.

### Strategy 1: DaemonSet + hostPath (default)

```
engine_mode = "daemonset"
```

```
┌─────────────── Node A ──────────────┐  ┌─────────────── Node B ──────────────┐
│                                     │  │                                     │
│  ┌─────────┐  ┌─────────┐           │  │  ┌─────────┐                        │
│  │ Runner  │  │ Runner  │           │  │  │ Runner  │                        │
│  │ Pod 1   │  │ Pod 2   │           │  │  │ Pod 3   │                        │
│  └────┬────┘  └────┬────┘           │  │  └────┬────┘                        │
│       │ Unix       │ socket         │  │       │ Unix socket                 │
│  ┌────▼────────────▼────┐           │  │  ┌────▼─────────────────┐           │
│  │  Dagger Engine       │           │  │  │  Dagger Engine       │           │
│  │  (DaemonSet pod)     │           │  │  │  (DaemonSet pod)     │           │
│  │                      │           │  │  │                      │           │
│  │  /var/lib/dagger ────┼── cache   │  │  │  /var/lib/dagger ────┼── cache   │
│  │  (hostPath)          │           │  │  │  (hostPath)          │           │
│  └──────────────────────┘           │  │  └──────────────────────┘           │
└─────────────────────────────────────┘  └─────────────────────────────────────┘
```

**How it works:** One Dagger engine runs on every node as a DaemonSet. Each engine stores its cache at `/var/lib/dagger` on the host via hostPath. Runner pods connect to the local engine via a Unix socket mounted from the host.

| Property | Value |
|----------|-------|
| Cache persistence | Ephemeral — lost when node is recycled |
| Cache scope | Node-local — each node has its own cache |
| Connection | `unix:///run/dagger/engine.sock` via hostPath mount |
| RBAC | None required |
| Best for | Stable node pools, Spot-tolerant workloads, simplest setup |

### Strategy 2: StatefulSet + PVC

```
engine_mode = "statefulset"
```

```
┌─────────────────────────────────────────────────────┐
│  Kubernetes Cluster                                 │
│                                                     │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐              │
│  │ Runner  │  │ Runner  │  │ Runner  │              │
│  │ Pod 1   │  │ Pod 2   │  │ Pod 3   │              │
│  └────┬────┘  └────┬────┘  └────┬────┘              │
│       │            │            │                   │
│       │    kube-pod:// protocol (K8s API exec)      │
│       │            │            │                   │
│  ┌────▼────────────▼────────────▼────┐              │
│  │  Dagger Engine                    │              │
│  │  (StatefulSet, replicas=1)        │              │
│  │                                   │              │
│  │  /var/lib/dagger ─────────┐       │              │
│  └───────────────────────────┼───────┘              │
│                              │                      │
│                     ┌────────▼────────┐             │
│                     │  PVC (RWO)      │             │
│                     │  e.g. 100Gi     │             │
│                     │  premium-rwo    │             │
│                     └─────────────────┘             │
└─────────────────────────────────────────────────────┘
```

**How it works:** One Dagger engine runs per version as a StatefulSet with `replicas=1`. The Helm chart creates a PVC via `volumeClaimTemplates` for persistent cache storage. Runner pods connect to the engine via the `kube-pod://` protocol, which uses the Kubernetes API to exec into the engine pod. This works across nodes — runners don't need to be co-located with the engine.

| Property | Value |
|----------|-------|
| Cache persistence | Persistent — survives pod restarts and node changes |
| Cache scope | Per-version — one PVC per engine StatefulSet |
| Connection | `kube-pod://<pod>?namespace=<ns>` via Kubernetes API |
| RBAC | ServiceAccount + Role (pods get/list, pods/exec) — created automatically |
| Best for | Spot instances, node autoscaling, when cache warmth is critical |

**StorageClass** controls the disk type. SSD is recommended — Dagger builds are heavily I/O-bound, and SSD typically yields 2-5x faster cold builds. Leave `persistent_cache_storage_class_name` empty to use the cluster's default StorageClass.

| Cloud | HDD (cheaper) | SSD (recommended) |
|-------|---------------|-------------------|
| GKE | `standard-rwo` (pd-standard) | `premium-rwo` (pd-ssd) |
| EKS | — | `gp3` (General Purpose) / `io2` (Provisioned IOPS) |
| AKS | `managed` (Standard_LRS) | `managed-premium` (Premium_LRS) |
| On-premise | Depends on provisioner | `longhorn`, `rook-ceph-block`, etc. |

### Strategy 3: Dagger Cloud (complementary)

```
dagger_cloud_token = "dag_..."
```

```
┌───────────────────────────────┐         ┌──────────────────────┐
│  Kubernetes Cluster           │         │  Dagger Cloud        │
│                               │         │                      │
│  ┌─────────┐  ┌────────────┐  │         │  ┌────────────────┐  │
│  │ Runner  │  │  Dagger    │  │  HTTP   │  │  Magicache     │  │
│  │ Pod     │  │  Engine    │◄─┼─────────┼──│  (distributed  │  │
│  │         │  │            │  │         │  │   cache)       │  │
│  │ DAGGER_ │  │ magicache: │  │         │  └────────────────┘  │
│  │ CLOUD_  │  │  enabled   │  │         │                      │
│  │ TOKEN   │  └────────────┘  │         │  ┌────────────────┐  │
│  │ (traces)│                  │         │  │  Traces UI     │  │
│  └─────────┘                  │         │  └────────────────┘  │
└───────────────────────────────┘         └──────────────────────┘
```

**How it works:** When `dagger_cloud_token` is set, two things happen:
1. **Engine-side:** The Helm chart enables [Magicache](https://docs.dagger.io/cloud/magicache) — a distributed cache service that shares build artifacts across all engines and clusters.
2. **Runner-side:** `DAGGER_CLOUD_TOKEN` is injected as an environment variable for SDK telemetry and pipeline tracing in the Dagger Cloud UI.

This is complementary — it works with **both** DaemonSet and StatefulSet modes.

| Property | Value |
|----------|-------|
| Cache persistence | Permanent — stored in Dagger Cloud |
| Cache scope | Global — shared across all engines, clusters, and CI systems |
| Configuration | `magicache.enabled` + `magicache.token` on engine Helm chart |
| Best for | Multi-cluster setups, Spot instances, teams sharing build artifacts |

### Strategy Comparison

| | DaemonSet (default) | StatefulSet | Dagger Cloud |
|---|---|---|---|
| `engine_mode` | `"daemonset"` | `"statefulset"` | Either |
| Cache survives node recycle | No | Yes | Yes |
| Cache shared across nodes | No | Yes (one engine) | Yes (all clusters) |
| Extra infrastructure | None | PVC per version | Dagger Cloud account |
| Runner connection | Unix socket | `kube-pod://` | N/A |
| RBAC needed | No | Yes (auto) | No |
| Cold start | Per-node | Per-cluster | Global |

### Recommended Combinations

| Scenario | Configuration |
|----------|---------------|
| Simple, stable nodes | `engine_mode = "daemonset"` (default) |
| Spot instances, single cluster | `engine_mode = "statefulset"` |
| Multi-cluster, shared cache | `engine_mode = "daemonset"` + `dagger_cloud_token` |
| Spot + maximum cache efficiency | `engine_mode = "statefulset"` + `dagger_cloud_token` |

## Runner Labels

Each Dagger version automatically creates three runner labels:

| Label | Example | Description |
|-------|---------|-------------|
| Exact version | `dagger-v0.20.0` | Pins to a specific patch |
| Minor alias | `dagger-v0.20` | Always routes to the latest patch in that minor |
| Latest | `dagger-latest` | Always routes to the newest version |

When `runner_size_templates` is set, each label gets a size suffix (e.g. `dagger-v0.20-large`).

## Modules

| Module | Description |
|--------|-------------|
| [Root](/) | Dagger engine only — CI-agnostic, cloud-agnostic |
| [modules/github/](modules/github/) | GitHub Actions runners via ARC + Dagger engine |
| [modules/github/gke/](modules/github/gke/) | GKE cluster + GitHub runners |

## Examples

| Example | Engine Mode | Dagger Cloud | Description |
|---------|-------------|--------------|-------------|
| [GKE Simple](examples/github/gke-simple/) | DaemonSet | No | Single version, simplest setup |
| [GKE StatefulSet](examples/github/gke-statefulset/) | StatefulSet | No | Persistent PVC cache, Spot-safe |
| [GKE Dagger Cloud](examples/github/gke-dagger-cloud/) | DaemonSet | Yes | Distributed cache + traces |
| [GKE Multi-Version](examples/github/gke-multi-version/) | StatefulSet | Yes | Two versions, Spot, full caching |
| [Existing Cluster](examples/github/existing-cluster/) | DaemonSet | No | Deploy onto any existing K8s cluster (GKE, EKS, AKS, k3s) |

## Roadmap

### GitHub Actions

- [x] GCP GKE
- [ ] AWS EKS
- [ ] Azure AKS
- [ ] Scaleway Kapsule

### GitLab CI

- [ ] GCP GKE
- [ ] AWS EKS
- [ ] Azure AKS
- [ ] Scaleway Kapsule

### Bitbucket Pipelines

- [ ] GCP GKE
- [ ] AWS EKS
- [ ] Azure AKS
- [ ] Scaleway Kapsule

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.1.1 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | 2.1.5 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.dagger_engine](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.dagger_engine_vpa](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_role.dagger_engine_access](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role) | resource |
| [kubernetes_role_binding.dagger_engine_access](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_secret.dagger_cloud_token](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_service_account.dagger_runner](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_dagger_cloud_token"></a> [dagger\_cloud\_token](#input\_dagger\_cloud\_token) | Optional Dagger Cloud token. Enables Magicache (distributed cache) on the Dagger engine and creates a Kubernetes secret for runner pods. Complements both DaemonSet and StatefulSet engine modes. | `string` | `""` | no |
| <a name="input_dagger_engine_requests"></a> [dagger\_engine\_requests](#input\_dagger\_engine\_requests) | Resource requests for the Dagger engine pods. The engine bursts well above requests under parallel load (e.g. 2-3 cores with 30 runners), but the scheduler only needs modest requests for placement. Memory should be generous — the engine's BuildKit cache is memory-mapped. | <pre>object({<br/>    cpu    = optional(string, "250m")<br/>    memory = optional(string, "12Gi")<br/>  })</pre> | <pre>{<br/>  "cpu": "250m",<br/>  "memory": "12Gi"<br/>}</pre> | no |
| <a name="input_dagger_versions"></a> [dagger\_versions](#input\_dagger\_versions) | List of Dagger engine versions to deploy. Each version creates a separate runner set definition with label 'dagger-v<version>' (e.g. 'dagger-v0.19'). | `list(string)` | <pre>[<br/>  "0.19.5"<br/>]</pre> | no |
| <a name="input_enable_vpa"></a> [enable\_vpa](#input\_enable\_vpa) | Create Vertical Pod Autoscaler objects for the Dagger engine. Requires VPA to be installed on the cluster (cloud-specific). | `bool` | `false` | no |
| <a name="input_engine_mode"></a> [engine\_mode](#input\_engine\_mode) | Dagger engine deployment mode. 'daemonset' runs one engine per node with ephemeral hostPath cache. 'statefulset' runs one engine per version with persistent PVC cache. | `string` | `"daemonset"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace to deploy the Dagger engine into. Must already exist — this module does not create namespaces. | `string` | n/a | yes |
| <a name="input_persistent_cache_size"></a> [persistent\_cache\_size](#input\_persistent\_cache\_size) | Size of the persistent cache PVC per Dagger engine. Only used when engine\_mode = 'statefulset'. The Helm chart manages the PVC via volumeClaimTemplates. | `string` | `"100Gi"` | no |
| <a name="input_persistent_cache_storage_class_name"></a> [persistent\_cache\_storage\_class\_name](#input\_persistent\_cache\_storage\_class\_name) | StorageClass name for the persistent cache PVC. Only used when<br/>engine\_mode = 'statefulset'. Must support ReadWriteOnce access mode.<br/><br/>The StorageClass determines the underlying disk type (HDD vs SSD).<br/>SSD is recommended for Dagger cache — build performance is heavily<br/>I/O-bound, and SSD typically yields 2-5x faster cold builds.<br/><br/>Common StorageClass names by cloud provider:<br/><br/>  GKE:  "standard-rwo"  (HDD)  \|  "premium-rwo"  (SSD) ← recommended<br/>  EKS:  "gp3"           (SSD)  \|  "io2"           (High-IOPS SSD)<br/>  AKS:  "managed"       (HDD)  \|  "managed-premium" (SSD)<br/><br/>Leave empty to use the cluster default StorageClass. | `string` | `""` | no |
| <a name="input_runner_size_templates"></a> [runner\_size\_templates](#input\_runner\_size\_templates) | Map of size template names to resource configurations for the runner pods.<br/>When defined, each runner label gets a size suffix (e.g. runs-on:<br/>dagger-v0.19-large) and the base unsuffixed labels are not created.<br/>Use an empty key "" for the default size (no suffix on labels).<br/><br/>Runner pods are lightweight — they only run the GitHub Actions runner<br/>process. The Dagger engine runs separately (as DaemonSet or StatefulSet)<br/>and is shared by all runners.<br/><br/>Example:<br/>  runner\_size\_templates = {<br/>    "" = {<br/>      runner\_requests = { cpu = "100m", memory = "256Mi" }<br/>      runner\_limits   = {}<br/>    }<br/>    large = {<br/>      runner\_requests = { cpu = "500m", memory = "512Mi" }<br/>      runner\_limits   = { cpu = "1",    memory = "1Gi" }<br/>    }<br/>  }<br/><br/>When empty (default), runner sets are created without size suffixes and<br/>without resource constraints (pods get BestEffort QoS class). | <pre>map(object({<br/>    runner_requests = optional(map(string), {})<br/>    runner_limits   = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_vpa_update_mode"></a> [vpa\_update\_mode](#input\_vpa\_update\_mode) | VPA update mode for the Dagger engine. 'Off' = recommendation only, 'InPlaceOrRecreate' = auto-resize without restarting pods when possible (requires Kubernetes >= 1.33 with InPlacePodVerticalScaling feature gate enabled; GA in 1.35). | `string` | `"Off"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dagger_cloud_token_secret_name"></a> [dagger\_cloud\_token\_secret\_name](#output\_dagger\_cloud\_token\_secret\_name) | Name of the Kubernetes secret containing the Dagger Cloud token. Empty string when no token is configured. |
| <a name="output_dagger_runner_service_account_name"></a> [dagger\_runner\_service\_account\_name](#output\_dagger\_runner\_service\_account\_name) | Name of the ServiceAccount for runner pods (StatefulSet mode only). Empty string when engine\_mode is daemonset. |
| <a name="output_engine_mode"></a> [engine\_mode](#output\_engine\_mode) | The engine deployment mode (daemonset or statefulset). CI platform modules use this to configure runner pod templates. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | The namespace the Dagger engine is deployed into. |
| <a name="output_runner_sets"></a> [runner\_sets](#output\_runner\_sets) | Map of runner set definitions. Each entry contains name, label, engine\_image, engine\_socket\_path, engine\_runner\_host, is\_alias, runner\_requests, and runner\_limits. CI platform modules iterate over this to create platform-specific runner scale sets. |
<!-- END_TF_DOCS -->

## License

Apache 2.0 — see [LICENSE](LICENSE).
