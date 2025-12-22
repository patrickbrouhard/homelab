# Rôle Ansible : stack_deployer

But : ce rôle déploie des stacks docker-compose à partir de templates. Utilisation prévue :

- définir `stacks` dans un playbook (recommandé) ou dans host_vars/group_vars
- chaque élément de stack est un dictionnaire avec les clés :
  - name : <nom de la stack> (utilisé comme projet compose)
  - compose_template : chemin vers le template relatif aux templates du rôle (optionnel)
  - env_template : chemin optionnel vers un template .env
  - data_dirs : liste optionnelle de sous-répertoires à créer sous docker_data_root/<stack>

Exemple via playbook :

```yaml
- hosts: docker
  become: true
  vars:
    stacks:
      - name: portainer
        compose_template: portainer/docker-compose.yml.j2
        data_dirs: [data]
  roles:
    - stack_deployer
```

Notes :
- Le rôle prend en charge l’analyse de docker_root pour découvrir les stacks si la variable stacks est vide
- Les templates sont rendus en utilisant les variables Ansible normales (par ex. docker_data_root)
- Utilisez les tags stacks et deploy pour cibler les tâches de déploiement

