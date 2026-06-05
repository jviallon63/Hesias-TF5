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

## 🗂️ Exercice 3 - Conditions ternaires et création conditionnelle

### 🧩 Problème

En environnement réel, on ne déploie pas toujours les mêmes options partout. Dans cet exercice, vous allez explorer deux usages complémentaires :

1. Conditionner la création d'une ressource avec `count`.
2. Conditionner la valeur d'un attribut avec un opérateur ternaire.

**Ce que vous devez faire :**

1. Vous allez créer 3 resources `azurerm_resource_group`, `azurerm_storage_account` et `azurerm_storage_container`. Le nom du container sera **app**.
2. Ajouter au moins une variable à votre projet : `environment` avec `dev` comme valeur par défaut.
3. Vous appliquer la bonne pratique terraform en tagguant `azurerm_resource_group` et `azurerm_storage_account` avec `managedBy` et `environment`
4. Vous ajoutez un tag `critical = false` à votre liste.
5. Assurez vous que le projet fonctionne avec `terraform plan`

**Ajouter les formes conditonnelles :**

1. Si l'environnement est `prod` vous allez créer un second `azurerm_storage_container` avec le nom **logs**. On n'utilise pas de liste ou map ici. Les blocs pour créer les container sont dupliqués.
2. Si l'environnement est `prod` le tag `critical` doit avoir pour valeur `true`
3. Ajoutez un output pour afficher le nom du container **logs**
4. Assurez vous que le projet fonctionne avec `terraform plan`. Vérifiez les ressources et attributs créés pour la dév
5. Faites de même avec `terraform plan -var="environment=prod"`

<!---
{::nomarkdown}
<details><summary>Solution - Étape 3.1</summary>
{:/nomarkdown}

`output.tf` :

```hcl
output "logs_container_name" {
  description = "Nom du container logs (null hors prod)"
  value       = var.environment == "prod" ? azurerm_storage_container.logs[0].name : null
}
```

`main.tf` :

```hcl
locals {
  tag = merge(
    {
      managed_by = "terraform"
      env        = var.environment
    },
    {
      critical = var.environment == "prod" ? "true" : "false"
    }
  )
}

...

resource "azurerm_storage_container" "logs" {
  count = var.environment == "prod" ? 1 : 0

  name                  = "logs"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}
```

{::nomarkdown}
</details>
{:/nomarkdown}
-->

---

## 🗂️ Exercice 4 - Protéger et contrôler le cycle de vie avec `lifecycle`

### 🧩 Problème

Par défaut, Terraform est libre de **détruire et recréer** n'importe quelle ressource quand une modification l'exige. En production, c'est inacceptable pour un serveur de base de données ou un réseau. Le bloc `lifecycle` permet de prendre le contrôle sur ce comportement ressource par ressource.

---

### 📝 Étape 4.1 - `prevent_destroy` : le filet de sécurité

Créez un nouveau projet qui déploie une base de données PostgreSQL Flexible Server et ajoutez `prevent_destroy = true` sur le serveur et sur son Resource Group. Utiliser le code [ici](lifecycle_prevent_destroy.zip)

**Ce que vous devez faire :**

1. Ajoutez un bloc `lifecycle { prevent_destroy = true }` sur `azurerm_postgresql_flexible_server` et sur `azurerm_resource_group`.
2. Tentez un `terraform destroy` et observez l'erreur.
3. Tentez de changer la `location` du Resource Group (ce qui forcerait une recreation) et observez le comportement au `plan`.
4. Supprimez `prevent_destroy` sur `azurerm_resource_group` et essayez d'appliquer la modification de la location

> 💡 `prevent_destroy` protège **uniquement contre les destructions explicites via Terraform**. Il ne protège pas contre une suppression manuelle depuis le portail Azure ou l'Azure CLI.

---

### 📝 Étape 4.2 - `ignore_changes` : survivre à la dérive

Dans beaucoup d'organisations, une **Azure Policy** applique automatiquement des tags sur toutes les ressources. Résultat : à chaque `terraform plan`, Terraform détecte une différence sur les tags et veut les écraser. Le cycle est sans fin.

`ignore_changes` permet d'indiquer à Terraform de ne jamais modifier certains attributs, même s'ils dérivent de la configuration.

**Ce que vous devez faire :**

1. Déployez un Resource Group **sans tags** dans votre `main.tf`.
2. Ajoutez manuellement un tag `managed-by = "azure-policy"` depuis le portail Azure.
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
