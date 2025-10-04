#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: generate-ssh.keypair.sh
# Description: Générer une paire de clés SSH avec configuration sécurisée
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="generate-ssh.keypair.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
FORCE=${FORCE:-0}
KEY_TYPE="ed25519"
KEY_SIZE=""
KEY_COMMENT=""
KEY_PATH=""
PASSPHRASE=""
NO_PASSPHRASE=${NO_PASSPHRASE:-0}

# =============================================================================
# Fonctions Utilitaires et Logging
# =============================================================================

log_debug() {
    [[ $DEBUG -eq 0 ]] && return 0
    echo "[DEBUG] $*" >&2
}

log_info() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[INFO] $*" >&2
}

log_warn() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

die() {
    log_error "$1"
    exit "${2:-1}"
}

# =============================================================================
# Fonctions d'Aide et de Parsing
# =============================================================================

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Description:
    Génère une paire de clés SSH sécurisée avec les meilleures pratiques
    de sécurité et configuration automatique.

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -f, --force            Écraser les clés existantes sans confirmation
    -t, --type TYPE        Type de clé (ed25519, rsa, ecdsa, défaut: ed25519)
    -b, --bits BITS        Taille de clé (2048, 3072, 4096 pour RSA)
    -C, --comment TEXT     Commentaire pour la clé
    -p, --path PATH        Chemin de la clé privée (défaut: ~/.ssh/id_TYPE)
    --passphrase PHRASE    Phrase de passe pour la clé
    --no-passphrase        Générer sans phrase de passe
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "key_type": "ed25519",
        "key_size": 256,
        "key_comment": "user@hostname-20251004",
        "private_key_path": "/home/user/.ssh/id_ed25519",
        "public_key_path": "/home/user/.ssh/id_ed25519.pub",
        "fingerprint": "SHA256:abc123...",
        "public_key_content": "ssh-ed25519 AAAAC3Nza... user@hostname",
        "key_strength": "high",
        "passphrase_protected": true,
        "permissions": {
          "private_key": "600",
          "public_key": "644",
          "ssh_dir": "700"
        },
        "installation": {
          "authorized_keys_added": false,
          "ssh_config_updated": false
        }
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - ssh-keygen non trouvé
    4 - Permissions insuffisantes

Types de clés supportés:
    - ed25519: Recommandé (sécurisé, rapide, petite taille)
    - rsa: Compatible (2048/3072/4096 bits)
    - ecdsa: Moderne (256/384/521 bits)

Exemples:
    $SCRIPT_NAME                                   # ed25519 par défaut
    $SCRIPT_NAME -t rsa -b 4096                   # RSA 4096 bits
    $SCRIPT_NAME -C "work-laptop" --no-passphrase # Sans phrase de passe
    $SCRIPT_NAME -p ~/.ssh/id_backup              # Chemin personnalisé
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                VERBOSE=1
                shift
                ;;
            -q|--quiet)
                QUIET=1
                shift
                ;;
            -j|--json-only)
                JSON_ONLY=1
                QUIET=1
                shift
                ;;
            -f|--force)
                FORCE=1
                shift
                ;;
            -t|--type)
                if [[ -n "${2:-}" ]]; then
                    KEY_TYPE="$2"
                    shift 2
                else
                    die "Type de clé manquant pour -t/--type" 2
                fi
                ;;
            -b|--bits)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                    KEY_SIZE="$2"
                    shift 2
                else
                    die "Taille de clé invalide: ${2:-}. Doit être un nombre." 2
                fi
                ;;
            -C|--comment)
                if [[ -n "${2:-}" ]]; then
                    KEY_COMMENT="$2"
                    shift 2
                else
                    die "Commentaire manquant pour -C/--comment" 2
                fi
                ;;
            -p|--path)
                if [[ -n "${2:-}" ]]; then
                    KEY_PATH="$2"
                    shift 2
                else
                    die "Chemin manquant pour -p/--path" 2
                fi
                ;;
            --passphrase)
                if [[ -n "${2:-}" ]]; then
                    PASSPHRASE="$2"
                    shift 2
                else
                    die "Phrase de passe manquante pour --passphrase" 2
                fi
                ;;
            --no-passphrase)
                NO_PASSPHRASE=1
                shift
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                die "Argument inattendu: $1. Utilisez -h pour l'aide." 2
                ;;
        esac
    done

    # Validation du type de clé
    case "$KEY_TYPE" in
        ed25519|rsa|ecdsa) ;;
        *) die "Type de clé non supporté: $KEY_TYPE. Utilisez ed25519, rsa ou ecdsa." 2 ;;
    esac
    
    # Validation de la taille selon le type
    if [[ -n "$KEY_SIZE" ]]; then
        case "$KEY_TYPE" in
            ed25519)
                if [[ "$KEY_SIZE" != "256" ]]; then
                    log_warn "Ed25519 utilise toujours 256 bits. Taille ignorée."
                fi
                KEY_SIZE=""  # Ed25519 n'a pas d'option de taille
                ;;
            rsa)
                if [[ $KEY_SIZE -lt 2048 ]]; then
                    die "Taille RSA trop petite: $KEY_SIZE. Minimum 2048 bits." 2
                fi
                ;;
            ecdsa)
                if [[ "$KEY_SIZE" != "256" && "$KEY_SIZE" != "384" && "$KEY_SIZE" != "521" ]]; then
                    die "Taille ECDSA invalide: $KEY_SIZE. Utilisez 256, 384 ou 521." 2
                fi
                ;;
        esac
    else
        # Tailles par défaut
        case "$KEY_TYPE" in
            rsa) KEY_SIZE="3072" ;;
            ecdsa) KEY_SIZE="256" ;;
        esac
    fi
    
    # Générer le commentaire par défaut
    if [[ -z "$KEY_COMMENT" ]]; then
        KEY_COMMENT="$(whoami)@$(hostname)-$(date +%Y%m%d)"
    fi
    
    # Chemin par défaut
    if [[ -z "$KEY_PATH" ]]; then
        KEY_PATH="$HOME/.ssh/id_$KEY_TYPE"
    fi
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    if ! command -v ssh-keygen >/dev/null 2>&1; then
        die "ssh-keygen non trouvé. Installez openssh-client." 3
    fi
    
    log_debug "Dépendances SSH vérifiées"
}

