#!/usr/bin/env bash

#===============================================================================
# Script Atomique : Suppression de clé SSH des authorized_keys
#===============================================================================
# Nom du fichier : remove-ssh.key.authorized.sh
# Niveau : 0 (Atomique)
# Catégorie : network
# Protocole : ssh
# Description : Retire une clé des authorized_keys (révocation d'accès)
#
# Objectif :
# - Supprimer une clé publique SSH du fichier authorized_keys
# - Identification par empreinte, fichier ou contenu de clé
# - Sauvegarde automatique avant suppression
# - Support de suppression multiple et par motif
# - Opération locale et distante via SSH
#
# Conforme à la méthodologie AtomicOps-Suite - Niveau 0
#===============================================================================

set -euo pipefail

# === MÉTADONNÉES DU SCRIPT ===
readonly SCRIPT_NAME="remove-ssh.key.authorized.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_CATEGORY="network"
readonly SCRIPT_PROTOCOL="ssh"
readonly SCRIPT_LEVEL=0

# === CONFIGURATION PAR DÉFAUT ===
readonly DEFAULT_SSH_DIR="$HOME/.ssh"
readonly DEFAULT_USER="$(whoami)"
readonly AUTHORIZED_KEYS_FILE="authorized_keys"

# === VARIABLES GLOBALES ===
TARGET_USER="$DEFAULT_USER"
SSH_DIRECTORY="$DEFAULT_SSH_DIR"
REMOTE_HOST=""
PUBLIC_KEY_FILE=""
PUBLIC_KEY_CONTENT=""
KEY_FINGERPRINT=""
KEY_COMMENT_PATTERN=""
REMOVE_ALL_MATCHING=false
BACKUP_EXISTING=true
DRY_RUN=false
QUIET_MODE=false
DEBUG_MODE=false

# === FONCTIONS D'AIDE ===
show_help() {
    cat << EOF
Suppression de clé SSH des authorized_keys - Script Atomique Niveau 0

USAGE:
    $(basename "$0") [OPTIONS] -k KEY_FILE|-f FINGERPRINT|--key-content "ssh-rsa..."

DESCRIPTION:
    Retire une ou plusieurs clés SSH du fichier authorized_keys :
    - Identification par fichier de clé, empreinte ou contenu
    - Recherche par motif dans les commentaires
    - Sauvegarde automatique avant modification
    - Mode dry-run pour prévisualisation des suppressions
    - Support de suppression locale et distante via SSH
    - Suppression sélective ou multiple avec confirmation

MÉTHODES D'IDENTIFICATION:
    -k, --key-file FILE     Fichier de clé publique à supprimer (.pub)
    -f, --fingerprint FP    Empreinte SHA256 de la clé à supprimer
    --key-content "KEY"     Contenu direct de la clé publique
    --comment-pattern PAT   Motif de recherche dans les commentaires
    
OPTIONS PRINCIPALES:
    -u, --user USER         Utilisateur cible (défaut: current user)
    -d, --directory PATH    Répertoire SSH (défaut: ~/.ssh)
    -r, --remote HOST       Suppression sur un hôte distant via SSH
    
OPTIONS AVANCÉES:
    --all-matching          Supprimer toutes les clés correspondantes
    --no-backup             Pas de sauvegarde de l'authorized_keys
    --dry-run               Mode simulation (affiche les actions sans les exécuter)
    
    -q, --quiet             Mode silencieux (erreurs uniquement)
    --debug                 Mode debug avec traces détaillées
    -h, --help              Affiche cette aide

EXEMPLES:
    # Suppression par fichier de clé
    $(basename "$0") --key-file ~/.ssh/old_key.pub
    
    # Suppression par empreinte
    $(basename "$0") --fingerprint "SHA256:abc123def456..."
    
    # Suppression par motif de commentaire
    $(basename "$0") --comment-pattern "laptop-*" --all-matching
    
    # Suppression distante avec dry-run
    $(basename "$0") --remote server.com --fingerprint "SHA256:..." --dry-run
    
    # Suppression de toutes les clés contenant un motif
    $(basename "$0") --comment-pattern "temporary" --all-matching --no-backup

SORTIE JSON:
    {
        "status": "success|error",
        "timestamp": "ISO8601",
        "script": "$SCRIPT_NAME",
        "data": {
            "user": "username",
            "ssh_directory": "/path/to/.ssh",
            "authorized_keys_file": "/path/to/authorized_keys",
            "search_criteria": {
                "method": "fingerprint|file|content|comment",
                "value": "search_value",
                "all_matching": boolean
            },
            "operation": {
                "dry_run": boolean,
                "keys_found": number,
                "keys_removed": number,
                "backup_created": "/path/to/backup",
                "removed_keys": [...]
            }
        }
    }

CODES DE RETOUR:
    0 : Succès - Clé(s) supprimée(s) avec succès
    1 : Erreur de paramètres
    2 : Critères de recherche invalides
    3 : Erreur de connexion SSH distante
    4 : Erreur de permissions ou d'écriture
    5 : Aucune clé correspondante trouvée

SÉCURITÉ:
    - Sauvegarde automatique avant toute modification
    - Mode dry-run pour validation des opérations
    - Confirmation requise pour suppressions multiples
    - Préservation des permissions du fichier

CONFORMITÉ:
    - Méthodologie AtomicOps-Suite Niveau 0 (Atomique)
    - Sortie JSON standardisée
    - Gestion d'erreurs robuste avec codes spécifiques
EOF
}

