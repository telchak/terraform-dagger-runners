/*****************************************
  Cluster targeting
 *****************************************/
variable "kubeconfig_path" {
  type        = string
  description = "Path to the kubeconfig file. Defaults to ~/.kube/config."
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  type        = string
  description = "Kubeconfig context to use. Run `kubectl config get-contexts` to list available contexts."
}

/*****************************************
  GitHub App credentials
 *****************************************/
variable "github_org" {
  type        = string
  description = "The GitHub organization name."
}

variable "gh_app_id" {
  type        = string
  description = "GitHub App ID."
}

variable "gh_app_installation_id" {
  type        = string
  description = "GitHub App installation ID."
}

variable "gh_app_private_key" {
  type        = string
  description = "GitHub App private key (.pem contents)."
  sensitive   = true
}
