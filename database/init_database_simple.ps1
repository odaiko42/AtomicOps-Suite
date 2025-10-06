# Script PowerShell simplifie pour initialiser la base SQLite3
param(
    [string]$DatabasePath = ".\atomicops_inputs.db",
    [string]$SqlScript = ".\input_parameter_types.sql"
)

$ErrorActionPreference = "Stop"

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

try {
    Write-Info "=== Initialisation de la base AtomicOps-Suite ==="
    
    # Verifier que le script SQL existe
    if (-not (Test-Path $SqlScript)) {
        Write-Error "Script SQL non trouve: $SqlScript"
        exit 1
    }
    
    # Chercher SQLite3
    $sqlite3 = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if (-not $sqlite3) {
        Write-Error "SQLite3 non trouve"
        exit 1
    }
    
    Write-Info "SQLite3 trouve: $($sqlite3.Source)"
    Write-Info "Script SQL: $SqlScript"
    Write-Info "Base cible: $DatabasePath"
    
    # Supprimer l'ancienne base si elle existe
    if (Test-Path $DatabasePath) {
        Write-Warning "Suppression de l'ancienne base"
        Remove-Item $DatabasePath -Force
    }
    
    # Executer le script SQL
    Write-Info "Creation de la base de donnees..."
    $result = & sqlite3 $DatabasePath ".read $SqlScript"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Base creee avec succes"
    } else {
        Write-Error "Erreur lors de la creation (code: $LASTEXITCODE)"
        exit 1
    }
    
    # Verifier le contenu
    Write-Info "Verification du contenu..."
    $count = & sqlite3 $DatabasePath "SELECT COUNT(*) FROM input_parameter_types;"
    
    if ($count -eq "13") {
        Write-Success "✓ $count types d'inputs initialises"
    } else {
        Write-Warning "Nombre inattendu: $count (attendu: 13)"
    }
    
    # Statistiques par categorie
    Write-Info "Categories disponibles:"
    $categories = & sqlite3 $DatabasePath "SELECT category, COUNT(*) FROM input_parameter_types GROUP BY category;"
    
    foreach ($line in $categories) {
        $parts = $line -split '\|'
        if ($parts.Length -eq 2) {
            Write-Success "  - $($parts[0]): $($parts[1]) types"
        }
    }
    
    Write-Info ""
    Write-Success "=== Base prete! ==="
    Write-Info "Fichier: $DatabasePath"
    Write-Info "Utilisez: .\query_inputs.ps1 help"
    
} catch {
    Write-Error "Erreur: $($_.Exception.Message)"
    exit 1
}