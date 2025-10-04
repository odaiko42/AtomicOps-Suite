#!/bin/bash
#
# Bibliothèque: ct-common.sh  
# Description: Fonctions communes spécifiques aux scripts de gestion des containers Proxmox
# Usage: source "$PROJECT_ROOT/lib/ct-common.sh"
#

# Vérification que la bibliothèque n'est chargée qu'une fois
[[ "${CT_COMMON_LIB_LOADED:-}" == "1" ]] && return 0
readonly CT_COMMON_LIB_LOADED=1

# Charger les dépendances
if [[ "${COMMON_LIB_LOADED:-}" != "1" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    source "$PROJECT_ROOT/lib/common.sh"
fi

if [[ "${LOGGER_LIB_LOADED:-}" != "1" ]]; then
    source "$PROJECT_ROOT/lib/logger.sh"
fi

if [[ "${VALIDATOR_LIB_LOADED:-}" != "1" ]]; then
    source "$PROJECT_ROOT/lib/validator.sh"
fi

# Configuration par défaut pour les containers
readonly DEFAULT_TEMPLATE_STORAGE="local"
readonly DEFAULT_ROOTFS_STORAGE="local-lvm"
readonly DEFAULT_NETWORK_BRIDGE="vmbr0"
readonly DEFAULT_DISK_SIZE_GB="8"
readonly DEFAULT_MEMORY_MB="512"
readonly DEFAULT_SWAP_MB="512"
readonly DEFAULT_CORES="1"

# Fonction : Trouver un CTID libre
pick_free_ctid() {
    local start_ctid="${1:-100}"
    local max_ctid="${2:-999}"
    
    ct_info "Looking for free container ID starting from $start_ctid"
    
    # Vérifier que pct est disponible
    if ! command_exists pct; then
        ct_error "Proxmox pct command not found"
        return $EXIT_ERROR_DEPENDENCY
    fi
    
    local ctid
    for ctid in $(seq "$start_ctid" "$max_ctid"); do
        if ! pct list | grep -q "^$ctid "; then
            ct_info "Found free container ID: $ctid"
            echo "$ctid"
            return 0
        fi
    done
    
    ct_error "No free container ID found between $start_ctid and $max_ctid"
    return $EXIT_ERROR_NOT_FOUND
}

# Fonction : Trouver le template Debian 12 le plus récent
find_debian12_template() {
    local template_storage="${1:-$DEFAULT_TEMPLATE_STORAGE}"
    
    ct_info "Looking for Debian 12 template in storage: $template_storage"
    
    if ! command_exists pveam; then
        ct_error "Proxmox pveam command not found"
        return $EXIT_ERROR_DEPENDENCY
    fi
    
    # Chercher les templates Debian 12
    local template_ref
    template_ref=$(pveam list "$template_storage" | grep -E "debian-12.*standard" | head -1 | awk '{print $2}')
    
    if [[ -z "$template_ref" ]]; then
        ct_warn "No Debian 12 template found, downloading latest"
        
        # Télécharger le template le plus récent
        local latest_template
        latest_template=$(pveam available | grep -E "debian-12.*standard" | head -1 | awk '{print $2}')
        
        if [[ -z "$latest_template" ]]; then
            ct_error "No Debian 12 template available for download"
            return $EXIT_ERROR_NOT_FOUND
        fi
        
        ct_info "Downloading template: $latest_template"
        if ! pveam download "$template_storage" "$latest_template"; then
            ct_error "Failed to download template: $latest_template"
            return $EXIT_ERROR_GENERAL
        fi
        
        template_ref="$template_storage:vztmpl/$latest_template"
    else
        template_ref="$template_storage:vztmpl/$template_ref"
    fi
    
    ct_info "Using template: $template_ref"
    echo "$template_ref"
    return 0
}

# Fonction : Créer un container avec configuration de base
create_basic_ct() {
    local ctid="$1"
    local template_ref="$2"
    local hostname="${3:-ct$ctid}"
    local rootfs_storage="${4:-$DEFAULT_ROOTFS_STORAGE}"
    local disk_gb="${5:-$DEFAULT_DISK_SIZE_GB}"
    local memory_mb="${6:-$DEFAULT_MEMORY_MB}"
    local swap_mb="${7:-$DEFAULT_SWAP_MB}"
    local cores="${8:-$DEFAULT_CORES}"
    local network_bridge="${9:-$DEFAULT_NETWORK_BRIDGE}"
    
    ct_info "Creating container $ctid with hostname $hostname"
    
    # Valider les paramètres
    validate_ctid "$ctid" || return $?
    validate_hostname "$hostname" || return $?
    validate_disk_size "${disk_gb}G" || return $?
    
    # Construire la commande pct create
    local pct_cmd=(
        pct create "$ctid" "$template_ref"
        --hostname "$hostname"
        --rootfs "$rootfs_storage:${disk_gb}"
        --memory "$memory_mb"
        --swap "$swap_mb"
        --cores "$cores"
        --net0 "name=eth0,bridge=$network_bridge,firewall=1,ip=dhcp"
        --onboot 1
        --unprivileged 1
        --features nesting=1
        --start 0
    )
    
    ct_info "Executing: ${pct_cmd[*]}"
    
    if "${pct_cmd[@]}"; then
        ct_info "Container $ctid created successfully"
        return 0
    else
        ct_error "Failed to create container $ctid"
        return $EXIT_ERROR_GENERAL
    fi
}

# Fonction : Démarrer un container et attendre qu'il soit prêt
start_and_wait_ct() {
    local ctid="$1"
    local timeout_seconds="${2:-300}"
    
    ct_info "Starting container $ctid"
    
    if ! pct start "$ctid"; then
        ct_error "Failed to start container $ctid"
        return $EXIT_ERROR_GENERAL
    fi
    
    ct_info "Waiting for container $ctid to be ready (timeout: ${timeout_seconds}s)"
    
    local elapsed=0
    while [[ $elapsed -lt $timeout_seconds ]]; do
        if pct exec "$ctid" -- systemctl is-system-running --wait 2>/dev/null | grep -qE "(running|degraded)"; then
            ct_info "Container $ctid is ready"
            return 0
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
        
        if [[ $((elapsed % 30)) -eq 0 ]]; then
            ct_info "Still waiting for container $ctid... (${elapsed}s elapsed)"
        fi
    done
    
    ct_error "Timeout waiting for container $ctid to be ready"
    return $EXIT_ERROR_TIMEOUT
}

# Fonction : Bootstrap de base à l'intérieur du container
bootstrap_base_inside() {
    local ctid="$1"
    
    ct_info "Bootstrapping base configuration for container $ctid"
    
    # Mettre à jour le système
    ct_info "Updating package lists"
    if ! pct exec "$ctid" -- apt-get update; then
        ct_error "Failed to update package lists"
        return $EXIT_ERROR_GENERAL
    fi
    
    # Installer les packages de base
    local base_packages=(
        "curl" "wget" "nano" "vim-tiny" "htop" "tree" "jq" "bash-completion"
        "sudo" "openssh-server" "ca-certificates" "gnupg" "lsb-release"
    )
    
    ct_info "Installing base packages: ${base_packages[*]}"
    if ! pct exec "$ctid" -- apt-get install -y "${base_packages[@]}"; then
        ct_error "Failed to install base packages"
        return $EXIT_ERROR_GENERAL
    fi
    
    # Configuration timezone
    ct_info "Configuring timezone"
    pct exec "$ctid" -- timedatectl set-timezone Europe/Paris 2>/dev/null || true
    
    # Configuration locale
    ct_info "Configuring locale"
    pct exec "$ctid" -- locale-gen en_US.UTF-8 2>/dev/null || true
    
    ct_info "Base bootstrap completed for container $ctid"
    return 0
}

# Fonction : Installer Docker dans le container
install_docker_inside() {
    local ctid="$1"
    
    ct_info "Installing Docker in container $ctid"
    
    # Prérequis pour Docker
    pct exec "$ctid" -- apt-get update
    pct exec "$ctid" -- apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Ajouter la clé GPG de Docker
    ct_info "Adding Docker GPG key"
    pct exec "$ctid" -- bash -c "curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
    
    # Ajouter le repository Docker
    ct_info "Adding Docker repository"
    pct exec "$ctid" -- bash -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list'
    
    # Installer Docker
    pct exec "$ctid" -- apt-get update
    pct exec "$ctid" -- apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Démarrer et activer Docker
    pct exec "$ctid" -- systemctl start docker
    pct exec "$ctid" -- systemctl enable docker
    
    # Vérifier l'installation
    if pct exec "$ctid" -- docker --version; then
        ct_info "Docker installed successfully in container $ctid"
        return 0
    else
        ct_error "Docker installation failed in container $ctid"
        return $EXIT_ERROR_GENERAL
    fi
}

# Fonction : Créer un utilisateur non-root avec sudo
create_user_inside() {
    local ctid="$1"
    local username="$2"
    local password="${3:-$(openssl rand -base64 12)}"
    
    ct_info "Creating user $username in container $ctid"
    
    # Créer l'utilisateur
    pct exec "$ctid" -- useradd -m -s /bin/bash "$username"
    
    # Définir le mot de passe
    pct exec "$ctid" -- bash -c "echo '$username:$password' | chpasswd"
    
    # Ajouter aux groupes sudo et docker (si disponible)
    pct exec "$ctid" -- usermod -aG sudo "$username"
    if pct exec "$ctid" -- getent group docker >/dev/null 2>&1; then
        pct exec "$ctid" -- usermod -aG docker "$username"
    fi
    
    ct_info "User $username created with password: $password"
    return 0
}

# Fonction : Copier des fichiers vers le container
copy_to_ct() {
    local ctid="$1"
    local source_path="$2"
    local dest_path="$3"
    local owner="${4:-root:root}"
    local permissions="${5:-644}"
    
    ct_info "Copying $source_path to container $ctid:$dest_path"
    
    if [[ ! -e "$source_path" ]]; then
        ct_error "Source file/directory does not exist: $source_path"
        return $EXIT_ERROR_NOT_FOUND
    fi
    
    # Utiliser pct push pour copier le fichier
    if ! pct push "$ctid" "$source_path" "$dest_path"; then
        ct_error "Failed to copy $source_path to container $ctid"
        return $EXIT_ERROR_GENERAL
    fi
    
    # Définir le propriétaire et permissions
    pct exec "$ctid" -- chown "$owner" "$dest_path"
    pct exec "$ctid" -- chmod "$permissions" "$dest_path"
    
    ct_info "File copied successfully: $dest_path"
    return 0
}

# Fonction : Exécuter un script à l'intérieur du container
exec_script_inside() {
    local ctid="$1"
    local script_content="$2"
    local script_name="${3:-install-script.sh}"
    
    ct_info "Executing script in container $ctid"
    
    # Créer un fichier temporaire avec le script
    local temp_script="/tmp/${script_name}"
    
    # Copier le script dans le container
    echo "$script_content" | pct exec "$ctid" -- tee "$temp_script" > /dev/null
    pct exec "$ctid" -- chmod +x "$temp_script"
    
    # Exécuter le script
    if pct exec "$ctid" -- "$temp_script"; then
        ct_info "Script executed successfully in container $ctid"
        pct exec "$ctid" -- rm -f "$temp_script"
        return 0
    else
        ct_error "Script execution failed in container $ctid"
        pct exec "$ctid" -- rm -f "$temp_script"
        return $EXIT_ERROR_GENERAL
    fi
}

# Fonction : Obtenir l'adresse IP du container
get_ct_ip() {
    local ctid="$1"
    local timeout_seconds="${2:-60}"
    
    ct_info "Getting IP address for container $ctid"
    
    local elapsed=0
    while [[ $elapsed -lt $timeout_seconds ]]; do
        local ip_address
        ip_address=$(pct exec "$ctid" -- hostname -I 2>/dev/null | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        
        if [[ -n "$ip_address" ]]; then
            ct_info "Container $ctid IP address: $ip_address"
            echo "$ip_address"
            return 0
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    ct_error "Could not retrieve IP address for container $ctid"
    return $EXIT_ERROR_TIMEOUT
}

# Export des fonctions pour utilisation dans les sous-shells
export -f pick_free_ctid
export -f find_debian12_template
export -f create_basic_ct
export -f start_and_wait_ct
export -f bootstrap_base_inside
export -f install_docker_inside
export -f create_user_inside
export -f copy_to_ct
export -f exec_script_inside
export -f get_ct_ip