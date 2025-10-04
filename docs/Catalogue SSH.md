Je vais chercher dans la documentation du projet pour trouver les noms des scripts atomiques SSH.Voici les **noms des scripts atomiques pour SSH** :

## Scripts SSH disponibles

1. **`list-ssh.keys.sh`**
   - Liste les clés SSH d'un utilisateur (clés publiques, privées, authorized_keys)

2. **`generate-ssh.keypair.sh`**
   - Génère une paire de clés SSH (RSA/ED25519)

3. **`add-ssh.key.authorized.sh`**
   - Ajoute une clé publique aux authorized_keys pour autoriser une connexion

4. **`remove-ssh.key.authorized.sh`**
   - Retire une clé des authorized_keys (révocation d'accès)

5. **`check-ssh.connection.sh`**
   - Teste la connexion SSH vers un hôte (diagnostic)

Ces 5 scripts atomiques couvrent les opérations principales pour la gestion SSH : génération de clés, autorisation/révocation d'accès, listing et diagnostic de connexion.

Je vais chercher dans la documentation les scripts de niveau supérieur qui utilisent les scripts SSH atomiques.Avec les 5 scripts atomiques SSH, vous pouvez créer plusieurs **scripts de niveau 1** (orchestrateurs) :

## Scripts de Niveau 1 possibles avec SSH

### 1. **`setup-ssh.access.sh`** (Niveau 1)
**Description** : Configure l'accès SSH complet pour un utilisateur
**Compose** :
- `generate-ssh.keypair.sh` - Génère la paire de clés
- `add-ssh.key.authorized.sh` - Ajoute la clé aux authorized_keys
- `check-ssh.connection.sh` - Vérifie que la connexion fonctionne

### 2. **`revoke-ssh.access.sh`** (Niveau 1)
**Description** : Révoque complètement l'accès SSH d'un utilisateur
**Compose** :
- `list-ssh.keys.sh` - Liste les clés de l'utilisateur
- `remove-ssh.key.authorized.sh` - Retire la/les clé(s)
- `check-ssh.connection.sh` - Vérifie que l'accès est bien coupé

### 3. **`audit-ssh.keys.sh`** (Niveau 1)
**Description** : Audit complet des clés SSH du système
**Compose** :
- `list-ssh.keys.sh` - Liste toutes les clés par utilisateur
- `check-ssh.connection.sh` - Teste chaque connexion

### 4. **`migrate-ssh.user.sh`** (Niveau 1)
**Description** : Migre les clés SSH d'un serveur à un autre
**Compose** :
- `list-ssh.keys.sh` - Récupère les clés source
- `add-ssh.key.authorized.sh` - Ajoute sur le serveur cible
- `check-ssh.connection.sh` - Valide la migration

### atomics/execute-ssh.remote.sh    (Niveau 1 )

### 5. **`rotate-ssh.keys.sh`** (Niveau 1)
**Description** : Rotation des clés SSH (sécurité)
**Compose** :
- `generate-ssh.keypair.sh` - Génère nouvelles clés
- `add-ssh.key.authorized.sh` - Ajoute nouvelles clés
- `remove-ssh.key.authorized.sh` - Supprime anciennes clés
- `check-ssh.connection.sh` - Valide le fonctionnement

### 6. **`deploy-ssh.multiserver.sh`** (Niveau 1)
**Description** : Déploie une clé SSH sur plusieurs serveurs
**Compose** :
- `generate-ssh.keypair.sh` - Génère la clé une fois
- `add-ssh.key.authorized.sh` - (appelé N fois pour N serveurs)
- `check-ssh.connection.sh` - (appelé N fois pour validation)

## Exemple d'architecture

```
orchestrators/level-1/setup-ssh.access.sh
│
├─ atomics/generate-ssh.keypair.sh
├─ atomics/add-ssh.key.authorized.sh  
└─ atomics/check-ssh.connection.sh
```

Ces orchestrateurs de **niveau 1** combinent les scripts atomiques pour réaliser des tâches métier complètes autour de SSH.

Je vais chercher des exemples de scripts de niveau 2 qui pourraient utiliser les orchestrateurs SSH de niveau 1.Avec les orchestrateurs SSH de **niveau 1**, vous pouvez créer des **scripts de niveau 2** encore plus complexes :

## Scripts de Niveau 2 possibles

### 1. **`provision-server.complete.sh`** (Niveau 2)
**Description** : Provisionnement complet d'un nouveau serveur
**Compose** :
- `setup-ssh.access.sh` (niveau 1) - Configure l'accès SSH admin
- `deploy-ssh.multiserver.sh` (niveau 1) - Déploie clés sur serveurs de backup
- Autres orchestrateurs niveau 1 (réseau, firewall, services...)

### 2. **`migrate-infrastructure.sh`** (Niveau 2)
**Description** : Migration complète d'infrastructure vers nouveaux serveurs
**Compose** :
- `audit-ssh.keys.sh` (niveau 1) - Audit des clés existantes
- `migrate-ssh.user.sh` (niveau 1) - Migration des clés (× N utilisateurs)
- `setup-ssh.access.sh` (niveau 1) - Setup accès sur nouveaux serveurs
- Autres orchestrateurs pour données, configs, services...

### 3. **`security-audit.full.sh`** (Niveau 2)
**Description** : Audit de sécurité complet du parc serveurs
**Compose** :
- `audit-ssh.keys.sh` (niveau 1) - Audit SSH par serveur
- `rotate-ssh.keys.sh` (niveau 1) - Rotation des clés compromises
- `revoke-ssh.access.sh` (niveau 1) - Révocation accès obsolètes
- Autres orchestrateurs (firewall, logs, permissions...)

### 4. **`deploy-cluster.kubernetes.sh`** (Niveau 2)
**Description** : Déploiement cluster Kubernetes multi-nœuds
**Compose** :
- `setup-ssh.access.sh` (niveau 1) - Accès SSH sur chaque nœud
- `deploy-ssh.multiserver.sh` (niveau 1) - Clés inter-nœuds
- Orchestrateurs réseau, stockage, k8s (niveau 1)

### 5. **`disaster-recovery.activate.sh`** (Niveau 2)
**Description** : Activation du plan de reprise après sinistre
**Compose** :
- `migrate-ssh.user.sh` (niveau 1) - Restauration des accès SSH
- `setup-ssh.access.sh` (niveau 1) - Nouveaux accès d'urgence
- `deploy-ssh.multiserver.sh` (niveau 1) - Distribution clés recovery
- Orchestrateurs backup, réseau, services (niveau 1)

### 6. **`compliance-enforcement.sh`** (Niveau 2)
**Description** : Application des politiques de conformité (SOC2, ISO27001)
**Compose** :
- `audit-ssh.keys.sh` (niveau 1) - Vérification conformité SSH
- `rotate-ssh.keys.sh` (niveau 1) - Rotation forcée tous les 90j
- `revoke-ssh.access.sh` (niveau 1) - Révocation ex-employés
- Orchestrateurs logs, encryption, access control (niveau 1)

### 7. **`onboarding-employee.sh`** (Niveau 2)
**Description** : Intégration complète d'un nouvel employé
**Compose** :
- `setup-ssh.access.sh` (niveau 1) - Création accès SSH personnel
- `deploy-ssh.multiserver.sh` (niveau 1) - Déploiement sur serveurs assignés
- Orchestrateurs comptes, permissions, VPN, outils (niveau 1)

### 8. **`offboarding-employee.sh`** (Niveau 2)
**Description** : Départ employé avec révocation tous accès
**Compose** :
- `audit-ssh.keys.sh` (niveau 1) - Liste tous les accès SSH
- `revoke-ssh.access.sh` (niveau 1) - Révocation tous serveurs
- Orchestrateurs désactivation comptes, backup données (niveau 1)

## Exemple d'Architecture Niveau 2

```
orchestrators/level-2/provision-server.complete.sh
│
├─ orchestrators/level-1/setup-ssh.access.sh
│  ├─ atomics/generate-ssh.keypair.sh
│  ├─ atomics/add-ssh.key.authorized.sh
│  └─ atomics/check-ssh.connection.sh
│
├─ orchestrators/level-1/deploy-ssh.multiserver.sh
│  ├─ atomics/generate-ssh.keypair.sh
│  ├─ atomics/add-ssh.key.authorized.sh (× N serveurs)
│  └─ atomics/check-ssh.connection.sh (× N serveurs)
│
├─ orchestrators/level-1/setup-network.sh
│  └─ [autres atomiques réseau...]
│
└─ orchestrators/level-1/configure-firewall.sh
   └─ [autres atomiques firewall...]
```

## Principe Clé

**Niveau 2** = Orchestration de **workflows métier complets** composant plusieurs orchestrateurs de **niveau 1**, eux-mêmes composés de scripts **atomiques**.

Chaque niveau ajoute une couche d'abstraction et de complexité métier, tout en restant modulaire et testable.

Je vais chercher des exemples de scripts de niveau 3 dans la documentation.Avec les orchestrateurs de **niveau 2**, vous pouvez créer des **scripts de niveau 3** pour des processus d'entreprise globaux :

## Scripts de Niveau 3 - Processus Métier Stratégiques

### 1. **`deploy-datacenter.complete.sh`** (Niveau 3)
**Description** : Déploiement complet d'un nouveau datacenter
**Compose** :
- `provision-server.complete.sh` (niveau 2) - × N serveurs (web, db, cache, etc.)
- `deploy-cluster.kubernetes.sh` (niveau 2) - Cluster orchestration
- `migrate-infrastructure.sh` (niveau 2) - Migration données existantes
- `security-audit.full.sh` (niveau 2) - Validation sécurité finale

**Workflow** :
1. Provisionnement infrastructure physique/virtuelle
2. Configuration réseau et sécurité globale
3. Déploiement applications et services
4. Migration et synchronisation données
5. Tests de charge et validation
6. Activation production

### 2. **`business-continuity.plan.sh`** (Niveau 3)
**Description** : Plan de continuité d'activité complet (PCA/PRA)
**Compose** :
- `disaster-recovery.activate.sh` (niveau 2) - Activation DR
- `migrate-infrastructure.sh` (niveau 2) - Bascule infrastructure
- `security-audit.full.sh` (niveau 2) - Audit post-bascule
- `compliance-enforcement.sh` (niveau 2) - Maintien conformité

**Scénarios** :
- Bascule site primaire → site secondaire
- Restauration après sinistre
- Test PRA annuel

### 3. **`enterprise-onboarding.complete.sh`** (Niveau 3)
**Description** : Intégration complète entreprise (acquisition/fusion)
**Compose** :
- `onboarding-employee.sh` (niveau 2) - × N employés
- `migrate-infrastructure.sh` (niveau 2) - Fusion infrastructures
- `compliance-enforcement.sh` (niveau 2) - Alignement politiques
- `security-audit.full.sh` (niveau 2) - Audit sécurité global

**Processus** :
1. Audit infrastructure cible
2. Planification migration
3. Intégration des équipes (accès, comptes)
4. Fusion des systèmes
5. Conformité réglementaire
6. Formation et documentation

### 4. **`annual-security.certification.sh`** (Niveau 3)
**Description** : Certification sécurité annuelle (ISO27001, SOC2, PCI-DSS)
**Compose** :
- `security-audit.full.sh` (niveau 2) - Audit complet parc
- `compliance-enforcement.sh` (niveau 2) - Mise en conformité
- `disaster-recovery.activate.sh` (niveau 2) - Test DR obligatoire
- Orchestrateurs reporting et documentation (niveau 2)

**Livrables** :
- Rapport d'audit complet
- Remédiation automatique
- Documentation de conformité
- Tests de résilience

### 5. **`saas-multitenancy.deployment.sh`** (Niveau 3)
**Description** : Déploiement plateforme SaaS multi-tenant
**Compose** :
- `deploy-datacenter.complete.sh` (niveau 3) - Infrastructure multi-région
- `deploy-cluster.kubernetes.sh` (niveau 2) - × N clusters par région
- `provision-server.complete.sh` (niveau 2) - Serveurs dédiés par tenant
- `security-audit.full.sh` (niveau 2) - Isolation et sécurité

**Architecture** :
- Multi-région (US, EU, APAC)
- Isolation données par tenant
- HA/DR global
- Monitoring centralisé

### 6. **`zero-trust.migration.sh`** (Niveau 3)
**Description** : Migration vers architecture Zero Trust
**Compose** :
- `security-audit.full.sh` (niveau 2) - État actuel
- `provision-server.complete.sh` (niveau 2) - Nouveaux composants ZT
- `migrate-infrastructure.sh` (niveau 2) - Migration progressive
- `compliance-enforcement.sh` (niveau 2) - Politiques Zero Trust

**Phases** :
1. Audit architecture actuelle
2. Déploiement composants ZT (IAM, MFA, micro-segmentation)
3. Migration application par application
4. Désactivation ancien modèle
5. Validation et certification

### 7. **`digital-transformation.platform.sh`** (Niveau 3)
**Description** : Transformation digitale complète de l'entreprise
**Compose** :
- `deploy-datacenter.complete.sh` (niveau 3) - Infrastructure cloud-native
- `saas-multitenancy.deployment.sh` (niveau 3) - Plateformes métier
- `enterprise-onboarding.complete.sh` (niveau 3) - Formation équipes
- `annual-security.certification.sh` (niveau 3) - Gouvernance

**Transformation** :
- Legacy → Cloud-native
- Monolithes → Microservices
- On-premise → Hybrid/Multi-cloud
- Waterfall → DevOps/CI-CD

### 8. **`mergers-acquisitions.integration.sh`** (Niveau 3)
**Description** : Intégration IT complète M&A (Mergers & Acquisitions)
**Compose** :
- `enterprise-onboarding.complete.sh` (niveau 3) - Intégration RH/IT
- `migrate-infrastructure.sh` (niveau 2) - Fusion infrastructures
- `business-continuity.plan.sh` (niveau 3) - Maintien activité
- `compliance-enforcement.sh` (niveau 2) - Harmonisation juridique

**Timeline typique** :
- J-30 : Audit et planification
- J0 : Annonce et début intégration
- J+90 : Fusion systèmes critiques
- J+180 : Intégration complète

## Architecture Niveau 3 - Exemple

```
orchestrators/level-3/deploy-datacenter.complete.sh
│
├─ orchestrators/level-2/provision-server.complete.sh (× 50 serveurs)
│  ├─ orchestrators/level-1/setup-ssh.access.sh
│  ├─ orchestrators/level-1/deploy-ssh.multiserver.sh
│  ├─ orchestrators/level-1/setup-network.sh
│  └─ orchestrators/level-1/configure-firewall.sh
│     └─ [atomiques réseau, sécurité...]
│
├─ orchestrators/level-2/deploy-cluster.kubernetes.sh
│  ├─ orchestrators/level-1/setup-ssh.access.sh
│  └─ [orchestrateurs k8s niveau 1...]
│
├─ orchestrators/level-2/migrate-infrastructure.sh
│  ├─ orchestrators/level-1/migrate-ssh.user.sh
│  └─ [orchestrateurs migration niveau 1...]
│
└─ orchestrators/level-2/security-audit.full.sh
   ├─ orchestrators/level-1/audit-ssh.keys.sh
   └─ [orchestrateurs audit niveau 1...]
```

## Caractéristiques Niveau 3

✅ **Processus métier stratégiques** (mois de travail)  
✅ **Coordination multi-équipes** (infra, sécu, dev, ops)  
✅ **Orchestration de niveau 2** (eux-mêmes composés de niveau 1)  
✅ **Gouvernance d'entreprise** (conformité, audit, reporting)  
✅ **Impact business critique** (M&A, transformation, certification)  
✅ **Timeline longue** (30-180 jours)  
✅ **Rollback complexe** avec plan B/C/D  

Le **niveau 3** représente les **initiatives stratégiques** de l'entreprise, orchestrant des dizaines voire centaines de scripts pour des transformations majeures.


Analysons votre diagramme pour identifier ce qu'il faut pour l'exécution SSH à distance.

## Scripts présents dans votre diagramme

**Scripts atomiques (niveau 0)** :
- `detect-disk.sh` - Détecte les disques
- `format-disk.sh` - Formate un disque
- `get-cpu.info.sh` - Infos CPU
- `get-memory.info.sh` - Infos mémoire

**Orchestrateurs (niveau 1)** :
- `setup-iscsi-target.sh` - Configure la cible iSCSI
- `ct-launcher.sh` - Lance un conteneur

## Scripts SSH manquants pour l'exécution à distance

Pour exécuter ce workflow sur un serveur distant via SSH, vous avez besoin de :

### 1. **Scripts SSH atomiques manquants** :

```bash
# Ces scripts devraient déjà exister selon le catalogue
atomics/check-ssh.connection.sh      # ✅ Existe - Tester la connexion
atomics/generate-ssh.keypair.sh      # ✅ Existe - Générer les clés
atomics/add-ssh.key.authorized.sh    # ✅ Existe - Autoriser l'accès

# Script atomique MANQUANT à créer :
atomics/execute-ssh.remote.sh        # ❌ À CRÉER
```

### 2. **Script atomique à créer : `execute-ssh.remote.sh`**

```bash
#!/bin/bash
# Script: execute-ssh.remote.sh
# Description: Exécute un script distant via SSH et récupère le JSON
# Usage: execute-ssh.remote.sh <host> <user> <script_path> [args...]
#
# Entrée:
#   - host: serveur distant
#   - user: utilisateur SSH
#   - script_path: chemin du script à exécuter
#   - args: arguments du script
#
# Sortie JSON:
# {
#   "data": {
#     "host": "server.example.com",
#     "exit_code": 0,
#     "stdout": "...",
#     "execution_time_ms": 1234
#   }
# }
```

### 3. **Orchestrateur niveau 1 manquant : `deploy-script.remote.sh`**

```bash
#!/bin/bash
# Script: deploy-script.remote.sh (niveau 1)
# Description: Déploie et exécute un script sur un serveur distant
#
# Compose:
#   - check-ssh.connection.sh (atomique)
#   - copy-file.sh (atomique) - pour transférer le script
#   - execute-ssh.remote.sh (atomique)
```

### 4. **Orchestrateur niveau 2 à créer : `execute-workflow.remote.sh`**

C'est CE script qui manque pour exécuter votre diagramme à distance :

```bash
#!/bin/bash
# Script: execute-workflow.remote.sh (niveau 2)
# Description: Exécute le workflow setup-iscsi-target complet sur serveur distant
#
# Usage: 
#   ./execute-workflow.remote.sh --host 192.168.1.100 --user admin
#
# Compose:
#   - setup-ssh.access.sh (niveau 1) - Configure l'accès SSH
#   - deploy-script.remote.sh (niveau 1) - Déploie les scripts
#   - execute-ssh.remote.sh (atomique) - Exécute le workflow
#
# Workflow:
#   1. Vérifier connexion SSH
#   2. Transférer tous les scripts nécessaires:
#      - atomics/detect-disk.sh
#      - atomics/format-disk.sh
#      - atomics/get-cpu.info.sh
#      - atomics/get-memory.info.sh
#      - orchestrators/level-1/setup-iscsi-target.sh
#      - orchestrators/main/ct-launcher.sh
#   3. Transférer les bibliothèques (lib/*)
#   4. Exécuter setup-iscsi-target.sh à distance
#   5. Récupérer les résultats JSON
#   6. Nettoyer les fichiers temporaires (optionnel)
```

## Architecture complète pour l'exécution SSH

```
orchestrators/level-2/execute-workflow.remote.sh (NOUVEAU)
│
├─ orchestrators/level-1/setup-ssh.access.sh
│  ├─ atomics/generate-ssh.keypair.sh
│  ├─ atomics/add-ssh.key.authorized.sh
│  └─ atomics/check-ssh.connection.sh
│
├─ orchestrators/level-1/deploy-script.remote.sh (NOUVEAU)
│  ├─ atomics/check-ssh.connection.sh
│  ├─ atomics/copy-file.sh (ou scp/rsync)
│  └─ atomics/execute-ssh.remote.sh (NOUVEAU)
│
└─ Workflow distant (exécuté sur le serveur cible):
   └─ orchestrators/level-1/setup-iscsi-target.sh
      ├─ atomics/detect-disk.sh
      ├─ atomics/format-disk.sh
      ├─ atomics/get-cpu.info.sh
      └─ atomics/get-memory.info.sh
```

## Scripts manquants - Résumé

### À créer immédiatement :

1. ✅ **`atomics/execute-ssh.remote.sh`** - Exécution commande SSH distante
2. ✅ **`atomics/copy-file.remote.sh`** - Copie fichier via SCP/rsync
3. ✅ **`orchestrators/level-1/deploy-script.remote.sh`** - Déploiement script distant
4. ✅ **`orchestrators/level-2/execute-workflow.remote.sh`** - Votre orchestrateur principal

### Déjà disponibles (à vérifier) :

- `atomics/check-ssh.connection.sh`
- `atomics/generate-ssh.keypair.sh`
- `atomics/add-ssh.key.authorized.sh`
- `orchestrators/level-1/setup-ssh.access.sh`

## Commande finale

Une fois ces scripts créés, vous pourrez exécuter :

```bash
./orchestrators/level-2/execute-workflow.remote.sh \
  --host 192.168.1.100 \
  --user root \
  --workflow setup-iscsi-target \
  --disk /dev/sdb \
  --target-iqn iqn.2025-01.com.example:target1
```

**Le script critique manquant est donc `execute-workflow.remote.sh` (niveau 2)** qui orchestre tout le déploiement et l'exécution à distance de votre workflow iSCSI.

