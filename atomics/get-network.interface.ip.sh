#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: get-network.interface.ip.sh
# Description: Récupère les adresses IP d'une interface réseau spécifique
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-01-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="get-network.interface.ip.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
ALL_INTERFACES=${ALL_INTERFACES:-0}
IPV4_ONLY=${IPV4_ONLY:-0}
IPV6_ONLY=${IPV6_ONLY:-0}
INCLUDE_LOOPBACK=${INCLUDE_LOOPBACK:-0}
INTERFACE_NAME=""

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
Usage: $SCRIPT_NAME [OPTIONS] [interface_name]

Description:
    Récupère les adresses IP (IPv4 et/ou IPv6) d'une interface réseau
    spécifique avec informations détaillées sur la configuration réseau.

Arguments:
    [interface_name]        Nom de l'interface (ex: eth0, wlan0, enp0s3)
                           Si omis, utilise --all pour lister toutes les interfaces

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -a, --all              Lister toutes les interfaces réseau
    -4, --ipv4-only        Afficher seulement les adresses IPv4
    -6, --ipv6-only        Afficher seulement les adresses IPv6
    -l, --include-loopback Inclure l'interface loopback (lo)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "interface": "eth0",
        "exists": true,
        "state": "UP",
        "mac_address": "00:11:22:33:44:55",
        "mtu": 1500,
        "addresses": {
          "ipv4": [
            {
              "ip": "192.168.1.100",
              "netmask": "255.255.255.0",
              "cidr": "192.168.1.100/24",
              "network": "192.168.1.0",
              "broadcast": "192.168.1.255",
              "scope": "global"
            }
          ],
          "ipv6": [
            {
              "ip": "fe80::211:22ff:fe33:4455",
              "prefix": 64,
              "scope": "link"
            }
          ]
        },
        "gateway": "192.168.1.1",
        "dns_servers": ["192.168.1.1", "8.8.8.8"]
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Interface inexistante
    4 - Interface sans IP

Exemples:
    $SCRIPT_NAME eth0                         # IPs de eth0
    $SCRIPT_NAME --all                        # Toutes les interfaces
    $SCRIPT_NAME --ipv4-only wlan0            # IPv4 uniquement
    $SCRIPT_NAME --ipv6-only eth0             # IPv6 uniquement
    $SCRIPT_NAME --include-loopback --all     # Inclure loopback
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
            -a|--all)
                ALL_INTERFACES=1
                shift
                ;;
            -4|--ipv4-only)
                IPV4_ONLY=1
                shift
                ;;
            -6|--ipv6-only)
                IPV6_ONLY=1
                shift
                ;;
            -l|--include-loopback)
                INCLUDE_LOOPBACK=1
                shift
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                if [[ -z "$INTERFACE_NAME" ]]; then
                    INTERFACE_NAME="$1"
                else
                    die "Interface déjà spécifiée: $INTERFACE_NAME. Argument supplémentaire: $1" 2
                fi
                shift
                ;;
        esac
    done

    # Validation cohérence options
    if [[ $IPV4_ONLY -eq 1 && $IPV6_ONLY -eq 1 ]]; then
        die "Options --ipv4-only et --ipv6-only mutuellement exclusives" 2
    fi

    # Si pas d'interface spécifiée et pas --all, demander une interface
    if [[ -z "$INTERFACE_NAME" && $ALL_INTERFACES -eq 0 ]]; then
        die "Interface name required or use --all option. Utilisez -h pour l'aide." 2
    fi
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    # Vérifier disponibilité des outils réseau
    if ! command -v ip >/dev/null 2>&1 && ! command -v ifconfig >/dev/null 2>&1; then
        missing+=("ip ou ifconfig")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Toutes les dépendances sont disponibles"
}

interface_exists() {
    local interface="$1"
    
    if command -v ip >/dev/null 2>&1; then
        ip link show "$interface" >/dev/null 2>&1
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig "$interface" >/dev/null 2>&1
    else
        false
    fi
}

get_interface_state() {
    local interface="$1"
    
    if command -v ip >/dev/null 2>&1; then
        ip link show "$interface" 2>/dev/null | grep -oE "state [A-Z]+" | awk '{print $2}' | head -1
    elif command -v ifconfig >/dev/null 2>&1; then
        if ifconfig "$interface" 2>/dev/null | grep -q "UP"; then
            echo "UP"
        else
            echo "DOWN"
        fi
    else
        echo "UNKNOWN"
    fi
}

