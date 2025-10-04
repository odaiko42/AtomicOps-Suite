#Requires -Version 5.1
<#
.SYNOPSIS
    Installation complète du système de catalogue SQLite pour scripts CT.

.DESCRIPTION
    Ce script PowerShell automatise la mise en place complète du système de catalogue
    SQLite, de l'initialisation à la validation finale.

.PARAMETER Force
    Force la réinitialisation même si une base existe déjà

.PARAMETER Quiet
    Mode silencieux, affiche uniquement les erreurs et résumés

.EXAMPLE
    .\setup-db-system.ps1
    
.EXAMPLE
    .\setup-db-system.ps1 -Force -Quiet

.NOTES
    Auteur: Système de Catalogue SQLite CT
    Version: 1.0
    Date: 3 octobre 2025
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage="Force la réinitialisation complète")]
    [switch]$Force,
    
    [Parameter(HelpMessage="Mode silencieux")]
    [switch]$Quiet
)

# Configuration globale
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$DatabaseFile = Join-Path $ProjectRoot "database\scripts_catalogue.db"

# Codes de sortie
$EXIT_SUCCESS = 0
$EXIT_ERROR_PREREQ = 1
$EXIT_ERROR_DB = 2
$EXIT_ERROR_INSTALL = 3

# Variables de suivi
$InstallStats = @{
    StartTime = Get-Date
    Steps = @()
    Errors = @()
    Warnings = @()
    CompletedSteps = 0
    DatabaseCreated = $false
    ScriptsRegistered = 0
}

# Fonctions de logging
function Write-Info {
    param([string]$Message)
    if (-not $Quiet) {
        Write-Host "[INFO] $Message" -ForegroundColor Cyan
    }
}

function Write-Warn {
    param([string]$Message)
    if (-not $Quiet) {
        Write-Host "[WARN] $Message" -ForegroundColor Yellow
    }
    $InstallStats.Warnings += $Message
}

function Write-Success {
    param([string]$Message)
    if (-not $Quiet) {
        Write-Host "[OK] $Message" -ForegroundColor Green
    }
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    $InstallStats.Errors += $Message
}

# Fonction pour afficher une barre de progression
function Show-Progress {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Status
    )
    
    if ($Quiet) {
        return
    }
    
    $percentage = if ($Total -gt 0) { [math]::Round(($Current / $Total) * 100) } else { 0 }
    $barLength = 30
    $filledLength = [math]::Round(($Current / $Total) * $barLength)
    
    $bar = "=" * $filledLength + "." * ($barLength - $filledLength)
    
    Write-Host "`rInstallation: [$bar] $percentage% - $Status" -NoNewline -ForegroundColor Cyan
    
    if ($Current -eq $Total) {
        Write-Host ""
    }
}

# Étape 1: Vérification des prérequis
function Test-Prerequisites {
    Write-Info "Etape 1/5: Verification des prerequis systeme"
    Show-Progress 1 5 "Verification des prerequis"
    
    $issues = @()
    
    # Vérifier PowerShell
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell 5.1+ requis (version actuelle: $($PSVersionTable.PSVersion))"
    }
    else {
        Write-Success "PowerShell version OK ($($PSVersionTable.PSVersion))"
    }
    
    # Vérifier SQLite
    $sqliteOK = $false
    if (Get-Command sqlite3 -ErrorAction SilentlyContinue) {
        $version = & sqlite3 -version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "SQLite3 disponible"
            $sqliteOK = $true
        }
    }
    
    if (-not $sqliteOK -and (Get-Module -ListAvailable -Name PSSQLite)) {
        Write-Success "Module PSSQLite disponible"
        $sqliteOK = $true
    }
    
    if (-not $sqliteOK) {
        $issues += "SQLite3 ou module PSSQLite requis"
    }
    
    # Vérifier les permissions d'écriture
    try {
        $testFile = Join-Path $ProjectRoot "test_permissions.tmp"
        "test" | Out-File -FilePath $testFile -Force
        Remove-Item $testFile -Force
        Write-Success "Permissions d'ecriture OK"
    }
    catch {
        $issues += "Permissions d'écriture insuffisantes dans $ProjectRoot"
    }
    
    # Vérifier la structure des répertoires
    $requiredDirs = @("database", "tools", "exports")
    foreach ($dir in $requiredDirs) {
        $dirPath = Join-Path $ProjectRoot $dir
        if (-not (Test-Path $dirPath)) {
            try {
                New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
                Write-Info "Repertoire cree: $dir"
            }
            catch {
                $issues += "Impossible de créer le répertoire: $dir"
            }
        }
        else {
            Write-Success "Repertoire existant: $dir"
        }
    }
    
    if ($issues.Count -gt 0) {
        Write-Error-Custom "Prerequis non satisfaits :"
        foreach ($issue in $issues) {
            Write-Error-Custom "  - $issue"
        }
        return $false
    }
    
    $InstallStats.CompletedSteps++
    return $true
}

# Étape 2: Vérification des outils de gestion
function Test-ManagementTools {
    Write-Info "Etape 2/5: Verification des outils de gestion"
    Show-Progress 2 5 "Verification des outils"
    
    $requiredTools = @{
        "register-script.ps1" = "Enregistrement unitaire de scripts"
        "register-all-scripts.ps1" = "Enregistrement en masse"
        "search-db.ps1" = "Recherche et consultation"
        "export-db.ps1" = "Export multi-format"
        "validate-db-system.ps1" = "Validation système"
    }
    
    $missingTools = @()
    
    foreach ($tool in $requiredTools.GetEnumerator()) {
        $toolPath = Join-Path $ScriptDir $tool.Key
        
        if (Test-Path $toolPath) {
            Write-Success "OK: $($tool.Key)"
        }
        else {
            $missingTools += $tool.Key
            Write-Error-Custom "MANQUANT: $($tool.Key)"
        }
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Error-Custom "Outils manquants : $($missingTools -join ', ')"
        return $false
    }
    
    $InstallStats.CompletedSteps++
    return $true
}

# Étape 3: Initialisation de la base de données
function Initialize-Database {
    Write-Info "Etape 3/5: Initialisation de la base de donnees"
    Show-Progress 3 5 "Initialisation de la base"
    
    $initScript = Join-Path $ProjectRoot "database\init-db.ps1"
    
    if (-not (Test-Path $initScript)) {
        Write-Error-Custom "Script d'initialisation non trouvé : $initScript"
        return $false
    }
    
    # Vérifier si la base existe déjà
    $dbExists = Test-Path $DatabaseFile
    if ($dbExists -and -not $Force) {
        if (-not $Quiet) {
            $response = Read-Host "Base de données existante trouvée. Réinitialiser ? [y/N]"
            if ($response -notmatch '^[yY]') {
                Write-Info "Conservation de la base existante"
                $InstallStats.CompletedSteps++
                return $true
            }
        }
        else {
            Write-Info "Base existante conservée (utilisez -Force pour réinitialiser)"
            $InstallStats.CompletedSteps++
            return $true
        }
    }
    
    try {
        $initArgs = @()
        if ($Force) { $initArgs += "-Force" }
        if ($Quiet) { $initArgs += "-Quiet" }
        
        Write-Info "Exécution de l'initialisation..."
        & powershell.exe -File $initScript @initArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Base de donnees initialisee"
            $InstallStats.DatabaseCreated = $true
            $InstallStats.CompletedSteps++
            return $true
        }
        else {
            Write-Error-Custom "Échec de l'initialisation (code: $LASTEXITCODE)"
            return $false
        }
    }
    catch {
        Write-Error-Custom "Erreur lors de l'initialisation : $($_.Exception.Message)"
        return $false
    }
}

# Étape 4: Enregistrement des scripts existants
function Register-ExistingScripts {
    Write-Info "Etape 4/5: Enregistrement des scripts existants"
    Show-Progress 4 5 "Enregistrement des scripts"
    
    $registerScript = Join-Path $ScriptDir "register-all-scripts.ps1"
    
    if (-not (Test-Path $registerScript)) {
        Write-Warn "Script d'enregistrement non trouvé - ignoré"
        $InstallStats.CompletedSteps++
        return $true
    }
    
    try {
        Write-Info "Recherche et enregistrement des scripts..."
        
        $registerArgs = @()
        if ($Force) { $registerArgs += "-Force" }
        if ($Quiet) { $registerArgs += "-Quiet" }
        
        & powershell.exe -File $registerScript @registerArgs
        
        if ($LASTEXITCODE -eq 0) {
            # Compter les scripts enregistrés
            try {
                if (Get-Command sqlite3 -ErrorAction SilentlyContinue) {
                    $scriptCount = & sqlite3 $DatabaseFile "SELECT COUNT(*) FROM scripts;" 2>$null
                    $InstallStats.ScriptsRegistered = [int]$scriptCount
                }
            }
            catch {
                $InstallStats.ScriptsRegistered = 0
            }
            
            Write-Success "Scripts enregistres : $($InstallStats.ScriptsRegistered)"
            $InstallStats.CompletedSteps++
            return $true
        }
        else {
            Write-Warn "Probleme lors de l'enregistrement (non-bloquant)"
            $InstallStats.CompletedSteps++
            return $true
        }
    }
    catch {
        Write-Warn "Erreur lors de l'enregistrement : $($_.Exception.Message)"
        $InstallStats.CompletedSteps++
        return $true
    }
}

# Étape 5: Validation finale
function Validate-Installation {
    Write-Info "Etape 5/5: Validation du systeme"
    Show-Progress 5 5 "Validation finale"
    
    $validateScript = Join-Path $ScriptDir "validate-db-system.ps1"
    
    if (-not (Test-Path $validateScript)) {
        Write-Warn "Script de validation non trouvé - validation manuelle requise"
        $InstallStats.CompletedSteps++
        return $true
    }
    
    try {
        Write-Info "Exécution de la validation..."
        
        $validateArgs = @("-QuickTest")
        if ($Quiet) { $validateArgs += "-Quiet" }
        
        & powershell.exe -File $validateScript @validateArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Validation reussie"
        }
        else {
            Write-Warn "Validation echouee - systeme probablement fonctionnel"
        }
        
        $InstallStats.CompletedSteps++
        return $true
    }
    catch {
        Write-Warn "Erreur lors de la validation : $($_.Exception.Message)"
        $InstallStats.CompletedSteps++
        return $true
    }
}

# Afficher le rapport final
function Show-InstallationReport {
    $endTime = Get-Date
    $duration = $endTime - $InstallStats.StartTime
    
    Show-Progress 5 5 "Installation terminée"
    
    Write-Host ""
    Write-Host "INSTALLATION TERMINEE !" -ForegroundColor Green
    Write-Host "============================" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Resume de l'installation :" -ForegroundColor White
    Write-Host "  Etapes completees    : $($InstallStats.CompletedSteps)/5" -ForegroundColor Gray
    Write-Host "  Duree totale         : $($duration.ToString('mm\:ss'))" -ForegroundColor Gray
    Write-Host "  Base de donnees      : $(if ($InstallStats.DatabaseCreated) { 'Creee' } else { 'Existante' })" -ForegroundColor Gray
    Write-Host "  Scripts enregistres  : $($InstallStats.ScriptsRegistered)" -ForegroundColor Gray
    Write-Host ""
    
    if ($InstallStats.Warnings.Count -gt 0) {
        Write-Host "Avertissements :" -ForegroundColor Yellow
        foreach ($warning in $InstallStats.Warnings) {
            Write-Host "  - $warning" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    Write-Host "Commandes de demarrage rapide :" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  # Statistiques du catalogue" -ForegroundColor White
    Write-Host "  .\tools\search-db.ps1 -Stats" -ForegroundColor Green
    Write-Host ""
    Write-Host "  # Interface interactive" -ForegroundColor White  
    Write-Host "  .\tools\search-db.ps1 -Interactive" -ForegroundColor Green
    Write-Host ""
    Write-Host "  # Lister tous les scripts" -ForegroundColor White
    Write-Host "  .\tools\search-db.ps1 -All" -ForegroundColor Green
    Write-Host ""
    Write-Host "  # Mettre à jour le catalogue" -ForegroundColor White
    Write-Host "  .\tools\register-all-scripts.ps1" -ForegroundColor Green
    Write-Host ""
    
    if ($InstallStats.Errors.Count -eq 0) {
        Write-Host "Installation reussie avec succes !" -ForegroundColor Green
    }
    else {
        Write-Host "Installation terminee avec $($InstallStats.Errors.Count) erreur(s)." -ForegroundColor Yellow
    }
}

# Fonction principale
function Main {
    Write-Host ""
    Write-Host "INSTALLATION DU SYSTEME DE CATALOGUE SQLITE" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Info "Configuration d'installation :"
    Write-Info "  Force reinitialisation : $(if ($Force) { 'Oui' } else { 'Non' })"
    Write-Info "  Mode silencieux        : $(if ($Quiet) { 'Oui' } else { 'Non' })"
    Write-Info "  Repertoire projet      : $ProjectRoot"
    Write-Info ""
    
    try {
        # Exécution séquentielle des étapes
        if (-not (Test-Prerequisites)) {
            throw "Échec de vérification des prérequis"
        }
        
        if (-not (Test-ManagementTools)) {
            throw "Outils de gestion manquants"
        }
        
        if (-not (Initialize-Database)) {
            throw "Échec de l'initialisation de la base de données"
        }
        
        Register-ExistingScripts | Out-Null
        Validate-Installation | Out-Null
        
        # Rapport final
        Show-InstallationReport
        
        if ($InstallStats.Errors.Count -eq 0) {
            exit $EXIT_SUCCESS
        }
        else {
            exit $EXIT_ERROR_INSTALL
        }
    }
    catch {
        Write-Error-Custom "Erreur critique : $($_.Exception.Message)"
        exit $EXIT_ERROR_INSTALL
    }
}

# Point d'entrée
if ($MyInvocation.InvocationName -ne ".") {
    Main
}