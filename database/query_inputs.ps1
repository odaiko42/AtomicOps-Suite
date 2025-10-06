# Script PowerShell pour interroger la base de données SQLite3 des types d'inputs
# Compatible avec l'environnement Windows de développement

param(
    [Parameter(Position=0)]
    [string]$Action = "help",
    
    [Parameter(Position=1)]
    [string]$Parameter = "",
    
    [string]$DatabasePath = ".\atomicops_inputs.db"
)

# === CONFIGURATION ===
$ErrorActionPreference = "Stop"
$DatabaseFullPath = (Resolve-Path -Path $DatabasePath -ErrorAction SilentlyContinue) ?? (Join-Path -Path (Get-Location) -ChildPath $DatabasePath)

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

function Write-Data {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Show-Help {
    Write-Host @"
[INFO] === Requêtes Base de Données AtomicOps-Suite ===

Usage: .\query_inputs.ps1 <action> [paramètre]

Actions disponibles:
  all                    - Afficher tous les types d'inputs
  category <nom>         - Afficher les inputs d'une catégorie (network/auth/system)
  details <type>         - Détails complets d'un type d'input
  stats                  - Statistiques de la base
  json                   - Export JSON (génère input_types.json)
  typescript             - Export TypeScript (génère inputTypes.ts)
  colors                 - Afficher les couleurs par catégorie
  validation <type>      - Voir la validation d'un type
  examples <type>        - Voir les exemples d'un type
  help                   - Cette aide

Exemples:
  .\query_inputs.ps1 all
  .\query_inputs.ps1 category network
  .\query_inputs.ps1 details ip
  .\query_inputs.ps1 validation username
  .\query_inputs.ps1 json
"@ -ForegroundColor Yellow
}

# === VÉRIFICATION DES PRÉREQUIS ===
function Test-Prerequisites {
    # Vérifier que la base existe
    if (-not (Test-Path $DatabaseFullPath)) {
        Write-Error "Base de données non trouvée: $DatabaseFullPath"
        Write-Info "Exécutez d'abord: .\init_database.ps1"
        return $false
    }

    # Chercher SQLite3
    $sqlite3Paths = @("sqlite3.exe", ".\sqlite3.exe", "..\sqlite3.exe")
    
    foreach ($path in $sqlite3Paths) {
        try {
            $result = Get-Command $path -ErrorAction SilentlyContinue
            if ($result) {
                $script:SQLitePath = $result.Source
                return $true
            }
        }
        catch {
            continue
        }
    }

    Write-Error "SQLite3 non trouvé"
    return $false
}

# === EXÉCUTION DE REQUÊTES ===
function Invoke-SqlQuery {
    param([string]$Query)
    
    try {
        return & $script:SQLitePath $DatabaseFullPath $Query
    }
    catch {
        Write-Error "Erreur lors de l'exécution de la requête: $($_.Exception.Message)"
        return $null
    }
}

# === ACTIONS ===
function Show-AllInputs {
    Write-Info "=== Tous les Types d'Inputs ==="
    $query = "SELECT type_name, display_label, category, color_hex FROM input_parameter_types ORDER BY category, type_name;"
    
    $results = Invoke-SqlQuery $query
    if ($results) {
        Write-Success "Type        | Label                | Catégorie | Couleur"
        Write-Success "------------|----------------------|-----------|--------"
        
        foreach ($line in $results) {
            if ($line -match "^([^|]+)\|([^|]+)\|([^|]+)\|([^|]+)$") {
                $type = $matches[1].PadRight(11)
                $label = $matches[2].PadRight(20)
                $category = $matches[3].PadRight(9)
                $color = $matches[4]
                Write-Data "$type | $label | $category | $color"
            }
        }
    }
}

function Show-InputsByCategory {
    param([string]$Category)
    
    if (-not $Category) {
        Write-Error "Catégorie requise. Disponibles: network, auth, system"
        return
    }
    
    Write-Info "=== Inputs de la catégorie: $Category ==="
    $query = "SELECT type_name, display_label, color_hex, examples FROM input_parameter_types WHERE category='$Category' ORDER BY type_name;"
    
    $results = Invoke-SqlQuery $query
    if ($results) {
        foreach ($line in $results) {
            if ($line -match "^([^|]+)\|([^|]+)\|([^|]+)\|([^|]*)$") {
                Write-Success "Type: $($matches[1])"
                Write-Data "  Label: $($matches[2])"
                Write-Data "  Couleur: $($matches[3])"
                Write-Data "  Exemples: $($matches[4])"
                Write-Host ""
            }
        }
    } else {
        Write-Error "Aucun input trouvé pour la catégorie: $Category"
    }
}

function Show-InputDetails {
    param([string]$Type)
    
    if (-not $Type) {
        Write-Error "Type d'input requis"
        return
    }
    
    Write-Info "=== Détails du type: $Type ==="
    $query = "SELECT * FROM input_parameter_types WHERE type_name='$Type';"
    
    $results = Invoke-SqlQuery $query
    if ($results) {
        $fields = $results[0] -split '\|'
        if ($fields.Length -ge 10) {
            Write-Success "Type: $($fields[1])"
            Write-Data "Label: $($fields[2])"
            Write-Data "Couleur: $($fields[3])"
            Write-Data "Validation Regex: $($fields[4])"
            Write-Data "Message d'erreur: $($fields[5])"
            Write-Data "Valeur par défaut: $($fields[6])"
            Write-Data "Description: $($fields[7])"
            Write-Data "Catégorie: $($fields[8])"
            Write-Data "Obligatoire: $($fields[9])"
            Write-Data "Exemples: $($fields[12])"
        }
    } else {
        Write-Error "Type d'input non trouvé: $Type"
    }
}

function Show-Stats {
    Write-Info "=== Statistiques de la Base ==="
    
    # Nombre total
    $totalQuery = "SELECT COUNT(*) FROM input_parameter_types;"
    $total = Invoke-SqlQuery $totalQuery
    Write-Success "Total des types d'inputs: $total"
    
    # Par catégorie
    $categoryQuery = "SELECT category, COUNT(*) FROM input_parameter_types GROUP BY category ORDER BY category;"
    $categories = Invoke-SqlQuery $categoryQuery
    
    Write-Info "Répartition par catégories:"
    foreach ($line in $categories) {
        if ($line -match "^([^|]+)\|([^|]+)$") {
            Write-Data "  - $($matches[1]): $($matches[2]) types"
        }
    }
}

function Export-Json {
    Write-Info "=== Export JSON ==="
    
    $query = @"
SELECT json_object(
    'inputTypes', 
    json_group_object(
        type_name,
        json_object(
            'label', display_label,
            'color', color_hex,
            'category', category,
            'validation', validation_regex,
            'message', validation_message,
            'default', default_value,
            'examples', examples,
            'required', is_required
        )
    )
) FROM input_parameter_types;
"@
    
    $result = Invoke-SqlQuery $query
    if ($result) {
        $outputFile = "input_types.json"
        $result | Out-File -FilePath $outputFile -Encoding UTF8
        Write-Success "Export JSON généré: $outputFile"
    }
}

function Export-TypeScript {
    Write-Info "=== Export TypeScript ==="
    
    $query = "SELECT type_name, display_label, color_hex, category, validation_regex, validation_message, default_value, examples, is_required FROM input_parameter_types ORDER BY category, type_name;"
    
    $results = Invoke-SqlQuery $query
    if ($results) {
        $tsContent = @"
// Types d'inputs générés automatiquement depuis la base de données
// Ne pas modifier ce fichier directement

export interface InputTypeConfig {
  label: string;
  color: string;
  category: 'network' | 'auth' | 'system';
  validation?: string;
  message?: string;
  default?: string;
  examples?: string;
  required?: boolean;
}

export const INPUT_TYPES_CONFIG: Record<string, InputTypeConfig> = {
"@
        
        foreach ($line in $results) {
            if ($line -match "^([^|]+)\|([^|]+)\|([^|]+)\|([^|]+)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)$") {
                $type = $matches[1]
                $label = $matches[2]
                $color = $matches[3]
                $category = $matches[4]
                $validation = $matches[5]
                $message = $matches[6]
                $default = $matches[7]
                $examples = $matches[8]
                $required = $matches[9]
                
                $tsContent += @"

  $type`: {
    label: '$label',
    color: '$color',
    category: '$category',
    validation: '$validation',
    message: '$message',
    default: '$default',
    examples: '$examples',
    required: $($required.ToLower())
  },
"@
            }
        }
        
        $tsContent += @"

};
"@
        
        $outputFile = "inputTypes.ts"
        $tsContent | Out-File -FilePath $outputFile -Encoding UTF8
        Write-Success "Export TypeScript généré: $outputFile"
    }
}

# === SCRIPT PRINCIPAL ===
function Main {
    try {
        if (-not (Test-Prerequisites)) {
            exit 1
        }

        switch ($Action.ToLower()) {
            "all" { Show-AllInputs }
            "category" { Show-InputsByCategory $Parameter }
            "details" { Show-InputDetails $Parameter }
            "stats" { Show-Stats }
            "json" { Export-Json }
            "typescript" { Export-TypeScript }
            "help" { Show-Help }
            default { 
                Write-Error "Action inconnue: $Action"
                Show-Help
                exit 1
            }
        }
        
    }
    catch {
        Write-Error "Erreur inattendue: $($_.Exception.Message)"
        exit 1
    }
}

# Exécution du script
Main