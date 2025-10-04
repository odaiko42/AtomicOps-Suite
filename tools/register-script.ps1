#Requires -Version 5.1
<#
.SYNOPSIS
    Enregistre un script dans le catalogue SQLite avec extraction automatique des métadonnées.

.DESCRIPTION
    Ce script PowerShell permet d'enregistrer un script Bash dans la base de données catalogue
    avec extraction automatique des métadonnées depuis les commentaires et en-têtes du script.
    
    Fonctionnalités :
    - Extraction automatique des métadonnées (nom, description, paramètres, etc.)
    - Support des modes interactif et automatique
    - Validation de l'intégrité des données
    - Gestion des dépendances et fonctions utilisées
    - Mise à jour des scripts existants

.PARAMETER ScriptPath
    Chemin vers le script à enregistrer dans le catalogue

.PARAMETER Auto
    Mode automatique sans interaction utilisateur

.PARAMETER Force
    Force l'enregistrement même si le script existe déjà

.PARAMETER Quiet
    Mode silencieux, affiche uniquement les erreurs

.EXAMPLE
    .\register-script.ps1 -ScriptPath "C:\Scripts\mon-script.sh"
    
.EXAMPLE
    .\register-script.ps1 -ScriptPath ".\create-base-CT.sh" -Auto -Force

.NOTES
    Auteur: Système de Catalogue SQLite CT
    Version: 1.0
    Date: 3 octobre 2025
    
    Prérequis:
    - SQLite3 accessible via PATH ou module PSSQLite
    - Base de données initialisée avec init-db.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Chemin vers le script à enregistrer")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$ScriptPath,
    
    [Parameter(HelpMessage="Mode automatique sans interaction")]
    [switch]$Auto,
    
    [Parameter(HelpMessage="Force l'enregistrement même si existe déjà")]
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
$EXIT_ERROR_ARGS = 1
$EXIT_ERROR_DB = 2
$EXIT_ERROR_SCRIPT = 3

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
            # Utiliser sqlite3 en ligne de commande
            $result = & sqlite3 $Database $Query 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "Erreur SQLite: $LASTEXITCODE"
            }
            return $result
        }
        elseif (Get-Module -ListAvailable -Name PSSQLite) {
            # Utiliser le module PowerShell PSSQLite si disponible
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

# Fonction pour extraire les métadonnées d'un script
function Get-ScriptMetadata {
    param([string]$FilePath)
    
    $metadata = @{
        name = Split-Path -Leaf $FilePath
        path = $FilePath
        description = ""
        category = "other"
        type = "script"
        parameters = @()
        dependencies = @()
        functions = @()
        exit_codes = @()
        examples = @()
        version = "1.0"
        author = ""
    }
    
    if (-not (Test-Path $FilePath)) {
        throw "Fichier non trouvé: $FilePath"
    }
    
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    $lines = Get-Content $FilePath -Encoding UTF8
    
    # Extraction des informations depuis les commentaires d'en-tête
    foreach ($line in $lines) {
        $line = $line.Trim()
        
        # Description depuis les commentaires
        if ($line -match "^#\s*Description:\s*(.+)$") {
            $metadata.description = $matches[1].Trim()
        }
        elseif ($line -match "^#\s*(.+)$" -and -not $metadata.description -and $line -notmatch "^#!/") {
            $desc = $matches[1].Trim()
            if ($desc -and $desc -notmatch "^(Script|Auteur|Version|Date):" -and $desc.Length -gt 10) {
                $metadata.description = $desc
            }
        }
        
        # Usage et paramètres
        if ($line -match "^#\s*Usage:\s*(.+)$") {
            $usage = $matches[1]
            # Extraire les paramètres depuis l'usage
            if ($usage -match '\$\{?(\w+)\}?') {
                $metadata.parameters += $matches[1]
            }
        }
        
        # Auteur
        if ($line -match "^#\s*Auteur?:\s*(.+)$") {
            $metadata.author = $matches[1].Trim()
        }
        
        # Version
        if ($line -match "^#\s*Version:\s*(.+)$") {
            $metadata.version = $matches[1].Trim()
        }
    }
    
    # Déterminer le type selon le nom et le contenu
    $name = $metadata.name.ToLower()
    if ($name -match "(create|setup|install)" -and $name -match "ct") {
        $metadata.type = "creator"
        $metadata.category = "ct"
    }
    elseif ($name -match "(usb|disk|storage)") {
        $metadata.category = "usb"
        if ($content -match "function\s+\w+\s*\(\)") {
            $metadata.type = "library"
        }
        else {
            $metadata.type = "atomic"
        }
    }
    elseif ($name -match "(lib|common)") {
        $metadata.type = "library"
    }
    elseif ($content -match "pct\s+(create|start|stop)") {
        $metadata.type = "orchestrator"
        $metadata.category = "ct"
    }
    
    # Extraire les dépendances (sources et calls)
    $sourcesPattern = 'source\s+["\']?([^"\';\s]+)'
    $callsPattern = '\.\/([a-zA-Z0-9_-]+\.sh)'
    
    if ($content -match $sourcesPattern) {
        $metadata.dependencies += ($content | Select-String $sourcesPattern -AllMatches).Matches | 
                                 ForEach-Object { Split-Path -Leaf $_.Groups[1].Value }
    }
    
    if ($content -match $callsPattern) {
        $metadata.dependencies += ($content | Select-String $callsPattern -AllMatches).Matches |
                                 ForEach-Object { $_.Groups[1].Value }
    }
    
    # Extraire les fonctions définies
    $functionsPattern = 'function\s+(\w+)\s*\(\)'
    if ($content -match $functionsPattern) {
        $metadata.functions += ($content | Select-String $functionsPattern -AllMatches).Matches |
                              ForEach-Object { $_.Groups[1].Value }
    }
    
    # Extraire les codes de sortie
    $exitPattern = 'exit\s+(\d+)'
    if ($content -match $exitPattern) {
        $metadata.exit_codes += ($content | Select-String $exitPattern -AllMatches).Matches |
                               ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique
    }
    
    # Nettoyer les données
    $metadata.dependencies = $metadata.dependencies | Where-Object { $_ } | Sort-Object -Unique
    $metadata.functions = $metadata.functions | Where-Object { $_ } | Sort-Object -Unique
    $metadata.parameters = $metadata.parameters | Where-Object { $_ } | Sort-Object -Unique
    
    if (-not $metadata.description) {
        $metadata.description = "Script $($metadata.name)"
    }
    
    return $metadata
}

# Fonction pour vérifier si un script existe déjà
function Test-ScriptExists {
    param([string]$ScriptName)
    
    try {
        $result = Invoke-SQLite "SELECT id FROM scripts WHERE name = '$ScriptName';"
        return ($result -and $result.Trim() -ne "")
    }
    catch {
        return $false
    }
}

# Fonction pour enregistrer un script dans la base
function Register-ScriptInDatabase {
    param([hashtable]$Metadata)
    
    $scriptName = $Metadata.name
    $existsAlready = Test-ScriptExists $scriptName
    
    if ($existsAlready -and -not $Force) {
        if ($Auto) {
            Write-Warn "Script '$scriptName' existe déjà (ignoré en mode auto)"
            return $true
        }
        else {
            $response = Read-Host "Script '$scriptName' existe déjà. Mettre à jour? (y/N)"
            if ($response -notmatch '^[yY]') {
                Write-Info "Enregistrement annulé"
                return $true
            }
        }
    }
    
    try {
        # Commencer une transaction
        Invoke-SQLite "BEGIN TRANSACTION;" -NoOutput
        
        if ($existsAlready) {
            # Mise à jour du script existant
            $query = @"
UPDATE scripts SET
    path = '$($Metadata.path -replace "'", "''")',
    description = '$($Metadata.description -replace "'", "''")',
    category = '$($Metadata.category)',
    type = '$($Metadata.type)',
    version = '$($Metadata.version)',
    author = '$($Metadata.author -replace "'", "''")',
    last_modified = datetime('now'),
    updated_at = datetime('now')
WHERE name = '$scriptName';
"@
            Invoke-SQLite $query -NoOutput
            $scriptId = Invoke-SQLite "SELECT id FROM scripts WHERE name = '$scriptName';"
            
            # Nettoyer les anciennes associations
            Invoke-SQLite "DELETE FROM script_parameters WHERE script_id = $scriptId;" -NoOutput
            Invoke-SQLite "DELETE FROM script_dependencies WHERE script_id = $scriptId;" -NoOutput
            Invoke-SQLite "DELETE FROM script_uses_functions WHERE script_id = $scriptId;" -NoOutput
            
            Write-Info "Script mis à jour: $scriptName"
        }
        else {
            # Insertion d'un nouveau script
            $query = @"
INSERT INTO scripts (name, path, description, category, type, version, author, created_at, updated_at, last_modified)
VALUES (
    '$scriptName',
    '$($Metadata.path -replace "'", "''")',
    '$($Metadata.description -replace "'", "''")',
    '$($Metadata.category)',
    '$($Metadata.type)',
    '$($Metadata.version)',
    '$($Metadata.author -replace "'", "''"))',
    datetime('now'),
    datetime('now'),
    datetime('now')
);
"@
            Invoke-SQLite $query -NoOutput
            $scriptId = Invoke-SQLite "SELECT last_insert_rowid();"
            
            Write-Info "Nouveau script enregistré: $scriptName"
        }
        
        # Ajouter les paramètres
        foreach ($param in $Metadata.parameters) {
            if ($param) {
                $query = "INSERT INTO script_parameters (script_id, name, description, required, default_value) VALUES ($scriptId, '$param', 'Paramètre détecté automatiquement', 0, NULL);"
                Invoke-SQLite $query -NoOutput
            }
        }
        
        # Ajouter les dépendances
        foreach ($dep in $Metadata.dependencies) {
            if ($dep) {
                $query = "INSERT INTO script_dependencies (script_id, dependency_name, dependency_type) VALUES ($scriptId, '$dep', 'script');"
                Invoke-SQLite $query -NoOutput
            }
        }
        
        # Ajouter les fonctions utilisées
        foreach ($func in $Metadata.functions) {
            if ($func) {
                # D'abord, s'assurer que la fonction existe dans la table functions
                $funcExists = Invoke-SQLite "SELECT id FROM functions WHERE name = '$func';"
                if (-not $funcExists) {
                    $funcQuery = "INSERT INTO functions (name, description, script_file, created_at) VALUES ('$func', 'Fonction détectée automatiquement', '$scriptName', datetime('now'));"
                    Invoke-SQLite $funcQuery -NoOutput
                    $functionId = Invoke-SQLite "SELECT last_insert_rowid();"
                }
                else {
                    $functionId = $funcExists
                }
                
                # Lier la fonction au script
                $query = "INSERT OR IGNORE INTO script_uses_functions (script_id, function_id) VALUES ($scriptId, $functionId);"
                Invoke-SQLite $query -NoOutput
            }
        }
        
        # Ajouter les codes de sortie
        foreach ($code in $Metadata.exit_codes) {
            $description = switch ($code) {
                0 { "Succès" }
                1 { "Erreur générale" }
                2 { "Erreur d'arguments" }
                3 { "Erreur de fichier" }
                default { "Code de sortie personnalisé" }
            }
            
            $query = "INSERT OR IGNORE INTO exit_codes (script_id, code, description) VALUES ($scriptId, $code, '$description');"
            Invoke-SQLite $query -NoOutput
        }
        
        # Valider la transaction
        Invoke-SQLite "COMMIT;" -NoOutput
        
        Write-Success "✓ Script '$scriptName' enregistré avec succès (ID: $scriptId)"
        
        # Afficher un résumé si pas en mode quiet
        if (-not $Quiet) {
            Write-Info "  Paramètres: $($Metadata.parameters.Count)"
            Write-Info "  Dépendances: $($Metadata.dependencies.Count)" 
            Write-Info "  Fonctions: $($Metadata.functions.Count)"
            Write-Info "  Codes de sortie: $($Metadata.exit_codes.Count)"
        }
        
        return $true
    }
    catch {
        # Annuler la transaction en cas d'erreur
        try { Invoke-SQLite "ROLLBACK;" -NoOutput } catch { }
        Write-Error-Custom "Erreur lors de l'enregistrement: $_"
        return $false
    }
}

# Fonction principale
function Main {
    Write-Info "🔧 Enregistrement de script dans le catalogue SQLite"
    
    # Vérifier la base de données
    if (-not (Test-Database)) {
        exit $EXIT_ERROR_DB
    }
    
    # Résoudre le chemin du script
    $resolvedPath = Resolve-Path $ScriptPath -ErrorAction Stop
    
    Write-Info "📄 Analyse du script: $(Split-Path -Leaf $resolvedPath)"
    
    try {
        # Extraire les métadonnées
        $metadata = Get-ScriptMetadata $resolvedPath.Path
        
        if (-not $Auto -and -not $Quiet) {
            Write-Info "Métadonnées extraites:"
            Write-Info "  Nom: $($metadata.name)"
            Write-Info "  Description: $($metadata.description)"
            Write-Info "  Type: $($metadata.type)"
            Write-Info "  Catégorie: $($metadata.category)"
            Write-Info "  Version: $($metadata.version)"
            
            if (-not $Force) {
                $response = Read-Host "Continuer l'enregistrement? (Y/n)"
                if ($response -match '^[nN]') {
                    Write-Info "Enregistrement annulé"
                    exit $EXIT_SUCCESS
                }
            }
        }
        
        # Enregistrer dans la base
        if (Register-ScriptInDatabase $metadata) {
            Write-Success "✨ Enregistrement terminé avec succès"
            exit $EXIT_SUCCESS
        }
        else {
            Write-Error-Custom "Échec de l'enregistrement"
            exit $EXIT_ERROR_DB
        }
    }
    catch {
        Write-Error-Custom "Erreur lors de l'analyse du script: $_"
        exit $EXIT_ERROR_SCRIPT
    }
}

# Point d'entrée
if ($MyInvocation.InvocationName -ne ".") {
    Main
}