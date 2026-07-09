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

#### Ansible failed: 'vault_splunk_hec_token' is undefined

##### Symptoms

```
TASK [splunk : Configure Splunk HEC]
[ERROR]: Task failed: 'vault_splunk_hec_token' is undefined
```

##### Root Cause

`defaults/main.yml` references `splunk_hec_token: "{{ vault_splunk_hec_token }}"`, but the underlying `vault_splunk_hec_token` variable was never added to `group_vars/all/vault.yml`.

##### Resolution

```bash
ansible-vault edit group_vars/all/vault.yml --ask-vault-pass
```
Added `vault_splunk_hec_token: "<generated-with-openssl-rand-hex-32>"`, matching the existing `vault_splunk_admin_password` naming convention. Re-ran the playbook.

---

#### Jenkins failed: Could not find credentials entry with ID 'splunk-hec-token'

##### Symptoms

```
ERROR: Could not find credentials entry with ID 'splunk-hec-token'
Finished: FAILURE
```

##### Root Cause

The `Create Splunk HEC Secret` stage uses `withCredentials([string(credentialsId: 'splunk-hec-token', ...)])`, but that credential had never been created in Jenkins — it's a separate store from Ansible Vault, with no automatic link between them.

##### Resolution

Created a **Secret text** credential in Jenkins (**Manage Jenkins → Credentials → Add Credentials**) with ID `splunk-hec-token`, value set to the *same* token as `vault_splunk_hec_token`. Re-ran the pipeline. The two values must be kept in sync manually — a mismatch causes Splunk to silently reject Fluent Bit's events with an invalid-token error, visible only in Fluent Bit's own logs, not in Splunk.

---