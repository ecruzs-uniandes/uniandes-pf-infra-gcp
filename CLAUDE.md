# CLAUDE.md — TravelHub Infra GCP (Grupo 9)

## Repositorio principal de infraestructura

**Repo:** `ecruzs-uniandes/uniandes-pf-infra-gcp`
Infraestructura GCP para TravelHub (MISW4501/4502 — Grupo 9). Defensa en profundidad: Cloud Armor > VPC Firewall > API Gateway JWT > Chain of Responsibility.

## Proyectos GCP

| Ambiente | Project ID | Project Number | Estado |
|---|---|---|---|
| **DEV** | `gen-lang-client-0930444414` | `154299161799` | Activo — recursos legacy sin prefijo `dev-` |
| **PROD** | `travelhub-prod-492116` | `974898737307` | Activo |

> Los recursos del proyecto DEV tienen naming legacy (sin prefijo `dev-travelhub-`): `travelhub-vpc`, `travelhub-db`, `travelhub-security-policy`, etc. Es el estado permanente — no se va a migrar.

## Variables de entorno

```bash
GCP_PROJECT_ID="${GCP_PROJECT_ID:-gen-lang-client-0930444414}"
GCP_REGION="${GCP_REGION:-us-central1}"
```

Archivos de configuración en `config/environments/`:
- `dev.env` — apunta a `gen-lang-client-0930444414`
- `prod.env` — apunta a `travelhub-prod-492116`

## Herramienta de IaC

- **gcloud CLI** (scripts bash en `scripts/` y `deploy/`). `set -euo pipefail` en todos.
- **Terraform** (`cloud-run-services-cicd-pipeline/`) — pipeline CI/CD de Cloud Run para servicios del equipo.

## Estructura del repositorio

```
uniandes-pf-infra-gcp/
├── CLAUDE.md                              ← este archivo
├── INFRA_STATUS.md                        ← estado actual de cada componente
├── INSTRUCTIONS_API_Gateway_JWT_Hibrido_GCP.md
├── CLAUDE_CODE_infra_rebuild.md
├── deploy-all.sh                          ← despliega toda la infra (source dev.env primero)
├── destroy-all.sh                         ← destruye todo (¡cuidado!)
├── status.sh                              ← muestra estado de recursos GCP
├── scripts/                               ← scripts numerados (01..10), ejecutar en orden
│   ├── 01-enable-apis.sh
│   ├── 02-vpc-setup.sh
│   ├── 03-firewall-rules.sh
│   ├── 04-private-access.sh
│   ├── 05-cloud-armor.sh
│   ├── 06-database.sh
│   ├── 06b-database-replica.sh            ← cross-region DR replica (solo PROD)
│   ├── 07-kafka.sh
│   ├── 08-gateway.sh
│   ├── 09-load-balancer.sh
│   ├── 10-tests.sh
│   └── lib/
│       ├── common.sh
│       └── kafka-startup.sh
├── runbooks/
│   └── db-failover.md                     ← promover réplica us-east1 en caso de DR
├── cloud-armor/
│   ├── security-policy.sh
│   └── adaptive-protection.sh
├── firewall/
│   ├── vpc-setup.sh
│   ├── firewall-rules.sh
│   └── private-access.sh
├── deploy/
│   ├── deploy-gateway.sh
│   ├── deploy-load-balancer.sh
│   └── deploy-cloud-armor.sh
├── database/
│   └── setup-cloudsql.sh
├── gateway/
│   ├── openapi-spec.yaml          ← spec ACTIVA desplegada en GCP
│   ├── openapi-spec.template.yaml ← plantilla parametrizada
│   └── cors-policy.yaml
├── tests/
│   ├── test_cloud_armor.sh
│   └── test_firewall_rules.sh
├── postman/
│   ├── travelhub-gcp.postman_collection.json
│   ├── travelhub-gcp.postman_environment.dev.json
│   └── travelhub-gcp.postman_environment.prod.json
├── config/
│   ├── environments/
│   │   ├── dev.env
│   │   └── prod.env
│   └── services.env
└── cloud-run-services-cicd-pipeline/  ← Terraform — pipeline CI/CD Cloud Run
    ├── modules/
    └── stacks/
```

## Orden de despliegue (primera vez en un proyecto nuevo)

```bash
source config/environments/dev.env    # o prod.env
bash scripts/01-enable-apis.sh
bash scripts/02-vpc-setup.sh
bash scripts/03-firewall-rules.sh
bash scripts/04-private-access.sh
bash scripts/05-cloud-armor.sh
bash scripts/06-database.sh
bash scripts/07-kafka.sh
bash scripts/08-gateway.sh
bash scripts/09-load-balancer.sh
bash scripts/10-tests.sh
```

O todo de una vez: `source config/environments/dev.env && bash deploy-all.sh`

## URLs del entorno DEV (recursos desplegados)

- **LB (entrada):** `https://apitravelhubdev.site` (IP estática 136.110.223.156, cert SSL managed `dev-travelhub-ssl-managed-new`) — desde 2026-05-08
- **Gateway (directo):** `https://travelhub-gateway-1yvtqj7r.uc.gateway.dev`
- **user-services:** `https://user-services-ridyy4wz4q-uc.a.run.app`
- **pms-integration:** `https://pms-integration-services-ridyy4wz4q-uc.a.run.app`
- **pms-sync-worker:** `https://pms-sync-worker-ridyy4wz4q-uc.a.run.app`
- **notification-services:** `https://notification-services-ridyy4wz4q-uc.a.run.app`
- **search-service:** `https://dev-search-service-app-service-ridyy4wz4q-uc.a.run.app`
- **booking-service:** `https://dev-booking-service-app-service-ridyy4wz4q-uc.a.run.app`
- **Kafka VM:** `travelhub-kafka` (zona `us-central1-c`, IP privada `10.10.3.3:9092`, solo IAP)

## URLs del entorno PROD (desplegado 2026-05-08)

- **LB (entrada):** `https://apitravelhub.site` (IP estática `34.49.119.31`, cert SSL managed `prod-travelhub-ssl-managed`)
- **Gateway (directo):** `https://prod-travelhub-gateway-cfv1jc0r.uc.gateway.dev`
- **user-services:** `https://user-services-qhweqfkejq-uc.a.run.app`
- **pms-integration:** `https://pms-integration-services-qhweqfkejq-uc.a.run.app`
- **pms-sync-worker:** `https://pms-sync-worker-qhweqfkejq-uc.a.run.app`
- **notification-services:** `https://notification-services-qhweqfkejq-uc.a.run.app`
- **search-service / booking-service:** ❌ no desplegados (compañeros pendientes — placeholder en gateway → 404)
- **Kafka VM:** `prod-travelhub-kafka` (zona `us-central1-c`, IP **interna** `10.20.3.3:9092`, IP externa `34.70.192.34` solo para egress apt/docker)

> Ver `gateway/openapi-spec-prod.yaml` para la spec PROD aplicada (config activa: `prod-travelhub-config-20260508-095948` — incluye fix de spec notifications con GET / + GET/PUT/POST /{path}).
> Estado completo de PROD: `INFRA_STATUS_PROD.md` (en raíz del monorepo travelhub).

## Naming legacy en DEV

Los recursos del proyecto DEV (`gen-lang-client-0930444414`) **no tienen prefijo `dev-`**:

| Recurso | Nombre real en DEV | Nombre que los scripts generarían |
|---|---|---|
| VPC | `travelhub-vpc` | `dev-travelhub-vpc` |
| BD | `travelhub-db` | `dev-travelhub-db` |
| Gateway | `travelhub-gateway` | `dev-travelhub-gateway` |
| Kafka VM | `travelhub-kafka` | `dev-travelhub-kafka` |

**Consecuencia:** si ejecutas `scripts/0X-*.sh` contra el proyecto DEV, los scripts NO encontrarán los recursos legacy y crearán duplicados. Para el DEV actual, usa `gcloud` directo con los nombres legacy, o corre los scripts solo contra PROD donde el naming sí es correcto (`prod-travelhub-*`).

## Flujo de red (DEV vs PROD)

```text
DEV : apitravelhubdev.site → 136.110.223.156 → LB → (Cloud Armor sin reglas) → Gateway → Cloud Run
PROD: apitravelhub.site    → 34.49.119.31    → LB → (Cloud Armor pendiente, cuota=0) → Gateway → Cloud Run
```

## Microservicios — mapa completo

> Contexto necesario para agregar rutas al gateway, crear secrets, o configurar WIF para un servicio nuevo.

| Servicio | Puerto | URL DEV | URL PROD | SA deploy (DEV) |
|---|---|---|---|---|
| **user-services** | 8000 | `https://user-services-ridyy4wz4q-uc.a.run.app` | `https://user-services-qhweqfkejq-uc.a.run.app` | `github-deploy@gen-lang-client-0930444414.iam.gserviceaccount.com` |
| **pms-integration-services** | 8001 | `https://pms-integration-services-ridyy4wz4q-uc.a.run.app` | `https://pms-integration-services-qhweqfkejq-uc.a.run.app` | `github-deploy-pms-int@gen-lang-client-0930444414.iam.gserviceaccount.com` |
| **pms-sync-worker** | 8002 | `https://pms-sync-worker-ridyy4wz4q-uc.a.run.app` | `https://pms-sync-worker-qhweqfkejq-uc.a.run.app` | `github-deploy-pms-sync-worker@gen-lang-client-0930444414.iam.gserviceaccount.com` |
| **notification-services** | 8004 | `https://notification-services-ridyy4wz4q-uc.a.run.app` | `https://notification-services-qhweqfkejq-uc.a.run.app` | `github-deploy-notification@gen-lang-client-0930444414.iam.gserviceaccount.com` |
| **search-service** | 8005 | `https://dev-search-service-app-service-ridyy4wz4q-uc.a.run.app` | ❌ no desplegado | Cloud Build service account (compañero) |
| **booking-service** | 8006 | `https://dev-booking-service-app-service-ridyy4wz4q-uc.a.run.app` | ❌ no desplegado | Cloud Build service account (compañero) |

### Comunicación entre servicios

```
user-services         → emite JWT RS256, expone /.well-known/jwks.json
                            ↑ todos los demás validan JWT (decode no-verify)
pms-integration       → valida JWT, publica a Kafka topic pms-sync-queue
   ↓ Kafka DEV 10.10.3.3:9092 / PROD 10.20.3.3:9092
pms-sync-worker       → consume, persiste, idempotencia por event_id
   ↓ HTTP interno POST /api/v1/notifications/internal
notification-services → envía email/push, guarda histórico in-app
```

### Secret Manager — secrets por servicio (DEV `gen-lang-client-0930444414`)

| Secret | Servicio que lo usa |
|---|---|
| `DATABASE_URL` | user-services, pms-integration, pms-sync-worker |
| `DATABASE_URL_SYNC` | pms-sync-worker (conexión síncrona Alembic) |
| `KAFKA_BOOTSTRAP_SERVERS` | pms-integration, pms-sync-worker |
| `RSA_PRIVATE_KEY_B64` | user-services (firma JWT) |
| `dev-travelhub-notification-db-url` | notification-services |
| `dev-travelhub-sendgrid-api-key` | notification-services |
| `dev-travelhub-fcm-credentials` | notification-services |
| `dev-travelhub-internal-notify-token` | notification-services |

> Nota: los primeros 4 usan naming plano (legacy). Los de notification-services ya tienen prefijo `dev-travelhub-`.

### Secret Manager — secrets en PROD (`travelhub-prod-492116`)

Todos con prefijo `prod-travelhub-` excepto los reusados de DEV (legacy).

| Secret | Uso |
|---|---|
| `DATABASE_URL` | user-services |
| `DATABASE_URL_SYNC` | user-services (Alembic) |
| `RSA_PRIVATE_KEY_B64` | user-services |
| `prod-travelhub-db-password` | password de `travelhub_app` en Cloud SQL PROD |
| `KAFKA_BOOTSTRAP_SERVERS` | `10.20.3.3:9092` (creado 2026-05-08) |
| `PMS_DATABASE_HOST/PORT/NAME/USER/PASSWORD` | pms-integration, pms-sync-worker |
| `NOTIFICATION_SERVICE_URL` | pms-sync-worker → notification (HTTP interno) |
| `prod-travelhub-notification-db-url` | notification-services |
| `prod-travelhub-sendgrid-api-key` | notification-services ✅ v3 operativo desde 2026-05-12 (dominio `apitravelhub.site` autenticado, sender `noreply@apitravelhub.site`). Pendiente rotación. |
| `prod-travelhub-fcm-credentials` | notification-services (PLACEHOLDER — en proceso 2026-05-12) |
| `prod-travelhub-db-replica-host` | DR replica `prod-travelhub-db-replica-us-east1` IP `10.200.1.3` — usado por runbook de failover |
| `prod-travelhub-internal-notify-token` | notification-services (auth endpoint /internal) |

### Estado de despliegue por servicio

| Servicio | DEV | PROD |
|---|---|---|
| user-services | ✅ | ✅ |
| pms-integration-services | ✅ | ✅ (2026-05-08) |
| pms-sync-worker | ✅ | ✅ (2026-05-08) |
| notification-services | ✅ | ✅ (2026-05-08; SendGrid operativo 2026-05-12 con dominio verificado, FCM aún placeholder) |
| search-service (compañero) | ✅ | ❌ (placeholder en gateway → 404) |
| booking-service (compañero) | ✅ | ❌ (placeholder en gateway → 404) |
| payments / inventory / shopping-cart | ❌ | ❌ |

### Gateway — rutas configuradas (openapi-spec.yaml)

Rutas **sin JWT** (públicas):
- `POST /api/v1/auth/login` → user-services
- `POST /api/v1/auth/register` → user-services
- `POST /api/v1/auth/refresh` → user-services
- `GET /.well-known/jwks.json` → user-services
- `GET /health` → user-services

Rutas **con JWT**:
- `/api/v1/auth/*` → user-services
- `/api/v1/admin/*` → user-services
- `/api/v1/pms/*` → pms-integration-services
- `/api/v1/notifications/*` → notification-services
- `/api/v1/search/*` → search-service (público — sin JWT)
- `/api/v1/booking/*` → booking-service (mixto: ping/reviews sin JWT, resto con JWT)
- Demás servicios (payments, inventory, cart) → PLACEHOLDER

**Al desplegar un servicio nuevo:** actualizar `gateway/openapi-spec.yaml` (reemplazar PLACEHOLDER con URL real) y redesplegar con `bash deploy/deploy-gateway.sh`.

## Workload Identity Federation

| Proyecto | Pool | Provider | Repos autorizados |
|---|---|---|---|
| DEV `154299161799` | `github-pool` | `github-provider` | `ecruzs-uniandes/miso-travelhub-*` en ramas `develop` o `feature/**` |
| PROD `974898737307` | `github-pool` | `github-provider` | idem para rama `main` |

## Cloud SQL PostgreSQL

- **DEV:** instancia `travelhub-db`, IP privada `10.100.0.3`, BD `travelhub`, usuario `travelhub_app`
- **PROD:** instancia `prod-travelhub-db`, IP privada `10.200.0.3`, BD `travelhub`. Cross-region DR replica `prod-travelhub-db-replica-us-east1` (IP `10.200.1.3`, us-east1-c) desde 2026-05-12 — hot standby, promoción manual. Backups + PITR habilitados (retención 7 días). Ver `runbooks/db-failover.md`.
- Sin IP pública en ningún ambiente. Acceso solo desde `subnet-services` (direct VPC egress).

## Flujo de red

```text
apitravelhub.site → 136.110.223.156 → LB (HTTPS + SSL) → Cloud Armor (WAF) → API Gateway (JWT) → Cloud Run
```

## ASRs que resuelve esta infra

| ASR | Solución |
|---|---|
| AH008 — Seguridad | 4 capas: Cloud Armor > Firewall > API Gateway JWT > Chain of Responsibility |
| AH009 — RBAC | RBACFilter en cada microservicio (claims del JWT) |
| AH007 — Cifrado JWT RS256 | API Gateway valida firma + backend valida claims de negocio |
| AH016 — Rate limiting distribuido | Cloud Armor en borde de red (no por instancia) |

## Decisiones técnicas críticas

### Networking Cloud Run
- **Direct VPC egress** (NO VPC connector): `--network=travelhub-vpc --subnet=subnet-services --vpc-egress=private-ranges-only`
- Si el servicio ya tenía VPC connector, agregar `--clear-vpc-connector`
- **asyncpg ≥ 0.30** obligatorio — versiones anteriores tienen bug SSL con direct VPC egress
- `?ssl=disable` en `DATABASE_URL` (Cloud SQL via IP privada ya está cifrado por GCP)

### JWT
- Emitido por user-services, `kid: travelhub-key-1`, RS256
- `iss: https://auth.travelhub.app`, `aud: travelhub-api`
- JWKS endpoint: `https://user-services-ridyy4wz4q-uc.a.run.app/.well-known/jwks.json`
- Los backends hacen **decode no-verify** (el gateway ya validó firma + exp + iss + aud)
- El gateway reemplaza `Authorization` con su propio OIDC token → el JWT del usuario llega en `X-Forwarded-Authorization`

### Cloud Deploy primer release
Cuando es el primer release en una pipeline nueva, el canary (10%→50%) se salta y va directo a 100%. A partir del segundo release funciona completo.

### Kafka (DEV)
- Broker: `10.10.3.3:9092` (VM `travelhub-kafka`, zona `us-central1-c`)
- Acceso admin: IAP tunnel → `gcloud compute ssh travelhub-kafka --zone=us-central1-c --tunnel-through-iap --project=gen-lang-client-0930444414`
- Topics activos DEV: `pms-sync-queue` (3p), `pms-sync-dlq` (1p), `cancel_booking_queue`, `payments-queue`, **`inventory-rate-events`** (3p — 2026-05-13)
- Topics activos PROD: `pms-sync-queue` (3p), `pms-sync-dlq` (1p), `booking-events` (3p), `payment-events` (3p), `user-events` (3p), `notification-dlq` (1p), **`inventory-rate-events`** (3p — 2026-05-13)
- Crear nuevos topics: SSH a la VM Kafka via IAP y `sudo docker exec travelhub-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic <nombre> --partitions <n> --replication-factor 1`. El container se llama `travelhub-kafka` en ambos ambientes (mismo nombre dentro de la VM PROD).

## NUNCA

- Hardcodear project IDs o URLs en scripts (usar env vars con default)
- `git commit` sin que el usuario lo pida explícitamente
- Tocar Cloud Armor / gateway / firewall / Cloud Deploy sin confirmar con el usuario
- Crear claves de SA — todo via Workload Identity Federation
- Ejecutar `scripts/0X-*.sh` contra DEV (`gen-lang-client-0930444414`) con recursos legacy — ver sección "Naming legacy en DEV"
