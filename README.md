# Template Packer pour Windows 10

Ce dossier contient les configurations nécessaires pour créer des images de machine virtuelle Windows 10 sur VMware vSphere à l'aide de HashiCorp Packer.

## Fonctionnalités

- Construction automatisée d'images Windows 10
- Configuration prête à l'emploi pour VMware vSphere
- Scripts de personnalisation pour l'installation et la configuration post-déploiement
- Support de différentes éditions de Windows 10 (Pro, Enterprise, Education)

## Prérequis

- HashiCorp Packer (>= 1.8.0)
- Accès à un serveur VMware vSphere
- ISO de Windows 10
- Fichier de réponse pour l'installation automatisée
- Docker (pour l'exécution des builds)
- Compte Bitwarden avec CLI configuré

## Structure du dossier

```
packer-win10/
├── build/                  # Templates Packer pour Windows 10
│   ├── variables.pkr.hcl   # Définitions des variables Packer
│   ├── windows.pkr.hcl     # Configuration principale de build
│   └── data/               # Données supplémentaires pour le build
├── config/                 # Fichiers de configuration
├── manifests/              # Manifestes de déploiement
├── scripts/                # Scripts de personnalisation
│   └── packer-config.ps1   # Script PowerShell de configuration
├── build.sh                # Script de lancement du build
├── build.yaml              # Configuration du menu de build
└── build.tmpl              # Template de build
```

## Configuration

Avant de lancer un build, vérifiez les fichiers de configuration dans le dossier `config/` :

1. `vsphere.pkrvars.hcl` - Configuration vSphere (serveur, datastore, réseau)
2. `windows.pkrvars.hcl` - Configuration spécifique à Windows 10
3. `network.pkrvars.hcl` - Configuration réseau
4. `storage.pkrvars.hcl` - Configuration du stockage
5. `common.pkrvars.hcl` - Variables communes à tous les builds

## Configuration initiale

### 1. Configuration des credentials Bitwarden

```bash
# Créer le fichier d'environnement
make setup-env

# Éditer .env avec vos vraies informations
nano .env
```

Le fichier `.env` doit contenir :
```bash
BW_EMAIL=votre.email@example.com
BW_PASSWORD=votre_mot_de_passe_principal
BW_CLIENT_ID=votre_client_id          # Optionnel (pour API Key)
BW_CLIENT_SECRET=votre_client_secret  # Optionnel (pour API Key)
```

### 2. Configuration automatique de Bitwarden

```bash
# Vérifier la configuration
make check-env

# Configurer Bitwarden et créer les éléments requis
make setup-bitwarden
```

Cette commande va :
- Se connecter automatiquement à Bitwarden avec vos credentials
- Créer 3 éléments dans votre coffre :
  - **Packer Network Configuration** : Configuration réseau
  - **vSphere vCenter Production** : Credentials et configuration vSphere
  - **Packer Build Account** : Compte utilisé pour les builds
- Sauvegarder les IDs des éléments dans `.bitwarden_ids`

### 3. Lancement des builds

```bash
# Build automatique (utilise .bitwarden_ids)
make build

# Ou spécifier manuellement les IDs
make build NETWORK_ITEM_ID=xxx VSPHERE_ITEM_ID=yyy BUILD_ITEM_ID=zzz
```

## Sécurité

- Le fichier `.env` contient vos credentials Bitwarden et **NE DOIT JAMAIS** être committé
- Les IDs Bitwarden dans `.bitwarden_ids` ne sont pas sensibles (ils référencent les éléments mais ne contiennent pas les données)
- Toutes les informations sensibles (mots de passe, configurations) sont stockées de manière chiffrée dans Bitwarden

## Workflow complet

```bash
# 1. Configuration initiale (une seule fois)
make setup-env
# Éditer .env avec vos vraies informations
make setup-bitwarden

# 2. Builds (répétables)
make build

# 3. Nettoyage si nécessaire
make clean
```

## Structure des éléments Bitwarden

### Network Configuration
- `gateway` : Passerelle réseau (ex: 192.168.1.1)
- `dns_primary` : DNS primaire (ex: 192.168.1.1)  
- `dns_secondary` : DNS secondaire (ex: 8.8.8.8)
- `iso_datastore` : Datastore pour les ISOs (ex: OS)

### vSphere vCenter Production
- `username/password` : Credentials vSphere
- `datacenter` : Nom du datacenter
- `host` : Hôte ESXi
- `datastore` : Datastore principal
- `network` : Réseau VM
- `folder` : Dossier des templates

### Packer Build Account
- `username/password` : Compte utilisé pendant le build Windows

## Dépannage

### Erreur d'authentification Bitwarden
```bash
# Vérifier le statut
bw status

# Se reconnecter manuellement si nécessaire
bw login votre.email@example.com
```

### Fichier .env manquant
```bash
make setup-env
# Puis éditer .env avec vos informations
```

### IDs Bitwarden perdus
```bash
# Relancer la configuration
make setup-bitwarden
```

## Lancement d'un build

Pour lancer un build, exécutez le script `build.sh` :

```bash
./build.sh
```

### Options disponibles

- Mode debug (pour le dépannage) :
  ```bash
  ./build.sh --debug
  ```

- Build automatique (sans menu interactif) :
  ```bash
  ./build.sh --auto=1
  ```

## Particularités de Windows 10

Cette configuration est optimisée pour les environnements d'entreprise et inclut :
- Désactivation de la télémétrie et des fonctionnalités de publicité
- Configuration des mises à jour Windows
- Installation des derniers correctifs de sécurité
- Optimisation des performances pour un environnement virtualisé

## Processus de build

Le processus de build suit les étapes suivantes :

1. Initialisation de Packer et des plugins nécessaires
2. Création d'une machine virtuelle sur vSphere
3. Installation automatisée de Windows 10
4. Exécution des scripts de personnalisation
5. Optimisation et nettoyage du système
6. Conversion en template vSphere

## Personnalisation

Pour personnaliser le build :

1. Modifiez les fichiers de variables dans `config/`
2. Ajoutez ou modifiez les scripts dans `scripts/`
3. Mettez à jour le template principal dans `build/windows.pkr.hcl`

## Résolution de problèmes

- Utilisez l'option `--debug` pour obtenir des logs détaillés
- Vérifiez les fichiers de logs dans le dossier `manifests/`
- Assurez-vous que les identifiants vSphere sont correctement configurés

## Licence

Copyright 2023-2024 Broadcom. All Rights Reserved.
SPDX-License-Identifier: BSD-2