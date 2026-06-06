# Database Seeds

Esta carpeta contiene datos base que Klyro necesita para funcionar.

Los seeds no son datos demo de una barbería o negocio específico. Son datos del sistema.

---

## Orden recomendado

```txt
001-seed-general-catalogs.sql
002-seed-security.sql
003-seed-operational-types.sql
004-seed-message-templates.sql
005-seed-plans.sql
006-seed-ai-model-catalog.sql   (corre DESPUÉS de las migraciones)
```

> **Excepción de orden:** `006-seed-ai-model-catalog.sql` depende de la tabla
> `ai_model_catalog` y del enum `ai_provider_enum` que crea la migración
> `2026-06-05-ai-provider-model-and-catalog.sql`. Por eso en `docker-compose.yml`
> se monta con un número (`028-...`) **posterior** al de las migraciones, para que
> en una base nueva se ejecute después de ellas. En una base existente, aplícalo
> manualmente con `psql` (igual que una migración).

---

## 001-seed-general-catalogs.sql

Inserta catálogos generales:

- monedas
- países
- prefijos telefónicos
- idiomas
- tipos de negocio
- proveedores de pago

Ejemplos:

```txt
GTQ
USD
Guatemala
United States
+502
+1
es
en
barbershop
salon
tutoring
lemonsqueezy
```

Estos datos son necesarios para evitar que el usuario escriba manualmente valores como:

```txt
Gua
Guatemalaaa
502
+502
Dolares
```

---

## 002-seed-security.sql

Inserta roles y permisos base.

Roles iniciales:

```txt
owner
worker
```

Permisos siguen el patrón:

```txt
resource.action
```

Ejemplos:

```txt
workers.create
workers.read
workers.update
appointments.cancel
conversations.handoff
billing.read
```

El rol `owner` recibe todos los permisos.

El rol `worker` recibe permisos limitados para operación diaria.

---

## 003-seed-operational-types.sql

Inserta tipos operativos necesarios para disponibilidad y notificaciones.

Incluye tipos como:

```txt
closed_day
custom_hours
vacation
sick_leave
break
emergency
manual_block
external_calendar_busy
```

También incluye tipos de notificaciones como:

```txt
appointment_created
appointment_cancelled
handoff_needed
calendar_sync_failed
usage_limit_warning
```

---

## 004-seed-message-templates.sql

Inserta templates globales internos.

Solo en **inglés** (fuente de verdad). Las traducciones a otros idiomas las
genera la IA bajo demanda y se cachean en `message_template_translations`.

Tipos de template:

```txt
welcome
confirmation
reminder
cancellation
reschedule
handoff
```

Estos templates son globales. Más adelante un negocio puede crear sus propios templates personalizados.

---

## 006-seed-ai-model-catalog.sql

Inserta el catálogo de modelos de IA (precios informativos en USD por 1K tokens)
usado por el selector de modelo y la estimación de costo:

```txt
openai · gpt-5
openai · gpt-5-mini
google · gemini-2.5-flash
```

Depende del schema creado por la migración de provider/model, por lo que se
ejecuta después de las migraciones (ver "Excepción de orden" arriba).

---

## 005-seed-plans.sql

Inserta planes base:

```txt
free
pro
max
```

Aunque Lemon Squeezy maneje el cobro, Klyro necesita tener los planes localmente para saber:

- límite de workers
- límite de sucursales
- límite de conversaciones
- límite de mensajes IA
- límite de tokens
- features habilitadas

---

## Idempotencia

Los seeds están diseñados para poder correrse más de una vez sin duplicar datos.

Se usan patrones como:

```sql
ON CONFLICT DO UPDATE
ON CONFLICT DO NOTHING
WHERE NOT EXISTS
```

---

## Qué NO debe ir en estos seeds

No deben ir datos demo de negocios específicos.

Ejemplos de datos que NO van aquí:

```txt
Barbería Santos
Chepe
Carlos Méndez
Corte Q60
Barba Q40
```

Eso debe ir en un seed separado, por ejemplo:

```txt
100-seed-demo-barbershop.sql
```

---

## Recomendación

Mantén los seeds base separados de los seeds demo.

```txt
seeds/
├── 001-seed-general-catalogs.sql
├── 002-seed-security.sql
├── 003-seed-operational-types.sql
├── 004-seed-message-templates.sql
├── 005-seed-plans.sql
└── demo/
    └── 100-seed-demo-barbershop.sql
```
