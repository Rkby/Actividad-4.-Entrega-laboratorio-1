-- LAB-01 | Actividades 7 a 15: consultas y ejemplos de pruebas
-- Leer cada bloque y ejecutar de forma controlada. No ejecutar como un solo lote.

-- A. Cambiar el registro de sentencias a MOD (superusuario).
-- ALTER SYSTEM SET log_statement = 'mod';
-- SELECT pg_reload_conf();
-- Abrir una nueva sesion para las comprobaciones posteriores.

-- B. Prueba UPDATE como app_ventas (ejecutar desde una conexion app_ventas):
-- UPDATE clientes SET telefono = '6679990000' WHERE id = 3;

-- C. Prueba INSERT/DELETE con auditoria (superusuario):
-- INSERT INTO clientes (nombre, correo, rfc, edad, ciudad, codigo_postal)
-- VALUES ('Pedro Ruiz', 'pedro.ruiz@example.test', 'RUPE950101AAA', 30, 'Guasave', '81000');
-- DELETE FROM clientes WHERE nombre = 'Pedro Ruiz';

-- D. Actualizacion masiva de segmento (superusuario; genera un evento por fila):
-- ALTER TABLE clientes ADD COLUMN segmento VARCHAR(20);
-- UPDATE clientes SET segmento = 'regular';

-- E. Verificar resumen de eventos:
SELECT operacion, COUNT(*)
FROM auditoria.cambios_clientes
GROUP BY operacion
ORDER BY operacion;

-- F. Reconstruir campos modificados a partir del JSONB:
SELECT a.id_evento,
       a.momento,
       a.usuario_sesion,
       a.ip_cliente,
       d.key AS campo,
       a.valores_antes ->> d.key AS antes,
       d.value #>> '{}' AS despues
FROM auditoria.cambios_clientes a
CROSS JOIN LATERAL jsonb_each(a.valores_despues) d
WHERE a.operacion = 'UPDATE'
  AND a.valores_antes -> d.key IS DISTINCT FROM d.value
ORDER BY a.id_evento;

-- G. Consultar historial completo:
SELECT id_evento, momento, usuario_sesion, usuario_efectivo,
       aplicacion, ip_cliente, operacion, id_cliente,
       valores_antes, valores_despues
FROM auditoria.cambios_clientes
ORDER BY id_evento;

-- H. Verificar estado del trigger:
SELECT tgname,
       CASE tgenabled
         WHEN 'O' THEN 'HABILITADO'
         WHEN 'D' THEN 'DESHABILITADO'
         WHEN 'R' THEN 'REPLICA'
         WHEN 'A' THEN 'SIEMPRE'
       END AS estado
FROM pg_trigger
WHERE tgname = 'trg_auditoria_clientes';

-- I. Buscar el UPDATE masivo en el LOG. En la salida observada la sentencia
-- se dividio en dos lineas consecutivas (UPDATE clientes / SET segmento...).
SELECT num, linea
FROM dba.bitacora
WHERE linea ILIKE '%UPDATE%'
   OR linea ILIKE '%segmento%'
   OR linea ILIKE '%regular%'
ORDER BY num DESC
LIMIT 20;

-- J. El trigger puede ser desactivado por el propietario/superusuario.
-- Esta prueba se realizó y el trigger se volvió a habilitar inmediatamente.
-- No dejarlo deshabilitado:
-- ALTER TABLE clientes DISABLE TRIGGER trg_auditoria_clientes;
-- UPDATE clientes SET rfc = 'GAMA780912GHI' WHERE id = 3;
-- ALTER TABLE clientes ENABLE TRIGGER trg_auditoria_clientes;
