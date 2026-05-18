---
title: "TP 1 — Prise en main de Terraform"
objective: "Installer Terraform, créer un premier fichier de configuration, connecter Azure et provisionner un Resource Group."
layout: tp
---

# 📦 Contexte

Votre équipe adopte une approche **Infrastructure as Code** avec Terraform. Dans ce premier TP, vous allez mettre en place votre environnement de travail, écrire votre premier fichier de configuration et créer un **Resource Group** sur Microsoft Azure.

---

## 🎯 Objectifs

<div class="section objective">

1. Installer Terraform sur votre machine
2. Créer son premier fichier `.tf`
3. Configurer la connexion Azure
4. Initialiser et appliquer la configuration pour créer un Resource Group
5. Explorer les fichiers générés par Terraform

</div>

---

## 📝 Étape 1 — Installer Terraform

Téléchargez et installez Terraform depuis le site officiel :  
👉 [https://developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install)

Vérifiez l'installation :

```bash
terraform -version
```

> Vous devez obtenir une version **>= 1.5**.

---

## 📝 Étape 2 — Créer son premier fichier `.tf`

Créez un dossier de travail et initialisez votre projet :

```bash
mkdir tp-terraform && cd tp-terraform
```

Créez un fichier `main.tf` avec le contenu suivant :

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "tp" {
  name     = "rg-tp-terraform"
  location = "West Europe"
}
```

---

## 📝 Étape 3 — Configurer la connexion Azure

Connectez-vous à Azure via la CLI :

```bash
az login
```

Vérifiez que vous êtes bien connecté et sur le bon abonnement :

```bash
az account show
```

> Si vous avez plusieurs abonnements, sélectionnez le bon avec :
> ```bash
> az account set --subscription "<nom-ou-id>"
> ```

---

## 📝 Étape 4 — Initialiser et appliquer la configuration

**Initialiser** le répertoire Terraform (télécharge le provider Azure) :

```bash
terraform init
```

**Prévisualiser** les changements qui vont être appliqués :

```bash
terraform plan
```

**Appliquer** la configuration pour créer le Resource Group :

```bash
terraform apply
```

Tapez `yes` pour confirmer.

---

## 📝 Étape 5 — Explorer les fichiers générés

Après l'exécution, listez les fichiers présents dans votre dossier :

```bash
ls -la
```

<div class="section tasks">

Identifiez et décrivez le rôle de chacun des fichiers suivants :

| Fichier | Rôle |
|---|---|
| `.terraform/` | ? |
| `.terraform.lock.hcl` | ? |
| `terraform.tfstate` | ? |

</div>

> 💡 Consultez la [documentation officielle](https://developer.hashicorp.com/terraform/language/state) pour comprendre l'état Terraform (`tfstate`).

---

## ✅ Résultat attendu

<div class="section objective">

- Le Resource Group `rg-tp-terraform` est visible dans le portail Azure.
- La commande `terraform show` affiche les attributs de la ressource créée.
- Vous êtes en mesure d'expliquer le contenu des fichiers générés.

</div>

---

## 🧹 Nettoyage (optionnel)

Pour supprimer les ressources créées et éviter des coûts inutiles :

```bash
terraform destroy
```
