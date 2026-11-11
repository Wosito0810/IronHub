-- =====================================================================
-- IRONHUB - Migración: planes especializados con planificación semanal
-- ---------------------------------------------------------------------
-- Requisito previo: haber ejecutado database/migracion_rutinas.sql
-- (aporta las columnas rutinas.tipo e id_usuario_propietario).
--
-- Esta migración:
--   1. Crea las tablas rutina_dias y rutina_dia_ejercicios.
--   2. Renombra el plan de fuerza de un solo día y añade Arnold Split.
--   3. Define los 7 días (entrenamiento o descanso) de los 6 planes.
--   4. Convierte las asignaciones especializadas antiguas en un plan
--      semanal completo (7 días) por cliente.
--   5. Conserva las rutinas personalizadas y sus asignaciones.
--
-- Es idempotente: puede ejecutarse más de una vez sin duplicar datos.
--
-- Uso:
--   mysql -u root -p ironhub_db < database/migracion_planes_semanales.sql
-- =====================================================================

USE ironhub_db;

-- Verificación amable del requisito previo
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_verificar_modulo_rutinas$$
CREATE PROCEDURE sp_verificar_modulo_rutinas()
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rutinas' AND COLUMN_NAME = 'tipo'
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ejecuta primero database/migracion_rutinas.sql';
    END IF;
END$$
DELIMITER ;

CALL sp_verificar_modulo_rutinas();
DROP PROCEDURE sp_verificar_modulo_rutinas;

-- ---------------------------------------------------------------------
-- 1. Planificación semanal de las rutinas especializadas
--    rutina_dias: un registro por día (incluye días de descanso)
--    rutina_dia_ejercicios: ejercicios concretos de cada día
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rutina_dias (
    id_rutina_dia INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_rutina INT UNSIGNED NOT NULL,
    dia_semana TINYINT UNSIGNED NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),
    enfoque VARCHAR(80) NOT NULL,
    es_descanso TINYINT(1) NOT NULL DEFAULT 0,
    CONSTRAINT fk_rd_rutina FOREIGN KEY (id_rutina) REFERENCES rutinas(id_rutina)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT uk_rutina_dia UNIQUE (id_rutina, dia_semana)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS rutina_dia_ejercicios (
    id_rutina_dia_ejercicio INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_rutina_dia INT UNSIGNED NOT NULL,
    id_ejercicio INT UNSIGNED NOT NULL,
    orden TINYINT UNSIGNED NOT NULL,
    series TINYINT UNSIGNED NOT NULL,
    repeticiones TINYINT UNSIGNED NOT NULL,
    CONSTRAINT fk_rde_dia FOREIGN KEY (id_rutina_dia) REFERENCES rutina_dias(id_rutina_dia)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_rde_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicios(id_ejercicio)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT uk_rutina_dia_orden UNIQUE (id_rutina_dia, orden)
) ENGINE=InnoDB;


-- ---------------------------------------------------------------------
-- 2. Altas y actualizaciones de los planes especializados
-- ---------------------------------------------------------------------
-- El antiguo plan de un solo día pasa a ser un programa semanal de fuerza.
UPDATE rutinas SET nombre = 'Fuerza 5x5 (3 Días - Fuerza Máxima)', descripcion = 'Fuerza máxima con sentadilla, press banca, remo, press militar y peso muerto. Tres sesiones A/B con progresión de cargas.'
WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Rutina de Fuerza Tren Superior%';

-- Fuerza 5x5 (si no existía el plan anterior)
INSERT INTO rutinas (id_entrenador, nombre, descripcion, tipo)
SELECT 1, 'Fuerza 5x5 (3 Días - Fuerza Máxima)', 'Fuerza máxima con sentadilla, press banca, remo, press militar y peso muerto. Tres sesiones A/B con progresión de cargas.', 'ESPECIALIZADA'
WHERE NOT EXISTS (SELECT 1 FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Fuerza 5x5%');

-- Nuevo plan Arnold Split
INSERT INTO rutinas (id_entrenador, nombre, descripcion, tipo)
SELECT 1, 'Arnold Split (6 Días - Volumen)', 'Split antagonista de seis días: pecho-espalda, hombros-brazos y piernas dos veces por semana. Volumen alto.', 'ESPECIALIZADA'
WHERE NOT EXISTS (SELECT 1 FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Arnold Split%');

UPDATE rutinas SET descripcion = 'División culturista por grupo muscular: pecho, espalda, hombros, piernas y brazos. Cinco sesiones de hipertrofia.' WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Rutina Weider%';
UPDATE rutinas SET descripcion = 'Empuje, tirón y pierna dos veces por semana. Seis sesiones que combinan fuerza al inicio y volumen al final.' WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Push-Pull-Legs%';
UPDATE rutinas SET descripcion = 'Dos sesiones de tren inferior y dos de torso. Énfasis en glúteos, femorales y cuádriceps con torso estético.' WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Torso-Pierna%';
UPDATE rutinas SET descripcion = 'Tres sesiones de cuerpo completo para recomposición: fuerza, gasto calórico y tonificación simultánea.' WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Full Body%';

SET @plan_fuerza := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Fuerza 5x5%' ORDER BY id_rutina LIMIT 1);
SET @plan_weider := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Rutina Weider%' ORDER BY id_rutina LIMIT 1);
SET @plan_ppl := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Push-Pull-Legs%' ORDER BY id_rutina LIMIT 1);
SET @plan_torso := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Torso-Pierna%' ORDER BY id_rutina LIMIT 1);
SET @plan_full := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Full Body%' ORDER BY id_rutina LIMIT 1);
SET @plan_arnold := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Arnold Split%' ORDER BY id_rutina LIMIT 1);

-- ---------------------------------------------------------------------
-- 3. Eliminar el detalle plano antiguo solo de los 6 planes migrados.
--    Las rutinas personalizadas y cualquier otro plan especializado
--    conservan intacto su detalle en rutina_ejercicios.
-- ---------------------------------------------------------------------
DELETE re FROM rutina_ejercicios re
JOIN rutinas r ON r.id_rutina = re.id_rutina
WHERE r.tipo = 'ESPECIALIZADA'
  AND (
      r.nombre LIKE 'Fuerza 5x5%'
      OR r.nombre LIKE 'Rutina Weider%'
      OR r.nombre LIKE 'Push-Pull-Legs%'
      OR r.nombre LIKE 'Torso-Pierna%'
      OR r.nombre LIKE 'Full Body%'
      OR r.nombre LIKE 'Arnold Split%'
  );

-- ---------------------------------------------------------------------
-- 4. Días, enfoques y ejercicios de cada plan semanal
-- ---------------------------------------------------------------------

-- Fuerza 5x5 (3 Días - Fuerza Máxima)
INSERT INTO rutina_dias (id_rutina, dia_semana, enfoque, es_descanso)
SELECT @plan_fuerza, d.dia, d.enfoque, d.es_descanso
FROM (
    SELECT 1 AS dia, 'Fuerza A · Cuerpo completo' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 2 AS dia, 'Descanso activo' AS enfoque, 1 AS es_descanso
    UNION ALL     SELECT 3 AS dia, 'Fuerza B · Cuerpo completo' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 4 AS dia, 'Descanso' AS enfoque, 1 AS es_descanso
    UNION ALL     SELECT 5 AS dia, 'Fuerza A · Cuerpo completo' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 6 AS dia, 'Movilidad y recuperación' AS enfoque, 1 AS es_descanso
    UNION ALL     SELECT 7 AS dia, 'Descanso' AS enfoque, 1 AS es_descanso
) AS d
WHERE @plan_fuerza IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM rutina_dias rd WHERE rd.id_rutina = @plan_fuerza AND rd.dia_semana = d.dia);

INSERT INTO rutina_dia_ejercicios (id_rutina_dia, id_ejercicio, orden, series, repeticiones)
SELECT rd.id_rutina_dia, e.id_ejercicio, x.orden, x.series, x.repeticiones
FROM rutina_dias rd
JOIN (
    SELECT 1 AS dia, 'Sentadilla libre profunda' AS nombre, 1 AS orden, 5 AS series, 5 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Press de banca plano con barra' AS nombre, 2 AS orden, 5 AS series, 5 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Remo con barra' AS nombre, 3 AS orden, 5 AS series, 5 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Plancha abdominal' AS nombre, 4 AS orden, 3 AS series, 45 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Sentadilla libre profunda' AS nombre, 1 AS orden, 5 AS series, 5 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Press militar' AS nombre, 2 AS orden, 5 AS series, 5 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Peso muerto convencional' AS nombre, 3 AS orden, 1 AS series, 5 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Dominadas' AS nombre, 4 AS orden, 3 AS series, 8 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Sentadilla libre profunda' AS nombre, 1 AS orden, 5 AS series, 5 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Press de banca plano con barra' AS nombre, 2 AS orden, 5 AS series, 5 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Remo con barra' AS nombre, 3 AS orden, 5 AS series, 5 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Plancha abdominal' AS nombre, 4 AS orden, 3 AS series, 45 AS repeticiones
) AS x ON x.dia = rd.dia_semana
JOIN ejercicios e ON e.nombre = x.nombre
WHERE rd.id_rutina = @plan_fuerza
  AND NOT EXISTS (SELECT 1 FROM rutina_dia_ejercicios rde WHERE rde.id_rutina_dia = rd.id_rutina_dia AND rde.orden = x.orden);

-- Rutina Weider (5 Días - Hipertrofia Torso)
INSERT INTO rutina_dias (id_rutina, dia_semana, enfoque, es_descanso)
SELECT @plan_weider, d.dia, d.enfoque, d.es_descanso
FROM (
    SELECT 1 AS dia, 'Pecho' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 2 AS dia, 'Espalda' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 3 AS dia, 'Hombros y abdominales' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 4 AS dia, 'Piernas' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 5 AS dia, 'Brazos' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 6 AS dia, 'Descanso' AS enfoque, 1 AS es_descanso
    UNION ALL     SELECT 7 AS dia, 'Descanso' AS enfoque, 1 AS es_descanso
) AS d
WHERE @plan_weider IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM rutina_dias rd WHERE rd.id_rutina = @plan_weider AND rd.dia_semana = d.dia);

INSERT INTO rutina_dia_ejercicios (id_rutina_dia, id_ejercicio, orden, series, repeticiones)
SELECT rd.id_rutina_dia, e.id_ejercicio, x.orden, x.series, x.repeticiones
FROM rutina_dias rd
JOIN (
    SELECT 1 AS dia, 'Press de banca plano con barra' AS nombre, 1 AS orden, 4 AS series, 8 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Press inclinado con mancuernas' AS nombre, 2 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Aperturas en polea' AS nombre, 3 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Fondos en paralelas' AS nombre, 4 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Dominadas' AS nombre, 1 AS orden, 4 AS series, 8 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Remo con barra' AS nombre, 2 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Jalón al pecho' AS nombre, 3 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Pullover' AS nombre, 4 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Press militar' AS nombre, 1 AS orden, 4 AS series, 8 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Elevaciones laterales' AS nombre, 2 AS orden, 4 AS series, 12 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Pájaros' AS nombre, 3 AS orden, 3 AS series, 15 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Plancha abdominal' AS nombre, 4 AS orden, 3 AS series, 45 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Sentadilla libre profunda' AS nombre, 1 AS orden, 4 AS series, 8 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Prensa de piernas' AS nombre, 2 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Peso muerto rumano' AS nombre, 3 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Extensión de cuádriceps' AS nombre, 4 AS orden, 3 AS series, 15 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Elevación de talones de pie' AS nombre, 5 AS orden, 4 AS series, 15 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Curl de bíceps con barra' AS nombre, 1 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Curl martillo' AS nombre, 2 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Fondos en paralelas (Tríceps)' AS nombre, 3 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Extensión de tríceps en polea' AS nombre, 4 AS orden, 3 AS series, 12 AS repeticiones
) AS x ON x.dia = rd.dia_semana
JOIN ejercicios e ON e.nombre = x.nombre
WHERE rd.id_rutina = @plan_weider
  AND NOT EXISTS (SELECT 1 FROM rutina_dia_ejercicios rde WHERE rde.id_rutina_dia = rd.id_rutina_dia AND rde.orden = x.orden);

-- Push-Pull-Legs (Empuje-Tirón-Pierna)
INSERT INTO rutina_dias (id_rutina, dia_semana, enfoque, es_descanso)
SELECT @plan_ppl, d.dia, d.enfoque, d.es_descanso
FROM (
    SELECT 1 AS dia, 'Push · Empuje (fuerza)' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 2 AS dia, 'Pull · Tirón (fuerza)' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 3 AS dia, 'Legs · Piernas (fuerza)' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 4 AS dia, 'Push · Empuje (volumen)' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 5 AS dia, 'Pull · Tirón (volumen)' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 6 AS dia, 'Legs · Piernas (volumen)' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 7 AS dia, 'Descanso' AS enfoque, 1 AS es_descanso
) AS d
WHERE @plan_ppl IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM rutina_dias rd WHERE rd.id_rutina = @plan_ppl AND rd.dia_semana = d.dia);

INSERT INTO rutina_dia_ejercicios (id_rutina_dia, id_ejercicio, orden, series, repeticiones)
SELECT rd.id_rutina_dia, e.id_ejercicio, x.orden, x.series, x.repeticiones
FROM rutina_dias rd
JOIN (
    SELECT 1 AS dia, 'Press de banca plano con barra' AS nombre, 1 AS orden, 4 AS series, 6 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Press militar' AS nombre, 2 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Fondos en paralelas' AS nombre, 3 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Elevaciones laterales' AS nombre, 4 AS orden, 4 AS series, 12 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Peso muerto convencional' AS nombre, 1 AS orden, 3 AS series, 5 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Jalón al pecho' AS nombre, 2 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Remo con mancuerna a una mano' AS nombre, 3 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Face pulls' AS nombre, 4 AS orden, 3 AS series, 15 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Sentadilla libre profunda' AS nombre, 1 AS orden, 4 AS series, 6 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Prensa de piernas' AS nombre, 2 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Curl femoral (tumbado o sentado)' AS nombre, 3 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Elevación de talones de pie' AS nombre, 4 AS orden, 4 AS series, 12 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Press de banca plano con mancuernas' AS nombre, 1 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Press de hombros sentado con mancuernas' AS nombre, 2 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Aperturas en polea' AS nombre, 3 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Extensión de tríceps en polea' AS nombre, 4 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Dominadas' AS nombre, 1 AS orden, 4 AS series, 8 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Remo con barra' AS nombre, 2 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Remo en polea baja / Gironda' AS nombre, 3 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Curl de bíceps con barra' AS nombre, 4 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 6 AS dia, 'Sentadilla búlgara' AS nombre, 1 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 6 AS dia, 'Peso muerto rumano' AS nombre, 2 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 6 AS dia, 'Extensión de cuádriceps' AS nombre, 3 AS orden, 3 AS series, 15 AS repeticiones
    UNION ALL     SELECT 6 AS dia, 'Elevación de talones sentado' AS nombre, 4 AS orden, 4 AS series, 15 AS repeticiones
) AS x ON x.dia = rd.dia_semana
JOIN ejercicios e ON e.nombre = x.nombre
WHERE rd.id_rutina = @plan_ppl
  AND NOT EXISTS (SELECT 1 FROM rutina_dia_ejercicios rde WHERE rde.id_rutina_dia = rd.id_rutina_dia AND rde.orden = x.orden);

-- Torso-Pierna (Énfasis Glúteos y Piernas)
INSERT INTO rutina_dias (id_rutina, dia_semana, enfoque, es_descanso)
SELECT @plan_torso, d.dia, d.enfoque, d.es_descanso
FROM (
    SELECT 1 AS dia, 'Pierna · Glúteo y femoral' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 2 AS dia, 'Torso · Empuje y tracción' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 3 AS dia, 'Descanso' AS enfoque, 1 AS es_descanso
    UNION ALL     SELECT 4 AS dia, 'Pierna · Cuádriceps y femoral' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 5 AS dia, 'Torso · Hombro y espalda' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 6 AS dia, 'Descanso' AS enfoque, 1 AS es_descanso
    UNION ALL     SELECT 7 AS dia, 'Descanso' AS enfoque, 1 AS es_descanso
) AS d
WHERE @plan_torso IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM rutina_dias rd WHERE rd.id_rutina = @plan_torso AND rd.dia_semana = d.dia);

INSERT INTO rutina_dia_ejercicios (id_rutina_dia, id_ejercicio, orden, series, repeticiones)
SELECT rd.id_rutina_dia, e.id_ejercicio, x.orden, x.series, x.repeticiones
FROM rutina_dias rd
JOIN (
    SELECT 1 AS dia, 'Hip Thrust con barra' AS nombre, 1 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Sentadilla búlgara' AS nombre, 2 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Peso muerto rumano' AS nombre, 3 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Patada de glúteo en polea' AS nombre, 4 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Jalón al pecho' AS nombre, 1 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Press de banca plano con mancuernas' AS nombre, 2 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Elevaciones laterales' AS nombre, 3 AS orden, 4 AS series, 12 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Plancha abdominal' AS nombre, 4 AS orden, 3 AS series, 45 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Sentadilla libre profunda' AS nombre, 1 AS orden, 4 AS series, 8 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Prensa de piernas' AS nombre, 2 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Curl femoral (tumbado o sentado)' AS nombre, 3 AS orden, 4 AS series, 12 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Extensión de cuádriceps' AS nombre, 4 AS orden, 3 AS series, 15 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Press militar' AS nombre, 1 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Remo en polea baja / Gironda' AS nombre, 2 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Face pulls' AS nombre, 3 AS orden, 3 AS series, 15 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Crunches' AS nombre, 4 AS orden, 3 AS series, 15 AS repeticiones
) AS x ON x.dia = rd.dia_semana
JOIN ejercicios e ON e.nombre = x.nombre
WHERE rd.id_rutina = @plan_torso
  AND NOT EXISTS (SELECT 1 FROM rutina_dia_ejercicios rde WHERE rde.id_rutina_dia = rd.id_rutina_dia AND rde.orden = x.orden);

-- Full Body (Recomposición Corporal)
INSERT INTO rutina_dias (id_rutina, dia_semana, enfoque, es_descanso)
SELECT @plan_full, d.dia, d.enfoque, d.es_descanso
FROM (
    SELECT 1 AS dia, 'Full Body A' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 2 AS dia, 'Descanso' AS enfoque, 1 AS es_descanso
    UNION ALL     SELECT 3 AS dia, 'Full Body B' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 4 AS dia, 'Descanso' AS enfoque, 1 AS es_descanso
    UNION ALL     SELECT 5 AS dia, 'Full Body C' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 6 AS dia, 'Descanso' AS enfoque, 1 AS es_descanso
    UNION ALL     SELECT 7 AS dia, 'Descanso' AS enfoque, 1 AS es_descanso
) AS d
WHERE @plan_full IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM rutina_dias rd WHERE rd.id_rutina = @plan_full AND rd.dia_semana = d.dia);

INSERT INTO rutina_dia_ejercicios (id_rutina_dia, id_ejercicio, orden, series, repeticiones)
SELECT rd.id_rutina_dia, e.id_ejercicio, x.orden, x.series, x.repeticiones
FROM rutina_dias rd
JOIN (
    SELECT 1 AS dia, 'Sentadilla libre profunda' AS nombre, 1 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Jalón al pecho' AS nombre, 2 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Hip Thrust con barra' AS nombre, 3 AS orden, 4 AS series, 12 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Press inclinado con mancuernas' AS nombre, 4 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Peso muerto rumano' AS nombre, 1 AS orden, 4 AS series, 8 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Press de hombros sentado con mancuernas' AS nombre, 2 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Sentadilla búlgara' AS nombre, 3 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Remo con barra' AS nombre, 4 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Prensa de piernas' AS nombre, 1 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Hip Thrust en máquina' AS nombre, 2 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Flexiones de pecho' AS nombre, 3 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Abdominales bicicleta' AS nombre, 4 AS orden, 3 AS series, 20 AS repeticiones
) AS x ON x.dia = rd.dia_semana
JOIN ejercicios e ON e.nombre = x.nombre
WHERE rd.id_rutina = @plan_full
  AND NOT EXISTS (SELECT 1 FROM rutina_dia_ejercicios rde WHERE rde.id_rutina_dia = rd.id_rutina_dia AND rde.orden = x.orden);

-- Arnold Split (6 Días - Volumen)
INSERT INTO rutina_dias (id_rutina, dia_semana, enfoque, es_descanso)
SELECT @plan_arnold, d.dia, d.enfoque, d.es_descanso
FROM (
    SELECT 1 AS dia, 'Pecho y espalda A' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 2 AS dia, 'Hombros y brazos A' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 3 AS dia, 'Piernas A' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 4 AS dia, 'Pecho y espalda B' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 5 AS dia, 'Hombros y brazos B' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 6 AS dia, 'Piernas B' AS enfoque, 0 AS es_descanso
    UNION ALL     SELECT 7 AS dia, 'Descanso' AS enfoque, 1 AS es_descanso
) AS d
WHERE @plan_arnold IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM rutina_dias rd WHERE rd.id_rutina = @plan_arnold AND rd.dia_semana = d.dia);

INSERT INTO rutina_dia_ejercicios (id_rutina_dia, id_ejercicio, orden, series, repeticiones)
SELECT rd.id_rutina_dia, e.id_ejercicio, x.orden, x.series, x.repeticiones
FROM rutina_dias rd
JOIN (
    SELECT 1 AS dia, 'Press de banca plano con barra' AS nombre, 1 AS orden, 4 AS series, 8 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Press inclinado con mancuernas' AS nombre, 2 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Aperturas en polea' AS nombre, 3 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Dominadas' AS nombre, 4 AS orden, 4 AS series, 8 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Remo con barra' AS nombre, 5 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 1 AS dia, 'Pullover' AS nombre, 6 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Press militar' AS nombre, 1 AS orden, 4 AS series, 8 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Elevaciones laterales' AS nombre, 2 AS orden, 4 AS series, 12 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Pájaros' AS nombre, 3 AS orden, 3 AS series, 15 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Curl de bíceps con barra' AS nombre, 4 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Curl de bíceps inclinado' AS nombre, 5 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Fondos en paralelas (Tríceps)' AS nombre, 6 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 2 AS dia, 'Press francés' AS nombre, 7 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Sentadilla libre profunda' AS nombre, 1 AS orden, 4 AS series, 8 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Prensa de piernas' AS nombre, 2 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Extensión de cuádriceps' AS nombre, 3 AS orden, 3 AS series, 15 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Curl femoral (tumbado o sentado)' AS nombre, 4 AS orden, 4 AS series, 12 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Peso muerto rumano' AS nombre, 5 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 3 AS dia, 'Elevación de talones de pie' AS nombre, 6 AS orden, 4 AS series, 15 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Press de banca plano con mancuernas' AS nombre, 1 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Fondos en paralelas' AS nombre, 2 AS orden, 3 AS series, 10 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Aperturas en polea' AS nombre, 3 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Jalón al pecho' AS nombre, 4 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Remo con mancuerna a una mano' AS nombre, 5 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 4 AS dia, 'Remo en polea baja / Gironda' AS nombre, 6 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Press de hombros sentado con mancuernas' AS nombre, 1 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Elevaciones laterales' AS nombre, 2 AS orden, 3 AS series, 15 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Face pulls' AS nombre, 3 AS orden, 3 AS series, 15 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Curl martillo' AS nombre, 4 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Curl de bíceps alterno' AS nombre, 5 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Extensión de tríceps en polea' AS nombre, 6 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 5 AS dia, 'Copa de tríceps' AS nombre, 7 AS orden, 3 AS series, 12 AS repeticiones
    UNION ALL     SELECT 6 AS dia, 'Sentadilla búlgara' AS nombre, 1 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 6 AS dia, 'Peso muerto rumano' AS nombre, 2 AS orden, 4 AS series, 10 AS repeticiones
    UNION ALL     SELECT 6 AS dia, 'Hip Thrust con barra' AS nombre, 3 AS orden, 4 AS series, 12 AS repeticiones
    UNION ALL     SELECT 6 AS dia, 'Curl femoral (tumbado o sentado)' AS nombre, 4 AS orden, 4 AS series, 12 AS repeticiones
    UNION ALL     SELECT 6 AS dia, 'Elevación de talones sentado' AS nombre, 5 AS orden, 4 AS series, 15 AS repeticiones
    UNION ALL     SELECT 6 AS dia, 'Plancha abdominal' AS nombre, 6 AS orden, 3 AS series, 45 AS repeticiones
) AS x ON x.dia = rd.dia_semana
JOIN ejercicios e ON e.nombre = x.nombre
WHERE rd.id_rutina = @plan_arnold
  AND NOT EXISTS (SELECT 1 FROM rutina_dia_ejercicios rde WHERE rde.id_rutina_dia = rd.id_rutina_dia AND rde.orden = x.orden);

-- ---------------------------------------------------------------------
-- 5. Convertir las asignaciones especializadas antiguas en plan semanal
--    Se conserva el plan especializado más reciente de cada cliente.
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_plan_activo;
CREATE TEMPORARY TABLE tmp_plan_activo AS
SELECT a.id_cliente, a.id_rutina
FROM asignaciones a
JOIN rutinas r ON r.id_rutina = a.id_rutina
WHERE r.tipo = 'ESPECIALIZADA'
  AND a.id_asignacion = (
      SELECT MAX(a2.id_asignacion)
      FROM asignaciones a2
      JOIN rutinas r2 ON r2.id_rutina = a2.id_rutina
      WHERE r2.tipo = 'ESPECIALIZADA' AND a2.id_cliente = a.id_cliente
  );

DELETE a FROM asignaciones a
JOIN rutinas r ON r.id_rutina = a.id_rutina
WHERE r.tipo = 'ESPECIALIZADA';

INSERT INTO asignaciones (id_cliente, id_rutina, dia_semana)
SELECT t.id_cliente, t.id_rutina, d.dia
FROM tmp_plan_activo t
CROSS JOIN (
    SELECT 1 AS dia UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
) d
WHERE EXISTS (
    SELECT 1 FROM rutina_dias rd
    WHERE rd.id_rutina = t.id_rutina AND rd.dia_semana = d.dia
)
AND NOT EXISTS (
    SELECT 1 FROM asignaciones a
    WHERE a.id_cliente = t.id_cliente AND a.id_rutina = t.id_rutina AND a.dia_semana = d.dia
);

DROP TEMPORARY TABLE IF EXISTS tmp_plan_activo;

-- ---------------------------------------------------------------------
-- 6. Vista de plan semanal con el tipo de rutina
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_plan_semanal AS
SELECT c.id_cliente, u.nombre, u.apellido, a.dia_semana, r.nombre AS rutina_nombre, r.tipo
FROM clientes c
JOIN usuarios u ON c.id_usuario = u.id_usuario
JOIN asignaciones a ON c.id_cliente = a.id_cliente
JOIN rutinas r ON a.id_rutina = r.id_rutina;
