---
layout: tp
title: "TP 4 - Modules et logiques avancées"
---

# 📦 Contexte

Le code des NSG du TP3 est fonctionnel mais répétitif : `staging/` et `prod/` contiennent quasiment la même logique. Et si l'équipe rajoute des nouveaux environnements la duplication du code ne va faire qu'augmenter. Vous allez **extraire cette logique dans un module local**. De la même façon les `security_rules` sont répétitives et manque de flexibilité, pour ajouter une régle vous devez dupliquer tout le bloc. A l'aide des mécanismes avancés de Terraform vous allez créer des ressources dynamiquement et facilement évolutives.

---

## 🎯 Objectifs

<div class="section objective">

1. Créer un module local réutilisable pour les NSG avec un contrat d'interface clair
2. Appeler le module depuis les environnements staging et prod
3. Comprendre les limites de `count` et surtout les cas d'usage adaptés
4. Maîtriser `for_each` comme alternative robuste à `count`
5. Utiliser les `dynamic` blocks pour générer les règles NSG depuis une structure de données

</div>

---

## 🗂️ Partie 4.1 - Créer et utiliser un module NSG

> **Point de départ :** le projet `tp3-nsg/` du TP précédent. Avec le backend remote et la structure du projet `shared/`, `staging/` et `prod/`

---

### 📝 Étape 4.1.1 - Créer le module

Un module Terraform est simplement un **répertoire contenant des fichiers `.tf`**. La convention est de les placer dans un sous-dossier `modules/`.

> ⚠️ Pour l'instant le module ne va pas gérer les `security_rules`, vous pouvez supprimer (ou commenter) les blocs dans les scripts Terraform.

Avant d'écrire une seule ligne de code, réfléchissez au **contrat du module** :
- Quelles informations le module a-t-il **besoin** pour créer un NSG ? (inputs)
- Quelles informations doit-il **exposer** à l'appelant ? (outputs)

> 💡 Un bon module est comme une fonction : son interface (inputs/outputs) doit être stable et documentée. L'implémentation interne peut changer sans impacter les appelants.

**Ce que vous devez faire :**

1. Créez la structure `shared/`, `staging/` et `prod/` dans un répertoire `tp4-nsg/` que vous pouvez copier `tp3-nsg/`.
2. Ajouter un répertoire `modules/nsg` vide pour l'instant.
3. Dans le nouveau module créez `variables.tf` avec la liste des inputs identifiés, n'oubliez pas les bonnes pratiques avec description et validation si pertinent.
4. Dans `modules/nsg/main.tf`, écrivez les ressources `azurerm_network_security_group` et `azurerm_subnet_network_security_group_association`. Les règles de sécurité seront ajoutées plus tard (partie 4.2) - pour l'instant, créez le NSG **sans règles**.
5. Créez `outputs.tf`pour exposer les informations utiles.
6. Générez votre **contrat du module** dans `README.md`.

{::nomarkdown}
<details><summary>Solution - Étape 4.1.1</summary>
{:/nomarkdown}

**Contrat du module - réflexion préalable :**

| Input | Type | Description |
|---|---|---|
| `name` | `string` | Nom du NSG |
| `location` | `string` | Région Azure |
| `resource_group_name` | `string` | Resource Group cible |
| `subnet_id` | `string` | ID du subnet à associer |

| Output | Description |
|---|---|
| `nsg_id` | ID du NSG créé |
| `nsg_name` | Nom du NSG créé |

`modules/nsg/variables.tf` :

```hcl
variable "name" {
  type        = string
  description = "Nom du Network Security Group"
}

variable "location" {
  type        = string
  description = "Région Azure"
}

variable "resource_group_name" {
  type        = string
  description = "Nom du Resource Group"
}

variable "subnet_id" {
  type        = string
  description = "ID du subnet auquel associer le NSG"
}
```

`modules/nsg/main.tf` (sans règles pour l'instant) :

```hcl
resource "azurerm_network_security_group" "main" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.main.id
}
```

`modules/nsg/outputs.tf` :

```hcl
output "nsg_id" {
  description = "ID du Network Security Group créé"
  value       = azurerm_network_security_group.main.id
}

output "nsg_name" {
  description = "Nom du Network Security Group créé"
  value       = azurerm_network_security_group.main.name
}
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 4.1.2 - Appeler le module depuis dev et prod

**Ce que vous devez faire :**

Remplacez le code des ressources NSG dans `staging/main.tf` et `prod/main.tf` par des appels au module local. Un appel de module commence par le mot-clé `module` et référence le chemin local avec `source = "../modules/nsg"`.

Après la refactorisation tester le cycle Terraform pour créer toutes les ressources à partir de `shared/`, `staging/` et `prod/`

> 💡 L'adresse d'une ressource **à l'intérieur d'un module** dans le state suit le format `module.<nom_module>.<type>.<label>`.

**Questions de réflexion :**
- Comment accéder à un output du module depuis le `main.tf` appelant ?

{::nomarkdown}
<details><summary>Solution - Étape 4.1.3</summary>
{:/nomarkdown}

`staging/main.tf` (extrait) :

```hcl
data "azurerm_subnet" "snet_dev" {
  name                 = "snet-dev"
  virtual_network_name = "vnet-tp3"
  resource_group_name  = "rg-tp3-shared"
}

module "nsg_dev" {
  source              = "../modules/nsg"
  name                = "nsg-tp4-dev"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = data.azurerm_subnet.snet_dev.id
}

# Accès à un output du module
output "nsg_dev_id" {
  value = module.nsg_dev.nsg_id
}
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🗂️ Étape 4.2 - `dynamic` blocks pour les règles

Le module NSG créé en 4.1 ne gère pas encore les règles de sécurité. Vous allez les ajouter en utilisant un **`dynamic` block**, qui permet de générer un nombre variable de blocs imbriqués à partir d'une liste.

**Ce que vous devez faire :**

Dans `modules/nsg/main.tf`, ajoutez un bloc `dynamic "security_rule"` à l'intérieur de la ressource `azurerm_network_security_group`. Ce bloc doit itérer sur `var.security_rules` et créer une règle pour chaque élément.

Puis, dans `tp4-nsg/staging/main.tf` et `tp4-nsg/prod/main.tf`, générez dynamiquement les règles pour chaque NSG à partir de la liste `var.nsg_configs` en utilisant les `allowed_ports` : chaque port doit devenir une règle `Allow Inbound`.

Template d'un `dynamic` block :

```hcl
dynamic "security_rule" {
  for_each = var.security_rules
  content {
    name = security_rule.value.name
    ...
  }
}
```

> L'itérateur par défaut porte le même nom que le bloc (`security_rule`). Vous pouvez le renommer avec `iterator = rule` pour plus de lisibilité.

**Questions de réflexion :**
- Comment générer automatiquement une priorité unique pour chaque règle à partir de son index ?
- Avec le module et le dynamic block vous pouvez facilement ajouter un environnement `dev`.

{::nomarkdown}
<details><summary>Solution - Étape 4.2.4</summary>
{:/nomarkdown}

Mise à jour de `modules/nsg/main.tf` avec le `dynamic` block :

```hcl
resource "azurerm_network_security_group" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = var.security_rules
    iterator = rule

    content {
      name                       = rule.value.name
      priority                   = rule.value.priority
      direction                  = rule.value.direction
      access                     = rule.value.access
      protocol                   = rule.value.protocol
      source_port_range          = rule.value.source_port_range
      destination_port_range     = rule.value.destination_port_range
      source_address_prefix      = rule.value.source_address_prefix
      destination_address_prefix = rule.value.destination_address_prefix
    }
  }
}
```

Dans `tp4-nsg/staging/main.tf`, génération des règles à partir des ports avec une expression `for` :

```hcl
resource "azurerm_network_security_group" "nsg" {
  for_each            = var.nsg_configs
  name                = "nsg-tp4-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = { environment = each.value.environment }

  dynamic "security_rule" {
    # Transforme la liste de ports en map indexée pour avoir une clé unique
    for_each = { for idx, port in each.value.allowed_ports : port => {
      priority = 100 + idx * 10
      port     = port
    }}
    iterator = rule

    content {
      name                       = "allow-${rule.key}"
      priority                   = rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = rule.key
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
    }
  }
}
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🗂️ Partie 4.3 - Logiques avancées : count, for_each

---

### 📝 Étape 4.3.1 - Création des subnets avec count

Avant de commencer, copiez `tp4-nsg/` dans un nouveau projet `tp4-nsg-count/`. Vous allez travailler sur le répertoire `shared/` pour créer les subnets de façon plus flexible, avec une ressource itérative et une liste d'objets définie en variable.

**Ce que vous devez faire :**

Le `shared/main.tf` actuel déclare deux ressources `azurerm_subnet` séparées pour `staging` et `prod`. Si l'équipe veut ajouter un environnement `dev`, il faut dupliquer un bloc entier.

1. Dans `shared/variables.tf`, déclarez une variable `subnets` de type `list(object)` avec les attributs `name` et `address_prefix`. Initialisez-la avec `snet-staging` et `snet-prod`.
2. Dans `shared/main.tf`, remplacez les deux blocs `azurerm_subnet` par une seule ressource utilisant `count`.
3. Appliquez. Vérifiez les adresses dans le state avec `terraform state list`.
4. Ajoutez `snet-dev` **en fin de liste** (adress_prefix = `10.0.3.0/24`) dans la variable et appliquez vos modification.

**Questions de réflexion :**
- Pourquoi il est préférable de gérer la liste des subnets en tant que `variables` plutôt qu'en `locals` ?
- Supprimé le subnet `staging`. Que ce passe t'il ? Pourquoi ? 

{::nomarkdown}
<details><summary>Solution - Étape 4.2.1</summary>
{:/nomarkdown}

`shared/variables.tf` :

```hcl
variable "subnets" {
  type = list(object({
    name           = string
    address_prefix = string
  }))
  default = [
    { name = "snet-staging", address_prefix = "10.0.1.0/24" },
    { name = "snet-prod",    address_prefix = "10.0.2.0/24" },
  ]
}
```

`shared/main.tf` :

```hcl
resource "azurerm_subnet" "snet" {
  count                = length(var.subnets)
  name                 = var.subnets[count.index].name
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnets[count.index].address_prefix]
}
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 4.3.2 - Création des subnets avec for_each

Avant de commencer, détruisez toutes les ressources créées précédement. Copiez `tp4-nsg/` dans un nouveau projet `tp4-nsg-for_each/`. Vous allez refaire le même exercice mais en remplaçant `count` par `for_each`.

**Ce que vous devez faire :**

1. Dans `shared/variables.tf`, déclarez une variable `subnets` de type `map(object)` avec `address_prefix` comme seul attribut. Le nom du subnet devient la **clé de la map**. Initialisez-la avec `snet-staging` et `snet-prod`.
2. Dans `shared/main.tf`, remplacez les deux blocs `azurerm_subnet` par une seule ressource utilisant `for_each`.
3. Appliquez. Vérifiez les adresses dans le state avec `terraform state list`.
4. Ajoutez `snet-dev` à la map (`address_prefix = "10.0.3.0/24"`) et appliquez. Observez le plan.

**Questions de réflexion :**
- Quelle est la différence entre les adresses dans le state (`snet[0]` vs `snet["snet-staging"]`) ?
- Pourquoi la suppression de `staging` ne provoque-t-elle pas de modification sur `prod` ?
- Quelle est la différence en `list` et `map` ?
- Dans quel cas `count` doit être utilisé ?

{::nomarkdown}
<details><summary>Solution - Étape 4.2.2</summary>
{:/nomarkdown}

`shared/variables.tf` :

```hcl
variable "subnets" {
  type = map(object({
    address_prefix = string
  }))
  default = {
    "snet-staging" = { address_prefix = "10.0.1.0/24" }
    "snet-prod"    = { address_prefix = "10.0.2.0/24" }
  }
}
```

`shared/main.tf` :

```hcl
resource "azurerm_subnet" "snet" {
  for_each             = var.subnets
  name                 = each.key
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [each.value.address_prefix]
}
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🧹 Nettoyage

Détruisez dans l'ordre : environnements d'abord (ils dépendent du réseau partagé), puis le réseau, puis `rg-tfstate`.
