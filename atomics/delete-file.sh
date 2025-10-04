#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: delete-file.sh
# Description: Supprime un fichier avec vérifications de sécurité et confirmation
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-01-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="delete-file.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
FORCE=${FORCE:-0}
RECURSIVE=${RECURSIVE:-0}
NO_CONFIRM=${NO_CONFIRM:-0}
FILE_PATH=""

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
Usage: $SCRIPT_NAME [OPTIONS] <file_path>

Description:
    Supprime un fichier ou répertoire avec vérifications de sécurité.
    Demande confirmation par défaut pour éviter les suppressions accidentelles.

Arguments:
    <file_path>             Chemin du fichier/répertoire à supprimer (obligatoire)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -f, --force            Supprimer sans demander confirmation
    -r, --recursive        Supprimer récursivement (répertoires)
    -y, --yes              Répondre automatiquement 'oui' à la confirmation
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "file_path": "/path/to/file.txt",
        "deleted": true,
        "was_directory": false,
        "size_bytes": 1024,
        "permissions": "644",
        "owner": "user:group",
        "deletion_time": "ISO8601"
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Fichier n'existe pas
    4 - Erreur de permissions
    5 - Suppression annulée par l'utilisateur
    6 - Protection système (fichiers critiques)

Sécurité:
    - Refuse de supprimer certains répertoires système (/etc, /usr, /bin, etc.)
    - Demande confirmation pour les fichiers importants
    - Vérifie les permissions avant suppression
    - Mode --force pour contourner les confirmations

Exemples:
    $SCRIPT_NAME /tmp/test.txt                     # Supprimer avec confirmation
    $SCRIPT_NAME --force /tmp/unwanted.log         # Supprimer sans confirmation
    $SCRIPT_NAME -r /tmp/test_directory            # Supprimer répertoire
    $SCRIPT_NAME --json-only /path/to/file         # Sortie JSON uniquement
    $SCRIPT_NAME --debug /tmp/file.txt             # Mode debug
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
            -r|--recursive)
                RECURSIVE=1
                shift
                ;;
            -y|--yes)
                NO_CONFIRM=1
                shift
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                if [[ -z "$FILE_PATH" ]]; then
                    FILE_PATH="$1"
                else
                    die "Trop d'arguments. Chemin de fichier déjà spécifié: $FILE_PATH" 2
                fi
                shift
                ;;
        esac
    done

    # Validation des paramètres obligatoires
    if [[ -z "$FILE_PATH" ]]; then
        die "Chemin de fichier obligatoire manquant. Utilisez -h pour l'aide." 2
    fi

    # Convertir en chemin absolu pour les vérifications de sécurité
    FILE_PATH=$(realpath "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    if ! command -v rm >/dev/null 2>&1; then
        missing+=("rm")
    fi
    
    if ! command -v stat >/dev/null 2>&1; then
        missing+=("stat")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Toutes les dépendances sont disponibles"
}

get_file_info() {
    local file_path="$1"
    
    if [[ ! -e "$file_path" ]]; then
        echo "0|000|unknown:unknown|false"
        return
    fi
    
    local size permissions owner is_directory
    is_directory=$([ -d "$file_path" ] && echo "true" || echo "false")
    
    if command -v stat >/dev/null 2>&1; then
        # Utiliser stat pour obtenir les informations
        if stat --version 2>/dev/null | grep -q GNU; then
            # GNU stat (Linux)
            size=$(stat -c%s "$file_path" 2>/dev/null || echo "0")
            permissions=$(stat -c%a "$file_path" 2>/dev/null || echo "000")
            owner=$(stat -c%U:%G "$file_path" 2>/dev/null || echo "unknown:unknown")
        else
            # BSD stat (macOS)
            size=$(stat -f%z "$file_path" 2>/dev/null || echo "0")
            permissions=$(stat -f%A "$file_path" 2>/dev/null || echo "000")
            owner=$(stat -f%Su:%Sg "$file_path" 2>/dev/null || echo "unknown:unknown")
        fi
    else
        # Fallback avec ls
        local ls_info
        ls_info=$(ls -la "$file_path" 2>/dev/null || echo "")
        size=$(echo "$ls_info" | awk '{print $5}' || echo "0")
        permissions="644"  # Valeur par défaut
        owner="unknown:unknown"
    fi
    
    echo "$size|$permissions|$owner|$is_directory"
}

check_system_protection() {
    local file_path="$1"
    
    log_debug "Vérification des protections système pour: $file_path"
    
    # Liste des répertoires système protégés
    local protected_dirs=(
        "/"
        "/bin"
        "/sbin" 
        "/usr"
        "/etc"
        "/boot"
        "/sys"
        "/proc"
        "/dev"
        "/lib"
        "/lib64"
        "/var/log"
        "/var/lib"
    )
    
    # Vérifier si le chemin correspond à un répertoire protégé
    for protected in "${protected_dirs[@]}"; do
        if [[ "$file_path" == "$protected" || "$file_path" == "$protected"/* ]]; then
            # Exception pour /tmp et /var/tmp qui sont sûrs
            if [[ "$file_path" == "/tmp"/* || "$file_path" == "/var/tmp"/* ]]; then
                continue
            fi
            
            log_warn "Répertoire système protégé détecté: $file_path"
            if [[ $FORCE -eq 0 ]]; then
                die "Refus de supprimer un répertoire système protégé: $file_path. Utilisez --force si vraiment nécessaire." 6
            fi
        fi
    done
    
    # Vérifier les fichiers système critiques
    local critical_files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/sudoers"
        "/etc/fstab"
        "/boot/vmlinuz"*
        "/boot/initrd"*
    )
    
    for critical in "${critical_files[@]}"; do
        if [[ "$file_path" == $critical ]]; then
            log_warn "Fichier système critique détecté: $file_path"
            if [[ $FORCE -eq 0 ]]; then
                die "Refus de supprimer un fichier système critique: $file_path. Utilisez --force si vraiment nécessaire." 6
            fi
        fi
    done
    
    log_debug "Vérifications de sécurité passées pour: $file_path"
}

ask_confirmation() {
    local file_path="$1"
    local is_directory="$2"
    
    # Pas de confirmation en mode --yes, --force, ou --json-only
    if [[ $NO_CONFIRM -eq 1 || $FORCE -eq 1 || $JSON_ONLY -eq 1 ]]; then
        return 0
    fi
    
    local file_type="fichier"
    [[ "$is_directory" == "true" ]] && file_type="répertoire"
    
    echo -n "Voulez-vous vraiment supprimer ce $file_type : $file_path ? [y/N] " >&2
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

delete_file() {
    local file_path="$1"
    
    log_debug "Tentative de suppression: $file_path"
    
    # Vérifier que le fichier/répertoire existe
    if [[ ! -e "$file_path" ]]; then
        die "Le fichier ou répertoire n'existe pas: $file_path" 3
    fi
    
    # Obtenir les informations avant suppression
    local file_info size permissions owner is_directory
    file_info=$(get_file_info "$file_path")
    IFS='|' read -r size permissions owner is_directory <<< "$file_info"
    
    log_debug "Informations fichier - Taille: ${size}o, Permissions: $permissions, Propriétaire: $owner, Répertoire: $is_directory"
    
    # Vérifications de sécurité
    check_system_protection "$file_path"
    
    # Demander confirmation si nécessaire
    if ! ask_confirmation "$file_path" "$is_directory"; then
        die "Suppression annulée par l'utilisateur" 5
    fi
    
    # Construire les options rm
    local rm_options=""
    
    if [[ "$is_directory" == "true" ]]; then
        if [[ $RECURSIVE -eq 1 ]]; then
            rm_options="-r"
        else
            die "Le chemin est un répertoire. Utilisez --recursive pour le supprimer: $file_path" 2
        fi
    fi
    
    if [[ $FORCE -eq 1 ]]; then
        rm_options="$rm_options -f"
    fi
    
    # Supprimer le fichier/répertoire
    log_debug "Commande rm avec options: $rm_options"
    
    if ! rm $rm_options "$file_path" 2>/dev/null; then
        die "Erreur lors de la suppression: $file_path" 4
    fi
    
    log_info "Suppression réussie: $file_path"
    
    # Échapper les caractères spéciaux pour JSON
    local file_path_escaped
    file_path_escaped=$(echo "$file_path" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "File deleted successfully",
  "data": {
    "file_path": "$file_path_escaped",
    "deleted": true,
    "was_directory": $is_directory,
    "size_bytes": $size,
    "permissions": "$permissions",
    "owner": "$owner",
    "deletion_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "force_used": $([ $FORCE -eq 1 ] && echo "true" || echo "false"),
    "recursive_used": $([ $RECURSIVE -eq 1 ] && echo "true" || echo "false")
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_debug "Suppression terminée avec succès"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    delete_file "$FILE_PATH"
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi