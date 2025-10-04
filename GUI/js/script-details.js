/**
 * AtomicOps-Suite - Détails des scripts
 * Gère l'affichage détaillé d'un script sélectionné
 */

class ScriptDetails {
    constructor(containerId) {
        this.container = document.getElementById(containerId);
        this.currentScript = null;
        this.init();
    }

    /**
     * Initialise le composant
     */
    init() {
        // Écouter les événements de sélection de script
        window.addEventListener('scriptSelected', (event) => {
            this.displayScript(event.detail.script);
        });

        this.renderEmptyState();
    }

    /**
     * Affiche l'état vide (aucun script sélectionné)
     */
    renderEmptyState() {
        this.container.innerHTML = `
            <div class="empty-state">
                <div class="empty-icon">
                    <i class="fas fa-file-code text-4xl text-gray-400"></i>
                </div>
                <h3 class="text-lg font-semibold text-gray-600 mt-4">Aucun script sélectionné</h3>
                <p class="text-gray-500 mt-2">Cliquez sur un script dans la visualisation pour voir ses détails</p>
            </div>
        `;
    }

    /**
     * Affiche les détails d'un script
     */
    displayScript(script) {
        if (!script) {
            this.renderEmptyState();
            return;
        }

        this.currentScript = script;
        
        this.container.innerHTML = `
            <div class="script-details-content">
                <!-- En-tête du script -->
                <div class="script-header">
                    <div class="flex items-center justify-between mb-4">
                        <div class="flex items-center">
                            <div class="script-icon">
                                <i class="fas fa-terminal text-2xl text-blue-600"></i>
                            </div>
                            <div class="ml-3">
                                <h2 class="text-xl font-bold text-gray-900">${script.name}</h2>
                                <p class="text-sm text-gray-600">${this.getCategoryDisplayName(script.category)}</p>
                            </div>
                        </div>
                        <div class="complexity-badge complexity-${this.getComplexityLevel(script.complexity)}">
                            <span class="text-sm font-medium">Complexité ${script.complexity}/10</span>
                        </div>
                    </div>
                    <p class="text-gray-700 leading-relaxed">${script.description}</p>
                </div>

                <!-- Onglets de contenu -->
                <div class="script-tabs mt-6">
                    <div class="tab-buttons flex border-b">
                        <button class="tab-btn active" data-tab="overview">
                            <i class="fas fa-info-circle mr-2"></i>Aperçu
                        </button>
                        <button class="tab-btn" data-tab="parameters">
                            <i class="fas fa-sliders-h mr-2"></i>Paramètres
                        </button>
                        <button class="tab-btn" data-tab="dependencies">
                            <i class="fas fa-project-diagram mr-2"></i>Dépendances
                        </button>
                        <button class="tab-btn" data-tab="usage">
                            <i class="fas fa-code mr-2"></i>Utilisation
                        </button>
                    </div>

                    <!-- Contenu des onglets -->
                    <div class="tab-content mt-4">
                        ${this.renderOverviewTab(script)}
                        ${this.renderParametersTab(script)}
                        ${this.renderDependenciesTab(script)}
                        ${this.renderUsageTab(script)}
                    </div>
                </div>
            </div>
        `;

        this.setupTabNavigation();
    }

