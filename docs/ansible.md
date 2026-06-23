# Ansible Implementation

## Overview

Ansible automates EC2 server configuration. It runs locally on the developer machine and connects to the EC2 instance over SSH.

| Role | Purpose |
|---|---|
| `common` | System packages, timezone, security updates |
| `docker` | Docker CE + Docker Compose plugin |
| `k3s_prerequisites` | Kernel modules, sysctl params, swap disable |
| `k3s` | K3s installation and validation |

---

## Repository Structure

```text
devops-infra/ansible/
├── ansible.cfg               ← connection settings, role path, privilege escalation
├── inventory.ini             ← EC2 host and group vars
├── site.yml                  ← main playbook, wires all roles
├── requirements.yml          ← external collections (community.general, ansible.posix)
├── group_vars/
│   └── all/
│       ├── vars.yml          ← shared plain variables
│       └── vault.yml         ← encrypted secrets (ansible-vault)
└── roles/
    ├── common/
    ├── docker/
    ├── k3s_prerequisites/
    └── k3s/
```

Each role follows the structure:

```text
role/
├── tasks/main.yml      ← task list
├── defaults/main.yml   ← default variables (overridable)
└── handlers/main.yml   ← service restart handlers (docker, k3s roles)
```

---

## Configuration — `ansible.cfg`

```ini
[defaults]
inventory         = inventory.ini
remote_user       = ubuntu
private_key_file  = ~/.ssh/cheap-fullstack
roles_path        = roles
host_key_checking = False

[privilege_escalation]
become        = True
become_method = sudo
```

- `remote_user` — SSH user for Ubuntu EC2 instances
- `private_key_file` — must match the key used when creating the EC2 instance in Terraform
- `host_key_checking = False` — required because EC2 IPs change on every `terraform apply`
- `become = True` — all tasks escalate to root via sudo

---

## Inventory — `inventory.ini`

```ini
[app]
<EC2_PUBLIC_IP>

[app:vars]
ansible_python_interpreter=/usr/bin/python3
```

Get the EC2 public IP from Terraform output:

```bash
cd devops-infra/terraform
terraform output ec2_public_ip
```

---

## External Collections — `requirements.yml`

```yaml
collections:
  - name: community.general   # timezone module
  - name: ansible.posix       # sysctl module
```

Install before running the playbook:

```bash
ansible-galaxy collection install -r requirements.yml
```

---

## Roles

### common

Prepares the base system.

| Task | Module |
|---|---|
| Update apt cache | `ansible.builtin.apt` |
| Install common packages | `ansible.builtin.package` |
| Set timezone to Europe/Kiev | `community.general.timezone` |
| Install + enable unattended-upgrades | `ansible.builtin.package` + `service` |
| Print system info | `ansible.builtin.debug` |

Packages installed: `curl`, `wget`, `git`, `vim`, `nano`, `unzip`, `jq`, `htop`, `ca-certificates`, `gnupg`, `lsb-release`

---

### docker

Installs Docker CE from the official Docker apt repository.

| Task | Purpose |
|---|---|
| Install prerequisite packages | `ca-certificates`, `curl`, `gnupg` |
| Create keyring directory | `/etc/apt/keyrings` |
| Download Docker GPG key | `/etc/apt/keyrings/docker.asc` |
| Add Docker apt repository | Official Docker repo for Ubuntu |
| Install Docker packages | `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin` |
| Enable Docker service | Starts and enables on boot |
| Add ubuntu user to docker group | Allows running Docker without sudo |
| Validate Docker version | Prints `docker --version` output |

Key defaults (`roles/docker/defaults/main.yml`):

```yaml
docker_users:
  - ubuntu
docker_packages:
  - docker-ce
  - docker-ce-cli
  - containerd.io
  - docker-buildx-plugin
  - docker-compose-plugin
```

---

### k3s_prerequisites

Prepares the kernel for K3s. Must run before the `k3s` role.

| Task | Purpose |
|---|---|
| Install prerequisite packages | `curl`, `ca-certificates`, `apt-transport-https` |
| Load kernel modules | `overlay`, `br_netfilter` via `community.general.modprobe` |
| Persist kernel modules | `/etc/modules-load.d/k3s.conf` |
| Configure sysctl parameters | Bridge networking + IP forwarding via `ansible.posix.sysctl` |
| Disable swap | Required by Kubernetes |
| Assert modules loaded | Validates kernel state |
| Assert sysctl values correct | Validates sysctl state |

Sysctl parameters set:

```yaml
net.bridge.bridge-nf-call-iptables: 1
net.bridge.bridge-nf-call-ip6tables: 1
net.ipv4.ip_forward: 1
```

---

### k3s

Installs and validates K3s (single-node Kubernetes).

| Task | Purpose |
|---|---|
| Check if k3s binary exists | Skips install if already present |
| Create temp directory | `/tmp/k3s` |
| Download install script | `https://get.k3s.io` via `get_url` |
| Run install script | Installs K3s binary and systemd service |
| Enable k3s service | Starts and enables on boot |
| Create `.kube` directory | `/home/ubuntu/.kube` with correct ownership |
| Copy kubeconfig | `/etc/rancher/k3s/k3s.yaml` → `/home/ubuntu/.kube/config` |
| Set KUBECONFIG env var | Adds `export KUBECONFIG=/home/ubuntu/.kube/config` to `~/.bashrc` |
| Validate k3s version | Prints version output |
| Check kubectl nodes | Runs `kubectl get nodes` |
| Assert node is Ready | Fails playbook if node not healthy |

**Note on kubeconfig:** K3s writes its kubeconfig to `/etc/rancher/k3s/k3s.yaml` (root-owned, 0600). The `kubectl` binary on K3s systems is a symlink to `k3s` and targets that path by default — it does not automatically fall back to `~/.kube/config`. The role copies the file and sets `KUBECONFIG` in `~/.bashrc` to make kubectl work for the `ubuntu` user. Run `source ~/.bashrc` in any existing SSH session after the playbook runs.

---

## Running the Playbook

All commands run from `devops-infra/ansible/`:

```bash
# Test SSH connectivity
ansible all -m ping

# Dry-run (no changes applied)
ansible-playbook site.yml --check

# Full run
ansible-playbook site.yml

# Run with verbose output
ansible-playbook site.yml -v

# Run a single role using tags (if tags are added)
ansible-playbook site.yml --tags docker
```

---

## Linting

```bash
# Lint a single role
ansible-lint roles/common/

# Lint the full playbook
ansible-lint site.yml
```

Run lint before every execution. Fix all `profile:min` violations — these are fatal.

---

## Idempotency

Run the playbook twice after any change. The second run should report zero changes. If it reports changes, the role is not idempotent and needs to be fixed.

```bash
ansible-playbook site.yml
# second run — expect: changed=0
ansible-playbook site.yml
```

---

## Useful Commands

```bash
# Ping all hosts
ansible all -m ping

# Run an ad-hoc command on all hosts
ansible all -m ansible.builtin.command -a "uptime"

# Check Docker status on EC2
ansible all -m ansible.builtin.command -a "docker --version"

# Check K3s node status
ansible all -m ansible.builtin.command -a "kubectl get nodes"

# List installed collections
ansible-galaxy collection list
```

---

## Notes for Future Stages

- **Stage 6 (Jenkins):** Jenkins will call `ansible-playbook site.yml` as part of the CD pipeline after a new image is pushed to ECR.
- **Stage 7 (Kubernetes):** The `k3s` role provisions the cluster. Kubernetes manifests are managed separately in `devops-infra/kubernetes/`.
- **Stage 8 (Monitoring):** A future `monitoring` role will deploy Prometheus and Grafana onto the K3s cluster.
