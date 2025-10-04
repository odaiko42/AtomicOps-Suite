-- Script SQL pour mise à jour de la base de données catalogue avec nouveaux scripts SSH
-- Ajout des scripts SSH manquants selon le catalogue SSH.mp
-- Version adaptée au schéma réel de la base

-- Insertion des nouveaux scripts atomiques SSH
INSERT OR REPLACE INTO scripts (
    name, 
    file_path, 
    category, 
    protocol,
    type,
    level, 
    description,
    parameters,
    dependencies,
    examples,
    version,
    date_created,
    date_updated
) VALUES 
-- Script atomique execute-ssh.remote.sh
(
    'execute-ssh.remote.sh',
    'atomics/network/execute-ssh.remote.sh',
    'network',
    'ssh',
    'atomic',
    0,
    'Exécution de commandes SSH distantes avec récupération JSON - Script Atomique Niveau 0',
    '{"host": {"type": "string", "required": true, "description": "Nom d''hôte ou adresse IP"}, "command": {"type": "string", "required": true, "description": "Commande à exécuter"}, "port": {"type": "integer", "default": 22}, "user": {"type": "string", "default": "current_user"}, "identity": {"type": "string", "optional": true}, "timeout": {"type": "integer", "default": 30}, "retries": {"type": "integer", "default": 3}}',
    '[]',
    '{"basic": {"description": "Exécuter commande simple", "command": "./execute-ssh.remote.sh --host server.example.com --command \"ls -la\"", "output": "JSON avec stdout, stderr, exit_code"}, "with_script": {"description": "Exécuter un script", "command": "./execute-ssh.remote.sh --host server.example.com --script-file /path/to/script.sh", "output": "Résultat d''exécution du script distant"}}',
    '1.0.0',
    datetime('now'),
    datetime('now')
),

-- Script atomique copy-file.remote.sh  
(
    'copy-file.remote.sh',
    'atomics/network/copy-file.remote.sh',
    'network',
    'ssh',
    'atomic',
    0,
    'Copie de fichiers vers/depuis un hôte distant via SCP/SFTP/rsync - Script Atomique Niveau 0',
    '{"host": {"type": "string", "required": true, "description": "Nom d''hôte ou adresse IP"}, "local_path": {"type": "string", "required": true, "description": "Chemin fichier/répertoire local"}, "remote_path": {"type": "string", "required": true, "description": "Chemin fichier/répertoire distant"}, "method": {"type": "string", "default": "scp", "values": ["scp", "sftp", "rsync"]}, "direction": {"type": "string", "default": "upload", "values": ["upload", "download", "sync"]}, "verify_checksum": {"type": "boolean", "default": true}, "recursive": {"type": "boolean", "default": false}}',
    '[]',
    '{"upload": {"description": "Upload fichier vers serveur", "command": "./copy-file.remote.sh --host server.example.com --local-path ./file.txt --remote-path /tmp/file.txt --direction upload", "output": "Status de transfert et checksum"}, "download": {"description": "Download fichier depuis serveur", "command": "./copy-file.remote.sh --host server.example.com --local-path ./file.txt --remote-path /tmp/file.txt --direction download", "output": "Fichier téléchargé avec vérification"}}',
    '1.0.0',
    datetime('now'),
    datetime('now')
),

-- Orchestrateur niveau 1 deploy-script.remote.sh
(
    'deploy-script.remote.sh',
    'orchestrators/level-1/deploy-script.remote.sh',
    'network',
    'ssh',
    'orchestrator',
    1,
    'Déploiement et exécution de script distant - Orchestrateur Niveau 1',
    '{"host": {"type": "string", "required": true, "description": "Nom d''hôte ou adresse IP"}, "script_path": {"type": "string", "required": true, "description": "Chemin du script local à déployer"}, "workdir": {"type": "string", "default": "/tmp", "description": "Répertoire de travail distant"}, "args": {"type": "string", "optional": true, "description": "Arguments pour le script"}, "timeout": {"type": "integer", "default": 300}, "cleanup": {"type": "boolean", "default": true}}',
    '["check-ssh.connection.sh", "copy-file.remote.sh", "execute-ssh.remote.sh"]',
    '{"deploy_and_run": {"description": "Déploie et exécute un script", "command": "./deploy-script.remote.sh --host server.example.com --script-path ./myscript.sh --workdir /tmp --args \"--verbose\"", "output": "Résultat complet du déploiement et exécution"}}',
    '1.0.0',
    datetime('now'),
    datetime('now')
),

-- Orchestrateur niveau 2 execute-workflow.remote.sh
(
    'execute-workflow.remote.sh',
    'orchestrators/level-2/execute-workflow.remote.sh',
    'network',
    'ssh',
    'orchestrator',
    2,
    'Exécution de workflow complet distant - Orchestrateur Niveau 2',
    '{"host": {"type": "string", "required": true, "description": "Nom d''hôte ou adresse IP"}, "workflow_name": {"type": "string", "required": true, "description": "Nom du workflow"}, "scripts": {"type": "array", "required": true, "description": "Liste des scripts à exécuter"}, "execution_mode": {"type": "string", "default": "sequential", "values": ["sequential", "parallel"]}, "setup_ssh": {"type": "boolean", "default": false}, "timeout": {"type": "integer", "default": 600}, "rollback_on_failure": {"type": "boolean", "default": true}}',
    '["deploy-script.remote.sh", "check-ssh.connection.sh", "generate-ssh.keypair.sh", "add-ssh.key.authorized.sh"]',
    '{"workflow_deployment": {"description": "Exécute workflow de déploiement", "command": "./execute-workflow.remote.sh --host server.example.com --workflow-name deployment --scripts \"[setup.sh, deploy.sh, test.sh]\" --execution-mode sequential", "output": "Résultats consolidés du workflow complet"}}',
    '1.0.0',
    datetime('now'),
    datetime('now')
);

-- Ajout des relations entre scripts
-- deploy-script.remote.sh utilise les scripts atomiques SSH
INSERT OR REPLACE INTO script_relationships (
    parent_script_id,
    child_script_id,
    relationship_type
) VALUES
(
    (SELECT id FROM scripts WHERE name = 'deploy-script.remote.sh'),
    (SELECT id FROM scripts WHERE name = 'check-ssh.connection.sh'),
    'uses'
),
(
    (SELECT id FROM scripts WHERE name = 'deploy-script.remote.sh'),
    (SELECT id FROM scripts WHERE name = 'copy-file.remote.sh'),
    'uses'
),
(
    (SELECT id FROM scripts WHERE name = 'deploy-script.remote.sh'),
    (SELECT id FROM scripts WHERE name = 'execute-ssh.remote.sh'),
    'uses'
);

-- execute-workflow.remote.sh utilise l'orchestrateur niveau 1 et les scripts atomiques
INSERT OR REPLACE INTO script_relationships (
    parent_script_id,
    child_script_id,
    relationship_type
) VALUES
(
    (SELECT id FROM scripts WHERE name = 'execute-workflow.remote.sh'),
    (SELECT id FROM scripts WHERE name = 'deploy-script.remote.sh'),
    'orchestrates'
),
(
    (SELECT id FROM scripts WHERE name = 'execute-workflow.remote.sh'),
    (SELECT id FROM scripts WHERE name = 'check-ssh.connection.sh'),
    'uses'
),
(
    (SELECT id FROM scripts WHERE name = 'execute-workflow.remote.sh'),
    (SELECT id FROM scripts WHERE name = 'generate-ssh.keypair.sh'),
    'uses'
),
(
    (SELECT id FROM scripts WHERE name = 'execute-workflow.remote.sh'),
    (SELECT id FROM scripts WHERE name = 'add-ssh.key.authorized.sh'),
    'uses'
);

-- Ajout des tags pour les nouveaux scripts SSH
INSERT OR REPLACE INTO script_tags (
    script_id,
    tag
) VALUES
-- Tags pour execute-ssh.remote.sh
((SELECT id FROM scripts WHERE name = 'execute-ssh.remote.sh'), 'ssh'),
((SELECT id FROM scripts WHERE name = 'execute-ssh.remote.sh'), 'remote'),
((SELECT id FROM scripts WHERE name = 'execute-ssh.remote.sh'), 'execution'),
((SELECT id FROM scripts WHERE name = 'execute-ssh.remote.sh'), 'atomic'),
((SELECT id FROM scripts WHERE name = 'execute-ssh.remote.sh'), 'network'),
((SELECT id FROM scripts WHERE name = 'execute-ssh.remote.sh'), 'json-output'),

-- Tags pour copy-file.remote.sh
((SELECT id FROM scripts WHERE name = 'copy-file.remote.sh'), 'ssh'),
((SELECT id FROM scripts WHERE name = 'copy-file.remote.sh'), 'file-transfer'),
((SELECT id FROM scripts WHERE name = 'copy-file.remote.sh'), 'scp'),
((SELECT id FROM scripts WHERE name = 'copy-file.remote.sh'), 'sftp'),
((SELECT id FROM scripts WHERE name = 'copy-file.remote.sh'), 'rsync'),
((SELECT id FROM scripts WHERE name = 'copy-file.remote.sh'), 'atomic'),
((SELECT id FROM scripts WHERE name = 'copy-file.remote.sh'), 'network'),
((SELECT id FROM scripts WHERE name = 'copy-file.remote.sh'), 'checksum'),

-- Tags pour deploy-script.remote.sh
((SELECT id FROM scripts WHERE name = 'deploy-script.remote.sh'), 'ssh'),
((SELECT id FROM scripts WHERE name = 'deploy-script.remote.sh'), 'deployment'),
((SELECT id FROM scripts WHERE name = 'deploy-script.remote.sh'), 'orchestrator'),
((SELECT id FROM scripts WHERE name = 'deploy-script.remote.sh'), 'level-1'),
((SELECT id FROM scripts WHERE name = 'deploy-script.remote.sh'), 'remote'),
((SELECT id FROM scripts WHERE name = 'deploy-script.remote.sh'), 'workflow'),

-- Tags pour execute-workflow.remote.sh
((SELECT id FROM scripts WHERE name = 'execute-workflow.remote.sh'), 'ssh'),
((SELECT id FROM scripts WHERE name = 'execute-workflow.remote.sh'), 'workflow'),
((SELECT id FROM scripts WHERE name = 'execute-workflow.remote.sh'), 'orchestrator'),
((SELECT id FROM scripts WHERE name = 'execute-workflow.remote.sh'), 'level-2'),
((SELECT id FROM scripts WHERE name = 'execute-workflow.remote.sh'), 'remote'),
((SELECT id FROM scripts WHERE name = 'execute-workflow.remote.sh'), 'automation'),
((SELECT id FROM scripts WHERE name = 'execute-workflow.remote.sh'), 'deployment'),
((SELECT id FROM scripts WHERE name = 'execute-workflow.remote.sh'), 'parallel-execution');

-- Affichage des nouveaux scripts ajoutés pour confirmation
SELECT 
    id,
    name,
    file_path,
    type,
    level,
    description,
    date_created
FROM scripts 
WHERE name IN (
    'execute-ssh.remote.sh',
    'copy-file.remote.sh', 
    'deploy-script.remote.sh',
    'execute-workflow.remote.sh'
)
ORDER BY level, name;

-- Affichage du nombre total de scripts SSH
SELECT 
    COUNT(*) as total_ssh_scripts,
    protocol,
    category
FROM scripts 
WHERE protocol = 'ssh' AND category = 'network'
GROUP BY protocol, category;