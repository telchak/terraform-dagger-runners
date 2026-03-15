# Simple Dagger Runners on GKE

This example deploys a single Dagger engine version on GKE with ARC using the default DaemonSet mode (ephemeral hostPath cache).

## What Gets Created

| Resource | Details |
|----------|---------|
| GKE Cluster | `dagger-runner-dagger`, autoscaling 1-3 nodes (`n2-standard-4`) |
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

## Usage

```bash
terraform init

terraform plan \
  -var="project_id=my-project" \
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
