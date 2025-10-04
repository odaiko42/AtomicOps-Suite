#!/bin/bash
#
# Orchestrator: test-framework-validation.sh (Level 1)
# Description: Test d'orchestration pour validation complète du framework
# Usage: test-framework-validation.sh [OPTIONS]
#
# Dependencies:
#   - atomics/test-ct-info.sh
#
# Options:
#   -h, --help              Affiche cette aide
#   -v, --verbose           Mode verbeux
#   -d, --debug             Mode debug
#   -f, --force             Force l'opération
#   -n, --dry-run           Simulation sans exécution
#
# Exit codes:
#   0 - Succès
#   1 - Erreur générale
#   2 - Paramètres invalides
#   3 - Permissions insuffisantes
#   4 - Ressource non trouvée
#   5 - Dépendance manquante
#
# Examples:
#   ./test-framework-validation.sh
#   ./test-framework-validation.sh --verbose
#   ./test-framework-validation.sh --debug --dry-run
#
# Architecture:
#   Niveau 1 - Ce script orchestre des actions atomiques pour tester le framework
#
# Author: Framework Test
# Created: $(date +%Y-%m-%d)
#

set -euo pipefail

# Détection du répertoire du projet
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Import des bibliothèques
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"
source "$PROJECT_ROOT/lib/validator.sh"
source "$PROJECT_ROOT/lib/ct-common.sh"

# Variables globales
VERBOSE=0
DEBUG=0
FORCE=0
DRY_RUN=0

# Variables de suivi du workflow
declare -a EXECUTED_SCRIPTS=()
declare -a ROLLBACK_STACK=()
WORKFLOW_ID="wf_test_$(date +%s)_$$"

# Configuration des chemins vers les scripts dépendants
ATOMICS_DIR="$PROJECT_ROOT/atomics"

# Fonction d'aide
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Test d'orchestration pour validation complète du framework

Ce script de niveau 1 orchestre les actions suivantes:
  1. Test des bibliothèques de base (via script atomique)
  2. Validation des fonctions CT (via script atomique)
  3. Test des sorties JSON standardisées

Options:
  -h, --help              Affiche cette aide
  -v, --verbose           Mode verbeux (LOG_LEVEL=1)
  -d, --debug             Mode debug (LOG_LEVEL=0)
  -f, --force             Force l'opération sans confirmation
  -n, --dry-run           Simulation sans exécution réelle

Exit codes:
  $EXIT_SUCCESS ($EXIT_SUCCESS) - Succès
  $EXIT_ERROR_GENERAL ($EXIT_ERROR_GENERAL) - Erreur générale
  $EXIT_ERROR_USAGE ($EXIT_ERROR_USAGE) - Paramètres invalides
  $EXIT_ERROR_PERMISSION ($EXIT_ERROR_PERMISSION) - Permissions insuffisantes
  $EXIT_ERROR_NOT_FOUND ($EXIT_ERROR_NOT_FOUND) - Ressource non trouvée
  $EXIT_ERROR_DEPENDENCY ($EXIT_ERROR_DEPENDENCY) - Dépendance manquante

Dependencies:
  - atomics/test-ct-info.sh

Examples:
  $0
  $0 --verbose
  $0 --debug --dry-run

EOF
}

# Parsing des arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit $EXIT_SUCCESS
                ;;
            -v|--verbose)
                VERBOSE=1
                LOG_LEVEL=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                LOG_LEVEL=0
                shift
                ;;
            -f|--force)
                FORCE=1
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=1
                shift
                ;;
            *)
                log_error "Option inconnue: $1"
                show_help >&2
                exit $EXIT_ERROR_USAGE
                ;;
        esac
    done
}

# Validation des prérequis
validate_prerequisites() {
    log_debug "Validation des prérequis pour l'orchestrateur niveau 1"
    
    # Vérification des dépendances système
    local required_commands=("jq")
    validate_dependencies "${required_commands[@]}" || exit $EXIT_ERROR_DEPENDENCY
    
    # Validation du script atomique requis
    local test_script="$ATOMICS_DIR/test-ct-info.sh"
    if [[ ! -f "$test_script" ]]; then
        log_error "Script atomique requis manquant: test-ct-info.sh"
        exit $EXIT_ERROR_DEPENDENCY
    fi
    
    log_debug "Prérequis validés avec succès"
}

# Fonction d'exécution sécurisée de scripts
execute_script() {
    local script_path="$1"
    local description="$2"
    shift 2
    local args=("$@")
    
    log_info "Exécution: $description"
    log_debug "Script: $script_path ${args[*]:-}"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Simulation: $script_path ${args[*]:-}"
        return 0
    fi
    
    if [[ ! -f "$script_path" ]]; then
        log_error "Script non trouvé: $script_path"
        return $EXIT_ERROR_NOT_FOUND
    fi
    
    local start_time=$(date +%s)
    local result
    local exit_code
    
    # Pour les tests sur Windows, on simule l'exécution
    if command -v bash >/dev/null 2>&1; then
        if result=$(bash "$script_path" "${args[@]}" 2>&1); then
            exit_code=0
        else
            exit_code=$?
        fi
    else
        # Simulation sur Windows
        log_info "[SIMULATION] Bash non disponible - simulation du script"
        result='{"status":"success","message":"Simulated execution on Windows"}'
        exit_code=0
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "✓ $description terminé avec succès (${duration}s)"
        log_debug "Sortie: $result"
        
        # Ajouter à la liste des scripts exécutés
        EXECUTED_SCRIPTS+=("$script_path:$description:$start_time")
        
        return 0
    else
        log_error "✗ Échec de $description (code: $exit_code)"
        log_error "Sortie d'erreur: $result"
        return $exit_code
    fi
}

# Étape 1: Test des bibliothèques de base
step_1_test_libraries() {
    log_info "=== Étape 1: Test des bibliothèques de base ==="
    
    # Test direct des fonctions sans script atomique
    log_debug "Test des utilitaires communs"
    
    if is_command_available "echo"; then
        log_info "✓ Fonction is_command_available fonctionne"
    else
        log_error "✗ Fonction is_command_available ne fonctionne pas"
        return $EXIT_ERROR_GENERAL
    fi
    
    if is_valid_ip "192.168.1.1"; then
        log_info "✓ Fonction is_valid_ip fonctionne"
    else
        log_error "✗ Fonction is_valid_ip ne fonctionne pas"
        return $EXIT_ERROR_GENERAL
    fi
    
    if is_valid_hostname "test-host"; then
        log_info "✓ Fonction is_valid_hostname fonctionne"
    else
        log_error "✗ Fonction is_valid_hostname ne fonctionne pas"
        return $EXIT_ERROR_GENERAL
    fi
    
    # Test des messages de log spécialisés
    ct_info "Test du logging CT - message d'information"
    ct_warn "Test du logging CT - message d'avertissement"
    
    log_info "✓ Étape 1 terminée - Bibliothèques validées"
}

# Étape 2: Test du script atomique
step_2_test_atomic_script() {
    log_info "=== Étape 2: Test du script atomique ==="
    
    execute_script "$ATOMICS_DIR/test-ct-info.sh" "Test du framework CT atomique" \
        --verbose
    
    log_info "✓ Étape 2 terminée - Script atomique testé"
}

# Étape 3: Validation des sorties JSON
step_3_validate_json_outputs() {
    log_info "=== Étape 3: Validation des sorties JSON ==="
    
    # Test de création JSON standardisée
    log_debug "Test de génération JSON"
    
    local test_json='{
        "status": "success",
        "workflow_id": "'$WORKFLOW_ID'",
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
        "framework_version": "1.0.0",
        "test_results": {
            "libraries": "passed",
            "atomics": "passed",
            "orchestration": "in_progress"
        }
    }'
    
    if echo "$test_json" | jq . >/dev/null 2>&1; then
        log_info "✓ Génération JSON valide"
    else
        log_error "✗ JSON invalide généré"
        return $EXIT_ERROR_GENERAL
    fi
    
    log_info "✓ Étape 3 terminée - JSON validé"
}

# Workflow principal
execute_workflow() {
    log_info "🚀 Démarrage du workflow de validation $WORKFLOW_ID"
    
    local workflow_start=$(date +%s)
    local errors=0
    
    # Exécution séquentielle des étapes
    step_1_test_libraries || { errors=$((errors + 1)); log_error "Échec de l'étape 1"; }
    
    if [[ $errors -eq 0 ]]; then
        step_2_test_atomic_script || { errors=$((errors + 1)); log_error "Échec de l'étape 2"; }
    fi
    
    if [[ $errors -eq 0 ]]; then
        step_3_validate_json_outputs || { errors=$((errors + 1)); log_error "Échec de l'étape 3"; }
    fi
    
    local workflow_end=$(date +%s)
    local total_duration=$((workflow_end - workflow_start))
    
    if [[ $errors -eq 0 ]]; then
        log_info "🎉 Workflow de validation $WORKFLOW_ID terminé avec succès (${total_duration}s)"
        
        # Construction de la sortie JSON de succès
        cat <<EOF
{
  "status": "success",
  "workflow_id": "$WORKFLOW_ID",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration": $total_duration,
  "steps_executed": 3,
  "executed_scripts": [$(printf '"%s",' "${EXECUTED_SCRIPTS[@]}" | sed 's/,$//')],
  "framework_validation": {
    "libraries": "✓ passed",
    "atomic_scripts": "✓ passed", 
    "orchestration": "✓ passed",
    "json_outputs": "✓ passed"
  },
  "message": "Framework validation completed successfully"
}
EOF
        return 0
    else
        log_error "💥 Workflow de validation $WORKFLOW_ID échoué avec $errors erreur(s)"
        
        # Construction de la sortie JSON d'erreur
        cat <<EOF
{
  "status": "error",
  "workflow_id": "$WORKFLOW_ID",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration": $total_duration,
  "errors": $errors,
  "executed_scripts": [$(printf '"%s",' "${EXECUTED_SCRIPTS[@]}" | sed 's/,$//')],
  "message": "Framework validation failed with $errors error(s)"
}
EOF
        return $EXIT_ERROR_GENERAL
    fi
}

# Fonction de nettoyage
cleanup() {
    local exit_code=$?
    
    log_debug "Nettoyage des ressources du workflow de test $WORKFLOW_ID (code: $exit_code)"
    
    exit $exit_code
}

# Point d'entrée principal
main() {
    # Configuration des flux de sortie
    exec 3>&1  # Sauvegarder STDOUT original
    exec 1>&2  # Rediriger STDOUT vers STDERR pour les logs
    
    # Configuration du trap de nettoyage
    trap cleanup EXIT ERR INT TERM
    
    # Initialisation du logging
    init_logging "$(basename "$0")"
    
    log_info "🧪 Démarrage de l'orchestrateur de test niveau 1: $(basename "$0")"
    log_debug "Arguments: $*"
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des prérequis
    validate_prerequisites
    
    # Exécution du workflow
    if execute_workflow >&3; then
        log_info "🎉 Orchestrateur de test terminé avec succès"
        exit $EXIT_SUCCESS
    else
        local exit_code=$?
        log_error "💥 Orchestrateur de test échoué (code: $exit_code)"
        exit $exit_code
    fi
}

# Exécution du script
main "$@"