-- LAB-01 | Actividades 2, 4 y consultas de bitacora
-- Ejecutar como superusuario en la base comercial.

CREATE SCHEMA dba;
REVOKE ALL ON SCHEMA dba FROM PUBLIC;

-- En este equipo, pg_read_file() falló al interpretar un byte 0xFA como UTF8.
-- La lectura binaria y convert_from(..., 'WIN1252') funcionó para el LOG observado.
-- La vista lee solamente el archivo indicado por pg_current_logfile() en ese momento.
CREATE VIEW dba.bitacora AS
SELECT t.n AS num,
       t.linea
FROM regexp_split_to_table(
    convert_from(
        pg_read_binary_file(pg_current_logfile()),
        'WIN1252'
    ),
    E'\r?\n'
) WITH ORDINALITY AS t(linea, n)
WHERE t.linea <> '';

-- Consultas de comprobacion: la consola puede mostrar acentos incorrectos
-- por la diferencia entre code page 850 y Windows 1252.
SELECT num, linea
FROM dba.bitacora
ORDER BY num DESC
LIMIT 10;

SELECT linea
FROM dba.bitacora
WHERE linea ILIKE '%FATAL%' OR linea ILIKE '%ERROR%';

-- En la instalacion observada, el prefijo se configuró como:
-- %m [%p] user=%u db=%d app=%a client=%h
-- Los mensajes de sentencia aparecen localizados como "sentencia:".
