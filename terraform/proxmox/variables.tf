variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token" {
  type = string
}

variable "default_ssh_pub_key" {
  type = string
}

# Map de configuration pour déployer plusieurs VMs
variable "vm_configs" {
  type = map(object({
    vmid               = number
    name               = string
    description        = string
    memory             = number
    vm_state           = string
    start_at_node_boot = bool
    automatic_reboot   = bool
    ipconfig0          = string # Config réseau (ex: "ip=192.168.1.200/24,gw=192.168.1.1")
    ciuser             = string # Utilisateur créé par cloud-init
    sockets            = number
    cores              = number
    numa               = bool
    bridge             = string
    disk_size          = string # "20G", "50G", etc.
    template_vmid      = number
    full_clone         = bool
  }))
}
