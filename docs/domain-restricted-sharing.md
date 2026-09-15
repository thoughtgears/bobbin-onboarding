# Domain-restricted sharing: choosing a route, and applying it

If granting Bobbin's four roles failed with `FAILED_PRECONDITION`, or the
product itself showed a "blocked" screen naming this constraint, your
organisation enforces
[`constraints/iam.allowedPolicyMemberDomains`](https://cloud.google.com/resource-manager/docs/organization-policy/restricting-domains)
— usually called **domain-restricted sharing**. It refuses any IAM role
binding to a principal outside your own Cloud Identity customer. Bobbin's
tenant service account lives in **our** Google Cloud project, not yours
— one dedicated account per customer, the same design that keeps one
Bobbin customer's identity from ever reaching another's — so every one
of the four read-only bindings is refused until you allow it.

**This is a deliberate security setting, not a misconfiguration**, and
neither route below asks you to turn it off. Both add a narrow
exception; the difference between them is how narrow.

## Choosing a route

|                        | Route 1: tag-scoped exception                                                                      | Route 2: add Bobbin to the allowlist                                                 |
| ---------------------- | ---------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| **Scope**              | The one project you tag. Nothing else in your organisation changes.                                  | Every project in your organisation that inherits this policy — present and future.     |
| **What it touches**    | Four resources: a tag key, a tag value, a tag binding, and a conditional rule on the org policy.      | One value added to the org policy's allowlist. Nothing else.                          |
| **Permission needed**  | `roles/orgpolicy.policyAdmin` on the **organisation** — both routes edit an org-level policy object. | Also `roles/orgpolicy.policyAdmin` on the **organisation** — the same requirement. |
| **New projects later** | Each one needs its own tag binding — a deliberate, visible, repeatable step.                          | Automatically covered, with no further action — which is convenient, and also means you may not notice Bobbin's access extending to a project you did not mean to include. |
| **To undo**            | Remove one tag binding. The policy rule and Bobbin's customer id stay defined but inert for every other project. | Edit the org policy again and remove the customer id.                                  |
| **Terraform module**   | [`../terraform/org-policy-exception`](../terraform/org-policy-exception) — optional, not required.   | None — a single value does not warrant a module; see the `gcloud` steps below.         |
| **Tooling maturity**   | Newer, more moving parts, **not yet exercised against a live enforcing organisation** — see the module's [Status](../terraform/org-policy-exception/README.md#status) section. | Simpler, and the fallback if Route 1 does not work for you. |

**Both routes need the same IAM role.** The real trade-off is not
permission but blast radius and maintenance shape: Route 1 stays narrow
forever, at the cost of one tag binding per future project; Route 2 is
one edit, done once, and then applies itself to every project your
organisation ever creates under this policy, including ones nobody
thought to check against a supplier allowlist. If your organisation
already reviews org policy changes as security-relevant (most that
enforce domain-restricted sharing do), Route 1 gives that review
something narrow and legible to approve. If you connect many projects to
Bobbin over time, or expect to, Route 2's one-time cost may be the more
honest trade — it is also the one with no unexercised Terraform module
behind it.

## What needs to be allowed

One service account, dedicated to your workspace, shaped like:

```text
tenant-<your-workspace>@bobbin-shard-<n>.iam.gserviceaccount.com
```

The exact address is shown in the console and printed by
[`../grant-bobbin-access.sh`](../grant-bobbin-access.sh) and the
[`../terraform`](../terraform) module. It is being granted four
**viewer** roles and nothing else — see
[`../README.md`](../README.md#what-bobbin-gets) for the complete list.
No path here ever requests a write role.

Bobbin's Cloud Identity customer id, used by both routes below, is
`C015nrtrj`.

## Before either route: read your current policy

Setting this org policy **replaces its entire rule set** — the
Organization Policy Service has no "add one value" operation, and
neither `gcloud org-policies set-policy` nor Terraform's
`google_org_policy_policy` resource can do a partial update. Read what
is currently allowed before writing anything:

```bash
gcloud org-policies describe iam.allowedPolicyMemberDomains \
  --organization=ORGANIZATION_ID --effective \
  --format='value(spec.rules[0].values.allowedValues)'
```

Keep that output. Both routes below need it, and skipping this step is
how a well-meant exception ends up narrower than intended — dropping
your own organisation's access rather than only adding Bobbin's.

## Route 1: a tag-scoped exception (preferred, narrower)

Full detail, a Terraform module, and an honest account of what has and
has not been verified are in
[`../terraform/org-policy-exception/README.md`](../terraform/org-policy-exception/README.md)
— read it before applying either the module or the equivalent `gcloud`
steps reproduced there. In outline: tag the one project, then add a rule
to the org policy that only relaxes the restriction on resources
carrying that tag.

## Route 2: add Bobbin to the allowlist (simpler, org-wide)

One value, added to the allowlist you already read above. No module —
a module around a single value would be ceremony, not help.

Write `allowlist.yaml`, with your existing values from "Before either
route" above plus Bobbin's:

```yaml
name: organizations/ORGANIZATION_ID/policies/iam.allowedPolicyMemberDomains
spec:
  rules:
    - values:
        allowedValues:
          - is:YOUR_EXISTING_VALUE # repeat one line per existing value
          - is:C015nrtrj # Bobbin
```

Apply it:

```bash
gcloud org-policies set-policy allowlist.yaml
```

**Success looks like:**

```bash
gcloud org-policies describe iam.allowedPolicyMemberDomains \
  --organization=ORGANIZATION_ID --effective
```

showing `is:C015nrtrj` in `allowedValues`, and re-running the grant —
the script, the doc, or the Terraform module in [`../terraform`](../terraform)
— no longer failing with `FAILED_PRECONDITION`.

**To undo:** edit `allowlist.yaml` to drop the `is:C015nrtrj` line and
`set-policy` again.

## After either route

Re-run whichever grant path you started with:
[`granting-access.md`](granting-access.md),
[`../grant-bobbin-access.sh`](../grant-bobbin-access.sh), or
[`../terraform`](../terraform) — the resources and commands are
idempotent, so it picks up exactly where it stopped. Nothing was applied
before the exception was in place, so there is nothing to undo on
Bobbin's side of that failed attempt.

If a project still fails after the exception is in place and the grant
has been re-run, the cause is something else — send us the project id
and organisation id at `support@getbobbin.dev`.

## What we verified, and what we assumed

Against Google's current documentation for
`constraints/iam.allowedPolicyMemberDomains` (`cloud.google.com/resource-manager/docs/organization-policy/restricting-domains`,
fetched 2026-09-15) — full detail in the module README's
["What we verified"](../terraform/org-policy-exception/README.md#what-we-verified)
section:

- **Verified**: the constraint is list-type and does not support
  `denyAll`/denied values; the `allowedValues` formats (`is:C…` /
  `is:principalSet://…`); that a conditional rule needs an unconditional
  fallback rule in the same policy or the policy cannot be saved; that
  `roles/orgpolicy.policyAdmin` on the organisation is the role Google
  itself names for this.
- **Assumed**: the exact IAM permission(s) for creating and binding tags
  (a separate permissions page we did not independently confirm role by
  role), and everything about how Route 1 behaves against an
  organisation actually enforcing the constraint — **we have not run
  either route against one**. Our own organisation has this constraint
  at `ALLOW`, so it has never been exercised end to end. Route 2 is the
  simpler command and the one we would reach for first if Route 1
  surprised us.
