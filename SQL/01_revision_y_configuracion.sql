-- LAB-01 | Actividad 1 y 4: revision y configuracion inicial
-- Ejecutar como superusuario (postgres) desde psql.

SELECT version();
SELECT current_user, rolsuper
FROM pg_roles
WHERE rolname = current_user;

SHOW config_file;
SHOW data_directory;
SHOW log_directory;
SHOW logging_collector;
SHOW server_encoding;
SHOW password_encryption;
SHOW hba_file;

SELECT name, setting, source
FROM pg_settings
WHERE name IN (
    'log_destination', 'logging_collector', 'log_directory',
    'log_filename', 'log_connections', 'log_disconnections',
    'log_line_prefix', 'log_statement', 'log_min_error_statement',
    'log_timezone'
)
ORDER BY name;

-- El colector ya estaba ON durante la práctica. Si se cambia de OFF a ON,
-- logging_collector requiere reinicio del servicio PostgreSQL.
-- Se habilitan registros de conexión y desconexión y se agrega contexto.
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_line_prefix = '%m [%p] user=%u db=%d app=%a client=%h ';

-- Fase inicial para las pruebas DDL de las actividades 4 y 6.
ALTER SYSTEM SET log_statement = 'ddl';
SELECT pg_reload_conf();

-- Abrir una NUEVA conexión para comprobar log_connections y log_disconnections.
-- Más adelante, para la Actividad 7, cambiar a mod:
-- ALTER SYSTEM SET log_statement = 'mod';
-- SELECT pg_reload_conf();

-- Comprobaciones:
SELECT name, setting, source, sourcefile
FROM pg_settings
WHERE name IN ('log_connections','log_disconnections','log_line_prefix','log_statement')
ORDER BY name;

SELECT pg_current_logfile();
