# Homelab: Provisionnement Proxmox + Ansible + Docker

Ce projet automatise la création et la configuration d’une VM Proxmox depuis zéro :
- création d’un template (script),
- création de la VM avec **Terraform** (provider Proxmox),
- provisioning et installation de Docker avec **Ansible**.

## Objectifs
- Présenter une stack IaC reproductible pour un homelab.
- Séparer la phase **provisionnement** (Terraform) de la phase **configuration** (Ansible).
- Fournir des rôles Ansible idempotents pour la maintenance des conteneurs.

## Prérequis
- Proxmox VE accessible (API).
- Terraform >= 1.7.0.
- Ansible (et Python3) sur la machine de contrôle.
- Clé SSH pour accès aux VMs.
- (Optionnel) gestionnaire de secrets (Ansible Vault / HashiCorp Vault).

## Structure (extrait)

```
/terraform/proxmox      # définitions Terraform & exemple de credentials
/ansible                # playbooks, inventory, roles (docker, hardening, notify_telegram...)
/scripts                # scripts de création de template, bootstrap...
```

## Sujets

* Infrastructure as Code (Terraform / provider Proxmox)
* Provisioning et configuration (Ansible — rôles idempotents)
* Automatisation de déploiement et hardening système
* Conteneurisation + gestion Docker
* "Roles as libraries, Playbooks as workflows"

---

