#!/usr/bin/env bash

#===============================================================================
# SSH Default Workflow - Orchestrateur de connexion SSH complète
#===============================================================================
# Description : Workflow par défaut pour connexion SSH avec exploration de répertoire
# Niveau : 1 (Orchestrateur)
# Catégorie : network
# Dépendances : ssh-connect.sh, ssh-execute-command.sh
# 
# Ce script orchestre une session SSH complète :
# 1. Connexion SSH sécurisée sur 192.168.88.50
# 2. Navigation vers le répertoire /root/script  
# 3. Affichage récursif du contenu
# 4. Fermeture propre de la session SSH
#
# Conforme à la méthodologie AtomicOps-Suite - Niveau 1
#===============================================================================

set -euo pipefail

# === CONFIGURATION GLOBALE ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"
ATOMIC_DIR="$(realpath "$SCRIPT_DIR/../../atomic")"

# === SOURCING DES BIBLIOTHÈQUES ===
# Note: Utilisation des fonctions JSON basiques intégrées pour éviter les dépendances
# source "$LIB_DIR/lib-common.sh"
# source "$LIB_DIR/lib-json.sh"

# === FONCTIONS JSON BASIQUES INTÉGRÉES ===
json_info() { echo "[INFO] $1" >&2; }
json_error() { echo "[ERROR] $1" >&2; }
json_success() { echo "[SUCCESS] $1" >&2; }  
json_debug() { [[ "$DEBUG_MODE" == true ]] && echo "[DEBUG] $1" >&2; }

# === CONSTANTES DU WORKFLOW ===
readonly DEFAULT_HOST="192.168.88.50"
readonly DEFAULT_USER="root" 
readonly DEFAULT_DIRECTORY="/root/scripts"
readonly CT_LAUNCHER_SCRIPT="ct-launcher.sh"
readonly WORKFLOW_NAME="SSH CT Launcher Workflow"

# === VARIABLES GLOBALES ===
QUIET_MODE=false
FORCE_MODE=false
DEBUG_MODE=false
HOST="$DEFAULT_HOST"
USERNAME="$DEFAULT_USER"
SSH_KEY=""
CONNECTION_TIMEOUT=30
TARGET_DIRECTORY="$DEFAULT_DIRECTORY"
ATOMIC_SSH_CONNECT=""
ATOMIC_SSH_EXECUTE=""

# === VARIABLES DE GESTION DE SESSION ===
SSH_SESSION_ACTIVE=false
SSH_CONNECTION_PID=""
SESSION_START_TIME=""
SESSION_CLEANUP_REQUIRED=false

#===============================================================================
# FONCTIONS DE GESTION DE SESSION SSH
#===============================================================================

# Trigger d'ouverture de session SSH avec gestion d'état
ssh_session_open_trigger() {
    local session_start=$(date +%s.%N)
    SESSION_START_TIME="$session_start"
    
    [[ "$DEBUG_MODE" == true ]] && json_debug "TRIGGER: Ouverture de session SSH vers $USERNAME@$HOST"
    
    # Vérification que la session n'est pas déjà active
    if [[ "$SSH_SESSION_ACTIVE" == true ]]; then
        json_error "TRIGGER: Une session SSH est déjà active"
        return 1
    fi
    
    # Marquage du début de session
    SSH_SESSION_ACTIVE=true
    SESSION_CLEANUP_REQUIRED=true
    
    # Test de connectivité initial (compatible WSL/Windows)
    [[ "$DEBUG_MODE" == true ]] && json_debug "TRIGGER: Test de connectivité réseau vers $HOST:22"
    
    # Utilisation de nc ou ping selon disponibilité
    if command -v nc >/dev/null 2>&1; then
        if ! timeout 5 nc -z "$HOST" 22 2>/dev/null; then
            json_error "TRIGGER: Host $HOST inaccessible sur le port 22 (nc test)"
            ssh_session_close_trigger "error"
            return 2
        fi
    elif command -v ping >/dev/null 2>&1; then
        if ! ping -c 1 -W 1000 "$HOST" >/dev/null 2>&1; then
            json_error "TRIGGER: Host $HOST inaccessible (ping test)"
            ssh_session_close_trigger "error"  
            return 2
        fi
    else
        [[ "$DEBUG_MODE" == true ]] && json_debug "TRIGGER: Pas d'outils de test réseau disponibles, connexion assumée possible"
    fi
    
    [[ "$DEBUG_MODE" == true ]] && json_success "TRIGGER: Connectivité réseau établie vers $HOST"
    
    # Enregistrement des métadonnées de session
    echo "$session_start" > /tmp/ssh_session_start_$$
    echo "$HOST" > /tmp/ssh_session_host_$$
    echo "$USERNAME" > /tmp/ssh_session_user_$$
    
    [[ "$DEBUG_MODE" == true ]] && json_success "TRIGGER: Session SSH initialisée avec succès"
    
    return 0
}

# Trigger de fermeture de session SSH avec nettoyage complet
ssh_session_close_trigger() {
    local closure_reason=${1:-"normal"}
    local session_end=$(date +%s.%N)
    
    [[ "$DEBUG_MODE" == true ]] && json_debug "TRIGGER: Fermeture de session SSH (raison: $closure_reason)"
    
    # Calcul de la durée totale de session si disponible
    if [[ -n "$SESSION_START_TIME" ]]; then
        local total_duration=$(echo "$session_end - $SESSION_START_TIME" | bc -l 2>/dev/null || echo "0.00")
        [[ "$DEBUG_MODE" == true ]] && json_debug "TRIGGER: Durée totale de session: ${total_duration}s"
        echo "$total_duration" > /tmp/ssh_session_duration_$$
    fi
    
    # Nettoyage des processus SSH actifs si nécessaire
    if [[ -n "$SSH_CONNECTION_PID" ]] && kill -0 "$SSH_CONNECTION_PID" 2>/dev/null; then
        [[ "$DEBUG_MODE" == true ]] && json_debug "TRIGGER: Terminaison du processus SSH PID: $SSH_CONNECTION_PID"
        kill -TERM "$SSH_CONNECTION_PID" 2>/dev/null || true
        sleep 1
        kill -KILL "$SSH_CONNECTION_PID" 2>/dev/null || true
    fi
    
    # Nettoyage des fichiers de session
    rm -f /tmp/ssh_session_*_$$ 2>/dev/null || true
    
    # Réinitialisation des variables d'état
    SSH_SESSION_ACTIVE=false
    SSH_CONNECTION_PID=""
    SESSION_START_TIME=""
    SESSION_CLEANUP_REQUIRED=false
    
    [[ "$DEBUG_MODE" == true ]] && json_success "TRIGGER: Session SSH fermée et nettoyée"
    
    return 0
}

# Vérification de l'état de session SSH
ssh_session_status_check() {
    local status_info=""
    
    if [[ "$SSH_SESSION_ACTIVE" == true ]]; then
        status_info="ACTIVE"
        [[ -n "$SESSION_START_TIME" ]] && {
            local current_time=$(date +%s.%N)
            local elapsed=$(echo "$current_time - $SESSION_START_TIME" | bc -l 2>/dev/null || echo "0.00")
            status_info="$status_info (${elapsed}s)"
        }
    else
        status_info="INACTIVE"
    fi
    
    [[ "$DEBUG_MODE" == true ]] && json_debug "STATUS: Session SSH $status_info"
    
    return 0
}

#===============================================================================
# FONCTIONS D'AIDE ET CONFIGURATION
#===============================================================================

show_help() {
    cat << EOF
$WORKFLOW_NAME - Orchestrateur de connexion SSH complète

USAGE:
    $(basename "$0") [OPTIONS]

DESCRIPTION:
    Orchestre un workflow SSH complet avec gestion d'état incluant :
    - TRIGGER: Initialisation de session SSH avec vérifications
    - Connexion SSH sécurisée sur le serveur cible
    - Navigation vers le répertoire cible (/root/scripts par défaut)
    - Exécution du ct-launcher.sh via session SSH distante
    - Affichage récursif du contenu du répertoire
    - Vérification d'état de session
    - TRIGGER: Fermeture propre et nettoyage de la session SSH

OPTIONS:
    -h, --host HOST         Serveur SSH cible (défaut: $DEFAULT_HOST)
    -u, --user USER         Utilisateur SSH (défaut: $DEFAULT_USER)
    -k, --key PATH          Chemin vers la clé SSH privée (optionnel)
    -t, --timeout SEC       Timeout de connexion en secondes (défaut: $CONNECTION_TIMEOUT)
    -d, --directory PATH    Répertoire cible à explorer (défaut: $DEFAULT_DIRECTORY)
    
    --quiet                 Mode silencieux (pas de sortie verbose)
    --force                 Force l'exécution même si des validations échouent
    --debug                 Active le mode debug avec traces détaillées
    --help                  Affiche cette aide

EXEMPLES:
    # Workflow par défaut
    $(basename "$0")
    
    # Avec serveur personnalisé
    $(basename "$0") --host 192.168.1.100 --user admin
    
    # Avec clé SSH spécifique
    $(basename "$0") --key ~/.ssh/id_rsa_server
    
    # Mode debug avec répertoire personnalisé
    $(basename "$0") --debug --directory /home/user/projects

SORTIE JSON:
    {
        "success": true|false,
        "workflow": "$WORKFLOW_NAME",
        "target": "user@host:directory", 
        "steps_completed": number,
        "total_steps": 7,
        "execution_time": "X.XXs",
        "results": {
            "session_init": {...},
            "connection": {...},
            "navigation": {...},
            "ct_launcher": {...},
            "listing": {...},
            "session_status": {...},
            "session_cleanup": {...}
        },
        "error": "message si échec"
    }

CODES DE RETOUR:
    0 : Succès - Workflow complété avec succès
    1 : Erreur de paramètres ou de validation
    2 : Échec de connexion SSH
    3 : Échec de navigation dans le répertoire
    4 : Échec d'affichage récursif
    5 : Échec de fermeture de session

CONFORMITÉ:
    - Méthodologie AtomicOps-Suite Niveau 1 (Orchestrateur)
    - Utilise les scripts atomiques ssh-connect.sh et ssh-execute-command.sh
    - Sortie JSON standardisée avec métriques de performance
    - Gestion d'erreurs robuste avec codes de retour spécifiques
EOF
}

#===============================================================================
# FONCTIONS DE VALIDATION
#===============================================================================

validate_parameters() {
    local errors=0
    
    # Validation de l'host
    if [[ -z "$HOST" ]]; then
        json_error "Host SSH obligatoire"
        ((errors++))
    fi
    
    # Validation du username
    if [[ -z "$USERNAME" ]]; then
        json_error "Nom d'utilisateur SSH obligatoire" 
        ((errors++))
    fi
    
    # Validation de la clé SSH si spécifiée
    if [[ -n "$SSH_KEY" ]] && [[ ! -f "$SSH_KEY" ]]; then
        json_error "Clé SSH non trouvée : $SSH_KEY"
        ((errors++))
    fi
    
    # Validation du timeout
    if ! [[ "$CONNECTION_TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$CONNECTION_TIMEOUT" -lt 5 ]]; then
        json_error "Timeout doit être un nombre >= 5 secondes"
        ((errors++))
    fi
    
    return $errors
}

check_dependencies() {
    local missing_deps=()
    
    # Vérification des scripts atomiques requis - utilisation du chemin correct
    local project_root="$(realpath "$SCRIPT_DIR/../../../../")"
    local ssh_connect="$project_root/atomics/network/ssh-connect.sh"
    local ssh_execute="$project_root/atomics/network/ssh-execute-command.sh"
    
    [[ ! -f "$ssh_connect" ]] && missing_deps+=("ssh-connect.sh at $ssh_connect")
    [[ ! -f "$ssh_execute" ]] && missing_deps+=("ssh-execute-command.sh at $ssh_execute")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        json_error "Scripts atomiques manquants : ${missing_deps[*]}"
        return 1
    fi
    
    # Stockage des chemins pour utilisation ultérieure
    ATOMIC_SSH_CONNECT="$ssh_connect"
    ATOMIC_SSH_EXECUTE="$ssh_execute"
    
    return 0
}

#===============================================================================
# FONCTIONS WORKFLOW PRINCIPAL
#===============================================================================

execute_ssh_connection() {
    local connection_start=$(date +%s.%N)
    
    [[ "$DEBUG_MODE" == true ]] && json_debug "Début connexion SSH vers $USERNAME@$HOST"
    
    # Construction des arguments pour ssh-connect
    local connect_args=(
        "--host" "$HOST"
        "--user" "$USERNAME" 
        "--timeout" "$CONNECTION_TIMEOUT"
    )
    
    # Ajout de la clé SSH si spécifiée
    [[ -n "$SSH_KEY" ]] && connect_args+=("--key" "$SSH_KEY")
    
    # Ajout des flags de mode
    [[ "$QUIET_MODE" == true ]] && connect_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && connect_args+=("--debug")
    
    # Exécution de la connexion SSH
    local connection_result
    if ! connection_result=$("$ATOMIC_SSH_CONNECT" "${connect_args[@]}" 2>&1); then
        json_error "Échec connexion SSH : $connection_result"
        return 2
    fi
    
    local connection_end=$(date +%s.%N)
    local connection_duration=$(echo "$connection_end - $connection_start" | bc -l 2>/dev/null || echo "0.00")
    
    [[ "$DEBUG_MODE" == true ]] && json_debug "Connexion SSH établie en ${connection_duration}s"
    
    # Stockage du résultat pour le JSON final
    echo "$connection_result" > /tmp/ssh_workflow_connection_$$
    echo "$connection_duration" > /tmp/ssh_workflow_connection_time_$$
    
    return 0
}

execute_directory_navigation() {
    local nav_start=$(date +%s.%N)
    
    [[ "$DEBUG_MODE" == true ]] && json_debug "Navigation vers le répertoire $TARGET_DIRECTORY"
    
    # Construction de la commande de navigation et vérification
    local nav_command="cd '$TARGET_DIRECTORY' && pwd && echo 'NAVIGATION_SUCCESS'"
    
    # Construction des arguments pour ssh-execute-command
    local execute_args=(
        "--host" "$HOST"
        "--user" "$USERNAME"
        "--command" "$nav_command"
        "--timeout" "$CONNECTION_TIMEOUT"
    )
    
    # Ajout de la clé SSH si spécifiée
    [[ -n "$SSH_KEY" ]] && execute_args+=("--key" "$SSH_KEY")
    
    # Ajout des flags de mode
    [[ "$QUIET_MODE" == true ]] && execute_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && execute_args+=("--debug")
    
    # Exécution de la navigation
    local nav_result
    if ! nav_result=$("$ATOMIC_SSH_EXECUTE" "${execute_args[@]}" 2>&1); then
        json_error "Échec navigation répertoire : $nav_result"
        return 3
    fi
    
    # Vérification que la navigation a réussi
    if ! echo "$nav_result" | grep -q "NAVIGATION_SUCCESS"; then
        json_error "Répertoire $TARGET_DIRECTORY inaccessible"
        return 3
    fi
    
    local nav_end=$(date +%s.%N)
    local nav_duration=$(echo "$nav_end - $nav_start" | bc -l 2>/dev/null || echo "0.00")
    
    [[ "$DEBUG_MODE" == true ]] && json_debug "Navigation complétée en ${nav_duration}s"
    
    # Stockage du résultat
    echo "$nav_result" > /tmp/ssh_workflow_navigation_$$
    echo "$nav_duration" > /tmp/ssh_workflow_navigation_time_$$
    
    return 0
}

execute_recursive_listing() {
    local listing_start=$(date +%s.%N)
    
    [[ "$DEBUG_MODE" == true ]] && json_debug "Affichage récursif du répertoire $TARGET_DIRECTORY"
    
    # Construction de la commande d'affichage récursif avec informations détaillées
    local listing_command="cd '$TARGET_DIRECTORY' && echo '=== CONTENU RÉCURSIF DE $TARGET_DIRECTORY ===' && ls -laR && echo '=== FIN AFFICHAGE RÉCURSIF ===' && echo 'LISTING_SUCCESS'"
    
    # Construction des arguments pour ssh-execute-command
    local execute_args=(
        "--host" "$HOST"
        "--user" "$USERNAME"
        "--command" "$listing_command"
        "--timeout" "$((CONNECTION_TIMEOUT * 2))"  # Timeout plus long pour ls -R
    )
    
    # Ajout de la clé SSH si spécifiée
    [[ -n "$SSH_KEY" ]] && execute_args+=("--key" "$SSH_KEY")
    
    # Ajout des flags de mode
    [[ "$QUIET_MODE" == true ]] && execute_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && execute_args+=("--debug")
    
    # Exécution de l'affichage récursif
    local listing_result
    if ! listing_result=$("$ATOMIC_SSH_EXECUTE" "${execute_args[@]}" 2>&1); then
        json_error "Échec affichage récursif : $listing_result"
        return 4
    fi
    
    # Vérification que l'affichage a réussi
    if ! echo "$listing_result" | grep -q "LISTING_SUCCESS"; then
        json_error "Échec lors de l'affichage récursif du répertoire"
        return 4
    fi
    
    local listing_end=$(date +%s.%N)
    local listing_duration=$(echo "$listing_end - $listing_start" | bc -l 2>/dev/null || echo "0.00")
    
    [[ "$DEBUG_MODE" == true ]] && json_debug "Affichage récursif complété en ${listing_duration}s"
    
    # Stockage du résultat
    echo "$listing_result" > /tmp/ssh_workflow_listing_$$
    echo "$listing_duration" > /tmp/ssh_workflow_listing_time_$$
    
    return 0
}

execute_ct_launcher() {
    local ct_launcher_start=$(date +%s.%N)
    
    [[ "$DEBUG_MODE" == true ]] && json_debug "Exécution de ct-launcher.sh via session SSH"
    
    # Construction de la commande pour exécuter ct-launcher.sh
    local ct_launcher_command="cd '$TARGET_DIRECTORY' && if [[ -f '$CT_LAUNCHER_SCRIPT' ]]; then echo 'LAUNCHER_FOUND' && chmod +x '$CT_LAUNCHER_SCRIPT' && ./$CT_LAUNCHER_SCRIPT --list && echo 'LAUNCHER_SUCCESS'; else echo 'LAUNCHER_NOT_FOUND: $CT_LAUNCHER_SCRIPT non trouvé dans $TARGET_DIRECTORY'; fi"
    
    # Construction des arguments pour ssh-execute-command
    local execute_args=(
        "--host" "$HOST"
        "--user" "$USERNAME"
        "--command" "$ct_launcher_command"
        "--timeout" "$((CONNECTION_TIMEOUT * 3))"  # Timeout plus long pour ct-launcher
    )
    
    # Ajout de la clé SSH si spécifiée
    [[ -n "$SSH_KEY" ]] && execute_args+=("--key" "$SSH_KEY")
    
    # Ajout des flags de mode
    [[ "$QUIET_MODE" == true ]] && execute_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && execute_args+=("--debug")
    
    # Exécution de ct-launcher.sh
    local launcher_result
    if ! launcher_result=$("$ATOMIC_SSH_EXECUTE" "${execute_args[@]}" 2>&1); then
        json_error "Échec exécution ct-launcher.sh : $launcher_result"
        return 4
    fi
    
    # Vérification que ct-launcher a été trouvé et exécuté
    if echo "$launcher_result" | grep -q "LAUNCHER_NOT_FOUND"; then
        json_error "ct-launcher.sh non trouvé dans $TARGET_DIRECTORY"
        return 4
    elif ! echo "$launcher_result" | grep -q "LAUNCHER_FOUND"; then
        json_error "Échec lors de la recherche de ct-launcher.sh"
        return 4
    fi
    
    local ct_launcher_end=$(date +%s.%N)
    local launcher_duration=$(echo "$ct_launcher_end - $ct_launcher_start" | bc -l 2>/dev/null || echo "0.00")
    
    [[ "$DEBUG_MODE" == true ]] && json_debug "ct-launcher.sh exécuté en ${launcher_duration}s"
    
    # Stockage du résultat
    echo "$launcher_result" > /tmp/ssh_workflow_ct_launcher_$$
    echo "$launcher_duration" > /tmp/ssh_workflow_ct_launcher_time_$$
    
    return 0
}

execute_session_closure() {
    local closure_start=$(date +%s.%N)
    
    [[ "$DEBUG_MODE" == true ]] && json_debug "Fermeture propre de la session SSH"
    
    # Construction de la commande de fermeture propre
    local closure_command="echo 'Session SSH fermée proprement' && exit 0"
    
    # Construction des arguments pour ssh-execute-command
    local execute_args=(
        "--host" "$HOST"
        "--user" "$USERNAME"
        "--command" "$closure_command"
        "--timeout" "10"  # Timeout court pour la fermeture
    )
    
    # Ajout de la clé SSH si spécifiée
    [[ -n "$SSH_KEY" ]] && execute_args+=("--key" "$SSH_KEY")
    
    # Ajout des flags de mode
    [[ "$QUIET_MODE" == true ]] && execute_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && execute_args+=("--debug")
    
    # Exécution de la fermeture (peut échouer naturellement)
    local closure_result
    closure_result=$("$ATOMIC_SSH_EXECUTE" "${execute_args[@]}" 2>&1 || echo "Session fermée")
    
    local closure_end=$(date +%s.%N)
    local closure_duration=$(echo "$closure_end - $closure_start" | bc -l 2>/dev/null || echo "0.00")
    
    [[ "$DEBUG_MODE" == true ]] && json_debug "Session SSH fermée en ${closure_duration}s"
    
    # Stockage du résultat
    echo "$closure_result" > /tmp/ssh_workflow_closure_$$
    echo "$closure_duration" > /tmp/ssh_workflow_closure_time_$$
    
    return 0
}

#===============================================================================
# FONCTION PRINCIPALE D'ORCHESTRATION
#===============================================================================

execute_workflow() {
    local workflow_start=$(date +%s.%N)
    local steps_completed=0
    local total_steps=7  # Ajout de l'étape ct-launcher
    
    [[ "$QUIET_MODE" == false ]] && json_info "Début du workflow SSH vers $USERNAME@$HOST:$TARGET_DIRECTORY"
    
    # ÉTAPE 0 : TRIGGER D'OUVERTURE DE SESSION
    [[ "$DEBUG_MODE" == true ]] && json_info "Étape 0/6 : Initialisation de session SSH"
    if ! ssh_session_open_trigger; then
        generate_error_json $? $steps_completed $total_steps "$workflow_start" "Échec initialisation session SSH"
        return 1
    fi
    ((steps_completed++))
    [[ "$DEBUG_MODE" == true ]] && json_success "Étape 0/6 : Session SSH initialisée"
    
    # ÉTAPE 1 : Connexion SSH
    [[ "$DEBUG_MODE" == true ]] && json_info "Étape 1/6 : Établissement connexion SSH"
    if ! execute_ssh_connection; then
        local connection_exit_code=$?
        ssh_session_close_trigger "connection_failed"
        generate_error_json $connection_exit_code $steps_completed $total_steps "$workflow_start" "Échec connexion SSH"
        return 2
    fi
    ((steps_completed++))
    [[ "$DEBUG_MODE" == true ]] && json_success "Étape 1/6 : Connexion SSH établie"
    
    # ÉTAPE 2 : Navigation vers le répertoire
    [[ "$DEBUG_MODE" == true ]] && json_info "Étape 2/6 : Navigation vers répertoire cible"
    if ! execute_directory_navigation; then
        ssh_session_close_trigger "navigation_failed"
        generate_error_json $? $steps_completed $total_steps "$workflow_start" "Échec navigation répertoire"
        return 3
    fi
    ((steps_completed++))
    [[ "$DEBUG_MODE" == true ]] && json_success "Étape 2/6 : Navigation répertoire réussie"
    
    # ÉTAPE 3 : Exécution de ct-launcher.sh via SSH
    [[ "$DEBUG_MODE" == true ]] && json_info "Étape 3/7 : Exécution de ct-launcher.sh via SSH"
    if ! execute_ct_launcher; then
        ssh_session_close_trigger "ct_launcher_failed"
        generate_error_json $? $steps_completed $total_steps "$workflow_start" "Échec exécution ct-launcher.sh"
        return 4
    fi
    ((steps_completed++))
    [[ "$DEBUG_MODE" == true ]] && json_success "Étape 3/7 : ct-launcher.sh exécuté avec succès"
    
    # ÉTAPE 4 : Affichage récursif
    [[ "$DEBUG_MODE" == true ]] && json_info "Étape 4/7 : Exploration récursive du contenu"
    if ! execute_recursive_listing; then
        ssh_session_close_trigger "listing_failed"
        generate_error_json $? $steps_completed $total_steps "$workflow_start" "Échec affichage récursif"
        return 5
    fi
    ((steps_completed++))
    [[ "$DEBUG_MODE" == true ]] && json_success "Étape 4/7 : Affichage récursif complété"
    
    # ÉTAPE 5 : Vérification d'état de session
    [[ "$DEBUG_MODE" == true ]] && json_info "Étape 5/7 : Vérification d'état de session"
    ssh_session_status_check
    ((steps_completed++))
    [[ "$DEBUG_MODE" == true ]] && json_success "Étape 5/7 : État de session vérifié"
    
    # ÉTAPE 6 : TRIGGER DE FERMETURE DE SESSION
    [[ "$DEBUG_MODE" == true ]] && json_info "Étape 6/7 : Fermeture propre de session SSH"
    if ! ssh_session_close_trigger "workflow_completed"; then
        generate_error_json $? $steps_completed $total_steps "$workflow_start" "Échec fermeture session SSH"
        return 6
    fi
    ((steps_completed++))
    [[ "$DEBUG_MODE" == true ]] && json_success "Étape 6/7 : Session SSH fermée proprement"
    
    # Génération du JSON de succès
    generate_success_json $steps_completed $total_steps "$workflow_start"
    
    [[ "$QUIET_MODE" == false ]] && json_success "Workflow SSH complété avec succès"
    
    return 0
}

#===============================================================================
# FONCTIONS DE GÉNÉRATION JSON
#===============================================================================

generate_success_json() {
    local steps_completed=$1
    local total_steps=$2
    local workflow_start=$3
    local workflow_end=$(date +%s.%N)
    local execution_time=$(echo "$workflow_end - $workflow_start" | bc -l 2>/dev/null || echo "0.00")
    
    # Lecture des résultats stockés
    local connection_result=$(cat /tmp/ssh_workflow_connection_$$ 2>/dev/null || echo "{}")
    local connection_time=$(cat /tmp/ssh_workflow_connection_time_$$ 2>/dev/null || echo "0.00")
    local navigation_result=$(cat /tmp/ssh_workflow_navigation_$$ 2>/dev/null || echo "{}")
    local navigation_time=$(cat /tmp/ssh_workflow_navigation_time_$$ 2>/dev/null || echo "0.00")
    local ct_launcher_result=$(cat /tmp/ssh_workflow_ct_launcher_$$ 2>/dev/null || echo "{}")
    local ct_launcher_time=$(cat /tmp/ssh_workflow_ct_launcher_time_$$ 2>/dev/null || echo "0.00")
    local listing_result=$(cat /tmp/ssh_workflow_listing_$$ 2>/dev/null || echo "{}")
    local listing_time=$(cat /tmp/ssh_workflow_listing_time_$$ 2>/dev/null || echo "0.00")
    local closure_result=$(cat /tmp/ssh_workflow_closure_$$ 2>/dev/null || echo "{}")
    local closure_time=$(cat /tmp/ssh_workflow_closure_time_$$ 2>/dev/null || echo "0.00")
    
    cat << EOF
{
    "success": true,
    "workflow": "$WORKFLOW_NAME",
    "target": "$USERNAME@$HOST:$TARGET_DIRECTORY",
    "steps_completed": $steps_completed,
    "total_steps": $total_steps,
    "execution_time": "${execution_time}s",
    "results": {
        "connection": {
            "duration": "${connection_time}s",
            "details": $connection_result
        },
        "navigation": {
            "duration": "${navigation_time}s", 
            "target_directory": "$TARGET_DIRECTORY",
            "details": $navigation_result
        },
        "ct_launcher": {
            "duration": "${ct_launcher_time}s",
            "script": "$CT_LAUNCHER_SCRIPT",
            "target_directory": "$TARGET_DIRECTORY",
            "details": $ct_launcher_result
        },
        "listing": {
            "duration": "${listing_time}s",
            "recursive": true,
            "details": $listing_result
        },
        "disconnection": {
            "duration": "${closure_time}s",
            "details": $closure_result
        }
    },
    "performance": {
        "total_time": "${execution_time}s",
        "connection_time": "${connection_time}s",
        "navigation_time": "${navigation_time}s",
        "ct_launcher_time": "${ct_launcher_time}s",
        "listing_time": "${listing_time}s",
        "closure_time": "${closure_time}s"
    }
}
EOF
    
    # Nettoyage des fichiers temporaires
    cleanup_temp_files
}

generate_error_json() {
    local exit_code=$1
    local steps_completed=$2
    local total_steps=$3
    local workflow_start=$4
    local error_message=$5
    local workflow_end=$(date +%s.%N)
    local execution_time=$(echo "$workflow_end - $workflow_start" | bc -l 2>/dev/null || echo "0.00")
    
    cat << EOF
{
    "success": false,
    "workflow": "$WORKFLOW_NAME",
    "target": "$USERNAME@$HOST:$TARGET_DIRECTORY",
    "steps_completed": $steps_completed,
    "total_steps": $total_steps,
    "execution_time": "${execution_time}s",
    "error": "$error_message",
    "exit_code": $exit_code
}
EOF
    
    # Nettoyage des fichiers temporaires
    cleanup_temp_files
}

cleanup_temp_files() {
    # Nettoyage des fichiers temporaires du workflow
    rm -f /tmp/ssh_workflow_*_$$ 2>/dev/null || true
    
    # Nettoyage des fichiers de session SSH
    rm -f /tmp/ssh_session_*_$$ 2>/dev/null || true
    
    # Fermeture de session SSH si nécessaire
    if [[ "$SESSION_CLEANUP_REQUIRED" == true ]]; then
        [[ "$DEBUG_MODE" == true ]] && json_debug "CLEANUP: Fermeture de session SSH requise"
        ssh_session_close_trigger "cleanup"
    fi
}

#===============================================================================
# GESTION DES ARGUMENTS
#===============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--host)
                HOST="$2"
                shift 2
                ;;
            -u|--user)
                USERNAME="$2"
                shift 2
                ;;
            -k|--key)
                SSH_KEY="$2"
                shift 2
                ;;
            -t|--timeout)
                CONNECTION_TIMEOUT="$2"
                shift 2
                ;;
            -d|--directory)
                TARGET_DIRECTORY="$2"
                shift 2
                ;;
            --quiet)
                QUIET_MODE=true
                shift
                ;;
            --force)
                FORCE_MODE=true
                shift
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                json_error "Argument inconnu : $1"
                show_help >&2
                exit 1
                ;;
        esac
    done
}

#===============================================================================
# FONCTION PRINCIPALE
#===============================================================================

main() {
    # Configuration du piégeage des signaux pour nettoyage SSH et fichiers temporaires
    trap 'cleanup_temp_files' EXIT
    trap 'ssh_session_close_trigger "interrupted"; cleanup_temp_files; exit 130' INT TERM
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des paramètres
    if ! validate_parameters; then
        exit 1
    fi
    
    # Vérification des dépendances
    if ! check_dependencies; then
        exit 1
    fi
    
    # Exécution du workflow principal
    execute_workflow
    local exit_code=$?
    
    # Nettoyage final
    cleanup_temp_files
    
    exit $exit_code
}

# Point d'entrée du script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi