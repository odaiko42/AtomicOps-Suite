#!/usr/bin/env bash

# ============================================================================
# Script atomique : set-system.timezone.sh
# Description : Configuration du fuseau horaire système avec synchronisation NTP
# Auteur : Généré automatiquement
# Version : 1.0
# Usage : ./set-system.timezone.sh [OPTIONS]
# ============================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === FONCTIONS UTILITAIRES ===
show_help() {
    cat << 'EOF'
USAGE:
    set-system.timezone.sh [OPTIONS]

DESCRIPTION:
    Configure le fuseau horaire système avec gestion NTP et synchronisation.
    Supporte systemd-timesyncd, chrony, ntpd et configuration manuelle.

OPTIONS:
    -z, --timezone TZ       Fuseau horaire (ex: Europe/Paris, UTC, America/New_York)
    -l, --list-timezones    Lister les fuseaux horaires disponibles
    --search PATTERN        Rechercher des fuseaux horaires
    --current               Afficher la configuration actuelle seulement
    -n, --ntp-enable        Activer la synchronisation NTP
    --ntp-disable          Désactiver la synchronisation NTP
    --ntp-server SERVER     Configurer un serveur NTP spécifique
    --ntp-servers LIST      Liste de serveurs NTP (séparés par des virgules)
    -s, --sync-now          Synchroniser l'heure immédiatement
    --systemd              Utiliser systemd-timesyncd
    --chrony               Utiliser chrony
    --ntpd                 Utiliser ntpd traditionnel
    -p, --persistent       Rendre les changements persistants (défaut)
    -t, --temporary        Changement temporaire uniquement
    -b, --backup           Sauvegarder la configuration actuelle
    -r, --restart-services Redémarrer les services de temps
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Afficher cette aide

TIMEZONE EXAMPLES:
    UTC                    - Temps universel coordonné
    Europe/Paris          - Heure de Paris (CET/CEST)
    America/New_York      - Heure de New York (EST/EDT)
    Asia/Tokyo            - Heure de Tokyo (JST)
    Australia/Sydney      - Heure de Sydney (AEST/AEDT)

EXAMPLES:
    # Changer de fuseau horaire
    set-system.timezone.sh -z "Europe/Paris"
    
    # Activer NTP avec serveurs personnalisés
    set-system.timezone.sh -z "UTC" --ntp-enable --ntp-servers "pool.ntp.org,time.google.com"
    
    # Synchronisation immédiate
    set-system.timezone.sh --sync-now
    
    # Rechercher des fuseaux horaires
    set-system.timezone.sh --search "Paris"
    
    # Configuration complète
    set-system.timezone.sh -z "America/New_York" --ntp-enable --sync-now --restart-services

OUTPUT:
    JSON avec statut, configuration timezone et informations de synchronisation
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
    local deps=("date" "timedatectl")
    local missing=()
    local optional_tools=("chrony" "ntpdate" "systemctl")
    
    # Vérification des dépendances critiques
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            # timedatectl est optionnel, on peut utiliser d'autres méthodes
            if [[ "$dep" != "timedatectl" ]]; then
                missing+=("$dep")
            fi
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

validate_timezone() {
    local timezone="$1"
    
    # Vérification via timedatectl si disponible
    if command -v timedatectl >/dev/null 2>&1; then
        if timedatectl list-timezones | grep -q "^${timezone}$"; then
            log_message "DEBUG" "Fuseau horaire validé via timedatectl: $timezone"
            return 0
        fi
    fi
    
    # Vérification via fichiers zoneinfo
    if [[ -f "/usr/share/zoneinfo/$timezone" ]]; then
        log_message "DEBUG" "Fuseau horaire validé via zoneinfo: $timezone"
        return 0
    fi
    
    # Vérification des fuseaux horaires standards
    case "$timezone" in
        UTC|GMT|EST|CST|MST|PST)
            log_message "DEBUG" "Fuseau horaire standard accepté: $timezone"
            return 0
            ;;
        *)
            log_message "ERROR" "Fuseau horaire invalide: $timezone"
            return 1
            ;;
    esac
}

detect_time_service() {
    local service=""
    
    # Détection de l'ordre de préférence
    if systemctl is-active systemd-timesyncd >/dev/null 2>&1; then
        service="systemd-timesyncd"
    elif systemctl is-active chrony >/dev/null 2>&1; then
        service="chrony"
    elif systemctl is-active chronyd >/dev/null 2>&1; then
        service="chronyd"
    elif systemctl is-active ntp >/dev/null 2>&1; then
        service="ntp"
    elif systemctl is-active ntpd >/dev/null 2>&1; then
        service="ntpd"
    elif command -v systemd-timesyncd >/dev/null 2>&1; then
        service="systemd-timesyncd"
    elif command -v chrony >/dev/null 2>&1; then
        service="chrony"
    elif command -v ntpd >/dev/null 2>&1; then
        service="ntpd"
    else
        service="manual"
    fi
    
    log_message "DEBUG" "Service de temps détecté: $service"
    echo "$service"
}

get_current_timezone_config() {
    local current_timezone current_time utc_time
    local ntp_enabled ntp_synchronized
    
    # Fuseau horaire actuel
    if command -v timedatectl >/dev/null 2>&1; then
        current_timezone=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "unknown")
        ntp_enabled=$(timedatectl show --property=NTP --value 2>/dev/null || echo "false")
        ntp_synchronized=$(timedatectl show --property=NTPSynchronized --value 2>/dev/null || echo "false")
    else
        current_timezone=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' || echo "unknown")
        ntp_enabled="unknown"
        ntp_synchronized="unknown"
    fi
    
    # Heures actuelles
    current_time=$(date '+%Y-%m-%d %H:%M:%S %Z')
    utc_time=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    
    # Service de temps actif
    local time_service
    time_service=$(detect_time_service)
    
    cat << EOF
{
    "timezone": "$current_timezone",
    "current_time": "$current_time",
    "utc_time": "$utc_time",
    "ntp_enabled": "$ntp_enabled",
    "ntp_synchronized": "$ntp_synchronized",
    "time_service": "$time_service"
}
EOF
}

list_available_timezones() {
    local pattern="${1:-}"
    
    if command -v timedatectl >/dev/null 2>&1; then
        if [[ -n "$pattern" ]]; then
            timedatectl list-timezones | grep -i "$pattern"
        else
            timedatectl list-timezones
        fi
    else
        # Fallback vers les fichiers zoneinfo
        find /usr/share/zoneinfo -type f -name '*' | \
        sed 's|/usr/share/zoneinfo/||' | \
        grep -v -E '^(posix|right)/' | \
        sort | \
        if [[ -n "$pattern" ]]; then
            grep -i "$pattern"
        else
            cat
        fi
    fi
}

backup_timezone_config() {
    local backup_dir="/tmp/timezone_backup_$(date +%s)"
    
    mkdir -p "$backup_dir"
    
    # Sauvegarde de la configuration actuelle
    {
        echo "# Sauvegarde configuration timezone"
        echo "# Date: $(date)"
        if command -v timedatectl >/dev/null 2>&1; then
            echo "=== timedatectl status ==="
            timedatectl status 2>/dev/null || true
        fi
        echo "=== date ==="
        date
        echo "=== TZ environment ==="
        echo "TZ=${TZ:-not_set}"
    } > "$backup_dir/timezone_current.conf"
    
    # Sauvegarde des fichiers de configuration
    [[ -e "/etc/localtime" ]] && cp -P "/etc/localtime" "$backup_dir/" 2>/dev/null
    [[ -f "/etc/timezone" ]] && cp "/etc/timezone" "$backup_dir/" 2>/dev/null
    [[ -f "/etc/chrony.conf" ]] && cp "/etc/chrony.conf" "$backup_dir/" 2>/dev/null
    [[ -f "/etc/ntp.conf" ]] && cp "/etc/ntp.conf" "$backup_dir/" 2>/dev/null
    [[ -f "/etc/systemd/timesyncd.conf" ]] && cp "/etc/systemd/timesyncd.conf" "$backup_dir/" 2>/dev/null
    
    log_message "INFO" "Sauvegarde timezone: $backup_dir"
    echo "$backup_dir"
}

set_timezone_systemd() {
    local timezone="$1"
    
    if ! command -v timedatectl >/dev/null 2>&1; then
        log_message "ERROR" "timedatectl non disponible"
        return 1
    fi
    
    log_message "DEBUG" "Configuration timezone via systemd: $timezone"
    
    if timedatectl set-timezone "$timezone" 2>/dev/null; then
        log_message "INFO" "Fuseau horaire configuré via systemd: $timezone"
        return 0
    else
        log_message "ERROR" "Échec configuration timezone systemd"
        return 1
    fi
}

set_timezone_traditional() {
    local timezone="$1"
    
    local zoneinfo_file="/usr/share/zoneinfo/$timezone"
    
    if [[ ! -f "$zoneinfo_file" ]]; then
        log_message "ERROR" "Fichier zoneinfo introuvable: $zoneinfo_file"
        return 1
    fi
    
    # Sauvegarde de l'ancien lien
    [[ -e "/etc/localtime" ]] && rm -f "/etc/localtime"
    
    # Création du nouveau lien symbolique
    if ln -sf "$zoneinfo_file" "/etc/localtime"; then
        log_message "INFO" "Lien symbolique créé: /etc/localtime -> $zoneinfo_file"
        
        # Mise à jour /etc/timezone si présent
        if [[ -f "/etc/timezone" ]]; then
            echo "$timezone" > /etc/timezone
            log_message "INFO" "Fichier /etc/timezone mis à jour"
        fi
        
        return 0
    else
        log_message "ERROR" "Impossible de créer le lien symbolique /etc/localtime"
        return 1
    fi
}

configure_ntp_systemd() {
    local enable="$1"
    local servers="${2:-}"
    
    if ! command -v timedatectl >/dev/null 2>&1; then
        log_message "ERROR" "timedatectl non disponible pour configuration NTP"
        return 1
    fi
    
    # Activation/désactivation NTP
    if [[ "$enable" == "true" ]]; then
        if timedatectl set-ntp true 2>/dev/null; then
            log_message "INFO" "NTP activé via systemd"
        else
            log_message "ERROR" "Échec activation NTP systemd"
            return 1
        fi
    else
        if timedatectl set-ntp false 2>/dev/null; then
            log_message "INFO" "NTP désactivé via systemd"
        else
            log_message "ERROR" "Échec désactivation NTP systemd"
            return 1
        fi
    fi
    
    # Configuration des serveurs NTP pour systemd-timesyncd
    if [[ -n "$servers" && "$enable" == "true" ]]; then
        local timesyncd_conf="/etc/systemd/timesyncd.conf"
        
        # Sauvegarde du fichier de configuration
        [[ -f "$timesyncd_conf" ]] && cp "$timesyncd_conf" "${timesyncd_conf}.bak.$(date +%s)"
        
        # Configuration des serveurs
        {
            echo "[Time]"
            echo "NTP=$servers"
            echo "FallbackNTP=pool.ntp.org"
        } > "$timesyncd_conf"
        
        # Redémarrage du service
        if systemctl restart systemd-timesyncd 2>/dev/null; then
            log_message "INFO" "Serveurs NTP configurés: $servers"
        else
            log_message "WARN" "Échec redémarrage systemd-timesyncd"
        fi
    fi
    
    return 0
}

configure_ntp_chrony() {
    local enable="$1"
    local servers="${2:-}"
    
    local chrony_conf="/etc/chrony.conf"
    local chrony_service="chrony"
    
    # Détection du service chrony (chrony ou chronyd)
    if systemctl list-unit-files | grep -q "chronyd.service"; then
        chrony_service="chronyd"
    fi
    
    if [[ "$enable" == "true" ]]; then
        # Configuration des serveurs si spécifiés
        if [[ -n "$servers" ]]; then
            # Sauvegarde
            [[ -f "$chrony_conf" ]] && cp "$chrony_conf" "${chrony_conf}.bak.$(date +%s)"
            
            # Suppression des anciennes entrées server/pool
            sed -i '/^server /d; /^pool /d' "$chrony_conf" 2>/dev/null || true
            
            # Ajout des nouveaux serveurs
            local IFS=','
            read -ra server_array <<< "$servers"
            for server in "${server_array[@]}"; do
                echo "server $server iburst" >> "$chrony_conf"
            done
            
            log_message "INFO" "Serveurs chrony configurés: $servers"
        fi
        
        # Activation et démarrage du service
        if systemctl enable "$chrony_service" 2>/dev/null && systemctl start "$chrony_service" 2>/dev/null; then
            log_message "INFO" "Service chrony activé et démarré"
        else
            log_message "ERROR" "Échec activation chrony"
            return 1
        fi
    else
        # Désactivation du service
        if systemctl stop "$chrony_service" 2>/dev/null && systemctl disable "$chrony_service" 2>/dev/null; then
            log_message "INFO" "Service chrony désactivé"
        else
            log_message "WARN" "Échec désactivation chrony"
        fi
    fi
    
    return 0
}

sync_time_now() {
    local success=false
    
    # Tentative avec timedatectl
    if command -v timedatectl >/dev/null 2>&1; then
        if timedatectl set-ntp true 2>/dev/null; then
            sleep 2  # Attendre la synchronisation
            if timedatectl timesync-status >/dev/null 2>&1; then
                log_message "INFO" "Synchronisation réussie via systemd-timesyncd"
                success=true
            fi
        fi
    fi
    
    # Tentative avec chrony
    if ! $success && command -v chronyc >/dev/null 2>&1; then
        if chronyc makestep >/dev/null 2>&1; then
            log_message "INFO" "Synchronisation réussie via chrony"
            success=true
        fi
    fi
    
    # Tentative avec ntpdate
    if ! $success && command -v ntpdate >/dev/null 2>&1; then
        if ntpdate -s pool.ntp.org >/dev/null 2>&1; then
            log_message "INFO" "Synchronisation réussie via ntpdate"
            success=true
        fi
    fi
    
    # Tentative avec sntp
    if ! $success && command -v sntp >/dev/null 2>&1; then
        if sntp -sS pool.ntp.org >/dev/null 2>&1; then
            log_message "INFO" "Synchronisation réussie via sntp"
            success=true
        fi
    fi
    
    if ! $success; then
        log_message "ERROR" "Aucune méthode de synchronisation disponible"
        return 1
    fi
    
    return 0
}

restart_time_services() {
    local services=("systemd-timesyncd" "chrony" "chronyd" "ntp" "ntpd")
    local restarted_services=()
    local failed_services=()
    
    for service in "${services[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            if systemctl restart "$service" 2>/dev/null; then
                restarted_services+=("$service")
                log_message "INFO" "Service redémarré: $service"
            else
                failed_services+=("$service")
                log_message "WARN" "Échec redémarrage service: $service"
            fi
        fi
    done
    
    if [[ ${#restarted_services[@]} -gt 0 ]]; then
        log_message "INFO" "Services de temps redémarrés: ${restarted_services[*]}"
    fi
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_message "WARN" "Services non redémarrés: ${failed_services[*]}"
        return 1
    fi
    
    return 0
}

get_time_synchronization_status() {
    local sync_status=()
    
    # Statut systemd
    if command -v timedatectl >/dev/null 2>&1; then
        local ntp_sync
        ntp_sync=$(timedatectl show --property=NTPSynchronized --value 2>/dev/null || echo "unknown")
        sync_status+=("systemd:$ntp_sync")
    fi
    
    # Statut chrony
    if command -v chronyc >/dev/null 2>&1; then
        local chrony_sync="unknown"
        if chronyc tracking >/dev/null 2>&1; then
            chrony_sync="active"
        else
            chrony_sync="inactive"
        fi
        sync_status+=("chrony:$chrony_sync")
    fi
    
    # Statut ntpq
    if command -v ntpq >/dev/null 2>&1; then
        local ntp_sync="unknown"
        if ntpq -p >/dev/null 2>&1; then
            ntp_sync="active"
        else
            ntp_sync="inactive"
        fi
        sync_status+=("ntp:$ntp_sync")
    fi
    
    printf '%s\n' "${sync_status[@]}"
}

main() {
    local timezone=""
    local ntp_servers=""
    local time_service=""
    
    # Analyse des arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -z|--timezone)
                timezone="$2"
                shift 2
                ;;
            -l|--list-timezones)
                list_available_timezones
                exit 0
                ;;
            --search)
                list_available_timezones "$2"
                exit 0
                ;;
            --current)
                get_current_timezone_config
                exit 0
                ;;
            -n|--ntp-enable)
                NTP_ENABLE=1
                shift
                ;;
            --ntp-disable)
                NTP_DISABLE=1
                shift
                ;;
            --ntp-server)
                ntp_servers="$2"
                shift 2
                ;;
            --ntp-servers)
                ntp_servers="$2"
                shift 2
                ;;
            -s|--sync-now)
                SYNC_NOW=1
                shift
                ;;
            --systemd)
                time_service="systemd"
                shift
                ;;
            --chrony)
                time_service="chrony"
                shift
                ;;
            --ntpd)
                time_service="ntpd"
                shift
                ;;
            -p|--persistent)
                PERSISTENT=1
                shift
                ;;
            -t|--temporary)
                TEMPORARY=1
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
    
    # Validation des conflits
    if [[ "${NTP_ENABLE:-0}" == "1" && "${NTP_DISABLE:-0}" == "1" ]]; then
        log_message "ERROR" "Options --ntp-enable et --ntp-disable mutuellement exclusives"
        exit 1
    fi
    
    if [[ "${PERSISTENT:-1}" == "1" && "${TEMPORARY:-0}" == "1" ]]; then
        log_message "ERROR" "Options --persistent et --temporary mutuellement exclusives"
        exit 1
    fi
    
    # Par défaut persistent à 1 sauf si temporary spécifié
    [[ "${TEMPORARY:-0}" == "1" ]] && PERSISTENT=0 || PERSISTENT=1
    
    # Vérification des permissions pour les changements persistants
    if [[ "${PERSISTENT:-0}" == "1" && $(id -u) -ne 0 ]]; then
        log_message "ERROR" "Droits root requis pour les changements persistants"
        exit 1
    fi
    
    # Vérification des dépendances
    if ! check_dependencies; then
        echo '{"success": false, "error": "dependencies_missing", "message": "Required time tools not available"}'
        exit 1
    fi
    
    # Validation du fuseau horaire si fourni
    if [[ -n "$timezone" ]] && ! validate_timezone "$timezone"; then
        echo '{"success": false, "error": "invalid_timezone", "message": "Timezone validation failed"}'
        exit 1
    fi
    
    local start_time=$(date +%s)
    local backup_dir=""
    local initial_config
    initial_config=$(get_current_timezone_config)
    
    # Détection du service de temps si non spécifié
    if [[ -z "$time_service" ]]; then
        time_service=$(detect_time_service)
    fi
    
    # Sauvegarde si demandée
    if [[ "${BACKUP_CONFIG:-0}" == "1" ]]; then
        backup_dir=$(backup_timezone_config) || true
    fi
    
    # Application des changements
    local operation_success=true
    local operations_applied=()
    
    # Configuration du fuseau horaire
    if [[ -n "$timezone" ]]; then
        if command -v timedatectl >/dev/null 2>&1 && [[ "$time_service" == "systemd" ]]; then
            if set_timezone_systemd "$timezone"; then
                operations_applied+=("timezone_systemd")
            else
                operation_success=false
            fi
        else
            if set_timezone_traditional "$timezone"; then
                operations_applied+=("timezone_traditional")
            else
                operation_success=false
            fi
        fi
    fi
    
    # Configuration NTP
    if [[ "${NTP_ENABLE:-0}" == "1" || "${NTP_DISABLE:-0}" == "1" ]]; then
        local enable_ntp="true"
        [[ "${NTP_DISABLE:-0}" == "1" ]] && enable_ntp="false"
        
        case "$time_service" in
            "systemd"|"systemd-timesyncd")
                if configure_ntp_systemd "$enable_ntp" "$ntp_servers"; then
                    operations_applied+=("ntp_systemd")
                else
                    log_message "WARN" "Échec configuration NTP systemd"
                fi
                ;;
            "chrony"|"chronyd")
                if configure_ntp_chrony "$enable_ntp" "$ntp_servers"; then
                    operations_applied+=("ntp_chrony")
                else
                    log_message "WARN" "Échec configuration NTP chrony"
                fi
                ;;
            *)
                log_message "WARN" "Configuration NTP non supportée pour: $time_service"
                ;;
        esac
    fi
    
    # Synchronisation immédiate si demandée
    if [[ "${SYNC_NOW:-0}" == "1" ]]; then
        if sync_time_now; then
            operations_applied+=("time_synced")
        else
            log_message "WARN" "Échec synchronisation immédiate"
        fi
    fi
    
    # Redémarrage des services si demandé
    if [[ "${RESTART_SERVICES:-0}" == "1" ]]; then
        if restart_time_services; then
            operations_applied+=("services_restarted")
        else
            log_message "WARN" "Certains services n'ont pas pu être redémarrés"
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local final_config
    final_config=$(get_current_timezone_config)
    
    # Statut de synchronisation
    local sync_status
    sync_status=($(get_time_synchronization_status))
    
    # Génération du rapport JSON
    cat << EOF
{
    "success": $($operation_success && echo "true" || echo "false"),
    "timezone": "${timezone:-null}",
    "time_service": "$time_service",
    "persistent": ${PERSISTENT:-true},
    "backup_dir": "${backup_dir:-null}",
    "duration_seconds": $duration,
    "configuration": {
        "before": $initial_config,
        "after": $final_config
    },
    "ntp_configuration": {
        "enabled": ${NTP_ENABLE:-null},
        "disabled": ${NTP_DISABLE:-null},
        "servers": "${ntp_servers:-null}",
        "sync_now": ${SYNC_NOW:-false}
    },
    "operations_applied": $(printf '%s\n' "${operations_applied[@]}" | jq -R . | jq -s .),
    "synchronization_status": $(printf '%s\n' "${sync_status[@]}" | jq -R . | jq -s .),
    "system_info": {
        "current_user": "$(id -un)",
        "is_root": $([[ $(id -u) -eq 0 ]] && echo "true" || echo "false"),
        "time_tools": {
            "timedatectl": $(command -v timedatectl >/dev/null && echo "true" || echo "false"),
            "chrony": $(command -v chronyc >/dev/null && echo "true" || echo "false"),
            "ntp": $(command -v ntpq >/dev/null && echo "true" || echo "false")
        },
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