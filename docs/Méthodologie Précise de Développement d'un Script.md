### Semaine 2 : Premier orchestrateur (8-10h)

```bash
Jour 6-7 : Planifier l'orchestrateur
Jour 8-9 : Implémenter et tester
Jour 10 : Documentation et intégration
```

### Mois 1 : Production-ready

```bash
Semaine 3 : Monitoring et CI/CD
Semaine 4 : Système complet avec 10+ scripts
```

---

## ✅ Checklist imprimable

### Avant de commencer un script

```
□ J'ai vérifié qu'aucun script similaire n'existe
□ J'ai défini précisément le rôle du script (1 phrase)
□ J'ai déterminé le niveau (atomique ou orchestrateur N)
□ J'ai identifié toutes les dépendances
□ J'ai choisi le nom selon la convention
□ J'ai défini les codes de sortie nécessaires
□ J'ai conçu la structure JSON de sortie
□ J'ai les documents 1 et 2 à portée de main
```

### Pendant le développement

```
□ J'ai copié le template approprié
□ J'ai personnalisé l'en-tête complètement
□ J'ai importé toutes les bibliothèques nécessaires
□ J'ai implémenté validate_prerequisites()
□ J'ai implémenté do_main_action() / orchestrate()
□ J'ai implémenté build_json_output()
□ J'ai implémenté cleanup()
□ J'ai défini trap cleanup EXIT ERR INT TERM
□ Je log à chaque étape importante
□ Je gère toutes les erreurs possibles
```

### Avant de commiter

```
□ bash -n script.sh passe
□ shellcheck script.sh passe (0 warnings)
□ ./tools/custom-linter.sh script.sh passe
□ ./tools/validate-script.sh script.sh passe
□ ./tests/*/test-script.sh passe (100%)
□ ./script.sh | jq . passe (JSON valide)
□ Documentation .md créée et complète
□ Tous les exemples de la doc fonctionnent
□ Diagramme créé (si orchestrateur)
□ Pas de fichiers temporaires restants
□ Pas de secrets hardcodés
□ Message de commit conforme
```

---

## 🎓 Conclusion

Cette méthodologie vous garantit :

✅ **Scripts robustes** - Gestion complète des erreurs, validation systématique  
✅ **Scripts maintenables** - Documentation exhaustive, tests automatiques  
✅ **Scripts évolutifs** - Architecture modulaire, composition facile  
✅ **Scripts sécurisés** - Validation, audit, sandbox  
✅ **Scripts performants** - Cache, parallélisme, optimisation  
✅ **Scripts monitorés** - Métriques, alertes, dashboards  

**Le respect rigoureux de cette méthodologie est la clé du succès.**

### Règles d'or à ne JAMAIS oublier

1. 🔍 **Toujours vérifier l'unicité** avant de créer
2. 📋 **Toujours suivre le template** approprié
3. ✅ **Toujours valider** avec les outils fournis
4. 🧪 **Toujours tester** tous les cas (succès + erreurs)
5. 📚 **Toujours documenter** complètement
6. 🔒 **Toujours nettoyer** les ressources (cleanup)
7. 📊 **Toujours logger** les actions importantes
8. 🎯 **Toujours respecter** les standards JSON

### Prochaines étapes

1. ✅ Imprimer cette méthodologie
2. ✅ Créer votre premier script en suivant chaque phase
3. ✅ Valider avec toutes les checklists
4. ✅ Demander une revue de code
5. ✅ Itérer jusqu'à la maîtrise complète

---

## 📞 Support et Ressources

### Documents de référence

1. **Document "Méthodologie de Développement Modulaire et Hiérarchique"**
   - Architecture et principes
   - Templates de base
   - Standards obligatoires
   - CI/CD et versioning

2. **Document "Méthodologie de Développement Modulaire - Partie 2"**
   - Bibliothèque de fonctions
   - Patterns avancés
   - Intégrations
   - Annexes pratiques

3. **Document "Guide de Démarrage"**
   - Comment utiliser les documents
   - Par où commencer
   - Stratégie de lecture

4. **Ce document "Méthodologie Précise de Développement"**
   - Processus étape par étape
   - Phases détaillées
   - Cas pratiques
   - Checklists

### En cas de blocage

**Ordre de résolution** :

1. ✅ **Relire la section concernée** dans ce document
2. ✅ **Consulter la FAQ** (Q&A dans ce document)
3. ✅ **Vérifier les annexes** du Document 2 (Troubleshooting)
4. ✅ **Examiner les cas pratiques** de ce document
5. ✅ **Chercher dans les documents de référence** avec Ctrl+F
6. ✅ **Consulter les exemples complets** (Document 1 et 2)
7. ✅ **Demander à l'équipe** ou ouvrir une issue

### Tableau de correspondance rapide

| Besoin | Document | Section |
|--------|----------|---------|
| Comprendre l'architecture | Doc 1 | Architecture hiérarchique |
| Voir un template complet | Doc 1 | Structure d'un script atomique/orchestrateur |
| Trouver une fonction (cache, retry...) | Doc 2 | Ctrl+F dans le sommaire |
| Savoir quelle fonction utiliser | Doc 2 | Tableaux "Quand utiliser..." |
| Comprendre les standards JSON | Doc 1 | Standard d'interface |
| Résoudre un problème | Doc 2 | Annexe E : Troubleshooting |
| Voir des commandes | Doc 2 | Annexe D : Commandes utiles |
| Débuter avec les documents | Guide | Les 5 étapes essentielles |
| Suivre le processus complet | Ce doc | Phases 0 à 7 |

### Amélioration continue

Cette méthodologie est vivante et doit évoluer :

**Vous pouvez contribuer en** :
- 🐛 Signalant les erreurs ou incohérences
- 💡 Proposant des améliorations
- 📝 Clarifiant les points obscurs
- 🆕 Partageant vos patterns utiles
- ✨ Créant de nouvelles bibliothèques
- 📖 Améliorant la documentation
- 🧪 Ajoutant des cas d'usage

**Process de contribution** :
1. Créer une issue décrivant le problème/amélioration
2. Discuter avec l'équipe
3. Implémenter la solution
4. Mettre à jour la documentation
5. Soumettre une PR

---

## 📊 Synthèse visuelle du processus

```
┌─────────────────────────────────────────────────────────────┐
│                    DÉVELOPPEMENT D'UN SCRIPT                 │
└─────────────────────────────────────────────────────────────┘

PHASE 0 : AVANT DE COMMENCER [30 min]
├── Vérifier unicité (grep, ls)
└── Définir rôle (fiche d'identité)
    ↓
PHASE 1 : PLANIFICATION [1h]
├── Déterminer niveau (arbre de décision)
├── Identifier dépendances (Doc 1 + Doc 2)
├── Définir nommage (verbe-objet.sh)
├── Définir codes sortie (0-8)
└── Concevoir JSON (structure standard)
    ↓
PHASE 2 : CRÉATION STRUCTURE [30 min]
├── Copier template (atomic/orchestrator)
├── Personnaliser en-tête (# Script:, # Description:...)
├── Configurer imports (lib/*.sh)
└── Définir variables (EXIT_*, globals)
    ↓
PHASE 3 : IMPLÉMENTATION [2-4h]
├── validate_prerequisites()
│   ├── validate_permissions
│   ├── validate_dependencies
│   └── validate_parameters
├── do_main_action() / orchestrate()
│   ├── Logique métier
│   ├── Logging (log_info, log_debug...)
│   └── Utilisation bibliothèques (Doc 2)
├── build_json_output()
│   └── JSON standardisé
└── cleanup()
    └── Nettoyage ressources + trap
    ↓
PHASE 4 : TESTS ET VALIDATION [1-2h]
├── Tests syntaxiques
│   ├── bash -n
│   ├── shellcheck
│   └── custom-linter
├── Tests fonctionnels
│   ├── Cas nominal
│   ├── Tous les cas d'erreur
│   └── Validation JSON (jq)
├── Tests unitaires
│   └── test-framework.sh
├── Tests intégration (orchestrateurs)
│   └── Flux complet
└── Validation logs
    └── Format et contenu
    ↓
PHASE 5 : DOCUMENTATION [1h]
├── Créer fichier .md
│   ├── Description
│   ├── Usage
│   ├── Options
│   ├── Dépendances
│   ├── Sortie JSON
│   ├── Codes de sortie
│   └── Exemples
├── Générer doc auto (optionnel)
└── Créer diagramme (orchestrateurs)
    ↓
PHASE 6 : VALIDATION FINALE [30 min]
├── Checklist automatique
│   └── validate-script.sh
├── Checklist manuelle
│   └── Tous les points
├── Intégration Git
│   ├── git add
│   ├── commit (format conventional)
│   └── push
└── Mise à jour changelog
    ↓
PHASE 7 : REVUE ET AMÉLIORATION [variable]
├── Revue de code (PR)
├── CI/CD automatique
├── Monitoring post-deploy
└── Documentation maintenance

┌─────────────────────────────────────────────────────────────┐
│  ✅ SCRIPT EN PRODUCTION                                     │
│  - Robuste, testé, documenté                                │
│  - Monitoré et maintenu                                      │
│  - Prêt à être composé dans des orchestrateurs              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Aide-mémoire pour les documents

### Document 1 : Méthodologie principale

**À utiliser pour** :
- ✅ Comprendre l'architecture globale
- ✅ Connaître les standards obligatoires
- ✅ Copier les templates de base
- ✅ Référence pour conventions et formats

**Structure principale** :
1. Architecture hiérarchique
2. Convention de nommage
3. Standards d'interface (codes sortie, JSON)
4. Templates (atomique, orchestrateur)
5. Logging centralisé
6. Validation et sécurité
7. Tests
8. CI/CD
9. Versioning
10. Monitoring

### Document 2 : Bibliothèque de fonctions

**À utiliser pour** :
- ✅ Trouver des fonctions réutilisables
- ✅ Découvrir des patterns avancés
- ✅ Résoudre des problèmes spécifiques
- ✅ Voir des cas d'usage complets

**Structure principale** :
1. Patterns avancés (cache, worker pool, retry)
2. Sécurité renforcée (sandbox, audit)
3. Gestion d'erreurs avancée
4. Intégrations (API, BDD, notifications)
5. Outils de développement
6. Documentation interactive
7. Cas d'usage
8. Annexes (commandes, troubleshooting)

### Document 3 : Guide de démarrage

**À utiliser pour** :
- ✅ Démarrer rapidement
- ✅ Comprendre comment utiliser Doc 1 et 2
- ✅ Éviter la paralysie de l'analyse
- ✅ Avoir un plan d'action clair

**Structure principale** :
1. Présentation des documents
2. 5 étapes essentielles
3. Workflow complet
4. Checklist pratique
5. Plan de lecture

### Document 4 : Méthodologie précise (ce document)

**À utiliser pour** :
- ✅ Suivre le processus étape par étape
- ✅ Savoir exactement quoi faire et quand
- ✅ Valider chaque phase
- ✅ Référence pendant le développement

**Structure principale** :
1. Phase 0 : Avant de commencer
2. Phase 1 : Planification
3. Phase 2 : Création structure
4. Phase 3 : Implémentation
5. Phase 4 : Tests
6. Phase 5 : Documentation
7. Phase 6 : Validation finale
8. Phase 7 : Revue
9. Cas pratiques et FAQ

---

## 🚦 Indicateurs de progression

### Comment savoir si je progresse bien ?

**Après 1 script (Jour 2)** :
- [ ] Je comprends la différence atomique/orchestrateur
- [ ] J'ai suivi toutes les phases consciencieusement
- [ ] Mon script passe tous les tests
- [ ] La validation automatique est à 100%

**Après 3 scripts (Semaine 1)** :
- [ ] Je commence à intérioriser le processus
- [ ] Je peux créer un atomique en 3-4h
- [ ] J'utilise naturellement les bibliothèques
- [ ] Je ne saute plus de phases

**Après 10 scripts (Mois 1)** :
- [ ] Le processus est automatique
- [ ] Je crée des atomiques en 2-3h
- [ ] J'ai créé mon premier orchestrateur
- [ ] Je contribue à améliorer la méthodologie

**Maîtrise complète (Mois 2-3)** :
- [ ] Je forme d'autres développeurs
- [ ] J'ai créé des orchestrateurs multi-niveaux
- [ ] Je crée de nouvelles bibliothèques
- [ ] Je pense naturellement en "atomique/composition"

---

## 💎 Principes philosophiques

### Principe 1 : "One Thing Well"

Chaque script fait **UNE chose**, mais la fait **parfaitement**.

```
❌ backup-and-restore-and-monitor.sh
✅ backup-files.sh
✅ restore-files.sh  
✅ monitor-backup.sh
```

### Principe 2 : "Composition over Complexity"

Préférer la **composition** de scripts simples plutôt qu'un script complexe.

```
❌ Un script de 1000 lignes qui fait tout
✅ 10 scripts de 100 lignes composés intelligemment
```

### Principe 3 : "Documentation as Code"

La documentation est **aussi importante** que le code.

```
Code sans doc = Code qui n'existe pas
Doc sans code = Doc inutile
Code + Doc + Tests = Script parfait
```

### Principe 4 : "Fail Fast, Clean Always"

**Échouer rapidement** avec un message clair, **nettoyer toujours**.

```bash
# Échouer vite
[[ -z "$REQUIRED" ]] && exit $EXIT_ERROR_USAGE

# Nettoyer toujours
trap cleanup EXIT ERR INT TERM
```

### Principe 5 : "Test Everything, Trust Nothing"

Tester **tous les chemins**, ne **rien assumer**.

```bash
# Cas nominal + toutes les erreurs possibles
test_success
test_missing_param
test_invalid_param
test_permission_denied
test_resource_not_found
```

### Principe 6 : "Standards Enable Creativity"

Les **standards libèrent** la créativité en éliminant les décisions triviales.

```
Pas de décision sur :
- Comment nommer ? → Convention établie
- Comment logger ? → logger.sh
- Quel format sortie ? → JSON standard
- Comment valider ? → validator.sh

Créativité sur :
- Quelle valeur métier ?
- Quelle architecture ?
- Quelles optimisations ?
```

---

## 🎓 Conclusion finale

### Ce que vous avez maintenant

Avec ces 4 documents, vous disposez d'un **système complet** pour développer des scripts de qualité professionnelle :

1. **Document 1** : Les fondations et standards
2. **Document 2** : La boîte à outils complète
3. **Document 3** : Le guide de démarrage rapide
4. **Document 4** : Le processus détaillé (ce doc)

### La promesse de cette méthodologie

Si vous suivez rigoureusement ce processus :

✅ Vos scripts seront **robustes** (gestion complète des erreurs)  
✅ Vos scripts seront **maintenables** (documentation exhaustive)  
✅ Vos scripts seront **testables** (tests automatiques)  
✅ Vos scripts seront **évolutifs** (architecture modulaire)  
✅ Vos scripts seront **sécurisés** (validation, audit)  
✅ Vos scripts seront **performants** (optimisations)  
✅ Vos scripts seront **monitorables** (métriques, alertes)  

### L'engagement requis

Cette qualité a un prix : **la discipline**.

- ⏱️ **Temps** : 6-9h pour un script atomique complet (au début)
- 📚 **Rigueur** : Suivre TOUTES les phases, même les fastidieuses
- 🧪 **Tests** : Tester TOUS les cas, pas seulement le nominal
- 📝 **Documentation** : Documenter COMPLÈTEMENT, pas "plus tard"
- ✅ **Validation** : Vérifier TOUTES les checklists

Mais après 10-20 scripts, ce processus devient **naturel** et le temps diminue à 2-4h.

### Le retour sur investissement

**Court terme** (1 mois) :
- Scripts qui fonctionnent du premier coup
- Pas de bugs en production
- Maintenance minimale

**Moyen terme** (3-6 mois) :
- Bibliothèque de scripts réutilisables
- Développement accéléré (composition)
- Confiance totale dans le code

**Long terme** (1 an+) :
- Système évolutif et scalable
- Onboarding rapide des nouveaux
- Dette technique quasi-nulle

### Les clés du succès

1. 🎯 **Commencer petit** : Un script simple pour apprendre
2. 📖 **Suivre le processus** : Ne pas improviser au début
3. ✅ **Valider systématiquement** : Checklists obligatoires
4. 🔄 **Itérer** : Chaque script est une occasion d'apprendre
5. 🤝 **Demander des revues** : Le feedback est crucial
6. 📚 **Documenter** : Pour soi et pour les autres
7. 🚀 **Persévérer** : La maîtrise vient avec la pratique

### Derniers conseils

**Ne cherchez pas la perfection** au premier script. Cherchez la **conformité**.

La perfection viendra avec l'expérience. La conformité aux standards garantit la qualité de base.

**Ne réinventez pas la roue**. Utilisez les bibliothèques fournies dans Document 2. Elles sont testées et éprouvées.

**Ne négligez pas la documentation**. Dans 6 mois, vous serez reconnaissant envers vous-même d'avoir bien documenté.

**Ne sautez pas les tests**. Un bug en production coûte 100x plus cher qu'un test unitaire.

---

## 🚀 Prêt à commencer ?

Vous avez maintenant **tout ce qu'il faut** pour développer des scripts de qualité professionnelle.

### Action immédiate

1. ✅ **Maintenant** : Choisir un script simple à créer
2. ✅ **Aujourd'hui** : Suivre les phases 0-2 (planification + structure)
3. ✅ **Demain** : Phases 3-4 (implémentation + tests)
4. ✅ **Après-demain** : Phases 5-6 (documentation + validation)

### Engagement

Je m'engage à :
- [ ] Suivre rigoureusement cette méthodologie
- [ ] Ne pas sauter de phases
- [ ] Tester complètement mes scripts
- [ ] Documenter exhaustivement
- [ ] Demander des revues de code
- [ ] Contribuer à l'amélioration de la méthodologie

### Support

Vous n'êtes pas seul. En cas de blocage :
- 📚 Consultez les 4 documents
- 🔍 Cherchez dans les FAQ
- 💡 Examinez les cas pratiques
- 🤝 Demandez à l'équipe

---

**Version** : 1.0.0  
**Date** : 2025-10-03  
**Auteur** : Équipe DevOps  
**Compatibilité** : Méthodologie v2.0  

---

**Bon développement ! 🚀**

*"La qualité n'est pas un acte, c'est une habitude."* - Aristote

*"Tout code est coupable jusqu'à preuve du contraire."* - Principe des tests

*"La documentation est un cadeau que vous faites à votre futur vous-même."* - Sagesse DevOps

**Maintenant, créez votre premier script ! 💪**- [ ] Logs créés dans le bon répertoire
- [ ] Cleanup fonctionne (pas de fichiers temporaires restants)

#### 4.3 - Validation de la sortie JSON

```bash
# Capturer la sortie
output=$(./atomics/mon-script.sh --param value)

# Valider le JSON
echo "$output" | jq empty || echo "❌ JSON invalide"

# Vérifier la structure obligatoire
echo "$output" | jq -e '.status' >/dev/null || echo "❌ Champ 'status' manquant"
echo "$output" | jq -e '.code' >/dev/null || echo "❌ Champ 'code' manquant"
echo "$output" | jq -e '.timestamp' >/dev/null || echo "❌ Champ 'timestamp' manquant"
echo "$output" | jq -e '.script' >/dev/null || echo "❌ Champ 'script' manquant"
echo "$output" | jq -e '.message' >/dev/null || echo "❌ Champ 'message' manquant"
echo "$output" | jq -e '.data' >/dev/null || echo "❌ Champ 'data' manquant"

# Vérifier les valeurs
status=$(echo "$output" | jq -r '.status')
[[ "$status" == "success" ]] || echo "❌ Status invalide: $status"

code=$(echo "$output" | jq -r '.code')
[[ "$code" == "0" ]] || echo "❌ Code invalide: $code"

script=$(echo "$output" | jq -r '.script')
[[ "$script" == "mon-script.sh" ]] || echo "❌ Script name invalide: $script"
```

**Référence** : Document "Méthodologie - Partie 1" > Standard d'interface > Format de sortie JSON

#### 4.4 - Tests unitaires (obligatoire pour atomiques)

**Créer le fichier de test** :

```bash
# tests/atomics/test-mon-script.sh
#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/tests/lib/test-framework.sh"

SCRIPT_UNDER_TEST="$PROJECT_ROOT/atomics/mon-script.sh"

echo "Testing: mon-script.sh"
echo "================================"

# Test 1: Script existe et est exécutable
test_script_executable() {
    echo ""
    echo "Test: Script exists and is executable"
    
    [[ -f "$SCRIPT_UNDER_TEST" ]] || { echo "❌ Script not found"; return 1; }
    [[ -x "$SCRIPT_UNDER_TEST" ]] || { echo "❌ Script not executable"; return 1; }
    
    echo "✓ Script exists and is executable"
}

# Test 2: Aide fonctionne
test_help() {
    echo ""
    echo "Test: Help display"
    
    local output
    output=$("$SCRIPT_UNDER_TEST" --help 2>&1) || true
    
    [[ "$output" =~ "Usage:" ]] || { echo "❌ Help missing Usage"; return 1; }
    [[ "$output" =~ "Options:" ]] || { echo "❌ Help missing Options"; return 1; }
    
    echo "✓ Help displays correctly"
}

# Test 3: Sortie JSON valide
test_json_output() {
    echo ""
    echo "Test: JSON output validity"
    
    local output
    output=$("$SCRIPT_UNDER_TEST" --param test 2>/dev/null) || true
    
    # Vérifier JSON valide
    echo "$output" | jq empty || { echo "❌ Invalid JSON"; return 1; }
    
    # Vérifier champs obligatoires
    assert_json_field "$output" ".status" "success" "Status field"
    assert_json_field "$output" ".code" "0" "Code field"
    assert_json_field "$output" ".script" "mon-script.sh" "Script field"
}

# Test 4: Gestion des erreurs
test_error_handling() {
    echo ""
    echo "Test: Error handling"
    
    # Test sans paramètre obligatoire
    local exit_code=0
    "$SCRIPT_UNDER_TEST" 2>/dev/null || exit_code=$?
    
    [[ $exit_code -eq 2 ]] || { echo "❌ Wrong exit code: $exit_code (expected 2)"; return 1; }
    
    echo "✓ Error handling works"
}

# Exécution des tests
test_script_executable
test_help
test_json_output
test_error_handling

# Rapport
test_report
```

**Référence** : Document "Méthodologie - Partie 1" > Tests > Framework de test

**Exécuter les tests** :

```bash
chmod +x tests/atomics/test-mon-script.sh
./tests/atomics/test-mon-script.sh
```

**Tous les tests doivent passer (100% de succès).**

#### 4.5 - Tests d'intégration (obligatoire pour orchestrateurs)

```bash
# tests/orchestrators/test-mon-orchestrateur.sh
#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ORCHESTRATOR="$PROJECT_ROOT/orchestrators/level-1/mon-orchestrateur.sh"

echo "Testing: mon-orchestrateur.sh"
echo "================================"

# Test 1: Orchestration complète
test_full_orchestration() {
    echo ""
    echo "Test: Full orchestration flow"
    
    local output
    output=$("$ORCHESTRATOR" --param test 2>/dev/null) || {
        echo "❌ Orchestration failed"
        return 1
    }
    
    # Vérifier que toutes les étapes sont présentes
    local steps=$(echo "$output" | jq -r '.data.steps_completed | length')
    [[ $steps -ge 2 ]] || {
        echo "❌ Not all steps completed: $steps"
        return 1
    }
    
    echo "✓ Full orchestration successful"
}

# Test 2: Gestion d'erreur en cascade
test_error_propagation() {
    echo ""
    echo "Test: Error propagation"
    
    # Forcer une erreur en passant un paramètre invalide
    local exit_code=0
    "$ORCHESTRATOR" --param invalid 2>/dev/null || exit_code=$?
    
    [[ $exit_code -ne 0 ]] || {
        echo "❌ Error not propagated"
        return 1
    }
    
    echo "✓ Error propagation works"
}

# Exécution
test_full_orchestration
test_error_propagation

echo ""
echo "================================"
echo "Integration tests completed"
```

#### 4.6 - Validation des logs

```bash
# Exécuter le script en mode verbose
LOG_LEVEL=0 ./atomics/mon-script.sh --debug --param test

# Vérifier que les logs sont créés
LOG_FILE="logs/atomics/$(date +%Y-%m-%d)/mon-script.log"
[[ -f "$LOG_FILE" ]] || echo "❌ Log file not created"

# Vérifier le contenu des logs
cat "$LOG_FILE"

# Checklist du contenu des logs :
# - [ ] [INFO] Script started
# - [ ] [DEBUG] Validating prerequisites
# - [ ] [INFO] Starting main action
# - [ ] [INFO] Script completed
# - [ ] Pas d'erreur non gérée
# - [ ] Format correct : [TIMESTAMP] [LEVEL] [SCRIPT:PID] [FUNCTION] Message
```

**Référence** : Document "Méthodologie - Partie 1" > Système de logging centralisé

---

## 📚 Phase 5 : Documentation

### Objectif
Documenter complètement le script pour faciliter sa réutilisation.

### Étapes

#### 5.1 - Créer la documentation Markdown

```bash
# Créer le fichier de documentation
mkdir -p docs/atomics  # ou docs/orchestrators
touch docs/atomics/mon-script.md
```

**Structure obligatoire** :

```markdown
# mon-script.sh

## Description
[Description détaillée de ce que fait le script]

## Usage
\`\`\`bash
./mon-script.sh [OPTIONS] <paramètres>
\`\`\`

## Options

| Option | Description | Valeur par défaut |
|--------|-------------|-------------------|
| `-h, --help` | Affiche l'aide | - |
| `-v, --verbose` | Mode verbeux | désactivé |
| `-d, --debug` | Mode debug | désactivé |
| `--param <value>` | Description du paramètre | - |

## Dépendances

### Système
- `commande1` : Description
- `commande2` : Description

### Bibliothèques
- `lib/logger.sh` : Système de logging
- `lib/validator.sh` : Validation des entrées

### Scripts (pour orchestrateurs uniquement)
- `atomics/script1.sh` : Description
- `atomics/script2.sh` : Description

## Sortie JSON

### Succès
\`\`\`json
{
  "status": "success",
  "code": 0,
  "timestamp": "2025-10-03T14:30:45Z",
  "script": "mon-script.sh",
  "message": "Operation completed successfully",
  "data": {
    "field1": "value1",
    "field2": "value2"
  },
  "errors": [],
  "warnings": []
}
\`\`\`

### Erreur
\`\`\`json
{
  "status": "error",
  "code": 4,
  "timestamp": "2025-10-03T14:30:45Z",
  "script": "mon-script.sh",
  "message": "Resource not found",
  "data": {},
  "errors": ["Detailed error message"],
  "warnings": []
}
\`\`\`

## Codes de sortie

| Code | Signification |
|------|---------------|
| 0 | Succès |
| 1 | Erreur générale |
| 2 | Paramètres invalides |
| 3 | Permissions insuffisantes |
| 4 | Ressource non trouvée |

## Exemples

### Exemple 1 : Utilisation basique
\`\`\`bash
./mon-script.sh --param value
\`\`\`

### Exemple 2 : Mode verbose
\`\`\`bash
./mon-script.sh --verbose --param value
\`\`\`

### Exemple 3 : Utilisation dans un autre script
\`\`\`bash
result=$(./mon-script.sh --param value)
field_value=$(echo "$result" | jq -r '.data.field1')
echo "Got value: $field_value"
\`\`\`

## Tests

\`\`\`bash
# Exécuter les tests unitaires
./tests/atomics/test-mon-script.sh
\`\`\`

## Changelog

### v1.0.0 (2025-10-03)
- Version initiale
- Fonctionnalité X implémentée

## Auteur
[Votre nom]

## Voir aussi
- `autre-script.sh` : Script connexe
```

**Référence** : Document "Méthodologie - Partie 1" > Documentation des scripts atomiques/orchestrateurs

#### 5.2 - Générer la documentation automatique (optionnel)

```bash
# Utiliser le générateur de documentation
./tools/doc-generator.sh all
```

**Référence** : Document "Méthodologie - Partie 2" > Outils de développement > Générateur de documentation

#### 5.3 - Créer un diagramme (obligatoire pour orchestrateurs)

**Pour les orchestrateurs, créer un diagramme de flux** :

```markdown
## Architecture

\`\`\`
mon-orchestrateur.sh (level-1)
├── detect-usb.sh (atomic)
├── format-disk.sh (atomic)
└── mount-disk.sh (atomic)
\`\`\`

## Flux d'exécution

\`\`\`mermaid
graph TD
    A[Début] --> B[detect-usb.sh]
    B --> C{USB trouvé?}
    C -->|Non| D[Erreur EXIT_ERROR_NOT_FOUND]
    C -->|Oui| E[format-disk.sh]
    E --> F[mount-disk.sh]
    F --> G[Succès]
\`\`\`
```

---

## ✅ Phase 6 : Validation finale et intégration

### Objectif
Valider que le script respecte tous les standards et peut être intégré au projet.

### Étapes

#### 6.1 - Checklist de validation complète

**Exécuter la checklist automatique** :

```bash
# Créer un script de validation
cat > tools/validate-script.sh <<'EOF'
#!/bin/bash

SCRIPT=$1

echo "Validating: $SCRIPT"
echo "================================"

errors=0

# 1. Shebang
[[ $(head -1 "$SCRIPT") == "#!/bin/bash" ]] || { echo "❌ Invalid shebang"; ((errors++)); }

# 2. set -euo pipefail
grep -q "set -euo pipefail" "$SCRIPT" || { echo "❌ Missing set -euo pipefail"; ((errors++)); }

# 3. Documentation header
grep -q "^# Script:" "$SCRIPT" || { echo "❌ Missing Script: header"; ((errors++)); }
grep -q "^# Description:" "$SCRIPT" || { echo "❌ Missing Description:"; ((errors++)); }
grep -q "^# Usage:" "$SCRIPT" || { echo "❌ Missing Usage:"; ((errors++)); }

# 4. Exit codes
grep -q "readonly EXIT_SUCCESS=0" "$SCRIPT" || { echo "❌ Missing EXIT_SUCCESS"; ((errors++)); }

# 5. Logger import
grep -q 'source.*lib/logger.sh' "$SCRIPT" || { echo "❌ Missing logger.sh import"; ((errors++)); }

# 6. Cleanup function
grep -q "cleanup()" "$SCRIPT" || { echo "❌ Missing cleanup function"; ((errors++)); }
grep -q "trap cleanup" "$SCRIPT" || { echo "❌ Missing trap cleanup"; ((errors++)); }

# 7. JSON output function
grep -q "build_json_output" "$SCRIPT" || { echo "❌ Missing build_json_output"; ((errors++)); }

# 8. Executable permission
[[ -x "$SCRIPT" ]] || { echo "❌ Not executable"; ((errors++)); }

# 9. Shellcheck
shellcheck "$SCRIPT" >/dev/null 2>&1 || { echo "❌ Shellcheck failed"; ((errors++)); }

# 10. Documentation exists
doc_file="docs/${SCRIPT#*/}"
doc_file="${doc_file%.sh}.md"
[[ -f "$doc_file" ]] || { echo "❌ Documentation missing: $doc_file"; ((errors++)); }

echo ""
if [[ $errors -eq 0 ]]; then
    echo "✅ All validations passed"
    exit 0
else
    echo "❌ $errors validation(s) failed"
    exit 1
fi
EOF

chmod +x tools/validate-script.sh
```

**Exécuter la validation** :

```bash
./tools/validate-script.sh atomics/mon-script.sh
```

#### 6.2 - Checklist manuelle finale

```markdown
## Checklist finale

### Code
- [ ] Passe shellcheck sans warning
- [ ] Passe le linter personnalisé
- [ ] Respecte le template (atomique ou orchestrateur)
- [ ] Nomné selon la convention (verbe-objet.sh)
- [ ] Tous les imports nécessaires présents
- [ ] Codes de sortie correctement définis

### Fonctionnalité
- [ ] Fait UNE chose bien définie (atomique)
- [ ] Compose correctement les scripts (orchestrateur)
- [ ] Tous les cas testés (succès, erreurs)
- [ ] Gestion d'erreurs complète
- [ ] Cleanup fonctionne
- [ ] Pas de fichiers temporaires restants

### Sortie
- [ ] JSON valide en sortie
- [ ] Structure JSON conforme au standard
- [ ] Tous les champs obligatoires présents
- [ ] Messages d'erreur clairs
- [ ] Logs corrects (format et contenu)

### Tests
- [ ] Tests unitaires écrits
- [ ] Tous les tests passent
- [ ] Coverage > 80%
- [ ] Tests d'intégration (orchestrateurs)

### Documentation
- [ ] Fichier .md créé
- [ ] Description complète
- [ ] Tous les exemples fonctionnent
- [ ] Dépendances documentées
- [ ] Codes de sortie documentés
- [ ] Diagramme créé (orchestrateurs)

### Validation
- [ ] Script de validation passe
- [ ] Pas de doublon (unicité vérifiée)
- [ ] Intégré dans l'arborescence correcte
- [ ] Tests automatisés dans CI/CD
```

#### 6.3 - Intégration dans le système

**1. Ajouter au contrôle de version** :

```bash
# Vérifier le statut
git status

# Ajouter les fichiers
git add atomics/mon-script.sh
git add docs/atomics/mon-script.md
git add tests/atomics/test-mon-script.sh

# Vérifier qu'il n'y a pas de fichiers indésirables
git status
```

**2. Créer un commit conforme** :

```bash
# Format : <type>(<scope>): <description>
# Types : feat, fix, refactor, docs, test, chore

git commit -m "feat(atomics): add mon-script.sh

- Implements functionality X
- Validates inputs Y
- Returns JSON with Z

Closes #123"
```

**Référence** : Document "Méthodologie - Partie 1" > Gestion des versions > Convention de messages de commit

**3. Mettre à jour l'index de documentation** :

```bash
# Régénérer l'index
./tools/doc-generator.sh index
git add docs/INDEX.md
git commit -m "docs: update index with mon-script.sh"
```

#### 6.4 - Mise à jour du changelog

```bash
# Si version mineure ou majeure
./tools/version-manager.sh changelog

# Vérifier le CHANGELOG.md
cat CHANGELOG.md
```

**Référence** : Document "Méthodologie - Partie 1" > Gestion des versions et changelog

---

## 🔄 Phase 7 : Revue et amélioration continue

### Objectif
S'assurer que le script peut être maintenu et amélioré.

### Étapes

#### 7.1 - Revue de code (si en équipe)

**Créer une Pull Request** :

```bash
# Pousser la branche
git push origin feature/mon-script

# Créer la PR sur GitHub/GitLab
# Titre : feat(atomics): add mon-script.sh
# Description : 
# - What: Script pour faire X
# - Why: Besoin de Y
# - How: Implémentation en Z
# - Tests: Tous les tests passent
```

**Points de revue** :

- [ ] Respect des standards
- [ ] Qualité du code
- [ ] Tests suffisants
- [ ] Documentation complète
- [ ] Pas de code dupliqué
- [ ] Performance acceptable

#### 7.2 - CI/CD automatique

**Vérifier que la CI passe** :

```yaml
# .github/workflows/test.yml ou .gitlab-ci.yml
# Vérifie automatiquement :
- shellcheck
- linter personnalisé
- tests unitaires
- tests d'intégration
- génération de documentation
```

**Référence** : Document "Méthodologie - Partie 1" > Système CI/CD

#### 7.3 - Monitoring post-déploiement

**Après le merge, vérifier** :

```bash
# 1. Le script est monitoré
cat monitoring/metrics/metrics-$(date +%Y-%m-%d).json | \
  jq '.[] | select(.script_name == "mon-script.sh")'

# 2. Les logs sont collectés
ls logs/atomics/$(date +%Y-%m-%d)/mon-script.log

# 3. Pas d'alertes
cat monitoring/metrics/alerts-$(date +%Y-%m-%d).json | \
  jq '.[] | select(.script == "mon-script.sh")'
```

**Référence** : Document "Méthodologie - Partie 1" > Métriques et monitoring

#### 7.4 - Documentation de maintenance

**Ajouter une section maintenance** :

```markdown
## Maintenance

### Dépendances à surveiller
- `commande1` : Peut changer dans version X
- `lib/cache.sh` : Utilisée pour Y

### Points d'attention
- Le cache expire après 1h
- Nécessite root pour Z
- Performance dégradée si > 1000 items

### Evolution prévue
- [ ] v1.1 : Ajouter support de X
- [ ] v2.0 : Refactor en Y

### Contact
- Mainteneur : @username
- Issue tracker : https://github.com/org/project/issues
```

---

## 📊 Récapitulatif : Workflow complet

### Vue d'ensemble

```
Phase 0: Avant de commencer (30 min)
  ├── Vérifier unicité
  └── Définir le rôle

Phase 1: Planification (1h)
  ├── Déterminer le niveau
  ├── Identifier dépendances
  ├── Définir nommage
  ├── Définir codes de sortie
  └── Concevoir JSON de sortie

Phase 2: Création structure (30 min)
  ├── Copier template
  ├── Personnaliser en-tête
  ├── Configurer imports
  └── Définir variables

Phase 3: Implémentation (2-4h)
  ├── Fonction validation
  ├── Logique métier
  ├── Construction JSON
  └── Fonction cleanup

Phase 4: Tests (1-2h)
  ├── Tests syntaxiques
  ├── Tests fonctionnels
  ├── Validation JSON
  ├── Tests unitaires
  ├── Tests intégration
  └── Validation logs

Phase 5: Documentation (1h)
  ├── Créer fichier .md
  ├── Générer doc auto
  └── Créer diagramme

Phase 6: Validation finale (30 min)
  ├── Checklist automatique
  ├── Checklist manuelle
  ├── Intégration Git
  └── Mise à jour changelog

Phase 7: Revue (variable)
  ├── Revue de code
  ├── CI/CD
  ├── Monitoring
  └── Documentation maintenance

TOTAL: 6-9 heures pour un script atomique complet
       8-12 heures pour un orchestrateur complexe
```

---

## 🎯 Cas pratiques

### Cas 1 : Créer un script atomique simple

**Besoin** : Lister les disques disponibles

**Application de la méthodologie** :

```bash
# Phase 0
grep -r "list.*disk" atomics/  # Vérifier unicité → Rien trouvé ✅

# Phase 1
# Niveau : Atomique (fait une seule chose)
# Nom : list-disks.sh (verbe-objet)
# Codes de sortie : 0, 1, 3
# JSON : {data: {disks: [...]}}

# Phase 2
./tools/script-generator.sh atomic list-disks

# Phase 3
# Implémenter do_main_action() avec lsblk
# Importer lib/logger.sh uniquement

# Phase 4
shellcheck atomics/list-disks.sh
./atomics/list-disks.sh | jq .
./tests/atomics/test-list-disks.sh

# Phase 5
# Créer docs/atomics/list-disks.md

# Phase 6
git add atomics/list-disks.sh docs/atomics/list-disks.md tests/atomics/test-list-disks.sh
git commit -m "feat(atomics): add list-disks.sh"
```

### Cas 2 : Créer un orchestrateur niveau 1

**Besoin** : Configurer un disque USB (détecter + formater + monter)

**Application de la méthodologie** :

```bash
# Phase 0
# Vérifier que setup-usb-disk.sh n'existe pas ✅
# Vérifier que detect-usb.sh, format-disk.sh, mount-disk.sh existent ✅

# Phase 1
# Niveau : Orchestrateur 1 (appelle 3 atomiques)
# Nom : setup-usb-disk.sh
# Dépendances : detect-usb.sh, format-disk.sh, mount-disk.sh
# JSON : {data: {steps_completed: [...], disk: "...", ...}}

# Phase 2
./tools/script-generator.sh orchestrator setup-usb-disk 1

# Phase 3
# Implémenter orchestrate()
# - Appeler detect-usb.sh
# - Parser le JSON pour récupérer le device
# - Appeler format-disk.sh avec le device
# - Appeler mount-disk.sh
# Importer lib/logger.sh + lib/notifications.sh

# Phase 4
shellcheck orchestrators/level-1/setup-usb-disk.sh
./orchestrators/level-1/setup-usb-disk.sh --device /dev/sdb | jq .
./tests/orchestrators/test-setup-usb-disk.sh

# Phase 5
# Créer docs/orchestrators/setup-usb-disk.md
# Créer diagramme de flux

# Phase 6
git add orchestrators/level-1/setup-usb-disk.sh \
        docs/orchestrators/setup-usb-disk.md \
        tests/orchestrators/test-setup-usb-disk.sh
git commit -m "feat(orchestrators): add setup-usb-disk.sh level-1"
```

### Cas 3 : Ajouter du cache à un script existant

**Besoin** : detect-usb.sh est trop lent, ajouter du cache

**Application de la méthodologie** :

```bash
# Phase 1 (re-planification)
# Ajouter dépendance : lib/cache.sh

# Phase 2
# Ajouter l'import
echo 'source "$PROJECT_ROOT/lib/cache.sh"' >> atomics/detect-usb.sh

# Phase 3
# Modifier do_main_action() :
# - init_cache
# - Vérifier cache_exists
# - cache_get ou exécuter + cache_set

# Référence : Doc 2 > Pattern : Cache et mémorisation
# Copier les fonctions cache_* depuis lib/cache.sh

# Phase 4
# Re-tester tout
./tests/atomics/test-detect-usb.sh

# Phase 5
# Mettre à jour la documentation
# Ajouter section "Cache" dans docs/atomics/detect-usb.md

# Phase 6
git add atomics/detect-usb.sh lib/cache.sh docs/atomics/detect-usb.md
git commit -m "perf(atomics): add caching to detect-usb.sh"
```

---

## ⚠️ Pièges courants à éviter

### Piège 1 : Ne pas vérifier l'unicité

```bash
❌ Créer create-backup.sh alors que backup-create.sh existe
✅ Utiliser backup-create.sh ou améliorer l'existant
```

### Piège 2 : Script atomique qui fait trop

```bash
❌ backup-and-restore.sh  # Fait 2 choses
✅ backup-files.sh + restore-files.sh  # 2 atomiques distincts
```

### Piège 3 : Oublier les imports

```bash
❌ Ne pas importer logger.sh
✅ Toujours importer au minimum logger.sh et validator.sh
```

### Piège 4 : JSON invalide

```bash
❌ Construire le JSON manuellement sans validation
✅ Utiliser build_json_output() et valider avec jq
```

### Piège 5 : Pas de cleanup

```bash
❌ Créer des fichiers temporaires sans les nettoyer
✅ Toujours implémenter cleanup() et trap
```

### Piège 6 : Copier toute la documentation

```bash
❌ Copier les 2 documents complets dans le projet
✅ Copier uniquement les bibliothèques nécessaires
```

### Piège 7 : Ne pas tester tous les cas

```bash
❌ Tester seulement le cas nominal
✅ Tester succès + toutes les erreurs possibles
```

### Piège 8 : Documentation obsolète

```bash
❌ Modifier le code sans mettre à jour la doc
✅ Toujours synchroniser code et documentation
```

---

## 📚 Références rapides

### Documents à consulter selon la phase

| Phase | Document | Section |
|-------|----------|---------|
| 0 - Unicité | - | Recherche manuelle |
| 1 - Planification | Doc 1 | Architecture hiérarchique<br>Convention de nommage<br>Codes de sortie<br>Format JSON |
| 2 - Structure | Doc 1 | Templates atomique/orchestrateur |
| 3 - Implémentation | Doc 1<br>Doc 2 | lib/logger.sh<br>lib/validator.sh<br>Bibliothèques selon besoin |
| 4 - Tests | Doc 1 | Tests<br>Framework de test |
| 5 - Documentation | Doc 1 | Documentation scripts |
| 6 - Validation | Doc 1<br>Doc 2 | Standards<br>Linter personnalisé |
| 7 - Monitoring | Doc 1 | Métriques et monitoring |

### Commandes essentielles

```bash
# Recherche
grep -r "pattern" atomics/ orchestrators/

# Création
./tools/script-generator.sh atomic|orchestrator nom [level]

# Validation
bash -n script.sh
shellcheck script.sh
./tools/custom-linter.sh script.sh
./tools/validate-script.sh script.sh

# Test
./script.# Méthodologie Précise de Développement d'un Script

## Introduction

Ce document décrit **la méthodologie étape par étape** pour développer un script, quel que soit son niveau (atomique, orchestrateur, ou autre). Chaque étape doit être suivie rigoureusement pour garantir le respect des standards et l'unicité des scripts.

---

## 📐 Phase 0 : Avant de commencer

### Objectif
Vérifier que le script que vous voulez créer n'existe pas déjà et définir précisément son rôle.

### Étapes

#### 0.1 - Vérifier l'unicité du script

**Action** : Rechercher si un script similaire existe déjà

```bash
# Rechercher dans les scripts existants
grep -r "Description:.*votre_concept" atomics/ orchestrators/

# Lister tous les scripts par thématique
ls atomics/ | grep "detect-"    # Scripts de détection
ls atomics/ | grep "format-"    # Scripts de formatage
ls atomics/ | grep "setup-"     # Scripts de configuration

# Rechercher dans la documentation
grep -r "votre_fonctionnalité" docs/
```

**Critère de décision** :

| Si le script... | Alors... |
|----------------|----------|
| Existe déjà exactement | ❌ Ne pas créer - Utiliser l'existant |
| Existe avec 80% de similitude | ❌ Ne pas créer - Améliorer l'existant |
| Existe mais avec une fonction différente | ✅ Créer un nouveau script |
| N'existe pas du tout | ✅ Créer le script |

**Exemple** :
```
Besoin : "Lister les périphériques USB"
Recherche : grep -r "USB" atomics/
Résultat : detect-usb.sh existe déjà
Action : Utiliser detect-usb.sh, NE PAS créer list-usb.sh
```

#### 0.2 - Définir précisément le rôle du script

**Remplir cette fiche** :

```markdown
## Fiche d'identité du script

**Nom** : [verbe]-[objet].[sous-objet].sh
Exemple : detect-usb.sh, format-disk.sh, setup-network.interface.sh

**Niveau** : 
- [ ] Atomique (niveau 0)
- [ ] Orchestrateur niveau 1
- [ ] Orchestrateur niveau 2
- [ ] Orchestrateur niveau N

**Description en une phrase** :
[Ce script fait exactement CELA]

**Action unique** (pour atomique seulement) :
[UNE SEULE action bien définie]

**Dépendances** (pour orchestrateur) :
- Script 1 (niveau X)
- Script 2 (niveau Y)

**Entrées** :
- Paramètre 1 : type, obligatoire/optionnel
- Paramètre 2 : type, obligatoire/optionnel

**Sortie JSON attendue** :
{
  "data": {
    "champ1": "...",
    "champ2": "..."
  }
}

**Codes de sortie utilisés** :
- 0 : Succès
- X : Type d'erreur spécifique
```

**Validation** : 
- ✅ La description tient en UNE phrase
- ✅ Pour un atomique : UNE SEULE action
- ✅ Pour un orchestrateur : au moins 2 dépendances claires

---

## 📝 Phase 1 : Planification et conception

### Objectif
Concevoir l'architecture du script avant d'écrire une ligne de code.

### Étapes

#### 1.1 - Déterminer le niveau exact du script

**Référence** : Document "Méthodologie - Partie 1" > Architecture hiérarchique

**Arbre de décision** :

```
┌─ Mon script appelle-t-il d'autres scripts du projet ?
│
├─ NON → ATOMIQUE (niveau 0)
│  │
│  └─ Fait-il UNE SEULE chose bien définie ?
│     ├─ OUI → ✅ Atomique valide
│     └─ NON → ❌ Diviser en plusieurs atomiques
│
└─ OUI → ORCHESTRATEUR
   │
   ├─ Appelle uniquement des atomiques ?
   │  └─ OUI → Orchestrateur niveau 1
   │
   ├─ Appelle des orchestrateurs niveau 1 ?
   │  └─ OUI → Orchestrateur niveau 2
   │
   └─ Appelle des orchestrateurs niveau N-1 ?
      └─ OUI → Orchestrateur niveau N
```

**Exemples** :

| Script | Niveau | Justification |
|--------|--------|---------------|
| `detect-usb.sh` | Atomique | Détecte USB, ne fait que ça, n'appelle rien |
| `format-disk.sh` | Atomique | Formate un disque, action unique |
| `setup-usb-disk.sh` | Orchestrateur 1 | Appelle detect-usb.sh + format-disk.sh + mount-disk.sh |
| `backup-system.sh` | Orchestrateur 2 | Appelle setup-usb-disk.sh + copy-files.sh |

#### 1.2 - Identifier les dépendances

##### Pour un script atomique

**Dépendances système à vérifier** :

```bash
# Lister les commandes que votre script va utiliser
Commandes nécessaires : lsblk, udevadm, awk
Packages requis : util-linux, udev
Permissions requises : root / user
```

**Bibliothèques du framework à importer** :

```bash
# Toujours nécessaires
source "$PROJECT_ROOT/lib/logger.sh"      # Logging obligatoire

# Selon le besoin
source "$PROJECT_ROOT/lib/validator.sh"   # Si validation d'entrées
source "$PROJECT_ROOT/lib/cache.sh"       # Si mise en cache
source "$PROJECT_ROOT/lib/retry.sh"       # Si opérations réseau/distantes
```

**Référence** : Document "Méthodologie - Partie 2" > Bibliothèques disponibles

##### Pour un orchestrateur

**Cartographier les scripts appelés** :

```
Mon orchestrateur : backup-system.sh (niveau 2)
│
├─ setup-usb-disk.sh (niveau 1)
│  ├─ detect-usb.sh (atomique)
│  ├─ format-disk.sh (atomique)
│  └─ mount-disk.sh (atomique)
│
└─ copy-files.sh (atomique)
```

**Créer le fichier de dépendances** :

```bash
# docs/orchestrators/backup-system.md
## Dépendances

### Scripts
- `orchestrators/level-1/setup-usb-disk.sh` : Configuration du disque USB
- `atomics/copy-files.sh` : Copie des fichiers

### Bibliothèques
- `lib/logger.sh` : Logging
- `lib/notifications.sh` : Notifications
```

#### 1.3 - Définir la convention de nommage

**Référence** : Document "Méthodologie - Partie 1" > Convention de nommage

**Pour un script atomique** :

```bash
Format : <verbe>-<objet>[.<sous-objet>].sh

Verbes autorisés :
- detect-    # Détection/découverte
- list-      # Listage
- get-       # Récupération d'information
- set-       # Configuration/modification
- create-    # Création
- delete-    # Suppression
- validate-  # Validation
- check-     # Vérification d'état
- format-    # Formatage
- mount-     # Montage
- backup-    # Sauvegarde
- restore-   # Restauration

Exemples valides :
✅ detect-usb.sh
✅ format-disk.sh
✅ get-network.interface.sh
✅ list-pci.ports.sh

Exemples INVALIDES :
❌ usb-detection.sh        # Pas verbe-objet
❌ DetectUSB.sh            # Pas de CamelCase
❌ detect_usb.sh           # Underscore au lieu de tiret
❌ detectusb.sh            # Pas de séparateur
```

**Pour un orchestrateur** :

```bash
Format : <action>-<domaine>[.<contexte>].sh

Actions :
- setup-        # Configuration complète
- configure-    # Configuration
- deploy-       # Déploiement
- manage-       # Gestion
- provision-    # Provisionnement

Exemples valides :
✅ setup-disk.sh
✅ configure-network.sh
✅ deploy-web.server.sh
✅ manage-backup.system.sh

Exemples INVALIDES :
❌ disk-setup.sh           # Ordre inversé
❌ setupDisk.sh            # CamelCase
```

**Vérifier l'unicité du nom** :

```bash
# Le nom ne doit pas exister
ls atomics/ | grep "^mon-nouveau-script.sh$"    # Doit être vide
ls orchestrators/**/*.sh | grep "mon-script"    # Doit être vide
```

#### 1.4 - Définir les codes de sortie

**Référence** : Document "Méthodologie - Partie 1" > Standard d'interface > Codes de sortie

**Codes obligatoires** (toujours définir) :

```bash
readonly EXIT_SUCCESS=0          # Succès
readonly EXIT_ERROR_GENERAL=1    # Erreur générale
```

**Codes optionnels** (selon le besoin) :

```bash
readonly EXIT_ERROR_USAGE=2      # Paramètres invalides
readonly EXIT_ERROR_PERMISSION=3 # Pas les permissions
readonly EXIT_ERROR_NOT_FOUND=4  # Ressource non trouvée
readonly EXIT_ERROR_ALREADY=5    # Ressource existe déjà
readonly EXIT_ERROR_DEPENDENCY=6 # Dépendance manquante
readonly EXIT_ERROR_TIMEOUT=7    # Timeout
readonly EXIT_ERROR_VALIDATION=8 # Validation échouée
```

**Décision** :

```markdown
Mon script peut échouer parce que :
- [ ] Paramètres invalides → EXIT_ERROR_USAGE (2)
- [ ] Pas root → EXIT_ERROR_PERMISSION (3)
- [ ] Fichier introuvable → EXIT_ERROR_NOT_FOUND (4)
- [ ] Fichier existe déjà → EXIT_ERROR_ALREADY (5)
- [ ] Commande manquante → EXIT_ERROR_DEPENDENCY (6)
- [ ] Timeout réseau → EXIT_ERROR_TIMEOUT (7)
- [ ] Validation entrée → EXIT_ERROR_VALIDATION (8)
```

#### 1.5 - Concevoir la structure JSON de sortie

**Référence** : Document "Méthodologie - Partie 1" > Standard d'interface > Format de sortie JSON

**Template de base** (obligatoire) :

```json
{
  "status": "success|error|warning",
  "code": 0,
  "timestamp": "2025-10-03T14:30:45Z",
  "script": "nom-du-script.sh",
  "message": "Description lisible",
  "data": {
    // Données spécifiques
  },
  "errors": [],
  "warnings": []
}
```

**Concevoir la section `data`** :

```markdown
## Données retournées par mon script

Pour detect-usb.sh :
{
  "data": {
    "count": 2,
    "devices": [
      {
        "id": "usb-0001",
        "vendor": "SanDisk",
        "device": "/dev/sdb",
        "size_gb": 64
      }
    ]
  }
}

Pour backup-system.sh :
{
  "data": {
    "source": "/home",
    "destination": "/backup",
    "files_copied": 1523,
    "size_mb": 4567,
    "duration_seconds": 234,
    "steps_completed": [
      {"step": "setup-disk", "status": "success"},
      {"step": "copy-files", "status": "success"}
    ]
  }
}
```

---

## 🏗️ Phase 2 : Création de la structure

### Objectif
Créer le fichier avec le template approprié et la structure standard.

### Étapes

#### 2.1 - Choisir et copier le template approprié

**Référence** : 
- Document "Méthodologie - Partie 1" > Structure d'un script atomique
- Document "Méthodologie - Partie 1" > Structure d'un orchestrateur

##### Pour un script atomique

```bash
# Créer le fichier depuis le template
cp templates/template-atomic.sh atomics/mon-script.sh

# OU utiliser l'outil de génération
./tools/script-generator.sh atomic mon-script
```

**Référence du template** : Document "Méthodologie - Partie 1" > Template `atomics/template-atomic.sh`

##### Pour un orchestrateur

```bash
# Déterminer le niveau
LEVEL=1  # ou 2, ou 3, etc.

# Créer le fichier
mkdir -p orchestrators/level-${LEVEL}
cp templates/template-orchestrator.sh orchestrators/level-${LEVEL}/mon-orchestrateur.sh

# OU utiliser l'outil
./tools/script-generator.sh orchestrator mon-orchestrateur ${LEVEL}
```

**Référence du template** : Document "Méthodologie - Partie 1" > Template `orchestrators/template-orchestrator.sh`

#### 2.2 - Personnaliser l'en-tête de documentation

**Standard obligatoire** :

```bash
#!/bin/bash
#
# Script: mon-script.sh
# Description: [Description en UNE phrase de ce que fait le script]
# Usage: mon-script.sh [OPTIONS] <paramètres>
#
# Options:
#   -h, --help              Affiche cette aide
#   -v, --verbose           Mode verbeux
#   -d, --debug             Mode debug
#   [autres options spécifiques]
#
# Exit codes:
#   0 - Succès
#   1 - Erreur générale
#   [autres codes utilisés]
#
# Examples:
#   ./mon-script.sh
#   ./mon-script.sh --verbose param1
#   ./mon-script.sh --option value param1
#
```

**Checklist de validation** :

- [ ] Ligne 1 : `#!/bin/bash` (exactement)
- [ ] Ligne 3 : `# Script: nom-du-fichier.sh` (nom exact du fichier)
- [ ] `# Description:` en UNE phrase claire
- [ ] `# Usage:` avec la syntaxe correcte
- [ ] Toutes les options documentées
- [ ] Tous les codes de sortie documentés
- [ ] Au moins 2 exemples d'utilisation

#### 2.3 - Configurer la section des imports

**Imports obligatoires** (tous les scripts) :

```bash
set -euo pipefail

# Détection du répertoire du projet
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"  # Adapter selon le niveau

# Import des bibliothèques (OBLIGATOIRE)
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"
source "$PROJECT_ROOT/lib/validator.sh"
```

**Imports optionnels** (selon besoin identifié en Phase 1.2) :

```bash
# Si mise en cache nécessaire
source "$PROJECT_ROOT/lib/cache.sh"

# Si retry nécessaire (opérations réseau, etc.)
source "$PROJECT_ROOT/lib/retry.sh"

# Si exécution parallèle nécessaire
source "$PROJECT_ROOT/lib/worker-pool.sh"

# Si notifications nécessaires
source "$PROJECT_ROOT/lib/notifications.sh"

# Si appels API nécessaires
source "$PROJECT_ROOT/lib/api-client.sh"

# Si interactions base de données nécessaires
source "$PROJECT_ROOT/lib/database.sh"

# Si sandbox nécessaire
source "$PROJECT_ROOT/lib/sandbox.sh"

# Si audit nécessaire
source "$PROJECT_ROOT/lib/audit.sh"

# Si timeout nécessaire
source "$PROJECT_ROOT/lib/timeout.sh"
```

**Comment décider quoi importer ?** :

Référence : Document "Méthodologie - Partie 2" > Chaque bibliothèque a sa section

| Si mon script doit... | Alors importer... | Section de référence |
|----------------------|-------------------|---------------------|
| Mettre en cache des résultats | `lib/cache.sh` | Doc 2 > Pattern : Cache et mémorisation |
| Réessayer en cas d'échec | `lib/retry.sh` | Doc 2 > Pattern : Retry avec backoff |
| Exécuter en parallèle | `lib/worker-pool.sh` | Doc 2 > Pattern : Pool de workers |
| Envoyer des notifications | `lib/notifications.sh` | Doc 2 > Webhooks et notifications |
| Appeler des APIs | `lib/api-client.sh` | Doc 2 > Intégration API REST |
| Accéder à une BDD | `lib/database.sh` | Doc 2 > Intégration avec bases de données |

#### 2.4 - Définir les variables globales

**Standard** :

```bash
# Codes de sortie (définis en Phase 1.4)
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR_GENERAL=1
readonly EXIT_ERROR_PERMISSION=3
# ... autres codes

# Variables globales du script
VERBOSE=0
DEBUG=0
# Variables métier spécifiques
PARAM1=""
PARAM2=""
```

**Règles** :
- ✅ Codes de sortie en `readonly`
- ✅ Constantes en `MAJUSCULES`
- ✅ Variables modifiables initialisées
- ❌ Pas de valeurs hardcodées (utiliser des variables)

---

## ⚙️ Phase 3 : Implémentation de la logique

### Objectif
Implémenter la logique métier en respectant les standards.

### Étapes

#### 3.1 - Implémenter la fonction de validation

**Référence** : Document "Méthodologie - Partie 1" > Validation et sécurité

**Template standard** :

```bash
validate_prerequisites() {
    log_debug "Validating prerequisites"
    
    # 1. Vérification des permissions
    validate_permissions || exit $EXIT_ERROR_PERMISSION
    
    # 2. Vérification des dépendances système
    validate_dependencies "cmd1" "cmd2" "cmd3" || exit $EXIT_ERROR_DEPENDENCY
    
    # 3. Validation des paramètres d'entrée
    if [[ -z "$REQUIRED_PARAM" ]]; then
        log_error "Missing required parameter"
        exit $EXIT_ERROR_USAGE
    fi
    
    # 4. Validation spécifique (selon type)
    # Exemple pour un périphérique bloc
    if [[ ! -b "$DEVICE" ]]; then
        log_error "Not a block device: $DEVICE"
        exit $EXIT_ERROR_NOT_FOUND
    fi
    
    log_debug "Prerequisites validated"
}
```

**Fonctions de validation disponibles** :

Référence : Document "Méthodologie - Partie 1" > `lib/validator.sh`

```bash
# Validation des permissions
validate_permissions  # Vérifie si root

# Validation des dépendances
validate_dependencies "jq" "curl" "awk"

# Validation d'un périphérique bloc
validate_block_device "/dev/sdb"

# Validation d'un système de fichiers
validate_filesystem "ext4"
```

**Checklist** :

- [ ] Permissions vérifiées
- [ ] Dépendances système vérifiées
- [ ] Paramètres obligatoires vérifiés
- [ ] Paramètres validés (format, type, existence)
- [ ] Codes de sortie appropriés en cas d'erreur

#### 3.2 - Implémenter la logique métier principale

##### Pour un script atomique

**Structure standard** :

```bash
do_main_action() {
    log_info "Starting main action"
    
    # Étape 1 : Préparation
    log_debug "Preparing..."
    local temp_var=$(prepare_something)
    
    # Étape 2 : Action principale
    log_info "Executing main operation"
    local result=$(execute_operation "$temp_var")
    
    # Étape 3 : Post-traitement
    log_debug "Post-processing..."
    local final_result=$(process_result "$result")
    
    log_info "Main action completed successfully"
    
    # Retourner les données au format attendu (JSON ou variable)
    echo "$final_result"
}
```

**Règles** :

- ✅ Logging à chaque étape importante
- ✅ Gestion des erreurs avec codes appropriés
- ✅ Variables locales (`local`)
- ✅ Retour structuré
- ❌ Pas d'echo pour debug (utiliser `log_debug`)
- ❌ Pas de modification d'état global

**Utilisation des bibliothèques** :

```bash
# Exemple avec cache
do_main_action() {
    local cache_key=$(cache_key "$(basename "$0")" "$@")
    
    # Vérifier le cache
    if cache_exists "$cache_key"; then
        log_info "Returning cached result"
        cache_get "$cache_key"
        return 0
    fi
    
    # Exécuter l'action
    log_info "Executing action"
    local result=$(expensive_operation)
    
    # Mettre en cache
    cache_set "$cache_key" "$result"
    
    echo "$result"
}
```

Référence : Document "Méthodologie - Partie 2" > `lib/cache.sh`

```bash
# Exemple avec retry
do_main_action() {
    log_info "Starting network operation"
    
    # Retry automatique en cas d'échec
    if retry_execute "curl -s https://api.example.com/data" 3; then
        log_info "API call successful"
        return 0
    else
        log_error "API call failed after retries"
        return $EXIT_ERROR_GENERAL
    fi
}
```

Référence : Document "Méthodologie - Partie 2" > `lib/retry.sh`

##### Pour un orchestrateur

**Structure standard** :

```bash
orchestrate() {
    log_info "Starting orchestration"
    
    local steps_completed=[]
    
    # Étape 1 : Exécuter script atomique 1
    log_info "Step 1: Executing atomic-script-1"
    local result1
    result1=$(execute_script "$PROJECT_ROOT/atomics/script1.sh" "param1") || return $?
    
    # Parser les données nécessaires
    local data1=$(echo "$result1" | jq -r '.data.field')
    
    # Enregistrer le step
    steps_completed=$(echo "$steps_completed" | jq ". += [{\"step\": \"script1\", \"status\": \"success\"}]")
    
    # Étape 2 : Exécuter script atomique 2 avec données de l'étape 1
    log_info "Step 2: Executing atomic-script-2"
    local result2
    result2=$(execute_script "$PROJECT_ROOT/atomics/script2.sh" "$data1") || return $?
    
    steps_completed=$(echo "$steps_completed" | jq ". += [{\"step\": \"script2\", \"status\": \"success\"}]")
    
    # Construire le résultat agrégé
    local final_data=$(cat <<EOF
{
  "steps_completed": $steps_completed,
  "result1": $(echo "$result1" | jq '.data'),
  "result2": $(echo "$result2" | jq '.data')
}
EOF
)
    
    log_info "Orchestration completed"
    echo "$final_data"
}
```

**Fonction helper pour exécuter les scripts** :

Référence : Document "Méthodologie - Partie 1" > Template orchestrateur

```bash
execute_script() {
    local script_path=$1
    shift
    local script_args=("$@")
    
    log_info "Executing: $(basename "$script_path") ${script_args[*]}"
    
    local start_time=$(date +%s%3N)
    local output
    local exit_code=0
    
    # Exécution et capture
    output=$("$script_path" "${script_args[@]}" 2>&1) || exit_code=$?
    
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script failed: $(basename "$script_path") (exit code: $exit_code)"
        echo "$output"
        return $exit_code
    fi
    
    log_info "Script completed: $(basename "$script_path") (${duration}ms)"
    
    # Retourner le JSON parsé
    echo "$output"
}
```

**Checklist orchestrateur** :

- [ ] Chaque étape logged
- [ ] Gestion d'erreur pour chaque appel
- [ ] Parsing JSON des résultats intermédiaires
- [ ] Agrégation des résultats dans `steps_completed`
- [ ] Données passées entre les étapes
- [ ] Sortie JSON finale agrégée

#### 3.3 - Implémenter la construction de la sortie JSON

**Référence** : Document "Méthodologie - Partie 1" > Standard d'interface

**Fonction standard** (obligatoire) :

```bash
build_json_output() {
    local status=$1
    local code=$2
    local message=$3
    local data=$4
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat <<EOF
{
  "status": "$status",
  "code": $code,
  "timestamp": "$timestamp",
  "script": "$(basename "$0")",
  "message": "$message",
  "data": $data,
  "errors": [],
  "warnings": []
}
EOF
}
```

**Utilisation** :

```bash
# Succès
local result='{"key": "value"}'
json_output=$(build_json_output "success" $EXIT_SUCCESS "Operation completed" "$result")

# Erreur
json_output=$(build_json_output "error" $EXIT_ERROR_NOT_FOUND "Device not found" '{}')
```

**Validation de la sortie JSON** :

```bash
# Toujours valider avec jq avant de retourner
echo "$json_output" | jq empty || {
    log_error "Invalid JSON output"
    exit $EXIT_ERROR_GENERAL
}
```

#### 3.4 - Implémenter la fonction de nettoyage

**Standard obligatoire** :

```bash
cleanup() {
    local exit_code=$?
    log_debug "Cleanup triggered with exit code: $exit_code"
    
    # Nettoyage des ressources temporaires
    [[ -n "${TEMP_FILE:-}" ]] && rm -f "$TEMP_FILE"
    [[ -n "${TEMP_DIR:-}" ]] && rm -rf "$TEMP_DIR"
    
    # Démontage si nécessaire
    [[ -n "${MOUNT_POINT:-}" ]] && umount "$MOUNT_POINT" 2>/dev/null || true
    
    # Autres nettoyages spécifiques
    
    exit $exit_code
}

# Trappe obligatoire
trap cleanup EXIT ERR INT TERM
```

**Règles** :

- ✅ Toujours implémenter `cleanup()`
- ✅ Toujours définir `trap cleanup EXIT ERR INT TERM`
- ✅ Nettoyer TOUTES les ressources créées
- ✅ Utiliser `|| true` pour éviter les erreurs sur cleanup
- ❌ Ne jamais exit dans cleanup (sauf le exit final)

---

## 🧪 Phase 4 : Tests et validation

### Objectif
Valider que le script fonctionne correctement et respecte tous les standards.

### Étapes

#### 4.1 - Tests syntaxiques

```bash
# 1. Vérification syntaxe Bash
bash -n atomics/mon-script.sh

# 2. Shellcheck (OBLIGATOIRE - doit passer sans warning)
shellcheck atomics/mon-script.sh

# 3. Linter personnalisé
./tools/custom-linter.sh atomics/mon-script.sh
```

**Référence** : Document "Méthodologie - Partie 2" > Outils de développement > Linter personnalisé

**Tous les warnings doivent être corrigés avant de continuer.**

#### 4.2 - Tests fonctionnels manuels

```bash
# Test 1 : Exécution normale (cas nominal)
./atomics/mon-script.sh --param value

# Vérifier :
# - Exit code = 0
# - JSON valide en sortie
# - Logs créés correctement

# Test 2 : Aide
./atomics/mon-script.sh --help

# Vérifier :
# - Affiche l'aide complète
# - Exit code = 0

# Test 3 : Paramètre manquant
./atomics/mon-script.sh

# Vérifier :
# - Message d'erreur clair
# - Exit code = 2 (EXIT_ERROR_USAGE)

# Test 4 : Paramètre invalide
./atomics/mon-script.sh --param invalid_value

# Vérifier :
# - Message d'erreur clair
# - Exit code = 8 (EXIT_ERROR_VALIDATION)

# Test 5 : Sans permissions (si applicable)
sudo -u nobody ./atomics/mon-script.sh --param value

# Vérifier :
# - Message d'erreur clair
# - Exit code = 3 (EXIT_ERROR_PERMISSION)
```

**Checklist de validation** :

- [ ] Cas nominal fonctionne
- [ ] JSON de sortie valide (`| jq .` ne plante pas)
- [ ] Tous les codes de sortie testés
- [ ] Tous les messages d'erreur clairs
- [ ] Logs créés dans le bon répertoire
- [ ] Cleanup fonctionne (pas de fichiers temporaires restants)