#!/usr/bin/env bash

#===============================================================================
# Script Orchestrateur : Déploiement et Exécution de Script Distant
#===============================================================================
# Nom du fichier : deploy-script.remote.sh
# Niveau : 1 (Orchestrateur)
# Catégorie : network
# Protocole : ssh
# Description : Orchestre le déploiement et l'exécution d'un script sur un hôte distant
#
# Objectif :
# - Déploiement complet d'un script sur serveur distant via SSH
# - Validation de connectivité et préparation de l'environnement
# - Transfert sécurisé du script et de ses dépendances
# - Exécution avec récupération des résultats JSON
# - Nettoyage automatique des fichiers temporaires
#
# Conforme à la méthodologie AtomicOps-Suite - Niveau 1 (Orchestrateur)
#===============================================================================

set -euo pipefail

# === MÉTADONNÉES DU SCRIPT ===
readonly SCRIPT_NAME="deploy-script.remote.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_CATEGORY="network"
readonly SCRIPT_PROTOCOL="ssh"
readonly SCRIPT_LEVEL=1

# === CHEMINS DES SCRIPTS ATOMIQUES ===
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ATOMICS_DIR="$(realpath "$SCRIPT_DIR/../../atomics")"
readonly CHECK_SSH_SCRIPT="$ATOMICS_DIR/network/check-ssh.connection.sh"
readonly COPY_FILE_SCRIPT="$ATOMICS_DIR/network/copy-file.remote.sh"
readonly EXECUTE_SSH_SCRIPT="$ATOMICS_DIR/network/execute-ssh.remote.sh"

# === CONFIGURATION PAR DÉFAUT ===
readonly DEFAULT_SSH_PORT=22
readonly DEFAULT_USER="$(whoami)"
readonly DEFAULT_REMOTE_WORKDIR="/tmp"

# === VARIABLES GLOBALES ===
TARGET_HOST=""
TARGET_PORT="$DEFAULT_SSH_PORT"
TARGET_USER="$DEFAULT_USER"
SSH_KEY_FILE=""
LOCAL_SCRIPT_PATH=""
REMOTE_WORKDIR="$DEFAULT_REMOTE_WORKDIR"
SCRIPT_ARGUMENTS=""
DEPENDENCY_PATHS=()
ENVIRONMENT_VARS=""
CLEANUP_AFTER=true
VALIDATE_BEFORE=true
TIMEOUT_SECONDS=300
RETRY_COUNT=3
DRY_RUN=false
QUIET_MODE=false
DEBUG_MODE=false
VERBOSE_MODE=false

# === FONCTIONS D'AIDE ===
show_help() {
    cat << EOF
Déploiement et Exécution de Script Distant - Orchestrateur Niveau 1

USAGE:
    $(basename "$0") [OPTIONS] HOST SCRIPT_PATH

DESCRIPTION:
    Orchestre le déploiement complet d'un script sur un serveur distant :
    1. Validation de la connectivité SSH avec l'hôte cible
    2. Transfert sécurisé du script principal et de ses dépendances
    3. Préparation de l'environnement d'exécution distant
    4. Exécution du script avec arguments et variables d'environnement
    5. Récupération des résultats JSON de l'exécution
    6. Nettoyage automatique des fichiers temporaires distants

PARAMÈTRES OBLIGATOIRES:
    HOST                    Nom d'hôte ou adresse IP du serveur distant
    SCRIPT_PATH             Chemin du script local à déployer et exécuter

OPTIONS PRINCIPALES:
    -p, --port PORT         Port SSH (défaut: 22)
    -u, --user USER         Utilisateur SSH (défaut: current user)
    -i, --identity FILE     Fichier de clé privée SSH
    -w, --workdir PATH      Répertoire de travail distant (défaut: /tmp)
    -a, --args "ARGUMENTS"  Arguments à passer au script distant
    
OPTIONS DE DÉPENDANCES:
    -d, --dependency FILE   Fichier de dépendance à transférer (répétable)
    --lib-dir DIRECTORY     Répertoire de bibliothèques à transférer
    -e, --env "VAR=value"   Variables d'environnement (répétable)
    
OPTIONS DE CONTRÔLE:
    --no-validate           Ne pas valider la connectivité SSH avant
    --no-cleanup            Laisser les fichiers sur le serveur distant
    -t, --timeout SECONDS   Timeout global d'exécution (défaut: 300)
    -r, --retries NUMBER    Nombre de tentatives de retry (défaut: 3)
    --dry-run               Simulation (affiche les actions sans les exécuter)
    
OPTIONS D'AFFICHAGE:
    -v, --verbose           Mode verbose avec détails des opérations
    -q, --quiet             Mode silencieux (erreurs uniquement)
    --debug                 Mode debug avec traces détaillées
    -h, --help              Affiche cette aide

EXEMPLES:
    # Déploiement simple d'un script
    $(basename "$0") server.com ./mon-script.sh
    
    # Avec arguments et variables d'environnement
    $(basename "$0") --args "-v --config prod" --env "ENV=production" server.com ./deploy.sh
    
    # Avec dépendances et répertoire de travail spécifique
    $(basename "$0") --dependency ./config.yml --lib-dir ./lib --workdir /opt/app server.com ./setup.sh
    
    # Authentification par clé avec timeout augmenté
    $(basename "$0") --identity ~/.ssh/deploy_key --timeout 600 --user deploy server.com ./migration.sh
    
    # Dry-run pour prévisualiser les actions
    $(basename "$0") --dry-run --verbose server.com ./maintenance.sh
    
    # Sans validation préalable et sans nettoyage
    $(basename "$0") --no-validate --no-cleanup server.com ./permanent-install.sh

WORKFLOW ORCHESTRÉ:
    1. check-ssh.connection.sh    - Validation connectivité SSH
    2. copy-file.remote.sh        - Transfert script principal
    3. copy-file.remote.sh        - Transfert dépendances (×N)
    4. execute-ssh.remote.sh      - Préparation environnement
    5. execute-ssh.remote.sh      - Exécution du script
    6. execute-ssh.remote.sh      - Nettoyage (optionnel)

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
            "deployment": {
                "script_path": "/local/path/script.sh",
                "remote_workdir": "/remote/workdir",
                "arguments": "script arguments",
                "dependencies_count": number,
                "environment_vars": {"VAR": "value"}
            },
            "orchestration": {
                "connectivity_check": {...},
                "file_transfers": [...],
                "script_execution": {...},
                "cleanup_performed": boolean
            },
            "performance": {
                "total_duration_ms": number,
                "connectivity_time_ms": number,
                "transfer_time_ms": number,
                "execution_time_ms": number
            },
            "result": {
                "exit_code": number,
                "stdout": "string",
                "stderr": "string",
                "files_transferred": number,
                "bytes_transferred": number
            }
        }
    }

CODES DE RETOUR:
    0 : Succès - Script déployé et exécuté avec succès
    1 : Erreur de paramètres ou de validation
    2 : Échec de connectivité SSH
    3 : Échec de transfert de fichiers
    4 : Échec d'exécution du script distant
    5 : Timeout global dépassé

SCRIPTS ATOMIQUES UTILISÉS:
    - check-ssh.connection.sh     : Test de connectivité SSH
    - copy-file.remote.sh         : Transfert sécurisé de fichiers
    - execute-ssh.remote.sh       : Exécution de commandes SSH distantes

CONFORMITÉ:
    - Méthodologie AtomicOps-Suite Niveau 1 (Orchestrateur)
    - Composition de scripts atomiques uniquement
    - Sortie JSON standardisée
    - Gestion d'erreurs robuste avec rollback
EOF
}

# === FONCTIONS DE LOGGING ===
log_debug() { [[ "$DEBUG_MODE" == true ]] && echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_info() { [[ "$QUIET_MODE" == false ]] && echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_verbose() { [[ "$VERBOSE_MODE" == true ]] && echo "[VERBOSE] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }

# === VALIDATION DES DÉPENDANCES ===
validate_dependencies() {
    local errors=0
    
    # Vérification de l'existence des scripts atomiques
    local required_scripts=("$CHECK_SSH_SCRIPT" "$COPY_FILE_SCRIPT" "$EXECUTE_SSH_SCRIPT")
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_error "Script atomique manquant : $script"
            ((errors++))
        elif [[ ! -x "$script" ]]; then
            log_error "Script atomique non exécutable : $script"
            ((errors++))
        fi
    done
    
    return $errors
}

# === VALIDATION DES PARAMÈTRES ===
validate_parameters() {
    local errors=0
    
    # Validation de l'hôte obligatoire
    if [[ -z "$TARGET_HOST" ]]; then
        log_error "Hôte cible obligatoire"
        ((errors++))
    fi
    
    # Validation du script local
    if [[ -z "$LOCAL_SCRIPT_PATH" ]]; then
        log_error "Chemin du script local obligatoire"
        ((errors++))
    elif [[ ! -f "$LOCAL_SCRIPT_PATH" ]]; then
        log_error "Script local non trouvé : $LOCAL_SCRIPT_PATH"
        ((errors++))
    elif [[ ! -r "$LOCAL_SCRIPT_PATH" ]]; then
        log_error "Script local non lisible : $LOCAL_SCRIPT_PATH"
        ((errors++))
    fi
    
    # Validation des fichiers de dépendance
    for dep_file in "${DEPENDENCY_PATHS[@]}"; do
        if [[ ! -e "$dep_file" ]]; then
            log_error "Fichier de dépendance non trouvé : $dep_file"
            ((errors++))
        elif [[ ! -r "$dep_file" ]]; then
            log_error "Fichier de dépendance non lisible : $dep_file"
            ((errors++))
        fi
    done
    
    # Validation du port SSH
    if [[ ! "$TARGET_PORT" =~ ^[0-9]+$ ]] || [[ "$TARGET_PORT" -lt 1 ]] || [[ "$TARGET_PORT" -gt 65535 ]]; then
        log_error "Port SSH invalide : $TARGET_PORT"
        ((errors++))
    fi
    
    # Validation du timeout
    if [[ ! "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || [[ "$TIMEOUT_SECONDS" -lt 1 ]]; then
        log_error "Timeout invalide : $TIMEOUT_SECONDS"
        ((errors++))
    fi
    
    # Validation du fichier de clé SSH si spécifié
    if [[ -n "$SSH_KEY_FILE" ]]; then
        if [[ ! -f "$SSH_KEY_FILE" ]]; then
            log_error "Fichier de clé SSH non trouvé : $SSH_KEY_FILE"
            ((errors++))
        elif [[ ! -r "$SSH_KEY_FILE" ]]; then
            log_error "Fichier de clé SSH non lisible : $SSH_KEY_FILE"
            ((errors++))
        fi
    fi
    
    return $errors
}

# === VALIDATION DE LA CONNECTIVITÉ SSH ===
validate_ssh_connectivity() {
    if [[ "$VALIDATE_BEFORE" == false ]]; then
        echo '{"status": "skipped", "connection_time_ms": 0}' > /tmp/connectivity_result_$$
        return 0
    fi
    
    log_info "Étape 1/6 : Validation de la connectivité SSH"
    
    local connectivity_start=$(date +%s.%N)
    local ssh_check_cmd=("$CHECK_SSH_SCRIPT")
    
    # Construction des arguments pour check-ssh.connection.sh
    ssh_check_cmd+=("--port" "$TARGET_PORT")
    ssh_check_cmd+=("--user" "$TARGET_USER")
    ssh_check_cmd+=("--timeout" "30")
    
    [[ -n "$SSH_KEY_FILE" ]] && ssh_check_cmd+=("--identity" "$SSH_KEY_FILE")
    [[ "$QUIET_MODE" == true ]] && ssh_check_cmd+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && ssh_check_cmd+=("--debug")
    
    ssh_check_cmd+=("$TARGET_HOST")
    
    log_debug "Commande de vérification SSH : ${ssh_check_cmd[*]}"
    
    local check_result
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Validation SSH simulée"
        check_result='{"status": "success", "data": {"ssh_connection": {"status": "success"}}}'
    else
        if check_result=$("${ssh_check_cmd[@]}" 2>/dev/null); then
            local ssh_status=$(echo "$check_result" | jq -r '.data.ssh_connection.status' 2>/dev/null || echo "failed")
            
            if [[ "$ssh_status" == "success" ]]; then
                log_verbose "Connectivité SSH validée avec succès"
            else
                log_error "Échec de validation de la connectivité SSH"
                echo "$check_result" > /tmp/connectivity_result_$$
                return 2
            fi
        else
            log_error "Erreur lors de l'exécution du test de connectivité SSH"
            return 2
        fi
    fi
    
    local connectivity_end=$(date +%s.%N)
    local connectivity_time=$(echo "($connectivity_end - $connectivity_start) * 1000" | bc -l 2>/dev/null || echo "0")
    
    # Extraction du temps de connexion depuis le résultat
    local connection_time_ms=$(echo "$check_result" | jq -r '.data.performance.connection_latency' 2>/dev/null || echo "0")
    
    # Stockage du résultat
    cat << EOF > /tmp/connectivity_result_$$
{
    "status": "success",
    "connection_time_ms": $connection_time_ms,
    "full_result": $check_result
}
EOF
    
    return 0
}

# === TRANSFERT DU SCRIPT PRINCIPAL ===
transfer_main_script() {
    log_info "Étape 2/6 : Transfert du script principal"
    
    local transfer_start=$(date +%s.%N)
    local script_name=$(basename "$LOCAL_SCRIPT_PATH")
    local remote_script_path="$REMOTE_WORKDIR/$script_name"
    
    local copy_cmd=("$COPY_FILE_SCRIPT")
    copy_cmd+=("--upload")
    copy_cmd+=("--method" "scp")
    copy_cmd+=("--port" "$TARGET_PORT")
    copy_cmd+=("--user" "$TARGET_USER")
    copy_cmd+=("--verify-checksum")
    
    [[ -n "$SSH_KEY_FILE" ]] && copy_cmd+=("--identity" "$SSH_KEY_FILE")
    [[ "$QUIET_MODE" == true ]] && copy_cmd+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && copy_cmd+=("--debug")
    [[ "$DRY_RUN" == true ]] && copy_cmd+=("--dry-run")
    
    copy_cmd+=("$TARGET_HOST" "$LOCAL_SCRIPT_PATH" "$remote_script_path")
    
    log_debug "Commande de transfert : ${copy_cmd[*]}"
    
    local transfer_result
    if transfer_result=$("${copy_cmd[@]}" 2>/dev/null); then
        local copy_status=$(echo "$transfer_result" | jq -r '.status' 2>/dev/null || echo "error")
        
        if [[ "$copy_status" == "success" ]]; then
            log_verbose "Script principal transféré avec succès : $remote_script_path"
        else
            log_error "Échec du transfert du script principal"
            echo "$transfer_result" > /tmp/main_transfer_result_$$
            return 3
        fi
    else
        log_error "Erreur lors du transfert du script principal"
        return 3
    fi
    
    local transfer_end=$(date +%s.%N)
    local transfer_time=$(echo "($transfer_end - $transfer_start) * 1000" | bc -l 2>/dev/null || echo "0")
    
    # Stockage du résultat avec le chemin distant
    echo "$transfer_result" | jq --arg remote_path "$remote_script_path" '. + {"remote_script_path": $remote_path}' > /tmp/main_transfer_result_$$ 2>/dev/null || echo "$transfer_result" > /tmp/main_transfer_result_$$
    
    return 0
}

# === TRANSFERT DES DÉPENDANCES ===
transfer_dependencies() {
    log_info "Étape 3/6 : Transfert des dépendances (${#DEPENDENCY_PATHS[@]} fichier(s))"
    
    if [[ ${#DEPENDENCY_PATHS[@]} -eq 0 ]]; then
        echo '[]' > /tmp/dependency_transfers_$$
        return 0
    fi
    
    local transfer_results=()
    local transfer_start=$(date +%s.%N)
    
    for dep_file in "${DEPENDENCY_PATHS[@]}"; do
        local dep_name=$(basename "$dep_file")
        local remote_dep_path="$REMOTE_WORKDIR/$dep_name"
        
        log_verbose "Transfert de dépendance : $dep_file → $remote_dep_path"
        
        local copy_cmd=("$COPY_FILE_SCRIPT")
        copy_cmd+=("--upload")
        copy_cmd+=("--method" "scp")
        copy_cmd+=("--port" "$TARGET_PORT")
        copy_cmd+=("--user" "$TARGET_USER")
        
        # Si c'est un répertoire, activer le mode récursif
        [[ -d "$dep_file" ]] && copy_cmd+=("--recursive")
        
        [[ -n "$SSH_KEY_FILE" ]] && copy_cmd+=("--identity" "$SSH_KEY_FILE")
        [[ "$QUIET_MODE" == true ]] && copy_cmd+=("--quiet")
        [[ "$DEBUG_MODE" == true ]] && copy_cmd+=("--debug")
        [[ "$DRY_RUN" == true ]] && copy_cmd+=("--dry-run")
        
        copy_cmd+=("$TARGET_HOST" "$dep_file" "$remote_dep_path")
        
        local dep_result
        if dep_result=$("${copy_cmd[@]}" 2>/dev/null); then
            local dep_status=$(echo "$dep_result" | jq -r '.status' 2>/dev/null || echo "error")
            
            if [[ "$dep_status" == "success" ]]; then
                log_verbose "Dépendance transférée : $dep_name"
                transfer_results+=("$dep_result")
            else
                log_error "Échec du transfert de dépendance : $dep_file"
                return 3
            fi
        else
            log_error "Erreur lors du transfert de dépendance : $dep_file"
            return 3
        fi
    done
    
    local transfer_end=$(date +%s.%N)
    local transfer_time=$(echo "($transfer_end - $transfer_start) * 1000" | bc -l 2>/dev/null || echo "0")
    
    # Stockage des résultats de transfert des dépendances
    local deps_json="[$(IFS=,; echo "${transfer_results[*]}")]"
    echo "$deps_json" > /tmp/dependency_transfers_$$
    
    return 0
}

# === PRÉPARATION DE L'ENVIRONNEMENT DISTANT ===
prepare_remote_environment() {
    log_info "Étape 4/6 : Préparation de l'environnement distant"
    
    # Commandes de préparation
    local prep_commands=(
        "mkdir -p '$REMOTE_WORKDIR'"
        "cd '$REMOTE_WORKDIR'"
        "chmod +x *.sh 2>/dev/null || true"
    )
    
    local exec_cmd=("$EXECUTE_SSH_SCRIPT")
    exec_cmd+=("--port" "$TARGET_PORT")
    exec_cmd+=("--user" "$TARGET_USER")
    exec_cmd+=("--timeout" "30")
    
    [[ -n "$SSH_KEY_FILE" ]] && exec_cmd+=("--identity" "$SSH_KEY_FILE")
    [[ "$QUIET_MODE" == true ]] && exec_cmd+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && exec_cmd+=("--debug")
    [[ "$DRY_RUN" == true ]] && exec_cmd+=("--dry-run")
    
    exec_cmd+=("$TARGET_HOST")
    exec_cmd+=("$(IFS='; '; echo "${prep_commands[*]}")")
    
    log_debug "Commande de préparation : ${exec_cmd[*]}"
    
    local prep_result
    if prep_result=$("${exec_cmd[@]}" 2>/dev/null); then
        local prep_status=$(echo "$prep_result" | jq -r '.status' 2>/dev/null || echo "error")
        
        if [[ "$prep_status" == "success" ]]; then
            log_verbose "Environnement distant préparé avec succès"
        else
            log_error "Échec de la préparation de l'environnement distant"
            echo "$prep_result" > /tmp/preparation_result_$$
            return 4
        fi
    else
        log_error "Erreur lors de la préparation de l'environnement"
        return 4
    fi
    
    echo "$prep_result" > /tmp/preparation_result_$$
    return 0
}

# === EXÉCUTION DU SCRIPT DISTANT ===
execute_remote_script() {
    log_info "Étape 5/6 : Exécution du script distant"
    
    local script_name=$(basename "$LOCAL_SCRIPT_PATH")
    local remote_script_path="$REMOTE_WORKDIR/$script_name"
    
    # Construction de la commande d'exécution
    local execution_command="cd '$REMOTE_WORKDIR' && ./$script_name"
    
    # Ajout des arguments si spécifiés
    if [[ -n "$SCRIPT_ARGUMENTS" ]]; then
        execution_command="$execution_command $SCRIPT_ARGUMENTS"
    fi
    
    local exec_cmd=("$EXECUTE_SSH_SCRIPT")
    exec_cmd+=("--port" "$TARGET_PORT")
    exec_cmd+=("--user" "$TARGET_USER")
    exec_cmd+=("--timeout" "$TIMEOUT_SECONDS")
    exec_cmd+=("--retries" "$RETRY_COUNT")
    
    # Ajout des variables d'environnement si spécifiées
    if [[ -n "$ENVIRONMENT_VARS" ]]; then
        exec_cmd+=("--env" "$ENVIRONMENT_VARS")
    fi
    
    # Spécification du répertoire de travail
    exec_cmd+=("--workdir" "$REMOTE_WORKDIR")
    
    [[ -n "$SSH_KEY_FILE" ]] && exec_cmd+=("--identity" "$SSH_KEY_FILE")
    [[ "$QUIET_MODE" == true ]] && exec_cmd+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && exec_cmd+=("--debug")
    [[ "$DRY_RUN" == true ]] && exec_cmd+=("--dry-run")
    
    exec_cmd+=("$TARGET_HOST")
    exec_cmd+=("$execution_command")
    
    log_debug "Commande d'exécution : ${exec_cmd[*]}"
    log_info "Exécution de : $execution_command"
    
    local execution_result
    if execution_result=$("${exec_cmd[@]}" 2>/dev/null); then
        local exec_status=$(echo "$execution_result" | jq -r '.status' 2>/dev/null || echo "error")
        local exit_code=$(echo "$execution_result" | jq -r '.data.result.exit_code' 2>/dev/null || echo "1")
        
        if [[ "$exec_status" == "success" && "$exit_code" == "0" ]]; then
            log_verbose "Script exécuté avec succès (code: $exit_code)"
        else
            log_error "Échec de l'exécution du script distant (code: $exit_code)"
            echo "$execution_result" > /tmp/execution_result_$$
            return 4
        fi
    else
        log_error "Erreur lors de l'exécution du script distant"
        return 4
    fi
    
    echo "$execution_result" > /tmp/execution_result_$$
    return 0
}

# === NETTOYAGE DES FICHIERS TEMPORAIRES DISTANTS ===
cleanup_remote_files() {
    if [[ "$CLEANUP_AFTER" == false ]]; then
        log_info "Étape 6/6 : Nettoyage désactivé - fichiers conservés sur le serveur"
        echo '{"status": "skipped"}' > /tmp/cleanup_result_$$
        return 0
    fi
    
    log_info "Étape 6/6 : Nettoyage des fichiers temporaires distants"
    
    # Liste des fichiers à nettoyer
    local cleanup_files=()
    cleanup_files+=("$(basename "$LOCAL_SCRIPT_PATH")")
    
    for dep_file in "${DEPENDENCY_PATHS[@]}"; do
        cleanup_files+=("$(basename "$dep_file")")
    done
    
    # Commande de nettoyage
    local cleanup_command="cd '$REMOTE_WORKDIR' && rm -f $(IFS=' '; echo "${cleanup_files[*]}")"
    
    local exec_cmd=("$EXECUTE_SSH_SCRIPT")
    exec_cmd+=("--port" "$TARGET_PORT")
    exec_cmd+=("--user" "$TARGET_USER")
    exec_cmd+=("--timeout" "30")
    
    [[ -n "$SSH_KEY_FILE" ]] && exec_cmd+=("--identity" "$SSH_KEY_FILE")
    [[ "$QUIET_MODE" == true ]] && exec_cmd+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && exec_cmd+=("--debug")
    [[ "$DRY_RUN" == true ]] && exec_cmd+=("--dry-run")
    
    exec_cmd+=("$TARGET_HOST")
    exec_cmd+=("$cleanup_command")
    
    log_debug "Commande de nettoyage : ${exec_cmd[*]}"
    
    local cleanup_result
    if cleanup_result=$("${exec_cmd[@]}" 2>/dev/null); then
        local cleanup_status=$(echo "$cleanup_result" | jq -r '.status' 2>/dev/null || echo "error")
        
        if [[ "$cleanup_status" == "success" ]]; then
            log_verbose "Nettoyage des fichiers temporaires terminé"
        else
            log_error "Échec du nettoyage (non critique)"
        fi
    else
        log_error "Erreur lors du nettoyage (non critique)"
    fi
    
    echo "$cleanup_result" > /tmp/cleanup_result_$$
    return 0
}

# === GÉNÉRATION DE LA SORTIE JSON ===
generate_output() {
    local status="$1"
    local start_time="$2"
    local end_time="$3"
    
    # Lecture des résultats de toutes les étapes
    local connectivity_result=$(cat /tmp/connectivity_result_$$ 2>/dev/null || echo '{"status": "skipped", "connection_time_ms": 0}')
    local main_transfer_result=$(cat /tmp/main_transfer_result_$$ 2>/dev/null || echo '{"status": "error"}')
    local dependency_transfers=$(cat /tmp/dependency_transfers_$$ 2>/dev/null || echo '[]')
    local preparation_result=$(cat /tmp/preparation_result_$$ 2>/dev/null || echo '{"status": "error"}')
    local execution_result=$(cat /tmp/execution_result_$$ 2>/dev/null || echo '{"status": "error"}')
    local cleanup_result=$(cat /tmp/cleanup_result_$$ 2>/dev/null || echo '{"status": "skipped"}')
    
    # Extraction des métriques de performance
    local start_time_sec=$(date -d "$start_time" +%s.%N 2>/dev/null || echo "0")
    local end_time_sec=$(date -d "$end_time" +%s.%N 2>/dev/null || echo "0")
    local total_duration_ms=$(echo "($end_time_sec - $start_time_sec) * 1000" | bc -l 2>/dev/null || echo "0")
    
    local connectivity_time_ms=$(echo "$connectivity_result" | jq -r '.connection_time_ms' 2>/dev/null || echo "0")
    local transfer_time_ms=$(echo "$main_transfer_result" | jq -r '.data.performance.transfer_time_ms' 2>/dev/null || echo "0")
    local execution_time_ms=$(echo "$execution_result" | jq -r '.data.performance.total_time_ms' 2>/dev/null || echo "0")
    
    # Extraction des résultats d'exécution
    local exit_code=$(echo "$execution_result" | jq -r '.data.result.exit_code' 2>/dev/null || echo "1")
    local stdout_content=$(echo "$execution_result" | jq -r '.data.result.stdout' 2>/dev/null || echo "")
    local stderr_content=$(echo "$execution_result" | jq -r '.data.result.stderr' 2>/dev/null || echo "")
    
    # Calcul des statistiques de transfert
    local files_transferred=$(( 1 + ${#DEPENDENCY_PATHS[@]} ))
    local bytes_transferred=$(echo "$main_transfer_result" | jq -r '.data.result.bytes_transferred' 2>/dev/null || echo "0")
    
    # Conversion des variables d'environnement en JSON
    local env_vars_json="{}"
    if [[ -n "$ENVIRONMENT_VARS" ]]; then
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
        "deployment": {
            "script_path": "$LOCAL_SCRIPT_PATH",
            "remote_workdir": "$REMOTE_WORKDIR",
            "arguments": "$SCRIPT_ARGUMENTS",
            "dependencies_count": ${#DEPENDENCY_PATHS[@]},
            "environment_vars": $env_vars_json
        },
        "orchestration": {
            "connectivity_check": $connectivity_result,
            "file_transfers": {
                "main_script": $main_transfer_result,
                "dependencies": $dependency_transfers
            },
            "script_execution": $execution_result,
            "cleanup_performed": $(echo "$cleanup_result" | jq -r '.status' 2>/dev/null | grep -q "success" && echo "true" || echo "false")
        },
        "performance": {
            "total_duration_ms": $(printf "%.0f" "$total_duration_ms"),
            "connectivity_time_ms": $(printf "%.0f" "$connectivity_time_ms"),
            "transfer_time_ms": $(printf "%.0f" "$transfer_time_ms"),
            "execution_time_ms": $(printf "%.0f" "$execution_time_ms")
        },
        "result": {
            "exit_code": $exit_code,
            "stdout": "$stdout_content",
            "stderr": "$stderr_content",
            "files_transferred": $files_transferred,
            "bytes_transferred": $bytes_transferred
        }
    }
}
EOF
}

# === NETTOYAGE DES FICHIERS TEMPORAIRES ===
cleanup() {
    rm -f /tmp/connectivity_result_$$ /tmp/main_transfer_result_$$ /tmp/dependency_transfers_$$ /tmp/preparation_result_$$ /tmp/execution_result_$$ /tmp/cleanup_result_$$ 2>/dev/null || true
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
            -w|--workdir)
                REMOTE_WORKDIR="$2"
                shift 2
                ;;
            -a|--args)
                SCRIPT_ARGUMENTS="$2"
                shift 2
                ;;
            -d|--dependency)
                DEPENDENCY_PATHS+=("$2")
                shift 2
                ;;
            --lib-dir)
                DEPENDENCY_PATHS+=("$2")
                shift 2
                ;;
            -e|--env)
                ENVIRONMENT_VARS="$ENVIRONMENT_VARS $2"
                shift 2
                ;;
            --no-validate)
                VALIDATE_BEFORE=false
                shift
                ;;
            --no-cleanup)
                CLEANUP_AFTER=false
                shift
                ;;
            -t|--timeout)
                TIMEOUT_SECONDS="$2"
                shift 2
                ;;
            -r|--retries)
                RETRY_COUNT="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
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
                elif [[ -z "$LOCAL_SCRIPT_PATH" ]]; then
                    LOCAL_SCRIPT_PATH="$1"
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
    
    # Configuration du piégeage pour nettoyage
    trap cleanup EXIT INT TERM
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des dépendances
    if ! validate_dependencies; then
        log_error "Dépendances manquantes - vérifiez l'installation des scripts atomiques"
        exit 1
    fi
    
    # Validation des paramètres
    if ! validate_parameters; then
        exit 1
    fi
    
    log_debug "Début du déploiement de script distant : $LOCAL_SCRIPT_PATH → $TARGET_USER@$TARGET_HOST"
    
    # Workflow orchestré en 6 étapes
    local workflow_success=true
    local exit_code=0
    
    # Étape 1 : Validation de la connectivité SSH
    if ! validate_ssh_connectivity; then
        workflow_success=false
        exit_code=2
    fi
    
    # Étape 2 : Transfert du script principal
    if [[ "$workflow_success" == true ]] && ! transfer_main_script; then
        workflow_success=false
        exit_code=3
    fi
    
    # Étape 3 : Transfert des dépendances
    if [[ "$workflow_success" == true ]] && ! transfer_dependencies; then
        workflow_success=false
        exit_code=3
    fi
    
    # Étape 4 : Préparation de l'environnement distant
    if [[ "$workflow_success" == true ]] && ! prepare_remote_environment; then
        workflow_success=false
        exit_code=4
    fi
    
    # Étape 5 : Exécution du script distant
    if [[ "$workflow_success" == true ]] && ! execute_remote_script; then
        workflow_success=false
        exit_code=4
    fi
    
    # Étape 6 : Nettoyage (toujours tenté, même en cas d'échec)
    cleanup_remote_files
    
    local end_time=$(date -Iseconds)
    
    # Génération du rapport final
    local final_status=$([ "$workflow_success" == true ] && echo "success" || echo "error")
    generate_output "$final_status" "$start_time" "$end_time"
    
    if [[ "$workflow_success" == true ]]; then
        log_info "Déploiement et exécution terminés avec succès"
    else
        log_error "Échec du déploiement de script distant"
    fi
    
    return $exit_code
}

# Point d'entrée du script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi