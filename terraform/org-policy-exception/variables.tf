# Every input here maps onto a value this module needs to build ONE
# thing: a tag-scoped exception to constraints/iam.allowedPolicyMemberDomains,
# narrowed to a single project. Read ../org-policy-exception/README.md
# before setting any of these — this module edits your ORGANISATION's
# policy, not a project, and needs roles/orgpolicy.policyAdmin (or an
# equivalent custom role) to apply.

variable "organization_id" {
  description = <<-EOT
    Your numeric Google Cloud organisation id, e.g. 123456789012 — get it
    with `gcloud organizations list`. This module sets a policy at
    organizations/<this id>/policies/iam.allowedPolicyMemberDomains, so a
    mistyped id here would not fail loudly: at best it targets an
    organisation that does not exist and plan fails; at worst, if the
    typo happens to resolve to a REAL organisation you have access to,
    it changes THAT organisation's policy instead of yours. The
    validation below can only confirm the id is numeric — it cannot know
    which organisation is yours.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.organization_id))
    error_message = "organization_id must be the numeric organisation id from `gcloud organizations list` (e.g. 123456789012) — not a domain name, and not prefixed with \"organizations/\"."
  }
}

variable "project_id" {
  description = <<-EOT
    The one GCP project being connected to Bobbin. Only this project is
    tagged; domain-restricted sharing stays enforced, unchanged,
    everywhere else in your organisation.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project id: lowercase letters, digits and hyphens, 6-30 characters, starting with a letter and not ending with a hyphen."
  }
}

variable "existing_allowed_values" {
  description = <<-EOT
    Your organisation's CURRENT domain-restricted-sharing allowlist,
    exactly as it reads today. Get it with:

      gcloud org-policies describe iam.allowedPolicyMemberDomains \
        --organization=ORGANIZATION_ID --effective \
        --format='value(spec.rules[0].values.allowedValues)'

    There is deliberately no default and this module will not guess it
    for you. Setting an organisation policy for a list constraint
    REPLACES its entire rule set — that is how the Organization Policy
    Service works, not a choice this module makes (see the README's
    "How this actually changes your policy" section) — so a default
    here would risk silently dropping your own organisation from its
    own allowlist the first time this module ran. An empty value fails
    plan rather than doing that.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.existing_allowed_values) > 0
    error_message = "existing_allowed_values must not be empty. Read your current effective policy first (see the variable description) and pass its allowedValues here — an empty list would remove your own organisation's access, not just narrow it."
  }

  validation {
    condition = alltrue([
      for value in var.existing_allowed_values :
      can(regex("^(is:)?(C[0-9A-Za-z]+|principalSet://.+)$", value))
    ])
    error_message = "each value in existing_allowed_values must look like a Google Workspace customer id (C…, optionally \"is:\"-prefixed) or an organisation principal set (…principalSet://…) — the same shapes `gcloud org-policies describe --effective` returns."
  }
}

variable "bobbin_customer_id" {
  description = <<-EOT
    Bobbin's Cloud Identity customer id — the value this module adds to
    your allowlist, conditional on the tag it creates. Defaults to the
    id current as of this module's v0.3.0 release. Override only if
    Bobbin tells you it has changed; we will say so loudly if it ever
    does, since every customer using Route 1 depends on it.
  EOT
  type        = string
  default     = "C015nrtrj"

  validation {
    condition     = can(regex("^C[0-9A-Za-z]+$", var.bobbin_customer_id))
    error_message = "bobbin_customer_id must look like a Google Workspace customer id, e.g. C015nrtrj."
  }
}

variable "tag_key_short_name" {
  description = <<-EOT
    Short name for the organisation-level tag key this module creates.
    The default is deliberately plain — change it only if "bobbin"
    already names something else in your tag namespace.
  EOT
  type        = string
  default     = "bobbin"
}

variable "tag_value_short_name" {
  description = <<-EOT
    Short name for the tag value bound to var.project_id. Change it only
    if you want a different value under the same key for your own
    purposes — the module does not depend on this string beyond using it
    consistently between the binding and the policy condition.
  EOT
  type        = string
  default     = "allowed"
}
