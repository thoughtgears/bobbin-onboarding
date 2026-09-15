# Route 1 from ../../docs/domain-restricted-sharing.md: a tag-scoped
# exception to constraints/iam.allowedPolicyMemberDomains (domain-
# restricted sharing), narrowed to the one project being connected
# rather than the whole organisation. Four resources:
#
#   1. an org-level tag key                 (google_tags_tag_key)
#   2. one tag value under it                (google_tags_tag_value)
#   3. that value bound to var.project_id    (google_tags_tag_binding)
#   4. the policy itself, whose exception     (google_org_policy_policy)
#      rule only fires on a resource carrying that tag
#
# This is deliberately its own module, never folded into ../ (the four
# read-only VIEWER roles applied in the customer's own project). That
# module needs no organisation-level access at all; this one needs
# roles/orgpolicy.policyAdmin (or an equivalent custom role) on the
# ORGANISATION — a far larger ask, and a reviewer approving one should
# never be handed the other by accident. Read this module's README
# before running it: it changes your organisation's policy, not a
# project, and it has not been exercised against an organisation that
# enforces the constraint — see the README's "Status" section.
#
# What this module does NOT do:
#   - it never sets a provider block or a backend, same as ../.
#   - it never widens the restriction beyond var.project_id. Everything
#     outside the tagged project keeps exactly the allowlist you already
#     have (rule 2 below), unchanged.
#   - it never touches the four viewer-role grants — that is ../, a
#     separate `module` block in your root configuration.

locals {
  # The namespaced tag key name org-policy conditions reference, e.g.
  # "123456789012/bobbin" — matches Google's own documented shape for
  # resource.matchTag()'s first argument (organisation id, not
  # "organizations/<id>").
  tag_key_namespaced = "${var.organization_id}/${var.tag_key_short_name}"
}

resource "google_tags_tag_key" "bobbin" {
  parent      = "organizations/${var.organization_id}"
  short_name  = var.tag_key_short_name
  description = "Marks a project as exempted from domain-restricted sharing for Bobbin's tenant service account. Managed by the bobbin-onboarding Terraform module (terraform/org-policy-exception)."
}

resource "google_tags_tag_value" "allowed" {
  parent      = google_tags_tag_key.bobbin.id
  short_name  = var.tag_value_short_name
  description = "Bound to the one project connecting Bobbin. Removing this binding removes the exception for that project without touching the policy rule itself."
}

# Read-only; needed to bind the tag by resource name, which the Tag
# Bindings API expects in //cloudresourcemanager.googleapis.com/projects/
# <NUMBER> form — the project id alone is not accepted here.
data "google_project" "target" {
  project_id = var.project_id
}

# A project is a global resource, so no `location` is needed on the
# binding — that field is only required for regional or zonal resources
# (Google's own google_tags_tag_binding documentation).
resource "google_tags_tag_binding" "project" {
  parent    = "//cloudresourcemanager.googleapis.com/projects/${data.google_project.target.number}"
  tag_value = google_tags_tag_value.allowed.id
}

# The policy itself. THIS RESOURCE OWNS THE WHOLE POLICY OBJECT for
# constraints/iam.allowedPolicyMemberDomains at your organisation: the
# Organization Policy Service has no concept of "add one more allowed
# value" — every apply of this resource (like every `gcloud org-policies
# set-policy`) replaces the complete rule set. That is why
# var.existing_allowed_values exists and has no default: rule 2 below
# re-states it unconditionally, so your organisation's own access is
# never narrower after this module runs than before it.
#
# If a Policy object already exists at this name — likely, since you
# would not be reading this module unless your organisation already
# enforces the constraint — Terraform will not silently adopt it. Import
# it first; see the README's "Before your first plan" section.
resource "google_org_policy_policy" "domain_restricted_sharing_exception" {
  name   = "organizations/${var.organization_id}/policies/iam.allowedPolicyMemberDomains"
  parent = "organizations/${var.organization_id}"

  spec {
    # Rule 1: on a resource carrying organizations/<id>/bobbin=allowed
    # — i.e. the one tagged project — allow everything already allowed,
    # plus Bobbin's tenant service account's customer id.
    rules {
      condition {
        expression = "resource.matchTag('${local.tag_key_namespaced}', '${var.tag_value_short_name}')"
      }
      values {
        allowed_values = concat(
          var.existing_allowed_values,
          ["is:${var.bobbin_customer_id}"],
        )
      }
    }

    # Rule 2: everywhere else, exactly what was already enforced. This
    # is not optional — Google's own org-policy rule is that a policy
    # with a conditional rule and no unconditional rule cannot be
    # saved, and dropping it here would lift domain-restricted sharing
    # organisation-wide rather than narrowing it to one project.
    rules {
      values {
        allowed_values = var.existing_allowed_values
      }
    }
  }
}
