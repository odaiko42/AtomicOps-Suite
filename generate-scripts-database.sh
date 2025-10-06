#!/usr/bin/env bash

# ==============================================================================
# Script: generate-scripts-database.sh
# Description: Génère une base de données SQLite avec tous les scripts catalogués
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-06
# ==============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_FILE="$SCRIPT_DIR/scripts-catalog.db"
ATOMICS_DIR="$SCRIPT_DIR/atomics"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Vérifier les dépendances
check_dependencies() {
    if ! command -v sqlite3 >/dev/null 2>&1; then
        log_error "sqlite3 is not installed"
        exit 1
    fi
}

# Créer le schéma de base de données
create_database_schema() {
    log_info "Creating database schema..."
    
    sqlite3 "$DATABASE_FILE" << 'EOF'
-- Table principale des scripts
CREATE TABLE IF NOT EXISTS scripts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT NOT NULL,
    long_description TEXT,
    version TEXT DEFAULT '1.0.0',
    author TEXT DEFAULT 'AtomicOps-Suite',
    path TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_tested DATETIME,
    documentation_path TEXT,
    complexity_score INTEGER DEFAULT 5,
    implementation_date DATE,
    
    CHECK (type IN ('atomic', 'orchestrator-1', 'orchestrator-2', 'orchestrator-3', 'orchestrator-4', 'orchestrator-5')),
    CHECK (status IN ('active', 'deprecated', 'experimental', 'disabled', 'implemented'))
);

-- Paramètres des scripts
CREATE TABLE IF NOT EXISTS script_parameters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    param_name TEXT NOT NULL,
    param_type TEXT NOT NULL,
    is_required BOOLEAN DEFAULT 0,
    default_value TEXT,
    description TEXT,
    validation_pattern TEXT,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    CHECK (param_type IN ('string', 'integer', 'boolean', 'file_path', 'directory_path', 'ip_address', 'url', 'email'))
);

-- Sorties des scripts  
CREATE TABLE IF NOT EXISTS script_outputs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    output_type TEXT NOT NULL,
    output_format TEXT NOT NULL,
    description TEXT,
    example_value TEXT,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    CHECK (output_type IN ('json', 'text', 'file', 'exit_code', 'log')),
    CHECK (output_format IN ('structured_json', 'plain_text', 'csv', 'xml', 'binary'))
);

-- Dépendances des scripts
CREATE TABLE IF NOT EXISTS script_dependencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    dependency_type TEXT NOT NULL,
    dependency_name TEXT NOT NULL,
    dependency_version TEXT,
    is_optional BOOLEAN DEFAULT 0,
    installation_command TEXT,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    CHECK (dependency_type IN ('system_command', 'package', 'service', 'library', 'script'))
);

-- Tags et catégories
CREATE TABLE IF NOT EXISTS script_tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    tag_name TEXT NOT NULL,
    tag_category TEXT,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

-- Compatibilité OS/distributions
CREATE TABLE IF NOT EXISTS script_compatibility (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    os_family TEXT NOT NULL,
    distribution TEXT,
    version_min TEXT,
    version_max TEXT,
    compatibility_level TEXT NOT NULL,
    notes TEXT,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    CHECK (os_family IN ('linux', 'unix', 'darwin', 'windows')),
    CHECK (compatibility_level IN ('full', 'partial', 'requires_adaptation', 'not_supported'))
);

-- Statistiques d'utilisation
CREATE TABLE IF NOT EXISTS script_usage_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    execution_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    execution_time_ms INTEGER,
    success BOOLEAN,
    error_message TEXT,
    user_context TEXT,
    
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

-- Index pour optimiser les requêtes
CREATE INDEX IF NOT EXISTS idx_scripts_type ON scripts(type);
CREATE INDEX IF NOT EXISTS idx_scripts_category ON scripts(category);
CREATE INDEX IF NOT EXISTS idx_scripts_status ON scripts(status);
CREATE INDEX IF NOT EXISTS idx_script_tags_name ON script_tags(tag_name);
CREATE INDEX IF NOT EXISTS idx_compatibility_os ON script_compatibility(os_family);
CREATE INDEX IF NOT EXISTS idx_usage_date ON script_usage_stats(execution_date);

EOF

    log_success "Database schema created successfully"
}

# Analyser un fichier script pour extraire les métadonnées
analyze_script_file() {
    local script_path="$1"
    local script_name
    script_name=$(basename "$script_path")
    
    # Extraire les métadonnées du header
    local description version author
    description=$(grep -m1 "^# Description:" "$script_path" 2>/dev/null | sed 's/^# Description: //' || echo "Script atomique")
    version=$(grep -m1 "^# Version:" "$script_path" 2>/dev/null | sed 's/^# Version: //' || echo "1.0")
    author=$(grep -m1 "^# Author:" "$script_path" 2>/dev/null | sed 's/^# Author: //' || echo "AtomicOps-Suite")
    
    # Détecter la catégorie basée sur le nom
    local category="system"
    case "$script_name" in
        *docker*|*compose*|*container*) category="container" ;;
        *kvm*|*vm*|*snapshot*) category="virtualization" ;;
        *network*|*ping*|*speed*) category="network" ;;
        *disk*|*partition*|*mount*) category="storage" ;;
        *user*|*password*|*unlock*) category="user_management" ;;
        *package*|*update*|*upgrade*) category="package_management" ;;
        *sync*|*directory*|*rsync*) category="synchronization" ;;
        *postgresql*|*database*|*vacuum*) category="database" ;;
        *lxc*|*lxd*) category="container" ;;
        *service*|*systemd*) category="service_management" ;;
    esac
    
    # Calculer le score de complexité (basé sur la taille du fichier et le nombre de fonctions)
    local file_size function_count complexity_score
    file_size=$(wc -l < "$script_path")
    function_count=$(grep -c "^[a-zA-Z_][a-zA-Z0-9_]*() {" "$script_path" 2>/dev/null || echo 0)
    complexity_score=$(( (file_size / 50) + (function_count / 2) ))
    complexity_score=$((complexity_score > 10 ? 10 : complexity_score))
    complexity_score=$((complexity_score < 1 ? 1 : complexity_score))
    
    echo "$script_name|atomic|$category|$description|$version|$author|$script_path|$complexity_score"
}

# Insérer les données des scripts dans la base
populate_scripts_data() {
    log_info "Analyzing and inserting script data..."
    
    # Scripts implémentés (23 nouveaux scripts)
    local implemented_scripts=(
        "snapshot-kvm.vm.sh"
        "start-compose.stack.sh"
        "start-docker.container.sh"
        "start-kvm.vm.sh"
        "start-lxc.container.sh"
        "stop-compose.stack.sh"
        "stop-docker.container.sh"
        "stop-kvm.vm.sh"
        "sync-directory.bidirectional.sh"
        "sync-directory.rsync.sh"
        "test-network.speed.sh"
        "unlock-user.sh"
        "unmount-disk.partition.sh"
        "update-package.all.yum.sh"
        "update-package.list.apt.sh"
        "upgrade-package.all.apt.sh"
        "vacuum-postgresql.database.sh"
    )
    
    # Analyser tous les scripts du répertoire atomics
    if [[ -d "$ATOMICS_DIR" ]]; then
        for script_file in "$ATOMICS_DIR"/*.sh; do
            if [[ -f "$script_file" ]]; then
                local script_info
                script_info=$(analyze_script_file "$script_file")
                
                IFS='|' read -r name type category description version author path complexity <<< "$script_info"
                
                # Déterminer le statut
                local status="active"
                local implementation_date=""
                for impl_script in "${implemented_scripts[@]}"; do
                    if [[ "$name" == "$impl_script" ]]; then
                        status="implemented"
                        implementation_date="2025-10-06"
                        break
                    fi
                done
                
                # Insérer dans la base de données
                sqlite3 "$DATABASE_FILE" << EOF
INSERT OR REPLACE INTO scripts (
    name, type, category, description, version, author, path, 
    status, complexity_score, implementation_date, updated_at
) VALUES (
    '$name', '$type', '$category', '$description', '$version', '$author', 
    '$path', '$status', $complexity, '$implementation_date', CURRENT_TIMESTAMP
);
EOF
                
                log_info "Added script: $name ($status)"
            fi
        done
    fi
    
    # Ajouter des scripts planifiés mais non encore implémentés
    local planned_scripts=(
        "backup-mysql.database.sh|database|Sauvegarde base MySQL"
        "create-lvm.volume.sh|storage|Création volume LVM"
        "monitor-cpu.usage.sh|monitoring|Surveillance CPU"
        "setup-firewall.iptables.sh|security|Configuration iptables"
        "deploy-nginx.config.sh|web|Déploiement Nginx"
        "analyze-log.apache.sh|logging|Analyse logs Apache"
        "compress-directory.tar.sh|archiving|Compression tar"
        "validate-ssl.certificate.sh|security|Validation SSL"
        "rotate-backup.cleanup.sh|backup|Nettoyage sauvegardes"
        "optimize-mysql.performance.sh|database|Optimisation MySQL"
    )
    
    for planned in "${planned_scripts[@]}"; do
        IFS='|' read -r name category desc <<< "$planned"
        sqlite3 "$DATABASE_FILE" << EOF
INSERT OR REPLACE INTO scripts (
    name, type, category, description, version, author, path, 
    status, complexity_score, updated_at
) VALUES (
    '$name', 'atomic', '$category', '$desc', '1.0', 'AtomicOps-Suite', 
    'atomics/$name', 'planned', 5, CURRENT_TIMESTAMP
);
EOF
    done
    
    log_success "Script data populated successfully"
}

# Ajouter les données de compatibilité
add_compatibility_data() {
    log_info "Adding compatibility data..."
    
    sqlite3 "$DATABASE_FILE" << 'EOF'
-- Compatibilité pour les scripts Docker
INSERT INTO script_compatibility (script_id, os_family, distribution, compatibility_level, notes)
SELECT id, 'linux', 'ubuntu', 'full', 'Docker natif supporté' 
FROM scripts WHERE name LIKE '%docker%' OR name LIKE '%compose%';

INSERT INTO script_compatibility (script_id, os_family, distribution, compatibility_level, notes)
SELECT id, 'linux', 'debian', 'full', 'Docker natif supporté' 
FROM scripts WHERE name LIKE '%docker%' OR name LIKE '%compose%';

INSERT INTO script_compatibility (script_id, os_family, distribution, compatibility_level, notes)
SELECT id, 'linux', 'centos', 'full', 'Docker CE supporté' 
FROM scripts WHERE name LIKE '%docker%' OR name LIKE '%compose%';

-- Compatibilité pour les scripts APT (Debian/Ubuntu uniquement)
INSERT INTO script_compatibility (script_id, os_family, distribution, compatibility_level, notes)
SELECT id, 'linux', 'ubuntu', 'full', 'Gestionnaire de paquets natif' 
FROM scripts WHERE name LIKE '%apt%';

INSERT INTO script_compatibility (script_id, os_family, distribution, compatibility_level, notes)
SELECT id, 'linux', 'debian', 'full', 'Gestionnaire de paquets natif' 
FROM scripts WHERE name LIKE '%apt%';

INSERT INTO script_compatibility (script_id, os_family, distribution, compatibility_level, notes)
SELECT id, 'linux', 'centos', 'not_supported', 'Utilise YUM/DNF' 
FROM scripts WHERE name LIKE '%apt%';

-- Compatibilité pour les scripts YUM (RHEL/CentOS)
INSERT INTO script_compatibility (script_id, os_family, distribution, compatibility_level, notes)
SELECT id, 'linux', 'centos', 'full', 'Gestionnaire de paquets natif' 
FROM scripts WHERE name LIKE '%yum%';

INSERT INTO script_compatibility (script_id, os_family, distribution, compatibility_level, notes)
SELECT id, 'linux', 'rhel', 'full', 'Gestionnaire de paquets natif' 
FROM scripts WHERE name LIKE '%yum%';

INSERT INTO script_compatibility (script_id, os_family, distribution, compatibility_level, notes)
SELECT id, 'linux', 'fedora', 'full', 'DNF supporté' 
FROM scripts WHERE name LIKE '%yum%';

-- Compatibilité universelle pour les scripts réseau
INSERT INTO script_compatibility (script_id, os_family, distribution, compatibility_level, notes)
SELECT id, 'linux', NULL, 'full', 'Compatible toutes distributions Linux' 
FROM scripts WHERE name LIKE '%network%' AND name NOT LIKE '%apt%' AND name NOT LIKE '%yum%';

EOF

    log_success "Compatibility data added"
}

# Ajouter les tags pour classification
add_script_tags() {
    log_info "Adding script tags..."
    
    sqlite3 "$DATABASE_FILE" << 'EOF'
-- Tags pour containerisation
INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'docker', 'technology' FROM scripts WHERE name LIKE '%docker%';

INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'compose', 'technology' FROM scripts WHERE name LIKE '%compose%';

INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'container', 'category' FROM scripts WHERE name LIKE '%docker%' OR name LIKE '%lxc%' OR name LIKE '%container%';

-- Tags pour virtualisation
INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'kvm', 'technology' FROM scripts WHERE name LIKE '%kvm%';

INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'virtualization', 'category' FROM scripts WHERE name LIKE '%kvm%' OR name LIKE '%vm%';

INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'snapshot', 'feature' FROM scripts WHERE name LIKE '%snapshot%';

-- Tags pour réseau
INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'network', 'category' FROM scripts WHERE name LIKE '%network%';

INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'speed-test', 'feature' FROM scripts WHERE name LIKE '%speed%';

-- Tags pour stockage
INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'storage', 'category' FROM scripts WHERE name LIKE '%disk%' OR name LIKE '%mount%' OR name LIKE '%partition%';

INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'synchronization', 'category' FROM scripts WHERE name LIKE '%sync%';

INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'rsync', 'technology' FROM scripts WHERE name LIKE '%rsync%';

-- Tags pour gestion utilisateurs
INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'user-management', 'category' FROM scripts WHERE name LIKE '%user%';

INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'security', 'category' FROM scripts WHERE name LIKE '%unlock%' OR name LIKE '%password%';

-- Tags pour bases de données
INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'database', 'category' FROM scripts WHERE name LIKE '%postgresql%' OR name LIKE '%mysql%' OR name LIKE '%database%';

INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'postgresql', 'technology' FROM scripts WHERE name LIKE '%postgresql%';

INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'maintenance', 'feature' FROM scripts WHERE name LIKE '%vacuum%' OR name LIKE '%optimize%';

-- Tags pour gestion de paquets
INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'package-management', 'category' FROM scripts WHERE name LIKE '%package%';

INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'apt', 'technology' FROM scripts WHERE name LIKE '%apt%';

INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'yum', 'technology' FROM scripts WHERE name LIKE '%yum%';

INSERT INTO script_tags (script_id, tag_name, tag_category)
SELECT id, 'system-maintenance', 'category' FROM scripts WHERE name LIKE '%update%' OR name LIKE '%upgrade%';

EOF

    log_success "Script tags added"
}

# Générer des statistiques sur la base
generate_statistics() {
    log_info "Generating database statistics..."
    
    sqlite3 "$DATABASE_FILE" << 'EOF'
-- Vue des statistiques par catégorie
CREATE VIEW IF NOT EXISTS stats_by_category AS
SELECT 
    category,
    COUNT(*) as total_scripts,
    SUM(CASE WHEN status = 'implemented' THEN 1 ELSE 0 END) as implemented,
    SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active,
    SUM(CASE WHEN status = 'planned' THEN 1 ELSE 0 END) as planned,
    ROUND(AVG(complexity_score), 2) as avg_complexity
FROM scripts 
GROUP BY category 
ORDER BY total_scripts DESC;

-- Vue des scripts récemment implémentés
CREATE VIEW IF NOT EXISTS recently_implemented AS
SELECT 
    name,
    category,
    description,
    implementation_date,
    complexity_score
FROM scripts 
WHERE status = 'implemented' 
ORDER BY implementation_date DESC;

-- Vue de compatibilité par OS
CREATE VIEW IF NOT EXISTS compatibility_by_os AS
SELECT 
    sc.os_family,
    sc.distribution,
    COUNT(*) as compatible_scripts,
    s.category
FROM script_compatibility sc
JOIN scripts s ON sc.script_id = s.id
WHERE sc.compatibility_level IN ('full', 'partial')
GROUP BY sc.os_family, sc.distribution, s.category
ORDER BY compatible_scripts DESC;

EOF
    
    # Afficher les statistiques
    echo
    log_success "=== DATABASE STATISTICS ==="
    
    echo
    log_info "📊 Scripts by Category:"
    sqlite3 -header -column "$DATABASE_FILE" "SELECT * FROM stats_by_category;"
    
    echo
    log_info "🆕 Recently Implemented Scripts:"
    sqlite3 -header -column "$DATABASE_FILE" "SELECT * FROM recently_implemented;"
    
    echo
    log_info "🌐 OS Compatibility Summary:"
    sqlite3 -header -column "$DATABASE_FILE" "
    SELECT 
        os_family || CASE WHEN distribution IS NOT NULL THEN ' (' || distribution || ')' ELSE '' END as platform,
        COUNT(DISTINCT script_id) as compatible_scripts
    FROM script_compatibility 
    WHERE compatibility_level = 'full' 
    GROUP BY os_family, distribution 
    ORDER BY compatible_scripts DESC;
    "
    
    echo
    log_info "🏷️  Top Script Tags:"
    sqlite3 -header -column "$DATABASE_FILE" "
    SELECT tag_name, COUNT(*) as usage_count 
    FROM script_tags 
    GROUP BY tag_name 
    ORDER BY usage_count DESC 
    LIMIT 10;
    "
    
    echo
    log_success "Database successfully created: $DATABASE_FILE"
}

# Fonction principale
main() {
    log_info "🚀 Starting AtomicOps-Suite Scripts Database Generation"
    
    check_dependencies
    
    # Supprimer l'ancienne base si elle existe
    if [[ -f "$DATABASE_FILE" ]]; then
        log_warn "Existing database found, backing up..."
        cp "$DATABASE_FILE" "${DATABASE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        rm "$DATABASE_FILE"
    fi
    
    create_database_schema
    populate_scripts_data
    add_compatibility_data
    add_script_tags
    generate_statistics
    
    echo
    log_success "✅ Database generation completed successfully!"
    log_info "Database location: $DATABASE_FILE"
    log_info "Use: sqlite3 '$DATABASE_FILE' to explore the database"
}

# Point d'entrée
main "$@"