#!/usr/bin/env bash

# ============================================================================
# Script atomique : set-system.hostname.sh
# Description : Configuration du nom d'hôte système avec persistance
# Auteur : Généré automatiquement
# Version : 1.0
# Usage : ./set-system.hostname.sh [OPTIONS]
# ============================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === FONCTIONS UTILITAIRES ===
show_help() {
    cat << 'EOF'
USAGE:
    set-system.hostname.sh [OPTIONS]

DESCRIPTION:
    Configure le nom d'hôte système avec gestion de la persistance.
    Supporte systemd, les méthodes traditionnelles et la mise à jour DNS.

OPTIONS:
    -n, --hostname NAME     Nouveau nom d'hôte (requis)
    -d, --domain DOMAIN     Domaine à ajouter (FQDN)
    --fqdn FQDN            Nom d'hôte complet (hostname.domain)
    -p, --persistent       Rendre le changement persistant
    -t, --temporary        Changement temporaire uniquement
    --update-hosts         Mettre à jour /etc/hosts automatiquement
    --preserve-hosts       Préserver /etc/hosts tel quel
    --systemd              Utiliser hostnamectl (systemd)
    --traditional          Utiliser les méthodes traditionnelles
    -b, --backup           Sauvegarder la configuration actuelle
    -r, --restart-services Redémarrer les services affectés
    -f, --force            Forcer les changements dangereux
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Afficher cette aide

HOSTNAME RULES:
    - Longueur: 1-63 caractères
    - Caractères autorisés: a-z, A-Z, 0-9, tirets (-)
    - Ne peut pas commencer ou finir par un tiret
    - Ne peut pas contenir uniquement des chiffres

EXAMPLES:
    # Changement temporaire
    set-system.hostname.sh -n "newhost" --temporary
    
    # Changement persistant avec domaine
    set-system.hostname.sh -n "server01" -d "example.com" --persistent
    
    # FQDN complet avec mise à jour hosts
    set-system.hostname.sh --fqdn "web.example.com" --update-hosts --persistent
    
    # Méthode traditionnelle
    set-system.hostname.sh -n "oldserver" --traditional --persistent

OUTPUT:
    JSON avec statut, configuration hostname et diagnostics réseau
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
    local deps=("hostname")
    local missing=()
    local optional_tools=("hostnamectl" "systemctl")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_message "ERROR" "Dépendances critiques manquantes: ${missing[*]}"
        return 1
    fi
    
    # Vérification des outils optionnels
    for tool in "${optional_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_message "DEBUG" "Outil disponible: $tool"
        fi
    done
    
    return 0
}

validate_hostname() {
    local hostname="$1"
    local allow_fqdn="${2:-0}"
    
    # Validation de la longueur totale
    if [[ ${#hostname} -gt 253 ]]; then
        log_message "ERROR" "Nom d'hôte trop long: ${#hostname} caractères (max: 253)"
        return 1
    fi
    
    # Si FQDN autorisé, diviser et valider chaque partie
    if [[ "$allow_fqdn" == "1" && "$hostname" == *"."* ]]; then
        local IFS='.'
        read -ra parts <<< "$hostname"
        
        for part in "${parts[@]}"; do
            if ! validate_hostname_part "$part"; then
                return 1
            fi
        done
        return 0
    fi
    
    # Validation d'une partie de hostname
    validate_hostname_part "$hostname"
}

validate_hostname_part() {
    local part="$1"
    
    # Longueur d'une partie (label)
    if [[ ${#part} -lt 1 || ${#part} -gt 63 ]]; then
        log_message "ERROR" "Partie hostname invalide (longueur): '$part' (doit être 1-63 caractères)"
        return 1
    fi
    
    # Caractères autorisés: lettres, chiffres, tirets
    if [[ ! "$part" =~ ^[a-zA-Z0-9-]+$ ]]; then
        log_message "ERROR" "Caractères invalides dans hostname: '$part' (seuls a-z, A-Z, 0-9, - autorisés)"
        return 1
    fi
    
    # Ne peut pas commencer ou finir par un tiret
    if [[ "$part" =~ ^- || "$part" =~ -$ ]]; then
        log_message "ERROR" "Hostname ne peut pas commencer ou finir par un tiret: '$part'"
        return 1
    fi
    
    # Ne peut pas être uniquement des chiffres
    if [[ "$part" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "Hostname ne peut pas être uniquement numérique: '$part'"
        return 1
    fi
    
    return 0
}

detect_hostname_method() {
    local method=""
    
    # Détection de la méthode disponible
    if command -v hostnamectl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
        method="systemd"
    elif [[ -f "/etc/hostname" ]]; then
        method="traditional"
    elif [[ -f "/etc/sysconfig/network" ]]; then
        method="redhat"
    else
        method="manual"
    fi
    
    log_message "DEBUG" "Méthode hostname détectée: $method"
    echo "$method"
}

get_current_hostname_config() {
    local current_hostname transient_hostname static_hostname
    
    # Hostname actuel
    current_hostname=$(hostname 2>/dev/null || echo "unknown")
    
    # Informations systemd si disponible
    if command -v hostnamectl >/dev/null 2>&1; then
        transient_hostname=$(hostnamectl status --transient 2>/dev/null || echo "")
        static_hostname=$(hostnamectl status --static 2>/dev/null || echo "")
    else
        transient_hostname="$current_hostname"
        static_hostname=$(cat /etc/hostname 2>/dev/null || echo "")
    fi
    
    # FQDN
    local fqdn
    fqdn=$(hostname -f 2>/dev/null || echo "$current_hostname")
    
    # Domaine
    local domain
    domain=$(hostname -d 2>/dev/null || echo "")
    
    cat << EOF
{
    "current": "$current_hostname",
    "transient": "$transient_hostname",
    "static": "$static_hostname",
    "fqdn": "$fqdn",
    "domain": "$domain"
}
EOF
}

backup_hostname_config() {
    local backup_dir="/tmp/hostname_backup_$(date +%s)"
    
    mkdir -p "$backup_dir"
    
    # Sauvegarde de la configuration actuelle
    {
        echo "# Sauvegarde configuration hostname"
        echo "# Date: $(date)"
        echo "CURRENT_HOSTNAME=$(hostname 2>/dev/null || echo "unknown")"
        echo "CURRENT_FQDN=$(hostname -f 2>/dev/null || hostname)"
        echo "CURRENT_DOMAIN=$(hostname -d 2>/dev/null || echo "")"
    } > "$backup_dir/hostname_current.conf"
    
    # Sauvegarde des fichiers de configuration
    [[ -f "/etc/hostname" ]] && cp "/etc/hostname" "$backup_dir/" 2>/dev/null
    [[ -f "/etc/hosts" ]] && cp "/etc/hosts" "$backup_dir/" 2>/dev/null
    [[ -f "/etc/sysconfig/network" ]] && cp "/etc/sysconfig/network" "$backup_dir/" 2>/dev/null
    
    # Informations systemd
    if command -v hostnamectl >/dev/null 2>&1; then
        hostnamectl status > "$backup_dir/hostnamectl_status.txt" 2>/dev/null || true
    fi
    
    log_message "INFO" "Sauvegarde hostname: $backup_dir"
    echo "$backup_dir"
}

set_hostname_systemd() {
    local hostname="$1"
    local persistent="${2:-0}"
    
    local hostnamectl_args=()
    
    if [[ "$persistent" == "1" ]]; then
        hostnamectl_args+=("set-hostname")
    else
        hostnamectl_args+=("hostname")
    fi
    
    hostnamectl_args+=("$hostname")
    
    log_message "DEBUG" "Commande systemd: hostnamectl ${hostnamectl_args[*]}"
    
    if hostnamectl "${hostnamectl_args[@]}" 2>/dev/null; then
        log_message "INFO" "Hostname configuré via systemd: $hostname"
        return 0
    else
        log_message "ERROR" "Échec configuration systemd hostname"
        return 1
    fi
}

set_hostname_traditional() {
    local hostname="$1"
    local persistent="${2:-0}"
    
    # Changement immédiat
    if hostname "$hostname" 2>/dev/null; then
        log_message "INFO" "Hostname temporaire configuré: $hostname"
    else
        log_message "ERROR" "Échec configuration hostname temporaire"
        return 1
    fi
    
    # Configuration persistante si demandée
    if [[ "$persistent" == "1" ]]; then
        # /etc/hostname
        if echo "$hostname" > /etc/hostname 2>/dev/null; then
            log_message "INFO" "Hostname écrit dans /etc/hostname"
        else
            log_message "ERROR" "Impossible d'écrire /etc/hostname"
            return 1
        fi
        
        # /etc/sysconfig/network (RedHat/CentOS)
        if [[ -f "/etc/sysconfig/network" ]]; then
            if grep -q "^HOSTNAME=" /etc/sysconfig/network; then
                sed -i "s/^HOSTNAME=.*/HOSTNAME=$hostname/" /etc/sysconfig/network
            else
                echo "HOSTNAME=$hostname" >> /etc/sysconfig/network
            fi
            log_message "INFO" "Hostname mis à jour dans /etc/sysconfig/network"
        fi
    fi
    
    return 0
}

update_etc_hosts() {
    local hostname="$1"
    local domain="${2:-}"
    local force="${3:-0}"
    
    local fqdn="$hostname"
    [[ -n "$domain" ]] && fqdn="${hostname}.${domain}"
    
    # Backup de /etc/hosts
    cp /etc/hosts /etc/hosts.bak.$(date +%s) 2>/dev/null || true
    
    # Récupération de l'IP locale principale
    local local_ip
    local_ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' | head -1 || echo "127.0.1.1")
    
    # Vérifier si une entrée existe déjà pour ce hostname
    if grep -q "\\b$hostname\\b" /etc/hosts; then
        if [[ "$force" == "1" ]]; then
            # Supprimer les anciennes entrées
            sed -i "/\\b$hostname\\b/d" /etc/hosts
            log_message "DEBUG" "Anciennes entrées hostname supprimées de /etc/hosts"
        else
            log_message "WARN" "Entrée hostname existante dans /etc/hosts (utiliser --force pour remplacer)"
            return 0
        fi
    fi
    
    # Ajout de la nouvelle entrée
    local hosts_line="$local_ip    $fqdn"
    [[ "$hostname" != "$fqdn" ]] && hosts_line="$hosts_line $hostname"
    
    if echo "$hosts_line" >> /etc/hosts; then
        log_message "INFO" "Entrée ajoutée à /etc/hosts: $hosts_line"
        return 0
    else
        log_message "ERROR" "Impossible de mettre à jour /etc/hosts"
        return 1
    fi
}

restart_affected_services() {
    local services=("systemd-logind" "dbus" "avahi-daemon")
    local restarted_services=()
    local failed_services=()
    
    for service in "${services[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            if systemctl reload-or-restart "$service" 2>/dev/null; then
                restarted_services+=("$service")
                log_message "INFO" "Service redémarré: $service"
            else
                failed_services+=("$service")
                log_message "WARN" "Échec redémarrage service: $service"
            fi
        fi
    done
    
    # Notification des services redémarrés
    if [[ ${#restarted_services[@]} -gt 0 ]]; then
        log_message "INFO" "Services redémarrés: ${restarted_services[*]}"
    fi
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_message "WARN" "Services non redémarrés: ${failed_services[*]}"
        return 1
    fi
    
    return 0
}

test_hostname_resolution() {
    local hostname="$1"
    local domain="${2:-}"
    
    local resolution_tests=()
    local fqdn="$hostname"
    [[ -n "$domain" ]] && fqdn="${hostname}.${domain}"
    
    # Test résolution hostname seul
    if getent hosts "$hostname" >/dev/null 2>&1; then
        resolution_tests+=("hostname:success")
    else
        resolution_tests+=("hostname:failed")
    fi
    
    # Test résolution FQDN si domaine présent
    if [[ -n "$domain" ]]; then
        if getent hosts "$fqdn" >/dev/null 2>&1; then
            resolution_tests+=("fqdn:success")
        else
            resolution_tests+=("fqdn:failed")
        fi
    fi
    
    # Test résolution inverse
    local local_ip
    local_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "")
    if [[ -n "$local_ip" ]] && getent hosts "$local_ip" >/dev/null 2>&1; then
        resolution_tests+=("reverse:success")
    else
        resolution_tests+=("reverse:failed")
    fi
    
    printf '%s\n' "${resolution_tests[@]}"
}

main() {
    local hostname=""
    local domain=""
    local fqdn=""
    local method=""
    
    # Analyse des arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--hostname)
                hostname="$2"
                shift 2
                ;;
            -d|--domain)
                domain="$2"
                shift 2
                ;;
            --fqdn)
                fqdn="$2"
                shift 2
                ;;
            -p|--persistent)
                PERSISTENT=1
                shift
                ;;
            -t|--temporary)
                TEMPORARY=1
                shift
                ;;
            --update-hosts)
                UPDATE_HOSTS=1
                shift
                ;;
            --preserve-hosts)
                PRESERVE_HOSTS=1
                shift
                ;;
            --systemd)
                method="systemd"
                shift
                ;;
            --traditional)
                method="traditional"
                shift
                ;;
            -b|--backup)
                BACKUP_CONFIG=1
                shift
                ;;
            -r|--restart-services)
                RESTART_SERVICES=1
                shift
                ;;
            -f|--force)
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
    
    # Traitement du FQDN
    if [[ -n "$fqdn" ]]; then
        hostname="${fqdn%%.*}"
        if [[ "$fqdn" == *"."* ]]; then
            domain="${fqdn#*.}"
        fi
    fi
    
    # Validation des paramètres obligatoires
    if [[ -z "$hostname" ]]; then
        log_message "ERROR" "Paramètre --hostname ou --fqdn requis"
        show_help
        exit 1
    fi
    
    # Validation des conflits
    if [[ "${PERSISTENT:-0}" == "1" && "${TEMPORARY:-0}" == "1" ]]; then
        log_message "ERROR" "Options --persistent et --temporary mutuellement exclusives"
        exit 1
    fi
    
    if [[ "${UPDATE_HOSTS:-0}" == "1" && "${PRESERVE_HOSTS:-0}" == "1" ]]; then
        log_message "ERROR" "Options --update-hosts et --preserve-hosts mutuellement exclusives"
        exit 1
    fi
    
    # Vérification des permissions
    if [[ "${PERSISTENT:-0}" == "1" && $(id -u) -ne 0 ]]; then
        log_message "ERROR" "Droits root requis pour les changements persistants"
        exit 1
    fi
    
    # Vérification des dépendances
    if ! check_dependencies; then
        echo '{"success": false, "error": "dependencies_missing", "message": "Required hostname tools not available"}'
        exit 1
    fi
    
    # Validation du hostname
    local allow_fqdn=0
    [[ -n "$domain" ]] && allow_fqdn=1
    
    if ! validate_hostname "$hostname" "$allow_fqdn"; then
        echo '{"success": false, "error": "invalid_hostname", "message": "Hostname validation failed"}'
        exit 1
    fi
    
    # Validation du domaine si fourni
    if [[ -n "$domain" ]] && ! validate_hostname "$domain" 1; then
        echo '{"success": false, "error": "invalid_domain", "message": "Domain validation failed"}'
        exit 1
    fi
    
    local start_time=$(date +%s)
    local backup_dir=""
    local initial_config
    initial_config=$(get_current_hostname_config)
    
    # Détection de la méthode si non spécifiée
    if [[ -z "$method" ]]; then
        method=$(detect_hostname_method)
    fi
    
    # Sauvegarde si demandée
    if [[ "${BACKUP_CONFIG:-0}" == "1" ]]; then
        backup_dir=$(backup_hostname_config) || true
    fi
    
    # Application des changements
    local operation_success=true
    local operations_applied=()
    
    # Configuration du hostname selon la méthode
    case "$method" in
        "systemd")
            if ! set_hostname_systemd "$hostname" "${PERSISTENT:-0}"; then
                operation_success=false
            else
                operations_applied+=("hostname_systemd")
            fi
            ;;
        "traditional"|"redhat"|"manual")
            if ! set_hostname_traditional "$hostname" "${PERSISTENT:-0}"; then
                operation_success=false
            else
                operations_applied+=("hostname_traditional")
            fi
            ;;
        *)
            log_message "ERROR" "Méthode hostname non supportée: $method"
            operation_success=false
            ;;
    esac
    
    # Mise à jour de /etc/hosts si demandée
    if [[ "$operation_success" == "true" && "${UPDATE_HOSTS:-0}" == "1" ]]; then
        if update_etc_hosts "$hostname" "$domain" "${FORCE:-0}"; then
            operations_applied+=("hosts_updated")
        else
            log_message "WARN" "Échec mise à jour /etc/hosts"
        fi
    fi
    
    # Redémarrage des services si demandé
    if [[ "$operation_success" == "true" && "${RESTART_SERVICES:-0}" == "1" ]]; then
        if restart_affected_services; then
            operations_applied+=("services_restarted")
        else
            log_message "WARN" "Certains services n'ont pas pu être redémarrés"
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local final_config
    final_config=$(get_current_hostname_config)
    
    # Tests de résolution
    local resolution_tests
    resolution_tests=($(test_hostname_resolution "$hostname" "$domain"))
    
    # Génération du rapport JSON
    cat << EOF
{
    "success": $($operation_success && echo "true" || echo "false"),
    "hostname": "$hostname",
    "domain": "${domain:-null}",
    "fqdn": "${hostname}${domain:+.${domain}}",
    "method": "$method",
    "persistent": ${PERSISTENT:-false},
    "backup_dir": "${backup_dir:-null}",
    "duration_seconds": $duration,
    "configuration": {
        "before": $initial_config,
        "after": $final_config
    },
    "operations_applied": $(printf '%s\n' "${operations_applied[@]}" | jq -R . | jq -s .),
    "resolution_tests": $(printf '%s\n' "${resolution_tests[@]}" | jq -R . | jq -s .),
    "files_modified": {
        "etc_hostname": $(([[ "${PERSISTENT:-0}" == "1" ]] && [[ "$method" != "systemd" ]]) && echo "true" || echo "false"),
        "etc_hosts": ${UPDATE_HOSTS:-false},
        "sysconfig_network": $([[ -f "/etc/sysconfig/network" && "${PERSISTENT:-0}" == "1" && "$method" != "systemd" ]] && echo "true" || echo "false")
    },
    "system_info": {
        "current_user": "$(id -un)",
        "is_root": $([[ $(id -u) -eq 0 ]] && echo "true" || echo "false"),
        "systemd_available": $(command -v hostnamectl >/dev/null && echo "true" || echo "false"),
        "distribution": "$(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
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