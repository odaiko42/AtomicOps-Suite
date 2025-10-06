# Script PowerShell simple pour initialiser la base SQLite3
param(
    [string]$DatabaseFile = "atomicops_inputs.db",
    [string]$SqlFile = "input_parameter_types.sql"
)

Write-Host "[INFO] Initialisation de la base AtomicOps-Suite" -ForegroundColor Blue

# Verifier les fichiers
if (-not (Test-Path $SqlFile)) {
    Write-Host "[ERROR] Script SQL non trouve: $SqlFile" -ForegroundColor Red
    exit 1
}

# Verifier SQLite3
$sqlite = Get-Command sqlite3 -ErrorAction SilentlyContinue
if (-not $sqlite) {
    Write-Host "[ERROR] SQLite3 non trouve" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] SQLite3: $($sqlite.Source)" -ForegroundColor Blue
Write-Host "[INFO] Script: $SqlFile" -ForegroundColor Blue
Write-Host "[INFO] Base: $DatabaseFile" -ForegroundColor Blue

# Supprimer ancienne base
if (Test-Path $DatabaseFile) {
    Write-Host "[WARN] Suppression ancienne base" -ForegroundColor Yellow
    Remove-Item $DatabaseFile -Force
}

# Creer la base
Write-Host "[INFO] Creation de la base..." -ForegroundColor Blue
$command = ".read `"$SqlFile`""
& sqlite3 $DatabaseFile $command

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Base creee avec succes!" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Erreur creation (code: $LASTEXITCODE)" -ForegroundColor Red
    exit 1
}

# Verification
$count = & sqlite3 $DatabaseFile "SELECT COUNT(*) FROM input_parameter_types;"
Write-Host "[OK] $count types d'inputs initialises" -ForegroundColor Green

# Categories
Write-Host "[INFO] Categories:" -ForegroundColor Blue
$cats = & sqlite3 $DatabaseFile "SELECT DISTINCT category FROM input_parameter_types ORDER BY category;"
foreach ($cat in $cats) {
    $nb = & sqlite3 $DatabaseFile "SELECT COUNT(*) FROM input_parameter_types WHERE category='$cat';"
    Write-Host "[OK]   - $cat`: $nb types" -ForegroundColor Green
}

Write-Host ""
Write-Host "[OK] === BASE PRETE! ===" -ForegroundColor Green
Write-Host "[INFO] Fichier: $DatabaseFile" -ForegroundColor Blue
Write-Host "[INFO] Utilisez: .\query_inputs_simple.ps1" -ForegroundColor Blue