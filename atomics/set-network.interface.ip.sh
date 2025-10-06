#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: set-network.interface.ip.sh
# Description: Configurer l'adresse IP d'une interface réseau
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-06
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="set-network.interface.ip.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
INTERFACE=""
IP_ADDRESS=""
NETMASK=""
GATEWAY=""
PERSISTENT=${PERSISTENT:-0}
METHOD="static"

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
Usage: $SCRIPT_NAME [OPTIONS] <interface> <ip_address> [netmask] [gateway]

Description:
    Configure l'adresse IP d'une interface réseau avec support pour 
    configuration temporaire ou persistante selon la distribution.

Arguments:
    <interface>             Nom de l'interface (ex: eth0, enp0s3, wlan0)
    <ip_address>            Adresse IP à assigner (ex: 192.168.1.100)
    [netmask]              Masque réseau (ex: 255.255.255.0 ou /24)
    [gateway]              Passerelle par défaut (optionnel)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -p, --persistent       Rendre la configuration persistante
    -m, --method METHOD    Méthode de configuration (static|dhcp)
    
Formats de masque acceptés:
    255.255.255.0          Notation décimale classique
    /24                    Notation CIDR
    24                     Préfixe réseau seulement
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "interface": "eth0",
        "ip_address": "192.168.1.100",
        "netmask": "255.255.255.0",
        "cidr_notation": "/24",
        "gateway": "192.168.1.1",
        "method": "static",
        "persistent": true,
        "previous_config": {
          "ip": "192.168.1.50",
          "netmask": "/24"
        },
        "network_manager": "systemd-networkd"
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0  - Succès
    1  - Erreur générale
    2  - Paramètres invalides
    3  - Interface non trouvée
    4  - Permissions insuffisantes
    5  - Adresse IP invalide

Exemples:
    $SCRIPT_NAME eth0 192.168.1.100 /24
    $SCRIPT_NAME -p enp0s3 10.0.0.50 255.255.255.0 10.0.0.1
    $SCRIPT_NAME --method dhcp eth0

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
            -m|--method)
                if [[ -n "${2:-}" ]]; then
                    METHOD="$2"
                    shift 2
                else
                    die "Méthode manquante pour -m/--method" 2
                fi
                ;;
            -*)
                die "Option inconnue: $1" 2
                ;;
            *)
                if [[ -z "$INTERFACE" ]]; then
                    INTERFACE="$1"
                elif [[ -z "$IP_ADDRESS" ]]; then
                    IP_ADDRESS="$1"
                elif [[ -z "$NETMASK" ]]; then
                    NETMASK="$1"
                elif [[ -z "$GATEWAY" ]]; then
                    GATEWAY="$1"
                else
                    die "Trop d'arguments positionnels" 2
                fi
                shift
                ;;
        esac
    done
    
    # Validation des arguments
    if [[ -z "$INTERFACE" ]]; then
        die "Nom de l'interface manquant" 2
    fi
    
    if [[ "$METHOD" == "static" ]] && [[ -z "$IP_ADDRESS" ]]; then
        die "Adresse IP manquante pour la méthode static" 2
    fi
    
    if [[ "$METHOD" != "static" ]] && [[ "$METHOD" != "dhcp" ]]; then
        die "Méthode invalide: $METHOD (utilisez 'static' ou 'dhcp')" 2
    fi
    
    # Valeurs par défaut pour le netmask
    if [[ "$METHOD" == "static" ]] && [[ -z "$NETMASK" ]]; then
        NETMASK="/24"
        log_debug "Utilisation du masque par défaut: $NETMASK"
    fi
}

# =============================================================================
# Fonctions de Validation et Vérification
# =============================================================================

check_dependencies() {
    local missing_deps=()
    
    if ! command -v ip >/dev/null 2>&1; then
        missing_deps+=("ip (iproute2)")
    fi
    
    # Vérifier la présence d'outils de configuration réseau
    local has_networkctl=0
    local has_nmcli=0
    
    if command -v networkctl >/dev/null 2>&1; then
        has_networkctl=1
    fi
    
    if command -v nmcli >/dev/null 2>&1; then
        has_nmcli=1
    fi
    
    if [[ $PERSISTENT -eq 1 ]] && [[ $has_networkctl -eq 0 ]] && [[ $has_nmcli -eq 0 ]]; then
        log_warn "Aucun gestionnaire de réseau détecté pour la configuration persistante"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        die "Dépendances manquantes: ${missing_deps[*]}" 1
    fi
}

validate_ip_address() {
    local ip="$1"
    
    # Validation IP v4
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        local IFS='.'
        local octets=($ip)
        for octet in "${octets[@]}"; do
            if [[ $octet -lt 0 ]] || [[ $octet -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    
    return 1
}

normalize_netmask() {
    local mask="$1"
    
    # Si c'est déjà au format CIDR avec /
    if [[ "$mask" =~ ^/[0-9]+$ ]]; then
        echo "$mask"
        return 0
    fi
    
    # Si c'est juste le nombre
    if [[ "$mask" =~ ^[0-9]+$ ]]; then
        echo "/$mask"
        return 0
    fi
    
    # Si c'est au format décimal (255.255.255.0)
    if [[ "$mask" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # Conversion décimal vers CIDR
        local decimal_mask="$mask"
        local cidr=0
        
        # Conversion simple pour les masques courants
        case "$decimal_mask" in
            "255.255.255.255") cidr=32 ;;
            "255.255.255.254") cidr=31 ;;
            "255.255.255.252") cidr=30 ;;
            "255.255.255.248") cidr=29 ;;
            "255.255.255.240") cidr=28 ;;
            "255.255.255.224") cidr=27 ;;
            "255.255.255.192") cidr=26 ;;
            "255.255.255.128") cidr=25 ;;
            "255.255.255.0")   cidr=24 ;;
            "255.255.254.0")   cidr=23 ;;
            "255.255.252.0")   cidr=22 ;;
            "255.255.248.0")   cidr=21 ;;
            "255.255.240.0")   cidr=20 ;;
            "255.255.224.0")   cidr=19 ;;
            "255.255.192.0")   cidr=18 ;;
            "255.255.128.0")   cidr=17 ;;
            "255.255.0.0")     cidr=16 ;;
            "255.254.0.0")     cidr=15 ;;
            "255.252.0.0")     cidr=14 ;;
            "255.248.0.0")     cidr=13 ;;
            "255.240.0.0")     cidr=12 ;;
            "255.224.0.0")     cidr=11 ;;
            "255.192.0.0")     cidr=10 ;;
            "255.128.0.0")     cidr=9 ;;
            "255.0.0.0")       cidr=8 ;;
            *) return 1 ;;  # Masque non reconnu
        esac
        
        echo "/$cidr"
        return 0
    fi
    
    return 1
}

check_interface_exists() {
    local interface="$1"
    
    if ip link show "$interface" >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

get_current_ip_config() {
    local interface="$1"
    local current_ip current_cidr
    
    # Obtenir la configuration IP actuelle
    local ip_info
    ip_info=$(ip addr show "$interface" | grep "inet " | head -1 | awk '{print $2}' 2>/dev/null || echo "")
    
    if [[ -n "$ip_info" ]]; then
        if [[ "$ip_info" =~ ^([0-9.]+)/([0-9]+)$ ]]; then
            current_ip="${BASH_REMATCH[1]}"
            current_cidr="/${BASH_REMATCH[2]}"
        fi
    fi
    
    echo "${current_ip:-none}|${current_cidr:-none}"
}

detect_network_manager() {
    # Détecter le gestionnaire de réseau utilisé
    if systemctl is-active networkd >/dev/null 2>&1; then
        echo "systemd-networkd"
    elif systemctl is-active NetworkManager >/dev/null 2>&1; then
        echo "NetworkManager"
    elif [[ -d /etc/network/interfaces.d ]] || [[ -f /etc/network/interfaces ]]; then
        echo "ifupdown"
    else
        echo "unknown"
    fi
}

# =============================================================================
# Fonction Principale de Configuration IP
# =============================================================================

set_network_interface_ip() {
    local interface="$1"
    local ip_addr="$2"
    local netmask="$3"
    local gateway="$4"
    local errors=()
    local warnings=()
    
    log_debug "Configuration IP pour interface: $interface"
    log_debug "IP: $ip_addr, Masque: $netmask, Gateway: $gateway"
    
    # Vérifier que l'interface existe
    if ! check_interface_exists "$interface"; then
        errors+=("Interface not found: $interface")
        handle_result "$interface" "$ip_addr" "$netmask" "$gateway" "${errors[@]}" "${warnings[@]}"
        return 3
    fi
    
    # Obtenir la configuration actuelle
    local current_config previous_ip previous_cidr
    current_config=$(get_current_ip_config "$interface")
    IFS='|' read -r previous_ip previous_cidr <<< "$current_config"
    
    if [[ "$METHOD" == "dhcp" ]]; then
        log_info "Configuration DHCP pour l'interface $interface"
        
        # Activer DHCP sur l'interface
        if command -v dhclient >/dev/null 2>&1; then
            if dhclient "$interface" 2>/dev/null; then
                log_info "DHCP activé avec succès"
            else
                errors+=("Failed to enable DHCP on interface")
            fi
        else
            # Fallback avec ip et dhcpcd si disponible
            if command -v dhcpcd >/dev/null 2>&1; then
                if dhcpcd "$interface" 2>/dev/null; then
                    log_info "DHCP activé avec dhcpcd"
                else
                    errors+=("Failed to enable DHCP with dhcpcd")
                fi
            else
                errors+=("No DHCP client available (dhclient or dhcpcd required)")
            fi
        fi
    else
        # Configuration statique
        if [[ "$METHOD" == "static" ]]; then
            # Valider l'adresse IP
            if ! validate_ip_address "$ip_addr"; then
                errors+=("Invalid IP address: $ip_addr")
            fi
            
            # Normaliser le masque réseau
            local normalized_netmask
            if ! normalized_netmask=$(normalize_netmask "$netmask"); then
                errors+=("Invalid netmask format: $netmask")
            fi
            
            if [[ ${#errors[@]} -eq 0 ]]; then
                log_info "Configuration IP statique: $ip_addr$normalized_netmask"
                
                # Supprimer l'ancienne configuration
                if [[ "$previous_ip" != "none" ]]; then
                    ip addr del "$previous_ip$previous_cidr" dev "$interface" 2>/dev/null || true
                fi
                
                # Ajouter la nouvelle adresse IP
                if ip addr add "$ip_addr$normalized_netmask" dev "$interface" 2>/dev/null; then
                    log_info "Adresse IP configurée avec succès"
                    
                    # Configurer la passerelle si fournie
                    if [[ -n "$gateway" ]]; then
                        if validate_ip_address "$gateway"; then
                            # Supprimer l'ancienne route par défaut
                            ip route del default 2>/dev/null || true
                            
                            # Ajouter la nouvelle route
                            if ip route add default via "$gateway" dev "$interface" 2>/dev/null; then
                                log_info "Passerelle configurée: $gateway"
                            else
                                warnings+=("Failed to set gateway: $gateway")
                            fi
                        else
                            warnings+=("Invalid gateway address: $gateway")
                        fi
                    fi
                    
                    # Activer l'interface si elle est down
                    ip link set "$interface" up 2>/dev/null || true
                else
                    errors+=("Failed to set IP address on interface")
                fi
            fi
        fi
    fi
    
    # Configuration persistante si demandée
    if [[ $PERSISTENT -eq 1 ]] && [[ ${#errors[@]} -eq 0 ]]; then
        local network_manager
        network_manager=$(detect_network_manager)
        
        case "$network_manager" in
            "NetworkManager")
                configure_persistent_networkmanager "$interface" "$ip_addr" "$normalized_netmask" "$gateway"
                ;;
            "systemd-networkd")
                configure_persistent_networkd "$interface" "$ip_addr" "$normalized_netmask" "$gateway"
                ;;
            *)
                warnings+=("Persistent configuration not implemented for detected network manager: $network_manager")
                ;;
        esac
    fi
    
    handle_result "$interface" "$ip_addr" "$netmask" "$gateway" "${errors[@]}" "${warnings[@]}" "$previous_ip" "$previous_cidr"
    
    [[ ${#errors[@]} -eq 0 ]] && return 0 || return 1
}

configure_persistent_networkmanager() {
    local interface="$1" ip_addr="$2" netmask="$3" gateway="$4"
    
    log_debug "Configuration persistante via NetworkManager"
    
    # Créer une connexion NetworkManager
    local conn_name="static-$interface"
    
    # Supprimer l'ancienne connexion si elle existe
    nmcli connection delete "$conn_name" 2>/dev/null || true
    
    # Créer la nouvelle connexion
    local nmcli_cmd="nmcli connection add type ethernet con-name $conn_name ifname $interface"
    
    if [[ "$METHOD" == "dhcp" ]]; then
        nmcli_cmd+=" ipv4.method auto"
    else
        nmcli_cmd+=" ipv4.method manual ipv4.addresses $ip_addr$netmask"
        if [[ -n "$gateway" ]]; then
            nmcli_cmd+=" ipv4.gateway $gateway"
        fi
    fi
    
    if eval "$nmcli_cmd" 2>/dev/null; then
        # Activer la connexion
        nmcli connection up "$conn_name" 2>/dev/null || true
        log_info "Configuration persistante NetworkManager créée"
    else
        log_warn "Échec de la configuration persistante NetworkManager"
    fi
}

configure_persistent_networkd() {
    local interface="$1" ip_addr="$2" netmask="$3" gateway="$4"
    
    log_debug "Configuration persistante via systemd-networkd"
    
    local config_file="/etc/systemd/network/50-$interface.network"
    
    cat > "$config_file" << EOF
[Match]
Name=$interface

[Network]
EOF
    
    if [[ "$METHOD" == "dhcp" ]]; then
        echo "DHCP=yes" >> "$config_file"
    else
        echo "DHCP=no" >> "$config_file"
        echo "Address=$ip_addr$netmask" >> "$config_file"
        if [[ -n "$gateway" ]]; then
            echo "Gateway=$gateway" >> "$config_file"
        fi
    fi
    
    # Redémarrer networkd
    if systemctl restart systemd-networkd 2>/dev/null; then
        log_info "Configuration persistante systemd-networkd créée"
    else
        log_warn "Échec du redémarrage de systemd-networkd"
    fi
}

handle_result() {
    local interface="$1" ip_addr="$2" netmask="$3" gateway="$4"
    local previous_ip="$5" previous_cidr="$6"
    shift 6
    local errors=("$@")
    local warnings=()
    
    # Séparer erreurs et warnings
    local actual_errors=()
    for item in "${errors[@]}"; do
        if [[ "$item" =~ ^WARNING: ]]; then
            warnings+=("${item#WARNING: }")
        else
            actual_errors+=("$item")
        fi
    done
    
    # Obtenir la configuration actuelle après modification
    local current_config current_ip current_cidr
    current_config=$(get_current_ip_config "$interface")
    IFS='|' read -r current_ip current_cidr <<< "$current_config"
    
    # Détecter le gestionnaire de réseau
    local network_manager
    network_manager=$(detect_network_manager)
    
    # Normaliser le masque pour le JSON
    local normalized_netmask
    if [[ "$METHOD" == "static" ]]; then
        normalized_netmask=$(normalize_netmask "$netmask" 2>/dev/null || echo "$netmask")
    else
        normalized_netmask=""
    fi
    
    # Échapper pour JSON
    local interface_escaped ip_escaped gateway_escaped
    interface_escaped=$(echo "$interface" | sed 's/\\/\\\\/g; s/"/\\"/g')
    ip_escaped=$(echo "$ip_addr" | sed 's/\\/\\\\/g; s/"/\\"/g')
    gateway_escaped=$(echo "${gateway:-}" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Construire les tableaux JSON
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
    local message="Network interface IP configured successfully"
    
    if [[ ${#actual_errors[@]} -gt 0 ]]; then
        status="error"
        code=1
        message="Failed to configure network interface IP"
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
    "interface": "$interface_escaped",
    "ip_address": "$ip_escaped",
    "netmask": "$netmask",
    "cidr_notation": "$normalized_netmask",
    "gateway": "$gateway_escaped",
    "method": "$METHOD",
    "persistent": $([ $PERSISTENT -eq 1 ] && echo "true" || echo "false"),
    "previous_config": {
      "ip": "$previous_ip",
      "netmask": "$previous_cidr"
    },
    "current_config": {
      "ip": "$current_ip", 
      "netmask": "$current_cidr"
    },
    "network_manager": "$network_manager"
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
    set_network_interface_ip "$INTERFACE" "$IP_ADDRESS" "$NETMASK" "$GATEWAY"
    
    log_info "Script completed"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi