-- Script SQL pour mise à jour de la base de données catalogue avec nouveaux scripts SSH
-- Ajout des scripts SSH manquants selon le catalogue SSH.mp

-- Insertion des nouveaux scripts atomiques SSH
INSERT OR REPLACE INTO scripts (
    name, 
    path, 
    category, 
    level, 
    description,
    protocol,
    status,
    created_at,
    updated_at
) VALUES 
-- Script atomique execute-ssh.remote.sh
(
    'execute-ssh.remote.sh',
    'atomics/network/execute-ssh.remote.sh',
    'network',
    0,
    'Exécution de commandes SSH distantes avec récupération JSON - Script Atomique Niveau 0',
    'ssh',
    'active',
    datetime('now'),
    datetime('now')
),

-- Script atomique copy-file.remote.sh  
(
    'copy-file.remote.sh',
    'atomics/network/copy-file.remote.sh',
    'network',
    0,
    'Copie de fichiers vers/depuis un hôte distant via SCP/SFTP/rsync - Script Atomique Niveau 0',
    'ssh',
    'active',
    datetime('now'),
    datetime('now')
);

-- Insertion des nouveaux orchestrateurs SSH
INSERT OR REPLACE INTO scripts (
    name,
    path,
    category,
    level,
    description,
    protocol,
    status,
    created_at,
    updated_at
) VALUES
-- Orchestrateur niveau 1 deploy-script.remote.sh
(
    'deploy-script.remote.sh',
    'orchestrators/level-1/deploy-script.remote.sh',
    'network',
    1,
    'Déploiement et exécution de script distant - Orchestrateur Niveau 1',
    'ssh',
    'active',
    datetime('now'),
    datetime('now')
),

-- Orchestrateur niveau 2 execute-workflow.remote.sh
(
    'execute-workflow.remote.sh',
    'orchestrators/level-2/execute-workflow.remote.sh', 
    'network',
    2,
    'Exécution de workflow complet distant - Orchestrateur Niveau 2',
    'ssh',
    'active',
    datetime('now'),
    datetime('now')
);

-- Mise à jour des dépendances pour les nouveaux orchestrateurs
-- deploy-script.remote.sh utilise les scripts atomiques SSH
INSERT OR REPLACE INTO dependencies (
    script_name,
    dependency_name,
    dependency_type,
    created_at
) VALUES
('deploy-script.remote.sh', 'check-ssh.connection.sh', 'atomic', datetime('now')),
('deploy-script.remote.sh', 'copy-file.remote.sh', 'atomic', datetime('now')),  
('deploy-script.remote.sh', 'execute-ssh.remote.sh', 'atomic', datetime('now'));

-- execute-workflow.remote.sh utilise l'orchestrateur niveau 1 et les scripts atomiques
INSERT OR REPLACE INTO dependencies (
    script_name,
    dependency_name,
    dependency_type,
    created_at
) VALUES
('execute-workflow.remote.sh', 'deploy-script.remote.sh', 'orchestrator', datetime('now')),
('execute-workflow.remote.sh', 'check-ssh.connection.sh', 'atomic', datetime('now')),
('execute-workflow.remote.sh', 'generate-ssh.keypair.sh', 'atomic', datetime('now')),
('execute-workflow.remote.sh', 'add-ssh.key.authorized.sh', 'atomic', datetime('now'));

-- Ajout des paramètres spécifiques aux nouveaux scripts SSH
INSERT OR REPLACE INTO script_parameters (
    script_name,
    parameter_name,
    parameter_type,
    is_required,
    default_value,
    description,
    created_at
) VALUES 
-- Paramètres pour execute-ssh.remote.sh
('execute-ssh.remote.sh', 'host', 'string', 1, NULL, 'Nom d''hôte ou adresse IP du serveur distant', datetime('now')),
('execute-ssh.remote.sh', 'command', 'string', 1, NULL, 'Commande à exécuter sur l''hôte distant', datetime('now')),
('execute-ssh.remote.sh', 'port', 'integer', 0, '22', 'Port SSH', datetime('now')),
('execute-ssh.remote.sh', 'user', 'string', 0, 'current_user', 'Utilisateur SSH', datetime('now')),
('execute-ssh.remote.sh', 'identity', 'string', 0, NULL, 'Fichier de clé privée SSH', datetime('now')),
('execute-ssh.remote.sh', 'timeout', 'integer', 0, '30', 'Timeout de connexion en secondes', datetime('now')),
('execute-ssh.remote.sh', 'retries', 'integer', 0, '3', 'Nombre de tentatives max', datetime('now')),

-- Paramètres pour copy-file.remote.sh
('copy-file.remote.sh', 'host', 'string', 1, NULL, 'Nom d''hôte ou adresse IP du serveur distant', datetime('now')),
('copy-file.remote.sh', 'local_path', 'string', 1, NULL, 'Chemin du fichier/répertoire local', datetime('now')),
('copy-file.remote.sh', 'remote_path', 'string', 1, NULL, 'Chemin du fichier/répertoire distant', datetime('now')),
('copy-file.remote.sh', 'method', 'string', 0, 'scp', 'Méthode de transfert (scp|sftp|rsync)', datetime('now')),
('copy-file.remote.sh', 'direction', 'string', 0, 'upload', 'Direction du transfert (upload|download|sync)', datetime('now')),
('copy-file.remote.sh', 'verify_checksum', 'boolean', 0, 'true', 'Vérifier l''intégrité par checksum', datetime('now')),
('copy-file.remote.sh', 'recursive', 'boolean', 0, 'false', 'Copie récursive des répertoires', datetime('now')),

-- Paramètres pour deploy-script.remote.sh  
('deploy-script.remote.sh', 'host', 'string', 1, NULL, 'Nom d''hôte ou adresse IP du serveur distant', datetime('now')),
('deploy-script.remote.sh', 'script_path', 'string', 1, NULL, 'Chemin du script local à déployer', datetime('now')),
('deploy-script.remote.sh', 'workdir', 'string', 0, '/tmp', 'Répertoire de travail distant', datetime('now')),
('deploy-script.remote.sh', 'args', 'string', 0, NULL, 'Arguments à passer au script distant', datetime('now')),
('deploy-script.remote.sh', 'timeout', 'integer', 0, '300', 'Timeout global d''exécution', datetime('now')),
('deploy-script.remote.sh', 'cleanup', 'boolean', 0, 'true', 'Nettoyer les fichiers après exécution', datetime('now')),

-- Paramètres pour execute-workflow.remote.sh
('execute-workflow.remote.sh', 'host', 'string', 1, NULL, 'Nom d''hôte ou adresse IP du serveur distant', datetime('now')),
('execute-workflow.remote.sh', 'workflow_name', 'string', 1, NULL, 'Nom du workflow à exécuter', datetime('now')),
('execute-workflow.remote.sh', 'scripts', 'array', 1, NULL, 'Scripts du workflow (ordre d''exécution)', datetime('now')),
('execute-workflow.remote.sh', 'execution_mode', 'string', 0, 'sequential', 'Mode d''exécution (sequential|parallel)', datetime('now')),
('execute-workflow.remote.sh', 'setup_ssh', 'boolean', 0, 'false', 'Configurer l''accès SSH automatiquement', datetime('now')),
('execute-workflow.remote.sh', 'timeout', 'integer', 0, '600', 'Timeout global d''exécution', datetime('now')),
('execute-workflow.remote.sh', 'rollback_on_failure', 'boolean', 0, 'true', 'Rollback automatique en cas d''échec', datetime('now'));

-- Ajout des tags pour faciliter la recherche
INSERT OR REPLACE INTO script_tags (
    script_name,
    tag_name,
    created_at
) VALUES
-- Tags pour execute-ssh.remote.sh
('execute-ssh.remote.sh', 'ssh', datetime('now')),
('execute-ssh.remote.sh', 'remote', datetime('now')),
('execute-ssh.remote.sh', 'execution', datetime('now')),
('execute-ssh.remote.sh', 'atomic', datetime('now')),
('execute-ssh.remote.sh', 'network', datetime('now')),

-- Tags pour copy-file.remote.sh
('copy-file.remote.sh', 'ssh', datetime('now')),
('copy-file.remote.sh', 'file-transfer', datetime('now')),
('copy-file.remote.sh', 'scp', datetime('now')),
('copy-file.remote.sh', 'sftp', datetime('now')),
('copy-file.remote.sh', 'rsync', datetime('now')),
('copy-file.remote.sh', 'atomic', datetime('now')),
('copy-file.remote.sh', 'network', datetime('now')),

-- Tags pour deploy-script.remote.sh
('deploy-script.remote.sh', 'ssh', datetime('now')),
('deploy-script.remote.sh', 'deployment', datetime('now')),
('deploy-script.remote.sh', 'orchestrator', datetime('now')),
('deploy-script.remote.sh', 'level-1', datetime('now')),
('deploy-script.remote.sh', 'remote', datetime('now')),
('deploy-script.remote.sh', 'workflow', datetime('now')),

-- Tags pour execute-workflow.remote.sh
('execute-workflow.remote.sh', 'ssh', datetime('now')),
('execute-workflow.remote.sh', 'workflow', datetime('now')),
('execute-workflow.remote.sh', 'orchestrator', datetime('now')),
('execute-workflow.remote.sh', 'level-2', datetime('now')),
('execute-workflow.remote.sh', 'remote', datetime('now')),
('execute-workflow.remote.sh', 'automation', datetime('now')),
('execute-workflow.remote.sh', 'deployment', datetime('now'));

-- Mise à jour des statistiques
UPDATE metadata 
SET value = (
    SELECT COUNT(*) 
    FROM scripts 
    WHERE category = 'network' AND protocol = 'ssh'
)
WHERE key = 'ssh_scripts_count';

-- Affichage des nouveaux scripts ajoutés
SELECT 
    name,
    path,
    level,
    description,
    created_at
FROM scripts 
WHERE name IN (
    'execute-ssh.remote.sh',
    'copy-file.remote.sh', 
    'deploy-script.remote.sh',
    'execute-workflow.remote.sh'
)
ORDER BY level, name;