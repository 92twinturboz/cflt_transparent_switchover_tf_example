data "confluent_organization" "this" {}

locals {
  org      = coalesce(var.org, data.confluent_organization.this.id)
  pair_env = coalesce(var.pair_env, confluent_environment.primary.id)

  pair_environment_crn = "crn://confluent.cloud/organization=${local.org}/environment=${local.pair_env}"
}

# ---------------------------------------------------------------------------
# Environments
# ---------------------------------------------------------------------------

resource "confluent_environment" "primary" {
  display_name = var.primary_env_name
}

resource "confluent_environment" "secondary" {
  display_name = var.secondary_env_name
}

# ---------------------------------------------------------------------------
# Primary and secondary clusters
# ---------------------------------------------------------------------------

resource "confluent_kafka_cluster" "primary" {
  display_name = var.primary_cluster_name
  availability = "MULTI_ZONE"
  cloud        = var.cloud
  region       = var.primary_region

  dedicated {
    cku = var.cku
  }

  environment {
    id = confluent_environment.primary.id
  }
}

resource "confluent_kafka_cluster" "secondary" {
  display_name = var.secondary_cluster_name
  availability = "MULTI_ZONE"
  cloud        = var.cloud
  region       = var.secondary_region

  dedicated {
    cku = var.cku
  }

  environment {
    id = confluent_environment.secondary.id
  }
}
