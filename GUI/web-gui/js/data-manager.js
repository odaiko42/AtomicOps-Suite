/**
 * ===========================
 * Gestionnaire de Données - AtomicOps Suite
 * ===========================
 * 
 * Ce module gère le chargement, le traitement et la mise à disposition
 * des données des scripts atomiques pour l'interface GUI.
 */

class DataManager {
    constructor() {
        this.scripts = new Map();
        this.categories = new Map();
        this.dependencies = new Map();
        this.loaded = false;
        this.eventListeners = new Map();
        
        // Configuration de cache
        this.cachePrefix = 'atomicops_';
        this.cacheExpiry = 24 * 60 * 60 * 1000; // 24 heures
    }

    /**
     * ===========================
     * Événements et Callbacks
     * ===========================
     */
    
    /**
     * Ajoute un écouteur d'événement pour les changements de données
     * @param {string} event - Type d'événement ('loaded', 'updated', 'error')
     * @param {function} callback - Fonction à appeler
     */
    on(event, callback) {
        if (!this.eventListeners.has(event)) {
            this.eventListeners.set(event, []);
        }
        this.eventListeners.get(event).push(callback);
    }

    /**
     * Déclenche un événement
     * @param {string} event - Type d'événement
     * @param {*} data - Données à passer au callback
     */
    emit(event, data = null) {
        const listeners = this.eventListeners.get(event);
        if (listeners) {
            listeners.forEach(callback => {
                try {
                    callback(data);
                } catch (error) {
                    console.error(`Erreur dans l'écouteur ${event}:`, error);
                }
            });
        }
    }

    /**
     * ===========================
     * Chargement des Données
     * ===========================
     */

    /**
     * Charge toutes les données depuis le fichier JSON ou le cache
     * @returns {Promise<boolean>} - True si le chargement est réussi
     */
    async loadData() {
        try {
            // Vérifier d'abord le cache
            const cachedData = this.getCachedData();
            if (cachedData) {
                console.log('Données chargées depuis le cache');
                this.processLoadedData(cachedData);
                return true;
            }

            // Charger depuis le fichier JSON
            console.log('Chargement des données depuis le fichier...');
            const response = await fetch('./data/atomic-scripts.json');
            
            if (!response.ok) {
                throw new Error(`Erreur HTTP: ${response.status}`);
            }

            const data = await response.json();
            
            // Sauvegarder en cache
            this.setCachedData(data);
            
            // Traiter les données
            this.processLoadedData(data);
            
            return true;

        } catch (error) {
            console.error('Erreur lors du chargement des données:', error);
            this.emit('error', error);
            
            // Essayer de charger les données d'exemple en cas d'échec
            this.loadSampleData();
            return false;
        }
    }

    /**
     * Traite les données chargées et les organise en structures utilisables
     * @param {Object} data - Données brutes du JSON
     */
    processLoadedData(data) {
        this.scripts.clear();
        this.categories.clear();
        this.dependencies.clear();

        // Traiter les scripts
        if (data.scripts && Array.isArray(data.scripts)) {
            data.scripts.forEach(script => {
                this.scripts.set(script.id, this.normalizeScript(script));
                
                // Organiser par catégories
                const category = script.category || 'other';
                if (!this.categories.has(category)) {
                    this.categories.set(category, []);
                }
                this.categories.get(category).push(script.id);
                
                // Traiter les dépendances
                if (script.dependencies && Array.isArray(script.dependencies)) {
                    script.dependencies.forEach(dep => {
                        if (!this.dependencies.has(script.id)) {
                            this.dependencies.set(script.id, []);
                        }
                        this.dependencies.get(script.id).push(dep);
                    });
                }
            });
        }

        this.loaded = true;
        console.log(`Chargé ${this.scripts.size} scripts dans ${this.categories.size} catégories`);
        this.emit('loaded', {
            scriptsCount: this.scripts.size,
            categoriesCount: this.categories.size
        });
    }

    /**
     * Normalise et valide un script
     * @param {Object} script - Script brut
     * @returns {Object} - Script normalisé
     */
    normalizeScript(script) {
        return {
            id: script.id || '',
            name: script.name || script.id || 'Script sans nom',
            description: script.description || '',
            category: script.category || 'other',
            level: script.level || 'atomic',
            path: script.path || '',
            inputs: Array.isArray(script.inputs) ? script.inputs : [],
            outputs: Array.isArray(script.outputs) ? script.outputs : [],
            conditions: Array.isArray(script.conditions) ? script.conditions : [],
            dependencies: Array.isArray(script.dependencies) ? script.dependencies : [],
            tags: Array.isArray(script.tags) ? script.tags : [],
            complexity: script.complexity || 'low',
            status: script.status || 'stable',
            lastModified: script.lastModified || new Date().toISOString(),
            author: script.author || 'Unknown',
            version: script.version || '1.0.0'
        };
    }

    /**
     * Charge des données d'exemple en cas d'échec du chargement
     */
    loadSampleData() {
        const sampleData = {
            scripts: [
                {
                    id: 'select-disk',
                    name: 'Sélecteur de Disque',
                    description: 'Permet à l\'utilisateur de sélectionner un disque USB',
                    category: 'usb',
                    level: 'atomic',
                    path: 'scripts/atomic/select-disk.sh',
                    inputs: ['liste_disques'],
                    outputs: ['disque_selectionne'],
                    conditions: ['disques_disponibles'],
                    dependencies: [],
                    tags: ['usb', 'selection', 'interactive'],
                    complexity: 'low',
                    status: 'stable'
                },
                {
                    id: 'format-disk',
                    name: 'Formatage de Disque',
                    description: 'Formate un disque USB avec le système de fichiers spécifié',
                    category: 'usb',
                    level: 'atomic',
                    path: 'scripts/atomic/format-disk.sh',
                    inputs: ['disque', 'format'],
                    outputs: ['disque_formate'],
                    conditions: ['disque_non_monte', 'permissions_admin'],
                    dependencies: [],
                    tags: ['usb', 'format', 'destructive'],
                    complexity: 'medium',
                    status: 'stable'
                },
                {
                    id: 'setup-usb-storage',
                    name: 'Configuration Stockage USB',
                    description: 'Orchestre la configuration complète d\'un stockage USB',
                    category: 'usb',
                    level: 'orchestrator',
                    path: 'scripts/orchestrators/setup-usb-storage.sh',
                    inputs: ['preferences_utilisateur'],
                    outputs: ['stockage_configure'],
                    conditions: ['disque_disponible'],
                    dependencies: ['select-disk', 'format-disk'],
                    tags: ['usb', 'workflow', 'setup'],
                    complexity: 'high',
                    status: 'stable'
                }
            ]
        };

        console.log('Chargement des données d\'exemple');
        this.processLoadedData(sampleData);
    }

    /**
     * ===========================
     * Cache Management
     * ===========================
     */

    /**
     * Récupère les données depuis le cache local
     * @returns {Object|null} - Données mises en cache ou null
     */
    getCachedData() {
        try {
            const cached = localStorage.getItem(this.cachePrefix + 'data');
            if (!cached) return null;

            const data = JSON.parse(cached);
            const timestamp = localStorage.getItem(this.cachePrefix + 'timestamp');
            
            if (!timestamp || Date.now() - parseInt(timestamp) > this.cacheExpiry) {
                this.clearCache();
                return null;
            }

            return data;
        } catch (error) {
            console.warn('Erreur lors de la lecture du cache:', error);
            this.clearCache();
            return null;
        }
    }

    /**
     * Sauvegarde les données en cache
     * @param {Object} data - Données à sauvegarder
     */
    setCachedData(data) {
        try {
            localStorage.setItem(this.cachePrefix + 'data', JSON.stringify(data));
            localStorage.setItem(this.cachePrefix + 'timestamp', Date.now().toString());
        } catch (error) {
            console.warn('Impossible de sauvegarder en cache:', error);
        }
    }

    /**
     * Vide le cache
     */
    clearCache() {
        try {
            localStorage.removeItem(this.cachePrefix + 'data');
            localStorage.removeItem(this.cachePrefix + 'timestamp');
        } catch (error) {
            console.warn('Erreur lors du vidage du cache:', error);
        }
    }

    /**
     * ===========================
     * Accès aux Données
     * ===========================
     */

    /**
     * Retourne tous les scripts
     * @returns {Array} - Tableau des scripts
     */
    getAllScripts() {
        return Array.from(this.scripts.values());
    }

    /**
     * Retourne un script par son ID
     * @param {string} id - ID du script
     * @returns {Object|null} - Script ou null si non trouvé
     */
    getScript(id) {
        return this.scripts.get(id) || null;
    }

    /**
     * Retourne les scripts d'une catégorie
     * @param {string} category - Nom de la catégorie
     * @returns {Array} - Scripts de la catégorie
     */
    getScriptsByCategory(category) {
        const scriptIds = this.categories.get(category) || [];
        return scriptIds.map(id => this.scripts.get(id)).filter(Boolean);
    }

    /**
     * Retourne toutes les catégories
     * @returns {Array} - Tableau des noms de catégories
     */
    getCategories() {
        return Array.from(this.categories.keys());
    }

    /**
     * Retourne les dépendances d'un script
     * @param {string} scriptId - ID du script
     * @returns {Array} - Tableau des IDs de dépendances
     */
    getDependencies(scriptId) {
        return this.dependencies.get(scriptId) || [];
    }

    /**
     * Retourne les scripts qui dépendent du script donné
     * @param {string} scriptId - ID du script
     * @returns {Array} - Scripts dépendants
     */
    getDependents(scriptId) {
        const dependents = [];
        this.dependencies.forEach((deps, id) => {
            if (deps.includes(scriptId)) {
                const script = this.scripts.get(id);
                if (script) dependents.push(script);
            }
        });
        return dependents;
    }

    /**
     * ===========================
     * Recherche et Filtrage
     * ===========================
     */

    /**
     * Recherche des scripts par terme
     * @param {string} term - Terme de recherche
     * @returns {Array} - Scripts correspondants
     */
    searchScripts(term) {
        if (!term || typeof term !== 'string') {
            return this.getAllScripts();
        }

        const searchTerm = term.toLowerCase();
        return this.getAllScripts().filter(script => {
            return script.name.toLowerCase().includes(searchTerm) ||
                   script.description.toLowerCase().includes(searchTerm) ||
                   script.tags.some(tag => tag.toLowerCase().includes(searchTerm)) ||
                   script.id.toLowerCase().includes(searchTerm);
        });
    }

    /**
     * Filtre les scripts par critères multiples
     * @param {Object} filters - Critères de filtrage
     * @returns {Array} - Scripts filtrés
     */
    filterScripts(filters = {}) {
        let results = this.getAllScripts();

        if (filters.category) {
            results = results.filter(script => script.category === filters.category);
        }

        if (filters.level) {
            results = results.filter(script => script.level === filters.level);
        }

        if (filters.status) {
            results = results.filter(script => script.status === filters.status);
        }

        if (filters.complexity) {
            results = results.filter(script => script.complexity === filters.complexity);
        }

        if (filters.tags && Array.isArray(filters.tags)) {
            results = results.filter(script => 
                filters.tags.some(tag => script.tags.includes(tag))
            );
        }

        if (filters.search) {
            results = results.filter(script => {
                const searchTerm = filters.search.toLowerCase();
                return script.name.toLowerCase().includes(searchTerm) ||
                       script.description.toLowerCase().includes(searchTerm);
            });
        }

        return results;
    }

    /**
     * ===========================
     * Statistiques
     * ===========================
     */

    /**
     * Retourne des statistiques sur les scripts
     * @returns {Object} - Objet contenant les statistiques
     */
    getStatistics() {
        const scripts = this.getAllScripts();
        
        const stats = {
            total: scripts.length,
            byLevel: {},
            byCategory: {},
            byStatus: {},
            byComplexity: {},
            totalDependencies: 0,
            avgDependenciesPerScript: 0,
            mostUsedTags: {},
            recentlyModified: 0
        };

        // Compter par niveau, catégorie, statut, complexité
        scripts.forEach(script => {
            // Par niveau
            stats.byLevel[script.level] = (stats.byLevel[script.level] || 0) + 1;
            
            // Par catégorie
            stats.byCategory[script.category] = (stats.byCategory[script.category] || 0) + 1;
            
            // Par statut
            stats.byStatus[script.status] = (stats.byStatus[script.status] || 0) + 1;
            
            // Par complexité
            stats.byComplexity[script.complexity] = (stats.byComplexity[script.complexity] || 0) + 1;
            
            // Dépendances
            stats.totalDependencies += script.dependencies.length;
            
            // Tags
            script.tags.forEach(tag => {
                stats.mostUsedTags[tag] = (stats.mostUsedTags[tag] || 0) + 1;
            });
            
            // Récemment modifiés (dernières 30 jours)
            const thirtyDaysAgo = new Date();
            thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
            if (new Date(script.lastModified) > thirtyDaysAgo) {
                stats.recentlyModified++;
            }
        });

        // Moyenne des dépendances
        stats.avgDependenciesPerScript = scripts.length > 0 
            ? (stats.totalDependencies / scripts.length).toFixed(1) 
            : 0;

        return stats;
    }

    /**
     * ===========================
     * Hiérarchie et Graphe
     * ===========================
     */

    /**
     * Génère la structure hiérarchique des scripts
     * @returns {Object} - Structure hiérarchique
     */
    getHierarchy() {
        const hierarchy = {
            name: 'AtomicOps Suite',
            children: []
        };

        // Organiser par catégories
        this.getCategories().forEach(category => {
            const categoryNode = {
                name: this.formatCategoryName(category),
                category: category,
                children: [],
                type: 'category'
            };

            const scripts = this.getScriptsByCategory(category);
            
            // Grouper par niveau dans chaque catégorie
            const levels = ['atomic', 'orchestrator', 'main'];
            levels.forEach(level => {
                const levelScripts = scripts.filter(s => s.level === level);
                if (levelScripts.length > 0) {
                    const levelNode = {
                        name: this.formatLevelName(level),
                        level: level,
                        children: levelScripts.map(script => ({
                            ...script,
                            name: script.name,
                            type: 'script'
                        })),
                        type: 'level'
                    };
                    categoryNode.children.push(levelNode);
                }
            });

            if (categoryNode.children.length > 0) {
                hierarchy.children.push(categoryNode);
            }
        });

        return hierarchy;
    }

    /**
     * Génère le graphe de dépendances
     * @returns {Object} - Graphe avec nœuds et liens
     */
    getDependencyGraph() {
        const nodes = [];
        const links = [];
        const processedNodes = new Set();

        this.getAllScripts().forEach(script => {
            // Ajouter le nœud du script
            if (!processedNodes.has(script.id)) {
                nodes.push({
                    id: script.id,
                    name: script.name,
                    category: script.category,
                    level: script.level,
                    complexity: script.complexity,
                    status: script.status,
                    type: 'script'
                });
                processedNodes.add(script.id);
            }

            // Ajouter les liens de dépendance
            script.dependencies.forEach(depId => {
                const dependency = this.getScript(depId);
                if (dependency) {
                    // Ajouter le nœud de dépendance s'il n'existe pas
                    if (!processedNodes.has(depId)) {
                        nodes.push({
                            id: depId,
                            name: dependency.name,
                            category: dependency.category,
                            level: dependency.level,
                            complexity: dependency.complexity,
                            status: dependency.status,
                            type: 'script'
                        });
                        processedNodes.add(depId);
                    }

                    // Ajouter le lien
                    links.push({
                        source: depId,
                        target: script.id,
                        type: 'dependency',
                        strength: this.calculateDependencyStrength(depId, script.id)
                    });
                }
            });
        });

        return { nodes, links };
    }

    /**
     * Calcule la force d'une dépendance
     * @param {string} sourceId - ID du script source
     * @param {string} targetId - ID du script cible
     * @returns {number} - Force de la dépendance (0-1)
     */
    calculateDependencyStrength(sourceId, targetId) {
        // Logique simplifiée pour calculer la force
        // Peut être étendue selon les besoins
        const source = this.getScript(sourceId);
        const target = this.getScript(targetId);
        
        if (!source || !target) return 0.1;

        // Plus de dépendances = lien plus faible individuellement
        const targetDepsCount = target.dependencies.length;
        return Math.max(0.1, 1 / (targetDepsCount + 1));
    }

    /**
     * ===========================
     * Utilitaires de Formatage
     * ===========================
     */

    /**
     * Formate le nom d'une catégorie pour l'affichage
     * @param {string} category - Nom de la catégorie
     * @returns {string} - Nom formaté
     */
    formatCategoryName(category) {
        const names = {
            'usb': 'Stockage USB',
            'iscsi': 'Configuration iSCSI',
            'network': 'Réseau',
            'system': 'Système',
            'file': 'Fichiers',
            'other': 'Autres'
        };
        return names[category] || category.charAt(0).toUpperCase() + category.slice(1);
    }

    /**
     * Formate le nom d'un niveau pour l'affichage
     * @param {string} level - Nom du niveau
     * @returns {string} - Nom formaté
     */
    formatLevelName(level) {
        const names = {
            'atomic': 'Scripts Atomiques',
            'orchestrator': 'Orchestrateurs',
            'main': 'Scripts Principaux'
        };
        return names[level] || level.charAt(0).toUpperCase() + level.slice(1);
    }

    /**
     * Vérifie si les données sont chargées
     * @returns {boolean} - True si les données sont chargées
     */
    isLoaded() {
        return this.loaded;
    }

    /**
     * Recharge les données en forçant le rechargement depuis le serveur
     * @returns {Promise<boolean>} - True si le rechargement est réussi
     */
    async reloadData() {
        this.clearCache();
        this.loaded = false;
        return await this.loadData();
    }
}

// Export pour utilisation
window.DataManager = DataManager;