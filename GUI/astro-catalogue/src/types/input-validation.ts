// Types pour les paramètres d'input et validation des valeurs

export enum ValidationType {
  IP = 'ip',
  HOSTNAME = 'hostname', 
  EMAIL = 'email',
  URL = 'url',
  IQN = 'iqn',
  USERNAME = 'username',
  PATH = 'path',
  DEVICE = 'device',
  PORT = 'port',
  NUMBER = 'number',
  STRING = 'string',
  BOOLEAN = 'boolean',
  ENUM = 'enum'
}

export interface InputParameter {
  name: string;
  label: string;
  type: ValidationType;
  required: boolean;
  defaultValue?: string;
  enumValues?: string[];
  placeholder?: string;
  description?: string;
  validation?: {
    min?: number;
    max?: number;
    pattern?: string;
    customValidator?: (value: string) => boolean;
  };
}

export interface ValueBox {
  id: string;
  type: ValidationType;
  value: string;
  isValid: boolean;
  position: Point2D;
  label: string;
  description?: string;
  connectedTo: string[]; // IDs des scripts connectés
}

export interface AttachmentPoint {
  id: string;
  parameterId: string;
  type: ValidationType;
  required: boolean;
  position: { x: number; y: number }; // Position relative sur le script
  isConnected: boolean;
  connectedValueBoxId?: string;
}

export interface Point2D {
  x: number;
  y: number;
}

// Validation functions
export const ValidationRules = {
  [ValidationType.IP]: {
    pattern: /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/,
    validate: (value: string) => ValidationRules[ValidationType.IP].pattern.test(value),
    placeholder: "192.168.1.100"
  },
  [ValidationType.HOSTNAME]: {
    pattern: /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/,
    validate: (value: string) => ValidationRules[ValidationType.HOSTNAME].pattern.test(value),
    placeholder: "server.example.com"
  },
  [ValidationType.EMAIL]: {
    pattern: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
    validate: (value: string) => ValidationRules[ValidationType.EMAIL].pattern.test(value),
    placeholder: "admin@company.com"
  },
  [ValidationType.URL]: {
    pattern: /^https?:\/\/[^\s/$.?#].[^\s]*$/,
    validate: (value: string) => ValidationRules[ValidationType.URL].pattern.test(value),
    placeholder: "https://api.server.com"
  },
  [ValidationType.IQN]: {
    pattern: /^iqn\.\d{4}-\d{2}\.([a-zA-Z0-9-]+\.)*[a-zA-Z0-9-]+:[a-zA-Z0-9._-]+$/,
    validate: (value: string) => ValidationRules[ValidationType.IQN].pattern.test(value),
    placeholder: "iqn.2025-01.com.example:target1"
  },
  [ValidationType.USERNAME]: {
    pattern: /^[a-zA-Z0-9._-]{3,32}$/,
    validate: (value: string) => ValidationRules[ValidationType.USERNAME].pattern.test(value),
    placeholder: "username"
  },
  [ValidationType.PATH]: {
    pattern: /^\/[a-zA-Z0-9._/-]*$/,
    validate: (value: string) => ValidationRules[ValidationType.PATH].pattern.test(value) || value.startsWith('./'),
    placeholder: "/path/to/file"
  },
  [ValidationType.DEVICE]: {
    pattern: /^\/dev\/[a-zA-Z0-9]+$/,
    validate: (value: string) => ValidationRules[ValidationType.DEVICE].pattern.test(value),
    placeholder: "/dev/sdb1"
  },
  [ValidationType.PORT]: {
    validate: (value: string) => {
      const num = parseInt(value);
      return !isNaN(num) && num >= 1 && num <= 65535;
    },
    placeholder: "22"
  },
  [ValidationType.NUMBER]: {
    validate: (value: string) => !isNaN(Number(value)),
    placeholder: "42"
  },
  [ValidationType.STRING]: {
    validate: (value: string) => value.length > 0,
    placeholder: "text value"
  },
  [ValidationType.BOOLEAN]: {
    validate: (value: string) => ['true', 'false', '1', '0', 'yes', 'no'].includes(value.toLowerCase()),
    placeholder: "true"
  },
  [ValidationType.ENUM]: {
    validate: (value: string, enumValues?: string[]) => enumValues ? enumValues.includes(value) : false,
    placeholder: "option"
  }
};

// Couleurs pour les types de validation
export const VALIDATION_TYPE_COLORS = {
  [ValidationType.IP]: '#3B82F6',      // Bleu
  [ValidationType.HOSTNAME]: '#10B981', // Vert
  [ValidationType.EMAIL]: '#F59E0B',    // Orange
  [ValidationType.URL]: '#8B5CF6',      // Violet
  [ValidationType.IQN]: '#EF4444',      // Rouge
  [ValidationType.USERNAME]: '#06B6D4', // Cyan
  [ValidationType.PATH]: '#84CC16',     // Lime
  [ValidationType.DEVICE]: '#F97316',   // Orange foncé
  [ValidationType.PORT]: '#14B8A6',     // Teal
  [ValidationType.NUMBER]: '#6366F1',   // Indigo
  [ValidationType.STRING]: '#64748B',   // Slate
  [ValidationType.BOOLEAN]: '#DC2626',  // Rouge foncé
  [ValidationType.ENUM]: '#7C3AED'      // Purple
};

// Configuration des paramètres pour chaque script
export const SCRIPT_PARAMETERS: Record<string, InputParameter[]> = {
  'ssh_012': [ // execute-workflow.remote.sh
    { name: 'host', label: 'Host', type: ValidationType.HOSTNAME, required: true, placeholder: 'server.com' },
    { name: 'user', label: 'User', type: ValidationType.USERNAME, required: true, placeholder: 'deploy' },
    { name: 'disk', label: 'Disk Device', type: ValidationType.DEVICE, required: true, placeholder: '/dev/sdb' },
    { name: 'target_iqn', label: 'Target IQN', type: ValidationType.IQN, required: true, placeholder: 'iqn.2025-01.local:target1' },
    { name: 'ssh_key', label: 'SSH Key Path', type: ValidationType.PATH, required: false, placeholder: '~/.ssh/id_rsa' },
    { name: 'log_server', label: 'Log Server', type: ValidationType.URL, required: false, placeholder: 'https://logs.company.com' }
  ],
  'ssh_orch_001': [ // setup-ssh.access.sh
    { name: 'host', label: 'Host IP', type: ValidationType.IP, required: true, placeholder: '192.168.1.10' },
    { name: 'user', label: 'Username', type: ValidationType.USERNAME, required: true, placeholder: 'deploy' },
    { name: 'key_type', label: 'Key Type', type: ValidationType.ENUM, required: false, defaultValue: 'ed25519', enumValues: ['rsa', 'ed25519'] },
    { name: 'key_size', label: 'Key Size', type: ValidationType.NUMBER, required: false, defaultValue: '4096', placeholder: '4096' }
  ],
  'ssh_001': [ // generate-ssh.keypair.sh
    { name: 'type', label: 'Key Type', type: ValidationType.ENUM, required: false, defaultValue: 'ed25519', enumValues: ['rsa', 'ed25519'] },
    { name: 'bits', label: 'Key Size', type: ValidationType.NUMBER, required: false, defaultValue: '4096', placeholder: '4096' },
    { name: 'comment', label: 'Comment', type: ValidationType.STRING, required: false, placeholder: 'user@host' },
    { name: 'output', label: 'Output Path', type: ValidationType.PATH, required: false, placeholder: '~/.ssh/id_rsa' }
  ],
  'ssh_002': [ // add-ssh.key.authorized.sh
    { name: 'user', label: 'Username', type: ValidationType.USERNAME, required: true, placeholder: 'deploy' },
    { name: 'key', label: 'Public Key', type: ValidationType.STRING, required: true, placeholder: 'ssh-ed25519 AAAA...' },
    { name: 'host', label: 'Hostname', type: ValidationType.HOSTNAME, required: false, placeholder: 'server.com' }
  ],
  'ssh_005': [ // check-ssh.connection.sh
    { name: 'host', label: 'Host IP', type: ValidationType.IP, required: true, placeholder: '192.168.1.10' },
    { name: 'port', label: 'Port', type: ValidationType.PORT, required: false, defaultValue: '22', placeholder: '22' },
    { name: 'user', label: 'Username', type: ValidationType.USERNAME, required: true, placeholder: 'deploy' },
    { name: 'timeout', label: 'Timeout (sec)', type: ValidationType.NUMBER, required: false, defaultValue: '10', placeholder: '10' }
  ],
  // Ajout d'autres scripts
  'script_003': [ // setup-iscsi-target.sh
    { name: 'disk', label: 'Disk Device', type: ValidationType.DEVICE, required: true, placeholder: '/dev/sdb' },
    { name: 'target_iqn', label: 'Target IQN', type: ValidationType.IQN, required: true, placeholder: 'iqn.2025-01.local:target1' },
    { name: 'portal_ip', label: 'Portal IP', type: ValidationType.IP, required: false, placeholder: '192.168.1.10' },
    { name: 'lun_id', label: 'LUN ID', type: ValidationType.NUMBER, required: false, defaultValue: '0', placeholder: '0' }
  ],
  'script_005': [ // format-disk.sh
    { name: 'device', label: 'Device', type: ValidationType.DEVICE, required: true, placeholder: '/dev/sdb1' },
    { name: 'filesystem', label: 'Filesystem', type: ValidationType.ENUM, required: true, enumValues: ['ext4', 'xfs', 'btrfs'] },
    { name: 'label', label: 'Label', type: ValidationType.STRING, required: false, placeholder: 'data' },
    { name: 'force', label: 'Force Format', type: ValidationType.BOOLEAN, required: false, defaultValue: 'false' }
  ]
};