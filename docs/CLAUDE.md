# CLAUDE.md

# TeachUA DevOps Portfolio Project

## Project Purpose

This repository contains the infrastructure, automation, deployment, monitoring, and documentation for the TeachUA DevOps Portfolio Project.

The goal is to demonstrate practical DevOps skills by deploying and operating a full-stack application using modern DevOps tools and AWS cloud services.

This project is intended for:

* DevOps learning
* Portfolio presentation
* Interview preparation
* Hands-on experience with cloud-native technologies

---

# Repository Structure

```text
TeachUA/
├── frontend/
├── backend/
└── infra/
    ├── docs/
    ├── terraform/
    ├── ansible/
    ├── kubernetes/
    ├── jenkins/
    ├── scripts/
    └── CLAUDE.md
```

## Repositories

### frontend

Frontend application source code.
Front-end written on: React JS;
Required Tools: nodejs 16 version.

### backend

Backend application source code.
Back-end programming language: Java
Database: MariaDB/MySQL
Required Tools: Java 17, Maven 3.6.3
### infra

Infrastructure, automation, deployment, monitoring, and documentation.

---

# Project Technology Stack

## Application

* Frontend Application
* Backend API
* Database

## Containerization

* Docker
* Docker Compose

## Infrastructure as Code

* Terraform

## Configuration Management

* Ansible

## CI/CD

* Jenkins

## Container Orchestration

* Kubernetes (K3s)

## Cloud Platform

* AWS

## Monitoring

* Splunk (self-hosted, dedicated EC2 instance)

---

# Architecture Principles

## Cost Optimization

This is a portfolio project.

When multiple valid solutions exist:

* Prefer lower-cost solutions.
* Avoid unnecessary managed services.
* Avoid enterprise-scale architecture unless required for learning purposes.

Examples:

* Prefer K3s over EKS.
* Prefer EC2-hosted database over RDS.
* Prefer single-node Kubernetes cluster.
* Avoid multi-AZ deployments unless specifically required.
* Minimize AWS monthly cost.

---

## Simplicity

Prefer solutions that are:

* Easy to understand
* Easy to document
* Easy to demonstrate during interviews

Avoid unnecessary complexity.

---

## Automation First

Infrastructure and deployments should be automated whenever practical.

Preferred order:

1. Terraform
2. Ansible
3. Jenkins
4. Kubernetes

Avoid manual configuration where automation is possible.

---

## Infrastructure as Code

AWS resources should be managed through Terraform.

Avoid creating infrastructure manually through the AWS Console except for temporary troubleshooting.

---

## Configuration Management

Server configuration should be managed through Ansible.

Examples:

* Package installation
* Docker installation
* Kubernetes prerequisites
* User management
* Configuration files

---

## Kubernetes

Target platform:

* K3s

Preferred resources:

* Namespace
* Deployment
* Service
* Ingress
* ConfigMap
* Secret
* Persistent Volume

Keep manifests simple and production-like.

---

## Monitoring

Monitoring is a required project component.

Monitoring stack:

* Splunk Enterprise (Free license), self-hosted on a dedicated EC2 instance separate from the K3s app node

Objectives:

* Infrastructure monitoring
* Container monitoring
* Kubernetes monitoring
* Application monitoring

Create dashboards that can be demonstrated during interviews.

---

# Documentation

All documentation is located in:

```text
infra/docs/
```

Current documentation:

```text
README.md
project-status.md
architecture.md
aws.md
terraform.md
ansible.md
jenkins.md
docker.md
monitoring.md
troubleshooting.md
```

Documentation should be updated as the project evolves.

---

# Expected Final Flow

Developer
→ GitHub
→ Jenkins Pipeline
→ Docker Build
→ Docker Image
→ Kubernetes Deployment
→ Application

Monitoring Flow:

Application (K3s, EC2 #1)
→ Splunk Forwarder / HEC
→ Splunk (dedicated EC2 #2)

Infrastructure Flow:

Terraform
→ AWS Resources

Configuration Flow:

Ansible
→ Server Configuration

---

# AI Assistant Instructions

When making recommendations:

* Consider the entire project architecture.
* Consider future Kubernetes deployment.
* Consider future Jenkins integration.
* Consider future monitoring requirements.
* Consider AWS cost impact.
* Prefer practical portfolio-ready solutions.
* Explain architectural decisions.
* Explain tradeoffs.
* Avoid unnecessary enterprise complexity.

When generating code:

* Follow DevOps best practices.
* Keep solutions maintainable.
* Keep solutions reproducible.
* Document important decisions.

Always assume this project will eventually include:

* Docker
* Docker Compose
* Terraform
* Ansible
* Jenkins
* Kubernetes (K3s)
* AWS
* Splunk
