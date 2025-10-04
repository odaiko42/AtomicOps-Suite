#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: check-network.connectivity.sh
# Description: Vérifie la connectivité réseau complète (ping, DNS, HTTP)
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-01-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="check-network.connectivity.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
TIMEOUT=${TIMEOUT:-5}
COMPREHENSIVE=${COMPREHENSIVE:-0}

# Destinations de test par défaut
DEFAULT_PING_HOST="8.8.8.8"
DEFAULT_DNS_HOST="google.com"
DEFAULT_HTTP_URL="http://www.google.com"
DEFAULT_HTTPS_URL="https://www.google.com"

# Destinations personnalisées
PING_HOST=""
DNS_HOST=""
HTTP_URL=""
HTTPS_URL=""

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
    Vérifie la connectivité réseau complète avec tests multiples :
    - Test ICMP (ping) vers serveur distant
    - Résolution DNS (nslookup/dig)
    - Connectivité HTTP (wget/curl)
    - Connectivité HTTPS (wget/curl)
    - Interface réseau locale

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -t, --timeout <sec>    Timeout pour tests réseau (défaut: 5s)
    -c, --comprehensive    Tests complets avec multiples destinations
    --ping-host <host>     Host pour test ping (défaut: 8.8.8.8)
    --dns-host <host>      Host pour test DNS (défaut: google.com)
    --http-url <url>       URL pour test HTTP (défaut: http://www.google.com)
    --https-url <url>      URL pour test HTTPS (défaut: https://www.google.com)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "connectivity": {
          "overall_status": "online|partial|offline",
          "ping": {"success": true, "target": "8.8.8.8", "time_ms": 15},
          "dns": {"success": true, "target": "google.com", "resolved_ips": []},
          "http": {"success": true, "url": "...", "status_code": 200},
          "https": {"success": true, "url": "...", "status_code": 200}
        },
        "interfaces": [{"name": "eth0", "ip": "192.168.1.100", "status": "up"}],
        "gateway": {"ip": "192.168.1.1", "reachable": true},
        "tests_summary": {"total": 5, "passed": 4, "failed": 1}
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Connectivité complète
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Connectivité partielle
    4 - Pas de connectivité

Exemples:
    $SCRIPT_NAME                              # Test connectivité basique
    $SCRIPT_NAME --comprehensive              # Tests complets
    $SCRIPT_NAME --timeout 10                # Timeout personnalisé
    $SCRIPT_NAME --ping-host 1.1.1.1         # Host ping personnalisé
    $SCRIPT_NAME --json-only                 # Sortie JSON seulement
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
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -c|--comprehensive)
                COMPREHENSIVE=1
                shift
                ;;
            --ping-host)
                PING_HOST="$2"
                shift 2
                ;;
            --dns-host)
                DNS_HOST="$2"
                shift 2
                ;;
            --http-url)
                HTTP_URL="$2"
                shift 2
                ;;
            --https-url)
                HTTPS_URL="$2"
                shift 2
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                die "Argument inattendu: $1. Utilisez -h pour l'aide." 2
                ;;
        esac
    done

    # Utiliser les valeurs par défaut si non spécifiées
    PING_HOST=${PING_HOST:-$DEFAULT_PING_HOST}
    DNS_HOST=${DNS_HOST:-$DEFAULT_DNS_HOST}
    HTTP_URL=${HTTP_URL:-$DEFAULT_HTTP_URL}
    HTTPS_URL=${HTTPS_URL:-$DEFAULT_HTTPS_URL}

    # Validation timeout
    if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [[ $TIMEOUT -lt 1 ]]; then
        die "Timeout doit être un entier positif: $TIMEOUT" 2
    fi
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    if ! command -v ping >/dev/null 2>&1; then
        missing+=("ping")
    fi
    
    # Vérifier outils DNS (nslookup ou dig)
    if ! command -v nslookup >/dev/null 2>&1 && ! command -v dig >/dev/null 2>&1; then
        missing+=("nslookup ou dig")
    fi
    
    # Vérifier outils HTTP (wget ou curl)
    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        missing+=("wget ou curl")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Toutes les dépendances sont disponibles"
}

test_ping_connectivity() {
    local host="$1"
    local success=false
    local ping_time=0
    local error_msg=""
    
    log_debug "Test ping vers: $host"
    
    if command -v ping >/dev/null 2>&1; then
        local ping_output
        if ping_output=$(ping -c 1 -W "$TIMEOUT" "$host" 2>&1); then
            success=true
            # Extraire le temps de ping (compatible Linux et macOS)
            if echo "$ping_output" | grep -q "time="; then
                ping_time=$(echo "$ping_output" | grep -oE "time=[0-9.]+" | head -1 | cut -d= -f2 | cut -d. -f1)
            fi
            log_debug "Ping réussi: ${ping_time}ms"
        else
            error_msg="Ping failed: $ping_output"
            log_debug "Ping échoué: $error_msg"
        fi
    else
        error_msg="Ping command not available"
    fi
    
    echo "$success|$ping_time|$error_msg"
}

test_dns_resolution() {
    local host="$1"
    local success=false
    local resolved_ips=""
    local error_msg=""
    
    log_debug "Test résolution DNS pour: $host"
    
    # Essayer avec nslookup d'abord
    if command -v nslookup >/dev/null 2>&1; then
        local nslookup_output
        if nslookup_output=$(timeout "$TIMEOUT" nslookup "$host" 2>&1); then
            if echo "$nslookup_output" | grep -q "Address:"; then
                resolved_ips=$(echo "$nslookup_output" | grep "Address:" | tail -n +2 | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
                success=true
                log_debug "DNS résolu: $resolved_ips"
            fi
        else
            error_msg="nslookup failed: $nslookup_output"
        fi
    # Essayer avec dig si nslookup échoue
    elif command -v dig >/dev/null 2>&1; then
        local dig_output
        if dig_output=$(timeout "$TIMEOUT" dig +short "$host" 2>&1); then
            if [[ -n "$dig_output" ]]; then
                resolved_ips=$(echo "$dig_output" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | tr '\n' ',' | sed 's/,$//')
                success=true
                log_debug "DNS résolu avec dig: $resolved_ips"
            fi
        else
            error_msg="dig failed: $dig_output"
        fi
    else
        error_msg="No DNS resolution tool available"
    fi
    
    echo "$success|$resolved_ips|$error_msg"
}

test_http_connectivity() {
    local url="$1"
    local success=false
    local status_code=0
    local error_msg=""
    
    log_debug "Test HTTP vers: $url"
    
    # Essayer avec curl d'abord
    if command -v curl >/dev/null 2>&1; then
        local curl_output
        if curl_output=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" "$url" 2>&1); then
            if [[ "$curl_output" =~ ^[0-9]+$ ]]; then
                status_code="$curl_output"
                if [[ $status_code -ge 200 && $status_code -lt 400 ]]; then
                    success=true
                    log_debug "HTTP réussi: $status_code"
                else
                    error_msg="HTTP error code: $status_code"
                fi
            else
                error_msg="Curl failed: $curl_output"
            fi
        else
            error_msg="Curl connection failed"
        fi
    # Essayer avec wget si curl échoue
    elif command -v wget >/dev/null 2>&1; then
        local wget_output
        if wget_output=$(wget --timeout="$TIMEOUT" --tries=1 --spider "$url" 2>&1); then
            if echo "$wget_output" | grep -q "200 OK"; then
                success=true
                status_code=200
                log_debug "HTTP réussi avec wget: $status_code"
            elif echo "$wget_output" | grep -qE "[0-9]{3}"; then
                status_code=$(echo "$wget_output" | grep -oE "[0-9]{3}" | head -1)
                error_msg="HTTP error code: $status_code"
            fi
        else
            error_msg="Wget failed: $wget_output"
        fi
    else
        error_msg="No HTTP client available"
    fi
    
    echo "$success|$status_code|$error_msg"
}

get_network_interfaces() {
    local interfaces=""
    
    log_debug "Récupération des interfaces réseau"
    
    if command -v ip >/dev/null 2>&1; then
        # Utiliser ip pour récupérer les interfaces
        while IFS= read -r line; do
            if [[ $line =~ ^[0-9]+:\ ([^:]+): ]]; then
                local iface="${BASH_REMATCH[1]}"
                if [[ $iface != "lo" ]]; then  # Ignorer loopback
                    local ip_addr state
                    ip_addr=$(ip addr show "$iface" 2>/dev/null | grep -oE "inet [0-9.]+/[0-9]+" | head -1 | awk '{print $2}' | cut -d/ -f1)
                    state=$(ip link show "$iface" 2>/dev/null | grep -oE "state [A-Z]+" | awk '{print $2}')
                    
                    if [[ -n "$ip_addr" ]]; then
                        interfaces="$interfaces{\"name\":\"$iface\",\"ip\":\"$ip_addr\",\"state\":\"${state:-unknown}\"},"
                    fi
                fi
            fi
        done < <(ip link show 2>/dev/null)
    elif command -v ifconfig >/dev/null 2>&1; then
        # Utiliser ifconfig comme fallback
        while IFS= read -r line; do
            if [[ $line =~ ^([^[:space:]]+): ]]; then
                local iface="${BASH_REMATCH[1]}"
                if [[ $iface != "lo" ]]; then
                    local ip_addr
                    ip_addr=$(ifconfig "$iface" 2>/dev/null | grep -oE "inet [0-9.]+" | awk '{print $2}')
                    if [[ -n "$ip_addr" ]]; then
                        interfaces="$interfaces{\"name\":\"$iface\",\"ip\":\"$ip_addr\",\"state\":\"up\"},"
                    fi
                fi
            fi
        done < <(ifconfig -s 2>/dev/null | tail -n +2)
    fi
    
    # Retirer la virgule finale
    interfaces="${interfaces%,}"
    echo "[$interfaces]"
}

get_default_gateway() {
    local gateway_ip=""
    local reachable=false
    
    log_debug "Récupération de la passerelle par défaut"
    
    if command -v ip >/dev/null 2>&1; then
        gateway_ip=$(ip route show default 2>/dev/null | grep "default via" | awk '{print $3}' | head -1)
    elif command -v route >/dev/null 2>&1; then
        gateway_ip=$(route -n 2>/dev/null | grep "^0.0.0.0" | awk '{print $2}' | head -1)
    fi
    
    if [[ -n "$gateway_ip" ]]; then
        # Tester l'accessibilité de la passerelle
        if ping -c 1 -W "$TIMEOUT" "$gateway_ip" >/dev/null 2>&1; then
            reachable=true
        fi
    fi
    
    echo "$gateway_ip|$reachable"
}

check_network_connectivity() {
    log_debug "Début de l'analyse de connectivité réseau"
    
    local tests_total=0
    local tests_passed=0
    local tests_failed=0
    local overall_status="offline"
    local errors=()
    local warnings=()
    
    # Test 1: Ping
    log_info "Test PING vers $PING_HOST..."
    local ping_result ping_success ping_time ping_error
    ping_result=$(test_ping_connectivity "$PING_HOST")
    IFS='|' read -r ping_success ping_time ping_error <<< "$ping_result"
    ((tests_total++))
    if [[ "$ping_success" == "true" ]]; then
        ((tests_passed++))
    else
        ((tests_failed++))
        errors+=("Ping: $ping_error")
    fi
    
    # Test 2: DNS
    log_info "Test DNS pour $DNS_HOST..."
    local dns_result dns_success dns_ips dns_error
    dns_result=$(test_dns_resolution "$DNS_HOST")
    IFS='|' read -r dns_success dns_ips dns_error <<< "$dns_result"
    ((tests_total++))
    if [[ "$dns_success" == "true" ]]; then
        ((tests_passed++))
    else
        ((tests_failed++))
        errors+=("DNS: $dns_error")
    fi
    
    # Test 3: HTTP
    log_info "Test HTTP vers $HTTP_URL..."
    local http_result http_success http_code http_error
    http_result=$(test_http_connectivity "$HTTP_URL")
    IFS='|' read -r http_success http_code http_error <<< "$http_result"
    ((tests_total++))
    if [[ "$http_success" == "true" ]]; then
        ((tests_passed++))
    else
        ((tests_failed++))
        errors+=("HTTP: $http_error")
    fi
    
    # Test 4: HTTPS
    log_info "Test HTTPS vers $HTTPS_URL..."
    local https_result https_success https_code https_error
    https_result=$(test_http_connectivity "$HTTPS_URL")
    IFS='|' read -r https_success https_code https_error <<< "$https_result"
    ((tests_total++))
    if [[ "$https_success" == "true" ]]; then
        ((tests_passed++))
    else
        ((tests_failed++))
        errors+=("HTTPS: $https_error")
    fi
    
    # Récupérer infos réseau locales
    local interfaces gateway_info gateway_ip gateway_reachable
    interfaces=$(get_network_interfaces)
    gateway_info=$(get_default_gateway)
    IFS='|' read -r gateway_ip gateway_reachable <<< "$gateway_info"
    
    # Déterminer le statut global
    if [[ $tests_passed -eq $tests_total ]]; then
        overall_status="online"
    elif [[ $tests_passed -gt 0 ]]; then
        overall_status="partial"
        warnings+=("Connectivité partielle: $tests_passed/$tests_total tests réussis")
    else
        overall_status="offline"
    fi
    
    # Préparer les IPs DNS pour JSON
    local dns_ips_json=""
    if [[ -n "$dns_ips" ]]; then
        IFS=',' read -ra IP_ARRAY <<< "$dns_ips"
        for ip in "${IP_ARRAY[@]}"; do
            dns_ips_json="$dns_ips_json\"$ip\","
        done
        dns_ips_json="[${dns_ips_json%,}]"
    else
        dns_ips_json="[]"
    fi
    
    # Préparer les erreurs pour JSON
    local errors_json=""
    for error in "${errors[@]}"; do
        local escaped_error
        escaped_error=$(echo "$error" | sed 's/\\/\\\\/g; s/"/\\"/g')
        errors_json="$errors_json\"$escaped_error\","
    done
    errors_json="[${errors_json%,}]"
    
    # Préparer les warnings pour JSON
    local warnings_json=""
    for warning in "${warnings[@]}"; do
        local escaped_warning
        escaped_warning=$(echo "$warning" | sed 's/\\/\\\\/g; s/"/\\"/g')
        warnings_json="$warnings_json\"$escaped_warning\","
    done
    warnings_json="[${warnings_json%,}]"
    
    # Échapper les URLs pour JSON
    local http_url_escaped https_url_escaped
    http_url_escaped=$(echo "$HTTP_URL" | sed 's/\\/\\\\/g; s/"/\\"/g')
    https_url_escaped=$(echo "$HTTPS_URL" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Network connectivity check completed",
  "data": {
    "connectivity": {
      "overall_status": "$overall_status",
      "ping": {
        "success": $ping_success,
        "target": "$PING_HOST",
        "time_ms": $ping_time
      },
      "dns": {
        "success": $dns_success,
        "target": "$DNS_HOST",
        "resolved_ips": $dns_ips_json
      },
      "http": {
        "success": $http_success,
        "url": "$http_url_escaped",
        "status_code": $http_code
      },
      "https": {
        "success": $https_success,
        "url": "$https_url_escaped",
        "status_code": $https_code
      }
    },
    "interfaces": $interfaces,
    "gateway": {
      "ip": "$gateway_ip",
      "reachable": $gateway_reachable
    },
    "tests_summary": {
      "total": $tests_total,
      "passed": $tests_passed,
      "failed": $tests_failed,
      "success_rate": $((tests_passed * 100 / tests_total))
    },
    "test_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": $errors_json,
  "warnings": $warnings_json
}
EOF
    
    # Code de sortie basé sur le statut
    case $overall_status in
        "online") exit_code=0 ;;
        "partial") exit_code=3 ;;
        "offline") exit_code=4 ;;
        *) exit_code=1 ;;
    esac
    
    log_debug "Analyse terminée - Statut: $overall_status ($tests_passed/$tests_total tests réussis)"
    exit $exit_code
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    check_network_connectivity
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi