# Terraform Implementation

## Overview

Terraform manages all AWS infrastructure for the TeachUA project.
Every resource is defined as code — nothing is created manually through the AWS Console.

**Provider:** AWS (`hashicorp/aws ~> 6.0`)
**Region:** `eu-north-1` (Stockholm)
**Terraform version:** `~> 1.5.7`
**Workspace:** single environment (`dev`)

---

## File Structure

```text
terraform/dev/
├── versions.tf        ← Terraform + provider version constraints
├── providers.tf       ← AWS provider config (region, profile)
├── variables.tf       ← All variable declarations with types and descriptions
├── terraform.tfvars   ← Actual values for all variables
├── main.tf            ← Networking + security group
├── iam.tf             ← IAM role, policies, instance profile
├── ecr.tf             ← ECR repositories + lifecycle policies
├── ec2.tf             ← AMI lookup, key pair, EC2 instance
└── outputs.tf         ← All output values printed after apply
```

Each concern lives in its own file. Terraform merges all `.tf` files in the directory at plan/apply time — locals and variables defined in one file are accessible in all others.

---

## Resources Created

### Networking — `main.tf`

| Resource | Name | Purpose |
|---|---|---|
| `aws_vpc` | `teachua-dev-vpc` | Isolated network (`10.20.0.0/16`) |
| `aws_subnet` | `teachua-dev-public-subnet` | Public subnet (`10.20.1.0/24`, `eu-north-1a`) |
| `aws_internet_gateway` | `teachua-dev-igw` | Connects the VPC to the internet |
| `aws_route_table` | `teachua-dev-public-rt` | Routes outbound traffic through the IGW |
| `aws_route` | — | Default route `0.0.0.0/0 → IGW` |
| `aws_route_table_association` | — | Links the public subnet to the route table |

### Security Group — `main.tf`

**`teachua-dev-ec2-sg`** — attached to the EC2 instance.

| Direction | Port | Source | Reason |
|---|---|---|---|
| Inbound | 22 | Your IP only | SSH access |
| Inbound | 80 | `0.0.0.0/0` | HTTP — app traffic |
| Inbound | 443 | `0.0.0.0/0` | HTTPS — app traffic |
| Inbound | 3000 | Your IP only | Grafana dashboard |
| Outbound | all | `0.0.0.0/0` | Unrestricted egress |

MySQL (3306) is intentionally not exposed — it stays internal to K3s networking.

### IAM — `iam.tf`

| Resource | Name | Purpose |
|---|---|---|
| `aws_iam_role` | `teachua-dev-ec2-role` | Identity assumed by the EC2 instance |
| `aws_iam_role_policy_attachment` | `ec2_ecr_read` | Allows pulling images from ECR |
| `aws_iam_role_policy_attachment` | `ec2_ssm` | Allows SSM Session Manager access |
| `aws_iam_instance_profile` | `teachua-dev-ec2-profile` | Bridge that attaches the role to EC2 |

Attached policies:

| Policy | Why |
|---|---|
| `AmazonEC2ContainerRegistryReadOnly` | EC2 only needs to pull images — Jenkins pushes |
| `AmazonSSMManagedInstanceCore` | Shell access via AWS Systems Manager without opening SSH |

### ECR — `ecr.tf`

| Repository | Name |
|---|---|
| Frontend | `teachua-dev-frontend` |
| Backend | `teachua-dev-backend` |

Both repositories share one lifecycle policy (defined as a `local` value):

| Rule | Priority | Behaviour |
|---|---|---|
| Delete untagged images | 1 | Expire untagged images older than 14 days |
| Keep last 10 images | 2 | Expire everything beyond the 10 most recent images |

`scan_on_push = true` is enabled on both repos — AWS scans images for known CVEs on every push.

### EC2 — `ec2.tf`

| Resource | Detail |
|---|---|
| AMI | Ubuntu 22.04 LTS — dynamic lookup via `data "aws_ami"` |
| Instance type | `t3.medium` (2 vCPU, 4 GB RAM) |
| Root volume | 30 GB, `gp3`, encrypted |
| Key pair | `cheap-fullstack` (loaded from `var.public_key_path`) |
| Public IP | Auto-assigned via subnet setting |

---

## Variables

All variables are declared in `variables.tf` and values are set in `terraform.tfvars`.

| Variable | Type | Value | Description |
|---|---|---|---|
| `project_name` | string | `teachua` | Used in all resource names and tags |
| `environment` | string | `dev` | Used in all resource names and tags |
| `aws_region` | string | `eu-north-1` | AWS region |
| `aws_profile` | string | `terraform-dev` | AWS CLI profile for authentication |
| `vpc_cidr` | string | `10.20.0.0/16` | VPC IP range |
| `public_subnet_cidr` | string | `10.20.1.0/24` | Public subnet IP range |
| `availability_zone` | string | `eu-north-1a` | AZ for the public subnet |
| `instance_type` | string | `t3.medium` | EC2 instance size |
| `root_volume_size` | number | `30` | EBS root volume size in GB |
| `allowed_ssh_cidr` | string | `<your-ip>/32` | IP allowed to SSH and access Grafana |
| `public_key_path` | string | `~/.ssh/cheap-fullstack.pub` | Path to SSH public key |

---

## Tagging Strategy

All resources share a common set of tags defined in a `locals` block in `main.tf`:

```hcl
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

Applied to every resource via:
```hcl
tags = merge(local.common_tags, {
  Name = "${var.project_name}-${var.environment}-<resource>"
})
```

This makes all resources identifiable in the AWS console and enables cost filtering by tag.

---

## Key Design Decisions

### `enable_dns_hostnames = true` on VPC
Required for EC2 instances to receive public DNS names (e.g. `ec2-x-x-x-x.eu-north-1.compute.amazonaws.com`). Also required for ECR image pulls to resolve correctly inside the VPC.

### `map_public_ip_on_launch = true` on subnet
EC2 instances launched in this subnet automatically receive a public IP. No need to set `associate_public_ip_address` on each instance individually.

### IAM role instead of access keys
The EC2 instance assumes an IAM role rather than storing AWS credentials on disk. AWS automatically rotates temporary credentials on the instance. This is the standard secure approach — never put access keys on an EC2 instance.

### ECR `ReadOnly` instead of full access
The EC2 instance only pulls images — it never pushes. Jenkins (local or CI server) handles the build and push. Principle of least privilege.

### AMI via data source, not hardcoded ID
AMI IDs are region-specific and change with each Ubuntu release update. Using a `data "aws_ami"` block queries AWS at plan time for the latest matching AMI, so the configuration stays correct without manual updates.

### `pathexpand()` for SSH key path
Terraform's `file()` function does not expand `~`. Wrapping with `pathexpand()` converts `~/.ssh/cheap-fullstack.pub` to the absolute home directory path before reading the file.

### ECR lifecycle policy as a `local`
The policy JSON is defined once in a `locals` block and referenced by both `aws_ecr_lifecycle_policy` resources. Change the policy in one place — both repositories get it.

### `gp3` volume type
`gp3` is the current-generation general purpose SSD. It is faster and ~20% cheaper than the older `gp2`. No reason to use `gp2` for new volumes.

### Root volume encryption
`encrypted = true` on the root block device. Good practice even for a dev environment — demonstrates security awareness in portfolio/interview context.

---

## Outputs

After `terraform apply`, the following values are printed:

| Output | Value |
|---|---|
| `vpc_id` | ID of the VPC |
| `public_subnet_id` | ID of the public subnet |
| `internet_gateway_id` | ID of the internet gateway |
| `public_route_table_id` | ID of the public route table |
| `ec2_instance_id` | EC2 instance ID |
| `ec2_public_ip` | Public IP — used for SSH and Ansible inventory |
| `ec2_public_dns` | Public DNS hostname |
| `iam_role_name` | IAM role name |
| `frontend_ecr_repository_url` | Full ECR URL for frontend — used in Jenkins push commands |
| `backend_ecr_repository_url` | Full ECR URL for backend — used in Jenkins push commands |

Retrieve any output after apply:
```bash
terraform output ec2_public_ip
terraform output frontend_ecr_repository_url
```

---

## Common Commands

All commands run from `terraform/dev/`:

```bash
# Initialise — download providers, set up backend
terraform init

# Preview what will be created/changed/destroyed
terraform plan

# Apply the plan and create resources
terraform apply

# Destroy all resources
terraform destroy

# Show current state
terraform show

# List all resources in state
terraform state list

# Print all outputs
terraform output
```

---

## Authentication

Terraform uses the AWS CLI profile `terraform-dev`. The profile must exist in `~/.aws/config` before running any Terraform commands.

Verify the profile works:
```bash
aws sts get-caller-identity --profile terraform-dev
```

Verify SSM connectivity after apply:
```bash
aws ssm describe-instance-information \
  --region eu-north-1 \
  --profile terraform-dev
```

---

## Notes for Future Stages

- **Stage 5 (Ansible):** Use `terraform output ec2_public_ip` to populate the Ansible inventory file with the EC2 IP.
- **Stage 6 (Jenkins):** Use `terraform output frontend_ecr_repository_url` and `backend_ecr_repository_url` as the push targets in the Jenkins pipeline. Jenkins will need `AmazonEC2ContainerRegistryPowerUser` on its own credentials (not the EC2 role) to push images.
- **Stage 7 (Kubernetes):** K3s runs on the same EC2. No infrastructure changes needed at this stage — K3s is installed via Ansible.
- **Stage 8 (Monitoring):** Prometheus and Grafana run inside K3s. Port 3000 is already open in the security group for Grafana access.
- **Remote state backend:** For production or team use, move Terraform state to S3 + DynamoDB for locking. Not implemented here to minimise cost and complexity.
