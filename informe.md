# Informe — LAB-01: Bitácoras y auditoría del dato en PostgreSQL

## 1. Datos generales

| Elemento | Resultado |
|---|---|
| Sistema operativo | Windows |
| Motor de base de datos | PostgreSQL 16.15, 64 bits |
| Cliente de administración | SQL Shell (`psql`) y CMD/PowerShell |
| Base de datos de práctica | `comercial` |
| Usuario administrador | `postgres` |
| Codificación del servidor | UTF8 |
| Cifrado de contraseñas | `scram-sha-256` |
| Zona horaria de bitácora | GMT |

## 2. Objetivo

Configurar bitácoras del servidor PostgreSQL y construir un mecanismo de auditoría a nivel de fila para la tabla `clientes`. El trabajo permite revisar conexiones y errores, registrar sentencias de modificación, distinguir usuarios y aplicaciones, y conservar en formato JSONB los valores anteriores y posteriores de las operaciones INSERT, UPDATE y DELETE.

## 3. Preparación del entorno

Se verificó PostgreSQL 16.15 y el acceso administrativo. El usuario `postgres` obtuvo `rolsuper = true`. Los archivos principales se localizaron en:

- `postgresql.conf`: `C:\Program Files\PostgreSQL\16\data\postgresql.conf`
- Directorio de datos: `C:\Program Files\PostgreSQL\16\data`
- Directorio de bitácoras: `log`
- Archivo HBA: `C:\Program Files\PostgreSQL\16\data\pg_hba.conf`

La instalación ya tenía `logging_collector = on`. También se comprobó `password_encryption = scram-sha-256`. Las seis reglas observadas en `pg_hba_file_rules` utilizaban `scram-sha-256` para conexiones locales, IPv4 `127.0.0.1`, IPv6 `::1` y replicación.

Se creó la base de datos `comercial`, una tabla `clientes` y cinco clientes ficticios: Ana López, Carlos Pérez, María García, Luis Torres y Laura Sánchez. Se crearon los roles `app_ventas` y `soporte_ana`. Se asignaron contraseñas de forma interactiva con `\password`, por lo que no se incluyen credenciales en este informe.

Permisos iniciales:

| Rol | SELECT | UPDATE | DELETE |
|---|---:|---:|---:|
| `app_ventas` | Sí | Sí | No |
| `soporte_ana` | Sí | No | No |

## 4. Actividades realizadas y resultados

### Actividad 1. Revisión inicial de parámetros

Se consultaron los diez parámetros solicitados. Los valores iniciales observados fueron:

| Parámetro | Valor inicial |
|---|---|
| `log_connections` | `off` |
| `log_destination` | `stderr` |
| `log_directory` | `log` |
| `log_disconnections` | `off` |
| `log_filename` | `postgresql-%Y-%m-%d_%H%M%S.log` |
| `log_line_prefix` | `%m [%p]` |
| `log_min_error_statement` | `error` |
| `log_statement` | `none` |
| `log_timezone` | `GMT` |
| `logging_collector` | `on` |

**Interpretación:** inicialmente no se registraban conexiones ni desconexiones y tampoco se guardaban sentencias SQL generales. El prefijo no identificaba usuario, base de datos, aplicación o IP.

### Actividad 2. Colector y lectura de la bitácora

Se confirmó `logging_collector = on` y `pending_restart = false`. `pg_current_logfile()` devolvió inicialmente un archivo en el directorio `log`.

La lectura directa con `pg_read_file()` produjo un error de codificación UTF8 (`0xFA`). El servidor indicó `server_encoding = UTF8`. Para inspeccionar el archivo se utilizó `pg_read_binary_file()` y `convert_from(..., 'WIN1252')`. La consulta permitió mostrar líneas del LOG, aunque algunos caracteres se visualizaron incorrectamente debido a la diferencia entre la página de códigos de la consola Windows (850) y la página de Windows (1252).

Se creó el esquema privado `dba` y la vista `dba.bitacora`, que separa el archivo LOG actual en líneas numeradas. La vista se limita al archivo devuelto por `pg_current_logfile()` en el momento de la consulta; no consolida automáticamente todos los archivos rotados.

La búsqueda de `FATAL` o `ERROR` encontró cuatro líneas en aquella consulta, incluidas fallas de autenticación, errores de sintaxis y el error inicial de codificación.

### Actividad 3. Incidente sin trazabilidad inicial

Se intentó ejecutar una actualización de RFC como `app_ventas` mientras `log_statement` todavía estaba en `none`. La primera invocación desde CMD colocó incorrectamente el argumento `-c`; `psql` lo ignoró y abrió una sesión interactiva, por lo que esa ejecución no quedó confirmada como UPDATE. Una comprobación posterior todavía mostró el RFC original de María García.

La actualización de prueba se ejecutó correctamente más adelante, durante la Actividad 7, cuando se corrigió el comando. Por rigor, no se atribuye a la primera ejecución un cambio que no fue comprobado.

### Actividad 4. Registro de conexiones y DDL

Se configuró:

```sql
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_line_prefix = '%m [%p] user=%u db=%d app=%a client=%h ';
ALTER SYSTEM SET log_statement = 'ddl';
SELECT pg_reload_conf();
```

Al consultar inmediatamente desde la sesión existente, `log_connections` y `log_disconnections` seguían apareciendo como `off`, ya que esos parámetros se aplican al iniciar una sesión. Se abrió una nueva conexión TCP a `127.0.0.1` como `postgres`; entonces ambos valores aparecieron como `on`. Los cuatro parámetros quedaron configurados desde `postgresql.auto.conf`.

La bitácora mostró mensajes de conexión recibida, autenticación y autorización, con usuario, base de datos, aplicación y dirección IP.

### Actividad 5. Accesos exitosos y fallidos

Se probaron dos autenticaciones fallidas: una contraseña incorrecta para `app_ventas` y un rol inexistente llamado `usuario_inexistente`. Ambas quedaron registradas como `FATAL`. Después se inició sesión correctamente como `app_ventas` y se ejecutó `SELECT count(*) FROM clientes`, que devolvió cinco registros.

Se observó que `app_ventas` no podía consultar el esquema privado `dba`; el intento produjo `ERROR: permiso denegado al esquema dba`. La bitácora identificó las conexiones, la IP `127.0.0.1` y la aplicación `app-ventas-web` en la conexión exitosa.

### Actividad 6. Cambios de privilegios y DDL

Se ejecutó `REVOKE UPDATE ON clientes FROM soporte_ana`, `GRANT UPDATE ON clientes TO app_ventas` y se agregó la columna `segmento VARCHAR(20)` a `clientes`. La estructura y los permisos se comprobaron con `\d clientes` y `\dp clientes`.

Se creó y eliminó el rol temporal `rol_temporal`. La consulta de la vista usando la palabra inglesa `statement` no devolvió filas porque los mensajes de este servidor estaban localizados en español y usaban `sentencia:`. Al cambiar el filtro a `ILIKE '%SENTENCIA:%'` se encontraron seis líneas, entre ellas los cambios de privilegios y estructura.

Se buscó la cadena de la contraseña temporal en la vista del archivo LOG consultado y no se encontraron coincidencias. Esta comprobación se limita al contenido visible a través de esa vista y no constituye una auditoría de todos los archivos de LOG históricos o rotados.

### Actividad 7. Diferencia entre DDL y MOD

Con `log_statement = 'ddl'` se actualizó el RFC de María (ID 3) a `GAMA780912XYZ`; el comando devolvió `UPDATE 1`, pero la sentencia DML no se registró bajo el nivel DDL. Posteriormente se cambió a `log_statement = 'mod'` y se actualizó el teléfono a `6679990000`. El comando devolvió `UPDATE 1`, y la bitácora registró la sentencia UPDATE. La consulta SELECT posterior no se registró, porque `mod` no registra lecturas.

### Actividad 8. Operaciones rechazadas

`soporte_ana` intentó borrar al cliente 5. PostgreSQL rechazó la operación con `ERROR: permiso denegado a la tabla clientes`. Después se intentó eliminar el rol `soporte_ana`, pero PostgreSQL lo impidió porque tenía privilegios dependientes sobre la tabla `clientes`. La vista `dba.bitacora` mostró ambos errores y las sentencias asociadas.

### Actividad 9. Sesiones activas

