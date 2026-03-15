# Contributing

Thank you for your interest in contributing to terraform-dagger-runners!

## Getting Started

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Submit a pull request

## Development Requirements

- [Terraform](https://www.terraform.io/downloads) >= 1.3
- [terraform-docs](https://terraform-docs.io/) for regenerating documentation
- [terraform-fmt](https://developer.hashicorp.com/terraform/cli/commands/fmt) for code formatting

## Code Style

- Run `terraform fmt -recursive` before committing
- Follow the existing module structure and naming conventions
- Mark sensitive variables with `sensitive = true`
- Add `validation` blocks for variables with constrained values
- Add descriptions to all variables and outputs

## Updating Documentation

The `README.md` files contain auto-generated sections between `<!-- BEGIN_TF_DOCS -->` and `<!-- END_TF_DOCS -->` markers. After changing variables, outputs, or providers, regenerate them:

```bash
terraform-docs markdown table --output-file README.md .
terraform-docs markdown table --output-file README.md modules/github/
terraform-docs markdown table --output-file README.md modules/github/gke/
```

## Testing

If your change affects the GKE module, verify with `terraform plan` against a GCP project:

```bash
cd examples/github/gke-simple
terraform init
terraform plan -var="project_id=your-project" -var="github_org=your-org" ...
```

For changes to the root or `modules/github/` module, use the existing-cluster example against any Kubernetes cluster:

```bash
cd examples/github/existing-cluster
terraform init
terraform plan -var="kubeconfig_context=your-context" -var="github_org=your-org" ...
```

## Pull Requests

- Keep PRs focused on a single change
- Update documentation if you change module interfaces
- Add a clear description of what the change does and why

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
