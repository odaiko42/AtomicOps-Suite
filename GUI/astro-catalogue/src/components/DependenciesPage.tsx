// ===========================
// Composant de visualisation des dépendances
// ===========================

import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { AlertCircle, Network, TreePine, Loader2, GitBranch, Users, Layers } from 'lucide-react';
import { useDependencyGraph, useHierarchy, useScripts } from '../hooks/useScriptData';
import D3Graph from './D3Graph';
import { Script } from '../services/sqliteDataService';

interface DependenciesPageProps {
  onScriptSelect?: (script: Script) => void;
}

const DependenciesPage: React.FC<DependenciesPageProps> = ({ onScriptSelect }) => {
  const { scripts } = useScripts();
  const { graph, loading: graphLoading, error: graphError } = useDependencyGraph();
  const { hierarchy, loading: hierarchyLoading, error: hierarchyError } = useHierarchy();
  const [selectedNode, setSelectedNode] = useState<any>(null);
  const [hoveredNode, setHoveredNode] = useState<any>(null);

  // Calcul des statistiques de dépendances
  const dependencyStats = React.useMemo(() => {
    const scriptsByLevel = scripts.reduce((acc, script) => {
      acc[script.level] = (acc[script.level] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    const scriptsByCategory = scripts.reduce((acc, script) => {
      acc[script.category] = (acc[script.category] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    // Scripts avec dépendances (simulation basée sur le niveau)
    const scriptsWithDeps = scripts.filter(s => s.level === 'orchestrator' || s.level === 'main').length;
    const independentScripts = scripts.filter(s => s.level === 'lib' || s.level === 'atomic').length;

    return {
      totalScripts: scripts.length,
      scriptsByLevel,
      scriptsByCategory,
      scriptsWithDeps,
      independentScripts,
      complexityScore: Math.round((scriptsWithDeps / scripts.length) * 100)
    };
  }, [scripts]);

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
      {/* Statistiques de dépendances */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Scripts Total</CardTitle>
            <Network className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{dependencyStats.totalScripts}</div>
            <p className="text-xs text-muted-foreground">
              Dans {Object.keys(dependencyStats.scriptsByCategory).length} catégories
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Scripts avec Dépendances</CardTitle>
            <GitBranch className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-orange-600">{dependencyStats.scriptsWithDeps}</div>
            <p className="text-xs text-muted-foreground">
              Orchestrateurs et interfaces
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Scripts Indépendants</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">{dependencyStats.independentScripts}</div>
            <p className="text-xs text-muted-foreground">
              Atomiques et librairies
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Complexité</CardTitle>
            <Layers className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">{dependencyStats.complexityScore}%</div>
            <p className="text-xs text-muted-foreground">
              Score de complexité
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Répartition par niveau */}
      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Layers className="h-5 w-5" />
              Répartition par Niveau
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {Object.entries(dependencyStats.scriptsByLevel).map(([level, count]) => (
                <div key={level} className="flex items-center gap-4">
                  <div className="flex-1">
                    <div className="flex items-center justify-between">
                      <span className="font-medium capitalize">
                        {level.replace(/-/g, ' ')}
                      </span>
                      <span className="text-sm font-bold">{count}</span>
                    </div>
                    <div className="w-full bg-gray-200 rounded-full h-2 mt-1">
                      <div
                        className="bg-blue-500 h-2 rounded-full transition-all"
                        style={{ width: `${(count / dependencyStats.totalScripts) * 100}%` }}
                      />
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Network className="h-5 w-5" />
              Répartition par Catégorie
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {Object.entries(dependencyStats.scriptsByCategory)
                .sort(([,a], [,b]) => b - a)
                .slice(0, 5)
                .map(([category, count]) => (
                  <div key={category} className="flex items-center gap-4">
                    <div className="flex-1">
                      <div className="flex items-center justify-between">
                        <span className="font-medium capitalize">
                          {category.replace(/-/g, ' ')}
                        </span>
                        <span className="text-sm font-bold">{count}</span>
                      </div>
                      <div className="w-full bg-gray-200 rounded-full h-2 mt-1">
                        <div
                          className="bg-green-500 h-2 rounded-full transition-all"
                          style={{ width: `${(count / dependencyStats.totalScripts) * 100}%` }}
                        />
                      </div>
                    </div>
                  </div>
                ))}
            </div>
          </CardContent>
        </Card>
      </div>

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