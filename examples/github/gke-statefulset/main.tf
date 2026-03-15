module "dagger-runners" {
  source = "../../../modules/github/gke"

  project_id     = var.project_id
  region         = "us-central1"
  create_network = true
  cluster_suffix = "dagger-sts"
  machine_type   = "n2-standard-4"
  disk_size_gb   = 100
  min_node_count = 1
  max_node_count = 4
  spot           = true # Safe with StatefulSet — cache is on PVC, not the node.

  # GitHub App authentication — required for ARC.
  gh_app_id              = var.gh_app_id
  gh_app_installation_id = var.gh_app_installation_id
  gh_app_private_key     = var.gh_app_private_key
  gh_config_url          = "https://github.com/${var.github_org}"

  dagger_versions = ["0.19.5"]
  min_runners     = 0
  max_runners     = 5

  # StatefulSet mode: persistent PVC cache per engine version.
  # The Helm chart creates the PVC via volumeClaimTemplates.
  # Cache survives pod restarts, node preemptions, and scale-downs.
  # Runners connect via kube-pod:// protocol (RBAC created automatically).
  engine_mode                         = "statefulset"
  persistent_cache_size               = "100Gi"
  persistent_cache_storage_class_name = "premium-rwo" # GKE SSD-backed PD
}
