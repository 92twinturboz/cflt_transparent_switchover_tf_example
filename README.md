# Cluster Linking Automatic Failover (EA) – Terraform

Terraform implementation of the Confluent Cloud
[Cluster Linking Automatic Failover tutorial](https://docs.confluent.io/cloud/current/multi-cloud/cluster-linking/dr-automatic-failover-tutorial.html)
for an active-passive DR setup.

> Automatic Failover is an **Early Access** feature. Your org must be enrolled before the
> switchover pair/endpoint resources work.

## What gets created

| File | Resources |
|---|---|
| `main.tf` | `east-env` and `west-env` environments; primary (`us-east-1`, in `east-env`) and secondary (`us-west-2`, in `west-env`) Dedicated, multi-zone, 2-CKU clusters |
| `cluster_link.tf` | `dr-link-sa` service account, `CloudClusterAdmin` on both clusters, Global API key, bidirectional `dr-link` (one resource per direction), link status lookups |
| `switchover.tf` | `my-cluster-pair` switchover pair, public `my-cluster-pair-endpoint`, status lookups, global bootstrap URL |
| `topics.tf` | `purchases` topic on the primary, optional mirror-topic lookup on the secondary |
| `clients.tf` | Client service account + Global API key (unless you pass `client_principal_id`), `DeveloperWrite`/`DeveloperRead` on the topic and `DeveloperRead` on the `dr-demo-consumer` group on **both** clusters, and a generated `client.properties` |

Two Dedicated 2-CKU clusters are billed hourly. Run `terraform destroy` when you're done (see [Teardown](#teardown)).

## Prerequisites

- Terraform >= 1.5, Confluent CLI >= 4.78.0 (to run failover, restore and failback)
- A Cloud API key (Cloud Resource Management or Global scope) owned by an OrganizationAdmin or EnvironmentAdmin
- The API key's owner must be an OrganizationAdmin to create the environments

```bash
export CONFLUENT_CLOUD_API_KEY=...
export CONFLUENT_CLOUD_API_SECRET=...
cp terraform.tfvars.example terraform.tfvars   # optional: every variable has a default
```

## Set up

```bash
terraform init
terraform apply
```

A single apply creates everything in dependency order: environments, clusters, link identity, cluster links,
switchover pair (the apply waits until it reaches `READY_TO_FAILOVER`), endpoint, topic and client
bindings. A 30s pause after the link role bindings gives them time to propagate, and a 60s pause
after the cluster links lets the link state settle before pairing (tune with `cluster_link_stabilize_duration`).

After about five minutes, the cluster link auto-creates the `purchases` mirror topic on the secondary. To confirm it exists:

```bash
terraform apply -var verify_mirror_topic=true
```

(or set `verify_mirror_topic = true` in `terraform.tfvars`).

Useful outputs:

```bash
terraform output global_bootstrap        # glkc-<sw>-<se>.global.glb.confluent.cloud:9092
terraform output cluster_link_state
terraform output pair_phase
terraform output endpoint_target
```

## Run the sample clients

When Terraform creates the client identity, it writes `client.properties` (mode 0600, git-ignored) with the global
bootstrap URL, `metadata.recovery.strategy=rebootstrap`, a 30s rebootstrap trigger, the
client's Global API key and `group.id=dr-demo-consumer`. Point the
[Java sample client](https://developer.confluent.io/get-started/java/) (or any Kafka 4.0+ client) at it
and run a producer and consumer in separate terminals.

If you bring your own principal (`client_principal_id`, a service account or OAuth identity pool), Terraform
only creates the role bindings. Build the client config yourself from the `global_bootstrap` output.

## Fail over, restore, fail back (CLI)

Terraform can't trigger these operations. Use the CLI:

```bash
SW=$(terraform output -raw switchover_pair_id)
PAIR_ENV=$(terraform output -raw pair_env)

# Planned failover to the secondary
confluent switchover pair failover $SW --active-member secondary --failover-type PLANNED --environment $PAIR_ENV

# ...or an unplanned failover (primary unavailable)
confluent switchover pair failover $SW --active-member secondary --failover-type UNPLANNED --environment $PAIR_ENV

# After an UNPLANNED failover only: restore the original primary (truncates unreplicated data!)
confluent switchover pair failover $SW --failover-type RESTORE --environment $PAIR_ENV

# Fail back to the primary
confluent switchover pair failover $SW --active-member primary --failover-type PLANNED --environment $PAIR_ENV
```

Add `--force` to skip the confirmation prompt in scripts. Run `terraform apply -refresh-only` and check the
`pair_active_member` and `endpoint_target` outputs to confirm where the pair points.

Notes:
- After creation, the switchover service owns `active_member`, so a failover doesn't show up as drift.
- Only `display_name` can change in place on the pair and endpoint. To change members, endpoints or
  CRNs, run `terraform apply -replace=...`.
- Monitor mirror lag with
  `confluent kafka mirror describe purchases --link dr-link --cluster $(terraform output -json secondary_cluster | jq -r .id) --environment $(terraform output -raw secondary_env)`.

## Teardown

1. Remove the `lifecycle { prevent_destroy = true }` block from
   `confluent_api_key.dr_link_global_key` in `cluster_link.tf`.
2. Destroy the endpoint and pair first. If deleting the pair right after the endpoint fails, retry:
   ```bash
   terraform destroy \
     -target=confluent_switchover_endpoint.my_cluster_pair_endpoint \
     -target=confluent_switchover_pair.my_cluster_pair
   ```
3. Destroy the rest, including the `east-env` and `west-env` environments:
   ```bash
   terraform destroy
   ```
