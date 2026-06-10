# Bravo Credit Engine

Sistema base para gestionar solicitudes de crédito en varios países. Está hecho en Elixir/Phoenix y la idea de fondo es que agregar un país, un proveedor bancario o un estado nuevo no obligue a reescribir medio sistema.

Hoy están implementados tres países: España (ES), México (MX) y Colombia (CO). El documento pedía al menos dos; sumé Colombia porque su regla depende de datos del proveedor bancario y servía para ejercitar ese caso.

La pila: Elixir (`~> 1.15`, desarrollado sobre 1.19 / OTP 29), Phoenix + LiveView para el frontend, PostgreSQL como base de datos, Oban para las colas y Cachex para caché.

---

## Dónde está cada entregable

Para ubicar rápido cada cosa:

| Entregable | Dónde |
|---|---|
| Backend | `lib/bravo` (dominio, aplicación, infraestructura) y `lib/bravo_web` (API + web) |
| Frontend | `lib/bravo_web/live/dashboard_live.ex` (LiveView) y `lib/bravo_web/controllers/*_html` (login/registro) |
| Procesamiento asíncrono y colas | `lib/bravo/workers/` (Oban) + los triggers en `priv/repo/migrations/` |
| Caché | `Bravo.CreditRequests` (lecturas) y `Bravo.Workflow` (estados), con Cachex |
| Despliegue | `Dockerfile`, `k8s/` |
| Comandos | `Makefile` (`make help`) |

Y los contenidos que pide el README:

- Instalación y ejecución: [Cómo correrlo](#cómo-correrlo)
- Decisiones técnicas: [Decisiones técnicas](#decisiones-técnicas)
- Supuestos: [Supuestos y simplificaciones](#supuestos-y-simplificaciones)
- Modelo de datos: [Modelo de datos](#modelo-de-datos)
- Consideraciones de seguridad: [Seguridad](#seguridad-autenticación-autorización-y-pii)
- Escalabilidad y grandes volúmenes: [Escalabilidad](#escalabilidad-y-grandes-volúmenes)
- Concurrencia, colas, caché y webhooks: [Procesamiento asíncrono y colas](#procesamiento-asíncrono-colas-y-eventos-nativos-de-postgresql), [Caché](#caché) y [Webhooks](#webhooks-y-procesos-externos)

---

## Cómo correrlo

Necesitas Elixir/Erlang y Docker (para la base de datos). En menos de 5 minutos:

```bash
make db-up      # levanta PostgreSQL con docker compose (credenciales ya configuradas)
make setup      # instala dependencias y compila assets
make db-setup   # crea la BD, corre migraciones y siembra usuarios + workflow
make run        # arranca el servidor en http://localhost:4000
```

Al entrar te redirige a `/login`. Hay usuarios de demostración (los crea `make db-setup`):

- `admin` / `admin123` — puede ver, crear y **decidir** (aprobar/rechazar).
- `officer` / `officer123` — puede ver y crear.
- `viewer` / `viewer123` — solo lectura.

También puedes registrar uno nuevo en `/register` (siempre se crea con rol `viewer`).

Para los tests:

```bash
make test
```

Si ya tienes tu propio PostgreSQL en `localhost:5432`, salta `make db-up` y ajusta credenciales en `config/dev.exs` y `config/test.exs`.

Todos los comandos están en el `Makefile` (`make help`): `db-up`, `db-down`, `setup`, `db-setup`, `migrate`, `seed`, `run`, `test`, `docker-build`, `deploy`, `clean`.

---

## Arquitectura

El código sigue una arquitectura hexagonal (puertos y adaptadores). En la práctica eso significa que la lógica de negocio no sabe nada de Ecto, Phoenix ni de los proveedores externos: solo conoce interfaces, y las implementaciones concretas se inyectan por configuración. Las capas son:

- **Dominio** (`Bravo.Domain`): reglas puras, sin dependencias de infraestructura. Aquí viven la validación de documentos y las reglas de crédito por país (`Bravo.Domain.Rules`) y la lógica de la máquina de estados (`Bravo.Domain.StateMachine`).
- **Aplicación** (`Bravo.Application`): los casos de uso (`CreateCreditRequest`, `ListCreditRequests`, etc.) y los **puertos**, que son los contratos (`CreditRequestRepository`, `BankProvider`).
- **Infraestructura** (`Bravo.Infrastructure`): los **adaptadores** que implementan esos puertos: el repositorio con Ecto, los proveedores bancarios por país y el listener de eventos de PostgreSQL.
- **Web** (`BravoWeb`): controladores REST, vistas JSON, autenticación y el dashboard LiveView.

El repositorio se resuelve con `Application.compile_env`, así que en los tests se puede inyectar un mock (`Mox`) del puerto sin tocar el código de negocio. Esa es la razón principal de separar puertos de adaptadores: poder probar la lógica de forma aislada y cambiar implementaciones sin efecto dominó.

Agregar un país nuevo, por ejemplo, toca tres puntos acotados: una cláusula de regla en `Domain.Rules`, un adaptador bancario y registrarlo en la factory. Nada más.

---

## Decisiones técnicas

Un resumen de las decisiones de fondo y por qué se tomaron:

- **Elixir/Phoenix.** El problema es de concurrencia y eventos en tiempo real (workers en paralelo, notificaciones, actualización viva del frontend). El modelo de actores de la BEAM y LiveView resuelven eso sin armar un stack de varias piezas.
- **Arquitectura hexagonal.** Separar dominio de infraestructura mantiene las reglas de negocio puras y testeables, y permite intercambiar adaptadores (o mockearlos) sin tocar el negocio. El costo es algo más de ceremonia (puertos/adaptadores), que se justifica por la extensibilidad que pedía el reto.
- **PostgreSQL como centro de los eventos.** En vez de orquestar todo desde la app, la base reacciona a los cambios con triggers: encola el trabajo y emite notificaciones. Esto da consistencia transaccional (el job vive solo si la transacción se confirma) y desacopla la API del trabajo pesado.
- **Oban para las colas.** Está respaldado en la misma PostgreSQL, así que no agrega infraestructura (Redis/RabbitMQ). Toma jobs con `SKIP LOCKED`, lo que permite varios consumidores/réplicas en paralelo sin duplicar trabajo.
- **Máquina de estados en datos, no en código.** Los estados y transiciones viven en tablas. Así se pueden agregar estados o flujos por país sin desplegar, que era justo el requisito de "el diseño debe permitir agregar nuevos estados o flujos".
- **No auto-aprobar.** La evaluación automática solo es un pre-screening que rechaza fallas duras y manda el resto a revisión humana. Es más fiel a cómo funciona el crédito real y le da sentido a la decisión manual.
- **LiveView en lugar de Socket.IO.** Es la vía natural de Phoenix para tiempo real bidireccional y evita mantener un frontend separado.
- **Dos autenticaciones según el canal.** Sesión con cookie firmada para el navegador (usuarios en BD con bcrypt) y JWT para la API. Es una simplificación consciente del MVP (ver Supuestos).
- **Caché con invalidación explícita.** Cachex con borrado en cada escritura, en vez de TTLs, para no servir datos viejos cuando un worker cambia el estado de fondo.

---

## Reglas de negocio por país

Cada país valida su documento de identidad y aplica una regla de riesgo. La validación de formato del documento corre en el changeset (al crear y al actualizar); la regla de riesgo corre en segundo plano cuando se evalúa la solicitud.

- **España (ES)**: documento DNI (8 dígitos + letra de control). Toda solicitud se enruta a revisión; los montos por encima de €5.000 se consideran de "revisión adicional".
- **México (MX)**: documento CURP (18 caracteres). Si el monto solicitado supera 10 veces el ingreso mensual, se rechaza automáticamente; si no, va a revisión.
- **Colombia (CO)**: documento Cédula de Ciudadanía (6–10 dígitos). Usa la **deuda total que reporta el proveedor bancario**: si esa deuda supera 12 veces el ingreso mensual, se rechaza; si no, va a revisión.

Un detalle importante de diseño: **ninguna solicitud se aprueba sola**. La evaluación automática es un pre-screening que solo puede rechazar fallas duras (sobre-endeudamiento, documento inválido); todo lo que pasa el filtro queda en `pending_review` esperando una decisión humana. El documento permitía auto-aprobar montos chicos, pero en crédito real una aprobación instantánea al crear no tiene sentido, así que opté por el flujo más conservador. Eso, además, le da sentido a los botones de aprobar/rechazar del dashboard.

---

## Proveedores bancarios

Cada país usa un proveedor distinto para traer información del cliente, y cada proveedor devuelve datos diferentes. Eso se modela con un puerto (`Bravo.Application.Ports.BankProvider`) y un adaptador por país, elegidos en tiempo de ejecución por `Bravo.Infrastructure.BankProvider.Factory` según el país de la solicitud.

Los adaptadores están simulados (no llaman a servicios reales), pero cada uno devuelve una estructura distinta a propósito, para mostrar que la aplicación tolera esas diferencias: España expone un IBAN y una calificación crediticia, México una CLABE y un score, Colombia un número de cuenta y la deuda total. La regla de Colombia justamente consume ese `total_debt` que los otros no tienen.

---

## El ciclo de vida de una solicitud (máquina de estados)

Los estados posibles son: `submitted`, `pending_review`, `approved`, `rejected` y `disbursed`. El flujo normal es: una solicitud nueva entra como `submitted`, la evaluación automática la manda a `pending_review` o `rejected`, y desde `pending_review` un administrador la pasa a `approved` o `rejected`. En España, una solicitud `approved` puede pasar además a `disbursed` (desembolsada); en los otros países `approved` es estado final.

Lo interesante es que **la máquina de estados no está hardcodeada en el código, sino guardada en la base de datos**. Hay dos tablas: `credit_statuses` (el catálogo de estados, con su etiqueta, color y si son inicial/terminal) y `credit_status_transitions` (qué transiciones son válidas, opcionalmente por país, y cuáles son acciones manuales de un humano).

Esto quiere decir que se puede agregar un estado o un flujo nuevo **sin desplegar**: basta insertar filas (con `Bravo.Workflow.upsert_status/1` y `add_transition/1`, una pantalla de admin o SQL directo). La validación de transiciones, el filtro del dashboard, los colores, las etiquetas y los botones de acción se recalculan solos a partir de esos datos.

La lógica pura de "¿esta transición es válida para este país?" vive en `Bravo.Domain.StateMachine` (recibe la tabla de transiciones como argumento, no la consulta), y `Bravo.Workflow` es el que carga los datos de la base, los cachea (Cachex) e invalida el caché cuando algo cambia. Las transiciones por país funcionan como override: si un país define transiciones para un estado, esas reemplazan a las del flujo por defecto para ese estado.

Cada cambio de estado dispara lógica adicional, de lo cual se encarga la base de datos (ver la sección de procesamiento asíncrono).

---

## Procesamiento asíncrono, colas y eventos nativos de PostgreSQL

La pieza central es que **la propia base de datos reacciona a los cambios** mediante funciones y triggers, y desde ahí encola el trabajo pesado para que la API no se bloquee.

Cuando se inserta una solicitud, un trigger `AFTER INSERT` hace dos cosas: registra el estado inicial en la auditoría e inserta un job en la tabla `oban_jobs` para el worker de evaluación de riesgo. Que el job se cree dentro de la misma transacción que la solicitud es importante: si la transacción no se confirma, el job tampoco existe. No hay forma de quedar con una solicitud sin su trabajo encolado, ni al revés.

Quien procesa ese job es **Oban**, la librería de colas (respaldada en PostgreSQL, sin necesidad de Redis ni RabbitMQ). Hay dos colas que corren en paralelo y de forma independiente:

- `:default` (concurrencia 10), worker `Bravo.Workers.RiskEvaluator`: resuelve el proveedor bancario del país, trae la info del cliente, corre la regla de negocio y actualiza el estado.
- `:notifications` (concurrencia 5), worker `Bravo.Workers.StatusNotifier`: envía la notificación saliente (webhook) cuando cambia el estado.

Cuando el estado de una solicitud cambia, otro trigger (`AFTER UPDATE OF status`) hace tres cosas: escribe una fila de auditoría, emite un `pg_notify` para avisar al frontend, y encola un job de `StatusNotifier` en la otra cola. Así, tanto los cambios automáticos (el worker) como los manuales (un admin desde el dashboard) quedan auditados y notificados de la misma manera.

Sobre la concurrencia y el escalado: Oban toma cada job con un lock a nivel de fila (`FOR UPDATE SKIP LOCKED`), de modo que se pueden correr varias réplicas del backend al mismo tiempo sin que dos procesen el mismo job ni se generen inconsistencias. Para escalar basta con subir la concurrencia de las colas o el número de réplicas en Kubernetes; no hace falta un proceso worker aparte porque Oban corre dentro de la misma app.

---

## Actualización en tiempo real

El dashboard se actualiza casi en tiempo real cuando cambia algo, sin que el usuario recargue. La cadena es: el trigger de cambio de estado emite un `pg_notify` en un canal de PostgreSQL; un GenServer (`Bravo.Infrastructure.Events.Listener`) está suscrito a ese canal nativo, recibe el evento, lo decodifica y lo reenvía por `Phoenix.PubSub`; el LiveView está suscrito a ese tópico y actualiza la lista (y el detalle, si está abierto) al instante.

Se usa LiveView en vez de Socket.IO porque es la herramienta natural de Phoenix para comunicación bidireccional y evita escribir un frontend aparte.

---

## Webhooks y procesos externos

En cada cambio de estado el sistema envía una notificación saliente a un endpoint externo (simulado) con los datos de la transición: id, país, estado anterior, estado nuevo, monto. Lo hace el worker `StatusNotifier`, encolado por el trigger de cambio de estado, usando `Req`. El destino se configura con la variable de entorno `WEBHOOK_URL` (por defecto apunta a `https://httpbin.org/post` para que se pueda observar el envío).

La entrega queda registrada: éxito, respuesta no-2xx o error de red. Si falla por red, el worker devuelve error y Oban reintenta con backoff hasta agotar los intentos.

El documento pedía recibir un webhook **o** enviar una notificación externa; aquí se implementó la segunda opción.

---

## Seguridad: autenticación, autorización y PII

Hay dos mecanismos de autenticación, según el canal:

- **Frontend (sesión):** login y registro propios. Los usuarios viven en la tabla `users` y las contraseñas se guardan con hash bcrypt (nunca en texto plano; los campos están marcados como `redact`). La sesión guarda un resumen del usuario en una cookie firmada, y un hook de LiveView (`on_mount`) protege el dashboard y manda a `/login` si no hay sesión.
- **API REST (JWT):** los endpoints de `/api/credit_requests` exigen un token firmado (HMAC-SHA256, con `Joken`). Hay un endpoint `POST /api/auth/token` que emite tokens de demostración para poder probar con `curl`.

La autorización es por roles y vive en un solo lugar (`BravoWeb.Auth.Authorization`): `admin` puede leer, escribir y decidir; `officer` puede leer y escribir; `viewer` solo lee. Las acciones de escritura sin rol suficiente devuelven 403 en la API, y en el dashboard los botones de decisión solo aparecen para `admin` (además se valida del lado del servidor, no solo ocultando el botón). El registro público siempre crea usuarios con el rol más bajo, para que nadie se auto-asigne `admin`.

Sobre la PII: en las respuestas JSON el documento de identidad se enmascara salvo para roles privilegiados, y los números de cuenta bancaria (IBAN, CLABE, número de cuenta) se enmascaran siempre dejando solo los últimos dígitos. Los secretos de producción (`SECRET_KEY_BASE`, `DATABASE_URL`) se inyectan por variables de entorno / `Secret` de Kubernetes, no van en el código.

---

## Caché

Se usa Cachex en dos lugares. El primero es la lectura de solicitudes individuales (`get_credit_request!`), que es la operación de lectura más frecuente (el detalle y los refrescos en tiempo real). La estrategia de invalidación es simple y explícita: cualquier actualización o borrado elimina la entrada de esa solicitud del caché, así la siguiente lectura la repuebla con datos frescos. Esto mantiene la coherencia incluso cuando el estado lo cambia un worker en segundo plano.

El segundo es el workflow (estados y transiciones), que cambia muy rara vez pero se lee en cada validación. Se cachea entero y se invalida cuando se modifica un estado o una transición. En el entorno de tests el caché del workflow se desactiva por configuración para que cada test lea directo de la base sin arrastrar estado entre pruebas.

---

## Observabilidad y métricas

Los logs son estructurados e incluyen `request_id`, y los errores se manejan de forma explícita. Los flujos asíncronos (jobs, webhooks, cambios de estado) dejan rastro de inicio, resultado y fallo, así que se puede reconstruir qué pasó.

Además, cada transición de estado queda registrada en la tabla `credit_request_status_history` (la escribe un trigger), de modo que hay una bitácora completa del ciclo de vida de cada solicitud. El dashboard muestra esa línea de tiempo en el detalle.

Para métricas hay un endpoint `GET /metrics` en formato Prometheus (con `telemetry_metrics_prometheus_core`), listo para que lo scrapee Prometheus y se grafique en Grafana. Las métricas que expone, construidas sobre eventos de `:telemetry`, son: latencia de HTTP, solicitudes creadas y actualizadas, throughput y latencia de las colas de Oban (por cola y worker) y entregas de webhook por resultado. Las definiciones están en `BravoWeb.Telemetry.prometheus_metrics/0`. En desarrollo también está el LiveDashboard de Phoenix en `/dev/dashboard`.

```bash
curl -s http://localhost:4000/metrics | grep bravo_
```

En un cluster real el endpoint `/metrics` se protegería por red o autenticación; aquí está abierto para facilitar la evaluación.

---

## Escalabilidad y grandes volúmenes

El diseño asume que la tabla de solicitudes puede crecer a millones de filas. No es necesario crear esos datos para la evaluación, pero el diseño los considera.

**Índices.** Ya están creados en una migración y cubren los accesos frecuentes: filtrado combinado por país y estado, listado cronológico y por rango de fechas, y búsqueda por documento.

**Particionamiento.** Para volúmenes grandes usaría particionamiento declarativo por rango sobre `request_date` (particiones mensuales o trimestrales). La ventaja es doble: los índices locales son más chicos y caben en memoria, manteniendo las inserciones rápidas; y archivar o borrar datos viejos se reduce a un `DROP` de la partición, evitando borrados masivos que saturan el WAL.

**Consultas críticas.** El listado paginado se apoya en el índice de país/estado y conviene paginar por keyset (no `OFFSET`) para que las páginas profundas no se degraden. La cola usa `SKIP LOCKED`, así que varios consumidores no se pelean por los mismos jobs.

**Archivado.** Las solicitudes en estado final con cierta antigüedad se podrían mover a almacenamiento frío o a una base analítica columnar, dejando la base transaccional liviana. La columna `bank_info` es JSONB y se beneficia de la compresión nativa de Postgres.

---

## Despliegue (Kubernetes)

En `k8s/` están los manifiestos: el `Deployment` de la app (con un `initContainer` que corre las migraciones antes de levantar el servidor), su `Service` e `Ingress`; el `Deployment` de PostgreSQL con su volumen; y un `Secret` con la URL de base de datos y la secret key base. La imagen se construye con el `Dockerfile` multi-stage, que arma un release de OTP auto-contenido.

Las migraciones corren desde el `initContainer` con `bin/migrate`; como todas las réplicas lo intentan, el lock de migraciones de Ecto garantiza que solo una las aplique y las demás esperen. No se usa Helm ni Kustomize: son manifiestos YAML planos que se aplican con `kubectl apply -f k8s/` (o `make deploy`). No hace falta un cluster real para la evaluación; lo importante es que la configuración está y es coherente.

```bash
make docker-build   # construye la imagen
make deploy         # kubectl apply -f k8s/
```

---

## Modelo de datos

La tabla principal es `credit_requests`:

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | clave primaria |
| `country` | string | `ES`, `MX`, `CO` |
| `full_name` | string | PII |
| `identity_document` | string | PII, enmascarado en la API según rol |
| `requested_amount` | decimal | monto solicitado |
| `monthly_income` | decimal | ingreso mensual |
| `request_date` | timestamptz | fecha de solicitud |
| `status` | string | estado del flujo |
| `bank_info` | jsonb | datos del proveedor; se completan en segundo plano |

Tablas de apoyo:

- `users` — usuarios del login (con `hashed_password` bcrypt y `role`).
- `credit_statuses` y `credit_status_transitions` — la máquina de estados configurable.
- `credit_request_status_history` — la auditoría de transiciones (la escriben triggers).
- `oban_jobs` — la cola de trabajos.

---

## Supuestos y simplificaciones

- La autenticación está pensada para el alcance del MVP: el frontend usa la tabla `users` con bcrypt; la API usa JWT con un endpoint que emite tokens libremente para facilitar las pruebas. En un sistema real ambos compartirían el mismo store de usuarios.
- Los proveedores bancarios están simulados; devuelven datos representativos en lugar de llamar a servicios externos.
- Se eligió enviar webhooks (no recibirlos), que era una de las dos opciones del documento.
- Están implementados ES, MX y CO. Agregar PT, IT o BR sería repetir el patrón (regla + adaptador + factory).
- El caché del workflow se invalida por instancia. Con varias réplicas, un cambio de estado se vería en las demás al expirar o reiniciar su caché; para invalidación inmediata multi-nodo se podría disparar la invalidación por `pg_notify`/PubSub. No se hizo por estar fuera del alcance.

---

## Probar la API REST

Primero, obtener un token (indicando el rol que quieras):

```bash
curl -X POST http://localhost:4000/api/auth/token \
  -H "Content-Type: application/json" \
  -d '{"user_id": "evaluador", "role": "admin"}'
```

Listar solicitudes, con filtros (`country`, `status`, `start_date`, `end_date`) y paginación (`page`, `page_size`):

```bash
curl -X GET "http://localhost:4000/api/credit_requests?country=ES&page=1&page_size=6" \
  -H "Authorization: Bearer <TU_TOKEN>" \
  -H "Accept: application/json"
```

La respuesta incluye `data` y un objeto `meta` con `page`, `page_size`, `total` y `total_pages`. El listado del dashboard usa la misma paginación (6 por página, con controles Anterior/Siguiente).

Crear una solicitud (requiere rol `admin` u `officer`; con `viewer` devuelve 403):

```bash
curl -X POST http://localhost:4000/api/credit_requests \
  -H "Authorization: Bearer <TU_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "credit_request": {
      "country": "MX",
      "full_name": "Sofía García",
      "identity_document": "GARS900101HMNDFS01",
      "requested_amount": "12000.00",
      "monthly_income": "2500.00"
    }
  }'
```

Al crearse, el trigger encola la evaluación de riesgo en segundo plano de inmediato. La solicitud quedará en `pending_review` (o `rejected` si falla una regla dura), lista para que un administrador la apruebe o rechace.
