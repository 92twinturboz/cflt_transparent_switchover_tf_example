terraform {
  required_version = ">= 1.5.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.88.0" # first version to include the switchover resources
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

# Credentials come from CONFLUENT_CLOUD_API_KEY / CONFLUENT_CLOUD_API_SECRET.
# Use a Cloud API key (Cloud Resource Management or Global scope) owned by a
# principal with OrganizationAdmin or EnvironmentAdmin.
provider "confluent" {
  endpoint         = "https://api.confluent.cloud"
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}
