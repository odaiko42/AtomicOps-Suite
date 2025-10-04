#!/usr/bin/env bash

#===============================================================================
# Générateur de Schéma Complet - Affichage de tous les scripts par catégorie
#===============================================================================
# Description : Génère un aperçu textuel de tous les scripts disponibles
# Objectif : Diagnostiquer pourquoi certains scripts n'apparaissent pas dans l'interface
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_PATH="$SCRIPT_DIR/catalogue-scripts.db"

echo "🔍 ANALYSE COMPLÈTE DU CATALOGUE DE SCRIPTS"
echo "==============================================="
echo ""

# Vérification de la base
if [[ ! -f "$DATABASE_PATH" ]]; then
    echo "❌ Base de données non trouvée : $DATABASE_PATH"
    exit 1
fi

# Statistiques générales
echo "📊 STATISTIQUES GÉNÉRALES :"
sqlite3 "$DATABASE_PATH" << 'EOF'
.mode box
SELECT 
    'TOTAL' as Métrique,
    COUNT(*) as Valeur
FROM scripts
UNION ALL
SELECT 
    'ATOMIQUES',
    COUNT(*)
FROM scripts WHERE type = 'atomic'
UNION ALL
SELECT 
    'ORCHESTRATEURS', 
    COUNT(*)
FROM scripts WHERE type = 'orchestrator';
EOF

echo ""
echo "📋 PAR CATÉGORIE :"
sqlite3 "$DATABASE_PATH" << 'EOF'
.mode box
SELECT 
    category as Catégorie,
    COUNT(*) as 'Nb Scripts',
    GROUP_CONCAT(DISTINCT type) as Types,
    GROUP_CONCAT(DISTINCT protocol) as Protocoles
FROM scripts 
GROUP BY category 
ORDER BY category;
EOF

echo ""
echo "🌐 SCRIPTS RÉSEAU DÉTAILLÉS :"
sqlite3 "$DATABASE_PATH" << 'EOF'
.mode table
.headers on
SELECT 
    name as 'Nom du Script',
    type as 'Type',
    protocol as 'Protocole',
    level as 'Niveau',
    CASE 
        WHEN LENGTH(description) > 50 THEN SUBSTR(description, 1, 47) || '...'
        ELSE description 
    END as 'Description'
FROM scripts 
WHERE category = 'network'
ORDER BY protocol, type, name;
EOF

echo ""
echo "🔗 RELATIONS ET DÉPENDANCES :"
sqlite3 "$DATABASE_PATH" << 'EOF'
.mode table  
.headers on
SELECT 
    s1.name as 'Script Parent',
    sr.relationship_type as 'Relation',
    s2.name as 'Script Enfant'
FROM script_relationships sr
JOIN scripts s1 ON sr.parent_script_id = s1.id
JOIN scripts s2 ON sr.child_script_id = s2.id
ORDER BY s1.name;
EOF

echo ""
echo "🏷️ TAGS PAR SCRIPT SSH :"
sqlite3 "$DATABASE_PATH" << 'EOF'
.mode table
.headers on
SELECT 
    s.name as 'Script SSH',
    s.type as 'Type',
    GROUP_CONCAT(st.tag, ', ') as 'Tags'
FROM scripts s
LEFT JOIN script_tags st ON s.id = st.script_id
WHERE s.protocol = 'ssh'
GROUP BY s.name
ORDER BY s.type, s.name;
EOF

echo ""
echo "🔧 DIAGNOSTIC INTERFACE GRAPHIQUE :"
echo "Les scripts suivants devraient apparaître dans l'interface :"

# Liste pour diagnostic d'interface
sqlite3 "$DATABASE_PATH" << 'EOF'
SELECT 
    '- ' || name || ' (' || type || ', ' || protocol || ')'
FROM scripts 
WHERE category = 'network'
ORDER BY type DESC, protocol, name;
EOF

echo ""
echo "💡 RECOMMANDATIONS :"
echo "1. Vérifier les filtres actifs dans l'interface graphique"
echo "2. S'assurer que l'interface charge la catégorie 'network'"
echo "3. Contrôler que les scripts SSH ne sont pas masqués par un filtre de protocole"
echo "4. Rafraîchir le cache de l'interface si nécessaire"

echo ""
echo "📁 CHEMINS DES FICHIERS SCRIPTS SSH :"
sqlite3 "$DATABASE_PATH" << 'EOF'
.mode table
.headers on
SELECT 
    name as 'Script',
    file_path as 'Chemin'
FROM scripts 
WHERE protocol = 'ssh'
ORDER BY type, name;
EOF