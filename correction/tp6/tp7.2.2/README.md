# TP6 - Diagnostic d'un Invalid count argument (niveau intermediaire)

Ce dossier contient un projet Terraform un peu plus realiste (reseau + stockage + verrouillage) avec une erreur volontaire:

- `Error: Invalid count argument`

## Ce que contient le scenario

- resource group
- virtual network + subnet
- network security group + association subnet
- storage account
- management lock sur le storage account

## Objectif pedagogique

1. Comprendre qu'une cardinalite (`count`) doit etre connue au moment du plan
2. Reperer les attributs calcules par le provider Azure (connus seulement apres apply)
3. Corriger en separant la decision de creation (variable connue au plan) des attributs runtime

## Lancer le scenario

```bash
terraform init
terraform plan
```

Resultat attendu: `terraform plan` echoue avec `Error: Invalid count argument`.

## Pourquoi ca casse

Dans `main.tf`, le `count` de `azurerm_management_lock.storage_delete_protection` depend de:

```hcl
azurerm_storage_account.logs.primary_blob_endpoint
```

Cet attribut est calcule par Azure pendant la creation. Au moment du plan, Terraform ne peut pas savoir sa valeur exacte, donc ne peut pas determiner si `count` vaut 0 ou 1.

## Guidage de correction

1. Conserver le storage account tel quel.
2. Piloter `count` avec une valeur deterministe au plan (ex: `var.enable_storage_lock ? 1 : 0`).
3. Garder les attributs calcules (endpoint, id, etc.) dans les arguments normaux des ressources, pas dans `count`.

Exemple de direction de fix:

```hcl
count = var.enable_storage_lock ? 1 : 0
```
