---
title: "TP 3 — State distant et gestion multi-environnements"
objective: "Configurer un backend Azure distant, gérer plusieurs environnements avec des states séparés et maîtriser les commandes de manipulation du state."
---

# 📦 Contexte

Votre équipe grossit. Plusieurs développeurs travaillent sur la même infrastructure et les fichiers `terraform.tfstate` locaux créent des conflits. Dans ce TP, vous allez migrer vers un **state distant** sur Azure Blob Storage, puis structurer un projet **multi-environnements** (dev, staging, prod) en appliquant des **NSG** (Network Security Groups) sur un réseau partagé. Vous terminerez par la maîtrise des commandes d'inspection et de manipulation du state.

---

## 🎯 Objectifs

<div class="section objective">

1. Créer un Storage Account Azure dédié au state Terraform et y migrer le backend
2. Structurer un projet multi-environnements avec des répertoires et des states séparés
3. Déployer un réseau (VNet, Subnet) et des NSG différenciés par environnement
4. Importer une ressource créée manuellement dans le state Terraform
5. Maîtriser les commandes `terraform state list`, `show`, `mv`, `rm`

</div>

---

## 🗂️ Partie 3.1 — Créer le Storage Account pour le backend distant

> **Point de départ :** un nouveau dossier vide. Votre formateur expliquera le concept de backend distant et ses enjeux avant cette partie.

---

### 📝 Étape 3.1.1 — Bootstrapper le Storage Account avec un backend local

Le Storage Account qui hébergera les states ne peut pas avoir son propre state dans Azure — c'est un problème de bootstrap. On commence donc avec un backend **local**, que l'on supprimera ensuite.

**Ce que vous devez faire :**

- Créez un dossier `tp3-bootstrap/` avec un `providers.tf` et un `main.tf`.
- Configurez un **backend local** dans `providers.tf`.
- Dans `main.tf`, déclarez les ressources nécessaires pour créer :
  1. Un **Resource Group** dédié à l'infrastructure Terraform : `rg-tfstate`
  2. Un **Storage Account** (nom unique, type `Standard_LRS`, `BlobServiceProperties` avec versioning activé)
  3. Un **Container** dans ce Storage Account, nommé `tfstate`

> 💡 Le nom du Storage Account doit être **globalement unique** sur Azure (3-24 caractères, minuscules et chiffres uniquement). Cherchez dans la doc `azurerm_storage_account` et `azurerm_storage_container`.

**Questions de réflexion :**
- Pourquoi ne peut-on pas utiliser un backend distant pour stocker le state du Storage Account lui-même ?
- Que se passe-t-il si deux développeurs lancent `terraform apply` en même temps sur un backend local ?

{::nomarkdown}
<details><summary>Solution — Étape 3.1.1</summary>
{:/nomarkdown}

```bash
mkdir tp3-bootstrap && cd tp3-bootstrap
```

`providers.tf` :

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}
```

`main.tf` :

```hcl
resource "azurerm_resource_group" "tfstate" {
  name     = "rg-tfstate"
  location = "West Europe"
}

resource "azurerm_storage_account" "tfstate" {
  name                     = "stotfstate${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    versioning_enabled = true
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}
```

Ajoutez le provider `random` dans le bloc `required_providers` :

```hcl
random = {
  source  = "hashicorp/random"
  version = "~> 3.0"
}
```

```bash
terraform init
terraform apply
```

Notez le nom du Storage Account généré — vous en aurez besoin pour les étapes suivantes :

```bash
terraform output -raw storage_account_name
```

Ajoutez dans `outputs.tf` :

```hcl
output "storage_account_name" {
  value = azurerm_storage_account.tfstate.name
}

output "resource_group_name" {
  value = azurerm_resource_group.tfstate.name
}
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 3.1.2 — Supprimer le tfstate local du bootstrap

Le Storage Account existe maintenant dans Azure. Le tfstate local de `tp3-bootstrap` doit être conservé **précieusement** — c'est le seul moyen pour Terraform de gérer cette ressource. Ne le migrez pas vers le backend distant qu'il héberge lui-même.

**Ce que vous devez faire :**

- Ajoutez `terraform.tfstate` et `terraform.tfstate.backup` dans un fichier `.gitignore` à la racine du projet.
- Vérifiez dans le portail Azure que le Storage Account et le container `tfstate` sont bien présents.
- Listez le contenu du container depuis la CLI Azure.

> 💡 Commande utile : `az storage container list --account-name <nom> --auth-mode login`

{::nomarkdown}
<details><summary>Solution — Étape 3.1.2</summary>
{:/nomarkdown}

`.gitignore` à la racine :

```
# Terraform state local
*.tfstate
*.tfstate.backup
.terraform/
.terraform.lock.hcl
terraform.tfvars
```

Vérifier depuis la CLI Azure :

```bash
az storage container list \
  --account-name <storage_account_name> \
  --auth-mode login \
  --output table
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🗂️ Partie 3.2 — Structure multi-environnements avec backend distant

> **Prérequis :** le Storage Account est déployé. Votre formateur présentera la stratégie de découpage par répertoire avant cette partie.

---

### 📝 Étape 3.2.1 — Créer la structure de répertoires

L'objectif est d'avoir **un state Azure par environnement**, tous stockés dans le même container `tfstate` mais sous des clés différentes.

**Ce que vous devez faire :**

Créez la structure suivante :

```
tp3-nsg/
├── shared/          ← réseau commun (VNet, Subnet)
│   ├── providers.tf
│   ├── main.tf
│   └── outputs.tf
├── dev/             ← NSG dev
│   ├── providers.tf
│   ├── main.tf
│   └── variables.tf
├── staging/         ← NSG staging
│   ├── providers.tf
│   ├── main.tf
│   └── variables.tf
└── prod/            ← NSG prod
    ├── providers.tf
    ├── main.tf
    └── variables.tf
```

> 💡 Chaque répertoire est un **projet Terraform indépendant** avec son propre `terraform init`. La clé (`key`) dans le bloc `backend "azurerm"` différencie les states.

**Questions de réflexion :**
- Quels sont les avantages et inconvénients de cette approche par répertoires vs l'utilisation de workspaces Terraform ?
- Pourquoi le réseau est-il dans un répertoire `shared/` séparé des NSG ?

{::nomarkdown}
<details><summary>Solution — Étape 3.2.1</summary>
{:/nomarkdown}

```bash
mkdir -p tp3-nsg/{shared,dev,staging,prod}
touch tp3-nsg/shared/{providers.tf,main.tf,outputs.tf}
touch tp3-nsg/dev/{providers.tf,main.tf,variables.tf}
touch tp3-nsg/staging/{providers.tf,main.tf,variables.tf}
touch tp3-nsg/prod/{providers.tf,main.tf,variables.tf}
```

Template de `providers.tf` pour **`shared/`** :

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "<votre_storage_account>"
    container_name       = "tfstate"
    key                  = "shared.tfstate"
  }
}

provider "azurerm" {
  features {}
}
```

Pour **`dev/`** : remplacez `key = "dev.tfstate"`, pour **`staging/`** : `key = "staging.tfstate"`, pour **`prod/`** : `key = "prod.tfstate"`.

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 3.2.2 — Déployer le réseau partagé

**Ce que vous devez faire :**

Dans `shared/main.tf`, déclarez :
1. Un Resource Group `rg-tp3-shared`
2. Un VNet `vnet-tp3` avec l'espace `10.0.0.0/16`
3. Trois subnets : `snet-dev` (`10.0.1.0/24`), `snet-staging` (`10.0.2.0/24`), `snet-prod` (`10.0.3.0/24`)

Dans `shared/outputs.tf`, exposez les IDs des trois subnets — les projets NSG en auront besoin.

Initialisez et appliquez depuis le répertoire `shared/`.

{::nomarkdown}
<details><summary>Solution — Étape 3.2.2</summary>
{:/nomarkdown}

`shared/main.tf` :

```hcl
resource "azurerm_resource_group" "shared" {
  name     = "rg-tp3-shared"
  location = "West Europe"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-tp3"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "snet_dev" {
  name                 = "snet-dev"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "snet_staging" {
  name                 = "snet-staging"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "snet_prod" {
  name                 = "snet-prod"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}
```

`shared/outputs.tf` :

```hcl
output "subnet_dev_id" {
  value = azurerm_subnet.snet_dev.id
}

output "subnet_staging_id" {
  value = azurerm_subnet.snet_staging.id
}

output "subnet_prod_id" {
  value = azurerm_subnet.snet_prod.id
}
```

```bash
cd tp3-nsg/shared
terraform init
terraform apply
```

Vérifiez dans le portail Azure : un blob `shared.tfstate` doit être apparu dans le container `tfstate`.

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 3.2.3 — Déployer les NSG par environnement

