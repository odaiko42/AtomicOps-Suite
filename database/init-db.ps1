#Requires -Version 5.1
<#
.SYNOPSIS
    Initialise la base de donnees SQLite pour le catalogue de scripts CT.

.DESCRIPTION
    Ce script PowerShell cree et initialise une base de donnees SQLite complete 
    pour le catalogue des scripts de gestion des containers Proxmox.

.PARAMETER Force
    Force la recreation de la base meme si elle existe deja

.PARAMETER Quiet
    Mode silencieux, affiche uniquement les erreurs critiques

.EXAMPLE
    .\init-db.ps1
    
.EXAMPLE
    .\init-db.ps1 -Force -Quiet

.NOTES
    Auteur: Systeme de Catalogue SQLite CT
    Version: 1.0
    Date: 3 octobre 2025
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage="Force la recreation de la base")]
    [switch]$Force,
    
    [Parameter(HelpMessage="Mode silencieux")]
    [switch]$Quiet
)

# Configuration globale
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$DatabaseFile = Join-Path $ProjectRoot "database\scripts_catalogue.db"

# Fonctions de logging
function Write-Info {
    param([string]$Message)
    if (-not $Quiet) {
        Write-Host "[INFO] $Message" -ForegroundColor Cyan
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

# Fonction pour executer SQLite
function Invoke-SQLite {
    param([string]$Command)
    
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        $Command | Out-File -FilePath $tempFile -Encoding UTF8
        $result = & sqlite3 $DatabaseFile ".read $tempFile" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "SQLite error: $result"
        }
        return $result
    }
    finally {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
    }
}

# Schema complet de la base de donnees
$DatabaseSchema = @"
-- ============================================================================
-- SCHEMA COMPLET DE LA BASE DE DONNEES CATALOGUE DE SCRIPTS CT
-- ============================================================================

-- Configuration SQLite pour performances optimales
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = 10000;
PRAGMA temp_store = MEMORY;

-- ============================================================================
-- 1. TABLE DES SCRIPTS PRINCIPAUX
-- ============================================================================
CREATE TABLE IF NOT EXISTS scripts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nom TEXT NOT NULL UNIQUE,
    type_script TEXT NOT NULL CHECK (type_script IN ('creation', 'gestion', 'utilitaire', 'orchestration')),
    description TEXT,
    chemin_absolu TEXT NOT NULL,
    taille_octets INTEGER DEFAULT 0,
    hash_contenu TEXT,
    date_creation DATETIME DEFAULT CURRENT_TIMESTAMP,
    date_modification DATETIME DEFAULT CURRENT_TIMESTAMP,
    derniere_execution DATETIME,
    nombre_executions INTEGER DEFAULT 0,
    statut TEXT DEFAULT 'actif' CHECK (statut IN ('actif', 'inactif', 'obsolete', 'test')),
    version TEXT DEFAULT '1.0',
    auteur TEXT,
    compatibilite_os TEXT DEFAULT 'linux',
    niveau_complexite TEXT DEFAULT 'moyen' CHECK (niveau_complexite IN ('simple', 'moyen', 'avance', 'expert')),
    temps_execution_moyen INTEGER DEFAULT 0,
    consommation_ressources TEXT DEFAULT 'faible',
    notes TEXT,
    tags TEXT
);

-- ============================================================================
-- 2. TABLE DES DEPENDANCES DE SCRIPTS
-- ============================================================================
CREATE TABLE IF NOT EXISTS dependances (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    dependance_nom TEXT NOT NULL,
    type_dependance TEXT NOT NULL CHECK (type_dependance IN ('script', 'binaire', 'module', 'service', 'port', 'fichier')),
    version_requise TEXT,
    obligatoire BOOLEAN DEFAULT 1,
    description TEXT,
    commande_verification TEXT,
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

-- ============================================================================
-- 3. TABLE DES PARAMETRES DE SCRIPTS
-- ============================================================================
CREATE TABLE IF NOT EXISTS parametres (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    nom_parametre TEXT NOT NULL,
    type_parametre TEXT NOT NULL CHECK (type_parametre IN ('string', 'integer', 'boolean', 'path', 'url', 'enum')),
    obligatoire BOOLEAN DEFAULT 0,
    valeur_defaut TEXT,
    description TEXT,
    valeurs_possibles TEXT,
    validation_pattern TEXT,
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

-- ============================================================================
-- 4. TABLE DES FONCTIONS INTERNES
-- ============================================================================
CREATE TABLE IF NOT EXISTS fonctions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    nom_fonction TEXT NOT NULL,
    ligne_debut INTEGER,
    ligne_fin INTEGER,
    description TEXT,
    parametres TEXT,
    valeur_retour TEXT,
    complexite TEXT DEFAULT 'simple',
    utilisation_externe BOOLEAN DEFAULT 0,
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

-- ============================================================================
-- 5. TABLE DES VARIABLES D'ENVIRONNEMENT
-- ============================================================================
CREATE TABLE IF NOT EXISTS variables_env (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    nom_variable TEXT NOT NULL,
    valeur_defaut TEXT,
    obligatoire BOOLEAN DEFAULT 0,
    description TEXT,
    exemple TEXT,
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

-- ============================================================================
-- 6. TABLE DES HISTORIQUES D'EXECUTION
-- ============================================================================
CREATE TABLE IF NOT EXISTS historique_executions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    date_execution DATETIME DEFAULT CURRENT_TIMESTAMP,
    duree_seconde INTEGER,
    code_retour INTEGER,
    utilisateur TEXT,
    parametres_utilises TEXT,
    sortie_stdout TEXT,
    sortie_stderr TEXT,
    environnement TEXT,
    succes BOOLEAN DEFAULT 0,
    notes_execution TEXT,
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

-- ============================================================================
-- 7. TABLE DES RESSOURCES EXTERNES
-- ============================================================================
CREATE TABLE IF NOT EXISTS ressources_externes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    type_ressource TEXT NOT NULL CHECK (type_ressource IN ('url', 'documentation', 'depot', 'api', 'service')),
    nom_ressource TEXT NOT NULL,
    url TEXT,
    description TEXT,
    derniere_verification DATETIME,
    statut_acces TEXT DEFAULT 'non_verifie',
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

-- ============================================================================
-- 8. TABLE DES CATEGORIES ET CLASSIFICATIONS
-- ============================================================================
CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nom_categorie TEXT NOT NULL UNIQUE,
    description TEXT,
    couleur_affichage TEXT DEFAULT '#007acc',
    ordre_affichage INTEGER DEFAULT 100,
    parent_id INTEGER,
    FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL
);

-- ============================================================================
-- 9. TABLE DE LIAISON SCRIPTS-CATEGORIES
-- ============================================================================
CREATE TABLE IF NOT EXISTS scripts_categories (
    script_id INTEGER NOT NULL,
    categorie_id INTEGER NOT NULL,
    PRIMARY KEY (script_id, categorie_id),
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
    FOREIGN KEY (categorie_id) REFERENCES categories(id) ON DELETE CASCADE
);

-- ============================================================================
-- 10. TABLE DES METRIQUES DE PERFORMANCE
-- ============================================================================
CREATE TABLE IF NOT EXISTS metriques_performance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    date_mesure DATETIME DEFAULT CURRENT_TIMESTAMP,
    cpu_utilisation REAL,
    memoire_mb INTEGER,
    disque_io_mb INTEGER,
    reseau_kb INTEGER,
    duree_execution INTEGER,
    charge_systeme REAL,
    contexte_mesure TEXT,
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

-- ============================================================================
-- 11. TABLE DES ERREURS ET PROBLEMES CONNUS
-- ============================================================================
CREATE TABLE IF NOT EXISTS erreurs_connues (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id INTEGER NOT NULL,
    code_erreur TEXT,
    message_erreur TEXT NOT NULL,
    cause_probable TEXT,
    solution_proposee TEXT,
    frequence_occurrence INTEGER DEFAULT 1,
    severite TEXT DEFAULT 'moyenne' CHECK (severite IN ('faible', 'moyenne', 'elevee', 'critique')),
    date_premiere_occurrence DATETIME DEFAULT CURRENT_TIMESTAMP,
    date_derniere_occurrence DATETIME DEFAULT CURRENT_TIMESTAMP,
    resolu BOOLEAN DEFAULT 0,
    FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
);

-- ============================================================================
-- 12. TABLE DES CONFIGURATIONS ET TEMPLATES
-- ============================================================================
CREATE TABLE IF NOT EXISTS configurations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nom_configuration TEXT NOT NULL UNIQUE,
    description TEXT,
    contenu_json TEXT NOT NULL,
    type_configuration TEXT NOT NULL CHECK (type_configuration IN ('template', 'preset', 'environnement', 'profil')),
    scripts_associes TEXT,
    date_creation DATETIME DEFAULT CURRENT_TIMESTAMP,
    date_modification DATETIME DEFAULT CURRENT_TIMESTAMP,
    actif BOOLEAN DEFAULT 1,
    version TEXT DEFAULT '1.0'
);

-- ============================================================================
-- VUES POUR FACILITER LES REQUETES
-- ============================================================================

-- Vue complete des scripts avec informations agregees
CREATE VIEW IF NOT EXISTS vue_scripts_complets AS
SELECT 
    s.*,
    COUNT(DISTINCT d.id) as nb_dependances,
    COUNT(DISTINCT p.id) as nb_parametres,
    COUNT(DISTINCT f.id) as nb_fonctions,
    COUNT(DISTINCT he.id) as nb_executions_historique,
    AVG(he.duree_seconde) as duree_moyenne,
    GROUP_CONCAT(DISTINCT c.nom_categorie) as categories,
    MAX(he.date_execution) as derniere_execution_historique
FROM scripts s
LEFT JOIN dependances d ON s.id = d.script_id
LEFT JOIN parametres p ON s.id = p.script_id
LEFT JOIN fonctions f ON s.id = f.script_id
LEFT JOIN historique_executions he ON s.id = he.script_id
LEFT JOIN scripts_categories sc ON s.id = sc.script_id
LEFT JOIN categories c ON sc.categorie_id = c.id
GROUP BY s.id;

-- Vue des statistiques globales
CREATE VIEW IF NOT EXISTS vue_statistiques_globales AS
SELECT 
    COUNT(*) as total_scripts,
    COUNT(CASE WHEN statut = 'actif' THEN 1 END) as scripts_actifs,
    COUNT(CASE WHEN statut = 'inactif' THEN 1 END) as scripts_inactifs,
    COUNT(CASE WHEN statut = 'obsolete' THEN 1 END) as scripts_obsoletes,
    COUNT(CASE WHEN type_script = 'creation' THEN 1 END) as scripts_creation,
    COUNT(CASE WHEN type_script = 'gestion' THEN 1 END) as scripts_gestion,
    COUNT(CASE WHEN type_script = 'utilitaire' THEN 1 END) as scripts_utilitaire,
    AVG(taille_octets) as taille_moyenne,
    SUM(taille_octets) as taille_totale,
    SUM(nombre_executions) as executions_totales,
    COUNT(DISTINCT auteur) as nb_auteurs
FROM scripts;

-- ============================================================================
-- INDEX POUR OPTIMISER LES PERFORMANCES
-- ============================================================================

-- Index sur les colonnes de recherche frequentes
CREATE INDEX IF NOT EXISTS idx_scripts_nom ON scripts(nom);
CREATE INDEX IF NOT EXISTS idx_scripts_type ON scripts(type_script);
CREATE INDEX IF NOT EXISTS idx_scripts_statut ON scripts(statut);
CREATE INDEX IF NOT EXISTS idx_scripts_auteur ON scripts(auteur);
CREATE INDEX IF NOT EXISTS idx_scripts_date_modif ON scripts(date_modification);

-- Index pour les jointures
CREATE INDEX IF NOT EXISTS idx_dependances_script ON dependances(script_id);
CREATE INDEX IF NOT EXISTS idx_parametres_script ON parametres(script_id);
CREATE INDEX IF NOT EXISTS idx_fonctions_script ON fonctions(script_id);
CREATE INDEX IF NOT EXISTS idx_historique_script ON historique_executions(script_id);
CREATE INDEX IF NOT EXISTS idx_historique_date ON historique_executions(date_execution);

-- Index pour les recherches de performance
CREATE INDEX IF NOT EXISTS idx_metriques_script ON metriques_performance(script_id);
CREATE INDEX IF NOT EXISTS idx_metriques_date ON metriques_performance(date_mesure);

-- ============================================================================
-- TRIGGERS POUR MAINTENIR LA COHERENCE
-- ============================================================================

-- Trigger pour mettre a jour automatiquement date_modification
CREATE TRIGGER IF NOT EXISTS trg_update_date_modification
    AFTER UPDATE ON scripts
    FOR EACH ROW
BEGIN
    UPDATE scripts 
    SET date_modification = CURRENT_TIMESTAMP 
    WHERE id = NEW.id;
END;

-- Trigger pour incrementer le compteur d'executions
CREATE TRIGGER IF NOT EXISTS trg_increment_executions
    AFTER INSERT ON historique_executions
    FOR EACH ROW
BEGIN
    UPDATE scripts 
    SET nombre_executions = nombre_executions + 1,
        derniere_execution = NEW.date_execution
    WHERE id = NEW.script_id;
END;

-- ============================================================================
-- INSERTION DES DONNEES INITIALES
-- ============================================================================

-- Categories de base
INSERT OR IGNORE INTO categories (nom_categorie, description, couleur_affichage, ordre_affichage) VALUES
    ('Containers CT', 'Scripts de creation et gestion des containers Proxmox', '#007acc', 10),
    ('Storage USB', 'Gestion du stockage USB et iSCSI', '#28a745', 20),
    ('Reseau', 'Configuration et gestion reseau', '#dc3545', 30),
    ('Monitoring', 'Surveillance et metriques', '#ffc107', 40),
    ('Utilitaires', 'Outils generaux et helpers', '#6c757d', 50),
    ('Base de donnees', 'Gestion des donnees et catalogues', '#17a2b8', 60);

-- Configuration par defaut
INSERT OR IGNORE INTO configurations (nom_configuration, description, contenu_json, type_configuration) VALUES
    ('environnement_dev', 'Configuration de developpement par defaut', '{"debug": true, "log_level": "verbose", "storage": "local-lvm"}', 'environnement'),
    ('environnement_prod', 'Configuration de production', '{"debug": false, "log_level": "info", "storage": "production-storage"}', 'environnement');

-- Finalisation
PRAGMA optimize;
"@

# Fonction principale d'initialisation
function Initialize-Database {
    Write-Info "Initialisation de la base de donnees SQLite"
    
    # Verifier si la base existe deja
    if (Test-Path $DatabaseFile) {
        if ($Force) {
            Write-Info "Suppression de la base existante (mode Force)"
            Remove-Item $DatabaseFile -Force
        }
        else {
            Write-Info "Base de donnees existante trouvee"
            if (-not $Quiet) {
                $response = Read-Host "Voulez-vous la recreer ? [y/N]"
                if ($response -match '^[yY]') {
                    Remove-Item $DatabaseFile -Force
                    Write-Info "Base existante supprimee"
                }
                else {
                    Write-Success "Conservation de la base existante"
                    return $true
                }
            }
            else {
                Write-Success "Base existante conservee"
                return $true
            }
        }
    }
    
    try {
        # Creer le repertoire si necessaire
        $dbDir = Split-Path $DatabaseFile -Parent
        if (-not (Test-Path $dbDir)) {
            New-Item -ItemType Directory -Path $dbDir -Force | Out-Null
        }
        
        # Creer la base et executer le schema
        Invoke-SQLite $DatabaseSchema
        
        Write-Success "Schema cree avec succes"
        
        # Verifier l'integrite
        $integrityCheck = & sqlite3 $DatabaseFile "PRAGMA integrity_check;"
        if ($integrityCheck -eq "ok") {
            Write-Success "Integrite verifiee"
        }
        else {
            Write-Error-Custom "Probleme d'integrite: $integrityCheck"
            return $false
        }
        
        # Statistiques finales
        $tableCount = & sqlite3 $DatabaseFile "SELECT COUNT(*) FROM sqlite_master WHERE type='table';"
        $indexCount = & sqlite3 $DatabaseFile "SELECT COUNT(*) FROM sqlite_master WHERE type='index';"
        $viewCount = & sqlite3 $DatabaseFile "SELECT COUNT(*) FROM sqlite_master WHERE type='view';"
        
        Write-Success "Base de donnees initialisee:"
        Write-Info "  Tables: $tableCount"
        Write-Info "  Index: $indexCount"
        Write-Info "  Vues: $viewCount"
        Write-Info "  Fichier: $DatabaseFile"
        
        return $true
    }
    catch {
        Write-Error-Custom "Erreur lors de l'initialisation: $($_.Exception.Message)"
        return $false
    }
}

# Point d'entree principal
function Main {
    Write-Host ""
    Write-Host "INITIALISATION BASE DE DONNEES SQLITE" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Info "Configuration:"
    Write-Info "  Force recreation: $(if ($Force) { 'Oui' } else { 'Non' })"
    Write-Info "  Mode silencieux: $(if ($Quiet) { 'Oui' } else { 'Non' })"
    Write-Info "  Fichier cible: $DatabaseFile"
    Write-Host ""
    
    if (Initialize-Database) {
        Write-Host ""
        Write-Host "Initialisation terminee avec succes !" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host ""
        Write-Host "Echec de l'initialisation !" -ForegroundColor Red
        exit 1
    }
}

# Execution
if ($MyInvocation.InvocationName -ne ".") {
    Main
}