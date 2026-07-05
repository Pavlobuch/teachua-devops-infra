# Troubleshooting

This document contains real issues encountered during project development and their resolutions.

---

### ImagePullBackOff

#### Symptoms

Backend and Frontend pods remained in:

- ErrImagePull
- ImagePullBackOff

#### Root Cause

AWS ECR repositories were private.

Kubernetes was unable to authenticate while pulling Docker images.

#### Resolution

Implemented an Infrastructure Jenkins pipeline that automatically:

- retrieves an ECR authentication token
- creates or updates the Kubernetes Docker Registry Secret
- patches the default ServiceAccount
- deploys Kubernetes manifests

This removed the need to manually create imagePullSecrets.

---

### Ingress returned 404

#### Symptoms

Opening the EC2 public IP displayed:

404 page not found

#### Root Cause

Ingress referenced a Service named:

frontend

while the actual Service was named:

frontend-service

Traefik could not resolve the backend Service.

#### Resolution

Renamed the frontend Service to match the Ingress configuration.

Application became accessible through:

http://<EC2_PUBLIC_IP>

---

### Stage 8 — Monitoring (Splunk / Fluent Bit)

No issues logged yet — Splunk has not been provisioned. Once Stage 8 is implemented, real issues encountered while setting up the second EC2, the Splunk role, HEC, or the Fluent Bit DaemonSet get recorded here in the same Symptoms / Root Cause / Resolution format. See [monitoring.md](monitoring.md) for the planned design.

---