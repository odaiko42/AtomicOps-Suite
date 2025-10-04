-- Insertion du nouveau workflow SSH par défaut avec la structure correcte
INSERT OR REPLACE INTO scripts (
    name, type, category, protocol, level, file_path, description,
    parameters, dependencies, examples, version, date_created
) VALUES (
    'ssh-default-workflow',
    'orchestrator',
    'network',
    'ssh',
    1,
    'usb-disk-manager/scripts/orchestrators/network/ssh-default-workflow.sh',
    'Workflow par défaut pour connexion SSH avec exploration de répertoire complète. Orchestre les opérations : connexion SSH sécurisée, navigation vers /root/script, affichage récursif du contenu, et fermeture propre de session.',
    '{"host": {"type": "string", "default": "192.168.88.50", "description": "Serveur SSH cible"}, "user": {"type": "string", "default": "root", "description": "Utilisateur SSH"}, "key": {"type": "string", "optional": true, "description": "Chemin vers clé SSH privée"}, "timeout": {"type": "integer", "default": 30, "description": "Timeout connexion en secondes"}, "directory": {"type": "string", "default": "/root/script", "description": "Répertoire cible à explorer"}}',
    '["ssh-connect.sh", "ssh-execute-command.sh"]',
    '{"basic": {"command": "./ssh-default-workflow.sh", "description": "Workflow par défaut vers 192.168.88.50"}, "custom_host": {"command": "./ssh-default-workflow.sh --host 192.168.1.100 --user admin", "description": "Avec serveur personnalisé"}, "with_key": {"command": "./ssh-default-workflow.sh --key ~/.ssh/id_rsa_server", "description": "Avec clé SSH spécifique"}, "debug": {"command": "./ssh-default-workflow.sh --debug --directory /home/user/projects", "description": "Mode debug avec répertoire personnalisé"}}',
    '1.0.0',
    datetime('now')
);

-- Récupérer l'ID du script inséré
SELECT last_insert_rowid() as script_id, 'ssh-default-workflow' as script_name;

-- Ajouter les tags au script (en utilisant l'ID)
INSERT INTO script_tags (script_id, tag) 
VALUES 
    ((SELECT id FROM scripts WHERE name = 'ssh-default-workflow'), 'ssh'),
    ((SELECT id FROM scripts WHERE name = 'ssh-default-workflow'), 'workflow'),
    ((SELECT id FROM scripts WHERE name = 'ssh-default-workflow'), 'orchestrateur'),
    ((SELECT id FROM scripts WHERE name = 'ssh-default-workflow'), 'default'),
    ((SELECT id FROM scripts WHERE name = 'ssh-default-workflow'), 'exploration'),
    ((SELECT id FROM scripts WHERE name = 'ssh-default-workflow'), 'connexion'),
    ((SELECT id FROM scripts WHERE name = 'ssh-default-workflow'), 'navigation');

-- Affichage de confirmation
SELECT 'WORKFLOW SSH AJOUTÉ AVEC SUCCÈS' as status;
SELECT name, type, level, category, protocol FROM scripts WHERE name = 'ssh-default-workflow';