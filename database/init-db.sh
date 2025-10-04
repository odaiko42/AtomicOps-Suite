#!/bin/bash
#
# Script: init-db.sh
# Description: Initialise la base de données SQLite du catalogue de scripts
# Usage: ./init-db.sh [--force]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$SCRIPT_DIR/scripts_catalogue.db"

# Import des bibliothèques
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"

# Variables globales
FORCE=0

# Fonction d'aide
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Initialise la base de données SQLite pour le catalogue de scripts

Options:
  -h, --help      Affiche cette aide
  -f, --force     Force la recréation de la base (supprime l'existante)

Exemples:
  $0              # Initialise la base si elle n'existe pas
  $0 --force      # Recrée complètement la base

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

# Vérifications préalables
validate_prerequisites() {
    log_debug "Validation des prérequis"
    
    # Vérifier SQLite3
    if ! command -v sqlite3 >/dev/null 2>&1; then
        log_error "sqlite3 n'est pas installé"
        log_info "Installation: apt-get install sqlite3"
        exit $EXIT_ERROR_DEPENDENCY
    fi
    
    # Vérifier les permissions d'écriture
    if [[ ! -w "$SCRIPT_DIR" ]]; then
        log_error "Permissions d'écriture insuffisantes dans: $SCRIPT_DIR"
        exit $EXIT_ERROR_PERMISSION
    fi
    
    log_debug "Prérequis validés"
}

# Créer le schéma de base de données
create_database_schema() {
    log_info "Création du schéma de base de données"
    
    sqlite3 "$DB_FILE" <<'EOF'
-- ============================================================================
-- SCHEMA DE BASE DE DONNEES - CATALOGUE DE SCRIPTS CT
-- Version: 1.0.0
-- ============================================================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- Table principale des scripts
CREATE TABLE IF NOT EXISTS scripts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT NOT NULL,
    long_description TEXT,
    version TEXT DEFAULT '1.0.0',
    author TEXT,
    path TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_tested DATETIME,
    documentation_path TEXT,
    complexity_score INTEGER DEFAULT 0,
    
    CHECK (type IN ('atomic', 'orchestrator-1', 'orchestrator-2', 'orchestrator-3', 'orchestrator-4', 'orchestrator-5')),
    CHECK (status IN ('active', 'deprecated', 'experimental', 'disabled'))
);

-- Paramètres d'entrée des scripts
CREATE TABLE IF NOT EXISTS script_parameters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    param_name TEXT NOT NULL,
    param_type TEXT NOT NULL,
    is_required BOOLEAN DEFAULT 0,
    default_value TEXT,
    position INTEGER,
    description TEXT,
    validation_regex TEXT,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, param_name)
);

-- Sorties JSON des scripts
CREATE TABLE IF NOT EXISTS script_outputs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    output_field TEXT NOT NULL,
    field_type TEXT NOT NULL,
    description TEXT,
    parent_field TEXT,
    is_always_present BOOLEAN DEFAULT 1,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

-- Dépendances des scripts
CREATE TABLE IF NOT EXISTS script_dependencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    dependency_type TEXT NOT NULL,
    depends_on_script_id INTEGER,
    depends_on_command TEXT,
    depends_on_library TEXT,
    depends_on_package TEXT,
    is_optional BOOLEAN DEFAULT 0,
    minimum_version TEXT,
    description TEXT,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    FOREIGN KEY (depends_on_script_id) REFERENCES scripts(id) ON DELETE RESTRICT,
    
    CHECK (dependency_type IN ('script', 'command', 'library', 'package')),
    CHECK (
        (dependency_type = 'script' AND depends_on_script_id IS NOT NULL) OR
        (dependency_type = 'command' AND depends_on_command IS NOT NULL) OR  
        (dependency_type = 'library' AND depends_on_library IS NOT NULL) OR
        (dependency_type = 'package' AND depends_on_package IS NOT NULL)
    )
);

-- Codes de sortie documentés
CREATE TABLE IF NOT EXISTS exit_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    exit_code INTEGER NOT NULL,
    code_name TEXT,
    description TEXT NOT NULL,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, exit_code)
);

-- Tags des scripts
CREATE TABLE IF NOT EXISTS script_tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    tag TEXT NOT NULL,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, tag)
);

-- Cas d'usage
CREATE TABLE IF NOT EXISTS use_cases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    use_case_title TEXT NOT NULL,
    use_case_description TEXT NOT NULL,
    example_command TEXT NOT NULL,
    expected_output TEXT,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

-- Historique des versions
CREATE TABLE IF NOT EXISTS version_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    version TEXT NOT NULL,
    release_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    changes_description TEXT NOT NULL,
    breaking_changes BOOLEAN DEFAULT 0,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

-- Statistiques d'utilisation
CREATE TABLE IF NOT EXISTS usage_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    execution_date DATE NOT NULL,
    execution_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    average_duration_ms INTEGER,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    UNIQUE(script_id, execution_date)
);

-- Exemples d'utilisation
CREATE TABLE IF NOT EXISTS script_examples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    example_title TEXT NOT NULL,
    example_description TEXT,
    example_command TEXT NOT NULL,
    expected_result TEXT,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

-- Catalogue des fonctions
CREATE TABLE IF NOT EXISTS functions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    library_file TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT NOT NULL,
    parameters TEXT,
    return_value TEXT,
    example_usage TEXT,
    status TEXT DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(name, library_file),
    CHECK (status IN ('active', 'deprecated'))
);

-- Utilisation des fonctions par les scripts
CREATE TABLE IF NOT EXISTS script_uses_functions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    function_id INTEGER NOT NULL,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    FOREIGN KEY (function_id) REFERENCES functions(id) ON DELETE CASCADE,
    UNIQUE(script_id, function_id)
);

-- Vue: Scripts avec nombre de dépendances
CREATE VIEW IF NOT EXISTS v_scripts_with_dep_count AS
SELECT 
    s.*,
    COALESCE(dep_count.count, 0) as dependency_count
FROM scripts s
LEFT JOIN (
    SELECT script_id, COUNT(*) as count
    FROM script_dependencies
    GROUP BY script_id
) dep_count ON s.id = dep_count.script_id;

-- Vue: Graphe de dépendances
CREATE VIEW IF NOT EXISTS v_dependency_graph AS
SELECT 
    s1.name as script_name,
    s1.type as script_type,
    COALESCE(s2.name, sd.depends_on_command, sd.depends_on_library, sd.depends_on_package) as depends_on,
    sd.dependency_type,
    sd.is_optional
FROM scripts s1
JOIN script_dependencies sd ON s1.id = sd.script_id
LEFT JOIN scripts s2 ON sd.depends_on_script_id = s2.id;

-- Index pour les performances
CREATE INDEX IF NOT EXISTS idx_scripts_type ON scripts(type);
CREATE INDEX IF NOT EXISTS idx_scripts_category ON scripts(category);
CREATE INDEX IF NOT EXISTS idx_scripts_status ON scripts(status);
CREATE INDEX IF NOT EXISTS idx_script_parameters_script_id ON script_parameters(script_id);
CREATE INDEX IF NOT EXISTS idx_script_dependencies_script_id ON script_dependencies(script_id);
CREATE INDEX IF NOT EXISTS idx_script_tags_script_id ON script_tags(script_id);
CREATE INDEX IF NOT EXISTS idx_usage_stats_date ON usage_stats(execution_date);
CREATE INDEX IF NOT EXISTS idx_functions_library ON functions(library_file);

-- Données initiales
INSERT OR IGNORE INTO scripts (name, type, category, description, path) VALUES
('common.sh', 'atomic', 'library', 'Bibliothèque utilitaires de base', 'lib/common.sh'),
('logger.sh', 'atomic', 'library', 'Système de logging centralisé', 'lib/logger.sh'),
('validator.sh', 'atomic', 'library', 'Fonctions de validation', 'lib/validator.sh'),
('ct-common.sh', 'atomic', 'library', 'Fonctions Proxmox CT', 'lib/ct-common.sh'),
('dev-helper.sh', 'atomic', 'development', 'Assistant méthodologique', 'tools/dev-helper.sh'),
('new-atomic.sh', 'atomic', 'development', 'Générateur scripts atomiques', 'tools/new-atomic.sh'),
('new-orchestrator.sh', 'atomic', 'development', 'Générateur orchestrateurs', 'tools/new-orchestrator.sh');

EOF
    
    if [[ $? -eq 0 ]]; then
        log_info "✓ Schéma créé avec succès"
    else
        log_error "✗ Erreur lors de la création du schéma"
        exit $EXIT_ERROR_GENERAL
    fi
}

# Insérer les données de base
populate_initial_data() {
    log_info "Insertion des données initiales"
    
    # Fonctions des bibliothèques
    sqlite3 "$DB_FILE" <<'EOF'
-- Fonctions de lib/common.sh
INSERT OR IGNORE INTO functions (name, library_file, category, description, parameters, return_value) VALUES
('is_command_available', 'lib/common.sh', 'system', 'Vérifie si une commande est disponible', '$1=command_name', '0=disponible, 1=non disponible'),
('cleanup_temp', 'lib/common.sh', 'system', 'Nettoie un fichier temporaire', '$1=file_path', 'void'),
('is_valid_ip', 'lib/common.sh', 'validation', 'Valide une adresse IP', '$1=ip_address', '0=valide, 1=invalide'),
('is_valid_hostname', 'lib/common.sh', 'validation', 'Valide un nom d''hôte', '$1=hostname', '0=valide, 1=invalide'),
('validate_required_params', 'lib/common.sh', 'validation', 'Valide les paramètres requis', '$1=param_name, $2=param_value', '0=valide, 1=invalide');

-- Fonctions de lib/logger.sh
INSERT OR IGNORE INTO functions (name, library_file, category, description, parameters, return_value) VALUES
('init_logging', 'lib/logger.sh', 'logging', 'Initialise le système de logging', '$1=script_name', 'void'),
('log_debug', 'lib/logger.sh', 'logging', 'Log message de debug', '$1=message', 'void'),
('log_info', 'lib/logger.sh', 'logging', 'Log message d''information', '$1=message', 'void'),
('log_warn', 'lib/logger.sh', 'logging', 'Log message d''avertissement', '$1=message', 'void'),
('log_error', 'lib/logger.sh', 'logging', 'Log message d''erreur', '$1=message', 'void'),
('ct_info', 'lib/logger.sh', 'ct_logging', 'Log CT spécialisé info', '$1=message', 'void'),
('ct_warn', 'lib/logger.sh', 'ct_logging', 'Log CT spécialisé warning', '$1=message', 'void'),
('ct_error', 'lib/logger.sh', 'ct_logging', 'Log CT spécialisé error', '$1=message', 'void');

-- Fonctions de lib/validator.sh
INSERT OR IGNORE INTO functions (name, library_file, category, description, parameters, return_value) VALUES
('validate_permissions', 'lib/validator.sh', 'validation', 'Valide les permissions utilisateur', '$1=required_user', '0=OK, 1=insuffisant'),
('validate_dependencies', 'lib/validator.sh', 'validation', 'Valide les dépendances système', '$@=command_list', '0=OK, 1=manquant'),
('validate_ctid', 'lib/validator.sh', 'ct_validation', 'Valide un ID de container', '$1=ctid', '0=valide, 1=invalide'),
('validate_storage_exists', 'lib/validator.sh', 'ct_validation', 'Valide l''existence d''un storage', '$1=storage_name', '0=existe, 1=manquant'),
('validate_block_device', 'lib/validator.sh', 'storage_validation', 'Valide un périphérique bloc', '$1=device_path', '0=valide, 1=invalide');

-- Fonctions de lib/ct-common.sh
INSERT OR IGNORE INTO functions (name, library_file, category, description, parameters, return_value) VALUES
('pick_free_ctid', 'lib/ct-common.sh', 'ct_management', 'Trouve un CTID libre', 'void', 'CTID_number'),
('create_basic_ct', 'lib/ct-common.sh', 'ct_management', 'Crée un container CT basique', '$1=ctid, $2=template, $3=storage', '0=succès, 1=échec'),
('start_and_wait_ct', 'lib/ct-common.sh', 'ct_management', 'Démarre et attend le CT', '$1=ctid', '0=succès, 1=échec'),
('bootstrap_base_inside', 'lib/ct-common.sh', 'ct_management', 'Bootstrap de base dans CT', '$1=ctid', '0=succès, 1=échec'),
('install_docker_inside', 'lib/ct-common.sh', 'ct_management', 'Installe Docker dans CT', '$1=ctid', '0=succès, 1=échec');

EOF
    
    log_info "✓ Données initiales insérées"
}

# Vérifier l'intégrité de la base
verify_database() {
    log_info "Vérification de l'intégrité de la base"
    
    # Test PRAGMA integrity_check
    local integrity_result
    integrity_result=$(sqlite3 "$DB_FILE" "PRAGMA integrity_check;")
    
    if [[ "$integrity_result" == "ok" ]]; then
        log_info "✓ Intégrité OK"
    else
        log_error "✗ Problème d'intégrité: $integrity_result"
        exit $EXIT_ERROR_GENERAL
    fi
    
    # Compter les tables
    local table_count
    table_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    
    log_info "✓ $table_count tables créées"
    
    # Compter les fonctions initiales
    local func_count
    func_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM functions;")
    
    log_info "✓ $func_count fonctions cataloguées"
}

# Afficher un résumé
show_summary() {
    log_info "Base de données initialisée avec succès"
    
    echo ""
    echo "📊 Résumé de la base de données"
    echo "================================"
    echo "📁 Fichier: $DB_FILE"
    echo "📊 Taille: $(du -h "$DB_FILE" | cut -f1)"
    
    echo ""
    echo "📋 Contenu initial:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    'Scripts:' as Type,
    COUNT(*) as Count
FROM scripts
UNION ALL
SELECT 
    'Fonctions:',
    COUNT(*)
FROM functions;
EOF

    echo ""
    echo "🛠️  Prochaines étapes:"
    echo "1. Enregistrer vos scripts: ./tools/register-script.sh"
    echo "2. Rechercher: ./tools/search-db.sh --all"
    echo "3. Voir les stats: ./tools/search-db.sh --stats"
}

# Point d'entrée principal
main() {
    # Initialisation du logging
    init_logging "$(basename "$0")"
    
    log_info "🗄️  Initialisation de la base de données SQLite"
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation
    validate_prerequisites
    
    # Vérifier si la base existe déjà
    if [[ -f "$DB_FILE" ]]; then
        if [[ $FORCE -eq 1 ]]; then
            log_warn "Suppression de la base existante (--force)"
            rm -f "$DB_FILE"
        else
            log_error "Base de données existante: $DB_FILE"
            log_info "Utilisez --force pour recréer"
            exit $EXIT_ERROR_GENERAL
        fi
    fi
    
    # Création
    create_database_schema
    populate_initial_data
    verify_database
    show_summary
    
    log_info "✅ Initialisation terminée avec succès"
}

# Exécution
main "$@"