#!/bin/bash
#
# Script: list-service.all.sh
# Description: Liste tous les services systemd avec leurs états (nom, état active/inactive, enabled/disabled)
# Usage: list-service.all.sh [OPTIONS]
#
# Options:
#   -h, --help              Affiche cette aide
#   -v, --verbose           Mode verbeux
#   -d, --debug             Mode debug
#   -j, --json-only         Sortie JSON uniquement (pas de logs)
#   -a, --active-only       Afficher uniquement les services actifs
#   -e, --enabled-only      Afficher uniquement les services enabled
#
# Exit codes:
#   0 - Succès
#   1 - Erreur générale
#   2 - Erreur d'utilisation
#   6 - Erreur de dépendance
#
# Examples:
#   ./list-service.all.sh
#   ./list-service.all.sh --active-only
#   ./list-service.all.sh --json-only
#

# Configuration stricte
set -euo pipefail

# Codes de sortie
EXIT_SUCCESS=0
EXIT_ERROR_GENERAL=1
EXIT_ERROR_USAGE=2
EXIT_ERROR_DEPENDENCY=6

# Variables globales
VERBOSE=0
DEBUG=0
JSON_ONLY=0
ACTIVE_ONLY=0
ENABLED_ONLY=0

# Fonctions de logging minimal
log_info() { 
    [[ $JSON_ONLY -eq 0 ]] && echo "[INFO] $*" >&2 || true
}

log_error() { 
    echo "[ERROR] $*" >&2
}

log_debug() { 
    [[ $DEBUG -eq 1 && $JSON_ONLY -eq 0 ]] && echo "[DEBUG] $*" >&2 || true
}

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
                shift
                ;;
            -d|--debug)
                DEBUG=1
                shift
                ;;
            -j|--json-only)
                JSON_ONLY=1
                shift
                ;;
            -a|--active-only)
                ACTIVE_ONLY=1
                shift
                ;;
            -e|--enabled-only)
                ENABLED_ONLY=1
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                exit $EXIT_ERROR_USAGE
                ;;
            *)
                log_error "Unexpected argument: $1"
                exit $EXIT_ERROR_USAGE
                ;;
        esac
    done
}

# Validation des prérequis
validate_prerequisites() {
    log_debug "Validating prerequisites"
    
    # Vérification de systemctl
    if ! command -v systemctl >/dev/null 2>&1; then
        log_error "systemctl command not found - systemd is required"
        exit $EXIT_ERROR_DEPENDENCY
    fi
    
    # Vérifier que systemd est en cours d'exécution
    if ! systemctl --version >/dev/null 2>&1; then
        log_error "systemd is not running or accessible"
        exit $EXIT_ERROR_DEPENDENCY
    fi
    
    log_debug "Prerequisites validated"
}

# Fonction pour obtenir l'état d'un service
get_service_state() {
    local service_name="$1"
    local active_state="unknown"
    local load_state="unknown"
    local enabled_state="unknown"
    
    # Obtenir l'état actif (active/inactive/failed/etc.)
    active_state=$(systemctl is-active "$service_name" 2>/dev/null || echo "unknown")
    
    # Obtenir l'état de load (loaded/not-found/etc.)
    load_state=$(systemctl is-loaded "$service_name" 2>/dev/null || echo "unknown")
    
    # Obtenir l'état enabled (enabled/disabled/static/etc.)
    enabled_state=$(systemctl is-enabled "$service_name" 2>/dev/null || echo "unknown")
    
    echo "$active_state|$load_state|$enabled_state"
}

# Fonction pour parser les informations d'un service
parse_service_info() {
    local line="$1"
    
    # Extraire le nom du service (première colonne)
    local service_name=$(echo "$line" | awk '{print $1}')
    
    # Enlever l'extension .service si présente pour le nom affiché
    local display_name="$service_name"
    if [[ "$service_name" == *.service ]]; then
        display_name="${service_name%.service}"
    fi
    
    # Obtenir les états détaillés
    local states
    states=$(get_service_state "$service_name")
    local active_state=$(echo "$states" | cut -d'|' -f1)
    local load_state=$(echo "$states" | cut -d'|' -f2)
    local enabled_state=$(echo "$states" | cut -d'|' -f3)
    
    # Filtrer selon les options
    if [[ $ACTIVE_ONLY -eq 1 && "$active_state" != "active" ]]; then
        return 1
    fi
    
    if [[ $ENABLED_ONLY -eq 1 && "$enabled_state" != "enabled" ]]; then
        return 1
    fi
    
    # Déterminer le type de service
    local service_type="service"
    case "$service_name" in
        *.service) service_type="service" ;;
        *.socket) service_type="socket" ;;
        *.timer) service_type="timer" ;;
        *.target) service_type="target" ;;
        *.mount) service_type="mount" ;;
        *.path) service_type="path" ;;
        *) service_type="other" ;;
    esac
    
    # Déterminer si c'est un service système ou utilisateur
    local scope="system"
    # Note: pour détecter les services utilisateur, il faudrait --user mais on se concentre sur system
    
    # Construction du JSON pour ce service
    cat <<EOF
{
  "name": "$display_name",
  "full_name": "$service_name",
  "active_state": "$active_state",
  "load_state": "$load_state",
  "enabled_state": "$enabled_state",
  "type": "$service_type",
  "scope": "$scope"
}
EOF
}

# Fonction principale métier
do_main_action() {
    log_info "Reading systemd services information"
    
    local service_count=0
    local services_json=""
    local first_service=true
    
    # Obtenir la liste de tous les services avec systemctl
    # --no-pager pour éviter les problèmes de pagination
    # --plain pour un format simple
    # --no-legend pour éviter les en-têtes
    local systemctl_output
    systemctl_output=$(systemctl list-units --type=service --all --no-pager --plain --no-legend 2>/dev/null || true)
    
    # Si pas de services trouvés, essayer une approche alternative
    if [[ -z "$systemctl_output" ]]; then
        systemctl_output=$(systemctl list-unit-files --type=service --no-pager --plain --no-legend 2>/dev/null || true)
    fi
    
    # Traiter chaque ligne
    while IFS= read -r line; do
        # Ignorer les lignes vides
        [[ -z "$line" ]] && continue
        
        # Parser la ligne et récupérer le JSON du service
        if service_json=$(parse_service_info "$line"); then
            # Ajouter une virgule avant chaque service sauf le premier
            if [[ $first_service == true ]]; then
                services_json="$service_json"
                first_service=false
            else
                services_json="$services_json,$service_json"
            fi
            ((service_count++))
        fi
    done <<< "$systemctl_output"
    
    log_info "Found $service_count services"
    
    # Construction du JSON de données
    cat <<EOF
{
  "services": [
    $services_json
  ],
  "count": $service_count,
  "source": "systemctl",
  "filter": "$(
    if [[ $ACTIVE_ONLY -eq 1 && $ENABLED_ONLY -eq 1 ]]; then
      echo "active_and_enabled"
    elif [[ $ACTIVE_ONLY -eq 1 ]]; then
      echo "active_only"
    elif [[ $ENABLED_ONLY -eq 1 ]]; then
      echo "enabled_only"
    else
      echo "all"
    fi
  )",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# Construction de la sortie JSON finale
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

# Point d'entrée principal
main() {
    # Redirection pour séparer logs et résultat JSON si pas en mode JSON-only
    if [[ $JSON_ONLY -eq 0 ]]; then
        exec 3>&1
        exec 1>&2
    fi
    
    log_info "Script started: $(basename "$0")"
    
    # Parse arguments
    parse_args "$@"
    
    # Validation
    validate_prerequisites
    
    # Exécution
    local services_data
    services_data=$(do_main_action)
    
    # Construction du JSON de sortie
    local json_output
    json_output=$(build_json_output "success" $EXIT_SUCCESS "Service list retrieved successfully" "$services_data")
    
    # Sortie du résultat
    if [[ $JSON_ONLY -eq 0 ]]; then
        echo "$json_output" >&3
        log_info "Script completed successfully"
    else
        echo "$json_output"
    fi
    
    exit $EXIT_SUCCESS
}

# Exécution
main "$@"