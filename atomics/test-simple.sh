#!/usr/bin/env bash

# Script de test simple pour identifier les problèmes
set -euo pipefail

echo "Test de génération JSON simple:"

cat << 'EOF'
{
  "status": "success",
  "code": 0,
  "timestamp": "2025-10-03T20:30:00Z",
  "script": "test-simple.sh",
  "message": "Test réussi",
  "data": {
    "test": "valeur"
  },
  "errors": [],
  "warnings": []
}
EOF

echo "Test terminé"