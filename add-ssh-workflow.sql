-- Insertion du nouveau workflow SSH par défaut
INSERT OR REPLACE INTO scripts (
    name, description, category, level, type, location, created_date
) VALUES (
    'ssh-default-workflow',
    'Workflow par défaut pour connexion SSH avec exploration de répertoire',
    'network',
    1,
    'orchestrator',
    'usb-disk-manager/scripts/orchestrators/network',
    datetime('now')
);

-- Ajout des tags pour le workflow
INSERT OR IGNORE INTO tags (tag) VALUES ('ssh');
INSERT OR IGNORE INTO tags (tag) VALUES ('workflow');
INSERT OR IGNORE INTO tags (tag) VALUES ('orchestrateur');
INSERT OR IGNORE INTO tags (tag) VALUES ('default');
INSERT OR IGNORE INTO tags (tag) VALUES ('exploration');

-- Association des tags au script
INSERT OR IGNORE INTO script_tags (script_name, tag) 
SELECT 'ssh-default-workflow', tag FROM tags 
WHERE tag IN ('ssh', 'workflow', 'orchestrateur', 'default', 'exploration');

-- Affichage de confirmation
SELECT 'WORKFLOW SSH AJOUTÉ AVEC SUCCÈS' as status;
SELECT name, type, level, category FROM scripts WHERE name = 'ssh-default-workflow';