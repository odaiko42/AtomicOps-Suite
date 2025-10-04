#!/bin/bash
#
# Script: dev-helper.sh
# Description: Assistant de développement pour le projet CT Proxmox
# Usage: dev-helper.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Couleurs pour l'affichage
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly RESET='\033[0m'

show_banner() {
    cat <<EOF
${CYAN}╔════════════════════════════════════════════════════════════════════════╗${RESET}
${CYAN}║                  🛠️  CT Proxmox Development Helper                      ║${RESET}
${CYAN}╚════════════════════════════════════════════════════════════════════════╝${RESET}

${GREEN}Projet basé sur la Méthodologie de Développement Modulaire${RESET}

EOF
}

show_menu() {
    cat <<EOF
${YELLOW}📋 Commandes disponibles :${RESET}

${BLUE}1. Créer un nouveau script atomique${RESET}
   ${CYAN}./tools/new-atomic.sh <nom>${RESET}
   Exemple: ./tools/new-atomic.sh detect-usb

${BLUE}2. Créer un nouveau orchestrateur${RESET}
   ${CYAN}./tools/new-orchestrator.sh <nom> <level>${RESET}
   Exemple: ./tools/new-orchestrator.sh setup-system 1

${BLUE}3. Tester un script${RESET}
   ${CYAN}./atomics/mon-script.sh${RESET}
   ${CYAN}./atomics/mon-script.sh | jq .${RESET}    # Valider JSON

${BLUE}4. Valider la syntaxe${RESET}
   ${CYAN}bash -n ./atomics/mon-script.sh${RESET}
   ${CYAN}shellcheck ./atomics/mon-script.sh${RESET}

${BLUE}5. Consulter les logs${RESET}
   ${CYAN}tail -f logs/atomics/\$(date +%Y-%m-%d)/mon-script.log${RESET}
   ${CYAN}tail -f logs/orchestrators/\$(date +%Y-%m-%d)/mon-orchestrateur.log${RESET}

${BLUE}6. Structure du projet${RESET}
   ${CYAN}tree${RESET}                              # Vue d'ensemble
   ${CYAN}ls -la atomics/${RESET}                    # Scripts atomiques
   ${CYAN}ls -la orchestrators/level-*/${RESET}      # Orchestrateurs

${BLUE}7. Outils de développement${RESET}
   ${CYAN}./tools/validate-all.sh${RESET}           # Valider tous les scripts
   ${CYAN}./tools/test-all.sh${RESET}               # Lancer tous les tests
   ${CYAN}./tools/lint-all.sh${RESET}               # Linter tous les scripts

${YELLOW}📚 Documentation de référence :${RESET}
   • Document 1: ${CYAN}docs/Méthodologie de Développement Modulaire et Hiérarchique.md${RESET}
     ${GREEN}→ TOUJOURS consulter pour les standards${RESET}
   
   • Document 2: ${CYAN}docs/Méthodologie de Développement Modulaire - Partie 2.md${RESET}
     ${GREEN}→ Chercher les fonctions dont vous avez besoin${RESET}
   
   • Document 3: ${CYAN}docs/Méthodologie Précise de Développement d'un Script.md${RESET}
     ${GREEN}→ Processus étape par étape${RESET}
   
   • Guide: ${CYAN}docs/Guide de Démarrage - Utilisation de la Méthodologie.md${RESET}
     ${GREEN}→ Comment utiliser la méthodologie${RESET}

${YELLOW}🎯 Règles d'or à ne JAMAIS oublier :${RESET}
   ${RED}1.${RESET} ${GREEN}Toujours vérifier l'unicité${RESET} avant de créer
   ${RED}2.${RESET} ${GREEN}Toujours suivre le template${RESET} approprié
   ${RED}3.${RESET} ${GREEN}Toujours valider${RESET} avec shellcheck
   ${RED}4.${RESET} ${GREEN}Toujours tester${RESET} tous les cas (succès + erreurs)
   ${RED}5.${RESET} ${GREEN}Toujours documenter${RESET} complètement
   ${RED}6.${RESET} ${GREEN}Toujours nettoyer${RESET} les ressources (cleanup)

${YELLOW}🚀 Workflow de développement recommandé :${RESET}

   ${CYAN}Phase 1 - Planification${RESET}
   1. Vérifier unicité: ${PURPLE}grep -r "concept" atomics/ orchestrators/${RESET}
   2. Définir le rôle en UNE phrase
   3. Choisir niveau (atomique/orchestrateur)
   4. Identifier dépendances (lib/*.sh)

   ${CYAN}Phase 2 - Création${RESET}
   1. Utiliser l'outil approprié (new-atomic.sh / new-orchestrator.sh)
   2. Personnaliser l'en-tête de documentation
   3. Implémenter la logique métier

   ${CYAN}Phase 3 - Validation${RESET}
   1. Tests syntaxiques: ${PURPLE}bash -n && shellcheck${RESET}
   2. Tests fonctionnels: ${PURPLE}./script.sh | jq .${RESET}
   3. Tests de tous les cas d'erreur
   4. Validation des logs

   ${CYAN}Phase 4 - Documentation${RESET}
   1. Compléter la documentation en en-tête
   2. Ajouter des exemples d'utilisation
   3. Créer README.md si nécessaire

${YELLOW}💡 Conseils pratiques :${RESET}
   • ${GREEN}Commencez simple${RESET}, complexifiez progressivement
   • ${GREEN}Un script = une action${RESET} (principe atomique)
   • ${GREEN}Utilisez les bibliothèques${RESET} lib/*.sh disponibles
   • ${GREEN}Loggez à chaque étape${RESET} importante
   • ${GREEN}Retournez toujours du JSON${RESET} structuré

${YELLOW}🆘 En cas de blocage :${RESET}
   • Erreur syntaxe → ${PURPLE}shellcheck script.sh${RESET}
   • Script ne marche pas → ${PURPLE}LOG_LEVEL=0 ./script.sh --debug${RESET}
   • Besoin d'une fonction → ${PURPLE}grep -r "fonction" docs/Méthodologie*${RESET}
   • Comprendre l'architecture → ${PURPLE}docs/Méthodologie*.md${RESET}

${YELLOW}📊 État actuel du projet :${RESET}
EOF

    # Afficher les statistiques du projet
    local atomics_count=$(find "$PROJECT_ROOT/atomics" -name "*.sh" 2>/dev/null | wc -l)
    local orchestrators_count=$(find "$PROJECT_ROOT/orchestrators" -name "*.sh" 2>/dev/null | wc -l)
    local lib_count=$(find "$PROJECT_ROOT/lib" -name "*.sh" 2>/dev/null | wc -l)
    
    echo "   • Scripts atomiques: ${GREEN}$atomics_count${RESET}"
    echo "   • Orchestrateurs: ${GREEN}$orchestrators_count${RESET}"  
    echo "   • Bibliothèques: ${GREEN}$lib_count${RESET}"
    echo ""
    
    if [[ -d "$PROJECT_ROOT/logs" ]]; then
        local logs_today=$(find "$PROJECT_ROOT/logs" -name "*.log" -newermt "$(date +%Y-%m-%d)" 2>/dev/null | wc -l)
        echo "   • Logs aujourd'hui: ${GREEN}$logs_today${RESET} fichiers"
    fi
    
    echo ""
    echo "${GREEN}Bon développement ! 🚀${RESET}"
    echo ""
}

main() {
    show_banner
    show_menu
}

main "$@"