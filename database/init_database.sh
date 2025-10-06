#!/usr/bin/env bash
# =====================================================
# SCRIPT DE CRÉATION DE LA BASE DE DONNÉES SQLite3
# AtomicOps-Suite - Initialisation des types d'inputs
# =====================================================

set -euo pipefail

# Variables de configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="${SCRIPT_DIR}/atomicops_inputs.db"
SQL_FILE="${SCRIPT_DIR}/input_parameter_types.sql"

# Fonction d'information
info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

# Fonction de succès
ok() {
    echo -e "\e[32m[OK]\e[0m $1"
}

# Fonction d'erreur
die() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
    exit 1
}

# Vérification des prérequis
check_prerequisites() {
    info "Vérification des prérequis..."
    
    if ! command -v sqlite3 &> /dev/null; then
        die "SQLite3 n'est pas installé. Installez-le avec: sudo apt-get install sqlite3"
    fi
    
    if [[ ! -f "$SQL_FILE" ]]; then
        die "Fichier SQL non trouvé: $SQL_FILE"
    fi
    
    ok "Prérequis vérifiés"
}

# Création de la base de données
create_database() {
    info "Création de la base de données: $DB_FILE"
    
    # Suppression de l'ancienne base si elle existe
    if [[ -f "$DB_FILE" ]]; then
        info "Suppression de l'ancienne base de données..."
        rm "$DB_FILE"
    fi
    
    # Création et initialisation de la base
    info "Exécution du script SQL d'initialisation..."
    sqlite3 "$DB_FILE" < "$SQL_FILE"
    
    ok "Base de données créée avec succès"
}

# Vérification du contenu
verify_database() {
    info "Vérification du contenu de la base de données..."
    
    # Compter le nombre d'inputs
    local count
    count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM input_parameter_types;")
    
    if [[ "$count" -eq 13 ]]; then
        ok "Base de données initialisée avec $count types d'inputs"
    else
        die "Erreur: attendu 13 types d'inputs, trouvé $count"
    fi
    
    # Afficher un résumé
    info "Résumé par catégorie:"
    sqlite3 "$DB_FILE" "SELECT category, COUNT(*) as total FROM input_parameter_types GROUP BY category;"
    
    info "Liste des types d'inputs:"
    sqlite3 "$DB_FILE" "SELECT type_name, display_label, category FROM input_parameter_types ORDER BY category, type_name;" | column -t -s '|'
}

# Fonction principale
main() {
    info "=== Initialisation de la base de données AtomicOps-Suite ==="
    info "Base de données: $DB_FILE"
    info "Script SQL: $SQL_FILE"
    echo
    
    check_prerequisites
    create_database
    verify_database
    
    echo
    ok "Initialisation terminée avec succès!"
    info "Vous pouvez maintenant utiliser la base de données:"
    echo "  sqlite3 $DB_FILE"
    echo "  .tables"
    echo "  SELECT * FROM input_parameter_types LIMIT 5;"
}

# Exécution du script
main "$@"