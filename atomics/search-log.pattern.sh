#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: search-log.pattern.sh 
# Description: Rechercher des patterns dans les logs système
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="search-log.pattern.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
PATTERN=""
LOG_FILES=()
CONTEXT_LINES=${CONTEXT_LINES:-3}
MAX_RESULTS=${MAX_RESULTS:-100}
CASE_SENSITIVE=${CASE_SENSITIVE:-0}
USE_REGEX=${USE_REGEX:-0}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <pattern> [log_files...]

Description:
    Recherche des patterns dans les fichiers de logs système
    avec contexte et analyse statistique des résultats.

Arguments:
    <pattern>       Pattern à rechercher
    [log_files...]  Fichiers de log (défaut: logs système)

Options:
    -h, --help       Afficher cette aide
    -v, --verbose    Mode verbeux
    -d, --debug      Mode debug
    -q, --quiet      Mode silencieux
    -j, --json-only  Sortie JSON uniquement
    -c, --context N  Lignes de contexte (défaut: 3)
    -m, --max N      Résultats maximum (défaut: 100)
    -i, --ignore-case Ignorer la casse
    -r, --regex      Utiliser regex
    
Exemples:
    $SCRIPT_NAME "error" /var/log/syslog
    $SCRIPT_NAME -i -c 5 "failed login"
    $SCRIPT_NAME -r "ERROR.*database" /var/log/myapp.log
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
            -c|--context) CONTEXT_LINES="$2"; shift 2 ;;
            -m|--max) MAX_RESULTS="$2"; shift 2 ;;
            -i|--ignore-case) CASE_SENSITIVE=0; shift ;;
            -r|--regex) USE_REGEX=1; shift ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                if [[ -z "$PATTERN" ]]; then
                    PATTERN="$1"
                else
                    LOG_FILES+=("$1")
                fi
                shift ;;
        esac
    done

    [[ -z "$PATTERN" ]] && { echo "Pattern manquant" >&2; exit 2; }
    
    # Fichiers par défaut si aucun spécifié
    if [[ ${#LOG_FILES[@]} -eq 0 ]]; then
        LOG_FILES=("/var/log/syslog" "/var/log/messages" "/var/log/auth.log")
    fi
}

search_in_file() {
    local pattern="$1" file="$2"
    local grep_opts="-n"
    
    [[ $CASE_SENSITIVE -eq 0 ]] && grep_opts+="i"
    [[ $USE_REGEX -eq 1 ]] && grep_opts+="E" || grep_opts+="F"
    [[ $CONTEXT_LINES -gt 0 ]] && grep_opts+="-C$CONTEXT_LINES"
    
    grep $grep_opts "$pattern" "$file" 2>/dev/null || true
}

analyze_matches() {
    local file="$1" matches="$2"
    local total_matches line_numbers=() timestamps=()
    
    total_matches=$(echo "$matches" | grep -c "^[0-9]" || echo "0")
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^([0-9]+): ]]; then
            line_numbers+=("${BASH_REMATCH[1]}")
            
            # Extraire timestamp si présent
            if [[ "$line" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]+[0-9]{2}:[0-9]{2}:[0-9]{2}) ]]; then
                timestamps+=("${BASH_REMATCH[1]}")
            fi
        fi
    done <<< "$matches"
    
    echo "$total_matches:$(IFS=','; echo "${line_numbers[*]}"):$(IFS=','; echo "${timestamps[*]}")"
}

main() {
    parse_args "$@"
    
    local errors=() warnings=() results=()
    local total_matches=0 files_searched=0
    
    for log_file in "${LOG_FILES[@]}"; do
        if [[ -f "$log_file" && -r "$log_file" ]]; then
            local matches analysis
            matches=$(search_in_file "$PATTERN" "$log_file")
            
            if [[ -n "$matches" ]]; then
                analysis=$(analyze_matches "$log_file" "$matches")
                IFS=':' read -r count lines times <<< "$analysis"
                
                total_matches=$((total_matches + count))
                
                # Limiter les résultats affichés
                local displayed_matches
                displayed_matches=$(echo "$matches" | head -n "$MAX_RESULTS")
                
                results+=("{\"file\":\"$log_file\",\"matches\":$count,\"lines\":\"$lines\",\"timestamps\":\"$times\",\"sample_matches\":\"$(echo "$displayed_matches" | sed 's/"/\\"/g' | tr '\n' '|')\"}")
            else
                results+=("{\"file\":\"$log_file\",\"matches\":0,\"lines\":\"\",\"timestamps\":\"\",\"sample_matches\":\"\"}")
            fi
            
            files_searched=$((files_searched + 1))
        else
            if [[ ! -f "$log_file" ]]; then
                warnings+=("Log file not found: $log_file")
            elif [[ ! -r "$log_file" ]]; then
                warnings+=("Log file not readable: $log_file")
            fi
        fi
    done
    
    if [[ $files_searched -eq 0 ]]; then
        errors+=("No log files could be searched")
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Log pattern search completed",
  "data": {
    "pattern": "$PATTERN",
    "search_options": {
      "case_sensitive": $([ $CASE_SENSITIVE -eq 1 ] && echo "true" || echo "false"),
      "regex_mode": $([ $USE_REGEX -eq 1 ] && echo "true" || echo "false"),
      "context_lines": $CONTEXT_LINES,
      "max_results": $MAX_RESULTS
    },
    "summary": {
      "total_matches": $total_matches,
      "files_searched": $files_searched,
      "files_with_matches": $(echo "[$(IFS=','; echo "${results[*]}")]" | jq '[.[] | select(.matches > 0)] | length' 2>/dev/null || echo "0")
    },
    "results": [$(IFS=','; echo "${results[*]}")]
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
  "message": "Log pattern search failed",
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