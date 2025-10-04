#!/bin/bash
#
# Script: SCRIPT_NAME.sh
# Description: SCRIPT_DESCRIPTION
# Usage: SCRIPT_NAME.sh [OPTIONS]
#
# Options:
#   -h, --help              Affiche cette aide
#   -v, --verbose           Mode verbeux
#   -d, --debug             Mode debug
#   -f, --force             Force l'opération
#
# Exit codes:
#   0 - Succès
#   1 - Erreur générale
#   2 - Paramètres invalides
#   3 - Permissions insuffisantes
#   4 - Ressource non trouvée
#
# Examples:
#   ./SCRIPT_NAME.sh
#   ./SCRIPT_NAME.sh --verbose
#   ./SCRIPT_NAME.sh --debug --force
#
# Author: AUTHOR_NAME
# Created: CREATION_DATE
#

set -euo pipefail

# Détection du répertoire du projet
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Import des bibliothèques obligatoires
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"
source "$PROJECT_ROOT/lib/validator.sh"

# Import des bibliothèques spécifiques au projet CT
source "$PROJECT_ROOT/lib/ct-common.sh"

# Variables globales
VERBOSE=0
DEBUG=0
FORCE=0

# Variables métier (à adapter selon vos besoins)
# PARAM1=""
# PARAM2=""

# Fonction d'aide
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

SCRIPT_DESCRIPTION

Options:
  -h, --help              Affiche cette aide
  -v, --verbose           Mode verbeux (LOG_LEVEL=1)
  -d, --debug             Mode debug (LOG_LEVEL=0)
  -f, --force             Force l'opération sans confirmation

Exit codes:
  $EXIT_SUCCESS ($EXIT_SUCCESS) - Succès
  $EXIT_ERROR_GENERAL ($EXIT_ERROR_GENERAL) - Erreur générale
  $EXIT_ERROR_USAGE ($EXIT_ERROR_USAGE) - Paramètres invalides
  $EXIT_ERROR_PERMISSION ($EXIT_ERROR_PERMISSION) - Permissions insuffisantes
  $EXIT_ERROR_NOT_FOUND ($EXIT_ERROR_NOT_FOUND) - Ressource non trouvée

Examples:
  $0
  $0 --verbose
  $0 --debug --force

EOF
}

# Parsing des arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit $EXIT_SUCCESS
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
            -f|--force)
                FORCE=1
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
    
    # Vérification des permissions (adapter selon vos besoins)
    # validate_permissions root || exit $EXIT_ERROR_PERMISSION
    
    # Vérification des dépendances système
    local required_commands=("jq")  # Ajouter les commandes nécessaires
    validate_dependencies "${required_commands[@]}" || exit $EXIT_ERROR_DEPENDENCY
    
    # Validation des paramètres métier (à implémenter selon vos besoins)
    # validate_required_params "PARAM1" "$PARAM1" || exit $EXIT_ERROR_USAGE
    
    log_debug "Prérequis validés avec succès"
}

# Logique métier principale
do_main_action() {
    log_info "Début de l'action principale"
    
    # TODO: Implémenter votre logique ici
    
    # Exemple de données retournées (à adapter)
    local result_data='{
        "action": "SCRIPT_ACTION",
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
        "status": "completed"
    }'
    
    log_info "Action principale terminée avec succès"
    echo "$result_data"
}

# Construction de la sortie JSON standardisée
build_json_output() {
    local status="$1"
    local code="$2"
    local message="$3"
    local data="$4"
    local errors="${5:-[]}"
    local warnings="${6:-[]}"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat <<EOF
{
  "status": "$status",
  "code": $code,
  "timestamp": "$timestamp",
  "script": "$(basename "$0")",
  "message": "$message",
  "data": $data,
  "errors": $errors,
  "warnings": $warnings
}
EOF
}

# Fonction de nettoyage
cleanup() {
    local exit_code=$?
    
    log_debug "Nettoyage des ressources (code de sortie: $exit_code)"
    
    # TODO: Nettoyer les ressources créées
    # [[ -n "${TEMP_FILE:-}" ]] && rm -f "$TEMP_FILE"
    # [[ -n "${TEMP_DIR:-}" ]] && cleanup_temp "$TEMP_DIR"
    
    exit $exit_code
}

# Point d'entrée principal
main() {
    # Configuration des flux de sortie
    exec 3>&1  # Sauvegarder STDOUT original
    exec 1>&2  # Rediriger STDOUT vers STDERR pour les logs
    
    # Configuration du trap de nettoyage
    trap cleanup EXIT ERR INT TERM
    
    # Initialisation du logging
    init_logging "$(basename "$0")"
    
    log_info "Démarrage du script: $(basename "$0")"
    log_debug "Arguments: $*"
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des prérequis
    validate_prerequisites
    
    # Exécution de l'action principale
    local result_data
    if result_data=$(do_main_action); then
        # Succès - construire la sortie JSON et l'envoyer sur le vrai STDOUT
        build_json_output "success" $EXIT_SUCCESS "Operation completed successfully" "$result_data" >&3
        
        log_info "Script terminé avec succès"
        exit $EXIT_SUCCESS
    else
        local exit_code=$?
        log_error "Échec de l'action principale (code: $exit_code)"
        
        # Erreur - construire la sortie JSON d'erreur
        local error_message="Main action failed"
        build_json_output "error" $exit_code "$error_message" '{}' '["Main action failed with exit code '$exit_code'"]' >&3
        
        exit $exit_code
    fi
}

# Exécution du script
main "$@"