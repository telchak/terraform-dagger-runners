# GKE + GitHub Actions Runners Module

Provisions a GKE cluster and deploys [Dagger](https://dagger.io)-powered GitHub Actions self-hosted runners using [Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller).

This is the all-in-one module: GKE cluster, networking, ARC controller, runner scale sets, and Dagger engines. Use this when you want the module to manage everything.

To deploy onto an existing Kubernetes cluster instead, use [`modules/github/`](../) directly.

## Usage

```hcl
module "dagger-runners" {
  source = "github.com/telchak/terraform-dagger-runners//modules/github/gke?ref=v0.1.0"

  project_id     = "my-project"
  region         = "us-central1"
  create_network = true
  machine_type   = "n2-standard-4"
  min_node_count = 1
  max_node_count = 4
  spot           = true

  gh_app_id              = var.gh_app_id
  gh_app_installation_id = var.gh_app_installation_id
  gh_app_private_key     = var.gh_app_private_key
  gh_config_url          = "https://github.com/my-org"

  dagger_versions = ["0.20.0"]
  min_runners     = 0
  max_runners     = 10
  engine_mode     = "statefulset"

  persistent_cache_size               = "100Gi"
  persistent_cache_storage_class_name = "premium-rwo"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.0, < 8 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >= 5.0, < 8 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 6.50.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_dagger-runners"></a> [dagger-runners](#module\_dagger-runners) | ./.. | n/a |
| <a name="module_runner-cluster"></a> [runner-cluster](#module\_runner-cluster) | terraform-google-modules/kubernetes-engine/google//modules/beta-public-cluster/ | ~> 35.0 |

## Resources

| Name | Type |
|------|------|
| [google_compute_network.dagger-network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_subnetwork.dagger-subnetwork](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_client_config.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alias_min_runners"></a> [alias\_min\_runners](#input\_alias\_min\_runners) | Minimum number of runners for alias scale sets (minor aliases like dagger-v0.19 and dagger-latest). When null (default), inherits the value of min\_runners. | `number` | `null` | no |
| <a name="input_arc_controller_values"></a> [arc\_controller\_values](#input\_arc\_controller\_values) | List of values in raw YAML format to pass to the ARC controller Helm chart. | `list(string)` | `[]` | no |
| <a name="input_arc_controller_version"></a> [arc\_controller\_version](#input\_arc\_controller\_version) | Version of the ARC scale set controller Helm chart. | `string` | `"0.10.1"` | no |
| <a name="input_arc_runners_namespace"></a> [arc\_runners\_namespace](#input\_arc\_runners\_namespace) | Namespace for the ARC runner pods. | `string` | `"arc-runners"` | no |
| <a name="input_arc_runners_version"></a> [arc\_runners\_version](#input\_arc\_runners\_version) | Version of the ARC runner scale set Helm chart. | `string` | `"0.10.1"` | no |
| <a name="input_arc_systems_namespace"></a> [arc\_systems\_namespace](#input\_arc\_systems\_namespace) | Namespace for the ARC operator pods. | `string` | `"arc-systems"` | no |
| <a name="input_cluster_autoscaling_profile"></a> [cluster\_autoscaling\_profile](#input\_cluster\_autoscaling\_profile) | Cluster autoscaler profile. Controls how aggressively the autoscaler<br/>scales down underutilized nodes.<br/><br/>  "BALANCED"              — Default. Conservative scale-down.<br/>  "OPTIMIZE\_UTILIZATION"  — Aggressive scale-down. Preferred for<br/>                            Spot/preemptible nodes and CI workloads.<br/>                            Reduces idle node costs and avoids<br/>                            PDB-related scale-down warnings from<br/>                            GKE system pods (kube-dns, etc.). | `string` | `"OPTIMIZE_UTILIZATION"` | no |
| <a name="input_cluster_suffix"></a> [cluster\_suffix](#input\_cluster\_suffix) | Suffix appended to the cluster name (e.g. 'dagger-runner-<suffix>'). | `string` | `"dagger"` | no |
| <a name="input_create_network"></a> [create\_network](#input\_create\_network) | When set to true, VPC will be auto created. | `bool` | `true` | no |
| <a name="input_dagger_cloud_token"></a> [dagger\_cloud\_token](#input\_dagger\_cloud\_token) | Optional Dagger Cloud token. Enables Magicache on the Dagger engine and injects DAGGER\_CLOUD\_TOKEN on runner pods. | `string` | `""` | no |
| <a name="input_dagger_engine_requests"></a> [dagger\_engine\_requests](#input\_dagger\_engine\_requests) | Resource requests for the Dagger engine pods. The engine bursts well above requests under parallel load (e.g. 2-3 cores with 30 runners), but the scheduler only needs modest requests for placement. Memory should be generous — the engine's BuildKit cache is memory-mapped. | <pre>object({<br/>    cpu    = optional(string, "250m")<br/>    memory = optional(string, "12Gi")<br/>  })</pre> | <pre>{<br/>  "cpu": "250m",<br/>  "memory": "12Gi"<br/>}</pre> | no |
| <a name="input_dagger_versions"></a> [dagger\_versions](#input\_dagger\_versions) | List of Dagger engine versions to deploy. Each version creates a separate runner scale set with label 'dagger-v<version>' (e.g. 'dagger-v0.19'). | `list(string)` | <pre>[<br/>  "0.19.5"<br/>]</pre> | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Whether to enable deletion protection on the GKE cluster. Set to true for production environments to prevent accidental destruction. | `bool` | `false` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Disk size in GB for runner nodes. | `number` | `100` | no |
| <a name="input_disk_type"></a> [disk\_type](#input\_disk\_type) | Disk type for runner nodes (pd-standard, pd-balanced, or pd-ssd). | `string` | `"pd-standard"` | no |
| <a name="input_enable_failed_pod_cleanup"></a> [enable\_failed\_pod\_cleanup](#input\_enable\_failed\_pod\_cleanup) | Deploy a CronJob that deletes Failed runner pods so ARC can recreate them. | `bool` | `true` | no |
| <a name="input_enable_private_nodes"></a> [enable\_private\_nodes](#input\_enable\_private\_nodes) | Whether nodes have internal IP addresses only. | `bool` | `false` | no |
| <a name="input_enable_vertical_pod_autoscaling"></a> [enable\_vertical\_pod\_autoscaling](#input\_enable\_vertical\_pod\_autoscaling) | Enable Vertical Pod Autoscaler on the cluster. When enabled, VPA objects are also created for the Dagger engine. | `bool` | `false` | no |
| <a name="input_engine_mode"></a> [engine\_mode](#input\_engine\_mode) | Dagger engine deployment mode. 'daemonset' = one engine per node with ephemeral hostPath cache. 'statefulset' = one engine per version with persistent PVC cache. | `string` | `"daemonset"` | no |
| <a name="input_failed_pod_cleanup_schedule"></a> [failed\_pod\_cleanup\_schedule](#input\_failed\_pod\_cleanup\_schedule) | Cron schedule for the failed pod cleanup job. | `string` | `"0 * * * *"` | no |
| <a name="input_gh_app_existing_secret_name"></a> [gh\_app\_existing\_secret\_name](#input\_gh\_app\_existing\_secret\_name) | Name of a pre-existing Kubernetes secret containing GitHub App credentials. When set, the module skips creating the secret and the gh\_app\_id/gh\_app\_installation\_id/gh\_app\_private\_key variables are ignored. The secret must exist in the runner namespace and contain keys: github\_app\_id, github\_app\_installation\_id, github\_app\_private\_key. | `string` | `""` | no |
| <a name="input_gh_app_id"></a> [gh\_app\_id](#input\_gh\_app\_id) | GitHub App ID for ARC authentication. Ignored when gh\_app\_existing\_secret\_name is set. | `string` | `""` | no |
| <a name="input_gh_app_installation_id"></a> [gh\_app\_installation\_id](#input\_gh\_app\_installation\_id) | GitHub App installation ID. Ignored when gh\_app\_existing\_secret\_name is set. | `string` | `""` | no |
| <a name="input_gh_app_pre_defined_secret_name"></a> [gh\_app\_pre\_defined\_secret\_name](#input\_gh\_app\_pre\_defined\_secret\_name) | Name for the Kubernetes secret when the module creates it. Ignored when gh\_app\_existing\_secret\_name is set. | `string` | `"gh-app-pre-defined-secret"` | no |
| <a name="input_gh_app_private_key"></a> [gh\_app\_private\_key](#input\_gh\_app\_private\_key) | GitHub App private key (.pem file contents). Ignored when gh\_app\_existing\_secret\_name is set. | `string` | `""` | no |
| <a name="input_gh_config_url"></a> [gh\_config\_url](#input\_gh\_config\_url) | URL of GitHub App config. For an organization: https://github.com/ORGANIZATION | `string` | n/a | yes |
| <a name="input_ip_range_pods_cidr"></a> [ip\_range\_pods\_cidr](#input\_ip\_range\_pods\_cidr) | The secondary IP range CIDR to use for pods. | `string` | `"192.168.0.0/18"` | no |
| <a name="input_ip_range_pods_name"></a> [ip\_range\_pods\_name](#input\_ip\_range\_pods\_name) | The secondary IP range to use for pods. | `string` | `"ip-range-pods"` | no |
| <a name="input_ip_range_services_cidr"></a> [ip\_range\_services\_cidr](#input\_ip\_range\_services\_cidr) | The secondary IP range CIDR to use for services. | `string` | `"192.168.64.0/18"` | no |
| <a name="input_ip_range_services_name"></a> [ip\_range\_services\_name](#input\_ip\_range\_services\_name) | The secondary IP range to use for services. | `string` | `"ip-range-svc"` | no |
| <a name="input_kubectl_image"></a> [kubectl\_image](#input\_kubectl\_image) | Container image providing kubectl. Used by the failed pod cleanup CronJob and the StatefulSet mode init container. Override to pin a specific version or use a private registry mirror. | `string` | `"bitnami/kubectl:latest"` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | Machine type for runner node pool. Dagger benefits from fast CPUs and large disks. | `string` | `"n2-standard-4"` | no |
| <a name="input_max_node_count"></a> [max\_node\_count](#input\_max\_node\_count) | Maximum number of nodes in the runner node pool. | `number` | `4` | no |
| <a name="input_max_runners"></a> [max\_runners](#input\_max\_runners) | Maximum number of runners per scale set. | `number` | `5` | no |
| <a name="input_min_node_count"></a> [min\_node\_count](#input\_min\_node\_count) | Minimum number of nodes in the runner node pool. Must be at least 1 — the ARC controller and listener pods require a node to receive GitHub job assignments. | `number` | `1` | no |
| <a name="input_min_runners"></a> [min\_runners](#input\_min\_runners) | Minimum number of runners per scale set. Set to 0 for scale-to-zero. | `number` | `0` | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | Name for the VPC network. | `string` | `"dagger-runner-network"` | no |
| <a name="input_persistent_cache_size"></a> [persistent\_cache\_size](#input\_persistent\_cache\_size) | Size of the persistent cache PVC per Dagger engine (StatefulSet mode only). | `string` | `"100Gi"` | no |
| <a name="input_persistent_cache_storage_class_name"></a> [persistent\_cache\_storage\_class\_name](#input\_persistent\_cache\_storage\_class\_name) | StorageClass for the persistent cache PVC (StatefulSet mode only).<br/>Must support ReadWriteOnce. The StorageClass controls the disk type:<br/><br/>  "standard-rwo"  → HDD (pd-standard) — cheapest, lower IOPS<br/>  "premium-rwo"   → SSD (pd-ssd)      — recommended for Dagger cache<br/><br/>SSD is recommended — Dagger builds are heavily I/O-bound, and SSD<br/>typically yields 2-5x faster cold builds compared to HDD.<br/><br/>Leave empty to use the cluster default StorageClass. | `string` | `""` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The project id to deploy the Dagger runner cluster. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The GCP region to deploy instances into. | `string` | `"us-central1"` | no |
| <a name="input_runner_image"></a> [runner\_image](#input\_runner\_image) | Container image for the GitHub Actions runner. Pin to a specific tag (e.g. '2.323.0') to avoid registry checks on every pod start and speed up scheduling. | `string` | `"ghcr.io/actions/actions-runner:latest"` | no |
| <a name="input_runner_size_templates"></a> [runner\_size\_templates](#input\_runner\_size\_templates) | Map of size template names to resource configurations for the runner pods.<br/>When defined, each runner label gets a size suffix (e.g. runs-on:<br/>dagger-v0.19-large) and the base unsuffixed labels are not created.<br/>Use an empty key "" for the default size (no suffix on labels).<br/><br/>When empty (default), runner sets are created without size suffixes and<br/>without resource constraints (pods get BestEffort QoS class). | <pre>map(object({<br/>    runner_requests = optional(map(string), {})<br/>    runner_limits   = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | Optional Service Account for the nodes. | `string` | `""` | no |
| <a name="input_spot"></a> [spot](#input\_spot) | Whether the underlying node VMs are Spot instances. | `bool` | `false` | no |
| <a name="input_subnet_ip"></a> [subnet\_ip](#input\_subnet\_ip) | IP range for the subnet. | `string` | `"10.0.0.0/17"` | no |
| <a name="input_subnet_name"></a> [subnet\_name](#input\_subnet\_name) | Name for the subnet. | `string` | `"dagger-runner-subnet"` | no |
| <a name="input_subnetwork_project"></a> [subnetwork\_project](#input\_subnetwork\_project) | The ID of the project in which the subnetwork belongs. If it is not provided, the project\_id is used. | `string` | `""` | no |
| <a name="input_vpa_update_mode"></a> [vpa\_update\_mode](#input\_vpa\_update\_mode) | VPA update mode for the Dagger engine. 'Off' = recommendation only, 'InPlaceOrRecreate' = auto-resize without restarting pods when possible (requires Kubernetes >= 1.33 with InPlacePodVerticalScaling feature gate enabled; GA in 1.35). | `string` | `"Off"` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | The GCP zones to deploy GKE into. | `list(string)` | <pre>[<br/>  "us-central1-a"<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ca_certificate"></a> [ca\_certificate](#output\_ca\_certificate) | The cluster CA certificate (base64 encoded). |
| <a name="output_client_token"></a> [client\_token](#output\_client\_token) | The bearer token for auth. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Cluster name. |
| <a name="output_kubernetes_endpoint"></a> [kubernetes\_endpoint](#output\_kubernetes\_endpoint) | The cluster endpoint. |
| <a name="output_location"></a> [location](#output\_location) | Cluster location. |
| <a name="output_network_name"></a> [network\_name](#output\_network\_name) | Name of VPC. |
| <a name="output_runner_labels"></a> [runner\_labels](#output\_runner\_labels) | Map of all runner scale set keys to their 'runs-on' labels. |
| <a name="output_service_account"></a> [service\_account](#output\_service\_account) | The default service account used for running nodes. |
| <a name="output_subnet_name"></a> [subnet\_name](#output\_subnet\_name) | Name of subnet. |
<!-- END_TF_DOCS -->
