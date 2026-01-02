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
```bash
# 1. Create secrets file
cp secrets.yml.example secrets.yml
nano secrets.yml  # Edit: container_ip, db_password

# 2. Update inventory
cp inventory.ini.example inventory.ini
nano inventory.ini  # Edit: container_ip (must match OpenTofu)

# 3. Run playbook
ansible-playbook playbook.yml
```

## Configuration

### Required Variables

Configure in `secrets.yml`:
```yaml
container_ip: "192.168.10.51"  # Without /24 CIDR notation
db_password: "strong_password_here"
```
Generate secure password:
```bash
openssl rand -base64 32
```

### Inventory

Update `inventory.ini` with container IP:
```ini
[forgejo_server]
192.168.10.51 
```

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
ansible-playbook playbook.yml --tags forgejo

# Skip backups
ansible-playbook playbook.yml --skip-tags backup
```
## Useful Commands

### Check versions
```bash
# Forgejo version
ssh ansible@<container_ip> -p 2222 'sudo docker exec forgejo-app forgejo --version'

# PostgreSQL version
ssh ansible@<container_ip> -p 2222 'sudo docker exec forgejo-db psql --version'

# Docker version
ssh ansible@<container_ip> -p 2222 'docker --version'
```

## Important Notes

- ⚠️ **IP must match** OpenTofu's `container_ip` (without `/24`)
- Container must be already created by OpenTofu
- SSH keys must be configured (`~/.ssh/id_ed25519`)
- NAS mount required at `/mnt/share` on container

