# Interface GUI AtomicOps Suite 🎯

Interface web interactive pour visualiser et explorer les 22 scripts atomiques de l'AtomicOps Suite.

## 📋 Fonctionnalités

### 🎨 Interface Multi-Vues
- **Dashboard** : Vue d'ensemble avec cartes de scripts et statistiques
- **Hiérarchie** : Diagramme arborescent des scripts par catégories et niveaux
- **Dépendances** : Graphe interactif des relations entre scripts

### 🔍 Exploration Interactive
- **Recherche** : Recherche textuelle dans noms, descriptions et tags
- **Filtrage** : Par catégorie (USB, iSCSI, System, Network) et niveau (Atomic, Orchestrator, Main)
- **Navigation** : Clic sur les nœuds pour voir les détails complets

### 📊 Visualisations Avancées
- **D3.js** : Diagrammes hiérarchiques fluides avec zoom/pan
- **vis.js** : Graphes de force pour les dépendances
- **Animations CSS** : Interface responsive et moderne

## 🚀 Démarrage Rapide

### 1. Ouvrir l'Interface
```bash
# Depuis le répertoire GUI
cd GUI
# Ouvrir index.html dans un navigateur moderne
# OU utiliser un serveur web local
python3 -m http.server 8000
# Puis accéder à http://localhost:8000
```

### 2. Générer les Données (Optionnel)
```bash
# Exécuter le parser pour analyser automatiquement les scripts
./parse-atomic-scripts.sh -v
# Les données seront générées dans data/parsed-atomic-scripts.json
```

## 📁 Structure des Fichiers

```
GUI/
├── index.html                    # Interface principale
├── css/
│   ├── main.css                 # Styles de base et variables CSS
│   ├── dashboard.css            # Styles du dashboard et cartes
│   └── diagram.css              # Styles des diagrammes et visualisations
├── js/
│   ├── data-manager.js          # Gestionnaire de données avec cache
│   ├── hierarchy-diagram.js     # Diagramme hiérarchique D3.js
│   ├── dependencies-diagram.js  # Diagramme de dépendances
│   └── dashboard.js             # Contrôleur principal de l'interface
├── data/
│   ├── atomic-scripts.json      # Données d'exemple (22 scripts)
│   └── parsed-* (généré)        # Données extraites automatiquement
├── assets/                      # Ressources (icônes, images)
└── parse-atomic-scripts.sh      # Script d'extraction automatique
```

## � Guide d'Utilisation

### Navigation Principale
- **Touches 1, 2, 3** : Basculer entre les vues
- **Ctrl+F** : Focus sur la recherche
- **Escape** : Fermer les modals

### Vue Dashboard
- **Cartes de Scripts** : Cliquer pour sélectionner, voir les détails
- **Arbre des Catégories** : Explorer par organisation hiérarchique
- **Statistiques** : Métriques en temps réel sur les scripts

### Vue Hiérarchique
- **Zoom** : Molette ou boutons de contrôle
- **Pan** : Clic-glisser pour naviguer
- **Nœuds** : Clic pour sélectionner, double-clic pour centrer

### Vue Dépendances
- **Force Layout** : Les nœuds se positionnent selon leurs relations
- **Drag & Drop** : Glisser les nœuds pour explorer
- **Pause/Play** : Contrôler la simulation de forces

## 🔧 Données des Scripts

### Métadonnées Extraites
- **Identification** : ID, nom, description, chemin
- **Classification** : Catégorie, niveau, complexité, statut
- **Fonctionnalités** : Inputs, outputs, conditions, fonctions
- **Relations** : Dépendances, scripts dépendants
- **Qualité** : Tags, version, auteur, dernière modification

### 22 Scripts Inclus

#### Scripts Atomiques (12)
- `select-disk` : Sélection interactive de disque USB
- `format-disk` : Formatage sécurisé avec validation
- `mount-disk` : Montage avec gestion des permissions
- `detect-usb` : Détection et listing des périphériques
- `setup-iscsi-target` : Configuration cible iSCSI
- `configure-iscsi-network` : Paramétrage réseau iSCSI
- `test-iscsi-connection` : Tests de connectivité
- `validate-storage-integrity` : Validation d'intégrité
- `monitor-system-resources` : Surveillance système
- `backup-configuration` : Sauvegarde de config
- `generate-logs` : Génération de logs structurés

#### Scripts Orchestrateurs (3)
- `setup-usb-storage` : Configuration USB complète
- `deploy-iscsi-solution` : Déploiement iSCSI complet
- `monitor-storage-health` : Surveillance continue

#### Scripts Principaux (7)
- `usb-to-iscsi-bridge` : Solution complète USB→iSCSI
- `disaster-recovery-manager` : Gestion de récupération
- `performance-optimizer` : Optimisation performances
- `security-audit-manager` : Audit de sécurité
- `automated-deployment-pipeline` : Pipeline CI/CD

## � Compatibilité

### Navigateurs Supportés
- **Chrome/Edge** : 90+ (recommandé)
- **Firefox** : 88+
- **Safari** : 14+

### Dépendances CDN
- **D3.js v7** : Visualisations hiérarchiques
- **Font Awesome 5** : Icônes
- **Google Fonts Inter** : Typographie

---

*Interface développée pour l'AtomicOps Suite - Gestion modulaire du stockage USB vers iSCSI* 🚀

### Contrôles de Vue (Onglet Hiérarchie)
- **Vue Arbre** : Structure hiérarchique traditionnelle
- **Vue Réseau** : Graphique de force avec dépendances
- **Vue Circulaire** : Diagramme concentrique par catégories

### Système de Filtrage
- **Recherche textuelle** : Nom de script ou description
- **Filtres catégories** : Sélection multiple par domaine
- **Filtre complexité** : Faible, Moyenne, Élevée
- **Reset rapide** : Bouton pour effacer tous les filtres

### Interactions Avancées
- **Clic sur nœud** : Sélection et affichage des détails
- **Zoom/Pan** : Navigation dans les visualisations complexes
- **Drag & Drop** : Repositionnement des nœuds (vue réseau)
- **Tooltips** : Informations contextuelles au survol

## ⌨️ Raccourcis Clavier

| Raccourci | Action |
|-----------|--------|
| `Ctrl + F` | Focus sur la recherche |
| `Ctrl + R` | Actualiser les données |
| `Ctrl + 1/2/3` | Basculer entre les onglets |
| `Escape` | Reset des filtres |
| `F11` | Mode plein écran |

## 🔧 Configuration et Personnalisation

### Thèmes
Le système détecte automatiquement les préférences du navigateur :
- **Thème clair** : Arrière-plan blanc, contrastes élevés
- **Thème sombre** : Arrière-plan foncé, couleurs adaptées

### Variables CSS Personnalisables
```css
:root {
    --primary-color: #3b82f6;    /* Couleur principale */
    --success-color: #10b981;    /* Couleur de succès */
    --error-color: #ef4444;      /* Couleur d'erreur */
    --warning-color: #f59e0b;    /* Couleur d'avertissement */
}
```

### Adaptation des Données
Pour ajouter de nouveaux scripts, modifier `js/data-parser.js` :
```javascript
this.scripts.set('nouveau-script.sh', {
    name: 'nouveau-script.sh',
    category: 'nouvelle-categorie',
    description: 'Description du nouveau script',
    complexity: 5,
    inputs: [...],
    outputs: [...],
    dependencies: [...]
});
```

## 🐛 Dépannage

### Problèmes Courants

**Visualisations vides**
- Vérifier que les scripts sont correctement définis dans `data-parser.js`
- Contrôler la console du navigateur pour les erreurs JavaScript

**Erreurs de chargement des librairies**
- Vérifier la connexion internet (CDN externes)
- Alternative : télécharger les librairies en local

**Performance lente**
- Réduire le nombre de scripts affichés avec les filtres
- Utiliser un navigateur récent avec support WebGL

### Console de Débogage
```javascript
// Accéder aux données depuis la console
window.atomicOpsApp.dataParser.getAllScripts()

// Forcer l'actualisation
window.atomicOpsApp.refreshAllData()

// État des filtres actuels
window.atomicOpsApp.filters
```

## 📈 Métriques et Analytics

### Tableaux de Bord Disponibles
- **Distribution par catégories** : Répartition des scripts
- **Analyse des complexités** : Niveaux de difficulté
- **Types de dépendances** : Outils système requis
- **Métriques des paramètres** : Analyse entrées/sorties

### Insights Automatiques
- Détection des scripts haute complexité
- Identification des catégories dominantes
- Analyse de l'autonomie (scripts sans dépendances)
- Recommandations d'équilibrage

## 🔄 Export et Sauvegarde

### Formats d'Export
- **JSON complet** : Toutes les données avec métadonnées
- **Date de génération** : Horodatage de l'export
- **Version** : Numéro de version des données

### Utilisation de l'Export
```bash
# Le fichier exporté peut être utilisé pour :
# - Sauvegarde des analyses
# - Import dans d'autres outils
# - Documentation automatique
# - Intégration CI/CD
```

## 🤝 Contribution

### Structure de Développement
- **Modulaire** : Chaque composant dans son fichier dédié
- **Événementiel** : Communication via événements personnalisés
- **Responsive** : Design mobile-first
- **Accessible** : Support des lecteurs d'écran

### Ajout de Fonctionnalités
1. Créer le composant dans `/js/`
2. Ajouter les styles dans `/css/main.css`
3. Intégrer dans `main.js`
4. Tester sur différents navigateurs
5. Mettre à jour cette documentation

## 📞 Support

Pour les questions techniques ou suggestions :
- Consulter les logs du navigateur (F12 → Console)
- Vérifier la compatibilité des navigateurs
- Tester avec les filtres désactivés
- Réinitialiser les données via le bouton Refresh

---

**AtomicOps-Suite GUI v1.0.0** - Interface de visualisation pour scripts atomiques  
Développé pour le projet de gestion de disques USB/iSCSI Proxmox