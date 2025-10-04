# Proxmox CT Management Scripts - AI Coding Instructions

## Architecture Overview

envionnement de developpement sous windows (powershell),; tu developpes des scriptes pour envionnement linux.
This project manages Proxmox Container Templates (CTs) through a **hierarchical modular system** with two main components:

### 1. CT Creation Scripts (Root Level)
- **Pattern**: `create-*-CT.sh` scripts that build specialized container templates
- **Shared Library**: All scripts source `lib/lib-ct-common.sh` for common functions
- **Entry Point**: `ct-launcher.sh` provides interactive menu for all CT types

### 2. USB Disk Manager (Sub-project)
- **Location**: `usb-disk-manager/` - Complete modular USB/iSCSI management system
- **Architecture**: 4-tier hierarchy following "one action = one script" principle:
  - `lib/` - Pure functions (no exit calls, return codes only)
  - `scripts/atomic/` - Single-action scripts (can use lib/ only)
  - `scripts/orchestrators/` - Multi-action workflows (use atomic/ + lib/)
  - `scripts/main/` - User interfaces (use all levels)

## Critical Development Patterns

### Bash Script Standards
```bash
#!/usr/bin/env bash
set -euo pipefail  # REQUIRED: Fail fast, undefined vars, pipe failures
source "$(dirname "$0")/lib-ct-common.sh"  # For CT scripts
# OR for USB manager:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../lib")"
```

### Logging Functions (Module-Specific Prefixes)
```bash
# CT scripts use lib-ct-common.sh:
info "message"    # [INFO] blue
warn "message"    # [WARN] yellow  
ok "message"      # [OK] green
die "message"     # [ERROR] red + exit 1

# USB manager uses module prefixes:
usb_info "msg"     # [USB-INFO]
iscsi_error "msg"  # [iSCSI-ERROR]
```

### Dependency Rules (USB Manager)
- **lib/** functions: Use `return 0|1`, never `exit`
- **atomic/** scripts: Can only source `lib/`, single responsibility
- **orchestrators/**: Call atomic scripts + use lib functions
- **main/**: Can use everything, provides user interfaces

### CT Script Patterns
- Use `CTID="${CTID:-}"` with fallback: `if [[ -z "${CTID}" ]]; then CTID=$(pick_free_ctid); fi`
- Template selection: `TEMPLATE_REF=$(find_debian12_template)`
- Container ops: `pct create`, `pct start`, `pct exec` for inside operations
- Environment overrides: `HOSTNAME_OVERRIDE`, `ROOTFS_STORAGE`, `DISK_GB`, etc.

## Key Workflows

### Creating New CT Scripts
1. Copy `create-base-CT.sh` as template
2. Source `lib-ct-common.sh` for shared functions (`pick_free_ctid`, `find_debian12_template`, `bootstrap_base_inside`)
3. Use installer pattern: `pct exec "$CTID" -- bash -c "commands"`
4. Add to `ct-launcher.sh` menu system

### USB Manager Development
1. **New atomic script**: Create in `scripts/atomic/`, single action only
2. **New workflow**: Create orchestrator combining atomic scripts
3. **New library function**: Add to appropriate `lib/lib-*.sh` with module prefix
4. **All scripts must have**: `show_help()` function, `parse_args()`, `main()` function

### Testing & Validation
- USB manager: `./docs/validate-compliance.sh` checks interface standards
- CT scripts: Test with `CTID=<number> ./create-*-CT.sh`
- Integration: `usb-disk-manager/test-integration.sh`

## Project Structure Specifics

### Critical Files to Understand
- `lib/lib-ct-common.sh` - Core CT management functions
- `docs/` - All development methodology and compliance standards
- `usb-disk-manager/lib/lib-usb-storage.sh` - USB detection/management
- `ct-launcher.sh` - Main CT creation interface

### Naming Conventions
- CT scripts: `create-<purpose>-CT.sh`
- USB atomic: `<action>-<target>.sh` (e.g., `select-disk.sh`)
- USB orchestrators: `setup-<workflow>.sh`
- Library functions: `<module>_<action>_<target>()` (e.g., `usb_list_storage_devices()`)

### Configuration Patterns
- Environment variables for defaults with fallbacks
- SCRIPT_DIR resolution for relative paths
- Proxmox-specific: Storage (`local-lvm`), network (`vmbr0`), templates (`debian-12-standard`)

## Compliance Standards (MANDATORY)

### Development Standards for All Components
All development (PCI, file, string, network, UI, GUI, etc.) MUST comply with:
- **`docs/Méthodologie de Développement Modulaire et Hiérarchique.md`** - Unified methodology covering interface specifications, function signatures, error handling, hierarchical rules, dependency patterns, and naming conventions
- **`docs/Méthodologie de Développement Modulaire - Partie 2.md`** - Advanced modular development patterns and extended guidelines
- **`docs/Méthodologie Précise de Développement d'un Script.md`** - **MANDATORY**: Precise script development methodology that MUST be followed scrupulously for every script creation or modification

### Compliance Validation
```bash
# Always run before committing any modular component changes
./docs/validate-compliance.sh

# Check specific compliance areas for all development types
./docs/validate-compliance.sh  # Full system validation
```

### Key Compliance Rules
- **Script Development**: MUST follow step-by-step methodology in `Méthodologie Précise de Développement d'un Script.md`
- **Function naming**: `module_action_target()` format (e.g., `usb_list_storage_devices()`)
- **Script structure**: Mandatory `show_help()`, `parse_args()`, `main()` functions
- **Error handling**: Libraries use `return 0|1`, scripts can use `exit`
- **Arguments**: Standard options (`-h/--help`, `-q/--quiet`, `-f/--force`)
- **Development Process**: Follow precise methodology scrupulously - no shortcuts or deviations allowed

## Integration Points

- **Proxmox API**: Uses `pct`, `pvesm`, `pveam` commands
- **iSCSI**: Integration with `targetcli-fb` for Proxmox storage
- **USB Hardware**: Direct `lsblk`, `lsusb`, `udevadm` interaction
- **JSON Processing**: `jq` for structured data in USB manager

When modifying existing code, always check compliance with `docs/` standards and maintain the established hierarchical patterns.

whe you finish  modificatin or new code : git  et git push 
aec un commentiare