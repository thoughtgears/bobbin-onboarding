# Applies exactly the grants in ../docs/granting-access.md and
# ../grant-bobbin-access.sh — no more. Read those first; this module is
# the third rendering of the same steps (ADR-0003 in the product repo),
# not a different decision about what Bobbin gets.
#
# What this module does NOT do, deliberately:
#   - it never touches the tenant topic's IAM policy. Granting the
#     customer's Cloud Monitoring service agent publish rights on that
#     topic happens on Bobbin's side, against Bobbin's own hub project,
#     once you send us the project number (see the "project_numbers"
#     output) — a customer's Terraform run has no access to grant that
#     even if it tried.
#   - it never sets a provider block or a backend. This is a module, not
#     a root config: your own root module supplies the google provider,
#     exactly as examples/single-project does.

locals {
  # The complete access list. Four Google-managed, read-only roles —
  # matching grant-bobbin-access.sh's ROLES array precisely.
  roles = [
    "roles/logging.viewer",
    "roles/monitoring.viewer",
    "roles/errorreporting.viewer",
    "roles/run.viewer",
  ]

  # One binding per (project, role) pair, keyed so a change to one
  # project or one role never forces a diff on any other.
  project_role_bindings = {
    for pair in setproduct(var.project_ids, local.roles) :
    "${pair[0]}/${pair[1]}" => {
      project_id = pair[0]
      role       = pair[1]
    }
  }
}

# Additive per-member bindings, not authoritative role bindings — the
# same shape as `gcloud projects add-iam-policy-binding`. This never
# removes another principal already holding one of these four roles,
# which an authoritative `google_project_iam_binding` would.
resource "google_project_iam_member" "bobbin_viewer" {
  for_each = local.project_role_bindings

  project = each.value.project_id
  role    = each.value.role
  member  = "serviceAccount:${var.tenant_service_account}"

  # `--condition=None` in the script and the doc means "no IAM
  # condition" — the default for this resource when condition is unset.
}

# Step 2 of the doc/script: one Pub/Sub-type notification channel per
# project, pointing at the tenant topic. Terraform's own idempotency is
# the equivalent of the script's "does one already exist" check — a
# second `apply` updates this resource in place rather than creating a
# second channel, so there is nothing extra to guard here.
resource "google_monitoring_notification_channel" "bobbin" {
  for_each = var.project_ids

  project      = each.value
  display_name = var.channel_display_name
  type         = "pubsub"

  labels = {
    topic = var.tenant_topic
  }

  # revoke-bobbin-access.sh always deletes with --force: a channel
  # cannot be deleted while an alert policy still references it, and the
  # policies referencing it are the customer's own — left alone, only
  # unlinked. `terraform destroy` needs the same permission to be the
  # exact reverse of `apply` rather than leaving the one thing removal
  # exists to remove.
  force_delete = true
}

# Read-only; needed only to hand you the same project numbers the script
# prints at the end of its run, which you still send to us by hand (see
# the module README's "one thing left" section).
data "google_project" "target" {
  for_each   = var.project_ids
  project_id = each.value
}
