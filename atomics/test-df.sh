#!/usr/bin/env bash
set -euo pipefail

echo "Test 1: Script démarre"
echo "Test 2: Exécution df"
df -P | head -5
echo "Test 3: Fin test"