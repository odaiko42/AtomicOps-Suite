#Requires -Version 5.1
<#
.SYNOPSIS
    Enregistre tous les scripts du projet dans le catalogue SQLite en mode batch.

.DESCRIPTION
    Ce script PowerShell parcourt récursivement tous les scripts Bash du projet
    et les enregistre automatiquement dans la base de données catalogue.
    
    Fonctionnalités :
    - Découverte automatique des scripts (.sh, .bash)
    - Traitement par lots avec gestion d'erreurs
    - Rapport détaillé avec statistiques
    - Mode simulation (dry-run)
    - Filtrage par répertoire et type
    - Mise à jour des scripts existants

.PARAMETER Path
    Répertoire racine à analyser (par défaut: répertoire du projet)

.PARAMETER Include
    Pattern de fichiers à inclure (par défaut: *.sh)

.PARAMETER Exclude
    Répertoires à exclure (par défaut: .git, node_modules, etc.)

.PARAMETER DryRun
    Mode simulation - affiche ce qui serait fait sans modifier la base

.PARAMETER Force
    Force la mise à jour des scripts existants

.PARAMETER Quiet
    Mode silencieux, affiche uniquement les erreurs et le résumé

.PARAMETER MaxDepth
    Profondeur maximale de récursion (par défaut: 10)

.EXAMPLE
    .\register-all-scripts.ps1
    
.EXAMPLE
    .\register-all-scripts.ps1 -Path "C:\Scripts" -DryRun
    
.EXAMPLE
    .\register-all-scripts.ps1 -Force -Quiet

.NOTES
    Auteur: Système de Catalogue SQLite CT
    Version: 1.0
    Date: 3 octobre 2025
    
    Prérequis:
    - SQLite3 accessible ou module PSSQLite
    - Base de données initialisée
    - register-script.ps1 présent
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage="Répertoire racine à analyser")]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$Path,
    
    [Parameter(HelpMessage="Pattern de fichiers à inclure")]
    [string]$Include = "*.sh",
    
    [Parameter(HelpMessage="Répertoires à exclure")]
    [string[]]$Exclude = @(".git", "node_modules", "temp", "tmp", "exports"),
    
    [Parameter(HelpMessage="Mode simulation sans modification")]
    [switch]$DryRun,
    
    [Parameter(HelpMessage="Force la mise à jour des scripts existants")]
    [switch]$Force,
    
    [Parameter(HelpMessage="Mode silencieux")]
    [switch]$Quiet,
    
    [Parameter(HelpMessage="Profondeur maximale de récursion")]
    [ValidateRange(1, 20)]
    [int]$MaxDepth = 10
)

# Configuration globale
$ErrorActionPreference = "Continue"  # Continue sur erreur pour traiter tous les scripts
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$DatabaseFile = Join-Path $ProjectRoot "database\scripts_catalogue.db"
$RegisterScriptPath = Join-Path $ScriptDir "register-script.ps1"

# Si pas de chemin spécifié, utiliser la racine du projet
if (-not $Path) {
    $Path = $ProjectRoot
}

# Codes de sortie
$EXIT_SUCCESS = 0
$EXIT_ERROR_ARGS = 1
$EXIT_ERROR_DB = 2
$EXIT_ERROR_SCRIPTS = 3

# Variables de statistiques
$Stats = @{
    TotalFound = 0
    Processed = 0
    Success = 0
    Errors = 0
    Skipped = 0
    Updated = 0
    ErrorList = @()
    StartTime = Get-Date
}

# Fonctions de logging avec couleurs
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
}

# Fonction pour exécuter des commandes SQLite
function Invoke-SQLite {
    param(
        [string]$Query,
        [string]$Database = $DatabaseFile,
        [switch]$NoOutput
    )
    
    try {
        if (Get-Command sqlite3 -ErrorAction SilentlyContinue) {
            $result = & sqlite3 $Database $Query 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "Erreur SQLite: $LASTEXITCODE"
            }
            return $result
        }
        elseif (Get-Module -ListAvailable -Name PSSQLite) {
            Import-Module PSSQLite
            return Invoke-SqliteQuery -DataSource $Database -Query $Query
        }
        else {
            throw "SQLite3 non disponible. Installez sqlite3 ou le module PSSQLite."
        }
    }
    catch {
        throw
    }
}

# Fonction pour vérifier la base de données
function Test-Database {
    if (-not (Test-Path $DatabaseFile)) {
        Write-Error-Custom "Base de données non trouvée: $DatabaseFile"
        Write-Info "Initialisez la base avec: .\database\init-db.ps1"
        return $false
    }
    
    try {
        $tableCount = Invoke-SQLite "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
        if ([int]$tableCount -lt 5) {
            Write-Error-Custom "Base de données incomplète ($tableCount tables)"
            return $false
        }
        return $true
    }
    catch {
        Write-Error-Custom "Base de données corrompue: $_"
        return $false
    }
}

# Fonction pour vérifier le script register-script.ps1
function Test-RegisterScript {
    if (-not (Test-Path $RegisterScriptPath)) {
        Write-Error-Custom "Script register-script.ps1 non trouvé: $RegisterScriptPath"
        return $false
    }
    return $true
}

# Fonction pour découvrir tous les scripts
function Find-Scripts {
    param(
        [string]$SearchPath,
        [string]$Pattern,
        [string[]]$ExcludeDirs,
        [int]$Depth
    )
    
    Write-Info "🔍 Recherche des scripts dans: $SearchPath"
    Write-Info "   Pattern: $Pattern, Profondeur max: $Depth"
    
    $foundScripts = @()
    
    try {
        # Construire le filtre d'exclusion pour Get-ChildItem
        $excludePattern = if ($ExcludeDirs) {
            "^(" + ($ExcludeDirs -join "|") + ")$"
        } else {
            $null
        }
        
        # Recherche récursive des fichiers
        $allFiles = Get-ChildItem -Path $SearchPath -Filter $Pattern -Recurse -File -ErrorAction SilentlyContinue |
                   Where-Object {
                       # Filtrer les répertoires exclus
                       if ($excludePattern) {
                           $relativePath = $_.FullName.Substring($SearchPath.Length).TrimStart('\', '/')
                           $pathParts = $relativePath.Split('\', '/')
                           $shouldExclude = $pathParts | Where-Object { $_ -match $excludePattern }
                           return -not $shouldExclude
                       }
                       return $true
                   } |
                   Where-Object {
                       # Vérifier la profondeur
                       $relativePath = $_.FullName.Substring($SearchPath.Length).TrimStart('\', '/')
                       $depth = ($relativePath.Split('\', '/').Count - 1)
                       return $depth -le $Depth
                   }
        
        foreach ($file in $allFiles) {
            # Vérifier que c'est bien un script (commence par shebang ou a une extension .sh/.bash)
            $isScript = $false
            
            if ($file.Extension -in @('.sh', '.bash')) {
                $isScript = $true
            }
            elseif ($file.Extension -eq '') {
                # Vérifier le shebang pour les fichiers sans extension
                try {
                    $firstLine = Get-Content $file.FullName -TotalCount 1 -ErrorAction SilentlyContinue
                    if ($firstLine -and $firstLine.StartsWith('#!') -and $firstLine -match '(bash|sh)') {
                        $isScript = $true
                    }
                }
                catch {
                    # Ignorer les erreurs de lecture
                }
            }
            
            if ($isScript) {
                $foundScripts += @{
                    Path = $file.FullName
                    Name = $file.Name
                    Size = $file.Length
                    LastModified = $file.LastWriteTime
                    RelativePath = $file.FullName.Substring($SearchPath.Length).TrimStart('\', '/')
                }
            }
        }
        
        $Stats.TotalFound = $foundScripts.Count
        Write-Info "✓ Trouvé $($foundScripts.Count) script(s)"
        
        return $foundScripts
    }
    catch {
        Write-Error-Custom "Erreur lors de la recherche: $_"
        return @()
    }
}

# Fonction pour traiter un script individuel
function Process-Script {
    param([hashtable]$ScriptInfo)
    
    $scriptName = $ScriptInfo.Name
    $scriptPath = $ScriptInfo.Path
    
    if (-not $Quiet) {
        Write-Host "  📄 $($ScriptInfo.RelativePath)" -NoNewline
    }
    
    try {
        $Stats.Processed++
        
        if ($DryRun) {
            if (-not $Quiet) {
                Write-Host " [SIMULATION]" -ForegroundColor Yellow
            }
            $Stats.Success++
            return $true
        }
        
        # Préparer les arguments pour register-script.ps1
        $registerArgs = @(
            '-ScriptPath', $scriptPath,
            '-Auto'
        )
        
        if ($Force) {
            $registerArgs += '-Force'
        }
        
        if ($Quiet) {
            $registerArgs += '-Quiet'
        }
        
        # Exécuter le script d'enregistrement
        $result = & powershell.exe -File $RegisterScriptPath @registerArgs
        
        if ($LASTEXITCODE -eq 0) {
            if (-not $Quiet) {
                Write-Host " ✓" -ForegroundColor Green
            }
            $Stats.Success++
            return $true
        }
        else {
            if (-not $Quiet) {
                Write-Host " ✗" -ForegroundColor Red
            }
            $errorMsg = "Code de sortie: $LASTEXITCODE"
            $Stats.ErrorList += "$scriptName : $errorMsg"
            $Stats.Errors++
            return $false
        }
    }
    catch {
        if (-not $Quiet) {
            Write-Host " ✗" -ForegroundColor Red
        }
        $errorMsg = $_.Exception.Message
        $Stats.ErrorList += "$scriptName : $errorMsg"
        $Stats.Errors++
        return $false
    }
}

# Fonction pour afficher la barre de progression
function Show-Progress {
    param(
        [int]$Current,
        [int]$Total,
        [string]$CurrentItem = ""
    )
    
    if ($Quiet -or $Total -eq 0) {
        return
    }
    
    $percentage = [math]::Round(($Current / $Total) * 100, 1)
    $barLength = 30
    $filledLength = [math]::Round(($Current / $Total) * $barLength)
    
    $bar = "█" * $filledLength + "░" * ($barLength - $filledLength)
    
    Write-Host "`r🔄 Progression: [$bar] $percentage% ($Current/$Total) $CurrentItem" -NoNewline
    
    if ($Current -eq $Total) {
        Write-Host ""  # Nouvelle ligne à la fin
    }
}

# Fonction pour afficher le rapport final
function Show-FinalReport {
    $endTime = Get-Date
    $duration = $endTime - $Stats.StartTime
    
    Write-Host ""
    Write-Host "📊 RAPPORT D'ENREGISTREMENT" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "📈 Statistiques générales :" -ForegroundColor White
    Write-Host "  Scripts découverts   : $($Stats.TotalFound)" -ForegroundColor Gray
    Write-Host "  Scripts traités      : $($Stats.Processed)" -ForegroundColor Gray
    Write-Host "  Succès               : " -NoNewline -ForegroundColor Gray
    Write-Host "$($Stats.Success)" -ForegroundColor Green
    Write-Host "  Erreurs              : " -NoNewline -ForegroundColor Gray
    Write-Host "$($Stats.Errors)" -ForegroundColor Red
    Write-Host "  Ignorés              : $($Stats.Skipped)" -ForegroundColor Gray
    Write-Host ""
    
    # Calcul du taux de réussite
    $successRate = if ($Stats.Processed -gt 0) {
        [math]::Round(($Stats.Success / $Stats.Processed) * 100, 1)
    } else { 0 }
    
    Write-Host "⚡ Performance :" -ForegroundColor White
    Write-Host "  Durée totale         : $($duration.ToString('mm\:ss'))" -ForegroundColor Gray
    Write-Host "  Taux de réussite     : $successRate%" -ForegroundColor Gray
    Write-Host "  Scripts/seconde      : $(if ($duration.TotalSeconds -gt 0) { [math]::Round($Stats.Processed / $duration.TotalSeconds, 2) } else { 'N/A' })" -ForegroundColor Gray
    Write-Host ""
    
    # Mode simulation
    if ($DryRun) {
        Write-Host "🧪 Mode Simulation :" -ForegroundColor Yellow
        Write-Host "  Aucune modification effectuée" -ForegroundColor Yellow
        Write-Host "  Utilisez sans -DryRun pour enregistrer réellement" -ForegroundColor Yellow
        Write-Host ""
    }
    
    # Informations sur la base de données
    if (-not $DryRun -and (Test-Path $DatabaseFile)) {
        try {
            $totalScriptsInDB = Invoke-SQLite "SELECT COUNT(*) FROM scripts;"
            $dbSize = (Get-Item $DatabaseFile).Length
            $dbSizeKB = [math]::Round($dbSize / 1KB, 1)
            
            Write-Host "🗄️  Base de données :" -ForegroundColor White
            Write-Host "  Scripts catalogués   : $totalScriptsInDB" -ForegroundColor Gray
            Write-Host "  Taille de la base    : $dbSizeKB KB" -ForegroundColor Gray
            Write-Host "  Fichier              : $DatabaseFile" -ForegroundColor Gray
            Write-Host ""
        }
        catch {
            Write-Warn "Impossible de lire les statistiques de la base"
        }
    }
    
    # Liste des erreurs si présentes
    if ($Stats.Errors -gt 0) {
        Write-Host "❌ Erreurs rencontrées :" -ForegroundColor Red
        foreach ($error in $Stats.ErrorList) {
            Write-Host "  • $error" -ForegroundColor Red
        }
        Write-Host ""
        
        Write-Host "🔧 Actions suggérées :" -ForegroundColor Yellow
        Write-Host "  1. Vérifiez les permissions des fichiers" -ForegroundColor Gray
        Write-Host "  2. Contrôlez la syntaxe des scripts en erreur" -ForegroundColor Gray
        Write-Host "  3. Relancez avec -Force pour forcer la mise à jour" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Message final
    if ($Stats.Errors -eq 0) {
        Write-Success "🎉 Enregistrement terminé avec succès !"
        if (-not $DryRun) {
            Write-Info "Utilisez .\tools\search-db.ps1 -Stats pour voir les statistiques"
        }
    }
    else {
        Write-Error-Custom "⚠️  Enregistrement terminé avec $($Stats.Errors) erreur(s)"
    }
}

# Fonction principale
function Main {
    Write-Info "📚 Enregistrement en masse des scripts dans le catalogue SQLite"
    
    # Vérifications préliminaires
    if (-not (Test-Database)) {
        exit $EXIT_ERROR_DB
    }
    
    if (-not (Test-RegisterScript)) {
        exit $EXIT_ERROR_SCRIPTS
    }
    
    # Mode simulation
    if ($DryRun) {
        Write-Warn "🧪 MODE SIMULATION - Aucune modification ne sera effectuée"
    }
    
    Write-Info "🎯 Configuration:"
    Write-Info "  Répertoire source    : $Path"
    Write-Info "  Pattern de fichiers  : $Include"
    Write-Info "  Répertoires exclus   : $($Exclude -join ', ')"
    Write-Info "  Profondeur max       : $MaxDepth"
    Write-Info ""
    
    # Découverte des scripts
    $scripts = Find-Scripts -SearchPath $Path -Pattern $Include -ExcludeDirs $Exclude -Depth $MaxDepth
    
    if ($scripts.Count -eq 0) {
        Write-Warn "Aucun script trouvé dans $Path"
        exit $EXIT_SUCCESS
    }
    
    Write-Info ""
    Write-Info "🔄 Traitement des scripts..."
    
    # Traitement des scripts
    for ($i = 0; $i -lt $scripts.Count; $i++) {
        $script = $scripts[$i]
        
        if (-not $Quiet) {
            Show-Progress -Current ($i + 1) -Total $scripts.Count -CurrentItem $script.Name
        }
        
        Process-Script $script
    }
    
    # Rapport final
    Show-FinalReport
    
    # Code de sortie selon les résultats
    if ($Stats.Errors -eq 0) {
        exit $EXIT_SUCCESS
    }
    elseif ($Stats.Success -gt 0) {
        exit $EXIT_ERROR_SCRIPTS  # Succès partiel
    }
    else {
        exit $EXIT_ERROR_SCRIPTS  # Échec complet
    }
}

# Point d'entrée
if ($MyInvocation.InvocationName -ne ".") {
    Main
}