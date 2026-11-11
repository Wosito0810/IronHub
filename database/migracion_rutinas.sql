-- =====================================================================
-- IRONHUB - Migración del módulo de rutinas
-- ---------------------------------------------------------------------
-- Se ejecuta UNA sola vez sobre una base de datos ironhub_db existente.
-- Conserva todos los datos actuales (usuarios, rutinas, asignaciones).
-- Es idempotente: si el cambio ya está aplicado, no vuelve a hacerlo.
--
-- Uso:
--   mysql -u root -p ironhub_db < database/migracion_rutinas.sql
--   (o abrir el archivo en MySQL Workbench y ejecutarlo completo)
-- =====================================================================

USE ironhub_db;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_ironhub_add_column$$
CREATE PROCEDURE sp_ironhub_add_column(IN p_tabla VARCHAR(64), IN p_columna VARCHAR(64), IN p_definicion TEXT)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = p_tabla AND COLUMN_NAME = p_columna
    ) THEN
        SET @ddl = CONCAT('ALTER TABLE `', p_tabla, '` ADD COLUMN `', p_columna, '` ', p_definicion);
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$

DROP PROCEDURE IF EXISTS sp_ironhub_add_index$$
CREATE PROCEDURE sp_ironhub_add_index(IN p_tabla VARCHAR(64), IN p_indice VARCHAR(64), IN p_definicion TEXT)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = p_tabla AND INDEX_NAME = p_indice
    ) THEN
        SET @ddl = CONCAT('ALTER TABLE `', p_tabla, '` ADD ', p_definicion);
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$

DROP PROCEDURE IF EXISTS sp_ironhub_drop_index$$
CREATE PROCEDURE sp_ironhub_drop_index(IN p_tabla VARCHAR(64), IN p_indice VARCHAR(64))
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = p_tabla AND INDEX_NAME = p_indice
    ) THEN
        SET @ddl = CONCAT('ALTER TABLE `', p_tabla, '` DROP INDEX `', p_indice, '`');
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$

DROP PROCEDURE IF EXISTS sp_ironhub_add_fk$$
CREATE PROCEDURE sp_ironhub_add_fk(IN p_nombre VARCHAR(64), IN p_definicion TEXT)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.TABLE_CONSTRAINTS
        WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = p_nombre
    ) THEN
        SET @ddl = CONCAT('ALTER TABLE rutinas ADD CONSTRAINT `', p_nombre, '` ', p_definicion);
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- 1. Nuevas columnas en rutinas
--    tipo: ESPECIALIZADA (plantilla del gimnasio) o PERSONALIZADA (cliente)
--    id_usuario_propietario: dueño del plan personalizado
-- ---------------------------------------------------------------------
CALL sp_ironhub_add_column('rutinas', 'tipo', "ENUM('ESPECIALIZADA','PERSONALIZADA') NOT NULL DEFAULT 'ESPECIALIZADA'");
CALL sp_ironhub_add_column('rutinas', 'id_usuario_propietario', 'INT UNSIGNED NULL');

CALL sp_ironhub_add_fk(
    'fk_rutina_propietario',
    'FOREIGN KEY (`id_usuario_propietario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE ON UPDATE CASCADE'
);

UPDATE rutinas SET tipo = 'ESPECIALIZADA' WHERE tipo IS NULL;
UPDATE rutinas SET id_usuario_propietario = NULL WHERE tipo = 'ESPECIALIZADA';

-- ---------------------------------------------------------------------
-- 2. Varias rutinas por día y por cliente (antes solo se permitía una)
-- ---------------------------------------------------------------------
CALL sp_ironhub_add_index(
    'asignaciones', 'idx_asig_cliente_dia',
    'INDEX `idx_asig_cliente_dia` (`id_cliente`, `dia_semana`)'
);
CALL sp_ironhub_drop_index('asignaciones', 'uk_cliente_dia');
CALL sp_ironhub_add_index(
    'asignaciones', 'uk_cliente_dia_rutina',
    'UNIQUE KEY `uk_cliente_dia_rutina` (`id_cliente`, `dia_semana`, `id_rutina`)'
);

