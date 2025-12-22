# Scripts pour créer un template Proxmox et provisionner une VM (Terraform + Ansible)

> [!WARNING]
> Ne pas oublier de rendre exécutable avec `chmod 700` ou `chmod +x`.

## Contenu

* `scripts/create-proxmox-cloud-template.sh` — télécharger, customiser et convertir une image cloud Ubuntu en **template Proxmox**.
* `scripts/create-vm-web.sh` — lancer Terraform (Proxmox) puis provisionner la VM `web` avec Ansible.

---

# create-proxmox-cloud-template.sh

Créer une VM depuis une image cloud Ubuntu, l'adapter (qemu-guest-agent, nettoyage), configurer disque/EFI/cloud-init, convertir en template Proxmox.

**Usage**

```bash
./scripts/create-proxmox-cloud-template.sh [--vmid <id>] [--name <name>]
# Ex: ./scripts/create-proxmox-cloud-template.sh --vmid 9010 --name ubuntu-noble-cloud
```

**Options**

* `--vmid <id>`  — ID Proxmox (par défaut `9000`)
* `--name <name>` — nom VM (par défaut `ubuntu-cloud-noble`)
* `-h|--help` — aide

**Prérequis**

* Exécuter en `root`
* Répertoire IMG_DIR existant (`/var/lib/vz/template/iso`)
* Commandes disponibles : `qm`, `pvesm`, `wget`, `sha256sum`, `virt-customize`, `virt-sysprep` (installe `libguestfs-tools` si manquant)

**Comportement important**

* Verrouillage via `/var/lock/create-template.lock` (empêche exécutions concurrentes)
* Validation des variables `VMID` (numérique) et `VM_NAME` (caractères autorisés `A-Z a-z 0-9 . _ -`)
* Téléchargement + vérification SHA256 (max 5 tentatives)
* Nettoyage automatique et trap en cas d'erreur (affiche instructions pour détruire la VM échouée)
* Valeurs par défaut modifiables en début de script :

  * `IMG_URL`, `IMG_NAME`, `STORAGE`, `CISTORAGE`, `RAM=2048`, `CORES=2`, `DISK_SIZE=20G`, `BRIDGE=vmbr0`

---

# create-vm-web.sh

**But**
Déployer une VM via Terraform (dossier `terraform/proxmox`) puis provisionner la cible `web` avec Ansible.

**Usage**

```bash
./scripts/create-vm-web.sh
```

**Prérequis**

* `terraform` dans le `PATH`
* `ansible-playbook` dans le `PATH`
* Structure attendue : repo racine contenant `terraform/proxmox` et `ansible/playbooks/`
* Scripts exécutable (`chmod +x`)

**Étapes exécutées**

1. `terraform init -upgrade`
2. `terraform validate`
3. `terraform apply -auto-approve`
4. `ansible-playbook playbooks/bootstrap-linux-cloudinit.yml --limit web`
5. `ansible-playbook playbooks/web_docker_install.yml --limit web`
6. `ansible-playbook playbooks/web_docker_containers_install.yml --limit web`

---

# Exemples rapides

```bash
# rendre les scripts exécutables
chmod +x scripts/create-proxmox-cloud-template.sh scripts/create-vm-web.sh

# créer template (root)
sudo ./scripts/create-proxmox-cloud-template.sh --vmid 9100 --name ubuntu-noble

# déployer et provisionner la VM web (depuis la racine du repo)
./scripts/create-vm-web.sh
```

---

# Dépannage rapide

* Script 1 : erreur si `IMG_DIR` manquant — créer `/var/lib/vz/template/iso` ou ajuster la variable.
* Script 1 : si `qm`/`pvesm` manquant, vérifier exécution sur un Proxmox (ou installer outils).
* Script 1 : checksum invalide → vérifier connectivité réseau et URL image.
* Script 2 : message `Terraform manquant` ou `Ansible manquant` → installer et ajouter au `PATH`.
* Consulter la sortie d'erreur — le script affiche l'état et propose `qm destroy <VMID> --purge` si VM partiellement créée.

---

# Remarques

* Fichiers modifiables : variables en tête de `create-proxmox-cloud-template.sh`.
* Scripts conçus pour être idempotents autant que possible ; cependant, en cas d'échec manuel, vérifier et nettoyer les ressources Proxmox restantes.
