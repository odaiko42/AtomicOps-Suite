import DependenciesPage from "@/components/DependenciesPage";

export default function Dependencies() {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Dépendances</h2>
        <p className="text-muted-foreground">
          Visualisez les relations entre vos scripts et leurs dépendances
        </p>
      </div>

      <DependenciesPage />
    </div>
  );
}