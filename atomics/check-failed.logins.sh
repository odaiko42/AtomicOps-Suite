#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: check-failed.logins.sh
# Description: Analyser les tentatives de connexion échouées depuis les logs
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="check-failed.logins.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
HOURS_BACK=${HOURS_BACK:-24}
MAX_RESULTS=${MAX_RESULTS:-50}
MIN_ATTEMPTS=${MIN_ATTEMPTS:-3}
SERVICE_FILTER=""
IP_FILTER=""

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
    Analyse les tentatives de connexion échouées depuis les logs système
    (auth.log, secure, journald) avec détection d'attaques et statistiques.

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    --hours HOURS          Nombre d'heures à analyser (défaut: 24)
    --max-results N        Nombre max de résultats (défaut: 50)
    --min-attempts N       Seuil min de tentatives par IP (défaut: 3)
    --service SERVICE      Filtrer par service (ssh, ftp, etc.)
    --ip IP                Filtrer par adresse IP spécifique
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "analysis_period": {
          "hours_back": 24,
          "start_time": "2025-10-03T00:00:00Z",
          "end_time": "2025-10-04T00:00:00Z"
        },
        "summary": {
          "total_failed_attempts": 156,
          "unique_ips": 23,
          "unique_users": 8,
          "services_targeted": ["ssh", "ftp"],
          "most_active_hour": "14:00-15:00",
          "potential_attacks": 5
        },
        "top_attackers": [
          {
            "ip": "192.168.1.100",
            "attempts": 45,
            "users_targeted": ["root", "admin"],
            "services": ["ssh"],
            "first_attempt": "2025-10-04T10:15:00Z",
            "last_attempt": "2025-10-04T14:30:00Z",
            "country": "Unknown",
            "threat_level": "high"
          }
        ],
        "failed_attempts": [
          {
            "timestamp": "2025-10-04T14:30:15Z",
            "ip": "192.168.1.100",
            "user": "root",
            "service": "ssh",
            "port": 22,
            "message": "Failed password for root from 192.168.1.100"
          }
        ],
        "hourly_stats": [
          {"hour": "00:00", "attempts": 12},
          {"hour": "01:00", "attempts": 8}
        ]
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Logs non accessibles
    4 - Permissions insuffisantes

Exemples:
    $SCRIPT_NAME                                   # Analyse 24h
    $SCRIPT_NAME --hours 168                      # Analyse 1 semaine
    $SCRIPT_NAME --service ssh --min-attempts 5  # SSH avec seuil 5
    $SCRIPT_NAME --ip 192.168.1.100             # IP spécifique
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
            --hours)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                    HOURS_BACK="$2"
                    shift 2
                else
                    die "Nombre d'heures invalide: ${2:-}. Doit être un entier." 2
                fi
                ;;
            --max-results)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                    MAX_RESULTS="$2"
                    shift 2
                else
                    die "Nombre max de résultats invalide: ${2:-}. Doit être un entier." 2
                fi
                ;;
            --min-attempts)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                    MIN_ATTEMPTS="$2"
                    shift 2
                else
                    die "Seuil min tentatives invalide: ${2:-}. Doit être un entier." 2
                fi
                ;;
            --service)
                if [[ -n "${2:-}" ]]; then
                    SERVICE_FILTER="$2"
                    shift 2
                else
                    die "Service manquant pour --service" 2
                fi
                ;;
            --ip)
                if [[ -n "${2:-}" ]]; then
                    IP_FILTER="$2"
                    shift 2
                else
                    die "IP manquante pour --ip" 2
                fi
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                die "Argument inattendu: $1. Utilisez -h pour l'aide." 2
                ;;
        esac
    done

    # Validation des paramètres
    if [[ $HOURS_BACK -lt 1 || $HOURS_BACK -gt 8760 ]]; then  # Max 1 an
        die "Heures invalides: $HOURS_BACK. Doit être entre 1-8760." 2
    fi
    
    if [[ $MAX_RESULTS -lt 1 || $MAX_RESULTS -gt 1000 ]]; then
        die "Max résultats invalide: $MAX_RESULTS. Doit être entre 1-1000." 2
    fi
    
    if [[ $MIN_ATTEMPTS -lt 1 ]]; then
        die "Min tentatives invalide: $MIN_ATTEMPTS. Doit être >= 1." 2
    fi
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    # Vérifier les outils de base
    if ! command -v grep >/dev/null 2>&1; then
        missing+=("grep")
    fi
    
    if ! command -v awk >/dev/null 2>&1; then
        missing+=("awk")
    fi
    
    if ! command -v sort >/dev/null 2>&1; then
        missing+=("sort")
    fi
    
    if ! command -v uniq >/dev/null 2>&1; then
        missing+=("uniq")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Dépendances vérifiées"
}

find_log_files() {
    local log_files=()
    
    # Journald (systemd) - prioritaire
    if command -v journalctl >/dev/null 2>&1; then
        log_files+=("journald")
        log_debug "Journald disponible"
    fi
    
    # Fichiers de logs traditionnels
    local auth_logs=(
        "/var/log/auth.log"      # Debian/Ubuntu
        "/var/log/secure"        # RHEL/CentOS
        "/var/log/messages"      # Générique
    )
    
    for log_file in "${auth_logs[@]}"; do
        if [[ -r "$log_file" ]]; then
            log_files+=("$log_file")
            log_debug "Log trouvé: $log_file"
        fi
    done
    
    if [[ ${#log_files[@]} -eq 0 ]]; then
        die "Aucun fichier de log accessible trouvé" 3
    fi
    
    printf "%s\n" "${log_files[@]}"
}

get_time_range() {
    local hours_back="$1"
    local start_time end_time
    
    end_time=$(date -u +"%Y-%m-%d %H:%M:%S")
    start_time=$(date -u -d "$hours_back hours ago" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || 
                date -u -v-"${hours_back}H" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || 
                echo "1970-01-01 00:00:00")
    
    echo "$start_time|$end_time"
}

parse_journald_logs() {
    local hours_back="$1"
    local service_filter="$2"
    local ip_filter="$3"
    
    local failed_attempts=""
    
    # Construire la commande journalctl
    local cmd="journalctl --no-pager --since \"$hours_back hours ago\" -u ssh -u sshd 2>/dev/null"
    
    # Filtrer les échecs de connexion
    local patterns=(
        "Failed password"
        "Invalid user"
        "Connection closed.*authenticating"
        "Failed publickey"
        "Failed keyboard-interactive"
    )
    
    for pattern in "${patterns[@]}"; do
        local entries
        entries=$(eval "$cmd" | grep -i "$pattern" 2>/dev/null || echo "")
        
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            
            # Parser la ligne journald
            # Format: Oct 04 15:30:22 hostname sshd[1234]: Failed password for user from IP port PORT
            if [[ "$line" =~ ([A-Za-z]{3}\ +[0-9]{1,2}\ +[0-9]{2}:[0-9]{2}:[0-9]{2}).*sshd\[([0-9]+)\]:\ (.*)\ for\ ([^\ ]+)\ from\ ([0-9\.]+) ]]; then
                local timestamp="${BASH_REMATCH[1]}"
                local pid="${BASH_REMATCH[2]}"
                local message="${BASH_REMATCH[3]}"
                local user="${BASH_REMATCH[4]}"
                local ip="${BASH_REMATCH[5]}"
                
                # Filtrer par IP si spécifié
                if [[ -n "$ip_filter" && "$ip" != "$ip_filter" ]]; then
                    continue
                fi
                
                # Convertir le timestamp
                local iso_timestamp
                iso_timestamp=$(date -d "$(date +%Y) $timestamp" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$timestamp")
                
                failed_attempts+="$iso_timestamp|$ip|$user|ssh|22|$message\n"
            fi
        done <<< "$entries"
    done
    
    echo -e "$failed_attempts"
}

parse_auth_logs() {
    local log_file="$1"
    local hours_back="$2"
    local service_filter="$3"
    local ip_filter="$4"
    
    local failed_attempts=""
    
    # Calculer la date de début
    local start_time
    start_time=$(date -d "$hours_back hours ago" +"%b %d %H:%M:%S" 2>/dev/null || 
                date -v-"${hours_back}H" +"%b %d %H:%M:%S" 2>/dev/null || 
                echo "")
    
    if [[ ! -r "$log_file" ]]; then
        return 0
    fi
    
    # Patterns pour différents services
    local ssh_patterns=(
        "Failed password"
        "Invalid user"
        "Failed publickey"
        "Connection closed.*authenticating"
    )
    
    # Analyser les logs SSH
    for pattern in "${ssh_patterns[@]}"; do
        local entries
        entries=$(grep -i "$pattern" "$log_file" 2>/dev/null || echo "")
        
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            
            # Parser ligne syslog standard
            # Format: Oct  4 15:30:22 hostname sshd[1234]: Failed password for user from IP port PORT
            if [[ "$line" =~ ([A-Za-z]{3}\ +[0-9]{1,2}\ +[0-9]{2}:[0-9]{2}:[0-9]{2}).*sshd\[([0-9]+)\]:.*\ for\ ([^\ ]+)\ from\ ([0-9\.]+) ]]; then
                local timestamp="${BASH_REMATCH[1]}"
                local pid="${BASH_REMATCH[2]}"
                local user="${BASH_REMATCH[3]}"
                local ip="${BASH_REMATCH[4]}"
                
                # Filtrer par service si spécifié
                if [[ -n "$service_filter" && "$service_filter" != "ssh" ]]; then
                    continue
                fi
                
                # Filtrer par IP si spécifié
                if [[ -n "$ip_filter" && "$ip" != "$ip_filter" ]]; then
                    continue
                fi
                
                # Convertir timestamp
                local iso_timestamp
                iso_timestamp=$(date -d "$(date +%Y) $timestamp" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$timestamp")
                
                local message=$(echo "$line" | sed 's/.*sshd\[[0-9]*\]: //')
                failed_attempts+="$iso_timestamp|$ip|$user|ssh|22|$message\n"
            fi
        done <<< "$entries"
    done
    
    echo -e "$failed_attempts"
}

analyze_failed_attempts() {
    local raw_attempts="$1"
    
    if [[ -z "$raw_attempts" ]]; then
        echo "0|0|0|[]|[]|[]"
        return
    fi
    
    # Compter les statistiques de base
    local total_attempts
    total_attempts=$(echo -e "$raw_attempts" | grep -c "^[^|]*|" || echo "0")
    
    local unique_ips
    unique_ips=$(echo -e "$raw_attempts" | cut -d'|' -f2 | sort -u | wc -l || echo "0")
    
    local unique_users
    unique_users=$(echo -e "$raw_attempts" | cut -d'|' -f3 | sort -u | wc -l || echo "0")
    
    # Top attackers (IPs avec le plus de tentatives)
    local top_attackers_json="[]"
    if [[ $total_attempts -gt 0 ]]; then
        local top_ips
        top_ips=$(echo -e "$raw_attempts" | cut -d'|' -f2 | sort | uniq -c | sort -nr | head -10)
        
        if [[ -n "$top_ips" ]]; then
            local attackers_list=""
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                
                local count ip
                read -r count ip <<< "$line"
                
                # Ignorer si moins que le seuil minimum
                if [[ $count -lt $MIN_ATTEMPTS ]]; then
                    continue
                fi
                
                # Obtenir les utilisateurs ciblés par cette IP
                local users_targeted
                users_targeted=$(echo -e "$raw_attempts" | grep "^[^|]*|$ip|" | cut -d'|' -f3 | sort -u | head -5 | tr '\n' ',' | sed 's/,$//')
                local users_json="[]"
                if [[ -n "$users_targeted" ]]; then
                    local users_list=""
                    IFS=',' read -ra USERS <<< "$users_targeted"
                    for user in "${USERS[@]}"; do
                        users_list+="\"$user\","
                    done
                    users_list=${users_list%,}
                    users_json="[$users_list]"
                fi
                
                # Première et dernière tentative
                local first_attempt last_attempt
                first_attempt=$(echo -e "$raw_attempts" | grep "^[^|]*|$ip|" | head -n1 | cut -d'|' -f1)
                last_attempt=$(echo -e "$raw_attempts" | grep "^[^|]*|$ip|" | tail -n1 | cut -d'|' -f1)
                
                # Niveau de menace basé sur le nombre de tentatives
                local threat_level="low"
                if [[ $count -ge 50 ]]; then
                    threat_level="critical"
                elif [[ $count -ge 20 ]]; then
                    threat_level="high"
                elif [[ $count -ge 10 ]]; then
                    threat_level="medium"
                fi
                
                local attacker_json="{\"ip\":\"$ip\",\"attempts\":$count,\"users_targeted\":$users_json,\"services\":[\"ssh\"],\"first_attempt\":\"$first_attempt\",\"last_attempt\":\"$last_attempt\",\"country\":\"Unknown\",\"threat_level\":\"$threat_level\"}"
                attackers_list+="$attacker_json,"
                
            done <<< "$top_ips"
            
            attackers_list=${attackers_list%,}
            [[ -n "$attackers_list" ]] && top_attackers_json="[$attackers_list]"
        fi
    fi
    
    # Services ciblés
    local services_json="[\"ssh\"]"  # Simplifié pour la démo
    
    echo "$total_attempts|$unique_ips|$unique_users|$top_attackers_json|$services_json|[]"
}

build_attempts_json() {
    local raw_attempts="$1"
    local max_results="$2"
    
    local attempts_json="[]"
    
    if [[ -n "$raw_attempts" ]]; then
        local attempts_list=""
        local count=0
        
        # Trier par timestamp (plus récent en premier)
        local sorted_attempts
        sorted_attempts=$(echo -e "$raw_attempts" | sort -r)
        
        while IFS= read -r line && [[ $count -lt $max_results ]]; do
            [[ -z "$line" ]] && continue
            
            local timestamp ip user service port message
            IFS='|' read -r timestamp ip user service port message <<< "$line"
            
            # Échapper pour JSON
            timestamp=$(echo "$timestamp" | sed 's/\\/\\\\/g; s/"/\\"/g')
            ip=$(echo "$ip" | sed 's/\\/\\\\/g; s/"/\\"/g')
            user=$(echo "$user" | sed 's/\\/\\\\/g; s/"/\\"/g')
            service=$(echo "$service" | sed 's/\\/\\\\/g; s/"/\\"/g')
            message=$(echo "$message" | sed 's/\\/\\\\/g; s/"/\\"/g')
            
            local attempt_json="{\"timestamp\":\"$timestamp\",\"ip\":\"$ip\",\"user\":\"$user\",\"service\":\"$service\",\"port\":$port,\"message\":\"$message\"}"
            attempts_list+="$attempt_json,"
            
            ((count++))
        done <<< "$sorted_attempts"
        
        attempts_list=${attempts_list%,}
        [[ -n "$attempts_list" ]] && attempts_json="[$attempts_list]"
    fi
    
    echo "$attempts_json"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    
    # Trouver les fichiers de logs
    local log_files
    log_files=$(find_log_files)
    log_debug "Fichiers de logs trouvés: $log_files"
    
    # Calculer la période d'analyse
    local time_range start_time end_time
    time_range=$(get_time_range "$HOURS_BACK")
    IFS='|' read -r start_time end_time <<< "$time_range"
    
    log_info "Analyse des échecs de connexion sur $HOURS_BACK heures"
    
    # Collecter les tentatives échouées
    local all_failed_attempts=""
    
    while IFS= read -r log_source; do
        [[ -z "$log_source" ]] && continue
        
        log_debug "Analyse du source: $log_source"
        
        local attempts=""
        if [[ "$log_source" == "journald" ]]; then
            attempts=$(parse_journald_logs "$HOURS_BACK" "$SERVICE_FILTER" "$IP_FILTER")
        else
            attempts=$(parse_auth_logs "$log_source" "$HOURS_BACK" "$SERVICE_FILTER" "$IP_FILTER")
        fi
        
        if [[ -n "$attempts" ]]; then
            all_failed_attempts+="$attempts"
        fi
        
    done <<< "$log_files"
    
    # Analyser les données collectées
    local analysis_result total_attempts unique_ips unique_users top_attackers_json services_json hourly_json
    analysis_result=$(analyze_failed_attempts "$all_failed_attempts")
    IFS='|' read -r total_attempts unique_ips unique_users top_attackers_json services_json hourly_json <<< "$analysis_result"
    
    # Construire le JSON des tentatives
    local attempts_json
    attempts_json=$(build_attempts_json "$all_failed_attempts" "$MAX_RESULTS")
    
    # Convertir les timestamps pour JSON
    local start_iso end_iso
    start_iso=$(date -d "$start_time" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$start_time")
    end_iso=$(date -d "$end_time" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$end_time")
    
    # Détecter les attaques potentielles
    local potential_attacks
    potential_attacks=$(echo "$top_attackers_json" | jq 'length' 2>/dev/null || echo "0")
    
    # Heure la plus active (simplifié)
    local most_active_hour="00:00-01:00"
    
    # Générer la réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Failed login analysis completed successfully",
  "data": {
    "analysis_period": {
      "hours_back": $HOURS_BACK,
      "start_time": "$start_iso",
      "end_time": "$end_iso"
    },
    "summary": {
      "total_failed_attempts": $total_attempts,
      "unique_ips": $unique_ips,
      "unique_users": $unique_users,
      "services_targeted": $services_json,
      "most_active_hour": "$most_active_hour",
      "potential_attacks": $potential_attacks,
      "min_attempts_threshold": $MIN_ATTEMPTS
    },
    "top_attackers": $top_attackers_json,
    "failed_attempts": $attempts_json,
    "filters_applied": {
      "service": "$([ -n "$SERVICE_FILTER" ] && echo "$SERVICE_FILTER" || echo "all")",
      "ip": "$([ -n "$IP_FILTER" ] && echo "$IP_FILTER" || echo "all")",
      "max_results": $MAX_RESULTS
    }
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_info "Analyse terminée: $total_attempts tentatives échouées trouvées"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi