# Runbook — Cloud SQL Cross-Region Failover (PROD)

> **Estrategia:** DR-only. Réplica `prod-travelhub-db-replica-us-east1` es hot standby en `us-east1`. Sin tráfico hasta promoción manual.
> **Primary:** `prod-travelhub-db` (us-central1, IP `10.200.0.3`).
> **Cuenta requerida:** `edwin.farmatodo@gmail.com` con role `roles/cloudsql.admin` en `travelhub-prod-492116`.
> **Tiempo total estimado:** 10–20 min con runbook ejecutado a mano.

## 1. Detectar la caída

Antes de promover, **confirmar que la caída no es de red** (Cloud Run sigue resolviendo, pero la BD no responde) revisando:

```bash
# 1.1 Estado del primary
gcloud sql instances describe prod-travelhub-db \
  --project=travelhub-prod-492116 \
  --format="value(state)"
# Esperado en falla: STOPPED / FAILED / MAINTENANCE prolongado
```

```bash
# 1.2 Status page de GCP — incidente confirmado en us-central1 Cloud SQL
open https://status.cloud.google.com/
```

```bash
# 1.3 Lag de replicación reciente (si todavía hay métricas)
gcloud monitoring time-series list \
  --project=travelhub-prod-492116 \
  --filter='metric.type="cloudsql.googleapis.com/database/replication/network_lag"
            resource.labels.database_id="travelhub-prod-492116:prod-travelhub-db-replica-us-east1"' \
  --interval-end-time=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --interval-start-time=$(date -u -v-15M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
                         || date -u -d '-15 min' +%Y-%m-%dT%H:%M:%SZ)
```

**Criterio para promover:** primary indisponible > 10 min AND no hay ETA del incidente AND lag de replicación al último snapshot < 60s.

## 2. Promover la réplica

> ⚠️ **Irreversible.** Una réplica promovida no puede volver a ser réplica. Tras la promoción habrá que crear una nueva réplica con `scripts/06b-database-replica.sh`.

```bash
gcloud sql instances promote-replica prod-travelhub-db-replica-us-east1 \
  --project=travelhub-prod-492116
```

Esperar a que el estado sea `RUNNABLE`:

```bash
until [[ "$(gcloud sql instances describe prod-travelhub-db-replica-us-east1 \
              --project=travelhub-prod-492116 --format='value(state)')" == "RUNNABLE" ]]; do
  echo "Esperando... $(date)"
  sleep 15
done
```

## 3. Capturar la nueva IP

```bash
NEW_IP=$(gcloud sql instances describe prod-travelhub-db-replica-us-east1 \
  --project=travelhub-prod-492116 \
  --format='value(ipAddresses[0].ipAddress)')
echo "Nueva IP del primary: ${NEW_IP}"
```

## 4. Rotar secrets para apuntar a la nueva IP

Cada servicio tiene secrets distintos. Rotar **todos** los que contengan la IP del primary anterior (`10.200.0.3`):

```bash
# user-services — DATABASE_URL es URL completa, hay que reconstruirla
DB_USER="travelhub_app"
DB_PASS=$(gcloud secrets versions access latest --secret=prod-travelhub-db-password \
  --project=travelhub-prod-492116)
NEW_URL_ASYNC="postgresql+asyncpg://${DB_USER}:${DB_PASS}@${NEW_IP}:5432/travelhub?ssl=disable"
NEW_URL_SYNC="postgresql+psycopg2://${DB_USER}:${DB_PASS}@${NEW_IP}:5432/travelhub"

echo -n "${NEW_URL_ASYNC}" | gcloud secrets versions add DATABASE_URL \
  --data-file=- --project=travelhub-prod-492116
echo -n "${NEW_URL_SYNC}" | gcloud secrets versions add DATABASE_URL_SYNC \
  --data-file=- --project=travelhub-prod-492116
```

```bash
# pms-integration + pms-sync-worker — solo DATABASE_HOST cambia
echo -n "${NEW_IP}" | gcloud secrets versions add PMS_DATABASE_HOST \
  --data-file=- --project=travelhub-prod-492116
```

```bash
# notification-services — DATABASE_URL completa
NEW_NOTIF_URL="postgresql+asyncpg://${DB_USER}:${DB_PASS}@${NEW_IP}:5432/travelhub?ssl=disable"
echo -n "${NEW_NOTIF_URL}" | gcloud secrets versions add prod-travelhub-notification-db-url \
  --data-file=- --project=travelhub-prod-492116
```

```bash
# inventory-services — DATABASE_URL completa (cuando esté desplegado)
NEW_INV_URL="postgresql+asyncpg://${DB_USER}:${DB_PASS}@${NEW_IP}:5432/travelhub?ssl=disable"
echo -n "${NEW_INV_URL}" | gcloud secrets versions add INVENTORY_DATABASE_URL \
  --data-file=- --project=travelhub-prod-492116
```

## 5. Forzar redeploy de Cloud Run para recoger los secrets

Cloud Run **no** recarga secrets en caliente; necesita una nueva revisión:

```bash
TS=$(date +%s)
for SVC in user-services pms-integration-services pms-sync-worker \
           notification-services inventory-services; do
  gcloud run services update "${SVC}" \
    --region=us-central1 \
    --project=travelhub-prod-492116 \
    --update-env-vars=FAILOVER_TS=${TS} \
    --quiet || echo "${SVC} no existe — skip"
done
```

> Si la falla regional afectó también a Cloud Run en us-central1, los servicios habrá que redesplegarlos en us-east1 (fuera del scope de DR-only). Ver sección 8 (Fase 2).

## 6. Validación

```bash
# Health checks via gateway
curl -s https://apitravelhub.site/health | jq
```

```bash
# Login E2E
curl -sX POST https://apitravelhub.site/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"smoke@travelhub.app","password":"<known-test-pass>"}' | jq .access_token
```

```bash
# Smoke por servicio
TOKEN="<token>"
curl -s https://apitravelhub.site/api/v1/pms/availability \
  -H "Authorization: Bearer ${TOKEN}"
curl -s https://apitravelhub.site/api/v1/notifications \
  -H "Authorization: Bearer ${TOKEN}"
```

**Criterio de éxito:** todos los endpoints responden `200` y los logs de los servicios no muestran errores de conexión a BD.

## 7. Tras la promoción — restaurar DR

La réplica fue promovida a primary; ya no existe DR. Crear una nueva réplica (esta vez con el nuevo primary en `us-east1` como master y un region distinto como destino — por ejemplo `us-central1` cuando se recupere):

```bash
# Editar prod.env temporalmente:
#   DB_INSTANCE_NAME="prod-travelhub-db-replica-us-east1"  (el nuevo primary)
#   REPLICA_REGION="us-central1"
#   REPLICA_INSTANCE_NAME="prod-travelhub-db-replica-us-central1"
source config/environments/prod.env && bash scripts/06b-database-replica.sh
```

## 8. Limitaciones conocidas (no resueltas por este runbook)

| Componente | Estado tras promoción |
|---|---|
| **Cloud Run** | Sigue en `us-central1`. Si el incidente es regional completo, también caen los Cloud Run y este runbook no aplica. Para DR regional completo habría que mantener Cloud Run + secrets en `us-east1` (Fase 2). |
| **Kafka VM** | `prod-travelhub-kafka` está en `us-central1-c`. Si la región completa cae, `pms-sync-worker` no tiene source. Sin DR de Kafka, mensajes en vuelo se pierden. |
| **API Gateway** | Recurso global, no afectado por la caída de us-central1. |
| **Load Balancer** | Global. No afectado. |
| **Secrets** | Replicación automática (Secret Manager es multi-region por default). |

## 9. Post-mortem

Tras restaurar el servicio, documentar en `INFRA_STATUS_PROD.md`:
- Fecha y hora del incidente.
- Tiempo de detección.
- Tiempo de promoción.
- Tiempo total de RTO real.
- Lag de replicación al momento de la promoción (RPO).
- Errores / fricciones encontradas en este runbook → actualizar el runbook.
