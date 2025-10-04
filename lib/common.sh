#!/bin/bash
#
# Bibliothèque: common.sh
# Description: Fonctions utilitaires communes à tous les scripts
# Usage: source "$PROJECT_ROOT/lib/common.sh"
#

# Vérification que la bibliothèque n'est chargée qu'une fois
[[ "${COMMON_LIB_LOADED:-}" == "1" ]] && return 0
readonly COMMON_LIB_LOADED=1

# Configuration globale
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOG_LEVEL="${LOG_LEVEL:-1}"  # 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR

# Codes de sortie standards
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR_GENERAL=1
readonly EXIT_ERROR_USAGE=2
readonly EXIT_ERROR_PERMISSION=3
readonly EXIT_ERROR_NOT_FOUND=4
readonly EXIT_ERROR_ALREADY=5
readonly EXIT_ERROR_DEPENDENCY=6
readonly EXIT_ERROR_TIMEOUT=7
readonly EXIT_ERROR_VALIDATION=8

# Couleurs pour l'affichage
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_RESET='\033[0m'

# Fonction utilitaire : Vérification de commande
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Fonction utilitaire : Vérification de fichier
file_exists() {
    [[ -f "$1" ]]
}

# Fonction utilitaire : Vérification de répertoire
dir_exists() {
    [[ -d "$1" ]]
}

# Fonction utilitaire : Création sécurisée de répertoire temporaire
make_temp_dir() {
    local template="${1:-script-tmp}"
    mktemp -d "/tmp/${template}.XXXXXX"
}

# Fonction utilitaire : Nettoyage sécurisé de fichiers temporaires
cleanup_temp() {
    local temp_path="$1"
    if [[ -n "$temp_path" ]] && [[ "$temp_path" =~ ^/tmp/ ]]; then
        rm -rf "$temp_path" 2>/dev/null || true
    fi
}

# Fonction utilitaire : Vérification que le script tourne en tant que root
require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root" >&2
        exit $EXIT_ERROR_PERMISSION
    fi
}

# Fonction utilitaire : Affichage formaté avec couleurs
print_colored() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${COLOR_RESET}"
}

# Fonction utilitaire : Validation d'adresse IP
is_valid_ip() {
    local ip=$1
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ $ip =~ $regex ]]; then
        local IFS='.'
        local -a octets=($ip)
        for octet in "${octets[@]}"; do
            if [[ $octet -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Fonction utilitaire : Validation de nom d'hôte
is_valid_hostname() {
    local hostname=$1
    local regex='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
    
    [[ $hostname =~ $regex ]] && [[ ${#hostname} -le 253 ]]
}

# Fonction utilitaire : Génération d'ID unique
generate_uuid() {
    if command_exists uuidgen; then
        uuidgen
    else
        # Fallback simple
        date +%s%N | sha256sum | head -c 32
    fi
}

# Fonction utilitaire : Conversion en JSON sécurisé
to_json_string() {
    local input="$1"
    printf '%s' "$input" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g'
}

# Fonction utilitaire : Vérification de format JSON
is_valid_json() {
    local json_string="$1"
    echo "$json_string" | jq empty 2>/dev/null
}

# Fonction utilitaire : Timeout pour commandes
run_with_timeout() {
    local timeout_seconds=$1
    shift
    local command=("$@")
    
    timeout "$timeout_seconds" "${command[@]}"
}

# Export des fonctions pour utilisation dans les sous-shells
export -f command_exists
export -f file_exists
export -f dir_exists
export -f is_valid_ip
export -f is_valid_hostname
export -f to_json_string
export -f is_valid_json