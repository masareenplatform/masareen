# MASAREN Development Environment
# On-premises: HPE ProLiant DL360 Gen10 (32GB RAM, 0GB VRAM)

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

variable "postgres_password" { type = string; sensitive = true }
variable "neo4j_password"    { type = string; sensitive = true }
variable "cloud_api_key"     { type = string; sensitive = true }
variable "jwt_secret"        { type = string; sensitive = true }

locals {
  network_name = "masaren-network"
  env_name     = "dev"
}

# ── Network ───────────────────────────────────────────────────────────────────
resource "docker_network" "masaren" {
  name   = local.network_name
  driver = "bridge"
}

# ── PostgreSQL + PostGIS ──────────────────────────────────────────────────────
resource "docker_container" "postgres" {
  name  = "masaren-postgres"
  image = "postgis/postgis:16-3.4"
  restart = "always"
  networks_advanced { name = docker_network.masaren.name }
  ports { internal = 5432; external = 5432 }
  env = [
    "POSTGRES_USER=masaren_user",
    "POSTGRES_PASSWORD=${var.postgres_password}",
    "POSTGRES_DB=masaren_impact",
  ]
  volumes { volume_name = "masaren_postgres_data"; container_path = "/var/lib/postgresql/data" }
}

# ── Neo4j ─────────────────────────────────────────────────────────────────────
resource "docker_container" "neo4j" {
  name  = "masaren-neo4j"
  image = "neo4j:5-community"
  restart = "always"
  networks_advanced { name = docker_network.masaren.name }
  ports { internal = 7474; external = 7474 }
  ports { internal = 7687; external = 7687 }
  env = [
    "NEO4J_AUTH=neo4j/${var.neo4j_password}",
    "NEO4J_PLUGINS=[\"apoc\",\"graph-data-science\"]",
    "NEO4J_dbms_memory_heap_max__size=1G",
  ]
  volumes { volume_name = "masaren_neo4j_data"; container_path = "/data" }
}

# ── Redis ─────────────────────────────────────────────────────────────────────
resource "docker_container" "redis" {
  name  = "masaren-redis"
  image = "redis:7-alpine"
  restart = "always"
  networks_advanced { name = docker_network.masaren.name }
  ports { internal = 6379; external = 6379 }
  command = ["redis-server","--maxmemory","256mb","--maxmemory-policy","allkeys-lru"]
  volumes { volume_name = "masaren_redis_data"; container_path = "/data" }
}

# ── Kafka (KRaft) ─────────────────────────────────────────────────────────────
resource "docker_container" "kafka" {
  name  = "masaren-kafka"
  image = "apache/kafka:3.7.0"
  restart = "always"
  networks_advanced { name = docker_network.masaren.name }
  ports { internal = 9092; external = 9092 }
  env = [
    "KAFKA_NODE_ID=1",
    "KAFKA_PROCESS_ROLES=broker,controller",
    "KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093",
    "KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://masaren-kafka:9092",
    "KAFKA_CONTROLLER_QUORUM_VOTERS=1@masaren-kafka:9093",
    "KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER",
    "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT",
    "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1",
    "KAFKA_AUTO_CREATE_TOPICS_ENABLE=true",
    "CLUSTER_ID=masaren-kafka-cluster-01",
  ]
  volumes { volume_name = "masaren_kafka_data"; container_path = "/var/lib/kafka/data" }
}

# ── OpenSearch ────────────────────────────────────────────────────────────────
resource "docker_container" "opensearch" {
  name  = "masaren-opensearch"
  image = "opensearchproject/opensearch:2"
  restart = "always"
  networks_advanced { name = docker_network.masaren.name }
  ports { internal = 9200; external = 9200 }
  env = [
    "discovery.type=single-node",
    "OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m",
    "DISABLE_SECURITY_PLUGIN=true",
  ]
  volumes { volume_name = "masaren_opensearch_data"; container_path = "/usr/share/opensearch/data" }
}

# ── Volumes ────────────────────────────────────────────────────────────────────
resource "docker_volume" "postgres"    { name = "masaren_postgres_data" }
resource "docker_volume" "neo4j"       { name = "masaren_neo4j_data" }
resource "docker_volume" "redis"       { name = "masaren_redis_data" }
resource "docker_volume" "kafka"       { name = "masaren_kafka_data" }
resource "docker_volume" "opensearch"  { name = "masaren_opensearch_data" }

output "postgres_host"    { value = "localhost:5432" }
output "neo4j_host"       { value = "localhost:7474" }
output "kafka_bootstrap"  { value = "localhost:9092" }
output "opensearch_host"  { value = "localhost:9200" }
