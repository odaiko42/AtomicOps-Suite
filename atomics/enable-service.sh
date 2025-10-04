#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: enable-service.sh
# Description: Active ou désactive un service au démarrage du système
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="enable-service.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
FORCE=${FORCE:-0}
DRY_RUN=${DRY_RUN:-0}
SERVICE_NAME=""
ACTION="enable"  # enable|disable

# =============================================================================
# Fonctions Utilitaires et Logging
# =============================================================================

log_debug() {
    [[ $DEBUG -eq 0 ]] && return 0
    echo "[DEBUG] $*" >&2
}

log_info() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[INFO] $*" >&2
}

log_warn() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

die() {
    log_error "$1"
    exit "${2:-1}"
}

# =============================================================================
# Fonctions d'Aide et de Parsing
# =============================================================================

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <enable|disable> <service_name>

Description:
    Active ou désactive un service au démarrage du système selon le
    gestionnaire de services disponible (systemd, SysV, OpenRC).

Arguments:
    <enable|disable>        Action à effectuer (obligatoire)
    <service_name>          Nom du service à configurer (obligatoire)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -f, --force            Forcer l'opération sans demander confirmation
    --dry-run              Simulation (afficher les commandes sans les exécuter)
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "service_name": "apache2",
        "action": "enable",
        "previous_state": "disabled",
        "new_state": "enabled",
        "service_manager": "systemd",
        "commands_executed": ["systemctl enable apache2"],
        "dry_run": false,
        "verification": {
          "enabled_after": true,
          "status_check": "success",
          "runlevel_links": ["/etc/systemd/system/multi-user.target.wants/apache2.service"]
        }
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Service non trouvé
    4 - Permissions insuffisantes

Exemples:
    $SCRIPT_NAME enable apache2                    # Activer apache2
    $SCRIPT_NAME disable nginx                     # Désactiver nginx
    $SCRIPT_NAME --force disable ssh              # Forcer désactivation
    $SCRIPT_NAME --dry-run enable mysql           # Simulation
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                VERBOSE=1
                shift
                ;;
            -q|--quiet)
                QUIET=1
                shift
                ;;
            -j|--json-only)
                JSON_ONLY=1
                QUIET=1
                shift
                ;;
            -f|--force)
                FORCE=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            enable|disable)
                if [[ -z "$ACTION" || "$ACTION" == "enable" ]]; then
                    ACTION="$1"
                else
                    die "Action déjà spécifiée: $ACTION" 2
                fi
                shift
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                if [[ -z "$SERVICE_NAME" ]]; then
                    SERVICE_NAME="$1"
                else
                    die "Trop d'arguments. Service déjà spécifié: $SERVICE_NAME" 2
                fi
                shift
                ;;
        esac
    done

    # Validation des arguments
    if [[ "$ACTION" != "enable" && "$ACTION" != "disable" ]]; then
        die "Action invalide: $ACTION. Utilisez 'enable' ou 'disable'." 2
    fi
    
    if [[ -z "$SERVICE_NAME" ]]; then
        die "Nom de service obligatoire manquant. Utilisez -h pour l'aide." 2
    fi
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    if ! command -v systemctl >/dev/null 2>&1 && 
       ! command -v update-rc.d >/dev/null 2>&1 && 
       ! command -v chkconfig >/dev/null 2>&1 &&
       ! command -v rc-update >/dev/null 2>&1; then
        missing+=("systemctl ou update-rc.d ou chkconfig ou rc-update")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Gestionnaires de service manquants: ${missing[*]}" 3
    fi
    
    log_debug "Dépendances vérifiées avec succès"
}

detect_service_manager() {
    if command -v systemctl >/dev/null 2>&1 && systemctl --version >/dev/null 2>&1; then
        echo "systemd"
    elif command -v update-rc.d >/dev/null 2>&1; then
        echo "sysv-debian"
    elif command -v chkconfig >/dev/null 2>&1; then
        echo "sysv-redhat"
    elif command -v rc-update >/dev/null 2>&1; then
        echo "openrc"
    else
        echo "unknown"
    fi
}

check_service_exists() {
    local service_name="$1"
    local service_manager="$2"
    
    case "$service_manager" in
        systemd)
            systemctl list-unit-files "$service_name.service" >/dev/null 2>&1 || \
            systemctl list-units "$service_name.service" >/dev/null 2>&1
            ;;
        sysv-debian|sysv-redhat)
            [[ -f "/etc/init.d/$service_name" ]]
            ;;
        openrc)
            [[ -f "/etc/init.d/$service_name" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

get_current_state() {
    local service_name="$1"
    local service_manager="$2"
    
    case "$service_manager" in
        systemd)
            if systemctl is-enabled "$service_name" >/dev/null 2>&1; then
                echo "enabled"
            else
                systemctl is-enabled "$service_name" 2>/dev/null || echo "disabled"
            fi
            ;;
        sysv-debian)
            if ls /etc/rc*.d/S*"$service_name" >/dev/null 2>&1; then
                echo "enabled"
            else
                echo "disabled"
            fi
            ;;
        sysv-redhat)
            chkconfig --list "$service_name" 2>/dev/null | grep -q ":on" && echo "enabled" || echo "disabled"
            ;;
        openrc)
            if rc-update show | grep -q "$service_name"; then
                echo "enabled"
            else
                echo "disabled"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

ask_confirmation() {
    local service_name="$1"
    local action="$2"
    
    if [[ $FORCE -eq 1 || $DRY_RUN -eq 1 ]]; then
        return 0
    fi
    
    local action_fr
    case "$action" in
        enable) action_fr="activer" ;;
        disable) action_fr="désactiver" ;;
    esac
    
    echo "Voulez-vous vraiment $action_fr le service '$service_name' au démarrage? [y/N]" >&2
    read -r response
    case "$response" in
        [yY]|[yY][eE][sS]|[oO]|[oO][uU][iI])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

execute_command() {
    local cmd="$1"
    local description="$2"
    
    log_debug "Exécution: $cmd"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "DRY-RUN: $description - $cmd"
        return 0
    fi
    
    if [[ $VERBOSE -eq 1 ]]; then
        log_info "Exécution: $description"
    fi
    
    if eval "$cmd" >/dev/null 2>&1; then
        log_debug "Commande réussie: $cmd"
        return 0
    else
        local exit_code=$?
        log_error "Échec de la commande: $cmd (code: $exit_code)"
        return $exit_code
    fi
}

enable_disable_service() {
    local service_name="$1"
    local action="$2"
    local service_manager="$3"
    
    local commands_executed=()
    local errors=()
    local warnings=()
    
    case "$service_manager" in
        systemd)
            local cmd="systemctl $action $service_name"
            if execute_command "$cmd" "${action^} service with systemd"; then
                commands_executed+=("$cmd")
            else
                errors+=("Failed to $action service with systemd")
                return 1
            fi
            
            # Reload daemon si nécessaire pour enable
            if [[ "$action" == "enable" ]]; then
                cmd="systemctl daemon-reload"
                if execute_command "$cmd" "Reload systemd daemon"; then
                    commands_executed+=("$cmd")
                fi
            fi
            ;;
            
        sysv-debian)
            if [[ "$action" == "enable" ]]; then
                local cmd="update-rc.d $service_name defaults"
                if execute_command "$cmd" "Enable service with update-rc.d"; then
                    commands_executed+=("$cmd")
                else
                    errors+=("Failed to enable service with update-rc.d")
                    return 1
                fi
            else
                local cmd="update-rc.d $service_name disable"
                if execute_command "$cmd" "Disable service with update-rc.d"; then
                    commands_executed+=("$cmd")
                else
                    # Essayer la méthode alternative
                    cmd="update-rc.d -f $service_name remove"
                    if execute_command "$cmd" "Remove service links with update-rc.d"; then
                        commands_executed+=("$cmd")
                        warnings+=("Service links removed instead of disabled")
                    else
                        errors+=("Failed to disable service with update-rc.d")
                        return 1
                    fi
                fi
            fi
            ;;
            
        sysv-redhat)
            local cmd="chkconfig $service_name $([[ $action == "enable" ]] && echo "on" || echo "off")"
            if execute_command "$cmd" "${action^} service with chkconfig"; then
                commands_executed+=("$cmd")
            else
                errors+=("Failed to $action service with chkconfig")
                return 1
            fi
            ;;
            
        openrc)
            if [[ "$action" == "enable" ]]; then
                local runlevel="default"
                local cmd="rc-update add $service_name $runlevel"
                if execute_command "$cmd" "Add service to runlevel with rc-update"; then
                    commands_executed+=("$cmd")
                else
                    errors+=("Failed to add service with rc-update")
                    return 1
                fi
            else
                local cmd="rc-update del $service_name"
                if execute_command "$cmd" "Remove service from runlevels with rc-update"; then
                    commands_executed+=("$cmd")
                else
                    errors+=("Failed to remove service with rc-update")
                    return 1
                fi
            fi
            ;;
            
        *)
            errors+=("Unsupported service manager: $service_manager")
            return 1
            ;;
    esac
    
    # Retourner les résultats via des variables globales
    EXECUTED_COMMANDS=("${commands_executed[@]}")
    OPERATION_ERRORS=("${errors[@]}")
    OPERATION_WARNINGS=("${warnings[@]}")
    
    return 0
}

verify_operation() {
    local service_name="$1"
    local expected_state="$2"
    local service_manager="$3"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        return 0  # Ne peut pas vérifier en mode dry-run
    fi
    
    # Attendre un peu pour que les changements prennent effet
    sleep 1
    
    local actual_state
    actual_state=$(get_current_state "$service_name" "$service_manager")
    
    [[ "$actual_state" == "$expected_state" ]]
}

get_runlevel_links() {
    local service_name="$1"
    local service_manager="$2"
    
    case "$service_manager" in
        systemd)
            find /etc/systemd/system -name "*$service_name.service" 2>/dev/null | head -5 | tr '\n' ',' | sed 's/,$//'
            ;;
        sysv-*)
            find /etc/rc*.d -name "*$service_name*" 2>/dev/null | head -5 | tr '\n' ',' | sed 's/,$//'
            ;;
        openrc)
            find /etc/runlevels -name "$service_name" 2>/dev/null | head -5 | tr '\n' ',' | sed 's/,$//'
            ;;
        *)
            echo ""
            ;;
    esac
}

# Variables globales pour les résultats d'opération
EXECUTED_COMMANDS=()
OPERATION_ERRORS=()
OPERATION_WARNINGS=()

