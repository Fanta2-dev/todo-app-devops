# Guide pédagogique final — TP DevOps : Todo App MediShop sur AWS

> Version mise à jour après le déploiement réel complet. Ce document reflète ce qui a **vraiment fonctionné**, avec les vrais problèmes rencontrés et leurs solutions — exactement ce qu'il te faut pour la soutenance.

---

## 0. Vue d'ensemble : les 3 piliers

- **Terraform** crée l'infrastructure AWS (réseau, serveurs).
- **Ansible** configure ces serveurs (installe Docker, Nginx).
- **GitHub Actions** déploie automatiquement le code à chaque push.

Phrase à retenir : **"Terraform crée les machines, Ansible les configure, GitHub Actions déploie le code dessus."**

---

## 1. Architecture finale réellement déployée

```
Internet
   │
   │ HTTP(S)
   ▼
┌─────────────────────────────────────────────┐
│  VPC (10.0.0.0/16) — 2 zones de disponibilité │
│                                                │
│  Zone A (eu-west-3a)     Zone B (eu-west-3b)  │
│  ┌──────────────────┐    ┌──────────────────┐ │
│  │ Sous-réseau public│    │ Sous-réseau public│ │ (prêt, pas d'instance)
│  │  - Front (Nginx +  │    │                  │ │
│  │    conteneur front)│    └──────────────────┘ │
│  │  - NAT Gateway     │                         │
│  └──────────────────┘    ┌──────────────────┐ │
│  ┌──────────────────┐    │ Sous-réseau privé │ │ (prêt, pas d'instance)
│  │ Sous-réseau privé  │    └──────────────────┘ │
│  │  - Back (API)      │                         │
│  │  - DB (PostgreSQL) │                         │
│  └──────────────────┘                          │
└─────────────────────────────────────────────┘
```

### Pourquoi une instance NAT ?

Ce n'était **pas prévu au départ**, mais on l'a découvert nécessaire en pratique : le Back et la DB, en sous-réseau privé, ne pouvaient pas faire `apt update` pour installer Docker, car ils n'avaient **aucune route vers Internet** (volontairement, pour la sécurité). La solution standard payante est un **NAT Gateway** managé par AWS, mais elle facture dès la première minute. On a utilisé à la place une **instance NAT** — une simple EC2 `t3.micro` (gratuite dans le tier gratuit) configurée pour relayer le trafic sortant du réseau privé vers Internet, sans jamais accepter de connexions entrantes depuis Internet.

**Question d'oral probable** : *"Pourquoi Back/DB ont-ils quand même accès à Internet si vous vouliez les isoler ?"* → Réponse : accès **sortant uniquement** (pour les mises à jour et téléchargements), jamais **entrant** — Internet ne peut toujours pas initier de connexion vers eux. C'est exactement la distinction entre "isolé" et "invisible depuis Internet".

---

## 2. Pourquoi 2 zones de disponibilité, mais des instances sur une seule ?

