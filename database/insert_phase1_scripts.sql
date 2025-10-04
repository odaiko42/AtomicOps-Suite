-- Insertion des scripts atomiques Phase 1 dans la base de données
INSERT OR REPLACE INTO scripts (
    nom,
    type_script,
    description,
    chemin_absolu,
    taille_octets,
    date_creation,
    date_modification,
    statut,
    version,
    auteur,
    compatibilite_os,
    niveau_complexite,
    temps_execution_moyen,
    consommation_ressources,
    notes,
    tags
) VALUES 
-- get-system.info.sh
(
    'get-system.info.sh',
    'utilitaire',
    'Récupère les informations système complètes (hostname, OS, version, architecture, uptime, kernel)',
    '/home/eforgues/CT/atomics/get-system.info.sh',
    9212,
    datetime('now'),
    datetime('now'),
    'actif',
    '1.0',
    'Generated with AI assistance',
    'linux',
    'simple',
    2,
    'faible',
    'Script atomique Phase 1 - Testé et validé sur Zorin OS 17',
    'system,info,hostname,os,kernel,uptime,phase1,atomique'
),

-- list-user.all.sh
(
    'list-user.all.sh',
    'utilitaire',
    'Liste tous les utilisateurs système avec informations détaillées (username, UID, GID, home, shell)',
    '/home/eforgues/CT/atomics/list-user.all.sh',
    6453,
    datetime('now'),
    datetime('now'),
    'actif',
    '1.0',
    'Generated with AI assistance',
    'linux',
    'simple',
    1,
    'faible',
    'Script atomique Phase 1 - Supporte filtrage utilisateurs humains uniquement',
    'users,list,uid,gid,home,shell,phase1,atomique'
),

-- list-service.all.sh
(
    'list-service.all.sh',
    'utilitaire',
    'Liste tous les services systemd avec leurs états (active/inactive, enabled/disabled)',
    '/home/eforgues/CT/atomics/list-service.all.sh',
    8532,
    datetime('now'),
    datetime('now'),
    'actif',
    '1.0',
    'Generated with AI assistance',
    'linux',
    'simple',
    3,
    'faible',
    'Script atomique Phase 1 - Supporte filtrage services actifs/enabled uniquement',
    'services,systemd,active,enabled,status,phase1,atomique'
),

-- get-disk.usage.sh
(
    'get-disk.usage.sh',
    'utilitaire',
    'Récupère les informations d''utilisation des disques/partitions avec formats multiples',
    '/home/eforgues/CT/atomics/get-disk.usage.sh',
    13000,
    datetime('now'),
    datetime('now'),
    'actif',
    '1.0',
    'Generated with AI assistance',
    'linux',
    'simple',
    2,
    'faible',
    'Script atomique Phase 1 - Supporte formats human/bytes/kb/mb/gb, filtrage tmpfs',
    'disk,usage,filesystem,space,df,phase1,atomique'
),

-- get-memory.usage.sh
(
    'get-memory.usage.sh',
    'utilitaire',
    'Récupère les statistiques d''utilisation mémoire (RAM, swap, buffers, cache)',
    '/home/eforgues/CT/atomics/get-memory.usage.sh',
    11000,
    datetime('now'),
    datetime('now'),
    'actif',
    '1.0',
    'Generated with AI assistance',
    'linux',
    'simple',
    1,
    'faible',
    'Script atomique Phase 1 - Analyse /proc/meminfo, formats multiples',
    'memory,ram,swap,buffers,cache,meminfo,phase1,atomique'
),

-- list-network.interfaces.sh
(
    'list-network.interfaces.sh',
    'utilitaire',
    'Liste toutes les interfaces réseau avec configurations, états et statistiques',
    '/home/eforgues/CT/atomics/list-network.interfaces.sh',
    13000,
    datetime('now'),
    datetime('now'),
    'actif',
    '1.0',
    'Generated with AI assistance',
    'linux',
    'simple',
    2,
    'faible',
    'Script atomique Phase 1 - Supporte filtrage actives uniquement, IP v4/v6, stats trafic',
    'network,interfaces,ip,mac,mtu,stats,phase1,atomique'
);