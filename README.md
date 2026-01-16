[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.11+-FFDA18?logo=opentofu&logoColor=black)](https://opentofu.org/)
[![Ansible](https://img.shields.io/badge/Ansible-2.19+-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Forgejo](https://img.shields.io/badge/Forgejo-14.0+-FB923C?logo=forgejo&logoColor=white)](https://forgejo.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17+-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)

[![Debian](https://img.shields.io/badge/Debian-13+-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)
[![Proxmox](https://img.shields.io/badge/Proxmox-9+-E57000?logo=proxmox&logoColor=white)](https://www.proxmox.com/)

[![Forgejo Logo](./forgejo.webp)](https://forgejo.org)
# Forgejo-server (IaC)

Automated deployment of local Forgejo Git server on Proxmox LXC using OpenTofu and Ansible.

## Features
- 🚀 Automated LXC container creation (OpenTofu)
- 🐳 Docker-based Forgejo + PostgreSQL
- 📦 Automated daily backups to NAS
- 🔒 UFW firewall + SSH hardening
- 🌐 Nginx reverse proxy with self-signed SSL


## Quick Start

### Prerequisites
- [x] OpenTofu installed (`>= 1.11`)
- [x] Ansible installed (`>= 2.19`)
- [x] SSH keys generated (`~/.ssh/id_ed25519`)
- [x] Proxmox VE accessible (`>= 9.1`)
- [x] NAS mount at `/shared-storage/share` on Proxmox host

### Step 1: Deploy Infrastructure
See [opentofu/README.md](opentofu/README.md) for detailed configuration options.
```bash
cd opentofu
cp secrets.auto.tfvars.example secrets.auto.tfvars
nano secrets.auto.tfvars # Edit: pm_api_url, container_ip, root_password
tofu init
tofu apply
```

### Step 2: Configure Services
See [ansible/README.md](ansible/README.md) for detailed configuration options.
```bash
cd ../ansible
cp secrets.yml.example secrets.yml
nano secrets.yml # Edit: db_password, container_ip
cp inventory.ini.example inventory.ini
nano inventory.ini # Edit: container_ip (MUST MATCH Step 1!)
ansible-playbook playbook.yml
```

### Step 3: Access Forgejo
- **Web UI:** `https://<container_ip>`
- **System SSH:** `ssh ansible@<container_ip> -p 2222`
- **Git SSH:** Port `22` (configure in Forgejo web UI)

## Configuration

### ⚠️ Important: IP Address Matching
The `container_ip` **must be identical** in both configs:
- `opentofu/secrets.auto.tfvars` → `container_ip = "192.168.10.51/24"`
- `ansible/secrets.yml` → `container_ip: "192.168.10.51"` (no /24)

### Password Generation

```bash
openssl rand -base64 32
```

## Backups
- **Schedule:** Daily at 3:00 AM (± 30min randomized delay)
- **Location:** `/opt/backups/forgejo/`
- **Retention:** 10 days


### Manual backup/restore
```bash
ssh ansible@<container_ip> -p 2222

sudo /opt/forgejo/forgejo-backup.sh

sudo /opt/forgejo/forgejo-restore.sh <backup-file>
```

## Maintenance

### Check for Updates

Monitor component versions to track server lifecycle:
```bash
# Setup
cp scripts/check-updates.sh.example scripts/check-updates.sh
# Edit SERVER variable in the script
nano scripts/check-updates.sh

# Run
./scripts/check-updates.sh
```

Output shows current vs latest versions for:
- Forgejo
- PostgreSQL
- Docker
- Nginx
- Debian


## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.