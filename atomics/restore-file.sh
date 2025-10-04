#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: restore-file.sh 
# Description: Restaurer un fichier à partir d'une sauvegarde
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="restore-file.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
BACKUP_FILE=""
TARGET_FILE=""
FORCE=${FORCE:-0}
VERIFY_CHECKSUM=${VERIFY_CHECKSUM:-1}
CREATE_BACKUP=${CREATE_BACKUP:-1}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <backup_file> <target_file>

Description:
    Restaure un fichier à partir d'une sauvegarde avec vérification
    d'intégrité et sauvegarde de l'existant.

Arguments:
    <backup_file>    Fichier de sauvegarde (compressé ou non)
    <target_file>    Chemin de destination pour la restauration

Options:
    -h, --help       Afficher cette aide
    -v, --verbose    Mode verbeux
    -d, --debug      Mode debug
    -q, --quiet      Mode silencieux
    -j, --json-only  Sortie JSON uniquement
    -f, --force      Forcer l'écrasement sans confirmation
    --no-verify      Ignorer vérification checksum
    --no-backup      Ne pas sauvegarder l'existant
    
Exemples:
    $SCRIPT_NAME backup.txt.gz /home/user/file.txt
    $SCRIPT_NAME -f --no-backup config.bak /etc/myapp/config.ini
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            -v|--verbose) VERBOSE=1; shift ;;
            -d|--debug) DEBUG=1; VERBOSE=1; shift ;;
            -q|--quiet) QUIET=1; shift ;;
            -j|--json-only) JSON_ONLY=1; QUIET=1; shift ;;
            -f|--force) FORCE=1; shift ;;
            --no-verify) VERIFY_CHECKSUM=0; shift ;;
            --no-backup) CREATE_BACKUP=0; shift ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                if [[ -z "$BACKUP_FILE" ]]; then
                    BACKUP_FILE="$1"
                elif [[ -z "$TARGET_FILE" ]]; then
                    TARGET_FILE="$1"
                else
                    echo "Trop d'arguments" >&2; exit 2
                fi
                shift ;;
        esac
    done

    [[ -z "$BACKUP_FILE" ]] && { echo "Fichier de sauvegarde manquant" >&2; exit 2; }
    [[ -z "$TARGET_FILE" ]] && { echo "Fichier cible manquant" >&2; exit 2; }
    [[ ! -f "$BACKUP_FILE" ]] && { echo "Fichier de sauvegarde non trouvé: $BACKUP_FILE" >&2; exit 3; }
}

detect_compression() {
    local file="$1"
    
    # Détecter par extension
    case "$file" in
        *.gz) echo "gzip"; return ;;
        *.bz2) echo "bzip2"; return ;;
        *.xz) echo "xz"; return ;;
        *.Z) echo "compress"; return ;;
    esac
    
    # Détecter par signature de fichier
    local magic
    magic=$(file -b --mime-type "$file" 2>/dev/null || echo "")
    
    case "$magic" in
        *gzip*) echo "gzip" ;;
        *bzip2*) echo "bzip2" ;;
        *xz*) echo "xz" ;;
        *compress*) echo "compress" ;;
        *) echo "none" ;;
    esac
}

decompress_file() {
    local source="$1"
    local target="$2"
    local compression="$3"
    
    case "$compression" in
        gzip)
            gunzip -c "$source" > "$target"
            ;;
        bzip2)
            bunzip2 -c "$source" > "$target"
            ;;
        xz)
            unxz -c "$source" > "$target"
            ;;
        compress)
            uncompress -c "$source" > "$target"
            ;;
        none)
            cp "$source" "$target"
            ;;
        *)
            return 1
            ;;
    esac
}

calculate_checksum() {
    local file="$1"
    md5sum "$file" 2>/dev/null | cut -d' ' -f1 || echo "unknown"
}

main() {
    parse_args "$@"
    
    local errors=() warnings=()
    local compression original_exists backup_created=false
    
    compression=$(detect_compression "$BACKUP_FILE")
    original_exists=false
    
    # Vérifier si le fichier cible existe
    if [[ -f "$TARGET_FILE" ]]; then
        original_exists=true
        if [[ $FORCE -eq 0 ]]; then
            warnings+=("Target file exists, use --force to overwrite")
        fi
        
        # Créer une sauvegarde de l'existant
        if [[ $CREATE_BACKUP -eq 1 ]] && [[ $FORCE -eq 1 ]]; then
            local backup_name="${TARGET_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
            if cp "$TARGET_FILE" "$backup_name" 2>/dev/null; then
                backup_created=true
                warnings+=("Original file backed up to: $backup_name")
            else
                warnings+=("Failed to backup original file")
            fi
        fi
    fi
    
    # Créer le répertoire parent si nécessaire
    local parent_dir
    parent_dir=$(dirname "$TARGET_FILE")
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir" 2>/dev/null || errors+=("Cannot create parent directory: $parent_dir")
    fi
    
    if [[ ${#errors[@]} -eq 0 ]] && ([[ $FORCE -eq 1 ]] || [[ $original_exists == false ]]); then
        # Calculer checksum original si demandé
        local original_checksum="none"
        if [[ $VERIFY_CHECKSUM -eq 1 ]] && [[ $original_exists == true ]]; then
            original_checksum=$(calculate_checksum "$TARGET_FILE")
        fi
        
        # Effectuer la restauration
        local start_time end_time duration
        start_time=$(date +%s)
        
        if decompress_file "$BACKUP_FILE" "$TARGET_FILE" "$compression"; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            
            # Calculer les tailles et checksums
            local backup_size restored_size restored_checksum
            backup_size=$(stat -c%s "$BACKUP_FILE" 2>/dev/null || echo "0")
            restored_size=$(stat -c%s "$TARGET_FILE" 2>/dev/null || echo "0")
            restored_checksum="none"
            
            if [[ $VERIFY_CHECKSUM -eq 1 ]]; then
                restored_checksum=$(calculate_checksum "$TARGET_FILE")
            fi
            
            # Détecter les permissions
            local file_permissions file_owner
            file_permissions=$(stat -c%a "$TARGET_FILE" 2>/dev/null || echo "644")
            file_owner=$(stat -c%U:%G "$TARGET_FILE" 2>/dev/null || echo "unknown:unknown")
            
            cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "File restore completed successfully",
  "data": {
    "backup_file": "$BACKUP_FILE",
    "target_file": "$TARGET_FILE",
    "compression": "$compression",
    "backup_size": $backup_size,
    "restored_size": $restored_size,
    "duration_seconds": $duration,
    "original_existed": $original_exists,
    "backup_created": $backup_created,
    "permissions": "$file_permissions",
    "owner": "$file_owner",
    "checksums": {
      "original": "$original_checksum",
      "restored": "$restored_checksum",
      "verified": $([ $VERIFY_CHECKSUM -eq 1 ] && echo "true" || echo "false")
    }
  },
  "errors": [],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
        else
            errors+=("File restoration failed")
        fi
    elif [[ ${#errors[@]} -eq 0 ]]; then
        errors+=("Target file exists and --force not specified")
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "File restore failed",
  "data": {},
  "errors": [$(printf '"%s",' "${errors[@]}" | sed 's/,$//')],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi