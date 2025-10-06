#!/usr/bin/env python3
"""
Script de test pour vérifier la base de données des scripts
"""

import sqlite3
import json

def test_database():
    """Teste et affiche des informations sur la base de données"""
    conn = sqlite3.connect('scripts-catalog.db')
    
    print("🔍 Testing Scripts Catalog Database")
    print("=" * 50)
    
    # Test 1: Scripts implémentés
    cursor = conn.execute("SELECT name, category FROM scripts WHERE status = 'implemented' ORDER BY name")
    implemented = cursor.fetchall()
    
    print(f"\n✅ Implemented Scripts ({len(implemented)}):")
    for name, category in implemented:
        print(f"  • {name:35} [{category}]")
    
    # Test 2: Scripts par catégorie
    print(f"\n📊 Scripts by Category:")
    cursor = conn.execute("""
        SELECT category, 
               COUNT(*) as total,
               SUM(CASE WHEN status = 'implemented' THEN 1 ELSE 0 END) as implemented
        FROM scripts 
        GROUP BY category 
        HAVING total > 0
        ORDER BY implemented DESC, total DESC
    """)
    
    for category, total, impl in cursor.fetchall():
        percentage = (impl / total * 100) if total > 0 else 0
        print(f"  {category:20} | {total:2} total | {impl:2} impl ({percentage:4.1f}%)")
    
    # Test 3: Scripts avec tags Docker/Container
    print(f"\n🐳 Container/Docker Scripts:")
    cursor = conn.execute("""
        SELECT DISTINCT s.name, s.status 
        FROM scripts s
        JOIN script_tags st ON s.id = st.script_id 
        WHERE st.tag_name IN ('docker', 'container', 'compose')
        ORDER BY s.name
    """)
    
    for name, status in cursor.fetchall():
        status_icon = "✅" if status == "implemented" else "⏳"
        print(f"  {status_icon} {name}")
    
    # Test 4: Compatibilité Linux
    print(f"\n🐧 Linux Compatibility:")
    cursor = conn.execute("""
        SELECT DISTINCT 
            COALESCE(sc.distribution, 'All Linux') as distro,
            sc.compatibility_level,
            COUNT(DISTINCT sc.script_id) as script_count
        FROM script_compatibility sc
        WHERE sc.os_family = 'linux'
        GROUP BY sc.distribution, sc.compatibility_level
        ORDER BY script_count DESC
    """)
    
    for distro, level, count in cursor.fetchall():
        distro_info = f"{distro} ({level})"
        print(f"  {distro_info:25} | {count:2} scripts")
    
    # Test 5: Export JSON des scripts implémentés
    print(f"\n💾 Exporting implemented scripts to JSON...")
    cursor = conn.execute("""
        SELECT name, category, description, implementation_date, complexity_score
        FROM scripts 
        WHERE status = 'implemented'
        ORDER BY name
    """)
    
    implemented_scripts = []
    for name, category, desc, impl_date, complexity in cursor.fetchall():
        implemented_scripts.append({
            "name": name,
            "category": category,
            "description": desc,
            "implementation_date": impl_date,
            "complexity_score": complexity
        })
    
    with open('implemented_scripts.json', 'w', encoding='utf-8') as f:
        json.dump(implemented_scripts, f, indent=2, ensure_ascii=False)
    
    print(f"✅ Exported {len(implemented_scripts)} implemented scripts to implemented_scripts.json")
    
    # Test 6: Résumé global
    cursor = conn.execute("SELECT COUNT(*) FROM scripts")
    total_scripts = cursor.fetchone()[0]
    
    cursor = conn.execute("SELECT COUNT(*) FROM scripts WHERE status = 'implemented'")
    implemented_count = cursor.fetchone()[0]
    
    cursor = conn.execute("SELECT COUNT(*) FROM script_tags")
    total_tags = cursor.fetchone()[0]
    
    cursor = conn.execute("SELECT COUNT(*) FROM script_compatibility")
    compatibility_entries = cursor.fetchone()[0]
    
    print(f"\n📈 Database Summary:")
    print(f"  Total Scripts:        {total_scripts}")
    print(f"  Implemented Scripts:  {implemented_count}")
    print(f"  Implementation Rate:  {(implemented_count/total_scripts*100):.1f}%")
    print(f"  Total Tags:           {total_tags}")
    print(f"  Compatibility Rules:  {compatibility_entries}")
    
    conn.close()
    print(f"\n✅ Database test completed successfully!")

if __name__ == "__main__":
    test_database()