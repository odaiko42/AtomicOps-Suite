import React, { useState } from 'react';
import { ArrowRight, Server, Lock, FileCode, Workflow, CheckCircle } from 'lucide-react';

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
    }
  };

  const connections = [
    { from: 'main', to: 'setupSSH' },
    { from: 'main', to: 'deployScript' },
    { from: 'setupSSH', to: 'generateKey' },
    { from: 'setupSSH', to: 'addKey' },
    { from: 'setupSSH', to: 'checkConn' },
    { from: 'deployScript', to: 'copyFile' },
    { from: 'deployScript', to: 'executeRemote' },
    { from: 'deployScript', to: 'iscsiTarget', remote: true },
    { from: 'iscsiTarget', to: 'detectDisk' },
    { from: 'iscsiTarget', to: 'formatDisk' },
    { from: 'iscsiTarget', to: 'getCPU' },
    { from: 'iscsiTarget', to: 'getMemory' }
  ];

  const getNodeColor = (node) => {
    if (node.status === 'missing') return 'bg-red-500';
    if (node.type === 'remote') return 'bg-purple-500';
    if (node.level === 2) return 'bg-blue-600';
    if (node.level === 1) return 'bg-blue-500';
    return 'bg-gray-700';
  };

  const getNodeIcon = (node) => {
    if (node.status === 'missing') return <FileCode className="w-4 h-4" />;
    if (node.type === 'remote') return <Server className="w-4 h-4" />;
    if (node.type === 'orchestrator') return <Workflow className="w-4 h-4" />;
    return <CheckCircle className="w-4 h-4" />;
  };

  return (
    <div className="w-full h-screen bg-gray-900 text-white p-8 overflow-auto">
      <div className="mb-6">
        <h1 className="text-3xl font-bold mb-2">Architecture Workflow SSH - Exécution à Distance</h1>
        <p className="text-gray-400">Cliquez sur un nœud pour voir les détails</p>
      </div>

      {/* Légende */}
      <div className="mb-8 flex gap-6 flex-wrap">
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
      </div>

      {/* Diagramme */}
      <div className="relative" style={{ minHeight: '700px' }}>
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
             style={{ left: '520px', top: 120, width: '300px', height: '500px' }}>
          <div className="flex items-center gap-2 mb-4">
            <Server className="w-5 h-5 text-purple-400" />
            <span className="text-purple-400 font-semibold">SERVEUR DISTANT (SSH)</span>
          </div>
        </div>

        {/* Connexions */}
        <svg className="absolute top-0 left-0 w-full h-full pointer-events-none" style={{ zIndex: 0 }}>
          {connections.map((conn, idx) => {
            const from = nodes[conn.from];
            const to = nodes[conn.to];
            const color = conn.remote ? '#a855f7' : '#60a5fa';
            const strokeWidth = conn.remote ? 3 : 2;
            
            return (
              <line
                key={idx}
                x1={from.x + 120}
                y1={from.y + 30}
                x2={to.x + 120}
                y2={to.y + 30}
                stroke={color}
                strokeWidth={strokeWidth}
                strokeDasharray={conn.remote ? "5,5" : "0"}
                markerEnd="url(#arrowhead)"
              />
            );
          })}
          <defs>
            <marker id="arrowhead" markerWidth="10" markerHeight="10" 
                    refX="9" refY="3" orient="auto">
              <polygon points="0 0, 10 3, 0 6" fill="#60a5fa" />
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
                <div className="mt-2 flex gap-2">
                  <span className="text-xs px-2 py-0.5 bg-black/30 rounded">
                    Niveau {node.level}
                  </span>
                  {node.status === 'missing' && (
                    <span className="text-xs px-2 py-0.5 bg-red-700 rounded">
                      À CRÉER
                    </span>
                  )}
                </div>
              </div>
            </div>
          </div>
        ))}

        {/* Flèche SSH */}
        <div className="absolute flex items-center gap-2" style={{ left: '480px', top: '280px' }}>
          <ArrowRight className="w-8 h-8 text-purple-400 animate-pulse" />
          <span className="text-purple-400 font-semibold">SSH</span>
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
                {nodes[selectedNode].status === 'missing' ? 'À créer' : 'Existe'}
              </span>
            </div>
            <div>
              <span className="text-gray-400">Exécution:</span>
              <span className="ml-2 font-semibold">
                {nodes[selectedNode].type === 'remote' ? 'Serveur distant' : 'Serveur local'}
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
        <h3 className="text-xl font-bold mb-4 text-red-400">⚠️ Scripts à créer (manquants)</h3>
        <ul className="space-y-2">
          <li className="flex items-center gap-2">
            <FileCode className="w-5 h-5 text-red-400" />
            <code className="bg-black/40 px-2 py-1 rounded">orchestrators/level-2/execute-workflow.remote.sh</code>
            <span className="text-sm text-gray-400">- Orchestrateur principal</span>
          </li>
          <li className="flex items-center gap-2">
            <FileCode className="w-5 h-5 text-red-400" />
            <code className="bg-black/40 px-2 py-1 rounded">orchestrators/level-1/deploy-script.remote.sh</code>
            <span className="text-sm text-gray-400">- Déploiement distant</span>
          </li>
          <li className="flex items-center gap-2">
            <FileCode className="w-5 h-5 text-red-400" />
            <code className="bg-black/40 px-2 py-1 rounded">atomics/copy-file.remote.sh</code>
            <span className="text-sm text-gray-400">- Copie SCP/rsync</span>
          </li>
          <li className="flex items-center gap-2">
            <FileCode className="w-5 h-5 text-red-400" />
            <code className="bg-black/40 px-2 py-1 rounded">atomics/execute-ssh.remote.sh</code>
            <span className="text-sm text-gray-400">- Exécution SSH</span>
          </li>
        </ul>
      </div>
    </div>
  );
};

export default SSHWorkflowDiagram;