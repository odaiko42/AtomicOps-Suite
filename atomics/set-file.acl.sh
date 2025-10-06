#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: set-file.acl.sh
# Description: Configurer les ACL (Access Control Lists) d'un fichier ou répertoire
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-06
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="set-file.acl.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
TARGET_PATH=""
ACL_RULE=""
RECURSIVE=${RECURSIVE:-0}
REMOVE_ALL=${REMOVE_ALL:-0}
DEFAULT_ACL=${DEFAULT_ACL:-0}

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
Usage: $SCRIPT_NAME [OPTIONS] <path> <acl_rule>

Description:
    Configure les ACL (Access Control Lists) pour un fichier ou répertoire.
    Permet de définir des permissions granulaires au-delà des permissions UNIX standards.

Arguments:
    <path>                  Chemin du fichier ou répertoire (obligatoire)
    <acl_rule>              Règle ACL (ex: u:username:rwx, g:groupname:r-x, m::rwx)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -r, --recursive        Appliquer récursivement aux sous-répertoires
    --default              Définir comme ACL par défaut (pour répertoires)
    --remove-all           Supprimer toutes les ACL étendues
    
Exemples de règles ACL:
    u:alice:rwx            Utilisateur 'alice' : lecture/écriture/exécution
    g:staff:r-x            Groupe 'staff' : lecture/exécution seulement
    o::r--                 Autres : lecture seulement
    m::rwx                 Masque : permissions maximales autorisées
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "path": "/path/to/file",
        "acl_rule": "u:username:rwx",
        "applied_recursive": true,
        "is_default_acl": false,
        "current_acl": ["u::rwx", "g::r-x", "o::r--"],
        "acl_supported": true
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0  - Succès
    1  - Erreur générale
    2  - Paramètres invalides
    3  - Fichier/répertoire non trouvé
    4  - Permissions insuffisantes
    5  - ACL non supportées sur le système de fichiers

Dépendances:
    - acl (paquet)
    - setfacl, getfacl (commandes)

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
            --default)
                DEFAULT_ACL=1
                shift
                ;;
            --remove-all)
                REMOVE_ALL=1
                shift
                ;;
            -*)
                die "Option inconnue: $1" 2
                ;;
            *)
                if [[ -z "$TARGET_PATH" ]]; then
                    TARGET_PATH="$1"
                elif [[ -z "$ACL_RULE" ]] && [[ $REMOVE_ALL -eq 0 ]]; then
                    ACL_RULE="$1"
                else
                    die "Trop d'arguments positionnels" 2
                fi
                shift
                ;;
        esac
    done
    
    # Validation des arguments
    if [[ -z "$TARGET_PATH" ]]; then
        die "Chemin du fichier/répertoire manquant" 2
    fi
    
    if [[ $REMOVE_ALL -eq 0 ]] && [[ -z "$ACL_RULE" ]]; then
        die "Règle ACL manquante (utilisez --remove-all pour supprimer toutes les ACL)" 2
    fi
    
    if [[ ! -e "$TARGET_PATH" ]]; then
        die "Fichier ou répertoire non trouvé: $TARGET_PATH" 3
    fi
    
    # Vérifier si DEFAULT_ACL est utilisé sur un fichier (erreur)
    if [[ $DEFAULT_ACL -eq 1 ]] && [[ ! -d "$TARGET_PATH" ]]; then
        die "L'option --default ne peut être utilisée que sur des répertoires" 2
    fi
}

# =============================================================================
# Fonctions de Validation et Vérification
# =============================================================================

check_dependencies() {
    local missing_deps=()
    
    if ! command -v setfacl >/dev/null 2>&1; then
        missing_deps+=("setfacl")
    fi
    
    if ! command -v getfacl >/dev/null 2>&1; then
        missing_deps+=("getfacl")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        die "Dépendances manquantes: ${missing_deps[*]}. Installez le paquet 'acl'" 1
    fi
}

check_acl_support() {
    local path="$1"
    local filesystem_path
    
    # Obtenir le point de montage du système de fichiers
    filesystem_path=$(df "$path" | awk 'NR==2 {print $1}')
    
    # Tester le support ACL en essayant de lire les ACL existantes
    if ! getfacl "$path" >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

validate_acl_rule() {
    local rule="$1"
    
    # Validation basique du format ACL
    # Format: [d:]<type>:<qualifier>:<permissions>
    # Types: u (user), g (group), o (other), m (mask)
    
    if [[ "$rule" =~ ^(d:)?(u|g|o|m):[^:]*:[r-][w-][x-]$ ]]; then
        return 0
    fi
    
    # Format étendu avec permissions numériques
    if [[ "$rule" =~ ^(d:)?(u|g|o|m):[^:]*:[0-7]$ ]]; then
        return 0
    fi
    
    return 1
}

get_current_acl() {
    local path="$1"
    local acl_entries=()
    
    # Obtenir les ACL actuelles et les formater
    while IFS= read -r line; do
        # Ignorer les commentaires et lignes vides
        if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
            continue
        fi
        acl_entries+=("$line")
    done < <(getfacl --omit-header --numeric "$path" 2>/dev/null)
    
    printf '%s\n' "${acl_entries[@]}"
}

# =============================================================================
# Fonction Principale de Configuration des ACL
# =============================================================================

set_file_acl() {
    local path="$1"
    local rule="$2"
    local errors=()
    local warnings=()
    
    log_debug "Configuration des ACL pour: $path"
    log_debug "Règle ACL: $rule"
    
    # Vérifier le support des ACL
    if ! check_acl_support "$path"; then
        errors+=("ACL not supported on filesystem for: $path")
        handle_result "$path" "$rule" "${errors[@]}" "${warnings[@]}"
        return 5
    fi
    
    # Obtenir les ACL actuelles avant modification
    local current_acl_before
    current_acl_before=$(get_current_acl "$path")
    
    if [[ $REMOVE_ALL -eq 1 ]]; then
        log_info "Suppression de toutes les ACL étendues"
        
        # Construire la commande setfacl pour suppression
        local setfacl_cmd="setfacl --remove-all"
        if [[ $RECURSIVE -eq 1 ]] && [[ -d "$path" ]]; then
            setfacl_cmd+=" --recursive"
        fi
        setfacl_cmd+=" \"$path\""
        
        if eval "$setfacl_cmd" 2>/dev/null; then
            log_info "ACL supprimées avec succès"
        else
            errors+=("Failed to remove ACL entries")
        fi
    else
        # Valider la règle ACL
        if ! validate_acl_rule "$rule"; then
            errors+=("Invalid ACL rule format: $rule")
            handle_result "$path" "$rule" "${errors[@]}" "${warnings[@]}"
            return 2
        fi
        
        log_info "Application de la règle ACL: $rule"
        
        # Construire la commande setfacl
        local setfacl_cmd="setfacl"
        
        if [[ $DEFAULT_ACL -eq 1 ]]; then
            setfacl_cmd+=" --default"
        fi
        
        if [[ $RECURSIVE -eq 1 ]] && [[ -d "$path" ]]; then
            setfacl_cmd+=" --recursive"
        fi
        
        setfacl_cmd+=" --modify \"$rule\" \"$path\""
        
        log_debug "Commande setfacl: $setfacl_cmd"
        
        # Exécuter la commande
        if eval "$setfacl_cmd" 2>/dev/null; then
            log_info "ACL appliquée avec succès"
        else
            errors+=("Failed to apply ACL rule: $rule")
        fi
    fi
    
    # Obtenir les ACL après modification
    local current_acl_after
    current_acl_after=$(get_current_acl "$path")
    
    # Vérifier si les ACL ont changé
    if [[ "$current_acl_before" == "$current_acl_after" ]] && [[ ${#errors[@]} -eq 0 ]]; then
        warnings+=("ACL rule may have had no effect (already applied or conflicted)")
    fi
    
    handle_result "$path" "$rule" "${errors[@]}" "${warnings[@]}"
    
    [[ ${#errors[@]} -eq 0 ]] && return 0 || return 1
}

handle_result() {
    local path="$1"
    local rule="$2"
    shift 2
    local errors=("$@")
    local warnings=()
    
    # Séparer les erreurs des warnings (convention: warnings commencent par "WARNING:")
    local actual_errors=()
    for item in "${errors[@]}"; do
        if [[ "$item" =~ ^WARNING: ]]; then
            warnings+=("${item#WARNING: }")
        else
            actual_errors+=("$item")
        fi
    done
    
    # Obtenir les ACL actuelles pour le JSON
    local current_acl_array="[]"
    if check_acl_support "$path"; then
        local acl_entries=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && acl_entries+=("\"$(echo "$line" | sed 's/"/\\"/g')\"")
        done < <(get_current_acl "$path")
        
        if [[ ${#acl_entries[@]} -gt 0 ]]; then
            current_acl_array="[$(IFS=','; echo "${acl_entries[*]}")]"
        fi
    fi
    
    # Échapper les caractères pour JSON
    local path_escaped rule_escaped
    path_escaped=$(echo "$path" | sed 's/\\/\\\\/g; s/"/\\"/g')
    rule_escaped=$(echo "$rule" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Construire les tableaux JSON pour erreurs et warnings
    local errors_json="[]" warnings_json="[]"
    if [[ ${#actual_errors[@]} -gt 0 ]]; then
        local errors_escaped=()
        for error in "${actual_errors[@]}"; do
            errors_escaped+=("\"$(echo "$error" | sed 's/\\/\\\\/g; s/"/\\"/g')\"")
        done
        errors_json="[$(IFS=','; echo "${errors_escaped[*]}")]"
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        local warnings_escaped=()
        for warning in "${warnings[@]}"; do
            warnings_escaped+=("\"$(echo "$warning" | sed 's/\\/\\\\/g; s/"/\\"/g')\"")
        done
        warnings_json="[$(IFS=','; echo "${warnings_escaped[*]}")]"
    fi
    
    # Déterminer le statut
    local status="success"
    local code=0
    local message="ACL configured successfully"
    
    if [[ ${#actual_errors[@]} -gt 0 ]]; then
        status="error"
        code=1
        message="Failed to configure ACL"
    fi
    
    if [[ $REMOVE_ALL -eq 1 ]]; then
        message="ACL entries removed successfully"
        [[ ${#actual_errors[@]} -gt 0 ]] && message="Failed to remove ACL entries"
    fi
    
    # Générer la réponse JSON
    cat << EOF
{
  "status": "$status",
  "code": $code,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "$message",
  "data": {
    "path": "$path_escaped",
    "acl_rule": "$rule_escaped",
    "applied_recursive": $([ $RECURSIVE -eq 1 ] && echo "true" || echo "false"),
    "is_default_acl": $([ $DEFAULT_ACL -eq 1 ] && echo "true" || echo "false"),
    "remove_all_mode": $([ $REMOVE_ALL -eq 1 ] && echo "true" || echo "false"),
    "current_acl": $current_acl_array,
    "acl_supported": $(check_acl_support "$path" && echo "true" || echo "false")
  },
  "errors": $errors_json,
  "warnings": $warnings_json
}
EOF
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    set_file_acl "$TARGET_PATH" "$ACL_RULE"
    
    log_info "Script completed"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi