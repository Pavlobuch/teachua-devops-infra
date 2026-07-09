# Ansible Implementation

## Overview

Ansible automates EC2 server configuration. It runs locally on the developer machine and connects to the EC2 instance over SSH.

| Role | Purpose |
|---|---|
| `common` | System packages, timezone, security updates |
| `docker` | Docker CE + Docker Compose plugin |
| `k3s_prerequisites` | Kernel modules, sysctl params, swap disable |
| `k3s` | K3s installation and validation |
| `splunk` | Splunk Enterprise install, license, admin user, indexes, HEC, S2S receiving, dashboards/alerts — runs on the `monitoring` host only |
| `splunk_forwarder` | Splunk Universal Forwarder + Splunk_TA_nix install, forwards CPU/memory/disk/network metrics to the indexer — runs on the `app` host only |

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
    ├── k3s/
    ├── splunk_forwarder/   ← runs on `app` host
    └── splunk/             ← runs on `monitoring` host
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

A `[monitoring]` group is added alongside `[app]`, so `site.yml` can target app and monitoring roles separately:

```ini
[app]
<APP_EC2_PUBLIC_IP>

[monitoring]
<MONITORING_EC2_PUBLIC_IP>

[app:vars]
ansible_python_interpreter=/usr/bin/python3
splunk_indexer_private_ip=<MONITORING_EC2_PRIVATE_IP>

[monitoring:vars]
ansible_python_interpreter=/usr/bin/python3
```

```bash
terraform output ec2_monitoring_public_ip
terraform output ec2_monitoring_private_ip
```

`splunk_indexer_private_ip` is consumed by the `splunk_forwarder` role (on `app`) to point its Universal Forwarder at the indexer over the private network — same value used in `kubernetes/monitoring/fluent-bit-configmap.yaml`, same caveat: not stable across instance recreation, must be updated in both places.

**Play order matters**: `site.yml`'s `monitoring` play runs before its `app` play. The `splunk` role must have the S2S listener (port 9997) up before `splunk_forwarder` tries to connect and validates it — reversing the order would make that validation fail on a fresh environment.

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

### splunk

Installs and configures Splunk Enterprise on the `monitoring` host. Full design in [monitoring.md](monitoring.md).

```text
roles/splunk/
├── defaults/main.yml     ← version, download URL, admin user, index names, HEC port/token
├── tasks/main.yml        ← task list
├── handlers/main.yml     ← restart Splunk
├── templates/            ← indexes.conf.j2, inputs.conf.j2 (HEC), user-seed.conf.j2
└── files/
    └── teachua_monitoring/
        └── default/      ← Splunk app: app.conf, savedsearches.conf (alerts), data/ui/views/*.xml (dashboards)
```

| Task | Purpose |
|---|---|
| Create `splunk` group and system user | Splunk should not run as root or `ubuntu` |
| Check if Splunk binary is already installed | Skip download/install if present, same pattern as the `k3s` role |
| Download Splunk Enterprise `.deb` package | Official Splunk download URL, version pinned in defaults |
| Install the package | `ansible.builtin.apt` with `deb` local file |
| Set ownership of the install directory | Recursive chown to `splunk:splunk` |
| Deploy `user-seed.conf` | Seeds the admin username/password before first start, avoids the setup wizard |
| Enable Splunk boot-start and accept license | `splunk enable boot-start --accept-license --answer-yes --no-prompt` |
| Ensure Splunk service is started and enabled | `ansible.builtin.service` against the systemd unit |
| Validate Splunk is listening on 8000 | `ansible.builtin.wait_for` |
| Configure Splunk indexes | Deploys `indexes.conf` (templated), notifies restart |
| Configure Splunk HEC and S2S receiving | Deploys `inputs.conf` (templated with the Vault-stored HEC token, plus a `[splunktcp://9997]` receiver stanza for the Universal Forwarder), notifies restart |
| Deploy TeachUA Splunk monitoring app | Copies `files/teachua_monitoring/` (dashboards + alerts) to `/opt/splunk/etc/apps/teachua_monitoring/`, notifies restart |

No third-party add-on is installed on this host — see `splunk_forwarder` below for why, and note `sourcetype=_json` (used by both the HEC/K8s pipeline and the infra metrics pipeline) needs no extra field-extraction knowledge on the indexer.

---

### splunk_forwarder

Installs the Splunk Universal Forwarder on the `app` host, feeding host-level CPU/memory/disk/network metrics into `teachua_infra` on the indexer. Full design in [monitoring.md](monitoring.md#infrastructure-metrics-cpumemorydisknetwork).

**Not using Splunk's official Add-on for Unix and Linux (Splunk_TA_nix)** — confirmed via direct HTTP request that Splunkbase gates it behind a login (401 without one), and there's no account available in this environment. Instead, `files/teachua_infra_metrics/` is a small self-authored Splunk app: four shell scripts (`cpu_metrics.sh`, `mem_metrics.sh`, `disk_metrics.sh`, `net_metrics.sh`), each emitting one JSON line per run. All four were tested against real command output in an Ubuntu 22.04 container before being committed. Upside over the add-on approach: since the fields are self-defined, there's no third-party-format uncertainty to verify later.

```text
roles/splunk_forwarder/
├── defaults/main.yml   ← version, download URL, indexer host/port, metrics app name/scripts, infra index
├── tasks/main.yml      ← task list
├── handlers/main.yml   ← restart Splunk Forwarder
├── templates/          ← user-seed.conf.j2, outputs.conf.j2, inputs.conf.j2 (enables the 4 metric scripts)
└── files/teachua_infra_metrics/
    ├── bin/            ← the 4 collector scripts
    └── default/app.conf
```

| Task | Purpose |
|---|---|
| Create `splunkfwd` group and system user | Universal Forwarder should not run as root or `ubuntu` |
| Check if the Forwarder binary is already installed | Skip download/install if present |
| Download the Universal Forwarder `.deb` package | Same unauthenticated `download.splunk.com` pattern as Splunk Enterprise — verified reachable without a Splunkbase login |
| Install the package | `ansible.builtin.apt` with `deb` local file |
| Set ownership of the install directory | Recursive chown to `splunkfwd:splunkfwd` |
| Deploy `user-seed.conf` | Seeds the admin username/password before first start |
| Enable boot-start and accept license | `splunk enable boot-start --accept-license --answer-yes --no-prompt` |
| Ensure the Forwarder is started | `splunk start`, idempotent |
| Configure forwarding to the indexer | Deploys `outputs.conf` pointing at `splunk_indexer_private_ip:9997`, notifies restart |
| Deploy the `teachua_infra_metrics` app | Copies `files/teachua_infra_metrics/` to `/opt/splunkforwarder/etc/apps/`, notifies restart |
| Make the collector scripts executable | `mode: "0755"` on each `bin/*.sh` — `copy` doesn't preserve execute bits by default |
| Enable the metric collector scripted inputs | Deploys `default/inputs.conf` enabling all 4 scripts with `sourcetype=_json`, `index=teachua_infra` — `default/` not `local/`, since the app's `local/` directory is never created by the `copy` task and doesn't exist to deploy into |
| Validate forwarding | Flushes handlers, runs `splunk list forward-server`, asserts the indexer host appears in the output |

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
- **Stage 8 (Monitoring):** The `splunk` role installs and configures Splunk Enterprise on the dedicated `monitoring` host. Log shipping from K3s is handled by a Fluent Bit DaemonSet Kubernetes manifest (not an Ansible role). Host-level infrastructure metrics (CPU/memory/disk/network) are handled by the `splunk_forwarder` role on the `app` host, via a Splunk Universal Forwarder + Splunk_TA_nix over S2S (port 9997) — see [monitoring.md](monitoring.md).
