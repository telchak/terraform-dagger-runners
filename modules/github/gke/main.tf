locals {
  network_name    = var.create_network ? google_compute_network.dagger-network[0].name : var.network_name
  subnet_name     = var.create_network ? google_compute_subnetwork.dagger-subnetwork[0].name : var.subnet_name
  service_account = var.service_account == "" ? "create" : var.service_account
}

/*****************************************
  Optional Network
 *****************************************/
resource "google_compute_network" "dagger-network" {
  count                   = var.create_network ? 1 : 0
  name                    = var.network_name
  project                 = var.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "dagger-subnetwork" {
  count         = var.create_network ? 1 : 0
  project       = var.project_id
  name          = var.subnet_name
  ip_cidr_range = var.subnet_ip
  region        = var.region
  network       = google_compute_network.dagger-network[0].name

  secondary_ip_range {
    range_name    = var.ip_range_pods_name
    ip_cidr_range = var.ip_range_pods_cidr
  }

  secondary_ip_range {
    range_name    = var.ip_range_services_name
    ip_cidr_range = var.ip_range_services_cidr
  }
}

/*****************************************
  Dagger Runner GKE Cluster
 *****************************************/
module "runner-cluster" {
  source                          = "terraform-google-modules/kubernetes-engine/google//modules/beta-public-cluster/"
  version                         = "~> 35.0"
  project_id                      = var.project_id
  name                            = "dagger-runner-${var.cluster_suffix}"
  regional                        = false
  region                          = var.region
  zones                           = var.zones
  network                         = local.network_name
  network_project_id              = var.subnetwork_project != "" ? var.subnetwork_project : var.project_id
  subnetwork                      = local.subnet_name
  ip_range_pods                   = var.ip_range_pods_name
  ip_range_services               = var.ip_range_services_name
  logging_service                 = "logging.googleapis.com/kubernetes"
  monitoring_service              = "monitoring.googleapis.com/kubernetes"
  remove_default_node_pool        = true
  service_account                 = local.service_account
  gce_pd_csi_driver               = true
  deletion_protection             = var.deletion_protection
  enable_vertical_pod_autoscaling = var.enable_vertical_pod_autoscaling

  cluster_autoscaling = {
    enabled             = false
    autoscaling_profile = var.cluster_autoscaling_profile
    min_cpu_cores       = 0
    max_cpu_cores       = 0
    min_memory_gb       = 0
    max_memory_gb       = 0
    gpu_resources       = []
    auto_repair         = true
    auto_upgrade        = true
  }
  node_pools = [
    {
      name                 = "dagger-pool"
      min_count            = var.min_node_count
      max_count            = var.max_node_count
      auto_upgrade         = true
      machine_type         = var.machine_type
      disk_size_gb         = var.disk_size_gb
      disk_type            = var.disk_type
      enable_private_nodes = var.enable_private_nodes
      spot                 = var.spot
    }
  ]
}

data "google_client_config" "default" {
}

/*****************************************
  GitHub Actions Runners + Dagger Engine
 *****************************************/
module "dagger-runners" {
  source = "./.."

  gh_app_existing_secret_name    = var.gh_app_existing_secret_name
  gh_app_id                      = var.gh_app_id
  gh_app_installation_id         = var.gh_app_installation_id
  gh_app_private_key             = var.gh_app_private_key
  gh_app_pre_defined_secret_name = var.gh_app_pre_defined_secret_name
  gh_config_url                  = var.gh_config_url

  arc_systems_namespace  = var.arc_systems_namespace
  arc_runners_namespace  = var.arc_runners_namespace
  arc_controller_version = var.arc_controller_version
  arc_runners_version    = var.arc_runners_version
  arc_controller_values  = var.arc_controller_values

  min_runners       = var.min_runners
  alias_min_runners = var.alias_min_runners
  max_runners       = var.max_runners
  kubectl_image     = var.kubectl_image
  runner_image      = var.runner_image

  dagger_versions        = var.dagger_versions
  dagger_cloud_token     = var.dagger_cloud_token
  dagger_engine_requests = var.dagger_engine_requests
  runner_size_templates  = var.runner_size_templates

  engine_mode                         = var.engine_mode
  persistent_cache_size               = var.persistent_cache_size
  persistent_cache_storage_class_name = var.persistent_cache_storage_class_name

  enable_vpa      = var.enable_vertical_pod_autoscaling
  vpa_update_mode = var.vpa_update_mode

  enable_failed_pod_cleanup   = var.enable_failed_pod_cleanup
  failed_pod_cleanup_schedule = var.failed_pod_cleanup_schedule
}