    /**
     * Rendu de l'onglet Aperçu
     */
    renderOverviewTab(script) {
        return `
            <div class="tab-panel active" data-panel="overview">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <!-- Informations générales -->
                    <div class="info-card">
                        <h3 class="card-title">
                            <i class="fas fa-info-circle text-blue-600 mr-2"></i>
                            Informations générales
                        </h3>
                        <div class="info-grid">
                            <div class="info-item">
                                <span class="label">Nom du fichier:</span>
                                <span class="value">${script.name}</span>
                            </div>
                            <div class="info-item">
                                <span class="label">Catégorie:</span>
                                <span class="value">${this.getCategoryDisplayName(script.category)}</span>
                            </div>
                            <div class="info-item">
                                <span class="label">Complexité:</span>
                                <span class="value">
                                    ${this.renderComplexityBar(script.complexity)}
                                </span>
                            </div>
                            <div class="info-item">
                                <span class="label">Type:</span>
                                <span class="value">Script atomique</span>
                            </div>
                        </div>
                    </div>

                    <!-- Métriques -->
                    <div class="info-card">
                        <h3 class="card-title">
                            <i class="fas fa-chart-bar text-green-600 mr-2"></i>
                            Métriques
                        </h3>
                        <div class="metrics-grid">
                            <div class="metric-item">
                                <div class="metric-value">${script.inputs ? script.inputs.length : 0}</div>
                                <div class="metric-label">Paramètres d'entrée</div>
                            </div>
                            <div class="metric-item">
                                <div class="metric-value">${script.outputs ? script.outputs.length : 0}</div>
                                <div class="metric-label">Sorties</div>
                            </div>
                            <div class="metric-item">
                                <div class="metric-value">${script.dependencies ? script.dependencies.length : 0}</div>
                                <div class="metric-label">Dépendances</div>
                            </div>
                            <div class="metric-item">
                                <div class="metric-value">${this.getEstimatedTime(script.complexity)}</div>
                                <div class="metric-label">Temps estimé</div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Description détaillée -->
                <div class="info-card mt-6">
                    <h3 class="card-title">
                        <i class="fas fa-file-alt text-purple-600 mr-2"></i>
                        Description détaillée
                    </h3>
                    <div class="description-content">
                        <p class="text-gray-700 leading-relaxed">${script.description}</p>
                        ${script.purpose ? `
                            <div class="mt-4">
                                <h4 class="font-semibold text-gray-800 mb-2">Objectif:</h4>
                                <p class="text-gray-700">${script.purpose}</p>
                            </div>
                        ` : ''}
                    </div>
                </div>
            </div>
        `;
    }

    /**
     * Rendu de l'onglet Paramètres
     */
    renderParametersTab(script) {
        const inputs = script.inputs || [];
        const outputs = script.outputs || [];

        return `
            <div class="tab-panel" data-panel="parameters">
                <!-- Paramètres d'entrée -->
                <div class="info-card mb-6">
                    <h3 class="card-title">
                        <i class="fas fa-sign-in-alt text-blue-600 mr-2"></i>
                        Paramètres d'entrée (${inputs.length})
                    </h3>
                    ${inputs.length > 0 ? `
                        <div class="parameters-list">
                            ${inputs.map(input => `
                                <div class="parameter-item">
                                    <div class="parameter-header">
                                        <span class="parameter-name">${input.name}</span>
                                        <span class="parameter-type ${input.required ? 'required' : 'optional'}">
                                            ${input.required ? 'Requis' : 'Optionnel'}
                                        </span>
                                    </div>
                                    <div class="parameter-description">
                                        ${input.description}
                                    </div>
                                    ${input.type ? `
                                        <div class="parameter-type-info">
                                            <span class="label">Type:</span> 
                                            <code>${input.type}</code>
                                        </div>
                                    ` : ''}
                                    ${input.default ? `
                                        <div class="parameter-default">
                                            <span class="label">Défaut:</span> 
                                            <code>${input.default}</code>
                                        </div>
                                    ` : ''}
                                </div>
                            `).join('')}
                        </div>
                    ` : `
                        <p class="text-gray-500 italic">Aucun paramètre d'entrée requis</p>
                    `}
                </div>

                <!-- Sorties -->
                <div class="info-card">
                    <h3 class="card-title">
                        <i class="fas fa-sign-out-alt text-green-600 mr-2"></i>
                        Sorties (${outputs.length})
                    </h3>
                    ${outputs.length > 0 ? `
                        <div class="outputs-list">
                            ${outputs.map(output => `
                                <div class="output-item">
                                    <div class="output-header">
                                        <span class="output-name">${output.name}</span>
                                        <span class="output-type">${output.type || 'Texte'}</span>
                                    </div>
                                    <div class="output-description">
                                        ${output.description}
                                    </div>
                                </div>
                            `).join('')}
                        </div>
                    ` : `
                        <p class="text-gray-500 italic">Aucune sortie spécifique documentée</p>
                    `}
                </div>
            </div>
        `;
    }

    /**
     * Rendu de l'onglet Dépendances
     */
    renderDependenciesTab(script) {
        const dependencies = script.dependencies || [];

        return `
            <div class="tab-panel" data-panel="dependencies">
                <div class="info-card">
                    <h3 class="card-title">
                        <i class="fas fa-project-diagram text-purple-600 mr-2"></i>
                        Dépendances système (${dependencies.length})
                    </h3>
                    ${dependencies.length > 0 ? `
                        <div class="dependencies-list">
                            ${dependencies.map(dep => `
                                <div class="dependency-item">
                                    <div class="dependency-icon">
                                        <i class="fas fa-${this.getDependencyIcon(dep.type)} text-blue-600"></i>
                                    </div>
                                    <div class="dependency-info">
                                        <div class="dependency-name">${dep.name}</div>
                                        <div class="dependency-description">${dep.description}</div>
                                        <div class="dependency-meta">
                                            <span class="dependency-type">${dep.type}</span>
                                            ${dep.required ? '<span class="required-badge">Requis</span>' : ''}
                                        </div>
                                    </div>
                                </div>
                            `).join('')}
                        </div>
                    ` : `
                        <div class="no-dependencies">
                            <i class="fas fa-check-circle text-green-500 text-2xl mb-2"></i>
                            <p class="text-gray-600">Ce script n'a aucune dépendance externe</p>
                            <p class="text-sm text-gray-500 mt-1">Il peut être exécuté de manière autonome</p>
                        </div>
                    `}
                </div>

                <!-- Scripts liés -->
                <div class="info-card mt-6">
                    <h3 class="card-title">
                        <i class="fas fa-link text-orange-600 mr-2"></i>
                        Scripts liés
                    </h3>
                    <div class="related-scripts">
                        <p class="text-gray-500 italic">Analyse des relations entre scripts en cours de développement</p>
                    </div>
                </div>
            </div>
        `;
    }

    /**
     * Rendu de l'onglet Utilisation
     */
    renderUsageTab(script) {
        return `
            <div class="tab-panel" data-panel="usage">
                <!-- Exemple d'utilisation -->
                <div class="info-card mb-6">
                    <h3 class="card-title">
                        <i class="fas fa-code text-green-600 mr-2"></i>
                        Exemple d'utilisation
                    </h3>
                    <div class="code-example">
                        <div class="code-header">
                            <span class="code-language">bash</span>
                            <button class="copy-btn" onclick="navigator.clipboard.writeText(this.nextElementSibling.textContent)">
                                <i class="fas fa-copy"></i>
                            </button>
                        </div>
                        <pre class="code-content"><code>${this.generateUsageExample(script)}</code></pre>
                    </div>
                </div>

                <!-- Instructions d'exécution -->
                <div class="info-card">
                    <h3 class="card-title">
                        <i class="fas fa-play-circle text-blue-600 mr-2"></i>
                        Instructions d'exécution
                    </h3>
                    <div class="execution-steps">
                        <div class="step">
                            <div class="step-number">1</div>
                            <div class="step-content">
                                <h4>Vérification des prérequis</h4>
                                <p>Assurez-vous que toutes les dépendances sont installées</p>
                            </div>
                        </div>
                        <div class="step">
                            <div class="step-number">2</div>
                            <div class="step-content">
                                <h4>Permissions d'exécution</h4>
                                <p>Accordez les permissions nécessaires : <code>chmod +x ${script.name}</code></p>
                            </div>
                        </div>
                        <div class="step">
                            <div class="step-number">3</div>
                            <div class="step-content">
                                <h4>Exécution</h4>
                                <p>Lancez le script avec les paramètres appropriés</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }

    /**
     * Configure la navigation par onglets
     */
    setupTabNavigation() {
        const tabButtons = this.container.querySelectorAll('.tab-btn');
        const tabPanels = this.container.querySelectorAll('.tab-panel');

        tabButtons.forEach(button => {
            button.addEventListener('click', () => {
                const targetTab = button.getAttribute('data-tab');

                // Désactiver tous les boutons et panneaux
                tabButtons.forEach(btn => btn.classList.remove('active'));
                tabPanels.forEach(panel => panel.classList.remove('active'));

                // Activer le bouton et panneau sélectionnés
                button.classList.add('active');
                const targetPanel = this.container.querySelector(`[data-panel="${targetTab}"]`);
                if (targetPanel) {
                    targetPanel.classList.add('active');
                }
            });
        });
    }

    /**
     * Génère un exemple d'utilisation pour le script
     */
    generateUsageExample(script) {
        const inputs = script.inputs || [];
        
        let example = `# Exécution de ${script.name}\n`;
        example += `cd /path/to/usb-disk-manager/scripts/atomic/\n`;
        example += `./${script.name}`;
        
        if (inputs.length > 0) {
            const requiredInputs = inputs.filter(input => input.required);
            const optionalInputs = inputs.filter(input => !input.required);
            
            // Paramètres requis
            requiredInputs.forEach(input => {
                example += ` --${input.name} "${input.example || 'valeur'}"`;
            });
            
            // Paramètres optionnels (commentés)
            if (optionalInputs.length > 0) {
                example += `\n\n# Paramètres optionnels:`;
                optionalInputs.forEach(input => {
                    example += `\n# --${input.name} "${input.example || 'valeur'}"`;
                });
            }
        }
        
        return example;
    }

    /**
     * Retourne le nom affiché de la catégorie
     */
    getCategoryDisplayName(category) {
        const categoryNames = {
            'restore': 'Restauration',
            'security': 'Sécurité',
            'configuration': 'Configuration',
            'network': 'Réseau',
            'notification': 'Notification',
            'maintenance': 'Maintenance',
            'testing': 'Tests',
            'scheduling': 'Planification',
            'search': 'Recherche'
        };
        
        return categoryNames[category] || category;
    }

    /**
     * Retourne le niveau de complexité (low, medium, high)
     */
    getComplexityLevel(complexity) {
        if (complexity <= 4) return 'low';
        if (complexity <= 7) return 'medium';
        return 'high';
    }

    /**
     * Génère une barre de complexité visuelle
     */
    renderComplexityBar(complexity) {
        const level = this.getComplexityLevel(complexity);
        const percentage = (complexity / 10) * 100;
        
        return `
            <div class="complexity-bar">
                <div class="complexity-fill complexity-${level}" style="width: ${percentage}%"></div>
                <span class="complexity-text">${complexity}/10</span>
            </div>
        `;
    }

    /**
     * Retourne le temps estimé d'exécution
     */
    getEstimatedTime(complexity) {
        const times = {
            1: '< 1 min',
            2: '1-2 min',
            3: '2-3 min',
            4: '3-5 min',
            5: '5-10 min',
            6: '10-15 min',
            7: '15-30 min',
            8: '30+ min',
            9: '1+ heure',
            10: 'Variable'
        };
        
        return times[complexity] || '~ 5 min';
    }

    /**
     * Retourne l'icône appropriée pour un type de dépendance
     */
    getDependencyIcon(type) {
        const icons = {
            'command': 'terminal',
            'package': 'box',
            'service': 'cogs',
            'file': 'file',
            'library': 'book',
            'network': 'network-wired'
        };
        
        return icons[type] || 'cube';
    }
}

// Export pour utilisation globale
window.ScriptDetails = ScriptDetails;