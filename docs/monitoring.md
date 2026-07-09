# Monitoring — Splunk

## Overview

Stage 8 adds monitoring and log analysis using **Splunk Enterprise (Free license)**, self-hosted on its own dedicated EC2 instance.

Status: **Implemented and verified working end-to-end** — logs from backend, frontend, and MySQL pods are flowing into Splunk via Fluent Bit/HEC, dashboards are populated, and alerts are scheduled. See [project-status.md](project-status.md) for the completed checklist.

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

## Terraform changes

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
| `ec2_monitoring_public_ip` | Used for SSH and the Ansible `[monitoring]` inventory group |
| `ec2_monitoring_private_ip` | Used as the `Host` in `fluent-bit-configmap.yaml` — not stable across instance recreation, must be re-fetched and the ConfigMap updated every time the monitoring EC2 is destroyed/recreated |

The stale `aws_vpc_security_group_ingress_rule.allow_grafana` (port 3000) was removed from `main.tf` — it was left over from the abandoned Prometheus/Grafana plan. See [terraform.md](terraform.md) for the full resource list.

---

## Ansible changes

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
├── defaults/main.yml     ← version, download URL, admin user, index names, HEC port/token
├── tasks/main.yml        ← install, license, admin creds, indexes, HEC, dashboards/alerts, validation
├── handlers/main.yml     ← restart Splunk
├── templates/            ← indexes.conf.j2, inputs.conf.j2 (HEC), user-seed.conf.j2
└── files/teachua_monitoring/default/  ← Splunk app: dashboards + savedsearches.conf (alerts)
```

Tasks (following the same idempotent check → install → validate pattern as the `k3s` role):

1. Create a dedicated `splunk` group and system user
2. Check whether Splunk is already installed (skip download/install if so)
3. Download the Splunk Enterprise `.deb` package
4. Install the package
5. Deploy `user-seed.conf` to seed the admin username/password (not interactive prompts)
6. Enable Splunk boot-start and accept the license in one command
7. Ensure the Splunk service is started and enabled
8. Validate Splunk is listening on port 8000 (`wait_for`)
9. Configure indexes and HEC (templated, Vault-driven token)
10. Deploy the `teachua_monitoring` Splunk app (dashboards + alerts)

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

Setup, as implemented:

1. HEC enabled globally via `inputs.conf` (templated by the `splunk` role), bound to the `teachua_k8s` index by default (not restricted to it — other indexes remain reachable if an event specifies one explicitly).
2. One HEC token, `vault_splunk_hec_token` in Ansible Vault, used to render Splunk's `inputs.conf` on the monitoring EC2.
3. Port `8088` open **only** from the App EC2 security group — never publicly.
4. The token is also stored as a Jenkins "Secret text" credential (`splunk-hec-token`), used by the Infrastructure CD pipeline's `Create Splunk HEC Secret` stage to create the `splunk-hec-secret` Kubernetes Secret imperatively — never committed to the repo as a file. **The Vault value and the Jenkins credential are two independent stores with no automatic link** — they must be kept identical manually, or Splunk silently rejects Fluent Bit's events with an invalid-token error (visible only in Fluent Bit's own logs).

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

(Both EC2s are in the same VPC, so the private IP avoids the extra hop and cost of routing through the public IP even though both are in a public subnet. This IP is not stable across instance recreation — see the Terraform outputs note above.)

Manifests — `kubernetes/monitoring/`:

| File | Purpose |
|---|---|
| `00-namespace.yaml` | Creates the `monitoring` namespace. Numbered to sort first — `kubectl apply -R -f kubernetes/` processes files in lexical order, and every other file here specifies `namespace: monitoring` |
| `fluent-bit-serviceaccount.yaml` | ServiceAccount + ClusterRole/ClusterRoleBinding to read pod logs |
| `fluent-bit-configmap.yaml` | Fluent Bit config: `INPUT` (tail `/var/log/containers/*.log`), `FILTER` (Kubernetes metadata enrichment), `OUTPUT` (splunk plugin → HEC) |
| `fluent-bit-daemonset.yaml` | DaemonSet spec, runs on every node, mounts `/var/log` read-only |

No `fluent-bit-secret.yaml` exists in this folder, intentionally — the Secret is created imperatively by the Jenkins pipeline (see below), not committed as a file, to avoid a placeholder token ever getting applied for real.

Applied by the Infrastructure CD Jenkins pipeline's `Deploy Fluent Bit` stage (explicit file list, run after the Secret exists) — see [jenkins.md](jenkins.md). These files also get swept up a second time by the pre-existing `Apply Kubernetes Manifests` stage's recursive `kubectl apply -R -f kubernetes/` — harmless since `kubectl apply` is idempotent.

---

## Application log flow

**Backend is unmodified** — Spring Boot already logs to stdout/stderr as plain text, picked up by Fluent Bit like any container.

**Frontend/Nginx was changed**: `frontend-Pavlobuch/nginx.conf` now defines a JSON `log_format` and uses it for `access_log`, so Splunk gets clean structured fields (`status`, `request_uri`, `request_method`, `remote_addr`, etc.) instead of a raw text line. This was necessary for the Frontend/Nginx dashboard and the "Frontend 5xx errors" alert to work on actual fields rather than fragile text matching. One side effect: Fluent Bit's `Merge_Log On` + `Keep_Log Off` means the raw `log` field is replaced by these parsed fields for frontend events specifically — dashboards/alerts querying frontend logs use the structured fields, not `log`.

```text
Backend container stdout/stderr  ──► Kubernetes container logs ──► Fluent Bit ──► Splunk HEC (teachua_k8s)
Frontend/Nginx container stdout (JSON) ─┘
```

All containers currently land in the single `teachua_k8s` index (the HEC token's default) — logs aren't yet split across `teachua_app`/`teachua_infra`/`teachua_access`. Still fully filterable by `kubernetes.container_name` regardless of index. Splitting by index would need a second Fluent Bit `[OUTPUT]` block matched on a distinct tag — not done in this pass.

Structured JSON logging in the Java backend is a later improvement, not implemented.

---

## Infrastructure metrics (CPU/memory/disk/network)

Separate from the K3s log pipeline above. Host-level metrics for the **App EC2** come from a second data path:

```text
Splunk Universal Forwarder (App EC2)
+ teachua_infra_metrics (self-authored scripted inputs, not a Splunkbase add-on)
──► S2S (port 9997) ──► Splunk indexer (Monitoring EC2) ──► teachua_infra index
```

- **Why a Universal Forwarder instead of extending Fluent Bit**: Fluent Bit tails container log files; it has no way to run OS-level metric collection commands (`vmstat`, `df`, etc.). A Universal Forwarder with scripted inputs is the standard, lightweight Splunk mechanism for this.
- **Why not Splunk's official Add-on for Unix and Linux (Splunk_TA_nix)**: tried first, but it's Splunkbase-gated — confirmed via direct HTTP request that the download returns 401 without a Splunkbase account, and the environment building this doesn't have one. Rather than block on that, `teachua_infra_metrics` is a small self-authored Splunk app (`ansible/roles/splunk_forwarder/files/teachua_infra_metrics/`) with four shell scripts, each emitting a single JSON line per run:
  - `cpu_metrics.sh` — parses `vmstat`'s cpu columns (indexed from the end of the line, robust to column-count drift across vmstat versions)
  - `mem_metrics.sh` — parses `free -b`
  - `disk_metrics.sh` — parses `df -B1`, one JSON line per real filesystem (tmpfs/devtmpfs/squashfs/overlay excluded)
  - `net_metrics.sh` — computes a 1-second byte-rate delta per interface from `/proc/net/dev`'s cumulative counters (loopback excluded)

  This has a real advantage over the add-on approach: since the fields are self-defined rather than a third-party add-on's internal (and unverifiable without a login) format, there's no field-name uncertainty — what's in the script is what's in the dashboard. All four scripts were tested against real command output in an actual Ubuntu 22.04 container before being committed.
- **Why port 9997**: this is the classic Splunk-to-Splunk (S2S) forwarding protocol — different from the HEC/8088 path Fluent Bit uses. The Monitoring security group already had 9997 open from the App EC2 security group (planned early in Stage 8, unused until now) — no Terraform changes were needed.
- **`teachua_infra` already existed** as one of the four original indexes — this reuses it rather than creating a new one. `sourcetype=_json` on all four inputs, same as the HEC/K8s log pipeline — no custom field-extraction knowledge needed on the indexer either.
- **Ansible play order matters here**: `site.yml`'s `monitoring` play runs *before* the `app` play — the indexer must be listening on 9997 before the forwarder tries to connect and the role's own validation step (`splunk list forward-server`) checks it.

Known noise: the network scripts will also report always-zero virtual tunnel interfaces (`tunl0`, `gre0`, `gretap0`, etc.) that some Linux kernels create by default from loaded kernel modules — confirmed present even in a stock Ubuntu 22.04 Docker container. The dashboard filters these out by name; extend the exclude list if new ones show up on the real EC2 kernel.

---

## Dashboards

Deployed as a Splunk app (`ansible/roles/splunk/files/teachua_monitoring/`), visible in Splunk Web as **TeachUA Monitoring**:

| Dashboard | Shows |
|---|---|
| TeachUA Overview | Total log volume by container, error/warning count, logs over time |
| Backend Health | Backend errors/exceptions table, backend log volume over time |
| Frontend / Nginx | Request logs, HTTP status codes over time, 404 errors — using the structured fields from the JSON logging change above |
| Kubernetes Pods | Logs by namespace, logs by pod |
| Deployment Visibility | Recent logs and container activity in the `teachua` namespace, last hour |
| Infrastructure Health | CPU/memory/disk usage over time, network activity by interface — from the Universal Forwarder + self-authored scripts above, `index=teachua_infra` |

Shipped under `default/` (not `local/`) in the Splunk app — `local/` is where Splunk/admins write runtime overrides, so shipping there would risk the next Ansible run silently overwriting any live dashboard edit made via Splunk Web.

Mostly log-based, as planned; Infrastructure Health is the first dashboard built on metric-style data.

---

## Alerts

Implemented in `ansible/roles/splunk/files/teachua_monitoring/default/savedsearches.conf`, deployed by the same "Deploy TeachUA Splunk monitoring app" task as the dashboards. Kept to three, on purpose — the goal is to demonstrate basic observability, not build a full alerting suite:

- **Backend errors detected** — `kubernetes.container_name=backend ("ERROR" OR "Exception")`, triggers on any match in the last 5 minutes.
- **No backend logs** — dead man's switch: `kubernetes.container_name=backend | stats count | search count=0`, checked every 10 minutes. Catches Fluent Bit or Splunk connectivity failures, not just app errors. Note: `stats count` with no `by` clause always emits one row even over zero input events, so a naive "results = 0" trigger never fires — the zero-check is folded into the search itself (`| search count=0`), then the alert triggers on "any results returned," same mechanism as the other two.
- **Frontend 5xx errors** — `kubernetes.container_name=frontend status>=500`, last 5 minutes. Uses the structured `status` field (see [Application log flow](#application-log-flow)) rather than raw-text matching, since nginx logs JSON now.

A Kubernetes `CrashLoopBackOff` alert (originally sketched here) is deferred — not implemented in this pass.

---

## Jenkins Infrastructure CD changes

Four stages added after the normal app deploy (see [jenkins.md](jenkins.md) for the full flow):

1. **Create Monitoring Namespace** — imperative `kubectl create namespace monitoring`, same pattern as the existing `teachua` namespace stage
2. **Create Splunk HEC Secret** — uses the Jenkins `splunk-hec-token` credential to create `splunk-hec-secret` imperatively, mirroring how `ecr-registry-secret` is already handled (never committed to Git)
3. **Deploy Fluent Bit** — applies the ServiceAccount/RBAC, ConfigMap, and DaemonSet
4. **Verify Fluent Bit** — `kubectl rollout status daemonset/fluent-bit -n monitoring --timeout=120s` then `kubectl get pods -n monitoring`

Ordering matters: the Secret must exist before Fluent Bit's pods try to mount it, or they sit in `CreateContainerConfigError` until Kubernetes retries once the Secret appears.

---

## Build order (as executed)

1. Update Terraform for second EC2 + Monitoring security group
2. `terraform apply` and verify both EC2 instances
3. Update Ansible inventory with `[app]` and `[monitoring]` groups
4. Create the Ansible `splunk` role
5. Install Splunk on the monitoring EC2
6. Open the Splunk Web UI on port 8000 and confirm login
7. Configure the four indexes
8. Configure the HEC token (hit the `vault_splunk_hec_token` undefined error here — see [troubleshooting.md](troubleshooting.md))
9. Create the Fluent Bit manifests in `kubernetes/monitoring/`
10. Deploy Fluent Bit to K3s via Jenkins (hit the missing `splunk-hec-token` Jenkins credential here — see [troubleshooting.md](troubleshooting.md))
11. Verify logs arrive in Splunk
12. Create dashboards
13. Add the alerts above
14. Jenkins Infrastructure CD pipeline updated with the monitoring stages
15. This document and the others listed below updated

Recreating infra from scratch (destroy/apply) requires redoing steps 2, and re-pointing the ConfigMap's private IP (step 9's manifest) at the new value — see [Terraform changes](#terraform-changes) above. Steps 3–8 also need rerunning against fresh instances.

---

## Troubleshooting

See [troubleshooting.md](troubleshooting.md) — two real issues were hit and logged there during this build: the Ansible Vault variable and the missing Jenkins credential, both around keeping the HEC token in sync across Vault and Jenkins.
