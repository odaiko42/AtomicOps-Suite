/**
 * AtomicOps-Suite - Application principale
 * Orchestre tous les composants de l'interface de visualisation
 */

class AtomicOpsApp {
    constructor() {
        this.dataParser = null;
        this.hierarchyViz = null;
        this.scriptDetails = null;
        this.analytics = null;
        this.currentTab = 'hierarchy';
        this.filters = {
            categories: ['all'],
            search: '',
            complexity: 'all'
        };
        
        this.init();
    }

    /**
     * Initialise l'application
     */
    async init() {
        try {
            // Afficher le loader
            this.showLoader('Initialisation d\'AtomicOps-Suite...');
            
            // Initialiser le parseur de données
            this.dataParser = new DataParser();
            await this.dataParser.init();
            
            // Initialiser les composants
            this.initializeComponents();
            
            // Configurer les événements
            this.setupEventListeners();
            
            // Initialiser l'interface
            this.setupInterface();
            
            // Cacher le loader
            this.hideLoader();
            
            console.log('AtomicOps-Suite initialisé avec succès');
            
        } catch (error) {
            console.error('Erreur lors de l\'initialisation:', error);
            this.showError('Erreur lors de l\'initialisation de l\'application');
        }
    }

    /**
     * Initialise tous les composants
     */
    initializeComponents() {
        // Composant de visualisation hiérarchique
        this.hierarchyViz = new HierarchyVisualization('hierarchyContainer', this.dataParser);
        
        // Composant de détails des scripts
        this.scriptDetails = new ScriptDetails('detailsContainer');
        
        // Composant d'analytics
        this.analytics = new Analytics('analyticsContainer', this.dataParser);
        
        console.log('Composants initialisés');
    }

    /**
     * Configure tous les événements
     */
    setupEventListeners() {
        // Navigation par onglets
        this.setupTabNavigation();
        
        // Contrôles de vue (arbre, réseau, circulaire)
        this.setupViewControls();
        
        // Système de recherche
        this.setupSearch();
        
        // Filtres par catégorie
        this.setupCategoryFilters();
        
        // Filtre de complexité
        this.setupComplexityFilter();
        
        // Boutons d'action
        this.setupActionButtons();
        
        // Redimensionnement de fenêtre
        this.setupWindowResize();
        
        // Événements globaux
        this.setupGlobalEvents();
    }

    /**
     * Configure la navigation par onglets
     */
    setupTabNavigation() {
        const tabButtons = document.querySelectorAll('[data-tab]');
        const tabContents = document.querySelectorAll('.tab-content');
        
        tabButtons.forEach(button => {
            button.addEventListener('click', (e) => {
                e.preventDefault();
                const tabId = button.getAttribute('data-tab');
                this.switchTab(tabId);
            });
        });
    }

    /**
     * Change d'onglet
     */
    switchTab(tabId) {
        // Désactiver tous les onglets
        document.querySelectorAll('[data-tab]').forEach(btn => {
            btn.classList.remove('active');
        });
        
        document.querySelectorAll('.tab-content').forEach(content => {
            content.classList.remove('active');
        });
        
        // Activer l'onglet sélectionné
        const activeButton = document.querySelector(`[data-tab="${tabId}"]`);
        const activeContent = document.getElementById(`${tabId}Tab`);
        
        if (activeButton && activeContent) {
            activeButton.classList.add('active');
            activeContent.classList.add('active');
            this.currentTab = tabId;
            
            // Actions spécifiques selon l'onglet
            this.onTabChanged(tabId);
        }
    }

    /**
     * Actions à effectuer lors du changement d'onglet
     */
    onTabChanged(tabId) {
        switch (tabId) {
            case 'hierarchy':
                // Redimensionner la visualisation si nécessaire
                if (this.hierarchyViz) {
                    setTimeout(() => this.hierarchyViz.resize(), 100);
                }
                break;
                
            case 'analytics':
                // Actualiser les analytics si nécessaire
                if (this.analytics) {
                    setTimeout(() => this.analytics.resizeCharts(), 100);
                }
                break;
        }
    }

    /**
     * Configure les contrôles de vue
     */
    setupViewControls() {
        const viewButtons = document.querySelectorAll('.view-btn');
        
        viewButtons.forEach(button => {
            button.addEventListener('click', () => {
                const viewType = button.id.replace('View', '');
                if (this.hierarchyViz) {
                    this.hierarchyViz.changeView(viewType);
                }
            });
        });
    }

    /**
     * Configure la recherche
     */
    setupSearch() {
        const searchInput = document.getElementById('searchInput');
        const searchButton = document.getElementById('searchButton');
        const clearButton = document.getElementById('clearSearch');
        
        if (searchInput) {
            // Recherche en temps réel
            searchInput.addEventListener('input', (e) => {
                this.filters.search = e.target.value.toLowerCase();
                this.debounce(() => this.applyFilters(), 300);
            });
            
            // Recherche à la validation
            searchInput.addEventListener('keypress', (e) => {
                if (e.key === 'Enter') {
                    this.applyFilters();
                }
            });
        }
        
        if (searchButton) {
            searchButton.addEventListener('click', () => {
                this.applyFilters();
            });
        }
        
        if (clearButton) {
            clearButton.addEventListener('click', () => {
                searchInput.value = '';
                this.filters.search = '';
                this.applyFilters();
            });
        }
    }

    /**
     * Configure les filtres par catégorie
     */
    setupCategoryFilters() {
        const categoryCheckboxes = document.querySelectorAll('input[name="category"]');
        
        categoryCheckboxes.forEach(checkbox => {
            checkbox.addEventListener('change', () => {
                this.updateCategoryFilters();
                this.applyFilters();
            });
        });
    }

    /**
     * Met à jour les filtres de catégorie
     */
    updateCategoryFilters() {
        const checkboxes = document.querySelectorAll('input[name="category"]:checked');
        this.filters.categories = Array.from(checkboxes).map(cb => cb.value);
        
        // Si aucune catégorie sélectionnée, afficher toutes
        if (this.filters.categories.length === 0) {
            this.filters.categories = ['all'];
        }
    }

    /**
     * Configure le filtre de complexité
     */
    setupComplexityFilter() {
        const complexitySelect = document.getElementById('complexityFilter');
        
        if (complexitySelect) {
            complexitySelect.addEventListener('change', (e) => {
                this.filters.complexity = e.target.value;
                this.applyFilters();
            });
        }
    }

    /**
     * Configure les boutons d'action
     */
    setupActionButtons() {
        // Bouton refresh
        const refreshButton = document.getElementById('refreshData');
        if (refreshButton) {
            refreshButton.addEventListener('click', () => {
                this.refreshAllData();
            });
        }
        
        // Bouton export
        const exportButton = document.getElementById('exportData');
        if (exportButton) {
            exportButton.addEventListener('click', () => {
                this.exportData();
            });
        }
        
        // Bouton fullscreen
        const fullscreenButton = document.getElementById('toggleFullscreen');
        if (fullscreenButton) {
            fullscreenButton.addEventListener('click', () => {
                this.toggleFullscreen();
            });
        }
        
        // Bouton reset filters
        const resetButton = document.getElementById('resetFilters');
        if (resetButton) {
            resetButton.addEventListener('click', () => {
                this.resetFilters();
            });
        }
    }

    /**
     * Configure le redimensionnement
     */
    setupWindowResize() {
        const resizeHandler = this.debounce(() => {
            if (this.hierarchyViz) {
                this.hierarchyViz.resize();
            }
            if (this.analytics) {
                this.analytics.resizeCharts();
            }
        }, 250);
        
        window.addEventListener('resize', resizeHandler);
    }

    /**
     * Configure les événements globaux
     */
    setupGlobalEvents() {
        // Gestion des erreurs globales
        window.addEventListener('error', (event) => {
            console.error('Erreur globale:', event.error);
            this.showError('Une erreur inattendue s\'est produite');
        });
        
        // Gestion des clics extérieurs (fermer modales, etc.)
        document.addEventListener('click', (e) => {
            this.handleGlobalClick(e);
        });
        
        // Raccourcis clavier
        document.addEventListener('keydown', (e) => {
            this.handleKeyboardShortcuts(e);
        });
    }

    /**
     * Applique tous les filtres actifs
     */
    applyFilters() {
        // Filtrer les données
        const filteredScripts = this.filterScripts();
        
        // Mettre à jour la visualisation
        if (this.hierarchyViz) {
            this.hierarchyViz.filterVisualization(this.filters);
        }
        
        // Mettre à jour le compteur de résultats
        this.updateResultCount(filteredScripts.length);
    }

    /**
     * Filtre les scripts selon les critères actuels
     */
    filterScripts() {
        const allScripts = this.dataParser.getAllScripts();
        
        return allScripts.filter(script => {
            // Filtre par catégorie
            const categoryMatch = this.filters.categories.includes('all') || 
                                this.filters.categories.includes(script.category);
            
            // Filtre par recherche
            const searchMatch = !this.filters.search || 
                              script.name.toLowerCase().includes(this.filters.search) ||
                              script.description.toLowerCase().includes(this.filters.search);
            
            // Filtre par complexité
            const complexityMatch = this.filters.complexity === 'all' ||
                                  this.matchesComplexityFilter(script.complexity);
            
            return categoryMatch && searchMatch && complexityMatch;
        });
    }

    /**
     * Vérifie si un script correspond au filtre de complexité
     */
    matchesComplexityFilter(complexity) {
        switch (this.filters.complexity) {
            case 'low': return complexity <= 4;
            case 'medium': return complexity > 4 && complexity <= 7;
            case 'high': return complexity > 7;
            default: return true;
        }
    }

    /**
     * Met à jour le compteur de résultats
     */
    updateResultCount(count) {
        const counter = document.getElementById('resultCount');
        if (counter) {
            const total = this.dataParser.getAllScripts().length;
            counter.textContent = `${count} sur ${total} scripts`;
        }
    }

    /**
     * Remet à zéro tous les filtres
     */
    resetFilters() {
        // Reset des valeurs
        this.filters = {
            categories: ['all'],
            search: '',
            complexity: 'all'
        };
        
        // Reset de l'interface
        const searchInput = document.getElementById('searchInput');
        if (searchInput) searchInput.value = '';
        
        const complexitySelect = document.getElementById('complexityFilter');
        if (complexitySelect) complexitySelect.value = 'all';
        
        const checkboxes = document.querySelectorAll('input[name="category"]');
        checkboxes.forEach(cb => cb.checked = cb.value === 'all');
        
        // Appliquer les filtres
        this.applyFilters();
    }

    /**
     * Actualise toutes les données
     */
    async refreshAllData() {
        try {
            this.showLoader('Actualisation des données...');
            
            // Réinitialiser le parseur de données
            await this.dataParser.init();
            
            // Actualiser tous les composants
            if (this.hierarchyViz) {
                this.hierarchyViz.changeView(this.hierarchyViz.currentView);
            }
            
            if (this.analytics) {
                this.analytics.refreshAnalytics();
            }
            
            // Réappliquer les filtres
            this.applyFilters();
            
            this.hideLoader();
            this.showSuccess('Données actualisées avec succès');
            
        } catch (error) {
            console.error('Erreur lors de l\'actualisation:', error);
            this.hideLoader();
            this.showError('Erreur lors de l\'actualisation des données');
        }
    }

    /**
     * Exporte les données
     */
    exportData() {
        try {
            const data = {
                scripts: this.dataParser.getAllScripts(),
                categories: this.dataParser.getCategories(),
                dependencies: Object.fromEntries(this.dataParser.getDependencyGraph()),
                exportDate: new Date().toISOString(),
                version: '1.0.0'
            };
            
            const blob = new Blob([JSON.stringify(data, null, 2)], {
                type: 'application/json'
            });
            
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `atomicops-data-${new Date().toISOString().split('T')[0]}.json`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            
            this.showSuccess('Données exportées avec succès');
            
        } catch (error) {
            console.error('Erreur lors de l\'export:', error);
            this.showError('Erreur lors de l\'export des données');
        }
    }

    /**
     * Bascule en mode plein écran
     */
    toggleFullscreen() {
        const container = document.querySelector('.app-container');
        
        if (!document.fullscreenElement) {
            container.requestFullscreen().catch(err => {
                console.error('Erreur plein écran:', err);
            });
        } else {
            document.exitFullscreen();
        }
    }

    /**
     * Gère les clics globaux
     */
    handleGlobalClick(event) {
        // Fermer les dropdowns ouverts, etc.
        const openDropdowns = document.querySelectorAll('.dropdown.open');
        openDropdowns.forEach(dropdown => {
            if (!dropdown.contains(event.target)) {
                dropdown.classList.remove('open');
            }
        });
    }

    /**
     * Gère les raccourcis clavier
     */
    handleKeyboardShortcuts(event) {
        // Ctrl+F : Focus sur la recherche
        if (event.ctrlKey && event.key === 'f') {
            event.preventDefault();
            const searchInput = document.getElementById('searchInput');
            if (searchInput) {
                searchInput.focus();
                searchInput.select();
            }
        }
        
        // Ctrl+R : Actualiser
        if (event.ctrlKey && event.key === 'r') {
            event.preventDefault();
            this.refreshAllData();
        }
        
        // Escape : Reset des filtres
        if (event.key === 'Escape') {
            this.resetFilters();
        }
        
        // Touches 1-3 : Changement d'onglet
        if (event.ctrlKey && ['1', '2', '3'].includes(event.key)) {
            event.preventDefault();
            const tabs = ['hierarchy', 'details', 'analytics'];
            const tabIndex = parseInt(event.key) - 1;
            if (tabs[tabIndex]) {
                this.switchTab(tabs[tabIndex]);
            }
        }
    }

    /**
     * Configure l'interface initiale
     */
    setupInterface() {
        // Initialiser les compteurs
        this.updateResultCount(this.dataParser.getAllScripts().length);
        
        // Activer l'onglet par défaut
        this.switchTab('hierarchy');
        
        // Mettre à jour les informations de version
        const versionElement = document.getElementById('appVersion');
        if (versionElement) {
            versionElement.textContent = 'v1.0.0';
        }
        
        // Initialiser les tooltips si nécessaire
        this.initializeTooltips();
    }

    /**
     * Initialise les tooltips
     */
    initializeTooltips() {
        const tooltipElements = document.querySelectorAll('[data-tooltip]');
        tooltipElements.forEach(element => {
            element.addEventListener('mouseenter', (e) => {
                this.showTooltip(e.target, e.target.getAttribute('data-tooltip'));
            });
            
            element.addEventListener('mouseleave', () => {
                this.hideTooltip();
            });
        });
    }

    /**
     * Utilitaire de debounce
     */
    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    /**
     * Affiche le loader
     */
    showLoader(message = 'Chargement...') {
        const loader = document.getElementById('loader');
        const loaderText = document.getElementById('loaderText');
        
        if (loader) {
            loader.classList.remove('hidden');
            if (loaderText) {
                loaderText.textContent = message;
            }
        }
    }

    /**
     * Cache le loader
     */
    hideLoader() {
        const loader = document.getElementById('loader');
        if (loader) {
            loader.classList.add('hidden');
        }
    }

    /**
     * Affiche un message d'erreur
     */
    showError(message) {
        this.showNotification(message, 'error');
    }

    /**
     * Affiche un message de succès
     */
    showSuccess(message) {
        this.showNotification(message, 'success');
    }

    /**
     * Affiche une notification
     */
    showNotification(message, type = 'info') {
        // Créer la notification
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        notification.innerHTML = `
            <div class="notification-content">
                <i class="fas fa-${this.getNotificationIcon(type)} mr-2"></i>
                <span>${message}</span>
            </div>
            <button class="notification-close">
                <i class="fas fa-times"></i>
            </button>
        `;
        
        // Ajouter au container
        const container = document.getElementById('notificationContainer') || document.body;
        container.appendChild(notification);
        
        // Fermer automatiquement
        setTimeout(() => {
            notification.remove();
        }, 5000);
        
        // Bouton de fermeture
        notification.querySelector('.notification-close').addEventListener('click', () => {
            notification.remove();
        });
    }

    /**
     * Retourne l'icône appropriée pour le type de notification
     */
    getNotificationIcon(type) {
        const icons = {
            success: 'check-circle',
            error: 'exclamation-circle',
            warning: 'exclamation-triangle',
            info: 'info-circle'
        };
        return icons[type] || 'info-circle';
    }
}

// Initialiser l'application au chargement de la page
document.addEventListener('DOMContentLoaded', () => {
    window.atomicOpsApp = new AtomicOpsApp();
});

// Export pour utilisation globale
window.AtomicOpsApp = AtomicOpsApp;