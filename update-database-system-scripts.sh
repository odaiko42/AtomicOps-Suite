#!/usr/bin/env bash

# ==============================================================================
# Script de Mise à Jour de la Base de Données
# Description: Intégrer les 6 nouveaux scripts atomiques dans catalogue-scripts.db
# Date: 2025-10-06
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/catalogue-scripts.db"

echo "=== MISE À JOUR DE LA BASE DE DONNÉES ==="
echo "Base de données: $DB_FILE"

# Fonction pour extraire les métadonnées d'un script
extract_metadata() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    
    # Extraire la description du header du script
    local description=""
    if [[ -f "$script_path" ]]; then
        description=$(grep "^# Description:" "$script_path" | head -1 | cut -d: -f2- | sed 's/^ *//')
        if [[ -z "$description" ]]; then
            description="Script atomique pour configuration système"
        fi
    fi
    
    echo "$script_name|$description"
}

# Fonction pour déterminer la catégorie d'un script
get_script_category() {
    local script_name="$1"
    
    case "$script_name" in
        set-file.acl.sh|set-file.owner.sh|set-file.permissions.sh)
            echo "file"
            ;;
        set-network.interface.ip.sh)
            echo "network"
            ;;
        set-password.expiry.sh|set-system.hostname.sh|set-system.timezone.sh)
            echo "system"
            ;;
        restore-directory.sh|restore-file.sh)
            echo "backup"
            ;;
        revoke-user.sudo.sh)
            echo "security"
            ;;
        rotate-log.sh|search-log.pattern.sh)
            echo "logging"
            ;;
        run-smart.test.sh)
            echo "monitoring"
            ;;
        schedule-task.at.sh)
            echo "scheduling"
            ;;
        search-package.apt.sh)
            echo "package"
            ;;
        send-notification.email.sh|send-notification.slack.sh|send-notification.telegram.sh)
            echo "notification"
            ;;
        set-config.kernel.parameter.sh|set-cpu.governor.sh|set-dns.server.sh|set-env.variable.sh)
            echo "system"
            ;;
        *)
            echo "other"
            ;;
    esac
}

# Liste des 22 scripts à vérifier/ajouter
SCRIPTS_TO_ADD=(
    "restore-directory.sh"
    "restore-file.sh"
    "revoke-user.sudo.sh"
    "rotate-log.sh"
    "run-smart.test.sh"
    "schedule-task.at.sh"
    "search-log.pattern.sh"
    "search-package.apt.sh"
    "send-notification.email.sh"
    "send-notification.slack.sh"
    "send-notification.telegram.sh"
    "set-config.kernel.parameter.sh"
    "set-cpu.governor.sh"
    "set-dns.server.sh"
    "set-env.variable.sh"
    "set-file.acl.sh"
    "set-file.owner.sh"
    "set-file.permissions.sh"
    "set-network.interface.ip.sh"
    "set-password.expiry.sh"
    "set-system.hostname.sh"
    "set-system.timezone.sh"
)

# Compter les scripts existants pour ces noms
existing_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM scripts WHERE name IN ('$(IFS=','; echo "${SCRIPTS_TO_ADD[*]}" | sed "s/,/','/g")')")
echo "Scripts déjà présents dans la DB: $existing_count/22"

# Ajouter les scripts manquants
added_count=0
for script_name in "${SCRIPTS_TO_ADD[@]}"; do
    script_path="$SCRIPT_DIR/atomics/$script_name"
    
    # Vérifier si le script existe déjà dans la DB
    exists=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM scripts WHERE name = '$script_name'")
    
    if [[ $exists -eq 0 ]]; then
        # Le script n'existe pas, l'ajouter
        if [[ -f "$script_path" ]]; then
            echo "Ajout de: $script_name"
            
            # Extraire les métadonnées
            metadata=$(extract_metadata "$script_path")
            IFS='|' read -r name description <<< "$metadata"
            category=$(get_script_category "$script_name")
            
            # Insérer dans la base
            sqlite3 "$DB_FILE" "INSERT INTO scripts (name, description, type, level, category, path, created_at) VALUES (
                '$script_name',
                '$description',
                'atomic',
                0,
                '$category',
                '/root/atomics/$script_name',
                datetime('now')
            );"
            
            # Ajouter des tags basiques
            script_id=$(sqlite3 "$DB_FILE" "SELECT id FROM scripts WHERE name = '$script_name'")
            
            # Tags basés sur le nom du script
            case "$script_name" in
                set-*) 
                    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO tags (name) VALUES ('configuration');"
                    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO script_tags (script_id, tag_id) SELECT $script_id, id FROM tags WHERE name = 'configuration';"
                    ;;
                restore-*|backup-*)
                    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO tags (name) VALUES ('backup');"
                    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO script_tags (script_id, tag_id) SELECT $script_id, id FROM tags WHERE name = 'backup';"
                    ;;
                search-*|find-*)
                    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO tags (name) VALUES ('search');"
                    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO script_tags (script_id, tag_id) SELECT $script_id, id FROM tags WHERE name = 'search';"
                    ;;
                send-notification*)
                    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO tags (name) VALUES ('notification');"
                    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO script_tags (script_id, tag_id) SELECT $script_id, id FROM tags WHERE name = 'notification';"
                    ;;
            esac
            
            ((added_count++))
        else
            echo "⚠️  Script non trouvé: $script_path"
        fi
    else
        echo "✅ Déjà présent: $script_name"
    fi
done

echo ""
echo "=== RÉSULTATS ==="
echo "Scripts ajoutés: $added_count"

# Statistiques finales
echo ""
echo "=== STATISTIQUES FINALES ==="
sqlite3 "$DB_FILE" "SELECT COUNT(*) || ' scripts total' FROM scripts;"
sqlite3 "$DB_FILE" "SELECT 'Par catégorie:' as info;"
sqlite3 "$DB_FILE" "SELECT '  ' || category || ': ' || COUNT(*) FROM scripts GROUP BY category ORDER BY COUNT(*) DESC;"
sqlite3 "$DB_FILE" "SELECT 'Par type:' as info;"
sqlite3 "$DB_FILE" "SELECT '  ' || type || ': ' || COUNT(*) FROM scripts GROUP BY type;"

echo ""
echo "=== VÉRIFICATION DES 22 SCRIPTS DEMANDÉS ==="
final_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM scripts WHERE name IN ('$(IFS=','; echo "${SCRIPTS_TO_ADD[*]}" | sed "s/,/','/g")')")
echo "Scripts des 22 demandés présents: $final_count/22"

if [[ $final_count -eq 22 ]]; then
    echo "🎉 TOUS LES 22 SCRIPTS SONT MAINTENANT DANS LA BASE DE DONNÉES !"
else
    echo "⚠️  Il manque encore $((22 - final_count)) scripts dans la base"
    echo "Scripts manquants:"
    for script_name in "${SCRIPTS_TO_ADD[@]}"; do
        exists=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM scripts WHERE name = '$script_name'")
        if [[ $exists -eq 0 ]]; then
            echo "  ❌ $script_name"
        fi
    done
fi

echo ""
echo "Base de données mise à jour avec succès !"