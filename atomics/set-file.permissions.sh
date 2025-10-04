#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: set-file.permissions.sh
# Description: Modifie les permissions d'un fichier/répertoire
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-01-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="set-file.permissions.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
RECURSIVE=${RECURSIVE:-0}
BACKUP=${BACKUP:-0}
DRY_RUN=${DRY_RUN:-0}
FILE_PATH=""
NEW_PERMISSIONS=""
CHMOD_MODE="octal"  # octal, symbolic, explicit

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
Usage: $SCRIPT_NAME [OPTIONS] <file_path> <permissions>

Description:
    Modifie les permissions d'un fichier ou répertoire avec validation
    et sauvegarde optionnelle des permissions originales.

Arguments:
    <file_path>             Chemin du fichier/répertoire à modifier (obligatoire)
    <permissions>           Nouvelles permissions (obligatoire)
                           - Format octal: 755, 644, 700, etc.
                           - Format symbolique: u+rwx,g+rx,o+rx, etc.
                           - Format explicite: owner:group:other (rwx:rx:rx)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -r, --recursive        Appliquer récursivement aux sous-répertoires
    -b, --backup           Sauvegarder les permissions actuelles
    -n, --dry-run          Test sans modification réelle
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "file_path": "/path/to/file",
        "previous_permissions": {
          "octal": "644",
          "symbolic": "rw-r--r--"
        },
        "new_permissions": {
          "octal": "755",
          "symbolic": "rwxr-xr-x"
        },
        "files_modified": 5,
        "recursive": true,
        "dry_run": false,
        "backup_created": true
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Fichier n'existe pas
    4 - Permissions insuffisantes
    5 - Format de permissions invalide

Exemples:
    $SCRIPT_NAME /tmp/file.txt 755                # Permissions octales
    $SCRIPT_NAME /tmp/dir u+rwx,g+rx,o+rx         # Permissions symboliques
    $SCRIPT_NAME --recursive /tmp/dir 644         # Récursif
    $SCRIPT_NAME --dry-run /tmp/file.txt 700      # Test sans modification
    $SCRIPT_NAME --backup /etc/config 600         # Avec sauvegarde
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
            -r|--recursive)
                RECURSIVE=1
                shift
                ;;
            -b|--backup)
                BACKUP=1
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=1
                shift
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                if [[ -z "$FILE_PATH" ]]; then
                    FILE_PATH="$1"
                elif [[ -z "$NEW_PERMISSIONS" ]]; then
                    NEW_PERMISSIONS="$1"
                else
                    die "Trop d'arguments. Utilisez -h pour l'aide." 2
                fi
                shift
                ;;
        esac
    done

    # Validation des paramètres obligatoires
    if [[ -z "$FILE_PATH" ]]; then
        die "Chemin de fichier obligatoire manquant. Utilisez -h pour l'aide." 2
    fi
    
    if [[ -z "$NEW_PERMISSIONS" ]]; then
        die "Permissions obligatoires manquantes. Utilisez -h pour l'aide." 2
    fi
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    if ! command -v chmod >/dev/null 2>&1; then
        missing+=("chmod")
    fi
    
    if ! command -v stat >/dev/null 2>&1; then
        missing+=("stat")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Toutes les dépendances sont disponibles"
}

validate_permissions() {
    local perms="$1"
    
    log_debug "Validation du format de permissions: $perms"
    
    # Test format octal (3 ou 4 chiffres)
    if [[ "$perms" =~ ^[0-7]{3,4}$ ]]; then
        CHMOD_MODE="octal"
        log_debug "Format octal détecté: $perms"
        return 0
    fi
    
    # Test format symbolique (u+rwx, g-w, o=r, etc.)
    if [[ "$perms" =~ ^[ugoa]*[+=-][rwxs]*([,][ugoa]*[+=-][rwxs]*)*$ ]]; then
        CHMOD_MODE="symbolic"
        log_debug "Format symbolique détecté: $perms"
        return 0
    fi
    
    # Test format explicite (rwx:rx:rx)
    if [[ "$perms" =~ ^[rwx-]{3}:[rwx-]{3}:[rwx-]{3}$ ]]; then
        CHMOD_MODE="explicit"
        log_debug "Format explicite détecté: $perms"
        return 0
    fi
    
    die "Format de permissions invalide: $perms. Formats acceptés: octal (755), symbolique (u+rwx,g+rx), explicite (rwx:rx:rx)" 5
}

convert_explicit_to_octal() {
    local explicit="$1"
    local owner_perms group_perms other_perms
    
    IFS=':' read -r owner_perms group_perms other_perms <<< "$explicit"
    
    local owner_val=0 group_val=0 other_val=0
    
    # Convertir permissions propriétaire
    [[ "$owner_perms" =~ r ]] && ((owner_val += 4))
    [[ "$owner_perms" =~ w ]] && ((owner_val += 2))
    [[ "$owner_perms" =~ x ]] && ((owner_val += 1))
    
    # Convertir permissions groupe
    [[ "$group_perms" =~ r ]] && ((group_val += 4))
    [[ "$group_perms" =~ w ]] && ((group_val += 2))
    [[ "$group_perms" =~ x ]] && ((group_val += 1))
    
    # Convertir permissions autres
    [[ "$other_perms" =~ r ]] && ((other_val += 4))
    [[ "$other_perms" =~ w ]] && ((other_val += 2))
    [[ "$other_perms" =~ x ]] && ((other_val += 1))
    
    echo "${owner_val}${group_val}${other_val}"
}

get_current_permissions() {
    local file_path="$1"
    
    if command -v stat >/dev/null 2>&1; then
        if stat --version 2>/dev/null | grep -q GNU; then
            # GNU stat (Linux)
            stat -c%a "$file_path" 2>/dev/null || echo "000"
        else
            # BSD stat (macOS)
            stat -f%A "$file_path" 2>/dev/null || echo "000"
        fi
    else
        echo "000"
    fi
}

octal_to_symbolic() {
    local octal="$1"
    local symbolic=""
    
    # Assurer que nous avons 3 chiffres
    if [[ ${#octal} -eq 3 ]]; then
        octal="0$octal"
    fi
    
    local owner group other
    owner=${octal:1:1}
    group=${octal:2:1}
    other=${octal:3:1}
    
    # Convertir chaque chiffre en rwx
    for digit in $owner $group $other; do
        case $digit in
            0) symbolic="${symbolic}---" ;;
            1) symbolic="${symbolic}--x" ;;
            2) symbolic="${symbolic}-w-" ;;
            3) symbolic="${symbolic}-wx" ;;
            4) symbolic="${symbolic}r--" ;;
            5) symbolic="${symbolic}r-x" ;;
            6) symbolic="${symbolic}rw-" ;;
            7) symbolic="${symbolic}rwx" ;;
        esac
    done
    
    echo "$symbolic"
}

backup_permissions() {
    local file_path="$1"
    local current_perms
    current_perms=$(get_current_permissions "$file_path")
    
    local backup_file="${file_path}.permissions.backup.$(date +%Y%m%d_%H%M%S)"
    
    echo "# Backup permissions for: $file_path" > "$backup_file"
    echo "# Created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$backup_file"
    echo "# Original permissions: $current_perms" >> "$backup_file"
    echo "chmod $current_perms \"$file_path\"" >> "$backup_file"
    
    log_info "Permissions sauvegardées dans: $backup_file"
    echo "$backup_file"
}

count_files_to_modify() {
    local file_path="$1"
    local count=0
    
    if [[ -f "$file_path" ]]; then
        echo 1
    elif [[ -d "$file_path" ]]; then
        if [[ $RECURSIVE -eq 1 ]]; then
            count=$(find "$file_path" -type f -o -type d | wc -l)
            echo "$count"
        else
            echo 1
        fi
    else
        echo 0
    fi
}

set_file_permissions() {
    local file_path="$1"
    local new_perms="$2"
    
    log_debug "Modification des permissions pour: $file_path"
    
    # Vérifier que le fichier existe
    if [[ ! -e "$file_path" ]]; then
        die "Le fichier ou répertoire n'existe pas: $file_path" 3
    fi
    
    # Validation des permissions
    validate_permissions "$new_perms"
    
    # Obtenir les permissions actuelles
    local current_perms current_symbolic new_symbolic backup_file=""
    current_perms=$(get_current_permissions "$file_path")
    current_symbolic=$(octal_to_symbolic "$current_perms")
    
    # Convertir le format explicite si nécessaire
    if [[ "$CHMOD_MODE" == "explicit" ]]; then
        new_perms=$(convert_explicit_to_octal "$new_perms")
        CHMOD_MODE="octal"
    fi
    
    # Obtenir la représentation symbolique des nouvelles permissions
    if [[ "$CHMOD_MODE" == "octal" ]]; then
        new_symbolic=$(octal_to_symbolic "$new_perms")
    else
        # Pour le mode symbolique, simuler le changement pour obtenir le résultat
        new_symbolic="symbolic_$new_perms"
    fi
    
    # Sauvegarder si demandé
    if [[ $BACKUP -eq 1 ]]; then
        backup_file=$(backup_permissions "$file_path")
    fi
    
    # Compter les fichiers à modifier
    local files_count
    files_count=$(count_files_to_modify "$file_path")
    
    log_debug "Permissions actuelles: $current_perms ($current_symbolic)"
    log_debug "Nouvelles permissions: $new_perms ($new_symbolic)"
    log_debug "Nombre de fichiers à modifier: $files_count"
    
    # Appliquer les permissions (sauf en mode dry-run)
    local chmod_success=true
    if [[ $DRY_RUN -eq 0 ]]; then
        log_info "Application des permissions $new_perms à $file_path"
        
        if [[ $RECURSIVE -eq 1 && -d "$file_path" ]]; then
            if ! chmod -R "$new_perms" "$file_path" 2>/dev/null; then
                chmod_success=false
            fi
        else
            if ! chmod "$new_perms" "$file_path" 2>/dev/null; then
                chmod_success=false
            fi
        fi
        
        if [[ "$chmod_success" == false ]]; then
            die "Impossible de modifier les permissions de $file_path. Vérifiez vos droits d'accès." 4
        fi
    else
        log_info "[DRY-RUN] Simulation: chmod ${RECURSIVE:+-R} $new_perms $file_path"
    fi
    
    # Vérifier que les permissions ont été appliquées (sauf en dry-run)
    local final_perms="$new_perms"
    if [[ $DRY_RUN -eq 0 && "$CHMOD_MODE" == "octal" ]]; then
        final_perms=$(get_current_permissions "$file_path")
        final_symbolic=$(octal_to_symbolic "$final_perms")
    fi
    
    # Échapper les caractères spéciaux pour JSON
    local file_path_escaped backup_file_escaped
    file_path_escaped=$(echo "$file_path" | sed 's/\\/\\\\/g; s/"/\\"/g')
    backup_file_escaped=$(echo "${backup_file:-}" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "File permissions ${DRY_RUN:+would be }modified successfully",
  "data": {
    "file_path": "$file_path_escaped",
    "previous_permissions": {
      "octal": "$current_perms",
      "symbolic": "$current_symbolic"
    },
    "new_permissions": {
      "octal": "$final_perms",
      "symbolic": "${new_symbolic/symbolic_/}"
    },
    "files_modified": $files_count,
    "recursive": $([ $RECURSIVE -eq 1 ] && echo "true" || echo "false"),
    "dry_run": $([ $DRY_RUN -eq 1 ] && echo "true" || echo "false"),
    "backup_created": $([ -n "$backup_file" ] && echo "true" || echo "false"),
    "backup_file": "$backup_file_escaped",
    "chmod_mode": "$CHMOD_MODE",
    "modification_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_debug "Modification des permissions terminée avec succès"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    set_file_permissions "$FILE_PATH" "$NEW_PERMISSIONS"
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi