#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: rotate-log.sh 
# Description: Effectuer la rotation des logs avec compression et nettoyage
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="rotate-log.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
LOG_FILE=""
ROTATE_COUNT=${ROTATE_COUNT:-5}
COMPRESS=${COMPRESS:-1}
COMPRESS_TYPE=${COMPRESS_TYPE:-"gzip"}
MIN_SIZE=${MIN_SIZE:-1048576}  # 1MB par défaut
MAX_AGE_DAYS=${MAX_AGE_DAYS:-30}
FORCE=${FORCE:-0}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <log_file>

Description:
    Effectue la rotation d'un fichier de log avec compression,
    numérotation automatique et nettoyage des anciens fichiers.

Arguments:
    <log_file>       Chemin du fichier de log à faire tourner

Options:
    -h, --help       Afficher cette aide
    -v, --verbose    Mode verbeux
    -d, --debug      Mode debug
    -q, --quiet      Mode silencieux
    -j, --json-only  Sortie JSON uniquement
    -f, --force      Forcer la rotation même si petit
    -n, --count N    Nombre de fichiers à conserver (défaut: 5)
    -s, --min-size N Taille minimale en bytes (défaut: 1048576)
    -a, --max-age N  Âge maximum en jours (défaut: 30)
    -c, --compress TYPE Compression (gzip|bzip2|xz|none, défaut: gzip)
    --no-compress    Désactiver la compression
    
Exemples:
    $SCRIPT_NAME /var/log/myapp.log
    $SCRIPT_NAME -n 10 -c bzip2 /var/log/access.log
    $SCRIPT_NAME -f --no-compress /tmp/debug.log
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
            -n|--count) ROTATE_COUNT="$2"; shift 2 ;;
            -s|--min-size) MIN_SIZE="$2"; shift 2 ;;
            -a|--max-age) MAX_AGE_DAYS="$2"; shift 2 ;;
            -c|--compress) COMPRESS_TYPE="$2"; shift 2 ;;
            --no-compress) COMPRESS=0; shift ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                [[ -z "$LOG_FILE" ]] && LOG_FILE="$1" || { echo "Trop d'arguments" >&2; exit 2; }
                shift ;;
        esac
    done

    [[ -z "$LOG_FILE" ]] && { echo "Fichier de log manquant" >&2; exit 2; }
    [[ ! -f "$LOG_FILE" ]] && { echo "Fichier de log non trouvé: $LOG_FILE" >&2; exit 3; }
    
    # Validation des paramètres
    [[ ! "$ROTATE_COUNT" =~ ^[0-9]+$ ]] && { echo "Nombre de rotation invalide" >&2; exit 2; }
    [[ ! "$MIN_SIZE" =~ ^[0-9]+$ ]] && { echo "Taille minimale invalide" >&2; exit 2; }
    [[ ! "$MAX_AGE_DAYS" =~ ^[0-9]+$ ]] && { echo "Âge maximal invalide" >&2; exit 2; }
}

get_file_size() {
    local file="$1"
    stat -c%s "$file" 2>/dev/null || echo "0"
}

should_rotate() {
    local file="$1"
    local size
    size=$(get_file_size "$file")
    
    # Forcer si demandé
    [[ $FORCE -eq 1 ]] && return 0
    
    # Vérifier la taille
    [[ $size -ge $MIN_SIZE ]] && return 0
    
    return 1
}

compress_file() {
    local file="$1"
    local type="$2"
    
    case "$type" in
        gzip)
            gzip "$file" && echo "${file}.gz"
            ;;
        bzip2)
            bzip2 "$file" && echo "${file}.bz2"
            ;;
        xz)
            xz "$file" && echo "${file}.xz"
            ;;
        none|*)
            echo "$file"
            ;;
    esac
}

rotate_existing_logs() {
    local base_file="$1"
    local max_count="$2"
    local rotated_files=()
    
    # Supprimer le plus ancien fichier s'il existe
    local oldest="${base_file}.${max_count}"
    for ext in "" ".gz" ".bz2" ".xz"; do
        if [[ -f "${oldest}${ext}" ]]; then
            rm -f "${oldest}${ext}"
            rotated_files+=("${oldest}${ext} (deleted)")
        fi
    done
    
    # Déplacer les fichiers existants
    for ((i = max_count - 1; i >= 1; i--)); do
        local current="${base_file}.${i}"
        local next="${base_file}.$((i + 1))"
        
        for ext in "" ".gz" ".bz2" ".xz"; do
            if [[ -f "${current}${ext}" ]]; then
                mv "${current}${ext}" "${next}${ext}"
                rotated_files+=("${current}${ext} -> ${next}${ext}")
            fi
        done
    done
    
    printf '%s\n' "${rotated_files[@]}"
}

