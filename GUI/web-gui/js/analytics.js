/**
 * AtomicOps-Suite - Analytics et statistiques
 * Génère des graphiques et analyses sur la collection de scripts
 */

class Analytics {
    constructor(containerId, dataParser) {
        this.container = document.getElementById(containerId);
        this.dataParser = dataParser;
        this.charts = {};
        this.init();
    }

    /**
     * Initialise le composant analytics
     */
    init() {
        this.renderDashboard();
        this.createCharts();
        
        // Redimensionnement automatique
        window.addEventListener('resize', () => {
            this.resizeCharts();
        });
    }

    /**
     * Rendu du tableau de bord principal
     */
    renderDashboard() {
        const stats = this.calculateStats();
        
        this.container.innerHTML = `
            <div class="analytics-dashboard">
                <!-- Métriques principales -->
                <div class="stats-overview mb-8">
                    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                        <div class="stat-card">
                            <div class="stat-icon bg-blue-100">
                                <i class="fas fa-file-code text-blue-600 text-2xl"></i>
                            </div>
                            <div class="stat-content">
                                <div class="stat-value">${stats.totalScripts}</div>
                                <div class="stat-label">Scripts totaux</div>
                            </div>
                        </div>
                        
                        <div class="stat-card">
                            <div class="stat-icon bg-green-100">
                                <i class="fas fa-layer-group text-green-600 text-2xl"></i>
                            </div>
                            <div class="stat-content">
                                <div class="stat-value">${stats.totalCategories}</div>
                                <div class="stat-label">Catégories</div>
                            </div>
                        </div>
                        
                        <div class="stat-card">
                            <div class="stat-icon bg-purple-100">
                                <i class="fas fa-brain text-purple-600 text-2xl"></i>
                            </div>
                            <div class="stat-content">
                                <div class="stat-value">${stats.avgComplexity.toFixed(1)}</div>
                                <div class="stat-label">Complexité moy.</div>
                            </div>
                        </div>
                        
                        <div class="stat-card">
                            <div class="stat-icon bg-orange-100">
                                <i class="fas fa-project-diagram text-orange-600 text-2xl"></i>
                            </div>
                            <div class="stat-content">
                                <div class="stat-value">${stats.totalDependencies}</div>
                                <div class="stat-label">Dépendances</div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Graphiques -->
                <div class="charts-section">
                    <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
                        <!-- Distribution par catégorie -->
                        <div class="chart-container">
                            <div class="chart-header">
                                <h3 class="chart-title">
                                    <i class="fas fa-chart-pie mr-2"></i>
                                    Distribution par catégorie
                                </h3>
                            </div>
                            <div class="chart-content">
                                <canvas id="categoryChart" width="400" height="300"></canvas>
                            </div>
                        </div>
                        
                        <!-- Répartition des complexités -->
                        <div class="chart-container">
                            <div class="chart-header">
                                <h3 class="chart-title">
                                    <i class="fas fa-chart-bar mr-2"></i>
                                    Répartition des complexités
                                </h3>
                            </div>
                            <div class="chart-content">
                                <canvas id="complexityChart" width="400" height="300"></canvas>
                            </div>
                        </div>
                        
                        <!-- Analyse des dépendances -->
                        <div class="chart-container">
                            <div class="chart-header">
                                <h3 class="chart-title">
                                    <i class="fas fa-network-wired mr-2"></i>
                                    Types de dépendances
                                </h3>
                            </div>
                            <div class="chart-content">
                                <canvas id="dependencyChart" width="400" height="300"></canvas>
                            </div>
                        </div>
                        
                        <!-- Métriques de paramètres -->
                        <div class="chart-container">
                            <div class="chart-header">
                                <h3 class="chart-title">
                                    <i class="fas fa-sliders-h mr-2"></i>
                                    Analyse des paramètres
                                </h3>
                            </div>
                            <div class="chart-content">
                                <canvas id="parametersChart" width="400" height="300"></canvas>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Tableaux d'analyse -->
                <div class="analysis-tables mt-8">
                    <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
                        <!-- Top scripts par complexité -->
                        <div class="table-container">
                            <h3 class="table-title">
                                <i class="fas fa-trophy mr-2"></i>
                                Scripts les plus complexes
                            </h3>
                            <div class="table-content">
                                ${this.renderComplexityTable(stats.topComplex)}
                            </div>
                        </div>
                        
                        <!-- Distribution des catégories -->
                        <div class="table-container">
                            <h3 class="table-title">
                                <i class="fas fa-list mr-2"></i>
                                Détail par catégorie
                            </h3>
                            <div class="table-content">
                                ${this.renderCategoryTable(stats.categoryBreakdown)}
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Insights et recommandations -->
                <div class="insights-section mt-8">
                    <div class="insights-container">
                        <h3 class="insights-title">
                            <i class="fas fa-lightbulb mr-2"></i>
                            Insights et recommandations
                        </h3>
                        <div class="insights-content">
                            ${this.generateInsights(stats)}
                        </div>
                    </div>
                </div>
            </div>
        `;
    }

    /**
     * Calcule les statistiques générales
     */
    calculateStats() {
        const scripts = this.dataParser.getAllScripts();
        const categories = this.dataParser.getCategories();
        
        // Statistiques de base
        const totalScripts = scripts.length;
        const totalCategories = categories.length;
        
        // Complexité moyenne
        const complexities = scripts.map(s => s.complexity || 5);
        const avgComplexity = complexities.reduce((a, b) => a + b, 0) / complexities.length;
        
        // Total des dépendances
        const totalDependencies = scripts.reduce((total, script) => {
            return total + (script.dependencies ? script.dependencies.length : 0);
        }, 0);
        
        // Top scripts par complexité
        const topComplex = scripts
            .sort((a, b) => (b.complexity || 5) - (a.complexity || 5))
            .slice(0, 5);
        
        // Répartition par catégorie
        const categoryBreakdown = categories.map(cat => ({
            name: cat.name,
            count: cat.scripts.length,
            percentage: (cat.scripts.length / totalScripts * 100).toFixed(1),
            color: cat.color
        }));
        
        // Analyse des complexités
        const complexityDistribution = {
            low: scripts.filter(s => (s.complexity || 5) <= 4).length,
            medium: scripts.filter(s => (s.complexity || 5) > 4 && (s.complexity || 5) <= 7).length,
            high: scripts.filter(s => (s.complexity || 5) > 7).length
        };
        
        // Types de dépendances
        const dependencyTypes = {};
        scripts.forEach(script => {
            if (script.dependencies) {
                script.dependencies.forEach(dep => {
                    const type = dep.type || 'other';
                    dependencyTypes[type] = (dependencyTypes[type] || 0) + 1;
                });
            }
        });
        
        // Analyse des paramètres
        const parameterStats = {
            totalInputs: scripts.reduce((total, s) => total + (s.inputs ? s.inputs.length : 0), 0),
            totalOutputs: scripts.reduce((total, s) => total + (s.outputs ? s.outputs.length : 0), 0),
            requiredParams: scripts.reduce((total, s) => {
                return total + (s.inputs ? s.inputs.filter(i => i.required).length : 0);
            }, 0),
            optionalParams: scripts.reduce((total, s) => {
                return total + (s.inputs ? s.inputs.filter(i => !i.required).length : 0);
            }, 0)
        };
        
        return {
            totalScripts,
            totalCategories,
            avgComplexity,
            totalDependencies,
            topComplex,
            categoryBreakdown,
            complexityDistribution,
            dependencyTypes,
            parameterStats
        };
    }

    /**
     * Crée tous les graphiques
     */
    createCharts() {
        const stats = this.calculateStats();
        
        // Graphique de distribution par catégorie (Donut)
        this.createCategoryChart(stats.categoryBreakdown);
        
        // Graphique des complexités (Bar)
        this.createComplexityChart(stats.complexityDistribution);
        
        // Graphique des dépendances (Doughnut)
        this.createDependencyChart(stats.dependencyTypes);
        
        // Graphique des paramètres (Radar)
        this.createParametersChart(stats.parameterStats);
    }

    /**
     * Crée le graphique de distribution par catégorie
     */
    createCategoryChart(categoryData) {
        const ctx = document.getElementById('categoryChart');
        if (!ctx) return;

        this.charts.category = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: categoryData.map(cat => cat.name.charAt(0).toUpperCase() + cat.name.slice(1)),
                datasets: [{
                    data: categoryData.map(cat => cat.count),
                    backgroundColor: categoryData.map(cat => cat.color || '#3b82f6'),
                    borderWidth: 2,
                    borderColor: '#ffffff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'right',
                        labels: {
                            padding: 20,
                            usePointStyle: true
                        }
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                const label = context.label || '';
                                const value = context.parsed || 0;
                                const percentage = categoryData[context.dataIndex].percentage;
                                return `${label}: ${value} scripts (${percentage}%)`;
                            }
                        }
                    }
                }
            }
        });
    }

    /**
     * Crée le graphique des complexités
     */
    createComplexityChart(complexityData) {
        const ctx = document.getElementById('complexityChart');
        if (!ctx) return;

        this.charts.complexity = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: ['Faible (1-4)', 'Moyenne (5-7)', 'Élevée (8-10)'],
                datasets: [{
                    label: 'Nombre de scripts',
                    data: [complexityData.low, complexityData.medium, complexityData.high],
                    backgroundColor: ['#10b981', '#f59e0b', '#ef4444'],
                    borderColor: ['#059669', '#d97706', '#dc2626'],
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            stepSize: 1
                        }
                    }
                }
            }
        });
    }

    /**
     * Crée le graphique des types de dépendances
     */
    createDependencyChart(dependencyData) {
        const ctx = document.getElementById('dependencyChart');
        if (!ctx) return;

        const labels = Object.keys(dependencyData);
        const data = Object.values(dependencyData);
        
        if (labels.length === 0) {
            // Graphique vide si pas de dépendances
            ctx.getContext('2d').fillText('Aucune dépendance analysée', 50, 150);
            return;
        }

        this.charts.dependency = new Chart(ctx, {
            type: 'pie',
            data: {
                labels: labels.map(l => l.charAt(0).toUpperCase() + l.slice(1)),
                datasets: [{
                    data: data,
                    backgroundColor: [
                        '#3b82f6', '#10b981', '#f59e0b', '#ef4444', 
                        '#8b5cf6', '#06b6d4', '#84cc16', '#f97316'
                    ],
                    borderWidth: 2,
                    borderColor: '#ffffff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom'
                    }
                }
            }
        });
    }

    /**
     * Crée le graphique radar des paramètres
     */
    createParametersChart(parameterData) {
        const ctx = document.getElementById('parametersChart');
        if (!ctx) return;

        this.charts.parameters = new Chart(ctx, {
            type: 'radar',
            data: {
                labels: ['Paramètres totaux', 'Entrées', 'Sorties', 'Requis', 'Optionnels'],
                datasets: [{
                    label: 'Métriques des paramètres',
                    data: [
                        parameterData.totalInputs + parameterData.totalOutputs,
                        parameterData.totalInputs,
                        parameterData.totalOutputs,
                        parameterData.requiredParams,
                        parameterData.optionalParams
                    ],
                    backgroundColor: 'rgba(59, 130, 246, 0.2)',
                    borderColor: 'rgba(59, 130, 246, 1)',
                    pointBackgroundColor: 'rgba(59, 130, 246, 1)',
                    pointBorderColor: '#ffffff',
                    pointHoverBackgroundColor: '#ffffff',
                    pointHoverBorderColor: 'rgba(59, 130, 246, 1)',
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    }
                },
                scales: {
                    r: {
                        beginAtZero: true,
                        ticks: {
                            stepSize: 1
                        }
                    }
                }
            }
        });
    }

    /**
     * Génère le tableau des scripts complexes
     */
    renderComplexityTable(topComplex) {
        return `
            <div class="complexity-table">
                ${topComplex.map((script, index) => `
                    <div class="complexity-row">
                        <div class="complexity-rank">#${index + 1}</div>
                        <div class="complexity-info">
                            <div class="complexity-name">${script.name.replace('.sh', '')}</div>
                            <div class="complexity-category">${script.category}</div>
                        </div>
                        <div class="complexity-score">
                            <div class="complexity-bar-mini complexity-${this.getComplexityLevel(script.complexity)}">
                                <div class="complexity-fill-mini" style="width: ${(script.complexity / 10) * 100}%"></div>
                            </div>
                            <span class="complexity-value">${script.complexity}/10</span>
                        </div>
                    </div>
                `).join('')}
            </div>
        `;
    }

    /**
     * Génère le tableau des catégories
     */
    renderCategoryTable(categoryData) {
        return `
            <div class="category-table">
                ${categoryData.map(cat => `
                    <div class="category-row">
                        <div class="category-color" style="background-color: ${cat.color}"></div>
                        <div class="category-info">
                            <div class="category-name">${cat.name.charAt(0).toUpperCase() + cat.name.slice(1)}</div>
                            <div class="category-count">${cat.count} scripts</div>
                        </div>
                        <div class="category-percentage">${cat.percentage}%</div>
                    </div>
                `).join('')}
            </div>
        `;
    }

    /**
     * Génère des insights automatiques
     */
    generateInsights(stats) {
        const insights = [];
        
        // Analyse de la distribution des complexités
        if (stats.complexityDistribution.high > stats.totalScripts * 0.3) {
            insights.push({
                type: 'warning',
                icon: 'exclamation-triangle',
                title: 'Complexité élevée',
                message: `${stats.complexityDistribution.high} scripts ont une complexité élevée (>7/10). Considérez la documentation supplémentaire.`
            });
        }
        
        // Analyse de la répartition des catégories
        const dominantCategory = stats.categoryBreakdown.sort((a, b) => b.count - a.count)[0];
        if (dominantCategory.count > stats.totalScripts * 0.4) {
            insights.push({
                type: 'info',
                icon: 'info-circle',
                title: 'Catégorie dominante',
                message: `La catégorie "${dominantCategory.name}" représente ${dominantCategory.percentage}% des scripts. Équilibrage possible.`
            });
        }
        
        // Analyse des dépendances
        if (stats.totalDependencies === 0) {
            insights.push({
                type: 'success',
                icon: 'check-circle',
                title: 'Scripts autonomes',
                message: 'Excellente autonomie : aucune dépendance externe détectée dans les scripts.'
            });
        } else if (stats.totalDependencies > stats.totalScripts * 2) {
            insights.push({
                type: 'warning',
                icon: 'project-diagram',
                title: 'Dépendances nombreuses',
                message: `${stats.totalDependencies} dépendances détectées. Vérifiez la disponibilité sur les systèmes cibles.`
            });
        }
        
        // Analyse des paramètres
        const avgInputs = stats.parameterStats.totalInputs / stats.totalScripts;
        if (avgInputs > 3) {
            insights.push({
                type: 'info',
                icon: 'sliders-h',
                title: 'Scripts paramétrés',
                message: `Moyenne de ${avgInputs.toFixed(1)} paramètres par script. Bonne flexibilité d'utilisation.`
            });
        }
        
        return `
            <div class="insights-grid">
                ${insights.map(insight => `
                    <div class="insight-card insight-${insight.type}">
                        <div class="insight-icon">
                            <i class="fas fa-${insight.icon}"></i>
                        </div>
                        <div class="insight-content">
                            <h4 class="insight-title">${insight.title}</h4>
                            <p class="insight-message">${insight.message}</p>
                        </div>
                    </div>
                `).join('')}
            </div>
        `;
    }

    /**
     * Retourne le niveau de complexité
     */
    getComplexityLevel(complexity) {
        if (complexity <= 4) return 'low';
        if (complexity <= 7) return 'medium';
        return 'high';
    }

    /**
     * Redimensionne les graphiques
     */
    resizeCharts() {
        Object.values(this.charts).forEach(chart => {
            if (chart && typeof chart.resize === 'function') {
                chart.resize();
            }
        });
    }

    /**
     * Met à jour les données et recharge les graphiques
     */
    refreshAnalytics() {
        // Détruire les graphiques existants
        Object.values(this.charts).forEach(chart => {
            if (chart && typeof chart.destroy === 'function') {
                chart.destroy();
            }
        });
        
        this.charts = {};
        
        // Recréer le dashboard
        this.renderDashboard();
        this.createCharts();
    }
}

// Export pour utilisation globale
window.Analytics = Analytics;