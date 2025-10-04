#!/usr/bin/env bash

# ===================================================================
# Script: set-cpu.governor.sh
# Description: Définit le gouverneur CPU
# Author: AtomicOps-Suite
# Version: 1.0
# Niveau: atomic
# Catégorie: performance
# ===================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"

# Source des librairies communes
if [[ -f "$LIB_DIR/lib-atomics-common.sh" ]]; then
    source "$LIB_DIR/lib-atomics-common.sh"
fi

# === VARIABLES GLOBALES ===
GOVERNOR=""
CPU_LIST="all"
VERBOSE=false
QUIET=false
DRY_RUN=false
FORCE=false

# === FONCTIONS ===

#################################################################
# Affiche l'aide du script
# Arguments: Aucun
# Retour: 0
#################################################################
show_help() {
    cat << 'EOF'
set-cpu.governor.sh - Définit le gouverneur CPU

SYNOPSIS:
    set-cpu.governor.sh -g GOVERNOR [OPTIONS]

DESCRIPTION:
    Ce script configure le gouverneur de fréquence CPU :
    - Gouverneurs supportés: performance, powersave, ondemand, 
      conservative, userspace, schedutil
    - Application sur CPU spécifiques ou tous les CPUs
    - Vérification des gouverneurs disponibles
    - Sauvegarde de l'état précédent
    
DÉPENDANCES:
    - cpufreq-set [recommandé]
    - /sys/devices/system/cpu/cpu*/cpufreq/ [alternative]
    - Permissions root requises
    
OPTIONS:
    -g, --governor GOVERNOR  Gouverneur à appliquer (obligatoire)
    -c, --cpu CPU_LIST      CPUs cibles (ex: 0,1,2 ou all) [défaut: all]
    -n, --dry-run           Simulation sans modification
    -f, --force             Forcer même si le gouverneur est déjà actif
    -v, --verbose           Mode verbeux
    -q, --quiet             Mode silencieux
    -h, --help              Affiche cette aide

GOUVERNEURS DISPONIBLES:
    performance     Fréquence maximale constante
    powersave       Fréquence minimale constante  
    ondemand        Adaptation dynamique (défaut sur la plupart des systèmes)
    conservative    Adaptation progressive
    userspace       Contrôle manuel par l'utilisateur
    schedutil       Basé sur le scheduler (kernel récents)

EXEMPLES:
    # Passer en mode performance
    sudo ./set-cpu.governor.sh -g performance
    
    # Mode économie d'énergie sur CPU 0 et 1
    sudo ./set-cpu.governor.sh -g powersave -c 0,1
    
    # Simulation du changement
    ./set-cpu.governor.sh -g ondemand --dry-run
    
    # Forcer le changement même si déjà actif
    sudo ./set-cpu.governor.sh -g performance --force

CODES DE RETOUR:
    0    Succès
    1    Erreur générale
    2    Permissions insuffisantes
    3    Gouverneur non supporté
    4    CPU non trouvé
EOF
}

#################################################################
# Parse les arguments de la ligne de commande
# Arguments: $@
# Retour: 0 si succès, 1 sinon
#################################################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -g|--governor)
                if [[ -z "${2:-}" ]]; then
                    atomic_error "Gouverneur requis pour l'option --governor"
                    return 1
                fi
                GOVERNOR="$2"
                shift 2
                ;;
            -c|--cpu)
                if [[ -z "${2:-}" ]]; then
                    atomic_error "Liste CPU requise pour l'option --cpu"
                    return 1
                fi
                CPU_LIST="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                atomic_error "Option inconnue: $1"
                return 1
                ;;
            *)
                atomic_error "Argument non reconnu: $1"
                return 1
                ;;
        esac
    done
    
    # Vérification des arguments obligatoires
    if [[ -z "$GOVERNOR" ]]; then
        atomic_error "Gouverneur requis (-g|--governor)"
        return 1
    fi
    
    return 0
}

#################################################################
# Vérifie les permissions et dépendances
# Arguments: Aucun
# Retour: 0 si OK, 2 sinon
#################################################################
check_requirements() {
    # Vérification des permissions (sauf en dry-run)
    if ! $DRY_RUN; then
        if [[ $EUID -ne 0 ]]; then
            atomic_error "Permissions root requises pour modifier les gouverneurs"
            atomic_info "Exécutez avec sudo ou en tant que root"
            return 2
        fi
    fi
    
    # Vérification de l'existence de cpufreq
    if [[ ! -d "/sys/devices/system/cpu/cpu0/cpufreq" ]]; then
        atomic_error "Support cpufreq non disponible dans le kernel"
        atomic_info "Vérifiez que le module cpufreq est chargé"
        return 2
    fi
    
    return 0
}

#################################################################
# Obtient la liste des gouverneurs disponibles pour un CPU
# Arguments: $1 (numéro CPU)
# Retour: 0 si succès, liste dans AVAILABLE_GOVERNORS
#################################################################
get_available_governors() {
    local cpu_num="$1"
    local governors_file="/sys/devices/system/cpu/cpu${cpu_num}/cpufreq/scaling_available_governors"
    
    if [[ ! -r "$governors_file" ]]; then
        return 1
    fi
    
    AVAILABLE_GOVERNORS=$(cat "$governors_file" 2>/dev/null)
    return 0
}

#################################################################
# Vérifie si un gouverneur est supporté
# Arguments: $1 (gouverneur), $2 (numéro CPU)
# Retour: 0 si supporté, 3 sinon
#################################################################
check_governor_support() {
    local governor="$1"
    local cpu_num="$2"
    
    if ! get_available_governors "$cpu_num"; then
        atomic_error "Impossible de lire les gouverneurs disponibles pour CPU $cpu_num"
        return 3
    fi
    
    if [[ " $AVAILABLE_GOVERNORS " =~ " $governor " ]]; then
        return 0
    else
        atomic_error "Gouverneur '$governor' non supporté sur CPU $cpu_num"
        atomic_info "Gouverneurs disponibles: $AVAILABLE_GOVERNORS"
        return 3
    fi
}

#################################################################
# Obtient le gouverneur actuel d'un CPU
# Arguments: $1 (numéro CPU)
# Retour: gouverneur actuel dans CURRENT_GOVERNOR
#################################################################
get_current_governor() {
    local cpu_num="$1"
    local governor_file="/sys/devices/system/cpu/cpu${cpu_num}/cpufreq/scaling_governor"
    
    if [[ -r "$governor_file" ]]; then
        CURRENT_GOVERNOR=$(cat "$governor_file" 2>/dev/null)
        return 0
    fi
    
    return 1
}

#################################################################
# Applique le gouverneur à un CPU
# Arguments: $1 (numéro CPU), $2 (gouverneur)
# Retour: 0 si succès, 1 sinon
#################################################################
set_cpu_governor() {
    local cpu_num="$1"
    local governor="$2"
    local governor_file="/sys/devices/system/cpu/cpu${cpu_num}/cpufreq/scaling_governor"
    
    # Vérification de l'existence du CPU
    if [[ ! -d "/sys/devices/system/cpu/cpu${cpu_num}/cpufreq" ]]; then
        atomic_error "CPU $cpu_num non trouvé ou cpufreq non disponible"
        return 4
    fi
    
    # Vérification du support du gouverneur
    if ! check_governor_support "$governor" "$cpu_num"; then
        return 3
    fi
    
    # Vérification de l'état actuel
    if get_current_governor "$cpu_num"; then
        if [[ "$CURRENT_GOVERNOR" == "$governor" ]] && ! $FORCE; then
            if $VERBOSE; then
                atomic_info "CPU $cpu_num: gouverneur '$governor' déjà actif"
            fi
            return 0
        fi
    fi
    
    if $DRY_RUN; then
        atomic_info "DRY-RUN: CPU $cpu_num: $CURRENT_GOVERNOR -> $governor"
        return 0
    fi
    
    # Tentative via cpufreq-set d'abord
    if command -v cpufreq-set >/dev/null 2>&1; then
        if cpufreq-set -c "$cpu_num" -g "$governor" 2>/dev/null; then
            if $VERBOSE; then
                atomic_success "CPU $cpu_num: gouverneur '$governor' appliqué via cpufreq-set"
            fi
            return 0
        fi
    fi
    
    # Fallback via sysfs
    if [[ -w "$governor_file" ]]; then
        if echo "$governor" > "$governor_file" 2>/dev/null; then
            if $VERBOSE; then
                atomic_success "CPU $cpu_num: gouverneur '$governor' appliqué via sysfs"
            fi
            return 0
        else
            atomic_error "Échec d'écriture du gouverneur pour CPU $cpu_num"
            return 1
        fi
    else
        atomic_error "Fichier gouverneur non accessible en écriture: $governor_file"
        return 2
    fi
}

#################################################################
# Parse la liste des CPUs cibles
# Arguments: Aucun (utilise CPU_LIST)
# Retour: liste dans CPU_TARGETS_ARRAY
#################################################################
parse_cpu_list() {
    CPU_TARGETS_ARRAY=()
    
    if [[ "$CPU_LIST" == "all" ]]; then
        # Tous les CPUs disponibles
        for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
            if [[ -d "$cpu_dir/cpufreq" ]]; then
                local cpu_num
                cpu_num=$(basename "$cpu_dir" | sed 's/cpu//')
                CPU_TARGETS_ARRAY+=("$cpu_num")
            fi
        done
    else
        # Liste spécifique (séparée par virgules)
        IFS=',' read -ra CPUS <<< "$CPU_LIST"
        for cpu in "${CPUS[@]}"; do
            # Nettoyer les espaces
            cpu=$(echo "$cpu" | xargs)
            if [[ "$cpu" =~ ^[0-9]+$ ]]; then
                CPU_TARGETS_ARRAY+=("$cpu")
            else
                atomic_error "Numéro CPU invalide: $cpu"
                return 1
            fi
        done
    fi
    
    if [[ ${#CPU_TARGETS_ARRAY[@]} -eq 0 ]]; then
        atomic_error "Aucun CPU cible trouvé"
        return 1
    fi
    
    return 0
}

#################################################################
# Affiche l'état actuel des gouverneurs
# Arguments: Aucun
# Retour: 0
#################################################################
show_current_state() {
    echo "=== État actuel des gouverneurs ==="
    for cpu_num in "${CPU_TARGETS_ARRAY[@]}"; do
        if get_current_governor "$cpu_num"; then
            echo "CPU $cpu_num: $CURRENT_GOVERNOR"
        else
            echo "CPU $cpu_num: Erreur lecture"
        fi
    done
    echo ""
}

#################################################################
# Fonction principale
# Arguments: $@
# Retour: Code d'erreur approprié
#################################################################
main() {
    local success_count=0
    local error_count=0
    
    # Initialisation du logging
    atomic_init_logging "$SCRIPT_NAME" "$QUIET"
    
    # Parse des arguments
    if ! parse_args "$@"; then
        atomic_error "Erreur dans les arguments"
        show_help >&2
        return 1
    fi
    
    # Mode verbeux
    if $VERBOSE; then
        atomic_info "Démarrage de $SCRIPT_NAME"
        atomic_info "Gouverneur cible: $GOVERNOR"
        atomic_info "CPUs cibles: $CPU_LIST"
        if $DRY_RUN; then
            atomic_info "Mode simulation activé"
        fi
    fi
    
    # Vérifications préalables
    if ! check_requirements; then
        return 2
    fi
    
    # Parse de la liste des CPUs
    if ! parse_cpu_list; then
        return 1
    fi
    
    # Affichage de l'état actuel en mode verbeux
    if $VERBOSE; then
        show_current_state
    fi
    
    # Application du gouverneur sur chaque CPU
    for cpu_num in "${CPU_TARGETS_ARRAY[@]}"; do
        if set_cpu_governor "$cpu_num" "$GOVERNOR"; then
            ((success_count++))
        else
            ((error_count++))
        fi
    done
    
    # Résumé
    if ! $QUIET; then
        if $DRY_RUN; then
            atomic_info "Simulation terminée: ${#CPU_TARGETS_ARRAY[@]} CPUs traités"
        else
            atomic_info "Gouverneur appliqué: $success_count succès, $error_count erreurs"
        fi
    fi
    
    # Affichage du nouvel état en mode verbeux
    if $VERBOSE && ! $DRY_RUN && [[ $success_count -gt 0 ]]; then
        echo ""
        show_current_state
    fi
    
    # Code de retour basé sur les résultats
    if [[ $error_count -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# === EXÉCUTION ===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi