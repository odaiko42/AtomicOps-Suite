#!/bin/bash
#
# Script: search-db.sh  
# Description: Recherche et consultation du catalogue de scripts
# Usage: ./search-db.sh [OPTIONS]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_FILE="$PROJECT_ROOT/database/scripts_catalogue.db"

# Import des bibliothèques
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"

# Fonction d'aide
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [TERM]

Recherche et consultation du catalogue de scripts

Options de recherche:
  -n, --name <pattern>      Recherche par nom (support wildcards)
  -c, --category <cat>      Recherche par catégorie
  -t, --type <type>         Recherche par type (atomic, orchestrator-1, etc.)
  -T, --tag <tag>           Recherche par tag
  -d, --description <term>  Recherche dans les descriptions
  -a, --all                 Lister tous les scripts
  
Options d'information:
  -i, --info <script>       Détails complets d'un script
  -D, --dependencies <script> Graphe des dépendances
  -s, --stats               Statistiques du catalogue
  -h, --help                Affiche cette aide

Exemples:
  $0 --all                    # Tous les scripts
  $0 --name "create-*"        # Scripts commençant par "create-"
  $0 --category storage       # Scripts de stockage
  $0 --type atomic            # Tous les atomiques
  $0 --tag backup            # Scripts avec tag "backup"
  $0 --info create-ct.sh     # Détails complets
  $0 --dependencies setup.sh # Dépendances du script

EOF
}

# Validation des prérequis
validate_prerequisites() {
    if ! command -v sqlite3 >/dev/null 2>&1; then
        log_error "sqlite3 n'est pas installé"
        exit $EXIT_ERROR_DEPENDENCY
    fi
    
    if [[ ! -f "$DB_FILE" ]]; then
        log_error "Base de données non trouvée: $DB_FILE"
        log_info "Initialisez la base: $PROJECT_ROOT/database/init-db.sh"
        exit $EXIT_ERROR_NOT_FOUND
    fi
}

# Recherche par nom (avec wildcards)
search_by_name() {
    local pattern="$1"
    
    echo "🔍 Recherche par nom: $pattern"
    echo "============================="
    
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    name as Nom,
    type as Type,
    category as Catégorie,
    substr(description, 1, 50) || '...' as Description
FROM scripts 
WHERE name LIKE '$pattern'
ORDER BY type, name;
EOF
}

# Recherche par catégorie
search_by_category() {
    local category="$1"
    
    echo "🔍 Scripts de catégorie: $category"
    echo "================================"
    
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    name as Nom,
    type as Type,
    status as Statut,
    substr(description, 1, 60) as Description
FROM scripts 
WHERE category = '$category'
ORDER BY type, name;
EOF
}

# Lister tous les scripts
list_all() {
    echo "📋 Catalogue complet des scripts"
    echo "==============================="
    
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    name as Nom,
    type as Type,
    category as Catégorie,
    status as Statut,
    version as Version
FROM scripts 
ORDER BY type, category, name;
EOF
    
    # Résumé
    echo ""
    echo "Résumé:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    'Total:' as Statistique,
    COUNT(*) as Nombre
FROM scripts
UNION ALL
SELECT 
    'Atomiques:',
    SUM(CASE WHEN type = 'atomic' THEN 1 ELSE 0 END)
FROM scripts
UNION ALL
SELECT 
    'Orchestrateurs:',
    SUM(CASE WHEN type LIKE 'orchestrator%' THEN 1 ELSE 0 END)
FROM scripts;
EOF
}

# Afficher les statistiques
show_stats() {
    echo "📊 Statistiques du catalogue"
    echo "============================"
    
    # Statistiques générales
    echo ""
    echo "Vue d'ensemble:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    COUNT(*) as total_scripts,
    COUNT(DISTINCT category) as categories,
    COUNT(DISTINCT author) as auteurs
FROM scripts;
EOF
    
    # Par type
    echo ""
    echo "Par type:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    type as Type,
    COUNT(*) as Nombre
FROM scripts
GROUP BY type
ORDER BY type;
EOF
    
    # Par catégorie
    echo ""
    echo "Par catégorie:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    category as Catégorie,
    COUNT(*) as Nombre
FROM scripts
GROUP BY category
ORDER BY Nombre DESC;
EOF
    
    # Par statut
    echo ""
    echo "Par statut:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    status as Statut,
    COUNT(*) as Nombre
FROM scripts
GROUP BY status;
EOF
    
    # Scripts avec le plus de dépendances
    echo ""
    echo "Top 5 - Plus de dépendances:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    name as Script,
    dependency_count as Dépendances
FROM v_scripts_with_dep_count
WHERE dependency_count > 0
ORDER BY dependency_count DESC
LIMIT 5;
EOF
    
    # Fonctions disponibles
    echo ""
    echo "Bibliothèques et fonctions:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    library_file as Bibliothèque,
    COUNT(*) as Fonctions
FROM functions
GROUP BY library_file
ORDER BY Fonctions DESC;
EOF
}

# Afficher les détails d'un script
show_script_info() {
    local script_name="$1"
    
    echo "📄 Détails du script: $script_name"
    echo "=================================="
    
    # Vérifier que le script existe
    local script_exists
    script_exists=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM scripts WHERE name = '$script_name';")
    
    if [[ "$script_exists" -eq 0 ]]; then
        echo "❌ Script non trouvé: $script_name"
        echo ""
        echo "Scripts disponibles:"
        sqlite3 "$DB_FILE" "SELECT name FROM scripts ORDER BY name LIMIT 10;"
        return 1
    fi
    
    # Informations générales
    echo ""
    echo "Informations générales:"
    sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    'Nom:' as Champ, name as Valeur FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Type:', type FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Catégorie:', category FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Version:', version FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Statut:', status FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Chemin:', path FROM scripts WHERE name = '$script_name'
UNION ALL SELECT 'Auteur:', COALESCE(author, '-') FROM scripts WHERE name = '$script_name';
EOF
    
    echo ""
    echo "Description:"
    sqlite3 "$DB_FILE" "SELECT description FROM scripts WHERE name = '$script_name';"
    
    # Paramètres
    echo ""
    echo "Paramètres d'entrée:"
    local param_count
    param_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM script_parameters WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name');")
    
    if [[ "$param_count" -gt 0 ]]; then
        sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    param_name as Paramètre,
    param_type as Type,
    CASE WHEN is_required = 1 THEN 'Oui' ELSE 'Non' END as Obligatoire,
    COALESCE(default_value, '-') as Défaut,
    COALESCE(description, '-') as Description
FROM script_parameters
WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name')
ORDER BY position, param_name;
EOF
    else
        echo "  Aucun paramètre documenté"
    fi
    
    # Codes de sortie
    echo ""
    echo "Codes de sortie:"
    local exit_count
    exit_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM exit_codes WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name');")
    
    if [[ "$exit_count" -gt 0 ]]; then
        sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    exit_code as Code,
    COALESCE(code_name, '-') as Nom,
    description as Description
FROM exit_codes
WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name')
ORDER BY exit_code;
EOF
    else
        echo "  Aucun code de sortie documenté"
    fi
    
    # Dépendances
    echo ""
    echo "Dépendances:"
    local dep_count
    dep_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM script_dependencies WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name');")
    
    if [[ "$dep_count" -gt 0 ]]; then
        sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    dependency_type || ': ' || 
    COALESCE(
        (SELECT name FROM scripts WHERE id = depends_on_script_id),
        depends_on_command,
        depends_on_library,
        depends_on_package
    ) || 
    CASE WHEN is_optional = 1 THEN ' (optionnel)' ELSE '' END as Dépendance
FROM script_dependencies
WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name')
ORDER BY dependency_type;
EOF
    else
        echo "  Aucune dépendance documentée"
    fi
    
    # Tags
    echo ""
    echo "Tags:"
    local tags
    tags=$(sqlite3 "$DB_FILE" "SELECT GROUP_CONCAT(tag, ', ') FROM script_tags WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name');")
    if [[ -n "$tags" && "$tags" != "" ]]; then
        echo "  $tags"
    else
        echo "  Aucun tag"
    fi
    
    # Exemples d'utilisation
    echo ""
    echo "Exemples d'utilisation:"
    local example_count
    example_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM script_examples WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name');")
    
    if [[ "$example_count" -gt 0 ]]; then
        sqlite3 "$DB_FILE" <<EOF
SELECT 
    '• ' || example_title || ':
  ' || example_command || '
'
FROM script_examples
WHERE script_id = (SELECT id FROM scripts WHERE name = '$script_name');
EOF
    else
        echo "  Aucun exemple documenté"
    fi
}

# Afficher le graphe de dépendances
show_dependencies() {
    local script_name="$1"
    
    echo "🔗 Dépendances de: $script_name"
    echo "==============================="
    
    # Vérifier que le script existe
    local script_exists
    script_exists=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM scripts WHERE name = '$script_name';")
    
    if [[ "$script_exists" -eq 0 ]]; then
        echo "❌ Script non trouvé: $script_name"
        return 1
    fi
    
    # Dépendances directes
    echo ""
    echo "Dépend de (niveau 1):"
    local has_deps
    has_deps=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM v_dependency_graph WHERE script_name = '$script_name';")
    
    if [[ "$has_deps" -gt 0 ]]; then
        sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    depends_on as Script,
    dependency_type as Type,
    CASE WHEN is_optional = 1 THEN 'Optionnel' ELSE 'Obligatoire' END as Statut
FROM v_dependency_graph
WHERE script_name = '$script_name'
ORDER BY dependency_type, depends_on;
EOF
    else
        echo "  Aucune dépendance"
    fi
    
    # Scripts qui dépendent de celui-ci
    echo ""
    echo "Scripts qui dépendent de $script_name:"
    local has_dependents
    has_dependents=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM v_dependency_graph WHERE depends_on = '$script_name';")
    
    if [[ "$has_dependents" -gt 0 ]]; then
        sqlite3 -column "$DB_FILE" <<EOF
SELECT 
    script_name as Script,
    script_type as Type
FROM v_dependency_graph
WHERE depends_on = '$script_name'
ORDER BY script_type, script_name;
EOF
    else
        echo "  Aucun script dépendant"
    fi
}

# Parsing des arguments
parse_args() {
    case ${1:-} in
        -n|--name)
            if [[ $# -lt 2 ]]; then
                log_error "Pattern requis pour --name"
                exit $EXIT_ERROR_USAGE
            fi
            search_by_name "$2"
            ;;
        -c|--category)
            if [[ $# -lt 2 ]]; then
                log_error "Catégorie requise pour --category"
                exit $EXIT_ERROR_USAGE
            fi
            search_by_category "$2"
            ;;
        -t|--type)
            if [[ $# -lt 2 ]]; then
                log_error "Type requis pour --type"
                exit $EXIT_ERROR_USAGE
            fi
            TYPE="$2"
            echo "🔍 Scripts de type: $TYPE"
            echo "======================"
            sqlite3 -header -column "$DB_FILE" "SELECT name, category, description FROM scripts WHERE type = '$TYPE' ORDER BY name;"
            ;;
        -T|--tag)
            if [[ $# -lt 2 ]]; then
                log_error "Tag requis pour --tag"
                exit $EXIT_ERROR_USAGE
            fi
            TAG="$2"
            echo "🔍 Scripts avec le tag: $TAG"
            echo "=========================="
            sqlite3 -header -column "$DB_FILE" <<EOF
SELECT s.name, s.type, s.category
FROM scripts s
JOIN script_tags st ON s.id = st.script_id
WHERE st.tag = '$TAG'
ORDER BY s.name;
EOF
            ;;
        -d|--description)
            if [[ $# -lt 2 ]]; then
                log_error "Terme requis pour --description"
                exit $EXIT_ERROR_USAGE
            fi
            TERM="$2"
            echo "🔍 Recherche dans les descriptions: $TERM"
            echo "======================================="
            sqlite3 -header -column "$DB_FILE" "SELECT name, type, description FROM scripts WHERE description LIKE '%$TERM%' OR long_description LIKE '%$TERM%' ORDER BY name;"
            ;;
        -a|--all)
            list_all
            ;;
        -s|--stats)
            show_stats
            ;;
        -i|--info)
            if [[ $# -lt 2 ]]; then
                log_error "Nom du script requis pour --info"
                exit $EXIT_ERROR_USAGE
            fi
            show_script_info "$2"
            ;;
        -D|--dependencies)
            if [[ $# -lt 2 ]]; then
                log_error "Nom du script requis pour --dependencies"
                exit $EXIT_ERROR_USAGE
            fi
            show_dependencies "$2"
            ;;
        -h|--help)
            show_help
            ;;
        "")
            show_help
            ;;
        *)
            log_error "Option inconnue: $1"
            echo ""
            show_help
            exit $EXIT_ERROR_USAGE
            ;;
    esac
}

# Point d'entrée principal
main() {
    # Initialisation du logging
    init_logging "$(basename "$0")"
    
    # Validation des prérequis
    validate_prerequisites
    
    # Parsing et exécution
    parse_args "$@"
}

# Exécution
main "$@"