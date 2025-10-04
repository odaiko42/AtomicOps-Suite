// ===========================
// Hooks React pour SQLite Data Service
// ===========================

import { useState, useEffect, useCallback } from 'react';
import { sqliteService, Script, DatabaseStats, FilterOptions } from '../services/sqliteDataService';

// Hook pour charger tous les scripts
export function useScripts() {
  const [scripts, setScripts] = useState<Script[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadScripts = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await sqliteService.getAllScripts();
      setScripts(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur lors du chargement des scripts');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadScripts();
  }, [loadScripts]);

  return { scripts, loading, error, reload: loadScripts };
}

// Hook pour un script spécifique
export function useScript(id: string | null) {
  const [script, setScript] = useState<Script | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!id) {
      setScript(null);
      return;
    }

    const loadScript = async () => {
      try {
        setLoading(true);
        setError(null);
        const data = await sqliteService.getScript(id);
        setScript(data);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Erreur lors du chargement du script');
      } finally {
        setLoading(false);
      }
    };

    loadScript();
  }, [id]);

  return { script, loading, error };
}

// Hook pour les statistiques
export function useStatistics() {
  const [stats, setStats] = useState<DatabaseStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadStats = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await sqliteService.getStatistics();
      setStats(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur lors du chargement des statistiques');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadStats();
  }, [loadStats]);

  return { stats, loading, error, reload: loadStats };
}

// Hook pour la recherche avec filtres
export function useScriptSearch() {
  const [results, setResults] = useState<Script[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [filters, setFilters] = useState<FilterOptions>({});

  const search = useCallback(async (newFilters: FilterOptions) => {
    try {
      setLoading(true);
      setError(null);
      setFilters(newFilters);
      
      // Si aucun filtre, retourner tous les scripts
      if (!newFilters.search && !newFilters.category && !newFilters.level && 
          !newFilters.status && !newFilters.complexity && 
          (!newFilters.tags || newFilters.tags.length === 0)) {
        const allScripts = await sqliteService.getAllScripts();
        setResults(allScripts);
      } else {
        const searchResults = await sqliteService.searchScripts(newFilters);
        setResults(searchResults);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur lors de la recherche');
    } finally {
      setLoading(false);
    }
  }, []);

  const clearSearch = useCallback(() => {
    setFilters({});
    setResults([]);
    setError(null);
  }, []);

  return { results, loading, error, filters, search, clearSearch };
}

// Hook pour le graphe de dépendances
export function useDependencyGraph() {
  const [graph, setGraph] = useState<{ nodes: any[], links: any[] } | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadGraph = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await sqliteService.getDependencyGraph();
      setGraph(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur lors du chargement du graphe');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadGraph();
  }, [loadGraph]);

  return { graph, loading, error, reload: loadGraph };
}

// Hook pour la hiérarchie
export function useHierarchy() {
  const [hierarchy, setHierarchy] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadHierarchy = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await sqliteService.getHierarchy();
      setHierarchy(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur lors du chargement de la hiérarchie');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadHierarchy();
  }, [loadHierarchy]);

  return { hierarchy, loading, error, reload: loadHierarchy };
}

// Hook pour les catégories et niveaux disponibles
export function useFiltersOptions() {
  const [options, setOptions] = useState<{
    categories: string[];
    levels: string[];
    statuses: string[];
    complexities: string[];
    tags: string[];
  }>({
    categories: [],
    levels: [],
    statuses: [],
    complexities: [],
    tags: []
  });

  useEffect(() => {
    const loadOptions = async () => {
      try {
        const scripts = await sqliteService.getAllScripts();
        
        const categories = [...new Set(scripts.map(s => s.category))];
        const levels = [...new Set(scripts.map(s => s.level))];
        const statuses = [...new Set(scripts.map(s => s.status))];
        const complexities = [...new Set(scripts.map(s => s.complexity))];
        const tags = [...new Set(scripts.flatMap(s => s.tags))];

        setOptions({
          categories: categories.sort(),
          levels: levels.sort(),
          statuses: statuses.sort(),
          complexities: complexities.sort(),
          tags: tags.sort()
        });
      } catch (error) {
        console.error('Erreur lors du chargement des options de filtres:', error);
      }
    };

    loadOptions();
  }, []);

  return options;
}

// Hook utilitaire pour rafraîchir le cache
export function useDataRefresh() {
  const [refreshing, setRefreshing] = useState(false);

  const refresh = useCallback(async () => {
    try {
      setRefreshing(true);
      await sqliteService.refreshCache();
    } catch (error) {
      console.error('Erreur lors du rafraîchissement:', error);
    } finally {
      setRefreshing(false);
    }
  }, []);

  return { refresh, refreshing };
}