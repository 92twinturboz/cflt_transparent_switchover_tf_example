# ---------------------------------------------------------------------------
# Cluster link identity
# ---------------------------------------------------------------------------

resource "confluent_service_account" "dr_link_sa" {
  display_name = "dr-link-sa"
  description  = "Cluster link identity for DR pair"
}

resource "confluent_role_binding" "dr_link_sa_primary" {
  principal   = "User:${confluent_service_account.dr_link_sa.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.primary.rbac_crn
}

resource "confluent_role_binding" "dr_link_sa_secondary" {
  principal   = "User:${confluent_service_account.dr_link_sa.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.secondary.rbac_crn
}

# Global (not cluster-scoped) key: the same credential authenticates against both clusters.
resource "confluent_api_key" "dr_link_global_key" {
  display_name = "dr-link global key"
  description  = "dr-link global key"

  owner {
    id          = confluent_service_account.dr_link_sa.id
    api_version = confluent_service_account.dr_link_sa.api_version
    kind        = confluent_service_account.dr_link_sa.kind
  }

  managed_resource {
    id          = "global"
    api_version = "global/v1"
    kind        = "Global"
  }

  # Both cluster links authenticate with this key. Remove this block before `terraform destroy`.
  lifecycle {
    prevent_destroy = false
  }
}

# New role bindings take a few seconds to propagate; creating the link straight
# away can fail with a cluster authorization error.
resource "time_sleep" "wait_for_dr_link_rbac" {
  create_duration = "30s"

  depends_on = [
    confluent_role_binding.dr_link_sa_primary,
    confluent_role_binding.dr_link_sa_secondary,
    confluent_api_key.dr_link_global_key,
  ]
}

# ---------------------------------------------------------------------------
# Bidirectional cluster link (one resource per direction, same config)
# ---------------------------------------------------------------------------

locals {
  dr_link_config = {
    "auto.create.mirror.topics.enable"  = "true"
    "auto.create.mirror.topics.filters" = jsonencode({ topicFilters = [{ name = "*", patternType = "LITERAL", filterType = "INCLUDE" }] })
    "topic.config.sync.ms"              = "1000"
    "consumer.offset.sync.enable"       = "true"
    "consumer.offset.group.filters"     = jsonencode({ groupFilters = [{ name = "*", patternType = "LITERAL", filterType = "INCLUDE", topicTypes = ["LOCAL_MIRROR"] }] })
    "consumer.offset.sync.ms"           = "1000"
    "acl.sync.enable"                   = "true"
    "acl.filters"                       = jsonencode({ aclFilters = [{ resourceFilter = { resourceType = "any", patternType = "any" }, accessFilter = { operation = "any", permissionType = "any" } }] })
    "acl.sync.ms"                       = "1000"
  }
}

resource "confluent_cluster_link" "primary_to_secondary" {
  link_name = "dr_link"
  link_mode = "BIDIRECTIONAL"

  local_kafka_cluster {
    id            = confluent_kafka_cluster.primary.id
    rest_endpoint = confluent_kafka_cluster.primary.rest_endpoint
    credentials {
      key    = confluent_api_key.dr_link_global_key.id
      secret = confluent_api_key.dr_link_global_key.secret
    }
  }

  remote_kafka_cluster {
    id                 = confluent_kafka_cluster.secondary.id
    bootstrap_endpoint = confluent_kafka_cluster.secondary.bootstrap_endpoint
    credentials {
      key    = confluent_api_key.dr_link_global_key.id
      secret = confluent_api_key.dr_link_global_key.secret
    }
  }

  config = local.dr_link_config

  depends_on = [time_sleep.wait_for_dr_link_rbac]
}

resource "confluent_cluster_link" "secondary_to_primary" {
  link_name = "dr_link"
  link_mode = "BIDIRECTIONAL"

  local_kafka_cluster {
    id            = confluent_kafka_cluster.secondary.id
    rest_endpoint = confluent_kafka_cluster.secondary.rest_endpoint
    credentials {
      key    = confluent_api_key.dr_link_global_key.id
      secret = confluent_api_key.dr_link_global_key.secret
    }
  }

  remote_kafka_cluster {
    id                 = confluent_kafka_cluster.primary.id
    bootstrap_endpoint = confluent_kafka_cluster.primary.bootstrap_endpoint
    credentials {
      key    = confluent_api_key.dr_link_global_key.id
      secret = confluent_api_key.dr_link_global_key.secret
    }
  }

  config = local.dr_link_config

  depends_on = [time_sleep.wait_for_dr_link_rbac, confluent_cluster_link.primary_to_secondary]
}

# ---------------------------------------------------------------------------
# Verify the cluster link on both sides
# ---------------------------------------------------------------------------

data "confluent_cluster_link" "primary" {
  link_name     = confluent_cluster_link.primary_to_secondary.link_name
  rest_endpoint = confluent_kafka_cluster.primary.rest_endpoint
  kafka_cluster {
    id = confluent_kafka_cluster.primary.id
  }
  credentials {
    key    = confluent_api_key.dr_link_global_key.id
    secret = confluent_api_key.dr_link_global_key.secret
  }
}

data "confluent_cluster_link" "secondary" {
  link_name     = confluent_cluster_link.secondary_to_primary.link_name
  rest_endpoint = confluent_kafka_cluster.secondary.rest_endpoint
  kafka_cluster {
    id = confluent_kafka_cluster.secondary.id
  }
  credentials {
    key    = confluent_api_key.dr_link_global_key.id
    secret = confluent_api_key.dr_link_global_key.secret
  }
}
