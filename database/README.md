# Klyro Database

Este directorio contiene la estructura base de datos de Klyro: scripts de inicialización, seeds, migraciones futuras y documentación del modelo.

Klyro usa:

```txt
Frontend: React
Backend: NestJS
Database: PostgreSQL
```

La base de datos está diseñada para soportar:

- múltiples negocios
- múltiples sucursales por negocio
- workers sin necesidad de cuenta de usuario
- servicios por worker
- servicios por sucursal
- horarios por worker
- excepciones de disponibilidad
- clientes por negocio
- conversaciones y mensajes
- citas internas como fuente principal de verdad
- templates de mensajes
- notificaciones internas
- planes y límites de uso
- integraciones futuras con WhatsApp y calendarios externos

---

## Estructura recomendada

```txt
database/
├── init/
│   ├── 000-create-database.sql
│   ├── 001-enums.sql
│   └── 002-tables.sql
├── seeds/
│   ├── 001-seed-general-catalogs.sql
│   ├── 002-seed-security.sql
│   ├── 003-seed-operational-types.sql
│   ├── 004-seed-message-templates.sql
│   └── 005-seed-plans.sql
├── migrations/
├── database-der.mmd
└── README.md
```

Tu estructura actual está bien organizada, pero recomiendo evitar nombres ambiguos como `000-init.sql` si ese archivo hace lo mismo que `001-create-database.sql`.

Recomendación final:

```txt
database/init/000-create-database.sql
database/init/001-enums.sql
database/init/002-tables.sql
```

Y para seeds:

```txt
database/seeds/001-seed-general-catalogs.sql
database/seeds/002-seed-security.sql
database/seeds/003-seed-operational-types.sql
database/seeds/004-seed-message-templates.sql
database/seeds/005-seed-plans.sql
```

---

## Importante sobre Docker

Si usas la imagen oficial de PostgreSQL y montas directamente una carpeta en:

```txt
/docker-entrypoint-initdb.d
```

PostgreSQL ejecuta los scripts de inicialización cuando el volumen de datos está vacío.

Pero debes cuidar algo:

```txt
/docker-entrypoint-initdb.d/
├── 000-create-database.sql
├── 001-enums.sql
└── 002-tables.sql
```

es más seguro que:

```txt
/docker-entrypoint-initdb.d/
├── init/
│   └── ...
└── seeds/
    └── ...
```

porque las subcarpetas no son una garantía si no tienes un script runner propio.

Si quieres mantener tu estructura con subcarpetas, crea un script principal que llame los archivos en orden usando `\i`.

Ejemplo:

```sql
\i /docker-entrypoint-initdb.d/init/000-create-database.sql
\i /docker-entrypoint-initdb.d/init/001-enums.sql
\i /docker-entrypoint-initdb.d/init/002-tables.sql

\i /docker-entrypoint-initdb.d/seeds/001-seed-general-catalogs.sql
\i /docker-entrypoint-initdb.d/seeds/002-seed-security.sql
\i /docker-entrypoint-initdb.d/seeds/003-seed-operational-types.sql
\i /docker-entrypoint-initdb.d/seeds/004-seed-message-templates.sql
\i /docker-entrypoint-initdb.d/seeds/005-seed-plans.sql
```

---

## Orden lógico de ejecución

La base debe levantarse en este orden:

```txt
1. Crear base de datos y extensiones
2. Crear enums
3. Crear tablas
4. Insertar catálogos generales
5. Insertar roles, permisos y relaciones
6. Insertar tipos operativos
7. Insertar templates globales
8. Insertar planes
```

---

## Qué contiene cada carpeta

### `init/`

Contiene scripts que crean la estructura.

No deben depender de datos de prueba ni de datos de negocio.

Incluye:

- base de datos
- extensiones
- enums
- tablas
- constraints
- foreign keys
- indexes
- triggers

### `seeds/`

Contiene datos necesarios para que el sistema funcione.

Incluye:

- países
- monedas
- prefijos telefónicos
- idiomas
- tipos de negocio
- proveedores de pago
- roles base
- permisos base
- tipos de disponibilidad
- tipos de notificación
- templates globales
- planes base

### `migrations/`

Reservado para cambios futuros de producción.

Ejemplos:

```txt
2026-05-21-add-worker-rating.sql
2026-05-22-add-branch-opening-hours.sql
2026-05-25-add-client-tags.sql
```

Durante el MVP puedes trabajar con scripts de init. Cuando el producto ya tenga datos reales, debes usar migraciones.

---

## Regla principal de diseño

```txt
La IA interpreta.
El backend valida.
La base de datos protege.
Las tools ejecutan.
WhatsApp solo comunica.
```

Esto significa que la base debe rechazar datos incoherentes con:

- `PRIMARY KEY`
- `FOREIGN KEY`
- `UNIQUE`
- `CHECK`
- `ENUM`
- `NOT NULL`
- índices parciales

---

## Soft delete

La mayoría de entidades importantes usan:

```sql
deleted_at TIMESTAMPTZ
```

Esto permite ocultar registros sin romper historial.

Ejemplos:

- no borrar citas históricas
- no borrar conversaciones necesarias para auditoría
- no borrar workers que tienen citas pasadas
- no borrar servicios usados anteriormente

---

## Estados

Los estados nunca deben ser texto libre.

Ejemplos:

```sql
status user_status_enum
status appointment_status_enum
status conversation_status_enum
```

Esto evita errores como:

```txt
activo
Active
actve
ACTIVO
```

---

## Teléfonos

Los teléfonos se modelan con:

```txt
phone_prefix_id
phone_number
phone_e164
```

Ejemplo:

```txt
phone_prefix_id -> +502
phone_number -> 55348069
phone_e164 -> +50255348069
```

`phone_prefix_id` evita que el usuario escriba prefijos inválidos.

`phone_e164` permite buscar y comparar números fácilmente, especialmente para WhatsApp.

---

## Sucursales

Las sucursales están en:

```txt
branches
```

Una sucursal pertenece a un negocio mediante:

```txt
branches.business_id
```

No se necesita una tabla `business_branches`.

Sí existen tablas relacionales para:

```txt
worker_branches
branch_services
client_branches
```

---

## Citas

La tabla principal es:

```txt
appointments
```

Esta tabla es la fuente de verdad de Klyro.

Google Calendar o Apple Calendar son integraciones externas, no la fuente principal.

---

## Diagrama DER

El archivo:

```txt
database-der.mmd
```

contiene el diagrama Mermaid ER del modelo.

Puedes visualizarlo en:

- Mermaid Live Editor
- Markdown Preview Mermaid Support en VS Code
- documentación interna del proyecto
