#!/bin/bash
#
# Bibliothèque: validator.sh
# Description: Système de validation des entrées et prérequis
# Usage: source "$PROJECT_ROOT/lib/validator.sh"
#

# Vérification que la bibliothèque n'est chargée qu'une fois
[[ "${VALIDATOR_LIB_LOADED:-}" == "1" ]] && return 0
readonly VALIDATOR_LIB_LOADED=1

# Charger les dépendances
if [[ "${COMMON_LIB_LOADED:-}" != "1" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    source "$PROJECT_ROOT/lib/common.sh"
fi

if [[ "${LOGGER_LIB_LOADED:-}" != "1" ]]; then
    source "$PROJECT_ROOT/lib/logger.sh"
fi

# Validation des permissions
validate_permissions() {
    local required_user="${1:-root}"
    
    case "$required_user" in
        root)
            if [[ $EUID -ne 0 ]]; then
                log_error "Root privileges required"
                return $EXIT_ERROR_PERMISSION
            fi
            ;;
        user)
            if [[ $EUID -eq 0 ]]; then
                log_warn "Running as root, consider using a regular user"
            fi
            ;;
        *)
            if [[ "$(whoami)" != "$required_user" ]]; then
                log_error "Must be run as user: $required_user"
                return $EXIT_ERROR_PERMISSION
            fi
            ;;
    esac
    
    log_debug "Permission validation passed for: $required_user"
    return 0
}

# Validation des dépendances système
validate_dependencies() {
    local missing_deps=()
    local dep
    
    for dep in "$@"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Install with: apt-get install ${missing_deps[*]} (Debian/Ubuntu)"
        log_info "Or: yum install ${missing_deps[*]} (RHEL/CentOS)"
        return $EXIT_ERROR_DEPENDENCY
    fi
    
    log_debug "All dependencies validated: $*"
    return 0
}

# Validation d'un périphérique bloc
validate_block_device() {
    local device="$1"
    
    if [[ -z "$device" ]]; then
        log_error "Device path cannot be empty"
        return $EXIT_ERROR_VALIDATION
    fi
    
    if [[ ! -b "$device" ]]; then
        log_error "Not a valid block device: $device"
        return $EXIT_ERROR_NOT_FOUND
    fi
    
    # Vérifier que ce n'est pas un disque système critique
    if [[ "$device" =~ ^/dev/(sda|nvme0n1|xvda|vda)$ ]]; then
        log_error "Cannot operate on system disk: $device"
        return $EXIT_ERROR_VALIDATION
    fi
    
    log_debug "Block device validation passed: $device"
    return 0
}

# Validation d'un système de fichiers
validate_filesystem() {
    local filesystem="$1"
    local supported_fs=("ext2" "ext3" "ext4" "xfs" "btrfs" "ntfs" "vfat" "exfat")
    
    if [[ -z "$filesystem" ]]; then
        log_error "Filesystem type cannot be empty"
        return $EXIT_ERROR_VALIDATION
    fi
    
    # Vérifier si le système de fichiers est supporté
    local fs_supported=false
    local fs
    for fs in "${supported_fs[@]}"; do
        if [[ "$filesystem" == "$fs" ]]; then
            fs_supported=true
            break
        fi
    done
    
    if ! $fs_supported; then
        log_error "Unsupported filesystem: $filesystem"
        log_info "Supported filesystems: ${supported_fs[*]}"
        return $EXIT_ERROR_VALIDATION
    fi
    
    # Vérifier si les outils pour ce filesystem sont disponibles
    case "$filesystem" in
        ext2|ext3|ext4)
            if ! command_exists mkfs.ext4; then
                log_error "e2fsprogs package required for ext filesystems"
                return $EXIT_ERROR_DEPENDENCY
            fi
            ;;
        xfs)
            if ! command_exists mkfs.xfs; then
                log_error "xfsprogs package required for XFS"
                return $EXIT_ERROR_DEPENDENCY
            fi
            ;;
        btrfs)
            if ! command_exists mkfs.btrfs; then
                log_error "btrfs-progs package required for BTRFS"
                return $EXIT_ERROR_DEPENDENCY
            fi
            ;;
        ntfs)
            if ! command_exists mkfs.ntfs; then
                log_error "ntfs-3g package required for NTFS"
                return $EXIT_ERROR_DEPENDENCY
            fi
            ;;
        vfat)
            if ! command_exists mkfs.vfat; then
                log_error "dosfstools package required for VFAT"
                return $EXIT_ERROR_DEPENDENCY
            fi
            ;;
    esac
    
    log_debug "Filesystem validation passed: $filesystem"
    return 0
}

# Validation d'un chemin de répertoire
validate_directory_path() {
    local path="$1"
    local create_if_missing="${2:-false}"
    
    if [[ -z "$path" ]]; then
        log_error "Directory path cannot be empty"
        return $EXIT_ERROR_VALIDATION
    fi
    
    # Vérifier les caractères dangereux
    if [[ "$path" =~ [[:space:]\;\|\&\$\`\(\)] ]]; then
        log_error "Directory path contains dangerous characters: $path"
        return $EXIT_ERROR_VALIDATION
    fi
    
    # Vérifier les chemins absolus dangereux
    local dangerous_paths=("/" "/bin" "/boot" "/dev" "/etc" "/lib" "/proc" "/root" "/sbin" "/sys" "/usr" "/var")
    local dangerous_path
    for dangerous_path in "${dangerous_paths[@]}"; do
        if [[ "$path" == "$dangerous_path" ]]; then
            log_error "Cannot operate on critical system directory: $path"
            return $EXIT_ERROR_VALIDATION
        fi
    done
    
    if [[ ! -d "$path" ]]; then
        if [[ "$create_if_missing" == "true" ]]; then
            log_info "Creating directory: $path"
            if ! mkdir -p "$path"; then
                log_error "Failed to create directory: $path"
                return $EXIT_ERROR_GENERAL
            fi
        else
            log_error "Directory does not exist: $path"
            return $EXIT_ERROR_NOT_FOUND
        fi
    fi
    
    # Vérifier les permissions d'écriture
    if [[ ! -w "$path" ]]; then
        log_error "No write permission for directory: $path"
        return $EXIT_ERROR_PERMISSION
    fi
    
    log_debug "Directory path validation passed: $path"
    return 0
}

# Validation d'un Container ID pour Proxmox
validate_ctid() {
    local ctid="$1"
    
    if [[ -z "$ctid" ]]; then
        log_error "Container ID cannot be empty"
        return $EXIT_ERROR_VALIDATION
    fi
    
    # Vérifier que c'est un nombre
    if ! [[ "$ctid" =~ ^[0-9]+$ ]]; then
        log_error "Container ID must be numeric: $ctid"
        return $EXIT_ERROR_VALIDATION
    fi
    
    # Vérifier la plage valide (100-999999)
    if [[ $ctid -lt 100 ]] || [[ $ctid -gt 999999 ]]; then
        log_error "Container ID must be between 100 and 999999: $ctid"
        return $EXIT_ERROR_VALIDATION
    fi
    
    # Vérifier si le CT existe déjà (si pct est disponible)
    if command_exists pct; then
        if pct list | grep -q "^$ctid "; then
            log_error "Container ID already exists: $ctid"
            return $EXIT_ERROR_ALREADY
        fi
    fi
    
    log_debug "Container ID validation passed: $ctid"
    return 0
}

# Validation d'un nom d'hôte
validate_hostname() {
    local hostname="$1"
    
    if [[ -z "$hostname" ]]; then
        log_error "Hostname cannot be empty"
        return $EXIT_ERROR_VALIDATION
    fi
    
    if ! is_valid_hostname "$hostname"; then
        log_error "Invalid hostname format: $hostname"
        log_info "Hostname must follow RFC 1123 standards"
        return $EXIT_ERROR_VALIDATION
    fi
    
    log_debug "Hostname validation passed: $hostname"
    return 0
}

# Validation d'une adresse IP
validate_ip_address() {
    local ip="$1"
    local allow_private="${2:-true}"
    
    if [[ -z "$ip" ]]; then
        log_error "IP address cannot be empty"
        return $EXIT_ERROR_VALIDATION
    fi
    
    if ! is_valid_ip "$ip"; then
        log_error "Invalid IP address format: $ip"
        return $EXIT_ERROR_VALIDATION
    fi
    
    # Vérifier les plages privées si demandé
    if [[ "$allow_private" == "false" ]]; then
        if [[ "$ip" =~ ^10\. ]] || [[ "$ip" =~ ^192\.168\. ]] || [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
            log_error "Private IP addresses not allowed: $ip"
            return $EXIT_ERROR_VALIDATION
        fi
    fi
    
    log_debug "IP address validation passed: $ip"
    return 0
}

# Validation de paramètres obligatoires
validate_required_params() {
    local param_name
    local param_value
    
    while [[ $# -gt 0 ]]; do
        param_name="$1"
        param_value="$2"
        
        if [[ -z "$param_value" ]]; then
            log_error "Required parameter is empty: $param_name"
            return $EXIT_ERROR_USAGE
        fi
        
        shift 2
    done
    
    log_debug "All required parameters validated"
    return 0
}

# Validation d'un fichier JSON
validate_json_file() {
    local json_file="$1"
    
    if [[ ! -f "$json_file" ]]; then
        log_error "JSON file not found: $json_file"
        return $EXIT_ERROR_NOT_FOUND
    fi
    
    if ! jq empty "$json_file" 2>/dev/null; then
        log_error "Invalid JSON format in file: $json_file"
        return $EXIT_ERROR_VALIDATION
    fi
    
    log_debug "JSON file validation passed: $json_file"
    return 0
}

# Validation de taille de disque
validate_disk_size() {
    local size="$1"
    local min_size_gb="${2:-1}"
    
    if [[ -z "$size" ]]; then
        log_error "Disk size cannot be empty"
        return $EXIT_ERROR_VALIDATION
    fi
    
    # Extraire la valeur numérique et l'unité
    local size_value
    local size_unit
    
    if [[ "$size" =~ ^([0-9]+)([KMGTPE]?B?)$ ]]; then
        size_value="${BASH_REMATCH[1]}"
        size_unit="${BASH_REMATCH[2]}"
    else
        log_error "Invalid disk size format: $size (use: 10G, 500M, 1T, etc.)"
        return $EXIT_ERROR_VALIDATION
    fi
    
    # Convertir en GB pour comparaison
    local size_gb
    case "${size_unit^^}" in
        ""|"B") size_gb=$(echo "scale=2; $size_value / 1024 / 1024 / 1024" | bc) ;;
        "K"|"KB") size_gb=$(echo "scale=2; $size_value / 1024 / 1024" | bc) ;;
        "M"|"MB") size_gb=$(echo "scale=2; $size_value / 1024" | bc) ;;
        "G"|"GB") size_gb="$size_value" ;;
        "T"|"TB") size_gb=$(echo "scale=0; $size_value * 1024" | bc) ;;
        *) 
            log_error "Unsupported size unit: $size_unit"
            return $EXIT_ERROR_VALIDATION
            ;;
    esac
    
    # Vérifier la taille minimale
    if (( $(echo "$size_gb < $min_size_gb" | bc -l) )); then
        log_error "Disk size too small: ${size_gb}GB (minimum: ${min_size_gb}GB)"
        return $EXIT_ERROR_VALIDATION
    fi
    
    log_debug "Disk size validation passed: $size (${size_gb}GB)"
    return 0
}

# Export des fonctions pour utilisation dans les sous-shells
export -f validate_permissions
export -f validate_dependencies
export -f validate_block_device
export -f validate_filesystem
export -f validate_directory_path
export -f validate_ctid
export -f validate_hostname
export -f validate_ip_address
export -f validate_required_params
export -f validate_json_file
export -f validate_disk_size