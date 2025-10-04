#!/usr/bin/env bash

# ============================================================================
# Script atomique : set-network.interface.ip.sh
# Description : Configuration des adresses IP sur les interfaces réseau
# Auteur : Généré automatiquement
# Version : 1.0
# Usage : ./set-network.interface.ip.sh [OPTIONS]
# ============================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === FONCTIONS UTILITAIRES ===
show_help() {
    cat << 'EOF'
USAGE:
    set-network.interface.ip.sh [OPTIONS]

DESCRIPTION:
    Configure les adresses IP sur les interfaces réseau avec gestion avancée.
    Supporte IPv4/IPv6, interfaces multiples et configuration persistante.

OPTIONS:
    -i, --interface IFACE    Interface réseau (eth0, wlan0, etc.) - requis
    -a, --address IP         Adresse IP à configurer (avec CIDR: 192.168.1.10/24)
    -g, --gateway IP         Passerelle par défaut
    -d, --dns DNS1,DNS2      Serveurs DNS (séparés par des virgules)
    -m, --method METHOD      Méthode de configuration (static, dhcp, manual)
    --ipv6                   Configuration IPv6 (défaut: IPv4)
    --add                    Ajouter l'IP (ne pas remplacer)
    --remove                 Supprimer l'IP spécifiée
    --flush                  Supprimer toutes les IPs de l'interface
    -p, --persistent         Rendre la configuration persistante
    -t, --temporary          Configuration temporaire uniquement
    --netplan               Utiliser netplan pour la persistance
    --networkd              Utiliser systemd-networkd
    --ifupdown              Utiliser /etc/network/interfaces
    -b, --backup            Sauvegarder la configuration actuelle
    -v, --verbose           Mode verbeux
    -q, --quiet             Mode silencieux
    -h, --help              Afficher cette aide

EXAMPLES:
    # Configuration IP statique temporaire
    set-network.interface.ip.sh -i eth0 -a "192.168.1.10/24" -g "192.168.1.1"
    
    # Configuration persistante avec DNS
    set-network.interface.ip.sh -i eth0 -a "192.168.1.10/24" -g "192.168.1.1" -d "8.8.8.8,8.8.4.4" --persistent
    
    # Ajouter une IP supplémentaire
    set-network.interface.ip.sh -i eth0 -a "192.168.1.20/24" --add
    
    # Configuration DHCP
    set-network.interface.ip.sh -i eth0 -m dhcp --persistent
    
    # IPv6
    set-network.interface.ip.sh -i eth0 -a "2001:db8::10/64" --ipv6 --persistent

OUTPUT:
    JSON avec statut, configuration réseau et diagnostics
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
    local deps=("ip" "ping")
    local missing=()
    local optional_tools=("netplan" "systemctl" "nmcli")
    
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

validate_interface() {
    local interface="$1"
    
    # Vérifier si l'interface existe
    if [[ ! -d "/sys/class/net/$interface" ]]; then
        log_message "ERROR" "Interface inexistante: $interface"
        return 1
    fi
    
    # Vérifier l'état de l'interface
    local state
    state=$(cat "/sys/class/net/$interface/operstate" 2>/dev/null || echo "unknown")
    log_message "DEBUG" "État interface $interface: $state"
    
    return 0
}

validate_ip_address() {
    local ip_with_cidr="$1"
    local is_ipv6="${2:-0}"
    
    # Extraction IP et CIDR
    local ip="${ip_with_cidr%/*}"
    local cidr="${ip_with_cidr#*/}"
    
    if [[ "$is_ipv6" == "1" ]]; then
        # Validation IPv6
        if [[ ! "$ip" =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then
            log_message "ERROR" "Format IPv6 invalide: $ip"
            return 1
        fi
        
        # Validation CIDR IPv6 (0-128)
        if [[ "$cidr" != "$ip_with_cidr" ]] && ! [[ "$cidr" =~ ^([0-9]|[1-9][0-9]|1[0-1][0-9]|12[0-8])$ ]]; then
            log_message "ERROR" "CIDR IPv6 invalide: $cidr (doit être entre 0 et 128)"
            return 1
        fi
    else
        # Validation IPv4
        if [[ ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            log_message "ERROR" "Format IPv4 invalide: $ip"
            return 1
        fi
        
        # Validation des octets IPv4
        local IFS='.'
        read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [[ "$octet" -lt 0 || "$octet" -gt 255 ]]; then
                log_message "ERROR" "Octet IPv4 invalide: $octet"
                return 1
            fi
        done
        
        # Validation CIDR IPv4 (0-32)
        if [[ "$cidr" != "$ip_with_cidr" ]] && ! [[ "$cidr" =~ ^([0-9]|[12][0-9]|3[0-2])$ ]]; then
            log_message "ERROR" "CIDR IPv4 invalide: $cidr (doit être entre 0 et 32)"
            return 1
        fi
    fi
    
    return 0
}

validate_gateway() {
    local gateway="$1"
    local is_ipv6="${2:-0}"
    
    if [[ "$is_ipv6" == "1" ]]; then
        if [[ ! "$gateway" =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then
            log_message "ERROR" "Format passerelle IPv6 invalide: $gateway"
            return 1
        fi
    else
        if [[ ! "$gateway" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            log_message "ERROR" "Format passerelle IPv4 invalide: $gateway"
            return 1
        fi
    fi
    
    return 0
}

detect_network_manager() {
    local manager=""
    
    # Détection de l'ordre de préférence
    if command -v netplan >/dev/null 2>&1 && [[ -d "/etc/netplan" ]]; then
        manager="netplan"
    elif systemctl is-active NetworkManager >/dev/null 2>&1; then
        manager="networkmanager"
    elif systemctl is-active systemd-networkd >/dev/null 2>&1; then
        manager="systemd-networkd"
    elif [[ -f "/etc/network/interfaces" ]]; then
        manager="ifupdown"
    else
        manager="manual"
    fi
    
    log_message "DEBUG" "Gestionnaire réseau détecté: $manager"
    echo "$manager"
}

get_current_network_config() {
    local interface="$1"
    
    local ipv4_addrs=()
    local ipv6_addrs=()
    local gateway_v4="" gateway_v6=""
    
    # Récupération des adresses IPv4
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            ipv4_addrs+=("$line")
        fi
    done < <(ip -4 addr show "$interface" 2>/dev/null | grep -oP 'inet \K[^/]+/[0-9]+' || true)
    
    # Récupération des adresses IPv6
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            ipv6_addrs+=("$line")
        fi
    done < <(ip -6 addr show "$interface" 2>/dev/null | grep -oP 'inet6 \K[^/]+/[0-9]+' | grep -v '^fe80:' || true)
    
    # Récupération des passerelles
    gateway_v4=$(ip -4 route show default 2>/dev/null | grep "dev $interface" | head -1 | awk '{print $3}' || echo "")
    gateway_v6=$(ip -6 route show default 2>/dev/null | grep "dev $interface" | head -1 | awk '{print $3}' || echo "")
    
    cat << EOF
{
    "ipv4_addresses": $(printf '%s\n' "${ipv4_addrs[@]}" | jq -R . | jq -s .),
    "ipv6_addresses": $(printf '%s\n' "${ipv6_addrs[@]}" | jq -R . | jq -s .),
    "gateway_v4": "$gateway_v4",
    "gateway_v6": "$gateway_v6",
    "state": "$(cat "/sys/class/net/$interface/operstate" 2>/dev/null || echo "unknown")",
    "mtu": $(cat "/sys/class/net/$interface/mtu" 2>/dev/null || echo 0),
    "mac": "$(cat "/sys/class/net/$interface/address" 2>/dev/null || echo "unknown")"
}
EOF
}

backup_network_config() {
    local interface="$1"
    local backup_dir="/tmp/network_backup_$(date +%s)"
    
    mkdir -p "$backup_dir"
    
    # Sauvegarde de la configuration actuelle
    {
        echo "# Sauvegarde réseau pour interface: $interface"
        echo "# Date: $(date)"
        echo "INTERFACE=$interface"
        ip addr show "$interface" 2>/dev/null || true
        echo "--- Routes ---"
        ip route show dev "$interface" 2>/dev/null || true
        echo "--- DNS ---"
        cat /etc/resolv.conf 2>/dev/null || true
    } > "$backup_dir/interface_${interface}.conf"
    
    # Sauvegarde des fichiers de configuration selon le gestionnaire
    local manager
    manager=$(detect_network_manager)
    
    case "$manager" in
        "netplan")
            cp -r /etc/netplan/* "$backup_dir/" 2>/dev/null || true
            ;;
        "ifupdown")
            cp /etc/network/interfaces "$backup_dir/" 2>/dev/null || true
            ;;
        "systemd-networkd")
            cp -r /etc/systemd/network/* "$backup_dir/" 2>/dev/null || true
            ;;
    esac
    
    log_message "INFO" "Sauvegarde réseau: $backup_dir"
    echo "$backup_dir"
}

configure_ip_temporary() {
    local interface="$1"
    local address="$2"
    local gateway="$3"
    local is_ipv6="${4:-0}"
    local action="${5:-replace}"  # add, replace, remove
    
    local ip_family_flag=""
    [[ "$is_ipv6" == "1" ]] && ip_family_flag="-6" || ip_family_flag="-4"
    
    case "$action" in
        "add")
            log_message "DEBUG" "Ajout IP: ip $ip_family_flag addr add $address dev $interface"
            if ip "$ip_family_flag" addr add "$address" dev "$interface" 2>/dev/null; then
                log_message "INFO" "IP ajoutée avec succès: $address"
            else
                log_message "ERROR" "Échec ajout IP: $address"
                return 1
            fi
            ;;
        "remove")
            log_message "DEBUG" "Suppression IP: ip $ip_family_flag addr del $address dev $interface"
            if ip "$ip_family_flag" addr del "$address" dev "$interface" 2>/dev/null; then
                log_message "INFO" "IP supprimée avec succès: $address"
            else
                log_message "WARN" "IP non trouvée ou déjà supprimée: $address"
            fi
            ;;
        "replace")
            # Suppression des IPs existantes si demandé
            local existing_ips
            if [[ "$is_ipv6" == "1" ]]; then
                existing_ips=($(ip -6 addr show "$interface" 2>/dev/null | grep -oP 'inet6 \K[^/]+/[0-9]+' | grep -v '^fe80:' || true))
            else
                existing_ips=($(ip -4 addr show "$interface" 2>/dev/null | grep -oP 'inet \K[^/]+/[0-9]+' || true))
            fi
            
            for existing_ip in "${existing_ips[@]}"; do
                ip "$ip_family_flag" addr del "$existing_ip" dev "$interface" 2>/dev/null || true
            done
            
            # Ajout de la nouvelle IP
            if ip "$ip_family_flag" addr add "$address" dev "$interface" 2>/dev/null; then
                log_message "INFO" "IP configurée avec succès: $address"
            else
                log_message "ERROR" "Échec configuration IP: $address"
                return 1
            fi
            ;;
    esac
    
    # Configuration de la passerelle si fournie
    if [[ -n "$gateway" ]]; then
        if ip "$ip_family_flag" route add default via "$gateway" dev "$interface" 2>/dev/null; then
            log_message "INFO" "Passerelle configurée: $gateway"
        else
            log_message "WARN" "Échec configuration passerelle: $gateway"
        fi
    fi
    
    return 0
}

configure_dhcp() {
    local interface="$1"
    
    # Tentative avec dhclient
    if command -v dhclient >/dev/null 2>&1; then
        log_message "DEBUG" "Configuration DHCP avec dhclient"
        if dhclient "$interface" 2>/dev/null; then
            log_message "INFO" "DHCP configuré avec dhclient"
            return 0
        fi
    fi
    
    # Tentative avec dhcpcd
    if command -v dhcpcd >/dev/null 2>&1; then
        log_message "DEBUG" "Configuration DHCP avec dhcpcd"
        if dhcpcd "$interface" 2>/dev/null; then
            log_message "INFO" "DHCP configuré avec dhcpcd"
            return 0
        fi
    fi
    
    log_message "ERROR" "Aucun client DHCP disponible"
    return 1
}

make_persistent_netplan() {
    local interface="$1"
    local address="$2"
    local gateway="$3"
    local dns_servers="$4"
    local method="$5"
    local is_ipv6="${6:-0}"
    
    local netplan_file="/etc/netplan/50-${interface}.yaml"
    local ip_version="addresses"
    local gateway_key="gateway4"
    
    if [[ "$is_ipv6" == "1" ]]; then
        gateway_key="gateway6"
    fi
    
    {
        echo "network:"
        echo "  version: 2"
        echo "  ethernets:"
        echo "    $interface:"
        
        if [[ "$method" == "dhcp" ]]; then
            if [[ "$is_ipv6" == "1" ]]; then
                echo "      dhcp6: true"
            else
                echo "      dhcp4: true"
            fi
        else
            echo "      $ip_version:"
            echo "        - $address"
            
            if [[ -n "$gateway" ]]; then
                echo "      $gateway_key: $gateway"
            fi
        fi
        
        if [[ -n "$dns_servers" ]]; then
            echo "      nameservers:"
            echo "        addresses:"
            local IFS=','
            read -ra dns_array <<< "$dns_servers"
            for dns in "${dns_array[@]}"; do
                echo "        - $dns"
            done
        fi
    } > "$netplan_file"
    
    log_message "INFO" "Configuration netplan écrite: $netplan_file"
    
    # Application de la configuration
    if netplan apply 2>/dev/null; then
        log_message "INFO" "Configuration netplan appliquée avec succès"
        return 0
    else
        log_message "ERROR" "Échec application netplan"
        return 1
    fi
}

test_connectivity() {
    local gateway="${1:-}"
    local dns_server="${2:-8.8.8.8}"
    
    local connectivity_results=()
    
    # Test de la passerelle locale
    if [[ -n "$gateway" ]]; then
        if ping -c 1 -W 2 "$gateway" >/dev/null 2>&1; then
            connectivity_results+=("gateway:success")
            log_message "DEBUG" "Connectivité passerelle OK: $gateway"
        else
            connectivity_results+=("gateway:failed")
            log_message "WARN" "Connectivité passerelle échouée: $gateway"
        fi
    fi
    
    # Test DNS
    if ping -c 1 -W 3 "$dns_server" >/dev/null 2>&1; then
        connectivity_results+=("dns:success")
        log_message "DEBUG" "Connectivité DNS OK: $dns_server"
    else
        connectivity_results+=("dns:failed")
        log_message "WARN" "Connectivité DNS échouée: $dns_server"
    fi
    
    # Test Internet
    if ping -c 1 -W 5 "8.8.8.8" >/dev/null 2>&1; then
        connectivity_results+=("internet:success")
        log_message "DEBUG" "Connectivité Internet OK"
    else
        connectivity_results+=("internet:failed")
        log_message "WARN" "Connectivité Internet échouée"
    fi
    
    printf '%s\n' "${connectivity_results[@]}"
}

main() {
    local interface=""
    local address=""
    local gateway=""
    local dns_servers=""
    local method="static"
    local action="replace"
    local network_manager=""
    
    # Analyse des arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--interface)
                interface="$2"
                shift 2
                ;;
            -a|--address)
                address="$2"
                shift 2
                ;;
            -g|--gateway)
                gateway="$2"
                shift 2
                ;;
            -d|--dns)
                dns_servers="$2"
                shift 2
                ;;
            -m|--method)
                method="$2"
                shift 2
                ;;
            --ipv6)
                IPV6=1
                shift
                ;;
            --add)
                action="add"
                shift
                ;;
            --remove)
                action="remove"
                shift
                ;;
            --flush)
                action="flush"
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
            --netplan)
                network_manager="netplan"
                shift
                ;;
            --networkd)
                network_manager="systemd-networkd"
                shift
                ;;
            --ifupdown)
                network_manager="ifupdown"
                shift
                ;;
            -b|--backup)
                BACKUP_CONFIG=1
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
    if [[ -z "$interface" ]]; then
        log_message "ERROR" "Paramètre --interface requis"
        show_help
        exit 1
    fi
    
    # Validation des conflits
    if [[ "${PERSISTENT:-0}" == "1" && "${TEMPORARY:-0}" == "1" ]]; then
        log_message "ERROR" "Options --persistent et --temporary mutuellement exclusives"
        exit 1
    fi
    
    # Vérification des dépendances
    if ! check_dependencies; then
        echo '{"success": false, "error": "dependencies_missing", "message": "Required network tools not available"}'
        exit 1
    fi
    
    # Validation de l'interface
    if ! validate_interface "$interface"; then
        echo '{"success": false, "error": "invalid_interface", "message": "Network interface validation failed"}'
        exit 1
    fi
    
    # Validation de l'adresse IP si fournie
    if [[ -n "$address" ]] && ! validate_ip_address "$address" "${IPV6:-0}"; then
        echo '{"success": false, "error": "invalid_address", "message": "IP address validation failed"}'
        exit 1
    fi
    
    # Validation de la passerelle si fournie
    if [[ -n "$gateway" ]] && ! validate_gateway "$gateway" "${IPV6:-0}"; then
        echo '{"success": false, "error": "invalid_gateway", "message": "Gateway validation failed"}'
        exit 1
    fi
    
    local start_time=$(date +%s)
    local backup_dir=""
    local initial_config
    initial_config=$(get_current_network_config "$interface")
    
    # Détection du gestionnaire réseau si non spécifié
    if [[ -z "$network_manager" ]]; then
        network_manager=$(detect_network_manager)
    fi
    
    # Sauvegarde si demandée
    if [[ "${BACKUP_CONFIG:-0}" == "1" ]]; then
        backup_dir=$(backup_network_config "$interface") || true
    fi
    
    # Application de la configuration
    local operation_success=true
    local operation_details=()
    
    case "$method" in
        "dhcp")
            if ! configure_dhcp "$interface"; then
                operation_success=false
            else
                operation_details+=("dhcp_configured")
            fi
            ;;
        "static"|"manual")
            if [[ -z "$address" && "$action" != "flush" ]]; then
                log_message "ERROR" "Adresse IP requise pour la configuration statique"
                operation_success=false
            else
                if [[ "$action" == "flush" ]]; then
                    # Suppression de toutes les IPs
                    ip addr flush dev "$interface" 2>/dev/null || operation_success=false
                    operation_details+=("interface_flushed")
                else
                    if ! configure_ip_temporary "$interface" "$address" "$gateway" "${IPV6:-0}" "$action"; then
                        operation_success=false
                    else
                        operation_details+=("ip_configured_${action}")
                    fi
                fi
            fi
            ;;
        *)
            log_message "ERROR" "Méthode de configuration inconnue: $method"
            operation_success=false
            ;;
    esac
    
    # Configuration persistante si demandée
    if [[ "$operation_success" == "true" && "${PERSISTENT:-0}" == "1" ]]; then
        case "$network_manager" in
            "netplan")
                if ! make_persistent_netplan "$interface" "$address" "$gateway" "$dns_servers" "$method" "${IPV6:-0}"; then
                    log_message "WARN" "Échec configuration persistante netplan"
                else
                    operation_details+=("persistent_netplan")
                fi
                ;;
            *)
                log_message "WARN" "Configuration persistante non supportée pour: $network_manager"
                ;;
        esac
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local final_config
    final_config=$(get_current_network_config "$interface")
    
    # Test de connectivité
    local connectivity_tests
    connectivity_tests=($(test_connectivity "$gateway" "${dns_servers%%,*}"))
    
    # Génération du rapport JSON
    cat << EOF
{
    "success": $($operation_success && echo "true" || echo "false"),
    "interface": "$interface",
    "operation": "$method",
    "action": "$action",
    "ipv6": ${IPV6:-false},
    "persistent": ${PERSISTENT:-false},
    "backup_dir": "${backup_dir:-null}",
    "duration_seconds": $duration,
    "network_manager": "$network_manager",
    "configuration": {
        "before": $initial_config,
        "after": $final_config,
        "requested": {
            "address": "${address:-null}",
            "gateway": "${gateway:-null}",
            "dns_servers": "${dns_servers:-null}",
            "method": "$method"
        }
    },
    "operation_details": $(printf '%s\n' "${operation_details[@]}" | jq -R . | jq -s .),
    "connectivity_tests": $(printf '%s\n' "${connectivity_tests[@]}" | jq -R . | jq -s .),
    "system_info": {
        "kernel": "$(uname -r)",
        "distribution": "$(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")",
        "network_tools": {
            "ip": $(command -v ip >/dev/null && echo "true" || echo "false"),
            "netplan": $(command -v netplan >/dev/null && echo "true" || echo "false"),
            "nmcli": $(command -v nmcli >/dev/null && echo "true" || echo "false")
        }
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