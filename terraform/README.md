# Terraform module

The Terraform-native way to apply Bobbin's access grants — the same
grants as [`../docs/granting-access.md`](../docs/granting-access.md) and
[`../grant-bobbin-access.sh`](../grant-bobbin-access.sh), no more.
Read the doc first: it is the spec, and this module is a mechanical
rendering of it, not a separate decision about what Bobbin gets.

## What it applies

On every project you list, this module:

1. grants `tenant_service_account` the four read-only roles below
2. creates one Pub/Sub-type Cloud Monitoring notification channel
   labelled with `tenant_topic`

| Role | What it reads |
| --- | --- |
| `roles/logging.viewer` | Log entries |
| `roles/monitoring.viewer` | Metrics and alert policies |
| `roles/errorreporting.viewer` | Error groups |
| `roles/run.viewer` | Cloud Run service and revision configuration |

That is the complete list — this module never requests, and never
grants, anything beyond it. It also never touches the tenant topic's own
IAM policy: granting your projects' Cloud Monitoring service agent
publish rights on that topic happens on Bobbin's side, against our hub
project, once you send us the `project_numbers` output below. A
customer's Terraform run has no access to grant that even if this module
tried to.

## Usage

```hcl
module "bobbin" {
  source = "github.com/thoughtgears/bobbin-onboarding//terraform?ref=v0.1.0"

  tenant_service_account = "tenant-acme-prod@bobbin-shard-N.iam.gserviceaccount.com"
  tenant_topic           = "projects/bobbin-hub-N/topics/tenant-acme-prod-alerts"
  project_ids            = ["my-production-project"]
}

output "bobbin_project_numbers" {
  value = module.bobbin.project_numbers
}
```

Pin `ref` to a tag (see [`../CHANGELOG.md`](../CHANGELOG.md) for what
changed at each one) rather than tracking a branch, so an upstream change
never lands in your plan unannounced.

A working, minimal root module is in
[`../examples/single-project`](../examples/single-project).

## Inputs

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `tenant_service_account` | `string` | yes | The service account Bobbin gave you, e.g. `tenant-acme-prod@bobbin-shard-N.iam.gserviceaccount.com`. The only principal these resources ever grant anything to. Validated against that shape. |
| `tenant_topic` | `string` | yes | Your alert intake topic as a full resource path, e.g. `projects/bobbin-hub-N/topics/tenant-acme-prod-alerts`. Validated against that shape. |
| `project_ids` | `set(string)` | yes | The GCP projects Bobbin should investigate. One set of grants and one notification channel are created per project. |
| `channel_display_name` | `string` | no | Notification channel display name. Defaults to `"Bobbin (@bobby)"`, matching the doc and the script. |

## Outputs

| Name | Description |
| --- | --- |
| `notification_channel_ids` | Map of `project_id => notification channel resource name` (`projects/<id>/notificationChannels/<n>`). Attach these to the alert policies you want investigated. |
| `granted_roles` | The exact four roles granted — the complete access list, for your own verification. |
| `project_numbers` | Map of `project_id => project number`. Send these to Bobbin: see "What it applies" above. |

## The known gotcha: domain-restricted sharing

If your org enforces `iam.allowedPolicyMemberDomains`, `apply` fails on
the first `google_project_iam_member` with a `FAILED_PRECONDITION` error
that does not mention the policy by name. This is the same failure the
script and the doc describe, just surfaced by Terraform instead of
`gcloud`.

Add a conditional exception for the Bobbin org (ask us for the org id)
or a project-level override, then `apply` again — the resources are
idempotent, so re-running picks up exactly where it stopped.
[Google's docs](https://cloud.google.com/resource-manager/docs/organization-policy/restricting-domains).

We deliberately do not ask this module to pre-check the policy, for the
same reason the script does not: reading it needs the Org Policy API
enabled, and the customer most likely to hit this — one project, no org
access — is also the one least able to enable it safely.

## Removing Bobbin

```bash
terraform destroy
```

The exact reverse of `apply`: it removes the four role bindings and
deletes the notification channel. The channel resource is configured
with `force_delete = true` for the same reason
`revoke-bobbin-access.sh` always deletes with `--force`: Cloud Monitoring
refuses to delete a channel still referenced by an alert policy, and the
policies referencing it are the customer's own. `force_delete` deletes
the channel and unlinks it from those policies; the policies survive and
keep firing, just with one fewer notification target — which is what
removing Bobbin means. Your alert policies themselves are never touched.

You do not have to run this for your data to be deleted. Our side of the
teardown — the service account that could read your projects, your
stored credentials, your investigation history — runs on our schedule
and does not wait for you. `terraform destroy` removes the permissions
you granted; ours removes the identity they were granted to. Either
alone stops Bobbin reading anything.

## Registry

This module is not published to the Terraform Registry. Registry listing
needs a repo named `terraform-google-bobbin-onboarding`; the decision as
of this module's first version is one public repo holding all three
onboarding paths (doc, script, module), sourced from GitHub as shown
above. Registry publication is deferred, not ruled out — extracting this
directory into its own repo later is a rename plus a tag, not a rewrite.
