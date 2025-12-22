#!/usr/bin/env bash
set -euo pipefail

command -v terraform >/dev/null || { echo "Terraform manquant"; exit 1; }
command -v ansible-playbook >/dev/null || { echo "Ansible manquant"; exit 1; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR/terraform/proxmox"

echo "=== Terraform init ==="
terraform init -upgrade

echo "=== Terraform validate ==="
terraform validate

echo "=== Terraform apply ==="
terraform apply -auto-approve

cd "$ROOT_DIR/ansible"

echo "=== Ansible bootstrap ==="
ansible-playbook playbooks/bootstrap-linux-cloudinit.yml --limit web

echo "=== Ansible provisioning ==="
ansible-playbook playbooks/web_docker_install.yml --limit web
ansible-playbook playbooks/web_docker_containers_install.yml --limit web

echo "=== Terminated ==="
