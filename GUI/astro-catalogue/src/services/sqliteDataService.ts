// ===========================
// Service de Base de Données SQLite - AtomicOps Suite
// ===========================
// 
// Adaptateur pour utiliser SQLite3 avec l'interface GUI existante
// Compatible avec l'architecture React/TypeScript d'astro-catalogue

import { mockScripts, allMockScripts, generateMockStats, generateMockDependencyGraph, generateMockHierarchy } from '../data/mockData';

// Mode développement - utilise les données de test
const isDevelopment = import.meta.env.DEV;

export interface Script {
  id: string;
  name: string;
  description: string;
  category: string; // Flexible pour supporter différentes catégories
  level: number | string; // Flexible pour supporter les niveaux numériques et textuels
  path: string;
  inputs?: string[];
  outputs?: string[];
  conditions?: string[];
  dependencies?: string[];
  tags?: string[];
  complexity: string; // Flexible pour différentes valeurs
  status: string; // Flexible pour différents statuts
  lastModified: string;
  author?: string;
  version?: string;
  functions?: ScriptFunction[];
  lineCount?: number;
  inputSockets?: ScriptInputSocket[];
}

export interface ScriptInputSocket {
  name: string;
  type: string;
  required: boolean;
  description?: string;
  defaultValue?: string;
}

export interface ScriptFunction {
  id?: string;
  name: string;
  description: string;
  inputs: string[];
  outputs: string[];
}

export interface DatabaseStats {
  total: number;
  byCategory: Record<string, number>;
  byLevel: Record<string, number>;
  byComplexity: Record<string, number>;
  byStatus: Record<string, number>;
  totalDependencies: number;
  avgDependenciesPerScript: number;
  totalFunctions: number;
  avgFunctionsPerScript: number;
  recentlyModified: number;
}

export interface FilterOptions {
  search?: string;
  category?: string;
  level?: string;
  status?: string;
  complexity?: string;
  tags?: string[];
}

class SQLiteDataService {
  private db: any = null;
  private isElectron: boolean = false;
  private cache = new Map<string, any>();
  private cacheExpiry = 5 * 60 * 1000; // 5 minutes

  constructor() {
    this.isElectron = typeof window !== 'undefined' && 
                     (window as any).electronAPI !== undefined;
    this.initializeDatabase();
  }

  /**
   * ===========================
   * Initialisation de la Base de Données
   * ===========================
   */

  private async initializeDatabase(): Promise<void> {
    try {
      if (this.isElectron) {
        // Environnement Electron avec SQLite natif
        await this.initializeElectronDB();
      } else {
        // Environnement Web avec sql.js
        await this.initializeWebDB();
      }

      // Créer les tables si elles n'existent pas
      await this.createTables();
      
      // Insérer des données d'exemple si la base est vide
      const count = await this.getScriptCount();
      if (count === 0) {
        await this.insertSampleData();
      }

      console.log('✅ Base de données SQLite initialisée avec succès');
    } catch (error) {
      console.error('❌ Erreur lors de l\'initialisation de la base de données:', error);
      throw error;
    }
  }

  private async initializeElectronDB(): Promise<void> {
    // Utiliser l'API Electron pour SQLite
    const { electronAPI } = window as any;
    this.db = await electronAPI.openDatabase('atomic-scripts.db');
  }

  private async initializeWebDB(): Promise<void> {
    // Utiliser sql.js pour le navigateur
    const initSqlJs = (await import('sql.js')).default;
    const SQL = await initSqlJs({
      locateFile: (file: string) => `https://sql.js.org/dist/${file}`
    });

    // Essayer de charger une base existante depuis localStorage
    const saved = localStorage.getItem('atomic-scripts-db');
    if (saved) {
      const uint8Array = new Uint8Array(JSON.parse(saved));
      this.db = new SQL.Database(uint8Array);
    } else {
      this.db = new SQL.Database();
    }
  }

  /**
   * ===========================
   * Gestion du Schéma
   * ===========================
   */

  private async createTables(): Promise<void> {
    const createScriptsTable = `
      CREATE TABLE IF NOT EXISTS scripts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        level TEXT NOT NULL,
        path TEXT,
        complexity TEXT DEFAULT 'low',
        status TEXT DEFAULT 'stable',
        last_modified TEXT,
        author TEXT,
        version TEXT DEFAULT '1.0.0',
        line_count INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      );
    `;

    const createFunctionsTable = `
      CREATE TABLE IF NOT EXISTS script_functions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        script_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
      );
    `;

    const createInputsTable = `
      CREATE TABLE IF NOT EXISTS script_inputs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        script_id TEXT NOT NULL,
        input_name TEXT NOT NULL,
        function_id INTEGER,
        FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
        FOREIGN KEY (function_id) REFERENCES script_functions(id) ON DELETE CASCADE
      );
    `;

    const createOutputsTable = `
      CREATE TABLE IF NOT EXISTS script_outputs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        script_id TEXT NOT NULL,
        output_name TEXT NOT NULL,
        function_id INTEGER,
        FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
        FOREIGN KEY (function_id) REFERENCES script_functions(id) ON DELETE CASCADE
      );
    `;

    const createConditionsTable = `
      CREATE TABLE IF NOT EXISTS script_conditions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        script_id TEXT NOT NULL,
        condition_text TEXT NOT NULL,
        FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
      );
    `;

    const createDependenciesTable = `
      CREATE TABLE IF NOT EXISTS script_dependencies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        script_id TEXT NOT NULL,
        dependency_id TEXT NOT NULL,
        FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
        FOREIGN KEY (dependency_id) REFERENCES scripts(id) ON DELETE CASCADE
      );
    `;

    const createTagsTable = `
      CREATE TABLE IF NOT EXISTS script_tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        script_id TEXT NOT NULL,
        tag TEXT NOT NULL,
        FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
      );
    `;

    const createIndexes = `
      CREATE INDEX IF NOT EXISTS idx_scripts_category ON scripts(category);
      CREATE INDEX IF NOT EXISTS idx_scripts_level ON scripts(level);
      CREATE INDEX IF NOT EXISTS idx_scripts_status ON scripts(status);
      CREATE INDEX IF NOT EXISTS idx_dependencies_script ON script_dependencies(script_id);
      CREATE INDEX IF NOT EXISTS idx_dependencies_dependency ON script_dependencies(dependency_id);
      CREATE INDEX IF NOT EXISTS idx_tags_script ON script_tags(script_id);
      CREATE INDEX IF NOT EXISTS idx_functions_script ON script_functions(script_id);
    `;

    try {
      await this.executeSQL(createScriptsTable);
      await this.executeSQL(createFunctionsTable);
      await this.executeSQL(createInputsTable);
      await this.executeSQL(createOutputsTable);
      await this.executeSQL(createConditionsTable);
      await this.executeSQL(createDependenciesTable);
      await this.executeSQL(createTagsTable);
      await this.executeSQL(createIndexes);
      
      console.log('📋 Tables de la base de données créées avec succès');
    } catch (error) {
      console.error('❌ Erreur lors de la création des tables:', error);
      throw error;
    }
  }

  /**
   * ===========================
   * Exécution des Requêtes
   * ===========================
   */

  private async executeSQL(sql: string, params: any[] = []): Promise<any> {
    if (this.isElectron) {
      const { electronAPI } = window as any;
      return await electronAPI.executeSQL(sql, params);
    } else {
      if (sql.trim().toUpperCase().startsWith('SELECT')) {
        const stmt = this.db.prepare(sql);
        const result = stmt.getAsObject(params);
        stmt.free();
        return result;
      } else {
        this.db.run(sql, params);
        this.saveWebDB();
        return { changes: this.db.getRowsModified() };
      }
    }
  }

  private async querySQL(sql: string, params: any[] = []): Promise<any[]> {
    if (this.isElectron) {
      const { electronAPI } = window as any;
      return await electronAPI.querySQL(sql, params);
    } else {
      const stmt = this.db.prepare(sql);
      const rows: any[] = [];
      
      while (stmt.step()) {
        rows.push(stmt.getAsObject());
      }
      
      stmt.free();
      return rows;
    }
  }

  private saveWebDB(): void {
    if (!this.isElectron && this.db) {
      const data = this.db.export();
      localStorage.setItem('atomic-scripts-db', JSON.stringify(Array.from(data)));
    }
  }

  /**
   * ===========================
   * CRUD Operations
   * ===========================
   */

