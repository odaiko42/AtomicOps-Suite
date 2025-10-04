// ===========================
// Composant de tableau de bord avec statistiques
// ===========================

import React from 'react';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, LineChart, Line } from 'recharts';
import { useStatistics } from '../hooks/useScriptData';
import { Loader2 } from 'lucide-react';

const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884d8', '#82ca9d', '#ffc658'];

const StatsDashboard: React.FC = () => {
  const { stats, loading, error } = useStatistics();

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center text-red-500 p-4">
        Erreur : {error}
      </div>
    );
  }

  if (!stats) {
    return (
      <div className="text-center text-gray-500 p-4">
        Aucune donnée disponible
      </div>
    );
  }

  // Préparation des données pour les graphiques
  const categoryData = Object.entries(stats.byCategory).map(([name, value]) => ({
    name,
    value,
    percentage: ((value / stats.total) * 100).toFixed(1)
  }));

  const levelData = Object.entries(stats.byLevel).map(([name, value]) => ({
    name,
    value,
    percentage: ((value / stats.total) * 100).toFixed(1)
  }));

  const statusData = Object.entries(stats.byStatus).map(([name, value]) => ({
    name,
    value,
    percentage: ((value / stats.total) * 100).toFixed(1)
  }));

  const complexityData = Object.entries(stats.byComplexity).map(([name, value]) => ({
    name,
    value
  }));

  return (
    <div className="space-y-6">
      {/* Statistiques générales */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Scripts</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.total}</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Fonctions</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.totalFunctions}</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Dépendances</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.totalDependencies}</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Scripts Récents</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">{stats.recentlyModified}</div>
          </CardContent>
        </Card>
      </div>

      {/* Graphiques */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Répartition par catégorie */}
        <Card>
          <CardHeader>
            <CardTitle>Répartition par Catégorie</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={categoryData}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percentage }) => `${name} (${percentage}%)`}
                  outerRadius={80}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {categoryData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Répartition par niveau hiérarchique */}
        <Card>
          <CardHeader>
            <CardTitle>Répartition par Niveau</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={levelData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis />
                <Tooltip />
                <Bar dataKey="value" fill="#8884d8" />
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Répartition par statut */}
        <Card>
          <CardHeader>
            <CardTitle>Répartition par Statut</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={statusData}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percentage }) => `${name} (${percentage}%)`}
                  outerRadius={80}
                  fill="#82ca9d"
                  dataKey="value"
                >
                  {statusData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Complexité */}
        <Card>
          <CardHeader>
            <CardTitle>Répartition par Complexité</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={complexityData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis />
                <Tooltip />
                <Bar dataKey="value" fill="#ffc658" />
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>

      {/* Statistiques des dépendances */}
      <Card>
        <CardHeader>
          <CardTitle>Métriques de Dépendances</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between">
              <span>Total des dépendances :</span>
              <span className="font-semibold">{stats.totalDependencies}</span>
            </div>
            <div className="flex justify-between">
              <span>Moyenne par script :</span>
              <span className="font-semibold">{stats.avgDependenciesPerScript.toFixed(2)}</span>
            </div>
            <div className="flex justify-between">
              <span>Total des fonctions :</span>
              <span className="font-semibold">{stats.totalFunctions}</span>
            </div>
            <div className="flex justify-between">
              <span>Fonctions par script :</span>
              <span className="font-semibold">{stats.avgFunctionsPerScript.toFixed(2)}</span>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Statistiques textuelles détaillées */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Card>
          <CardHeader>
            <CardTitle>Détails par Catégorie</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {categoryData.map((item, index) => (
                <div key={item.name} className="flex justify-between items-center">
                  <span className="text-sm">{item.name}</span>
                  <div className="flex items-center space-x-2">
                    <span className="text-sm font-medium">{String(item.value)}</span>
                    <span className="text-xs text-gray-500">({item.percentage}%)</span>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Détails par Niveau</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {levelData.map((item, index) => (
                <div key={item.name} className="flex justify-between items-center">
                  <span className="text-sm">Niveau {item.name}</span>
                  <div className="flex items-center space-x-2">
                    <span className="text-sm font-medium">{String(item.value)}</span>
                    <span className="text-xs text-gray-500">({item.percentage}%)</span>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default StatsDashboard;