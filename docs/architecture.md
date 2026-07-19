# Arquitectura y Requerimientos: Micro-ERP Financiero

> **Versión del documento:** 1.1 · **Última actualización:** 2026-07-19

Este documento detalla la arquitectura del sistema y los requerimientos funcionales para el gestor financiero colaborativo. El diseño prioriza una infraestructura de costo cero, alta disponibilidad mediante contenedores y procesamiento de lenguaje natural (NLP) integrado.

---

## 1. Arquitectura del Sistema

El sistema sigue una arquitectura cliente-servidor desacoplada, con comunicación segura mediante **JWT Auth** y un diseño preparado para Web, iOS y Android.

```
┌─────────────────────────────────────────────────┐
│                 Clientes                         │
│   Web (PWA)    iOS    Android                    │
└──────────────────┬──────────────────────────────┘
                   │  HTTPS + JWT
                   ▼
┌─────────────────────────────────────────────────┐
│          Vercel CDN (Frontend)                   │
│   Renderizado SPA · Service Worker (offline)     │
└──────────────────┬──────────────────────────────┘
                   │  HTTPS + JWT
                   ▼
┌─────────────────────────────────────────────────┐
│     Oracle Cloud — Instancia Always Free         │
│  ┌───────────────────────────────────────────┐  │
│  │        Docker Containers                  │  │
│  │  ┌─────────┐ ┌──────────┐ ┌───────────┐  │  │
│  │  │  API    │ │  Cron    │ │   NLP     │  │  │
│  │  │ (NestJS)│ │ (sync    │ │ (Gemini   │  │  │
│  │  │         │ │  rates)  │ │  proxy)   │  │  │
│  │  └────┬────┘ └──────────┘ └───────────┘  │  │
│  └───────┼───────────────────────────────────┘  │
└──────────┼──────────────────────────────────────┘
           │
           ▼
┌──────────────────────┐    ┌──────────────────────┐
│   Oracle Database    │    │  Google Gemini API   │
│   (Always Free)      │    │  (NLP externo)       │
└──────────────────────┘    └──────────────────────┘
```

### Capa de Presentación (Frontend)

| Componente | Detalle |
|------------|---------|
| **Clientes** | Web (PWA), iOS, Android |
| **Framework** | Por definir (React / React Native / Flutter) |
| **Hosting** | Vercel (CDN gratuito, despliegue automático desde Git) |
| **Distribución** | PWA instalable en Web; App Store / Google Play para nativas |
| **Offline** | Service Worker con caché de recursos; IndexedDB para datos locales; cola de operaciones pendientes con sincronización al recuperar conexión |
| **Estado** | UI optimista: la operación se refleja inmediato en pantalla y se confirma contra backend en segundo plano |

### Capa de Lógica y Negocio (Backend)

| Componente | Detalle |
|------------|---------|
| **Infraestructura** | Oracle Cloud (Instancia Always Free — ARM Ampere A1, 4 OCPU, 24 GB RAM) |
| **SO** | Oracle Linux 8 |
| **Runtime** | Docker Engine 24+ · Docker Compose v2 |
| **Framework API** | NestJS (Node.js 20 LTS) — por confirmar |
| **Autenticación** | JWT (access + refresh tokens) |
| **Contenedores** | API principal, cron de sincronización de tasas, proxy NLP |

#### Flujo de Autenticación JWT

1. El cliente envía credenciales a `POST /auth/login`.
2. El backend valida y responde con:
   - `accessToken` (corto: 15 min) — firmado con `HS256`, contenido: `{ sub, role, iat, exp }`.
   - `refreshToken` (largo: 7 días) — almacenado en DB, permitido un solo uso (rotación).
3. El cliente incluye `Authorization: Bearer <accessToken>` en cada petición.
4. Al expirar el access token, el cliente llama a `POST /auth/refresh` con el refresh token.
5. El backend invalida el refresh token anterior y emite un nuevo par.

### Capa de Datos y Servicios Externos

| Componente | Detalle |
|------------|---------|
| **Base de Datos** | Oracle Database 21c XE (Always Free, hasta 20 GB) |
| **NLP / IA** | Google Gemini API (modelo gemini-2.0-flash) |
| **Tasas de Cambio** | API gratuita: [exchangerate-api.com](https://www.exchangerate-api.com) (o similar, por definir) |

---

## 2. Stack Tecnológico — Versiones

| Capa | Tecnología | Versión / Imagen |
|------|-----------|-------------------|
| Frontend Web | Por definir (React / Next.js) | — |
| Móvil | Por definir (React Native / Flutter) | — |
| Backend | NestJS | 10.x |
| Runtime Backend | Node.js | 20 LTS |
| Contenedores | Docker + Compose | 24+ / v2 |
| SO Servidor | Oracle Linux | 8 |
| Base de Datos | Oracle Database XE | 21c |
| IA / NLP | Google Gemini API | gemini-2.0-flash |
| Tasas de Cambio | ExchangeRate-API | v6 |
| Cache / Colas | Redis (por definir) | 7.x |
| Proxy inverso | Nginx (dentro de Docker) | 1.25+ |

> **Nota:** Las tecnologías marcadas como "Por definir" se decidirán al iniciar la implementación, basándose en this investigación adicional.

---

## 3. Modelo de Datos

### Entidades Principales

```
Usuarios
  ├── id (PK)
  ├── email (UNIQUE)
  ├── password_hash
  ├── nombre
  ├── rol: 'admin' | 'promotor'
  ├── moneda_base: VARCHAR(3) DEFAULT 'PEN'
  └── created_at

Categorías
  ├── id (PK)
  ├── nombre
  ├── tipo: 'ingreso' | 'gasto'
  ├── usuario_id (FK -> Usuarios, nullable = categorías globales)
  └── activa: BOOLEAN

Transacciones (ingresos/gastos)
  ├── id (PK)
  ├── usuario_id (FK -> Usuarios)
  ├── categoria_id (FK -> Categorías)
  ├── tipo: 'ingreso' | 'gasto'
  ├── monto: NUMBER(12,2)
  ├── moneda: VARCHAR(3)
  ├── descripcion: TEXT
  ├── fecha: DATE
  ├── origen_nlp: BOOLEAN (si fue creada por NLP)
  ├── raw_nlp: TEXT (texto original del NLP)
  ├── contrapartida_id (FK -> Transacciones, para partida doble)
  └── created_at

Presupuestos
  ├── id (PK)
  ├── usuario_id (FK -> Usuarios)
  ├── categoria_id (FK -> Categorías)
  ├── limite: NUMBER(12,2)
  ├── periodo: 'mensual' | 'anual'
  ├── mes YEAR_MONTH
  └── created_at

Préstamos
  ├── id (PK)
  ├── usuario_id (FK -> Usuarios, administrador)
  ├── promotor_id (FK -> Usuarios, nullable)
  ├── deudor: VARCHAR
  ├── monto_original: NUMBER(12,2)
  ├── moneda: VARCHAR(3)
  ├── interes: DECIMAL(5,2) (tasa periódica)
  ├── frecuencia_pago: 'diario' | 'semanal' | 'quincenal' | 'mensual'
  ├── cuotas_totales: INT
  ├── cuotas_restantes: INT
  ├── saldo_pendiente: NUMBER(12,2)
  ├── fecha_inicio: DATE
  ├── fecha_proximo_pago: DATE
  ├── estado: 'activo' | 'pagado' | 'castigado'
  ├── penalidad_diaria: DECIMAL(5,2) (% de mora por día)
  └── created_at

Pagos (Préstamos)
  ├── id (PK)
  ├── prestamo_id (FK -> Préstamos)
  ├── monto: NUMBER(12,2)
  ├── monto_interes: NUMBER(12,2)
  ├── monto_capital: NUMBER(12,2)
  ├── moneda: VARCHAR(3)
  ├── fecha_pago: DATE
  ├── nro_cuota: INT
  └── created_at

Comisiones (Promotor)
  ├── id (PK)
  ├── promotor_id (FK -> Usuarios)
  ├── prestamo_id (FK -> Préstamos)
  ├── pago_id (FK -> Pagos)
  ├── tasa_comision: DECIMAL(5,2)
  ├── monto_comision: NUMBER(12,2)
  ├── moneda: VARCHAR(3)
  ├── pagada: BOOLEAN DEFAULT FALSE
  └── created_at

Tasas_Cambio
  ├── id (PK)
  ├── moneda_origen: VARCHAR(3)
  ├── moneda_destino: VARCHAR(3)
  ├── tasa: NUMBER(12,6)
  ├── fuente: VARCHAR
  └── fecha: DATE (UNIQUE por par + fecha)

Configuraciones
  ├── id (PK)
  ├── usuario_id (FK -> Usuarios, UNIQUE)
  ├── moneda_base: VARCHAR(3) DEFAULT 'PEN'
  ├── tasa_comision_promotor: DECIMAL(5,2)
  ├── notificaciones: BOOLEAN
  └── updated_at
```

### Modelo Contable (Partida Doble Oculta)

Cada transacción de ingreso o gasto genera automáticamente dos asientos:

```
Ejemplo: Gasto de S/ 50 en "Alimentación"

  Cuenta                     Debe      Haber
  ───────────────────────    ─────     ──────
  Gasto: Alimentación        50
  Patrimonio Neto                      50

Ejemplo: Ingreso de S/ 2000 "Sueldo"

  Cuenta                     Debe      Haber
  ───────────────────────    ─────     ──────
  Patrimonio Neto            2000
  Ingreso: Sueldo                      2000
```

El usuario solo ve una línea simple ("Gasté S/ 50 en Alimentación"). El backend crea la contrapartida en una tabla `asientos_contables` oculta, que permite generar reportes contables reales sin exponer complejidad al usuario.

---

## 4. API Endpoints (Vista General)

| Método | Ruta | Acceso | Descripción |
|--------|------|--------|-------------|
| `POST` | `/auth/login` | Público | Iniciar sesión |
| `POST` | `/auth/refresh` | Público | Renovar access token |
| `POST` | `/auth/register` | Admin | Crear usuario (promotor) |
| `GET` | `/users` | Admin | Listar usuarios |
| `GET` | `/users/:id` | Admin | Ver usuario |
| `GET` | `/transactions` | Admin | Listar transacciones |
| `POST` | `/transactions` | Admin | Crear transacción |
| `GET` | `/transactions/:id` | Admin | Ver transacción |
| `PUT` | `/transactions/:id` | Admin | Actualizar transacción |
| `DELETE` | `/transactions/:id` | Admin | Eliminar transacción |
| `GET` | `/categories` | Ambos | Listar categorías |
| `POST` | `/categories` | Admin | Crear categoría |
| `GET` | `/budgets` | Admin | Listar presupuestos |
| `POST` | `/budgets` | Admin | Crear/actualizar presupuesto |
| `GET` | `/loans` | Ambos | Listar préstamos (Admin: todos; Promotor: su cartera) |
| `POST` | `/loans` | Ambos | Registrar préstamo |
| `GET` | `/loans/:id` | Ambos | Ver detalle de préstamo |
| `POST` | `/loans/:id/payments` | Ambos | Registrar pago |
| `GET` | `/commissions` | Promotor | Ver comisiones propias |
| `GET` | `/commissions` | Admin | Ver todas las comisiones |
| `GET` | `/dashboard/summary` | Admin | Resumen de flujo de caja |
| `GET` | `/dashboard/projections` | Admin | Proyecciones financieras |
| `GET` | `/dashboard/portfolio` | Promotor | Rendimiento de cartera |
| `POST` | `/nlp/parse` | Ambos | Enviar texto para análisis NLP |
| `GET` | `/exchange-rates` | Ambos | Obtener tasas vigentes |
| `GET` | `/settings` | Admin | Obtener configuración |
| `PUT` | `/settings` | Admin | Actualizar configuración |

---

## 5. Actores y Permisos

| Recurso | Admin (`Yo`) | Promotor (Broker) |
|---------|:------------:|:-----------------:|
| Transacciones (ingresos/gastos) | CRUD completo | ❌ |
| Categorías | CRUD completo | Solo lectura |
| Presupuestos | CRUD completo | ❌ |
| Préstamos — todos | CRUD completo | ❌ |
| Préstamos — cartera propia | CRUD completo | CRUD completo |
| Pagos de préstamos — cartera propia | CRUD completo | Solo registrar |
| Comisiones propias | Lectura | Lectura |
| Comisiones de terceros | Lectura | ❌ |
| Configuración del sistema | CRUD completo | ❌ |
| Usuarios (promotores) | CRUD completo | ❌ |
| NLP | Uso completo | Uso completo |
| Dashboard global | Lectura | ❌ |
| Dashboard cartera propia | Lectura | Lectura |

### Reglas de Negocio por Rol

- **Admin:** Puede registrar préstamos en cualquier cartera (asignando un promotor o quedándoselo como propio).
- **Promotor:** Solo puede registrar préstamos bajo su propio `promotor_id` y ver los suyos.
- **Comisión:** Se calcula automáticamente al registrar cada pago basado en la `tasa_comision_promotor` de la configuración global.

---

## 6. Requerimientos Funcionales

### 6.1. Procesamiento de Lenguaje Natural (NLP)

Flujo completo de una interacción NLP:

```
Usuario: "Gasté 50 soles en almuerzo hoy"
   │
   ▼
[1] Frontend → POST /nlp/parse
   │  Body: { text: "Gasté 50 soles en almuerzo hoy" }
   │
   ▼
[2] Backend → Google Gemini API
   │  Prompt:
   │    "Clasifica el siguiente texto financiero.
   │     Responde SOLO con JSON:
   │     {
   │       tipo: 'gasto' | 'ingreso' | 'prestamo' | 'pago_prestamo' | 'no_clasificado',
   │       monto: number | null,
   │       moneda: 'PEN' | 'USD' | ... | null,
   │       descripcion: string,
   │       categoria_sugerida: string | null,
   │       fecha: 'YYYY-MM-DD' | null,
   │       deudor: string | null (solo si es préstamo),
   │       confianza: 0.0-1.0
   │     }
   │     Texto: 'Gasté 50 soles en almuerzo hoy'"
   │
   ▼
[3] Gemini → JSON response
   │  {
   │    tipo: 'gasto',
   │    monto: 50,
   │    moneda: 'PEN',
   │    descripcion: 'Almuerzo',
   │    categoria_sugerida: 'Alimentación',
   │    fecha: '2026-07-19',
   │    confianza: 0.95
   │  }
   │
   ▼
[4] Backend devuelve JSON al frontend
   │
   ▼
[5] Frontend muestra vista previa:
   │  ┌──────────────────────────────────┐
   │  │  Gasto                           │
   │  │  S/ 50.00 — Almuerzo             │
   │  │  Categoría: Alimentación         │
   │  │  Fecha: 19/07/2026               │
   │  │  ┌──────┐ ┌──────┐              │
   │  │  │Editar│ │Confirmar│            │
   │  │  └──────┘ └──────┘              │
   │  └──────────────────────────────────┘
   │
   ▼
[6] Usuario confirma → POST /transactions
   │  Crea transacción + asiento contable oculto
   │
   ▼
[7] Transacción registrada + UI actualiza dashboard
```

### 6.2. Gestión de Préstamos

#### Cálculo de Cuota (Sistema de Amortización)

Fórmula de cuota fija (sistema francés):

```
Cuota = (Monto * i * (1 + i)^n) / ((1 + i)^n - 1)

Donde:
  i = tasa de interés periódica (decimal)
  n = número total de cuotas

Ejemplo:
  Préstamo: S/ 1000
  Interés: 5% mensual
  Plazo: 4 cuotas
  Cuota = (1000 * 0.05 * 1.05^4) / (1.05^4 - 1) = S/ 282.01
```

#### Recálculo por Pago Adelantado o Atrasado

- **Pago exacto:** Se marca la cuota como pagada, se reduce `saldo_pendiente` y `cuotas_restantes`.
- **Pago parcial:** Se aplica primero a intereses acumulados, luego a capital. Las cuotas restantes se recalculan automáticamente.
- **Pago atrasado:** Se aplica penalidad diaria (`penalidad_diaria` % sobre el saldo de la cuota vencida por día de retraso) antes de aplicar el pago.
- **Pago adelantado (extra):** Reduce capital directamente; el sistema recalcula las cuotas restantes (menor monto o menor plazo, según preferencia del admin).

#### Comisión del Promotor

```
Comisión = (Monto del pago) * (tasa_comision_promotor / 100)
```

- Se calcula automáticamente al registrar cada pago.
- La comisión se acumula en la tabla `Comisiones` con estado `pagada: FALSE`.
- El dashboard del promotor muestra el total de comisiones pendientes y pagadas.
- El admin puede marcar comisiones como pagadas desde configuración.

### 6.3. Finanzas Personales

#### Registro de Ingresos y Gastos

- Clasificación bajo categorías personalizadas creadas por el usuario.
- Soporte multimoneda por transacción.
- Cada transacción puede crearse manualmente o mediante NLP.
- Las transacciones creadas por NLP almacenan el texto original (`raw_nlp`) para auditoría y reentrenamiento.

#### Presupuestos

- Límite mensual o anual por categoría.
- Al alcanzar el 80% del límite, el sistema muestra una advertencia.
- Al superar el límite, el sistema lo notifica pero no bloquea (solo informativo).
- El dashboard de presupuestos compara gasto real vs. presupuestado en tiempo real.

#### Contabilidad de Partida Doble Oculta

- Cada transacción visible genera automáticamente un asiento contable en la tabla `asientos_contables`.
- El usuario nunca interactúa con esta tabla.
- El admin puede acceder a un reporte contable avanzado (balance general, estado de resultados) generado desde los asientos ocultos.
- Esto permite proyecciones financieras precisas basadas en principios contables reales.

### 6.4. Inteligencia de Negocios / Dashboards

#### Dashboard Administrador

| Componente | Descripción |
|------------|-------------|
| **Flujo de Caja** | Ingresos vs. Gastos del mes actual, con comparativa mensual (gráfico de barras) |
| **Proyecciones** | Tendencia de 3, 6 y 12 meses basada en datos históricos e ingresos recurrentes |
| **Presupuestos** | Barra de progreso por categoría (gastado vs. presupuestado) |
| **Cartera de Préstamos** | Total prestado, saldo pendiente, intereses generados, morosidad |
| **Distribución** | Gráfico circular de gastos por categoría |
| **Patrimonio Neto** | Evolución del patrimonio en el tiempo (línea de tendencia) |

#### Dashboard Promotor

| Componente | Descripción |
|------------|-------------|
| **Mi Cartera** | Lista de préstamos gestionados con estado, saldo y próximos pagos |
| **Comisiones** | Comisiones generadas (pendientes y pagadas) del mes y acumuladas |
| **Rendimiento** | Tasa de cobranza (pagos a tiempo vs. atrasados) |

### 6.5. Soporte Multimoneda

1. **Detección NLP:** El modelo de IA extrae automáticamente la divisa del texto (ej. "dólares", "soles", "euros"). Si no se especifica, asume la moneda base del usuario.
2. **Registro Histórico de Tasas:** La base de datos almacena el tipo de cambio exacto en el momento de la transacción en `Tasas_Cambio`. Un pago de $100 hoy no vale lo mismo contablemente que hace un año.
3. **Sincronización de Tipos de Cambio:** El backend ejecuta un cron job diario (06:00 UTC) que consulta [ExchangeRate-API](https://www.exchangerate-api.com) y almacena las tasas en `Tasas_Cambio`.
4. **Dashboard Unificado:**
   - Muestra los saldos individuales de cada cuenta en su moneda original (ej. "Ahorros: $500", "Efectivo: S/ 200").
   - Consolida el flujo de caja global convirtiendo todo a la moneda base del usuario usando la tasa histórica más cercana a la fecha de la transacción.
   - Cálculo del patrimonio neto en moneda base con conversión en tiempo real.

---

## 7. Requerimientos No Funcionales

### 7.1. Rendimiento

| Métrica | Objetivo |
|---------|----------|
| Tiempo de respuesta API (p95) | < 500 ms (operaciones CRUD) · < 2 s (NLP) |
| Tiempo de carga inicial (PWA) | < 3 s en 4G |
| Sincronización offline | < 5 s al recuperar conexión |
| Consultas a DB | < 100 ms (índices en columnas de búsqueda frecuente: fecha, usuario_id, moneda) |

### 7.2. Seguridad

| Aspecto | Medida |
|---------|--------|
| Transporte | HTTPS obligatorio (TLS 1.3) |
| Almacenamiento de contraseñas | bcrypt (cost factor 12) |
| JWT | Firma HS256; access token 15 min, refresh token 7 días con rotación |
| Headers de seguridad | Helmet (CSP, X-Frame-Options, HSTS) |
| Rate limiting | 100 req/min por IP (público) · 500 req/min por usuario (autenticado) |
| Validación | Class-validator (NestJS) en todos los DTOs |
| SQL Injection | Prevenido por ORM (TypeORM / Prisma) |
| CORS | Solo orígenes permitidos (Vercel domain) |
| Logs | Sin datos sensibles (no passwords, no tokens completos) |

### 7.3. Disponibilidad

| Componente | SLA esperado |
|------------|-------------|
| API Backend | 99.5% (Oracle Cloud Always Free) |
| Frontend | 99.9% (Vercel CDN) |
| Base de Datos | 99.5% (Oracle Cloud) |
| Tolerancia a fallos | El frontend opera offline sin depender del backend |
| Backup | Respaldos diarios de la DB mediante script cron + Oracle Cloud Object Storage |

### 7.4. Escalabilidad

- La instancia Always Free actual soporta ~100 usuarios concurrentes.
- Si se requiere escalar, el backend está diseñado para ser stateless (sesiones en JWT, no en servidor) y horizontalmente escalable añadiendo más contenedores detrás de un load balancer.
- La DB Oracle XE 21c soporta hasta 20 GB y puede migrarse a Oracle ATP (Autonomous Transaction Processing) sin cambios en el esquema.

---

## 8. Estrategia de Sincronización Offline

### Flujo de Operación Offline

1. El Service Worker intercepta peticiones fetch y sirve desde la caché (estrategia stale-while-revalidate para recursos estáticos).
2. Las operaciones de escritura (crear transacción, registrar pago) se almacenan en una **cola de operaciones** en IndexedDB.
3. Cada operación en cola contiene: `{ id, endpoint, method, body, timestamp, intentos }`.
4. Al recuperar conexión, la cola se procesa en orden FIFO:
   - Si una operación falla (ej. conflicto), se reintenta hasta 3 veces.
   - Si persiste el error, se notifica al usuario y se marca como "pendiente de revisión".
5. La UI opera en **modo optimista**: la operación se refleja inmediatamente en pantalla sin esperar confirmación del servidor.

### Conflicto de Datos

- Cada entidad tiene un campo `updated_at` y un `version` (entero incremental).
- Al sincronizar, si `version` del cliente es menor que la del servidor, se resuelve con "last-write-wins" (la operación más reciente gana) y se notifica al usuario si sus datos fueron sobrescritos.

---

## 9. Seguridad Adicional

- **Variables de entorno:** Todas las credenciales (DB, Gemini API, JWT secret) se inyectan como variables de entorno en el contenedor Docker, nunca en el código fuente.
- **Principio de mínimo privilegio:** El usuario de la DB solo tiene permisos CRUD sobre las tablas de su esquema; no tiene acceso a tablas del sistema Oracle.
- **Auditoría:** Tabla `log_auditoria` que registra: `{ usuario_id, accion, entidad, entidad_id, detalle, timestamp }`. Toda operación de escritura (POST, PUT, DELETE) queda registrada.
- **Cifrado en reposo:** Oracle Cloud cifra los datos almacenados por defecto (transparent data encryption).

---

## 10. Diagramas (Referencia)

Para una representación visual de la arquitectura, consultar:

- `docs/diagrams/architecture-overview.puml` — Diagrama C4 de contexto y contenedores (PlantUML)
- `docs/diagrams/entity-model.puml` — Diagrama entidad-relación

> **Nota:** Los diagramas se crearán durante la fase de diseño detallado previa a la implementación.

---

## 11. Glosario

| Término | Definición |
|---------|------------|
| **PWA** | Progressive Web App — aplicación web instalable con capacidades nativas (offline, notificaciones) |
| **NLP** | Procesamiento de Lenguaje Natural — técnica de IA para interpretar texto humano |
| **JWT** | JSON Web Token — estándar de token de acceso autenticado |
| **Partida Doble** | Principio contable donde cada transacción afecta al menos dos cuentas (debe y haber) |
| **Cron Job** | Tarea programada que se ejecuta en intervalos definidos |
| **Sistema Francés** | Método de amortización de préstamos con cuotas fijas |
| **Moneda Base** | Divisa principal del usuario contra la que se convierten todas las demás |
