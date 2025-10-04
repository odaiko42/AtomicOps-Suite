// ===========================
// Composant de statistiques en temps réel pour le Dashboard
// ===========================

import React from 'react';
import { FileCode, GitBranch, Activity, TrendingUp, Database, Clock, CheckCircle, AlertTriangle } from "lucide-react";
import StatCard from "@/components/StatCard";
import { useScripts, useStatistics } from '../hooks/useScriptData';

const RealTimeStats: React.FC = () => {
  const { scripts, loading: scriptsLoading } = useScripts();
  const { stats, loading: statsLoading } = useStatistics();

  // Calcul des statistiques réelles à partir des données
  const totalScripts = scripts.length;
  const atomicScripts = scripts.filter(s => s.level === 0 || s.level === 'atomic').length;
  const orchestrators = scripts.filter(s => 
    (typeof s.level === 'number' && s.level >= 1) || 
    s.level === 'orchestrator' || 
    s.level === 'main'
  ).length;
  const stableScripts = scripts.filter(s => s.status === 'stable').length;
  const testingScripts = scripts.filter(s => s.status === 'testing').length;
  
  // Calculs de pourcentages
  const atomicPercentage = totalScripts > 0 ? ((atomicScripts / totalScripts) * 100).toFixed(1) : '0';
  const orchestratorPercentage = totalScripts > 0 ? ((orchestrators / totalScripts) * 100).toFixed(1) : '0';
  const stablePercentage = totalScripts > 0 ? ((stableScripts / totalScripts) * 100).toFixed(1) : '0';
  
  // Scripts récents (derniers 30 jours)
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const recentScripts = scripts.filter(s => new Date(s.lastModified) > thirtyDaysAgo).length;
  
  // Calcul du nombre total de fonctions
  const totalFunctions = scripts.reduce((acc, script) => acc + (script.functions?.length || 0), 0);
  
  // Scripts par catégorie (top 3)
  const categoryCount = scripts.reduce((acc, script) => {
    acc[script.category] = (acc[script.category] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);
  
  const topCategories = Object.entries(categoryCount)
    .sort(([,a], [,b]) => b - a)
    .slice(0, 3);

  if (scriptsLoading || statsLoading) {
    return (
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        {[1, 2, 3, 4].map(i => (
          <div key={i} className="animate-pulse">
            <div className="h-32 bg-gray-200 rounded-lg"></div>
          </div>
        ))}
      </div>
    );
  }

  return (
    <>
      {/* Stats Grid */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <StatCard
          icon={FileCode}
          title="Total Scripts"
          value={totalScripts.toString()}
          subtitle="scripts dans le catalogue"
          trend={{ 
            value: recentScripts.toString(), 
            positive: recentScripts > 0
          }}
        />
        <StatCard
          icon={Activity}
          title="Scripts Atomiques"
          value={atomicScripts.toString()}
          subtitle={`${atomicPercentage}% du catalogue`}
        />
        <StatCard
          icon={GitBranch}
          title="Orchestrateurs"
          value={orchestrators.toString()}
          subtitle={`${orchestratorPercentage}% du catalogue`}
        />
        <StatCard
          icon={CheckCircle}
          title="Scripts Stables"
          value={`${stablePercentage}%`}
          subtitle={`${stableScripts}/${totalScripts} scripts`}
          trend={{ 
            value: stableScripts.toString(), 
            positive: true
          }}
        />
      </div>

      {/* Statistiques détaillées */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        <div className="rounded-xl bg-card p-6 card-shadow border border-border">
          <div className="flex items-center gap-3 mb-4">
            <Database className="h-5 w-5 text-blue-500" />
            <h3 className="text-lg font-semibold text-foreground">Contenu du Catalogue</h3>
          </div>
          <div className="space-y-3">
            <div className="flex justify-between items-center">
              <span className="text-sm text-muted-foreground">Total fonctions</span>
              <span className="font-medium">{totalFunctions}</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-muted-foreground">Moy. fonctions/script</span>
              <span className="font-medium">
                {totalScripts > 0 ? (totalFunctions / totalScripts).toFixed(1) : '0'}
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-muted-foreground">Scripts en test</span>
              <span className="font-medium text-orange-600">{testingScripts}</span>
            </div>
          </div>
        </div>

        <div className="rounded-xl bg-card p-6 card-shadow border border-border">
          <div className="flex items-center gap-3 mb-4">
            <TrendingUp className="h-5 w-5 text-green-500" />
            <h3 className="text-lg font-semibold text-foreground">Top Catégories</h3>
          </div>
          <div className="space-y-3">
            {topCategories.map(([category, count], index) => (
              <div key={category} className="flex justify-between items-center">
                <span className="text-sm text-muted-foreground capitalize">
                  {category.replace(/-/g, ' ')}
                </span>
                <div className="flex items-center gap-2">
                  <span className="font-medium">{count}</span>
                  <div className="w-16 h-2 bg-gray-200 rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-blue-500 rounded-full transition-all"
                      style={{ width: `${(count / totalScripts) * 100}%` }}
                    />
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-xl bg-card p-6 card-shadow border border-border">
          <div className="flex items-center gap-3 mb-4">
            <Clock className="h-5 w-5 text-purple-500" />
            <h3 className="text-lg font-semibold text-foreground">Activité Récente</h3>
          </div>
          <div className="space-y-3">
            <div className="flex justify-between items-center">
              <span className="text-sm text-muted-foreground">Modifiés (30j)</span>
              <span className="font-medium text-green-600">{recentScripts}</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-muted-foreground">Scripts stables</span>
              <span className="font-medium text-blue-600">{stableScripts}</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-muted-foreground">En développement</span>
              <span className="font-medium text-orange-600">
                {scripts.filter(s => s.status === 'draft').length}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Répartition par niveau */}
      <div className="rounded-xl bg-card p-6 card-shadow border border-border">
        <div className="flex items-center gap-3 mb-4">
          <GitBranch className="h-5 w-5 text-indigo-500" />
          <h3 className="text-lg font-semibold text-foreground">Répartition par Niveau Hiérarchique</h3>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="text-center p-4 bg-blue-50 rounded-lg border">
            <div className="text-2xl font-bold text-blue-600">{atomicScripts}</div>
            <div className="text-sm text-blue-600 font-medium">Scripts Atomiques</div>
            <div className="text-xs text-gray-600">Actions individuelles</div>
          </div>
          <div className="text-center p-4 bg-green-50 rounded-lg border">
            <div className="text-2xl font-bold text-green-600">
              {scripts.filter(s => s.level === 1 || s.level === 'orchestrator').length}
            </div>
            <div className="text-sm text-green-600 font-medium">Orchestrateurs</div>
            <div className="text-xs text-gray-600">Workflows composés</div>
          </div>
          <div className="text-center p-4 bg-purple-50 rounded-lg border">
            <div className="text-2xl font-bold text-purple-600">
              {scripts.filter(s => 
                (typeof s.level === 'number' && s.level >= 2) || 
                s.level === 'main'
              ).length}
            </div>
            <div className="text-sm text-purple-600 font-medium">Scripts Principaux</div>
            <div className="text-xs text-gray-600">Interfaces utilisateur</div>
          </div>
        </div>
      </div>
    </>
  );
};

export default RealTimeStats;