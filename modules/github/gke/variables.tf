/*****************************************
  GCP Project & Region
 *****************************************/
variable "project_id" {
  type        = string
  description = "The project id to deploy the Dagger runner cluster."
}

variable "region" {
  type        = string
  description = "The GCP region to deploy instances into."
  default     = "us-central1"
}

variable "zones" {
  type        = list(string)
  description = "The GCP zones to deploy GKE into."
  default     = ["us-central1-a"]
}

variable "deletion_protection" {
  type        = bool
  description = "Whether to enable deletion protection on the GKE cluster. Set to true for production environments to prevent accidental destruction."
  default     = false
}

/*****************************************
  Network
 *****************************************/
variable "create_network" {
  type        = bool
  description = "When set to true, VPC will be auto created."
  default     = true
}

variable "network_name" {
  type        = string
  description = "Name for the VPC network."
  default     = "dagger-runner-network"
}

variable "subnet_name" {
  type        = string
  description = "Name for the subnet."
  default     = "dagger-runner-subnet"
}

variable "subnet_ip" {
  type        = string
  description = "IP range for the subnet."
  default     = "10.0.0.0/17"
}

variable "subnetwork_project" {
  type        = string
  description = "The ID of the project in which the subnetwork belongs. If it is not provided, the project_id is used."
  default     = ""
}

variable "ip_range_pods_name" {
  type        = string
  description = "The secondary IP range to use for pods."
  default     = "ip-range-pods"
}

variable "ip_range_pods_cidr" {
  type        = string
  description = "The secondary IP range CIDR to use for pods."
  default     = "192.168.0.0/18"
}

variable "ip_range_services_name" {
  type        = string
  description = "The secondary IP range to use for services."
  default     = "ip-range-svc"
}

variable "ip_range_services_cidr" {
  type        = string
  description = "The secondary IP range CIDR to use for services."
  default     = "192.168.64.0/18"
}

/*****************************************
  GKE Cluster
 *****************************************/
variable "cluster_suffix" {
  type        = string
  description = "Suffix appended to the cluster name (e.g. 'dagger-runner-<suffix>')."
  default     = "dagger"
}

variable "machine_type" {
  type        = string
  description = "Machine type for runner node pool. Dagger benefits from fast CPUs and large disks."
  default     = "n2-standard-4"
}

variable "disk_size_gb" {
  type        = number
  description = "Disk size in GB for runner nodes."
  default     = 100
}

variable "disk_type" {
  type        = string
  description = "Disk type for runner nodes (pd-standard, pd-balanced, or pd-ssd)."
  default     = "pd-standard"
}

variable "min_node_count" {
  type        = number
  description = "Minimum number of nodes in the runner node pool. Must be at least 1 — the ARC controller and listener pods require a node to receive GitHub job assignments."
  default     = 1
}

variable "max_node_count" {
  type        = number
  description = "Maximum number of nodes in the runner node pool."
  default     = 4
}

variable "enable_vertical_pod_autoscaling" {
  type        = bool
  description = "Enable Vertical Pod Autoscaler on the cluster. When enabled, VPA objects are also created for the Dagger engine."
  default     = false
}

variable "cluster_autoscaling_profile" {
  type        = string
  description = <<-EOT
    Cluster autoscaler profile. Controls how aggressively the autoscaler
    scales down underutilized nodes.

      "BALANCED"              — Default. Conservative scale-down.
      "OPTIMIZE_UTILIZATION"  — Aggressive scale-down. Preferred for
                                Spot/preemptible nodes and CI workloads.
                                Reduces idle node costs and avoids
                                PDB-related scale-down warnings from
                                GKE system pods (kube-dns, etc.).
  EOT
  default     = "OPTIMIZE_UTILIZATION"

  validation {
    condition     = contains(["BALANCED", "OPTIMIZE_UTILIZATION"], var.cluster_autoscaling_profile)
    error_message = "cluster_autoscaling_profile must be 'BALANCED' or 'OPTIMIZE_UTILIZATION'."
  }
}

variable "vpa_update_mode" {
  type        = string
  description = "VPA update mode for the Dagger engine. 'Off' = recommendation only, 'InPlaceOrRecreate' = auto-resize without restarting pods when possible (requires Kubernetes >= 1.33 with InPlacePodVerticalScaling feature gate enabled; GA in 1.35)."
  default     = "Off"

  validation {
    condition     = contains(["Off", "Initial", "Auto", "InPlaceOrRecreate"], var.vpa_update_mode)
    error_message = "vpa_update_mode must be one of: Off, Initial, Auto, InPlaceOrRecreate."
  }
}

variable "enable_private_nodes" {
  type        = bool
  description = "Whether nodes have internal IP addresses only."
  default     = false
}

variable "spot" {
  type        = bool
  description = "Whether the underlying node VMs are Spot instances."
  default     = false
}

variable "service_account" {
  type        = string
  description = "Optional Service Account for the nodes."
  default     = ""
}

/*****************************************
  GitHub App Authentication

  Two modes are supported:
  1. Module-managed secret (default): Pass gh_app_id, gh_app_installation_id,
     and gh_app_private_key — the module creates the Kubernetes secret.
  2. External secret: Set gh_app_existing_secret_name to the name of a
     pre-existing Kubernetes secret (e.g. managed by Vault, External Secrets
     Operator, or sealed-secrets). The credentials variables are ignored.
 *****************************************/
variable "gh_app_existing_secret_name" {
  type        = string
  description = "Name of a pre-existing Kubernetes secret containing GitHub App credentials. When set, the module skips creating the secret and the gh_app_id/gh_app_installation_id/gh_app_private_key variables are ignored. The secret must exist in the runner namespace and contain keys: github_app_id, github_app_installation_id, github_app_private_key."
  default     = ""

  validation {
    condition     = var.gh_app_existing_secret_name == "" || can(regex("^[a-z0-9][a-z0-9.-]*$", var.gh_app_existing_secret_name))
    error_message = "gh_app_existing_secret_name must be a valid Kubernetes secret name (lowercase alphanumeric, dashes, and dots)."
  }
}

variable "gh_app_id" {
  type        = string
  description = "GitHub App ID for ARC authentication. Ignored when gh_app_existing_secret_name is set."
  default     = ""
}

variable "gh_app_installation_id" {
  type        = string
  description = "GitHub App installation ID. Ignored when gh_app_existing_secret_name is set."
  default     = ""
}

variable "gh_app_private_key" {
  type        = string
  description = "GitHub App private key (.pem file contents). Ignored when gh_app_existing_secret_name is set."
  sensitive   = true
  default     = ""
}

variable "gh_app_pre_defined_secret_name" {
  type        = string
  description = "Name for the Kubernetes secret when the module creates it. Ignored when gh_app_existing_secret_name is set."
  default     = "gh-app-pre-defined-secret"
}

variable "gh_config_url" {
  type        = string
  description = "URL of GitHub App config. For an organization: https://github.com/ORGANIZATION"
}

/*****************************************
  ARC Controller & Runners
 *****************************************/
variable "arc_systems_namespace" {
  type        = string
  description = "Namespace for the ARC operator pods."
  default     = "arc-systems"
}

variable "arc_runners_namespace" {
  type        = string
  description = "Namespace for the ARC runner pods."
  default     = "arc-runners"
}

variable "arc_controller_version" {
  type        = string
  description = "Version of the ARC scale set controller Helm chart."
  default     = "0.10.1"
}

variable "arc_runners_version" {
  type        = string
  description = "Version of the ARC runner scale set Helm chart."
  default     = "0.10.1"
}

variable "arc_controller_values" {
  type        = list(string)
  description = "List of values in raw YAML format to pass to the ARC controller Helm chart."
  default     = []
}

variable "enable_failed_pod_cleanup" {
  type        = bool
  description = "Deploy a CronJob that deletes Failed runner pods so ARC can recreate them."
  default     = true
}

variable "failed_pod_cleanup_schedule" {
  type        = string
  description = "Cron schedule for the failed pod cleanup job."
  default     = "0 * * * *"
}

