output "cluster_name" {
  description = "Cluster name."
  value       = module.dagger-runners.cluster_name
}

output "location" {
  description = "Cluster location."
  value       = module.dagger-runners.location
}

output "service_account" {
  description = "The default service account used for running nodes."
  value       = module.dagger-runners.service_account
}

output "runner_labels" {
  description = "Runner labels to use in 'runs-on'."
  value       = module.dagger-runners.runner_labels
}

output "project_id" {
  description = "The project in which resources are created."
  value       = var.project_id
}
