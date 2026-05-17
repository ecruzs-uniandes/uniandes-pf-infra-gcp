###########################################################
# Config Variables
###########################################################
region = "us-central1"
owner = "privera2505" #Github User
project_name = "booking-worker"
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
load_balancer_uri = "https://apitravelhubdev.site" #Modificar para produccion
###########################################################
# CI/CD Variables
###########################################################
gh_repo = "miso-travelhub-cancel-booking-worker"
gh_branch = "develop"
container_port = 8000
gh_conn_name = "privera2505" #En cloud build v2, se debe conectar a un host en la v2
health_check_url = "/worker/booking_cancelation/health"
ingress_type_cicd = "internal-and-cloud-load-balancing"
env_vars = {
    database_host = "10.100.0.3"
    database_port = "5432"
    database_name = "travelhub"
    database_user = "travelhub_app"
    database_password = "lALk8rAOj1TSltRQzGavZdBCrSu67ZJg"
    kafka_bootstrap_servers = "10.10.3.3:9092"
    kafka_topic_pms_sync = "cancel_booking_queue"
    kafka_consumer_group = "cancel-booking-worker-group"
    kafka_enabled = "True"
    payments_service_url = "https://payments-services-154299161799.us-central1.run.app"
}