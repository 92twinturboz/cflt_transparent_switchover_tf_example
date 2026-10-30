# ---------------------------------------------------------------------------
# Sample producer/consumer identity
#
# Clients must authenticate with a Global API key or OAuth (cluster-scoped keys
# cannot fail over). Pass client_principal_id to reuse an existing service
# account or identity pool; otherwise one is created here with a Global API key.
# ---------------------------------------------------------------------------

locals {
  create_client = var.client_principal_id == null
  client_principal_id = (
    local.create_client ? confluent_service_account.client[0].id : var.client_principal_id
  )

  # RBAC is not synced by the cluster link, so every binding is made on both clusters.
  clusters = {
    primary   = confluent_kafka_cluster.primary
    secondary = confluent_kafka_cluster.secondary
  }
}

resource "confluent_service_account" "client" {
  count = local.create_client ? 1 : 0

  display_name = "dr-demo-client-sa"
  description  = "Sample producer/consumer for the DR pair"
}

resource "confluent_api_key" "client_global_key" {
  count = local.create_client ? 1 : 0

  display_name = "dr-demo-client global key"
  description  = "Global API key for the sample producer/consumer"

  owner {
    id          = confluent_service_account.client[0].id
    api_version = confluent_service_account.client[0].api_version
    kind        = confluent_service_account.client[0].kind
  }

  managed_resource {
    id          = "global"
    api_version = "global/v1"
    kind        = "Global"
  }
}

resource "confluent_role_binding" "client_write_topic" {
  for_each = local.clusters

  principal   = "User:${local.client_principal_id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${each.value.rbac_crn}/kafka=${each.value.id}/topic=${var.topic_name}"
}

resource "confluent_role_binding" "client_read_topic" {
  for_each = local.clusters

  principal   = "User:${local.client_principal_id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${each.value.rbac_crn}/kafka=${each.value.id}/topic=${var.topic_name}"
}

resource "confluent_role_binding" "client_read_group" {
  for_each = local.clusters

  principal   = "User:${local.client_principal_id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${each.value.rbac_crn}/kafka=${each.value.id}/group=${var.consumer_group}"
}

# Ready-to-use client config pointing at the global bootstrap URL.
resource "local_sensitive_file" "client_properties" {
  count = local.create_client ? 1 : 0

  filename        = "${path.module}/client.properties"
  file_permission = "0600"
  content         = <<-EOT
    bootstrap.servers=${local.global_bootstrap}
    metadata.recovery.strategy=rebootstrap
    # Lets producers detect an unplanned failover sooner (default 300000).
    metadata.recovery.rebootstrap.trigger.ms=30000

    security.protocol=SASL_SSL
    sasl.mechanism=PLAIN
    sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username='${confluent_api_key.client_global_key[0].id}' password='${confluent_api_key.client_global_key[0].secret}';

    # Consumer
    group.id=${var.consumer_group}
  EOT
}
