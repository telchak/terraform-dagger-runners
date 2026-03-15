module "dagger-runners" {
  source = "../../../modules/github"

  # GitHub App authentication — required for ARC.
  # See https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/authenticating-to-the-github-api
  gh_app_id              = var.gh_app_id
  gh_app_installation_id = var.gh_app_installation_id
  gh_app_private_key     = var.gh_app_private_key
  gh_config_url          = "https://github.com/${var.github_org}"

  # Deploys a single Dagger engine version.
  # The module automatically creates three runner labels:
  #   - runs-on: dagger-v0.19.5   (exact version)
  #   - runs-on: dagger-v0.19     (minor alias, points to 0.19.5)
  #   - runs-on: dagger-latest    (latest version, points to 0.19.5)
  dagger_versions = ["0.19.5"]

  # Runner scale-to-zero — no idle runners when there are no pending jobs.
  min_runners = 0
  max_runners = 5

  # DaemonSet mode (default): one engine per node, ephemeral hostPath cache.
  # Cache persists across jobs on the same node but is lost on node recycle.
  # engine_mode = "daemonset"
}
