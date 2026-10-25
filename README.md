# ⚡ CloudForge

> **Production-Grade DevSecOps & Platform Engineering Blueprint for AWS & Kubernetes (EKS)**  
> *Go from Zero to Production in 15 minutes with declarative IaC, automated GitOps CI/CD, DevSecOps security gates, native self-healing, and end-to-end observability.*

---

[![Terraform](https://img.shields.io/badge/Terraform-1.9.0-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS%20v1.30-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/eks/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.30-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo&logoColor=white)](https://argoproj.github.io/cd/)
[![Security](https://img.shields.io/badge/Security-Trivy%20%7C%20tfsec%20%7C%20CIS-success)](https://trivy.dev/)
[![Observability](https://img.shields.io/badge/Monitoring-Prometheus%20%7C%20Grafana-F46800?logo=prometheus&logoColor=white)](https://prometheus.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 📌 Architecture Overview

CloudForge provisions an enterprise-ready, multi-AZ AWS cloud topology following AWS Well-Architected and CIS Kubernetes benchmarks.

```text
                                         AWS REGION (ap-south-1)
 ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │  VPC (10.0.0.0/16)                                                                                          │
 │                                                                                                             │
 │    ┌─────────────────────────── AZ-1 (ap-south-1a) ───────────────────────────┐                             │
 │    │  PUBLIC SUBNET (10.0.1.0/24)                                             │                             │
 │    │  ┌───────────────────────┐         ┌─────────────────────────────────┐   │                             │
 │    │  │  NAT Gateway (EIP)    │         │  AWS ALB (Ingress Controller)   │   │                             │
 │    │  └───────────┬───────────┘         └────────────────┬────────────────┘   │                             │
 │    │              │                                      │                    │                             │
 │    │  PRIVATE SUBNET (10.0.10.0/24)                      │                    │                             │
 │    │  ┌──────────────────────────────────────────────────┴─────────────────┐  │                             │
 │    │  │  EKS Managed Node Group (Worker Nodes)                             │  │                             │
 │    │  │  ┌──────────────────────────────────────────────────────────────┐  │  │                             │
 │    │  │  │ Pod (Sample Microservice)                                    │  │  │                             │
 │    │  │  │  - Liveness & Readiness Probes (/healthz)                    │  │  │                             │
 │    │  │  │  - HPA Auto-scaler (2 -> 10 Pods on CPU > 70%)               │  │  │                             │
 │    │  │  │  - Argo Rollouts Canary (10% -> 30% -> 60% -> 100%)          │  │  │                             │
 │    │  │  └──────────────────────────────┬───────────────────────────────┘  │  │                             │
 │    │  │                                 │ Port 5432 (SG Chained)            │  │                             │
 │    │  └─────────────────────────────────┼──────────────────────────────────┘  │                             │
 │    │                                    │                                     │                             │
 │    │  ISOLATED SUBNET (10.0.100.0/24)   │                                     │                             │
 │    │  ┌─────────────────────────────────▼──────────────────────────────────┐  │                             │
 │    │  │  Amazon RDS PostgreSQL (db.t3.medium / Multi-AZ ready)             │  │                             │
 │    │  │  - Zero Internet Route | Encrypted gp3 | prevent_destroy           │  │                             │
 │    │  └────────────────────────────────────────────────────────────────────┘  │                             │
 │    └──────────────────────────────────────────────────────────────────────────┘                             │
 │                                                                                                             │
 │    ┌─────────────────────────── AZ-2 (ap-south-1b) ───────────────────────────┐                             │
 │    │  PUBLIC SUBNET (10.0.2.0/24)         PRIVATE SUBNET (10.0.20.0/24)       │  ISOLATED (10.0.200.0/24)   │
 │    │  ┌─────────────────────────┐         ┌───────────────────────────────┐   │  ┌────────────────────────┐ │
 │    │  │ Bastion Host (Jumpbox)  │         │ EKS Node Group (Redundancy)   │   │  │ RDS Standby (Multi-AZ) │ │
 │    │  │ - CIS Hardened / UFW    │         │                               │   │  │                        │ │
 │    │  └─────────────────────────┘         └───────────────────────────────┘   │  └────────────────────────┘ │
 │    └──────────────────────────────────────────────────────────────────────────┘                             │
 │                                                                                                             │
 │    ┌──────────────────────────────────────────────────────────────────────────────────────────────────┐     │
 │    │ S3 Gateway VPC Endpoint (Direct, zero-cost, high-speed private routing to AWS S3)                 │     │
 │    └──────────────────────────────────────────────────────────────────────────────────────────────────┘     │
 └─────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                               ▲                                                     ▲
                               │ Push Docker Image                                   │ Sync GitOps Manifests
 ┌─────────────────────────────┴─────────────────┐            ┌──────────────────────┴────────────────────────┐
 │ DevSecOps CI Pipeline (GitHub Actions)        │            │ GitOps Continuous Delivery (ArgoCD)           │
 │  1. Python/Node Lint & Pytest                 │            │  1. App-of-Apps Pattern                       │
 │  2. Trivy Container CVE Scan (Blocks Critical)│            │  2. AWS LB Controller & Cert-Manager Addons   │
 │  3. Docker Build & Push to Amazon ECR         │            │  3. Argo Rollouts Automated Canary Analysis   │
 │  4. Automated Git Commit (Helm tag update)    │            │  4. Self-Healing Drift Detection & Auto-Sync  │
 └───────────────────────────────────────────────┘            └───────────────────────────────────────────────┘
```

---

## ✨ Key Platform Features

| Capability | Implementation | Production Value |
| :--- | :--- | :--- |
| **Modular IaC** | Terraform 1.9+ (`aws ~> 5.0`) | Reusable modules for VPC, EKS, RDS, Bastion with dev & prod environment parity. |
| **Zero-Trust Network** | 6 Subnets across 2 AZs | Strict tier separation (Public, Private, Isolated). RDS has zero route to internet. |
| **Kubernetes Engine** | AWS EKS v1.30 | Managed node groups, IRSA (IAM Roles for Service Accounts), VPC-CNI, EBS CSI. |
| **Security Group Chaining**| RDS Security Group | Database port 5432 strictly rejects all traffic except from the EKS Node Security Group. |
| **OS Security Hardening** | Ansible CIS Benchmark | Bastion Jumpbox enforced with key-only SSH, root disabled, UFW, and audit logging. |
| **DevSecOps Pipeline** | GitHub Actions + Trivy | Static testing, container vulnerability blocking (CRITICAL/HIGH), automated GitOps tag updates. |
| **Declarative GitOps** | ArgoCD App-of-Apps | Continuous automated reconciliation, drift detection, self-healing, and wave-ordered addons. |
| **Progressive Delivery** | Argo Rollouts Canary | Automated canary progression (10% → 30% → 60% → 100%) with auto-rollback on >1% 5xx errors. |
| **Native Self-Healing** | Kubernetes Probes & HPA | HTTP `/healthz` liveness/readiness probes + dynamic horizontal scaling (2–10 pods on CPU > 70%). |
| **Observability (LGTM)** | Prometheus + Grafana | Pre-configured Google SRE Golden Signals dashboard (Latency, Traffic, Errors, Saturation). |

---

## 📁 Repository Directory Structure

```text
cloudforge/
├── .github/
│   └── workflows/
│       ├── ci-pipeline.yaml              # DevSecOps CI: Test, Trivy CVE scan, Docker build, ECR push, GitOps update
│       └── terraform-checks.yaml         # IaC CI: fmt check, terraform validate, TFLint, and tfsec security scan
├── terraform/
│   ├── backend.tf                        # S3 bucket + DynamoDB distributed state locking
│   ├── environments/
│   │   ├── dev/                          # Development environment configuration (t3.medium, single-AZ RDS)
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── terraform.tfvars.example
│   │   └── prod/                         # Production environment configuration (t3.xlarge, Multi-AZ RDS)
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── terraform.tfvars.example
│   └── modules/
│       ├── vpc/                          # 6 Subnets, IGW, NAT GW, Route Tables, S3 Gateway Endpoint
│       ├── eks/                          # EKS v1.30, OIDC IRSA, Auto-scaling Node Groups, EKS Addons
│       ├── rds/                          # PostgreSQL 16, isolated subnet group, SG chaining, Secrets Manager
│       └── bastion/                      # Secure Admin Jumpbox in public subnet, IMDSv2 enforced
├── ansible/
│   ├── ansible.cfg                       # Fast SSH pipelining and host key verification settings
│   ├── inventories/
│   │   └── hosts.ini                     # Bastion host target inventory
│   ├── playbooks/
│   │   └── harden-bastion.yaml           # Jumpbox hardening playbook
│   └── roles/
│       └── security_hardening/           # CIS benchmark tasks: SSH, UFW, auditd, install kubectl/helm/awscli
├── gitops/
│   ├── apps/
│   │   └── sample-microservice/          # Production 2-tier application Helm chart
│   │       ├── Chart.yaml
│   │       ├── values.yaml               # Configurable resource limits, probes, autoscaling, canary steps
│   │       └── templates/
│   │           ├── deployment.yaml       # Native self-healing probes, readOnlyRootFilesystem, anti-affinity
│   │           ├── service.yaml          # ClusterIP service
│   │           ├── hpa.yaml              # Horizontal Pod Autoscaler (CPU > 70%, Min: 2, Max: 10)
│   │           ├── ingress.yaml          # AWS ALB Ingress with TLS annotations
│   │           ├── rollout.yaml          # Argo Rollouts Canary with Prometheus metric analysis
│   │           └── pdb.yaml              # Pod Disruption Budget
│   └── argocd/
│       ├── root-application.yaml         # GitOps App-of-Apps master controller
│       └── addons-app.yaml               # Cluster Addons: AWS Load Balancer Controller & Cert-Manager
├── observability/
│   ├── prometheus/
│   │   └── alert-rules.yaml              # SRE alert rules: PodCrashLoop, HighLatency, TargetUnhealthy, OOM
│   ├── grafana/
│   │   └── golden-signals-dashboard.json # Pre-built dashboard for Latency, Traffic, Errors, Saturation
│   └── alertmanager/
│       └── alertmanager-config.yaml      # Notification routing to Slack / Telegram
├── automation/
│   ├── bootstrap.sh                      # 1-Click interactive setup engine
│   └── destroy.sh                        # 1-Click clean up script to avoid idle AWS cloud billing
├── Makefile                              # Unified Developer CLI (make infra-up, make gitops-init, etc.)
├── app-config.yaml                       # 10-line developer onboarding interface
└── README.md                             # Comprehensive technical blueprint documentation
```

---

## 🚀 Quick Start: Zero to Production in 15 Minutes

### Step 0: Prerequisites Check
Ensure you have the following installed locally:
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) (configured with admin credentials: `aws configure`)
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) (>= 1.5.0)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (>= 1.30.0)
- [Helm v3](https://helm.sh/docs/intro/install/) (>= 3.14.0)

---

### Step 1: Automated 1-Click Bootstrap
Execute the interactive bootstrap wizard:

```bash
chmod +x automation/bootstrap.sh automation/destroy.sh
./automation/bootstrap.sh
```

The script will:
1. Verify toolchain dependencies and AWS caller identity.
2. Prompt for environment (`dev` or `prod`) and region.
3. Execute `terraform init` and `terraform apply`.
4. Update local `kubeconfig` to point to the new EKS cluster.
5. Deploy the ArgoCD GitOps engine and register the Root App-of-Apps.
6. Apply Prometheus alerting rules and observability dashboards.

---

### Step 2: Alternatively, Step-by-Step via Developer CLI (`Makefile`)

If you prefer granular control, run each phase via `make`:

```bash
# 1. Initialize & provision infrastructure
make infra-init ENV=dev
make infra-plan ENV=dev
make infra-up   ENV=dev

# 2. Secure and harden the Bastion host
# Update ansible/inventories/hosts.ini with the Bastion IP from terraform output
make bastion-harden

# 3. Bootstrap GitOps (ArgoCD & App-of-Apps)
make gitops-init

# 4. Run local DevSecOps quality tests
make test
```

---

## 👩‍💻 Developer Interface: Onboarding an Application

CloudForge provides a minimalist 10-line abstraction (`app-config.yaml`) allowing developers to deploy microservices without deep Kubernetes knowledge:

```yaml
app:
  name: "order-service"
  namespace: "production"
  image:
    repository: "123456789012.dkr.ecr.ap-south-1.amazonaws.com/order-service"
    tag: "v1.2.0"
  replicas:
    min: 2
    max: 10
  port: 8080
  healthcheck: "/healthz"
  resources:
    cpu: "256m"
    memory: "512Mi"
  ingress:
    enabled: true
    host: "api.orders.yourdomain.com"
    tls: true
  database:
    enabled: true
    engine: "postgresql"
```

Once updated, commit changes to your Git repository. ArgoCD detects the change and synchronizes your progressive rollout automatically.

---

## 🛡️ Security Architecture & DevSecOps Gates

### 1. Zero-Trust Network Isolation
- **No Direct RDS Access:** RDS is placed inside `Isolated Subnets` with no default internet gateway or NAT route.
- **Security Group Chaining:** Port 5432 ingress rule is tied strictly to the `sg_id` of the EKS Worker Nodes. Even if an attacker enters the public subnet, the database remains completely unreachable.

### 2. CI/CD DevSecOps Pipeline
Every pull request and push to `main` undergoes automated vulnerability inspection:
- **Linting & Unit Tests:** Python/Node syntax checks and unit tests.
- **Trivy Container Scan:** Container images are inspected for OS and library CVEs. Any `CRITICAL` vulnerability **blocks the build**.
- **SARIF Upload:** Scan results are uploaded to the GitHub Security tab for real-time compliance tracking.
- **Automated GitOps Tag Synchronization:** The commit SHA is stamped into `values.yaml` and committed via bot, closing the loop between CI and CD.

### 3. CIS Hardened Bastion Host
The Bastion jumpbox is locked down using an automated Ansible role:
- SSH passwords disabled; public-key authentication enforced.
- Root login disabled (`PermitRootLogin no`).
- UFW firewall enabled; incoming connections dropped by default.
- Kernel audit logging (`auditd`) enabled for sensitive file monitoring (`/etc/ssh/sshd_config`, `/etc/sudoers`).
- Unused filesystems (`cramfs`, `freevxfs`, `hfs`) disabled at kernel level.

---

## 📈 Observability & SRE Golden Signals

CloudForge includes pre-built Prometheus rules and a Grafana dashboard monitoring the **Four Golden Signals**:

1. **Latency:** p50, p90, and p99 percentile HTTP request response durations.
2. **Traffic:** Total request throughput per second across services.
3. **Errors:** HTTP 5xx error percentage vs total requests (Alert triggers when > 1%).
4. **Saturation:** Real-time CPU and Memory utilization against container limits.

### SRE Alert Rules Included:
- `PodCrashLooping`: Pod restarts > 5 in a 10-minute window.
- `PodNotReady`: Pod stuck in non-running state for > 5 minutes.
- `ContainerOOMKilled`: Pod terminated due to memory saturation.
- `HighNodeCPU` & `HighNodeMemory`: Node utilization > 85% / 90%.
- `HighLatencyP99`: Service latency > 1.0s for 5 minutes.
- `HighErrorRate`: 5xx error rate > 1% (triggers automated canary rollback).

---

## 🧹 Clean Up & Cloud Cost Prevention

When you are done testing or want to prevent ongoing AWS billing, execute the 1-click teardown script:

```bash
make destroy
# or run directly:
./automation/destroy.sh
```

> **Important:** The teardown script safely deletes Kubernetes Ingress and Load Balancer objects **before** initiating Terraform destruction. This prevents orphaned AWS ALBs from blocking VPC deletion and incurring unexpected cloud charges.

---

## 📜 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
