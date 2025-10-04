#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: list-network.connections.sh
# Description: Liste les connexions réseau actives avec détails
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-01-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="list-network.connections.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
LISTENING_ONLY=${LISTENING_ONLY:-0}
ESTABLISHED_ONLY=${ESTABLISHED_ONLY:-0}
TCP_ONLY=${TCP_ONLY:-0}
UDP_ONLY=${UDP_ONLY:-0}
SHOW_PROCESSES=${SHOW_PROCESSES:-0}
FILTER_PORT=""
FILTER_IP=""

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
    Liste les connexions réseau actives (TCP/UDP) avec informations détaillées
    incluant les adresses locales/distantes, états, et processus associés.

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -l, --listening        Afficher seulement les ports en écoute
    -e, --established      Afficher seulement les connexions établies
    -t, --tcp-only         Afficher seulement les connexions TCP
    -u, --udp-only         Afficher seulement les connexions UDP
    -p, --processes        Inclure informations des processus (nécessite privilèges)
    --port <port>          Filtrer par port spécifique
    --ip <ip>              Filtrer par adresse IP spécifique

Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "connections": [
          {
            "protocol": "tcp",
            "local_address": "192.168.1.100",
            "local_port": 22,
            "remote_address": "192.168.1.50",
            "remote_port": 54321,
            "state": "ESTABLISHED",
            "process": {
              "pid": 1234,
              "name": "sshd",
              "user": "root"
            }
          }
        ],
        "summary": {
          "total_connections": 45,
          "tcp_connections": 30,
          "udp_connections": 15,
          "listening_ports": 10,
          "established_connections": 20,
          "protocols": ["tcp", "udp", "tcp6", "udp6"]
        },
        "listening_ports": [
          {"protocol": "tcp", "port": 22, "address": "0.0.0.0", "service": "ssh"}
        ]
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Outils réseau indisponibles
    4 - Aucune connexion trouvée

Exemples:
    $SCRIPT_NAME                              # Toutes les connexions
    $SCRIPT_NAME --listening                  # Ports en écoute uniquement
    $SCRIPT_NAME --established --tcp-only     # Connexions TCP établies
    $SCRIPT_NAME --processes                  # Avec infos processus
    $SCRIPT_NAME --port 80                    # Connexions port 80
    $SCRIPT_NAME --ip 192.168.1.100          # Connexions vers/depuis cette IP
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
            -l|--listening)
                LISTENING_ONLY=1
                shift
                ;;
            -e|--established)
                ESTABLISHED_ONLY=1
                shift
                ;;
            -t|--tcp-only)
                TCP_ONLY=1
                shift
                ;;
            -u|--udp-only)
                UDP_ONLY=1
                shift
                ;;
            -p|--processes)
                SHOW_PROCESSES=1
                shift
                ;;
            --port)
                FILTER_PORT="$2"
                shift 2
                ;;
            --ip)
                FILTER_IP="$2"
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

    # Validation des filtres mutuellement exclusifs
    if [[ $LISTENING_ONLY -eq 1 && $ESTABLISHED_ONLY -eq 1 ]]; then
        die "Options --listening et --established mutuellement exclusives" 2
    fi

    if [[ $TCP_ONLY -eq 1 && $UDP_ONLY -eq 1 ]]; then
        die "Options --tcp-only et --udp-only mutuellement exclusives" 2
    fi

    # Validation du port si spécifié
    if [[ -n "$FILTER_PORT" ]]; then
        if ! [[ "$FILTER_PORT" =~ ^[0-9]+$ ]] || [[ $FILTER_PORT -lt 1 ]] || [[ $FILTER_PORT -gt 65535 ]]; then
            die "Port invalide: $FILTER_PORT (doit être entre 1 et 65535)" 2
        fi
    fi
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    # Vérifier disponibilité des outils de listage réseau
    if ! command -v ss >/dev/null 2>&1 && ! command -v netstat >/dev/null 2>&1; then
        missing+=("ss ou netstat")
    fi
    
    if [[ $SHOW_PROCESSES -eq 1 ]] && ! command -v ps >/dev/null 2>&1; then
        missing+=("ps")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Toutes les dépendances sont disponibles"
}

get_process_info() {
    local pid="$1"
    local name="unknown"
    local user="unknown"
    
    if [[ -n "$pid" && "$pid" != "-" && "$pid" != "0" ]]; then
        if command -v ps >/dev/null 2>&1; then
            local ps_output
            if ps_output=$(ps -p "$pid" -o comm=,user= 2>/dev/null); then
                name=$(echo "$ps_output" | awk '{print $1}')
                user=$(echo "$ps_output" | awk '{print $2}')
            fi
        fi
    fi
    
    echo "$name|$user"
}

parse_ss_output() {
    local protocol="$1"
    local connections_json=""
    local total_connections=0
    
    log_debug "Analyse sortie ss pour protocole: $protocol"
    
    # Construire la commande ss
    local ss_cmd="ss"
    local ss_args=("-n")  # Pas de résolution DNS
    
    case $protocol in
        "tcp")
            ss_args+=("-t")
            if [[ $LISTENING_ONLY -eq 1 ]]; then
                ss_args+=("-l")
            elif [[ $ESTABLISHED_ONLY -eq 1 ]]; then
                ss_args+=("-o" "state" "established")
            fi
            ;;
        "udp")
            ss_args+=("-u")
            if [[ $LISTENING_ONLY -eq 1 ]]; then
                ss_args+=("-l")
            fi
            ;;
        "tcp6")
            ss_args+=("-t" "-6")
            if [[ $LISTENING_ONLY -eq 1 ]]; then
                ss_args+=("-l")
            elif [[ $ESTABLISHED_ONLY -eq 1 ]]; then
                ss_args+=("-o" "state" "established")
            fi
            ;;
        "udp6")
            ss_args+=("-u" "-6")
            if [[ $LISTENING_ONLY -eq 1 ]]; then
                ss_args+=("-l")
            fi
            ;;
    esac
    
    # Ajouter info processus si demandé
    if [[ $SHOW_PROCESSES -eq 1 ]]; then
        ss_args+=("-p")
    fi
    
    # Exécuter ss et parser
    local ss_output
    if ss_output=$("$ss_cmd" "${ss_args[@]}" 2>/dev/null); then
        while IFS= read -r line; do
            # Ignorer l'en-tête
            if [[ $line =~ ^(State|Netid) ]] || [[ -z "$line" ]]; then
                continue
            fi
            
            # Parser selon format ss
            local state="UNKNOWN"
            local local_addr local_port remote_addr remote_port
            local process_info=""
            
            if [[ $protocol =~ tcp ]]; then
                # Format TCP: State Recv-Q Send-Q Local Address:Port Peer Address:Port Process
                if [[ $line =~ ^([A-Z-]+)[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)(.*)$ ]]; then
                    state="${BASH_REMATCH[1]}"
                    local local_full="${BASH_REMATCH[2]}"
                    local remote_full="${BASH_REMATCH[3]}"
                    process_info="${BASH_REMATCH[4]}"
                    
                    # Parser adresse:port locale
                    if [[ $local_full =~ ^(.*):([0-9]+)$ ]]; then
                        local_addr="${BASH_REMATCH[1]}"
                        local_port="${BASH_REMATCH[2]}"
                    fi
                    
                    # Parser adresse:port distante
                    if [[ $remote_full =~ ^(.*):([0-9]+)$ ]]; then
                        remote_addr="${BASH_REMATCH[1]}"
                        remote_port="${BASH_REMATCH[2]}"
                    fi
                fi
            else
                # Format UDP: State Recv-Q Send-Q Local Address:Port Peer Address:Port Process
                state="UNCONN"  # UDP est sans état par défaut
                if [[ $line =~ ^[A-Z-]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)(.*)$ ]]; then
                    local local_full="${BASH_REMATCH[1]}"
                    local remote_full="${BASH_REMATCH[2]}"
                    process_info="${BASH_REMATCH[3]}"
                    
                    # Parser adresse:port locale
                    if [[ $local_full =~ ^(.*):([0-9]+)$ ]]; then
                        local_addr="${BASH_REMATCH[1]}"
                        local_port="${BASH_REMATCH[2]}"
                    fi
                    
                    # Parser adresse:port distante
                    if [[ $remote_full =~ ^(.*):([0-9]+)$ ]]; then
                        remote_addr="${BASH_REMATCH[1]}"
                        remote_port="${BASH_REMATCH[2]}"
                    fi
                fi
            fi
            
            # Appliquer filtres
            local skip=false
            
            # Filtre par port
            if [[ -n "$FILTER_PORT" ]]; then
                if [[ "$local_port" != "$FILTER_PORT" && "$remote_port" != "$FILTER_PORT" ]]; then
                    skip=true
                fi
            fi
            
            # Filtre par IP
            if [[ -n "$FILTER_IP" ]]; then
                if [[ "$local_addr" != *"$FILTER_IP"* && "$remote_addr" != *"$FILTER_IP"* ]]; then
                    skip=true
                fi
            fi
            
            if [[ $skip == true ]]; then
                continue
            fi
            
            # Parser informations processus si disponible
            local pid="0" process_name="unknown" process_user="unknown"
            if [[ $SHOW_PROCESSES -eq 1 && -n "$process_info" ]]; then
                # Format: users:(("processname",pid=1234,fd=3))
                if [[ $process_info =~ pid=([0-9]+) ]]; then
                    pid="${BASH_REMATCH[1]}"
                    
                    # Récupérer nom et utilisateur du processus
                    local proc_info
                    proc_info=$(get_process_info "$pid")
                    IFS='|' read -r process_name process_user <<< "$proc_info"
                fi
            fi
            
            # Nettoyer les adresses IPv6 (retirer les crochets)
            local_addr=${local_addr//\[/}
            local_addr=${local_addr//\]/}
            remote_addr=${remote_addr//\[/}
            remote_addr=${remote_addr//\]/}
            
            # Remplacer * par 0.0.0.0 pour clarté
            [[ "$local_addr" == "*" ]] && local_addr="0.0.0.0"
            [[ "$remote_addr" == "*" ]] && remote_addr="0.0.0.0"
            
            # Échapper pour JSON
            local local_addr_escaped remote_addr_escaped process_name_escaped process_user_escaped
            local_addr_escaped=$(echo "$local_addr" | sed 's/\\/\\\\/g; s/"/\\"/g')
            remote_addr_escaped=$(echo "$remote_addr" | sed 's/\\/\\\\/g; s/"/\\"/g')
            process_name_escaped=$(echo "$process_name" | sed 's/\\/\\\\/g; s/"/\\"/g')
            process_user_escaped=$(echo "$process_user" | sed 's/\\/\\\\/g; s/"/\\"/g')
            
            # Ajouter à la liste JSON
            connections_json="$connections_json{\"protocol\":\"$protocol\",\"local_address\":\"$local_addr_escaped\",\"local_port\":${local_port:-0},\"remote_address\":\"$remote_addr_escaped\",\"remote_port\":${remote_port:-0},\"state\":\"$state\",\"process\":{\"pid\":$pid,\"name\":\"$process_name_escaped\",\"user\":\"$process_user_escaped\"}},"
            
            ((total_connections++))
            
        done <<< "$ss_output"
    fi
    
    echo "$connections_json|$total_connections"
}

parse_netstat_output() {
    local protocol="$1"
    local connections_json=""
    local total_connections=0
    
    log_debug "Analyse sortie netstat pour protocole: $protocol"
    
    # Construire la commande netstat
    local netstat_cmd="netstat"
    local netstat_args=("-n")  # Pas de résolution DNS
    
    case $protocol in
        "tcp") netstat_args+=("-t") ;;
        "udp") netstat_args+=("-u") ;;
        "tcp6") netstat_args+=("-t" "-6") ;;
        "udp6") netstat_args+=("-u" "-6") ;;
    esac
    
    if [[ $LISTENING_ONLY -eq 1 ]]; then
        netstat_args+=("-l")
    elif [[ $ESTABLISHED_ONLY -eq 1 ]]; then
        netstat_args+=("-e")
    fi
    
    if [[ $SHOW_PROCESSES -eq 1 ]]; then
        netstat_args+=("-p")
    fi
    
    # Exécuter netstat et parser
    local netstat_output
    if netstat_output=$("$netstat_cmd" "${netstat_args[@]}" 2>/dev/null); then
        while IFS= read -r line; do
            # Ignorer les en-têtes et lignes vides
            if [[ $line =~ ^(Proto|Active|tcp|udp) ]] || [[ -z "$line" ]] || [[ $line =~ ^total ]]; then
                if [[ ! $line =~ ^(tcp|udp) ]]; then
                    continue
                fi
            fi
            
            # Parser ligne netstat
            local proto local_full remote_full state process_info
            if [[ $line =~ ^([a-z0-9]+)[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)(.*)$ ]]; then
                proto="${BASH_REMATCH[1]}"
                local_full="${BASH_REMATCH[2]}"
                remote_full="${BASH_REMATCH[3]}"
                state="${BASH_REMATCH[4]}"
                process_info="${BASH_REMATCH[5]}"
            fi
            
            # Ignorer si pas le bon protocole
            if [[ "$proto" != "$protocol" ]]; then
                continue
            fi
            
            # Parser adresse:port locale et distante
            local local_addr local_port remote_addr remote_port
            if [[ $local_full =~ ^(.*):([0-9]+)$ ]]; then
                local_addr="${BASH_REMATCH[1]}"
                local_port="${BASH_REMATCH[2]}"
            fi
            
            if [[ $remote_full =~ ^(.*):([0-9]+)$ ]]; then
                remote_addr="${BASH_REMATCH[1]}"
                remote_port="${BASH_REMATCH[2]}"
            fi
            
            # Appliquer filtres (même logique que ss)
            local skip=false
            
            if [[ -n "$FILTER_PORT" ]]; then
                if [[ "$local_port" != "$FILTER_PORT" && "$remote_port" != "$FILTER_PORT" ]]; then
                    skip=true
                fi
            fi
            
            if [[ -n "$FILTER_IP" ]]; then
                if [[ "$local_addr" != *"$FILTER_IP"* && "$remote_addr" != *"$FILTER_IP"* ]]; then
                    skip=true
                fi
            fi
            
            if [[ $skip == true ]]; then
                continue
            fi
            
            # Parser infos processus pour netstat
            local pid="0" process_name="unknown" process_user="unknown"
            if [[ $SHOW_PROCESSES -eq 1 && -n "$process_info" ]]; then
                if [[ $process_info =~ ([0-9]+)/([^[:space:]]+) ]]; then
                    pid="${BASH_REMATCH[1]}"
                    process_name="${BASH_REMATCH[2]}"
                    
                    # Récupérer utilisateur
                    local proc_info
                    proc_info=$(get_process_info "$pid")
                    IFS='|' read -r _ process_user <<< "$proc_info"
                fi
            fi
            
            # Nettoyer adresses
            [[ "$local_addr" == "*" ]] && local_addr="0.0.0.0"
            [[ "$remote_addr" == "*" ]] && remote_addr="0.0.0.0"
            
            # Échapper pour JSON
            local local_addr_escaped remote_addr_escaped process_name_escaped process_user_escaped
            local_addr_escaped=$(echo "$local_addr" | sed 's/\\/\\\\/g; s/"/\\"/g')
            remote_addr_escaped=$(echo "$remote_addr" | sed 's/\\/\\\\/g; s/"/\\"/g')
            process_name_escaped=$(echo "$process_name" | sed 's/\\/\\\\/g; s/"/\\"/g')
            process_user_escaped=$(echo "$process_user" | sed 's/\\/\\\\/g; s/"/\\"/g')
            
            # Ajouter à la liste JSON
            connections_json="$connections_json{\"protocol\":\"$protocol\",\"local_address\":\"$local_addr_escaped\",\"local_port\":${local_port:-0},\"remote_address\":\"$remote_addr_escaped\",\"remote_port\":${remote_port:-0},\"state\":\"$state\",\"process\":{\"pid\":$pid,\"name\":\"$process_name_escaped\",\"user\":\"$process_user_escaped\"}},"
            
            ((total_connections++))
            
        done <<< "$netstat_output"
    fi
    
    echo "$connections_json|$total_connections"
}

get_listening_ports_summary() {
    local connections_json="$1"
    local listening_json=""
    
    # Parser les connexions pour extraire les ports en écoute
    # (état LISTEN pour TCP, ou adresse locale != 0.0.0.0 pour UDP)
    
    echo "[]"  # Simplifié pour cet exemple
}

list_network_connections() {
    log_debug "Listage des connexions réseau"
    
    local all_connections_json=""
    local total_tcp=0 total_udp=0 total_tcp6=0 total_udp6=0
    local total_connections=0
    local listening_count=0 established_count=0
    local protocols_used=()
    
    # Déterminer quels protocoles traiter
    local protocols_to_check=()
    
    if [[ $UDP_ONLY -eq 0 ]]; then
        protocols_to_check+=("tcp")
        if command -v ss >/dev/null 2>&1 || command -v netstat >/dev/null 2>&1; then
            protocols_to_check+=("tcp6")
        fi
    fi
    
    if [[ $TCP_ONLY -eq 0 ]]; then
        protocols_to_check+=("udp")
        if command -v ss >/dev/null 2>&1 || command -v netstat >/dev/null 2>&1; then
            protocols_to_check+=("udp6")
        fi
    fi
    
    # Utiliser ss si disponible, sinon netstat
    local use_ss=false
    if command -v ss >/dev/null 2>&1; then
        use_ss=true
        log_debug "Utilisation de ss pour lister les connexions"
    elif command -v netstat >/dev/null 2>&1; then
        log_debug "Utilisation de netstat pour lister les connexions"
    else
        die "Aucun outil de listage réseau disponible (ss ou netstat requis)" 3
    fi
    
    # Traiter chaque protocole
    for protocol in "${protocols_to_check[@]}"; do
        log_info "Analyse protocole $protocol..."
        
        local result connections_json count
        if [[ $use_ss == true ]]; then
            result=$(parse_ss_output "$protocol")
        else
            result=$(parse_netstat_output "$protocol")
        fi
        
        IFS='|' read -r connections_json count <<< "$result"
        
        if [[ $count -gt 0 ]]; then
            protocols_used+=("$protocol")
            all_connections_json="$all_connections_json$connections_json"
            
            case $protocol in
                "tcp") total_tcp=$count ;;
                "udp") total_udp=$count ;;
                "tcp6") total_tcp6=$count ;;
                "udp6") total_udp6=$count ;;
            esac
            
            ((total_connections += count))
        fi
    done
    
    # Compter états spécifiques dans toutes les connexions
    if [[ -n "$all_connections_json" ]]; then
        listening_count=$(echo "$all_connections_json" | grep -o '"state":"LISTEN"' | wc -l)
        established_count=$(echo "$all_connections_json" | grep -o '"state":"ESTABLISHED"' | wc -l)
    fi
    
    # Retirer virgule finale
    all_connections_json="[${all_connections_json%,}]"
    
    # Préparer liste des protocoles pour JSON
    local protocols_json=""
    for protocol in "${protocols_used[@]}"; do
        protocols_json="$protocols_json\"$protocol\","
    done
    protocols_json="[${protocols_json%,}]"
    
    # Générer résumé des ports en écoute
    local listening_ports_json
    listening_ports_json=$(get_listening_ports_summary "$all_connections_json")
    
    # Réponse JSON finale
    local message="Network connections listed successfully"
    if [[ $total_connections -eq 0 ]]; then
        message="No network connections found matching criteria"
    fi
    
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "$message",
  "data": {
    "connections": $all_connections_json,
    "summary": {
      "total_connections": $total_connections,
      "tcp_connections": $((total_tcp + total_tcp6)),
      "udp_connections": $((total_udp + total_udp6)),
      "ipv4_connections": $((total_tcp + total_udp)),
      "ipv6_connections": $((total_tcp6 + total_udp6)),
      "listening_ports": $listening_count,
      "established_connections": $established_count,
      "protocols": $protocols_json
    },
    "listening_ports": $listening_ports_json,
    "filters_applied": {
      "port": "${FILTER_PORT:-none}",
      "ip": "${FILTER_IP:-none}",
      "listening_only": $([ $LISTENING_ONLY -eq 1 ] && echo "true" || echo "false"),
      "established_only": $([ $ESTABLISHED_ONLY -eq 1 ] && echo "true" || echo "false"),
      "tcp_only": $([ $TCP_ONLY -eq 1 ] && echo "true" || echo "false"),
      "udp_only": $([ $UDP_ONLY -eq 1 ] && echo "true" || echo "false"),
      "show_processes": $([ $SHOW_PROCESSES -eq 1 ] && echo "true" || echo "false")
    },
    "scan_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": [],
  "warnings": []
}
EOF
    
    # Code de sortie selon résultats
    if [[ $total_connections -eq 0 ]]; then
        exit 4  # Aucune connexion trouvée
    fi
    
    log_debug "Listage terminé - $total_connections connexion(s) trouvée(s)"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    list_network_connections
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi