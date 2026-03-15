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
  Dagger Configuration (passed to root)
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
  description = "Optional Dagger Cloud token. Enables Magicache (distributed cache) on the Dagger engine and injects DAGGER_CLOUD_TOKEN on runner pods for pipeline visualization. Complements both DaemonSet and StatefulSet engine modes."
  sensitive   = true
  default     = ""
}

variable "engine_mode" {
  type        = string
  description = "Dagger engine deployment mode. 'daemonset' runs one engine per node with ephemeral hostPath cache. 'statefulset' runs one engine per version with persistent PVC cache."
  default     = "daemonset"

  validation {
    condition     = contains(["daemonset", "statefulset"], var.engine_mode)
    error_message = "engine_mode must be 'daemonset' or 'statefulset'."
  }
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

variable "persistent_cache_size" {
  type        = string
  description = "Size of the persistent cache PVC per Dagger engine. Only used when engine_mode = 'statefulset'. The Helm chart manages the PVC via volumeClaimTemplates."
  default     = "100Gi"
}

variable "persistent_cache_storage_class_name" {
  type        = string
  description = <<-EOT
    StorageClass name for the persistent cache PVC. Only used when
    engine_mode = 'statefulset'. Must support ReadWriteOnce access mode.

    The StorageClass determines the underlying disk type (HDD vs SSD).
    SSD is recommended for Dagger cache — build performance is heavily
    I/O-bound, and SSD typically yields 2-5x faster cold builds.

    Common StorageClass names by cloud provider:

      GKE:  "standard-rwo"  (HDD)  |  "premium-rwo"  (SSD) ← recommended
      EKS:  "gp3"           (SSD)  |  "io2"           (High-IOPS SSD)
      AKS:  "managed"       (HDD)  |  "managed-premium" (SSD)

    Leave empty to use the cluster default StorageClass.
  EOT
  default     = ""
}

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

/*****************************************
  VPA
 *****************************************/
variable "enable_vpa" {
  type        = bool
  description = "Create Vertical Pod Autoscaler objects for the Dagger engine. Requires VPA to be installed on the cluster (cloud-specific)."
  default     = false
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
