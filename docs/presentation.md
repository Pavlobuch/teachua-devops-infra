# TeachUA — DevOps Portfolio Presentation

---

## 1. Project Goal

- Demonstrate end-to-end DevOps skills for interviews: take a real full-stack application and own it from local dev through to a monitored, cloud-deployed production environment.
- Deliberately built as a single cost-optimized pipeline rather than an enterprise-scale setup — the goal is to show breadth and depth of the toolchain, not to over-engineer for scale nobody needs.
- Every infra decision (K3s vs EKS, Traefik vs ALB, Splunk deployment shape) was made and justified explicitly, not defaulted to — see *Cost Optimization Decisions*.

---

## 2. Application & Tech Stack

- **Frontend:** React (Node 16), served via Nginx
- **Backend:** Java 17 / Spring Boot (Maven), port 8080
- **Database:** MySQL/MariaDB (`teachua2`, utf8_bin)
- **Containerization:** Docker multi-stage builds, Docker Compose for local dev
- **IaC:** Terraform — AWS VPC, EC2, ECR, IAM, security groups
- **Config management:** Ansible — `common`, `docker`, `k3s_prerequisites`, `k3s`, `splunk` roles
- **CI/CD:** Jenkins (containerized), builds → ECR → deploys to K3s
- **Orchestration:** K3s (single-node)
- **Monitoring:** Splunk Enterprise (Free license), self-hosted, dedicated EC2

---

## 3. Target Architecture

- Two EC2 instances: **App Server** (K3s + workloads) and **Monitoring Server** (Splunk), split for resource isolation and independent lifecycle.
- Traffic path: Internet → EC2 public IP → Traefik (bundled in K3s) → Ingress → Service → Pod.
- Logs path: App pods → Fluent Bit DaemonSet → Splunk HEC (monitoring EC2) → dashboards/alerts.
- Images: Jenkins builds → pushes to private ECR → K3s pulls via an imagePullSecret refreshed each deploy.
- Config/secrets: Ansible Vault for provisioning-time secrets, Jenkins credentials store for pipeline-time secrets, Kubernetes Secrets created imperatively (never committed) for runtime app config.

---

## 4. Local Development → Docker → Compose

- Multi-stage Dockerfiles for backend (Maven build stage → slim JRE runtime) and frontend (Node build → Nginx serve).
- Docker Compose wires frontend, backend, and MySQL together for local iteration before anything touches AWS.
- This local parity is what later exposed a subtle bug: the frontend baked `REACT_APP_ROOT_SERVER=http://localhost:8080` at build time — fine locally, broken once the same image ran against a real backend on EC2 (see Troubleshooting).

---

## 5. AWS with Terraform

- Provisioned: VPC, subnets, security groups, EC2 (App + Monitoring), ECR repositories, IAM roles/instance profiles, gp3 volumes.
- IAM design: EC2 gets a role + instance profile (never embedded credentials); ECR access scoped to read-only on the instance since pushes happen from Jenkins, not the box itself — least privilege by design.
- Caught in review before ever reaching `apply`: a security-group rule meant for Grafana had `to_port` set to 22 instead of 3000 — would have silently blocked the monitoring port while duplicating SSH exposure.
- Real `terraform apply` failure: AWS rejected an ECR lifecycle policy (`InvalidParameterException` — `tagStatus=TAGGED` requires a tag filter). Root-caused from the actual API error and fixed by switching to `tagStatus=any`.
- Other real gotchas hit and fixed: `pathexpand()` needed for `~` in SSH key paths (Terraform doesn't expand `~` natively), and SSH key pair renames must happen *before* first `apply` since `key_name` is immutable on an existing instance.

---

## 6. Server Provisioning with Ansible

- Five roles: `common`, `docker`, `k3s_prerequisites`, `k3s`, `splunk` (+ `splunk_forwarder`), driven by a single `site.yml` against a Terraform-sourced inventory.
- Recurring failure class: **silent misconfiguration, not errors** — `ansible.cfg` settings placed outside `[defaults]` were silently ignored; `become: true` nested inside module params instead of at task level passed lint but did nothing; an inventory group name (`ec2` vs `app`) mismatch would have targeted zero hosts with no error at all.
- One genuine live failure: `k3s_binary.stats.exists` (typo for `.stat.exists`) — a real `FAILED!` on the actual EC2 during a playbook run.
- Secrets handled via Ansible Vault from early in the role design (not bolted on later) after an initial plan was reviewed and revised specifically because it had no vault strategy and no idempotency-check step.

---

## 7. CI/CD with Jenkins + ECR

- Separate CI (build & push to ECR) and CD (deploy to K3s) pipelines, deliberately split into different repos once it became clear the deploy logic didn't belong inside the backend app repo.
- CD pipeline automates the full imagePullSecret lifecycle each run: fetch ECR token → create/update K8s docker-registry secret → patch default ServiceAccount → apply manifests → verify rollout — no manual secret provisioning required.
- Hardest bugs were shell-quoting across the local → SSH → remote-shell boundary: an `--docker-password` quoting bug (I gave wrong advice first, reversed after re-tracing the quoting layers) and a `kubectl patch` JSON payload that arrived on the remote host with its quotes stripped, both root-caused from real pipeline error output.
- Cross-platform image bug: building on Apple Silicon (arm64) and deploying to an x86_64 EC2 node caused `ImagePullBackOff` with a platform-mismatch error — fixed with an explicit `--platform linux/amd64` on `docker build`.

---

## 8. Kubernetes on K3s

- Namespace, Deployments (backend/frontend/MySQL), Services, ConfigMaps, Secrets, Ingress — all hand-authored and applied via `kubectl apply -R`.
- First real pass at K8s YAML surfaced a wave of case-sensitivity and indentation bugs typical of learning the schema: `stringdata` vs `stringData`, `targetport` vs `targetPort`, `matchLabels` typos, an Ingress `paths:` block nested one level too shallow. Most were caught in review; one (`metadata::` double colon dropping the namespace's `name` field) threw a real `resource name may not be empty` error on the live cluster.
- Entry-point decision: K3s already ships Traefik on 80/443, so an AWS ALB was deliberately skipped — see *Cost Optimization*.
- Acknowledged, documented tech debt: MySQL/JWT secrets are still plaintext K8s Secrets; a real production path (External Secrets Operator, Sealed Secrets, or Vault Agent Injector) was scoped but deferred as out of portfolio scope for now.

---

## 9. Monitoring with Splunk

- Originally planned as Prometheus + Grafana; explicitly replaced with Splunk Enterprise (Free license) for two reasons: a single tool covering both logs and dashboards is simpler to demo end-to-end in an interview, and Splunk/SPL is more directly relevant experience for enterprise ops/security roles.
- Runs on its own dedicated EC2 (not inside K3s) specifically for resource isolation — indexing is memory/CPU/disk-hungry and would contend with the app and database on a single box.
- Fluent Bit DaemonSet ships container logs to Splunk over HEC; a Universal Forwarder ships host-level metrics from custom self-authored scripts (`cpu/mem/disk/net_metrics.sh`) after Splunk's official TA-nix add-on turned out to be gated behind a Splunkbase login.
- Manifest apply-order bug (fluent-bit files sorting alphabetically before `namespace.yaml`) was fixed by prefixing the namespace file `00-`; a near-miss where a "safe" `*.example.yaml` secret rename would still have been picked up and applied by `kubectl apply -R` was caught before it could leak a placeholder token into the live cluster.

---

## 10. Problems Solved / Troubleshooting

*The highlights — real incidents, root-caused from actual error output, not hypotheticals:*

1. **Ansible inventory group swap → wrong software on wrong servers.** A manual `inventory.ini` edit swapped the `[app]`/`[monitoring]` IPs. Ansible silently installed Splunk on the App EC2 and K3s on the Monitoring EC2. Surfaced via a `kubectl: command not found` failure in Jenkins; root-caused via direct SSH checks; resolved by fixing the inventory and fully recreating the contaminated App EC2 through Terraform rather than patching live infra.
2. **ECR lifecycle policy rejected by AWS API** — `tagStatus=TAGGED` requires a tag filter; fixed by switching to `tagStatus=any`.
3. **Security-group misconfiguration caught pre-apply** — Grafana rule's `to_port` was 22 instead of 3000, which would have blocked monitoring traffic while silently duplicating SSH exposure.
4. **Cross-architecture image builds** — arm64 (Apple Silicon) images built locally failed to run on the amd64 EC2 node (`ImagePullBackOff`); fixed with `--platform linux/amd64`.
5. **Shell-quoting bugs across the SSH boundary** — both an ECR password and a `kubectl patch` JSON payload lost their quoting crossing from local shell → SSH → remote shell; each required tracing exactly which shell layer was consuming which quote.
6. **Kubernetes apply-ordering bug** — Fluent Bit manifests were applied before the `monitoring` namespace existed, because `kubectl apply -R` walks files in lexical order; fixed by forcing the namespace file first (`00-namespace.yaml`).
7. **A near-miss secrets leak** — renaming a Secret manifest to `*.example.yaml` would *still* have been applied by `kubectl` (it matches on extension, not filename intent), which would have written a placeholder token into the cluster as a real credential. Caught before it ever deployed.
8. **Splunk package collision after the inventory swap** — re-running Ansible against the contaminated App EC2 hit an init.d boot-start collision between the wrongly-installed Splunk Enterprise and the correct Universal Forwarder; resolved by a clean Terraform recreate instead of manual package surgery.
9. **Private IP instability across infra recreation** — Fluent Bit's Splunk target IP is a literal value in a committed ConfigMap; every EC2 recreate silently breaks log shipping until it's manually updated. Root cause identified (no static IP pinning); documented as a known operational gotcha, later fixed by pinning a static private IP on the monitoring instance.

---

## 11. Cost Optimization Decisions

- **K3s (single-node) over EKS** — a managed control plane is unnecessary spend for a project sized to demonstrate skills, not to serve real traffic.
- **Traefik (bundled in K3s) over an AWS ALB** — saves roughly $20/month; K3s already binds 80/443 on the host, so a managed load balancer would have been redundant for a single-node deployment.
- **Splunk on one dedicated EC2 instead of a Prometheus + Grafana pair** — chosen for demo simplicity and portfolio relevance rather than raw resource savings; still isolated from the app box to avoid indexing load contending with production workloads.
- **ECR lifecycle policy simplified to two rules** (expire untagged images after 14 days, keep the last 10 tagged) — sized for portfolio image churn rather than copying a production-grade multi-tier archival policy that would have cost more to run than it saved.
- **Conscious tradeoff, not acted on:** `t3.medium` was flagged mid-project as oversized for the workload (a `t3.micro`/`t3.small` would fit the free tier) — kept for stability during active development, a deliberate "not yet, but known" call rather than an oversight.
- **Scope discipline on IAM:** an AWS SSM Session Manager policy was initially rejected as unnecessary complexity since the project already standardized on SSH + Ansible — later added back after reconsideration, illustrating a real design conversation rather than a default "add everything" posture.

---

## 12. Final Result + Next Improvements

**Final result:** a working, observable, end-to-end pipeline — `git push` → Jenkins CI builds and pushes images to ECR → Jenkins CD deploys to K3s with automated imagePullSecret refresh → the app runs behind Traefik on a public EC2 IP → Fluent Bit and a Splunk Universal Forwarder ship logs and host metrics to a dedicated Splunk Enterprise instance with custom dashboards and alerts.

**Next improvements (real, scoped tech debt — not hypothetical):**
- Replace plaintext Kubernetes Secrets (DB credentials, JWT secret) with a real secrets manager — External Secrets Operator, Sealed Secrets, or Vault Agent Injector were all evaluated; none implemented yet.
- Add TLS/HTTPS — security group already reserves port 443, not yet wired up.
- Split the single combined Splunk index (`teachua_k8s`) into `teachua_app` / `teachua_infra` / `teachua_access` as originally designed.
- Replace the hardcoded monitoring-EC2 private IP in the Fluent Bit ConfigMap with a stable Kubernetes Service/Endpoints reference so infra recreation doesn't silently break log shipping.
- Tighten the Jenkins `IMAGE_TAG` variable into a proper `environment {}` declaration instead of relying on Groovy's global script binding.
- Right-size EC2 instance types once the project moves from active development into a "steady state" demo posture.