Chaque environnement a des règles NSG différentes. Vous allez factoriser la structure des règles via des variables.

**Ce que vous devez faire :**

Pour chaque environnement (`dev/`, `staging/`, `prod/`) :

1. Récupérez l'ID du subnet correspondant via un **data source** `azurerm_subnet` (ou copiez l'output de `shared/`).
2. Créez un **`azurerm_network_security_group`** avec des règles adaptées à l'environnement :
   - `dev` : autoriser RDP (3389) et SSH (22) depuis Internet
   - `staging` : autoriser uniquement SSH (22) depuis Internet
   - `prod` : aucun accès entrant depuis Internet (règle deny-all)
3. Associez le NSG au subnet via `azurerm_subnet_network_security_group_association`.

> 💡 Les règles sont définies dans des blocs `security_rule` imbriqués dans le NSG, ou via la ressource séparée `azurerm_network_security_rule`. Réfléchissez à quelle approche utiliser et pourquoi.

**Questions de réflexion :**
- Comment les règles NSG sont-elles évaluées (priorité, allow vs deny) ?
- Pourquoi utilise-t-on un data source pour le subnet plutôt qu'une référence directe ?

{::nomarkdown}
<details><summary>Solution — Étape 3.2.3</summary>
{:/nomarkdown}

Exemple pour **`dev/main.tf`** :

```hcl
data "azurerm_subnet" "snet_dev" {
  name                 = "snet-dev"
  virtual_network_name = "vnet-tp3"
  resource_group_name  = "rg-tp3-shared"
}

resource "azurerm_network_security_group" "nsg_dev" {
  name                = "nsg-tp3-dev"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-rdp"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "dev" {
  subnet_id                 = data.azurerm_subnet.snet_dev.id
  network_security_group_id = azurerm_network_security_group.nsg_dev.id
}
```

Pour `staging/` : gardez uniquement la règle SSH (supprimez RDP).

Pour `prod/main.tf` : une seule règle deny-all avec priorité haute :

```hcl
security_rule {
  name                       = "deny-internet-inbound"
  priority                   = 100
  direction                  = "Inbound"
  access                     = "Deny"
  protocol                   = "*"
  source_port_range          = "*"
  destination_port_range     = "*"
  source_address_prefix      = "Internet"
  destination_address_prefix = "*"
}
```

Déployez chaque environnement :

```bash
cd tp3-nsg/dev && terraform init && terraform apply
cd ../staging  && terraform init && terraform apply
cd ../prod     && terraform init && terraform apply
```

Vérifiez dans le container `tfstate` : vous devez voir `dev.tfstate`, `staging.tfstate` et `prod.tfstate` en plus de `shared.tfstate`.

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🗂️ Partie 3.3 — Import d'une ressource existante

> **Prérequis :** le réseau de la partie 3.2 est déployé. Votre formateur introduira le concept d'import avant cette partie.

---

### 📝 Étape 3.3.1 — Créer une ressource manuellement dans Azure

**Ce que vous devez faire :**

- Depuis le **portail Azure** (ou la CLI), créez manuellement un nouveau NSG nommé `nsg-tp3-import` dans le Resource Group `rg-tp3-shared`.
- Ajoutez-y une règle inbound SSH manuellement.
- Notez bien l'**ID Azure complet** de ce NSG (visible dans le portail, onglet "Properties" ou via `az network nsg show`).

> 💡 Cet exercice simule une ressource créée hors Terraform par un collègue ou une procédure d'urgence — ce qu'on appelle une ressource **"orpheline"** du point de vue du state.

{::nomarkdown}
<details><summary>Solution — Étape 3.3.1</summary>
{:/nomarkdown}

Via la CLI Azure :

```bash
az network nsg create \
  --name nsg-tp3-import \
  --resource-group rg-tp3-shared \
  --location westeurope

az network nsg rule create \
  --nsg-name nsg-tp3-import \
  --resource-group rg-tp3-shared \
  --name allow-ssh \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --destination-port-range 22
```

Récupérer l'ID du NSG :

