#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: test-network.ping.sh
# Description: Test la connectivité ping vers une ou plusieurs destinations
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-01-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="test-network.ping.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
COUNT=${COUNT:-4}
TIMEOUT=${TIMEOUT:-5}
INTERVAL=${INTERVAL:-1}
PACKET_SIZE=${PACKET_SIZE:-56}
CONTINUOUS=${CONTINUOUS:-0}
IPV6=${IPV6:-0}

# Destinations à tester
TARGETS=()

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
Usage: $SCRIPT_NAME [OPTIONS] <target1> [target2] [...]

Description:
    Test la connectivité ICMP (ping) vers une ou plusieurs destinations
    avec statistiques détaillées et analyse de performance réseau.

Arguments:
    <target>                IP ou nom d'hôte à tester (obligatoire, multiples possibles)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -c, --count <n>        Nombre de pings par destination (défaut: 4)
    -t, --timeout <sec>    Timeout par ping en secondes (défaut: 5)
    -i, --interval <sec>   Intervalle entre pings en secondes (défaut: 1)
    -s, --size <bytes>     Taille des paquets ICMP (défaut: 56)
    -C, --continuous       Mode continu (jusqu'à interruption Ctrl+C)
    -6, --ipv6             Utiliser IPv6 (ping6)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "targets": [
          {
            "target": "8.8.8.8",
            "resolved_ip": "8.8.8.8",
            "reachable": true,
            "statistics": {
              "packets_sent": 4,
              "packets_received": 4,
              "packet_loss_percent": 0,
              "time_total_ms": 3456,
              "rtt": {
                "min_ms": 15.2,
                "max_ms": 18.7,
                "avg_ms": 16.8,
                "stddev_ms": 1.2
              }
            },
            "individual_pings": [
              {"sequence": 1, "time_ms": 15.2, "ttl": 64},
              {"sequence": 2, "time_ms": 16.8, "ttl": 64}
            ]
          }
        ],
        "summary": {
          "total_targets": 2,
          "reachable_targets": 1,
          "unreachable_targets": 1,
          "success_rate_percent": 50
        }
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Toutes les destinations sont accessibles
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Certaines destinations inaccessibles
    4 - Aucune destination accessible

Exemples:
    $SCRIPT_NAME 8.8.8.8                     # Ping simple
    $SCRIPT_NAME 8.8.8.8 1.1.1.1            # Ping multiple destinations
    $SCRIPT_NAME --count 10 google.com       # 10 pings
    $SCRIPT_NAME --ipv6 2001:4860:4860::8888 # IPv6
    $SCRIPT_NAME --continuous 192.168.1.1    # Mode continu
    $SCRIPT_NAME --size 1000 --interval 2 8.8.8.8  # Paquets 1KB, intervalle 2s
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
            -c|--count)
                COUNT="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -i|--interval)
                INTERVAL="$2"
                shift 2
                ;;
            -s|--size)
                PACKET_SIZE="$2"
                shift 2
                ;;
            -C|--continuous)
                CONTINUOUS=1
                shift
                ;;
            -6|--ipv6)
                IPV6=1
                shift
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                TARGETS+=("$1")
                shift
                ;;
        esac
    done

    # Validation des paramètres obligatoires
    if [[ ${#TARGETS[@]} -eq 0 ]]; then
        die "Au moins une destination est requise. Utilisez -h pour l'aide." 2
    fi

    # Validation des paramètres numériques
    if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [[ $COUNT -lt 1 ]]; then
        die "Count doit être un entier positif: $COUNT" 2
    fi

    if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [[ $TIMEOUT -lt 1 ]]; then
        die "Timeout doit être un entier positif: $TIMEOUT" 2
    fi

    if ! [[ "$PACKET_SIZE" =~ ^[0-9]+$ ]] || [[ $PACKET_SIZE -lt 8 ]]; then
        die "Packet size doit être >= 8 bytes: $PACKET_SIZE" 2
    fi
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    if [[ $IPV6 -eq 1 ]]; then
        if ! command -v ping6 >/dev/null 2>&1 && ! (command -v ping >/dev/null 2>&1 && ping -6 -c 1 ::1 >/dev/null 2>&1); then
            missing+=("ping6 ou ping avec support IPv6")
        fi
    else
        if ! command -v ping >/dev/null 2>&1; then
            missing+=("ping")
        fi
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Toutes les dépendances sont disponibles"
}

resolve_target() {
    local target="$1"
    local resolved_ip="$target"
    
    log_debug "Résolution de $target"
    
    # Tenter de résoudre le nom d'hôte vers IP
    if ! [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && ! [[ "$target" =~ ^[0-9a-fA-F:]+$ ]]; then
        # Ce n'est pas une IP, essayer de résoudre
        if command -v nslookup >/dev/null 2>&1; then
            local nslookup_output
            if nslookup_output=$(nslookup "$target" 2>/dev/null); then
                if [[ $IPV6 -eq 1 ]]; then
                    resolved_ip=$(echo "$nslookup_output" | grep -E "Address.*:" | grep -E "[0-9a-fA-F:]" | tail -1 | awk '{print $2}' | head -1)
                else
                    resolved_ip=$(echo "$nslookup_output" | grep -E "Address.*:" | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | tail -1 | awk '{print $2}' | head -1)
                fi
            fi
        elif command -v dig >/dev/null 2>&1; then
            local record_type
            record_type=$([[ $IPV6 -eq 1 ]] && echo "AAAA" || echo "A")
            resolved_ip=$(dig +short "$target" "$record_type" 2>/dev/null | head -1)
        fi
        
        # Si la résolution échoue, utiliser le nom original
        if [[ -z "$resolved_ip" ]]; then
            resolved_ip="$target"
        fi
    fi
    
    echo "$resolved_ip"
}

parse_ping_output() {
    local ping_output="$1"
    local packets_sent=0
    local packets_received=0
    local packet_loss=0
    local time_total=0
    local rtt_min=0
    local rtt_max=0
    local rtt_avg=0
    local rtt_stddev=0
    
    # Parser les statistiques globales
    if echo "$ping_output" | grep -q "packets transmitted"; then
        local stats_line
        stats_line=$(echo "$ping_output" | grep "packets transmitted")
        packets_sent=$(echo "$stats_line" | grep -oE "[0-9]+ packets transmitted" | awk '{print $1}')
        packets_received=$(echo "$stats_line" | grep -oE "[0-9]+ received" | awk '{print $1}')
        
        if [[ $packets_sent -gt 0 ]]; then
            packet_loss=$(( (packets_sent - packets_received) * 100 / packets_sent ))
        fi
        
        # Temps total
        if echo "$stats_line" | grep -q "time [0-9]*ms"; then
            time_total=$(echo "$stats_line" | grep -oE "time [0-9]*ms" | grep -oE "[0-9]+")
        fi
    fi
    
    # Parser les statistiques RTT
    if echo "$ping_output" | grep -q "min/avg/max"; then
        local rtt_line
        rtt_line=$(echo "$ping_output" | grep "min/avg/max" | tail -1)
        local rtt_values
        rtt_values=$(echo "$rtt_line" | grep -oE "[0-9]+\.[0-9]+/[0-9]+\.[0-9]+/[0-9]+\.[0-9]+")
        
        if [[ -n "$rtt_values" ]]; then
            IFS='/' read -r rtt_min rtt_avg rtt_max <<< "$rtt_values"
            
            # Chercher stddev si disponible
            if echo "$rtt_line" | grep -q "mdev"; then
                rtt_stddev=$(echo "$rtt_line" | grep -oE "mdev = [0-9]+\.[0-9]+" | awk '{print $3}')
            fi
        fi
    fi
    
    echo "$packets_sent|$packets_received|$packet_loss|$time_total|$rtt_min|$rtt_avg|$rtt_max|$rtt_stddev"
}

parse_individual_pings() {
    local ping_output="$1"
    local pings_json=""
    
    # Parser chaque ligne de ping individuel
    local seq=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "bytes from" && echo "$line" | grep -q "time="; then
            ((seq++))
            local time_ms ttl
            time_ms=$(echo "$line" | grep -oE "time=[0-9]+\.?[0-9]*" | cut -d= -f2)
            ttl=$(echo "$line" | grep -oE "ttl=[0-9]+" | cut -d= -f2)
            
            if [[ -n "$time_ms" ]]; then
                pings_json="$pings_json{\"sequence\":$seq,\"time_ms\":$time_ms,\"ttl\":${ttl:-0}},"
            fi
        fi
    done <<< "$ping_output"
    
    # Retirer la virgule finale
    pings_json="[${pings_json%,}]"
    echo "$pings_json"
}

ping_target() {
    local target="$1"
    local resolved_ip
    resolved_ip=$(resolve_target "$target")
    
    log_debug "Test ping vers $target (résolu: $resolved_ip)"
    
    local ping_cmd="ping"
    local ping_args=()
    
    # Construire la commande ping
    if [[ $IPV6 -eq 1 ]]; then
        if command -v ping6 >/dev/null 2>&1; then
            ping_cmd="ping6"
        else
            ping_args+=("-6")
        fi
    fi
    
    # Arguments communs
    if [[ $CONTINUOUS -eq 0 ]]; then
        ping_args+=("-c" "$COUNT")
    fi
    ping_args+=("-W" "$TIMEOUT")
    ping_args+=("-i" "$INTERVAL")
    ping_args+=("-s" "$PACKET_SIZE")
    
    # Exécuter ping
    local ping_output exit_code=0
    log_info "Ping $target... ($COUNT paquets)"
    
    if ping_output=$("$ping_cmd" "${ping_args[@]}" "$resolved_ip" 2>&1); then
        log_debug "Ping réussi pour $target"
    else
        exit_code=$?
        log_debug "Ping échoué pour $target (code: $exit_code)"
    fi
    
    # Parser les résultats
    local stats individual_pings
    stats=$(parse_ping_output "$ping_output")
    individual_pings=$(parse_individual_pings "$ping_output")
    
    local packets_sent packets_received packet_loss time_total rtt_min rtt_avg rtt_max rtt_stddev
    IFS='|' read -r packets_sent packets_received packet_loss time_total rtt_min rtt_avg rtt_max rtt_stddev <<< "$stats"
    
    # Déterminer si accessible
    local reachable
    reachable=$([[ $packets_received -gt 0 ]] && echo "true" || echo "false")
    
    # Échapper pour JSON
    local target_escaped resolved_ip_escaped
    target_escaped=$(echo "$target" | sed 's/\\/\\\\/g; s/"/\\"/g')
    resolved_ip_escaped=$(echo "$resolved_ip" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Retourner JSON pour cette destination
    cat << EOF
{
  "target": "$target_escaped",
  "resolved_ip": "$resolved_ip_escaped",
  "reachable": $reachable,
  "statistics": {
    "packets_sent": ${packets_sent:-0},
    "packets_received": ${packets_received:-0},
    "packet_loss_percent": ${packet_loss:-100},
    "time_total_ms": ${time_total:-0},
    "rtt": {
      "min_ms": ${rtt_min:-0},
      "max_ms": ${rtt_max:-0},
      "avg_ms": ${rtt_avg:-0},
      "stddev_ms": ${rtt_stddev:-0}
    }
  },
  "individual_pings": $individual_pings
}
EOF
}

test_ping_connectivity() {
    log_debug "Démarrage des tests ping pour ${#TARGETS[@]} destination(s)"
    
    local targets_json=""
    local total_targets=${#TARGETS[@]}
    local reachable_count=0
    local unreachable_count=0
    local errors=()
    local warnings=()
    
    # Tester chaque destination
    for target in "${TARGETS[@]}"; do
        log_info "Test de $target..."
        
        local target_result
        if target_result=$(ping_target "$target"); then
            # Vérifier si accessible
            if echo "$target_result" | grep -q '"reachable": true'; then
                ((reachable_count++))
            else
                ((unreachable_count++))
                warnings+=("Destination inaccessible: $target")
            fi
            
            targets_json="$targets_json$target_result,"
        else
            ((unreachable_count++))
            errors+=("Erreur lors du test de $target")
            
            # Ajouter une entrée d'erreur
            local target_escaped
            target_escaped=$(echo "$target" | sed 's/\\/\\\\/g; s/"/\\"/g')
            targets_json="$targets_json{\"target\":\"$target_escaped\",\"resolved_ip\":\"$target_escaped\",\"reachable\":false,\"error\":\"Ping command failed\"},"
        fi
    done
    
    # Retirer la virgule finale
    targets_json="[${targets_json%,}]"
    
    # Calculer le taux de succès
    local success_rate=0
    if [[ $total_targets -gt 0 ]]; then
        success_rate=$((reachable_count * 100 / total_targets))
    fi
    
    # Préparer les erreurs et warnings pour JSON
    local errors_json=""
    for error in "${errors[@]}"; do
        local escaped_error
        escaped_error=$(echo "$error" | sed 's/\\/\\\\/g; s/"/\\"/g')
        errors_json="$errors_json\"$escaped_error\","
    done
    errors_json="[${errors_json%,}]"
    
    local warnings_json=""
    for warning in "${warnings[@]}"; do
        local escaped_warning
        escaped_warning=$(echo "$warning" | sed 's/\\/\\\\/g; s/"/\\"/g')
        warnings_json="$warnings_json\"$escaped_warning\","
    done
    warnings_json="[${warnings_json%,}]"
    
    # Réponse JSON finale
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Ping connectivity test completed",
  "data": {
    "targets": $targets_json,
    "summary": {
      "total_targets": $total_targets,
      "reachable_targets": $reachable_count,
      "unreachable_targets": $unreachable_count,
      "success_rate_percent": $success_rate
    },
    "test_parameters": {
      "count": $COUNT,
      "timeout": $TIMEOUT,
      "interval": $INTERVAL,
      "packet_size": $PACKET_SIZE,
      "continuous": $([ $CONTINUOUS -eq 1 ] && echo "true" || echo "false"),
      "ipv6": $([ $IPV6 -eq 1 ] && echo "true" || echo "false")
    },
    "test_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": $errors_json,
  "warnings": $warnings_json
}
EOF
    
    # Code de sortie basé sur les résultats
    if [[ $reachable_count -eq $total_targets ]]; then
        exit_code=0  # Tout accessible
    elif [[ $reachable_count -gt 0 ]]; then
        exit_code=3  # Partiellement accessible
    else
        exit_code=4  # Rien d'accessible
    fi
    
    log_debug "Tests terminés - $reachable_count/$total_targets destinations accessibles"
    exit $exit_code
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    test_ping_connectivity
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi