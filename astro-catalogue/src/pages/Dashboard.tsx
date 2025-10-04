import { FileCode, GitBranch, Activity, TrendingUp } from "lucide-react";
import StatCard from "@/components/StatCard";
import StatsDashboard from "@/components/StatsDashboard";

export default function Dashboard() {
  return (
    <div className="space-y-6">
      {/* Page Title */}
      <div>
        <h2 className="text-3xl font-bold tracking-tight text-foreground">Dashboard</h2>
        <p className="text-muted-foreground">Vue d'ensemble de votre catalogue de scripts</p>
      </div>

      {/* Stats Grid */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <StatCard
          icon={FileCode}
          title="Total Scripts"
          value="247"
          subtitle="scripts actifs"
          trend={{ value: "12", positive: true }}
        />
        <StatCard
          icon={Activity}
          title="Scripts Atomiques"
          value="189"
          subtitle="76% du catalogue"
        />
        <StatCard
          icon={GitBranch}
          title="Orchestrateurs"
          value="58"
          subtitle="24% du catalogue"
        />
        <StatCard
          icon={TrendingUp}
          title="Taux de Succès"
          value="97.7%"
          subtitle="30 derniers jours"
          trend={{ value: "2.3%", positive: true }}
        />
      </div>

      {/* Activity Chart */}
      <div className="rounded-xl bg-card p-6 card-shadow border border-border">
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h3 className="text-lg font-semibold text-foreground">Activité des 30 derniers jours</h3>
            <p className="text-sm text-muted-foreground">Exécutions et taux de succès</p>
          </div>
          <div className="flex gap-4">
            <div className="flex items-center gap-2">
              <div className="h-3 w-3 rounded-full bg-primary" />
              <span className="text-sm text-muted-foreground">Exécutions</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="h-3 w-3 rounded-full bg-success" />
              <span className="text-sm text-muted-foreground">Succès</span>
            </div>
          </div>
        </div>
        
        {/* Placeholder for chart */}
        <div className="flex h-64 items-center justify-center rounded-lg bg-muted/20">
          <p className="text-muted-foreground">📈 Graphique d'activité</p>
        </div>
      </div>

      {/* Statistiques dynamiques avec graphiques */}
      <StatsDashboard />
    </div>
  );
}
