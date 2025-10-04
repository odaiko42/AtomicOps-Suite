import { useState } from "react";
import { TrendingUp, TrendingDown, Calendar, Clock, CheckCircle, XCircle } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

const stats = {
  total: {
    executions: 15247,
    success: 14891,
    errors: 356,
    rate: 97.7,
  },
  topPerformers: [
    { name: "backup-system.sh", executions: 892, rate: 98.5 },
    { name: "detect-usb.sh", executions: 743, rate: 99.2 },
    { name: "check-status.sh", executions: 521, rate: 97.8 },
    { name: "network-config.sh", executions: 445, rate: 96.3 },
    { name: "setup-disk.sh", executions: 389, rate: 99.0 },
  ],
  mostReliable: [
    { name: "get-date.sh", rate: 100, category: "utils", executions: 234 },
    { name: "list-users.sh", rate: 100, category: "system", executions: 189 },
    { name: "get-cpu.sh", rate: 99.9, category: "monitoring", executions: 456 },
    { name: "network-status.sh", rate: 99.2, category: "network", executions: 321 },
  ],
  problematic: [
    { name: "network-config.sh", errorRate: 23, errors: 45, executions: 195 },
    { name: "deploy-app.sh", errorRate: 15, errors: 28, executions: 187 },
    { name: "database-backup.sh", errorRate: 8, errors: 12, executions: 150 },
  ],
  daily: [
    { day: "Lun", executions: 523, success: 98.3 },
    { day: "Mar", executions: 498, success: 97.5 },
    { day: "Mer", executions: 567, success: 98.1 },
    { day: "Jeu", executions: 612, success: 97.9 },
    { day: "Ven", executions: 589, success: 96.8 },
    { day: "Sam", executions: 234, success: 99.1 },
    { day: "Dim", executions: 198, success: 99.5 },
  ],
};

export default function Stats() {
  const [period, setPeriod] = useState("30");

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight text-foreground">Statistiques & Analytics</h2>
          <p className="text-muted-foreground">Analyse détaillée de l'utilisation des scripts</p>
        </div>
        <Select value={period} onValueChange={setPeriod}>
          <SelectTrigger className="w-[200px]">
            <Calendar className="mr-2 h-4 w-4" />
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="7">7 derniers jours</SelectItem>
            <SelectItem value="30">30 derniers jours</SelectItem>
            <SelectItem value="90">90 derniers jours</SelectItem>
            <SelectItem value="365">1 an</SelectItem>
          </SelectContent>
        </Select>
      </div>

      {/* Main Stats */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card className="p-6">
          <div className="flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-primary/10">
              <Clock className="h-6 w-6 text-primary" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">Exécutions</p>
              <p className="text-2xl font-bold text-foreground">{stats.total.executions.toLocaleString()}</p>
            </div>
          </div>
        </Card>

        <Card className="p-6">
          <div className="flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-success/10">
              <CheckCircle className="h-6 w-6 text-success" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">Succès</p>
              <p className="text-2xl font-bold text-success">{stats.total.success.toLocaleString()}</p>
            </div>
          </div>
        </Card>

        <Card className="p-6">
          <div className="flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-destructive/10">
              <XCircle className="h-6 w-6 text-destructive" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">Erreurs</p>
              <p className="text-2xl font-bold text-destructive">{stats.total.errors}</p>
            </div>
          </div>
        </Card>

        <Card className="p-6">
          <div className="flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-primary/10">
              <TrendingUp className="h-6 w-6 text-primary" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">Taux de succès</p>
              <p className="text-2xl font-bold text-foreground">{stats.total.rate}%</p>
            </div>
          </div>
        </Card>
      </div>

      {/* Activity Chart */}
      <Card className="p-6">
        <h3 className="mb-6 text-lg font-semibold text-foreground">📈 Activité de la semaine</h3>
        <div className="space-y-4">
          {stats.daily.map((day) => (
            <div key={day.day} className="space-y-2">
              <div className="flex items-center justify-between text-sm">
                <span className="w-12 font-medium text-foreground">{day.day}</span>
                <span className="text-muted-foreground">{day.executions} exec.</span>
                <Badge variant={day.success >= 98 ? "default" : "secondary"}>
                  {day.success}%
                </Badge>
              </div>
              <div className="h-2 w-full overflow-hidden rounded-full bg-muted">
                <div
                  className="h-full rounded-full bg-primary transition-all"
                  style={{ width: `${(day.executions / 650) * 100}%` }}
                />
              </div>
            </div>
          ))}
        </div>
      </Card>

      {/* Performance Tables */}
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Top Performers */}
        <Card className="p-6">
          <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold text-foreground">
            🏆 Scripts les plus utilisés
          </h3>
          <div className="space-y-4">
            {stats.topPerformers.map((script, index) => (
              <div key={script.name} className="flex items-center gap-4">
                <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10 text-lg font-bold text-primary">
                  {index + 1}
                </div>
                <div className="flex-1">
                  <p className="font-medium text-foreground">{script.name}</p>
                  <div className="mt-1 flex items-center gap-2">
                    <span className="text-sm text-muted-foreground">{script.executions} exec.</span>
                    <span className="text-sm text-success">• {script.rate}%</span>
                  </div>
                </div>
                <div className="h-2 w-24 overflow-hidden rounded-full bg-muted">
                  <div
                    className="h-full rounded-full bg-primary"
                    style={{ width: `${(script.executions / 900) * 100}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </Card>

        {/* Most Reliable */}
        <Card className="p-6">
          <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold text-foreground">
            ✅ Scripts les plus fiables
          </h3>
          <div className="space-y-4">
            {stats.mostReliable.map((script, index) => (
              <div key={script.name} className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-success/10 text-lg font-bold text-success">
                    {index + 1}
                  </div>
                  <div>
                    <p className="font-medium text-foreground">{script.name}</p>
                    <div className="flex items-center gap-2">
                      <Badge variant="outline" className="text-xs">
                        {script.category}
                      </Badge>
                      <span className="text-xs text-muted-foreground">{script.executions} exec.</span>
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-lg font-semibold text-success">{script.rate}%</span>
                  {script.rate === 100 && <CheckCircle className="h-5 w-5 text-success" />}
                </div>
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* Problematic Scripts */}
      <Card className="p-6">
        <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold text-destructive">
          ⚠️ Scripts problématiques
        </h3>
        <div className="space-y-4">
          {stats.problematic.map((script) => (
            <div key={script.name} className="rounded-lg border border-destructive/20 bg-destructive/5 p-4">
              <div className="flex items-center justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-3">
                    <p className="font-medium text-foreground">{script.name}</p>
                    <Badge variant="destructive">{script.errorRate}% d'échecs</Badge>
                  </div>
                  <p className="mt-1 text-sm text-muted-foreground">
                    {script.errors} erreurs sur {script.executions} exécutions
                  </p>
                </div>
                <TrendingDown className="h-6 w-6 text-destructive" />
              </div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}
