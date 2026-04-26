###########################################################
# Config Variables
###########################################################
region = "us-central1"
owner = "privera2505" #Github User
project_name = "booking-service"
environment = "dev"
project_id_gcp = "gen-lang-client-0930444414"
###########################################################
# VPC Variables
###########################################################
vpc_name = "travelhub-vpc"
subnet_name = "subnet-services"
###########################################################
# Cloud run Variables
###########################################################
ingress_type = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
security_type =  "allUsers"
load_balancer_uri = "https://apitravelhub.site" #Modificar para produccion
###########################################################
# CI/CD Variables
###########################################################
gh_repo = "uniandes-pf-booking-gcp"
gh_branch = "develop"
container_port = 8000
gh_conn_name = "privera2505" #En cloud build v2, se debe conectar a un host en la v2
health_check_url = "/api/v1/booking/ping"
ingress_type_cicd = "internal-and-cloud-load-balancing"
env_vars = {
    REPOSITORY_IMPL = "memory"
    APP_HOST = "0.0.0.0"
    APP_PORT = "8000"
    INSTANCE_CONNECTION_NAME = "gen-lang-client-0930444414:us-central1:travelhub-db"
    DB_HOST = "localhost"
    DB_PORT = "5432"
    DB_USER = "travelhub_app"
    DB_NAME = "travelhub"
    DB_PASSWORD = "lALk8rAOj1TSltRQzGavZdBCrSu67ZJg"
    ENVIRONMENT = "prod"
}