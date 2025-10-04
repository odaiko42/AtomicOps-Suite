#!/bin/bash
#
# Script: register-all-scripts.sh
# Description: Enregistre automatiquement tous les scripts du projet dans la base
# Usage: ./register-all-scripts.sh [--force]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"

# Import des bibliothèques
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"

# Variables globales
FORCE=0

# Fonction d'aide
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Enregistre automatiquement tous les scripts du projet dans la base de données

Options:
  -h, --help      Affiche cette aide
  -f, --force     Force la mise à jour des scripts existants

Exemples:
  $0              # Enregistre les nouveaux scripts seulement
  $0 --force      # Met à jour tous les scripts

EOF
}

# Parsing des arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit $EXIT_SUCCESS
                ;;
            -f|--force)
                FORCE=1
                shift
                ;;
            *)
                log_error "Option inconnue: $1"
                show_help >&2
                exit $EXIT_ERROR_USAGE
                ;;
        esac
    done
}

# Validation des prérequis
validate_prerequisites() {
    log_debug "Validation des prérequis"
    
    # Vérifier SQLite3
    if ! command -v sqlite3 >/dev/null 2>&1; then
        log_error "sqlite3 n'est pas installé"
        exit $EXIT_ERROR_DEPENDENCY
    fi
    
    # Vérifier que la base existe
    if [[ ! -f "$DB_FILE" ]]; then
        log_error "Base de données non trouvée: $DB_FILE"
        log_info "Initialisez la base: $PROJECT_ROOT/database/init-db.sh"
        exit $EXIT_ERROR_NOT_FOUND
    fi
    
    # Vérifier le script d'enregistrement
    local register_script="$PROJECT_ROOT/tools/register-script.sh"
    if [[ ! -x "$register_script" ]]; then
        log_error "Script d'enregistrement non trouvé ou non exécutable: $register_script"
        exit $EXIT_ERROR_NOT_FOUND
    fi
    
    log_debug "Prérequis validés"
}

# Trouver tous les scripts du projet
find_all_scripts() {
    log_info "🔍 Recherche de tous les scripts du projet"
    
    local script_files=()
    
    # Chercher dans les répertoires principaux
    local search_dirs=("lib" "tools" "atomics" "orchestrators" "templates")
    
    for dir in "${search_dirs[@]}"; do
        if [[ -d "$PROJECT_ROOT/$dir" ]]; then
            while IFS= read -r -d '' script_file; do
                # Chemin relatif depuis PROJECT_ROOT
                local relative_path="${script_file#$PROJECT_ROOT/}"
                
                # Ignorer certains fichiers
                case "$relative_path" in
                    "tools/register-script.sh"|"tools/register-all-scripts.sh"|"tools/search-db.sh")
                        log_debug "Ignoré (script système): $relative_path"
                        continue
                        ;;
                    "templates/"*)
                        log_debug "Ignoré (template): $relative_path"
                        continue
                        ;;
                esac
                
                script_files+=("$relative_path")
                log_debug "Trouvé: $relative_path"
            done < <(find "$PROJECT_ROOT/$dir" -name "*.sh" -type f -print0 2>/dev/null)
        fi
    done
    
    printf '%s\n' "${script_files[@]}"
}

# Enregistrer un script avec gestion d'erreurs
register_single_script() {
    local script_path="$1"
    local register_script="$PROJECT_ROOT/tools/register-script.sh"
    
    log_info "📝 Enregistrement: $script_path"
    
    # Vérifier si le script existe déjà dans la base
    local script_name=$(basename "$script_path")
    local existing_id
    existing_id=$(sqlite3 "$DB_FILE" "SELECT id FROM scripts WHERE name = '$script_name';" 2>/dev/null || echo "")
    
    if [[ -n "$existing_id" && $FORCE -eq 0 ]]; then
        log_debug "Déjà enregistré (ID: $existing_id): $script_name"
        return 0
    fi
    
    # Enregistrer le script
    local register_args="--auto"
    if [[ $FORCE -eq 1 ]]; then
        register_args="$register_args"  # --auto implique déjà la mise à jour
    fi
    
    if "$register_script" "$script_path" $register_args >/dev/null 2>&1; then
        if [[ -n "$existing_id" ]]; then
            log_info "✓ Mis à jour: $script_name"
        else
            log_info "✓ Enregistré: $script_name"
        fi
        return 0
    else
        local exit_code=$?
        log_warn "✗ Échec enregistrement: $script_name (code: $exit_code)"
        return $exit_code
    fi
}

# Traiter tous les scripts
process_all_scripts() {
    log_info "📋 Enregistrement de tous les scripts"
    
    local all_scripts
    mapfile -t all_scripts < <(find_all_scripts)
    
    local total=${#all_scripts[@]}
    local success=0
    local errors=0
    local skipped=0
    
    log_info "Scripts trouvés: $total"
    
    if [[ $total -eq 0 ]]; then
        log_warn "Aucun script trouvé à enregistrer"
        return 0
    fi
    
    echo ""
    for script_path in "${all_scripts[@]}"; do
        if register_single_script "$script_path"; then
            success=$((success + 1))
        else
            errors=$((errors + 1))
        fi
    done
    
    echo ""
    log_info "📊 Résumé du traitement:"
    log_info "  Total: $total"
    log_info "  Succès: $success"
    log_info "  Erreurs: $errors"
    
    if [[ $errors -gt 0 ]]; then
        log_warn "Certains scripts n'ont pas pu être enregistrés"
        return 1
    fi
    
    return 0
}

# Enregistrer les fonctions des bibliothèques
register_library_functions() {
    log_info "📚 Enregistrement des fonctions des bibliothèques"
    
    # Les fonctions sont déjà insérées lors de l'initialisation de la base
    # Cette fonction pourrait analyser automatiquement les fichiers lib/*.sh
    # pour extraire les fonctions définies et les enregistrer
    
    local lib_dir="$PROJECT_ROOT/lib"
    if [[ ! -d "$lib_dir" ]]; then
        log_debug "Répertoire lib/ non trouvé"
        return 0
    fi
    
    local func_count=0
    
    for lib_file in "$lib_dir"/*.sh; do
        if [[ -f "$lib_file" ]]; then
            local lib_name=$(basename "$lib_file")
            log_debug "Analyse des fonctions dans: $lib_name"
            
            # Rechercher les fonctions définies (pattern: function_name() {)
            while IFS= read -r line; do
                if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)[[:space:]]*\{ ]]; then
                    local func_name="${BASH_REMATCH[1]}"
                    
                    # Ignorer certaines fonctions système
                    case "$func_name" in
                        "main"|"show_help"|"parse_args"|"cleanup"|"validate_prerequisites")
                            continue
                            ;;
                    esac
                    
                    # Vérifier si la fonction n'existe pas déjà
                    local existing_func
                    existing_func=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM functions WHERE name = '$func_name' AND library_file = '$lib_name';" 2>/dev/null || echo "0")
                    
                    if [[ "$existing_func" -eq 0 ]]; then
                        # Tenter d'extraire un commentaire de description
                        local description="Fonction de $lib_name"
                        
                        # Insérer la fonction
                        sqlite3 "$DB_FILE" <<EOF >/dev/null 2>&1
INSERT OR IGNORE INTO functions (name, library_file, category, description, status) 
VALUES ('$func_name', '$lib_name', 'extracted', '$description', 'active');
EOF
                        
                        if [[ $? -eq 0 ]]; then
                            log_debug "Fonction ajoutée: $func_name"
                            func_count=$((func_count + 1))
                        fi
                    fi
                fi
            done < "$lib_file"
        fi
    done
    
    if [[ $func_count -gt 0 ]]; then
        log_info "✓ $func_count nouvelles fonctions détectées et enregistrées"
    else
        log_debug "Aucune nouvelle fonction trouvée"
    fi
}

# Afficher un résumé final
show_final_summary() {
    log_info "📊 Résumé final du catalogue"
    
    echo ""
    echo "Base de données: $DB_FILE"
    echo "Taille: $(du -h "$DB_FILE" | cut -f1)"
    
    echo ""
    echo "Contenu:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    'Scripts:' as Type,
    COUNT(*) as Nombre
FROM scripts
UNION ALL
SELECT 
    'Fonctions:',
    COUNT(*)
FROM functions
UNION ALL
SELECT 
    'Dépendances:',
    COUNT(*)
FROM script_dependencies;
EOF
    
    echo ""
    echo "Par type de script:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    type as Type,
    COUNT(*) as Nombre
FROM scripts
GROUP BY type
ORDER BY type;
EOF
    
    echo ""
    log_info "🎉 Catalogue mis à jour avec succès!"
    log_info ""
    log_info "Prochaines étapes:"
    log_info "  • Rechercher: ./tools/search-db.sh --all"
    log_info "  • Statistiques: ./tools/search-db.sh --stats"
    log_info "  • Détails d'un script: ./tools/search-db.sh --info <script>"
}

# Point d'entrée principal
main() {
    # Initialisation du logging
    init_logging "$(basename "$0")"
    
    log_info "🗂️  Enregistrement automatique de tous les scripts"
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation
    validate_prerequisites
    
    # Traitement
    if process_all_scripts; then
        register_library_functions
        show_final_summary
        
        log_info "✅ Enregistrement automatique terminé avec succès"
        exit $EXIT_SUCCESS
    else
        log_error "❌ Échec de l'enregistrement automatique"
        exit $EXIT_ERROR_GENERAL
    fi
}

# Exécution
main "$@"