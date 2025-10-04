#!/bin/bash
#
# Bibliothèque: logger.sh
# Description: Système de logging centralisé conforme à la méthodologie
# Usage: source "$PROJECT_ROOT/lib/logger.sh"
#

# Vérification que la bibliothèque n'est chargée qu'une fois
[[ "${LOGGER_LIB_LOADED:-}" == "1" ]] && return 0
readonly LOGGER_LIB_LOADED=1

# Charger common.sh si pas déjà fait
if [[ "${COMMON_LIB_LOADED:-}" != "1" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    source "$PROJECT_ROOT/lib/common.sh"
fi

# Configuration du logging
LOG_LEVEL="${LOG_LEVEL:-1}"  # 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR
LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs}"
LOG_FORMAT="${LOG_FORMAT:-standard}"  # standard, json, syslog

# Niveaux de log
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# Mapping des niveaux vers les noms
declare -A LOG_LEVEL_NAMES=(
    [$LOG_LEVEL_DEBUG]="DEBUG"
    [$LOG_LEVEL_INFO]="INFO"
    [$LOG_LEVEL_WARN]="WARN"
    [$LOG_LEVEL_ERROR]="ERROR"
)

# Mapping des niveaux vers les couleurs
declare -A LOG_LEVEL_COLORS=(
    [$LOG_LEVEL_DEBUG]="$COLOR_CYAN"
    [$LOG_LEVEL_INFO]="$COLOR_GREEN"
    [$LOG_LEVEL_WARN]="$COLOR_YELLOW"
    [$LOG_LEVEL_ERROR]="$COLOR_RED"
)

# Variables globales pour le contexte
SCRIPT_NAME="${SCRIPT_NAME:-$(basename "${0:-unknown}")}"
SCRIPT_PID="${SCRIPT_PID:-$$}"

# Initialisation du système de logging
init_logging() {
    local script_name="${1:-$SCRIPT_NAME}"
    
    SCRIPT_NAME="$script_name"
    
    # Créer le répertoire de logs si nécessaire
    local log_subdir="$LOG_DIR"
    
    # Organiser par type de script et par date
    if [[ "$SCRIPT_NAME" == *"atomic"* ]] || [[ -f "$PROJECT_ROOT/atomics/$SCRIPT_NAME" ]]; then
        log_subdir="$LOG_DIR/atomics/$(date +%Y-%m-%d)"
    elif [[ "$SCRIPT_NAME" == *"orchestrator"* ]] || [[ -d "$PROJECT_ROOT/orchestrators" ]]; then
        log_subdir="$LOG_DIR/orchestrators/$(date +%Y-%m-%d)"
    else
        log_subdir="$LOG_DIR/general/$(date +%Y-%m-%d)"
    fi
    
    mkdir -p "$log_subdir" 2>/dev/null || true
    
    # Définir le fichier de log
    LOG_FILE="$log_subdir/${SCRIPT_NAME%.*}.log"
}

# Fonction de logging générique
log_message() {
    local level=$1
    local message=$2
    local function_name="${3:-${FUNCNAME[2]:-main}}"
    
    # Vérifier si on doit logger ce niveau
    [[ $level -lt $LOG_LEVEL ]] && return 0
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local level_name="${LOG_LEVEL_NAMES[$level]}"
    local level_color="${LOG_LEVEL_COLORS[$level]}"
    
    # Format du message
    local log_entry=""
    
    case "$LOG_FORMAT" in
        json)
            log_entry=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "level": "$level_name",
  "script": "$SCRIPT_NAME",
  "pid": $SCRIPT_PID,
  "function": "$function_name",
  "message": "$(to_json_string "$message")"
}
EOF
            )
            ;;
        syslog)
            log_entry="<$(( (16 + level) * 8 + 6 ))>1 $timestamp $(hostname) $SCRIPT_NAME $SCRIPT_PID $function_name - $message"
            ;;
        *)
            # Format standard : [TIMESTAMP] [LEVEL] [SCRIPT:PID] [FUNCTION] Message
            log_entry="[$timestamp] [$level_name] [$SCRIPT_NAME:$SCRIPT_PID] [$function_name] $message"
            ;;
    esac
    
    # Écrire dans le fichier de log si configuré
    if [[ -n "${LOG_FILE:-}" ]] && [[ -w "$(dirname "$LOG_FILE")" ]]; then
        echo "$log_entry" >> "$LOG_FILE" 2>/dev/null || true
    fi
    
    # Afficher sur stderr avec couleur selon le niveau
    if [[ $level -ge $LOG_LEVEL ]]; then
        echo -e "${level_color}$log_entry${COLOR_RESET}" >&2
    fi
}

# Fonctions de logging par niveau
log_debug() {
    log_message $LOG_LEVEL_DEBUG "$1" "${FUNCNAME[1]:-unknown}"
}

log_info() {
    log_message $LOG_LEVEL_INFO "$1" "${FUNCNAME[1]:-unknown}"
}

log_warn() {
    log_message $LOG_LEVEL_WARN "$1" "${FUNCNAME[1]:-unknown}"
}

log_error() {
    log_message $LOG_LEVEL_ERROR "$1" "${FUNCNAME[1]:-unknown}"
}

# Fonctions de logging avec préfixes spéciaux
ct_info() {
    log_message $LOG_LEVEL_INFO "[CT] $1" "${FUNCNAME[1]:-unknown}"
}

ct_warn() {
    log_message $LOG_LEVEL_WARN "[CT] $1" "${FUNCNAME[1]:-unknown}"
}

ct_error() {
    log_message $LOG_LEVEL_ERROR "[CT] $1" "${FUNCNAME[1]:-unknown}"
}

usb_info() {
    log_message $LOG_LEVEL_INFO "[USB] $1" "${FUNCNAME[1]:-unknown}"
}

usb_warn() {
    log_message $LOG_LEVEL_WARN "[USB] $1" "${FUNCNAME[1]:-unknown}"
}

usb_error() {
    log_message $LOG_LEVEL_ERROR "[USB] $1" "${FUNCNAME[1]:-unknown}"
}

iscsi_info() {
    log_message $LOG_LEVEL_INFO "[iSCSI] $1" "${FUNCNAME[1]:-unknown}"
}

iscsi_warn() {
    log_message $LOG_LEVEL_WARN "[iSCSI] $1" "${FUNCNAME[1]:-unknown}"
}

iscsi_error() {
    log_message $LOG_LEVEL_ERROR "[iSCSI] $1" "${FUNCNAME[1]:-unknown}"
}

# Fonction pour changer le niveau de log dynamiquement
set_log_level() {
    local new_level=$1
    
    case "$new_level" in
        debug|DEBUG|0) LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        info|INFO|1) LOG_LEVEL=$LOG_LEVEL_INFO ;;
        warn|WARN|warning|WARNING|2) LOG_LEVEL=$LOG_LEVEL_WARN ;;
        error|ERROR|3) LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        *)
            log_error "Invalid log level: $new_level"
            return 1
            ;;
    esac
    
    log_info "Log level set to: ${LOG_LEVEL_NAMES[$LOG_LEVEL]}"
}

# Fonction pour logger l'exécution de commandes
log_command() {
    local command_line="$*"
    
    log_debug "Executing: $command_line"
    
    local start_time=$(date +%s%3N)
    local exit_code=0
    
    "$@" || exit_code=$?
    
    local end_time=$(date +%s%3N)
    local duration=$(( end_time - start_time ))
    
    if [[ $exit_code -eq 0 ]]; then
        log_debug "Command completed successfully (${duration}ms): $command_line"
    else
        log_error "Command failed with exit code $exit_code (${duration}ms): $command_line"
    fi
    
    return $exit_code
}

# Fonction de nettoyage des logs anciens
cleanup_old_logs() {
    local retention_days="${1:-30}"
    
    if [[ -d "$LOG_DIR" ]]; then
        log_info "Cleaning up logs older than $retention_days days"
        
        find "$LOG_DIR" -name "*.log" -type f -mtime "+$retention_days" -delete 2>/dev/null || true
        
        # Nettoyer les répertoires vides
        find "$LOG_DIR" -type d -empty -delete 2>/dev/null || true
        
        log_info "Log cleanup completed"
    fi
}

# Initialisation automatique avec le nom du script appelant
if [[ -n "${BASH_SOURCE[1]:-}" ]]; then
    auto_script_name=$(basename "${BASH_SOURCE[1]}")
    init_logging "$auto_script_name"
fi

# Export des fonctions pour utilisation dans les sous-shells
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f ct_info
export -f ct_warn
export -f ct_error
export -f usb_info
export -f usb_warn
export -f usb_error
export -f iscsi_info
export -f iscsi_warn
export -f iscsi_error
export -f log_command