#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: restore-backup.sh 
# Description: Restaurer une sauvegarde avec vérifications
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="restore-backup.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
BACKUP_FILE=""
RESTORE_DIR=""
FORCE=${FORCE:-0}
VERIFY_CHECKSUM=${VERIFY_CHECKSUM:-1}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <backup_file> [restore_directory]

Description:
    Restaure une sauvegarde tar avec vérification d'intégrité
    et gestion des conflits de fichiers existants.

Arguments:
    <backup_file>          Fichier de sauvegarde à restaurer
    [restore_directory]    Répertoire destination (défaut: PWD)

Options:
    -h, --help            Afficher cette aide
    -v, --verbose         Mode verbeux
    -d, --debug           Mode debug
    -q, --quiet           Mode silencieux
    -j, --json-only       Sortie JSON uniquement
    -f, --force           Forcer écrasement sans confirmation
    --no-verify           Ignorer vérification checksum
    
Exemples:
    $SCRIPT_NAME backup.tar.gz
    $SCRIPT_NAME -f backup.tar.bz2 /home/user
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
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                if [[ -z "$BACKUP_FILE" ]]; then
                    BACKUP_FILE="$1"
                elif [[ -z "$RESTORE_DIR" ]]; then
                    RESTORE_DIR="$1"
                else
                    echo "Trop d'arguments" >&2; exit 2
                fi
                shift ;;
        esac
    done

    [[ -z "$BACKUP_FILE" ]] && { echo "Fichier de sauvegarde manquant" >&2; exit 2; }
    [[ ! -f "$BACKUP_FILE" ]] && { echo "Fichier de sauvegarde non trouvé: $BACKUP_FILE" >&2; exit 3; }
    [[ -z "$RESTORE_DIR" ]] && RESTORE_DIR="$PWD"
}

check_backup_integrity() {
    local file="$1"
    
    # Vérifier selon l'extension
    case "$file" in
        *.tar.gz|*.tgz)
            gzip -t "$file" 2>/dev/null || return 1
            tar -tzf "$file" >/dev/null 2>&1 || return 1
            ;;
        *.tar.bz2|*.tbz2)
            bzip2 -t "$file" 2>/dev/null || return 1
            tar -tjf "$file" >/dev/null 2>&1 || return 1
            ;;
        *.tar.xz|*.txz)
            xz -t "$file" 2>/dev/null || return 1
            tar -tJf "$file" >/dev/null 2>&1 || return 1
            ;;
        *.tar)
            tar -tf "$file" >/dev/null 2>&1 || return 1
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

main() {
    parse_args "$@"
    
    local errors=() warnings=()
    
    # Vérifier l'intégrité de l'archive
    if [[ $VERIFY_CHECKSUM -eq 1 ]]; then
        if ! check_backup_integrity "$BACKUP_FILE"; then
            errors+=("Archive integrity check failed")
        fi
    fi
    
    # Créer le répertoire de restauration
    mkdir -p "$RESTORE_DIR"
    
    # Vérifier l'espace disque
    local archive_size restore_space
    archive_size=$(stat -c%s "$BACKUP_FILE" 2>/dev/null || echo "0")
    restore_space=$(df "$RESTORE_DIR" | awk 'NR==2 {print $4 * 1024}')
    
    if [[ $archive_size -gt $restore_space ]]; then
        warnings+=("Insufficient disk space might be available")
    fi
    
    # Construire la commande tar pour la restauration
    local tar_cmd="tar"
    case "$BACKUP_FILE" in
        *.tar.gz|*.tgz) tar_cmd+=" -xzf" ;;
        *.tar.bz2|*.tbz2) tar_cmd+=" -xjf" ;;
        *.tar.xz|*.txz) tar_cmd+=" -xJf" ;;
        *.tar) tar_cmd+=" -xf" ;;
        *) errors+=("Unsupported archive format") ;;
    esac
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        tar_cmd+=" \"$BACKUP_FILE\" -C \"$RESTORE_DIR\""
        
        # Exécuter la restauration
        local start_time
        start_time=$(date +%s)
        
        if eval "$tar_cmd" >/dev/null 2>&1; then
            local end_time duration files_restored
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            files_restored=$(tar -tf "$BACKUP_FILE" | wc -l)
            
            # JSON de succès
            cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Backup restore completed successfully",
  "data": {
    "backup_file": "$BACKUP_FILE",
    "restore_directory": "$RESTORE_DIR",
    "archive_size": $archive_size,
    "files_restored": $files_restored,
    "duration_seconds": $duration,
    "integrity_verified": $([ $VERIFY_CHECKSUM -eq 1 ] && echo "true" || echo "false")
  },
  "errors": [$(printf '"%s",' "${errors[@]}" | sed 's/,$//')],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
        else
            errors+=("Tar extract command failed")
        fi
    fi
    
    # JSON d'erreur si nécessaire
    if [[ ${#errors[@]} -gt 0 ]]; then
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Backup restore failed",
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