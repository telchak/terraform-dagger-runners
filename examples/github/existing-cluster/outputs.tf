output "runner_labels" {
  description = "Runner labels to use in 'runs-on'."
  value       = module.dagger-runners.runner_labels
}