get_interface_mac() {
    local interface="$1"
    
    if command -v ip >/dev/null 2>&1; then
        ip link show "$interface" 2>/dev/null | grep -oE "link/ether [a-fA-F0-9:]{17}" | awk '{print $2}'
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig "$interface" 2>/dev/null | grep -oE "ether [a-fA-F0-9:]{17}" | awk '{print $2}'
    fi
}

get_interface_mtu() {
    local interface="$1"
    
    if command -v ip >/dev/null 2>&1; then
        ip link show "$interface" 2>/dev/null | grep -oE "mtu [0-9]+" | awk '{print $2}'
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig "$interface" 2>/dev/null | grep -oE "mtu [0-9]+" | awk '{print $2}'
    fi
}

get_ipv4_addresses() {
    local interface="$1"
    local ipv4_json=""
    
    log_debug "Récupération adresses IPv4 pour $interface"
    
    if command -v ip >/dev/null 2>&1; then
        # Utiliser ip addr pour récupérer les IPv4
        while IFS= read -r line; do
            if [[ $line =~ inet\ ([0-9.]+)/([0-9]+) ]]; then
                local ip="${BASH_REMATCH[1]}"
                local cidr="${BASH_REMATCH[2]}"
                local scope="global"
                
                # Extraire le scope si présent
                if [[ $line =~ scope\ ([a-z]+) ]]; then
                    scope="${BASH_REMATCH[1]}"
                fi
                
                # Calculer netmask, network et broadcast
                local netmask network broadcast
                case $cidr in
                    8) netmask="255.0.0.0" ;;
                    16) netmask="255.255.0.0" ;;
                    24) netmask="255.255.255.0" ;;
                    *) netmask="255.255.255.255" ;;  # Approximation
                esac
                
                # Calculer network (approximation simple)
                IFS='.' read -ra IP_PARTS <<< "$ip"
                case $cidr in
                    8) network="${IP_PARTS[0]}.0.0.0" ;;
                    16) network="${IP_PARTS[0]}.${IP_PARTS[1]}.0.0" ;;
                    24) network="${IP_PARTS[0]}.${IP_PARTS[1]}.${IP_PARTS[2]}.0" ;;
                    *) network="$ip" ;;
                esac
                
                # Calculer broadcast (approximation simple)
                case $cidr in
                    8) broadcast="${IP_PARTS[0]}.255.255.255" ;;
                    16) broadcast="${IP_PARTS[0]}.${IP_PARTS[1]}.255.255" ;;
                    24) broadcast="${IP_PARTS[0]}.${IP_PARTS[1]}.${IP_PARTS[2]}.255" ;;
                    *) broadcast="$ip" ;;
                esac
                
                ipv4_json="$ipv4_json{\"ip\":\"$ip\",\"netmask\":\"$netmask\",\"cidr\":\"$ip/$cidr\",\"network\":\"$network\",\"broadcast\":\"$broadcast\",\"scope\":\"$scope\"},"
            fi
        done < <(ip addr show "$interface" 2>/dev/null | grep "inet ")
        
    elif command -v ifconfig >/dev/null 2>&1; then
        # Utiliser ifconfig comme fallback
        local ifconfig_output
        ifconfig_output=$(ifconfig "$interface" 2>/dev/null)
        
        if echo "$ifconfig_output" | grep -q "inet "; then
            local ip netmask broadcast
            ip=$(echo "$ifconfig_output" | grep "inet " | awk '{print $2}')
            netmask=$(echo "$ifconfig_output" | grep "inet " | grep -oE "netmask [0-9.]+" | awk '{print $2}')
            broadcast=$(echo "$ifconfig_output" | grep "inet " | grep -oE "broadcast [0-9.]+" | awk '{print $2}')
            
            if [[ -n "$ip" ]]; then
                ipv4_json="{\"ip\":\"$ip\",\"netmask\":\"${netmask:-255.255.255.255}\",\"cidr\":\"$ip/24\",\"network\":\"unknown\",\"broadcast\":\"${broadcast:-unknown}\",\"scope\":\"global\"},"
            fi
        fi
    fi
    
    echo "[${ipv4_json%,}]"
}

get_ipv6_addresses() {
    local interface="$1"
    local ipv6_json=""
    
    log_debug "Récupération adresses IPv6 pour $interface"
    
    if command -v ip >/dev/null 2>&1; then
        # Utiliser ip addr pour récupérer les IPv6
        while IFS= read -r line; do
            if [[ $line =~ inet6\ ([a-fA-F0-9:]+)/([0-9]+) ]]; then
                local ip="${BASH_REMATCH[1]}"
                local prefix="${BASH_REMATCH[2]}"
                local scope="global"
                
                # Extraire le scope si présent
                if [[ $line =~ scope\ ([a-z]+) ]]; then
                    scope="${BASH_REMATCH[1]}"
                fi
                
                ipv6_json="$ipv6_json{\"ip\":\"$ip\",\"prefix\":$prefix,\"scope\":\"$scope\"},"
            fi
        done < <(ip addr show "$interface" 2>/dev/null | grep "inet6 ")
        
    elif command -v ifconfig >/dev/null 2>&1; then
        # Utiliser ifconfig comme fallback
        local ifconfig_output
        ifconfig_output=$(ifconfig "$interface" 2>/dev/null)
        
        while IFS= read -r line; do
            if echo "$line" | grep -q "inet6 "; then
                local ip prefix scope
                ip=$(echo "$line" | awk '{print $2}')
                prefix=$(echo "$line" | grep -oE "prefixlen [0-9]+" | awk '{print $2}')
                scope="global"
                
                if echo "$line" | grep -q "scopeid"; then
                    scope="link"
                fi
                
                if [[ -n "$ip" ]]; then
                    ipv6_json="$ipv6_json{\"ip\":\"$ip\",\"prefix\":${prefix:-64},\"scope\":\"$scope\"},"
                fi
            fi
        done <<< "$ifconfig_output"
    fi
    
    echo "[${ipv6_json%,}]"
}

get_default_gateway() {
    local gateway=""
    
    if command -v ip >/dev/null 2>&1; then
        gateway=$(ip route show default 2>/dev/null | grep "default via" | awk '{print $3}' | head -1)
    elif command -v route >/dev/null 2>&1; then
        gateway=$(route -n 2>/dev/null | grep "^0.0.0.0" | awk '{print $2}' | head -1)
    fi
    
    echo "$gateway"
}

get_dns_servers() {
    local dns_servers=""
    
    # Essayer plusieurs méthodes pour récupérer les serveurs DNS
    if [[ -f /etc/resolv.conf ]]; then
        while IFS= read -r line; do
            if [[ $line =~ ^nameserver[[:space:]]+([0-9a-fA-F:.]+) ]]; then
                local dns="${BASH_REMATCH[1]}"
                dns_servers="$dns_servers\"$dns\","
            fi
        done < /etc/resolv.conf
    fi
    
    echo "[${dns_servers%,}]"
}

list_all_interfaces() {
    local interfaces=()
    
    log_debug "Récupération de toutes les interfaces"
    
    if command -v ip >/dev/null 2>&1; then
        while IFS= read -r line; do
            if [[ $line =~ ^[0-9]+:\ ([^:@]+)[@:]? ]]; then
                local iface="${BASH_REMATCH[1]}"
                
                # Filtrer loopback si demandé
                if [[ $INCLUDE_LOOPBACK -eq 0 && "$iface" == "lo" ]]; then
                    continue
                fi
                
                interfaces+=("$iface")
            fi
        done < <(ip link show 2>/dev/null)
        
    elif command -v ifconfig >/dev/null 2>&1; then
        while IFS= read -r line; do
            if [[ $line =~ ^([^[:space:]]+): ]]; then
                local iface="${BASH_REMATCH[1]}"
                
                # Filtrer loopback si demandé
                if [[ $INCLUDE_LOOPBACK -eq 0 && "$iface" == "lo" ]]; then
                    continue
                fi
                
                interfaces+=("$iface")
            fi
        done < <(ifconfig -s 2>/dev/null | tail -n +2)
    fi
    
    printf '%s\n' "${interfaces[@]}"
}

get_interface_info() {
    local interface="$1"
    
    log_debug "Collecte informations pour interface: $interface"
    
    # Vérifier si l'interface existe
    if ! interface_exists "$interface"; then
        die "Interface '$interface' n'existe pas" 3
    fi
    
    # Récupérer informations de base
    local state mac_address mtu gateway dns_servers
    state=$(get_interface_state "$interface")
    mac_address=$(get_interface_mac "$interface")
    mtu=$(get_interface_mtu "$interface")
    gateway=$(get_default_gateway)
    dns_servers=$(get_dns_servers)
    
    # Récupérer adresses IP selon les options
    local ipv4_addresses="[]"
    local ipv6_addresses="[]"
    
    if [[ $IPV6_ONLY -eq 0 ]]; then
        ipv4_addresses=$(get_ipv4_addresses "$interface")
    fi
    
    if [[ $IPV4_ONLY -eq 0 ]]; then
        ipv6_addresses=$(get_ipv6_addresses "$interface")
    fi
    
    # Vérifier si l'interface a des IPs
    local has_ips=false
    if [[ "$ipv4_addresses" != "[]" || "$ipv6_addresses" != "[]" ]]; then
        has_ips=true
    fi
    
    # Échapper pour JSON
    local interface_escaped
    interface_escaped=$(echo "$interface" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Interface information retrieved successfully",
  "data": {
    "interface": "$interface_escaped",
    "exists": true,
    "state": "${state:-UNKNOWN}",
    "mac_address": "${mac_address:-unknown}",
    "mtu": ${mtu:-0},
    "addresses": {
      "ipv4": $ipv4_addresses,
      "ipv6": $ipv6_addresses
    },
    "gateway": "${gateway:-unknown}",
    "dns_servers": $dns_servers,
    "has_addresses": $has_ips,
    "query_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": [],
  "warnings": []
}
EOF
    
    # Code de sortie selon si l'interface a des IPs
    if [[ "$has_ips" == "false" ]]; then
        exit 4  # Interface sans IP
    fi
    
    log_debug "Informations récupérées avec succès pour $interface"
}

get_all_interfaces_info() {
    log_debug "Récupération informations de toutes les interfaces"
    
    local interfaces_list interfaces_json=""
    mapfile -t interfaces_list < <(list_all_interfaces)
    
    local total_interfaces=${#interfaces_list[@]}
    local interfaces_with_ips=0
    
    # Traiter chaque interface
    for interface in "${interfaces_list[@]}"; do
        if interface_exists "$interface"; then
            # Récupérer informations de base
            local state mac_address mtu
            state=$(get_interface_state "$interface")
            mac_address=$(get_interface_mac "$interface")
            mtu=$(get_interface_mtu "$interface")
            
            # Récupérer adresses selon options
            local ipv4_addresses="[]"
            local ipv6_addresses="[]"
            
            if [[ $IPV6_ONLY -eq 0 ]]; then
                ipv4_addresses=$(get_ipv4_addresses "$interface")
            fi
            
            if [[ $IPV4_ONLY -eq 0 ]]; then
                ipv6_addresses=$(get_ipv6_addresses "$interface")
            fi
            
            # Compter si l'interface a des IPs
            if [[ "$ipv4_addresses" != "[]" || "$ipv6_addresses" != "[]" ]]; then
                ((interfaces_with_ips++))
            fi
            
            # Échapper pour JSON
            local interface_escaped
            interface_escaped=$(echo "$interface" | sed 's/\\/\\\\/g; s/"/\\"/g')
            
            interfaces_json="$interfaces_json{\"interface\":\"$interface_escaped\",\"state\":\"${state:-UNKNOWN}\",\"mac_address\":\"${mac_address:-unknown}\",\"mtu\":${mtu:-0},\"addresses\":{\"ipv4\":$ipv4_addresses,\"ipv6\":$ipv6_addresses}},"
        fi
    done
    
    # Récupérer infos réseau globales
    local gateway dns_servers
    gateway=$(get_default_gateway)
    dns_servers=$(get_dns_servers)
    
    # Retirer virgule finale
    interfaces_json="[${interfaces_json%,}]"
    
    # Réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "All interfaces information retrieved successfully",
  "data": {
    "interfaces": $interfaces_json,
    "summary": {
      "total_interfaces": $total_interfaces,
      "interfaces_with_addresses": $interfaces_with_ips,
      "interfaces_without_addresses": $((total_interfaces - interfaces_with_ips))
    },
    "global_network": {
      "gateway": "${gateway:-unknown}",
      "dns_servers": $dns_servers
    },
    "query_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_debug "Informations récupérées pour $total_interfaces interface(s)"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    
    if [[ $ALL_INTERFACES -eq 1 ]]; then
        get_all_interfaces_info
    else
        get_interface_info "$INTERFACE_NAME"
    fi
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi