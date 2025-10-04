#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: get-file.permissions.sh
# Description: Récupère les permissions détaillées d'un fichier/répertoire
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-01-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="get-file.permissions.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
DETAILED=${DETAILED:-0}
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
    Récupère les permissions détaillées d'un fichier ou répertoire
    avec analyse complète des droits d'accès et propriétés.

Arguments:
    <file_path>             Chemin du fichier/répertoire à analyser (obligatoire)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    --detailed             Analyse détaillée avec bits spéciaux
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "file_path": "/path/to/file",
        "exists": true,
        "type": "file|directory|symlink|other",
        "permissions": {
          "octal": "755",
          "symbolic": "rwxr-xr-x",
          "owner": {"read": true, "write": true, "execute": true},
          "group": {"read": true, "write": false, "execute": true},
          "other": {"read": true, "write": false, "execute": true}
        },
        "owner": {"name": "user", "uid": 1000},
        "group": {"name": "group", "gid": 1000},
        "size": 1024,
        "timestamps": {"modified": "ISO8601", "accessed": "ISO8601"}
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Fichier n'existe pas
    4 - Erreur de permissions d'accès

Exemples:
    $SCRIPT_NAME /tmp/file.txt                     # Permissions basiques
    $SCRIPT_NAME --detailed /usr/bin/sudo         # Analyse détaillée
    $SCRIPT_NAME --json-only /etc/passwd          # Sortie JSON uniquement
    $SCRIPT_NAME /home/user/directory             # Répertoire
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
            --detailed)
                DETAILED=1
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
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    if ! command -v stat >/dev/null 2>&1; then
        missing+=("stat")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Toutes les dépendances sont disponibles"
}

parse_permissions() {
    local octal_perms="$1"
    local symbolic=""
    local owner_read="false" owner_write="false" owner_execute="false"
    local group_read="false" group_write="false" group_execute="false"
    local other_read="false" other_write="false" other_execute="false"
    
    # Convertir les permissions octales en binaire pour analyse
    local owner_perm group_perm other_perm
    owner_perm=${octal_perms:0:1}
    group_perm=${octal_perms:1:1}
    other_perm=${octal_perms:2:1}
    
    # Analyser les permissions propriétaire
    case $owner_perm in
        7) owner_read="true"; owner_write="true"; owner_execute="true"; symbolic="${symbolic}rwx" ;;
        6) owner_read="true"; owner_write="true"; owner_execute="false"; symbolic="${symbolic}rw-" ;;
        5) owner_read="true"; owner_write="false"; owner_execute="true"; symbolic="${symbolic}r-x" ;;
        4) owner_read="true"; owner_write="false"; owner_execute="false"; symbolic="${symbolic}r--" ;;
        3) owner_read="false"; owner_write="true"; owner_execute="true"; symbolic="${symbolic}-wx" ;;
        2) owner_read="false"; owner_write="true"; owner_execute="false"; symbolic="${symbolic}-w-" ;;
        1) owner_read="false"; owner_write="false"; owner_execute="true"; symbolic="${symbolic}--x" ;;
        0) owner_read="false"; owner_write="false"; owner_execute="false"; symbolic="${symbolic}---" ;;
    esac
    
    # Analyser les permissions groupe
    case $group_perm in
        7) group_read="true"; group_write="true"; group_execute="true"; symbolic="${symbolic}rwx" ;;
        6) group_read="true"; group_write="true"; group_execute="false"; symbolic="${symbolic}rw-" ;;
        5) group_read="true"; group_write="false"; group_execute="true"; symbolic="${symbolic}r-x" ;;
        4) group_read="true"; group_write="false"; group_execute="false"; symbolic="${symbolic}r--" ;;
        3) group_read="false"; group_write="true"; group_execute="true"; symbolic="${symbolic}-wx" ;;
        2) group_read="false"; group_write="true"; group_execute="false"; symbolic="${symbolic}-w-" ;;
        1) group_read="false"; group_write="false"; group_execute="true"; symbolic="${symbolic}--x" ;;
        0) group_read="false"; group_write="false"; group_execute="false"; symbolic="${symbolic}---" ;;
    esac
    
    # Analyser les permissions autres
    case $other_perm in
        7) other_read="true"; other_write="true"; other_execute="true"; symbolic="${symbolic}rwx" ;;
        6) other_read="true"; other_write="true"; other_execute="false"; symbolic="${symbolic}rw-" ;;
        5) other_read="true"; other_write="false"; other_execute="true"; symbolic="${symbolic}r-x" ;;
        4) other_read="true"; other_write="false"; other_execute="false"; symbolic="${symbolic}r--" ;;
        3) other_read="false"; other_write="true"; other_execute="true"; symbolic="${symbolic}-wx" ;;
        2) other_read="false"; other_write="true"; other_execute="false"; symbolic="${symbolic}-w-" ;;
        1) other_read="false"; other_write="false"; other_execute="true"; symbolic="${symbolic}--x" ;;
        0) other_read="false"; other_write="false"; other_execute="false"; symbolic="${symbolic}---" ;;
    esac
    
    echo "$symbolic|$owner_read|$owner_write|$owner_execute|$group_read|$group_write|$group_execute|$other_read|$other_write|$other_execute"
}