cleanup_old_logs() {
    local base_file="$1"
    local max_age_days="$2"
    local cleaned_files=()
    
    # Rechercher les fichiers anciens
    local base_dir
    base_dir=$(dirname "$base_file")
    local base_name
    base_name=$(basename "$base_file")
    
    while IFS= read -r -d '' file; do
        local age_days
        age_days=$(( ($(date +%s) - $(stat -c%Y "$file")) / 86400 ))
        
        if [[ $age_days -gt $max_age_days ]]; then
            if rm -f "$file"; then
                cleaned_files+=("$file (${age_days} days old)")
            fi
        fi
    done < <(find "$base_dir" -name "${base_name}.*" -type f -print0 2>/dev/null)
    
    printf '%s\n' "${cleaned_files[@]}"
}

main() {
    parse_args "$@"
    
    local errors=() warnings=()
    
    # Vérifier si la rotation est nécessaire
    if ! should_rotate "$LOG_FILE"; then
        local current_size
        current_size=$(get_file_size "$LOG_FILE")
        warnings+=("Log file size ($current_size bytes) below threshold ($MIN_SIZE bytes)")
        
        if [[ $FORCE -eq 0 ]]; then
            cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Log rotation skipped - file too small",
  "data": {
    "log_file": "$LOG_FILE",
    "current_size": $current_size,
    "minimum_size": $MIN_SIZE,
    "rotation_performed": false,
    "force_mode": false
  },
  "errors": [],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
            exit 0
        fi
    fi
    
    # Vérifier les permissions d'écriture
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    if [[ ! -w "$log_dir" ]]; then
        errors+=("No write permission in log directory: $log_dir")
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        local start_time end_time duration
        local original_size rotated_files=() cleaned_files=()
        
        start_time=$(date +%s)
        original_size=$(get_file_size "$LOG_FILE")
        
        # Effectuer la rotation des fichiers existants
        readarray -t rotated_files < <(rotate_existing_logs "$LOG_FILE" "$ROTATE_COUNT")
        
        # Copier et vider le fichier de log actuel
        local rotated_file="${LOG_FILE}.1"
        if cp "$LOG_FILE" "$rotated_file" && truncate -s 0 "$LOG_FILE"; then
            
            # Compresser si demandé
            local compressed_file="$rotated_file"
            if [[ $COMPRESS -eq 1 ]] && [[ "$COMPRESS_TYPE" != "none" ]]; then
                compressed_file=$(compress_file "$rotated_file" "$COMPRESS_TYPE")
                if [[ "$compressed_file" != "$rotated_file" ]]; then
                    rotated_files+=("$rotated_file -> $compressed_file (compressed)")
                fi
            fi
            
            # Nettoyer les anciens fichiers
            readarray -t cleaned_files < <(cleanup_old_logs "$LOG_FILE" "$MAX_AGE_DAYS")
            
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            
            # Calculer la taille finale
            local final_compressed_size=0
            if [[ -f "$compressed_file" ]]; then
                final_compressed_size=$(get_file_size "$compressed_file")
            fi
            
            cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Log rotation completed successfully",
  "data": {
    "log_file": "$LOG_FILE",
    "original_size": $original_size,
    "rotated_to": "$compressed_file",
    "compressed_size": $final_compressed_size,
    "compression_ratio": $([ $original_size -gt 0 ] && echo "scale=1; (1 - $final_compressed_size / $original_size) * 100" | bc 2>/dev/null || echo "0"),
    "duration_seconds": $duration,
    "rotation_count": $ROTATE_COUNT,
    "compression_type": "$COMPRESS_TYPE",
    "compression_enabled": $([ $COMPRESS -eq 1 ] && echo "true" || echo "false"),
    "rotated_files": [$(printf '"%s",' "${rotated_files[@]}" | sed 's/,$//')],
    "cleaned_files": [$(printf '"%s",' "${cleaned_files[@]}" | sed 's/,$//')],
    "files_cleaned": ${#cleaned_files[@]}
  },
  "errors": [],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
        else
            errors+=("Failed to rotate log file")
        fi
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Log rotation failed",
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