#!/bin/bash
# ============================================================
# TravelHub — Step 06b: Cloud SQL cross-region READ REPLICA (DR)
# ============================================================
# Crea una réplica de lectura de la instancia primaria en otra
# región. Estrategia: DR-only (hot standby). La réplica no recibe
# tráfico normalmente — se promueve manualmente si el primary cae.
#
# Idempotente: si la réplica ya existe, omite la creación pero
# refresca el secret con la IP actual.
#
# Prerrequisitos:
#   - Instancia primaria existe (script 06)
#   - Primary tiene backups + PITR habilitados (el script los habilita
#     si faltan, previa confirmación del usuario)
#
# Uso:
#   source config/environments/prod.env && bash scripts/06b-database-replica.sh
#
# Solo PROD. Ejecutar contra DEV no tiene sentido (DR sobre BD de pruebas).
# ============================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
require_env

if [[ "${ENV}" != "prod" ]]; then
  log_error "Este script solo debe correrse contra PROD."
  log_error "Ambiente actual: ${ENV}. Aborto."
  exit 1
fi

# Defaults — pueden sobreescribirse desde prod.env
: "${REPLICA_REGION:=us-east1}"
: "${REPLICA_INSTANCE_NAME:=${DB_INSTANCE_NAME}-replica-${REPLICA_REGION}}"
: "${REPLICA_TIER:=}"            # vacío = mismo tier que primary
: "${REPLICA_SECRET_HOST_NAME:=${PREFIX}-db-replica-host}"

log_step "Creando réplica cross-region: ${REPLICA_INSTANCE_NAME} (${REPLICA_REGION})"

# ── 1. Validar primary existe ──
if ! sql_instance_exists "${DB_INSTANCE_NAME}"; then
  log_error "Instancia primaria '${DB_INSTANCE_NAME}' no existe. Corre script 06 primero."
  exit 1
fi

# ── 2. Obtener metadata de primary ──
log_info "Inspeccionando configuración del primary..."
PRIMARY_TIER=$(gcloud sql instances describe "${DB_INSTANCE_NAME}" \
  --project="${GCP_PROJECT_ID}" \
  --format="value(settings.tier)")
PRIMARY_REGION=$(gcloud sql instances describe "${DB_INSTANCE_NAME}" \
  --project="${GCP_PROJECT_ID}" \
  --format="value(region)")
PRIMARY_BACKUPS=$(gcloud sql instances describe "${DB_INSTANCE_NAME}" \
  --project="${GCP_PROJECT_ID}" \
  --format="value(settings.backupConfiguration.enabled)")
PRIMARY_PITR=$(gcloud sql instances describe "${DB_INSTANCE_NAME}" \
  --project="${GCP_PROJECT_ID}" \
  --format="value(settings.backupConfiguration.pointInTimeRecoveryEnabled)")
PRIMARY_NETWORK=$(gcloud sql instances describe "${DB_INSTANCE_NAME}" \
  --project="${GCP_PROJECT_ID}" \
  --format="value(settings.ipConfiguration.privateNetwork)")

log_info "  tier:    ${PRIMARY_TIER}"
log_info "  region:  ${PRIMARY_REGION}"
log_info "  backups: ${PRIMARY_BACKUPS}"
log_info "  PITR:    ${PRIMARY_PITR}"

if [[ "${REPLICA_REGION}" == "${PRIMARY_REGION}" ]]; then
  log_error "REPLICA_REGION (${REPLICA_REGION}) == PRIMARY_REGION. Para DR cross-region usa otra región."
  exit 1
fi

REPLICA_TIER="${REPLICA_TIER:-${PRIMARY_TIER}}"

# ── 3. Habilitar backups + PITR en primary si faltan ──
NEED_PATCH=""
if [[ "${PRIMARY_BACKUPS}" != "True" && "${PRIMARY_BACKUPS}" != "true" ]]; then
  NEED_PATCH="${NEED_PATCH} --backup-start-time=03:00"
fi
if [[ "${PRIMARY_PITR}" != "True" && "${PRIMARY_PITR}" != "true" ]]; then
  NEED_PATCH="${NEED_PATCH} --enable-point-in-time-recovery"
fi

if [[ -n "${NEED_PATCH}" ]]; then
  log_warn "Primary necesita backups/PITR habilitados para soportar replicación cross-region."
  log_warn "Comando a ejecutar:"
  echo "  gcloud sql instances patch ${DB_INSTANCE_NAME} --project=${GCP_PROJECT_ID}${NEED_PATCH}"
  log_warn "Esto reinicia el primary brevemente (~minutos)."
  read -r -p "¿Aplicar el patch ahora? [y/N] " CONFIRM
  if [[ "${CONFIRM}" =~ ^[Yy]$ ]]; then
    gcloud sql instances patch "${DB_INSTANCE_NAME}" \
      --project="${GCP_PROJECT_ID}" \
      ${NEED_PATCH}
    log_success "Patch aplicado en primary."
  else
    log_error "Patch rechazado. La réplica no se puede crear sin backups+PITR en primary. Aborto."
    exit 1
  fi
fi

# ── 4. Crear réplica (si no existe) ──
if sql_instance_exists "${REPLICA_INSTANCE_NAME}"; then
  log_warn "Réplica '${REPLICA_INSTANCE_NAME}' ya existe — omitiendo creación"
else
  log_info "Creando réplica '${REPLICA_INSTANCE_NAME}' en ${REPLICA_REGION}..."
  log_info "  tier: ${REPLICA_TIER}"
  log_info "  master: ${DB_INSTANCE_NAME} (${PRIMARY_REGION})"

  gcloud sql instances create "${REPLICA_INSTANCE_NAME}" \
    --master-instance-name="${DB_INSTANCE_NAME}" \
    --region="${REPLICA_REGION}" \
    --tier="${REPLICA_TIER}" \
    --availability-type=zonal \
    --network="${PRIMARY_NETWORK}" \
    --no-assign-ip \
    --project="${GCP_PROJECT_ID}"
  log_success "Réplica creada (puede tardar varios minutos en inicializar)."
fi

# ── 5. Obtener IP privada de la réplica y guardarla en Secret Manager ──
REPLICA_IP=$(gcloud sql instances describe "${REPLICA_INSTANCE_NAME}" \
  --project="${GCP_PROJECT_ID}" \
  --format="value(ipAddresses[0].ipAddress)")

if [[ -z "${REPLICA_IP}" ]]; then
  log_warn "Réplica aún no tiene IP asignada (inicializando). Re-corre el script en unos minutos."
else
  if secret_exists "${REPLICA_SECRET_HOST_NAME}"; then
    log_info "Actualizando secret ${REPLICA_SECRET_HOST_NAME} con IP ${REPLICA_IP}..."
    echo -n "${REPLICA_IP}" | gcloud secrets versions add "${REPLICA_SECRET_HOST_NAME}" \
      --data-file=- \
      --project="${GCP_PROJECT_ID}"
  else
    log_info "Creando secret ${REPLICA_SECRET_HOST_NAME}=${REPLICA_IP}..."
    echo -n "${REPLICA_IP}" | gcloud secrets create "${REPLICA_SECRET_HOST_NAME}" \
      --data-file=- \
      --project="${GCP_PROJECT_ID}"
  fi
  log_success "Secret ${REPLICA_SECRET_HOST_NAME} listo."
fi

echo ""
log_success "Configuración de réplica cross-region completada"
echo ""
echo "Resumen:"
echo "  Primary:     ${DB_INSTANCE_NAME} (${PRIMARY_REGION})"
echo "  Réplica:     ${REPLICA_INSTANCE_NAME} (${REPLICA_REGION})"
echo "  Tier:        ${REPLICA_TIER}"
echo "  IP replica:  ${REPLICA_IP:-<pending>}"
echo "  Secret IP:   ${REPLICA_SECRET_HOST_NAME}"
echo ""
echo "Estado actual: hot standby. Sin tráfico normalmente."
echo "Verificación de replicación:"
echo "  gcloud sql instances describe ${REPLICA_INSTANCE_NAME} \\"
echo "    --project=${GCP_PROJECT_ID} \\"
echo "    --format='value(replicaConfiguration,state)'"
echo ""
echo "Para promover en caso de DR: ver runbooks/db-failover.md"
