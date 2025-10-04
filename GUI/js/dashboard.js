/**
 * ===========================
 * Dashboard Principal - AtomicOps Suite
 * ===========================
 * 
 * Ce module coordonne l'interface graphique complète et gère
 * l'interaction entre les différents composants de visualisation
 */

class Dashboard {
    constructor() {
        // Gestionnaire de données
        this.dataManager = null;
        
        // Diagrammes
        this.hierarchyDiagram = null;
        this.dependenciesDiagram = null;
        
        // Éléments DOM
        this.elements = {};
        
        // État de l'interface
        this.currentView = 'dashboard';
        this.currentFilters = {};
        this.selectedScript = null;
        
        // Configuration
        this.config = {
            animationDuration: 300,
            searchDebounceDelay: 500,
            autoRefreshInterval: 30000 // 30 secondes
        };
        
        // Timers
        this.searchTimer = null;
        this.refreshTimer = null;
        
        this.init();
    }

    /**
     * ===========================
     * Initialisation
     * ===========================
     */

    async init() {
        try {
            console.log('🚀 Initialisation du Dashboard AtomicOps Suite');
            
            // Initialiser le gestionnaire de données
            this.dataManager = new DataManager();
            
            // Récupérer les éléments DOM
            this.cacheElements();
            
            // Configurer les événements
            this.setupEventListeners();
            
            // Charger les données
            await this.loadData();
            
            // Initialiser l'interface
            this.initializeInterface();
            
            // Démarrer le rafraîchissement automatique
            this.startAutoRefresh();
            
            console.log('✅ Dashboard initialisé avec succès');
            
        } catch (error) {
            console.error('❌ Erreur lors de l\'initialisation du dashboard:', error);
            this.showErrorMessage('Erreur d\'initialisation', error.message);
        }
    }

    /**
     * Met en cache les éléments DOM fréquemment utilisés
     */
    cacheElements() {
        this.elements = {
            // Navigation et contrôles
            sidebarToggle: document.getElementById('sidebar-toggle'),
            sidebar: document.getElementById('sidebar'),
            viewButtons: document.querySelectorAll('[data-view]'),
            searchInput: document.getElementById('search-input'),
            categoryFilter: document.getElementById('category-filter'),
            levelFilter: document.getElementById('level-filter'),
            
            // Contenu principal
            mainContent: document.getElementById('main-content'),
            dashboardView: document.getElementById('dashboard-view'),
            hierarchyView: document.getElementById('hierarchy-view'),
            dependenciesView: document.getElementById('dependencies-view'),
            
            // Statistiques et informations
            statsCards: document.querySelectorAll('.stat-card'),
            scriptCount: document.getElementById('script-count'),
            categoryCount: document.getElementById('category-count'),
            
            // Conteneurs de diagrammes
            hierarchyContainer: document.getElementById('hierarchy-container'),
            dependenciesContainer: document.getElementById('dependencies-container'),
            
            // Scripts et détails
            scriptsList: document.getElementById('scripts-list'),
            scriptDetails: document.getElementById('script-details'),
            
            // Modal et notifications
            modal: document.getElementById('script-modal'),
            modalContent: document.getElementById('modal-content'),
            loadingIndicator: document.getElementById('loading-indicator'),
            errorContainer: document.getElementById('error-container')
        };
        
        console.log('📝 Éléments DOM mis en cache');
    }

    /**
     * Configure tous les écouteurs d'événements
     */
    setupEventListeners() {
        // Basculement de la sidebar
        if (this.elements.sidebarToggle) {
            this.elements.sidebarToggle.addEventListener('click', () => {
                this.toggleSidebar();
            });
        }

        // Boutons de vue
        this.elements.viewButtons.forEach(button => {
            button.addEventListener('click', (e) => {
                const view = e.target.getAttribute('data-view');
                this.switchView(view);
            });
        });

        // Recherche avec debounce
        if (this.elements.searchInput) {
            this.elements.searchInput.addEventListener('input', (e) => {
                clearTimeout(this.searchTimer);
                this.searchTimer = setTimeout(() => {
                    this.handleSearch(e.target.value);
                }, this.config.searchDebounceDelay);
            });
        }

        // Filtres
        if (this.elements.categoryFilter) {
            this.elements.categoryFilter.addEventListener('change', (e) => {
                this.handleFilterChange('category', e.target.value);
            });
        }

        if (this.elements.levelFilter) {
            this.elements.levelFilter.addEventListener('change', (e) => {
                this.handleFilterChange('level', e.target.value);
            });
        }

        // Fermeture du modal
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('modal') || e.target.classList.contains('modal-close')) {
                this.closeModal();
            }
        });

        // Raccourcis clavier
        document.addEventListener('keydown', (e) => {
            this.handleKeyboardShortcuts(e);
        });

        // Redimensionnement de fenêtre
        window.addEventListener('resize', () => {
            this.handleResize();
        });

        console.log('🎯 Écouteurs d\'événements configurés');
    }

    /**
     * ===========================
     * Chargement des Données
     * ===========================
     */

    async loadData() {
        try {
            this.showLoading(true);
            
            // Configurer les callbacks du gestionnaire de données
            this.dataManager.on('loaded', (data) => {
                console.log('📊 Données chargées:', data);
                this.onDataLoaded();
            });
            
            this.dataManager.on('error', (error) => {
                console.error('❌ Erreur de chargement des données:', error);
                this.showErrorMessage('Erreur de chargement', error.message);
            });

            // Charger les données
            const success = await this.dataManager.loadData();
            
            if (!success) {
                console.warn('⚠️ Chargement des données d\'exemple');
            }
            
        } catch (error) {
            console.error('❌ Erreur lors du chargement:', error);
            this.showErrorMessage('Erreur de chargement', error.message);
        } finally {
            this.showLoading(false);
        }
    }

    /**
     * Appelée quand les données sont chargées avec succès
     */
    onDataLoaded() {
        this.updateStatistics();
        this.populateFilters();
        this.renderDashboardContent();
        this.initializeDiagrams();
        
        console.log('🎉 Interface mise à jour avec les nouvelles données');
    }

    /**
     * ===========================
     * Interface Utilisateur
     * ===========================
     */

    /**
     * Initialise l'interface après le chargement des données
     */
    initializeInterface() {
        // Afficher la vue dashboard par défaut
        this.switchView('dashboard');
        
        // Initialiser les tooltips si nécessaire
        this.initializeTooltips();
        
        // Configurer les animations
        this.setupAnimations();
    }

    /**
     * Bascule la visibilité de la sidebar
     */
    toggleSidebar() {
        if (this.elements.sidebar) {
            this.elements.sidebar.classList.toggle('collapsed');
            
            // Sauvegarder l'état dans localStorage
            const isCollapsed = this.elements.sidebar.classList.contains('collapsed');
            localStorage.setItem('sidebar-collapsed', isCollapsed);
        }
    }

    /**
     * Change la vue active
     */
    switchView(viewName) {
        if (this.currentView === viewName) return;
        
        console.log(`🔄 Changement de vue: ${this.currentView} → ${viewName}`);
        
        // Masquer toutes les vues
        document.querySelectorAll('.view').forEach(view => {
            view.classList.remove('active');
        });
        
        // Désactiver tous les boutons de vue
        this.elements.viewButtons.forEach(button => {
            button.classList.remove('active');
        });
        
        // Activer la nouvelle vue
        const targetView = document.getElementById(`${viewName}-view`);
        const targetButton = document.querySelector(`[data-view="${viewName}"]`);
        
        if (targetView) {
            targetView.classList.add('active');
        }
        
        if (targetButton) {
            targetButton.classList.add('active');
        }
        
        // Mettre à jour l'état
        this.currentView = viewName;
        
        // Actions spécifiques par vue
        this.handleViewSwitch(viewName);
    }

    /**
     * Gère les actions spécifiques lors du changement de vue
     */
    handleViewSwitch(viewName) {
        switch (viewName) {
            case 'dashboard':
                this.renderDashboardContent();
                break;
                
            case 'hierarchy':
                this.renderHierarchyView();
                break;
                
            case 'dependencies':
                this.renderDependenciesView();
                break;
                
            default:
                console.warn('Vue inconnue:', viewName);
        }
    }

    /**
     * ===========================
     * Rendu du Contenu
     * ===========================
     */

    /**
     * Rend le contenu du tableau de bord
     */
    renderDashboardContent() {
        if (!this.dataManager.isLoaded()) return;
        
        this.updateStatistics();
        this.renderScriptCards();
        this.renderCategoryTree();
    }

    /**
     * Met à jour les statistiques affichées
     */
    updateStatistics() {
        const stats = this.dataManager.getStatistics();
        
        // Mettre à jour les cartes de statistiques
        if (this.elements.scriptCount) {
            this.elements.scriptCount.textContent = stats.total;
        }
        
        if (this.elements.categoryCount) {
            this.elements.categoryCount.textContent = Object.keys(stats.byCategory).length;
        }
        
        // Animer les changements de nombres
        this.animateNumbers();
    }

    /**
     * Rend les cartes de scripts
     */
    renderScriptCards() {
        const container = this.elements.scriptsList;
        if (!container) return;
        
        const scripts = this.getFilteredScripts();
        
        container.innerHTML = '';
        
        scripts.forEach(script => {
            const card = this.createScriptCard(script);
            container.appendChild(card);
        });
        
        // Animer l'apparition des cartes
        this.animateCards();
    }

    /**
     * Crée une carte pour un script
     */
    createScriptCard(script) {
        const card = document.createElement('div');
        card.className = `script-card ${script.level}`;
        card.setAttribute('data-script-id', script.id);
        
        card.innerHTML = `
            <div class="script-card-header">
                <h3 class="script-title">${script.name}</h3>
                <span class="script-level ${script.level}">${script.level}</span>
            </div>
            <div class="script-card-body">
                <p class="script-description">${script.description || 'Pas de description'}</p>
                <div class="script-meta">
                    <span class="meta-item">
                        <i class="fas fa-folder"></i>
                        ${this.dataManager.formatCategoryName(script.category)}
                    </span>
                    <span class="meta-item">
                        <i class="fas fa-cog"></i>
                        ${script.complexity}
                    </span>
                    ${script.dependencies.length > 0 ? `
                        <span class="meta-item">
                            <i class="fas fa-link"></i>
                            ${script.dependencies.length} dép.
                        </span>
                    ` : ''}
                </div>
            </div>
            <div class="script-card-footer">
                <div class="script-tags">
                    ${script.tags.slice(0, 3).map(tag => 
                        `<span class="tag">${tag}</span>`
                    ).join('')}
                    ${script.tags.length > 3 ? `<span class="tag-more">+${script.tags.length - 3}</span>` : ''}
                </div>
                <button class="btn-details" data-script-id="${script.id}">
                    <i class="fas fa-info-circle"></i>
                    Détails
                </button>
            </div>
        `;
        
        // Ajouter les événements
        card.addEventListener('click', () => {
            this.selectScript(script);
        });
        
        const detailsBtn = card.querySelector('.btn-details');
        detailsBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            this.showScriptDetails(script);
        });
        
        return card;
    }

    /**
     * Rend l'arbre des catégories
     */
    renderCategoryTree() {
        const container = document.querySelector('.category-tree');
        if (!container) return;
        
        const categories = this.dataManager.getCategories();
        
        container.innerHTML = '';
        
        categories.forEach(category => {
            const scripts = this.dataManager.getScriptsByCategory(category);
            const categoryElement = this.createCategoryElement(category, scripts);
            container.appendChild(categoryElement);
        });
    }

    /**
     * Crée un élément de catégorie
     */
    createCategoryElement(category, scripts) {
        const element = document.createElement('div');
        element.className = 'category-item';
        
        const isExpanded = localStorage.getItem(`category-${category}-expanded`) === 'true';
        
        element.innerHTML = `
            <div class="category-header" data-category="${category}">
                <i class="fas fa-chevron-${isExpanded ? 'down' : 'right'} category-toggle"></i>
                <i class="fas fa-folder category-icon"></i>
                <span class="category-name">${this.dataManager.formatCategoryName(category)}</span>
                <span class="category-count">${scripts.length}</span>
            </div>
            <div class="category-content ${isExpanded ? 'expanded' : ''}">
                ${scripts.map(script => `
                    <div class="category-script" data-script-id="${script.id}">
                        <i class="fas fa-file-code script-icon ${script.level}"></i>
                        <span class="script-name">${script.name}</span>
                        <span class="script-level-badge ${script.level}">${script.level}</span>
                    </div>
                `).join('')}
            </div>
        `;
        
        // Ajouter les événements
        const header = element.querySelector('.category-header');
        header.addEventListener('click', () => {
            this.toggleCategory(category, element);
        });
        
        const scriptElements = element.querySelectorAll('.category-script');
        scriptElements.forEach(scriptEl => {
            scriptEl.addEventListener('click', () => {
                const scriptId = scriptEl.getAttribute('data-script-id');
                const script = this.dataManager.getScript(scriptId);
                if (script) {
                    this.selectScript(script);
                }
            });
        });
        
        return element;
    }

    /**
     * ===========================
     * Diagrammes
     * ===========================
     */

    /**
     * Initialise les diagrammes
     */
    initializeDiagrams() {
        // Diagramme hiérarchique
        if (this.elements.hierarchyContainer) {
            this.hierarchyDiagram = new HierarchyDiagram(
                'hierarchy-container', 
                this.dataManager
            );
            
            this.hierarchyDiagram.setOnNodeClick((data) => {
                if (data.type === 'script') {
                    this.selectScript(data);
                }
            });
        }
        
        // Diagramme de dépendances
        if (this.elements.dependenciesContainer) {
            this.dependenciesDiagram = new DependenciesDiagram(
                'dependencies-container', 
                this.dataManager
            );
            
            this.dependenciesDiagram.setOnNodeClick((data) => {
                const script = this.dataManager.getScript(data.id);
                if (script) {
                    this.selectScript(script);
                }
            });
        }
        
        console.log('📊 Diagrammes initialisés');
    }

    /**
     * Rend la vue hiérarchique
     */
    renderHierarchyView() {
        if (this.hierarchyDiagram) {
            // Appliquer les filtres actuels
            this.hierarchyDiagram.filterDiagram(this.currentFilters);
        }
    }

    /**
     * Rend la vue des dépendances
     */
    renderDependenciesView() {
        if (this.dependenciesDiagram) {
            // Appliquer les filtres actuels
            this.dependenciesDiagram.filterDiagram(this.currentFilters);
        }
    }

    /**
     * ===========================
     * Filtrage et Recherche
     * ===========================
     */

    /**
     * Peuple les filtres avec les données disponibles
     */
    populateFilters() {
        // Filtre de catégories
        if (this.elements.categoryFilter) {
            const categories = this.dataManager.getCategories();
            this.elements.categoryFilter.innerHTML = '<option value="">Toutes les catégories</option>';
            
            categories.forEach(category => {
                const option = document.createElement('option');
                option.value = category;
                option.textContent = this.dataManager.formatCategoryName(category);
                this.elements.categoryFilter.appendChild(option);
            });
        }
        
        // Filtre de niveaux
        if (this.elements.levelFilter) {
            const levels = ['atomic', 'orchestrator', 'main'];
            this.elements.levelFilter.innerHTML = '<option value="">Tous les niveaux</option>';
            
            levels.forEach(level => {
                const option = document.createElement('option');
                option.value = level;
                option.textContent = this.dataManager.formatLevelName(level);
                this.elements.levelFilter.appendChild(option);
            });
        }
    }

    /**
     * Gère les changements de filtre
     */
    handleFilterChange(filterType, value) {
        if (value) {
            this.currentFilters[filterType] = value;
        } else {
            delete this.currentFilters[filterType];
        }
        
        console.log('🔍 Filtres mis à jour:', this.currentFilters);
        
        // Appliquer les filtres
        this.applyFilters();
    }

    /**
     * Gère la recherche
     */
    handleSearch(searchTerm) {
        if (searchTerm.trim()) {
            this.currentFilters.search = searchTerm.trim();
        } else {
            delete this.currentFilters.search;
        }
        
        console.log('🔍 Recherche:', searchTerm);
        
        // Appliquer les filtres
        this.applyFilters();
    }

    /**
     * Applique les filtres actuels
     */
    applyFilters() {
        // Mettre à jour la vue actuelle
        this.handleViewSwitch(this.currentView);
        
        // Mettre à jour les diagrammes si nécessaire
        if (this.hierarchyDiagram && this.currentView === 'hierarchy') {
            this.hierarchyDiagram.filterDiagram(this.currentFilters);
        }
        
        if (this.dependenciesDiagram && this.currentView === 'dependencies') {
            this.dependenciesDiagram.filterDiagram(this.currentFilters);
        }
    }

    /**
     * Retourne les scripts filtrés selon les critères actuels
     */
    getFilteredScripts() {
        return this.dataManager.filterScripts(this.currentFilters);
    }

    /**
     * ===========================
     * Interactions et Événements
     * ===========================
     */

    /**
     * Sélectionne un script
     */
    selectScript(script) {
        this.selectedScript = script;
        
        console.log('📋 Script sélectionné:', script.name);
        
        // Mettre à jour l'interface
        this.updateScriptSelection();
        
        // Highlight dans les diagrammes
        this.highlightScriptInDiagrams(script);
    }

    /**
     * Met à jour la sélection visuelle du script
     */
    updateScriptSelection() {
        // Enlever les anciennes sélections
        document.querySelectorAll('.script-card.selected').forEach(card => {
            card.classList.remove('selected');
        });
        
        document.querySelectorAll('.category-script.selected').forEach(script => {
            script.classList.remove('selected');
        });
        
        // Ajouter la nouvelle sélection
        if (this.selectedScript) {
            const scriptCard = document.querySelector(`[data-script-id="${this.selectedScript.id}"]`);
            if (scriptCard) {
                scriptCard.classList.add('selected');
            }
        }
    }

    /**
     * Met en surbrillance un script dans les diagrammes
     */
    highlightScriptInDiagrams(script) {
        if (this.hierarchyDiagram) {
            this.hierarchyDiagram.highlightNodes([script.id]);
        }
        
        if (this.dependenciesDiagram) {
            // Highlight le script et ses dépendances
            const dependencies = this.dataManager.getDependencies(script.id);
            const dependents = this.dataManager.getDependents(script.id);
            const allRelated = [script.id, ...dependencies, ...dependents.map(d => d.id)];
            
            this.dependenciesDiagram.highlightNodes(allRelated);
        }
    }

    /**
     * Affiche les détails d'un script dans un modal
     */
    showScriptDetails(script) {
        if (!this.elements.modal || !this.elements.modalContent) return;
        
        const dependencies = this.dataManager.getDependencies(script.id);
        const dependents = this.dataManager.getDependents(script.id);
        
        this.elements.modalContent.innerHTML = `
            <div class="modal-header">
                <h2>${script.name}</h2>
                <button class="modal-close">
                    <i class="fas fa-times"></i>
                </button>
            </div>
            <div class="modal-body">
                <div class="script-info">
                    <div class="info-section">
                        <h3>Informations générales</h3>
                        <div class="info-grid">
                            <div class="info-item">
                                <label>Niveau:</label>
                                <span class="level-badge ${script.level}">${script.level}</span>
                            </div>
                            <div class="info-item">
                                <label>Catégorie:</label>
                                <span>${this.dataManager.formatCategoryName(script.category)}</span>
                            </div>
                            <div class="info-item">
                                <label>Complexité:</label>
                                <span class="complexity-${script.complexity}">${script.complexity}</span>
                            </div>
                            <div class="info-item">
                                <label>Statut:</label>
                                <span class="status-${script.status}">${script.status}</span>
                            </div>
                        </div>
                    </div>
                    
                    ${script.description ? `
                        <div class="info-section">
                            <h3>Description</h3>
                            <p>${script.description}</p>
                        </div>
                    ` : ''}
                    
                    ${script.inputs.length > 0 ? `
                        <div class="info-section">
                            <h3>Entrées (${script.inputs.length})</h3>
                            <ul class="params-list">
                                ${script.inputs.map(input => `<li><code>${input}</code></li>`).join('')}
                            </ul>
                        </div>
                    ` : ''}
                    
                    ${script.outputs.length > 0 ? `
                        <div class="info-section">
                            <h3>Sorties (${script.outputs.length})</h3>
                            <ul class="params-list">
                                ${script.outputs.map(output => `<li><code>${output}</code></li>`).join('')}
                            </ul>
                        </div>
                    ` : ''}
                    
                    ${script.conditions.length > 0 ? `
                        <div class="info-section">
                            <h3>Conditions (${script.conditions.length})</h3>
                            <ul class="params-list">
                                ${script.conditions.map(condition => `<li>${condition}</li>`).join('')}
                            </ul>
                        </div>
                    ` : ''}
                    
                    ${dependencies.length > 0 ? `
                        <div class="info-section">
                            <h3>Dépendances (${dependencies.length})</h3>
                            <div class="dependencies-list">
                                ${dependencies.map(depId => {
                                    const dep = this.dataManager.getScript(depId);
                                    return dep ? `
                                        <div class="dependency-item" data-script-id="${dep.id}">
                                            <i class="fas fa-arrow-right"></i>
                                            <span>${dep.name}</span>
                                            <small>(${dep.level})</small>
                                        </div>
                                    ` : `<div class="dependency-item missing">⚠️ ${depId} (non trouvé)</div>`;
                                }).join('')}
                            </div>
                        </div>
                    ` : ''}
                    
                    ${dependents.length > 0 ? `
                        <div class="info-section">
                            <h3>Utilisé par (${dependents.length})</h3>
                            <div class="dependencies-list">
                                ${dependents.map(dep => `
                                    <div class="dependency-item" data-script-id="${dep.id}">
                                        <i class="fas fa-arrow-left"></i>
                                        <span>${dep.name}</span>
                                        <small>(${dep.level})</small>
                                    </div>
                                `).join('')}
                            </div>
                        </div>
                    ` : ''}
                    
                    ${script.tags.length > 0 ? `
                        <div class="info-section">
                            <h3>Tags</h3>
                            <div class="tags-container">
                                ${script.tags.map(tag => `<span class="tag">${tag}</span>`).join('')}
                            </div>
                        </div>
                    ` : ''}
                </div>
            </div>
        `;
        
        // Ajouter les événements aux liens de dépendances
        this.elements.modalContent.querySelectorAll('.dependency-item[data-script-id]').forEach(item => {
            item.addEventListener('click', () => {
                const scriptId = item.getAttribute('data-script-id');
                const relatedScript = this.dataManager.getScript(scriptId);
                if (relatedScript) {
                    this.showScriptDetails(relatedScript);
                }
            });
        });
        
        this.elements.modal.classList.add('active');
        document.body.classList.add('modal-open');
    }

    /**
     * Ferme le modal
     */
    closeModal() {
        if (this.elements.modal) {
            this.elements.modal.classList.remove('active');
            document.body.classList.remove('modal-open');
        }
    }

    /**
     * Bascule l'expansion d'une catégorie
     */
    toggleCategory(category, element) {
        const content = element.querySelector('.category-content');
        const toggle = element.querySelector('.category-toggle');
        
        const isExpanded = content.classList.contains('expanded');
        
        if (isExpanded) {
            content.classList.remove('expanded');
            toggle.classList.remove('fa-chevron-down');
            toggle.classList.add('fa-chevron-right');
        } else {
            content.classList.add('expanded');
            toggle.classList.remove('fa-chevron-right');
            toggle.classList.add('fa-chevron-down');
        }
        
        // Sauvegarder l'état
        localStorage.setItem(`category-${category}-expanded`, !isExpanded);
    }

    /**
     * ===========================
     * Utilitaires et Helpers
     * ===========================
     */

    /**
     * Gère les raccourcis clavier
     */
    handleKeyboardShortcuts(e) {
        // Ctrl/Cmd + F pour la recherche
        if ((e.ctrlKey || e.metaKey) && e.key === 'f') {
            e.preventDefault();
            if (this.elements.searchInput) {
                this.elements.searchInput.focus();
            }
        }
        
        // Échap pour fermer le modal
        if (e.key === 'Escape') {
            this.closeModal();
        }
        
        // Raccourcis de navigation (1, 2, 3 pour les vues)
        if (e.key >= '1' && e.key <= '3' && !e.ctrlKey && !e.metaKey) {
            const views = ['dashboard', 'hierarchy', 'dependencies'];
            const viewIndex = parseInt(e.key) - 1;
            if (views[viewIndex]) {
                this.switchView(views[viewIndex]);
            }
        }
    }

    /**
     * Gère le redimensionnement de la fenêtre
     */
    handleResize() {
        // Les diagrammes gèrent leur propre redimensionnement
        // Ici on peut ajouter d'autres ajustements si nécessaire
    }

    /**
     * Affiche/cache l'indicateur de chargement
     */
    showLoading(show) {
        if (this.elements.loadingIndicator) {
            this.elements.loadingIndicator.style.display = show ? 'flex' : 'none';
        }
    }

    /**
     * Affiche un message d'erreur
     */
    showErrorMessage(title, message) {
        if (this.elements.errorContainer) {
            this.elements.errorContainer.innerHTML = `
                <div class="error-message">
                    <div class="error-title">${title}</div>
                    <div class="error-text">${message}</div>
                    <button class="error-close" onclick="this.parentElement.parentElement.style.display='none'">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
            `;
            this.elements.errorContainer.style.display = 'block';
        }
        
        console.error(`${title}: ${message}`);
    }

    /**
     * Initialise les tooltips
     */
    initializeTooltips() {
        // Ajouter des tooltips aux éléments avec attribut data-tooltip
        document.querySelectorAll('[data-tooltip]').forEach(element => {
            element.addEventListener('mouseenter', (e) => {
                // Implémenter tooltip si nécessaire
            });
        });
    }

    /**
     * Configure les animations CSS
     */
    setupAnimations() {
        // Activer les animations après le chargement complet
        setTimeout(() => {
            document.body.classList.add('animations-ready');
        }, 100);
    }

    /**
     * Anime les nombres dans les statistiques
     */
    animateNumbers() {
        document.querySelectorAll('.stat-number').forEach(element => {
            const target = parseInt(element.textContent);
            let current = 0;
            const increment = target / 20;
            
            const timer = setInterval(() => {
                current += increment;
                if (current >= target) {
                    element.textContent = target;
                    clearInterval(timer);
                } else {
                    element.textContent = Math.floor(current);
                }
            }, 50);
        });
    }

    /**
     * Anime l'apparition des cartes
     */
    animateCards() {
        const cards = document.querySelectorAll('.script-card');
        cards.forEach((card, index) => {
            card.style.animationDelay = `${index * 0.05}s`;
            card.classList.add('animate-in');
        });
    }

    /**
     * Démarre le rafraîchissement automatique des données
     */
    startAutoRefresh() {
        if (this.config.autoRefreshInterval > 0) {
            this.refreshTimer = setInterval(() => {
                console.log('🔄 Rafraîchissement automatique des données');
                this.dataManager.reloadData();
            }, this.config.autoRefreshInterval);
        }
    }

    /**
     * Arrête le rafraîchissement automatique
     */
    stopAutoRefresh() {
        if (this.refreshTimer) {
            clearInterval(this.refreshTimer);
            this.refreshTimer = null;
        }
    }

    /**
     * Nettoie les ressources avant destruction
     */
    destroy() {
        // Arrêter les timers
        this.stopAutoRefresh();
        
        if (this.searchTimer) {
            clearTimeout(this.searchTimer);
        }
        
        // Nettoyer les diagrammes
        if (this.hierarchyDiagram) {
            this.hierarchyDiagram.destroy();
        }
        
        if (this.dependenciesDiagram) {
            this.dependenciesDiagram.destroy();
        }
        
        console.log('🧹 Dashboard nettoyé');
    }
}

// Initialisation automatique quand le DOM est prêt
document.addEventListener('DOMContentLoaded', () => {
    window.dashboard = new Dashboard();
});

// Export pour utilisation
window.Dashboard = Dashboard;