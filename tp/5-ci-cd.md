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

4. Une fois le dépôt créé, allez dans **Settings → Secrets and variables → Actions** et ajoutez les secrets dans **New repository secret** : 
- `ARM_CLIENT_ID` = `clientId`
- `ARM_CLIENT_SECRET` = `clientSecret`
- `ARM_SUBSCRIPTION_ID` = `subscriptionId`
- `ARM_TENANT_ID` = `tenantId`

> 💡 Le provider `azurerm` lit automatiquement cette variable d'environnement pour s'authentifier. Aucune credential ne doit apparaître dans vos fichiers `.tf`.

---

### 📝 Étape 5.1.3 - Initialiser le state remote

Le projet fourni pour ce TP contient un répertoire `state` dans le zip. Ce répertoire permet de créer le Storage Account qui servira de backend distant Terraform.

**Ce que vous devez faire :**

1. Depuis votre terminal, placez-vous dans le répertoire `state`.
2. Exécutez localement les commandes Terraform pour créer l'infrastructure.
3. Notez le nom du Storage Account généré : vous en aurez besoin pour configurer le backend distant.

> 💡 **À noter :**
> Le nom du Storage Account est généré aléatoirement grâce au provider `random`.
> Le projet `state` utilise un state local, mais ce state n'est pas versionné dans Git (vérifiez le `.gitignore`).

Placez-vous dans le projet `terraform` : vous allez configurer le backend distant et le provider Azure.

**Ce que vous devez faire :**

1. Configurez le backend remote avec le nom du Storage Account créé précédemment.
2. Générez un plan Terraform pour valider le bon fonctionnement du projet.

> 💡 Si le plan est un succès, n'oubliez pas de commiter puis de pousser votre code sur votre dépôt GitHub :
>
> ```bash
> git add .
> git commit -m "Configure backend and Azure provider"
> git push origin main
> ```

---

## 🗂️ Partie 5.2 - Créer le workflow

Le projet importé contient déjà un workflow GitHub Actions dans `.github/workflows/terraform.yml`.
Ce workflow exécute les commandes Terraform suivantes : `init`, `plan`, `apply` et `destroy`.

### 📝 Étape 5.2.1 - Tester l'exécution du workflow

**Ce que vous devez faire :**

1. Depuis votre termine, créez une branche de travail : `git checkout -b feature/test-workflow`
2. Faites une modification dans le dossier `terraform/` (par exemple une description, un tag, ou une règle).
3. Commitez et poussez votre branche : `git add . && git commit -m "Test workflow terraform" && git push -u origin feature/test-workflow`
4. Ouvrez une Pull Request (PR) vers `main` depuis GitHub.
5. Vérifiez dans l'onglet **Actions** que le workflow démarre automatiquement.
6. Vérifiez dans la PR que le plan Terraform est publié en commentaire.

> 💡 **Pourquoi `-out=tfplan` ?**
> Sans ce flag, `plan` et `apply` font chacun leur propre calcul. Entre les deux, une autre personne peut avoir modifié l'infrastructure ou poussé un nouveau commit. Avec `-out`, l'`apply` exécute **exactement** ce qui a été planifié et affiché dans la PR, rien de plus, rien de moins.

> 💡 **Analyse du plan**
> Le step `Comment Plan On PR` publie le résultat du plan directement dans la PR pour faciliter la revue humaine.

**Questions de réflexion :**
- Pourquoi `continue-on-error: true` est-il utilisé sur le step `plan` ?

L'`apply` de l'infrastructure doit se faire manuellement une fois le plan validé. Pour déclencher manuellement le workflow, le fichier `.github/workflows/terraform.yml` doit être présent sur la branche `main`. Mergez votre PR, puis :

7. Retournez dans l'onglet **Actions**.
8. Sélectionnez le workflow **Terraform CI/CD** dans la colonne à gauche.
9. Dans **Run workflow**, sélectionnez la branche `main`, choisissez `apply` et déclenchez le workflow.
10. Vérifiez que l'`apply` fonctionne comme attendu.
11. Répétez l'opération en sélectionnant `destroy` pour nettoyer l'infrastructure.

> 💡 **Plan et apply dans le même job** : c'est intentionnel. Si on séparait en deux jobs distincts, l'état d'Azure pourrait changer entre les deux. En exécutant les deux étapes dans le même job, la fenêtre de temps est de quelques secondes — et surtout, l'`apply` utilise le fichier binaire `tfplan` généré juste avant, pas un nouveau calcul.

---

### 📝 Étape 5.2.2 - Ajouter les steps de CI

Vous allez améliorer les contrôles exécutés par le workflow en parallèle du job de plan. L'objectif est de donner toutes les informations nécessaires au reviewer pour valider la Pull Request dans de bonnes conditions. Vous allez ajouter les jobs suivants :

- `terraform fmt -check -recursive` : vérifie le formatage Terraform.
- `terraform validate` : vérifie la syntaxe et la cohérence du code Terraform.
- `tflint` : détecte les mauvaises pratiques et erreurs de configuration. Installation locale : https://github.com/terraform-linters/tflint#installation
- `tfsec` : détecte les problèmes de sécurité sur le code IaC. Installation locale : https://github.com/aquasecurity/tfsec#installation

**Ce que vous devez faire :**

1. Modifiez le workflow et ajoutez les jobs suivants. Ils doivent s'exécuter en parallèle du job `plan` :

| job_name | step | command |
| --- | --- | --- |
| `validate` | `format` | `terraform fmt -check -recursive` |
| `validate` | `validate` | `terraform validate` |
| `validate` | `linter` | `tflint --init && tflint` |
| `security` | `security` | `tfsec` |


**Aides :**

- `terraform validate` nécessite un `terraform init` du projet avant l'exécution de la commande.
- Pour exécuter `tflint`, utilisez :

```yml
- name: Setup TFLint
  uses: terraform-linters/setup-tflint@v4
```

- Pour `tfsec`, utilisez :

```yml
- name: Install tfsec
  run: |
    curl -sSL -o /tmp/tfsec https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64
    chmod +x /tmp/tfsec
    sudo mv /tmp/tfsec /usr/local/bin/tfsec
    tfsec --version
```

> 💡 Toutes les commandes utilisées par la CI sont exécutables en local. N'hésitez pas à les tester : c'est une bonne pratique de valider localement que la CI peut s'exécuter sans problème avant de pousser le code.

{::nomarkdown}
<details><summary>Solution - Étape 5.2.2</summary>
{:/nomarkdown}

Dans `.github/workflows/terraform.yml` :

```yml
...
jobs:
  validate:
    name: Validate
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.9"

      - name: Setup TFLint
        uses: terraform-linters/setup-tflint@v4

      - name: Terraform Init
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: terraform init -input=false

      - name: Terraform fmt (format)
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: terraform fmt -check -recursive

      - name: Terraform validate
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: terraform validate

      - name: Linter
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: tflint --init && tflint

  security:
    name: Security
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install tfsec
        run: |
          curl -sSL -o /tmp/tfsec https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64
          chmod +x /tmp/tfsec
          sudo mv /tmp/tfsec /usr/local/bin/tfsec
          tfsec --version

      - name: tfsec
        working-directory: ${{ env.TF_WORKING_DIR }}
        run: tfsec

  plan:
  ...
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🧹 Nettoyage

Détruisez toutes les ressources en exécutant le workflow de destroy. Vérifiez sur le portail Azure que tout est bien détruit.
