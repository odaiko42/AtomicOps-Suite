#!/usr/bin/env bash

#===============================================================================
# Script Atomique : Ajout de clé SSH aux authorized_keys
#===============================================================================
# Nom du fichier : add-ssh.key.authorized.sh
# Niveau : 0 (Atomique)
# Catégorie : network
# Protocole : ssh
# Description : Ajoute une clé publique aux authorized_keys pour autoriser une connexion
#
# Objectif :
# - Ajouter une clé publique SSH au fichier authorized_keys d'un utilisateur
# - Valider le format de la clé avant ajout
# - Éviter les doublons (détection de clés existantes)
# - Gérer les permissions et la sécurité du fichier
# - Support local et distant via SSH
#
# Conforme à la méthodologie AtomicOps-Suite - Niveau 0
#===============================================================================

set -euo pipefail

# === MÉTADONNÉES DU SCRIPT ===
readonly SCRIPT_NAME="add-ssh.key.authorized.sh"
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
KEY_COMMENT=""
CHECK_DUPLICATES=true
BACKUP_EXISTING=true
SET_PERMISSIONS=true
FORCE_ADD=false
QUIET_MODE=false
DEBUG_MODE=false

# === FONCTIONS D'AIDE ===
show_help() {
    cat << EOF
Ajout de clé SSH aux authorized_keys - Script Atomique Niveau 0

USAGE:
    $(basename "$0") [OPTIONS] -k KEY_FILE|--key-content "ssh-rsa AAAAB3..."

DESCRIPTION:
    Ajoute une clé publique SSH au fichier authorized_keys d'un utilisateur :
    - Validation complète du format de la clé SSH
    - Détection automatique des doublons
    - Sauvegarde automatique de l'authorized_keys existant
    - Configuration des permissions sécurisées (600)
    - Support d'ajout local et distant via SSH
    - Gestion des commentaires et métadonnées

OPTIONS PRINCIPALES:
    -k, --key-file FILE     Fichier de clé publique à ajouter (.pub)
    --key-content "KEY"     Contenu direct de la clé publique
    -u, --user USER         Utilisateur cible (défaut: current user)
    -d, --directory PATH    Répertoire SSH (défaut: ~/.ssh)
    -r, --remote HOST       Ajout sur un hôte distant via SSH
    
OPTIONS AVANCÉES:
    -c, --comment TEXT      Commentaire à ajouter à la clé
    --no-duplicates-check   Désactive la vérification de doublons
    --no-backup             Pas de sauvegarde de l'authorized_keys
    --no-permissions        Ne pas définir les permissions (600)
    -f, --force             Force l'ajout même si la clé existe
    
    -q, --quiet             Mode silencieux (erreurs uniquement)
    --debug                 Mode debug avec traces détaillées
    -h, --help              Affiche cette aide

EXEMPLES:
    # Ajout depuis un fichier de clé publique
    $(basename "$0") --key-file ~/.ssh/id_rsa.pub
    
    # Ajout avec contenu direct et commentaire
    $(basename "$0") --key-content "ssh-rsa AAAAB3NzaC1yc2E..." --comment "workstation-key"
    
    # Ajout distant sur un serveur
    $(basename "$0") --key-file ~/.ssh/id_rsa.pub --remote server.example.com --user admin
    
    # Ajout forcé sans vérification de doublons
    $(basename "$0") --key-file ~/.ssh/id_rsa.pub --force --no-duplicates-check

SORTIE JSON:
    {
        "status": "success|error",
        "timestamp": "ISO8601",
        "script": "$SCRIPT_NAME",
        "data": {
            "user": "username",
            "ssh_directory": "/path/to/.ssh",
            "authorized_keys_file": "/path/to/authorized_keys",
            "key_info": {
                "type": "ssh-rsa|ssh-ed25519|...",
                "fingerprint": "SHA256:...",
                "bits": number,
                "comment": "comment",
                "source": "file|content"
            },
            "operation": {
                "action": "added|exists|updated",
                "duplicate_found": boolean,
                "backup_created": "/path/to/backup",
                "permissions_set": boolean
            }
        }
    }

CODES DE RETOUR:
    0 : Succès - Clé ajoutée avec succès
    1 : Erreur de paramètres
    2 : Fichier de clé non trouvé ou invalide
    3 : Erreur de connexion SSH distante
    4 : Erreur de permissions ou d'écriture
    5 : Clé déjà présente (sans --force)

SÉCURITÉ:
    - Validation stricte du format de clé SSH
    - Permissions 600 sur authorized_keys
    - Sauvegarde automatique avant modification
    - Vérification de l'intégrité après ajout

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
    
    # Validation de la source de la clé
    if [[ -z "$PUBLIC_KEY_FILE" && -z "$PUBLIC_KEY_CONTENT" ]]; then
        log_error "Clé publique obligatoire : --key-file ou --key-content"
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
    
    # Validation de l'utilisateur
    if [[ -z "$TARGET_USER" ]]; then
        log_error "Utilisateur cible obligatoire"
        ((errors++))
    fi
    
    # Validation du répertoire SSH pour opération locale
    if [[ -z "$REMOTE_HOST" && -n "$SSH_DIRECTORY" ]]; then
        if [[ ! -d "$SSH_DIRECTORY" ]]; then
            log_debug "Répertoire SSH sera créé : $SSH_DIRECTORY"
        fi
    fi
    
    return $errors
}

# === LECTURE ET VALIDATION DE LA CLÉ ===
read_and_validate_key() {
    local key_content=""
    
    # Lecture depuis fichier ou contenu direct
    if [[ -n "$PUBLIC_KEY_FILE" ]]; then
        log_debug "Lecture de la clé depuis : $PUBLIC_KEY_FILE"
        key_content=$(cat "$PUBLIC_KEY_FILE")
        if [[ -z "$key_content" ]]; then
            log_error "Fichier de clé vide : $PUBLIC_KEY_FILE"
            return 2
        fi
    else
        key_content="$PUBLIC_KEY_CONTENT"
    fi
    
    # Validation du format SSH
    if ! echo "$key_content" | ssh-keygen -l -f - >/dev/null 2>&1; then
        log_error "Format de clé SSH invalide"
        return 2
    fi
    
    # Extraction des métadonnées de la clé
    local key_info
    if key_info=$(echo "$key_content" | ssh-keygen -l -f - 2>/dev/null); then
        local key_bits=$(echo "$key_info" | awk '{print $1}')
        local key_fingerprint=$(echo "$key_info" | awk '{print $2}')
        local key_type=$(echo "$key_info" | awk '{print $4}' | tr -d '()')
        
        log_debug "Clé validée - Type: $key_type, Bits: $key_bits, Empreinte: $key_fingerprint"
        
        # Stockage des métadonnées pour la sortie JSON
        echo "$key_content" > /tmp/validated_key_$$
        echo "$key_type" > /tmp/key_type_$$
        echo "$key_bits" > /tmp/key_bits_$$
        echo "$key_fingerprint" > /tmp/key_fingerprint_$$
        
        return 0
    else
        log_error "Impossible d'extraire les métadonnées de la clé"
        return 2
    fi
}

# === PRÉPARATION DU RÉPERTOIRE ET FICHIER ===
prepare_ssh_directory() {
    local ssh_dir="$1"
    local user="$2"
    
    log_debug "Préparation du répertoire SSH : $ssh_dir"
    
    # Création du répertoire .ssh si nécessaire
    if [[ ! -d "$ssh_dir" ]]; then
        log_info "Création du répertoire SSH : $ssh_dir"
        if ! mkdir -p "$ssh_dir"; then
            log_error "Impossible de créer le répertoire SSH : $ssh_dir"
            return 4
        fi
    fi
    
    # Configuration des permissions du répertoire
    if [[ "$SET_PERMISSIONS" == true ]]; then
        chmod 700 "$ssh_dir" || {
            log_error "Impossible de définir les permissions du répertoire SSH"
            return 4
        }
    fi
    
    return 0
}

# === VÉRIFICATION DES DOUBLONS ===
check_duplicate_key() {
    local authorized_keys_path="$1"
    local key_fingerprint="$2"
    
    if [[ "$CHECK_DUPLICATES" == false ]]; then
        return 1  # Pas de vérification = pas de doublon
    fi
    
    if [[ ! -f "$authorized_keys_path" ]]; then
        return 1  # Fichier n'existe pas = pas de doublon
    fi
    
    log_debug "Vérification des doublons dans : $authorized_keys_path"
    
    # Vérification par empreinte
    while IFS= read -r line; do
        # Ignorer les lignes vides et commentaires
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Créer un fichier temporaire pour cette ligne
        local temp_line_file=$(mktemp)
        echo "$line" > "$temp_line_file"
        
        local line_fingerprint
        if line_fingerprint=$(ssh-keygen -l -f "$temp_line_file" 2>/dev/null | awk '{print $2}'); then
            if [[ "$line_fingerprint" == "$key_fingerprint" ]]; then
                rm -f "$temp_line_file"
                log_debug "Clé déjà présente (empreinte: $key_fingerprint)"
                return 0  # Doublon trouvé
            fi
        fi
        
        rm -f "$temp_line_file"
    done < "$authorized_keys_path"
    
    return 1  # Pas de doublon
}

# === SAUVEGARDE DU FICHIER EXISTANT ===
backup_authorized_keys() {
    local authorized_keys_path="$1"
    
    if [[ "$BACKUP_EXISTING" == false || ! -f "$authorized_keys_path" ]]; then
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

# === AJOUT DE LA CLÉ ===
add_key_to_authorized_keys() {
    local authorized_keys_path="$1"
    local key_content="$2"
    local comment="$3"
    
    log_debug "Ajout de la clé à : $authorized_keys_path"
    
    # Préparation de la ligne à ajouter
    local key_line="$key_content"
    if [[ -n "$comment" ]]; then
        # Remplacer ou ajouter le commentaire
        key_line=$(echo "$key_content" | sed "s/\([^[:space:]]*[[:space:]]*[^[:space:]]*\).*/\1 $comment/")
    fi
    
    # Ajout de la clé au fichier
    if echo "$key_line" >> "$authorized_keys_path"; then
        log_info "Clé ajoutée avec succès"
        
        # Configuration des permissions
        if [[ "$SET_PERMISSIONS" == true ]]; then
            chmod 600 "$authorized_keys_path" || {
                log_error "Impossible de définir les permissions de authorized_keys"
                return 4
            }
        fi
        
        return 0
    else
        log_error "Échec de l'ajout de la clé"
        return 4
    fi
}

# === VÉRIFICATION POST-AJOUT ===
verify_key_addition() {
    local authorized_keys_path="$1"
    local expected_fingerprint="$2"
    
    log_debug "Vérification de l'ajout de la clé"
    
    # Vérifier que la clé est bien présente
    if check_duplicate_key "$authorized_keys_path" "$expected_fingerprint"; then
        log_debug "Clé vérifiée avec succès dans authorized_keys"
        return 0
    else
        log_error "La clé n'a pas été trouvée après ajout"
        return 4
    fi
}

# === OPÉRATION DISTANTE VIA SSH ===
add_key_remote() {
    local remote_host="$1"
    local remote_user="$2"
    local ssh_dir="$3"
    local key_content="$4"
    
    log_debug "Ajout de clé distant sur $remote_user@$remote_host"
    
    # Créer le script d'ajout distant
    local remote_script=$(cat << 'REMOTE_EOF'
#!/bin/bash
set -euo pipefail

SSH_DIR="$1"
KEY_CONTENT="$2"
COMMENT="$3"
CHECK_DUPLICATES="$4"
SET_PERMISSIONS="$5"

AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# Créer le répertoire si nécessaire
mkdir -p "$SSH_DIR"
[[ "$SET_PERMISSIONS" == "true" ]] && chmod 700 "$SSH_DIR"

# Vérifier les doublons si demandé
if [[ "$CHECK_DUPLICATES" == "true" && -f "$AUTHORIZED_KEYS" ]]; then
    KEY_FINGERPRINT=$(echo "$KEY_CONTENT" | ssh-keygen -l -f - 2>/dev/null | awk '{print $2}' || echo "")
    
    if [[ -n "$KEY_FINGERPRINT" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            LINE_FP=$(echo "$line" | ssh-keygen -l -f - 2>/dev/null | awk '{print $2}' || echo "")
            if [[ "$LINE_FP" == "$KEY_FINGERPRINT" ]]; then
                echo '{"status": "exists", "message": "Key already present"}'
                exit 0
            fi
        done < "$AUTHORIZED_KEYS"
    fi
fi

# Ajouter la clé
KEY_LINE="$KEY_CONTENT"
[[ -n "$COMMENT" ]] && KEY_LINE=$(echo "$KEY_CONTENT" | sed "s/\([^[:space:]]*[[:space:]]*[^[:space:]]*\).*/\1 $COMMENT/")

if echo "$KEY_LINE" >> "$AUTHORIZED_KEYS"; then
    [[ "$SET_PERMISSIONS" == "true" ]] && chmod 600 "$AUTHORIZED_KEYS"
    echo '{"status": "added", "message": "Key added successfully"}'
else
    echo '{"status": "error", "message": "Failed to add key"}'
    exit 4
fi
REMOTE_EOF
    )
    
    # Exécution du script sur l'hôte distant
    local result
    if result=$(ssh "$remote_user@$remote_host" "bash -s -- '$ssh_dir' '$key_content' '$KEY_COMMENT' '$CHECK_DUPLICATES' '$SET_PERMISSIONS'" <<< "$remote_script" 2>&1); then
        echo "$result" > /tmp/remote_result_$$
        return 0
    else
        log_error "Échec de l'opération distante : $result"
        return 3
    fi
}

# === GÉNÉRATION DE LA SORTIE JSON ===
generate_output() {
    local operation_status="$1"
    local duplicate_found="$2"
    local backup_created="$3"
    
    # Lecture des métadonnées stockées
    local key_type=$(cat /tmp/key_type_$$ 2>/dev/null || echo "unknown")
    local key_bits=$(cat /tmp/key_bits_$$ 2>/dev/null || echo "0")
    local key_fingerprint=$(cat /tmp/key_fingerprint_$$ 2>/dev/null || echo "unknown")
    local backup_path=$(cat /tmp/backup_path_$$ 2>/dev/null || echo "none")
    
    # Détermination de la source de la clé
    local key_source="content"
    [[ -n "$PUBLIC_KEY_FILE" ]] && key_source="file"
    
    # Construction du JSON
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
        "key_info": {
            "type": "$key_type",
            "fingerprint": "$key_fingerprint",
            "bits": $key_bits,
            "comment": "$KEY_COMMENT",
            "source": "$key_source",
            "source_file": "$PUBLIC_KEY_FILE"
        },
        "operation": {
            "action": "$operation_status",
            "duplicate_found": $duplicate_found,
            "backup_created": "$backup_path",
            "permissions_set": $SET_PERMISSIONS,
            "force_mode": $FORCE_ADD
        }
    }
}
EOF
}

# === NETTOYAGE DES FICHIERS TEMPORAIRES ===
cleanup() {
    rm -f /tmp/validated_key_$$ /tmp/key_type_$$ /tmp/key_bits_$$ /tmp/key_fingerprint_$$ /tmp/backup_path_$$ /tmp/remote_result_$$ 2>/dev/null || true
}

# === GESTION DES ARGUMENTS ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -k|--key-file)
                PUBLIC_KEY_FILE="$2"
                shift 2
                ;;
            --key-content)
                PUBLIC_KEY_CONTENT="$2"
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
            -c|--comment)
                KEY_COMMENT="$2"
                shift 2
                ;;
            --no-duplicates-check)
                CHECK_DUPLICATES=false
                shift
                ;;
            --no-backup)
                BACKUP_EXISTING=false
                shift
                ;;
            --no-permissions)
                SET_PERMISSIONS=false
                shift
                ;;
            -f|--force)
                FORCE_ADD=true
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
    
    log_debug "Début de l'ajout de clé SSH pour $TARGET_USER"
    
    # Lecture et validation de la clé
    if ! read_and_validate_key; then
        exit 2
    fi
    
    local key_content=$(cat /tmp/validated_key_$$)
    local key_fingerprint=$(cat /tmp/key_fingerprint_$$)
    
    # Opération distante ou locale
    if [[ -n "$REMOTE_HOST" ]]; then
        log_info "Ajout de clé distant sur $REMOTE_HOST"
        if ! add_key_remote "$REMOTE_HOST" "$TARGET_USER" "$SSH_DIRECTORY" "$key_content"; then
            exit 3
        fi
        
        # Traitement du résultat distant
        local remote_result=$(cat /tmp/remote_result_$$ 2>/dev/null || echo '{"status": "unknown"}')
        local remote_status=$(echo "$remote_result" | jq -r '.status' 2>/dev/null || echo "unknown")
        
        case "$remote_status" in
            "exists")
                if [[ "$FORCE_ADD" == false ]]; then
                    log_error "Clé déjà présente sur l'hôte distant"
                    exit 5
                fi
                ;;
            "added")
                log_info "Clé ajoutée avec succès sur l'hôte distant"
                ;;
            "error")
                log_error "Erreur lors de l'ajout distant"
                exit 4
                ;;
        esac
        
        generate_output "added" "false" "none"
        
    else
        # Opération locale
        log_info "Ajout de clé local dans $SSH_DIRECTORY"
        
        local authorized_keys_path="$SSH_DIRECTORY/$AUTHORIZED_KEYS_FILE"
        
        # Préparation du répertoire SSH
        if ! prepare_ssh_directory "$SSH_DIRECTORY" "$TARGET_USER"; then
            exit 4
        fi
        
        # Vérification des doublons
        local duplicate_found=false
        if check_duplicate_key "$authorized_keys_path" "$key_fingerprint"; then
            duplicate_found=true
            if [[ "$FORCE_ADD" == false ]]; then
                log_error "Clé déjà présente dans authorized_keys"
                exit 5
            else
                log_info "Clé existante - ajout forcé activé"
            fi
        fi
        
        # Sauvegarde du fichier existant
        local backup_created="none"
        if backup_authorized_keys "$authorized_keys_path"; then
            backup_created=$(cat /tmp/backup_path_$$ 2>/dev/null || echo "none")
        fi
        
        # Ajout de la clé
        if ! add_key_to_authorized_keys "$authorized_keys_path" "$key_content" "$KEY_COMMENT"; then
            exit 4
        fi
        
        # Vérification post-ajout
        if ! verify_key_addition "$authorized_keys_path" "$key_fingerprint"; then
            exit 4
        fi
        
        local operation_action="added"
        [[ "$duplicate_found" == true ]] && operation_action="updated"
        
        generate_output "$operation_action" "$duplicate_found" "$backup_created"
    fi
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.00")
    
    log_debug "Ajout de clé terminé en ${duration}s"
    
    return 0
}

# Point d'entrée du script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi