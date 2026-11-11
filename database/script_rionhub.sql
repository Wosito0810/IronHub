-- =====================================================================
-- PROYECTO DE AULA: IRONHUB - Sistema de Gestión de Gimnasio
-- Asignatura: Diseño de Software 1
-- Motor: MySQL 8.0 (Normalizado hasta 3FN, Integridad Referencial, Vistas)
-- Autores: Moisés Baquero, Sergio Cristancho, David Vargas
-- ---------------------------------------------------------------------
-- Este script crea la base de datos DESDE CERO.
-- Si ya tienes datos, ejecuta en orden:
--   1) database/migracion_rutinas.sql
--   2) database/migracion_planes_semanales.sql
-- =====================================================================

DROP DATABASE IF EXISTS ironhub_db;
CREATE DATABASE ironhub_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ironhub_db;

-- -----------------------------------------------------
-- 1. Tabla: roles
-- -----------------------------------------------------
CREATE TABLE roles (
    id_rol TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(20) NOT NULL UNIQUE COMMENT 'ADMIN o CLIENTE'
) ENGINE=InnoDB;

INSERT INTO roles (nombre) VALUES ('ADMIN'), ('CLIENTE');

-- -----------------------------------------------------
-- 2. Tabla: usuarios
-- -----------------------------------------------------
CREATE TABLE usuarios (
    id_usuario INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_rol TINYINT UNSIGNED NOT NULL,
    nombre VARCHAR(60) NOT NULL,
    apellido VARCHAR(60) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL COMMENT 'Contraseña del usuario',
    telefono VARCHAR(20) DEFAULT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_usuario_rol FOREIGN KEY (id_rol) REFERENCES roles(id_rol)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 3. Tabla: clientes
-- -----------------------------------------------------
CREATE TABLE clientes (
    id_cliente INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT UNSIGNED NOT NULL UNIQUE,
    documento VARCHAR(20) NOT NULL UNIQUE,
    fecha_nacimiento DATE DEFAULT NULL,
    objetivo VARCHAR(150) DEFAULT 'Hipertrofia y acondicionamiento general',
    CONSTRAINT fk_cliente_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 4. Tabla: grupos_musculares
-- -----------------------------------------------------
CREATE TABLE grupos_musculares (
    id_grupo INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(40) NOT NULL UNIQUE
) ENGINE=InnoDB;

INSERT INTO grupos_musculares (id_grupo, nombre) VALUES
(1, 'Glúteos y Femorales'),
(2, 'Cuádriceps'),
(3, 'Pantorrillas'),
(4, 'Pecho'),
(5, 'Espalda'),
(6, 'Hombros'),
(7, 'Bíceps'),
(8, 'Tríceps'),
(9, 'Abdominales');

-- -----------------------------------------------------
-- 5. Tabla: ejercicios
-- -----------------------------------------------------
CREATE TABLE ejercicios (
    id_ejercicio INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_grupo INT UNSIGNED NOT NULL,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(255) DEFAULT NULL,
    CONSTRAINT fk_ejercicio_grupo FOREIGN KEY (id_grupo) REFERENCES grupos_musculares(id_grupo)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

INSERT INTO ejercicios (id_grupo, nombre, descripcion) VALUES
-- Glúteos y Femorales (id_grupo = 1)
(1, 'Hip Thrust con barra', 'Empuje de cadera, el rey para glúteos'),
(1, 'Hip Thrust en máquina', 'Empuje de cadera guiado'),
(1, 'Peso muerto rumano', 'Con barra o con mancuernas para cadena posterior'),
(1, 'Peso muerto convencional', 'Ejercicio básico de fuerza general'),
(1, 'Patada de glúteo en polea', 'Aislamiento de glúteo máximo'),
(1, 'Abductores en máquina o polea', 'Glúteo medio y lateral'),
(1, 'Curl femoral (tumbado o sentado)', 'Aislamiento de isquiotibiales'),
(1, 'Hiperextensiones', 'Enfocadas en glúteo e isquios'),
-- Cuádriceps (id_grupo = 2)
(2, 'Sentadilla libre profunda', 'Con barra tras nuca'),
(2, 'Sentadilla en máquina Smith', 'Sentadilla guiada'),
(2, 'Sentadilla Goblet', 'Sosteniendo mancuerna al pecho'),
(2, 'Sentadilla búlgara', 'A una pierna con apoyo trasero'),
(2, 'Prensa de piernas', 'Inclinada o recta'),
(2, 'Zancadas', 'Estáticas o caminando con mancuernas'),
(2, 'Extensión de cuádriceps', 'En máquina'),
(2, 'Sentadilla Libre con Barra', 'Barra sobre trapecios, descenso controlado manteniendo la espalda recta.'),
-- Pantorrillas (id_grupo = 3)
(3, 'Elevación de talones de pie', 'En máquina o con barra'),
(3, 'Elevación de talones sentado', 'En máquina costurera'),
-- Pecho (id_grupo = 4)
(4, 'Press de banca plano con barra', 'Básico para pectoral'),
(4, 'Press inclinado con mancuernas', 'Énfasis en pectoral superior'),
(4, 'Press de banca plano con mancuernas', 'Rango de movimiento amplio'),
(4, 'Aperturas en polea', 'Cruces de polea para definición'),
(4, 'Fondos en paralelas', 'Enfocados en parte inferior de pecho'),
(4, 'Flexiones de pecho', 'Lagartijas tradicionales o modificadas'),
(4, 'Press de Banca Plano', 'Acostado en banco plano, barra a la altura del pecho, empujar verticalmente.'),
-- Espalda (id_grupo = 5)
(5, 'Dominadas', 'Con peso corporal, asistidas o con lastre'),
(5, 'Jalón al pecho', 'Con agarre prono abierto o invertido'),
(5, 'Remo con barra', 'Libre inclinado'),
(5, 'Remo con mancuerna a una mano', 'Apoyado en banco'),
(5, 'Remo en polea baja / Gironda', 'Espalda media'),
(5, 'Pullover', 'Con mancuerna en banco'),
(5, 'Dominadas en Barra', 'Suspensión en barra fija, tracción hasta superar la barbilla.'),
-- Hombros (id_grupo = 6)
(6, 'Press militar', 'De pie con barra o sentado'),
(6, 'Press de hombros sentado con mancuernas', 'Desarrollo de deltoides'),
(6, 'Elevaciones laterales', 'Con mancuernas o en polea'),
(6, 'Pájaros', 'Elevaciones posteriores para deltoides posterior'),
(6, 'Face pulls', 'Con cuerda en polea alta para postura'),
-- Bíceps (id_grupo = 7)
(7, 'Curl de bíceps con barra', 'De pie'),
(7, 'Curl de bíceps inclinado', 'Sentado con mancuernas'),
(7, 'Curl de bíceps alterno', 'De pie con mancuernas'),
(7, 'Curl martillo', 'Con mancuernas y agarre neutro'),
-- Tríceps (id_grupo = 8)
(8, 'Extensión de tríceps en polea', 'Con barra recta o cuerda'),
(8, 'Copa de tríceps', 'Extensión sobre la cabeza con mancuerna'),
(8, 'Press francés', 'Con barra Z tumbado en banco'),
(8, 'Fondos en paralelas (Tríceps)', 'Con agarre estrecho para tríceps'),
-- Abdominales (id_grupo = 9)
(9, 'Plancha abdominal', 'Isométrica apoyando antebrazos'),
(9, 'Crunches', 'Abdominales tradicionales en el suelo'),
(9, 'Crunch invertido', 'Elevación de pelvis en el suelo'),
(9, 'Elevación de piernas colgado', 'En barra de dominadas'),
(9, 'Abdominales bicicleta', 'Rotación de oblicuos');

-- -----------------------------------------------------
-- 6. Tabla: rutinas
--    tipo = ESPECIALIZADA -> plantilla del gimnasio (sin dueño)
--    tipo = PERSONALIZADA -> plan creado por un cliente
-- -----------------------------------------------------
CREATE TABLE rutinas (
    id_rutina INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_entrenador INT UNSIGNED NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(255) DEFAULT NULL,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo ENUM('ESPECIALIZADA','PERSONALIZADA') NOT NULL DEFAULT 'ESPECIALIZADA',
    id_usuario_propietario INT UNSIGNED DEFAULT NULL,
    CONSTRAINT fk_rutina_entrenador FOREIGN KEY (id_entrenador) REFERENCES usuarios(id_usuario)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_rutina_propietario FOREIGN KEY (id_usuario_propietario) REFERENCES usuarios(id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 7. Tabla: rutina_ejercicios (Detalle M:N)
-- -----------------------------------------------------
CREATE TABLE rutina_ejercicios (
    id_rutina_ejercicio INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_rutina INT UNSIGNED NOT NULL,
    id_ejercicio INT UNSIGNED NOT NULL,
    orden TINYINT UNSIGNED NOT NULL,
    series TINYINT UNSIGNED NOT NULL,
    repeticiones TINYINT UNSIGNED NOT NULL,
    CONSTRAINT fk_re_rutina FOREIGN KEY (id_rutina) REFERENCES rutinas(id_rutina)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_re_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicios(id_ejercicio)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT uk_rutina_orden UNIQUE (id_rutina, orden)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 8. Tablas: planificación semanal de rutinas especializadas
--    rutina_dias guarda un registro por día (incluido el descanso);
--    rutina_dia_ejercicios guarda los ejercicios de cada día.
-- -----------------------------------------------------
CREATE TABLE rutina_dias (
    id_rutina_dia INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_rutina INT UNSIGNED NOT NULL,
    dia_semana TINYINT UNSIGNED NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),
    enfoque VARCHAR(80) NOT NULL,
    es_descanso TINYINT(1) NOT NULL DEFAULT 0,
    CONSTRAINT fk_rd_rutina FOREIGN KEY (id_rutina) REFERENCES rutinas(id_rutina)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT uk_rutina_dia UNIQUE (id_rutina, dia_semana)
) ENGINE=InnoDB;

CREATE TABLE rutina_dia_ejercicios (
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

-- -----------------------------------------------------
-- 9. Tabla: asignaciones (rutina guardada por un cliente para un día)
--    Se permite más de una rutina por día (especializada + personalizada).
-- -----------------------------------------------------
CREATE TABLE asignaciones (
    id_asignacion INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNSIGNED NOT NULL,
    id_rutina INT UNSIGNED NOT NULL,
    dia_semana TINYINT UNSIGNED NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),
    fecha_asignacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_asig_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_asig_rutina FOREIGN KEY (id_rutina) REFERENCES rutinas(id_rutina)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT uk_cliente_dia_rutina UNIQUE (id_cliente, dia_semana, id_rutina),
    INDEX idx_asig_cliente_dia (id_cliente, dia_semana)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 10. Tabla: asistencias
-- -----------------------------------------------------
CREATE TABLE asistencias (
    id_asistencia INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNSIGNED NOT NULL,
    fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha DATE NOT NULL,
    CONSTRAINT fk_asistencia_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT uk_cliente_fecha_asistencia UNIQUE (id_cliente, fecha),
    INDEX idx_asistencias_fecha (fecha)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 11. Usuarios de prueba
--     Todos usan la contraseña: 1234
-- -----------------------------------------------------
INSERT INTO usuarios (id_rol, nombre, apellido, email, password_hash, telefono) VALUES
(1, 'Moisés', 'Baquero', 'admin@ironhub.com', '1234', '3001234567'),
(2, 'Carlos', 'Pérez', 'cliente@ironhub.com', '1234', '3109876543'),
(2, 'Carlos', 'Pérez', 'carlos@ironhub.com', '1234', '3101112233'),
(2, 'Ana', 'Gómez', 'ana@ironhub.com', '1234', '3102223344'),
(2, 'Luis', 'Martínez', 'luis@ironhub.com', '1234', '3103334455'),
(2, 'Sofía', 'Rodríguez', 'sofia@ironhub.com', '1234', '3104445566'),
(2, 'Mateo', 'López', 'mateo@ironhub.com', '1234', '3105556677'),
(2, 'Valentina', 'Torres', 'valentina@ironhub.com', '1234', '3106667788'),
(2, 'Andrés', 'Ramírez', 'andres@ironhub.com', '1234', '3107778899'),
(2, 'Lucía', 'Castro', 'lucia@ironhub.com', '1234', '3108889900'),
(1, 'Pedro', 'Entrenador', 'pedro.coach@ironhub.com', '1234', '3201112233'),
(1, 'Maria', 'Admin', 'maria.admin@ironhub.com', '1234', '3202223344');

-- Perfil de cliente del usuario de prueba principal
INSERT INTO clientes (id_usuario, documento, fecha_nacimiento, objetivo)
VALUES (2, '1098765432', '2000-05-15', 'Ganancia de masa muscular y fuerza');

-- Perfil de cliente para el resto de usuarios con rol CLIENTE
INSERT INTO clientes (id_usuario, documento, fecha_nacimiento, objetivo)
SELECT u.id_usuario, CONCAT('AUTO-', LPAD(u.id_usuario, 6, '0')), NULL,
       'Hipertrofia y acondicionamiento general'
FROM usuarios u
LEFT JOIN clientes c ON c.id_usuario = u.id_usuario
WHERE u.id_rol = 2 AND c.id_cliente IS NULL;

-- -----------------------------------------------------
-- 12. Planes especializados oficiales (planificación semanal)
-- -----------------------------------------------------
INSERT INTO rutinas (id_entrenador, nombre, descripcion, tipo) VALUES
(1, 'Fuerza 5x5 (3 Días - Fuerza Máxima)', 'Fuerza máxima con sentadilla, press banca, remo, press militar y peso muerto. Tres sesiones A/B con progresión de cargas.', 'ESPECIALIZADA'),
(1, 'Rutina Weider (5 Días - Hipertrofia Torso)', 'División culturista por grupo muscular: pecho, espalda, hombros, piernas y brazos. Cinco sesiones de hipertrofia.', 'ESPECIALIZADA'),
(1, 'Push-Pull-Legs (Empuje-Tirón-Pierna)', 'Empuje, tirón y pierna dos veces por semana. Seis sesiones que combinan fuerza al inicio y volumen al final.', 'ESPECIALIZADA'),
(1, 'Torso-Pierna (Énfasis Glúteos y Piernas)', 'Dos sesiones de tren inferior y dos de torso. Énfasis en glúteos, femorales y cuádriceps con torso estético.', 'ESPECIALIZADA'),
(1, 'Full Body (Recomposición Corporal)', 'Tres sesiones de cuerpo completo para recomposición: fuerza, gasto calórico y tonificación simultánea.', 'ESPECIALIZADA'),
(1, 'Arnold Split (6 Días - Volumen)', 'Split antagonista de seis días: pecho-espalda, hombros-brazos y piernas dos veces por semana. Volumen alto.', 'ESPECIALIZADA');

SET @plan_fuerza := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Fuerza 5x5%' ORDER BY id_rutina LIMIT 1);
SET @plan_weider := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Rutina Weider%' ORDER BY id_rutina LIMIT 1);
SET @plan_ppl := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Push-Pull-Legs%' ORDER BY id_rutina LIMIT 1);
SET @plan_torso := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Torso-Pierna%' ORDER BY id_rutina LIMIT 1);
SET @plan_full := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Full Body%' ORDER BY id_rutina LIMIT 1);
SET @plan_arnold := (SELECT id_rutina FROM rutinas WHERE tipo = 'ESPECIALIZADA' AND nombre LIKE 'Arnold Split%' ORDER BY id_rutina LIMIT 1);

-- Días, enfoques y ejercicios de cada plan semanal

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

-- Ejemplo: el cliente 1 tiene el plan de fuerza activo toda la semana
INSERT INTO asignaciones (id_cliente, id_rutina, dia_semana)
SELECT 1, @plan_fuerza, d.dia
FROM (
    SELECT 1 AS dia UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
) d
WHERE @plan_fuerza IS NOT NULL;

-- -----------------------------------------------------
-- 13. Vistas útiles para reportes
-- -----------------------------------------------------
CREATE OR REPLACE VIEW vw_plan_semanal AS
SELECT c.id_cliente, u.nombre, u.apellido, a.dia_semana, r.nombre AS rutina_nombre, r.tipo
FROM clientes c
JOIN usuarios u ON c.id_usuario = u.id_usuario
JOIN asignaciones a ON c.id_cliente = a.id_cliente
JOIN rutinas r ON a.id_rutina = r.id_rutina;

CREATE OR REPLACE VIEW vw_reporte_asistencia AS
SELECT c.id_cliente, u.nombre, u.apellido, COUNT(ast.id_asistencia) AS total_asistencias, MAX(ast.fecha_hora) AS ultima_asistencia
FROM clientes c
JOIN usuarios u ON c.id_usuario = u.id_usuario
LEFT JOIN asistencias ast ON c.id_cliente = ast.id_cliente
GROUP BY c.id_cliente, u.nombre, u.apellido;
