import { useState } from "react";
import { Outlet } from "react-router-dom";
import { 
  Home, 
  FileCode, 
  Search, 
  BarChart3, 
  Network, 
  Menu,
  X,
  Settings as SettingsIcon,
  Code
} from "lucide-react";
import { cn } from "@/lib/utils";
import { NavLink } from "react-router-dom";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";

  const navigationItems = [
    { icon: Home, label: "Dashboard", path: "/" },
    { icon: FileCode, label: "Scripts", path: "/scripts" },
    { icon: Search, label: "Recherche", path: "/search" },
    { icon: BarChart3, label: "Statistiques", path: "/stats" },
    { icon: Network, label: "Dépendances", path: "/dependencies" },
    { icon: SettingsIcon, label: "Paramètres", path: "/settings" },
    { icon: Code, label: "Builder", path: "/builder" },
  ];

export default function Layout() {
  const [sidebarOpen, setSidebarOpen] = useState(true);

  return (
    <div className="flex h-screen w-full overflow-hidden bg-background">
      {/* Sidebar */}
      <aside
        className={cn(
          "relative flex flex-col border-r border-sidebar-border bg-sidebar transition-all duration-300",
          sidebarOpen ? "w-64" : "w-20"
        )}
      >
        {/* Logo & Toggle */}
        <div className="flex h-16 items-center justify-between border-b border-sidebar-border px-4">
          {sidebarOpen && (
            <div className="flex items-center gap-2">
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary">
                <FileCode className="h-5 w-5 text-primary-foreground" />
              </div>
              <span className="font-semibold text-sidebar-foreground">Script Catalogue</span>
            </div>
          )}
          <button
            onClick={() => setSidebarOpen(!sidebarOpen)}
            className="rounded-lg p-2 hover:bg-sidebar-accent"
          >
            {sidebarOpen ? (
              <X className="h-5 w-5 text-sidebar-foreground" />
            ) : (
              <Menu className="h-5 w-5 text-sidebar-foreground" />
            )}
          </button>
        </div>

        {/* Navigation */}
        <nav className="flex-1 space-y-1 p-4">
          {navigationItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              className={({ isActive }) =>
                cn(
                  "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-all hover:bg-sidebar-accent",
                  isActive
                    ? "bg-sidebar-accent text-sidebar-primary"
                    : "text-sidebar-foreground hover:text-sidebar-primary",
                  !sidebarOpen && "justify-center"
                )
              }
            >
              <item.icon className="h-5 w-5 flex-shrink-0" />
              {sidebarOpen && <span>{item.label}</span>}
            </NavLink>
          ))}
        </nav>
      </aside>

      {/* Main Content */}
      <div className="flex flex-1 flex-col overflow-hidden">
        {/* Header */}
        <header className="flex h-16 items-center justify-between border-b border-border bg-card px-6">
          <h1 className="text-xl font-semibold text-foreground">Script Catalogue Manager</h1>
          <div className="flex items-center gap-4">
            <NavLink to="/settings" className="transition-opacity hover:opacity-80">
              <Avatar className="h-9 w-9 ring-2 ring-primary/20">
                <AvatarImage src="/placeholder.svg" alt="Photo de profil" />
                <AvatarFallback className="bg-primary text-primary-foreground">
                  JD
                </AvatarFallback>
              </Avatar>
            </NavLink>
          </div>
        </header>

        {/* Page Content */}
        <main className="flex-1 overflow-auto p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
