import React, { useState } from 'react';
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Edit, Check, X, AlertCircle } from "lucide-react";
import { 
  InputParameterBox, 
  InputParameterType, 
  Point2D 
} from '@/types/script-flow';
import { 
  InputValidators, 
  INPUT_PARAMETER_COLORS, 
  INPUT_PARAMETER_LABELS 
} from '@/utils/inputValidators';

interface InputParameterBoxProps {
  parameterBox: InputParameterBox;
  onValueChange: (id: string, value: string) => void;
  onMove: (id: string, position: Point2D) => void;
  onConnectionStart: (boxId: string) => void;
  zoom: number;
}

export const InputParameterBoxComponent: React.FC<InputParameterBoxProps> = ({
  parameterBox,
  onValueChange,
  onMove,
  onConnectionStart,
  zoom
}) => {
  const [isEditing, setIsEditing] = useState(false);
  const [tempValue, setTempValue] = useState(parameterBox.value);
  const [isDragging, setIsDragging] = useState(false);
  const [dragOffset, setDragOffset] = useState<Point2D>({ x: 0, y: 0 });
  const [isExpanded, setIsExpanded] = useState(false);

  // Validation en temps réel
  const validation = InputValidators[parameterBox.type](parameterBox.value);
  const color = INPUT_PARAMETER_COLORS[parameterBox.type];
  const label = INPUT_PARAMETER_LABELS[parameterBox.type];

  const handleStartEdit = () => {
    setTempValue(parameterBox.value);
    setIsEditing(true);
  };

  const handleSaveEdit = () => {
    const tempValidation = InputValidators[parameterBox.type](tempValue);
    if (tempValidation.isValid) {
      onValueChange(parameterBox.id, tempValue);
      setIsEditing(false);
    }
  };

  const handleCancelEdit = () => {
    setTempValue(parameterBox.value);
    setIsEditing(false);
  };

  const handleMouseDown = (e: React.MouseEvent) => {
    if (isEditing) return;
    
    const rect = e.currentTarget.getBoundingClientRect();
    setDragOffset({
      x: e.clientX - rect.left,
      y: e.clientY - rect.top
    });
    setIsDragging(true);
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (isDragging && !isEditing) {
      const newPosition = {
        x: (e.clientX - dragOffset.x) / zoom,
        y: (e.clientY - dragOffset.y) / zoom
      };
      onMove(parameterBox.id, newPosition);
    }
  };

  const handleMouseUp = () => {
    setIsDragging(false);
  };

  const handleConnectionClick = () => {
    onConnectionStart(parameterBox.id);
  };

  const handleToggleExpand = () => {
    setIsExpanded(!isExpanded);
  };

  return (
    <div
      className="absolute"
      style={{
        left: parameterBox.position.x,
        top: parameterBox.position.y,
        transform: `scale(${zoom})`
      }}
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
    >
      {isExpanded ? (
        // Mode étendu - Interface complète
        <Card className={`w-64 border-2 transition-all duration-200 ${validation.isValid ? 'border-green-500' : 'border-red-500'}`}>
          <CardContent className="p-3">
            <div className="flex items-center justify-between mb-2">
              <Badge 
                style={{ backgroundColor: color, color: 'white' }}
                className="text-xs cursor-pointer"
                onClick={handleToggleExpand}
              >
                {label}
              </Badge>
              <div className="flex items-center gap-1">
                {parameterBox.required && (
                  <Badge variant="destructive" className="text-xs">
                    Requis
                  </Badge>
                )}
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-6 w-6 p-0"
                  onClick={handleStartEdit}
                  disabled={isEditing}
                >
                  <Edit className="h-3 w-3" />
                </Button>
              </div>
            </div>

            <div className="flex items-center gap-2 mb-2">
              <div className="font-medium text-sm truncate">
                {parameterBox.name}
              </div>
              {/* Point de sortie pour connexions */}
              <Button
                size="sm"
                variant="outline"
                className="h-6 w-6 p-0 rounded-full border-2"
                style={{ borderColor: color }}
                onClick={handleConnectionClick}
                title="Connecter à des scripts"
              >
                <div 
                  className="w-2 h-2 rounded-full"
                  style={{ backgroundColor: color }}
                />
              </Button>
            </div>

            {isEditing ? (
              <div className="flex items-center gap-2">
                <Input
                  value={tempValue}
                  onChange={(e) => setTempValue(e.target.value)}
                  className="h-8 text-xs"
                  placeholder={parameterBox.defaultValue || `Entrez ${label.toLowerCase()}`}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') handleSaveEdit();
                    if (e.key === 'Escape') handleCancelEdit();
                  }}
                  autoFocus
                />
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-6 w-6 p-0"
                  onClick={handleSaveEdit}
                >
                  <Check className="h-3 w-3 text-green-600" />
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-6 w-6 p-0"
                  onClick={handleCancelEdit}
                >
                  <X className="h-3 w-3 text-red-600" />
                </Button>
              </div>
            ) : (
              <div className="text-sm font-mono bg-gray-100 p-2 rounded">
                {parameterBox.value || (
                  <span className="text-gray-400 italic">
                    {parameterBox.defaultValue || 'Non défini'}
                  </span>
                )}
              </div>
            )}

            {/* Validation */}
            {!validation.isValid && validation.message && (
              <div className="flex items-center gap-1 mt-2 text-xs text-red-600">
                <AlertCircle className="h-3 w-3" />
                <span>{validation.message}</span>
              </div>
            )}

            {/* Connexions actives */}
            {parameterBox.connections.length > 0 && (
              <div className="mt-2 text-xs text-gray-600">
                <span className="font-medium">Connecté à:</span>
                <div className="text-xs">
                  {parameterBox.connections.length} script(s)
                </div>
              </div>
            )}
          </CardContent>
        </Card>
      ) : (
        // Mode compact - Badge cliquable avec point de connexion
        <div 
          className="flex items-center gap-1 cursor-pointer"
          onMouseDown={handleMouseDown}
        >
          <Badge 
            style={{ backgroundColor: color, color: 'white' }}
            className="text-xs transition-all duration-200 hover:scale-105"
            onClick={handleToggleExpand}
          >
            {label}
          </Badge>
          
          {/* Point de connexion compact */}
          <Button
            size="sm"
            variant="outline"
            className="h-5 w-5 p-0 rounded-full border-2"
            style={{ borderColor: color }}
            onClick={handleConnectionClick}
            title={`Connecter ${parameterBox.name}`}
          >
            <div 
              className="w-1.5 h-1.5 rounded-full"
              style={{ backgroundColor: color }}
            />
          </Button>

          {/* Indicateur de validation compact */}
          {!validation.isValid && (
            <AlertCircle className="h-3 w-3 text-red-500" />
          )}

          {/* Indicateur de connexions actives */}
          {parameterBox.connections.length > 0 && (
            <div 
              className="h-2 w-2 rounded-full bg-green-500"
              title={`${parameterBox.connections.length} connexion(s)`}
            />
          )}
        </div>
      )}
    </div>
  );
};