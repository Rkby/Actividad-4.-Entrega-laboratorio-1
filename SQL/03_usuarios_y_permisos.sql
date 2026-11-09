-- LAB-01 | Preparacion de roles y permisos
-- Ejecutar conectado a comercial como postgres.
-- No escribir contraseñas en este archivo ni en sentencias SQL visibles.

CREATE ROLE app_ventas LOGIN;
CREATE ROLE soporte_ana LOGIN;

-- En psql, introducir las contraseñas de forma interactiva:
-- \password app_ventas
-- \password soporte_ana

GRANT SELECT, UPDATE ON TABLE clientes TO app_ventas;
GRANT SELECT ON TABLE clientes TO soporte_ana;

-- En la actividad 6 se repitieron explícitamente estos cambios:
-- REVOKE UPDATE ON clientes FROM soporte_ana;
-- GRANT UPDATE ON clientes TO app_ventas;

\du
\dp clientes
