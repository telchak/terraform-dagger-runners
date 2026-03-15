variable "project_id" {
  type        = string
  description = "The GCP project ID."
}

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

variable "dagger_cloud_token" {
  type        = string
  description = "Dagger Cloud token for distributed caching and tracing."
  sensitive   = true
}
