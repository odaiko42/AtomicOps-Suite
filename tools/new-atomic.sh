#!/bin/bash
#
# Script: new-atomic.sh
# Description: Générateur de scripts atomiques conforme à la méthodologie
# Usage: new-atomic.sh <script-name>
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly RESET='\033[0m'

show_help() {
    cat <<EOF
Usage: $0 <script-name>

Crée un nouveau script atomique conforme à la méthodologie.

Arguments:
  script-name    Nom du script (format: verbe-objet)

Exemples:
  $0 detect-usb         # Créé atomics/detect-usb.sh
  $0 format-disk        # Créé atomics/format-disk.sh
  $0 backup-files       # Créé atomics/backup-files.sh

Le script créé inclut:
  - Template standard conforme à la méthodologie
  - En-tête de documentation personnalisé
  - Structure de base avec fonctions obligatoires
  - Imports des bibliothèques essentielles
  - Gestion d'erreurs et cleanup
  - Sortie JSON standardisée

Référence: docs/Méthodologie de Développement Modulaire et Hiérarchique.md
EOF
}

validate_script_name() {
    local name="$1"
    
    # Vérifier le format verbe-objet
    if [[ ! "$name" =~ ^[a-z]+-[a-z]+(-[a-z]+)*$ ]]; then
        echo -e "${RED}❌ Nom invalide: $name${RESET}" >&2
        echo -e "${YELLOW}Format attendu: verbe-objet (ex: detect-usb, format-disk)${RESET}" >&2
        return 1
    fi
    
    # Vérifier l'unicité
    local script_file="$PROJECT_ROOT/atomics/${name}.sh"
    if [[ -f "$script_file" ]]; then
        echo -e "${RED}❌ Le script existe déjà: $script_file${RESET}" >&2
        return 1
    fi
    
    # Vérifier qu'il n'existe pas dans les orchestrateurs
    if find "$PROJECT_ROOT/orchestrators" -name "${name}.sh" 2>/dev/null | grep -q .; then
        echo -e "${RED}❌ Un orchestrateur avec ce nom existe déjà${RESET}" >&2
        return 1
    fi
    
    return 0
}

