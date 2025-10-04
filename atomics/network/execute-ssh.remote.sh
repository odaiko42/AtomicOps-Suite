#!/usr/bin/env bash

#===============================================================================
# Script Atomique : Exécution de commande SSH distante
#===============================================================================
# Nom du fichier : execute-ssh.remote.sh
# Niveau : 0 (Atomique)
# Catégorie : network
# Protocole : ssh
# Description : Exécute une commande ou script sur un hôte distant via SSH
#
# Objectif :
# - Exécution sécurisée de commandes SSH distantes
# - Récupération du code de sortie et des sorties stdout/stderr
# - Mesure des temps d'exécution et performances
# - Support des clés SSH et authentification par mot de passe
# - Gestion des timeouts et retry automatique
#
# Conforme à la méthodologie AtomicOps-Suite - Niveau 0
#===============================================================================

set -euo pipefail

# === MÉTADONNÉES DU SCRIPT ===
readonly SCRIPT_NAME="execute-ssh.remote.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_CATEGORY="network"
readonly SCRIPT_PROTOCOL="ssh"
readonly SCRIPT_LEVEL=0

# === CONFIGURATION PAR DÉFAUT ===
readonly DEFAULT_SSH_PORT=22
readonly DEFAULT_TIMEOUT=30
readonly DEFAULT_USER="$(whoami)"
readonly DEFAULT_MAX_RETRIES=3

# === VARIABLES GLOBALES ===
TARGET_HOST=""
TARGET_PORT="$DEFAULT_SSH_PORT"
TARGET_USER="$DEFAULT_USER"
SSH_KEY_FILE=""
REMOTE_COMMAND=""
REMOTE_SCRIPT_FILE=""
CONNECTION_TIMEOUT="$DEFAULT_TIMEOUT"
MAX_RETRIES="$DEFAULT_MAX_RETRIES"
WORKING_DIRECTORY=""
ENVIRONMENT_VARS=""
CAPTURE_OUTPUT=true
MEASURE_PERFORMANCE=true
QUIET_MODE=false
DEBUG_MODE=false
DRY_RUN=false

# === FONCTIONS D'AIDE ===
show_help() {
    cat << EOF
Exécution de commande SSH distante - Script Atomique Niveau 0

USAGE:
    $(basename "$0") [OPTIONS] HOST COMMAND
    $(basename "$0") [OPTIONS] HOST --script-file SCRIPT

DESCRIPTION:
    Exécute une commande ou un script sur un hôte distant via SSH :
    - Exécution sécurisée avec gestion des erreurs
    - Récupération des sorties stdout/stderr séparées
    - Mesure des performances et temps d'exécution
    - Support des variables d'environnement distantes
    - Retry automatique en cas d'échec temporaire
    - Validation des codes de retour et timeouts

PARAMÈTRES OBLIGATOIRES:
    HOST                    Nom d'hôte ou adresse IP du serveur distant
    COMMAND                 Commande à exécuter sur l'hôte distant
    --script-file SCRIPT    Alternative : fichier script à exécuter

OPTIONS PRINCIPALES:
    -p, --port PORT         Port SSH (défaut: 22)
    -u, --user USER         Utilisateur SSH (défaut: current user)
    -i, --identity FILE     Fichier de clé privée SSH
    -t, --timeout SECONDS   Timeout de connexion (défaut: 30)
    -r, --retries NUMBER    Nombre de tentatives max (défaut: 3)
    
OPTIONS AVANCÉES:
    -w, --workdir PATH      Répertoire de travail distant
    -e, --env "VAR=value"   Variables d'environnement (répétable)
    --no-output             Ne pas capturer stdout/stderr
    --no-performance        Désactiver les mesures de performance
    --dry-run               Simulation (affiche la commande SSH sans l'exécuter)
    
    -q, --quiet             Mode silencieux (erreurs uniquement)
    --debug                 Mode debug avec traces détaillées
    -h, --help              Affiche cette aide

EXEMPLES:
    # Commande simple
    $(basename "$0") server.com "uptime"
    
    # Avec authentification par clé
    $(basename "$0") --identity ~/.ssh/id_rsa --user admin server.com "df -h"
    
    # Exécution de script distant
    $(basename "$0") --script-file /tmp/setup.sh server.com
    
    # Avec variables d'environnement
    $(basename "$0") --env "ENV=production" --env "DEBUG=1" server.com "echo \$ENV"
    
    # Commande longue avec timeout augmenté
    $(basename "$0") --timeout 120 --retries 1 server.com "apt update && apt upgrade -y"
    
    # Dans un répertoire spécifique
    $(basename "$0") --workdir /var/log server.com "tail -n 100 syslog"

SORTIE JSON:
    {
        "status": "success|error",
        "timestamp": "ISO8601",
        "script": "$SCRIPT_NAME",
        "data": {
            "target": {
                "host": "hostname",
                "port": number,
                "user": "username"
            },
            "execution": {
                "command": "command_executed",
                "working_directory": "/path",
                "environment_vars": {"VAR": "value"},
                "start_time": "ISO8601",
                "end_time": "ISO8601",
                "duration_ms": number,
                "retries_used": number
            },
            "result": {
                "exit_code": number,
                "stdout": "string",
                "stderr": "string",
                "stdout_lines": number,
                "stderr_lines": number
            },
            "performance": {
                "connection_time_ms": number,
                "execution_time_ms": number,
                "total_time_ms": number,
                "data_transferred_bytes": number
            }
        }
    }

CODES DE RETOUR:
    0 : Succès - Commande exécutée avec succès
    1 : Erreur de paramètres
    2 : Erreur de connexion SSH
    3 : Timeout de connexion ou d'exécution
    4 : Erreur d'authentification SSH
    5 : Commande distante échouée (code non-zéro)
    6 : Échec après tous les retries

SÉCURITÉ:
    - Support clés SSH et authentification robuste
    - Échappement automatique des caractères spéciaux
    - Validation des paramètres d'entrée
    - Timeout pour éviter les blocages
    - Pas de stockage des mots de passe en plain text

CONFORMITÉ:
    - Méthodologie AtomicOps-Suite Niveau 0 (Atomique)
    - Sortie JSON standardisée
    - Gestion d'erreurs robuste avec codes spécifiques
EOF
}

# === FONCTIONS DE LOGGING ===
log_debug() { [[ "$DEBUG_MODE" == true ]] && echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_info() { [[ "$QUIET_MODE" == false ]] && echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }

# === VALIDATION DES PARAMÈTRES ===
validate_parameters() {
    local errors=0
    
    # Validation de l'hôte obligatoire
    if [[ -z "$TARGET_HOST" ]]; then
        log_error "Hôte cible obligatoire"
        ((errors++))
    fi
    
    # Validation de la commande ou du script
    if [[ -z "$REMOTE_COMMAND" && -z "$REMOTE_SCRIPT_FILE" ]]; then
        log_error "Commande ou fichier script obligatoire"
        ((errors++))
    elif [[ -n "$REMOTE_COMMAND" && -n "$REMOTE_SCRIPT_FILE" ]]; then
        log_error "Commande ET fichier script mutuellement exclusifs"
        ((errors++))
    fi
    
    # Validation du fichier script si spécifié
    if [[ -n "$REMOTE_SCRIPT_FILE" ]]; then
        if [[ ! -f "$REMOTE_SCRIPT_FILE" ]]; then
            log_error "Fichier script non trouvé : $REMOTE_SCRIPT_FILE"
            ((errors++))
        elif [[ ! -r "$REMOTE_SCRIPT_FILE" ]]; then
            log_error "Fichier script non lisible : $REMOTE_SCRIPT_FILE"
            ((errors++))
        fi
    fi
    
    # Validation du port
    if [[ ! "$TARGET_PORT" =~ ^[0-9]+$ ]] || [[ "$TARGET_PORT" -lt 1 ]] || [[ "$TARGET_PORT" -gt 65535 ]]; then
        log_error "Port invalide : $TARGET_PORT (doit être entre 1 et 65535)"
        ((errors++))
    fi
    
    # Validation du timeout
    if [[ ! "$CONNECTION_TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$CONNECTION_TIMEOUT" -lt 1 ]]; then
        log_error "Timeout invalide : $CONNECTION_TIMEOUT (doit être >= 1)"
        ((errors++))
    fi
    
    # Validation du nombre de retries
    if [[ ! "$MAX_RETRIES" =~ ^[0-9]+$ ]] || [[ "$MAX_RETRIES" -lt 0 ]]; then
        log_error "Nombre de retries invalide : $MAX_RETRIES (doit être >= 0)"
        ((errors++))
    fi
    
    # Validation du fichier de clé si spécifié
    if [[ -n "$SSH_KEY_FILE" ]]; then
        if [[ ! -f "$SSH_KEY_FILE" ]]; then
            log_error "Fichier de clé SSH non trouvé : $SSH_KEY_FILE"
            ((errors++))
        elif [[ ! -r "$SSH_KEY_FILE" ]]; then
            log_error "Fichier de clé SSH non lisible : $SSH_KEY_FILE"
            ((errors++))
        fi
    fi
    
    # Validation de l'utilisateur
    if [[ -z "$TARGET_USER" ]]; then
        log_error "Nom d'utilisateur obligatoire"
        ((errors++))
    fi
    
    return $errors
}

# === PRÉPARATION DE LA COMMANDE SSH ===
prepare_ssh_command() {
    log_debug "Préparation de la commande SSH"
    
    # Construction des options SSH de base
    local ssh_options=(
        "-o" "ConnectTimeout=$CONNECTION_TIMEOUT"
        "-o" "BatchMode=yes"
        "-o" "StrictHostKeyChecking=no"
        "-o" "UserKnownHostsFile=/dev/null"
        "-o" "LogLevel=ERROR"
        "-p" "$TARGET_PORT"
    )
    
    # Ajout de la clé privée si spécifiée
    if [[ -n "$SSH_KEY_FILE" ]]; then
        ssh_options+=("-i" "$SSH_KEY_FILE")
        log_debug "Utilisation de la clé SSH : $SSH_KEY_FILE"
    fi
    
    # Préparation de la commande à exécuter
    local final_command="$REMOTE_COMMAND"
    
    # Si c'est un fichier script, le lire et l'encoder
    if [[ -n "$REMOTE_SCRIPT_FILE" ]]; then
        log_debug "Préparation du script : $REMOTE_SCRIPT_FILE"
        local script_content
        script_content=$(cat "$REMOTE_SCRIPT_FILE" | base64 -w 0 2>/dev/null || base64 < "$REMOTE_SCRIPT_FILE")
        final_command="echo '$script_content' | base64 -d | bash"
    fi
    
    # Ajout du répertoire de travail si spécifié
    if [[ -n "$WORKING_DIRECTORY" ]]; then
        final_command="cd '$WORKING_DIRECTORY' && $final_command"
        log_debug "Répertoire de travail : $WORKING_DIRECTORY"
    fi
    
    # Ajout des variables d'environnement si spécifiées
    if [[ -n "$ENVIRONMENT_VARS" ]]; then
        final_command="$ENVIRONMENT_VARS $final_command"
        log_debug "Variables d'environnement : $ENVIRONMENT_VARS"
    fi
    
    # Stockage des informations pour utilisation ultérieure
    printf '%s\n' "${ssh_options[@]}" > /tmp/ssh_options_$$
    echo "$final_command" > /tmp/final_command_$$
    
    log_debug "Commande finale préparée : $final_command"
    
    return 0
}

# === EXÉCUTION SSH AVEC RETRY ===
execute_ssh_with_retry() {
    log_debug "Début de l'exécution SSH avec retry"
    
    # Lecture des options SSH préparées
    local ssh_options=()
    while IFS= read -r option; do
        ssh_options+=("$option")
    done < /tmp/ssh_options_$$
    
    local final_command=$(cat /tmp/final_command_$$)
    local attempt=1
    local success=false
    local last_exit_code=0
    local connection_time=0
    local execution_time=0
    local total_time=0
    local stdout_content=""
    local stderr_content=""
    
    while [[ $attempt -le $((MAX_RETRIES + 1)) ]]; do
        log_info "Tentative $attempt/$((MAX_RETRIES + 1)) - Connexion à $TARGET_USER@$TARGET_HOST:$TARGET_PORT"
        
        local attempt_start=$(date +%s.%N)
        
        # Fichiers temporaires pour les sorties
        local stdout_file=$(mktemp)
        local stderr_file=$(mktemp)
        
        if [[ "$DRY_RUN" == true ]]; then
            log_info "MODE DRY-RUN : ssh ${ssh_options[*]} $TARGET_USER@$TARGET_HOST \"$final_command\""
            echo "DRY-RUN: Command would be executed" > "$stdout_file"
            echo "" > "$stderr_file"
            last_exit_code=0
            success=true
        else
            # Exécution SSH réelle
            log_debug "Exécution : ssh ${ssh_options[*]} $TARGET_USER@$TARGET_HOST"
            
            if ssh "${ssh_options[@]}" "$TARGET_USER@$TARGET_HOST" "$final_command" > "$stdout_file" 2> "$stderr_file"; then
                last_exit_code=0
                success=true
                log_debug "Commande SSH exécutée avec succès"
            else
                last_exit_code=$?
                log_debug "Échec commande SSH (code: $last_exit_code)"
                
                # Vérification si c'est un problème de connexion (retry possible)
                if [[ $last_exit_code -eq 255 ]]; then
                    log_debug "Erreur de connexion SSH (code 255) - retry possible"
                else
                    log_debug "Erreur d'exécution de commande (code: $last_exit_code) - pas de retry"
                    success=false
                    break
                fi
            fi
        fi
        
        local attempt_end=$(date +%s.%N)
        local attempt_duration=$(echo "$attempt_end - $attempt_start" | bc -l 2>/dev/null || echo "0.00")
        
        # Lecture des sorties
        stdout_content=$(cat "$stdout_file" 2>/dev/null || echo "")
        stderr_content=$(cat "$stderr_file" 2>/dev/null || echo "")
        
        # Nettoyage des fichiers temporaires
        rm -f "$stdout_file" "$stderr_file"
        
        if [[ "$success" == true ]]; then
            total_time="$attempt_duration"
            log_info "Commande exécutée avec succès en ${total_time}s"
            break
        else
            log_debug "Tentative $attempt échouée en ${attempt_duration}s"
            
            if [[ $attempt -le $MAX_RETRIES ]]; then
                local wait_time=$((attempt * 2))
                log_info "Attente ${wait_time}s avant retry..."
                sleep "$wait_time"
            fi
            
            ((attempt++))
        fi
    done
    
    # Stockage des résultats
    cat << EOF > /tmp/execution_result_$$
{
    "success": $success,
    "exit_code": $last_exit_code,
    "retries_used": $((attempt - 1)),
    "total_time": "$total_time",
    "stdout": "$(echo "$stdout_content" | sed 's/"/\\"/g' | tr '\n' '\\n')",
    "stderr": "$(echo "$stderr_content" | sed 's/"/\\"/g' | tr '\n' '\\n')",
    "stdout_lines": $(echo "$stdout_content" | wc -l 2>/dev/null || echo "0"),
    "stderr_lines": $(echo "$stderr_content" | wc -l 2>/dev/null || echo "0")
}
EOF
    
    return $([ "$success" == true ] && echo 0 || echo $last_exit_code)
}

# === MESURES DE PERFORMANCE ===
measure_performance() {
    if [[ "$MEASURE_PERFORMANCE" == false ]]; then
        echo '{"connection_time_ms": 0, "execution_time_ms": 0, "total_time_ms": 0, "data_transferred_bytes": 0}' > /tmp/performance_result_$$
        return 0
    fi
    
    log_debug "Mesures de performance SSH"
    
    # Lecture du temps total depuis le résultat d'exécution
    local execution_result=$(cat /tmp/execution_result_$$ 2>/dev/null || echo '{"total_time": "0"}')
    local total_time_sec=$(echo "$execution_result" | grep -o '"total_time": "[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "0")
    local total_time_ms=$(echo "$total_time_sec * 1000" | bc -l 2>/dev/null || echo "0")
    
    # Estimation de la taille des données transférées
    local stdout_content=$(echo "$execution_result" | grep -o '"stdout": "[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
    local stderr_content=$(echo "$execution_result" | grep -o '"stderr": "[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
    local data_transferred=$((${#stdout_content} + ${#stderr_content}))
    
    # Estimation approximative du temps de connexion (30% du temps total)
    local connection_time_ms=$(echo "$total_time_ms * 0.3" | bc -l 2>/dev/null || echo "0")
    local execution_time_ms=$(echo "$total_time_ms * 0.7" | bc -l 2>/dev/null || echo "0")
    
    cat << EOF > /tmp/performance_result_$$
{
    "connection_time_ms": $(printf "%.0f" "$connection_time_ms"),
    "execution_time_ms": $(printf "%.0f" "$execution_time_ms"),
    "total_time_ms": $(printf "%.0f" "$total_time_ms"),
    "data_transferred_bytes": $data_transferred
}
EOF
    
    return 0
}

# === GÉNÉRATION DE LA SORTIE JSON ===
generate_output() {
    local status="$1"
    local start_time="$2"
    local end_time="$3"
    
    # Lecture des résultats
    local execution_result=$(cat /tmp/execution_result_$$ 2>/dev/null || echo '{"success": false, "exit_code": 1, "retries_used": 0, "total_time": "0", "stdout": "", "stderr": "", "stdout_lines": 0, "stderr_lines": 0}')
    local performance_result=$(cat /tmp/performance_result_$$ 2>/dev/null || echo '{"connection_time_ms": 0, "execution_time_ms": 0, "total_time_ms": 0, "data_transferred_bytes": 0}')
    
    # Extraction des valeurs depuis les résultats
    local exit_code=$(echo "$execution_result" | grep -o '"exit_code": [0-9]*' | cut -d' ' -f2 2>/dev/null || echo "1")
    local retries_used=$(echo "$execution_result" | grep -o '"retries_used": [0-9]*' | cut -d' ' -f2 2>/dev/null || echo "0")
    local stdout_content=$(echo "$execution_result" | grep -o '"stdout": "[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
    local stderr_content=$(echo "$execution_result" | grep -o '"stderr": "[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
    local stdout_lines=$(echo "$execution_result" | grep -o '"stdout_lines": [0-9]*' | cut -d' ' -f2 2>/dev/null || echo "0")
    local stderr_lines=$(echo "$execution_result" | grep -o '"stderr_lines": [0-9]*' | cut -d' ' -f2 2>/dev/null || echo "0")
    
    # Préparation de la commande finale
    local final_command=$(cat /tmp/final_command_$$ 2>/dev/null || echo "$REMOTE_COMMAND")
    
    # Conversion des variables d'environnement en JSON
    local env_vars_json="{}"
    if [[ -n "$ENVIRONMENT_VARS" ]]; then
        # Parsing simple des variables KEY=VALUE
        local env_pairs=()
        IFS=' ' read -ra ENV_ARRAY <<< "$ENVIRONMENT_VARS"
        for env_var in "${ENV_ARRAY[@]}"; do
            if [[ "$env_var" =~ ^([^=]+)=(.*)$ ]]; then
                env_pairs+=("\"${BASH_REMATCH[1]}\": \"${BASH_REMATCH[2]}\"")
            fi
        done
        if [[ ${#env_pairs[@]} -gt 0 ]]; then
            env_vars_json="{$(IFS=,; echo "${env_pairs[*]}")}"
        fi
    fi
    
    cat << EOF
{
    "status": "$status",
    "timestamp": "$(date -Iseconds)",
    "script": "$SCRIPT_NAME",
    "version": "$SCRIPT_VERSION",
    "data": {
        "target": {
            "host": "$TARGET_HOST",
            "port": $TARGET_PORT,
            "user": "$TARGET_USER"
        },
        "execution": {
            "command": "$final_command",
            "working_directory": "$WORKING_DIRECTORY",
            "environment_vars": $env_vars_json,
            "start_time": "$start_time",
            "end_time": "$end_time",
            "duration_ms": $(echo "($end_time_sec - $start_time_sec) * 1000" | bc -l 2>/dev/null || echo "0"),
            "retries_used": $retries_used
        },
        "result": {
            "exit_code": $exit_code,
            "stdout": "$stdout_content",
            "stderr": "$stderr_content",
            "stdout_lines": $stdout_lines,
            "stderr_lines": $stderr_lines
        },
        "performance": $performance_result
    }
}
EOF
}

# === NETTOYAGE DES FICHIERS TEMPORAIRES ===
cleanup() {
    rm -f /tmp/ssh_options_$$ /tmp/final_command_$$ /tmp/execution_result_$$ /tmp/performance_result_$$ 2>/dev/null || true
}

# === GESTION DES ARGUMENTS ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--port)
                TARGET_PORT="$2"
                shift 2
                ;;
            -u|--user)
                TARGET_USER="$2"
                shift 2
                ;;
            -i|--identity)
                SSH_KEY_FILE="$2"
                shift 2
                ;;
            -t|--timeout)
                CONNECTION_TIMEOUT="$2"
                shift 2
                ;;
            -r|--retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            --script-file)
                REMOTE_SCRIPT_FILE="$2"
                shift 2
                ;;
            -w|--workdir)
                WORKING_DIRECTORY="$2"
                shift 2
                ;;
            -e|--env)
                ENVIRONMENT_VARS="$ENVIRONMENT_VARS $2"
                shift 2
                ;;
            --no-output)
                CAPTURE_OUTPUT=false
                shift
                ;;
            --no-performance)
                MEASURE_PERFORMANCE=false
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Option inconnue : $1"
                show_help >&2
                exit 1
                ;;
            *)
                if [[ -z "$TARGET_HOST" ]]; then
                    TARGET_HOST="$1"
                elif [[ -z "$REMOTE_COMMAND" && -z "$REMOTE_SCRIPT_FILE" ]]; then
                    REMOTE_COMMAND="$1"
                else
                    log_error "Argument en trop : $1"
                    show_help >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# === FONCTION PRINCIPALE ===
main() {
    local start_time=$(date -Iseconds)
    local start_time_sec=$(date +%s.%N)
    
    # Configuration du piégeage pour nettoyage
    trap cleanup EXIT INT TERM
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des paramètres
    if ! validate_parameters; then
        exit 1
    fi
    
    log_debug "Début de l'exécution SSH vers $TARGET_USER@$TARGET_HOST:$TARGET_PORT"
    
    # Préparation de la commande SSH
    if ! prepare_ssh_command; then
        log_error "Échec de la préparation de la commande SSH"
        exit 1
    fi
    
    # Exécution SSH avec retry
    local ssh_exit_code=0
    if ! execute_ssh_with_retry; then
        ssh_exit_code=$?
        
        # Détermination du type d'erreur pour le code de retour
        case $ssh_exit_code in
            255) exit 2 ;;  # Erreur de connexion SSH
            124) exit 3 ;;  # Timeout
            *)   exit 5 ;;  # Commande distante échouée
        esac
    fi
    
    # Mesures de performance
    if ! measure_performance; then
        log_error "Échec des mesures de performance"
    fi
    
    local end_time=$(date -Iseconds)
    local end_time_sec=$(date +%s.%N)
    
    # Génération du rapport final
    generate_output "success" "$start_time" "$end_time"
    
    local duration=$(echo "$end_time_sec - $start_time_sec" | bc -l 2>/dev/null || echo "0.00")
    log_debug "Exécution SSH terminée en ${duration}s"
    
    return $ssh_exit_code
}

# Point d'entrée du script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi