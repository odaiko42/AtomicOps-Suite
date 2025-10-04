#!/bin/bash
#
# Script: export-db.sh
# Description: Exporte la base de données catalogue dans différents formats
# Usage: ./export-db.sh [format] [--output-dir DIR]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"

# Import des bibliothèques
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"

# Variables globales
FORMAT="all"
OUTPUT_DIR="$PROJECT_ROOT/exports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Fonction d'aide
show_help() {
    cat <<EOF
Usage: $0 [FORMAT] [OPTIONS]

Exporte la base de données catalogue dans différents formats

Formats disponibles:
  sql         Dump SQL complet de la base
  csv         Export CSV de toutes les tables
  json        Export JSON structuré
  markdown    Documentation Markdown
  backup      Copie de sauvegarde de la base
  all         Tous les formats (défaut)

Options:
  -o, --output-dir DIR    Répertoire de sortie (défaut: exports/)
  -h, --help              Affiche cette aide

Exemples:
  $0                      # Export complet (tous formats)
  $0 json                 # Export JSON uniquement
  $0 backup -o /backups   # Backup dans répertoire spécifique

EOF
}

# Parsing des arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            sql|csv|json|markdown|backup|all)
                FORMAT="$1"
                shift
                ;;
            -o|--output-dir)
                if [[ $# -lt 2 ]]; then
                    log_error "Répertoire requis pour --output-dir"
                    exit $EXIT_ERROR_USAGE
                fi
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit $EXIT_SUCCESS
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
    
    # Vérifier la base de données
    if [[ ! -f "$DB_FILE" ]]; then
        log_error "Base de données non trouvée: $DB_FILE"
        exit $EXIT_ERROR_NOT_FOUND
    fi
    
    # Créer le répertoire de sortie
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        mkdir -p "$OUTPUT_DIR"
        log_debug "Répertoire créé: $OUTPUT_DIR"
    fi
    
    # Vérifier les permissions d'écriture
    if [[ ! -w "$OUTPUT_DIR" ]]; then
        log_error "Permissions d'écriture insuffisantes: $OUTPUT_DIR"
        exit $EXIT_ERROR_PERMISSION
    fi
    
    log_debug "Prérequis validés"
}

# Export SQL complet
export_sql() {
    local output_file="$OUTPUT_DIR/catalogue_${TIMESTAMP}.sql"
    
    log_info "📄 Export SQL vers: $(basename "$output_file")"
    
    sqlite3 "$DB_FILE" .dump > "$output_file"
    
    if [[ $? -eq 0 ]]; then
        log_info "✓ Export SQL terminé ($(du -h "$output_file" | cut -f1))"
        echo "$output_file"
    else
        log_error "✗ Échec export SQL"
        return 1
    fi
}

# Export CSV de toutes les tables
export_csv() {
    local csv_dir="$OUTPUT_DIR/csv_${TIMESTAMP}"
    
    log_info "📊 Export CSV vers: $(basename "$csv_dir")"
    
    mkdir -p "$csv_dir"
    
    # Lister toutes les tables (hors système SQLite)
    local tables
    mapfile -t tables < <(sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;")
    
    local table_count=0
    
    for table in "${tables[@]}"; do
        local csv_file="$csv_dir/${table}.csv"
        
        sqlite3 -header -csv "$DB_FILE" "SELECT * FROM $table;" > "$csv_file"
        
        if [[ $? -eq 0 ]]; then
            local row_count
            row_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM $table;")
            log_debug "✓ Table $table: $row_count lignes"
            table_count=$((table_count + 1))
        else
            log_warn "✗ Échec export table: $table"
        fi
    done
    
    log_info "✓ Export CSV terminé ($table_count tables)"
    echo "$csv_dir"
}

# Export JSON structuré
export_json() {
    local output_file="$OUTPUT_DIR/catalogue_${TIMESTAMP}.json"
    
    log_info "📋 Export JSON vers: $(basename "$output_file")"
    
    # Construction du JSON avec informations complètes
    sqlite3 "$DB_FILE" <<EOF | jq . > "$output_file" 2>/dev/null
SELECT json_object(
    'export_metadata', json_object(
        'export_date', datetime('now'),
        'timestamp', '$TIMESTAMP',
        'version', '1.0.0',
        'database_file', '$(basename "$DB_FILE")',
        'total_scripts', (SELECT COUNT(*) FROM scripts),
        'total_functions', (SELECT COUNT(*) FROM functions)
    ),
    'scripts', (
        SELECT json_group_array(
            json_object(
                'id', id,
                'name', name,
                'type', type,
                'category', category,
                'description', description,
                'version', version,
                'author', author,
                'path', path,
                'status', status,
                'created_at', created_at,
                'updated_at', updated_at,
                'complexity_score', complexity_score,
                'parameters', (
                    SELECT json_group_array(
                        json_object(
                            'name', param_name,
                            'type', param_type,
                            'required', is_required,
                            'default', default_value,
                            'description', description
                        )
                    )
                    FROM script_parameters WHERE script_id = scripts.id
                ),
                'dependencies', (
                    SELECT json_group_array(
                        json_object(
                            'type', dependency_type,
                            'target', COALESCE(
                                (SELECT name FROM scripts WHERE id = depends_on_script_id),
                                depends_on_command,
                                depends_on_library,
                                depends_on_package
                            ),
                            'optional', is_optional,
                            'description', description
                        )
                    )
                    FROM script_dependencies WHERE script_id = scripts.id
                ),
                'exit_codes', (
                    SELECT json_group_array(
                        json_object(
                            'code', exit_code,
                            'name', code_name,
                            'description', description
                        )
                    )
                    FROM exit_codes WHERE script_id = scripts.id
                )
            )
        )
        FROM scripts ORDER BY type, name
    ),
    'functions', (
        SELECT json_group_array(
            json_object(
                'id', id,
                'name', name,
                'library_file', library_file,
                'category', category,
                'description', description,
                'parameters', parameters,
                'return_value', return_value,
                'example_usage', example_usage,
                'status', status
            )
        )
        FROM functions ORDER BY library_file, name
    ),
    'statistics', json_object(
        'scripts_by_type', (
            SELECT json_group_object(type, COUNT(*))
            FROM scripts GROUP BY type
        ),
        'scripts_by_category', (
            SELECT json_group_object(category, COUNT(*))
            FROM scripts GROUP BY category
        ),
        'functions_by_library', (
            SELECT json_group_object(library_file, COUNT(*))
            FROM functions GROUP BY library_file
        )
    )
);
EOF
    
    if [[ $? -eq 0 && -f "$output_file" ]]; then
        log_info "✓ Export JSON terminé ($(du -h "$output_file" | cut -f1))"
        echo "$output_file"
    else
        log_error "✗ Échec export JSON (jq requis)"
        return 1
    fi
}

# Export Markdown (documentation)
export_markdown() {
    local output_file="$OUTPUT_DIR/catalogue_${TIMESTAMP}.md"
    
    log_info "📖 Export Markdown vers: $(basename "$output_file")"
    
    # En-tête du document
    cat > "$output_file" <<EOF
# 📚 Catalogue de Scripts - Framework CT

**Généré le :** $(date '+%d/%m/%Y à %H:%M:%S')  
**Base de données :** $(basename "$DB_FILE")

## 📊 Statistiques Générales

EOF
    
    # Statistiques
    sqlite3 "$DB_FILE" <<EOSQL >> "$output_file"
.mode markdown
SELECT 
    'Type' as 'Catégorie',
    'Nombre' as 'Scripts'
UNION ALL
SELECT type, COUNT(*) FROM scripts GROUP BY type
UNION ALL  
SELECT '**Total**', COUNT(*) FROM scripts;
EOSQL
    
    # Scripts atomiques
    cat >> "$output_file" <<EOF

## ⚛️ Scripts Atomiques

EOF
    
    sqlite3 "$DB_FILE" <<EOSQL >> "$output_file"
SELECT 
    '### ' || name || char(10) ||
    '**Catégorie :** ' || category || char(10) ||
    '**Description :** ' || description || char(10) ||
    '**Chemin :** \`' || path || '\`' || char(10) ||
    CASE WHEN author IS NOT NULL THEN '**Auteur :** ' || author || char(10) ELSE '' END ||
    char(10)
FROM scripts 
WHERE type = 'atomic' 
ORDER BY category, name;
EOSQL
    
    # Orchestrateurs
    cat >> "$output_file" <<EOF

## 🎭 Orchestrateurs

EOF
    
    sqlite3 "$DB_FILE" <<EOSQL >> "$output_file"
SELECT 
    '### ' || name || char(10) ||
    '**Niveau :** ' || type || char(10) ||
    '**Catégorie :** ' || category || char(10) ||
    '**Description :** ' || description || char(10) ||
    '**Chemin :** \`' || path || '\`' || char(10) ||
    char(10)
FROM scripts 
WHERE type LIKE 'orchestrator%' 
ORDER BY type, category, name;
EOSQL
    
    # Fonctions des bibliothèques
    cat >> "$output_file" <<EOF

## 📚 Fonctions des Bibliothèques

EOF
    
    sqlite3 "$DB_FILE" <<EOSQL >> "$output_file"
SELECT 
    '### ' || library_file || char(10) ||
    char(10) ||
    GROUP_CONCAT(
        '- **' || name || '()** : ' || description ||
        CASE WHEN parameters IS NOT NULL THEN char(10) || '  - *Paramètres :* ' || parameters ELSE '' END ||
        CASE WHEN return_value IS NOT NULL THEN char(10) || '  - *Retour :* ' || return_value ELSE '' END,
        char(10)
    ) || char(10) || char(10)
FROM functions 
WHERE status = 'active'
GROUP BY library_file 
ORDER BY library_file;
EOSQL
    
    # Graphe de dépendances (simplifié)
    cat >> "$output_file" <<EOF

## 🔗 Graphe de Dépendances (Top 10)

EOF
    
    sqlite3 "$DB_FILE" <<EOSQL >> "$output_file"
.mode markdown
SELECT 
    script_name as 'Script',
    depends_on as 'Dépend de',
    dependency_type as 'Type'
FROM v_dependency_graph 
ORDER BY script_name 
LIMIT 10;
EOSQL
    
    # Pied de page
    cat >> "$output_file" <<EOF

---

**Généré automatiquement par :** \`tools/export-db.sh\`  
**Framework CT Version :** $(cat "$PROJECT_ROOT/VERSION" 2>/dev/null || echo "1.0.0")  
**Documentation complète :** [README.md](../README.md)
EOF
    
    log_info "✓ Export Markdown terminé ($(du -h "$output_file" | cut -f1))"
    echo "$output_file"
}

# Backup de la base
backup_database() {
    local backup_file="$OUTPUT_DIR/backup_${TIMESTAMP}.db"
    
    log_info "💾 Backup vers: $(basename "$backup_file")"
    
    cp "$DB_FILE" "$backup_file"
    
    if [[ $? -eq 0 ]]; then
        log_info "✓ Backup terminé ($(du -h "$backup_file" | cut -f1))"
        echo "$backup_file"
    else
        log_error "✗ Échec backup"
        return 1
    fi
}

# Exécution selon le format
execute_export() {
    local exported_files=()
    
    case $FORMAT in
        sql)
            if exported_files+=($(export_sql)); then
                log_info "Export SQL réussi"
            fi
            ;;
        csv)
            if exported_files+=($(export_csv)); then
                log_info "Export CSV réussi"
            fi
            ;;
        json)
            if exported_files+=($(export_json)); then
                log_info "Export JSON réussi"
            fi
            ;;
        markdown)
            if exported_files+=($(export_markdown)); then
                log_info "Export Markdown réussi"
            fi
            ;;
        backup)
            if exported_files+=($(backup_database)); then
                log_info "Backup réussi"
            fi
            ;;
        all)
            log_info "Export complet (tous formats)"
            
            export_sql && exported_files+=($(export_sql)) || log_warn "Échec export SQL"
            export_csv && exported_files+=($(export_csv)) || log_warn "Échec export CSV"
            export_json && exported_files+=($(export_json)) || log_warn "Échec export JSON"
            export_markdown && exported_files+=($(export_markdown)) || log_warn "Échec export Markdown"
            backup_database && exported_files+=($(backup_database)) || log_warn "Échec backup"
            ;;
        *)
            log_error "Format inconnu: $FORMAT"
            log_info "Formats disponibles: sql, csv, json, markdown, backup, all"
            exit $EXIT_ERROR_USAGE
            ;;
    esac
    
    # Résumé
    echo ""
    log_info "📋 Résumé de l'export"
    log_info "Format: $FORMAT"
    log_info "Répertoire: $OUTPUT_DIR"
    log_info "Fichiers créés: ${#exported_files[@]}"
    
    for file in "${exported_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_info "  ✓ $(basename "$file") ($(du -h "$file" | cut -f1))"
        elif [[ -d "$file" ]]; then
            local file_count=$(find "$file" -type f | wc -l)
            log_info "  ✓ $(basename "$file")/ ($file_count fichiers)"
        fi
    done
}

# Point d'entrée principal  
main() {
    # Initialisation du logging
    init_logging "$(basename "$0")"
    
    log_info "📤 Export de la base de données catalogue"
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation
    validate_prerequisites
    
    # Exécution
    execute_export
    
    log_info "✅ Export terminé avec succès"
}

# Exécution
main "$@"