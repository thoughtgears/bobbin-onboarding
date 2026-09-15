output "tag_key_namespaced_name" {
  description = "The tag key this module created, e.g. \"123456789012/bobbin\". For your own verification, and for binding the same tag to another project by hand later without re-running this module."
  value       = google_tags_tag_key.bobbin.namespaced_name
}

output "tag_value_namespaced_name" {
  description = "The tag value bound to var.project_id, e.g. \"123456789012/bobbin/allowed\"."
  value       = google_tags_tag_value.allowed.namespaced_name
}

output "policy_name" {
  description = "The full resource name of the policy object this module manages, e.g. \"organizations/123456789012/policies/iam.allowedPolicyMemberDomains\". Fetch it with `gcloud org-policies describe iam.allowedPolicyMemberDomains --organization=<id> --effective` to confirm what is actually enforced."
  value       = google_org_policy_policy.domain_restricted_sharing_exception.name
}

output "allowed_values_on_tagged_project" {
  description = "The complete allowlist that applies to the tagged project once this policy takes effect (existing values plus Bobbin's customer id) — for you to check against what you expected before trusting the exception."
  value       = concat(var.existing_allowed_values, ["is:${var.bobbin_customer_id}"])
}
