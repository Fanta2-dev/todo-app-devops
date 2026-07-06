# Guide pédagogique — TP DevOps : Todo App sur AWS

> Lis ce document dans l'ordre. Chaque partie répond à une question que ton prof (ou le jury) pourrait te poser : "pourquoi ce choix ?", "comment ça marche ?", "que se passe-t-il si..."

---

## 0. Vue d'ensemble : les 3 piliers, en une phrase chacun

- **Terraform (Infrastructure as Code)** = au lieu de cliquer dans la console AWS pour créer le VPC, les sous-réseaux, les EC2..., on **décrit** cette infrastructure dans des fichiers `.tf`, et Terraform la crée pour nous. Avantage : reproductible, versionné, on peut tout détruire et recréer à l'identique.
- **Ansible (Configuration Management)** = une fois les machines créées, il faut les **configurer** (installer Docker, Nginx...). Ansible se connecte en SSH à chaque machine et exécute des instructions décrites dans un "playbook" YAML. Avantage : pas besoin de se connecter à la main sur chaque serveur.
- **GitHub Actions (CI/CD)** = à chaque fois qu'on pousse du code sur `main`, un robot (le "workflow") construit automatiquement l'image Docker, la publie, et va la déployer sur le bon serveur. Avantage : plus jamais de "ça marche chez moi mais pas en prod".

Retiens cette phrase pour ta soutenance : **"Terraform crée les machines, Ansible les configure, GitHub Actions déploie le code dessus."**

---

## 1. Le choix des langages / technologies (et pourquoi)

C'est une question presque garantie à l'oral : "pourquoi avoir choisi ça ?"

