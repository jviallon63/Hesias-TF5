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

## 🗂️ Partie 4.2 - Logiques avancées : count, for_each

> **Prérequis :** le module NSG fonctionne. Votre formateur présentera les meta-arguments avant cette partie.
>
> Dans cette partie, vous travaillez dans un **nouveau dossier `tp4-logic/`** indépendant, pour explorer les concepts sans impacter le projet NSG.

---

### 📝 Étape 4.2.1 - Définir une map de configuration NSG

Vous allez centraliser la configuration de plusieurs NSG dans une **variable de type `map`**.

**Ce que vous devez faire :**

Dans `tp4-logic/variables.tf`, déclarez une variable `nsg_configs` de type `map(object)` contenant la configuration de plusieurs NSG : au moins `dev`, `staging` et `prod`, chacun avec un nom, une liste de ports autorisés et un niveau d'accès.

Réfléchissez à la structure de l'objet avant de coder : quels attributs sont nécessaires pour différencier les NSG ?

> 💡 Une `map` en Terraform est une collection de valeurs indexées par une **clé string**. Elle se prête bien aux ressources similaires qu'on veut instancier plusieurs fois avec des paramètres différents.

{::nomarkdown}
<details><summary>Solution - Étape 4.2.1</summary>
{:/nomarkdown}

```bash
mkdir tp4-logic && cd tp4-logic
touch providers.tf variables.tf main.tf outputs.tf
```

`variables.tf` :

```hcl
variable "location" {
  type    = string
  default = "West Europe"
}

variable "resource_group_name" {
  type    = string
  default = "rg-tp4-logic"
}

variable "nsg_configs" {
  type = map(object({
    allowed_ports = list(string)
    environment   = string
  }))
  default = {
    dev = {
      allowed_ports = ["22", "3389", "8080"]
      environment   = "dev"
    }
    staging = {
      allowed_ports = ["22", "8080"]
      environment   = "staging"
    }
    prod = {
      allowed_ports = ["443"]
      environment   = "prod"
    }
  }
}
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 4.2.2 - Version 1 : `count` et ses limites

**Ce que vous devez faire :**

Dans `main.tf`, utilisez `count` pour créer autant de NSG qu'il y a d'entrées dans `var.nsg_configs`. Pour accéder aux clés et valeurs, utilisez les fonctions `keys()` et `values()`.

1. Appliquez la configuration. Observez les ressources créées (`terraform state list`).
2. **Expérience critique :** supprimez l'entrée `staging` de la map dans `variables.tf`.
3. Lancez `terraform plan`. Qu'observez-vous ? Combien de ressources vont être modifiées ou détruites ?
4. Notez le problème et réfléchissez à son origine avant de passer à la suite.

> 💡 `count` adresse les ressources par leur **index numérique** dans la liste. Que se passe-t-il quand l'index change ?

{::nomarkdown}
<details><summary>Solution - Étape 4.2.2</summary>
{:/nomarkdown}

`main.tf` - Version 1 avec `count` :

```hcl
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_network_security_group" "nsg" {
  count               = length(var.nsg_configs)
  name                = "nsg-tp4-${keys(var.nsg_configs)[count.index]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    environment = values(var.nsg_configs)[count.index].environment
  }
}
```

```bash
terraform init && terraform apply
terraform state list
# → azurerm_network_security_group.nsg[0]  (dev)
# → azurerm_network_security_group.nsg[1]  (staging)
# → azurerm_network_security_group.nsg[2]  (prod)
```

**Après suppression de `staging` de la map :**

```bash
terraform plan
```

**Problème observé :** Terraform veut **modifier** `nsg[1]` (qui était `staging`, maintenant `prod`) et **détruire** `nsg[2]`. Il ne comprend pas qu'on a supprimé `staging` - il voit juste que les index ont changé.

Ce comportement est **dangereux en production** : supprimer un élément du milieu d'une liste entraîne la destruction/recréation de toutes les ressources suivantes.

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 4.2.3 - Version 2 : `for_each` comme solution

**Ce que vous devez faire :**

Remplacez le `count` par `for_each` en passant directement la `map` `var.nsg_configs`. 

1. Avant d'appliquer, utilisez `terraform state mv` pour migrer les ressources existantes vers leurs nouvelles adresses (de `nsg[0]` vers `nsg["dev"]`, etc.) afin d'éviter un destroy/recreate.
2. Appliquez et vérifiez que `terraform plan` affiche `No changes`.
3. **Même expérience :** supprimez à nouveau `staging` de la map.
4. Lancez `terraform plan`. Comparez le résultat avec la version `count`.

> 💡 Avec `for_each`, Terraform adresse chaque ressource par la **clé de la map** (`nsg["dev"]`, `nsg["staging"]`…). La suppression d'une clé n'affecte pas les autres.

{::nomarkdown}
<details><summary>Solution - Étape 4.2.3</summary>
{:/nomarkdown}

`main.tf` - Version 2 avec `for_each` :

```hcl
resource "azurerm_network_security_group" "nsg" {
  for_each            = var.nsg_configs
  name                = "nsg-tp4-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    environment = each.value.environment
  }
}
```

Migration du state avant d'appliquer :

```bash
terraform state mv \
  'azurerm_network_security_group.nsg[0]' \
  'azurerm_network_security_group.nsg["dev"]'

terraform state mv \
  'azurerm_network_security_group.nsg[1]' \
  'azurerm_network_security_group.nsg["staging"]'

terraform state mv \
  'azurerm_network_security_group.nsg[2]' \
  'azurerm_network_security_group.nsg["prod"]'

terraform plan
# → No changes.
```

**Après suppression de `staging` :**

```bash
terraform plan
# → Plan: 0 to add, 0 to change, 1 to destroy.
# Seul nsg["staging"] est détruit - dev et prod ne sont pas touchés.
```

C'est le comportement attendu et sûr. `for_each` est **toujours préférable à `count`** pour des ressources différenciées par un identifiant métier.

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🗂️ Étape 4.3 - `dynamic` blocks pour les règles

Le module NSG créé en 4.1 ne gère pas encore les règles de sécurité. Vous allez les ajouter en utilisant un **`dynamic` block**, qui permet de générer un nombre variable de blocs imbriqués à partir d'une liste.

**Ce que vous devez faire :**

Dans `modules/nsg/main.tf`, ajoutez un bloc `dynamic "security_rule"` à l'intérieur de la ressource `azurerm_network_security_group`. Ce bloc doit itérer sur `var.security_rules` et créer une règle pour chaque élément.

Puis, dans `tp4-logic/main.tf`, générez dynamiquement les règles pour chaque NSG à partir de la map `var.nsg_configs` en utilisant les `allowed_ports` : chaque port doit devenir une règle `Allow Inbound`.

> 💡 La syntaxe d'un `dynamic` block :
> ```hcl
> dynamic "security_rule" {
>   for_each = var.security_rules
>   content {
>     name = security_rule.value.name
>     ...
>   }
> }
> ```
> L'itérateur par défaut porte le même nom que le bloc (`security_rule`). Vous pouvez le renommer avec `iterator = rule` pour plus de lisibilité.

**Questions de réflexion :**
- Quelle est la différence entre `for_each` sur une ressource et `for_each` dans un `dynamic` block ?
- Comment générer automatiquement une priorité unique pour chaque règle à partir de son index ?

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

Dans `tp4-logic/main.tf`, génération des règles à partir des ports avec une expression `for` :

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

```bash
terraform plan
terraform apply
```

Inspectez le résultat :

```bash
terraform state show 'azurerm_network_security_group.nsg["dev"]'
# → 3 règles : allow-22, allow-3389, allow-8080

terraform state show 'azurerm_network_security_group.nsg["prod"]'
# → 1 règle : allow-443
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 4.2.5 - Intégration : module + for_each + dynamic

**Ce que vous devez faire :**

Revenez dans `tp4-nsg/dev/` et appelez le module NSG en lui passant des règles générées dynamiquement depuis une variable locale. Le but est d'obtenir un code d'appel **aussi court que possible** tout en restant lisible.

Utilisez une expression `for` dans l'appel au module pour transformer la liste de ports en liste d'objets `security_rule` attendus par le module.

{::nomarkdown}
<details><summary>Solution - Étape 4.2.5</summary>
{:/nomarkdown}

`dev/main.tf` avec appel du module et génération des règles :

```hcl
locals {
  dev_ports = ["22", "3389", "8080"]

  dev_rules = [for idx, port in local.dev_ports : {
    name                       = "allow-${port}"
    priority                   = 100 + idx * 10
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = port
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }]
}

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
  security_rules      = local.dev_rules
  tags                = { environment = "dev", project = "tp4" }
}
```

```bash
terraform apply
terraform state show module.nsg_dev.azurerm_network_security_group.this
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🧹 Nettoyage

Détruisez dans l'ordre : environnements d'abord (ils dépendent du réseau partagé), puis le réseau, puis `rg-tfstate`.
