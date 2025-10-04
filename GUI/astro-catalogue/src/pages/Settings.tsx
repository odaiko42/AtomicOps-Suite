import { useState } from "react";
import { User, Mail, Shield, Bell, Save, Upload, Camera } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Switch } from "@/components/ui/switch";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
import { toast } from "sonner";

export default function Settings() {
  const [profileImage, setProfileImage] = useState<string>("/placeholder.svg");
  const [userData, setUserData] = useState({
    firstName: "Jean",
    lastName: "Dupont",
    email: "jean.dupont@example.com",
    role: "DevOps Team",
    phone: "+33 6 12 34 56 78",
  });

  const [notifications, setNotifications] = useState({
    emailNotifications: true,
    scriptExecutions: true,
    errorAlerts: true,
    weeklyReport: false,
  });

  const handleImageUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setProfileImage(reader.result as string);
        toast.success("Photo de profil mise à jour");
      };
      reader.readAsDataURL(file);
    }
  };

  const handleSaveProfile = () => {
    toast.success("Profil mis à jour avec succès");
  };

  const handleSaveNotifications = () => {
    toast.success("Paramètres de notification enregistrés");
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight text-foreground">Paramètres</h2>
        <p className="text-muted-foreground">Gérez votre profil et vos préférences</p>
      </div>

      <Tabs defaultValue="profile" className="space-y-6">
        <TabsList className="grid w-full grid-cols-3 lg:w-[400px]">
          <TabsTrigger value="profile">Profil</TabsTrigger>
          <TabsTrigger value="notifications">Notifications</TabsTrigger>
          <TabsTrigger value="security">Sécurité</TabsTrigger>
        </TabsList>

        {/* Profile Tab */}
        <TabsContent value="profile" className="space-y-6">
          {/* Profile Picture */}
          <Card className="p-6">
            <div className="space-y-4">
              <div className="flex items-center gap-6">
                <div className="relative">
                  <Avatar className="h-24 w-24">
                    <AvatarImage src={profileImage} alt="Photo de profil" />
                    <AvatarFallback className="bg-primary text-2xl text-primary-foreground">
                      {userData.firstName[0]}
                      {userData.lastName[0]}
                    </AvatarFallback>
                  </Avatar>
                  <label
                    htmlFor="avatar-upload"
                    className="absolute bottom-0 right-0 flex h-8 w-8 cursor-pointer items-center justify-center rounded-full bg-primary text-primary-foreground hover:bg-primary/90"
                  >
                    <Camera className="h-4 w-4" />
                    <input
                      id="avatar-upload"
                      type="file"
                      accept="image/*"
                      className="hidden"
                      onChange={handleImageUpload}
                    />
                  </label>
                </div>
                <div>
                  <h3 className="text-xl font-semibold text-foreground">
                    {userData.firstName} {userData.lastName}
                  </h3>
                  <p className="text-sm text-muted-foreground">{userData.role}</p>
                  <Button variant="outline" size="sm" className="mt-2 gap-2" asChild>
                    <label htmlFor="avatar-upload" className="cursor-pointer">
                      <Upload className="h-4 w-4" />
                      Changer la photo
                    </label>
                  </Button>
                </div>
              </div>
            </div>
          </Card>

          {/* Personal Information */}
          <Card className="p-6">
            <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold text-foreground">
              <User className="h-5 w-5" />
              Informations personnelles
            </h3>
            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="firstName">Prénom</Label>
                <Input
                  id="firstName"
                  value={userData.firstName}
                  onChange={(e) =>
                    setUserData({ ...userData, firstName: e.target.value })
                  }
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="lastName">Nom</Label>
                <Input
                  id="lastName"
                  value={userData.lastName}
                  onChange={(e) =>
                    setUserData({ ...userData, lastName: e.target.value })
                  }
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  value={userData.email}
                  onChange={(e) =>
                    setUserData({ ...userData, email: e.target.value })
                  }
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="phone">Téléphone</Label>
                <Input
                  id="phone"
                  type="tel"
                  value={userData.phone}
                  onChange={(e) =>
                    setUserData({ ...userData, phone: e.target.value })
                  }
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="role">Équipe / Rôle</Label>
                <Input
                  id="role"
                  value={userData.role}
                  onChange={(e) =>
                    setUserData({ ...userData, role: e.target.value })
                  }
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="language">Langue</Label>
                <Select defaultValue="fr">
                  <SelectTrigger id="language">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="fr">Français</SelectItem>
                    <SelectItem value="en">English</SelectItem>
                    <SelectItem value="es">Español</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
            <Separator className="my-6" />
            <div className="flex justify-end">
              <Button onClick={handleSaveProfile} className="gap-2">
                <Save className="h-4 w-4" />
                Enregistrer les modifications
              </Button>
            </div>
          </Card>
        </TabsContent>

        {/* Notifications Tab */}
        <TabsContent value="notifications" className="space-y-6">
          <Card className="p-6">
            <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold text-foreground">
              <Bell className="h-5 w-5" />
              Préférences de notification
            </h3>
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label htmlFor="email-notif">Notifications par email</Label>
                  <p className="text-sm text-muted-foreground">
                    Recevoir les notifications importantes par email
                  </p>
                </div>
                <Switch
                  id="email-notif"
                  checked={notifications.emailNotifications}
                  onCheckedChange={(checked) =>
                    setNotifications({ ...notifications, emailNotifications: checked })
                  }
                />
              </div>

              <Separator />

              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label htmlFor="script-exec">Exécutions de scripts</Label>
                  <p className="text-sm text-muted-foreground">
                    Être notifié à chaque exécution de script
                  </p>
                </div>
                <Switch
                  id="script-exec"
                  checked={notifications.scriptExecutions}
                  onCheckedChange={(checked) =>
                    setNotifications({ ...notifications, scriptExecutions: checked })
                  }
                />
              </div>

              <Separator />

              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label htmlFor="error-alerts">Alertes d'erreur</Label>
                  <p className="text-sm text-muted-foreground">
                    Recevoir des alertes en cas d'erreur critique
                  </p>
                </div>
                <Switch
                  id="error-alerts"
                  checked={notifications.errorAlerts}
                  onCheckedChange={(checked) =>
                    setNotifications({ ...notifications, errorAlerts: checked })
                  }
                />
              </div>

              <Separator />

              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label htmlFor="weekly-report">Rapport hebdomadaire</Label>
                  <p className="text-sm text-muted-foreground">
                    Recevoir un résumé hebdomadaire des activités
                  </p>
                </div>
                <Switch
                  id="weekly-report"
                  checked={notifications.weeklyReport}
                  onCheckedChange={(checked) =>
                    setNotifications({ ...notifications, weeklyReport: checked })
                  }
                />
              </div>
            </div>
            <Separator className="my-6" />
            <div className="flex justify-end">
              <Button onClick={handleSaveNotifications} className="gap-2">
                <Save className="h-4 w-4" />
                Enregistrer
              </Button>
            </div>
          </Card>
        </TabsContent>

        {/* Security Tab */}
        <TabsContent value="security" className="space-y-6">
          <Card className="p-6">
            <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold text-foreground">
              <Shield className="h-5 w-5" />
              Sécurité et confidentialité
            </h3>
            <div className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="current-password">Mot de passe actuel</Label>
                <Input id="current-password" type="password" />
              </div>
              <div className="space-y-2">
                <Label htmlFor="new-password">Nouveau mot de passe</Label>
                <Input id="new-password" type="password" />
              </div>
              <div className="space-y-2">
                <Label htmlFor="confirm-password">Confirmer le mot de passe</Label>
                <Input id="confirm-password" type="password" />
              </div>
              <Button variant="outline">Changer le mot de passe</Button>
            </div>

            <Separator className="my-6" />

            <div className="space-y-4">
              <h4 className="font-medium text-foreground">Sessions actives</h4>
              <div className="rounded-lg border border-border bg-muted/50 p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="font-medium text-foreground">Appareil actuel</p>
                    <p className="text-sm text-muted-foreground">Chrome • Paris, France</p>
                  </div>
                  <Button variant="outline" size="sm">
                    Déconnecter
                  </Button>
                </div>
              </div>
            </div>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
