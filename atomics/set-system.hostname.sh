#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: set-system.hostname.sh
# Description: Configurer le nom d'hôte du système (temporaire et persistant)
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-06
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="set-system.hostname.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
NEW_HOSTNAME=""
PERSISTENT=${PERSISTENT:-1}
UPDATE_HOSTS=${UPDATE_HOSTS:-1}
FORCE=${FORCE:-0}

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
Usage: $SCRIPT_NAME [OPTIONS] <new_hostname>

Description:
    Configure le nom d'hôte du système de manière temporaire et/ou persistante.
    Supporte différentes méthodes selon la distribution Linux utilisée.

Arguments:
    <new_hostname>          Nouveau nom d'hôte (obligatoire)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -p, --persistent       Configuration persistante (défaut: activé)
    --no-persistent        Configuration temporaire uniquement
    --no-update-hosts      Ne pas mettre à jour /etc/hosts
    -f, --force            Forcer le changement même si identique
    
Règles de validation du nom d'hôte:
    - Longueur: 1-63 caractères
    - Caractères autorisés: a-z, A-Z, 0-9, tiret (-)
    - Doit commencer et finir par un caractère alphanumérique
    - Ne peut pas contenir de points (utiliser FQDN séparément)
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "hostname": "new-hostname",
        "previous_hostname": "old-hostname",
        "fqdn": "new-hostname.domain.com",
        "persistent": true,
        "hosts_updated": true,
        "method_used": "hostnamectl",
        "files_modified": [
          "/etc/hostname",
          "/etc/hosts"
        ]
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0  - Succès
    1  - Erreur générale
    2  - Paramètres invalides
    3  - Nom d'hôte invalide
    4  - Permissions insuffisantes
    5  - Fichier système non modifiable

Exemples:
    $SCRIPT_NAME web-server
    $SCRIPT_NAME --no-persistent temp-host
    $SCRIPT_NAME -f production-db

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
            -p|--persistent)
                PERSISTENT=1
                shift
                ;;
            --no-persistent)
                PERSISTENT=0
                shift
                ;;
            --no-update-hosts)
                UPDATE_HOSTS=0
                shift
                ;;
            -f|--force)
                FORCE=1
                shift
                ;;
            -*)
                die "Option inconnue: $1" 2
                ;;
            *)
                if [[ -z "$NEW_HOSTNAME" ]]; then
                    NEW_HOSTNAME="$1"
                else
                    die "Trop d'arguments positionnels" 2
                fi
                shift
                ;;
        esac
    done
    
    # Validation des arguments
    if [[ -z "$NEW_HOSTNAME" ]]; then
        die "Nouveau nom d'hôte manquant" 2
    fi
}

# =============================================================================
# Fonctions de Validation et Vérification
# =============================================================================

check_dependencies() {
    local missing_deps=()
    
    if ! command -v hostname >/dev/null 2>&1; then
        missing_deps+=("hostname")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        die "Dépendances manquantes: ${missing_deps[*]}" 1
    fi
}

validate_hostname() {
    local hostname="$1"
    
    # Vérifier la longueur
    if [[ ${#hostname} -lt 1 ]] || [[ ${#hostname} -gt 63 ]]; then
        return 1
    fi
    
    # Vérifier le format: lettres, chiffres, tirets seulement
    if ! [[ "$hostname" =~ ^[a-zA-Z0-9-]+$ ]]; then
        return 1
    fi
    
    # Ne doit pas commencer ou finir par un tiret
    if [[ "$hostname" =~ ^- ]] || [[ "$hostname" =~ -$ ]]; then
        return 1
    fi
    
    # Ne doit pas contenir de tirets consécutifs
    if [[ "$hostname" =~ -- ]]; then
        return 1
    fi
    
    # Vérifier qu'il ne s'agit pas d'un nombre pur
    if [[ "$hostname" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    return 0
}

get_current_hostname() {
    # Obtenir le nom d'hôte actuel
    hostname 2>/dev/null || echo "unknown"
}

get_hostname_method() {
    # Détecter la méthode de configuration disponible
    if command -v hostnamectl >/dev/null 2>&1 && systemctl is-active systemd-hostnamed >/dev/null 2>&1; then
        echo "hostnamectl"
    elif [[ -w /etc/hostname ]]; then
        echo "file"
    elif command -v hostname >/dev/null 2>&1; then
        echo "hostname-command"
    else
        echo "unknown"
    fi
}

backup_hostname_files() {
    local backup_dir="/tmp/hostname-backup-$(date +%s)"
    mkdir -p "$backup_dir"
    
    # Sauvegarder /etc/hostname
    if [[ -f /etc/hostname ]]; then
        cp /etc/hostname "$backup_dir/hostname" 2>/dev/null || true
    fi
    
    # Sauvegarder /etc/hosts
    if [[ -f /etc/hosts ]]; then
        cp /etc/hosts "$backup_dir/hosts" 2>/dev/null || true
    fi
    
    echo "$backup_dir"
}

update_hosts_file() {
    local new_hostname="$1"
    local old_hostname="$2"
    local warnings=()
    
    if [[ $UPDATE_HOSTS -eq 0 ]]; then
        log_debug "Mise à jour de /etc/hosts désactivée"
        return 0
    fi
    
    if [[ ! -f /etc/hosts ]]; then
        log_warn "Fichier /etc/hosts non trouvé"
        return 1
    fi
    
    log_debug "Mise à jour de /etc/hosts"
    
    # Créer une sauvegarde temporaire
    cp /etc/hosts /etc/hosts.backup.$(date +%s) 2>/dev/null || true
    
    # Mettre à jour les entrées localhost
    if grep -q "127.0.0.1.*$old_hostname" /etc/hosts 2>/dev/null; then
        sed -i "s/127\.0\.0\.1.*$old_hostname/127.0.0.1\t$new_hostname/g" /etc/hosts 2>/dev/null || {
            warnings+=("Failed to update IPv4 localhost entry in /etc/hosts")
        }
    else
        # Ajouter l'entrée si elle n'existe pas
        if ! grep -q "127.0.0.1.*$new_hostname" /etc/hosts 2>/dev/null; then
            echo -e "127.0.0.1\t$new_hostname" >> /etc/hosts 2>/dev/null || {
                warnings+=("Failed to add IPv4 localhost entry to /etc/hosts")
            }
        fi
    fi
    
    # Mettre à jour les entrées IPv6 si elles existent
    if grep -q "::1.*$old_hostname" /etc/hosts 2>/dev/null; then
        sed -i "s/::1.*$old_hostname/::1\t\t$new_hostname/g" /etc/hosts 2>/dev/null || {
            warnings+=("Failed to update IPv6 localhost entry in /etc/hosts")
        }
    fi
    
    return 0
}

# =============================================================================
# Fonction Principale de Configuration du Nom d'Hôte
# =============================================================================

set_system_hostname() {
    local new_hostname="$1"
    local errors=()
    local warnings=()
    local files_modified=()
    
    log_debug "Configuration du nom d'hôte: $new_hostname"
    
    # Valider le nom d'hôte
    if ! validate_hostname "$new_hostname"; then
        errors+=("Invalid hostname format: $new_hostname")
        handle_result "$new_hostname" "${errors[@]}" "${warnings[@]}"
        return 3
    fi
    
    # Obtenir le nom d'hôte actuel
    local current_hostname
    current_hostname=$(get_current_hostname)
    log_debug "Nom d'hôte actuel: $current_hostname"
    
    # Vérifier si le changement est nécessaire
    if [[ "$current_hostname" == "$new_hostname" ]] && [[ $FORCE -eq 0 ]]; then
        warnings+=("Hostname is already set to: $new_hostname")
        handle_result "$new_hostname" "${errors[@]}" "${warnings[@]}" "$current_hostname"
        return 0
    fi
    
    # Créer une sauvegarde des fichiers
    local backup_dir
    if [[ $PERSISTENT -eq 1 ]]; then
        backup_dir=$(backup_hostname_files)
        log_debug "Sauvegarde créée dans: $backup_dir"
    fi
    
    # Détecter la méthode de configuration
    local hostname_method
    hostname_method=$(get_hostname_method)
    log_debug "Méthode utilisée: $hostname_method"
    
    # Configuration temporaire (immédiate)
    log_info "Configuration temporaire du nom d'hôte"
    if hostname "$new_hostname" 2>/dev/null; then
        log_info "Nom d'hôte temporaire configuré: $new_hostname"
    else
        errors+=("Failed to set temporary hostname")
    fi
    
    # Configuration persistante
    if [[ $PERSISTENT -eq 1 ]] && [[ ${#errors[@]} -eq 0 ]]; then
        log_info "Configuration persistante du nom d'hôte"
        
        case "$hostname_method" in
            "hostnamectl")
                # Utiliser systemd hostnamectl
                if hostnamectl set-hostname "$new_hostname" 2>/dev/null; then
                    log_info "Nom d'hôte persistant configuré via hostnamectl"
                    files_modified+=("/etc/hostname")
                else
                    errors+=("Failed to set persistent hostname via hostnamectl")
                fi
                ;;
            "file")
                # Modifier directement /etc/hostname
                if echo "$new_hostname" > /etc/hostname 2>/dev/null; then
                    log_info "Nom d'hôte persistant configuré via /etc/hostname"
                    files_modified+=("/etc/hostname")
                else
                    errors+=("Failed to write to /etc/hostname")
                fi
                ;;
            *)
                warnings+=("Persistent hostname configuration not supported with method: $hostname_method")
                ;;
        esac
    fi
    
    # Mettre à jour /etc/hosts
    if [[ ${#errors[@]} -eq 0 ]]; then
        if update_hosts_file "$new_hostname" "$current_hostname"; then
            log_info "Fichier /etc/hosts mis à jour"
            files_modified+=("/etc/hosts")
        else
            warnings+=("Failed to update /etc/hosts file")
        fi
    fi
    
    # Vérifier que le changement a pris effet
    local final_hostname
    final_hostname=$(get_current_hostname)
    
    if [[ "$final_hostname" != "$new_hostname" ]] && [[ ${#errors[@]} -eq 0 ]]; then
        warnings+=("Hostname change may require system restart to take full effect")
    fi
    
    handle_result "$new_hostname" "${errors[@]}" "${warnings[@]}" "$current_hostname" "$hostname_method" "${files_modified[@]}"
    
    [[ ${#errors[@]} -eq 0 ]] && return 0 || return 1
}

handle_result() {
    local new_hostname="$1" current_hostname="$2" hostname_method="$3"
    shift 3
    local files_modified=("$@")
    local errors=() warnings=()
    
    # Les erreurs et warnings sont maintenant dans files_modified, il faut les séparer
    # Cette fonction sera appelée avec les paramètres dans le bon ordre depuis set_system_hostname
    
    # Réorganiser les paramètres car ils ne sont pas dans le bon ordre
    # Récupérer le nom d'hôte final
    local final_hostname
    final_hostname=$(get_current_hostname)
    
    # Construire le FQDN si possible
    local fqdn="$final_hostname"
    if command -v dnsdomainname >/dev/null 2>&1; then
        local domain
        domain=$(dnsdomainname 2>/dev/null)
        if [[ -n "$domain" ]] && [[ "$domain" != "(none)" ]]; then
            fqdn="$final_hostname.$domain"
        fi
    fi
    
    # Échapper pour JSON
    local hostname_escaped current_escaped fqdn_escaped method_escaped
    hostname_escaped=$(echo "$new_hostname" | sed 's/\\/\\\\/g; s/"/\\"/g')
    current_escaped=$(echo "${current_hostname:-unknown}" | sed 's/\\/\\\\/g; s/"/\\"/g')
    fqdn_escaped=$(echo "$fqdn" | sed 's/\\/\\\\/g; s/"/\\"/g')
    method_escaped=$(echo "${hostname_method:-unknown}" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Construire le tableau des fichiers modifiés
    local files_json="[]"
    if [[ ${#files_modified[@]} -gt 0 ]]; then
        local files_escaped=()
        for file in "${files_modified[@]}"; do
            files_escaped+=("\"$(echo "$file" | sed 's/\\/\\\\/g; s/"/\\"/g')\"")
        done
        files_json="[$(IFS=','; echo "${files_escaped[*]}")]"
    fi
    
    # Construire les tableaux d'erreurs et warnings (vides pour cette version simplifiée)
    local errors_json="[]" warnings_json="[]"
    
    # Déterminer le statut
    local status="success"
    local code=0
    local message="System hostname configured successfully"
    
    # Générer la réponse JSON
    cat << EOF
{
  "status": "$status",
  "code": $code,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "$message",
  "data": {
    "hostname": "$hostname_escaped",
    "previous_hostname": "$current_escaped",
    "fqdn": "$fqdn_escaped",
    "persistent": $([ $PERSISTENT -eq 1 ] && echo "true" || echo "false"),
    "hosts_updated": $([ $UPDATE_HOSTS -eq 1 ] && echo "true" || echo "false"),
    "method_used": "$method_escaped",
    "files_modified": $files_json
  },
  "errors": $errors_json,
  "warnings": $warnings_json
}
EOF
}

# Version corrigée de la fonction principale qui gère mieux les paramètres
set_system_hostname_fixed() {
    local new_hostname="$1"
    local errors=()
    local warnings=()
    local files_modified=()
    
    log_debug "Configuration du nom d'hôte: $new_hostname"
    
    # Valider le nom d'hôte
    if ! validate_hostname "$new_hostname"; then
        errors+=("Invalid hostname format: $new_hostname")
    fi
    
    # Obtenir le nom d'hôte actuel
    local current_hostname
    current_hostname=$(get_current_hostname)
    log_debug "Nom d'hôte actuel: $current_hostname"
    
    # Vérifier si le changement est nécessaire
    if [[ "$current_hostname" == "$new_hostname" ]] && [[ $FORCE -eq 0 ]]; then
        warnings+=("Hostname is already set to: $new_hostname")
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        # Détecter la méthode de configuration
        local hostname_method
        hostname_method=$(get_hostname_method)
        log_debug "Méthode utilisée: $hostname_method"
        
        # Configuration temporaire
        log_info "Configuration temporaire du nom d'hôte"
        if hostname "$new_hostname" 2>/dev/null; then
            log_info "Nom d'hôte temporaire configuré: $new_hostname"
        else
            errors+=("Failed to set temporary hostname")
        fi
        
        # Configuration persistante
        if [[ $PERSISTENT -eq 1 ]] && [[ ${#errors[@]} -eq 0 ]]; then
            log_info "Configuration persistante du nom d'hôte"
            
            case "$hostname_method" in
                "hostnamectl")
                    if hostnamectl set-hostname "$new_hostname" 2>/dev/null; then
                        log_info "Nom d'hôte persistant configuré via hostnamectl"
                        files_modified+=("/etc/hostname")
                    else
                        errors+=("Failed to set persistent hostname via hostnamectl")
                    fi
                    ;;
                "file")
                    if echo "$new_hostname" > /etc/hostname 2>/dev/null; then
                        log_info "Nom d'hôte persistant configuré via /etc/hostname"
                        files_modified+=("/etc/hostname")
                    else
                        errors+=("Failed to write to /etc/hostname")
                    fi
                    ;;
                *)
                    warnings+=("Persistent hostname configuration not supported with method: $hostname_method")
                    ;;
            esac
        fi
        
        # Mettre à jour /etc/hosts
        if [[ ${#errors[@]} -eq 0 ]]; then
            if update_hosts_file "$new_hostname" "$current_hostname"; then
                log_info "Fichier /etc/hosts mis à jour"
                files_modified+=("/etc/hosts")
            else
                warnings+=("Failed to update /etc/hosts file")
            fi
        fi
    fi
    
    # Générer la réponse avec tous les paramètres nécessaires
    generate_hostname_result "$new_hostname" "$current_hostname" "${errors[@]}" "${warnings[@]}" "${files_modified[@]}"
    
    [[ ${#errors[@]} -eq 0 ]] && return 0 || return 1
}

generate_hostname_result() {
    local new_hostname="$1" current_hostname="$2"
    shift 2
    local all_params=("$@")
    
    # Séparer erreurs, warnings et fichiers modifiés
    local errors=() warnings=() files_modified=()
    local mode="errors"
    
    for param in "${all_params[@]}"; do
        if [[ "$param" == "---WARNINGS---" ]]; then
            mode="warnings"
        elif [[ "$param" == "---FILES---" ]]; then
            mode="files"
        elif [[ "$mode" == "errors" ]]; then
            errors+=("$param")
        elif [[ "$mode" == "warnings" ]]; then
            warnings+=("$param")
        elif [[ "$mode" == "files" ]]; then
            files_modified+=("$param")
        fi
    done
    
    # Obtenir les informations finales
    local final_hostname hostname_method
    final_hostname=$(get_current_hostname)
    hostname_method=$(get_hostname_method)
    
    # Construire le FQDN
    local fqdn="$final_hostname"
    if command -v dnsdomainname >/dev/null 2>&1; then
        local domain
        domain=$(dnsdomainname 2>/dev/null)
        if [[ -n "$domain" ]] && [[ "$domain" != "(none)" ]]; then
            fqdn="$final_hostname.$domain"
        fi
    fi
    
    # Échapper pour JSON
    local hostname_escaped current_escaped fqdn_escaped method_escaped
    hostname_escaped=$(echo "$new_hostname" | sed 's/\\/\\\\/g; s/"/\\"/g')
    current_escaped=$(echo "$current_hostname" | sed 's/\\/\\\\/g; s/"/\\"/g')
    fqdn_escaped=$(echo "$fqdn" | sed 's/\\/\\\\/g; s/"/\\"/g')
    method_escaped=$(echo "$hostname_method" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Construire les tableaux JSON
    local errors_json="[]" warnings_json="[]" files_json="[]"
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        local errors_escaped=()
        for error in "${errors[@]}"; do
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
    
    if [[ ${#files_modified[@]} -gt 0 ]]; then
        local files_escaped=()
        for file in "${files_modified[@]}"; do
            files_escaped+=("\"$(echo "$file" | sed 's/\\/\\\\/g; s/"/\\"/g')\"")
        done
        files_json="[$(IFS=','; echo "${files_escaped[*]}")]"
    fi
    
    # Déterminer le statut
    local status="success"
    local code=0
    local message="System hostname configured successfully"
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        status="error"
        code=1
        message="Failed to configure system hostname"
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
    "hostname": "$hostname_escaped",
    "previous_hostname": "$current_escaped",
    "fqdn": "$fqdn_escaped",
    "persistent": $([ $PERSISTENT -eq 1 ] && echo "true" || echo "false"),
    "hosts_updated": $([ $UPDATE_HOSTS -eq 1 ] && echo "true" || echo "false"),
    "method_used": "$method_escaped",
    "files_modified": $files_json
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
    set_system_hostname_fixed "$NEW_HOSTNAME"
    
    log_info "Script completed"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi