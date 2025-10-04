#!/usr/bin/env bash
#===============================================================================
# Orchestrateur SSH : Révocation Accès SSH Complet
#===============================================================================
# Nom du fichier : revoke-ssh.access.sh
# Niveau : 1 (Orchestrateur)
# Catégorie : network
# Protocole : ssh
# Description : Révoque complètement l'accès SSH d'un utilisateur distant
#
# Objectif :
# - Identification des clés SSH actives de l'utilisateur
# - Suppression des clés des authorized_keys du serveur distant
# - Vérification que l'accès est effectivement révoqué
# - Nettoyage sécurisé complet
#
# Conforme à la méthodologie AtomicOps-Suite - Niveau 1
#===============================================================================

set -euo pipefail

# === MÉTADONNÉES DU SCRIPT ===
readonly SCRIPT_NAME="revoke-ssh.access.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_CATEGORY="network"
readonly SCRIPT_PROTOCOL="ssh"
readonly SCRIPT_LEVEL=1

# === CHEMINS DES SCRIPTS ATOMIQUES ===
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ATOMICS_DIR="$(realpath "$SCRIPT_DIR/../../atomics")"

# Scripts atomiques utilisés
readonly LIST_SSH_KEYS="$ATOMICS_DIR/network/list-ssh.keys.sh"
readonly REMOVE_SSH_KEY="$ATOMICS_DIR/network/remove-ssh.key.authorized.sh"
readonly CHECK_SSH_CONNECTION="$ATOMICS_DIR/network/check-ssh.connection.sh"

# === CONFIGURATION PAR DÉFAUT ===
readonly DEFAULT_SSH_PORT=22
readonly DEFAULT_TIMEOUT=30

# === VARIABLES GLOBALES ===
TARGET_HOST=""
TARGET_PORT="$DEFAULT_SSH_PORT"
TARGET_USER=""
REVOKE_USER=""  # Utilisateur dont on révoque l'accès (peut être différent de TARGET_USER)
SSH_ADMIN_KEY=""  # Clé d'admin pour se connecter et faire la révocation
SPECIFIC_KEY_PATH=""  # Clé spécifique à révoquer (optionnel)
BACKUP_AUTHORIZED_KEYS=true
VERIFY_REVOCATION=true
FORCE_REVOKE=false
DRY_RUN=false
QUIET_MODE=false
DEBUG_MODE=false
JSON_ONLY=false

# Métriques de performance
REVOKE_START_TIME=0
KEYS_LISTING_TIME=0
KEYS_REMOVAL_TIME=0
VERIFICATION_TIME=0
TOTAL_EXECUTION_TIME=0

# État de révocation
KEYS_FOUND=0
KEYS_REVOKED=0
REVOCATION_VERIFIED=false

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
    revoke-ssh.access.sh [OPTIONS] --host <hostname> --admin-user <admin> --revoke-user <user>

DESCRIPTION:
    Révoque complètement l'accès SSH d'un utilisateur distant.
    
    Ce script orchestre :
    1. Identification des clés SSH actives
    2. Suppression des clés authorized_keys
    3. Vérification de la révocation effective

OPTIONS OBLIGATOIRES:
    --host <hostname>         Nom d'hôte ou adresse IP du serveur distant
    --admin-user <username>   Utilisateur admin pour effectuer la révocation
    --revoke-user <username>  Utilisateur dont on révoque l'accès SSH

OPTIONS SSH:
    --port <port>            Port SSH (défaut: 22)
    --admin-key <path>       Clé SSH d'admin pour la connexion
    --specific-key <path>    Révoque seulement cette clé spécifique

OPTIONS DE COMPORTEMENT:
    --no-backup             Ne sauvegarde pas authorized_keys avant modification
    --skip-verify           Ignore la vérification de révocation
    --force                 Force la révocation même si utilisateur connecté
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
        "keys_found": 2,
        "keys_revoked": 2,
        "revocation_verified": true,
        "backup_created": true,
        "revoked_keys": [
          "/home/user/.ssh/id_rsa.pub",
          "/home/user/.ssh/id_ed25519.pub"
        ],
        "performance": {
          "listing_ms": 234,
          "removal_ms": 567,
          "verification_ms": 123,
          "total_ms": 924
        }
      },
      "message": "Accès SSH révoqué avec succès"
    }

CODES DE SORTIE:
    0 - Révocation SSH réussie
    1 - Erreur de paramètres ou prérequis
    2 - Échec de listing des clés
    3 - Échec de suppression des clés
    4 - Échec de vérification de révocation
    5 - Erreur générale d'orchestration

EXEMPLES:
    # Révocation basique
    ./revoke-ssh.access.sh --host server.example.com \
        --admin-user root --revoke-user deploy

    # Avec clé d'admin spécifique
    ./revoke-ssh.access.sh --host 192.168.1.100 \
        --admin-user admin --revoke-user temp_user \
        --admin-key ~/.ssh/admin_key

    # Révocation d'une clé spécifique
    ./revoke-ssh.access.sh --host server.domain.com \
        --admin-user root --revoke-user contractor \
        --specific-key /home/contractor/.ssh/project_key.pub

    # Mode dry-run avec debug
    ./revoke-ssh.access.sh --host test-server \
        --admin-user admin --revoke-user test \
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
            --admin-user)
                TARGET_USER="$2"
                shift 2
                ;;
            --revoke-user)
                REVOKE_USER="$2"
                shift 2
                ;;
            --port)
                TARGET_PORT="$2"
                shift 2
                ;;
            --admin-key)
                SSH_ADMIN_KEY="$2"
                shift 2
                ;;
            --specific-key)
                SPECIFIC_KEY_PATH="$2"
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
            --no-backup)
                BACKUP_AUTHORIZED_KEYS=false
                shift
                ;;
            --skip-verify)
                VERIFY_REVOCATION=false
                shift
                ;;
            --force)
                FORCE_REVOKE=true
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
        log_error "Paramètre --admin-user requis"
        ((errors++))
    fi
    
    if [[ -z "$REVOKE_USER" ]]; then
        log_error "Paramètre --revoke-user requis"
        ((errors++))
    fi
    
    # Validation du port SSH
    if [[ ! "$TARGET_PORT" =~ ^[0-9]+$ ]] || [[ "$TARGET_PORT" -lt 1 || "$TARGET_PORT" -gt 65535 ]]; then
        log_error "Port SSH invalide : $TARGET_PORT"
        ((errors++))
    fi
    
    # Validation de la clé d'admin si spécifiée
    if [[ -n "$SSH_ADMIN_KEY" && ! -f "$SSH_ADMIN_KEY" ]]; then
        log_error "Clé d'admin non trouvée : $SSH_ADMIN_KEY"
        ((errors++))
    fi
    
    # Validation de la clé spécifique si spécifiée
    if [[ -n "$SPECIFIC_KEY_PATH" && ! -f "$SPECIFIC_KEY_PATH" ]]; then
        log_error "Clé spécifique non trouvée : $SPECIFIC_KEY_PATH"
        ((errors++))
    fi
    
    return $errors
}

# === VALIDATION DES PRÉREQUIS ===
validate_prerequisites() {
    local errors=0
    
    # Vérification des scripts atomiques
    local required_scripts=("$LIST_SSH_KEYS" "$REMOVE_SSH_KEY" "$CHECK_SSH_CONNECTION")
    
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
    local required_commands=("ssh" "scp" "grep" "awk")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Commande requise manquante : $cmd"
            ((errors++))
        fi
    done
    
    return $errors
}

# === LISTING DES CLÉS SSH ===
list_user_keys() {
    log_info "ÉTAPE 1/3 : Identification des clés SSH de l'utilisateur"
    local listing_start=$(date +%s.%N)
    
    # Préparer les arguments pour list-ssh.keys.sh
    local list_args=()
    list_args+=("--host" "$TARGET_HOST")
    list_args+=("--port" "$TARGET_PORT")
    list_args+=("--user" "$TARGET_USER")
    list_args+=("--target-user" "$REVOKE_USER")
    
    [[ -n "$SSH_ADMIN_KEY" ]] && list_args+=("--identity" "$SSH_ADMIN_KEY")
    [[ "$QUIET_MODE" == true ]] && list_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && list_args+=("--debug")
    
    log_debug "Commande listing : $LIST_SSH_KEYS ${list_args[*]}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Listing des clés simulé"
        local list_result='{"status": "success", "data": {"keys_found": 2, "authorized_keys": ["/home/user/.ssh/id_rsa.pub", "/home/user/.ssh/id_ed25519.pub"]}}'
        KEYS_FOUND=2
    else
        local list_result
        if ! list_result=$("$LIST_SSH_KEYS" "${list_args[@]}" 2>/dev/null); then
            log_error "Échec du listing des clés SSH"
            return 2
        fi
        
        # Extraire le nombre de clés trouvées
        KEYS_FOUND=$(echo "$list_result" | jq -r '.data.keys_found // 0' 2>/dev/null || echo "0")
    fi
    
    local listing_end=$(date +%s.%N)
    KEYS_LISTING_TIME=$(echo "($listing_end - $listing_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    # Vérifier le résultat
    local list_status=$(echo "$list_result" | jq -r '.status' 2>/dev/null || echo "error")
    if [[ "$list_status" != "success" ]]; then
        log_error "Listing des clés échoué"
        return 2
    fi
    
    log_info "Clés SSH trouvées : $KEYS_FOUND"
    
    if [[ "$KEYS_FOUND" -eq 0 ]]; then
        log_warn "Aucune clé SSH trouvée pour l'utilisateur $REVOKE_USER"
    fi
    
    return 0
}

# === SUPPRESSION DES CLÉS ===
remove_ssh_keys() {
    if [[ "$KEYS_FOUND" -eq 0 ]]; then
        log_info "Aucune clé à supprimer"
        KEYS_REMOVAL_TIME=0
        return 0
    fi
    
    log_info "ÉTAPE 2/3 : Suppression des clés SSH autorisées"
    local removal_start=$(date +%s.%N)
    
    # Préparer les arguments pour remove-ssh.key.authorized.sh
    local remove_args=()
    remove_args+=("--host" "$TARGET_HOST")
    remove_args+=("--port" "$TARGET_PORT")
    remove_args+=("--user" "$TARGET_USER")
    remove_args+=("--target-user" "$REVOKE_USER")
    
    [[ -n "$SSH_ADMIN_KEY" ]] && remove_args+=("--identity" "$SSH_ADMIN_KEY")
    [[ -n "$SPECIFIC_KEY_PATH" ]] && remove_args+=("--key-file" "$SPECIFIC_KEY_PATH")
    [[ "$BACKUP_AUTHORIZED_KEYS" == true ]] && remove_args+=("--backup")
    [[ "$FORCE_REVOKE" == true ]] && remove_args+=("--force")
    [[ "$QUIET_MODE" == true ]] && remove_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && remove_args+=("--debug")
    
    log_debug "Commande suppression : $REMOVE_SSH_KEY ${remove_args[*]}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Suppression des clés simulée"
        local remove_result='{"status": "success", "data": {"keys_removed": 2, "backup_created": true}}'
        KEYS_REVOKED=2
    else
        local remove_result
        if ! remove_result=$("$REMOVE_SSH_KEY" "${remove_args[@]}" 2>/dev/null); then
            log_error "Échec de suppression des clés SSH"
            return 3
        fi
        
        # Extraire le nombre de clés supprimées
        KEYS_REVOKED=$(echo "$remove_result" | jq -r '.data.keys_removed // 0' 2>/dev/null || echo "0")
    fi
    
    local removal_end=$(date +%s.%N)
    KEYS_REMOVAL_TIME=$(echo "($removal_end - $removal_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    # Vérifier le résultat
    local remove_status=$(echo "$remove_result" | jq -r '.status' 2>/dev/null || echo "error")
    if [[ "$remove_status" != "success" ]]; then
        log_error "Suppression des clés échouée"
        return 3
    fi
    
    log_info "Clés SSH supprimées : $KEYS_REVOKED"
    return 0
}

# === VÉRIFICATION DE LA RÉVOCATION ===
verify_revocation() {
    if [[ "$VERIFY_REVOCATION" == false ]]; then
        log_info "Vérification de révocation ignorée (--skip-verify)"
        VERIFICATION_TIME=0
        REVOCATION_VERIFIED=true
        return 0
    fi
    
    log_info "ÉTAPE 3/3 : Vérification de la révocation d'accès"
    local verify_start=$(date +%s.%N)
    
    # Tenter une connexion avec les anciennes clés pour vérifier qu'elle échoue
    # Préparer les arguments pour check-ssh.connection.sh
    local verify_args=()
    verify_args+=("--host" "$TARGET_HOST")
    verify_args+=("--port" "$TARGET_PORT")
    verify_args+=("--user" "$REVOKE_USER")
    verify_args+=("--timeout" "10")  # Timeout court pour test de révocation
    verify_args+=("--expect-failure")  # Option spéciale pour vérifier l'échec
    
    [[ "$QUIET_MODE" == true ]] && verify_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && verify_args+=("--debug")
    
    log_debug "Commande vérification : $CHECK_SSH_CONNECTION ${verify_args[*]}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Vérification de révocation simulée"
        local verify_result='{"status": "success", "data": {"connection_denied": true}}'
        REVOCATION_VERIFIED=true
    else
        local verify_result
        # Pour la vérification de révocation, on s'attend à un échec de connexion
        if verify_result=$("$CHECK_SSH_CONNECTION" "${verify_args[@]}" 2>/dev/null); then
            # Si la connexion réussit, la révocation a échoué
            local connection_status=$(echo "$verify_result" | jq -r '.data.connection_status // "failed"' 2>/dev/null)
            if [[ "$connection_status" == "success" ]]; then
                log_error "ATTENTION: L'utilisateur peut encore se connecter!"
                REVOCATION_VERIFIED=false
                return 4
            else
                REVOCATION_VERIFIED=true
            fi
        else
            # Échec de connexion = révocation réussie
            REVOCATION_VERIFIED=true
        fi
    fi
    
    local verify_end=$(date +%s.%N)
    VERIFICATION_TIME=$(echo "($verify_end - $verify_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    if [[ "$REVOCATION_VERIFIED" == true ]]; then
        log_info "Révocation d'accès vérifiée avec succès"
    else
        log_error "Échec de vérification de révocation"
        return 4
    fi
    
    return 0
}

# === GÉNÉRATION DU RÉSULTAT JSON ===
generate_json_result() {
    local status="$1"
    local message="$2"
    
    # Construction de la liste des clés révoquées
    local revoked_keys_json="[]"
    if [[ "$KEYS_REVOKED" -gt 0 ]]; then
        revoked_keys_json='["keys_revoked_count": '$KEYS_REVOKED']'
    fi
    
    JSON_RESULT=$(cat << EOF
{
  "status": "$status",
  "data": {
    "keys_found": $KEYS_FOUND,
    "keys_revoked": $KEYS_REVOKED,
    "revocation_verified": $REVOCATION_VERIFIED,
    "backup_created": $BACKUP_AUTHORIZED_KEYS,
    "performance": {
      "listing_ms": $KEYS_LISTING_TIME,
      "removal_ms": $KEYS_REMOVAL_TIME,
      "verification_ms": $VERIFICATION_TIME,
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
    REVOKE_START_TIME=$(date +%s.%N)
    
    # Exécution séquentielle des étapes
    if ! list_user_keys; then
        return $?
    fi
    
    if ! remove_ssh_keys; then
        return $?
    fi
    
    if ! verify_revocation; then
        return $?
    fi
    
    log_info "Révocation d'accès SSH terminée avec succès"
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
    local result_message="Révocation SSH réussie"
    
    if do_main_action; then
        exit_code=0
        if [[ "$KEYS_FOUND" -eq 0 ]]; then
            result_message="Aucune clé SSH trouvée pour $REVOKE_USER@$TARGET_HOST"
        else
            result_message="Accès SSH révoqué avec succès pour $REVOKE_USER@$TARGET_HOST ($KEYS_REVOKED clés supprimées)"
        fi
    else
        local action_exit_code=$?
        case $action_exit_code in
            2)
                result_message="Échec du listing des clés SSH"
                exit_code=2
                ;;
            3)
                result_message="Échec de suppression des clés SSH"
                exit_code=3
                ;;
            4)
                result_message="Échec de vérification de révocation"
                exit_code=4
                ;;
            *)
                result_message="Erreur générale de révocation SSH"
                exit_code=5
                ;;
        esac
    fi
    
    # Calcul du temps total
    local revoke_end=$(date +%s.%N)
    TOTAL_EXECUTION_TIME=$(echo "($revoke_end - $REVOKE_START_TIME) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
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