Consigne du prof (donnée oralement, illustrée par l'exemple Dakar/Thiès) : prévoir la haute disponibilité. Le réseau (sous-réseaux) est dupliqué sur 2 zones (`eu-west-3a` et `eu-west-3b`), **gratuitement** (les sous-réseaux ne coûtent rien).

**Ce qui n'a volontairement pas été fait** : dupliquer les instances elles-mêmes. Une vraie haute disponibilité demanderait un Load Balancer (facturé dès la première minute) et poserait la question de la réplication de la base de données (RDS Multi-AZ, hors budget et hors scope "Docker sur EC2" du sujet).

**Phrase à donner à l'oral** :
> "J'ai conçu le réseau sur 2 zones de disponibilité pour préparer la haute disponibilité. Pour ce TP, avec un budget tier gratuit, je n'ai pas dupliqué les instances — ça demanderait un Load Balancer et un NAT Gateway managé, tous deux facturés dès la première minute d'usage. En conditions de production, l'étape suivante serait de dupliquer Front et Back derrière un Application Load Balancer, et migrer la DB vers RDS Multi-AZ."

---

## 3. Terraform : fichiers finaux

```
terraform/
├── main.tf              → provider AWS
├── variables.tf          → variables déclarées (region, instance_type, key_pair_name, admin_ip)
├── terraform.tfvars       → tes valeurs réelles (jamais commité)
├── vpc.tf                 → VPC + 4 sous-réseaux (2 zones × public/privé) + IGW + routage public
├── security_groups.tf      → 3 Security Groups (front/back/db) + règle SSH GitHub Actions
├── nat.tf                   → instance NAT + sa table de routage privée
├── ec2.tf                    → 3 instances (front/back/db)
└── outputs.tf                 → IPs affichées
```

### Pièges rencontrés et corrigés (bon matériel pour l'oral)

| Piège | Cause | Correction |
|---|---|---|
| `terraform plan` redemande les variables au clavier | Faute de casse : `Key_pair_name` au lieu de `key_pair_name` dans `terraform.tfvars` | Terraform est sensible à la casse — toujours vérifier l'orthographe exacte entre `variables.tf` et `terraform.tfvars` |
| Erreur "Invalid security group description" | Apostrophes et accents interdits par AWS dans les champs `description` des Security Groups | Toutes les descriptions réécrites sans accents ni apostrophes |
| `InvalidKeyPair.NotFound` | La paire de clés SSH avait été créée dans une région différente d'`eu-west-3` | Recréée directement avec `aws ec2 create-key-pair --region eu-west-3` |
| `InstanceType not eligible for Free Tier` | `t2.micro` non éligible sur ce compte, contrairement à `t3.micro` | Vérifié avec `aws ec2 describe-instance-types --filters "Name=free-tier-eligible,Values=true"` avant de choisir |
| `apt update` timeout sur Back/DB | Sous-réseau privé sans route vers Internet | Ajout d'une instance NAT (voir section 2) |

### Sécurité SSH : le compromis GitHub Actions

Le Security Group du Front autorise le SSH depuis **2 sources** :
1. `var.admin_ip` (ton IP précise, pour toi)
2. `0.0.0.0/0` (pour que les runners GitHub Actions, dont l'IP change à chaque exécution, puissent se connecter)

**À dire honnêtement à l'oral** : ouvrir SSH à `0.0.0.0/0` est un vrai compromis de sécurité, pas une solution idéale. La solution propre en entreprise serait d'utiliser des runners GitHub self-hosted (dans le même VPC, IP fixe) ou un bastion/VPN — hors scope budgétaire de ce TP.

---

## 4. Ansible : ce qui a vraiment posé problème

### Ansible ne tourne pas nativement sous Windows

Erreur rencontrée : `AttributeError: module 'os' has no attribute 'get_blocking'`. Solution : installer **WSL** (Windows Subsystem for Linux) et faire tourner Ansible depuis un vrai environnement Linux à l'intérieur de Windows.

### ProxyJump simple ne suffit pas — il faut ProxyCommand explicite

`ansible_ssh_common_args='-o ProxyJump=...'` seul ne réutilise pas automatiquement la clé privée pour le saut intermédiaire (le Front). Solution retenue dans `inventory.ini` :

```ini
[back]
back-01 ansible_host=10.0.2.32 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/ma-cle-todo-devops.pem ansible_ssh_common_args='-o ProxyCommand="ssh -i ~/.ssh/ma-cle-todo-devops.pem -W %h:%p -o StrictHostKeyChecking=no ubuntu@<IP_FRONT>"'
```

**Point important** : l'IP publique du Front **change à chaque redémarrage** de l'instance (pas d'Elastic IP réservée). Il faut donc mettre à jour cette IP dans `inventory.ini` (3 occurrences) à chaque fois que les instances sont redémarrées.

### known_hosts séparé entre Windows et WSL

Accepter une empreinte SSH dans Git Bash (Windows) ne la fait pas connaître de WSL (Linux) — ce sont deux fichiers `known_hosts` distincts. Il faut faire une connexion SSH manuelle une fois **depuis WSL** vers chaque machine (front, back, db) avant qu'Ansible puisse s'y connecter sans bloquer.

### Idempotence prouvée concrètement

Deux exécutions consécutives du playbook : la première affiche `changed=X`, la seconde affiche `changed=0` partout — preuve tangible que le playbook ne casse rien en le rejouant. **Bon élément visuel à montrer en direct à l'oral.**

---

## 5. Docker : la leçon la plus importante — `--restart always`

**Bug rencontré** : après un arrêt/redémarrage des instances EC2 (pour économiser le quota gratuit), tous les conteneurs Docker restaient éteints — ils ne redémarrent **pas automatiquement** avec la machine, sauf configuration explicite.

**Solution** : toujours lancer les conteneurs avec l'option `--restart always` :

```bash
docker run --name todo-db -e POSTGRES_USER=todo_user -e POSTGRES_PASSWORD=motdepasse123 -e POSTGRES_DB=todo_db -p 5432:5432 --restart always -d postgres:16-alpine

docker run --name todo-backend -e DB_HOST=<IP_DB> -e DB_USER=todo_user -e DB_PASSWORD=motdepasse123 -e DB_NAME=todo_db -e DB_PORT=5432 -p 3000:3000 --restart always -d fantadev2/todo-backend:latest

docker run --name todo-frontend -p 8080:80 --restart always -d fantadev2/todo-frontend:latest
```

**Question d'oral probable** : *"Que se passe-t-il si l'EC2 redémarre ?"* → Avec `--restart always`, Docker relance automatiquement chaque conteneur au démarrage du service Docker — y compris en retentant plusieurs fois si une dépendance (comme la DB) n'est pas encore prête, ce qu'on a observé concrètement dans les logs du Back.

---

## 6. Nginx : le bug du `proxy_pass` avec slash final

**Bug rencontré** : toutes les requêtes vers `/api/todos` renvoyaient une erreur 404 (page HTML d'Express, pas du JSON), alors que l'API fonctionnait très bien testée directement.

**Cause** : dans la configuration Nginx, `proxy_pass http://IP:3000/;` (avec un `/` final) fait que Nginx **retire** le préfixe `/api/` avant de transmettre la requête au Back — qui reçoit donc `/todos` au lieu de `/api/todos`, une route qui n'existe pas.

**Correction** : retirer le `/` final :
```nginx
location /api/ {
    proxy_pass http://10.0.2.32:3000;   # SANS slash final
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

**Question d'oral probable** : *"Quelle est la différence entre `proxy_pass http://ip:port/` et `proxy_pass http://ip:port` ?"* → Avec le `/` final, Nginx réécrit l'URL en retirant le chemin du `location` ; sans le `/`, il transmet l'URL complète telle quelle. C'est un piège très courant et une excellente question à savoir expliquer.

---

## 7. GitHub Actions : le piège du scope de token

**Erreur rencontrée** : `refusing to allow a Personal Access Token to create or update workflow ... without workflow scope`.

**Cause** : créer ou modifier un fichier dans `.github/workflows/` nécessite un token avec le scope **`workflow`** en plus du scope `repo` classique — une mesure de sécurité de GitHub pour empêcher qu'un token quelconque modifie silencieusement des pipelines d'automatisation.

**Solution** : régénérer un token avec `repo` **et** `workflow` cochés, puis :
```bash
git remote set-url origin https://TON_USER:NOUVEAU_TOKEN@github.com/TON_USER/TON_REPO.git
```

---

## 8. HTTPS gratuit sans nom de domaine : sslip.io

Pas de nom de domaine ? Solution 100% gratuite : **sslip.io**, un service DNS public qui transforme une IP en nom de domaine automatiquement, sans inscription :

```
35-180-2-9.sslip.io  →  pointe automatiquement vers 35.180.2.9
```

Utilisable directement avec Certbot :
```bash
sudo certbot --nginx -d 35-180-2-9.sslip.io
```

**Limite à connaître** : si l'IP publique du Front change (redémarrage sans Elastic IP), ce nom de domaine devient invalide — il faudrait relancer Certbot avec la nouvelle IP. En production, on réserverait une **Elastic IP** (gratuite tant qu'elle est attachée à une instance qui tourne) pour fixer l'IP définitivement.

---

## 9. Checklist de démonstration pour l'oral

Dans l'ordre, testé et validé :

1. `terraform apply` → crée toute l'infra (ou montre l'infra déjà existante avec `terraform output`)
2. `ansible-playbook -i inventory.ini playbook.yml` → relance-le une 2ᵉ fois en direct pour montrer `changed=0` (idempotence)
3. Modifie un petit détail visuel dans `app/frontend/index.html`
4. `git add . && git commit -m "..." && git push`
5. Ouvre l'onglet **Actions** sur GitHub, montre le pipeline se dérouler en direct
6. Rafraîchis `https://<ip-avec-tirets>.sslip.io` → montre le changement déployé automatiquement
7. Montre le CRUD complet fonctionnel (Create/Read/Update/Delete)
8. Explique les Security Groups (moindre privilège, `nc -zv` pour tester TCP vs `ping` qui échoue volontairement en ICMP)

## 10. Questions pièges et réponses courtes

- **"Pourquoi Back/DB ont accès à Internet si vous les isolez ?"** → Sortant uniquement (NAT), jamais entrant.
- **"Pourquoi le ping échoue entre vos machines alors qu'elles communiquent ?"** → ICMP n'est pas autorisé dans les Security Groups, seul TCP sur les ports précis l'est.
- **"Pourquoi 2 zones de disponibilité mais une seule utilisée par les instances ?"** → Réseau prêt pour la HA, instances non dupliquées par contrainte budgétaire (voir section 2).
- **"Que se passe-t-il si le conteneur backend plante ?"** → `--restart always` le relance automatiquement, avec retry si une dépendance n'est pas encore prête.
- **"Différence entre ProxyJump et ProxyCommand ?"** → ProxyJump est un raccourci pratique mais qui ne propage pas toujours explicitement la clé pour le saut intermédiaire ; ProxyCommand permet un contrôle complet et explicite de chaque étape de la connexion.
- **"Pourquoi avoir ouvert SSH à 0.0.0.0/0 ?"** → Compromis assumé pour permettre à GitHub Actions (IP variable) de déployer ; en entreprise on utiliserait un runner self-hosted ou un bastion.

---

Voilà, tu as un guide qui reflète exactement ton vrai parcours — avec les vraies embûches et les vraies solutions. Relis-le une fois avant l'oral, et surtout, entraîne-toi à raconter ces histoires de debug avec tes mots : c'est ce qui montre le mieux que tu as vraiment compris, pas juste suivi des instructions.