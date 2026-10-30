variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API key (cloud resource management scope) used by Terraform"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API secret used by Terraform"
  type        = string
  sensitive   = true
}

variable "org" {
  description = "Confluent Cloud organization ID. Looked up from the API credentials when null."
  type        = string
  default     = null
}

variable "primary_env_name" {
  description = "Name of the environment created for the primary cluster."
  type        = string
  default     = "east-env"
}

variable "secondary_env_name" {
  description = "Name of the environment created for the secondary (DR) cluster."
  type        = string
  default     = "west-env"
}

variable "pair_env" {
  description = "Environment ID hosting the switchover pair and endpoint. Defaults to the primary environment."
  type        = string
  default     = null
}

variable "cloud" {
  description = "Cloud provider for both clusters."
  type        = string
  default     = "AWS"
}

variable "primary_region" {
  description = "Region of the primary cluster."
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Region of the secondary (DR) cluster."
  type        = string
  default     = "us-west-2"
}

variable "cku" {
  description = "CKUs for each Dedicated cluster. Keep both clusters the same size."
  type        = number
  default     = 2
}

variable "primary_cluster_name" {
  type    = string
  default = "my-primary-cluster"
}

variable "secondary_cluster_name" {
  type    = string
  default = "my-secondary-cluster"
}

variable "link_name" {
  type    = string
  default = "dr-link"
}

variable "pair_name" {
  type    = string
  default = "my-cluster-pair"
}

variable "endpoint_name" {
  type    = string
  default = "my-cluster-pair-endpoint"
}

variable "topic_name" {
  type    = string
  default = "purchases"
}

variable "topic_partitions" {
  type    = number
  default = 6
}

variable "consumer_group" {
  description = "Consumer group the sample client is authorized to use."
  type        = string
  default     = "dr-demo-consumer"
}

variable "client_principal_id" {
  description = <<-EOT
    Existing client principal: a service account (sa-xxxxx) or identity pool (pool-xxxxx).
    When null, a service account and a Global API key are created for the sample clients.
  EOT
  type        = string
  default     = null
}

variable "verify_mirror_topic" {
  description = <<-EOT
    Look up the mirror topic on the secondary cluster. Auto-create runs about every five
    minutes, so leave false on the first apply and set true afterwards.
  EOT
  type        = bool
  default     = false
}

variable "cluster_link_stabilize_duration" {
  description = "How long to wait after creating the cluster links before creating the switchover pair (time_sleep duration, e.g. \"60s\", \"2m\")."
  type        = string
  default     = "360s"
}
