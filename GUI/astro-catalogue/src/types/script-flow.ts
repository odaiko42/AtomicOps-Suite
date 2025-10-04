// Types pour le système de flow-craft adapté aux scripts AtomicOps-Suite

export enum ScriptDataType {
  FILE = 'file',
  STRING = 'string',
  NUMBER = 'number',
  BOOLEAN = 'boolean',
  JSON = 'json',
  ARRAY = 'array',
  EXIT_CODE = 'exit_code',
  LOG = 'log',
  DEVICE = 'device',
  NETWORK = 'network',
  PROCESS = 'process',
  PERFORMANCE = 'performance',
  ANY = 'any'
}

export interface Point2D {
  x: number;
  y: number;
}

export interface ScriptSocketDefinition {
  name: string;
  type: ScriptDataType;
  required: boolean;
  multiple?: boolean;
  description?: string;
  format?: string; // Format attendu (ex: "path", "json", "csv")
}

export interface ScriptParameterDefinition {
  name: string;
  type: string;
  defaultValue?: any;
  description?: string;
  options?: string[]; // Pour les select
  min?: number;
  max?: number;
}

export interface ScriptDefinition {
  id: string;
  name: string;
  category: string; // performance, system, network, usb, iscsi, file
  level: string; // atomic, orchestrator, main
  description?: string;
  path?: string; // Chemin vers le script
  inputs: ScriptSocketDefinition[];
  outputs: ScriptSocketDefinition[];
  parameters: ScriptParameterDefinition[];
  color?: string;
  icon?: string;
}

export interface ScriptInstance {
  id: string;
  definitionId: string;
  position: Point2D;
  parameters: Map<string, any>;
  selected?: boolean;
  status?: 'idle' | 'running' | 'completed' | 'error';
  logs?: string[];
}

export interface ScriptConnection {
  id: string;
  sourceScriptId: string;
  sourceSocket: string;
  targetScriptId: string;
  targetSocket: string;
  type: ScriptDataType;
}

export interface WorkflowData {
  scripts: ScriptInstance[];
  connections: ScriptConnection[];
  metadata?: {
    name: string;
    description?: string;
    version?: string;
    created?: string;
    modified?: string;
  };
}

export const SCRIPT_DATA_TYPE_COLORS: Record<ScriptDataType, string> = {
  [ScriptDataType.FILE]: '#f59e0b',          // Orange pour fichiers
  [ScriptDataType.STRING]: '#10b981',        // Vert pour texte
  [ScriptDataType.NUMBER]: '#3b82f6',        // Bleu pour nombres
  [ScriptDataType.BOOLEAN]: '#8b5cf6',       // Violet pour boolean
  [ScriptDataType.JSON]: '#ec4899',          // Rose pour JSON
  [ScriptDataType.ARRAY]: '#06b6d4',         // Cyan pour tableaux
  [ScriptDataType.EXIT_CODE]: '#ef4444',     // Rouge pour codes de sortie
  [ScriptDataType.LOG]: '#84cc16',           // Lime pour logs
  [ScriptDataType.DEVICE]: '#f97316',        // Orange foncé pour devices
  [ScriptDataType.NETWORK]: '#6366f1',       // Indigo pour réseau
  [ScriptDataType.PROCESS]: '#a855f7',       // Pourpre pour processus
  [ScriptDataType.PERFORMANCE]: '#d946ef',   // Magenta pour perf
  [ScriptDataType.ANY]: '#6b7280'            // Gris pour générique
};

export const SCRIPT_CATEGORY_COLORS: Record<string, string> = {
  'performance': '#d946ef',
  'system': '#3b82f6',
  'network': '#6366f1',
  'usb': '#f59e0b',
  'iscsi': '#ef4444',
  'file': '#10b981',
  'utility': '#8b5cf6',
  'monitoring': '#06b6d4'
};