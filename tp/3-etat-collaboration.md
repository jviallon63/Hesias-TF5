---
layout: tp
title: "TP 3 - State distant et gestion multi-environnements"
---

# 📦 Contexte

Votre équipe grossit, plusieurs développeurs travaillent sur la même infrastructure. Dans ce TP, vous allez migrer vers un **state distant** sur Azure Blob Storage, puis structurer un projet **multi-environnements** (staging, prod) en appliquant des **NSG** (Network Security Groups) sur un réseau partagé.s

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

## 🗂️ Partie 3.1 - Créer le Storage Account pour le backend distant

Le Storage Account qui hébergera les states ne peut pas avoir son propre state dans Azure. On commence donc avec un backend **local**, que l'on supprimera ensuite.

**Ce que vous devez faire :**

- Créez un dossier `tp3-bootstrap/` avec un `providers.tf` et un `main.tf`.
- Configurez un **backend local** dans `providers.tf`.
- Dans `main.tf`, déclarez les ressources nécessaires pour créer :
  1. Un **Resource Group** dédié à l'infrastructure Terraform : `rg-tfstate`
  2. Un `azurerm_storage_account` (nom unique, versioning activé et soft delete activé)
  3. Un `azurerm_storage_container` dans ce Storage Account, nommé `tfstate`

Template de création **Storage Account** et **Container**

```hcl
resource "azurerm_storage_account" "tfstate" {
  name                     = "tfstate..."
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = "West Europe"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    # Activer le versioning

    # Activer le soft delete
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id  = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}
```

**Questions de réflexion :**
- Pourquoi ne peut-on pas utiliser un backend distant pour stocker le state du Storage Account lui-même ?
- Pourquoi nous n'activons pas le locking sur le storage account pour sécuriser le state ? 

<!---
{::nomarkdown}
<details><summary>Solution - Étape 3.1.1</summary>
{:/nomarkdown}

`providers.tf` :

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
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
resource "azurerm_resource_group" "rg_tfstate" {
  name     = "rg-tfstate"
  location = "West Europe"
}

resource "azurerm_storage_account" "tfstate" {
  name                     = "tfstate..."
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = "West Europe"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      permanent_delete_enabled = true
      days = 14
  }
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id  = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}
```

{::nomarkdown}
</details>
{:/nomarkdown}
-->

---

## 🗂️ Partie 3.2 - Structure multi-environnements avec backend distant

---

### 📝 Étape 3.2.1 - Créer la structure de répertoires

L'objectif est d'avoir **un state Azure par environnement**, tous stockés dans le même container `tfstate` mais sous des clés différentes.

**Ce que vous devez faire :**

Créez la structure suivante :

```
tp3-nsg/
├── shared/          ← réseau commun (VNet, Subnet)
│   ├── providers.tf
│   ├── main.tf
├── staging/         ← NSG staging
│   ├── providers.tf
│   ├── main.tf
└── prod/            ← NSG prod
    ├── providers.tf
    ├── main.tf
```

Dans `shared/providers.tf`, déclarez :
1. Le providers `azurerm`
2. Le backend remote qui utilise le storage account créé précédement

Dans `shared/main.tf`, déclarez :
1. Un Resource Group `rg-tp3-shared`
2. Un VNet `vnet-tp3` avec l'espace `10.0.0.0/16`
3. Deux subnets : `snet-staging` (`10.0.1.0/24`), `snet-prod` (`10.0.2.0/24`)

Initialisez et appliquez votre projet depuis le répertoire `shared/`.

> 💡 Chaque répertoire est un **projet Terraform indépendant** avec son propre `terraform init`. La clé (`key`) dans le bloc `backend "azurerm"` différencie les states.

**Questions de réflexion :**
- Pourquoi le réseau est-il dans un répertoire `shared/` séparé des NSG ?

<!---
{::nomarkdown}
<details><summary>Solution - Étape 3.2.1</summary>
{:/nomarkdown}

Template de `providers.tf` :

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
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

Pour **`staging/`** : `key = "staging.tfstate"`, pour **`prod/`** : `key = "prod.tfstate"`.

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

resource "azurerm_subnet" "snet_staging" {
  name                 = "snet-staging"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "snet_prod" {
  name                 = "snet-prod"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}
```

Vérifiez dans le portail Azure : un blob `shared.tfstate` doit être apparu dans le container `tfstate`.

{::nomarkdown}
</details>
{:/nomarkdown}
-->

---

### 📝 Étape 3.2.3 - Déployer les NSG par environnement

Chaque environnement a des règles NSG différentes.

**Ce que vous devez faire :**

Pour chaque environnement (`staging/`, `prod/`) :

1. Créer `providers.tf`.
2. Dans `main.tf` récupérez l'ID du subnet correspondant via un **data source** `azurerm_subnet`, ainsi que le nom du ressource group.
3. Créez un **`azurerm_resource_group`** pour **staging** ou **prod**
4. Créez un **`azurerm_network_security_group`** avec des règles adaptées à l'environnement :
   - `staging` : autoriser RDP (3389) et SSH (22) depuis Internet
   - `prod` : aucun accès entrant depuis Internet (règle deny-all)
5. Associez le NSG au subnet via `azurerm_subnet_network_security_group_association`.

Template de création d'une NSG : 

```hcl
resource "azurerm_network_security_group" "nsg_staging" {
  name                = "nsg-tp3-staging"
  location            = ...
  resource_group_name = ...

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
}

resource "azurerm_subnet_network_security_group_association" "staging" {
  subnet_id                 = ...
  network_security_group_id = ...
}
```

**Questions de réflexion :**
- Pourquoi utilise-t-on un data source pour le subnet plutôt qu'une référence directe ?
- Quel est l'inconvenient de cette solution ? Imaginez une infrastructure avec x subnets et chacun des dizaines de NSG.

<!---
{::nomarkdown}
<details><summary>Solution - Étape 3.2.3</summary>
{:/nomarkdown}

Pour `staging/` :

```hcl
data "azurerm_subnet" "snet_staging" {
  name                 = "snet-staging"
  virtual_network_name = "vnet-tp3"
  resource_group_name  = "rg-tp3-shared"
}

resource "azurerm_resource_group" "staging" {
  name     = "rg-tp3-staging"
  location = "West Europe"
}

resource "azurerm_network_security_group" "nsg_staging" {
  name                = "nsg-tp3-staging"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name

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

resource "azurerm_subnet_network_security_group_association" "staging" {
  subnet_id                 = data.azurerm_subnet.snet_staging.id
  network_security_group_id = azurerm_network_security_group.nsg_staging.id
}
```

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

Déployez chaque environnement

Vérifiez dans le container `tfstate` : vous devez voir `staging.tfstate` et `prod.tfstate` en plus de `shared.tfstate`.

{::nomarkdown}
</details>
{:/nomarkdown}
-->

---

## 🗂️ Partie 3.3 - Import d'une ressource existante

On souhaite importer dans nos scripts terraform l'environnement `dev` déjà existant.

**Avant de commencer :**

- Depuis le **portail Azure**, créez manuellement un nouveau Resource Group `rg-tp3-dev`.
- Ajouter un nouveau NSG `nsg-tp3-dev`, avec une `security_rule`.
- Notez bien l'**ID Azure complet** de ce NSG (visible dans le portail, onglet "Parameters" > "Properties").

**Ce que vous devez faire :**

- Créer une nouvelle structure de répertoire pour l'environnement `dev`.
- Créer le fichier `provider.tf`.
- Initialiser le fichier `main.tf` avec les blocs `resource "azurerm_resource_group" "dev` et `resource "azurerm_network_security_group" "nsg_dev`. Les blocs contiennent le minimum d'information pour identifier la ressource `name`, `location`, `resource_group_name`
- Lancer l'init du projet et importer la ressource avec `terraform import` pour associer la ressource existante à ce bloc.

> 💡 La syntaxe est : `terraform import <type>.<nom_local> <id_azure>`

Après l'import :
1. Lancez `terraform plan` - que devrait-il afficher ?
2. Ajustez la configuration si nécessaire pour atteindre l'état `No changes`.

**Questions de réflexion :**
- Que contient le state après l'import ? Utilisez `terraform state show` pour l'explorer.
- Que se passe-t-il si vous lancez `terraform apply` sans avoir aligné la configuration avec la réalité Azure ?

<!---
{::nomarkdown}
<details><summary>Solution - Étape 3.3.1</summary>
{:/nomarkdown}

Ajoutez dans `dev/main.tf` :

```hcl
resource "azurerm_resource_group" "dev" {
  name     = "rg-tp3-dev"
  location = "West Europe"
}

resource "azurerm_network_security_group" "nsg_dev" {
  name                = "nsg-tp3-dev"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
}
```

Puis importez :

```bash
terraform import azurerm_network_security_group.nsg_dev /subscriptions/37fe744e-5727-4031-a37a-f19348de8bf3/resourceGroups/rg-tp3-dev/providers/Microsoft.Network/networkSecurityGroups/nsg-tp3-dev
```

`aztfexport` permet d'importer une ressource sans initialiser de fichier tf avant : 

```bash
aztfexport resource /subscriptions/37fe744e-5727-4031-a37a-f19348de8bf3/resourceGroups/rg-tp3-dev/providers/Microsoft.Network/networkSecurityGroups/nsg-tp3-dev
```

{::nomarkdown}
</details>
{:/nomarkdown}
-->

---

## 🗂️ Partie 3.4 - Manipulation du state

---

### 📝 Étape 3.4.1 - Inspecter le state

**Ce que vous devez faire :**

Depuis le répertoire `staging/`, explorez le state avec les commandes suivantes et notez ce que retourne chacune :

| Commande | Ce qu'elle fait |
|---|---|
| `terraform state list` | ? |
| `terraform state show <adresse>` | ? |
| `terraform show` | ? |
| `terraform show -json \| jq .` | ? |

<!---
{::nomarkdown}
<details><summary>Solution - Étape 3.4.1</summary>
{:/nomarkdown}

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
-->

---

### 📝 Étape 3.4.2 - Renommer une ressource dans le state (`mv`)

**Contexte :** vous souhaitez renommer le label local du NSG de `nsg_staging` en `main` pour uniformiser les conventions.

**Ce que vous devez faire :**

1. Renommez le bloc resource dans `main.tf` : `azurerm_network_security_group.nsg_staging` → `azurerm_network_security_group.main`
2. Sans toucher au state, lancez `terraform plan`. Que se passe-t-il ?
3. Utilisez `terraform state mv` pour synchroniser le renommage dans le state.
4. Relancez `terraform plan`. Que se passe-t-il maintenant ?

---

### 📝 Étape 3.4.3 - Retirer une ressource du state (`rm`)

**Contexte :** vous souhaitez que Terraform **arrête de gérer** l'association NSG/subnet (`azurerm_subnet_network_security_group_association`) sans la supprimer dans Azure.

**Ce que vous devez faire :**

1. Utilisez `terraform state rm` pour retirer l'association du state.
2. Lancez `terraform plan`. Que propose Terraform ?
3. Supprimez également le bloc resource correspondant dans `main.tf`.
2. Relancez `terraform plan`. Que propose Terraform maintenant ?

> 💡 `state rm` est utile pour "désadopter" une ressource sans la détruire - par exemple pour la confier à une autre équipe ou à un autre projet Terraform.

---

## 🧹 Nettoyage

Détruisez dans l'ordre : environnements d'abord (ils dépendent du réseau partagé), puis le réseau, puis `rg-tfstate`.
