# Multi-Version Dagger Runners on GKE

This example deploys multiple Dagger engine versions side-by-side on GKE, with StatefulSet mode for persistent cache, Dagger Cloud integration, and Spot instances for cost optimization.

## What Gets Created

| Resource | Details |
|----------|---------|
| GKE Cluster | `dagger-runner-dagger-multi`, autoscaling 1-6 Spot nodes (`n2-standard-8`) |
| ARC Controller | Helm chart in `arc-systems` namespace |
| Dagger Engines | StatefulSet per version (replicas=1), each with a 200 Gi PVC (`premium-rwo`) |
| Runner Scale Sets | Five labels (see below) in `arc-runners` namespace |
| RBAC | ServiceAccount + Role for `kube-pod://` protocol |
| Dagger Cloud | Magicache on engines + `DAGGER_CLOUD_TOKEN` on runners |

### Runner Labels

With `dagger_versions = ["0.18.7", "0.19.5"]`, the module creates:

| Label | Engine | Cache | Use case |
|-------|--------|-------|----------|
| `dagger-v0.18.7` | `engine:v0.18.7` | PVC (200 Gi) | Legacy repos pinned to 0.18 |
| `dagger-v0.18` | `engine:v0.18.7` | PVC (200 Gi) | Legacy repos, auto-patch |
| `dagger-v0.19.5` | `engine:v0.19.5` | PVC (200 Gi) | Migrated repos, pinned |
| `dagger-v0.19` | `engine:v0.19.5` | PVC (200 Gi) | Migrated repos, auto-patch |
| `dagger-latest` | `engine:v0.19.5` | PVC (200 Gi) | "Just use the newest" |

## Usage

```bash
terraform init

terraform plan \
  -var="project_id=my-project" \
  -var="github_org=my-org" \
  -var="gh_app_id=123456" \
  -var="gh_app_installation_id=12345678" \
  -var="gh_app_private_key=$(cat github-app.pem)" \
  -var="dagger_cloud_token=dag_..."

terraform apply
```

## Workflow Example

```yaml
jobs:
  build:
    runs-on: dagger-v0.19      # always latest 0.19.x patch
    steps:
      - uses: actions/checkout@v6
      - uses: dagger/dagger-for-github@v8
        with:
          version: "0.19"
          verb: call
          args: all --source=.
```
