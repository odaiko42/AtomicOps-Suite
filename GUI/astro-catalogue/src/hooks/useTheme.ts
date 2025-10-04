import { useState, useEffect } from 'react';

export type Theme = 'dark' | 'light';

export function useTheme() {
  const [theme, setTheme] = useState<Theme>(() => {
    // Vérifier si un thème est sauvegardé dans localStorage
    const savedTheme = localStorage.getItem('theme') as Theme;
    // Par défaut, utiliser le thème sombre
    return savedTheme || 'dark';
  });

  useEffect(() => {
    // Sauvegarder le thème dans localStorage
    localStorage.setItem('theme', theme);
    
    // Appliquer le thème au document
    const root = document.documentElement;
    
    if (theme === 'light') {
      // Thème clair - variables CSS
      root.style.setProperty('--background', '220 8% 88%');
      root.style.setProperty('--foreground', '220 15% 25%');
      root.style.setProperty('--card', '220 15% 93%');
      root.style.setProperty('--card-foreground', '220 15% 25%');
      root.style.setProperty('--popover', '220 20% 91%');
      root.style.setProperty('--popover-foreground', '220 15% 25%');
      root.style.setProperty('--muted', '220 10% 82%');
      root.style.setProperty('--muted-foreground', '220 15% 45%');
      root.style.setProperty('--border', '220 12% 78%');
      root.style.setProperty('--input', '220 15% 85%');
      root.style.setProperty('--sidebar-background', '220 12% 90%');
      root.style.setProperty('--sidebar-foreground', '220 15% 25%');
      root.style.setProperty('--sidebar-accent', '220 15% 83%');
      root.style.setProperty('--sidebar-accent-foreground', '220 15% 25%');
      root.style.setProperty('--sidebar-border', '220 12% 78%');
      root.style.setProperty('--accent-foreground', '220 15% 95%');
      root.style.setProperty('--sidebar-primary-foreground', '220 15% 95%');
    } else {
      // Thème sombre - valeurs harmonisées
      root.style.setProperty('--background', '222 47% 8%');
      root.style.setProperty('--foreground', '210 40% 98%');
      root.style.setProperty('--card', '220 25% 12%');
      root.style.setProperty('--card-foreground', '210 40% 98%');
      root.style.setProperty('--popover', '220 30% 10%');
      root.style.setProperty('--popover-foreground', '210 40% 98%');
      root.style.setProperty('--muted', '220 20% 15%');
      root.style.setProperty('--muted-foreground', '215 20% 70%');
      root.style.setProperty('--border', '220 15% 18%');
      root.style.setProperty('--input', '220 20% 14%');
      root.style.setProperty('--sidebar-background', '220 25% 10%');
      root.style.setProperty('--sidebar-foreground', '210 40% 98%');
      root.style.setProperty('--sidebar-accent', '220 20% 15%');
      root.style.setProperty('--sidebar-accent-foreground', '210 40% 98%');
      root.style.setProperty('--sidebar-border', '220 15% 18%');
      root.style.setProperty('--accent-foreground', '210 40% 98%');
      root.style.setProperty('--sidebar-primary-foreground', '210 40% 98%');
    }
  }, [theme]);

  const toggleTheme = () => {
    setTheme(prev => prev === 'dark' ? 'light' : 'dark');
  };

  return { theme, toggleTheme };
}