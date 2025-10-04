// ===========================
// Données de test pour le développement
// ===========================

import { Script } from '../services/sqliteDataService';

export const mockScripts: Script[] = [
  {
    id: 'script_001',
    name: 'create-base-CT.sh',
    description: 'Script de création de conteneur de base avec configuration minimale',
    category: 'ct-creation',
    level: 0,
    status: 'stable',
    complexity: 'simple',
    path: '/root/scripts/create-base-CT.sh',
    lastModified: new Date('2024-01-15').toISOString(),
    tags: ['proxmox', 'container', 'base', 'debian'],
    functions: [
      {
        id: 'func_001',
        name: 'bootstrap_base_inside',
        description: 'Configure le conteneur de base avec les paquets essentiels',
        inputs: ['CTID'],
        outputs: ['container_ready']
      },
      {
        id: 'func_002',
        name: 'pick_free_ctid',
        description: 'Trouve un CTID libre pour le nouveau conteneur',
        inputs: [],
        outputs: ['free_ctid']
      }
    ],
    dependencies: []
  },
  {
    id: 'script_002',
    name: 'create-docker-CT.sh',
    description: 'Création de conteneur avec Docker pré-installé et configuré',
    category: 'ct-creation',
    level: 1,
    status: 'stable',
    complexity: 'moyen',
    path: '/root/scripts/create-docker-CT.sh',
    lastModified: new Date('2024-01-20').toISOString(),
    tags: ['proxmox', 'docker', 'container', 'orchestration'],
    functions: [
      {
        id: 'func_003',
        name: 'install_docker',
        description: 'Installation et configuration de Docker dans le conteneur',
        inputs: ['CTID'],
        outputs: ['docker_ready']
      },
      {
        id: 'func_004',
        name: 'configure_docker_daemon',
        description: 'Configuration du daemon Docker avec les bonnes pratiques',
        inputs: ['CTID', 'docker_config'],
        outputs: ['daemon_configured']
      }
    ],
    dependencies: ['script_001'] // Dépend du script de base
  },
  {
    id: 'script_003',
    name: 'setup-iscsi-target.sh',
    description: 'Configuration d\'un target iSCSI avec LVM et authentification',
    category: 'usb-disk-manager/orchestrators',
    level: 2,
    status: 'testing',
    complexity: 'complexe',
    path: '/root/usb-disk-manager/scripts/orchestrators/setup-iscsi-target.sh',
    lastModified: new Date('2024-02-01').toISOString(),
    tags: ['iscsi', 'storage', 'lvm', 'authentification'],
    functions: [
      {
        id: 'func_005',
        name: 'create_lvm_volume',
        description: 'Création d\'un volume LVM pour le stockage iSCSI',
        inputs: ['device_path', 'volume_size'],
        outputs: ['lvm_volume_path']
      },
      {
        id: 'func_006',
        name: 'configure_target_auth',
        description: 'Configuration de l\'authentification CHAP pour le target',
        inputs: ['target_iqn', 'username', 'password'],
        outputs: ['auth_configured']
      }
    ],
    dependencies: ['script_004', 'script_005'] // Dépend d'autres scripts USB
  },
  {
    id: 'script_004',
    name: 'select-disk.sh',
    description: 'Sélection interactive de disque USB avec validation',
    category: 'usb-disk-manager/atomic',
    level: 0,
    status: 'stable',
    complexity: 'simple',
    path: '/root/usb-disk-manager/scripts/atomic/select-disk.sh',
    lastModified: new Date('2024-01-25').toISOString(),
    tags: ['usb', 'disk', 'selection', 'interface'],
    functions: [
      {
        id: 'func_007',
        name: 'list_usb_disks',
        description: 'Liste tous les disques USB détectés sur le système',
        inputs: [],
        outputs: ['usb_disk_list']
      },
      {
        id: 'func_008',
        name: 'validate_disk_selection',
        description: 'Valide que le disque sélectionné est approprié',
        inputs: ['disk_path'],
        outputs: ['validation_result']
      }
    ],
    dependencies: []
  },
  {
    id: 'script_005',
    name: 'format-disk.sh',
    description: 'Formatage sécurisé de disque avec support LVM',
    category: 'usb-disk-manager/atomic',
    level: 1,
    status: 'stable',
    complexity: 'moyen',
    path: '/root/usb-disk-manager/scripts/atomic/format-disk.sh',
    lastModified: new Date('2024-01-28').toISOString(),
    tags: ['format', 'lvm', 'security', 'disk'],
    functions: [
      {
        id: 'func_009',
        name: 'secure_wipe_disk',
        description: 'Effacement sécurisé du disque avant formatage',
        inputs: ['disk_path'],
        outputs: ['wipe_completed']
      },
      {
        id: 'func_010',
        name: 'create_lvm_structure',
        description: 'Création de la structure LVM sur le disque',
        inputs: ['disk_path', 'vg_name'],
        outputs: ['lvm_ready']
      }
    ],
    dependencies: ['script_004']
  },
  {
    id: 'script_006',
    name: 'ct-launcher.sh',
    description: 'Interface de lancement interactive pour tous les types de CT',
    category: 'ct-main',
    level: 3,
    status: 'stable',
    complexity: 'complexe',
    path: '/root/ct-launcher.sh',
    lastModified: new Date('2024-02-05').toISOString(),
    tags: ['interface', 'menu', 'launcher', 'orchestration'],
    functions: [
      {
        id: 'func_011',
        name: 'show_ct_menu',
        description: 'Affiche le menu principal de sélection de type de CT',
        inputs: [],
        outputs: ['selected_ct_type']
      },
      {
        id: 'func_012',
        name: 'launch_ct_creation',
        description: 'Lance le script de création approprié selon le type choisi',
        inputs: ['ct_type', 'parameters'],
        outputs: ['ct_creation_result']
      }
    ],
    dependencies: ['script_001', 'script_002', 'script_007']
  },
  {
    id: 'script_007',
    name: 'create-web-CT.sh',
    description: 'Création de conteneur web avec Nginx, PHP et base de données',
    category: 'ct-creation',
    level: 2,
    status: 'testing',
    complexity: 'complexe',
    path: '/root/scripts/create-web-CT.sh',
    lastModified: new Date('2024-02-03').toISOString(),
    tags: ['web', 'nginx', 'php', 'database', 'lamp'],
    functions: [
      {
        id: 'func_013',
        name: 'install_web_stack',
        description: 'Installation complète de la stack web (Nginx + PHP + MariaDB)',
        inputs: ['CTID', 'stack_config'],
        outputs: ['web_stack_ready']
      },
      {
        id: 'func_014',
        name: 'configure_virtual_hosts',
        description: 'Configuration des hôtes virtuels Nginx',
        inputs: ['CTID', 'vhost_configs'],
        outputs: ['vhosts_configured']
      }
    ],
    dependencies: ['script_001']
  },
  {
    id: 'script_008',
    name: 'lib-ct-common.sh',
    description: 'Bibliothèque de fonctions communes pour la gestion des CT',
    category: 'lib',
    level: 0,
    status: 'stable',
    complexity: 'moyen',
    path: '/root/lib/lib-ct-common.sh',
    lastModified: new Date('2024-01-10').toISOString(),
    tags: ['library', 'common', 'utilities', 'logging'],
    functions: [
      {
        id: 'func_015',
        name: 'info',
        description: 'Affichage de messages d\'information avec formatage',
        inputs: ['message'],
        outputs: ['formatted_output']
      },
      {
        id: 'func_016',
        name: 'warn',
        description: 'Affichage d\'avertissements avec formatage coloré',
        inputs: ['message'],
        outputs: ['warning_output']
      },
      {
        id: 'func_017',
        name: 'die',
        description: 'Affichage d\'erreur et arrêt du script',
        inputs: ['error_message', 'exit_code'],
        outputs: ['script_exit']
      },
      {
        id: 'func_018',
        name: 'find_debian12_template',
        description: 'Recherche et retourne la référence du template Debian 12',
        inputs: [],
        outputs: ['template_reference']
      }
    ],
    dependencies: []
  }
];

// Ajout de scripts atomiques réalistes du projet
const atomicScripts: Script[] = [
  {
    id: 'atomic_001',
    name: 'check-network.connectivity.sh',
    description: 'Vérifie la connectivité réseau vers des hôtes spécifiés',
    category: 'network',
    level: 0,
    status: 'stable',
    complexity: 'low',
    path: '/root/atomics/check-network.connectivity.sh',
    lastModified: new Date('2024-02-01').toISOString(),
    tags: ['network', 'connectivity', 'ping', 'monitoring'],
    functions: [
      {
        name: 'test_connectivity',
        description: 'Test de connectivité vers un hôte',
        inputs: ['host', 'timeout'],
        outputs: ['connection_status']
      }
    ]
  },
  {
    id: 'atomic_002',
    name: 'get-system.info.sh',
    description: 'Collecte les informations système (OS, CPU, RAM)',
    category: 'system',
    level: 0,
    status: 'stable',
    complexity: 'low',
    path: '/root/atomics/get-system.info.sh',
    lastModified: new Date('2024-01-20').toISOString(),
    tags: ['system', 'info', 'monitoring', 'hardware'],
    functions: [
      {
        name: 'get_os_info',
        description: 'Récupère les informations OS',
        inputs: [],
        outputs: ['os_name', 'os_version']
      },
      {
        name: 'get_hardware_info',
        description: 'Récupère les informations matérielles',
        inputs: [],
        outputs: ['cpu_info', 'memory_info']
      }
    ]
  },
  {
    id: 'atomic_003',
    name: 'backup-directory.sh',
    description: 'Sauvegarde complète d\'un répertoire avec compression',
    category: 'file',
    level: 0,
    status: 'stable',
    complexity: 'medium',
    path: '/root/atomics/backup-directory.sh',
    lastModified: new Date('2024-01-25').toISOString(),
    tags: ['backup', 'compression', 'tar', 'archive'],
    functions: [
      {
        name: 'create_backup',
        description: 'Crée une archive tar.gz du répertoire',
        inputs: ['source_dir', 'backup_path'],
        outputs: ['backup_file']
      }
    ]
  },
  {
    id: 'atomic_004',
    name: 'detect-disk.all.sh',
    description: 'Détecte tous les disques disponibles sur le système',
    category: 'system',
    level: 0,
    status: 'stable',
    complexity: 'low',
    path: '/root/atomics/detect-disk.all.sh',
    lastModified: new Date('2024-02-05').toISOString(),
    tags: ['disk', 'detection', 'storage', 'hardware'],
    functions: [
      {
        name: 'list_all_disks',
        description: 'Liste tous les disques détectés',
        inputs: [],
        outputs: ['disk_list']
      }
    ]
  }
];

// Scripts de performance
const performanceScripts: Script[] = [
  {
    id: 'perf_001',
    name: 'get-cpu.info.sh',
    description: 'Collecte des informations détaillées sur le processeur',
    category: 'performance',
    level: 0,
    status: 'stable',
    complexity: 'simple',
    path: '/root/atomics/performance/cpu/get-cpu.info.sh',
    lastModified: new Date('2025-10-04').toISOString(),
    tags: ['cpu', 'info', 'monitoring', 'hardware'],
    functions: [
      {
        name: 'get_cpu_details',
        description: 'Récupère les détails du processeur',
        inputs: ['format'],
        outputs: ['cpu_info', 'architecture', 'frequencies']
      }
    ],
    dependencies: []
  },
  {
    id: 'perf_002',
    name: 'get-memory.info.sh',
    description: 'Informations complètes sur la mémoire système',
    category: 'performance',
    level: 0,
    status: 'stable',
    complexity: 'simple',
    path: '/root/atomics/performance/memory/get-memory.info.sh',
    lastModified: new Date('2025-10-04').toISOString(),
    tags: ['memory', 'ram', 'monitoring', 'system'],
    functions: [
      {
        name: 'get_memory_stats',
        description: 'Statistiques mémoire détaillées',
        inputs: ['detail_level'],
        outputs: ['memory_info', 'swap_info', 'usage_stats']
      }
    ],
    dependencies: []
  },
  {
    id: 'perf_003',
    name: 'benchmark-disk.speed.sh',
    description: 'Benchmark de vitesse des disques',
    category: 'performance',
    level: 1,
    status: 'stable',
    complexity: 'moyen',
    path: '/root/atomics/performance/io/benchmark-disk.speed.sh',
    lastModified: new Date('2025-10-04').toISOString(),
    tags: ['disk', 'benchmark', 'io', 'performance'],
    functions: [
      {
        name: 'run_disk_benchmark',
        description: 'Effectue les tests de vitesse disque',
        inputs: ['target_path', 'file_size'],
        outputs: ['read_speed', 'write_speed', 'latency']
      }
    ],
    dependencies: []
  },
  {
    id: 'perf_004',
    name: 'get-network.bandwidth.sh',
    description: 'Mesure la bande passante réseau en temps réel',
    category: 'performance',
    level: 0,
    status: 'stable',
    complexity: 'moyen',
    path: '/root/atomics/performance/network/get-network.bandwidth.sh',
    lastModified: new Date('2025-10-04').toISOString(),
    tags: ['network', 'bandwidth', 'monitoring', 'traffic'],
    functions: [
      {
        name: 'measure_bandwidth',
        description: 'Mesure la bande passante par interface',
        inputs: ['interface', 'interval'],
        outputs: ['rx_bandwidth', 'tx_bandwidth', 'statistics']
      }
    ],
    dependencies: []
  }
];

// Scripts SSH atomiques (niveau 0) et orchestrateurs (niveau 1)
const sshScripts: Script[] = [
  // === SCRIPTS ATOMIQUES SSH (NIVEAU 0) ===
  {
    id: 'ssh_001',
    name: 'generate-ssh.keypair.sh',
    description: 'Génère une paire de clés SSH sécurisée avec configuration optimale',
    category: 'network',
    level: 0,
    status: 'stable',
    complexity: 'low',
    path: '/root/atomics/network/generate-ssh.keypair.sh',
    lastModified: new Date('2024-03-01').toISOString(),
    tags: ['ssh', 'security', 'keys', 'authentication'],
    functions: [
      {
        name: 'generate_keypair',
        description: 'Génère paire de clés SSH avec type et taille spécifiés',
        inputs: ['key_type', 'key_size', 'comment', 'output_path'],
        outputs: ['private_key_path', 'public_key_path', 'fingerprint']
      }
    ],
    dependencies: []
  },
  {
    id: 'ssh_002',
    name: 'add-ssh.key.authorized.sh',
    description: 'Ajoute une clé publique SSH au fichier authorized_keys d\'un utilisateur',
    category: 'network',
    level: 0,
    status: 'stable',
    complexity: 'low',
    path: '/root/atomics/network/add-ssh.key.authorized.sh',
    lastModified: new Date('2024-03-01').toISOString(),
    tags: ['ssh', 'authorization', 'keys', 'access'],
    functions: [
      {
        name: 'add_authorized_key',
        description: 'Ajoute une clé au fichier authorized_keys',
        inputs: ['public_key', 'target_user', 'host'],
        outputs: ['key_added', 'authorized_keys_path']
      }
    ],
    dependencies: []
  },
  {
    id: 'ssh_003',
    name: 'remove-ssh.key.authorized.sh',
    description: 'Supprime une clé publique SSH du fichier authorized_keys',
    category: 'network',
    level: 0,
    status: 'stable',
    complexity: 'low',
    path: '/root/atomics/network/remove-ssh.key.authorized.sh',
    lastModified: new Date('2024-03-01').toISOString(),
    tags: ['ssh', 'revocation', 'keys', 'security'],
    functions: [
      {
        name: 'remove_authorized_key',
        description: 'Supprime une clé du fichier authorized_keys',
        inputs: ['key_fingerprint', 'target_user', 'host'],
        outputs: ['key_removed', 'backup_created']
      }
    ],
    dependencies: []
  },
  {
    id: 'ssh_004',
    name: 'list-ssh.keys.sh',
    description: 'Liste toutes les clés SSH d\'un utilisateur avec métadonnées',
    category: 'network',
    level: 0,
    status: 'stable',
    complexity: 'low',
    path: '/root/atomics/network/list-ssh.keys.sh',
    lastModified: new Date('2024-03-01').toISOString(),
    tags: ['ssh', 'inventory', 'keys', 'audit'],
    functions: [
      {
        name: 'list_user_keys',
        description: 'Liste les clés SSH avec empreintes et métadonnées',
        inputs: ['target_user', 'host', 'key_type_filter'],
        outputs: ['keys_list', 'total_count', 'key_metadata']
      }
    ],
    dependencies: []
  },
  {
    id: 'ssh_005',
    name: 'check-ssh.connection.sh',
    description: 'Teste la connectivité SSH vers un hôte avec validation d\'authentification',
    category: 'network',
    level: 0,
    status: 'stable',
    complexity: 'medium',
    path: '/root/atomics/network/check-ssh.connection.sh',
    lastModified: new Date('2024-03-01').toISOString(),
    tags: ['ssh', 'connectivity', 'testing', 'validation'],
    functions: [
      {
        name: 'test_ssh_connection',
        description: 'Teste la connexion SSH avec différentes méthodes d\'auth',
        inputs: ['host', 'user', 'port', 'identity_file', 'timeout'],
        outputs: ['connection_status', 'auth_method', 'response_time']
      }
    ],
    dependencies: []
  },

  // === ORCHESTRATEURS SSH (NIVEAU 1) ===
  {
    id: 'ssh_orch_001',
    name: 'setup-ssh.access.sh',
    description: 'Configuration complète d\'accès SSH pour un utilisateur (génération + déploiement + test)',
    category: 'network',
    level: 1,
    status: 'stable',
    complexity: 'medium',
    path: '/root/orchestrators/level-1/setup-ssh.access.sh',
    lastModified: new Date('2024-10-05').toISOString(),
    tags: ['ssh', 'orchestrator', 'setup', 'automation'],
    functions: [
      {
        name: 'setup_complete_access',
        description: 'Orchestration complète setup SSH avec validation',
        inputs: ['target_user', 'target_host', 'key_type', 'test_connection'],
        outputs: ['access_configured', 'key_deployed', 'connection_validated']
      }
    ],
    dependencies: ['ssh_001', 'ssh_002', 'ssh_005']
  },
  {
    id: 'ssh_orch_002',
    name: 'revoke-ssh.access.sh',
    description: 'Révocation sécurisée d\'accès SSH avec sauvegarde et vérification',
    category: 'network',
    level: 1,
    status: 'stable',
    complexity: 'medium',
    path: '/root/orchestrators/level-1/revoke-ssh.access.sh',
    lastModified: new Date('2024-10-05').toISOString(),
    tags: ['ssh', 'orchestrator', 'revocation', 'security'],
    functions: [
      {
        name: 'revoke_user_access',
        description: 'Révocation complète avec backup et vérification',
        inputs: ['target_user', 'target_host', 'backup_keys', 'verify_revocation'],
        outputs: ['access_revoked', 'backup_created', 'revocation_verified']
      }
    ],
    dependencies: ['ssh_003', 'ssh_004', 'ssh_005']
  },
  {
    id: 'ssh_orch_003',
    name: 'audit-ssh.keys.sh',
    description: 'Audit complet des clés SSH système avec analyse sécuritaire et rapport',
    category: 'network',
    level: 1,
    status: 'stable',
    complexity: 'high',
    path: '/root/orchestrators/level-1/audit-ssh.keys.sh',
    lastModified: new Date('2024-10-05').toISOString(),
    tags: ['ssh', 'orchestrator', 'audit', 'security', 'compliance'],
    functions: [
      {
        name: 'perform_ssh_audit',
        description: 'Audit système complet avec analyse et recommandations',
        inputs: ['scan_all_users', 'test_connectivity', 'generate_report'],
        outputs: ['audit_report', 'security_analysis', 'recommendations']
      }
    ],
    dependencies: ['ssh_004', 'ssh_005']
  },
  {
    id: 'ssh_orch_004',
    name: 'migrate-ssh.user.sh',
    description: 'Migration des clés SSH d\'un utilisateur entre serveurs avec validation',
    category: 'network',
    level: 1,
    status: 'stable',
    complexity: 'high',
    path: '/root/orchestrators/level-1/migrate-ssh.user.sh',
    lastModified: new Date('2024-10-05').toISOString(),
    tags: ['ssh', 'orchestrator', 'migration', 'infrastructure'],
    functions: [
      {
        name: 'migrate_user_keys',
        description: 'Migration complète avec backup et validation',
        inputs: ['source_host', 'dest_host', 'migrate_user', 'migration_mode'],
        outputs: ['migration_completed', 'keys_migrated', 'validation_passed']
      }
    ],
    dependencies: ['ssh_004', 'ssh_002', 'ssh_005']
  },
  {
    id: 'ssh_orch_005',
    name: 'rotate-ssh.keys.sh',
    description: 'Rotation complète des clés SSH avec stratégies multiples (sequential/parallel/canary)',
    category: 'network',
    level: 1,
    status: 'stable',
    complexity: 'high',
    path: '/root/orchestrators/level-1/rotate-ssh.keys.sh',
    lastModified: new Date('2024-10-05').toISOString(),
    tags: ['ssh', 'orchestrator', 'rotation', 'security', 'automation'],
    functions: [
      {
        name: 'rotate_ssh_keys',
        description: 'Rotation avec stratégies avancées et rollback automatique',
        inputs: ['target_servers', 'rotation_strategy', 'key_type', 'grace_period'],
        outputs: ['rotation_completed', 'servers_success', 'rollback_executed']
      }
    ],
    dependencies: ['ssh_001', 'ssh_002', 'ssh_003', 'ssh_005']
  },
  {
    id: 'ssh_orch_006',
    name: 'deploy-ssh.multiserver.sh',
    description: 'Déploiement massif de clés SSH sur infrastructure avec orchestration avancée',
    category: 'network',
    level: 1,
    status: 'stable',
    complexity: 'high',
    path: '/root/orchestrators/level-1/deploy-ssh.multiserver.sh',
    lastModified: new Date('2024-10-05').toISOString(),
    tags: ['ssh', 'orchestrator', 'deployment', 'infrastructure', 'automation'],
    functions: [
      {
        name: 'deploy_multiserver',
        description: 'Déploiement avec stratégies (rolling/canary/parallel) et retry intelligent',
        inputs: ['target_servers', 'ssh_key_file', 'deployment_strategy', 'max_parallel'],
        outputs: ['deployment_completed', 'servers_success', 'deployment_report']
      }
    ],
    dependencies: ['ssh_002', 'ssh_005']
  }
];

// Fusion des scripts existants avec les nouveaux
export const allMockScripts = [...mockScripts, ...atomicScripts, ...performanceScripts, ...sshScripts];

// Fonction pour générer des statistiques à partir des données de test
export const generateMockStats = () => {
  const totalScripts = allMockScripts;
  const stats = {
    total: totalScripts.length,
    byCategory: {} as Record<string, number>,
    byLevel: {} as Record<string, number>,
    byComplexity: {} as Record<string, number>,
    byStatus: {} as Record<string, number>,
    totalDependencies: 0,
    avgDependenciesPerScript: 0,
    totalFunctions: 0,
    avgFunctionsPerScript: 0,
    recentlyModified: 0
  };

  totalScripts.forEach(script => {
    // Par catégorie
    stats.byCategory[script.category] = (stats.byCategory[script.category] || 0) + 1;
    
    // Par niveau
    const levelKey = script.level.toString();
    stats.byLevel[levelKey] = (stats.byLevel[levelKey] || 0) + 1;
    
    // Par complexité
    stats.byComplexity[script.complexity] = (stats.byComplexity[script.complexity] || 0) + 1;
    
    // Par statut
    stats.byStatus[script.status] = (stats.byStatus[script.status] || 0) + 1;
    
    // Dépendances
    stats.totalDependencies += script.dependencies?.length || 0;
    
    // Fonctions
    stats.totalFunctions += script.functions?.length || 0;
    
    // Récemment modifiés (derniers 30 jours)
    const scriptDate = new Date(script.lastModified);
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    if (scriptDate > thirtyDaysAgo) {
      stats.recentlyModified++;
    }
  });

  stats.avgDependenciesPerScript = stats.totalDependencies / stats.total;
  stats.avgFunctionsPerScript = stats.totalFunctions / stats.total;

  return stats;
};

// Fonction pour générer un graphe de dépendances
export const generateMockDependencyGraph = () => {
  const nodes = allMockScripts.map(script => ({
    id: script.id,
    name: script.name,
    level: script.level,
    category: script.category,
    group: script.category
  }));

  const links: Array<{ source: string; target: string; type: string }> = [];

  allMockScripts.forEach(script => {
    script.dependencies?.forEach(depId => {
      links.push({
        source: depId,
        target: script.id,
        type: 'dependency'
      });
    });
  });

  return { nodes, links };
};

// Fonction pour générer une hiérarchie
export const generateMockHierarchy = () => {
  const hierarchy: any = {
    name: 'Proxmox CT Management',
    level: -1,
    category: 'root',
    children: []
  };

  // Grouper par catégorie
  const categories: Record<string, any> = {};
  
  allMockScripts.forEach(script => {
    if (!categories[script.category]) {
      categories[script.category] = {
        name: script.category,
        level: 0,
        category: script.category,
        children: []
      };
    }
    
    categories[script.category].children.push({
      id: script.id,
      name: script.name,
      level: script.level,
      category: script.category,
      functions: script.functions,
      children: []
    });
  });

  // Ajouter les catégories à la hiérarchie
  Object.values(categories).forEach(category => {
    hierarchy.children.push(category);
  });

  return hierarchy;
};