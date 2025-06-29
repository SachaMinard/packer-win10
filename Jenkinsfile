@Library('shared') _
pipeline {
  agent {
    docker {
      image 'mcr.microsoft.com/powershell:latest'
      args '--privileged -v /var/run/docker.sock:/var/run/docker.sock'
    }
  }

  parameters {
    password(
      name: 'ENV_PASSWORD',
      defaultValue: '',
      description: 'Mot de passe de déchiffrement du fichier .env'
    )
    string(
      name: 'BW_EMAIL',
      defaultValue: 'sacha.minard@hotmail.fr',
      description: 'Email Bitwarden'
    )
    password(
      name: 'BW_PASSWORD',
      defaultValue: '',
      description: 'Mot de passe Bitwarden'
    )
    string(
      name: 'BW_CLIENT_ID',
      defaultValue: 'user.b121a4ab-a454-4351-821c-ac0500c3d229',
      description: 'Client ID Bitwarden'
    )
    password(
      name: 'BW_CLIENT_SECRET',
      defaultValue: '',
      description: 'Client Secret Bitwarden'
    )
    choice(
      name: 'PACKER_ACTION',
      choices: ['validate', 'build'],
      description: 'Action Packer à exécuter'
    )
    booleanParam(
      name: 'CLEAN_WORKSPACE',
      defaultValue: true,
      description: 'Nettoyer le workspace avant le build'
    )
    booleanParam(
      name: 'DEBUG_MODE',
      defaultValue: false,
      description: 'Activer le mode debug (affichage des variables)'
    )
  }

  environment {
    WORKSPACE_PATH = '/home/cloud/git/sta4ck-4.0'
    PACKER_PATH = '/home/cloud/git/sta4ck-4.0/packer/vsphere/windows/packer-win10'
    PACKER_LOG = '1'
    PACKER_LOG_PATH = 'packer.log'
  }

  stages {
    stage('🧹 Cleanup') {
      when {
        expression { params.CLEAN_WORKSPACE }
      }
      steps {
        script {
          echo "=== Nettoyage du workspace ==="
          sh '''
            rm -rf /tmp/packer-vars* || true
            rm -rf /tmp/.env.temp.* || true
            rm -f packer.log || true
          '''
        }
      }
    }
    
    stage('🔧 Setup Environment') {
      steps {
        script {
          echo "=== Configuration de l'environnement ==="
          
          // Installation des dépendances
          sh '''
            apt-get update -qq
            apt-get install -y curl wget unzip make git
            
            # Installation de Packer
            if ! command -v packer >/dev/null 2>&1; then
              echo "Installation de Packer..."
              wget -q https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_linux_amd64.zip
              unzip -q packer_1.9.4_linux_amd64.zip
              mv packer /usr/local/bin/
              rm packer_1.9.4_linux_amd64.zip
            fi
            
            # Installation de Bitwarden CLI
            if ! command -v bw >/dev/null 2>&1; then
              echo "Installation de Bitwarden CLI..."
              wget -q https://github.com/bitwarden/clients/releases/download/cli-v2024.2.0/bw-linux-2024.2.0.zip
              unzip -q bw-linux-2024.2.0.zip
              chmod +x bw
              mv bw /usr/local/bin/
              rm bw-linux-2024.2.0.zip
            fi
            
            # Vérification des versions
            echo "Versions installées:"
            packer --version
            bw --version
            pwsh --version
          '''
        }
      }
    }
    
    stage('📥 Checkout Code') {
      steps {
        script {
          echo "=== Récupération du code source ==="
          
          // Checkout du code depuis Git
          checkout scm
          
          // Affichage des informations du build
          sh '''
            echo "=== Informations du build ==="
            echo "Branch: ${GIT_BRANCH}"
            echo "Commit: ${GIT_COMMIT}"
            echo "Workspace: $(pwd)"
            ls -la
          '''
        }
      }
    }
    
    stage('🔐 Initialize STA4CK') {
      steps {
        script {
          echo "=== Initialisation STA4CK avec Bitwarden ==="
          
          // Validation des paramètres requis
          if (!params.ENV_PASSWORD) {
            error("ENV_PASSWORD est requis")
          }
          if (!params.BW_PASSWORD) {
            error("BW_PASSWORD est requis")
          }
          if (!params.BW_CLIENT_SECRET) {
            error("BW_CLIENT_SECRET est requis")
          }
          
          // Initialisation avec les credentials Bitwarden
          sh """
            cd ${env.WORKSPACE_PATH}
            pwsh -File ./init.ps1 \\
              -Email '${params.BW_EMAIL}' \\
              -Password '${params.BW_PASSWORD}' \\
              -ClientId '${params.BW_CLIENT_ID}' \\
              -ClientSecret '${params.BW_CLIENT_SECRET}' \\
              -EnvPassword '${params.ENV_PASSWORD}'
          """
        }
      }
    }
    
    stage('🔍 Validate Packer Template') {
      when {
        expression { params.PACKER_ACTION == 'validate' || params.PACKER_ACTION == 'build' }
      }
      steps {
        script {
          echo "=== Validation du template Packer ==="
          
          dir(env.PACKER_PATH) {
            sh """
              make init
              make build-vars ENV_PASSWORD='${params.ENV_PASSWORD}'
            """
            
            // Validation du template
            sh """
              set -a
              source /tmp/packer-vars-decrypted.env || true
              set +a
              
              packer validate \\
                -var-file="config/build.pkrvars.hcl" \\
                -var-file="config/common.pkrvars.hcl" \\
                -var-file="config/network.pkrvars.hcl" \\
                -var-file="config/storage.pkrvars.hcl" \\
                -var-file="config/vsphere.pkrvars.hcl" \\
                -var-file="config/windows.pkrvars.hcl" \\
                -var-file="config/ansible.pkrvars.hcl" \\
                build/
            """
          }
        }
      }
    }
    
    stage('🔨 Build Packer Image') {
      when {
        expression { params.PACKER_ACTION == 'build' }
      }
      steps {
        script {
          echo "=== Build de l'image Packer ==="
          
          dir(env.PACKER_PATH) {
            // Affichage des variables en mode debug
            if (params.DEBUG_MODE) {
              sh '''
                echo "=== Variables Packer (Debug) ==="
                if [ -f /tmp/packer-vars-decrypted.env ]; then
                  cat /tmp/packer-vars-decrypted.env
                else
                  echo "Fichier de variables non trouvé"
                fi
              '''
            }
            
            // Lancement du build
            timeout(time: 120, unit: 'MINUTES') {
              sh """
                make build ENV_PASSWORD='${params.ENV_PASSWORD}'
              """
            }
          }
        }
      }
    }
    
    stage('📊 Collect Artifacts') {
      when {
        expression { params.PACKER_ACTION == 'build' }
      }
      steps {
        script {
          echo "=== Collecte des artefacts ==="
          
          dir(env.PACKER_PATH) {
            // Archive des logs et manifests
            sh '''
              # Création du dossier d'artefacts
              mkdir -p artifacts
              
              # Copie des logs
              if [ -f packer.log ]; then
                cp packer.log artifacts/
              fi
              
              # Copie des manifests
              if [ -d manifests ]; then
                cp -r manifests artifacts/
              fi
              
              # Copie des exports OVF si présents
              if [ -d artifacts ]; then
                find artifacts -name "*.ovf" -o -name "*.vmdk" -o -name "*.mf" | head -10
              fi
              
              # Résumé du build
              echo "=== Résumé du build ===" > artifacts/build-summary.txt
              echo "Date: $(date)" >> artifacts/build-summary.txt
              echo "Branch: ${GIT_BRANCH}" >> artifacts/build-summary.txt
              echo "Commit: ${GIT_COMMIT}" >> artifacts/build-summary.txt
              echo "Build Number: ${BUILD_NUMBER}" >> artifacts/build-summary.txt
            '''
            
            // Archive des artefacts Jenkins
            archiveArtifacts artifacts: 'artifacts/**/*', allowEmptyArchive: true
            
            // Publication des logs
            if (fileExists('packer.log')) {
              publishHTML([
                allowMissing: false,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: '.',
                reportFiles: 'packer.log',
                reportName: 'Packer Build Log'
              ])
            }
          }
        }
      }
    }
  }
  
  post {
    always {
      script {
        echo "=== Nettoyage final ==="
        
        // Nettoyage des fichiers sensibles
        sh '''
          rm -f /tmp/packer-vars* || true
          rm -f /tmp/.env.temp.* || true
          rm -f /tmp/packer-vars-decrypted.env || true
        '''
        
        // Déconnexion Bitwarden
        sh 'bw logout || true'
      }
    }
    
    success {
      script {
        echo "🎉 Build réussi !"
        
        // Notification de succès (optionnel)
        if (params.PACKER_ACTION == 'build') {
          echo "✅ L'image Windows 10 a été créée avec succès"
          
          // Exemple de notification Slack (à adapter)
          /*
          slackSend(
            channel: '#builds',
            color: 'good',
            message: "✅ Build Packer Windows 10 réussi - Build #${BUILD_NUMBER}"
          )
          */
        }
      }
    }
    
    failure {
      script {
        echo "❌ Build échoué !"
        
        // Collecte des logs d'erreur
        sh '''
          echo "=== Logs d'erreur ===" > error-logs.txt
          if [ -f packer.log ]; then
            echo "--- Packer Log ---" >> error-logs.txt
            tail -50 packer.log >> error-logs.txt
          fi
          
          echo "--- System Info ---" >> error-logs.txt
          df -h >> error-logs.txt
          free -h >> error-logs.txt
        '''
        
        archiveArtifacts artifacts: 'error-logs.txt', allowEmptyArchive: true
        
        // Notification d'échec (optionnel)
        /*
        slackSend(
          channel: '#builds',
          color: 'danger',
          message: "❌ Build Packer Windows 10 échoué - Build #${BUILD_NUMBER}"
        )
        */
      }
    }
    
    unstable {
      script {
        echo "⚠️ Build instable"
      }
    }
    
    cleanup {
      script {
        echo "🧹 Nettoyage final du workspace"
        
        // Nettoyage complet si demandé
        if (params.CLEAN_WORKSPACE) {
          cleanWs()
        }
      }
    }
  }
}