#!/usr/bin/env bash

# ============================================================================
# Script atomique : set-file.permissions.sh
# Description : Gestion des permissions de fichiers et répertoires (chmod)
# Auteur : Généré automatiquement
# Version : 1.0
# Usage : ./set-file.permissions.sh [OPTIONS]
# ============================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === FONCTIONS UTILITAIRES ===
show_help() {
    cat << 'EOF'
USAGE:
    set-file.permissions.sh [OPTIONS]

DESCRIPTION:
    Modifie les permissions de fichiers et répertoires avec gestion avancée.
    Supporte les formats octaux, symboliques et templates prédéfinis.

OPTIONS:
    -t, --target PATH        Chemin du fichier/répertoire cible (requis)
    -p, --permissions PERM   Permissions (octal: 755, symbolique: u+rwx,g+r,o+r)
    -m, --mode MODE          Mode prédéfini (private, shared, public, executable, readonly)
    -u, --user PERM          Permissions utilisateur (rwx, r-x, etc.)
    -g, --group PERM         Permissions groupe (rwx, r-x, etc.)
    -o, --other PERM         Permissions autres (rwx, r-x, etc.)
    -r, --recursive          Application récursive pour répertoires
    -H, --dereference        Suivre les liens symboliques
    -P, --preserve-root      Protection contre changement sur /
    -f, --files-only         Appliquer seulement aux fichiers (avec -r)
    -d, --dirs-only          Appliquer seulement aux répertoires (avec -r)
    -b, --backup             Sauvegarder les permissions actuelles
    --force                  Forcer les changements dangereux
    -v, --verbose            Mode verbeux
    -q, --quiet              Mode silencieux
    -h, --help               Afficher cette aide

PERMISSION MODES:
    private     = 600/700  (owner seulement)
    shared      = 664/775  (owner+group write)
    public      = 644/755  (lecture publique)
    executable  = 755      (exécutable pour tous)
    readonly    = 444      (lecture seule)
    secret      = 600      (lecture/écriture owner seul)

EXAMPLES:
    # Permissions octales
    set-file.permissions.sh -t /path/to/file -p 755
    
    # Mode symbolique
    set-file.permissions.sh -t /path/to/file -p "u+rwx,g+r,o+r"
    
    # Mode prédéfini
    set-file.permissions.sh -t /path/to/dir -m "shared" --recursive
    
    # Permissions par classe d'utilisateur
    set-file.permissions.sh -t /path/to/file -u "rwx" -g "r-x" -o "---"

OUTPUT:
    JSON avec statut, détails des permissions et statistiques
EOF
}

log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "${QUIET:-0}" != "1" ]]; then
        case "$level" in
            "ERROR") echo "[$timestamp] ERROR: $message" >&2 ;;
            "WARN")  echo "[$timestamp] WARN: $message" >&2 ;;
            "INFO")  echo "[$timestamp] INFO: $message" >&2 ;;
            "DEBUG") [[ "${VERBOSE:-0}" == "1" ]] && echo "[$timestamp] DEBUG: $message" >&2 ;;
        esac
    fi
}

check_dependencies() {
    local deps=("chmod" "stat" "find")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_message "ERROR" "Dépendances manquantes: ${missing[*]}"
        return 1
    fi
    
    return 0
}

validate_target() {
    local target="$1"
    
    if [[ ! -e "$target" ]]; then
        log_message "ERROR" "Cible inexistante: $target"
        return 1
    fi
    
    # Protection contre la racine si demandée
    if [[ "${PRESERVE_ROOT:-0}" == "1" && "$target" == "/" ]]; then
        log_message "ERROR" "Changement sur / interdit (--preserve-root)"
        return 1
    fi
    
    return 0
}

convert_symbolic_to_octal() {
    local symbolic="$1"
    local result=""
    
    # Conversion rwx vers octal
    local value=0
    
    [[ "$symbolic" =~ r ]] && ((value += 4))
    [[ "$symbolic" =~ w ]] && ((value += 2))
    [[ "$symbolic" =~ x ]] && ((value += 1))
    
    echo "$value"
}

parse_permissions_spec() {
    local perm="$1"
    
    # Formats supportés:
    # - Octal: 755, 644, etc.
    # - Symbolique complet: rwxr--r--
    # - Symbolique par classe: u+rwx,g+r,o+r
    # - Par classe: rwx,r-x,r--
    
    if [[ "$perm" =~ ^[0-7]{3,4}$ ]]; then
        # Format octal
        echo "$perm"
        return 0
    elif [[ "$perm" =~ ^[rwx-]{9}$ ]]; then
        # Format symbolique complet (rwxr--r--)
        local user_perm="${perm:0:3}"
        local group_perm="${perm:3:3}"
        local other_perm="${perm:6:3}"
        
        local octal_user octal_group octal_other
        octal_user=$(convert_symbolic_to_octal "$user_perm")
        octal_group=$(convert_symbolic_to_octal "$group_perm")
        octal_other=$(convert_symbolic_to_octal "$other_perm")
        
        echo "${octal_user}${octal_group}${octal_other}"
        return 0
    elif [[ "$perm" == *","* ]]; then
        # Format par virgules (rwx,r-x,r--)
        local IFS=','
        read -ra parts <<< "$perm"
        
        if [[ ${#parts[@]} -eq 3 ]]; then
            local octal_user octal_group octal_other
            octal_user=$(convert_symbolic_to_octal "${parts[0]}")
            octal_group=$(convert_symbolic_to_octal "${parts[1]}")
            octal_other=$(convert_symbolic_to_octal "${parts[2]}")
            
            echo "${octal_user}${octal_group}${octal_other}"
            return 0
        fi
    fi
    
    # Format symbolique chmod (u+rwx,g+r,o+r) - retourner tel quel
    echo "$perm"
    return 0
}

get_predefined_mode() {
    local mode="$1"
    local target="$2"
    
    local is_dir=false
    [[ -d "$target" ]] && is_dir=true
    
    case "$mode" in
        "private")
            if $is_dir; then echo "700"; else echo "600"; fi
            ;;
        "shared")
            if $is_dir; then echo "775"; else echo "664"; fi
            ;;
        "public")
            if $is_dir; then echo "755"; else echo "644"; fi
            ;;
        "executable")
            echo "755"
            ;;
        "readonly")
            if $is_dir; then echo "555"; else echo "444"; fi
            ;;
        "secret")
            echo "600"
            ;;
        *)
            log_message "ERROR" "Mode prédéfini inconnu: $mode"
            return 1
            ;;
    esac
    
    return 0
}

validate_permissions_security() {
    local perm="$1"
    local target="$2"
    
    # Vérifications de sécurité
    local warnings=()
    
    # Permissions world-writable dangereuses
    if [[ "$perm" =~ [0-7]*[2367]$ ]]; then
        warnings+=("Permissions world-writable détectées")
    fi
    
    # Setuid/setgid sur fichiers exécutables
    if [[ "$perm" =~ ^[4567] ]]; then
        warnings+=("Permissions setuid/setgid détectées")
    fi
    
    # Fichiers système critiques
    if [[ "$target" =~ ^/(etc|usr/bin|bin|sbin)/ ]]; then
        if [[ "$perm" =~ [0-7]*[2367]$ ]] && [[ "${FORCE:-0}" != "1" ]]; then
            warnings+=("Modification dangereuse sur fichier système")
        fi
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        for warning in "${warnings[@]}"; do
            log_message "WARN" "$warning"
        done
        
        if [[ "${FORCE:-0}" != "1" ]]; then
            log_message "ERROR" "Utilisez --force pour ignorer les avertissements"
            return 1
        fi
    fi
    
    return 0
}

backup_permissions() {
    local target="$1"
    local backup_file="/tmp/permissions_backup_$(basename "$target")_$(date +%s).info"
    
    {
        echo "# Sauvegarde permissions pour: $target"
        echo "# Date: $(date)"
        echo "TARGET=$target"
        echo "MODE=$(stat -c %a "$target" 2>/dev/null || echo "000")"
        echo "OWNER=$(stat -c %U "$target" 2>/dev/null || echo "unknown")"
        echo "GROUP=$(stat -c %G "$target" 2>/dev/null || echo "unknown")"
        echo "TYPE=$([[ -d "$target" ]] && echo "directory" || echo "file")"
    } > "$backup_file"
    
    if [[ -f "$backup_file" ]]; then
        log_message "INFO" "Sauvegarde permissions: $backup_file"
        echo "$backup_file"
        return 0
    else
        log_message "WARN" "Impossible de sauvegarder les permissions"
        return 1
    fi
}

get_current_permissions() {
    local target="$1"
    
    local mode owner group type size
    mode=$(stat -c %a "$target" 2>/dev/null || echo "000")
    owner=$(stat -c %U "$target" 2>/dev/null || echo "unknown")
    group=$(stat -c %G "$target" 2>/dev/null || echo "unknown")
    type=$([[ -d "$target" ]] && echo "directory" || echo "file")
    size=$(stat -c %s "$target" 2>/dev/null || echo 0)
    
    cat << EOF
{
    "mode": "$mode",
    "owner": "$owner",
    "group": "$group",
    "type": "$type",
    "size": $size,
    "symbolic": "$(stat -c %A "$target" 2>/dev/null || echo "unknown")"
}
EOF
}

count_affected_items() {
    local target="$1"
    local recursive="${2:-0}"
    local files_only="${3:-0}"
    local dirs_only="${4:-0}"
    
    if [[ "$recursive" == "1" && -d "$target" ]]; then
        local find_args=("$target")
        
        if [[ "$files_only" == "1" ]]; then
            find_args+=("-type" "f")
        elif [[ "$dirs_only" == "1" ]]; then
            find_args+=("-type" "d")
        fi
        
        find "${find_args[@]}" | wc -l
    else
        echo "1"
    fi
}

apply_permissions() {
    local target="$1"
    local permissions="$2"
    
    local chmod_args=()
    
    # Options chmod
    [[ "${RECURSIVE:-0}" == "1" ]] && chmod_args+=("-R")
    [[ "${DEREFERENCE:-0}" == "1" ]] && chmod_args+=("-H")
    [[ "${PRESERVE_ROOT:-0}" == "1" ]] && chmod_args+=("--preserve-root")
    [[ "${VERBOSE:-0}" == "1" ]] && chmod_args+=("-v")
    
    chmod_args+=("$permissions" "$target")
    
    log_message "DEBUG" "Commande: chmod ${chmod_args[*]}"
    
    if chmod "${chmod_args[@]}" 2>/dev/null; then
        log_message "INFO" "Permissions modifiées avec succès: $permissions"
        
        # Application sélective si demandée
        if [[ "${RECURSIVE:-0}" == "1" && -d "$target" ]]; then
            if [[ "${FILES_ONLY:-0}" == "1" ]]; then
                find "$target" -type f -exec chmod "$permissions" {} \; 2>/dev/null || true
                log_message "DEBUG" "Permissions appliquées aux fichiers seulement"
            elif [[ "${DIRS_ONLY:-0}" == "1" ]]; then
                find "$target" -type d -exec chmod "$permissions" {} \; 2>/dev/null || true
                log_message "DEBUG" "Permissions appliquées aux répertoires seulement"
            fi
        fi
        
        return 0
    else
        local exit_code=$?
        log_message "ERROR" "Échec changement permissions (code: $exit_code)"
        return 1
    fi
}

main() {
    local target=""
    local permissions=""
    local mode=""
    local user_perm=""
    local group_perm=""
    local other_perm=""
    
    # Analyse des arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--target)
                target="$2"
                shift 2
                ;;
            -p|--permissions)
                permissions="$2"
                shift 2
                ;;
            -m|--mode)
                mode="$2"
                shift 2
                ;;
            -u|--user)
                user_perm="$2"
                shift 2
                ;;
            -g|--group)
                group_perm="$2"
                shift 2
                ;;
            -o|--other)
                other_perm="$2"
                shift 2
                ;;
            -r|--recursive)
                RECURSIVE=1
                shift
                ;;
            -H|--dereference)
                DEREFERENCE=1
                shift
                ;;
            -P|--preserve-root)
                PRESERVE_ROOT=1
                shift
                ;;
            -f|--files-only)
                FILES_ONLY=1
                shift
                ;;
            -d|--dirs-only)
                DIRS_ONLY=1
                shift
                ;;
            -b|--backup)
                BACKUP_PERMISSIONS=1
                shift
                ;;
            --force)
                FORCE=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -q|--quiet)
                QUIET=1
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_message "ERROR" "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validation des paramètres obligatoires
    if [[ -z "$target" ]]; then
        log_message "ERROR" "Paramètre --target requis"
        show_help
        exit 1
    fi
    
    # Détermination des permissions finales
    local final_permissions=""
    
    if [[ -n "$mode" ]]; then
        # Mode prédéfini
        final_permissions=$(get_predefined_mode "$mode" "$target") || {
            echo '{"success": false, "error": "invalid_mode", "message": "Predefined mode resolution failed"}'
            exit 1
        }
    elif [[ -n "$permissions" ]]; then
        # Permissions spécifiées directement
        final_permissions=$(parse_permissions_spec "$permissions") || {
            echo '{"success": false, "error": "invalid_permissions", "message": "Permission parsing failed"}'
            exit 1
        }
    elif [[ -n "$user_perm" || -n "$group_perm" || -n "$other_perm" ]]; then
        # Construction par classes d'utilisateurs
        local u_octal g_octal o_octal
        u_octal=$(convert_symbolic_to_octal "${user_perm:----}")
        g_octal=$(convert_symbolic_to_octal "${group_perm:----}")
        o_octal=$(convert_symbolic_to_octal "${other_perm:----}")
        final_permissions="${u_octal}${g_octal}${o_octal}"
    else
        log_message "ERROR" "Aucune spécification de permissions fournie"
        show_help
        exit 1
    fi
    
    # Validation des conflits d'options
    if [[ "${FILES_ONLY:-0}" == "1" && "${DIRS_ONLY:-0}" == "1" ]]; then
        log_message "ERROR" "Options --files-only et --dirs-only mutuellement exclusives"
        exit 1
    fi
    
    # Vérification des dépendances
    if ! check_dependencies; then
        echo '{"success": false, "error": "dependencies_missing", "message": "Required tools not available"}'
        exit 1
    fi
    
    # Validation de la cible
    if ! validate_target "$target"; then
        echo '{"success": false, "error": "invalid_target", "message": "Target validation failed"}'
        exit 1
    fi
    
    # Validation sécurité des permissions
    if ! validate_permissions_security "$final_permissions" "$target"; then
        echo '{"success": false, "error": "security_validation", "message": "Permissions security validation failed"}'
        exit 1
    fi
    
    local start_time=$(date +%s)
    local backup_file=""
    local initial_permissions
    initial_permissions=$(get_current_permissions "$target")
    
    # Sauvegarde si demandée
    if [[ "${BACKUP_PERMISSIONS:-0}" == "1" ]]; then
        backup_file=$(backup_permissions "$target") || true
    fi
    
    # Comptage des éléments affectés
    local items_count
    items_count=$(count_affected_items "$target" "${RECURSIVE:-0}" "${FILES_ONLY:-0}" "${DIRS_ONLY:-0}")
    
    # Application des changements
    local operation_success=true
    
    if ! apply_permissions "$target" "$final_permissions"; then
        operation_success=false
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local final_permissions_state
    final_permissions_state=$(get_current_permissions "$target")
    
    # Génération du rapport JSON
    cat << EOF
{
    "success": $($operation_success && echo "true" || echo "false"),
    "target": "$target",
    "operation": "change_permissions",
    "recursive": ${RECURSIVE:-false},
    "files_only": ${FILES_ONLY:-false},
    "dirs_only": ${DIRS_ONLY:-false},
    "preserve_root": ${PRESERVE_ROOT:-false},
    "backup_file": "${backup_file:-null}",
    "duration_seconds": $duration,
    "items_affected": $items_count,
    "permissions": {
        "before": $initial_permissions,
        "after": $final_permissions_state,
        "requested": "$final_permissions",
        "mode_used": "${mode:-null}",
        "specification": {
            "user": "${user_perm:-null}",
            "group": "${group_perm:-null}",
            "other": "${other_perm:-null}"
        }
    },
    "security": {
        "world_writable": $([[ "$final_permissions" =~ [0-7]*[2367]$ ]] && echo "true" || echo "false"),
        "setuid_setgid": $([[ "$final_permissions" =~ ^[4567] ]] && echo "true" || echo "false"),
        "system_file": $([[ "$target" =~ ^/(etc|usr/bin|bin|sbin)/ ]] && echo "true" || echo "false"),
        "forced": ${FORCE:-false}
    },
    "system_info": {
        "current_user": "$(id -un)",
        "current_uid": $(id -u),
        "is_root": $([[ $(id -u) -eq 0 ]] && echo "true" || echo "false")
    },
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "script": "$SCRIPT_NAME"
}
EOF
}

# Point d'entrée principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi