/**
 * AtomicOps-Suite - Visualisation hiérarchique
 * Gère les différents types de diagrammes (arbre, réseau, circulaire)
 */

class HierarchyVisualization {
    constructor(containerId, dataParser) {
        this.container = d3.select(`#${containerId}`);
        this.dataParser = dataParser;
        this.currentView = 'tree';
        this.selectedNode = null;
        this.simulation = null;
        this.init();
    }

    /**
     * Initialise la visualisation
     */
    init() {
        this.setupContainer();
        this.renderTreeView();
    }

    /**
     * Configure le conteneur SVG
     */
    setupContainer() {
        // Nettoyer le conteneur existant
        this.container.selectAll('*').remove();
        
        // Créer le SVG principal
        const containerRect = this.container.node().getBoundingClientRect();
        this.width = containerRect.width - 40;
        this.height = containerRect.height - 40;
        
        this.svg = this.container.append('svg')
            .attr('width', this.width)
            .attr('height', this.height)
            .attr('id', 'hierarchyViz');

        // Groupe principal avec zoom/pan
        this.g = this.svg.append('g');
        
        // Configuration du zoom
        this.zoom = d3.zoom()
            .scaleExtent([0.1, 3])
            .on('zoom', (event) => {
                this.g.attr('transform', event.transform);
            });
            
        this.svg.call(this.zoom);
        
        // Tooltip
        this.tooltip = d3.select('body').append('div')
            .attr('class', 'tooltip')
            .style('opacity', 0);
    }

    /**
     * Vue en arbre hiérarchique
     */
    renderTreeView() {
        this.currentView = 'tree';
        this.g.selectAll('*').remove();

        // Données organisées par catégories
        const categories = this.dataParser.getCategories();
        const treeData = {
            name: 'AtomicOps-Suite',
            category: 'root',
            children: categories.map(cat => ({
                name: cat.name,
                category: cat.name,
                color: cat.color,
                description: cat.description,
                children: cat.scripts.map(scriptName => ({
                    name: scriptName,
                    category: cat.name,
                    data: this.dataParser.getScript(scriptName),
                    isLeaf: true
                }))
            }))
        };

        // Configuration de l'arbre
        const treeLayout = d3.tree()
            .size([this.height - 100, this.width - 200]);

        const hierarchy = d3.hierarchy(treeData);
        treeLayout(hierarchy);

        // Liens
        this.g.selectAll('.link')
            .data(hierarchy.descendants().slice(1))
            .enter().append('path')
            .attr('class', 'link hierarchy')
            .attr('d', d => {
                return `M${d.y},${d.x}C${(d.y + d.parent.y) / 2},${d.x} ${(d.y + d.parent.y) / 2},${d.parent.x} ${d.parent.y},${d.parent.x}`;
            });

        // Nœuds
        const nodes = this.g.selectAll('.node')
            .data(hierarchy.descendants())
            .enter().append('g')
            .attr('class', 'node')
            .attr('transform', d => `translate(${d.y},${d.x})`)
            .style('cursor', 'pointer')
            .on('click', (event, d) => this.onNodeClick(event, d))
            .on('mouseover', (event, d) => this.showTooltip(event, d))
            .on('mouseout', () => this.hideTooltip());

        // Cercles des nœuds
        nodes.append('circle')
            .attr('r', d => {
                if (d.depth === 0) return 12; // Root
                if (d.depth === 1) return 10; // Categories
                return 8; // Scripts
            })
            .style('fill', d => {
                if (d.depth === 0) return '#1e3a8a';
                if (d.depth === 1) return d.data.color || '#3b82f6';
                return this.getComplexityColor(d.data.data?.complexity || 5);
            })
            .style('stroke', '#fff')
            .style('stroke-width', 2);

        // Labels des nœuds
        nodes.append('text')
            .attr('dy', d => d.depth === 0 ? -20 : (d.children ? -15 : 15))
            .attr('text-anchor', 'middle')
            .style('font-size', d => d.depth === 0 ? '14px' : '11px')
            .style('font-weight', d => d.depth <= 1 ? 'bold' : 'normal')
            .text(d => {
                if (d.depth <= 1) return d.data.name;
                return d.data.name.replace('.sh', '');
            });

        // Centrer la vue
        this.centerView();
    }

    /**
     * Vue en réseau de dépendances
     */
    renderNetworkView() {
        this.currentView = 'network';
        this.g.selectAll('*').remove();

        const scripts = this.dataParser.getAllScripts();
        const dependencies = this.dataParser.getDependencyGraph();
        
        // Création des nœuds
        const nodes = scripts.map(script => ({
            id: script.name,
            name: script.name.replace('.sh', ''),
            category: script.category,
            complexity: script.complexity,
            data: script,
            radius: 8 + script.complexity
        }));

        // Création des liens de dépendances
        const links = [];
        dependencies.forEach((deps, scriptName) => {
            deps.forEach(depName => {
                if (scripts.find(s => s.name === depName)) {
                    links.push({
                        source: scriptName,
                        target: depName,
                        type: 'dependency'
                    });
                }
            });
        });

        // Configuration de la simulation de forces
        this.simulation = d3.forceSimulation(nodes)
            .force('link', d3.forceLink(links).id(d => d.id).distance(100))
            .force('charge', d3.forceManyBody().strength(-300))
            .force('center', d3.forceCenter(this.width / 2, this.height / 2))
            .force('collision', d3.forceCollide().radius(d => d.radius + 5));

        // Liens
        const link = this.g.selectAll('.link')
            .data(links)
            .enter().append('line')
            .attr('class', 'link dependency')
            .style('stroke-width', 2);

        // Nœuds
        const node = this.g.selectAll('.node')
            .data(nodes)
            .enter().append('g')
            .attr('class', 'node')
            .style('cursor', 'pointer')
            .call(d3.drag()
                .on('start', (event, d) => this.dragstarted(event, d))
                .on('drag', (event, d) => this.dragged(event, d))
                .on('end', (event, d) => this.dragended(event, d)))
            .on('click', (event, d) => this.onNodeClick(event, d))
            .on('mouseover', (event, d) => this.showTooltip(event, d))
            .on('mouseout', () => this.hideTooltip());

        // Cercles des nœuds
        node.append('circle')
            .attr('r', d => d.radius)
            .style('fill', d => this.getCategoryColor(d.category))
            .style('stroke', '#fff')
            .style('stroke-width', 2);

        // Labels
        node.append('text')
            .attr('dy', -15)
            .attr('text-anchor', 'middle')
            .style('font-size', '10px')
            .style('pointer-events', 'none')
            .text(d => d.name);

        // Animation de la simulation
        this.simulation.on('tick', () => {
            link
                .attr('x1', d => d.source.x)
                .attr('y1', d => d.source.y)
                .attr('x2', d => d.target.x)
                .attr('y2', d => d.target.y);

            node.attr('transform', d => `translate(${d.x},${d.y})`);
        });
    }

    /**
     * Vue circulaire (sunburst)
     */
    renderCircularView() {
        this.currentView = 'circular';
        this.g.selectAll('*').remove();

        const categories = this.dataParser.getCategories();
        const radius = Math.min(this.width, this.height) / 2 - 50;

        // Données hiérarchiques pour le sunburst
        const data = {
            name: 'AtomicOps',
            children: categories.map(cat => ({
                name: cat.name,
                category: cat.name,
                color: cat.color,
                children: cat.scripts.map(scriptName => {
                    const script = this.dataParser.getScript(scriptName);
                    return {
                        name: scriptName,
                        value: script.complexity,
                        data: script,
                        category: cat.name
                    };
                })
            }))
        };

        // Configuration de la partition
        const partition = d3.partition()
            .size([2 * Math.PI, radius]);

        const hierarchy = d3.hierarchy(data)
            .sum(d => d.value || 1);
        
        partition(hierarchy);

        // Générateur d'arc
        const arc = d3.arc()
            .startAngle(d => d.x0)
            .endAngle(d => d.x1)
            .innerRadius(d => d.y0)
            .outerRadius(d => d.y1);

        // Groupe centré
        const g = this.g.append('g')
            .attr('transform', `translate(${this.width / 2},${this.height / 2})`);

        // Segments
        const segments = g.selectAll('path')
            .data(hierarchy.descendants())
            .enter().append('path')
            .attr('d', arc)
            .style('fill', d => {
                if (d.depth === 0) return '#1e3a8a';
                if (d.depth === 1) return d.data.color || '#3b82f6';
                return this.getComplexityColor(d.data.value || 5);
            })
            .style('stroke', '#fff')
            .style('stroke-width', 2)
            .style('cursor', 'pointer')
            .on('click', (event, d) => this.onNodeClick(event, d))
            .on('mouseover', (event, d) => this.showTooltip(event, d))
            .on('mouseout', () => this.hideTooltip());

        // Labels pour les catégories principales
        g.selectAll('text')
            .data(hierarchy.descendants().filter(d => d.depth === 1))
            .enter().append('text')
            .attr('transform', d => {
                const angle = (d.x0 + d.x1) / 2;
                const radius = (d.y0 + d.y1) / 2;
                return `rotate(${angle * 180 / Math.PI - 90}) translate(${radius}) rotate(${angle > Math.PI ? 180 : 0})`;
            })
            .attr('text-anchor', 'middle')
            .style('font-size', '11px')
            .style('font-weight', 'bold')
            .style('pointer-events', 'none')
            .text(d => d.data.name);
    }

    /**
     * Change la vue de visualisation
     */
    changeView(viewType) {
        if (this.simulation) {
            this.simulation.stop();
            this.simulation = null;
        }

        switch (viewType) {
            case 'tree':
                this.renderTreeView();
                break;
            case 'network':
                this.renderNetworkView();
                break;
            case 'circular':
                this.renderCircularView();
                break;
        }

        // Mise à jour des boutons de vue
        document.querySelectorAll('.view-btn').forEach(btn => {
            btn.classList.remove('active');
            btn.classList.add('bg-gray-300', 'text-gray-700');
            btn.classList.remove('bg-blue-500', 'text-white');
        });

        const activeBtn = document.getElementById(viewType + 'View');
        if (activeBtn) {
            activeBtn.classList.add('active');
            activeBtn.classList.remove('bg-gray-300', 'text-gray-700');
            activeBtn.classList.add('bg-blue-500', 'text-white');
        }
    }

    /**
     * Gestionnaire de clic sur un nœud
     */
    onNodeClick(event, d) {
        event.stopPropagation();
        
        this.selectedNode = d;
        
        // Mise à jour visuelle de la sélection
        this.g.selectAll('.node circle')
            .classed('selected', false);
        
        d3.select(event.currentTarget)
            .select('circle')
            .classed('selected', true);

        // Émettre un événement personnalisé
        const scriptData = d.data.data || d.data;
        if (scriptData && scriptData.name) {
            window.dispatchEvent(new CustomEvent('scriptSelected', {
                detail: { script: scriptData }
            }));
        }
    }

    /**
     * Affiche le tooltip
     */
    showTooltip(event, d) {
        const data = d.data.data || d.data;
        let content = `<strong>${d.data.name}</strong>`;
        
        if (data.description) {
            content += `<br/><span style="color: #ccc;">${data.description}</span>`;
        }
        
        if (data.complexity) {
            content += `<br/>Complexité: ${data.complexity}/10`;
        }
        
        if (data.category) {
            content += `<br/>Catégorie: ${data.category}`;
        }

        this.tooltip.transition()
            .duration(200)
            .style('opacity', .9);
            
        this.tooltip.html(content)
            .style('left', (event.pageX + 10) + 'px')
            .style('top', (event.pageY - 28) + 'px');
    }

    /**
     * Cache le tooltip
     */
    hideTooltip() {
        this.tooltip.transition()
            .duration(500)
            .style('opacity', 0);
    }

    /**
     * Centre la vue sur le contenu
     */
    centerView() {
        const bounds = this.g.node().getBBox();
        const fullWidth = this.width;
        const fullHeight = this.height;
        const width = bounds.width;
        const height = bounds.height;
        const midX = bounds.x + width / 2;
        const midY = bounds.y + height / 2;

        if (width === 0 || height === 0) return;

        const scale = Math.min(fullWidth / width, fullHeight / height) * 0.8;
        const translate = [fullWidth / 2 - scale * midX, fullHeight / 2 - scale * midY];

        this.svg.transition()
            .duration(750)
            .call(this.zoom.transform, d3.zoomIdentity.translate(translate[0], translate[1]).scale(scale));
    }

    /**
     * Gestion du drag pour la vue réseau
     */
    dragstarted(event, d) {
        if (!event.active && this.simulation) {
            this.simulation.alphaTarget(0.3).restart();
        }
        d.fx = d.x;
        d.fy = d.y;
    }

    dragged(event, d) {
        d.fx = event.x;
        d.fy = event.y;
    }

    dragended(event, d) {
        if (!event.active && this.simulation) {
            this.simulation.alphaTarget(0);
        }
        d.fx = null;
        d.fy = null;
    }

    /**
     * Retourne une couleur basée sur la complexité
     */
    getComplexityColor(complexity) {
        const colors = {
            low: '#10b981',    // Vert - complexité 1-4
            medium: '#f59e0b', // Orange - complexité 5-7
            high: '#ef4444'    // Rouge - complexité 8-10
        };

        if (complexity <= 4) return colors.low;
        if (complexity <= 7) return colors.medium;
        return colors.high;
    }

    /**
     * Retourne une couleur basée sur la catégorie
     */
    getCategoryColor(category) {
        const categoryColors = {
            'restore': '#3b82f6',
            'security': '#ef4444',
            'configuration': '#10b981',
            'network': '#8b5cf6',
            'notification': '#f59e0b',
            'maintenance': '#06b6d4',
            'testing': '#84cc16',
            'scheduling': '#f97316',
            'search': '#6366f1'
        };

        return categoryColors[category] || '#6b7280';
    }

    /**
     * Met à jour la taille lors du redimensionnement
     */
    resize() {
        const containerRect = this.container.node().getBoundingClientRect();
        this.width = containerRect.width - 40;
        this.height = containerRect.height - 40;
        
        this.svg
            .attr('width', this.width)
            .attr('height', this.height);

        // Re-render la vue actuelle
        this.changeView(this.currentView);
    }

    /**
     * Filtre la visualisation selon les critères
     */
    filterVisualization(filters) {
        // Implémentation du filtrage selon les catégories sélectionnées
        const visibleCategories = filters.categories || [];
        
        if (visibleCategories.length === 0 || visibleCategories.includes('all')) {
            // Afficher tous les éléments
            this.g.selectAll('.node').style('opacity', 1);
            this.g.selectAll('.link').style('opacity', 1);
        } else {
            // Filtrer selon les catégories
            this.g.selectAll('.node')
                .style('opacity', d => {
                    const category = d.data?.category || d.category;
                    return visibleCategories.includes(category) ? 1 : 0.2;
                });
                
            this.g.selectAll('.link')
                .style('opacity', 0.6);
        }
    }
}

// Export pour utilisation globale
window.HierarchyVisualization = HierarchyVisualization;