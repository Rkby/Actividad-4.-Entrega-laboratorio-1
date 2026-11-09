# LAB-01 — Bitácoras y auditoría del dato en PostgreSQL

Paquete de entrega preparado con los resultados observados durante la práctica en Windows y PostgreSQL 16.15.

## Contenido

```text
LAB01_entrega/
├── README.md
├── informe.md
├── SHA256.txt
├── verificar_hash.ps1
├── SQL/
│   ├── 01_revision_y_configuracion.sql
│   ├── 02_base_datos_y_clientes.sql
│   ├── 03_usuarios_y_permisos.sql
│   ├── 04_bitacoras_y_vista_dba.sql
│   ├── 05_auditoria_funcion_trigger.sql
│   └── 06_pruebas_y_consultas.sql
├── evidencias/
│   └── README.md
└── logs/
    └── README.md
```


## Entorno utilizado

- Sistema operativo: Windows.
- PostgreSQL: 16.15, 64 bits.
- Cliente: `psql`.
- Base de datos de práctica: `comercial`.
- Usuario administrador: `postgres`.
- Codificación del servidor: UTF8.
- Autenticación local/TCP observada: `scram-sha-256`.

## Orden de lectura y ejecución

Los SQL se entregan como referencia reproducible. **No ejecutes todos a ciegas en una base que ya tiene datos**, porque algunos crean objetos o realizan modificaciones deliberadas.

1. `SQL/01_revision_y_configuracion.sql`: revisa parámetros y contiene la secuencia de configuración de bitácoras.
2. `SQL/02_base_datos_y_clientes.sql`: crea `comercial`, la tabla y los cinco clientes de prueba. Se ejecuta una sola vez.
3. `SQL/03_usuarios_y_permisos.sql`: crea roles y concede permisos. Introduce las contraseñas de forma interactiva con `\password`; nunca las guardes en archivos SQL.
4. `SQL/04_bitacoras_y_vista_dba.sql`: crea el esquema privado `dba` y la vista de lectura del archivo LOG actual.
5. `SQL/05_auditoria_funcion_trigger.sql`: crea el esquema, tabla, función y trigger de auditoría.
6. `SQL/06_pruebas_y_consultas.sql`: contiene consultas de comprobación y ejemplos de pruebas. Lee los comentarios antes de ejecutar instrucciones que modifican o eliminan datos.

Para ejecutar desde SQL Shell (psql), abre el archivo correspondiente o usa `\i 'C:/ruta/al/archivo.sql'`. Los comandos `\password`, `\connect` y `\i` son comandos propios de `psql`, no SQL estándar.

## Incorporar el LOG y las evidencias

1. Copia desde tu escritorio el archivo `LAB01\logs\postgresql-lab01.log` a esta carpeta, dentro de `logs/`.
2. Copia las capturas de las actividades 1 a 15 dentro de `evidencias/`.
3. Conserva el LOG original bajo acceso restringido. La bitácora puede contener nombres de usuarios, direcciones IP, consultas y datos de prueba.
4. Si vas a subir el material a un repositorio público, revisa y redacta cualquier dato confidencial antes de publicarlo. La búsqueda de la contraseña temporal devolvió cero coincidencias en la vista del LOG consultado; esto no sustituye una revisión del archivo completo ni de archivos rotados.

## Verificar SHA-256

El hash observado durante la práctica está en `SHA256.txt`. Una vez que coloques el archivo LOG en `logs/`, ejecuta PowerShell desde esta carpeta:

```powershell
.\verificar_hash.ps1
```

El script compara el archivo local con el hash documentado. Si cambias o redactas el LOG, su hash cambiará; calcula y documenta el nuevo hash por separado, sin sobrescribir la evidencia del original.

## Seguridad y alcance

- Las contraseñas de `postgres`, `app_ventas` y `soporte_ana` no se incluyen en este paquete.
- El rol `rol_temporal` se creó y eliminó durante la práctica.
- El usuario `app_ventas` tuvo `SELECT` y `UPDATE` sobre `clientes`; `soporte_ana` tuvo `SELECT`.
- `app_ventas` no obtuvo acceso al esquema privado `auditoria`.
- `pgAudit` (Parte C) no se instaló porque el laboratorio la plantea como opcional/avanzada.
- La vista `dba.bitacora` lee el archivo devuelto por `pg_current_logfile()`; si el servidor rota el LOG, la vista mostrará el archivo actual, no un histórico consolidado de todos los archivos rotados.