create_atomic_script() {
    local script_name="$1"
    local script_file="$PROJECT_ROOT/atomics/${script_name}.sh"
    
    echo -e "${BLUE}📝 Création du script atomique: $script_name${RESET}"
    
    # Extraire verbe et objet pour la description
    local verb=$(echo "$script_name" | cut -d'-' -f1)
    local object=$(echo "$script_name" | cut -d'-' -f2-)
    local description="TODO: Describe what this script does with $object"
    
    cat > "$script_file" <<EOF
#!/bin/bash
#
# Script: $script_name.sh
# Description: $description
# Usage: $script_name.sh [OPTIONS]
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
#   ./$script_name.sh
#   ./$script_name.sh --verbose
#   ./$script_name.sh --debug --force
#
# Author: \$(whoami)
# Created: \$(date +%Y-%m-%d)
#

set -euo pipefail

# Détection du répertoire du projet
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="\$(cd "\$SCRIPT_DIR/.." && pwd)"

# Import des bibliothèques obligatoires
source "\$PROJECT_ROOT/lib/common.sh"
source "\$PROJECT_ROOT/lib/logger.sh"
source "\$PROJECT_ROOT/lib/validator.sh"

# Import des bibliothèques spécifiques au projet CT
source "\$PROJECT_ROOT/lib/ct-common.sh"

# Variables globales
VERBOSE=0
DEBUG=0
FORCE=0

# Variables métier (à adapter selon vos besoins)
# PARAM1=""
# PARAM2=""

# Fonction d'aide
show_help() {
    cat <<EEOF
Usage: \$0 [OPTIONS]

$description

Options:
  -h, --help              Affiche cette aide
  -v, --verbose           Mode verbeux (LOG_LEVEL=1)
  -d, --debug             Mode debug (LOG_LEVEL=0)  
  -f, --force             Force l'opération sans confirmation

Exit codes:
  \$EXIT_SUCCESS (\$EXIT_SUCCESS) - Succès
  \$EXIT_ERROR_GENERAL (\$EXIT_ERROR_GENERAL) - Erreur générale
  \$EXIT_ERROR_USAGE (\$EXIT_ERROR_USAGE) - Paramètres invalides
  \$EXIT_ERROR_PERMISSION (\$EXIT_ERROR_PERMISSION) - Permissions insuffisantes
  \$EXIT_ERROR_NOT_FOUND (\$EXIT_ERROR_NOT_FOUND) - Ressource non trouvée

Examples:
  \$0
  \$0 --verbose
  \$0 --debug --force

EEOF
}

# Parsing des arguments
parse_args() {
    while [[ \$# -gt 0 ]]; do
        case \$1 in
            -h|--help)
                show_help
                exit \$EXIT_SUCCESS
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
            *)
                log_error "Option inconnue: \$1"
                show_help >&2
                exit \$EXIT_ERROR_USAGE
                ;;
        esac
    done
}

# Validation des prérequis
validate_prerequisites() {
    log_debug "Validation des prérequis"
    
    # Vérification des permissions (adapter selon vos besoins)
    # validate_permissions root || exit \$EXIT_ERROR_PERMISSION
    
    # Vérification des dépendances système (adapter selon vos besoins)
    local required_commands=("jq")  # Ajouter les commandes nécessaires
    validate_dependencies "\${required_commands[@]}" || exit \$EXIT_ERROR_DEPENDENCY
    
    # Validation des paramètres métier (à implémenter selon vos besoins)
    # validate_required_params "PARAM1" "\$PARAM1" || exit \$EXIT_ERROR_USAGE
    
    log_debug "Prérequis validés avec succès"
}

# Logique métier principale
do_main_action() {
    log_info "Début de l'action principale: $verb $object"
    
    # TODO: Implémenter votre logique ici
    # Exemples selon le type de script:
    
    # Pour un script de détection:
    # local detected_items=\$(detect_something)
    
    # Pour un script de formatage:
    # local device="\$1"
    # validate_block_device "\$device" || return \$EXIT_ERROR_VALIDATION
    # format_device "\$device"
    
    # Pour un script de backup:
    # local source_path="\$1"
    # local dest_path="\$2"
    # validate_directory_path "\$source_path" || return \$EXIT_ERROR_NOT_FOUND
    # validate_directory_path "\$dest_path" true || return \$EXIT_ERROR_VALIDATION
    # perform_backup "\$source_path" "\$dest_path"
    
    # Exemple de données retournées (à adapter)
    local result_data='{
        "action": "'$verb'",
        "target": "'$object'",
        "timestamp": "'"\$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",
        "status": "completed"
    }'
    
    log_info "Action principale terminée avec succès"
    echo "\$result_data"
}

# Construction de la sortie JSON standardisée
build_json_output() {
    local status="\$1"
    local code="\$2"  
    local message="\$3"
    local data="\$4"
    local errors="\${5:-[]}"
    local warnings="\${6:-[]}"
    
    local timestamp=\$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat <<EEOF
{
  "status": "\$status",
  "code": \$code,
  "timestamp": "\$timestamp",
  "script": "\$(basename "\$0")",
  "message": "\$message",
  "data": \$data,
  "errors": \$errors,
  "warnings": \$warnings
}
EEOF
}

# Fonction de nettoyage
cleanup() {
    local exit_code=\$?
    
    log_debug "Nettoyage des ressources (code de sortie: \$exit_code)"
    
    # TODO: Nettoyer les ressources créées
    # Exemples:
    # [[ -n "\${TEMP_FILE:-}" ]] && rm -f "\$TEMP_FILE"
    # [[ -n "\${TEMP_DIR:-}" ]] && cleanup_temp "\$TEMP_DIR"
    # [[ -n "\${MOUNT_POINT:-}" ]] && umount "\$MOUNT_POINT" 2>/dev/null || true
    
    exit \$exit_code
}

# Point d'entrée principal
main() {
    # Configuration des flux de sortie
    exec 3>&1  # Sauvegarder STDOUT original
    exec 1>&2  # Rediriger STDOUT vers STDERR pour les logs
    
    # Configuration du trap de nettoyage
    trap cleanup EXIT ERR INT TERM
    
    # Initialisation du logging
    init_logging "\$(basename "\$0")"
    
    log_info "Démarrage du script: $script_name.sh"
    log_debug "Arguments: \$*"
    
    # Parsing des arguments
    parse_args "\$@"
    
    # Validation des prérequis
    validate_prerequisites
    
    # Exécution de l'action principale
    local result_data
    if result_data=\$(do_main_action); then
        # Succès - construire la sortie JSON et l'envoyer sur le vrai STDOUT
        build_json_output "success" \$EXIT_SUCCESS "Operation completed successfully" "\$result_data" >&3
        
        log_info "Script terminé avec succès"
        exit \$EXIT_SUCCESS
    else
        local exit_code=\$?
        log_error "Échec de l'action principale (code: \$exit_code)"
        
        # Erreur - construire la sortie JSON d'erreur
        local error_message="Main action failed"
        build_json_output "error" \$exit_code "\$error_message" '{}' '["'"Main action failed with exit code \$exit_code"'"]' >&3
        
        exit \$exit_code
    fi
}

# Exécution du script
main "\$@"
EOF

    chmod +x "$script_file"
    echo -e "${GREEN}✅ Script créé: $script_file${RESET}"
}

create_test_file() {
    local script_name="$1"
    local test_file="$PROJECT_ROOT/tests/atomics/test-${script_name}.sh"
    
    echo -e "${BLUE}🧪 Création du fichier de test: test-${script_name}.sh${RESET}"
    
    cat > "$test_file" <<EOF
#!/bin/bash
#
# Test: test-$script_name.sh  
# Description: Tests unitaires pour $script_name.sh
# Usage: ./test-$script_name.sh
#

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="\$(cd "\$SCRIPT_DIR/../.." && pwd)"

# Import du framework de test (à créer plus tard)
# source "\$PROJECT_ROOT/tests/lib/test-framework.sh"

SCRIPT_UNDER_TEST="\$PROJECT_ROOT/atomics/$script_name.sh"

echo "Testing: $script_name.sh"
echo "================================"

# Test 1: Script existe et est exécutable
test_script_executable() {
    echo ""
    echo "Test: Script exists and is executable"
    
    if [[ ! -f "\$SCRIPT_UNDER_TEST" ]]; then
        echo "❌ Script not found: \$SCRIPT_UNDER_TEST"
        return 1
    fi
    
    if [[ ! -x "\$SCRIPT_UNDER_TEST" ]]; then
        echo "❌ Script not executable: \$SCRIPT_UNDER_TEST"
        return 1
    fi
    
    echo "✅ Script exists and is executable"
    return 0
}

# Test 2: Aide fonctionne
test_help() {
    echo ""
    echo "Test: Help display"
    
    local output
    if ! output=\$("\$SCRIPT_UNDER_TEST" --help 2>&1); then
        echo "❌ Help command failed"
        return 1
    fi
    
    if [[ ! "\$output" =~ "Usage:" ]]; then
        echo "❌ Help missing Usage section"
        return 1
    fi
    
    if [[ ! "\$output" =~ "Options:" ]]; then
        echo "❌ Help missing Options section"
        return 1
    fi
    
    echo "✅ Help displays correctly"
    return 0
}

# Test 3: Sortie JSON valide
test_json_output() {
    echo ""
    echo "Test: JSON output validity"
    
    local output
    if ! output=\$("\$SCRIPT_UNDER_TEST" 2>/dev/null); then
        echo "❌ Script execution failed"
        return 1
    fi
    
    # Vérifier JSON valide
    if ! echo "\$output" | jq empty 2>/dev/null; then
        echo "❌ Invalid JSON output"
        echo "Output: \$output"
        return 1
    fi
    
    # Vérifier champs obligatoires
    local status=\$(echo "\$output" | jq -r '.status // "missing"')
    local code=\$(echo "\$output" | jq -r '.code // "missing"')
    local script_field=\$(echo "\$output" | jq -r '.script // "missing"')
    
    if [[ "\$status" == "missing" ]]; then
        echo "❌ Missing status field"
        return 1
    fi
    
    if [[ "\$code" == "missing" ]]; then
        echo "❌ Missing code field"  
        return 1
    fi
    
    if [[ "\$script_field" == "missing" ]]; then
        echo "❌ Missing script field"
        return 1
    fi
    
    echo "✅ JSON output is valid"
    return 0
}

# Test 4: Gestion des erreurs
test_error_handling() {
    echo ""
    echo "Test: Error handling"
    
    # Test avec option invalide
    local exit_code=0
    "\$SCRIPT_UNDER_TEST" --invalid-option 2>/dev/null || exit_code=\$?
    
    if [[ \$exit_code -eq 0 ]]; then
        echo "❌ Script should fail with invalid option"
        return 1
    fi
    
    if [[ \$exit_code -ne 2 ]]; then
        echo "⚠️  Unexpected exit code: \$exit_code (expected 2 for usage error)"
    fi
    
    echo "✅ Error handling works"
    return 0
}

# Exécution des tests
run_tests() {
    local tests_passed=0
    local tests_total=0
    
    local test_functions=(
        "test_script_executable"
        "test_help"
        "test_json_output"
        "test_error_handling"
    )
    
    for test_func in "\${test_functions[@]}"; do
        ((tests_total++))
        if \$test_func; then
            ((tests_passed++))
        fi
    done
    
    echo ""
    echo "================================"
    echo "Tests: \$tests_passed/\$tests_total passed"
    
    if [[ \$tests_passed -eq \$tests_total ]]; then
        echo "✅ All tests passed!"
        exit 0
    else
        echo "❌ Some tests failed"
        exit 1
    fi
}

# Point d'entrée
main() {
    run_tests
}

main "\$@"
EOF

    chmod +x "$test_file"
    echo -e "${GREEN}✅ Test créé: $test_file${RESET}"
}

show_next_steps() {
    local script_name="$1"
    local script_file="$PROJECT_ROOT/atomics/${script_name}.sh"
    local test_file="$PROJECT_ROOT/tests/atomics/test-${script_name}.sh"
    
    cat <<EOF

${GREEN}🎉 Script atomique créé avec succès !${RESET}

${YELLOW}📂 Fichiers créés :${RESET}
  • Script: ${BLUE}$script_file${RESET}
  • Test:   ${BLUE}$test_file${RESET}

${YELLOW}🎯 Prochaines étapes :${RESET}

  ${BLUE}1. Personnaliser le script${RESET}
     nano $script_file
     ${GREEN}→ Modifier la description${RESET}
     ${GREEN}→ Implémenter do_main_action()${RESET}
     ${GREEN}→ Adapter les validations${RESET}

  ${BLUE}2. Tester le script${RESET}
     ./$script_file --help
     ./$script_file | jq .
     
  ${BLUE}3. Valider la syntaxe${RESET}
     bash -n $script_file
     shellcheck $script_file
     
  ${BLUE}4. Lancer les tests${RESET}
     $test_file
     
  ${BLUE}5. Documenter${RESET}
     ${GREEN}→ Compléter l'en-tête${RESET}
     ${GREEN}→ Ajouter des exemples${RESET}

${YELLOW}📚 Références utiles :${RESET}
  • Méthodologie: ${CYAN}docs/Méthodologie de Développement Modulaire et Hiérarchique.md${RESET}
  • Bibliothèques: ${CYAN}lib/*.sh${RESET} (common, logger, validator, ct-common)
  • Assistant: ${CYAN}./tools/dev-helper.sh${RESET}

${GREEN}Bon développement ! 🚀${RESET}
EOF
}

main() {
    local script_name="${1:-}"
    
    if [[ -z "$script_name" ]]; then
        echo -e "${RED}❌ Nom du script requis${RESET}" >&2
        show_help >&2
        exit 1
    fi
    
    if [[ "$script_name" == "-h" ]] || [[ "$script_name" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    # Validation du nom
    if ! validate_script_name "$script_name"; then
        exit 1
    fi
    
    echo -e "${GREEN}🚀 Création du script atomique: $script_name${RESET}"
    echo ""
    
    # Création des fichiers
    create_atomic_script "$script_name"
    create_test_file "$script_name"
    
    # Afficher les prochaines étapes
    show_next_steps "$script_name"
}

main "$@"