#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: scp-transfer.sh
# Description: Transfert de fichiers via SCP avec gestion des erreurs et métriques
# Author: Generated with AtomicOps-Suite AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# Level: 0 (Atomique)
# Dependencies: scp, ssh
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="scp-transfer.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}

# Variables SCP
SSH_HOST=""
SSH_PORT=${SSH_PORT:-22}
SSH_USER=""
SSH_PRIVATE_KEY=""
SSH_TIMEOUT=${SSH_TIMEOUT:-30}
SSH_STRICT_HOST_CHECK=${SSH_STRICT_HOST_CHECK:-1}

# Variables de transfert
TRANSFER_MODE="upload"  # upload|download
LOCAL_PATH=""
REMOTE_PATH=""
PRESERVE_ATTRIBUTES=${PRESERVE_ATTRIBUTES:-1}
RECURSIVE=${RECURSIVE:-0}
COMPRESSION=${COMPRESSION:-1}
BANDWIDTH_LIMIT=""  # En KB/s

# Variables de résultat
TRANSFER_SUCCESS=0
TRANSFER_SIZE=0
TRANSFER_TIME=0
TRANSFER_SPEED=0
FILES_TRANSFERRED=0
ERROR_MESSAGE=""

# =============================================================================
# Fonctions Utilitaires et Logging
# =============================================================================

log_debug() {
    [[ $DEBUG -eq 0 ]] && return 0
    echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_info() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_warn() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

die() {
    log_error "$1"
    build_json_output "error" "${2:-1}" "$1"
    exit "${2:-1}"
}

# =============================================================================
# Fonctions d'Aide et de Parsing
# =============================================================================

show_help() {
    cat << 'EOF'
Usage: scp-transfer.sh [OPTIONS] --host <host> --user <user> --mode <mode> --local <path> --remote <path>

Description:
    Transfert de fichiers ou répertoires via SCP (SSH Copy Protocol). Supporte
    l'upload et le download avec métriques de performance, gestion des erreurs,
    et options avancées de transfert.

Arguments obligatoires:
    --host <hostname>        Nom d'hôte ou IP du serveur SSH
    --user <username>        Nom d'utilisateur SSH
    --mode <upload|download> Mode de transfert
    --local <path>           Chemin du fichier/répertoire local
    --remote <path>          Chemin du fichier/répertoire distant

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)

Options SSH:
    -p, --port <port>      Port SSH (défaut: 22)
    -k, --key <path>       Chemin vers la clé privée SSH
    -t, --timeout <sec>    Timeout de connexion SSH (défaut: 30)
    --no-strict-host       Désactiver la vérification des clés d'hôte

Options de transfert:
    -r, --recursive        Transfert récursif (répertoires)
    --no-preserve          Ne pas préserver les attributs (permissions, dates)
    --no-compression       Désactiver la compression
    --limit <kb/s>         Limiter la bande passante (en KB/s)

Variables d'environnement:
    SSH_HOST               Nom d'hôte par défaut
    SSH_PORT               Port par défaut (défaut: 22)
    SSH_USER               Utilisateur par défaut
    SSH_PRIVATE_KEY        Clé privée par défaut
    SSH_TIMEOUT            Timeout par défaut (défaut: 30)
    SSH_STRICT_HOST_CHECK  Vérification des clés d'hôte (défaut: 1)
    PRESERVE_ATTRIBUTES    Préserver attributs (défaut: 1)
    COMPRESSION            Compression activée (défaut: 1)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0|1|2|3|4,
      "timestamp": "ISO8601",
      "script": "scp-transfer.sh",
      "message": "Description du résultat",
      "data": {
        "transfer": {
          "mode": "upload|download",
          "local_path": "/local/path",
          "remote_path": "/remote/path",
          "success": true,
          "recursive": false
        },
        "connection": {
          "host": "hostname",
          "port": 22,
          "user": "username"
        },
        "performance": {
          "size_bytes": 1234567,
          "time_ms": 5000,
          "speed_kbps": 247.1,
          "files_count": 1
        },
        "options": {
          "preserve_attributes": true,
          "compression": true,
          "bandwidth_limit_kbps": null
        }
      }
    }

Codes de sortie:
    0 - Transfert réussi
    1 - Erreur de paramètres ou configuration
    2 - Connexion SSH impossible
    3 - Erreur de transfert SCP
    4 - Fichier source non trouvé

Exemples:
    # Upload d'un fichier
    ./scp-transfer.sh --host 192.168.1.100 --user admin \
        --key ~/.ssh/id_rsa --mode upload \
        --local ./document.pdf --remote /tmp/document.pdf
    
    # Download d'un répertoire (récursif)
    ./scp-transfer.sh --host server.example.com --user backup \
        --mode download --recursive \
        --remote /var/backups/daily --local ./backups/
    
    # Upload avec limitation de bande passante
    ./scp-transfer.sh --host slow-connection.com --user upload \
        --mode upload --limit 100 \
        --local ./large-file.zip --remote /uploads/
    
    # Transfer sans préservation des attributs
    ./scp-transfer.sh --host target-server --user deploy \
        --mode upload --no-preserve \
        --local ./app --remote /opt/app --recursive
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
                ;;
            -d|--debug)
                DEBUG=1
                VERBOSE=1
                ;;
            -q|--quiet)
                QUIET=1
                ;;
            -j|--json-only)
                JSON_ONLY=1
                QUIET=1
                ;;
            --host)
                [[ -z "${2:-}" ]] && die "Option --host nécessite une valeur" 1
                SSH_HOST="$2"
                shift
                ;;
            --user)
                [[ -z "${2:-}" ]] && die "Option --user nécessite une valeur" 1
                SSH_USER="$2"
                shift
                ;;
            --mode)
                [[ -z "${2:-}" ]] && die "Option --mode nécessite une valeur" 1
                TRANSFER_MODE="$2"
                shift
                ;;
            --local)
                [[ -z "${2:-}" ]] && die "Option --local nécessite une valeur" 1
                LOCAL_PATH="$2"
                shift
                ;;
            --remote)
                [[ -z "${2:-}" ]] && die "Option --remote nécessite une valeur" 1
                REMOTE_PATH="$2"
                shift
                ;;
            -p|--port)
                [[ -z "${2:-}" ]] && die "Option --port nécessite une valeur" 1
                SSH_PORT="$2"
                shift
                ;;
            -k|--key)
                [[ -z "${2:-}" ]] && die "Option --key nécessite une valeur" 1
                SSH_PRIVATE_KEY="$2"
                shift
                ;;
            -t|--timeout)
                [[ -z "${2:-}" ]] && die "Option --timeout nécessite une valeur" 1
                SSH_TIMEOUT="$2"
                shift
                ;;
            --no-strict-host)
                SSH_STRICT_HOST_CHECK=0
                ;;
            -r|--recursive)
                RECURSIVE=1
                ;;
            --no-preserve)
                PRESERVE_ATTRIBUTES=0
                ;;
            --no-compression)
                COMPRESSION=0
                ;;
            --limit)
                [[ -z "${2:-}" ]] && die "Option --limit nécessite une valeur" 1
                BANDWIDTH_LIMIT="$2"
                shift
                ;;
            -*)
                die "Option inconnue: $1" 1
                ;;
            *)
                die "Argument non attendu: $1" 1
                ;;
        esac
        shift
    done
}

# =============================================================================
# Fonctions de Validation
# =============================================================================

validate_prerequisites() {
    log_debug "Validation des prérequis système..."
    
    # Vérification des commandes nécessaires
    local missing_commands=()
    
    if ! command -v scp >/dev/null 2>&1; then
        missing_commands+=("scp")
    fi
    
    if ! command -v ssh >/dev/null 2>&1; then
        missing_commands+=("ssh")
    fi
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing_commands[*]}" 1
    fi
    
    # Validation des paramètres obligatoires
    [[ -z "$SSH_HOST" ]] && die "Paramètre --host obligatoire" 1
    [[ -z "$SSH_USER" ]] && die "Paramètre --user obligatoire" 1
    [[ -z "$LOCAL_PATH" ]] && die "Paramètre --local obligatoire" 1
    [[ -z "$REMOTE_PATH" ]] && die "Paramètre --remote obligatoire" 1
    
    # Validation du mode de transfert
    case "$TRANSFER_MODE" in
        upload|download)
            ;;
        *)
            die "Mode de transfert invalide: $TRANSFER_MODE (upload ou download)" 1
            ;;
    esac
    
    # Validation du port
    if [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]] || [[ $SSH_PORT -lt 1 ]] || [[ $SSH_PORT -gt 65535 ]]; then
        die "Port SSH invalide: $SSH_PORT (doit être entre 1-65535)" 1
    fi
    
    # Validation du timeout
    if [[ ! "$SSH_TIMEOUT" =~ ^[0-9]+$ ]] || [[ $SSH_TIMEOUT -lt 1 ]]; then
        die "Timeout invalide: $SSH_TIMEOUT (doit être >= 1)" 1
    fi
    
    # Validation de la limite de bande passante
    if [[ -n "$BANDWIDTH_LIMIT" ]] && [[ ! "$BANDWIDTH_LIMIT" =~ ^[0-9]+$ ]]; then
        die "Limite de bande passante invalide: $BANDWIDTH_LIMIT (doit être un nombre en KB/s)" 1
    fi
    
    # Validation de la clé privée si spécifiée
    if [[ -n "$SSH_PRIVATE_KEY" ]] && [[ ! -r "$SSH_PRIVATE_KEY" ]]; then
        die "Clé privée non accessible: $SSH_PRIVATE_KEY" 1
    fi
    
    # Validation spécifique au mode upload
    if [[ "$TRANSFER_MODE" = "upload" ]]; then
        if [[ ! -e "$LOCAL_PATH" ]]; then
            die "Fichier/répertoire source non trouvé: $LOCAL_PATH" 4
        fi
        
        if [[ -d "$LOCAL_PATH" ]] && [[ $RECURSIVE -eq 0 ]]; then
            die "Répertoire détecté mais option --recursive non utilisée" 1
        fi
    fi
    
    log_debug "Validation réussie"
    log_info "Transfert SCP: $TRANSFER_MODE de $LOCAL_PATH vers $SSH_USER@$SSH_HOST:$REMOTE_PATH"
    
    return 0
}

# =============================================================================
# Fonctions Principales
# =============================================================================

# Calcul de la taille des fichiers à transférer
calculate_transfer_size() {
    log_debug "Calcul de la taille du transfert"
    
    if [[ "$TRANSFER_MODE" = "upload" ]]; then
        if [[ -f "$LOCAL_PATH" ]]; then
            TRANSFER_SIZE=$(stat -c%s "$LOCAL_PATH" 2>/dev/null || echo "0")
            FILES_TRANSFERRED=1
        elif [[ -d "$LOCAL_PATH" ]] && [[ $RECURSIVE -eq 1 ]]; then
            TRANSFER_SIZE=$(du -sb "$LOCAL_PATH" 2>/dev/null | cut -f1 || echo "0")
            FILES_TRANSFERRED=$(find "$LOCAL_PATH" -type f | wc -l 2>/dev/null || echo "0")
        fi
    else
        # Pour le download, on ne peut pas calculer la taille à l'avance facilement
        TRANSFER_SIZE=0
        FILES_TRANSFERRED=0
    fi
    
    log_debug "Taille estimée: $TRANSFER_SIZE octets, Fichiers: $FILES_TRANSFERRED"
}

# Construction des options SCP
build_scp_options() {
    local scp_options=()
    
    # Options SSH de base
    scp_options+=(
        -o "BatchMode=yes"
        -o "ConnectTimeout=$SSH_TIMEOUT"
        -P "$SSH_PORT"
    )
    
    if [[ $SSH_STRICT_HOST_CHECK -eq 0 ]]; then
        scp_options+=(
            -o "StrictHostKeyChecking=no"
            -o "UserKnownHostsFile=/dev/null"
        )
    fi
    
    if [[ -n "$SSH_PRIVATE_KEY" ]]; then
        scp_options+=(-i "$SSH_PRIVATE_KEY")
    fi
    
    # Options SCP spécifiques
    if [[ $PRESERVE_ATTRIBUTES -eq 1 ]]; then
        scp_options+=(-p)
    fi
    
    if [[ $RECURSIVE -eq 1 ]]; then
        scp_options+=(-r)
    fi
    
    if [[ $COMPRESSION -eq 1 ]]; then
        scp_options+=(-C)
    fi
    
    if [[ -n "$BANDWIDTH_LIMIT" ]]; then
        scp_options+=(-l "$BANDWIDTH_LIMIT")
    fi
    
    if [[ $VERBOSE -eq 1 ]] && [[ $JSON_ONLY -eq 0 ]]; then
        scp_options+=(-v)
    fi
    
    echo "${scp_options[@]}"
}

# Exécution du transfert SCP
execute_scp_transfer() {
    log_debug "Exécution du transfert SCP"
    
    # Calcul de la taille avant transfert
    calculate_transfer_size
    
    # Construction des options SCP
    local scp_options
    IFS=' ' read -ra scp_options <<< "$(build_scp_options)"
    
    # Construction de la commande selon le mode
    local scp_command
    local source_path
    local dest_path
    
    if [[ "$TRANSFER_MODE" = "upload" ]]; then
        source_path="$LOCAL_PATH"
        dest_path="$SSH_USER@$SSH_HOST:$REMOTE_PATH"
    else
        source_path="$SSH_USER@$SSH_HOST:$REMOTE_PATH"
        dest_path="$LOCAL_PATH"
    fi
    
    log_debug "Commande: scp ${scp_options[*]} '$source_path' '$dest_path'"
    
    # Exécution du transfert avec mesure du temps
    local start_time=$(date +%s%3N)
    local scp_output=""
    local scp_exit_code=0
    
    if scp_output=$(scp "${scp_options[@]}" "$source_path" "$dest_path" 2>&1); then
        scp_exit_code=0
        TRANSFER_SUCCESS=1
    else
        scp_exit_code=$?
        TRANSFER_SUCCESS=0
        ERROR_MESSAGE="$scp_output"
    fi
    
    local end_time=$(date +%s%3N)
    TRANSFER_TIME=$((end_time - start_time))
    
    # Calcul de la vitesse de transfert
    if [[ $TRANSFER_TIME -gt 0 ]] && [[ $TRANSFER_SIZE -gt 0 ]]; then
        TRANSFER_SPEED=$(echo "scale=2; $TRANSFER_SIZE * 8 / $TRANSFER_TIME" | bc -l 2>/dev/null || echo "0")
    else
        TRANSFER_SPEED=0
    fi
    
    # Recalcul de la taille après transfert pour le mode download
    if [[ "$TRANSFER_MODE" = "download" ]] && [[ $TRANSFER_SUCCESS -eq 1 ]]; then
        if [[ -f "$LOCAL_PATH" ]]; then
            TRANSFER_SIZE=$(stat -c%s "$LOCAL_PATH" 2>/dev/null || echo "0")
            FILES_TRANSFERRED=1
        elif [[ -d "$LOCAL_PATH" ]]; then
            TRANSFER_SIZE=$(du -sb "$LOCAL_PATH" 2>/dev/null | cut -f1 || echo "0")
            FILES_TRANSFERRED=$(find "$LOCAL_PATH" -type f | wc -l 2>/dev/null || echo "0")
        fi
    fi
    
    log_debug "Transfert terminé - Code: $scp_exit_code, Temps: ${TRANSFER_TIME}ms, Vitesse: ${TRANSFER_SPEED} Kbps"
    
    if [[ $TRANSFER_SUCCESS -eq 1 ]]; then
        log_info "Transfert SCP réussi ($TRANSFER_SIZE octets en ${TRANSFER_TIME}ms)"
        return 0
    else
        log_error "Transfert SCP échoué: $ERROR_MESSAGE"
        case $scp_exit_code in
            1)
                return 3  # Erreur générale SCP
                ;;
            2)
                return 2  # Connexion impossible
                ;;
            *)
                return 3  # Erreur de transfert
                ;;
        esac
    fi
}

# Action principale du script
do_main_action() {
    log_debug "Démarrage du transfert SCP"
    
    # Test de connectivité SSH basique
    log_debug "Test de connectivité SSH vers $SSH_HOST:$SSH_PORT"
    if ! timeout "$SSH_TIMEOUT" bash -c "exec 3<>/dev/tcp/$SSH_HOST/$SSH_PORT" 2>/dev/null; then
        ERROR_MESSAGE="Connexion réseau impossible vers $SSH_HOST:$SSH_PORT"
        log_error "$ERROR_MESSAGE"
        exec 3>&- 2>/dev/null || true
        return 2
    fi
    exec 3>&- 2>/dev/null || true
    
    # Exécution du transfert
    if execute_scp_transfer; then
        log_info "Transfert SCP terminé avec succès"
        return 0
    else
        local transfer_exit_code=$?
        log_error "Transfert SCP échoué"
        return $transfer_exit_code
    fi
}

# =============================================================================
# Fonction de Construction de Sortie JSON
# =============================================================================

build_json_output() {
    local status="$1"
    local exit_code="$2"
    local message="$3"
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
    
    cat << EOF
{
  "status": "$status",
  "code": $exit_code,
  "timestamp": "$timestamp",
  "script": "$SCRIPT_NAME",
  "message": "$message",
  "data": {
    "transfer": {
      "mode": "$TRANSFER_MODE",
      "local_path": "$LOCAL_PATH",
      "remote_path": "$REMOTE_PATH",
      "success": $([ $TRANSFER_SUCCESS -eq 1 ] && echo "true" || echo "false"),
      "recursive": $([ $RECURSIVE -eq 1 ] && echo "true" || echo "false")
    },
    "connection": {
      "host": "$SSH_HOST",
      "port": $SSH_PORT,
      "user": "$SSH_USER",
      "key_file": "${SSH_PRIVATE_KEY:-null}"
    },
    "performance": {
      "size_bytes": $TRANSFER_SIZE,
      "time_ms": $TRANSFER_TIME,
      "speed_kbps": $TRANSFER_SPEED,
      "files_count": $FILES_TRANSFERRED
    },
    "options": {
      "preserve_attributes": $([ $PRESERVE_ATTRIBUTES -eq 1 ] && echo "true" || echo "false"),
      "compression": $([ $COMPRESSION -eq 1 ] && echo "true" || echo "false"),
      "bandwidth_limit_kbps": $([ -n "$BANDWIDTH_LIMIT" ] && echo "$BANDWIDTH_LIMIT" || echo "null")
    },
    "error": "${ERROR_MESSAGE:-null}"
  }
}
EOF
}

# =============================================================================
# Fonction de Nettoyage
# =============================================================================

cleanup() {
    log_debug "Nettoyage des ressources"
    # Fermer les connexions TCP ouvertes si nécessaire
    exec 3>&- 2>/dev/null || true
}

# =============================================================================
# Point d'Entrée Principal
# =============================================================================

main() {
    # Configuration du trap pour le nettoyage
    trap cleanup EXIT ERR INT TERM
    
    # Récupération des variables d'environnement par défaut
    SSH_HOST="${SSH_HOST:-}"
    SSH_USER="${SSH_USER:-}"
    SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-}"
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des prérequis
    validate_prerequisites
    
    # Exécution de l'action principale
    local exit_code=0
    local result_message="Transfert SCP exécuté avec succès"
    
    if do_main_action; then
        result_message="Transfert SCP $TRANSFER_MODE réussi ($TRANSFER_SIZE octets)"
        exit_code=0
    else
        local action_exit_code=$?
        case $action_exit_code in
            2)
                result_message="Connexion SSH impossible"
                exit_code=2
                ;;
            3)
                result_message="Erreur de transfert SCP"
                exit_code=3
                ;;
            4)
                result_message="Fichier source non trouvé"
                exit_code=4
                ;;
            *)
                result_message="Erreur lors du transfert SCP"
                exit_code=1
                ;;
        esac
    fi
    
    # Génération de la sortie JSON
    build_json_output \
        "$([ $exit_code -eq 0 ] && echo "success" || echo "error")" \
        "$exit_code" \
        "$result_message"
    
    exit $exit_code
}

# Exécution du script si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi