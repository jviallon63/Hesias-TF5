---
layout: tp
title: "TP 5 - CI/CD Terraform avec GitHub Actions"
---

# 📦 Contexte

Jusqu'ici vous exécutez Terraform depuis votre machine. Dans une vraie équipe, personne ne devrait appliquer de l'infrastructure depuis son laptop : les credentials diffèrent, l'historique est perdu et deux personnes peuvent appliquer en même temps. La solution : **automatiser le workflow Terraform dans une CI/CD**.

Dans ce TP vous allez brancher le projet `tp4-nsg/` sur GitHub Actions avec trois workflows :

```
┌─────────────────────────────────────────────────────────────┐
│  Pull Request ouverte                                       │
│  └─► terraform init + plan -out=tfplan                      │
│       └─► résultat posté en commentaire de PR               │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│  Apply  (déclenchement manuel)                              │
│  └─► terraform init + plan -out=tfplan + apply tfplan       │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│  Destroy  (déclenchement manuel)                            │
│  └─► terraform init + destroy                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Objectifs

<div class="section objective">

1. Créer un Service Principal Azure et configurer les secrets GitHub
2. Écrire un workflow Plan qui s'exécute sur chaque PR et poste le résultat en commentaire
3. Comprendre l'intérêt du flag `-out` et la séparation plan / apply
4. Écrire un workflow Apply déclenché manuellement
5. Écrire un workflow Destroy déclenché manuellement avec confirmation

</div>

---

## 🗂️ Partie 5.1 - Authentification Azure depuis GitHub Actions

GitHub Actions doit pouvoir s'authentifier sur Azure pour exécuter Terraform. La méthode la plus simple est un **Service Principal** dont les credentials sont stockés comme **secrets GitHub**.

---

### 📝 Étape 5.1.1 - Créer le Service Principal

Un Service Principal est une identité applicative Azure (équivalent d'un compte de service). Il sera limité au périmètre dont GitHub Actions a besoin.

**Ce que vous devez faire :**

1. Créez un Service Principal avec le rôle `Contributor` sur votre abonnement via Azure CLI :

```bash
az ad sp create-for-rbac \
  --name "sp-github-terraform" \
  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID> \
  --sdk-auth
```

2. Copiez le JSON retourné — il contient les quatre valeurs dont Terraform a besoin.

> ⚠️ Ce JSON contient des credentials sensibles. **Ne le committez jamais** dans votre dépôt. Il disparaît dès que vous fermez le terminal si vous ne le sauvegardez pas ailleurs.

{::nomarkdown}
<details><summary>Exemple de sortie de la commande</summary>
{:/nomarkdown}

```json
{
  "clientId":       "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret":   "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId":       "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 5.1.2 - Ajouter les secrets dans GitHub

Dans votre dépôt GitHub, allez dans **Settings → Secrets and variables → Actions** et créez les quatre secrets suivants :

| Secret GitHub | Valeur |
|---|---|
| `ARM_CLIENT_ID` | `clientId` |
| `ARM_CLIENT_SECRET` | `clientSecret` |
| `ARM_SUBSCRIPTION_ID` | `subscriptionId` |
| `ARM_TENANT_ID` | `tenantId` |

> 💡 Le provider `azurerm` lit automatiquement ces quatre variables d'environnement pour s'authentifier. Aucune credential ne doit apparaître dans vos fichiers `.tf`.

---

### 📝 Étape 5.1.3 - Adapter le projet pour la CI

Le projet `tp4-nsg/` utilise un backend distant — c'est déjà une bonne base. Vérifiez que :

1. Le `backend "azurerm"` dans `providers.tf` ne contient **aucune valeur en dur** qui nécessiterait d'être différente en CI (le Service Principal a accès au Storage Account du TP3).
2. Le `provider "azurerm"` **ne contient pas** de `subscription_id` hardcodé — il sera fourni via la variable d'environnement `ARM_SUBSCRIPTION_ID`.
3. Aucun `.terraform.lock.hcl` ou `*.tfstate` local n'est committé (vérifiez votre `.gitignore`).

**Ce que vous devez faire :**

Ajoutez (ou vérifiez) un `.gitignore` à la racine du projet :

```gitignore
# Terraform
.terraform/
*.tfstate
*.tfstate.backup
*.tfplan
.terraform.lock.hcl
crash.log
override.tf
override.tf.json
```

---

## 🗂️ Partie 5.2 - Workflow Plan sur Pull Request

Le workflow Plan s'exécute automatiquement dès qu'une PR est ouverte ou mise à jour. Son but : **afficher ce que Terraform ferait** sans rien appliquer, directement dans la PR pour faciliter la revue.

---

### 📝 Étape 5.2.1 - Structure des workflows

Créez la structure suivante dans votre dépôt :

```
.github/
  workflows/
    terraform-plan.yml
    terraform-apply.yml
    terraform-destroy.yml
```

---

### 📝 Étape 5.2.2 - Écrire le workflow Plan

Créez `.github/workflows/terraform-plan.yml`.

**Ce que le workflow doit faire :**

1. Se déclencher sur `pull_request` vers `main`.
2. Exporter les credentials Azure comme variables d'environnement.
3. Exécuter `terraform init`.
4. Exécuter `terraform plan -no-color -out=tfplan` et capturer la sortie.
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

### 📝 Étape 5.2.3 - Tester le workflow Plan

**Ce que vous devez faire :**

1. Créez une branche `feature/tp5-test` à partir de votre code `tp4-nsg/`.
2. Faites un changement mineur (ajoutez un tag, changez une description de variable).
3. Ouvrez une PR vers `main`.
4. Vérifiez dans l'onglet **Actions** que le workflow se déclenche.
5. Vérifiez que le plan apparaît en commentaire de la PR.

**Questions de réflexion :**
- Pourquoi utilise-t-on `continue-on-error: true` sur l'étape Plan mais qu'on échoue quand même à la fin ?
- Que se passe-t-il si deux développeurs ouvrent une PR en même temps qui modifient les mêmes ressources ?

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

### 📝 Étape 5.3.2 - Ajouter une protection d'environnement (bonus)

GitHub permet de définir des **environnements** avec des règles de protection : approbation manuelle requise avant qu'un job puisse s'exécuter.

**Ce que vous devez faire :**

1. Dans GitHub, allez dans **Settings → Environments → New environment** et créez `production`.
2. Activez **Required reviewers** et ajoutez-vous comme approbateur.
3. Dans `terraform-apply.yml`, ajoutez `environment: production` sur le job `apply`.
4. Déclenchez l'Apply et observez que GitHub vous demande une approbation avant d'exécuter les étapes.

```yaml
jobs:
  apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    environment: production   # ← protection d'environnement
```

> 💡 Avec cette configuration, même si quelqu'un déclenche le workflow, **il faut une approbation explicite** d'un reviewer avant que les credentials Azure et les étapes Terraform s'exécutent.

**Questions de réflexion :**
- Quelle est la différence entre `workflow_dispatch` avec confirmation manuelle et une protection d'environnement GitHub ?
- Pourquoi l'étape `terraform plan` est-elle re-exécutée dans le workflow Apply plutôt que de réutiliser le plan généré dans la PR ?

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

### 📝 Pour aller plus loin : OIDC (Workload Identity Federation)

La méthode Service Principal utilise un **secret qui expire** et doit être renouvelé. L'alternative moderne est **OIDC (OpenID Connect)** : GitHub prouve son identité à Azure sans jamais partager de secret.

**Principe :**

```
GitHub Actions                Azure
──────────────                ─────────────────────────────
Exécute le job  ──► présente un token JWT ──► Azure valide
                                              le token et
                                              accorde l'accès
                                              (pas de secret !)
```

**Configuration Azure :**

```bash
# Créer une app registration
az ad app create --display-name "github-oidc-terraform"

# Ajouter une federated credential (autorise le repo GitHub à se connecter)
az ad app federated-credential create \
  --id <APP_ID> \
  --parameters '{
    "name": "github-actions",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<ORG>/<REPO>:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

**Dans le workflow GitHub Actions :**

```yaml
permissions:
  id-token: write   # indispensable pour OIDC
  contents: read

steps:
  - name: Azure Login (OIDC)
    uses: azure/login@v2
    with:
      client-id:       ${{ secrets.ARM_CLIENT_ID }}
      tenant-id:       ${{ secrets.ARM_TENANT_ID }}
      subscription-id: ${{ secrets.ARM_SUBSCRIPTION_ID }}
      # Pas de client-secret !
```

> 💡 Avec OIDC, les seuls secrets GitHub sont `ARM_CLIENT_ID`, `ARM_TENANT_ID` et `ARM_SUBSCRIPTION_ID` — **pas de `ARM_CLIENT_SECRET`**. En cas de compromission du dépôt, aucun secret rotatif n'est exposé.
