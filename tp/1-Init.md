---
layout: tp
title: "TP 1 - Prise en main de Terraform"
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

Terraform est un outil open-source maintenu par HashiCorp. Il s'installe comme un binaire unique sur votre machine.

**Ce que vous devez faire :**

- Rendez-vous sur la [documentation officielle d'installation](https://developer.hashicorp.com/terraform/install) et choisissez la méthode adaptée à votre système d'exploitation.
- Une fois installé, vérifiez que l'outil est accessible depuis votre terminal en interrogeant sa version.

```bash
terraform -version
```

> La version affichée doit être >= 1.15.

---

## 📝 Étape 2 — Créer son premier fichier `.tf`

Un fichier `.tf` est un fichier de configuration Terraform écrit en **HCL (HashiCorp Configuration Language)**. Il déclare les ressources que vous souhaitez créer.

**Ce que vous devez faire :**

- Créez un nouveau dossier dédié à ce TP et placez-vous dedans.
- Dans ce dossier, créez un fichier `main.tf`.
- Ce fichier doit contenir **trois blocs distincts** :
  1. Un bloc **`terraform`** qui déclare le provider requis (`azurerm`) et contraint sa version.
  2. Un bloc **`provider`** qui configure le provider Azure.
  3. Un bloc **`resource`** qui déclare un Resource Group Azure nommé `tp-terraform` dans la région `West Europe`.

> 💡 Consultez la [documentation du provider azurerm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) pour trouver le nom exact du type de ressource et ses arguments obligatoires. Cherchez `azurerm_resource_group`.

**Questions de réflexion :**
- Pourquoi est-il recommandé de contraindre la version d'un provider ?

{::nomarkdown}
<details><summary>Solution — Étape 2</summary>
{:/nomarkdown}

Contenu du fichier `main.tf` :

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "tp" {
  name     = "tp-terraform"
  location = "West Europe"
}
```

> `~> 4.0` signifie "toute version >= 4.0 et < 5.0". Cela évite les breaking changes lors d'une montée de version majeure.

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 📝 Étape 3 — Configurer la connexion Azure

Terraform a besoin de s'authentifier auprès d'Azure pour créer des ressources. Plusieurs méthodes existent (Service Principal, Managed Identity, CLI…). Dans ce TP, nous utilisons **Azure CLI**, la méthode la plus simple en local.

**Ce que vous devez faire :**

- Assurez-vous que `az` (Azure CLI) est installé sur votre machine. Sinon, installez-le depuis la [documentation officielle](https://learn.microsoft.com/cli/azure/install-azure-cli).
- Connectez-vous à Azure via la CLI.
- Vérifiez que vous êtes bien positionné sur le bon abonnement (subscription). Si vous en avez plusieurs, sélectionnez le bon.

**Verification de l'installation :**
```bash
az version
```

**Connexion interactive :**
```bash
az login
```

**Vérifier l'abonnement actif :**
```bash
az account show
```

**Changer d'abonnement si nécessaire :**
```bash
az account list --output table
az account set --subscription "<nom-ou-id-de-labonnement>"
```

---

## 📝 Étape 4 — Initialiser et appliquer la configuration

Le workflow Terraform suit toujours le même enchaînement : **init → plan → apply**. Chaque étape a un rôle précis.

**Ce que vous devez faire :**

- **Initialisez** votre répertoire de travail. Cette commande prépare l'environnement local : elle télécharge le provider déclaré et crée les fichiers internes nécessaires.
- **Planifiez** l'exécution. Cette commande analyse votre configuration et affiche ce qui va être créé, modifié ou supprimé — sans rien toucher à Azure. Lisez attentivement la sortie.
- **Appliquez** la configuration. Cette commande exécute réellement les changements sur Azure. Une confirmation vous sera demandée.

> 💡 Cherchez dans la documentation Terraform les commandes `terraform init`, `terraform plan` et `terraform apply`. Prêtez attention aux flags disponibles (`-out`, `-auto-approve`, `-var`…).

**Questions de réflexion :**
- Explorer le plan généré avant l'apply.
- Que se passe-t-il si vous relancez `terraform apply` une deuxième fois sans modifier le fichier `.tf` ?

{::nomarkdown}
<details><summary>Solution — Étape 4</summary>
{:/nomarkdown}

```bash
# 1. Initialiser le répertoire (télécharge le provider azurerm)
terraform init

# 2. Prévisualiser les changements
terraform plan

# 3. Appliquer la configuration
terraform apply
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 📝 Étape 5 — Explorer les fichiers générés

Après l'initialisation et l'application, Terraform a créé plusieurs fichiers et dossiers dans votre répertoire de travail. Chacun joue un rôle fondamental.

**Ce que vous devez faire :**

- Listez tous les fichiers du répertoire (y compris les fichiers cachés).
- Pour chaque élément ci-dessous, explorez son contenu et répondez aux questions associées.

<div class="section tasks">

| Élément | Questions d'exploration |
|---|---|
| `.terraform/` | Que contient ce dossier ? Pourquoi ne doit-il pas être commité dans Git ? |
| `.terraform.lock.hcl` | À quoi ressemble son contenu ? Quel est son rôle par rapport à la version du provider ? |
| `terraform.tfstate` | Ouvrez ce fichier. Que représente-t-il ? Comparer la description de la ressource avec la documentation `azurem_resource_group` |

</div>

> 💡 Consultez la [documentation sur le state Terraform](https://developer.hashicorp.com/terraform/language/state) et la page sur le [`.terraform.lock.hcl`](https://developer.hashicorp.com/terraform/language/files/dependency-lock) pour approfondir.

{::nomarkdown}
<details><summary>Solution — Étape 5</summary>
{:/nomarkdown}

**Rôle de chaque élément :**

| Élément | Rôle |
|---|---|
| `.terraform/` | Cache local contenant les binaires des providers téléchargés. À ajouter dans `.gitignore`. |
| `.terraform.lock.hcl` | Fichier de verrouillage des versions exactes des providers. **Doit** être commité pour garantir la reproductibilité. |
| `terraform.tfstate` | Représente l'état courant de l'infrastructure gérée par Terraform (mapping entre la config et les ressources réelles). Peut contenir des données sensibles — à ne pas commiter, à stocker dans un **backend distant** (ex : Azure Blob Storage) en production. |

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🧹 Nettoyage

Pour supprimer les ressources créées et éviter des coûts inutiles, détruisez l'infrastructure gérée par Terraform. Cherchez la commande correspondante dans la documentation.

{::nomarkdown}
<details><summary>Solution — Nettoyage</summary>
{:/nomarkdown}

```bash
terraform destroy
```

{::nomarkdown}
</details>
{:/nomarkdown}

