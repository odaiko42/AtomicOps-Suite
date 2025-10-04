import React, { useState } from "react";
import { Search, Filter, Plus, Eye, Edit, Trash2, Atom, GitBranch, MoreVertical } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useScripts } from "../hooks/useScriptData";

export default function Scripts() {
  const { scripts, loading, error } = useScripts();
  const [searchTerm, setSearchTerm] = useState("");
  const [filterType, setFilterType] = useState<string>("all");

  // Filtrage des scripts
  const filteredScripts = scripts.filter(script => {
    const matchesSearch = script.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         script.description.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesType = filterType === "all" || 
                       (filterType === "atomic" && (script.level === 0 || script.level === "atomic")) ||
                       (filterType === "orchestrator" && ((typeof script.level === 'number' && script.level >= 1) || script.level === "orchestrator" || script.level === "main"));
    
    return matchesSearch && matchesType;
  });

  // Fonction pour déterminer le type de script
  const getScriptType = (script: any) => {
    if (script.level === 0 || script.level === "atomic") {
      return { type: "Atomique", color: "blue" };
    } else if (typeof script.level === 'number' && script.level >= 1) {
      return { type: "Orchestrateur", color: "purple" };
    } else if (script.level === "orchestrator" || script.level === "main") {
      return { type: "Orchestrateur", color: "purple" };
    }
    return { type: "Autre", color: "gray" };
  };

  // Simulation de données d'exécution (à remplacer par de vraies données)
  const getExecutionData = (scriptId: string) => {
    const executions = Math.floor(Math.random() * 1000) + 100;
    const success = 95 + Math.random() * 5; // Entre 95% et 100%
    return { executions, success: success.toFixed(1) };
  };

  // Fonction pour obtenir la version (simulation)
  const getVersion = (script: any) => {
    return script.version || "1.0.0";
  };

  if (loading) {
    return (
      <div className="space-y-6">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Scripts</h2>
          <p className="text-muted-foreground">Gérez votre catalogue de scripts</p>
        </div>
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900"></div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="space-y-6">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Scripts</h2>
          <p className="text-muted-foreground">Gérez votre catalogue de scripts</p>
        </div>
        <div className="text-center text-red-500 p-8">
          Erreur : {error}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Scripts</h2>
          <p className="text-muted-foreground">Gérez votre catalogue de scripts</p>
        </div>
        <Button>
          <Plus className="h-4 w-4 mr-2" />
          Nouveau Script
        </Button>
      </div>

      {/* Search and Filters */}
      <div className="flex items-center gap-4">
        <div className="relative flex-1 max-w-sm">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Rechercher un script..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-9"
          />
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant={filterType === "all" ? "default" : "outline"}
            size="sm"
            onClick={() => setFilterType("all")}
          >
            Tous
          </Button>
          <Button
            variant={filterType === "atomic" ? "default" : "outline"}
            size="sm"
            onClick={() => setFilterType("atomic")}
          >
            <Atom className="h-4 w-4 mr-1" />
            Atomique
          </Button>
          <Button
            variant={filterType === "orchestrator" ? "default" : "outline"}
            size="sm"
            onClick={() => setFilterType("orchestrator")}
          >
            <GitBranch className="h-4 w-4 mr-1" />
            Orchestrateur
          </Button>
        </div>
        <Button variant="outline" size="sm">
          <Filter className="h-4 w-4 mr-2" />
          Filtres
        </Button>
      </div>

      {/* Scripts Table */}
      <div className="rounded-lg border bg-card">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Nom</TableHead>
              <TableHead>Type</TableHead>
              <TableHead>Catégorie</TableHead>
              <TableHead>Version</TableHead>
              <TableHead className="text-center">Exec.</TableHead>
              <TableHead className="text-center">Succès</TableHead>
              <TableHead className="text-center">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredScripts.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="text-center py-8 text-muted-foreground">
                  Aucun script trouvé
                </TableCell>
              </TableRow>
            ) : (
              filteredScripts.map((script) => {
                const scriptType = getScriptType(script);
                const execData = getExecutionData(script.id);
                const version = getVersion(script);

                return (
                  <TableRow key={script.id} className="hover:bg-muted/50">
                    <TableCell>
                      <div>
                        <div className="font-medium">{script.name}</div>
                        <div className="text-sm text-muted-foreground truncate max-w-[300px]">
                          {script.description}
                        </div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge 
                        variant={scriptType.color === "blue" ? "default" : "secondary"}
                        className={
                          scriptType.color === "blue" 
                            ? "bg-blue-100 text-blue-700 border-blue-200" 
                            : "bg-purple-100 text-purple-700 border-purple-200"
                        }
                      >
                        {scriptType.color === "blue" && <Atom className="h-3 w-3 mr-1" />}
                        {scriptType.color === "purple" && <GitBranch className="h-3 w-3 mr-1" />}
                        {scriptType.type}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <Badge variant="outline" className="capitalize">
                        {script.category.replace(/-/g, ' ')}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-sm font-mono">
                      {version}
                    </TableCell>
                    <TableCell className="text-center font-medium">
                      {execData.executions.toLocaleString()}
                    </TableCell>
                    <TableCell className="text-center">
                      <span className={`font-medium ${
                        parseFloat(execData.success) >= 98 ? 'text-green-600' :
                        parseFloat(execData.success) >= 95 ? 'text-yellow-600' :
                        'text-red-600'
                      }`}>
                        {execData.success}%
                      </span>
                    </TableCell>
                    <TableCell className="text-center">
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="sm">
                            <MoreVertical className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem>
                            <Eye className="h-4 w-4 mr-2" />
                            Voir détails
                          </DropdownMenuItem>
                          <DropdownMenuItem>
                            <Edit className="h-4 w-4 mr-2" />
                            Modifier
                          </DropdownMenuItem>
                          <DropdownMenuItem className="text-red-600">
                            <Trash2 className="h-4 w-4 mr-2" />
                            Supprimer
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
                  </TableRow>
                );
              })
            )}
          </TableBody>
        </Table>
      </div>

      {/* Footer Stats */}
      <div className="flex items-center justify-between text-sm text-muted-foreground">
        <div>
          Affichage de {filteredScripts.length} script{filteredScripts.length > 1 ? 's' : ''} 
          {filteredScripts.length !== scripts.length && ` sur ${scripts.length} total`}
        </div>
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-blue-500"></div>
            <span>Atomique ({scripts.filter(s => s.level === 0 || s.level === 'atomic').length})</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-purple-500"></div>
            <span>Orchestrateur ({scripts.filter(s => 
              (typeof s.level === 'number' && s.level >= 1) || 
              s.level === 'orchestrator' || 
              s.level === 'main'
            ).length})</span>
          </div>
        </div>
      </div>
    </div>
  );
}