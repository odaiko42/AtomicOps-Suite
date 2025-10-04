#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: ssh-key-test.sh  
# Description: Test et validation des clés SSH (génération, format, permissions)
# Author: Generated with AtomicOps-Suite AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# Level: 0 (Atomique)
# Dependencies: ssh-keygen, ssh-add
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="ssh-key-test.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}

# Variables de clé SSH
SSH_KEY_PATH=""
SSH_KEY_TYPE=""
SSH_KEY_BITS=""
PASSPHRASE=""
GENERATE_KEY=${GENERATE_KEY:-0}
TEST_MODE=${TEST_MODE:-"validate"}  # validate|generate|info

# Variables de résultat
KEY_EXISTS=0
KEY_VALID=0
KEY_TYPE_DETECTED=""
KEY_BITS_DETECTED=""
KEY_FINGERPRINT=""
KEY_COMMENT=""
KEY_PERMISSIONS_OK=0
PUBLIC_KEY_EXISTS=0
PRIVATE_KEY_ENCRYPTED=0

# =============================================================================
# Fonctions Utilitaires et Logging
# =============================================================================

log_debug() {
    [[ $DEBUG -eq 0 ]] && return 0
    echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_info() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_warn() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

die() {
    log_error "$1"
    build_json_output "error" "${2:-1}" "$1"
    exit "${2:-1}"
}

# =============================================================================
# Fonctions d'Aide et de Parsing
# =============================================================================

show_help() {
    cat << 'EOF'
Usage: ssh-key-test.sh [OPTIONS] --key <path> [--mode <mode>]

Description:
    Test et validation des clés SSH - vérifie le format, les permissions, 
    génère de nouvelles clés, ou affiche des informations détaillées sur 
    les clés existantes.

Modes d'opération:
    --mode validate        Valide une clé SSH existante (défaut)
    --mode generate        Génère une nouvelle paire de clés SSH
    --mode info           Affiche les informations d'une clé existante

Arguments obligatoires:
    --key <path>           Chemin vers la clé privée SSH

Options générales:
    -h, --help            Afficher cette aide
    -v, --verbose         Mode verbeux (affichage détaillé)
    -d, --debug           Mode debug (informations de débogage)
    -q, --quiet           Mode silencieux (erreurs seulement)
    -j, --json-only       Sortie JSON uniquement (sans logs)

Options pour génération (--mode generate):
    --type <type>         Type de clé: rsa|ed25519|ecdsa (défaut: ed25519)
    --bits <n>            Taille de clé RSA en bits (défaut: 4096)
    --passphrase <pass>   Phrase de passe pour la clé privée
    --comment <text>      Commentaire pour la clé

Variables d'environnement:
    SSH_KEY_TYPE          Type de clé par défaut (ed25519)
    SSH_KEY_BITS          Taille par défaut pour RSA (4096)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0|1|2|3,
      "timestamp": "ISO8601",
      "script": "ssh-key-test.sh",
      "message": "Description du résultat",
      "data": {
        "key_info": {
          "path": "/path/to/key",
          "exists": true,
          "valid": true,
          "type": "ed25519",
          "bits": 256,
          "fingerprint": "SHA256:...",
          "comment": "user@host",
          "encrypted": false
        },
        "permissions": {
          "private_key": "600",
          "public_key": "644", 
          "permissions_ok": true
        },
        "validation": {
          "format_valid": true,
          "can_load": true,
          "pair_exists": true
        }
      }
    }

Codes de sortie:
    0 - Opération réussie
    1 - Erreur de paramètres ou configuration
    2 - Clé SSH non trouvée ou inaccessible
    3 - Clé SSH invalide ou corrompue

Exemples:
    # Valider une clé existante
    ./ssh-key-test.sh --key ~/.ssh/id_rsa --mode validate
    
    # Générer une nouvelle clé ED25519
    ./ssh-key-test.sh --key ~/.ssh/new_key --mode generate --type ed25519
    
    # Générer clé RSA avec phrase de passe
    ./ssh-key-test.sh --key ~/.ssh/deploy_key --mode generate \
        --type rsa --bits 4096 --passphrase "secure123"
    
    # Informations sur une clé
    ./ssh-key-test.sh --key ~/.ssh/id_ed25519 --mode info
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
                ;;
            -d|--debug)
                DEBUG=1
                VERBOSE=1
                ;;
            -q|--quiet)
                QUIET=1
                ;;
            -j|--json-only)
                JSON_ONLY=1
                QUIET=1
                ;;
            --key)
                [[ -z "${2:-}" ]] && die "Option --key nécessite une valeur" 1
                SSH_KEY_PATH="$2"
                shift
                ;;
            --mode)
                [[ -z "${2:-}" ]] && die "Option --mode nécessite une valeur" 1
                TEST_MODE="$2"
                shift
                ;;
            --type)
                [[ -z "${2:-}" ]] && die "Option --type nécessite une valeur" 1
                SSH_KEY_TYPE="$2"
                shift
                ;;
            --bits)
                [[ -z "${2:-}" ]] && die "Option --bits nécessite une valeur" 1
                SSH_KEY_BITS="$2"
                shift
                ;;
            --passphrase)
                [[ -z "${2:-}" ]] && die "Option --passphrase nécessite une valeur" 1
                PASSPHRASE="$2"
                shift
                ;;
            --comment)
                [[ -z "${2:-}" ]] && die "Option --comment nécessite une valeur" 1
                KEY_COMMENT="$2"
                shift
                ;;
            -*)
                die "Option inconnue: $1" 1
                ;;
            *)
                die "Argument non attendu: $1" 1
                ;;
        esac
        shift
    done
}

# =============================================================================
# Fonctions de Validation
# =============================================================================

validate_prerequisites() {
    log_debug "Validation des prérequis système..."
    
    # Vérification des commandes nécessaires
    local missing_commands=()
    
    if ! command -v ssh-keygen >/dev/null 2>&1; then
        missing_commands+=("ssh-keygen")
    fi
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing_commands[*]}" 1
    fi
    
    # Validation des paramètres obligatoires
    [[ -z "$SSH_KEY_PATH" ]] && die "Paramètre --key obligatoire" 1
    
    # Validation du mode
    case "$TEST_MODE" in
        validate|generate|info)
            ;;
        *)
            die "Mode invalide: $TEST_MODE (doit être: validate|generate|info)" 1
            ;;
    esac
    
    # Validation spécifique au mode génération
    if [[ "$TEST_MODE" = "generate" ]]; then
        SSH_KEY_TYPE="${SSH_KEY_TYPE:-${SSH_KEY_TYPE:-ed25519}}"
        
        case "$SSH_KEY_TYPE" in
            rsa)
                SSH_KEY_BITS="${SSH_KEY_BITS:-4096}"
                if [[ ! "$SSH_KEY_BITS" =~ ^(2048|3072|4096|8192)$ ]]; then
                    die "Taille RSA invalide: $SSH_KEY_BITS (2048, 3072, 4096, 8192)" 1
                fi
                ;;
            ed25519)
                SSH_KEY_BITS="256"  # Fixe pour ED25519
                ;;
            ecdsa)
                SSH_KEY_BITS="${SSH_KEY_BITS:-256}"
                if [[ ! "$SSH_KEY_BITS" =~ ^(256|384|521)$ ]]; then
                    die "Taille ECDSA invalide: $SSH_KEY_BITS (256, 384, 521)" 1
                fi
                ;;
            *)
                die "Type de clé invalide: $SSH_KEY_TYPE (rsa, ed25519, ecdsa)" 1
                ;;
        esac
    fi
    
    log_debug "Validation réussie"
    log_info "Mode: $TEST_MODE pour clé: $SSH_KEY_PATH"
    
    return 0
}

# =============================================================================
# Fonctions Principales
# =============================================================================

# Vérification de l'existence et accès aux fichiers
check_key_files() {
    log_debug "Vérification des fichiers de clés"
    
    # Clé privée
    if [[ -f "$SSH_KEY_PATH" ]]; then
        KEY_EXISTS=1
        log_debug "Clé privée trouvée: $SSH_KEY_PATH"
        
        # Vérification des permissions
        local perms=$(stat -c "%a" "$SSH_KEY_PATH" 2>/dev/null || echo "000")
        if [[ "$perms" = "600" ]] || [[ "$perms" = "400" ]]; then
            KEY_PERMISSIONS_OK=1
            log_debug "Permissions clé privée OK: $perms"
        else
            log_warn "Permissions clé privée incorrectes: $perms (recommandé: 600)"
        fi
    else
        log_debug "Clé privée non trouvée: $SSH_KEY_PATH"
    fi
    
    # Clé publique
    local public_key_path="${SSH_KEY_PATH}.pub"
    if [[ -f "$public_key_path" ]]; then
        PUBLIC_KEY_EXISTS=1
        log_debug "Clé publique trouvée: $public_key_path"
    else
        log_debug "Clé publique non trouvée: $public_key_path"
    fi
}

# Analyse des informations de la clé
analyze_key_info() {
    log_debug "Analyse des informations de la clé"
    
    if [[ $KEY_EXISTS -eq 0 ]]; then
        log_debug "Clé n'existe pas, analyse impossible"
        return 0
    fi
    
    # Test de validité et extraction d'informations
    local key_info_output
    if key_info_output=$(ssh-keygen -l -f "$SSH_KEY_PATH" 2>/dev/null); then
        KEY_VALID=1
        
        # Parsing de la sortie: "2048 SHA256:... user@host (RSA)"
        if [[ "$key_info_output" =~ ([0-9]+)\ (SHA256:[A-Za-z0-9+/]+)\ (.*)\ \(([A-Z0-9]+)\) ]]; then
            KEY_BITS_DETECTED="${BASH_REMATCH[1]}"
            KEY_FINGERPRINT="${BASH_REMATCH[2]}"
            KEY_COMMENT="${BASH_REMATCH[3]}"
            KEY_TYPE_DETECTED="${BASH_REMATCH[4]}"
        elif [[ "$key_info_output" =~ ([0-9]+)\ (SHA256:[A-Za-z0-9+/]+)\ \(([A-Z0-9]+)\) ]]; then
            # Format sans commentaire
            KEY_BITS_DETECTED="${BASH_REMATCH[1]}"
            KEY_FINGERPRINT="${BASH_REMATCH[2]}"
            KEY_TYPE_DETECTED="${BASH_REMATCH[3]}"
            KEY_COMMENT=""
        fi
        
        log_debug "Type: ${KEY_TYPE_DETECTED}, Bits: ${KEY_BITS_DETECTED}, Empreinte: ${KEY_FINGERPRINT}"
    else
        log_warn "Impossible d'analyser la clé (corrompue ou format invalide)"
        KEY_VALID=0
    fi
    
    # Test de chiffrement de la clé privée
    if head -n 5 "$SSH_KEY_PATH" | grep -q "ENCRYPTED"; then
        PRIVATE_KEY_ENCRYPTED=1
        log_debug "Clé privée chiffrée détectée"
    else
        log_debug "Clé privée non chiffrée"
    fi
}

# Génération d'une nouvelle clé SSH
generate_ssh_key() {
    log_debug "Génération d'une nouvelle clé SSH"
    
    # Vérifier si la clé existe déjà
    if [[ -f "$SSH_KEY_PATH" ]]; then
        die "Clé existe déjà: $SSH_KEY_PATH (utilisez --mode validate pour tester)" 2
    fi
    
    # Créer le répertoire parent si nécessaire
    local key_dir=$(dirname "$SSH_KEY_PATH")
    if [[ ! -d "$key_dir" ]]; then
        mkdir -p "$key_dir" || die "Impossible de créer le répertoire: $key_dir" 1
        chmod 700 "$key_dir"
        log_debug "Répertoire créé: $key_dir"
    fi
    
    # Préparation des arguments ssh-keygen
    local keygen_args=()
    keygen_args+=(-t "$SSH_KEY_TYPE")
    
    if [[ "$SSH_KEY_TYPE" = "rsa" ]]; then
        keygen_args+=(-b "$SSH_KEY_BITS")
    elif [[ "$SSH_KEY_TYPE" = "ecdsa" ]]; then
        keygen_args+=(-b "$SSH_KEY_BITS")
    fi
    
    keygen_args+=(-f "$SSH_KEY_PATH")
    
    if [[ -n "$KEY_COMMENT" ]]; then
        keygen_args+=(-C "$KEY_COMMENT")
    fi
    
    if [[ -n "$PASSPHRASE" ]]; then
        keygen_args+=(-N "$PASSPHRASE")
    else
        keygen_args+=(-N "")  # Pas de phrase de passe
    fi
    
    log_info "Génération de la clé $SSH_KEY_TYPE (${SSH_KEY_BITS} bits)"
    
    # Génération de la clé
    if ssh-keygen "${keygen_args[@]}" >/dev/null 2>&1; then
        log_info "Clé générée avec succès: $SSH_KEY_PATH"
        
        # Mise à jour des permissions
        chmod 600 "$SSH_KEY_PATH"
        if [[ -f "${SSH_KEY_PATH}.pub" ]]; then
            chmod 644 "${SSH_KEY_PATH}.pub"
        fi
        
        # Re-analyser la clé générée
        check_key_files
        analyze_key_info
        
        return 0
    else
        die "Échec de génération de la clé SSH" 3
    fi
}

# Mode validation de clé
validate_ssh_key() {
    log_debug "Validation de la clé SSH"
    
    check_key_files
    
    if [[ $KEY_EXISTS -eq 0 ]]; then
        die "Clé SSH non trouvée: $SSH_KEY_PATH" 2
    fi
    
    analyze_key_info
    
    if [[ $KEY_VALID -eq 0 ]]; then
        die "Clé SSH invalide ou corrompue: $SSH_KEY_PATH" 3
    fi
    
    # Vérifications additionnelles
    local warnings=()
    
    if [[ $KEY_PERMISSIONS_OK -eq 0 ]]; then
        warnings+=("Permissions de clé privée non sécurisées")
    fi
    
    if [[ $PUBLIC_KEY_EXISTS -eq 0 ]]; then
        warnings+=("Clé publique associée manquante")
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        for warning in "${warnings[@]}"; do
            log_warn "$warning"
        done
    fi
    
    log_info "Clé SSH validée avec succès"
    return 0
}

# Mode information de clé
show_key_info() {
    log_debug "Affichage des informations de clé"
    
    check_key_files
    analyze_key_info
    
    if [[ $KEY_EXISTS -eq 0 ]]; then
        die "Clé SSH non trouvée: $SSH_KEY_PATH" 2
    fi
    
    if [[ $KEY_VALID -eq 0 ]]; then
        die "Clé SSH invalide, impossible d'afficher les informations" 3
    fi
    
    # Informations détaillées (en mode non-quiet)
    if [[ $QUIET -eq 0 ]] && [[ $JSON_ONLY -eq 0 ]]; then
        echo "=== Informations de clé SSH ==="
        echo "Fichier: $SSH_KEY_PATH"
        echo "Type: $KEY_TYPE_DETECTED"
        echo "Taille: $KEY_BITS_DETECTED bits"
        echo "Empreinte: $KEY_FINGERPRINT"
        echo "Commentaire: ${KEY_COMMENT:-<aucun>}"
        echo "Chiffrée: $([ $PRIVATE_KEY_ENCRYPTED -eq 1 ] && echo "Oui" || echo "Non")"
        echo "Clé publique: $([ $PUBLIC_KEY_EXISTS -eq 1 ] && echo "Présente" || echo "Manquante")"
        echo "Permissions: $([ $KEY_PERMISSIONS_OK -eq 1 ] && echo "OK" || echo "À corriger")"
    fi
    
    return 0
}

# Action principale du script
do_main_action() {
    log_debug "Démarrage du mode: $TEST_MODE"
    
    case "$TEST_MODE" in
        validate)
            validate_ssh_key
            ;;
        generate)
            generate_ssh_key
            ;;
        info)
            show_key_info
            ;;
        *)
            die "Mode non supporté: $TEST_MODE" 1
            ;;
    esac
}

# =============================================================================
# Fonction de Construction de Sortie JSON
# =============================================================================

build_json_output() {
    local status="$1"
    local exit_code="$2"
    local message="$3"
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
    
    # Permissions des fichiers
    local private_perms="null"
    local public_perms="null"
    
    if [[ $KEY_EXISTS -eq 1 ]]; then
        private_perms="\"$(stat -c "%a" "$SSH_KEY_PATH" 2>/dev/null || echo "000")\""
    fi
    
    if [[ $PUBLIC_KEY_EXISTS -eq 1 ]]; then
        public_perms="\"$(stat -c "%a" "${SSH_KEY_PATH}.pub" 2>/dev/null || echo "000")\""
    fi
    
    cat << EOF
{
  "status": "$status",
  "code": $exit_code,
  "timestamp": "$timestamp",
  "script": "$SCRIPT_NAME",
  "message": "$message",
  "data": {
    "key_info": {
      "path": "$SSH_KEY_PATH",
      "exists": $([ $KEY_EXISTS -eq 1 ] && echo "true" || echo "false"),
      "valid": $([ $KEY_VALID -eq 1 ] && echo "true" || echo "false"),
      "type": "${KEY_TYPE_DETECTED:-null}",
      "bits": ${KEY_BITS_DETECTED:-0},
      "fingerprint": "${KEY_FINGERPRINT:-null}",
      "comment": "${KEY_COMMENT:-null}",
      "encrypted": $([ $PRIVATE_KEY_ENCRYPTED -eq 1 ] && echo "true" || echo "false")
    },
    "permissions": {
      "private_key": $private_perms,
      "public_key": $public_perms,
      "permissions_ok": $([ $KEY_PERMISSIONS_OK -eq 1 ] && echo "true" || echo "false")
    },
    "validation": {
      "format_valid": $([ $KEY_VALID -eq 1 ] && echo "true" || echo "false"),
      "can_load": $([ $KEY_VALID -eq 1 ] && echo "true" || echo "false"),
      "pair_exists": $([ $PUBLIC_KEY_EXISTS -eq 1 ] && echo "true" || echo "false")
    },
    "operation": {
      "mode": "$TEST_MODE",
      "generated": $([ "$TEST_MODE" = "generate" ] && echo "true" || echo "false")
    }
  }
}
EOF
}

# =============================================================================
# Fonction de Nettoyage
# =============================================================================

cleanup() {
    log_debug "Nettoyage des ressources"
    # Pas de ressources spécifiques à nettoyer pour ce script
}

# =============================================================================
# Point d'Entrée Principal
# =============================================================================

main() {
    # Configuration du trap pour le nettoyage
    trap cleanup EXIT ERR INT TERM
    
    # Récupération des variables d'environnement par défaut
    SSH_KEY_TYPE="${SSH_KEY_TYPE:-ed25519}"
    SSH_KEY_BITS="${SSH_KEY_BITS:-4096}"
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des prérequis
    validate_prerequisites
    
    # Exécution de l'action principale
    local exit_code=0
    local result_message="Opération SSH key réussie"
    
    if do_main_action; then
        case "$TEST_MODE" in
            validate)
                result_message="Clé SSH validée avec succès"
                ;;
            generate)
                result_message="Clé SSH générée avec succès"
                ;;
            info)
                result_message="Informations de clé SSH récupérées"
                ;;
        esac
        exit_code=0
    else
        local action_exit_code=$?
        case $action_exit_code in
            2)
                result_message="Clé SSH non trouvée ou inaccessible"
                exit_code=2
                ;;
            3)
                result_message="Clé SSH invalide ou corrompue"
                exit_code=3
                ;;
            *)
                result_message="Erreur lors de l'opération SSH key"
                exit_code=1
                ;;
        esac
    fi
    
    # Génération de la sortie JSON
    build_json_output \
        "$([ $exit_code -eq 0 ] && echo "success" || echo "error")" \
        "$exit_code" \
        "$result_message"
    
    exit $exit_code
}

# Exécution du script si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi