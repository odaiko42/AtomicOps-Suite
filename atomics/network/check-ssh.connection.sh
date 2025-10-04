#!/usr/bin/env bash

#===============================================================================
# Script Atomique : Test de Connectivité SSH et Diagnostic
#===============================================================================
# Nom du fichier : check-ssh.connection.sh
# Niveau : 0 (Atomique)
# Catégorie : network
# Protocole : ssh
# Description : Vérifie la connectivité SSH avec diagnostic détaillé
#
# Objectif :
# - Test de connectivité SSH complète avec diagnostic
# - Validation de l'authentification par clé ou mot de passe
# - Analyse des performances de connexion
# - Test de commandes distantes et transfert de fichiers
# - Diagnostic réseau et configuration SSH
#
# Conforme à la méthodologie AtomicOps-Suite - Niveau 0
#===============================================================================

set -euo pipefail

# === MÉTADONNÉES DU SCRIPT ===
readonly SCRIPT_NAME="check-ssh.connection.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_CATEGORY="network"
readonly SCRIPT_PROTOCOL="ssh"
readonly SCRIPT_LEVEL=0

# === CONFIGURATION PAR DÉFAUT ===
readonly DEFAULT_SSH_PORT=22
readonly DEFAULT_TIMEOUT=10
readonly DEFAULT_USER="$(whoami)"
readonly SSH_CONFIG_PATHS=("/etc/ssh/ssh_config" "$HOME/.ssh/config")

# === VARIABLES GLOBALES ===
TARGET_HOST=""
TARGET_PORT="$DEFAULT_SSH_PORT"
TARGET_USER="$DEFAULT_USER"
SSH_KEY_FILE=""
CONNECTION_TIMEOUT="$DEFAULT_TIMEOUT"
TEST_COMMAND=""
TEST_FILE_TRANSFER=false
VERBOSE_MODE=false
QUIET_MODE=false
DEBUG_MODE=false
BENCHMARK_MODE=false
FULL_DIAGNOSTIC=false

# === FONCTIONS D'AIDE ===
show_help() {
    cat << EOF
Test de Connectivité SSH et Diagnostic - Script Atomique Niveau 0

USAGE:
    $(basename "$0") [OPTIONS] HOST

DESCRIPTION:
    Effectue un test complet de connectivité SSH avec diagnostic détaillé :
    - Test de connectivité réseau (ping, telnet)
    - Validation de l'authentification SSH
    - Mesure des performances de connexion
    - Test d'exécution de commandes distantes
    - Diagnostic de configuration SSH
    - Test optionnel de transfert de fichiers (SCP/SFTP)

PARAMÈTRES OBLIGATOIRES:
    HOST                    Nom d'hôte ou adresse IP à tester

OPTIONS PRINCIPALES:
    -p, --port PORT         Port SSH (défaut: 22)
    -u, --user USER         Nom d'utilisateur SSH (défaut: current user)
    -i, --identity FILE     Fichier de clé privée SSH à utiliser
    -t, --timeout SECONDS   Timeout de connexion en secondes (défaut: 10)
    
OPTIONS DE TEST:
    -c, --command "CMD"     Commande à exécuter sur l'hôte distant
    --test-transfer         Test de transfert de fichiers (SCP/SFTP)
    --benchmark             Mode benchmark avec mesures détaillées
    --full-diagnostic       Diagnostic complet (config, réseau, SSH)
    
OPTIONS D'AFFICHAGE:
    -v, --verbose           Mode verbose avec détails des opérations
    -q, --quiet             Mode silencieux (erreurs uniquement)
    --debug                 Mode debug avec traces détaillées
    -h, --help              Affiche cette aide

EXEMPLES:
    # Test de base
    $(basename "$0") server.com
    
    # Test avec utilisateur et port spécifiques
    $(basename "$0") --user admin --port 2222 192.168.1.100
    
    # Test avec clé spécifique et commande distante
    $(basename "$0") --identity ~/.ssh/id_rsa --command "uptime" server.com
    
    # Diagnostic complet avec benchmark
    $(basename "$0") --full-diagnostic --benchmark --test-transfer server.com
    
    # Test rapide silencieux
    $(basename "$0") --quiet --timeout 5 server.com

SORTIE JSON:
    {
        "status": "success|error",
        "timestamp": "ISO8601",
        "script": "$SCRIPT_NAME",
        "data": {
            "target": {
                "host": "hostname",
                "port": number,
                "user": "username"
            },
            "network_tests": {
                "ping_reachable": boolean,
                "ping_avg_time": "ms",
                "port_open": boolean,
                "dns_resolution": boolean
            },
            "ssh_connection": {
                "status": "success|failed|timeout",
                "connection_time": "seconds",
                "auth_method": "publickey|password|none",
                "server_version": "string",
                "supported_methods": ["list"]
            },
            "remote_tests": {
                "command_execution": {
                    "status": "success|failed",
                    "command": "string",
                    "output": "string",
                    "exit_code": number
                },
                "file_transfer": {
                    "scp_upload": boolean,
                    "scp_download": boolean,
                    "sftp_available": boolean
                }
            },
            "performance": {
                "connection_latency": "ms",
                "throughput_estimate": "KB/s"
            },
            "diagnostic": {
                "ssh_config": {...},
                "detected_issues": ["list"],
                "recommendations": ["list"]
            }
        }
    }

CODES DE RETOUR:
    0 : Succès - Connexion SSH fonctionnelle
    1 : Erreur de paramètres
    2 : Hôte inaccessible (réseau)
    3 : Port SSH fermé ou filtré
    4 : Échec d'authentification SSH
    5 : Erreur d'exécution de commande distante
    6 : Erreur de transfert de fichiers

TESTS EFFECTUÉS:
    1. Résolution DNS du nom d'hôte
    2. Test de connectivité réseau (ping)
    3. Vérification d'ouverture du port SSH
    4. Tentative de connexion SSH
    5. Validation de l'authentification
    6. Test d'exécution de commande (optionnel)
    7. Test de transfert de fichiers (optionnel)
    8. Mesures de performance (optionnel)

DIAGNOSTIC AVANCÉ:
    - Analyse de la configuration SSH locale
    - Détection des problèmes courants
    - Suggestions d'optimisation
    - Informations sur le serveur distant

CONFORMITÉ:
    - Méthodologie AtomicOps-Suite Niveau 0 (Atomique)
    - Sortie JSON standardisée
    - Gestion d'erreurs robuste avec codes spécifiques
EOF
}

# === FONCTIONS DE LOGGING ===
log_debug() { [[ "$DEBUG_MODE" == true ]] && echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_info() { [[ "$QUIET_MODE" == false ]] && echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_verbose() { [[ "$VERBOSE_MODE" == true ]] && echo "[VERBOSE] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }

# === VALIDATION DES PARAMÈTRES ===
validate_parameters() {
    local errors=0
    
    # Validation de l'hôte cible obligatoire
    if [[ -z "$TARGET_HOST" ]]; then
        log_error "Hôte cible obligatoire"
        ((errors++))
    fi
    
    # Validation du port
    if [[ ! "$TARGET_PORT" =~ ^[0-9]+$ ]] || [[ "$TARGET_PORT" -lt 1 ]] || [[ "$TARGET_PORT" -gt 65535 ]]; then
        log_error "Port invalide : $TARGET_PORT (doit être entre 1 et 65535)"
        ((errors++))
    fi
    
    # Validation du timeout
    if [[ ! "$CONNECTION_TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$CONNECTION_TIMEOUT" -lt 1 ]]; then
        log_error "Timeout invalide : $CONNECTION_TIMEOUT (doit être >= 1)"
        ((errors++))
    fi
    
    # Validation du fichier de clé si spécifié
    if [[ -n "$SSH_KEY_FILE" ]]; then
        if [[ ! -f "$SSH_KEY_FILE" ]]; then
            log_error "Fichier de clé non trouvé : $SSH_KEY_FILE"
            ((errors++))
        elif [[ ! -r "$SSH_KEY_FILE" ]]; then
            log_error "Fichier de clé non lisible : $SSH_KEY_FILE"
            ((errors++))
        fi
    fi
    
    # Validation de l'utilisateur
    if [[ -z "$TARGET_USER" ]]; then
        log_error "Nom d'utilisateur obligatoire"
        ((errors++))
    fi
    
    return $errors
}

# === TEST DE RÉSOLUTION DNS ===
test_dns_resolution() {
    log_verbose "Test de résolution DNS pour $TARGET_HOST"
    
    local dns_result="unknown"
    local resolved_ip=""
    
    if command -v nslookup >/dev/null 2>&1; then
        if resolved_ip=$(nslookup "$TARGET_HOST" 2>/dev/null | awk '/^Address: / { print $2; exit }' | grep -v '#'); then
            dns_result="success"
            log_debug "DNS résolu: $TARGET_HOST -> $resolved_ip"
        else
            dns_result="failed"
            log_debug "Échec de résolution DNS pour $TARGET_HOST"
        fi
    elif command -v dig >/dev/null 2>&1; then
        if resolved_ip=$(dig +short "$TARGET_HOST" 2>/dev/null | head -n1); then
            [[ -n "$resolved_ip" ]] && dns_result="success" || dns_result="failed"
        else
            dns_result="failed"
        fi
    else
        dns_result="no_tools"
        log_debug "Outils DNS (nslookup/dig) non disponibles"
    fi
    
    echo "{\"status\": \"$dns_result\", \"resolved_ip\": \"$resolved_ip\"}" > /tmp/dns_result_$$
    
    return 0
}

# === TEST DE CONNECTIVITÉ RÉSEAU ===
test_network_connectivity() {
    log_verbose "Test de connectivité réseau vers $TARGET_HOST"
    
    local ping_reachable="false"
    local ping_avg_time="0"
    local port_open="false"
    
    # Test ping si disponible
    if command -v ping >/dev/null 2>&1; then
        log_debug "Test ping vers $TARGET_HOST"
        
        local ping_output
        if ping_output=$(ping -c 3 -W "$CONNECTION_TIMEOUT" "$TARGET_HOST" 2>/dev/null); then
            ping_reachable="true"
            
            # Extraction du temps moyen (différent selon l'OS)
            if echo "$ping_output" | grep -q "rtt min/avg/max"; then
                # Linux
                ping_avg_time=$(echo "$ping_output" | grep "rtt min/avg/max" | cut -d'/' -f5)
            elif echo "$ping_output" | grep -q "Average"; then
                # Windows
                ping_avg_time=$(echo "$ping_output" | grep "Average" | sed 's/.*= *\([0-9]*\)ms/\1/')
            fi
            
            log_debug "Ping réussi - temps moyen: ${ping_avg_time}ms"
        else
            log_debug "Ping échoué vers $TARGET_HOST"
        fi
    fi
    
    # Test d'ouverture du port SSH
    log_debug "Test d'ouverture du port $TARGET_PORT sur $TARGET_HOST"
    
    if command -v nc >/dev/null 2>&1; then
        # Utilisation de netcat
        if timeout "$CONNECTION_TIMEOUT" nc -z "$TARGET_HOST" "$TARGET_PORT" 2>/dev/null; then
            port_open="true"
            log_debug "Port $TARGET_PORT ouvert"
        else
            log_debug "Port $TARGET_PORT fermé ou filtré"
        fi
    elif command -v telnet >/dev/null 2>&1; then
        # Utilisation de telnet comme fallback
        if timeout "$CONNECTION_TIMEOUT" bash -c "echo '' | telnet $TARGET_HOST $TARGET_PORT" 2>/dev/null | grep -q "Connected"; then
            port_open="true"
            log_debug "Port $TARGET_PORT ouvert (telnet)"
        else
            log_debug "Port $TARGET_PORT inaccessible (telnet)"
        fi
    elif [[ -e /dev/tcp ]]; then
        # Utilisation des pseudo-fichiers bash
        if timeout "$CONNECTION_TIMEOUT" bash -c "exec 3<>/dev/tcp/$TARGET_HOST/$TARGET_PORT" 2>/dev/null; then
            exec 3>&-
            port_open="true"
            log_debug "Port $TARGET_PORT ouvert (/dev/tcp)"
        else
            log_debug "Port $TARGET_PORT inaccessible (/dev/tcp)"
        fi
    fi
    
    # Stockage des résultats
    cat << EOF > /tmp/network_result_$$
{
    "ping_reachable": $ping_reachable,
    "ping_avg_time": "$ping_avg_time",
    "port_open": $port_open
}
EOF
    
    return 0
}

# === TEST DE CONNEXION SSH ===
test_ssh_connection() {
    log_verbose "Test de connexion SSH vers $TARGET_USER@$TARGET_HOST:$TARGET_PORT"
    
    local connection_start=$(date +%s.%N)
    local ssh_status="failed"
    local auth_method="unknown"
    local server_version=""
    local connection_time="0"
    
    # Construction des options SSH
    local ssh_options=(
        "-o" "ConnectTimeout=$CONNECTION_TIMEOUT"
        "-o" "BatchMode=yes"
        "-o" "StrictHostKeyChecking=no"
        "-o" "UserKnownHostsFile=/dev/null"
        "-o" "LogLevel=ERROR"
        "-p" "$TARGET_PORT"
    )
    
    # Ajout de la clé privée si spécifiée
    if [[ -n "$SSH_KEY_FILE" ]]; then
        ssh_options+=("-i" "$SSH_KEY_FILE")
    fi
    
    log_debug "Tentative de connexion SSH avec options: ${ssh_options[*]}"
    
    # Test de connexion SSH avec extraction d'informations
    local ssh_output
    if ssh_output=$(ssh "${ssh_options[@]}" "$TARGET_USER@$TARGET_HOST" "echo 'SSH_CONNECTION_SUCCESS'" 2>&1); then
        local connection_end=$(date +%s.%N)
        connection_time=$(echo "$connection_end - $connection_start" | bc -l 2>/dev/null || echo "0.00")
        
        if echo "$ssh_output" | grep -q "SSH_CONNECTION_SUCCESS"; then
            ssh_status="success"
            auth_method="publickey"
            log_debug "Connexion SSH réussie en ${connection_time}s"
        else
            ssh_status="failed"
            log_debug "Connexion SSH échouée: $ssh_output"
        fi
    else
        local connection_end=$(date +%s.%N)
        connection_time=$(echo "$connection_end - $connection_start" | bc -l 2>/dev/null || echo "0.00")
        
        # Analyse de l'erreur pour déterminer le type d'échec
        if echo "$ssh_output" | grep -qi "timeout"; then
            ssh_status="timeout"
        elif echo "$ssh_output" | grep -qi "permission denied"; then
            ssh_status="auth_failed"
        elif echo "$ssh_output" | grep -qi "connection refused"; then
            ssh_status="connection_refused"
        else
            ssh_status="failed"
        fi
        
        log_debug "Échec de connexion SSH ($ssh_status) en ${connection_time}s: $ssh_output"
    fi
    
    # Tentative d'extraction de la version du serveur SSH
    local version_output
    if version_output=$(ssh "${ssh_options[@]}" -V "$TARGET_USER@$TARGET_HOST" 2>&1 | head -n1); then
        server_version=$(echo "$version_output" | grep -oE 'OpenSSH_[0-9]+\.[0-9]+' || echo "unknown")
    fi
    
    # Stockage des résultats
    cat << EOF > /tmp/ssh_result_$$
{
    "status": "$ssh_status",
    "connection_time": "$connection_time",
    "auth_method": "$auth_method",
    "server_version": "$server_version",
    "raw_output": "$ssh_output"
}
EOF
    
    return 0
}

# === TEST D'EXÉCUTION DE COMMANDE DISTANTE ===
test_remote_command() {
    local test_cmd="$1"
    
    if [[ -z "$test_cmd" ]]; then
        echo '{"status": "skipped"}' > /tmp/command_result_$$
        return 0
    fi
    
    log_verbose "Test d'exécution de commande distante: $test_cmd"
    
    local ssh_options=(
        "-o" "ConnectTimeout=$CONNECTION_TIMEOUT"
        "-o" "BatchMode=yes"
        "-o" "StrictHostKeyChecking=no"
        "-o" "UserKnownHostsFile=/dev/null"
        "-o" "LogLevel=ERROR"
        "-p" "$TARGET_PORT"
    )
    
    [[ -n "$SSH_KEY_FILE" ]] && ssh_options+=("-i" "$SSH_KEY_FILE")
    
    local cmd_start=$(date +%s.%N)
    local cmd_output
    local cmd_exit_code=0
    
    if cmd_output=$(ssh "${ssh_options[@]}" "$TARGET_USER@$TARGET_HOST" "$test_cmd" 2>&1); then
        local cmd_end=$(date +%s.%N)
        local cmd_duration=$(echo "$cmd_end - $cmd_start" | bc -l 2>/dev/null || echo "0.00")
        
        log_debug "Commande distante exécutée avec succès en ${cmd_duration}s"
        
        cat << EOF > /tmp/command_result_$$
{
    "status": "success",
    "command": "$test_cmd",
    "output": "$cmd_output",
    "exit_code": 0,
    "duration": "$cmd_duration"
}
EOF
    else
        cmd_exit_code=$?
        local cmd_end=$(date +%s.%N)
        local cmd_duration=$(echo "$cmd_end - $cmd_start" | bc -l 2>/dev/null || echo "0.00")
        
        log_debug "Échec d'exécution de commande distante (code: $cmd_exit_code) en ${cmd_duration}s"
        
        cat << EOF > /tmp/command_result_$$
{
    "status": "failed",
    "command": "$test_cmd",
    "output": "$cmd_output",
    "exit_code": $cmd_exit_code,
    "duration": "$cmd_duration"
}
EOF
    fi
    
    return 0
}

# === TEST DE TRANSFERT DE FICHIERS ===
test_file_transfer() {
    if [[ "$TEST_FILE_TRANSFER" == false ]]; then
        echo '{"scp_upload": false, "scp_download": false, "sftp_available": false}' > /tmp/transfer_result_$$
        return 0
    fi
    
    log_verbose "Test de transfert de fichiers (SCP/SFTP)"
    
    local scp_upload="false"
    local scp_download="false"
    local sftp_available="false"
    
    # Création d'un fichier de test temporaire
    local test_file=$(mktemp)
    echo "SSH_CONNECTION_TEST_$(date +%s)" > "$test_file"
    local test_filename="ssh_test_$(date +%s).tmp"
    
    local scp_options=(
        "-o" "ConnectTimeout=$CONNECTION_TIMEOUT"
        "-o" "BatchMode=yes"
        "-o" "StrictHostKeyChecking=no"
        "-o" "UserKnownHostsFile=/dev/null"
        "-o" "LogLevel=ERROR"
        "-P" "$TARGET_PORT"
    )
    
    [[ -n "$SSH_KEY_FILE" ]] && scp_options+=("-i" "$SSH_KEY_FILE")
    
    # Test SCP upload
    log_debug "Test SCP upload"
    if scp "${scp_options[@]}" "$test_file" "$TARGET_USER@$TARGET_HOST:/tmp/$test_filename" 2>/dev/null; then
        scp_upload="true"
        log_debug "SCP upload réussi"
        
        # Test SCP download
        log_debug "Test SCP download"
        local download_file=$(mktemp)
        if scp "${scp_options[@]}" "$TARGET_USER@$TARGET_HOST:/tmp/$test_filename" "$download_file" 2>/dev/null; then
            scp_download="true"
            log_debug "SCP download réussi"
        fi
        rm -f "$download_file"
        
        # Nettoyage du fichier distant
        ssh "${ssh_options[@]}" "$TARGET_USER@$TARGET_HOST" "rm -f /tmp/$test_filename" 2>/dev/null || true
    fi
    
    # Test SFTP
    log_debug "Test disponibilité SFTP"
    local sftp_options=(
        "-o" "ConnectTimeout=$CONNECTION_TIMEOUT"
        "-o" "BatchMode=yes"
        "-o" "StrictHostKeyChecking=no"
        "-o" "UserKnownHostsFile=/dev/null"
        "-o" "LogLevel=ERROR"
        "-P" "$TARGET_PORT"
    )
    
    [[ -n "$SSH_KEY_FILE" ]] && sftp_options+=("-i" "$SSH_KEY_FILE")
    
    if echo "pwd" | sftp "${sftp_options[@]}" "$TARGET_USER@$TARGET_HOST" 2>/dev/null | grep -q "Remote working directory"; then
        sftp_available="true"
        log_debug "SFTP disponible"
    fi
    
    rm -f "$test_file"
    
    # Stockage des résultats
    cat << EOF > /tmp/transfer_result_$$
{
    "scp_upload": $scp_upload,
    "scp_download": $scp_download,
    "sftp_available": $sftp_available
}
EOF
    
    return 0
}

# === MESURES DE PERFORMANCE ===
measure_performance() {
    if [[ "$BENCHMARK_MODE" == false ]]; then
        echo '{"connection_latency": "0", "throughput_estimate": "0"}' > /tmp/performance_result_$$
        return 0
    fi
    
    log_verbose "Mesures de performance SSH"
    
    local connection_latency="0"
    local throughput_estimate="0"
    
    local ssh_options=(
        "-o" "ConnectTimeout=$CONNECTION_TIMEOUT"
        "-o" "BatchMode=yes"
        "-o" "StrictHostKeyChecking=no"
        "-o" "UserKnownHostsFile=/dev/null"
        "-o" "LogLevel=ERROR"
        "-p" "$TARGET_PORT"
    )
    
    [[ -n "$SSH_KEY_FILE" ]] && ssh_options+=("-i" "$SSH_KEY_FILE")
    
    # Mesure de latence (multiple connexions)
    log_debug "Mesure de latence de connexion"
    local total_time=0
    local successful_connections=0
    
    for i in {1..3}; do
        local start_time=$(date +%s.%N)
        if ssh "${ssh_options[@]}" "$TARGET_USER@$TARGET_HOST" "true" 2>/dev/null; then
            local end_time=$(date +%s.%N)
            local conn_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            total_time=$(echo "$total_time + $conn_time" | bc -l 2>/dev/null || echo "$total_time")
            ((successful_connections++))
        fi
    done
    
    if [[ $successful_connections -gt 0 ]]; then
        connection_latency=$(echo "scale=3; $total_time / $successful_connections * 1000" | bc -l 2>/dev/null || echo "0")
    fi
    
    # Estimation du débit (transfert de test)
    log_debug "Estimation du débit de transfert"
    local test_data=$(mktemp)
    dd if=/dev/zero of="$test_data" bs=1024 count=100 2>/dev/null || true
    
    if [[ -s "$test_data" ]]; then
        local transfer_start=$(date +%s.%N)
        if scp -q "${scp_options[@]}" "$test_data" "$TARGET_USER@$TARGET_HOST:/tmp/ssh_perf_test" 2>/dev/null; then
            local transfer_end=$(date +%s.%N)
            local transfer_time=$(echo "$transfer_end - $transfer_start" | bc -l 2>/dev/null || echo "1")
            local file_size=$(stat -f%z "$test_data" 2>/dev/null || stat -c%s "$test_data" 2>/dev/null || echo "102400")
            
            throughput_estimate=$(echo "scale=0; $file_size / $transfer_time / 1024" | bc -l 2>/dev/null || echo "0")
            
            # Nettoyage du fichier distant
            ssh "${ssh_options[@]}" "$TARGET_USER@$TARGET_HOST" "rm -f /tmp/ssh_perf_test" 2>/dev/null || true
        fi
    fi
    
    rm -f "$test_data"
    
    # Stockage des résultats
    cat << EOF > /tmp/performance_result_$$
{
    "connection_latency": "$connection_latency",
    "throughput_estimate": "$throughput_estimate"
}
EOF
    
    return 0
}

# === DIAGNOSTIC COMPLET ===
run_full_diagnostic() {
    if [[ "$FULL_DIAGNOSTIC" == false ]]; then
        echo '{"ssh_config": {}, "detected_issues": [], "recommendations": []}' > /tmp/diagnostic_result_$$
        return 0
    fi
    
    log_verbose "Diagnostic complet SSH et réseau"
    
    local detected_issues=()
    local recommendations=()
    local ssh_config="{}"
    
    # Analyse de la configuration SSH locale
    log_debug "Analyse de la configuration SSH"
    for config_file in "${SSH_CONFIG_PATHS[@]}"; do
        if [[ -f "$config_file" ]]; then
            log_debug "Configuration trouvée: $config_file"
            # Extraction de paramètres clés (simplifiée)
            ssh_config="{\"config_file\": \"$config_file\", \"exists\": true}"
            break
        fi
    done
    
    # Vérification des résultats précédents pour détecter les problèmes
    local dns_status=$(cat /tmp/dns_result_$$ 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unknown")
    local network_result=$(cat /tmp/network_result_$$ 2>/dev/null || echo '{}')
    local ssh_result=$(cat /tmp/ssh_result_$$ 2>/dev/null || echo '{}')
    
    # Analyse des problèmes DNS
    if [[ "$dns_status" == "failed" ]]; then
        detected_issues+=("\"DNS resolution failed\"")
        recommendations+=("\"Check DNS configuration or use IP address\"")
    fi
    
    # Analyse des problèmes réseau
    local ping_reachable=$(echo "$network_result" | jq -r '.ping_reachable' 2>/dev/null || echo "false")
    local port_open=$(echo "$network_result" | jq -r '.port_open' 2>/dev/null || echo "false")
    
    if [[ "$ping_reachable" == "false" ]]; then
        detected_issues+=("\"Host not reachable via ping\"")
        recommendations+=("\"Check network connectivity and firewall rules\"")
    fi
    
    if [[ "$port_open" == "false" ]]; then
        detected_issues+=("\"SSH port not accessible\"")
        recommendations+=("\"Verify SSH service is running and port is correct\"")
    fi
    
    # Analyse des problèmes SSH
    local ssh_status=$(echo "$ssh_result" | jq -r '.status' 2>/dev/null || echo "failed")
    
    if [[ "$ssh_status" == "auth_failed" ]]; then
        detected_issues+=("\"SSH authentication failed\"")
        recommendations+=("\"Check SSH key or password, verify authorized_keys\"")
    elif [[ "$ssh_status" == "timeout" ]]; then
        detected_issues+=("\"SSH connection timeout\"")
        recommendations+=("\"Increase timeout value or check network latency\"")
    fi
    
    # Recommandations de performance
    local connection_time=$(echo "$ssh_result" | jq -r '.connection_time' 2>/dev/null || echo "0")
    if (( $(echo "$connection_time > 5" | bc -l 2>/dev/null) )); then
        detected_issues+=("\"Slow SSH connection\"")
        recommendations+=("\"Consider SSH connection multiplexing or compression\"")
    fi
    
    # Construction du JSON de diagnostic
    local issues_json="[$(IFS=,; echo "${detected_issues[*]}")]"
    local recommendations_json="[$(IFS=,; echo "${recommendations[*]}")]"
    
    cat << EOF > /tmp/diagnostic_result_$$
{
    "ssh_config": $ssh_config,
    "detected_issues": $issues_json,
    "recommendations": $recommendations_json
}
EOF
    
    return 0
}

# === GÉNÉRATION DE LA SORTIE JSON ===
generate_output() {
    # Lecture des résultats de tous les tests
    local dns_result=$(cat /tmp/dns_result_$$ 2>/dev/null || echo '{"status": "unknown", "resolved_ip": ""}')
    local network_result=$(cat /tmp/network_result_$$ 2>/dev/null || echo '{"ping_reachable": false, "ping_avg_time": "0", "port_open": false}')
    local ssh_result=$(cat /tmp/ssh_result_$$ 2>/dev/null || echo '{"status": "failed", "connection_time": "0", "auth_method": "unknown", "server_version": ""}')
    local command_result=$(cat /tmp/command_result_$$ 2>/dev/null || echo '{"status": "skipped"}')
    local transfer_result=$(cat /tmp/transfer_result_$$ 2>/dev/null || echo '{"scp_upload": false, "scp_download": false, "sftp_available": false}')
    local performance_result=$(cat /tmp/performance_result_$$ 2>/dev/null || echo '{"connection_latency": "0", "throughput_estimate": "0"}')
    local diagnostic_result=$(cat /tmp/diagnostic_result_$$ 2>/dev/null || echo '{"ssh_config": {}, "detected_issues": [], "recommendations": []}')
    
    # Ajout des informations DNS au résultat réseau
    local dns_status=$(echo "$dns_result" | jq -r '.status' 2>/dev/null || echo "unknown")
    local enhanced_network=$(echo "$network_result" | jq --arg dns_status "$dns_status" '. + {"dns_resolution": ($dns_status == "success")}' 2>/dev/null || echo "$network_result")
    
    cat << EOF
{
    "status": "success",
    "timestamp": "$(date -Iseconds)",
    "script": "$SCRIPT_NAME",
    "version": "$SCRIPT_VERSION",
    "data": {
        "target": {
            "host": "$TARGET_HOST",
            "port": $TARGET_PORT,
            "user": "$TARGET_USER"
        },
        "network_tests": $enhanced_network,
        "ssh_connection": $ssh_result,
        "remote_tests": {
            "command_execution": $command_result,
            "file_transfer": $transfer_result
        },
        "performance": $performance_result,
        "diagnostic": $diagnostic_result
    }
}
EOF
}

# === NETTOYAGE DES FICHIERS TEMPORAIRES ===
cleanup() {
    rm -f /tmp/dns_result_$$ /tmp/network_result_$$ /tmp/ssh_result_$$ /tmp/command_result_$$ /tmp/transfer_result_$$ /tmp/performance_result_$$ /tmp/diagnostic_result_$$ 2>/dev/null || true
}

# === GESTION DES ARGUMENTS ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--port)
                TARGET_PORT="$2"
                shift 2
                ;;
            -u|--user)
                TARGET_USER="$2"
                shift 2
                ;;
            -i|--identity)
                SSH_KEY_FILE="$2"
                shift 2
                ;;
            -t|--timeout)
                CONNECTION_TIMEOUT="$2"
                shift 2
                ;;
            -c|--command)
                TEST_COMMAND="$2"
                shift 2
                ;;
            --test-transfer)
                TEST_FILE_TRANSFER=true
                shift
                ;;
            --benchmark)
                BENCHMARK_MODE=true
                shift
                ;;
            --full-diagnostic)
                FULL_DIAGNOSTIC=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
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
            -*)
                log_error "Option inconnue : $1"
                show_help >&2
                exit 1
                ;;
            *)
                if [[ -z "$TARGET_HOST" ]]; then
                    TARGET_HOST="$1"
                else
                    log_error "Argument en trop : $1"
                    show_help >&2
                    exit 1
                fi
                shift
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
    
    log_debug "Début du test SSH pour $TARGET_USER@$TARGET_HOST:$TARGET_PORT"
    
    # Séquence complète de tests
    log_info "Test de connectivité SSH vers $TARGET_HOST"
    
    # 1. Test de résolution DNS
    if ! test_dns_resolution; then
        log_error "Échec du test DNS"
        exit 2
    fi
    
    # 2. Tests de connectivité réseau
    if ! test_network_connectivity; then
        log_error "Échec des tests réseau"
        exit 2
    fi
    
    # Vérification que le port SSH est accessible
    local port_status=$(cat /tmp/network_result_$$ | jq -r '.port_open' 2>/dev/null || echo "false")
    if [[ "$port_status" == "false" ]]; then
        log_error "Port SSH $TARGET_PORT inaccessible sur $TARGET_HOST"
        exit 3
    fi
    
    # 3. Test de connexion SSH
    if ! test_ssh_connection; then
        log_error "Échec du test de connexion SSH"
        exit 4
    fi
    
    # Vérification du statut de connexion SSH
    local ssh_status=$(cat /tmp/ssh_result_$$ | jq -r '.status' 2>/dev/null || echo "failed")
    case "$ssh_status" in
        "auth_failed")
            log_error "Échec d'authentification SSH"
            exit 4
            ;;
        "timeout"|"connection_refused"|"failed")
            log_error "Connexion SSH échouée ($ssh_status)"
            exit 4
            ;;
    esac
    
    # 4. Test d'exécution de commande (optionnel)
    if ! test_remote_command "$TEST_COMMAND"; then
        log_error "Échec du test de commande distante"
    fi
    
    # 5. Test de transfert de fichiers (optionnel)
    if ! test_file_transfer; then
        log_error "Échec du test de transfert de fichiers"
    fi
    
    # 6. Mesures de performance (optionnel)
    if ! measure_performance; then
        log_error "Échec des mesures de performance"
    fi
    
    # 7. Diagnostic complet (optionnel)
    if ! run_full_diagnostic; then
        log_error "Échec du diagnostic complet"
    fi
    
    # Génération du rapport final
    generate_output
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.00")
    
    log_debug "Test SSH terminé en ${duration}s"
    log_info "Connexion SSH fonctionnelle vers $TARGET_HOST"
    
    return 0
}

# Point d'entrée du script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi