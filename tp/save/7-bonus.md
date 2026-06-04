---
layout: tp
title: "TP Bonus - Aller plus loin avec Terraform"
---

# 🎉 Contexte

Vous avez fini les TP principaux ? Bravo. Ce TP bonus regroupe plusieurs **exercices indépendants** pour explorer des fonctionnalités de Terraform et du provider `azurerm` qui n'ont pas été abordées. Ils peuvent être réalisés dans n'importe quel ordre. Chaque exercice est autonome et peut être déposé dans un dossier dédié.

---

## 🗂️ Exercice 1 - Azure Key Vault avec create_kv et use_kv

### 🧩 Problème

Il est recommandé de stocker les secrets dans un coffre fort externe pour une meilleure sécurité. Dans ce TP vous allez créer 2 projets distinct : 

1. `create_kv`: crée le Key Vault, génère un mot de passe aléatoire, puis le stocke dans un secret.
2. `use_kv`: lit le Key Vault et le secret avec des data sources Azure, puis expose la valeur en output `sensitive`.

---

### 📝 Étape 1.1 - Créer le projet create_kv

**Ce que vous devez faire :**

1. Créez un dossier `create_kv/` avec la structure standard d'un projet terraform.
2. Déclarer les providers `azurerm` et `random`.
3. Vous allez générer un mot de passe avec `random_password`.
4. Créer les ressources Azure nécessaire pour le **key vault**
- Resource Group
- `azurerm_key_vault` qui créé la ressource Azure Key Vault
- `azurerm_key_vault_access_policy` pour authoriser votre compte à accéder aux vault. Utiliser une datasource pour récupérer l'id de votre compte personnel `azurerm_client_config`.
- `azurerm_key_vault_secret` qui stocke le mot de passe généré.

---

### 📝 Étape 1.2 - Créer le projet use_kv

Vous allez maintenant créer un second projet pour récupérer le secret stocké.

**Ce que vous devez faire :**

1. Créez un dossier `use_kv/` avec la structure standard d'un projet terraform.
2. Déclarer le provider `azurerm`.
3. Utiliser les datasource `azurerm_key_vault` et `azurerm_key_vault_secret` pour récupérer le secret
5. Exposer le secret avec `sensitive = true`.

---

## 🗂️ Exercice 2 - Refactoriser sans détruire avec `moved`

### 🧩 Problème

En production, renommer une ressource Terraform (changer son label, la déplacer dans un module…) **détruirait et recréerait** la ressource réelle. Pour un serveur de base de données ou un réseau, c'est inacceptable. Le bloc `moved` permet de dire à Terraform : *"cette ressource n'a pas bougé dans Azure, c'est juste son adresse dans mon code qui a changé"*.

---

### 📝 Étape 2.1 - Situation initiale

Créez un nouveau projet terraform avec uniquement un `main.tf` qui créé un ressource groupe nommé `rg`

Appliquez la config pour créer le Resource Group.

---

### 📝 Étape 2.2 - Renommer sans détruire

Vous décidez que le label `rg` n'est pas assez explicite et souhaitez le renommer en `main.tf`. Normalement Terraform voudrait détruire `azurerm_resource_group.rg` et créer `azurerm_resource_group.main`.

**Ce que vous devez faire :**

1. Renommez votre ressource groupe dans `main.tf`
2. Ajoutez un bloc `moved` pour indiquer la migration.
3. Validez avec `terraform plan`

> 💡 Un bloc `moved` indique juste une migration d'adresse dans le state. **Il ne crée, modifie ni détruit rien dans Azure.** Il peut être supprimé une fois que toute l'équipe a appliqué le plan de migration.

<!---
{::nomarkdown}
<details><summary>Solution - Étape 2.2</summary>
{:/nomarkdown}

```hcl
resource "azurerm_resource_group" "main" {
  name     = "rg-bonus-moved"
  location = "westeurope"
}

moved {
  from = azurerm_resource_group.rg
  to   = azurerm_resource_group.main
}
```

{::nomarkdown}
</details>
{:/nomarkdown}
-->

---

### 📝 Étape 2.3 - Déplacer une ressource dans un module

Le bloc `moved` fonctionne aussi pour déplacer une ressource hors d'un module ou vers un module. Imaginez que vous souhaitez maintenant encapsuler le Resource Group dans un module `modules/rg`.

**Ce que vous devez faire :**

1. Créez `modules/rg/main.tf` avec la ressource `azurerm_resource_group`.
2. Remplacez la ressource directe dans `main.tf` par un appel de module.
3. Ajoutez un bloc `moved` pour déplacer le ressource groupe local au projet dans votre module.

<!---
{::nomarkdown}
<details><summary>Solution - Étape 2.3</summary>
{:/nomarkdown}

`main.tf` :

```hcl
module "rg" {
  source   = "./modules/rg"
}

moved {
  from = azurerm_resource_group.main
  to   = module.rg.azurerm_resource_group.main
}
```


`modules/rg/main.tf` :

```hcl
resource "azurerm_resource_group" "main" {
  name     = "rg-bonus-moved"
  location = "westeurope"

  tags = {
    environment = "demo"
    managed_by  = "terraform"
  }
}
```

{::nomarkdown}
</details>
{:/nomarkdown}
-->

---

## 🗂️ Exercice 4 - Conditions ternaires et création conditionnelle

### 🧩 Problème

En environnement réel, on ne déploie pas toujours les mêmes ressources partout. Par exemple, on veut un Bastion en production mais pas en dev, ou une SKU différente selon l'environnement. Vous allez utiliser l'opérateur ternaire de Terraform (`condition ? valeur_si_vrai : valeur_si_faux`) pour piloter ce comportement.

---

### 📝 Étape 4.1 - Utiliser un ternaire pour adapter la configuration

Créez un dossier `tp-bonus-conditions/` avec `providers.tf`, `variables.tf`, `main.tf`.

**Ce que vous devez faire :**

1. Déclarez une variable `environment` (`dev`, `staging`, `prod`).
2. Créez un Resource Group.
3. Créez une IP publique avec une SKU calculée par ternaire : `Standard` en `prod`, `Basic` sinon.
4. Ajoutez un tag `critical = "yes"` en prod et `critical = "no"` sinon, via ternaire.

> 💡 Le ternaire est une expression : il peut être utilisé dans n'importe quel attribut Terraform (`name`, `sku`, `tags`, `locals`, etc.).

<!---
{::nomarkdown}
<details><summary>Solution - Étape 4.1</summary>
{:/nomarkdown}

`variables.tf` :

```hcl
variable "environment" {
  type        = string
  description = "Environnement cible (dev, staging, prod)"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment doit être dev, staging ou prod."
  }
}
```

`main.tf` :

```hcl
resource "azurerm_resource_group" "main" {
  name     = "rg-bonus-${var.environment}"
  location = "West Europe"
}

resource "azurerm_public_ip" "main" {
  name                = "pip-bonus-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = var.environment == "prod" ? "Standard" : "Basic"

  tags = {
    environment = var.environment
    critical    = var.environment == "prod" ? "yes" : "no"
  }
}
```

{::nomarkdown}
</details>
{:/nomarkdown}
-->

---

### 📝 Étape 4.2 - Créer une ressource uniquement si condition vraie (if/else)

Dans le même projet, ajoutez une variable booléenne `enable_bastion` et créez un Bastion Host uniquement si elle vaut `true`.

**Ce que vous devez faire :**

1. Déclarez `enable_bastion` (bool) avec `false` par défaut.
2. Créez une ressource `azurerm_subnet` nommée `AzureBastionSubnet` seulement si `enable_bastion = true`.
3. Créez la ressource `azurerm_bastion_host` avec le même principe.
4. Utilisez un output ternaire pour afficher un message clair selon que le Bastion est créé ou non.

> ⚠️ Terraform n'a pas de bloc `if {}` autour des ressources. Le "if/else" se fait via `count` (0/1) ou `for_each` conditionnel.

**Questions de réflexion :**
- Pourquoi `count = var.enable_bastion ? 1 : 0` est-il une forme de if/else ?
- Quelle différence entre conditionner une ressource (avec `count`) et conditionner un attribut (avec un ternaire) ?

<!---
{::nomarkdown}
<details><summary>Solution - Étape 4.2</summary>
{:/nomarkdown}

`variables.tf` (ajout) :

```hcl
variable "enable_bastion" {
  type        = bool
  description = "Active ou non le déploiement du Bastion"
  default     = false
}
```

`main.tf` (extrait) :

```hcl
resource "azurerm_virtual_network" "main" {
  name                = "vnet-bonus-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.20.0.0/16"]
}

resource "azurerm_subnet" "bastion" {
  count                = var.enable_bastion ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_bastion_host" "main" {
  count               = var.enable_bastion ? 1 : 0
  name                = "bas-bonus-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.main.id
  }
}
```

`outputs.tf` :

```hcl
output "bastion_status" {
  description = "Etat du bastion"
  value       = var.enable_bastion ? "Bastion deploye" : "Bastion non deploye"
}
```

{::nomarkdown}
</details>
{:/nomarkdown}
-->

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

<!---
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
-->

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

<!---
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
-->

---

### 📝 Étape 5.3 - `create_before_destroy` : zéro downtime

Pour certaines ressources (certificats, règles de sécurité), Terraform doit d'abord créer la nouvelle version avant de supprimer l'ancienne pour éviter une interruption de service.

**Ce que vous devez faire :**

1. Ajoutez un NSG avec une règle dans votre projet.
2. Activez `create_before_destroy = true` sur le NSG.
3. Modifiez le nom du NSG (ce qui force une recreation) et observez l'ordre des opérations dans le `plan` : `(+) create` apparaît avant `(-) destroy`.

<!---
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
-->
---