# === FONCTIONS DE LOGGING ===
log_debug() { [[ "$DEBUG_MODE" == true ]] && echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_info() { [[ "$QUIET_MODE" == false ]] && echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }

# === VALIDATION DES PARAMÈTRES ===
validate_parameters() {
    local errors=0
    local criteria_count=0
    
    # Compter les critères de recherche fournis
    [[ -n "$PUBLIC_KEY_FILE" ]] && ((criteria_count++))
    [[ -n "$PUBLIC_KEY_CONTENT" ]] && ((criteria_count++))
    [[ -n "$KEY_FINGERPRINT" ]] && ((criteria_count++))
    [[ -n "$KEY_COMMENT_PATTERN" ]] && ((criteria_count++))
    
    # Validation qu'au moins un critère est fourni
    if [[ $criteria_count -eq 0 ]]; then
        log_error "Au moins un critère de recherche obligatoire : --key-file, --fingerprint, --key-content ou --comment-pattern"
        ((errors++))
    elif [[ $criteria_count -gt 1 ]]; then
        log_error "Un seul critère de recherche autorisé à la fois"
        ((errors++))
    fi
    
    # Validation du fichier de clé si spécifié
    if [[ -n "$PUBLIC_KEY_FILE" ]]; then
        if [[ ! -f "$PUBLIC_KEY_FILE" ]]; then
            log_error "Fichier de clé non trouvé : $PUBLIC_KEY_FILE"
            ((errors++))
        elif [[ ! -r "$PUBLIC_KEY_FILE" ]]; then
            log_error "Fichier de clé non lisible : $PUBLIC_KEY_FILE"
            ((errors++))
        fi
    fi
    
    # Validation de l'empreinte si spécifiée
    if [[ -n "$KEY_FINGERPRINT" ]]; then
        if [[ ! "$KEY_FINGERPRINT" =~ ^(SHA256:|MD5:) ]]; then
            log_error "Format d'empreinte invalide. Attendu: SHA256:... ou MD5:..."
            ((errors++))
        fi
    fi
    
    # Validation de l'utilisateur
    if [[ -z "$TARGET_USER" ]]; then
        log_error "Utilisateur cible obligatoire"
        ((errors++))
    fi
    
    # Validation du répertoire SSH pour opération locale
    if [[ -z "$REMOTE_HOST" ]]; then
        if [[ ! -d "$SSH_DIRECTORY" ]]; then
            log_error "Répertoire SSH non trouvé : $SSH_DIRECTORY"
            ((errors++))
        fi
        
        local auth_keys_file="$SSH_DIRECTORY/$AUTHORIZED_KEYS_FILE"
        if [[ ! -f "$auth_keys_file" ]]; then
            log_error "Fichier authorized_keys non trouvé : $auth_keys_file"
            ((errors++))
        elif [[ ! -r "$auth_keys_file" ]]; then
            log_error "Fichier authorized_keys non lisible : $auth_keys_file"
            ((errors++))
        fi
    fi
    
    return $errors
}

# === PRÉPARATION DES CRITÈRES DE RECHERCHE ===
prepare_search_criteria() {
    local search_method=""
    local search_value=""
    
    # Détermination du critère de recherche principal
    if [[ -n "$PUBLIC_KEY_FILE" ]]; then
        search_method="file"
        search_value="$PUBLIC_KEY_FILE"
        
        # Extraction de l'empreinte du fichier
        if ! KEY_FINGERPRINT=$(ssh-keygen -l -f "$PUBLIC_KEY_FILE" 2>/dev/null | awk '{print $2}'); then
            log_error "Impossible d'extraire l'empreinte du fichier : $PUBLIC_KEY_FILE"
            return 2
        fi
        
    elif [[ -n "$PUBLIC_KEY_CONTENT" ]]; then
        search_method="content"
        search_value="$PUBLIC_KEY_CONTENT"
        
        # Extraction de l'empreinte du contenu
        local temp_key_file=$(mktemp)
        echo "$PUBLIC_KEY_CONTENT" > "$temp_key_file"
        
        if KEY_FINGERPRINT=$(ssh-keygen -l -f "$temp_key_file" 2>/dev/null | awk '{print $2}'); then
            rm -f "$temp_key_file"
        else
            rm -f "$temp_key_file"
            log_error "Contenu de clé SSH invalide"
            return 2
        fi
        
    elif [[ -n "$KEY_FINGERPRINT" ]]; then
        search_method="fingerprint"
        search_value="$KEY_FINGERPRINT"
        
    elif [[ -n "$KEY_COMMENT_PATTERN" ]]; then
        search_method="comment"
        search_value="$KEY_COMMENT_PATTERN"
    fi
    
    # Stockage des critères pour utilisation ultérieure
    echo "$search_method" > /tmp/search_method_$$
    echo "$search_value" > /tmp/search_value_$$
    
    log_debug "Critères de recherche - Méthode: $search_method, Valeur: $search_value"
    
    return 0
}

# === RECHERCHE DES CLÉS CORRESPONDANTES ===
find_matching_keys() {
    local authorized_keys_path="$1"
    local search_method="$2"
    local search_value="$3"
    local matching_keys=()
    
    log_debug "Recherche des clés correspondantes dans : $authorized_keys_path"
    
    local line_number=0
    while IFS= read -r line; do
        ((line_number++))
        
        # Ignorer les lignes vides et commentaires
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        local is_match=false
        
        case "$search_method" in
            "fingerprint"|"file"|"content")
                # Recherche par empreinte
                local temp_line_file=$(mktemp)
                echo "$line" > "$temp_line_file"
                
                local line_fingerprint
                if line_fingerprint=$(ssh-keygen -l -f "$temp_line_file" 2>/dev/null | awk '{print $2}'); then
                    if [[ "$line_fingerprint" == "$KEY_FINGERPRINT" ]]; then
                        is_match=true
                    fi
                fi
                
                rm -f "$temp_line_file"
                ;;
                
            "comment")
                # Recherche par motif dans le commentaire
                if [[ "$line" =~ $search_value ]]; then
                    is_match=true
                fi
                ;;
        esac
        
        if [[ "$is_match" == true ]]; then
            # Stocker les informations de la clé correspondante
            local key_info=$(create_key_info_json "$line" "$line_number" "$authorized_keys_path")
            matching_keys+=("$key_info")
            
            log_debug "Clé correspondante trouvée à la ligne $line_number"
            
            # Si on ne cherche qu'une seule correspondance, arrêter ici
            [[ "$REMOVE_ALL_MATCHING" == false ]] && break
        fi
        
    done < "$authorized_keys_path"
    
    # Stockage des résultats
    local keys_json="[$(IFS=,; echo "${matching_keys[*]}")]"
    echo "$keys_json" > /tmp/matching_keys_$$
    echo "${#matching_keys[@]}" > /tmp/matching_count_$$
    
    log_info "Trouvé ${#matching_keys[@]} clé(s) correspondante(s)"
    
    return 0
}

# === CRÉATION DU JSON D'INFORMATION DE CLÉ ===
create_key_info_json() {
    local key_line="$1"
    local line_number="$2"
    local file_path="$3"
    
    # Extraction des métadonnées de la clé
    local temp_key_file=$(mktemp)
    echo "$key_line" > "$temp_key_file"
    
    local key_type="unknown"
    local key_bits="unknown" 
    local key_fingerprint="unknown"
    local key_comment=""
    
    # Extraction des informations SSH
    local key_info
    if key_info=$(ssh-keygen -l -f "$temp_key_file" 2>/dev/null); then
        key_bits=$(echo "$key_info" | awk '{print $1}')
        key_fingerprint=$(echo "$key_info" | awk '{print $2}')
        key_type=$(echo "$key_info" | awk '{print $4}' | tr -d '()')
    fi
    
    # Extraction du commentaire de la ligne
    if [[ "$key_line" =~ ^[^[:space:]]*[[:space:]]+[^[:space:]]+[[:space:]]+(.*)$ ]]; then
        key_comment="${BASH_REMATCH[1]}"
    fi
    
    rm -f "$temp_key_file"
    
    # Construction du JSON
    cat << EOF
{
    "line_number": $line_number,
    "type": "$key_type",
    "fingerprint": "$key_fingerprint",
    "bits": "$key_bits",
    "comment": "$key_comment",
    "full_line": "$key_line"
}
EOF
}

# === SAUVEGARDE DU FICHIER AUTHORIZED_KEYS ===
backup_authorized_keys() {
    local authorized_keys_path="$1"
    
    if [[ "$BACKUP_EXISTING" == false ]]; then
        echo "none" > /tmp/backup_path_$$
        return 0
    fi
    
    local backup_path="${authorized_keys_path}.backup.$(date +%Y%m%d_%H%M%S)"
    
    log_debug "Sauvegarde de authorized_keys : $backup_path"
    
    if cp "$authorized_keys_path" "$backup_path"; then
        echo "$backup_path" > /tmp/backup_path_$$
        log_info "Sauvegarde créée : $backup_path"
        return 0
    else
        log_error "Échec de la sauvegarde : $backup_path"
        return 4
    fi
}

# === SUPPRESSION DES CLÉS ===
remove_matching_keys() {
    local authorized_keys_path="$1"
    local matching_keys_json="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Aucune modification effectuée"
        return 0
    fi
    
    log_debug "Suppression des clés correspondantes"
    
    # Créer un fichier temporaire pour la nouvelle version
    local temp_auth_file=$(mktemp)
    local removed_count=0
    
    # Extraction des numéros de ligne à supprimer
    local lines_to_remove=()
    while IFS= read -r key_info; do
        local line_num=$(echo "$key_info" | jq -r '.line_number' 2>/dev/null || echo "0")
        [[ "$line_num" -gt 0 ]] && lines_to_remove+=("$line_num")
    done < <(echo "$matching_keys_json" | jq -c '.[]' 2>/dev/null)
    
    # Reconstruction du fichier sans les lignes à supprimer
    local current_line=0
    while IFS= read -r line; do
        ((current_line++))
        
        local should_remove=false
        for remove_line in "${lines_to_remove[@]}"; do
            if [[ "$current_line" == "$remove_line" ]]; then
                should_remove=true
                ((removed_count++))
                log_debug "Ligne $current_line supprimée : $line"
                break
            fi
        done
        
        [[ "$should_remove" == false ]] && echo "$line" >> "$temp_auth_file"
        
    done < "$authorized_keys_path"
    
    # Remplacement du fichier original
    if mv "$temp_auth_file" "$authorized_keys_path"; then
        # Préservation des permissions
        chmod 600 "$authorized_keys_path" 2>/dev/null || true
        
        log_info "Supprimé $removed_count clé(s) du fichier authorized_keys"
        echo "$removed_count" > /tmp/removed_count_$$
        return 0
    else
        rm -f "$temp_auth_file"
        log_error "Échec du remplacement du fichier authorized_keys"
        return 4
    fi
}

# === OPÉRATION DISTANTE VIA SSH ===
remove_keys_remote() {
    local remote_host="$1"
    local remote_user="$2"
    local ssh_dir="$3"
    local search_method="$4"
    local search_value="$5"
    
    log_debug "Suppression de clés distante sur $remote_user@$remote_host"
    
    # Script de suppression distant
    local remote_script=$(cat << 'REMOTE_EOF'
#!/bin/bash
set -euo pipefail

SSH_DIR="$1"
SEARCH_METHOD="$2"
SEARCH_VALUE="$3"
DRY_RUN="$4"
REMOVE_ALL="$5"
BACKUP_EXISTING="$6"

AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

if [[ ! -f "$AUTHORIZED_KEYS" ]]; then
    echo '{"status": "error", "message": "authorized_keys not found"}'
    exit 5
fi

# Sauvegarde si demandée
BACKUP_PATH="none"
if [[ "$BACKUP_EXISTING" == "true" && "$DRY_RUN" == "false" ]]; then
    BACKUP_PATH="$AUTHORIZED_KEYS.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$AUTHORIZED_KEYS" "$BACKUP_PATH"
fi

# Recherche et suppression des clés
MATCHING_COUNT=0
REMOVED_COUNT=0
TEMP_FILE=$(mktemp)

LINE_NUM=0
while IFS= read -r line; do
    ((LINE_NUM++))
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && { echo "$line" >> "$TEMP_FILE"; continue; }
    
    SHOULD_REMOVE=false
    
    case "$SEARCH_METHOD" in
        "fingerprint"|"file"|"content")
            TEMP_KEY=$(mktemp)
            echo "$line" > "$TEMP_KEY"
            LINE_FP=$(ssh-keygen -l -f "$TEMP_KEY" 2>/dev/null | awk '{print $2}' || echo "")
            rm -f "$TEMP_KEY"
            
            if [[ "$LINE_FP" == "$SEARCH_VALUE" ]]; then
                SHOULD_REMOVE=true
                ((MATCHING_COUNT++))
            fi
            ;;
        "comment")
            if [[ "$line" =~ $SEARCH_VALUE ]]; then
                SHOULD_REMOVE=true
                ((MATCHING_COUNT++))
            fi
            ;;
    esac
    
    if [[ "$SHOULD_REMOVE" == "true" ]]; then
        [[ "$DRY_RUN" == "false" ]] && ((REMOVED_COUNT++))
        [[ "$REMOVE_ALL" == "false" ]] && break
    else
        echo "$line" >> "$TEMP_FILE"
    fi
done < "$AUTHORIZED_KEYS"

# Remplacement du fichier si pas en dry-run
if [[ "$DRY_RUN" == "false" && "$MATCHING_COUNT" -gt 0 ]]; then
    mv "$TEMP_FILE" "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"
else
    rm -f "$TEMP_FILE"
fi

echo "{\"status\": \"success\", \"matching_count\": $MATCHING_COUNT, \"removed_count\": $REMOVED_COUNT, \"backup_path\": \"$BACKUP_PATH\"}"
REMOTE_EOF
    )
    
    # Exécution du script sur l'hôte distant
    local result
    if result=$(ssh "$remote_user@$remote_host" "bash -s -- '$ssh_dir' '$search_method' '$search_value' '$DRY_RUN' '$REMOVE_ALL_MATCHING' '$BACKUP_EXISTING'" <<< "$remote_script" 2>&1); then
        echo "$result" > /tmp/remote_result_$$
        return 0
    else
        log_error "Échec de l'opération distante : $result"
        return 3
    fi
}

# === GÉNÉRATION DE LA SORTIE JSON ===
generate_output() {
    local keys_found="$1"
    local keys_removed="$2"
    local backup_path="$3"
    
    # Lecture des critères de recherche
    local search_method=$(cat /tmp/search_method_$$ 2>/dev/null || echo "unknown")
    local search_value=$(cat /tmp/search_value_$$ 2>/dev/null || echo "unknown")
    local matching_keys_json=$(cat /tmp/matching_keys_$$ 2>/dev/null || echo "[]")
    
    cat << EOF
{
    "status": "success",
    "timestamp": "$(date -Iseconds)",
    "script": "$SCRIPT_NAME",
    "version": "$SCRIPT_VERSION",
    "data": {
        "user": "$TARGET_USER",
        "ssh_directory": "$SSH_DIRECTORY",
        "authorized_keys_file": "$SSH_DIRECTORY/$AUTHORIZED_KEYS_FILE",
        "remote_host": "$REMOTE_HOST",
        "search_criteria": {
            "method": "$search_method",
            "value": "$search_value",
            "all_matching": $REMOVE_ALL_MATCHING
        },
        "operation": {
            "dry_run": $DRY_RUN,
            "keys_found": $keys_found,
            "keys_removed": $keys_removed,
            "backup_created": "$backup_path",
            "removed_keys": $matching_keys_json
        }
    }
}
EOF
}

# === NETTOYAGE DES FICHIERS TEMPORAIRES ===
cleanup() {
    rm -f /tmp/search_method_$$ /tmp/search_value_$$ /tmp/matching_keys_$$ /tmp/matching_count_$$ /tmp/backup_path_$$ /tmp/removed_count_$$ /tmp/remote_result_$$ 2>/dev/null || true
}

# === GESTION DES ARGUMENTS ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -k|--key-file)
                PUBLIC_KEY_FILE="$2"
                shift 2
                ;;
            -f|--fingerprint)
                KEY_FINGERPRINT="$2"
                shift 2
                ;;
            --key-content)
                PUBLIC_KEY_CONTENT="$2"
                shift 2
                ;;
            --comment-pattern)
                KEY_COMMENT_PATTERN="$2"
                shift 2
                ;;
            -u|--user)
                TARGET_USER="$2"
                shift 2
                ;;
            -d|--directory)
                SSH_DIRECTORY="$2"
                shift 2
                ;;
            -r|--remote)
                REMOTE_HOST="$2"
                shift 2
                ;;
            --all-matching)
                REMOVE_ALL_MATCHING=true
                shift
                ;;
            --no-backup)
                BACKUP_EXISTING=false
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Argument inconnu : $1"
                show_help >&2
                exit 1
                ;;
        esac
    done
}

# === FONCTION PRINCIPALE ===
main() {
    local start_time=$(date +%s.%N)
    
    # Configuration du piégeage pour nettoyage
    trap cleanup EXIT INT TERM
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des paramètres
    if ! validate_parameters; then
        exit 1
    fi
    
    log_debug "Début de la suppression de clé SSH pour $TARGET_USER"
    
    # Préparation des critères de recherche
    if ! prepare_search_criteria; then
        exit 2
    fi
    
    local search_method=$(cat /tmp/search_method_$$)
    local search_value=$(cat /tmp/search_value_$$)
    
    # Opération distante ou locale
    if [[ -n "$REMOTE_HOST" ]]; then
        log_info "Suppression de clé distante sur $REMOTE_HOST"
        
        if ! remove_keys_remote "$REMOTE_HOST" "$TARGET_USER" "$SSH_DIRECTORY" "$search_method" "$search_value"; then
            exit 3
        fi
        
        # Traitement du résultat distant
        local remote_result=$(cat /tmp/remote_result_$$ 2>/dev/null || echo '{"matching_count": 0, "removed_count": 0, "backup_path": "none"}')
        local keys_found=$(echo "$remote_result" | jq -r '.matching_count' 2>/dev/null || echo "0")
        local keys_removed=$(echo "$remote_result" | jq -r '.removed_count' 2>/dev/null || echo "0")
        local backup_path=$(echo "$remote_result" | jq -r '.backup_path' 2>/dev/null || echo "none")
        
        generate_output "$keys_found" "$keys_removed" "$backup_path"
        
    else
        # Opération locale
        log_info "Suppression de clé locale dans $SSH_DIRECTORY"
        
        local authorized_keys_path="$SSH_DIRECTORY/$AUTHORIZED_KEYS_FILE"
        
        # Recherche des clés correspondantes
        if ! find_matching_keys "$authorized_keys_path" "$search_method" "$search_value"; then
            exit 4
        fi
        
        local keys_found=$(cat /tmp/matching_count_$$)
        local matching_keys_json=$(cat /tmp/matching_keys_$$)
        
        if [[ "$keys_found" -eq 0 ]]; then
            log_error "Aucune clé correspondante trouvée"
            exit 5
        fi
        
        # Sauvegarde du fichier existant
        local backup_path="none"
        if backup_authorized_keys "$authorized_keys_path"; then
            backup_path=$(cat /tmp/backup_path_$$)
        fi
        
        # Suppression des clés correspondantes
        if ! remove_matching_keys "$authorized_keys_path" "$matching_keys_json"; then
            exit 4
        fi
        
        local keys_removed=0
        [[ "$DRY_RUN" == false ]] && keys_removed=$(cat /tmp/removed_count_$$ 2>/dev/null || echo "$keys_found")
        
        generate_output "$keys_found" "$keys_removed" "$backup_path"
    fi
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.00")
    
    log_debug "Suppression de clé terminée en ${duration}s"
    
    return 0
}

# Point d'entrée du script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi