-- =====================================================
-- BASE DE DONNÉES SQLite3 POUR LES TYPES D'INPUTS
-- AtomicOps-Suite - Système de gestion des paramètres d'entrée
-- =====================================================

-- Suppression et création de la table des types d'inputs
DROP TABLE IF EXISTS input_parameter_types;

CREATE TABLE input_parameter_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_name VARCHAR(20) NOT NULL UNIQUE,
    display_label VARCHAR(50) NOT NULL,
    color_hex VARCHAR(7) NOT NULL,
    validation_regex TEXT,
    validation_message VARCHAR(200),
    default_value VARCHAR(100),
    description TEXT,
    category VARCHAR(20),
    is_required BOOLEAN DEFAULT FALSE,
    min_length INTEGER,
    max_length INTEGER,
    examples VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertion des 13 types d'inputs avec leurs propriétés complètes
INSERT INTO input_parameter_types (
    type_name, display_label, color_hex, validation_regex, validation_message, 
    default_value, description, category, is_required, min_length, max_length, examples
) VALUES 
    -- Paramètres réseau
    (
        'ip', 'Adresse IP', '#3b82f6',
        '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
        'Format IP invalide (ex: 192.168.1.1)',
        '192.168.88.210',
        'Adresse IP version 4 pour la connexion réseau',
        'network', TRUE, 7, 15,
        '192.168.1.1, 10.0.0.1, 172.16.0.1, 127.0.0.1'
    ),
    (
        'hostname', 'Nom d''hôte', '#06b6d4',
        '^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$',
        'Format hostname invalide (ex: server.domain.com)',
        'proxmox.local',
        'Nom d''hôte ou FQDN pour identifier un serveur',
        'network', FALSE, 1, 253,
        'server1, web.example.com, db-master.local, api.company.org'
    ),
    (
        'url', 'URL', '#8b5cf6',
        NULL,
        'URL invalide (ex: https://example.com/path)',
        'https://logs.example.com/api',
        'URL complète pour accéder à un service web',
        'network', FALSE, 8, 2048,
        'https://api.example.com, http://localhost:8080, ftp://files.company.com'
    ),
    (
        'email', 'Email', '#ec4899',
        '^[^\s@]+@[^\s@]+\.[^\s@]+$',
        'Format email invalide (ex: user@domain.com)',
        'admin@example.com',
        'Adresse email pour les notifications et contacts',
        'network', FALSE, 5, 320,
        'admin@company.com, user.name@domain.org, support@example.fr'
    ),
    (
        'port', 'Port', '#6366f1',
        '^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$',
        'Port invalide (1-65535)',
        '22',
        'Numéro de port TCP/UDP pour les connexions réseau',
        'network', FALSE, 1, 5,
        '22, 80, 443, 3306, 5432, 8080, 9000'
    ),

    -- Paramètres d'authentification
    (
        'username', 'Nom d''utilisateur', '#84cc16',
        '^[a-zA-Z0-9]([a-zA-Z0-9\-_]{0,30}[a-zA-Z0-9])?$',
        'Username invalide (lettres, chiffres, - et _)',
        'root',
        'Nom d''utilisateur pour l''authentification système',
        'auth', TRUE, 1, 32,
        'root, admin, user1, service-account, backup_user'
    ),
    (
        'password', 'Mot de passe', '#f97316',
        NULL,
        'Mot de passe trop court (min 8 caractères)',
        '',
        'Mot de passe sécurisé pour l''authentification',
        'auth', TRUE, 8, 128,
        'MySecurePass123!, P@ssw0rd2024, AdminSecret456'
    ),
    (
        'token', 'Token', '#a855f7',
        '^[a-zA-Z0-9\-_\.=]+$',
        'Token invalide (min 16 chars, alphanumériques + -_.=)',
        '',
        'Token d''authentification ou clé SSH',
        'auth', FALSE, 16, 4096,
        'ssh-ed25519 AAAAC3NzaC1..., eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
    ),

    -- Paramètres système et stockage
    (
        'device', 'Périphérique', '#ef4444',
        '^/dev/[a-zA-Z0-9]+[a-zA-Z0-9]*$',
        'Chemin de périphérique invalide (ex: /dev/sdb1)',
        '/dev/sdb1',
        'Chemin vers un périphérique de stockage système',
        'system', FALSE, 5, 50,
        '/dev/sda1, /dev/sdb, /dev/nvme0n1, /dev/mapper/data'
    ),
    (
        'path', 'Chemin', '#10b981',
        '^(/[^/\0]+)*/?$',
        'Chemin de fichier invalide (ex: /home/user/file.txt)',
        '/tmp',
        'Chemin vers un fichier ou répertoire sur le système',
        'system', FALSE, 1, 4096,
        '/home/user/script.sh, /etc/config.conf, /var/log/app.log'
    ),
    (
        'iqn', 'IQN iSCSI', '#f59e0b',
        '^iqn\.\d{4}-\d{2}\.[a-zA-Z0-9\-\.]+(:.*)?$',
        'Format IQN invalide (ex: iqn.2025-01.com.example:target1)',
        'iqn.2025-01.com.example:target1',
        'Identificateur iSCSI Qualified Name pour le stockage réseau',
        'system', FALSE, 10, 200,
        'iqn.2025-01.com.example:target1, iqn.1998-01.com.vmware:server-backup'
    ),
    (
        'size', 'Taille', '#d946ef',
        '^[1-9][0-9]*[KMGT]?[Bb]?$|^[1-9][0-9]*$',
        'Taille invalide (ex: 4096, 1GB, 500MB)',
        '4096',
        'Taille en octets, Ko, Mo, Go ou To',
        'system', FALSE, 1, 20,
        '1024, 4096, 1GB, 500MB, 2TB, 8192'
    ),
    (
        'timeout', 'Timeout', '#14b8a6',
        '^[1-9][0-9]*$',
        'Timeout invalide (1-86400 secondes)',
        '10',
        'Délai d''expiration en secondes pour les opérations',
        'system', FALSE, 1, 5,
        '10, 30, 60, 300, 3600'
    );

-- Index pour optimiser les requêtes
CREATE INDEX idx_input_type_name ON input_parameter_types(type_name);
CREATE INDEX idx_input_category ON input_parameter_types(category);

-- =====================================================
-- REQUÊTES UTILES POUR LA GESTION DES INPUTS
-- =====================================================

-- Vue pour les paramètres réseau
CREATE VIEW network_input_types AS
SELECT * FROM input_parameter_types WHERE category = 'network';

-- Vue pour les paramètres d'authentification
CREATE VIEW auth_input_types AS
SELECT * FROM input_parameter_types WHERE category = 'auth';

-- Vue pour les paramètres système
CREATE VIEW system_input_types AS
SELECT * FROM input_parameter_types WHERE category = 'system';

-- =====================================================
-- REQUÊTES D'EXEMPLE POUR UTILISATION
-- =====================================================

-- Récupérer tous les types d'inputs avec leurs propriétés
-- SELECT * FROM input_parameter_types ORDER BY category, type_name;

-- Récupérer les inputs par catégorie
-- SELECT type_name, display_label, color_hex FROM input_parameter_types WHERE category = 'network';

-- Rechercher un input par son nom
-- SELECT * FROM input_parameter_types WHERE type_name = 'ip';

-- Récupérer les inputs requis
-- SELECT type_name, display_label FROM input_parameter_types WHERE is_required = TRUE;

-- Statistiques par catégorie
-- SELECT category, COUNT(*) as total_inputs FROM input_parameter_types GROUP BY category;

-- Export JSON des types d'inputs (pour import dans l'application)
-- SELECT json_group_array(
--     json_object(
--         'type', type_name,
--         'label', display_label,
--         'color', color_hex,
--         'regex', validation_regex,
--         'message', validation_message,
--         'default', default_value,
--         'category', category,
--         'required', is_required,
--         'examples', examples
--     )
-- ) as input_types_json FROM input_parameter_types;

PRAGMA table_info(input_parameter_types);