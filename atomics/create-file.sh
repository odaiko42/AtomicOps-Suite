#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: create-file.sh
# Description: Crée un fichier avec contenu optionnel et gestion des permissions
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-01-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="create-file.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
FORCE=${FORCE:-0}
FILE_PATH=""
FILE_CONTENT=""
FILE_PERMISSIONS=""

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
    Crée un nouveau fichier avec contenu optionnel et gestion des permissions.
    Supporte la création de répertoires parents automatiquement.

Arguments:
    <file_path>             Chemin du fichier à créer (obligatoire)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -f, --force            Écraser le fichier s'il existe déjà
    -c, --content TEXT     Contenu à écrire dans le fichier
    -p, --permissions MODE Permissions du fichier (format octal, ex: 644)
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "file_path": "/path/to/file.txt",
        "created": true,
        "size_bytes": 1024,
        "permissions": "644",
        "owner": "user:group",
        "content_provided": true,
        "parent_dirs_created": true
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Fichier existe déjà (sans --force)
    4 - Erreur de permissions
    5 - Erreur d'écriture

Exemples:
    $SCRIPT_NAME /tmp/test.txt                     # Créer fichier vide
    $SCRIPT_NAME -c "Hello World" /tmp/hello.txt   # Avec contenu
    $SCRIPT_NAME -p 755 -f /usr/local/bin/script  # Avec permissions
    $SCRIPT_NAME --json-only /path/to/file         # Sortie JSON uniquement
    $SCRIPT_NAME --debug --content "Test" file.txt # Mode debug
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
            -c|--content)
                if [[ -n "${2:-}" ]]; then
                    FILE_CONTENT="$2"
                    shift 2
                else
                    die "Option --content requiert une valeur" 2
                fi
                ;;
            -p|--permissions)
                if [[ -n "${2:-}" ]]; then
                    FILE_PERMISSIONS="$2"
                    shift 2
                else
                    die "Option --permissions requiert une valeur" 2
                fi
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

    # Validation du format des permissions
    if [[ -n "$FILE_PERMISSIONS" ]]; then
        if ! [[ "$FILE_PERMISSIONS" =~ ^[0-7]{3,4}$ ]]; then
            die "Format de permissions invalide: $FILE_PERMISSIONS. Utilisez un format octal (ex: 644)" 2
        fi
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
    
    if ! command -v chmod >/dev/null 2>&1; then
        missing+=("chmod")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Toutes les dépendances sont disponibles"
}

validate_file_path() {
    local file_path="$1"
    
    log_debug "Validation du chemin de fichier: $file_path"
    
    # Vérifier si le fichier existe déjà
    if [[ -e "$file_path" ]]; then
        if [[ $FORCE -eq 0 ]]; then
            die "Le fichier existe déjà: $file_path. Utilisez --force pour écraser." 3
        else
            log_warn "Fichier existant sera écrasé: $file_path"
        fi
    fi
    
    # Vérifier si le répertoire parent existe ou peut être créé
    local parent_dir
    parent_dir=$(dirname "$file_path")
    
    if [[ ! -d "$parent_dir" ]]; then
        log_debug "Répertoire parent n'existe pas: $parent_dir"
        if ! mkdir -p "$parent_dir" 2>/dev/null; then
            die "Impossible de créer le répertoire parent: $parent_dir" 4
        else
            log_info "Répertoires parents créés: $parent_dir"
        fi
    fi
    
    # Vérifier les permissions d'écriture dans le répertoire parent
    if [[ ! -w "$parent_dir" ]]; then
        die "Pas de permission d'écriture dans le répertoire: $parent_dir" 4
    fi
    
    log_debug "Validation réussie pour: $file_path"
}

get_file_info() {
    local file_path="$1"
    
    if [[ ! -e "$file_path" ]]; then
        echo "0|||"
        return
    fi
    
    local size permissions owner
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
    
    echo "$size|$permissions|$owner|true"
}

create_file() {
    local file_path="$1"
    local content="$2"
    
    log_debug "Création du fichier: $file_path"
    log_debug "Contenu fourni: $([ -n "$content" ] && echo "oui" || echo "non")"
    
    # Vérifier si les répertoires parents ont été créés
    local parent_dir parent_dirs_created=false
    parent_dir=$(dirname "$file_path")
    
    if [[ ! -d "$parent_dir" ]]; then
        if mkdir -p "$parent_dir" 2>/dev/null; then
            parent_dirs_created=true
            log_info "Répertoires parents créés: $parent_dir"
        else
            die "Erreur lors de la création des répertoires parents: $parent_dir" 4
        fi
    fi
    
    # Créer le fichier avec le contenu
    if [[ -n "$content" ]]; then
        if ! echo "$content" > "$file_path" 2>/dev/null; then
            die "Erreur lors de l'écriture du contenu dans le fichier: $file_path" 5
        fi
    else
        if ! touch "$file_path" 2>/dev/null; then
            die "Erreur lors de la création du fichier: $file_path" 5
        fi
    fi
    
    log_debug "Fichier créé avec succès: $file_path"
    
    # Appliquer les permissions si spécifiées
    if [[ -n "$FILE_PERMISSIONS" ]]; then
        if ! chmod "$FILE_PERMISSIONS" "$file_path" 2>/dev/null; then
            log_warn "Erreur lors de l'application des permissions $FILE_PERMISSIONS au fichier: $file_path"
        else
            log_debug "Permissions appliquées: $FILE_PERMISSIONS"
        fi
    fi
    
    # Obtenir les informations finales du fichier
    local file_info size permissions owner
    file_info=$(get_file_info "$file_path")
    IFS='|' read -r size permissions owner _ <<< "$file_info"
    
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
  "message": "File created successfully",
  "data": {
    "file_path": "$file_path_escaped",
    "created": true,
    "size_bytes": $size,
    "permissions": "$permissions",
    "owner": "$owner",
    "content_provided": $([ -n "$content" ] && echo "true" || echo "false"),
    "parent_dirs_created": $([ $parent_dirs_created = true ] && echo "true" || echo "false"),
    "permissions_set": $([ -n "$FILE_PERMISSIONS" ] && echo "true" || echo "false"),
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_debug "Création de fichier terminée avec succès"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    validate_file_path "$FILE_PATH"
    create_file "$FILE_PATH" "$FILE_CONTENT"
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi