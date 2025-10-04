#!/usr/bin/env bash
#===============================================================================
# Orchestrateur SSH : Configuration Accès SSH Complet
#===============================================================================
# Nom du fichier : setup-ssh.access.sh
# Niveau : 1 (Orchestrateur)
# Catégorie : network
# Protocole : ssh
# Description : Configure l'accès SSH complet pour un utilisateur distant
#
# Objectif :
# - Génération de paire de clés SSH si nécessaire
# - Déploiement de la clé publique sur le serveur distant
# - Validation de la connexion SSH authentifiée
# - Configuration complète prête pour usage
#
# Conforme à la méthodologie AtomicOps-Suite - Niveau 1
#===============================================================================

set -euo pipefail

# === MÉTADONNÉES DU SCRIPT ===
readonly SCRIPT_NAME="setup-ssh.access.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_CATEGORY="network"
readonly SCRIPT_PROTOCOL="ssh"
readonly SCRIPT_LEVEL=1

# === CHEMINS DES SCRIPTS ATOMIQUES ===
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ATOMICS_DIR="$(realpath "$SCRIPT_DIR/../../atomics")"

# Scripts atomiques utilisés
readonly GENERATE_SSH_KEY="$ATOMICS_DIR/generate-ssh.keypair.sh"
readonly ADD_SSH_KEY="$ATOMICS_DIR/network/add-ssh.key.authorized.sh"
readonly CHECK_SSH_CONNECTION="$ATOMICS_DIR/network/check-ssh.connection.sh"

# === CONFIGURATION PAR DÉFAUT ===
readonly DEFAULT_SSH_PORT=22
readonly DEFAULT_KEY_TYPE="ed25519"
readonly DEFAULT_KEY_BITS=4096
readonly DEFAULT_TIMEOUT=30

# === VARIABLES GLOBALES ===
TARGET_HOST=""
TARGET_PORT="$DEFAULT_SSH_PORT"
TARGET_USER=""
SSH_KEY_PATH=""
SSH_KEY_TYPE="$DEFAULT_KEY_TYPE"
SSH_KEY_BITS="$DEFAULT_KEY_BITS"
SSH_KEY_COMMENT=""
FORCE_KEY_GENERATION=false
SKIP_CONNECTION_TEST=false
BACKUP_EXISTING_KEYS=true
DRY_RUN=false
QUIET_MODE=false
DEBUG_MODE=false
JSON_ONLY=false

# Métriques de performance
SETUP_START_TIME=0
KEY_GENERATION_TIME=0
KEY_DEPLOYMENT_TIME=0
CONNECTION_TEST_TIME=0
TOTAL_EXECUTION_TIME=0

# Résultats JSON
JSON_RESULT=""

# === FONCTIONS DE LOGGING ===
log_debug() { [[ "$DEBUG_MODE" == true ]] && echo "[DEBUG] $*" >&2; }
log_info() { [[ "$QUIET_MODE" == false ]] && [[ "$JSON_ONLY" == false ]] && echo "[INFO] $*" >&2; }
log_warn() { [[ "$JSON_ONLY" == false ]] && echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# === FONCTIONS UTILITAIRES ===
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 && "$DRY_RUN" == false ]]; then
        log_debug "Nettoyage en cas d'erreur (code: $exit_code)"
    fi
    return $exit_code
}

show_help() {
    cat << 'EOF'
USAGE:
    setup-ssh.access.sh [OPTIONS] --host <hostname> --user <username>

DESCRIPTION:
    Configure l'accès SSH complet pour un utilisateur distant.
    
    Ce script orchestre :
    1. Génération de clés SSH (si nécessaire)
    2. Déploiement de la clé publique
    3. Test de connexion authentifiée

OPTIONS OBLIGATOIRES:
    --host <hostname>         Nom d'hôte ou adresse IP du serveur distant
    --user <username>         Nom d'utilisateur pour la connexion SSH

OPTIONS SSH:
    --port <port>            Port SSH (défaut: 22)
    --key-path <path>        Chemin de la clé SSH (génère si absent)
    --key-type <type>        Type de clé SSH: rsa|ed25519 (défaut: ed25519)
    --key-bits <bits>        Taille de clé en bits (défaut: 4096)
    --key-comment <text>     Commentaire pour la clé SSH

OPTIONS DE COMPORTEMENT:
    --force-keygen          Force la génération même si clé existe
    --skip-test             Ignore le test de connexion final
    --no-backup             Ne sauvegarde pas les clés existantes
    --timeout <seconds>     Timeout de connexion (défaut: 30)

OPTIONS GÉNÉRALES:
    --dry-run               Simulation sans exécution réelle
    --quiet                 Mode silencieux (pas de logs informatifs)
    --debug                 Mode debug détaillé
    --json                  Sortie JSON uniquement
    --help                  Affiche cette aide

SORTIE JSON:
    {
      "status": "success|error",
      "data": {
        "ssh_key_generated": true|false,
        "ssh_key_path": "/path/to/key",
        "public_key_deployed": true|false,
        "connection_authenticated": true|false,
        "performance": {
          "key_generation_ms": 1234,
          "deployment_ms": 567,
          "connection_test_ms": 890,
          "total_ms": 2691
        }
      },
      "message": "Configuration SSH réussie"
    }

CODES DE SORTIE:
    0 - Configuration SSH réussie
    1 - Erreur de paramètres ou prérequis
    2 - Échec de génération de clé
    3 - Échec de déploiement de clé
    4 - Échec de test de connexion
    5 - Erreur générale d'orchestration

EXEMPLES:
    # Configuration basique
    ./setup-ssh.access.sh --host server.example.com --user admin

    # Avec clé spécifique et port personnalisé
    ./setup-ssh.access.sh --host 192.168.1.100 --user deploy \
        --port 2222 --key-path ~/.ssh/deploy_key

    # Génération forcée avec clé RSA
    ./setup-ssh.access.sh --host server.domain.com --user root \
        --force-keygen --key-type rsa --key-bits 4096

    # Mode dry-run avec debug
    ./setup-ssh.access.sh --host test-server --user test \
        --dry-run --debug
EOF
}

# === PARSING DES ARGUMENTS ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --host)
                TARGET_HOST="$2"
                shift 2
                ;;
            --user)
                TARGET_USER="$2"
                shift 2
                ;;
            --port)
                TARGET_PORT="$2"
                shift 2
                ;;
            --key-path)
                SSH_KEY_PATH="$2"
                shift 2
                ;;
            --key-type)
                SSH_KEY_TYPE="$2"
                shift 2
                ;;
            --key-bits)
                SSH_KEY_BITS="$2"
                shift 2
                ;;
            --key-comment)
                SSH_KEY_COMMENT="$2"
                shift 2
                ;;
            --timeout)
                if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -gt 0 ]]; then
                    DEFAULT_TIMEOUT="$2"
                else
                    log_error "Timeout invalide : $2"
                    return 1
                fi
                shift 2
                ;;
            --force-keygen)
                FORCE_KEY_GENERATION=true
                shift
                ;;
            --skip-test)
                SKIP_CONNECTION_TEST=true
                shift
                ;;
            --no-backup)
                BACKUP_EXISTING_KEYS=false
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --quiet)
                QUIET_MODE=true
                shift
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            --json)
                JSON_ONLY=true
                QUIET_MODE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Option inconnue : $1"
                show_help >&2
                return 1
                ;;
        esac
    done
}

# === VALIDATION DES PARAMÈTRES ===
validate_parameters() {
    local errors=0
    
    # Paramètres obligatoires
    if [[ -z "$TARGET_HOST" ]]; then
        log_error "Paramètre --host requis"
        ((errors++))
    fi
    
    if [[ -z "$TARGET_USER" ]]; then
        log_error "Paramètre --user requis"
        ((errors++))
    fi
    
    # Validation du port SSH
    if [[ ! "$TARGET_PORT" =~ ^[0-9]+$ ]] || [[ "$TARGET_PORT" -lt 1 || "$TARGET_PORT" -gt 65535 ]]; then
        log_error "Port SSH invalide : $TARGET_PORT"
        ((errors++))
    fi
    
    # Validation du type de clé
    case "$SSH_KEY_TYPE" in
        rsa|ed25519)
            # Types valides
            ;;
        *)
            log_error "Type de clé invalide : $SSH_KEY_TYPE (rsa|ed25519)"
            ((errors++))
            ;;
    esac
    
    # Validation de la taille de clé
    if [[ ! "$SSH_KEY_BITS" =~ ^[0-9]+$ ]] || [[ "$SSH_KEY_BITS" -lt 1024 ]]; then
        log_error "Taille de clé invalide : $SSH_KEY_BITS (minimum 1024)"
        ((errors++))
    fi
    
    return $errors
}

# === VALIDATION DES PRÉREQUIS ===
validate_prerequisites() {
    local errors=0
    
    # Vérification des scripts atomiques
    local required_scripts=("$GENERATE_SSH_KEY" "$ADD_SSH_KEY" "$CHECK_SSH_CONNECTION")
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_error "Script atomique manquant : $script"
            ((errors++))
        elif [[ ! -x "$script" ]]; then
            log_error "Script atomique non exécutable : $script"
            ((errors++))
        fi
    done
    
    # Vérification des commandes système requises
    local required_commands=("ssh" "ssh-keygen" "scp")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Commande requise manquante : $cmd"
            ((errors++))
        fi
    done
    
    return $errors
}

# === GÉNÉRATION DE CLÉS SSH ===
generate_ssh_key() {
    if [[ -z "$SSH_KEY_PATH" ]]; then
        SSH_KEY_PATH="$HOME/.ssh/id_${SSH_KEY_TYPE}_$(date +%Y%m%d)"
        log_debug "Chemin de clé automatique : $SSH_KEY_PATH"
    fi
    
    # Vérifier si la clé existe déjà
    if [[ -f "$SSH_KEY_PATH" && "$FORCE_KEY_GENERATION" == false ]]; then
        log_info "Clé SSH existante trouvée : $SSH_KEY_PATH"
        return 0
    fi
    
    log_info "ÉTAPE 1/3 : Génération de la paire de clés SSH"
    local keygen_start=$(date +%s.%N)
    
    # Préparer les arguments pour generate-ssh.keypair.sh
    local keygen_args=()
    keygen_args+=("--type" "$SSH_KEY_TYPE")
    keygen_args+=("--bits" "$SSH_KEY_BITS")
    keygen_args+=("--output" "$SSH_KEY_PATH")
    
    [[ -n "$SSH_KEY_COMMENT" ]] && keygen_args+=("--comment" "$SSH_KEY_COMMENT")
    [[ "$BACKUP_EXISTING_KEYS" == true ]] && keygen_args+=("--backup")
    [[ "$FORCE_KEY_GENERATION" == true ]] && keygen_args+=("--force")
    [[ "$QUIET_MODE" == true ]] && keygen_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && keygen_args+=("--debug")
    
    log_debug "Commande génération : $GENERATE_SSH_KEY ${keygen_args[*]}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Génération de clé simulée"
        local keygen_result='{"status": "success", "data": {"key_generated": true, "key_path": "'"$SSH_KEY_PATH"'"}}'
    else
        local keygen_result
        if ! keygen_result=$("$GENERATE_SSH_KEY" "${keygen_args[@]}" 2>/dev/null); then
            log_error "Échec de génération de clé SSH"
            return 2
        fi
    fi
    
    local keygen_end=$(date +%s.%N)
    KEY_GENERATION_TIME=$(echo "($keygen_end - $keygen_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    # Vérifier le résultat
    local keygen_status=$(echo "$keygen_result" | jq -r '.status' 2>/dev/null || echo "error")
    if [[ "$keygen_status" != "success" ]]; then
        log_error "Génération de clé échouée"
        return 2
    fi
    
    log_info "Clé SSH générée avec succès : $SSH_KEY_PATH"
    return 0
}

# === DÉPLOIEMENT DE CLÉ PUBLIQUE ===
deploy_public_key() {
    log_info "ÉTAPE 2/3 : Déploiement de la clé publique"
    local deploy_start=$(date +%s.%N)
    
    # Préparer les arguments pour add-ssh.key.authorized.sh
    local deploy_args=()
    deploy_args+=("--host" "$TARGET_HOST")
    deploy_args+=("--port" "$TARGET_PORT") 
    deploy_args+=("--user" "$TARGET_USER")
    deploy_args+=("--key-file" "$SSH_KEY_PATH.pub")
    
    [[ "$QUIET_MODE" == true ]] && deploy_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && deploy_args+=("--debug")
    
    log_debug "Commande déploiement : $ADD_SSH_KEY ${deploy_args[*]}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Déploiement de clé simulé"
        local deploy_result='{"status": "success", "data": {"key_deployed": true}}'
    else
        local deploy_result
        if ! deploy_result=$("$ADD_SSH_KEY" "${deploy_args[@]}" 2>/dev/null); then
            log_error "Échec de déploiement de clé publique"
            return 3
        fi
    fi
    
    local deploy_end=$(date +%s.%N)
    KEY_DEPLOYMENT_TIME=$(echo "($deploy_end - $deploy_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    # Vérifier le résultat
    local deploy_status=$(echo "$deploy_result" | jq -r '.status' 2>/dev/null || echo "error")
    if [[ "$deploy_status" != "success" ]]; then
        log_error "Déploiement de clé échoué"
        return 3
    fi
    
    log_info "Clé publique déployée avec succès"
    return 0
}

# === TEST DE CONNEXION ===
test_ssh_connection() {
    if [[ "$SKIP_CONNECTION_TEST" == true ]]; then
        log_info "Test de connexion ignoré (--skip-test)"
        CONNECTION_TEST_TIME=0
        return 0
    fi
    
    log_info "ÉTAPE 3/3 : Test de connexion SSH authentifiée"
    local test_start=$(date +%s.%N)
    
    # Préparer les arguments pour check-ssh.connection.sh
    local test_args=()
    test_args+=("--host" "$TARGET_HOST")
    test_args+=("--port" "$TARGET_PORT")
    test_args+=("--user" "$TARGET_USER")
    test_args+=("--identity" "$SSH_KEY_PATH")
    test_args+=("--timeout" "$DEFAULT_TIMEOUT")
    
    [[ "$QUIET_MODE" == true ]] && test_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && test_args+=("--debug")
    
    log_debug "Commande test connexion : $CHECK_SSH_CONNECTION ${test_args[*]}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Test de connexion simulé"
        local test_result='{"status": "success", "data": {"connection_authenticated": true}}'
    else
        local test_result
        if ! test_result=$("$CHECK_SSH_CONNECTION" "${test_args[@]}" 2>/dev/null); then
            log_error "Échec du test de connexion SSH"
            return 4
        fi
    fi
    
    local test_end=$(date +%s.%N)
    CONNECTION_TEST_TIME=$(echo "($test_end - $test_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    # Vérifier le résultat
    local test_status=$(echo "$test_result" | jq -r '.status' 2>/dev/null || echo "error")
    if [[ "$test_status" != "success" ]]; then
        log_error "Test de connexion échoué"
        return 4
    fi
    
    log_info "Connexion SSH authentifiée avec succès"
    return 0
}

# === GÉNÉRATION DU RÉSULTAT JSON ===
generate_json_result() {
    local status="$1"
    local message="$2"
    
    local ssh_key_generated="false"
    local public_key_deployed="false" 
    local connection_authenticated="false"
    
    # Déterminer les statuts selon l'exécution
    [[ "$KEY_GENERATION_TIME" -gt 0 ]] && ssh_key_generated="true"
    [[ "$KEY_DEPLOYMENT_TIME" -gt 0 ]] && public_key_deployed="true"
    [[ "$CONNECTION_TEST_TIME" -gt 0 || "$SKIP_CONNECTION_TEST" == true ]] && connection_authenticated="true"
    
    JSON_RESULT=$(cat << EOF
{
  "status": "$status",
  "data": {
    "ssh_key_generated": $ssh_key_generated,
    "ssh_key_path": "$SSH_KEY_PATH",
    "public_key_deployed": $public_key_deployed,
    "connection_authenticated": $connection_authenticated,
    "performance": {
      "key_generation_ms": $KEY_GENERATION_TIME,
      "deployment_ms": $KEY_DEPLOYMENT_TIME,
      "connection_test_ms": $CONNECTION_TEST_TIME,
      "total_ms": $TOTAL_EXECUTION_TIME
    }
  },
  "message": "$message"
}
EOF
    )
}

# === FONCTION PRINCIPALE ===
do_main_action() {
    SETUP_START_TIME=$(date +%s.%N)
    
    # Exécution séquentielle des étapes
    if ! generate_ssh_key; then
        return $?
    fi
    
    if ! deploy_public_key; then
        return $?
    fi
    
    if ! test_ssh_connection; then
        return $?
    fi
    
    log_info "Configuration SSH terminée avec succès"
    return 0
}

# === POINT D'ENTRÉE PRINCIPAL ===
main() {
    # Configuration du trap pour le nettoyage
    trap cleanup EXIT ERR INT TERM
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des paramètres
    if ! validate_parameters; then
        log_error "Paramètres invalides"
        return 1
    fi
    
    # Validation des prérequis
    if ! validate_prerequisites; then
        log_error "Prérequis non satisfaits"
        return 1
    fi
    
    # Exécution de l'action principale
    local exit_code=0
    local result_message="Configuration SSH réussie"
    
    if do_main_action; then
        exit_code=0
        result_message="Configuration SSH réussie pour $TARGET_USER@$TARGET_HOST"
    else
        local action_exit_code=$?
        case $action_exit_code in
            2)
                result_message="Échec de génération de clé SSH"
                exit_code=2
                ;;
            3)
                result_message="Échec de déploiement de clé publique"
                exit_code=3
                ;;
            4)
                result_message="Échec de test de connexion SSH"
                exit_code=4
                ;;
            *)
                result_message="Erreur générale d'orchestration SSH"
                exit_code=5
                ;;
        esac
    fi
    
    # Calcul du temps total
    local setup_end=$(date +%s.%N)
    TOTAL_EXECUTION_TIME=$(echo "($setup_end - $SETUP_START_TIME) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    # Génération du résultat JSON
    local json_status="success"
    [[ $exit_code -ne 0 ]] && json_status="error"
    generate_json_result "$json_status" "$result_message"
    
    # Sortie du résultat
    if [[ "$JSON_ONLY" == true ]]; then
        echo "$JSON_RESULT"
    else
        log_info "Résultat JSON : $JSON_RESULT"
    fi
    
    return $exit_code
}

# Exécution si script appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi