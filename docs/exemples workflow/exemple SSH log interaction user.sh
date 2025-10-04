import React, { useState } from 'react';
import { ArrowRight, Server, Lock, FileCode, Workflow, CheckCircle, FileText, Database, User, Keyboard } from 'lucide-react';

const SSHWorkflowDiagram = () => {
  const [selectedNode, setSelectedNode] = useState(null);
  const [showUserInputOnly, setShowUserInputOnly] = useState(false);

  const nodes = {
    // Point d'entrée utilisateur - NIVEAU 2
    main: {
      id: 'execute-workflow.remote.sh',
      level: 2,
      type: 'orchestrator',
      status: 'exists',
      description: 'Exécution de workflow complet distant - Orchestrateur Niveau 2',
      userInput: true,
      inputs: [
        '--host <IP/hostname> (obligatoire)',
        '--workflow-name <nom-workflow> (obligatoire)',
        '--scripts <liste-scripts> (obligatoire)',
        '--execution-mode [sequential|parallel] (défaut: sequential)',
        '--setup-ssh [true|false] (défaut: false)',
        '--timeout <secondes> (défaut: 600)',
        '--rollback-on-failure [true|false] (défaut: true)'
      ],
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
      userInput: true,
      inputs: [
        '--host <IP>',
        '--user <username>',
        '--key-type [rsa|ed25519] (défaut: ed25519)',
        '--key-size <bits> (défaut: 4096)'
      ],
      x: 50,
      y: 200
    },
    deployScript: {
      id: 'deploy-script.remote.sh',
      level: 1,
      type: 'orchestrator',
      status: 'exists',
      description: 'Déploie et exécute un script distant - Orchestrateur Niveau 1',
      userInput: true,
      inputs: [
        '--host <IP/hostname> (obligatoire)',
        '--script-path <chemin-script-local> (obligatoire)',
        '--workdir <repertoire-distant> (défaut: /tmp)',
        '--args <arguments-script> (optionnel)',
        '--timeout <secondes> (défaut: 300)',
        '--cleanup [true|false] (défaut: true)'
      ],
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
      userInput: true,
      inputs: [
        '--type [rsa|ed25519]',
        '--bits <size>',
        '--comment <texte>',
        '--output <path> (optionnel)'
      ],
      x: 20,
      y: 350
    },
    addKey: {
      id: 'add-ssh.key.authorized.sh',
      level: 0,
      type: 'atomic',
      status: 'exists',
      description: 'Ajoute la clé publique',
      userInput: true,
      inputs: [
        '--user <username>',
        '--key <public-key-content>',
        '--host <hostname> (optionnel)'
      ],
      x: 20,
      y: 420
    },
    checkConn: {
      id: 'check-ssh.connection.sh',
      level: 0,
      type: 'atomic',
      status: 'exists',
      description: 'Vérifie la connexion SSH',
      userInput: true,
      inputs: [
        '--host <IP>',
        '--port <port> (défaut: 22)',
        '--user <username>',
        '--timeout <seconds> (défaut: 10)'
      ],
      x: 20,
      y: 490
    },
    copyFile: {
      id: 'copy-file.remote.sh',
      level: 0,
      type: 'atomic',
      status: 'exists',
      description: 'Copie de fichiers vers/depuis un hôte distant via SCP/SFTP/rsync - Script Atomique Niveau 0',
      userInput: true,
      inputs: [
        '--host <IP/hostname> (obligatoire)',
        '--local-path <chemin-local> (obligatoire)',
        '--remote-path <chemin-distant> (obligatoire)',
        '--method [scp|sftp|rsync] (défaut: scp)',
        '--direction [upload|download|sync] (défaut: upload)',
        '--verify-checksum [true|false] (défaut: true)',
        '--recursive [true|false] (défaut: false)'
      ],
      x: 270,
      y: 350
    },
    executeRemote: {
      id: 'execute-ssh.remote.sh',
      level: 0,
      type: 'atomic',
      status: 'exists',
      description: 'Exécution de commandes SSH distantes avec récupération JSON - Script Atomique Niveau 0',
      userInput: true,
      inputs: [
        '--host <IP/hostname> (obligatoire)',
        '--command <commande> (obligatoire)',
        '--port <port> (défaut: 22)',
        '--user <username> (défaut: current_user)',
        '--identity <clé-privée> (optionnel)',
        '--timeout <secondes> (défaut: 30)',
        '--retries <nombre> (défaut: 3)',
        '--script-file <fichier-script> (optionnel)'
      ],
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
      userInput: true,
      inputs: [
        '--disk <device>',
        '--target-iqn <iqn>',
        '--portal-ip <ip> (optionnel)',
        '--lun-id <id> (défaut: 0)'
      ],
      x: 550,
      y: 200
    },
    detectDisk: {
      id: 'detect-disk.sh',
      level: 0,
      type: 'remote',
      status: 'exists',
      description: 'Détecte les disques',
      userInput: false,
      inputs: [],
      x: 520,
      y: 350
    },
    formatDisk: {
      id: 'format-disk.sh',
      level: 0,
      type: 'remote',
      status: 'exists',
      description: 'Formate le disque',
      userInput: true,
      inputs: [
        '--device <device>',
        '--filesystem [ext4|xfs|btrfs]',
        '--label <name> (optionnel)',
        '--force (optionnel)'
      ],
      x: 520,
      y: 420
    },
    getCPU: {
      id: 'get-cpu.info.sh',
      level: 0,
      type: 'remote',
      status: 'exists',
      description: 'Infos CPU',
      userInput: false,
      inputs: [],
      x: 520,
      y: 490
    },
    getMemory: {
      id: 'get-memory.info.sh',
      level: 0,
      type: 'remote',
      status: 'exists',
      description: 'Infos mémoire',
      userInput: false,
      inputs: [],
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
      userInput: true,
      inputs: [
        '--host <IP>',
        '--log-path <path> (défaut: /var/log/scripts)',
        '--since <timestamp> (optionnel)',
        '--filter <pattern> (optionnel)'
      ],
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
      userInput: false,
      inputs: [],
      x: 270,
      y: 850
    },
    parseLogs: {
      id: 'parse-logs.json.sh',
      level: 0,
      type: 'atomic',
      status: 'missing',
      description: 'Parse logs au format JSON',
      userInput: false,
      inputs: [],
      x: 270,
      y: 920
    },
    storeLogs: {
      id: 'store-logs.centralized.sh',
      level: 0,
      type: 'atomic',
      status: 'missing',
      description: 'Stocke logs centralisés',
      userInput: true,
      inputs: [
        '--server <url>',
        '--index <name>',
        '--auth-token <token> (optionnel)',
        '--retention <days> (optionnel)'
      ],
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
      userInput: false,
      inputs: [],
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
      userInput: false,
      inputs: [],
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
    if (node.userInput && showUserInputOnly) return 'bg-orange-500 ring-4 ring-orange-300';
    if (node.userInput) return 'bg-orange-500';
    if (node.status === 'missing') return 'bg-red-500';
    if (node.type === 'logs' || node.type === 'remote-log') return 'bg-yellow-600';
    if (node.status === 'infra') return 'bg-green-600';
    if (node.type === 'remote') return 'bg-purple-500';
    if (node.level === 2) return 'bg-blue-600';
    if (node.level === 1) return 'bg-blue-500';
    return 'bg-gray-700';
  };

  const getNodeIcon = (node) => {
    if (node.userInput) return <Keyboard className="w-4 h-4" />;
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

  const userInputNodes = Object.entries(nodes).filter(([_, node]) => node.userInput);

  return (
    <div className="w-full h-screen bg-gray-900 text-white p-8 overflow-auto">
      <div className="mb-6">
        <h1 className="text-3xl font-bold mb-2">Points d'Interaction Utilisateur - Workflow SSH</h1>
        <p className="text-gray-400">Scripts nécessitant des paramètres utilisateur</p>
      </div>

      {/* Toggle */}
      <div className="mb-6">
        <label className="flex items-center gap-3 cursor-pointer w-fit">
          <input 
            type="checkbox" 
            checked={showUserInputOnly}
            onChange={(e) => setShowUserInputOnly(e.target.checked)}
            className="w-5 h-5"
          />
          <span className="text-lg">Mettre en évidence les scripts nécessitant une saisie utilisateur</span>
        </label>
      </div>

      {/* Légende */}
      <div className="mb-8 flex gap-4 flex-wrap">
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 bg-orange-500 rounded"></div>
          <span className="text-sm font-bold">Saisie utilisateur requise</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 bg-red-500 rounded"></div>
          <span className="text-sm">À créer (manquant)</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 bg-purple-500 rounded"></div>
          <span className="text-sm">Exécuté à distance</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 bg-yellow-600 rounded"></div>
          <span className="text-sm">Gestion logs</span>
        </div>
      </div>

      {/* Résumé des inputs utilisateur */}
      <div className="mb-8 bg-orange-900/20 border-2 border-orange-500 rounded-lg p-6">
        <h3 className="text-xl font-bold mb-4 text-orange-400 flex items-center gap-2">
          <User className="w-6 h-6" />
          Scripts nécessitant une saisie utilisateur ({userInputNodes.length})
        </h3>
        <div className="grid md:grid-cols-2 gap-4">
          {userInputNodes.map(([key, node]) => (
            <div key={key} className="bg-gray-800 rounded p-4 border border-orange-600/30">
              <div className="flex items-center gap-2 mb-2">
                <Keyboard className="w-5 h-5 text-orange-400" />
                <h4 className="font-semibold text-orange-300">{node.id}</h4>
              </div>
              <ul className="space-y-1 text-sm">
                {node.inputs.map((input, idx) => (
                  <li key={idx} className="text-gray-300 flex items-start gap-2">
                    <span className="text-orange-400">•</span>
                    <code className="bg-black/40 px-1 rounded">{input}</code>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>

      {/* Diagramme */}
      <div className="relative" style={{ minHeight: '1150px', opacity: showUserInputOnly ? 0.6 : 1 }}>
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
              border: selectedNode === key ? '3px solid yellow' : 'none',
              opacity: showUserInputOnly && !node.userInput ? 0.3 : 1
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
                  {node.userInput && (
                    <span className="text-xs px-2 py-0.5 bg-orange-700 rounded flex items-center gap-1">
                      <User className="w-3 h-3" />
                      INPUT
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
          <div className="grid grid-cols-2 gap-4 mb-4">
            <div>
              <span className="text-gray-400">Type:</span>
              <span className="ml-2 font-semibold">{nodes[selectedNode].type}</span>
            </div>
            <div>
              <span className="text-gray-400">Saisie utilisateur:</span>
              <span className={`ml-2 font-semibold ${nodes[selectedNode].userInput ? 'text-orange-400' : 'text-gray-500'}`}>
                {nodes[selectedNode].userInput ? 'Oui' : 'Non'}
              </span>
            </div>
          </div>
          <div className="mt-4">
            <span className="text-gray-400">Description:</span>
            <p className="mt-1">{nodes[selectedNode].description}</p>
          </div>
          {nodes[selectedNode].userInput && nodes[selectedNode].inputs.length > 0 && (
            <div className="mt-4">
              <span className="text-gray-400">Paramètres requis:</span>
              <ul className="mt-2 space-y-1">
                {nodes[selectedNode].inputs.map((input, idx) => (
                  <li key={idx} className="text-sm">
                    <code className="bg-black/40 px-2 py-1 rounded">{input}</code>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default SSHWorkflowDiagram;