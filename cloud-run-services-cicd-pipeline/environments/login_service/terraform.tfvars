###########################################################
# Config Variables
###########################################################
region = "us-central1"
owner = "ecruzs-uniandes" #Github User
project_name = "login-service"
environment = "dev"
project_id_gcp = "gen-lang-client-0930444414"
###########################################################
# Cloud run Variables
###########################################################
service_name = "user-services" #Quitar si es nuevo
ingress_type = "internal-and-cloud-load-balancing"
security_type =  "allUsers"
load_balancer_uri = "https://apitravelhub.site/" #Modificar para produccion
###########################################################
# CI/CD Variables
###########################################################
gh_repo = "uniandes-pf-user-services"
gh_branch = "main"
container_port = 8000
gh_conn_name = "ecruzs-uniandes" #En cloud build v2, se debe conectar a un host en la v2
health_check_url = "/health"
env_vars = {
    DATABASE_URL="postgresql+asyncpg://travelhub_app:lALk8rAOj1TSltRQzGavZdBCrSu67ZJg@10.100.0.3:5432/travelhub"
    DATABASE_URL_SYNC="postgresql+psycopg2://travelhub_app:lALk8rAOj1TSltRQzGavZdBCrSu67ZJg@10.100.0.3:5432/travelhub"
    JWT_SECRET_KEY="dev-secret-key-change-in-production"
    JWT_ALGORITHM="RS256"
    JWT_ISSUER="https://auth.travelhub.app"
    JWT_AUDIENCE="travelhub-api"
    JWT_ACCESS_TTL=900
    JWT_REFRESH_TTL=604800
    ACCESS_TOKEN_EXPIRE_MINUTES=15
    REFRESH_TOKEN_EXPIRE_DAYS=7
    BCRYPT_ROUNDS=12
    MAX_LOGIN_ATTEMPTS=5
    LOCKOUT_MINUTES=15
    RATE_LIMIT_REQUESTS=100
    RATE_LIMIT_WINDOW_SECONDS=60
    ENVIRONMENT="development"
    DEBUG=true
}