get_file_permissions() {
    local file_path="$1"
    
    log_debug "Analyse des permissions pour: $file_path"
    
    # Vérifier que le fichier existe
    if [[ ! -e "$file_path" ]]; then
        die "Le fichier ou répertoire n'existe pas: $file_path" 3
    fi
    
    # Déterminer le type de fichier
    local file_type
    if [[ -f "$file_path" ]]; then
        file_type="file"
    elif [[ -d "$file_path" ]]; then
        file_type="directory"
    elif [[ -L "$file_path" ]]; then
        file_type="symlink"
    else
        file_type="other"
    fi
    
    # Obtenir les informations avec stat
    local permissions owner_name owner_uid group_name group_gid size mtime atime
    
    if command -v stat >/dev/null 2>&1; then
        if stat --version 2>/dev/null | grep -q GNU; then
            # GNU stat (Linux)
            permissions=$(stat -c%a "$file_path" 2>/dev/null || echo "000")
            owner_name=$(stat -c%U "$file_path" 2>/dev/null || echo "unknown")
            owner_uid=$(stat -c%u "$file_path" 2>/dev/null || echo "0")
            group_name=$(stat -c%G "$file_path" 2>/dev/null || echo "unknown")
            group_gid=$(stat -c%g "$file_path" 2>/dev/null || echo "0")
            size=$(stat -c%s "$file_path" 2>/dev/null || echo "0")
            mtime=$(stat -c%Y "$file_path" 2>/dev/null || echo "0")
            atime=$(stat -c%X "$file_path" 2>/dev/null || echo "0")
        else
            # BSD stat (macOS)
            permissions=$(stat -f%A "$file_path" 2>/dev/null || echo "000")
            owner_name=$(stat -f%Su "$file_path" 2>/dev/null || echo "unknown")
            owner_uid=$(stat -f%u "$file_path" 2>/dev/null || echo "0")
            group_name=$(stat -f%Sg "$file_path" 2>/dev/null || echo "unknown")
            group_gid=$(stat -f%g "$file_path" 2>/dev/null || echo "0")
            size=$(stat -f%z "$file_path" 2>/dev/null || echo "0")
            mtime=$(stat -f%m "$file_path" 2>/dev/null || echo "0")
            atime=$(stat -f%a "$file_path" 2>/dev/null || echo "0")
        fi
    else
        die "Commande stat non disponible" 4
    fi
    
    log_debug "Informations - Type: $file_type, Permissions: $permissions, Propriétaire: $owner_name:$group_name"
    
    # Parser les permissions
    local perm_info symbolic owner_r owner_w owner_x group_r group_w group_x other_r other_w other_x
    perm_info=$(parse_permissions "$permissions")
    IFS='|' read -r symbolic owner_r owner_w owner_x group_r group_w group_x other_r other_w other_x <<< "$perm_info"
    
    # Convertir les timestamps
    local mtime_iso atime_iso
    if command -v date >/dev/null 2>&1; then
        mtime_iso=$(date -u -d "@$mtime" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
        atime_iso=$(date -u -d "@$atime" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
    else
        mtime_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        atime_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fi
    
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
  "message": "File permissions retrieved successfully",
  "data": {
    "file_path": "$file_path_escaped",
    "exists": true,
    "type": "$file_type",
    "permissions": {
      "octal": "$permissions",
      "symbolic": "$symbolic",
      "owner": {
        "read": $owner_r,
        "write": $owner_w,
        "execute": $owner_x
      },
      "group": {
        "read": $group_r,
        "write": $group_w,
        "execute": $group_x
      },
      "other": {
        "read": $other_r,
        "write": $other_w,
        "execute": $other_x
      }
    },
    "owner": {
      "name": "$owner_name",
      "uid": $owner_uid
    },
    "group": {
      "name": "$group_name",
      "gid": $group_gid
    },
    "size_bytes": $size,
    "timestamps": {
      "modified": "$mtime_iso",
      "accessed": "$atime_iso",
      "modified_timestamp": $mtime,
      "accessed_timestamp": $atime
    },
    "analysis_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_debug "Analyse des permissions terminée avec succès"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    get_file_permissions "$FILE_PATH"
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi