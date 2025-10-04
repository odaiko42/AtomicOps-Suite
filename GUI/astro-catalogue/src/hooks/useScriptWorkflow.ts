import { useState, useCallback, useMemo } from 'react';
import { 
  ScriptInstance, 
  ScriptConnection, 
  ScriptDefinition, 
  Point2D, 
  WorkflowData,
  ScriptDataType 
} from '@/types/script-flow';
import { allMockScripts } from '@/data/mockData';

// Générer des définitions de scripts à partir des données existantes
const generateScriptDefinitions = (): ScriptDefinition[] => {
  return allMockScripts.map((script, index) => ({
    id: script.id,
    name: script.name,
    category: script.category || 'utility',
    level: typeof script.level === 'number' 
      ? (script.level === 0 ? 'atomic' : script.level === 1 ? 'orchestrator' : 'main')
      : script.level.toString(),
    description: script.description,
    path: script.path,
    inputs: [
      // Entrées basées sur les inputs du script
      ...(script.inputs?.map((input, idx) => ({
        name: input,
        type: ScriptDataType.STRING,
        required: false,
        description: `Entrée ${input}`
      })) || []),
      // Entrées standard pour les scripts
      { name: 'trigger', type: ScriptDataType.ANY, required: false, description: 'Déclencheur d\'exécution' }
    ],
    outputs: [
      // Sorties basées sur les outputs du script
      ...(script.outputs?.map((output, idx) => ({
        name: output,
        type: ScriptDataType.STRING,
        required: true,
        description: `Sortie ${output}`
      })) || []),
      // Sorties standard pour tous les scripts
      { name: 'exit_code', type: ScriptDataType.EXIT_CODE, required: true, description: 'Code de retour' },
      { name: 'stdout', type: ScriptDataType.STRING, required: true, description: 'Sortie standard' },
      { name: 'stderr', type: ScriptDataType.STRING, required: false, description: 'Sortie d\'erreur' },
      // Sorties spécifiques selon la catégorie
      ...(script.category === 'performance' ? [
        { name: 'metrics', type: ScriptDataType.JSON, required: true, description: 'Métriques de performance' }
      ] : []),
      ...(script.category === 'file' ? [
        { name: 'file_path', type: ScriptDataType.FILE, required: true, description: 'Chemin du fichier généré' }
      ] : []),
      ...(script.category === 'network' ? [
        { name: 'network_data', type: ScriptDataType.JSON, required: true, description: 'Données réseau' }
      ] : [])
    ],
    parameters: script.functions?.flatMap(func => 
      func.inputs.map(input => ({
        name: input,
        type: 'string',
        defaultValue: '',
        description: `Paramètre ${input} de ${func.name}`
      }))
    ) || [],
    color: script.category === 'performance' ? '#d946ef' : undefined,
    icon: script.category
  }));
};

export const useScriptWorkflow = () => {
  const [scripts, setScripts] = useState<ScriptInstance[]>([]);
  const [connections, setConnections] = useState<ScriptConnection[]>([]);
  const [selectedScriptId, setSelectedScriptId] = useState<string>();
  const [zoom, setZoom] = useState(1);
  const [camera, setCamera] = useState({ x: 0, y: 0 });

  // Définitions de scripts disponibles
  const scriptDefinitions = useMemo(() => generateScriptDefinitions(), []);

  // Charger un exemple de workflow
  const loadExampleWorkflow = useCallback(() => {
    // Effacer le workflow actuel
    setScripts([]);
    setConnections([]);
    setSelectedScriptId(undefined);

    // Scripts atomiques (niveau 0)
    const script1: ScriptInstance = {
      id: 'example_1',
      definitionId: 'script_004', // select-disk.sh (atomic)
      position: { x: 100, y: 100 },
      parameters: new Map([['format', 'json']]),
      status: 'idle'
    };

    const script2: ScriptInstance = {
      id: 'example_2', 
      definitionId: 'perf_001', // get-cpu.info.sh (atomic)
      position: { x: 100, y: 320 },
      parameters: new Map([['format', 'json']]),
      status: 'idle'
    };

    const script3: ScriptInstance = {
      id: 'example_3',
      definitionId: 'perf_002', // get-memory.info.sh (atomic)
      position: { x: 100, y: 540 },
      parameters: new Map([['detail_level', 'full']]),
      status: 'idle'
    };

    // Script orchestrateur niveau 1 (connecté aux atomiques)
    const script4: ScriptInstance = {
      id: 'example_4',
      definitionId: 'script_005', // format-disk.sh (orchestrator niveau 1)
      position: { x: 500, y: 200 },
      parameters: new Map([['vg_name', 'data_vg']]),
      status: 'idle'
    };

    // Script orchestrateur niveau 2 (connecté à l'orchestrateur niveau 1)
    const script5: ScriptInstance = {
      id: 'example_5',
      definitionId: 'script_003', // setup-iscsi-target.sh (orchestrator niveau 2)
      position: { x: 900, y: 300 },
      parameters: new Map([['target_iqn', 'iqn.2025-10.local:target1']]),
      status: 'idle'
    };

    // Script principal niveau 3 (connecté aux orchestrateurs)
    const script6: ScriptInstance = {
      id: 'example_6',
      definitionId: 'script_006', // ct-launcher.sh (main niveau 3)
      position: { x: 1300, y: 250 },
      parameters: new Map([['ct_type', 'web']]),
      status: 'idle'
    };

    // Connexions entre les scripts
    const connections: ScriptConnection[] = [
      // Script atomique select-disk -> format-disk
      {
        id: 'conn_1',
        sourceScriptId: 'example_1',
        sourceSocket: 'stdout',
        targetScriptId: 'example_4', 
        targetSocket: 'trigger',
        type: ScriptDataType.STRING
      },
      // Script atomique cpu-info -> format-disk
      {
        id: 'conn_2',
        sourceScriptId: 'example_2',
        sourceSocket: 'stdout',
        targetScriptId: 'example_4',
        targetSocket: 'trigger', 
        type: ScriptDataType.JSON
      },
      // Script orchestrateur format-disk -> setup-iscsi
      {
        id: 'conn_3',
        sourceScriptId: 'example_4',
        sourceSocket: 'stdout',
        targetScriptId: 'example_5',
        targetSocket: 'trigger',
        type: ScriptDataType.STRING
      },
      // Script memory-info -> setup-iscsi (connexion directe)
      {
        id: 'conn_4',
        sourceScriptId: 'example_3',
        sourceSocket: 'stdout',
        targetScriptId: 'example_5',
        targetSocket: 'trigger',
        type: ScriptDataType.JSON
      },
      // Script orchestrateur setup-iscsi -> ct-launcher
      {
        id: 'conn_5',
        sourceScriptId: 'example_5',
        sourceSocket: 'stdout',
        targetScriptId: 'example_6',
        targetSocket: 'trigger',
        type: ScriptDataType.STRING
      }
    ];

    // Appliquer l'exemple
    setScripts([script1, script2, script3, script4, script5, script6]);
    setConnections(connections);
    
    // Centrer la vue sur le workflow
    setTimeout(() => {
      setCamera({ x: -200, y: -50 });
      setZoom(0.8);
    }, 100);
  }, []);

  // Ajouter un script au workflow
  const addScript = useCallback((definition: ScriptDefinition, position: Point2D): ScriptInstance => {
    const newScript: ScriptInstance = {
      id: `script_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      definitionId: definition.id,
      position,
      parameters: new Map(
        definition.parameters.map(p => [p.name, p.defaultValue])
      ),
      status: 'idle'
    };

    setScripts(prev => [...prev, newScript]);
    return newScript;
  }, []);

  // Supprimer un script
  const removeScript = useCallback((scriptId: string) => {
    setScripts(prev => prev.filter(s => s.id !== scriptId));
    setConnections(prev => prev.filter(c => 
      c.sourceScriptId !== scriptId && c.targetScriptId !== scriptId
    ));
    if (selectedScriptId === scriptId) {
      setSelectedScriptId(undefined);
    }
  }, [selectedScriptId]);

  // Déplacer un script
  const moveScript = useCallback((scriptId: string, position: Point2D) => {
    setScripts(prev => prev.map(script => 
      script.id === scriptId ? { ...script, position } : script
    ));
  }, []);

  // Sélectionner un script
  const selectScript = useCallback((scriptId: string) => {
    setSelectedScriptId(scriptId);
  }, []);

  // Ajouter une connexion
  const addConnection = useCallback((connection: Omit<ScriptConnection, 'id'>) => {
    const newConnection: ScriptConnection = {
      ...connection,
      id: `conn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
    };

    setConnections(prev => [...prev, newConnection]);
    return newConnection;
  }, []);

  // Supprimer une connexion
  const removeConnection = useCallback((connectionId: string) => {
    setConnections(prev => prev.filter(c => c.id !== connectionId));
  }, []);

  // Mettre à jour un paramètre de script
  const updateScriptParameter = useCallback((scriptId: string, paramName: string, value: any) => {
    setScripts(prev => prev.map(script => {
      if (script.id === scriptId) {
        const newParameters = new Map(script.parameters);
        newParameters.set(paramName, value);
        return { ...script, parameters: newParameters };
      }
      return script;
    }));
  }, []);

  // Obtenir un script sélectionné
  const getSelectedScript = useCallback((): ScriptInstance | undefined => {
    return scripts.find(s => s.id === selectedScriptId);
  }, [scripts, selectedScriptId]);

  // Obtenir la définition d'un script sélectionné
  const getSelectedScriptDefinition = useCallback((): ScriptDefinition | undefined => {
    const script = getSelectedScript();
    if (!script) return undefined;
    return scriptDefinitions.find(def => def.id === script.definitionId);
  }, [getSelectedScript, scriptDefinitions]);

  // Effacer le workflow
  const clearWorkflow = useCallback(() => {
    setScripts([]);
    setConnections([]);
    setSelectedScriptId(undefined);
  }, []);

  // Exporter le workflow
  const exportWorkflow = useCallback((): WorkflowData => {
    return {
      scripts,
      connections,
      metadata: {
        name: 'Workflow AtomicOps-Suite',
        description: 'Workflow de scripts généré avec Script Builder',
        version: '1.0',
        created: new Date().toISOString(),
        modified: new Date().toISOString()
      }
    };
  }, [scripts, connections]);

  // Importer un workflow
  const importWorkflow = useCallback((workflowData: WorkflowData) => {
    setScripts(workflowData.scripts || []);
    setConnections(workflowData.connections || []);
    setSelectedScriptId(undefined);
  }, []);

  // Contrôles de zoom
  const zoomIn = useCallback(() => {
    setZoom(prev => Math.min(prev * 1.2, 3));
  }, []);

  const zoomOut = useCallback(() => {
    setZoom(prev => Math.max(prev / 1.2, 0.1));
  }, []);

  const resetView = useCallback(() => {
    setZoom(1);
    setCamera({ x: 0, y: 0 });
  }, []);

  const updateZoom = useCallback((newZoom: number) => {
    setZoom(Math.max(0.1, Math.min(5.0, newZoom)));
  }, []);

  // Recentrer la vue sur les scripts
  const recenterView = useCallback(() => {
    if (scripts.length === 0) {
      setCamera({ x: 0, y: 0 });
      return;
    }

    const bounds = scripts.reduce((acc, script) => ({
      minX: Math.min(acc.minX, script.position.x),
      maxX: Math.max(acc.maxX, script.position.x + 280),
      minY: Math.min(acc.minY, script.position.y),
      maxY: Math.max(acc.maxY, script.position.y + 180)
    }), {
      minX: scripts[0].position.x,
      maxX: scripts[0].position.x + 280,
      minY: scripts[0].position.y,
      maxY: scripts[0].position.y + 180
    });

    const centerX = (bounds.minX + bounds.maxX) / 2;
    const centerY = (bounds.minY + bounds.maxY) / 2;

    setCamera({ x: -centerX + 400, y: -centerY + 300 });
  }, [scripts]);

  // Exécuter un script
  const executeScript = useCallback(async (scriptId: string) => {
    setScripts(prev => prev.map(script => 
      script.id === scriptId 
        ? { ...script, status: 'running' } 
        : script
    ));

    // Simulation d'exécution
    setTimeout(() => {
      setScripts(prev => prev.map(script => 
        script.id === scriptId 
          ? { 
              ...script, 
              status: Math.random() > 0.1 ? 'completed' : 'error',
              logs: [
                `[INFO] Exécution du script ${script.definitionId}`,
                `[INFO] Paramètres: ${JSON.stringify(Object.fromEntries(script.parameters))}`,
                Math.random() > 0.1 
                  ? '[SUCCESS] Script exécuté avec succès'
                  : '[ERROR] Erreur lors de l\'exécution'
              ]
            } 
          : script
      ));
    }, 2000 + Math.random() * 3000);
  }, []);

  // Exécuter tout le workflow
  const executeWorkflow = useCallback(() => {
    // TODO: Implémenter l'exécution séquentielle basée sur les connexions
    scripts.forEach(script => {
      executeScript(script.id);
    });
  }, [scripts, executeScript]);

  // Valider le workflow
  const validateWorkflow = useCallback(() => {
    const errors: string[] = [];
    
    // Vérifier les connexions
    connections.forEach(conn => {
      const sourceScript = scripts.find(s => s.id === conn.sourceScriptId);
      const targetScript = scripts.find(s => s.id === conn.targetScriptId);
      
      if (!sourceScript || !targetScript) {
        errors.push(`Connexion invalide: ${conn.id}`);
      }
    });

    // Vérifier les paramètres requis
    scripts.forEach(script => {
      const definition = scriptDefinitions.find(def => def.id === script.definitionId);
      if (definition) {
        definition.parameters.forEach(param => {
          if (param.defaultValue === undefined && !script.parameters.has(param.name)) {
            errors.push(`Paramètre requis manquant: ${param.name} pour ${definition.name}`);
          }
        });
      }
    });

    return {
      isValid: errors.length === 0,
      errors
    };
  }, [scripts, connections, scriptDefinitions]);

  return {
    // État
    scripts,
    connections,
    selectedScriptId,
    scriptDefinitions,
    zoom,
    camera,
    
    // Actions sur les scripts
    addScript,
    removeScript,
    moveScript,
    selectScript,
    
    // Actions sur les connexions
    addConnection,
    removeConnection,
    
    // Paramètres
    updateScriptParameter,
    
    // Sélection
    getSelectedScript,
    getSelectedScriptDefinition,
    
    // Workflow
    clearWorkflow,
    exportWorkflow,
    importWorkflow,
    loadExampleWorkflow,
    
    // Vue
    zoomIn,
    zoomOut,
    resetView,
    recenterView,
    setCamera,
    updateZoom,
    
    // Exécution
    executeScript,
    executeWorkflow,
    validateWorkflow
  };
};