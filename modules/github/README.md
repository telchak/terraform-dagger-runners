# GitHub Actions Runners Module

Deploys [Dagger](https://dagger.io)-powered GitHub Actions self-hosted runners on an existing Kubernetes cluster using [Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller).

This module creates the ARC controller, runner scale sets, and calls the root module to deploy Dagger engines. Use this when you already have a Kubernetes cluster (GKE, EKS, AKS, on-premise, k3s).

For a fully managed GKE cluster, use [`modules/github/gke/`](gke/) instead.

## Usage

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
  engine_mode     = "statefulset"
}
```

## Runner Labels

The module automatically generates runner scale sets with `runs-on` labels based on the Dagger versions you configure. Each version produces three labels:

| Label type | Pattern | Purpose |
|------------|---------|---------|
| **Exact version** | `dagger-v0.20.0` | Pin to a specific patch version |
| **Minor alias** | `dagger-v0.20` | Always resolves to the latest patch in that minor series |
| **Latest alias** | `dagger-latest` | Always resolves to the newest version across all configured versions |

### Single version example

With `dagger_versions = ["0.20.0"]`, the module creates **3 runner scale sets**:

```
runs-on: dagger-v0.20.0    # exact
runs-on: dagger-v0.20      # minor alias → 0.20.0
runs-on: dagger-latest     # latest alias → 0.20.0
```

### Multi-version example

With `dagger_versions = ["0.19.5", "0.20.0", "0.20.3"]`, the module creates **7 runner scale sets**:

```
runs-on: dagger-v0.19.5    # exact
runs-on: dagger-v0.19      # minor alias → 0.19.5
runs-on: dagger-v0.20.0    # exact
runs-on: dagger-v0.20.3    # exact
runs-on: dagger-v0.20      # minor alias → 0.20.3 (latest patch in 0.20.x)
runs-on: dagger-latest     # latest alias → 0.20.3 (newest overall)
```

Alias scale sets (minor and latest) can have a different `min_runners` value via the `alias_min_runners` variable — useful for keeping exact-version runners warm while letting aliases scale to zero.

## Runner Size Templates

By default, runner pods have no resource requests or limits (BestEffort QoS). Use `runner_size_templates` to create T-shirt sized runner scale sets with specific resource constraints.

When size templates are defined, each base label gets a size suffix, and the **unsuffixed labels are not created**. This means workflows must target a specific size.

### Example: small / medium / large

```hcl
module "dagger-runners" {
  source = "github.com/telchak/terraform-dagger-runners//modules/github?ref=v0.1.0"

  # ...

  dagger_versions = ["0.20.0"]

  runner_size_templates = {
    small = {
      runner_requests = { cpu = "500m", memory = "1Gi" }
      runner_limits   = { cpu = "1",    memory = "2Gi" }
    }
    medium = {
      runner_requests = { cpu = "1",  memory = "2Gi" }
      runner_limits   = { cpu = "2",  memory = "4Gi" }
    }
    large = {
      runner_requests = { cpu = "2",  memory = "4Gi" }
      runner_limits   = { cpu = "4",  memory = "8Gi" }
    }
  }
}
```

This produces **9 runner scale sets** (3 base labels x 3 sizes):

```
runs-on: dagger-v0.20.0-small     runs-on: dagger-v0.20-small     runs-on: dagger-latest-small
runs-on: dagger-v0.20.0-medium    runs-on: dagger-v0.20-medium    runs-on: dagger-latest-medium
runs-on: dagger-v0.20.0-large     runs-on: dagger-v0.20-large     runs-on: dagger-latest-large
```

Use them in your workflow:

```yaml
jobs:
  lint:
    runs-on: dagger-latest-small
  build:
    runs-on: dagger-latest-medium
  deploy:
    runs-on: dagger-latest-large
```

### Default size (no suffix)

Use an empty string key `""` to create a default size that keeps the original unsuffixed labels:

```hcl
runner_size_templates = {
  "" = {
    runner_requests = { cpu = "500m", memory = "1Gi" }
  }
  large = {
    runner_requests = { cpu = "2", memory = "4Gi" }
    runner_limits   = { cpu = "4", memory = "8Gi" }
  }
}
```

This produces both `dagger-latest` (default resources) and `dagger-latest-large` (heavy workloads).

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
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_dagger-engine"></a> [dagger-engine](#module\_dagger-engine) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [helm_release.arc](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.dagger_runner_sets](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_cron_job_v1.pod_cleanup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cron_job_v1) | resource |
| [kubernetes_namespace.arc_runners](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.arc_systems](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_role.pod_cleanup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role) | resource |
| [kubernetes_role_binding.pod_cleanup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_secret.gh_app_pre_defined_secret](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_service_account.pod_cleanup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alias_min_runners"></a> [alias\_min\_runners](#input\_alias\_min\_runners) | Minimum number of runners for alias scale sets (minor aliases like dagger-v0.19 and dagger-latest). When null (default), inherits the value of min\_runners. | `number` | `null` | no |
| <a name="input_arc_controller_values"></a> [arc\_controller\_values](#input\_arc\_controller\_values) | List of values in raw YAML format to pass to the ARC controller Helm chart. | `list(string)` | `[]` | no |
| <a name="input_arc_controller_version"></a> [arc\_controller\_version](#input\_arc\_controller\_version) | Version of the ARC scale set controller Helm chart. | `string` | `"0.10.1"` | no |
| <a name="input_arc_runners_namespace"></a> [arc\_runners\_namespace](#input\_arc\_runners\_namespace) | Namespace for the ARC runner pods. | `string` | `"arc-runners"` | no |
| <a name="input_arc_runners_version"></a> [arc\_runners\_version](#input\_arc\_runners\_version) | Version of the ARC runner scale set Helm chart. | `string` | `"0.10.1"` | no |
| <a name="input_arc_systems_namespace"></a> [arc\_systems\_namespace](#input\_arc\_systems\_namespace) | Namespace for the ARC operator pods. | `string` | `"arc-systems"` | no |
| <a name="input_dagger_cloud_token"></a> [dagger\_cloud\_token](#input\_dagger\_cloud\_token) | Optional Dagger Cloud token. Enables Magicache (distributed cache) on the Dagger engine and injects DAGGER\_CLOUD\_TOKEN on runner pods for pipeline visualization. Complements both DaemonSet and StatefulSet engine modes. | `string` | `""` | no |
| <a name="input_dagger_engine_requests"></a> [dagger\_engine\_requests](#input\_dagger\_engine\_requests) | Resource requests for the Dagger engine pods. The engine bursts well above requests under parallel load (e.g. 2-3 cores with 30 runners), but the scheduler only needs modest requests for placement. Memory should be generous — the engine's BuildKit cache is memory-mapped. | <pre>object({<br/>    cpu    = optional(string, "250m")<br/>    memory = optional(string, "12Gi")<br/>  })</pre> | <pre>{<br/>  "cpu": "250m",<br/>  "memory": "12Gi"<br/>}</pre> | no |
| <a name="input_dagger_versions"></a> [dagger\_versions](#input\_dagger\_versions) | List of Dagger engine versions to deploy. Each version creates a separate runner scale set with label 'dagger-v<version>' (e.g. 'dagger-v0.19'). | `list(string)` | <pre>[<br/>  "0.19.5"<br/>]</pre> | no |
| <a name="input_enable_failed_pod_cleanup"></a> [enable\_failed\_pod\_cleanup](#input\_enable\_failed\_pod\_cleanup) | Deploy a CronJob that deletes Failed runner pods so ARC can recreate them. | `bool` | `true` | no |
| <a name="input_enable_vpa"></a> [enable\_vpa](#input\_enable\_vpa) | Create Vertical Pod Autoscaler objects for the Dagger engine. Requires VPA to be installed on the cluster (cloud-specific). | `bool` | `false` | no |
| <a name="input_engine_mode"></a> [engine\_mode](#input\_engine\_mode) | Dagger engine deployment mode. 'daemonset' runs one engine per node with ephemeral hostPath cache. 'statefulset' runs one engine per version with persistent PVC cache. | `string` | `"daemonset"` | no |
| <a name="input_failed_pod_cleanup_schedule"></a> [failed\_pod\_cleanup\_schedule](#input\_failed\_pod\_cleanup\_schedule) | Cron schedule for the failed pod cleanup job. | `string` | `"0 * * * *"` | no |
| <a name="input_gh_app_existing_secret_name"></a> [gh\_app\_existing\_secret\_name](#input\_gh\_app\_existing\_secret\_name) | Name of a pre-existing Kubernetes secret containing GitHub App credentials. When set, the module skips creating the secret and the gh\_app\_id/gh\_app\_installation\_id/gh\_app\_private\_key variables are ignored. The secret must exist in the runner namespace and contain keys: github\_app\_id, github\_app\_installation\_id, github\_app\_private\_key. | `string` | `""` | no |
| <a name="input_gh_app_id"></a> [gh\_app\_id](#input\_gh\_app\_id) | GitHub App ID for ARC authentication. Ignored when gh\_app\_existing\_secret\_name is set. | `string` | `""` | no |
| <a name="input_gh_app_installation_id"></a> [gh\_app\_installation\_id](#input\_gh\_app\_installation\_id) | GitHub App installation ID. Ignored when gh\_app\_existing\_secret\_name is set. | `string` | `""` | no |
| <a name="input_gh_app_pre_defined_secret_name"></a> [gh\_app\_pre\_defined\_secret\_name](#input\_gh\_app\_pre\_defined\_secret\_name) | Name for the Kubernetes secret when the module creates it. Ignored when gh\_app\_existing\_secret\_name is set. | `string` | `"gh-app-pre-defined-secret"` | no |
| <a name="input_gh_app_private_key"></a> [gh\_app\_private\_key](#input\_gh\_app\_private\_key) | GitHub App private key (.pem file contents). Ignored when gh\_app\_existing\_secret\_name is set. | `string` | `""` | no |
| <a name="input_gh_config_url"></a> [gh\_config\_url](#input\_gh\_config\_url) | URL of GitHub App config. For an organization: https://github.com/ORGANIZATION | `string` | n/a | yes |
| <a name="input_kubectl_image"></a> [kubectl\_image](#input\_kubectl\_image) | Container image providing kubectl. Used by the failed pod cleanup CronJob and the StatefulSet mode init container. Override to pin a specific version or use a private registry mirror. | `string` | `"bitnami/kubectl:latest"` | no |
| <a name="input_max_runners"></a> [max\_runners](#input\_max\_runners) | Maximum number of runners per scale set. | `number` | `5` | no |
| <a name="input_min_runners"></a> [min\_runners](#input\_min\_runners) | Minimum number of runners per scale set. Set to 0 for scale-to-zero. | `number` | `0` | no |
| <a name="input_persistent_cache_size"></a> [persistent\_cache\_size](#input\_persistent\_cache\_size) | Size of the persistent cache PVC per Dagger engine. Only used when engine\_mode = 'statefulset'. The Helm chart manages the PVC via volumeClaimTemplates. | `string` | `"100Gi"` | no |
| <a name="input_persistent_cache_storage_class_name"></a> [persistent\_cache\_storage\_class\_name](#input\_persistent\_cache\_storage\_class\_name) | StorageClass name for the persistent cache PVC. Only used when<br/>engine\_mode = 'statefulset'. Must support ReadWriteOnce access mode.<br/><br/>The StorageClass determines the underlying disk type (HDD vs SSD).<br/>SSD is recommended for Dagger cache — build performance is heavily<br/>I/O-bound, and SSD typically yields 2-5x faster cold builds.<br/><br/>Common StorageClass names by cloud provider:<br/><br/>  GKE:  "standard-rwo"  (HDD)  \|  "premium-rwo"  (SSD) ← recommended<br/>  EKS:  "gp3"           (SSD)  \|  "io2"           (High-IOPS SSD)<br/>  AKS:  "managed"       (HDD)  \|  "managed-premium" (SSD)<br/><br/>Leave empty to use the cluster default StorageClass. | `string` | `""` | no |
| <a name="input_runner_image"></a> [runner\_image](#input\_runner\_image) | Container image for the GitHub Actions runner. Pin to a specific tag (e.g. '2.323.0') to avoid registry checks on every pod start and speed up scheduling. | `string` | `"ghcr.io/actions/actions-runner:latest"` | no |
| <a name="input_runner_size_templates"></a> [runner\_size\_templates](#input\_runner\_size\_templates) | Map of size template names to resource configurations for the runner pods.<br/>When defined, each runner label gets a size suffix (e.g. runs-on:<br/>dagger-v0.19-large) and the base unsuffixed labels are not created.<br/>Use an empty key "" for the default size (no suffix on labels).<br/><br/>When empty (default), runner sets are created without size suffixes and<br/>without resource constraints (pods get BestEffort QoS class). | <pre>map(object({<br/>    runner_requests = optional(map(string), {})<br/>    runner_limits   = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_vpa_update_mode"></a> [vpa\_update\_mode](#input\_vpa\_update\_mode) | VPA update mode for the Dagger engine. 'Off' = recommendation only, 'InPlaceOrRecreate' = auto-resize without restarting pods when possible (requires Kubernetes >= 1.33 with InPlacePodVerticalScaling feature gate enabled; GA in 1.35). | `string` | `"Off"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_runner_labels"></a> [runner\_labels](#output\_runner\_labels) | Map of all runner scale set keys to their 'runs-on' labels. Includes exact versions (dagger-v0.19.5), minor aliases (dagger-v0.19), and dagger-latest. |
<!-- END_TF_DOCS -->
