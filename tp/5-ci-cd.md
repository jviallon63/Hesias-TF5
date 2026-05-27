---
layout: tp
title: "TP 5 - CI/CD Terraform avec GitHub Actions"
---

# 📦 Contexte

Jusqu'ici vous exécutez Terraform depuis votre machine. Dans une vraie équipe, personne ne devrait appliquer de l'infrastructure depuis son laptop : les credentials diffèrent, l'historique est perdu et deux personnes peuvent appliquer en même temps. La solution : **automatiser le workflow Terraform dans une CI/CD**.

Dans ce TP vous allez brancher le projet `tp4-nsg/shared` sur GitHub Actions.

---

## 🎯 Objectifs

<div class="section objective">

1. Créer un Service Principal Azure et configurer les secrets GitHub
2. Écrire un workflow qui s'exécute sur chaque PR.
3. Le plan est remonté en commentaire pour la revue.
4. Vous ajouter les outils pour valider la PR (linters, validate, security).

</div>

---

## 🗂️ Partie 5.1 - Pré requis, initialisation de l'environnement

GitHub Actions doit pouvoir s'authentifier sur Azure pour exécuter Terraform. La méthode la plus simple est un **Service Principal** dont les credentials sont stockés comme **secrets GitHub**. Dans ce TP nous n'allons pas allez jusqu'à l'authentification OIDC, mais dans un contexte d'entreprise c'est une solution à privilégier.

---

### 📝 Étape 5.1.1 - Authentification Azure depuis GitHub Actions

Un Service Principal est une identité applicative Azure (équivalent d'un compte de service). Il sera limité au périmètre dont GitHub Actions a besoin.

**Ce que vous devez faire :**

1. Créez un Service Principal avec le rôle `Contributor` sur votre abonnement via Azure CLI :

```bash
az ad sp create-for-rbac --name "sp-tp-terraform-<PRENOM>" --role Contributor --scopes /subscriptions/<SUBSCRIPTION_ID> --sdk-auth
```

2. Copiez les informations du JSON retourné — il contient les quatres valeurs dont Terraform a besoin : `clientId`, `clientSecret`, `subscriptionId` et `tenantId`
3. Gardez précieusement la valeur `clientSecret` : vous l'utiliserez à l'étape suivante pour créer le secret GitHub `ARM_CLIENT_SECRET`.

---

### 📝 Étape 5.1.2 - Initialiser le dépôt GitHub

Téléchargez le code [ici](tp5-init.zip) et décompressez le dans un dossier local de travail, puis initialisez le dépôt Git en suivant les étapes ci-dessous.

**Ce que vous devez faire :**

1. Créez un dépôt vide sur GitHub.
2. Dans votre terminal, positionnez-vous dans le dossier du projet extrait du zip, puis initialisez Git et préparez le premier commit :

```bash
git init
git branch -M main
git add .
git commit -m "Initial commit"
```

3. Ajoutez le dépôt GitHub comme remote et poussez le code sur `main` :

```bash
git remote add origin https://github.com/<VOTRE_COMPTE>/<VOTRE_DEPOT>.git
git push -u origin main
```

4. Une fois le dépôt créé, allez dans **Settings → Secrets and variables → Actions** et ajoutez le secret dans **New repository secret** : `ARM_CLIENT_SECRET` avec la valeur `clientSecret` récupéré précédement.

> 💡 Le provider `azurerm` lit automatiquement cette variable d'environnement pour s'authentifier. Aucune credential ne doit apparaître dans vos fichiers `.tf`.

---

### 📝 Étape 5.1.3 - Initialiser le state remote

Le projet fourni pour ce TP contient un répertoire `state` dans le zip. Ce répertoire permet de créer le Storage Account qui servira de backend distant Terraform.

**Ce que vous devez faire :**

1. Depuis votre terminal, placez-vous dans le répertoire `state`.
2. Exécutez les commandes Terraform pour créer l'infrastructure.
3. Notez le nom du Storage Account généré : vous en aurez besoin pour configurer le backend distant.

> 💡 **À noter :**
> Le nom du Storage Account est généré aléatoirement grâce au provider `random`.
> Le projet `state` utilise un state local, mais ce state n'est pas versionné dans Git (vérifiez le `.gitignore`).

---

### 📝 Étape 5.1.4 - Adapter le projet pour la CI

Placez-vous dans le projet `terraform` : vous allez configurer le backend distant et le provider Azure.

**Ce que vous devez faire :**

1. Configurez le backend remote avec le nom du Storage Account créé précédemment.
2. Ajoutez les variables nécessaires à la connexion Azure dans le provider `azurerm`, avec les informations récupérées lors de la création du Service Principal (`clientId`, `subscriptionId`, `tenantId`)
3. Générez un plan Terraform pour valider le bon fonctionnement du projet.

> 💡 Si le plan est un succès, n'oubliez pas de commiter puis de pousser votre code sur votre dépôt GitHub :
>
> ```bash
> git add .
> git commit -m "Configure backend and Azure provider"
> git push origin main
> ```

---

## 🗂️ Partie 5.2 - Créer le workflow

1. Créez la structure suivante dans votre dépôt :

```
.github/
  workflows/
    terraform.yml
```

2. Appliquer le template suivant. Le workflow s'execute à chaque PR sur mai, le `CLIENT_SECRET` est exporté depuis les secrets github, 4 steps existe : init, plan, apply destroy.

### 5.1.4 - Créer le workflow

**Ce que vous devez faire :**

1. Adapter chaque step pour excuter les commandes terraform adéquates.
2. Le plan doit utiliser -out et capturer la sortie.
5. Convertir le plan binaire en texte lisible avec `terraform show -no-color tfplan`.
6. Poster ce texte en commentaire de la PR (mettre à jour le commentaire si il existe déjà).
7. Échouer le workflow si le plan a retourné une erreur.

> 💡 **Pourquoi `-out=tfplan` ?**
> Sans ce flag, `plan` et `apply` font chacun leur propre calcul. Entre les deux, une autre personne peut avoir modifié l'infrastructure ou poussé un nouveau commit. Avec `-out`, l'`apply` exécute **exactement** ce qui a été planifié et affiché dans la PR — rien de plus, rien de moins.

{::nomarkdown}
<details><summary>Solution - terraform-plan.yml</summary>
{:/nomarkdown}

```yaml
name: Terraform Plan

on:
  pull_request:
    branches: [main]
    paths:
      - 'tp4-nsg/**'
      - '.github/workflows/terraform-plan.yml'

env:
  TF_WORKING_DIR: tp4-nsg
  ARM_CLIENT_ID:       ${{ secrets.ARM_CLIENT_ID }}
  ARM_CLIENT_SECRET:   ${{ secrets.ARM_CLIENT_SECRET }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
  ARM_TENANT_ID:       ${{ secrets.ARM_TENANT_ID }}

jobs:
  plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write   # nécessaire pour poster un commentaire

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.9"

      - name: Terraform Init
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: terraform init -input=false

      - name: Terraform Plan
        id: plan
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: terraform plan -no-color -input=false -out=tfplan
        continue-on-error: true   # on veut poster le résultat même en cas d'erreur

      - name: Afficher le plan en texte lisible
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: terraform show -no-color tfplan > plan.txt

      - name: Poster le plan en commentaire de PR
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const fs = require('fs');
            const raw = fs.readFileSync('${{ env.TF_WORKING_DIR }}/plan.txt', 'utf8');

            // GitHub limite les commentaires à ~65 536 caractères
            const plan = raw.length > 60000
              ? raw.substring(0, 60000) + '\n\n> ⚠️ Plan tronqué — voir les logs du workflow pour la version complète.'
              : raw;

            const status = '${{ steps.plan.outcome }}' === 'success' ? '✅' : '❌';
            const body = `## ${status} Terraform Plan — \`${{ github.head_ref }}\`

            <details>
            <summary>Afficher le plan complet</summary>

            \`\`\`hcl
            ${plan}
            \`\`\`
            </details>

            *Déclenché par @${{ github.actor }} · commit \`${{ github.sha.substring(0,7) }}\`*`;

            // Recherche un commentaire existant pour l'écraser plutôt d'en créer un nouveau à chaque push
            const { data: comments } = await github.rest.issues.listComments({
              owner: context.repo.owner,
              repo:  context.repo.repo,
              issue_number: context.issue.number,
            });
            const existing = comments.find(c =>
              c.user.type === 'Bot' && c.body.includes('Terraform Plan')
            );

            if (existing) {
              await github.rest.issues.updateComment({
                owner:      context.repo.owner,
                repo:       context.repo.repo,
                comment_id: existing.id,
                body,
              });
            } else {
              await github.rest.issues.createComment({
                owner:        context.repo.owner,
                repo:         context.repo.repo,
                issue_number: context.issue.number,
                body,
              });
            }

      - name: Échouer si le plan a retourné une erreur
        if: steps.plan.outcome == 'failure'
        run: exit 1
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🗂️ Partie 5.3 - Workflow Apply manuel

Le workflow Apply doit être **explicitement déclenché par un humain**, après revue du plan. On utilise `workflow_dispatch` pour cela.

---

### 📝 Étape 5.3.1 - Écrire le workflow Apply

Créez `.github/workflows/terraform-apply.yml`.

**Ce que le workflow doit faire :**

1. Se déclencher uniquement via `workflow_dispatch` (bouton manuel dans GitHub Actions).
2. Exporter les credentials Azure.
3. Exécuter `terraform init`.
4. Exécuter `terraform plan -out=tfplan` — **dans le même job** que l'apply.
5. Exécuter `terraform apply tfplan` — le plan sauvegardé garantit que l'apply est **identique au plan**.

> 💡 **Plan et apply dans le même job** : c'est intentionnel. Si on séparait en deux jobs distincts, l'état d'Azure pourrait changer entre les deux. En exécutant les deux étapes dans le même job, la fenêtre de temps est de quelques secondes — et surtout, l'`apply` utilise le fichier binaire `tfplan` généré juste avant, pas un nouveau calcul.

{::nomarkdown}
<details><summary>Solution - terraform-apply.yml</summary>
{:/nomarkdown}

```yaml
name: Terraform Apply

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environnement cible'
        required: true
        default: 'staging'
        type: choice
        options: [staging, prod]
      confirm:
        description: 'Tapez "apply" pour confirmer'
        required: true
        type: string

env:
  TF_WORKING_DIR: tp4-nsg
  ARM_CLIENT_ID:       ${{ secrets.ARM_CLIENT_ID }}
  ARM_CLIENT_SECRET:   ${{ secrets.ARM_CLIENT_SECRET }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
  ARM_TENANT_ID:       ${{ secrets.ARM_TENANT_ID }}

jobs:
  apply:
    name: Terraform Apply — ${{ github.event.inputs.environment }}
    runs-on: ubuntu-latest
    # Bloque si la confirmation est incorrecte
    if: github.event.inputs.confirm == 'apply'

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.9"

      - name: Terraform Init
        working-directory: ${{ env.TF_WORKING_DIR }}/${{ github.event.inputs.environment }}
        run: terraform init -input=false

      - name: Terraform Plan
        working-directory: ${{ env.TF_WORKING_DIR }}/${{ github.event.inputs.environment }}
        run: terraform plan -no-color -input=false -out=tfplan

      - name: Terraform Apply
        working-directory: ${{ env.TF_WORKING_DIR }}/${{ github.event.inputs.environment }}
        # -auto-approve est sûr ici car on applique le fichier tfplan,
        # pas un nouveau plan calculé au moment de l'apply
        run: terraform apply -auto-approve tfplan
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🗂️ Partie 5.4 - Workflow Destroy manuel

Le Destroy est l'opération la plus dangereuse — il supprime de l'infrastructure réelle. Il doit être **difficile à déclencher accidentellement**.

---

### 📝 Étape 5.4.1 - Écrire le workflow Destroy

Créez `.github/workflows/terraform-destroy.yml`.

Le workflow reprend le même principe de confirmation que l'Apply, avec une étape supplémentaire : afficher le plan de destruction avant d'exécuter quoi que ce soit.

{::nomarkdown}
<details><summary>Solution - terraform-destroy.yml</summary>
{:/nomarkdown}

```yaml
name: Terraform Destroy

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environnement à détruire'
        required: true
        type: choice
        options: [staging, prod]
      confirm:
        description: 'Tapez "destroy" pour confirmer (irréversible)'
        required: true
        type: string

env:
  TF_WORKING_DIR: tp4-nsg
  ARM_CLIENT_ID:       ${{ secrets.ARM_CLIENT_ID }}
  ARM_CLIENT_SECRET:   ${{ secrets.ARM_CLIENT_SECRET }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
  ARM_TENANT_ID:       ${{ secrets.ARM_TENANT_ID }}

jobs:
  destroy:
    name: "⚠️ Terraform Destroy — ${{ github.event.inputs.environment }}"
    runs-on: ubuntu-latest
    if: github.event.inputs.confirm == 'destroy'
    environment: production

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.9"

      - name: Terraform Init
        working-directory: ${{ env.TF_WORKING_DIR }}/${{ github.event.inputs.environment }}
        run: terraform init -input=false

      - name: Terraform Plan Destroy (aperçu)
        working-directory: ${{ env.TF_WORKING_DIR }}/${{ github.event.inputs.environment }}
        run: terraform plan -destroy -no-color -input=false

      - name: Terraform Destroy
        working-directory: ${{ env.TF_WORKING_DIR }}/${{ github.event.inputs.environment }}
        run: terraform destroy -auto-approve -input=false
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 5.4.2 - Tester le workflow complet

**Ce que vous devez faire :**

Reproduisez le workflow complet de bout en bout :

1. **Plan** : ouvrez une PR qui modifie une règle NSG → vérifiez le commentaire dans la PR.
2. **Apply** : mergez la PR puis déclenchez le workflow Apply manuellement depuis l'onglet Actions.
3. **Vérification** : contrôlez dans le portail Azure que la règle NSG est bien mise à jour.
4. **Destroy** : déclenchez le workflow Destroy sur l'environnement `staging` pour nettoyer.

---

## 🗂️ Partie 5.5 - Bonnes pratiques et aller plus loin

### Récapitulatif des bonnes pratiques appliquées

| Pratique | Pourquoi |
|---|---|
| `-out=tfplan` sur le plan | Garantit que l'apply exécute exactement ce qui a été planifié |
| `continue-on-error` + échec explicite | Permet de toujours poster le résultat du plan, même en cas d'erreur |
| Confirmation textuelle (`destroy`) | Prévient les destructions accidentelles |
| Environnement GitHub avec approbation | Second niveau de protection humaine avant apply/destroy |
| `paths:` sur le déclencheur PR | Évite de re-planifier pour des changements de documentation |
| Secrets GitHub, jamais dans le code | Les credentials ne doivent jamais apparaître dans l'historique git |

---


## 🧹 Nettoyage

Détruisez toutes les ressources.
