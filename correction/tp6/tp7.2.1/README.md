# TP6 - Diagnostic d'une dependance circulaire Terraform

Ce dossier contient un projet Terraform plus complet avec des ressources reseau Azure a faible cout:

- resource group
- virtual network
- subnet
- network security group
- route table
- associations subnet <-> NSG et subnet <-> route table

Le projet contient volontairement une dependance circulaire afin d'entrainer le diagnostic.

## Objectif pedagogique

1. Identifier quelles ressources participent au cycle
2. Expliquer pourquoi Terraform ne peut pas ordonnancer le graphe
3. Corriger le code en conservant l'intention fonctionnelle

## Lancer le scenario

```bash
terraform init
terraform plan
```

Resultat attendu: `terraform plan` echoue avec `Error: Cycle`.

## Guidage pour les etudiants

- Commencez par lire les references inter-ressources dans `main.tf`.
- Cherchez les dependances qui semblent "innocentes" (ex: tags) mais ajoutent des liens dans le graphe.
- Utilisez `terraform graph` si vous voulez visualiser le graphe de dependance.

## Exemple de correction possible

Conserver les memes ressources, mais casser le lien circulaire en retirant une des references croisees.
Par exemple, garder une reference NSG -> route table dans les tags, mais remplacer l'autre par une valeur statique.
