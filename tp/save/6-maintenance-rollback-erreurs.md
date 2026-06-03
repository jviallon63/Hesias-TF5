---
layout: tp
title: "TP 7 - Maintenance Terraform, rollback et diagnostic d'erreurs"
---

## 🎯 Objectifs

<div class="section objective">

1. Utiliser un rollback controlé avec `-target`, `-replace` et `taint`
2. Comprendre et corriger les erreurs Terraform frequentes

</div>

---

## 🗂️ Partie 7.1 - Rollback controle et maintenance corrective

---

### 📝 Etape 7.1.1 - Rollback partiel avec `-target`

`-target` permet de limiter temporairement l'operation a un sous-ensemble du graphe.

**Ce que vous devez faire :**

1. Provoquez un changement simple sur 2 ressources (ex: tag + nom d'une regle NSG).
2. Lancez un plan cible sur une seule ressource:

```bash
terraform plan -target="azurerm_virtual_network.vnet"
```

3. Appliquez ce plan cible.
4. Relancez un `terraform plan` complet et observez ce qu'il reste.

> ⚠️ `-target` est un outil de depannage, pas une strategie CI/CD permanente.

---

### 📝 Etape 7.1.2 - Forcer la recreation avec `-replace`

Quand une ressource est unhealthy, on peut forcer sa recreation de façon explicite.

**Ce que vous devez faire :**

1. Generez un plan avec recreation forcee:

```bash
terraform plan -replace="azurerm_virtual_network.vnet"
```

2. Appliquez le plan.
3. Verifiez dans le plan/outputs que seule la ressource ciblee a ete remplacee.

> 💡 En pratique moderne, `-replace` est prefere a `taint` pour son caractere explicite dans le plan.

---

### 📝 Etape 7.1.3 - Utiliser `taint` (legacy) pour conserver l'historique

Certaines equipes utilisent encore `terraform taint`.

**Ce que vous devez faire :**

1. Marquez une ressource comme "a recreer":

```bash
terraform taint azurerm_virtual_network.vnet
```

2. Lancez `terraform plan` puis `terraform apply`.
3. Si besoin, annulez avant apply avec:

```bash
terraform untaint azurerm_virtual_network.vnet
```

---

## 🗂️ Partie 7.2 - Laboratoire des erreurs Terraform frequentes

Dans cette partie, vous allez **reproduire** puis **corriger** les erreurs les plus fréquentes. Limitez-vous à `terraform plan` pour tester et valider la correction. Il n'est pas nécessaire de déployer l'infrastructure.

1. [Etude de case 7.2.1](tp7.2.1.zip)
2. [Etude de case 7.2.2](tp7.2.2.zip)
3. [Etude de case 7.2.3](tp7.2.3.zip)
4. [Etude de case 7.2.4](tp7.2.4.zip)
5. [Etude de case 7.2.5](tp7.2.5.zip)

<!--
{::nomarkdown}
<details><summary>Solution - Étape 7.2.1</summary>
{:/nomarkdown}

**7.2.1**

Le cycle ne vient pas forcement d'une ressource "principale", mais parfois de references croisees dans des attributs secondaires (ici des `tags`).

```hcl
resource "azurerm_network_security_group" "app" {
  # ...
  tags = merge(local.common_tags, {
    route_table_marker = azurerm_route_table.app.name
  })
}

resource "azurerm_route_table" "app" {
  # ...
  tags = merge(local.common_tags, {
    nsg_marker = azurerm_network_security_group.app.name
  })
}
```

`azurerm_network_security_group.app` depend de `azurerm_route_table.app` et `azurerm_route_table.app` depend de `azurerm_network_security_group.app`. Terraform ne peut pas ordonner la creation du graphe -> `Error: Cycle`

Comment corriger : Remplacer les références par une valeur stable (variable/local/chaine statique).

{::nomarkdown}
</details>
{:/nomarkdown}

{::nomarkdown}
<details><summary>Solution - Étape 7.2.2</summary>
{:/nomarkdown}

**7.2.2**

L'erreur `Invalid count argument` apparait quand Terraform ne peut pas calculer `count` au moment du plan.

Dans ce cas, `count` depend de `random_id.suffix.dec`, une valeur qui n'existe qu'apres la phase apply. La cardinalite d'une ressource (0, 1, n) doit toujours etre connue pendant le plan.

Exemple problematique :

```hcl
resource "random_id" "suffix" {
  byte_length = 2
}

resource "azurerm_storage_account" "sa" {
  count                    = random_id.suffix.dec > 0 ? 1 : 0
  name                     = "sttp7${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

Comment corriger : piloter `count` avec une entree connue au plan (variable, local statique, tfvars).

```hcl
variable "enable_storage" {
  description = "Active la creation du compte de stockage"
  type        = bool
  default     = true
}

resource "random_id" "suffix" {
  byte_length = 2
}

resource "azurerm_storage_account" "sa" {
  count                    = var.enable_storage ? 1 : 0
  name                     = "sttp7${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

Pourquoi cela fonctionne :

- `var.enable_storage` est connue des le plan.
- Terraform sait donc immediatement s'il doit creer 0 ou 1 instance.
- La valeur aleatoire peut toujours etre utilisee dans `name`, car elle n'influence plus la cardinalite.

Verification attendue :

```bash
terraform plan -var="enable_storage=true"
terraform plan -var="enable_storage=false"
```

Le premier plan propose la creation du storage account, le second n'en propose aucun, sans erreur de type `Invalid count argument`.

{::nomarkdown}
</details>
{:/nomarkdown}

{::nomarkdown}
<details><summary>Solution - Étape 7.2.4</summary>
{:/nomarkdown}

**7.2.4**

L'erreur `Reference to undeclared resource` apparait lorsqu'une reference pointe vers une ressource qui n'est pas definie dans la configuration courante.

Exemple problematique :

```hcl
resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.80.1.0/24"]
}

output "subnet_id" {
  value = azurerm_subnet.web.id
}
```

`azurerm_subnet.web` n'existe pas. Le seul label declare est `azurerm_subnet.app`.

Comment corriger : aligner toutes les references avec les labels reels (resource, output, locals, modules).

```hcl
output "subnet_id" {
  value = azurerm_subnet.app.id
}
```

Bonnes pratiques :

- Apres un renommage de ressource, rechercher toutes les references (`rg`, outputs, locals, modules).
- Lancer `terraform validate` apres chaque refacto pour detecter ce type d'erreur tot.

Verification attendue :

```bash
terraform validate
terraform plan
```

`validate` doit passer sans erreur, puis `plan` doit s'executer sans message `Reference to undeclared resource`.

{::nomarkdown}
</details>
{:/nomarkdown}

{::nomarkdown}
<details><summary>Solution - Étape 7.2.5</summary>
{:/nomarkdown}

**7.2.5**

L'erreur `Resource already exists` apparait quand Terraform tente de creer une ressource deja presente dans Azure mais absente du state local.

Dans ce cas de test:

- le groupe `NetworkWatcherRG` existe deja
- le network watcher par defaut existe deja, avec un nom du type `NetworkWatcher_<region>`

Exemple problematique :

```hcl
resource "azurerm_resource_group" "network_watcher" {
  name     = "NetworkWatcherRG"
  location = var.location
}

resource "azurerm_network_watcher" "default" {
  name                = "NetworkWatcher_westeurope"
  location            = var.location
  resource_group_name = azurerm_resource_group.network_watcher.name
}
```

Comment corriger :

1. Importer les ressources existantes dans le state Terraform.
2. Variabiliser la region du network watcher pour construire son nom de facon generique.

```hcl
variable "network_watcher_region" {
  type    = string
  default = "westeurope"
}

locals {
  network_watcher_name = "NetworkWatcher_${var.network_watcher_region}"
}

resource "azurerm_network_watcher" "default" {
  name                = local.network_watcher_name
  location            = var.network_watcher_region
  resource_group_name = azurerm_resource_group.network_watcher.name
}
```

Commandes d'import (a adapter):

```bash
terraform import azurerm_resource_group.network_watcher \
  "/subscriptions/<SUB_ID>/resourceGroups/NetworkWatcherRG"

terraform import azurerm_network_watcher.default \
  "/subscriptions/<SUB_ID>/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/networkWatchers/NetworkWatcher_<REGION>"
```

Verification attendue :

```bash
terraform plan
```

Le plan doit revenir propre (pas de creation forcee des ressources deja existantes).

{::nomarkdown}
</details>
{:/nomarkdown}
-->

---

### 📝 Etape 7.2.2 - Erreur `Invalid count argument`

#### 🧩 Scenario

`count` depend d'une valeur inconnue au moment du plan.

```hcl
resource "random_id" "suffix" {
  byte_length = 2
}

resource "azurerm_storage_account" "sa" {
  count                    = random_id.suffix.dec > 0 ? 1 : 0
  name                     = "sttp7${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

**Ce que vous devez faire :**

1. Identifiez pourquoi Terraform ne peut pas determiner `count` au plan.
2. Corrigez avec une condition basee sur une variable connue au plan (ex: `var.enable_storage`).
3. Relancez `terraform plan`.

---

### 📝 Etape 7.2.3 - Erreur `Provider configuration not present`

#### 🧩 Scenario

Un state contient des ressources creees avec un provider alias qui n'existe plus dans le code.

**Symptome typique :**

```text
Error: Provider configuration not present
To work with module.x.azurerm_resource_group.main its original provider configuration at
module.x.provider["registry.terraform.io/hashicorp/azurerm"].alias is required, but it has been removed.
```

**Ce que vous devez faire :**

1. Reintroduisez temporairement le provider alias manquant.
2. Lancez un `terraform state replace-provider` si vous migrez d'un alias vers un autre.
3. Replanifiez et supprimez l'ancien alias uniquement apres migration complete.

> 💡 Ce cas apparait souvent apres refacto de modules ou renommage d'alias provider.

---

### 📝 Etape 7.2.4 - Erreur `Reference to undeclared resource` (frequente)

#### 🧩 Scenario

On référence une ressource qui n'existe pas 


---

### 📝 Etape 7.2.5 - Erreur `Resource already exists` (frequente)

#### 🧩 Scenario

On tente de creer `NetworkWatcherRG` et le network watcher par defaut, mais ils existent deja dans Azure.

**Ce que vous devez faire :**

1. Importez le RG `NetworkWatcherRG` et le network watcher existant dans le state.
2. Variabilisez la region et utilisez-la en suffixe du nom: `NetworkWatcher_<region>`.
3. Verifiez que `terraform plan` ne propose plus de recreation de ces ressources.

---