variable "kubectl_image" {
  type        = string
  description = "Container image providing kubectl. Used by the failed pod cleanup CronJob and the StatefulSet mode init container. Override to pin a specific version or use a private registry mirror."
  default     = "bitnami/kubectl:latest"
}

variable "runner_image" {
  type        = string
  description = "Container image for the GitHub Actions runner. Pin to a specific tag (e.g. '2.323.0') to avoid registry checks on every pod start and speed up scheduling."
  default     = "ghcr.io/actions/actions-runner:latest"
}

variable "min_runners" {
  type        = number
  description = "Minimum number of runners per scale set. Set to 0 for scale-to-zero."
  default     = 0
}

variable "alias_min_runners" {
  type        = number
  description = "Minimum number of runners for alias scale sets (minor aliases like dagger-v0.19 and dagger-latest). When null (default), inherits the value of min_runners."
  default     = null
}


variable "max_runners" {
  type        = number
  description = "Maximum number of runners per scale set."
  default     = 5
}

/*****************************************
  Dagger Configuration
 *****************************************/
variable "dagger_versions" {
  type        = list(string)
  description = "List of Dagger engine versions to deploy. Each version creates a separate runner scale set with label 'dagger-v<version>' (e.g. 'dagger-v0.19')."
  default     = ["0.19.5"]

  validation {
    condition     = length(var.dagger_versions) > 0
    error_message = "At least one Dagger version must be specified."
  }
}

variable "dagger_cloud_token" {
  type        = string
  description = "Optional Dagger Cloud token. Enables Magicache on the Dagger engine and injects DAGGER_CLOUD_TOKEN on runner pods."
  sensitive   = true
  default     = ""
}

variable "dagger_engine_requests" {
  type = object({
    cpu    = optional(string, "250m")
    memory = optional(string, "12Gi")
  })
  description = "Resource requests for the Dagger engine pods. The engine bursts well above requests under parallel load (e.g. 2-3 cores with 30 runners), but the scheduler only needs modest requests for placement. Memory should be generous — the engine's BuildKit cache is memory-mapped."
  default = {
    cpu    = "250m"
    memory = "12Gi"
  }
}

/*****************************************
  Engine Mode & Cache Strategy
 *****************************************/
variable "engine_mode" {
  type        = string
  description = "Dagger engine deployment mode. 'daemonset' = one engine per node with ephemeral hostPath cache. 'statefulset' = one engine per version with persistent PVC cache."
  default     = "daemonset"

  validation {
    condition     = contains(["daemonset", "statefulset"], var.engine_mode)
    error_message = "engine_mode must be 'daemonset' or 'statefulset'."
  }
}

variable "persistent_cache_size" {
  type        = string
  description = "Size of the persistent cache PVC per Dagger engine (StatefulSet mode only)."
  default     = "100Gi"
}

variable "persistent_cache_storage_class_name" {
  type        = string
  description = <<-EOT
    StorageClass for the persistent cache PVC (StatefulSet mode only).
    Must support ReadWriteOnce. The StorageClass controls the disk type:

      "standard-rwo"  → HDD (pd-standard) — cheapest, lower IOPS
      "premium-rwo"   → SSD (pd-ssd)      — recommended for Dagger cache

    SSD is recommended — Dagger builds are heavily I/O-bound, and SSD
    typically yields 2-5x faster cold builds compared to HDD.

    Leave empty to use the cluster default StorageClass.
  EOT
  default     = ""
}

/*****************************************
  Runner Size Templates
 *****************************************/
variable "runner_size_templates" {
  type = map(object({
    runner_requests = optional(map(string), {})
    runner_limits   = optional(map(string), {})
  }))
  description = <<-EOT
    Map of size template names to resource configurations for the runner pods.
    When defined, each runner label gets a size suffix (e.g. runs-on:
    dagger-v0.19-large) and the base unsuffixed labels are not created.
    Use an empty key "" for the default size (no suffix on labels).

    When empty (default), runner sets are created without size suffixes and
    without resource constraints (pods get BestEffort QoS class).
  EOT
  default     = {}
}