| Composant | Choix fait dans ce projet | Pourquoi ce choix pour un·e débutant·e |
|---|---|---|
| **Backend** | Node.js + Express (JavaScript) | Un seul langage (JS) pour front et back, énormément de documentation, très peu de code pour faire une API REST, démarre en une commande (`node server.js`). |
| **Frontend** | HTML + CSS + JavaScript "vanilla" (pas de framework) | Pas de build (Webpack/Vite) à gérer dans Docker, pas de complexité React à expliquer en plus du DevOps. Le TP évalue le pipeline DevOps, pas la sophistication du front. C'est un choix assumé et défendable à l'oral : "j'ai volontairement simplifié le front pour me concentrer sur l'infra et le CI/CD". |
| **Base de données** | PostgreSQL (image Docker officielle) | Relationnel, très répandu, image officielle bien maintenue, simple à lancer avec des variables d'environnement (`POSTGRES_PASSWORD`, etc.). |
| **Reverse proxy** | Nginx (installé nativement sur l'hôte Front, pas en conteneur) | Le sujet demande "Nginx sur l'instance Front" comme point d'entrée fixe, avant même que les conteneurs démarrent — plus simple à administrer avec Certbot pour le HTTPS. |

> Tu peux tout à fait remplacer Node.js par Python/Flask ou React par un framework si tu es plus à l'aise — la logique DevOps (Docker, Terraform, Ansible, CI/CD) reste identique. L'important est de savoir **justifier** ton choix, pas de suivre celui-ci à la lettre.

---

## 2. Comprendre l'architecture réseau AWS (avant de toucher à Terraform)

Imagine le VPC comme un **quartier fermé** que tu construis dans AWS :

- **VPC** = le quartier lui-même (un espace d'adresses IP privé, ex: `10.0.0.0/16`).
- **Sous-réseau public** = la rue qui donne sur l'extérieur (Internet). La maison "Front" y habite : elle a une IP publique.
- **Sous-réseau privé** = les rues intérieures, sans accès direct depuis l'extérieur. Les maisons "Back" et "DB" y habitent.
- **Internet Gateway (IGW)** = la porte du quartier vers Internet. Seul le sous-réseau public y est raccordé (via une route dans sa table de routage).
- **Security Group (SG)** = un vigile **par maison** qui vérifie qui a le droit d'entrer (et parfois de sortir). Chaque couche (Front/Back/DB) a son propre vigile avec ses propres règles.

### Les règles de sécurité demandées, traduites en "qui peut parler à qui" :

```
Internet ──(HTTP 80, HTTPS 443)──▶ Front
Toi (admin) ──(SSH 22, depuis TON ip uniquement)──▶ Front
Front ──(port de l'API, ex: 3000)──▶ Back
Back ──(port Postgres, 5432)──▶ DB
```

Et strictement rien d'autre. En particulier :
- Le SG de **Back** n'autorise QUE le trafic venant du SG **Front** (pas d'Internet, pas de "0.0.0.0/0").
- Le SG de **DB** n'autorise QUE le trafic venant du SG **Back**.

C'est ce qu'on appelle le **principe du moindre privilège** : chaque couche n'ouvre que le strict nécessaire. C'est LA question de sécurité qu'on te posera à l'oral — sache l'expliquer avec ce schéma "qui parle à qui".

---

## 3. Terraform, fichier par fichier

Regarde le dossier `terraform/`. Voici ce que fait chaque fichier (tu dois pouvoir dérouler cette explication à l'oral) :

- **`variables.tf`** : déclare toutes les valeurs qui peuvent changer (région AWS, CIDR du VPC, type d'instance, ton IP pour le SSH...). **Rien n'est écrit en dur** dans le code — c'est une exigence explicite du sujet ("variables externalisées").
- **`terraform.tfvars`** (à créer toi-même, à partir de `terraform.tfvars.example`) : contient TES valeurs personnelles (ta clé SSH, ton IP...). Ce fichier ne doit **jamais** être poussé sur Git (il est dans `.gitignore`).
- **`vpc.tf`** : crée le VPC, les 2 sous-réseaux (public/privé), l'Internet Gateway, la table de routage publique et son association.
- **`security_groups.tf`** : crée les 3 Security Groups (front/back/db) avec les règles décrites plus haut — remarque que le SG "back" référence le SG "front" comme source autorisée (pas une IP en dur), c'est la bonne pratique.
- **`ec2.tf`** : crée les 3 instances EC2 (Front en sous-réseau public avec IP publique, Back et DB en sous-réseau privé), en leur attachant le bon Security Group.
- **`outputs.tf`** : affiche à la fin (`terraform output`) l'IP publique du Front, l'IP privée du Back, l'IP privée de la DB — comme demandé dans le sujet. Ansible ira lire ces sorties pour générer son inventaire.

### Comment on l'utilise (à connaître par cœur pour la démo) :

```bash
cd terraform
terraform init      # télécharge le "provider" AWS
terraform plan       # montre ce qui VA être créé, sans rien créer encore
terraform apply       # crée réellement l'infrastructure (demande confirmation "yes")
terraform output      # affiche les IPs à la fin
terraform destroy     # ⚠️ détruit tout (à faire en fin de TP pour ne pas payer/consommer le quota gratuit)
```

> **Piège classique à l'oral** : on te demandera "que se passe-t-il si tu relances `terraform apply` deux fois ?" Réponds : Terraform compare l'état désiré (le code) à l'état réel (stocké dans `terraform.tfstate`) et ne recrée QUE ce qui a changé. C'est ce qu'on appelle l'**idempotence** de Terraform.

---

## 4. Ansible, fichier par fichier

Regarde le dossier `ansible/`.

- **`inventory.ini`** : la liste des machines à configurer, groupées par rôle (`[front]`, `[back]`, `[db]`), avec leur IP (récupérée depuis `terraform output`) et l'utilisateur SSH (`ubuntu` en général sur AWS).
- **`playbook.yml`** : le fichier principal. Il dit "sur le groupe front, applique le rôle docker ET le rôle nginx ; sur back et db, applique juste le rôle docker".
- **`roles/docker/tasks/main.yml`** : installe Docker et Docker Compose sur la machine, quel que soit son rôle.
- **`roles/nginx/tasks/main.yml`** : installe Nginx, copie le fichier de configuration (le "fichier de config du domaine" demandé dans le sujet) depuis `roles/nginx/templates/`, redémarre Nginx.
- **`roles/nginx/templates/nginx.conf.j2`** : le fichier de configuration Nginx, en template Jinja2 (Ansible peut y injecter des variables, comme l'IP du Back).

### Pourquoi c'est "idempotent" (exigence du sujet) ?

Ansible ne réinstalle pas Docker s'il est déjà installé — chaque module Ansible (`apt`, `service`, `copy`...) vérifie l'état actuel avant d'agir. Relancer le playbook 10 fois de suite ne casse rien : c'est la différence fondamentale avec un simple script bash.

### Comment on l'utilise :

```bash
cd ansible
ansible-playbook -i inventory.ini playbook.yml
```

---

## 5. L'application (Docker), fichier par fichier

Regarde `app/backend/` et `app/frontend/`.

- **`app/backend/server.js`** : une petite API Express avec des routes `GET /api/todos`, `POST /api/todos`, `DELETE /api/todos/:id`, connectée à PostgreSQL via les variables d'environnement (`DB_HOST`, `DB_USER`, `DB_PASSWORD`...). **Aucun mot de passe n'est écrit dans le code** — exigence du sujet.
- **`app/backend/Dockerfile`** : construit une image légère (`node:alpine`) contenant l'API.
- **`app/frontend/index.html` / `app.js` / `style.css`** : une page simple qui appelle l'API (`fetch('/api/todos')`) pour afficher/ajouter/supprimer des tâches.
- **`app/frontend/Dockerfile`** : sert les fichiers statiques via une image `nginx:alpine` (un mini serveur web dans le conteneur, à ne pas confondre avec le Nginx installé par Ansible sur l'hôte — celui-là fait le reverse proxy **devant** ce conteneur).
- **DB** : pas de Dockerfile custom, on utilise directement l'image officielle `postgres:16-alpine` avec des variables d'environnement.

### Pourquoi 2 "Nginx" différents ? (question piège fréquente)

1. **Nginx "hôte"** (installé par Ansible sur la VM Front) = le reverse proxy public, avec Certbot pour le HTTPS. C'est LUI que voit Internet.
2. **Nginx "conteneur"** (dans l'image frontend) = sert juste les fichiers HTML/CSS/JS statiques.

Le Nginx hôte redirige `/` vers le conteneur frontend (port interne, ex: 8080) et `/api` vers le Back (IP privée : port 3000).

---

## 6. Docker : builder, tagger, pousser

```bash
docker build -t tonpseudo/todo-backend:latest ./app/backend
docker push tonpseudo/todo-backend:latest

docker build -t tonpseudo/todo-frontend:latest ./app/frontend
docker push tonpseudo/todo-frontend:latest
```

Crée un compte gratuit sur [Docker Hub](https://hub.docker.com) si tu n'en as pas. C'est ce registre que GitHub Actions utilisera automatiquement à chaque push.

---

## 7. GitHub Actions, expliqué ligne par ligne

Regarde `.github/workflows/deploy.yml`. Le pipeline fait, dans l'ordre :

1. **`checkout`** : récupère le code du dépôt.
2. **`docker/login-action`** : se connecte à Docker Hub avec des identifiants stockés dans **GitHub Secrets** (jamais en clair dans le fichier YAML — exigence du sujet).
3. **`docker build` + `docker push`** : construit l'image Back (et/ou Front) et la publie.
4. **`appleboy/ssh-action`** : se connecte en SSH à l'instance concernée (IP et clé privée stockées dans les Secrets) et exécute un script de déploiement.
5. **Script de déploiement** : fait un `docker pull` de la nouvelle image, **arrête et supprime l'ancien conteneur s'il existe** (`docker stop ... || true` / `docker rm ... || true` — le `|| true` évite que le script échoue si le conteneur n'existait pas encore, exigence explicite du sujet pour le "premier déploiement"), puis relance un nouveau conteneur avec `docker run`.

### Les secrets à créer dans GitHub (Settings → Secrets and variables → Actions) :

| Nom du secret | Contenu |
|---|---|
| `DOCKERHUB_USERNAME` | ton pseudo Docker Hub |
| `DOCKERHUB_TOKEN` | un token d'accès Docker Hub (pas ton mot de passe) |
| `BACK_HOST` | IP privée du Back (accessible car le runner GitHub passe par... voir note ci-dessous) |
| `FRONT_HOST` | IP publique du Front |
| `SSH_PRIVATE_KEY` | la clé privée qui correspond à la clé publique injectée dans les EC2 par Terraform |

> **Note importante** : GitHub Actions tourne sur Internet, il ne peut pas atteindre directement une IP **privée** (Back/DB). La pratique la plus simple pour ce TP : le pipeline se connecte en SSH au **Front** (IP publique), puis, depuis le Front, rebondit en SSH vers le Back (`ssh -J` ou un double saut) pour le déployer — ou plus simple pour débuter : le pipeline copie le `docker-compose` du Back sur le Front, qui le relaie. Le plus simple et le plus souvent accepté en TP : configure un **saut SSH (ProxyJump)** via le Front. C'est un excellent point à mentionner à l'oral car ça montre que tu as compris la contrainte réseau (Back en sous-réseau privé = pas d'accès direct depuis Internet).

---

## 8. Nginx + HTTPS (Let's Encrypt / Certbot)

Une fois ton nom de domaine acheté (ou sous-domaine offert par un fournisseur) et pointé (enregistrement DNS de type **A**) vers l'IP publique du Front :

```bash
sudo apt update && sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d ton-domaine.com
```

Certbot modifie automatiquement la configuration Nginx pour ajouter le certificat et rediriger le HTTP vers le HTTPS. Ansible peut aussi automatiser cette étape avec le module `command` (à condition que le DNS pointe déjà vers l'IP, sinon la validation Let's Encrypt échoue).

---

## 9. Tester le déploiement de bout en bout (check-list avant la démo)

1. `terraform apply` → note les IPs.
2. Génère l'inventaire Ansible avec ces IPs (`ansible/inventory.ini`).
3. `ansible-playbook -i ansible/inventory.ini ansible/playbook.yml` → Docker + Nginx installés partout.
4. Lance manuellement les conteneurs une première fois (DB, puis Back, puis Front) pour vérifier que tout communique.
5. Vérifie `curl http://IP_PUBLIQUE_FRONT` → doit renvoyer la page HTML.
6. Vérifie `curl http://IP_PUBLIQUE_FRONT/api/todos` → doit renvoyer du JSON (via le reverse proxy vers le Back).
7. Fais un petit changement de code, `git push` sur `main` → observe le workflow GitHub Actions se déclencher dans l'onglet "Actions" du dépôt → vérifie que le changement est visible sur le site.

C'est exactement l'enchaînement qu'on te demandera de démontrer en live (point 5 des livrables).

---

## 10. Préparer la soutenance orale (15 min)

Structure suggérée :

1. **Contexte & architecture** (2 min) : montre le schéma, explique le "qui parle à qui".
2. **Terraform en live** (3 min) : montre `terraform plan`/`apply`, explique un extrait de `security_groups.tf`.
3. **Ansible en live** (2 min) : lance le playbook, montre qu'il est idempotent (relance-le une 2e fois, montre que rien ne "change" — ligne verte "ok" au lieu de "changed").
4. **CI/CD en live — LE moment fort** (5 min) : fais un petit changement visuel dans le frontend, `git push`, montre le workflow tourner dans GitHub Actions, puis rafraîchis le site pour montrer le changement déployé automatiquement.
5. **Sécurité** (2 min) : explique les Security Groups et pourquoi Back/DB ne sont jamais exposés à Internet.
6. **Questions** (1 min de marge).

### Questions probables et réponses courtes à avoir en tête :

- *"Pourquoi Terraform et pas la console AWS ?"* → reproductibilité, versionning, travail en équipe, rollback possible.
- *"Pourquoi séparer Ansible de Terraform ?"* → Terraform gère l'infrastructure (le "quoi"), Ansible gère la configuration logicielle (le "comment"). Séparer les responsabilités = principe de base du DevOps.
- *"Que se passe-t-il si le conteneur back plante ?"* → mentionne `restart: always` dans le `docker run`/compose, et le rollback prévu dans le pipeline.
- *"Pourquoi la DB est en sous-réseau privé ?"* → surface d'attaque minimale, principe du moindre privilège.
- *"Comment gères-tu les secrets ?"* → GitHub Secrets pour le CI/CD, variables d'environnement (jamais en dur) pour les conteneurs, `terraform.tfvars` jamais commité.

---

## 11. Checklist finale des livrables

- [ ] Code Terraform versionné sur Git (avec `.gitignore` pour `terraform.tfvars` et `*.tfstate`)
- [ ] Playbooks Ansible fonctionnels et idempotents
- [ ] Dockerfiles (Front, Back) + image DB officielle documentée
- [ ] Workflow GitHub Actions qui build, push, et déploie automatiquement
- [ ] Site accessible en HTTPS via un nom de domaine
- [ ] Démo live prête (changement de code → push → mise à jour visible)

Bon courage — tu as toutes les pièces du puzzle dans ce dossier, prends le temps de relire chaque fichier en te demandant "est-ce que je saurais l'expliquer avec mes mots ?" avant l'oral.
