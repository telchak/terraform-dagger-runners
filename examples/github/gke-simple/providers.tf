/*****************************************
  Kubernetes provider configuration
 *****************************************/

data "google_client_config" "default" {
}

provider "kubernetes" {
  host                   = "https://${module.dagger-runners.kubernetes_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.dagger-runners.ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.dagger-runners.kubernetes_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.dagger-runners.ca_certificate)
  }
}

provider "kubectl" {
  host                   = "https://${module.dagger-runners.kubernetes_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.dagger-runners.ca_certificate)
  load_config_file       = false
}
