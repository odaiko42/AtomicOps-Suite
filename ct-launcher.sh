#!/usr/bin/env bash

#===============================================================================
# CT Launcher - Lanceur de scripts de création de containers Proxmox
#===============================================================================
# Description : Interface interactive pour le lancement des scripts de création CT
# Localisation : Racine du projet
# Utilisation : ./ct-launcher.sh [--auto] [--ctid ID]
#
# Ce script présente un menu interactif des différents scripts de création
# de containers Proxmox disponibles et lance celui sélectionné.
#===============================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CT_SCRIPTS_DIR="$SCRIPT_DIR"

# === VARIABLES GLOBALES ===
AUTO_MODE=false
CTID_OVERRIDE=""
DEBUG_MODE=false

# === COULEURS POUR L'AFFICHAGE ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# === FONCTIONS D'AFFICHAGE ===
print_header() {
    echo -e "${CYAN}===============================================================================${NC}"
    echo -e "${CYAN}                    🚀 PROXMOX CT LAUNCHER 🚀${NC}"
    echo -e "${CYAN}          Lanceur de scripts de création de containers Proxmox${NC}"
    echo -e "${CYAN}===============================================================================${NC}"
    echo ""
}

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_debug() { [[ "$DEBUG_MODE" == true ]] && echo -e "${MAGENTA}[DEBUG]${NC} $1"; }

# === FONCTION D'AIDE ===
show_help() {
    cat << EOF
CT Launcher - Lanceur de scripts de création de containers Proxmox

USAGE:
    $(basename "$0") [OPTIONS]

DESCRIPTION:
    Interface interactive pour lancer les scripts de création de containers
    Proxmox. Détecte automatiquement tous les scripts create-*-CT.sh 
    disponibles et permet leur exécution avec paramètres configurables.

OPTIONS:
    --auto              Mode automatique (pas d'interaction utilisateur)
    --ctid ID           Force l'utilisation du CTID spécifié
    --debug             Active le mode debug avec traces détaillées
    --list              Liste les scripts CT disponibles et quitte
    --help              Affiche cette aide

EXEMPLES:
    # Lancement interactif
    $(basename "$0")
    
    # Mode automatique avec CTID forcé
    $(basename "$0") --auto --ctid 200
    
    # Liste des scripts disponibles
    $(basename "$0") --list

SCRIPTS CT DÉTECTÉS:
    Les scripts suivant le pattern 'create-*-CT.sh' sont automatiquement
    détectés et proposés dans le menu interactif.

CONFIGURATION:
    - Répertoire de scripts : $CT_SCRIPTS_DIR
    - Variables d'environnement supportées : CTID, HOSTNAME_OVERRIDE, etc.
EOF
}

# === DÉTECTION DES SCRIPTS CT ===
detect_ct_scripts() {
    local scripts=()
    
    print_debug "Recherche des scripts CT dans : $CT_SCRIPTS_DIR"
    
    # Recherche des scripts create-*-CT.sh
    for script in "$CT_SCRIPTS_DIR"/create-*-CT.sh; do
        if [[ -f "$script" && -x "$script" ]]; then
            scripts+=("$script")
            print_debug "Script CT trouvé : $(basename "$script")"
        fi
    done
    
    if [[ ${#scripts[@]} -eq 0 ]]; then
        print_warning "Aucun script CT trouvé dans $CT_SCRIPTS_DIR"
        print_info "Les scripts doivent suivre le pattern : create-*-CT.sh"
        return 1
    fi
    
    # Stockage dans un fichier temporaire pour accès global
    printf "%s\n" "${scripts[@]}" > /tmp/ct_scripts_$$
    
    print_success "Détecté ${#scripts[@]} script(s) CT disponible(s)"
    return 0
}

# === AFFICHAGE DU MENU ===
display_menu() {
    local scripts_file="/tmp/ct_scripts_$$"
    local index=1
    
    echo ""
    echo -e "${GREEN}📋 Scripts de création CT disponibles :${NC}"
    echo ""
    
    while IFS= read -r script; do
        local script_name=$(basename "$script")
        local description=$(extract_description "$script")
        
        echo -e "${YELLOW}  [$index]${NC} $script_name"
        [[ -n "$description" ]] && echo -e "      ${CYAN}→${NC} $description"
        echo ""
        ((index++))
    done < "$scripts_file"
    
    echo -e "${YELLOW}  [0]${NC} Quitter"
    echo ""
}

# === EXTRACTION DE DESCRIPTION ===
extract_description() {
    local script_file="$1"
    
    # Recherche d'une ligne de description dans les commentaires
    grep -m 1 "^# Description\|^# Objectif\|^#.*CT.*:" "$script_file" 2>/dev/null | \
        sed 's/^#[[:space:]]*//' | \
        cut -c1-60 || echo "Script de création CT"
}

# === SÉLECTION DE SCRIPT ===
select_script() {
    local scripts_file="/tmp/ct_scripts_$$"
    local total_scripts=$(wc -l < "$scripts_file")
    
    while true; do
        echo -e -n "${BLUE}Sélectionnez un script [1-$total_scripts, 0 pour quitter] : ${NC}"
        read -r choice
        
        if [[ "$choice" == "0" ]]; then
            print_info "Arrêt demandé par l'utilisateur"
            return 1
        elif [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [[ "$choice" -le "$total_scripts" ]]; then
            local selected_script=$(sed -n "${choice}p" "$scripts_file")
            echo "$selected_script" > /tmp/ct_selected_$$
            return 0
        else
            print_error "Sélection invalide. Veuillez choisir entre 1 et $total_scripts, ou 0 pour quitter."
        fi
    done
}

# === CONFIGURATION DES PARAMÈTRES ===
configure_parameters() {
    local script_file="$1"
    
    echo ""
    echo -e "${GREEN}⚙️  Configuration des paramètres :${NC}"
    echo ""
    
    # Configuration du CTID
    if [[ -n "$CTID_OVERRIDE" ]]; then
        export CTID="$CTID_OVERRIDE"
        print_info "CTID forcé : $CTID"
    else
        echo -e -n "${BLUE}CTID du container [auto] : ${NC}"
        read -r ctid_input
        [[ -n "$ctid_input" ]] && export CTID="$ctid_input"
    fi
    
    # Configuration du hostname
    echo -e -n "${BLUE}Hostname du container [auto] : ${NC}"
    read -r hostname_input
    [[ -n "$hostname_input" ]] && export HOSTNAME_OVERRIDE="$hostname_input"
    
    # Configuration du stockage
    echo -e -n "${BLUE}Stockage Proxmox [local-lvm] : ${NC}"
    read -r storage_input
    [[ -n "$storage_input" ]] && export ROOTFS_STORAGE="$storage_input"
    
    # Configuration de la taille du disque
    echo -e -n "${BLUE}Taille du disque en GB [8] : ${NC}"
    read -r disk_input
    [[ -n "$disk_input" ]] && export DISK_GB="$disk_input"
    
    echo ""
    print_success "Configuration terminée"
}

# === EXÉCUTION DU SCRIPT CT ===
execute_ct_script() {
    local script_file="$1"
    local script_name=$(basename "$script_file")
    
    print_info "Exécution de $script_name..."
    echo ""
    
    # Affichage des variables d'environnement si debug
    if [[ "$DEBUG_MODE" == true ]]; then
        print_debug "Variables d'environnement :"
        env | grep -E "^(CTID|HOSTNAME_OVERRIDE|ROOTFS_STORAGE|DISK_GB)" || true
        echo ""
    fi
    
    # Exécution du script
    print_info "Lancement de : $script_file"
    echo -e "${CYAN}===============================================================================${NC}"
    
    if bash "$script_file"; then
        echo ""
        echo -e "${CYAN}===============================================================================${NC}"
        print_success "Script $script_name exécuté avec succès !"
        return 0
    else
        local exit_code=$?
        echo ""
        echo -e "${CYAN}===============================================================================${NC}"
        print_error "Échec du script $script_name (code de sortie: $exit_code)"
        return $exit_code
    fi
}

# === MODE LISTE ===
list_scripts() {
    if ! detect_ct_scripts; then
        return 1
    fi
    
    echo ""
    echo -e "${GREEN}Scripts CT disponibles dans $CT_SCRIPTS_DIR :${NC}"
    echo ""
    
    local index=1
    while IFS= read -r script; do
        local script_name=$(basename "$script")
        local description=$(extract_description "$script")
        
        echo -e "${YELLOW}$index.${NC} $script_name"
        echo -e "   ${CYAN}Description:${NC} $description"
        echo -e "   ${CYAN}Chemin:${NC} $script"
        echo ""
        ((index++))
    done < /tmp/ct_scripts_$$
    
    cleanup
}

# === NETTOYAGE ===
cleanup() {
    rm -f /tmp/ct_*_$$ 2>/dev/null || true
}

# === GESTION DES ARGUMENTS ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                AUTO_MODE=true
                shift
                ;;
            --ctid)
                CTID_OVERRIDE="$2"
                shift 2
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            --list)
                detect_ct_scripts && list_scripts
                exit 0
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Argument inconnu : $1"
                show_help >&2
                exit 1
                ;;
        esac
    done
}

# === FONCTION PRINCIPALE ===
main() {
    # Configuration du piégeage pour nettoyage
    trap cleanup EXIT INT TERM
    
    # Parsing des arguments
    parse_args "$@"
    
    # Affichage de l'en-tête
    print_header
    
    # Détection des scripts disponibles
    if ! detect_ct_scripts; then
        exit 1
    fi
    
    # Mode automatique ou interactif
    if [[ "$AUTO_MODE" == true ]]; then
        # En mode auto, prendre le premier script disponible
        local first_script=$(head -1 /tmp/ct_scripts_$$)
        echo "$first_script" > /tmp/ct_selected_$$
        print_info "Mode automatique : sélection de $(basename "$first_script")"
    else
        # Mode interactif
        display_menu
        if ! select_script; then
            exit 0
        fi
    fi
    
    # Récupération du script sélectionné
    local selected_script=$(cat /tmp/ct_selected_$$)
    local script_name=$(basename "$selected_script")
    
    print_success "Script sélectionné : $script_name"
    
    # Configuration des paramètres (sauf en mode auto)
    if [[ "$AUTO_MODE" == false ]]; then
        configure_parameters "$selected_script"
    fi
    
    # Exécution du script
    execute_ct_script "$selected_script"
    local exit_code=$?
    
    # Nettoyage
    cleanup
    
    exit $exit_code
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi