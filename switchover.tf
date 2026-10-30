# ---------------------------------------------------------------------------
# Switchover (cluster) pair
#
# Terraform creates/reads/destroys the pair and endpoint only. Failover,
# restore and failback are run with the Confluent CLI or REST API (see README).
# ---------------------------------------------------------------------------

# Pairing requires the bidirectional link to be ACTIVE on both sides; give the
# link state time to stabilize after creation.
resource "time_sleep" "wait_for_cluster_link" {
  create_duration = var.cluster_link_stabilize_duration

  depends_on = [
    confluent_cluster_link.primary_to_secondary,
    confluent_cluster_link.secondary_to_primary,
  ]
}

resource "confluent_switchover_pair" "my_cluster_pair" {
  display_name = var.pair_name

  # Only honoured at create time; afterwards the service owns it and it follows failovers.
  active_member = "primary"

  members {
    name       = "primary"
    member_crn = confluent_kafka_cluster.primary.rbac_crn
  }
  members {
    name       = "secondary"
    member_crn = confluent_kafka_cluster.secondary.rbac_crn
  }

  environment_crn = local.pair_environment_crn

  # apply blocks until the pair reaches READY_TO_FAILOVER.
  depends_on = [time_sleep.wait_for_cluster_link]
}

data "confluent_switchover_pair" "my_cluster_pair" {
  id              = confluent_switchover_pair.my_cluster_pair.id
  environment_crn = local.pair_environment_crn
}

# ---------------------------------------------------------------------------
# Switchover endpoint (public endpoint pair -> global bootstrap URL)
# ---------------------------------------------------------------------------

resource "confluent_switchover_endpoint" "my_cluster_pair_endpoint" {
  display_name        = var.endpoint_name
  parent_resource_crn = "${confluent_switchover_pair.my_cluster_pair.environment_crn}/switchover-pair=${confluent_switchover_pair.my_cluster_pair.id}"

  endpoints {
    name = "primary-ep"
    endpoint_filter {
      type = "public"
    }
  }
  endpoints {
    name = "secondary-ep"
    endpoint_filter {
      type = "public"
    }
  }
}

data "confluent_switchover_endpoint" "my_cluster_pair_endpoint" {
  id              = confluent_switchover_endpoint.my_cluster_pair_endpoint.id
  environment_crn = local.pair_environment_crn
}

locals {
  # Not returned by any API; constructed from the pair and endpoint IDs.
  global_bootstrap = "glkc-${confluent_switchover_pair.my_cluster_pair.id}-${confluent_switchover_endpoint.my_cluster_pair_endpoint.id}.global.glb.confluent.cloud:9092"
}
