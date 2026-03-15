terraform {
  required_version = ">= 1.3"
  required_providers {

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }

    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0"
    }
  }
}
