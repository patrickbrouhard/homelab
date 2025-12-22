vm_configs = {
  serveur_symfony = {
    vmid               = 505
    name               = "serveur-symfony"
    description        = "Serveur Symfony déployé par Terraform"
    memory             = 2048
    vm_state           = "running"
    start_at_node_boot = false
    automatic_reboot   = true
    ipconfig0          = "ip=192.168.1.200/24,gw=192.168.1.1"
    ciuser             = "ubuntu"
    sockets            = 1
    cores              = 2
    numa               = true
    bridge             = "vmbr0"
    disk_size          = "20G"
    template_vmid      = 9000
    full_clone         = true
  }
  # ajouter d'autres clés ici pour créer d'autres VMs
}
