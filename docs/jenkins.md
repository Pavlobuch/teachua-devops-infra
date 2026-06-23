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

## Next Steps

CI/CD improvements:

- Implement automatic GitHub webhook trigger
- Add deployment stage to K3s
