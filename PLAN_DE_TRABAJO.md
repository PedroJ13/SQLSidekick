# SQLSidekick - Plan de trabajo

Fecha de actualizacion: 2026-05-23

## Vision

SQLSidekick debe evolucionar de una herramienta local de inventario SQL Server a una plataforma de inteligencia operativa para bases de datos y procesos de datos.

El foco del producto es explicar:

- que existe en la base,
- que procesos lo ejecutan,
- que objetos y tablas estan involucrados,
- que dependencias existen,
- que alertas basicas aparecen,
- que deberia revisarse primero.

## Estado actual

La app ya cuenta con una base funcional para documentacion, lineage online, diagnostico Live y Operations Review.

Componentes principales:

- `app.py`: arranque local en `127.0.0.1:8765`.
- `sqlsidekick/http_app.py`: API local para consultas, alertas, detalles y lineage maps.
- `sqlsidekick/query_loader.py`: loader de scripts `.sql` versionados.
- `sqlsidekick/sql_server.py`: conexion SQL Server via ODBC/pymssql.
- `static/`: UI web sin framework frontend pesado.
- `sql/`: consultas separadas por categoria, con versiones `light` y `full`.

Modulos actuales:

- **Documentation**: servidor, database, storage, structure, constraints, SQL code, security y SQL Agent jobs.
- **Processes**: lineage maps visuales para Jobs, Procedures, Views y Functions.
- **Live**: dashboard/checks online para actividad actual, bloqueos, waits, TempDB y log.
- **Operations > Review**: Health dashboard, Jobs Health, Index Health, Storage/Datafiles Health, Waits/TempDB Review, Query Store Intelligence, Impact Analysis y Recommendations.

## Estado funcional por modulo

### Documentation

Estado: listo como primera etapa de documentacion basica.

Incluye inventario de:

- Server.
- Database.
- Storage.
- Structure.
- Constraints.
- SQL Code.
- Security.
- SQL Agent Jobs.

Tambien incluye detalles para:

- Tablas: columnas, indices, foreign keys y SQL code que referencia la tabla.
- Objetos SQL: detalle y objetos relacionados.

### Processes

Estado: Jobs/Lineage basico listo.

El modulo Processes queda enfocado en mapas visuales:

  - Jobs.
  - Procedures.
  - Views.
  - Functions.

Los mapas de lineage muestran:

```text
Job/Object -> Step/Root -> SQL Object -> Table -> Trigger/Computed Column
```

Incluyen:

- vista grafica colapsable,
- arbol detallado,
- resumen de impacto,
- detalles por nodo,
- fragmentos de codigo,
- direccion inversa para tablas dentro del mapa,
  - persistencia de ultima seleccion por tipo de mapa en el navegador.

La documentacion tabular de SQL Agent queda dentro de **Documentation > Jobs**:

- SQL Agent jobs.
- SQL Agent job steps.
- SQL Agent job schedules.
- SQL Agent job history.

### Live

Estado: Live dashboard/checks listo como primera version online.

El modulo Live permite revisar rapidamente actividad actual sin persistencia:

- **Live dashboard** con semaforo, presion, actividad y resource pressure.
- **Current requests**.
- **Top active sessions**.
- **Blocking now**.
- **Root blockers**.
- **Active waits**.
- **TempDB usage by session**.
- **Transaction log usage**.

El dashboard permite navegar desde cada KPI al detalle correspondiente.

Settings incluye auto-refresh opcional para refrescar la consulta Live activa cada X segundos.

### Health

Estado: Operations > Review listo como modulo principal de accion inicial.

Incluye:

- **Health dashboard**: estado general por categoria usando alertas basicas existentes.
- Cards clicables para ver alertas por categoria.
- Totales por severidad clicables.
- Boton para ver todas las alertas.
- **Jobs Health**: dashboard accionable enfocado en SQL Agent jobs.
- **Index Health**: revision online de missing indexes, indices no usados, heaps, indices deshabilitados e hipoteticos.
- **Storage / Datafiles Health**: revision online de uso de archivos, autogrowth, log usage y layout.
- **Waits / TempDB Review**: revision online de bloqueos, waits, requests largos, TempDB y log pressure.
- **Query Store Intelligence**: revision online de estado de Query Store, top queries, regresiones, waits por query y diversidad de planes.
- **Impact Analysis**: analisis online de riesgo antes de cambiar tablas, columnas, procedures, views o functions.
- **Recommendations**: recomendaciones con evidencia, severidad, objeto afectado, SQL sugerido y notas de seguridad.

Jobs Health revisa:

- jobs deshabilitados,
- jobs fallidos recientes,
- jobs sin schedule futuro activo,
- jobs sin ejecucion reciente,
- steps con retry alto,
- owners sospechosos o inexistentes.

## Decisiones de producto actuales

### Sin snapshots por ahora

Snapshots / History queda fuera de esta version.

Motivo:

- requiere definir repositorio local o externo,
- implica modelo de persistencia,
- pertenece mejor a una version mas enterprise.

La version actual trabaja online: consulta SQL Server, renderiza resultados y no almacena historicos de analisis.

Esto aplica tambien a Live y Health: no hay tablas locales de snapshots ni repositorio historico.

### SQL Server-first

El producto sigue enfocado primero en SQL Server. Otras plataformas se evaluaran despues.

### Lineage pragmatica

El lineage no busca perfeccion absoluta desde el inicio.

Se muestran niveles de confianza y mensajes claros cuando SQL Server no puede resolver dependencias por:

- SQL dinamico,
- temp tables,
- permisos,
- referencias cross-database,
- modulos encriptados,
- metadata incompleta.

## Backlog recomendado

### P0 - Estabilizacion actual

- Probar Documentation completa en entornos con permisos distintos.
- Probar Live dashboard/checks con y sin permisos de DMV.
- Probar Health dashboard y Jobs Health con usuario principal y usuario dedicado de SQL Agent.
- Probar Processes lineage maps con jobs grandes y chicos.
- Revisar mensajes de error en entornos AWS RDS y permisos limitados.
- Confirmar que `light` y `full` cargan todas las consultas esperadas.
- Revisar nombres user friendly de columnas nuevas.

### P1 - Mejoras de lineage online

- Filtros por tipo de nodo.
- Filtros por confianza.
- Resaltar nodos con dependencias parciales.
- Mejorar deteccion read/write cuando sea posible.
- Mejorar parseo de SQL dinamico simple.
- Mostrar referencias cross-database con badge especial.

### P2 - Impact analysis online

Objetivo:

Responder que podria afectarse antes de cambiar un objeto.

Estado: MVP inicial implementado.

- Impact analysis por tabla.
- Impact analysis por columna.
- Impact analysis por procedure/view/function.
- Separar dependencias directas e indirectas.
- Incluir jobs relacionados.
- Incluir ultimo run / ultimo fallo cuando exista.

Siguientes mejoras:

- Mejorar deteccion read/write.
- Integrar recomendaciones/fixes sugeridos desde findings de Health.
- Marcar objetos externos o cross-database con mayor claridad.
- Enlazar findings hacia detalles de Documentation y mapas de Processes.

### P3 - Recommendations / Suggested SQL

Estado: MVP inicial implementado.

- Consolidar findings de Jobs, Index, Storage y Waits/TempDB.
- Mostrar evidencia, severidad, objeto afectado, SQL sugerido y notas de seguridad.
- Mantener el SQL como propuesta revisable, nunca ejecucion automatica.

Siguientes mejoras:

- Enlazar cada recomendacion con Impact Analysis.
- Exportar recomendacion completa.
- Marcar pre-requisitos por edicion/permisos.
- Diferenciar SQL diagnostico vs SQL de cambio.

### P4 - Query Store Intelligence

Objetivo:

Detectar regresiones y explicarlas con contexto de procesos y lineage.

Estado: MVP inicial implementado.

- Top regressions por duracion, CPU, reads y writes.
- Queries con cambio de plan.
- Waits dominantes.
- Relacion con objeto/proceso cuando sea posible.
- Resumen humano de causa probable y siguiente accion.

Implementado:

- Query Store overview.
- Top queries por duracion, CPU y lecturas.
- Regresiones recientes contra baseline corta.
- Wait categories por query.
- Plan diversity / forced plan signals.
- Recomendaciones basicas desde regresiones de Query Store.

Siguientes mejoras:

- Enlazar query text con objetos/procesos cuando el texto permita resolverlos.
- Enlazar regresiones con lineage maps e Impact Analysis.
- Agregar filtros por ventana de tiempo.
- Separar queries parametrizadas por query hash / plan hash cuando aplique.

### P5 - Version enterprise / historico

Queda para una version posterior:

- repositorio local o central,
- snapshots,
- comparacion entre ejecuciones,
- auditoria tecnica,
- cambios desde ultimo release,
- correlacion con Query Store y alertas.

## Criterios de exito del MVP actual

El MVP actual es valioso si responde:

- Que hay en esta base?
- Que jobs existen y que ejecutan?
- Que steps tiene un proceso?
- Que SQL objects llama un proceso?
- Que tablas toca un job/procedure/view/function?
- Que triggers o columnas calculadas estan involucradas?
- Que objetos usan una tabla dentro del mapa actual?
- Que configuraciones basicas parecen riesgosas?
- Que puede estar lento ahora mismo?
- Que jobs requieren atencion primero?
- Que accion segura podria revisar para un finding?
- Que riesgo tiene aplicar una recomendacion?

## Riesgos

- SQL dinamico puede ocultar dependencias.
- `sys.sql_expression_dependencies` no siempre resuelve todo.
- Jobs pueden ejecutar SSIS, PowerShell, comandos externos o scripts complejos.
- AWS RDS y permisos limitados pueden bloquear `msdb` directo.
- El lineage perfecto es dificil; debe mantenerse el modelo de confianza.

## Principio de producto

SQLSidekick no debe convertirse en otro dashboard lleno de numeros.

Cada pantalla importante debe intentar responder:

- Que existe?
- Que proceso esta involucrado?
- Que objetos son afectados?
- Que tan confiable es la deteccion?
- Que deberia revisar primero?
