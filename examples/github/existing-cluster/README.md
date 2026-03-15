# Dagger Runners on an Existing Kubernetes Cluster

This example deploys Dagger engines and GitHub Actions runners (via ARC) on a **pre-existing** Kubernetes cluster — no cloud infrastructure is provisioned.

Use this when you already have a cluster (GKE, EKS, AKS, k3s, etc.) and want to add Dagger-powered self-hosted runners to it.

## What Gets Created

| Resource | Details |
|----------|---------|
| ARC Controller | Helm chart in `arc-systems` namespace |
| Dagger Engine | DaemonSet (one engine per node) in `arc-runners` namespace |
| Runner Scale Sets | Three labels (see below) in `arc-runners` namespace |

### Runner Labels

With `dagger_versions = ["0.19.5"]`, the module creates:

| Label | Engine | Use case |
|-------|--------|----------|
| `dagger-v0.19.5` | `registry.dagger.io/engine:v0.19.5` | Pinned, reproducible builds |
| `dagger-v0.19` | `registry.dagger.io/engine:v0.19.5` | Auto-patch on next deploy |
| `dagger-latest` | `registry.dagger.io/engine:v0.19.5` | Always newest |

## Targeting Your Cluster

The module itself is cluster-agnostic — it uses whichever `kubernetes`, `helm`, and `kubectl` providers the caller configures. This example uses kubeconfig:

```hcl
provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context
}
```

List your available contexts:

```bash
kubectl config get-contexts
```

### Other Authentication Methods

Instead of kubeconfig, you can configure the providers with explicit credentials:

```hcl
# GKE — token-based
provider "kubernetes" {
  host                   = "https://${google_container_cluster.my_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.my_cluster.master_auth[0].cluster_ca_certificate)
}

# EKS — exec-based
provider "kubernetes" {
  host                   = aws_eks_cluster.my_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.my_cluster.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.my_cluster.name]
  }
}
```

## Usage

```bash
terraform init

terraform plan \
  -var="kubeconfig_context=my-cluster-context" \
  -var="github_org=my-org" \
  -var="gh_app_id=123456" \
  -var="gh_app_installation_id=12345678" \
  -var="gh_app_private_key=$(cat github-app.pem)"

terraform apply
```

## Workflow Example

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: dagger-v0.19       # minor alias — always latest 0.19.x patch
    steps:
      - uses: actions/checkout@v6

      - name: Build and Test
        uses: dagger/dagger-for-github@v8
        with:
          version: "0.19"
          verb: call
          args: all --source=.
```
