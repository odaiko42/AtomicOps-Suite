#Requires -Version 5.1
<#
.SYNOPSIS
    Système d'export multi-format pour le catalogue SQLite de scripts.

.DESCRIPTION
    Ce script PowerShell permet d'exporter les données du catalogue SQLite
    dans différents formats pour backup, reporting et intégration avec d'autres outils.
    
    Fonctionnalités :
    - Export complet de la base de données
    - Formats multiples : JSON, CSV, SQL, Markdown, XML
    - Backup compressé de la base SQLite
    - Génération de rapports personnalisés
    - Export sélectif par catégorie/type
    - Validation des exports générés

.PARAMETER Format
    Format d'export (json, csv, sql, markdown, xml, backup, all)

.PARAMETER OutputDir
    Répertoire de destination pour les exports (par défaut: exports/)

.PARAMETER Tables
    Tables spécifiques à exporter (par défaut: toutes)

.PARAMETER Category
    Filtrer par catégorie de scripts

.PARAMETER Type
    Filtrer par type de scripts

.PARAMETER Compress
    Compresser les exports générés

.PARAMETER Validate
    Valider les exports après génération

.PARAMETER Force
    Écraser les fichiers existants

.PARAMETER Quiet
    Mode silencieux

.EXAMPLE
    .\export-db.ps1 -Format json
    
.EXAMPLE
    .\export-db.ps1 -Format all -OutputDir "C:\Exports" -Compress
    
.EXAMPLE
    .\export-db.ps1 -Format csv -Category usb -Type atomic

.NOTES
    Auteur: Système de Catalogue SQLite CT
    Version: 1.0
    Date: 3 octobre 2025
    
    Prérequis:
    - SQLite3 accessible ou module PSSQLite
    - Base de données catalogue initialisée
    - PowerShell 5.1+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Format d'export")]
    [ValidateSet("json", "csv", "sql", "markdown", "xml", "backup", "all")]
    [string]$Format,
    
    [Parameter(HelpMessage="Répertoire de sortie")]
    [string]$OutputDir,
    
    [Parameter(HelpMessage="Tables spécifiques à exporter")]
    [string[]]$Tables,
    
    [Parameter(HelpMessage="Filtrer par catégorie")]
    [ValidateSet("usb", "ct", "network", "system", "database", "other")]
    [string]$Category,
    
    [Parameter(HelpMessage="Filtrer par type")]
    [ValidateSet("atomic", "orchestrator", "library", "creator", "script", "tool")]
    [string]$Type,
    
    [Parameter(HelpMessage="Compresser les exports")]
    [switch]$Compress,
    
    [Parameter(HelpMessage="Valider les exports")]
    [switch]$Validate,
    
    [Parameter(HelpMessage="Écraser les fichiers existants")]
    [switch]$Force,
    
    [Parameter(HelpMessage="Mode silencieux")]
    [switch]$Quiet
)

# Configuration globale
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$DatabaseFile = Join-Path $ProjectRoot "database\scripts_catalogue.db"

# Répertoire de sortie par défaut
if (-not $OutputDir) {
    $OutputDir = Join-Path $ProjectRoot "exports"
}

# Créer le répertoire de sortie s'il n'existe pas
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Codes de sortie
$EXIT_SUCCESS = 0
$EXIT_ERROR_ARGS = 1
$EXIT_ERROR_DB = 2
$EXIT_ERROR_EXPORT = 3

# Variables globales
$ExportStats = @{
    TotalExports = 0
    SuccessCount = 0
    ErrorCount = 0
    TotalSize = 0
    StartTime = Get-Date
    Exports = @()
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
        [switch]$AsObject
    )
    
    try {
        if (Get-Command sqlite3 -ErrorAction SilentlyContinue) {
            if ($AsObject) {
                # Mode JSON pour les objets structurés
                $jsonOutput = & sqlite3 $Database ".mode json" $Query 2>$null
                if ($LASTEXITCODE -ne 0) {
                    throw "Erreur SQLite: $LASTEXITCODE"
                }
                if ($jsonOutput) {
                    return ($jsonOutput | ConvertFrom-Json)
                }
                return @()
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

# Fonction pour générer un nom de fichier unique
function Get-ExportFileName {
    param(
        [string]$BaseName,
        [string]$Extension,
        [string]$Directory
    )
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $fileName = "${BaseName}_$timestamp.$Extension"
    return Join-Path $Directory $fileName
}

# Fonction pour construire les filtres WHERE
function Build-WhereClause {
    $conditions = @()
    
    if ($Category) {
        $conditions += "s.category = '$Category'"
    }
    
    if ($Type) {
        $conditions += "s.type = '$Type'"
    }
    
    if ($conditions.Count -gt 0) {
        return "WHERE " + ($conditions -join " AND ")
    }
    
    return ""
}

# Export JSON complet
function Export-ToJson {
    param([string]$OutputPath)
    
    try {
        Write-Info "📄 Génération de l'export JSON..."
        
        $exportData = @{
            metadata = @{
                export_date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                database_file = $DatabaseFile
                total_scripts = [int](Invoke-SQLite "SELECT COUNT(*) FROM scripts;")
                generator = "export-db.ps1"
                version = "1.0"
            }
            scripts = @()
            functions = @()
            dependencies = @()
            statistics = @{}
        }
        
        # Scripts avec détails complets
        $whereClause = Build-WhereClause
        $scriptsQuery = @"
SELECT 
    s.id, s.name, s.path, s.description, s.category, s.type, 
    s.version, s.author, s.created_at, s.updated_at, s.last_modified
FROM scripts s
$whereClause
ORDER BY s.category, s.type, s.name;
"@
        
        $scripts = Invoke-SQLite $scriptsQuery -AsObject
        
        foreach ($script in $scripts) {
            # Paramètres du script
            $parameters = Invoke-SQLite "SELECT name, description, required, default_value FROM script_parameters WHERE script_id = $($script.id);" -AsObject
            
            # Dépendances du script
            $dependencies = Invoke-SQLite "SELECT dependency_name, dependency_type FROM script_dependencies WHERE script_id = $($script.id);" -AsObject
            
            # Codes de sortie
            $exitCodes = Invoke-SQLite "SELECT code, description FROM exit_codes WHERE script_id = $($script.id);" -AsObject
            
            # Fonctions utilisées
            $usedFunctions = Invoke-SQLite @"
SELECT f.name, f.description 
FROM functions f 
JOIN script_uses_functions suf ON f.id = suf.function_id 
WHERE suf.script_id = $($script.id);
"@ -AsObject
            
            $scriptData = @{
                id = $script.id
                name = $script.name
                path = $script.path
                description = $script.description
                category = $script.category
                type = $script.type
                version = $script.version
                author = $script.author
                created_at = $script.created_at
                updated_at = $script.updated_at
                last_modified = $script.last_modified
                parameters = $parameters
                dependencies = $dependencies
                exit_codes = $exitCodes
                functions_used = $usedFunctions
            }
            
            $exportData.scripts += $scriptData
        }
        
        # Fonctions globales
        $exportData.functions = Invoke-SQLite "SELECT * FROM functions ORDER BY name;" -AsObject
        
        # Statistiques globales
        $exportData.statistics = @{
            total_scripts = $exportData.scripts.Count
            total_functions = $exportData.functions.Count
            scripts_by_type = @{}
            scripts_by_category = @{}
        }
        
        # Statistiques par type et catégorie
        $typeStats = Invoke-SQLite "SELECT type, COUNT(*) as count FROM scripts GROUP BY type;" -AsObject
        foreach ($stat in $typeStats) {
            $exportData.statistics.scripts_by_type[$stat.type] = $stat.count
        }
        
        $categoryStats = Invoke-SQLite "SELECT category, COUNT(*) as count FROM scripts GROUP BY category;" -AsObject
        foreach ($stat in $categoryStats) {
            $exportData.statistics.scripts_by_category[$stat.category] = $stat.count
        }
        
        # Sauvegarder en JSON
        $jsonContent = $exportData | ConvertTo-Json -Depth 5
        $jsonContent | Out-File -FilePath $OutputPath -Encoding UTF8
        
        return $true
    }
    catch {
        Write-Error-Custom "Erreur lors de l'export JSON: $_"
        return $false
    }
}

# Export CSV
function Export-ToCsv {
    param([string]$OutputPath)
    
    try {
        Write-Info "📊 Génération de l'export CSV..."
        
        $whereClause = Build-WhereClause
        $query = @"
SELECT 
    s.name,
    s.path,
    s.description,
    s.category,
    s.type,
    s.version,
    s.author,
    s.created_at,
    s.updated_at,
    COUNT(DISTINCT sp.id) as parameters_count,
    COUNT(DISTINCT sd.id) as dependencies_count
FROM scripts s
LEFT JOIN script_parameters sp ON s.id = sp.script_id
LEFT JOIN script_dependencies sd ON s.id = sd.script_id
$whereClause
GROUP BY s.id, s.name, s.path, s.description, s.category, s.type, s.version, s.author, s.created_at, s.updated_at
ORDER BY s.category, s.type, s.name;
"@
        
        $data = Invoke-SQLite $query -AsObject
        
        # Exporter en CSV
        $data | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        
        return $true
    }
    catch {
        Write-Error-Custom "Erreur lors de l'export CSV: $_"
        return $false
    }
}

# Export SQL (dump)
function Export-ToSql {
    param([string]$OutputPath)
    
    try {
        Write-Info "🗄️ Génération de l'export SQL...")
        
        # Utiliser sqlite3 pour faire un dump SQL complet
        if (Get-Command sqlite3 -ErrorAction SilentlyContinue) {
            $dumpContent = & sqlite3 $DatabaseFile ".dump" 2>$null
            if ($LASTEXITCODE -eq 0) {
                # Ajouter un en-tête avec métadonnées
                $header = @"
-- ================================================================
-- Export SQL du Catalogue de Scripts CT
-- Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
-- Base source: $DatabaseFile
-- Généré par: export-db.ps1
-- ================================================================

"@
                ($header + ($dumpContent -join "`n")) | Out-File -FilePath $OutputPath -Encoding UTF8
                return $true
            }
        }
        
        Write-Error-Custom "Impossible de générer le dump SQL"
        return $false
    }
    catch {
        Write-Error-Custom "Erreur lors de l'export SQL: $_"
        return $false
    }
}

# Export Markdown (rapport)
function Export-ToMarkdown {
    param([string]$OutputPath)
    
    try {
        Write-Info "📝 Génération du rapport Markdown..."
        
        $content = @()
        $content += "# Catalogue de Scripts CT"
        $content += ""
        $content += "**Date d'export:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
        $content += "**Base source:** ``$DatabaseFile``"
        $content += ""
        
        # Statistiques générales
        $totalScripts = Invoke-SQLite "SELECT COUNT(*) FROM scripts;"
        $totalFunctions = Invoke-SQLite "SELECT COUNT(*) FROM functions;"
        
        $content += "## 📊 Statistiques Générales"
        $content += ""
        $content += "| Métrique | Valeur |"
        $content += "|----------|--------|"
        $content += "| Scripts catalogués | $totalScripts |"
        $content += "| Fonctions répertoriées | $totalFunctions |"
        $content += ""
        
        # Répartition par type
        $typeStats = Invoke-SQLite "SELECT type, COUNT(*) as count FROM scripts GROUP BY type ORDER BY count DESC;"
        
        if ($typeStats) {
            $content += "## 🏷️ Répartition par Type"
            $content += ""
            $content += "| Type | Nombre | Pourcentage |"
            $content += "|------|--------|-------------|"
            
            $typeLines = $typeStats -split "`n" | Where-Object { $_ }
            foreach ($line in $typeLines) {
                $parts = $line -split "\|"
                if ($parts.Count -eq 2) {
                    $percentage = [math]::Round(([int]$parts[1] / [int]$totalScripts) * 100, 1)
                    $content += "| $($parts[0]) | $($parts[1]) | $percentage% |"
                }
            }
            $content += ""
        }
        
        # Répartition par catégorie
        $categoryStats = Invoke-SQLite "SELECT category, COUNT(*) as count FROM scripts GROUP BY category ORDER BY count DESC;"
        
        if ($categoryStats) {
            $content += "## 📂 Répartition par Catégorie"
            $content += ""
            $content += "| Catégorie | Nombre | Pourcentage |"
            $content += "|-----------|--------|-------------|"
            
            $categoryLines = $categoryStats -split "`n" | Where-Object { $_ }
            foreach ($line in $categoryLines) {
                $parts = $line -split "\|"
                if ($parts.Count -eq 2) {
                    $percentage = [math]::Round(([int]$parts[1] / [int]$totalScripts) * 100, 1)
                    $content += "| $($parts[0]) | $($parts[1]) | $percentage% |"
                }
            }
            $content += ""
        }
        
        # Liste détaillée des scripts
        $whereClause = Build-WhereClause
        $scriptsQuery = @"
SELECT 
    s.name, s.description, s.category, s.type, s.version, s.author
FROM scripts s
$whereClause
ORDER BY s.category, s.type, s.name;
"@
        
        $scripts = Invoke-SQLite $scriptsQuery -AsObject
        
        if ($scripts) {
            $content += "## 📋 Liste des Scripts"
            $content += ""
            $content += "| Nom | Type | Catégorie | Version | Description |"
            $content += "|-----|------|-----------|---------|-------------|"
            
            foreach ($script in $scripts) {
                $desc = if ($script.description.Length -gt 50) {
                    $script.description.Substring(0, 47) + "..."
                } else {
                    $script.description
                }
                $content += "| ``$($script.name)`` | $($script.type) | $($script.category) | $($script.version) | $desc |"
            }
            $content += ""
        }
        
        # Informations de génération
        $content += "---"
        $content += "*Rapport généré automatiquement par export-db.ps1*"
        
        # Sauvegarder le fichier Markdown
        $content -join "`n" | Out-File -FilePath $OutputPath -Encoding UTF8
        
        return $true
    }
    catch {
        Write-Error-Custom "Erreur lors de l'export Markdown: $_"
        return $false
    }
}

# Export XML
function Export-ToXml {
    param([string]$OutputPath)
    
    try {
        Write-Info "📄 Génération de l'export XML..."
        
        # Créer le document XML
        $xmlDoc = New-Object System.Xml.XmlDocument
        
        # Déclaration XML
        $xmlDeclaration = $xmlDoc.CreateXmlDeclaration("1.0", "UTF-8", $null)
        $xmlDoc.AppendChild($xmlDeclaration) | Out-Null
        
        # Élément racine
        $rootElement = $xmlDoc.CreateElement("ScriptCatalog")
        $rootElement.SetAttribute("exportDate", (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
        $rootElement.SetAttribute("database", $DatabaseFile)
        $xmlDoc.AppendChild($rootElement) | Out-Null
        
        # Scripts
        $scriptsElement = $xmlDoc.CreateElement("Scripts")
        $rootElement.AppendChild($scriptsElement) | Out-Null
        
        $whereClause = Build-WhereClause
        $scriptsQuery = @"
SELECT 
    s.id, s.name, s.path, s.description, s.category, s.type, 
    s.version, s.author, s.created_at, s.updated_at
FROM scripts s
$whereClause
ORDER BY s.category, s.type, s.name;
"@
        
        $scripts = Invoke-SQLite $scriptsQuery -AsObject
        
        foreach ($script in $scripts) {
            $scriptElement = $xmlDoc.CreateElement("Script")
            $scriptElement.SetAttribute("id", $script.id)
            
            # Éléments du script
            $nameElement = $xmlDoc.CreateElement("Name")
            $nameElement.InnerText = $script.name
            $scriptElement.AppendChild($nameElement) | Out-Null
            
            $pathElement = $xmlDoc.CreateElement("Path")
            $pathElement.InnerText = $script.path
            $scriptElement.AppendChild($pathElement) | Out-Null
            
            $descElement = $xmlDoc.CreateElement("Description")
            $descElement.InnerText = $script.description
            $scriptElement.AppendChild($descElement) | Out-Null
            
            $categoryElement = $xmlDoc.CreateElement("Category")
            $categoryElement.InnerText = $script.category
            $scriptElement.AppendChild($categoryElement) | Out-Null
            
            $typeElement = $xmlDoc.CreateElement("Type")
            $typeElement.InnerText = $script.type
            $scriptElement.AppendChild($typeElement) | Out-Null
            
            $versionElement = $xmlDoc.CreateElement("Version")
            $versionElement.InnerText = $script.version
            $scriptElement.AppendChild($versionElement) | Out-Null
            
            $authorElement = $xmlDoc.CreateElement("Author")
            $authorElement.InnerText = $script.author
            $scriptElement.AppendChild($authorElement) | Out-Null
            
            $createdElement = $xmlDoc.CreateElement("CreatedAt")
            $createdElement.InnerText = $script.created_at
            $scriptElement.AppendChild($createdElement) | Out-Null
            
            $scriptsElement.AppendChild($scriptElement) | Out-Null
        }
        
        # Sauvegarder le XML
        $xmlDoc.Save($OutputPath)
        
        return $true
    }
    catch {
        Write-Error-Custom "Erreur lors de l'export XML: $_"
        return $false
    }
}

# Créer un backup de la base de données
function Create-Backup {
    param([string]$OutputPath)
    
    try {
        Write-Info "💾 Création du backup de la base de données..."
        
        # Copier le fichier de base de données
        Copy-Item -Path $DatabaseFile -Destination $OutputPath -Force
        
        return $true
    }
    catch {
        Write-Error-Custom "Erreur lors de la création du backup: $_"
        return $false
    }
}

# Compresser un fichier
function Compress-File {
    param(
        [string]$FilePath,
        [string]$OutputPath
    )
    
    try {
        if (Get-Command 7z -ErrorAction SilentlyContinue) {
            # Utiliser 7-Zip si disponible
            & 7z a "$OutputPath" "$FilePath" | Out-Null
        }
        elseif ($PSVersionTable.PSVersion.Major -ge 5) {
            # Utiliser Compress-Archive de PowerShell 5+
            Compress-Archive -Path $FilePath -DestinationPath $OutputPath -Force
        }
        else {
            Write-Warn "Compression non disponible - fichier conservé non compressé"
            return $false
        }
        
        return $true
    }
    catch {
        Write-Error-Custom "Erreur lors de la compression: $_"
        return $false
    }
}

# Valider un export
function Test-Export {
    param(
        [string]$FilePath,
        [string]$ExportFormat
    )
    
    try {
        if (-not (Test-Path $FilePath)) {
            return $false
        }
        
        $fileSize = (Get-Item $FilePath).Length
        if ($fileSize -eq 0) {
            return $false
        }
        
        switch ($ExportFormat.ToLower()) {
            "json" {
                $content = Get-Content $FilePath -Raw
                $json = $content | ConvertFrom-Json
                return $json -ne $null
            }
            "csv" {
                $csv = Import-Csv $FilePath
                return $csv.Count -gt 0
            }
            "xml" {
                [xml]$xml = Get-Content $FilePath
                return $xml -ne $null
            }
            default {
                return $true  # Pour SQL et Markdown, vérifier juste l'existence
            }
        }
    }
    catch {
        return $false
    }
}

# Traiter un export spécifique
function Process-Export {
    param(
        [string]$ExportFormat,
        [string]$BaseFileName
    )
    
    try {
        $ExportStats.TotalExports++
        
        # Déterminer l'extension de fichier
        $extension = switch ($ExportFormat.ToLower()) {
            "json" { "json" }
            "csv" { "csv" }
            "sql" { "sql" }
            "markdown" { "md" }
            "xml" { "xml" }
            "backup" { "db" }
            default { "txt" }
        }
        
        # Générer le nom de fichier
        $outputFile = Get-ExportFileName -BaseName $BaseFileName -Extension $extension -Directory $OutputDir
        
        # Vérifier si le fichier existe déjà
        if ((Test-Path $outputFile) -and -not $Force) {
            Write-Warn "Fichier existant: $outputFile (utilisez -Force pour écraser)"
            return $false
        }
        
        Write-Info "📤 Export $ExportFormat vers: $(Split-Path -Leaf $outputFile)"
        
        # Exécuter l'export selon le format
        $success = switch ($ExportFormat.ToLower()) {
            "json" { Export-ToJson $outputFile }
            "csv" { Export-ToCsv $outputFile }
            "sql" { Export-ToSql $outputFile }
            "markdown" { Export-ToMarkdown $outputFile }
            "xml" { Export-ToXml $outputFile }
            "backup" { Create-Backup $outputFile }
            default { $false }
        }
        
        if (-not $success) {
            $ExportStats.ErrorCount++
            return $false
        }
        
        # Validation si demandée
        if ($Validate) {
            Write-Info "   ✓ Validation..."
            if (-not (Test-Export $outputFile $ExportFormat)) {
                Write-Error-Custom "Validation échouée pour: $outputFile"
                $ExportStats.ErrorCount++
                return $false
            }
        }
        
        # Compression si demandée
        $finalFile = $outputFile
        if ($Compress -and $ExportFormat -ne "backup") {
            Write-Info "   🗜️ Compression..."
            $compressedFile = "$outputFile.zip"
            if (Compress-File $outputFile $compressedFile) {
                Remove-Item $outputFile -Force
                $finalFile = $compressedFile
                Write-Success "   Fichier compressé: $(Split-Path -Leaf $compressedFile)"
            }
        }
        
        # Calculer la taille
        $fileSize = (Get-Item $finalFile).Length
        $ExportStats.TotalSize += $fileSize
        
        # Ajouter à la liste des exports
        $ExportStats.Exports += @{
            Format = $ExportFormat
            File = $finalFile
            Size = $fileSize
            Success = $true
        }
        
        $ExportStats.SuccessCount++
        Write-Success "✓ Export $ExportFormat terminé ($(Format-FileSize $fileSize))"
        
        return $true
    }
    catch {
        Write-Error-Custom "Erreur lors de l'export $ExportFormat : $_"
        $ExportStats.ErrorCount++
        return $false
    }
}

# Fonction utilitaire pour formater la taille de fichier
function Format-FileSize {
    param([long]$Size)
    
    if ($Size -gt 1MB) {
        return "{0:N1} MB" -f ($Size / 1MB)
    }
    elseif ($Size -gt 1KB) {
        return "{0:N1} KB" -f ($Size / 1KB)
    }
    else {
        return "$Size bytes"
    }
}

# Afficher le rapport final
function Show-FinalReport {
    $endTime = Get-Date
    $duration = $endTime - $ExportStats.StartTime
    
    Write-Host ""
    Write-Host "📊 RAPPORT D'EXPORT" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "📈 Résultats :" -ForegroundColor White
    Write-Host "  Exports demandés     : $($ExportStats.TotalExports)" -ForegroundColor Gray
    Write-Host "  Réussis              : " -NoNewline -ForegroundColor Gray
    Write-Host "$($ExportStats.SuccessCount)" -ForegroundColor Green
    Write-Host "  Échecs               : " -NoNewline -ForegroundColor Gray
    Write-Host "$($ExportStats.ErrorCount)" -ForegroundColor Red
    Write-Host "  Taille totale        : $(Format-FileSize $ExportStats.TotalSize)" -ForegroundColor Gray
    Write-Host "  Durée                : $($duration.ToString('mm\:ss'))" -ForegroundColor Gray
    Write-Host ""
    
    # Liste des fichiers générés
    if ($ExportStats.Exports.Count -gt 0) {
        Write-Host "📁 Fichiers générés :" -ForegroundColor White
        foreach ($export in $ExportStats.Exports) {
            $fileName = Split-Path -Leaf $export.File
            $sizeStr = Format-FileSize $export.Size
            Write-Host "  • $($export.Format.ToUpper().PadRight(8)) : $fileName ($sizeStr)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Informations sur le répertoire
    Write-Host "📂 Répertoire d'export :" -ForegroundColor White
    Write-Host "  Chemin               : $OutputDir" -ForegroundColor Gray
    
    if (Test-Path $OutputDir) {
        $dirSize = (Get-ChildItem $OutputDir -Recurse | Measure-Object -Property Length -Sum).Sum
        $fileCount = (Get-ChildItem $OutputDir -File).Count
        Write-Host "  Fichiers totaux      : $fileCount" -ForegroundColor Gray
        Write-Host "  Taille du répertoire : $(Format-FileSize $dirSize)" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Message final
    if ($ExportStats.ErrorCount -eq 0) {
        Write-Success "🎉 Export(s) terminé(s) avec succès !"
    }
    else {
        Write-Error-Custom "⚠️ Export(s) terminé(s) avec $($ExportStats.ErrorCount) erreur(s)"
    }
}

# Fonction principale
function Main {
    Write-Info "📤 Système d'export du catalogue SQLite"
    
    # Vérifier la base de données
    if (-not (Test-Database)) {
        exit $EXIT_ERROR_DB
    }
    
    Write-Info "🎯 Configuration:"
    Write-Info "  Format(s)       : $Format"
    Write-Info "  Répertoire      : $OutputDir"
    if ($Category) { Write-Info "  Catégorie       : $Category" }
    if ($Type) { Write-Info "  Type            : $Type" }
    if ($Compress) { Write-Info "  Compression     : Activée" }
    if ($Validate) { Write-Info "  Validation      : Activée" }
    Write-Info ""
    
    # Traitement selon le format
    if ($Format -eq "all") {
        # Tous les formats
        $formats = @("json", "csv", "sql", "markdown", "xml", "backup")
        
        Write-Info "📦 Export de tous les formats..."
        
        foreach ($fmt in $formats) {
            Process-Export -ExportFormat $fmt -BaseFileName "catalogue_complete" | Out-Null
        }
    }
    else {
        # Format spécifique
        $baseName = if ($Category -or $Type) {
            "catalogue_filtre"
        } else {
            "catalogue_complete"
        }
        
        Process-Export -ExportFormat $Format -BaseFileName $baseName | Out-Null
    }
    
    # Rapport final
    Show-FinalReport
    
    # Code de sortie selon les résultats
    if ($ExportStats.ErrorCount -eq 0) {
        exit $EXIT_SUCCESS
    }
    else {
        exit $EXIT_ERROR_EXPORT
    }
}

# Point d'entrée
if ($MyInvocation.InvocationName -ne ".") {
    Main
}