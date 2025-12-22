#!/usr/bin/env bash

### ===============================
### Script pour créer un template de VM
### /usr/local/bin/create-proxmox-cloud-template.sh
### faire chmod 700 nom_du_script.sh -> accessible et exécutable uniquement par le propriétaire (lecture/écriture/exécution)
### ===============================


# Empêcher deux executions simultanées
exec 200>/var/lock/create-template.lock
flock -n 200 || {
    echo "Script déjà en cours d'exécution"
    exit 1
}

# set -e → le script s’arrête dès qu’une commande échoue.
# -u  le script s’arrête si tu utilises une variable non définie
# -o pipefail → une erreur dans un pipe fait échouer toute la chaîne.
set -euo pipefail

### ===============================
### Paramètres + Fonctions
### ===============================

IMG_DIR="/var/lib/vz/template/iso"
IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMG_NAME="noble-server-cloudimg-amd64.img"
SHA256SUM_FILE_URL="https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
MAX_DOWNLOAD_TRIES="5"
VMID="9000"
VM_NAME="ubuntu-cloud-noble"

STORAGE="local-lvm"        # stockage pour le disque
CISTORAGE="local-lvm"      # stockage pour le cloud-init
RAM="2048"
CORES="2"
DISK_SIZE="20G"
BRIDGE="vmbr0"

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --vmid <id>        VMID Proxmox (par défaut: $VMID)
  --name <name>      Nom de la VM (par défaut: $VM_NAME)
  -h, --help         Afficher cette aide

Exemple:
  $0 --vmid 9010 --name ubuntu-noble-cloud
EOF
}

# Analyse des arguments et options passés au script
while [ "$#" -gt 0 ]; do
    case "$1" in
        --vmid)
            VMID="${2:-}"
            shift 2
            ;;
        --name)
            VM_NAME="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "❌ Option inconnue: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# validation flag VMID
if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
    echo "❌ VMID invalide: '$VMID' (doit être numérique)" >&2
    exit 1
fi

