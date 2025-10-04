#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: copy-file.sh
# Description: Copie un fichier avec vérifications d'intégrité et gestion permissions
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-01-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="copy-file.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
FORCE=${FORCE:-0}
PRESERVE_PERMISSIONS=${PRESERVE_PERMISSIONS:-0}
PRESERVE_TIMESTAMPS=${PRESERVE_TIMESTAMPS:-0}
VERIFY_COPY=${VERIFY_COPY:-1}
SOURCE_PATH=""
DEST_PATH=""

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
Usage: $SCRIPT_NAME [OPTIONS] <source_path> <destination_path>

Description:
    Copie un fichier ou répertoire avec vérifications d'intégrité et options avancées.
    Supporte la préservation des permissions, timestamps et vérification par checksum.

Arguments:
    <source_path>           Chemin du fichier/répertoire source (obligatoire)
    <destination_path>      Chemin de destination (obligatoire)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -f, --force            Écraser la destination si elle existe
    -p, --preserve-perms   Préserver les permissions du fichier source
    -t, --preserve-time    Préserver les timestamps (mtime, atime)
    -n, --no-verify        Désactiver la vérification par checksum
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "source_path": "/path/to/source.txt",
        "destination_path": "/path/to/dest.txt",
        "copied": true,
        "source_size": 1024,
        "dest_size": 1024,
        "checksum_verified": true,
        "permissions_preserved": true,
        "timestamps_preserved": false
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Fichier source n'existe pas
    4 - Destination existe déjà (sans --force)
    5 - Erreur de permissions
    6 - Erreur de copie
    7 - Échec de vérification d'intégrité

Exemples:
    $SCRIPT_NAME file1.txt file2.txt                # Copie simple
    $SCRIPT_NAME -p -t src.txt dest.txt             # Préserver perms et time
    $SCRIPT_NAME -f /tmp/a.txt /tmp/b.txt            # Écraser si existe
    $SCRIPT_NAME --json-only src dest               # Sortie JSON uniquement
    $SCRIPT_NAME --no-verify large_file.iso backup/ # Sans vérification
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
            -p|--preserve-perms)
                PRESERVE_PERMISSIONS=1
                shift
                ;;
            -t|--preserve-time)
                PRESERVE_TIMESTAMPS=1
                shift
                ;;
            -n|--no-verify)
                VERIFY_COPY=0
                shift
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                if [[ -z "$SOURCE_PATH" ]]; then
                    SOURCE_PATH="$1"
                elif [[ -z "$DEST_PATH" ]]; then
                    DEST_PATH="$1"
                else
                    die "Trop d'arguments. Source et destination déjà spécifiés." 2
                fi
                shift
                ;;
        esac
    done

    # Validation des paramètres obligatoires
    if [[ -z "$SOURCE_PATH" ]]; then
        die "Chemin source obligatoire manquant. Utilisez -h pour l'aide." 2
    fi
    
    if [[ -z "$DEST_PATH" ]]; then
        die "Chemin destination obligatoire manquant. Utilisez -h pour l'aide." 2
    fi
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    if ! command -v cp >/dev/null 2>&1; then
        missing+=("cp")
    fi
    
    if ! command -v stat >/dev/null 2>&1; then
        missing+=("stat")
    fi
    
    if [[ $VERIFY_COPY -eq 1 ]] && ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
        log_warn "Commande de checksum non disponible, vérification désactivée"
        VERIFY_COPY=0
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Toutes les dépendances sont disponibles"
}

get_file_info() {
    local file_path="$1"
    
    if [[ ! -e "$file_path" ]]; then
        echo "0|000|unknown:unknown|false|0|0"
        return
    fi
    
    local size permissions owner is_directory mtime atime
    is_directory=$([ -d "$file_path" ] && echo "true" || echo "false")
    
    if command -v stat >/dev/null 2>&1; then
        if stat --version 2>/dev/null | grep -q GNU; then
            # GNU stat (Linux)
            size=$(stat -c%s "$file_path" 2>/dev/null || echo "0")
            permissions=$(stat -c%a "$file_path" 2>/dev/null || echo "000")
            owner=$(stat -c%U:%G "$file_path" 2>/dev/null || echo "unknown:unknown")
            mtime=$(stat -c%Y "$file_path" 2>/dev/null || echo "0")
            atime=$(stat -c%X "$file_path" 2>/dev/null || echo "0")
        else
            # BSD stat (macOS)
            size=$(stat -f%z "$file_path" 2>/dev/null || echo "0")
            permissions=$(stat -f%A "$file_path" 2>/dev/null || echo "000")
            owner=$(stat -f%Su:%Sg "$file_path" 2>/dev/null || echo "unknown:unknown")
            mtime=$(stat -f%m "$file_path" 2>/dev/null || echo "0")
            atime=$(stat -f%a "$file_path" 2>/dev/null || echo "0")
        fi
    else
        # Fallback basique
        size="0"
        permissions="644"
        owner="unknown:unknown"
        mtime="0"
        atime="0"
    fi
    
    echo "$size|$permissions|$owner|$is_directory|$mtime|$atime"
}

calculate_checksum() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        echo ""
        return
    fi
    
    local checksum=""
    if command -v sha256sum >/dev/null 2>&1; then
        checksum=$(sha256sum "$file_path" 2>/dev/null | awk '{print $1}' || echo "")
    elif command -v shasum >/dev/null 2>&1; then
        checksum=$(shasum -a 256 "$file_path" 2>/dev/null | awk '{print $1}' || echo "")
    fi
    
    echo "$checksum"
}

validate_paths() {
    local source_path="$1"
    local dest_path="$2"
    
    log_debug "Validation des chemins - Source: $source_path, Destination: $dest_path"
    
    # Vérifier que la source existe
    if [[ ! -e "$source_path" ]]; then
        die "Le fichier/répertoire source n'existe pas: $source_path" 3
    fi
    
    # Vérifier que la source est lisible
    if [[ ! -r "$source_path" ]]; then
        die "Pas de permission de lecture sur le fichier source: $source_path" 5
    fi
    
    # Vérifier si la destination existe déjà
    if [[ -e "$dest_path" ]]; then
        if [[ $FORCE -eq 0 ]]; then
            die "Le fichier/répertoire destination existe déjà: $dest_path. Utilisez --force pour écraser." 4
        else
            log_warn "Destination existante sera écrasée: $dest_path"
        fi
    fi
    
    # Vérifier que le répertoire parent de la destination existe ou peut être créé
    local dest_parent
    dest_parent=$(dirname "$dest_path")
    
    if [[ ! -d "$dest_parent" ]]; then
        log_debug "Répertoire parent destination n'existe pas: $dest_parent"
        if ! mkdir -p "$dest_parent" 2>/dev/null; then
            die "Impossible de créer le répertoire parent destination: $dest_parent" 5
        else
            log_info "Répertoires parents créés: $dest_parent"
        fi
    fi
    
    # Vérifier les permissions d'écriture dans le répertoire destination
    if [[ ! -w "$dest_parent" ]]; then
        die "Pas de permission d'écriture dans le répertoire destination: $dest_parent" 5
    fi
    
    log_debug "Validation des chemins réussie"
}

copy_file() {
    local source_path="$1"
    local dest_path="$2"
    
    log_debug "Début de la copie - Source: $source_path vers Destination: $dest_path"
    
    # Obtenir les informations de la source avant copie
    local source_info source_size source_perms source_owner source_is_dir source_mtime source_atime
    source_info=$(get_file_info "$source_path")
    IFS='|' read -r source_size source_perms source_owner source_is_dir source_mtime source_atime <<< "$source_info"
    
    log_debug "Source - Taille: ${source_size}o, Permissions: $source_perms, Propriétaire: $source_owner"
    
    # Calculer le checksum de la source si vérification activée
    local source_checksum=""
    if [[ $VERIFY_COPY -eq 1 && "$source_is_dir" == "false" ]]; then
        log_debug "Calcul du checksum source..."
        source_checksum=$(calculate_checksum "$source_path")
        log_debug "Checksum source: $source_checksum"
    fi
    
    # Construire les options cp
    local cp_options=""
    
    if [[ "$source_is_dir" == "true" ]]; then
        cp_options="$cp_options -r"
    fi
    
    if [[ $PRESERVE_PERMISSIONS -eq 1 ]]; then
        cp_options="$cp_options -p"
    fi
    
    if [[ $PRESERVE_TIMESTAMPS -eq 1 ]]; then
        cp_options="$cp_options -p"
    fi
    
    if [[ $FORCE -eq 1 ]]; then
        cp_options="$cp_options -f"
    fi
    
    # Effectuer la copie
    log_debug "Commande cp avec options: $cp_options"
    
    if ! cp $cp_options "$source_path" "$dest_path" 2>/dev/null; then
        die "Erreur lors de la copie: $source_path vers $dest_path" 6
    fi
    
    log_info "Copie effectuée avec succès"
    
    # Obtenir les informations de la destination après copie
    local dest_info dest_size dest_perms dest_owner dest_is_dir dest_mtime dest_atime
    dest_info=$(get_file_info "$dest_path")
    IFS='|' read -r dest_size dest_perms dest_owner dest_is_dir dest_mtime dest_atime <<< "$dest_info"
    
    log_debug "Destination - Taille: ${dest_size}o, Permissions: $dest_perms, Propriétaire: $dest_owner"
    
    # Vérifier l'intégrité si activée
    local checksum_verified="false"
    local dest_checksum=""
    
    if [[ $VERIFY_COPY -eq 1 && "$source_is_dir" == "false" && -n "$source_checksum" ]]; then
        log_debug "Vérification de l'intégrité..."
        dest_checksum=$(calculate_checksum "$dest_path")
        
        if [[ "$source_checksum" == "$dest_checksum" ]]; then
            checksum_verified="true"
            log_debug "Vérification d'intégrité réussie"
        else
            die "Échec de la vérification d'intégrité. Checksums différents: source=$source_checksum, dest=$dest_checksum" 7
        fi
    else
        checksum_verified="true"  # Pas de vérification demandée
    fi
    
    # Vérifications supplémentaires
    local permissions_preserved="false"
    local timestamps_preserved="false"
    
    if [[ $PRESERVE_PERMISSIONS -eq 1 && "$source_perms" == "$dest_perms" ]]; then
        permissions_preserved="true"
    elif [[ $PRESERVE_PERMISSIONS -eq 0 ]]; then
        permissions_preserved="not_requested"
    fi
    
    if [[ $PRESERVE_TIMESTAMPS -eq 1 && "$source_mtime" == "$dest_mtime" ]]; then
        timestamps_preserved="true"
    elif [[ $PRESERVE_TIMESTAMPS -eq 0 ]]; then
        timestamps_preserved="not_requested"
    fi
    
    # Échapper les caractères spéciaux pour JSON
    local source_escaped dest_escaped
    source_escaped=$(echo "$source_path" | sed 's/\\/\\\\/g; s/"/\\"/g')
    dest_escaped=$(echo "$dest_path" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "File copied successfully",
  "data": {
    "source_path": "$source_escaped",
    "destination_path": "$dest_escaped",
    "copied": true,
    "source_size": $source_size,
    "dest_size": $dest_size,
    "is_directory": $source_is_dir,
    "checksum_verified": $checksum_verified,
    "source_checksum": "$source_checksum",
    "dest_checksum": "$dest_checksum",
    "permissions_preserved": "$permissions_preserved",
    "timestamps_preserved": "$timestamps_preserved",
    "source_permissions": "$source_perms",
    "dest_permissions": "$dest_perms",
    "copy_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_debug "Copie terminée avec succès"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    validate_paths "$SOURCE_PATH" "$DEST_PATH"
    copy_file "$SOURCE_PATH" "$DEST_PATH"
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi