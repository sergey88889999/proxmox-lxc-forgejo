[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.11+-FFDA18?logo=opentofu&logoColor=black)](https://opentofu.org/)
# OpenTofu Configuration

Infrastructure as Code for deploying Forgejo Git Server on Proxmox.

## Overview

Deploys a Debian 13 LXC container with:
- Docker support enabled
- Dedicated ansible user for provisioning
- SSH on port 2222
- NAS mount for backups
- Automatic Ansible Inventory generation (Syncs IP, Port, and SSH keys)

## Quick Start
```bash
# 1. Create secrets file
cp secrets.auto.tfvars.example secrets.auto.tfvars
nano secrets.auto.tfvars # Edit: pm_api_url, root_password, ip_prod/test

# 2. Deploy infrastructure
tofu init
tofu workspace new prod
tofu workspace new test
tofu workspace select prod   # or test
tofu apply

# 3. Verify deployment
ssh ansible@<container_ip> -p 2222
```

## Files

- `main.tf` - Main infrastructure configuration
- `secrets.auto.tfvars.example` - Template for secrets (copy and fill)
- `secrets.auto.tfvars` - Your secrets (git-ignored)

## Variables

### Required

Configure in `secrets.auto.tfvars`:
```hcl
pm_api_url    = "https://192.168.10.5:8006/api2/json"
pm_user       = "root@pam"
pm_password   = "your_proxmox_password"

root_password = "container_root_password"
ip_prod = "192.168.10.51/24"
ip_test = "192.168.10.52/24"
```

### Optional (with defaults)
```hcl
cpu_cores            = 1                            # CPU cores
memory_mb            = 1024                         # RAM in MB
swap_mb              = 1024                         # Swap in MB
disk_size            = "20G"                        # Root filesystem size
ssh_public_key_path  = "~/.ssh/id_ed25519.pub"      # SSH public key path
ssh_private_key_path = "~/.ssh/id_ed25519"          # SSH private key path
```

## Outputs

After successful deployment:
- `container_id` - Proxmox VMID
- `container_ip` - Container IP address
- `ssh_connection` - SSH command to connect

## Notes

- Container is configured for Docker (AppArmor, capabilities)
- Root SSH access is disabled after provisioning
- Ansible user has passwordless sudo
- Auto-generated Ansible inventory