import { FileCode, GitBranch, Activity, TrendingUp } from "lucide-react";
import StatCard from "@/components/StatCard";
import StatsDashboard from "@/components/StatsDashboard";
import RealTimeStats from "@/components/RealTimeStats";
import RecentActivity from "@/components/RecentActivity";

export default function Dashboard() {
  return (
    <div className="space-y-6">
      {/* Page Title */}
      <div>
        <h2 className="text-3xl font-bold tracking-tight text-foreground">Dashboard</h2>
        <p className="text-muted-foreground">Vue d'ensemble de votre catalogue de scripts</p>
      </div>

      {/* Stats en temps réel */}
      <RealTimeStats />

      {/* Activité récente */}
      <RecentActivity />

      {/* Statistiques dynamiques avec graphiques */}
      <StatsDashboard />
    </div>
  );
}
