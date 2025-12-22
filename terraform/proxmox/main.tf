terraform {
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc06"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token
  pm_tls_insecure     = true
}

resource "proxmox_vm_qemu" "vms" {
  for_each = var.vm_configs

  vmid        = each.value.vmid
  name        = each.value.name
  target_node = "pve"
  agent       = 1
  description = each.value.description
  clone_id    = each.value.template_vmid
  full_clone  = each.value.full_clone
  qemu_os     = "l26"
  os_type     = "ubuntu"

  # CPU / mémoire
  cpu {
    sockets = each.value.sockets
    cores   = each.value.cores
    type    = "host"
    numa    = each.value.numa
  }
  memory = each.value.memory

  # matériel / firmware / SCSI
  scsihw  = "virtio-scsi-pci"
  bios    = "ovmf"
  machine = "q35"

  # options de démarrage
  boot               = "order=scsi0"
  start_at_node_boot = each.value.start_at_node_boot # la VM doit-elle démarrer automatiquement quand la node pve boot ?
  vm_state           = each.value.vm_state           # "running" ou "stopped"
  automatic_reboot   = each.value.automatic_reboot

  # cloud-init configuration
  ciuser    = each.value.ciuser
  ipconfig0 = each.value.ipconfig0
  skip_ipv6 = true                    # Désactiver IPv6
  sshkeys   = var.default_ssh_pub_key # Clé SSH pour accès initial

  # Configuration série pour console graphique via noVNC / SPIC
  serial {
    id   = 0
    type = "socket"
  }

  # VGA reliée au port série
  vga {
    type = "serial0"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = each.value.bridge
  }

  disks {
    ide {
      ide2 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          storage    = "local-lvm"
          size       = each.value.disk_size # identique au template : verifier si le bug unused disk apparait
          discard    = true
          emulatessd = true
        }
      }
    }
  }
}
