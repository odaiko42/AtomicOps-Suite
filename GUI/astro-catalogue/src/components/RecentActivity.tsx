// ===========================
// Composant d'activité récente pour le Dashboard
// ===========================

import React from 'react';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Clock, FileCode, GitBranch, Activity } from 'lucide-react';
import { useScripts } from '../hooks/useScriptData';

const RecentActivity: React.FC = () => {
  const { scripts, loading } = useScripts();

  if (loading) {
    return (
      <div className="animate-pulse">
        <div className="h-64 bg-gray-200 rounded-lg"></div>
      </div>
    );
  }

  // Scripts les plus récents (derniers 7 jours)
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
  
  const recentScripts = scripts
    .filter(s => new Date(s.lastModified) > sevenDaysAgo)
    .sort((a, b) => new Date(b.lastModified).getTime() - new Date(a.lastModified).getTime())
    .slice(0, 5);

  // Scripts les plus utilisés (simulation basée sur le nom et la catégorie)
  const popularScripts = scripts
    .filter(s => s.category === 'system' || s.category === 'network' || s.level === 0)
    .slice(0, 5);

  const getTypeIcon = (level: string | number) => {
    if (level === 0 || level === 'atomic') {
      return <Activity className="h-4 w-4 text-blue-500" />;
    } else if ((typeof level === 'number' && level >= 1) || level === 'orchestrator' || level === 'main') {
      return <GitBranch className="h-4 w-4 text-green-500" />;
    }
    return <FileCode className="h-4 w-4 text-gray-500" />;
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffTime = Math.abs(now.getTime() - date.getTime());
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    if (diffDays === 1) return 'Aujourd\'hui';
    if (diffDays === 2) return 'Hier';
    if (diffDays <= 7) return `Il y a ${diffDays - 1} jours`;
    return date.toLocaleDateString('fr-FR');
  };

  return (
    <div className="grid gap-6 md:grid-cols-2">
      {/* Activité récente */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Clock className="h-5 w-5 text-blue-500" />
            Activité Récente
          </CardTitle>
        </CardHeader>
        <CardContent>
          {recentScripts.length === 0 ? (
            <p className="text-muted-foreground text-sm">Aucune activité récente</p>
          ) : (
            <div className="space-y-3">
              {recentScripts.map(script => (
                <div key={script.id} className="flex items-start gap-3 p-2 rounded-lg hover:bg-gray-50">
                  {getTypeIcon(script.level)}
                  <div className="flex-1 min-w-0">
                    <p className="font-medium text-sm truncate">{script.name}</p>
                    <p className="text-xs text-muted-foreground truncate">
                      {script.description}
                    </p>
                    <div className="flex items-center gap-2 mt-1">
                      <Badge variant="outline" className="text-xs">
                        {script.category}
                      </Badge>
                      <span className="text-xs text-muted-foreground">
                        {formatDate(script.lastModified)}
                      </span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Scripts populaires */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Activity className="h-5 w-5 text-green-500" />
            Scripts Populaires
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {popularScripts.map((script, index) => (
              <div key={script.id} className="flex items-center gap-3 p-2 rounded-lg hover:bg-gray-50">
                <div className="flex h-8 w-8 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-600">
                  {index + 1}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    {getTypeIcon(script.level)}
                    <p className="font-medium text-sm truncate">{script.name}</p>
                  </div>
                  <div className="flex items-center gap-2 mt-1">
                    <Badge variant="secondary" className="text-xs">
                      {script.category}
                    </Badge>
                    <Badge 
                      variant={script.status === 'stable' ? 'default' : 'outline'} 
                      className="text-xs"
                    >
                      {script.status}
                    </Badge>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-sm font-medium text-green-600">
                    {script.functions?.length || 0}
                  </p>
                  <p className="text-xs text-muted-foreground">fonctions</p>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default RecentActivity;