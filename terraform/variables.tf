# Every input here maps directly onto a value the doc and the script also
# ask for — see ../docs/granting-access.md. Nothing is inferred and
# nothing has a default that grants access on your behalf.

variable "tenant_service_account" {
  description = <<-EOT
    The service account Bobbin gave you during onboarding, e.g.
    tenant-acme-prod@bobbin-shard-N.iam.gserviceaccount.com. This is the
    ONLY principal these resources ever grant anything to.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.iam\\.gserviceaccount\\.com$", var.tenant_service_account))
    error_message = "tenant_service_account must look like a service account, e.g. tenant-acme-prod@bobbin-shard-N.iam.gserviceaccount.com."
  }
}

variable "tenant_topic" {
  description = <<-EOT
    Your alert intake topic, as the full resource path Bobbin gave you,
    e.g. projects/bobbin-hub-N/topics/tenant-acme-prod-alerts. Only the
    notification channel's label points at this — nothing in this module
    grants access to the topic itself, on either side.
  EOT
  type        = string

  validation {
    condition     = can(regex("^projects/[^/]+/topics/[^/]+$", var.tenant_topic))
    error_message = "tenant_topic must be a full path (projects/PROJECT/topics/TOPIC), e.g. projects/bobbin-hub-N/topics/tenant-acme-prod-alerts."
  }
}

variable "project_ids" {
  description = <<-EOT
    The GCP projects Bobbin should be able to investigate. One set of
    grants (the four roles) and one notification channel are created per
    project — the same shape as running grant-bobbin-access.sh once per
    project id.
  EOT
  type        = set(string)

  validation {
    condition     = length(var.project_ids) > 0
    error_message = "project_ids must contain at least one project id."
  }
}

variable "channel_display_name" {
  description = "Display name for the Cloud Monitoring notification channel."
  type        = string
  default     = "Bobbin (@bobby)"
}

variable "families" {
  description = <<-EOT
    Optional. The services whose SETTINGS Bobbin may read as well as
    their telemetry — one custom, read-only role per family, defined in
    each project and bound to tenant_service_account. Empty (the default)
    applies exactly the four roles above and nothing else. Each family
    maps to one role holding exactly the get/list permissions the
    product's tool calls (see local.family_roles in main.tf):
      managed-sql -> bobbinManagedSqlConfigViewer  (Cloud SQL settings and flags)
      cache       -> bobbinCacheConfigViewer       (Memorystore settings)
      kubernetes  -> bobbinKubernetesConfigViewer  (GKE cluster settings from the GKE API — never the cluster)
      compute     -> bobbinComputeConfigViewer     (Compute Engine instance and group settings)
      networking  -> bobbinNetworkingConfigViewer  (load balancer backend health and configuration)
    Defining a role needs iam.roles.create on the project.
  EOT
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for family in var.families :
      contains(["managed-sql", "cache", "kubernetes", "compute", "networking"], family)
    ])
    error_message = "families must be a subset of: managed-sql, cache, kubernetes, compute, networking."
  }
}
