import { Moon, Sun } from "lucide-react";
import { useTheme } from "@/hooks/useTheme";
import { cn } from "@/lib/utils";

interface ThemeToggleProps {
  className?: string;
}

export function ThemeToggle({ className }: ThemeToggleProps) {
  const { theme, toggleTheme } = useTheme();

  return (
    <button
      onClick={toggleTheme}
      className={cn(
        "flex items-center justify-center rounded-lg p-2 transition-all duration-200",
        "hover:bg-sidebar-accent border border-border",
        "focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2",
        className
      )}
      title={theme === 'dark' ? 'Basculer vers le thème clair' : 'Basculer vers le thème sombre'}
      aria-label={`Basculer vers le thème ${theme === 'dark' ? 'clair' : 'sombre'}`}
    >
      {theme === 'dark' ? (
        <Sun className="h-5 w-5 text-sidebar-foreground transition-transform hover:rotate-12" />
      ) : (
        <Moon className="h-5 w-5 text-sidebar-foreground transition-transform hover:-rotate-12" />
      )}
    </button>
  );
}