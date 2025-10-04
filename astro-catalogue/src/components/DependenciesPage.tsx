// ===========================
// Composant de visualisation des dépendances
// ===========================

import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { AlertCircle, Network, TreePine, Loader2 } from 'lucide-react';
import { useDependencyGraph, useHierarchy } from '../hooks/useScriptData';
import D3Graph from './D3Graph';
import { Script } from '../services/sqliteDataService';

interface DependenciesPageProps {
  onScriptSelect?: (script: Script) => void;
}

const DependenciesPage: React.FC<DependenciesPageProps> = ({ onScriptSelect }) => {
  const { graph, loading: graphLoading, error: graphError } = useDependencyGraph();
  const { hierarchy, loading: hierarchyLoading, error: hierarchyError } = useHierarchy();
  const [selectedNode, setSelectedNode] = useState<any>(null);
  const [hoveredNode, setHoveredNode] = useState<any>(null);

  const handleNodeClick = (node: any) => {
    setSelectedNode(node);
    // Si on a une fonction de callback pour sélectionner un script
    if (onScriptSelect && node.type === 'script') {
      // On devrait avoir les données du script complet
      onScriptSelect(node);
    }
  };

  const handleNodeHover = (node: any) => {
    setHoveredNode(node);
  };

  const renderNodeDetails = (node: any) => {
    if (!node) return null;

    return (
      <Card className="mt-4">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Network className="h-5 w-5" />
            Détails du nœud
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <div>
            <span className="font-semibold">Nom :</span> {node.name}
          </div>
          <div>
            <span className="font-semibold">Niveau :</span> 
            <Badge variant="outline" className="ml-2">
              {node.level}
            </Badge>
          </div>
          <div>
            <span className="font-semibold">Catégorie :</span> 
            <Badge variant="secondary" className="ml-2">
              {node.category}
            </Badge>
          </div>
          {node.group && (
            <div>
              <span className="font-semibold">Groupe :</span> 
              <Badge variant="outline" className="ml-2">
                {node.group}
              </Badge>
            </div>
          )}
          {node.description && (
            <div>
              <span className="font-semibold">Description :</span>
              <p className="text-sm text-gray-600 mt-1">{node.description}</p>
            </div>
          )}
        </CardContent>
      </Card>
    );
  };

  const renderGraphView = () => {
    if (graphLoading) {
      return (
        <div className="flex items-center justify-center h-64">
          <Loader2 className="h-8 w-8 animate-spin" />
          <span className="ml-2">Chargement du graphe...</span>
        </div>
      );
    }

    if (graphError) {
      return (
        <div className="flex items-center justify-center h-64 text-red-500">
          <AlertCircle className="h-8 w-8 mr-2" />
          Erreur : {graphError}
        </div>
      );
    }

    if (!graph || !graph.nodes.length) {
      return (
        <div className="flex items-center justify-center h-64 text-gray-500">
          <Network className="h-8 w-8 mr-2" />
          Aucune donnée de graphe disponible
        </div>
      );
    }

    return (
      <div className="space-y-4">
        <div className="h-96 border rounded-lg">
          <D3Graph
            nodes={graph.nodes}
            links={graph.links}
            width={800}
            height={384}
            onNodeClick={handleNodeClick}
            onNodeHover={handleNodeHover}
          />
        </div>
        
        {/* Informations sur le nœud survolé ou sélectionné */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {hoveredNode && (
            <Card>
              <CardHeader>
                <CardTitle className="text-sm">Nœud survolé</CardTitle>
              </CardHeader>
              <CardContent className="text-sm space-y-1">
                <div><strong>Nom :</strong> {hoveredNode.name}</div>
                <div><strong>Niveau :</strong> {hoveredNode.level}</div>
                <div><strong>Catégorie :</strong> {hoveredNode.category}</div>
              </CardContent>
            </Card>
          )}
          
          {selectedNode && (
            <Card>
              <CardHeader>
                <CardTitle className="text-sm">Nœud sélectionné</CardTitle>
              </CardHeader>
              <CardContent className="text-sm space-y-1">
                <div><strong>Nom :</strong> {selectedNode.name}</div>
                <div><strong>Niveau :</strong> {selectedNode.level}</div>
                <div><strong>Catégorie :</strong> {selectedNode.category}</div>
                {selectedNode.group && (
                  <div><strong>Groupe :</strong> {selectedNode.group}</div>
                )}
              </CardContent>
            </Card>
          )}
        </div>
      </div>
    );
  };

  const renderHierarchyView = () => {
    if (hierarchyLoading) {
      return (
        <div className="flex items-center justify-center h-64">
          <Loader2 className="h-8 w-8 animate-spin" />
          <span className="ml-2">Chargement de la hiérarchie...</span>
        </div>
      );
    }

    if (hierarchyError) {
      return (
        <div className="flex items-center justify-center h-64 text-red-500">
          <AlertCircle className="h-8 w-8 mr-2" />
          Erreur : {hierarchyError}
        </div>
      );
    }

    if (!hierarchy) {
      return (
        <div className="flex items-center justify-center h-64 text-gray-500">
          <TreePine className="h-8 w-8 mr-2" />
          Aucune donnée hiérarchique disponible
        </div>
      );
    }

    const renderNode = (node: any, level: number = 0) => {
      const indent = level * 24;
      
      return (
        <div key={node.id || node.name} className="space-y-1">
          <div 
            className="flex items-center p-2 rounded hover:bg-gray-50 cursor-pointer"
            style={{ marginLeft: indent }}
            onClick={() => handleNodeClick(node)}
          >
            <div className="flex items-center space-x-2 flex-1">
              <span className="font-medium">{node.name}</span>
              <Badge variant="outline" className="text-xs">
                Niveau {node.level}
              </Badge>
              <Badge variant="secondary" className="text-xs">
                {node.category}
              </Badge>
            </div>
            {node.functions && (
              <Badge variant="outline" className="text-xs">
                {node.functions.length} fonction(s)
              </Badge>
            )}
          </div>
          
          {node.children && node.children.map((child: any) => 
            renderNode(child, level + 1)
          )}
        </div>
      );
    };

    return (
      <div className="space-y-4">
        <div className="max-h-96 overflow-y-auto border rounded-lg p-4">
          {Array.isArray(hierarchy) ? (
            hierarchy.map((node: any) => renderNode(node))
          ) : (
            renderNode(hierarchy)
          )}
        </div>
        
        {selectedNode && renderNodeDetails(selectedNode)}
      </div>
    );
  };

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Network className="h-5 w-5" />
            Visualisation des Dépendances et Hiérarchie
          </CardTitle>
        </CardHeader>
        <CardContent>
          <Tabs defaultValue="graph" className="w-full">
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="graph" className="flex items-center gap-2">
                <Network className="h-4 w-4" />
                Graphe de Dépendances
              </TabsTrigger>
              <TabsTrigger value="hierarchy" className="flex items-center gap-2">
                <TreePine className="h-4 w-4" />
                Vue Hiérarchique
              </TabsTrigger>
            </TabsList>
            
            <TabsContent value="graph" className="mt-4">
              {renderGraphView()}
            </TabsContent>
            
            <TabsContent value="hierarchy" className="mt-4">
              {renderHierarchyView()}
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>

      {/* Légende */}
      <Card>
        <CardHeader>
          <CardTitle className="text-sm">Légende</CardTitle>
        </CardHeader>
        <CardContent className="text-sm space-y-2">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <h4 className="font-semibold mb-2">Types de liens :</h4>
              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <div className="w-4 h-0.5 bg-gray-600"></div>
                  <span>Dépendance directe</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-4 h-0.5 bg-gray-400 border-dashed"></div>
                  <span>Dépendance indirecte</span>
                </div>
              </div>
            </div>
            
            <div>
              <h4 className="font-semibold mb-2">Interaction :</h4>
              <div className="space-y-1">
                <div>• Cliquez sur un nœud pour voir les détails</div>
                <div>• Survolez un nœud pour l'information rapide</div>
                <div>• Glissez-déposez pour réorganiser le graphe</div>
                <div>• Utilisez la molette pour zoomer</div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default DependenciesPage;