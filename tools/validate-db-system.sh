#!/bin/bash
#
# Script: validate-db-system.sh
# Description: Valide que le système de base de données catalogue fonctionne
# Usage: ./validate-db-system.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"

# Import des bibliothèques
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"

# Variables globales de test
TEMP_TEST_DIR=""
TEST_ERRORS=0

# Fonction d'aide
show_help() {
    cat <<EOF
Usage: $0

Valide le système complet de base de données catalogue

Tests effectués:
  ✓ Initialisation de la base de données
  ✓ Enregistrement de scripts
  ✓ Recherches et requêtes
  ✓ Export des données
  ✓ Intégrité et performance

Options:
  -h, --help      Affiche cette aide

EOF
}

# Initialisation des tests
setup_test_environment() {
    log_info "🧪 Initialisation de l'environnement de test"
    
    # Créer un répertoire temporaire pour les tests
    TEMP_TEST_DIR=$(mktemp -d)
    log_debug "Répertoire de test: $TEMP_TEST_DIR"
    
    # Backup de la base existante si elle existe
    if [[ -f "$DB_FILE" ]]; then
        cp "$DB_FILE" "$TEMP_TEST_DIR/backup_original.db"
        log_debug "Backup de la base originale créé"
    fi
}

# Nettoyage après tests
cleanup_test_environment() {
    log_info "🧹 Nettoyage de l'environnement de test"
    
    # Restaurer la base originale si elle existait
    if [[ -f "$TEMP_TEST_DIR/backup_original.db" ]]; then
        cp "$TEMP_TEST_DIR/backup_original.db" "$DB_FILE"
        log_debug "Base originale restaurée"
    fi
    
    # Nettoyer le répertoire temporaire
    if [[ -n "$TEMP_TEST_DIR" && -d "$TEMP_TEST_DIR" ]]; then
        rm -rf "$TEMP_TEST_DIR"
        log_debug "Répertoire de test nettoyé"
    fi
}

# Test d'initialisation de la base
test_database_initialization() {
    log_info "📋 Test 1: Initialisation de la base de données"
    
    # Supprimer la base existante pour le test
    [[ -f "$DB_FILE" ]] && rm -f "$DB_FILE"
    
    # Tester l'initialisation
    if "$PROJECT_ROOT/database/init-db.sh" >/dev/null 2>&1; then
        log_info "✓ Initialisation réussie"
        
        # Vérifier que la base existe
        if [[ -f "$DB_FILE" ]]; then
            log_debug "✓ Fichier base créé"
        else
            log_error "✗ Fichier base manquant"
            TEST_ERRORS=$((TEST_ERRORS + 1))
            return 1
        fi
        
        # Vérifier les tables
        local table_count
        table_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
        
        if [[ "$table_count" -ge 10 ]]; then
            log_debug "✓ Tables créées ($table_count tables)"
        else
            log_error "✗ Nombre de tables insuffisant: $table_count"
            TEST_ERRORS=$((TEST_ERRORS + 1))
            return 1
        fi
        
        return 0
    else
        log_error "✗ Échec initialisation"
        TEST_ERRORS=$((TEST_ERRORS + 1))
        return 1
    fi
}

# Test d'enregistrement de scripts
test_script_registration() {
    log_info "📝 Test 2: Enregistrement de scripts"
    
    # Tester l'enregistrement d'un script existant
    local test_script="tools/dev-helper.sh"
    
    if "$PROJECT_ROOT/tools/register-script.sh" "$test_script" --auto >/dev/null 2>&1; then
        log_info "✓ Enregistrement unitaire réussi"
        
        # Vérifier que le script est dans la base
        local script_count
        script_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM scripts WHERE name = 'dev-helper.sh';")
        
        if [[ "$script_count" -eq 1 ]]; then
            log_debug "✓ Script trouvé dans la base"
        else
            log_error "✗ Script non trouvé dans la base"
            TEST_ERRORS=$((TEST_ERRORS + 1))
            return 1
        fi
    else
        log_error "✗ Échec enregistrement unitaire"
        TEST_ERRORS=$((TEST_ERRORS + 1))
        return 1
    fi
    
    # Tester l'enregistrement en masse
    if "$PROJECT_ROOT/tools/register-all-scripts.sh" >/dev/null 2>&1; then
        log_info "✓ Enregistrement en masse réussi"
        
        # Vérifier le nombre de scripts
        local total_scripts
        total_scripts=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM scripts;")
        
        if [[ "$total_scripts" -ge 5 ]]; then
            log_debug "✓ $total_scripts scripts enregistrés"
        else
            log_error "✗ Nombre de scripts insuffisant: $total_scripts"
            TEST_ERRORS=$((TEST_ERRORS + 1))
            return 1
        fi
    else
        log_error "✗ Échec enregistrement en masse"  
        TEST_ERRORS=$((TEST_ERRORS + 1))
        return 1
    fi
    
    return 0
}

# Test des fonctionnalités de recherche
test_search_functionality() {
    log_info "🔍 Test 3: Fonctionnalités de recherche"
    
    # Test recherche générale
    if "$PROJECT_ROOT/tools/search-db.sh" --all >/dev/null 2>&1; then
        log_debug "✓ Recherche --all fonctionne"
    else
        log_error "✗ Échec recherche --all"
        TEST_ERRORS=$((TEST_ERRORS + 1))
    fi
    
    # Test statistiques
    if "$PROJECT_ROOT/tools/search-db.sh" --stats >/dev/null 2>&1; then
        log_debug "✓ Statistiques fonctionnent"
    else
        log_error "✗ Échec statistiques"
        TEST_ERRORS=$((TEST_ERRORS + 1))
    fi
    
    # Test info détaillée (si script existe)
    local existing_script
    existing_script=$(sqlite3 "$DB_FILE" "SELECT name FROM scripts LIMIT 1;" 2>/dev/null || echo "")
    
    if [[ -n "$existing_script" ]]; then
        if "$PROJECT_ROOT/tools/search-db.sh" --info "$existing_script" >/dev/null 2>&1; then
            log_debug "✓ Info détaillée fonctionne"
        else
            log_error "✗ Échec info détaillée"
            TEST_ERRORS=$((TEST_ERRORS + 1))
        fi
    fi
    
    # Test recherche par type
    if "$PROJECT_ROOT/tools/search-db.sh" --type atomic >/dev/null 2>&1; then
        log_debug "✓ Recherche par type fonctionne"
    else
        log_error "✗ Échec recherche par type"
        TEST_ERRORS=$((TEST_ERRORS + 1))
    fi
    
    log_info "✓ Tests de recherche terminés"
    return 0
}

# Test des exports
test_export_functionality() {
    log_info "📤 Test 4: Fonctionnalités d'export"
    
    local test_export_dir="$TEMP_TEST_DIR/exports"
    mkdir -p "$test_export_dir"
    
    # Test export JSON
    if "$PROJECT_ROOT/tools/export-db.sh" json --output-dir "$test_export_dir" >/dev/null 2>&1; then
        log_debug "✓ Export JSON fonctionne"
        
        # Vérifier que le fichier JSON existe et est valide
        local json_file
        json_file=$(find "$test_export_dir" -name "*.json" -type f | head -1)
        
        if [[ -f "$json_file" ]]; then
            if command -v jq >/dev/null 2>&1; then
                if jq . "$json_file" >/dev/null 2>&1; then
                    log_debug "✓ JSON valide"
                else
                    log_error "✗ JSON invalide"
                    TEST_ERRORS=$((TEST_ERRORS + 1))
                fi
            else
                log_debug "? JSON créé (jq non disponible pour validation)"
            fi
        else
            log_error "✗ Fichier JSON non créé"
            TEST_ERRORS=$((TEST_ERRORS + 1))
        fi
    else
        log_error "✗ Échec export JSON"
        TEST_ERRORS=$((TEST_ERRORS + 1))
    fi
    
    # Test backup
    if "$PROJECT_ROOT/tools/export-db.sh" backup --output-dir "$test_export_dir" >/dev/null 2>&1; then
        log_debug "✓ Backup fonctionne"
        
        # Vérifier que le backup existe
        local backup_file
        backup_file=$(find "$test_export_dir" -name "backup_*.db" -type f | head -1)
        
        if [[ -f "$backup_file" ]]; then
            # Vérifier que le backup est une base SQLite valide
            if sqlite3 "$backup_file" "SELECT COUNT(*) FROM scripts;" >/dev/null 2>&1; then
                log_debug "✓ Backup valide"
            else
                log_error "✗ Backup invalide"
                TEST_ERRORS=$((TEST_ERRORS + 1))
            fi
        else
            log_error "✗ Fichier backup non créé"
            TEST_ERRORS=$((TEST_ERRORS + 1))
        fi
    else
        log_error "✗ Échec backup"
        TEST_ERRORS=$((TEST_ERRORS + 1))
    fi
    
    log_info "✓ Tests d'export terminés"
    return 0
}

# Test de l'intégrité et performance
test_integrity_performance() {
    log_info "🔧 Test 5: Intégrité et performance"
    
    # Test intégrité SQLite
    local integrity_result
    integrity_result=$(sqlite3 "$DB_FILE" "PRAGMA integrity_check;" 2>/dev/null || echo "error")
    
    if [[ "$integrity_result" == "ok" ]]; then
        log_debug "✓ Intégrité base OK"
    else
        log_error "✗ Problème intégrité: $integrity_result"
        TEST_ERRORS=$((TEST_ERRORS + 1))
    fi
    
    # Test des contraintes de clés étrangères
    local foreign_key_check
    foreign_key_check=$(sqlite3 "$DB_FILE" "PRAGMA foreign_key_check;" 2>/dev/null)
    
    if [[ -z "$foreign_key_check" ]]; then
        log_debug "✓ Contraintes clés étrangères OK"
    else
        log_error "✗ Violations clés étrangères: $foreign_key_check"
        TEST_ERRORS=$((TEST_ERRORS + 1))
    fi
    
    # Test performance basique (requête complexe)
    local start_time=$(date +%s%N)
    
    sqlite3 "$DB_FILE" <<EOF >/dev/null 2>&1
SELECT s.name, COUNT(sd.id) as dep_count
FROM scripts s
LEFT JOIN script_dependencies sd ON s.id = sd.script_id
GROUP BY s.id
ORDER BY dep_count DESC
LIMIT 10;
EOF
    
    local end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $duration_ms -lt 1000 ]]; then
        log_debug "✓ Performance OK (${duration_ms}ms)"
    else
        log_warn "⚠ Performance lente (${duration_ms}ms)"
    fi
    
    # Vérifier la taille de la base
    local db_size_kb
    db_size_kb=$(du -k "$DB_FILE" | cut -f1)
    
    if [[ $db_size_kb -lt 10240 ]]; then  # < 10MB
        log_debug "✓ Taille base acceptable (${db_size_kb}KB)"
    else
        log_warn "⚠ Base volumineuse (${db_size_kb}KB)"
    fi
    
    log_info "✓ Tests intégrité/performance terminés"
    return 0
}

# Affichage du rapport final
show_test_report() {
    echo ""
    echo "📊 RAPPORT DE VALIDATION"
    echo "========================"
    echo ""
    
    if [[ $TEST_ERRORS -eq 0 ]]; then
        log_info "🎉 SUCCÈS - Tous les tests sont passés !"
        echo ""
        echo "Le système de catalogue SQLite est pleinement fonctionnel :"
        echo "  ✓ Base de données opérationnelle"
        echo "  ✓ Enregistrement de scripts fonctionnel"
        echo "  ✓ Recherches et requêtes disponibles"
        echo "  ✓ Exports et sauvegardes prêts"
        echo "  ✓ Intégrité et performances validées"
        echo ""
        echo "Prochaines étapes recommandées :"
        echo "  1. ./tools/register-all-scripts.sh     # Enregistrer tous vos scripts"
        echo "  2. ./tools/search-db.sh --stats        # Voir les statistiques"
        echo "  3. ./tools/export-db.sh backup         # Créer un backup"
        
    else
        log_error "❌ ÉCHEC - $TEST_ERRORS erreur(s) détectée(s)"
        echo ""
        echo "Le système présente des dysfonctionnements."
        echo "Vérifiez les logs ci-dessus et corrigez les problèmes."
        echo ""
        echo "Actions de dépannage :"
        echo "  1. Vérifiez les permissions sur database/"
        echo "  2. Testez sqlite3 : sqlite3 --version"
        echo "  3. Réinitialisez : ./database/init-db.sh --force"
    fi
    
    echo ""
    echo "Base de données : $DB_FILE"
    if [[ -f "$DB_FILE" ]]; then
        echo "Taille base     : $(du -h "$DB_FILE" | cut -f1)"
        echo "Scripts catalogués : $(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM scripts;" 2>/dev/null || echo "N/A")"
    else
        echo "Statut          : Base non trouvée"
    fi
}

# Point d'entrée principal
main() {
    # Initialisation du logging
    init_logging "$(basename "$0")"
    
    log_info "🧪 Validation du système de catalogue SQLite"
    
    # Vérification des arguments
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
        exit $EXIT_SUCCESS
    fi
    
    # Configuration du trap pour nettoyage
    trap cleanup_test_environment EXIT ERR INT TERM
    
    # Initialisation
    setup_test_environment
    
    # Exécution des tests
    log_info "Début des tests de validation"
    echo ""
    
    test_database_initialization
    test_script_registration  
    test_search_functionality
    test_export_functionality
    test_integrity_performance
    
    # Rapport final
    show_test_report
    
    # Code de sortie selon les résultats
    if [[ $TEST_ERRORS -eq 0 ]]; then
        exit $EXIT_SUCCESS
    else
        exit $EXIT_ERROR_GENERAL
    fi
}

# Exécution
main "$@"