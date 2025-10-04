# Versions PowerShell du Système de Catalogue SQLite

## 🎯 Vue d'ensemble

Ce répertoire contient les **versions PowerShell complètes** de tous les scripts de gestion du système de catalogue SQLite. Ces scripts permettent d'utiliser le système directement depuis Windows avec PowerShell, sans nécessiter un environnement Bash/Linux.

## 📋 Scripts PowerShell Disponibles

### 🔧 Scripts de Gestion Principaux

| Script PowerShell | Équivalent Bash | Description |
|-------------------|-----------------|-------------|
| `register-script.ps1` | `register-script.sh` | Enregistrement unitaire de scripts avec extraction automatique de métadonnées |
| `register-all-scripts.ps1` | `register-all-scripts.sh` | Enregistrement en masse de tous les scripts du projet |
| `search-db.ps1` | `search-db.sh` | Interface complète de recherche et consultation du catalogue |
| `export-db.ps1` | `export-db.sh` | Système d'export multi-format (JSON, CSV, SQL, Markdown, XML) |
| `validate-db-system.ps1` | `validate-db-system.sh` | Tests de validation complète du système |
| `setup-db-system.ps1` | `setup-db-system.sh` | Installation automatisée complète du système |

## 🚀 Installation Rapide

### Prérequis Windows

```powershell
# Vérifier la version PowerShell (5.1+ requis)
$PSVersionTable.PSVersion

# Installer SQLite3 (via Chocolatey - optionnel)
choco install sqlite

# OU installer le module PSSQLite (alternative)
Install-Module -Name PSSQLite -Scope CurrentUser
```

### Installation Automatisée

```powershell
# Navigation vers le répertoire du projet
cd "C:\Projects\system\linux\CT"

# Installation complète en une commande
.\tools\setup-db-system.ps1

# OU installation silencieuse avec réinitialisation
.\tools\setup-db-system.ps1 -Force -Quiet
```

## 💡 Utilisation Quotidienne

### 📊 Consultation et Statistiques

```powershell
# Statistiques globales du catalogue
.\tools\search-db.ps1 -Stats

# Interface interactive avec menus
.\tools\search-db.ps1 -Interactive

# Lister tous les scripts
.\tools\search-db.ps1 -All

# Recherche par nom (wildcards supportés)
.\tools\search-db.ps1 -Name "*usb*"

# Filtrer par type et catégorie
.\tools\search-db.ps1 -Type atomic -Category usb

# Informations détaillées d'un script spécifique
.\tools\search-db.ps1 -Info "setup-usb-storage.sh"

# Export des résultats de recherche
.\tools\search-db.ps1 -All -Format json -Output "scripts_list.json"
```

### 📝 Enregistrement et Mise à Jour

```powershell
# Enregistrer un nouveau script
.\tools\register-script.ps1 -ScriptPath "C:\Scripts\mon-script.sh"

# Enregistrement automatique sans interaction
.\tools\register-script.ps1 -ScriptPath ".\create-new-CT.sh" -Auto

# Forcer la mise à jour d'un script existant
.\tools\register-script.ps1 -ScriptPath ".\existing-script.sh" -Force

# Mettre à jour tous les scripts du projet
.\tools\register-all-scripts.ps1

# Enregistrement en masse avec mode simulation
.\tools\register-all-scripts.ps1 -DryRun

# Mise à jour forcée et silencieuse
.\tools\register-all-scripts.ps1 -Force -Quiet
```

### 📤 Exports et Sauvegardes

```powershell
# Backup complet de la base de données
.\tools\export-db.ps1 -Format backup

# Export JSON structuré complet
.\tools\export-db.ps1 -Format json -OutputDir "C:\Exports"

# Export CSV pour analyse Excel
.\tools\export-db.ps1 -Format csv -Category usb

# Rapport Markdown pour documentation
.\tools\export-db.ps1 -Format markdown -Validate

# Export SQL (dump complet)
.\tools\export-db.ps1 -Format sql

# Tous les formats en une fois avec compression
.\tools\export-db.ps1 -Format all -Compress -OutputDir "C:\Exports"
```

### ✅ Validation et Maintenance

```powershell
# Validation complète du système
.\tools\validate-db-system.ps1

# Tests rapides uniquement
.\tools\validate-db-system.ps1 -QuickTest

# Validation avec rapport détaillé
.\tools\validate-db-system.ps1 -Verbose -OutputReport "validation.txt"

# Réinstallation complète du système
.\tools\setup-db-system.ps1 -Force
```

## 🔧 Fonctionnalités Avancées PowerShell

### 🎯 Paramètres Standardisés

Tous les scripts PowerShell supportent :

```powershell
# Aide détaillée avec exemples
Get-Help .\tools\search-db.ps1 -Full

# Paramètres nommés avec auto-complétion
.\tools\search-db.ps1 -Name "setup*" -Type creator -Format table

# Mode silencieux pour automatisation
.\tools\register-all-scripts.ps1 -Quiet

# Mode verbeux pour débogage
.\tools\validate-db-system.ps1 -Verbose
```

### 📊 Formats de Sortie

```powershell
# Formats tabulaires
.\tools\search-db.ps1 -All -Format table    # Tableau compact
.\tools\search-db.ps1 -All -Format list     # Liste détaillée

# Formats structurés
.\tools\search-db.ps1 -All -Format json     # JSON pour APIs
.\tools\search-db.ps1 -All -Format csv      # CSV pour Excel

# Exports avec fichiers
.\tools\search-db.ps1 -All -Output "results.csv" -Format csv
```

### 🔄 Intégration avec PowerShell

```powershell
# Utilisation dans des scripts PowerShell
$scripts = & .\tools\search-db.ps1 -Type atomic -Format json | ConvertFrom-Json
foreach ($script in $scripts) {
    Write-Host "Script: $($script.name) - $($script.description)"
}

# Pipeline PowerShell
.\tools\search-db.ps1 -All -Format json | 
    ConvertFrom-Json | 
    Where-Object { $_.category -eq 'usb' } |
    Select-Object name, description
```

## 🛠️ Configuration et Personnalisation

### 📁 Structure de Fichiers

```
tools/
├── register-script.ps1      # ✅ Enregistrement unitaire
├── register-all-scripts.ps1 # ✅ Enregistrement en masse  
├── search-db.ps1           # ✅ Recherche et consultation
├── export-db.ps1           # ✅ Exports multi-format
├── validate-db-system.ps1  # ✅ Tests de validation
└── setup-db-system.ps1     # ✅ Installation automatisée

database/
├── init-db.ps1             # Script d'initialisation (à créer)
├── scripts_catalogue.db    # Base SQLite (généré)
└── README.md              # Documentation complète

exports/                    # Répertoire des exports (généré)
├── backup_*.db            # Sauvegardes
├── catalogue_*.json       # Exports JSON
├── catalogue_*.csv        # Exports CSV
└── catalogue_*.md         # Rapports Markdown
```

### ⚙️ Variables d'Environnement

```powershell
# Personnaliser le répertoire d'exports
$env:DB_EXPORT_DIR = "D:\MonCatalogue\Exports"
.\tools\export-db.ps1 -Format json -OutputDir $env:DB_EXPORT_DIR

# Répertoire de base personnalisé
$env:CT_PROJECT_ROOT = "D:\MesProjets\CT"
```

## 🔍 Dépannage et FAQ

### ❓ Problèmes Fréquents

**Q: "SQLite3 non disponible"**
```powershell
# Solution 1: Installer SQLite3
choco install sqlite

# Solution 2: Utiliser le module PowerShell
Install-Module -Name PSSQLite -Force
Import-Module PSSQLite
```

**Q: "Erreur d'exécution des scripts"**
```powershell
# Vérifier la politique d'exécution
Get-ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Q: "Base de données corrompue"**
```powershell
# Réinitialisation complète
.\tools\setup-db-system.ps1 -Force

# Ou validation avec rapport
.\tools\validate-db-system.ps1 -Verbose
```

### 🔧 Tests de Diagnostic

```powershell
# Test des prérequis
$PSVersionTable.PSVersion                    # Version PowerShell
Get-Command sqlite3 -ErrorAction SilentlyContinue  # SQLite3 disponible
Get-Module -ListAvailable PSSQLite          # Module PSSQLite

# Test de la base
Test-Path ".\database\scripts_catalogue.db"  # Base existe
.\tools\validate-db-system.ps1 -QuickTest   # Validation rapide
```

## 📚 Ressources et Documentation

### 📖 Documentation Complète

- **Guide utilisateur complet** : `database\README.md`
- **Méthodologie de développement** : `docs\Méthodologie*.md`
- **Architecture de la base** : `docs\Base de Données SQLite pour Catalogue de Scripts.md`

### 🔗 Liens Utiles

- [Documentation PowerShell](https://docs.microsoft.com/powershell/)
- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [Module PSSQLite](https://github.com/RamblingCookieMonster/PSSQLite)

### ⚡ Raccourcis et Alias

```powershell
# Créer des alias pour utilisation fréquente
New-Alias -Name "catalog-search" -Value ".\tools\search-db.ps1"
New-Alias -Name "catalog-register" -Value ".\tools\register-script.ps1"
New-Alias -Name "catalog-export" -Value ".\tools\export-db.ps1"

# Utilisation avec les alias
catalog-search -Stats
catalog-register -ScriptPath "nouveau-script.sh" -Auto
catalog-export -Format backup
```

## 🎉 Conclusion

Les versions PowerShell du système de catalogue SQLite offrent une **expérience native Windows** complète avec :

- ✅ **Fonctionnalités identiques** aux versions Bash
- ✅ **Interface PowerShell native** avec paramètres nommés
- ✅ **Intégration Windows** (raccourcis, tâches planifiées)
- ✅ **Support multi-format** pour tous les exports
- ✅ **Validation complète** et tests automatisés
- ✅ **Installation automatisée** en une commande
- ✅ **Documentation intégrée** avec Get-Help

Le système est maintenant **pleinement opérationnel** sur Windows et Linux ! 🚀

---

**Version** : 1.0  
**Date** : 3 octobre 2025  
**Compatibilité** : PowerShell 5.1+ / Windows 10+ / Windows Server 2016+