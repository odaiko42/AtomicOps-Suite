// Validateurs pour les paramètres d'entrée
import { InputParameterType } from '@/types/script-flow';

interface ValidationResult {
  isValid: boolean;
  message?: string;
}

export const InputValidators = {
  [InputParameterType.IP]: (value: string): ValidationResult => {
    const ipRegex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
    return {
      isValid: ipRegex.test(value),
      message: ipRegex.test(value) ? undefined : 'Format IP invalide (ex: 192.168.1.1)'
    };
  },

  [InputParameterType.HOSTNAME]: (value: string): ValidationResult => {
    const hostnameRegex = /^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$/;
    return {
      isValid: hostnameRegex.test(value) && value.length <= 253,
      message: hostnameRegex.test(value) ? undefined : 'Format hostname invalide (ex: server.domain.com)'
    };
  },

  [InputParameterType.URL]: (value: string): ValidationResult => {
    try {
      new URL(value);
      return { isValid: true };
    } catch {
      return {
        isValid: false,
        message: 'URL invalide (ex: https://example.com/path)'
      };
    }
  },

  [InputParameterType.EMAIL]: (value: string): ValidationResult => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return {
      isValid: emailRegex.test(value),
      message: emailRegex.test(value) ? undefined : 'Format email invalide (ex: user@domain.com)'
    };
  },

  [InputParameterType.IQN]: (value: string): ValidationResult => {
    const iqnRegex = /^iqn\.\d{4}-\d{2}\.[a-zA-Z0-9\-\.]+(:.*)?$/;
    return {
      isValid: iqnRegex.test(value),
      message: iqnRegex.test(value) ? undefined : 'Format IQN invalide (ex: iqn.2025-01.com.example:target1)'
    };
  },

  [InputParameterType.DEVICE]: (value: string): ValidationResult => {
    const deviceRegex = /^\/dev\/[a-zA-Z0-9\/\-_]+$/;
    return {
      isValid: deviceRegex.test(value),
      message: deviceRegex.test(value) ? undefined : 'Format device invalide (ex: /dev/sda1, /dev/nvme0n1)'
    };
  },

  [InputParameterType.PATH]: (value: string): ValidationResult => {
    const pathRegex = /^(\/[^\/\0]+)+\/?$|^\/$/;
    return {
      isValid: pathRegex.test(value),
      message: pathRegex.test(value) ? undefined : 'Chemin invalide (ex: /path/to/file)'
    };
  },

  [InputParameterType.PORT]: (value: string): ValidationResult => {
    const port = parseInt(value, 10);
    const isValid = !isNaN(port) && port >= 1 && port <= 65535;
    return {
      isValid,
      message: isValid ? undefined : 'Port invalide (1-65535)'
    };
  },

  [InputParameterType.USERNAME]: (value: string): ValidationResult => {
    const usernameRegex = /^[a-zA-Z0-9]([a-zA-Z0-9\-_]{0,30}[a-zA-Z0-9])?$/;
    return {
      isValid: usernameRegex.test(value) && value.length <= 32,
      message: usernameRegex.test(value) ? undefined : 'Username invalide (lettres, chiffres, - et _)'
    };
  },

  [InputParameterType.PASSWORD]: (value: string): ValidationResult => {
    const isValid = value.length >= 8;
    return {
      isValid,
      message: isValid ? undefined : 'Mot de passe trop court (min 8 caractères)'
    };
  },

  [InputParameterType.TOKEN]: (value: string): ValidationResult => {
    const isValid = value.length >= 16 && /^[a-zA-Z0-9\-_\.=]+$/.test(value);
    return {
      isValid,
      message: isValid ? undefined : 'Token invalide (min 16 chars, alphanumériques + -_.=)'
    };
  },

  [InputParameterType.SIZE]: (value: string): ValidationResult => {
    const sizeRegex = /^\d+(\.\d+)?[KMGT]?B?$/i;
    return {
      isValid: sizeRegex.test(value),
      message: sizeRegex.test(value) ? undefined : 'Taille invalide (ex: 100, 1.5GB, 500MB)'
    };
  },

  [InputParameterType.TIMEOUT]: (value: string): ValidationResult => {
    const timeout = parseInt(value, 10);
    const isValid = !isNaN(timeout) && timeout > 0 && timeout <= 86400; // Max 24h
    return {
      isValid,
      message: isValid ? undefined : 'Timeout invalide (1-86400 secondes)'
    };
  }
};

// Configuration des couleurs pour les types de paramètres
export const INPUT_PARAMETER_COLORS: Record<InputParameterType, string> = {
  [InputParameterType.IP]: '#3b82f6',        // Bleu
  [InputParameterType.HOSTNAME]: '#06b6d4',  // Cyan
  [InputParameterType.URL]: '#8b5cf6',       // Violet
  [InputParameterType.EMAIL]: '#ec4899',     // Rose
  [InputParameterType.IQN]: '#f59e0b',       // Orange
  [InputParameterType.DEVICE]: '#ef4444',    // Rouge
  [InputParameterType.PATH]: '#10b981',      // Vert
  [InputParameterType.PORT]: '#6366f1',      // Indigo
  [InputParameterType.USERNAME]: '#84cc16',  // Lime
  [InputParameterType.PASSWORD]: '#f97316',  // Orange foncé
  [InputParameterType.TOKEN]: '#a855f7',     // Pourpre
  [InputParameterType.SIZE]: '#d946ef',      // Magenta
  [InputParameterType.TIMEOUT]: '#14b8a6'    // Teal
};

// Labels pour l'interface utilisateur
export const INPUT_PARAMETER_LABELS: Record<InputParameterType, string> = {
  [InputParameterType.IP]: 'Adresse IP',
  [InputParameterType.HOSTNAME]: 'Nom d\'hôte',
  [InputParameterType.URL]: 'URL',
  [InputParameterType.EMAIL]: 'Email',
  [InputParameterType.IQN]: 'IQN iSCSI',
  [InputParameterType.DEVICE]: 'Périphérique',
  [InputParameterType.PATH]: 'Chemin',
  [InputParameterType.PORT]: 'Port',
  [InputParameterType.USERNAME]: 'Nom d\'utilisateur',
  [InputParameterType.PASSWORD]: 'Mot de passe',
  [InputParameterType.TOKEN]: 'Token',
  [InputParameterType.SIZE]: 'Taille',
  [InputParameterType.TIMEOUT]: 'Timeout'
};