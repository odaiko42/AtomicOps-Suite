#!/bin/bash
#
# Script: new-orchestrator.sh
# Description: Générateur d'orchestrateurs conforme à la méthodologie
# Usage: new-orchestrator.sh <orchestrator-name> <level>
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly RESET='\033[0m'

show_help() {
    cat <<EOF
Usage: $0 <orchestrator-name> <level>

Crée un nouvel orchestrateur conforme à la méthodologie hiérarchique.

Arguments:
  orchestrator-name    Nom de l'orchestrateur (format: action-domaine)
  level               Niveau hiérarchique (1, 2, 3, ...)

Niveaux hiérarchiques:
  1 - Appelle uniquement des scripts atomiques
  2 - Appelle des orchestrateurs niveau 1 + atomiques
  3 - Appelle des orchestrateurs niveau 2 + inférieurs
  N - Appelle des orchestrateurs niveau N-1 + inférieurs

Exemples:
  $0 setup-system 1     # Créé orchestrators/level-1/setup-system.sh
  $0 deploy-webapp 2    # Créé orchestrators/level-2/deploy-webapp.sh
  $0 provision-env 3   # Créé orchestrators/level-3/provision-env.sh

Convention de nommage orchestrateurs:
  - setup-*      : Configuration complète
  - configure-*  : Configuration
  - deploy-*     : Déploiement  
  - manage-*     : Gestion
  - provision-*  : Provisionnement

Référence: docs/Méthodologie de Développement Modulaire et Hiérarchique.md
EOF
}

validate_orchestrator_name() {
    local name="$1"
    
    # Vérifier le format action-domaine
    if [[ ! "$name" =~ ^[a-z]+-[a-z]+(-[a-z]+)*$ ]]; then
        echo -e "${RED}❌ Nom invalide: $name${RESET}" >&2
        echo -e "${YELLOW}Format attendu: action-domaine (ex: setup-system, deploy-webapp)${RESET}" >&2
        return 1
    fi
    
    # Vérifier les préfixes recommandés
    local action=$(echo "$name" | cut -d'-' -f1)
    local valid_actions=("setup" "configure" "deploy" "manage" "provision" "install" "create" "backup" "restore")
    local action_valid=false
    
    for valid_action in "${valid_actions[@]}"; do
        if [[ "$action" == "$valid_action" ]]; then
            action_valid=true
            break
        fi
    done
    
    if ! $action_valid; then
        echo -e "${YELLOW}⚠️  Action non standard: $action${RESET}" >&2
        echo -e "${BLUE}Actions recommandées: ${valid_actions[*]}${RESET}" >&2
    fi
    
    return 0
}

validate_level() {
    local level="$1"
    
    # Vérifier que c'est un nombre positif
    if ! [[ "$level" =~ ^[1-9][0-9]*$ ]]; then
        echo -e "${RED}❌ Niveau invalide: $level${RESET}" >&2
        echo -e "${YELLOW}Le niveau doit être un nombre entier positif (1, 2, 3, ...)${RESET}" >&2
        return 1
    fi
    
    # Vérifier que le niveau n'est pas trop élevé (limite pratique)
    if [[ $level -gt 10 ]]; then
        echo -e "${YELLOW}⚠️  Niveau très élevé: $level (considérez la simplification)${RESET}" >&2
    fi
    
    return 0
}

check_uniqueness() {
    local name="$1"
    local level="$2"
    local script_file="$PROJECT_ROOT/orchestrators/level-${level}/${name}.sh"
    
    # Vérifier que le script n'existe pas déjà
    if [[ -f "$script_file" ]]; then
        echo -e "${RED}❌ L'orchestrateur existe déjà: $script_file${RESET}" >&2
        return 1
    fi
    
    # Vérifier qu'il n'existe pas dans les atomiques
    if [[ -f "$PROJECT_ROOT/atomics/${name}.sh" ]]; then
        echo -e "${RED}❌ Un script atomique avec ce nom existe déjà${RESET}" >&2
        return 1
    fi
    
    # Vérifier qu'il n'existe pas dans d'autres niveaux
    if find "$PROJECT_ROOT/orchestrators" -name "${name}.sh" 2>/dev/null | grep -v "level-${level}" | grep -q .; then
        echo -e "${RED}❌ Un orchestrateur avec ce nom existe à un autre niveau${RESET}" >&2
        return 1
    fi
    
    return 0
}

create_orchestrator_script() {
    local script_name="$1"
    local level="$2"
    local script_file="$PROJECT_ROOT/orchestrators/level-${level}/${script_name}.sh"
    
    # Créer le répertoire si nécessaire
    mkdir -p "$PROJECT_ROOT/orchestrators/level-${level}"
    
    echo -e "${BLUE}📝 Création de l'orchestrateur niveau $level: $script_name${RESET}"
    
    # Extraire action et domaine pour la description
    local action=$(echo "$script_name" | cut -d'-' -f1)
    local domain=$(echo "$script_name" | cut -d'-' -f2-)
    local description="TODO: Describe what this orchestrator does to $action $domain"
    
    # Déterminer le path relatif vers PROJECT_ROOT selon le niveau
    local relative_path="../.."
    if [[ $level -gt 1 ]]; then
        relative_path="../.."
    fi
    
    cat > "$script_file" <<EOF
#!/bin/bash
#
# Script: $script_name.sh
# Description: $description
# Level: $level
# Usage: $script_name.sh [OPTIONS]
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
#   5 - Dépendance échouée
#
# Dependencies:
#   TODO: Lister les scripts atomiques et orchestrateurs utilisés
#   Example:
#   - atomics/detect-usb.sh
#   - atomics/format-disk.sh
#   - orchestrators/level-1/setup-storage.sh (si niveau > 1)
#
# Examples:
#   ./$script_name.sh
#   ./$script_name.sh --verbose --dry-run
#   ./$script_name.sh --debug --force
#
# Author: \$(whoami)
# Created: \$(date +%Y-%m-%d)
#

set -euo pipefail

# Détection du répertoire du projet
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="\$(cd "\$SCRIPT_DIR/$relative_path" && pwd)"

# Import des bibliothèques obligatoires
source "\$PROJECT_ROOT/lib/common.sh"
source "\$PROJECT_ROOT/lib/logger.sh"
source "\$PROJECT_ROOT/lib/validator.sh"

# Import des bibliothèques spécifiques au projet CT
source "\$PROJECT_ROOT/lib/ct-common.sh"

# Import des bibliothèques optionnelles (décommenter selon besoin)
# source "\$PROJECT_ROOT/lib/cache.sh"
# source "\$PROJECT_ROOT/lib/retry.sh"
# source "\$PROJECT_ROOT/lib/notifications.sh"

# Variables globales
VERBOSE=0
DEBUG=0
FORCE=0
DRY_RUN=0

# Variables métier (à adapter selon vos besoins)
# PARAM1=""
# PARAM2=""

# Fonction d'aide
show_help() {
    cat <<EEOF
Usage: \$0 [OPTIONS]

$description

This is a level $level orchestrator that coordinates multiple scripts.

Options:
  -h, --help              Affiche cette aide
  -v, --verbose           Mode verbeux (LOG_LEVEL=1)
  -d, --debug             Mode debug (LOG_LEVEL=0)
  -f, --force             Force l'opération sans confirmation
  -n, --dry-run           Simulation sans exécution réelle

Exit codes:
  \$EXIT_SUCCESS (\$EXIT_SUCCESS) - Succès
  \$EXIT_ERROR_GENERAL (\$EXIT_ERROR_GENERAL) - Erreur générale
  \$EXIT_ERROR_USAGE (\$EXIT_ERROR_USAGE) - Paramètres invalides
  \$EXIT_ERROR_PERMISSION (\$EXIT_ERROR_PERMISSION) - Permissions insuffisantes
  \$EXIT_ERROR_NOT_FOUND (\$EXIT_ERROR_NOT_FOUND) - Ressource non trouvée

Architecture:
  Ce script de niveau $level peut appeler:
EOF

    if [[ $level -eq 1 ]]; then
        echo "  - Scripts atomiques uniquement"
    else
        echo "  - Orchestrateurs niveau $((level-1)) et inférieurs"
        echo "  - Scripts atomiques"
    fi
    
    cat <<EEOF

Dependencies:
  TODO: Documenter les dépendances
  
Examples:
  \$0
  \$0 --verbose --dry-run
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
            -n|--dry-run)
                DRY_RUN=1
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
    
    # Vérification des dépendances système
    local required_commands=("jq")  # Ajouter les commandes nécessaires
    validate_dependencies "\${required_commands[@]}" || exit \$EXIT_ERROR_DEPENDENCY
    
    # Vérifier que les scripts dépendants existent
    # TODO: Ajouter les vérifications de dépendances
    # local required_scripts=(
    #     "\$PROJECT_ROOT/atomics/detect-usb.sh"
    #     "\$PROJECT_ROOT/atomics/format-disk.sh"
    # )
    # 
    # for script in "\${required_scripts[@]}"; do
    #     if [[ ! -x "\$script" ]]; then
    #         log_error "Script dépendant non trouvé ou non exécutable: \$script"
    #         exit \$EXIT_ERROR_DEPENDENCY
    #     fi
    # done
    
    log_debug "Prérequis validés avec succès"
}

# Fonction utilitaire pour exécuter un script dépendant
execute_script() {
    local script_path="\$1"
    local script_name=\$(basename "\$script_path")
    shift
    local script_args=("\$@")
    
    log_info "Exécution: \$script_name \${script_args[*]}"
    
    if [[ \$DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Simulation: \$script_path \${script_args[*]}"
        echo '{"status": "success", "code": 0, "message": "Dry run simulation", "data": {}}'
        return 0
    fi
    
    local start_time=\$(date +%s%3N)
    local output
    local exit_code=0
    
    # Exécution avec capture de sortie
    if output=\$("\$script_path" "\${script_args[@]}" 2>&1); then
        local end_time=\$(date +%s%3N)
        local duration=\$((end_time - start_time))
        
        log_info "Script terminé avec succès: \$script_name (\${duration}ms)"
        
        # Vérifier que la sortie est du JSON valide
        if echo "\$output" | jq empty 2>/dev/null; then
            echo "\$output"
        else
            log_warn "Sortie non-JSON du script: \$script_name"
            echo '{"status": "success", "code": 0, "message": "Script completed", "data": {"output": "'"\$(to_json_string "\$output")"'"}}'
        fi
    else
        exit_code=\$?
        log_error "Échec du script: \$script_name (code: \$exit_code)"
        echo "\$output" >&2
        return \$exit_code
    fi
}

# Orchestration principale
orchestrate() {
    log_info "Début de l'orchestration: $script_name (niveau $level)"
    
    local steps_completed=()
    local orchestration_data='{}'
    
    # TODO: Implémenter la séquence d'orchestration
    # Exemple pour un orchestrateur niveau 1:
    
    # # Étape 1: Détecter les périphériques USB
    # log_info "Étape 1: Détection des périphériques USB"
    # local usb_result
    # if usb_result=\$(execute_script "\$PROJECT_ROOT/atomics/detect-usb.sh"); then
    #     steps_completed+=("detect-usb")
    #     local usb_device=\$(echo "\$usb_result" | jq -r '.data.devices[0].device // empty')
    #     orchestration_data=\$(echo "\$orchestration_data" | jq '. + {"usb_device": "'\$usb_device'"}')
    # else
    #     log_error "Échec de la détection USB"
    #     return \$EXIT_ERROR_GENERAL
    # fi
    
    # # Étape 2: Formater le disque
    # if [[ -n "\$usb_device" ]]; then
    #     log_info "Étape 2: Formatage du disque \$usb_device"
    #     local format_result
    #     if format_result=\$(execute_script "\$PROJECT_ROOT/atomics/format-disk.sh" "\$usb_device"); then
    #         steps_completed+=("format-disk")
    #     else
    #         log_error "Échec du formatage"
    #         return \$EXIT_ERROR_GENERAL
    #     fi
    # fi
    
    # Exemple pour orchestrateur niveau 2+ (appel d'autres orchestrateurs):
    # if [[ $level -gt 1 ]]; then
    #     # Appel d'orchestrateurs de niveau inférieur
    #     log_info "Étape X: Orchestration de niveau \$((level-1))"
    #     local sub_result
    #     if sub_result=\$(execute_script "\$PROJECT_ROOT/orchestrators/level-\$((level-1))/sub-orchestrator.sh" --param value); then
    #         steps_completed+=("sub-orchestrator")
    #     else
    #         log_error "Échec de l'orchestration de niveau \$((level-1))"
    #         return \$EXIT_ERROR_GENERAL
    #     fi
    # fi
    
    # Construire les données de résultat
    local steps_json=\$(printf '%s\n' "\${steps_completed[@]}" | jq -R . | jq -s .)
    orchestration_data=\$(echo "\$orchestration_data" | jq '. + {
        "level": $level,
        "steps_completed": '\$steps_json',
        "total_steps": '\${#steps_completed[@]}',
        "orchestrator": "$script_name"
    }')
    
    log_info "Orchestration terminée avec succès (\${#steps_completed[@]} étapes)"
    echo "\$orchestration_data"
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
  "level": $level,
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
    
    # TODO: Nettoyer les ressources créées par l'orchestrateur
    # Exemples:
    # [[ -n "\${TEMP_FILE:-}" ]] && rm -f "\$TEMP_FILE"
    # [[ -n "\${TEMP_DIR:-}" ]] && cleanup_temp "\$TEMP_DIR"
    
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
    
    log_info "Démarrage de l'orchestrateur: $script_name.sh (niveau $level)"
    log_debug "Arguments: \$*"
    
    # Parsing des arguments
    parse_args "\$@"
    
    # Validation des prérequis
    validate_prerequisites
    
    # Exécution de l'orchestration
    local orchestration_result
    if orchestration_result=\$(orchestrate); then
        # Succès - construire la sortie JSON et l'envoyer sur le vrai STDOUT
        build_json_output "success" \$EXIT_SUCCESS "Orchestration completed successfully" "\$orchestration_result" >&3
        
        log_info "Orchestrateur terminé avec succès"
        exit \$EXIT_SUCCESS
    else
        local exit_code=\$?
        log_error "Échec de l'orchestration (code: \$exit_code)"
        
        # Erreur - construire la sortie JSON d'erreur
        local error_message="Orchestration failed"
        build_json_output "error" \$exit_code "\$error_message" '{}' '["'"Orchestration failed with exit code \$exit_code"'"]' >&3
        
        exit \$exit_code
    fi
}

# Exécution du script
main "\$@"
EOF

    chmod +x "$script_file"
    echo -e "${GREEN}✅ Orchestrateur créé: $script_file${RESET}"
}

create_test_file() {
    local script_name="$1"
    local level="$2"
    local test_file="$PROJECT_ROOT/tests/orchestrators/test-${script_name}.sh"
    
    echo -e "${BLUE}🧪 Création du fichier de test: test-${script_name}.sh${RESET}"
    
    cat > "$test_file" <<EOF
#!/bin/bash
#
# Test: test-$script_name.sh
# Description: Tests d'intégration pour $script_name.sh (niveau $level)
# Usage: ./test-$script_name.sh
#

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="\$(cd "\$SCRIPT_DIR/../.." && pwd)"

ORCHESTRATOR_UNDER_TEST="\$PROJECT_ROOT/orchestrators/level-${level}/$script_name.sh"

echo "Testing: $script_name.sh (level $level)"
echo "================================"

# Test 1: Orchestrateur existe et est exécutable
test_orchestrator_executable() {
    echo ""
    echo "Test: Orchestrator exists and is executable"
    
    if [[ ! -f "\$ORCHESTRATOR_UNDER_TEST" ]]; then
        echo "❌ Orchestrator not found: \$ORCHESTRATOR_UNDER_TEST"
        return 1
    fi
    
    if [[ ! -x "\$ORCHESTRATOR_UNDER_TEST" ]]; then
        echo "❌ Orchestrator not executable: \$ORCHESTRATOR_UNDER_TEST"
        return 1
    fi
    
    echo "✅ Orchestrator exists and is executable"
    return 0
}

# Test 2: Aide fonctionne
test_help() {
    echo ""
    echo "Test: Help display"
    
    local output
    if ! output=\$("\$ORCHESTRATOR_UNDER_TEST" --help 2>&1); then
        echo "❌ Help command failed"
        return 1
    fi
    
    if [[ ! "\$output" =~ "Usage:" ]]; then
        echo "❌ Help missing Usage section"
        return 1
    fi
    
    if [[ ! "\$output" =~ "Level: $level" ]] && [[ ! "\$output" =~ "level $level" ]]; then
        echo "❌ Help missing level information"
        return 1
    fi
    
    echo "✅ Help displays correctly"
    return 0
}

# Test 3: Mode dry-run fonctionne
test_dry_run() {
    echo ""
    echo "Test: Dry run mode"
    
    local output
    if ! output=\$("\$ORCHESTRATOR_UNDER_TEST" --dry-run 2>/dev/null); then
        echo "❌ Dry run failed"
        return 1
    fi
    
    # Vérifier JSON valide
    if ! echo "\$output" | jq empty 2>/dev/null; then
        echo "❌ Invalid JSON output in dry run"
        echo "Output: \$output"
        return 1
    fi
    
    local status=\$(echo "\$output" | jq -r '.status // "missing"')
    if [[ "\$status" != "success" ]]; then
        echo "❌ Dry run should succeed, got status: \$status"
        return 1
    fi
    
    echo "✅ Dry run mode works"
    return 0
}

# Test 4: Sortie JSON valide
test_json_output() {
    echo ""
    echo "Test: JSON output validity"
    
    local output
    # Utiliser dry-run pour éviter les effets de bord
    if ! output=\$("\$ORCHESTRATOR_UNDER_TEST" --dry-run 2>/dev/null); then
        echo "❌ Script execution failed"
        return 1
    fi
    
    # Vérifier JSON valide
    if ! echo "\$output" | jq empty 2>/dev/null; then
        echo "❌ Invalid JSON output"
        echo "Output: \$output"
        return 1
    fi
    
    # Vérifier champs obligatoires pour orchestrateur
    local status=\$(echo "\$output" | jq -r '.status // "missing"')
    local level_field=\$(echo "\$output" | jq -r '.level // "missing"')
    local data=\$(echo "\$output" | jq -r '.data // "missing"')
    
    if [[ "\$status" == "missing" ]]; then
        echo "❌ Missing status field"
        return 1
    fi
    
    if [[ "\$level_field" == "missing" ]]; then
        echo "❌ Missing level field"
        return 1
    fi
    
    if [[ "\$level_field" != "$level" ]]; then
        echo "❌ Incorrect level field: \$level_field (expected $level)"
        return 1
    fi
    
    echo "✅ JSON output is valid"
    return 0
}

# Test 5: Gestion des erreurs
test_error_handling() {
    echo ""
    echo "Test: Error handling"
    
    # Test avec option invalide
    local exit_code=0
    "\$ORCHESTRATOR_UNDER_TEST" --invalid-option 2>/dev/null || exit_code=\$?
    
    if [[ \$exit_code -eq 0 ]]; then
        echo "❌ Orchestrator should fail with invalid option"
        return 1
    fi
    
    if [[ \$exit_code -ne 2 ]]; then
        echo "⚠️  Unexpected exit code: \$exit_code (expected 2 for usage error)"
    fi
    
    echo "✅ Error handling works"
    return 0
}

# Test 6: Vérification des dépendances (spécifique aux orchestrateurs)
test_dependencies() {
    echo ""
    echo "Test: Dependencies check"
    
    # TODO: Vérifier que les scripts dépendants existent
    # Exemple:
    # local dependencies=(
    #     "\$PROJECT_ROOT/atomics/detect-usb.sh"
    #     "\$PROJECT_ROOT/atomics/format-disk.sh"
    # )
    # 
    # for dep in "\${dependencies[@]}"; do
    #     if [[ ! -x "\$dep" ]]; then
    #         echo "❌ Missing dependency: \$dep"
    #         return 1
    #     fi
    # done
    
    echo "✅ Dependencies check passed (TODO: implement specific checks)"
    return 0
}

# Exécution des tests
run_tests() {
    local tests_passed=0
    local tests_total=0
    
    local test_functions=(
        "test_orchestrator_executable"
        "test_help"
        "test_dry_run"
        "test_json_output"
        "test_error_handling"
        "test_dependencies"
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

show_architecture_info() {
    local level="$1"
    
    echo -e "${BLUE}📊 Architecture niveau $level :${RESET}"
    
    if [[ $level -eq 1 ]]; then
        cat <<EOF
  ${GREEN}Niveau 1${RESET} - Peut appeler :
    • Scripts atomiques uniquement
    • Exemples : atomics/detect-usb.sh, atomics/format-disk.sh
    
  ${YELLOW}Utilisation typique :${RESET}
    • Configuration de services simples
    • Séquences d'actions atomiques
    • Installation de composants
EOF
    elif [[ $level -eq 2 ]]; then
        cat <<EOF
  ${GREEN}Niveau 2${RESET} - Peut appeler :
    • Orchestrateurs niveau 1
    • Scripts atomiques
    
  ${YELLOW}Utilisation typique :${RESET}
    • Déploiement d'applications complètes
    • Configuration système complexe
    • Orchestration de plusieurs services
EOF
    else
        cat <<EOF
  ${GREEN}Niveau $level${RESET} - Peut appeler :
    • Orchestrateurs niveau $((level-1)) et inférieurs
    • Scripts atomiques
    
  ${YELLOW}Utilisation typique :${RESET}
    • Provisionnement d'environnements complets
    • Déploiements multi-composants
    • Orchestration haute niveau
EOF
    fi
}

show_next_steps() {
    local script_name="$1"
    local level="$2"
    local script_file="$PROJECT_ROOT/orchestrators/level-${level}/${script_name}.sh"
    local test_file="$PROJECT_ROOT/tests/orchestrators/test-${script_name}.sh"
    
    cat <<EOF

${GREEN}🎉 Orchestrateur niveau $level créé avec succès !${RESET}

${YELLOW}📂 Fichiers créés :${RESET}
  • Orchestrateur: ${BLUE}$script_file${RESET}
  • Test:          ${BLUE}$test_file${RESET}

${YELLOW}🎯 Prochaines étapes :${RESET}

  ${BLUE}1. Définir les dépendances${RESET}
     nano $script_file
     ${GREEN}→ Lister les scripts appelés dans validate_prerequisites()${RESET}
     ${GREEN}→ Vérifier leur existence${RESET}

  ${BLUE}2. Implémenter l'orchestration${RESET}
     ${GREEN}→ Compléter la fonction orchestrate()${RESET}
     ${GREEN}→ Ajouter les appels execute_script()${RESET}
     ${GREEN}→ Gérer les données entre étapes${RESET}

  ${BLUE}3. Tester l'orchestrateur${RESET}
     ./$script_file --help
     ./$script_file --dry-run | jq .
     
  ${BLUE}4. Valider la syntaxe${RESET}
     bash -n $script_file
     shellcheck $script_file
     
  ${BLUE}5. Lancer les tests${RESET}
     $test_file

EOF

    show_architecture_info "$level"

    cat <<EOF

${YELLOW}📚 Références utiles :${RESET}
  • Méthodologie: ${CYAN}docs/Méthodologie de Développement Modulaire et Hiérarchique.md${RESET}
  • Patterns avancés: ${CYAN}docs/Méthodologie de Développement Modulaire - Partie 2.md${RESET}
  • Guide processus: ${CYAN}docs/Méthodologie Précise de Développement d'un Script.md${RESET}

${YELLOW}🔗 Exemple d'orchestration niveau $level :${RESET}
EOF

    if [[ $level -eq 1 ]]; then
        cat <<EOF
  ${PURPLE}# Dans orchestrate()${RESET}
  ${CYAN}usb_result=\$(execute_script "\$PROJECT_ROOT/atomics/detect-usb.sh")${RESET}
  ${CYAN}device=\$(echo "\$usb_result" | jq -r '.data.devices[0].device')${RESET}
  ${CYAN}format_result=\$(execute_script "\$PROJECT_ROOT/atomics/format-disk.sh" "\$device")${RESET}
EOF
    else
        cat <<EOF
  ${PURPLE}# Dans orchestrate()${RESET}
  ${CYAN}storage_result=\$(execute_script "\$PROJECT_ROOT/orchestrators/level-1/setup-storage.sh")${RESET}
  ${CYAN}app_result=\$(execute_script "\$PROJECT_ROOT/orchestrators/level-1/deploy-app.sh")${RESET}
EOF
    fi

    echo -e "\n${GREEN}Bon développement ! 🚀${RESET}"
}

main() {
    local script_name="${1:-}"
    local level="${2:-}"
    
    if [[ -z "$script_name" ]] || [[ -z "$level" ]]; then
        echo -e "${RED}❌ Nom et niveau de l'orchestrateur requis${RESET}" >&2
        show_help >&2
        exit 1
    fi
    
    if [[ "$script_name" == "-h" ]] || [[ "$script_name" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    # Validations
    if ! validate_orchestrator_name "$script_name"; then
        exit 1
    fi
    
    if ! validate_level "$level"; then
        exit 1
    fi
    
    if ! check_uniqueness "$script_name" "$level"; then
        exit 1
    fi
    
    echo -e "${GREEN}🚀 Création de l'orchestrateur niveau $level: $script_name${RESET}"
    echo ""
    
    # Création des fichiers
    create_orchestrator_script "$script_name" "$level"
    create_test_file "$script_name" "$level"
    
    # Afficher les prochaines étapes
    show_next_steps "$script_name" "$level"
}

main "$@"