  async getAllScripts(): Promise<Script[]> {
    // Mode développement : retourner les données de test
    if (isDevelopment) {
      return allMockScripts;
    }

    const cacheKey = 'all-scripts';
    const cached = this.getCached(cacheKey);
    if (cached) return cached;

    try {
      const scripts = await this.querySQL(`
        SELECT s.*, 
               GROUP_CONCAT(DISTINCT st.tag) as tags,
               GROUP_CONCAT(DISTINCT si.input_name) as inputs,
               GROUP_CONCAT(DISTINCT so.output_name) as outputs,
               GROUP_CONCAT(DISTINCT sc.condition_text) as conditions,
               GROUP_CONCAT(DISTINCT sd.dependency_id) as dependencies
        FROM scripts s
        LEFT JOIN script_tags st ON s.id = st.script_id
        LEFT JOIN script_inputs si ON s.id = si.script_id
        LEFT JOIN script_outputs so ON s.id = so.script_id  
        LEFT JOIN script_conditions sc ON s.id = sc.script_id
        LEFT JOIN script_dependencies sd ON s.id = sd.script_id
        GROUP BY s.id
        ORDER BY s.name
      `);

      const processedScripts = await Promise.all(
        scripts.map(async (script: any) => {
          const functions = await this.getScriptFunctions(script.id);
          
          return {
            ...script,
            tags: script.tags ? script.tags.split(',').filter(Boolean) : [],
            inputs: script.inputs ? script.inputs.split(',').filter(Boolean) : [],
            outputs: script.outputs ? script.outputs.split(',').filter(Boolean) : [],
            conditions: script.conditions ? script.conditions.split(',').filter(Boolean) : [],
            dependencies: script.dependencies ? script.dependencies.split(',').filter(Boolean) : [],
            functions: functions,
            lastModified: script.last_modified
          } as Script;
        })
      );

      this.setCached(cacheKey, processedScripts);
      return processedScripts;
    } catch (error) {
      console.error('Erreur lors de la récupération des scripts:', error);
      return [];
    }
  }

  async getScript(id: string): Promise<Script | null> {
    const cacheKey = `script-${id}`;
    const cached = this.getCached(cacheKey);
    if (cached) return cached;

    try {
      const scripts = await this.querySQL('SELECT * FROM scripts WHERE id = ?', [id]);
      if (scripts.length === 0) return null;

      const script = scripts[0];
      
      // Récupérer les données associées
      const [tags, inputs, outputs, conditions, dependencies, functions] = await Promise.all([
        this.querySQL('SELECT tag FROM script_tags WHERE script_id = ?', [id]),
        this.querySQL('SELECT input_name FROM script_inputs WHERE script_id = ?', [id]),
        this.querySQL('SELECT output_name FROM script_outputs WHERE script_id = ?', [id]),
        this.querySQL('SELECT condition_text FROM script_conditions WHERE script_id = ?', [id]),
        this.querySQL('SELECT dependency_id FROM script_dependencies WHERE script_id = ?', [id]),
        this.getScriptFunctions(id)
      ]);

      const result = {
        ...script,
        tags: tags.map((t: any) => t.tag),
        inputs: inputs.map((i: any) => i.input_name),
        outputs: outputs.map((o: any) => o.output_name),
        conditions: conditions.map((c: any) => c.condition_text),
        dependencies: dependencies.map((d: any) => d.dependency_id),
        functions: functions,
        lastModified: script.last_modified
      } as Script;

      this.setCached(cacheKey, result);
      return result;
    } catch (error) {
      console.error('Erreur lors de la récupération du script:', error);
      return null;
    }
  }

  async getScriptFunctions(scriptId: string): Promise<ScriptFunction[]> {
    try {
      const functions = await this.querySQL(`
        SELECT f.*,
               GROUP_CONCAT(DISTINCT fi.input_name) as inputs,
               GROUP_CONCAT(DISTINCT fo.output_name) as outputs
        FROM script_functions f
        LEFT JOIN script_inputs fi ON f.id = fi.function_id
        LEFT JOIN script_outputs fo ON f.id = fo.function_id
        WHERE f.script_id = ?
        GROUP BY f.id
      `, [scriptId]);

      return functions.map((func: any) => ({
        name: func.name,
        description: func.description || '',
        inputs: func.inputs ? func.inputs.split(',').filter(Boolean) : [],
        outputs: func.outputs ? func.outputs.split(',').filter(Boolean) : []
      }));
    } catch (error) {
      console.error('Erreur lors de la récupération des fonctions:', error);
      return [];
    }
  }

  async searchScripts(filters: FilterOptions): Promise<Script[]> {
    let sql = `
      SELECT DISTINCT s.id
      FROM scripts s
      LEFT JOIN script_tags st ON s.id = st.script_id
      WHERE 1=1
    `;
    const params: any[] = [];

    if (filters.search) {
      sql += ` AND (s.name LIKE ? OR s.description LIKE ?)`;
      params.push(`%${filters.search}%`, `%${filters.search}%`);
    }

    if (filters.category) {
      sql += ` AND s.category = ?`;
      params.push(filters.category);
    }

    if (filters.level) {
      sql += ` AND s.level = ?`;
      params.push(filters.level);
    }

    if (filters.status) {
      sql += ` AND s.status = ?`;
      params.push(filters.status);
    }

    if (filters.complexity) {
      sql += ` AND s.complexity = ?`;
      params.push(filters.complexity);
    }

    if (filters.tags && filters.tags.length > 0) {
      sql += ` AND st.tag IN (${filters.tags.map(() => '?').join(',')})`;
      params.push(...filters.tags);
    }

    try {
      const scriptIds = await this.querySQL(sql, params);
      const scripts = await Promise.all(
        scriptIds.map((row: any) => this.getScript(row.id))
      );
      
      return scripts.filter(Boolean) as Script[];
    } catch (error) {
      console.error('Erreur lors de la recherche:', error);
      return [];
    }
  }

  async getStatistics(): Promise<DatabaseStats> {
    // Mode développement : retourner les statistiques de test
    if (isDevelopment) {
      return generateMockStats();
    }

    const cacheKey = 'statistics';
    const cached = this.getCached(cacheKey);
    if (cached) return cached;

    try {
      const [
        totalResult,
        categoryStats,
        levelStats,
        complexityStats,
        statusStats,
        depsResult,
        functionsResult,
        recentResult
      ] = await Promise.all([
        this.querySQL('SELECT COUNT(*) as total FROM scripts'),
        this.querySQL('SELECT category, COUNT(*) as count FROM scripts GROUP BY category'),
        this.querySQL('SELECT level, COUNT(*) as count FROM scripts GROUP BY level'),
        this.querySQL('SELECT complexity, COUNT(*) as count FROM scripts GROUP BY complexity'),
        this.querySQL('SELECT status, COUNT(*) as count FROM scripts GROUP BY status'),
        this.querySQL('SELECT COUNT(*) as total FROM script_dependencies'),
        this.querySQL('SELECT COUNT(*) as total FROM script_functions'),
        this.querySQL(`
          SELECT COUNT(*) as recent 
          FROM scripts 
          WHERE datetime(last_modified) > datetime('now', '-30 days')
        `)
      ]);

      const total = totalResult[0]?.total || 0;
      
      const stats: DatabaseStats = {
        total,
        byCategory: categoryStats.reduce((acc: any, item: any) => {
          acc[item.category] = item.count;
          return acc;
        }, {}),
        byLevel: levelStats.reduce((acc: any, item: any) => {
          acc[item.level] = item.count;
          return acc;
        }, {}),
        byComplexity: complexityStats.reduce((acc: any, item: any) => {
          acc[item.complexity] = item.count;
          return acc;
        }, {}),
        byStatus: statusStats.reduce((acc: any, item: any) => {
          acc[item.status] = item.count;
          return acc;
        }, {}),
        totalDependencies: depsResult[0]?.total || 0,
        avgDependenciesPerScript: total > 0 ? (depsResult[0]?.total || 0) / total : 0,
        totalFunctions: functionsResult[0]?.total || 0,
        avgFunctionsPerScript: total > 0 ? (functionsResult[0]?.total || 0) / total : 0,
        recentlyModified: recentResult[0]?.recent || 0
      };

      this.setCached(cacheKey, stats);
      return stats;
    } catch (error) {
      console.error('Erreur lors du calcul des statistiques:', error);
      return {
        total: 0,
        byCategory: {},
        byLevel: {},
        byComplexity: {},
        byStatus: {},
        totalDependencies: 0,
        avgDependenciesPerScript: 0,
        totalFunctions: 0,
        avgFunctionsPerScript: 0,
        recentlyModified: 0
      };
    }
  }

  /**
   * ===========================
   * Gestion du Cache
   * ===========================
   */

  private getCached(key: string): any {
    const cached = this.cache.get(key);
    if (cached && Date.now() - cached.timestamp < this.cacheExpiry) {
      return cached.data;
    }
    return null;
  }

  private setCached(key: string, data: any): void {
    this.cache.set(key, {
      data,
      timestamp: Date.now()
    });
  }

  private clearCache(): void {
    this.cache.clear();
  }

  /**
   * ===========================
   * Utilitaires
   * ===========================
   */

  private async getScriptCount(): Promise<number> {
    try {
      const result = await this.querySQL('SELECT COUNT(*) as count FROM scripts');
      return result[0]?.count || 0;
    } catch (error) {
      return 0;
    }
  }

  private async insertSampleData(): Promise<void> {
    // Insérer des données d'exemple basées sur notre JSON
    const sampleScripts = [
      {
        id: 'select-disk',
        name: 'Sélecteur de Disque USB',
        description: 'Interface interactive pour sélectionner un disque USB parmi ceux disponibles.',
        category: 'usb',
        level: 'atomic',
        path: 'scripts/atomic/select-disk.sh',
        complexity: 'low',
        status: 'stable',
        author: 'AtomicOps Team',
        version: '1.2.0',
        last_modified: new Date().toISOString()
      },
      // Ajouter d'autres scripts d'exemple...
    ];

    try {
      for (const script of sampleScripts) {
        await this.executeSQL(`
          INSERT INTO scripts (
            id, name, description, category, level, path, 
            complexity, status, author, version, last_modified
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `, [
          script.id, script.name, script.description, script.category,
          script.level, script.path, script.complexity, script.status,
          script.author, script.version, script.last_modified
        ]);

        // Ajouter des tags d'exemple
        const tags = [script.category, script.level, 'example'];
        for (const tag of tags) {
          await this.executeSQL(
            'INSERT INTO script_tags (script_id, tag) VALUES (?, ?)',
            [script.id, tag]
          );
        }
      }

      console.log('📦 Données d\'exemple insérées avec succès');
    } catch (error) {
      console.error('Erreur lors de l\'insertion des données d\'exemple:', error);
    }
  }

  /**
   * ===========================
   * API Publique
   * ===========================
   */

  async refreshCache(): Promise<void> {
    this.clearCache();
    await this.getAllScripts();
    await this.getStatistics();
  }

  async exportData(): Promise<string> {
    const scripts = await this.getAllScripts();
    const stats = await this.getStatistics();
    
    return JSON.stringify({
      metadata: {
        version: '1.0.0',
        generated: new Date().toISOString(),
        total_scripts: scripts.length
      },
      scripts,
      statistics: stats
    }, null, 2);
  }

  async getDependencyGraph(): Promise<{ nodes: any[], links: any[] }> {
    // Mode développement : retourner le graphe de test
    if (isDevelopment) {
      return generateMockDependencyGraph();
    }

    const scripts = await this.getAllScripts();
    const nodes = scripts.map(script => ({
      id: script.id,
      name: script.name,
      category: script.category,
      level: script.level,
      complexity: script.complexity,
      status: script.status
    }));

    const links: any[] = [];
    scripts.forEach(script => {
      script.dependencies.forEach(depId => {
        links.push({
          source: depId,
          target: script.id,
          type: 'dependency'
        });
      });
    });

    return { nodes, links };
  }

  async getHierarchy(): Promise<any> {
    // Mode développement : retourner la hiérarchie de test
    if (isDevelopment) {
      return generateMockHierarchy();
    }

    const scripts = await this.getAllScripts();
    
    // Organiser par catégories puis par niveaux
    const categories = [...new Set(scripts.map(s => s.category))];
    
    return {
      name: 'AtomicOps Suite',
      children: categories.map(category => ({
        name: this.formatCategoryName(category),
        category,
        type: 'category',
        children: ['atomic', 'orchestrator', 'main'].map(level => {
          const levelScripts = scripts.filter(s => 
            s.category === category && s.level === level
          );
          
          if (levelScripts.length === 0) return null;
          
          return {
            name: this.formatLevelName(level),
            level,
            type: 'level',
            children: levelScripts.map(script => ({
              ...script,
              type: 'script'
            }))
          };
        }).filter(Boolean)
      })).filter(cat => cat.children.length > 0)
    };
  }

  private formatCategoryName(category: string): string {
    const names: { [key: string]: string } = {
      'usb': 'Stockage USB',
      'iscsi': 'Configuration iSCSI',
      'network': 'Réseau',
      'system': 'Système',
      'file': 'Fichiers',
      'other': 'Autres'
    };
    return names[category] || category.charAt(0).toUpperCase() + category.slice(1);
  }

  private formatLevelName(level: string): string {
    const names: { [key: string]: string } = {
      'atomic': 'Scripts Atomiques',
      'orchestrator': 'Orchestrateurs',
      'main': 'Scripts Principaux'
    };
    return names[level] || level.charAt(0).toUpperCase() + level.slice(1);
  }
}

// Singleton instance
export const sqliteService = new SQLiteDataService();
export default SQLiteDataService;