---
title: "TP 2 - Premier projet"
objective: "Objectif pédagogique"
---

TP 2 : Les Fondations et l'IAC (4h)

Objectif : Apprivoiser la syntaxe HCL et le cycle de vie de Terraform.
	Bootstrapping : Installation de Terraform et Azure CLI. Authentification via Service Principal.
	Monolithe Initial : Création d'un Resource Group, d'un VNET et d'un Subnet.
	Calcul & Stockage : Déploiement d'une VM Linux avec sa carte réseau et un disque managé.
	Variables & Outputs : Paramétrer les régions, les tailles de VM et ressortir l'IP publique.
	Le State : Observation du fichier terraform.tfstate.
	Renommer une ressource
		Exercice critique : Supprimer manuellement une ressource dans le portail Azure et voir comment terraform plan réagit.