-- ---------------------------------------------------------------------
-- 3. Garantizar que los planes especializados existan
-- ---------------------------------------------------------------------
INSERT INTO rutinas (id_entrenador, nombre, descripcion, tipo)
SELECT 1, 'Rutina Weider (5 Días - Hipertrofia Torso)',
       'Enfoque culturismo tradicional para volumen máximo en torso y extremidades.', 'ESPECIALIZADA'
WHERE NOT EXISTS (SELECT 1 FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Rutina Weider%');

INSERT INTO rutinas (id_entrenador, nombre, descripcion, tipo)
SELECT 1, 'Push-Pull-Legs (Empuje-Tirón-Pierna)',
       'La distribución más eficiente y famosa del fitness moderno para fuerza e hipertrofia.', 'ESPECIALIZADA'
WHERE NOT EXISTS (SELECT 1 FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Push-Pull-Legs%');

INSERT INTO rutinas (id_entrenador, nombre, descripcion, tipo)
SELECT 1, 'Torso-Pierna (Énfasis Glúteos y Piernas)',
       'Prioriza alta frecuencia y volumen en el tren inferior con torso estético.', 'ESPECIALIZADA'
WHERE NOT EXISTS (SELECT 1 FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Torso-Pierna%');

INSERT INTO rutinas (id_entrenador, nombre, descripcion, tipo)
SELECT 1, 'Full Body (Recomposición Corporal)',
       'Cuerpo completo ideal para quema calórica alta y tonificación simultánea.', 'ESPECIALIZADA'
WHERE NOT EXISTS (SELECT 1 FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Full Body%');

-- ---------------------------------------------------------------------
-- 4. Catálogo: grupos musculares correctos y ejercicios faltantes
--    (el script anterior dejó glúteos en "Pecho", cuádriceps en
--     "Espalda", pantorrillas en "Piernas" y perdió los tríceps)
-- ---------------------------------------------------------------------
INSERT IGNORE INTO grupos_musculares (nombre) VALUES
('Glúteos y Femorales'), ('Cuádriceps'), ('Pantorrillas');

-- Unificar "Abdomen" dentro de "Abdominales"
UPDATE ejercicios e
JOIN grupos_musculares origen ON origen.nombre = 'Abdomen'
JOIN grupos_musculares destino ON destino.nombre = 'Abdominales'
SET e.id_grupo = destino.id_grupo
WHERE e.id_grupo = origen.id_grupo;

SET @grupo_gluteos   := (SELECT id_grupo FROM grupos_musculares WHERE nombre = 'Glúteos y Femorales');
SET @grupo_cuadriceps := (SELECT id_grupo FROM grupos_musculares WHERE nombre = 'Cuádriceps');
SET @grupo_pantorrillas := (SELECT id_grupo FROM grupos_musculares WHERE nombre = 'Pantorrillas');
SET @grupo_pecho     := (SELECT id_grupo FROM grupos_musculares WHERE nombre = 'Pecho');
SET @grupo_espalda   := (SELECT id_grupo FROM grupos_musculares WHERE nombre = 'Espalda');
SET @grupo_hombros   := (SELECT id_grupo FROM grupos_musculares WHERE nombre = 'Hombros');
SET @grupo_biceps    := (SELECT id_grupo FROM grupos_musculares WHERE nombre = 'Bíceps');
SET @grupo_triceps   := (SELECT id_grupo FROM grupos_musculares WHERE nombre = 'Tríceps');

UPDATE ejercicios SET id_grupo = @grupo_gluteos WHERE nombre IN (
    'Hip Thrust con barra', 'Hip Thrust en máquina', 'Peso muerto rumano',
    'Peso muerto convencional', 'Patada de glúteo en polea',
    'Abductores en máquina o polea', 'Curl femoral (tumbado o sentado)', 'Hiperextensiones'
);

UPDATE ejercicios SET id_grupo = @grupo_cuadriceps WHERE nombre IN (
    'Sentadilla libre profunda', 'Sentadilla en máquina Smith', 'Sentadilla Goblet',
    'Sentadilla búlgara', 'Prensa de piernas', 'Zancadas', 'Extensión de cuádriceps',
    'Sentadilla Libre con Barra'
);

UPDATE ejercicios SET id_grupo = @grupo_pantorrillas WHERE nombre IN (
    'Elevación de talones de pie', 'Elevación de talones sentado'
);

UPDATE ejercicios SET id_grupo = @grupo_pecho WHERE nombre IN (
    'Press de Banca Plano', 'Press de banca plano con barra', 'Press inclinado con mancuernas',
    'Press de banca plano con mancuernas', 'Aperturas en polea', 'Fondos en paralelas',
    'Flexiones de pecho'
);

UPDATE ejercicios SET id_grupo = @grupo_espalda WHERE nombre IN (
    'Dominadas en Barra', 'Dominadas', 'Jalón al pecho', 'Remo con barra',
    'Remo con mancuerna a una mano', 'Remo en polea baja / Gironda', 'Pullover'
);

UPDATE ejercicios SET id_grupo = @grupo_hombros WHERE nombre IN (
    'Press militar', 'Press de hombros sentado con mancuernas', 'Elevaciones laterales',
    'Pájaros', 'Face pulls'
);

UPDATE ejercicios SET id_grupo = @grupo_biceps WHERE nombre IN (
    'Curl de bíceps con barra', 'Curl de bíceps inclinado', 'Curl de bíceps alterno', 'Curl martillo'
);

INSERT IGNORE INTO ejercicios (id_grupo, nombre, descripcion) VALUES
(@grupo_triceps, 'Extensión de tríceps en polea', 'Con barra recta o cuerda'),
(@grupo_triceps, 'Copa de tríceps', 'Extensión sobre la cabeza con mancuerna'),
(@grupo_triceps, 'Press francés', 'Con barra Z tumbado en banco'),
(@grupo_triceps, 'Fondos en paralelas (Tríceps)', 'Con agarre estrecho para tríceps');

-- Limpiar grupos que quedaron vacíos y duplicados
DELETE FROM grupos_musculares
WHERE nombre IN ('Abdomen', 'Piernas')
  AND NOT EXISTS (SELECT 1 FROM ejercicios e WHERE e.id_grupo = grupos_musculares.id_grupo);

-- ---------------------------------------------------------------------
-- 5. Detalle real de los planes especializados
-- ---------------------------------------------------------------------
SET @plan_weider := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Rutina Weider%' ORDER BY id_rutina LIMIT 1);

INSERT INTO rutina_ejercicios (id_rutina, id_ejercicio, orden, series, repeticiones)
SELECT @plan_weider, e.id_ejercicio, p.orden, p.series, p.repeticiones
FROM (
    SELECT 'Press de banca plano con barra' AS nombre, 1 AS orden, 4 AS series, 8 AS repeticiones
    UNION ALL SELECT 'Press inclinado con mancuernas', 2, 4, 10
    UNION ALL SELECT 'Aperturas en polea', 3, 3, 12
    UNION ALL SELECT 'Dominadas', 4, 4, 8
    UNION ALL SELECT 'Remo con barra', 5, 4, 10
    UNION ALL SELECT 'Press militar', 6, 4, 8
    UNION ALL SELECT 'Elevaciones laterales', 7, 4, 12
    UNION ALL SELECT 'Curl de bíceps con barra', 8, 3, 10
) AS p
JOIN ejercicios e ON e.nombre = p.nombre
WHERE @plan_weider IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM rutina_ejercicios re WHERE re.id_rutina = @plan_weider AND re.orden = p.orden
  );

SET @plan_ppl := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Push-Pull-Legs%' ORDER BY id_rutina LIMIT 1);

INSERT INTO rutina_ejercicios (id_rutina, id_ejercicio, orden, series, repeticiones)
SELECT @plan_ppl, e.id_ejercicio, p.orden, p.series, p.repeticiones
FROM (
    SELECT 'Press de banca plano con barra' AS nombre, 1 AS orden, 4 AS series, 6 AS repeticiones
    UNION ALL SELECT 'Press militar', 2, 3, 10
    UNION ALL SELECT 'Fondos en paralelas', 3, 3, 10
    UNION ALL SELECT 'Elevaciones laterales', 4, 4, 12
    UNION ALL SELECT 'Jalón al pecho', 5, 4, 10
    UNION ALL SELECT 'Remo con mancuerna a una mano', 6, 3, 10
    UNION ALL SELECT 'Face pulls', 7, 3, 15
    UNION ALL SELECT 'Sentadilla libre profunda', 8, 4, 6
) AS p
JOIN ejercicios e ON e.nombre = p.nombre
WHERE @plan_ppl IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM rutina_ejercicios re WHERE re.id_rutina = @plan_ppl AND re.orden = p.orden
  );

SET @plan_torso := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Torso-Pierna%' ORDER BY id_rutina LIMIT 1);

INSERT INTO rutina_ejercicios (id_rutina, id_ejercicio, orden, series, repeticiones)
SELECT @plan_torso, e.id_ejercicio, p.orden, p.series, p.repeticiones
FROM (
    SELECT 'Hip Thrust con barra' AS nombre, 1 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL SELECT 'Sentadilla búlgara', 2, 3, 10
    UNION ALL SELECT 'Peso muerto rumano', 3, 4, 10
    UNION ALL SELECT 'Patada de glúteo en polea', 4, 3, 12
    UNION ALL SELECT 'Prensa de piernas', 5, 3, 12
    UNION ALL SELECT 'Curl femoral (tumbado o sentado)', 6, 4, 12
    UNION ALL SELECT 'Elevaciones laterales', 7, 4, 12
    UNION ALL SELECT 'Plancha abdominal', 8, 3, 45
) AS p
JOIN ejercicios e ON e.nombre = p.nombre
WHERE @plan_torso IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM rutina_ejercicios re WHERE re.id_rutina = @plan_torso AND re.orden = p.orden
  );

SET @plan_full := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Full Body%' ORDER BY id_rutina LIMIT 1);

INSERT INTO rutina_ejercicios (id_rutina, id_ejercicio, orden, series, repeticiones)
SELECT @plan_full, e.id_ejercicio, p.orden, p.series, p.repeticiones
FROM (
    SELECT 'Sentadilla libre profunda' AS nombre, 1 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL SELECT 'Jalón al pecho', 2, 3, 10
    UNION ALL SELECT 'Hip Thrust con barra', 3, 4, 12
    UNION ALL SELECT 'Press inclinado con mancuernas', 4, 3, 12
    UNION ALL SELECT 'Peso muerto rumano', 5, 4, 8
    UNION ALL SELECT 'Press de hombros sentado con mancuernas', 6, 3, 10
    UNION ALL SELECT 'Remo con barra', 7, 3, 10
    UNION ALL SELECT 'Abdominales bicicleta', 8, 3, 20
) AS p
JOIN ejercicios e ON e.nombre = p.nombre
WHERE @plan_full IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM rutina_ejercicios re WHERE re.id_rutina = @plan_full AND re.orden = p.orden
  );

-- ---------------------------------------------------------------------
-- 6. Perfil de cliente para todos los usuarios con rol CLIENTE
--    (varios usuarios de prueba no lo tenían y no podían guardar rutinas)
-- ---------------------------------------------------------------------
INSERT INTO clientes (id_usuario, documento, fecha_nacimiento, objetivo)
SELECT u.id_usuario, CONCAT('AUTO-', LPAD(u.id_usuario, 6, '0')), NULL,
       'Perfil creado automáticamente por IRONHUB'
FROM usuarios u
LEFT JOIN clientes c ON c.id_usuario = u.id_usuario
WHERE u.id_rol = 2 AND c.id_cliente IS NULL;

-- ---------------------------------------------------------------------
-- 7. Limpieza de procedimientos temporales
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ironhub_add_column;
DROP PROCEDURE IF EXISTS sp_ironhub_add_index;
DROP PROCEDURE IF EXISTS sp_ironhub_drop_index;
DROP PROCEDURE IF EXISTS sp_ironhub_add_fk;
