module "dagger-runners" {
  source = "../../../modules/github/gke"

  project_id     = var.project_id
  region         = "us-central1"
  create_network = true
  cluster_suffix = "dagger-multi"
  machine_type   = "n2-standard-8"
  disk_size_gb   = 200
  min_node_count = 1
  max_node_count = 6
  spot           = true

  # GitHub App authentication — required for ARC.
  gh_app_id              = var.gh_app_id
  gh_app_installation_id = var.gh_app_installation_id
  gh_app_private_key     = var.gh_app_private_key
  gh_config_url          = "https://github.com/${var.github_org}"

  # Deploy two Dagger engine versions side-by-side.
  #
  # This creates five runner scale sets (exact + alias labels):
  #   - runs-on: dagger-v0.18.7  (exact, engine v0.18.7)
  #   - runs-on: dagger-v0.18    (minor alias -> engine v0.18.7)
  #   - runs-on: dagger-v0.19.5  (exact, engine v0.19.5)
  #   - runs-on: dagger-v0.19    (minor alias -> engine v0.19.5)
  #   - runs-on: dagger-latest   (always the newest -> engine v0.19.5)
  dagger_versions = ["0.18.7", "0.19.5"]

  min_runners = 0
  max_runners = 5

  # StatefulSet mode: persistent PVC cache per engine version.
  # Cache survives pod restarts and node changes.
  # Runners connect via kube-pod:// protocol (RBAC created automatically).
  engine_mode                         = "statefulset"
  persistent_cache_size               = "200Gi"
  persistent_cache_storage_class_name = "premium-rwo"

  # Dagger Cloud for distributed caching and pipeline visualization.
  # Complements the local PVC cache — PVC for fast local access,
  # Dagger Cloud for cross-cluster sharing and traces.
  dagger_cloud_token = var.dagger_cloud_token
}
