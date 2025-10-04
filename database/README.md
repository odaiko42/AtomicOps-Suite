# 🗄️ Base de Données SQLite - Catalogue de Scripts

## 🎯 Vue d'Ensemble

Cette base de données SQLite catalogue et organise tous les scripts du framework modulaire CT. Elle permet la **recherche**, **documentation** et **gestion des dépendances** de l'ensemble du projet.

## 🚀 Démarrage Rapide

### 1. Initialisation
```bash
# Créer la base de données
./database/init-db.sh

# Enregistrer tous les scripts existants  
./tools/register-all-scripts.sh
```

### 2. Utilisation Courante
```bash
# Rechercher des scripts
./tools/search-db.sh --all                    # Tous les scripts
./tools/search-db.sh --category storage       # Par catégorie
./tools/search-db.sh --name "backup-*"        # Par pattern

# Voir les détails
./tools/search-db.sh --info create-ct.sh      # Informations complètes
./tools/search-db.sh --dependencies setup.sh # Graphe dépendances
./tools/search-db.sh --stats                  # Statistiques globales
```

### 3. Enregistrement de Nouveaux Scripts
```bash
# Enregistrement unitaire
./tools/register-script.sh atomics/new-feature.sh

# Enregistrement automatique (mode batch)
./tools/register-script.sh lib/utils.sh --auto
```

## 📁 Structure des Fichiers

```
database/
├── README.md                     # Ce fichier
├── init-db.sh                    # Initialisation de la base
├── scripts_catalogue.db          # Base SQLite (généré)
└── migrations/                   # Migrations futures (à créer)

tools/
├── register-script.sh            # Enregistrement unitaire
├── register-all-scripts.sh       # Enregistrement en masse
├── search-db.sh                  # Recherche et consultation
└── export-db.sh                  # Exports multi-formats

exports/                          # Exports générés (créé automatiquement)
```

## 🏗️ Architecture de la Base

### Tables Principales
- **`scripts`** - Catalogue principal des scripts
- **`script_parameters`** - Paramètres d'entrée documentés
- **`script_outputs`** - Sorties JSON structurées
- **`script_dependencies`** - Dépendances multi-types
- **`exit_codes`** - Codes de sortie standardisés
- **`functions`** - Catalogue des fonctions des bibliothèques

### Vues Optimisées
- **`v_scripts_with_dep_count`** - Scripts avec comptage dépendances
- **`v_dependency_graph`** - Graphe des relations entre scripts

## 📊 Exemples de Recherches

### Recherches Simples
```bash
# Par type de script
./tools/search-db.sh --type atomic
./tools/search-db.sh --type orchestrator-1

# Par catégorie métier
./tools/search-db.sh --category ct
./tools/search-db.sh --category storage
./tools/search-db.sh --category network

# Recherche textuelle
./tools/search-db.sh --description "backup"
./tools/search-db.sh --name "*docker*"
```

### Analyses Avancées (SQL direct)
```sql
-- Connecter à la base
sqlite3 database/scripts_catalogue.db

-- Scripts les plus complexes (plus de dépendances)
SELECT name, type, dependency_count 
FROM v_scripts_with_dep_count 
WHERE dependency_count > 0 
ORDER BY dependency_count DESC 
LIMIT 10;

-- Fonctions les plus utilisées
SELECT f.name, f.library_file, COUNT(suf.script_id) as usage_count
FROM functions f
LEFT JOIN script_uses_functions suf ON f.id = suf.function_id
GROUP BY f.id
HAVING usage_count > 0
ORDER BY usage_count DESC;

-- Scripts sans documentation complète
SELECT name, type,
  CASE 
    WHEN (SELECT COUNT(*) FROM script_parameters WHERE script_id = scripts.id) = 0 THEN 'Manque params'
    WHEN (SELECT COUNT(*) FROM exit_codes WHERE script_id = scripts.id) = 0 THEN 'Manque codes sortie'
    ELSE 'OK'
  END as statut_doc
FROM scripts
WHERE statut_doc != 'OK';
```

## 🔧 Maintenance et Administration

### Mise à Jour des Statistiques
```bash
# Mise à jour manuelle
./tools/update-stats.sh

# Configuration automatique (cron)
0 23 * * * /path/to/project/tools/update-stats.sh >> /var/log/catalogue-stats.log
```

### Exports et Sauvegardes
```bash
# Export complet (tous formats)
./tools/export-db.sh all

# Backup quotidien
./tools/export-db.sh backup

# Export spécifique
./tools/export-db.sh json --output-dir /custom/path
```

### Validation et Contrôle Qualité
```sql
-- Vérifier l'intégrité
PRAGMA integrity_check;

-- Scripts orphelins (sans dépendants)
SELECT s.name, s.type
FROM scripts s
LEFT JOIN script_dependencies sd ON s.id = sd.depends_on_script_id
WHERE sd.id IS NULL AND s.type = 'atomic';

-- Dépendances manquantes
SELECT sd.script_id, 
       (SELECT name FROM scripts WHERE id = sd.script_id) as script,
       sd.depends_on_command
FROM script_dependencies sd
WHERE sd.dependency_type = 'command'
  AND sd.depends_on_command NOT IN (
    SELECT DISTINCT depends_on_command 
    FROM script_dependencies 
    WHERE dependency_type = 'command'
  );
```

## ⚡ Performance et Optimisation

### Index Automatiques
La base inclut des index optimisés pour :
- Recherches par type (`idx_scripts_type`)
- Recherches par catégorie (`idx_scripts_category`) 
- Filtres par statut (`idx_scripts_status`)
- Jointures dépendances (`idx_script_dependencies_script_id`)
- Statistiques temporelles (`idx_usage_stats_date`)

### Requêtes Optimisées
```sql
-- Utiliser les vues pour de meilleures performances
SELECT * FROM v_scripts_with_dep_count WHERE dependency_count > 2;

-- Plutôt que les jointures manuelles complexes
SELECT s.*, COUNT(sd.id) as dep_count
FROM scripts s
LEFT JOIN script_dependencies sd ON s.id = sd.script_id
GROUP BY s.id
HAVING dep_count > 2;
```

## 🔄 Intégration avec le Framework

### Auto-Enregistrement des Nouveaux Scripts
```bash
# Activer l'enregistrement automatique
export AUTO_REGISTER_DB=1

# Les nouveaux scripts générés seront auto-enregistrés
./tools/new-atomic.sh feature "Nouvelle fonctionnalité"
./tools/new-orchestrator.sh workflow 1 "Nouveau workflow"
```

### Hook Git (Recommandé)
```bash
# Configurer l'auto-enregistrement sur commit
cat > .git/hooks/post-commit << 'EOF'
#!/bin/bash
ADDED_SCRIPTS=$(git diff-tree --no-commit-id --name-only -r HEAD | grep '\.sh$')
for script in $ADDED_SCRIPTS; do
    ./tools/register-script.sh "$script" --auto >/dev/null 2>&1 || true
done
EOF

chmod +x .git/hooks/post-commit
```

## 🎯 Cas d'Usage Courants

### Développement Quotidien
1. **Trouver un script existant** : `./tools/search-db.sh --description "backup"`
2. **Voir ses dépendances** : `./tools/search-db.sh --dependencies backup-ct.sh`
3. **Comprendre ses paramètres** : `./tools/search-db.sh --info backup-ct.sh`

### Gestion de Projet
1. **Vue d'ensemble** : `./tools/search-db.sh --stats`
2. **Scripts par catégorie** : `./tools/search-db.sh --category storage`
3. **Orchestrateurs complexes** : `./tools/search-db.sh --type orchestrator-2`

### Maintenance et Qualité
1. **Export documentation** : `./tools/export-db.sh markdown`
2. **Backup régulier** : `./tools/export-db.sh backup`
3. **Analyse dépendances** : Requêtes SQL custom

## 🆘 Dépannage

### Problèmes Courants

#### Base de données corrompue
```bash
# Vérifier l'intégrité
sqlite3 database/scripts_catalogue.db "PRAGMA integrity_check;"

# Recréer si nécessaire
./database/init-db.sh --force
./tools/register-all-scripts.sh
```

#### Enregistrement échoue
```bash
# Vérifier les permissions
ls -la database/scripts_catalogue.db

# Tester en mode debug
./tools/register-script.sh path/to/script.sh --auto 2>&1 | grep ERROR
```

#### Performances lentes
```bash
# Analyser la base
sqlite3 database/scripts_catalogue.db "ANALYZE;"

# Vérifier la taille
du -h database/scripts_catalogue.db

# Vacuum si nécessaire
sqlite3 database/scripts_catalogue.db "VACUUM;"
```

### Logs et Diagnostics
```bash
# Logs des outils de catalogue
grep -E "(register-|search-|export-)" logs/debug/*.log

# Test de connectivité à la base
sqlite3 database/scripts_catalogue.db "SELECT COUNT(*) FROM scripts;"
```

## 📚 Ressources

### Documentation Complète
- **[Base de Données SQLite pour Catalogue de Scripts.md](../docs/Base%20de%20Données%20SQLite%20pour%20Catalogue%20de%20Scripts.md)** - Documentation détaillée
- **[README principal](../README.md)** - Vue d'ensemble du framework
- **[Méthodologie de Développement](../docs/Méthodologie%20de%20Développement%20Modulaire%20et%20Hiérarchique.md)** - Standards de développement

### Liens Utiles
- **SQLite Documentation** : https://sqlite.org/docs.html
- **SQL Tutorial** : https://www.w3schools.com/sql/
- **JSON in SQLite** : https://sqlite.org/json1.html

---

**Système de Catalogue SQLite - v1.0.0**  
**Framework CT** - Gestion modulaire des scripts Proxmox  
**Dernière mise à jour** : $(date +%Y-%m-%d)