#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: set-env.variable.sh 
# Description: Configurer des variables d'environnement système
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="set-env.variable.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
VAR_NAME=""
VAR_VALUE=""
SCOPE=${SCOPE:-"user"}
PERSISTENT=${PERSISTENT:-1}
EXPORT_VAR=${EXPORT_VAR:-1}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <variable_name> <value>

Description:
    Configure des variables d'environnement avec persistance
    au niveau utilisateur ou système.

Arguments:
    <variable_name>  Nom de la variable d'environnement
    <value>          Valeur à assigner

Options:
    -h, --help       Afficher cette aide
    -v, --verbose    Mode verbeux
    -d, --debug      Mode debug
    -q, --quiet      Mode silencieux
    -j, --json-only  Sortie JSON uniquement
    -s, --scope SCOPE Portée (user|system|session)
    --no-persist     Ne pas rendre persistant
    --no-export      Ne pas exporter dans l'environnement actuel
    
Exemples:
    $SCRIPT_NAME PATH "/usr/local/bin:\$PATH"
    $SCRIPT_NAME -s system JAVA_HOME "/usr/lib/jvm/java-11"
    $SCRIPT_NAME --no-persist TEMP_VAR "temporary_value"
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
            -s|--scope) SCOPE="$2"; shift 2 ;;
            --no-persist) PERSISTENT=0; shift ;;
            --no-export) EXPORT_VAR=0; shift ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                if [[ -z "$VAR_NAME" ]]; then
                    VAR_NAME="$1"
                elif [[ -z "$VAR_VALUE" ]]; then
                    VAR_VALUE="$1"
                else
                    echo "Trop d'arguments" >&2; exit 2
                fi
                shift ;;
        esac
    done

    [[ -z "$VAR_NAME" ]] && { echo "Nom de variable manquant" >&2; exit 2; }
    [[ -z "$VAR_VALUE" ]] && { echo "Valeur manquante" >&2; exit 2; }
}

validate_variable_name() {
    local name="$1"
    [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]
}

validate_scope() {
    local scope="$1"
    case "$scope" in
        user|system|session) return 0 ;;
        *) return 1 ;;
    esac
}

get_profile_file() {
    local scope="$1"
    
    case "$scope" in
        user)
            if [[ -f "$HOME/.bashrc" ]]; then
                echo "$HOME/.bashrc"
            elif [[ -f "$HOME/.profile" ]]; then
                echo "$HOME/.profile"
            else
                echo "$HOME/.bashrc"  # Créer .bashrc par défaut
            fi
            ;;
        system)
            if [[ -w /etc/environment ]]; then
                echo "/etc/environment"
            elif [[ -w /etc/profile.d/ ]]; then
                echo "/etc/profile.d/custom-vars.sh"
            else
                echo "/etc/profile"
            fi
            ;;
        session)
            echo "session"  # Pas de fichier, juste export temporaire
            ;;
    esac
}

get_current_value() {
    local name="$1"
    echo "${!name:-}"
}

export_variable() {
    local name="$1" value="$2"
    export "$name=$value"
}

add_to_bashrc() {
    local file="$1" name="$2" value="$3"
    local line="export $name=\"$value\""
    
    # Créer le fichier s'il n'existe pas
    [[ ! -f "$file" ]] && touch "$file"
    
    # Supprimer l'ancienne définition
    sed -i "/^export $name=/d" "$file"
    
    # Ajouter la nouvelle définition
    echo "$line" >> "$file"
}

add_to_environment() {
    local file="$1" name="$2" value="$3"
    
    # Format pour /etc/environment
    local line="$name=\"$value\""
    
    # Créer le fichier s'il n'existe pas
    [[ ! -f "$file" ]] && touch "$file"
    
    # Supprimer l'ancienne définition
    sed -i "/^$name=/d" "$file"
    
    # Ajouter la nouvelle définition
    echo "$line" >> "$file"
}

add_to_profile_d() {
    local file="$1" name="$2" value="$3"
    local line="export $name=\"$value\""
    
    # Créer le répertoire s'il n'existe pas
    mkdir -p "$(dirname "$file")"
    
    # Créer ou mettre à jour le fichier
    if [[ -f "$file" ]]; then
        sed -i "/^export $name=/d" "$file"
    else
        cat > "$file" << 'EOF'
#!/bin/bash
# Custom environment variables
EOF
    fi
    
    echo "$line" >> "$file"
    chmod +x "$file"
}

check_special_variables() {
    local name="$1"
    local special_vars=("PATH" "LD_LIBRARY_PATH" "PYTHONPATH" "CLASSPATH")
    
    for special in "${special_vars[@]}"; do
        [[ "$name" == "$special" ]] && return 0
    done
    return 1
}

main() {
    parse_args "$@"
    
    local errors=() warnings=()
    
    # Valider le nom de variable
    if ! validate_variable_name "$VAR_NAME"; then
        errors+=("Invalid variable name: $VAR_NAME")
    fi
    
    # Valider la portée
    if ! validate_scope "$SCOPE"; then
        errors+=("Invalid scope: $SCOPE")
    fi
    
    # Vérifier les permissions pour système
    if [[ "$SCOPE" == "system" ]] && [[ $EUID -ne 0 ]]; then
        errors+=("Root privileges required for system-wide environment variables")
    fi
    
    # Vérifier les variables spéciales
    if check_special_variables "$VAR_NAME"; then
        warnings+=("Modifying special variable $VAR_NAME - ensure value is correct")
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        local start_time end_time duration profile_file=""
        local previous_value current_value
        
        start_time=$(date +%s)
        previous_value=$(get_current_value "$VAR_NAME")
        
        # Exporter dans l'environnement actuel
        if [[ $EXPORT_VAR -eq 1 ]]; then
            export_variable "$VAR_NAME" "$VAR_VALUE"
        fi
        
        # Rendre persistant si demandé
        local persistence_method=""
        if [[ $PERSISTENT -eq 1 ]] && [[ "$SCOPE" != "session" ]]; then
            profile_file=$(get_profile_file "$SCOPE")
            
            case "$profile_file" in
                /etc/environment)
                    add_to_environment "$profile_file" "$VAR_NAME" "$VAR_VALUE"
                    persistence_method="environment"
                    ;;
                /etc/profile.d/*)
                    add_to_profile_d "$profile_file" "$VAR_NAME" "$VAR_VALUE"
                    persistence_method="profile.d"
                    ;;
                *)
                    add_to_bashrc "$profile_file" "$VAR_NAME" "$VAR_VALUE"
                    persistence_method="profile"
                    ;;
            esac
        else
            persistence_method="session_only"
        fi
        
        current_value=$(get_current_value "$VAR_NAME")
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        # Vérifier que la variable a été définie
        local set_successfully="true"
        if [[ $EXPORT_VAR -eq 1 ]] && [[ "$current_value" != "$VAR_VALUE" ]]; then
            set_successfully="false"
            warnings+=("Variable may not have been set correctly in current session")
        fi
        
        cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Environment variable configured successfully",
  "data": {
    "variable_name": "$VAR_NAME",
    "new_value": "$VAR_VALUE",
    "previous_value": "$previous_value",
    "current_value": "$current_value",
    "scope": "$SCOPE",
    "set_successfully": $set_successfully,
    "exported_to_session": $([ $EXPORT_VAR -eq 1 ] && echo "true" || echo "false"),
    "made_persistent": $([ $PERSISTENT -eq 1 ] && [ "$SCOPE" != "session" ] && echo "true" || echo "false"),
    "persistence_method": "$persistence_method",
    "profile_file": "$profile_file",
    "duration_seconds": $duration,
    "special_variable": $(check_special_variables "$VAR_NAME" && echo "true" || echo "false")
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
  "message": "Environment variable configuration failed",
  "data": {},
  "errors": [$(printf '"%s",' "${errors[@]}" | sed 's/,$//')],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi