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

## 🗂️ Partie 7.2 - Rollback controle et maintenance corrective

---

### 📝 Etape 7.2.1 - Rollback partiel avec `-target`

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

### 📝 Etape 7.2.2 - Forcer la recreation avec `-replace`

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

### 📝 Etape 7.2.3 - Utiliser `taint` (legacy) pour conserver l'historique

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

## 🗂️ Partie 7.3 - Laboratoire des erreurs Terraform frequentes

Dans cette partie, vous allez **reproduire** puis **corriger** les erreurs les plus fréquentes. Limitez-vous à `terraform plan` pour tester et valider la correction. Il n'est pas nécessaire de déployer l'infrastructure.

1. [Etude de case 7.3.1](tp7.3.1.zip)
2. [Etude de case 7.3.2](tp7.3.2.zip)
3. [Etude de case 7.3.3](tp7.3.3.zip)
4. [Etude de case 7.3.4](tp7.3.4.zip)
5. [Etude de case 7.3.5](tp7.3.5.zip)

<!---
{::nomarkdown}
<details><summary>Solution - Étape 7.3</summary>
{:/nomarkdown}

**7.3.1**

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
-->
---

### 📝 Etape 7.3.1 - Erreur `Cycle: ...`

#### 🧩 Scenario

Vous creez une dependance circulaire entre 2 ressources.

```hcl
resource "azurerm_resource_group" "a" {
  name     = "rg-a"
  location = azurerm_resource_group.b.location
}

resource "azurerm_resource_group" "b" {
  name     = "rg-b"
  location = azurerm_resource_group.a.location
}
```

**Ce que vous devez faire :**

1. Lancez `terraform plan` et observez l'erreur `Cycle`.
2. Cassez la boucle en introduisant une valeur source stable (variable, local, data source).
3. Revalidez avec `terraform plan`.

---

### 📝 Etape 7.3.2 - Erreur `Invalid count argument`

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

### 📝 Etape 7.3.3 - Erreur `Provider configuration not present`

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

### 📝 Etape 7.3.4 - Erreur `Reference to undeclared resource` (frequente)

#### 🧩 Scenario

Vous renommez une ressource mais oubliez de mettre a jour toutes les references.

**Ce que vous devez faire :**

1. Provoquez l'erreur en changeant le label d'une ressource.
2. Corrigez toutes les references (`resource`, `output`, `module`, `locals`).
3. Verifiez avec `terraform validate`.

---

### 📝 Etape 7.3.6 - Erreur `Resource already exists` (frequente)

#### 🧩 Scenario

La ressource existe dans Azure mais pas dans le state Terraform.

**Ce que vous devez faire :**

1. Importez la ressource existante:

```bash
terraform import azurerm_resource_group.main /subscriptions/<SUB_ID>/resourceGroups/<RG_NAME>
```

2. Alignez le code HCL avec l'etat reel.
3. Verifiez que `terraform plan` revient propre (0 a ajouter/0 a detruire attendu).

---
