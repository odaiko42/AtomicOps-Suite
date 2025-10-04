// ===========================
// Composant de visualisation D3.js pour React
// ===========================

import React, { useEffect, useRef } from 'react';
import * as d3 from 'd3';

interface Node {
  id: string;
  name: string;
  level: number;
  category: string;
  group?: string;
  x?: number;
  y?: number;
  fx?: number | null;
  fy?: number | null;
}

interface Link {
  source: string | Node;
  target: string | Node;
  type: 'dependency' | 'child' | 'parent';
}

interface D3GraphProps {
  nodes: Node[];
  links: Link[];
  width?: number;
  height?: number;
  onNodeClick?: (node: Node) => void;
  onNodeHover?: (node: Node | null) => void;
}

const D3Graph: React.FC<D3GraphProps> = ({
  nodes,
  links,
  width = 800,
  height = 600,
  onNodeClick,
  onNodeHover
}) => {
  const svgRef = useRef<SVGSVGElement>(null);

  useEffect(() => {
    if (!svgRef.current || !nodes.length) return;

    const svg = d3.select(svgRef.current);
    svg.selectAll("*").remove(); // Clear previous render

    // Configuration
    const margin = { top: 20, right: 20, bottom: 20, left: 20 };
    const innerWidth = width - margin.left - margin.right;
    const innerHeight = height - margin.top - margin.bottom;

    // Conteneur principal
    const container = svg
      .attr("width", width)
      .attr("height", height)
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`);

    // Définition des couleurs par catégorie
    const colorScale = d3.scaleOrdinal(d3.schemeCategory10);

    // Simulation de force
    const simulation = d3.forceSimulation(nodes as d3.SimulationNodeDatum[])
      .force("link", d3.forceLink(links).id((d: any) => d.id).distance(100))
      .force("charge", d3.forceManyBody().strength(-300))
      .force("center", d3.forceCenter(innerWidth / 2, innerHeight / 2))
      .force("collision", d3.forceCollide().radius(30));

    // Création des liens
    const linkSelection = container
      .selectAll(".link")
      .data(links)
      .join("line")
      .attr("class", "link")
      .attr("stroke", "#999")
      .attr("stroke-opacity", 0.6)
      .attr("stroke-width", (d: any) => {
        switch (d.type) {
          case 'dependency': return 2;
          case 'child': return 1.5;
          case 'parent': return 1;
          default: return 1;
        }
      })
      .attr("stroke-dasharray", (d: any) => {
        return d.type === 'dependency' ? "5,5" : "none";
      });

    // Création des groupes de nœuds
    const nodeGroup = container
      .selectAll(".node-group")
      .data(nodes)
      .join("g")
      .attr("class", "node-group")
      .style("cursor", "pointer")
      .call(d3.drag<SVGGElement, Node>()
        .on("start", dragstarted)
        .on("drag", dragged)
        .on("end", dragended));

    // Cercles des nœuds
    nodeGroup
      .append("circle")
      .attr("r", (d: Node) => 8 + d.level * 2)
      .attr("fill", (d: Node) => colorScale(d.category))
      .attr("stroke", "#fff")
      .attr("stroke-width", 2)
      .on("mouseover", function(event, d) {
        d3.select(this).attr("r", (d: Node) => 12 + d.level * 2);
        onNodeHover?.(d);
      })
      .on("mouseout", function(event, d) {
        d3.select(this).attr("r", (d: Node) => 8 + d.level * 2);
        onNodeHover?.(null);
      })
      .on("click", (event, d) => {
        onNodeClick?.(d);
      });

    // Labels des nœuds
    nodeGroup
      .append("text")
      .text((d: Node) => d.name.length > 15 ? d.name.substring(0, 12) + "..." : d.name)
      .attr("x", 0)
      .attr("y", -15)
      .attr("text-anchor", "middle")
      .attr("font-size", "12px")
      .attr("font-family", "Arial, sans-serif")
      .attr("fill", "#333")
      .attr("pointer-events", "none");

    // Badge niveau
    nodeGroup
      .append("circle")
      .attr("r", 8)
      .attr("cx", 15)
      .attr("cy", -10)
      .attr("fill", "#007bff")
      .attr("stroke", "#fff")
      .attr("stroke-width", 1);

    nodeGroup
      .append("text")
      .text((d: Node) => d.level.toString())
      .attr("x", 15)
      .attr("y", -6)
      .attr("text-anchor", "middle")
      .attr("font-size", "10px")
      .attr("font-weight", "bold")
      .attr("fill", "white")
      .attr("pointer-events", "none");

    // Fonction de mise à jour de la simulation
    simulation.on("tick", () => {
      linkSelection
        .attr("x1", (d: any) => d.source.x)
        .attr("y1", (d: any) => d.source.y)
        .attr("x2", (d: any) => d.target.x)
        .attr("y2", (d: any) => d.target.y);

      nodeGroup
        .attr("transform", (d: any) => `translate(${d.x},${d.y})`);
    });

    // Fonctions de drag
    function dragstarted(event: any, d: any) {
      if (!event.active) simulation.alphaTarget(0.3).restart();
      d.fx = d.x;
      d.fy = d.y;
    }

    function dragged(event: any, d: any) {
      d.fx = event.x;
      d.fy = event.y;
    }

    function dragended(event: any, d: any) {
      if (!event.active) simulation.alphaTarget(0);
      d.fx = null;
      d.fy = null;
    }

    // Zoom et pan
    const zoom = d3.zoom<SVGSVGElement, unknown>()
      .scaleExtent([0.1, 4])
      .on("zoom", (event) => {
        container.attr("transform", event.transform);
      });

    svg.call(zoom);

    // Cleanup
    return () => {
      simulation.stop();
    };

  }, [nodes, links, width, height, onNodeClick, onNodeHover]);

  return (
    <div className="w-full h-full border rounded-lg bg-white">
      <svg
        ref={svgRef}
        className="w-full h-full"
        style={{ background: 'linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%)' }}
      />
    </div>
  );
};

export default D3Graph;