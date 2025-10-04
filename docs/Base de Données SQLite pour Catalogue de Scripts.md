# Base de Données SQLite pour Catalogue de Scripts

## 📋 Vue d'ensemble

Ce document décrit l'implémentation d'une base de données SQLite pour cataloguer et gérer tous les scripts du framework modulaire CT. Cette base permet de :

- **Cataloguer** tous les scripts atomiques et orchestrateurs
- **Tracer les dépendances** entre scripts et bibliothèques
- **Documenter** les paramètres, sorties et exemples
- **Monitorer** l'utilisation et les performances
- **Rechercher** et filtrer les scripts par critères multiples

## 🏗️ Architecture de la Base de Données

### Tables Principales

#### 1. Table `scripts` - Catalogue principal

```sql
CREATE TABLE IF NOT EXISTS scripts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,                    -- Nom du fichier (ex: create-ct.sh)
    type TEXT NOT NULL,                           -- atomic, orchestrator-1, orchestrator-2, etc.
    category TEXT NOT NULL,                       -- storage, network, ct, backup, etc.
    description TEXT NOT NULL,                    -- Description courte
    long_description TEXT,                        -- Description détaillée
    version TEXT DEFAULT '1.0.0',               -- Version sémantique
    author TEXT,                                 -- Auteur du script
    path TEXT NOT NULL,                          -- Chemin relatif dans le projet
    status TEXT DEFAULT 'active',                -- active, deprecated, experimental
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_tested DATETIME,                        -- Dernière validation
    documentation_path TEXT,                     -- Chemin vers doc détaillée
    complexity_score INTEGER DEFAULT 0,          -- Score de complexité (1-10)
    
    CHECK (type IN ('atomic', 'orchestrator-1', 'orchestrator-2', 'orchestrator-3', 'orchestrator-4', 'orchestrator-5')),
    CHECK (status IN ('active', 'deprecated', 'experimental', 'disabled'))
);
```

#### 2. Table `script_parameters` - Paramètres d'entrée

```sql  
CREATE TABLE IF NOT EXISTS script_parameters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    param_name TEXT NOT NULL,                    -- Nom du paramètre (ex: CTID, --verbose)
    param_type TEXT NOT NULL,                    -- string, integer, boolean, file_path, etc.
    is_required BOOLEAN DEFAULT 0,              -- Paramètre obligatoire
    default_value TEXT,                          -- Valeur par défaut
    position INTEGER,                            -- Position pour paramètres positionnels
    description TEXT,                            -- Description du paramètre
    validation_regex TEXT,                       -- Regex de validation
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, param_name)
);
```

#### 3. Table `script_outputs` - Sorties JSON structurées

```sql
CREATE TABLE IF NOT EXISTS script_outputs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    output_field TEXT NOT NULL,                  -- Champ JSON (ex: status, data.ctid)
    field_type TEXT NOT NULL,                    -- string, integer, object, array
    description TEXT,                            -- Description du champ
    parent_field TEXT,                           -- Pour les objets imbriqués
    is_always_present BOOLEAN DEFAULT 1,        -- Toujours présent dans la sortie
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);
```

#### 4. Table `script_dependencies` - Dépendances multiples

```sql
CREATE TABLE IF NOT EXISTS script_dependencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    dependency_type TEXT NOT NULL,               -- script, command, library, package
    depends_on_script_id INTEGER,                -- Si dépendance vers script
    depends_on_command TEXT,                     -- Si dépendance système (jq, curl)
    depends_on_library TEXT,                     -- Si dépendance vers lib/*.sh
    depends_on_package TEXT,                     -- Si dépendance package système
    is_optional BOOLEAN DEFAULT 0,              -- Dépendance optionnelle
    minimum_version TEXT,                        -- Version minimum requise
    description TEXT,                            -- Pourquoi cette dépendance
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    FOREIGN KEY (depends_on_script_id) REFERENCES scripts(id) ON DELETE RESTRICT,
    
    CHECK (dependency_type IN ('script', 'command', 'library', 'package')),
    CHECK (
        (dependency_type = 'script' AND depends_on_script_id IS NOT NULL) OR
        (dependency_type = 'command' AND depends_on_command IS NOT NULL) OR  
        (dependency_type = 'library' AND depends_on_library IS NOT NULL) OR
        (dependency_type = 'package' AND depends_on_package IS NOT NULL)
    )
);
```

#### 5. Table `exit_codes` - Codes de sortie documentés

```sql
CREATE TABLE IF NOT EXISTS exit_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    exit_code INTEGER NOT NULL,
    code_name TEXT,                              -- EXIT_SUCCESS, EXIT_ERROR_USAGE, etc.
    description TEXT NOT NULL,                   -- Description de la condition
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, exit_code)
);
```

#### 6. Table `script_tags` - Tags pour classification

```sql
CREATE TABLE IF NOT EXISTS script_tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    tag TEXT NOT NULL,                           -- backup, security, network, etc.
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, tag)
);
```

#### 7. Table `use_cases` - Cas d'usage documentés

```sql
CREATE TABLE IF NOT EXISTS use_cases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    use_case_title TEXT NOT NULL,                -- "Sauvegarde quotidienne"
    use_case_description TEXT NOT NULL,          -- Description détaillée
    example_command TEXT NOT NULL,               -- Exemple de commande
    expected_output TEXT,                        -- Sortie attendue
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);
```

#### 8. Table `version_history` - Historique des versions

```sql
CREATE TABLE IF NOT EXISTS version_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    version TEXT NOT NULL,
    release_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    changes_description TEXT NOT NULL,           -- Description des changements
    breaking_changes BOOLEAN DEFAULT 0,         -- Changements cassants
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);
```

#### 9. Table `usage_stats` - Statistiques d'utilisation

```sql
CREATE TABLE IF NOT EXISTS usage_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    execution_date DATE NOT NULL,
    execution_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    average_duration_ms INTEGER,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, execution_date)
);
```

#### 10. Table `script_examples` - Exemples d'utilisation

```sql
CREATE TABLE IF NOT EXISTS script_examples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    example_title TEXT NOT NULL,
    example_description TEXT,
    example_command TEXT NOT NULL,
    expected_result TEXT,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);
```

### Tables pour les Fonctions (Bibliothèques)

#### 11. Table `functions` - Catalogue des fonctions

```sql
CREATE TABLE IF NOT EXISTS functions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,                          -- Nom de la fonction (ex: ct_create_container)
    library_file TEXT NOT NULL,                  -- Fichier source (ex: lib/ct-common.sh)
    category TEXT NOT NULL,                      -- ct, storage, network, validation, etc.
    description TEXT NOT NULL,                   -- Description de la fonction
    parameters TEXT,                             -- Description des paramètres
    return_value TEXT,                           -- Description de la valeur retournée
    example_usage TEXT,                          -- Exemple d'utilisation
    status TEXT DEFAULT 'active',               -- active, deprecated
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(name, library_file),
    CHECK (status IN ('active', 'deprecated'))
);
```

#### 12. Table `script_uses_functions` - Utilisation des fonctions

```sql
CREATE TABLE IF NOT EXISTS script_uses_functions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    function_id INTEGER NOT NULL,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    FOREIGN KEY (function_id) REFERENCES functions(id) ON DELETE CASCADE,
    UNIQUE(script_id, function_id)
);
```

### Vues Utiles

#### Vue `v_scripts_with_dep_count` - Scripts avec nombre de dépendances

```sql
CREATE VIEW IF NOT EXISTS v_scripts_with_dep_count AS
SELECT 
    s.*,
    COALESCE(dep_count.count, 0) as dependency_count
FROM scripts s
LEFT JOIN (
    SELECT script_id, COUNT(*) as count
    FROM script_dependencies
    GROUP BY script_id
) dep_count ON s.id = dep_count.script_id;
```

#### Vue `v_dependency_graph` - Graphe de dépendances simplifié

```sql
CREATE VIEW IF NOT EXISTS v_dependency_graph AS
SELECT 
    s1.name as script_name,
    s1.type as script_type,
    COALESCE(s2.name, sd.depends_on_command, sd.depends_on_library, sd.depends_on_package) as depends_on,
    sd.dependency_type,
    sd.is_optional
FROM scripts s1
JOIN script_dependencies sd ON s1.id = sd.script_id
LEFT JOIN scripts s2 ON sd.depends_on_script_id = s2.id;
```

## Parsing des arguments
case ${1:-} in
## 🚀 Implémentation

Le système de catalogue SQLite a été **entièrement implémenté** avec les composants suivants :

### 📁 Structure des Fichiers

```
database/
├── init-db.sh                    # Initialisation de la base
├── scripts_catalogue.db          # Base SQLite (créée par init-db.sh)
└── migrate-db.sh                 # Migrations de schéma (futur)

tools/
├── register-script.sh            # Enregistrement d'un script
├── register-all-scripts.sh       # Enregistrement automatique
├── search-db.sh                  # Recherche et consultation
├── export-db.sh                  # Export multi-formats
└── update-stats.sh               # Mise à jour statistiques
```

### 🔧 Outils Principaux

#### 1. `database/init-db.sh` - Initialisation
```bash
# Initialiser la base de données
./database/init-db.sh

# Forcer la recréation
./database/init-db.sh --force
```

**Fonctionnalités :**
- Création du schéma complet (12 tables + 2 vues)
- Insertion des données initiales (scripts et fonctions système)
- Validation de l'intégrité
- Configuration des index pour les performances

#### 2. `tools/register-script.sh` - Enregistrement unitaire
```bash
# Enregistrement interactif
./tools/register-script.sh atomics/create-ct.sh

# Enregistrement automatique
./tools/register-script.sh lib/common.sh --auto
```

**Fonctionnalités :**
- Extraction automatique des métadonnées depuis les headers
- Analyse des dépendances (bibliothèques, commandes système)
- Extraction des paramètres et codes de sortie
- Mode interactif ou automatique

#### 3. `tools/register-all-scripts.sh` - Enregistrement en masse
```bash
# Enregistrer tous les nouveaux scripts
./tools/register-all-scripts.sh

# Forcer la mise à jour de tous les scripts
./tools/register-all-scripts.sh --force
```

**Fonctionnalités :**
- Balayage automatique de tous les répertoires
- Traitement en lot avec gestion d'erreurs
- Détection automatique des nouvelles fonctions
- Rapport de synthèse complet

#### 4. `tools/search-db.sh` - Recherche et consultation
```bash
# Recherches
./tools/search-db.sh --all                    # Tous les scripts
./tools/search-db.sh --name "create-*"        # Par pattern
./tools/search-db.sh --category storage       # Par catégorie
./tools/search-db.sh --type atomic            # Par type

# Informations détaillées
./tools/search-db.sh --info create-ct.sh      # Détails complets
./tools/search-db.sh --dependencies setup.sh # Graphe dépendances
./tools/search-db.sh --stats                  # Statistiques
```

**Fonctionnalités :**
- Recherche multi-critères avec wildcards
- Affichage détaillé des métadonnées
- Graphe de dépendances visuelles
- Statistiques avancées du catalogue

### 📊 Exemples d'Utilisation

#### Initialisation rapide
```bash
# 1. Créer la base
./database/init-db.sh

# 2. Enregistrer tous les scripts existants
./tools/register-all-scripts.sh

# 3. Voir le résultat
./tools/search-db.sh --stats
```

#### Workflow quotidien
```bash
# Rechercher un script pour une tâche
./tools/search-db.sh --description "backup"
./tools/search-db.sh --tag "storage"

# Voir les détails avant utilisation
./tools/search-db.sh --info backup-ct.sh
./tools/search-db.sh --dependencies backup-ct.sh

# Enregistrer un nouveau script
./tools/register-script.sh atomics/new-feature.sh
```

#### Recherches avancées
```bash
# Scripts par type
./tools/search-db.sh --type orchestrator-1
./tools/search-db.sh --type atomic

# Par catégorie métier  
./tools/search-db.sh --category ct
./tools/search-db.sh --category storage

# Recherche textuelle
./tools/search-db.sh --description "container"
./tools/search-db.sh --name "*backup*"
```

### 🔍 Requêtes SQL Directes

#### Requêtes courantes
```sql
-- Scripts avec le plus de dépendances
SELECT name, dependency_count 
FROM v_scripts_with_dep_count 
WHERE dependency_count > 0 
ORDER BY dependency_count DESC;

-- Graphe complet des dépendances
SELECT script_name, depends_on, dependency_type 
FROM v_dependency_graph 
ORDER BY script_name;

-- Scripts par catégorie
SELECT category, COUNT(*) as count 
FROM scripts 
GROUP BY category 
ORDER BY count DESC;

-- Fonctions les plus utilisées
SELECT f.name, f.library_file, COUNT(suf.script_id) as usage_count
FROM functions f
LEFT JOIN script_uses_functions suf ON f.id = suf.function_id
GROUP BY f.id
ORDER BY usage_count DESC;
```

#### Analyses avancées
```sql
-- Scripts orphelins (sans dépendants)
SELECT s.name, s.type
FROM scripts s
LEFT JOIN script_dependencies sd ON s.id = sd.depends_on_script_id
WHERE sd.id IS NULL AND s.type = 'atomic';

-- Orchestrateurs complexes
SELECT name, type, dependency_count
FROM v_scripts_with_dep_count
WHERE type LIKE 'orchestrator%' AND dependency_count >= 5
ORDER BY dependency_count DESC;

-- Scripts récents
SELECT name, type, created_at
FROM scripts
WHERE created_at >= date('now', '-7 days')
ORDER BY created_at DESC;
```

### 📈 Monitoring et Maintenance

#### Statistiques automatiques
```bash
# Mise à jour quotidienne des stats d'usage
./tools/update-stats.sh

# Configuration cron
0 23 * * * /path/to/project/tools/update-stats.sh >> /var/log/catalogue-stats.log
```

#### Exports réguliers  
```bash
# Export complet multi-formats
./tools/export-db.sh all

# Export spécifique
./tools/export-db.sh json
./tools/export-db.sh csv
./tools/export-db.sh markdown

# Backup quotidien
./tools/export-db.sh backup
```

### 🎯 Intégration avec le Framework

#### Auto-enregistrement
Les nouveaux scripts générés par `new-atomic.sh` et `new-orchestrator.sh` peuvent être automatiquement enregistrés :

```bash
# Activer l'auto-enregistrement
export AUTO_REGISTER_DB=1

# Générer et auto-enregistrer
./tools/new-atomic.sh my-script "Description"
```

#### Hook Git
Configuration pour enregistrement automatique lors des commits :

```bash
# .git/hooks/post-commit
#!/bin/bash
ADDED_SCRIPTS=$(git diff-tree --no-commit-id --name-only -r HEAD | grep '\.sh$')
for script in $ADDED_SCRIPTS; do
    ./tools/register-script.sh "$script" --auto >/dev/null 2>&1 || true
done
```

### ✅ État d'Implémentation

**✅ COMPLET - Système opérationnel** avec :

- ✅ **Base de données SQLite** complète (12 tables, 2 vues, index)
- ✅ **Script d'initialisation** automatisé et robuste  
- ✅ **Enregistrement unitaire** avec extraction métadonnées
- ✅ **Enregistrement en masse** pour tout le projet
- ✅ **Recherche multi-critères** puissante et intuitive
- ✅ **Consultation détaillée** des scripts et dépendances
- ✅ **Extraction automatique** des paramètres et codes sortie
- ✅ **Analyse des dépendances** complète (libs, commandes, scripts)
- ✅ **Statistiques avancées** du catalogue
- ✅ **Vues SQL optimisées** pour les requêtes courantes

**Prêt pour utilisation en production ! 🚀**

## 📚 Exemples d'Usage Avancés

### Recherches Complexes

#### Trouver tous les orchestrateurs niveau 2+ utilisant des atomiques de stockage
```sql
SELECT DISTINCT o.name as orchestrateur, o.type
FROM scripts o
JOIN script_dependencies sd ON o.id = sd.script_id  
JOIN scripts a ON sd.depends_on_script_id = a.id
WHERE o.type LIKE 'orchestrator-%' 
  AND CAST(substr(o.type, 14) AS INTEGER) >= 2
  AND a.category = 'storage'
ORDER BY o.type, o.name;
```

#### Scripts avec paramètres obligatoires multiples
```sql
SELECT s.name, COUNT(sp.id) as required_params
FROM scripts s
JOIN script_parameters sp ON s.id = sp.script_id
WHERE sp.is_required = 1
GROUP BY s.id
HAVING required_params >= 3
ORDER BY required_params DESC;
```

### Validation et Qualité

#### Scripts sans documentation complète
```sql
SELECT name, type,
    CASE 
        WHEN documentation_path IS NULL THEN 'Pas de doc'
        WHEN (SELECT COUNT(*) FROM script_parameters WHERE script_id = scripts.id) = 0 THEN 'Pas de params'
        WHEN (SELECT COUNT(*) FROM exit_codes WHERE script_id = scripts.id) = 0 THEN 'Pas de codes sortie'
        ELSE 'OK'
    END as manque
FROM scripts
WHERE manque != 'OK'
ORDER BY type, name;
```

#### Dépendances circulaires (détection)
```sql
WITH RECURSIVE dep_path(script_id, path) AS (
    SELECT id, name FROM scripts
    UNION ALL
    SELECT sd.depends_on_script_id, dp.path || ' -> ' || s.name
    FROM script_dependencies sd
    JOIN dep_path dp ON sd.script_id = dp.script_id
    JOIN scripts s ON sd.depends_on_script_id = s.id
    WHERE sd.dependency_type = 'script'
      AND instr(dp.path, s.name) > 0  -- Cycle détecté
)
SELECT path FROM dep_path WHERE path LIKE '%->%->%';
```

Le système de catalogue SQLite est **pleinement fonctionnel** et prêt pour gérer efficacement tous vos scripts ! 🎉
```

**Rendre le script exécutable** :

```bash
chmod +x tools/search-db.sh
```

---

## 4.3 Script pour lister les fonctions

**Créer le fichier `tools/list-functions.sh`** :

```bash
#!/bin/bash
#
# Script: list-functions.sh
# Description: Liste toutes les fonctions des bibliothèques
# Usage: ./list-functions.sh [library]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"

LIBRARY=${1:-}

if [[ -z "$LIBRARY" ]]; then
    # Lister toutes les fonctions groupées par bibliothèque
    echo "📚 Toutes les fonctions disponibles"
    echo "==========================================="
    
    sqlite3 "$DB_FILE" <<EOF
SELECT library_file FROM functions GROUP BY library_file ORDER BY library_file;
EOF | while read -r lib; do
        echo ""
        echo "Bibliothèque: $lib"
        echo "---"
        sqlite3 -column "$DB_FILE" <<EOSQL
SELECT 
    name,
    substr(description, 1, 50) || '...' as description
FROM functions
WHERE library_file = '$lib'
ORDER BY name;
EOSQL
    done
else
    # Lister les fonctions d'une bibliothèque spécifique
    echo "📚 Fonctions de: $LIBRARY"
    echo "==========================================="
    
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    name,
    description,
    parameters,
    return_value
FROM functions
WHERE library_file = '$LIBRARY'
ORDER BY name;
EOF
fi
```

---

## 4.4 Script pour voir l'utilisation d'une fonction

**Créer le fichier `tools/function-usage.sh`** :

```bash
#!/bin/bash
#
# Script: function-usage.sh
# Description: Montre quels scripts utilisent une fonction donnée
# Usage: ./function-usage.sh <function_name>
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <function_name>"
    echo "Exemple: $0 cache_get"
    exit 1
fi

FUNCTION_NAME=$1

echo "🔍 Scripts utilisant la fonction: $FUNCTION_NAME"
echo "==========================================="

# Vérifier que la fonction existe
FUNC_EXISTS=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM functions WHERE name = '$FUNCTION_NAME';")

if [[ "$FUNC_EXISTS" -eq 0 ]]; then
    echo "❌ Fonction non trouvée: $FUNCTION_NAME"
    echo ""
    echo "Fonctions disponibles:"
    sqlite3 "$DB_FILE" "SELECT name FROM functions ORDER BY name;"
    exit 1
fi

# Informations sur la fonction
echo ""
echo "Informations sur la fonction:"
sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    'Bibliothèque:' as field, library_file as value FROM functions WHERE name = '$FUNCTION_NAME'
UNION ALL SELECT 'Description:', description FROM functions WHERE name = '$FUNCTION_NAME'
UNION ALL SELECT 'Paramètres:', COALESCE(parameters, '-') FROM functions WHERE name = '$FUNCTION_NAME'
UNION ALL SELECT 'Retour:', COALESCE(return_value, '-') FROM functions WHERE name = '$FUNCTION_NAME';
EOF

# Scripts qui utilisent cette fonction
echo ""
echo "Scripts utilisant cette fonction:"
sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    s.name,
    s.type,
    s.category
FROM scripts s
JOIN script_uses_functions suf ON s.id = suf.script_id
JOIN functions f ON suf.function_id = f.id
WHERE f.name = '$FUNCTION_NAME'
ORDER BY s.type, s.name;
EOF

# Compter
COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM scripts s JOIN script_uses_functions suf ON s.id = suf.script_id JOIN functions f ON suf.function_id = f.id WHERE f.name = '$FUNCTION_NAME';")

echo ""
echo "Total: $COUNT script(s)"
```

**Rendre exécutables** :

```bash
chmod +x tools/list-functions.sh
chmod +x tools/function-usage.sh
```

---

## 4.5 Exemples d'utilisation avancée

### Recherche complexe avec SQLite directement

```bash
# Scripts atomiques de catégorie storage, actifs, avec au moins 1 dépendance
sqlite3 -header -column database/scripts_catalogue.db <<EOF
SELECT 
    s.name,
    s.version,
    COUNT(sd.id) as nb_deps
FROM scripts s
LEFT JOIN script_dependencies sd ON s.id = sd.script_id
WHERE s.type = 'atomic'
  AND s.category = 'storage'
  AND s.status = 'active'
GROUP BY s.id
HAVING nb_deps > 0
ORDER BY nb_deps DESC;
EOF

# Orchestrateurs niveau 2 ou plus
sqlite3 database/scripts_catalogue.db <<EOF
SELECT name, type, description
FROM scripts
WHERE type LIKE 'orchestrator-%'
  AND CAST(substr(type, 14) AS INTEGER) >= 2
ORDER BY type, name;
EOF

# Scripts créés le mois dernier
sqlite3 database/scripts_catalogue.db <<EOF
SELECT 
    name, 
    type, 
    date(created_at) as creation_date
FROM scripts
WHERE created_at >= date('now', 'start of month', '-1 month')
  AND created_at < date('now', 'start of month')
ORDER BY created_at DESC;
EOF

# Scripts jamais exécutés
sqlite3 database/scripts_catalogue.db <<EOF
SELECT 
    s.name,
    s.type,
    s.created_at
FROM scripts s
LEFT JOIN usage_stats us ON s.id = us.script_id
WHERE us.id IS NULL
ORDER BY s.created_at;
EOF
```

### Analyse de dépendances en profondeur

```bash
# Trouver tous les scripts qui dépendent directement ou indirectement d'un script
# (requête récursive)
sqlite3 database/scripts_catalogue.db <<EOF
WITH RECURSIVE deps(script_id, level) AS (
    SELECT id, 0 FROM scripts WHERE name = 'detect-usb.sh'
    UNION ALL
    SELECT sd.script_id, deps.level + 1
    FROM script_dependencies sd
    JOIN deps ON sd.depends_on_script_id = deps.script_id
    WHERE sd.dependency_type = 'script'
)
SELECT 
    s.name,
    s.type,
    d.level as dependency_level
FROM deps d
JOIN scripts s ON d.script_id = s.id
ORDER BY d.level, s.name;
EOF
```

### Génération de graphes de dépendances (format DOT)

```bash
# Générer un fichier DOT pour Graphviz
sqlite3 database/scripts_catalogue.db <<EOF
.output dependencies.dot
SELECT 'digraph G {';
SELECT '  rankdir=LR;';
SELECT '  node [shape=box];';
SELECT 
    '  "' || s1.name || '" -> "' || s2.name || '";'
FROM script_dependencies sd
JOIN scripts s1 ON sd.script_id = s1.id
JOIN scripts s2 ON sd.depends_on_script_id = s2.id
WHERE sd.dependency_type = 'script';
SELECT '}';
.output stdout
EOF

# Générer l'image avec Graphviz
dot -Tpng dependencies.dot -o dependencies.png
```

---

## Conclusion du système de base de données

Vous disposez maintenant d'un **système complet de catalogage** avec :

✅ **Base SQLite installée et configurée**  
✅ **Schéma robuste avec 15+ tables**  
✅ **Scripts d'enregistrement automatisés**  
✅ **Outils de recherche puissants**  
✅ **Système d'export multi-formats**  
✅ **Interface web optionnelle**  
✅ **Intégration Git avec hooks**  
✅ **Maintenance automatisée**  
✅ **Requêtes SQL avancées**  

Le système est **production-ready** et évolutif ! 🎉

**Prochaines étapes suggérées** :
1. Initialiser la base : `./database/init-db.sh`
2. Enregistrer vos scripts existants : `./tools/register-all-scripts.sh`
3. Explorer avec l'interface de recherche : `./tools/search-db.sh --stats`
4. Configurer les backups automatiques (cron)

**Le catalogue SQLite est opérationnel ! 🚀** else {
                    card.style.display = 'none';
                }
            }
        }
    </script>
</body>
</html>
```

**Lancer le serveur web** :

```bash
# Avec PHP built-in server
cd web/
php -S localhost:8000

# Accéder à http://localhost:8000
```

---

## 9. Maintenance et Mises à Jour

### 9.1 Script de migration de schéma

**Créer le fichier `database/migrate-db.sh`** :

```bash
#!/bin/bash
#
# Script: migrate-db.sh
# Description: Applique les migrations de schéma
# Usage: ./migrate-db.sh <version>
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/scripts_catalogue.db"

VERSION=${1:-}

if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>"
    echo "Exemple: $0 1.1"
    exit 1
fi

echo "🔄 Migration vers la version $VERSION"
echo "=================================================="

# Backup avant migration
BACKUP_FILE="${DB_FILE}.before_v${VERSION}.backup"
cp "$DB_FILE" "$BACKUP_FILE"
echo "✓ Backup créé: $BACKUP_FILE"

# Appliquer les migrations selon la version
case $VERSION in
    1.1)
        echo "Migration 1.0 -> 1.1"
        sqlite3 "$DB_FILE" <<EOF
-- Ajout de nouvelles colonnes
ALTER TABLE scripts ADD COLUMN complexity_score INTEGER DEFAULT 0;
ALTER TABLE scripts ADD COLUMN test_coverage_percent INTEGER DEFAULT 0;

-- Nouvelle table pour les relations entre orchestrateurs
CREATE TABLE IF NOT EXISTS orchestrator_composition (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    orchestrator_id INTEGER NOT NULL,
    composed_script_id INTEGER NOT NULL,
    execution_order INTEGER,
    is_parallel BOOLEAN DEFAULT 0,
    
    FOREIGN KEY (orchestrator_id) REFERENCES scripts(id) ON DELETE CASCADE,
    FOREIGN KEY (composed_script_id) REFERENCES scripts(id) ON DELETE RESTRICT,
    UNIQUE(orchestrator_id, composed_script_id)
);
EOF
        echo "✓ Migration 1.1 appliquée"
        ;;
        
    1.2)
        echo "Migration 1.1 -> 1.2"
        sqlite3 "$DB_FILE" <<EOF
-- Table pour les benchmarks
CREATE TABLE IF NOT EXISTS performance_benchmarks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    benchmark_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    execution_time_ms INTEGER,
    memory_usage_mb INTEGER,
    cpu_usage_percent INTEGER,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

CREATE INDEX idx_benchmarks_script ON performance_benchmarks(script_id);
EOF
        echo "✓ Migration 1.2 appliquée"
        ;;
        
    *)
        echo "❌ Version de migration inconnue: $VERSION"
        exit 1
        ;;
esac

echo ""
echo "✅ Migration terminée!"
```

### 9.2 Mise à jour automatique des statistiques

**Créer le fichier `tools/update-stats.sh`** :

```bash
#!/bin/bash
#
# Script: update-stats.sh
# Description: Met à jour les statistiques d'utilisation dans la base
# Usage: ./update-stats.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"
LOGS_DIR="$PROJECT_ROOT/logs"

echo "📊 Mise à jour des statistiques d'utilisation"
echo "=================================================="

# Date d'aujourd'hui
TODAY=$(date +%Y-%m-%d)

# Parser les logs pour extraire les statistiques
if [[ ! -d "$LOGS_DIR" ]]; then
    echo "⚠️  Répertoire de logs non trouvé: $LOGS_DIR"
    exit 0
fi

# Pour chaque script dans la base
sqlite3 "$DB_FILE" "SELECT id, name FROM scripts;" | while IFS='|' read -r script_id script_name; do
    
    # Chercher les logs de ce script
    log_file="$LOGS_DIR/atomics/$TODAY/${script_name%.sh}.log"
    
    if [[ ! -f "$log_file" ]]; then
        continue
    fi
    
    # Compter les exécutions
    exec_count=$(grep -c "Script started" "$log_file" || echo 0)
    success_count=$(grep -c "Script completed successfully" "$log_file" || echo 0)
    error_count=$(grep -c "Script failed" "$log_file" || echo 0)
    
    # Calculer la durée moyenne (simplifié)
    avg_duration=0  # TODO: parser les durées réelles
    
    # Insérer ou mettre à jour les stats
    sqlite3 "$DB_FILE" <<EOF
INSERT INTO usage_stats (
    script_id, execution_date, execution_count, success_count, error_count, average_duration_ms
) VALUES (
    $script_id, '$TODAY', $exec_count, $success_count, $error_count, $avg_duration
)
ON CONFLICT(script_id, execution_date) DO UPDATE SET
    execution_count = $exec_count,
    success_count = $success_count,
    error_count = $error_count,
    average_duration_ms = $avg_duration;
EOF
    
    if [[ $exec_count -gt 0 ]]; then
        echo "  ✓ $script_name: $exec_count exécutions ($success_count succès, $error_count erreurs)"
    fi
done

echo ""
echo "✅ Statistiques mises à jour!"
```

**Automatiser avec cron** :

```bash
# Mettre à jour les stats chaque soir à 23h
0 23 * * * /chemin/vers/projet/tools/update-stats.sh >> /var/log/update-stats.log 2>&1
```

---

## 10. Intégration avec les Scripts

### 10.1 Auto-enregistrement lors de la création

**Modifier le template de script atomique pour inclure** :

```bash
# À la fin du script atomique, après main()

# Auto-enregistrement dans la base (si activé)
if [[ "${AUTO_REGISTER_DB:-0}" == "1" ]]; then
    "$PROJECT_ROOT/tools/register-script.sh" "$(basename "$0")" <<< "o" > /dev/null 2>&1 || true
fi
```

**Activer l'auto-enregistrement** :

```bash
export AUTO_REGISTER_DB=1
```

### 10.2 Hook Git pour enregistrement automatique

**Créer le fichier `.git/hooks/post-commit`** :

```bash
#!/bin/bash
#
# Hook Git: post-commit
# Auto-enregistre les nouveaux scripts dans la base
#

PROJECT_ROOT="$(git rev-parse --show-toplevel)"

# Récupérer les fichiers .sh ajoutés dans ce commit
ADDED_SCRIPTS=$(git diff-tree --no-commit-id --name-only -r HEAD | grep '\.sh    echo "Par type:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    type,
    COUNT(*) as count
FROM scripts
GROUP BY type
ORDER BY type;
EOF
    
    # Par catégorie
    echo ""
    echo "Par catégorie:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    category,
    COUNT(*) as count
FROM scripts
GROUP BY category
ORDER BY count DESC;
EOF
    
    # Par statut
    echo ""
    echo "Par statut:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    status,
    COUNT(*) as count
FROM scripts
GROUP BY status;
EOF
    
    # Avec le plus de dépendances
    echo ""
    echo "Top 5 scripts avec le plus de dépendances:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    name,
    dependency_count
FROM v_scripts_with_dep_count
ORDER BY dependency_count DESC
LIMIT 5;
EOF
}

# Fonction pour afficher les détails d'un script
show_script_info() {
    local script_name=$1
    
    echo "📄 Détails du script: $script_name"
    echo "==========================================="
    
    # Informations générales
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    'Nom:' as field, name as value FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Type:', type FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Catégorie:', category FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Version:', version FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Statut:', status FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Chemin:', path FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Documentation:', documentation_path FROM scripts WHERE name = '$script_name';
EOF
    
    echo ""
    echo "Description:"
    sqlite3 "$DB_FILE" "SELECT description FROM scripts WHERE name = '$script_name';"
    
    # Paramètres
    echo ""
    echo "Paramètres d'entrée:"
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    param_name as Parametre,
    param_type as Type,
    CASE WHEN is_required = 1 THEN 'Oui' ELSE 'Non' END as Obligatoire,
    COALESCE(default_value, '-') as Defaut,
    description as Description
FROM script_parameters
WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name')
ORDER BY position, param_name;
EOF
    
    # Sorties
    echo ""
    echo "Champs de sortie (JSON):"
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    output_field as Champ,
    field_type as Type,
    description as Description
FROM script_outputs
WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name')
ORDER BY parent_field, output_field;
EOF
    
    # Codes de sortie
    echo ""
    echo "Codes de sortie:"
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    exit_code as Code,
    code_name as Nom,
    description as Description
FROM exit_codes
WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name')
ORDER BY exit_code;
EOF
    
    # Dépendances
    echo ""
    echo "Dépendances:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    dependency_type || ': ' || 
    COALESCE(
        (SELECT name FROM scripts WHERE id = depends_on_script_id),
        depends_on_command,
        depends_on_library,
        depends_on_package
    ) as dependance
FROM script_dependencies
WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name');
EOF
    
    # Tags
    echo ""
    echo "Tags:"
    sqlite3 "$DB_FILE" "SELECT GROUP_CONCAT(tag, ', ') FROM script_tags WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name');"
    
    # Exemples
    echo ""
    echo "Exemples d'utilisation:"
    sqlite3 "$DB_FILE" <<EOF
SELECT 
    example_title || ':
    ' || example_command || '
    
' as exemple
FROM script_examples
WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name');
EOF
}

# Fonction pour afficher le graphe de dépendances
show_dependencies() {
    local script_name=$1
    
    echo "🔗 Dépendances de: $script_name"
    echo "==========================================="
    
    # Dépendances directes
    echo ""
    echo "Dépend de (niveau 1):"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    depends_on as Script,
    CASE WHEN is_optional = 1 THEN 'Optionnel' ELSE 'Obligatoire' END as Type
FROM v_dependency_graph
WHERE script_name = '$script_name';
EOF
    
    # Scripts qui dépendent de celui-ci
    echo ""
    echo "Scripts qui dépendent de $script_name:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    script_name as Script,
    script_type as Type
FROM v_dependency_graph
WHERE depends_on = '$script_name';
EOF
}

# Parsing des arguments
case ${1:-} in
    -n|--name)
        search_by_name "$2"
        ;;
    -c|--category)
        search_by_category "$2"
        ;;
    -t|--type)
        TYPE=$2
        sqlite3 -header -column "$DB_FILE" "SELECT name, category, description FROM scripts WHERE type = '$TYPE' ORDER BY name;"
        ;;
    -T|--tag)
        TAG=$2
        echo "🔍 Scripts avec le tag: $TAG"
        sqlite3 -header -column "$DB_FILE" <<EOF
SELECT s.name, s.type, s.category
FROM scripts s
JOIN script_tags st ON s.id = st.script_id
WHERE st.tag = '$TAG'
ORDER BY s.name;
EOF
        ;;
    -d|--description)
        TERM=$2
        echo "🔍 Recherche dans les descriptions: $TERM"
        sqlite3 -header -column "$DB_FILE" "SELECT name, type, description FROM scripts WHERE description LIKE '%$TERM%' OR long_description LIKE '%$TERM%';"
        ;;
    -a|--all)
        list_all
        ;;
    -s|--stats)
        show_stats
        ;;
    -i|--info)
        show_script_info "$2"
        ;;
    -D|--dependencies)
        show_dependencies "$2"
        ;;
    -h|--help)
        show_help
        ;;
    "")
        show_help
        ;;
    *)
        echo "Option inconnue: $1"
        show_help
        exit 1
        ;;
esac
```

