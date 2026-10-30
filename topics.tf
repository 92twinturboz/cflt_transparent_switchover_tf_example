# Created on the primary only; the cluster link auto-creates the mirror on the secondary.
resource "confluent_kafka_topic" "purchases_primary" {
  kafka_cluster {
    id = confluent_kafka_cluster.primary.id
  }

  topic_name       = var.topic_name
  partitions_count = var.topic_partitions
  rest_endpoint    = confluent_kafka_cluster.primary.rest_endpoint

  credentials {
    key    = confluent_api_key.dr_link_global_key.id
    secret = confluent_api_key.dr_link_global_key.secret
  }

  depends_on = [
    confluent_cluster_link.primary_to_secondary,
    confluent_cluster_link.secondary_to_primary,
  ]
}

# Fails if the mirror topic doesn't exist yet, hence gated behind verify_mirror_topic.
data "confluent_kafka_topic" "purchases_secondary" {
  count = var.verify_mirror_topic ? 1 : 0

  kafka_cluster {
    id = confluent_kafka_cluster.secondary.id
  }

  topic_name    = confluent_kafka_topic.purchases_primary.topic_name
  rest_endpoint = confluent_kafka_cluster.secondary.rest_endpoint

  credentials {
    key    = confluent_api_key.dr_link_global_key.id
    secret = confluent_api_key.dr_link_global_key.secret
  }
}
