output "primary_env" {
  value = confluent_environment.primary.id
}

output "secondary_env" {
  value = confluent_environment.secondary.id
}

output "primary_cluster" {
  value = {
    id                 = confluent_kafka_cluster.primary.id
    crn                = confluent_kafka_cluster.primary.rbac_crn
    bootstrap_endpoint = confluent_kafka_cluster.primary.bootstrap_endpoint
    rest_endpoint      = confluent_kafka_cluster.primary.rest_endpoint
  }
}

output "secondary_cluster" {
  value = {
    id                 = confluent_kafka_cluster.secondary.id
    crn                = confluent_kafka_cluster.secondary.rbac_crn
    bootstrap_endpoint = confluent_kafka_cluster.secondary.bootstrap_endpoint
    rest_endpoint      = confluent_kafka_cluster.secondary.rest_endpoint
  }
}

output "cluster_link_state" {
  value = {
    primary   = data.confluent_cluster_link.primary.link_state
    secondary = data.confluent_cluster_link.secondary.link_state
  }
}

output "switchover_pair_id" {
  description = "$SW in the tutorial."
  value       = confluent_switchover_pair.my_cluster_pair.id
}

output "switchover_endpoint_id" {
  description = "$SE in the tutorial."
  value       = confluent_switchover_endpoint.my_cluster_pair_endpoint.id
}

output "pair_env" {
  description = "$PAIR_ENV in the tutorial."
  value       = local.pair_env
}

output "pair_phase" {
  value = data.confluent_switchover_pair.my_cluster_pair.phase
}

output "pair_active_member" {
  value = data.confluent_switchover_pair.my_cluster_pair.active_member
}

output "endpoint_target" {
  value = data.confluent_switchover_endpoint.my_cluster_pair_endpoint.target
}

output "global_bootstrap" {
  description = "Give this to producers and consumers instead of a cluster bootstrap."
  value       = local.global_bootstrap
}

output "purchases_mirror_topic_config" {
  value = var.verify_mirror_topic ? data.confluent_kafka_topic.purchases_secondary[0].config : null
}

output "client_principal_id" {
  value = local.client_principal_id
}

output "client_api_key" {
  value = local.create_client ? confluent_api_key.client_global_key[0].id : null
}

output "client_api_secret" {
  value     = local.create_client ? confluent_api_key.client_global_key[0].secret : null
  sensitive = true
}

output "cluster_link_api_key" {
  description = "$CL_API_KEY in the tutorial."
  value       = confluent_api_key.dr_link_global_key.id
}

output "cluster_link_api_secret" {
  value     = confluent_api_key.dr_link_global_key.secret
  sensitive = true
}
