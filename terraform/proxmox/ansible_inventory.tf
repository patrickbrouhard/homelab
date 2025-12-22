locals {
  web_hosts = {
    for _, vm in var.vm_configs :
    vm.name => {
      ansible_host = regex("ip=([0-9.]+)", vm.ipconfig0)[0] # fonction terraform : regex(pattern, string)
      ansible_user = vm.ciuser
    }
  }

  ansible_inventory_web = {
    web = {
      hosts = local.web_hosts
    }
  }
}

resource "local_file" "ansible_inventory_web" {
  filename = "${path.module}/../../ansible/inventory/web.generated.yml"
  content  = yamlencode(local.ansible_inventory_web)
}
