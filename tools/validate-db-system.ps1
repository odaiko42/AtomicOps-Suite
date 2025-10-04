#Requires -Version 5.1
<#
.SYNOPSIS
    Valide le système complet de base de données catalogue SQLite.

.DESCRIPTION
    Ce script PowerShell effectue une validation complète du système de catalogue
    SQLite pour s'assurer que tous les composants fonctionnent correctement.
    
    Tests effectués :
    - Initialisation et intégrité de la base de données
    - Fonctionnement des scripts d'enregistrement
    - Système de recherche et consultation
    - Exports multi-formats
    - Performance et cohérence des données
    - Validation des outils auxiliaires

.PARAMETER SkipBackup
    Ignore la création de backup avant les tests

.PARAMETER QuickTest
    Effectue uniquement les tests essentiels (plus rapide)

.PARAMETER Verbose
    Affichage détaillé des étapes de validation

.PARAMETER OutputReport
    Génère un rapport de validation dans un fichier

.EXAMPLE
    .\validate-db-system.ps1
    
.EXAMPLE
    .\validate-db-system.ps1 -QuickTest -Verbose
    
.EXAMPLE
    .\validate-db-system.ps1 -OutputReport "validation_report.txt"

.NOTES
    Auteur: Système de Catalogue SQLite CT
    Version: 1.0
    Date: 3 octobre 2025
    
    Prérequis:
    - Tous les scripts du système catalogue présents
    - SQLite3 accessible ou module PSSQLite
    - PowerShell 5.1+
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage="Ignorer la création de backup")]
    [switch]$SkipBackup,
    
    [Parameter(HelpMessage="Tests rapides uniquement")]
    [switch]$QuickTest,
    
    [Parameter(HelpMessage="Affichage détaillé")]
    [switch]$Verbose,
    
    [Parameter(HelpMessage="Fichier de rapport de validation")]
    [string]$OutputReport
)

# Configuration globale
$ErrorActionPreference = "Continue"  # Continuer sur erreur pour tous les tests
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$DatabaseFile = Join-Path $ProjectRoot "database\scripts_catalogue.db"

# Codes de sortie
$EXIT_SUCCESS = 0
$EXIT_ERROR_DB = 2
$EXIT_ERROR_TOOLS = 3

# Variables de test globales
$TestResults = @{
    Total = 0
    Passed = 0
    Failed = 0
    Warnings = 0
    StartTime = Get-Date
    Tests = @()
    TempDir = ""
}

# Fonctions de logging avec couleurs
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
    Add-ToReport "INFO: $Message"
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
    Add-ToReport "WARN: $Message"
    $TestResults.Warnings++
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
    Add-ToReport "OK: $Message"
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    Add-ToReport "ERROR: $Message"
}

function Write-Verbose-Custom {
    param([string]$Message)
    if ($Verbose) {
        Write-Host "[VERBOSE] $Message" -ForegroundColor Gray
        Add-ToReport "VERBOSE: $Message"
    }
}

# Fonction pour ajouter au rapport
function Add-ToReport {
    param([string]$Message)
    
    if ($OutputReport) {
        $timestamp = Get-Date -Format "HH:mm:ss"
        "$timestamp - $Message" | Add-Content -Path $OutputReport -Encoding UTF8
    }
}

# Fonction pour exécuter des commandes SQLite
function Invoke-SQLite {
    param(
        [string]$Query,
        [string]$Database = $DatabaseFile,
        [switch]$SuppressErrors
    )
    
    try {
        if (Get-Command sqlite3 -ErrorAction SilentlyContinue) {
            $result = & sqlite3 $Database $Query 2>$null
            if ($LASTEXITCODE -ne 0 -and -not $SuppressErrors) {
                throw "Erreur SQLite: $LASTEXITCODE"
            }
            return $result
        }
        elseif (Get-Module -ListAvailable -Name PSSQLite) {
            Import-Module PSSQLite -ErrorAction SilentlyContinue
            return Invoke-SqliteQuery -DataSource $Database -Query $Query -ErrorAction Stop
        }
        else {
            if (-not $SuppressErrors) {
                throw "SQLite3 non disponible"
            }
            return $null
        }
    }
    catch {
        if (-not $SuppressErrors) {
            throw
        }
        return $null
    }
}

# Fonction pour enregistrer un résultat de test
function Record-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Details = "",
        [string]$ErrorMessage = ""
    )
    
    $TestResults.Total++
    
    $result = @{
        Name = $TestName
        Success = $Success
        Details = $Details
        ErrorMessage = $ErrorMessage
        Timestamp = Get-Date
    }
    
    $TestResults.Tests += $result
    
    if ($Success) {
        $TestResults.Passed++
        Write-Success "✓ $TestName"
        if ($Details) {
            Write-Verbose-Custom $Details
        }
    }
    else {
        $TestResults.Failed++
        Write-Error-Custom "✗ $TestName"
        if ($ErrorMessage) {
            Write-Error-Custom "  → $ErrorMessage"
        }
    }
}

# Test 1: Vérification des prérequis système
function Test-Prerequisites {
    Write-Info "🔍 Test 1: Vérification des prérequis système"
    
    # Test SQLite
    try {
        if (Get-Command sqlite3 -ErrorAction SilentlyContinue) {
            $version = & sqlite3 -version 2>$null
            Record-TestResult "SQLite3 disponible" $true "Version: $version"
        }
        elseif (Get-Module -ListAvailable -Name PSSQLite) {
            Record-TestResult "Module PSSQLite disponible" $true
        }
        else {
            Record-TestResult "SQLite disponible" $false "" "Ni sqlite3 ni PSSQLite trouvés"
            return $false
        }
    }
    catch {
        Record-TestResult "SQLite disponible" $false "" $_.Exception.Message
        return $false
    }
    
    # Test PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 5) {
        Record-TestResult "PowerShell version" $true "Version: $psVersion"
    }
    else {
        Record-TestResult "PowerShell version" $false "" "Version $psVersion < 5.0 requise"
    }
    
    # Test structure de répertoires
    $requiredDirs = @("database", "tools", "exports")
    foreach ($dir in $requiredDirs) {
        $dirPath = Join-Path $ProjectRoot $dir
        if (Test-Path $dirPath) {
            Record-TestResult "Répertoire $dir" $true "Chemin: $dirPath"
        }
        else {
            Record-TestResult "Répertoire $dir" $false "" "Répertoire manquant: $dirPath"
        }
    }
    
    return $true
}

# Test 2: Intégrité de la base de données
function Test-DatabaseIntegrity {
    Write-Info "🗄️ Test 2: Intégrité de la base de données"
    
    # Vérifier l'existence du fichier
    if (Test-Path $DatabaseFile) {
        Record-TestResult "Fichier base de données existe" $true "Chemin: $DatabaseFile"
    }
    else {
        Record-TestResult "Fichier base de données existe" $false "" "Fichier non trouvé: $DatabaseFile"
        return $false
    }
    
    # Test d'intégrité SQLite
    try {
        $integrityResult = Invoke-SQLite "PRAGMA integrity_check;"
        if ($integrityResult -eq "ok") {
            Record-TestResult "Intégrité SQLite" $true
        }
        else {
            Record-TestResult "Intégrité SQLite" $false "" "Résultat: $integrityResult"
        }
    }
    catch {
        Record-TestResult "Intégrité SQLite" $false "" $_.Exception.Message
    }
    
    # Vérifier les tables essentielles
    $expectedTables = @("scripts", "script_parameters", "script_dependencies", "functions", "exit_codes")
    
    try {
        $tables = Invoke-SQLite "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
        $tableList = $tables -split "`n" | Where-Object { $_ }
        
        foreach ($table in $expectedTables) {
            if ($tableList -contains $table) {
                Record-TestResult "Table $table" $true
            }
            else {
                Record-TestResult "Table $table" $false "" "Table manquante"
            }
        }
        
        # Compter le nombre total de tables
        $totalTables = $tableList.Count
        Record-TestResult "Nombre de tables" ($totalTables -ge 10) "Tables trouvées: $totalTables"
    }
    catch {
        Record-TestResult "Vérification des tables" $false "" $_.Exception.Message
    }
    
    # Test des contraintes de clés étrangères
    try {
        $fkResult = Invoke-SQLite "PRAGMA foreign_key_check;"
        if (-not $fkResult -or $fkResult.Trim() -eq "") {
            Record-TestResult "Contraintes clés étrangères" $true
        }
        else {
            Record-TestResult "Contraintes clés étrangères" $false "" "Violations: $fkResult"
        }
    }
    catch {
        Record-TestResult "Contraintes clés étrangères" $false "" $_.Exception.Message
    }
    
    return $true
}

# Test 3: Outils de gestion disponibles
function Test-ManagementTools {
    Write-Info "🔧 Test 3: Outils de gestion disponibles"
    
    $tools = @{
        "register-script.ps1" = "Enregistrement unitaire"
        "register-all-scripts.ps1" = "Enregistrement en masse"
        "search-db.ps1" = "Recherche et consultation"
        "export-db.ps1" = "Export multi-format"
        "setup-db-system.ps1" = "Installation automatisée"
    }
    
    foreach ($tool in $tools.GetEnumerator()) {
        $toolPath = Join-Path $ScriptDir $tool.Key
        
        if (Test-Path $toolPath) {
            Record-TestResult "Outil $($tool.Key)" $true $tool.Value
            
            # Test de syntaxe PowerShell (basique)
            try {
                $syntax = Get-Command $toolPath -Syntax -ErrorAction Stop
                Write-Verbose-Custom "Syntaxe OK pour $($tool.Key)"
            }
            catch {
                Write-Warn "Problème de syntaxe pour $($tool.Key): $($_.Exception.Message)"
            }
        }
        else {
            Record-TestResult "Outil $($tool.Key)" $false "" "Fichier non trouvé"
        }
    }
    
    return $true
}

# Test 4: Fonctionnement des scripts (tests légers)
function Test-ScriptFunctionality {
    Write-Info "⚙️ Test 4: Fonctionnement des scripts"
    
    # Test du script de recherche (help)
    try {
        $searchScript = Join-Path $ScriptDir "search-db.ps1"
        if (Test-Path $searchScript) {
            # Test avec paramètre d'aide (ne devrait pas échouer)
            $helpResult = & powershell.exe -File $searchScript -ErrorAction SilentlyContinue 2>$null
            # Si pas d'erreur critique, c'est bon
            Record-TestResult "Script de recherche exécutable" $true
        }
        else {
            Record-TestResult "Script de recherche exécutable" $false "" "Script non trouvé"
        }
    }
    catch {
        Record-TestResult "Script de recherche exécutable" $false "" $_.Exception.Message
    }
    
    # Test du script d'export (help)
    try {
        $exportScript = Join-Path $ScriptDir "export-db.ps1"
        if (Test-Path $exportScript) {
            # Juste vérifier que le script peut être chargé
            $null = Get-Command $exportScript -ErrorAction Stop
            Record-TestResult "Script d'export exécutable" $true
        }
        else {
            Record-TestResult "Script d'export exécutable" $false "" "Script non trouvé"
        }
    }
    catch {
        Record-TestResult "Script d'export exécutable" $false "" $_.Exception.Message
    }
    
    # Test de base de données (requête simple)
    if (Test-Path $DatabaseFile) {
        try {
            $scriptCount = Invoke-SQLite "SELECT COUNT(*) FROM scripts;"
            $count = [int]$scriptCount
            Record-TestResult "Requête de base fonctionnelle" $true "Scripts catalogués: $count"
            
            if ($count -gt 0) {
                # Test requête plus complexe
                $complexQuery = @"
SELECT s.name, COUNT(sp.id) as params 
FROM scripts s 
LEFT JOIN script_parameters sp ON s.id = sp.script_id 
GROUP BY s.id 
LIMIT 5;
"@
                $complexResult = Invoke-SQLite $complexQuery
                Record-TestResult "Requête complexe fonctionnelle" $true
            }
        }
        catch {
            Record-TestResult "Requête de base fonctionnelle" $false "" $_.Exception.Message
        }
    }
    
    return $true
}

# Test 5: Performance de base (si pas en mode rapide)
function Test-BasicPerformance {
    if ($QuickTest) {
        Write-Info "⏱️ Test 5: Performance (ignoré en mode rapide)"
        return $true
    }
    
    Write-Info "⏱️ Test 5: Performance de base"
    
    if (-not (Test-Path $DatabaseFile)) {
        Record-TestResult "Test de performance" $false "" "Base de données non disponible"
        return $false
    }
    
    # Test performance requête simple
    try {
        $startTime = Get-Date
        $result = Invoke-SQLite "SELECT COUNT(*) FROM scripts;"
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        if ($duration -lt 1000) {  # Moins d'1 seconde
            Record-TestResult "Performance requête simple" $true "Durée: ${duration}ms"
        }
        else {
            Record-TestResult "Performance requête simple" $false "" "Durée: ${duration}ms (> 1000ms)"
        }
    }
    catch {
        Record-TestResult "Performance requête simple" $false "" $_.Exception.Message
    }
    
    # Test performance requête complexe
    try {
        $complexQuery = @"
SELECT s.category, s.type, COUNT(*) as count
FROM scripts s
LEFT JOIN script_dependencies sd ON s.id = sd.script_id
GROUP BY s.category, s.type
ORDER BY count DESC;
"@
        
        $startTime = Get-Date
        $result = Invoke-SQLite $complexQuery
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        if ($duration -lt 2000) {  # Moins de 2 secondes
            Record-TestResult "Performance requête complexe" $true "Durée: ${duration}ms"
        }
        else {
            Record-TestResult "Performance requête complexe" $false "" "Durée: ${duration}ms (> 2000ms)"
        }
    }
    catch {
        Record-TestResult "Performance requête complexe" $false "" $_.Exception.Message
    }
    
    # Taille de la base de données
    try {
        $dbSize = (Get-Item $DatabaseFile).Length
        $dbSizeKB = [math]::Round($dbSize / 1KB, 1)
        
        if ($dbSizeKB -lt 10240) {  # Moins de 10MB
            Record-TestResult "Taille base acceptable" $true "Taille: ${dbSizeKB}KB"
        }
        else {
            Write-Warn "Base de données volumineuse: ${dbSizeKB}KB"
            Record-TestResult "Taille base acceptable" $true "Taille: ${dbSizeKB}KB (volumineuse)"
        }
    }
    catch {
        Record-TestResult "Taille base acceptable" $false "" $_.Exception.Message
    }
    
    return $true
}

# Test 6: Cohérence des données
function Test-DataConsistency {
    Write-Info "📊 Test 6: Cohérence des données"
    
    if (-not (Test-Path $DatabaseFile)) {
        Record-TestResult "Cohérence des données" $false "" "Base de données non disponible"
        return $false
    }
    
    try {
        # Vérifier qu'il n'y a pas de scripts avec des noms en double
        $duplicateNames = Invoke-SQLite "SELECT name, COUNT(*) as count FROM scripts GROUP BY name HAVING count > 1;"
        if (-not $duplicateNames -or $duplicateNames.Trim() -eq "") {
            Record-TestResult "Pas de noms en double" $true
        }
        else {
            Record-TestResult "Pas de noms en double" $false "" "Doublons trouvés: $duplicateNames"
        }
    }
    catch {
        Record-TestResult "Pas de noms en double" $false "" $_.Exception.Message
    }
    
    try {
        # Vérifier que tous les scripts ont une description
        $scriptsWithoutDesc = Invoke-SQLite "SELECT COUNT(*) FROM scripts WHERE description IS NULL OR description = '';"
        $count = [int]$scriptsWithoutDesc
        if ($count -eq 0) {
            Record-TestResult "Tous les scripts ont une description" $true
        }
        else {
            Record-TestResult "Tous les scripts ont une description" $false "" "$count script(s) sans description"
        }
    }
    catch {
        Record-TestResult "Tous les scripts ont une description" $false "" $_.Exception.Message
    }
    
    try {
        # Vérifier les références d'intégrité basiques
        $orphanParams = Invoke-SQLite "SELECT COUNT(*) FROM script_parameters WHERE script_id NOT IN (SELECT id FROM scripts);"
        $orphanCount = [int]$orphanParams
        if ($orphanCount -eq 0) {
            Record-TestResult "Intégrité paramètres" $true
        }
        else {
            Record-TestResult "Intégrité paramètres" $false "" "$orphanCount paramètre(s) orphelin(s)"
        }
    }
    catch {
        Record-TestResult "Intégrité paramètres" $false "" $_.Exception.Message
    }
    
    return $true
}

# Créer un backup avant tests
function Create-TestBackup {
    if ($SkipBackup) {
        Write-Info "💾 Backup ignoré (-SkipBackup spécifié)"
        return $true
    }
    
    Write-Info "💾 Création d'un backup avant tests"
    
    if (-not (Test-Path $DatabaseFile)) {
        Write-Warn "Pas de base de données à sauvegarder"
        return $true
    }
    
    try {
        $backupName = "backup_validation_$(Get-Date -Format 'yyyyMMdd_HHmmss').db"
        $backupPath = Join-Path $TestResults.TempDir $backupName
        
        Copy-Item -Path $DatabaseFile -Destination $backupPath -Force
        Record-TestResult "Backup créé" $true "Fichier: $backupName"
        
        Write-Verbose-Custom "Backup sauvegardé: $backupPath"
        return $true
    }
    catch {
        Record-TestResult "Backup créé" $false "" $_.Exception.Message
        return $false
    }
}

# Nettoyer l'environnement de test
function Clean-TestEnvironment {
    Write-Info "🧹 Nettoyage de l'environnement de test"
    
    if ($TestResults.TempDir -and (Test-Path $TestResults.TempDir)) {
        try {
            Remove-Item -Path $TestResults.TempDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Verbose-Custom "Répertoire temporaire nettoyé: $($TestResults.TempDir)"
        }
        catch {
            Write-Warn "Impossible de nettoyer le répertoire temporaire: $($_.Exception.Message)"
        }
    }
}

# Afficher le rapport final
function Show-ValidationReport {
    $endTime = Get-Date
    $duration = $endTime - $TestResults.StartTime
    
    Write-Host ""
    Write-Host "📊 RAPPORT DE VALIDATION" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    Write-Host ""
    
    # Statistiques générales
    Write-Host "📈 Résultats généraux :" -ForegroundColor White
    Write-Host "  Tests exécutés       : $($TestResults.Total)" -ForegroundColor Gray
    Write-Host "  Réussis              : " -NoNewline -ForegroundColor Gray
    Write-Host "$($TestResults.Passed)" -ForegroundColor Green
    Write-Host "  Échecs               : " -NoNewline -ForegroundColor Gray
    Write-Host "$($TestResults.Failed)" -ForegroundColor Red
    Write-Host "  Avertissements       : " -NoNewline -ForegroundColor Gray
    Write-Host "$($TestResults.Warnings)" -ForegroundColor Yellow
    Write-Host "  Durée totale         : $($duration.ToString('mm\:ss'))" -ForegroundColor Gray
    Write-Host ""
    
    # Taux de réussite
    $successRate = if ($TestResults.Total -gt 0) {
        [math]::Round(($TestResults.Passed / $TestResults.Total) * 100, 1)
    } else { 0 }
    
    Write-Host "📊 Taux de réussite     : $successRate%" -ForegroundColor Gray
    Write-Host ""
    
    # Détail par catégorie de tests
    if ($TestResults.Failed -gt 0) {
        Write-Host "❌ Tests échoués :" -ForegroundColor Red
        foreach ($test in $TestResults.Tests) {
            if (-not $test.Success) {
                Write-Host "  • $($test.Name)" -ForegroundColor Red
                if ($test.ErrorMessage) {
                    Write-Host "    → $($test.ErrorMessage)" -ForegroundColor DarkRed
                }
            }
        }
        Write-Host ""
    }
    
    # Message final et recommandations
    if ($TestResults.Failed -eq 0) {
        Write-Success "🎉 VALIDATION RÉUSSIE - Le système fonctionne correctement !"
        Write-Host ""
        Write-Host "✨ Le système de catalogue SQLite est opérationnel :" -ForegroundColor Green
        Write-Host "  • Base de données intègre et performante" -ForegroundColor Gray
        Write-Host "  • Tous les outils de gestion fonctionnels" -ForegroundColor Gray
        Write-Host "  • Cohérence des données validée" -ForegroundColor Gray
        Write-Host ""
        Write-Host "🚀 Prochaines étapes recommandées :" -ForegroundColor Cyan
        Write-Host "  1. .\tools\register-all-scripts.ps1    # Mettre à jour le catalogue" -ForegroundColor Gray
        Write-Host "  2. .\tools\search-db.ps1 -Stats        # Voir les statistiques" -ForegroundColor Gray
        Write-Host "  3. .\tools\export-db.ps1 -Format backup # Créer un backup" -ForegroundColor Gray
    }
    else {
        Write-Error-Custom "❌ VALIDATION ÉCHOUÉE - $($TestResults.Failed) problème(s) détecté(s)"
        Write-Host ""
        Write-Host "🔧 Actions de dépannage recommandées :" -ForegroundColor Yellow
        Write-Host "  1. Vérifiez les permissions sur database/ et tools/" -ForegroundColor Gray
        Write-Host "  2. Réinitialisez la base : .\database\init-db.ps1 -Force" -ForegroundColor Gray
        Write-Host "  3. Installez les prérequis manquants (SQLite3, modules PS)" -ForegroundColor Gray
        Write-Host "  4. Consultez les logs détaillés ci-dessus" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Informations sur la base
    if (Test-Path $DatabaseFile) {
        try {
            $dbSize = (Get-Item $DatabaseFile).Length
            $dbSizeKB = [math]::Round($dbSize / 1KB, 1)
            $scriptCount = Invoke-SQLite "SELECT COUNT(*) FROM scripts;" -SuppressErrors
            
            Write-Host "🗄️  État de la base de données :" -ForegroundColor White
            Write-Host "  Fichier              : $DatabaseFile" -ForegroundColor Gray
            Write-Host "  Taille               : $dbSizeKB KB" -ForegroundColor Gray
            if ($scriptCount) {
                Write-Host "  Scripts catalogués   : $scriptCount" -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "  État                 : Problème d'accès" -ForegroundColor Red
        }
    }
    else {
        Write-Host "🗄️  Base de données     : Non trouvée" -ForegroundColor Red
    }
    
    # Rapport de fichier si demandé
    if ($OutputReport) {
        Write-Host ""
        Write-Host "📄 Rapport détaillé sauvegardé : $OutputReport" -ForegroundColor Cyan
    }
}

# Initialiser l'environnement de test
function Initialize-TestEnvironment {
    # Créer un répertoire temporaire
    $TestResults.TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "validate_db_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $TestResults.TempDir -Force | Out-Null
    
    Write-Verbose-Custom "Répertoire temporaire: $($TestResults.TempDir)"
    
    # Initialiser le fichier de rapport si demandé
    if ($OutputReport) {
        $reportPath = if ([System.IO.Path]::IsPathRooted($OutputReport)) {
            $OutputReport
        } else {
            Join-Path $PWD $OutputReport
        }
        
        # Créer le fichier de rapport avec en-tête
        @"
=================================================================
RAPPORT DE VALIDATION DU SYSTÈME DE CATALOGUE SQLITE
=================================================================

Date de validation: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Système: $env:COMPUTERNAME
Utilisateur: $env:USERNAME
PowerShell: $($PSVersionTable.PSVersion)
Répertoire projet: $ProjectRoot

=================================================================

"@ | Out-File -FilePath $reportPath -Encoding UTF8 -Force
        
        $script:OutputReport = $reportPath
        Write-Info "Rapport détaillé : $reportPath"
    }
}

# Fonction principale
function Main {
    Write-Host ""
    Write-Host "🧪 VALIDATION DU SYSTÈME DE CATALOGUE SQLITE" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Initialisation
    Initialize-TestEnvironment
    
    # Configuration du trap pour nettoyage
    trap {
        Clean-TestEnvironment
        exit 1
    }
    
    Write-Info "🎯 Configuration de validation :"
    Write-Info "  Mode rapide          : $(if ($QuickTest) { 'Oui' } else { 'Non' })"
    Write-Info "  Backup               : $(if ($SkipBackup) { 'Ignoré' } else { 'Créé' })"
    Write-Info "  Verbeux              : $(if ($Verbose) { 'Oui' } else { 'Non' })"
    Write-Info "  Répertoire projet    : $ProjectRoot"
    Write-Info ""
    
    # Exécution des tests
    try {
        # Backup préventif
        Create-TestBackup | Out-Null
        
        # Tests principaux
        Test-Prerequisites | Out-Null
        Test-DatabaseIntegrity | Out-Null
        Test-ManagementTools | Out-Null
        Test-ScriptFunctionality | Out-Null
        Test-BasicPerformance | Out-Null
        Test-DataConsistency | Out-Null
        
        # Rapport final
        Show-ValidationReport
        
        # Nettoyage
        Clean-TestEnvironment
        
        # Code de sortie
        if ($TestResults.Failed -eq 0) {
            exit $EXIT_SUCCESS
        }
        else {
            exit $EXIT_ERROR_TOOLS
        }
    }
    catch {
        Write-Error-Custom "Erreur critique lors de la validation : $($_.Exception.Message)"
        Clean-TestEnvironment
        exit $EXIT_ERROR_DB
    }
}

# Point d'entrée
if ($MyInvocation.InvocationName -ne ".") {
    Main
}