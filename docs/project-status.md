# Project Status

## Current Stage

Stage 8 – Monitoring

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

---

## Planned Stages

### Stage 8 – Monitoring

Full design in [monitoring.md](monitoring.md).

* Update Terraform: second EC2, Monitoring security group, Splunk ports, remove stale Grafana rule, new outputs
* Apply Terraform and verify both EC2 instances
* Update Ansible inventory with `[app]` and `[monitoring]` groups
* Create Ansible `splunk` role
* Install Splunk on the monitoring EC2
* Configure Splunk indexes (`teachua_app`, `teachua_k8s`, `teachua_infra`, `teachua_access`)
* Configure Splunk HTTP Event Collector (HEC) and token
* Create Fluent Bit Kubernetes manifests (`kubernetes/monitoring/`)
* Deploy Fluent Bit DaemonSet to K3s and verify logs arrive in Splunk
* Create Splunk dashboards
* Add basic alerts (backend error rate, frontend 5xx, missing logs, CrashLoopBackOff)
* Update Jenkins Infrastructure CD to apply monitoring manifests

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

1. Update Terraform for second EC2 + Monitoring security group
        ↓
2. Apply Terraform and verify both EC2 instances
        ↓
3. Update Ansible inventory with `[app]` and `[monitoring]` groups
        ↓
4. Create Ansible `splunk` role and install Splunk on the monitoring EC2
        ↓
5. Configure Splunk indexes and HEC token
        ↓
6. Create and deploy Fluent Bit manifests to K3s, verify logs arrive in Splunk
        ↓
7. Create dashboards and alerts
        ↓
8. Update Jenkins Infrastructure CD to apply monitoring manifests
        ↓
9. Configure GitHub Webhooks for automatic pipeline triggers

See [monitoring.md](monitoring.md) for full detail on each step.
