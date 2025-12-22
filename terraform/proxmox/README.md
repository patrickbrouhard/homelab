# Terraform - Déploiement de VMs sur Proxmox

Ce projet Terraform permet de déployer automatiquement des machines virtuelles sur un cluster Proxmox VE à partir de templates cloud-init.


## Utilisation

### Initialisation (première fois uniquement)

```bash
terraform init
```

Télécharge le provider Proxmox et initialise le projet.

### Vérifier ce qui va être créé

```bash
terraform plan
```

Affiche un aperçu des ressources qui seront créées/modifiées/détruites.

### Déployer les VMs

```bash
terraform apply
```

Faire `terraform apply -auto-approve` pour ne pas avoir à confirmer.

### Voir l'état actuel

```bash
# Liste des ressources
terraform state list

# Détails d'une VM
terraform state show 'proxmox_vm_qemu.vms["serveur-symfony"]'
```

### Détruire une VM

```bash
# Détruire uniquement serveur-symfony
terraform destroy -target=proxmox_vm_qemu.vms[\"serveur-symfony\"]

# Détruire toutes les VMs
terraform destroy
```

## Personnalisation

### Modifier les specs matérielles

Dans `vms.auto.tfvars`, ajuster :
- `memory` : RAM en Mo (2048 = 2 Go)
- `cores` : Nombre de cœurs CPU
- `sockets` : Nombre de sockets CPU (généralement 1)

### Changer le réseau

Modifier `ipconfig0` :
```terraform
ipconfig0 = "ip=192.168.1.200/24,gw=192.168.1.1"
#              ^IP statique   ^masque ^passerelle
```

### Utiliser un autre template

Changer `template_vmid` pour pointer vers un autre template Proxmox.

### Ajouter un disque supplémentaire

Dans `main.tf`, section `disks.scsi`, ajouter :
```terraform
scsi1 {
  disk {
    storage = "local-lvm"
    size    = "50G"
  }
}
```

## Dépannage

### Erreur : "API token authentication failed"

Vérifier que :
- Le token dans `credentials.auto.tfvars` est correct
- Le token n'a pas expiré
- "Privilege Separation" est décoché dans Proxmox

### Erreur : "template not found"

Vérifier que le VMID du template (`template_vmid`) existe bien dans Proxmox.

### VM créée mais pas accessible en SSH

1. Vérifier que cloud-init a bien terminé :
   ```bash
   # Dans Proxmox, console de la VM
   cloud-init status --wait
   ```

2. Vérifier que la clé SSH est correcte dans `credentials.auto.tfvars`

3. Vérifier la configuration réseau dans Proxmox (firewall, VLAN, etc.)

### Conflit de VMID

Si le VMID est déjà utilisé dans Proxmox, changer le `vmid` dans `vm_configs`.

## Sécurité

- ⚠️ **Ne jamais commiter** `credentials.auto.tfvars` dans Git
- Les tokens API Proxmox doivent être traités comme des mots de passe
- Utiliser des clés SSH au lieu de mots de passe pour les VMs
- Régénérer les tokens régulièrement

## Ressources utiles

- [Documentation Terraform Provider Proxmox](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)
- [Documentation Proxmox VE](https://pve.proxmox.com/pve-docs/)
- [Documentation Cloud-Init](https://cloudinit.readthedocs.io/)
