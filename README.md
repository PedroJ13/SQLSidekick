# SQLSidekick

SQLSidekick es una app web local para documentar, revisar y explorar bases de datos SQL Server sin instalar objetos en el servidor.

La version actual se enfoca en:

- Inventario tecnico de servidor, base de datos, storage, estructura, codigo SQL, seguridad y SQL Agent.
- Alertas basicas por categoria.
- Documentacion de procesos basada en SQL Agent jobs.
- Lineage online para jobs, procedures, views y functions.
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
- **Processes**: inventario de procesos, steps, SQL objects detectados, recent runs y lineage maps.
- **Lineage**: consultas tabulares de dependencias y uso de tablas.
- **Health**: alertas basicas por categoria.

## Processes

El modulo Processes incluye una vista estable para:

- `Inventory`: jobs como procesos, estado, owner, next run y ultimo resultado.
- `Steps`: pasos de SQL Agent y comandos resumidos.
- `SQL Objects`: objetos SQL detectados desde steps T-SQL.
- `Recent Runs`: ejecuciones recientes del proceso.
- `Lineage maps`: mapas para Jobs, Procedures, Views y Functions.

Los mapas se generan online en cada ejecucion. No se guardan resultados en un repositorio local.

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
