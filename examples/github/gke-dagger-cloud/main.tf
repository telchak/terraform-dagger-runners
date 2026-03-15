module "dagger-runners" {
  source = "../../../modules/github/gke"

  project_id     = var.project_id
  region         = "us-central1"
  create_network = true
  cluster_suffix = "dagger-cloud"
  machine_type   = "n2-standard-4"
  min_node_count = 1
  max_node_count = 4

  # GitHub App authentication — required for ARC.
  gh_app_id              = var.gh_app_id
  gh_app_installation_id = var.gh_app_installation_id
  gh_app_private_key     = var.gh_app_private_key
  gh_config_url          = "https://github.com/${var.github_org}"

  dagger_versions = ["0.19.5"]
  min_runners     = 0
  max_runners     = 5

  # DaemonSet mode (default): ephemeral hostPath cache per node.
  # engine_mode = "daemonset"

  # Dagger Cloud: distributed caching + pipeline visualization.
  # Magicache is enabled on the engine — build layers, volumes, and
  # function results are cached in Dagger Cloud and shared across
  # all nodes and clusters. Pipeline traces appear in the Dagger
  # Cloud UI for debugging and performance analysis.
  dagger_cloud_token = var.dagger_cloud_token
}
