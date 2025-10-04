# Guide de Démarrage - Méthodologie de Développement Modulaire

## Introduction

Ce guide vous explique **comment utiliser les deux documents de méthodologie** avant de commencer à développer vos scripts pour un nouveau projet. Les deux documents sont conçus pour être utilisés comme référence et guide pratique.

---

## 📚 Présentation des documents

### Document 1 : "Méthodologie de Développement Modulaire et Hiérarchique"
**Type** : Documentation de référence et spécifications  
**Contenu** :
- Architecture et principes fondamentaux
- Standards et conventions obligatoires
- Templates de base (atomique et orchestrateur)
- Système de logging, validation, sécurité
- Tests et documentation
- CI/CD, versioning, monitoring

**Utilisation** : Document à lire EN PREMIER, à consulter régulièrement

### Document 2 : "Méthodologie de Développement Modulaire - Partie 2"
**Type** : Bibliothèque de fonctions et patterns avancés  
**Contenu** :
- Fonctions réutilisables (cache, worker pool, retry, etc.)
- Patterns d'architecture avancés
- Intégrations (API, BDD, notifications)
- Outils de développement
- Cas d'usage complets
- Annexes pratiques

**Utilisation** : Bibliothèque de référence, à copier/adapter selon besoins

---

## 🎯 Avant de commencer : Les 5 étapes essentielles

### Étape 1 : Lecture et compréhension (2-3 heures)

#### 📖 Que lire dans le Document 1 ?

**À lire obligatoirement** :
1. ✅ **Vue d'ensemble** - Comprendre le principe fondamental
2. ✅ **Architecture hiérarchique** - Structure des niveaux
3. ✅ **Convention de nommage** - Comment nommer vos scripts
4. ✅ **Standard d'interface** - Codes de sortie et format JSON
5. ✅ **Structure d'un script atomique** - Le template de base
6. ✅ **Structure d'un orchestrateur** - Le template orchestrateur
7. ✅ **Système de logging** - Comment logger correctement

**À lire si vous avez le temps** :
- Validation et sécurité
- Tests (vous y reviendrez plus tard)
- CI/CD (quand vous serez prêt à automatiser)

**À survoler pour savoir que ça existe** :
- Monitoring et métriques (pour plus tard)
- Exemples de scripts complets (inspiration)

#### 📖 Que lire dans le Document 2 ?

**NE PAS LIRE EN DÉTAIL** - Ce document est une **bibliothèque de fonctions**

**À faire** :
1. ✅ Lire le **sommaire** pour connaître ce qui existe
2. ✅ Marquer les sections importantes :
   - Patterns avancés (cache, worker pool, retry)
   - Intégrations (notifications, API, BDD)
   - Outils de développement
   - Annexes (commandes utiles, troubleshooting)

**Stratégie** : Revenez à ce document **quand vous avez besoin** d'une fonctionnalité spécifique.

---

### Étape 2 : Préparation de l'environnement (30 minutes)

#### Installation du framework de base

```bash
# 1. Créer la structure du projet
mkdir -p mon-projet/{atomics,orchestrators,lib,tests,docs,logs,monitoring}
cd mon-projet

# 2. Initialiser Git
git init

# 3. Copier les templates depuis Document 1
# Créer les fichiers de base
```

#### Créer la structure minimale

```bash
mon-projet/
├── atomics/                 # Scripts atomiques
├── orchestrators/           # Orchestrateurs
│   ├── level-1/
│   ├── level-2/
│   └── level-3/
├── lib/                     # Bibliothèques partagées
│   ├── common.sh
│   ├── logger.sh
│   └── validator.sh
├── tests/                   # Tests
│   ├── atomics/
│   └── orchestrators/
├── docs/                    # Documentation
├── logs/                    # Logs
├── monitoring/              # Monitoring
├── tools/                   # Outils de dev
├── .gitignore
├── README.md
└── VERSION
```

#### Copier les bibliothèques essentielles depuis Document 2

**Fichiers à créer en priorité** (copier depuis Document 2) :

1. **`lib/common.sh`** - Fonctions utilitaires de base
2. **`lib/logger.sh`** - Système de logging
3. **`lib/validator.sh`** - Validation des entrées

**Optionnel** (selon vos besoins) :
- `lib/cache.sh` - Si vous avez besoin de cache
- `lib/retry.sh` - Si vous interagissez avec des services externes
- `lib/notifications.sh` - Si vous voulez des alertes
- `lib/worker-pool.sh` - Si vous faites du parallélisme

#### Créer le fichier .gitignore

```bash
cat > .gitignore <<EOF
# Logs
logs/
*.log

# Cache
.cache/
*.cache

# Temporaires
*.tmp
tmp/

# Secrets
secrets/
*.key
*.pem

# Build
build/
dist/

# OS
.DS_Store
Thumbs.db
EOF
```

---

### Étape 3 : Créer votre premier script (1 heure)

#### Processus recommandé

```bash
# 1. Identifier votre besoin
# Exemple : "Je dois lister les disques disponibles"

# 2. Copier le template atomique depuis Document 1
cp templates/template-atomic.sh atomics/list-disks.sh

# 3. Personnaliser l'en-tête
nano atomics/list-disks.sh
```

#### Template de démarrage simplifié

```bash
#!/bin/bash
#
# Script: list-disks.sh
# Description: Liste tous les disques disponibles sur le système
# Usage: list-disks.sh [OPTIONS]
#
# Options:
#   -h, --help              Affiche cette aide
#   -v, --verbose           Mode verbeux
#
# Exit codes:
#   0 - Succès
#   1 - Erreur générale
#   3 - Erreur de permission
#

set -euo pipefail

# Chemins
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Import des bibliothèques
source "$PROJECT_ROOT/lib/logger.sh"

# Codes de sortie
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR_GENERAL=1
readonly EXIT_ERROR_PERMISSION=3

# Variables
VERBOSE=0

# Fonction principale
do_main_action() {
    log_info "Listing available disks"
    
    # VOTRE LOGIQUE ICI
    local disks=$(lsblk -d -n -o NAME,SIZE,TYPE | grep "disk")
    
    # Convertir en JSON
    local json_array="[]"
    while read -r name size type; do
        json_array=$(echo "$json_array" | jq ". += [{\"name\": \"$name\", \"size\": \"$size\", \"type\": \"$type\"}]")
    done <<< "$disks"
    
    echo "$json_array"
}

# Construction JSON de sortie
build_json_output() {
    local status=$1
    local code=$2
    local message=$3
    local data=$4
    
    cat <<EOF
{
  "status": "$status",
  "code": $code,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$(basename "$0")",
  "message": "$message",
  "data": $data
}
EOF
}

# Point d'entrée
main() {
    exec 3>&1  # Sauvegarder STDOUT
    exec 1>&2  # Rediriger STDOUT vers STDERR pour les logs
    
    log_info "Script started"
    
    # Exécution
    local result=$(do_main_action)
    
    # Sortie JSON sur le vrai STDOUT
    build_json_output "success" $EXIT_SUCCESS "Disks listed successfully" "$result" >&3
    
    log_info "Script completed"
    exit $EXIT_SUCCESS
}

main "$@"
```

#### Tester votre script

```bash
# Rendre exécutable
chmod +x atomics/list-disks.sh

# Tester
./atomics/list-disks.sh

# Vérifier le JSON
./atomics/list-disks.sh | jq .
```

---

### Étape 4 : Établir votre workflow de développement (30 minutes)

#### Créer un script d'aide au développement

```bash
# tools/dev-helper.sh
#!/bin/bash

cat <<EOF
🛠️  Aide au développement

Commandes disponibles:

1. Créer un nouveau script atomique:
   ./tools/new-atomic.sh <nom>

2. Créer un nouveau orchestrateur:
   ./tools/new-orchestrator.sh <nom> <level>

3. Tester un script:
   ./atomics/mon-script.sh
   ./atomics/mon-script.sh | jq .

4. Valider la syntaxe:
   bash -n ./atomics/mon-script.sh
   shellcheck ./atomics/mon-script.sh

5. Consulter les logs:
   tail -f logs/atomics/$(date +%Y-%m-%d)/mon-script.log

6. Consulter la doc:
   # Document 1: Architecture et standards
   # Document 2: Bibliothèque de fonctions

📚 Documents de référence:
   - Document 1: TOUJOURS consulter pour les standards
   - Document 2: Chercher les fonctions dont vous avez besoin
EOF
```

#### Script pour créer rapidement un atomique

```bash
# tools/new-atomic.sh
#!/bin/bash

NAME=$1

if [[ -z "$NAME" ]]; then
    echo "Usage: $0 <script-name>"
    exit 1
fi

SCRIPT_FILE="atomics/${NAME}.sh"

if [[ -f "$SCRIPT_FILE" ]]; then
    echo "Error: $SCRIPT_FILE already exists"
    exit 1
fi

cat > "$SCRIPT_FILE" <<'EOF'
#!/bin/bash
#
# Script: SCRIPT_NAME.sh
# Description: TODO
# Usage: SCRIPT_NAME.sh [OPTIONS]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_ROOT/lib/logger.sh"

readonly EXIT_SUCCESS=0
readonly EXIT_ERROR_GENERAL=1

do_main_action() {
    log_info "Starting main action"
    
    # TODO: Implement your logic here
    
    echo '{"result": "success"}'
}

build_json_output() {
    local status=$1
    local code=$2
    local message=$3
    local data=$4
    
    cat <<EEOF
{
  "status": "$status",
  "code": $code,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$(basename "$0")",
  "message": "$message",
  "data": $data
}
EEOF
}

main() {
    exec 3>&1
    exec 1>&2
    
    log_info "Script started"
    
    local result=$(do_main_action)
    
    build_json_output "success" $EXIT_SUCCESS "Operation completed" "$result" >&3
    
    log_info "Script completed"
    exit $EXIT_SUCCESS
}

main "$@"
EOF

sed -i "s/SCRIPT_NAME/$NAME/g" "$SCRIPT_FILE"
chmod +x "$SCRIPT_FILE"

echo "✓ Created: $SCRIPT_FILE"
echo ""
echo "Next steps:"
echo "  1. Edit the script: nano $SCRIPT_FILE"
echo "  2. Implement your logic in do_main_action()"
echo "  3. Test: ./$SCRIPT_FILE"
echo "  4. Validate: shellcheck $SCRIPT_FILE"
```

---

### Étape 5 : Comprendre comment chercher dans les documents (15 minutes)

#### Quand consulter le Document 1 ?

| Situation | Section à consulter |
|-----------|---------------------|
| Je ne sais pas comment nommer mon script | **Convention de nommage** |
| Je veux créer un nouveau script | **Structure d'un script atomique** |
| Mon script doit appeler d'autres scripts | **Structure d'un orchestrateur** |
| Je ne sais pas quel code de sortie utiliser | **Standard d'interface > Codes de sortie** |
| Je veux logger quelque chose | **Système de logging centralisé** |
| Je veux valider les entrées | **Validation et sécurité** |
| Je configure le CI/CD | **Système CI/CD** |
| Je veux packager mon projet | **Déploiement et distribution** |

#### Quand chercher dans le Document 2 ?

| Besoin | Fonction/Section à utiliser |
|--------|----------------------------|
| Mettre en cache des résultats | **`lib/cache.sh`** - Pattern : Cache et mémorisation |
| Exécuter des tâches en parallèle | **`lib/worker-pool.sh`** - Pattern : Pool de workers |
| Réessayer une opération qui échoue | **`lib/retry.sh`** - Pattern : Retry avec backoff |
| Appeler une API REST | **`lib/api-client.sh`** - Intégration API REST |
| Se connecter à une base de données | **`lib/database.sh`** - Intégration avec bases de données |
| Envoyer des notifications | **`lib/notifications.sh`** - Webhooks et notifications |
| Exécuter dans un environnement isolé | **`lib/sandbox.sh`** - Pattern : Sandbox d'exécution |
| Auditer les exécutions | **`lib/audit.sh`** - Audit et traçabilité |
| Gérer les timeouts | **`lib/timeout.sh`** - Gestion des timeouts |
| Créer un nouveau script rapidement | **Outils de développement > Générateur de scripts** |
| Débugger un problème | **Annexe E : Troubleshooting** |
| Voir toutes les commandes utiles | **Annexe D : Commandes utiles** |

#### Méthode de recherche efficace

```bash
# 1. Identifier votre besoin
"Je veux envoyer une notification Slack quand mon script échoue"

# 2. Chercher dans le Document 2
# Ctrl+F : "notification" ou "slack"
# Trouver : lib/notifications.sh > notify_slack()

# 3. Copier la fonction dans votre lib/notifications.sh

# 4. Utiliser dans votre script
source "$PROJECT_ROOT/lib/notifications.sh"
notify_slack "$WEBHOOK_URL" "Backup failed" "error"
```

---

## 🚀 Workflow complet de développement

### Scénario : Créer un système de backup

#### Phase 1 : Planification (10 minutes)

```markdown
## Mon besoin
Créer un système de backup automatisé qui:
- Détecte les disques USB
- Formate le disque
- Copie les fichiers
- Envoie une notification

## Architecture
1. Script atomique: detect-usb.sh
2. Script atomique: format-disk.sh
3. Script atomique: copy-files.sh
4. Orchestrateur: backup-system.sh (level-1)

## Fonctions nécessaires (Document 2)
- lib/notifications.sh (pour Slack)
- lib/retry.sh (pour la copie)
```

#### Phase 2 : Création des atomiques (1-2 heures)

```bash
# 1. Créer detect-usb.sh
./tools/new-atomic.sh detect-usb
# Implémenter la logique
# Tester

# 2. Créer format-disk.sh
./tools/new-atomic.sh format-disk
# Implémenter
# Tester

# 3. Créer copy-files.sh
./tools/new-atomic.sh copy-files
# Utiliser lib/retry.sh pour la robustesse
# Tester
```

#### Phase 3 : Création de l'orchestrateur (30 minutes)

```bash
# Créer l'orchestrateur
mkdir -p orchestrators/level-1
./tools/new-orchestrator.sh backup-system 1

# Implémenter la séquence:
# 1. detect-usb.sh
# 2. format-disk.sh avec le device détecté
# 3. copy-files.sh vers le device
# 4. notify_slack avec le résultat

# Tester le flux complet
```

#### Phase 4 : Tests et validation (30 minutes)

```bash
# Tester chaque atomique individuellement
./atomics/detect-usb.sh | jq .
./atomics/format-disk.sh /dev/sdb1 | jq .
./atomics/copy-files.sh /source /dest | jq .

# Tester l'orchestrateur
./orchestrators/level-1/backup-system.sh --source /home --notify

# Valider avec shellcheck
find atomics/ orchestrators/ -name "*.sh" -exec shellcheck {} \;
```

#### Phase 5 : Documentation (15 minutes)

```bash
# Créer README.md pour chaque script
# Documenter les dépendances
# Ajouter des exemples d'utilisation
```

---

## 📋 Checklist avant de coder

### Avant de créer un nouveau script

- [ ] J'ai lu la section "Architecture hiérarchique" (Document 1)
- [ ] Je sais si mon script est atomique ou orchestrateur
- [ ] J'ai vérifié la "Convention de nommage" (Document 1)
- [ ] J'ai le template approprié sous les yeux
- [ ] Je connais les codes de sortie à utiliser
- [ ] Je sais comment logger (lib/logger.sh)

### Pendant le développement

- [ ] Mon script respecte le template
- [ ] J'utilise `set -euo pipefail`
- [ ] Je valide toutes les entrées
- [ ] Je log aux endroits appropriés
- [ ] Je retourne du JSON structuré
- [ ] Je gère les erreurs avec cleanup

### Avant de commiter

- [ ] Mon script passe shellcheck sans erreur
- [ ] J'ai testé toutes les branches (succès/erreur)
- [ ] La sortie JSON est valide (testé avec jq)
- [ ] J'ai documenté le script (en-tête)
- [ ] J'ai ajouté des exemples d'utilisation

---

## 💡 Conseils pratiques

### Principe KISS (Keep It Simple, Stupid)

```bash
# ❌ PAS BIEN : Tout faire dans un seul script
#!/bin/bash
# mega-script.sh qui fait 10 choses différentes

# ✅ BIEN : Un script = une action
#!/bin/bash
# detect-usb.sh - fait SEULEMENT la détection USB
```

### Commencez simple, complexifiez progressivement

```bash
# Étape 1: Script qui fonctionne
./atomics/detect-usb.sh

# Étape 2: Ajouter la validation
source "$PROJECT_ROOT/lib/validator.sh"
validate_permissions

# Étape 3: Ajouter le cache (si nécessaire)
source "$PROJECT_ROOT/lib/cache.sh"

# Étape 4: Ajouter le monitoring (plus tard)
```

### Ne copiez pas tout le Document 2

**❌ Erreur fréquente** : Copier toutes les bibliothèques "au cas où"

**✅ Bonne pratique** : 
1. Commencer avec juste `logger.sh` et `validator.sh`
2. Ajouter les autres bibliothèques QUAND vous en avez besoin
3. Copier seulement les fonctions que vous utilisez

### Utilisez les annexes du Document 2

Les annexes sont vos meilleures amies :
- **Annexe D** : Toutes les commandes utiles → à imprimer !
- **Annexe E** : Troubleshooting → quand ça ne marche pas
- **Annexe C** : Variables d'environnement → pour la configuration

---

## 🎯 Résumé : Les 3 règles d'or

### Règle 1 : Document 1 = La Bible
- **Lisez-le une fois complètement**
- **Consultez-le systématiquement** pour les standards
- **Ne déviez jamais** des conventions établies

### Règle 2 : Document 2 = La Boîte à outils
- **NE PAS lire en entier**
- **Parcourez** le sommaire pour savoir ce qui existe
- **Cherchez** quand vous avez un besoin spécifique
- **Copiez** seulement ce dont vous avez besoin

### Règle 3 : Commencer petit, grandir progressivement
- **Jour 1** : Un script atomique simple
- **Semaine 1** : 3-5 scripts atomiques qui marchent bien
- **Semaine 2** : Premier orchestrateur niveau 1
- **Mois 1** : Système complet avec monitoring

---

## 📖 Plan de lecture recommandé

### Jour 1 (3 heures)
1. Lire Document 1 sections essentielles (1h30)
2. Parcourir sommaire Document 2 (30 min)
3. Installer l'environnement (30 min)
4. Créer premier script (30 min)

### Jour 2-3 (4 heures)
1. Créer 3-4 scripts atomiques
2. Tester et valider
3. Ajouter lib/notifications.sh ou lib/retry.sh selon besoin

### Semaine 1 (8 heures)
1. 10 scripts atomiques fonctionnels
2. Premier orchestrateur simple
3. Tests et documentation

### Mois 1
1. Système complet avec orchestrateurs multi-niveaux
2. CI/CD en place
3. Monitoring basique

---

## ✅ Vous êtes prêt quand vous pouvez répondre OUI à:

- [ ] Je comprends la différence entre atomique et orchestrateur
- [ ] Je sais où trouver le template de script atomique
- [ ] Je connais les codes de sortie standards
- [ ] Je sais comment logger correctement
- [ ] Je sais où chercher une fonction dont j'ai besoin dans Document 2
- [ ] J'ai créé et testé mon premier script atomique
- [ ] Je sais valider mon code avec shellcheck
- [ ] J'ai les deux documents à portée de main

---

## 🆘 En cas de blocage

### "Je ne comprends pas l'architecture"
→ Relire Document 1 "Architecture hiérarchique" avec un schéma papier

### "Mon script ne marche pas"
→ Document 2 "Annexe E : Troubleshooting"

### "Je ne sais pas quelle fonction utiliser"
→ Document 2 sommaire + Ctrl+F avec votre mot-clé

### "C'est trop complexe"
→ Commencer avec le template minimal fourni dans ce guide
→ Ajouter la complexité progressivement

### "Je veux un exemple complet"
→ Document 1 "Exemples de scripts complets"
→ Document 2 "Cas d'usage avancés"

---

## 🎓 Formation continue

### Après 1 mois d'utilisation
- [ ] Relire les sections CI/CD (Document 1)
- [ ] Explorer le monitoring avancé (Document 2)
- [ ] Mettre en place les tests automatisés

### Après 3 mois d'utilisation
- [ ] Contribuer des améliorations à la méthodologie
- [ ] Créer vos propres patterns
- [ ] Former d'autres développeurs

---

**Bon développement ! 🚀**

N'oubliez pas : Ces documents sont là pour vous aider, pas pour vous compliquer la vie. Utilisez-les comme des guides, pas comme des contraintes absolues. L'objectif est de créer des scripts robustes et maintenables, pas d'appliquer aveuglément des règles.

**Commencez simple. Ajoutez la complexité quand nécessaire.**