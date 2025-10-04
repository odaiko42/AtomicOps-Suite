import React, { useRef, useEffect, useState, useCallback } from 'react';
import { 
  ScriptInstance, 
  ScriptConnection, 
  Point2D, 
  ScriptDataType, 
  SCRIPT_DATA_TYPE_COLORS,
  SCRIPT_CATEGORY_COLORS,
  ScriptDefinition
} from '@/types/script-flow';
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Play, Square, AlertCircle, CheckCircle, Clock } from "lucide-react";

interface ScriptCanvasProps {
  scripts: ScriptInstance[];
  connections: ScriptConnection[];
  scriptDefinitions: ScriptDefinition[];
  selectedScriptId?: string;
  onScriptMove: (scriptId: string, position: Point2D) => void;
  onScriptSelect: (scriptId: string) => void;
  onConnectionCreate: (connection: Omit<ScriptConnection, 'id'>) => void;
  onConnectionDelete: (connectionId: string) => void;
  onScriptExecute?: (scriptId: string) => void;
  zoom: number;
  camera: { x: number; y: number };
  onCameraChange: (camera: { x: number; y: number }) => void;
  onZoomChange: (zoom: number) => void;
}

interface DragState {
  isDragging: boolean;
  scriptId?: string;
  offset?: Point2D;
  startPos?: Point2D;
}

interface ConnectionState {
  isConnecting: boolean;
  sourceScriptId?: string;
  sourceSocket?: string;
  sourceSocketType?: ScriptDataType;
  sourcePos?: Point2D;
  currentPos?: Point2D;
}

interface HoverState {
  scriptId?: string;
  socketName?: string;
  socketType?: 'input' | 'output';
}

interface PanState {
  isPanning: boolean;
  startPos?: Point2D;
  startCamera?: { x: number; y: number };
}

const SCRIPT_WIDTH = 280;
const SCRIPT_HEIGHT = 180;
const SOCKET_RADIUS = 8;
const SOCKET_SPACING = 25;

// Configuration des niveaux
const LEVEL_CONFIG = {
  0: { label: 'Level 0 - Atomique', color: '#10b981', bgColor: 'rgba(16, 185, 129, 0.2)' },
  1: { label: 'Level 1 - Orchestrateur', color: '#f59e0b', bgColor: 'rgba(245, 158, 11, 0.2)' },
  2: { label: 'Level 2 - Orchestrateur', color: '#ef4444', bgColor: 'rgba(239, 68, 68, 0.2)' },
  3: { label: 'Level 3 - Main', color: '#8b5cf6', bgColor: 'rgba(139, 92, 246, 0.2)' },
  'atomic': { label: 'Level 0 - Atomique', color: '#10b981', bgColor: 'rgba(16, 185, 129, 0.2)' },
  'orchestrator': { label: 'Level 1+ - Orchestrateur', color: '#f59e0b', bgColor: 'rgba(245, 158, 11, 0.2)' },
  'main': { label: 'Level 3 - Main', color: '#8b5cf6', bgColor: 'rgba(139, 92, 246, 0.2)' }
} as const;

const getLevelConfig = (level: string | number) => {
  const key = String(level) as keyof typeof LEVEL_CONFIG;
  return LEVEL_CONFIG[key] || LEVEL_CONFIG[0];
};

export const ScriptCanvas: React.FC<ScriptCanvasProps> = ({
  scripts,
  connections,
  scriptDefinitions,
  selectedScriptId,
  onScriptMove,
  onScriptSelect,
  onConnectionCreate,
  onConnectionDelete,
  onScriptExecute,
  zoom,
  camera,
  onCameraChange,
  onZoomChange
}) => {
  const canvasRef = useRef<SVGSVGElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [dragState, setDragState] = useState<DragState>({ isDragging: false });
  const [connectionState, setConnectionState] = useState<ConnectionState>({ isConnecting: false });
  const [hoverState, setHoverState] = useState<HoverState>({});
  const [panState, setPanState] = useState<PanState>({ isPanning: false });

  // Obtenir la définition d'un script
  const getScriptDefinition = useCallback((scriptId: string): ScriptDefinition | undefined => {
    const script = scripts.find(s => s.id === scriptId);
    if (!script) return undefined;
    return scriptDefinitions.find(def => def.id === script.definitionId);
  }, [scripts, scriptDefinitions]);

  // Fonction pour calculer la position d'un socket
  const getSocketPosition = useCallback((
    scriptId: string, 
    socketName: string, 
    socketType: 'input' | 'output'
  ): Point2D | null => {
    const script = scripts.find(s => s.id === scriptId);
    const definition = getScriptDefinition(scriptId);
    
    if (!script || !definition) return null;

    const sockets = socketType === 'input' ? definition.inputs : definition.outputs;
    const socketIndex = sockets.findIndex(s => s.name === socketName);
    
    if (socketIndex === -1) return null;

    const baseX = socketType === 'input' 
      ? script.position.x 
      : script.position.x + SCRIPT_WIDTH;
    
    const baseY = script.position.y + 60 + (socketIndex * SOCKET_SPACING);

    return { x: baseX, y: baseY };
  }, [scripts, getScriptDefinition]);

  // Rendu d'un socket
  const renderSocket = (
    script: ScriptInstance,
    definition: ScriptDefinition,
    socket: any,
    index: number,
    type: 'input' | 'output'
  ) => {
    const isHovered = hoverState.scriptId === script.id && 
                     hoverState.socketName === socket.name && 
                     hoverState.socketType === type;
    
    const x = type === 'input' ? -SOCKET_RADIUS : SCRIPT_WIDTH + SOCKET_RADIUS;
    const y = 60 + (index * SOCKET_SPACING);
    
    return (
      <g key={`${type}-${socket.name}`}>
        <circle
          cx={x}
          cy={y}
          r={SOCKET_RADIUS}
          fill={SCRIPT_DATA_TYPE_COLORS[socket.type]}
          stroke={isHovered ? '#ffffff' : '#000000'}
          strokeWidth={isHovered ? 3 : 1}
          className="cursor-pointer"
          onMouseEnter={() => setHoverState({
            scriptId: script.id,
            socketName: socket.name,
            socketType: type
          })}
          onMouseLeave={() => setHoverState({})}
          onMouseDown={(e) => handleSocketMouseDown(e, script.id, socket.name, socket.type)}
        />
        <text
          x={type === 'input' ? x + 15 : x - 15}
          y={y + 4}
          fontSize="12"
          fill="currentColor"
          textAnchor={type === 'input' ? 'start' : 'end'}
          className="select-none pointer-events-none"
        >
          {socket.name}
        </text>
        {socket.required && (
          <circle
            cx={type === 'input' ? x - 12 : x + 12}
            cy={y - 8}
            r="3"
            fill="#ef4444"
          />
        )}
      </g>
    );
  };

  // Gestionnaire de clic sur socket
  const handleSocketMouseDown = (
    e: React.MouseEvent,
    scriptId: string,
    socketName: string,
    socketType: ScriptDataType
  ) => {
    e.preventDefault();
    e.stopPropagation();
    
    const socketPos = getSocketPosition(scriptId, socketName, 'output');
    if (!socketPos) return;

    setConnectionState({
      isConnecting: true,
      sourceScriptId: scriptId,
      sourceSocket: socketName,
      sourceSocketType: socketType,
      sourcePos: socketPos,
      currentPos: socketPos
    });
  };

  // Rendu des connexions
  const renderConnections = () => {
    return connections.map(connection => {
      const sourcePos = getSocketPosition(connection.sourceScriptId, connection.sourceSocket, 'output');
      const targetPos = getSocketPosition(connection.targetScriptId, connection.targetSocket, 'input');
      
      if (!sourcePos || !targetPos) return null;

      const dx = targetPos.x - sourcePos.x;
      const controlOffset = Math.abs(dx) * 0.5;
      
      const path = `M ${sourcePos.x} ${sourcePos.y} 
                   C ${sourcePos.x + controlOffset} ${sourcePos.y} 
                     ${targetPos.x - controlOffset} ${targetPos.y} 
                     ${targetPos.x} ${targetPos.y}`;

      return (
        <path
          key={connection.id}
          d={path}
          stroke={SCRIPT_DATA_TYPE_COLORS[connection.type]}
          strokeWidth="3"
          fill="none"
          className="cursor-pointer hover:stroke-width-4"
          onClick={() => onConnectionDelete(connection.id)}
        />
      );
    });
  };

  // Rendu de la connexion temporaire
  const renderTempConnection = () => {
    if (!connectionState.isConnecting || !connectionState.sourcePos || !connectionState.currentPos) {
      return null;
    }

    const dx = connectionState.currentPos.x - connectionState.sourcePos.x;
    const controlOffset = Math.abs(dx) * 0.5;
    
    const path = `M ${connectionState.sourcePos.x} ${connectionState.sourcePos.y} 
                 C ${connectionState.sourcePos.x + controlOffset} ${connectionState.sourcePos.y} 
                   ${connectionState.currentPos.x - controlOffset} ${connectionState.currentPos.y} 
                   ${connectionState.currentPos.x} ${connectionState.currentPos.y}`;

    return (
      <path
        d={path}
        stroke={connectionState.sourceSocketType ? SCRIPT_DATA_TYPE_COLORS[connectionState.sourceSocketType] : '#6b7280'}
        strokeWidth="3"
        fill="none"
        strokeDasharray="5,5"
        opacity="0.7"
      />
    );
  };

  // Rendu d'un script
  const renderScript = (script: ScriptInstance) => {
    const definition = getScriptDefinition(script.id);
    if (!definition) return null;

    const isSelected = selectedScriptId === script.id;
    const categoryColor = SCRIPT_CATEGORY_COLORS[definition.category] || '#6b7280';

    // Icône de statut
    const StatusIcon = () => {
      switch (script.status) {
        case 'running': return <Clock className="h-4 w-4 text-blue-500 animate-spin" />;
        case 'completed': return <CheckCircle className="h-4 w-4 text-green-500" />;
        case 'error': return <AlertCircle className="h-4 w-4 text-red-500" />;
        default: return <Square className="h-4 w-4 text-gray-500" />;
      }
    };

    return (
      <g key={script.id} transform={`translate(${script.position.x}, ${script.position.y})`}>
        {/* Conteneur principal du script */}
        <rect
          width={SCRIPT_WIDTH}
          height={SCRIPT_HEIGHT}
          rx="8"
          fill={isSelected ? 'hsl(var(--accent))' : 'hsl(var(--card))'}
          stroke={isSelected ? 'hsl(var(--primary))' : 'hsl(var(--border))'}
          strokeWidth={isSelected ? "3" : "1"}
          className="cursor-pointer"
          onMouseDown={(e) => handleScriptMouseDown(e, script.id)}
        />
        
        {/* En-tête avec catégorie */}
        <rect
          width={SCRIPT_WIDTH}
          height="40"
          rx="8"
          fill={categoryColor}
          opacity="0.8"
        />
        <rect
          y="32"
          width={SCRIPT_WIDTH}
          height="8"
          fill={categoryColor}
        />
        
        {/* Titre du script */}
        <text
          x="12"
          y="20"
          fontSize="14"
          fontWeight="bold"
          fill="white"
          className="select-none"
        >
          {definition.name}
        </text>
        
        {/* Badge de niveau */}
        <rect
          x={SCRIPT_WIDTH - 130}
          y="6"
          width="120"
          height="22"
          rx="11"
          fill={getLevelConfig(definition.level).bgColor}
          stroke={getLevelConfig(definition.level).color}
          strokeWidth="1"
        />
        <text
          x={SCRIPT_WIDTH - 70}
          y="19"
          fontSize="9"
          fontWeight="600"
          fill={getLevelConfig(definition.level).color}
          textAnchor="middle"
          className="select-none"
        >
          {getLevelConfig(definition.level).label}
        </text>

        {/* Description */}
        {definition.description && (
          <text
            x="12"
            y="58"
            fontSize="11"
            fill="hsl(var(--muted-foreground))"
            className="select-none"
          >
            {definition.description.length > 35 
              ? definition.description.substring(0, 35) + '...' 
              : definition.description}
          </text>
        )}

        {/* Sockets d'entrée */}
        {definition.inputs.map((input, index) => 
          renderSocket(script, definition, input, index, 'input')
        )}

        {/* Sockets de sortie */}
        {definition.outputs.map((output, index) => 
          renderSocket(script, definition, output, index, 'output')
        )}

        {/* Bouton d'exécution */}
        {onScriptExecute && (
          <g transform={`translate(${SCRIPT_WIDTH - 35}, ${SCRIPT_HEIGHT - 35})`}>
            <circle
              r="15"
              fill="hsl(var(--primary))"
              className="cursor-pointer"
              onClick={() => onScriptExecute(script.id)}
            />
            <Play 
              x="-6" 
              y="-6" 
              width="12" 
              height="12" 
              fill="white"
            />
          </g>
        )}

        {/* Indicateur de statut */}
        <g transform={`translate(12, ${SCRIPT_HEIGHT - 25})`}>
          <StatusIcon />
        </g>

        {/* Cadre de niveau au bas du script */}
        <rect
          x="0"
          y={SCRIPT_HEIGHT - 30}
          width={SCRIPT_WIDTH}
          height="30"
          fill={getLevelConfig(definition.level).bgColor}
          stroke={getLevelConfig(definition.level).color}
          strokeWidth="1"
          rx="0 0 8 8"
        />
        <text
          x={SCRIPT_WIDTH / 2}
          y={SCRIPT_HEIGHT - 10}
          fontSize="12"
          fontWeight="bold"
          fill={getLevelConfig(definition.level).color}
          textAnchor="middle"
          className="select-none"
        >
          {getLevelConfig(definition.level).label}
        </text>
      </g>
    );
  };

  // Gestionnaire de clic sur script
  const handleScriptMouseDown = (e: React.MouseEvent, scriptId: string) => {
    e.preventDefault();
    e.stopPropagation();
    
    const script = scripts.find(s => s.id === scriptId);
    if (!script) return;

    onScriptSelect(scriptId);

    const rect = containerRef.current?.getBoundingClientRect();
    if (!rect) return;

    const startPos = { x: e.clientX, y: e.clientY };
    const offset = {
      x: (e.clientX - rect.left - camera.x) / zoom - script.position.x,
      y: (e.clientY - rect.top - camera.y) / zoom - script.position.y
    };

    setDragState({
      isDragging: true,
      scriptId,
      offset,
      startPos
    });
  };

  // Gestionnaire de déplacement de la vue (pan)
  const handleCanvasMouseDown = (e: React.MouseEvent) => {
    // Seulement si clic droit ou clic gauche sur le canvas vide
    if (e.button === 2 || (e.button === 0 && e.target === e.currentTarget)) {
      e.preventDefault();
      e.stopPropagation();

      setPanState({
        isPanning: true,
        startPos: { x: e.clientX, y: e.clientY },
        startCamera: { ...camera }
      });
    }
  };

  // Gestionnaires de souris globaux
  const handleMouseMove = useCallback((e: MouseEvent) => {
    if (dragState.isDragging && dragState.scriptId && dragState.offset) {
      const rect = containerRef.current?.getBoundingClientRect();
      if (!rect) return;

      const newPosition = {
        x: (e.clientX - rect.left - camera.x) / zoom - dragState.offset.x,
        y: (e.clientY - rect.top - camera.y) / zoom - dragState.offset.y
      };

      onScriptMove(dragState.scriptId, newPosition);
    }

    if (connectionState.isConnecting) {
      const rect = containerRef.current?.getBoundingClientRect();
      if (!rect) return;

      setConnectionState(prev => ({
        ...prev,
        currentPos: {
          x: (e.clientX - rect.left - camera.x) / zoom,
          y: (e.clientY - rect.top - camera.y) / zoom
        }
      }));
    }

    if (panState.isPanning && panState.startPos && panState.startCamera) {
      const deltaX = e.clientX - panState.startPos.x;
      const deltaY = e.clientY - panState.startPos.y;

      onCameraChange({
        x: panState.startCamera.x + deltaX,
        y: panState.startCamera.y + deltaY
      });
    }
  }, [dragState, connectionState, panState, onScriptMove, onCameraChange, camera, zoom]);

  const handleMouseUp = useCallback((e: MouseEvent) => {
    if (dragState.isDragging) {
      setDragState({ isDragging: false });
    }

    if (connectionState.isConnecting) {
      // Tentative de connexion
      const element = document.elementFromPoint(e.clientX, e.clientY);
      // TODO: Implémenter la logique de connexion automatique
      setConnectionState({ isConnecting: false });
    }

    if (panState.isPanning) {
      setPanState({ isPanning: false });
    }
  }, [dragState, connectionState, panState]);

  // Gestionnaire de zoom avec la molette
  const handleWheel = useCallback((e: WheelEvent) => {
    e.preventDefault();
    
    const rect = containerRef.current?.getBoundingClientRect();
    if (!rect) return;

    // Position de la souris relative au container
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;

    // Position de la souris dans le système de coordonnées du canvas
    const worldMouseX = (mouseX - camera.x) / zoom;
    const worldMouseY = (mouseY - camera.y) / zoom;

    // Calcul du nouveau zoom
    const zoomDelta = e.deltaY > 0 ? 0.9 : 1.1;
    const newZoom = Math.max(0.1, Math.min(5.0, zoom * zoomDelta));

    // Ajustement de la caméra pour zoomer sur la position de la souris
    const newCameraX = mouseX - worldMouseX * newZoom;
    const newCameraY = mouseY - worldMouseY * newZoom;

    onCameraChange({ x: newCameraX, y: newCameraY });
    onZoomChange(newZoom);
  }, [camera, zoom, onCameraChange, onZoomChange]);

  // Effets
  useEffect(() => {
    if (dragState.isDragging || connectionState.isConnecting || panState.isPanning) {
      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);
      
      return () => {
        document.removeEventListener('mousemove', handleMouseMove);
        document.removeEventListener('mouseup', handleMouseUp);
      };
    }
  }, [dragState.isDragging, connectionState.isConnecting, panState.isPanning, handleMouseMove, handleMouseUp]);

  // Gestionnaire de la molette pour le zoom
  useEffect(() => {
    const container = containerRef.current;
    if (container) {
      container.addEventListener('wheel', handleWheel, { passive: false });
      
      return () => {
        container.removeEventListener('wheel', handleWheel);
      };
    }
  }, [handleWheel]);

  return (
    <div 
      ref={containerRef}
      className="relative w-full h-full overflow-hidden bg-gray-50 dark:bg-gray-900"
      style={{ 
        cursor: dragState.isDragging ? 'grabbing' : 
                panState.isPanning ? 'grabbing' : 'grab'
      }}
      onMouseDown={handleCanvasMouseDown}
      onContextMenu={(e) => e.preventDefault()} // Empêcher le menu contextuel
    >
      <svg
        ref={canvasRef}
        width="100%"
        height="100%"
        className="absolute inset-0"
      >
        <defs>
          <pattern id="grid" width="20" height="20" patternUnits="userSpaceOnUse">
            <path d="M 20 0 L 0 0 0 20" fill="none" stroke="currentColor" strokeWidth="0.5" opacity="0.2"/>
          </pattern>
        </defs>
        
        {/* Grille de fond */}
        <rect width="100%" height="100%" fill="url(#grid)" />
        
        {/* Groupe principal avec transformation de caméra */}
        <g transform={`translate(${camera.x}, ${camera.y}) scale(${zoom})`}>
          {/* Rendu des connexions */}
          {renderConnections()}
          
          {/* Rendu de la connexion temporaire */}
          {renderTempConnection()}
          
          {/* Rendu des scripts */}
          {scripts.map(renderScript)}
        </g>
      </svg>
    </div>
  );
};