# Validation flag VM_NAME
if ! [[ "$VM_NAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "❌ Nom de VM invalide: '$VM_NAME'" >&2
    echo "   Caractères autorisés: lettres, chiffres, . _ -" >&2
    exit 1
fi

# Fonction de nettoyage appelée automatiquement en cas d'erreur.
cleanup() {
    # éviter que cleanup déclenche encore trap ERR
    set +euo pipefail

    local exit_code=${1:-$?}
    echo ""
    echo "=========================================="
    echo "❌ Erreur: $exit_code"
    echo "=========================================="

    if [ -n "${VMID:-}" ] && command -v qm >/dev/null 2>&1; then
        if qm status "$VMID" >/dev/null 2>&1; then
            qm set "$VMID" --name "FAIL-$(date +%H%M%S)-$VM_NAME" 2>/dev/null || true
            qm stop "$VMID" 2>/dev/null || true
            echo "VM marquée comme défaillante"
            echo ""
            echo "Pour détruire: qm destroy $VMID --purge"
            echo ""
            show_vm_list "$VMID" || true
        else
            echo "La VM $VMID n'existe pas (ou qm inaccessible)."
        fi
    fi
}
# Active le déclenchement de cleanup() si une commande échoue
trap 'cleanup $?' ERR

cleanup_tmp_files() {
    rm -f "${IMG_DIR}/SHA256SUMS" "${IMG_DIR}/${IMG_NAME}.sha256"
}
trap cleanup_tmp_files EXIT


show_vm_list() {
    local target_id="$1"
    if command -v qm >/dev/null 2>&1; then
        qm list | awk -v id="$target_id" '
            NR==1 {print " " $0; next}
            $1 == id {print ">" $0}
            $1 != id {print " " $0}
        '
    else
        echo "qm non disponible pour lister les VMs."
    fi
}

check_storage_exists() {
    local storage="$1"
    if ! pvesm status | awk '{print $1}' | grep -qx "$storage"; then
        echo "❌ Le stockage '$storage' n'existe pas." >&2
        exit 1
    fi
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

wget_download_file() {
    local file_url="$1"
    local out_file="$2"

    wget \
        --tries=5 \
        --timeout=30 \
        --waitretry=5 \
        --retry-connrefused \
        -O "$out_file" \
        "$file_url"

}


get_checksum() {
    local url="$1"
    local out="${IMG_NAME}.sha256"

    if ! wget_download_file "$url" SHA256SUMS; then
        echo "❌ Téléchargement du fichier SHA256SUMS impossible" >&2
        return 1
    fi

    if ! grep -E -- " [*]?${IMG_NAME}$" SHA256SUMS > "$out"; then
        echo "❌ Impossible de trouver $IMG_NAME dans SHA256SUMS" >&2
        rm -f SHA256SUMS
        return 1
    fi

    return 0
}

### ===============================
### Vérifications
### ===============================

if [ ! -d "$IMG_DIR" ]; then
    echo "❌ Le répertoire $IMG_DIR n'existe pas. Arrêt du script."
    exit 1
fi

# on doit être root pour executer
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en root." >&2
    exit 1
fi

# Vérifie que toutes les commandes nécessaires sont disponibles
for cmd in qm pvesm wget sha256sum; do
  if ! has_cmd "$cmd"; then
    echo "❌ '$cmd' manquant. Veuillez l'installer." >&2
    exit 1
  fi
done

# Vérification du stockage principal
check_storage_exists "$STORAGE"
check_storage_exists "$CISTORAGE"

# installer outils de customisation si manquant
if ! has_cmd virt-customize || ! has_cmd virt-sysprep; then
  echo "==> Installation de libguestfs-tools"
  apt update -y
  apt install -y libguestfs-tools
fi

# Vérifie si l'ID est déjà prise (après s'être assuré que qm est présent)
if qm status "$VMID" >/dev/null 2>&1; then
    echo "❌ L'ID $VMID est déjà utilisée."
    echo ""
    show_vm_list "$VMID"
    exit 1
fi

### ===============================
### Script
### ===============================

cd "$IMG_DIR"

## téléchargement + vérification
get_checksum "$SHA256SUM_FILE_URL" || exit 1
attempt=1
while [ "$attempt" -le "$MAX_DOWNLOAD_TRIES" ]; do
    echo "==> Tentative $attempt/$MAX_DOWNLOAD_TRIES (checksum)"

    if ! wget_download_file "$IMG_URL" "$IMG_NAME"; then
        echo "❌ Échec téléchargement (réseau)" >&2
        exit 1
    fi

    if sha256sum --check --status "${IMG_NAME}.sha256"; then
        echo "✔️ Checksum OK"
        break
    fi

    echo "❌ Checksum invalide"
    attempt=$((attempt+1))
done

if [ "$attempt" -gt "$MAX_DOWNLOAD_TRIES" ]; then
    echo "❌ Échec : checksum invalide après $MAX_DOWNLOAD_TRIES tentatives" >&2
    exit 1
fi

# Customisation de l'image
echo "==> Customisation de l'image avec virt-customize…"
virt-customize -a "$IMG_NAME" --install "qemu-guest-agent" --firstboot-command "systemctl enable qemu-guest-agent"

# Nettoyage avec virt-sysprep 
echo "==> Nettoyage de l'image avec virt-sysprep…"
virt-sysprep -a "$IMG_NAME" --operations machine-id,bash-history,logfiles,tmp-files,dhcp-client-state,package-manager-cache,ssh-hostkeys

### Creation de la VM
echo "==> Création de la VM $VMID"
qm create "$VMID" \
  --name "$VM_NAME" \
  --memory "$RAM" \
  --cores "$CORES" \
  --cpu host \
  --ostype l26 \
  --agent enabled=1

# Active le support NUMA pour de meilleures performances
qm set "$VMID" --numa 1

echo "==> Import et attachement du disque…"
qm importdisk "$VMID" "$IMG_NAME" "$STORAGE"
qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "${STORAGE}:vm-${VMID}-disk-0,ssd=1,discard=on"

echo "==> ajout du BIOS EFI"
qm set "$VMID" \
  --bios ovmf \
  --machine q35 \
  --efidisk0 "${STORAGE}:1"

echo "==> Ajout du lecteur Cloud-Init…"
qm set "$VMID" --ide2 "${CISTORAGE}:cloudinit,media=cdrom"

## Réseau
echo "==> Configuration Réseau DHCP"
qm set "$VMID" --net0 virtio,bridge="$BRIDGE"
qm set "$VMID" --ipconfig0 ip=dhcp

echo "==> Configuration du boot…"
qm set "$VMID" --boot order=scsi0

echo "==> Activation de la console série…"
qm set "$VMID" --serial0 socket --vga serial0

echo "==> Redimensionnement du disque à $DISK_SIZE…"
qm resize "$VMID" scsi0 "$DISK_SIZE"

### ===============================
echo "==> Vérifications finales..."
### ===============================

if ! qm status "$VMID" >/dev/null 2>&1; then
    echo "ERREUR : la VM $VMID n'existe pas." >&2
    exit 1
fi

nb_erreurs=0

if ! qm config "$VMID" | grep -q "scsi0"; then
    echo "ERREUR : aucun disque scsi0 trouvé." >&2
    nb_erreurs=$((nb_erreurs+1))
fi

if ! qm config "$VMID" | grep -q "efidisk0"; then
    echo "ERREUR : aucun efidisk0 trouvé." >&2
    nb_erreurs=$((nb_erreurs+1))
fi

if ! qm config "$VMID" | grep -q "ide2"; then
    echo "ERREUR : aucun lecteur cloud-init (ide2) trouvé." >&2
    nb_erreurs=$((nb_erreurs+1))
fi

if [ "$nb_erreurs" -gt 0 ]; then
    echo "Il y a eu un problème: $nb_erreurs erreurs détectées"
    exit 1
fi

echo "==> Vérification OK ✔️"
echo "==> Conversion en template…"
qm template "$VMID"

echo ""
echo "#########################################################"
echo " ✅ Template Proxmox créé avec succès !"
qm config "$VMID"
echo "#########################################################"
