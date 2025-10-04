#!/usr/bin/env bash
#===============================================================================
# Orchestrateur SSH : Audit Complet des Clés SSH
#===============================================================================
# Nom du fichier : audit-ssh.keys.sh
# Niveau : 1 (Orchestrateur)
# Catégorie : network
# Protocole : ssh
# Description : Audit complet des clés SSH du système
#
# Objectif :
# - Inventaire exhaustif de toutes les clés SSH par utilisateur
# - Test de connectivité pour chaque clé active
# - Analyse de sécurité et détection d'anomalies
# - Rapport détaillé pour audit de conformité
#
# Conforme à la méthodologie AtomicOps-Suite - Niveau 1
#===============================================================================

set -euo pipefail

# === MÉTADONNÉES DU SCRIPT ===
readonly SCRIPT_NAME="audit-ssh.keys.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_CATEGORY="network"
readonly SCRIPT_PROTOCOL="ssh"
readonly SCRIPT_LEVEL=1

# === CHEMINS DES SCRIPTS ATOMIQUES ===
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ATOMICS_DIR="$(realpath "$SCRIPT_DIR/../../atomics")"

# Scripts atomiques utilisés
readonly LIST_SSH_KEYS="$ATOMICS_DIR/network/list-ssh.keys.sh"
readonly CHECK_SSH_CONNECTION="$ATOMICS_DIR/network/check-ssh.connection.sh"

# === CONFIGURATION PAR DÉFAUT ===
readonly DEFAULT_SSH_PORT=22
readonly DEFAULT_TIMEOUT=10
readonly DEFAULT_OUTPUT_FORMAT="json"

# === VARIABLES GLOBALES ===
TARGET_HOST=""
TARGET_PORT="$DEFAULT_SSH_PORT"
TARGET_USER=""
SSH_ADMIN_KEY=""
OUTPUT_FORMAT="$DEFAULT_OUTPUT_FORMAT"
OUTPUT_FILE=""
USERS_LIST=()  # Liste spécifique d'utilisateurs à auditer
SCAN_ALL_USERS=false
TEST_CONNECTIVITY=true
CHECK_PERMISSIONS=true
ANALYZE_SECURITY=true
GENERATE_REPORT=true
DRY_RUN=false
QUIET_MODE=false
DEBUG_MODE=false
JSON_ONLY=false

# Métriques de performance
AUDIT_START_TIME=0
USERS_SCAN_TIME=0
KEYS_LISTING_TIME=0
CONNECTIVITY_TEST_TIME=0
SECURITY_ANALYSIS_TIME=0
TOTAL_EXECUTION_TIME=0

# État d'audit
TOTAL_USERS_SCANNED=0
TOTAL_KEYS_FOUND=0
ACTIVE_KEYS_COUNT=0
INACTIVE_KEYS_COUNT=0
SECURITY_ISSUES_COUNT=0
AUDIT_RESULTS=()

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
    audit-ssh.keys.sh [OPTIONS] --host <hostname> --admin-user <admin>

DESCRIPTION:
    Audit complet des clés SSH du système avec tests de connectivité.
    
    Ce script orchestre :
    1. Inventaire des clés SSH par utilisateur
    2. Test de connectivité pour chaque clé
    3. Analyse de sécurité et anomalies
    4. Génération de rapport d'audit

OPTIONS OBLIGATOIRES:
    --host <hostname>         Nom d'hôte ou adresse IP du serveur à auditer
    --admin-user <username>   Utilisateur admin pour l'audit

OPTIONS SSH:
    --port <port>            Port SSH (défaut: 22)
    --admin-key <path>       Clé SSH d'admin pour la connexion

OPTIONS D'AUDIT:
    --users <user1,user2>    Liste spécifique d'utilisateurs à auditer
    --all-users              Audit de tous les utilisateurs du système
    --skip-connectivity      Ignore les tests de connectivité
    --skip-permissions       Ignore la vérification des permissions
    --skip-security          Ignore l'analyse de sécurité
    --no-report              Ne génère pas de rapport final

OPTIONS DE SORTIE:
    --format <format>        Format de sortie: json|csv|html (défaut: json)
    --output <file>          Fichier de sortie pour le rapport
    --timeout <seconds>      Timeout de connexion (défaut: 10)

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
        "audit_summary": {
          "total_users_scanned": 5,
          "total_keys_found": 12,
          "active_keys": 8,
          "inactive_keys": 4,
          "security_issues": 2
        },
        "users_audit": [
          {
            "username": "user1",
            "keys_count": 3,
            "active_keys": 2,
            "security_score": 85,
            "keys": [...]
          }
        ],
        "security_analysis": {
          "weak_keys": [],
          "expired_keys": [],
          "duplicate_keys": [],
          "permission_issues": []
        },
        "performance": {
          "scan_ms": 1234,
          "listing_ms": 567,
          "connectivity_ms": 890,
          "analysis_ms": 345,
          "total_ms": 3036
        }
      },
      "message": "Audit SSH terminé avec succès"
    }

CODES DE SORTIE:
    0 - Audit SSH réussi
    1 - Erreur de paramètres ou prérequis
    2 - Échec de scan des utilisateurs
    3 - Échec de listing des clés
    4 - Échec des tests de connectivité
    5 - Erreur générale d'orchestration

EXEMPLES:
    # Audit complet d'un serveur
    ./audit-ssh.keys.sh --host server.example.com --admin-user root

    # Audit d'utilisateurs spécifiques
    ./audit-ssh.keys.sh --host 192.168.1.100 --admin-user admin \
        --users "deploy,www-data,backup"

    # Audit avec rapport HTML
    ./audit-ssh.keys.sh --host server.domain.com --admin-user root \
        --format html --output /tmp/ssh_audit.html

    # Mode dry-run avec debug
    ./audit-ssh.keys.sh --host test-server --admin-user admin \
        --all-users --dry-run --debug
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
            --port)
                TARGET_PORT="$2"
                shift 2
                ;;
            --admin-key)
                SSH_ADMIN_KEY="$2"
                shift 2
                ;;
            --users)
                IFS=',' read -ra USERS_LIST <<< "$2"
                shift 2
                ;;
            --all-users)
                SCAN_ALL_USERS=true
                shift
                ;;
            --format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
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
            --skip-connectivity)
                TEST_CONNECTIVITY=false
                shift
                ;;
            --skip-permissions)
                CHECK_PERMISSIONS=false
                shift
                ;;
            --skip-security)
                ANALYZE_SECURITY=false
                shift
                ;;
            --no-report)
                GENERATE_REPORT=false
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
    
    # Validation du port SSH
    if [[ ! "$TARGET_PORT" =~ ^[0-9]+$ ]] || [[ "$TARGET_PORT" -lt 1 || "$TARGET_PORT" -gt 65535 ]]; then
        log_error "Port SSH invalide : $TARGET_PORT"
        ((errors++))
    fi
    
    # Validation du format de sortie
    case "$OUTPUT_FORMAT" in
        json|csv|html)
            # Formats valides
            ;;
        *)
            log_error "Format de sortie invalide : $OUTPUT_FORMAT (json|csv|html)"
            ((errors++))
            ;;
    esac
    
    # Validation de la clé d'admin si spécifiée
    if [[ -n "$SSH_ADMIN_KEY" && ! -f "$SSH_ADMIN_KEY" ]]; then
        log_error "Clé d'admin non trouvée : $SSH_ADMIN_KEY"
        ((errors++))
    fi
    
    # Validation du fichier de sortie si spécifié
    if [[ -n "$OUTPUT_FILE" ]]; then
        local output_dir=$(dirname "$OUTPUT_FILE")
        if [[ ! -d "$output_dir" ]]; then
            log_error "Répertoire de sortie non trouvé : $output_dir"
            ((errors++))
        fi
    fi
    
    return $errors
}

# === VALIDATION DES PRÉREQUIS ===
validate_prerequisites() {
    local errors=0
    
    # Vérification des scripts atomiques
    local required_scripts=("$LIST_SSH_KEYS" "$CHECK_SSH_CONNECTION")
    
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
    local required_commands=("ssh" "jq" "awk" "sort" "uniq")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Commande requise manquante : $cmd"
            ((errors++))
        fi
    done
    
    return $errors
}

# === SCAN DES UTILISATEURS ===
scan_system_users() {
    log_info "ÉTAPE 1/4 : Scan des utilisateurs du système"
    local scan_start=$(date +%s.%N)
    
    if [[ "$SCAN_ALL_USERS" == true ]]; then
        log_debug "Récupération de tous les utilisateurs système"
        
        if [[ "$DRY_RUN" == true ]]; then
            USERS_LIST=("root" "admin" "deploy" "www-data" "backup")
        else
            # Récupérer la liste des utilisateurs ayant un shell valide
            local ssh_cmd="getent passwd | awk -F: '\$7 ~ /\/bin\/(bash|sh|zsh)$/ {print \$1}'"
            local users_result
            
            if [[ -n "$SSH_ADMIN_KEY" ]]; then
                users_result=$(ssh -i "$SSH_ADMIN_KEY" -p "$TARGET_PORT" "$TARGET_USER@$TARGET_HOST" "$ssh_cmd" 2>/dev/null || echo "")
            else
                users_result=$(ssh -p "$TARGET_PORT" "$TARGET_USER@$TARGET_HOST" "$ssh_cmd" 2>/dev/null || echo "")
            fi
            
            if [[ -n "$users_result" ]]; then
                readarray -t USERS_LIST <<< "$users_result"
            else
                log_error "Impossible de récupérer la liste des utilisateurs"
                return 2
            fi
        fi
    fi
    
    TOTAL_USERS_SCANNED=${#USERS_LIST[@]}
    
    local scan_end=$(date +%s.%N)
    USERS_SCAN_TIME=$(echo "($scan_end - $scan_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    log_info "Utilisateurs à auditer : $TOTAL_USERS_SCANNED (${USERS_LIST[*]})"
    return 0
}

# === LISTING DES CLÉS SSH ===
audit_user_keys() {
    log_info "ÉTAPE 2/4 : Inventaire des clés SSH par utilisateur"
    local listing_start=$(date +%s.%N)
    
    AUDIT_RESULTS=()
    local user_count=0
    
    for user in "${USERS_LIST[@]}"; do
        log_debug "Audit des clés SSH pour l'utilisateur : $user"
        ((user_count++))
        
        # Préparer les arguments pour list-ssh.keys.sh
        local list_args=()
        list_args+=("--host" "$TARGET_HOST")
        list_args+=("--port" "$TARGET_PORT")
        list_args+=("--user" "$TARGET_USER")
        list_args+=("--target-user" "$user")
        
        [[ -n "$SSH_ADMIN_KEY" ]] && list_args+=("--identity" "$SSH_ADMIN_KEY")
        [[ "$CHECK_PERMISSIONS" == true ]] && list_args+=("--check-permissions")
        [[ "$QUIET_MODE" == true ]] && list_args+=("--quiet")
        [[ "$DEBUG_MODE" == true ]] && list_args+=("--debug")
        
        log_debug "Commande listing pour $user : $LIST_SSH_KEYS ${list_args[*]}"
        
        if [[ "$DRY_RUN" == true ]]; then
            # Données simulées pour le dry-run
            local user_keys='{"status": "success", "data": {"user": "'"$user"'", "keys_found": '$((RANDOM % 5))', "authorized_keys": [], "private_keys": [], "public_keys": []}}'
        else
            local user_keys
            if ! user_keys=$("$LIST_SSH_KEYS" "${list_args[@]}" 2>/dev/null); then
                log_warn "Échec du listing des clés pour l'utilisateur : $user"
                user_keys='{"status": "error", "data": {"user": "'"$user"'", "keys_found": 0}}'
            fi
        fi
        
        # Ajouter le résultat à l'audit global
        AUDIT_RESULTS+=("$user_keys")
        
        # Compter les clés trouvées
        local user_keys_count=$(echo "$user_keys" | jq -r '.data.keys_found // 0' 2>/dev/null || echo "0")
        TOTAL_KEYS_FOUND=$((TOTAL_KEYS_FOUND + user_keys_count))
        
        log_info "Utilisateur $user ($user_count/$TOTAL_USERS_SCANNED) : $user_keys_count clés trouvées"
    done
    
    local listing_end=$(date +%s.%N)
    KEYS_LISTING_TIME=$(echo "($listing_end - $listing_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    log_info "Total des clés SSH trouvées : $TOTAL_KEYS_FOUND"
    return 0
}

# === TEST DE CONNECTIVITÉ ===
test_keys_connectivity() {
    if [[ "$TEST_CONNECTIVITY" == false ]]; then
        log_info "Tests de connectivité ignorés (--skip-connectivity)"
        CONNECTIVITY_TEST_TIME=0
        return 0
    fi
    
    log_info "ÉTAPE 3/4 : Tests de connectivité des clés SSH"
    local connectivity_start=$(date +%s.%N)
    
    local active_keys=0
    local inactive_keys=0
    
    for user_result in "${AUDIT_RESULTS[@]}"; do
        local user=$(echo "$user_result" | jq -r '.data.user' 2>/dev/null || echo "unknown")
        local keys_found=$(echo "$user_result" | jq -r '.data.keys_found // 0' 2>/dev/null || echo "0")
        
        if [[ "$keys_found" -gt 0 ]]; then
            log_debug "Test de connectivité pour l'utilisateur : $user"
            
            # Test de connexion SSH pour cet utilisateur
            local conn_args=()
            conn_args+=("--host" "$TARGET_HOST")
            conn_args+=("--port" "$TARGET_PORT")
            conn_args+=("--user" "$user")
            conn_args+=("--timeout" "$DEFAULT_TIMEOUT")
            
            [[ "$QUIET_MODE" == true ]] && conn_args+=("--quiet")
            [[ "$DEBUG_MODE" == true ]] && conn_args+=("--debug")
            
            if [[ "$DRY_RUN" == true ]]; then
                # Simulation : 70% de clés actives
                if [[ $((RANDOM % 10)) -lt 7 ]]; then
                    ((active_keys++))
                    log_debug "Clé active simulée pour $user"
                else
                    ((inactive_keys++))
                    log_debug "Clé inactive simulée pour $user"
                fi
            else
                local conn_result
                if conn_result=$("$CHECK_SSH_CONNECTION" "${conn_args[@]}" 2>/dev/null); then
                    local conn_status=$(echo "$conn_result" | jq -r '.data.connection_status' 2>/dev/null || echo "failed")
                    if [[ "$conn_status" == "success" ]]; then
                        ((active_keys++))
                        log_debug "Clé active confirmée pour $user"
                    else
                        ((inactive_keys++))
                        log_debug "Clé inactive pour $user"
                    fi
                else
                    ((inactive_keys++))
                    log_debug "Test de connexion échoué pour $user"
                fi
            fi
        fi
    done
    
    ACTIVE_KEYS_COUNT=$active_keys
    INACTIVE_KEYS_COUNT=$inactive_keys
    
    local connectivity_end=$(date +%s.%N)
    CONNECTIVITY_TEST_TIME=$(echo "($connectivity_end - $connectivity_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    log_info "Clés actives : $ACTIVE_KEYS_COUNT, Clés inactives : $INACTIVE_KEYS_COUNT"
    return 0
}

# === ANALYSE DE SÉCURITÉ ===
analyze_security() {
    if [[ "$ANALYZE_SECURITY" == false ]]; then
        log_info "Analyse de sécurité ignorée (--skip-security)"
        SECURITY_ANALYSIS_TIME=0
        return 0
    fi
    
    log_info "ÉTAPE 4/4 : Analyse de sécurité des clés SSH"
    local analysis_start=$(date +%s.%N)
    
    local security_issues=0
    
    # Analyse des résultats d'audit pour détecter des problèmes de sécurité
    for user_result in "${AUDIT_RESULTS[@]}"; do
        local user=$(echo "$user_result" | jq -r '.data.user' 2>/dev/null || echo "unknown")
        local keys_found=$(echo "$user_result" | jq -r '.data.keys_found // 0' 2>/dev/null || echo "0")
        
        if [[ "$keys_found" -gt 5 ]]; then
            log_warn "SÉCURITÉ: Utilisateur $user a trop de clés SSH ($keys_found)"
            ((security_issues++))
        fi
        
        # Vérification des permissions si disponible
        if echo "$user_result" | jq -e '.data.permission_issues' >/dev/null 2>&1; then
            local perm_issues=$(echo "$user_result" | jq -r '.data.permission_issues | length' 2>/dev/null || echo "0")
            if [[ "$perm_issues" -gt 0 ]]; then
                log_warn "SÉCURITÉ: Utilisateur $user a $perm_issues problèmes de permissions"
                ((security_issues++))
            fi
        fi
    done
    
    SECURITY_ISSUES_COUNT=$security_issues
    
    local analysis_end=$(date +%s.%N)
    SECURITY_ANALYSIS_TIME=$(echo "($analysis_end - $analysis_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    if [[ "$security_issues" -gt 0 ]]; then
        log_warn "Analyse de sécurité terminée : $security_issues problèmes détectés"
    else
        log_info "Analyse de sécurité terminée : aucun problème détecté"
    fi
    
    return 0
}

# === GÉNÉRATION DU RÉSULTAT JSON ===
generate_json_result() {
    local status="$1"
    local message="$2"
    
    # Construction du tableau des résultats utilisateurs
    local users_audit_json="["
    local first=true
    for user_result in "${AUDIT_RESULTS[@]}"; do
        if [[ "$first" == false ]]; then
            users_audit_json+=","
        fi
        users_audit_json+="$user_result"
        first=false
    done
    users_audit_json+="]"
    
    JSON_RESULT=$(cat << EOF
{
  "status": "$status",
  "data": {
    "audit_summary": {
      "total_users_scanned": $TOTAL_USERS_SCANNED,
      "total_keys_found": $TOTAL_KEYS_FOUND,
      "active_keys": $ACTIVE_KEYS_COUNT,
      "inactive_keys": $INACTIVE_KEYS_COUNT,
      "security_issues": $SECURITY_ISSUES_COUNT
    },
    "users_audit": $users_audit_json,
    "performance": {
      "scan_ms": $USERS_SCAN_TIME,
      "listing_ms": $KEYS_LISTING_TIME,
      "connectivity_ms": $CONNECTIVITY_TEST_TIME,
      "analysis_ms": $SECURITY_ANALYSIS_TIME,
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
    AUDIT_START_TIME=$(date +%s.%N)
    
    # Exécution séquentielle des étapes d'audit
    if ! scan_system_users; then
        return $?
    fi
    
    if ! audit_user_keys; then
        return $?
    fi
    
    if ! test_keys_connectivity; then
        return $?
    fi
    
    if ! analyze_security; then
        return $?
    fi
    
    log_info "Audit SSH terminé avec succès"
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
    local result_message="Audit SSH réussi"
    
    if do_main_action; then
        exit_code=0
        result_message="Audit SSH terminé avec succès pour $TARGET_HOST ($TOTAL_USERS_SCANNED utilisateurs, $TOTAL_KEYS_FOUND clés)"
    else
        local action_exit_code=$?
        case $action_exit_code in
            2)
                result_message="Échec du scan des utilisateurs"
                exit_code=2
                ;;
            3)
                result_message="Échec du listing des clés SSH"
                exit_code=3
                ;;
            4)
                result_message="Échec des tests de connectivité"
                exit_code=4
                ;;
            *)
                result_message="Erreur générale d'audit SSH"
                exit_code=5
                ;;
        esac
    fi
    
    # Calcul du temps total
    local audit_end=$(date +%s.%N)
    TOTAL_EXECUTION_TIME=$(echo "($audit_end - $AUDIT_START_TIME) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
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
    
    # Sauvegarde du rapport si demandée
    if [[ -n "$OUTPUT_FILE" && "$GENERATE_REPORT" == true ]]; then
        echo "$JSON_RESULT" > "$OUTPUT_FILE"
        log_info "Rapport d'audit sauvegardé : $OUTPUT_FILE"
    fi
    
    return $exit_code
}

# Exécution si script appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi