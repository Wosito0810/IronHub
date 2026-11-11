-- IRONHUB 2.0 | Solo añade una tabla; NO elimina datos previos.
-- Ejecutar una sola vez DESPUES de haber creado ironhub_db.
USE ironhub_db;
CREATE TABLE IF NOT EXISTS propuestas_ejercicios (
    id_propuesta INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT UNSIGNED NOT NULL,
    id_grupo INT UNSIGNED NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT NOT NULL,
    nombre_archivo VARCHAR(100) NOT NULL,
    tipo_media ENUM('imagen', 'video') NOT NULL,
    estado ENUM('PENDIENTE', 'APROBADA', 'RECHAZADA') NOT NULL DEFAULT 'PENDIENTE',
    id_ejercicio INT UNSIGNED DEFAULT NULL,
    id_revisor INT UNSIGNED DEFAULT NULL,
    fecha_envio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_revision DATETIME NULL,
    CONSTRAINT fk_propuesta_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_propuesta_grupo FOREIGN KEY (id_grupo) REFERENCES grupos_musculares(id_grupo),
    CONSTRAINT fk_propuesta_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicios(id_ejercicio) ON DELETE SET NULL,
    CONSTRAINT fk_propuesta_revisor FOREIGN KEY (id_revisor) REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    INDEX ix_propuesta_estado_fecha (estado, fecha_envio),
    INDEX ix_propuesta_autor (id_usuario, fecha_envio)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
