# Méthodologie de Développement Modulaire et Hiérarchique

## Vue d'ensemble

Cette méthodologie décrit une approche de développement de scripts basée sur la composition de fonctions atomiques robustes en orchestrateurs de plus en plus complexes. Chaque composant fait une chose simple mais la fait parfaitement, de manière sécurisée et contrôlée.

### Principe fondamental

> **Un script bien développé ne nécessite jamais de maintenance corrective, seulement évolutive.**

Les scripts sont organisés en couches hiérarchiques où chaque niveau s'appuie sur la robustesse du niveau inférieur, permettant de construire des systèmes complexes fiables par composition.

---

## Architecture hiérarchique

### Structure des niveaux

```
projet/
├── atomics/              # Niveau 0 : Fonctions atomiques
│   ├── detect-usb.sh
│   ├── format-disk.sh
│   ├── partition-disk.sh
│   └── mount-disk.sh
├── orchestrators/        # Niveau 1+ : Orchestrateurs
│   ├── level-1/
│   │   ├── usb-disk-configurator.sh
│   │   └── usb-disk-manager.sh
│   ├── level-2/
│   │   ├── setup-disk.sh
│   │   └── setup-filesystem.sh
│   └── level-3/
│       └── setup-iscsi-target.sh
├── lib/                  # Bibliothèques partagées
│   ├── common.sh         # Fonctions communes
│   ├── logger.sh         # Système de logging
│   └── validator.sh      # Validation des entrées
├── tests/                # Tests unitaires et d'intégration
│   ├── atomics/
│   └── orchestrators/
├── docs/                 # Documentation
│   ├── atomics/
│   └── orchestrators/
└── logs/                 # Logs centralisés
    ├── atomics/
    └── orchestrators/
```

### Définition des niveaux

#### Niveau 0 : Fonctions Atomiques (`atomics/`)

**Caractéristiques :**
- Effectue **une seule action** bien définie
- Aucune dépendance vers d'autres scripts du projet (sauf `lib/`)
- Interface claire avec entrées/sorties standardisées
- Gestion complète des erreurs
- Documentation exhaustive

**Exemples :**
- `detect-usb.sh` : Détecte les périphériques USB connectés
- `format-disk.sh` : Formate un disque avec un système de fichiers spécifique
- `list-pci-ports.sh` : Liste les ports PCI disponibles

#### Niveau 1+ : Orchestrateurs (`orchestrators/level-N/`)

**Caractéristiques :**
- Compose plusieurs scripts de niveau inférieur
- Implémente une logique métier plus complexe
- Gère les flux de données entre composants
- Coordination et gestion d'erreurs au niveau workflow
- Documentation des dépendances et du flux d'exécution

**Niveau 1 :** Combine 2 à 5 fonctions atomiques
**Niveau 2 :** Combine plusieurs orchestrateurs de niveau 1
**Niveau N :** Combine des orchestrateurs de niveau N-1

---

## Convention de nommage

### Scripts atomiques

```
<verbe>-<objet>[.<sous-objet>].sh
```

**Exemples :**
- `detect-usb.sh`
- `format-disk.sh`
- `mount-disk.sh`
- `list-pci.ports.sh`
- `get-network.interface.sh`

**Verbes recommandés :**
- `detect-` : détection/découverte
- `list-` : listage d'éléments
- `get-` : récupération d'information
- `set-` : configuration/modification
- `create-` : création
- `delete-` : suppression
- `validate-` : validation
- `check-` : vérification d'état

### Scripts orchestrateurs

```
<action>-<domaine>[.<contexte>].sh
```

**Exemples :**
- `setup-disk.sh`
- `configure-network.sh`
- `deploy-iscsi.target.sh`
- `manage-usb.storage.sh`

---

## Standard d'interface

### Codes de sortie

Tous les scripts **doivent** utiliser les codes de sortie standardisés :

```bash
# Codes de sortie standards
EXIT_SUCCESS=0          # Succès
EXIT_ERROR_GENERAL=1    # Erreur générale
EXIT_ERROR_USAGE=2      # Erreur d'utilisation (paramètres invalides)
EXIT_ERROR_PERMISSION=3 # Erreur de permission
EXIT_ERROR_NOT_FOUND=4  # Ressource non trouvée
EXIT_ERROR_ALREADY=5    # Ressource déjà existante
EXIT_ERROR_DEPENDENCY=6 # Dépendance manquante
EXIT_ERROR_TIMEOUT=7    # Timeout
EXIT_ERROR_VALIDATION=8 # Erreur de validation des données
```

### Format de sortie JSON

#### Structure standard

```json
{
  "status": "success|error|warning",
  "code": 0,
  "timestamp": "2025-10-03T14:30:45Z",
  "script": "detect-usb.sh",
  "message": "Description lisible du résultat",
  "data": {
    // Données spécifiques au script
  },
  "errors": [
    // Liste des erreurs si applicable
  ],
  "warnings": [
    // Liste des avertissements si applicable
  ]
}
```

#### Exemple : Fonction atomique

```json
{
  "status": "success",
  "code": 0,
  "timestamp": "2025-10-03T14:30:45Z",
  "script": "detect-usb.sh",
  "message": "2 USB devices detected",
  "data": {
    "devices": [
      {
        "id": "usb-0001",
        "vendor": "SanDisk",
        "product": "Ultra USB 3.0",
        "size": "64GB",
        "device": "/dev/sdb"
      },
      {
        "id": "usb-0002",
        "vendor": "Kingston",
        "product": "DataTraveler",
        "size": "32GB",
        "device": "/dev/sdc"
      }
    ]
  },
  "errors": [],
  "warnings": []
}
```

#### Exemple : Orchestrateur

```json
{
  "status": "success",
  "code": 0,
  "timestamp": "2025-10-03T14:32:10Z",
  "script": "setup-disk.sh",
  "message": "Disk setup completed successfully",
  "data": {
    "disk": "/dev/sdb",
    "partition": "/dev/sdb1",
    "filesystem": "ext4",
    "mountpoint": "/mnt/usb",
    "steps_completed": [
      {
        "step": "partition",
        "script": "partition-disk.sh",
        "status": "success",
        "duration_ms": 1234
      },
      {
        "step": "format",
        "script": "format-disk.sh",
        "status": "success",
        "duration_ms": 5678
      },
      {
        "step": "mount",
        "script": "mount-disk.sh",
        "status": "success",
        "duration_ms": 234
      }
    ]
  },
  "errors": [],
  "warnings": [
    "Disk was not empty, existing data may be lost"
  ]
}
```

### Sortie sur STDOUT/STDERR

**Règle absolue :**
- **STDOUT** : Uniquement le JSON de résultat
- **STDERR** : Messages de logs, debug, progression

```bash
# Exemple d'implémentation
exec 3>&1  # Sauvegarde STDOUT
exec 1>&2  # Redirige STDOUT vers STDERR pour les logs

# Logs pendant l'exécution
echo "[INFO] Detecting USB devices..."
echo "[DEBUG] Scanning /dev/..."

# Résultat final sur le vrai STDOUT
echo "$json_result" >&3
```

---

## Système de logging centralisé

### Architecture des logs

```
logs/
├── atomics/
│   ├── 2025-10-03/
│   │   ├── detect-usb.log
│   │   ├── format-disk.log
│   │   └── ...
│   └── 2025-10-04/
├── orchestrators/
│   ├── 2025-10-03/
│   │   ├── setup-disk.log
│   │   └── ...
│   └── 2025-10-04/
└── global.log              # Log agrégé de tous les scripts
```

### Format de log

Chaque ligne de log suit le format :

```
[TIMESTAMP] [LEVEL] [SCRIPT:PID] [FUNCTION] Message
```

**Exemple :**
```
[2025-10-03T14:30:45.123Z] [INFO] [detect-usb.sh:12345] [main] Starting USB detection
[2025-10-03T14:30:45.234Z] [DEBUG] [detect-usb.sh:12345] [scan_devices] Found device: /dev/sdb
[2025-10-03T14:30:45.567Z] [WARN] [detect-usb.sh:12345] [validate_device] Device /dev/sdb has no label
[2025-10-03T14:30:45.890Z] [INFO] [detect-usb.sh:12345] [main] Detection completed: 2 devices found
```

### Niveaux de log

```bash
LOG_LEVEL_DEBUG=0    # Détails techniques, variables, états
LOG_LEVEL_INFO=1     # Informations normales d'exécution
LOG_LEVEL_WARN=2     # Avertissements (non bloquant)
LOG_LEVEL_ERROR=3    # Erreurs (bloquant)
LOG_LEVEL_CRITICAL=4 # Erreurs critiques (système)
```

### Implémentation dans `lib/logger.sh`

```bash
#!/bin/bash

# Configuration
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_LEVEL="${LOG_LEVEL:-1}"  # INFO par défaut
SCRIPT_NAME="$(basename "$0")"
SCRIPT_TYPE=""  # atomic ou orchestrator

# Détection du type de script
if [[ "$0" == *"/atomics/"* ]]; then
    SCRIPT_TYPE="atomics"
elif [[ "$0" == *"/orchestrators/"* ]]; then
    SCRIPT_TYPE="orchestrators"
fi

# Chemins des logs
DATE=$(date +%Y-%m-%d)
LOG_FILE="${LOG_DIR}/${SCRIPT_TYPE}/${DATE}/${SCRIPT_NAME%.sh}.log"
GLOBAL_LOG="${LOG_DIR}/global.log"

# Création des répertoires si nécessaire
mkdir -p "$(dirname "$LOG_FILE")"

# Fonction de log
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local function_name="${FUNCNAME[2]}"
    
    local log_entry="[${timestamp}] [${level}] [${SCRIPT_NAME}:$$] [${function_name}] ${message}"
    
    # Écriture dans le fichier du script
    echo "$log_entry" >> "$LOG_FILE"
    
    # Écriture dans le log global
    echo "$log_entry" >> "$GLOBAL_LOG"
    
    # Affichage sur STDERR selon le niveau
    case $level in
        ERROR|CRITICAL)
            echo "$log_entry" >&2
            ;;
        WARN)
            [[ $LOG_LEVEL -le 2 ]] && echo "$log_entry" >&2
            ;;
        INFO)
            [[ $LOG_LEVEL -le 1 ]] && echo "$log_entry" >&2
            ;;
        DEBUG)
            [[ $LOG_LEVEL -le 0 ]] && echo "$log_entry" >&2
            ;;
    esac
}

# Fonctions de commodité
log_debug() { log "DEBUG" "$@"; }
log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_critical() { log "CRITICAL" "$@"; }
```

---

## Validation et sécurité

### Validation des entrées

Tous les scripts **doivent** valider leurs entrées avec `lib/validator.sh` :

```bash
#!/bin/bash

# Validation d'un périphérique bloc
validate_block_device() {
    local device=$1
    
    # Vérification format
    if [[ ! "$device" =~ ^/dev/[a-z]+[0-9]*$ ]]; then
        return $EXIT_ERROR_VALIDATION
    fi
    
    # Vérification existence
    if [[ ! -b "$device" ]]; then
        return $EXIT_ERROR_NOT_FOUND
    fi
    
    return $EXIT_SUCCESS
}

# Validation d'un système de fichiers
validate_filesystem() {
    local fs=$1
    local valid_fs=("ext4" "ext3" "xfs" "btrfs" "vfat")
    
    if [[ ! " ${valid_fs[@]} " =~ " ${fs} " ]]; then
        return $EXIT_ERROR_VALIDATION
    fi
    
    return $EXIT_SUCCESS
}

# Validation des permissions
validate_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        return $EXIT_ERROR_PERMISSION
    fi
    return $EXIT_SUCCESS
}

# Validation des dépendances
validate_dependencies() {
    local deps=("$@")
    local missing=()
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        return $EXIT_ERROR_DEPENDENCY
    fi
    
    return $EXIT_SUCCESS
}
```

### Gestion des erreurs

Chaque script doit implémenter :

```bash
#!/bin/bash

set -euo pipefail  # Arrêt sur erreur, variables non définies, erreurs dans pipes

# Trappe pour nettoyage
cleanup() {
    local exit_code=$?
    log_debug "Cleanup triggered with exit code: $exit_code"
    
    # Nettoyage des ressources temporaires
    [[ -n "${TEMP_FILE:-}" ]] && rm -f "$TEMP_FILE"
    [[ -n "${MOUNT_POINT:-}" ]] && umount "$MOUNT_POINT" 2>/dev/null || true
    
    exit $exit_code
}

trap cleanup EXIT ERR INT TERM

# Trappe pour erreurs spécifiques
error_handler() {
    local line_no=$1
    local exit_code=$2
    log_error "Error on line $line_no with exit code $exit_code"
}

trap 'error_handler ${LINENO} $?' ERR
```

---

## Structure d'un script atomique

### Template `atomics/template-atomic.sh`

```bash
#!/bin/bash
#
# Script: template-atomic.sh
# Description: Description courte de l'action atomique
# Usage: template-atomic.sh [OPTIONS] <required_param>
#
# Options:
#   -h, --help              Affiche cette aide
#   -v, --verbose           Mode verbeux
#   -d, --debug             Mode debug
#
# Exit codes:
#   0 - Succès
#   1 - Erreur générale
#   2 - Erreur d'utilisation
#   3 - Erreur de permission
#   4 - Ressource non trouvée
#
# Examples:
#   ./template-atomic.sh param1
#   ./template-atomic.sh --verbose param1
#

# Configuration stricte
set -euo pipefail

# Détection du répertoire du projet
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Import des bibliothèques
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"
source "$PROJECT_ROOT/lib/validator.sh"

# Codes de sortie
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR_GENERAL=1
readonly EXIT_ERROR_USAGE=2
readonly EXIT_ERROR_PERMISSION=3
readonly EXIT_ERROR_NOT_FOUND=4
readonly EXIT_ERROR_ALREADY=5
readonly EXIT_ERROR_DEPENDENCY=6
readonly EXIT_ERROR_TIMEOUT=7
readonly EXIT_ERROR_VALIDATION=8

# Variables globales
VERBOSE=0
DEBUG=0
REQUIRED_PARAM=""

# Fonction d'aide
show_help() {
    sed -n '/^# Script:/,/^$/p' "$0" | sed 's/^# \?//'
    exit 0
}

# Parsing des arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -v|--verbose)
                VERBOSE=1
                LOG_LEVEL=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                LOG_LEVEL=0
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit $EXIT_ERROR_USAGE
                ;;
            *)
                REQUIRED_PARAM="$1"
                shift
                ;;
        esac
    done
    
    # Validation des paramètres requis
    if [[ -z "$REQUIRED_PARAM" ]]; then
        log_error "Missing required parameter"
        show_help
        exit $EXIT_ERROR_USAGE
    fi
}

# Validation des prérequis
validate_prerequisites() {
    log_debug "Validating prerequisites"
    
    # Vérification des permissions
    validate_permissions || exit $EXIT_ERROR_PERMISSION
    
    # Vérification des dépendances
    validate_dependencies "command1" "command2" || exit $EXIT_ERROR_DEPENDENCY
    
    # Validation des paramètres
    # validate_block_device "$REQUIRED_PARAM" || exit $EXIT_ERROR_VALIDATION
    
    log_debug "Prerequisites validated"
}

# Fonction principale métier
do_main_action() {
    log_info "Starting main action with param: $REQUIRED_PARAM"
    
    # Logique métier ici
    local result="example_result"
    
    log_info "Main action completed successfully"
    echo "$result"
}

# Construction de la sortie JSON
build_json_output() {
    local status=$1
    local code=$2
    local message=$3
    local data=$4
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat <<EOF
{
  "status": "$status",
  "code": $code,
  "timestamp": "$timestamp",
  "script": "$(basename "$0")",
  "message": "$message",
  "data": $data,
  "errors": [],
  "warnings": []
}
EOF
}

# Nettoyage
cleanup() {
    local exit_code=$?
    log_debug "Cleanup triggered with exit code: $exit_code"
    # Nettoyage des ressources
    exit $exit_code
}

trap cleanup EXIT ERR INT TERM

# Point d'entrée principal
main() {
    # Redirection pour séparer logs et résultat JSON
    exec 3>&1
    exec 1>&2
    
    log_info "Script started: $(basename "$0")"
    
    # Parse arguments
    parse_args "$@"
    
    # Validation
    validate_prerequisites
    
    # Exécution
    local result
    result=$(do_main_action)
    
    # Construction du JSON de sortie
    local json_data="{\"result\": \"$result\"}"
    local json_output
    json_output=$(build_json_output "success" $EXIT_SUCCESS "Operation completed successfully" "$json_data")
    
    # Sortie du résultat sur STDOUT
    echo "$json_output" >&3
    
    log_info "Script completed successfully"
    exit $EXIT_SUCCESS
}

# Exécution
main "$@"
```

---

## Structure d'un orchestrateur

### Template `orchestrators/template-orchestrator.sh`

```bash
#!/bin/bash
#
# Script: template-orchestrator.sh
# Description: Orchestre plusieurs scripts atomiques pour réaliser une tâche complexe
# Usage: template-orchestrator.sh [OPTIONS]
#
# Dependencies:
#   - atomics/script1.sh
#   - atomics/script2.sh
#   - orchestrators/level-1/script3.sh
#
# Options:
#   -h, --help              Affiche cette aide
#   -v, --verbose           Mode verbeux
#   -d, --debug             Mode debug
#
# Exit codes:
#   0 - Succès
#   1 - Erreur générale
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"
source "$PROJECT_ROOT/lib/validator.sh"

readonly EXIT_SUCCESS=0
readonly EXIT_ERROR_GENERAL=1
readonly EXIT_ERROR_USAGE=2

VERBOSE=0
DEBUG=0

# Fonction pour exécuter un script et parser son JSON
execute_script() {
    local script_path=$1
    shift
    local script_args=("$@")
    
    log_info "Executing: $(basename "$script_path") ${script_args[*]}"
    
    local start_time=$(date +%s%3N)
    local output
    local exit_code=0
    
    # Exécution et capture
    output=$("$script_path" "${script_args[@]}" 2>&1) || exit_code=$?
    
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script failed: $(basename "$script_path") (exit code: $exit_code)"
        echo "$output"
        return $exit_code
    fi
    
    log_info "Script completed: $(basename "$script_path") (${duration}ms)"
    
    # Retourne le JSON parsé
    echo "$output"
}

# Orchestration principale
orchestrate() {
    log_info "Starting orchestration"
    
    local steps_completed=[]
    
    # Étape 1
    log_info "Step 1: Execute atomic script 1"
    local result1
    result1=$(execute_script "$PROJECT_ROOT/atomics/script1.sh" "param1") || return $?
    
    # Parser les données nécessaires de result1
    local data1=$(echo "$result1" | jq -r '.data.some_field')
    
    steps_completed=$(echo "$steps_completed" | jq ". += [{
        \"step\": \"script1\",
        \"script\": \"script1.sh\",
        \"status\": \"success\",
        \"duration_ms\": $(echo "$result1" | jq -r '.duration // 0')
    }]")
    
    # Étape 2
    log_info "Step 2: Execute atomic script 2 with data from step 1"
    local result2
    result2=$(execute_script "$PROJECT_ROOT/atomics/script2.sh" "$data1") || return $?
    
    steps_completed=$(echo "$steps_completed" | jq ". += [{
        \"step\": \"script2\",
        \"script\": \"script2.sh\",
        \"status\": \"success\",
        \"duration_ms\": $(echo "$result2" | jq -r '.duration // 0')
    }]")
    
    # Étape 3
    log_info "Step 3: Execute level-1 orchestrator"
    local result3
    result3=$(execute_script "$PROJECT_ROOT/orchestrators/level-1/script3.sh") || return $?
    
    steps_completed=$(echo "$steps_completed" | jq ". += [{
        \"step\": \"script3\",
        \"script\": \"script3.sh\",
        \"status\": \"success\",
        \"duration_ms\": $(echo "$result3" | jq -r '.duration // 0')
    }]")
    
    log_info "Orchestration completed successfully"
    
    # Construction de la sortie agrégée
    local json_data=$(cat <<EOF
{
  "steps_completed": $steps_completed,
  "final_result": {
    "data1": $(echo "$result1" | jq '.data'),
    "data2": $(echo "$result2" | jq '.data'),
    "data3": $(echo "$result3" | jq '.data')
  }
}
EOF
)
    
    echo "$json_data"
}

# Point d'entrée
main() {
    exec 3>&1
    exec 1>&2
    
    log_info "Orchestrator started: $(basename "$0")"
    
    # Validation des dépendances
    validate_dependencies "jq" || exit $EXIT_ERROR_DEPENDENCY
    
    # Orchestration
    local result
    result=$(orchestrate)
    
    # Sortie JSON
    local json_output
    json_output=$(build_json_output "success" $EXIT_SUCCESS "Orchestration completed" "$result")
    
    echo "$json_output" >&3
    
    log_info "Orchestrator completed successfully"
    exit $EXIT_SUCCESS
}

main "$@"
```

---

## Documentation

### Documentation des scripts atomiques

Chaque script atomique doit avoir un fichier markdown dans `docs/atomics/` :

**Format : `docs/atomics/detect-usb.md`**

```markdown
# detect-usb.sh

## Description
Détecte et liste tous les périphériques USB connectés au système.

## Dépendances
- Système : `lsusb`, `udevadm`
- Permissions : root

## Usage
```bash
./detect-usb.sh [OPTIONS]
```

## Options
- `-h, --help` : Affiche l'aide
- `-v, --verbose` : Mode verbeux
- `-d, --debug` : Mode debug
- `--filter <vendor>` : Filtre par fabricant

## Sortie JSON

### Succès
```json
{
  "status": "success",
  "code": 0,
  "timestamp": "2025-10-03T14:30:45Z",
  "script": "detect-usb.sh",
  "message": "2 USB devices detected",
  "data": {
    "devices": [
      {
        "id": "usb-0001",
        "vendor": "SanDisk",
        "product": "Ultra USB 3.0",
        "size": "64GB",
        "device": "/dev/sdb",
        "bus": "001",
        "port": "002"
      }
    ]
  },
  "errors": [],
  "warnings": []
}
```

### Erreur - Aucun périphérique
```json
{
  "status": "error",
  "code": 4,
  "timestamp": "2025-10-03T14:30:45Z",
  "script": "detect-usb.sh",
  "message": "No USB devices found",
  "data": {
    "devices": []
  },
  "errors": ["No USB devices connected"],
  "warnings": []
}
```

## Codes de sortie
- `0` : Succès, périphériques détectés
- `3` : Erreur de permission (pas root)
- `4` : Aucun périphérique trouvé
- `6` : Dépendances manquantes

## Exemples

### Détection simple
```bash
./detect-usb.sh
```

### Détection avec filtre
```bash
./detect-usb.sh --filter "SanDisk"
```

### Utilisation dans un script
```bash
result=$(./detect-usb.sh)
device=$(echo "$result" | jq -r '.data.devices[0].device')
echo "First device: $device"
```

## Tests

Voir `tests/atomics/test-detect-usb.sh`

## Changelog

### v1.0.0 (2025-10-03)
- Version initiale
- Support USB 2.0 et 3.0

### v1.1.0 (2025-10-05)
- Ajout du filtre par fabricant
- Amélioration de la détection de la taille
```

### Documentation des orchestrateurs

**Format : `docs/orchestrators/setup-disk.md`**

```markdown
# setup-disk.sh

## Description
Configure un disque complet : détection, partitionnement, formatage et montage.

## Dépendances

### Scripts atomiques
- `atomics/detect-usb.sh` : Détection du périphérique
- `atomics/partition-disk.sh` : Partitionnement
- `atomics/format-disk.sh` : Formatage
- `atomics/mount-disk.sh` : Montage

### Scripts orchestrateurs
Aucun

### Système
- `jq` : Parsing JSON

## Architecture

```
setup-disk.sh
├── detect-usb.sh (atomic)
├── partition-disk.sh (atomic)
├── format-disk.sh (atomic)
└── mount-disk.sh (atomic)
```

## Flux d'exécution

```mermaid
graph TD
    A[Début] --> B[detect-usb.sh]
    B --> C{Périphérique trouvé?}
    C -->|Non| D[Erreur EXIT_ERROR_NOT_FOUND]
    C -->|Oui| E[partition-disk.sh]
    E --> F[format-disk.sh]
    F --> G[mount-disk.sh]
    G --> H[Succès]
```

## Usage
```bash
./setup-disk.sh --device /dev/sdb --filesystem ext4 --mount /mnt/usb
```

## Options
- `-d, --device <device>` : Périphérique à configurer (requis)
- `-f, --filesystem <fs>` : Système de fichiers (défaut: ext4)
- `-m, --mount <path>` : Point de montage (défaut: /mnt/disk)
- `--label <label>` : Label du volume
- `-h, --help` : Affiche l'aide
- `-v, --verbose` : Mode verbeux

## Sortie JSON

### Succès
```json
{
  "status": "success",
  "code": 0,
  "timestamp": "2025-10-03T14:32:10Z",
  "script": "setup-disk.sh",
  "message": "Disk setup completed successfully",
  "data": {
    "disk": "/dev/sdb",
    "partition": "/dev/sdb1",
    "filesystem": "ext4",
    "mountpoint": "/mnt/usb",
    "label": "USB_DISK",
    "steps_completed": [
      {
        "step": "detect",
        "script": "detect-usb.sh",
        "status": "success",
        "duration_ms": 234
      },
      {
        "step": "partition",
        "script": "partition-disk.sh",
        "status": "success",
        "duration_ms": 1234
      },
      {
        "step": "format",
        "script": "format-disk.sh",
        "status": "success",
        "duration_ms": 5678
      },
      {
        "step": "mount",
        "script": "mount-disk.sh",
        "status": "success",
        "duration_ms": 234
      }
    ]
  },
  "errors": [],
  "warnings": []
}
```

## Codes de sortie
- `0` : Succès complet
- `1` : Erreur générale
- `3` : Erreur de permission
- `4` : Périphérique non trouvé

## Exemples

### Configuration complète
```bash
./setup-disk.sh --device /dev/sdb --filesystem ext4 --mount /mnt/usb --label BACKUP
```

### Configuration minimale
```bash
./setup-disk.sh --device /dev/sdb
```

## Tests

Voir `tests/orchestrators/test-setup-disk.sh`
```

---

## Tests

### Structure des tests

```
tests/
├── lib/
│   └── test-framework.sh      # Framework de test
├── atomics/
│   ├── test-detect-usb.sh
│   ├── test-format-disk.sh
│   └── ...
└── orchestrators/
    ├── level-1/
    │   └── test-setup-disk.sh
    └── level-2/
        └── ...
```

### Framework de test (`tests/lib/test-framework.sh`)

```bash
#!/bin/bash

# Compteurs de tests
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction d'assertion
assert_equals() {
    local expected=$1
    local actual=$2
    local message=${3:-""}
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} Test passed: $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} Test failed: $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

assert_exit_code() {
    local expected=$1
    local command=$2
    local message=${3:-""}
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    local actual
    eval "$command" > /dev/null 2>&1
    actual=$?
    
    if [[ $expected -eq $actual ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} Test passed: $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} Test failed: $message"
        echo "  Expected exit code: $expected"
        echo "  Actual exit code:   $actual"
        return 1
    fi
}

assert_json_field() {
    local json=$1
    local field=$2
    local expected=$3
    local message=${4:-""}
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    local actual
    actual=$(echo "$json" | jq -r "$field")
    
    if [[ "$expected" == "$actual" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} Test passed: $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} Test failed: $message"
        echo "  Expected $field: $expected"
        echo "  Actual $field:   $actual"
        return 1
    fi
}

# Rapport final
test_report() {
    echo ""
    echo "================================"
    echo "Test Summary"
    echo "================================"
    echo "Total:  $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo "================================"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}
```

### Exemple de test atomique

**`tests/atomics/test-detect-usb.sh`**

```bash
#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../lib/test-framework.sh"

SCRIPT_UNDER_TEST="$PROJECT_ROOT/atomics/detect-usb.sh"

echo "Testing: detect-usb.sh"
echo "================================"

# Test 1: Script existe et est exécutable
test_script_exists() {
    echo ""
    echo "Test: Script exists and is executable"
    
    [[ -f "$SCRIPT_UNDER_TEST" ]] || { echo "Script not found"; return 1; }
    [[ -x "$SCRIPT_UNDER_TEST" ]] || { echo "Script not executable"; return 1; }
    
    echo -e "${GREEN}✓${NC} Script exists and is executable"
}

# Test 2: Affichage de l'aide
test_help() {
    echo ""
    echo "Test: Help display"
    
    local output
    output=$("$SCRIPT_UNDER_TEST" --help 2>&1) || true
    
    [[ "$output" =~ "Usage:" ]] || { echo "Help missing Usage section"; return 1; }
    
    echo -e "${GREEN}✓${NC} Help displays correctly"
}

# Test 3: Sortie JSON valide
test_json_output() {
    echo ""
    echo "Test: JSON output validity"
    
    local output
    output=$("$SCRIPT_UNDER_TEST" 2>/dev/null) || true
    
    # Vérifier que c'est du JSON valide
    echo "$output" | jq empty || { echo "Invalid JSON output"; return 1; }
    
    # Vérifier les champs requis
    assert_json_field "$output" ".status" "success" "Status field"
    assert_json_field "$output" ".code" "0" "Code field"
    assert_json_field "$output" ".script" "detect-usb.sh" "Script field"
}

# Test 4: Gestion des erreurs de permission
test_permission_error() {
    echo ""
    echo "Test: Permission error handling"
    
    # Simuler une erreur de permission (si non-root)
    if [[ $EUID -ne 0 ]]; then
        assert_exit_code 3 "$SCRIPT_UNDER_TEST" "Non-root returns EXIT_ERROR_PERMISSION"
    else
        echo -e "${YELLOW}⊘${NC} Test skipped (running as root)"
    fi
}

# Exécution des tests
test_script_exists
test_help
test_json_output
test_permission_error

# Rapport
test_report
```

---

## Checklist de développement

### Pour chaque script atomique

- [ ] Suit le template standard
- [ ] En-tête de documentation complet
- [ ] Import des bibliothèques (`common.sh`, `logger.sh`, `validator.sh`)
- [ ] Codes de sortie standardisés définis
- [ ] Fonction `show_help()` implémentée
- [ ] Parsing des arguments robuste
- [ ] Validation complète des prérequis
- [ ] Validation des paramètres d'entrée
- [ ] Gestion des erreurs avec trappes
- [ ] Logs appropriés (DEBUG, INFO, WARN, ERROR)
- [ ] Sortie JSON conforme au standard
- [ ] Séparation STDOUT (JSON) / STDERR (logs)
- [ ] Fonction `cleanup()` pour les ressources
- [ ] Tests unitaires écrits
- [ ] Documentation markdown créée
- [ ] Exécution sans warning avec `shellcheck`

### Pour chaque orchestrateur

- [ ] Suit le template orchestrateur
- [ ] Liste complète des dépendances documentée
- [ ] Diagramme de flux dans la documentation
- [ ] Fonction `execute_script()` pour chaque sous-script
- [ ] Parsing JSON des résultats intermédiaires
- [ ] Gestion des erreurs en cascade
- [ ] Agrégation des résultats dans `steps_completed`
- [ ] Sortie JSON agrégée
- [ ] Tests d'intégration écrits
- [ ] Documentation markdown avec exemples
- [ ] Vérification avec `shellcheck`

---

## Bonnes pratiques

### 1. Principe de responsabilité unique
Chaque script fait **une seule chose** et la fait parfaitement.

### 2. Idempotence
Un script peut être exécuté plusieurs fois sans effets de bord indésirables.

### 3. Fail-fast
Arrêt immédiat en cas d'erreur (`set -e`), avec nettoyage approprié.

### 4. Traçabilité complète
Logs détaillés à chaque étape, permettant de retracer l'exécution.

### 5. Testabilité
Chaque script est testable indépendamment de son contexte.

### 6. Documentation vivante
La documentation est mise à jour avec chaque modification du code.

### 7. Versioning sémantique
Utiliser le versioning pour les changements majeurs, mineurs et patches.

### 8. Revue de code
Chaque script est revu avant intégration, vérifié avec `shellcheck`.

---

## Outils recommandés

### Validation de code
```bash
# Installation shellcheck
apt-get install shellcheck  # Debian/Ubuntu
brew install shellcheck     # macOS

# Vérification d'un script
shellcheck script.sh
```

### Parsing JSON
```bash
# Installation jq
apt-get install jq  # Debian/Ubuntu
brew install jq     # macOS

# Exemples d'utilisation
echo "$json" | jq '.data.devices[0].id'
echo "$json" | jq -r '.status'
```

### Tests
```bash
# Exécution des tests atomiques
./tests/atomics/test-detect-usb.sh

# Exécution de tous les tests
find tests/ -name "test-*.sh" -exec {} \;
```

---

## Maintenance et évolution

### Ajout d'un nouveau script atomique

1. Créer le script depuis le template : `cp atomics/template-atomic.sh atomics/nouveau-script.sh`
2. Implémenter la logique métier
3. Créer les tests : `cp tests/atomics/template-test.sh tests/atomics/test-nouveau-script.sh`
4. Créer la documentation : `cp docs/atomics/template.md docs/atomics/nouveau-script.md`
5. Valider avec `shellcheck`
6. Exécuter les tests
7. Commit avec message clair

### Ajout d'un orchestrateur

1. Identifier le niveau approprié
2. Créer depuis le template orchestrateur
3. Documenter les dépendances
4. Créer le diagramme de flux
5. Implémenter l'orchestration
6. Créer les tests d'intégration
7. Documenter les cas d'usage
8. Valider et tester

### Refactoring

Quand refactorer un script :
- Bugs récurrents
- Code dupliqué
- Complexité élevée
- Nouvelles exigences

**Procédure :**
1. S'assurer que les tests existent et passent
2. Refactorer le code
3. Vérifier que les tests passent toujours
4. Mettre à jour la documentation
5. Incrémenter la version

---

## Conclusion

Cette méthodologie permet de construire des systèmes complexes et fiables par composition de briques simples et robustes. La rigueur initiale sur chaque composant atomique évite la dette technique et garantit la maintenabilité à long terme.

**Principes clés à retenir :**
- Une fonction atomique = une responsabilité
- Validation systématique des entrées
- Gestion rigoureuse des erreurs
- Logs traçables et centralisés
- Tests exhaustifs
- Documentation à jour
- Code propre vérifié par `shellcheck`

En suivant ces principes, chaque nouveau script s'appuie sur une fondation solide, permettant de développer des systèmes de plus en plus sophistiqués sans sacrifier la qualité ni la fiabilité.

---

## Exemples de scripts complets

### Script atomique complet : `detect-usb.sh`

```bash
#!/bin/bash
#
# Script: detect-usb.sh
# Description: Détecte et liste tous les périphériques USB de stockage connectés
# Usage: detect-usb.sh [OPTIONS]
#
# Options:
#   -h, --help              Affiche cette aide
#   -v, --verbose           Mode verbeux
#   -d, --debug             Mode debug
#   --filter <vendor>       Filtre par fabricant
#   --min-size <size>       Taille minimale en Go (défaut: 0)
#
# Exit codes:
#   0 - Succès, périphériques détectés
#   3 - Erreur de permission (pas root)
#   4 - Aucun périphérique trouvé
#   6 - Dépendances manquantes
#
# Examples:
#   ./detect-usb.sh
#   ./detect-usb.sh --filter "SanDisk" --min-size 32
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"
source "$PROJECT_ROOT/lib/validator.sh"

readonly EXIT_SUCCESS=0
readonly EXIT_ERROR_GENERAL=1
readonly EXIT_ERROR_USAGE=2
readonly EXIT_ERROR_PERMISSION=3
readonly EXIT_ERROR_NOT_FOUND=4
readonly EXIT_ERROR_DEPENDENCY=6

VERBOSE=0
DEBUG=0
FILTER_VENDOR=""
MIN_SIZE_GB=0

show_help() {
    sed -n '/^# Script:/,/^$/p' "$0" | sed 's/^# \?//'
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -v|--verbose)
                VERBOSE=1
                LOG_LEVEL=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                LOG_LEVEL=0
                shift
                ;;
            --filter)
                FILTER_VENDOR="$2"
                shift 2
                ;;
            --min-size)
                MIN_SIZE_GB="$2"
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit $EXIT_ERROR_USAGE
                ;;
            *)
                log_error "Unexpected argument: $1"
                show_help
                exit $EXIT_ERROR_USAGE
                ;;
        esac
    done
}

validate_prerequisites() {
    log_debug "Validating prerequisites"
    
    validate_permissions || exit $EXIT_ERROR_PERMISSION
    validate_dependencies "lsblk" "udevadm" "awk" || exit $EXIT_ERROR_DEPENDENCY
    
    log_debug "Prerequisites validated"
}

get_usb_devices() {
    log_info "Scanning for USB storage devices"
    
    local devices=()
    local device_count=0
    
    # Liste tous les périphériques de type disque
    while IFS= read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local device_path="/dev/$device"
        
        # Vérifier si c'est un périphérique USB
        local bus_type=$(udevadm info --query=property --name="$device_path" 2>/dev/null | grep "ID_BUS=" | cut -d'=' -f2)
        
        if [[ "$bus_type" != "usb" ]]; then
            log_debug "Skipping $device (not USB)"
            continue
        fi
        
        log_debug "Found USB device: $device"
        
        # Récupérer les informations du périphérique
        local vendor=$(udevadm info --query=property --name="$device_path" 2>/dev/null | grep "ID_VENDOR=" | cut -d'=' -f2 | sed 's/_/ /g')
        local model=$(udevadm info --query=property --name="$device_path" 2>/dev/null | grep "ID_MODEL=" | cut -d'=' -f2 | sed 's/_/ /g')
        local serial=$(udevadm info --query=property --name="$device_path" 2>/dev/null | grep "ID_SERIAL_SHORT=" | cut -d'=' -f2)
        local size_bytes=$(lsblk -b -d -n -o SIZE "$device_path" 2>/dev/null)
        local size_gb=$((size_bytes / 1024 / 1024 / 1024))
        
        # Filtres
        if [[ -n "$FILTER_VENDOR" && ! "$vendor" =~ $FILTER_VENDOR ]]; then
            log_debug "Skipping $device (vendor filter)"
            continue
        fi
        
        if [[ $size_gb -lt $MIN_SIZE_GB ]]; then
            log_debug "Skipping $device (size filter: ${size_gb}GB < ${MIN_SIZE_GB}GB)"
            continue
        fi
        
        # Construction de l'objet JSON du périphérique
        local device_json=$(cat <<EOF
{
    "id": "usb-$(printf "%04d" $device_count)",
    "device": "$device_path",
    "vendor": "$vendor",
    "model": "$model",
    "serial": "$serial",
    "size_bytes": $size_bytes,
    "size_gb": $size_gb,
    "size_human": "${size_gb}GB"
}
EOF
)
        
        devices+=("$device_json")
        device_count=$((device_count + 1))
        
        log_info "Detected: $vendor $model (${size_gb}GB) at $device_path"
        
    done < <(lsblk -d -n -o NAME,TYPE | grep "disk")
    
    log_info "Detection completed: $device_count device(s) found"
    
    # Construction du tableau JSON
    if [[ $device_count -eq 0 ]]; then
        echo "[]"
        return $EXIT_ERROR_NOT_FOUND
    fi
    
    # Joindre les objets JSON avec des virgules
    local json_array="["
    for i in "${!devices[@]}"; do
        json_array+="${devices[$i]}"
        if [[ $i -lt $((${#devices[@]} - 1)) ]]; then
            json_array+=","
        fi
    done
    json_array+="]"
    
    echo "$json_array"
    return $EXIT_SUCCESS
}

build_json_output() {
    local status=$1
    local code=$2
    local message=$3
    local devices=$4
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local device_count=$(echo "$devices" | jq 'length')
    
    cat <<EOF
{
  "status": "$status",
  "code": $code,
  "timestamp": "$timestamp",
  "script": "$(basename "$0")",
  "message": "$message",
  "data": {
    "count": $device_count,
    "devices": $devices
  },
  "errors": [],
  "warnings": []
}
EOF
}

cleanup() {
    local exit_code=$?
    log_debug "Cleanup triggered with exit code: $exit_code"
    exit $exit_code
}

trap cleanup EXIT ERR INT TERM

main() {
    exec 3>&1
    exec 1>&2
    
    log_info "Script started: $(basename "$0")"
    
    parse_args "$@"
    validate_prerequisites
    
    local devices
    local result_code=0
    devices=$(get_usb_devices) || result_code=$?
    
    local json_output
    if [[ $result_code -eq $EXIT_ERROR_NOT_FOUND ]]; then
        json_output=$(build_json_output "error" $EXIT_ERROR_NOT_FOUND "No USB devices found" "[]")
    else
        local device_count=$(echo "$devices" | jq 'length')
        json_output=$(build_json_output "success" $EXIT_SUCCESS "$device_count USB device(s) detected" "$devices")
    fi
    
    echo "$json_output" >&3
    
    log_info "Script completed"
    exit $result_code
}

main "$@"
```

### Script atomique complet : `format-disk.sh`

```bash
#!/bin/bash
#
# Script: format-disk.sh
# Description: Formate un périphérique de stockage avec le système de fichiers spécifié
# Usage: format-disk.sh [OPTIONS] <device>
#
# Options:
#   -h, --help              Affiche cette aide
#   -v, --verbose           Mode verbeux
#   -d, --debug             Mode debug
#   -f, --filesystem <fs>   Système de fichiers (défaut: ext4)
#   -l, --label <label>     Label du volume
#   --force                 Force le formatage sans confirmation
#
# Exit codes:
#   0 - Succès
#   2 - Erreur d'utilisation
#   3 - Erreur de permission
#   4 - Périphérique non trouvé
#   8 - Erreur de validation
#
# Examples:
#   ./format-disk.sh /dev/sdb1
#   ./format-disk.sh --filesystem xfs --label BACKUP /dev/sdb1
#   ./format-disk.sh --force /dev/sdb1
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"
source "$PROJECT_ROOT/lib/validator.sh"

readonly EXIT_SUCCESS=0
readonly EXIT_ERROR_GENERAL=1
readonly EXIT_ERROR_USAGE=2
readonly EXIT_ERROR_PERMISSION=3
readonly EXIT_ERROR_NOT_FOUND=4
readonly EXIT_ERROR_VALIDATION=8

VERBOSE=0
DEBUG=0
DEVICE=""
FILESYSTEM="ext4"
LABEL=""
FORCE=0

show_help() {
    sed -n '/^# Script:/,/^$/p' "$0" | sed 's/^# \?//'
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -v|--verbose)
                VERBOSE=1
                LOG_LEVEL=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                LOG_LEVEL=0
                shift
                ;;
            -f|--filesystem)
                FILESYSTEM="$2"
                shift 2
                ;;
            -l|--label)
                LABEL="$2"
                shift 2
                ;;
            --force)
                FORCE=1
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit $EXIT_ERROR_USAGE
                ;;
            *)
                DEVICE="$1"
                shift
                ;;
        esac
    done
    
    if [[ -z "$DEVICE" ]]; then
        log_error "Missing required parameter: device"
        show_help
        exit $EXIT_ERROR_USAGE
    fi
}

validate_prerequisites() {
    log_debug "Validating prerequisites"
    
    validate_permissions || exit $EXIT_ERROR_PERMISSION
    
    # Vérifier les outils nécessaires selon le système de fichiers
    case $FILESYSTEM in
        ext4|ext3|ext2)
            validate_dependencies "mkfs.ext4" || exit $EXIT_ERROR_DEPENDENCY
            ;;
        xfs)
            validate_dependencies "mkfs.xfs" || exit $EXIT_ERROR_DEPENDENCY
            ;;
        btrfs)
            validate_dependencies "mkfs.btrfs" || exit $EXIT_ERROR_DEPENDENCY
            ;;
        vfat|fat32)
            validate_dependencies "mkfs.vfat" || exit $EXIT_ERROR_DEPENDENCY
            ;;
        *)
            log_error "Unsupported filesystem: $FILESYSTEM"
            exit $EXIT_ERROR_VALIDATION
            ;;
    esac
    
    # Validation du périphérique
    if [[ ! -b "$DEVICE" ]]; then
        log_error "Device not found or not a block device: $DEVICE"
        exit $EXIT_ERROR_NOT_FOUND
    fi
    
    # Vérifier si le périphérique est monté
    if mount | grep -q "^$DEVICE "; then
        log_error "Device is currently mounted: $DEVICE"
        exit $EXIT_ERROR_VALIDATION
    fi
    
    log_debug "Prerequisites validated"
}

confirm_format() {
    if [[ $FORCE -eq 1 ]]; then
        log_info "Force mode enabled, skipping confirmation"
        return 0
    fi
    
    log_warn "WARNING: This will erase all data on $DEVICE"
    read -p "Are you sure you want to format $DEVICE? (yes/no): " -r
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Format cancelled by user"
        exit 0
    fi
    
    log_info "User confirmed format operation"
}

format_device() {
    log_info "Starting format: $DEVICE with $FILESYSTEM"
    
    local start_time=$(date +%s)
    local format_cmd=""
    local format_output=""
    
    case $FILESYSTEM in
        ext4)
            format_cmd="mkfs.ext4 -F"
            [[ -n "$LABEL" ]] && format_cmd+=" -L $LABEL"
            format_cmd+=" $DEVICE"
            ;;
        ext3)
            format_cmd="mkfs.ext3 -F"
            [[ -n "$LABEL" ]] && format_cmd+=" -L $LABEL"
            format_cmd+=" $DEVICE"
            ;;
        xfs)
            format_cmd="mkfs.xfs -f"
            [[ -n "$LABEL" ]] && format_cmd+=" -L $LABEL"
            format_cmd+=" $DEVICE"
            ;;
        btrfs)
            format_cmd="mkfs.btrfs -f"
            [[ -n "$LABEL" ]] && format_cmd+=" -L $LABEL"
            format_cmd+=" $DEVICE"
            ;;
        vfat|fat32)
            format_cmd="mkfs.vfat -F 32"
            [[ -n "$LABEL" ]] && format_cmd+=" -n $LABEL"
            format_cmd+=" $DEVICE"
            ;;
    esac
    
    log_debug "Executing: $format_cmd"
    
    if format_output=$(eval "$format_cmd" 2>&1); then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_info "Format completed successfully in ${duration}s"
        
        # Récupérer les informations du système de fichiers
        local uuid=$(blkid -s UUID -o value "$DEVICE" 2>/dev/null || echo "")
        local fs_type=$(blkid -s TYPE -o value "$DEVICE" 2>/dev/null || echo "$FILESYSTEM")
        local actual_label=$(blkid -s LABEL -o value "$DEVICE" 2>/dev/null || echo "$LABEL")
        
        cat <<EOF
{
    "device": "$DEVICE",
    "filesystem": "$fs_type",
    "label": "$actual_label",
    "uuid": "$uuid",
    "duration_seconds": $duration
}
EOF
        return $EXIT_SUCCESS
    else
        log_error "Format failed: $format_output"
        return $EXIT_ERROR_GENERAL
    fi
}

build_json_output() {
    local status=$1
    local code=$2
    local message=$3
    local data=$4
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat <<EOF
{
  "status": "$status",
  "code": $code,
  "timestamp": "$timestamp",
  "script": "$(basename "$0")",
  "message": "$message",
  "data": $data,
  "errors": [],
  "warnings": []
}
EOF
}

cleanup() {
    local exit_code=$?
    log_debug "Cleanup triggered with exit code: $exit_code"
    exit $exit_code
}

trap cleanup EXIT ERR INT TERM

main() {
    exec 3>&1
    exec 1>&2
    
    log_info "Script started: $(basename "$0")"
    
    parse_args "$@"
    validate_prerequisites
    confirm_format
    
    local result
    result=$(format_device)
    
    local json_output
    json_output=$(build_json_output "success" $EXIT_SUCCESS "Device formatted successfully" "$result")
    
    echo "$json_output" >&3
    
    log_info "Script completed successfully"
    exit $EXIT_SUCCESS
}

main "$@"
```

---

## Système CI/CD

### Architecture CI/CD

```
.github/workflows/          # ou .gitlab-ci.yml
├── test-atomics.yml       # Tests des fonctions atomiques
├── test-orchestrators.yml  # Tests des orchestrateurs
├── lint.yml                # Validation shellcheck
└── release.yml             # Gestion des releases
```

### Workflow GitHub Actions : Tests automatiques

**`.github/workflows/test-atomics.yml`**

```yaml
name: Test Atomic Scripts

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'atomics/**'
      - 'lib/**'
      - 'tests/atomics/**'
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y shellcheck jq
    
    - name: Run shellcheck on atomics
      run: |
        find atomics/ -name "*.sh" -exec shellcheck {} \;
    
    - name: Run shellcheck on lib
      run: |
        find lib/ -name "*.sh" -exec shellcheck {} \;
    
    - name: Make scripts executable
      run: |
        chmod +x atomics/*.sh
        chmod +x tests/atomics/*.sh
    
    - name: Run atomic tests
      run: |
        for test in tests/atomics/test-*.sh; do
          echo "Running $test"
          bash "$test" || exit 1
        done
    
    - name: Generate test report
      if: always()
      run: |
        echo "# Test Results" >> $GITHUB_STEP_SUMMARY
        echo "Date: $(date)" >> $GITHUB_STEP_SUMMARY
        echo "Branch: ${{ github.ref }}" >> $GITHUB_STEP_SUMMARY
```

### Workflow GitHub Actions : Lint

**`.github/workflows/lint.yml`**

```yaml
name: Lint Shell Scripts

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Install shellcheck
      run: sudo apt-get install -y shellcheck
    
    - name: Run shellcheck on all scripts
      run: |
        find . -name "*.sh" -not -path "./node_modules/*" -exec shellcheck -x {} \;
    
    - name: Check script permissions
      run: |
        BAD_PERMS=$(find atomics/ orchestrators/ -name "*.sh" ! -perm -111)
        if [ -n "$BAD_PERMS" ]; then
          echo "Scripts without execute permission:"
          echo "$BAD_PERMS"
          exit 1
        fi
    
    - name: Validate JSON schemas
      run: |
        # Vérifier que tous les scripts produisent du JSON valide
        for script in atomics/*.sh; do
          if [ -x "$script" ]; then
            echo "Checking JSON output of $script"
            # Simuler l'exécution en mode dry-run si disponible
            # ou parser la doc pour extraire le JSON d'exemple
          fi
        done
```

### Workflow GitHub Actions : Release

**`.github/workflows/release.yml`**

```yaml
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  release:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
      with:
        fetch-depth: 0  # Récupère tout l'historique pour le changelog
    
    - name: Validate version tag
      run: |
        TAG=${GITHUB_REF#refs/tags/}
        if ! [[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          echo "Invalid version tag format: $TAG"
          exit 1
        fi
    
    - name: Generate changelog
      id: changelog
      run: |
        # Génération automatique du changelog
        TAG=${GITHUB_REF#refs/tags/}
        PREV_TAG=$(git describe --abbrev=0 --tags $(git rev-list --tags --skip=1 --max-count=1) 2>/dev/null || echo "")
        
        if [ -z "$PREV_TAG" ]; then
          git log --pretty=format:"- %s (%h)" > CHANGELOG.txt
        else
          git log ${PREV_TAG}..HEAD --pretty=format:"- %s (%h)" > CHANGELOG.txt
        fi
        
        echo "Generated changelog for $TAG"
        cat CHANGELOG.txt
    
    - name: Run all tests
      run: |
        chmod +x tests/**/*.sh
        for test in tests/atomics/*.sh; do bash "$test"; done
        for test in tests/orchestrators/**/*.sh; do bash "$test"; done
    
    - name: Create Release
      uses: actions/create-release@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        tag_name: ${{ github.ref }}
        release_name: Release ${{ github.ref }}
        body_path: CHANGELOG.txt
        draft: false
        prerelease: false
    
    - name: Package scripts
      run: |
        TAG=${GITHUB_REF#refs/tags/}
        tar -czf scripts-${TAG}.tar.gz atomics/ orchestrators/ lib/ docs/
    
    - name: Upload Release Asset
      uses: actions/upload-release-asset@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        upload_url: ${{ steps.create_release.outputs.upload_url }}
        asset_path: ./scripts-${{ github.ref }}.tar.gz
        asset_name: scripts-${{ github.ref }}.tar.gz
        asset_content_type: application/gzip
```

### Configuration GitLab CI

**`.gitlab-ci.yml`**

```yaml
stages:
  - lint
  - test
  - release

variables:
  GIT_DEPTH: 0

lint:shellcheck:
  stage: lint
  image: koalaman/shellcheck-alpine:stable
  script:
    - find . -name "*.sh" -not -path "./node_modules/*" -exec shellcheck -x {} \;
  only:
    - branches
    - merge_requests

test:atomics:
  stage: test
  image: ubuntu:latest
  before_script:
    - apt-get update && apt-get install -y jq
    - chmod +x atomics/*.sh tests/atomics/*.sh
  script:
    - |
      for test in tests/atomics/test-*.sh; do
        echo "Running $test"
        bash "$test" || exit 1
      done
  only:
    - branches
    - merge_requests
  artifacts:
    reports:
      junit: test-results.xml
    when: always

test:orchestrators:
  stage: test
  image: ubuntu:latest
  before_script:
    - apt-get update && apt-get install -y jq
    - chmod +x orchestrators/**/*.sh tests/orchestrators/**/*.sh
  script:
    - |
      for test in tests/orchestrators/**/*.sh; do
        echo "Running $test"
        bash "$test" || exit 1
      done
  only:
    - branches
    - merge_requests

release:
  stage: release
  image: ubuntu:latest
  script:
    - |
      TAG=$CI_COMMIT_TAG
      tar -czf scripts-${TAG}.tar.gz atomics/ orchestrators/ lib/ docs/
  artifacts:
    paths:
      - scripts-*.tar.gz
  only:
    - tags
  except:
    - branches
```

---

## Gestion des versions et changelog

### Structure du versioning sémantique

**Format : `MAJOR.MINOR.PATCH`**

- **MAJOR** : Changements incompatibles avec les versions précédentes
- **MINOR** : Ajout de fonctionnalités rétrocompatibles
- **PATCH** : Corrections de bugs rétrocompatibles

### Fichier de version

**`VERSION`**

```
1.2.3
```

### Script de gestion des versions

**`scripts/version-manager.sh`**

```bash
#!/bin/bash
#
# Script: version-manager.sh
# Description: Gère le versioning sémantique et génère les changelogs
# Usage: version-manager.sh <command> [options]
#
# Commands:
#   bump major|minor|patch  Incrémente la version
#   current                 Affiche la version actuelle
#   changelog              Génère le changelog
#

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$PROJECT_ROOT/VERSION"
CHANGELOG_FILE="$PROJECT_ROOT/CHANGELOG.md"

get_current_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "0.0.0"
    fi
}

bump_version() {
    local bump_type=$1
    local current_version=$(get_current_version)
    
    IFS='.' read -r major minor patch <<< "$current_version"
    
    case $bump_type in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo "Invalid bump type: $bump_type"
            exit 1
            ;;
    esac
    
    local new_version="$major.$minor.$patch"
    echo "$new_version" > "$VERSION_FILE"
    echo "Version bumped: $current_version -> $new_version"
    echo "$new_version"
}

generate_changelog() {
    local version=$(get_current_version)
    local date=$(date +%Y-%m-%d)
    
    echo "Generating changelog for version $version"
    
    # Récupérer le tag précédent
    local prev_tag=$(git describe --abbrev=0 --tags $(git rev-list --tags --skip=1 --max-count=1) 2>/dev/null || echo "")
    
    local temp_changelog=$(mktemp)
    
    # En-tête
    cat > "$temp_changelog" <<EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [${version}] - ${date}

EOF
    
    # Catégoriser les commits
    local added=()
    local changed=()
    local fixed=()
    local removed=()
    
    if [[ -z "$prev_tag" ]]; then
        commits=$(git log --pretty=format:"%s|||%h" --no-merges)
    else
        commits=$(git log ${prev_tag}..HEAD --pretty=format:"%s|||%h" --no-merges)
    fi
    
    while IFS='|||' read -r message hash; do
        if [[ "$message" =~ ^feat(\(.*\))?:\ (.*) ]]; then
            added+=("- ${BASH_REMATCH[2]} ($hash)")
        elif [[ "$message" =~ ^fix(\(.*\))?:\ (.*) ]]; then
            fixed+=("- ${BASH_REMATCH[2]} ($hash)")
        elif [[ "$message" =~ ^refactor(\(.*\))?:\ (.*) ]]; then
            changed+=("- ${BASH_REMATCH[2]} ($hash)")
        elif [[ "$message" =~ ^remove(\(.*\))?:\ (.*) ]]; then
            removed+=("- ${BASH_REMATCH[2]} ($hash)")
        else
            changed+=("- $message ($hash)")
        fi
    done <<< "$commits"
    
    # Génération des sections
    if [[ ${#added[@]} -gt 0 ]]; then
        echo "### Added" >> "$temp_changelog"
        printf '%s\n' "${added[@]}" >> "$temp_changelog"
        echo "" >> "$temp_changelog"
    fi
    
    if [[ ${#changed[@]} -gt 0 ]]; then
        echo "### Changed" >> "$temp_changelog"
        printf '%s\n' "${changed[@]}" >> "$temp_changelog"
        echo "" >> "$temp_changelog"
    fi
    
    if [[ ${#fixed[@]} -gt 0 ]]; then
        echo "### Fixed" >> "$temp_changelog"
        printf '%s\n' "${fixed[@]}" >> "$temp_changelog"
        echo "" >> "$temp_changelog"
    fi
    
    if [[ ${#removed[@]} -gt 0 ]]; then
        echo "### Removed" >> "$temp_changelog"
        printf '%s\n' "${removed[@]}" >> "$temp_changelog"
        echo "" >> "$temp_changelog"
    fi
    
    # Fusionner avec l'ancien changelog
    if [[ -f "$CHANGELOG_FILE" ]]; then
        # Insérer le nouveau changelog après l'en-tête
        awk '/^## \[/ {exit} {print}' "$CHANGELOG_FILE" > "${CHANGELOG_FILE}.header"
        cat "${CHANGELOG_FILE}.header" "$temp_changelog" > "${CHANGELOG_FILE}.new"
        awk '/^## \[/,0' "$CHANGELOG_FILE" >> "${CHANGELOG_FILE}.new"
        mv "${CHANGELOG_FILE}.new" "$CHANGELOG_FILE"
        rm "${CHANGELOG_FILE}.header"
    else
        mv "$temp_changelog" "$CHANGELOG_FILE"
    fi
    
    rm -f "$temp_changelog"
    echo "Changelog generated: $CHANGELOG_FILE"
}

create_release() {
    local version=$(get_current_version)
    local tag="v${version}"
    
    echo "Creating release: $tag"
    
    # Vérifier que tout est commité
    if [[ -n $(git status -s) ]]; then
        echo "Error: Working directory is not clean"
        exit 1
    fi
    
    # Générer le changelog
    generate_changelog
    
    # Commiter le changelog et la version
    git add "$VERSION_FILE" "$CHANGELOG_FILE"
    git commit -m "chore: release version $version"
    
    # Créer le tag
    git tag -a "$tag" -m "Release version $version"
    
    echo "Release created: $tag"
    echo "Push with: git push origin main && git push origin $tag"
}

case ${1:-} in
    bump)
        bump_version "${2:-patch}"
        ;;
    current)
        get_current_version
        ;;
    changelog)
        generate_changelog
        ;;
    release)
        create_release
        ;;
    *)
        sed -n '/^# Script:/,/^$/p' "$0" | sed 's/^# \?//'
        exit 1
        ;;
esac
```

### Convention de messages de commit

Pour faciliter la génération automatique du changelog, utiliser **Conventional Commits** :

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types :**
- `feat`: Nouvelle fonctionnalité
- `fix`: Correction de bug
- `refactor`: Refactorisation
- `docs`: Documentation
- `test`: Tests
- `chore`: Maintenance (version, config)
- `perf`: Amélioration de performance
- `style`: Formatage

**Exemples :**
```
feat(atomics): add detect-usb.sh script
fix(format-disk): handle mounted devices correctly
docs(readme): update installation instructions
test(orchestrators): add integration tests for setup-disk
chore: release version 1.2.0
```

### Exemple de CHANGELOG.md

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2025-10-03

### Added
- New atomic script: detect-usb.sh with vendor filtering (a1b2c3d)
- Support for XFS filesystem in format-disk.sh (e4f5g6h)
- Comprehensive logging system with rotation (i7j8k9l)

### Changed
- Improved error handling in orchestrators (m0n1o2p)
- Updated JSON output format for better parsing (q3r4s5t)
- Refactored validation library for better reusability (u6v7w8x)

### Fixed
- Fixed mount point detection in mount-disk.sh (y9z0a1b)
- Corrected permission checks in setup-iscsi-target.sh (c2d3e4f)
- Fixed race condition in usb-disk-manager.sh (g5h6i7j)

## [1.1.3] - 2025-09-28

### Fixed
- Critical bug in partition-disk.sh causing data loss (k8l9m0n)
- Memory leak in long-running orchestrators (o1p2q3r)

## [1.1.2] - 2025-09-25

### Changed
- Performance improvements in detect-usb.sh (s4t5u6v)

### Fixed
- Handle edge case with empty USB devices (w7x8y9z)

## [1.1.0] - 2025-09-20

### Added
- New orchestrator: setup-filesystem.sh (a0b1c2d)
- Support for BTRFS filesystem (e3f4g5h)
- Automated tests for all atomic scripts (i6j7k8l)

### Changed
- Improved documentation with more examples (m9n0o1p)

## [1.0.0] - 2025-09-15

### Added
- Initial release with core atomic scripts
- Basic orchestrators for disk management
- Documentation and testing framework
```

---

## Métriques et monitoring

### Architecture de monitoring

```
monitoring/
├── collectors/
│   ├── script-metrics.sh      # Collecte les métriques d'exécution
│   └── error-tracker.sh       # Suivi des erreurs
├── dashboards/
│   ├── grafana-dashboard.json # Dashboard Grafana
│   └── prometheus-config.yml  # Configuration Prometheus
└── alerts/
    └── alert-rules.yml        # Règles d'alerte
```

### Métriques collectées

#### Métriques par script

```json
{
  "script_name": "detect-usb.sh",
  "execution_count": 1523,
  "success_count": 1498,
  "error_count": 25,
  "success_rate": 98.36,
  "avg_duration_ms": 234,
  "p50_duration_ms": 210,
  "p95_duration_ms": 450,
  "p99_duration_ms": 890,
  "last_execution": "2025-10-03T14:30:45Z",
  "errors": {
    "EXIT_ERROR_NOT_FOUND": 20,
    "EXIT_ERROR_PERMISSION": 5
  }
}
```

#### Métriques système

```json
{
  "timestamp": "2025-10-03T14:30:45Z",
  "total_scripts": 45,
  "total_executions_24h": 5432,
  "success_rate_24h": 97.8,
  "avg_duration_24h_ms": 567,
  "active_orchestrations": 3,
  "failed_orchestrations_24h": 12
}
```

### Collecteur de métriques

**`monitoring/collectors/script-metrics.sh`**

```bash
#!/bin/bash
#
# Script: script-metrics.sh
# Description: Collecte et agrège les métriques d'exécution des scripts
# Usage: script-metrics.sh [OPTIONS]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
METRICS_DIR="$PROJECT_ROOT/monitoring/metrics"
LOGS_DIR="$PROJECT_ROOT/logs"

mkdir -p "$METRICS_DIR"

