# Database Init Scripts

Esta carpeta contiene los scripts que crean la estructura base de datos de Klyro.

Orden recomendado:

```txt
000-create-database.sql
001-enums.sql
002-tables.sql
```

---

## 000-create-database.sql

Crea la base de datos `klyro` si no existe y habilita extensiones necesarias.

Incluye:

```sql
CREATE DATABASE klyro;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

`pgcrypto` se usa para:

```sql
gen_random_uuid()
```

---

## 001-enums.sql

Crea todos los enums del sistema.

Ejemplos:

```txt
user_status_enum
appointment_status_enum
message_channel_enum
message_type_enum
source_enum
```

Los enums se usan para evitar estados y tipos como texto libre.

Esto protege la base de datos de valores inválidos como:

```txt
activo
Active
aprobadooo
cancelad
```

---

## 002-tables.sql

Crea todas las tablas, constraints, foreign keys, indexes y triggers.

Incluye:

- tablas de catálogo
- tablas principales
- tablas relacionales
- constraints `CHECK`
- constraints `UNIQUE`
- constraints `PRIMARY KEY`
- constraints `FOREIGN KEY`
- índices parciales
- triggers para `updated_at`

---

## Orden obligatorio

Estos scripts deben correrse en orden.

```txt
000-create-database.sql
↓
001-enums.sql
↓
002-tables.sql
```

No debes correr `002-tables.sql` antes de `001-enums.sql`, porque varias tablas dependen de enums.

---

## Uso con Docker

Si montas directamente esta carpeta como `/docker-entrypoint-initdb.d`, los archivos deben estar directamente dentro de esa carpeta.

Ejemplo seguro:

```txt
/docker-entrypoint-initdb.d/
├── 000-create-database.sql
├── 001-enums.sql
└── 002-tables.sql
```

Si mantienes la estructura:

```txt
database/init/
database/seeds/
```

necesitas un runner o script principal que ejecute los archivos con `\i`.

---

## Re-ejecución

Los scripts están pensados para desarrollo, pero recuerda:

PostgreSQL en Docker solo ejecuta los scripts de init automáticamente cuando el volumen de datos está vacío.

Si ya existe el volumen, no se ejecutan otra vez.

Para reiniciar desde cero en desarrollo:

```bash
docker compose down -v
docker compose up -d
```

Cuidado: `-v` borra el volumen y por lo tanto borra los datos.

---

## Recomendación de nombres

Recomiendo usar:

```txt
000-create-database.sql
001-enums.sql
002-tables.sql
```

Evitar:

```txt
000-init.sql
001-create-database.sql
```

porque puede ser confuso si ambos parecen hacer inicialización.
