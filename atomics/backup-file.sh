#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: backup-file.sh
# Description: Sauvegarder un fichier avec compression, métadonnées et vérification
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="backup-file.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
COMPRESSION="gzip"
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
VERIFY=${VERIFY:-1}
METADATA=${METADATA:-1}
OVERWRITE=${OVERWRITE:-0}
SOURCE_FILE=""
CUSTOM_NAME=""

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
Usage: $SCRIPT_NAME [OPTIONS] <source_file>

Description:
    Sauvegarde un fichier avec compression, vérification d'intégrité et
    génération de métadonnées complètes pour restauration.

Arguments:
    <source_file>           Fichier source à sauvegarder (obligatoire)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -c, --compression TYPE  Type de compression (gzip|bzip2|xz|none, défaut: gzip)
    -b, --backup-dir DIR    Répertoire de sauvegarde (défaut: ~/backups)
    -n, --name NAME         Nom personnalisé pour la sauvegarde
    --no-verify            Désactiver la vérification d'intégrité
    --no-metadata          Ne pas générer les métadonnées
    --overwrite            Écraser la sauvegarde existante
    
Variables d'environnement:
    BACKUP_DIR             Répertoire de sauvegarde par défaut
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "source_file": "/path/to/file.txt",
        "backup_file": "/home/user/backups/file_20251004_143022.txt.gz",
        "metadata_file": "/home/user/backups/file_20251004_143022.txt.gz.meta",
        "compression": "gzip",
        "original_size": 1048576,
        "compressed_size": 262144,
        "compression_ratio": 75.0,
        "checksums": {
          "original_md5": "d41d8cd98f00b204e9800998ecf8427e",
          "backup_md5": "d41d8cd98f00b204e9800998ecf8427e",
          "verification": "success"
        },
        "metadata": {
          "backup_date": "2025-10-04T14:30:22Z",
          "original_permissions": "644",
          "original_owner": "user:group",
          "original_modified": "2025-10-04T12:15:30Z",
          "backup_tool": "backup-file.sh v1.0"
        },
        "timing": {
          "backup_duration": 2.5,
          "verification_duration": 0.8
        }
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Fichier source non trouvé
    4 - Espace disque insuffisant

Exemples:
    $SCRIPT_NAME /etc/hosts                       # Sauvegarde simple
    $SCRIPT_NAME -c xz /var/log/app.log          # Compression XZ
    $SCRIPT_NAME -b /backup -n config /etc/nginx.conf # Nom et répertoire personnalisés
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
            -c|--compression)
                if [[ -n "${2:-}" ]]; then
                    COMPRESSION="$2"
                    shift 2
                else
                    die "Type de compression manquant pour -c/--compression" 2
                fi
                ;;
            -b|--backup-dir)
                if [[ -n "${2:-}" ]]; then
                    BACKUP_DIR="$2"
                    shift 2
                else
                    die "Répertoire de sauvegarde manquant pour -b/--backup-dir" 2
                fi
                ;;
            -n|--name)
                if [[ -n "${2:-}" ]]; then
                    CUSTOM_NAME="$2"
                    shift 2
                else
                    die "Nom personnalisé manquant pour -n/--name" 2
                fi
                ;;
            --no-verify)
                VERIFY=0
                shift
                ;;
            --no-metadata)
                METADATA=0
                shift
                ;;
            --overwrite)
                OVERWRITE=1
                shift
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                if [[ -z "$SOURCE_FILE" ]]; then
                    SOURCE_FILE="$1"
                else
                    die "Trop d'arguments. Un seul fichier source accepté." 2
                fi
                shift
                ;;
        esac
    done

    # Validation des arguments
    if [[ -z "$SOURCE_FILE" ]]; then
        die "Fichier source obligatoire manquant. Utilisez -h pour l'aide." 2
    fi
    
    case "$COMPRESSION" in
        gzip|bzip2|xz|none) ;;
        *) die "Type de compression invalide: $COMPRESSION. Utilisez gzip, bzip2, xz ou none." 2 ;;
    esac
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    # Outils de base
    if ! command -v cp >/dev/null 2>&1; then
        missing+=("cp")
    fi
    
    if ! command -v md5sum >/dev/null 2>&1 && ! command -v md5 >/dev/null 2>&1; then
        missing+=("md5sum ou md5")
    fi
    
    # Outils de compression selon le type
    case "$COMPRESSION" in
        gzip)
            if ! command -v gzip >/dev/null 2>&1; then
                missing+=("gzip")
            fi
            ;;
        bzip2)
            if ! command -v bzip2 >/dev/null 2>&1; then
                missing+=("bzip2")
            fi
            ;;
        xz)
            if ! command -v xz >/dev/null 2>&1; then
                missing+=("xz")
            fi
            ;;
    esac
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Dépendances vérifiées"
}

validate_source_file() {
    local file="$1"
    
    # Résoudre le chemin absolu
    file=$(readlink -f "$file" 2>/dev/null || realpath "$file" 2>/dev/null || echo "$file")
    
    if [[ ! -f "$file" ]]; then
        die "Fichier source non trouvé: $file" 3
    fi
    
    if [[ ! -r "$file" ]]; then
        die "Impossible de lire le fichier source: $file" 4
    fi
    
    echo "$file"
}

create_backup_directory() {
    local backup_dir="$1"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_debug "Création du répertoire de sauvegarde: $backup_dir"
        if ! mkdir -p "$backup_dir"; then
            die "Impossible de créer le répertoire de sauvegarde: $backup_dir" 1
        fi
    fi
    
    if [[ ! -w "$backup_dir" ]]; then
        die "Répertoire de sauvegarde non accessible en écriture: $backup_dir" 4
    fi
}

generate_backup_filename() {
    local source_file="$1"
    local custom_name="$2"
    local compression="$3"
    
    local base_name
    if [[ -n "$custom_name" ]]; then
        base_name="$custom_name"
    else
        base_name=$(basename "$source_file")
    fi
    
    # Ajouter timestamp
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_name="${base_name}_${timestamp}"
    
    # Ajouter extension de compression
    case "$compression" in
        gzip) backup_name+=".gz" ;;
        bzip2) backup_name+=".bz2" ;;
        xz) backup_name+=".xz" ;;
    esac
    
    echo "$backup_name"
}

check_disk_space() {
    local source_file="$1"
    local backup_dir="$2"
    
    # Taille du fichier source
    local source_size
    source_size=$(stat -c%s "$source_file" 2>/dev/null || stat -f%z "$source_file" 2>/dev/null || echo "0")
    
    # Espace disponible dans le répertoire de destination
    local available_space
    available_space=$(df "$backup_dir" | awk 'NR==2 {print $4*1024}' 2>/dev/null || echo "0")
    
    # Estimation conservative (2x la taille du fichier)
    local required_space=$((source_size * 2))
    
    if [[ $available_space -lt $required_space ]]; then
        die "Espace disque insuffisant. Requis: $(( required_space / 1024 / 1024 ))MB, Disponible: $(( available_space / 1024 / 1024 ))MB" 4
    fi
    
    log_debug "Vérification espace disque OK: $(( available_space / 1024 / 1024 ))MB disponible"
    echo "$source_size"
}

calculate_checksum() {
    local file="$1"
    
    if command -v md5sum >/dev/null 2>&1; then
        md5sum "$file" | awk '{print $1}'
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q "$file"
    else
        echo ""
    fi
}

get_file_metadata() {
    local file="$1"
    
    local permissions owner modified_time
    
    # Permissions
    permissions=$(stat -c%a "$file" 2>/dev/null || stat -f%Mp%Lp "$file" 2>/dev/null || echo "644")
    
    # Propriétaire
    owner=$(stat -c%U:%G "$file" 2>/dev/null || stat -f%Su:%Sg "$file" 2>/dev/null || echo "unknown:unknown")
    
    # Date de modification
    modified_time=$(stat -c%y "$file" 2>/dev/null | cut -d'.' -f1 | tr ' ' 'T')
    if [[ -z "$modified_time" ]]; then
        modified_time=$(date -r "$file" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || echo "")
    fi
    [[ -n "$modified_time" ]] && modified_time="${modified_time}Z"
    
    echo "$permissions|$owner|$modified_time"
}

perform_backup() {
    local source_file="$1"
    local backup_file="$2"
    local compression="$3"
    
    local start_time
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    log_info "Sauvegarde en cours: $(basename "$source_file")"
    
    case "$compression" in
        gzip)
            if ! gzip -c "$source_file" > "$backup_file"; then
                die "Échec de la compression gzip" 1
            fi
            ;;
        bzip2)
            if ! bzip2 -c "$source_file" > "$backup_file"; then
                die "Échec de la compression bzip2" 1
            fi
            ;;
        xz)
            if ! xz -c "$source_file" > "$backup_file"; then
                die "Échec de la compression xz" 1
            fi
            ;;
        none)
            if ! cp "$source_file" "$backup_file"; then
                die "Échec de la copie" 1
            fi
            ;;
    esac
    
    local end_time duration
    end_time=$(date +%s.%N 2>/dev/null || date +%s)
    duration=$(echo "scale=2; $end_time - $start_time" | bc 2>/dev/null || echo "0")
    
    log_debug "Sauvegarde terminée en ${duration}s"
    echo "$duration"
}

verify_backup() {
    local source_file="$1"
    local backup_file="$2"
    local compression="$3"
    
    if [[ $VERIFY -eq 0 ]]; then
        echo "skipped|||0"
        return 0
    fi
    
    local start_time
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    log_info "Vérification de l'intégrité..."
    
    # Calculer le checksum original
    local original_md5
    original_md5=$(calculate_checksum "$source_file")
    
    # Décompresser temporairement et calculer le checksum
    local temp_file backup_md5
    temp_file=$(mktemp)
    
    case "$compression" in
        gzip)
            if ! gzip -dc "$backup_file" > "$temp_file"; then
                rm -f "$temp_file"
                die "Échec de la décompression pour vérification" 1
            fi
            ;;
        bzip2)
            if ! bzip2 -dc "$backup_file" > "$temp_file"; then
                rm -f "$temp_file"
                die "Échec de la décompression pour vérification" 1
            fi
            ;;
        xz)
            if ! xz -dc "$backup_file" > "$temp_file"; then
                rm -f "$temp_file"
                die "Échec de la décompression pour vérification" 1
            fi
            ;;
        none)
            cp "$backup_file" "$temp_file"
            ;;
    esac
    
    backup_md5=$(calculate_checksum "$temp_file")
    rm -f "$temp_file"
    
    local verification="success"
    if [[ "$original_md5" != "$backup_md5" ]]; then
        verification="failed"
        die "Vérification d'intégrité échouée: checksums différents" 1
    fi
    
    local end_time duration
    end_time=$(date +%s.%N 2>/dev/null || date +%s)
    duration=$(echo "scale=2; $end_time - $start_time" | bc 2>/dev/null || echo "0")
    
    log_debug "Vérification terminée en ${duration}s"
    echo "$verification|$original_md5|$backup_md5|$duration"
}

create_metadata_file() {
    local source_file="$1"
    local backup_file="$2"
    local metadata_file="$3"
    local compression="$4"
    local original_size="$5"
    local compressed_size="$6"
    
    if [[ $METADATA -eq 0 ]]; then
        return 0
    fi
    
    log_debug "Génération des métadonnées: $metadata_file"
    
    local file_metadata
    file_metadata=$(get_file_metadata "$source_file")
    local permissions owner modified_time
    IFS='|' read -r permissions owner modified_time <<< "$file_metadata"
    
    # Ratio de compression
    local compression_ratio="0"
    if [[ $original_size -gt 0 && "$compression" != "none" ]]; then
        compression_ratio=$(echo "scale=1; (1 - $compressed_size / $original_size) * 100" | bc 2>/dev/null || echo "0")
    fi
    
    # Créer le fichier de métadonnées JSON
    cat > "$metadata_file" << EOF
{
  "backup_metadata": {
    "version": "1.0",
    "backup_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "backup_tool": "$SCRIPT_NAME v$SCRIPT_VERSION",
    "source_file": "$source_file",
    "backup_file": "$backup_file",
    "compression": "$compression",
    "original_size": $original_size,
    "compressed_size": $compressed_size,
    "compression_ratio": $compression_ratio,
    "original_metadata": {
      "permissions": "$permissions",
      "owner": "$owner",
      "modified_time": "$modified_time"
    },
    "restore_command": "$(generate_restore_command "$backup_file" "$source_file" "$compression")"
  }
}
EOF
    
    log_debug "Métadonnées sauvegardées"
}

generate_restore_command() {
    local backup_file="$1"
    local original_path="$2"
    local compression="$3"
    
    case "$compression" in
        gzip) echo "gzip -dc \"$backup_file\" > \"$original_path\"" ;;
        bzip2) echo "bzip2 -dc \"$backup_file\" > \"$original_path\"" ;;
        xz) echo "xz -dc \"$backup_file\" > \"$original_path\"" ;;
        none) echo "cp \"$backup_file\" \"$original_path\"" ;;
    esac
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    
    # Valider et résoudre le fichier source
    SOURCE_FILE=$(validate_source_file "$SOURCE_FILE")
    log_debug "Fichier source validé: $SOURCE_FILE"
    
    # Créer le répertoire de sauvegarde
    create_backup_directory "$BACKUP_DIR"
    
    # Vérifier l'espace disque et obtenir la taille
    local original_size
    original_size=$(check_disk_space "$SOURCE_FILE" "$BACKUP_DIR")
    
    # Générer le nom de fichier de sauvegarde
    local backup_filename backup_file metadata_file
    backup_filename=$(generate_backup_filename "$SOURCE_FILE" "$CUSTOM_NAME" "$COMPRESSION")
    backup_file="$BACKUP_DIR/$backup_filename"
    metadata_file="${backup_file}.meta"
    
    # Vérifier si la sauvegarde existe déjà
    if [[ -f "$backup_file" && $OVERWRITE -eq 0 ]]; then
        die "Sauvegarde existe déjà: $backup_file. Utilisez --overwrite pour écraser." 1
    fi
    
    log_info "Destination: $backup_file"
    
    # Effectuer la sauvegarde
    local backup_duration
    backup_duration=$(perform_backup "$SOURCE_FILE" "$backup_file" "$COMPRESSION")
    
    # Obtenir la taille de la sauvegarde
    local compressed_size
    compressed_size=$(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file" 2>/dev/null || echo "0")
    
    # Calculer le ratio de compression
    local compression_ratio="0"
    if [[ $original_size -gt 0 && "$COMPRESSION" != "none" ]]; then
        compression_ratio=$(echo "scale=1; (1 - $compressed_size / $original_size) * 100" | bc 2>/dev/null || echo "0")
    fi
    
    # Vérifier l'intégrité
    local verification_result verification_status original_md5 backup_md5 verification_duration
    verification_result=$(verify_backup "$SOURCE_FILE" "$backup_file" "$COMPRESSION")
    IFS='|' read -r verification_status original_md5 backup_md5 verification_duration <<< "$verification_result"
    
    # Créer les métadonnées
    create_metadata_file "$SOURCE_FILE" "$backup_file" "$metadata_file" "$COMPRESSION" "$original_size" "$compressed_size"
    
    # Échapper pour JSON
    local source_escaped backup_escaped metadata_escaped
    source_escaped=$(echo "$SOURCE_FILE" | sed 's/\\/\\\\/g; s/"/\\"/g')
    backup_escaped=$(echo "$backup_file" | sed 's/\\/\\\\/g; s/"/\\"/g')
    metadata_escaped=$(echo "$metadata_file" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Métadonnées du fichier original
    local file_metadata permissions owner modified_time
    file_metadata=$(get_file_metadata "$SOURCE_FILE")
    IFS='|' read -r permissions owner modified_time <<< "$file_metadata"
    
    # Générer la réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "File backup completed successfully",
  "data": {
    "source_file": "$source_escaped",
    "backup_file": "$backup_escaped",
    "metadata_file": "$metadata_escaped",
    "compression": "$COMPRESSION",
    "original_size": $original_size,
    "compressed_size": $compressed_size,
    "compression_ratio": $compression_ratio,
    "checksums": {
      "original_md5": "$original_md5",
      "backup_md5": "$backup_md5",
      "verification": "$verification_status"
    },
    "metadata": {
      "backup_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
      "original_permissions": "$permissions",
      "original_owner": "$owner",
      "original_modified": "$modified_time",
      "backup_tool": "$SCRIPT_NAME v$SCRIPT_VERSION"
    },
    "timing": {
      "backup_duration": $backup_duration,
      "verification_duration": $verification_duration
    },
    "options": {
      "compression_type": "$COMPRESSION",
      "verification_enabled": $([ $VERIFY -eq 1 ] && echo "true" || echo "false"),
      "metadata_generated": $([ $METADATA -eq 1 ] && echo "true" || echo "false")
    }
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_info "Sauvegarde terminée avec succès"
    log_info "Ratio de compression: ${compression_ratio}%"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi