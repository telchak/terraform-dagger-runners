/*****************************************
  Namespace
 *****************************************/
variable "namespace" {
  type        = string
  description = "Kubernetes namespace to deploy the Dagger engine into. Must already exist — this module does not create namespaces."
}

/*****************************************
  Dagger Configuration
 *****************************************/
variable "dagger_versions" {
  type        = list(string)
  description = "List of Dagger engine versions to deploy. Each version creates a separate runner set definition with label 'dagger-v<version>' (e.g. 'dagger-v0.19')."
  default     = ["0.19.5"]

  validation {
    condition     = length(var.dagger_versions) > 0
    error_message = "At least one Dagger version must be specified."
  }
}

variable "dagger_cloud_token" {
  type        = string
  description = "Optional Dagger Cloud token. Enables Magicache (distributed cache) on the Dagger engine and creates a Kubernetes secret for runner pods. Complements both DaemonSet and StatefulSet engine modes."
  sensitive   = true
  default     = ""
}

/*****************************************
  Dagger Engine Mode & Cache Strategy

  Strategy 1 — DaemonSet + hostPath (default):
    engine_mode = "daemonset"
    One engine per node, cache at /var/lib/dagger on the host.
    Ephemeral — cache is lost when the node is recycled.
    Runners connect via Unix socket (hostPath mount).

  Strategy 2 — StatefulSet + PVC:
    engine_mode = "statefulset"
    One engine per version (replicas=1), cache on a
    PersistentVolumeClaim managed by the Helm chart.
    Persistent — cache survives pod restarts and node changes.
    Runners connect via kube-pod:// protocol (Kubernetes API).
    Requires RBAC for runners (created automatically).

  Strategy 3 — Dagger Cloud (complementary):
    Set dagger_cloud_token to enable Magicache on the engine
    and DAGGER_CLOUD_TOKEN on runner pods. Works with either
    DaemonSet or StatefulSet mode. Provides distributed caching
    across clusters and pipeline tracing.
 *****************************************/
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

/*****************************************
  Persistent Cache (StatefulSet mode only)

  The StorageClass determines the underlying
  disk type (HDD vs SSD). Common options:

  GKE:
    "standard-rwo"  → HDD (pd-standard) — cheapest
    "premium-rwo"   → SSD (pd-ssd)      — recommended

  EKS:
    "gp3"           → SSD (General Purpose)
    "io2"           → SSD (Provisioned IOPS)

  AKS:
    "managed"          → HDD (Standard_LRS)
    "managed-premium"  → SSD (Premium_LRS)

  Leave empty to use the cluster default.
 *****************************************/
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

    Runner pods are lightweight — they only run the GitHub Actions runner
    process. The Dagger engine runs separately (as DaemonSet or StatefulSet)
    and is shared by all runners.

    Example:
      runner_size_templates = {
        "" = {
          runner_requests = { cpu = "100m", memory = "256Mi" }
          runner_limits   = {}
        }
        large = {
          runner_requests = { cpu = "500m", memory = "512Mi" }
          runner_limits   = { cpu = "1",    memory = "1Gi" }
        }
      }

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
