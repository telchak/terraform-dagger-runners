# Dagger Cloud Runners on GKE

This example deploys Dagger runners on GKE using **DaemonSet mode** with **Dagger Cloud** for distributed caching and pipeline visualization.

## What Gets Created

| Resource | Details |
|----------|---------|
| GKE Cluster | `dagger-runner-dagger-cloud`, autoscaling 1-4 nodes (`n2-standard-4`) |
| ARC Controller | Helm chart in `arc-systems` namespace |
| Dagger Engine | DaemonSet (one per node) with Magicache enabled |
| Runner Scale Sets | Three labels in `arc-runners` namespace |
| Dagger Cloud Secret | `DAGGER_CLOUD_TOKEN` injected on runner pods |

### How It Works

```
┌──────────────── Node A ─────────────┐       ┌──────────────────────┐
│                                     │       │  Dagger Cloud        │
│  ┌─────────┐  ┌─────────┐           │       │                      │
│  │ Runner  │  │ Runner  │           │       │  ┌────────────────┐  │
│  │ Pod 1   │  │ Pod 2   │           │       │  │  Magicache     │  │
│  │ DAGGER_ │  │ DAGGER_ │           │       │  │  (distributed  │  │
│  │ CLOUD_  │  │ CLOUD_  │           │       │  │   cache)       │  │
│  │ TOKEN   │  │ TOKEN   │           │       │  └───────▲────────┘  │
│  └────┬────┘  └────┬────┘           │       │          │           │
│       │ Unix       │ socket         │       │  ┌───────┴────────┐  │
│  ┌────▼────────────▼────┐           │       │  │  Traces UI     │  │
│  │  Dagger Engine       │───────────┼───────┤  └────────────────┘  │
│  │  (DaemonSet)         │  HTTP     │       │                      │
│  │  magicache: enabled  │           │       └──────────────────────┘
│  │                      │           │
│  │  /var/lib/dagger ────┼── local   │
│  │  (hostPath)     cache│           │
│  └──────────────────────┘           │
└─────────────────────────────────────┘
```

The DaemonSet provides fast node-local cache via hostPath. Dagger Cloud's Magicache adds a distributed cache layer on top — when a local cache miss occurs, the engine checks Magicache before rebuilding. This gives you:

- **Fast local hits** — node-local hostPath cache for repeated builds on the same node
- **Cross-node sharing** — Magicache fills the gap when a job lands on a different node
- **Cross-cluster sharing** — multiple clusters share the same Magicache
- **Pipeline traces** — debug and optimize builds in the Dagger Cloud UI

### Runner Labels

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
  -var="gh_app_private_key=$(cat github-app.pem)" \
  -var="dagger_cloud_token=dag_..."

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
    runs-on: dagger-v0.19
    steps:
      - uses: actions/checkout@v6

      # DAGGER_CLOUD_TOKEN is already injected by the module.
      # Traces appear automatically in the Dagger Cloud UI.
      - uses: dagger/dagger-for-github@v8
        with:
          version: "0.19"
          verb: call
          args: all --source=.
```

## Adding Persistent Cache

For maximum cache efficiency, combine Dagger Cloud with StatefulSet mode:

```hcl
engine_mode                         = "statefulset"
persistent_cache_size               = "100Gi"
persistent_cache_storage_class_name = "premium-rwo"
dagger_cloud_token                  = var.dagger_cloud_token
```

This gives you persistent local cache (PVC) + distributed cache (Magicache).