# Fonction pour parser les logs et extraire les métriques
parse_logs() {
    local date=${1:-$(date +%Y-%m-%d)}
    local script_name=$2
    local log_file="$LOGS_DIR/atomics/$date/${script_name%.sh}.log"
    
    if [[ ! -f "$log_file" ]]; then
        return 1
    fi
    
    local executions=0
    local successes=0
    local errors=0
    local durations=()
    local error_codes=()
    
    # Parser le log
    while IFS= read -r line; do
        if [[ "$line" =~ "Script started:" ]]; then
            ((executions++))
        elif [[ "$line" =~ "Script completed successfully" ]]; then
            ((successes++))
        elif [[ "$line" =~ "Script failed with exit code: "([0-9]+) ]]; then
            ((errors++))
            error_codes+=("${BASH_REMATCH[1]}")
        fi
    done < "$log_file"
    
    # Calculer les statistiques
    local success_rate=0
    if [[ $executions -gt 0 ]]; then
        success_rate=$(echo "scale=2; ($successes / $executions) * 100" | bc)
    fi
    
    # Comptage des codes d'erreur
    local error_breakdown=()
    for code in "${error_codes[@]}"; do
        error_breakdown+=("\"EXIT_ERROR_$code\": $(echo "${error_codes[@]}" | tr ' ' '\n' | grep -c "^$code$")")
    done
    
    # Génération du JSON
    cat <<EOF
{
  "script_name": "$script_name",
  "date": "$date",
  "execution_count": $executions,
  "success_count": $successes,
  "error_count": $errors,
  "success_rate": $success_rate,
  "errors": {
    $(IFS=,; echo "${error_breakdown[*]}")
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# Collecte des métriques pour tous les scripts atomiques
collect_all_metrics() {
    local date=${1:-$(date +%Y-%m-%d)}
    local output_file="$METRICS_DIR/metrics-$date.json"
    
    echo "[" > "$output_file"
    
    local first=1
    for script in "$PROJECT_ROOT"/atomics/*.sh; do
        local script_name=$(basename "$script")
        local metrics=$(parse_logs "$date" "$script_name")
        
        if [[ -n "$metrics" ]]; then
            if [[ $first -eq 0 ]]; then
                echo "," >> "$output_file"
            fi
            echo "$metrics" >> "$output_file"
            first=0
        fi
    done
    
    echo "]" >> "$output_file"
    
    echo "Metrics collected: $output_file"
}

# Génération des métriques pour Prometheus
generate_prometheus_metrics() {
    local metrics_file="$METRICS_DIR/prometheus-metrics.txt"
    
    cat > "$metrics_file" <<EOF
# HELP script_executions_total Total number of script executions
# TYPE script_executions_total counter
EOF
    
    # Parser les métriques récentes
    local latest_metrics="$METRICS_DIR/metrics-$(date +%Y-%m-%d).json"
    if [[ -f "$latest_metrics" ]]; then
        while read -r script_name exec_count; do
            echo "script_executions_total{script=\"$script_name\"} $exec_count" >> "$metrics_file"
        done < <(jq -r '.[] | "\(.script_name) \(.execution_count)"' "$latest_metrics")
    fi
    
    cat >> "$metrics_file" <<EOF

# HELP script_success_rate Script success rate percentage
# TYPE script_success_rate gauge
EOF
    
    if [[ -f "$latest_metrics" ]]; then
        while read -r script_name success_rate; do
            echo "script_success_rate{script=\"$script_name\"} $success_rate" >> "$metrics_file"
        done < <(jq -r '.[] | "\(.script_name) \(.success_rate)"' "$latest_metrics")
    fi
    
    echo "Prometheus metrics generated: $metrics_file"
}

# Détection des anomalies
detect_anomalies() {
    local date=${1:-$(date +%Y-%m-%d)}
    local metrics_file="$METRICS_DIR/metrics-$date.json"
    local alerts_file="$METRICS_DIR/alerts-$date.json"
    
    if [[ ! -f "$metrics_file" ]]; then
        return 1
    fi
    
    local alerts=()
    
    # Détecter les scripts avec un taux d'erreur élevé (> 5%)
    while read -r script_name success_rate; do
        if (( $(echo "$success_rate < 95" | bc -l) )); then
            alerts+=("$(cat <<EOF
{
  "level": "warning",
  "script": "$script_name",
  "message": "High error rate detected: ${success_rate}%",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
)")
        fi
    done < <(jq -r '.[] | "\(.script_name) \(.success_rate)"' "$metrics_file")
    
    # Détecter les scripts qui n'ont pas été exécutés aujourd'hui
    for script in "$PROJECT_ROOT"/atomics/*.sh; do
        local script_name=$(basename "$script")
        local found=$(jq -r --arg name "$script_name" '.[] | select(.script_name == $name) | .script_name' "$metrics_file")
        
        if [[ -z "$found" ]]; then
            alerts+=("$(cat <<EOF
{
  "level": "info",
  "script": "$script_name",
  "message": "Script not executed today",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
)")
        fi
    done
    
    # Écriture des alertes
    if [[ ${#alerts[@]} -gt 0 ]]; then
        echo "[" > "$alerts_file"
        local first=1
        for alert in "${alerts[@]}"; do
            if [[ $first -eq 0 ]]; then
                echo "," >> "$alerts_file"
            fi
            echo "$alert" >> "$alerts_file"
            first=0
        done
        echo "]" >> "$alerts_file"
        
        echo "Alerts generated: $alerts_file"
    else
        echo "[]" > "$alerts_file"
        echo "No alerts detected"
    fi
}

# Dashboard en mode texte
show_dashboard() {
    local date=${1:-$(date +%Y-%m-%d)}
    local metrics_file="$METRICS_DIR/metrics-$date.json"
    
    if [[ ! -f "$metrics_file" ]]; then
        echo "No metrics available for $date"
        return 1
    fi
    
    echo "╔════════════════════════════════════════╗"
    echo "║         Scripts Dashboard              ║"
    echo "║         Date: $date                ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    echo "📊 Execution Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local total_executions=$(jq '[.[].execution_count] | add // 0' "$metrics_file")
    local total_successes=$(jq '[.[].success_count] | add // 0' "$metrics_file")
    local total_errors=$(jq '[.[].error_count] | add // 0' "$metrics_file")
    local overall_success_rate=$(echo "scale=2; ($total_successes / $total_executions) * 100" | bc -l 2>/dev/null || echo "0")
    
    echo "Total Executions: $total_executions"
    echo "Successful: $total_successes"
    echo "Failed: $total_errors"
    echo "Success Rate: ${overall_success_rate}%"
    echo ""
    
    echo "🔥 Top 5 Most Used Scripts"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    jq -r '.[] | "\(.execution_count) \(.script_name)"' "$metrics_file" | \
        sort -nr | head -5 | \
        awk '{printf "%-30s %s executions\n", $2, $1}' | nl
    echo ""
    
    echo "⚠️  Scripts with Issues"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local issues_found=0
    while read -r script_name success_rate; do
        if (( $(echo "$success_rate < 95" | bc -l) )); then
            echo "📉 $script_name: ${success_rate}% success rate"
            issues_found=1
        fi
    done < <(jq -r '.[] | "\(.script_name) \(.success_rate)"' "$metrics_file")
    
    if [[ $issues_found -eq 0 ]]; then
        echo "✅ All scripts performing well"
    fi
    echo ""
    
    echo "Last updated: $(date)"
}

case ${1:-} in
    collect)
        collect_all_metrics "${2:-}"
        ;;
    prometheus)
        generate_prometheus_metrics
        ;;
    alerts)
        detect_anomalies "${2:-}"
        ;;
    dashboard)
        show_dashboard "${2:-}"
        ;;
    *)
        echo "Usage: $0 <collect|prometheus|alerts|dashboard> [date]"
        exit 1
        ;;
esac
```

### Configuration Grafana

**`monitoring/dashboards/grafana-dashboard.json`**

```json
{
  "dashboard": {
    "title": "Scripts Monitoring Dashboard",
    "panels": [
      {
        "title": "Script Executions Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(script_executions_total[5m])",
            "legendFormat": "{{script}}"
          }
        ]
      },
      {
        "title": "Success Rate by Script",
        "type": "singlestat",
        "targets": [
          {
            "expr": "script_success_rate",
            "legendFormat": "{{script}}"
          }
        ]
      },
      {
        "title": "Error Distribution",
        "type": "piechart",
        "targets": [
          {
            "expr": "increase(script_errors_total[1h])",
            "legendFormat": "{{error_code}}"
          }
        ]
      }
    ]
  }
}
```

---

## Intégration avec des systèmes externes

### Intégration avec des APIs REST

**`lib/api-client.sh`**

```bash
#!/bin/bash

# Client API générique avec retry et gestion d'erreurs

api_call() {
    local method=$1
    local endpoint=$2
    local data=${3:-}
    local headers=${4:-}
    
    local url="${API_BASE_URL}${endpoint}"
    local curl_opts=()
    
    curl_opts+=("-X" "$method")
    curl_opts+=("-H" "Content-Type: application/json")
    curl_opts+=("--max-time" "${API_TIMEOUT:-30}")
    curl_opts+=("--retry" "${API_RETRY_ATTEMPTS:-3}")
    curl_opts+=("--silent" "--show-error")
    
    if [[ -n "$headers" ]]; then
        while read -r header; do
            curl_opts+=("-H" "$header")
        done <<< "$headers"
    fi
    
    if [[ -n "$data" ]]; then
        curl_opts+=("-d" "$data")
    fi
    
    local response
    local http_code
    
    response=$(curl "${curl_opts[@]}" -w "\n%{http_code}" "$url")
    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | head -n -1)
    
    case $http_code in
        200|201|202)
            echo "$response"
            return 0
            ;;
        4*)
            log_error "API client error (HTTP $http_code): $response"
            return $EXIT_ERROR_VALIDATION
            ;;
        5*)
            log_error "API server error (HTTP $http_code): $response"
            return $EXIT_ERROR_GENERAL
            ;;
        *)
            log_error "Unexpected HTTP code: $http_code"
            return $EXIT_ERROR_GENERAL
            ;;
    esac
}

api_get() {
    api_call "GET" "$1" "" "$2"
}

api_post() {
    api_call "POST" "$1" "$2" "$3"
}

api_put() {
    api_call "PUT" "$1" "$2" "$3"
}

api_delete() {
    api_call "DELETE" "$1" "" "$2"
}
```

### Intégration avec bases de données

**`lib/database.sh`**

```bash
#!/bin/bash

# Interface générique pour bases de données

db_execute() {
    local query=$1
    local db_type=${DB_TYPE:-mysql}
    
    case $db_type in
        mysql)
            mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$query"
            ;;
        postgres)
            PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$query"
            ;;
        sqlite)
            sqlite3 "$DB_NAME" "$query"
            ;;
        *)
            log_error "Unsupported database type: $db_type"
            return $EXIT_ERROR_VALIDATION
            ;;
    esac
}

db_query() {
    local query=$1
    local format=${2:-json}
    
    case $format in
        json)
            db_execute "$query" | jq -R -s 'split("\n") | .[:-1] | map(split("\t"))'
            ;;
        csv)
            db_execute "$query" | tr '\t' ','
            ;;
        *)
            db_execute "$query"
            ;;
    esac
}

db_insert_metrics() {
    local table=$1
    local script_name=$2
    local execution_time=$3
    local status=$4
    
    local query="INSERT INTO $table (script_name, execution_time, status, timestamp) VALUES ('$script_name', $execution_time, '$status', NOW())"
    
    db_execute "$query"
}
```

### Notifications

**`lib/notifications.sh`**

```bash
#!/bin/bash

# Système de notifications multi-canal

send_notification() {
    local title=$1
    local message=$2
    local level=${3:-info}
    local channels=${4:-}
    
    if [[ -z "$channels" ]]; then
        channels="${DEFAULT_NOTIFICATION_CHANNELS:-email}"
    fi
    
    for channel in $channels; do
        case $channel in
            slack)
                send_slack_notification "$title" "$message" "$level"
                ;;
            discord)
                send_discord_notification "$title" "$message" "$level"
                ;;
            teams)
                send_teams_notification "$title" "$message" "$level"
                ;;
            email)
                send_email_notification "$title" "$message" "$level"
                ;;
            pagerduty)
                send_pagerduty_alert "$title" "$message" "$level"
                ;;
            *)
                log_warn "Unknown notification channel: $channel"
                ;;
        esac
    done
}

send_slack_notification() {
    local title=$1
    local message=$2
    local level=$3
    
    if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
        log_warn "SLACK_WEBHOOK_URL not configured"
        return 1
    fi
    
    local color="good"
    case $level in
        error|critical)
            color="danger"
            ;;
        warning)
            color="warning"
            ;;
    esac
    
    local payload=$(cat <<EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "$title",
            "text": "$message",
            "footer": "Scripts Monitoring",
            "ts": $(date +%s)
        }
    ]
}
EOF
)
    
    curl -X POST -H 'Content-type: application/json' \
         --data "$payload" \
         "$SLACK_WEBHOOK_URL"
}

send_email_notification() {
    local title=$1
    local message=$2
    local level=$3
    
    if [[ -z "${NOTIFICATION_EMAIL:-}" ]]; then
        log_warn "NOTIFICATION_EMAIL not configured"
        return 1
    fi
    
    local subject="[$level] $title"
    
    cat <<EOF | sendmail "$NOTIFICATION_EMAIL"
Subject: $subject
From: scripts-monitor@$(hostname)
To: $NOTIFICATION_EMAIL

$message

---
Generated by Scripts Monitoring System
Date: $(date)
Host: $(hostname)
EOF
}

notify_script_failure() {
    local script_name=$1
    local error_code=$2
    local error_message=$3
    
    local title="Script Failure: $script_name"
    local message="Script $script_name failed with exit code $error_code
    
Error: $error_message
Host: $(hostname)
Time: $(date)
    
Please check the logs for more details."
    
    send_notification "$title" "$message" "error"
}

notify_high_error_rate() {
    local script_name=$1
    local error_rate=$2
    
    local title="High Error Rate Alert: $script_name"
    local message="Script $script_name has a high error rate: $error_rate%
    
This may indicate a problem that needs attention.
Please review the script and recent executions."
    
    send_notification "$title" "$message" "warning"
}
```

---

## Déploiement et packaging

### Script d'installation

**`install.sh`**

```bash
#!/bin/bash
#
# Script: install.sh
# Description: Installe le framework de scripts sur le système
# Usage: ./install.sh [INSTALL_DIR]
#

set -euo pipefail

INSTALL_DIR="${1:-/usr/local/scripts-toolkit}"
SERVICE_USER="${SERVICE_USER:-scripts}"
SYSTEMD_SERVICE="${SYSTEMD_SERVICE:-1}"

echo "Installing Scripts Toolkit to $INSTALL_DIR"

# Vérifier les permissions
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Créer les répertoires
mkdir -p "$INSTALL_DIR"/{atomics,orchestrators,lib,tests,docs,logs,monitoring}
mkdir -p /etc/scripts-toolkit
mkdir -p /var/log/scripts-toolkit
mkdir -p /var/cache/scripts-toolkit

# Copier les fichiers
cp -r atomics/* "$INSTALL_DIR/atomics/"
cp -r orchestrators/* "$INSTALL_DIR/orchestrators/" 2>/dev/null || true
cp -r lib/* "$INSTALL_DIR/lib/"
cp -r tests/* "$INSTALL_DIR/tests/" 2>/dev/null || true
cp -r docs/* "$INSTALL_DIR/docs/" 2>/dev/null || true
cp -r monitoring/* "$INSTALL_DIR/monitoring/" 2>/dev/null || true

# Rendre les scripts exécutables
find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \;

# Créer l'utilisateur de service
if ! id "$SERVICE_USER" >/dev/null 2>&1; then
    useradd -r -s /bin/bash -d "$INSTALL_DIR" -c "Scripts Toolkit Service User" "$SERVICE_USER"
fi

# Configuration des permissions
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
chown -R "$SERVICE_USER:$SERVICE_USER" /var/log/scripts-toolkit
chown -R "$SERVICE_USER:$SERVICE_USER" /var/cache/scripts-toolkit

# Configuration système
cat > /etc/profile.d/scripts-toolkit.sh <<EOF
# Scripts Toolkit Configuration
export SCRIPTS_TOOLKIT_HOME="$INSTALL_DIR"
export PATH="\$PATH:$INSTALL_DIR/atomics:$INSTALL_DIR/orchestrators"
export PROJECT_ROOT="$INSTALL_DIR"
EOF

# Configuration par défaut
cat > /etc/scripts-toolkit/config.sh <<EOF
# Scripts Toolkit Default Configuration

# Logging
export LOG_LEVEL=1
export LOG_DIR="/var/log/scripts-toolkit"

# Cache
export CACHE_DIR="/var/cache/scripts-toolkit"
export CACHE_TTL=3600

# Monitoring
export MONITOR_INTERVAL=300
export METRICS_RETENTION_DAYS=30

# Notifications (configure according to your setup)
# export SLACK_WEBHOOK_URL=""
# export NOTIFICATION_EMAIL=""

# Database (if used)
# export DB_TYPE="mysql"
# export DB_HOST="localhost"
# export DB_PORT="3306"
# export DB_NAME="scripts_toolkit"
# export DB_USER="scripts"
# export DB_PASS=""
EOF

# Service systemd pour monitoring
if [[ $SYSTEMD_SERVICE -eq 1 ]]; then
    cat > /etc/systemd/system/scripts-monitor.service <<EOF
[Unit]
Description=Scripts Toolkit Monitoring Service
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
Environment=PROJECT_ROOT=$INSTALL_DIR
ExecStart=$INSTALL_DIR/monitoring/collectors/script-metrics.sh daemon
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable scripts-monitor.service
    
    echo "Systemd service installed: scripts-monitor.service"
    echo "Start with: systemctl start scripts-monitor"
fi

# Créer les liens symboliques pour les commandes principales
ln -sf "$INSTALL_DIR/lib/script-launcher.sh" /usr/local/bin/scripts-toolkit
ln -sf "$INSTALL_DIR/monitoring/collectors/script-metrics.sh" /usr/local/bin/scripts-metrics

echo "Installation completed successfully!"
echo ""
echo "Quick start:"
echo "  1. Source the configuration: source /etc/profile.d/scripts-toolkit.sh"
echo "  2. Edit configuration: nano /etc/scripts-toolkit/config.sh"
echo "  3. Test installation: scripts-toolkit --help"
echo "  4. Run a test script: $INSTALL_DIR/atomics/detect-usb.sh --help"
echo ""
echo "Documentation: $INSTALL_DIR/docs/"
```

### Script de désinstallation

**`uninstall.sh`**

```bash
#!/bin/bash
#
# Script: uninstall.sh
# Description: Désinstalle proprement le framework de scripts
# Usage: ./uninstall.sh [--purge]
#

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/usr/local/scripts-toolkit}"
PURGE_DATA=0

if [[ "${1:-}" == "--purge" ]]; then
    PURGE_DATA=1
    echo "WARNING: This will remove all data, logs, and configuration!"
    read -p "Are you sure? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Uninstall cancelled"
        exit 0
    fi
fi

echo "Uninstalling Scripts Toolkit..."

# Arrêter les services
if systemctl is-active scripts-monitor >/dev/null 2>&1; then
    systemctl stop scripts-monitor
fi

if systemctl is-enabled scripts-monitor >/dev/null 2>&1; then
    systemctl disable scripts-monitor
fi

# Supprimer les fichiers systemd
rm -f /etc/systemd/system/scripts-monitor.service
systemctl daemon-reload

# Supprimer les liens symboliques
rm -f /usr/local/bin/scripts-toolkit
rm -f /usr/local/bin/scripts-metrics

# Supprimer les fichiers de configuration système
rm -f /etc/profile.d/scripts-toolkit.sh

# Supprimer le répertoire d'installation
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    echo "Removed: $INSTALL_DIR"
fi

if [[ $PURGE_DATA -eq 1 ]]; then
    # Supprimer toutes les données
    rm -rf /etc/scripts-toolkit
    rm -rf /var/log/scripts-toolkit
    rm -rf /var/cache/scripts-toolkit
    echo "Purged: all data and logs"
    
    # Supprimer l'utilisateur de service
    if id scripts >/dev/null 2>&1; then
        userdel -r scripts 2>/dev/null || true
        echo "Removed: service user 'scripts'"
    fi
fi

echo "Uninstallation completed!"
```

---

## Conclusion et méthodologies avancées

Cette méthodologie complète garantit la création de systèmes de scripts robustes, maintenables et évolutifs. La clé du succès réside dans le respect rigoureux des standards établis et la composition intelligente de briques atomiques simples.

### Principes fondamentaux récapitulatifs

1. **Architecture hiérarchique stricte** : Scripts atomiques → Orchestrateurs multi-niveaux
2. **Standards non-négociables** : JSON, codes de sortie, logging, conventions de nommage
3. **Qualité par construction** : Tests automatiques, validation continue, documentation vivante
4. **Observabilité complète** : Logging, métriques, alertes, dashboards
5. **Sécurité by design** : Validation entrées, audit trail, gestion erreurs
6. **Évolutivité maîtrisée** : Versioning sémantique, CI/CD, déploiement automatisé

### Adoption progressive recommandée

**Phase 1 (Semaine 1-2)** : Fondations
- Mise en place de l'architecture de base
- Création des premiers scripts atomiques
- Implémentation du système de logging

**Phase 2 (Semaine 3-4)** : Consolidation  
- Développement des premiers orchestrateurs
- Tests automatisés complets
- Documentation exhaustive

**Phase 3 (Mois 2)** : Production
- Monitoring et métriques
- CI/CD pipeline
- Système d'alertes

**Phase 4 (Mois 3+)** : Optimisation
- Performance tuning
- Fonctionnalités avancées (cache, parallélisme)
- Intégrations tierces

En suivant cette méthodologie de manière scrupuleuse, vous obtiendrez un système de scripts de qualité industrielle, capable d'évoluer et de s'adapter aux besoins futurs tout en maintenant une robustesse et une fiabilité exemplaires.

La discipline initiale dans l'application de ces standards se traduira par des gains exponentiels en termes de maintenabilité, de debuggabilité et de collaboration d'équipe sur le long terme.
            first=0
        done
        echo "]" >> "$alerts_file"
        
        echo "Alerts generated: $alerts_file (${#alerts[@]} alerts)"
    else
        echo "No alerts detected"
    fi
}

# Dashboard en ligne de commande
show_dashboard() {
    local date=${1:-$(date +%Y-%m-%d)}
    local metrics_file="$METRICS_DIR/metrics-$date.json"
    
    if [[ ! -f "$metrics_file" ]]; then
        echo "No metrics available for $date"
        return 1
    fi
    
    echo "================================"
    echo "Script Metrics Dashboard"
    echo "Date: $date"
    echo "================================"
    echo ""
    
    # Vue d'ensemble
    local total_exec=$(jq '[.[] | .execution_count] | add' "$metrics_file")
    local total_success=$(jq '[.[] | .success_count] | add' "$metrics_file")
    local total_errors=$(jq '[.[] | .error_count] | add' "$metrics_file")
    local overall_rate=$(echo "scale=2; ($total_success / $total_exec) * 100" | bc)
    
    echo "Overview:"
    echo "  Total Executions: $total_exec"
    echo "  Successful: $total_success"
    echo "  Errors: $total_errors"
    echo "  Success Rate: ${overall_rate}%"
    echo ""
    
    # Top 5 scripts les plus exécutés
    echo "Top 5 Most Executed Scripts:"
    jq -r '.[] | "\(.script_name): \(.execution_count) executions"' "$metrics_file" | \
        sort -t':' -k2 -rn | head -5 | nl
    echo ""
    
    # Scripts avec le plus d'erreurs
    echo "Scripts with Most Errors:"
    jq -r '.[] | select(.error_count > 0) | "\(.script_name): \(.error_count) errors (\(.success_rate)%)"' "$metrics_file" | \
        sort -t':' -k2 -rn | head -5 | nl
    echo ""
    
    # Alertes récentes
    local alerts_file="$METRICS_DIR/alerts-$date.json"
    if [[ -f "$alerts_file" ]]; then
        local alert_count=$(jq 'length' "$alerts_file")
        echo "Active Alerts: $alert_count"
        if [[ $alert_count -gt 0 ]]; then
            jq -r '.[] | "  [\(.level | ascii_upcase)] \(.script): \(.message)"' "$alerts_file"
        fi
    fi
    
    echo ""
    echo "================================"
}

# Exportation vers InfluxDB
export_to_influxdb() {
    local date=${1:-$(date +%Y-%m-%d)}
    local metrics_file="$METRICS_DIR/metrics-$date.json"
    local influx_url=${INFLUXDB_URL:-"http://localhost:8086"}
    local influx_db=${INFLUXDB_DB:-"scripts_metrics"}
    
    if [[ ! -f "$metrics_file" ]]; then
        echo "No metrics available for $date"
        return 1
    fi
    
    # Convertir JSON en format InfluxDB Line Protocol
    while read -r line; do
        local script_name=$(echo "$line" | jq -r '.script_name')
        local exec_count=$(echo "$line" | jq -r '.execution_count')
        local success_count=$(echo "$line" | jq -r '.success_count')
        local error_count=$(echo "$line" | jq -r '.error_count')
        local success_rate=$(echo "$line" | jq -r '.success_rate')
        local timestamp=$(date -d "$date" +%s)000000000
        
        # Format InfluxDB Line Protocol
        echo "script_executions,script=$script_name count=$exec_count $timestamp"
        echo "script_successes,script=$script_name count=$success_count $timestamp"
        echo "script_errors,script=$script_name count=$error_count $timestamp"
        echo "script_success_rate,script=$script_name rate=$success_rate $timestamp"
    done < <(jq -c '.[]' "$metrics_file") | \
        curl -XPOST "$influx_url/write?db=$influx_db" --data-binary @-
    
    echo "Metrics exported to InfluxDB"
}

# Point d'entrée
case ${1:-collect} in
    collect)
        collect_all_metrics "${2:-}"
        ;;
    prometheus)
        generate_prometheus_metrics
        ;;
    anomalies)
        detect_anomalies "${2:-}"
        ;;
    dashboard)
        show_dashboard "${2:-}"
        ;;
    influxdb)
        export_to_influxdb "${2:-}"
        ;;
    *)
        echo "Usage: $0 {collect|prometheus|anomalies|dashboard|influxdb} [date]"
        exit 1
        ;;
esac
```

### Configuration Prometheus

**`monitoring/dashboards/prometheus-config.yml`**

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'script_metrics'
    static_configs:
      - targets: ['localhost:9090']
    file_sd_configs:
      - files:
          - '/path/to/project/monitoring/metrics/prometheus-metrics.txt'
        refresh_interval: 60s

rule_files:
  - '/path/to/project/monitoring/alerts/alert-rules.yml'

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - 'localhost:9093'
```

### Règles d'alerte

**`monitoring/alerts/alert-rules.yml`**

```yaml
groups:
  - name: script_alerts
    interval: 30s
    rules:
      # Alerte si le taux de succès est inférieur à 90%
      - alert: LowSuccessRate
        expr: script_success_rate < 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low success rate for {{ $labels.script }}"
          description: "Script {{ $labels.script }} has a success rate of {{ $value }}% (threshold: 90%)"
      
      # Alerte si le taux de succès est inférieur à 50%
      - alert: CriticalSuccessRate
        expr: script_success_rate < 50
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Critical success rate for {{ $labels.script }}"
          description: "Script {{ $labels.script }} has a critical success rate of {{ $value }}% (threshold: 50%)"
      
      # Alerte si un script n'a pas été exécuté depuis 24h
      - alert: ScriptNotExecuted
        expr: time() - script_last_execution_timestamp > 86400
        for: 1h
        labels:
          severity: info
        annotations:
          summary: "Script {{ $labels.script }} not executed recently"
          description: "Script {{ $labels.script }} has not been executed in the last 24 hours"
      
      # Alerte si le nombre d'erreurs augmente rapidement
      - alert: ErrorRateIncreasing
        expr: rate(script_errors[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Error rate increasing for {{ $labels.script }}"
          description: "Script {{ $labels.script }} error rate is increasing: {{ $value }} errors/sec"
```

### Dashboard Grafana

**`monitoring/dashboards/grafana-dashboard.json`**

```json
{
  "dashboard": {
    "title": "Scripts Monitoring Dashboard",
    "panels": [
      {
        "id": 1,
        "title": "Overall Success Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "avg(script_success_rate)",
            "legendFormat": "Success Rate"
          }
        ]
      },
      {
        "id": 2,
        "title": "Script Executions Over Time",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(script_executions_total[5m])) by (script)",
            "legendFormat": "{{ script }}"
          }
        ]
      },
      {
        "id": 3,
        "title": "Error Rate by Script",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(script_errors[5m])) by (script)",
            "legendFormat": "{{ script }}"
          }
        ]
      },
      {
        "id": 4,
        "title": "Top 10 Most Executed Scripts",
        "type": "bargauge",
        "targets": [
          {
            "expr": "topk(10, script_executions_total)",
            "legendFormat": "{{ script }}"
          }
        ]
      },
      {
        "id": 5,
        "title": "Scripts with Lowest Success Rate",
        "type": "table",
        "targets": [
          {
            "expr": "bottomk(10, script_success_rate)",
            "format": "table"
          }
        ]
      }
    ]
  }
}
```

### Script de monitoring continu

**`monitoring/monitor-daemon.sh`**

```bash
#!/bin/bash
#
# Script: monitor-daemon.sh
# Description: Daemon de monitoring continu des scripts
# Usage: monitor-daemon.sh start|stop|status
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PID_FILE="/var/run/script-monitor.pid"
INTERVAL=${MONITOR_INTERVAL:-300}  # 5 minutes par défaut

start_monitoring() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Monitor is already running (PID: $pid)"
            return 1
        fi
    fi
    
    echo "Starting monitoring daemon..."
    
    # Démarrage en arrière-plan
    (
        while true; do
            # Collecte des métriques
            "$SCRIPT_DIR/collectors/script-metrics.sh" collect
            
            # Génération des métriques Prometheus
            "$SCRIPT_DIR/collectors/script-metrics.sh" prometheus
            
            # Détection des anomalies
            "$SCRIPT_DIR/collectors/script-metrics.sh" anomalies
            
            # Attente avant la prochaine collecte
            sleep "$INTERVAL"
        done
    ) &
    
    echo $! > "$PID_FILE"
    echo "Monitor started (PID: $!)"
}

stop_monitoring() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "Monitor is not running"
        return 1
    fi
    
    local pid=$(cat "$PID_FILE")
    
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "Stopping monitor (PID: $pid)..."
        kill "$pid"
        rm "$PID_FILE"
        echo "Monitor stopped"
    else
        echo "Monitor is not running (stale PID file)"
        rm "$PID_FILE"
    fi
}

status_monitoring() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "Monitor is not running"
        return 1
    fi
    
    local pid=$(cat "$PID_FILE")
    
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "Monitor is running (PID: $pid)"
        
        # Afficher les dernières métriques
        "$SCRIPT_DIR/collectors/script-metrics.sh" dashboard
    else
        echo "Monitor is not running (stale PID file)"
        rm "$PID_FILE"
        return 1
    fi
}

case ${1:-status} in
    start)
        start_monitoring
        ;;
    stop)
        stop_monitoring
        ;;
    restart)
        stop_monitoring
        sleep 2
        start_monitoring
        ;;
    status)
        status_monitoring
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
```

### Installation du système de monitoring

**`monitoring/install-monitoring.sh`**

```bash
#!/bin/bash
#
# Script: install-monitoring.sh
# Description: Installe et configure le système de monitoring
#

set -euo pipefail

echo "Installing monitoring system..."

# Installation des dépendances
echo "Installing dependencies..."
apt-get update
apt-get install -y jq bc prometheus grafana influxdb

# Configuration de Prometheus
echo "Configuring Prometheus..."
cp monitoring/dashboards/prometheus-config.yml /etc/prometheus/prometheus.yml
cp monitoring/alerts/alert-rules.yml /etc/prometheus/rules/

# Configuration de Grafana
echo "Configuring Grafana..."
systemctl enable grafana-server
systemctl start grafana-server

# Import du dashboard
sleep 5  # Attendre que Grafana soit prêt
curl -X POST -H "Content-Type: application/json" \
     -d @monitoring/dashboards/grafana-dashboard.json \
     http://admin:admin@localhost:3000/api/dashboards/db

# Configuration du daemon de monitoring
echo "Setting up monitoring daemon..."
chmod +x monitoring/monitor-daemon.sh
cp monitoring/monitor-daemon.sh /usr/local/bin/script-monitor

# Création du service systemd
cat > /etc/systemd/system/script-monitor.service <<EOF
[Unit]
Description=Script Monitoring Daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/script-monitor start
ExecStop=/usr/local/bin/script-monitor stop
PIDFile=/var/run/script-monitor.pid
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable script-monitor
systemctl start script-monitor

echo "Monitoring system installed successfully!"
echo ""
echo "Access points:"
echo "  - Prometheus: http://localhost:9090"
echo "  - Grafana: http://localhost:3000 (admin/admin)"
echo "  - CLI Dashboard: script-monitor status"
```

---

## Conclusion finale

Cette méthodologie complète fournit un cadre robuste pour le développement, le déploiement et la maintenance de scripts modulaires et hiérarchiques. En combinant :

- **Architecture modulaire** avec fonctions atomiques et orchestrateurs
- **Standards rigoureux** de codage, documentation et tests
- **CI/CD automatisé** pour validation continue
- **Versioning sémantique** avec génération automatique de changelog
- **Monitoring complet** avec métriques, alertes et dashboards

Vous disposez d'un système évolutif capable de gérer des workflows complexes tout en maintenant une qualité et une fiabilité élevées. Chaque nouveau script s'appuie sur une fondation solide et prouvée, permettant de construire des systèmes de plus en plus sophistiqués sans dette technique.
        sed -n '/^