check_existing_keys() {
    local private_key="$1"
    local public_key="${private_key}.pub"
    
    if [[ -f "$private_key" || -f "$public_key" ]]; then
        if [[ $FORCE -eq 1 ]]; then
            log_warn "Écrasement des clés existantes: $private_key"
            return 0
        else
            echo "Des clés SSH existent déjà:" >&2
            [[ -f "$private_key" ]] && echo "  - $private_key" >&2
            [[ -f "$public_key" ]] && echo "  - $public_key" >&2
            echo "Utilisez -f/--force pour les écraser ou choisissez un autre chemin." >&2
            return 1
        fi
    fi
    
    return 0
}

create_ssh_directory() {
    local ssh_dir
    ssh_dir=$(dirname "$KEY_PATH")
    
    if [[ ! -d "$ssh_dir" ]]; then
        log_debug "Création du répertoire SSH: $ssh_dir"
        if ! mkdir -p "$ssh_dir"; then
            die "Impossible de créer le répertoire: $ssh_dir" 1
        fi
    fi
    
    # Sécuriser le répertoire SSH
    chmod 700 "$ssh_dir"
    log_debug "Permissions SSH dir définies: 700"
}

generate_ssh_key() {
    local key_path="$1"
    local key_type="$2"
    local key_size="$3"
    local key_comment="$4"
    local passphrase="$5"
    
    log_info "Génération de la clé SSH $key_type..."
    
    # Construire la commande ssh-keygen
    local cmd="ssh-keygen"
    cmd+=" -t $key_type"
    
    if [[ -n "$key_size" ]]; then
        cmd+=" -b $key_size"
    fi
    
    cmd+=" -C \"$key_comment\""
    cmd+=" -f \"$key_path\""
    
    # Gestion de la phrase de passe
    if [[ $NO_PASSPHRASE -eq 1 || -z "$passphrase" ]]; then
        cmd+=" -N \"\""
    else
        cmd+=" -N \"$passphrase\""
    fi
    
    log_debug "Commande ssh-keygen: ${cmd//-N */[passphrase hidden]}"
    
    # Exécuter la génération
    if eval "$cmd" >/dev/null 2>&1; then
        log_info "Clé SSH générée avec succès"
        return 0
    else
        die "Échec de la génération de clé SSH" 1
    fi
}

set_key_permissions() {
    local private_key="$1"
    local public_key="${private_key}.pub"
    
    # Permissions clé privée (lecture seule propriétaire)
    if [[ -f "$private_key" ]]; then
        chmod 600 "$private_key"
        log_debug "Permissions clé privée: 600"
    fi
    
    # Permissions clé publique (lecture pour tous)
    if [[ -f "$public_key" ]]; then
        chmod 644 "$public_key"
        log_debug "Permissions clé publique: 644"
    fi
}

get_key_info() {
    local private_key="$1"
    local public_key="${private_key}.pub"
    
    local fingerprint="" public_key_content="" actual_key_size=""
    
    # Empreinte de la clé
    if [[ -f "$public_key" ]]; then
        fingerprint=$(ssh-keygen -lf "$public_key" 2>/dev/null | awk '{print $2}' || echo "")
        public_key_content=$(cat "$public_key" 2>/dev/null || echo "")
        
        # Taille réelle de la clé
        actual_key_size=$(ssh-keygen -lf "$public_key" 2>/dev/null | awk '{print $1}' || echo "0")
    fi
    
    echo "$fingerprint|$public_key_content|$actual_key_size"
}

assess_key_strength() {
    local key_type="$1"
    local key_size="$2"
    local has_passphrase="$3"
    
    local strength="medium"
    
    case "$key_type" in
        ed25519)
            strength="high"
            ;;
        rsa)
            if [[ $key_size -ge 4096 ]]; then
                strength="high"
            elif [[ $key_size -ge 3072 ]]; then
                strength="medium"
            else
                strength="low"
            fi
            ;;
        ecdsa)
            if [[ $key_size -ge 384 ]]; then
                strength="high"
            else
                strength="medium"
            fi
            ;;
    esac
    
    # Réduire si pas de phrase de passe
    if [[ "$has_passphrase" == "false" ]]; then
        case "$strength" in
            high) strength="medium" ;;
            medium) strength="low" ;;
        esac
    fi
    
    echo "$strength"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    
    # Résoudre le chemin absolu
    KEY_PATH=$(readlink -f "$KEY_PATH" 2>/dev/null || echo "$KEY_PATH")
    
    log_info "Génération clé SSH $KEY_TYPE dans: $KEY_PATH"
    
    # Vérifier les clés existantes
    if ! check_existing_keys "$KEY_PATH"; then
        die "Clés existantes trouvées. Utilisez -f pour les écraser." 1
    fi
    
    # Créer le répertoire SSH
    create_ssh_directory
    
    # Déterminer la phrase de passe
    local has_passphrase=false
    if [[ $NO_PASSPHRASE -eq 0 ]]; then
        if [[ -z "$PASSPHRASE" ]]; then
            # Générer une phrase de passe aléatoire si aucune n'est fournie
            if command -v openssl >/dev/null 2>&1; then
                PASSPHRASE=$(openssl rand -base64 32 2>/dev/null || echo "")
                [[ -n "$PASSPHRASE" ]] && has_passphrase=true
            fi
        else
            has_passphrase=true
        fi
    fi
    
    # Générer la clé
    generate_ssh_key "$KEY_PATH" "$KEY_TYPE" "$KEY_SIZE" "$KEY_COMMENT" "$PASSPHRASE"
    
    # Définir les permissions
    set_key_permissions "$KEY_PATH"
    
    # Obtenir les informations de la clé
    local key_info fingerprint public_key_content actual_key_size
    key_info=$(get_key_info "$KEY_PATH")
    IFS='|' read -r fingerprint public_key_content actual_key_size <<< "$key_info"
    
    # Évaluer la force de la clé
    local key_strength
    key_strength=$(assess_key_strength "$KEY_TYPE" "${actual_key_size:-$KEY_SIZE}" "$has_passphrase")
    
    # Échapper pour JSON
    local key_comment_escaped key_path_escaped public_key_escaped fingerprint_escaped
    key_comment_escaped=$(echo "$KEY_COMMENT" | sed 's/\\/\\\\/g; s/"/\\"/g')
    key_path_escaped=$(echo "$KEY_PATH" | sed 's/\\/\\\\/g; s/"/\\"/g')
    public_key_escaped=$(echo "$public_key_content" | sed 's/\\/\\\\/g; s/"/\\"/g')
    fingerprint_escaped=$(echo "$fingerprint" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Générer la réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "SSH keypair generated successfully",
  "data": {
    "key_type": "$KEY_TYPE",
    "key_size": ${actual_key_size:-$KEY_SIZE},
    "key_comment": "$key_comment_escaped",
    "private_key_path": "$key_path_escaped",
    "public_key_path": "${key_path_escaped}.pub",
    "fingerprint": "$fingerprint_escaped",
    "public_key_content": "$public_key_escaped",
    "key_strength": "$key_strength",
    "passphrase_protected": $has_passphrase,
    "permissions": {
      "private_key": "600",
      "public_key": "644",
      "ssh_dir": "700"
    },
    "installation": {
      "authorized_keys_added": false,
      "ssh_config_updated": false
    },
    "security_recommendations": [
      "Add public key to remote authorized_keys",
      "Test SSH connection before removing password auth",
      "Backup private key securely",
      "Use SSH agent for key management"
    ]
  },
  "errors": [],
  "warnings": $([ "$has_passphrase" == "false" ] && echo "[\"Key generated without passphrase - consider adding one for security\"]" || echo "[]")
}
EOF
    
    # Afficher la clé publique si pas en mode JSON-only
    if [[ $JSON_ONLY -eq 0 ]]; then
        echo >&2
        echo "Clé publique générée:" >&2
        echo "$public_key_content" >&2
        echo >&2
        echo "Pour utiliser cette clé:" >&2
        echo "1. Copiez la clé publique sur le serveur distant:" >&2
        echo "   ssh-copy-id -i ${KEY_PATH}.pub user@server" >&2
        echo "2. Ou ajoutez-la manuellement à ~/.ssh/authorized_keys" >&2
    fi
    
    log_info "Génération terminée avec succès"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi