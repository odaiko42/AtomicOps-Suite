import React, { useState, useRef, useEffect } from 'react';
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { 
  ValidationType, 
  ValidationRules, 
  VALIDATION_TYPE_COLORS,
  ValueBox as ValueBoxType,
  Point2D 
} from '@/types/input-validation';
import { 
  Edit3, 
  Check, 
  X, 
  AlertCircle, 
  CheckCircle,
  Network,
  User,
  Mail,
  Globe,
  HardDrive,
  Hash
} from "lucide-react";

interface ValueBoxProps {
  valueBox: ValueBoxType;
  zoom: number;
  camera: { x: number; y: number };
  onValueChange: (id: string, value: string) => void;
  onMove: (id: string, position: Point2D) => void;
  onDelete?: (id: string) => void;
  isSelected?: boolean;
  onSelect?: (id: string) => void;
}

interface DragState {
  isDragging: boolean;
  offset: Point2D;
}

// Icônes par type de validation
const ValidationIcons = {
  [ValidationType.IP]: Network,
  [ValidationType.HOSTNAME]: Globe,
  [ValidationType.EMAIL]: Mail,
  [ValidationType.URL]: Globe,
  [ValidationType.IQN]: HardDrive,
  [ValidationType.USERNAME]: User,
  [ValidationType.PATH]: HardDrive,
  [ValidationType.DEVICE]: HardDrive,
  [ValidationType.PORT]: Hash,
  [ValidationType.NUMBER]: Hash,
  [ValidationType.STRING]: Hash,
  [ValidationType.BOOLEAN]: CheckCircle,
  [ValidationType.ENUM]: Hash
};

export const ValueBox: React.FC<ValueBoxProps> = ({
  valueBox,
  zoom,
  camera,
  onValueChange,
  onMove,
  onDelete,
  isSelected = false,
  onSelect
}) => {
  const [isEditing, setIsEditing] = useState(false);
  const [editValue, setEditValue] = useState(valueBox.value);
  const [dragState, setDragState] = useState<DragState>({ isDragging: false, offset: { x: 0, y: 0 } });
  
  const boxRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Validation de la valeur
  const validateValue = (value: string): boolean => {
    const rule = ValidationRules[valueBox.type];
    if (!rule) return true;
    
    if (valueBox.type === ValidationType.ENUM) {
      // Pour les enum, on aurait besoin des valeurs possibles
      return rule.validate(value, ['option1', 'option2']); // Placeholder
    }
    
    return rule.validate(value);
  };

  const isValid = validateValue(valueBox.value);
  const color = VALIDATION_TYPE_COLORS[valueBox.type];
  const IconComponent = ValidationIcons[valueBox.type];

  // Gestion du drag & drop
  const handleMouseDown = (e: React.MouseEvent) => {
    if (isEditing) return;
    
    e.preventDefault();
    e.stopPropagation();
    
    onSelect?.(valueBox.id);
    
    const rect = boxRef.current?.getBoundingClientRect();
    if (!rect) return;

    const offset = {
      x: (e.clientX - camera.x) / zoom - valueBox.position.x,
      y: (e.clientY - camera.y) / zoom - valueBox.position.y
    };

    setDragState({ isDragging: true, offset });
  };

  const handleMouseMove = (e: MouseEvent) => {
    if (!dragState.isDragging) return;

    const newPosition = {
      x: (e.clientX - camera.x) / zoom - dragState.offset.x,
      y: (e.clientY - camera.y) / zoom - dragState.offset.y
    };

    onMove(valueBox.id, newPosition);
  };

  const handleMouseUp = () => {
    setDragState({ isDragging: false, offset: { x: 0, y: 0 } });
  };

  useEffect(() => {
    if (dragState.isDragging) {
      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);
      
      return () => {
        document.removeEventListener('mousemove', handleMouseMove);
        document.removeEventListener('mouseup', handleMouseUp);
      };
    }
  }, [dragState.isDragging]);

  // Gestion de l'édition
  const startEditing = (e: React.MouseEvent) => {
    e.stopPropagation();
    setIsEditing(true);
    setEditValue(valueBox.value);
    
    setTimeout(() => inputRef.current?.focus(), 100);
  };

  const saveValue = () => {
    if (validateValue(editValue)) {
      onValueChange(valueBox.id, editValue);
      setIsEditing(false);
    }
  };

  const cancelEdit = () => {
    setEditValue(valueBox.value);
    setIsEditing(false);
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      saveValue();
    } else if (e.key === 'Escape') {
      cancelEdit();
    }
  };

  // Style de la boîte
  const boxStyle = {
    position: 'absolute' as const,
    left: valueBox.position.x,
    top: valueBox.position.y,
    transform: `scale(${zoom})`,
    transformOrigin: 'top left',
    zIndex: isSelected ? 1000 : 100,
    cursor: dragState.isDragging ? 'grabbing' : 'grab'
  };

  return (
    <div
      ref={boxRef}
      style={boxStyle}
      className={`select-none transition-all duration-200 ${
        isSelected ? 'ring-2 ring-blue-500 ring-opacity-75' : ''
      }`}
      onMouseDown={handleMouseDown}
    >
      <Card className={`w-64 shadow-lg border-2 transition-all duration-200 ${
        isValid 
          ? 'border-green-400 bg-green-50 hover:border-green-500' 
          : 'border-red-400 bg-red-50 hover:border-red-500'
      }`}>
        <CardContent className="p-3 space-y-2">
          {/* En-tête avec type et icône */}
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-2">
              <IconComponent 
                size={16} 
                style={{ color }} 
              />
              <Badge 
                variant="outline"
                style={{ 
                  borderColor: color,
                  color: color,
                  backgroundColor: `${color}15`
                }}
                className="text-xs font-medium"
              >
                {valueBox.type.toUpperCase()}
              </Badge>
            </div>
            
            <div className="flex items-center space-x-1">
              {/* Indicateur de validation */}
              {isValid ? (
                <CheckCircle size={16} className="text-green-500" />
              ) : (
                <AlertCircle size={16} className="text-red-500" />
              )}
              
              {/* Bouton d'édition */}
              <Button
                size="sm"
                variant="ghost"
                className="h-6 w-6 p-0 hover:bg-white/50"
                onClick={startEditing}
              >
                <Edit3 size={12} />
              </Button>
              
              {/* Bouton de suppression (optionnel) */}
              {onDelete && (
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-6 w-6 p-0 hover:bg-red-100 text-red-600"
                  onClick={(e) => {
                    e.stopPropagation();
                    onDelete(valueBox.id);
                  }}
                >
                  <X size={12} />
                </Button>
              )}
            </div>
          </div>

          {/* Label */}
          <div className="text-sm font-medium text-gray-700">
            {valueBox.label}
          </div>

          {/* Valeur ou input d'édition */}
          {isEditing ? (
            <div className="space-y-2">
              <Input
                ref={inputRef}
                value={editValue}
                onChange={(e) => setEditValue(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder={ValidationRules[valueBox.type]?.placeholder || ''}
                className={`text-sm ${
                  validateValue(editValue)
                    ? 'border-green-300 focus:border-green-500'
                    : 'border-red-300 focus:border-red-500'
                }`}
              />
              
              <div className="flex space-x-1">
                <Button
                  size="sm"
                  onClick={saveValue}
                  disabled={!validateValue(editValue)}
                  className="h-6 text-xs bg-green-600 hover:bg-green-700"
                >
                  <Check size={12} className="mr-1" />
                  Save
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={cancelEdit}
                  className="h-6 text-xs"
                >
                  <X size={12} className="mr-1" />
                  Cancel
                </Button>
              </div>
            </div>
          ) : (
            <div 
              className={`text-sm p-2 rounded border ${
                isValid 
                  ? 'bg-white border-green-200 text-gray-900' 
                  : 'bg-red-50 border-red-200 text-red-900'
              }`}
            >
              {valueBox.value || (
                <span className="italic text-gray-400">
                  {ValidationRules[valueBox.type]?.placeholder || 'No value'}
                </span>
              )}
            </div>
          )}

          {/* Description ou message d'erreur */}
          {valueBox.description && (
            <div className="text-xs text-gray-500">
              {valueBox.description}
            </div>
          )}
          
          {!isValid && valueBox.value && (
            <div className="text-xs text-red-600 flex items-center space-x-1">
              <AlertCircle size={12} />
              <span>Invalid {valueBox.type} format</span>
            </div>
          )}

          {/* Compteur de connexions */}
          {valueBox.connectedTo.length > 0 && (
            <div className="flex items-center space-x-1">
              <div className="w-2 h-2 bg-blue-500 rounded-full"></div>
              <span className="text-xs text-gray-600">
                Connected to {valueBox.connectedTo.length} script{valueBox.connectedTo.length > 1 ? 's' : ''}
              </span>
            </div>
          )}
        </CardContent>
        
        {/* Point de sortie pour les connexions */}
        <div
          className="absolute right-0 top-1/2 transform translate-x-1/2 -translate-y-1/2 w-3 h-3 rounded-full border-2 border-white shadow-md transition-all duration-200 hover:scale-125"
          style={{ backgroundColor: color }}
          data-output-socket={valueBox.id}
          data-output-type={valueBox.type}
        />
      </Card>
    </div>
  );
};