Se inició una consulta `SELECT pg_sleep(90)` con `application_name = reporte-mensual` como `soporte_ana`. `pg_stat_activity` identificó la sesión con PID `25544`, usuario `soporte_ana`, aplicación `reporte-mensual`, cliente `127.0.0.1` y estado `active`.

La búsqueda por PID localizó los registros de conexión recibida, autenticación, autorización y desconexión. La sesión duró `00:01:30.141`. Después de finalizar, la consulta a `pg_stat_activity` devolvió cero filas para esa aplicación, mientras que los registros históricos continuaron disponibles en la bitácora.

### Actividad 10. Tabla de auditoría

Se creó el esquema `auditoria`, se revocó el acceso público y se creó `auditoria.cambios_clientes` con diez campos: `id_evento`, `momento`, `usuario_sesion`, `usuario_efectivo`, `aplicacion`, `ip_cliente`, `operacion`, `id_cliente`, `valores_antes` y `valores_despues`. Los campos de imagen anterior y posterior son `JSONB`; la fecha/hora es `TIMESTAMPTZ`.

**Preguntas y respuestas:**

1. **¿Por qué `TIMESTAMPTZ` en lugar de `TIMESTAMP`?** Permite manejar instantes de tiempo con contexto de zona horaria y normalizar su representación, algo útil para correlacionar eventos de distintos sistemas.
2. **¿Por qué JSONB en lugar de guardar solo la columna modificada?** Permite conservar la imagen completa del registro antes y después, y reconstruir qué cambió posteriormente.
3. **¿Qué implica almacenar RFC en la auditoría?** La tabla contiene datos personales y debe clasificarse y protegerse como información confidencial, con acceso limitado y retención definida.

### Actividad 11. Función y trigger

Se creó `auditoria.registrar_cambio_cliente()` en PL/pgSQL con `SECURITY DEFINER` y `search_path` controlado. La función inserta una fila de auditoría para INSERT, UPDATE o DELETE, utilizando `to_jsonb(NEW)` y `to_jsonb(OLD)`. Se revocaron privilegios públicos sobre la función y se creó `trg_auditoria_clientes` como trigger `AFTER ... FOR EACH ROW`.

`pg_trigger` confirmó que el disparador estaba habilitado. La bitácora registró la creación de la función, el REVOKE y la creación del trigger.

**Preguntas y respuestas:**

1. **¿Por qué revocar acceso público a la función?** Para evitar que todos los roles puedan invocarla directamente; su ejecución normal la realiza el trigger.
2. **¿Qué ocurre sin `SECURITY DEFINER`?** La función se ejecutaría con los privilegios del usuario que realiza el cambio. Como `app_ventas` no tiene permisos directos de escritura en la tabla de auditoría, la inserción del historial podría fallar y hacer fallar la modificación.
3. **¿Se registró la creación?** Sí; se encontraron las sentencias de creación de la función, revocación de permisos y creación del trigger en el LOG.

### Actividad 12. Incidente auditado

Como `app_ventas` se cambió el RFC de María (ID 3) de `GAMA780912XYZ` a `GAMA780912ZZZ`; el comando devolvió `UPDATE 1`. El trigger generó el evento 1. La auditoría mostró `usuario_sesion = app_ventas`, `usuario_efectivo = postgres`, `aplicacion = app-ventas-web`, `ip_cliente = 127.0.0.1`, `operacion = UPDATE` e `id_cliente = 3`.

El usuario `app_ventas` intentó consultar la tabla de auditoría y recibió `permiso denegado al esquema auditoria`, confirmando la restricción de acceso.

La comparación JSONB mostró el campo `rfc`, con valor anterior `GAMA780912XYZ` y valor nuevo `GAMA780912ZZZ`.

**Preguntas y respuestas:**

1. **¿Qué demuestra `SECURITY DEFINER`?** Que la función se ejecutó con los privilegios de su propietario (`postgres`), mientras `session_user` conservó la identidad de quien inició sesión (`app_ventas`).
2. **¿Cómo se restauraría el RFC anterior?** Con un UPDATE de la fila 3 estableciendo `rfc = 'GAMA780912XYZ'`; durante la prueba posterior el valor se modificó de otra manera y el estado final se documenta más adelante.
3. **¿Qué aporta IP frente a aplicación?** La IP puede orientar sobre el origen de red; `application_name` identifica el cliente declarado, pero puede ser elegido por la propia aplicación.

### Actividad 13. INSERT y DELETE auditados

Se insertó a Pedro Ruiz, con RFC `RUPE950101AAA`, como cliente ID 6. El trigger generó el evento 2. Después se eliminó con `DELETE 1`, y el trigger generó el evento 3 con la imagen anterior. La consulta a `clientes` devolvió cero filas para Pedro, mientras que la auditoría conservó su registro de inserción y eliminación.

**Preguntas y respuestas:**

1. **¿Dónde queda evidencia de Pedro después de eliminarlo?** En `auditoria.cambios_clientes`, en las imágenes JSONB del INSERT y DELETE.
2. **¿Por qué `ip_cliente` podría ser NULL?** `inet_client_addr()` devuelve NULL para conexiones locales que no usan TCP/IP; en esta práctica las conexiones probadas fueron TCP a `127.0.0.1`.
3. **¿Qué conflicto hay con datos personales?** La evidencia histórica debe equilibrarse con minimización, retención y obligaciones de privacidad; la organización debe definir una política formal de conservación y acceso.

### Actividad 14. Intentos de manipulación

Como `app_ventas` se intentó borrar la tabla de auditoría y desactivar el trigger. Ambos intentos fueron rechazados: no tenía permiso sobre el esquema `auditoria` ni era propietario de `clientes`.

Como administrador se desactivó temporalmente el trigger, se actualizó el RFC de María a `GAMA780912GHI` y se volvió a habilitar. El conteo de eventos permaneció en tres durante esa prueba: el UPDATE ejecutado con el trigger desactivado no creó una fila de auditoría. La bitácora registró las sentencias para desactivar y reactivar el trigger y permitió observar la operación administrativa.

**Preguntas y respuestas:**

1. **¿Qué evidencia permite detectar un cambio no auditado por el trigger?** La bitácora registra la desactivación y reactivación del trigger, mientras que el conteo de auditoría no aumenta durante el UPDATE.
2. **¿Qué control reduciría el riesgo?** Separación de funciones, control de cambios, monitoreo de acciones privilegiadas y envío de logs a un sistema externo protegido contra modificación por el administrador de la base de datos.
3. **¿Cómo se relaciona con la separación de funciones?** Una sola persona no debería controlar los datos, el mecanismo de auditoría y la evidencia histórica.

### Actividad 15. Lecturas y volumen

`soporte_ana` ejecutó correctamente una consulta SELECT sobre los datos de María (RFC `GAMA780912GHI` y teléfono `6679990000`). La búsqueda de esa lectura en el LOG devolvió cero coincidencias, consistente con `log_statement = 'mod'`, que registra modificaciones y no lecturas.

Después se ejecutó `UPDATE clientes SET segmento = 'regular'`, que devolvió `UPDATE 5`. El trigger produjo cinco eventos adicionales. El resumen final de la tabla de auditoría mostró:

| Operación | Eventos |
|---|---:|
| DELETE | 1 |
| INSERT | 1 |
| UPDATE | 6 |
| **Total** | **8** |

La búsqueda inicial en la bitácora por la frase completa `UPDATE clientes SET segmento` devolvió cero porque PostgreSQL dividió la sentencia en dos líneas. Una búsqueda más amplia encontró la sentencia en las líneas 143 y 144: `sentencia: UPDATE clientes` y `SET segmento = 'regular';`.

**Preguntas y respuestas:**

1. **¿Qué ocurriría con un UPDATE sin WHERE sobre un millón de filas?** El trigger por fila generaría aproximadamente un millón de eventos, con impacto en almacenamiento, I/O, tiempo de ejecución y mantenimiento.
2. **¿Quién debe autorizar la depuración?** El responsable de seguridad/cumplimiento y el propietario de los datos, mediante política de retención aprobada y registro de la eliminación.
3. **¿Por qué `log_statement = 'all'` puede almacenar datos sensibles?** Porque registra también consultas de lectura y sentencias que pueden contener valores personales o secretos ingresados directamente en SQL.

## 5. Estado final observado

- La tabla `clientes` conservó cinco clientes originales; Pedro Ruiz fue eliminado.
- María García (ID 3) terminó con RFC `GAMA780912GHI` y teléfono `6679990000`.
- La columna `segmento` fue añadida y los cinco clientes quedaron con el valor `regular`.
- El trigger `trg_auditoria_clientes` terminó habilitado.
- La tabla de auditoría terminó con ocho eventos: seis UPDATE, un INSERT y un DELETE.
- La consulta final confirmó `log_statement = mod`.
- El archivo LOG exportado se identificó como `postgresql-2026-11-09_000000.log` y se copió como `postgresql-lab01.log`.

## 6. Incidencias y soluciones

1. **Contraseña de `postgres`:** inicialmente no se conocía y el intento con contraseña vacía falló. Más tarde se consiguió una sesión administrativa válida; no se desinstaló PostgreSQL ni se eliminaron bases.
2. **Páginas de código 850/1252:** psql advirtió que la página de códigos de la consola difería de Windows. La conexión y consultas funcionaron; algunos caracteres acentuados se mostraron incorrectamente.
3. **Codificación del LOG:** `pg_read_file()` falló al interpretar el byte `0xFA` como UTF8. La lectura binaria con conversión WIN1252 permitió consultar las líneas.
4. **Parámetros de conexión:** `log_connections` y `log_disconnections` siguieron `off` en la sesión antigua. Tras abrir una nueva conexión, se confirmaron como `on`.
5. **Localización de mensajes:** las sentencias se mostraron con `sentencia:` en español, no `statement:`; se corrigieron los filtros usando `ILIKE`.
6. **Argumento `-c` de psql:** en una invocación inicial quedó después de los parámetros de conexión, por lo que se ignoró. Se corrigió el orden del comando y se comprobó el UPDATE en una ejecución posterior.
7. **Sentencia partida en varias líneas:** el UPDATE de segmento se registró en dos líneas consecutivas. La búsqueda amplia permitió localizarlo.

## 7. Exportación del LOG e integridad

Archivo activo consultado:

`log/postgresql-2026-11-09_000000.log`

Copia realizada en Windows:

`%USERPROFILE%\Desktop\LAB01\logs\postgresql-lab01.log`

Hash SHA-256 calculado mediante `Get-FileHash`:

`A4EF66FDFEE1D9BC50BBA66BC4AB5B7E1FC8432EE02FBBECDE23E4B3AEC569FD`

El valor también se guardó en `SHA256.txt`. El LOG original debe conservarse con acceso restringido. La búsqueda de `Temporal_Practica_2026` devolvió cero coincidencias en la vista del LOG consultado; esta búsqueda puntual no sustituye una inspección completa de otros archivos rotados.

## 8. Conclusiones

La práctica permitió comprobar que las bitácoras del servidor y la auditoría a nivel de fila cumplen funciones complementarias. Las bitácoras permiten registrar conexiones, errores, contexto de sesión y sentencias de modificación. La tabla de auditoría, junto con la función y el trigger, conserva las imágenes anteriores y posteriores de cada INSERT, UPDATE y DELETE.

La prueba con María García demostró que se puede identificar al usuario de sesión, la aplicación, la IP, la operación y el cambio concreto entre valores JSONB. La prueba de Pedro Ruiz comprobó que la información histórica puede permanecer en la auditoría aun después de eliminar la fila original.

También se observó un límite importante: un propietario o superusuario puede desactivar el trigger y hacer modificaciones que no se incorporan a la tabla de auditoría. La bitácora del servidor conserva evidencia de las sentencias administrativas, pero una arquitectura más robusta debe enviar los logs a un sistema externo con controles de integridad y separación de funciones.

En conclusión, la auditoría implementada aporta trazabilidad a los cambios de datos, pero no sustituye las políticas de seguridad, retención, respaldo, monitoreo externo y control de privilegios.

## 9. Alcance no realizado

La Parte C relacionada con `pgaudit` no se instaló ni configuró. Se omitió por tratarse de una extensión/actividad avanzada opcional. Las actividades obligatorias de bitácoras y auditoría de las partes A y B sí se ejecutaron y documentaron en este informe.
