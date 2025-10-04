# 🚀 Framework de Scripts Modulaires pour Proxmox CT

## 📋 Vue d'ensemble

Ce projet implémente un **framework de développement modulaire et hiérarchique** pour la gestion des **Proxmox Container Templates (CT)**. Il suit rigoureusement la méthodologie définie dans `docs/Méthodologie de Développement Modulaire et Hiérarchique.md`.

### 🎯 Objectifs du Projet

- **Gestion automatisée** des conteneurs Proxmox CT
- **Architecture modulaire** avec scripts atomiques et orchestrateurs hiérarchiques  
- **Réutilisabilité** et **maintenabilité** du code
- **Compliance méthodologique** stricte avec validation automatique
- **Logging centralisé** et **gestion d'erreurs robuste**

## 🏗️ Architecture du Framework

### Structure Hiérarchique

```
├── atomics/                    # Niveau 0 - Scripts atomiques (actions unitaires)
├── orchestrators/
│   ├── level-1/               # Niveau 1 - Orchestrateurs simples
│   ├── level-2/               # Niveau 2 - Orchestrateurs complexes
│   └── level-N/               # Niveau N - Orchestrateurs de haut niveau
├── lib/                       # Bibliothèques partagées
│   ├── common.sh             # Utilitaires de base et constantes
│   ├── logger.sh             # Système de logging centralisé
│   ├── validator.sh          # Validations complètes
│   └── ct-common.sh          # Fonctions spécifiques Proxmox CT
├── tools/                     # Outils de développement
│   ├── dev-helper.sh         # Assistant méthodologique
│   ├── new-atomic.sh         # Générateur de scripts atomiques
│   └── new-orchestrator.sh   # Générateur d'orchestrateurs
├── templates/                 # Templates de base
│   ├── template-atomic.sh    # Template pour scripts atomiques
│   └── template-orchestrator.sh # Template pour orchestrateurs
├── tests/                     # Tests et validation
├── docs/                      # Documentation méthodologique
├── logs/                      # Journaux d'exécution
└── monitoring/               # Données de monitoring
```

### Principes Architecturaux

1. **Séparation des Responsabilités**: Chaque niveau a un rôle précis
2. **Dépendances Contrôlées**: Les niveaux supérieurs peuvent utiliser les niveaux inférieurs
3. **Atomicité**: Un script atomique = une action = un objectif
4. **Orchestration**: Les orchestrateurs coordonnent plusieurs actions
5. **Réutilisabilité**: Bibliothèques partagées pour éviter la duplication

## 🚀 Démarrage Rapide

### Prérequis

- **Proxmox VE** 7.0+ avec accès administrateur
- **Bash** 4.0+ 
- **jq** pour le traitement JSON
- **git** pour la gestion de versions

### Installation

```bash
# Cloner le projet
git clone <repository-url>
cd CT

# Rendre les outils exécutables
chmod +x tools/*.sh
chmod +x lib/*.sh

# Vérifier l'installation
./tools/dev-helper.sh --status
```

### Premier Script Atomique

```bash
# Utiliser le générateur pour créer votre premier script
./tools/new-atomic.sh my-first-script "Mon premier script atomique"

# Éditer le script généré
nano atomics/my-first-script.sh

# Tester le script
./atomics/my-first-script.sh --help
```

### Premier Orchestrateur

```bash
# Créer un orchestrateur de niveau 1
./tools/new-orchestrator.sh my-workflow 1 "Mon premier workflow"

# Éditer l'orchestrateur
nano orchestrators/level-1/my-workflow.sh

# Exécuter en mode simulation
./orchestrators/level-1/my-workflow.sh --dry-run
```

## 🛠️ Outils de Développement

### Assistant Méthodologique (`tools/dev-helper.sh`)

```bash
# Afficher l'aide méthodologique
./tools/dev-helper.sh

# Vérifier le statut du projet
./tools/dev-helper.sh --status

# Afficher les statistiques
./tools/dev-helper.sh --stats
```

### Générateur de Scripts Atomiques (`tools/new-atomic.sh`)

```bash
# Syntaxe générale
./tools/new-atomic.sh <nom-script> <description> [options]

# Exemples
./tools/new-atomic.sh create-ct "Créer un container CT"
./tools/new-atomic.sh backup-storage "Sauvegarder le stockage" --author "John Doe"
```

### Générateur d'Orchestrateurs (`tools/new-orchestrator.sh`)

```bash
# Syntaxe générale
./tools/new-orchestrator.sh <nom> <niveau> <description> [options]

# Exemples
./tools/new-orchestrator.sh setup-environment 1 "Configuration de l'environnement"
./tools/new-orchestrator.sh deploy-infrastructure 2 "Déploiement complet"
```

## 📚 Bibliothèques Disponibles

### `lib/common.sh` - Utilitaires de Base

```bash
source lib/common.sh

# Codes de sortie standardisés
exit $EXIT_SUCCESS
exit $EXIT_ERROR_USAGE

# Utilitaires système
check_command "jq"
cleanup_temp "/tmp/myfile"

# Validation IP et hostnames
is_valid_ip "192.168.1.1"
is_valid_hostname "myhost"
```

### `lib/logger.sh` - Logging Centralisé

```bash
source lib/logger.sh

# Initialiser le logging
init_logging "mon-script"

# Logs par niveau
log_debug "Message de debug"
log_info "Information générale"
log_warn "Avertissement"
log_error "Erreur critique"

# Logs spécialisés CT
ct_info "Container créé avec succès"
ct_warn "Ressources limitées"
ct_error "Échec de création"
```

### `lib/validator.sh` - Validations Complètes

```bash
source lib/validator.sh

# Validation des permissions
validate_permissions root

# Validation des dépendances
validate_dependencies "jq" "curl" "pvesm"

# Validation spécifique CT
validate_ctid 100
validate_hostname "my-ct"
validate_storage_exists "local-lvm"
```

### `lib/ct-common.sh` - Fonctions Proxmox CT

```bash
source lib/ct-common.sh

# Gestion des CT IDs
free_ctid=$(pick_free_ctid)

# Création et gestion de CT
create_basic_ct $ctid "debian-12-standard" "local-lvm"
start_and_wait_ct $ctid
bootstrap_base_inside $ctid

# Installation de services
install_docker_inside $ctid
```

## 📋 Standards de Développement

### Convention de Nommage

- **Scripts atomiques**: `action-target.sh` (ex: `create-ct.sh`, `backup-storage.sh`)
- **Orchestrateurs**: `workflow-name.sh` (ex: `setup-environment.sh`, `deploy-services.sh`)  
- **Fonctions**: `module_action_target()` (ex: `ct_create_container()`, `storage_backup_data()`)

### Structure de Script Obligatoire

Tous les scripts doivent inclure:

1. **Header** avec description et usage
2. **Fonction `show_help()`** - Aide détaillée
3. **Fonction `parse_args()`** - Parsing des arguments
4. **Fonction `validate_prerequisites()`** - Validation des prérequis
5. **Fonction `main()`** - Point d'entrée principal
6. **Gestion d'erreurs** avec trap et cleanup

### Options Standardisées

Toutes les scripts doivent supporter:

- `-h, --help` : Affichage de l'aide
- `-v, --verbose` : Mode verbeux
- `-d, --debug` : Mode debug
- `-f, --force` : Force l'opération

Les orchestrateurs ajoutent:

- `-n, --dry-run` : Simulation sans exécution

## 🧪 Tests et Validation

### Validation de Compliance

```bash
# Valider la compliance méthodologique
./docs/validate-compliance.sh

# Valider un script spécifique
./docs/validate-compliance.sh atomics/my-script.sh
```

### Tests d'Intégration

```bash
# Exécuter tous les tests
./tests/run-all-tests.sh

# Tester un module spécifique
./tests/test-ct-operations.sh
```

## 📊 Monitoring et Logs

### Structure des Logs

```
logs/
├── debug/          # Logs de debug détaillés
├── error/          # Logs d'erreurs uniquement
├── audit/          # Logs d'audit des opérations
└── *.log          # Logs principaux par script
```

### Formats de Sortie

Les scripts produisent du **JSON structuré** sur STDOUT:

```json
{
  "status": "success|error",
  "code": 0,
  "timestamp": "2024-01-01T12:00:00Z",
  "script": "script-name.sh",
  "message": "Operation completed",
  "data": { ... },
  "errors": [],
  "warnings": []
}
```

## 🔧 Configuration Avancée

### Variables d'Environnement

```bash
# Niveau de log global
export LOG_LEVEL=1  # 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR

# Configuration Proxmox
export PROXMOX_STORAGE="local-lvm"
export PROXMOX_BRIDGE="vmbr0"
export CT_TEMPLATE_DEFAULT="debian-12-standard"

# Paramètres par défaut des CT
export CT_MEMORY_MB=1024
export CT_DISK_GB=8
export CT_CORES=2
```

### Personnalisation des Templates

Les templates dans `templates/` peuvent être personnalisés:

1. **Modifier les templates existants** pour adapter aux besoins
2. **Créer de nouveaux templates** pour des cas spécifiques
3. **Utiliser les outils de génération** qui s'adaptent automatiquement

## 🤝 Contribution

### Workflow de Contribution

1. **Suivre la méthodologie**: Lire `docs/Méthodologie Précise de Développement d'un Script.md`
2. **Utiliser les outils**: Générateurs pour créer de nouveaux scripts
3. **Valider la compliance**: Exécuter `./docs/validate-compliance.sh`
4. **Tester**: Valider le bon fonctionnement
5. **Documenter**: Mettre à jour la documentation si nécessaire

### Standards de Code

- **Bash strict mode**: `set -euo pipefail`
- **Fonctions courtes**: Maximum 50 lignes par fonction
- **Comments explicatifs**: Documenter la logique complexe
- **Gestion d'erreurs**: Toujours nettoyer les ressources

## 📖 Documentation

### Documentation Complète

Voir le répertoire `docs/` pour:

- **Méthodologie de Développement Modulaire et Hiérarchique.md**: Guide complet de la méthodologie
- **Méthodologie Précise de Développement d'un Script.md**: Processus détaillé de création de scripts
- **Guide de Démarrage - Utilisation de la Méthodologie.md**: Guide de mise en œuvre
- **Catalogue de Scripts Atomiques par Catégorie.md**: Référence des scripts disponibles

### API Reference

Documentation complète des fonctions disponibles dans chaque bibliothèque avec exemples d'usage.

## 📄 Licence

[Définir la licence du projet]

## 🚨 Support

Pour questions et support:

1. **Consulter la documentation** dans `docs/`
2. **Utiliser l'assistant**: `./tools/dev-helper.sh`
3. **Créer une issue** sur le repository Git
4. **Suivre les guidelines** de contribution

---

**Version**: 1.0.0  
**Dernière mise à jour**: $(date +%Y-%m-%d)  
**Compatibilité**: Proxmox VE 7.0+, Bash 4.0+