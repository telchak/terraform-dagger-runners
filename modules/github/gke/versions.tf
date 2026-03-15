terraform {
  required_version = ">= 1.3"
  required_providers {

    google = {
      source  = "hashicorp/google"
      version = ">= 5.0, < 8"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0, < 8"
    }

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
