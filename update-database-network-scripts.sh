#!/usr/bin/env bash

# ==============================================================================
# Script Utilitaire: update-database-network-scripts.sh
# Description: Mise à jour de la base de données SQLite avec les nouveaux scripts réseau
# Author: Generated with AtomicOps-Suite AI assistance
# Version: 1.0
# Date: 2025-10-04
# Dependencies: sqlite3, jq
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="update-database-network-scripts.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}

# Configuration de la base de données
DATABASE_FILE="${DATABASE_FILE:-catalogue-scripts.db}"
ATOMICS_DIR="${ATOMICS_DIR:-atomics/network}"
ORCHESTRATORS_DIR="${ORCHESTRATORS_DIR:-orchestrators/network}"

# Statistiques
TOTAL_SCRIPTS=0
SCRIPTS_ADDED=0
SCRIPTS_UPDATED=0
SCRIPTS_ERRORS=0

# =============================================================================
# Fonctions Utilitaires
# =============================================================================

log_debug() {
    [[ $DEBUG -eq 0 ]] && return 0
    echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

die() {
    log_error "$1"
    exit "${2:-1}"
}

# =============================================================================
# Fonctions de Base de Données
# =============================================================================

# Initialisation de la base de données
init_database() {
    log_info "Initialisation de la base de données: $DATABASE_FILE"
    
    # Création de la table des scripts si elle n'existe pas
    sqlite3 "$DATABASE_FILE" << 'EOF'
CREATE TABLE IF NOT EXISTS scripts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL,  -- 'atomic' ou 'orchestrator'
    category TEXT NOT NULL,  -- 'network', 'storage', 'system', etc.
    protocol TEXT,  -- 'ssh', 'ftp', 'http', 'scp' pour les scripts réseau
    level INTEGER NOT NULL,  -- 0 pour atomique, 1 pour orchestrateur, etc.
    file_path TEXT NOT NULL,
    description TEXT,
    parameters TEXT,  -- JSON des paramètres
    dependencies TEXT,  -- JSON des dépendances
    examples TEXT,  -- JSON des exemples
    version TEXT,
    date_created TEXT,
    date_updated TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS script_tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER,
    tag TEXT NOT NULL,
    FOREIGN KEY (script_id) REFERENCES scripts (id),
    UNIQUE(script_id, tag)
);

CREATE TABLE IF NOT EXISTS script_relationships (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_script_id INTEGER,
    child_script_id INTEGER,
    relationship_type TEXT,  -- 'uses', 'depends_on', 'orchestrates'
    FOREIGN KEY (parent_script_id) REFERENCES scripts (id),
    FOREIGN KEY (child_script_id) REFERENCES scripts (id)
);

CREATE INDEX IF NOT EXISTS idx_scripts_type ON scripts(type);
CREATE INDEX IF NOT EXISTS idx_scripts_category ON scripts(category);
CREATE INDEX IF NOT EXISTS idx_scripts_protocol ON scripts(protocol);
CREATE INDEX IF NOT EXISTS idx_script_tags_tag ON script_tags(tag);
EOF

    log_info "Base de données initialisée avec succès"
}

# Extraction des métadonnées d'un script
extract_script_metadata() {
    local script_file="$1"
    local script_name=$(basename "$script_file" .sh)
    local metadata_json=""
    
    log_debug "Extraction des métadonnées de: $script_file"
    
    # Vérification de l'existence du fichier
    if [[ ! -f "$script_file" ]]; then
        log_warn "Fichier non trouvé: $script_file"
        return 1
    fi
    
    # Extraction des informations du header
    local description=$(grep "^# Description:" "$script_file" | head -1 | cut -d: -f2- | sed 's/^ *//')
    local version=$(grep "^# Version:" "$script_file" | head -1 | cut -d: -f2- | sed 's/^ *//')
    local date_created=$(grep "^# Date:" "$script_file" | head -1 | cut -d: -f2- | sed 's/^ *//')
    local dependencies=$(grep "^# Dependencies:" "$script_file" | head -1 | cut -d: -f2- | sed 's/^ *//')
    local level=$(grep "^# Level:" "$script_file" | head -1 | cut -d: -f2- | sed 's/^ *//' | grep -o '[0-9]')
    
    # Détermination du type et de la catégorie
    local type=""
    local category="network"
    local protocol=""
    
    if [[ "$script_file" == *"/atomics/"* ]]; then
        type="atomic"
        level="${level:-0}"
    elif [[ "$script_file" == *"/orchestrators/"* ]]; then
        type="orchestrator"
        level="${level:-1}"
    fi
    
    # Détermination du protocole depuis le nom du script
    case "$script_name" in
        ssh-*) protocol="ssh" ;;
        ftp-*) protocol="ftp" ;;
        http-*) protocol="http" ;;
        scp-*) protocol="scp" ;;
        network-*) protocol="multi" ;;
        *) protocol="unknown" ;;
    esac
    
    # Extraction des paramètres depuis l'aide
    local parameters=""
    if command -v bash >/dev/null 2>&1; then
        local help_output=""
        if help_output=$(bash "$script_file" --help 2>/dev/null | grep -A 20 "Arguments obligatoires:" | grep -B 20 "Options:" || true); then
            parameters="$help_output"
        fi
    fi
    
    # Construction du JSON des métadonnées
    metadata_json=$(jq -n \
        --arg name "$script_name" \
        --arg type "$type" \
        --arg category "$category" \
        --arg protocol "$protocol" \
        --arg level "$level" \
        --arg file_path "$script_file" \
        --arg description "$description" \
        --arg version "$version" \
        --arg date_created "$date_created" \
        --arg dependencies "$dependencies" \
        --arg parameters "$parameters" \
        '{
            name: $name,
            type: $type,
            category: $category,
            protocol: $protocol,
            level: ($level | tonumber),
            file_path: $file_path,
            description: $description,
            version: $version,
            date_created: $date_created,
            dependencies: $dependencies,
            parameters: $parameters
        }')
    
    echo "$metadata_json"
    return 0
}

# Insertion ou mise à jour d'un script dans la base
upsert_script() {
    local metadata_json="$1"
    
    local name=$(echo "$metadata_json" | jq -r '.name')
    local type=$(echo "$metadata_json" | jq -r '.type')
    local category=$(echo "$metadata_json" | jq -r '.category')
    local protocol=$(echo "$metadata_json" | jq -r '.protocol')
    local level=$(echo "$metadata_json" | jq -r '.level')
    local file_path=$(echo "$metadata_json" | jq -r '.file_path')
    local description=$(echo "$metadata_json" | jq -r '.description')
    local version=$(echo "$metadata_json" | jq -r '.version')
    local date_created=$(echo "$metadata_json" | jq -r '.date_created')
    local dependencies=$(echo "$metadata_json" | jq -r '.dependencies')
    local parameters=$(echo "$metadata_json" | jq -r '.parameters')
    
    log_debug "Insertion/mise à jour de: $name"
    
    # Échapper les guillemets et caractères spéciaux pour SQL
    local safe_description=$(echo "$description" | sed "s/'/''/g")
    local safe_dependencies=$(echo "$dependencies" | sed "s/'/''/g")
    local safe_parameters=$(echo "$parameters" | sed "s/'/''/g")
    local safe_file_path=$(echo "$file_path" | sed "s/'/''/g")
    
    # Vérifier si le script existe déjà
    local existing_id=$(sqlite3 "$DATABASE_FILE" \
        "SELECT id FROM scripts WHERE name = '$name';")
    
    if [[ -n "$existing_id" ]]; then
        # Mise à jour
        sqlite3 "$DATABASE_FILE" << EOF
UPDATE scripts SET
    type = '$type',
    category = '$category',
    protocol = '$protocol',
    level = $level,
    file_path = '$safe_file_path',
    description = '$safe_description',
    version = '$version',
    date_created = '$date_created',
    dependencies = '$safe_dependencies',
    parameters = '$safe_parameters',
    date_updated = datetime('now')
WHERE name = '$name';
EOF
        SCRIPTS_UPDATED=$((SCRIPTS_UPDATED + 1))
        log_info "Script mis à jour: $name (ID: $existing_id)"
    else
        # Insertion
        sqlite3 "$DATABASE_FILE" << EOF
INSERT INTO scripts (
    name, type, category, protocol, level, file_path,
    description, version, date_created, dependencies, parameters
) VALUES (
    '$name', '$type', '$category', '$protocol', $level, '$safe_file_path',
    '$safe_description', '$version', '$date_created', '$safe_dependencies', '$safe_parameters'
);
EOF
        local new_id=$(sqlite3 "$DATABASE_FILE" \
            "SELECT last_insert_rowid();")
        SCRIPTS_ADDED=$((SCRIPTS_ADDED + 1))
        log_info "Script ajouté: $name (ID: $new_id)"
    fi
}

# Ajout de tags pour un script
add_script_tags() {
    local script_name="$1"
    shift
    local tags=("$@")
    
    local script_id=$(sqlite3 "$DATABASE_FILE" \
        "SELECT id FROM scripts WHERE name = '$script_name';")
    
    if [[ -z "$script_id" ]]; then
        log_warn "Script non trouvé pour les tags: $script_name"
        return 1
    fi
    
    for tag in "${tags[@]}"; do
        sqlite3 "$DATABASE_FILE" \
            "INSERT OR IGNORE INTO script_tags (script_id, tag) VALUES ($script_id, '$tag');" \
            2>/dev/null || true
        log_debug "Tag ajouté: $tag -> $script_name"
    done
}

# =============================================================================
# Traitement des Scripts Réseau
# =============================================================================

# Traitement des scripts atomiques
process_atomic_scripts() {
    log_info "Traitement des scripts atomiques réseau..."
    
    if [[ ! -d "$ATOMICS_DIR" ]]; then
        log_warn "Répertoire atomiques non trouvé: $ATOMICS_DIR"
        return 0
    fi
    
    local atomic_scripts=()
    while IFS= read -r -d '' script; do
        atomic_scripts+=("$script")
    done < <(find "$ATOMICS_DIR" -name "*.sh" -type f -print0)
    
    for script_file in "${atomic_scripts[@]}"; do
        local script_name=$(basename "$script_file" .sh)
        log_info "Traitement atomique: $script_name"
        
        local metadata=""
        if metadata=$(extract_script_metadata "$script_file"); then
            upsert_script "$metadata"
            
            # Ajout de tags spécifiques
            local tags=("atomic" "network")
            case "$script_name" in
                ssh-*) tags+=("ssh" "connection" "remote") ;;
                ftp-*) tags+=("ftp" "transfer" "upload" "download") ;;
                http-*) tags+=("http" "https" "web" "api") ;;
                scp-*) tags+=("scp" "transfer" "secure") ;;
            esac
            
            add_script_tags "$script_name" "${tags[@]}"
            TOTAL_SCRIPTS=$((TOTAL_SCRIPTS + 1))
        else
            log_error "Erreur lors du traitement de: $script_file"
            SCRIPTS_ERRORS=$((SCRIPTS_ERRORS + 1))
        fi
    done
}

# Traitement des orchestrateurs
process_orchestrator_scripts() {
    log_info "Traitement des orchestrateurs réseau..."
    
    if [[ ! -d "$ORCHESTRATORS_DIR" ]]; then
        log_warn "Répertoire orchestrateurs non trouvé: $ORCHESTRATORS_DIR"
        return 0
    fi
    
    local orchestrator_scripts=()
    while IFS= read -r -d '' script; do
        orchestrator_scripts+=("$script")
    done < <(find "$ORCHESTRATORS_DIR" -name "*.sh" -type f -print0)
    
    for script_file in "${orchestrator_scripts[@]}"; do
        local script_name=$(basename "$script_file" .sh)
        log_info "Traitement orchestrateur: $script_name"
        
        local metadata=""
        if metadata=$(extract_script_metadata "$script_file"); then
            upsert_script "$metadata"
            
            # Ajout de tags spécifiques
            local tags=("orchestrator" "network" "workflow")
            case "$script_name" in
                network-setup-deployment) 
                    tags+=("deployment" "ssh" "scp" "http" "automated") ;;
                network-secure-connection) 
                    tags+=("security" "connection" "multi-protocol" "validation") ;;
            esac
            
            add_script_tags "$script_name" "${tags[@]}"
            TOTAL_SCRIPTS=$((TOTAL_SCRIPTS + 1))
        else
            log_error "Erreur lors du traitement de: $script_file"
            SCRIPTS_ERRORS=$((SCRIPTS_ERRORS + 1))
        fi
    done
}

# Création des relations entre scripts
create_script_relationships() {
    log_info "Création des relations entre scripts..."
    
    # Relations orchestrateurs -> atomiques
    local deployment_id=$(sqlite3 "$DATABASE_FILE" \
        "SELECT id FROM scripts WHERE name = 'network-setup-deployment';")
    local secure_connection_id=$(sqlite3 "$DATABASE_FILE" \
        "SELECT id FROM scripts WHERE name = 'network-secure-connection';")
    
    # Scripts atomiques utilisés
    local atomic_scripts=(
        "ssh-connect" "ssh-execute-command" "scp-transfer" "http-request"
    )
    
    for atomic_name in "${atomic_scripts[@]}"; do
        local atomic_id=$(sqlite3 "$DATABASE_FILE" \
            "SELECT id FROM scripts WHERE name = '$atomic_name';")
        
        if [[ -n "$deployment_id" ]] && [[ -n "$atomic_id" ]]; then
            sqlite3 "$DATABASE_FILE" \
                "INSERT OR IGNORE INTO script_relationships (parent_script_id, child_script_id, relationship_type) VALUES ($deployment_id, $atomic_id, 'uses');" \
                2>/dev/null || true
        fi
        
        if [[ -n "$secure_connection_id" ]] && [[ -n "$atomic_id" ]]; then
            sqlite3 "$DATABASE_FILE" \
                "INSERT OR IGNORE INTO script_relationships (parent_script_id, child_script_id, relationship_type) VALUES ($secure_connection_id, $atomic_id, 'uses');" \
                2>/dev/null || true
        fi
    done
    
    log_info "Relations créées avec succès"
}

# =============================================================================
# Fonction de Rapport
# =============================================================================

generate_report() {
    log_info "=== RAPPORT DE MISE À JOUR BASE DE DONNÉES ==="
    log_info "Scripts traités: $TOTAL_SCRIPTS"
    log_info "Scripts ajoutés: $SCRIPTS_ADDED"
    log_info "Scripts mis à jour: $SCRIPTS_UPDATED"
    log_info "Erreurs: $SCRIPTS_ERRORS"
    
    # Statistiques de la base
    local total_db_scripts=$(sqlite3 "$DATABASE_FILE" \
        "SELECT COUNT(*) FROM scripts;")
    local network_scripts=$(sqlite3 "$DATABASE_FILE" \
        "SELECT COUNT(*) FROM scripts WHERE category = 'network';")
    local atomic_count=$(sqlite3 "$DATABASE_FILE" \
        "SELECT COUNT(*) FROM scripts WHERE type = 'atomic' AND category = 'network';")
    local orchestrator_count=$(sqlite3 "$DATABASE_FILE" \
        "SELECT COUNT(*) FROM scripts WHERE type = 'orchestrator' AND category = 'network';")
    
    log_info "--- STATISTIQUES BASE DE DONNÉES ---"
    log_info "Total scripts en base: $total_db_scripts"
    log_info "Scripts réseau: $network_scripts"
    log_info "Scripts atomiques réseau: $atomic_count"
    log_info "Orchestrateurs réseau: $orchestrator_count"
    
    # Affichage des scripts par protocole
    log_info "--- RÉPARTITION PAR PROTOCOLE ---"
    sqlite3 "$DATABASE_FILE" \
        "SELECT protocol, COUNT(*) as count FROM scripts WHERE category = 'network' GROUP BY protocol ORDER BY count DESC;" | \
        while IFS='|' read -r protocol count; do
            log_info "  $protocol: $count scripts"
        done
}

# =============================================================================
# Point d'Entrée Principal
# =============================================================================

show_help() {
    cat << 'EOF'
Usage: update-database-network-scripts.sh [OPTIONS]

Description:
    Met à jour la base de données SQLite avec les métadonnées des scripts réseau.
    Analyse les scripts atomiques et orchestrateurs pour extraire leurs informations
    et les intégrer dans le catalogue de scripts.

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux
    -d, --debug            Mode debug
    --database <file>      Fichier de base de données (défaut: catalogue-scripts.db)
    --atomics-dir <dir>    Répertoire des scripts atomiques (défaut: atomics/network)
    --orchestrators-dir <dir> Répertoire des orchestrateurs (défaut: orchestrators/network)

Variables d'environnement:
    DATABASE_FILE          Fichier de base de données SQLite
    ATOMICS_DIR           Répertoire des scripts atomiques
    ORCHESTRATORS_DIR     Répertoire des orchestrateurs

Exemples:
    # Mise à jour standard
    ./update-database-network-scripts.sh

    # Avec base de données personnalisée
    ./update-database-network-scripts.sh --database /path/to/custom.db

    # Mode debug avec répertoires spécifiques
    ./update-database-network-scripts.sh --debug \
        --atomics-dir ./custom/atomics \
        --orchestrators-dir ./custom/orchestrators
EOF
}

main() {
    # Parse des arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=1
                ;;
            -d|--debug)
                DEBUG=1
                VERBOSE=1
                ;;
            --database)
                [[ -z "${2:-}" ]] && die "Option --database nécessite une valeur" 1
                DATABASE_FILE="$2"
                shift
                ;;
            --atomics-dir)
                [[ -z "${2:-}" ]] && die "Option --atomics-dir nécessite une valeur" 1
                ATOMICS_DIR="$2"
                shift
                ;;
            --orchestrators-dir)
                [[ -z "${2:-}" ]] && die "Option --orchestrators-dir nécessite une valeur" 1
                ORCHESTRATORS_DIR="$2"
                shift
                ;;
            -*)
                die "Option inconnue: $1" 1
                ;;
            *)
                die "Argument non attendu: $1" 1
                ;;
        esac
        shift
    done
    
    # Vérification des prérequis
    if ! command -v sqlite3 >/dev/null 2>&1; then
        die "sqlite3 non disponible (requis pour la base de données)" 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        die "jq non disponible (requis pour le parsing JSON)" 1
    fi
    
    log_info "Démarrage de la mise à jour de la base de données réseau"
    log_info "Base de données: $DATABASE_FILE"
    log_info "Répertoire atomiques: $ATOMICS_DIR"
    log_info "Répertoire orchestrateurs: $ORCHESTRATORS_DIR"
    
    # Initialisation de la base
    init_database
    
    # Traitement des scripts
    process_atomic_scripts
    process_orchestrator_scripts
    
    # Création des relations
    create_script_relationships
    
    # Génération du rapport
    generate_report
    
    log_info "Mise à jour de la base de données terminée avec succès"
}

# Exécution du script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi