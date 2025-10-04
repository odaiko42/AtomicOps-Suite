import SearchPage from "@/components/SearchPage";

export default function Search() {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Recherche</h2>
        <p className="text-muted-foreground">
          Trouvez rapidement les scripts dont vous avez besoin
        </p>
      </div>

      <SearchPage />
    </div>
  );
}