#!/bin/bash
#
# Script: register-script.sh
# Description: Enregistre un script dans la base de données du catalogue
# Usage: ./register-script.sh <script_path> [--auto]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"

# Import des bibliothèques
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"

# Variables globales
AUTO_MODE=0
SCRIPT_PATH=""

# Fonction d'aide
show_help() {
    cat <<EOF
Usage: $0 <script_path> [OPTIONS]

Enregistre un script dans le catalogue de la base de données

Arguments:
  script_path        Chemin vers le script à enregistrer

Options:
  -h, --help         Affiche cette aide
  -a, --auto         Mode automatique (pas d'interaction)

Exemples:
  $0 atomics/create-ct.sh
  $0 orchestrators/level-1/setup-env.sh --auto
  $0 lib/common.sh

EOF
}

# Parsing des arguments
parse_args() {
    if [[ $# -lt 1 ]]; then
        log_error "Chemin du script requis"
        show_help >&2
        exit $EXIT_ERROR_USAGE
    fi
    
    SCRIPT_PATH="$1"
    shift
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit $EXIT_SUCCESS
                ;;
            -a|--auto)
                AUTO_MODE=1
                shift
                ;;
            *)
                log_error "Option inconnue: $1"
                show_help >&2
                exit $EXIT_ERROR_USAGE
                ;;
        esac
    done
}

# Validation des prérequis
validate_prerequisites() {
    log_debug "Validation des prérequis"
    
    # Vérifier SQLite3
    if ! command -v sqlite3 >/dev/null 2>&1; then
        log_error "sqlite3 n'est pas installé"
        exit $EXIT_ERROR_DEPENDENCY
    fi
    
    # Vérifier que la base existe
    if [[ ! -f "$DB_FILE" ]]; then
        log_error "Base de données non trouvée: $DB_FILE"
        log_info "Initialisez la base: $PROJECT_ROOT/database/init-db.sh"
        exit $EXIT_ERROR_NOT_FOUND
    fi
    
    # Vérifier le fichier script
    if [[ ! -f "$PROJECT_ROOT/$SCRIPT_PATH" ]]; then
        log_error "Script non trouvé: $PROJECT_ROOT/$SCRIPT_PATH"
        exit $EXIT_ERROR_NOT_FOUND
    fi
    
    log_debug "Prérequis validés"
}

# Extraire les informations du script
extract_script_info() {
    local script_file="$PROJECT_ROOT/$SCRIPT_PATH"
    local script_name=$(basename "$SCRIPT_PATH")
    
    log_info "📝 Extraction des informations du script: $script_name"
    
    # Déterminer le type
    local script_type="atomic"  # Par défaut
    if [[ "$SCRIPT_PATH" =~ orchestrators/level-([0-9]+)/ ]]; then
        script_type="orchestrator-${BASH_REMATCH[1]}"
    elif [[ "$SCRIPT_PATH" =~ lib/ ]]; then
        script_type="library"
    fi
    
    # Déterminer la catégorie depuis le chemin
    local category="general"
    if [[ "$SCRIPT_PATH" =~ atomics/ ]]; then
        category="atomic"
    elif [[ "$SCRIPT_PATH" =~ orchestrators/ ]]; then
        category="orchestration"
    elif [[ "$SCRIPT_PATH" =~ lib/ ]]; then
        category="library"
    elif [[ "$SCRIPT_PATH" =~ tools/ ]]; then
        category="development"
    fi
    
    # Extraire description du header
    local description=""
    if [[ -f "$script_file" ]]; then
        description=$(grep -m 1 "^# Description:" "$script_file" 2>/dev/null | sed 's/^# Description: *//' || echo "")
        if [[ -z "$description" ]]; then
            description=$(head -10 "$script_file" | grep -m 1 "^#.*" | sed 's/^# *//' || echo "Script sans description")
        fi
    fi
    
    # Extraire l'auteur
    local author=""
    author=$(grep -m 1 "^# Author:" "$script_file" 2>/dev/null | sed 's/^# Author: *//' || echo "")
    
    # Extraire la version
    local version="1.0.0"
    version=$(grep -m 1 "^# Version:" "$script_file" 2>/dev/null | sed 's/^# Version: *//' || echo "1.0.0")
    
    echo "script_name=$script_name"
    echo "script_type=$script_type"  
    echo "category=$category"
    echo "description=$description"
    echo "author=$author"
    echo "version=$version"
}

# Demander confirmation ou informations complémentaires
prompt_for_info() {
    local script_info
    script_info=$(extract_script_info)
    
    eval "$script_info"  # Charge les variables
    
    if [[ $AUTO_MODE -eq 1 ]]; then
        log_info "Mode automatique - utilisation des informations extraites"
        return 0
    fi
    
    echo ""
    echo "📋 Informations extraites du script:"
    echo "  Nom: $script_name"
    echo "  Type: $script_type"
    echo "  Catégorie: $category"
    echo "  Description: $description"
    echo "  Auteur: $author"
    echo "  Version: $version"
    
    echo ""
    read -p "Confirmer ces informations ? (o/N): " confirm
    
    if [[ "$confirm" != "o" && "$confirm" != "O" ]]; then
        echo ""
        echo "Saisie manuelle des informations:"
        
        read -p "Type [$script_type]: " new_type
        [[ -n "$new_type" ]] && script_type="$new_type"
        
        read -p "Catégorie [$category]: " new_category
        [[ -n "$new_category" ]] && category="$new_category"
        
        read -p "Description [$description]: " new_description
        [[ -n "$new_description" ]] && description="$new_description"
        
        read -p "Auteur [$author]: " new_author
        [[ -n "$new_author" ]] && author="$new_author"
        
        read -p "Version [$version]: " new_version
        [[ -n "$new_version" ]] && version="$new_version"
    fi
}

# Enregistrer dans la base de données
register_in_database() {
    local script_info
    script_info=$(extract_script_info)
    eval "$script_info"
    
    # Prompt pour info complémentaires si pas en mode auto
    prompt_for_info
    
    log_info "💾 Enregistrement dans la base de données"
    
    # Vérifier si le script existe déjà
    local existing_id
    existing_id=$(sqlite3 "$DB_FILE" "SELECT id FROM scripts WHERE name = '$script_name';" 2>/dev/null || echo "")
    
    if [[ -n "$existing_id" ]]; then
        log_warn "Script déjà enregistré (ID: $existing_id)"
        
        if [[ $AUTO_MODE -eq 0 ]]; then
            read -p "Mettre à jour ? (o/N): " update_confirm
            if [[ "$update_confirm" != "o" && "$update_confirm" != "O" ]]; then
                log_info "Enregistrement annulé"
                return 0
            fi
        fi
        
        # Mise à jour
        sqlite3 "$DB_FILE" <<EOF
UPDATE scripts SET
    type = '$script_type',
    category = '$category', 
    description = '$description',
    author = '$author',
    version = '$version',
    path = '$SCRIPT_PATH',
    updated_at = CURRENT_TIMESTAMP
WHERE name = '$script_name';
EOF
        log_info "✓ Script mis à jour: $script_name"
    else
        # Insertion
        sqlite3 "$DB_FILE" <<EOF
INSERT INTO scripts (name, type, category, description, author, version, path) 
VALUES ('$script_name', '$script_type', '$category', '$description', '$author', '$version', '$SCRIPT_PATH');
EOF
        
        # Récupérer l'ID inséré
        local new_id
        new_id=$(sqlite3 "$DB_FILE" "SELECT id FROM scripts WHERE name = '$script_name';")
        log_info "✓ Script enregistré: $script_name (ID: $new_id)"
    fi
}

# Analyser les dépendances du script
analyze_dependencies() {
    local script_file="$PROJECT_ROOT/$SCRIPT_PATH"
    local script_name=$(basename "$SCRIPT_PATH")
    
    log_info "🔍 Analyse des dépendances"
    
    # Récupérer l'ID du script
    local script_id
    script_id=$(sqlite3 "$DB_FILE" "SELECT id FROM scripts WHERE name = '$script_name';")
    
    if [[ -z "$script_id" ]]; then
        log_error "Script non trouvé dans la base"
        return 1
    fi
    
    # Nettoyer les anciennes dépendances
    sqlite3 "$DB_FILE" "DELETE FROM script_dependencies WHERE script_id = $script_id;"
    
    # Analyser les imports de bibliothèques (source)
    if grep -q "source.*lib/" "$script_file" 2>/dev/null; then
        grep "source.*lib/" "$script_file" | while read -r line; do
            # Extraire le nom du fichier lib
            local lib_path
            lib_path=$(echo "$line" | sed -n 's/.*source.*\([^"]*lib\/[^"]*\.sh\).*/\1/p')
            if [[ -n "$lib_path" ]]; then
                local lib_file=$(basename "$lib_path")
                log_debug "Dépendance library trouvée: $lib_file"
                
                sqlite3 "$DB_FILE" <<EOF
INSERT OR IGNORE INTO script_dependencies (script_id, dependency_type, depends_on_library, description) 
VALUES ($script_id, 'library', '$lib_file', 'Import de bibliothèque');
EOF
            fi
        done
    fi
    
    # Analyser les commandes système utilisées
    local common_commands=("jq" "curl" "pct" "pvesm" "docker" "systemctl" "awk" "sed")
    for cmd in "${common_commands[@]}"; do
        if grep -qw "$cmd" "$script_file" 2>/dev/null; then
            log_debug "Dépendance command trouvée: $cmd"
            
            sqlite3 "$DB_FILE" <<EOF
INSERT OR IGNORE INTO script_dependencies (script_id, dependency_type, depends_on_command, description) 
VALUES ($script_id, 'command', '$cmd', 'Commande système requise');
EOF
        fi
    done
    
    # TODO: Analyser les appels vers d'autres scripts (execute_script, bash script.sh, etc.)
    
    log_info "✓ Analyse des dépendances terminée"
}

# Extraire les paramètres du script
extract_parameters() {
    local script_file="$PROJECT_ROOT/$SCRIPT_PATH"
    local script_name=$(basename "$SCRIPT_PATH")
    
    log_info "⚙️  Extraction des paramètres"
    
    # Récupérer l'ID du script
    local script_id
    script_id=$(sqlite3 "$DB_FILE" "SELECT id FROM scripts WHERE name = '$script_name';")
    
    if [[ -z "$script_id" ]]; then
        log_error "Script non trouvé dans la base"
        return 1
    fi
    
    # Nettoyer les anciens paramètres
    sqlite3 "$DB_FILE" "DELETE FROM script_parameters WHERE script_id = $script_id;"
    
    # Rechercher les options dans le parsing (case)
    if grep -A 50 "parse_args()" "$script_file" 2>/dev/null | grep -B 5 -A 5 "case.*in" | grep -E "^\s*-[a-zA-Z]|--[a-zA-Z]" >/dev/null 2>&1; then
        
        # Extraire les options standardisées
        local standard_options=("-h|--help" "-v|--verbose" "-d|--debug" "-f|--force" "-n|--dry-run")
        
        for opt_pattern in "${standard_options[@]}"; do
            if grep -q "$opt_pattern" "$script_file" 2>/dev/null; then
                local opt_name=$(echo "$opt_pattern" | cut -d'|' -f2 | sed 's/--//')
                local description=""
                
                case $opt_name in
                    "help") description="Affiche l'aide" ;;
                    "verbose") description="Mode verbeux" ;;
                    "debug") description="Mode debug" ;;
                    "force") description="Force l'opération" ;;
                    "dry-run") description="Simulation sans exécution" ;;
                esac
                
                log_debug "Paramètre trouvé: --$opt_name"
                
                sqlite3 "$DB_FILE" <<EOF
INSERT OR IGNORE INTO script_parameters (script_id, param_name, param_type, is_required, description) 
VALUES ($script_id, '--$opt_name', 'boolean', 0, '$description');
EOF
            fi
        done
    fi
    
    log_info "✓ Extraction des paramètres terminée"
}

# Extraire les codes de sortie
extract_exit_codes() {
    local script_file="$PROJECT_ROOT/$SCRIPT_PATH"
    local script_name=$(basename "$SCRIPT_PATH")
    
    log_info "🚪 Extraction des codes de sortie"
    
    # Récupérer l'ID du script
    local script_id
    script_id=$(sqlite3 "$DB_FILE" "SELECT id FROM scripts WHERE name = '$script_name';")
    
    if [[ -z "$script_id" ]]; then
        log_error "Script non trouvé dans la base"
        return 1
    fi
    
    # Nettoyer les anciens codes
    sqlite3 "$DB_FILE" "DELETE FROM exit_codes WHERE script_id = $script_id;"
    
    # Rechercher les exit avec constantes
    local exit_patterns=("EXIT_SUCCESS" "EXIT_ERROR_GENERAL" "EXIT_ERROR_USAGE" "EXIT_ERROR_PERMISSION" "EXIT_ERROR_NOT_FOUND" "EXIT_ERROR_DEPENDENCY")
    
    for pattern in "${exit_patterns[@]}"; do
        if grep -q "exit.*$pattern" "$script_file" 2>/dev/null; then
            local code_value=""
            local description=""
            
            case $pattern in
                "EXIT_SUCCESS") code_value=0; description="Succès" ;;
                "EXIT_ERROR_GENERAL") code_value=1; description="Erreur générale" ;;
                "EXIT_ERROR_USAGE") code_value=2; description="Paramètres invalides" ;;
                "EXIT_ERROR_PERMISSION") code_value=3; description="Permissions insuffisantes" ;;
                "EXIT_ERROR_NOT_FOUND") code_value=4; description="Ressource non trouvée" ;;
                "EXIT_ERROR_DEPENDENCY") code_value=5; description="Dépendance manquante" ;;
            esac
            
            log_debug "Code de sortie trouvé: $code_value ($pattern)"
            
            sqlite3 "$DB_FILE" <<EOF
INSERT OR IGNORE INTO exit_codes (script_id, exit_code, code_name, description) 
VALUES ($script_id, $code_value, '$pattern', '$description');
EOF
        fi
    done
    
    log_info "✓ Extraction des codes de sortie terminée"
}

# Point d'entrée principal
main() {
    # Initialisation du logging
    init_logging "$(basename "$0")"
    
    log_info "📋 Enregistrement d'un script dans le catalogue"
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation
    validate_prerequisites
    
    # Enregistrement
    register_in_database
    
    # Analyses complémentaires
    analyze_dependencies
    extract_parameters
    extract_exit_codes
    
    log_info "✅ Enregistrement terminé avec succès"
    
    # Afficher un résumé
    local script_name=$(basename "$SCRIPT_PATH")
    echo ""
    echo "📊 Script enregistré: $script_name"
    
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    'ID:' as Field, id as Value FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Type:', type FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Catégorie:', category FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Dépendances:', 
    COALESCE((SELECT COUNT(*) FROM script_dependencies WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name')), 0)
FROM scripts WHERE name = '$script_name' LIMIT 1;
EOF
}

# Exécution
main "$@"