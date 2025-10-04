import { useState } from "react";
import { Search, Filter, Plus, Eye, Edit, Trash2, Atom, GitBranch } from "lucide-react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { toast } from "sonner";

const scriptFormSchema = z.object({
  name: z.string().min(3, "Le nom doit contenir au moins 3 caractères").max(100),
  description: z.string().min(10, "La description doit contenir au moins 10 caractères").max(500),
  type: z.enum(["atomic", "orchestrator"], {
    required_error: "Veuillez sélectionner un type",
  }),
  category: z.string().min(1, "Veuillez sélectionner une catégorie"),
  version: z.string().regex(/^\d+\.\d+\.\d+$/, "Format de version invalide (ex: 1.0.0)"),
  status: z.enum(["active", "deprecated", "development"]),
  author: z.string().min(2, "Le nom de l'auteur est requis"),
  tags: z.string().optional(),
});

type ScriptFormValues = z.infer<typeof scriptFormSchema>;

const mockScripts = [
  {
    id: 1,
    name: "detect-usb.sh",
    type: "atomic",
    category: "storage",
    status: "active",
    version: "1.2.0",
    executions: 892,
    success: 98.5,
  },
  {
    id: 2,
    name: "format-disk.sh",
    type: "atomic",
    category: "storage",
    status: "active",
    version: "2.0.1",
    executions: 456,
    success: 97.2,
  },
  {
    id: 3,
    name: "setup-disk.sh",
    type: "orchestrator",
    category: "storage",
    status: "active",
    version: "1.5.0",
    executions: 521,
    success: 99.1,
  },
  {
    id: 4,
    name: "backup-system.sh",
    type: "orchestrator",
    category: "backup",
    status: "active",
    version: "3.1.2",
    executions: 743,
    success: 96.8,
  },
];

const categories = [
  "storage",
  "backup",
  "network",
  "security",
  "system",
  "monitoring",
  "deployment",
  "database",
];

export default function Scripts() {
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedScript, setSelectedScript] = useState<typeof mockScripts[0] | null>(null);
  const [newScriptDialogOpen, setNewScriptDialogOpen] = useState(false);
  const [editScriptDialogOpen, setEditScriptDialogOpen] = useState(false);
  const [deleteScriptDialogOpen, setDeleteScriptDialogOpen] = useState(false);
  const [scriptToEdit, setScriptToEdit] = useState<typeof mockScripts[0] | null>(null);
  const [scriptToDelete, setScriptToDelete] = useState<typeof mockScripts[0] | null>(null);

  const form = useForm<ScriptFormValues>({
    resolver: zodResolver(scriptFormSchema),
    defaultValues: {
      name: "",
      description: "",
      type: "atomic",
      category: "",
      version: "1.0.0",
      status: "active",
      author: "",
      tags: "",
    },
  });

  const editForm = useForm<ScriptFormValues>({
    resolver: zodResolver(scriptFormSchema),
    defaultValues: {
      name: "",
      description: "",
      type: "atomic",
      category: "",
      version: "1.0.0",
      status: "active",
      author: "",
      tags: "",
    },
  });

  const onSubmit = (data: ScriptFormValues) => {
    console.log("Nouveau script:", data);
    toast.success("Script créé avec succès!", {
      description: `${data.name} a été ajouté au catalogue`,
    });
    setNewScriptDialogOpen(false);
    form.reset();
  };

  const onEdit = (data: ScriptFormValues) => {
    console.log("Script modifié:", data);
    toast.success("Script modifié avec succès!", {
      description: `${data.name} a été mis à jour`,
    });
    setEditScriptDialogOpen(false);
    setScriptToEdit(null);
    editForm.reset();
  };

  const handleEditClick = (script: typeof mockScripts[0]) => {
    setScriptToEdit(script);
    editForm.reset({
      name: script.name,
      description: "Détecte et liste tous les périphériques USB de stockage connectés", // Mock description
      type: script.type as "atomic" | "orchestrator",
      category: script.category,
      version: script.version,
      status: script.status as "active" | "deprecated" | "development",
      author: "DevOps Team", // Mock author
      tags: "usb, storage, detection",
    });
    setEditScriptDialogOpen(true);
  };

  const handleDeleteClick = (script: typeof mockScripts[0]) => {
    setScriptToDelete(script);
    setDeleteScriptDialogOpen(true);
  };

  const confirmDelete = () => {
    if (scriptToDelete) {
      console.log("Script supprimé:", scriptToDelete);
      toast.success("Script supprimé", {
        description: `${scriptToDelete.name} a été retiré du catalogue`,
      });
      setDeleteScriptDialogOpen(false);
      setScriptToDelete(null);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight text-foreground">Scripts</h2>
          <p className="text-muted-foreground">Gérez votre catalogue de scripts</p>
        </div>
        <Button className="gap-2" onClick={() => setNewScriptDialogOpen(true)}>
          <Plus className="h-4 w-4" />
          Nouveau Script
        </Button>
      </div>

      {/* Filters */}
      <div className="flex gap-4">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Rechercher un script..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-10"
          />
        </div>
        <Button variant="outline" className="gap-2">
          <Filter className="h-4 w-4" />
          Filtres
        </Button>
      </div>

      {/* Scripts Table */}
      <div className="rounded-xl border border-border bg-card card-shadow">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Nom</TableHead>
              <TableHead>Type</TableHead>
              <TableHead>Catégorie</TableHead>
              <TableHead>Version</TableHead>
              <TableHead>Exec.</TableHead>
              <TableHead>Succès</TableHead>
              <TableHead className="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {mockScripts
              .filter((script) =>
                script.name.toLowerCase().includes(searchTerm.toLowerCase())
              )
              .map((script) => (
                <TableRow
                  key={script.id}
                  className="cursor-pointer transition-colors hover:bg-muted/50"
                  onClick={() => setSelectedScript(script)}
                >
                  <TableCell className="font-medium">{script.name}</TableCell>
                  <TableCell>
                    <Badge variant={script.type === "atomic" ? "default" : "secondary"} className="gap-1">
                      {script.type === "atomic" ? (
                        <Atom className="h-3 w-3" />
                      ) : (
                        <GitBranch className="h-3 w-3" />
                      )}
                      {script.type === "atomic" ? "Atomique" : "Orchestrateur"}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <Badge variant="outline">{script.category}</Badge>
                  </TableCell>
                  <TableCell className="text-muted-foreground">{script.version}</TableCell>
                  <TableCell className="text-muted-foreground">{script.executions}</TableCell>
                  <TableCell>
                    <span className="font-medium text-success">{script.success}%</span>
                  </TableCell>
                  <TableCell className="text-right">
                    <div className="flex justify-end gap-2">
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={(e) => {
                          e.stopPropagation();
                          setSelectedScript(script);
                        }}
                        title="Voir les détails"
                      >
                        <Eye className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={(e) => {
                          e.stopPropagation();
                          handleEditClick(script);
                        }}
                        title="Modifier"
                      >
                        <Edit className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={(e) => {
                          e.stopPropagation();
                          handleDeleteClick(script);
                        }}
                        title="Supprimer"
                      >
                        <Trash2 className="h-4 w-4 text-destructive" />
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
          </TableBody>
        </Table>
      </div>

      {/* Edit Script Dialog */}
      <Dialog open={editScriptDialogOpen} onOpenChange={setEditScriptDialogOpen}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Edit className="h-5 w-5" />
              Modifier le script
            </DialogTitle>
          </DialogHeader>

          <Form {...editForm}>
            <form onSubmit={editForm.handleSubmit(onEdit)} className="space-y-6">
              {/* Nom du script */}
              <FormField
                control={editForm.control}
                name="name"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Nom du script *</FormLabel>
                    <FormControl>
                      <Input placeholder="detect-usb.sh" {...field} />
                    </FormControl>
                    <FormDescription>
                      Le nom du fichier script (incluant l'extension)
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

              {/* Description */}
              <FormField
                control={editForm.control}
                name="description"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Description *</FormLabel>
                    <FormControl>
                      <Textarea
                        placeholder="Détecte et liste tous les périphériques USB de stockage connectés..."
                        className="resize-none"
                        rows={3}
                        {...field}
                      />
                    </FormControl>
                    <FormDescription>
                      Description claire et concise du script
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

              {/* Type */}
              <FormField
                control={editForm.control}
                name="type"
                render={({ field }) => (
                  <FormItem className="space-y-3">
                    <FormLabel>Type de script *</FormLabel>
                    <FormControl>
                      <RadioGroup
                        onValueChange={field.onChange}
                        value={field.value}
                        className="flex gap-4"
                      >
                        <FormItem className="flex items-center space-x-3 space-y-0">
                          <FormControl>
                            <RadioGroupItem value="atomic" />
                          </FormControl>
                          <FormLabel className="flex items-center gap-2 font-normal cursor-pointer">
                            <Atom className="h-4 w-4 text-primary" />
                            Atomique
                          </FormLabel>
                        </FormItem>
                        <FormItem className="flex items-center space-x-3 space-y-0">
                          <FormControl>
                            <RadioGroupItem value="orchestrator" />
                          </FormControl>
                          <FormLabel className="flex items-center gap-2 font-normal cursor-pointer">
                            <GitBranch className="h-4 w-4 text-secondary" />
                            Orchestrateur
                          </FormLabel>
                        </FormItem>
                      </RadioGroup>
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <div className="grid gap-6 md:grid-cols-2">
                {/* Catégorie */}
                <FormField
                  control={editForm.control}
                  name="category"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Catégorie *</FormLabel>
                      <Select onValueChange={field.onChange} value={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue placeholder="Sélectionner une catégorie" />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          {categories.map((cat) => (
                            <SelectItem key={cat} value={cat}>
                              {cat}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                {/* Version */}
                <FormField
                  control={editForm.control}
                  name="version"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Version *</FormLabel>
                      <FormControl>
                        <Input placeholder="1.0.0" {...field} />
                      </FormControl>
                      <FormDescription>Format: X.Y.Z</FormDescription>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                {/* Statut */}
                <FormField
                  control={editForm.control}
                  name="status"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Statut *</FormLabel>
                      <Select onValueChange={field.onChange} value={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          <SelectItem value="active">Actif</SelectItem>
                          <SelectItem value="development">En développement</SelectItem>
                          <SelectItem value="deprecated">Deprecated</SelectItem>
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                {/* Auteur */}
                <FormField
                  control={editForm.control}
                  name="author"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Auteur *</FormLabel>
                      <FormControl>
                        <Input placeholder="DevOps Team" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>

              {/* Tags */}
              <FormField
                control={editForm.control}
                name="tags"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Tags</FormLabel>
                    <FormControl>
                      <Input placeholder="usb, storage, detection, hardware" {...field} />
                    </FormControl>
                    <FormDescription>
                      Séparés par des virgules (optionnel)
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <div className="flex gap-3 pt-4">
                <Button
                  type="button"
                  variant="outline"
                  className="flex-1"
                  onClick={() => {
                    setEditScriptDialogOpen(false);
                    setScriptToEdit(null);
                    editForm.reset();
                  }}
                >
                  Annuler
                </Button>
                <Button type="submit" className="flex-1 gap-2">
                  <Edit className="h-4 w-4" />
                  Enregistrer les modifications
                </Button>
              </div>
            </form>
          </Form>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog open={deleteScriptDialogOpen} onOpenChange={setDeleteScriptDialogOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 text-destructive">
              <Trash2 className="h-5 w-5" />
              Supprimer le script ?
            </DialogTitle>
          </DialogHeader>

          <div className="space-y-4">
            <div className="rounded-lg bg-destructive/10 p-4">
              <p className="text-sm text-foreground">
                Êtes-vous sûr de vouloir supprimer{" "}
                <span className="font-semibold">{scriptToDelete?.name}</span> ?
              </p>
              <p className="mt-2 text-sm text-muted-foreground">
                Cette action est irréversible et supprimera définitivement ce script du catalogue.
              </p>
            </div>

            {scriptToDelete && (
              <div className="space-y-2 text-sm">
                <div className="flex items-center justify-between">
                  <span className="text-muted-foreground">Type:</span>
                  <Badge variant={scriptToDelete.type === "atomic" ? "default" : "secondary"}>
                    {scriptToDelete.type === "atomic" ? "Atomique" : "Orchestrateur"}
                  </Badge>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-muted-foreground">Catégorie:</span>
                  <span className="font-medium">{scriptToDelete.category}</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-muted-foreground">Version:</span>
                  <span className="font-medium">{scriptToDelete.version}</span>
                </div>
              </div>
            )}

            <div className="flex gap-3 pt-2">
              <Button
                variant="outline"
                className="flex-1"
                onClick={() => {
                  setDeleteScriptDialogOpen(false);
                  setScriptToDelete(null);
                }}
              >
                Annuler
              </Button>
              <Button
                variant="destructive"
                className="flex-1 gap-2"
                onClick={confirmDelete}
              >
                <Trash2 className="h-4 w-4" />
                Supprimer
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* New Script Dialog */}
      <Dialog open={newScriptDialogOpen} onOpenChange={setNewScriptDialogOpen}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Plus className="h-5 w-5" />
              Créer un nouveau script
            </DialogTitle>
          </DialogHeader>

          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
              {/* Nom du script */}
              <FormField
                control={form.control}
                name="name"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Nom du script *</FormLabel>
                    <FormControl>
                      <Input placeholder="detect-usb.sh" {...field} />
                    </FormControl>
                    <FormDescription>
                      Le nom du fichier script (incluant l'extension)
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

              {/* Description */}
              <FormField
                control={form.control}
                name="description"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Description *</FormLabel>
                    <FormControl>
                      <Textarea
                        placeholder="Détecte et liste tous les périphériques USB de stockage connectés..."
                        className="resize-none"
                        rows={3}
                        {...field}
                      />
                    </FormControl>
                    <FormDescription>
                      Description claire et concise du script
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

              {/* Type */}
              <FormField
                control={form.control}
                name="type"
                render={({ field }) => (
                  <FormItem className="space-y-3">
                    <FormLabel>Type de script *</FormLabel>
                    <FormControl>
                      <RadioGroup
                        onValueChange={field.onChange}
                        defaultValue={field.value}
                        className="flex gap-4"
                      >
                        <FormItem className="flex items-center space-x-3 space-y-0">
                          <FormControl>
                            <RadioGroupItem value="atomic" />
                          </FormControl>
                          <FormLabel className="flex items-center gap-2 font-normal cursor-pointer">
                            <Atom className="h-4 w-4 text-primary" />
                            Atomique
                          </FormLabel>
                        </FormItem>
                        <FormItem className="flex items-center space-x-3 space-y-0">
                          <FormControl>
                            <RadioGroupItem value="orchestrator" />
                          </FormControl>
                          <FormLabel className="flex items-center gap-2 font-normal cursor-pointer">
                            <GitBranch className="h-4 w-4 text-secondary" />
                            Orchestrateur
                          </FormLabel>
                        </FormItem>
                      </RadioGroup>
                    </FormControl>
                    <FormDescription>
                      Atomique: script de base. Orchestrateur: combine plusieurs scripts
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <div className="grid gap-6 md:grid-cols-2">
                {/* Catégorie */}
                <FormField
                  control={form.control}
                  name="category"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Catégorie *</FormLabel>
                      <Select onValueChange={field.onChange} defaultValue={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue placeholder="Sélectionner une catégorie" />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          {categories.map((cat) => (
                            <SelectItem key={cat} value={cat}>
                              {cat}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                {/* Version */}
                <FormField
                  control={form.control}
                  name="version"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Version *</FormLabel>
                      <FormControl>
                        <Input placeholder="1.0.0" {...field} />
                      </FormControl>
                      <FormDescription>Format: X.Y.Z</FormDescription>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                {/* Statut */}
                <FormField
                  control={form.control}
                  name="status"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Statut *</FormLabel>
                      <Select onValueChange={field.onChange} defaultValue={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          <SelectItem value="active">Actif</SelectItem>
                          <SelectItem value="development">En développement</SelectItem>
                          <SelectItem value="deprecated">Deprecated</SelectItem>
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                {/* Auteur */}
                <FormField
                  control={form.control}
                  name="author"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Auteur *</FormLabel>
                      <FormControl>
                        <Input placeholder="DevOps Team" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>

              {/* Tags */}
              <FormField
                control={form.control}
                name="tags"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Tags</FormLabel>
                    <FormControl>
                      <Input placeholder="usb, storage, detection, hardware" {...field} />
                    </FormControl>
                    <FormDescription>
                      Séparés par des virgules (optionnel)
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <div className="flex gap-3 pt-4">
                <Button
                  type="button"
                  variant="outline"
                  className="flex-1"
                  onClick={() => {
                    setNewScriptDialogOpen(false);
                    form.reset();
                  }}
                >
                  Annuler
                </Button>
                <Button type="submit" className="flex-1 gap-2">
                  <Plus className="h-4 w-4" />
                  Créer le script
                </Button>
              </div>
            </form>
          </Form>
        </DialogContent>
      </Dialog>

      {/* Script Detail Dialog */}
      <Dialog open={!!selectedScript} onOpenChange={() => setSelectedScript(null)}>
        <DialogContent className="max-w-3xl">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-3">
              <span>{selectedScript?.name}</span>
              <Badge variant={selectedScript?.type === "atomic" ? "default" : "secondary"}>
                {selectedScript?.type === "atomic" ? "Atomique" : "Orchestrateur"}
              </Badge>
            </DialogTitle>
          </DialogHeader>

          <Tabs defaultValue="general" className="w-full">
            <TabsList className="grid w-full grid-cols-4">
              <TabsTrigger value="general">Général</TabsTrigger>
              <TabsTrigger value="parameters">Paramètres</TabsTrigger>
              <TabsTrigger value="outputs">Sorties</TabsTrigger>
              <TabsTrigger value="dependencies">Dépendances</TabsTrigger>
            </TabsList>

            <TabsContent value="general" className="space-y-4">
              <div className="grid gap-4">
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">Version</p>
                    <p className="text-foreground">{selectedScript?.version}</p>
                  </div>
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">Statut</p>
                    <Badge variant="outline">Actif</Badge>
                  </div>
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">Catégorie</p>
                    <p className="text-foreground">{selectedScript?.category}</p>
                  </div>
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">Exécutions</p>
                    <p className="text-foreground">{selectedScript?.executions}</p>
                  </div>
                </div>

                <div className="rounded-lg bg-muted/50 p-4">
                  <h4 className="mb-2 font-semibold">Description</h4>
                  <p className="text-sm text-muted-foreground">
                    Détecte et liste tous les périphériques USB de stockage connectés au système
                  </p>
                </div>

                <div className="rounded-lg bg-muted/50 p-4">
                  <h4 className="mb-2 font-semibold">Statistiques (30 derniers jours)</h4>
                  <div className="grid grid-cols-3 gap-4">
                    <div>
                      <p className="text-2xl font-bold text-foreground">{selectedScript?.executions}</p>
                      <p className="text-sm text-muted-foreground">Exécutions</p>
                    </div>
                    <div>
                      <p className="text-2xl font-bold text-success">{selectedScript?.success}%</p>
                      <p className="text-sm text-muted-foreground">Taux de succès</p>
                    </div>
                    <div>
                      <p className="text-2xl font-bold text-foreground">234ms</p>
                      <p className="text-sm text-muted-foreground">Durée moyenne</p>
                    </div>
                  </div>
                </div>
              </div>
            </TabsContent>

            <TabsContent value="parameters" className="space-y-4">
              <div className="rounded-lg bg-muted/50 p-4">
                <h4 className="mb-3 font-semibold">Paramètres d'entrée</h4>
                <div className="space-y-3">
                  <div className="flex items-center justify-between rounded-md bg-card p-3">
                    <div>
                      <p className="font-mono text-sm">--filter</p>
                      <p className="text-xs text-muted-foreground">Filtre par fabricant USB</p>
                    </div>
                    <Badge variant="outline">string</Badge>
                  </div>
                  <div className="flex items-center justify-between rounded-md bg-card p-3">
                    <div>
                      <p className="font-mono text-sm">--min-size</p>
                      <p className="text-xs text-muted-foreground">Taille minimale en GB</p>
                    </div>
                    <Badge variant="outline">integer</Badge>
                  </div>
                </div>
              </div>
            </TabsContent>

            <TabsContent value="outputs" className="space-y-4">
              <div className="rounded-lg bg-muted/50 p-4">
                <h4 className="mb-3 font-semibold">Format de sortie JSON</h4>
                <pre className="rounded-md bg-card p-4 text-sm">
{`{
  "status": "success",
  "code": 0,
  "data": {
    "count": 2,
    "devices": [...]
  }
}`}
                </pre>
              </div>
            </TabsContent>

            <TabsContent value="dependencies" className="space-y-4">
              <div className="rounded-lg bg-muted/50 p-4">
                <h4 className="mb-3 font-semibold">Dépendances système</h4>
                <div className="space-y-2">
                  {["lsblk", "udevadm", "awk"].map((dep) => (
                    <div key={dep} className="flex items-center gap-2">
                      <div className="h-2 w-2 rounded-full bg-success" />
                      <span className="font-mono text-sm">{dep}</span>
                    </div>
                  ))}
                </div>
              </div>
            </TabsContent>
          </Tabs>
        </DialogContent>
      </Dialog>
    </div>
  );
}
