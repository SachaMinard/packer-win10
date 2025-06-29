# Makefile pour build Packer Windows 10 avec Jenkins CI/CD et Bitwarden
# Les secrets sont gérés par Jenkins et injectés via secrets.env

SHELL := /bin/bash
.PHONY: help check-secrets build-vars build clean init encode-secrets generate-secrets-plain

# Variables de sécurité
ENV_PASSWORD ?= $(error ENV_PASSWORD is required. Usage: make build ENV_PASSWORD=your_password)
SECRETS_FILE := scripts/secrets.env
TEMP_ENV := /tmp/.env.temp.$$$$
TEMP_VARS := /tmp/packer-vars.temp
PACKER_TEMPLATE := build/
PACKER_CACHE := .packer_cache

help: ## Affiche l'aide
	@echo "=== Packer Windows 10 Build ==="
	@echo "Usage:"
	@echo "  make init                                     - Initialise les plugins Packer (packer init)"
	@echo "  make build ENV_PASSWORD=your_password        - Lance le build complet"
	@echo "  make build-vars ENV_PASSWORD=your_password   - Génère les variables Packer depuis Bitwarden"
	@echo "  make clean                                    - Nettoie les fichiers temporaires"
	@echo "  make encode-secrets                            - Encode un fichier texte en base64"
	@echo ""
	@echo "Paramètres requis:"
	@echo "  ENV_PASSWORD    - Mot de passe de déchiffrement (fourni par Jenkins)"
	@echo ""
	@echo "Note: Les secrets Bitwarden sont générés par Jenkins dans scripts/secrets.env"

check-secrets: ## Vérifie que le fichier secrets.env existe
	@echo "=== Vérification du fichier secrets.env ==="
	@if [ ! -f "$(SECRETS_FILE)" ]; then \
		echo "ERREUR: Fichier secrets.env non trouvé: $(SECRETS_FILE)"; \
		echo "Le pipeline Jenkins doit générer ce fichier d'abord"; \
		exit 1; \
	fi
	@echo "✓ Fichier secrets.env trouvé: $(SECRETS_FILE)"
	@echo "Taille: $$(stat -c%s $(SECRETS_FILE)) bytes"

init: build/windows.pkr.hcl
	@echo "=== Initialisation des plugins Packer ==="
	packer init $(PACKER_TEMPLATE)

build-vars: $(SECRETS_FILE)
	@echo "=== Génération des variables Packer depuis Bitwarden ==="
	@# Vérifier que le fichier secrets.env existe
	@if [ ! -f "$(SECRETS_FILE)" ]; then \
		echo "ERREUR: Fichier secrets.env non trouvé: $(SECRETS_FILE)"; \
		echo "Le pipeline Jenkins doit générer ce fichier d'abord"; \
		exit 1; \
	fi
	@echo "✓ Fichier secrets.env trouvé: $(SECRETS_FILE)"
	@# Vérifier que bw existe et est accessible
	@if ! command -v bw >/dev/null 2>&1; then \
		echo "ERREUR: Bitwarden CLI non installé. Installez-le avec 'npm install -g @bitwarden/cli'"; \
		exit 1; \
	fi
	@echo "✓ Bitwarden CLI trouvé"
	@# Décoder secrets.env, récupérer secrets Bitwarden, générer variables Packer
	@if [ ! -f "$(TEMP_VARS)" ] || [ $(SECRETS_FILE) -nt $(TEMP_VARS) ]; then \
		pwsh -Command "try { \
			Write-Host '🔓 Décodage du fichier secrets.env...'; \
			\$$encodedContent = Get-Content '$(SECRETS_FILE)' -Raw; \
			\$$decodedBytes = [System.Convert]::FromBase64String(\$$encodedContent); \
			\$$plainContent = [System.Text.Encoding]::UTF8.GetString(\$$decodedBytes); \
			Write-Host 'DEBUG: Décodage terminé'; \
			\$$tempEnv = '$(TEMP_ENV)'; \
			Set-Content -Path \$$tempEnv -Value \$$plainContent -Encoding UTF8; \
			Write-Host 'DEBUG: Fichier temporaire créé'; \
			Write-Host 'Variables environnement chargées depuis secrets.env'; \
			Get-Content \$$tempEnv | ForEach-Object { \
				\$$line = \$$_.Trim(); \
				if (\$$line -and -not \$$line.StartsWith('#')) { \
					\$$parts = \$$line.Split('=', 2); \
					if (\$$parts.Length -eq 2) { \
						\$$key = \$$parts[0]; \
						\$$value = \$$parts[1] -replace '^\"|\"$$', ''; \
						[System.Environment]::SetEnvironmentVariable(\$$key, \$$value); \
					} \
				} \
			}; \
			Write-Host 'DEBUG: Variables environnement chargées'; \
			Write-Host '🔐 Vérification du statut Bitwarden...'; \
			\$$bwStatusJson = bw status --raw; \
			\$$bwStatusObj = \$$bwStatusJson | ConvertFrom-Json; \
			\$$bwStatus = \$$bwStatusObj.status; \
			Write-Host \"DEBUG: Statut Bitwarden: \$$bwStatus\"; \
			if (\$$bwStatus -eq 'unauthenticated') { \
				Write-Host '🔑 Connexion à Bitwarden...'; \
				\$$clientId = [System.Environment]::GetEnvironmentVariable('BW_CLIENTID'); \
				\$$clientSecret = [System.Environment]::GetEnvironmentVariable('BW_CLIENTSECRET'); \
				if (-not \$$clientId -or -not \$$clientSecret) { \
					throw 'Variables BW_CLIENTID et BW_CLIENTSECRET requises dans secrets.env'; \
				} \
				[System.Environment]::SetEnvironmentVariable('BW_CLIENTID', \$$clientId); \
				[System.Environment]::SetEnvironmentVariable('BW_CLIENTSECRET', \$$clientSecret); \
				\$$loginResult = bw login --apikey --raw; \
				if (\$$LASTEXITCODE -ne 0) { throw \"Échec de connexion Bitwarden: \$$loginResult\" }; \
				Write-Host '✓ Connexion Bitwarden réussie'; \
				Write-Host '🔓 Déverrouillage automatique du coffre...'; \
				\$$masterPassword = [System.Environment]::GetEnvironmentVariable('BW_PASSWORD'); \
				if (-not \$$masterPassword) { \
					throw 'Variable BW_PASSWORD requise pour le déverrouillage automatique'; \
				} \
				\$$unlockResult = bw unlock \$$masterPassword --raw; \
				if (\$$LASTEXITCODE -ne 0) { throw \"Échec de déverrouillage: \$$unlockResult\" }; \
				[System.Environment]::SetEnvironmentVariable('BW_SESSION', \$$unlockResult); \
				Write-Host '✓ Coffre Bitwarden déverrouillé automatiquement'; \
			} elseif (\$$bwStatus -eq 'locked') { \
				Write-Host '🔓 Déverrouillage du coffre Bitwarden...'; \
				\$$masterPassword = [System.Environment]::GetEnvironmentVariable('BW_PASSWORD'); \
				if (-not \$$masterPassword) { \
					throw 'Variable BW_PASSWORD requise pour le déverrouillage automatique'; \
				} \
				\$$unlockResult = bw unlock \$$masterPassword --raw; \
				if (\$$LASTEXITCODE -ne 0) { throw \"Échec de déverrouillage: \$$unlockResult\" }; \
				[System.Environment]::SetEnvironmentVariable('BW_SESSION', \$$unlockResult); \
				Write-Host '✓ Coffre Bitwarden déverrouillé'; \
			} elseif (\$$bwStatus -eq 'unlocked') { \
				Write-Host '✓ Bitwarden déjà déverrouillé'; \
			} else { \
				throw \"Statut Bitwarden inattendu: \$$bwStatus\"; \
			} \
			Write-Host '🔍 Récupération des secrets depuis Bitwarden...'; \
			\$$sessionKey = [System.Environment]::GetEnvironmentVariable('BW_SESSION'); \
			if (\$$sessionKey) { \
				\$$env:BW_SESSION = \$$sessionKey; \
			} \
			\$$allItems = bw list items | ConvertFrom-Json; \
			Write-Host \"DEBUG: \$$(\$$allItems.Count) items récupérés\"; \
			\$$vsphere = \$$allItems | Where-Object { \$$_.name -eq 'utapau.sta4ck.eu' }; \
			\$$network = \$$allItems | Where-Object { \$$_.name -eq 'network-config' }; \
			\$$ansible = \$$allItems | Where-Object { \$$_.name -eq 'ansible-config' }; \
			\$$vars = @{}; \
			\$$vars['PKR_VAR_vsphere_endpoint'] = (\$$vsphere.fields | Where-Object { \$$_.name -eq 'endpoint' }).value; \
			\$$vars['PKR_VAR_vsphere_username'] = \$$vsphere.login.username; \
			\$$vars['PKR_VAR_vsphere_password'] = \$$vsphere.login.password; \
			\$$vars['PKR_VAR_vsphere_datacenter'] = (\$$vsphere.fields | Where-Object { \$$_.name -eq 'datacenter' }).value; \
			\$$vars['PKR_VAR_vsphere_host'] = (\$$vsphere.fields | Where-Object { \$$_.name -eq 'host' }).value; \
			\$$vars['PKR_VAR_vsphere_datastore'] = (\$$vsphere.fields | Where-Object { \$$_.name -eq 'datastore' }).value; \
			\$$vars['PKR_VAR_vsphere_network'] = (\$$vsphere.fields | Where-Object { \$$_.name -eq 'network' }).value; \
			\$$vars['PKR_VAR_vsphere_folder'] = (\$$vsphere.fields | Where-Object { \$$_.name -eq 'folder' }).value; \
			\$$vars['PKR_VAR_build_username'] = (\$$vsphere.fields | Where-Object { \$$_.name -eq 'build_username' }).value; \
			\$$vars['PKR_VAR_build_password'] = (\$$vsphere.fields | Where-Object { \$$_.name -eq 'build_password' }).value; \
			\$$vars['PKR_VAR_common_iso_datastore'] = (\$$vsphere.fields | Where-Object { \$$_.name -eq 'iso_datastore' }).value; \
			if (\$$null -ne \$$network) { \
				\$$vars['PKR_VAR_vm_ip_address'] = (\$$network.fields | Where-Object { \$$_.name -eq 'vm_ip_address' }).value; \
				\$$vars['PKR_VAR_vm_ip_gateway'] = (\$$network.fields | Where-Object { \$$_.name -eq 'vm_ip_gateway' }).value; \
				\$$vars['PKR_VAR_vm_dns_primary'] = (\$$network.fields | Where-Object { \$$_.name -eq 'vm_dns_primary' }).value; \
				\$$vars['PKR_VAR_vm_dns_secondary'] = (\$$network.fields | Where-Object { \$$_.name -eq 'vm_dns_secondary' }).value; \
			} else { Write-Host 'Network config optional - DHCP will be used'; } \
			if (\$$null -ne \$$ansible) { \
				\$$vars['PKR_VAR_ansible_username'] = (\$$ansible.fields | Where-Object { \$$_.name -eq 'ansible_username' }).value; \
				\$$vars['PKR_VAR_ansible_key'] = (\$$ansible.fields | Where-Object { \$$_.name -eq 'ansible_key' }).value; \
			} else { Write-Host 'Ansible config optional - skipping'; } \
			Write-Host \"✓ \$$(\$$vars.Count) secrets récupérés depuis Bitwarden\"; \
			Write-Host '📝 Génération des variables Packer...'; \
			\$$newline = [Environment]::NewLine; \
			\$$varsArray = @(); \
			foreach (\$$key in \$$vars.Keys) { \
				if (\$$vars[\$$key]) { \
					\$$varsArray += \"\$$key='\$$(\$$vars[\$$key])'\"; \
				} \
			}; \
			\$$varsContent = \$$varsArray -join \$$newline; \
			\$$tempVars = '$(TEMP_VARS)'; \
			Set-Content -Path \$$tempVars -Value \$$varsContent -Encoding UTF8; \
			Remove-Item \$$tempEnv -Force -ErrorAction SilentlyContinue; \
			Write-Host \"✓ Variables Packer générées: \$$tempVars\"; \
		} catch { \
			Write-Host 'ERREUR détaillée PowerShell :'; \
			Write-Host \"Message : \$$(\$$_.Exception.Message)\"; \
			Write-Host \"StackTrace : \$$(\$$_.ScriptStackTrace)\"; \
			exit 1; \
		}"; \
	else \
		echo "✓ Variables Packer déjà à jour."; \
	fi

build: init build-vars
	@echo "=== Lancement du build Packer ==="
	@echo "🔨 Exécution de Packer build..."
	@# Charger les variables et lancer packer
	@set -a && source $(TEMP_VARS) && set +a && \
	packer build \
		-var-file="config/build.pkrvars.hcl" \
		-var-file="config/common.pkrvars.hcl" \
		-var-file="config/network.pkrvars.hcl" \
		-var-file="config/storage.pkrvars.hcl" \
		-var-file="config/vsphere.pkrvars.hcl" \
		-var-file="config/windows.pkrvars.hcl" \
		-var-file="config/ansible.pkrvars.hcl" \
		-color=true -on-error=ask -force \
		$(PACKER_TEMPLATE) && \
	rm -f $(TEMP_VARS)

clean: ## Nettoie tous les fichiers temporaires
	@echo "=== Nettoyage des fichiers temporaires ==="
	@rm -rf $(PACKER_CACHE) 2>/dev/null || true
	@rm -f /tmp/.env.temp.* /tmp/packer-vars.temp.* 2>/dev/null || true
	@echo "Nettoyage terminé"

encode-secrets-plain:
	@echo "Encodage du fichier scripts/secrets.env.plain en base64..."
	@base64 scripts/secrets.env.plain > scripts/secrets.env
	@echo "✓ Fichier scripts/secrets.env généré."

# Règle par défaut
.DEFAULT_GOAL := help 