**Rendre exécutable** :

```bash
chmod +x tools/search-db.sh
```

### 4.2 Exemples d'utilisation

```bash
# Lister tous les scripts
./tools/search-db.sh --all

# Rechercher par nom
./tools/search-db.sh --name "detect-*"
./tools/search-db.sh --name "backup"

# Rechercher par catégorie
./tools/search-db.sh --category storage
./tools/search-db.sh --category network

# Rechercher par type
./tools/search-db.sh --type atomic
./tools/search-db.sh --type orchestrator-1

# Voir les détails d'un script
./tools/search-db.sh --info detect-usb.sh
./tools/search-db.sh --info setup-disk.sh

# Voir les dépendances
./tools/search-db.sh --dependencies setup-disk.sh

# Voir les statistiques
./tools/search-db.sh --stats

# Rechercher par tag
./tools/search-db.sh --tag backup
./tools/search-db.sh --tag security
```

---

## 5. Gestion des Fonctions (Bibliothèques)

### 5.1 Enregistrement des fonctions

**Créer le fichier `tools/register-function.sh`** :

```bash
#!/bin/bash
#
# Script: register-function.sh
# Description: Enregistre une fonction de bibliothèque dans la base
# Usage: ./register-function.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"

echo "📚 Enregistrement d'une fonction"
echo "=================================================="

# Demander les informations
read -p "Nom de la fonction: " func_name
read -p "Fichier bibliothèque (ex: lib/cache.sh): " lib_file
read -p "Catégorie (cache, retry, notification, etc.): " category
read -p "Description: " description
read -p "Paramètres (ex: \$1=key, \$2=value): " parameters
read -p "Valeur de retour: " return_value
read -p "Exemple d'utilisation: " example

# Insérer dans la base
sqlite3 "$DB_FILE" <<EOF
INSERT INTO functions (
    name, library_file, category, description, 
    parameters, return_value, example_usage
) VALUES (
    '$func_name',
    '$lib_file',
    '$category',
    '$description',
    '$parameters',
    '$return_value',
    '$example'
);
EOF

if [[ $? -eq 0 ]]; then
    echo "✅ Fonction enregistrée: $func_name"
else
    echo "❌ Erreur lors de l'enregistrement"
fi
```

### 5.2 Lier un script à des fonctions

**Créer le fichier `tools/link-script-functions.sh`** :

```bash
#!/bin/bash
#
# Script: link-script-functions.sh
# Description: Lie un script aux fonctions qu'il utilise
# Usage: ./link-script-functions.sh <script_name>
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"

SCRIPT_NAME=$1

# Récupérer l'ID du script
SCRIPT_ID=$(sqlite3 "$DB_FILE" "SELECT id FROM scripts WHERE name = '$SCRIPT_NAME';")

if [[ -z "$SCRIPT_ID" ]]; then
    echo "❌ Script non trouvé: $SCRIPT_NAME"
    exit 1
fi

echo "🔗 Liaison de fonctions pour: $SCRIPT_NAME"
echo "=================================================="

# Lister les fonctions disponibles
echo ""
echo "Fonctions disponibles:"
sqlite3 -column "$DB_FILE" "SELECT id, name, library_file FROM functions ORDER BY library_file, name;"

echo ""
echo "Entrez les IDs des fonctions utilisées (séparés par des espaces, 'done' pour terminer):"

while true; do
    read -p "ID fonction (ou 'done'): " func_id
    [[ "$func_id" == "done" ]] && break
    
    # Vérifier que la fonction existe
    FUNC_EXISTS=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM functions WHERE id = $func_id;")
    if [[ "$FUNC_EXISTS" -eq 0 ]]; then
        echo "⚠️  Fonction ID $func_id non trouvée"
        continue
    fi
    
    # Lier
    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO script_uses_functions (script_id, function_id) VALUES ($SCRIPT_ID, $func_id);" 2>/dev/null
    
    FUNC_NAME=$(sqlite3 "$DB_FILE" "SELECT name FROM functions WHERE id = $func_id;")
    echo "  ✓ Lié à: $FUNC_NAME"
done

echo ""
echo "✅ Liaison terminée!"
```

---

## 6. Requêtes SQL Utiles

### 6.1 Fichier de requêtes prédéfinies

**Créer le fichier `database/queries/common-queries.sql`** :

```sql
-- ============================================================================
-- REQUETES SQL COMMUNES POUR LE CATALOGUE DE SCRIPTS
-- ============================================================================

-- 1. Liste tous les scripts atomiques actifs
-- Usage: sqlite3 scripts_catalogue.db < queries/common-queries.sql
SELECT name, category, description
FROM scripts
WHERE type = 'atomic' AND status = 'active'
ORDER BY category, name;

-- 2. Scripts avec leurs dépendances (graphe complet)
SELECT 
    s1.name as script,
    s1.type,
    GROUP_CONCAT(
        COALESCE(s2.name, sd.depends_on_command, sd.depends_on_library),
        ', '
    ) as dependencies
FROM scripts s1
LEFT JOIN script_dependencies sd ON s1.id = sd.script_id
LEFT JOIN scripts s2 ON sd.depends_on_script_id = s2.id
GROUP BY s1.id
ORDER BY s1.name;

-- 3. Scripts par catégorie avec comptage
SELECT 
    category,
    COUNT(*) as total_scripts,
    SUM(CASE WHEN type = 'atomic' THEN 1 ELSE 0 END) as atomiques,
    SUM(CASE WHEN type LIKE 'orchestrator%' THEN 1 ELSE 0 END) as orchestrateurs
FROM scripts
WHERE status = 'active'
GROUP BY category
ORDER BY total_scripts DESC;

-- 4. Scripts deprecated à supprimer
SELECT 
    name,
    type,
    category,
    version,
    updated_at,
    julianday('now') - julianday(updated_at) as jours_depuis_maj
FROM scripts
WHERE status = 'deprecated'
ORDER BY updated_at;

-- 5. Orchestrateurs et leurs scripts atomiques
SELECT 
    s1.name as orchestrateur,
    s1.type as niveau,
    s2.name as script_atomique
FROM scripts s1
JOIN script_dependencies sd ON s1.id = sd.script_id
JOIN scripts s2 ON sd.depends_on_script_id = s2.id
WHERE s1.type LIKE 'orchestrator%' 
  AND s2.type = 'atomic'
ORDER BY s1.name, s2.name;

-- 6. Scripts sans documentation
SELECT 
    name,
    type,
    category,
    path
FROM scripts
WHERE documentation_path IS NULL 
   OR documentation_path = ''
ORDER BY type, name;

-- 7. Fonctions par bibliothèque
SELECT 
    library_file,
    COUNT(*) as nb_fonctions,
    GROUP_CONCAT(name, ', ') as fonctions
FROM functions
WHERE status = 'active'
GROUP BY library_file
ORDER BY nb_fonctions DESC;

-- 8. Scripts utilisant une fonction spécifique
-- Remplacer 'cache_get' par la fonction recherchée
SELECT 
    s.name,
    s.type,
    s.category
FROM scripts s
JOIN script_uses_functions suf ON s.id = suf.script_id
JOIN functions f ON suf.function_id = f.id
WHERE f.name = 'cache_get'
ORDER BY s.type, s.name;

-- 9. Scripts les plus complexes (plus de dépendances)
SELECT 
    name,
    type,
    dependency_count,
    category
FROM v_scripts_with_dep_count
WHERE dependency_count > 0
ORDER BY dependency_count DESC
LIMIT 20;

-- 10. Scripts jamais testés
SELECT 
    name,
    type,
    category,
    created_at,
    last_tested
FROM scripts
WHERE last_tested IS NULL
ORDER BY created_at;

-- 11. Statistiques d'utilisation des derniers 7 jours
SELECT 
    s.name,
    s.type,
    SUM(us.execution_count) as executions,
    SUM(us.success_count) as success,
    SUM(us.error_count) as errors,
    ROUND(AVG(us.average_duration_ms), 2) as avg_duration_ms
FROM scripts s
JOIN usage_stats us ON s.id = us.script_id
WHERE us.execution_date >= date('now', '-7 days')
GROUP BY s.id
ORDER BY executions DESC
LIMIT 20;

-- 12. Scripts avec paramètres obligatoires
SELECT 
    s.name,
    s.type,
    COUNT(sp.id) as nb_params_obligatoires,
    GROUP_CONCAT(sp.param_name, ', ') as parametres
FROM scripts s
JOIN script_parameters sp ON s.id = sp.script_id
WHERE sp.is_required = 1
GROUP BY s.id
ORDER BY nb_params_obligatoires DESC;

-- 13. Export CSV de tous les scripts
.mode csv
.headers on
.output scripts_export.csv
SELECT 
    name,
    type,
    category,
    status,
    version,
    description,
    path
FROM scripts
ORDER BY type, category, name;
.output stdout

-- 14. Recherche full-text dans descriptions
-- Remplacer 'backup' par votre terme de recherche
SELECT 
    name,
    type,
    category,
    description
FROM scripts
WHERE description LIKE '%backup%'
   OR long_description LIKE '%backup%'
ORDER BY type, name;

-- 15. Scripts par auteur
SELECT 
    author,
    COUNT(*) as nb_scripts,
    GROUP_CONCAT(DISTINCT type) as types
FROM scripts
WHERE author IS NOT NULL
GROUP BY author
ORDER BY nb_scripts DESC;
```

### 6.2 Utilisation des requêtes

```bash
# Exécuter une requête spécifique
sqlite3 database/scripts_catalogue.db < database/queries/common-queries.sql

# Ou en interactif
sqlite3 database/scripts_catalogue.db

# Dans SQLite interactif
sqlite> .read database/queries/common-queries.sql

# Export CSV
sqlite3 -csv -header database/scripts_catalogue.db "SELECT * FROM scripts;" > scripts.csv
```

---

## 7. Export et Backup

### 7.1 Script d'export

**Créer le fichier `tools/export-db.sh`** :

```bash
#!/bin/bash
#
# Script: export-db.sh
# Description: Exporte la base de données dans différents formats
# Usage: ./export-db.sh [format]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"
EXPORT_DIR="$PROJECT_ROOT/exports"

mkdir -p "$EXPORT_DIR"

FORMAT=${1:-all}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "📤 Export de la base de données"
echo "=================================================="

# Export SQL (dump complet)
export_sql() {
    local output="$EXPORT_DIR/catalogue_${TIMESTAMP}.sql"
    echo "Exportation SQL..."
    sqlite3 "$DB_FILE" .dump > "$output"
    echo "  ✓ SQL: $output"
}

# Export CSV de chaque table
export_csv() {
    echo "Exportation CSV..."
    local csv_dir="$EXPORT_DIR/csv_${TIMESTAMP}"
    mkdir -p "$csv_dir"
    
    # Liste des tables
    local tables=$(sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    
    for table in $tables; do
        sqlite3 -header -csv "$DB_FILE" "SELECT * FROM $table;" > "$csv_dir/${table}.csv"
        echo "  ✓ CSV: ${table}.csv"
    done
}

# Export JSON
export_json() {
    echo "Exportation JSON..."
    local json_file="$EXPORT_DIR/catalogue_${TIMESTAMP}.json"
    
    sqlite3 "$DB_FILE" <<EOF | python3 -m json.tool > "$json_file"
SELECT json_object(
    'export_date', datetime('now'),
    'version', '1.0',
    'scripts', (
        SELECT json_group_array(
            json_object(
                'name', name,
                'type', type,
                'category', category,
                'description', description,
                'version', version,
                'status', status
            )
        )
        FROM scripts
    ),
    'functions', (
        SELECT json_group_array(
            json_object(
                'name', name,
                'library', library_file,
                'description', description
            )
        )
        FROM functions
    )
);
EOF
    
    echo "  ✓ JSON: $json_file"
}

# Export Markdown (documentation)
export_markdown() {
    echo "Exportation Markdown..."
    local md_file="$EXPORT_DIR/catalogue_${TIMESTAMP}.md"
    
    cat > "$md_file" <<EOF
# Catalogue de Scripts
Généré le: $(date)

## Scripts Atomiques

EOF
    
    sqlite3 "$DB_FILE" "SELECT '### ' || name || char(10) || char(10) || '**Description:** ' || description || char(10) || char(10) FROM scripts WHERE type='atomic' ORDER BY category, name;" >> "$md_file"
    
    cat >> "$md_file" <<EOF

## Orchestrateurs

EOF
    
    sqlite3 "$DB_FILE" "SELECT '### ' || name || char(10) || char(10) || '**Description:** ' || description || char(10) || '**Niveau:** ' || type || char(10) || char(10) FROM scripts WHERE type LIKE 'orchestrator%' ORDER BY type, name;" >> "$md_file"
    
    echo "  ✓ Markdown: $md_file"
}

# Backup complet (copie de la DB)
backup_db() {
    echo "Backup de la base..."
    local backup_file="$EXPORT_DIR/backup_${TIMESTAMP}.db"
    cp "$DB_FILE" "$backup_file"
    echo "  ✓ Backup: $backup_file"
}

# Exécution selon le format
case $FORMAT in
    sql)
        export_sql
        ;;
    csv)
        export_csv
        ;;
    json)
        export_json
        ;;
    markdown|md)
        export_markdown
        ;;
    backup)
        backup_db
        ;;
    all)
        export_sql
        export_csv
        export_json
        export_markdown
        backup_db
        ;;
    *)
        echo "Format inconnu: $FORMAT"
        echo "Formats disponibles: sql, csv, json, markdown, backup, all"
        exit 1
        ;;
esac

echo ""
echo "✅ Export terminé!"
echo "   Répertoire: $EXPORT_DIR"
```

### 7.2 Automatisation des backups

**Créer un cron job** :

```bash
# Editer crontab
crontab -e

# Ajouter une ligne pour backup quotidien à 2h du matin
0 2 * * * /chemin/vers/projet/tools/export-db.sh backup >> /var/log/db-backup.log 2>&1
```

---

## 8. Interface Web (Optionnel)

### 8.1 Serveur Web Simple avec PHP

**Créer le fichier `web/index.php`** :

```php
<?php
// Interface web simple pour consulter le catalogue
$db_path = __DIR__ . '/../database/scripts_catalogue.db';
$db = new SQLite3($db_path);

// Récupérer tous les scripts
$query = "SELECT name, type, category, description, status FROM scripts ORDER BY type, category, name";
$results = $db->query($query);

$scripts = [];
while ($row = $results->fetchArray(SQLITE3_ASSOC)) {
    $scripts[] = $row;
}

// Statistiques
$stats_query = "SELECT 
    COUNT(*) as total,
    SUM(CASE WHEN type = 'atomic' THEN 1 ELSE 0 END) as atomiques,
    SUM(CASE WHEN type LIKE 'orchestrator%' THEN 1 ELSE 0 END) as orchestrateurs
FROM scripts WHERE status = 'active'";
$stats = $db->querySingle($stats_query, true);

?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Catalogue de Scripts</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            padding: 20px;
            background: #f5f5f5;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        header { 
            background: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 { color: #333; margin-bottom: 10px; }
        .stats { 
            display: flex;
            gap: 20px;
            margin-top: 20px;
        }
        .stat-card {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            flex: 1;
        }
        .stat-number { font-size: 32px; font-weight: bold; color: #007bff; }
        .stat-label { color: #666; margin-top: 5px; }
        
        .search-box {
            background: white;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        input[type="text"] {
            width: 100%;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 6px;
            font-size: 16px;
        }
        
        .scripts-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
            gap: 20px;
        }
        .script-card {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .script-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0,0,0,0.15);
        }
        .script-name {
            font-size: 18px;
            font-weight: 600;
            color: #333;
            margin-bottom: 8px;
        }
        .script-meta {
            display: flex;
            gap: 10px;
            margin-bottom: 12px;
        }
        .badge {
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 500;
        }
        .badge-atomic { background: #e3f2fd; color: #1976d2; }
        .badge-orchestrator { background: #f3e5f5; color: #7b1fa2; }
        .badge-category { background: #fff3e0; color: #f57c00; }
        .script-description {
            color: #666;
            line-height: 1.6;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📚 Catalogue de Scripts</h1>
            <p style="color: #666;">Base de données de scripts et fonctions</p>
            
            <div class="stats">
                <div class="stat-card">
                    <div class="stat-number"><?= $stats['total'] ?></div>
                    <div class="stat-label">Total Scripts</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number"><?= $stats['atomiques'] ?></div>
                    <div class="stat-label">Atomiques</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number"><?= $stats['orchestrateurs'] ?></div>
                    <div class="stat-label">Orchestrateurs</div>
                </div>
            </div>
        </header>
        
        <div class="search-box">
            <input type="text" id="searchInput" placeholder="🔍 Rechercher un script..." onkeyup="filterScripts()">
        </div>
        
        <div class="scripts-grid" id="scriptsGrid">
            <?php foreach ($scripts as $script): ?>
            <div class="script-card" data-name="<?= htmlspecialchars($script['name']) ?>" data-category="<?= htmlspecialchars($script['category']) ?>">
                <div class="script-name"><?= htmlspecialchars($script['name']) ?></div>
                <div class="script-meta">
                    <span class="badge <?= $script['type'] === 'atomic' ? 'badge-atomic' : 'badge-orchestrator' ?>">
                        <?= htmlspecialchars($script['type']) ?>
                    </span>
                    <span class="badge badge-category"><?= htmlspecialchars($script['category']) ?></span>
                </div>
                <div class="script-description">
                    <?= htmlspecialchars($script['description']) ?>
                </div>
            </div>
            <?php endforeach; ?>
        </div>
    </div>
    
    <script>
        function filterScripts() {
            const input = document.getElementById('searchInput');
            const filter = input.value.toLowerCase();
            const cards = document.getElementsByClassName('script-card');
            
            for (let card of cards) {
                const name = card.dataset.name.toLowerCase();
                const category = card.dataset.category.toLowerCase();
                const text = card.textContent.toLowerCase();
                
                if (name.includes(filter) || category.includes(filter) || text.includes(filter)) {
                    card.style.display = '';
                } else# Base de Données SQLite - Catalogue de Scripts et Fonctions

## Introduction

Ce document explique comment installer, configurer et utiliser une base de données SQLite3 pour référencer tous les scripts et fonctions développés selon la méthodologie. Cette base permet de :

- 📋 Cataloguer tous les scripts atomiques et orchestrateurs
- 🔍 Rechercher rapidement des scripts par nom, catégorie, fonction
- 📊 Suivre les dépendances entre scripts
- 📝 Documenter les entrées/sorties de chaque script
- 🔄 Gérer les versions et l'évolution
- 📈 Analyser l'utilisation et les statistiques

---

## 1. Installation de SQLite3

### 1.1 Installation sur différentes distributions

#### Debian/Ubuntu
```bash
sudo apt-get update
sudo apt-get install -y sqlite3 libsqlite3-dev
```

#### RHEL/CentOS/Fedora
```bash
sudo yum install -y sqlite sqlite-devel
# ou
sudo dnf install -y sqlite sqlite-devel
```

#### Arch Linux
```bash
sudo pacman -S sqlite
```

#### Alpine Linux
```bash
apk add sqlite sqlite-dev
```

### 1.2 Vérification de l'installation

```bash
# Vérifier la version
sqlite3 --version

# Test rapide
sqlite3 test.db "SELECT 'Installation OK';"
rm test.db
```

**Version recommandée** : SQLite 3.35.0 ou supérieur

---

## 2. Création de la Base de Données

### 2.1 Structure du projet

```
projet/
├── database/
│   ├── scripts_catalogue.db       # Base de données principale
│   ├── schema.sql                 # Schéma de la base
│   ├── init-db.sh                 # Script d'initialisation
│   ├── migrate-db.sh              # Script de migration
│   └── queries/                   # Requêtes SQL prédéfinies
│       ├── search-script.sql
│       ├── list-dependencies.sql
│       └── stats.sql
├── tools/
│   ├── register-script.sh         # Enregistre un script dans la DB
│   ├── search-db.sh               # Recherche dans la DB
│   └── export-db.sh               # Export de la DB
└── docs/
    └── database-schema.md         # Documentation du schéma
```

### 2.2 Schéma de la base de données

**Créer le fichier `database/schema.sql`** :

```sql
-- ============================================================================
-- SCHEMA DE LA BASE DE DONNEES - CATALOGUE DE SCRIPTS
-- Version: 1.0
-- Date: 2025-10-03
-- ============================================================================

-- Table principale des scripts
CREATE TABLE IF NOT EXISTS scripts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,              -- Nom du script (ex: detect-usb.sh)
    type TEXT NOT NULL,                      -- Type: atomic, orchestrator-1, orchestrator-2, etc.
    category TEXT NOT NULL,                  -- Catégorie (système, réseau, etc.)
    subcategory TEXT,                        -- Sous-catégorie (optionnel)
    description TEXT NOT NULL,               -- Description courte
    long_description TEXT,                   -- Description longue
    path TEXT NOT NULL,                      -- Chemin relatif du script
    version TEXT NOT NULL DEFAULT '1.0.0',  -- Version sémantique
    status TEXT NOT NULL DEFAULT 'active',  -- active, deprecated, obsolete
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_tested DATETIME,                    -- Dernière date de test
    author TEXT,                             -- Auteur du script
    maintainer TEXT,                         -- Mainteneur actuel
    documentation_path TEXT,                 -- Chemin vers la doc .md
    
    CHECK (type IN ('atomic', 'orchestrator-1', 'orchestrator-2', 'orchestrator-3', 'orchestrator-4', 'orchestrator-5')),
    CHECK (status IN ('active', 'deprecated', 'obsolete', 'development'))
);

-- Index pour recherches rapides
CREATE INDEX idx_scripts_name ON scripts(name);
CREATE INDEX idx_scripts_type ON scripts(type);
CREATE INDEX idx_scripts_category ON scripts(category);
CREATE INDEX idx_scripts_status ON scripts(status);

-- Table des paramètres d'entrée
CREATE TABLE IF NOT EXISTS script_parameters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    param_name TEXT NOT NULL,               -- Nom du paramètre
    param_type TEXT NOT NULL,               -- Type: string, integer, boolean, path, etc.
    is_required BOOLEAN NOT NULL DEFAULT 0, -- Obligatoire ou optionnel
    default_value TEXT,                     -- Valeur par défaut
    description TEXT NOT NULL,              -- Description du paramètre
    validation_rule TEXT,                   -- Règle de validation (regex, range, etc.)
    example_value TEXT,                     -- Exemple de valeur
    position INTEGER,                       -- Position dans la liste des paramètres
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, param_name)
);

CREATE INDEX idx_params_script ON script_parameters(script_id);

-- Table des sorties
CREATE TABLE IF NOT EXISTS script_outputs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    output_field TEXT NOT NULL,             -- Champ dans le JSON de sortie
    field_type TEXT NOT NULL,               -- Type: string, integer, array, object, boolean
    description TEXT NOT NULL,              -- Description du champ
    is_always_present BOOLEAN DEFAULT 1,    -- Toujours présent ou conditionnel
    example_value TEXT,                     -- Exemple de valeur
    parent_field TEXT,                      -- Champ parent si nested (ex: data.devices)
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

CREATE INDEX idx_outputs_script ON script_outputs(script_id);

-- Table des dépendances
CREATE TABLE IF NOT EXISTS script_dependencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,             -- Script qui dépend
    depends_on_script_id INTEGER,           -- Script dont il dépend
    depends_on_command TEXT,                -- Commande système dont il dépend
    depends_on_library TEXT,                -- Bibliothèque dont il dépend
    dependency_type TEXT NOT NULL,          -- Type: script, command, library, package
    is_optional BOOLEAN DEFAULT 0,          -- Dépendance optionnelle
    minimum_version TEXT,                   -- Version minimale requise
    notes TEXT,                             -- Notes sur la dépendance
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    FOREIGN KEY (depends_on_script_id) REFERENCES scripts(id) ON DELETE RESTRICT,
    CHECK (dependency_type IN ('script', 'command', 'library', 'package'))
);

CREATE INDEX idx_deps_script ON script_dependencies(script_id);
CREATE INDEX idx_deps_on_script ON script_dependencies(depends_on_script_id);

-- Table des codes de sortie
CREATE TABLE IF NOT EXISTS exit_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    exit_code INTEGER NOT NULL,             -- Code de sortie (0-255)
    code_name TEXT,                         -- Nom symbolique (EXIT_SUCCESS, EXIT_ERROR_GENERAL, etc.)
    description TEXT NOT NULL,              -- Description de la condition
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, exit_code)
);

CREATE INDEX idx_exitcodes_script ON exit_codes(script_id);

-- Table des tags/mots-clés
CREATE TABLE IF NOT EXISTS script_tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    tag TEXT NOT NULL,                      -- Tag (ex: backup, network, security)
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, tag)
);

CREATE INDEX idx_tags_script ON script_tags(script_id);
CREATE INDEX idx_tags_tag ON script_tags(tag);

-- Table des cas d'usage
CREATE TABLE IF NOT EXISTS use_cases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    use_case_title TEXT NOT NULL,           -- Titre du cas d'usage
    use_case_description TEXT NOT NULL,     -- Description détaillée
    example_command TEXT,                   -- Exemple de commande
    context TEXT,                           -- Contexte d'utilisation
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

CREATE INDEX idx_usecases_script ON use_cases(script_id);

-- Table d'historique des versions
CREATE TABLE IF NOT EXISTS version_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    version TEXT NOT NULL,                  -- Version
    release_date DATETIME NOT NULL,
    changelog TEXT NOT NULL,                -- Description des changements
    breaking_changes BOOLEAN DEFAULT 0,     -- Changements incompatibles
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

CREATE INDEX idx_versions_script ON version_history(script_id);

-- Table des statistiques d'utilisation
CREATE TABLE IF NOT EXISTS usage_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    execution_date DATE NOT NULL,
    execution_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    average_duration_ms INTEGER,            -- Durée moyenne en millisecondes
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, execution_date)
);

CREATE INDEX idx_stats_script ON usage_stats(script_id);
CREATE INDEX idx_stats_date ON usage_stats(execution_date);

-- Table des exemples complets
CREATE TABLE IF NOT EXISTS script_examples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    example_title TEXT NOT NULL,            -- Titre de l'exemple
    example_command TEXT NOT NULL,          -- Commande complète
    example_description TEXT,               -- Description de ce que fait l'exemple
    expected_output TEXT,                   -- Sortie attendue
    prerequisites TEXT,                     -- Prérequis pour cet exemple
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

CREATE INDEX idx_examples_script ON script_examples(script_id);

-- Table des fonctions (bibliothèques)
CREATE TABLE IF NOT EXISTS functions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,              -- Nom de la fonction
    library_file TEXT NOT NULL,             -- Fichier bibliothèque (ex: lib/cache.sh)
    category TEXT NOT NULL,                 -- Catégorie de fonction
    description TEXT NOT NULL,              -- Description
    parameters TEXT,                        -- Paramètres de la fonction (format texte)
    return_value TEXT,                      -- Ce que retourne la fonction
    example_usage TEXT,                     -- Exemple d'utilisation
    version TEXT NOT NULL DEFAULT '1.0.0',
    status TEXT NOT NULL DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    CHECK (status IN ('active', 'deprecated', 'obsolete'))
);

CREATE INDEX idx_functions_name ON functions(name);
CREATE INDEX idx_functions_library ON functions(library_file);

-- Table de relation script -> fonctions utilisées
CREATE TABLE IF NOT EXISTS script_uses_functions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    function_id INTEGER NOT NULL,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    FOREIGN KEY (function_id) REFERENCES functions(id) ON DELETE RESTRICT,
    UNIQUE(script_id, function_id)
);

CREATE INDEX idx_script_functions ON script_uses_functions(script_id);
CREATE INDEX idx_function_scripts ON script_uses_functions(function_id);

-- Vues utiles pour requêtes fréquentes

-- Vue: Scripts avec leur nombre de dépendances
CREATE VIEW IF NOT EXISTS v_scripts_with_dep_count AS
SELECT 
    s.id,
    s.name,
    s.type,
    s.category,
    s.status,
    s.version,
    COUNT(DISTINCT sd.id) as dependency_count
FROM scripts s
LEFT JOIN script_dependencies sd ON s.id = sd.script_id
GROUP BY s.id;

-- Vue: Scripts les plus utilisés (30 derniers jours)
CREATE VIEW IF NOT EXISTS v_top_scripts_30days AS
SELECT 
    s.id,
    s.name,
    s.type,
    s.category,
    SUM(us.execution_count) as total_executions,
    AVG(us.average_duration_ms) as avg_duration
FROM scripts s
JOIN usage_stats us ON s.id = us.script_id
WHERE us.execution_date >= date('now', '-30 days')
GROUP BY s.id
ORDER BY total_executions DESC;

-- Vue: Graphe de dépendances
CREATE VIEW IF NOT EXISTS v_dependency_graph AS
SELECT 
    s1.name as script_name,
    s1.type as script_type,
    s2.name as depends_on,
    sd.dependency_type,
    sd.is_optional
FROM script_dependencies sd
JOIN scripts s1 ON sd.script_id = s1.id
LEFT JOIN scripts s2 ON sd.depends_on_script_id = s2.id
WHERE sd.dependency_type = 'script';

-- Triggers pour mettre à jour updated_at automatiquement
CREATE TRIGGER update_scripts_timestamp 
AFTER UPDATE ON scripts
BEGIN
    UPDATE scripts SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- ============================================================================
-- FIN DU SCHEMA
-- ============================================================================
```

### 2.3 Script d'initialisation

**Créer le fichier `database/init-db.sh`** :

```bash
#!/bin/bash
#
# Script: init-db.sh
# Description: Initialise la base de données SQLite du catalogue
# Usage: ./init-db.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/scripts_catalogue.db"
SCHEMA_FILE="$SCRIPT_DIR/schema.sql"

echo "🗄️  Initialisation de la base de données du catalogue"
echo "=================================================="

# Vérifier que SQLite3 est installé
if ! command -v sqlite3 &> /dev/null; then
    echo "❌ Erreur: sqlite3 n'est pas installé"
    echo "   Installer avec: sudo apt-get install sqlite3"
    exit 1
fi

# Vérifier que le fichier schema existe
if [[ ! -f "$SCHEMA_FILE" ]]; then
    echo "❌ Erreur: Fichier schema.sql non trouvé"
    exit 1
fi

# Backup de la DB existante si elle existe
if [[ -f "$DB_FILE" ]]; then
    BACKUP_FILE="${DB_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
    echo "📦 Backup de la base existante: $BACKUP_FILE"
    cp "$DB_FILE" "$BACKUP_FILE"
fi

# Créer/Recréer la base de données
echo "🔨 Création de la base de données..."
sqlite3 "$DB_FILE" < "$SCHEMA_FILE"

# Vérifier la création
if [[ $? -eq 0 ]]; then
    echo "✅ Base de données créée avec succès: $DB_FILE"
    
    # Afficher les tables créées
    echo ""
    echo "📋 Tables créées:"
    sqlite3 "$DB_FILE" ".tables"
    
    echo ""
    echo "📊 Statistiques:"
    echo "   - Tables: $(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")"
    echo "   - Vues: $(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='view';")"
    echo "   - Index: $(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%';")"
    
    echo ""
    echo "🎉 Initialisation terminée!"
    echo ""
    echo "Prochaines étapes:"
    echo "  1. Enregistrer vos scripts: ./tools/register-script.sh"
    echo "  2. Rechercher dans la DB: ./tools/search-db.sh"
    echo "  3. Consulter la doc: docs/database-schema.md"
else
    echo "❌ Erreur lors de la création de la base de données"
    exit 1
fi
```

**Rendre exécutable et lancer** :

```bash
chmod +x database/init-db.sh
./database/init-db.sh
```

---

## 3. Enregistrement des Scripts dans la Base

### 3.1 Script d'enregistrement automatique

**Créer le fichier `tools/register-script.sh`** :

```bash
#!/bin/bash
#
# Script: register-script.sh
# Description: Enregistre un script dans la base de données du catalogue
# Usage: ./register-script.sh <chemin_script>
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"

# Vérifier les arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <chemin_script>"
    echo "Exemple: $0 atomics/detect-usb.sh"
    exit 1
fi

SCRIPT_PATH=$1

# Vérifier que le script existe
if [[ ! -f "$PROJECT_ROOT/$SCRIPT_PATH" ]]; then
    echo "❌ Erreur: Script non trouvé: $SCRIPT_PATH"
    exit 1
fi

SCRIPT_NAME=$(basename "$SCRIPT_PATH")

echo "📝 Enregistrement du script: $SCRIPT_NAME"
echo "=================================================="

# Parser les informations du script (en-tête)
parse_script_header() {
    local script="$1"
    
    # Extraire la description
    DESCRIPTION=$(grep "^# Description:" "$script" | head -1 | sed 's/^# Description: //')
    
    # Extraire le type (atomic ou orchestrator)
    if [[ "$script" =~ /atomics/ ]]; then
        TYPE="atomic"
    elif [[ "$script" =~ /orchestrators/level-1/ ]]; then
        TYPE="orchestrator-1"
    elif [[ "$script" =~ /orchestrators/level-2/ ]]; then
        TYPE="orchestrator-2"
    elif [[ "$script" =~ /orchestrators/level-3/ ]]; then
        TYPE="orchestrator-3"
    else
        TYPE="atomic"
    fi
    
    # Déterminer la catégorie selon le nom
    case $SCRIPT_NAME in
        detect-*|list-*|get-*|check-*) CATEGORY="information" ;;
        format-*|mount-*|partition-*) CATEGORY="storage" ;;
        start-*|stop-*|restart-*|enable-*|disable-*) CATEGORY="services" ;;
        create-*|delete-*|set-*) CATEGORY="management" ;;
        backup-*|restore-*) CATEGORY="backup" ;;
        test-*|benchmark-*) CATEGORY="testing" ;;
        install-*|remove-*|update-*) CATEGORY="packages" ;;
        *) CATEGORY="other" ;;
    esac
    
    # Extraire la version (si présente dans le changelog)
    VERSION="1.0.0"  # Défaut
    
    # Chemin de la documentation
    DOC_PATH="${script%.sh}.md"
    DOC_PATH="${DOC_PATH/atomics/docs\/atomics}"
    DOC_PATH="${DOC_PATH/orchestrators/docs\/orchestrators}"
}

parse_script_header "$PROJECT_ROOT/$SCRIPT_PATH"

# Afficher les informations détectées
echo "Informations détectées:"
echo "  - Nom: $SCRIPT_NAME"
echo "  - Type: $TYPE"
echo "  - Catégorie: $CATEGORY"
echo "  - Description: $DESCRIPTION"
echo ""

# Demander confirmation
read -p "Enregistrer ce script dans la base? (o/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo "❌ Annulé"
    exit 0
fi

# Insérer dans la base
sqlite3 "$DB_FILE" <<EOF
INSERT OR REPLACE INTO scripts (
    name, type, category, description, path, version, documentation_path, status
) VALUES (
    '$SCRIPT_NAME',
    '$TYPE',
    '$CATEGORY',
    '$DESCRIPTION',
    '$SCRIPT_PATH',
    '$VERSION',
    '$DOC_PATH',
    'active'
);
EOF

if [[ $? -eq 0 ]]; then
    SCRIPT_ID=$(sqlite3 "$DB_FILE" "SELECT id FROM scripts WHERE name='$SCRIPT_NAME';")
    echo "✅ Script enregistré avec succès (ID: $SCRIPT_ID)"
    
    # Proposer d'enregistrer les paramètres
    echo ""
    read -p "Voulez-vous enregistrer les paramètres interactivement? (o/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        register_parameters "$SCRIPT_ID"
    fi
    
    # Proposer d'enregistrer les codes de sortie
    echo ""
    read -p "Voulez-vous enregistrer les codes de sortie? (o/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        register_exit_codes "$SCRIPT_ID"
    fi
else
    echo "❌ Erreur lors de l'enregistrement"
    exit 1
fi

# Fonction pour enregistrer les paramètres
register_parameters() {
    local script_id=$1
    echo ""
    echo "📝 Enregistrement des paramètres"
    echo "Entrez 'done' quand vous avez fini"
    
    while true; do
        echo ""
        read -p "Nom du paramètre (ou 'done'): " param_name
        [[ "$param_name" == "done" ]] && break
        
        read -p "Type (string/integer/boolean/path): " param_type
        read -p "Obligatoire? (o/N): " required
        [[ "$required" =~ ^[Oo]$ ]] && is_required=1 || is_required=0
        read -p "Valeur par défaut (ou vide): " default_val
        read -p "Description: " param_desc
        
        sqlite3 "$DB_FILE" <<EOSQL
INSERT INTO script_parameters (
    script_id, param_name, param_type, is_required, default_value, description
) VALUES (
    $script_id, '$param_name', '$param_type', $is_required, 
    $([ -n "$default_val" ] && echo "'$default_val'" || echo "NULL"), 
    '$param_desc'
);
EOSQL
        echo "  ✓ Paramètre '$param_name' enregistré"
    done
}

# Fonction pour enregistrer les codes de sortie
register_exit_codes() {
    local script_id=$1
    echo ""
    echo "📝 Enregistrement des codes de sortie"
    
    # Codes standards
    declare -A standard_codes=(
        [0]="EXIT_SUCCESS:Succès"
        [1]="EXIT_ERROR_GENERAL:Erreur générale"
        [2]="EXIT_ERROR_USAGE:Paramètres invalides"
        [3]="EXIT_ERROR_PERMISSION:Permissions insuffisantes"
        [4]="EXIT_ERROR_NOT_FOUND:Ressource non trouvée"
        [8]="EXIT_ERROR_VALIDATION:Erreur de validation"
    )
    
    for code in "${!standard_codes[@]}"; do
        IFS=':' read -r name desc <<< "${standard_codes[$code]}"
        read -p "Utilise le code $code ($desc)? (O/n): " use_code
        if [[ ! "$use_code" =~ ^[Nn]$ ]]; then
            sqlite3 "$DB_FILE" <<EOSQL
INSERT INTO exit_codes (script_id, exit_code, code_name, description)
VALUES ($script_id, $code, '$name', '$desc');
EOSQL
            echo "  ✓ Code $code enregistré"
        fi
    done
}

echo ""
echo "🎉 Enregistrement terminé!"
```

### 3.2 Script d'enregistrement en masse

**Créer le fichier `tools/register-all-scripts.sh`** :

```bash
#!/bin/bash
#
# Script: register-all-scripts.sh
# Description: Enregistre tous les scripts du projet dans la base
# Usage: ./register-all-scripts.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📚 Enregistrement en masse des scripts"
echo "=================================================="

# Compter les scripts
ATOMIC_COUNT=$(find "$PROJECT_ROOT/atomics" -name "*.sh" -not -name "template-*" 2>/dev/null | wc -l)
ORCH_COUNT=$(find "$PROJECT_ROOT/orchestrators" -name "*.sh" -not -name "template-*" 2>/dev/null | wc -l)
TOTAL=$((ATOMIC_COUNT + ORCH_COUNT))

echo "Scripts trouvés:"
echo "  - Atomiques: $ATOMIC_COUNT"
echo "  - Orchestrateurs: $ORCH_COUNT"
echo "  - Total: $TOTAL"
echo ""

read -p "Continuer l'enregistrement? (o/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    exit 0
fi

# Enregistrer les atomiques
echo ""
echo "📝 Enregistrement des scripts atomiques..."
find "$PROJECT_ROOT/atomics" -name "*.sh" -not -name "template-*" | while read -r script; do
    rel_path="${script#$PROJECT_ROOT/}"
    echo "  • $(basename "$script")"
    "$SCRIPT_DIR/register-script.sh" "$rel_path" <<< "o" > /dev/null 2>&1 || echo "    ⚠️  Erreur"
done

# Enregistrer les orchestrateurs
echo ""
echo "📝 Enregistrement des orchestrateurs..."
find "$PROJECT_ROOT/orchestrators" -name "*.sh" -not -name "template-*" | while read -r script; do
    rel_path="${script#$PROJECT_ROOT/}"
    echo "  • $(basename "$script")"
    "$SCRIPT_DIR/register-script.sh" "$rel_path" <<< "o" > /dev/null 2>&1 || echo "    ⚠️  Erreur"
done

echo ""
echo "✅ Enregistrement en masse terminé!"
```

---

## 4. Recherche et Consultation

### 4.1 Script de recherche

**Créer le fichier `tools/search-db.sh`** :

```bash
#!/bin/bash
#
# Script: search-db.sh
# Description: Recherche dans le catalogue de scripts
# Usage: ./search-db.sh [options]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"

# Fonction d'aide
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [TERM]

Options:
    -n, --name <pattern>        Recherche par nom
    -c, --category <cat>        Recherche par catégorie
    -t, --type <type>           Recherche par type (atomic, orchestrator-1, etc.)
    -T, --tag <tag>             Recherche par tag
    -d, --description <term>    Recherche dans les descriptions
    -a, --all                   Liste tous les scripts
    -s, --stats                 Affiche les statistiques
    -i, --info <name>           Détails complets d'un script
    -D, --dependencies <name>   Affiche les dépendances d'un script
    -h, --help                  Affiche cette aide

Exemples:
    $0 --name "detect-*"
    $0 --category storage
    $0 --type atomic
    $0 --tag backup
    $0 --info detect-usb.sh
    $0 --dependencies setup-disk.sh

EOF
}

# Fonction de recherche par nom
search_by_name() {
    local pattern=$1
    echo "🔍 Recherche par nom: $pattern"
    echo ""
    
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    name,
    type,
    category,
    substr(description, 1, 50) || '...' as description,
    status
FROM scripts
WHERE name LIKE '%$pattern%'
ORDER BY type, name;
EOF
}

# Fonction de recherche par catégorie
search_by_category() {
    local cat=$1
    echo "🔍 Scripts de la catégorie: $cat"
    echo ""
    
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    name,
    type,
    substr(description, 1, 60) as description
FROM scripts
WHERE category = '$cat'
ORDER BY type, name;
EOF
}

# Fonction pour afficher tous les scripts
list_all() {
    echo "📋 Tous les scripts"
    echo ""
    
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    name,
    type,
    category,
    status,
    version
FROM scripts
ORDER BY type, category, name;
EOF
}

# Fonction pour afficher les statistiques
show_stats() {
    echo "📊 Statistiques du catalogue"
    echo "==========================================="
    
    # Total de scripts
    local total=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM scripts;")
    echo "Total de scripts: $total"
    
    # Par type
    echo ""
    echo "Par type:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    type,
    COUNT(*) as count
FROM scripts
GROUP BY type
ORDER BY type;
EOF
    
    # Par catégorie
    echo ""
    echo "Par catégorie:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    category,
    COUNT(*) as count
FROM scripts
GROUP BY category
ORDER BY count DESC;
EOF
    
    # Par statut
    echo ""
    echo "Par statut:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    status,
    COUNT(*) as count
FROM scripts
GROUP BY status;
EOF
    
    # Avec le plus de dépendances
    echo ""
    echo "Top 5 scripts avec le plus de dépendances:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    name,
    dependency_count
FROM v_scripts_with_dep_count
ORDER BY dependency_count DESC
LIMIT 5;
EOF
} | grep -E '^(atomics|orchestrators)/')

if [[ -n "$ADDED_SCRIPTS" ]]; then
    echo "📝 Enregistrement des nouveaux scripts dans la base..."
    
    while IFS= read -r script; do
        if [[ -f "$PROJECT_ROOT/$script" ]]; then
            echo "  • $(basename "$script")"
            "$PROJECT_ROOT/tools/register-script.sh" "$script" <<< "o" > /dev/null 2>&1 || echo "    ⚠️  Erreur"
        fi
    done <<< "$ADDED_SCRIPTS"
fi
```

**Rendre exécutable** :

```bash
chmod +x .git/hooks/post-commit
```

---

## 11. Exemples d'Utilisation Complète

### 11.1 Workflow complet : Du développement à l'enregistrement

```bash
# 1. Créer un nouveau script
./tools/script-generator.sh atomic detect-network

# 2. Développer le script
nano atomics/detect-network.sh

# 3. Tester le script
./atomics/detect-network.sh --verbose

# 4. Enregistrer dans la base
./tools/register-script.sh atomics/detect-network.sh

# Répondre aux questions interactives :
# - Confirmer les informations détectées
# - Ajouter les paramètres
# - Définir les codes de sortie
# - Ajouter des exemples

# 5. Lier aux fonctions utilisées (si applicable)
./tools/link-script-functions.sh detect-network.sh

# 6. Vérifier l'enregistrement
./tools/search-db.sh --info detect-network.sh

# 7. Commit Git (auto-enregistrement via hook)
git add atomics/detect-network.sh
git commit -m "feat(atomics): add detect-network.sh"
```

### 11.2 Recherche et analyse

```bash
# Rechercher tous les scripts réseau
./tools/search-db.sh --category network

# Trouver les scripts qui utilisent une fonction spécifique
sqlite3 database/scripts_catalogue.db <<EOF
SELECT s.name, s.type
FROM scripts s
JOIN script_uses_functions suf ON s.id = suf.script_id
JOIN functions f ON suf.function_id = f.id
WHERE f.name = 'retry_execute';
EOF

# Analyser les dépendances d'un orchestrateur
./tools/search-db.sh --dependencies setup-monitoring.sh

# Voir les statistiques d'utilisation
./tools/search-db.sh --stats
```

### 11.3 Génération de rapports

```bash
# Export complet pour documentation
./tools/export-db.sh markdown

# Rapport des scripts deprecated
sqlite3 database/scripts_catalogue.db <<EOF
SELECT 
    name,
    type,
    'Deprecated depuis ' || 
    CAST((julianday('now') - julianday(updated_at)) AS INTEGER) || 
    ' jours' as info
FROM scripts
WHERE status = 'deprecated'
ORDER BY updated_at;
EOF

# Top 10 des scripts les plus utilisés
sqlite3 -column database/scripts_catalogue.db <<EOF
SELECT 
    s.name,
    SUM(us.execution_count) as total_exec
FROM scripts s
JOIN usage_stats us ON s.id = us.script_id
WHERE us.execution_date >= date('now', '-30 days')
GROUP BY s.id
ORDER BY total_exec DESC
LIMIT 10;
EOF
```

---

## 12. Bonnes Pratiques

### 12.1 Maintenance régulière

**Tâches quotidiennes** :
```bash
# Mettre à jour les statistiques
./tools/update-stats.sh

# Vérifier l'intégrité de la base
sqlite3 database/scripts_catalogue.db "PRAGMA integrity_check;"
```

**Tâches hebdomadaires** :
```bash
# Backup de la base
./tools/export-db.sh backup

# Vérifier les scripts sans documentation
sqlite3 database/scripts_catalogue.db "SELECT name FROM scripts WHERE documentation_path IS NULL;"

# Nettoyer les vieilles stats (> 90 jours)
sqlite3 database/scripts_catalogue.db "DELETE FROM usage_stats WHERE execution_date < date('now', '-90 days');"
```

**Tâches mensuelles** :
```bash
# Export complet
./tools/export-db.sh all

# Analyser les scripts jamais utilisés
sqlite3 database/scripts_catalogue.db <<EOF
SELECT s.name, s.type, s.created_at
FROM scripts s
LEFT JOIN usage_stats us ON s.id = us.script_id
WHERE us.id IS NULL
ORDER BY s.created_at;
EOF

# Optimiser la base
sqlite3 database/scripts_catalogue.db "VACUUM; ANALYZE;"
```

### 12.2 Standards d'enregistrement

**Checklist avant d'enregistrer un script** :

- [ ] Le script est fonctionnel et testé
- [ ] La documentation .md est créée
- [ ] Le script suit les conventions de nommage
- [ ] Tous les paramètres sont documentés
- [ ] Les codes de sortie sont définis
- [ ] Les dépendances sont identifiées
- [ ] Au moins un exemple d'utilisation existe
- [ ] Le script est dans Git

### 12.3 Cohérence des données

**Vérifications à effectuer régulièrement** :

```bash
# Scripts référencés mais fichiers manquants
sqlite3 database/scripts_catalogue.db <<EOF
SELECT name, path
FROM scripts
WHERE NOT EXISTS (
    SELECT 1 FROM pragma_table_info('scripts')
);
EOF

# Dépendances vers des scripts inexistants
sqlite3 database/scripts_catalogue.db <<EOF
SELECT s.name as script, sd.depends_on_script_id
FROM scripts s
JOIN script_dependencies sd ON s.id = sd.script_id
WHERE sd.depends_on_script_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM scripts WHERE id = sd.depends_on_script_id
  );
EOF
```

---

## 13. Conclusion

### 13.1 Résumé de l'installation

Vous avez maintenant :

✅ **Une base SQLite3 installée et configurée**  
✅ **Un schéma complet avec 15+ tables**  
✅ **Des outils d'enregistrement et de recherche**  
✅ **Des scripts de maintenance et d'export**  
✅ **Des requêtes SQL prêtes à l'emploi**  
✅ **Une interface web optionnelle**  
✅ **Un système d'intégration avec Git**  

### 13.2 Flux de travail recommandé

```
1. Développer script → 2. Tester → 3. Enregistrer dans DB
                                          ↓
4. Commit Git ← 5. Documenter ← 6. Lier fonctions
                                          ↓
7. Utiliser/Composer → 8. Statistiques → 9. Maintenance
```

### 13.3 Avantages de cette approche

**Pour le développeur** :
- Recherche rapide de scripts existants
- Évite la duplication de code
- Comprend rapidement les dépendances
- Accès aux exemples d'utilisation

**Pour l'équipe** :
- Base de connaissance centralisée
- Documentation toujours à jour
- Visibilité sur ce qui existe
- Facilite l'onboarding

**Pour le projet** :
- Traçabilité complète
- Statistiques d'utilisation
- Identification des scripts obsolètes
- Facilite la maintenance

### 13.4 Évolutions possibles

**Court terme** :
- Ajouter plus de requêtes prédéfinies
- Améliorer l'interface web
- Intégration CI/CD

**Moyen terme** :
- API REST pour accès programmatique
- Dashboard de monitoring en temps réel
- Génération automatique de documentation

**Long terme** :
- Machine learning pour recommandations
- Détection automatique de patterns
- Analyse de complexité automatique

---

## Annexes

### A. Commandes SQLite Utiles

```bash
# Ouvrir la base en mode interactif
sqlite3 database/scripts_catalogue.db

# Mode colonne pour affichage lisible
.mode column
.headers on

# Lister toutes les tables
.tables

# Afficher le schéma d'une table
.schema scripts

# Export CSV
.mode csv
.output export.csv
SELECT * FROM scripts;
.output stdout

# Afficher les index
.indexes

# Statistiques de la base
.dbinfo
```

### B. Structure des Fichiers

```
projet/
├── database/
│   ├── scripts_catalogue.db          # ← Base SQLite
│   ├── schema.sql                    # ← Schéma
│   ├── init-db.sh                    # ← Initialisation
│   ├── migrate-db.sh                 # ← Migrations
│   └── queries/
│       └── common-queries.sql        # ← Requêtes
├── tools/
│   ├── register-script.sh            # ← Enregistrement
│   ├── register-all-scripts.sh       # ← Enregistrement masse
│   ├── register-function.sh          # ← Enregistrement fonctions
│   ├── link-script-functions.sh      # ← Liaison
│   ├── search-db.sh                  # ← Recherche
│   ├── export-db.sh                  # ← Export
│   └── update-stats.sh               # ← Mise à jour stats
├── web/
│   └── index.php                     # ← Interface web
└── exports/                          # ← Exports générés
```

### C. Ressources

**Documentation SQLite** :
- https://www.sqlite.org/docs.html
- https://www.sqlite.org/lang.html

**Outils** :
- DB Browser for SQLite : https://sqlitebrowser.org/
- SQLite CLI : Fourni avec sqlite3

**Tutoriels** :
- SQL pour SQLite : https://www.sqlitetutorial.net/

---

**Version du document** : 1.0  
**Date** : 2025-10-03  
**Compatibilité** : SQLite 3.35.0+

**La base de données est maintenant opérationnelle ! 🎉**    echo "Par type:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    type,
    COUNT(*) as count
FROM scripts
GROUP BY type
ORDER BY type;
EOF
    
    # Par catégorie
    echo ""
    echo "Par catégorie:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    category,
    COUNT(*) as count
FROM scripts
GROUP BY category
ORDER BY count DESC;
EOF
    
    # Par statut
    echo ""
    echo "Par statut:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    status,
    COUNT(*) as count
FROM scripts
GROUP BY status;
EOF
    
    # Avec le plus de dépendances
    echo ""
    echo "Top 5 scripts avec le plus de dépendances:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    name,
    dependency_count
FROM v_scripts_with_dep_count
ORDER BY dependency_count DESC
LIMIT 5;
EOF
}

# Fonction pour afficher les détails d'un script
show_script_info() {
    local script_name=$1
    
    echo "📄 Détails du script: $script_name"
    echo "==========================================="
    
    # Informations générales
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    'Nom:' as field, name as value FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Type:', type FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Catégorie:', category FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Version:', version FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Statut:', status FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Chemin:', path FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Documentation:', documentation_path FROM scripts WHERE name = '$script_name';
EOF
    
    echo ""
    echo "Description:"
    sqlite3 "$DB_FILE" "SELECT description FROM scripts WHERE name = '$script_name';"
    
    # Paramètres
    echo ""
    echo "Paramètres d'entrée:"
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    param_name as Parametre,
    param_type as Type,
    CASE WHEN is_required = 1 THEN 'Oui' ELSE 'Non' END as Obligatoire,
    COALESCE(default_value, '-') as Defaut,
    description as Description
FROM script_parameters
WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name')
ORDER BY position, param_name;
EOF
    
    # Sorties
    echo ""
    echo "Champs de sortie (JSON):"
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    output_field as Champ,
    field_type as Type,
    description as Description
FROM script_outputs
WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name')
ORDER BY parent_field, output_field;
EOF
    
    # Codes de sortie
    echo ""
    echo "Codes de sortie:"
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    exit_code as Code,
    code_name as Nom,
    description as Description
FROM exit_codes
WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name')
ORDER BY exit_code;
EOF
    
    # Dépendances
    echo ""
    echo "Dépendances:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    dependency_type || ': ' || 
    COALESCE(
        (SELECT name FROM scripts WHERE id = depends_on_script_id),
        depends_on_command,
        depends_on_library,
        depends_on_package
    ) as dependance
FROM script_dependencies
WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name');
EOF
    
    # Tags
    echo ""
    echo "Tags:"
    sqlite3 "$DB_FILE" "SELECT GROUP_CONCAT(tag, ', ') FROM script_tags WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name');"
    
    # Exemples
    echo ""
    echo "Exemples d'utilisation:"
    sqlite3 "$DB_FILE" <<EOF
SELECT 
    example_title || ':
    ' || example_command || '
    
' as exemple
FROM script_examples
WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name');
EOF
}

# Fonction pour afficher le graphe de dépendances
show_dependencies() {
    local script_name=$1
    
    echo "🔗 Dépendances de: $script_name"
    echo "==========================================="
    
    # Dépendances directes
    echo ""
    echo "Dépend de (niveau 1):"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    depends_on as Script,
    CASE WHEN is_optional = 1 THEN 'Optionnel' ELSE 'Obligatoire' END as Type
FROM v_dependency_graph
WHERE script_name = '$script_name';
EOF
    
    # Scripts qui dépendent de celui-ci
    echo ""
    echo "Scripts qui dépendent de $script_name:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    script_name as Script,
    script_type as Type
FROM v_dependency_graph
WHERE depends_on = '$script_name';
EOF
}

# Parsing des arguments
case ${1:-} in
    -n|--name)
        search_by_name "$2"
        ;;
    -c|--category)
        search_by_category "$2"
        ;;
    -t|--type)
        TYPE=$2
        sqlite3 -header -column "$DB_FILE" "SELECT name, category, description FROM scripts WHERE type = '$TYPE' ORDER BY name;"
        ;;
    -T|--tag)
        TAG=$2
        echo "🔍 Scripts avec le tag: $TAG"
        sqlite3 -header -column "$DB_FILE" <<EOF
SELECT s.name, s.type, s.category
FROM scripts s
JOIN script_tags st ON s.id = st.script_id
WHERE st.tag = '$TAG'
ORDER BY s.name;
EOF
        ;;
    -d|--description)
        TERM=$2
        echo "🔍 Recherche dans les descriptions: $TERM"
        sqlite3 -header -column "$DB_FILE" "SELECT name, type, description FROM scripts WHERE description LIKE '%$TERM%' OR long_description LIKE '%$TERM%';"
        ;;
    -a|--all)
        list_all
        ;;
    -s|--stats)
        show_stats
        ;;
    -i|--info)
        show_script_info "$2"
        ;;
    -D|--dependencies)
        show_dependencies "$2"
        ;;
    -h|--help)
        show_help
        ;;
    "")
        show_help
        ;;
    *)
        echo "Option inconnue: $1"
        show_help
        exit 1
        ;;
esac
```

**Rendre exécutable** :

```bash
chmod +x tools/search-db.sh
```

### 4.2 Exemples d'utilisation

```bash
# Lister tous les scripts
./tools/search-db.sh --all

# Rechercher par nom
./tools/search-db.sh --name "detect-*"
./tools/search-db.sh --name "backup"

# Rechercher par catégorie
./tools/search-db.sh --category storage
./tools/search-db.sh --category network

# Rechercher par type
./tools/search-db.sh --type atomic
./tools/search-db.sh --type orchestrator-1

# Voir les détails d'un script
./tools/search-db.sh --info detect-usb.sh
./tools/search-db.sh --info setup-disk.sh

# Voir les dépendances
./tools/search-db.sh --dependencies setup-disk.sh

# Voir les statistiques
./tools/search-db.sh --stats

# Rechercher par tag
./tools/search-db.sh --tag backup
./tools/search-db.sh --tag security
```

---

## 5. Gestion des Fonctions (Bibliothèques)

### 5.1 Enregistrement des fonctions

**Créer le fichier `tools/register-function.sh`** :

```bash
#!/bin/bash
#
# Script: register-function.sh
# Description: Enregistre une fonction de bibliothèque dans la base
# Usage: ./register-function.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"

echo "📚 Enregistrement d'une fonction"
echo "=================================================="

# Demander les informations
read -p "Nom de la fonction: " func_name
read -p "Fichier bibliothèque (ex: lib/cache.sh): " lib_file
read -p "Catégorie (cache, retry, notification, etc.): " category
read -p "Description: " description
read -p "Paramètres (ex: \$1=key, \$2=value): " parameters
read -p "Valeur de retour: " return_value
read -p "Exemple d'utilisation: " example

# Insérer dans la base
sqlite3 "$DB_FILE" <<EOF
INSERT INTO functions (
    name, library_file, category, description, 
    parameters, return_value, example_usage
) VALUES (
    '$func_name',
    '$lib_file',
    '$category',
    '$description',
    '$parameters',
    '$return_value',
    '$example'
);
EOF

if [[ $? -eq 0 ]]; then
    echo "✅ Fonction enregistrée: $func_name"
else
    echo "❌ Erreur lors de l'enregistrement"
fi
```

### 5.2 Lier un script à des fonctions

**Créer le fichier `tools/link-script-functions.sh`** :

```bash
#!/bin/bash
#
# Script: link-script-functions.sh
# Description: Lie un script aux fonctions qu'il utilise
# Usage: ./link-script-functions.sh <script_name>
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"

SCRIPT_NAME=$1

# Récupérer l'ID du script
SCRIPT_ID=$(sqlite3 "$DB_FILE" "SELECT id FROM scripts WHERE name = '$SCRIPT_NAME';")

if [[ -z "$SCRIPT_ID" ]]; then
    echo "❌ Script non trouvé: $SCRIPT_NAME"
    exit 1
fi

echo "🔗 Liaison de fonctions pour: $SCRIPT_NAME"
echo "=================================================="

# Lister les fonctions disponibles
echo ""
echo "Fonctions disponibles:"
sqlite3 -column "$DB_FILE" "SELECT id, name, library_file FROM functions ORDER BY library_file, name;"

echo ""
echo "Entrez les IDs des fonctions utilisées (séparés par des espaces, 'done' pour terminer):"

while true; do
    read -p "ID fonction (ou 'done'): " func_id
    [[ "$func_id" == "done" ]] && break
    
    # Vérifier que la fonction existe
    FUNC_EXISTS=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM functions WHERE id = $func_id;")
    if [[ "$FUNC_EXISTS" -eq 0 ]]; then
        echo "⚠️  Fonction ID $func_id non trouvée"
        continue
    fi
    
    # Lier
    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO script_uses_functions (script_id, function_id) VALUES ($SCRIPT_ID, $func_id);" 2>/dev/null
    
    FUNC_NAME=$(sqlite3 "$DB_FILE" "SELECT name FROM functions WHERE id = $func_id;")
    echo "  ✓ Lié à: $FUNC_NAME"
done

echo ""
echo "✅ Liaison terminée!"
```

---

## 6. Requêtes SQL Utiles

### 6.1 Fichier de requêtes prédéfinies

**Créer le fichier `database/queries/common-queries.sql`** :

```sql
-- ============================================================================
-- REQUETES SQL COMMUNES POUR LE CATALOGUE DE SCRIPTS
-- ============================================================================

-- 1. Liste tous les scripts atomiques actifs
-- Usage: sqlite3 scripts_catalogue.db < queries/common-queries.sql
SELECT name, category, description
FROM scripts
WHERE type = 'atomic' AND status = 'active'
ORDER BY category, name;

-- 2. Scripts avec leurs dépendances (graphe complet)
SELECT 
    s1.name as script,
    s1.type,
    GROUP_CONCAT(
        COALESCE(s2.name, sd.depends_on_command, sd.depends_on_library),
        ', '
    ) as dependencies
FROM scripts s1
LEFT JOIN script_dependencies sd ON s1.id = sd.script_id
LEFT JOIN scripts s2 ON sd.depends_on_script_id = s2.id
GROUP BY s1.id
ORDER BY s1.name;

-- 3. Scripts par catégorie avec comptage
SELECT 
    category,
    COUNT(*) as total_scripts,
    SUM(CASE WHEN type = 'atomic' THEN 1 ELSE 0 END) as atomiques,
    SUM(CASE WHEN type LIKE 'orchestrator%' THEN 1 ELSE 0 END) as orchestrateurs
FROM scripts
WHERE status = 'active'
GROUP BY category
ORDER BY total_scripts DESC;

-- 4. Scripts deprecated à supprimer
SELECT 
    name,
    type,
    category,
    version,
    updated_at,
    julianday('now') - julianday(updated_at) as jours_depuis_maj
FROM scripts
WHERE status = 'deprecated'
ORDER BY updated_at;

-- 5. Orchestrateurs et leurs scripts atomiques
SELECT 
    s1.name as orchestrateur,
    s1.type as niveau,
    s2.name as script_atomique
FROM scripts s1
JOIN script_dependencies sd ON s1.id = sd.script_id
JOIN scripts s2 ON sd.depends_on_script_id = s2.id
WHERE s1.type LIKE 'orchestrator%' 
  AND s2.type = 'atomic'
ORDER BY s1.name, s2.name;

-- 6. Scripts sans documentation
SELECT 
    name,
    type,
    category,
    path
FROM scripts
WHERE documentation_path IS NULL 
   OR documentation_path = ''
ORDER BY type, name;

-- 7. Fonctions par bibliothèque
SELECT 
    library_file,
    COUNT(*) as nb_fonctions,
    GROUP_CONCAT(name, ', ') as fonctions
FROM functions
WHERE status = 'active'
GROUP BY library_file
ORDER BY nb_fonctions DESC;

-- 8. Scripts utilisant une fonction spécifique
-- Remplacer 'cache_get' par la fonction recherchée
SELECT 
    s.name,
    s.type,
    s.category
FROM scripts s
JOIN script_uses_functions suf ON s.id = suf.script_id
JOIN functions f ON suf.function_id = f.id
WHERE f.name = 'cache_get'
ORDER BY s.type, s.name;

-- 9. Scripts les plus complexes (plus de dépendances)
SELECT 
    name,
    type,
    dependency_count,
    category
FROM v_scripts_with_dep_count
WHERE dependency_count > 0
ORDER BY dependency_count DESC
LIMIT 20;

-- 10. Scripts jamais testés
SELECT 
    name,
    type,
    category,
    created_at,
    last_tested
FROM scripts
WHERE last_tested IS NULL
ORDER BY created_at;

-- 11. Statistiques d'utilisation des derniers 7 jours
SELECT 
    s.name,
    s.type,
    SUM(us.execution_count) as executions,
    SUM(us.success_count) as success,
    SUM(us.error_count) as errors,
    ROUND(AVG(us.average_duration_ms), 2) as avg_duration_ms
FROM scripts s
JOIN usage_stats us ON s.id = us.script_id
WHERE us.execution_date >= date('now', '-7 days')
GROUP BY s.id
ORDER BY executions DESC
LIMIT 20;

-- 12. Scripts avec paramètres obligatoires
SELECT 
    s.name,
    s.type,
    COUNT(sp.id) as nb_params_obligatoires,
    GROUP_CONCAT(sp.param_name, ', ') as parametres
FROM scripts s
JOIN script_parameters sp ON s.id = sp.script_id
WHERE sp.is_required = 1
GROUP BY s.id
ORDER BY nb_params_obligatoires DESC;

-- 13. Export CSV de tous les scripts
.mode csv
.headers on
.output scripts_export.csv
SELECT 
    name,
    type,
    category,
    status,
    version,
    description,
    path
FROM scripts
ORDER BY type, category, name;
.output stdout

-- 14. Recherche full-text dans descriptions
-- Remplacer 'backup' par votre terme de recherche
SELECT 
    name,
    type,
    category,
    description
FROM scripts
WHERE description LIKE '%backup%'
   OR long_description LIKE '%backup%'
ORDER BY type, name;

-- 15. Scripts par auteur
SELECT 
    author,
    COUNT(*) as nb_scripts,
    GROUP_CONCAT(DISTINCT type) as types
FROM scripts
WHERE author IS NOT NULL
GROUP BY author
ORDER BY nb_scripts DESC;
```

### 6.2 Utilisation des requêtes

```bash
# Exécuter une requête spécifique
sqlite3 database/scripts_catalogue.db < database/queries/common-queries.sql

# Ou en interactif
sqlite3 database/scripts_catalogue.db

# Dans SQLite interactif
sqlite> .read database/queries/common-queries.sql

# Export CSV
sqlite3 -csv -header database/scripts_catalogue.db "SELECT * FROM scripts;" > scripts.csv
```

---

## 7. Export et Backup

### 7.1 Script d'export

**Créer le fichier `tools/export-db.sh`** :

```bash
#!/bin/bash
#
# Script: export-db.sh
# Description: Exporte la base de données dans différents formats
# Usage: ./export-db.sh [format]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"
EXPORT_DIR="$PROJECT_ROOT/exports"

mkdir -p "$EXPORT_DIR"

FORMAT=${1:-all}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "📤 Export de la base de données"
echo "=================================================="

# Export SQL (dump complet)
export_sql() {
    local output="$EXPORT_DIR/catalogue_${TIMESTAMP}.sql"
    echo "Exportation SQL..."
    sqlite3 "$DB_FILE" .dump > "$output"
    echo "  ✓ SQL: $output"
}

# Export CSV de chaque table
export_csv() {
    echo "Exportation CSV..."
    local csv_dir="$EXPORT_DIR/csv_${TIMESTAMP}"
    mkdir -p "$csv_dir"
    
    # Liste des tables
    local tables=$(sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    
    for table in $tables; do
        sqlite3 -header -csv "$DB_FILE" "SELECT * FROM $table;" > "$csv_dir/${table}.csv"
        echo "  ✓ CSV: ${table}.csv"
    done
}

# Export JSON
export_json() {
    echo "Exportation JSON..."
    local json_file="$EXPORT_DIR/catalogue_${TIMESTAMP}.json"
    
    sqlite3 "$DB_FILE" <<EOF | python3 -m json.tool > "$json_file"
SELECT json_object(
    'export_date', datetime('now'),
    'version', '1.0',
    'scripts', (
        SELECT json_group_array(
            json_object(
                'name', name,
                'type', type,
                'category', category,
                'description', description,
                'version', version,
                'status', status
            )
        )
        FROM scripts
    ),
    'functions', (
        SELECT json_group_array(
            json_object(
                'name', name,
                'library', library_file,
                'description', description
            )
        )
        FROM functions
    )
);
EOF
    
    echo "  ✓ JSON: $json_file"
}

# Export Markdown (documentation)
export_markdown() {
    echo "Exportation Markdown..."
    local md_file="$EXPORT_DIR/catalogue_${TIMESTAMP}.md"
    
    cat > "$md_file" <<EOF
# Catalogue de Scripts
Généré le: $(date)

## Scripts Atomiques

EOF
    
    sqlite3 "$DB_FILE" "SELECT '### ' || name || char(10) || char(10) || '**Description:** ' || description || char(10) || char(10) FROM scripts WHERE type='atomic' ORDER BY category, name;" >> "$md_file"
    
    cat >> "$md_file" <<EOF

## Orchestrateurs

EOF
    
    sqlite3 "$DB_FILE" "SELECT '### ' || name || char(10) || char(10) || '**Description:** ' || description || char(10) || '**Niveau:** ' || type || char(10) || char(10) FROM scripts WHERE type LIKE 'orchestrator%' ORDER BY type, name;" >> "$md_file"
    
    echo "  ✓ Markdown: $md_file"
}

# Backup complet (copie de la DB)
backup_db() {
    echo "Backup de la base..."
    local backup_file="$EXPORT_DIR/backup_${TIMESTAMP}.db"
    cp "$DB_FILE" "$backup_file"
    echo "  ✓ Backup: $backup_file"
}

# Exécution selon le format
case $FORMAT in
    sql)
        export_sql
        ;;
    csv)
        export_csv
        ;;
    json)
        export_json
        ;;
    markdown|md)
        export_markdown
        ;;
    backup)
        backup_db
        ;;
    all)
        export_sql
        export_csv
        export_json
        export_markdown
        backup_db
        ;;
    *)
        echo "Format inconnu: $FORMAT"
        echo "Formats disponibles: sql, csv, json, markdown, backup, all"
        exit 1
        ;;
esac

echo ""
echo "✅ Export terminé!"
echo "   Répertoire: $EXPORT_DIR"
```

### 7.2 Automatisation des backups

**Créer un cron job** :

```bash
# Editer crontab
crontab -e

# Ajouter une ligne pour backup quotidien à 2h du matin
0 2 * * * /chemin/vers/projet/tools/export-db.sh backup >> /var/log/db-backup.log 2>&1
```

---

## 8. Interface Web (Optionnel)

### 8.1 Serveur Web Simple avec PHP

**Créer le fichier `web/index.php`** :

```php
<?php
// Interface web simple pour consulter le catalogue
$db_path = __DIR__ . '/../database/scripts_catalogue.db';
$db = new SQLite3($db_path);

// Récupérer tous les scripts
$query = "SELECT name, type, category, description, status FROM scripts ORDER BY type, category, name";
$results = $db->query($query);

$scripts = [];
while ($row = $results->fetchArray(SQLITE3_ASSOC)) {
    $scripts[] = $row;
}

// Statistiques
$stats_query = "SELECT 
    COUNT(*) as total,
    SUM(CASE WHEN type = 'atomic' THEN 1 ELSE 0 END) as atomiques,
    SUM(CASE WHEN type LIKE 'orchestrator%' THEN 1 ELSE 0 END) as orchestrateurs
FROM scripts WHERE status = 'active'";
$stats = $db->querySingle($stats_query, true);

?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Catalogue de Scripts</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            padding: 20px;
            background: #f5f5f5;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        header { 
            background: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 { color: #333; margin-bottom: 10px; }
        .stats { 
            display: flex;
            gap: 20px;
            margin-top: 20px;
        }
        .stat-card {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            flex: 1;
        }
        .stat-number { font-size: 32px; font-weight: bold; color: #007bff; }
        .stat-label { color: #666; margin-top: 5px; }
        
        .search-box {
            background: white;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        input[type="text"] {
            width: 100%;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 6px;
            font-size: 16px;
        }
        
        .scripts-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
            gap: 20px;
        }
        .script-card {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .script-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0,0,0,0.15);
        }
        .script-name {
            font-size: 18px;
            font-weight: 600;
            color: #333;
            margin-bottom: 8px;
        }
        .script-meta {
            display: flex;
            gap: 10px;
            margin-bottom: 12px;
        }
        .badge {
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 500;
        }
        .badge-atomic { background: #e3f2fd; color: #1976d2; }
        .badge-orchestrator { background: #f3e5f5; color: #7b1fa2; }
        .badge-category { background: #fff3e0; color: #f57c00; }
        .script-description {
            color: #666;
            line-height: 1.6;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📚 Catalogue de Scripts</h1>
            <p style="color: #666;">Base de données de scripts et fonctions</p>
            
            <div class="stats">
                <div class="stat-card">
                    <div class="stat-number"><?= $stats['total'] ?></div>
                    <div class="stat-label">Total Scripts</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number"><?= $stats['atomiques'] ?></div>
                    <div class="stat-label">Atomiques</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number"><?= $stats['orchestrateurs'] ?></div>
                    <div class="stat-label">Orchestrateurs</div>
                </div>
            </div>
        </header>
        
        <div class="search-box">
            <input type="text" id="searchInput" placeholder="🔍 Rechercher un script..." onkeyup="filterScripts()">
        </div>
        
        <div class="scripts-grid" id="scriptsGrid">
            <?php foreach ($scripts as $script): ?>
            <div class="script-card" data-name="<?= htmlspecialchars($script['name']) ?>" data-category="<?= htmlspecialchars($script['category']) ?>">
                <div class="script-name"><?= htmlspecialchars($script['name']) ?></div>
                <div class="script-meta">
                    <span class="badge <?= $script['type'] === 'atomic' ? 'badge-atomic' : 'badge-orchestrator' ?>">
                        <?= htmlspecialchars($script['type']) ?>
                    </span>
                    <span class="badge badge-category"><?= htmlspecialchars($script['category']) ?></span>
                </div>
                <div class="script-description">
                    <?= htmlspecialchars($script['description']) ?>
                </div>
            </div>
            <?php endforeach; ?>
        </div>
    </div>
    
    <script>
        function filterScripts() {
            const input = document.getElementById('searchInput');
            const filter = input.value.toLowerCase();
            const cards = document.getElementsByClassName('script-card');
            
            for (let card of cards) {
                const name = card.dataset.name.toLowerCase();
                const category = card.dataset.category.toLowerCase();
                const text = card.textContent.toLowerCase();
                
                if (name.includes(filter) || category.includes(filter) || text.includes(filter)) {
                    card.style.display = '';
                } else# Base de Données SQLite - Catalogue de Scripts et Fonctions

## Introduction

Ce document explique comment installer, configurer et utiliser une base de données SQLite3 pour référencer tous les scripts et fonctions développés selon la méthodologie. Cette base permet de :

- 📋 Cataloguer tous les scripts atomiques et orchestrateurs
- 🔍 Rechercher rapidement des scripts par nom, catégorie, fonction
- 📊 Suivre les dépendances entre scripts
- 📝 Documenter les entrées/sorties de chaque script
- 🔄 Gérer les versions et l'évolution
- 📈 Analyser l'utilisation et les statistiques

---

## 1. Installation de SQLite3

### 1.1 Installation sur différentes distributions

#### Debian/Ubuntu
```bash
sudo apt-get update
sudo apt-get install -y sqlite3 libsqlite3-dev
```

#### RHEL/CentOS/Fedora
```bash
sudo yum install -y sqlite sqlite-devel
# ou
sudo dnf install -y sqlite sqlite-devel
```

#### Arch Linux
```bash
sudo pacman -S sqlite
```

#### Alpine Linux
```bash
apk add sqlite sqlite-dev
```

### 1.2 Vérification de l'installation

```bash
# Vérifier la version
sqlite3 --version

# Test rapide
sqlite3 test.db "SELECT 'Installation OK';"
rm test.db
```

**Version recommandée** : SQLite 3.35.0 ou supérieur

---

## 2. Création de la Base de Données

### 2.1 Structure du projet

```
projet/
├── database/
│   ├── scripts_catalogue.db       # Base de données principale
│   ├── schema.sql                 # Schéma de la base
│   ├── init-db.sh                 # Script d'initialisation
│   ├── migrate-db.sh              # Script de migration
│   └── queries/                   # Requêtes SQL prédéfinies
│       ├── search-script.sql
│       ├── list-dependencies.sql
│       └── stats.sql
├── tools/
│   ├── register-script.sh         # Enregistre un script dans la DB
│   ├── search-db.sh               # Recherche dans la DB
│   └── export-db.sh               # Export de la DB
└── docs/
    └── database-schema.md         # Documentation du schéma
```

### 2.2 Schéma de la base de données

**Créer le fichier `database/schema.sql`** :

```sql
-- ============================================================================
-- SCHEMA DE LA BASE DE DONNEES - CATALOGUE DE SCRIPTS
-- Version: 1.0
-- Date: 2025-10-03
-- ============================================================================

-- Table principale des scripts
CREATE TABLE IF NOT EXISTS scripts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,              -- Nom du script (ex: detect-usb.sh)
    type TEXT NOT NULL,                      -- Type: atomic, orchestrator-1, orchestrator-2, etc.
    category TEXT NOT NULL,                  -- Catégorie (système, réseau, etc.)
    subcategory TEXT,                        -- Sous-catégorie (optionnel)
    description TEXT NOT NULL,               -- Description courte
    long_description TEXT,                   -- Description longue
    path TEXT NOT NULL,                      -- Chemin relatif du script
    version TEXT NOT NULL DEFAULT '1.0.0',  -- Version sémantique
    status TEXT NOT NULL DEFAULT 'active',  -- active, deprecated, obsolete
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_tested DATETIME,                    -- Dernière date de test
    author TEXT,                             -- Auteur du script
    maintainer TEXT,                         -- Mainteneur actuel
    documentation_path TEXT,                 -- Chemin vers la doc .md
    
    CHECK (type IN ('atomic', 'orchestrator-1', 'orchestrator-2', 'orchestrator-3', 'orchestrator-4', 'orchestrator-5')),
    CHECK (status IN ('active', 'deprecated', 'obsolete', 'development'))
);

-- Index pour recherches rapides
CREATE INDEX idx_scripts_name ON scripts(name);
CREATE INDEX idx_scripts_type ON scripts(type);
CREATE INDEX idx_scripts_category ON scripts(category);
CREATE INDEX idx_scripts_status ON scripts(status);

-- Table des paramètres d'entrée
CREATE TABLE IF NOT EXISTS script_parameters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    param_name TEXT NOT NULL,               -- Nom du paramètre
    param_type TEXT NOT NULL,               -- Type: string, integer, boolean, path, etc.
    is_required BOOLEAN NOT NULL DEFAULT 0, -- Obligatoire ou optionnel
    default_value TEXT,                     -- Valeur par défaut
    description TEXT NOT NULL,              -- Description du paramètre
    validation_rule TEXT,                   -- Règle de validation (regex, range, etc.)
    example_value TEXT,                     -- Exemple de valeur
    position INTEGER,                       -- Position dans la liste des paramètres
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, param_name)
);

CREATE INDEX idx_params_script ON script_parameters(script_id);

-- Table des sorties
CREATE TABLE IF NOT EXISTS script_outputs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    output_field TEXT NOT NULL,             -- Champ dans le JSON de sortie
    field_type TEXT NOT NULL,               -- Type: string, integer, array, object, boolean
    description TEXT NOT NULL,              -- Description du champ
    is_always_present BOOLEAN DEFAULT 1,    -- Toujours présent ou conditionnel
    example_value TEXT,                     -- Exemple de valeur
    parent_field TEXT,                      -- Champ parent si nested (ex: data.devices)
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

CREATE INDEX idx_outputs_script ON script_outputs(script_id);

-- Table des dépendances
CREATE TABLE IF NOT EXISTS script_dependencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,             -- Script qui dépend
    depends_on_script_id INTEGER,           -- Script dont il dépend
    depends_on_command TEXT,                -- Commande système dont il dépend
    depends_on_library TEXT,                -- Bibliothèque dont il dépend
    dependency_type TEXT NOT NULL,          -- Type: script, command, library, package
    is_optional BOOLEAN DEFAULT 0,          -- Dépendance optionnelle
    minimum_version TEXT,                   -- Version minimale requise
    notes TEXT,                             -- Notes sur la dépendance
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    FOREIGN KEY (depends_on_script_id) REFERENCES scripts(id) ON DELETE RESTRICT,
    CHECK (dependency_type IN ('script', 'command', 'library', 'package'))
);

CREATE INDEX idx_deps_script ON script_dependencies(script_id);
CREATE INDEX idx_deps_on_script ON script_dependencies(depends_on_script_id);

-- Table des codes de sortie
CREATE TABLE IF NOT EXISTS exit_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    exit_code INTEGER NOT NULL,             -- Code de sortie (0-255)
    code_name TEXT,                         -- Nom symbolique (EXIT_SUCCESS, EXIT_ERROR_GENERAL, etc.)
    description TEXT NOT NULL,              -- Description de la condition
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, exit_code)
);

CREATE INDEX idx_exitcodes_script ON exit_codes(script_id);

-- Table des tags/mots-clés
CREATE TABLE IF NOT EXISTS script_tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    tag TEXT NOT NULL,                      -- Tag (ex: backup, network, security)
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, tag)
);

CREATE INDEX idx_tags_script ON script_tags(script_id);
CREATE INDEX idx_tags_tag ON script_tags(tag);

-- Table des cas d'usage
CREATE TABLE IF NOT EXISTS use_cases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    use_case_title TEXT NOT NULL,           -- Titre du cas d'usage
    use_case_description TEXT NOT NULL,     -- Description détaillée
    example_command TEXT,                   -- Exemple de commande
    context TEXT,                           -- Contexte d'utilisation
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

CREATE INDEX idx_usecases_script ON use_cases(script_id);

-- Table d'historique des versions
CREATE TABLE IF NOT EXISTS version_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    version TEXT NOT NULL,                  -- Version
    release_date DATETIME NOT NULL,
    changelog TEXT NOT NULL,                -- Description des changements
    breaking_changes BOOLEAN DEFAULT 0,     -- Changements incompatibles
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

CREATE INDEX idx_versions_script ON version_history(script_id);

-- Table des statistiques d'utilisation
CREATE TABLE IF NOT EXISTS usage_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    execution_date DATE NOT NULL,
    execution_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    average_duration_ms INTEGER,            -- Durée moyenne en millisecondes
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, execution_date)
);

CREATE INDEX idx_stats_script ON usage_stats(script_id);
CREATE INDEX idx_stats_date ON usage_stats(execution_date);

-- Table des exemples complets
CREATE TABLE IF NOT EXISTS script_examples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    example_title TEXT NOT NULL,            -- Titre de l'exemple
    example_command TEXT NOT NULL,          -- Commande complète
    example_description TEXT,               -- Description de ce que fait l'exemple
    expected_output TEXT,                   -- Sortie attendue
    prerequisites TEXT,                     -- Prérequis pour cet exemple
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

CREATE INDEX idx_examples_script ON script_examples(script_id);

-- Table des fonctions (bibliothèques)
CREATE TABLE IF NOT EXISTS functions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,              -- Nom de la fonction
    library_file TEXT NOT NULL,             -- Fichier bibliothèque (ex: lib/cache.sh)
    category TEXT NOT NULL,                 -- Catégorie de fonction
    description TEXT NOT NULL,              -- Description
    parameters TEXT,                        -- Paramètres de la fonction (format texte)
    return_value TEXT,                      -- Ce que retourne la fonction
    example_usage TEXT,                     -- Exemple d'utilisation
    version TEXT NOT NULL DEFAULT '1.0.0',
    status TEXT NOT NULL DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    CHECK (status IN ('active', 'deprecated', 'obsolete'))
);

CREATE INDEX idx_functions_name ON functions(name);
CREATE INDEX idx_functions_library ON functions(library_file);

-- Table de relation script -> fonctions utilisées
CREATE TABLE IF NOT EXISTS script_uses_functions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    function_id INTEGER NOT NULL,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    FOREIGN KEY (function_id) REFERENCES functions(id) ON DELETE RESTRICT,
    UNIQUE(script_id, function_id)
);

CREATE INDEX idx_script_functions ON script_uses_functions(script_id);
CREATE INDEX idx_function_scripts ON script_uses_functions(function_id);

-- Vues utiles pour requêtes fréquentes

-- Vue: Scripts avec leur nombre de dépendances
CREATE VIEW IF NOT EXISTS v_scripts_with_dep_count AS
SELECT 
    s.id,
    s.name,
    s.type,
    s.category,
    s.status,
    s.version,
    COUNT(DISTINCT sd.id) as dependency_count
FROM scripts s
LEFT JOIN script_dependencies sd ON s.id = sd.script_id
GROUP BY s.id;

-- Vue: Scripts les plus utilisés (30 derniers jours)
CREATE VIEW IF NOT EXISTS v_top_scripts_30days AS
SELECT 
    s.id,
    s.name,
    s.type,
    s.category,
    SUM(us.execution_count) as total_executions,
    AVG(us.average_duration_ms) as avg_duration
FROM scripts s
JOIN usage_stats us ON s.id = us.script_id
WHERE us.execution_date >= date('now', '-30 days')
GROUP BY s.id
ORDER BY total_executions DESC;

-- Vue: Graphe de dépendances
CREATE VIEW IF NOT EXISTS v_dependency_graph AS
SELECT 
    s1.name as script_name,
    s1.type as script_type,
    s2.name as depends_on,
    sd.dependency_type,
    sd.is_optional
FROM script_dependencies sd
JOIN scripts s1 ON sd.script_id = s1.id
LEFT JOIN scripts s2 ON sd.depends_on_script_id = s2.id
WHERE sd.dependency_type = 'script';

-- Triggers pour mettre à jour updated_at automatiquement
CREATE TRIGGER update_scripts_timestamp 
AFTER UPDATE ON scripts
BEGIN
    UPDATE scripts SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- ============================================================================
-- FIN DU SCHEMA
-- ============================================================================
```

### 2.3 Script d'initialisation

**Créer le fichier `database/init-db.sh`** :

```bash
#!/bin/bash
#
# Script: init-db.sh
# Description: Initialise la base de données SQLite du catalogue
# Usage: ./init-db.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/scripts_catalogue.db"
SCHEMA_FILE="$SCRIPT_DIR/schema.sql"

echo "🗄️  Initialisation de la base de données du catalogue"
echo "=================================================="

# Vérifier que SQLite3 est installé
if ! command -v sqlite3 &> /dev/null; then
    echo "❌ Erreur: sqlite3 n'est pas installé"
    echo "   Installer avec: sudo apt-get install sqlite3"
    exit 1
fi

# Vérifier que le fichier schema existe
if [[ ! -f "$SCHEMA_FILE" ]]; then
    echo "❌ Erreur: Fichier schema.sql non trouvé"
    exit 1
fi

# Backup de la DB existante si elle existe
if [[ -f "$DB_FILE" ]]; then
    BACKUP_FILE="${DB_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
    echo "📦 Backup de la base existante: $BACKUP_FILE"
    cp "$DB_FILE" "$BACKUP_FILE"
fi

# Créer/Recréer la base de données
echo "🔨 Création de la base de données..."
sqlite3 "$DB_FILE" < "$SCHEMA_FILE"

# Vérifier la création
if [[ $? -eq 0 ]]; then
    echo "✅ Base de données créée avec succès: $DB_FILE"
    
    # Afficher les tables créées
    echo ""
    echo "📋 Tables créées:"
    sqlite3 "$DB_FILE" ".tables"
    
    echo ""
    echo "📊 Statistiques:"
    echo "   - Tables: $(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")"
    echo "   - Vues: $(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='view';")"
    echo "   - Index: $(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%';")"
    
    echo ""
    echo "🎉 Initialisation terminée!"
    echo ""
    echo "Prochaines étapes:"
    echo "  1. Enregistrer vos scripts: ./tools/register-script.sh"
    echo "  2. Rechercher dans la DB: ./tools/search-db.sh"
    echo "  3. Consulter la doc: docs/database-schema.md"
else
    echo "❌ Erreur lors de la création de la base de données"
    exit 1
fi
```

**Rendre exécutable et lancer** :

```bash
chmod +x database/init-db.sh
./database/init-db.sh
```

---

## 3. Enregistrement des Scripts dans la Base

### 3.1 Script d'enregistrement automatique

**Créer le fichier `tools/register-script.sh`** :

```bash
#!/bin/bash
#
# Script: register-script.sh
# Description: Enregistre un script dans la base de données du catalogue
# Usage: ./register-script.sh <chemin_script>
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"

# Vérifier les arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <chemin_script>"
    echo "Exemple: $0 atomics/detect-usb.sh"
    exit 1
fi

SCRIPT_PATH=$1

# Vérifier que le script existe
if [[ ! -f "$PROJECT_ROOT/$SCRIPT_PATH" ]]; then
    echo "❌ Erreur: Script non trouvé: $SCRIPT_PATH"
    exit 1
fi

SCRIPT_NAME=$(basename "$SCRIPT_PATH")

echo "📝 Enregistrement du script: $SCRIPT_NAME"
echo "=================================================="

# Parser les informations du script (en-tête)
parse_script_header() {
    local script="$1"
    
    # Extraire la description
    DESCRIPTION=$(grep "^# Description:" "$script" | head -1 | sed 's/^# Description: //')
    
    # Extraire le type (atomic ou orchestrator)
    if [[ "$script" =~ /atomics/ ]]; then
        TYPE="atomic"
    elif [[ "$script" =~ /orchestrators/level-1/ ]]; then
        TYPE="orchestrator-1"
    elif [[ "$script" =~ /orchestrators/level-2/ ]]; then
        TYPE="orchestrator-2"
    elif [[ "$script" =~ /orchestrators/level-3/ ]]; then
        TYPE="orchestrator-3"
    else
        TYPE="atomic"
    fi
    
    # Déterminer la catégorie selon le nom
    case $SCRIPT_NAME in
        detect-*|list-*|get-*|check-*) CATEGORY="information" ;;
        format-*|mount-*|partition-*) CATEGORY="storage" ;;
        start-*|stop-*|restart-*|enable-*|disable-*) CATEGORY="services" ;;
        create-*|delete-*|set-*) CATEGORY="management" ;;
        backup-*|restore-*) CATEGORY="backup" ;;
        test-*|benchmark-*) CATEGORY="testing" ;;
        install-*|remove-*|update-*) CATEGORY="packages" ;;
        *) CATEGORY="other" ;;
    esac
    
    # Extraire la version (si présente dans le changelog)
    VERSION="1.0.0"  # Défaut
    
    # Chemin de la documentation
    DOC_PATH="${script%.sh}.md"
    DOC_PATH="${DOC_PATH/atomics/docs\/atomics}"
    DOC_PATH="${DOC_PATH/orchestrators/docs\/orchestrators}"
}

parse_script_header "$PROJECT_ROOT/$SCRIPT_PATH"

# Afficher les informations détectées
echo "Informations détectées:"
echo "  - Nom: $SCRIPT_NAME"
echo "  - Type: $TYPE"
echo "  - Catégorie: $CATEGORY"
echo "  - Description: $DESCRIPTION"
echo ""

# Demander confirmation
read -p "Enregistrer ce script dans la base? (o/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo "❌ Annulé"
    exit 0
fi

# Insérer dans la base
sqlite3 "$DB_FILE" <<EOF
INSERT OR REPLACE INTO scripts (
    name, type, category, description, path, version, documentation_path, status
) VALUES (
    '$SCRIPT_NAME',
    '$TYPE',
    '$CATEGORY',
    '$DESCRIPTION',
    '$SCRIPT_PATH',
    '$VERSION',
    '$DOC_PATH',
    'active'
);
EOF

if [[ $? -eq 0 ]]; then
    SCRIPT_ID=$(sqlite3 "$DB_FILE" "SELECT id FROM scripts WHERE name='$SCRIPT_NAME';")
    echo "✅ Script enregistré avec succès (ID: $SCRIPT_ID)"
    
    # Proposer d'enregistrer les paramètres
    echo ""
    read -p "Voulez-vous enregistrer les paramètres interactivement? (o/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        register_parameters "$SCRIPT_ID"
    fi
    
    # Proposer d'enregistrer les codes de sortie
    echo ""
    read -p "Voulez-vous enregistrer les codes de sortie? (o/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        register_exit_codes "$SCRIPT_ID"
    fi
else
    echo "❌ Erreur lors de l'enregistrement"
    exit 1
fi

# Fonction pour enregistrer les paramètres
register_parameters() {
    local script_id=$1
    echo ""
    echo "📝 Enregistrement des paramètres"
    echo "Entrez 'done' quand vous avez fini"
    
    while true; do
        echo ""
        read -p "Nom du paramètre (ou 'done'): " param_name
        [[ "$param_name" == "done" ]] && break
        
        read -p "Type (string/integer/boolean/path): " param_type
        read -p "Obligatoire? (o/N): " required
        [[ "$required" =~ ^[Oo]$ ]] && is_required=1 || is_required=0
        read -p "Valeur par défaut (ou vide): " default_val
        read -p "Description: " param_desc
        
        sqlite3 "$DB_FILE" <<EOSQL
INSERT INTO script_parameters (
    script_id, param_name, param_type, is_required, default_value, description
) VALUES (
    $script_id, '$param_name', '$param_type', $is_required, 
    $([ -n "$default_val" ] && echo "'$default_val'" || echo "NULL"), 
    '$param_desc'
);
EOSQL
        echo "  ✓ Paramètre '$param_name' enregistré"
    done
}

# Fonction pour enregistrer les codes de sortie
register_exit_codes() {
    local script_id=$1
    echo ""
    echo "📝 Enregistrement des codes de sortie"
    
    # Codes standards
    declare -A standard_codes=(
        [0]="EXIT_SUCCESS:Succès"
        [1]="EXIT_ERROR_GENERAL:Erreur générale"
        [2]="EXIT_ERROR_USAGE:Paramètres invalides"
        [3]="EXIT_ERROR_PERMISSION:Permissions insuffisantes"
        [4]="EXIT_ERROR_NOT_FOUND:Ressource non trouvée"
        [8]="EXIT_ERROR_VALIDATION:Erreur de validation"
    )
    
    for code in "${!standard_codes[@]}"; do
        IFS=':' read -r name desc <<< "${standard_codes[$code]}"
        read -p "Utilise le code $code ($desc)? (O/n): " use_code
        if [[ ! "$use_code" =~ ^[Nn]$ ]]; then
            sqlite3 "$DB_FILE" <<EOSQL
INSERT INTO exit_codes (script_id, exit_code, code_name, description)
VALUES ($script_id, $code, '$name', '$desc');
EOSQL
            echo "  ✓ Code $code enregistré"
        fi
    done
}

echo ""
echo "🎉 Enregistrement terminé!"
```

### 3.2 Script d'enregistrement en masse

**Créer le fichier `tools/register-all-scripts.sh`** :

```bash
#!/bin/bash
#
# Script: register-all-scripts.sh
# Description: Enregistre tous les scripts du projet dans la base
# Usage: ./register-all-scripts.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📚 Enregistrement en masse des scripts"
echo "=================================================="

# Compter les scripts
ATOMIC_COUNT=$(find "$PROJECT_ROOT/atomics" -name "*.sh" -not -name "template-*" 2>/dev/null | wc -l)
ORCH_COUNT=$(find "$PROJECT_ROOT/orchestrators" -name "*.sh" -not -name "template-*" 2>/dev/null | wc -l)
TOTAL=$((ATOMIC_COUNT + ORCH_COUNT))

echo "Scripts trouvés:"
echo "  - Atomiques: $ATOMIC_COUNT"
echo "  - Orchestrateurs: $ORCH_COUNT"
echo "  - Total: $TOTAL"
echo ""

read -p "Continuer l'enregistrement? (o/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    exit 0
fi

# Enregistrer les atomiques
echo ""
echo "📝 Enregistrement des scripts atomiques..."
find "$PROJECT_ROOT/atomics" -name "*.sh" -not -name "template-*" | while read -r script; do
    rel_path="${script#$PROJECT_ROOT/}"
    echo "  • $(basename "$script")"
    "$SCRIPT_DIR/register-script.sh" "$rel_path" <<< "o" > /dev/null 2>&1 || echo "    ⚠️  Erreur"
done

# Enregistrer les orchestrateurs
echo ""
echo "📝 Enregistrement des orchestrateurs..."
find "$PROJECT_ROOT/orchestrators" -name "*.sh" -not -name "template-*" | while read -r script; do
    rel_path="${script#$PROJECT_ROOT/}"
    echo "  • $(basename "$script")"
    "$SCRIPT_DIR/register-script.sh" "$rel_path" <<< "o" > /dev/null 2>&1 || echo "    ⚠️  Erreur"
done

echo ""
echo "✅ Enregistrement en masse terminé!"
```

---

## 4. Recherche et Consultation

### 4.1 Script de recherche

**Créer le fichier `tools/search-db.sh`** :

```bash
#!/bin/bash
#
# Script: search-db.sh
# Description: Recherche dans le catalogue de scripts
# Usage: ./search-db.sh [options]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"

# Fonction d'aide
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [TERM]

Options:
    -n, --name <pattern>        Recherche par nom
    -c, --category <cat>        Recherche par catégorie
    -t, --type <type>           Recherche par type (atomic, orchestrator-1, etc.)
    -T, --tag <tag>             Recherche par tag
    -d, --description <term>    Recherche dans les descriptions
    -a, --all                   Liste tous les scripts
    -s, --stats                 Affiche les statistiques
    -i, --info <name>           Détails complets d'un script
    -D, --dependencies <name>   Affiche les dépendances d'un script
    -h, --help                  Affiche cette aide

Exemples:
    $0 --name "detect-*"
    $0 --category storage
    $0 --type atomic
    $0 --tag backup
    $0 --info detect-usb.sh
    $0 --dependencies setup-disk.sh

EOF
}

# Fonction de recherche par nom
search_by_name() {
    local pattern=$1
    echo "🔍 Recherche par nom: $pattern"
    echo ""
    
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    name,
    type,
    category,
    substr(description, 1, 50) || '...' as description,
    status
FROM scripts
WHERE name LIKE '%$pattern%'
ORDER BY type, name;
EOF
}

# Fonction de recherche par catégorie
search_by_category() {
    local cat=$1
    echo "🔍 Scripts de la catégorie: $cat"
    echo ""
    
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    name,
    type,
    substr(description, 1, 60) as description
FROM scripts
WHERE category = '$cat'
ORDER BY type, name;
EOF
}

# Fonction pour afficher tous les scripts
list_all() {
    echo "📋 Tous les scripts"
    echo ""
    
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    name,
    type,
    category,
    status,
    version
FROM scripts
ORDER BY type, category, name;
EOF
}

# Fonction pour afficher les statistiques
show_stats() {
    echo "📊 Statistiques du catalogue"
    echo "==========================================="
    
    # Total de scripts
    local total=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM scripts;")
    echo "Total de scripts: $total"
    
    # Par type
    echo ""
    echo "Par type