manage_service_enable() {
    local service_name="$1"
    local action="$2"
    
    log_debug "Gestion de l'activation pour: $service_name (action: $action)"
    
    # Détecter le gestionnaire de services
    local service_manager
    service_manager=$(detect_service_manager)
    log_debug "Gestionnaire détecté: $service_manager"
    
    # Vérifier que le service existe
    if ! check_service_exists "$service_name" "$service_manager"; then
        die "Service non trouvé: $service_name" 3
    fi
    
    # État actuel
    local previous_state
    previous_state=$(get_current_state "$service_name" "$service_manager")
    log_debug "État actuel: $previous_state"
    
    # Vérifier si l'opération est nécessaire
    if [[ "$action" == "enable" && "$previous_state" == "enabled" ]]; then
        log_warn "Service déjà activé: $service_name"
    elif [[ "$action" == "disable" && "$previous_state" == "disabled" ]]; then
        log_warn "Service déjà désactivé: $service_name"
    fi
    
    # Demander confirmation
    if ! ask_confirmation "$service_name" "$action"; then
        die "Opération annulée par l'utilisateur" 1
    fi
    
    # Exécuter l'opération
    if ! enable_disable_service "$service_name" "$action" "$service_manager"; then
        die "Échec de l'opération $action pour $service_name" 1
    fi
    
    # Vérification
    local verification_status="success"
    local enabled_after="false"
    
    if verify_operation "$service_name" "$action" "$service_manager"; then
        enabled_after=$([[ "$action" == "enable" ]] && echo "true" || echo "false")
        log_info "Vérification réussie: service $service_name ${action}d"
    else
        verification_status="failed"
        OPERATION_WARNINGS+=("Verification failed: service state may not have changed")
        log_warn "Vérification échouée pour: $service_name"
    fi
    
    # Obtenir les liens de niveau d'exécution
    local runlevel_links
    runlevel_links=$(get_runlevel_links "$service_name" "$service_manager")
    
    # Échapper le nom du service pour JSON
    local service_name_escaped
    service_name_escaped=$(echo "$service_name" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Construire le tableau des commandes exécutées pour JSON
    local commands_json="[]"
    if [[ ${#EXECUTED_COMMANDS[@]} -gt 0 ]]; then
        local cmd_list=""
        for cmd in "${EXECUTED_COMMANDS[@]}"; do
            local escaped_cmd
            escaped_cmd=$(echo "$cmd" | sed 's/\\/\\\\/g; s/"/\\"/g')
            cmd_list+="\"$escaped_cmd\","
        done
        cmd_list=${cmd_list%,}
        commands_json="[$cmd_list]"
    fi
    
    # Construire le tableau des liens pour JSON
    local links_json="[]"
    if [[ -n "$runlevel_links" ]]; then
        local links_list=""
        IFS=',' read -ra LINKS <<< "$runlevel_links"
        for link in "${LINKS[@]}"; do
            [[ -n "$link" ]] && links_list+="\"$link\","
        done
        links_list=${links_list%,}
        [[ -n "$links_list" ]] && links_json="[$links_list]"
    fi
    
    # Construire les tableaux d'erreurs et avertissements
    local errors_json="[]" warnings_json="[]"
    
    if [[ ${#OPERATION_ERRORS[@]} -gt 0 ]]; then
        local err_list=""
        for err in "${OPERATION_ERRORS[@]}"; do
            local escaped_err
            escaped_err=$(echo "$err" | sed 's/\\/\\\\/g; s/"/\\"/g')
            err_list+="\"$escaped_err\","
        done
        err_list=${err_list%,}
        errors_json="[$err_list]"
    fi
    
    if [[ ${#OPERATION_WARNINGS[@]} -gt 0 ]]; then
        local warn_list=""
        for warn in "${OPERATION_WARNINGS[@]}"; do
            local escaped_warn
            escaped_warn=$(echo "$warn" | sed 's/\\/\\\\/g; s/"/\\"/g')
            warn_list+="\"$escaped_warn\","
        done
        warn_list=${warn_list%,}
        warnings_json="[$warn_list]"
    fi
    
    # Générer la réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Service $action operation completed successfully",
  "data": {
    "service_name": "$service_name_escaped",
    "action": "$action",
    "previous_state": "$previous_state",
    "new_state": "$action$([ "$action" == "enable" ] && echo "d" || echo "d")",
    "service_manager": "$service_manager",
    "commands_executed": $commands_json,
    "dry_run": $([ $DRY_RUN -eq 1 ] && echo "true" || echo "false"),
    "verification": {
      "enabled_after": $enabled_after,
      "status_check": "$verification_status",
      "runlevel_links": $links_json
    },
    "operation_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": $errors_json,
  "warnings": $warnings_json
}
EOF
    
    log_debug "Opération $action terminée pour $service_name"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    
    # Vérifier les permissions
    if [[ $EUID -ne 0 && $DRY_RUN -eq 0 ]]; then
        log_warn "Ce script nécessite généralement les privilèges root"
        log_warn "Certaines opérations peuvent échouer sans sudo/root"
    fi
    
    manage_service_enable "$SERVICE_NAME" "$ACTION"
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi