variable "project_id" {
  description = "The GCP project Bobbin should investigate."
  type        = string
}

variable "tenant_service_account" {
  description = "The service account Bobbin gave you during onboarding."
  type        = string
}

variable "tenant_topic" {
  description = "Your alert intake topic, as the full resource path Bobbin gave you."
  type        = string
}
