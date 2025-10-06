# Base de Données SQLite3 - Types d'Inputs AtomicOps-Suite

## Vue d'ensemble

Cette base de données SQLite3 contient la définition complète des **13 types d'inputs supportés** par l'interface AtomicOps-Suite pour la configuration des scripts et workflows.

## Types d'Inputs Supportés

### Catégorie Réseau (`network`)
- **IP** - Adresse IP version 4 
- **HOSTNAME** - Nom d'hôte ou FQDN
- **URL** - URL complète pour services web
- **EMAIL** - Adresse email pour notifications
- **PORT** - Port TCP/UDP (1-65535)

### Catégorie Authentification (`auth`)
- **USERNAME** - Nom d'utilisateur système
- **PASSWORD** - Mot de passe sécurisé
- **TOKEN** - Token d'authentification ou clé SSH

### Catégorie Système (`system`)
- **DEVICE** - Chemin vers périphérique de stockage
- **PATH** - Chemin vers fichier ou répertoire
- **IQN** - Identificateur iSCSI Qualified Name
- **SIZE** - Taille en octets/Ko/Mo/Go/To
- **TIMEOUT** - Délai d'expiration en secondes

## Structure de la Base de Données

```sql
CREATE TABLE input_parameter_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_name VARCHAR(20) NOT NULL UNIQUE,
    display_label VARCHAR(50) NOT NULL,
    color_hex VARCHAR(7) NOT NULL,
    validation_regex TEXT,
    validation_message VARCHAR(200),
    default_value VARCHAR(100),
    description TEXT,
    category VARCHAR(20),
    is_required BOOLEAN DEFAULT FALSE,
    min_length INTEGER,
    max_length INTEGER,
    examples VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Utilisation

### 1. Initialisation de la Base

```bash
# Créer la base de données avec tous les types d'inputs
chmod +x init_database.sh
./init_database.sh
```

### 2. Consultation des Données

```bash
# Rendre le script exécutable
chmod +x query_inputs.sh

# Afficher tous les types d'inputs
./query_inputs.sh all

# Afficher les inputs par catégorie
./query_inputs.sh category network
./query_inputs.sh category auth
./query_inputs.sh category system

# Détails d'un type spécifique
./query_inputs.sh details ip
./query_inputs.sh details username

# Statistiques générales
./query_inputs.sh stats
```

### 3. Export pour l'Application

```bash
# Export JSON
./query_inputs.sh json
# Génère: input_types.json

# Export TypeScript
./query_inputs.sh typescript
# Génère: inputTypes.ts
```

### 4. Requêtes Directes SQLite3

```bash
# Ouvrir la base de données
sqlite3 atomicops_inputs.db

# Requêtes utiles
.tables
.schema input_parameter_types

# Tous les types d'inputs
SELECT * FROM input_parameter_types;

# Par catégorie
SELECT * FROM input_parameter_types WHERE category = 'network';

# Recherche par nom
SELECT * FROM input_parameter_types WHERE type_name = 'ip';

# Statistiques
SELECT category, COUNT(*) FROM input_parameter_types GROUP BY category;
```

## Exemples de Requêtes

### Récupérer la Configuration d'un Input

```sql
SELECT 
    type_name,
    display_label,
    color_hex,
    validation_regex,
    validation_message,
    default_value
FROM input_parameter_types 
WHERE type_name = 'ip';
```

### Inputs par Catégorie avec Couleurs

```sql
SELECT 
    category,
    type_name,
    display_label,
    color_hex
FROM input_parameter_types 
ORDER BY category, type_name;
```

### Export JSON des Inputs Réseau

```sql
SELECT json_group_array(
    json_object(
        'type', type_name,
        'label', display_label,
        'color', color_hex,
        'default', default_value
    )
) 
FROM input_parameter_types 
WHERE category = 'network';
```

## Integration avec l'Application

La base de données peut être intégrée avec l'application TypeScript/React de plusieurs façons :

1. **Export statique** : Générer des fichiers TypeScript/JSON
2. **API REST** : Créer une API pour interroger la base
3. **Import direct** : Utiliser une bibliothèque SQLite3 côté client

### Exemple d'Integration TypeScript

```typescript
import { INPUT_TYPES_CONFIG } from './inputTypes';

// Récupérer la configuration d'un type
const ipConfig = INPUT_TYPES_CONFIG['ip'];
console.log(ipConfig.label);     // "Adresse IP"
console.log(ipConfig.color);     // "#3b82f6"
console.log(ipConfig.regex);     // Regex de validation

// Filtrer par catégorie
const networkInputs = Object.values(INPUT_TYPES_CONFIG)
    .filter(config => config.category === 'network');
```

## Maintenance

### Ajouter un Nouveau Type

```sql
INSERT INTO input_parameter_types (
    type_name, display_label, color_hex, validation_regex,
    validation_message, default_value, description, category
) VALUES (
    'nouveau_type', 'Nouveau Type', '#ff0000',
    '^[a-z]+$', 'Format invalide', 'valeur_defaut',
    'Description du nouveau type', 'system'
);
```

### Modifier un Type Existant

```sql
UPDATE input_parameter_types 
SET display_label = 'Nouveau Label',
    color_hex = '#00ff00'
WHERE type_name = 'ip';
```

### Supprimer un Type

```sql
DELETE FROM input_parameter_types 
WHERE type_name = 'type_obsolete';
```

## Fichiers du Projet

- `input_parameter_types.sql` - Script de création et initialisation
- `init_database.sh` - Script d'initialisation automatique
- `query_inputs.sh` - Script de requêtes et export
- `atomicops_inputs.db` - Base de données SQLite3 (générée)
- `input_types.json` - Export JSON (généré)
- `inputTypes.ts` - Export TypeScript (généré)

## Validation des Données

Chaque type d'input inclut :
- **Regex de validation** pour vérifier le format
- **Message d'erreur** personnalisé en français
- **Valeurs d'exemple** pour aider les utilisateurs
- **Valeur par défaut** sensée
- **Couleur d'identification** unique

Cette approche garantit une validation cohérente et une expérience utilisateur optimale dans toute l'application AtomicOps-Suite.