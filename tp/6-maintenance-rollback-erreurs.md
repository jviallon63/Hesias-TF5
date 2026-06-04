---
layout: tp
title: "TP 6 - Maintenance Terraform, rollback et diagnostic d'erreurs"
---

## 🎯 Objectifs

<div class="section objective">

1. Utiliser un rollback controlé avec `-target`, `-replace` et `taint`
2. Comprendre et corriger les erreurs Terraform frequentes

</div>

---

## 🗂️ Partie 6.1 - Rollback controle et maintenance corrective

---

### 📝 Etape 6.1.1 - Rollback partiel avec `-target`

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

### 📝 Etape 6.1.2 - Forcer la recreation avec `-replace`

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

### 📝 Etape 6.1.3 - Utiliser `taint` (legacy) pour conserver l'historique

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

## 🗂️ Partie 6.2 - Laboratoire des erreurs Terraform frequentes

Dans cette partie, vous allez **reproduire** puis **corriger** les erreurs les plus fréquentes. Limitez-vous à `terraform plan` pour tester et valider la correction. Il n'est pas nécessaire de déployer l'infrastructure.

1. [Etude de case 6.2.1](tp6.2.1.zip)
2. [Etude de case 6.2.2](tp6.2.2.zip)
3. [Etude de case 6.2.3](tp6.2.3.zip)
4. [Etude de case 6.2.4](tp6.2.4.zip) - Allez jusqu'à l'apply pour ce cas de test
5. [Etude de case 6.2.5](tp6.2.5.zip)
6. [Etude de case 6.2.6](tp6.2.6.zip)

<!--
{::nomarkdown}
<details><summary>Solution - Étape 6.2.1</summary>
{:/nomarkdown}


> Error: Cycle: <ressource 1>, <ressource 2>

Il existe une references croisees entre ressource 1 et ressource 2. Ici dans des attributs secondaires : `tags`.

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
<details><summary>Solution - Étape 6.2.2</summary>
{:/nomarkdown}

L'erreur `Invalid count argument` apparait quand Terraform ne peut pas calculer `count` au moment du plan.

Dans ce cas, `count` depend de `var.enable_storage_lock` qui vaut "true" par défaut, la variable est initialisé donc elle existe. Count dépende en plus de `azurerm_storage_account.logs.primary_blob_endpoint`, `primary_blob_endpoint` est un attribut exporté automatiquement aprés la création du storage_account. Au moment du plan l'attribut n'existe pas et ne peux pas être utilisé dans le count.

```hcl
resource "azurerm_management_lock" "storage_delete_protection" {
  count = var.enable_storage_lock && azurerm_storage_account.logs.primary_blob_endpoint != "" ? 1 : 0

  ...
}
```

Pour corriger il faut piloter `count` avec des entrées connue au plan (variable, local statique, tfvars, attribut configurée d'une autre ressource).

```hcl
resource "azurerm_management_lock" "storage_delete_protection" {
  count = var.enable_storage_lock ? 1 : 0

  ...
}
```

{::nomarkdown}
</details>
{:/nomarkdown}

{::nomarkdown}
<details><summary>Solution - Étape 6.2.3</summary>
{:/nomarkdown}

L'erreur `Reference to undeclared resource` apparait lorsqu'une reference pointe vers une ressource qui n'est pas definie dans la configuration courante. Le problème ici c'est que la ressource `azurerm_subnet_network_security_group_association` essaye de mapper un attribut du subnet **web**. Dans l'exemple c'est le subnet **app** qui existe. De la même manière le problème existe dans la déclaration des outputs

```hcl
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

output "subnet_id" {
  value = azurerm_subnet.app.id
}
```

{::nomarkdown}
</details>
{:/nomarkdown}

{::nomarkdown}
<details><summary>Solution - Étape 6.2.4</summary>
{:/nomarkdown}

L'erreur `Resource already exists` apparait quand Terraform tente de creer une ressource deja presente dans Azure mais absente du state local.

Dans ce cas de test:

- le groupe `NetworkWatcherRG` existe deja
- le network watcher par defaut existe deja, avec un nom du type `NetworkWatcher_<region>`

Comment corriger :

1. Importer les ressources existantes dans le state Terraform.
2. Variabiliser la region du network watcher pour construire son nom de facon generique.

{::nomarkdown}
</details>
{:/nomarkdown}

{::nomarkdown}
<details><summary>Solution - Étape 6.2.5</summary>
{:/nomarkdown}

L'erreur `Invalid for_each argument` apparait quand `for_each` depend d'une valeur inconnue au moment du plan.

Dans ce cas, l'association NSG->NIC est pilotee avec les IDs des NIC. Or ces IDs sont calcules apres creation, donc Terraform ne peut pas determiner les cles de `for_each` pendant `terraform plan`.

Exemple problematique :

```hcl
resource "azurerm_network_interface_security_group_association" "app" {
  for_each = toset(azurerm_network_interface.app[*].id)

  network_interface_id      = each.value
  network_security_group_id = azurerm_network_security_group.app.id
}
```

Comment corriger :

1. Piloter la cardinalite avec une valeur connue au plan (`var.nic_count`).
2. Garder les IDs calcules uniquement dans les attributs de la ressource.

```hcl
resource "azurerm_network_interface_security_group_association" "app" {
  count = var.nic_count

  network_interface_id      = azurerm_network_interface.app[count.index].id
  network_security_group_id = azurerm_network_security_group.app.id
}
```

Autre solution : remplace count par for_each partout. Dans ce cas vous devez remplacer la variable de type number `nic_count` par une variable de type List ou Map `nic_list` pour avoir les nic nommées explicitement

{::nomarkdown}
</details>
{:/nomarkdown}

{::nomarkdown}
<details><summary>Solution - Étape 6.2.6</summary>
{:/nomarkdown}

L'erreur `Unsupported argument` apparait lorsqu'on passe un argument a un module qui ne le declare pas dans ses variables d'entree.

Dans ce cas, l'appel du module `network` fournit `enable_ddos = true`, mais cette variable n'existe pas dans `modules/network/variables.tf`.

Comment corriger :

1. Soit supprimer l'argument `enable_ddos` de l'appel de module s'il n'est pas utile.
2. Soit declarer une variable `enable_ddos` dans `modules/network/variables.tf` et l'utiliser dans le module si c'est un vrai besoin fonctionnel.

{::nomarkdown}
</details>
{:/nomarkdown}
-->