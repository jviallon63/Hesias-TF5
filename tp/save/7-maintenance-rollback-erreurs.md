---
layout: tp
title: "TP 7 - Maintenance Terraform, rollback et diagnostic d'erreurs"
---

# 🧰 Contexte

Maintenir une infrastructure Terraform en production ne consiste pas seulement a faire `terraform apply`. Il faut savoir:
- diagnostiquer une derive entre le code, le state et le cloud,
- faire un rollback controle sans casser le reste,
- corriger rapidement les erreurs Terraform les plus frequentes.

Dans ce TP, vous allez pratiquer des situations reelles d'exploitation et de support.

---

## 🎯 Objectifs

<div class="section objective">

1. Mettre en place une routine de maintenance Terraform (state, drift, verification)
2. Utiliser un rollback controle avec `-target`, `-replace` et `taint`
3. Comprendre et corriger les erreurs Terraform frequentes:
4. `Cycle: ...`
5. `Invalid count argument`
6. `Provider configuration not present`
7. et d'autres erreurs courantes de runbook

</div>

---

## 🗂️ Partie 7.1 - Routine de maintenance Terraform

> **Point de depart :** prenez un petit projet existant (par exemple `tp5-terraform/terraform`) ou creez un dossier `tp7-maintenance/`.

---

### 📝 Etape 7.1.1 - Verifier l'etat reel et le state

Avant toute action de correction, on valide la coherence entre:
- l'etat Terraform (state),
- le code HCL,
- l'etat reel Azure.

**Ce que vous devez faire :**

1. Lancez `terraform init` puis `terraform validate`.
2. Listez les ressources du state avec `terraform state list`.
3. Inspectez une ressource avec `terraform state show <adresse_ressource>`.
4. Lancez un plan de verification uniquement: `terraform plan -refresh-only`.

> 💡 `-refresh-only` est tres utile en maintenance: il met a jour la vision Terraform sans proposer de changement infra depuis le code.

---

### 📝 Etape 7.1.2 - Detecter une derive (drift)

Vous simulez un changement manuel dans Azure (ex: tag ajoute dans le portail).

**Ce que vous devez faire :**

1. Modifiez une propriete d'une ressource directement depuis Azure Portal ou CLI.
2. Relancez `terraform plan`.
3. Identifiez ce que Terraform veut corriger.
4. Decidez si la derive doit etre:
   - corrigee par Terraform,
   - ignoree via `lifecycle.ignore_changes`,
   - ou importee/integree proprement.

**Question de reflexion :**
- Pourquoi ignorer une derive sans la documenter peut devenir dangereux en production ?

---

## 🗂️ Partie 7.2 - Rollback controle et maintenance corrective

---

### 📝 Etape 7.2.1 - Rollback partiel avec `-target`

`-target` permet de limiter temporairement l'operation a un sous-ensemble du graphe.

**Ce que vous devez faire :**

1. Provoquez un changement simple sur 2 ressources (ex: tag + nom d'une regle NSG).
2. Lancez un plan cible sur une seule ressource:

```bash
terraform plan -target="azurerm_network_security_group.main"
```

3. Appliquez ce plan cible.
4. Relancez un `terraform plan` complet et observez ce qu'il reste.

> ⚠️ `-target` est un outil de depannage, pas une strategie CI/CD permanente.

---

### 📝 Etape 7.2.2 - Forcer la recreation avec `-replace`

Quand une ressource est unhealthy, on peut forcer sa recreation de facon explicite.

**Ce que vous devez faire :**

1. Generez un plan avec recreation forcee:

```bash
terraform plan -replace="azurerm_public_ip.main"
```

2. Appliquez le plan.
3. Verifiez dans le plan/outputs que seule la ressource ciblee a ete remplacee.

> 💡 En pratique moderne, `-replace` est prefere a `taint` pour son caractere explicite dans le plan.

---

### 📝 Etape 7.2.3 - Utiliser `taint` (legacy) pour comprendre l'historique

Certaines equipes utilisent encore `terraform taint`.

**Ce que vous devez faire :**

1. Marquez une ressource comme "a recreer":

```bash
terraform taint azurerm_network_interface.main
```

2. Lancez `terraform plan` puis `terraform apply`.
3. Si besoin, annulez avant apply avec:

```bash
terraform untaint azurerm_network_interface.main
```

**Question de reflexion :**
- Pourquoi `taint` est moins lisible dans un workflow d'equipe qu'un `-replace` porte directement dans la commande de plan ?

---

## 🗂️ Partie 7.3 - Laboratoire des erreurs Terraform frequentes

Dans cette partie, vous allez **reproduire** puis **corriger** les erreurs les plus frequentes.

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

### 📝 Etape 7.3.5 - Erreur `Error acquiring the state lock` (frequente)

#### 🧩 Scenario

Deux executions Terraform concurrentes tentent d'acceder au meme state distant.

**Ce que vous devez faire :**

1. Identifiez l'execution concurrente (CI, collegue, terminal local).
2. Attendez la fin si un run est legitime.
3. En dernier recours seulement, utilisez:

```bash
terraform force-unlock <LOCK_ID>
```

> ⚠️ `force-unlock` sans verification peut corrompre le workflow equipe.

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

## 🗂️ Partie 7.4 - Runbook d'equipe (synthese)

Creez un `README.md` de runbook avec vos procedures standard:

1. Verification avant action: `fmt`, `validate`, `plan -refresh-only`
2. Rollback partiel: usage encadre de `-target`
3. Recreation ciblee: `-replace` (prioritaire) vs `taint` (legacy)
4. Gestion des incidents state: lock, import, replace-provider
5. Regles de securite equipe: jamais de `apply` sans plan relu

---

### ✅ Critere de reussite du TP

Le TP est valide si vous etes capable de:

1. Expliquer la difference entre maintenance, correction de derive et rollback.
2. Justifier quand utiliser `-target`, `-replace`, `taint`.
3. Diagnostiquer et corriger les erreurs suivantes sans aide externe:
4. `Cycle`
5. `Invalid count argument`
6. `Provider configuration not present`
7. plus au moins 2 erreurs frequentes (state lock, undeclared resource, import requis).

---

### 💡 Pour aller plus loin

- Ajoutez une pipeline CI qui execute automatiquement:
  - `terraform fmt -check -recursive`
  - `terraform validate`
  - `terraform plan -detailed-exitcode`
- Ajoutez des tests de politique (ex: `tflint`, `tfsec`, OPA/Sentinel selon votre contexte).
- Introduisez des modules avec alias providers puis testez une migration complete de provider via `state replace-provider`.
