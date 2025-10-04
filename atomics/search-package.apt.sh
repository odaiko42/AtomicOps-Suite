#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: search-package.apt.sh 
# Description: Rechercher des paquets avec APT
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="search-package.apt.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
SEARCH_TERM=""
SEARCH_TYPE=${SEARCH_TYPE:-"name"}
INSTALLED_ONLY=${INSTALLED_ONLY:-0}
AVAILABLE_ONLY=${AVAILABLE_ONLY:-0}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <search_term>

Description:
    Recherche des paquets dans les dépôts APT avec filtrage
    et informations détaillées sur les résultats.

Arguments:
    <search_term>    Terme de recherche (nom ou description)

Options:
    -h, --help       Afficher cette aide
    -v, --verbose    Mode verbeux
    -d, --debug      Mode debug
    -q, --quiet      Mode silencieux
    -j, --json-only  Sortie JSON uniquement
    -t, --type TYPE  Type recherche (name|description|all)
    --installed      Paquets installés seulement
    --available      Paquets disponibles seulement
    
Exemples:
    $SCRIPT_NAME nginx
    $SCRIPT_NAME -t description "web server"
    $SCRIPT_NAME --installed python
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            -v|--verbose) VERBOSE=1; shift ;;
            -d|--debug) DEBUG=1; VERBOSE=1; shift ;;
            -q|--quiet) QUIET=1; shift ;;
            -j|--json-only) JSON_ONLY=1; QUIET=1; shift ;;
            -t|--type) SEARCH_TYPE="$2"; shift 2 ;;
            --installed) INSTALLED_ONLY=1; shift ;;
            --available) AVAILABLE_ONLY=1; shift ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                [[ -z "$SEARCH_TERM" ]] && SEARCH_TERM="$1" || { echo "Trop d'arguments" >&2; exit 2; }
                shift ;;
        esac
    done

    [[ -z "$SEARCH_TERM" ]] && { echo "Terme de recherche manquant" >&2; exit 2; }
}

check_apt() {
    command -v apt >/dev/null 2>&1 || command -v apt-cache >/dev/null 2>&1
}

search_packages() {
    local term="$1" type="$2"
    local search_cmd=""
    
    case "$type" in
        name)
            if [[ $INSTALLED_ONLY -eq 1 ]]; then
                search_cmd="dpkg -l | grep \"$term\""
            else
                search_cmd="apt-cache search --names-only \"$term\""
            fi
            ;;
        description|all)
            if [[ $INSTALLED_ONLY -eq 1 ]]; then
                search_cmd="dpkg -l | grep \"$term\""
            else
                search_cmd="apt-cache search \"$term\""
            fi
            ;;
    esac
    
    eval "$search_cmd" 2>/dev/null || true
}

get_package_info() {
    local package="$1"
    local info="{}"
    
    if apt-cache show "$package" >/dev/null 2>&1; then
        local version description size installed
        version=$(apt-cache policy "$package" | grep "Candidate:" | awk '{print $2}' || echo "unknown")
        description=$(apt-cache show "$package" | grep "^Description:" | cut -d: -f2- | head -1 | xargs || echo "No description")
        size=$(apt-cache show "$package" | grep "^Size:" | cut -d: -f2 | xargs || echo "0")
        
        # Vérifier si installé
        if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
            installed="true"
        else
            installed="false"
        fi
        
        info=$(cat << EOF
{
  "name": "$package",
  "version": "$version",
  "description": "$description",
  "size": $size,
  "installed": $installed
}
EOF
)
    fi
    
    echo "$info"
}

parse_search_results() {
    local results="$1" type="$2"
    local packages=()
    
    if [[ $INSTALLED_ONLY -eq 1 ]]; then
        while read -r line; do
            if [[ "$line" =~ ^ii[[:space:]]+([^[:space:]]+) ]]; then
                local pkg="${BASH_REMATCH[1]}"
                packages+=("$pkg")
            fi
        done <<< "$results"
    else
        while read -r line; do
            if [[ -n "$line" && ! "$line" =~ ^WARNING ]]; then
                local pkg
                pkg=$(echo "$line" | awk '{print $1}')
                [[ -n "$pkg" ]] && packages+=("$pkg")
            fi
        done <<< "$results"
    fi
    
    printf '%s\n' "${packages[@]}"
}

main() {
    parse_args "$@"
    
    local errors=() warnings=()
    
    if ! check_apt; then
        errors+=("APT package manager not available")
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        local search_results packages_info=() found_packages=()
        
        search_results=$(search_packages "$SEARCH_TERM" "$SEARCH_TYPE")
        
        if [[ -n "$search_results" ]]; then
            readarray -t found_packages < <(parse_search_results "$search_results" "$SEARCH_TYPE")
            
            # Limiter à 50 résultats pour éviter surcharge
            local max_packages=50
            local processed=0
            
            for package in "${found_packages[@]}"; do
                [[ $processed -ge $max_packages ]] && break
                
                if [[ $AVAILABLE_ONLY -eq 1 ]]; then
                    # Vérifier si le paquet n'est pas installé
                    if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
                        continue
                    fi
                fi
                
                local pkg_info
                pkg_info=$(get_package_info "$package")
                [[ "$pkg_info" != "{}" ]] && packages_info+=("$pkg_info")
                
                processed=$((processed + 1))
            done
            
            if [[ $processed -ge $max_packages ]]; then
                warnings+=("Results limited to $max_packages packages")
            fi
        fi
        
        cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Package search completed",
  "data": {
    "search_term": "$SEARCH_TERM",
    "search_type": "$SEARCH_TYPE",
    "filters": {
      "installed_only": $([ $INSTALLED_ONLY -eq 1 ] && echo "true" || echo "false"),
      "available_only": $([ $AVAILABLE_ONLY -eq 1 ] && echo "true" || echo "false")
    },
    "results": {
      "total_found": ${#found_packages[@]},
      "displayed": ${#packages_info[@]},
      "packages": [$(IFS=','; echo "${packages_info[*]}")]
    }
  },
  "errors": [],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
    else
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Package search failed",
  "data": {},
  "errors": [$(printf '"%s",' "${errors[@]}" | sed 's/,$//')],
  "warnings": []
}
EOF
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi