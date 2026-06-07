# Project Status

## Current Stage

Stage 4 – Terraform

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

---

## Planned Stages

### Stage 4 – Terraform

* Define AWS architecture and region
* Set up AWS account and configure credentials
* Initialize Terraform project structure
* Create VPC and public subnet
* Create Internet Gateway and route table
* Create EC2 security group with SSH and HTTP access
* Create IAM role and instance profile for EC2
* Create ECR repositories for frontend and backend images
* Create EC2 instance with attached IAM profile
* Run Terraform plan and apply
* Verify SSH or SSM access to EC2
* Update infrastructure documentation

### Stage 5 – Ansible

* Configure servers
* Install required software
* Automate provisioning

### Stage 6 – Jenkins

* Build CI pipeline
* Build CD pipeline

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

---

## Next Steps

1. Define AWS architecture and region
2. Set up AWS account and configure credentials
3. Initialize Terraform project structure
4. Create VPC, subnet, and networking resources
5. Create security group, IAM role, and ECR repositories
6. Create EC2 instance and apply Terraform configuration
