restore-directory.sh
restore-file.sh
revoke-user.sudo.sh
rotate-log.sh
run-smart.test.sh
schedule-task.at.sh
search-log.pattern.sh
search-package.apt.sh
send-notification.email.sh
send-notification.slack.sh
send-notification.telegram.sh
set-config.kernel.parameter.sh
set-cpu.governor.sh
set-dns.server.sh
set-env.variable.sh
set-file.acl.sh
set-file.owner.sh
set-file.permissions.sh
set-network.interface.ip.sh
set-password.expiry.sh
set-system.hostname.sh
set-system.timezone.sh
snapshot-kvm.vm.sh
start-compose.stack.sh
start-docker.container.sh
start-kvm.vm.sh
start-lxc.container.sh
start-service.sh
stop-compose.stack.sh
stop-docker.container.sh
stop-kvm.vm.sh
stop-lxc.container.sh
stop-service.sh
sync-directory.bidirectional.sh
sync-directory.rsync.sh
test-network.ping.sh
test-network.port.sh
test-network.speed.sh
unlock-user.sh
unmount-disk.partition.sh
update-package.all.yum.sh
update-package.list.apt.sh
upgrade-package.all.apt.sh
vacuum-postgresql.database.sh
```

### F. Matrice de Compatibilité Distributions

| Script | Debian/Ubuntu | RHEL/CentOS | Arch | Alpine | Notes |
|--------|---------------|-------------|------|--------|-------|
| **Packages APT** | ✅ | ❌ | ❌ | ❌ | Debian/Ubuntu uniquement |
| **Packages YUM/DNF** | ❌ | ✅ | ❌ | ❌ | RHEL/CentOS uniquement |
| **systemd** | ✅ | ✅ | ✅ | ⚠️ | Alpine peut utiliser OpenRC |
| **Network (ip)** | ✅ | ✅ | ✅ | ✅ | Universel |
| **LVM** | ✅ | ✅ | ✅ | ✅ | Si lvm2 installé |
| **Docker** | ✅ | ✅ | ✅ | ✅ | Si Docker installé |
| **Firewall (iptables)** | ✅ | ✅ | ✅ | ✅ | Universel |
| **Firewall (firewalld)** | ⚠️ | ✅ | ⚠️ | ❌ | Principalement RHEL |

**Légende** :
- ✅ Compatible nativement
- ⚠️ Compatible avec adaptation
- ❌ Incompatible

### G. Guide de Priorité d'Implémentation

**Pour démarrer un nouveau projet, implémenter dans cet ordre** :

#### Phase 1 : Scripts de Base (Semaine 1)
1. ✅ `get-system.info.sh`
2. ✅ `list-user.all.sh`
3. ✅ `list-service.all.sh`
4. ✅ `get-disk.usage.sh`
5. ✅ `get-memory.usage.sh`
6. ✅ `list-network.interfaces.sh`

#### Phase 2 : Gestion Fichiers (Semaine 2)
1. ✅ `create-file.sh`
2. ✅ `delete-file.sh`
3. ✅ `copy-file.sh`
4. ✅ `create-directory.sh`
5. ✅ `get-file.permissions.sh`
6. ✅ `set-file.permissions.sh`

#### Phase 3 : Réseau et Connectivité (Semaine 3)
1. ✅ `check-network.connectivity.sh`
2. ✅ `test-network.ping.sh`
3. ✅ `get-network.interface.ip.sh`
4. ✅ `list-network.connections.sh`
5. ✅ `test-network.port.sh`

#### Phase 4 : Stockage (Semaine 4)
1. ✅ `list-disk.partitions.sh`
2. ✅ `detect-disk.all.sh`
3. ✅ `format-disk.ext4.sh`
4. `mount-disk.partition.sh`
5. `unmount-disk.partition.sh`

#### Phase 5 : Services et Processus (Semaine 5)
1. ✅ `start-service.sh`
2. ✅ `stop-service.sh`
3. ✅ `restart-service.sh`
4. ✅ `get-service.status.sh`
5. ✅ `enable-service.sh`
6. ✅ `monitor-processes.sh`

#### Phase 6 : Sécurité (Semaine 6)
1. `list-firewall.rules.sh`
2. `allow-firewall.port.sh`
3. `check-failed.logins.sh`
4. `list-user.sudo.sh`
5. `generate-ssh.keypair.sh`

#### Phase 7 : Backup et Monitoring (Semaine 7-8)
1. `backup-file.sh`
2. `backup-directory.sh`
3. `get-log.system.sh`
4. `get-cpu.usage.sh`
5. `check-smart.health.sh`

### H. Templates de Documentation par Catégorie

**Template pour script de détection** :

```markdown
# detect-xxx.sh

## Description
Détecte et liste [ressource] sur le système.

## Dépendances
- Système : `commande1`, `commande2`
- Permissions : root / user

## Usage
```bash
./detect-xxx.sh [OPTIONS]
```

## Sortie JSON
```json
{
  "data": {
    "count": N,
    "items": [
      {"id": "...", "name": "...", "property": "..."}
    ]
  }
}
```

## Cas d'usage
- Inventaire système
- Diagnostic matériel
- Monitoring
```

**Template pour script de gestion** :

```markdown
# create-xxx.sh / delete-xxx.sh / modify-xxx.sh

## Description
[Action] sur [ressource].

## Dépendances
- Système : `commande1`
- Permissions : root

## Usage
```bash
./action-xxx.sh [OPTIONS] <paramètres>
```

## Paramètres
- `param1` : Description (obligatoire)
- `param2` : Description (optionnel, défaut: value)

## Sortie JSON
```json
{
  "data": {
    "created": true,
    "id": "...",
    "details": {...}
  }
}
```

## Cas d'usage
- Provisioning
- Automatisation
- Configuration initiale
```

### I. Scripts à NE PAS Créer (Anti-patterns)

**❌ Scripts trop génériques** :
- `manage-everything.sh` → Trop vague
- `do-stuff.sh` → Pas d'action claire
- `system-admin.sh` → Trop large

**❌ Scripts qui font plusieurs choses** :
- `backup-and-restore.sh` → Diviser en 2
- `install-and-configure.sh` → Diviser en 2
- `start-stop-service.sh` → Diviser en 2

**❌ Scripts dupliquant des commandes** :
- `list-files.sh` → Utiliser `ls` directement
- `echo-text.sh` → Utiliser `echo` directement
- `cat-file.sh` → Utiliser `cat` directement

**❌ Scripts non-atomiques** :
- Un script qui dépend d'un état créé par un autre script du projet
- Un script qui modifie plusieurs types de ressources
- Un script avec trop de branches if/else (> 10)

### J. Maintenance et Évolution du Catalogue

**Ajouter un nouveau script au catalogue** :

1. ✅ Vérifier qu'il n'existe pas déjà
2. ✅ S'assurer qu'il est atomique (une seule action)
3. ✅ Le classer dans la bonne catégorie
4. ✅ Respecter la convention de nommage
5. ✅ Documenter complètement
6. ✅ Ajouter à l'index alphabétique
7. ✅ Mettre à jour ce catalogue

**Supprimer un script obsolète** :

1. ✅ Vérifier qu'aucun orchestrateur ne l'utilise
2. ✅ Marquer comme deprecated pendant 1 mois
3. ✅ Communiquer la suppression
4. ✅ Supprimer le fichier
5. ✅ Mettre à jour ce catalogue

**Modifier un script existant** :

1. ✅ Vérifier la compatibilité ascendante
2. ✅ Mettre à jour la documentation
3. ✅ Mettre à jour les tests
4. ✅ Incrémenter la version
5. ✅ Mettre à jour le changelog

---

## Conclusion

Ce catalogue contient **250+ scripts atomiques** couvrant tous les aspects de l'administration système Linux.

### Statistiques

**Par catégorie** :
- Système et Information : 15 scripts
- Disques et Stockage : 35 scripts
- Réseau : 30 scripts
- Utilisateurs et Groupes : 20 scripts
- Processus et Services : 18 scripts
- Fichiers et Répertoires : 25 scripts
- Sauvegarde et Restauration : 12 scripts
- Sécurité et Permissions : 22 scripts
- Packages et Logiciels : 20 scripts
- Logs et Monitoring : 18 scripts
- Périphériques Matériels : 15 scripts
- Bases de Données : 15 scripts
- Conteneurs et Virtualisation : 25 scripts
- Performance et Ressources : 20 scripts
- Automatisation et Planification : 12 scripts
- Utilitaires Divers : 15 scripts

**Total : ~270 scripts atomiques**

### Principe de Composition

Avec ces 270 scripts atomiques, vous pouvez créer des **milliers d'orchestrateurs** différents.

**Exemple de compositions possibles** :
- 270 atomiques → ~100 orchestrateurs niveau 1
- 100 orchestrateurs N1 → ~30 orchestrateurs niveau 2
- 30 orchestrateurs N2 → ~10 orchestrateurs niveau 3
- Et ainsi de suite...

### Croissance Organique

Ce catalogue est **vivant** et doit **évoluer** avec vos besoins :

1. **Commencez petit** : Implémentez 10-20 scripts les plus utiles
2. **Ajoutez au besoin** : Créez un script atomique quand nécessaire
3. **Maintenez la qualité** : Chaque script respecte la méthodologie
4. **Documentez tout** : Le catalogue reste à jour

### Prochaines Étapes

1. ✅ Choisir 10-20 scripts prioritaires pour votre contexte
2. ✅ Implémenter ces scripts en suivant la méthodologie
3. ✅ Créer vos premiers orchestrateurs
4. ✅ Étendre progressivement le catalogue
5. ✅ Contribuer de nouveaux scripts si pertinent

---

**Version du catalogue** : 1.0  
**Date de création** : 2025-10-03  
**Dernière mise à jour** : 2025-10-03  
**Compatibilité** : Méthodologie v2.0

**Ce catalogue est une base de référence. Adaptez-le à vos besoins spécifiques !**

---

## Ressources Complémentaires

### Documents de Référence

1. **Méthodologie de Développement Modulaire et Hiérarchique** : Architecture, standards, templates
2. **Méthodologie - Partie 2** : Bibliothèques de fonctions avancées
3. **Guide de Démarrage** : Comment utiliser les documents
4. **Méthodologie Précise** : Processus étape par étape

### Liens Utiles

- **Linux Documentation Project** : https://tldp.org/
- **Bash Guide** : https://mywiki.wooledge.org/BashGuide
- **ShellCheck** : https://www.shellcheck.net/
- **Man Pages** : https://linux.die.net/man/

### Support Communautaire

Pour questions, suggestions ou contributions sur ce catalogue :
- Ouvrir une issue sur le repository du projet
- Consulter les documents de méthodologie
- Contacter l'équipe DevOps

**Bonne implémentation ! 🚀**#### `list-mongodb.collections.sh`
**Description** : Liste les collections d'une base MongoDB  
**Entrée** : Nom BDD  
**Sortie** : Collections avec nombre de documents  
**Dépendances** : `mongo`  
**Use case** : Analyse structure MongoDB

### 12.4 Redis

#### `check-redis.status.sh`
**Description** : Vérifie l'état du serveur Redis  
**Sortie** : Running/stopped, version, mémoire  
**Dépendances** : `redis-cli ping`, `redis-cli info`  
**Use case** : Monitoring Redis

#### `get-redis.keys.sh`
**Description** : Liste les clés Redis par pattern  
**Entrée** : Pattern (*, user:*, etc.)  
**Sortie** : Liste des clés correspondantes  
**Dépendances** : `redis-cli keys`  
**Use case** : Analyse données Redis

#### `get-redis.memory.sh`
**Description** : Récupère l'utilisation mémoire Redis  
**Sortie** : Mémoire utilisée, peak, fragmentation  
**Dépendances** : `redis-cli info memory`  
**Use case** : Monitoring Redis

---

## 13. Conteneurs et Virtualisation

### 13.1 Docker

#### `list-docker.containers.sh`
**Description** : Liste tous les conteneurs Docker  
**Sortie** : ID, nom, image, état, ports  
**Dépendances** : `docker ps -a`  
**Use case** : Inventaire conteneurs

#### `list-docker.images.sh`
**Description** : Liste toutes les images Docker  
**Sortie** : Repository, tag, ID, taille  
**Dépendances** : `docker images`  
**Use case** : Inventaire images

#### `get-docker.container.info.sh`
**Description** : Récupère les infos d'un conteneur  
**Entrée** : Container ID ou nom  
**Sortie** : Config complète du conteneur  
**Dépendances** : `docker inspect`  
**Use case** : Diagnostic conteneur

#### `get-docker.container.logs.sh`
**Description** : Récupère les logs d'un conteneur  
**Entrée** : Container ID, nombre lignes  
**Sortie** : Logs du conteneur  
**Dépendances** : `docker logs`  
**Use case** : Diagnostic application

#### `start-docker.container.sh`
**Description** : Démarre un conteneur Docker  
**Entrée** : Container ID ou nom  
**Dépendances** : `docker start`  
**Use case** : Gestion conteneurs

#### `stop-docker.container.sh`
**Description** : Arrête un conteneur Docker  
**Entrée** : Container ID ou nom  
**Dépendances** : `docker stop`  
**Use case** : Gestion conteneurs

#### `remove-docker.container.sh`
**Description** : Supprime un conteneur Docker  
**Entrée** : Container ID, force (optionnel)  
**Dépendances** : `docker rm`  
**Use case** : Nettoyage conteneurs

#### `remove-docker.image.sh`
**Description** : Supprime une image Docker  
**Entrée** : Image ID ou nom  
**Dépendances** : `docker rmi`  
**Use case** : Nettoyage images

#### `prune-docker.system.sh`
**Description** : Nettoie les ressources Docker inutilisées  
**Sortie** : Espace récupéré  
**Dépendances** : `docker system prune`  
**Use case** : Maintenance Docker

#### `get-docker.stats.sh`
**Description** : Récupère les statistiques des conteneurs  
**Sortie** : CPU, mémoire, I/O, réseau par conteneur  
**Dépendances** : `docker stats --no-stream`  
**Use case** : Monitoring ressources

### 13.2 Docker Compose

#### `list-compose.services.sh`
**Description** : Liste les services Docker Compose  
**Entrée** : Chemin docker-compose.yml  
**Sortie** : Services avec état  
**Dépendances** : `docker-compose ps`  
**Use case** : Gestion stack

#### `start-compose.stack.sh`
**Description** : Démarre une stack Docker Compose  
**Entrée** : Chemin docker-compose.yml  
**Dépendances** : `docker-compose up -d`  
**Use case** : Déploiement stack

#### `stop-compose.stack.sh`
**Description** : Arrête une stack Docker Compose  
**Entrée** : Chemin docker-compose.yml  
**Dépendances** : `docker-compose down`  
**Use case** : Arrêt stack

### 13.3 Podman

#### `list-podman.containers.sh`
**Description** : Liste tous les conteneurs Podman  
**Sortie** : ID, nom, image, état  
**Dépendances** : `podman ps -a`  
**Use case** : Inventaire Podman

#### `list-podman.pods.sh`
**Description** : Liste tous les pods Podman  
**Sortie** : ID pod, nom, nombre conteneurs, état  
**Dépendances** : `podman pod ps`  
**Use case** : Gestion pods

### 13.4 LXC/LXD

#### `list-lxc.containers.sh`
**Description** : Liste tous les conteneurs LXC  
**Sortie** : Nom, état, IP  
**Dépendances** : `lxc-ls`, `lxc list`  
**Use case** : Inventaire LXC

#### `start-lxc.container.sh`
**Description** : Démarre un conteneur LXC  
**Entrée** : Nom conteneur  
**Dépendances** : `lxc-start`, `lxc start`  
**Use case** : Gestion LXC

#### `stop-lxc.container.sh`
**Description** : Arrête un conteneur LXC  
**Entrée** : Nom conteneur  
**Dépendances** : `lxc-stop`, `lxc stop`  
**Use case** : Gestion LXC

### 13.5 KVM/QEMU

#### `list-kvm.vms.sh`
**Description** : Liste toutes les VMs KVM  
**Sortie** : Nom, état, ID  
**Dépendances** : `virsh list --all`  
**Use case** : Inventaire VMs

#### `get-kvm.vm.info.sh`
**Description** : Récupère les infos d'une VM KVM  
**Entrée** : Nom VM  
**Sortie** : Config complète (CPU, RAM, disques)  
**Dépendances** : `virsh dominfo`  
**Use case** : Analyse VM

#### `start-kvm.vm.sh`
**Description** : Démarre une VM KVM  
**Entrée** : Nom VM  
**Dépendances** : `virsh start`  
**Use case** : Gestion VMs

#### `stop-kvm.vm.sh`
**Description** : Arrête une VM KVM  
**Entrée** : Nom VM, force (optionnel)  
**Dépendances** : `virsh shutdown`, `virsh destroy`  
**Use case** : Gestion VMs

#### `snapshot-kvm.vm.sh`
**Description** : Crée un snapshot d'une VM KVM  
**Entrée** : Nom VM, nom snapshot  
**Dépendances** : `virsh snapshot-create-as`  
**Use case** : Backup VM

---

## 14. Performance et Ressources

### 14.1 CPU

#### `get-cpu.info.sh`
**Description** : Récupère les informations CPU détaillées  
**Sortie** : Modèle, cœurs, threads, cache, flags  
**Dépendances** : `lscpu`, `/proc/cpuinfo`  
**Use case** : Inventaire, analyse

#### `get-cpu.temperature.sh`
**Description** : Récupère la température du CPU  
**Sortie** : Température par cœur  
**Dépendances** : `sensors`, `/sys/class/thermal`  
**Use case** : Monitoring thermique

#### `get-cpu.frequency.sh`
**Description** : Récupère la fréquence CPU actuelle  
**Sortie** : Fréquence par cœur  
**Dépendances** : `cpufreq-info`, `lscpu`  
**Use case** : Analyse performance

#### `set-cpu.governor.sh`
**Description** : Définit le gouverneur CPU  
**Entrée** : Governor (performance, powersave, ondemand)  
**Dépendances** : `cpufreq-set`  
**Use case** : Optimisation énergie/perf

#### `get-cpu.top.processes.sh`
**Description** : Liste les processus consommant le plus de CPU  
**Entrée** : Nombre de processus (défaut: 10)  
**Sortie** : Top processus par CPU  
**Dépendances** : `ps`, `top`  
**Use case** : Diagnostic performance

### 14.2 Mémoire

#### `get-memory.info.sh`
**Description** : Récupère les informations mémoire détaillées  
**Sortie** : Total, type, slots, fréquence  
**Dépendances** : `dmidecode`, `free`  
**Use case** : Inventaire RAM

#### `get-memory.available.sh`
**Description** : Récupère la mémoire disponible  
**Sortie** : Mémoire libre, disponible, cache  
**Dépendances** : `free`, `/proc/meminfo`  
**Use case** : Monitoring RAM

#### `get-memory.top.processes.sh`
**Description** : Liste les processus consommant le plus de RAM  
**Entrée** : Nombre de processus  
**Sortie** : Top processus par mémoire  
**Dépendances** : `ps`  
**Use case** : Diagnostic mémoire

#### `clear-memory.cache.sh`
**Description** : Vide les caches mémoire  
**Sortie** : Mémoire libérée  
**Dépendances** : `sync`, `/proc/sys/vm/drop_caches`  
**Use case** : Libération mémoire

#### `check-memory.oom.sh`
**Description** : Vérifie les événements OOM (Out of Memory)  
**Sortie** : Processus tués par OOM  
**Dépendances** : `dmesg`, logs kernel  
**Use case** : Diagnostic crashes

### 14.3 Swap

#### `get-swap.usage.sh`
**Description** : Récupère l'utilisation du swap  
**Sortie** : Total, utilisé, libre  
**Dépendances** : `free`, `swapon`  
**Use case** : Monitoring swap

#### `create-swap.file.sh`
**Description** : Crée un fichier swap  
**Entrée** : Taille, chemin  
**Dépendances** : `dd`, `mkswap`, `swapon`  
**Use case** : Ajout swap

#### `enable-swap.sh`
**Description** : Active un espace swap  
**Entrée** : Device ou fichier  
**Dépendances** : `swapon`  
**Use case** : Gestion swap

#### `disable-swap.sh`
**Description** : Désactive un espace swap  
**Entrée** : Device ou fichier  
**Dépendances** : `swapoff`  
**Use case** : Maintenance swap

### 14.4 I/O et Disque

#### `get-io.stats.sh`
**Description** : Récupère les statistiques I/O  
**Sortie** : Read/write rates par device  
**Dépendances** : `iostat`  
**Use case** : Monitoring I/O

#### `get-io.top.processes.sh`
**Description** : Liste les processus avec le plus d'I/O  
**Entrée** : Nombre de processus  
**Sortie** : Top processus par I/O  
**Dépendances** : `iotop`  
**Use case** : Diagnostic I/O

#### `check-disk.latency.sh`
**Description** : Vérifie la latence des disques  
**Entrée** : Device  
**Sortie** : Latence read/write en ms  
**Dépendances** : `ioping`, `fio`  
**Use case** : Test performance

#### `benchmark-disk.speed.sh`
**Description** : Benchmark de vitesse disque  
**Entrée** : Device ou point montage  
**Sortie** : Vitesse séquentielle et aléatoire  
**Dépendances** : `dd`, `hdparm`, `fio`  
**Use case** : Test performance

### 14.5 Réseau

#### `get-network.bandwidth.sh`
**Description** : Mesure la bande passante réseau  
**Entrée** : Interface  
**Sortie** : Débit RX/TX actuel  
**Dépendances** : `ifstat`, `iftop`  
**Use case** : Monitoring réseau

#### `test-network.speed.sh`
**Description** : Test de vitesse réseau (speedtest)  
**Sortie** : Download, upload, ping  
**Dépendances** : `speedtest-cli`  
**Use case** : Test connexion

#### `benchmark-network.iperf.sh`
**Description** : Benchmark réseau avec iperf  
**Entrée** : Serveur cible  
**Sortie** : Bande passante, jitter, packet loss  
**Dépendances** : `iperf`, `iperf3`  
**Use case** : Test performance LAN

---

## 15. Automatisation et Planification

### 15.1 Cron

#### `add-cron.job.sh`
**Description** : Ajoute une tâche cron  
**Entrée** : User, schedule, commande  
**Dépendances** : `crontab`  
**Use case** : Automatisation

#### `remove-cron.job.sh`
**Description** : Supprime une tâche cron  
**Entrée** : User, pattern de la commande  
**Dépendances** : `crontab`  
**Use case** : Nettoyage cron

#### `enable-cron.job.sh`
**Description** : Active une tâche cron (décommenter)  
**Entrée** : User, pattern  
**Dépendances** : `crontab`, `sed`  
**Use case** : Gestion planification

#### `disable-cron.job.sh`
**Description** : Désactive une tâche cron (commenter)  
**Entrée** : User, pattern  
**Dépendances** : `crontab`, `sed`  
**Use case** : Pause automatisation

### 15.2 Systemd Timers

#### `list-timer.all.sh`
**Description** : Liste tous les timers systemd  
**Sortie** : Nom, next run, last run, état  
**Dépendances** : `systemctl list-timers`  
**Use case** : Audit timers

#### `create-timer.sh`
**Description** : Crée un timer systemd  
**Entrée** : Nom, schedule, commande  
**Dépendances** : Création fichiers .timer et .service  
**Use case** : Planification moderne

#### `enable-timer.sh`
**Description** : Active un timer systemd  
**Entrée** : Nom timer  
**Dépendances** : `systemctl enable --now`  
**Use case** : Activation timer

#### `disable-timer.sh`
**Description** : Désactive un timer systemd  
**Entrée** : Nom timer  
**Dépendances** : `systemctl disable --now`  
**Use case** : Arrêt timer

### 15.3 At (Tâches ponctuelles)

#### `schedule-task.at.sh`
**Description** : Planifie une tâche ponctuelle avec at  
**Entrée** : Moment (time), commande  
**Dépendances** : `at`  
**Use case** : Tâche unique différée

#### `list-task.at.sh`
**Description** : Liste les tâches at planifiées  
**Sortie** : ID tâche, moment, commande  
**Dépendances** : `atq`  
**Use case** : Audit tâches at

#### `cancel-task.at.sh`
**Description** : Annule une tâche at  
**Entrée** : ID tâche  
**Dépendances** : `atrm`  
**Use case** : Annulation tâche

### 15.4 Systemd Path (Surveillance fichiers)

#### `create-path.watch.sh`
**Description** : Crée une surveillance de fichier/dossier  
**Entrée** : Chemin à surveiller, action  
**Dépendances** : Création .path et .service  
**Use case** : Automatisation événementielle

---

## 16. Scripts Utilitaires Divers

### 16.1 Date et Heure

#### `get-date.current.sh`
**Description** : Récupère la date/heure actuelle  
**Sortie** : Date dans différents formats  
**Dépendances** : `date`  
**Use case** : Horodatage, logs

#### `get-date.timestamp.sh`
**Description** : Récupère le timestamp Unix  
**Sortie** : Secondes depuis epoch  
**Dépendances** : `date +%s`  
**Use case** : Calculs temporels

#### `convert-date.format.sh`
**Description** : Convertit une date vers un autre format  
**Entrée** : Date source, format source, format cible  
**Dépendances** : `date`  
**Use case** : Formatage dates

#### `calculate-date.diff.sh`
**Description** : Calcule la différence entre deux dates  
**Entrée** : Date1, date2  
**Sortie** : Différence en jours, heures, minutes  
**Dépendances** : `date`  
**Use case** : Calculs temporels

### 16.2 Environnement

#### `get-env.variable.sh`
**Description** : Récupère une variable d'environnement  
**Entrée** : Nom variable  
**Sortie** : Valeur de la variable  
**Dépendances** : `printenv`, `echo`  
**Use case** : Configuration

#### `set-env.variable.sh`
**Description** : Définit une variable d'environnement  
**Entrée** : Nom, valeur, scope (session/user/system)  
**Dépendances** : `export`, édition profils  
**Use case** : Configuration

#### `list-env.all.sh`
**Description** : Liste toutes les variables d'environnement  
**Sortie** : Toutes les variables et leurs valeurs  
**Dépendances** : `printenv`, `env`  
**Use case** : Audit environnement

### 16.3 Configuration

#### `get-config.kernel.parameter.sh`
**Description** : Récupère un paramètre kernel (sysctl)  
**Entrée** : Nom paramètre  
**Sortie** : Valeur actuelle  
**Dépendances** : `sysctl`  
**Use case** : Audit kernel

#### `set-config.kernel.parameter.sh`
**Description** : Modifie un paramètre kernel  
**Entrée** : Paramètre, valeur, persistent  
**Dépendances** : `sysctl`, `/etc/sysctl.conf`  
**Use case** : Tuning système

### 16.4 Notifications

#### `send-notification.email.sh`
**Description** : Envoie une notification par email  
**Entrée** : Destinataire, sujet, message  
**Dépendances** : `mail`, `sendmail`  
**Use case** : Alertes email

#### `send-notification.slack.sh`
**Description** : Envoie une notification Slack  
**Entrée** : Webhook URL, message  
**Dépendances** : `curl`  
**Use case** : Alertes Slack

#### `send-notification.telegram.sh`
**Description** : Envoie une notification Telegram  
**Entrée** : Bot token, chat ID, message  
**Dépendances** : `curl`  
**Use case** : Alertes Telegram

---

## Annexes

### A. Conventions de Nommage Rappel

**Format général** : `<verbe>-<objet>[.<sous-objet>].sh`

**Verbes par catégorie** :
- **Détection/Information** : `detect-`, `get-`, `list-`, `check-`
- **Modification** : `set-`, `create-`, `delete-`, `modify-`, `update-`
- **Actions** : `start-`, `stop-`, `restart-`, `enable-`, `disable-`
- **Opérations** : `install-`, `remove-`, `backup-`, `restore-`, `sync-`
- **Analyse** : `analyze-`, `search-`, `find-`, `compare-`
- **Tests** : `test-`, `benchmark-`, `validate-`

### B. Dépendances Communes

**Toujours présentes sur Linux moderne** :
- `bash`, `sh`, `awk`, `sed`, `grep`, `find`, `wc`, `cat`, `echo`

**Souvent présentes** :
- `systemctl`, `journalctl`, `ip`, `ps`, `top`, `free`, `df`, `du`

**À vérifier/installer** :
- `jq` (parsing JSON)
- `lsblk`, `fdisk`, `parted` (gestion disques)
- `smartctl` (SMART)
- `docker`, `docker-compose` (conteneurs)
- `iostat`, `iotop`, `iftop` (monitoring avancé)

### C. Structure JSON Standard Rappel

Tous les scripts atomiques DOIVENT retourner :

```json
{
  "status": "success|error|warning",
  "code": 0,
  "timestamp": "2025-10-03T14:30:45Z",
  "script": "nom-script.sh",
  "message": "Description du résultat",
  "data": {
    // Données spécifiques du script
  },
  "errors": [],
  "warnings": []
}
```

### D. Utilisation dans des Orchestrateurs

**Exemple de composition** :

```bash
# Orchestrateur : setup-monitoring.sh (niveau 1)
# Compose plusieurs atomiques :

# 1. Installer les outils
./install-package.apt.sh prometheus
./install-package.apt.sh grafana

# 2. Configurer les services
./enable-service.sh prometheus
./enable-service.sh grafana

# 3. Configurer le firewall
./allow-firewall.port.sh 9090 tcp
./allow-firewall.port.sh 3000 tcp

# 4. Vérifier le fonctionnement
./check-service.status.sh prometheus
./check-service.status.sh grafana
```

### E. Index Alphabétique

Pour recherche rapide, tous les scripts par ordre alphabétique :

```
add-cron.job.sh
add-network.route.sh
add-ssh.key.authorized.sh
add-user.togroup.sh
allow-firewall.port.sh
analyze-log.errors.sh
backup-database.mysql.sh
backup-database.postgresql.sh
backup-directory.sh
backup-file.sh
backup-system.config.sh
benchmark-disk.speed.sh
benchmark-network.iperf.sh
block-firewall.port.sh
calculate-date.diff.sh
cancel-task.at.sh
check-build.dependencies.sh
check-disk.latency.sh
check-failed.logins.sh
check-firewall.status.sh
check-memory.oom.sh
check-mongodb.status.sh
check-mysql.status.sh
check-network.connectivity.sh
check-package.updates.apt.sh
check-password.strength.sh
check-postgresql.status.sh
check-raid.health.sh
check-redis.status.sh
check-smart.health.sh
check-ssh.connection.sh
check-ssl.certificate.sh
check-ssl.remote.sh
check-suid.files.sh
check-user.exists.sh
check-user.password.expired.sh
check-world.writable.sh
clear-memory.cache.sh
compare-file.checksum.sh
compress-file.bzip2.sh
compress-file.gzip.sh
compress-file.xz.sh
compress-log.old.sh
convert-date.format.sh
copy-file.sh
count-file.lines.sh
create-archive.tar.sh
create-archive.targz.sh
create-archive.zip.sh
create-compose.stack.sh
create-directory.sh
create-disk.partition.sh
create-file.sh
create-group.sh
create-lvm.lv.sh
create-lvm.pv.sh
create-lvm.vg.sh
create-path.watch.sh
create-ssl.selfsigned.sh
create-swap.file.sh
create-timer.sh
create-user.sh
decompress-file.sh
delete-directory.sh
delete-disk.partition.sh
delete-file.sh
delete-group.sh
delete-network.route.sh
delete-user.sh
detect-disk.all.sh
detect-disk.nvme.sh
detect-disk.ssd.sh
detect-hardware.bios.sh
detect-hardware.cpu.sh
detect-hardware.memory.sh
detect-raid.all.sh
detect-usb.all.sh
detect-usb.storage.sh
disable-cron.job.sh
disable-network.interface.sh
disable-service.sh
disable-swap.sh
disable-timer.sh
enable-cron.job.sh
enable-network.interface.sh
enable-service.sh
enable-swap.sh
enable-timer.sh
extend-lvm.lv.sh
extract-archive.tar.sh
extract-archive.zip.sh
find-file.bycontent.sh
find-file.bydate.sh
find-file.byname.sh
find-file.bysize.sh
format-disk.btrfs.sh
format-disk.ext4.sh
format-disk.vfat.sh
format-disk.xfs.sh
generate-password.sh
generate-ssh.keypair.sh
get-block.device.info.sh
get-config.kernel.parameter.sh
get-cpu.frequency.sh
get-cpu.info.sh
get-cpu.temperature.sh
get-cpu.top.processes.sh
get-cpu.usage.sh
get-date.current.sh
get-date.timestamp.sh
get-directory.size.sh
get-disk.io.sh
✅ get-disk.usage.sh
get-dns.servers.sh
get-docker.container.info.sh
get-docker.container.logs.sh
get-docker.stats.sh
get-env.variable.sh
get-file.acl.sh
get-file.checksum.md5.sh
get-file.checksum.sha256.sh
get-file.permissions.sh
get-file.size.sh
get-group.members.sh
get-io.stats.sh
get-io.top.processes.sh
get-journal.boot.sh
get-journal.priority.sh
get-journal.service.sh
get-kvm.vm.info.sh
get-log.auth.sh
get-log.kernel.sh
get-log.system.sh
get-memory.available.sh
get-memory.info.sh
get-memory.top.processes.sh
✅ get-memory.usage.sh
get-mysql.table.size.sh
get-network.bandwidth.sh
get-network.gateway.sh
get-network.interface.ip.sh
get-network.interface.mac.sh
get-network.traffic.sh
get-package.info.apt.sh
get-process.info.sh
get-redis.keys.sh
get-redis.memory.sh
get-service.status.sh
get-smart.attributes.sh
get-ssl.expiry.sh
get-swap.usage.sh
get-system.hostname.sh
✅ get-system.info.sh
get-system.load.sh
get-system.timezone.sh
get-system.uptime.sh
get-usb.device.info.sh
get-user.info.sh
grant-user.sudo.sh
install-package.apt.sh
install-package.flatpak.sh
install-package.snap.sh
install-package.yum.sh
kill-process.sh
killall-process.byname.sh
list-archive.contents.sh
list-block.devices.sh
list-compose.services.sh
list-cron.system.sh
list-cron.user.sh
list-disk.mounted.sh
list-disk.partitions.sh
list-docker.containers.sh
list-docker.images.sh
list-env.all.sh
list-file.byname.sh
list-firewall.rules.sh
list-group.all.sh
list-lvm.all.sh
list-lxc.containers.sh
list-mongodb.collections.sh
list-mongodb.databases.sh
list-mysql.databases.sh
list-mysql.tables.sh
list-network.connections.sh
✅ list-network.interfaces.sh
list-network.listening.sh
list-network.routes.sh
list-package.flatpak.sh
list-package.installed.apt.sh
list-package.installed.yum.sh
list-package.snap.sh
list-pci.devices.sh
list-pci.graphics.sh
list-pci.network.sh
list-podman.containers.sh
list-podman.pods.sh
list-postgresql.databases.sh
list-postgresql.tables.sh
list-process.all.sh
list-process.byuser.sh
list-service.active.sh
✅ list-service.all.sh
list-service.failed.sh
list-ssh.keys.sh
list-sudo.commands.sh
list-task.at.sh
list-timer.all.sh
list-usb.devices.sh
✅ list-user.all.sh
list-user.human.sh
list-user.sudo.sh
lock-user.sh
modify-user.shell.sh
mount-disk.fstab.sh
mount-disk.partition.sh
move-file.sh
optimize-mysql.table.sh
prune-docker.system.sh
remove-cron.job.sh
remove-docker.container.sh
remove-docker.image.sh
remove-package.apt.sh
remove-package.yum.sh
remove-ssh.key.authorized.sh
remove-user.fromgroup.sh
resolve-dns.hostname.sh
resolve-dns.reverse.sh
restart-service.sh
restore-database.mysql.sh
restore-database.postgresql.sh
restore-directory.sh#### `set-file.permissions.sh`
**Description** : Modifie les permissions d'un fichier  
**Entrée** : Chemin, permissions (755, u+x, etc.), récursif  
**Dépendances** : `chmod`  
**Use case** : Sécurisation fichiers

#### `set-file.owner.sh`
**Description** : Modifie le propriétaire d'un fichier  
**Entrée** : Chemin, user, group, récursif  
**Dépendances** : `chown`  
**Use case** : Gestion propriété

#### `set-file.acl.sh`
**Description** : Définit des ACL sur un fichier  
**Entrée** : Chemin, ACL règles  
**Dépendances** : `setfacl`  
**Use case** : Permissions avancées

#### `get-file.acl.sh`
**Description** : Récupère les ACL d'un fichier  
**Entrée** : Chemin fichier  
**Sortie** : ACL définies  
**Dépendances** : `getfacl`  
**Use case** : Audit ACL

### 6.4 Compression et Archives

#### `compress-file.gzip.sh`
**Description** : Compresse un fichier avec gzip  
**Entrée** : Fichier source  
**Sortie** : Fichier .gz  
**Dépendances** : `gzip`  
**Use case** : Économie espace

#### `compress-file.bzip2.sh`
**Description** : Compresse un fichier avec bzip2  
**Entrée** : Fichier source  
**Sortie** : Fichier .bz2  
**Dépendances** : `bzip2`  
**Use case** : Meilleure compression

#### `compress-file.xz.sh`
**Description** : Compresse un fichier avec xz  
**Entrée** : Fichier source  
**Sortie** : Fichier .xz  
**Dépendances** : `xz`  
**Use case** : Compression maximale

#### `decompress-file.sh`
**Description** : Décompresse un fichier (auto-détection format)  
**Entrée** : Fichier compressé  
**Dépendances** : `gunzip`, `bunzip2`, `unxz`  
**Use case** : Extraction fichiers

#### `create-archive.tar.sh`
**Description** : Crée une archive tar  
**Entrée** : Fichiers/dossiers, nom archive  
**Dépendances** : `tar`  
**Use case** : Archivage

#### `create-archive.targz.sh`
**Description** : Crée une archive tar.gz  
**Entrée** : Fichiers/dossiers, nom archive  
**Dépendances** : `tar`, `gzip`  
**Use case** : Archive compressée

#### `extract-archive.tar.sh`
**Description** : Extrait une archive tar  
**Entrée** : Fichier archive, destination  
**Dépendances** : `tar`  
**Use case** : Restauration fichiers

#### `list-archive.contents.sh`
**Description** : Liste le contenu d'une archive  
**Entrée** : Fichier archive  
**Sortie** : Liste des fichiers dans l'archive  
**Dépendances** : `tar`, `unzip`  
**Use case** : Inspection archive

#### `create-archive.zip.sh`
**Description** : Crée une archive ZIP  
**Entrée** : Fichiers/dossiers, nom archive  
**Dépendances** : `zip`  
**Use case** : Compatibilité multi-OS

#### `extract-archive.zip.sh`
**Description** : Extrait une archive ZIP  
**Entrée** : Fichier ZIP, destination  
**Dépendances** : `unzip`  
**Use case** : Extraction ZIP

### 6.5 Analyse et Statistiques

#### `get-file.size.sh`
**Description** : Récupère la taille d'un fichier  
**Entrée** : Chemin fichier  
**Sortie** : Taille (bytes, KB, MB, GB)  
**Dépendances** : `du`, `stat`  
**Use case** : Analyse espace

#### `get-directory.size.sh`
**Description** : Calcule la taille totale d'un répertoire  
**Entrée** : Chemin répertoire  
**Sortie** : Taille totale récursive  
**Dépendances** : `du`  
**Use case** : Analyse espace disque

#### `get-file.checksum.md5.sh`
**Description** : Calcule le checksum MD5 d'un fichier  
**Entrée** : Chemin fichier  
**Sortie** : Hash MD5  
**Dépendances** : `md5sum`  
**Use case** : Vérification intégrité

#### `get-file.checksum.sha256.sh`
**Description** : Calcule le checksum SHA256 d'un fichier  
**Entrée** : Chemin fichier  
**Sortie** : Hash SHA256  
**Dépendances** : `sha256sum`  
**Use case** : Vérification intégrité sécurisée

#### `compare-file.checksum.sh`
**Description** : Compare deux fichiers par checksum  
**Entrée** : Fichier1, fichier2  
**Sortie** : Identiques (true/false)  
**Dépendances** : `md5sum`, `sha256sum`  
**Use case** : Validation copies

#### `count-file.lines.sh`
**Description** : Compte le nombre de lignes d'un fichier  
**Entrée** : Chemin fichier  
**Sortie** : Nombre de lignes  
**Dépendances** : `wc`  
**Use case** : Analyse fichiers texte

---

## 7. Sauvegarde et Restauration

### 7.1 Backup

#### `backup-file.sh`
**Description** : Sauvegarde un fichier avec timestamp  
**Entrée** : Fichier source, destination  
**Sortie** : Fichier de backup horodaté  
**Dépendances** : `cp`  
**Use case** : Backup avant modification

#### `backup-directory.sh`
**Description** : Sauvegarde un répertoire complet  
**Entrée** : Répertoire source, destination  
**Dépendances** : `rsync`, `tar`  
**Use case** : Backup données

#### `backup-system.config.sh`
**Description** : Sauvegarde les fichiers de configuration système  
**Sortie** : Archive des configs (/etc)  
**Dépendances** : `tar`  
**Use case** : Backup configuration

#### `backup-database.mysql.sh`
**Description** : Sauvegarde une base MySQL  
**Entrée** : Nom BDD, credentials  
**Sortie** : Dump SQL  
**Dépendances** : `mysqldump`  
**Use case** : Backup base de données

#### `backup-database.postgresql.sh`
**Description** : Sauvegarde une base PostgreSQL  
**Entrée** : Nom BDD, credentials  
**Sortie** : Dump SQL  
**Dépendances** : `pg_dump`  
**Use case** : Backup PostgreSQL

### 7.2 Restore

#### `restore-file.sh`
**Description** : Restaure un fichier depuis backup  
**Entrée** : Fichier backup, destination  
**Dépendances** : `cp`  
**Use case** : Restauration fichier

#### `restore-directory.sh`
**Description** : Restaure un répertoire depuis backup  
**Entrée** : Archive backup, destination  
**Dépendances** : `tar`, `rsync`  
**Use case** : Restauration complète

#### `restore-database.mysql.sh`
**Description** : Restaure une base MySQL depuis dump  
**Entrée** : Fichier dump, nom BDD, credentials  
**Dépendances** : `mysql`  
**Use case** : Restauration base

#### `restore-database.postgresql.sh`
**Description** : Restaure une base PostgreSQL depuis dump  
**Entrée** : Fichier dump, nom BDD  
**Dépendances** : `psql`  
**Use case** : Restauration PostgreSQL

### 7.3 Synchronisation

#### `sync-directory.rsync.sh`
**Description** : Synchronise deux répertoires avec rsync  
**Entrée** : Source, destination, options  
**Dépendances** : `rsync`  
**Use case** : Sync données, backup incrémental

#### `sync-directory.bidirectional.sh`
**Description** : Synchronisation bidirectionnelle  
**Entrée** : Répertoire1, répertoire2  
**Dépendances** : `rsync`, `unison`  
**Use case** : Sync multi-sites

---

## 8. Sécurité et Permissions

### 8.1 Authentification

#### `check-password.strength.sh`
**Description** : Vérifie la force d'un mot de passe  
**Entrée** : Mot de passe  
**Sortie** : Score force, recommandations  
**Dépendances** : `cracklib-check`, regex  
**Use case** : Politique mots de passe

#### `generate-password.sh`
**Description** : Génère un mot de passe sécurisé  
**Entrée** : Longueur, complexité  
**Sortie** : Mot de passe aléatoire  
**Dépendances** : `pwgen`, `/dev/urandom`  
**Use case** : Création comptes

#### `check-user.password.expired.sh`
**Description** : Vérifie si le mot de passe d'un user est expiré  
**Entrée** : Username  
**Sortie** : Expiré (true/false), jours restants  
**Dépendances** : `chage`  
**Use case** : Audit sécurité

#### `set-password.expiry.sh`
**Description** : Définit l'expiration du mot de passe  
**Entrée** : Username, jours avant expiration  
**Dépendances** : `chage`  
**Use case** : Politique sécurité

### 8.2 SSH

#### `list-ssh.keys.sh`
**Description** : Liste les clés SSH d'un utilisateur  
**Entrée** : Username  
**Sortie** : Clés publiques, privées, authorized_keys  
**Dépendances** : Lecture ~/.ssh/  
**Use case** : Audit SSH

#### `generate-ssh.keypair.sh`
**Description** : Génère une paire de clés SSH  
**Entrée** : Type (rsa/ed25519), longueur, comment  
**Sortie** : Clés publique et privée  
**Dépendances** : `ssh-keygen`  
**Use case** : Configuration SSH

#### `add-ssh.key.authorized.sh`
**Description** : Ajoute une clé publique aux authorized_keys  
**Entrée** : Username, clé publique  
**Dépendances** : Édition authorized_keys  
**Use case** : Autorisation connexion

#### `remove-ssh.key.authorized.sh`
**Description** : Retire une clé des authorized_keys  
**Entrée** : Username, fingerprint ou pattern  
**Dépendances** : Édition authorized_keys  
**Use case** : Révocation accès

#### `check-ssh.connection.sh`
**Description** : Teste la connexion SSH vers un hôte  
**Entrée** : Host, port, user  
**Sortie** : Accessible (true/false), infos connexion  
**Dépendances** : `ssh`, `nc`  
**Use case** : Diagnostic SSH

### 8.3 Certificats SSL/TLS

#### `generate-ssl.selfsigned.sh`
**Description** : Génère un certificat SSL auto-signé  
**Entrée** : CN, durée validité, clé size  
**Sortie** : Certificat et clé privée  
**Dépendances** : `openssl`  
**Use case** : Dev, tests

#### `check-ssl.certificate.sh`
**Description** : Vérifie un certificat SSL  
**Entrée** : Fichier certificat  
**Sortie** : Validité, émetteur, dates, CN  
**Dépendances** : `openssl`  
**Use case** : Audit certificats

#### `check-ssl.remote.sh`
**Description** : Vérifie le certificat SSL d'un site distant  
**Entrée** : Hostname, port  
**Sortie** : Infos certificat, validité  
**Dépendances** : `openssl s_client`  
**Use case** : Monitoring SSL

#### `get-ssl.expiry.sh`
**Description** : Récupère la date d'expiration d'un certificat  
**Entrée** : Fichier certificat ou hostname  
**Sortie** : Date expiration, jours restants  
**Dépendances** : `openssl`  
**Use case** : Alertes expiration

### 8.4 Audit et Logs

#### `check-failed.logins.sh`
**Description** : Liste les tentatives de connexion échouées  
**Sortie** : IPs, users, timestamps  
**Dépendances** : `/var/log/auth.log`, `lastb`  
**Use case** : Détection intrusion

#### `list-sudo.commands.sh`
**Description** : Liste les commandes sudo exécutées  
**Sortie** : User, commande, timestamp  
**Dépendances** : `/var/log/auth.log`, `sudo -l`  
**Use case** : Audit privilèges

#### `check-suid.files.sh`
**Description** : Liste les fichiers avec bit SUID  
**Entrée** : Répertoire de départ (défaut: /)  
**Sortie** : Fichiers SUID dangereux potentiels  
**Dépendances** : `find`  
**Use case** : Audit sécurité

#### `check-world.writable.sh`
**Description** : Liste les fichiers/dossiers world-writable  
**Entrée** : Répertoire de départ  
**Sortie** : Fichiers accessibles en écriture par tous  
**Dépendances** : `find`  
**Use case** : Audit permissions

---

## 9. Packages et Logiciels

### 9.1 Gestion Packages (APT - Debian/Ubuntu)

#### `list-package.installed.apt.sh`
**Description** : Liste tous les packages installés (APT)  
**Sortie** : Nom, version, architecture  
**Dépendances** : `dpkg`, `apt`  
**Use case** : Inventaire logiciel

#### `search-package.apt.sh`
**Description** : Recherche un package dans les dépôts APT  
**Entrée** : Nom ou pattern  
**Sortie** : Packages correspondants  
**Dépendances** : `apt-cache`  
**Use case** : Découverte logiciel

#### `get-package.info.apt.sh`
**Description** : Récupère les infos d'un package APT  
**Entrée** : Nom package  
**Sortie** : Version, description, dépendances, taille  
**Dépendances** : `apt-cache show`, `dpkg`  
**Use case** : Analyse package

#### `install-package.apt.sh`
**Description** : Installe un package avec APT  
**Entrée** : Nom package  
**Dépendances** : `apt-get install`  
**Use case** : Installation logiciel

#### `remove-package.apt.sh`
**Description** : Désinstalle un package APT  
**Entrée** : Nom package, purge (optionnel)  
**Dépendances** : `apt-get remove`  
**Use case** : Nettoyage système

#### `update-package.list.apt.sh`
**Description** : Met à jour la liste des packages APT  
**Dépendances** : `apt-get update`  
**Use case** : Préparation installation

#### `upgrade-package.all.apt.sh`
**Description** : Met à jour tous les packages APT  
**Dépendances** : `apt-get upgrade`  
**Use case** : Maintenance système

#### `check-package.updates.apt.sh`
**Description** : Liste les packages avec mises à jour disponibles  
**Sortie** : Packages, versions actuelles et nouvelles  
**Dépendances** : `apt list --upgradable`  
**Use case** : Planification mises à jour

### 9.2 Gestion Packages (YUM/DNF - RedHat/CentOS)

#### `list-package.installed.yum.sh`
**Description** : Liste tous les packages installés (YUM/DNF)  
**Sortie** : Nom, version, repo  
**Dépendances** : `yum list installed`, `dnf`  
**Use case** : Inventaire RHEL

#### `install-package.yum.sh`
**Description** : Installe un package avec YUM/DNF  
**Entrée** : Nom package  
**Dépendances** : `yum install`, `dnf install`  
**Use case** : Installation RHEL

#### `remove-package.yum.sh`
**Description** : Désinstalle un package YUM/DNF  
**Entrée** : Nom package  
**Dépendances** : `yum remove`, `dnf remove`  
**Use case** : Nettoyage RHEL

#### `update-package.all.yum.sh`
**Description** : Met à jour tous les packages YUM/DNF  
**Dépendances** : `yum update`, `dnf update`  
**Use case** : Maintenance RHEL

### 9.3 Snap et Flatpak

#### `list-package.snap.sh`
**Description** : Liste les packages Snap installés  
**Sortie** : Nom, version, publisher  
**Dépendances** : `snap list`  
**Use case** : Inventaire Snap

#### `install-package.snap.sh`
**Description** : Installe un package Snap  
**Entrée** : Nom package  
**Dépendances** : `snap install`  
**Use case** : Installation Snap

#### `list-package.flatpak.sh`
**Description** : Liste les packages Flatpak installés  
**Sortie** : Nom, version, origine  
**Dépendances** : `flatpak list`  
**Use case** : Inventaire Flatpak

#### `install-package.flatpak.sh`
**Description** : Installe un package Flatpak  
**Entrée** : Nom package, remote  
**Dépendances** : `flatpak install`  
**Use case** : Installation Flatpak

### 9.4 Compilation depuis sources

#### `check-build.dependencies.sh`
**Description** : Vérifie les dépendances de compilation  
**Entrée** : Liste des tools requis  
**Sortie** : Présent/absent pour chaque dépendance  
**Dépendances** : `which`, `command`  
**Use case** : Préparation build

---

## 10. Logs et Monitoring

### 10.1 Logs Système

#### `get-log.system.sh`
**Description** : Récupère les logs système (syslog)  
**Entrée** : Nombre de lignes, filtre (optionnel)  
**Sortie** : Logs système récents  
**Dépendances** : `/var/log/syslog`, `journalctl`  
**Use case** : Diagnostic système

#### `get-log.auth.sh`
**Description** : Récupère les logs d'authentification  
**Entrée** : Nombre de lignes, filtre  
**Sortie** : Logs auth.log  
**Dépendances** : `/var/log/auth.log`  
**Use case** : Audit sécurité

#### `get-log.kernel.sh`
**Description** : Récupère les logs kernel  
**Sortie** : Logs dmesg  
**Dépendances** : `dmesg`, `journalctl -k`  
**Use case** : Diagnostic matériel

#### `search-log.pattern.sh`
**Description** : Recherche un pattern dans les logs  
**Entrée** : Pattern, fichier log, contexte  
**Sortie** : Lignes correspondantes  
**Dépendances** : `grep`  
**Use case** : Analyse logs

#### `analyze-log.errors.sh`
**Description** : Analyse les erreurs dans les logs  
**Entrée** : Fichier log, période  
**Sortie** : Erreurs groupées par type  
**Dépendances** : `grep`, `awk`, `sort`, `uniq`  
**Use case** : Diagnostic problèmes

#### `rotate-log.sh`
**Description** : Effectue la rotation d'un fichier log  
**Entrée** : Fichier log, nombre de rotations  
**Dépendances** : `logrotate`, `mv`  
**Use case** : Gestion espace disque

#### `compress-log.old.sh`
**Description** : Compresse les anciens logs  
**Entrée** : Répertoire logs, âge minimum  
**Dépendances** : `find`, `gzip`  
**Use case** : Économie espace

### 10.2 Journald

#### `get-journal.service.sh`
**Description** : Récupère les logs journald d'un service  
**Entrée** : Nom service, période  
**Sortie** : Logs du service  
**Dépendances** : `journalctl`  
**Use case** : Diagnostic service

#### `get-journal.boot.sh`
**Description** : Récupère les logs du boot actuel  
**Sortie** : Logs depuis dernier démarrage  
**Dépendances** : `journalctl -b`  
**Use case** : Diagnostic démarrage

#### `get-journal.priority.sh`
**Description** : Récupère les logs par niveau de priorité  
**Entrée** : Niveau (emerg, alert, crit, err, warning)  
**Sortie** : Logs filtrés  
**Dépendances** : `journalctl -p`  
**Use case** : Analyse erreurs critiques

### 10.3 Monitoring Ressources

#### `get-cpu.usage.sh`
**Description** : Récupère l'utilisation CPU actuelle  
**Sortie** : Usage global et par cœur (%)  
**Dépendances** : `mpstat`, `top`  
**Use case** : Monitoring CPU

#### `get-memory.usage.sh`
**Description** : Récupère l'utilisation mémoire  
**Sortie** : Total, utilisé, libre, cache, swap  
**Dépendances** : `free`  
**Use case** : Monitoring RAM

#### `get-disk.usage.sh`
**Description** : Récupère l'utilisation des disques  
**Sortie** : Partitions, taille, utilisé, disponible, %  
**Dépendances** : `df`  
**Use case** : Monitoring stockage

#### `get-disk.io.sh`
**Description** : Récupère les statistiques I/O disque  
**Sortie** : Read/write rates, IOPS  
**Dépendances** : `iostat`  
**Use case** : Analyse performance disque

#### `get-network.traffic.sh`
**Description** : Récupère les statistiques réseau  
**Sortie** : RX/TX bytes, packets, errors  
**Dépendances** : `/proc/net/dev`, `ifconfig`  
**Use case** : Monitoring réseau

#### `get-system.load.sh`
**Description** : Récupère la charge système (load average)  
**Sortie** : Load 1min, 5min, 15min  
**Dépendances** : `uptime`, `/proc/loadavg`  
**Use case** : Monitoring charge

---

## 11. Périphériques Matériels

### 11.1 PCI

#### `list-pci.devices.sh`
**Description** : Liste tous les périphériques PCI  
**Sortie** : Bus, device, function, description  
**Dépendances** : `lspci`  
**Use case** : Inventaire matériel

#### `list-pci.network.sh`
**Description** : Liste les cartes réseau PCI  
**Sortie** : Cartes réseau avec détails  
**Dépendances** : `lspci | grep Network`  
**Use case** : Inventaire réseau

#### `list-pci.graphics.sh`
**Description** : Liste les cartes graphiques PCI  
**Sortie** : GPU avec détails  
**Dépendances** : `lspci | grep VGA`  
**Use case** : Inventaire GPU

### 11.2 USB

#### `list-usb.devices.sh`
**Description** : Liste tous les périphériques USB  
**Sortie** : Bus, device, ID, description  
**Dépendances** : `lsusb`  
**Use case** : Inventaire USB

#### `get-usb.device.info.sh`
**Description** : Récupère les détails d'un périphérique USB  
**Entrée** : Bus:Device ID  
**Sortie** : Infos complètes du périphérique  
**Dépendances** : `lsusb -v`  
**Use case** : Diagnostic USB

### 11.3 Périphériques Bloc

#### `list-block.devices.sh`
**Description** : Liste tous les périphériques bloc  
**Sortie** : Nom, type, taille, point montage  
**Dépendances** : `lsblk`  
**Use case** : Inventaire stockage

#### `get-block.device.info.sh`
**Description** : Récupère les infos d'un périphérique bloc  
**Entrée** : Device (/dev/sda)  
**Sortie** : Toutes les caractéristiques  
**Dépendances** : `lsblk`, `hdparm`, `smartctl`  
**Use case** : Analyse disque

### 11.4 SMART (Disques)

#### `check-smart.health.sh`
**Description** : Vérifie l'état SMART d'un disque  
**Entrée** : Device  
**Sortie** : État santé, température, erreurs  
**Dépendances** : `smartctl`  
**Use case** : Monitoring santé disques

#### `get-smart.attributes.sh`
**Description** : Récupère tous les attributs SMART  
**Entrée** : Device  
**Sortie** : Attributs SMART détaillés  
**Dépendances** : `smartctl -A`  
**Use case** : Analyse approfondie

#### `run-smart.test.sh`
**Description** : Lance un test SMART  
**Entrée** : Device, type test (short/long)  
**Dépendances** : `smartctl -t`  
**Use case** : Test proactif disques

---

## 12. Bases de Données

### 12.1 MySQL/MariaDB

#### `check-mysql.status.sh`
**Description** : Vérifie l'état du serveur MySQL  
**Sortie** : Running/stopped, uptime, connexions  
**Dépendances** : `mysqladmin`  
**Use case** : Monitoring MySQL

#### `list-mysql.databases.sh`
**Description** : Liste toutes les bases de données MySQL  
**Entrée** : Credentials  
**Sortie** : Liste des BDD  
**Dépendances** : `mysql -e "SHOW DATABASES"`  
**Use case** : Inventaire BDD

#### `list-mysql.tables.sh`
**Description** : Liste les tables d'une base MySQL  
**Entrée** : Nom BDD, credentials  
**Sortie** : Tables de la BDD  
**Dépendances** : `mysql -e "SHOW TABLES"`  
**Use case** : Analyse structure

#### `get-mysql.table.size.sh`
**Description** : Récupère la taille d'une table MySQL  
**Entrée** : BDD, table, credentials  
**Sortie** : Taille en MB  
**Dépendances** : Requête information_schema  
**Use case** : Analyse espace

#### `optimize-mysql.table.sh`
**Description** : Optimise une table MySQL  
**Entrée** : BDD, table  
**Dépendances** : `mysqlcheck --optimize`  
**Use case** : Maintenance BDD

### 12.2 PostgreSQL

#### `check-postgresql.status.sh`
**Description** : Vérifie l'état du serveur PostgreSQL  
**Sortie** : Running/stopped, version, connexions  
**Dépendances** : `pg_isready`, `psql`  
**Use case** : Monitoring PostgreSQL

#### `list-postgresql.databases.sh`
**Description** : Liste toutes les bases PostgreSQL  
**Sortie** : Liste des BDD avec taille  
**Dépendances** : `psql -l`  
**Use case** : Inventaire PostgreSQL

#### `list-postgresql.tables.sh`
**Description** : Liste les tables d'une base PostgreSQL  
**Entrée** : Nom BDD  
**Sortie** : Tables avec schémas  
**Dépendances** : `psql -c "\dt"`  
**Use case** : Analyse structure

#### `vacuum-postgresql.database.sh`
**Description** : Lance VACUUM sur une base PostgreSQL  
**Entrée** : Nom BDD, full (optionnel)  
**Dépendances** : `vacuumdb`  
**Use case** : Maintenance PostgreSQL

### 12.3 MongoDB

#### `check-mongodb.status.sh`
**Description** : Vérifie l'état du serveur MongoDB  
**Sortie** : Running/stopped, version, connexions  
**Dépendances** : `mongo --eval "db.serverStatus()"`  
**Use case** : Monitoring MongoDB

#### `list-mongodb.databases.sh`
**Description** : Liste toutes les bases MongoDB  
**Sortie** : Liste des BDD avec taille  
**Dépendances** : `mongo --eval "db.adminCommand('listDatabases')"`  
**Use case** : Inventaire MongoDB

#### `list-mongodb.collections.sh`
**Description** : Liste les collections d'une base MongoDB  
**Entrée** : Nom BDD# Catalogue de Scripts Atomiques pour Environnement Linux

## Introduction

Ce catalogue liste tous les scripts atomiques organisés par catégorie fonctionnelle. Chaque script respecte la méthodologie définie et fait **UNE seule chose** de manière robuste et sécurisée.

---

## 📋 Index des catégories

1. [Système et Information](#1-système-et-information)
2. [Disques et Stockage](#2-disques-et-stockage)
3. [Réseau](#3-réseau)
4. [Utilisateurs et Groupes](#4-utilisateurs-et-groupes)
5. [Processus et Services](#5-processus-et-services)
6. [Fichiers et Répertoires](#6-fichiers-et-répertoires)
7. [Sauvegarde et Restauration](#7-sauvegarde-et-restauration)
8. [Sécurité et Permissions](#8-sécurité-et-permissions)
9. [Packages et Logiciels](#9-packages-et-logiciels)
10. [Logs et Monitoring](#10-logs-et-monitoring)
11. [Périphériques Matériels](#11-périphériques-matériels)
12. [Bases de Données](#12-bases-de-données)
13. [Conteneurs et Virtualisation](#13-conteneurs-et-virtualisation)
14. [Performance et Ressources](#14-performance-et-ressources)
15. [Automatisation et Planification](#15-automatisation-et-planification)

---

## 1. Système et Information

### 1.1 Information Système

#### `get-system.info.sh`
**Description** : Récupère les informations système complètes  
**Sortie** : Hostname, OS, version, architecture, uptime, kernel  
**Dépendances** : `uname`, `lsb_release`, `hostname`  
**Use case** : Inventaire système, audit, rapports

#### `get-system.hostname.sh`
**Description** : Récupère le nom d'hôte système  
**Sortie** : Hostname court et FQDN  
**Dépendances** : `hostname`  
**Use case** : Configuration, identification serveur

#### `get-system.uptime.sh`
**Description** : Récupère le temps d'activité système  
**Sortie** : Uptime en secondes, minutes, heures, jours  
**Dépendances** : `uptime`, `awk`  
**Use case** : Monitoring stabilité, SLA

#### `get-system.timezone.sh`
**Description** : Récupère le fuseau horaire système  
**Sortie** : Timezone, offset UTC, heure locale  
**Dépendances** : `timedatectl`, `date`  
**Use case** : Synchronisation, logs

#### `set-system.hostname.sh`
**Description** : Définit le nom d'hôte système  
**Entrée** : Nouveau hostname  
**Dépendances** : `hostnamectl`  
**Use case** : Configuration initiale, migration

#### `set-system.timezone.sh`
**Description** : Définit le fuseau horaire système  
**Entrée** : Timezone (ex: Europe/Paris)  
**Dépendances** : `timedatectl`  
**Use case** : Configuration régionale

### 1.2 Détection Matérielle

#### `detect-hardware.cpu.sh`
**Description** : Détecte les informations CPU  
**Sortie** : Modèle, nombre de cœurs, fréquence, cache  
**Dépendances** : `lscpu`, `/proc/cpuinfo`  
**Use case** : Inventaire, optimisation

#### `detect-hardware.memory.sh`
**Description** : Détecte la mémoire RAM installée  
**Sortie** : Total, type, slots, fréquence  
**Dépendances** : `dmidecode`, `free`  
**Use case** : Inventaire, capacity planning

#### `detect-hardware.bios.sh`
**Description** : Détecte les informations BIOS/UEFI  
**Sortie** : Vendor, version, date, serial  
**Dépendances** : `dmidecode`  
**Use case** : Inventaire, mises à jour firmware

---

## 2. Disques et Stockage

### 2.1 Détection et Listage

#### `detect-disk.all.sh`
**Description** : Détecte tous les disques disponibles  
**Sortie** : Liste complète des disques (HDD, SSD, NVMe)  
**Dépendances** : `lsblk`, `fdisk`  
**Use case** : Inventaire stockage, provisioning

#### `detect-disk.ssd.sh`
**Description** : Détecte uniquement les disques SSD  
**Sortie** : Liste des SSD avec capacité et modèle  
**Dépendances** : `lsblk`, `smartctl`  
**Use case** : Optimisation, sélection disque

#### `detect-disk.nvme.sh`
**Description** : Détecte les disques NVMe  
**Sortie** : Liste des NVMe avec performances  
**Dépendances** : `nvme`, `lsblk`  
**Use case** : Configuration haute performance

#### `list-disk.partitions.sh`
**Description** : Liste toutes les partitions d'un disque  
**Entrée** : Chemin du disque (/dev/sda)  
**Sortie** : Partitions, tailles, types, points de montage  
**Dépendances** : `lsblk`, `parted`  
**Use case** : Analyse stockage, diagnostic

#### `list-disk.mounted.sh`
**Description** : Liste tous les systèmes de fichiers montés  
**Sortie** : Point montage, device, filesystem, options  
**Dépendances** : `mount`, `df`  
**Use case** : Audit montages, troubleshooting

### 2.2 Partitionnement

#### `create-disk.partition.sh`
**Description** : Crée une partition sur un disque  
**Entrée** : Disque, taille, type (primary/extended/logical)  
**Dépendances** : `parted`, `fdisk`  
**Use case** : Provisioning disque

#### `delete-disk.partition.sh`
**Description** : Supprime une partition  
**Entrée** : Partition (/dev/sda1)  
**Dépendances** : `parted`  
**Use case** : Reconfiguration stockage

#### `resize-disk.partition.sh`
**Description** : Redimensionne une partition  
**Entrée** : Partition, nouvelle taille  
**Dépendances** : `parted`, `resize2fs`  
**Use case** : Extension stockage

### 2.3 Systèmes de Fichiers

#### `format-disk.ext4.sh`
**Description** : Formate une partition en ext4  
**Entrée** : Partition, label (optionnel)  
**Dépendances** : `mkfs.ext4`  
**Use case** : Préparation stockage Linux

#### `format-disk.xfs.sh`
**Description** : Formate une partition en XFS  
**Entrée** : Partition, options  
**Dépendances** : `mkfs.xfs`  
**Use case** : Haute performance, grands fichiers

#### `format-disk.btrfs.sh`
**Description** : Formate une partition en Btrfs  
**Entrée** : Partition, options  
**Dépendances** : `mkfs.btrfs`  
**Use case** : Snapshots, compression

#### `format-disk.vfat.sh`
**Description** : Formate une partition en FAT32  
**Entrée** : Partition, label  
**Dépendances** : `mkfs.vfat`  
**Use case** : Compatibilité multi-OS

### 2.4 Montage et Démontage

#### `mount-disk.partition.sh`
**Description** : Monte une partition  
**Entrée** : Partition, point de montage, options  
**Dépendances** : `mount`  
**Use case** : Accès stockage

#### `unmount-disk.partition.sh`
**Description** : Démonte une partition  
**Entrée** : Point de montage ou partition  
**Dépendances** : `umount`  
**Use case** : Maintenance, sécurité

#### `mount-disk.fstab.sh`
**Description** : Ajoute une entrée dans /etc/fstab  
**Entrée** : Partition, point montage, filesystem, options  
**Dépendances** : `blkid`, éditeur fstab  
**Use case** : Montage permanent

### 2.5 Périphériques USB

#### `detect-usb.storage.sh`
**Description** : Détecte les périphériques de stockage USB  
**Sortie** : Liste USB avec vendor, model, size, device  
**Dépendances** : `lsusb`, `udevadm`, `lsblk`  
**Use case** : Backup USB, transfert données

#### `detect-usb.all.sh`
**Description** : Détecte tous les périphériques USB  
**Sortie** : Liste complète (storage, input, autres)  
**Dépendances** : `lsusb`, `udevadm`  
**Use case** : Inventaire USB, diagnostic

### 2.6 LVM (Logical Volume Manager)

#### `create-lvm.pv.sh`
**Description** : Crée un Physical Volume LVM  
**Entrée** : Partition  
**Dépendances** : `pvcreate`  
**Use case** : Configuration LVM

#### `create-lvm.vg.sh`
**Description** : Crée un Volume Group LVM  
**Entrée** : Nom VG, PV à inclure  
**Dépendances** : `vgcreate`  
**Use case** : Gestion stockage flexible

#### `create-lvm.lv.sh`
**Description** : Crée un Logical Volume  
**Entrée** : Nom LV, VG, taille  
**Dépendances** : `lvcreate`  
**Use case** : Allocation stockage

#### `list-lvm.all.sh`
**Description** : Liste tous les éléments LVM  
**Sortie** : PV, VG, LV avec détails  
**Dépendances** : `pvs`, `vgs`, `lvs`  
**Use case** : Audit LVM

#### `extend-lvm.lv.sh`
**Description** : Étend un Logical Volume  
**Entrée** : LV, taille supplémentaire  
**Dépendances** : `lvextend`, `resize2fs`  
**Use case** : Extension stockage

### 2.7 RAID

#### `detect-raid.all.sh`
**Description** : Détecte les configurations RAID  
**Sortie** : Arrays RAID, niveau, état, disques  
**Dépendances** : `mdadm`, `/proc/mdstat`  
**Use case** : Monitoring RAID

#### `check-raid.health.sh`
**Description** : Vérifie l'état de santé d'un RAID  
**Entrée** : Device RAID (/dev/md0)  
**Sortie** : État, disques défaillants, sync status  
**Dépendances** : `mdadm`  
**Use case** : Monitoring proactif

---

## 3. Réseau

### 3.1 Interfaces Réseau

#### `list-network.interfaces.sh`
**Description** : Liste toutes les interfaces réseau  
**Sortie** : Nom, état, type (ethernet, wifi, virtuel)  
**Dépendances** : `ip`, `ifconfig`  
**Use case** : Inventaire réseau

#### `get-network.interface.ip.sh`
**Description** : Récupère l'IP d'une interface  
**Entrée** : Nom interface (eth0, ens33)  
**Sortie** : IPv4, IPv6, masque, broadcast  
**Dépendances** : `ip addr`  
**Use case** : Configuration, diagnostic

#### `get-network.interface.mac.sh`
**Description** : Récupère l'adresse MAC d'une interface  
**Entrée** : Nom interface  
**Sortie** : Adresse MAC  
**Dépendances** : `ip link`  
**Use case** : Identification matérielle

#### `set-network.interface.ip.sh`
**Description** : Configure l'IP d'une interface  
**Entrée** : Interface, IP, masque, gateway  
**Dépendances** : `ip addr`, `ip route`  
**Use case** : Configuration réseau

#### `enable-network.interface.sh`
**Description** : Active une interface réseau  
**Entrée** : Nom interface  
**Dépendances** : `ip link`  
**Use case** : Gestion interfaces

#### `disable-network.interface.sh`
**Description** : Désactive une interface réseau  
**Entrée** : Nom interface  
**Dépendances** : `ip link`  
**Use case** : Maintenance, sécurité

### 3.2 Connectivité

#### `check-network.connectivity.sh`
**Description** : Vérifie la connectivité internet  
**Sortie** : État connexion, latence, DNS  
**Dépendances** : `ping`, `curl`  
**Use case** : Diagnostic réseau

#### `test-network.ping.sh`
**Description** : Teste la connectivité vers un hôte  
**Entrée** : IP ou hostname, nombre de pings  
**Sortie** : Latence, packet loss, jitter  
**Dépendances** : `ping`  
**Use case** : Diagnostic connectivité

#### `test-network.port.sh`
**Description** : Teste si un port est ouvert  
**Entrée** : IP/hostname, port  
**Sortie** : État port (open/closed/filtered)  
**Dépendances** : `nc`, `telnet`  
**Use case** : Diagnostic services

### 3.3 DNS

#### `get-dns.servers.sh`
**Description** : Récupère les serveurs DNS configurés  
**Sortie** : Liste des serveurs DNS  
**Dépendances** : `/etc/resolv.conf`  
**Use case** : Audit configuration DNS

#### `set-dns.server.sh`
**Description** : Configure un serveur DNS  
**Entrée** : IP serveur DNS  
**Dépendances** : Édition `/etc/resolv.conf`  
**Use case** : Configuration DNS

#### `resolve-dns.hostname.sh`
**Description** : Résout un hostname en IP  
**Entrée** : Hostname  
**Sortie** : Adresses IP associées  
**Dépendances** : `nslookup`, `dig`, `host`  
**Use case** : Diagnostic DNS

#### `resolve-dns.reverse.sh`
**Description** : Résolution DNS inverse (IP → hostname)  
**Entrée** : Adresse IP  
**Sortie** : Hostname associé  
**Dépendances** : `dig`, `host`  
**Use case** : Identification hôtes

### 3.4 Routage

#### `list-network.routes.sh`
**Description** : Liste toutes les routes réseau  
**Sortie** : Destinations, gateways, interfaces, métriques  
**Dépendances** : `ip route`  
**Use case** : Audit routage

#### `get-network.gateway.sh`
**Description** : Récupère la passerelle par défaut  
**Sortie** : IP gateway, interface  
**Dépendances** : `ip route`  
**Use case** : Configuration réseau

#### `add-network.route.sh`
**Description** : Ajoute une route statique  
**Entrée** : Réseau destination, gateway, interface  
**Dépendances** : `ip route`  
**Use case** : Configuration routage avancé

#### `delete-network.route.sh`
**Description** : Supprime une route  
**Entrée** : Réseau destination  
**Dépendances** : `ip route`  
**Use case** : Reconfiguration réseau

### 3.5 Firewall

#### `list-firewall.rules.sh`
**Description** : Liste toutes les règles firewall  
**Sortie** : Règles iptables/nftables structurées  
**Dépendances** : `iptables`, `nft`  
**Use case** : Audit sécurité

#### `check-firewall.status.sh`
**Description** : Vérifie l'état du firewall  
**Sortie** : Actif/inactif, service utilisé  
**Dépendances** : `systemctl`, `iptables`  
**Use case** : Monitoring sécurité

#### `allow-firewall.port.sh`
**Description** : Autorise un port dans le firewall  
**Entrée** : Port, protocole (tcp/udp), source (optionnel)  
**Dépendances** : `iptables`, `firewall-cmd`  
**Use case** : Configuration services

#### `block-firewall.port.sh`
**Description** : Bloque un port dans le firewall  
**Entrée** : Port, protocole  
**Dépendances** : `iptables`, `firewall-cmd`  
**Use case** : Sécurisation

### 3.6 Connexions Actives

#### `list-network.connections.sh`
**Description** : Liste toutes les connexions réseau actives  
**Sortie** : Proto, local addr, remote addr, état, PID  
**Dépendances** : `ss`, `netstat`  
**Use case** : Monitoring activité réseau

#### `list-network.listening.sh`
**Description** : Liste tous les ports en écoute  
**Sortie** : Port, protocole, processus, PID  
**Dépendances** : `ss`, `netstat`  
**Use case** : Audit sécurité, services

---

## 4. Utilisateurs et Groupes

### 4.1 Utilisateurs

#### `list-user.all.sh`
**Description** : Liste tous les utilisateurs système  
**Sortie** : Username, UID, GID, home, shell  
**Dépendances** : `/etc/passwd`  
**Use case** : Audit utilisateurs

#### `list-user.human.sh`
**Description** : Liste uniquement les utilisateurs humains (UID >= 1000)  
**Sortie** : Utilisateurs non-système  
**Dépendances** : `/etc/passwd`, `awk`  
**Use case** : Gestion utilisateurs réels

#### `get-user.info.sh`
**Description** : Récupère les informations d'un utilisateur  
**Entrée** : Username  
**Sortie** : UID, GID, groupes, home, shell, lastlog  
**Dépendances** : `id`, `groups`, `lastlog`  
**Use case** : Audit utilisateur spécifique

#### `create-user.sh`
**Description** : Crée un nouvel utilisateur  
**Entrée** : Username, password, groupes, home, shell  
**Dépendances** : `useradd`, `passwd`  
**Use case** : Provisioning utilisateurs

#### `delete-user.sh`
**Description** : Supprime un utilisateur  
**Entrée** : Username, option supprimer home  
**Dépendances** : `userdel`  
**Use case** : Déprovisionning

#### `modify-user.shell.sh`
**Description** : Modifie le shell d'un utilisateur  
**Entrée** : Username, nouveau shell  
**Dépendances** : `usermod`, `chsh`  
**Use case** : Configuration utilisateur

#### `lock-user.sh`
**Description** : Verrouille un compte utilisateur  
**Entrée** : Username  
**Dépendances** : `usermod`, `passwd`  
**Use case** : Sécurité, suspension compte

#### `unlock-user.sh`
**Description** : Déverrouille un compte utilisateur  
**Entrée** : Username  
**Dépendances** : `usermod`, `passwd`  
**Use case** : Réactivation compte

#### `check-user.exists.sh`
**Description** : Vérifie si un utilisateur existe  
**Entrée** : Username  
**Sortie** : Existe (true/false)  
**Dépendances** : `id`, `/etc/passwd`  
**Use case** : Validation, scripts

### 4.2 Groupes

#### `list-group.all.sh`
**Description** : Liste tous les groupes système  
**Sortie** : Nom groupe, GID, membres  
**Dépendances** : `/etc/group`  
**Use case** : Audit groupes

#### `get-group.members.sh`
**Description** : Liste les membres d'un groupe  
**Entrée** : Nom du groupe  
**Sortie** : Liste des utilisateurs membres  
**Dépendances** : `/etc/group`, `getent`  
**Use case** : Audit appartenance

#### `create-group.sh`
**Description** : Crée un nouveau groupe  
**Entrée** : Nom groupe, GID (optionnel)  
**Dépendances** : `groupadd`  
**Use case** : Organisation utilisateurs

#### `delete-group.sh`
**Description** : Supprime un groupe  
**Entrée** : Nom groupe  
**Dépendances** : `groupdel`  
**Use case** : Nettoyage système

#### `add-user.togroup.sh`
**Description** : Ajoute un utilisateur à un groupe  
**Entrée** : Username, nom groupe  
**Dépendances** : `usermod`, `gpasswd`  
**Use case** : Gestion permissions

#### `remove-user.fromgroup.sh`
**Description** : Retire un utilisateur d'un groupe  
**Entrée** : Username, nom groupe  
**Dépendances** : `gpasswd`  
**Use case** : Révocation permissions

### 4.3 Sudo et Permissions

#### `list-user.sudo.sh`
**Description** : Liste les utilisateurs avec accès sudo  
**Sortie** : Utilisateurs du groupe sudo/wheel  
**Dépendances** : `/etc/group`, `/etc/sudoers`  
**Use case** : Audit privilèges

#### `grant-user.sudo.sh`
**Description** : Accorde les privilèges sudo à un utilisateur  
**Entrée** : Username  
**Dépendances** : `usermod`, édition sudoers  
**Use case** : Élévation privilèges

#### `revoke-user.sudo.sh`
**Description** : Révoque les privilèges sudo  
**Entrée** : Username  
**Dépendances** : `gpasswd`, édition sudoers  
**Use case** : Sécurité

---

## 5. Processus et Services

### 5.1 Processus

#### `list-process.all.sh`
**Description** : Liste tous les processus en cours  
**Sortie** : PID, user, CPU%, MEM%, command  
**Dépendances** : `ps`  
**Use case** : Monitoring système

#### `list-process.byuser.sh`
**Description** : Liste les processus d'un utilisateur  
**Entrée** : Username  
**Sortie** : Processus de l'utilisateur  
**Dépendances** : `ps`, `pgrep`  
**Use case** : Audit utilisateur

#### `get-process.info.sh`
**Description** : Récupère les détails d'un processus  
**Entrée** : PID  
**Sortie** : Toutes les infos du processus  
**Dépendances** : `ps`, `/proc`  
**Use case** : Diagnostic

#### `kill-process.sh`
**Description** : Termine un processus  
**Entrée** : PID, signal (optionnel)  
**Dépendances** : `kill`  
**Use case** : Gestion processus

#### `killall-process.byname.sh`
**Description** : Termine tous les processus d'un nom  
**Entrée** : Nom processus  
**Dépendances** : `killall`, `pkill`  
**Use case** : Nettoyage processus

### 5.2 Services (systemd)

#### `list-service.all.sh`
**Description** : Liste tous les services systemd  
**Sortie** : Nom, état (active/inactive), enabled/disabled  
**Dépendances** : `systemctl`  
**Use case** : Audit services

#### `list-service.active.sh`
**Description** : Liste uniquement les services actifs  
**Sortie** : Services en cours d'exécution  
**Dépendances** : `systemctl`  
**Use case** : Monitoring

#### `list-service.failed.sh`
**Description** : Liste les services en échec  
**Sortie** : Services failed avec raison  
**Dépendances** : `systemctl`  
**Use case** : Diagnostic problèmes

#### `get-service.status.sh`
**Description** : Récupère l'état d'un service  
**Entrée** : Nom service  
**Sortie** : État détaillé, logs récents  
**Dépendances** : `systemctl`  
**Use case** : Diagnostic service

#### `start-service.sh`
**Description** : Démarre un service  
**Entrée** : Nom service  
**Dépendances** : `systemctl`  
**Use case** : Gestion services

#### `stop-service.sh`
**Description** : Arrête un service  
**Entrée** : Nom service  
**Dépendances** : `systemctl`  
**Use case** : Maintenance

#### `restart-service.sh`
**Description** : Redémarre un service  
**Entrée** : Nom service  
**Dépendances** : `systemctl`  
**Use case** : Application configuration

#### `enable-service.sh`
**Description** : Active un service au démarrage  
**Entrée** : Nom service  
**Dépendances** : `systemctl`  
**Use case** : Configuration permanente

#### `disable-service.sh`
**Description** : Désactive un service au démarrage  
**Entrée** : Nom service  
**Dépendances** : `systemctl`  
**Use case** : Optimisation démarrage

### 5.3 Tâches Planifiées

#### `list-cron.user.sh`
**Description** : Liste les tâches cron d'un utilisateur  
**Entrée** : Username (défaut: current user)  
**Sortie** : Crontab de l'utilisateur  
**Dépendances** : `crontab`  
**Use case** : Audit automatisation

#### `list-cron.system.sh`
**Description** : Liste toutes les tâches cron système  
**Sortie** : Contenu de /etc/crontab et /etc/cron.d/  
**Dépendances** : Lecture fichiers cron  
**Use case** : Audit système

---

## 6. Fichiers et Répertoires

### 6.1 Opérations de Base

#### `create-file.sh`
**Description** : Crée un fichier vide ou avec contenu  
**Entrée** : Chemin, contenu (optionnel), permissions  
**Dépendances** : `touch`, `echo`  
**Use case** : Provisioning fichiers

#### `delete-file.sh`
**Description** : Supprime un fichier  
**Entrée** : Chemin fichier  
**Dépendances** : `rm`  
**Use case** : Nettoyage

#### `copy-file.sh`
**Description** : Copie un fichier  
**Entrée** : Source, destination, préserver attributs  
**Dépendances** : `cp`  
**Use case** : Backup, duplication

#### `move-file.sh`
**Description** : Déplace ou renomme un fichier  
**Entrée** : Source, destination  
**Dépendances** : `mv`  
**Use case** : Réorganisation

#### `create-directory.sh`
**Description** : Crée un répertoire  
**Entrée** : Chemin, permissions, récursif  
**Dépendances** : `mkdir`  
**Use case** : Structure arborescence

#### `delete-directory.sh`
**Description** : Supprime un répertoire  
**Entrée** : Chemin, récursif, force  
**Dépendances** : `rm`, `rmdir`  
**Use case** : Nettoyage

### 6.2 Recherche

#### `find-file.byname.sh`
**Description** : Recherche des fichiers par nom  
**Entrée** : Pattern, répertoire de départ  
**Sortie** : Liste des fichiers trouvés  
**Dépendances** : `find`  
**Use case** : Localisation fichiers

#### `find-file.bysize.sh`
**Description** : Recherche des fichiers par taille  
**Entrée** : Taille min/max, répertoire  
**Sortie** : Fichiers correspondants  
**Dépendances** : `find`  
**Use case** : Nettoyage espace disque

#### `find-file.bydate.sh`
**Description** : Recherche des fichiers par date de modification  
**Entrée** : Date/âge, répertoire  
**Sortie** : Fichiers modifiés dans la période  
**Dépendances** : `find`  
**Use case** : Audit modifications

#### `find-file.bycontent.sh`
**Description** : Recherche des fichiers contenant un texte  
**Entrée** : Pattern texte, répertoire  
**Sortie** : Fichiers avec occurrences  
**Dépendances** : `grep`, `find`  
**Use case** : Recherche configuration

### 6.3 Permissions et Propriété

#### `get-file.permissions.sh`
**Description** : Récupère les permissions d'un fichier  
**Entrée** : Chemin fichier  
**Sortie** : Permissions (numeric et symbolic), owner, group  
**Dépendances** : `stat`, `ls`  
**Use case** : Audit sécurité

#### `set-file.permissions.sh`
**Description** : Modifie les permissions