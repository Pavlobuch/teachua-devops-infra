# Monitoring — Splunk

## Overview

Stage 8 adds monitoring and log analysis using **Splunk Enterprise (Free license)**, self-hosted on its own dedicated EC2 instance.

Status: **Planned** — this document describes the target design. See [project-status.md](project-status.md) for what has actually been built so far.

---

## Why Splunk instead of Prometheus/Grafana

The project originally planned Prometheus + Grafana for Stage 8. That direction changed to Splunk:

- Splunk covers both **log aggregation** and **metrics/dashboards** in a single product, which is simpler to demonstrate end-to-end in an interview than a two-tool Prometheus/Grafana stack.
- Splunk's search language (SPL) and dashboarding are widely used in enterprise operations/security roles — relevant portfolio experience beyond what Prometheus/Grafana would show.
- A single self-hosted instance with the Free license is enough for a portfolio project; no need for Prometheus's pull-based scraping model or a separate Grafana deployment.

## Why Splunk runs on a second, dedicated EC2

Splunk is not deployed inside K3s. It runs on its own EC2 instance ("DB/Monitoring Server"), alongside MySQL. See [aws.md](aws.md) for the full 2-EC2 architecture.

Reasons:

- **Resource isolation** — Splunk indexing is memory/CPU/disk hungry; running it next to K3s, the app, and MySQL on one `t3.medium` would cause resource pressure.
- **Survives app restarts/redeploys** — monitoring data and the Splunk instance are unaffected by K3s rollouts, pod crashes, or `kubectl apply` on the app cluster.
- **Cleaner security boundary** — a dedicated Monitoring Security Group with narrow, explicit inbound rules is easier to reason about (and explain in an interview) than more rules bolted onto the app instance's security group.
- **Matches the already-planned Phase 2 split** in [aws.md](aws.md) — Stage 8 is what triggers that split, rather than waiting for a later, unrelated milestone.

---

## Topology

```text
EC2 #1 — App Server                    EC2 #2 — DB/Monitoring Server
├── K3s                                ├── MySQL
│   ├── Frontend                       └── Splunk Enterprise (Free)
│   ├── Backend                            ├── Web UI      (8000)
│   ├── MySQL client → EC2 #2               ├── HEC         (8088)
│   └── Fluent Bit (DaemonSet)  ──────────► └── Indexer     (9997)
└── K3s Ingress (Traefik)
```

Monitoring flow:

```text
Backend container stdout/stderr   ─┐
Frontend/Nginx container stdout ───┼──► Kubernetes container logs ──► Fluent Bit DaemonSet ──► Splunk HEC (EC2 #2:8088) ──► Splunk indexes
Node/system logs ───────────────────┘
```

---

## Terraform changes (planned)

New resources, in addition to the existing single `aws_instance.app`:

| Resource | Purpose |
|---|---|
| `aws_instance.monitoring` | Second EC2 (Ubuntu 22.04), runs MySQL + Splunk |
| `aws_security_group.monitoring_sg` | Dedicated security group, separate from `ec2_sg` |
| Ingress rule | `22` from `var.allowed_ssh_cidr` — SSH |
| Ingress rule | `8000` from `var.allowed_ssh_cidr` — Splunk Web UI |
| Ingress rule | `8088` from `aws_security_group.ec2_sg` (App EC2 SG) — HEC |
| Ingress rule | `9997` from `aws_security_group.ec2_sg` (App EC2 SG) — forwarder-to-indexer |
| Egress rule | all — unrestricted, matching the existing pattern |

New outputs:

| Output | Purpose |
|---|---|
| `monitoring_ec2_public_ip` | Used for SSH and the Ansible `[monitoring]` inventory group |
| `monitoring_ec2_public_dns` | Public DNS of the monitoring EC2 |
| `monitoring_security_group_id` | Referenced when wiring up cross-SG rules |

Also required: remove the stale `aws_vpc_security_group_ingress_rule.allow_grafana` (port 3000) from `main.tf` — it was added for the abandoned Prometheus/Grafana plan and is no longer used. See [terraform.md](terraform.md) for the full planned resource list.

---

## Ansible changes (planned)

Inventory grows from a single `[app]` group to `[app]` + `[monitoring]`:

```ini
[app]
<APP_EC2_PUBLIC_IP>

[monitoring]
<MONITORING_EC2_PUBLIC_IP>

[app:vars]
ansible_python_interpreter=/usr/bin/python3

[monitoring:vars]
ansible_python_interpreter=/usr/bin/python3
```

`site.yml` gets a second play targeting `monitoring`:

```yaml
- name: Provision monitoring EC2
  hosts: monitoring
  become: true
  roles:
    - common
    - docker
    - splunk
```

New role: `ansible/roles/splunk/`

```text
splunk/
├── defaults/main.yml     ← version, download URL, admin user, index names, HEC port
├── tasks/main.yml        ← install, license, admin creds, indexes, HEC, validation
├── handlers/main.yml     ← restart Splunk
└── templates/            ← indexes.conf, inputs.conf (HEC) if managed as files rather than CLI calls
```

Planned tasks (following the same idempotent check → install → validate pattern as the `k3s` role):

1. Create a dedicated `splunk` system user
2. Check whether Splunk is already installed (skip download/install if so)
3. Download the Splunk Enterprise `.deb` package
4. Install the package
5. Accept the Splunk license (`--accept-license`)
6. Set the admin username/password (via `user-seed.conf`, not interactive prompts)
7. Enable the Splunk boot-start systemd service
8. Start Splunk
9. Validate Splunk is listening on port 8000 (`wait_for` / `uri` module)

See [ansible.md](ansible.md) for the full role table.

---

## Splunk indexes

| Index | Purpose |
|---|---|
| `teachua_app` | Backend application logs |
| `teachua_k8s` | Kubernetes pod/container logs |
| `teachua_infra` | Node/system logs |
| `teachua_access` | Frontend/Nginx access logs |

Kept deliberately small — four indexes is enough to demonstrate index-based data separation without overengineering a portfolio project.

---

## HTTP Event Collector (HEC)

HEC lets Fluent Bit (or any HTTP client) push events into Splunk without the older Universal Forwarder agent.

Setup:

1. Enable HEC globally in Splunk (`Settings → Data Inputs → HTTP Event Collector`).
2. Create one HEC token, bound to the four indexes above (or one token per index if finer-grained access control is wanted later — start with one).
3. Open port `8088` **only** from the App EC2 security group — never publicly.
4. Store the HEC token as a Kubernetes Secret (`fluent-bit-secret.yaml`) referenced by the Fluent Bit DaemonSet — never committed in plaintext to the repo. For the Ansible side (setting the token during Splunk provisioning), keep it in Ansible Vault.

---

## Fluent Bit (log forwarder)

Runs as a DaemonSet in K3s — one pod per node — rather than the Splunk Universal Forwarder, because it's lighter weight and is the standard choice for container log forwarding.

Collects:

```text
/var/log/containers/*.log
```

Ships to:

```text
http://<MONITORING_EC2_PRIVATE_IP>:8088
```

(Both EC2s are in the same VPC, so the private IP avoids the extra hop and cost of routing through the public IP even though both are in a public subnet.)

Planned manifests — `kubernetes/monitoring/`:

| File | Purpose |
|---|---|
| `fluent-bit-serviceaccount.yaml` | ServiceAccount + ClusterRole/ClusterRoleBinding to read pod logs |
| `fluent-bit-configmap.yaml` | Fluent Bit config: `INPUT` (tail `/var/log/containers/*.log`), `FILTER` (Kubernetes metadata enrichment), `OUTPUT` (splunk plugin → HEC) |
| `fluent-bit-secret.yaml` | HEC token, mounted as an env var into the Fluent Bit container |
| `fluent-bit-daemonset.yaml` | DaemonSet spec, runs on every node, mounts `/var/log` and `/var/lib/docker/containers` read-only |

Applied by the Infrastructure CD Jenkins pipeline (`kubectl apply -f kubernetes/monitoring/`), same as the existing app manifests — see [jenkins.md](jenkins.md).

---

## Application log flow

**Backend and Frontend are not modified at this stage.** Both already log to stdout/stderr inside their containers:

```text
Backend container stdout/stderr  ──► Kubernetes container logs ──► Fluent Bit ──► Splunk HEC (teachua_app / teachua_access)
Frontend/Nginx container stdout ─┘
```

Nginx access/error logs go to stdout/stderr by default in the container image, so no Dockerfile change is needed to get status codes, 404s, and request volume into Splunk.

Structured JSON logging in the Java app is a later improvement, not a Stage 8 requirement.

---

## Dashboards (planned)

| Dashboard | Shows |
|---|---|
| TeachUA Overview | Total log volume, error/warning counts, request counts |
| Backend Health | Backend errors, exceptions, API activity |
| Frontend / Nginx | HTTP status codes, 404s, request count |
| Kubernetes Pods | Pod logs filtered by namespace/app/container |
| Deployment Visibility | Logs filtered by image tag or deployment time |

Start with log-based dashboards; metric-based panels can be added later.

---

## Alerts

Implemented in `ansible/roles/splunk/files/teachua_monitoring/default/savedsearches.conf`, deployed by the same "Deploy TeachUA Splunk monitoring app" task as the dashboards. Kept to three, on purpose — the goal is to demonstrate basic observability, not build a full alerting suite:

- **Backend errors detected** — `kubernetes.container_name=backend ("ERROR" OR "Exception")`, triggers on any match in the last 5 minutes.
- **No backend logs** — dead man's switch: `kubernetes.container_name=backend | stats count | search count=0`, checked every 10 minutes. Catches Fluent Bit or Splunk connectivity failures, not just app errors. Note: `stats count` with no `by` clause always emits one row even over zero input events, so a naive "results = 0" trigger never fires — the zero-check is folded into the search itself (`| search count=0`), then the alert triggers on "any results returned," same mechanism as the other two.
- **Frontend 5xx errors** — `kubernetes.container_name=frontend status>=500`, last 5 minutes. Uses the structured `status` field (see [Application log flow](#application-log-flow)) rather than raw-text matching, since nginx logs JSON now.

A Kubernetes `CrashLoopBackOff` alert (originally sketched here) is deferred — not implemented in this pass.

---

## Jenkins Infrastructure CD changes (planned)

The existing Infrastructure CD pipeline (see [jenkins.md](jenkins.md)) already applies Kubernetes manifests declaratively. It gains one more step:

```text
kubectl apply -f kubernetes/monitoring/
```

This only gets added to the pipeline once Splunk is installed and an HEC token exists — applying the Fluent Bit DaemonSet before Splunk can accept events would just produce a crash-looping/erroring pod.

---

## Recommended build order

1. Update Terraform for second EC2 + Monitoring security group
2. `terraform apply` and verify both EC2 instances
3. Update Ansible inventory with `[app]` and `[monitoring]` groups
4. Create the Ansible `splunk` role
5. Install Splunk on the monitoring EC2
6. Open the Splunk Web UI on port 8000 and confirm login
7. Configure the four indexes
8. Configure the HEC token
9. Create the Fluent Bit manifests in `kubernetes/monitoring/`
10. Deploy Fluent Bit to K3s
11. Verify logs arrive in Splunk
12. Create dashboards
13. Add the alerts above
14. Update the Jenkins Infrastructure CD pipeline to apply `kubernetes/monitoring/`
15. Keep this document and the others listed below current

---

## Troubleshooting

No issues logged yet — Splunk has not been provisioned. Once the steps above are executed, real issues and their resolutions get recorded here, following the same format as [troubleshooting.md](troubleshooting.md) (Symptoms / Root Cause / Resolution).