```bash
az network nsg show \
  --name nsg-tp3-import \
  --resource-group rg-tp3-shared \
  --query id \
  --output tsv
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 3.3.2 — Importer la ressource dans Terraform

**Ce que vous devez faire :**

Dans l'un des projets environnement (ex. `dev/`), écrivez le bloc `resource` correspondant au NSG importé **sans** lancer `apply`. Puis utilisez `terraform import` pour associer la ressource existante à ce bloc.

Après l'import :
1. Lancez `terraform plan` — que devrait-il afficher ?
2. Ajustez la configuration si nécessaire pour atteindre l'état `No changes`.

> 💡 La syntaxe est : `terraform import <type>.<nom_local> <id_azure>`

**Questions de réflexion :**
- Que contient le state après l'import ? Utilisez `terraform state show` pour l'explorer.
- Que se passe-t-il si vous lancez `terraform apply` sans avoir aligné la configuration avec la réalité Azure ?

{::nomarkdown}
<details><summary>Solution — Étape 3.3.2</summary>
{:/nomarkdown}

Ajoutez dans `dev/main.tf` le bloc ressource vide (à compléter après l'import) :

```hcl
resource "azurerm_network_security_group" "nsg_import" {
  name                = "nsg-tp3-import"
  location            = var.location
  resource_group_name = var.resource_group_name
}
```

Puis importez :

```bash
terraform import azurerm_network_security_group.nsg_import \
  /subscriptions/<sub_id>/resourceGroups/rg-tp3-shared/providers/Microsoft.Network/networkSecurityGroups/nsg-tp3-import
```

Inspectez ce que Terraform a récupéré :

```bash
terraform state show azurerm_network_security_group.nsg_import
```

Lancez `terraform plan` — si des différences apparaissent (ex. la règle SSH n'est pas dans votre config), complétez le bloc `resource` pour les aligner. L'objectif est d'obtenir `No changes`.

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 3.3.3 — Comparaison avec aztfexport

Azure propose un outil officiel [`aztfexport`](https://github.com/Azure/aztfexport) qui automatise la génération de la configuration Terraform à partir de ressources Azure existantes.

**Ce que vous devez faire :**

- Installez `aztfexport` sur votre machine.
- Exportez le NSG `nsg-tp3-import` avec cet outil dans un dossier temporaire.
- Comparez la configuration générée avec celle que vous avez écrite manuellement.

> 💡 `aztfexport` peut exporter une ressource individuelle, un Resource Group entier ou un abonnement. Cherchez la commande dans la [documentation](https://github.com/Azure/aztfexport#usage).

**Questions de réflexion :**
- Quels sont les avantages et limites d'`aztfexport` par rapport à un import manuel ?
- La configuration générée est-elle directement utilisable en production ?

{::nomarkdown}
<details><summary>Solution — Étape 3.3.3</summary>
{:/nomarkdown}

Installation sur macOS :

```bash
brew install aztfexport
```

Export de la ressource :

```bash
mkdir /tmp/aztfexport-test && cd /tmp/aztfexport-test

aztfexport resource \
  /subscriptions/<sub_id>/resourceGroups/rg-tp3-shared/providers/Microsoft.Network/networkSecurityGroups/nsg-tp3-import
```

Ou export de tout le Resource Group :

```bash
aztfexport resource-group rg-tp3-shared
```

Comparez les fichiers générés (`main.tf`, `import.tf`) avec votre configuration manuelle. `aztfexport` génère souvent des configurations verbeuses avec tous les attributs optionnels — il est nécessaire de les nettoyer avant utilisation.

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🗂️ Partie 3.4 — Manipulation du state

> **Prérequis :** au moins un environnement est déployé avec son state distant. Votre formateur présentera les risques des manipulations de state avant cette partie.

---

### 📝 Étape 3.4.1 — Inspecter le state

**Ce que vous devez faire :**

Depuis le répertoire `dev/`, explorez le state avec les commandes suivantes et notez ce que retourne chacune :

| Commande | Ce qu'elle fait |
|---|---|
| `terraform state list` | ? |
| `terraform state show <adresse>` | ? |
| `terraform show` | ? |
| `terraform show -json \| jq .` | ? |

> 💡 L'`<adresse>` est le chemin complet d'une ressource dans le state, tel qu'affiché par `state list` (ex. `azurerm_network_security_group.nsg_dev`).

{::nomarkdown}
<details><summary>Solution — Étape 3.4.1</summary>
{:/nomarkdown}

```bash
# Lister toutes les ressources du state
terraform state list

# Inspecter une ressource spécifique
terraform state show azurerm_network_security_group.nsg_dev

# Afficher tout le state formaté
terraform show

