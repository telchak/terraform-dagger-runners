/*****************************************
  Kubernetes provider configuration

  Point the kubernetes, helm, and kubectl providers at your existing cluster.
  The simplest approach is kubeconfig + context name. Run `kubectl config
  get-contexts` to list available contexts.

  For alternatives (token, client certificate, exec-based auth) see:
    https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
 *****************************************/

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kubeconfig_context
  }
}

provider "kubectl" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context
}
