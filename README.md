# Todo App DevOps — MediShop

Déploiement d'une Todo App sur AWS avec Terraform, Ansible et GitHub Actions.

**Commence par lire `GUIDE-PEDAGOGIQUE.md`** — il explique chaque fichier de ce dépôt et te prépare pour la soutenance orale.

## Structure du dépôt

```
terraform/        -> Infrastructure AWS (VPC, EC2, Security Groups)
ansible/           -> Configuration des serveurs (Docker, Nginx)
app/backend/        -> API Node.js/Express + Dockerfile
app/frontend/       -> Site statique HTML/JS + Dockerfile
db/                 -> docker-compose pour PostgreSQL (image officielle)
.github/workflows/  -> Pipeline CI/CD GitHub Actions
```

## Démarrage rapide

1. `cd terraform && cp terraform.tfvars.example terraform.tfvars` puis remplis tes valeurs.
2. `terraform init && terraform apply`
3. `cp ansible/inventory.ini.example ansible/inventory.ini` puis remplis les IPs obtenues.
4. `ansible-playbook -i ansible/inventory.ini ansible/playbook.yml`
5. Lance les conteneurs (DB, puis Back, puis Front) — voir `GUIDE-PEDAGOGIQUE.md` section 9.
6. Configure les GitHub Secrets, pousse du code sur `main`, observe le déploiement automatique.

## Documentation complète

Voir `GUIDE-PEDAGOGIQUE.md`.
