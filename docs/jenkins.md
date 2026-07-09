# Jenkins Documentation

## Overview

Jenkins is used as the CI/CD automation server for the TeachUA DevOps project.

Current implementation includes:

- Jenkins running as a Docker container
- Custom Jenkins Docker image
- Docker CLI integration through Docker socket
- GitHub SSH authentication
- Backend CI pipeline using Jenkinsfile
- Backend Docker image build and ECR push
- Frontend CI pipeline using Jenkinsfile
- Frontend Docker image build and ECR push

---

## Jenkins Architecture

Current local architecture:

GitHub
↓
Jenkins Container
↓
Docker Engine (Docker socket)
↓
Backend Docker Image

The Jenkins container does not run application builds directly.
Instead, Jenkins executes Docker builds, and the application Dockerfiles define their own build environments.

---

## Jenkins Deployment

Jenkins is deployed using Docker Compose.

Location:

infra/jenkins/docker-compose.yaml

Key components:

- Jenkins LTS image as a base
- Persistent Jenkins data volume
- Docker socket mount for Docker CLI access
- Custom Jenkins image with additional tools

---

## Custom Jenkins Image

Location:

infra/jenkins/Dockerfile

Base image:

jenkins/jenkins:lts


Additional tools:

- Git
- Docker CLI
- AWS CLI
- kubectl
- Maven (installed for flexibility and troubleshooting)


---

## Docker Socket Integration

Docker socket:

/var/run/docker.sock

is mounted inside the Jenkins container.

This allows Jenkins to communicate with the Docker daemon running on the host machine.

Flow:

Jenkins Container
↓
Docker CLI
↓
Docker Socket
↓
Docker Engine
↓
Build Docker Images

---

## Jenkins Persistent Storage

Jenkins data is stored using a named Docker volume:

jenkins_home

Stored data:

- Jenkins users
- Installed plugins
- Jobs
- Credentials
- Build history
- Configuration files

The Jenkins container can be recreated without losing data.

---

## GitHub Authentication

Jenkins accesses GitHub repositories using SSH credentials.

Authentication flow:

Jenkins private SSH key
↓
GitHub public SSH key
↓
Repository access granted

The GitHub host key is added to known_hosts inside the Jenkins image to allow SSH host verification.

---

## Jenkins Pipelines

### Backend Pipeline

Pipeline source:

Jenkinsfile stored in the backend repository.

Stages:

1. Checkout — downloads the repository from GitHub
2. Set Image Tag — uses git commit SHA as the Docker image tag
3. Verify Tools — validates Docker CLI and AWS CLI
4. Build Backend Docker Image — runs docker build using the backend Dockerfile
5. Login to AWS ECR — authenticates using Jenkins credentials
6. Tag Image for ECR — tags image with ECR repository URI
7. Push Image to ECR — pushes image to ECR

The backend Dockerfile performs:

- Maven build stage
- Application packaging
- Final runtime image creation

### Frontend Pipeline

Pipeline source:

Jenkinsfile stored in the frontend repository.

Stages:

1. Checkout — downloads the repository from GitHub
2. Set Image Tag — uses git commit SHA as the Docker image tag
3. Verify Tools — validates Docker CLI and AWS CLI
4. Build Frontend Docker Image — runs docker build with REACT_APP_ROOT_SERVER build argument
5. Login to AWS ECR — authenticates using Jenkins credentials
6. Tag Image for ECR — tags image with ECR repository URI
7. Push Image to ECR — pushes image to ECR

The frontend Dockerfile performs:

- Node.js build stage with React app compilation
- Final Nginx runtime image creation


---

## Current CI Flow

### Backend CI

Developer
↓
git push
↓
GitHub Repository
↓
Jenkins manual build trigger
↓
Checkout source code
↓
Docker build
↓
ECR push

### Frontend CI

GitHub
↓
Jenkins
↓
Docker build with REACT_APP_ROOT_SERVER
↓
ECR push

Current trigger method:

Manual execution using "Build Now".

---

## Troubleshooting

### GitHub Authentication Failed

Error:

Invalid username or token.

Cause:

GitHub HTTPS authentication requires a Personal Access Token.

Resolution:

Switched to SSH authentication.


---

### GitHub Host Verification Failed

Error:

No ED25519 host key is known for github.com.

Cause:

Jenkins did not have GitHub in known_hosts.

Resolution:

Added GitHub host key to the custom Jenkins Docker image.


---

### Maven Not Found

Error:

mvn: command not found

Cause:

The original pipeline attempted to run Maven directly inside Jenkins.

Resolution:

Pipeline architecture was changed to build Docker images using the backend Dockerfile. The Dockerfile contains the Maven build stage.


---

---

## Continuous Deployment Pipeline

The project uses three Jenkins pipelines.

### Backend CI

GitHub
↓
Checkout
↓
Build Docker Image
↓
Tag Image (Git SHA)
↓
Push to AWS ECR

---

### Frontend CI

GitHub
↓
Checkout
↓
Build Docker Image
↓
Tag Image (Git SHA)
↓
Push to AWS ECR

---

### Infrastructure CD

GitHub
↓
Checkout Infrastructure Repository
↓
Discover EC2 Instance
↓
Retrieve Latest Image Tags
↓
Update ECR Pull Secret
↓
Apply Kubernetes Manifests
↓
Update Deployment Images
↓
Wait for Rolling Update
↓
Verify Deployment
↓
Create Monitoring Namespace
↓
Create Splunk HEC Secret
↓
Deploy Fluent Bit
↓
Verify Fluent Bit

The four monitoring stages (added for Stage 8) run after the normal app deploy. `Create Splunk HEC Secret` uses a Jenkins "Secret text" credential (`splunk-hec-token`) to create the `splunk-hec-secret` Kubernetes Secret imperatively — mirroring how `ecr-registry-secret` is already handled, never committed to Git. `Deploy Fluent Bit` applies the ServiceAccount/RBAC, ConfigMap, and DaemonSet from `kubernetes/monitoring/` (the namespace was already created by the preceding stage, so it's not re-applied from the manifest file). `Verify Fluent Bit` waits on the DaemonSet rollout and lists pods in the `monitoring` namespace. Full design in [monitoring.md](monitoring.md).

Note: `kubernetes/monitoring/` also lives under the `kubernetes/` tree that `Apply Kubernetes Manifests` already sweeps recursively, so those files get applied twice per run — harmless (idempotent) but worth knowing if the stage list looks redundant.

---

## Deployment Architecture

Developer
        │
        ▼
GitHub
        │
        ▼
Jenkins
        │
        ├──────────────► Backend CI
        │                    │
        │                    ▼
        │              AWS ECR Backend
        │
        ├──────────────► Frontend CI
        │                    │
        │                    ▼
        │             AWS ECR Frontend
        │
        └──────────────► Infrastructure CD
                             │
                             ▼
                          EC2 (K3s)
                             │
                 Update ECR Pull Secret
                             │
                             ▼
                    kubectl apply
                             │
                             ▼
                     Rolling Update
                             │
                             ▼
                         Traefik
                             │
                             ▼
                         Browser

---

## Key Design Decisions

- Infrastructure deployment is separated from application build pipelines.
- Backend and Frontend pipelines are responsible only for building and publishing Docker images.
- Kubernetes deployment is managed exclusively by the Infrastructure pipeline.
- Docker images are versioned using Git commit SHA.
- Kubernetes resources are managed declaratively using manifests stored in the Infrastructure repository.
- Deployments use rolling updates to avoid application downtime.

---

## Next Steps

CI/CD improvements:

- Configure GitHub Webhooks for automatic pipeline triggers
- Trigger deployment after successful CI builds

Monitoring (Stage 8) is complete — see [monitoring.md](monitoring.md).
