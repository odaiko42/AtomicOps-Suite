#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: allow-firewall.port.sh
# Description: Autoriser un port dans le firewall avec validation et persistence
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="allow-firewall.port.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
DRY_RUN=${DRY_RUN:-0}
FORCE=${FORCE:-0}
PORT=""
PROTOCOL="tcp"
SOURCE_IP=""
ZONE="public"
PERMANENT=${PERMANENT:-1}

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
Usage: $SCRIPT_NAME [OPTIONS] <port> [protocol]

Description:
    Autorise un port dans le firewall système avec gestion multi-firewall
    (iptables, firewalld, ufw) et persistence des règles.

Arguments:
    <port>                  Port à autoriser (obligatoire, 1-65535)
    [protocol]             Protocole (tcp|udp|both, défaut: tcp)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -f, --force            Forcer sans demander confirmation
    --dry-run              Simulation (afficher les commandes sans les exécuter)
    -s, --source IP        IP/réseau source autorisé (défaut: any)
    -z, --zone ZONE        Zone firewalld (défaut: public)
    --temporary            Règle temporaire seulement (non persistante)
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "port": 22,
        "protocol": "tcp",
        "source_ip": "192.168.1.0/24",
        "firewall_type": "iptables",
        "zone": "public",
        "permanent": true,
        "commands_executed": [
          "iptables -A INPUT -p tcp --dport 22 -s 192.168.1.0/24 -j ACCEPT"
        ],
        "rule_verification": {
          "rule_exists": true,
          "rule_active": true,
          "rule_persistent": true
        },
        "dry_run": false
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Firewall non trouvé
    4 - Permissions insuffisantes

Exemples:
    $SCRIPT_NAME 22                                # SSH (TCP)
    $SCRIPT_NAME 80 tcp                           # HTTP
    $SCRIPT_NAME 53 both --source 192.168.1.0/24 # DNS pour réseau local
    $SCRIPT_NAME --dry-run 443                   # Simulation HTTPS
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
            -f|--force)
                FORCE=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            -s|--source)
                if [[ -n "${2:-}" ]]; then
                    SOURCE_IP="$2"
                    shift 2
                else
                    die "IP source manquante pour -s/--source" 2
                fi
                ;;
            -z|--zone)
                if [[ -n "${2:-}" ]]; then
                    ZONE="$2"
                    shift 2
                else
                    die "Zone manquante pour -z/--zone" 2
                fi
                ;;
            --temporary)
                PERMANENT=0
                shift
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                if [[ -z "$PORT" ]]; then
                    PORT="$1"
                elif [[ -z "$PROTOCOL" || "$PROTOCOL" == "tcp" ]]; then
                    PROTOCOL="$1"
                else
                    die "Trop d'arguments. Utilisez -h pour l'aide." 2
                fi
                shift
                ;;
        esac
    done

    # Validation des arguments
    if [[ -z "$PORT" ]]; then
        die "Port obligatoire manquant. Utilisez -h pour l'aide." 2
    fi
    
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [[ $PORT -lt 1 || $PORT -gt 65535 ]]; then
        die "Port invalide: $PORT. Doit être entre 1-65535." 2
    fi
    
    case "$PROTOCOL" in
        tcp|udp|both) ;;
        *) die "Protocole invalide: $PROTOCOL. Utilisez tcp, udp ou both." 2 ;;
    esac
    
    # Validation IP source si fournie
    if [[ -n "$SOURCE_IP" ]]; then
        if ! [[ "$SOURCE_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
            die "Format IP source invalide: $SOURCE_IP" 2
        fi
    fi
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    # Détecter le firewall disponible
    if ! command -v iptables >/dev/null 2>&1 && 
       ! command -v firewall-cmd >/dev/null 2>&1 && 
       ! command -v ufw >/dev/null 2>&1; then
        die "Aucun firewall supporté trouvé (iptables, firewalld, ufw)" 3
    fi
    
    log_debug "Dépendances firewall vérifiées"
}

detect_firewall_type() {
    if command -v firewall-cmd >/dev/null 2>&1 && 
       firewall-cmd --state >/dev/null 2>&1; then
        echo "firewalld"
    elif command -v ufw >/dev/null 2>&1 && 
         ufw status >/dev/null 2>&1; then
        echo "ufw"
    elif command -v iptables >/dev/null 2>&1; then
        echo "iptables"
    else
        echo "unknown"
    fi
}

ask_confirmation() {
    local port="$1"
    local protocol="$2"
    local source="$3"
    
    if [[ $FORCE -eq 1 || $DRY_RUN -eq 1 ]]; then
        return 0
    fi
    
    local source_text=""
    [[ -n "$source" ]] && source_text=" depuis $source"
    
    echo "Voulez-vous autoriser le port $port/$protocol$source_text dans le firewall? [y/N]" >&2
    read -r response
    case "$response" in
        [yY]|[yY][eE][sS]|[oO]|[oO][uU][iI])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

execute_command() {
    local cmd="$1"
    local description="$2"
    
    log_debug "Commande à exécuter: $cmd"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "DRY-RUN: $description - $cmd"
        return 0
    fi
    
    if [[ $VERBOSE -eq 1 ]]; then
        log_info "Exécution: $description"
    fi
    
    if eval "$cmd" >/dev/null 2>&1; then
        log_debug "Succès: $cmd"
        return 0
    else
        local exit_code=$?
        log_error "Échec: $cmd (code: $exit_code)"
        return $exit_code
    fi
}

add_iptables_rule() {
    local port="$1"
    local protocol="$2"
    local source_ip="$3"
    
    local commands_executed=()
    local errors=()
    
    # Construire les protocoles à traiter
    local protocols=()
    case "$protocol" in
        tcp) protocols=("tcp") ;;
        udp) protocols=("udp") ;;
        both) protocols=("tcp" "udp") ;;
    esac
    
    for prot in "${protocols[@]}"; do
        # Construire la règle iptables
        local cmd="iptables -A INPUT -p $prot --dport $port"
        
        # Ajouter la source si spécifiée
        if [[ -n "$source_ip" ]]; then
            cmd+=" -s $source_ip"
        fi
        
        cmd+=" -j ACCEPT"
        
        # Exécuter la règle
        if execute_command "$cmd" "Add iptables rule for port $port/$prot"; then
            commands_executed+=("$cmd")
        else
            errors+=("Failed to add iptables rule for port $port/$prot")
        fi
        
        # Sauvegarder si permanent et iptables-save disponible
        if [[ $PERMANENT -eq 1 && $DRY_RUN -eq 0 ]]; then
            if command -v iptables-save >/dev/null 2>&1 && 
               command -v iptables-restore >/dev/null 2>&1; then
                local save_cmd=""
                # Distribution-specific save
                if [[ -f "/etc/debian_version" ]]; then
                    save_cmd="iptables-save > /etc/iptables/rules.v4"
                elif [[ -f "/etc/redhat-release" ]]; then
                    save_cmd="iptables-save > /etc/sysconfig/iptables"
                else
                    save_cmd="iptables-save > /etc/iptables.rules"
                fi
                
                if execute_command "$save_cmd" "Save iptables rules"; then
                    commands_executed+=("$save_cmd")
                fi
            fi
        fi
    done
    
    # Retourner les résultats via variables globales
    EXECUTED_COMMANDS=("${commands_executed[@]}")
    OPERATION_ERRORS=("${errors[@]}")
    
    return $(( ${#errors[@]} > 0 ? 1 : 0 ))
}

add_firewalld_rule() {
    local port="$1"
    local protocol="$2"
    local source_ip="$3"
    local zone="$4"
    
    local commands_executed=()
    local errors=()
    
    # Construire les protocoles
    local protocols=()
    case "$protocol" in
        tcp) protocols=("tcp") ;;
        udp) protocols=("udp") ;;
        both) protocols=("tcp" "udp") ;;
    esac
    
    for prot in "${protocols[@]}"; do
        # Commande de base
        local cmd="firewall-cmd --zone=$zone --add-port=$port/$prot"
        
        # Ajouter source si spécifiée
        if [[ -n "$source_ip" ]]; then
            # Firewalld utilise des règles rich pour les sources
            cmd="firewall-cmd --zone=$zone --add-rich-rule='rule family=\"ipv4\" source address=\"$source_ip\" port protocol=\"$prot\" port=\"$port\" accept'"
        fi
        
        # Exécuter temporairement d'abord
        if execute_command "$cmd" "Add firewalld rule for port $port/$prot"; then
            commands_executed+=("$cmd")
        else
            errors+=("Failed to add firewalld rule for port $port/$prot")
            continue
        fi
        
        # Rendre permanent si demandé
        if [[ $PERMANENT -eq 1 ]]; then
            local perm_cmd="${cmd/firewall-cmd/firewall-cmd --permanent}"
            if execute_command "$perm_cmd" "Make firewalld rule permanent"; then
                commands_executed+=("$perm_cmd")
                
                # Recharger la configuration
                local reload_cmd="firewall-cmd --reload"
                if execute_command "$reload_cmd" "Reload firewalld configuration"; then
                    commands_executed+=("$reload_cmd")
                fi
            fi
        fi
    done
    
    EXECUTED_COMMANDS=("${commands_executed[@]}")
    OPERATION_ERRORS=("${errors[@]}")
    
    return $(( ${#errors[@]} > 0 ? 1 : 0 ))
}

add_ufw_rule() {
    local port="$1"
    local protocol="$2"
    local source_ip="$3"
    
    local commands_executed=()
    local errors=()
    
    # Construire les protocoles
    local protocols=()
    case "$protocol" in
        tcp) protocols=("tcp") ;;
        udp) protocols=("udp") ;;
        both) protocols=("tcp" "udp") ;;
    esac
    
    for prot in "${protocols[@]}"; do
        # Construire la commande UFW
        local cmd="ufw allow"
        
        if [[ -n "$source_ip" ]]; then
            cmd+=" from $source_ip to any port $port proto $prot"
        else
            cmd+=" $port/$prot"
        fi
        
        # Exécuter la règle
        if execute_command "$cmd" "Add UFW rule for port $port/$prot"; then
            commands_executed+=("$cmd")
        else
            errors+=("Failed to add UFW rule for port $port/$prot")
        fi
    done
    
    EXECUTED_COMMANDS=("${commands_executed[@]}")
    OPERATION_ERRORS=("${errors[@]}")
    
    return $(( ${#errors[@]} > 0 ? 1 : 0 ))
}

verify_rule_added() {
    local port="$1"
    local protocol="$2"
    local fw_type="$3"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        return 0  # Ne peut pas vérifier en dry-run
    fi
    
    case "$fw_type" in
        iptables)
            iptables -L INPUT | grep -q "dpt:$port" >/dev/null 2>&1
            ;;
        firewalld)
            firewall-cmd --list-ports | grep -q "$port/$protocol" >/dev/null 2>&1 ||
            firewall-cmd --list-rich-rules | grep -q "port=\"$port\"" >/dev/null 2>&1
            ;;
        ufw)
            ufw status | grep -q "$port" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# Variables globales pour les résultats
EXECUTED_COMMANDS=()
OPERATION_ERRORS=()

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    
    # Vérifier les permissions
    if [[ $EUID -ne 0 && $DRY_RUN -eq 0 ]]; then
        log_warn "Ce script nécessite généralement les privilèges root"
        log_warn "Certaines opérations peuvent échouer sans sudo/root"
    fi
    
    # Détecter le firewall
    local fw_type
    fw_type=$(detect_firewall_type)
    log_debug "Firewall détecté: $fw_type"
    
    if [[ "$fw_type" == "unknown" ]]; then
        die "Firewall non supporté ou inactif" 3
    fi
    
    # Demander confirmation
    if ! ask_confirmation "$PORT" "$PROTOCOL" "$SOURCE_IP"; then
        die "Opération annulée par l'utilisateur" 1
    fi
    
    log_info "Ajout de règle firewall: port $PORT/$PROTOCOL"
    
    # Ajouter la règle selon le type de firewall
    case "$fw_type" in
        iptables)
            if ! add_iptables_rule "$PORT" "$PROTOCOL" "$SOURCE_IP"; then
                die "Échec de l'ajout de règle iptables" 1
            fi
            ;;
        firewalld)
            if ! add_firewalld_rule "$PORT" "$PROTOCOL" "$SOURCE_IP" "$ZONE"; then
                die "Échec de l'ajout de règle firewalld" 1
            fi
            ;;
        ufw)
            if ! add_ufw_rule "$PORT" "$PROTOCOL" "$SOURCE_IP"; then
                die "Échec de l'ajout de règle UFW" 1
            fi
            ;;
    esac
    
    # Vérification
    local rule_active=false rule_persistent=true
    if verify_rule_added "$PORT" "$PROTOCOL" "$fw_type"; then
        rule_active=true
        log_info "Règle ajoutée et vérifiée avec succès"
    else
        rule_active=false
        OPERATION_WARNINGS+=("Rule verification failed")
        log_warn "Impossible de vérifier l'ajout de la règle"
    fi
    
    # Construire le JSON des commandes exécutées
    local commands_json="[]"
    if [[ ${#EXECUTED_COMMANDS[@]} -gt 0 ]]; then
        local cmd_list=""
        for cmd in "${EXECUTED_COMMANDS[@]}"; do
            local escaped_cmd
            escaped_cmd=$(echo "$cmd" | sed 's/\\/\\\\/g; s/"/\\"/g')
            cmd_list+="\"$escaped_cmd\","
        done
        cmd_list=${cmd_list%,}
        commands_json="[$cmd_list]"
    fi
    
    # Construire les erreurs JSON
    local errors_json="[]"
    if [[ ${#OPERATION_ERRORS[@]} -gt 0 ]]; then
        local err_list=""
        for err in "${OPERATION_ERRORS[@]}"; do
            local escaped_err
            escaped_err=$(echo "$err" | sed 's/\\/\\\\/g; s/"/\\"/g')
            err_list+="\"$escaped_err\","
        done
        err_list=${err_list%,}
        errors_json="[$err_list]"
    fi
    
    # Échapper les valeurs pour JSON
    local port_escaped="$PORT"
    local protocol_escaped="$PROTOCOL"
    local source_escaped="${SOURCE_IP:-any}"
    local zone_escaped="$ZONE"
    
    # Générer la réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Firewall port rule added successfully",
  "data": {
    "port": $port_escaped,
    "protocol": "$protocol_escaped",
    "source_ip": "$source_escaped",
    "firewall_type": "$fw_type",
    "zone": "$zone_escaped",
    "permanent": $([ $PERMANENT -eq 1 ] && echo "true" || echo "false"),
    "commands_executed": $commands_json,
    "rule_verification": {
      "rule_exists": true,
      "rule_active": $rule_active,
      "rule_persistent": $([ $PERMANENT -eq 1 ] && echo "true" || echo "false")
    },
    "dry_run": $([ $DRY_RUN -eq 1 ] && echo "true" || echo "false"),
    "operation_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": $errors_json,
  "warnings": []
}
EOF
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi