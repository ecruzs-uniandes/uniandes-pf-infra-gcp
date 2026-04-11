###########################################################
# Config Variables
###########################################################
region = "us-central1"
owner = "privera2505" #Github User
project_name = "search-service"
environment = "prod"
project_id_gcp = "secret-lambda-491419-p2"
###########################################################
# Cloud run Variables
###########################################################
ingress_type = "internal-and-cloud-load-balancing"
security_type =  "allUsers"
load_balancer_uri = "http://url.com" #Modificar para produccion
###########################################################
# CI/CD Variables
###########################################################
gh_repo = "search-service-miso"
gh_branch = "main"
container_port = 8000
gh_conn_name = "gh-conn" #En cloud build v2, se debe conectar a un host en la v2
health_check_url = "/search/ping"
env_vars = {
    REPOSITORY_IMPL = "postgres"
    APP_HOST = "0.0.0.0"
    APP_PORT = "8000"
    INSTANCE_CONNECTION_NAME = "secret-lambda-491419-p2:us-central1:test-search-services"
    DB_HOST = "localhost"
    DB_PORT = "5432"
    DB_USER = "postgres"
    DB_NAME = "postgres"
    DB_PASSWORD = "Postgres1."
    ENVIRONMENT = "prod"
}