✅ Principe de responsabilité unique
✅ Idempotence
✅ Fail-fast avec cleanup
✅ Traçabilité complète
✅ Tests exhaustifs
✅ Documentation vivante
✅ Sécurité par défaut
✅ Performance optimisée

### 📖 Guide de démarrage rapide

#### Installation

```bash
# Cloner le projet
git clone https://github.com/yourorg/scripts-toolkit.git
cd scripts-toolkit

# Installer
sudo ./install.sh

# Sourcer la configuration
source /etc/profile.d/scripts-toolkit.sh
```

#### Créer un nouveau script atomique

```bash
# Générer le squelette
./tools/script-generator.sh atomic mon-nouveau-script

# Éditer le script
nano atomics/mon-nouveau-script.sh

# Écrire les tests
nano tests/atomics/test-mon-nouveau-script.sh

# Tester
./tests/atomics/test-mon-nouveau-script.sh

# Valider avec le linter
./tools/custom-linter.sh atomics/mon-nouveau-script.sh

# Documenter
./tools/doc-generator.sh all
```

#### Créer un orchestrateur

```bash
# Générer l'orchestrateur
./tools/script-generator.sh orchestrator mon-orchestrateur

# Définir les dépendances dans le script
# Implémenter la logique d'orchestration
nano orchestrators/level-1/mon-orchestrateur.sh

# Tester l'intégration
./mon-orchestrateur.sh --verbose

# Générer la documentation
./tools/doc-generator.sh all
```

#### Workflow de développement complet

```bash
# 1. Créer une branche
git checkout -b feature/new-script

# 2. Générer le script
./tools/script-generator.sh atomic detect-network

# 3. Développer et tester
nano atomics/detect-network.sh
./tests/atomics/test-detect-network.sh

# 4. Valider
./tools/custom-linter.sh atomics/detect-network.sh
shellcheck atomics/detect-network.sh

# 5. Documenter
./tools/doc-generator.sh all

# 6. Commiter
git add .
git commit -m "feat(atomics): add detect-network.sh"

# 7. Push et créer une PR
git push origin feature/new-script

# 8. CI/CD s'exécute automatiquement
# - Tests
# - Lint
# - Documentation

# 9. Après merge, créer une release
./tools/version-manager.sh bump minor
./tools/version-manager.sh release
git push origin main --tags
```

### 🎯 Cas d'usage réels

#### 1. Système de backup automatisé

```bash
# Configuration
cat > /etc/scripts-toolkit/backup-config.sh <<EOF
SOURCE_DIRS=("/home" "/var/www" "/etc")
DEST_DIR="/backup"
RETENTION_DAYS=30
ENCRYPT=1
ENCRYPTION_KEY="your-secret-key"
NOTIFICATION_CHANNELS=("slack" "email")
EOF

# Exécution manuelle
./examples/automated-backup.sh \
  --source /home \
  --destination /backup/home \
  --retention 30 \
  --encrypt "your-key"

# Planification avec cron
echo "0 2 * * * root /usr/local/bin/automated-backup.sh --source /home --destination /backup/home" >> /etc/crontab
```

#### 2. Pipeline ETL de données

```bash
# Traitement de fichiers CSV
./examples/data-pipeline.sh \
  --input data/sales-2024.csv \
  --output /var/analytics \
  --db-host analytics.db.internal \
  --db-pass secret

# Résultat JSON
{
  "total_records": 150000,
  "processed": 149850,
  "errors": 150,
  "success_rate": 99.90
}
```

#### 3. Infrastructure as Code

```bash
# Orchestrateur pour provisionner un serveur complet
./orchestrators/level-3/provision-web-server.sh \
  --hostname web01.example.com \
  --domain example.com \
  --ssl-email admin@example.com \
  --apps "nginx,php,mysql" \
  --firewall-rules "80,443,22"

# Sortie avec tous les détails
{
  "status": "success",
  "hostname": "web01.example.com",
  "services_installed": ["nginx", "php-fpm", "mysql"],
  "ssl_certificate": "issued",
  "firewall_configured": true,
  "duration_seconds": 245
}
```

#### 4. Monitoring et alertes

```bash
# Démarrer le daemon de monitoring
sudo systemctl start script-monitor

# Voir le dashboard
./monitoring/collectors/script-metrics.sh dashboard

# Consulter les alertes
cat /var/log/scripts-toolkit/monitoring/alerts-$(date +%Y-%m-%d).json

# Configuration des seuils
cat > /etc/scripts-toolkit/monitoring.conf <<EOF
SUCCESS_RATE_THRESHOLD=95
ERROR_RATE_ALERT=5
TIMEOUT_THRESHOLD=300
EOF
```

### 🔍 Debugging et troubleshooting

#### Activer le mode debug

```bash
# Pour un script spécifique
LOG_LEVEL=0 ./atomics/detect-usb.sh --debug

# Globalement
export LOG_LEVEL=0
```

#### Profiling de performance

```bash
# Profiler un script
./tools/profiler.sh ./orchestrators/level-2/setup-disk.sh /dev/sdb

# Résultat
Top 20 slowest operations:
=========================================
2.345s (1x) format-disk.sh /dev/sdb1
0.892s (3x) validate_block_device
0.234s (1x) detect-usb.sh
...
```

#### Audit et traçabilité

```bash
# Rechercher dans l'audit
./lib/audit.sh search "setup-disk" \
  --start "2024-10-01" \
  --end "2024-10-03"

# Générer un rapport
./lib/audit.sh report "2024-10-01" "2024-10-03"

# Analyser les échecs
jq 'select(.event_type == "EXECUTION_END" and .details | contains("FAILURE"))' \
  /var/log/scripts-toolkit/audit.log
```

### 🔐 Sécurité avancée

#### Exécution en sandbox

```bash
# Créer et exécuter dans une sandbox
source "$PROJECT_ROOT/lib/sandbox.sh"

sandbox_create
sandbox_exec ./atomics/untrusted-script.sh --params
sandbox_destroy
```

#### Validation des permissions

```bash
# Vérifier les permissions avant exécution
source "$PROJECT_ROOT/lib/sandbox.sh"

if sandbox_validate_permissions ./atomics/script.sh; then
  ./atomics/script.sh
else
  echo "Security violation detected"
fi
```

#### Audit de sécurité

```bash
# Enregistrer les accès sensibles
audit_sensitive_access "setup-firewall.sh" "/etc/iptables" "WRITE"

# Rechercher les accès suspects
jq 'select(.event_type == "SENSITIVE_ACCESS")' \
  /var/log/scripts-toolkit/audit.log
```

### 📈 Optimisations avancées

#### Utilisation du cache

```bash
# Script avec cache automatique
source "$PROJECT_ROOT/lib/cache.sh"

init_cache

# Définir un TTL personnalisé
CACHE_TTL=1800  # 30 minutes

# Le cache est automatique
result=$(./atomics/detect-usb.sh --cached)

# Nettoyer le cache expiré
cache_cleanup
```

#### Exécution parallèle

```bash
# Orchestrateur avec pool de workers
source "$PROJECT_ROOT/lib/worker-pool.sh"

WORKER_POOL_SIZE=8  # 8 workers en parallèle

worker_pool_init

# Soumettre plusieurs tâches
for disk in /dev/sd{b..h}; do
  worker_pool_submit "disk-$disk" \
    "./atomics/format-disk.sh" "$disk"
done

# Exécuter en parallèle
worker_pool_execute

# Collecter les résultats
for disk in /dev/sd{b..h}; do
  worker_pool_get_result "disk-$disk"
done

worker_pool_cleanup
```

#### Retry intelligent

```bash
source "$PROJECT_ROOT/lib/retry.sh"

# Retry avec backoff exponentiel
retry_execute "./atomics/api-call.sh" 5

# Retry seulement sur certaines erreurs
retry_execute_conditional \
  "./atomics/network-operation.sh" \
  "7 124"  # Retry sur timeout uniquement \
  3

# Circuit breaker pour éviter les cascades
circuit_breaker_execute "external-api" \
  "./atomics/api-call.sh --endpoint /users"
```

### 🌐 Intégrations entreprise

#### Intégration avec Ansible

```yaml
# playbook.yml
---
- name: Deploy scripts toolkit
  hosts: all
  tasks:
    - name: Install scripts toolkit
      shell: |
        curl -L https://github.com/yourorg/scripts-toolkit/releases/latest/download/scripts-toolkit.tar.gz | tar xz
        cd scripts-toolkit
        ./install.sh
        
    - name: Configure monitoring
      template:
        src: monitoring.conf.j2
        dest: /etc/scripts-toolkit/monitoring.conf
        
    - name: Execute provisioning script
      shell: |
        /usr/local/bin/provision-server.sh \
          --hostname {{ inventory_hostname }} \
          --environment {{ env }}
```

#### Intégration avec Terraform

```hcl
# main.tf
resource "null_resource" "provision_server" {
  provisioner "remote-exec" {
    inline = [
      "curl -L ${var.toolkit_url} | tar xz",
      "cd scripts-toolkit && ./install.sh",
      "/usr/local/bin/setup-web-server.sh --hostname ${var.hostname}"
    ]
  }
  
  connection {
    host = aws_instance.web.public_ip
    user = "ubuntu"
  }
}
```

#### Intégration avec Kubernetes

```yaml
# job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-pipeline
spec:
  template:
    spec:
      containers:
      - name: pipeline
        image: scripts-toolkit:latest
        command: ["/usr/local/bin/data-pipeline.sh"]
        args:
          - "--input"
          - "/data/input.csv"
          - "--output"
          - "/data/processed"
        volumeMounts:
        - name: data
          mountPath: /data
        env:
        - name: LOG_LEVEL
          value: "1"
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: host
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: data-pvc
      restartPolicy: OnFailure
```

#### Intégration avec GitLab CI/CD

```yaml
# .gitlab-ci.yml
stages:
  - test
  - build
  - deploy

variables:
  SCRIPTS_VERSION: "1.2.0"

test:
  stage: test
  image: ubuntu:latest
  before_script:
    - apt-get update && apt-get install -y shellcheck jq
  script:
    - ./tools/custom-linter.sh atomics/*.sh
    - find tests/ -name "test-*.sh" -exec {} \;

build:
  stage: build
  script:
    - ./tools/package-builder.sh all $SCRIPTS_VERSION
  artifacts:
    paths:
      - build/*.deb
      - build/*.rpm
      - build/*.tar.gz
    expire_in: 1 week

deploy_production:
  stage: deploy
  script:
    - scp build/scripts-toolkit-${SCRIPTS_VERSION}.tar.gz prod-server:/tmp/
    - ssh prod-server "cd /tmp && tar xzf scripts-toolkit-${SCRIPTS_VERSION}.tar.gz && cd scripts-toolkit && ./install.sh"
  only:
    - tags
  when: manual
```

### 📊 Métriques et KPIs

#### Tableau de bord de santé du système

```bash
# Générer un rapport de santé
cat > /usr/local/bin/health-report.sh <<'EOF'
#!/bin/bash

echo "╔════════════════════════════════════════╗"
echo "║     Scripts Toolkit Health Report      ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Statistiques globales
echo "📊 Execution Statistics (Last 24h)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

total=$(jq -s 'map(.execution_count) | add' /var/log/scripts-toolkit/monitoring/metrics/metrics-*.json 2>/dev/null || echo 0)
success=$(jq -s 'map(.success_count) | add' /var/log/scripts-toolkit/monitoring/metrics/metrics-*.json 2>/dev/null || echo 0)

echo "Total Executions: $total"
echo "Successful: $success"
echo "Success Rate: $(echo "scale=2; ($success / $total) * 100" | bc)%"
echo ""

# Scripts les plus utilisés
echo "🔥 Top 5 Most Used Scripts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
jq -s 'map({script: .script_name, count: .execution_count}) | group_by(.script) | map({script: .[0].script, total: map(.count) | add}) | sort_by(.total) | reverse | .[0:5]' \
  /var/log/scripts-toolkit/monitoring/metrics/metrics-*.json 2>/dev/null | \
  jq -r '.[] | "\(.script): \(.total) executions"' | nl
echo ""

# Alertes actives
echo "⚠️  Active Alerts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
alert_count=$(find /var/log/scripts-toolkit/monitoring/metrics/ -name "alerts-*.json" -exec cat {} \; | jq -s 'map(select(.level == "warning" or .level == "critical")) | length' 2>/dev/null || echo 0)

if [[ $alert_count -gt 0 ]]; then
  find /var/log/scripts-toolkit/monitoring/metrics/ -name "alerts-*.json" -exec cat {} \; | \
    jq -s 'map(select(.level == "warning" or .level == "critical")) | .[] | "[\(.level | ascii_upcase)] \(.script): \(.message)"' -r
else
  echo "✓ No active alerts"
fi
echo ""

# Performance
echo "⚡ Performance Metrics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Average execution time: TBD"
echo "P95 execution time: TBD"
echo "Slowest script: TBD"
echo ""

# Stockage
echo "💾 Storage Usage"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Logs: $(du -sh /var/log/scripts-toolkit 2>/dev/null | awk '{print $1}')"
echo "Cache: $(du -sh /var/cache/scripts-toolkit 2>/dev/null | awk '{print $1}')"
echo ""

echo "Last updated: $(date)"
EOF

chmod +x /usr/local/bin/health-report.sh
```

### 🎓 Formation et documentation

#### Guide du contributeur

```markdown
# Guide du contributeur

## Prérequis

- Bash 4.0+
- jq
- shellcheck
- Git

## Environnement de développement

1. Fork le projet
2. Clone votre fork
3. Installer les dépendances de dev
4. Configurer pre-commit hooks

## Standards de code

- Suivre le template atomic/orchestrator
- Tests obligatoires pour tout nouveau code
- Documentation inline
- Passer shellcheck sans warning
- Passer le linter personnalisé

## Workflow de contribution

1. Créer une issue
2. Créer une branche feature/fix
3. Développer + tester
4. Créer une PR
5. Review et merge

## Tests

- Tests unitaires pour atomiques
- Tests d'intégration pour orchestrateurs
- Coverage minimum: 80%

## Documentation

- README pour chaque nouveau script
- Exemples d'utilisation
- Diagrammes pour orchestrateurs complexes
```

### 🚀 Roadmap et évolution

#### Fonctionnalités futures

```markdown
## Version 2.0 (Q1 2025)

### Nouvelles fonctionnalités
- [ ] Support multi-langage (Python, Ruby)
- [ ] Interface web de monitoring
- [ ] Génération de rapports PDF
- [ ] Support Windows (WSL/Git Bash)
- [ ] Plugin système extensible
- [ ] Marketplace de scripts
- [ ] IDE integration (VS Code extension)

### Améliorations
- [ ] Performance: réduction de 50% du temps d'exécution
- [ ] Cache distribué (Redis)
- [ ] Orchestration Kubernetes native
- [ ] Machine learning pour prédiction d'erreurs
- [ ] Auto-healing et self-correction

### Infrastructure
- [ ] Multi-cloud deployment
- [ ] Containerisation complète
- [ ] Service mesh integration
- [ ] Observability avancée (OpenTelemetry)
```

### 📞 Support et communauté

#### Ressources

- **Documentation**: https://docs.scripts-toolkit.io
- **GitHub**: https://github.com/yourorg/scripts-toolkit
- **Issues**: https://github.com/yourorg/scripts-toolkit/issues
- **Discussions**: https://github.com/yourorg/scripts-toolkit/discussions
- **Slack**: scripts-toolkit.slack.com
- **Stack Overflow**: Tag `scripts-toolkit`

#### Obtenir de l'aide

```bash
# Documentation intégrée
./tools/doc-browser.sh

# Aide d'un script spécifique
detect-usb.sh --help

# Rechercher dans la documentation
./tools/doc-browser.sh search "format disk"

# Logs de debug
LOG_LEVEL=0 ./atomics/your-script.sh --debug

# Ouvrir une issue
gh issue create --title "Bug: describe issue" --body "Details..."
```

### 🏆 Conclusion finale

Ce framework complet vous permet de :

✅ **Développer** des scripts robustes et maintenables  
✅ **Tester** automatiquement avec CI/CD  
✅ **Déployer** sur multiples plateformes  
✅ **Monitorer** en temps réel avec alertes  
✅ **Documenter** automatiquement  
✅ **Collaborer** efficacement en équipe  
✅ **Scaler** de scripts simples à des systèmes complexes  

**Votre système évolue de manière organique**, chaque nouveau script s'appuyant sur une fondation solide et éprouvée. La dette technique est minimisée grâce aux standards rigoureux, et la qualité est garantie par les tests et validations automatiques.

**Commencez petit, évoluez grand** : démarrez avec quelques scripts atomiques, puis construisez progressivement des orchestrateurs plus complexes. Le framework est conçu pour grandir avec vos besoins.

---

## Annexes

### Annexe A : Checklist de mise en production

```markdown
## Avant la mise en production

### Scripts
- [ ] Tous les scripts passent shellcheck sans erreur
- [ ] Tests unitaires écrits et passent à 100%
- [ ] Tests d'intégration validés
- [ ] Documentation complète et à jour
- [ ] Exemples d'utilisation fournis
- [ ] Codes de sortie documentés

### Sécurité
- [ ] Validation des entrées implémentée
- [ ] Permissions vérifiées
- [ ] Audit trail activé
- [ ] Secrets externalisés (pas de hardcoding)
- [ ] Sandbox testée si nécessaire

### Performance
- [ ] Profiling effectué
- [ ] Goulots d'étranglement identifiés et corrigés
- [ ] Cache configuré si pertinent
- [ ] Timeouts définis

### Monitoring
- [ ] Logs configurés
- [ ] Métriques collectées
- [ ] Alertes définies
- [ ] Dashboard configuré
- [ ] Notifications testées

### Déploiement
- [ ] Package créé (DEB/RPM/TAR)
- [ ] Installation testée sur environnement cible
- [ ] Rollback plan défini
- [ ] Documentation de déploiement
- [ ] Runbook opérationnel

### Post-déploiement
- [ ] Smoke tests exécutés
- [ ] Monitoring actif
- [ ] Équipe formée
- [ ] Documentation accessible
- [ ] Support en place
```

### Annexe B : Glossaire

| Terme | Définition |
|-------|------------|
| **Script Atomique** | Script de niveau 0 qui effectue une seule action bien définie, sans dépendance vers d'autres scripts du projet |
| **Orchestrateur** | Script qui compose plusieurs scripts atomiques ou orchestrateurs de niveau inférieur pour réaliser une tâche complexe |
| **Worker Pool** | Système d'exécution parallèle permettant de lancer plusieurs tâches simultanément avec un nombre limité de workers |
| **Circuit Breaker** | Pattern qui empêche l'exécution répétée d'opérations qui échouent systématiquement |
| **Backoff Exponentiel** | Stratégie de retry où le délai entre chaque tentative augmente exponentiellement |
| **Idempotence** | Propriété d'une opération qui peut être exécutée plusieurs fois sans changer le résultat après la première exécution |
| **Sandbox** | Environnement d'exécution isolé et sécurisé |
| **Audit Trail** | Journal détaillé de toutes les actions effectuées par les scripts |
| **TTL (Time To Live)** | Durée de validité d'une donnée en cache |
| **Versioning Sémantique** | Système de numérotation de versions au format MAJOR.MINOR.PATCH |

### Annexe C : Variables d'environnement

```bash
# Chemins
PROJECT_ROOT           # Racine du projet
LOG_DIR               # Répertoire des logs
CACHE_DIR             # Répertoire du cache

# Logging
LOG_LEVEL             # Niveau de log (0=DEBUG, 1=INFO, 2=WARN, 3=ERROR)

# Cache
CACHE_TTL             # Durée de vie du cache en secondes

# Performance
WORKER_POOL_SIZE      # Nombre de workers parallèles
RETRY_MAX_ATTEMPTS    # Nombre maximum de tentatives
RETRY_INITIAL_DELAY   # Délai initial entre tentatives (secondes)

# Monitoring
MONITOR_INTERVAL      # Intervalle de collecte des métriques (secondes)

# Notifications
SLACK_WEBHOOK_URL     # URL du webhook Slack
DISCORD_WEBHOOK_URL   # URL du webhook Discord
TEAMS_WEBHOOK_URL     # URL du webhook Microsoft Teams
NOTIFICATION_EMAIL    # Email pour notifications
PAGERDUTY_ROUTING_KEY # Clé PagerDuty

# Base de données
DB_HOST               # Hôte de la base de données
DB_PORT               # Port de la base de données
DB_NAME               # Nom de la base de données
DB_USER               # Utilisateur de la base de données
DB_PASS               # Mot de passe (utiliser un secret manager en prod)

# API
API_BASE_URL          # URL de base pour les appels API
API_TIMEOUT           # Timeout des requêtes API (secondes)
API_RETRY_ATTEMPTS    # Nombre de tentatives pour les appels API

# Sécurité
AUDIT_RETENTION_DAYS  # Durée de rétention des logs d'audit
CIRCUIT_BREAKER_THRESHOLD    # Nombre d'échecs avant ouverture du circuit
CIRCUIT_BREAKER_TIMEOUT      # Durée avant réessai (secondes)
```

### Annexe D : Commandes utiles

```bash
# Installation et configuration
sudo ./install.sh                          # Installation standard
sudo ./install.sh /opt/scripts             # Installation personnalisée
source /etc/profile.d/scripts-toolkit.sh   # Charger la configuration

# Développement
./tools/script-generator.sh atomic mon-script        # Créer un script atomique
./tools/script-generator.sh orchestrator mon-orch    # Créer un orchestrateur
./tools/custom-linter.sh atomics/*.sh                # Valider les scripts
shellcheck atomics/*.sh                              # Vérification syntaxe

# Tests
./tests/atomics/test-mon-script.sh                   # Tester un script
find tests/ -name "test-*.sh" -exec {} \;            # Tous les tests

# Documentation
./tools/doc-generator.sh all                         # Générer la doc
./tools/doc-generator.sh html                        # Générer HTML
./tools/doc-browser.sh                               # Navigateur interactif

# Versioning
./tools/version-manager.sh current                   # Version actuelle
./tools/version-manager.sh bump minor                # Incrémenter version
./tools/version-manager.sh changelog                 # Générer changelog
./tools/version-manager.sh release                   # Créer une release

# Packaging
./tools/package-builder.sh deb 1.2.3                # Package DEB
./tools/package-builder.sh rpm 1.2.3                # Package RPM
./tools/package-builder.sh tar 1.2.3                # Archive TAR
./tools/package-builder.sh all 1.2.3                # Tous les formats

# Monitoring
./monitoring/monitor-daemon.sh start                 # Démarrer monitoring
./monitoring/monitor-daemon.sh status                # Status
./monitoring/collectors/script-metrics.sh dashboard  # Dashboard CLI
health-report.sh                                     # Rapport de santé

# Profiling et debugging
LOG_LEVEL=0 ./atomics/script.sh --debug             # Mode debug
./tools/profiler.sh ./atomics/script.sh args        # Profiler un script

# Audit
./lib/audit.sh search "script-name"                 # Rechercher dans audit
./lib/audit.sh report "2024-10-01" "2024-10-03"    # Rapport d'audit

# Cache
cache_cleanup                                        # Nettoyer le cache
cache_invalidate "detect-*"                         # Invalider pattern
```

### Annexe E : Troubleshooting

#### Problème : Script ne s'exécute pas

```bash
# Vérifier les permissions
ls -la atomics/mon-script.sh
chmod +x atomics/mon-script.sh

# Vérifier la syntaxe
bash -n atomics/mon-script.sh
shellcheck atomics/mon-script.sh

# Exécuter en mode debug
bash -x atomics/mon-script.sh
```

#### Problème : Erreur de dépendances

```bash
# Vérifier les dépendances manquantes
./atomics/script.sh --help  # Affiche les erreurs de dépendances

# Installer les dépendances communes
sudo apt-get install jq bash coreutils  # Debian/Ubuntu
sudo yum install jq bash coreutils      # RHEL/CentOS
```

#### Problème : Logs non créés

```bash
# Vérifier les permissions des répertoires
ls -ld /var/log/scripts-toolkit
sudo mkdir -p /var/log/scripts-toolkit
sudo chown $USER:$USER /var/log/scripts-toolkit

# Vérifier la configuration
cat /etc/scripts-toolkit/config.sh
```

#### Problème : Monitoring ne fonctionne pas

```bash
# Vérifier le daemon
systemctl status script-monitor
sudo systemctl restart script-monitor

# Vérifier les logs du daemon
tail -f /var/log/scripts-toolkit/monitoring/daemon.log

# Vérifier Prometheus
curl http://localhost:9090/-/healthy
```

#### Problème : Cache corrompu

```bash
# Nettoyer complètement le cache
rm -rf /var/cache/scripts-toolkit/*
# ou
cache_invalidate "*"
```

### Annexe F : Migration depuis une version antérieure

```bash
#!/bin/bash
# migrate-to-v2.sh

echo "Migration Scripts Toolkit v1.x -> v2.0"

# Backup de la configuration
cp -r /etc/scripts-toolkit /etc/scripts-toolkit.backup.$(date +%Y%m%d)

# Backup des logs
tar -czf /tmp/logs-backup-$(date +%Y%m%d).tar.gz /var/log/scripts-toolkit

# Arrêter les services
systemctl stop script-monitor

# Installation de la nouvelle version
./install.sh

# Migration de la configuration
# (adapter selon vos besoins spécifiques)

# Redémarrer les services
systemctl start script-monitor

# Vérification
health-report.sh

echo "Migration terminée. Vérifiez le rapport de santé ci-dessus."
```

### Annexe G : Références et ressources externes

#### Documentation Bash
- [Bash Guide](https://mywiki.wooledge.org/BashGuide)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)

#### Best Practices
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Defensive Bash Programming](https://kfirlavi.herokuapp.com/blog/2012/11/14/defensive-bash-programming/)

#### Outils
- [jq Manual](https://stedolan.github.io/jq/manual/)
- [ShellCheck](https://github.com/koalaman/shellcheck)
- [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core)

#### Monitoring
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

#### CI/CD
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)

---

## Licence

```
MIT License

Copyright (c) 2024 [Your Organization]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Changelog

### Version 2.0.0 (En développement)
- Ajout du support multi-langage
- Interface web de monitoring
- Amélioration des performances (50% plus rapide)
- Cache distribué avec Redis
- Support Kubernetes natif

### Version 1.2.0 (2024-10-03)
- Ajout du système de monitoring complet
- Support des notifications multi-canal
- Amélioration du système de cache
- Worker pool pour exécution parallèle
- Documentation interactive

### Version 1.1.0 (2024-09-15)
- Ajout du système d'audit
- Amélioration de la sécurité (sandbox)
- Support des bases de données multiples
- Retry avec backoff exponentiel
- Circuit breaker

### Version 1.0.0 (2024-09-01)
- Release initiale
- Scripts atomiques de base
- Orchestrateurs niveau 1 et 2
- Système de logging
- Tests automatisés
- Documentation complète

---

## Contributeurs

Merci à tous ceux qui ont contribué à ce projet :

- **Votre Nom** - Créateur et mainteneur principal
- **[Liste des contributeurs](https://github.com/yourorg/scripts-toolkit/graphs/contributors)**

---

## Contact et Support

### Communauté
- 💬 **Discussions GitHub** : [github.com/yourorg/scripts-toolkit/discussions](https://github.com/yourorg/scripts-toolkit/discussions)
- 💬 **Slack** : scripts-toolkit.slack.com
- 📧 **Email** : support@scripts-toolkit.io

### Support Commercial
Pour un support entreprise, formations ou consulting :
- 🌐 **Site web** : https://scripts-toolkit.io
- 📧 **Email** : enterprise@scripts-toolkit.io
- 📞 **Téléphone** : +33 X XX XX XX XX

### Contribuer
Les contributions sont les bienvenues ! Consultez le [Guide du contributeur](CONTRIBUTING.md).

### Rapporter un bug
Ouvrez une issue sur GitHub avec le template approprié.

### Proposer une fonctionnalité
Ouvrez une discussion GitHub pour en discuter avec la communauté.

---

*"La simplicité est la sophistication suprême" - Leonardo da Vinci*

Cette philosophie guide chaque aspect de cette méthodologie : des briques simples et robustes qui s'assemblent pour créer des systèmes sophistiqués et fiables.

**Bonne construction ! 🚀**

---

**Documentation générée le : 2024-10-03**  
**Version du document : 2.0**  
**Dernière mise à jour : 2024-10-03**Cette méthodologie complète fournit un framework professionnel pour le développement de scripts modulaires Shell. Voici ce qui a été couvert :

### 📋 Composants principaux

1. **Architecture modulaire hiérarchique**
   - Scripts atomiques (niveau 0)
   - Orchestrateurs multi-niveaux
   - Bibliothèques partagées

2. **Standards et conventions**
   - Codes de sortie standardisés
   - Format JSON structuré
   - Conventions de nommage
   - Documentation intégrée

3. **Qualité et sécurité**
   - Validation systématique
   - Gestion d'erreurs robuste
   - Audit complet
   - Sandbox d'exécution

4. **Performance**
   - Cache et mémorisation
   - Pool de workers parallèles
   - Retry avec backoff
   - Circuit breaker

5. **CI/CD et DevOps**
   - Tests automatisés
   - Versioning sémantique
   - Packages multi-formats
   - Monitoring complet

### 🛠️ Outils fournis

| Outil | Description |
|-------|-------------|
| `script-generator.sh` | Génère nouveaux scripts depuis templates |
| `custom-linter.sh` | Validation personnalisée des scripts |
| `doc-generator.sh` | Documentation automatique |
| `doc-browser.sh` | Navigateur de documentation CLI |
| `profiler.sh` | Analyse de performance |
| `package-builder.sh` | Construction de packages DEB/RPM/TAR |
| `monitor-daemon.sh` | Monitoring en temps réel |
| `version-manager.sh` | Gestion automatique des versions |

### 📊 Métriques et monitoring

- Collecte automatique des métriques d'exécution
- Dashboards Grafana intégrés
- Alertes Prometheus
- Export InfluxDB
- Notifications multi-canal (Slack, Teams, Email, PagerDuty)

### 🔧 Intégrations

- **APIs REST** : Client HTTP complet
- **Bases de données** : PostgreSQL, MySQL, MongoDB, Redis, SQLite
- **Notifications** : Slack, Discord, Teams, Email, PagerDuty
- **Webhooks** : Support complet

### 📚 Documentation

- Génération automatique depuis le code
- Format Markdown et HTML
- Navigateur interactif CLI
- Exemples et cas d'usage
- Changelog automatique

### 🚀 Déploiement

- Installateur universel
- Packages DEB/RPM
- Archives TAR
- Configuration centralisée
- Tests post-installation

### 💡 Bonnes pratiques implémentées

✅ Principe de responsabilité unique
✅    for func in $functions; do
        local line_num=$(grep -n "^${func}()" "$file" | cut -d: -f1)
        local prev_line=$((line_num - 1))
        local comment=$(sed -n "${prev_line}p" "$file")
        
        if [[ ! "$comment" =~ ^#.*$ ]]; then
            warning "$file: Function '$func' is not documented"
        fi
    done
}

check_logging_usage() {
    local file=$1
    
    # Vérifier que les scripts utilisent le système de logging
    if ! grep -q "source.*logger.sh" "$file"; then
        warning "$file: Not using centralized logging system"
    fi
    
    # Vérifier l'utilisation d'echo au lieu de log_*
    if grep -q "echo.*ERROR" "$file"; then
        warning "$file: Using 'echo' instead of 'log_error'"
    fi
}

check_json_output() {
    local file=$1
    local script_type=""
    
    if [[ "$file" =~ /atomics/ ]]; then
        script_type="atomic"
    elif [[ "$file" =~ /orchestrators/ ]]; then
        script_type="orchestrator"
    fi
    
    if [[ -n "$script_type" ]]; then
        if ! grep -q "build_json_output" "$file"; then
            warning "$file: Not using standard JSON output function"
        fi
    fi
}

check_validation() {
    local file=$1
    
    if ! grep -q "validate_prerequisites" "$file"; then
        warning "$file: No prerequisites validation"
    fi
}

check_cleanup_trap() {
    local file=$1
    
    if ! grep -q "trap cleanup" "$file"; then
        warning "$file: No cleanup trap defined"
    fi
}

check_naming_convention() {
    local file=$1
    local filename=$(basename "$file" .sh)
    
    # Vérifier que le nom suit la convention verbe-objet
    if [[ ! "$filename" =~ ^[a-z]+-[a-z]+(-[a-z]+)*$ ]]; then
        warning "$file: Filename doesn't follow naming convention (verb-object)"
    fi
}

check_permissions() {
    local file=$1
    
    if [[ ! -x "$file" ]]; then
        error "$file: Script is not executable"
    fi
}

check_variable_quotes() {
    local file=$1
    
    # Rechercher des variables non quotées (pattern simple)
    local unquoted=$(grep -E '\$[A-Z_]+[^"\}]' "$file" | grep -v "^\s*#" || true)
    
    if [[ -n "$unquoted" ]]; then
        warning "$file: Potential unquoted variables detected"
    fi
}

check_hardcoded_paths() {
    local file=$1
    
    # Rechercher des chemins en dur
    if grep -qE '/(tmp|var|home)/[^$"]' "$file"; then
        warning "$file: Hardcoded paths detected, consider using variables"
    fi
}

# Linter principal
lint_script() {
    local file=$1
    
    echo "Linting: $file"
    
    check_shebang "$file"
    check_set_options "$file"
    check_header_doc "$file"
    check_exit_codes "$file"
    check_functions_documented "$file"
    check_logging_usage "$file"
    check_json_output "$file"
    check_validation "$file"
    check_cleanup_trap "$file"
    check_naming_convention "$file"
    check_permissions "$file"
    check_variable_quotes "$file"
    check_hardcoded_paths "$file"
    
    echo ""
}

# Point d'entrée
if [[ $# -eq 0 ]]; then
    # Linter tous les scripts
    scripts=(
        "$PROJECT_ROOT"/atomics/*.sh
        "$PROJECT_ROOT"/orchestrators/**/*.sh
    )
else
    scripts=("$@")
fi

for script in "${scripts[@]}"; do
    if [[ -f "$script" ]]; then
        lint_script "$script"
    fi
done

# Rapport final
echo "========================================"
echo "Linting Report"
echo "========================================"
echo -e "${RED}Errors:   $ERRORS${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo "========================================"

if [[ $ERRORS -gt 0 ]]; then
    exit 1
fi

exit 0
```

---

## Déploiement et distribution

### Package Builder

**`tools/package-builder.sh`**

```bash
#!/bin/bash
#
# Script: package-builder.sh
# Description: Construit des packages pour différentes distributions
# Usage: package-builder.sh <format> <version>
#

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
PACKAGE_FORMAT=$1
VERSION=$2

# Validation
if [[ -z "$PACKAGE_FORMAT" ]] || [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <deb|rpm|tar> <version>"
    exit 1
fi

mkdir -p "$BUILD_DIR"

# Construction d'un package DEB
build_deb() {
    local version=$1
    local package_name="scripts-toolkit"
    local deb_dir="$BUILD_DIR/${package_name}_${version}"
    
    echo "Building DEB package for version $version"
    
    # Structure du package
    mkdir -p "$deb_dir"/{DEBIAN,usr/local/bin,usr/local/lib,usr/share/doc/$package_name}
    
    # Copie des fichiers
    cp -r "$PROJECT_ROOT"/atomics/*.sh "$deb_dir/usr/local/bin/"
    cp -r "$PROJECT_ROOT"/lib/*.sh "$deb_dir/usr/local/lib/"
    cp -r "$PROJECT_ROOT"/docs/* "$deb_dir/usr/share/doc/$package_name/"
    
    # Fichier de contrôle
    cat > "$deb_dir/DEBIAN/control" <<EOF
Package: $package_name
Version: $version
Section: utils
Priority: optional
Architecture: all
Depends: bash (>= 4.0), jq, coreutils
Maintainer: Your Name <your.email@example.com>
Description: Modular shell script toolkit
 A collection of atomic scripts and orchestrators
 for system administration and automation.
EOF
    
    # Scripts post-installation
    cat > "$deb_dir/DEBIAN/postinst" <<EOF
#!/bin/bash
set -e

# Rendre les scripts exécutables
chmod +x /usr/local/bin/*.sh

# Créer les répertoires de logs
mkdir -p /var/log/scripts-toolkit

echo "Scripts Toolkit installed successfully!"
EOF
    
    chmod +x "$deb_dir/DEBIAN/postinst"
    
    # Construction du package
    dpkg-deb --build "$deb_dir"
    
    mv "$deb_dir.deb" "$BUILD_DIR/${package_name}_${version}_all.deb"
    rm -rf "$deb_dir"
    
    echo "DEB package created: $BUILD_DIR/${package_name}_${version}_all.deb"
}

# Construction d'un package RPM
build_rpm() {
    local version=$1
    local package_name="scripts-toolkit"
    local rpm_dir="$BUILD_DIR/rpmbuild"
    
    echo "Building RPM package for version $version"
    
    # Structure RPM
    mkdir -p "$rpm_dir"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    
    # Créer le tarball source
    local source_dir="${package_name}-${version}"
    mkdir -p "$rpm_dir/SOURCES/$source_dir"
    
    cp -r "$PROJECT_ROOT"/{atomics,lib,docs} "$rpm_dir/SOURCES/$source_dir/"
    
    tar -czf "$rpm_dir/SOURCES/${package_name}-${version}.tar.gz" \
        -C "$rpm_dir/SOURCES" "$source_dir"
    
    # Fichier spec
    cat > "$rpm_dir/SPECS/${package_name}.spec" <<EOF
Name:           $package_name
Version:        $version
Release:        1%{?dist}
Summary:        Modular shell script toolkit
License:        MIT
URL:            https://github.com/yourorg/scripts-toolkit
Source0:        %{name}-%{version}.tar.gz

Requires:       bash >= 4.0, jq

%description
A collection of atomic scripts and orchestrators
for system administration and automation.

%prep
%setup -q

%install
mkdir -p %{buildroot}/usr/local/bin
mkdir -p %{buildroot}/usr/local/lib
mkdir -p %{buildroot}/usr/share/doc/%{name}

cp -r atomics/*.sh %{buildroot}/usr/local/bin/
cp -r lib/*.sh %{buildroot}/usr/local/lib/
cp -r docs/* %{buildroot}/usr/share/doc/%{name}/

%files
/usr/local/bin/*.sh
/usr/local/lib/*.sh
/usr/share/doc/%{name}/*

%changelog
* $(date +"%a %b %d %Y") Your Name <your.email@example.com> - $version-1
- Version $version release
EOF
    
    # Construction
    rpmbuild --define "_topdir $rpm_dir" -ba "$rpm_dir/SPECS/${package_name}.spec"
    
    cp "$rpm_dir/RPMS/noarch/${package_name}-${version}-1.noarch.rpm" "$BUILD_DIR/"
    
    echo "RPM package created: $BUILD_DIR/${package_name}-${version}-1.noarch.rpm"
}

# Construction d'un tarball
build_tar() {
    local version=$1
    local package_name="scripts-toolkit"
    local archive="${package_name}-${version}.tar.gz"
    
    echo "Building TAR archive for version $version"
    
    local temp_dir="$BUILD_DIR/${package_name}-${version}"
    mkdir -p "$temp_dir"
    
    # Copie de la structure
    cp -r "$PROJECT_ROOT"/{atomics,orchestrators,lib,docs,tests} "$temp_dir/"
    cp "$PROJECT_ROOT"/{README.md,LICENSE,VERSION} "$temp_dir/" 2>/dev/null || true
    
    # Script d'installation
    cat > "$temp_dir/install.sh" <<EOF
#!/bin/bash
set -e

echo "Installing Scripts Toolkit v$version"

INSTALL_DIR=\${1:-/usr/local}

echo "Installing to \$INSTALL_DIR"

mkdir -p "\$INSTALL_DIR"/{bin,lib}

cp atomics/*.sh "\$INSTALL_DIR/bin/"
cp lib/*.sh "\$INSTALL_DIR/lib/"
cp -r orchestrators "\$INSTALL_DIR/lib/"

chmod +x "\$INSTALL_DIR/bin"/*.sh

mkdir -p /var/log/scripts-toolkit

echo "Installation complete!"
echo "Scripts installed in: \$INSTALL_DIR/bin/"
EOF
    
    chmod +x "$temp_dir/install.sh"
    
    # Création de l'archive
    tar -czf "$BUILD_DIR/$archive" -C "$BUILD_DIR" "${package_name}-${version}"
    
    rm -rf "$temp_dir"
    
    echo "TAR archive created: $BUILD_DIR/$archive"
}

# Construction selon le format
case $PACKAGE_FORMAT in
    deb)
        build_deb "$VERSION"
        ;;
    rpm)
        build_rpm "$VERSION"
        ;;
    tar)
        build_tar "$VERSION"
        ;;
    all)
        build_deb "$VERSION"
        build_rpm "$VERSION"
        build_tar "$VERSION"
        ;;
    *)
        echo "Unknown package format: $PACKAGE_FORMAT"
        echo "Supported formats: deb, rpm, tar, all"
        exit 1
        ;;
esac

echo ""
echo "Package building completed!"
echo "Output directory: $BUILD_DIR"
```

### Installateur universel

**`install.sh`**

```bash
#!/bin/bash
#
# Script: install.sh
# Description: Installateur universel pour le toolkit
# Usage: ./install.sh [OPTIONS]
#

set -euo pipefail

INSTALL_DIR="${1:-/usr/local}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════════════╗"
echo "║     Scripts Toolkit Installer                  ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# Vérification des prérequis
echo "Checking prerequisites..."

MISSING_DEPS=()

for cmd in bash jq; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_DEPS+=("$cmd")
    fi
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo "Error: Missing dependencies: ${MISSING_DEPS[*]}"
    echo ""
    echo "Please install them first:"
    echo "  Debian/Ubuntu: sudo apt-get install ${MISSING_DEPS[*]}"
    echo "  RHEL/CentOS:   sudo yum install ${MISSING_DEPS[*]}"
    echo "  Arch:          sudo pacman -S ${MISSING_DEPS[*]}"
    exit 1
fi

echo "✓ All prerequisites satisfied"
echo ""

# Vérification des permissions
if [[ ! -w "$INSTALL_DIR" ]]; then
    echo "Error: No write permission to $INSTALL_DIR"
    echo "Please run with sudo or choose a different installation directory"
    exit 1
fi

# Installation
echo "Installing to: $INSTALL_DIR"
echo ""

# Création des répertoires
echo "Creating directories..."
mkdir -p "$INSTALL_DIR"/{bin,lib/scripts-toolkit}
mkdir -p /var/log/scripts-toolkit
mkdir -p /etc/scripts-toolkit

# Installation des scripts atomiques
echo "Installing atomic scripts..."
cp "$PROJECT_ROOT"/atomics/*.sh "$INSTALL_DIR/bin/"
chmod +x "$INSTALL_DIR/bin"/*.sh

# Installation des bibliothèques
echo "Installing libraries..."
cp "$PROJECT_ROOT"/lib/*.sh "$INSTALL_DIR/lib/scripts-toolkit/"

# Installation des orchestrateurs
echo "Installing orchestrators..."
cp -r "$PROJECT_ROOT/orchestrators" "$INSTALL_DIR/lib/scripts-toolkit/"
find "$INSTALL_DIR/lib/scripts-toolkit/orchestrators" -name "*.sh" -exec chmod +x {} \;

# Configuration par défaut
echo "Creating default configuration..."
cat > /etc/scripts-toolkit/config.sh <<EOF
# Scripts Toolkit Configuration

# Project root
export PROJECT_ROOT="$INSTALL_DIR/lib/scripts-toolkit"

# Logging
export LOG_LEVEL=1  # 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR
export LOG_DIR="/var/log/scripts-toolkit"

# Cache
export CACHE_TTL=3600
export CACHE_DIR="/var/cache/scripts-toolkit"

# Monitoring
export MONITOR_INTERVAL=300

# Notifications (configure as needed)
# export SLACK_WEBHOOK_URL=""
# export NOTIFICATION_EMAIL=""
EOF

# Ajout au PATH
echo "Updating PATH configuration..."
if ! grep -q "$INSTALL_DIR/bin" /etc/profile.d/scripts-toolkit.sh 2>/dev/null; then
    cat > /etc/profile.d/scripts-toolkit.sh <<EOF
# Scripts Toolkit PATH
export PATH="$INSTALL_DIR/bin:\$PATH"
source /etc/scripts-toolkit/config.sh
EOF
fi

# Tests post-installation
echo ""
echo "Running post-installation tests..."

test_count=0
test_passed=0

for script in "$INSTALL_DIR"/bin/*.sh; do
    ((test_count++))
    script_name=$(basename "$script")
    
    if "$script" --help &> /dev/null; then
        echo "✓ $script_name"
        ((test_passed++))
    else
        echo "✗ $script_name"
    fi
done

echo ""
echo "Tests: $test_passed/$test_count passed"
echo ""

# Affichage du résumé
cat <<EOF
╔════════════════════════════════════════════════╗
║          Installation Complete!                ║
╚════════════════════════════════════════════════╝

Installation Details:
  - Scripts:        $INSTALL_DIR/bin/
  - Libraries:      $INSTALL_DIR/lib/scripts-toolkit/
  - Configuration:  /etc/scripts-toolkit/
  - Logs:           /var/log/scripts-toolkit/

Next Steps:
  1. Source your profile or restart your shell:
     source /etc/profile.d/scripts-toolkit.sh
  
  2. Verify installation:
     detect-usb.sh --help
  
  3. Configure notifications (optional):
     sudo nano /etc/scripts-toolkit/config.sh
  
  4. View documentation:
     cat $INSTALL_DIR/lib/scripts-toolkit/docs/INDEX.md

For support, visit: https://github.com/yourorg/scripts-toolkit

EOF
```

---

## Cas d'usage avancés

### Exemple complet : Backup automatisé

**`examples/automated-backup.sh`**

```bash
#!/bin/bash
#
# Script: automated-backup.sh
# Description: Système de backup automatisé complet
# Usage: automated-backup.sh --source <dir> --destination <dir>
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"
source "$PROJECT_ROOT/lib/notifications.sh"
source "$PROJECT_ROOT/lib/retry.sh"

readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1

SOURCE_DIR=""
DEST_DIR=""
RETENTION_DAYS=30
COMPRESS=1
ENCRYPT=0
ENCRYPTION_KEY=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --source)
                SOURCE_DIR="$2"
                shift 2
                ;;
            --destination)
                DEST_DIR="$2"
                shift 2
                ;;
            --retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            --no-compress)
                COMPRESS=0
                shift
                ;;
            --encrypt)
                ENCRYPT=1
                ENCRYPTION_KEY="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                exit $EXIT_ERROR
                ;;
        esac
    done
    
    if [[ -z "$SOURCE_DIR" ]] || [[ -z "$DEST_DIR" ]]; then
        log_error "Source and destination are required"
        exit $EXIT_ERROR
    fi
}

create_backup() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name="backup-${timestamp}"
    local backup_path="$DEST_DIR/$backup_name"
    
    log_info "Starting backup: $SOURCE_DIR -> $backup_path"
    
    # Création du répertoire de backup
    mkdir -p "$backup_path"
    
    # Copie avec rsync
    log_info "Copying files..."
    retry_execute "rsync -av --progress '$SOURCE_DIR/' '$backup_path/'" 3
    
    # Compression
    if [[ $COMPRESS -eq 1 ]]; then
        log_info "Compressing backup..."
        tar -czf "${backup_path}.tar.gz" -C "$DEST_DIR" "$backup_name"
        rm -rf "$backup_path"
        backup_path="${backup_path}.tar.gz"
    fi
    
    # Chiffrement
    if [[ $ENCRYPT -eq 1 ]]; then
        log_info "Encrypting backup..."
        openssl enc -aes-256-cbc -salt -in "$backup_path" \
            -out "${backup_path}.enc" -k "$ENCRYPTION_KEY"
        rm -f "$backup_path"
        backup_path="${backup_path}.enc"
    fi
    
    # Calcul du hash
    local hash=$(sha256sum "$backup_path" | awk '{print $1}')
    
    log_info "Backup created: $backup_path"
    log_info "SHA256: $hash"
    
    echo "$backup_path"
}

verify_backup() {
    local backup_path=$1
    
    log_info "Verifying backup: $backup_path"
    
    if [[ ! -f "$backup_path" ]]; then
        log_error "Backup file not found"
        return 1
    fi
    
    local size=$(stat -c%s "$backup_path")
    log_info "Backup size: $((size / 1024 / 1024)) MB"
    
    # TODO: Ajouter des vérifications supplémentaires
    
    return 0
}

cleanup_old_backups() {
    log_info "Cleaning up backups older than $RETENTION_DAYS days"
    
    find "$DEST_DIR" -name "backup-*" -mtime +$RETENTION_DAYS -delete
    
    local deleted=$(find "$DEST_DIR" -name "backup-*" -mtime +$RETENTION_DAYS | wc -l)
    log_info "Deleted $deleted old backups"
}

send_notification() {
    local status=$1
    local backup_path=$2
    local duration=$3
    
    local message="Backup $status
Source: $SOURCE_DIR
Destination: $backup_path
Duration: ${duration}s"
    
    notify "$status" "Backup Report" "$message" "slack" "email"
}

main() {
    exec 3>&1
    exec 1>&2
    
    log_info "Backup script started"
    
    parse_args "$@"
    
    local start_time=$(date +%s)
    
    # Création du backup
    local backup_path
    if backup_path=$(create_backup); then
        
        # Vérification
        if verify_backup "$backup_path"; then
            
            # Nettoyage
            cleanup_old_backups
            
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            # Notification de succès
            send_notification "success" "$backup_path" "$duration"
            
            # Sortie JSON
            cat >&3 <<EOF
{
  "status": "success",
  "backup_path": "$backup_path",
  "source": "$SOURCE_DIR",
  "duration_seconds": $duration,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
            
            log_info "Backup completed successfully"
            exit $EXIT_SUCCESS
        else
            send_notification "error" "$backup_path" "N/A"
            exit $EXIT_ERROR
        fi
    else
        send_notification "error" "N/A" "N/A"
        exit $EXIT_ERROR
    fi
}

main "$@"
```

### Exemple : Pipeline de traitement de données

**`examples/data-pipeline.sh`**

```bash
#!/bin/bash
#
# Script: data-pipeline.sh
# Description: Pipeline de traitement de données ETL
# Usage: data-pipeline.sh --input <file> --output <dir>
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logger.sh"
source "$PROJECT_ROOT/lib/worker-pool.sh"
source "$PROJECT_ROOT/lib/database.sh"

INPUT_FILE=""
OUTPUT_DIR=""
DB_HOST="localhost"
DB_PORT=5432
DB_NAME="analytics"
DB_USER="etl_user"
DB_PASS=""

# Extract
extract_data() {
    local input=$1
    
    log_info "Extracting data from: $input"
    
    # Détection du format
    local format=$(file --mime-type -b "$input")
    
    case $format in
        application/json)
            jq -c '.[]' "$input"
            ;;
        text/csv)
            # Convertir CSV en JSON
            python3 -c "
import csv, json, sys
reader = csv.DictReader(open('$input'))
for row in reader:
    print(json.dumps(row))
"
            ;;
        *)
            log_error "Unsupported format: $format"
            return 1
            ;;
    esac
}

# Transform
transform_data() {
    local record=$1
    
    # Nettoyage et transformation
    echo "$record" | jq -c '
        .timestamp = (.timestamp | tonumber),
        .value = (.value | tonumber),
        .processed_at = now
    '
}

# Load
load_data() {
    local record=$1
    
    # Insertion dans la base de données
    local query="INSERT INTO processed_data (data) VALUES ('$record')"
    db_postgres_query "$DB_HOST" "$DB_PORT" "$DB_NAME" "$DB_USER" "$DB_PASS" "$query"
}

# Pipeline principal
run_pipeline() {
    log_info "Starting ETL pipeline"
    
    local total=0
    local processed=0
    local errors=0
    
    # Extract et Transform en parallèle
    worker_pool_init
    
    while IFS= read -r record; do
        ((total++))
        
        # Soumettre au pool de workers
        worker_pool_submit "record-$total" \
            "bash" "-c" "echo '$record' | $0 transform"
        
        # Limiter le nombre de jobs en parallèle
        if [[ $((total % WORKER_POOL_SIZE)) -eq 0 ]]; then
            worker_pool_execute
            worker_pool_init
        fi
    done < <(extract_data "$INPUT_FILE")
    
    # Exécuter les derniers jobs
    worker_pool_execute
    
    # Load des résultats
    for i in $(seq 1 $total); do
        local result=$(worker_pool_get_result "record-$i")
        local exit_code=$(echo "$result" | jq -r '.exit_code')
        
        if [[ $exit_code -eq 0 ]]; then
            local transformed=$(echo "$result" | jq -r '.output')
            if load_data "$transformed"; then
                ((processed++))
            else
                ((errors++))
            fi
        else
            ((errors++))
        fi
    done
    
    worker_pool_cleanup
    
    log_info "Pipeline completed: $processed/$total processed, $errors errors"
    
    cat <<EOF
{
  "total_records": $total,
  "processed": $processed,
  "errors": $errors,
  "success_rate": $(echo "scale=2; ($processed / $total) * 100" | bc)
}
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --input)
                INPUT_FILE="$2"
                shift 2
                ;;
            --output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --db-host)
                DB_HOST="$2"
                shift 2
                ;;
            --db-pass)
                DB_PASS="$2"
                shift 2
                ;;
            transform)
                # Mode transform pour worker
                cat | transform_data
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
}

main() {
    parse_args "$@"
    
    if [[ -z "$INPUT_FILE" ]]; then
        log_error "Input file required"
        exit 1
    fi
    
    run_pipeline
}

main "$@"
```

---

## Conclusion et ressources

### Récapitulatif complet

Cette méthodologie complète fournit un framework professionnel pour le développement de scripts modulaires    "severity": "$severity",
    "source": "$(hostname)",
    "custom_details": $details
  }
}
EOF
)
    
    curl -X POST -H 'Content-type: application/json' \
        --data "$payload" "https://events.pagerduty.com/v2/enqueue" 2>/dev/null
}

# Notification générique (multi-canal)
notify() {
    local level=$1
    local title=$2
    local message=$3
    shift 3
    local channels=("$@")
    
    for channel in "${channels[@]}"; do
        case $channel in
            slack)
                [[ -n "${SLACK_WEBHOOK_URL:-}" ]] && notify_slack "$SLACK_WEBHOOK_URL" "$title: $message" "$level"
                ;;
            email)
                [[ -n "${NOTIFICATION_EMAIL:-}" ]] && notify_email "$NOTIFICATION_EMAIL" "$title" "$message"
                ;;
            discord)
                [[ -n "${DISCORD_WEBHOOK_URL:-}" ]] && notify_discord "$DISCORD_WEBHOOK_URL" "$title: $message"
                ;;
            teams)
                [[ -n "${TEAMS_WEBHOOK_URL:-}" ]] && notify_teams "$TEAMS_WEBHOOK_URL" "$title" "$message" "$level"
                ;;
            pagerduty)
                [[ -n "${PAGERDUTY_ROUTING_KEY:-}" ]] && notify_pagerduty "$PAGERDUTY_ROUTING_KEY" "$level" "$title" "{\"message\": \"$message\"}"
                ;;
        esac
    done
}
```

### Intégration API REST

**`lib/api-client.sh`**

```bash
#!/bin/bash
#
# Bibliothèque: api-client.sh
# Description: Client API REST générique
#

API_BASE_URL=${API_BASE_URL:-""}
API_TIMEOUT=${API_TIMEOUT:-30}
API_RETRY_ATTEMPTS=${API_RETRY_ATTEMPTS:-3}

# Requête GET
api_get() {
    local endpoint=$1
    local headers=${2:-""}
    
    local url="${API_BASE_URL}${endpoint}"
    
    log_debug "API GET: $url"
    
    local curl_cmd="curl -s -w '\n%{http_code}' -X GET"
    curl_cmd+=" --max-time $API_TIMEOUT"
    
    if [[ -n "$headers" ]]; then
        while IFS='|' read -r header; do
            curl_cmd+=" -H '$header'"
        done <<< "$headers"
    fi
    
    curl_cmd+=" '$url'"
    
    local response
    response=$(eval "$curl_cmd")
    
    local http_code=$(echo "$response" | tail -1)
    local body=$(echo "$response" | sed '$d')
    
    if [[ $http_code -ge 200 ]] && [[ $http_code -lt 300 ]]; then
        echo "$body"
        return 0
    else
        log_error "API GET failed: HTTP $http_code"
        echo "$body" >&2
        return 1
    fi
}

# Requête POST
api_post() {
    local endpoint=$1
    local data=$2
    local headers=${3:-"Content-Type: application/json"}
    
    local url="${API_BASE_URL}${endpoint}"
    
    log_debug "API POST: $url"
    
    local curl_cmd="curl -s -w '\n%{http_code}' -X POST"
    curl_cmd+=" --max-time $API_TIMEOUT"
    curl_cmd+=" -d '$data'"
    
    while IFS='|' read -r header; do
        curl_cmd+=" -H '$header'"
    done <<< "$headers"
    
    curl_cmd+=" '$url'"
    
    local response
    response=$(eval "$curl_cmd")
    
    local http_code=$(echo "$response" | tail -1)
    local body=$(echo "$response" | sed '$d')
    
    if [[ $http_code -ge 200 ]] && [[ $http_code -lt 300 ]]; then
        echo "$body"
        return 0
    else
        log_error "API POST failed: HTTP $http_code"
        echo "$body" >&2
        return 1
    fi
}

# Requête PUT
api_put() {
    local endpoint=$1
    local data=$2
    local headers=${3:-"Content-Type: application/json"}
    
    local url="${API_BASE_URL}${endpoint}"
    
    log_debug "API PUT: $url"
    
    local response=$(curl -s -w '\n%{http_code}' -X PUT \
        --max-time "$API_TIMEOUT" \
        -H "$headers" \
        -d "$data" \
        "$url")
    
    local http_code=$(echo "$response" | tail -1)
    local body=$(echo "$response" | sed '$d')
    
    if [[ $http_code -ge 200 ]] && [[ $http_code -lt 300 ]]; then
        echo "$body"
        return 0
    else
        log_error "API PUT failed: HTTP $http_code"
        echo "$body" >&2
        return 1
    fi
}

# Requête DELETE
api_delete() {
    local endpoint=$1
    local headers=${2:-""}
    
    local url="${API_BASE_URL}${endpoint}"
    
    log_debug "API DELETE: $url"
    
    local curl_cmd="curl -s -w '\n%{http_code}' -X DELETE"
    curl_cmd+=" --max-time $API_TIMEOUT"
    
    if [[ -n "$headers" ]]; then
        while IFS='|' read -r header; do
            curl_cmd+=" -H '$header'"
        done <<< "$headers"
    fi
    
    curl_cmd+=" '$url'"
    
    local response
    response=$(eval "$curl_cmd")
    
    local http_code=$(echo "$response" | tail -1)
    local body=$(echo "$response" | sed '$d')
    
    if [[ $http_code -ge 200 ]] && [[ $http_code -lt 300 ]]; then
        echo "$body"
        return 0
    else
        log_error "API DELETE failed: HTTP $http_code"
        echo "$body" >&2
        return 1
    fi
}

# Authentification OAuth2
api_oauth2_token() {
    local token_url=$1
    local client_id=$2
    local client_secret=$3
    local scope=${4:-""}
    
    local data="grant_type=client_credentials&client_id=$client_id&client_secret=$client_secret"
    [[ -n "$scope" ]] && data+="&scope=$scope"
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "$data" \
        "$token_url")
    
    echo "$response" | jq -r '.access_token'
}
```

### Intégration avec bases de données

**`lib/database.sh`**

```bash
#!/bin/bash
#
# Bibliothèque: database.sh
# Description: Interaction avec différentes bases de données
#

# PostgreSQL
db_postgres_query() {
    local host=$1
    local port=$2
    local database=$3
    local user=$4
    local password=$5
    local query=$6
    
    PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$database" \
        -t -A -F'|' -c "$query" 2>/dev/null
}

db_postgres_execute() {
    local host=$1
    local port=$2
    local database=$3
    local user=$4
    local password=$5
    local sql_file=$6
    
    PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$database" \
        -f "$sql_file" 2>/dev/null
}

# MySQL/MariaDB
db_mysql_query() {
    local host=$1
    local port=$2
    local database=$3
    local user=$4
    local password=$5
    local query=$6
    
    mysql -h "$host" -P "$port" -u "$user" -p"$password" -D "$database" \
        -s -N -e "$query" 2>/dev/null
}

db_mysql_execute() {
    local host=$1
    local port=$2
    local database=$3
    local user=$4
    local password=$5
    local sql_file=$6
    
    mysql -h "$host" -P "$port" -u "$user" -p"$password" -D "$database" \
        < "$sql_file" 2>/dev/null
}

# SQLite
db_sqlite_query() {
    local db_file=$1
    local query=$2
    
    sqlite3 "$db_file" "$query" 2>/dev/null
}

db_sqlite_execute() {
    local db_file=$1
    local sql_file=$2
    
    sqlite3 "$db_file" < "$sql_file" 2>/dev/null
}

# MongoDB
db_mongo_query() {
    local host=$1
    local port=$2
    local database=$3
    local collection=$4
    local query=$5
    
    mongo --host "$host" --port "$port" "$database" \
        --eval "db.$collection.find($query).forEach(printjson)" \
        --quiet 2>/dev/null
}

db_mongo_insert() {
    local host=$1
    local port=$2
    local database=$3
    local collection=$4
    local document=$5
    
    mongo --host "$host" --port "$port" "$database" \
        --eval "db.$collection.insertOne($document)" \
        --quiet 2>/dev/null
}

# Redis
db_redis_get() {
    local host=$1
    local port=$2
    local key=$3
    
    redis-cli -h "$host" -p "$port" GET "$key" 2>/dev/null
}

db_redis_set() {
    local host=$1
    local port=$2
    local key=$3
    local value=$4
    local ttl=${5:-0}
    
    if [[ $ttl -gt 0 ]]; then
        redis-cli -h "$host" -p "$port" SETEX "$key" "$ttl" "$value" 2>/dev/null
    else
        redis-cli -h "$host" -p "$port" SET "$key" "$value" 2>/dev/null
    fi
}

# Helper : Export de résultats vers JSON
db_result_to_json() {
    local delimiter=${1:-"|"}
    local has_header=${2:-true}
    
    local headers=()
    local first=true
    
    echo "["
    
    while IFS="$delimiter" read -r line; do
        if $first && $has_header; then
            IFS="$delimiter" read -ra headers <<< "$line"
            first=false
            continue
        fi
        
        if ! $first; then
            echo ","
        fi
        first=false
        
        IFS="$delimiter" read -ra values <<< "$line"
        
        echo -n "{"
        for i in "${!headers[@]}"; do
            if [[ $i -gt 0 ]]; then echo -n ","; fi
            echo -n "\"${headers[$i]}\": \"${values[$i]}\""
        done
        echo -n "}"
    done
    
    echo "]"
}
```

---

## Documentation interactive

### Générateur de documentation

**`tools/doc-generator.sh`**

```bash
#!/bin/bash
#
# Script: doc-generator.sh
# Description: Génère automatiquement la documentation à partir des scripts
# Usage: doc-generator.sh [OPTIONS]
#

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC_OUTPUT_DIR="${PROJECT_ROOT}/docs/generated"

mkdir -p "$DOC_OUTPUT_DIR"

# Extraction de la documentation d'un script
extract_script_doc() {
    local script=$1
    local script_name=$(basename "$script")
    
    # Extraire l'en-tête de documentation
    local doc=$(sed -n '/^# Script:/,/^$/p' "$script" | sed 's/^# \?//')
    
    if [[ -z "$doc" ]]; then
        return 1
    fi
    
    echo "$doc"
}

# Extraction des fonctions d'un script
extract_functions() {
    local script=$1
    
    grep -E "^[a-zA-Z_][a-zA-Z0-9_]*\(\)" "$script" | sed 's/().*$//' | while read -r func; do
        # Extraire la description de la fonction
        local line_num=$(grep -n "^${func}()" "$script" | cut -d: -f1)
        local desc=$(sed -n "$((line_num - 1))p" "$script" | sed 's/^# \?//')
        
        echo "- \`$func()\`: $desc"
    done
}

# Extraction des variables d'environnement
extract_env_vars() {
    local script=$1
    
    grep -E "^[A-Z_]+=" "$script" | cut -d= -f1 | sort -u | while read -r var; do
        local default=$(grep "^${var}=" "$script" | head -1 | cut -d= -f2- | sed 's/[\${}]//g')
        echo "- \`$var\`: ${default:-"(no default)"}"
    done
}

# Génération de la documentation pour un script atomique
generate_atomic_doc() {
    local script=$1
    local script_name=$(basename "$script" .sh)
    local output_file="$DOC_OUTPUT_DIR/atomics/${script_name}.md"
    
    mkdir -p "$(dirname "$output_file")"
    
    cat > "$output_file" <<EOF
# $script_name

$(extract_script_doc "$script")

## Functions

$(extract_functions "$script")

## Environment Variables

$(extract_env_vars "$script")

## Dependencies

\`\`\`bash
$(grep -E "source.*lib/" "$script" | sed 's/.*source.*lib\//- lib\//')
\`\`\`

## Example Usage

\`\`\`bash
# Basic usage
./$script_name.sh

# With options
./$script_name.sh --verbose --debug
\`\`\`

## Generated

This documentation was automatically generated on $(date +"%Y-%m-%d %H:%M:%S").
EOF

    echo "Generated: $output_file"
}

# Génération de la documentation pour tous les scripts
generate_all_docs() {
    echo "Generating documentation for atomic scripts..."
    
    for script in "$PROJECT_ROOT"/atomics/*.sh; do
        if [[ -f "$script" ]]; then
            generate_atomic_doc "$script"
        fi
    done
    
    echo "Generating documentation for orchestrators..."
    
    find "$PROJECT_ROOT/orchestrators" -name "*.sh" -type f | while read -r script; do
        generate_atomic_doc "$script"
    done
    
    # Génération de l'index
    generate_index
}

# Génération de l'index de documentation
generate_index() {
    local index_file="$DOC_OUTPUT_DIR/INDEX.md"
    
    cat > "$index_file" <<EOF
# Scripts Documentation Index

Generated on $(date +"%Y-%m-%d %H:%M:%S")

## Atomic Scripts

EOF

    for doc in "$DOC_OUTPUT_DIR"/atomics/*.md; do
        if [[ -f "$doc" ]]; then
            local name=$(basename "$doc" .md)
            local description=$(grep "^Description:" "$doc" | sed 's/Description: //')
            echo "- [$name](atomics/$name.md): $description" >> "$index_file"
        fi
    done
    
    cat >> "$index_file" <<EOF

## Orchestrators

EOF

    find "$DOC_OUTPUT_DIR/orchestrators" -name "*.md" -type f | while read -r doc; do
        local name=$(basename "$doc" .md)
        local description=$(grep "^Description:" "$doc" | sed 's/Description: //')
        local rel_path=${doc#$DOC_OUTPUT_DIR/}
        echo "- [$name]($rel_path): $description" >> "$index_file"
    done
    
    echo "Index generated: $index_file"
}

# Génération de documentation HTML
generate_html_docs() {
    echo "Generating HTML documentation..."
    
    if ! command -v pandoc &> /dev/null; then
        log_error "pandoc is required for HTML generation"
        return 1
    fi
    
    local html_dir="$DOC_OUTPUT_DIR/html"
    mkdir -p "$html_dir"
    
    # Générer HTML pour chaque fichier MD
    find "$DOC_OUTPUT_DIR" -name "*.md" -type f | while read -r md_file; do
        local rel_path=${md_file#$DOC_OUTPUT_DIR/}
        local html_file="$html_dir/${rel_path%.md}.html"
        
        mkdir -p "$(dirname "$html_file")"
        
        pandoc "$md_file" -s --toc -c style.css -o "$html_file"
        echo "Generated: $html_file"
    done
    
    # Créer une feuille de style
    cat > "$html_dir/style.css" <<EOF
body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
    line-height: 1.6;
    max-width: 900px;
    margin: 0 auto;
    padding: 20px;
    color: #333;
}

code {
    background-color: #f4f4f4;
    padding: 2px 6px;
    border-radius: 3px;
    font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
}

pre {
    background-color: #f4f4f4;
    padding: 15px;
    border-radius: 5px;
    overflow-x: auto;
}

pre code {
    background-color: transparent;
    padding: 0;
}

h1, h2, h3 {
    color: #2c3e50;
    border-bottom: 1px solid #e0e0e0;
    padding-bottom: 10px;
}

a {
    color: #3498db;
    text-decoration: none;
}

a:hover {
    text-decoration: underline;
}

table {
    border-collapse: collapse;
    width: 100%;
    margin: 20px 0;
}

th, td {
    border: 1px solid #ddd;
    padding: 12px;
    text-align: left;
}

th {
    background-color: #f4f4f4;
}
EOF

    echo "HTML documentation generated in: $html_dir"
}

# Point d'entrée
case ${1:-all} in
    all)
        generate_all_docs
        ;;
    html)
        generate_html_docs
        ;;
    index)
        generate_index
        ;;
    *)
        echo "Usage: $0 {all|html|index}"
        exit 1
        ;;
esac
```

### Documentation interactive en ligne de commande

**`tools/doc-browser.sh`**

```bash
#!/bin/bash
#
# Script: doc-browser.sh
# Description: Navigateur de documentation interactif en CLI
# Usage: doc-browser.sh
#

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_DIR="${PROJECT_ROOT}/docs"

# Afficher le menu principal
show_main_menu() {
    clear
    cat <<EOF
╔════════════════════════════════════════════════╗
║        Script Documentation Browser            ║
╚════════════════════════════════════════════════╝

1. Browse Atomic Scripts
2. Browse Orchestrators
3. Search Documentation
4. View Recent Changes
5. Exit

Enter your choice: 
EOF
}

# Lister les scripts atomiques
list_atomics() {
    clear
    echo "=== Atomic Scripts ==="
    echo ""
    
    local i=1
    local scripts=()
    
    for script in "$PROJECT_ROOT"/atomics/*.sh; do
        local name=$(basename "$script" .sh)
        scripts+=("$name")
        echo "$i. $name"
        ((i++))
    done
    
    echo ""
    echo "0. Back to main menu"
    echo ""
    read -p "Select a script to view documentation: " choice
    
    if [[ $choice -eq 0 ]]; then
        return
    elif [[ $choice -ge 1 ]] && [[ $choice -le ${#scripts[@]} ]]; then
        show_script_doc "atomics" "${scripts[$((choice-1))]}"
    fi
}

# Afficher la documentation d'un script
show_script_doc() {
    local type=$1
    local name=$2
    local doc_file="$DOCS_DIR/$type/${name}.md"
    
    if [[ ! -f "$doc_file" ]]; then
        doc_file="$DOCS_DIR/generated/$type/${name}.md"
    fi
    
    if [[ -f "$doc_file" ]]; then
        clear
        if command -v bat &> /dev/null; then
            bat --style=plain "$doc_file"
        elif command -v less &> /dev/null; then
            less "$doc_file"
        else
            cat "$doc_file"
        fi
    else
        echo "Documentation not found for: $name"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Recherche dans la documentation
search_docs() {
    clear
    echo "=== Search Documentation ==="
    echo ""
    read -p "Enter search term: " term
    
    if [[ -z "$term" ]]; then
        return
    fi
    
    echo ""
    echo "Search results for '$term':"
    echo "=============================="
    
    grep -r -i -n "$term" "$DOCS_DIR" --include="*.md" | while IFS=: read -r file line content; do
        local rel_file=${file#$DOCS_DIR/}
        echo ""
        echo "File: $rel_file (line $line)"
        echo "  $content"
    done
    
    echo ""
    read -p "Press Enter to continue..."
}

# Afficher les changements récents
show_recent_changes() {
    clear
    echo "=== Recent Changes ==="
    echo ""
    
    if [[ -f "$PROJECT_ROOT/CHANGELOG.md" ]]; then
        head -50 "$PROJECT_ROOT/CHANGELOG.md"
    else
        echo "No changelog found."
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Boucle principale
main() {
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1)
                list_atomics
                ;;
            2)
                # list_orchestrators (similar implementation)
                echo "Orchestrators browser - TODO"
                read -p "Press Enter to continue..."
                ;;
            3)
                search_docs
                ;;
            4)
                show_recent_changes
                ;;
            5)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid choice"
                sleep 1
                ;;
        esac
    done
}

main
```

---

## Outils de développement

### Générateur de scripts

**`tools/script-generator.sh`**

```bash
#!/bin/bash
#
# Script: script-generator.sh
# Description: Génère un nouveau script à partir des templates
# Usage: script-generator.sh <type> <name>
#

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SCRIPT_TYPE=$1
SCRIPT_NAME=$2

# Validation des paramètres
if [[ -z "$SCRIPT_TYPE" ]] || [[ -z "$SCRIPT_NAME" ]]; then
    echo "Usage: $0 <atomic|orchestrator> <script-name>"
    exit 1
fi

# Génération d'un script atomique
generate_atomic() {
    local name=$1
    local script_file="$PROJECT_ROOT/atomics/${name}.sh"
    local test_file="$PROJECT_ROOT/tests/atomics/test-${name}.sh"
    local doc_file="$PROJECT_ROOT/docs/atomics/${name}.md"
    
    if [[ -f "$script_file" ]]; then
        echo "Error: Script already exists: $script_file"
        exit 1
    fi
    
    echo "Creating atomic script: $name"
    
    # Copier le template
    cp "$PROJECT_ROOT/atomics/template-atomic.sh" "$script_file"
    
    # Personnaliser le template
    sed -i "s/template-atomic/$name/g" "$script_file"
    
    # Créer le test
    cat > "$test_file" <<EOF
#!/bin/bash
# Test: $name.sh

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="\$(cd "\$SCRIPT_DIR/../.." && pwd)"

source "\$SCRIPT_DIR/../lib/test-framework.sh"

SCRIPT_UNDER_TEST="\$PROJECT_ROOT/atomics/$name.sh"

echo "Testing: $name.sh"
echo "================================"

# Add your tests here

test_report
EOF
    
    chmod +x "$test_file"
    
    # Créer la documentation
    cat > "$doc_file" <<EOF
# $name.sh

## Description
TODO: Add description

## Usage
\`\`\`bash
./$name.sh [OPTIONS]
\`\`\`

## Options
TODO: Add options

## Examples
TODO: Add examples
EOF
    
    chmod +x "$script_file"
    
    echo "✓ Script created: $script_file"
    echo "✓ Test created: $test_file"
    echo "✓ Documentation created: $doc_file"
    echo ""
    echo "Next steps:"
    echo "  1. Edit $script_file to implement your logic"
    echo "  2. Write tests in $test_file"
    echo "  3. Complete documentation in $doc_file"
}

# Génération d'un orchestrateur
generate_orchestrator() {
    local name=$1
    local level=${3:-1}
    local script_file="$PROJECT_ROOT/orchestrators/level-${level}/${name}.sh"
    local test_file="$PROJECT_ROOT/tests/orchestrators/level-${level}/test-${name}.sh"
    local doc_file="$PROJECT_ROOT/docs/orchestrators/${name}.md"
    
    mkdir -p "$(dirname "$script_file")"
    mkdir -p "$(dirname "$test_file")"
    
    if [[ -f "$script_file" ]]; then
        echo "Error: Script already exists: $script_file"
        exit 1
    fi
    
    echo "Creating orchestrator: $name (level $level)"
    
    # Copier le template
    cp "$PROJECT_ROOT/orchestrators/template-orchestrator.sh" "$script_file"
    
    # Personnaliser
    sed -i "s/template-orchestrator/$name/g" "$script_file"
    
    chmod +x "$script_file"
    
    # Créer le test (similaire à atomic)
    cat > "$test_file" <<EOF
#!/bin/bash
# Test: $name.sh

# TODO: Add integration tests
EOF
    
    chmod +x "$test_file"
    
    # Créer la documentation
    cat > "$doc_file" <<EOF
# $name.sh

## Description
TODO: Add description

## Dependencies
TODO: List atomic scripts and orchestrators used

## Architecture
TODO: Add flow diagram

## Usage
\`\`\`bash
./$name.sh [OPTIONS]
\`\`\`
EOF
    
    echo "✓ Orchestrator created: $script_file"
    echo "✓ Test created: $test_file"
    echo "✓ Documentation created: $doc_file"
}

# Exécution
case $SCRIPT_TYPE in
    atomic)
        generate_atomic "$SCRIPT_NAME"
        ;;
    orchestrator)
        generate_orchestrator "$SCRIPT_NAME"
        ;;
    *)
        echo "Invalid script type: $SCRIPT_TYPE"
        echo "Usage: $0 <atomic|orchestrator> <script-name>"
        exit 1
        ;;
esac
```

### Linter personnalisé

**`tools/custom-linter.sh`**

```bash
#!/bin/bash
#
# Script: custom-linter.sh
# Description: Linter personnalisé pour valider les scripts du projet
# Usage: custom-linter.sh [script...]
#

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ERRORS=0
WARNINGS=0

# Couleurs
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

error() {
    echo -e "${RED}[ERROR]${NC} $*"
    ((ERRORS++))
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
    ((WARNINGS++))
}

info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

# Vérifications
check_shebang() {
    local file=$1
    local first_line=$(head -1 "$file")
    
    if [[ "$first_line" != "#!/bin/bash" ]]; then
        error "$file: Invalid or missing shebang"
    fi
}

check_set_options() {
    local file=$1
    
    if ! grep -q "set -euo pipefail" "$file"; then
        warning "$file: Missing 'set -euo pipefail'"
    fi
}

check_header_doc() {
    local file=$1
    
    if ! grep -q "^# Script:" "$file"; then
        error "$file: Missing header documentation"
    fi
    
    if ! grep -q "^# Description:" "$file"; then
        warning "$file: Missing description in header"
    fi
    
    if ! grep -q "^# Usage:" "$file"; then
        warning "$file: Missing usage in header"
    fi
}

check_exit_codes() {
    local file=$1
    
    if ! grep -q "readonly EXIT_SUCCESS=0" "$file"; then
        warning "$file: Exit codes constants not defined"
    fi
}

check_functions_documented() {
    local file=$1
    
    local functions=$(grep -E "^[a-zA-Z_][a-zA-Z0-9_]*\(\)" "$file" | sed 's/().*$//' || true)
    
    for func in $# Méthodologie de Développement Modulaire - Partie 2

## Patterns avancés et optimisations

### Pattern : Cache et mémorisation

Pour les scripts atomiques fréquemment appelés avec les mêmes paramètres, implémenter un système de cache peut améliorer significativement les performances.

**`lib/cache.sh`**

```bash
#!/bin/bash
#
# Bibliothèque: cache.sh
# Description: Système de cache pour résultats de scripts
#

CACHE_DIR="${PROJECT_ROOT}/.cache"
CACHE_TTL=${CACHE_TTL:-3600}  # 1 heure par défaut

# Initialisation du cache
init_cache() {
    mkdir -p "$CACHE_DIR"
    log_debug "Cache initialized at $CACHE_DIR"
}

# Génération de clé de cache
cache_key() {
    local script_name=$1
    shift
    local params="$*"
    echo -n "${script_name}${params}" | md5sum | awk '{print $1}'
}

# Vérification de l'existence et de la validité du cache
cache_exists() {
    local key=$1
    local cache_file="$CACHE_DIR/$key.json"
    
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    # Vérifier l'âge du cache
    local cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file")))
    if [[ $cache_age -gt $CACHE_TTL ]]; then
        log_debug "Cache expired for key: $key (age: ${cache_age}s)"
        return 1
    fi
    
    log_debug "Cache hit for key: $key"
    return 0
}

# Récupération depuis le cache
cache_get() {
    local key=$1
    local cache_file="$CACHE_DIR/$key.json"
    cat "$cache_file"
}

# Mise en cache
cache_set() {
    local key=$1
    local data=$2
    local cache_file="$CACHE_DIR/$key.json"
    
    echo "$data" > "$cache_file"
    log_debug "Cache set for key: $key"
}

# Invalidation du cache
cache_invalidate() {
    local pattern=${1:-"*"}
    find "$CACHE_DIR" -name "${pattern}.json" -delete
    log_debug "Cache invalidated for pattern: $pattern"
}

# Nettoyage du cache expiré
cache_cleanup() {
    log_info "Cleaning up expired cache entries"
    local count=0
    
    while IFS= read -r file; do
        local age=$(($(date +%s) - $(stat -c %Y "$file")))
        if [[ $age -gt $CACHE_TTL ]]; then
            rm -f "$file"
            ((count++))
        fi
    done < <(find "$CACHE_DIR" -name "*.json")
    
    log_info "Cleaned up $count expired cache entries"
}
```

**Exemple d'utilisation du cache dans un script :**

```bash
#!/bin/bash
# detect-usb-cached.sh - Version avec cache de detect-usb.sh

source "$PROJECT_ROOT/lib/cache.sh"

main() {
    init_cache
    
    # Génération de la clé de cache
    local cache_key=$(cache_key "detect-usb" "$@")
    
    # Vérifier si le résultat est en cache
    if cache_exists "$cache_key"; then
        log_info "Returning cached result"
        cache_get "$cache_key" >&3
        exit $EXIT_SUCCESS
    fi
    
    # Sinon, exécuter normalement
    local result=$(detect_usb_devices)
    
    # Mettre en cache
    cache_set "$cache_key" "$result"
    
    echo "$result" >&3
    exit $EXIT_SUCCESS
}
```

### Pattern : Pool de workers

Pour les orchestrateurs qui doivent exécuter plusieurs scripts en parallèle, implémenter un pool de workers.

**`lib/worker-pool.sh`**

```bash
#!/bin/bash
#
# Bibliothèque: worker-pool.sh
# Description: Pool de workers pour exécution parallèle
#

WORKER_POOL_SIZE=${WORKER_POOL_SIZE:-4}
WORKER_JOBS_DIR="/tmp/worker-jobs-$$"
WORKER_RESULTS_DIR="/tmp/worker-results-$$"

# Initialisation du pool
worker_pool_init() {
    mkdir -p "$WORKER_JOBS_DIR" "$WORKER_RESULTS_DIR"
    log_info "Worker pool initialized (size: $WORKER_POOL_SIZE)"
}

# Ajout d'un job au pool
worker_pool_submit() {
    local job_id=$1
    local script=$2
    shift 2
    local args=("$@")
    
    local job_file="$WORKER_JOBS_DIR/${job_id}.job"
    
    cat > "$job_file" <<EOF
#!/bin/bash
SCRIPT="$script"
ARGS=(${args[@]})
RESULT_FILE="$WORKER_RESULTS_DIR/${job_id}.result"

# Exécution
"\$SCRIPT" "\${ARGS[@]}" > "\$RESULT_FILE" 2>&1
echo \$? > "\$RESULT_FILE.exitcode"
EOF
    
    chmod +x "$job_file"
    log_debug "Job submitted: $job_id"
}

# Exécution du pool
worker_pool_execute() {
    log_info "Executing worker pool"
    
    local jobs=("$WORKER_JOBS_DIR"/*.job)
    local total=${#jobs[@]}
    local completed=0
    
    # Exécution en parallèle avec limitation
    printf '%s\n' "${jobs[@]}" | xargs -P "$WORKER_POOL_SIZE" -I {} bash {}
    
    log_info "Worker pool execution completed"
}

# Récupération des résultats
worker_pool_get_result() {
    local job_id=$1
    local result_file="$WORKER_RESULTS_DIR/${job_id}.result"
    local exitcode_file="${result_file}.exitcode"
    
    if [[ ! -f "$result_file" ]]; then
        log_error "Result not found for job: $job_id"
        return 1
    fi
    
    local exitcode=$(cat "$exitcode_file")
    local output=$(cat "$result_file")
    
    cat <<EOF
{
  "job_id": "$job_id",
  "exit_code": $exitcode,
  "output": $(echo "$output" | jq -Rs .)
}
EOF
}

# Nettoyage du pool
worker_pool_cleanup() {
    rm -rf "$WORKER_JOBS_DIR" "$WORKER_RESULTS_DIR"
    log_debug "Worker pool cleaned up"
}
```

**Exemple d'orchestrateur avec pool de workers :**

```bash
#!/bin/bash
# parallel-disk-setup.sh - Configuration parallèle de plusieurs disques

source "$PROJECT_ROOT/lib/worker-pool.sh"

main() {
    local disks=("/dev/sdb" "/dev/sdc" "/dev/sdd")
    
    worker_pool_init
    
    # Soumettre les jobs
    for i in "${!disks[@]}"; do
        worker_pool_submit "disk-$i" \
            "$PROJECT_ROOT/orchestrators/level-1/setup-disk.sh" \
            "--device" "${disks[$i]}" \
            "--filesystem" "ext4"
    done
    
    # Exécuter en parallèle
    worker_pool_execute
    
    # Collecter les résultats
    local results="["
    for i in "${!disks[@]}"; do
        if [[ $i -gt 0 ]]; then results+=","; fi
        results+=$(worker_pool_get_result "disk-$i")
    done
    results+="]"
    
    worker_pool_cleanup
    
    # Sortie JSON agrégée
    cat <<EOF
{
  "status": "success",
  "disks_configured": ${#disks[@]},
  "results": $results
}
EOF
}
```

---

## Sécurité renforcée

### Pattern : Sandbox d'exécution

Pour isoler l'exécution des scripts et limiter les risques.

**`lib/sandbox.sh`**

```bash
#!/bin/bash
#
# Bibliothèque: sandbox.sh
# Description: Exécution sécurisée dans un environnement sandboxé
#

SANDBOX_ROOT="/tmp/sandbox-$$"
SANDBOX_ALLOWED_DIRS=("/tmp" "/var/tmp")
SANDBOX_ALLOWED_CMDS=("cat" "echo" "ls" "grep" "awk" "sed")

# Création de la sandbox
sandbox_create() {
    mkdir -p "$SANDBOX_ROOT"/{bin,tmp,var}
    
    # Copie des commandes autorisées
    for cmd in "${SANDBOX_ALLOWED_CMDS[@]}"; do
        local cmd_path=$(command -v "$cmd")
        if [[ -n "$cmd_path" ]]; then
            cp "$cmd_path" "$SANDBOX_ROOT/bin/"
        fi
    done
    
    log_info "Sandbox created at $SANDBOX_ROOT"
}

# Exécution dans la sandbox
sandbox_exec() {
    local script=$1
    shift
    local args=("$@")
    
    # Validation du script
    if [[ ! -f "$script" ]]; then
        log_error "Script not found: $script"
        return 1
    fi
    
    # Exécution avec restrictions
    chroot "$SANDBOX_ROOT" /bin/bash "$script" "${args[@]}" 2>&1
}

# Nettoyage de la sandbox
sandbox_destroy() {
    rm -rf "$SANDBOX_ROOT"
    log_info "Sandbox destroyed"
}

# Validation des permissions
sandbox_validate_permissions() {
    local file=$1
    
    # Vérifier le propriétaire
    local owner=$(stat -c '%U' "$file")
    if [[ "$owner" != "root" ]] && [[ "$owner" != "$USER" ]]; then
        log_error "Invalid file owner: $owner"
        return 1
    fi
    
    # Vérifier les permissions (pas d'écriture pour group/others)
    local perms=$(stat -c '%a' "$file")
    if [[ "${perms:1:1}" -gt 5 ]] || [[ "${perms:2:1}" -gt 5 ]]; then
        log_error "Invalid permissions: $perms (file is group/world writable)"
        return 1
    fi
    
    return 0
}
```

### Audit et traçabilité

**`lib/audit.sh`**

```bash
#!/bin/bash
#
# Bibliothèque: audit.sh
# Description: Système d'audit complet des exécutions
#

AUDIT_LOG="${PROJECT_ROOT}/logs/audit.log"
AUDIT_RETENTION_DAYS=${AUDIT_RETENTION_DAYS:-90}

# Initialisation de l'audit
audit_init() {
    mkdir -p "$(dirname "$AUDIT_LOG")"
    
    # Rotation si nécessaire
    if [[ -f "$AUDIT_LOG" ]]; then
        local size=$(stat -c%s "$AUDIT_LOG")
        if [[ $size -gt 104857600 ]]; then  # 100MB
            mv "$AUDIT_LOG" "${AUDIT_LOG}.$(date +%Y%m%d-%H%M%S)"
            gzip "${AUDIT_LOG}.$(date +%Y%m%d-%H%M%S)"
        fi
    fi
}

# Enregistrement d'un événement d'audit
audit_log() {
    local event_type=$1
    local script_name=$2
    local user=$3
    local details=$4
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local hostname=$(hostname)
    local pid=$$
    local ppid=$PPID
    
    # Format JSON structuré
    local audit_entry=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "event_type": "$event_type",
  "script": "$script_name",
  "user": "$user",
  "uid": $(id -u "$user"),
  "hostname": "$hostname",
  "pid": $pid,
  "ppid": $ppid,
  "working_directory": "$PWD",
  "command_line": "$0 $*",
  "details": $(echo "$details" | jq -Rs .)
}
EOF
)
    
    echo "$audit_entry" >> "$AUDIT_LOG"
}

# Audit de début d'exécution
audit_execution_start() {
    local script_name=$1
    shift
    local params="$*"
    
    audit_log "EXECUTION_START" "$script_name" "$USER" "Parameters: $params"
}

# Audit de fin d'exécution
audit_execution_end() {
    local script_name=$1
    local exit_code=$2
    local duration=$3
    
    local status="SUCCESS"
    [[ $exit_code -ne 0 ]] && status="FAILURE"
    
    audit_log "EXECUTION_END" "$script_name" "$USER" \
        "Status: $status, Exit code: $exit_code, Duration: ${duration}ms"
}

# Audit de modification de fichier
audit_file_modification() {
    local script_name=$1
    local file_path=$2
    local operation=$3  # CREATE, MODIFY, DELETE
    
    local file_hash=""
    if [[ -f "$file_path" ]]; then
        file_hash=$(sha256sum "$file_path" | awk '{print $1}')
    fi
    
    audit_log "FILE_MODIFICATION" "$script_name" "$USER" \
        "Operation: $operation, File: $file_path, Hash: $file_hash"
}

# Audit d'accès sensible
audit_sensitive_access() {
    local script_name=$1
    local resource=$2
    local access_type=$3  # READ, WRITE, EXECUTE
    
    audit_log "SENSITIVE_ACCESS" "$script_name" "$USER" \
        "Resource: $resource, Access: $access_type"
}

# Recherche dans l'audit
audit_search() {
    local criteria=$1
    local start_date=${2:-""}
    local end_date=${3:-""}
    
    local query='.'
    
    if [[ -n "$criteria" ]]; then
        query+=" | select(.script | contains(\"$criteria\"))"
    fi
    
    if [[ -n "$start_date" ]]; then
        query+=" | select(.timestamp >= \"$start_date\")"
    fi
    
    if [[ -n "$end_date" ]]; then
        query+=" | select(.timestamp <= \"$end_date\")"
    fi
    
    jq -c "$query" "$AUDIT_LOG" 2>/dev/null || true
}

# Génération de rapport d'audit
audit_report() {
    local start_date=$1
    local end_date=$2
    
    echo "==================================="
    echo "Audit Report"
    echo "Period: $start_date to $end_date"
    echo "==================================="
    echo ""
    
    # Statistiques par type d'événement
    echo "Events by Type:"
    jq -r 'select(.timestamp >= "'$start_date'" and .timestamp <= "'$end_date'") | .event_type' "$AUDIT_LOG" | \
        sort | uniq -c | sort -rn
    echo ""
    
    # Scripts les plus exécutés
    echo "Top 10 Most Executed Scripts:"
    jq -r 'select(.event_type == "EXECUTION_START" and .timestamp >= "'$start_date'" and .timestamp <= "'$end_date'") | .script' "$AUDIT_LOG" | \
        sort | uniq -c | sort -rn | head -10
    echo ""
    
    # Échecs
    echo "Failed Executions:"
    jq -c 'select(.event_type == "EXECUTION_END" and .details | contains("FAILURE") and .timestamp >= "'$start_date'" and .timestamp <= "'$end_date'")' "$AUDIT_LOG" | \
        head -20
    echo ""
    
    # Accès sensibles
    echo "Sensitive Access Events:"
    jq -c 'select(.event_type == "SENSITIVE_ACCESS" and .timestamp >= "'$start_date'" and .timestamp <= "'$end_date'")' "$AUDIT_LOG"
}

# Nettoyage des anciens logs
audit_cleanup() {
    log_info "Cleaning up audit logs older than $AUDIT_RETENTION_DAYS days"
    
    find "$(dirname "$AUDIT_LOG")" -name "audit.log.*.gz" -mtime +$AUDIT_RETENTION_DAYS -delete
    
    log_info "Audit cleanup completed"
}
```

---

## Gestion avancée des erreurs

### Pattern : Retry avec backoff exponentiel

**`lib/retry.sh`**

```bash
#!/bin/bash
#
# Bibliothèque: retry.sh
# Description: Mécanisme de retry avec backoff exponentiel
#

RETRY_MAX_ATTEMPTS=${RETRY_MAX_ATTEMPTS:-3}
RETRY_INITIAL_DELAY=${RETRY_INITIAL_DELAY:-1}
RETRY_MAX_DELAY=${RETRY_MAX_DELAY:-60}
RETRY_BACKOFF_MULTIPLIER=${RETRY_BACKOFF_MULTIPLIER:-2}

# Exécution avec retry
retry_execute() {
    local command=$1
    local max_attempts=${2:-$RETRY_MAX_ATTEMPTS}
    local delay=$RETRY_INITIAL_DELAY
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Attempt $attempt/$max_attempts: $command"
        
        if eval "$command"; then
            log_info "Command succeeded on attempt $attempt"
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_warn "Command failed, retrying in ${delay}s..."
            sleep "$delay"
            
            # Backoff exponentiel
            delay=$((delay * RETRY_BACKOFF_MULTIPLIER))
            if [[ $delay -gt $RETRY_MAX_DELAY ]]; then
                delay=$RETRY_MAX_DELAY
            fi
        fi
        
        ((attempt++))
    done
    
    log_error "Command failed after $max_attempts attempts"
    return 1
}

# Retry conditionnel (selon le code d'erreur)
retry_execute_conditional() {
    local command=$1
    local retryable_codes=$2  # Liste de codes d'erreur pour lesquels retry
    local max_attempts=${3:-$RETRY_MAX_ATTEMPTS}
    local delay=$RETRY_INITIAL_DELAY
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Attempt $attempt/$max_attempts: $command"
        
        local exit_code=0
        eval "$command" || exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            log_info "Command succeeded on attempt $attempt"
            return 0
        fi
        
        # Vérifier si le code d'erreur est retryable
        if [[ ! " $retryable_codes " =~ " $exit_code " ]]; then
            log_error "Non-retryable error code: $exit_code"
            return $exit_code
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_warn "Retryable error ($exit_code), retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * RETRY_BACKOFF_MULTIPLIER))
            if [[ $delay -gt $RETRY_MAX_DELAY ]]; then
                delay=$RETRY_MAX_DELAY
            fi
        fi
        
        ((attempt++))
    done
    
    log_error "Command failed after $max_attempts attempts (last exit code: $exit_code)"
    return $exit_code
}

# Circuit breaker
declare -A CIRCUIT_BREAKER_FAILURES
declare -A CIRCUIT_BREAKER_LAST_ATTEMPT
CIRCUIT_BREAKER_THRESHOLD=${CIRCUIT_BREAKER_THRESHOLD:-5}
CIRCUIT_BREAKER_TIMEOUT=${CIRCUIT_BREAKER_TIMEOUT:-60}

circuit_breaker_execute() {
    local circuit_name=$1
    local command=$2
    
    local current_time=$(date +%s)
    local failures=${CIRCUIT_BREAKER_FAILURES[$circuit_name]:-0}
    local last_attempt=${CIRCUIT_BREAKER_LAST_ATTEMPT[$circuit_name]:-0}
    
    # Vérifier si le circuit est ouvert
    if [[ $failures -ge $CIRCUIT_BREAKER_THRESHOLD ]]; then
        local time_since_last=$((current_time - last_attempt))
        
        if [[ $time_since_last -lt $CIRCUIT_BREAKER_TIMEOUT ]]; then
            log_error "Circuit breaker open for $circuit_name (wait $((CIRCUIT_BREAKER_TIMEOUT - time_since_last))s)"
            return 1
        else
            log_info "Circuit breaker half-open, attempting $circuit_name"
            CIRCUIT_BREAKER_FAILURES[$circuit_name]=0
        fi
    fi
    
    # Exécuter la commande
    CIRCUIT_BREAKER_LAST_ATTEMPT[$circuit_name]=$current_time
    
    if eval "$command"; then
        CIRCUIT_BREAKER_FAILURES[$circuit_name]=0
        log_info "Circuit breaker: $circuit_name succeeded"
        return 0
    else
        CIRCUIT_BREAKER_FAILURES[$circuit_name]=$((failures + 1))
        log_warn "Circuit breaker: $circuit_name failed (${CIRCUIT_BREAKER_FAILURES[$circuit_name]}/$CIRCUIT_BREAKER_THRESHOLD)"
        return 1
    fi
}
```

### Gestion des timeouts

**`lib/timeout.sh`**

```bash
#!/bin/bash
#
# Bibliothèque: timeout.sh
# Description: Gestion des timeouts pour scripts
#

DEFAULT_TIMEOUT=300  # 5 minutes

# Exécution avec timeout
timeout_execute() {
    local timeout_seconds=${1:-$DEFAULT_TIMEOUT}
    shift
    local command="$*"
    
    log_debug "Executing with timeout: ${timeout_seconds}s"
    
    # Utiliser timeout GNU
    if timeout "$timeout_seconds" bash -c "$command"; then
        log_debug "Command completed within timeout"
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "Command timed out after ${timeout_seconds}s"
            return $EXIT_ERROR_TIMEOUT
        else
            log_error "Command failed with exit code: $exit_code"
            return $exit_code
        fi
    fi
}

# Exécution avec timeout et callback
timeout_execute_with_callback() {
    local timeout_seconds=$1
    local command=$2
    local timeout_callback=$3
    
    if ! timeout_execute "$timeout_seconds" "$command"; then
        local exit_code=$?
        if [[ $exit_code -eq $EXIT_ERROR_TIMEOUT ]]; then
            log_info "Executing timeout callback"
            eval "$timeout_callback"
        fi
        return $exit_code
    fi
    
    return 0
}
```

---

## Performance et optimisation

### Profiling des scripts

**`tools/profiler.sh`**

```bash
#!/bin/bash
#
# Script: profiler.sh
# Description: Profile l'exécution d'un script pour identifier les goulots d'étranglement
# Usage: profiler.sh <script> [args...]
#

set -euo pipefail

SCRIPT_TO_PROFILE=$1
shift
PROFILE_OUTPUT="/tmp/profile-$$.log"

# Activation du profiling
profile_start() {
    log_info "Starting profiling of $SCRIPT_TO_PROFILE"
    
    # Tracer toutes les commandes avec leur temps d'exécution
    export PS4='+ $(date +%s.%N) ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    exec 3>&2 2>"$PROFILE_OUTPUT"
    set -x
}

# Analyse du profiling
profile_analyze() {
    set +x
    exec 2>&3 3>&-
    
    log_info "Analyzing profile data..."
    
    # Parser le log de profiling
    awk '
    BEGIN {
        prev_time = 0
    }
    {
        if (match($0, /^\\+ ([0-9]+\\.[0-9]+)/, arr)) {
            curr_time = arr[1]
            if (prev_time > 0) {
                duration = curr_time - prev_time
                line = substr($0, index($0, $3))
                times[line] += duration
                counts[line]++
            }
            prev_time = curr_time
        }
    }
    END {
        print "Top 20 slowest operations:"
        print "========================================="
        for (line in times) {
            printf "%.3fs (%dx) %s\n", times[line], counts[line], line
        }
    }
    ' "$PROFILE_OUTPUT" | sort -rn | head -20
    
    # Statistiques globales
    local start_time=$(head -1 "$PROFILE_OUTPUT" | awk '{print $2}')
    local end_time=$(tail -1 "$PROFILE_OUTPUT" | awk '{print $2}')
    local total_duration=$(echo "$end_time - $start_time" | bc)
    
    echo ""
    echo "========================================="
    echo "Total execution time: ${total_duration}s"
    echo "Profile log saved to: $PROFILE_OUTPUT"
}

# Exécution
profile_start
"$SCRIPT_TO_PROFILE" "$@"
profile_analyze
```

### Optimisation des scripts

**Recommandations de performance :**

```bash
# ❌ Mauvais : Appels multiples à des commandes externes dans une boucle
for file in *.txt; do
    lines=$(wc -l < "$file")
    size=$(stat -c%s "$file")
    echo "$file: $lines lines, $size bytes"
done

# ✅ Bon : Utilisation de built-ins et réduction d'appels
while IFS= read -r file; do
    while IFS= read -r line; do ((lines++)); done < "$file"
    size=$(stat -c%s "$file")
    echo "$file: $lines lines, $size bytes"
    lines=0
done < <(find . -name "*.txt")

# ❌ Mauvais : Parsing de JSON ligne par ligne
while read -r line; do
    id=$(echo "$line" | jq -r '.id')
    name=$(echo "$line" | jq -r '.name')
done < data.json

# ✅ Bon : Parsing JSON en une seule fois
jq -r '.[] | "\(.id) \(.name)"' data.json | while read -r id name; do
    # traitement
done

# ❌ Mauvais : Multiples redirections
echo "line1" > file
echo "line2" >> file
echo "line3" >> file

# ✅ Bon : Redirection groupée
{
    echo "line1"
    echo "line2"
    echo "line3"
} > file

# ❌ Mauvais : Sous-shells inutiles
result=$(cat file | grep pattern | awk '{print $1}')

# ✅ Bon : Pipes directs sans sous-shell quand possible
grep pattern file | awk '{print $1}' > result.txt
result=$(< result.txt)
```

---

## Intégration avec d'autres systèmes

### Webhooks et notifications

**`lib/notifications.sh`**

```bash
#!/bin/bash
#
# Bibliothèque: notifications.sh
# Description: Système de notifications multi-canal
#

# Notification Slack
notify_slack() {
    local webhook_url=$1
    local message=$2
    local level=${3:-"info"}
    
    local color="good"
    case $level in
        error|critical) color="danger" ;;
        warning) color="warning" ;;
    esac
    
    local payload=$(cat <<EOF
{
  "attachments": [{
    "color": "$color",
    "title": "Script Notification",
    "text": "$message",
    "ts": $(date +%s)
  }]
}
EOF
)
    
    curl -X POST -H 'Content-type: application/json' \
        --data "$payload" "$webhook_url" 2>/dev/null
}

# Notification Email
notify_email() {
    local to=$1
    local subject=$2
    local body=$3
    local attachment=${4:-""}
    
    if [[ -n "$attachment" ]]; then
        echo "$body" | mail -s "$subject" -A "$attachment" "$to"
    else
        echo "$body" | mail -s "$subject" "$to"
    fi
}

# Notification Discord
notify_discord() {
    local webhook_url=$1
    local message=$2
    
    local payload=$(cat <<EOF
{
  "content": "$message",
  "username": "Script Monitor"
}
EOF
)
    
    curl -X POST -H 'Content-type: application/json' \
        --data "$payload" "$webhook_url" 2>/dev/null
}

# Notification Microsoft Teams
notify_teams() {
    local webhook_url=$1
    local title=$2
    local message=$3
    local level=${4:-"info"}
    
    local color="0078D4"
    case $level in
        error|critical) color="D13438" ;;
        warning) color="FFB900" ;;
        success) color="107C10" ;;
    esac
    
    local payload=$(cat <<EOF
{
  "@type": "MessageCard",
  "@context": "http://schema.org/extensions",
  "themeColor": "$color",
  "summary": "$title",
  "sections": [{
    "activityTitle": "$title",
    "text": "$message",
    "markdown": true
  }]
}
EOF
)
    
    curl -X POST -H 'Content-type: application/json' \
        --data "$payload" "$webhook_url" 2>/dev/null
}

# Notification PagerDuty
notify_pagerduty() {
    local routing_key=$1
    local severity=$2  # critical, error, warning, info
    local summary=$3
    local details=$4
    
    local payload=$(cat <<EOF
{
  "routing_key": "$routing_key",
  "event_action": "trigger",
  "payload": {
    "summary": "$summary",
    "severity": "$severity",
    "source": "$(hostname)",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "custom_details": $details
  }
}
EOF
)
    
    local response=$(curl -s -X POST \
        -H 'Content-Type: application/json' \
        -d "$payload" \
        "https://events.pagerduty.com/v2/enqueue")
    
    local status=$(echo "$response" | jq -r '.status // "error"')
    
    if [[ "$status" == "success" ]]; then
        log_debug "PagerDuty notification sent successfully"
        return 0
    else
        log_error "PagerDuty notification failed: $response"
        return 1
    fi
}