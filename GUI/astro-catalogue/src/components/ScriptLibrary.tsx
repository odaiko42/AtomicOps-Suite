import React, { useState, useMemo } from 'react';
import { 
  ScriptDefinition, 
  SCRIPT_CATEGORY_COLORS,
  ScriptDataType,
  SCRIPT_DATA_TYPE_COLORS
} from '@/types/script-flow';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import { 
  Search, 
  ChevronDown, 
  ChevronRight, 
  FileCode, 
  Play,
  Settings,
  Network,
  HardDrive,
  Cpu,
  Activity
} from "lucide-react";

interface ScriptLibraryProps {
  scriptDefinitions: ScriptDefinition[];
  onScriptDragStart: (script: ScriptDefinition, e: React.DragEvent) => void;
  onScriptAdd?: (script: ScriptDefinition) => void;
}

interface CategoryState {
  [key: string]: boolean;
}

const CATEGORY_ICONS: Record<string, React.ComponentType<any>> = {
  'performance': Activity,
  'system': Settings,
  'network': Network,
  'usb': HardDrive,
  'iscsi': HardDrive,
  'file': FileCode,
  'utility': Settings,
  'monitoring': Activity
};

export const ScriptLibrary: React.FC<ScriptLibraryProps> = ({
  scriptDefinitions,
  onScriptDragStart,
  onScriptAdd
}) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [expandedCategories, setExpandedCategories] = useState<CategoryState>({
    'performance': true,
    'system': true,
    'network': true,
    'usb': false,
    'iscsi': false,
    'file': false,
    'utility': false,
    'monitoring': false
  });

  // Grouper les scripts par catégorie
  const scriptsByCategory = useMemo(() => {
    const filtered = scriptDefinitions.filter(script => 
      script.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      script.description?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      script.category.toLowerCase().includes(searchTerm.toLowerCase())
    );

    const grouped = filtered.reduce((acc, script) => {
      if (!acc[script.category]) {
        acc[script.category] = [];
      }
      acc[script.category].push(script);
      return acc;
    }, {} as Record<string, ScriptDefinition[]>);

    // Trier les scripts dans chaque catégorie
    Object.keys(grouped).forEach(category => {
      grouped[category].sort((a, b) => {
        // D'abord par niveau (atomic, orchestrator, main)
        const levelOrder = { 'atomic': 1, 'orchestrator': 2, 'main': 3 };
        const levelDiff = (levelOrder[a.level as keyof typeof levelOrder] || 4) - 
                         (levelOrder[b.level as keyof typeof levelOrder] || 4);
        if (levelDiff !== 0) return levelDiff;
        
        // Puis par nom
        return a.name.localeCompare(b.name);
      });
    });

    return grouped;
  }, [scriptDefinitions, searchTerm]);

  // Basculer l'état d'une catégorie
  const toggleCategory = (category: string) => {
    setExpandedCategories(prev => ({
      ...prev,
      [category]: !prev[category]
    }));
  };

  // Gestionnaire de début de drag
  const handleDragStart = (script: ScriptDefinition) => (e: React.DragEvent) => {
    e.dataTransfer.setData('application/json', JSON.stringify(script));
    e.dataTransfer.effectAllowed = 'copy';
    onScriptDragStart(script, e);
  };

  // Rendu d'un script individuel
  const renderScript = (script: ScriptDefinition) => {
    const IconComponent = CATEGORY_ICONS[script.category] || FileCode;
    const categoryColor = SCRIPT_CATEGORY_COLORS[script.category] || '#6b7280';

    return (
      <Card
        key={script.id}
        className="mb-2 cursor-grab active:cursor-grabbing hover:shadow-md transition-all duration-200 border-l-4"
        style={{ borderLeftColor: categoryColor }}
        draggable
        onDragStart={handleDragStart(script)}
        onClick={() => onScriptAdd?.(script)}
      >
        <CardContent className="p-3">
          <div className="flex items-start justify-between mb-2">
            <div className="flex items-center gap-2">
              <IconComponent 
                className="h-4 w-4 flex-shrink-0" 
                style={{ color: categoryColor }} 
              />
              <h4 className="font-medium text-sm truncate">{script.name}</h4>
            </div>
            <Badge 
              variant="outline" 
              className="text-xs"
              style={{ 
                borderColor: categoryColor, 
                color: categoryColor 
              }}
            >
              {script.level}
            </Badge>
          </div>
          
          {script.description && (
            <p className="text-xs text-muted-foreground mb-2 line-clamp-2">
              {script.description}
            </p>
          )}

          <div className="flex flex-wrap gap-1 mb-2">
            {/* Indicateurs d'entrées */}
            {script.inputs.length > 0 && (
              <Badge variant="secondary" className="text-xs">
                {script.inputs.length} entrée{script.inputs.length > 1 ? 's' : ''}
              </Badge>
            )}
            
            {/* Indicateurs de sorties */}
            {script.outputs.length > 0 && (
              <Badge variant="secondary" className="text-xs">
                {script.outputs.length} sortie{script.outputs.length > 1 ? 's' : ''}
              </Badge>
            )}

            {/* Indicateurs de paramètres */}
            {script.parameters.length > 0 && (
              <Badge variant="outline" className="text-xs">
                {script.parameters.length} param{script.parameters.length > 1 ? 's' : ''}
              </Badge>
            )}
          </div>

          {/* Aperçu des types de données */}
          <div className="flex gap-1">
            {[...new Set([
              ...script.inputs.map(i => i.type),
              ...script.outputs.map(o => o.type)
            ])].slice(0, 4).map((type, index) => (
              <div
                key={index}
                className="w-3 h-3 rounded-full border border-white"
                style={{ backgroundColor: SCRIPT_DATA_TYPE_COLORS[type] }}
                title={type}
              />
            ))}
          </div>
        </CardContent>
      </Card>
    );
  };

  // Rendu d'une catégorie
  const renderCategory = (category: string, scripts: ScriptDefinition[]) => {
    const isExpanded = expandedCategories[category];
    const IconComponent = CATEGORY_ICONS[category] || FileCode;
    const categoryColor = SCRIPT_CATEGORY_COLORS[category] || '#6b7280';

    return (
      <Collapsible key={category} open={isExpanded} onOpenChange={() => toggleCategory(category)}>
        <CollapsibleTrigger asChild>
          <Button
            variant="ghost"
            className="w-full justify-start p-2 h-auto mb-2"
            style={{ 
              borderLeft: `4px solid ${categoryColor}`,
              backgroundColor: isExpanded ? `${categoryColor}10` : 'transparent'
            }}
          >
            <div className="flex items-center gap-2 w-full">
              <IconComponent 
                className="h-4 w-4" 
                style={{ color: categoryColor }} 
              />
              <span className="font-medium capitalize flex-1 text-left">
                {category}
              </span>
              <Badge variant="secondary" className="text-xs">
                {scripts.length}
              </Badge>
              {isExpanded ? (
                <ChevronDown className="h-4 w-4" />
              ) : (
                <ChevronRight className="h-4 w-4" />
              )}
            </div>
          </Button>
        </CollapsibleTrigger>
        
        <CollapsibleContent className="space-y-1 ml-2">
          {scripts.map(renderScript)}
        </CollapsibleContent>
      </Collapsible>
    );
  };

  // Statistiques
  const totalScripts = scriptDefinitions.length;
  const filteredScripts = Object.values(scriptsByCategory).flat().length;
  const categoriesWithScripts = Object.keys(scriptsByCategory).length;

  return (
    <Card className="w-80 flex flex-col h-full">
      <CardHeader className="pb-3">
        <CardTitle className="flex items-center gap-2 text-lg">
          <FileCode className="h-5 w-5" />
          Bibliothèque de Scripts
        </CardTitle>
        
        {/* Barre de recherche */}
        <div className="relative">
          <Search className="absolute left-2 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Rechercher des scripts..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-8"
          />
        </div>

        {/* Statistiques */}
        <div className="flex gap-2 text-xs text-muted-foreground">
          <span>{filteredScripts}/{totalScripts} scripts</span>
          <span>•</span>
          <span>{categoriesWithScripts} catégories</span>
        </div>
      </CardHeader>

      <CardContent className="flex-1 overflow-hidden p-0">
        <ScrollArea className="h-full px-4 pb-4">
          {Object.keys(scriptsByCategory).length > 0 ? (
            <div className="space-y-1">
              {Object.entries(scriptsByCategory)
                .sort(([a], [b]) => a.localeCompare(b))
                .map(([category, scripts]) => renderCategory(category, scripts))
              }
            </div>
          ) : (
            <div className="text-center text-muted-foreground py-8">
              <FileCode className="h-8 w-8 mx-auto mb-2 opacity-50" />
              <p>Aucun script trouvé</p>
              {searchTerm && (
                <p className="text-xs mt-1">
                  Essayez un autre terme de recherche
                </p>
              )}
            </div>
          )}
        </ScrollArea>
      </CardContent>

      {/* Instructions */}
      <div className="border-t p-3 text-xs text-muted-foreground">
        <p className="mb-1">💡 <strong>Glisser-déposer</strong> pour ajouter un script</p>
        <p><strong>Cliquer</strong> pour voir les détails</p>
      </div>
    </Card>
  );
};