# Project Status

## Current Stage

Stage 7 – Kubernetes

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

### Stage 6 – Jenkins (CI Foundation)

* Installed Jenkins using Docker Compose
* Created custom Jenkins Docker image
* Added Docker CLI
* Added AWS CLI
* Added kubectl
* Configured Jenkins persistent volume
* Configured Docker socket access
* Configured GitHub SSH authentication
* Added GitHub host key verification
* Created backend Jenkins pipeline
* Implemented Docker-based backend build
* Successfully built backend Docker image through Jenkins
* Configured AWS ECR authentication in Jenkins
* Pushed backend Docker image to ECR
* Created frontend Jenkins pipeline
* Pushed frontend Docker image to ECR

---

## Planned Stages

### Jenkins CI/CD Improvements

* Implement automatic GitHub webhook trigger
* Add deployment stage to K3s

### Stage 7 – Kubernetes

* Deploy application to K3s
* Configure Deployments
* Configure Services
* Configure Ingress

### Stage 8 – Monitoring

* Deploy Prometheus
* Deploy Grafana
* Create dashboards
* Configure alerts

### Stage 9 – Finalization

* Documentation review
* Architecture review
* Portfolio preparation
* Replace plain-text Kubernetes Secrets (mysql-secret.yaml) with a proper secrets manager — options: AWS Secrets Manager via External Secrets Operator, Sealed Secrets, or Vault Agent Injector

---

## Next Steps

1. Terraform apply (create EC2 again)
        ↓
2. Update Ansible inventory
        ↓
3. Run Ansible
        ↓
4. Verify Docker and K3s
        ↓
5. Create Kubernetes directory structure
        ↓
6. Create Namespace
        ↓
7. Deploy MySQL
        ↓
8. Deploy Backend
        ↓
9. Deploy Frontend
        ↓
10. Configure Ingress
        ↓
11. Test application
        ↓
12. Add Jenkins deployment stage
        ↓
13. Add GitHub webhook
