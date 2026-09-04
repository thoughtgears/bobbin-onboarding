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
