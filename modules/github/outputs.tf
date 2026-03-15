output "runner_labels" {
  description = "Map of all runner scale set keys to their 'runs-on' labels. Includes exact versions (dagger-v0.19.5), minor aliases (dagger-v0.19), and dagger-latest."
  value       = { for k, s in module.dagger-engine.runner_sets : k => s.label }
}
