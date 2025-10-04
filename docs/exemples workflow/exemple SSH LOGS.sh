import React, { useState } from 'react';
import { ArrowRight, Server, Lock, FileCode, Workflow, CheckCircle, FileText, Database } from 'lucide-react';

const SSHWorkflowDiagram = () => {
  const [selectedNode, setSelectedNode] = useState(null);

  const nodes = {
    // Niveau 2 - Orchestrateur principal
    main: {
      id: 'execute-workflow.remote.sh',
      level: 2,
      type: 'orchestrator',
      status: 'missing',
      description: 'Orchestre l\'exécution complète à distance',
      x: 50,
      y: 50
    },
    
    // Niveau 1 - Orchestrateurs
    setupSSH: {
      id: 'setup-ssh.access.sh',
      level: 1,
      type: 'orchestrator',
      status: 'exists',
      description: 'Configure l\'accès SSH',
      x: 50,
      y: 200
    },
    deployScript: {
      id: 'deploy-script.remote.sh',
      level: 1,
      type: 'orchestrator',
      status: 'missing',
      description: 'Déploie les scripts sur le serveur distant',
      x: 300,
      y: 200
    },
    
    // Niveau 0 - Atomiques SSH
    generateKey: {
      id: 'generate-ssh.keypair.sh',
      level: 0,
      type: 'atomic',
      status: 'exists',
      description: 'Génère la paire de clés SSH',
      x: 20,
      y: 350
    },
    addKey: {
      id: 'add-ssh.key.authorized.sh',
      level: 0,
      type: 'atomic',
      status: 'exists',
      description: 'Ajoute la clé publique',
      x: 20,
      y: 420
    },
    checkConn: {
      id: 'check-ssh.connection.sh',
      level: 0,
      type: 'atomic',
      status: 'exists',
      description: 'Vérifie la connexion SSH',
      x: 20,
      y: 490
    },
    copyFile: {
      id: 'copy-file.remote.sh',
      level: 0,
      type: 'atomic',
      status: 'missing',
      description: 'Copie fichiers via SCP',
      x: 270,
      y: 350
    },
    executeRemote: {
      id: 'execute-ssh.remote.sh',
      level: 0,
      type: 'atomic',
      status: 'missing',
      description: 'Exécute commande SSH distante',
      x: 270,
      y: 420
    },
    
    // Workflow distant
    iscsiTarget: {
      id: 'setup-iscsi-target.sh',
      level: 1,
      type: 'remote',
      status: 'exists',
      description: 'Configure iSCSI (exécuté à distance)',
      x: 550,
      y: 200
    },
    detectDisk: {
      id: 'detect-disk.sh',
      level: 0,
      type: 'remote',
      status: 'exists',
      description: 'Détecte les disques',
      x: 520,
      y: 350
    },
    formatDisk: {
      id: 'format-disk.sh',
      level: 0,
      type: 'remote',
      status: 'exists',
      description: 'Formate le disque',
      x: 520,
      y: 420
    },
    getCPU: {
      id: 'get-cpu.info.sh',
      level: 0,
      type: 'remote',
      status: 'exists',
      description: 'Infos CPU',
      x: 520,
      y: 490
    },
    getMemory: {
      id: 'get-memory.info.sh',
      level: 0,
      type: 'remote',
      status: 'exists',
      description: 'Infos mémoire',
      x: 520,
      y: 560
    },
    
    // Gestion des logs - Niveau 1
    logsCollector: {
      id: 'collect-logs.remote.sh',
      level: 1,
      type: 'orchestrator',
      status: 'missing',
      description: 'Collecte logs depuis serveur distant',
      x: 300,
      y: 700
    },
    
    // Gestion des logs - Atomiques
    fetchLogs: {
      id: 'fetch-logs.ssh.sh',
      level: 0,
      type: 'atomic',
      status: 'missing',
      description: 'Récupère logs via SSH',
      x: 270,
      y: 850
    },
    parseLogs: {
      id: 'parse-logs.json.sh',
      level: 0,
      type: 'atomic',
      status: 'missing',
      description: 'Parse logs au format JSON',
      x: 270,
      y: 920
    },
    storeLogs: {
      id: 'store-logs.centralized.sh',
      level: 0,
      type: 'atomic',
      status: 'missing',
      description: 'Stocke logs centralisés',
      x: 270,
      y: 990
    },
    
    // Serveur de logs
    logServer: {
      id: 'log-server',
      level: 'infra',
      type: 'logs',
      status: 'infra',
      description: 'Serveur centralisé de logs',
      x: 900,
      y: 700
    },
    
    // Logs distants (sur serveur cible)
    remoteLogger: {
      id: 'logger.sh (remote)',
      level: 0,
      type: 'remote-log',
      status: 'exists',
      description: 'Logger sur serveur distant',
      x: 550,
      y: 700
    }
  };

  const connections = [
    { from: 'main', to: 'setupSSH' },
    { from: 'main', to: 'deployScript' },
    { from: 'main', to: 'logsCollector', type: 'log' },
    { from: 'setupSSH', to: 'generateKey' },
    { from: 'setupSSH', to: 'addKey' },
    { from: 'setupSSH', to: 'checkConn' },
    { from: 'deployScript', to: 'copyFile' },
    { from: 'deployScript', to: 'executeRemote' },
    { from: 'deployScript', to: 'iscsiTarget', remote: true },
    { from: 'iscsiTarget', to: 'detectDisk' },
    { from: 'iscsiTarget', to: 'formatDisk' },
    { from: 'iscsiTarget', to: 'getCPU' },
    { from: 'iscsiTarget', to: 'getMemory' },
    { from: 'iscsiTarget', to: 'remoteLogger', type: 'log' },
    { from: 'logsCollector', to: 'fetchLogs' },
    { from: 'logsCollector', to: 'parseLogs' },
    { from: 'logsCollector', to: 'storeLogs' },
    { from: 'remoteLogger', to: 'fetchLogs', type: 'log', remote: true },
    { from: 'storeLogs', to: 'logServer', type: 'log' }
  ];

  const getNodeColor = (node) => {
    if (node.status === 'missing') return 'bg-red-500';
    if (node.type === 'logs' || node.type === 'remote-log') return 'bg-yellow-600';
    if (node.status === 'infra') return 'bg-green-600';
    if (node.type === 'remote') return 'bg-purple-500';
    if (node.level === 2) return 'bg-blue-600';
    if (node.level === 1) return 'bg-blue-500';
    return 'bg-gray-700';
  };

  const getNodeIcon = (node) => {
    if (node.type === 'logs' || node.type === 'remote-log') return <FileText className="w-4 h-4" />;
    if (node.status === 'infra') return <Database className="w-4 h-4" />;
    if (node.status === 'missing') return <FileCode className="w-4 h-4" />;
    if (node.type === 'remote') return <Server className="w-4 h-4" />;
    if (node.type === 'orchestrator') return <Workflow className="w-4 h-4" />;
    return <CheckCircle className="w-4 h-4" />;
  };

  const getConnectionColor = (conn) => {
    if (conn.type === 'log') return '#eab308';
    if (conn.remote) return '#a855f7';
    return '#60a5fa';
  };

  return (
    <div className="w-full h-screen bg-gray-900 text-white p-8 overflow-auto">
      <div className="mb-6">
        <h1 className="text-3xl font-bold mb-2">Architecture Workflow SSH + Gestion Logs Distants</h1>
        <p className="text-gray-400">Cliquez sur un nœud pour voir les détails</p>
      </div>

      {/* Légende */}
      <div className="mb-8 flex gap-4 flex-wrap">
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 bg-red-500 rounded"></div>
          <span className="text-sm">À créer (manquant)</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 bg-blue-600 rounded"></div>
          <span className="text-sm">Niveau 2 (existe)</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 bg-blue-500 rounded"></div>
          <span className="text-sm">Niveau 1 (existe)</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 bg-gray-700 rounded"></div>
          <span className="text-sm">Atomique local (existe)</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 bg-purple-500 rounded"></div>
          <span className="text-sm">Exécuté à distance</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 bg-yellow-600 rounded"></div>
          <span className="text-sm">Gestion logs</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 bg-green-600 rounded"></div>
          <span className="text-sm">Infrastructure</span>
        </div>
      </div>

      {/* Diagramme */}
      <div className="relative" style={{ minHeight: '1150px' }}>
        {/* Zone serveur local */}
        <div className="absolute border-2 border-blue-400 rounded-lg p-4" 
             style={{ left: 0, top: 0, width: '500px', height: '600px' }}>
          <div className="flex items-center gap-2 mb-4">
            <Lock className="w-5 h-5 text-blue-400" />
            <span className="text-blue-400 font-semibold">SERVEUR LOCAL</span>
          </div>
        </div>

        {/* Zone serveur distant */}
        <div className="absolute border-2 border-purple-400 rounded-lg p-4" 
             style={{ left: '520px', top: 120, width: '300px', height: '650px' }}>
          <div className="flex items-center gap-2 mb-4">
            <Server className="w-5 h-5 text-purple-400" />
            <span className="text-purple-400 font-semibold">SERVEUR DISTANT (SSH)</span>
          </div>
        </div>

        {/* Zone gestion logs */}
        <div className="absolute border-2 border-yellow-400 rounded-lg p-4" 
             style={{ left: 0, top: 640, width: '500px', height: '400px' }}>
          <div className="flex items-center gap-2 mb-4">
            <FileText className="w-5 h-5 text-yellow-400" />
            <span className="text-yellow-400 font-semibold">GESTION LOGS</span>
          </div>
        </div>

        {/* Zone serveur de logs */}
        <div className="absolute border-2 border-green-400 rounded-lg p-4" 
             style={{ left: '850px', top: 640, width: '300px', height: '200px' }}>
          <div className="flex items-center gap-2 mb-4">
            <Database className="w-5 h-5 text-green-400" />
            <span className="text-green-400 font-semibold">SERVEUR LOGS CENTRALISÉ</span>
          </div>
        </div>

        {/* Connexions */}
        <svg className="absolute top-0 left-0 w-full h-full pointer-events-none" style={{ zIndex: 0 }}>
          {connections.map((conn, idx) => {
            const from = nodes[conn.from];
            const to = nodes[conn.to];
            const color = getConnectionColor(conn);
            const strokeWidth = conn.type === 'log' ? 3 : conn.remote ? 3 : 2;
            const dashArray = conn.type === 'log' ? "8,4" : conn.remote ? "5,5" : "0";
            
            return (
              <line
                key={idx}
                x1={from.x + 120}
                y1={from.y + 30}
                x2={to.x + 120}
                y2={to.y + 30}
                stroke={color}
                strokeWidth={strokeWidth}
                strokeDasharray={dashArray}
                markerEnd={`url(#arrowhead-${conn.type || 'default'})`}
              />
            );
          })}
          <defs>
            <marker id="arrowhead-default" markerWidth="10" markerHeight="10" 
                    refX="9" refY="3" orient="auto">
              <polygon points="0 0, 10 3, 0 6" fill="#60a5fa" />
            </marker>
            <marker id="arrowhead-log" markerWidth="10" markerHeight="10" 
                    refX="9" refY="3" orient="auto">
              <polygon points="0 0, 10 3, 0 6" fill="#eab308" />
            </marker>
          </defs>
        </svg>

        {/* Nœuds */}
        {Object.entries(nodes).map(([key, node]) => (
          <div
            key={key}
            className={`absolute ${getNodeColor(node)} rounded-lg p-3 cursor-pointer transition-all hover:scale-105 shadow-lg`}
            style={{ 
              left: `${node.x}px`, 
              top: `${node.y}px`,
              width: '240px',
              zIndex: 10,
              border: selectedNode === key ? '3px solid yellow' : 'none'
            }}
            onClick={() => setSelectedNode(key)}
          >
            <div className="flex items-start gap-2">
              {getNodeIcon(node)}
              <div className="flex-1">
                <div className="font-semibold text-sm mb-1">{node.id}</div>
                <div className="text-xs opacity-80">{node.description}</div>
                <div className="mt-2 flex gap-2 flex-wrap">
                  {node.level !== 'infra' && (
                    <span className="text-xs px-2 py-0.5 bg-black/30 rounded">
                      Niveau {node.level}
                    </span>
                  )}
                  {node.status === 'missing' && (
                    <span className="text-xs px-2 py-0.5 bg-red-700 rounded">
                      À CRÉER
                    </span>
                  )}
                  {node.status === 'infra' && (
                    <span className="text-xs px-2 py-0.5 bg-green-700 rounded">
                      INFRA
                    </span>
                  )}
                </div>
              </div>
            </div>
          </div>
        ))}

        {/* Flèches annotées */}
        <div className="absolute flex items-center gap-2" style={{ left: '480px', top: '280px' }}>
          <ArrowRight className="w-8 h-8 text-purple-400 animate-pulse" />
          <span className="text-purple-400 font-semibold">SSH</span>
        </div>
        
        <div className="absolute flex items-center gap-2" style={{ left: '480px', top: '750px' }}>
          <ArrowRight className="w-8 h-8 text-yellow-400 animate-pulse" />
          <span className="text-yellow-400 font-semibold">LOGS</span>
        </div>

        <div className="absolute flex items-center gap-2" style={{ left: '780px', top: '750px' }}>
          <ArrowRight className="w-8 h-8 text-green-400 animate-pulse" />
          <span className="text-green-400 font-semibold">STORE</span>
        </div>
      </div>

      {/* Panneau de détails */}
      {selectedNode && (
        <div className="mt-8 bg-gray-800 rounded-lg p-6 border-2 border-blue-500">
          <h3 className="text-xl font-bold mb-4">Détails : {nodes[selectedNode].id}</h3>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <span className="text-gray-400">Type:</span>
              <span className="ml-2 font-semibold">{nodes[selectedNode].type}</span>
            </div>
            <div>
              <span className="text-gray-400">Niveau:</span>
              <span className="ml-2 font-semibold">{nodes[selectedNode].level}</span>
            </div>
            <div>
              <span className="text-gray-400">Statut:</span>
              <span className={`ml-2 font-semibold ${nodes[selectedNode].status === 'missing' ? 'text-red-400' : 'text-green-400'}`}>
                {nodes[selectedNode].status === 'missing' ? 'À créer' : nodes[selectedNode].status === 'infra' ? 'Infrastructure' : 'Existe'}
              </span>
            </div>
            <div>
              <span className="text-gray-400">Exécution:</span>
              <span className="ml-2 font-semibold">
                {nodes[selectedNode].type === 'remote' || nodes[selectedNode].type === 'remote-log' ? 'Serveur distant' : nodes[selectedNode].type === 'logs' ? 'Serveur logs' : 'Serveur local'}
              </span>
            </div>
          </div>
          <div className="mt-4">
            <span className="text-gray-400">Description:</span>
            <p className="mt-1">{nodes[selectedNode].description}</p>
          </div>
        </div>
      )}

      {/* Scripts manquants */}
      <div className="mt-8 bg-red-900/20 border-2 border-red-500 rounded-lg p-6">
        <h3 className="text-xl font-bold mb-4 text-red-400">⚠️ Scripts à créer pour SSH + Logs</h3>
        <div className="grid md:grid-cols-2 gap-4">
          <div>
            <h4 className="font-semibold mb-2 text-blue-300">SSH / Exécution distante:</h4>
            <ul className="space-y-2">
              <li className="flex items-center gap-2 text-sm">
                <FileCode className="w-4 h-4 text-red-400" />
                <code className="bg-black/40 px-2 py-1 rounded text-xs">execute-workflow.remote.sh</code>
              </li>
              <li className="flex items-center gap-2 text-sm">
                <FileCode className="w-4 h-4 text-red-400" />
                <code className="bg-black/40 px-2 py-1 rounded text-xs">deploy-script.remote.sh</code>
              </li>
              <li className="flex items-center gap-2 text-sm">
                <FileCode className="w-4 h-4 text-red-400" />
                <code className="bg-black/40 px-2 py-1 rounded text-xs">copy-file.remote.sh</code>
              </li>
              <li className="flex items-center gap-2 text-sm">
                <FileCode className="w-4 h-4 text-red-400" />
                <code className="bg-black/40 px-2 py-1 rounded text-xs">execute-ssh.remote.sh</code>
              </li>
            </ul>
          </div>
          <div>
            <h4 className="font-semibold mb-2 text-yellow-300">Gestion des logs:</h4>
            <ul className="space-y-2">
              <li className="flex items-center gap-2 text-sm">
                <FileCode className="w-4 h-4 text-red-400" />
                <code className="bg-black/40 px-2 py-1 rounded text-xs">collect-logs.remote.sh</code>
              </li>
              <li className="flex items-center gap-2 text-sm">
                <FileCode className="w-4 h-4 text-red-400" />
                <code className="bg-black/40 px-2 py-1 rounded text-xs">fetch-logs.ssh.sh</code>
              </li>
              <li className="flex items-center gap-2 text-sm">
                <FileCode className="w-4 h-4 text-red-400" />
                <code className="bg-black/40 px-2 py-1 rounded text-xs">parse-logs.json.sh</code>
              </li>
              <li className="flex items-center gap-2 text-sm">
                <FileCode className="w-4 h-4 text-red-400" />
                <code className="bg-black/40 px-2 py-1 rounded text-xs">store-logs.centralized.sh</code>
              </li>
            </ul>
          </div>
        </div>
      </div>

      {/* Flux de logs */}
      <div className="mt-8 bg-yellow-900/20 border-2 border-yellow-500 rounded-lg p-6">
        <h3 className="text-xl font-bold mb-4 text-yellow-400">📊 Flux de gestion des logs</h3>
        <ol className="space-y-3">
          <li className="flex items-start gap-3">
            <span className="bg-yellow-600 text-white rounded-full w-6 h-6 flex items-center justify-center text-sm font-bold flex-shrink-0">1</span>
            <div>
              <strong>Génération logs sur serveur distant</strong>
              <p className="text-sm text-gray-400">Les scripts distants utilisent logger.sh pour générer des logs JSON</p>
            </div>
          </li>
          <li className="flex items-start gap-3">
            <span className="bg-yellow-600 text-white rounded-full w-6 h-6 flex items-center justify-center text-sm font-bold flex-shrink-0">2</span>
            <div>
              <strong>Collecte via SSH</strong>
              <p className="text-sm text-gray-400">fetch-logs.ssh.sh récupère les logs du serveur distant</p>
            </div>
          </li>
          <li className="flex items-start gap-3">
            <span className="bg-yellow-600 text-white rounded-full w-6 h-6 flex items-center justify-center text-sm font-bold flex-shrink-0">3</span>
            <div>
              <strong>Parsing et normalisation</strong>
              <p className="text-sm text-gray-400">parse-logs.json.sh structure les logs au format standard</p>
            </div>
          </li>
          <li className="flex items-start gap-3">
            <span className="bg-yellow-600 text-white rounded-full w-6 h-6 flex items-center justify-center text-sm font-bold flex-shrink-0">4</span>
            <div>
              <strong>Stockage centralisé</strong>
              <p className="text-sm text-gray-400">store-logs.centralized.sh envoie vers serveur de logs (Elasticsearch, Loki, etc.)</p>
            </div>
          </li>
        </ol>
      </div>
    </div>
  );
};

export default SSHWorkflowDiagram;