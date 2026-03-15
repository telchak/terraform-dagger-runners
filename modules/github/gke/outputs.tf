output "kubernetes_endpoint" {
  description = "The cluster endpoint."
  sensitive   = true
  value       = module.runner-cluster.endpoint
}

output "client_token" {
  description = "The bearer token for auth."
  sensitive   = true
  value       = base64encode(data.google_client_config.default.access_token)
}

output "ca_certificate" {
  description = "The cluster CA certificate (base64 encoded)."
  sensitive   = true
  value       = module.runner-cluster.ca_certificate
}

output "service_account" {
  description = "The default service account used for running nodes."
  value       = module.runner-cluster.service_account
}

output "cluster_name" {
  description = "Cluster name."
  value       = module.runner-cluster.name
}

output "network_name" {
  description = "Name of VPC."
  value       = local.network_name
}

output "subnet_name" {
  description = "Name of subnet."
  value       = local.subnet_name
}

output "location" {
  description = "Cluster location."
  value       = module.runner-cluster.location
}

output "runner_labels" {
  description = "Map of all runner scale set keys to their 'runs-on' labels."
  value       = module.dagger-runners.runner_labels
}
