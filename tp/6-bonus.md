---
layout: tp
title: "TP Bonus - Aller plus loin avec Terraform"
---

# 🎉 Contexte

Vous avez fini les TP principaux ? Bravo. Ce TP bonus regroupe **5 exercices indépendants** pour explorer des fonctionnalités de Terraform et du provider `azurerm` qui n'ont pas été abordées. Ils peuvent être réalisés dans n'importe quel ordre. Chaque exercice est autonome et peut être déposé dans un dossier dédié.

---

## 🗂️ Exercice 1 - Base de données PostgreSQL avec mot de passe aléatoire

### 🧩 Problème

Votre équipe doit déployer une base de données **Azure PostgreSQL Flexible Server**. Le mot de passe administrateur ne doit jamais être écrit en clair dans le code ou dans un `.tfvars`. Vous allez utiliser le provider **`random`** pour le générer automatiquement à chaque déploiement initial, puis le stabiliser entre les `apply`.

---

### 📝 Étape 1.1 - Configurer les deux providers

Créez un dossier `tp-bonus-postgres/` avec un `providers.tf`. Ce fichier doit déclarer **deux providers** :
- `azurerm` (comme d'habitude)
- `random` (source : `hashicorp/random`)

> 💡 Vous pouvez déclarer plusieurs providers dans le même bloc `terraform { required_providers { ... } }`.

{::nomarkdown}
<details><summary>Solution - Étape 1.1</summary>
{:/nomarkdown}

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "random" {}
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 1.2 - Générer le mot de passe

Dans `main.tf`, utilisez la ressource `random_password` pour générer un mot de passe de **16 caractères minimum**, avec des majuscules, minuscules, chiffres et caractères spéciaux. Stockez-le ensuite dans un `azurerm_key_vault_secret`.

> ⚠️ Une ressource `random_password` génère sa valeur **une seule fois** lors du premier `apply`. Les `apply` suivants ne la régénèrent pas — sauf si vous forcez la re-création avec `terraform apply -replace="random_password.admin"`.

**Ce que vous devez faire :**

1. Déclarez une ressource `random_password` avec les contraintes souhaitées.
2. Référencez `random_password.<nom>.result` comme mot de passe administrateur du serveur PostgreSQL.
3. Ajoutez un output de type `sensitive = true` pour afficher le mot de passe après le premier déploiement.

> 💡 Consultez la documentation : [registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)

{::nomarkdown}
<details><summary>Solution - Étape 1.2</summary>
{:/nomarkdown}

```hcl
resource "random_password" "admin" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "azurerm_resource_group" "postgres" {
  name     = "rg-bonus-postgres"
  location = "West Europe"
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "psql-bonus-${random_password.admin.id}"
  resource_group_name    = azurerm_resource_group.postgres.name
  location               = azurerm_resource_group.postgres.location
  version                = "16"
  administrator_login    = "psqladmin"
  administrator_password = random_password.admin.result
  zone                   = "1"

  storage_mb   = 32768
  sku_name     = "B_Standard_B1ms"
}

output "admin_password" {
  description = "Mot de passe administrateur PostgreSQL"
  value       = random_password.admin.result
  sensitive   = true
}
```

> Pour afficher la valeur d'un output `sensitive` :
> ```bash
> terraform output -raw admin_password
> ```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 💡 Pour aller encore plus loin

- Stockez le mot de passe dans un **Azure Key Vault** avec `azurerm_key_vault_secret` pour éviter de le lire en clair dans les outputs.
- Ajoutez une règle de firewall `azurerm_postgresql_flexible_server_firewall_rule` pour n'autoriser que votre IP.

---

## 🗂️ Exercice 2 - Dompter NetworkWatcherRG

### 🧩 Problème

Dès qu'Azure déploie une ressource réseau dans une région (VNet, NIC…), il crée automatiquement un Resource Group `NetworkWatcherRG` contenant un `NetworkWatcher`. Ce comportement est invisible mais génère un état « sale » : **des ressources Azure existent sans être dans votre state Terraform**.

Dans cet exercice vous allez reprendre le contrôle via deux approches complémentaires.

---

### 📝 Étape 2.1 - Explorer le bloc `features {}`

Le bloc `features {}` du provider `azurerm` expose des paramètres de comportement qui ne sont **pas** liés à des ressources Azure mais au fonctionnement du provider lui-même.

**Ce que vous devez faire :**

Créez un `providers.tf` dans un dossier `tp-bonus-network-watcher/` et configurez le bloc `features {}` avec :
- `resource_group.prevent_deletion_if_contains_resources = false` — pour pouvoir détruire un RG non vide sans erreur côté provider.
- `network.relaxed_locking = true` — pour éviter les blocages lors de mises à jour concurrentes sur les ressources réseau.

Appliquez ensuite la config et observez l'effet.

{::nomarkdown}
<details><summary>Solution - Étape 2.1</summary>
{:/nomarkdown}

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
  subscription_id = var.subscription_id

  features {
    resource_group {
      # Par défaut à true : Terraform refuse de supprimer un RG contenant des ressources.
      # Mettre à false pour autoriser la suppression forcée (utile en dev/CI).
      prevent_deletion_if_contains_resources = false
    }

    network {
      # Évite les erreurs de locking lors de modifications parallèles sur des VNets.
      relaxed_locking = true
    }
  }
}
```

> 💡 Consultez la liste complète des options disponibles dans `features {}` :
> [registry.terraform.io/providers/hashicorp/azurerm/latest/docs#features](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#features)

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 2.2 - Déclarer le NetworkWatcher explicitement

La clé : si vous déclarez vous-même `azurerm_network_watcher` dans votre code Terraform **avant** de créer des ressources réseau, Azure utilise votre NetworkWatcher et **ne crée pas** `NetworkWatcherRG`.

**Ce que vous devez faire :**

1. Dans `main.tf`, créez un Resource Group `rg-bonus-shared` et un `azurerm_network_watcher` dans ce groupe.
2. Créez ensuite un VNet dans ce même RG.
3. Lancez `terraform apply` et vérifiez dans le portail Azure qu'aucun `NetworkWatcherRG` supplémentaire n'a été créé.

**Questions de réflexion :**
- Que se passe-t-il si `NetworkWatcherRG` existe déjà dans votre abonnement avant que vous déployiez votre code ?
- Comment importeriez-vous le NetworkWatcher existant dans votre state ?

{::nomarkdown}
<details><summary>Solution - Étape 2.2</summary>
{:/nomarkdown}

```hcl
resource "azurerm_resource_group" "shared" {
  name     = "rg-bonus-shared"
  location = "West Europe"
}

# En déclarant explicitement le NetworkWatcher, Azure n'en crée pas un second
# dans le RG automatique "NetworkWatcherRG".
resource "azurerm_network_watcher" "main" {
  name                = "nw-bonus-westeurope"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-bonus"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
}
```

Pour importer un NetworkWatcher déjà créé automatiquement par Azure :
```bash
terraform import azurerm_network_watcher.main \
  /subscriptions/<SUB_ID>/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/networkWatchers/NetworkWatcher_westeurope
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🗂️ Exercice 3 - Refactoriser sans détruire avec `moved`

### 🧩 Problème

En production, renommer une ressource Terraform (changer son label, la déplacer dans un module…) **détruirait et recréerait** la ressource réelle. Pour un serveur de base de données ou un réseau, c'est inacceptable. Le bloc `moved` permet de dire à Terraform : *"cette ressource n'a pas bougé dans Azure, c'est juste son adresse dans mon code qui a changé"*.

---

### 📝 Étape 3.1 - Situation initiale

Créez un dossier `tp-bonus-moved/` avec ce `main.tf` de départ :

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-bonus-moved"
  location = "West Europe"
}
```

Appliquez la config pour créer le Resource Group.

---

### 📝 Étape 3.2 - Renommer sans détruire

Vous décidez que le label `rg` n'est pas assez explicite et souhaitez le renommer en `main`. Normalement Terraform voudrait détruire `azurerm_resource_group.rg` et créer `azurerm_resource_group.main`.

**Ce que vous devez faire :**

1. Renommez le label dans `main.tf` : `resource "azurerm_resource_group" "main"`.
2. Ajoutez un bloc `moved` dans un fichier `moved.tf` pour indiquer la migration.
3. Lancez `terraform plan` et observez qu'aucune destruction n'est prévue.

> 💡 Un bloc `moved` indique juste une migration d'adresse dans le state. **Il ne crée, modifie ni détruit rien dans Azure.** Il peut être supprimé une fois que toute l'équipe a appliqué le plan de migration.

{::nomarkdown}
<details><summary>Solution - Étape 3.2</summary>
{:/nomarkdown}

`main.tf` après refactorisation :

```hcl
resource "azurerm_resource_group" "main" {
  name     = "rg-bonus-moved"
  location = "West Europe"
}
```

`moved.tf` :

```hcl
moved {
  from = azurerm_resource_group.rg
  to   = azurerm_resource_group.main
}
```

`terraform plan` doit afficher :
```
# azurerm_resource_group.rg has moved to azurerm_resource_group.main
  resource "azurerm_resource_group" "main" { ... }

Plan: 0 to add, 0 to change, 0 to destroy.
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 3.3 - Déplacer une ressource dans un module

Le bloc `moved` fonctionne aussi pour déplacer une ressource hors d'un module ou vers un module. Imaginez que vous souhaitez maintenant encapsuler le Resource Group dans un module `modules/rg`.

**Ce que vous devez faire :**

1. Créez `modules/rg/main.tf` avec la ressource `azurerm_resource_group`.
2. Remplacez la ressource directe dans `main.tf` par un appel de module.
3. Ajoutez un bloc `moved` de `azurerm_resource_group.main` vers `module.rg.azurerm_resource_group.main`.

{::nomarkdown}
<details><summary>Solution - Étape 3.3</summary>
{:/nomarkdown}

`moved.tf` :

```hcl
moved {
  from = azurerm_resource_group.main
  to   = module.rg.azurerm_resource_group.main
}
```

`main.tf` :

```hcl
module "rg" {
  source   = "./modules/rg"
  name     = "rg-bonus-moved"
  location = "West Europe"
}
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🗂️ Exercice 4 - Partage de state avec `terraform_remote_state`

### 🧩 Problème

Dans un vrai projet, l'infrastructure est souvent découpée en plusieurs stacks Terraform indépendantes : une équipe déploie le réseau, une autre déploie les VMs, une autre les bases de données. Comment l'équipe VM récupère-t-elle l'ID du subnet créé par l'équipe réseau **sans copier-coller des valeurs en dur** ?

La réponse : `terraform_remote_state`. Ce data source lit directement le fichier `.tfstate` d'un autre projet et expose ses `output`.

---

### 📝 Étape 4.1 - Stack réseau : déployer et exposer des outputs

Créez un dossier `tp-bonus-remote-state/network/`. C'est la stack "infrastructure réseau", gérée par une équipe dédiée.

**Ce que vous devez faire :**

1. Déployez un Resource Group, un VNet et deux subnets (`snet-app` et `snet-db`).
2. Exposez dans `outputs.tf` les IDs des deux subnets, l'ID du VNet et le nom du Resource Group.
3. Configurez un **backend distant** (Azure Blob Storage) pour ce projet — le state doit être accessible par d'autres projets.

> 💡 Un `output` n'est accessible via `terraform_remote_state` que s'il est déclaré dans `outputs.tf` de la stack source. Pensez à tout exposer dès maintenant.

{::nomarkdown}
<details><summary>Solution - Étape 4.1</summary>
{:/nomarkdown}

`network/outputs.tf` :

```hcl
output "vnet_id" {
  description = "ID du Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "subnet_app_id" {
  description = "ID du subnet applicatif"
  value       = azurerm_subnet.app.id
}

output "subnet_db_id" {
  description = "ID du subnet base de données"
  value       = azurerm_subnet.db.id
}

output "resource_group_name" {
  description = "Nom du Resource Group réseau"
  value       = azurerm_resource_group.network.name
}
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 4.2 - Stack applicative : consommer le state réseau

Créez un dossier `tp-bonus-remote-state/app/`. C'est la stack "application", qui a besoin du subnet créé par l'équipe réseau.

**Ce que vous devez faire :**

1. Déclarez un `data "terraform_remote_state"` pointant vers le backend de la stack réseau.
2. Utilisez `data.terraform_remote_state.network.outputs.subnet_app_id` pour associer une NIC ou un NSG au bon subnet — **sans dupliquer ni copier aucun ID en dur**.
3. Lancez `terraform plan` depuis `app/` et vérifiez que les IDs sont bien résolus.

> ⚠️ `terraform_remote_state` lit le state **au moment du plan/apply**. Si la stack réseau n'a pas encore été appliquée, le plan échouera. C'est un couplage fort entre stacks — comparez avec l'approche `data source` classique qui interroge Azure directement.

**Questions de réflexion :**
- Quelle est la différence entre `terraform_remote_state` et un `data "azurerm_subnet"` classique ?
- Qui contrôle ce qu'une stack expose à l'extérieur ?

{::nomarkdown}
<details><summary>Solution - Étape 4.2</summary>
{:/nomarkdown}

`app/main.tf` :

```hcl
data "terraform_remote_state" "network" {
  backend = "azurerm"

  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "stftstate..."
    container_name       = "tfstate"
    key                  = "bonus-network.tfstate"
  }
}

# Utilisation directe des outputs de la stack réseau
locals {
  subnet_app_id = data.terraform_remote_state.network.outputs.subnet_app_id
}

resource "azurerm_network_interface" "app" {
  name                = "nic-bonus-app"
  location            = "West Europe"
  resource_group_name = data.terraform_remote_state.network.outputs.resource_group_name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = local.subnet_app_id
    private_ip_address_allocation = "Dynamic"
  }
}
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🗂️ Exercice 5 - Protéger et contrôler le cycle de vie avec `lifecycle`

### 🧩 Problème

Par défaut, Terraform est libre de **détruire et recréer** n'importe quelle ressource quand une modification l'exige. En production, c'est inacceptable pour un serveur de base de données ou un réseau. Le bloc `lifecycle` permet de prendre le contrôle sur ce comportement ressource par ressource.

---

### 📝 Étape 5.1 - `prevent_destroy` : le filet de sécurité

Créez un dossier `tp-bonus-lifecycle/`. Déployez un PostgreSQL Flexible Server (vous pouvez réutiliser le code de l'exercice 1) et ajoutez `prevent_destroy = true` sur le serveur et sur son Resource Group.

**Ce que vous devez faire :**

1. Ajoutez un bloc `lifecycle { prevent_destroy = true }` sur `azurerm_postgresql_flexible_server` et sur `azurerm_resource_group`.
2. Tentez un `terraform destroy` et observez l'erreur.
3. Tentez de changer la `location` du Resource Group (ce qui forcerait une recreation) et observez le comportement au `plan`.

> 💡 `prevent_destroy` protège **uniquement contre les destructions explicites via Terraform**. Il ne protège pas contre une suppression manuelle depuis le portail Azure ou l'Azure CLI.

{::nomarkdown}
<details><summary>Solution - Étape 5.1</summary>
{:/nomarkdown}

```hcl
resource "azurerm_resource_group" "db" {
  name     = "rg-bonus-lifecycle"
  location = "West Europe"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "psql-bonus-lifecycle"
  resource_group_name    = azurerm_resource_group.db.name
  location               = azurerm_resource_group.db.location
  version                = "16"
  administrator_login    = "psqladmin"
  administrator_password = random_password.admin.result
  zone                   = "1"
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"

  lifecycle {
    prevent_destroy = true
  }
}
```

`terraform destroy` retourne :
```
Error: Instance cannot be destroyed
  on main.tf line X, in resource "azurerm_postgresql_flexible_server" "main":
  lifecycle {
    prevent_destroy = true
  }
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 5.2 - `ignore_changes` : survivre à la dérive

Dans beaucoup d'organisations, une **Azure Policy** applique automatiquement des tags sur toutes les ressources. Résultat : à chaque `terraform plan`, Terraform détecte une différence sur les tags et veut les écraser. Le cycle est sans fin.

`ignore_changes` permet d'indiquer à Terraform de ne jamais modifier certains attributs, même s'ils dérivent de la configuration.

**Ce que vous devez faire :**

1. Déployez un Resource Group **sans tags** dans votre `main.tf`.
2. Ajoutez manuellement un tag `managed-by = "azure-policy"` depuis le portail Azure (ou Azure CLI).
3. Lancez `terraform plan` et observez que Terraform veut supprimer ce tag.
4. Ajoutez `ignore_changes = [tags]` dans le bloc `lifecycle` du Resource Group.
5. Relancez `terraform plan` : la dérive sur les tags doit être ignorée.

{::nomarkdown}
<details><summary>Solution - Étape 5.2</summary>
{:/nomarkdown}

```hcl
resource "azurerm_resource_group" "app" {
  name     = "rg-bonus-lifecycle-app"
  location = "West Europe"

  tags = {
    environment = "bonus"
    owner       = "students"
  }

  lifecycle {
    # Azure Policy peut ajouter/modifier des tags automatiquement.
    # On dit à Terraform de ne jamais toucher aux tags après la création.
    ignore_changes = [tags]
  }
}
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 5.3 - `create_before_destroy` : zéro downtime

Pour certaines ressources (certificats, règles de sécurité), Terraform doit d'abord créer la nouvelle version avant de supprimer l'ancienne pour éviter une interruption de service.

**Ce que vous devez faire :**

1. Ajoutez un NSG avec une règle dans votre projet.
2. Activez `create_before_destroy = true` sur le NSG.
3. Modifiez le nom du NSG (ce qui force une recreation) et observez l'ordre des opérations dans le `plan` : `(+) create` apparaît avant `(-) destroy`.

{::nomarkdown}
<details><summary>Solution - Étape 5.3</summary>
{:/nomarkdown}

```hcl
resource "azurerm_network_security_group" "app" {
  name                = "nsg-bonus-app-v2"   # changement de nom = recreation
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name

  lifecycle {
    create_before_destroy = true
  }
}
```

`terraform plan` affichera :
```
# azurerm_network_security_group.app must be replaced
+/- resource "azurerm_network_security_group" "app" {
      # (create before destroy)
    }
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 💡 Pour aller encore plus loin

- Combinez `prevent_destroy = true` et `ignore_changes = [administrator_password]` sur votre serveur PostgreSQL pour simuler une gestion réaliste de prod : le mot de passe peut être changé hors de Terraform sans que celui-ci le réinitialise au prochain `apply`.
