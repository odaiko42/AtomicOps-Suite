#Requires -Version 5.1
<#
.SYNOPSIS
    Interface de recherche et consultation du catalogue SQLite de scripts.

.DESCRIPTION
    Ce script PowerShell fournit une interface complète pour rechercher et consulter
    les scripts enregistrés dans la base de données catalogue.
    
    Fonctionnalités :
    - Recherche par nom, type, catégorie, description
    - Affichage détaillé des métadonnées
    - Analyse des dépendances et graphiques
    - Statistiques globales et par catégorie
    - Export des résultats de recherche
    - Interface interactive et en ligne de commande

.PARAMETER All
    Affiche tous les scripts du catalogue

.PARAMETER Name
    Recherche par nom de script (support des wildcards)

.PARAMETER Type
    Filtre par type de script (atomic, orchestrator, library, creator, etc.)

.PARAMETER Category
    Filtre par catégorie (usb, ct, network, system, etc.)

.PARAMETER Description
    Recherche dans les descriptions (texte libre)

.PARAMETER Info
    Affiche les informations détaillées d'un script spécifique

.PARAMETER Dependencies
    Affiche les dépendances d'un script

.PARAMETER Stats
    Affiche les statistiques globales du catalogue

.PARAMETER Interactive
    Mode interactif avec menu de navigation

.PARAMETER Format
    Format de sortie (table, list, json, csv)

.PARAMETER Output
    Fichier de sortie pour les résultats

.EXAMPLE
    .\search-db.ps1 -All
    
.EXAMPLE
    .\search-db.ps1 -Name "*usb*" -Type atomic
    
.EXAMPLE
    .\search-db.ps1 -Info "setup-usb-storage.sh"
    
.EXAMPLE
    .\search-db.ps1 -Stats -Format json -Output stats.json

.NOTES
    Auteur: Système de Catalogue SQLite CT
    Version: 1.0
    Date: 3 octobre 2025
    
    Prérequis:
    - SQLite3 accessible ou module PSSQLite
    - Base de données catalogue initialisée
#>

[CmdletBinding(DefaultParameterSetName="Search")]
param(
    [Parameter(ParameterSetName="All", HelpMessage="Afficher tous les scripts")]
    [switch]$All,
    
    [Parameter(ParameterSetName="Search", HelpMessage="Nom du script (wildcards supportés)")]
    [string]$Name,
    
    [Parameter(ParameterSetName="Search", HelpMessage="Type de script")]
    [ValidateSet("atomic", "orchestrator", "library", "creator", "script", "tool")]
    [string]$Type,
    
    [Parameter(ParameterSetName="Search", HelpMessage="Catégorie du script")]
    [ValidateSet("usb", "ct", "network", "system", "database", "other")]
    [string]$Category,
    
    [Parameter(ParameterSetName="Search", HelpMessage="Recherche dans les descriptions")]
    [string]$Description,
    
    [Parameter(ParameterSetName="Info", Mandatory=$true, HelpMessage="Nom du script pour info détaillée")]
    [string]$Info,
    
    [Parameter(ParameterSetName="Dependencies", Mandatory=$true, HelpMessage="Afficher les dépendances")]
    [string]$Dependencies,
    
    [Parameter(ParameterSetName="Stats", HelpMessage="Statistiques globales")]
    [switch]$Stats,
    
    [Parameter(ParameterSetName="Interactive", HelpMessage="Mode interactif")]
    [switch]$Interactive,
    
    [Parameter(HelpMessage="Format de sortie")]
    [ValidateSet("table", "list", "json", "csv")]
    [string]$Format = "table",
    
    [Parameter(HelpMessage="Fichier de sortie")]
    [string]$Output,
    
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
$EXIT_ERROR_ARGS = 1
$EXIT_ERROR_DB = 2
$EXIT_ERROR_NOTFOUND = 3

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
        [switch]$AsObject
    )
    
    try {
        if (Get-Command sqlite3 -ErrorAction SilentlyContinue) {
            if ($AsObject) {
                # Mode JSON pour les objets structurés
                $result = & sqlite3 $Database ".mode json" $Query 2>$null
                if ($LASTEXITCODE -ne 0) {
                    throw "Erreur SQLite: $LASTEXITCODE"
                }
                return ($result | ConvertFrom-Json)
            }
            else {
                # Mode texte normal
                $result = & sqlite3 $Database $Query 2>$null
                if ($LASTEXITCODE -ne 0) {
                    throw "Erreur SQLite: $LASTEXITCODE"
                }
                return $result
            }
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
        Write-Error-Custom "Erreur SQLite: $_"
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

# Fonction pour construire une requête de recherche
function Build-SearchQuery {
    param(
        [string]$NamePattern,
        [string]$TypeFilter,
        [string]$CategoryFilter,
        [string]$DescriptionFilter
    )
    
    $whereConditions = @()
    
    if ($NamePattern) {
        # Convertir les wildcards PowerShell en SQL LIKE
        $sqlPattern = $NamePattern.Replace('*', '%').Replace('?', '_')
        $whereConditions += "s.name LIKE '$sqlPattern'"
    }
    
    if ($TypeFilter) {
        $whereConditions += "s.type = '$TypeFilter'"
    }
    
    if ($CategoryFilter) {
        $whereConditions += "s.category = '$CategoryFilter'"
    }
    
    if ($DescriptionFilter) {
        $whereConditions += "s.description LIKE '%$DescriptionFilter%'"
    }
    
    $baseQuery = @"
SELECT 
    s.id,
    s.name,
    s.type,
    s.category,
    s.description,
    s.version,
    s.author,
    s.created_at,
    s.updated_at,
    s.path,
    COUNT(DISTINCT sp.id) as param_count,
    COUNT(DISTINCT sd.id) as dep_count
FROM scripts s
LEFT JOIN script_parameters sp ON s.id = sp.script_id
LEFT JOIN script_dependencies sd ON s.id = sd.script_id
"@
    
    if ($whereConditions.Count -gt 0) {
        $baseQuery += "`nWHERE " + ($whereConditions -join " AND ")
    }
    
    $baseQuery += @"

GROUP BY s.id, s.name, s.type, s.category, s.description, s.version, s.author, s.created_at, s.updated_at, s.path
ORDER BY s.category, s.type, s.name;
"@
    
    return $baseQuery
}

# Fonction pour afficher les résultats en tableau
function Show-ResultsTable {
    param([array]$Results)
    
    if ($Results.Count -eq 0) {
        Write-Warn "Aucun résultat trouvé"
        return
    }
    
    Write-Host ""
    Write-Host "📋 Résultats de recherche ($($Results.Count) script(s))" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Gray
    
    # En-têtes
    $format = "{0,-25} {1,-12} {2,-10} {3,-8} {4,-30}"
    Write-Host ($format -f "Nom", "Type", "Catégorie", "Params", "Description") -ForegroundColor White
    Write-Host ("-" * 80) -ForegroundColor Gray
    
    # Données
    foreach ($script in $Results) {
        $name = if ($script.name.Length -gt 24) { $script.name.Substring(0, 21) + "..." } else { $script.name }
        $desc = if ($script.description.Length -gt 29) { $script.description.Substring(0, 26) + "..." } else { $script.description }
        
        $color = switch ($script.type) {
            "atomic" { "Green" }
            "orchestrator" { "Blue" }
            "library" { "Magenta" }
            "creator" { "Yellow" }
            default { "Gray" }
        }
        
        Write-Host ($format -f $name, $script.type, $script.category, $script.param_count, $desc) -ForegroundColor $color
    }
    
    Write-Host ""
}

# Fonction pour afficher les résultats en liste détaillée
function Show-ResultsList {
    param([array]$Results)
    
    if ($Results.Count -eq 0) {
        Write-Warn "Aucun résultat trouvé"
        return
    }
    
    Write-Host ""
    Write-Host "📋 Résultats détaillés ($($Results.Count) script(s))" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Gray
    
    foreach ($script in $Results) {
        Write-Host ""
        Write-Host "📄 $($script.name)" -ForegroundColor White
        Write-Host "   Type        : $($script.type)" -ForegroundColor Gray
        Write-Host "   Catégorie   : $($script.category)" -ForegroundColor Gray
        Write-Host "   Version     : $($script.version)" -ForegroundColor Gray
        Write-Host "   Auteur      : $($script.author)" -ForegroundColor Gray
        Write-Host "   Paramètres  : $($script.param_count)" -ForegroundColor Gray
        Write-Host "   Dépendances : $($script.dep_count)" -ForegroundColor Gray
        Write-Host "   Description : $($script.description)" -ForegroundColor Gray
        Write-Host "   Chemin      : $($script.path)" -ForegroundColor Gray
        Write-Host "   Créé        : $($script.created_at)" -ForegroundColor Gray
    }
    
    Write-Host ""
}

# Fonction pour afficher les informations détaillées d'un script
function Show-ScriptInfo {
    param([string]$ScriptName)
    
    try {
        # Requête principale pour le script
        $query = @"
SELECT 
    s.*,
    COUNT(DISTINCT sp.id) as param_count,
    COUNT(DISTINCT sd.id) as dep_count,
    COUNT(DISTINCT suf.function_id) as func_count
FROM scripts s
LEFT JOIN script_parameters sp ON s.id = sp.script_id
LEFT JOIN script_dependencies sd ON s.id = sd.script_id
LEFT JOIN script_uses_functions suf ON s.id = suf.script_id
WHERE s.name = '$ScriptName'
GROUP BY s.id;
"@
        
        $script = Invoke-SQLite $query
        if (-not $script) {
            Write-Error-Custom "Script '$ScriptName' non trouvé dans le catalogue"
            return $false
        }
        
        # Affichage des informations principales
        Write-Host ""
        Write-Host "📄 INFORMATIONS DÉTAILLÉES" -ForegroundColor Cyan
        Write-Host "=" * 50 -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "🏷️  Identité :" -ForegroundColor White
        Write-Host "   Nom          : $($script[1])" -ForegroundColor Gray  # name
        Write-Host "   Type         : $($script[3])" -ForegroundColor Gray  # type
        Write-Host "   Catégorie    : $($script[4])" -ForegroundColor Gray  # category
        Write-Host "   Version      : $($script[6])" -ForegroundColor Gray  # version
        Write-Host "   Auteur       : $($script[7])" -ForegroundColor Gray  # author
        Write-Host ""
        
        Write-Host "📝 Description :" -ForegroundColor White
        Write-Host "   $($script[5])" -ForegroundColor Gray  # description
        Write-Host ""
        
        Write-Host "📊 Statistiques :" -ForegroundColor White
        Write-Host "   Paramètres   : $($script[12])" -ForegroundColor Gray  # param_count
        Write-Host "   Dépendances  : $($script[13])" -ForegroundColor Gray  # dep_count
        Write-Host "   Fonctions    : $($script[14])" -ForegroundColor Gray  # func_count
        Write-Host ""
        
        Write-Host "📂 Fichier :" -ForegroundColor White
        Write-Host "   Chemin       : $($script[2])" -ForegroundColor Gray  # path
        Write-Host "   Créé le      : $($script[8])" -ForegroundColor Gray  # created_at
        Write-Host "   Modifié le   : $($script[9])" -ForegroundColor Gray  # updated_at
        Write-Host ""
        
        # Paramètres détaillés
        $scriptId = $script[0]  # id
        $params = Invoke-SQLite "SELECT name, description, required, default_value FROM script_parameters WHERE script_id = $scriptId ORDER BY name;"
        
        if ($params) {
            Write-Host "⚙️  Paramètres :" -ForegroundColor White
            $paramLines = $params -split "`n" | Where-Object { $_ }
            foreach ($paramLine in $paramLines) {
                $parts = $paramLine -split "\|"
                if ($parts.Count -ge 2) {
                    $required = if ($parts[2] -eq "1") { " (requis)" } else { "" }
                    $default = if ($parts[3]) { " [défaut: $($parts[3])]" } else { "" }
                    Write-Host "   • $($parts[0])$required$default" -ForegroundColor Gray
                    if ($parts[1]) {
                        Write-Host "     $($parts[1])" -ForegroundColor DarkGray
                    }
                }
            }
            Write-Host ""
        }
        
        # Dépendances
        $deps = Invoke-SQLite "SELECT dependency_name, dependency_type FROM script_dependencies WHERE script_id = $scriptId ORDER BY dependency_name;"
        
        if ($deps) {
            Write-Host "🔗 Dépendances :" -ForegroundColor White
            $depLines = $deps -split "`n" | Where-Object { $_ }
            foreach ($depLine in $depLines) {
                $parts = $depLine -split "\|"
                if ($parts.Count -ge 2) {
                    Write-Host "   • $($parts[0]) ($($parts[1]))" -ForegroundColor Gray
                }
            }
            Write-Host ""
        }
        
        # Fonctions utilisées
        $funcs = Invoke-SQLite @"
SELECT f.name, f.description 
FROM functions f 
JOIN script_uses_functions suf ON f.id = suf.function_id 
WHERE suf.script_id = $scriptId 
ORDER BY f.name;
"@
        
        if ($funcs) {
            Write-Host "🔧 Fonctions utilisées :" -ForegroundColor White
            $funcLines = $funcs -split "`n" | Where-Object { $_ }
            foreach ($funcLine in $funcLines) {
                $parts = $funcLine -split "\|"
                if ($parts.Count -ge 1) {
                    Write-Host "   • $($parts[0])" -ForegroundColor Gray
                    if ($parts.Count -ge 2 -and $parts[1]) {
                        Write-Host "     $($parts[1])" -ForegroundColor DarkGray
                    }
                }
            }
            Write-Host ""
        }
        
        # Codes de sortie
        $exitCodes = Invoke-SQLite "SELECT code, description FROM exit_codes WHERE script_id = $scriptId ORDER BY code;"
        
        if ($exitCodes) {
            Write-Host "🚪 Codes de sortie :" -ForegroundColor White
            $codeLines = $exitCodes -split "`n" | Where-Object { $_ }
            foreach ($codeLine in $codeLines) {
                $parts = $codeLine -split "\|"
                if ($parts.Count -ge 2) {
                    Write-Host "   • Code $($parts[0]): $($parts[1])" -ForegroundColor Gray
                }
            }
            Write-Host ""
        }
        
        return $true
    }
    catch {
        Write-Error-Custom "Erreur lors de la récupération des informations: $_"
        return $false
    }
}

# Fonction pour afficher les statistiques globales
function Show-GlobalStats {
    try {
        Write-Host ""
        Write-Host "📊 STATISTIQUES DU CATALOGUE" -ForegroundColor Cyan
        Write-Host "=" * 40 -ForegroundColor Gray
        Write-Host ""
        
        # Statistiques générales
        $totalScripts = Invoke-SQLite "SELECT COUNT(*) FROM scripts;"
        $totalFunctions = Invoke-SQLite "SELECT COUNT(*) FROM functions;"
        $totalDeps = Invoke-SQLite "SELECT COUNT(*) FROM script_dependencies;"
        
        Write-Host "📈 Vue d'ensemble :" -ForegroundColor White
        Write-Host "   Scripts catalogués    : $totalScripts" -ForegroundColor Gray
        Write-Host "   Fonctions répertoriées: $totalFunctions" -ForegroundColor Gray
        Write-Host "   Dépendances totales   : $totalDeps" -ForegroundColor Gray
        Write-Host ""
        
        # Répartition par type
        $typeStats = Invoke-SQLite "SELECT type, COUNT(*) as count FROM scripts GROUP BY type ORDER BY count DESC;"
        
        if ($typeStats) {
            Write-Host "🏷️  Répartition par type :" -ForegroundColor White
            $typeLines = $typeStats -split "`n" | Where-Object { $_ }
            foreach ($typeLine in $typeLines) {
                $parts = $typeLine -split "\|"
                if ($parts.Count -eq 2) {
                    $percentage = [math]::Round(([int]$parts[1] / [int]$totalScripts) * 100, 1)
                    Write-Host "   • $($parts[0].PadRight(12)): $($parts[1].PadLeft(3)) scripts ($percentage%)" -ForegroundColor Gray
                }
            }
            Write-Host ""
        }
        
        # Répartition par catégorie
        $categoryStats = Invoke-SQLite "SELECT category, COUNT(*) as count FROM scripts GROUP BY category ORDER BY count DESC;"
        
        if ($categoryStats) {
            Write-Host "📂 Répartition par catégorie :" -ForegroundColor White
            $categoryLines = $categoryStats -split "`n" | Where-Object { $_ }
            foreach ($categoryLine in $categoryLines) {
                $parts = $categoryLine -split "\|"
                if ($parts.Count -eq 2) {
                    $percentage = [math]::Round(([int]$parts[1] / [int]$totalScripts) * 100, 1)
                    Write-Host "   • $($parts[0].PadRight(12)): $($parts[1].PadLeft(3)) scripts ($percentage%)" -ForegroundColor Gray
                }
            }
            Write-Host ""
        }
        
        # Top 5 des scripts avec le plus de dépendances
        $topDeps = Invoke-SQLite @"
SELECT s.name, COUNT(sd.id) as dep_count 
FROM scripts s 
LEFT JOIN script_dependencies sd ON s.id = sd.script_id 
GROUP BY s.id, s.name 
HAVING dep_count > 0
ORDER BY dep_count DESC 
LIMIT 5;
"@
        
        if ($topDeps) {
            Write-Host "🔗 Scripts avec le plus de dépendances :" -ForegroundColor White
            $depLines = $topDeps -split "`n" | Where-Object { $_ }
            foreach ($depLine in $depLines) {
                $parts = $depLine -split "\|"
                if ($parts.Count -eq 2) {
                    Write-Host "   • $($parts[0]): $($parts[1]) dépendance(s)" -ForegroundColor Gray
                }
            }
            Write-Host ""
        }
        
        # Informations sur la base de données
        if (Test-Path $DatabaseFile) {
            $dbSize = (Get-Item $DatabaseFile).Length
            $dbSizeKB = [math]::Round($dbSize / 1KB, 1)
            $lastModified = (Get-Item $DatabaseFile).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            
            Write-Host "🗄️  Base de données :" -ForegroundColor White
            Write-Host "   Taille           : $dbSizeKB KB" -ForegroundColor Gray
            Write-Host "   Dernière modif.  : $lastModified" -ForegroundColor Gray
            Write-Host "   Fichier          : $DatabaseFile" -ForegroundColor Gray
        }
        
        Write-Host ""
        return $true
    }
    catch {
        Write-Error-Custom "Erreur lors du calcul des statistiques: $_"
        return $false
    }
}

# Fonction pour exporter les résultats
function Export-Results {
    param(
        [array]$Results,
        [string]$OutputFile,
        [string]$ExportFormat
    )
    
    if (-not $Results -or $Results.Count -eq 0) {
        Write-Warn "Aucun résultat à exporter"
        return $false
    }
    
    try {
        switch ($ExportFormat.ToLower()) {
            "json" {
                $Results | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputFile -Encoding UTF8
            }
            "csv" {
                $Results | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
            }
            default {
                # Format texte par défaut
                $Results | Format-Table -AutoSize | Out-File -FilePath $OutputFile -Encoding UTF8
            }
        }
        
        Write-Success "Résultats exportés vers: $OutputFile"
        return $true
    }
    catch {
        Write-Error-Custom "Erreur lors de l'export: $_"
        return $false
    }
}

# Mode interactif
function Start-InteractiveMode {
    Write-Host ""
    Write-Host "🔍 MODE INTERACTIF - Recherche dans le catalogue" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Gray
    
    do {
        Write-Host ""
        Write-Host "Options disponibles :" -ForegroundColor White
        Write-Host "  1. Lister tous les scripts" -ForegroundColor Gray
        Write-Host "  2. Rechercher par nom" -ForegroundColor Gray
        Write-Host "  3. Filtrer par type" -ForegroundColor Gray
        Write-Host "  4. Filtrer par catégorie" -ForegroundColor Gray
        Write-Host "  5. Informations détaillées" -ForegroundColor Gray
        Write-Host "  6. Statistiques" -ForegroundColor Gray
        Write-Host "  0. Quitter" -ForegroundColor Gray
        Write-Host ""
        
        $choice = Read-Host "Votre choix"
        
        switch ($choice) {
            "1" {
                $query = Build-SearchQuery
                $results = Invoke-SQLite $query -AsObject
                Show-ResultsTable $results
            }
            "2" {
                $searchName = Read-Host "Nom du script (wildcards * et ? supportés)"
                if ($searchName) {
                    $query = Build-SearchQuery -NamePattern $searchName
                    $results = Invoke-SQLite $query -AsObject
                    Show-ResultsTable $results
                }
            }
            "3" {
                Write-Host "Types disponibles: atomic, orchestrator, library, creator, script, tool" -ForegroundColor Yellow
                $searchType = Read-Host "Type de script"
                if ($searchType) {
                    $query = Build-SearchQuery -TypeFilter $searchType
                    $results = Invoke-SQLite $query -AsObject
                    Show-ResultsTable $results
                }
            }
            "4" {
                Write-Host "Catégories disponibles: usb, ct, network, system, database, other" -ForegroundColor Yellow
                $searchCategory = Read-Host "Catégorie"
                if ($searchCategory) {
                    $query = Build-SearchQuery -CategoryFilter $searchCategory
                    $results = Invoke-SQLite $query -AsObject
                    Show-ResultsTable $results
                }
            }
            "5" {
                $scriptName = Read-Host "Nom du script"
                if ($scriptName) {
                    Show-ScriptInfo $scriptName | Out-Null
                }
            }
            "6" {
                Show-GlobalStats | Out-Null
            }
            "0" {
                Write-Info "Au revoir !"
                break
            }
            default {
                Write-Warn "Choix invalide"
            }
        }
        
        if ($choice -ne "0") {
            Write-Host ""
            Read-Host "Appuyez sur Entrée pour continuer..."
        }
        
    } while ($choice -ne "0")
}

# Fonction principale
function Main {
    # Vérifier la base de données
    if (-not (Test-Database)) {
        exit $EXIT_ERROR_DB
    }
    
    # Mode interactif
    if ($Interactive) {
        Start-InteractiveMode
        exit $EXIT_SUCCESS
    }
    
    # Statistiques globales
    if ($Stats) {
        if (Show-GlobalStats) {
            if ($Output) {
                # TODO: Export des statistiques
                Write-Info "Export des statistiques vers $Output (à implémenter)"
            }
            exit $EXIT_SUCCESS
        }
        else {
            exit $EXIT_ERROR_DB
        }
    }
    
    # Informations détaillées d'un script
    if ($Info) {
        if (Show-ScriptInfo $Info) {
            exit $EXIT_SUCCESS
        }
        else {
            exit $EXIT_ERROR_NOTFOUND
        }
    }
    
    # Dépendances d'un script
    if ($Dependencies) {
        # TODO: Implémenter l'affichage des dépendances
        Write-Info "Affichage des dépendances pour $Dependencies (à implémenter)"
        exit $EXIT_SUCCESS
    }
    
    # Recherche et affichage
    try {
        if ($All -and -not $Name -and -not $Type -and -not $Category -and -not $Description) {
            # Tous les scripts
            $query = Build-SearchQuery
        }
        else {
            # Recherche avec critères
            $query = Build-SearchQuery -NamePattern $Name -TypeFilter $Type -CategoryFilter $Category -DescriptionFilter $Description
        }
        
        $results = Invoke-SQLite $query -AsObject
        
        # Affichage selon le format
        switch ($Format.ToLower()) {
            "table" { Show-ResultsTable $results }
            "list" { Show-ResultsList $results }
            "json" { 
                if ($Output) {
                    Export-Results $results $Output $Format
                }
                else {
                    $results | ConvertTo-Json -Depth 2
                }
            }
            "csv" {
                if ($Output) {
                    Export-Results $results $Output $Format
                }
                else {
                    $results | ConvertTo-Csv -NoTypeInformation
                }
            }
        }
        
        # Export si demandé
        if ($Output -and $Format -in @("table", "list")) {
            Export-Results $results $Output $Format | Out-Null
        }
        
        exit $EXIT_SUCCESS
    }
    catch {
        Write-Error-Custom "Erreur lors de la recherche: $_"
        exit $EXIT_ERROR_DB
    }
}

# Point d'entrée
if ($MyInvocation.InvocationName -ne ".") {
    Main
}