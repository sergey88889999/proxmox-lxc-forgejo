# ============================================================================
# Forgejo Git Server Infrastructure
# ============================================================================
# Deploys a containerized Forgejo instance on Proxmox with:
# - Debian 13 LXC container
# - PostgreSQL database
# - NAS backup mount
# - Docker support enabled
# ============================================================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc06"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

# ============================================================================
# Variables
# ============================================================================

# Provider variables (loaded from secrets.auto.tfvars)
variable "pm_api_url" { 
  type        = string
  description = "Proxmox API URL"
}

variable "pm_user" { 
  type        = string
  description = "Proxmox user"
}

variable "pm_password" { 
  type        = string
  description = "Proxmox password"
  sensitive   = true  
}

variable "pm_tls_insecure" { 
  type        = bool
  description = "Skip TLS verification"
  default     = false
}

# Container Configuration (loaded from secrets.auto.tfvars)
variable "root_password" {
  type        = string
  description = "Password root for LXC"
  sensitive   = true
}
variable "container_ip" {
  type        = string
  description = "Container IP address with CIDR notation"
  validation {
    condition     = can(cidrhost(var.container_ip, 0))
    error_message = "Container IP must be in CIDR notation (e.g., 192.168.10.51/24)"
  }
}

# SSH Configuration
variable "ssh_public_key_path" {
  type        = string
  description = "Path to SSH public key for ansible user"
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  type        = string
  description = "Path to SSH private key for provisioning"
  default     = "~/.ssh/id_ed25519"
}

# Container Resources
variable "cpu_cores" {
  type        = number
  description = "Number of CPU cores"
  default     = 1
}

variable "memory_mb" {
  type        = number
  description = "Memory in MB"
  default     = 1024
}

variable "swap_mb" {
  type        = number
  description = "Swap in MB"
  default     = 1024
}

variable "disk_size" {
  type        = string
  description = "Root filesystem size"
  default     = "20G"
}

# ============================================================================
# Provider Configuration
# ============================================================================
provider "proxmox" {
  pm_api_url      = var.pm_api_url
  pm_user         = var.pm_user
  pm_password     = var.pm_password
  pm_tls_insecure = var.pm_tls_insecure
}

# ============================================================================
# Local Values
# ============================================================================

locals {
  # Extract Proxmox host from API URL
  pm_host    = regex("://([^:/]+)", var.pm_api_url)[0]
  # Calculate gateway IP from container CIDR
  gateway_ip = cidrhost(var.container_ip, 1)
 
  # Extract clean IP without CIDR for SSH
  container_ip_clean = split("/", var.container_ip)[0]

  # SSH Configuration
  ssh_port = 2222

  # Ansible user configuration
  ansible_user = "ansible"
}

resource "proxmox_lxc" "forgejo_server" {
  target_node  = "proxmox"
  hostname     = "forgejo-server"
  ostemplate   = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
  password     = var.root_password
  unprivileged = true
  onboot       = true  # Autostart on boot
  start        = true
  description = "Git-Server (Forgejo+PostgreSQL) IP ${var.container_ip}"

  # Resources
  cores  = var.cpu_cores
  memory = var.memory_mb
  swap   = var.swap_mb

  # Container features for Docker support
  features {
    nesting = true
    fuse    = true
    keyctl  = true
  }

  # Root filesystem
  rootfs {
    storage = "local-lvm"
    size    = var.disk_size
  }

   # Network configuration
  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = var.container_ip
    gw     = local.gateway_ip
    ip6    = "auto"
  }

 # NAS backup mount
   mountpoint {
    key    = "0"
    slot   = 0
    mp     = "/mnt/share"
    volume = "/shared-storage/share"
    acl    = true
  }
  
  ssh_public_keys = file(var.ssh_public_key_path)

  # SSH connection for provisioning
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
    host        = local.container_ip_clean
    timeout     = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "sleep 10",
      "echo '=== Installing base packages'",
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y sudo curl locales",
      
      "echo '=== Creating ${local.ansible_user} user'",
      "useradd -m -s /bin/bash ${local.ansible_user} || true",
      "mkdir -p /home/${local.ansible_user}/.ssh",
      "cp /root/.ssh/authorized_keys /home/${local.ansible_user}/.ssh/authorized_keys",
      "chown -R ${local.ansible_user}:${local.ansible_user} /home/${local.ansible_user}/.ssh",
      "chmod 700 /home/${local.ansible_user}/.ssh",
      "chmod 600 /home/${local.ansible_user}/.ssh/authorized_keys",
      "echo '${local.ansible_user} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${local.ansible_user}",
      "chmod 0440 /etc/sudoers.d/${local.ansible_user}",
            
      "rm -rf /root/.ssh/authorized_keys",
      "echo '=== Removing root SSH access'",
      
      "echo '=== Changing SSH port to ${local.ssh_port}'",
      "mkdir -p /etc/systemd/system/ssh.socket.d",
      "cat > /etc/systemd/system/ssh.socket.d/override.conf << 'EOF'",
      "[Socket]",
      "ListenStream=",
      "ListenStream=${local.ssh_port}",
      "EOF",     
      
      # Changing sshd_config
      "echo 'Port ${local.ssh_port}' > /etc/ssh/sshd_config.d/port.conf",
      "chmod 644 /etc/ssh/sshd_config.d/port.conf",      
      
      "echo '=== Applying SSH configuration'",
      "systemctl daemon-reload",
      "(sleep 2; systemctl restart ssh.socket) &",
    ]
  }

}

# ============================================================================
# Docker Support Configuration
# ============================================================================

resource "local_file" "lxc_docker_config" {
  filename = "${path.module}/lxc_docker.conf"
  file_permission = "0644"
  content  = <<-EOT
    lxc.cap.drop: 
    lxc.mount.auto: proc:rw sys:rw
    lxc.apparmor.raw: mount fstype=overlay,
    lxc.apparmor.raw: mount fstype=fuse,
  EOT
}

resource "null_resource" "forgejo_docker_tweak" {
  depends_on = [
    proxmox_lxc.forgejo_server, 
    local_file.lxc_docker_config
  ]
  
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "=== Uploading Docker configuration to Proxmox host"
      scp -o StrictHostKeyChecking=no ${local_file.lxc_docker_config.filename} root@${local.pm_host}:/tmp/lxc_docker.conf
      echo "=== Applying Docker configuration to LXC"
      ssh -o StrictHostKeyChecking=no root@${local.pm_host} bash <<'REMOTE_EOF'
        set -e
        CONF="/etc/pve/lxc/${proxmox_lxc.forgejo_server.vmid}.conf"
        
        echo "=== Cleaning up old Docker-related settings..."
        sed -i '/^lxc\.apparmor\./d; /^lxc\.cgroup2\./d; /^lxc\.cap\.drop:/d; /^lxc\.mount\.auto/d' "$CONF"
        
        echo "=== Adding new Docker settings..."
        cat /tmp/lxc_docker.conf >> "$CONF"
        rm /tmp/lxc_docker.conf

        echo "=== Restarting container..."
        pct stop ${proxmox_lxc.forgejo_server.vmid} || true
        sleep 2
        pct start ${proxmox_lxc.forgejo_server.vmid}
        
        echo "=== Docker configuration applied successfully"
      REMOTE_EOF
    EOT
  }
}


# ============================================================================
# Outputs
# ============================================================================

output "container_id" {
  value       = proxmox_lxc.forgejo_server.vmid
  description = "LXC container ID (VMID)"
}

output "container_ip" {
  value       = local.container_ip_clean
  description = "Container IP address"
}

output "ssh_connection" {
  value       = "ssh ${local.ansible_user}@${local.container_ip_clean} -p ${local.ssh_port}"
  description = "SSH connection command for ansible user"
}

output "container_status" {
  value       = "Container deployed successfully. Ready for Ansible provisioning."
  description = "Deployment status"
}