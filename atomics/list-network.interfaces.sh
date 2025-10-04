#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: list-network.interfaces.sh
# Description: Liste toutes les interfaces réseau avec leurs configurations et états
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-01-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="list-network.interfaces.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
ACTIVE_ONLY=${ACTIVE_ONLY:-0}
INCLUDE_LOOPBACK=${INCLUDE_LOOPBACK:-1}

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
Usage: $SCRIPT_NAME [OPTIONS]

Description:
    Liste toutes les interfaces réseau du système avec leurs configurations,
    états, adresses IP et statistiques de trafic.

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -a, --active-only      Afficher seulement les interfaces actives
    -n, --no-loopback      Exclure l'interface loopback (lo)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "interfaces": [
          {
            "name": "eth0",
            "type": "ethernet",
            "state": "UP",
            "mtu": 1500,
            "mac_address": "00:11:22:33:44:55",
            "ipv4": {
              "addresses": ["192.168.1.100/24"],
              "gateway": "192.168.1.1"
            },
            "ipv6": {
              "addresses": ["fe80::211:22ff:fe33:4455/64"]
            },
            "stats": {
              "rx_bytes": 1048576,
              "tx_bytes": 524288,
              "rx_packets": 1024,
              "tx_packets": 512
            }
          }
        ],
        "count": 1,
        "filter": "all|active_only"
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Commande non disponible
    4 - Erreur de parsing

Exemples:
    $SCRIPT_NAME                           # Toutes les interfaces
    $SCRIPT_NAME --json-only               # Sortie JSON uniquement
    $SCRIPT_NAME --active-only             # Seulement les actives
    $SCRIPT_NAME --no-loopback             # Sans loopback
    $SCRIPT_NAME --debug                   # Mode debug
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
            -a|--active-only)
                ACTIVE_ONLY=1
                shift
                ;;
            -n|--no-loopback)
                INCLUDE_LOOPBACK=0
                shift
                ;;
            *)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
        esac
    done
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    if ! command -v ip >/dev/null 2>&1; then
        missing+=("ip")
    fi
    
    if ! [[ -d /sys/class/net ]]; then
        missing+=("/sys/class/net")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Dépendances manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Toutes les dépendances sont disponibles"
}

get_interface_type() {
    local interface="$1"
    local type_file="/sys/class/net/$interface/type"
    
    if [[ -r "$type_file" ]]; then
        local type_num
        type_num=$(cat "$type_file" 2>/dev/null || echo "1")
        
        case "$type_num" in
            1) echo "ethernet" ;;
            24) echo "ethernet" ;;  # Ethernet over firewire
            32) echo "infiniband" ;;
            512) echo "ppp" ;;
            768) echo "ipip" ;;
            769) echo "ip6ip6" ;;
            772) echo "loopback" ;;
            776) echo "sit" ;;
            778) echo "gre" ;;
            783) echo "irda" ;;
            801) echo "wireless" ;;
            *) echo "other" ;;
        esac
    else
        # Détection basée sur le nom pour les interfaces virtuelles
        case "$interface" in
            lo) echo "loopback" ;;
            eth*) echo "ethernet" ;;
            wlan*|wl*) echo "wireless" ;;
            br*) echo "bridge" ;;
            docker*) echo "docker" ;;
            veth*) echo "virtual" ;;
            tun*|tap*) echo "tunnel" ;;
            *) echo "unknown" ;;
        esac
    fi
}

get_interface_mtu() {
    local interface="$1"
    local mtu_file="/sys/class/net/$interface/mtu"
    
    if [[ -r "$mtu_file" ]]; then
        cat "$mtu_file" 2>/dev/null || echo "1500"
    else
        echo "1500"
    fi
}

get_interface_mac() {
    local interface="$1"
    local address_file="/sys/class/net/$interface/address"
    
    if [[ -r "$address_file" ]]; then
        cat "$address_file" 2>/dev/null || echo "00:00:00:00:00:00"
    else
        echo "00:00:00:00:00:00"
    fi
}

get_interface_stats() {
    local interface="$1"
    local stats_dir="/sys/class/net/$interface/statistics"
    
    local rx_bytes tx_bytes rx_packets tx_packets
    
    if [[ -d "$stats_dir" ]]; then
        rx_bytes=$(cat "$stats_dir/rx_bytes" 2>/dev/null || echo "0")
        tx_bytes=$(cat "$stats_dir/tx_bytes" 2>/dev/null || echo "0")
        rx_packets=$(cat "$stats_dir/rx_packets" 2>/dev/null || echo "0")
        tx_packets=$(cat "$stats_dir/tx_packets" 2>/dev/null || echo "0")
    else
        rx_bytes="0"
        tx_bytes="0"
        rx_packets="0"
        tx_packets="0"
    fi
    
    echo "$rx_bytes $tx_bytes $rx_packets $tx_packets"
}

get_interface_ips() {
    local interface="$1"
    local ipv4_addrs=()
    local ipv6_addrs=()
    
    # Utiliser ip addr pour obtenir les adresses
    local addr_info
    if addr_info=$(ip addr show "$interface" 2>/dev/null); then
        # IPv4 addresses
        while IFS= read -r line; do
            [[ -n "$line" ]] && ipv4_addrs+=("$line")
        done < <(echo "$addr_info" | awk '/inet / && !/inet 127/ {print $2}' 2>/dev/null || true)
        
        # IPv6 addresses
        while IFS= read -r line; do
            [[ -n "$line" ]] && ipv6_addrs+=("$line")
        done < <(echo "$addr_info" | awk '/inet6/ {print $2}' 2>/dev/null || true)
    fi
    
    # Construire le JSON pour les IPs
    local ipv4_json ipv6_json
    
    if [[ ${#ipv4_addrs[@]} -gt 0 ]]; then
        ipv4_json="\"$(IFS='", "'; echo "${ipv4_addrs[*]}")\""
        ipv4_json="[$ipv4_json]"
    else
        ipv4_json="[]"
    fi
    
    if [[ ${#ipv6_addrs[@]} -gt 0 ]]; then
        ipv6_json="\"$(IFS='", "'; echo "${ipv6_addrs[*]}")\""
        ipv6_json="[$ipv6_json]"
    else
        ipv6_json="[]"
    fi
    
    echo "$ipv4_json|$ipv6_json"
}

get_default_gateway() {
    local gateway
    gateway=$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}' || echo "")
    echo "${gateway:-\"\"}"
}

list_network_interfaces() {
    log_debug "Récupération des interfaces réseau"
    
    local interfaces=()
    local default_gateway
    default_gateway=$(get_default_gateway)
    
    log_debug "Passerelle par défaut: $default_gateway"
    
    # Obtenir la liste des interfaces
    for interface_path in /sys/class/net/*; do
        [[ ! -d "$interface_path" ]] && continue
        
        local interface
        interface=$(basename "$interface_path")
        
        log_debug "Traitement de l'interface: $interface"
        
        # Filtrer loopback si demandé
        if [[ $INCLUDE_LOOPBACK -eq 0 && "$interface" == "lo" ]]; then
            log_debug "Filtrage de l'interface loopback: $interface"
            continue
        fi
        
        # Obtenir l'état de l'interface
        local state
        if command -v ip >/dev/null 2>&1; then
            state=$(ip link show "$interface" 2>/dev/null | awk -F'[<>]' '/state/ {for(i=1;i<=NF;i++) if($i~/UP|DOWN/) print $i; exit}' || echo "UNKNOWN")
        else
            state="UNKNOWN"
        fi
        
        # Filtrer les interfaces inactives si demandé
        if [[ $ACTIVE_ONLY -eq 1 && "$state" != "UP" ]]; then
            log_debug "Filtrage de l'interface inactive: $interface (état: $state)"
            continue
        fi
        
        # Obtenir les informations de l'interface
        local interface_type mtu mac_address
        interface_type=$(get_interface_type "$interface")
        mtu=$(get_interface_mtu "$interface")
        mac_address=$(get_interface_mac "$interface")
        
        # Obtenir les statistiques
        local stats_raw rx_bytes tx_bytes rx_packets tx_packets
        stats_raw=$(get_interface_stats "$interface")
        read -r rx_bytes tx_bytes rx_packets tx_packets <<< "$stats_raw"
        
        # Obtenir les adresses IP
        local ip_info ipv4_addrs ipv6_addrs
        ip_info=$(get_interface_ips "$interface")
        ipv4_addrs="${ip_info%|*}"
        ipv6_addrs="${ip_info#*|}"
        
        # Échapper les caractères spéciaux pour JSON
        local interface_escaped mac_escaped
        interface_escaped=$(echo "$interface" | sed 's/\\/\\\\/g; s/"/\\"/g')
        mac_escaped=$(echo "$mac_address" | sed 's/\\/\\\\/g; s/"/\\"/g')
        
        # Construire l'objet interface JSON
        local interface_json
        interface_json=$(cat << EOF
{
  "name": "$interface_escaped",
  "type": "$interface_type",
  "state": "$state",
  "mtu": $mtu,
  "mac_address": "$mac_escaped",
  "ipv4": {
    "addresses": $ipv4_addrs,
    "gateway": "$default_gateway"
  },
  "ipv6": {
    "addresses": $ipv6_addrs
  },
  "stats": {
    "rx_bytes": $rx_bytes,
    "tx_bytes": $tx_bytes,
    "rx_packets": $rx_packets,
    "tx_packets": $tx_packets
  }
}
EOF
        )
        
        interfaces+=("$interface_json")
        
        log_debug "Interface $interface traitée: type=$interface_type, état=$state, MTU=$mtu"
    done
    
    # Construire la réponse JSON
    local interfaces_json filter_mode
    if [[ ${#interfaces[@]} -gt 0 ]]; then
        # Joindre les éléments avec des virgules
        interfaces_json=$(IFS=','; echo "${interfaces[*]}")
    else
        interfaces_json=""
    fi
    
    # Déterminer le mode de filtrage
    if [[ $ACTIVE_ONLY -eq 1 ]]; then
        filter_mode="active_only"
    else
        filter_mode="all"
    fi
    
    # Réponse JSON finale
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Network interfaces list retrieved successfully",
  "data": {
    "interfaces": [
      $interfaces_json
    ],
    "count": ${#interfaces[@]},
    "default_gateway": "$default_gateway",
    "filter": "$filter_mode",
    "include_loopback": $([ $INCLUDE_LOOPBACK -eq 1 ] && echo "true" || echo "false"),
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_debug "Informations des interfaces réseau récupérées avec succès: ${#interfaces[@]} interfaces"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    list_network_interfaces
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi