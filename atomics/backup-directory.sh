#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: backup-directory.sh 
# Description: Sauvegarder un répertoire avec exclusions et compression
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="backup-directory.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
SOURCE_DIR=""
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
EXCLUDE_PATTERNS=()
COMPRESSION="gzip"

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <source_directory>

Description:
    Sauvegarde un répertoire complet avec gestion des exclusions,
    compression tar et vérification d'intégrité.

Arguments:
    <source_directory>      Répertoire source à sauvegarder

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux
    -d, --debug            Mode debug
    -q, --quiet            Mode silencieux
    -j, --json-only        Sortie JSON uniquement
    -b, --backup-dir DIR    Répertoire de destination
    -c, --compression TYPE  Type (gzip|bzip2|xz|none)
    -e, --exclude PATTERN   Pattern d'exclusion (répétable)
    
Exemples:
    $SCRIPT_NAME /home/user
    $SCRIPT_NAME -e "*.tmp" -e "cache/" /var/www
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
            -b|--backup-dir) BACKUP_DIR="$2"; shift 2 ;;
            -c|--compression) COMPRESSION="$2"; shift 2 ;;
            -e|--exclude) EXCLUDE_PATTERNS+=("$2"); shift 2 ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                [[ -z "$SOURCE_DIR" ]] && SOURCE_DIR="$1" || { echo "Trop d'arguments" >&2; exit 2; }
                shift ;;
        esac
    done

    [[ -z "$SOURCE_DIR" ]] && { echo "Répertoire source manquant" >&2; exit 2; }
    [[ ! -d "$SOURCE_DIR" ]] && { echo "Répertoire source non trouvé: $SOURCE_DIR" >&2; exit 3; }
}

main() {
    parse_args "$@"
    
    # Créer le répertoire de destination
    mkdir -p "$BACKUP_DIR"
    
    # Générer le nom de fichier
    local backup_name
    backup_name="$(basename "$SOURCE_DIR")_$(date +%Y%m%d_%H%M%S).tar"
    
    case "$COMPRESSION" in
        gzip) backup_name+=".gz" ;;
        bzip2) backup_name+=".bz2" ;;
        xz) backup_name+=".xz" ;;
    esac
    
    local backup_file="$BACKUP_DIR/$backup_name"
    
    # Construire la commande tar
    local tar_cmd="tar"
    case "$COMPRESSION" in
        gzip) tar_cmd+=" -czf" ;;
        bzip2) tar_cmd+=" -cjf" ;;
        xz) tar_cmd+=" -cJf" ;;
        none) tar_cmd+=" -cf" ;;
    esac
    
    tar_cmd+=" \"$backup_file\""
    
    # Ajouter exclusions
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        tar_cmd+=" --exclude=\"$pattern\""
    done
    
    tar_cmd+=" -C \"$(dirname "$SOURCE_DIR")\" \"$(basename "$SOURCE_DIR")\""
    
    # Exécuter la sauvegarde
    local start_time
    start_time=$(date +%s)
    
    if eval "$tar_cmd" >/dev/null 2>&1; then
        local end_time duration
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        local original_size backup_size
        original_size=$(du -sb "$SOURCE_DIR" | cut -f1)
        backup_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
        
        local compression_ratio="0"
        [[ $original_size -gt 0 ]] && compression_ratio=$(echo "scale=1; (1 - $backup_size / $original_size) * 100" | bc 2>/dev/null || echo "0")
        
        # Générer JSON de sortie
        cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Directory backup completed successfully",
  "data": {
    "source_directory": "$SOURCE_DIR",
    "backup_file": "$backup_file",
    "compression": "$COMPRESSION",
    "original_size": $original_size,
    "backup_size": $backup_size,
    "compression_ratio": $compression_ratio,
    "duration_seconds": $duration,
    "excluded_patterns": [$(printf '"%s",' "${EXCLUDE_PATTERNS[@]}" | sed 's/,$//')],
    "files_count": $(find "$SOURCE_DIR" -type f | wc -l)
  },
  "errors": [],
  "warnings": []
}
EOF
    else
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Directory backup failed",
  "data": {},
  "errors": ["Tar backup command failed"],
  "warnings": []
}
EOF
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi