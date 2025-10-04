import React, { useRef, useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { 
  DropdownMenu, 
  DropdownMenuContent, 
  DropdownMenuItem, 
  DropdownMenuTrigger 
} from "@/components/ui/dropdown-menu";
import { ScriptCanvas } from "@/components/ScriptCanvas";
import { ScriptLibrary } from "@/components/ScriptLibrary";
import { useScriptWorkflow } from "@/hooks/useScriptWorkflow";
import { ScriptDefinition, Point2D } from "@/types/script-flow";
import { 
  Play, 
  Save, 
  Download, 
  Upload, 
  RefreshCw, 
  ZoomIn, 
  ZoomOut, 
  RotateCcw,
  Target,
  Settings,
  CheckCircle,
  AlertTriangle,
  ChevronDown,
  Network,
  Database
} from "lucide-react";
import { toast } from "sonner";

export default function Builder() {
  const canvasRef = useRef<HTMLDivElement>(null);
  const {
    scripts,
    connections,
    selectedScriptId,
    scriptDefinitions,
    zoom,
    camera,
    addScript,
    removeScript,
    moveScript,
    selectScript,
    addConnection,
    removeConnection,
    updateScriptParameter,
    getSelectedScript,
    getSelectedScriptDefinition,
    clearWorkflow,
    exportWorkflow,
    importWorkflow,
    loadExampleWorkflow,
    loadSSHExampleWorkflow,
    zoomIn,
    zoomOut,
    resetView,
    recenterView,
    setCamera,
    updateZoom,
    executeScript,
    executeWorkflow,
    validateWorkflow
  } = useScriptWorkflow();

  const [isDragOver, setIsDragOver] = useState(false);

  // Gestionnaire de glisser-déposer depuis la bibliothèque
  const handleScriptDragStart = (script: ScriptDefinition, e: React.DragEvent) => {
    e.dataTransfer.setData('application/json', JSON.stringify(script));
    e.dataTransfer.effectAllowed = 'copy';
  };

  const handleCanvasDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragOver(false);
    
    try {
      const scriptDefinition = JSON.parse(e.dataTransfer.getData('application/json'));
      const rect = canvasRef.current?.getBoundingClientRect();
      
      if (rect) {
        const position: Point2D = {
          x: (e.clientX - rect.left - camera.x) / zoom - 140,
          y: (e.clientY - rect.top - camera.y) / zoom - 90
        };
        
        addScript(scriptDefinition, position);
        toast.success(`Script "${scriptDefinition.name}" ajouté au workflow`);
      }
    } catch (error) {
      toast.error('Erreur lors de l\'ajout du script');
      console.error('Erreur de drop:', error);
    }
  };

  const handleCanvasDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragOver(true);
  };

  const handleCanvasDragLeave = (e: React.DragEvent) => {
    setIsDragOver(false);
  };

  // Sauvegarder le workflow
  const handleSave = () => {
    const workflow = exportWorkflow();
    localStorage.setItem('scriptWorkflow', JSON.stringify(workflow));
    toast.success('Workflow sauvegardé');
  };

  // Charger un workflow
  const handleLoad = () => {
    const saved = localStorage.getItem('scriptWorkflow');
    if (saved) {
      try {
        const workflow = JSON.parse(saved);
        importWorkflow(workflow);
        toast.success('Workflow chargé');
      } catch (error) {
        toast.error('Erreur lors du chargement');
      }
    } else {
      toast.info('Aucun workflow sauvegardé trouvé');
    }
  };

  // Télécharger le workflow
  const handleDownload = () => {
    const workflow = exportWorkflow();
    const blob = new Blob([JSON.stringify(workflow, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `workflow-${Date.now()}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    toast.success('Workflow téléchargé');
  };

  // Uploader un workflow
  const handleUpload = () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json';
    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (file) {
        const reader = new FileReader();
        reader.onload = (e) => {
          try {
            const workflow = JSON.parse(e.target?.result as string);
            importWorkflow(workflow);
            toast.success('Workflow importé');
          } catch (error) {
            toast.error('Fichier invalide');
          }
        };
        reader.readAsText(file);
      }
    };
    input.click();
  };

  // Statistiques du workflow
  const workflowStats = {
    totalScripts: scripts.length,
    totalConnections: connections.length,
    completedScripts: scripts.filter(s => s.status === 'completed').length,
    runningScripts: scripts.filter(s => s.status === 'running').length,
    errorScripts: scripts.filter(s => s.status === 'error').length
  };

  return (
    <div className="flex-1 space-y-6 p-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Script Workflow Builder</h2>
          <p className="text-muted-foreground">
            Créez des workflows visuels en connectant vos scripts AtomicOps-Suite
          </p>
        </div>
        
        <div className="flex gap-2">
          {workflowStats.totalScripts > 0 && (
            <Badge variant="outline" className="gap-1">
              <Settings className="h-3 w-3" />
              {workflowStats.totalScripts} scripts
            </Badge>
          )}
        </div>
      </div>

      {/* Barre d'outils */}
      <Card>
        <CardContent className="p-4">
          <div className="flex items-center justify-between">
            <div className="flex gap-2">
              <Button onClick={handleSave} variant="outline" disabled={scripts.length === 0}>
                <Save className="h-4 w-4 mr-2" />
                Sauvegarder
              </Button>
              <Button onClick={handleLoad} variant="outline">
                <Upload className="h-4 w-4 mr-2" />
                Charger
              </Button>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="outline">
                    <Target className="h-4 w-4 mr-2" />
                    Exemples
                    <ChevronDown className="h-4 w-4 ml-1" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="start" className="w-56">
                  <DropdownMenuItem 
                    onClick={() => {
                      loadExampleWorkflow();
                      toast.success('Exemple de workflow Infrastructure chargé');
                    }}
                  >
                    <Database className="h-4 w-4 mr-2" />
                    <div className="flex flex-col">
                      <span>Infrastructure & Storage</span>
                      <span className="text-xs text-muted-foreground">
                        iSCSI, disques, containers
                      </span>
                    </div>
                  </DropdownMenuItem>
                  <DropdownMenuItem 
                    onClick={() => {
                      loadSSHExampleWorkflow();
                      toast.success('Exemple de workflow SSH chargé');
                    }}
                  >
                    <Network className="h-4 w-4 mr-2" />
                    <div className="flex flex-col">
                      <span>Gestion SSH Complète</span>
                      <span className="text-xs text-muted-foreground">
                        Clés, accès, audit, rotation
                      </span>
                    </div>
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
              <Button onClick={handleDownload} variant="outline" disabled={scripts.length === 0}>
                <Download className="h-4 w-4 mr-2" />
                Exporter
              </Button>
            </div>

            <div className="flex gap-2">
              <Button onClick={zoomIn} size="sm" variant="outline">
                <ZoomIn className="h-4 w-4" />
              </Button>
              <Button onClick={zoomOut} size="sm" variant="outline">
                <ZoomOut className="h-4 w-4" />
              </Button>
              <Button onClick={resetView} size="sm" variant="outline">
                <RotateCcw className="h-4 w-4" />
              </Button>
              <Button 
                onClick={clearWorkflow} 
                variant="destructive" 
                size="sm"
                disabled={scripts.length === 0}
              >
                Effacer tout
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Interface principale */}
      <div className="flex gap-6 h-[calc(100vh-300px)]">
        {/* Bibliothèque de scripts */}
        <ScriptLibrary
          scriptDefinitions={scriptDefinitions}
          onScriptDragStart={handleScriptDragStart}
        />

        {/* Canvas principal */}
        <Card className="flex-1 relative overflow-hidden">
          <CardHeader className="pb-3">
            <CardTitle className="text-lg">Workflow Canvas</CardTitle>
            <CardDescription>
              Glissez-déposez des scripts depuis la bibliothèque pour créer votre workflow
            </CardDescription>
          </CardHeader>
          <CardContent className="p-0 h-full">
            <div 
              ref={canvasRef}
              className={`relative w-full h-full transition-colors ${
                isDragOver 
                  ? 'bg-primary/10 border-2 border-dashed border-primary' 
                  : 'bg-gray-50 dark:bg-gray-900'
              }`}
              onDrop={handleCanvasDrop}
              onDragOver={handleCanvasDragOver}
              onDragLeave={handleCanvasDragLeave}
            >
              <ScriptCanvas
                scripts={scripts}
                connections={connections}
                scriptDefinitions={scriptDefinitions}
                selectedScriptId={selectedScriptId}
                onScriptMove={moveScript}
                onScriptSelect={selectScript}
                onConnectionCreate={addConnection}
                onConnectionDelete={removeConnection}
                onScriptExecute={executeScript}
                zoom={zoom}
                camera={camera}
                onCameraChange={setCamera}
                onZoomChange={updateZoom}
              />
              
              {/* Message d'aide si vide */}
              {scripts.length === 0 && !isDragOver && (
                <div className="absolute inset-0 flex items-center justify-center">
                  <div className="text-center max-w-md">
                    <div className="text-6xl mb-4">🚀</div>
                    <h3 className="text-xl font-semibold mb-2">Commencez votre workflow</h3>
                    <p className="text-muted-foreground mb-4">
                      Glissez-déposez des scripts depuis la bibliothèque de gauche pour créer votre premier workflow
                    </p>
                  </div>
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}