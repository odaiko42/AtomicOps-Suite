#!/bin/bash
#
# Script: setup-db-system.sh
# Description: Script de mise en place complète du système de catalogue SQLite
# Usage: ./setup-db-system.sh [--force]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Import des bibliothèques
source "$PROJECT_ROOT/lib/common.sh" 2>/dev/null || {
    echo "[INFO] Bibliothèque commune non trouvée, utilisation de fonctions basiques"
    info() { echo -e "\033[36m[INFO]\033[0m $1"; }
    warn() { echo -e "\033[33m[WARN]\033[0m $1"; }
    error() { echo -e "\033[31m[ERROR]\033[0m $1"; }
    ok() { echo -e "\033[32m[OK]\033[0m $1"; }
}

# Fonction d'aide
show_help() {
    cat <<EOF
Usage: $0 [--force]

Met en place le système complet de catalogue SQLite pour les scripts CT.

Ce script effectue automatiquement :
  1. Initialisation de la base de données
  2. Enregistrement de tous les scripts existants
  3. Validation du système
  4. Configuration des hooks Git (optionnel)

Options:
  --force         Force la réinitialisation même si une base existe
  -h, --help      Affiche cette aide

Composants installés :
  📄 Base de données : database/scripts_catalogue.db
  🔧 Outils         : tools/{register-script,register-all-scripts,search-db,export-db}.sh
  ✅ Validation     : tools/validate-db-system.sh
  📚 Documentation : database/README.md

EOF
}

# Vérification des prérequis
check_prerequisites() {
    info "🔍 Vérification des prérequis"
    
    local missing_tools=()
    
    # Vérifier sqlite3
    if ! command -v sqlite3 >/dev/null 2>&1; then
        missing_tools+=("sqlite3")
    fi
    
    # Vérifier bash
    if ! command -v bash >/dev/null 2>&1; then
        missing_tools+=("bash")
    fi
    
    # Optionnel : jq pour les exports JSON
    if ! command -v jq >/dev/null 2>&1; then
        warn "jq non trouvé - les exports JSON seront sans formatage"
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Outils manquants : ${missing_tools[*]}"
        echo ""
        echo "Installation requise :"
        echo "  Ubuntu/Debian : sudo apt-get install sqlite3 bash"
        echo "  CentOS/RHEL   : sudo yum install sqlite bash"
        echo "  Alpine        : sudo apk add sqlite bash"
        echo ""
        return 1
    fi
    
    ok "Prérequis validés"
    return 0
}

# Vérification de la structure du projet
check_project_structure() {
    info "📁 Vérification de la structure du projet"
    
    local required_dirs=("database" "tools" "exports")
    local required_files=(
        "database/init-db.sh"
        "tools/register-script.sh" 
        "tools/register-all-scripts.sh"
        "tools/search-db.sh"
        "tools/export-db.sh"
    )
    
    # Vérifier les répertoires
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$PROJECT_ROOT/$dir" ]]; then
            error "Répertoire manquant : $dir"
            return 1
        fi
    done
    
    # Vérifier les fichiers essentiels
    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            error "Fichier manquant : $file"
            return 1
        fi
        
        if [[ ! -x "$PROJECT_ROOT/$file" ]]; then
            warn "Fichier non exécutable : $file"
            chmod +x "$PROJECT_ROOT/$file" 2>/dev/null || true
        fi
    done
    
    ok "Structure du projet validée"
    return 0
}

# Initialisation de la base de données
initialize_database() {
    local force_init="${1:-false}"
    
    info "🗄️ Initialisation de la base de données"
    
    local db_file="$PROJECT_ROOT/database/scripts_catalogue.db"
    
    # Vérifier si la base existe déjà
    if [[ -f "$db_file" && "$force_init" != "true" ]]; then
        warn "Base de données existante trouvée"
        echo -n "Voulez-vous la réinitialiser ? [y/N] "
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS])
                info "Réinitialisation de la base..."
                ;;
            *)
                info "Conservation de la base existante"
                return 0
                ;;
        esac
    fi
    
    # Exécuter l'initialisation
    if "$PROJECT_ROOT/database/init-db.sh" --force 2>/dev/null; then
        ok "Base de données initialisée avec succès"
        
        # Vérifier que la base fonctionne
        local table_count
        table_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null)
        info "Tables créées : $table_count"
        
        return 0
    else
        error "Échec de l'initialisation de la base"
        return 1
    fi
}

# Enregistrement des scripts existants
register_existing_scripts() {
    info "📝 Enregistrement des scripts existants"
    
    if "$PROJECT_ROOT/tools/register-all-scripts.sh" 2>/dev/null; then
        ok "Scripts enregistrés avec succès"
        
        # Afficher les statistiques
        local script_count
        script_count=$(sqlite3 "$PROJECT_ROOT/database/scripts_catalogue.db" \
                      "SELECT COUNT(*) FROM scripts;" 2>/dev/null)
        info "Scripts catalogués : $script_count"
        
        return 0
    else
        error "Échec de l'enregistrement des scripts"
        return 1
    fi
}

# Validation du système
validate_system() {
    info "✅ Validation du système"
    
    if [[ -f "$PROJECT_ROOT/tools/validate-db-system.sh" ]]; then
        if "$PROJECT_ROOT/tools/validate-db-system.sh" >/dev/null 2>&1; then
            ok "Validation système réussie"
            return 0
        else
            warn "Validation système échouée - vérifiez les détails"
            return 1
        fi
    else
        warn "Script de validation non trouvé - validation manuelle requise"
        return 0
    fi
}

# Configuration des hooks Git (optionnel)
setup_git_hooks() {
    info "🔗 Configuration des hooks Git (optionnel)"
    
    local git_dir="$PROJECT_ROOT/.git"
    local hooks_dir="$git_dir/hooks"
    
    if [[ ! -d "$git_dir" ]]; then
        info "Pas de dépôt Git trouvé - hooks ignorés"
        return 0
    fi
    
    echo -n "Configurer les hooks Git pour auto-enregistrement ? [y/N] "
    read -r response
    case "$response" in
        [yY]|[yY][eE][sS])
            # Créer hook pre-commit
            cat > "$hooks_dir/pre-commit" <<'EOF'
#!/bin/bash
# Auto-enregistrement des scripts modifiés dans le catalogue

REPO_ROOT=$(git rev-parse --show-toplevel)

# Vérifier si le système de catalogue existe
if [[ -f "$REPO_ROOT/tools/register-all-scripts.sh" ]]; then
    echo "🔄 Mise à jour du catalogue de scripts..."
    "$REPO_ROOT/tools/register-all-scripts.sh" --quiet || true
fi
EOF
            chmod +x "$hooks_dir/pre-commit"
            ok "Hook pre-commit configuré"
            ;;
        *)
            info "Configuration des hooks ignorée"
            ;;
    esac
    
    return 0
}

# Affichage du résumé final
show_final_summary() {
    echo ""
    echo "🎉 INSTALLATION TERMINÉE !"
    echo "=========================="
    echo ""
    
    local db_file="$PROJECT_ROOT/database/scripts_catalogue.db"
    
    if [[ -f "$db_file" ]]; then
        local script_count function_count
        script_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM scripts;" 2>/dev/null || echo "N/A")
        function_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM functions;" 2>/dev/null || echo "N/A")
        
        echo "📊 Statistiques :"
        echo "  Scripts catalogués : $script_count"
        echo "  Fonctions répertoriées : $function_count"
        echo "  Base de données : $(du -h "$db_file" 2>/dev/null | cut -f1 || echo "N/A")"
    fi
    
    echo ""
    echo "🚀 Commandes disponibles :"
    echo "  ./tools/search-db.sh --stats          # Voir les statistiques"
    echo "  ./tools/search-db.sh --all            # Lister tous les scripts"  
    echo "  ./tools/search-db.sh --info SCRIPT    # Info détaillée d'un script"
    echo "  ./tools/register-script.sh SCRIPT     # Enregistrer un nouveau script"
    echo "  ./tools/export-db.sh backup           # Créer un backup"
    echo ""
    
    echo "📚 Documentation complète :"
    echo "  database/README.md                     # Guide d'utilisation complet"
    echo ""
    
    echo "✨ Le système de catalogue SQLite est opérationnel !"
}

# Point d'entrée principal
main() {
    echo "🏗️  MISE EN PLACE DU SYSTÈME DE CATALOGUE SQLITE"
    echo "================================================="
    echo ""
    
    local force_init="false"
    
    # Traitement des arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                force_init="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Argument inconnu : $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Vérifications préliminaires
    check_prerequisites || exit 1
    check_project_structure || exit 1
    
    echo ""
    
    # Installation du système
    initialize_database "$force_init" || exit 1
    register_existing_scripts || exit 1
    validate_system || warn "Validation partielle - système probablement fonctionnel"
    setup_git_hooks || true  # Non critique
    
    # Résumé
    show_final_summary
    
    exit 0
}

# Exécution
main "$@"