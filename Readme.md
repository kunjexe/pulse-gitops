# Pulse GitOps

Infrastructure and deployment configuration for the [Pulse platform](https://github.com/kunjexe/pulse-platform). This repo is the single source of truth for what's running in the cluster.

ArgoCD watches this repo. Push a change here and it gets deployed automatically. No `kubectl apply`, no SSH-ing into servers, no manual anything.

## How it works

The CI pipeline (Jenkins) builds new Docker images and updates the image tags in this repo. ArgoCD detects the change and rolls out the new version. If something breaks, `git revert` is your rollback.

```
Developer pushes code to pulse-platform
    → Jenkins runs tests, builds image, pushes to registry
    → Jenkins updates image tag in this repo
    → ArgoCD detects the change
    → ArgoCD deploys to Kubernetes
    → Done
```

## What's in here

### Helm Charts (`helm-charts/`)

One chart per service. Each chart defines a Deployment, Service, and optional HPA + ServiceMonitor. Configuration lives in `values.yaml` — replica counts, resource limits, environment variables, health check paths.

```
helm-charts/
├── api-gateway/          # Port 3000, proxies to all services
├── user-service/         # Port 8001, Vault sidecar for DB creds
├── post-service/         # Port 8002, Vault sidecar for DB creds
├── feed-service/         # Port 8003, Vault sidecar for Redis URL
├── notification-service/ # Port 8005, Vault sidecar for DB creds
└── media-service/        # Port 8004, no Vault (no secrets needed)
```

To change the replica count for user-service, edit `helm-charts/user-service/values.yaml`:

```yaml
replicaCount: 3  # was 2
```

Commit, push, and ArgoCD handles the rest.

### Terraform (`terraform/`)

AWS infrastructure defined as code. Four modules that compose into environment-specific configurations.

```
terraform/
├── modules/
│   ├── networking/    # VPC, subnets, NAT gateway, route tables
│   ├── eks/           # EKS cluster, node groups, OIDC for IRSA
│   ├── databases/     # RDS Postgres, ElastiCache Redis
│   └── storage/       # S3 buckets, ECR repositories
└── environments/
    ├── dev/           # 2 nodes, db.t3.micro, single-AZ
    └── prod/          # Multi-AZ, larger instances, backups
```

Spin up the dev environment:

```bash
cd terraform/environments/dev
terraform init
terraform plan -var="db_password=<password>"
terraform apply -var="db_password=<password>"
```

### ArgoCD Applications (`argocd/`)

Application manifests that tell ArgoCD what to watch. Each service gets its own Application resource pointing to its Helm chart in this repo.

All apps are configured with:
- **Auto-sync** — deploys on every push
- **Self-heal** — reverts manual `kubectl` changes
- **Auto-prune** — removes resources deleted from Git

## Vault integration

Five of the six services run with a Vault agent sidecar that injects secrets at startup. Secrets are stored at `secret/data/pulse/<service-name>` in Vault. Each service has its own Kubernetes service account and Vault policy with read-only access to its own secrets.

The media-service runs without Vault since it doesn't handle sensitive credentials.

## Local development

For local development, use the `docker-compose.yml` in the [pulse-platform](https://github.com/kunjexe/pulse-platform) repo instead. This repo is for Kubernetes deployments only.

## Related

- [pulse-platform](https://github.com/kunjexe/pulse-platform) — Application source code, Dockerfiles, docker-compose