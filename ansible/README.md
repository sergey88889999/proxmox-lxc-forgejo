[![Ansible](https://img.shields.io/badge/Ansible-2.19+-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
# Ansible Configuration

Automated provisioning of Forgejo Git server with PostgreSQL, Nginx, and backups.

## Overview

Configures a Debian 13 LXC container with:
- Base system setup (timezone, locales, packages)
- Docker CE for running containers
- Forgejo + PostgreSQL stack
- Nginx reverse proxy with self-signed SSL
- Daily automated backups to NAS
- Security hardening (UFW firewall, SSH)

## Quick Start

### Step 1: Prepare Inventory
> [!IMPORTANT]
> The `inventory.ini` file is **automatically generated** by OpenTofu. Ensure you have run `tofu apply` in the `opentofu/` directory first.

Verify that the file exists and contains the correct IP addresses:
```bash
cat inventory.ini
```
### Step 2. Create secrets file
```bash
cp secrets.yml.example secrets.yml
nano secrets.yml  # Edit: db_password
```
### Step 3. Run playbook
```bash 
ansible-playbook playbook.yml -l prod    # or test
```

## Configuration

### Required Variables

Configure in `secrets.yml`:
```yaml
db_password: "strong_password_here"
```
Generate secure password:
```bash
openssl rand -base64 32
```

## Playbook

## Roles

Playbook executes roles in this order:

1. **base** - System setup (hosts, timezone, locales, packages)
2. **docker** - Install Docker CE for LXC
3. **forgejo** - Deploy Forgejo + PostgreSQL via docker-compose
4. **nginx** - Install Nginx reverse proxy with SSL
5. **backup** - Configure automated backups (systemd timer)
6. **security** - UFW firewall + SSH hardening

## Selective Deployment

Run specific roles using tags:
```bash
# Only update Forgejo
ansible-playbook playbook.yml --tags forgejo -l test

# Skip backups
ansible-playbook playbook.yml --skip-tags backup -l test
```
## Useful Commands

### Check for Updates

Monitor component versions to track server lifecycle:
```bash
# Setup
cp scripts/check-updates.sh.example scripts/check-updates.sh
# Edit SERVER variable in the script: ip + ssh port
nano scripts/check-updates.sh

# Run
./scripts/check-updates.sh
```

## Important Notes

- ⚠️ **IP must match** OpenTofu's `container_ip` (without `/24`)
- Container must be already created by OpenTofu
- SSH keys must be configured (`~/.ssh/id_ed25519`)
- NAS mount required at `/mnt/share` on container

