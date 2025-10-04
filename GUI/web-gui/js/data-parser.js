/**
 * AtomicOps-Suite - Parseur de données des scripts atomiques
 * Extrait les métadonnées, paramètres et dépendances des scripts
 */

class DataParser {
    constructor() {
        this.scriptsData = new Map();
        this.categoriesData = new Map();
        this.dependencyGraph = new Map();
        this.init();
    }

    /**
     * Initialise le parseur avec les données des scripts atomiques
     */
    async init() {
        try {
            // Chargement des données depuis le catalogue
            await this.loadScriptsFromCatalog();
            await this.parseScriptFiles();
            this.buildDependencyGraph();
            this.categorizeScripts();
        } catch (error) {
            console.error('Erreur lors de l\'initialisation du parseur:', error);
        }
    }

    /**
     * Charge la liste des scripts depuis le catalogue
     */
    async loadScriptsFromCatalog() {
        // Données des 22 scripts atomiques créés
        const atomicScripts = [
            {
                name: 'restore-directory.sh',
                category: 'restore',
                phase: '8A',
                description: 'Restauration complète de répertoires depuis archives',
                complexity: 7,
                dependencies: ['tar', 'gzip', 'bzip2', 'xz'],
                parameters: {
                    required: ['--source', '--target'],
                    optional: ['--format', '--preserve-permissions', '--verify']
                },
                outputs: ['success', 'restored_files', 'verification_status'],
                useCases: ['backup_recovery', 'system_restore', 'data_migration']
            },
            {
                name: 'restore-file.sh',
                category: 'restore',
                phase: '8A',
                description: 'Restauration de fichiers individuels avec vérification',
                complexity: 5,
                dependencies: ['cp', 'sha256sum', 'file'],
                parameters: {
                    required: ['--file', '--backup'],
                    optional: ['--verify-checksum', '--preserve-attributes']
                },
                outputs: ['success', 'restored_file', 'checksum_match'],
                useCases: ['config_restore', 'file_recovery', 'rollback']
            },
            {
                name: 'revoke-user.sudo.sh',
                category: 'security',
                phase: '8A',
                description: 'Révocation des privilèges sudo utilisateur',
                complexity: 6,
                dependencies: ['sudo', 'visudo', 'groups'],
                parameters: {
                    required: ['--user'],
                    optional: ['--backup-config', '--force', '--log-action']
                },
                outputs: ['success', 'revoked_privileges', 'backup_location'],
                useCases: ['security_audit', 'user_offboarding', 'privilege_cleanup']
            },
            {
                name: 'rotate-log.sh',
                category: 'maintenance',
                phase: '8A',
                description: 'Rotation automatique des fichiers de logs',
                complexity: 6,
                dependencies: ['logrotate', 'gzip', 'find'],
                parameters: {
                    required: ['--log-file'],
                    optional: ['--max-size', '--keep-days', '--compress']
                },
                outputs: ['success', 'rotated_files', 'space_freed'],
                useCases: ['log_management', 'disk_space', 'maintenance']
            },
            {
                name: 'run-smart.test.sh',
                category: 'testing',
                phase: '8B',
                description: 'Tests SMART des disques avec rapports détaillés',
                complexity: 8,
                dependencies: ['smartctl', 'smartmontools', 'hdparm'],
                parameters: {
                    required: ['--device'],
                    optional: ['--test-type', '--save-report', '--email-report']
                },
                outputs: ['success', 'smart_status', 'test_results', 'health_score'],
                useCases: ['disk_health', 'preventive_maintenance', 'hardware_monitoring']
            },
            {
                name: 'schedule-task.at.sh',
                category: 'scheduling',
                phase: '8B',
                description: 'Planification de tâches avec at/cron',
                complexity: 6,
                dependencies: ['at', 'atd', 'crontab'],
                parameters: {
                    required: ['--command', '--time'],
                    optional: ['--user', '--recurring', '--notification']
                },
                outputs: ['success', 'job_id', 'scheduled_time'],
                useCases: ['task_automation', 'delayed_execution', 'maintenance_windows']
            },
            {
                name: 'search-log.pattern.sh',
                category: 'search',
                phase: '8B',
                description: 'Recherche avancée de motifs dans les logs',
                complexity: 7,
                dependencies: ['grep', 'awk', 'sed', 'tail'],
                parameters: {
                    required: ['--pattern'],
                    optional: ['--log-files', '--time-range', '--context-lines']
                },
                outputs: ['success', 'matches', 'match_count', 'context'],
                useCases: ['troubleshooting', 'security_analysis', 'monitoring']
            },
            {
                name: 'search-package.apt.sh',
                category: 'search',
                phase: '8B',
                description: 'Recherche de packages APT avec filtres avancés',
                complexity: 5,
                dependencies: ['apt', 'apt-cache', 'dpkg'],
                parameters: {
                    required: ['--query'],
                    optional: ['--installed-only', '--available-only', '--description']
                },
                outputs: ['success', 'packages', 'package_details'],
                useCases: ['package_management', 'system_audit', 'software_inventory']
            },
            {
                name: 'send-notification.email.sh',
                category: 'notification',
                phase: '8C',
                description: 'Envoi de notifications par email avec pièces jointes',
                complexity: 6,
                dependencies: ['sendmail', 'mail', 'mutt', 'curl'],
                parameters: {
                    required: ['--to', '--subject'],
                    optional: ['--body', '--attachment', '--smtp-server']
                },
                outputs: ['success', 'message_id', 'delivery_status'],
                useCases: ['alerting', 'reporting', 'automation_feedback']
            },
            {
                name: 'send-notification.slack.sh',
                category: 'notification',
                phase: '8C',
                description: 'Notifications Slack avec formatage riche',
                complexity: 5,
                dependencies: ['curl', 'jq'],
                parameters: {
                    required: ['--webhook-url', '--message'],
                    optional: ['--channel', '--username', '--emoji', '--attachments']
                },
                outputs: ['success', 'response', 'timestamp'],
                useCases: ['team_communication', 'alerting', 'ci_cd_notifications']
            },
            {
                name: 'send-notification.telegram.sh',
                category: 'notification',
                phase: '8C',
                description: 'Notifications Telegram avec support média',
                complexity: 5,
                dependencies: ['curl', 'jq'],
                parameters: {
                    required: ['--bot-token', '--chat-id', '--message'],
                    optional: ['--parse-mode', '--photo', '--document']
                },
                outputs: ['success', 'message_id', 'chat_response'],
                useCases: ['personal_alerts', 'mobile_notifications', 'monitoring']
            },
            {
                name: 'set-config.kernel.parameter.sh',
                category: 'configuration',
                phase: '8D',
                description: 'Configuration des paramètres kernel avec sécurité',
                complexity: 8,
                dependencies: ['sysctl', 'modprobe'],
                parameters: {
                    required: ['--parameter', '--value'],
                    optional: ['--persistent', '--validate', '--backup']
                },
                outputs: ['success', 'parameter_set', 'previous_value', 'validation'],
                useCases: ['performance_tuning', 'security_hardening', 'system_optimization']
            },
            {
                name: 'set-cpu.governor.sh',
                category: 'configuration',
                phase: '8D',
                description: 'Gestion des gouverneurs CPU par cœur',
                complexity: 7,
                dependencies: ['cpupower', 'cpufreq-utils'],
                parameters: {
                    required: ['--governor'],
                    optional: ['--cpu', '--persistent', '--frequency-range']
                },
                outputs: ['success', 'governor_set', 'frequency_info', 'power_consumption'],
                useCases: ['power_management', 'performance_optimization', 'energy_saving']
            },
            {
                name: 'set-dns.server.sh',
                category: 'network',
                phase: '8D',
                description: 'Configuration DNS avec détection de conflits',
                complexity: 7,
                dependencies: ['systemd-resolved', 'NetworkManager', 'dig'],
                parameters: {
                    required: ['--servers'],
                    optional: ['--interface', '--fallback', '--test-connectivity']
                },
                outputs: ['success', 'dns_configured', 'resolution_test', 'conflicts'],
                useCases: ['network_setup', 'dns_management', 'connectivity_optimization']
            },
            {
                name: 'set-env.variable.sh',
                category: 'configuration',
                phase: '8D',
                description: 'Gestion variables d\'environnement système/utilisateur',
                complexity: 6,
                dependencies: ['bash', 'systemd'],
                parameters: {
                    required: ['--name', '--value'],
                    optional: ['--scope', '--persistent', '--export']
                },
                outputs: ['success', 'variable_set', 'scope_applied', 'persistence'],
                useCases: ['application_config', 'environment_setup', 'deployment']
            },
            {
                name: 'set-file.acl.sh',
                category: 'security',
                phase: '8E',
                description: 'Gestion ACL POSIX étendues avec validation',
                complexity: 8,
                dependencies: ['getfacl', 'setfacl', 'acl'],
                parameters: {
                    required: ['--target'],
                    optional: ['--user', '--group', '--mask', '--recursive', '--default']
                },
                outputs: ['success', 'acl_applied', 'before_after', 'validation'],
                useCases: ['fine_grained_permissions', 'multi_user_access', 'security_compliance']
            },
            {
                name: 'set-file.owner.sh',
                category: 'security',
                phase: '8E',
                description: 'Gestion propriété fichiers avec validation sécurité',
                complexity: 6,
                dependencies: ['chown', 'stat', 'id'],
                parameters: {
                    required: ['--target'],
                    optional: ['--owner', '--group', '--recursive', '--backup']
                },
                outputs: ['success', 'ownership_changed', 'files_affected', 'permissions_check'],
                useCases: ['file_management', 'security_setup', 'ownership_correction']
            },
            {
                name: 'set-file.permissions.sh',
                category: 'security',
                phase: '8E',
                description: 'Gestion permissions avec templates sécurisés',
                complexity: 7,
                dependencies: ['chmod', 'stat', 'find'],
                parameters: {
                    required: ['--target'],
                    optional: ['--permissions', '--mode', '--recursive', '--force']
                },
                outputs: ['success', 'permissions_set', 'security_validation', 'items_affected'],
                useCases: ['security_hardening', 'permission_management', 'compliance']
            },
            {
                name: 'set-network.interface.ip.sh',
                category: 'network',
                phase: '8E',
                description: 'Configuration IP avancée IPv4/IPv6 avec persistance',
                complexity: 9,
                dependencies: ['ip', 'netplan', 'systemd-networkd', 'NetworkManager'],
                parameters: {
                    required: ['--interface'],
                    optional: ['--address', '--gateway', '--dns', '--method', '--persistent']
                },
                outputs: ['success', 'ip_configured', 'connectivity_tests', 'persistence_status'],
                useCases: ['network_setup', 'ip_management', 'connectivity_configuration']
            },
            {
                name: 'set-password.expiry.sh',
                category: 'security',
                phase: '8E',
                description: 'Politiques expiration mots de passe avec audit',
                complexity: 7,
                dependencies: ['chage', 'passwd', 'id'],
                parameters: {
                    required: ['--user'],
                    optional: ['--days', '--warn-days', '--inactive', '--force-change']
                },
                outputs: ['success', 'policy_applied', 'expiration_info', 'security_status'],
                useCases: ['security_compliance', 'password_policy', 'user_management']
            },
            {
                name: 'set-system.hostname.sh',
                category: 'configuration',
                phase: '8E',
                description: 'Configuration hostname système avec validation DNS',
                complexity: 7,
                dependencies: ['hostnamectl', 'systemctl', 'dig'],
                parameters: {
                    required: ['--hostname'],
                    optional: ['--domain', '--persistent', '--update-hosts']
                },
                outputs: ['success', 'hostname_set', 'dns_resolution', 'services_restarted'],
                useCases: ['system_setup', 'hostname_management', 'dns_configuration']
            },
            {
                name: 'set-system.timezone.sh',
                category: 'configuration',
                phase: '8E',
                description: 'Configuration timezone avec synchronisation NTP',
                complexity: 8,
                dependencies: ['timedatectl', 'chrony', 'systemd-timesyncd'],
                parameters: {
                    required: ['--timezone'],
                    optional: ['--ntp-enable', '--ntp-servers', '--sync-now']
                },
                outputs: ['success', 'timezone_set', 'ntp_status', 'time_sync'],
                useCases: ['system_setup', 'time_management', 'ntp_configuration']
            }
        ];

        // Stockage des données dans la Map
        atomicScripts.forEach(script => {
            this.scriptsData.set(script.name, script);
        });
    }

    /**
     * Parse les fichiers de scripts pour extraire des métadonnées supplémentaires
     */
    async parseScriptFiles() {
        // Simulation du parsing des fichiers - en production, ceci lirait les vrais fichiers
        for (const [name, script] of this.scriptsData) {
            // Analyse statique simulée
            script.linesOfCode = this.estimateLinesOfCode(script.complexity);
            script.estimatedRuntime = this.estimateRuntime(script.complexity);
            script.riskLevel = this.calculateRiskLevel(script);
            script.lastModified = new Date().toISOString();
            script.version = '1.0.0';
        }
    }

    /**
     * Construit le graphe de dépendances entre scripts
     */
    buildDependencyGraph() {
        this.scriptsData.forEach((script, name) => {
            const dependencies = [];
            
            // Analyse des dépendances logiques entre scripts
            if (script.category === 'restore') {
                dependencies.push('search-log.pattern.sh'); // Pour logs de restauration
            }
            
            if (script.name.startsWith('set-')) {
                dependencies.push('restore-file.sh'); // Backup avant modification
            }
            
            if (script.category === 'notification') {
                // Peut être utilisé par d'autres scripts pour les alertes
                this.scriptsData.forEach((otherScript, otherName) => {
                    if (otherName !== name && otherScript.complexity > 7) {
                        if (!this.dependencyGraph.has(otherName)) {
                            this.dependencyGraph.set(otherName, []);
                        }
                        this.dependencyGraph.get(otherName).push(name);
                    }
                });
            }
            
            if (dependencies.length > 0) {
                this.dependencyGraph.set(name, dependencies);
            }
        });
    }

    /**
     * Catégorise les scripts selon différents critères
     */
    categorizeScripts() {
        const categories = {
            'restore': { scripts: [], color: '#3b82f6', description: 'Scripts de restauration et récupération' },
            'security': { scripts: [], color: '#ef4444', description: 'Scripts de sécurité et permissions' },
            'configuration': { scripts: [], color: '#10b981', description: 'Scripts de configuration système' },
            'network': { scripts: [], color: '#8b5cf6', description: 'Scripts de gestion réseau' },
            'notification': { scripts: [], color: '#f59e0b', description: 'Scripts de notification' },
            'maintenance': { scripts: [], color: '#06b6d4', description: 'Scripts de maintenance' },
            'testing': { scripts: [], color: '#84cc16', description: 'Scripts de test et validation' },
            'scheduling': { scripts: [], color: '#f97316', description: 'Scripts de planification' },
            'search': { scripts: [], color: '#6366f1', description: 'Scripts de recherche et analyse' }
        };

        this.scriptsData.forEach((script, name) => {
            if (categories[script.category]) {
                categories[script.category].scripts.push(name);
            }
        });

        this.categoriesData = new Map(Object.entries(categories));
    }

    /**
     * Estime le nombre de lignes de code basé sur la complexité
     */
    estimateLinesOfCode(complexity) {
        return complexity * 25 + Math.floor(Math.random() * 50);
    }

    /**
     * Estime le temps d'exécution basé sur la complexité
     */
    estimateRuntime(complexity) {
        const baseTime = complexity * 0.5;
        return `${baseTime}-${baseTime * 2}s`;
    }

    /**
     * Calcule le niveau de risque d'un script
     */
    calculateRiskLevel(script) {
        let risk = 0;
        
        // Complexité
        risk += script.complexity;
        
        // Dépendances système critiques
        const criticalDeps = ['sudo', 'rm', 'dd', 'fdisk', 'mkfs'];
        risk += script.dependencies.filter(dep => criticalDeps.includes(dep)).length * 2;
        
        // Catégories à risque
        if (['security', 'configuration'].includes(script.category)) {
            risk += 3;
        }
        
        if (risk <= 5) return 'low';
        if (risk <= 10) return 'medium';
        return 'high';
    }

    /**
     * Retourne toutes les données des scripts
     */
    getAllScripts() {
        return Array.from(this.scriptsData.entries()).map(([name, data]) => ({
            name,
            ...data
        }));
    }

    /**
     * Retourne les données d'un script spécifique
     */
    getScript(name) {
        return this.scriptsData.get(name);
    }

    /**
     * Retourne les catégories avec leurs scripts
     */
    getCategories() {
        return Array.from(this.categoriesData.entries()).map(([category, data]) => ({
            name: category,
            ...data
        }));
    }

    /**
     * Retourne le graphe de dépendances
     */
    getDependencyGraph() {
        return this.dependencyGraph;
    }

    /**
     * Recherche de scripts selon des critères
     */
    searchScripts(query, filters = {}) {
        let results = this.getAllScripts();

        // Filtrage par texte
        if (query) {
            const searchTerms = query.toLowerCase().split(' ');
            results = results.filter(script => {
                const searchText = `${script.name} ${script.description} ${script.category}`.toLowerCase();
                return searchTerms.every(term => searchText.includes(term));
            });
        }

        // Filtrage par catégorie
        if (filters.categories && filters.categories.length > 0) {
            results = results.filter(script => filters.categories.includes(script.category));
        }

        // Filtrage par complexité
        if (filters.complexityRange) {
            const [min, max] = filters.complexityRange;
            results = results.filter(script => script.complexity >= min && script.complexity <= max);
        }

        // Filtrage par niveau de risque
        if (filters.riskLevel) {
            results = results.filter(script => script.riskLevel === filters.riskLevel);
        }

        return results;
    }

    /**
     * Génère des statistiques sur les scripts
     */
    getStatistics() {
        const scripts = this.getAllScripts();
        const categories = this.getCategories();
        
        return {
            totalScripts: scripts.length,
            totalCategories: categories.length,
            averageComplexity: scripts.reduce((sum, s) => sum + s.complexity, 0) / scripts.length,
            totalDependencies: [...new Set(scripts.flatMap(s => s.dependencies))].length,
            distributionByCategory: categories.map(cat => ({
                name: cat.name,
                count: cat.scripts.length,
                percentage: (cat.scripts.length / scripts.length * 100).toFixed(1)
            })),
            complexityDistribution: {
                low: scripts.filter(s => s.complexity <= 5).length,
                medium: scripts.filter(s => s.complexity > 5 && s.complexity <= 7).length,
                high: scripts.filter(s => s.complexity > 7).length
            },
            riskDistribution: {
                low: scripts.filter(s => s.riskLevel === 'low').length,
                medium: scripts.filter(s => s.riskLevel === 'medium').length,
                high: scripts.filter(s => s.riskLevel === 'high').length
            }
        };
    }
}

// Export pour utilisation dans d'autres modules
window.DataParser = DataParser;