-- IRONHUB 3.1: MIGRACION ADITIVA. NO BORRA TABLAS NI REGISTROS.
-- Primero exportar una copia de respaldo desde MySQL Workbench.
-- Ejecutar una sola vez después de migracion_propuestas.sql.
USE ironhub_db;

CREATE TABLE IF NOT EXISTS sesiones_entrenamiento (
    id_sesion INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT UNSIGNED NOT NULL,
    dia_semana TINYINT UNSIGNED NOT NULL,
    notas VARCHAR(255) NOT NULL DEFAULT '',
    fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_sesion_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    INDEX ix_sesion_usuario_fecha (id_usuario, fecha_hora)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS series_entrenamiento (
    id_serie INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_sesion INT UNSIGNED NOT NULL,
    id_ejercicio INT UNSIGNED NOT NULL,
    series TINYINT UNSIGNED NOT NULL,
    repeticiones SMALLINT UNSIGNED NOT NULL,
    peso_kg DECIMAL(7,2) DEFAULT NULL,
    CONSTRAINT fk_serie_sesion FOREIGN KEY (id_sesion) REFERENCES sesiones_entrenamiento(id_sesion) ON DELETE CASCADE,
    CONSTRAINT fk_serie_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicios(id_ejercicio) ON DELETE RESTRICT,
    INDEX ix_serie_ejercicio (id_ejercicio)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS notificaciones (
    id_notificacion INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT UNSIGNED NOT NULL,
    tipo VARCHAR(30) NOT NULL DEFAULT 'SISTEMA',
    titulo VARCHAR(120) NOT NULL,
    mensaje VARCHAR(255) NOT NULL,
    leida TINYINT(1) NOT NULL DEFAULT 0,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_aviso_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    INDEX ix_aviso_usuario (id_usuario, leida, fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
