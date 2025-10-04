#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: create-directory.sh
# Description: Crée un répertoire avec permissions et création récursive
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-01-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="create-directory.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
FORCE=${FORCE:-0}
RECURSIVE=${RECURSIVE:-1}
DIRECTORY_PATH=""
DIR_PERMISSIONS=""

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
Usage: $SCRIPT_NAME [OPTIONS] <directory_path>

Description:
    Crée un nouveau répertoire avec support de création récursive et 
    gestion avancée des permissions.

Arguments:
    <directory_path>        Chemin du répertoire à créer (obligatoire)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -f, --force            Continuer si le répertoire existe déjà
    -p, --permissions MODE Permissions du répertoire (format octal, ex: 755)
    --no-recursive         Ne pas créer les répertoires parents
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "directory_path": "/path/to/directory",
        "created": true,
        "already_existed": false,
        "permissions": "755",
        "owner": "user:group",
        "parent_dirs_created": ["dir1", "dir2"],
        "recursive_used": true
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Répertoire existe déjà (sans --force)
    4 - Erreur de permissions
    5 - Erreur de création

Exemples:
    $SCRIPT_NAME /tmp/new_dir                      # Création simple
    $SCRIPT_NAME -p 750 /var/log/app               # Avec permissions
    $SCRIPT_NAME /deep/nested/path                 # Création récursive
    $SCRIPT_NAME --no-recursive single_dir         # Sans récursion
    $SCRIPT_NAME --json-only /path/to/dir          # Sortie JSON uniquement
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
            --no-recursive)
                RECURSIVE=0
                shift
                ;;
            -p|--permissions)
                if [[ -n "${2:-}" ]]; then
                    DIR_PERMISSIONS="$2"
                    shift 2
                else
                    die "Option --permissions requiert une valeur" 2
                fi
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                if [[ -z "$DIRECTORY_PATH" ]]; then
                    DIRECTORY_PATH="$1"
                else
                    die "Trop d'arguments. Chemin de répertoire déjà spécifié: $DIRECTORY_PATH" 2
                fi
                shift
                ;;
        esac
    done

    # Validation des paramètres obligatoires
    if [[ -z "$DIRECTORY_PATH" ]]; then
        die "Chemin de répertoire obligatoire manquant. Utilisez -h pour l'aide." 2
    fi

    # Validation du format des permissions
    if [[ -n "$DIR_PERMISSIONS" ]]; then
        if ! [[ "$DIR_PERMISSIONS" =~ ^[0-7]{3,4}$ ]]; then
            die "Format de permissions invalide: $DIR_PERMISSIONS. Utilisez un format octal (ex: 755)" 2
        fi
    fi
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    if ! command -v mkdir >/dev/null 2>&1; then
        missing+=("mkdir")
    fi
    
    if ! command -v stat >/dev/null 2>&1; then
        missing+=("stat")
    fi
    
    if ! command -v chmod >/dev/null 2>&1; then
        missing+=("chmod")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Toutes les dépendances sont disponibles"
}

get_directory_info() {
    local dir_path="$1"
    
    if [[ ! -d "$dir_path" ]]; then
        echo "000|unknown:unknown"
        return
    fi
    
    local permissions owner
    if command -v stat >/dev/null 2>&1; then
        if stat --version 2>/dev/null | grep -q GNU; then
            # GNU stat (Linux)
            permissions=$(stat -c%a "$dir_path" 2>/dev/null || echo "000")
            owner=$(stat -c%U:%G "$dir_path" 2>/dev/null || echo "unknown:unknown")
        else
            # BSD stat (macOS)
            permissions=$(stat -f%A "$dir_path" 2>/dev/null || echo "000")
            owner=$(stat -f%Su:%Sg "$dir_path" 2>/dev/null || echo "unknown:unknown")
        fi
    else
        permissions="755"
        owner="unknown:unknown"
    fi
    
    echo "$permissions|$owner"
}

find_missing_parent_dirs() {
    local target_path="$1"
    local missing_dirs=()
    local current_path="$target_path"
    
    # Remonter jusqu'à trouver un répertoire existant
    while [[ ! -d "$current_path" && "$current_path" != "/" ]]; do
        missing_dirs=("$(basename "$current_path")" "${missing_dirs[@]}")
        current_path=$(dirname "$current_path")
    done
    
    # Retourner la liste des répertoires manquants (du plus haut niveau au plus bas)
    if [[ ${#missing_dirs[@]} -gt 0 ]]; then
        printf '%s\n' "${missing_dirs[@]}"
    fi
}

create_directory() {
    local dir_path="$1"
    
    log_debug "Création du répertoire: $dir_path"
    
    local already_existed="false"
    local parent_dirs_created=()
    
    # Vérifier si le répertoire existe déjà
    if [[ -d "$dir_path" ]]; then
        if [[ $FORCE -eq 0 ]]; then
            die "Le répertoire existe déjà: $dir_path. Utilisez --force pour continuer." 3
        else
            already_existed="true"
            log_warn "Répertoire existe déjà: $dir_path"
        fi
    elif [[ -e "$dir_path" ]]; then
        die "Un fichier existe déjà à cet emplacement: $dir_path" 3
    fi
    
    # Si le répertoire n'existe pas encore, le créer
    if [[ ! -d "$dir_path" ]]; then
        # Identifier les répertoires parents manquants
        if [[ $RECURSIVE -eq 1 ]]; then
            while IFS= read -r missing_dir; do
                [[ -n "$missing_dir" ]] && parent_dirs_created+=("$missing_dir")
            done < <(find_missing_parent_dirs "$dir_path")
        fi
        
        # Construire les options mkdir
        local mkdir_options=""
        if [[ $RECURSIVE -eq 1 ]]; then
            mkdir_options="-p"
        fi
        
        # Créer le répertoire
        log_debug "Commande mkdir avec options: $mkdir_options"
        
        if ! mkdir $mkdir_options "$dir_path" 2>/dev/null; then
            die "Erreur lors de la création du répertoire: $dir_path" 5
        fi
        
        log_info "Répertoire créé avec succès: $dir_path"
        
        # Appliquer les permissions si spécifiées
        if [[ -n "$DIR_PERMISSIONS" ]]; then
            if ! chmod "$DIR_PERMISSIONS" "$dir_path" 2>/dev/null; then
                log_warn "Erreur lors de l'application des permissions $DIR_PERMISSIONS au répertoire: $dir_path"
            else
                log_debug "Permissions appliquées: $DIR_PERMISSIONS"
            fi
        fi
    fi
    
    # Obtenir les informations finales du répertoire
    local dir_info permissions owner
    dir_info=$(get_directory_info "$dir_path")
    IFS='|' read -r permissions owner <<< "$dir_info"
    
    # Construire la liste des répertoires parents créés pour JSON
    local parent_dirs_json="[]"
    if [[ ${#parent_dirs_created[@]} -gt 0 ]]; then
        local dirs_escaped=()
        for dir in "${parent_dirs_created[@]}"; do
            dirs_escaped+=("\"$(echo "$dir" | sed 's/\\/\\\\/g; s/"/\\"/g')\"")
        done
        parent_dirs_json="[$(IFS=','; echo "${dirs_escaped[*]}")]"
    fi
    
    # Échapper les caractères spéciaux pour JSON
    local dir_path_escaped
    dir_path_escaped=$(echo "$dir_path" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Directory created successfully",
  "data": {
    "directory_path": "$dir_path_escaped",
    "created": $([ "$already_existed" == "false" ] && echo "true" || echo "false"),
    "already_existed": $already_existed,
    "permissions": "$permissions",
    "owner": "$owner",
    "parent_dirs_created": $parent_dirs_json,
    "recursive_used": $([ $RECURSIVE -eq 1 ] && echo "true" || echo "false"),
    "permissions_set": $([ -n "$DIR_PERMISSIONS" ] && echo "true" || echo "false"),
    "creation_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_debug "Création de répertoire terminée avec succès"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    create_directory "$DIRECTORY_PATH"
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi