---
title: "TP 4 - Modules et logiques avancées"
objective: "Factoriser la création des NSG dans un module local, puis maîtriser count, for_each et les dynamic blocks pour gérer des ressources dynamiques."
---

# 📦 Contexte

Le code des NSG du TP3 est fonctionnel mais répétitif : `dev/`, `staging/` et `prod/` contiennent quasiment la même logique. Vous allez **extraire cette logique dans un module local**, puis explorer les mécanismes avancés de Terraform pour créer des ressources dynamiquement à partir de structures de données.

---

## 🎯 Objectifs

<div class="section objective">

1. Créer un module local réutilisable pour les NSG avec un contrat d'interface clair
2. Appeler le module depuis les environnements dev et prod
3. Comprendre les limites de `count` face aux suppressions dans une liste
4. Maîtriser `for_each` comme alternative robuste à `count`
5. Utiliser les `dynamic` blocks pour générer les règles NSG depuis une structure de données

</div>

---

## 🗂️ Partie 4.1 — Créer et utiliser un module NSG

> **Point de départ :** le projet `tp3-nsg/` du TP précédent. Votre formateur introduira le concept de module Terraform avant cette partie.

---

### 📝 Étape 4.1.1 — Créer la structure du module

Un module Terraform est simplement un **répertoire contenant des fichiers `.tf`**. La convention est de les placer dans un sous-dossier `modules/`.

**Ce que vous devez faire :**

Créez la structure suivante à la racine du projet `tp3-nsg/` (que vous pouvez copier ou renommer en `tp4-nsg/`) :

```
tp4-nsg/
├── modules/
│   └── nsg/
│       ├── main.tf        ← ressources créées par le module
│       ├── variables.tf   ← contrat d'entrée (inputs)
│       ├── outputs.tf     ← contrat de sortie (outputs)
│       └── README.md      ← documentation du module
├── shared/                ← inchangé depuis TP3
├── dev/
│   ├── providers.tf
│   ├── main.tf            ← appellera le module
│   └── variables.tf
└── prod/
    ├── providers.tf
    ├── main.tf
    └── variables.tf
```

Avant d'écrire une seule ligne de code, réfléchissez au **contrat du module** :
- Quelles informations le module a-t-il **besoin** pour créer un NSG ? (inputs)
- Quelles informations doit-il **exposer** à l'appelant ? (outputs)

> 💡 Un bon module est comme une fonction : son interface (inputs/outputs) doit être stable et documentée. L'implémentation interne peut changer sans impacter les appelants.

**Questions de réflexion :**
- Quelle est la différence entre un module local et un module distant (Terraform Registry) ?
- Pourquoi le module ne doit-il **pas** contenir de bloc `provider` ?

{::nomarkdown}
<details><summary>Solution — Étape 4.1.1</summary>
{:/nomarkdown}

```bash
cp -r tp3-nsg tp4-nsg
mkdir -p tp4-nsg/modules/nsg
touch tp4-nsg/modules/nsg/{main.tf,variables.tf,outputs.tf,README.md}
```

**Contrat du module — réflexion préalable :**

| Input | Type | Description |
|---|---|---|
| `name` | `string` | Nom du NSG |
| `location` | `string` | Région Azure |
| `resource_group_name` | `string` | Resource Group cible |
| `subnet_id` | `string` | ID du subnet à associer |
| `security_rules` | `list(object)` | Règles de sécurité |
| `tags` | `map(string)` | Tags Azure |

| Output | Description |
|---|---|
| `nsg_id` | ID du NSG créé |
| `nsg_name` | Nom du NSG créé |

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 4.1.2 — Écrire le module

**Ce que vous devez faire :**

Dans `modules/nsg/variables.tf`, déclarez chaque input avec son type, sa description et une valeur par défaut si pertinent.

Dans `modules/nsg/main.tf`, écrivez les ressources `azurerm_network_security_group` et `azurerm_subnet_network_security_group_association`. Les règles de sécurité seront ajoutées plus tard (partie 4.2) — pour l'instant, créez le NSG **sans règles**.

Dans `modules/nsg/outputs.tf`, exposez l'`id` et le `name` du NSG.

Dans `modules/nsg/README.md`, documentez le module : description, inputs, outputs, exemple d'utilisation.

> 💡 Pour les types complexes comme `list(object(...))`, consultez la doc [Type Constraints](https://developer.hashicorp.com/terraform/language/expressions/type-constraints). La définition du type d'un objet dans une variable est un contrat fort.

{::nomarkdown}
<details><summary>Solution — Étape 4.1.2</summary>
{:/nomarkdown}

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

variable "security_rules" {
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
  description = "Liste des règles de sécurité du NSG"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags Azure à appliquer aux ressources"
  default     = {}
}
```

`modules/nsg/main.tf` (sans règles pour l'instant) :

```hcl
resource "azurerm_network_security_group" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.this.id
}
```

`modules/nsg/outputs.tf` :

```hcl
output "nsg_id" {
  description = "ID du Network Security Group créé"
  value       = azurerm_network_security_group.this.id
}

output "nsg_name" {
  description = "Nom du Network Security Group créé"
  value       = azurerm_network_security_group.this.name
}
```

`modules/nsg/README.md` :

```markdown
# Module NSG

Crée un Network Security Group Azure et l'associe à un subnet.

## Utilisation

    module "nsg_dev" {
      source              = "../modules/nsg"
      name                = "nsg-tp4-dev"
      location            = "West Europe"
      resource_group_name = "rg-tp4-dev"
      subnet_id           = data.azurerm_subnet.dev.id
      tags                = { environment = "dev" }
    }

## Inputs / Outputs

Voir variables.tf et outputs.tf.
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 4.1.3 — Appeler le module depuis dev et prod

**Ce que vous devez faire :**

Remplacez le code des ressources NSG dans `dev/main.tf` et `prod/main.tf` par des appels au module local. Un appel de module commence par le mot-clé `module` et référence le chemin local avec `source = "../modules/nsg"`.

Après la refactorisation :
1. Lancez `terraform init` dans chaque répertoire (nécessaire après l'ajout d'un module).
2. Lancez `terraform plan` — observez ce que Terraform prévoit. Est-ce attendu ?
3. Si nécessaire, utilisez `terraform state mv` pour éviter les destroy/recreate.

> 💡 L'adresse d'une ressource **à l'intérieur d'un module** dans le state suit le format `module.<nom_module>.<type>.<label>`.

**Questions de réflexion :**
- Pourquoi `terraform init` est-il nécessaire après l'ajout d'un module ?
- Comment accéder à un output du module depuis le `main.tf` appelant ?

{::nomarkdown}
<details><summary>Solution — Étape 4.1.3</summary>
{:/nomarkdown}

`dev/main.tf` (extrait) :

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
  tags                = { environment = "dev", project = "tp4" }
}

# Accès à un output du module
output "nsg_dev_id" {
  value = module.nsg_dev.nsg_id
}
```

`prod/main.tf` : identique en remplaçant les noms par les valeurs prod.

```bash
cd tp4-nsg/dev
terraform init   # nécessaire pour enregistrer le module
terraform plan
```

Si le plan prévoit de recréer les ressources déjà existantes (car les adresses dans le state ont changé), utilisez `state mv` :

```bash
# Avant : azurerm_network_security_group.nsg_dev
# Après : module.nsg_dev.azurerm_network_security_group.this
terraform state mv \
  azurerm_network_security_group.nsg_dev \
  module.nsg_dev.azurerm_network_security_group.this

terraform state mv \
  azurerm_subnet_network_security_group_association.dev \
  module.nsg_dev.azurerm_subnet_network_security_group_association.this
```

{::nomarkdown}
</details>
{:/nomarkdown}

---

## 🗂️ Partie 4.2 — Logiques avancées : count, for_each et dynamic blocks

> **Prérequis :** le module NSG fonctionne. Votre formateur présentera les meta-arguments avant cette partie.
>
> Dans cette partie, vous travaillez dans un **nouveau dossier `tp4-logic/`** indépendant, pour explorer les concepts sans impacter le projet NSG.

---

### 📝 Étape 4.2.1 — Définir une map de configuration NSG

Vous allez centraliser la configuration de plusieurs NSG dans une **variable de type `map`**.

**Ce que vous devez faire :**

Dans `tp4-logic/variables.tf`, déclarez une variable `nsg_configs` de type `map(object)` contenant la configuration de plusieurs NSG : au moins `dev`, `staging` et `prod`, chacun avec un nom, une liste de ports autorisés et un niveau d'accès.

Réfléchissez à la structure de l'objet avant de coder : quels attributs sont nécessaires pour différencier les NSG ?

> 💡 Une `map` en Terraform est une collection de valeurs indexées par une **clé string**. Elle se prête bien aux ressources similaires qu'on veut instancier plusieurs fois avec des paramètres différents.

{::nomarkdown}
<details><summary>Solution — Étape 4.2.1</summary>
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

### 📝 Étape 4.2.2 — Version 1 : `count` et ses limites

**Ce que vous devez faire :**

Dans `main.tf`, utilisez `count` pour créer autant de NSG qu'il y a d'entrées dans `var.nsg_configs`. Pour accéder aux clés et valeurs, utilisez les fonctions `keys()` et `values()`.

1. Appliquez la configuration. Observez les ressources créées (`terraform state list`).
2. **Expérience critique :** supprimez l'entrée `staging` de la map dans `variables.tf`.
3. Lancez `terraform plan`. Qu'observez-vous ? Combien de ressources vont être modifiées ou détruites ?
4. Notez le problème et réfléchissez à son origine avant de passer à la suite.

> 💡 `count` adresse les ressources par leur **index numérique** dans la liste. Que se passe-t-il quand l'index change ?

{::nomarkdown}
<details><summary>Solution — Étape 4.2.2</summary>
{:/nomarkdown}

`main.tf` — Version 1 avec `count` :

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

**Problème observé :** Terraform veut **modifier** `nsg[1]` (qui était `staging`, maintenant `prod`) et **détruire** `nsg[2]`. Il ne comprend pas qu'on a supprimé `staging` — il voit juste que les index ont changé.

Ce comportement est **dangereux en production** : supprimer un élément du milieu d'une liste entraîne la destruction/recréation de toutes les ressources suivantes.

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 4.2.3 — Version 2 : `for_each` comme solution

**Ce que vous devez faire :**

Remplacez le `count` par `for_each` en passant directement la `map` `var.nsg_configs`. 

1. Avant d'appliquer, utilisez `terraform state mv` pour migrer les ressources existantes vers leurs nouvelles adresses (de `nsg[0]` vers `nsg["dev"]`, etc.) afin d'éviter un destroy/recreate.
2. Appliquez et vérifiez que `terraform plan` affiche `No changes`.
3. **Même expérience :** supprimez à nouveau `staging` de la map.
4. Lancez `terraform plan`. Comparez le résultat avec la version `count`.

> 💡 Avec `for_each`, Terraform adresse chaque ressource par la **clé de la map** (`nsg["dev"]`, `nsg["staging"]`…). La suppression d'une clé n'affecte pas les autres.

{::nomarkdown}
<details><summary>Solution — Étape 4.2.3</summary>
{:/nomarkdown}

`main.tf` — Version 2 avec `for_each` :

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
# Seul nsg["staging"] est détruit — dev et prod ne sont pas touchés.
```

C'est le comportement attendu et sûr. `for_each` est **toujours préférable à `count`** pour des ressources différenciées par un identifiant métier.

{::nomarkdown}
</details>
{:/nomarkdown}

---

### 📝 Étape 4.2.4 — Version 3 : `dynamic` blocks pour les règles

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
<details><summary>Solution — Étape 4.2.4</summary>
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

### 📝 Étape 4.2.5 — Intégration : module + for_each + dynamic

**Ce que vous devez faire :**

Revenez dans `tp4-nsg/dev/` et appelez le module NSG en lui passant des règles générées dynamiquement depuis une variable locale. Le but est d'obtenir un code d'appel **aussi court que possible** tout en restant lisible.

Utilisez une expression `for` dans l'appel au module pour transformer la liste de ports en liste d'objets `security_rule` attendus par le module.

{::nomarkdown}
<details><summary>Solution — Étape 4.2.5</summary>
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

## ✅ Résultat attendu

<div class="section objective">

À la fin du TP 4 :

**Module NSG (`modules/nsg/`) :**
- Interface claire : variables typées et décrites, outputs documentés
- `README.md` avec exemple d'utilisation
- Règles gérées via `dynamic` block

**Projet `tp4-logic/` :**
- NSG créés via `for_each` sur une `map` — suppression d'une clé ne détruit que la ressource concernée
- Règles générées dynamiquement depuis une liste de ports via une expression `for`
- Vous pouvez expliquer **pourquoi `for_each` est préférable à `count`** pour des ressources identifiées métier

**Projet `tp4-nsg/` :**
- `dev/` et `prod/` n'ont plus de ressource NSG en dur — uniquement des appels `module`
- Les règles sont définies dans des `locals`, séparées de la logique d'appel

</div>

---

## 🧹 Nettoyage

{::nomarkdown}
<details><summary>Solution — Nettoyage</summary>
{:/nomarkdown}

```bash
# Projet tp4-logic
cd tp4-logic
terraform destroy

# Projet tp4-nsg — dans l'ordre
cd tp4-nsg/dev     && terraform destroy
cd ../prod         && terraform destroy
cd ../shared       && terraform destroy

# Bootstrap (Storage Account)
cd ../../tp3-bootstrap && terraform destroy
```

{::nomarkdown}
</details>
{:/nomarkdown}
