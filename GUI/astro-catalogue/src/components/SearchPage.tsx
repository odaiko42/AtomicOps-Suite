// ===========================
// Composant de recherche avancée avec filtres
// ===========================

import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Checkbox } from "@/components/ui/checkbox";
import { Label } from "@/components/ui/label";
import { Search, Filter, X } from 'lucide-react';
import { useScriptSearch, useFiltersOptions } from '../hooks/useScriptData';
import { FilterOptions, Script } from '../services/sqliteDataService';

interface SearchPageProps {
  onScriptSelect?: (script: Script) => void;
}

const SearchPage: React.FC<SearchPageProps> = ({ onScriptSelect }) => {
  const { results, loading, error, search, clearSearch } = useScriptSearch();
  const filterOptions = useFiltersOptions();
  
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('');
  const [selectedLevel, setSelectedLevel] = useState<string>('');
  const [selectedStatus, setSelectedStatus] = useState<string>('');
  const [selectedComplexity, setSelectedComplexity] = useState<string>('');
  const [selectedTags, setSelectedTags] = useState<string[]>([]);
  const [showAdvanced, setShowAdvanced] = useState(false);

  const handleSearch = () => {
    const filters: FilterOptions = {};
    
    if (searchTerm.trim()) filters.search = searchTerm.trim();
    if (selectedCategory) filters.category = selectedCategory;
    if (selectedLevel) filters.level = selectedLevel;
    if (selectedStatus) filters.status = selectedStatus;
    if (selectedComplexity) filters.complexity = selectedComplexity;
    if (selectedTags.length > 0) filters.tags = selectedTags;
    
    search(filters);
  };

  const handleClearFilters = () => {
    setSearchTerm('');
    setSelectedCategory('');
    setSelectedLevel('');
    setSelectedStatus('');
    setSelectedComplexity('');
    setSelectedTags([]);
    clearSearch();
  };

  const toggleTag = (tag: string) => {
    setSelectedTags(prev => 
      prev.includes(tag) 
        ? prev.filter(t => t !== tag)
        : [...prev, tag]
    );
  };

  const removeTag = (tag: string) => {
    setSelectedTags(prev => prev.filter(t => t !== tag));
  };

  const hasActiveFilters = searchTerm || selectedCategory || selectedLevel || 
                          selectedStatus || selectedComplexity || selectedTags.length > 0;

  return (
    <div className="space-y-6">
      {/* Barre de recherche principale */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Search className="h-5 w-5" />
            Recherche de Scripts
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex gap-2">
            <Input
              placeholder="Rechercher par nom, description, fonction..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
              className="flex-1"
            />
            <Button onClick={handleSearch} disabled={loading}>
              <Search className="h-4 w-4 mr-2" />
              Rechercher
            </Button>
            <Button
              variant="outline"
              onClick={() => setShowAdvanced(!showAdvanced)}
            >
              <Filter className="h-4 w-4 mr-2" />
              Filtres
            </Button>
          </div>

          {/* Filtres avancés */}
          {showAdvanced && (
            <div className="border-t pt-4 space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                <div>
                  <Label htmlFor="category">Catégorie</Label>
                  <Select value={selectedCategory} onValueChange={setSelectedCategory}>
                    <SelectTrigger>
                      <SelectValue placeholder="Toutes les catégories" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="">Toutes les catégories</SelectItem>
                      {filterOptions.categories.map(category => (
                        <SelectItem key={category} value={category}>
                          {category}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                <div>
                  <Label htmlFor="level">Niveau</Label>
                  <Select value={selectedLevel} onValueChange={setSelectedLevel}>
                    <SelectTrigger>
                      <SelectValue placeholder="Tous les niveaux" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="">Tous les niveaux</SelectItem>
                      {filterOptions.levels.map(level => (
                        <SelectItem key={level} value={level}>
                          Niveau {level}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                <div>
                  <Label htmlFor="status">Statut</Label>
                  <Select value={selectedStatus} onValueChange={setSelectedStatus}>
                    <SelectTrigger>
                      <SelectValue placeholder="Tous les statuts" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="">Tous les statuts</SelectItem>
                      {filterOptions.statuses.map(status => (
                        <SelectItem key={status} value={status}>
                          {status}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                <div>
                  <Label htmlFor="complexity">Complexité</Label>
                  <Select value={selectedComplexity} onValueChange={setSelectedComplexity}>
                    <SelectTrigger>
                      <SelectValue placeholder="Toutes complexités" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="">Toutes complexités</SelectItem>
                      {filterOptions.complexities.map(complexity => (
                        <SelectItem key={complexity} value={complexity}>
                          {complexity}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>

              {/* Sélection de tags */}
              {filterOptions.tags.length > 0 && (
                <div>
                  <Label>Tags</Label>
                  <div className="mt-2 flex flex-wrap gap-2 max-h-32 overflow-y-auto">
                    {filterOptions.tags.map(tag => (
                      <div key={tag} className="flex items-center space-x-2">
                        <Checkbox
                          id={`tag-${tag}`}
                          checked={selectedTags.includes(tag)}
                          onCheckedChange={() => toggleTag(tag)}
                        />
                        <Label htmlFor={`tag-${tag}`} className="text-sm">
                          {tag}
                        </Label>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}

          {/* Tags sélectionnés */}
          {selectedTags.length > 0 && (
            <div className="flex flex-wrap gap-2">
              <span className="text-sm font-medium">Tags sélectionnés :</span>
              {selectedTags.map(tag => (
                <Badge key={tag} variant="secondary" className="flex items-center gap-1">
                  {tag}
                  <X
                    className="h-3 w-3 cursor-pointer"
                    onClick={() => removeTag(tag)}
                  />
                </Badge>
              ))}
            </div>
          )}

          {/* Bouton de reset */}
          {hasActiveFilters && (
            <div className="flex justify-end">
              <Button variant="outline" onClick={handleClearFilters}>
                <X className="h-4 w-4 mr-2" />
                Effacer les filtres
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Résultats */}
      <Card>
        <CardHeader>
          <CardTitle>
            Résultats {results.length > 0 && `(${results.length} script${results.length > 1 ? 's' : ''})`}
          </CardTitle>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="text-center py-8">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900 mx-auto"></div>
              <p className="mt-2 text-gray-500">Recherche en cours...</p>
            </div>
          ) : error ? (
            <div className="text-center py-8 text-red-500">
              Erreur : {error}
            </div>
          ) : results.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              {hasActiveFilters ? "Aucun script ne correspond aux critères de recherche" : "Effectuez une recherche pour voir les résultats"}
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {results.map(script => (
                <Card 
                  key={script.id} 
                  className="cursor-pointer hover:shadow-lg transition-shadow"
                  onClick={() => onScriptSelect?.(script)}
                >
                  <CardHeader className="pb-2">
                    <div className="flex justify-between items-start">
                      <h3 className="font-semibold text-lg truncate">{script.name}</h3>
                      <Badge variant={script.status === 'stable' ? 'default' : 'secondary'}>
                        {script.status}
                      </Badge>
                    </div>
                  </CardHeader>
                  <CardContent className="space-y-2">
                    <p className="text-sm text-gray-600 line-clamp-2">
                      {script.description}
                    </p>
                    
                    <div className="flex items-center justify-between text-xs text-gray-500">
                      <span>Niveau {script.level}</span>
                      <span>{script.category}</span>
                    </div>

                    <div className="flex items-center justify-between text-xs">
                      <span className="text-gray-500">Complexité: {script.complexity}</span>
                      <span className="text-blue-600">{script.functions?.length || 0} fonction(s)</span>
                    </div>

                    {script.tags && script.tags.length > 0 && (
                      <div className="flex flex-wrap gap-1 mt-2">
                        {script.tags.slice(0, 3).map(tag => (
                          <Badge key={tag} variant="outline" className="text-xs">
                            {tag}
                          </Badge>
                        ))}
                        {script.tags.length > 3 && (
                          <Badge variant="outline" className="text-xs">
                            +{script.tags.length - 3}
                          </Badge>
                        )}
                      </div>
                    )}
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
};

export default SearchPage;