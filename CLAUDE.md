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
│   ├── 07-kafka.sh
│   ├── 08-gateway.sh
│   ├── 09-load-balancer.sh
│   ├── 10-tests.sh
│   └── lib/
│       ├── common.sh
│       └── kafka-startup.sh
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

- **LB (entrada):** `https://apitravelhub.site` (IP estática 136.110.223.156)
- **Gateway (directo):** `https://travelhub-gateway-1yvtqj7r.uc.gateway.dev`
- **user-services:** `https://user-services-ridyy4wz4q-uc.a.run.app`
- **pms-integration:** `https://pms-integration-services-ridyy4wz4q-uc.a.run.app`
- **pms-sync-worker:** `https://pms-sync-worker-ridyy4wz4q-uc.a.run.app`
- **notification-services:** pendiente primer deploy completo
- **Kafka VM:** `travelhub-kafka` (zona `us-central1-c`, IP privada `10.10.3.3:9092`, solo IAP)

## Naming legacy en DEV

Los recursos del proyecto DEV (`gen-lang-client-0930444414`) **no tienen prefijo `dev-`**:

| Recurso | Nombre real en DEV | Nombre que los scripts generarían |
|---|---|---|
| VPC | `travelhub-vpc` | `dev-travelhub-vpc` |
| BD | `travelhub-db` | `dev-travelhub-db` |
| Gateway | `travelhub-gateway` | `dev-travelhub-gateway` |
| Kafka VM | `travelhub-kafka` | `dev-travelhub-kafka` |

**Consecuencia:** si ejecutas `scripts/0X-*.sh` contra el proyecto DEV, los scripts NO encontrarán los recursos legacy y crearán duplicados. Para el DEV actual, usa `gcloud` directo con los nombres legacy, o corre los scripts solo contra PROD donde el naming sí es correcto (`prod-travelhub-*`).

## Workload Identity Federation

| Proyecto | Pool | Provider | Repos autorizados |
|---|---|---|---|
| DEV `154299161799` | `github-pool` | `github-provider` | `ecruzs-uniandes/miso-travelhub-*` en ramas `develop` o `feature/**` |
| PROD `974898737307` | `github-pool` | `github-provider` | idem para rama `main` |

## Cloud SQL PostgreSQL

- **DEV:** instancia `travelhub-db`, IP privada `10.100.0.3`, BD `travelhub`, usuario `travelhub_app`
- **PROD:** instancia `prod-travelhub-db`, IP privada `10.200.0.3`, BD `travelhub`
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

## NUNCA

- Hardcodear project IDs o URLs en scripts (usar env vars con default)
- `git commit` sin que el usuario lo pida explícitamente
- Tocar Cloud Armor / gateway / firewall / Cloud Deploy sin confirmar con el usuario
- Crear claves de SA — todo via Workload Identity Federation
- Ejecutar `scripts/0X-*.sh` contra DEV (`gen-lang-client-0930444414`) con recursos legacy — ver sección "Naming legacy en DEV"
