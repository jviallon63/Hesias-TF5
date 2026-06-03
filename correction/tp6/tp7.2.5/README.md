# TP6 - Diagnostic d'un Resource already exists

Ce dossier reproduit un cas frequent: on veut mettre sous controle Terraform des ressources Azure deja presentes par defaut.

Ressources ciblees:

- `NetworkWatcherRG`
- `NetworkWatcher_<region>`

## Objectif pedagogique

1. Comprendre pourquoi Terraform retourne `Resource already exists`
2. Importer des ressources existantes dans le state Terraform
3. Variabiliser la region et la reutiliser comme suffixe du nom du Network Watcher

## Lancer le scenario

```bash
terraform init
terraform plan
```

Resultat attendu: `terraform plan` echoue car les ressources existent deja dans Azure, mais pas dans le state.

## Indices de correction

- Le nom du network watcher par defaut suit le format `NetworkWatcher_<region>`.
- La region doit etre pilotable via `var.network_watcher_region`.
- Importer d'abord les ressources, puis replanifier.

## Exemple de commandes d'import

```bash
terraform import azurerm_resource_group.network_watcher \
  "/subscriptions/<SUB_ID>/resourceGroups/NetworkWatcherRG"

terraform import azurerm_network_watcher.default \
  "/subscriptions/<SUB_ID>/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/networkWatchers/NetworkWatcher_<REGION>"
```

## Verification attendue

```bash
terraform plan
```

Apres import et alignement de la region, le plan doit etre propre.
