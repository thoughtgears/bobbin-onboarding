# Terraform module: organisation policy exception (optional)

**This module changes your organisation's policy, not a project.** It
sets a tag-scoped exception to `constraints/iam.allowedPolicyMemberDomains`
(domain-restricted sharing) so Bobbin's tenant service account — which
lives in our project, not yours — can be granted the four viewer roles
on the one project you name, without weakening the restriction anywhere
else in your organisation. It needs `roles/orgpolicy.policyAdmin`
(Google's "Organization Policy Administrator" predefined role — or an
equivalent custom role) on the **organisation**, which is a far
larger ask than [`../`](../) — the module that applies the four viewer
roles themselves needs no organisation-level access at all. That is why
this is its own module and will never be folded into that one: a
reviewer approving the narrow grant should never be handed the wide one
by accident.

You only need this at all if your organisation enforces
[domain-restricted sharing](https://cloud.google.com/resource-manager/docs/organization-policy/restricting-domains)
and you hit `FAILED_PRECONDITION` granting the four roles. Most
organisations do not enforce it, and if yours does not, none of this
applies to you — skip straight to [`../`](../).

**You can do this by hand instead — see "By hand" below.** This module
is a mechanical rendering of the same four resources, for the reasons
[`../README.md`](../README.md) gives for the sibling module: four
resources are easy to get one wrong by hand, and this one edits
organisation policy where a mistake is more consequential than a
project-scoped IAM grant.

## Status

**This has not been run against an organisation that enforces the
constraint.** Our own organisation has it at `ALLOW`, so it could not be
exercised. The commands and resources follow Google's documented
behaviour. Route 2 (the allowlist) is the known-good fallback if Route 1
does not work for you.

Spelled out rather than left at that one paragraph: `terraform apply`
has not been run against a real `iam.allowedPolicyMemberDomains` policy,
and the failure modes described elsewhere in this README are reasoned
from Google's documentation, not observed. "Documented" and "tested by
us" are not the same claim, and this README does not make the second
one anywhere.
[Route 2](../../docs/domain-restricted-sharing.md#route-2-add-bobbin-to-the-allowlist-simpler-org-wide)
— the allowlist — is one policy value, not four resources, and simpler
to unwind by hand if something about your organisation's existing
policy does not match what this module assumes.

## What it applies

On your organisation:

1. an org-level tag key (`organizations/<id>/<tag_key_short_name>`,
   default short name `bobbin`)
2. one tag value under it (default short name `allowed`)
3. that value bound to `var.project_id` — and only that project
4. a policy for `constraints/iam.allowedPolicyMemberDomains` with two
   rules: one that applies **only** to a resource carrying the tag
   (your existing allowlist plus Bobbin's customer id), and one that
   applies to everything else (your existing allowlist, unchanged)

That is the complete list. This module never grants an IAM role itself
— [`../`](../) does that, against the project, once this exception
makes the grant possible.

## How this actually changes your policy

The Organization Policy Service has no "add one more allowed value"
operation. Every `gcloud org-policies set-policy` — and every apply of
the `google_org_policy_policy` resource this module uses — **replaces
the entire rule set** for that constraint at that organisation. There is
no partial update.

That has one direct consequence for you: **this module needs to know
your organisation's current allowlist before it can write a new one
that includes it.** That is `var.existing_allowed_values`, and it has no
default on purpose — a default would either invent a value (wrong) or
start empty (which would replace your policy with one that allows
nothing but Bobbin, on the tagged project, and nothing at all
everywhere else — the opposite of "narrow exception"). Read your current
value first:

```bash
gcloud org-policies describe iam.allowedPolicyMemberDomains \
  --organization=ORGANIZATION_ID --effective \
  --format='value(spec.rules[0].values.allowedValues)'
```

and pass what it prints as `existing_allowed_values`. The module's own
`validation` block rejects an empty list rather than silently narrowing
your organisation's own access to nothing.

## Before your first `plan`

If your organisation was created on or after 3 May 2024, Google enforces
`iam.allowedPolicyMemberDomains` by default with your domain as the only
allowed value — and if you are reading this, some Policy object for this
constraint almost certainly already exists at your organisation, whether
Google created it by default or an admin set it explicitly. Terraform
will not adopt an existing resource on `apply`; it will fail claiming
the policy already exists. Import it first:

```bash
terraform import google_org_policy_policy.domain_restricted_sharing_exception \
  "organizations/ORGANIZATION_ID/policies/iam.allowedPolicyMemberDomains"
```

then run `plan` and read the diff carefully before `apply` — it should
show your existing allowlist preserved in rule 2 and the new conditional
rule 1 added, and nothing else changing. **We have not exercised this
import step ourselves** (see "Status" above); if `plan` after importing
shows anything other than "add one conditional rule, leave the rest
alone", stop and read the diff rather than applying it.

## Usage

```hcl
module "bobbin_org_policy_exception" {
  source = "github.com/thoughtgears/bobbin-onboarding//terraform/org-policy-exception?ref=v0.3.0"

  organization_id         = "123456789012"
  project_id               = "my-production-project"
  existing_allowed_values  = ["is:C0xxxxxxx"] # from the `describe --effective` command above
}
```

**Pin `ref` to a tag rather than tracking a branch**, exactly as
[`../README.md`](../README.md#usage) says for the sibling module —
`v0.3.0` is the first release this module ships in;
[`../../CHANGELOG.md`](../../CHANGELOG.md) says what changed at each tag.

There is no `examples/` root module for this one. Given "Status" above,
we did not want a copy-paste example implying a working reference run —
the usage block is complete on its own.

## Inputs

| Name                     | Type           | Required | Description                                                                                                                                             |
| ------------------------ | -------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `organization_id`        | `string`       | yes      | Your numeric organisation id (`gcloud organizations list`). Validated as numeric only — see `variables.tf` for why a typo here is not fully caught.      |
| `project_id`              | `string`       | yes      | The one project being connected. Validated against GCP's project id shape.                                                                             |
| `existing_allowed_values` | `list(string)` | yes      | Your organisation's current domain-restricted-sharing allowlist, exactly as it reads today. No default — see "How this actually changes your policy". |
| `bobbin_customer_id`      | `string`       | no       | Bobbin's Cloud Identity customer id. Default `C015nrtrj`, current as of this module's v0.3.0 release.                                                  |
| `tag_key_short_name`      | `string`       | no       | Default `bobbin`. Change only if that name already means something else in your tag namespace.                                                         |
| `tag_value_short_name`    | `string`       | no       | Default `allowed`.                                                                                                                                      |

## Outputs

| Name                             | Description                                                                        |
| -------------------------------- | ----------------------------------------------------------------------------------- |
| `tag_key_namespaced_name`        | The created tag key, e.g. `123456789012/bobbin`.                                    |
| `tag_value_namespaced_name`      | The tag value bound to `project_id`, e.g. `123456789012/bobbin/allowed`.            |
| `policy_name`                    | The policy object's full resource name, for `gcloud org-policies describe`.         |
| `allowed_values_on_tagged_project` | The complete allowlist that applies to the tagged project — check it against what you expected. |

## By hand

The same four resources, as `gcloud` commands — if you would rather not
grant this module `orgpolicy.policyAdmin`, or want to see exactly what
it would do before running it:

```bash
gcloud resource-manager tags keys create bobbin \
  --parent "organizations/ORGANIZATION_ID"

gcloud resource-manager tags values create allowed \
  --parent "ORGANIZATION_ID/bobbin"

gcloud resource-manager tags bindings create \
  --tag-value "ORGANIZATION_ID/bobbin/allowed" \
  --parent "//cloudresourcemanager.googleapis.com/projects/PROJECT_ID"
```

Then, having read your current allowlist as shown above, write
`exception.yaml`:

```yaml
name: organizations/ORGANIZATION_ID/policies/iam.allowedPolicyMemberDomains
spec:
  rules:
    - condition:
        expression: "resource.matchTag('ORGANIZATION_ID/bobbin', 'allowed')"
      values:
        allowedValues:
          - is:YOUR_EXISTING_VALUE # repeat one line per existing value
          - is:C015nrtrj # Bobbin's customer id
    - values:
        allowedValues:
          - is:YOUR_EXISTING_VALUE # the same existing values, unconditional
```

and apply it:

```bash
gcloud org-policies set-policy exception.yaml
```

**Success looks like:**

```bash
gcloud org-policies describe iam.allowedPolicyMemberDomains \
  --organization=ORGANIZATION_ID --effective
```

showing both rules, and re-running the grant (the script, the doc, or
[`../`](../)) against `PROJECT_ID` no longer failing with
`FAILED_PRECONDITION`.

## Removing the exception

```bash
terraform destroy
```

removes the tag binding, the tag value, the tag key, and the policy
object itself. Deleting the policy object reverts your organisation to
whatever applies with no explicit override at that level — for an
organisation created on or after 3 May 2024 with no other customisation,
that is Google's own default (your domain only), which is the outcome
you want. **We have not verified this for an organisation whose
domain-restricted-sharing policy was customised beyond the default**
(a different allowlist, a policy inherited from a folder, or one set
before this module ever ran) — in that case, deleting the policy object
might revert further than "back to how it was before this module",
rather than to your organisation's actual prior state. Run the
`describe --effective` command above after `destroy` and check it
against what you expect before considering the exception fully removed.

This module never touches the four viewer-role grants
([`../`](../) does, on `terraform destroy` there) or Bobbin's own side
of the teardown — see [`../README.md#removing-bobbin`](../README.md#removing-bobbin)
for what removes what.

## What we verified

Against Google's current Organization Policy documentation
(`cloud.google.com/resource-manager/docs/organization-policy/restricting-domains`,
fetched 2026-09-15):

- `iam.allowedPolicyMemberDomains` is a **legacy managed, list-type**
  constraint. It does not support `denyAll` or denied values — only
  `allowedValues`. **This is why this module's policy resource never
  uses `allowAll`/`denyAll`**: Google's own worked example for this
  exact constraint uses a conditional `values.allowedValues` rule plus
  an unconditional fallback rule, which is the shape this module
  produces.
- The tag-conditional example on that same page is for this exact
  constraint (not a different one): `resource.matchTag('ORGANIZATION_ID/<key>', '<value>')`,
  a conditional rule and a mandatory unconditional rule, both using
  `values.allowedValues` — set at the **organisation**, via
  `gcloud org-policies set-policy POLICY_PATH`.
- Allowed-value formats shown in that worked example: `is:C03g5e3bc`
  (Google Workspace customer id) or
  `is:principalSet://cloudresourcemanager.googleapis.com/organizations/<id>`
  (organisation principal set) — both `is:`-prefixed. This module
  prefixes `bobbin_customer_id` with `is:` for that reason.
- Required role: `roles/orgpolicy.policyAdmin` **on the organisation**,
  stated directly on that page.
- A conditional rule requires at least one unconditional rule in the
  same policy, or the policy cannot be saved — stated on the same page
  and on the general "Scope organization policies with tags" guidance
  it links to.
- Terraform resource arguments (`google_org_policy_policy`'s
  `name`/`parent`/`spec.rules.condition.expression`/`spec.rules.values.allowed_values`;
  `google_tags_tag_key`'s `parent`/`short_name`;
  `google_tags_tag_value`'s `parent` as the tag key's `id`;
  `google_tags_tag_binding`'s `parent` as
  `//cloudresourcemanager.googleapis.com/projects/<NUMBER>` — a project
  **number**, not id — and `tag_value` in namespaced or `tagValues/<id>`
  form) against the `hashicorp/google` provider's own resource
  documentation.

**What we assumed rather than verified:**

- The exact IAM permission(s) needed to create a tag key/value and bind
  it (`resourcemanager.tagAdmin`/`resourcemanager.tagUser` or similar).
  Google's guidance points at a separate tags-permissions page we did
  not independently confirm role-by-role; if tag creation is refused,
  the person applying this module is not necessarily the person who
  granted the four viewer roles, same gotcha as `../`'s `families`.
- Whether `terraform import` against a Policy object that Google created
  by default (rather than one an admin set explicitly) behaves exactly
  as the provider's documented import path describes — see "Before your
  first `plan`" above.
- End-to-end behaviour against a live enforcing organisation — see
  "Status" above; this is the load-bearing caveat, not a footnote to it.

## Registry

Not published, for the same reason as [`../README.md`](../README.md#registry)
— one public repository holding every onboarding path, sourced from
GitHub.
