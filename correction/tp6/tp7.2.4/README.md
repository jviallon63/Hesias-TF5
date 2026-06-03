# TP6 - Diagnostic d'une reference vers une ressource non declaree

Ce dossier contient un projet Terraform volontairement incorrect pour reproduire l'erreur:

- `Error: Reference to undeclared resource`

## Objectif pedagogique

1. Identifier une reference qui pointe vers un label de ressource inexistant
2. Reperer toutes les references impactees (resources, outputs, locals)
3. Corriger la configuration puis valider avec Terraform

## Lancer le scenario

```bash
terraform init
terraform validate
```

Resultat attendu: `terraform validate` echoue avec `Reference to undeclared resource`.

## Pourquoi ca casse

La ressource `azurerm_subnet` est declaree avec le label `app`, mais certaines references utilisent encore `azurerm_subnet.web`.

Exemples volontaires d'erreur:

- association NSG/subnet dans `main.tf`
- output subnet dans `outputs.tf`

## Piste de correction

Mettre a jour toutes les references pour utiliser `azurerm_subnet.app`.

## Verification attendue

```bash
terraform validate
terraform plan
```

Apres correction, `validate` ne doit plus remonter de `Reference to undeclared resource`.
