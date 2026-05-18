# SQLSidekick

SQLSidekick es una app web local para documentar y revisar bases de datos SQL Server sin instalar objetos en el servidor.

Esta primera version se enfoca en inventario/documentacion:

- Conectar a SQL Server on-premises o cloud desde la maquina local.
- Ejecutar consultas `.sql` versionadas en el repo.
- Mostrar objetos, columnas, indices, llaves foraneas, procedimientos, vistas, triggers, tamanos y archivos.
- Dejar una base lista para agregar historicos, crecimiento e IA despues.

## Requisitos

- Python 3.12+
- Driver ODBC de SQL Server instalado en Windows.
- Paquetes Python `pyodbc` y/o `pymssql` para conectarse a SQL Server.

La app web y la UI no dependen de frameworks externos. Para conectarse realmente a SQL Server se necesita:

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

## Seguridad

Las credenciales se envian solo al servidor local de la app para abrir la conexion ODBC. No se guardan en disco en esta version.

## Consultas

Las consultas viven en archivos separados dentro de `sql/`. Cada seccion se marca asi:

```sql
-- name: tables
SELECT ...
```

La app carga esas secciones y las ejecuta cuando eliges un modulo en la web.
