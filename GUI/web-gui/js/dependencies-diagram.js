/**
 * ===========================
 * Diagramme de Dépendances - AtomicOps Suite
 * ===========================
 * 
 * Ce module génère et gère l'affichage du diagramme de dépendances
 * des scripts atomiques utilisant D3.js avec un layout de force
 */

class DependenciesDiagram {
    constructor(containerId, dataManager) {
        this.containerId = containerId;
        this.dataManager = dataManager;
        this.container = d3.select(`#${containerId}`);
        
        // Dimensions et marges
        this.margin = { top: 40, right: 40, bottom: 40, left: 40 };
        this.width = 0;
        this.height = 0;
        
        // Éléments SVG
        this.svg = null;
        this.g = null;
        this.tooltip = null;
        
        // Configuration du zoom
        this.zoom = null;
        this.currentTransform = d3.zoomIdentity;
        
        // Simulation de force
        this.simulation = null;
        this.nodes = [];
        this.links = [];
        
        // État du diagramme
        this.selectedNode = null;
        this.highlightedNodes = new Set();
        this.currentFilter = null;
        
        // Configuration visuelle
        this.nodeRadius = 25;
        this.linkDistance = 100;
        this.chargeStrength = -300;
        
        // Callbacks
        this.onNodeClick = null;
        this.onNodeHover = null;
        
        this.init();
    }

    /**
     * ===========================
     * Initialisation
     * ===========================
     */

    init() {
        this.setupDimensions();
        this.createSVG();
        this.setupZoom();
        this.createTooltip();
        this.setupControls();
        this.createLegend();
        
        // Écouter les changements de taille de fenêtre
        window.addEventListener('resize', () => this.handleResize());
        
        // Si les données sont déjà chargées, afficher le diagramme
        if (this.dataManager.isLoaded()) {
            this.render();
        } else {
            // Écouter le chargement des données
            this.dataManager.on('loaded', () => this.render());
        }
    }

    /**
     * Configure les dimensions du conteneur
     */
    setupDimensions() {
        const containerRect = document.getElementById(this.containerId).getBoundingClientRect();
        this.width = containerRect.width - this.margin.left - this.margin.right;
        this.height = containerRect.height - this.margin.top - this.margin.bottom;
        
        // Assurer des dimensions minimales
        this.width = Math.max(this.width, 800);
        this.height = Math.max(this.height, 600);
    }

    /**
     * Crée l'élément SVG principal
     */
    createSVG() {
        // Nettoyer le conteneur existant
        this.container.selectAll('svg').remove();

        this.svg = this.container
            .append('svg')
            .attr('width', '100%')
            .attr('height', '100%')
            .attr('viewBox', `0 0 ${this.width + this.margin.left + this.margin.right} ${this.height + this.margin.top + this.margin.bottom}`)
            .style('background', 'var(--bg-primary)');

        // Groupe principal avec marges
        this.g = this.svg
            .append('g')
            .attr('transform', `translate(${this.margin.left}, ${this.margin.top})`);

        // Définir les patterns pour les flèches
        this.createArrowMarkers();

        // Groupe pour les liens (en arrière-plan)
        this.g.append('g').attr('class', 'links');
        
        // Groupe pour les nœuds (au premier plan)
        this.g.append('g').attr('class', 'nodes');
    }

    /**
     * Crée les marqueurs de flèches pour les liens
     */
    createArrowMarkers() {
        const defs = this.svg.append('defs');

        // Flèche pour dépendances normales
        defs.append('marker')
            .attr('id', 'arrowhead')
            .attr('viewBox', '0 -5 10 10')
            .attr('refX', 8)
            .attr('refY', 0)
            .attr('markerWidth', 6)
            .attr('markerHeight', 6)
            .attr('orient', 'auto')
            .append('path')
            .attr('d', 'M0,-5L10,0L0,5')
            .style('fill', '#6b7280');

        // Flèche pour dépendances fortes
        defs.append('marker')
            .attr('id', 'arrowhead-strong')
            .attr('viewBox', '0 -5 10 10')
            .attr('refX', 8)
            .attr('refY', 0)
            .attr('markerWidth', 6)
            .attr('markerHeight', 6)
            .attr('orient', 'auto')
            .append('path')
            .attr('d', 'M0,-5L10,0L0,5')
            .style('fill', '#2563eb');
    }

    /**
     * Configure le système de zoom et de pan
     */
    setupZoom() {
        this.zoom = d3.zoom()
            .scaleExtent([0.1, 3])
            .on('zoom', (event) => {
                this.currentTransform = event.transform;
                this.g.attr('transform', 
                    `translate(${this.margin.left + event.transform.x}, ${this.margin.top + event.transform.y}) scale(${event.transform.k})`
                );
            });

        this.svg.call(this.zoom);
    }

    /**
     * Crée le tooltip pour les nœuds
     */
    createTooltip() {
        this.tooltip = d3.select('body')
            .append('div')
            .attr('class', 'diagram-tooltip')
            .style('opacity', 0);
    }

    /**
     * Configure les contrôles
     */
    setupControls() {
        const controlsContainer = this.container
            .append('div')
            .attr('class', 'zoom-controls');

        // Bouton zoom in
        controlsContainer
            .append('button')
            .attr('class', 'zoom-btn')
            .attr('title', 'Zoom avant')
            .html('<i class="fas fa-plus"></i>')
            .on('click', () => this.zoomIn());

        // Bouton zoom out
        controlsContainer
            .append('button')
            .attr('class', 'zoom-btn')
            .attr('title', 'Zoom arrière')
            .html('<i class="fas fa-minus"></i>')
            .on('click', () => this.zoomOut());

        // Bouton reset
        controlsContainer
            .append('button')
            .attr('class', 'zoom-btn')
            .attr('title', 'Réinitialiser')
            .html('<i class="fas fa-home"></i>')
            .on('click', () => this.resetView());

        // Bouton pause/play simulation
        controlsContainer
            .append('button')
            .attr('class', 'zoom-btn')
            .attr('title', 'Pause/Play simulation')
            .html('<i class="fas fa-pause"></i>')
            .on('click', () => this.toggleSimulation());
    }

    /**
     * Crée la légende du diagramme
     */
    createLegend() {
        const legend = this.container
            .append('div')
            .attr('class', 'diagram-legend');

        legend.append('div')
            .attr('class', 'legend-title')
            .text('Légende');

        const items = legend.append('div')
            .attr('class', 'legend-items');

        // Types de nœuds
        const nodeTypes = [
            { type: 'atomic', label: 'Script Atomique', color: '#2563eb' },
            { type: 'orchestrator', label: 'Orchestrateur', color: '#f59e0b' },
            { type: 'main', label: 'Script Principal', color: '#10b981' }
        ];

        nodeTypes.forEach(type => {
            const item = items.append('div')
                .attr('class', 'legend-item');
            
            item.append('div')
                .attr('class', `legend-color ${type.type}`)
                .style('background', type.color);
            
            item.append('span')
                .attr('class', 'legend-text')
                .text(type.label);
        });

        // Types de liens
        const linkItem = items.append('div')
            .attr('class', 'legend-item');
        
        linkItem.append('div')
            .attr('class', 'legend-color dependency');
        
        linkItem.append('span')
            .attr('class', 'legend-text')
            .text('Dépendance');
    }

    /**
     * ===========================
     * Rendu du Diagramme
     * ===========================
     */

    /**
     * Rend le diagramme complet
     */
    render(filter = null) {
        if (!this.dataManager.isLoaded()) {
            console.warn('Données non chargées pour le diagramme de dépendances');
            return;
        }

        this.currentFilter = filter;
        const graphData = this.dataManager.getDependencyGraph();
        
        // Filtrer si nécessaire
        if (filter) {
            this.filterGraphData(graphData, filter);
        }

        this.prepareData(graphData);
        this.setupSimulation();
        this.renderGraph();
    }

    /**
     * Filtre les données du graphe selon les critères
     */
    filterGraphData(graphData, filter) {
        if (filter.category) {
            graphData.nodes = graphData.nodes.filter(node => 
                node.category === filter.category
            );
            
            const nodeIds = new Set(graphData.nodes.map(n => n.id));
            graphData.links = graphData.links.filter(link => 
                nodeIds.has(link.source) && nodeIds.has(link.target)
            );
        }

        if (filter.level) {
            graphData.nodes = graphData.nodes.filter(node => 
                node.level === filter.level
            );
            
            const nodeIds = new Set(graphData.nodes.map(n => n.id));
            graphData.links = graphData.links.filter(link => 
                nodeIds.has(link.source) && nodeIds.has(link.target)
            );
        }

        if (filter.search) {
            const searchTerm = filter.search.toLowerCase();
            graphData.nodes = graphData.nodes.filter(node => 
                node.name.toLowerCase().includes(searchTerm) ||
                node.id.toLowerCase().includes(searchTerm)
            );
            
            const nodeIds = new Set(graphData.nodes.map(n => n.id));
            graphData.links = graphData.links.filter(link => 
                nodeIds.has(link.source) && nodeIds.has(link.target)
            );
        }
    }

    /**
     * Prépare les données pour D3
     */
    prepareData(graphData) {
        // Cloner les données pour éviter les mutations
        this.nodes = graphData.nodes.map(d => ({ ...d }));
        this.links = graphData.links.map(d => ({ ...d }));

        // Ajouter des propriétés visuelles aux nœuds
        this.nodes.forEach(node => {
            node.radius = this.getNodeRadius(node);
            node.color = this.getNodeColor(node);
            node.fx = null; // Position fixe X (null = libre)
            node.fy = null; // Position fixe Y (null = libre)
        });

        // Ajouter des propriétés aux liens
        this.links.forEach(link => {
            link.strength = link.strength || 0.5;
        });
    }

    /**
     * Configure la simulation de forces
     */
    setupSimulation() {
        // Arrêter l'ancienne simulation si elle existe
        if (this.simulation) {
            this.simulation.stop();
        }

        this.simulation = d3.forceSimulation(this.nodes)
            .force('link', d3.forceLink(this.links)
                .id(d => d.id)
                .distance(this.linkDistance)
                .strength(d => d.strength)
            )
            .force('charge', d3.forceManyBody()
                .strength(this.chargeStrength)
            )
            .force('center', d3.forceCenter(
                this.width / 2, 
                this.height / 2
            ))
            .force('collision', d3.forceCollide()
                .radius(d => d.radius + 5)
                .strength(0.7)
            )
            .force('x', d3.forceX(this.width / 2)
                .strength(0.1)
            )
            .force('y', d3.forceY(this.height / 2)
                .strength(0.1)
            );

        // Écouter les événements de simulation
        this.simulation.on('tick', () => this.updatePositions());
        this.simulation.on('end', () => this.onSimulationEnd());
    }

    /**
     * Rend les éléments graphiques
     */
    renderGraph() {
        this.renderLinks();
        this.renderNodes();
    }

    /**
     * Rend les liens
     */
    renderLinks() {
        const linkSelection = this.g.select('.links')
            .selectAll('.link')
            .data(this.links, d => `${d.source.id || d.source}-${d.target.id || d.target}`);

        // Supprimer les anciens liens
        linkSelection.exit().remove();

        // Créer les nouveaux liens
        const linkEnter = linkSelection.enter()
            .append('line')
            .attr('class', d => `link ${d.type || 'dependency'}`)
            .attr('marker-end', d => d.strength > 0.7 ? 'url(#arrowhead-strong)' : 'url(#arrowhead)')
            .style('stroke-width', d => Math.max(1, d.strength * 4))
            .style('opacity', 0);

        // Fusionner avec les liens existants
        this.linkUpdate = linkEnter.merge(linkSelection);

        // Animer l'apparition
        this.linkUpdate
            .transition()
            .duration(500)
            .style('opacity', 0.6);
    }

    /**
     * Rend les nœuds
     */
    renderNodes() {
        const nodeSelection = this.g.select('.nodes')
            .selectAll('.node')
            .data(this.nodes, d => d.id);

        // Supprimer les anciens nœuds
        nodeSelection.exit()
            .transition()
            .duration(300)
            .style('opacity', 0)
            .remove();

        // Créer les nouveaux nœuds
        const nodeEnter = nodeSelection.enter()
            .append('g')
            .attr('class', d => `node ${d.type} ${d.level}`)
            .style('opacity', 0)
            .call(this.createDragBehavior())
            .on('click', (event, d) => this.handleNodeClick(event, d))
            .on('mouseenter', (event, d) => this.handleNodeMouseEnter(event, d))
            .on('mouseleave', (event, d) => this.handleNodeMouseLeave(event, d))
            .on('dblclick', (event, d) => this.handleNodeDoubleClick(event, d));

        // Ajouter le cercle principal
        nodeEnter
            .append('circle')
            .attr('r', d => d.radius)
            .style('fill', d => d.color)
            .style('stroke', '#ffffff')
            .style('stroke-width', 2);

        // Ajouter l'icône
        nodeEnter
            .append('text')
            .attr('class', 'node-icon')
            .attr('text-anchor', 'middle')
            .attr('dominant-baseline', 'central')
            .style('font-family', 'Font Awesome 5 Free')
            .style('font-weight', '900')
            .style('font-size', d => Math.max(12, d.radius * 0.6) + 'px')
            .style('fill', '#ffffff')
            .text(d => this.getNodeIcon(d))
            .style('pointer-events', 'none');

        // Ajouter le label
        nodeEnter
            .append('text')
            .attr('class', 'node-label')
            .attr('text-anchor', 'middle')
            .attr('dy', d => d.radius + 16)
            .style('font-size', '12px')
            .style('font-weight', '500')
            .style('fill', 'var(--text-primary)')
            .text(d => this.truncateText(d.name, 15))
            .style('pointer-events', 'none');

        // Ajouter les badges
        this.addNodeBadges(nodeEnter);

        // Fusionner avec les nœuds existants
        this.nodeUpdate = nodeEnter.merge(nodeSelection);

        // Animer l'apparition
        this.nodeUpdate
            .transition()
            .duration(500)
            .style('opacity', 1);
    }

    /**
     * Ajoute des badges aux nœuds
     */
    addNodeBadges(nodeEnter) {
        // Badge de complexité
        nodeEnter
            .filter(d => d.complexity)
            .append('circle')
            .attr('class', 'complexity-badge')
            .attr('cx', d => d.radius * 0.7)
            .attr('cy', d => -d.radius * 0.7)
            .attr('r', 6)
            .style('fill', d => this.getComplexityColor(d.complexity))
            .style('stroke', '#ffffff')
            .style('stroke-width', 1);

        // Badge de statut
        nodeEnter
            .filter(d => d.status && d.status !== 'stable')
            .append('circle')
            .attr('class', 'status-badge')
            .attr('cx', d => -d.radius * 0.7)
            .attr('cy', d => -d.radius * 0.7)
            .attr('r', 4)
            .style('fill', d => this.getStatusColor(d.status))
            .style('stroke', '#ffffff')
            .style('stroke-width', 1);
    }

    /**
     * ===========================
     * Comportements d'Interaction
     * ===========================
     */

    /**
     * Crée le comportement de drag pour les nœuds
     */
    createDragBehavior() {
        return d3.drag()
            .on('start', (event, d) => {
                if (!event.active) this.simulation.alphaTarget(0.3).restart();
                d.fx = d.x;
                d.fy = d.y;
            })
            .on('drag', (event, d) => {
                d.fx = event.x;
                d.fy = event.y;
            })
            .on('end', (event, d) => {
                if (!event.active) this.simulation.alphaTarget(0);
                // Laisser le nœud libre ou le fixer selon les préférences
                // d.fx = null;
                // d.fy = null;
            });
    }

    /**
     * Gère le clic sur un nœud
     */
    handleNodeClick(event, d) {
        event.stopPropagation();
        
        // Mettre à jour la sélection
        if (this.selectedNode === d) {
            this.selectedNode = null;
        } else {
            this.selectedNode = d;
        }
        
        // Mettre à jour visuellement
        this.updateNodeSelection();
        
        // Highlight des dépendances
        this.highlightDependencies(d);

        // Callback personnalisé
        if (this.onNodeClick) {
            this.onNodeClick(d, event);
        }
    }

    /**
     * Gère l'entrée de souris sur un nœud
     */
    handleNodeMouseEnter(event, d) {
        this.showTooltip(event, d);
        
        // Mettre en surbrillance temporaire
        this.highlightNode(d, true);

        // Callback personnalisé
        if (this.onNodeHover) {
            this.onNodeHover(d, event);
        }
    }

    /**
     * Gère la sortie de souris d'un nœud
     */
    handleNodeMouseLeave(event, d) {
        this.hideTooltip();
        
        // Enlever la surbrillance temporaire
        if (this.selectedNode !== d) {
            this.highlightNode(d, false);
        }
    }

    /**
     * Gère le double-clic sur un nœud
     */
    handleNodeDoubleClick(event, d) {
        event.stopPropagation();
        
        // Centrer la vue sur le nœud
        this.centerOnNode(d);
        
        // Fixer/libérer le nœud
        if (d.fx !== null || d.fy !== null) {
            d.fx = null;
            d.fy = null;
        } else {
            d.fx = d.x;
            d.fy = d.y;
        }
    }

    /**
     * ===========================
     * Mise à Jour et Animation
     * ===========================
     */

    /**
     * Met à jour les positions lors de la simulation
     */
    updatePositions() {
        if (this.linkUpdate) {
            this.linkUpdate
                .attr('x1', d => d.source.x)
                .attr('y1', d => d.source.y)
                .attr('x2', d => d.target.x)
                .attr('y2', d => d.target.y);
        }

        if (this.nodeUpdate) {
            this.nodeUpdate
                .attr('transform', d => `translate(${d.x}, ${d.y})`);
        }
    }

    /**
     * Met à jour la sélection des nœuds
     */
    updateNodeSelection() {
        this.g.selectAll('.node')
            .classed('selected', d => d === this.selectedNode);
    }

    /**
     * Met en surbrillance les dépendances d'un nœud
     */
    highlightDependencies(node) {
        const connectedNodes = new Set();
        const connectedLinks = new Set();

        // Trouver tous les nœuds et liens connectés
        this.links.forEach(link => {
            if (link.source === node || link.source.id === node.id) {
                connectedNodes.add(link.target.id || link.target);
                connectedLinks.add(link);
            }
            if (link.target === node || link.target.id === node.id) {
                connectedNodes.add(link.source.id || link.source);
                connectedLinks.add(link);
            }
        });

        // Appliquer les styles
        this.g.selectAll('.node')
            .classed('highlighted', d => d === node)
            .classed('connected', d => connectedNodes.has(d.id))
            .classed('faded', d => d !== node && !connectedNodes.has(d.id));

        this.g.selectAll('.link')
            .classed('highlighted', l => connectedLinks.has(l))
            .classed('faded', l => !connectedLinks.has(l));
    }

    /**
     * Met en surbrillance un nœud spécifique
     */
    highlightNode(node, highlight) {
        this.g.select(`[data-id="${node.id}"]`)
            .classed('hover', highlight);
    }

    /**
     * ===========================
     * Contrôles de Vue
     * ===========================
     */

    zoomIn() {
        this.svg
            .transition()
            .duration(300)
            .call(this.zoom.scaleBy, 1.5);
    }

    zoomOut() {
        this.svg
            .transition()
            .duration(300)
            .call(this.zoom.scaleBy, 1 / 1.5);
    }

    resetView() {
        this.svg
            .transition()
            .duration(750)
            .call(this.zoom.transform, d3.zoomIdentity);
        
        // Redémarrer la simulation
        if (this.simulation) {
            this.simulation.alpha(0.3).restart();
        }
    }

    centerOnNode(node) {
        const scale = 1.5;
        const x = -node.x * scale + this.width / 2;
        const y = -node.y * scale + this.height / 2;
        
        this.svg
            .transition()
            .duration(750)
            .call(
                this.zoom.transform,
                d3.zoomIdentity.translate(x, y).scale(scale)
            );
    }

    toggleSimulation() {
        if (this.simulation) {
            const isRunning = this.simulation.alpha() > 0;
            
            if (isRunning) {
                this.simulation.stop();
                this.container.select('.zoom-controls .fa-pause')
                    .attr('class', 'fas fa-play');
            } else {
                this.simulation.alpha(0.3).restart();
                this.container.select('.zoom-controls .fa-play')
                    .attr('class', 'fas fa-pause');
            }
        }
    }

    /**
     * ===========================
     * Tooltip et Utilitaires
     * ===========================
     */

    /**
     * Affiche le tooltip
     */
    showTooltip(event, d) {
        const tooltipContent = this.createTooltipContent(d);
        
        this.tooltip
            .html(tooltipContent)
            .style('opacity', 1)
            .style('left', (event.pageX + 10) + 'px')
            .style('top', (event.pageY - 10) + 'px')
            .classed('visible', true);
    }

    /**
     * Cache le tooltip
     */
    hideTooltip() {
        this.tooltip
            .style('opacity', 0)
            .classed('visible', false);
    }

    /**
     * Crée le contenu du tooltip
     */
    createTooltipContent(data) {
        const script = this.dataManager.getScript(data.id);
        
        let content = `<div class="tooltip-title">${data.name}</div>`;
        
        if (script && script.description) {
            content += `<div class="tooltip-description">${script.description}</div>`;
        }
        
        content += '<div class="tooltip-meta">';
        
        content += `<span><i class="fas fa-layer-group"></i> ${data.level}</span>`;
        
        if (data.complexity) {
            content += `<span><i class="fas fa-cog"></i> ${data.complexity}</span>`;
        }
        
        // Compter les dépendances
        const dependencies = this.dataManager.getDependencies(data.id);
        const dependents = this.dataManager.getDependents(data.id);
        
        if (dependencies.length > 0) {
            content += `<span><i class="fas fa-arrow-right"></i> ${dependencies.length} dép.</span>`;
        }
        
        if (dependents.length > 0) {
            content += `<span><i class="fas fa-arrow-left"></i> ${dependents.length} usage</span>`;
        }
        
        content += '</div>';
        
        return content;
    }

    /**
     * ===========================
     * Fonctions Utilitaires
     * ===========================
     */

    /**
     * Retourne la taille appropriée pour un nœud
     */
    getNodeRadius(node) {
        const baseRadius = this.nodeRadius;
        const dependencies = this.dataManager.getDependencies(node.id);
        const dependents = this.dataManager.getDependents(node.id);
        
        // Ajuster selon le nombre de connexions
        const connections = dependencies.length + dependents.length;
        return baseRadius + Math.min(connections * 2, 15);
    }

    /**
     * Retourne la couleur appropriée pour un nœud
     */
    getNodeColor(node) {
        const colors = {
            'atomic': '#2563eb',      // bleu
            'orchestrator': '#f59e0b', // orange
            'main': '#10b981'         // vert
        };
        return colors[node.level] || '#6b7280';
    }

    /**
     * Retourne l'icône appropriée pour un nœud
     */
    getNodeIcon(node) {
        const icons = {
            'atomic': '\\uf1b2',      // cube
            'orchestrator': '\\uf013', // cogs
            'main': '\\uf135'         // rocket
        };
        return icons[node.level] || '\\uf15b';
    }

    /**
     * Retourne la couleur de complexité
     */
    getComplexityColor(complexity) {
        const colors = {
            'low': '#10b981',     // vert
            'medium': '#f59e0b',  // orange
            'high': '#ef4444'     // rouge
        };
        return colors[complexity] || '#6b7280';
    }

    /**
     * Retourne la couleur de statut
     */
    getStatusColor(status) {
        const colors = {
            'stable': '#10b981',    // vert
            'testing': '#f59e0b',   // orange
            'deprecated': '#ef4444', // rouge
            'draft': '#6b7280'      // gris
        };
        return colors[status] || '#6b7280';
    }

    /**
     * Tronque un texte
     */
    truncateText(text, maxLength) {
        if (!text) return '';
        return text.length <= maxLength ? text : text.substring(0, maxLength - 3) + '...';
    }

    /**
     * Gère le redimensionnement
     */
    handleResize() {
        this.setupDimensions();
        this.svg.attr('viewBox', `0 0 ${this.width + this.margin.left + this.margin.right} ${this.height + this.margin.top + this.margin.bottom}`);
        
        // Ajuster les forces de simulation
        if (this.simulation) {
            this.simulation
                .force('center', d3.forceCenter(this.width / 2, this.height / 2))
                .force('x', d3.forceX(this.width / 2).strength(0.1))
                .force('y', d3.forceY(this.height / 2).strength(0.1))
                .alpha(0.3)
                .restart();
        }
    }

    /**
     * Appelée quand la simulation se termine
     */
    onSimulationEnd() {
        console.log('Simulation de forces terminée');
        
        // Changer l'icône de pause en play
        this.container.select('.zoom-controls .fa-pause')
            .attr('class', 'fas fa-play');
    }

    /**
     * ===========================
     * API Publique
     * ===========================
     */

    /**
     * Filtre le diagramme
     */
    filterDiagram(filters) {
        this.render(filters);
    }

    /**
     * Supprime les filtres
     */
    clearFilter() {
        this.render();
    }

    /**
     * Supprime toute mise en surbrillance
     */
    clearHighlight() {
        this.g.selectAll('.node')
            .classed('highlighted', false)
            .classed('connected', false)
            .classed('faded', false);

        this.g.selectAll('.link')
            .classed('highlighted', false)
            .classed('faded', false);
    }

    /**
     * Définit les callbacks
     */
    setOnNodeClick(callback) {
        this.onNodeClick = callback;
    }

    setOnNodeHover(callback) {
        this.onNodeHover = callback;
    }

    /**
     * Nettoie les ressources
     */
    destroy() {
        if (this.simulation) {
            this.simulation.stop();
        }
        
        if (this.tooltip) {
            this.tooltip.remove();
        }
        
        window.removeEventListener('resize', this.handleResize);
        
        this.container.selectAll('*').remove();
    }
}

// Export pour utilisation
window.DependenciesDiagram = DependenciesDiagram;