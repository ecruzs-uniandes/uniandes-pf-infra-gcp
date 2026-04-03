# CI/CD Pipeline - Cloud Run Deployment

Pipeline de integración y despliegue continuo para microservicios en Google Cloud Run, utilizando Cloud Build y estrategias avanzadas de despliegue Blue/Green + Canary, con rollback automático basado en validaciones de health checks.

Este pipeline permite construir, validar, desplegar progresivamente y asegurar la estabilidad del servicio antes de exponer tráfico completo.
## Índice

1. [Estructura](#estructura)
2. [Arquitectura](#arquitectura)
3. [Estrategia de Despliegue](#estrategia-de-despliegue)
4. [Flujo del Pipeline](#flujo-del-pipeline)
5. [Variables de Configuración Terraform](#variables-de-configuración-terraform)
6. [Variables de Configuración Makefile](#variables-de-configuración-makefile)
7. [Ejecución](#ejecución)
8. [Autor](#autor)


## Estructura

Estructura de la **carpeta del pipeline**:
```
cloud-run-services-cicd-pipeline/
├─ .gitignore                # Excluye .venv, .terraform, .tfplan.
├─ makefile                  # Comandos básicos de ejecución.
├─ environments/
│  ├─ pablo/
│  │  ├─ backend.tfvars      # Var. para backend remoto de Terraform
│  │  ├─ terraform.tfvars    # Var. Amb para stack
├─ modules/
│  ├─ artifact-registry/
│  ├─ bucket/
│  ├─ cloud_build_repository/
│  ├─ cloud_build_sa/
│  ├─ cloud_build_trigger/
│  ├─ cloud_deploy_automation/
│  ├─ cloud_deploy_automation_sa/
│  ├─ cloud_deploy_delivery_pipeline/
│  ├─ cloud_deploy_targets/
│  ├─ cloud_run_service/
│  ├─ neg/
│  ├─ service-account-cloud-build/
├─ modules/
│  ├─ bucket_backend/        # Crear backend remoto
│  ├─ main/                  # Crear pipelince CI/Cd
```

## Arquitectura

El pipeline se basa en los siguientes componentes:

- **Cloud Build:** Desencadena el build del artefacto cuando se hace un push a la rama [gh_branch](#cicd) en el repositorio [gh_repo](#cicd). Además, construye la imagen Docker, la etiqueta y la publica en el registry.
- **Cloud Deploy Pipeline:** Orquesta el despliegue progresivo usando estrategias Blue/Green + Canary. Gestiona releases, targets y promociones entre revisiones de Cloud Run, incluyendo validaciones automatizadas.
    - **Cloud Deploy Automation:** En caso de que las validaciones automatizadas fallan generan un rollback a la ultima revisión estable.
- **Artifact Registry:** Almacenamiento de imágenes Docker versionadas.
- **Cloud Run:** Plataforma serverless donde se despliegan las revisiones del servicio.
- **HTTP Load Balancer:** Controla el enrutamiento de tráfico entre versiones (Blue/Green y Canary).
- **GitHub:** Fuente del código y disparador del pipeline CI/CD. 

## Estrategia de Despliegue
Se implementa una estrategia híbrida:

- Blue/Green Deployment: 
    - Se mantiene una versión estable (Blue) en producción.
    - Se despliega una nueva versión (Green) sin afectar usuarios.
El tráfico se redirige solo después de validación exitosa.
- Canary Deployment
    - Se enruta un pequeño porcentaje de tráfico a la nueva versión.
    - Se monitorea comportamiento antes de liberar al 100%.
- Distribución típica de tráfico:
    - 10% -> nueva versión (canary)
    - 30% -> nueva versión (canary)
    - 60% -> nueva versión (canary)
    - Luego → 100% si todo es correcto

## Flujo del Pipeline

1. Trigger (GitHub)
    - Se activa en push a la rama [gh_branch](#cicd).
2. Build
    - Construcción de imagen Docker, tag basado en commit SHA y push a Artifact Registry.
3. Deploy (Green)
    - Despliegue de nueva revisión en Cloud Run, sin tráfico inicial (0%)
4. Health Check
    - Validación mediante:
       - GET {[load_balancer_uri](#cloud-run)}{[health_check_url](#cicd)}
5. Canary Release
    - Se asigna tráfico parcial (ej: 10%) y se monitorean errores y latencia
6. Promoción
    - Si todo es exitoso:
    - Se asigna 100% del tráfico a la revisión con la nueva versión.
    - Si hay un error
        - En caso de que ocurra alguna de las siguientes condiciones:
            - Fallo en health check
            - Timeout en respuesta
            - Código HTTP diferente de 200
            - Errores detectados en fase canary
        - Comportamiento:
            - Se detiene la promoción
            - Se redirige el tráfico al deployment anterior
            - Se marca el build como fallido

## **Variables de Configuración Terraform**



### Configuración General

| Variable          | Default     | Descripción                                  |
|-------------------|-------------|----------------------------------------------|
| `region`        | `us-central1`   | Región de despliegue                             |
| `owner`        | `privera2505`      | Usuario de GitHub                            |
| `project_name` | `travelhub-project`  | Nombre del proyecto o servicio |
| `environment`         | `prod` | Ambiente (dev, qa, prod)                          |
| `project_id_gcp`         | `secret-lambda-491419-p2`      | ID del proyecto en GCP        |

### Cloud Run

| Variable          | Default     | Descripción                                  |
|-------------------|-------------|----------------------------------------------|
| `ingress_type`        | `internal-and-cloud-load-balancing`   | Tipo de ingreso                                |
| `security_type`        | `allUsers`      | Acceso público                             |
| `load_balancer_uri` | `http://url.com`  | URL del balanceador                       |

### CI/CD

| Variable          | Default     | Descripción                                  |
|-------------------|-------------|----------------------------------------------|
| `gh_repo`        | `test-cicd-devop`   | Repositorio de GitHub                               |
| `gh_branch`        | `main`      | Rama de despliegue                            |
| `container_port` | 8000  | Puerto del contenedor                      |
| `gh_conn_name` | `gh-conn`  | Conexión GitHub en Cloud Build v2                      |
| `health_check_url` | `/api2/health`  | Endpoint de validación (Healthcheck)                       |

## **Variables de Configuración Makefile**

### Makefile

| Variable          | Default     | Descripción                                  |
|-------------------|-------------|----------------------------------------------|
| `PROJECT-ID`        | `secret-lambda-491419-p2`   | ID del proyecto en GCP. Debe coincidir con [ID](#configuración-general)  |
| `REGION`        | `us-central1`      | Región de despliegue. Debe coincidir con [REGION](#configuración-general)|
| `ZONE` | `us-central1-a`  | Zona de despliegue. Debe ser una zona que se encuentre en la región seleccionada.|

## Ejecución

### Prerrequisitos

Antes de ejecutar los comandos, asegúrate de tener instalado y configurado:
- Terraform
- Google Cloud SDK
- Credenciales activas (gcloud auth login)
    - Usar la cuenta donde tienes el proyecto de GCP.

#### 1. Configurar el proyecto en GCP
Inicializa el contexto del proyecto, región y zona:
``` bash
make init-project
```
Verificación opcional:
```bash
make get-project
make get-region
make get-zone
```
Con esto se logra establecer en que parte del mundo se desplegara la infraestructura que construye este stack.

#### 2. Inicializar Backend de Terraform
Este paso crea/configura el backend remoto donde se almacenará el estado:
``` bash
make init-terraform
```
**¿Qué hace internamente?**
- Inicializa Terraform en stacks/bucket_backend
- Genera el plan
- Aplica la infraestructura del bucket backend

#### 3. Desplegar Infraestructura Principal

Una vez configurado el backend, se despliega la infraestructura principal:
``` bash
make create-terraform
```
Incluye:
- Cloud Run
- Cloud Deploy
- Artifact Registry
- Load Balancer
- Configuración CI/CD

#### 4. Eliminación de Infraestructura
Eliminar infraestructura principal:
``` bash
make delete
```
Eliminar backend (bucket Terraform):
``` bash
make reset
```

#### Flujo recomendado de ejecución
Configurar proyecto:
``` bash
make init-project
```
Crear backend:
``` bash
make init-terraform
```
Desplegar infraestructura:
``` bash
make create-terraform
```

#### Notas importantes
- El backend debe crearse antes de la infraestructura principal.
- No elimines el backend (reset) si aún tienes infraestructura activa.
- Los archivos .tfplan son temporales y no deben versionarse.

## Autor

- Pablo Jose Rivera herrera
- Contacto: `<p.riverah@uniandes.edu.co>`
