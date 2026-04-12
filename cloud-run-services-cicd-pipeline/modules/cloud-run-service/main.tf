resource "google_cloud_run_v2_service" "app_service" {
    name     = "${var.environment}-${var.project_name}-app-service"
    location = var.region
    ingress  = var.ingress_type # El ingress ahora es un atributo directo, no una anotación

    template {
        containers {
        name  = var.project_name
        image = "us-docker.pkg.dev/cloudrun/container/hello"
        ports {
            container_port = var.container_port
        }
        }
        
        # Configuración de Direct VPC Egress (Reemplaza al Connector)
        vpc_access {
        network_interfaces {
            network    = var.vpc_name # Aquí SÍ va el nombre de tu red VPC
            subnetwork = var.subnet_name # Necesitarás especificar la subred
        }
        egress = "PRIVATE_RANGES_ONLY"
        }
    }
    }

    # Los permisos IAM para v2 usan un recurso ligeramente distinto
    resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
    location = google_cloud_run_v2_service.app_service.location
    project  = google_cloud_run_v2_service.app_service.project
    name     = google_cloud_run_v2_service.app_service.name
    role     = "roles/run.invoker"
    member   = var.security_type
    }