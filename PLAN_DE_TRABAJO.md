# SQLSidekick - Plan de trabajo

Fecha de actualizacion: 2026-05-22

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

La app ya cuenta con una base funcional para documentacion y lineage online.

Componentes principales:

- `app.py`: arranque local en `127.0.0.1:8765`.
- `sqlsidekick/http_app.py`: API local para consultas, alertas, detalles y lineage maps.
- `sqlsidekick/query_loader.py`: loader de scripts `.sql` versionados.
- `sqlsidekick/sql_server.py`: conexion SQL Server via ODBC/pymssql.
- `static/`: UI web sin framework frontend pesado.
- `sql/`: consultas separadas por categoria, con versiones `light` y `full`.

Modulos actuales:

- **Documentation**: servidor, database, storage, structure, constraints, SQL code, security y SQL Agent jobs.
- **Processes**: inventario de procesos, steps, SQL objects, recent runs y lineage maps.
- **Lineage**: consultas tabulares de dependencias.
- **Health**: alertas basicas por categoria.

## Estado funcional por modulo

### Documentation

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

El modulo Processes queda como vista estable para procesos operativos:

- **Inventory**: procesos detectados desde SQL Agent jobs.
- **Steps**: steps del job.
- **SQL Objects**: objetos SQL llamados desde steps T-SQL.
- **Recent Runs**: ejecuciones recientes.
- **Process Detail**: popup con tabs `Overview`, `Steps`, `SQL Objects` y `Recent Runs`.
- **Lineage maps**:
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

### Health

Existen alertas basicas para categorias principales, incluyendo procesos/jobs.

Ejemplos:

- jobs deshabilitados,
- ultimo run fallido,
- jobs sin schedule,
- jobs que no corren hace X dias,
- retries altos,
- owners sospechosos o inexistentes.

## Decisiones de producto actuales

### Sin snapshots por ahora

Snapshots / History queda fuera de esta version.

Motivo:

- requiere definir repositorio local o externo,
- implica modelo de persistencia,
- pertenece mejor a una version mas enterprise.

La version actual trabaja online: consulta SQL Server, renderiza resultados y no almacena historicos de analisis.

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

- Probar Processes con jobs grandes y chicos.
- Probar mapas para procedures, views y functions.
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

MVP:

- Impact analysis por tabla.
- Impact analysis por columna.
- Impact analysis por procedure/view/function.
- Separar dependencias directas e indirectas.
- Incluir jobs relacionados.
- Incluir ultimo run / ultimo fallo cuando exista.

### P3 - Query Store Intelligence

Objetivo:

Detectar regresiones y explicarlas con contexto de procesos y lineage.

MVP:

- Top regressions por duracion, CPU, reads y writes.
- Queries con cambio de plan.
- Waits dominantes.
- Relacion con objeto/proceso cuando sea posible.
- Resumen humano de causa probable y siguiente accion.

### P4 - Version enterprise / historico

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
