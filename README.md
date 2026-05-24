# SQLSidekick

SQLSidekick es una app web local para documentar, revisar y explorar bases de datos SQL Server sin instalar objetos en el servidor.

La version actual se enfoca en:

- Inventario tecnico de servidor, base de datos, storage, estructura, codigo SQL, seguridad y SQL Agent.
- Alertas basicas por categoria.
- Documentacion de Jobs basada en SQL Agent.
- Lineage basico online para jobs, procedures, views y functions.
- Live dashboard/checks para revisar actividad actual sin persistencia.
- Operations Review con Health, Jobs/Index/Storage/Waits reviews, Impact Analysis y Recommendations.
- Impact Analysis online para revisar riesgo antes de cambiar objetos.
- Mapas visuales de dependencias sin guardar snapshots ni historial local.

## Requisitos

- Python 3.12+
- Driver ODBC de SQL Server instalado en Windows.
- Paquetes Python `pyodbc` y/o `pymssql`.

Instala dependencias con:

```powershell
python -m pip install -r requirements.txt
```

La app intenta usar ODBC primero. Si Windows/ODBC falla por TLS/Schannel y la autenticacion es SQL Login, usa `pymssql` como alternativa.

## Ejecutar local

```powershell
python app.py
```

Luego abre:

```text
http://127.0.0.1:8765
```

## Modulos

- **Documentation**: documentacion basica de objetos SQL Server.
- **Processes**: mapas visuales de lineage para jobs, procedures, views y functions.
- **Live**: diagnostico online de actividad actual, bloqueos, waits, TempDB y log.
- **Operations > Review**: Health dashboard, Jobs Health, Index Health, Storage/Datafiles Health, Waits/TempDB Review, Impact Analysis y Recommendations.

## Processes

El modulo Processes queda enfocado en mapas visuales de lineage:

- `Lineage maps`: mapas para Jobs, Procedures, Views y Functions.

Los mapas se generan online en cada ejecucion. No se guardan resultados en un repositorio local.

La documentacion tabular de SQL Agent jobs vive dentro de **Documentation > Jobs**.

## Lineage maps

Los mapas muestran:

```text
Job/Object -> Step/Root -> SQL Object -> Table -> Trigger/Computed Column
```

Incluyen:

- Vista grafica colapsable.
- Arbol detallado colapsable.
- Resumen de impacto.
- Detalle por nodo.
- Fragmentos de codigo donde se detectan referencias.
- Direccion inversa para tablas usadas dentro del mapa.

La deteccion usa metadata de SQL Server cuando existe y heuristicas sobre comandos T-SQL cuando aplica. SQL dinamico, permisos limitados, referencias cross-database, temp tables o modulos encriptados pueden reducir la precision.

## Live

El modulo Live es una vista online para responder "que puede estar lento ahora?" sin guardar datos:

- **Live dashboard**: semaforo, presion actual, actividad y resource pressure.
- **Current requests**: requests activos y de larga duracion.
- **Top active sessions**: sesiones activas por CPU, lecturas, escrituras y duracion.
- **Blocking now** y **Root blockers**.
- **Active waits**.
- **TempDB usage by session**.
- **Transaction log usage**.

El dashboard permite navegar desde cada KPI al detalle correspondiente. En Settings puede habilitarse auto-refresh para refrescar la consulta Live activa cada X segundos.

## Health

Dentro de **Operations > Review**, Health consolida alertas basicas y revisiones operativas:

- **Health dashboard**: estado general por categoria y detalle filtrado desde cada card.
- **Jobs health**: hallazgos accionables para SQL Agent jobs.
- **Index health**: missing indexes, indices no usados, heaps, indices deshabilitados o hipoteticos.
- **Storage / Datafiles health**: uso de archivos, autogrowth, log usage y layout de datafiles.
- **Waits / TempDB review**: bloqueos, waits activos, requests largos, uso de TempDB y presion del log.
- **Impact analysis**: riesgo antes de cambiar tablas, columnas, procedures, views o functions.
- **Recommendations**: acciones recomendadas con evidencia, impacto, SQL sugerido y notas de seguridad.

Jobs Health revisa:

- jobs fallidos recientes,
- jobs sin ejecucion reciente,
- jobs sin schedule futuro activo,
- owners no resueltos, deshabilitados o sospechosos,
- steps con retry alto,
- jobs deshabilitados.

Health no guarda historico. Ejecuta reglas online contra SQL Server y muestra el resultado actual.

## Impact Analysis

Impact Analysis responde "si cambio esto, que se afecta?" usando metadata visible online:

- dependencias directas e indirectas,
- dependencias upstream/downstream,
- triggers, computed columns y constraints relacionados,
- jobs relacionados cuando hay credenciales de SQL Agent configuradas,
- ultimo run visible del job cuando aplica,
- nivel de riesgo y confianza.

No ejecuta cambios ni fixes. La salida es una guia de revision previa al cambio.

## Recommendations

Recommendations convierte findings online en acciones revisables:

- evidencia,
- severidad,
- objeto afectado,
- impacto o riesgo conocido,
- accion recomendada,
- SQL sugerido,
- notas de seguridad.

El SQL sugerido es una ayuda para revision. SQLSidekick no lo ejecuta automaticamente.

## Seguridad

Las credenciales se envian solo al servidor local de la app para abrir la conexion SQL Server. La app puede guardar en `localStorage` del navegador:

- borrador de conexion,
- preferencias de version `light/full`,
- credenciales opcionales de SQL Agent configuradas por el usuario,
- ultima seleccion de mapas por tipo.

## Consultas

Las consultas viven en archivos separados dentro de `sql/`. Cada seccion se marca asi:

```sql
-- name: tables
-- title: Tables
-- description: Table inventory.
SELECT ...
```

La app carga esas secciones y las ejecuta cuando eliges un modulo en la web. Existen versiones `light` y `full` para controlar profundidad.

## Fuera de alcance por ahora

- Snapshots historicos.
- Comparacion entre ejecuciones.
- Repositorio local de analisis.
- Query Store Intelligence.
- IA con contexto historico.
