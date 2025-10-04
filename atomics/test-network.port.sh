#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: test-network.port.sh
# Description: Test l'accessibilité d'un port TCP/UDP sur une adresse
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-01-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="test-network.port.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
TIMEOUT=${TIMEOUT:-5}
PROTOCOL="tcp"
PORT=""
HOST=""
PORT_RANGE=""
SCAN_MULTIPLE=${SCAN_MULTIPLE:-0}

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
Usage: $SCRIPT_NAME [OPTIONS] <host> <port|port_range>

Description:
    Test l'accessibilité d'un ou plusieurs ports TCP/UDP sur une adresse
    avec mesure des temps de réponse et détection des services.

Arguments:
    <host>                  Adresse IP ou nom d'hôte à tester (obligatoire)
    <port>                  Port unique à tester (ex: 80, 443, 22)
    <port_range>            Plage de ports (ex: 80-90, 1-1024)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -t, --timeout <sec>    Timeout par connexion (défaut: 5s)
    -u, --udp              Tester en UDP au lieu de TCP
    --tcp                   Tester en TCP (défaut)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "target": {
          "host": "192.168.1.1",
          "resolved_ip": "192.168.1.1"
        },
        "tests": [
          {
            "port": 80,
            "protocol": "tcp",
            "accessible": true,
            "response_time_ms": 15,
            "service": "http",
            "banner": "Apache/2.4.41",
            "error": null
          }
        ],
        "summary": {
          "total_ports": 5,
          "accessible_ports": 3,
          "closed_ports": 2,
          "success_rate_percent": 60,
          "fastest_response_ms": 15,
          "slowest_response_ms": 234
        },
        "open_ports": [80, 443, 22],
        "closed_ports": [21, 23]
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Tous les ports testés sont accessibles
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Host inaccessible
    4 - Certains ports inaccessibles
    5 - Aucun port accessible

Exemples:
    $SCRIPT_NAME 192.168.1.1 80             # Test port 80 TCP
    $SCRIPT_NAME --udp 8.8.8.8 53           # Test port 53 UDP
    $SCRIPT_NAME google.com 80-90           # Test ports 80 à 90
    $SCRIPT_NAME --timeout 10 server.com 443 # Timeout 10s
    $SCRIPT_NAME localhost 1-1024           # Scan ports 1-1024
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
            -u|--udp)
                PROTOCOL="udp"
                shift
                ;;
            --tcp)
                PROTOCOL="tcp"
                shift
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                if [[ -z "$HOST" ]]; then
                    HOST="$1"
                elif [[ -z "$PORT" && -z "$PORT_RANGE" ]]; then
                    # Déterminer si c'est un port simple ou une plage
                    if [[ "$1" =~ ^[0-9]+-[0-9]+$ ]]; then
                        PORT_RANGE="$1"
                        SCAN_MULTIPLE=1
                    elif [[ "$1" =~ ^[0-9]+$ ]]; then
                        PORT="$1"
                    else
                        die "Format de port invalide: $1. Utilisez un nombre ou une plage (ex: 80-90)" 2
                    fi
                else
                    die "Trop d'arguments. Host et port déjà spécifiés." 2
                fi
                shift
                ;;
        esac
    done

    # Validation des paramètres obligatoires
    if [[ -z "$HOST" ]]; then
        die "Host obligatoire manquant. Utilisez -h pour l'aide." 2
    fi

    if [[ -z "$PORT" && -z "$PORT_RANGE" ]]; then
        die "Port ou plage de ports obligatoire manquant. Utilisez -h pour l'aide." 2
    fi

    # Validation timeout
    if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [[ $TIMEOUT -lt 1 ]]; then
        die "Timeout doit être un entier positif: $TIMEOUT" 2
    fi

    # Validation port simple
    if [[ -n "$PORT" ]]; then
        if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [[ $PORT -lt 1 ]] || [[ $PORT -gt 65535 ]]; then
            die "Port invalide: $PORT (doit être entre 1 et 65535)" 2
        fi
    fi

    # Validation plage de ports
    if [[ -n "$PORT_RANGE" ]]; then
        if [[ $PORT_RANGE =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local start_port="${BASH_REMATCH[1]}"
            local end_port="${BASH_REMATCH[2]}"
            
            if [[ $start_port -lt 1 ]] || [[ $start_port -gt 65535 ]] || [[ $end_port -lt 1 ]] || [[ $end_port -gt 65535 ]]; then
                die "Ports dans la plage doivent être entre 1 et 65535: $PORT_RANGE" 2
            fi
            
            if [[ $start_port -ge $end_port ]]; then
                die "Port de début doit être inférieur au port de fin: $PORT_RANGE" 2
            fi
            
            # Limiter les gros scans pour éviter les abus
            local port_count=$((end_port - start_port + 1))
            if [[ $port_count -gt 1000 ]]; then
                die "Plage de ports trop large (max 1000 ports): $port_count ports demandés" 2
            fi
        else
            die "Format de plage invalide: $PORT_RANGE. Utilisez format start-end (ex: 80-90)" 2
        fi
    fi
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    # Vérifier outils de test de connectivité
    if [[ "$PROTOCOL" == "tcp" ]]; then
        if ! command -v nc >/dev/null 2>&1 && ! command -v telnet >/dev/null 2>&1 && ! command -v nmap >/dev/null 2>&1; then
            # Essayer avec bash natif /dev/tcp
            if ! exec 3<> /dev/tcp/127.0.0.1/22 2>/dev/null; then
                missing+=("nc (netcat) ou telnet ou nmap ou bash avec /dev/tcp")
            fi
            exec 3>&-
        fi
    else
        # Pour UDP, nc est fortement recommandé
        if ! command -v nc >/dev/null 2>&1 && ! command -v nmap >/dev/null 2>&1; then
            missing+=("nc (netcat) ou nmap pour tests UDP")
        fi
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Toutes les dépendances sont disponibles"
}

resolve_host() {
    local host="$1"
    local resolved_ip="$host"
    
    log_debug "Résolution de $host"
    
    # Si c'est déjà une IP, pas besoin de résoudre
    if [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$host" =~ ^[0-9a-fA-F:]+$ ]]; then
        echo "$host"
        return 0
    fi
    
    # Tenter de résoudre le nom d'hôte
    if command -v nslookup >/dev/null 2>&1; then
        local nslookup_output
        if nslookup_output=$(nslookup "$host" 2>/dev/null); then
            resolved_ip=$(echo "$nslookup_output" | grep -E "Address.*:" | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | tail -1 | awk '{print $2}' | head -1)
        fi
    elif command -v dig >/dev/null 2>&1; then
        resolved_ip=$(dig +short "$host" A 2>/dev/null | head -1)
    elif command -v host >/dev/null 2>&1; then
        resolved_ip=$(host "$host" 2>/dev/null | grep "has address" | awk '{print $4}' | head -1)
    fi
    
    # Si la résolution échoue, utiliser le nom original
    if [[ -z "$resolved_ip" ]]; then
        resolved_ip="$host"
    fi
    
    echo "$resolved_ip"
}

get_service_name() {
    local port="$1"
    local protocol="$2"
    
    # Services communs par port
    case $port in
        21) echo "ftp" ;;
        22) echo "ssh" ;;
        23) echo "telnet" ;;
        25) echo "smtp" ;;
        53) echo "dns" ;;
        80) echo "http" ;;
        110) echo "pop3" ;;
        143) echo "imap" ;;
        443) echo "https" ;;
        993) echo "imaps" ;;
        995) echo "pop3s" ;;
        3306) echo "mysql" ;;
        5432) echo "postgresql" ;;
        6379) echo "redis" ;;
        27017) echo "mongodb" ;;
        *) echo "unknown" ;;
    esac
}

test_tcp_port() {
    local host="$1"
    local port="$2"
    local start_time end_time response_time_ms
    local accessible=false
    local banner=""
    local error_msg=""
    
    log_debug "Test TCP $host:$port"
    
    start_time=$(date +%s%N)
    
    # Méthode 1: netcat (nc)
    if command -v nc >/dev/null 2>&1; then
        if timeout "$TIMEOUT" nc -z "$host" "$port" 2>/dev/null; then
            accessible=true
            
            # Tenter de récupérer une bannière
            if banner_output=$(timeout 2 nc "$host" "$port" </dev/null 2>/dev/null | head -1); then
                banner=$(echo "$banner_output" | tr -d '\r\n' | cut -c1-100)
            fi
        else
            error_msg="Connection failed (nc)"
        fi
    # Méthode 2: telnet
    elif command -v telnet >/dev/null 2>&1; then
        if timeout "$TIMEOUT" bash -c "echo | telnet $host $port" 2>/dev/null | grep -q "Connected"; then
            accessible=true
        else
            error_msg="Connection failed (telnet)"
        fi
    # Méthode 3: bash natif /dev/tcp
    else
        if timeout "$TIMEOUT" bash -c "exec 3<> /dev/tcp/$host/$port" 2>/dev/null; then
            accessible=true
            exec 3>&-
        else
            error_msg="Connection failed (bash /dev/tcp)"
        fi
    fi
    
    end_time=$(date +%s%N)
    response_time_ms=$(( (end_time - start_time) / 1000000 ))
    
    echo "$accessible|$response_time_ms|$banner|$error_msg"
}

test_udp_port() {
    local host="$1"
    local port="$2"
    local start_time end_time response_time_ms
    local accessible=false
    local banner=""
    local error_msg=""
    
    log_debug "Test UDP $host:$port"
    
    start_time=$(date +%s%N)
    
    # Pour UDP, c'est plus complexe car il n'y a pas d'établissement de connexion
    if command -v nc >/dev/null 2>&1; then
        # Envoyer un paquet et voir s'il y a une réponse
        if echo "" | timeout "$TIMEOUT" nc -u "$host" "$port" 2>/dev/null | grep -q "."; then
            accessible=true
        else
            # Pour UDP, l'absence de réponse ne signifie pas forcément que le port est fermé
            # On considère "probablement ouvert" si pas d'erreur ICMP
            if timeout "$TIMEOUT" nc -u -z "$host" "$port" 2>/dev/null; then
                accessible=true
                error_msg="UDP port may be open (no response)"
            else
                accessible=false
                error_msg="UDP port unreachable"
            fi
        fi
    elif command -v nmap >/dev/null 2>&1; then
        # Utiliser nmap pour un test UDP plus fiable
        local nmap_output
        if nmap_output=$(timeout "$TIMEOUT" nmap -sU -p "$port" "$host" 2>/dev/null); then
            if echo "$nmap_output" | grep -q "open"; then
                accessible=true
            else
                accessible=false
                error_msg="UDP port filtered/closed (nmap)"
            fi
        else
            error_msg="nmap UDP scan failed"
        fi
    else
        error_msg="No suitable tool for UDP testing"
    fi
    
    end_time=$(date +%s%N)
    response_time_ms=$(( (end_time - start_time) / 1000000 ))
    
    echo "$accessible|$response_time_ms|$banner|$error_msg"
}

test_single_port() {
    local host="$1"
    local port="$2"
    local result accessible response_time banner error_msg
    
    # Tester selon le protocole
    if [[ "$PROTOCOL" == "tcp" ]]; then
        result=$(test_tcp_port "$host" "$port")
    else
        result=$(test_udp_port "$host" "$port")
    fi
    
    IFS='|' read -r accessible response_time banner error_msg <<< "$result"
    
    # Récupérer le nom du service
    local service
    service=$(get_service_name "$port" "$PROTOCOL")
    
    # Échapper pour JSON
    local banner_escaped error_escaped
    banner_escaped=$(echo "$banner" | sed 's/\\/\\\\/g; s/"/\\"/g')
    error_escaped=$(echo "$error_msg" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Retourner JSON pour ce port
    cat << EOF
{
  "port": $port,
  "protocol": "$PROTOCOL",
  "accessible": $accessible,
  "response_time_ms": $response_time,
  "service": "$service",
  "banner": "${banner_escaped:-null}",
  "error": $([ -n "$error_escaped" ] && echo "\"$error_escaped\"" || echo "null")
}
EOF
}

expand_port_range() {
    local range="$1"
    local ports=()
    
    if [[ $range =~ ^([0-9]+)-([0-9]+)$ ]]; then
        local start="${BASH_REMATCH[1]}"
        local end="${BASH_REMATCH[2]}"
        
        for ((port=start; port<=end; port++)); do
            ports+=("$port")
        done
    fi
    
    printf '%s\n' "${ports[@]}"
}

test_port_connectivity() {
    log_debug "Début test de connectivité port"
    
    # Résoudre l'hôte
    local resolved_ip
    resolved_ip=$(resolve_host "$HOST")
    
    log_info "Test de $HOST (résolu: $resolved_ip) en $PROTOCOL"
    
    # Préparer la liste des ports à tester
    local ports_to_test=()
    
    if [[ -n "$PORT" ]]; then
        ports_to_test=("$PORT")
    else
        mapfile -t ports_to_test < <(expand_port_range "$PORT_RANGE")
    fi
    
    local total_ports=${#ports_to_test[@]}
    log_info "Test de $total_ports port(s)"
    
    # Variables pour les statistiques
    local tests_json=""
    local accessible_count=0
    local closed_count=0
    local open_ports=()
    local closed_ports=()
    local fastest_time=999999
    local slowest_time=0
    local errors=()
    local warnings=()
    
    # Tester chaque port
    for port in "${ports_to_test[@]}"; do
        log_info "Test port $port..."
        
        local port_result
        if port_result=$(test_single_port "$resolved_ip" "$port"); then
            tests_json="$tests_json$port_result,"
            
            # Analyser le résultat pour les statistiques
            if echo "$port_result" | grep -q '"accessible": true'; then
                ((accessible_count++))
                open_ports+=("$port")
                
                # Extraire le temps de réponse
                local response_time
                response_time=$(echo "$port_result" | grep -oE '"response_time_ms": [0-9]+' | awk '{print $2}')
                
                if [[ $response_time -lt $fastest_time ]]; then
                    fastest_time=$response_time
                fi
                
                if [[ $response_time -gt $slowest_time ]]; then
                    slowest_time=$response_time
                fi
            else
                ((closed_count++))
                closed_ports+=("$port")
            fi
        else
            ((closed_count++))
            closed_ports+=("$port")
            errors+=("Erreur lors du test du port $port")
        fi
    done
    
    # Calculer le taux de succès
    local success_rate=0
    if [[ $total_ports -gt 0 ]]; then
        success_rate=$((accessible_count * 100 / total_ports))
    fi
    
    # Gérer les cas où aucun port n'est accessible
    if [[ $accessible_count -eq 0 ]]; then
        fastest_time=0
        slowest_time=0
    fi
    
    # Retirer la virgule finale des tests
    tests_json="[${tests_json%,}]"
    
    # Préparer les listes de ports pour JSON
    local open_ports_json=""
    for port in "${open_ports[@]}"; do
        open_ports_json="$open_ports_json$port,"
    done
    open_ports_json="[${open_ports_json%,}]"
    
    local closed_ports_json=""
    for port in "${closed_ports[@]}"; do
        closed_ports_json="$closed_ports_json$port,"
    done
    closed_ports_json="[${closed_ports_json%,}]"
    
    # Préparer les erreurs pour JSON
    local errors_json=""
    for error in "${errors[@]}"; do
        local escaped_error
        escaped_error=$(echo "$error" | sed 's/\\/\\\\/g; s/"/\\"/g')
        errors_json="$errors_json\"$escaped_error\","
    done
    errors_json="[${errors_json%,}]"
    
    # Échapper pour JSON
    local host_escaped resolved_ip_escaped
    host_escaped=$(echo "$HOST" | sed 's/\\/\\\\/g; s/"/\\"/g')
    resolved_ip_escaped=$(echo "$resolved_ip" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Réponse JSON finale
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Port connectivity test completed",
  "data": {
    "target": {
      "host": "$host_escaped",
      "resolved_ip": "$resolved_ip_escaped"
    },
    "tests": $tests_json,
    "summary": {
      "total_ports": $total_ports,
      "accessible_ports": $accessible_count,
      "closed_ports": $closed_count,
      "success_rate_percent": $success_rate,
      "fastest_response_ms": $fastest_time,
      "slowest_response_ms": $slowest_time
    },
    "open_ports": $open_ports_json,
    "closed_ports": $closed_ports_json,
    "test_parameters": {
      "protocol": "$PROTOCOL",
      "timeout": $TIMEOUT,
      "port_range": "${PORT_RANGE:-single_port}"
    },
    "scan_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": $errors_json,
  "warnings": []
}
EOF
    
    # Code de sortie basé sur les résultats
    local exit_code
    if [[ $accessible_count -eq $total_ports ]]; then
        exit_code=0  # Tous accessibles
    elif [[ $accessible_count -gt 0 ]]; then
        exit_code=4  # Certains accessibles
    else
        exit_code=5  # Aucun accessible
    fi
    
    log_debug "Tests terminés - $accessible_count/$total_ports ports accessibles"
    exit $exit_code
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    test_port_connectivity
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi