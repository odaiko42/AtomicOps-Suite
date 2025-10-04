#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: restore-directory.sh 
# Description: Restaurer un répertoire à partir d'une sauvegarde
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="restore-directory.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
BACKUP_FILE=""
TARGET_DIR=""
FORCE=${FORCE:-0}
PRESERVE_PERMISSIONS=${PRESERVE_PERMISSIONS:-1}
OVERWRITE=${OVERWRITE:-0}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <backup_file> <target_directory>

Description:
    Restaure un répertoire complet à partir d'une archive de sauvegarde
    avec préservation des permissions et vérifications de sécurité.

Arguments:
    <backup_file>        Archive de sauvegarde (tar.gz, tar.bz2, tar.xz, tar)
    <target_directory>   Répertoire de destination pour la restauration

Options:
    -h, --help          Afficher cette aide
    -v, --verbose       Mode verbeux
    -d, --debug         Mode debug
    -q, --quiet         Mode silencieux
    -j, --json-only     Sortie JSON uniquement
    -f, --force         Forcer la restauration même si le répertoire existe
    --no-preserve       Ne pas préserver les permissions originales
    --overwrite         Écraser les fichiers existants
    
Exemples:
    $SCRIPT_NAME backup.tar.gz /home/user/restored
    $SCRIPT_NAME -f --overwrite backup.tar.bz2 /var/www
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
            --no-preserve) PRESERVE_PERMISSIONS=0; shift ;;
            --overwrite) OVERWRITE=1; shift ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                if [[ -z "$BACKUP_FILE" ]]; then
                    BACKUP_FILE="$1"
                elif [[ -z "$TARGET_DIR" ]]; then
                    TARGET_DIR="$1"
                else
                    echo "Trop d'arguments" >&2; exit 2
                fi
                shift ;;
        esac
    done

    [[ -z "$BACKUP_FILE" ]] && { echo "Fichier de sauvegarde manquant" >&2; exit 2; }
    [[ -z "$TARGET_DIR" ]] && { echo "Répertoire cible manquant" >&2; exit 2; }
    [[ ! -f "$BACKUP_FILE" ]] && { echo "Fichier de sauvegarde non trouvé: $BACKUP_FILE" >&2; exit 3; }
}

check_archive_type() {
    local file="$1"
    case "$file" in
        *.tar.gz|*.tgz) echo "gzip" ;;
        *.tar.bz2|*.tbz2) echo "bzip2" ;;
        *.tar.xz|*.txz) echo "xz" ;;
        *.tar) echo "tar" ;;
        *) echo "unknown" ;;
    esac
}

verify_archive() {
    local file="$1"
    local type="$2"
    
    case "$type" in
        gzip) gzip -t "$file" 2>/dev/null ;;
        bzip2) bzip2 -t "$file" 2>/dev/null ;;
        xz) xz -t "$file" 2>/dev/null ;;
        tar|*) tar -tf "$file" >/dev/null 2>&1 ;;
    esac
}

main() {
    parse_args "$@"
    
    local errors=() warnings=()
    local archive_type
    archive_type=$(check_archive_type "$BACKUP_FILE")
    
    # Vérifier le type d'archive
    if [[ "$archive_type" == "unknown" ]]; then
        errors+=("Unsupported archive format: $BACKUP_FILE")
    fi
    
    # Vérifier l'intégrité de l'archive
    if [[ ${#errors[@]} -eq 0 ]] && ! verify_archive "$BACKUP_FILE" "$archive_type"; then
        errors+=("Archive integrity check failed")
    fi
    
    # Vérifier si le répertoire cible existe
    if [[ -d "$TARGET_DIR" ]] && [[ $FORCE -eq 0 ]]; then
        warnings+=("Target directory exists, use --force to proceed")
        if [[ $OVERWRITE -eq 0 ]]; then
            errors+=("Target directory exists and --overwrite not specified")
        fi
    fi
    
    # Créer le répertoire parent si nécessaire
    local parent_dir
    parent_dir=$(dirname "$TARGET_DIR")
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir" 2>/dev/null || errors+=("Cannot create parent directory: $parent_dir")
    fi
    
    # Vérifier l'espace disque
    local archive_size available_space
    archive_size=$(stat -c%s "$BACKUP_FILE" 2>/dev/null || echo "0")
    available_space=$(df "$parent_dir" | awk 'NR==2 {print $4 * 1024}')
    
    if [[ $archive_size -gt $available_space ]]; then
        warnings+=("Insufficient disk space might be available")
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        # Créer le répertoire cible
        mkdir -p "$TARGET_DIR"
        
        # Construire la commande tar
        local tar_cmd="tar"
        local tar_flags=""
        
        case "$archive_type" in
            gzip) tar_flags="-xzf" ;;
            bzip2) tar_flags="-xjf" ;;
            xz) tar_flags="-xJf" ;;
            tar) tar_flags="-xf" ;;
        esac
        
        [[ $PRESERVE_PERMISSIONS -eq 1 ]] && tar_flags+="p"
        [[ $VERBOSE -eq 1 ]] && tar_flags+="v"
        [[ $OVERWRITE -eq 1 ]] && tar_flags+="" # tar écrase par défaut
        
        tar_cmd+=" $tar_flags \"$BACKUP_FILE\" -C \"$TARGET_DIR\""
        
        # Exécuter la restauration
        local start_time end_time duration files_count
        start_time=$(date +%s)
        
        if eval "$tar_cmd" >/dev/null 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            files_count=$(find "$TARGET_DIR" -type f | wc -l)
            
            # Calculer la taille restaurée
            local restored_size
            restored_size=$(du -sb "$TARGET_DIR" | cut -f1)
            
            cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Directory restore completed successfully",
  "data": {
    "backup_file": "$BACKUP_FILE",
    "target_directory": "$TARGET_DIR",
    "archive_type": "$archive_type",
    "archive_size": $archive_size,
    "restored_size": $restored_size,
    "files_restored": $files_count,
    "duration_seconds": $duration,
    "permissions_preserved": $([ $PRESERVE_PERMISSIONS -eq 1 ] && echo "true" || echo "false"),
    "overwrite_mode": $([ $OVERWRITE -eq 1 ] && echo "true" || echo "false")
  },
  "errors": [],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
        else
            errors+=("Archive extraction failed")
        fi
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Directory restore failed",
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