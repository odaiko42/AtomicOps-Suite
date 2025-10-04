#!/usr/bin/env bash

# ===========================
# Parser de Scripts Atomiques - AtomicOps Suite
# ===========================
# 
# Ce script analyse automatiquement tous les scripts atomiques du projet
# et génère un fichier JSON avec les métadonnées extraites :
# - Fonctions définies
# - Paramètres d'entrée et de sortie
# - Dépendances
# - Conditions d'exécution
# - Documentation intégrée

set -euo pipefail

# ===========================
# Configuration
# ===========================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_FILE="$SCRIPT_DIR/data/parsed-atomic-scripts.json"
TEMP_DIR="/tmp/atomic-parser-$$"

# Répertoires à analyser
ATOMIC_SCRIPTS_DIR="$PROJECT_ROOT/usb-disk-manager/scripts/atomic"
ORCHESTRATOR_SCRIPTS_DIR="$PROJECT_ROOT/usb-disk-manager/scripts/orchestrators"
MAIN_SCRIPTS_DIR="$PROJECT_ROOT/usb-disk-manager/scripts/main"
LIB_DIR="$PROJECT_ROOT/usb-disk-manager/lib"

# Configuration de logging
LOG_LEVEL="${LOG_LEVEL:-INFO}"
VERBOSE="${VERBOSE:-false}"

# ===========================
# Fonctions Utilitaires
# ===========================

info() {
    echo "[INFO] $*" >&2
}

warn() {
    echo "[WARN] $*" >&2
}

error() {
    echo "[ERROR] $*" >&2
}

debug() {
    [[ "$VERBOSE" == "true" ]] && echo "[DEBUG] $*" >&2
}

die() {
    error "$*"
    exit 1
}

# Crée un répertoire temporaire
setup_temp_dir() {
    mkdir -p "$TEMP_DIR"
    trap "rm -rf '$TEMP_DIR'" EXIT
}

# ===========================
# Fonctions d'Analyse
# ===========================

# Extrait les métadonnées d'en-tête d'un script
extract_header_metadata() {
    local script_file="$1"
    local metadata_file="$TEMP_DIR/$(basename "$script_file").meta"
    
    debug "Extraction des métadonnées de $script_file"
    
    # Initialiser les variables
    local name=""
    local description=""
    local author=""
    local version=""
    local category=""
    local level=""
    
    # Lire les commentaires d'en-tête
    while IFS= read -r line; do
        # Arrêter à la première ligne non-commentaire significative
        if [[ "$line" =~ ^[^#[:space:]] ]]; then
            break
        fi
        
        # Extraire les métadonnées des commentaires
        if [[ "$line" =~ ^#[[:space:]]*([A-Za-z_]+):[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1],,}"  # lowercase
            local value="${BASH_REMATCH[2]}"
            
            case "$key" in
                "name"|"nom")
                    name="$value"
                    ;;
                "description")
                    description="$value"
                    ;;
                "author"|"auteur")
                    author="$value"
                    ;;
                "version")
                    version="$value"
                    ;;
                "category"|"categorie")
                    category="$value"
                    ;;
                "level"|"niveau")
                    level="$value"
                    ;;
            esac
        fi
        
        # Aussi extraire la description des blocs de commentaires
        if [[ "$line" =~ ^#[[:space:]]*[A-Z][^:]*$ ]] && [[ -z "$description" ]]; then
            description="${line#\#*([[:space:]])}"
        fi
        
    done < "$script_file"
    
    # Générer les métadonnées par défaut si manquantes
    [[ -z "$name" ]] && name="$(basename "$script_file" .sh | tr '-' ' ' | sed 's/\b\w/\U&/g')"
    [[ -z "$description" ]] && description="Script $(basename "$script_file")"
    [[ -z "$author" ]] && author="AtomicOps Team"
    [[ -z "$version" ]] && version="1.0.0"
    
    # Déterminer la catégorie et le niveau à partir du chemin
    if [[ -z "$category" ]]; then
        if [[ "$script_file" =~ /usb[^/]*/ ]]; then
            category="usb"
        elif [[ "$script_file" =~ /iscsi[^/]*/ ]]; then
            category="iscsi"
        elif [[ "$script_file" =~ /network[^/]*/ ]]; then
            category="network"
        elif [[ "$script_file" =~ /system[^/]*/ ]]; then
            category="system"
        else
            category="other"
        fi
    fi
    
    if [[ -z "$level" ]]; then
        if [[ "$script_file" =~ /atomic/ ]]; then
            level="atomic"
        elif [[ "$script_file" =~ /orchestrators/ ]]; then
            level="orchestrator"
        elif [[ "$script_file" =~ /main/ ]]; then
            level="main"
        else
            level="atomic"
        fi
    fi
    
    # Sauvegarder les métadonnées
    cat > "$metadata_file" << EOF
{
    "name": "$name",
    "description": "$description",
    "author": "$author",
    "version": "$version",
    "category": "$category",
    "level": "$level"
}
EOF
    
    echo "$metadata_file"
}

# Extrait les fonctions définies dans un script
extract_functions() {
    local script_file="$1"
    local functions_file="$TEMP_DIR/$(basename "$script_file").functions"
    
    debug "Extraction des fonctions de $script_file"
    
    # Analyser le script pour trouver les définitions de fonctions
    grep -n "^[[:space:]]*function\|^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$script_file" | \
    while IFS=: read -r line_num line_content; do
        # Extraire le nom de la fonction
        local func_name
        if [[ "$line_content" =~ ^[[:space:]]*function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            func_name="${BASH_REMATCH[1]}"
        elif [[ "$line_content" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\( ]]; then
            func_name="${BASH_REMATCH[1]}"
        else
            continue
        fi
        
        # Ignorer les fonctions privées (commençant par _)
        [[ "$func_name" =~ ^_.* ]] && continue
        
        # Extraire la documentation de la fonction
        local func_description=""
        local func_inputs=()
        local func_outputs=()
        
        # Lire les lignes de commentaires avant la fonction
        local current_line=$((line_num - 1))
        while [[ $current_line -gt 0 ]]; do
            local prev_line=$(sed -n "${current_line}p" "$script_file")
            
            # Arrêter si ce n'est plus un commentaire
            if [[ ! "$prev_line" =~ ^[[:space:]]*# ]]; then
                break
            fi
            
            # Extraire la description
            if [[ "$prev_line" =~ ^#[[:space:]]*([^@#:].*)$ ]] && [[ -z "$func_description" ]]; then
                func_description="${BASH_REMATCH[1]}"
            fi
            
            # Extraire les paramètres d'entrée
            if [[ "$prev_line" =~ ^#[[:space:]]*@param[[:space:]]+([^[:space:]]+) ]]; then
                func_inputs+=("${BASH_REMATCH[1]}")
            fi
            
            # Extraire les sorties
            if [[ "$prev_line" =~ ^#[[:space:]]*@(return|output)[[:space:]]+([^[:space:]]+) ]]; then
                func_outputs+=("${BASH_REMATCH[2]}")
            fi
            
            current_line=$((current_line - 1))
        done
        
        # Générer le JSON pour cette fonction
        cat << EOF
        {
            "name": "$func_name",
            "description": "${func_description:-"Fonction $func_name"}",
            "inputs": [$(printf '"%s",' "${func_inputs[@]}" | sed 's/,$//')]],
            "outputs": [$(printf '"%s",' "${func_outputs[@]}" | sed 's/,$//')]
        }
EOF
        
    done > "$functions_file"
    
    echo "$functions_file"
}

# Extrait les dépendances d'un script
extract_dependencies() {
    local script_file="$1"
    local deps_file="$TEMP_DIR/$(basename "$script_file").deps"
    
    debug "Extraction des dépendances de $script_file"
    
    local dependencies=()
    
    # Chercher les appels source/include
    while IFS= read -r line; do
        if [[ "$line" =~ source[[:space:]]+\"?([^\"[:space:]]+)\"? ]] ||
           [[ "$line" =~ \.[[:space:]]+\"?([^\"[:space:]]+)\"? ]]; then
            local dep_path="${BASH_REMATCH[1]}"
            local dep_name=$(basename "$dep_path" .sh)
            dependencies+=("$dep_name")
        fi
    done < "$script_file"
    
    # Chercher les appels directs à d'autres scripts
    while IFS= read -r line; do
        if [[ "$line" =~ \./([a-zA-Z0-9_-]+\.sh) ]] ||
           [[ "$line" =~ bash[[:space:]]+([a-zA-Z0-9_-]+\.sh) ]]; then
            local dep_script="${BASH_REMATCH[1]}"
            local dep_name=$(basename "$dep_script" .sh)
            dependencies+=("$dep_name")
        fi
    done < "$script_file"
    
    # Supprimer les doublons et sauvegarder
    printf '%s\n' "${dependencies[@]}" | sort -u | \
    jq -R -s 'split("\n") | map(select(length > 0))' > "$deps_file"
    
    echo "$deps_file"
}

# Extrait les conditions et prérequis
extract_conditions() {
    local script_file="$1"
    local conditions_file="$TEMP_DIR/$(basename "$script_file").conditions"
    
    debug "Extraction des conditions de $script_file"
    
    local conditions=()
    
    # Chercher les vérifications dans le code
    while IFS= read -r line; do
        # Vérifications de fichiers/répertoires
        if [[ "$line" =~ \[\[[[:space:]]*(-[efdr])[[:space:]]+([^]]+)[[:space:]]*\]\] ]]; then
            local test_op="${BASH_REMATCH[1]}"
            local test_path="${BASH_REMATCH[2]}"
            
            case "$test_op" in
                "-f") conditions+=("fichier_existe: $test_path") ;;
                "-d") conditions+=("repertoire_existe: $test_path") ;;
                "-e") conditions+=("ressource_existe: $test_path") ;;
                "-r") conditions+=("lecture_autorisee: $test_path") ;;
            esac
        fi
        
        # Vérifications de commandes
        if [[ "$line" =~ command[[:space:]]+-v[[:space:]]+([^[:space:]]+) ]] ||
           [[ "$line" =~ which[[:space:]]+([^[:space:]]+) ]]; then
            conditions+=("commande_disponible: ${BASH_REMATCH[1]}")
        fi
        
        # Vérifications de permissions
        if [[ "$line" =~ \$EUID.*==.*0 ]] || [[ "$line" =~ root ]]; then
            conditions+=("permissions_administrateur")
        fi
        
        # Vérifications d'espace disque
        if [[ "$line" =~ df.*-h ]] || [[ "$line" =~ espace ]]; then
            conditions+=("espace_disque_suffisant")
        fi
        
    done < "$script_file"
    
    # Supprimer les doublons et sauvegarder
    printf '%s\n' "${conditions[@]}" | sort -u | \
    jq -R -s 'split("\n") | map(select(length > 0))' > "$conditions_file"
    
    echo "$conditions_file"
}

# Analyse un script complet
analyze_script() {
    local script_file="$1"
    local relative_path="${script_file#$PROJECT_ROOT/}"
    
    info "Analyse de $relative_path"
    
    # Générer un ID unique basé sur le nom du fichier
    local script_id=$(basename "$script_file" .sh | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    
    # Extraire toutes les informations
    local metadata_file=$(extract_header_metadata "$script_file")
    local functions_file=$(extract_functions "$script_file")
    local deps_file=$(extract_dependencies "$script_file")
    local conditions_file=$(extract_conditions "$script_file")
    
    # Obtenir les statistiques du fichier
    local last_modified=$(date -r "$script_file" -Iseconds 2>/dev/null || date -Iseconds)
    local file_size=$(wc -l < "$script_file")
    
    # Déterminer la complexité basée sur la taille et le nombre de fonctions
    local complexity="low"
    local function_count=$(grep -c "^[[:space:]]*function\|^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$script_file" || echo 0)
    
    if [[ $file_size -gt 200 ]] || [[ $function_count -gt 5 ]]; then
        complexity="high"
    elif [[ $file_size -gt 100 ]] || [[ $function_count -gt 2 ]]; then
        complexity="medium"
    fi
    
    # Déterminer le statut (par défaut stable, sauf si marqué autrement)
    local status="stable"
    if grep -q -i "todo\|fixme\|hack\|draft" "$script_file"; then
        status="draft"
    elif grep -q -i "test\|beta" "$script_file"; then
        status="testing"
    fi
    
    # Extraire les tags depuis les commentaires
    local tags=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^#[[:space:]]*[Tt]ags?:[[:space:]]*(.+)$ ]]; then
            IFS=',' read -ra tag_array <<< "${BASH_REMATCH[1]}"
            for tag in "${tag_array[@]}"; do
                tags+=($(echo "$tag" | tr -d ' '))
            done
        fi
    done < "$script_file"
    
    # Ajouter des tags automatiques
    tags+=("$(jq -r '.category' "$metadata_file")")
    tags+=("$(jq -r '.level' "$metadata_file")")
    
    # Combiner toutes les informations
    jq -s --arg id "$script_id" \
         --arg path "$relative_path" \
         --arg lastModified "$last_modified" \
         --argjson lineCount "$file_size" \
         --arg complexity "$complexity" \
         --arg status "$status" \
         --argjson tags "$(printf '%s\n' "${tags[@]}" | sort -u | jq -R . | jq -s .)" \
    '{
        id: $id,
        path: $path,
        lastModified: $lastModified,
        lineCount: $lineCount,
        complexity: $complexity,
        status: $status,
        tags: $tags
    } + .[0] + {
        functions: (if .[1] != "" then [.[1]] else [] end),
        dependencies: .[2],
        conditions: .[3],
        inputs: (.[1] // [] | map(.inputs) | add // []),
        outputs: (.[1] // [] | map(.outputs) | add // [])
    }' "$metadata_file" "$functions_file" "$deps_file" "$conditions_file"
}

# ===========================
# Fonctions Principales
# ===========================

# Trouve tous les scripts à analyser
find_scripts() {
    local scripts=()
    
    # Scripts atomiques
    if [[ -d "$ATOMIC_SCRIPTS_DIR" ]]; then
        while IFS= read -r -d '' script; do
            scripts+=("$script")
        done < <(find "$ATOMIC_SCRIPTS_DIR" -name "*.sh" -type f -print0)
    fi
    
    # Scripts orchestrateurs
    if [[ -d "$ORCHESTRATOR_SCRIPTS_DIR" ]]; then
        while IFS= read -r -d '' script; do
            scripts+=("$script")
        done < <(find "$ORCHESTRATOR_SCRIPTS_DIR" -name "*.sh" -type f -print0)
    fi
    
    # Scripts principaux
    if [[ -d "$MAIN_SCRIPTS_DIR" ]]; then
        while IFS= read -r -d '' script; do
            scripts+=("$script")
        done < <(find "$MAIN_SCRIPTS_DIR" -name "*.sh" -type f -print0)
    fi
    
    # Scripts de niveau racine (CT)
    while IFS= read -r -d '' script; do
        [[ "$(basename "$script")" =~ ^create-.*-CT\.sh$ ]] && scripts+=("$script")
    done < <(find "$PROJECT_ROOT" -maxdepth 1 -name "create-*-CT.sh" -type f -print0)
    
    printf '%s\n' "${scripts[@]}" | sort
}

# Génère les statistiques globales
generate_statistics() {
    local scripts_data="$1"
    
    jq '{
        total: length,
        by_category: (group_by(.category) | map({key: .[0].category, value: length}) | from_entries),
        by_level: (group_by(.level) | map({key: .[0].level, value: length}) | from_entries),
        by_complexity: (group_by(.complexity) | map({key: .[0].complexity, value: length}) | from_entries),
        by_status: (group_by(.status) | map({key: .[0].status, value: length}) | from_entries),
        total_dependencies: (map(.dependencies | length) | add),
        avg_dependencies_per_script: ((map(.dependencies | length) | add) / length | . * 100 | round / 100),
        total_functions: (map(.functions | length) | add),
        avg_functions_per_script: ((map(.functions | length) | add) / length | . * 100 | round / 100),
        total_lines: (map(.lineCount) | add),
        avg_lines_per_script: ((map(.lineCount) | add) / length | round)
    }' <<< "$scripts_data"
}

# Fonction principale
main() {
    info "Démarrage de l'analyse des scripts AtomicOps Suite"
    
    # Vérifier les prérequis
    command -v jq >/dev/null 2>&1 || die "jq est requis mais non installé"
    
    # Configurer l'environnement
    setup_temp_dir
    
    # Créer le répertoire de sortie
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    
    # Trouver tous les scripts
    info "Recherche des scripts à analyser..."
    local scripts
    mapfile -t scripts < <(find_scripts)
    
    if [[ ${#scripts[@]} -eq 0 ]]; then
        warn "Aucun script trouvé à analyser"
        exit 0
    fi
    
    info "Trouvé ${#scripts[@]} script(s) à analyser"
    
    # Analyser chaque script
    local all_scripts_data="["
    local first=true
    
    for script in "${scripts[@]}"; do
        [[ "$first" == "true" ]] && first=false || all_scripts_data+=","
        
        if [[ -r "$script" ]]; then
            all_scripts_data+=$(analyze_script "$script")
        else
            warn "Impossible de lire $script, ignoré"
        fi
    done
    
    all_scripts_data+="]"
    
    # Générer les statistiques
    info "Génération des statistiques..."
    local statistics=$(generate_statistics "$all_scripts_data")
    
    # Créer le JSON final
    local final_json=$(jq -n \
        --argjson scripts "$all_scripts_data" \
        --argjson stats "$statistics" \
        --arg generated "$(date -Iseconds)" \
        --arg version "1.0.0" \
    '{
        metadata: {
            version: $version,
            generated: $generated,
            description: "Base de données générée automatiquement des scripts AtomicOps Suite",
            parser_version: "1.0.0"
        },
        scripts: $scripts,
        statistics: $stats
    }')
    
    # Sauvegarder le résultat
    echo "$final_json" | jq . > "$OUTPUT_FILE"
    
    info "Analyse terminée avec succès"
    info "Résultats sauvegardés dans: $OUTPUT_FILE"
    info "Scripts analysés: $(echo "$all_scripts_data" | jq 'length')"
    info "Catégories détectées: $(echo "$statistics" | jq -r '.by_category | keys | join(", ")')"
    
    # Afficher un résumé si verbose
    if [[ "$VERBOSE" == "true" ]]; then
        info "Résumé détaillé:"
        echo "$statistics" | jq .
    fi
}

# ===========================
# Gestion des Arguments
# ===========================

show_help() {
    cat << EOF
Parser de Scripts Atomiques - AtomicOps Suite

UTILISATION:
    $0 [OPTIONS]

DESCRIPTION:
    Analyse automatiquement tous les scripts du projet AtomicOps Suite
    et génère un fichier JSON avec les métadonnées extraites.

OPTIONS:
    -o, --output FILE    Fichier de sortie (défaut: $OUTPUT_FILE)
    -v, --verbose        Mode verbeux
    -h, --help           Affiche cette aide

EXEMPLES:
    $0                                    # Analyse standard
    $0 -v                                 # Mode verbeux
    $0 -o custom-output.json              # Sortie personnalisée

SORTIE:
    Le fichier JSON généré contient pour chaque script:
    - Métadonnées (nom, description, auteur, etc.)
    - Fonctions définies avec leurs paramètres
    - Dépendances détectées
    - Conditions d'exécution
    - Statistiques diverses

EOF
}

# Traitement des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Exécuter le programme principal
main "$@"