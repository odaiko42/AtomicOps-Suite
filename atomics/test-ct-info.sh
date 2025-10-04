#!/bin/bash
#
# Script: test-ct-info.sh
# Description: Script de test pour valider le framework - affiche les informations CT
# Usage: test-ct-info.sh [OPTIONS] [CTID]
#
# Options:
#   -h, --help              Affiche cette aide
#   -v, --verbose           Mode verbeux
#   -d, --debug             Mode debug
#   -f, --force             Force l'opération
#
# Exit codes:
#   0 - Succès
#   1 - Erreur générale
#   2 - Paramètres invalides
#   3 - Permissions insuffisantes
#   4 - Ressource non trouvée
#
# Examples:
#   ./test-ct-info.sh
#   ./test-ct-info.sh 100
#   ./test-ct-info.sh --verbose
#
# Author: Framework Test
# Created: $(date +%Y-%m-%d)
#

set -euo pipefail

# Détection du répertoire du projet
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Import des bibliothèques obligatoires
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"
source "$PROJECT_ROOT/lib/validator.sh"

# Import des bibliothèques spécifiques au projet CT
source "$PROJECT_ROOT/lib/ct-common.sh"

# Variables globales
VERBOSE=0
DEBUG=0
FORCE=0

# Variables métier
CTID="${1:-}"

# Fonction d'aide
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [CTID]

Script de test pour valider le framework - affiche les informations des containers CT

Options:
  -h, --help              Affiche cette aide
  -v, --verbose           Mode verbeux (LOG_LEVEL=1)
  -d, --debug             Mode debug (LOG_LEVEL=0)
  -f, --force             Force l'opération sans confirmation

Arguments:
  CTID                   ID du container à examiner (optionnel)

Exit codes:
  $EXIT_SUCCESS ($EXIT_SUCCESS) - Succès
  $EXIT_ERROR_GENERAL ($EXIT_ERROR_GENERAL) - Erreur générale
  $EXIT_ERROR_USAGE ($EXIT_ERROR_USAGE) - Paramètres invalides
  $EXIT_ERROR_PERMISSION ($EXIT_ERROR_PERMISSION) - Permissions insuffisantes
  $EXIT_ERROR_NOT_FOUND ($EXIT_ERROR_NOT_FOUND) - Ressource non trouvée

Examples:
  $0                     # Affiche tous les CTs
  $0 100                 # Affiche les infos du CT 100
  $0 --verbose           # Mode verbeux
  $0 --debug 100         # Debug pour le CT 100

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
            [0-9]*)
                if [[ -z "$CTID" ]]; then
                    CTID="$1"
                else
                    log_error "CTID déjà spécifié: $CTID (nouveau: $1)"
                    exit $EXIT_ERROR_USAGE
                fi
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
    log_debug "Validation des prérequis"
    
    # Vérification des dépendances système
    local required_commands=("jq")
    validate_dependencies "${required_commands[@]}" || exit $EXIT_ERROR_DEPENDENCY
    
    # Validation du CTID si fourni
    if [[ -n "$CTID" ]]; then
        validate_required_params "CTID" "$CTID" || exit $EXIT_ERROR_USAGE
        if ! validate_ctid "$CTID"; then
            log_error "CTID invalide: $CTID"
            exit $EXIT_ERROR_USAGE
        fi
    fi
    
    log_debug "Prérequis validés avec succès"
}

# Test des fonctions du framework
test_framework_functions() {
    log_info "Test des fonctions du framework"
    
    # Test des utilitaires de base
    log_debug "Test de is_command_available"
    if is_command_available "ls"; then
        log_info "✓ is_command_available fonctionne"
    else
        log_error "✗ is_command_available ne fonctionne pas"
        return $EXIT_ERROR_GENERAL
    fi
    
    # Test de validation IP
    log_debug "Test de is_valid_ip"
    if is_valid_ip "192.168.1.1"; then
        log_info "✓ is_valid_ip fonctionne"
    else
        log_error "✗ is_valid_ip ne fonctionne pas"
        return $EXIT_ERROR_GENERAL
    fi
    
    # Test de validation hostname
    log_debug "Test de is_valid_hostname"
    if is_valid_hostname "test-host"; then
        log_info "✓ is_valid_hostname fonctionne"
    else
        log_error "✗ is_valid_hostname ne fonctionne pas"
        return $EXIT_ERROR_GENERAL
    fi
    
    log_info "✓ Tests des fonctions framework réussis"
}

# Logique métier principale
do_main_action() {
    log_info "Début du test d'informations CT"
    
    # Test du framework
    test_framework_functions
    
    # Simuler l'obtention d'informations CT
    if [[ -n "$CTID" ]]; then
        log_info "Simulation d'informations pour CT $CTID"
        
        # Simuler des données CT (remplacer par vraies fonctions Proxmox plus tard)
        local ct_data='{
            "ctid": "'$CTID'",
            "status": "running",
            "name": "test-ct-'$CTID'",
            "memory": 1024,
            "cores": 2,
            "storage": "local-lvm",
            "ip": "192.168.1.'$((100 + CTID))'",
            "template": "debian-12-standard",
            "created": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
        }'
        
        ct_info "Informations du container $CTID récupérées"
    else
        log_info "Simulation de la liste de tous les CTs"
        
        # Simuler une liste de CTs
        local ct_list='{
            "total": 3,
            "containers": [
                {
                    "ctid": 100,
                    "status": "running",
                    "name": "test-ct-100"
                },
                {
                    "ctid": 101,
                    "status": "stopped",
                    "name": "test-ct-101"
                },
                {
                    "ctid": 102,
                    "status": "running",
                    "name": "test-ct-102"
                }
            ]
        }'
        
        ct_data="$ct_list"
        ct_info "Liste des containers récupérée (3 containers trouvés)"
    fi
    
    # Test des messages CT spécialisés
    ct_warn "Ceci est un message d'avertissement CT"
    
    log_info "Test d'informations CT terminé avec succès"
    echo "$ct_data"
}

# Construction de la sortie JSON standardisée
build_json_output() {
    local status="$1"
    local code="$2"
    local message="$3"
    local data="$4"
    local errors="${5:-[]}"
    local warnings="${6:-[]}"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat <<EOF
{
  "status": "$status",
  "code": $code,
  "timestamp": "$timestamp",
  "script": "$(basename "$0")",
  "message": "$message",
  "data": $data,
  "errors": $errors,
  "warnings": $warnings,
  "framework_test": {
    "version": "1.0.0",
    "libraries_loaded": [
      "common.sh",
      "logger.sh", 
      "validator.sh",
      "ct-common.sh"
    ],
    "test_type": "ct-info-simulation"
  }
}
EOF
}

# Fonction de nettoyage
cleanup() {
    local exit_code=$?
    
    log_debug "Nettoyage des ressources (code de sortie: $exit_code)"
    
    # Pas de ressources temporaires à nettoyer dans ce test
    
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
    
    log_info "🧪 Démarrage du test du framework CT: $(basename "$0")"
    log_debug "Arguments: $*"
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des prérequis
    validate_prerequisites
    
    # Exécution de l'action principale
    local result_data
    if result_data=$(do_main_action); then
        # Succès - construire la sortie JSON et l'envoyer sur le vrai STDOUT
        build_json_output "success" $EXIT_SUCCESS "Framework test completed successfully" "$result_data" >&3
        
        log_info "🎉 Test du framework terminé avec succès"
        exit $EXIT_SUCCESS
    else
        local exit_code=$?
        log_error "💥 Échec du test du framework (code: $exit_code)"
        
        # Erreur - construire la sortie JSON d'erreur
        local error_message="Framework test failed"
        build_json_output "error" $exit_code "$error_message" '{}' '["Framework test failed with exit code '$exit_code'"]' >&3
        
        exit $exit_code
    fi
}

# Exécution du script
main "$@"