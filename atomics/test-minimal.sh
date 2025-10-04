#!/bin/bash
#
# Test script minimal pour vérifier l'environnement
#

set -euo pipefail

echo "Test script started"
echo "Bash version: $BASH_VERSION"
echo "Working directory: $(pwd)"
echo "Script directory: $(dirname "$0")"
echo "Test completed"