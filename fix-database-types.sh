#!/usr/bin/env bash

# ==============================================================================
# Script de Correction: fix-database-types.sh
# Description: Correction des types manquants dans la base de données SQLite
# Author: Generated with AtomicOps-Suite AI assistance  
# Version: 1.0
# Date: 2025-10-04
# Dependencies: sqlite3
# ==============================================================================

set -euo pipefail

DATABASE_FILE="${1:-catalogue-scripts.db}"

echo "=== CORRECTION DES TYPES DANS LA BASE DE DONNÉES ==="
echo "Base de données: $DATABASE_FILE"

# Vérification de l'existence de la base
if [[ ! -f "$DATABASE_FILE" ]]; then
    echo "ERREUR: Base de données non trouvée: $DATABASE_FILE"
    exit 1
fi

echo "Correction des types de scripts..."

# Mise à jour des scripts atomiques
sqlite3 "$DATABASE_FILE" << 'EOF'
UPDATE scripts SET type = 'atomic' WHERE level = 0;
UPDATE scripts SET type = 'orchestrator' WHERE level = 1;
EOF

echo "Types corrigés avec succès!"

# Vérification des corrections
echo ""
echo "=== VÉRIFICATION DES CORRECTIONS ==="

echo "Répartition par type:"
sqlite3 "$DATABASE_FILE" "SELECT type, COUNT(*) as count FROM scripts GROUP BY type;"

echo ""
echo "Répartition par niveau:"
sqlite3 "$DATABASE_FILE" "SELECT 
    CASE level 
        WHEN 0 THEN 'Niveau 0 (Atomique)' 
        WHEN 1 THEN 'Niveau 1 (Orchestrateur)'
        ELSE 'Niveau ' || level 
    END as niveau, 
    COUNT(*) as count 
FROM scripts GROUP BY level;"

echo ""
echo "Liste complète des scripts:"
sqlite3 "$DATABASE_FILE" "SELECT 
    name, 
    type, 
    protocol, 
    level,
    SUBSTR(description, 1, 50) || '...' as description_short
FROM scripts ORDER BY type, protocol, name;"

echo ""
echo "=== CORRECTION TERMINÉE ==="