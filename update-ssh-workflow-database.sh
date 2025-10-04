#!/usr/bin/env bash

#===============================================================================
# Mise à jour du catalogue avec le workflow SSH par défaut
#===============================================================================
# Description : Ajoute le nouveau workflow SSH dans la base de données SQLite
# Objectif : Intégrer ssh-default-workflow.sh dans le catalogue des scripts
#===============================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_PATH="$SCRIPT_DIR/catalogue-scripts.db"
WORKFLOW_SCRIPT="$SCRIPT_DIR/usb-disk-manager/scripts/orchestrators/network/ssh-default-workflow.sh"

# === VALIDATION ===
if [[ ! -f "$DATABASE_PATH" ]]; then
    echo "❌ Base de données non trouvée : $DATABASE_PATH"
    exit 1
fi

if [[ ! -f "$WORKFLOW_SCRIPT" ]]; then
    echo "❌ Script workflow non trouvé : $WORKFLOW_SCRIPT"
    exit 1
fi

echo "🔄 Mise à jour du catalogue avec le workflow SSH par défaut..."

# === EXTRACTION MÉTADONNÉES ===
WORKFLOW_NAME="ssh-default-workflow"
DESCRIPTION="Workflow par défaut pour connexion SSH avec exploration de répertoire"
CATEGORY="network"
LEVEL=1  # Orchestrateur
TYPE="orchestrator"
LOCATION="usb-disk-manager/scripts/orchestrators/network"
CREATED_DATE=$(date -Iseconds)

# === AJOUT DANS LA BASE ===
sqlite3 "$DATABASE_PATH" << EOF
-- Insertion du nouveau workflow
INSERT OR REPLACE INTO scripts (
    name, description, category, level, type, location, created_date
) VALUES (
    '$WORKFLOW_NAME',
    '$DESCRIPTION', 
    '$CATEGORY',
    $LEVEL,
    '$TYPE',
    '$LOCATION',
    '$CREATED_DATE'
);

-- Ajout des tags pour le workflow
INSERT OR IGNORE INTO tags (tag) VALUES ('ssh');
INSERT OR IGNORE INTO tags (tag) VALUES ('workflow');
INSERT OR IGNORE INTO tags (tag) VALUES ('orchestrateur');
INSERT OR IGNORE INTO tags (tag) VALUES ('default');
INSERT OR IGNORE INTO tags (tag) VALUES ('exploration');

-- Association des tags au script
INSERT OR IGNORE INTO script_tags (script_name, tag) 
SELECT '$WORKFLOW_NAME', tag FROM tags 
WHERE tag IN ('ssh', 'workflow', 'orchestrateur', 'default', 'exploration');

-- Affichage de confirmation
SELECT 'Script ajouté avec succès:' as status;
SELECT name, type, level, category FROM scripts WHERE name = '$WORKFLOW_NAME';
SELECT 'Tags associés:' as info;
SELECT st.tag FROM script_tags st WHERE st.script_name = '$WORKFLOW_NAME';
EOF

echo "✅ Workflow SSH par défaut ajouté au catalogue !"

# === STATISTIQUES FINALES ===
echo ""
echo "📊 État du catalogue après mise à jour :"
sqlite3 "$DATABASE_PATH" << EOF
SELECT 'Total des scripts: ' || COUNT(*) FROM scripts;
SELECT 'Orchestrateurs: ' || COUNT(*) FROM scripts WHERE type = 'orchestrator';
SELECT 'Scripts atomiques: ' || COUNT(*) FROM scripts WHERE type = 'atomic';
SELECT 'Catégorie network: ' || COUNT(*) FROM scripts WHERE category = 'network';
EOF