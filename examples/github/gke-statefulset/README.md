# StatefulSet Dagger Runners on GKE

This example deploys Dagger runners on GKE using **StatefulSet mode** with persistent PVC cache. Ideal for Spot instances — the cache survives node preemptions.

## What Gets Created

| Resource | Details |
|----------|---------|
| GKE Cluster | `dagger-runner-dagger-sts`, autoscaling 1-4 Spot nodes (`n2-standard-4`) |
| ARC Controller | Helm chart in `arc-systems` namespace |
| Dagger Engine | StatefulSet (replicas=1) with 100 Gi PVC (`premium-rwo`) |
| Runner Scale Sets | Three labels (see below) in `arc-runners` namespace |
| RBAC | ServiceAccount + Role for `kube-pod://` protocol |

### How It Works

```
┌─────────────────────────────────────────────────────┐
│  GKE Cluster (Spot nodes)                           │
│                                                     │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐              │
│  │ Runner  │  │ Runner  │  │ Runner  │              │
│  │ Pod 1   │  │ Pod 2   │  │ Pod 3   │              │
│  └────┬────┘  └────┬────┘  └────┬────┘              │
│       │            │            │                   │
│       │    kube-pod:// protocol (K8s API exec)      │
│       │            │            │                   │
│  ┌────▼────────────▼────────────▼────┐              │
│  │  Dagger Engine (StatefulSet)      │              │
│  │  replicas=1                       │              │
│  └──────────────┬────────────────────┘              │
│                 │                                   │
│        ┌────────▼────────┐                          │
│        │  PVC 100Gi      │                          │
│        │  premium-rwo    │                          │
│        └─────────────────┘                          │
└─────────────────────────────────────────────────────┘
```

Runners connect to the engine via the Kubernetes API (`kube-pod://` protocol), not via a Unix socket. This means runners can be on any node — they don't need to be co-located with the engine.

When a Spot node is preempted, the engine pod reschedules on another node and reattaches its PVC. The warm cache is preserved.

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
    runs-on: dagger-v0.19
    steps:
      - uses: actions/checkout@v6
      - uses: dagger/dagger-for-github@v8
        with:
          version: "0.19"
          verb: call
          args: all --source=.
```

## Switching to DaemonSet Mode

If you don't need persistent cache (e.g. stable on-demand nodes), remove the StatefulSet variables to use the default DaemonSet mode:

```hcl
# engine_mode                         = "statefulset"   # remove
# persistent_cache_size               = "100Gi"         # remove
# persistent_cache_storage_class_name = "premium-rwo"   # remove
```
