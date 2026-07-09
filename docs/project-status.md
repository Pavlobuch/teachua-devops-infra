# Project Status

## Current Stage

CI/CD Improvements (Stage 8 – Monitoring completed)

---

## Completed

### Project Initialization

* Forked Frontend Repository
* Forked Backend Repository
* Created Infrastructure Repository
* Defined Project Scope
* Defined Technology Stack
* Created Initial Documentation
* Designed Repository Structure

### Stage 1 – Local Development

* Installed required development tools
* Configured Java environment
* Configured Node.js environment
* Started MySQL database
* Built and started Backend application
* Installed Frontend dependencies
* Started Frontend application
* Configured Frontend ↔ Backend communication
* Verified Backend ↔ Database communication
* Verified application functionality
* Completed local smoke testing

### Stage 2 – Docker

* Analyzed Frontend application requirements
* Analyzed Backend application requirements
* Designed containerization strategy
* Created Backend Dockerfile (multi-stage: Maven build + JRE runtime)
* Created Frontend Dockerfile (multi-stage: Node build + Nginx serve)
* Built Docker images
* Validated containerized application

### Stage 3 – Docker Compose

* Created Docker Compose environment
* Configured networking
* Configured volumes
* Configured environment variables
* Validated full local stack

### Stage 4 – Terraform

* Defined AWS architecture and region
* Set up AWS account and configured credentials
* Initialized Terraform project structure
* Created VPC and public subnet
* Created Internet Gateway and route table
* Created EC2 security group with SSH, HTTP, HTTPS, and Grafana access
* Created IAM role with ECR ReadOnly and SSM policies
* Created IAM instance profile
* Created ECR repositories for frontend and backend images with lifecycle policies
* Created EC2 instance with Ubuntu 22.04, gp3 encrypted volume, and IAM profile
* Configured dynamic AMI lookup via data source
* Configured consistent tagging strategy across all resources
* Run Terraform plan and apply
* Verified SSM access to EC2
* Updated infrastructure documentation

### Stage 5 – Ansible

* Pinned and installed Ansible + ansible-lint
* Created repository structure
* Created ansible.cfg
* Created inventory
* Tested SSH connectivity with Ansible ping
* Added group_vars / host_vars
* Defined Vault / secrets strategy
* Created playbook skeleton
* Created common role
* Lint → dry-run → execute → idempotency check (common)
* Created Docker role
* Lint → dry-run → execute → validate → idempotency check (Docker)
* Created K3s prerequisites role
* Created K3s role
* Lint → dry-run → execute → validate → idempotency check (K3s)
* Created Ansible documentation

### Stage 6 – Jenkins

* Created custom Jenkins Docker image
* Installed Docker CLI
* Installed AWS CLI
* Installed kubectl
* Installed Git
* Configured GitHub SSH authentication
* Configured AWS credentials
* Created Backend CI pipeline
* Created Frontend CI pipeline
* Built backend Docker image
* Built frontend Docker image
* Tagged Docker images using Git commit SHA
* Pushed backend image to AWS ECR
* Pushed frontend image to AWS ECR

### Stage 7 – Kubernetes

* Created Kubernetes namespace
* Created MySQL Deployment and Service
* Created Backend Deployment and Service
* Created Frontend Deployment and Service
* Created ConfigMaps
* Created Secrets
* Created Ingress
* Successfully deployed application to K3s
* Configured automatic ECR authentication
* Implemented rolling updates through Jenkins
* Verified successful deployment
* Application is accessible through Ingress

### Stage 8 – Monitoring

Full design in [monitoring.md](monitoring.md).

* Provisioned second EC2 instance (DB/Monitoring Server) via Terraform, with a dedicated Monitoring security group (22, 8000, 8088, 9997) and the stale Grafana rule removed
* Added Ansible `[monitoring]` inventory group
* Created and ran the Ansible `splunk` role — installs Splunk Enterprise, accepts license, seeds admin credentials, configures indexes, HEC, and deploys the `teachua_monitoring` Splunk app
* Configured Splunk indexes (`teachua_app`, `teachua_k8s`, `teachua_infra`, `teachua_access`)
* Configured Splunk HTTP Event Collector (HEC) with a Vault-stored token
* Created Kubernetes manifests for Fluent Bit (`kubernetes/monitoring/`) and deployed the DaemonSet to K3s
* Switched frontend Nginx access logs to JSON format so Splunk gets structured fields (status, request_uri, etc.)
* Verified logs from backend, frontend, and MySQL pods arrive in Splunk
* Created 6 Splunk dashboards (Overview, Backend Health, Frontend/Nginx, Kubernetes Pods, Deployment Visibility, Infrastructure Health)
* Added 3 alerts (backend errors detected, no backend logs, frontend 5xx errors)
* Updated Jenkins Infrastructure CD with `Create Monitoring Namespace`, `Create Splunk HEC Secret`, `Deploy Fluent Bit`, and `Verify Fluent Bit` stages
* Verified end-to-end in production: dashboards populated with live data
* Added the `splunk_forwarder` Ansible role (Universal Forwarder + self-authored `teachua_infra_metrics` scripts on the App EC2, not the Splunkbase-gated Splunk_TA_nix — no account available) feeding CPU/memory/disk/network metrics into `teachua_infra` over S2S (port 9997); scripts tested against real command output before commit, see [monitoring.md](monitoring.md#infrastructure-metrics-cpumemorydisknetwork)

---

## Planned Stages

### CI/CD Improvements

* Configure GitHub Webhooks
* Trigger Jenkins pipelines automatically on push
* Trigger deployment after successful CI builds

### Stage 9 – Finalization

* Documentation review
* Architecture review
* Portfolio preparation
* Replace plain-text Kubernetes Secrets (mysql-secret.yaml) with a proper secrets manager — options: AWS Secrets Manager via External Secrets Operator, Sealed Secrets, or Vault Agent Injector

---

## Next Steps

1. Configure GitHub Webhooks for automatic pipeline triggers
        ↓
2. Trigger deployment automatically after successful CI builds
        ↓
3. Stage 9 — documentation/architecture review and portfolio preparation

See [monitoring.md](monitoring.md) for the full Stage 8 design and what was built.
