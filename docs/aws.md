# AWS Architecture

## Purpose

Deploy a full-stack application to AWS using a cost-optimized DevOps architecture.

**Start with:** Local Jenkins + 1 EC2
**Evolve to:** Local Jenkins + 2 EC2

Jenkins runs locally to save AWS costs and avoid resource pressure on the single EC2 instance. AWS is used only for the application runtime.

---

## Phase 1: 1 EC2 Architecture

### Region

**eu-north-1** (Stockholm)

### High-Level Layout

```text
Developer Laptop
├── Jenkins (local)
├── Docker CLI
├── AWS CLI
└── kubectl

GitHub
└── Frontend / Backend / Infra repositories

AWS (eu-north-1)
├── VPC (10.20.0.0/16)
│   └── Public Subnet (10.20.1.0/24)
│       └── Internet Gateway → Route Table
├── Security Group
├── IAM Role
├── ECR (teachua-frontend, teachua-backend)
└── EC2
    ├── Docker + K3s
    └── Frontend / Backend / MySQL
```

Monitoring (Splunk) is not on this instance — see [Phase 2: 2 EC2 Architecture](#phase-2-2-ec2-architecture) below. Stage 8 triggers the split early, ahead of the original rollout order, because Splunk needs to run on its own host rather than inside K3s.

### EC2 Instance

**t3.medium** (2 vCPU, 4 GB RAM, ~$30/month) — K3s + MySQL are memory-heavy together.
EBS: **30 GB gp3** (~$2.40/month).

### IAM Role

Attach to EC2 instead of using access keys:

```text
AmazonSSMManagedInstanceCore   # SSH alternative via SSM
AmazonEC2ContainerRegistryReadOnly
CloudWatchAgentServerPolicy    # optional
```

### Security Group — Inbound

```text
22    your IP only       # SSH
80    0.0.0.0/0          # HTTP
443   0.0.0.0/0          # HTTPS (future)
```

Do not expose MySQL (3306) publicly — it stays internal to K3s networking.

### ECR Repositories

```text
teachua-frontend
teachua-backend
```

Use Git SHA tags, not just `latest`:

```text
teachua-frontend:<git-sha>
teachua-backend:<git-sha>
```

---

## Flows

### User Traffic

```text
Browser → EC2 Public IP → K3s Ingress → Frontend → Backend → MySQL
```

### CI/CD

```text
git push → Jenkins pipeline → docker build → push to ECR → SSH to EC2 → kubectl apply → K3s pulls from ECR
```

**Deployment options:**

- **SSH-based** (simpler): Jenkins SSHs into EC2, runs `kubectl apply` there
- **kubeconfig-based**: Jenkins runs `kubectl` locally against K3s API (requires secure API exposure)

Start with SSH-based.

### Monitoring

```text
K3s pod/node logs + metrics → Splunk Forwarder / HEC → Splunk (EC2 #2)
```

---

## Phase 2: 2 EC2 Architecture

Introduced with Stage 8 — Splunk needs its own host, so the split happens now rather than waiting for full Phase 1 stability.

```text
EC2 #1 — App Server
├── K3s
├── Frontend + Backend
└── K3s Ingress

EC2 #2 — DB/Monitoring Server
├── MySQL
└── Splunk Enterprise (Free license)
```

### Why Split

- Reduces resource pressure on one instance
- Cleaner architecture for interview explanations
- Security Groups become more meaningful (App SG → DB SG)
- Monitoring survives app restarts

### Networking

Both EC2s in public subnets — avoids NAT Gateway cost (~$32/month). Security Groups enforce private DB access.

**App EC2 Security Group:**

```text
Inbound:  22 (your IP), 80 (all), 443 (all)
Outbound: 3306 → DB Security Group
         8088 → Monitoring Security Group (HEC)
```

**DB/Monitoring EC2 Security Group:**

```text
Inbound:  22 (your IP), 3306 (App SG only), 8000 (your IP, Splunk Web), 8088 (App SG only, HEC), 9997 (App SG only, forwarder-to-indexer)
```

---

## Cost Summary

| Setup | Monthly estimate |
|---|---|
| 1× t3.medium + 30 GB gp3 | ~$33–36 |
| 2× t3.medium + 2× 30 GB gp3 | ~$68–72 |
| + NAT Gateway | +$32 (avoid) |
| + ALB | +$16–20 (add later) |

All estimates are before taxes and data transfer.

---

## Rollout Order

1. Get 1 EC2 working end-to-end (Terraform → Ansible → K3s → Jenkins)
2. Split to 2 EC2 for Stage 8 — provision the DB/Monitoring EC2 and install Splunk
3. Add Route 53 + HTTPS if needed for portfolio presentation
4. Add ALB optionally

**Do not add NAT Gateway, RDS, or EKS** — unnecessary cost for this project.
