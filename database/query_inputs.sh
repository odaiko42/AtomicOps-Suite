#!/usr/bin/env bash
# =====================================================
# SCRIPT DE REQUÊTES POUR LA BASE DE DONNÉES INPUTS
# AtomicOps-Suite - Requêtes pratiques pour les types d'inputs
# =====================================================

set -euo pipefail

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="${SCRIPT_DIR}/atomicops_inputs.db"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction d'information
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Fonction de titre
title() {
    echo -e "${YELLOW}=== $1 ===${NC}"
}

# Vérification de l'existence de la base
check_database() {
    if [[ ! -f "$DB_FILE" ]]; then
        echo -e "${RED}[ERROR]${NC} Base de données non trouvée: $DB_FILE"
        echo "Exécutez d'abord: ./init_database.sh"
        exit 1
    fi
}

# Afficher tous les types d'inputs
show_all_inputs() {
    title "Tous les types d'inputs"
    sqlite3 "$DB_FILE" -header -column "
        SELECT 
            type_name as 'Type',
            display_label as 'Label',
            color_hex as 'Couleur',
            category as 'Catégorie',
            CASE WHEN is_required THEN 'Oui' ELSE 'Non' END as 'Requis'
        FROM input_parameter_types 
        ORDER BY category, type_name;
    "
}

# Afficher les inputs par catégorie
show_by_category() {
    local category=$1
    title "Inputs de catégorie: $category"
    sqlite3 "$DB_FILE" -header -column "
        SELECT 
            type_name as 'Type',
            display_label as 'Label',
            default_value as 'Valeur par défaut',
            examples as 'Exemples'
        FROM input_parameter_types 
        WHERE category = '$category'
        ORDER BY type_name;
    "
}

# Afficher les détails d'un input spécifique
show_input_details() {
    local input_type=$1
    title "Détails pour: $input_type"
    sqlite3 "$DB_FILE" -header -column "
        SELECT 
            type_name as 'Type',
            display_label as 'Label',
            color_hex as 'Couleur',
            validation_regex as 'Regex de validation',
            validation_message as 'Message d\'erreur',
            default_value as 'Valeur par défaut',
            description as 'Description',
            category as 'Catégorie',
            examples as 'Exemples'
        FROM input_parameter_types 
        WHERE type_name = '$input_type';
    "
}

# Statistiques générales
show_statistics() {
    title "Statistiques"
    
    echo -e "${GREEN}Total des types d'inputs:${NC}"
    sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM input_parameter_types;"
    echo
    
    echo -e "${GREEN}Répartition par catégorie:${NC}"
    sqlite3 "$DB_FILE" -header -column "
        SELECT 
            category as 'Catégorie',
            COUNT(*) as 'Nombre',
            GROUP_CONCAT(type_name, ', ') as 'Types'
        FROM input_parameter_types 
        GROUP BY category;
    "
    echo
    
    echo -e "${GREEN}Inputs requis:${NC}"
    sqlite3 "$DB_FILE" -header -column "
        SELECT type_name as 'Type', display_label as 'Label' 
        FROM input_parameter_types 
        WHERE is_required = TRUE;
    "
}

# Export JSON pour l'application
export_json() {
    title "Export JSON des types d'inputs"
    info "Export vers: input_types.json"
    
    sqlite3 "$DB_FILE" "
        SELECT json_group_array(
            json_object(
                'type', type_name,
                'label', display_label,
                'color', color_hex,
                'regex', validation_regex,
                'message', validation_message,
                'default', default_value,
                'category', category,
                'required', is_required,
                'description', description,
                'examples', examples
            )
        ) 
        FROM input_parameter_types;
    " > "${SCRIPT_DIR}/input_types.json"
    
    echo -e "${GREEN}Export terminé:${NC} input_types.json"
}

# Export TypeScript pour l'application
export_typescript() {
    title "Export TypeScript des types d'inputs"
    info "Export vers: inputTypes.ts"
    
    cat > "${SCRIPT_DIR}/inputTypes.ts" << 'EOF'
// =====================================================
// TYPES D'INPUTS - GÉNÉRÉ AUTOMATIQUEMENT DEPUIS SQLite3
// AtomicOps-Suite - Ne pas modifier manuellement
// =====================================================

export interface InputTypeConfig {
  type: string;
  label: string;
  color: string;
  regex?: string;
  message?: string;
  defaultValue?: string;
  category: string;
  required: boolean;
  description: string;
  examples: string;
}

export const INPUT_TYPES_CONFIG: Record<string, InputTypeConfig> = {
EOF
    
    sqlite3 "$DB_FILE" "
        SELECT 
            '  ' || type_name || ': {' || CHAR(10) ||
            '    type: ''' || type_name || ''',' || CHAR(10) ||
            '    label: ''' || REPLACE(display_label, '''', '\''') || ''',' || CHAR(10) ||
            '    color: ''' || color_hex || ''',' || CHAR(10) ||
            CASE WHEN validation_regex IS NOT NULL 
                THEN '    regex: ''' || REPLACE(validation_regex, '''', '\''') || ''',' || CHAR(10)
                ELSE '' 
            END ||
            CASE WHEN validation_message IS NOT NULL 
                THEN '    message: ''' || REPLACE(validation_message, '''', '\''') || ''',' || CHAR(10)
                ELSE '' 
            END ||
            '    defaultValue: ''' || COALESCE(default_value, '') || ''',' || CHAR(10) ||
            '    category: ''' || category || ''',' || CHAR(10) ||
            '    required: ' || CASE WHEN is_required THEN 'true' ELSE 'false' END || ',' || CHAR(10) ||
            '    description: ''' || REPLACE(description, '''', '\''') || ''',' || CHAR(10) ||
            '    examples: ''' || REPLACE(examples, '''', '\''') || '''' || CHAR(10) ||
            '  },'
        FROM input_parameter_types 
        ORDER BY type_name;
    " >> "${SCRIPT_DIR}/inputTypes.ts"
    
    echo "};" >> "${SCRIPT_DIR}/inputTypes.ts"
    echo -e "${GREEN}Export terminé:${NC} inputTypes.ts"
}

# Afficher l'aide
show_help() {
    echo "Usage: $0 [OPTION]"
    echo
    echo "Options:"
    echo "  all                    Afficher tous les types d'inputs"
    echo "  category <cat>         Afficher les inputs d'une catégorie (network|auth|system)"
    echo "  details <type>         Afficher les détails d'un type spécifique"
    echo "  stats                  Afficher les statistiques"
    echo "  json                   Exporter en JSON"
    echo "  typescript             Exporter en TypeScript"
    echo "  help                   Afficher cette aide"
    echo
    echo "Exemples:"
    echo "  $0 all"
    echo "  $0 category network"
    echo "  $0 details ip"
    echo "  $0 stats"
}

# Fonction principale
main() {
    check_database
    
    case "${1:-help}" in
        "all")
            show_all_inputs
            ;;
        "category")
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}[ERROR]${NC} Catégorie manquante"
                echo "Catégories disponibles: network, auth, system"
                exit 1
            fi
            show_by_category "$2"
            ;;
        "details")
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}[ERROR]${NC} Type d'input manquant"
                exit 1
            fi
            show_input_details "$2"
            ;;
        "stats")
            show_statistics
            ;;
        "json")
            export_json
            ;;
        "typescript")
            export_typescript
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Exécution
main "$@"