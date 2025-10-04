-- Correction des types dans la base de données
-- Niveau 0 = atomic, Niveau 1 = orchestrator
UPDATE scripts SET type = 'atomic' WHERE level = 0;
UPDATE scripts SET type = 'orchestrator' WHERE level = 1;

-- Vérification des corrections
SELECT name, level, type FROM scripts ORDER BY level, name;