# Script PowerShell pour initialiser la base de données SQLite3 des types d'inputs
# Compatible avec l'environnement Windows de développement

param(
    [string]$DatabasePath = ".\atomicops_inputs.db",
    [string]$SqlScript = ".\input_parameter_types.sql"
)

# === CONFIGURATION ===
$ErrorActionPreference = "Stop"
$DatabaseFullPath = if (Test-Path $DatabasePath) { (Resolve-Path -Path $DatabasePath).Path } else { Join-Path -Path (Get-Location) -ChildPath $DatabasePath }
$SqlScriptFullPath = if (Test-Path $SqlScript) { (Resolve-Path -Path $SqlScript).Path } else { Join-Path -Path (Get-Location) -ChildPath $SqlScript }

# === FONCTIONS UTILITAIRES ===
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

# === VÉRIFICATION DES PRÉREQUIS ===
function Test-Prerequisites {
    Write-Info "=== Initialisation de la base de données AtomicOps-Suite ==="
    Write-Info "Base de données: $DatabaseFullPath"
    Write-Info "Script SQL: $SqlScriptFullPath"
    Write-Info ""

    # Vérifier que le script SQL existe
    if (-not (Test-Path $SqlScriptFullPath)) {
        Write-Error "Script SQL non trouvé: $SqlScriptFullPath"
        return $false
    }

    # Chercher SQLite3 dans différents emplacements
    $sqlite3Paths = @(
        "sqlite3.exe",
        ".\sqlite3.exe", 
        "..\sqlite3.exe",
        "C:\Program Files\SQLite\sqlite3.exe",
        "C:\Tools\sqlite3.exe"
    )

    foreach ($path in $sqlite3Paths) {
        try {
            $result = Get-Command $path -ErrorAction SilentlyContinue
            if ($result) {
                $script:SQLitePath = $result.Source
                Write-Info "SQLite3 trouvé: $($script:SQLitePath)"
                return $true
            }
        }
        catch {
            continue
        }
    }

    Write-Error "SQLite3 non trouvé. Veuillez installer SQLite3 ou le placer dans le répertoire courant."
    Write-Info "Téléchargement: https://www.sqlite.org/download.html"
    return $false
}

# === CRÉATION DE LA BASE ===
function Initialize-Database {
    Write-Info "Création de la base de données..."
    
    # Supprimer l'ancienne base si elle existe
    if (Test-Path $DatabaseFullPath) {
        Write-Warning "Suppression de l'ancienne base de données"
        Remove-Item $DatabaseFullPath -Force
    }

    # Exécuter le script SQL
    try {
        $process = Start-Process -FilePath $script:SQLitePath -ArgumentList @($DatabaseFullPath, ".read `"$SqlScriptFullPath`"") -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Success "Base de données créée avec succès"
        } else {
            Write-Error "Erreur lors de l'exécution du script SQL (code: $($process.ExitCode))"
            return $false
        }
    }
    catch {
        Write-Error "Erreur lors de l'exécution de SQLite3: $($_.Exception.Message)"
        return $false
    }

    return $true
}

# === VÉRIFICATION DU CONTENU ===
function Test-DatabaseContent {
    Write-Info "Vérification du contenu de la base..."
    
    try {
        # Compter les enregistrements
        $countQuery = "SELECT COUNT(*) FROM input_parameter_types;"
        $result = & $script:SQLitePath $DatabaseFullPath $countQuery
        
        if ($result -eq "13") {
            Write-Success "✓ Base de données initialisée: $result types d'inputs trouvés"
        } else {
            Write-Warning "⚠ Nombre d'inputs inattendu: $result (attendu: 13)"
        }

        # Vérifier les catégories
        $categoryQuery = "SELECT category, COUNT(*) FROM input_parameter_types GROUP BY category ORDER BY category;"
        Write-Info "Repartition par categories:"
        $categories = & $script:SQLitePath $DatabaseFullPath $categoryQuery
        
        foreach ($line in $categories) {
            if ($line -match "^(\w+)\|(\d+)") {
                Write-Success "  - $($matches[1]): $($matches[2]) types"
            }
        }
    }
    catch {
        Write-Error "Erreur lors de la vérification: $($_.Exception.Message)"
        return $false
    }

    return $true
}

# === AFFICHAGE D'INFORMATIONS ===
function Show-UsageInfo {
    Write-Info ""
    Write-Info "=== Base de données prête! ==="
    Write-Info "Fichier: $DatabaseFullPath"
    Write-Info ""
    Write-Info "Utilisation avec PowerShell:"
    Write-Success "  # Lister tous les types"
    Write-Success "  & `"$($script:SQLitePath)`" `"$DatabaseFullPath`" `"SELECT * FROM input_parameter_types;`""
    Write-Info ""
    Write-Success "  # Par catégorie"  
    Write-Success "  & `"$($script:SQLitePath)`" `"$DatabaseFullPath`" `"SELECT * FROM input_parameter_types WHERE category='network';`""
    Write-Info ""
    Write-Success "  # Détails d'un type"
    Write-Success "  & `"$($script:SQLitePath)`" `"$DatabaseFullPath`" `"SELECT * FROM input_parameter_types WHERE type_name='ip';`""
    Write-Info ""
    Write-Info "Script de requêtes disponible: .\query_inputs.ps1"
}

# === SCRIPT PRINCIPAL ===
function Main {
    try {
        if (-not (Test-Prerequisites)) {
            exit 1
        }

        if (-not (Initialize-Database)) {
            exit 1
        }

        if (-not (Test-DatabaseContent)) {
            exit 1
        }

        Show-UsageInfo
        Write-Success "Initialisation terminée avec succès!"
        
    }
    catch {
        Write-Error "Erreur inattendue: $($_.Exception.Message)"
        exit 1
    }
}

# Exécution du script
Main