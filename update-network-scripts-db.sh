#!/usr/bin/env bash

# ==============================================================================
# Script de Mise à Jour Base de Données: update-network-scripts-db.sh
# Description: Met à jour la base de données SQLite avec les nouveaux scripts réseau
# Author: AtomicOps-Suite AI assistant
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/atomic-scripts.db"
ATOMICS_DIR="$SCRIPT_DIR/atomics/network"
ORCHESTRATORS_DIR="$SCRIPT_DIR/orchestrators/network"

# =============================================================================
# Fonctions Utilitaires
# =============================================================================

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

die() {
    log_error "$1"
    exit "${2:-1}"
}

# =============================================================================
# Initialisation de la Base de Données
# =============================================================================

init_database() {
    log_info "Initialisation de la base de données SQLite..."
    
    sqlite3 "$DB_FILE" << 'EOF'
-- Table des scripts atomiques
CREATE TABLE IF NOT EXISTS atomic_scripts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    path TEXT NOT NULL,
    category TEXT NOT NULL,
    subcategory TEXT,
    description TEXT,
    level INTEGER NOT NULL,
    dependencies TEXT,
    version TEXT,
    date_created TEXT,
    date_modified TEXT,
    file_size INTEGER,
    line_count INTEGER,
    functions_count INTEGER,
    has_help BOOLEAN DEFAULT 0,
    has_json_output BOOLEAN DEFAULT 0,
    has_error_handling BOOLEAN DEFAULT 0,
    conformity_score REAL DEFAULT 0.0,
    tags TEXT
);

-- Table des orchestrateurs
CREATE TABLE IF NOT EXISTS orchestrator_scripts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    path TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    level INTEGER NOT NULL,
    atomic_dependencies TEXT,
    version TEXT,
    date_created TEXT,
    date_modified TEXT,
    file_size INTEGER,
    line_count INTEGER,
    workflow_steps INTEGER,
    has_rollback BOOLEAN DEFAULT 0,
    has_retry_logic BOOLEAN DEFAULT 0,
    conformity_score REAL DEFAULT 0.0,
    tags TEXT
);

-- Index pour les recherches
CREATE INDEX IF NOT EXISTS idx_atomic_category ON atomic_scripts(category, subcategory);
CREATE INDEX IF NOT EXISTS idx_atomic_level ON atomic_scripts(level);
CREATE INDEX IF NOT EXISTS idx_orchestrator_category ON orchestrator_scripts(category);
CREATE INDEX IF NOT EXISTS idx_orchestrator_level ON orchestrator_scripts(level);
EOF

    log_info "Base de données initialisée"
}

# =============================================================================
# Analyse d'un Script
# =============================================================================

analyze_script() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    
    # Informations de base du fichier
    local file_size=$(stat -c%s "$script_path" 2>/dev/null || echo 0)
    local line_count=$(wc -l < "$script_path" 2>/dev/null || echo 0)
    local date_modified=$(stat -c%Y "$script_path" 2>/dev/null || echo 0)
    date_modified=$(date -d "@$date_modified" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "1970-01-01 00:00:00")
    
    # Analyse du contenu
    local functions_count=$(grep -c "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$script_path" 2>/dev/null || echo 0)
    local has_help=0
    local has_json_output=0
    local has_error_handling=0
    local version=""
    local description=""
    local dependencies=""
    
    # Vérification de l'aide
    if grep -q "show_help\|--help" "$script_path" 2>/dev/null; then
        has_help=1
    fi
    
    # Vérification de la sortie JSON
    if grep -q "build_json_output\|--json-only" "$script_path" 2>/dev/null; then
        has_json_output=1
    fi
    
    # Vérification de la gestion d'erreur
    if grep -q "set -euo pipefail\|die\|trap.*cleanup" "$script_path" 2>/dev/null; then
        has_error_handling=1
    fi
    
    # Extraction de la version
    version=$(grep "^# Version:" "$script_path" 2>/dev/null | head -1 | cut -d: -f2 | xargs || echo "1.0")
    
    # Extraction de la description
    description=$(grep "^# Description:" "$script_path" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo "")
    
    # Extraction des dépendances
    dependencies=$(grep "^# Dependencies:" "$script_path" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo "")
    
    # Calcul du score de conformité
    local conformity_score=0.0
    if [[ $has_help -eq 1 ]]; then conformity_score=$(echo "$conformity_score + 25.0" | bc); fi
    if [[ $has_json_output -eq 1 ]]; then conformity_score=$(echo "$conformity_score + 25.0" | bc); fi
    if [[ $has_error_handling -eq 1 ]]; then conformity_score=$(echo "$conformity_score + 25.0" | bc); fi
    if [[ $functions_count -gt 5 ]]; then conformity_score=$(echo "$conformity_score + 25.0" | bc); fi
    
    echo "$file_size|$line_count|$date_modified|$functions_count|$has_help|$has_json_output|$has_error_handling|$version|$description|$dependencies|$conformity_score"
}

# =============================================================================
# Insertion des Scripts Atomiques
# =============================================================================

insert_atomic_scripts() {
    log_info "Insertion des scripts atomiques réseau..."
    
    local scripts=(
        "ssh-connect.sh|network|ssh|Test et validation de connexion SSH avec authentification et collecte d'informations serveur"
        "ssh-execute-command.sh|network|ssh|Exécution de commandes distantes via SSH avec capture de sortie et gestion d'environnement"
        "ssh-key-test.sh|network|ssh|Validation, génération et analyse de clés SSH avec support multi-algorithmes"
        "ftp-connect.sh|network|ftp|Test de connectivité FTP/FTPS avec authentification et validation SSL"
        "ftp-upload.sh|network|ftp|Upload de fichiers via FTP/FTPS avec vérification d'intégrité et reprise de transfert"
        "http-request.sh|network|http|Requêtes HTTP/HTTPS avec authentification, headers personnalisés et analyse de réponse"
        "http-download.sh|network|http|Téléchargement de fichiers HTTP/HTTPS avec reprise et limitation de bande passante"
        "scp-transfer.sh|network|scp|Transfert de fichiers via SCP avec métriques de performance et options avancées"
    )
    
    for script_info in "${scripts[@]}"; do
        IFS='|' read -r script_name category subcategory desc <<< "$script_info"
        local script_path="$ATOMICS_DIR/$script_name"
        
        if [[ -f "$script_path" ]]; then
            log_info "Analyse de $script_name..."
            local analysis=$(analyze_script "$script_path")
            IFS='|' read -r file_size line_count date_modified functions_count has_help has_json_output has_error_handling version description dependencies conformity_score <<< "$analysis"
            
            # Utiliser la description fournie si celle extraite est vide
            if [[ -z "$description" ]]; then
                description="$desc"
            fi
            
            # Tags basés sur la fonctionnalité
            local tags="network,connectivity,${subcategory}"
            if [[ $has_help -eq 1 ]]; then tags="$tags,documented"; fi
            if [[ $has_json_output -eq 1 ]]; then tags="$tags,json-output"; fi
            if [[ $has_error_handling -eq 1 ]]; then tags="$tags,robust"; fi
            
            sqlite3 "$DB_FILE" << EOF
INSERT OR REPLACE INTO atomic_scripts (
    name, path, category, subcategory, description, level, dependencies,
    version, date_created, date_modified, file_size, line_count, functions_count,
    has_help, has_json_output, has_error_handling, conformity_score, tags
) VALUES (
    '$script_name', '$script_path', '$category', '$subcategory', '$description', 0, '$dependencies',
    '$version', '2025-10-04 00:00:00', '$date_modified', $file_size, $line_count, $functions_count,
    $has_help, $has_json_output, $has_error_handling, $conformity_score, '$tags'
);
EOF
            
            log_info "$script_name ajouté (Score: $conformity_score%)"
        else
            log_error "Script non trouvé: $script_path"
        fi
    done
}

# =============================================================================
# Insertion des Orchestrateurs
# =============================================================================

insert_orchestrator_scripts() {
    log_info "Insertion des orchestrateurs réseau..."
    
    local orchestrators=(
        "network-setup-deployment.sh|network|Orchestrateur de déploiement réseau complet avec SSH, SCP, et vérification HTTP"
        "network-secure-connection.sh|network|Orchestrateur de connexions réseau sécurisées multi-protocoles (SSH/FTP/HTTP/SCP)"
    )
    
    for orchestrator_info in "${orchestrators[@]}"; do
        IFS='|' read -r script_name category description <<< "$orchestrator_info"
        local script_path="$ORCHESTRATORS_DIR/$script_name"
        
        if [[ -f "$script_path" ]]; then
            log_info "Analyse de $script_name..."
            local analysis=$(analyze_script "$script_path")
            IFS='|' read -r file_size line_count date_modified functions_count has_help has_json_output has_error_handling version _ dependencies conformity_score <<< "$analysis"
            
            # Analyse spécifique aux orchestrateurs
            local workflow_steps=$(grep -c "log_info.*===" "$script_path" 2>/dev/null || echo 0)
            local has_rollback=0
            local has_retry_logic=0
            
            if grep -q "rollback\|backup" "$script_path" 2>/dev/null; then
                has_rollback=1
            fi
            
            if grep -q "retry\|attempt" "$script_path" 2>/dev/null; then
                has_retry_logic=1
            fi
            
            # Dépendances atomiques (scripts utilisés)
            local atomic_deps=""
            if grep -q "ssh-connect.sh" "$script_path" 2>/dev/null; then atomic_deps="$atomic_deps,ssh-connect.sh"; fi
            if grep -q "ssh-execute-command.sh" "$script_path" 2>/dev/null; then atomic_deps="$atomic_deps,ssh-execute-command.sh"; fi
            if grep -q "scp-transfer.sh" "$script_path" 2>/dev/null; then atomic_deps="$atomic_deps,scp-transfer.sh"; fi
            if grep -q "http-request.sh" "$script_path" 2>/dev/null; then atomic_deps="$atomic_deps,http-request.sh"; fi
            if grep -q "ftp-connect.sh" "$script_path" 2>/dev/null; then atomic_deps="$atomic_deps,ftp-connect.sh"; fi
            atomic_deps=${atomic_deps#,}  # Supprimer la virgule initiale
            
            # Tags
            local tags="network,orchestrator,automation"
            if [[ $has_rollback -eq 1 ]]; then tags="$tags,rollback"; fi
            if [[ $has_retry_logic -eq 1 ]]; then tags="$tags,retry-logic"; fi
            if [[ $has_json_output -eq 1 ]]; then tags="$tags,json-output"; fi
            
            sqlite3 "$DB_FILE" << EOF
INSERT OR REPLACE INTO orchestrator_scripts (
    name, path, category, description, level, atomic_dependencies,
    version, date_created, date_modified, file_size, line_count, workflow_steps,
    has_rollback, has_retry_logic, conformity_score, tags
) VALUES (
    '$script_name', '$script_path', '$category', '$description', 1, '$atomic_deps',
    '$version', '2025-10-04 00:00:00', '$date_modified', $file_size, $line_count, $workflow_steps,
    $has_rollback, $has_retry_logic, $conformity_score, '$tags'
);
EOF
            
            log_info "$script_name ajouté (Étapes: $workflow_steps, Score: $conformity_score%)"
        else
            log_error "Orchestrateur non trouvé: $script_path"
        fi
    done
}

# =============================================================================
# Génération du Rapport
# =============================================================================

generate_report() {
    log_info "Génération du rapport de mise à jour..."
    
    echo "==============================================="
    echo "RAPPORT DE MISE À JOUR - SCRIPTS RÉSEAU"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "==============================================="
    
    echo
    echo "📊 STATISTIQUES GLOBALES"
    echo "------------------------"
    
    local atomic_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM atomic_scripts WHERE category='network';")
    local orchestrator_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM orchestrator_scripts WHERE category='network';")
    local avg_conformity_atomic=$(sqlite3 "$DB_FILE" "SELECT ROUND(AVG(conformity_score), 2) FROM atomic_scripts WHERE category='network';")
    local avg_conformity_orchestrator=$(sqlite3 "$DB_FILE" "SELECT ROUND(AVG(conformity_score), 2) FROM orchestrator_scripts WHERE category='network';")
    
    echo "Scripts atomiques réseau     : $atomic_count"
    echo "Orchestrateurs réseau        : $orchestrator_count"
    echo "Score conformité atomiques   : ${avg_conformity_atomic}%"
    echo "Score conformité orchestrateurs : ${avg_conformity_orchestrator}%"
    
    echo
    echo "📋 DÉTAILS SCRIPTS ATOMIQUES"
    echo "----------------------------"
    sqlite3 -header -column "$DB_FILE" << 'EOF'
SELECT 
    name,
    subcategory,
    ROUND(conformity_score, 1) as score,
    CASE WHEN has_help = 1 THEN '✓' ELSE '✗' END as help,
    CASE WHEN has_json_output = 1 THEN '✓' ELSE '✗' END as json,
    line_count as lines
FROM atomic_scripts 
WHERE category = 'network'
ORDER BY subcategory, name;
EOF
    
    echo
    echo "🔀 DÉTAILS ORCHESTRATEURS"
    echo "-------------------------"
    sqlite3 -header -column "$DB_FILE" << 'EOF'
SELECT 
    name,
    workflow_steps as steps,
    ROUND(conformity_score, 1) as score,
    CASE WHEN has_rollback = 1 THEN '✓' ELSE '✗' END as rollback,
    CASE WHEN has_retry_logic = 1 THEN '✓' ELSE '✗' END as retry,
    line_count as lines
FROM orchestrator_scripts 
WHERE category = 'network'
ORDER BY name;
EOF
    
    echo
    echo "🔍 ANALYSE DE COUVERTURE"
    echo "------------------------"
    
    echo "Protocoles couverts:"
    sqlite3 "$DB_FILE" "SELECT DISTINCT subcategory FROM atomic_scripts WHERE category='network';" | while read -r protocol; do
        local count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM atomic_scripts WHERE category='network' AND subcategory='$protocol';")
        echo "  • $protocol: $count scripts"
    done
    
    echo
    echo "==============================================="
}

# =============================================================================
# Point d'Entrée Principal
# =============================================================================

main() {
    log_info "Démarrage de la mise à jour de la base de données"
    
    # Vérification des prérequis
    if ! command -v sqlite3 >/dev/null 2>&1; then
        die "SQLite3 non disponible" 1
    fi
    
    if ! command -v bc >/dev/null 2>&1; then
        log_info "bc non disponible - calculs approximatifs"
    fi
    
    # Vérification des répertoires
    if [[ ! -d "$ATOMICS_DIR" ]]; then
        die "Répertoire atomics/network non trouvé: $ATOMICS_DIR" 1
    fi
    
    if [[ ! -d "$ORCHESTRATORS_DIR" ]]; then
        die "Répertoire orchestrators/network non trouvé: $ORCHESTRATORS_DIR" 1
    fi
    
    # Traitement
    init_database
    insert_atomic_scripts
    insert_orchestrator_scripts
    generate_report
    
    log_info "Mise à jour terminée avec succès"
    log_info "Base de données: $DB_FILE"
}

# Exécution
main "$@"