#!/usr/bin/env python3
"""
Script de génération de base de données SQLite pour le catalogue de scripts AtomicOps-Suite
"""

import sqlite3
import os
import re
import json
from datetime import datetime
from pathlib import Path

class ScriptsCatalogGenerator:
    def __init__(self, db_path="scripts-catalog.db"):
        self.db_path = db_path
        self.script_dir = Path(__file__).parent
        self.atomics_dir = self.script_dir / "atomics"
        
        # Scripts implémentés récemment (23 nouveaux)
        self.implemented_scripts = {
            "snapshot-kvm.vm.sh": "2025-10-06",
            "start-compose.stack.sh": "2025-10-06", 
            "start-docker.container.sh": "2025-10-06",
            "start-kvm.vm.sh": "2025-10-06",
            "start-lxc.container.sh": "2025-10-06",
            "stop-compose.stack.sh": "2025-10-06",
            "stop-docker.container.sh": "2025-10-06", 
            "stop-kvm.vm.sh": "2025-10-06",
            "sync-directory.bidirectional.sh": "2025-10-06",
            "sync-directory.rsync.sh": "2025-10-06",
            "test-network.speed.sh": "2025-10-06",
            "unlock-user.sh": "2025-10-06",
            "unmount-disk.partition.sh": "2025-10-06",
            "update-package.all.yum.sh": "2025-10-06",
            "update-package.list.apt.sh": "2025-10-06",
            "upgrade-package.all.apt.sh": "2025-10-06",
            "vacuum-postgresql.database.sh": "2025-10-06"
        }
    
    def create_database_schema(self, conn):
        """Crée le schéma de base de données"""
        print("🏗️  Creating database schema...")
        
        schema_sql = '''
        -- Table principale des scripts
        CREATE TABLE IF NOT EXISTS scripts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            type TEXT NOT NULL,
            category TEXT NOT NULL,
            description TEXT NOT NULL,
            long_description TEXT,
            version TEXT DEFAULT '1.0.0',
            author TEXT DEFAULT 'AtomicOps-Suite',
            path TEXT NOT NULL,
            status TEXT DEFAULT 'active',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            last_tested DATETIME,
            documentation_path TEXT,
            complexity_score INTEGER DEFAULT 5,
            implementation_date DATE,
            
            CHECK (type IN ('atomic', 'orchestrator-1', 'orchestrator-2', 'orchestrator-3', 'orchestrator-4', 'orchestrator-5')),
            CHECK (status IN ('active', 'deprecated', 'experimental', 'disabled', 'implemented', 'planned'))
        );

        -- Paramètres des scripts
        CREATE TABLE IF NOT EXISTS script_parameters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            script_id INTEGER NOT NULL,
            param_name TEXT NOT NULL,
            param_type TEXT NOT NULL,
            is_required BOOLEAN DEFAULT 0,
            default_value TEXT,
            description TEXT,
            validation_pattern TEXT,
            
            FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
            CHECK (param_type IN ('string', 'integer', 'boolean', 'file_path', 'directory_path', 'ip_address', 'url', 'email'))
        );

        -- Sorties des scripts  
        CREATE TABLE IF NOT EXISTS script_outputs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            script_id INTEGER NOT NULL,
            output_type TEXT NOT NULL,
            output_format TEXT NOT NULL,
            description TEXT,
            example_value TEXT,
            
            FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
            CHECK (output_type IN ('json', 'text', 'file', 'exit_code', 'log')),
            CHECK (output_format IN ('structured_json', 'plain_text', 'csv', 'xml', 'binary'))
        );

        -- Dépendances des scripts
        CREATE TABLE IF NOT EXISTS script_dependencies (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            script_id INTEGER NOT NULL,
            dependency_type TEXT NOT NULL,
            dependency_name TEXT NOT NULL,
            dependency_version TEXT,
            is_optional BOOLEAN DEFAULT 0,
            installation_command TEXT,
            
            FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
            CHECK (dependency_type IN ('system_command', 'package', 'service', 'library', 'script'))
        );

        -- Tags et catégories
        CREATE TABLE IF NOT EXISTS script_tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            script_id INTEGER NOT NULL,
            tag_name TEXT NOT NULL,
            tag_category TEXT,
            
            FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
        );

        -- Compatibilité OS/distributions
        CREATE TABLE IF NOT EXISTS script_compatibility (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            script_id INTEGER NOT NULL,
            os_family TEXT NOT NULL,
            distribution TEXT,
            version_min TEXT,
            version_max TEXT,
            compatibility_level TEXT NOT NULL,
            notes TEXT,
            
            FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE,
            CHECK (os_family IN ('linux', 'unix', 'darwin', 'windows')),
            CHECK (compatibility_level IN ('full', 'partial', 'requires_adaptation', 'not_supported'))
        );

        -- Statistiques d'utilisation
        CREATE TABLE IF NOT EXISTS script_usage_stats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            script_id INTEGER NOT NULL,
            execution_date DATETIME DEFAULT CURRENT_TIMESTAMP,
            execution_time_ms INTEGER,
            success BOOLEAN,
            error_message TEXT,
            user_context TEXT,
            
            FOREIGN KEY (script_id) REFERENCES scripts(id) ON DELETE CASCADE
        );

        -- Index pour optimiser les requêtes
        CREATE INDEX IF NOT EXISTS idx_scripts_type ON scripts(type);
        CREATE INDEX IF NOT EXISTS idx_scripts_category ON scripts(category);
        CREATE INDEX IF NOT EXISTS idx_scripts_status ON scripts(status);
        CREATE INDEX IF NOT EXISTS idx_script_tags_name ON script_tags(tag_name);
        CREATE INDEX IF NOT EXISTS idx_compatibility_os ON script_compatibility(os_family);
        CREATE INDEX IF NOT EXISTS idx_usage_date ON script_usage_stats(execution_date);
        '''
        
        conn.executescript(schema_sql)
        print("✅ Database schema created successfully")
    
    def analyze_script_file(self, script_path):
        """Analyse un fichier script pour extraire les métadonnées"""
        try:
            with open(script_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            script_name = os.path.basename(script_path)
            
            # Extraire les métadonnées du header
            description = self._extract_field(content, "Description") or "Script atomique"
            version = self._extract_field(content, "Version") or "1.0"
            author = self._extract_field(content, "Author") or "AtomicOps-Suite"
            
            # Détecter la catégorie basée sur le nom
            category = self._determine_category(script_name)
            
            # Calculer le score de complexité
            complexity_score = self._calculate_complexity(content)
            
            return {
                'name': script_name,
                'type': 'atomic',
                'category': category,
                'description': description,
                'version': version,
                'author': author,
                'path': str(script_path),
                'complexity_score': complexity_score
            }
        except Exception as e:
            print(f"⚠️  Error analyzing {script_path}: {e}")
            return None
    
    def _extract_field(self, content, field_name):
        """Extrait un champ du header du script"""
        pattern = rf'^#\s*{field_name}:\s*(.+)$'
        match = re.search(pattern, content, re.MULTILINE | re.IGNORECASE)
        return match.group(1).strip() if match else None
    
    def _determine_category(self, script_name):
        """Détermine la catégorie basée sur le nom du script"""
        categories = {
            'container': ['docker', 'compose', 'container', 'lxc', 'lxd'],
            'virtualization': ['kvm', 'vm', 'snapshot', 'virsh'],
            'network': ['network', 'ping', 'speed', 'interface'],
            'storage': ['disk', 'partition', 'mount', 'lvm'],
            'user_management': ['user', 'password', 'unlock', 'sudo'],
            'package_management': ['package', 'update', 'upgrade', 'apt', 'yum'],
            'synchronization': ['sync', 'directory', 'rsync'],
            'database': ['postgresql', 'mysql', 'database', 'vacuum'],
            'service_management': ['service', 'systemd', 'start', 'stop'],
            'monitoring': ['monitor', 'check', 'usage', 'info'],
            'security': ['firewall', 'ssl', 'certificate', 'encrypt'],
            'backup': ['backup', 'restore', 'archive'],
            'logging': ['log', 'rotate', 'analyze']
        }
        
        script_lower = script_name.lower()
        for category, keywords in categories.items():
            if any(keyword in script_lower for keyword in keywords):
                return category
        
        return 'system'  # Catégorie par défaut
    
    def _calculate_complexity(self, content):
        """Calcule un score de complexité basé sur le contenu"""
        lines = content.split('\n')
        line_count = len(lines)
        function_count = len(re.findall(r'^[a-zA-Z_][a-zA-Z0-9_]*\(\)\s*{', content, re.MULTILINE))
        
        # Score basé sur la taille et le nombre de fonctions
        complexity = (line_count // 50) + (function_count // 2)
        return max(1, min(10, complexity))  # Entre 1 et 10
    
    def populate_scripts_data(self, conn):
        """Peuple la base avec les données des scripts"""
        print("📊 Analyzing and inserting script data...")
        
        scripts_added = 0
        
        # Analyser les scripts existants
        if self.atomics_dir.exists():
            for script_file in self.atomics_dir.glob("*.sh"):
                script_data = self.analyze_script_file(script_file)
                if script_data:
                    # Déterminer le statut et la date d'implémentation
                    status = 'active'
                    implementation_date = None
                    
                    if script_data['name'] in self.implemented_scripts:
                        status = 'implemented'
                        implementation_date = self.implemented_scripts[script_data['name']]
                    
                    # Insérer dans la base
                    conn.execute('''
                        INSERT OR REPLACE INTO scripts (
                            name, type, category, description, version, author, path,
                            status, complexity_score, implementation_date, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        script_data['name'],
                        script_data['type'],
                        script_data['category'],
                        script_data['description'],
                        script_data['version'],
                        script_data['author'],
                        script_data['path'],
                        status,
                        script_data['complexity_score'],
                        implementation_date,
                        datetime.now().isoformat()
                    ))
                    
                    scripts_added += 1
                    print(f"  ✅ Added: {script_data['name']} ({status})")
        
        # Ajouter des scripts planifiés
        planned_scripts = [
            ("backup-mysql.database.sh", "database", "Sauvegarde base MySQL"),
            ("create-lvm.volume.sh", "storage", "Création volume LVM"),
            ("monitor-cpu.usage.sh", "monitoring", "Surveillance CPU"),
            ("setup-firewall.iptables.sh", "security", "Configuration iptables"),
            ("deploy-nginx.config.sh", "web", "Déploiement Nginx"),
            ("analyze-log.apache.sh", "logging", "Analyse logs Apache"),
            ("compress-directory.tar.sh", "archiving", "Compression tar"),
            ("validate-ssl.certificate.sh", "security", "Validation SSL"),
            ("rotate-backup.cleanup.sh", "backup", "Nettoyage sauvegardes"),
            ("optimize-mysql.performance.sh", "database", "Optimisation MySQL")
        ]
        
        for name, category, description in planned_scripts:
            conn.execute('''
                INSERT OR REPLACE INTO scripts (
                    name, type, category, description, version, author, path,
                    status, complexity_score, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                name, 'atomic', category, description, '1.0', 'AtomicOps-Suite',
                f'atomics/{name}', 'planned', 5, datetime.now().isoformat()
            ))
            scripts_added += 1
        
        conn.commit()
        print(f"✅ {scripts_added} scripts added to database")
    
    def add_compatibility_data(self, conn):
        """Ajoute les données de compatibilité"""
        print("🌐 Adding compatibility data...")
        
        compatibility_rules = [
            # Docker - Compatible Linux universel
            (["docker", "compose"], "linux", "ubuntu", "full", "Docker natif supporté"),
            (["docker", "compose"], "linux", "debian", "full", "Docker natif supporté"),
            (["docker", "compose"], "linux", "centos", "full", "Docker CE supporté"),
            (["docker", "compose"], "linux", "rhel", "full", "Docker CE supporté"),
            
            # APT - Debian/Ubuntu uniquement
            (["apt"], "linux", "ubuntu", "full", "Gestionnaire de paquets natif"),
            (["apt"], "linux", "debian", "full", "Gestionnaire de paquets natif"),
            (["apt"], "linux", "centos", "not_supported", "Utilise YUM/DNF"),
            
            # YUM - RHEL/CentOS/Fedora
            (["yum"], "linux", "centos", "full", "Gestionnaire de paquets natif"),
            (["yum"], "linux", "rhel", "full", "Gestionnaire de paquets natif"),
            (["yum"], "linux", "fedora", "full", "DNF supporté"),
            (["yum"], "linux", "ubuntu", "not_supported", "Utilise APT"),
            
            # KVM - Compatible Linux avec virtualisation
            (["kvm", "vm"], "linux", None, "full", "Supporté si virtualisation activée"),
            
            # Network - Universel
            (["network"], "linux", None, "full", "Compatible toutes distributions Linux"),
            
            # LXC/LXD - Linux moderne
            (["lxc"], "linux", "ubuntu", "full", "LXD intégré"),
            (["lxc"], "linux", "debian", "full", "LXC/LXD disponible"),
            (["lxc"], "linux", "centos", "partial", "LXC disponible, LXD limité"),
        ]
        
        for keywords, os_family, distribution, level, notes in compatibility_rules:
            # Trouver les scripts correspondants par nom
            for keyword in keywords:
                cursor = conn.execute("SELECT id, name FROM scripts WHERE name LIKE ?", (f"%{keyword}%",))
                for script_id, script_name in cursor.fetchall():
                    conn.execute('''
                        INSERT OR IGNORE INTO script_compatibility 
                        (script_id, os_family, distribution, compatibility_level, notes)
                        VALUES (?, ?, ?, ?, ?)
                    ''', (script_id, os_family, distribution, level, notes))
        
        conn.commit()
        print("✅ Compatibility data added")
    
    def add_script_tags(self, conn):
        """Ajoute les tags pour classification"""
        print("🏷️  Adding script tags...")
        
        tag_rules = [
            # Technologies
            (["docker"], "docker", "technology"),
            (["compose"], "compose", "technology"),
            (["kvm"], "kvm", "technology"),
            (["lxc"], "lxc", "technology"),
            (["postgresql"], "postgresql", "technology"),
            (["rsync"], "rsync", "technology"),
            (["apt"], "apt", "technology"),
            (["yum"], "yum", "technology"),
            
            # Catégories
            (["docker", "lxc", "container"], "container", "category"),
            (["kvm", "vm"], "virtualization", "category"),
            (["network"], "network", "category"),
            (["disk", "mount", "partition"], "storage", "category"),
            (["user"], "user-management", "category"),
            (["postgresql", "mysql", "database"], "database", "category"),
            (["package"], "package-management", "category"),
            (["sync"], "synchronization", "category"),
            
            # Fonctionnalités
            (["snapshot"], "snapshot", "feature"),
            (["speed"], "speed-test", "feature"),
            (["unlock"], "security", "feature"),
            (["vacuum"], "maintenance", "feature"),
            (["update", "upgrade"], "system-maintenance", "feature"),
        ]
        
        for keywords, tag_name, tag_category in tag_rules:
            for keyword in keywords:
                cursor = conn.execute("SELECT id FROM scripts WHERE name LIKE ?", (f"%{keyword}%",))
                for (script_id,) in cursor.fetchall():
                    conn.execute('''
                        INSERT OR IGNORE INTO script_tags (script_id, tag_name, tag_category)
                        VALUES (?, ?, ?)
                    ''', (script_id, tag_name, tag_category))
        
        conn.commit()
        print("✅ Script tags added")
    
    def create_views_and_statistics(self, conn):
        """Crée les vues et génère les statistiques"""
        print("📈 Creating views and generating statistics...")
        
        views_sql = '''
        -- Vue des statistiques par catégorie
        CREATE VIEW IF NOT EXISTS stats_by_category AS
        SELECT 
            category,
            COUNT(*) as total_scripts,
            SUM(CASE WHEN status = 'implemented' THEN 1 ELSE 0 END) as implemented,
            SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active,
            SUM(CASE WHEN status = 'planned' THEN 1 ELSE 0 END) as planned,
            ROUND(AVG(complexity_score), 2) as avg_complexity
        FROM scripts 
        GROUP BY category 
        ORDER BY total_scripts DESC;

        -- Vue des scripts récemment implémentés
        CREATE VIEW IF NOT EXISTS recently_implemented AS
        SELECT 
            name,
            category,
            description,
            implementation_date,
            complexity_score
        FROM scripts 
        WHERE status = 'implemented' 
        ORDER BY implementation_date DESC;

        -- Vue de compatibilité par OS
        CREATE VIEW IF NOT EXISTS compatibility_summary AS
        SELECT 
            sc.os_family,
            sc.distribution,
            COUNT(DISTINCT sc.script_id) as compatible_scripts,
            s.category
        FROM script_compatibility sc
        JOIN scripts s ON sc.script_id = s.id
        WHERE sc.compatibility_level IN ('full', 'partial')
        GROUP BY sc.os_family, sc.distribution, s.category
        ORDER BY compatible_scripts DESC;
        '''
        
        conn.executescript(views_sql)
        conn.commit()
        print("✅ Views created successfully")
    
    def display_statistics(self, conn):
        """Affiche les statistiques de la base"""
        print("\n" + "="*60)
        print("📊 DATABASE STATISTICS")
        print("="*60)
        
        # Statistiques par catégorie
        print("\n🗂️  Scripts by Category:")
        cursor = conn.execute("SELECT * FROM stats_by_category")
        for row in cursor.fetchall():
            category, total, implemented, active, planned, avg_complexity = row
            print(f"  {category:20} | Total: {total:2} | Impl: {implemented:2} | Active: {active:2} | Planned: {planned:2} | Complexity: {avg_complexity}")
        
        # Scripts récemment implémentés
        print("\n🆕 Recently Implemented Scripts:")
        cursor = conn.execute("SELECT * FROM recently_implemented LIMIT 10")
        for row in cursor.fetchall():
            name, category, description, impl_date, complexity = row
            print(f"  {name:30} | {category:15} | {impl_date} | Complexity: {complexity}")
        
        # Compatibilité OS
        print("\n🌐 OS Compatibility Summary:")
        cursor = conn.execute('''
            SELECT 
                os_family || CASE WHEN distribution IS NOT NULL THEN ' (' || distribution || ')' ELSE '' END as platform,
                COUNT(DISTINCT script_id) as compatible_scripts
            FROM script_compatibility 
            WHERE compatibility_level = 'full' 
            GROUP BY os_family, distribution 
            ORDER BY compatible_scripts DESC
        ''')
        for platform, count in cursor.fetchall():
            print(f"  {platform:25} | {count:2} scripts")
        
        # Top tags
        print("\n🏷️  Top Script Tags:")
        cursor = conn.execute('''
            SELECT tag_name, COUNT(*) as usage_count 
            FROM script_tags 
            GROUP BY tag_name 
            ORDER BY usage_count DESC 
            LIMIT 10
        ''')
        for tag, count in cursor.fetchall():
            print(f"  {tag:20} | {count:2} scripts")
        
        # Résumé global
        cursor = conn.execute("SELECT COUNT(*) FROM scripts")
        total_scripts = cursor.fetchone()[0]
        
        cursor = conn.execute("SELECT COUNT(*) FROM scripts WHERE status = 'implemented'")
        implemented_count = cursor.fetchone()[0]
        
        print(f"\n📈 Global Summary:")
        print(f"  Total Scripts:      {total_scripts}")
        print(f"  Implemented:        {implemented_count}")
        print(f"  Implementation %:   {(implemented_count/total_scripts*100):.1f}%")
        print(f"  Database Size:      {os.path.getsize(self.db_path)/1024:.1f} KB")
    
    def generate_database(self):
        """Génère la base de données complète"""
        print("🚀 Starting AtomicOps-Suite Scripts Database Generation")
        
        # Backup existing database
        if os.path.exists(self.db_path):
            backup_path = f"{self.db_path}.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            os.rename(self.db_path, backup_path)
            print(f"⚠️  Existing database backed up to: {backup_path}")
        
        # Create new database
        with sqlite3.connect(self.db_path) as conn:
            # Enable foreign keys
            conn.execute("PRAGMA foreign_keys = ON")
            
            self.create_database_schema(conn)
            self.populate_scripts_data(conn)
            self.add_compatibility_data(conn)
            self.add_script_tags(conn)
            self.create_views_and_statistics(conn)
            self.display_statistics(conn)
        
        print(f"\n✅ Database generation completed successfully!")
        print(f"📍 Database location: {os.path.abspath(self.db_path)}")
        print(f"💡 Use: python -c \"import sqlite3; conn=sqlite3.connect('{self.db_path}'); print('Connected to database')\" to test")

if __name__ == "__main__":
    generator = ScriptsCatalogGenerator()
    generator.generate_database()