# Afficher le state en JSON (nécessite jq)
terraform show -json | jq .
```

**Ce que retourne chaque commande :**

| Commande | Résultat |
|---|---|
| `state list` | Liste des adresses de toutes les ressources gérées |
| `state show <adresse>` | Tous les attributs d'une ressource (id, tags, règles…) |
| `show` | Vue lisible de tout l'état courant |
| `show -json` | État brut en JSON, exploitable par d'autres outils |

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 3.4.2 — Renommer une ressource dans le state (`mv`)

**Contexte :** vous souhaitez renommer le label local du NSG de `nsg_dev` en `main` pour uniformiser les conventions.

**Ce que vous devez faire :**

1. Renommez le bloc resource dans `main.tf` : `azurerm_network_security_group.nsg_dev` → `azurerm_network_security_group.main`
2. Sans toucher au state, lancez `terraform plan`. Que se passe-t-il ?
3. Utilisez `terraform state mv` pour synchroniser le renommage dans le state.
4. Relancez `terraform plan`. Que se passe-t-il maintenant ?

> ⚠️ `terraform state mv` modifie le state directement. Sur un backend distant, un verrou (lock) est automatiquement posé pendant l'opération.

{::nomarkdown}
<details><summary>Solution — Étape 3.4.2</summary>
{:/nomarkdown}

Après avoir renommé le bloc dans `main.tf`, le `plan` prévoit de **détruire** l'ancien NSG et d'en **créer** un nouveau — ce qui n'est pas souhaité.

La commande `mv` déplace l'adresse dans le state sans toucher à Azure :

```bash
terraform state mv \
  azurerm_network_security_group.nsg_dev \
  azurerm_network_security_group.main
```

Relancez ensuite :

```bash
terraform plan
# → No changes. Infrastructure is up-to-date.
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 3.4.3 — Retirer une ressource du state (`rm`)

**Contexte :** vous souhaitez que Terraform **arrête de gérer** l'association NSG/subnet (`azurerm_subnet_network_security_group_association`) sans la supprimer dans Azure.

**Ce que vous devez faire :**

1. Utilisez `terraform state rm` pour retirer l'association du state.
2. Lancez `terraform plan`. Que propose Terraform ?
3. Supprimez également le bloc resource correspondant dans `main.tf`.
4. Vérifiez dans le portail Azure que l'association existe toujours.

> 💡 `state rm` est utile pour "désadopter" une ressource sans la détruire — par exemple pour la confier à une autre équipe ou à un autre projet Terraform.

{::nomarkdown}
<details><summary>Solution — Étape 3.4.3</summary>
{:/nomarkdown}

```bash
# Lister pour trouver l'adresse exacte
terraform state list

# Retirer l'association du state
terraform state rm azurerm_subnet_network_security_group_association.dev
```

Après le `rm`, `terraform plan` propose de **recréer** l'association (elle n'est plus dans le state mais est dans la config). Pour éviter cela, supprimez aussi le bloc resource dans `main.tf`.

Vérifiez dans le portail Azure que le NSG est **toujours associé** au subnet — `state rm` ne touche pas à Azure.

{::nomarkdown}
</details>
{:/nomarkdown}

---

## ✅ Résultat attendu

<div class="section objective">

À la fin du TP 3 :

- Le container `tfstate` contient **4 fichiers** : `shared.tfstate`, `dev.tfstate`, `staging.tfstate`, `prod.tfstate`
- Chaque environnement a son propre NSG avec des règles adaptées, visible dans le portail Azure
- Vous avez importé une ressource créée manuellement et aligné sa configuration
- Vous maîtrisez les commandes `terraform state list`, `show`, `mv`, `rm`
- Vous pouvez expliquer la différence entre backend local et distant, et pourquoi le locking est critique

</div>

---

## 🧹 Nettoyage

Détruisez dans l'ordre : environnements d'abord (ils dépendent du réseau partagé), puis le réseau, puis le bootstrap.

{::nomarkdown}
<details><summary>Solution — Nettoyage</summary>
{:/nomarkdown}

```bash
# 1. Environnements NSG
cd tp3-nsg/prod    && terraform destroy
cd ../staging      && terraform destroy
cd ../dev          && terraform destroy

# 2. Réseau partagé
cd ../shared       && terraform destroy

# 3. Storage Account de bootstrap (backend local)
cd ../../tp3-bootstrap && terraform destroy
```

> ⚠️ Détruire le Storage Account supprime également tous les fichiers tfstate distants. Assurez-vous que toutes les ressources gérées ont bien été détruites avant.

{::nomarkdown}
</details>
{:/nomarkdown}
