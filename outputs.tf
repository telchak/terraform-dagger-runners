output "runner_sets" {
  description = "Map of runner set definitions. Each entry contains name, label, engine_image, engine_socket_path, engine_runner_host, is_alias, runner_requests, and runner_limits. CI platform modules iterate over this to create platform-specific runner scale sets."
  value       = local.runner_sets
}

output "engine_mode" {
  description = "The engine deployment mode (daemonset or statefulset). CI platform modules use this to configure runner pod templates."
  value       = var.engine_mode
}

output "dagger_runner_service_account_name" {
  description = "Name of the ServiceAccount for runner pods (StatefulSet mode only). Empty string when engine_mode is daemonset."
  value       = var.engine_mode == "statefulset" ? kubernetes_service_account.dagger_runner[0].metadata[0].name : ""
}

output "dagger_cloud_token_secret_name" {
  description = "Name of the Kubernetes secret containing the Dagger Cloud token. Empty string when no token is configured."
  value       = var.dagger_cloud_token != "" ? kubernetes_secret.dagger_cloud_token[0].metadata[0].name : ""
  sensitive   = true
}

output "namespace" {
  description = "The namespace the Dagger engine is deployed into."
  value       = var.namespace
}
