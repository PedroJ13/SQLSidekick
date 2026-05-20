# SQLSidekick - Plan de trabajo

Fecha: 2026-05-20

## Vision

SQLSidekick debe evolucionar de una herramienta local de inventario SQL Server a una plataforma de inteligencia operativa para bases de datos y procesos de datos.

La oportunidad principal no esta en mostrar mas metricas, sino en explicar que significan, que cambio, que proceso esta involucrado, que objetos estan afectados y cual es la siguiente accion probable.

El norte del producto:

- Documentacion viva de bases de datos.
- Mapa real de procesos y dependencias.
- Lineage tecnico y operativo.
- Analisis de impacto antes de cambios.
- Troubleshooting con contexto historico.
- Inteligencia sobre Query Store, jobs, waits, planes y costos.
- Explicaciones orientadas a DBA, Data Engineer y negocio.

## Problema que queremos resolver

Las herramientas actuales suelen fallar en uno o varios puntos:

- Mucha metrica, poca explicacion.
- Alertas sin contexto operativo.
- Documentacion automatica superficial o desactualizada.
- Poco entendimiento real de SQL, stored procedures, jobs y planes.
- Lineage incompleto o demasiado enterprise.
- Costos altos y adopcion compleja.
- Troubleshooting fragmentado entre monitoreo, documentacion, tickets, PRs y dashboards.
- IA superficial que resume datos, pero no diagnostica con contexto.

SQLSidekick debe diferenciarse por entender la base de datos como sistema vivo: objetos, codigo, jobs, dependencias, historial, sintomas y procesos de negocio.

## Donde vamos ahora

Estamos construyendo la primera base del producto:

- App web local en Python, sin framework frontend pesado.
- Conexion local a SQL Server.
- Consultas SQL versionadas en el repositorio.
- Modulos de inventario y documentacion.
- Ejecucion de queries por categoria desde la UI.
- Versiones `light` y `full` para controlar profundidad.
- Alertas basicas por categoria.
- Detalle de tablas y objetos de codigo.

Lo que ya existe en el repo:

- `app.py`: arranque local de la app en `127.0.0.1:8765`.
- `sqlsidekick/http_app.py`: API local para health, queries, ejecucion, alertas y detalles.
- `sqlsidekick/query_loader.py`: carga de archivos `.sql` con secciones nombradas.
- `sqlsidekick/sql_server.py`: conexion y ejecucion contra SQL Server.
- `static/`: UI web.
- `sql/server`: inventario de servidor.
- `sql/database`: propiedades y configuracion de base de datos.
- `sql/storage`: archivos, tamanos y almacenamiento.
- `sql/structure`: tablas, columnas, indices, llaves y estructura.
- `sql/code`: procedimientos, funciones, vistas y triggers.
- `sql/security`: principals, roles y permisos.
- `sql/jobs`: SQL Agent jobs, steps, schedules e historia.
- `basic_alerts`: primeras alertas por modulo.

Estado actual del producto:

> Estamos en la etapa de documentacion basica de objetos e inventario tecnico.

El siguiente paso logico es convertir esa documentacion en documentacion de procesos y lineage operativo.

## Decision de producto

No conviene saltar directo a "Query Store con IA" como siguiente fase principal.

Query Store con IA sera muy valioso, pero necesita contexto para ser realmente diferente. Si primero construimos el mapa de procesos y lineage, despues Query Store podra explicar no solo que query empeoro, sino que proceso la ejecuta, que job la dispara, que tablas afecta y que impacto tiene aguas abajo.

Orden recomendado:

1. Documentacion de objetos.
2. Documentacion de procesos.
3. Lineage tecnico y operativo.
4. Analisis de impacto.
5. Query Store Intelligence.
6. Recomendaciones IA con contexto.

## Fase 1 - Base actual: documentacion de objetos

Objetivo:

Crear una vista clara de que existe en la base de datos y como esta construido.

Incluye:

- Servidor.
- Bases de datos.
- Propiedades.
- Configuraciones.
- Tablas.
- Columnas.
- Indices.
- Llaves primarias.
- Llaves foraneas.
- Views.
- Stored procedures.
- Functions.
- Triggers.
- SQL Agent jobs.
- Job steps.
- Schedules.
- Job history.
- Storage.
- Seguridad.
- Alertas basicas.

Entregables principales:

- Inventario navegable desde la UI.
- Detalle por tabla.
- Detalle por objeto de codigo.
- Queries separadas y versionadas.
- Modo `light` y `full`.
- Primer set de health checks.

Estado:

- En progreso.
- La estructura tecnica ya existe.
- Falta endurecer experiencia de usuario, exportacion y persistencia historica.

## Fase 2 - Documentacion de procesos

Objetivo:

Pasar de "que objetos existen" a "que procesos existen y que hacen".

Preguntas que debe responder:

- Que job ejecuta este proceso?
- Que stored procedure corre dentro del job?
- Que tablas lee?
- Que tablas escribe?
- Que tablas son staging, core, mart o reporting?
- Cada cuanto corre?
- Cuando corrio por ultima vez?
- Cuanto duro?
- Fallo recientemente?
- Que pasa si falla?
- Que area o flujo de negocio depende de esto?
- Quien es el owner tecnico?
- Quien es el owner funcional?
- Que criticidad tiene?

Fuentes iniciales en SQL Server:

- `msdb.dbo.sysjobs`.
- `msdb.dbo.sysjobsteps`.
- `msdb.dbo.sysjobschedules`.
- `msdb.dbo.sysjobhistory`.
- `sys.sql_modules`.
- `sys.objects`.
- `sys.sql_expression_dependencies`.
- `sys.dm_sql_referenced_entities`.
- `sys.dm_sql_referencing_entities`.
- Texto de stored procedures, views, functions y triggers.

Primer modelo de datos logico:

- Process.
- Process step.
- Code object.
- Source object.
- Target object.
- Job.
- Schedule.
- Execution history.
- Owner.
- Criticality.
- Notes.

MVP de esta fase:

- Pantalla "Processes".
- Detectar jobs y sus steps.
- Relacionar steps con stored procedures cuando el comando sea identificable.
- Extraer objetos referenciados por stored procedures y views.
- Marcar read/write cuando sea posible.
- Generar resumen automatico inicial del proceso.
- Mostrar historial reciente del job.
- Permitir agregar owner, criticidad y notas manuales.

## Fase 3 - Lineage tecnico y operativo

Objetivo:

Construir un grafo de dependencias que muestre flujo real de datos, no solo relaciones FK.

Ejemplo esperado:

```text
SQL Agent Job
  -> Job Step
    -> Stored Procedure
      -> staging table
        -> transformation table
          -> reporting table
            -> dashboard / consumer
```

Lineage inicial SQL Server:

- Objeto A referencia objeto B.
- Stored procedure lee tabla X.
- Stored procedure escribe tabla Y.
- View depende de tablas y views.
- Trigger modifica o depende de objetos.
- Job ejecuta procedure o comando SQL.

Capacidades necesarias:

- Parser inicial de SQL suficientemente practico.
- Dependencias detectadas por catalog views.
- Heuristicas para SQL dinamico.
- Marcado de confianza de la dependencia: alta, media, baja.
- Deteccion de objetos no resueltos.
- Deteccion de referencias cross-database.
- Deteccion de referencias a linked servers si aplica.

MVP de esta fase:

- Busqueda "que usa esta tabla".
- Busqueda "que alimenta esta tabla".
- Vista upstream/downstream.
- Grafo simple por objeto.
- Grafo simple por proceso.
- Exportacion Markdown/JSON.
- Badges de confianza para dependencias.

## Fase 4 - Analisis de impacto

Objetivo:

Responder que se rompe o que podria afectarse antes de cambiar un objeto.

Preguntas que debe responder:

- Si cambio esta tabla, que SPs se afectan?
- Si elimino esta columna, donde se usa?
- Si modifico esta view, que reportes o procesos downstream dependen de ella?
- Que jobs corren despues de este proceso?
- Que objetos criticos dependen de esta tabla?
- Que cambios son de alto riesgo?

MVP:

- "Impact analysis" por tabla.
- "Impact analysis" por columna.
- "Impact analysis" por stored procedure/view/function.
- Lista ordenada por criticidad.
- Separar dependencias directas e indirectas.
- Mostrar jobs relacionados.
- Mostrar ultima ejecucion y ultimo fallo cuando exista.

Valor diferencial:

> SQLSidekick no solo documenta; ayuda a decidir si un cambio es seguro.

## Fase 5 - Historico y snapshots

Objetivo:

Poder responder "que cambio desde ayer", "que cambio desde el ultimo release" y "cuando empezo el problema".

Necesario para:

- Deteccion de cambios.
- Regresiones.
- Auditoria tecnica.
- Correlacion temporal.
- Query Store Intelligence.

Snapshots recomendados:

- Objetos y definiciones.
- Columnas.
- Indices.
- Jobs.
- Schedules.
- Job durations.
- Storage.
- Table growth.
- Query Store summaries.
- Alertas detectadas.

Decisiones tecnicas por definir:

- Archivo local SQLite.
- Export JSON versionado.
- Ambos: SQLite para app y JSON/Markdown para portabilidad.

MVP:

- Guardar snapshot manual.
- Comparar snapshot actual vs anterior.
- Mostrar objetos nuevos, modificados y eliminados.
- Mostrar cambios en jobs.
- Mostrar crecimiento por tabla.
- Mostrar cambios en indices.

## Fase 6 - Query Store Intelligence

Objetivo:

Usar Query Store para detectar regresiones y explicar causas probables con contexto de procesos.

Preguntas que debe responder:

- Que queries empeoraron?
- Desde cuando?
- Cambio el plan?
- Cambio el volumen de ejecuciones?
- Cambio el tiempo promedio?
- Que waits dominan?
- Que stored procedure o proceso contiene esa query?
- Que job la ejecuta?
- Que tablas toca?
- Que impacto downstream puede tener?
- Que accion conviene revisar primero?

Fuentes:

- `sys.query_store_query`.
- `sys.query_store_query_text`.
- `sys.query_store_plan`.
- `sys.query_store_runtime_stats`.
- `sys.query_store_runtime_stats_interval`.
- `sys.query_store_wait_stats`.
- `sys.query_context_settings`.
- Plan XML cuando aplique.

MVP:

- Top regressions por duracion.
- Top regressions por CPU.
- Top regressions por reads.
- Queries con cambio de plan.
- Queries con waits dominantes.
- Comparacion antes/despues.
- Relacion con stored procedure cuando sea posible.
- Resumen humano: causa probable y siguiente paso.

Ejemplo de salida deseada:

```text
El proceso Nightly Sales Load empeoro 320% desde el ultimo snapshot.
La query principal cambio de plan y aumento logical reads.
El cambio afecta fact.Sales y procesos downstream de reporting.
Primera accion sugerida: revisar cardinalidad y parametros del procedure dbo.LoadSalesDaily.
```

## Fase 7 - IA con contexto

Objetivo:

Agregar IA donde ya existe contexto estructurado suficiente.

No queremos una IA que solo diga "CPU alta". Queremos una IA que conecte:

- Objeto.
- Proceso.
- Job.
- Historial.
- Query Store.
- Dependencias.
- Cambios recientes.
- Alertas.
- Criticidad.
- Owner.

Casos de uso:

- Resumen automatico de proceso.
- Explicacion de stored procedure.
- Deteccion de anti-patterns SQL.
- Recomendaciones de tuning.
- Root cause probable.
- Generacion de documentacion viva.
- Preguntas en lenguaje natural sobre la base.

Ejemplos:

- "Que cambio desde ayer?"
- "Por que este job tardo mas?"
- "Que tablas toca este proceso?"
- "Que impacto tiene modificar esta columna?"
- "Cual query explica el spike de TempDB?"
- "Que objetos parecen huerfanos?"
- "Que procesos son mas criticos para negocio?"

## Fase 8 - Integraciones externas

Objetivo:

Conectar documentacion, monitoreo y delivery.

Integraciones potenciales:

- Git / Azure DevOps / GitHub.
- Jira / Azure Boards.
- Power BI.
- dbt.
- Snowflake.
- Databricks SQL.
- Microsoft Fabric.
- Slack / Teams.

No son prioridad inmediata, pero deben influir en el diseno para no cerrar puertas.

## Roadmap recomendado

### Corto plazo

- Terminar y pulir documentacion basica de objetos.
- Mejorar detalle de tablas y objetos de codigo.
- Agregar exportacion Markdown/JSON.
- Crear pantalla de jobs mas operativa.
- Detectar procesos desde SQL Agent jobs.
- Relacionar jobs con stored procedures.

### Mediano plazo

- Construir Process Map.
- Construir lineage por objeto.
- Agregar upstream/downstream.
- Agregar impact analysis.
- Guardar snapshots locales.
- Comparar cambios entre snapshots.

### Largo plazo

- Query Store Intelligence.
- Correlacion temporal.
- IA para diagnostico.
- Integraciones con repositorios, tickets y dashboards.
- Soporte Snowflake/dbt/Databricks/Fabric.

## Primer backlog sugerido

### P0 - Base de producto

- Revisar UI actual y ordenar navegacion por modulos.
- Confirmar que todas las queries `light` y `full` cargan correctamente.
- Agregar exportacion de resultados.
- Agregar estados de loading/error mas claros.
- Agregar README operativo para correr y probar.

### P1 - Procesos

- Crear modulo `processes`.
- Agregar query de jobs + steps + schedules + last run.
- Detectar stored procedures llamados desde job steps.
- Crear vista de proceso por job.
- Mostrar step order, command, database, subsystem y schedule.
- Agregar estado historico: ultima ejecucion, duracion, resultado.

### P2 - Dependencias y lineage

- Expandir dependencias desde `sys.sql_expression_dependencies`.
- Agregar dependencias entrantes y salientes por objeto.
- Extraer referencias desde definiciones SQL para casos donde catalog views no resuelven.
- Clasificar dependencias como read/write cuando sea posible.
- Crear endpoint de lineage por objeto.
- Crear vista upstream/downstream.

### P3 - Impact analysis

- Crear endpoint de impacto por objeto.
- Crear endpoint de impacto por columna.
- Ordenar impacto por distancia y criticidad.
- Incluir jobs relacionados.
- Incluir ultima ejecucion o ultimo fallo.
- Exportar analisis a Markdown.

### P4 - Historico

- Definir almacenamiento local.
- Guardar snapshots.
- Comparar snapshots.
- Mostrar cambios desde ultimo snapshot.
- Preparar base para Query Store.

### P5 - Query Store

- Agregar modulo Query Store.
- Detectar si Query Store esta habilitado.
- Traer top queries por duracion, CPU, reads, writes y ejecuciones.
- Detectar regresiones.
- Detectar cambio de plan.
- Relacionar query con objeto/proceso.
- Generar explicacion inicial.

## Criterios de exito del MVP

El MVP empieza a ser realmente valioso cuando puede responder:

- Que hay en esta base?
- Que jobs existen y que ejecutan?
- Que procesos alimentan esta tabla?
- Que objetos dependen de este objeto?
- Que pasaria si cambio esta tabla o columna?
- Que cambio desde el ultimo snapshot?
- Que proceso fallo o empeoro recientemente?

## Riesgos

- SQL dinamico puede ocultar dependencias.
- `sys.sql_expression_dependencies` no siempre resuelve todo.
- Jobs pueden ejecutar scripts complejos, SSIS, PowerShell o comandos externos.
- Permisos limitados pueden impedir ver metadata completa.
- Query Store puede estar deshabilitado o con retencion insuficiente.
- Lineage perfecto es dificil; se debe mostrar nivel de confianza.
- IA sin contexto suficiente puede generar respuestas genericas.

Mitigacion:

- Mostrar confianza de cada hallazgo.
- Separar "detectado por catalogo" vs "inferido por texto".
- Permitir notas/manual overrides.
- Guardar snapshots para mejorar contexto historico.
- Empezar SQL Server-first antes de abrir demasiadas plataformas.

## Principio de producto

SQLSidekick debe evitar convertirse en otro dashboard lleno de numeros.

Cada pantalla importante debe intentar responder:

- Que paso?
- Que cambio?
- Que proceso esta involucrado?
- Que objetos son afectados?
- Que tan grave es?
- Que deberia revisar primero?

## Siguiente paso recomendado

Construir el modulo `Processes`.

Primer entregable concreto:

- Nueva categoria SQL `sql/processes`.
- Query `processes` con jobs, steps, schedules y ultimo resultado.
- Deteccion inicial de stored procedures llamadas desde job steps.
- Endpoint/API reutilizando el loader actual.
- Vista UI para explorar procesos.
- Boton o panel "ver dependencias" para conectar con objetos de codigo.

Este paso conecta directamente lo que ya existe con la siguiente capa de valor: documentacion de procesos y lineage.
