import React, { useState } from "react";
import { TrendingUp, TrendingDown, Calendar, Clock, CheckCircle, XCircle, BarChart3, PieChart, Activity } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useScripts, useStatistics } from "../hooks/useScriptData";
import StatsDashboard from "@/components/StatsDashboard";

export default function Stats() {
  const { scripts, loading: scriptsLoading } = useScripts();
  const { stats, loading: statsLoading } = useStatistics();
  const [period, setPeriod] = useState("30");

  const loading = scriptsLoading || statsLoading;

  // Calculs basés sur les vraies données
  const totalScripts = scripts.length;
  const stableScripts = scripts.filter(s => s.status === 'stable').length;
  const testingScripts = scripts.filter(s => s.status === 'testing').length;
  const draftScripts = scripts.filter(s => s.status === 'draft').length;

  // Scripts par catégorie
  const scriptsByCategory = scripts.reduce((acc, script) => {
    acc[script.category] = (acc[script.category] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  // Top catégories
  const topCategories = Object.entries(scriptsByCategory)
    .sort(([,a], [,b]) => b - a)
    .slice(0, 5);

  // Scripts les plus complexes
  const complexScripts = scripts
    .filter(s => s.functions && s.functions.length > 0)
    .sort((a, b) => (b.functions?.length || 0) - (a.functions?.length || 0))
    .slice(0, 5);

  // Scripts récents
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const recentScripts = scripts.filter(s => new Date(s.lastModified) > thirtyDaysAgo);

  // Simulation de données de performance (à remplacer par de vraies données)
  const performanceData = scripts.map(script => ({
    name: script.name,
    executions: Math.floor(Math.random() * 1000) + 50,
    successRate: 95 + Math.random() * 5,
    category: script.category,
    status: script.status
  }));

  const topPerformers = performanceData
    .sort((a, b) => b.executions - a.executions)
    .slice(0, 5);

  const mostReliable = performanceData
    .sort((a, b) => b.successRate - a.successRate)
    .slice(0, 5);

  if (loading) {
    return (
      <div className="space-y-6">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Statistiques</h2>
          <p className="text-muted-foreground">Analyse des performances et tendances</p>
        </div>
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Statistiques</h2>
          <p className="text-muted-foreground">Analyse des performances et tendances</p>
        </div>
        <Select value={period} onValueChange={setPeriod}>
          <SelectTrigger className="w-[180px]">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="7">7 derniers jours</SelectItem>
            <SelectItem value="30">30 derniers jours</SelectItem>
            <SelectItem value="90">3 derniers mois</SelectItem>
            <SelectItem value="365">Année complète</SelectItem>
          </SelectContent>
        </Select>
      </div>

      {/* Métriques principales */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Scripts</CardTitle>
            <BarChart3 className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{totalScripts}</div>
            <p className="text-xs text-muted-foreground">
              +{recentScripts.length} ce mois
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Scripts Stables</CardTitle>
            <CheckCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stableScripts}</div>
            <p className="text-xs text-muted-foreground">
              {((stableScripts / totalScripts) * 100).toFixed(1)}% du total
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">En Test</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-orange-600">{testingScripts}</div>
            <p className="text-xs text-muted-foreground">
              Scripts en validation
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Brouillons</CardTitle>
            <XCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-600">{draftScripts}</div>
            <p className="text-xs text-muted-foreground">
              Scripts en développement
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Graphiques de statistiques détaillées */}
      <StatsDashboard />

      {/* Analyses détaillées */}
      <div className="grid gap-6 md:grid-cols-2">
        {/* Top catégories */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <PieChart className="h-5 w-5" />
              Top Catégories
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {topCategories.map(([category, count], index) => (
                <div key={category} className="flex items-center gap-4">
                  <div className="flex h-8 w-8 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-600">
                    {index + 1}
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center justify-between">
                      <span className="font-medium capitalize">
                        {category.replace(/-/g, ' ')}
                      </span>
                      <span className="text-sm font-bold">{count}</span>
                    </div>
                    <div className="w-full bg-gray-200 rounded-full h-2 mt-1">
                      <div
                        className="bg-blue-500 h-2 rounded-full transition-all"
                        style={{ width: `${(count / totalScripts) * 100}%` }}
                      />
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* Scripts les plus complexes */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Activity className="h-5 w-5" />
              Scripts les Plus Complexes
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {complexScripts.map((script, index) => (
                <div key={script.id} className="flex items-center gap-3 p-2 rounded-lg hover:bg-gray-50">
                  <div className="flex h-8 w-8 items-center justify-center rounded-full bg-purple-100 text-sm font-bold text-purple-600">
                    {index + 1}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="font-medium text-sm truncate">{script.name}</p>
                    <div className="flex items-center gap-2 mt-1">
                      <Badge variant="outline" className="text-xs">
                        {script.category}
                      </Badge>
                      <Badge variant="secondary" className="text-xs">
                        {script.functions?.length || 0} fonctions
                      </Badge>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Performance simulée */}
      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <TrendingUp className="h-5 w-5 text-green-500" />
              Scripts les Plus Utilisés
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {topPerformers.map((script, index) => (
                <div key={script.name} className="flex items-center justify-between p-2 rounded-lg hover:bg-gray-50">
                  <div className="flex items-center gap-3">
                    <div className="flex h-6 w-6 items-center justify-center rounded-full bg-green-100 text-xs font-bold text-green-600">
                      {index + 1}
                    </div>
                    <div>
                      <p className="font-medium text-sm">{script.name}</p>
                      <Badge variant="outline" className="text-xs">
                        {script.category}
                      </Badge>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="font-bold text-green-600">{script.executions}</p>
                    <p className="text-xs text-muted-foreground">exécutions</p>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <CheckCircle className="h-5 w-5 text-blue-500" />
              Scripts les Plus Fiables
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {mostReliable.map((script, index) => (
                <div key={script.name} className="flex items-center justify-between p-2 rounded-lg hover:bg-gray-50">
                  <div className="flex items-center gap-3">
                    <div className="flex h-6 w-6 items-center justify-center rounded-full bg-blue-100 text-xs font-bold text-blue-600">
                      {index + 1}
                    </div>
                    <div>
                      <p className="font-medium text-sm">{script.name}</p>
                      <Badge variant="outline" className="text-xs">
                        {script.category}
                      </Badge>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="font-bold text-green-600">{script.successRate.toFixed(1)}%</p>
                    <p className="text-xs text-muted-foreground">succès</p>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}