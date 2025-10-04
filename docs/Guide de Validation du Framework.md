# 🔍 Guide de Validation du Framework CT

## Vue d'ensemble

Ce document décrit comment valider que le framework de scripts modulaires pour Proxmox CT fonctionne correctement dans votre environnement.

## 🚀 Tests de Validation Rapide

### 1. Validation des Outils de Développement

```bash
# Vérifier l'assistant méthodologique
./tools/dev-helper.sh --status

# Tester la génération d'un script atomique
./tools/new-atomic.sh test-validation "Script de test" --dry-run

# Tester la génération d'un orchestrateur
./tools/new-orchestrator.sh test-workflow 1 "Workflow de test" --dry-run
```

### 2. Test des Bibliothèques

```bash
# Test direct des fonctions (exemple)
source lib/common.sh
source lib/logger.sh
source lib/validator.sh

# Test des utilitaires
is_command_available "jq" && echo "✓ jq disponible"
is_valid_ip "192.168.1.1" && echo "✓ Validation IP OK"
is_valid_hostname "test-ct" && echo "✓ Validation hostname OK"
```

### 3. Test du Script Atomique de Validation

```bash
# Exécuter le script de test CT
./atomics/test-ct-info.sh --help
./atomics/test-ct-info.sh --verbose
./atomics/test-ct-info.sh --debug 100
```

### 4. Test de l'Orchestrateur de Validation

```bash
# Exécuter l'orchestrateur de test complet
./orchestrators/level-1/test-framework-validation.sh --help
./orchestrators/level-1/test-framework-validation.sh --dry-run
./orchestrators/level-1/test-framework-validation.sh --verbose
```

## 🧪 Suite de Tests Complète

### Prérequis pour les Tests

```bash
# Vérifier les dépendances
command -v jq >/dev/null || echo "❌ jq manquant"
command -v bash >/dev/null || echo "❌ bash manquant"

# Vérifier les permissions (sur Linux/Proxmox)
[[ $EUID -eq 0 ]] && echo "✓ Exécution en root" || echo "⚠️  Tests limités sans root"
```

### Tests par Niveau

#### Niveau 0 - Bibliothèques (`lib/`)

```bash
# Test de lib/common.sh
source lib/common.sh
echo "EXIT_SUCCESS = $EXIT_SUCCESS"
is_command_available "ls" && echo "✓ is_command_available"

# Test de lib/logger.sh  
source lib/logger.sh
init_logging "test"
log_info "Test de logging"
ct_info "Test logging CT"

# Test de lib/validator.sh
source lib/validator.sh
validate_dependencies "jq" && echo "✓ validate_dependencies"

# Test de lib/ct-common.sh
source lib/ct-common.sh
echo "CT functions loaded: $(declare -F | grep -c 'ct_')"
```

#### Niveau 1 - Scripts Atomiques (`atomics/`)

```bash
# Test du script atomique créé
./atomics/test-ct-info.sh --help
./atomics/test-ct-info.sh --verbose

# Vérifier la sortie JSON
./atomics/test-ct-info.sh 2>/dev/null | jq .
```

#### Niveau 2 - Orchestrateurs (`orchestrators/level-1/`)

```bash
# Test de l'orchestrateur de validation
./orchestrators/level-1/test-framework-validation.sh --dry-run
./orchestrators/level-1/test-framework-validation.sh --verbose
```

## 📊 Validation des Sorties

### Format JSON Attendu

Tous les scripts doivent produire du JSON structuré :

```json
{
  "status": "success|error",
  "code": 0,
  "timestamp": "2024-01-01T12:00:00Z",
  "script": "nom-script.sh",
  "message": "Description",
  "data": { /* données spécifiques */ },
  "errors": [],
  "warnings": []
}
```

### Validation JSON

```bash
# Tester la validité JSON des sorties
./atomics/test-ct-info.sh 2>/dev/null | jq . >/dev/null && echo "✓ JSON valide"
./orchestrators/level-1/test-framework-validation.sh --dry-run 2>/dev/null | jq . >/dev/null && echo "✓ JSON valide"
```

## 🏥 Diagnostic des Problèmes

### Problèmes Courants

#### 1. Erreur de dépendances

```bash
# Symptôme: "command not found: jq"
# Solution:
sudo apt-get update && sudo apt-get install jq

# Ou sur d'autres distributions:
dnf install jq     # Fedora/RHEL
zypper install jq  # SUSE
```

#### 2. Erreurs de permissions

```bash
# Symptôme: "Permission denied"
# Solution:
chmod +x tools/*.sh lib/*.sh atomics/*.sh orchestrators/*/*.sh
```

#### 3. Variables non définies

```bash
# Symptôme: "unbound variable"
# Vérifier que set -euo pipefail est en place
head -5 atomics/test-ct-info.sh | grep "set -euo pipefail"
```

#### 4. Imports manqués

```bash
# Vérifier que tous les source pointent correctement
grep -n "source.*lib" atomics/test-ct-info.sh
```

### Commandes de Diagnostic

```bash
# Vérifier la structure du projet
find . -name "*.sh" -type f | sort

# Vérifier les permissions
find . -name "*.sh" -not -executable

# Vérifier la syntaxe bash
bash -n atomics/test-ct-info.sh && echo "✓ Syntaxe OK"

# Vérifier les imports
grep -r "source.*lib" . | grep -v ".git"
```

## 📈 Tests de Performance

### Mesure des Temps d'Exécution

```bash
# Test de performance simple
time ./atomics/test-ct-info.sh >/dev/null 2>&1

# Test de l'orchestrateur
time ./orchestrators/level-1/test-framework-validation.sh --dry-run >/dev/null 2>&1
```

### Métriques Attendues

- **Script atomique**: < 2 secondes
- **Orchestrateur niveau 1**: < 5 secondes  
- **Chargement des bibliothèques**: < 0.5 secondes

## 🔧 Configuration des Tests Automatisés

### Script de Validation Globale

```bash
#!/bin/bash
# validate-framework.sh
set -euo pipefail

echo "🧪 Validation du framework CT..."

# 1. Test des outils
echo "1. Test des outils de développement"
./tools/dev-helper.sh --status >/dev/null && echo "✓ dev-helper OK"

# 2. Test des bibliothèques
echo "2. Test des bibliothèques"
source lib/common.sh && echo "✓ common.sh"
source lib/logger.sh && echo "✓ logger.sh"  
source lib/validator.sh && echo "✓ validator.sh"
source lib/ct-common.sh && echo "✓ ct-common.sh"

# 3. Test des scripts
echo "3. Test des scripts"
./atomics/test-ct-info.sh --help >/dev/null && echo "✓ test-ct-info.sh"

# 4. Test de l'orchestrateur
echo "4. Test de l'orchestrateur"
./orchestrators/level-1/test-framework-validation.sh --dry-run >/dev/null && echo "✓ test-framework-validation.sh"

echo "🎉 Validation terminée avec succès!"
```

### Intégration CI/CD (exemple)

```yaml
# .github/workflows/validate.yml
name: Validate Framework
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Install dependencies
      run: sudo apt-get update && sudo apt-get install -y jq
    - name: Validate framework
      run: |
        chmod +x validate-framework.sh
        ./validate-framework.sh
```

## 📋 Checklist de Validation

### ✅ Avant Déploiement

- [ ] Tous les scripts ont les permissions d'exécution
- [ ] Les dépendances système sont installées (`jq`, `bash 4.0+`)
- [ ] La syntaxe de tous les scripts est valide
- [ ] Les imports de bibliothèques fonctionnent
- [ ] Les scripts produisent du JSON valide
- [ ] Les codes de sortie sont cohérents
- [ ] Les messages de log sont appropriés
- [ ] La documentation est à jour

### ✅ Tests Fonctionnels

- [ ] Script atomique s'exécute sans erreur
- [ ] Orchestrateur s'exécute en mode `--dry-run`
- [ ] Gestion d'erreur fonctionne (test avec paramètres invalides)
- [ ] Mode verbose/debug produit plus de logs
- [ ] Aide (`--help`) s'affiche correctement
- [ ] JSON de sortie est bien formé

### ✅ Tests d'Intégration

- [ ] Framework fonctionne sur Proxmox VE cible
- [ ] Permissions root disponibles si nécessaire
- [ ] Accès aux commandes Proxmox (`pct`, `pvesm`)
- [ ] Réseau et stockage Proxmox configurés
- [ ] Templates CT disponibles

## 🚀 Prochaines Étapes

Après validation réussie:

1. **Créer vos premiers scripts métier** avec les générateurs
2. **Adapter les templates** aux besoins spécifiques
3. **Développer des orchestrateurs** pour vos workflows
4. **Configurer le monitoring** et les logs
5. **Déployer en production** Proxmox

---

**Validation Framework CT - v1.0.0**  
*Mise à jour: $(date +%Y-%m-%d)*