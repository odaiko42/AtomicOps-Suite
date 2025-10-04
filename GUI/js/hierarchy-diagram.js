/**
 * ===========================
 * Diagramme Hiérarchique - AtomicOps Suite
 * ===========================
 * 
 * Ce module génère et gère l'affichage du diagramme hiérarchique
 * des scripts atomiques utilisant D3.js
 */

class HierarchyDiagram {
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
        
        // État du diagramme
        this.currentData = null;
        this.selectedNode = null;
        this.expandedNodes = new Set();
        
        // Configuration de l'arbre
        this.treeLayout = null;
        this.nodeHeight = 60;
        this.nodeWidth = 180;
        this.levelHeight = 120;
        
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
        this.container.selectAll('*').remove();

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

        // Groupe pour les liens (en arrière-plan)
        this.g.append('g').attr('class', 'links');
        
        // Groupe pour les nœuds (au premier plan)
        this.g.append('g').attr('class', 'nodes');
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
     * Configure les contrôles de zoom
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
            .attr('title', 'Réinitialiser le zoom')
            .html('<i class="fas fa-home"></i>')
            .on('click', () => this.resetZoom());
    }

    /**
     * ===========================
     * Rendu du Diagramme
     * ===========================
     */

    /**
     * Rend le diagramme complet
     */
    render() {
        if (!this.dataManager.isLoaded()) {
            console.warn('Données non chargées pour le diagramme hiérarchique');
            return;
        }

        this.currentData = this.dataManager.getHierarchy();
        this.setupTreeLayout();
        this.renderTree();
        this.centerDiagram();
    }

    /**
     * Configure le layout de l'arbre
     */
    setupTreeLayout() {
        this.treeLayout = d3.tree()
            .size([this.width, this.height])
            .separation((a, b) => {
                // Plus d'espacement entre les nœuds de différentes branches
                return a.parent === b.parent ? 1 : 2;
            });
    }

    /**
     * Rend l'arbre hiérarchique
     */
    renderTree() {
        // Créer la hiérarchie D3
        const root = d3.hierarchy(this.currentData);
        
        // Appliquer le layout
        this.treeLayout(root);

        // Ajuster les positions pour un meilleur espacement
        this.adjustNodePositions(root);

        // Rendre les liens
        this.renderLinks(root.links());
        
        // Rendre les nœuds
        this.renderNodes(root.descendants());
    }

    /**
     * Ajuste les positions des nœuds pour un meilleur rendu
     */
    adjustNodePositions(root) {
        root.descendants().forEach(d => {
            // Ajuster l'espacement vertical selon le niveau
            d.y = d.depth * this.levelHeight;
            
            // Ajuster l'espacement horizontal pour éviter les chevauchements
            if (d.children) {
                const totalWidth = d.children.length * this.nodeWidth;
                const startX = d.x - totalWidth / 2;
                d.children.forEach((child, i) => {
                    child.x = startX + (i + 0.5) * this.nodeWidth;
                });
            }
        });
    }

    /**
     * Rend les liens entre les nœuds
     */
    renderLinks(links) {
        const linkSelection = this.g.select('.links')
            .selectAll('.link')
            .data(links, d => `${d.source.data.name}-${d.target.data.name}`);

        // Supprimer les anciens liens
        linkSelection.exit().remove();

        // Créer les nouveaux liens
        const linkEnter = linkSelection.enter()
            .append('path')
            .attr('class', 'link')
            .style('opacity', 0);

        // Fusionner avec les liens existants
        const linkUpdate = linkEnter.merge(linkSelection);

        // Animer les liens
        linkUpdate
            .transition()
            .duration(750)
            .style('opacity', 1)
            .attr('d', this.createLinkPath.bind(this));
    }

    /**
     * Crée le chemin d'un lien
     */
    createLinkPath(d) {
        const source = d.source;
        const target = d.target;
        
        // Créer une courbe de Bézier cubique
        return `M ${source.x} ${source.y + this.nodeHeight / 2}
                C ${source.x} ${(source.y + target.y) / 2},
                  ${target.x} ${(source.y + target.y) / 2},
                  ${target.x} ${target.y - this.nodeHeight / 2}`;
    }

    /**
     * Rend les nœuds
     */
    renderNodes(nodes) {
        const nodeSelection = this.g.select('.nodes')
            .selectAll('.node')
            .data(nodes, d => d.data.name || d.data.id);

        // Supprimer les anciens nœuds
        nodeSelection.exit()
            .transition()
            .duration(500)
            .style('opacity', 0)
            .remove();

        // Créer les nouveaux nœuds
        const nodeEnter = nodeSelection.enter()
            .append('g')
            .attr('class', d => `node ${d.data.type} ${d.data.level || ''}`)
            .style('opacity', 0)
            .on('click', (event, d) => this.handleNodeClick(event, d))
            .on('mouseenter', (event, d) => this.showTooltip(event, d))
            .on('mouseleave', () => this.hideTooltip());

        // Ajouter le rectangle du nœud
        nodeEnter
            .append('rect')
            .attr('width', this.nodeWidth)
            .attr('height', this.nodeHeight)
            .attr('x', -this.nodeWidth / 2)
            .attr('y', -this.nodeHeight / 2)
            .attr('rx', 8)
            .attr('ry', 8);

        // Ajouter l'icône
        nodeEnter
            .append('text')
            .attr('class', 'node-icon')
            .attr('x', -this.nodeWidth / 2 + 16)
            .attr('y', -8)
            .style('font-family', 'Font Awesome 5 Free')
            .style('font-weight', '900')
            .style('font-size', '16px')
            .text(d => this.getNodeIcon(d.data));

        // Ajouter le titre principal
        nodeEnter
            .append('text')
            .attr('class', 'node-label')
            .attr('x', -this.nodeWidth / 2 + 40)
            .attr('y', -8)
            .style('font-weight', '600')
            .style('font-size', '13px')
            .text(d => this.truncateText(d.data.name, 18));

        // Ajouter la description
        nodeEnter
            .append('text')
            .attr('class', 'node-sublabel')
            .attr('x', -this.nodeWidth / 2 + 40)
            .attr('y', 8)
            .style('font-size', '11px')
            .text(d => this.getNodeSubtitle(d.data));

        // Ajouter les badges (niveau, complexité, etc.)
        this.addNodeBadges(nodeEnter);

        // Fusionner avec les nœuds existants
        const nodeUpdate = nodeEnter.merge(nodeSelection);

        // Animer les nœuds vers leur position finale
        nodeUpdate
            .transition()
            .duration(750)
            .style('opacity', 1)
            .attr('transform', d => `translate(${d.x}, ${d.y})`);

        // Mettre à jour les classes selon l'état
        nodeUpdate
            .classed('selected', d => d === this.selectedNode)
            .classed('expanded', d => this.expandedNodes.has(d.data.id || d.data.name));
    }

    /**
     * Ajoute des badges informatifs aux nœuds
     */
    addNodeBadges(nodeEnter) {
        // Badge de complexité pour les scripts
        nodeEnter
            .filter(d => d.data.type === 'script' && d.data.complexity)
            .append('circle')
            .attr('class', 'complexity-badge')
            .attr('cx', this.nodeWidth / 2 - 12)
            .attr('cy', -this.nodeHeight / 2 + 12)
            .attr('r', 6)
            .style('fill', d => this.getComplexityColor(d.data.complexity));

        // Badge de statut
        nodeEnter
            .filter(d => d.data.type === 'script' && d.data.status)
            .append('text')
            .attr('class', 'status-badge')
            .attr('x', this.nodeWidth / 2 - 8)
            .attr('y', this.nodeHeight / 2 - 8)
            .style('font-size', '10px')
            .style('font-weight', '500')
            .text(d => d.data.status.charAt(0).toUpperCase());

        // Indicateur de dépendances
        nodeEnter
            .filter(d => d.data.dependencies && d.data.dependencies.length > 0)
            .append('text')
            .attr('class', 'dependency-indicator')
            .attr('x', -this.nodeWidth / 2 + 8)
            .attr('y', this.nodeHeight / 2 - 8)
            .style('font-family', 'Font Awesome 5 Free')
            .style('font-weight', '900')
            .style('font-size', '10px')
            .style('fill', '#6b7280')
            .text('\\uf0c1'); // Icône de lien
    }

    /**
     * ===========================
     * Interactions
     * ===========================
     */

    /**
     * Gère le clic sur un nœud
     */
    handleNodeClick(event, d) {
        event.stopPropagation();
        
        // Mettre à jour la sélection
        this.selectedNode = d;
        
        // Mettre à jour visuellement
        this.g.selectAll('.node')
            .classed('selected', node => node === d);

        // Callback personnalisé
        if (this.onNodeClick) {
            this.onNodeClick(d.data, d);
        }

        // Centrer sur le nœud sélectionné
        this.centerOnNode(d);
    }

    /**
     * Centre la vue sur un nœud spécifique
     */
    centerOnNode(d) {
        const scale = 1.2;
        const x = -d.x * scale + this.width / 2;
        const y = -d.y * scale + this.height / 2;
        
        this.svg
            .transition()
            .duration(750)
            .call(
                this.zoom.transform,
                d3.zoomIdentity.translate(x, y).scale(scale)
            );
    }

    /**
     * Affiche le tooltip
     */
    showTooltip(event, d) {
        const tooltipContent = this.createTooltipContent(d.data);
        
        this.tooltip
            .html(tooltipContent)
            .style('opacity', 1)
            .style('left', (event.pageX + 10) + 'px')
            .style('top', (event.pageY - 10) + 'px')
            .classed('visible', true);

        // Callback personnalisé
        if (this.onNodeHover) {
            this.onNodeHover(d.data, d);
        }
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
        let content = `<div class="tooltip-title">${data.name}</div>`;
        
        if (data.description) {
            content += `<div class="tooltip-description">${data.description}</div>`;
        }
        
        content += '<div class="tooltip-meta">';
        
        if (data.type) {
            content += `<span><i class="fas fa-tag"></i> ${data.type}</span>`;
        }
        
        if (data.level) {
            content += `<span><i class="fas fa-layer-group"></i> ${data.level}</span>`;
        }
        
        if (data.complexity) {
            content += `<span><i class="fas fa-cog"></i> ${data.complexity}</span>`;
        }
        
        if (data.dependencies && data.dependencies.length > 0) {
            content += `<span><i class="fas fa-link"></i> ${data.dependencies.length} dép.</span>`;
        }
        
        content += '</div>';
        
        return content;
    }

    /**
     * ===========================
     * Contrôles de Zoom
     * ===========================
     */

    zoomIn() {
        this.svg
            .transition()
            .duration(300)
            .call(
                this.zoom.scaleBy,
                1.5
            );
    }

    zoomOut() {
        this.svg
            .transition()
            .duration(300)
            .call(
                this.zoom.scaleBy,
                1 / 1.5
            );
    }

    resetZoom() {
        this.svg
            .transition()
            .duration(750)
            .call(
                this.zoom.transform,
                d3.zoomIdentity
            );
    }

    centerDiagram() {
        // Calculer le centre du contenu
        const bounds = this.g.node().getBBox();
        const fullWidth = this.width + this.margin.left + this.margin.right;
        const fullHeight = this.height + this.margin.top + this.margin.bottom;
        const scale = Math.min(
            0.8 * this.width / bounds.width,
            0.8 * this.height / bounds.height,
            1
        );
        
        const x = (this.width - bounds.width * scale) / 2 - bounds.x * scale;
        const y = (this.height - bounds.height * scale) / 2 - bounds.y * scale;

        this.svg.call(
            this.zoom.transform,
            d3.zoomIdentity.translate(x, y).scale(scale)
        );
    }

    /**
     * ===========================
     * Utilitaires
     * ===========================
     */

    /**
     * Retourne l'icône appropriée pour un type de nœud
     */
    getNodeIcon(data) {
        const icons = {
            'category': '\\uf07b',      // folder
            'level': '\\uf0e8',         // sitemap
            'script': '\\uf15b',        // file
            'atomic': '\\uf1b2',        // cube
            'orchestrator': '\\uf013',  // cogs
            'main': '\\uf135'           // rocket
        };
        
        return icons[data.type] || icons[data.level] || icons['script'];
    }

    /**
     * Retourne le sous-titre d'un nœud
     */
    getNodeSubtitle(data) {
        if (data.type === 'category') {
            const count = data.children ? data.children.length : 0;
            return `${count} niveau${count > 1 ? 'x' : ''}`;
        }
        
        if (data.type === 'level') {
            const count = data.children ? data.children.length : 0;
            return `${count} script${count > 1 ? 's' : ''}`;
        }
        
        if (data.type === 'script') {
            const parts = [];
            if (data.category) parts.push(data.category);
            if (data.complexity) parts.push(data.complexity);
            return parts.join(' • ');
        }
        
        return '';
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
     * Tronque un texte à une longueur donnée
     */
    truncateText(text, maxLength) {
        if (!text) return '';
        return text.length <= maxLength ? text : text.substring(0, maxLength - 3) + '...';
    }

    /**
     * Gère le redimensionnement de la fenêtre
     */
    handleResize() {
        this.setupDimensions();
        this.svg.attr('viewBox', `0 0 ${this.width + this.margin.left + this.margin.right} ${this.height + this.margin.top + this.margin.bottom}`);
        this.setupTreeLayout();
        if (this.currentData) {
            this.renderTree();
        }
    }

    /**
     * ===========================
     * API Publique
     * ===========================
     */

    /**
     * Filtre le diagramme selon des critères
     */
    filterDiagram(filters) {
        // Implémenter le filtrage selon les besoins
        console.log('Filtrage du diagramme:', filters);
        // TODO: Implémenter la logique de filtrage
    }

    /**
     * Met en surbrillance des nœuds spécifiques
     */
    highlightNodes(nodeIds) {
        this.g.selectAll('.node')
            .classed('highlighted', d => nodeIds.includes(d.data.id || d.data.name))
            .classed('faded', d => !nodeIds.includes(d.data.id || d.data.name) && nodeIds.length > 0);
    }

    /**
     * Supprime toute mise en surbrillance
     */
    clearHighlight() {
        this.g.selectAll('.node')
            .classed('highlighted', false)
            .classed('faded', false);
    }

    /**
     * Définit le callback pour les clics sur nœuds
     */
    setOnNodeClick(callback) {
        this.onNodeClick = callback;
    }

    /**
     * Définit le callback pour le survol des nœuds
     */
    setOnNodeHover(callback) {
        this.onNodeHover = callback;
    }

    /**
     * Nettoie les ressources
     */
    destroy() {
        if (this.tooltip) {
            this.tooltip.remove();
        }
        
        window.removeEventListener('resize', this.handleResize);
        
        this.container.selectAll('*').remove();
    }
}

// Export pour utilisation
window.HierarchyDiagram = HierarchyDiagram;