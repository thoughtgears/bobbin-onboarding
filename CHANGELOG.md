# Changelog

Notable changes to this repository, written by hand as changes land, and
reconstructed from `git log` where it fell behind.

A tag here is meant to be the `ref` you pin in the Terraform module's
GitHub source
(`github.com/thoughtgears/bobbin-onboarding//terraform?ref=vX.Y.Z`).
`v0.1.0` (2026-09-09), `v0.2.0` (2026-09-14), `v0.2.1` (2026-09-15) and
`v0.3.0` (2026-09-15) are real tags you can pin. A commit SHA works as a
`ref` too, and is immutable in exactly the way the advice cares about.
See [`terraform/README.md`](terraform/README.md#usage).

## v0.3.0 — 2026-09-15

### Added

- **`terraform/org-policy-exception/`** — an optional, separate Terraform
  module for the narrower of the two ways to unblock a grant when a
  customer's organisation enforces domain-restricted sharing
  (`constraints/iam.allowedPolicyMemberDomains`): a tag bound to the one
  project being connected, plus a conditional policy rule that lifts the
  restriction only on resources carrying that tag. Four resources
  (`google_tags_tag_key`, `google_tags_tag_value`, `google_tags_tag_binding`,
  `google_org_policy_policy`), easy to get wrong by hand, mechanically
  rendered. Deliberately never folded into [`terraform/`](terraform/):
  this module needs `roles/orgpolicy.policyAdmin` on the customer's
  **organisation**, a far larger ask than the four project-scoped viewer
  roles the existing module grants, and a reviewer approving one should
  never be handed the other by accident.
- **[`docs/domain-restricted-sharing.md`](docs/domain-restricted-sharing.md)**
  — the two routes (tag-scoped exception vs adding Bobbin's customer id,
  `C015nrtrj`, to the allowlist), a comparison table to help a customer
  choose between them, and the corrected `gcloud` commands for both,
  checked against Google's current Organization Policy documentation
  rather than carried forward unverified. Route 2 (the allowlist) is
  intentionally **not** a module — one policy value does not warrant
  one; the doc gives the `gcloud` command and stops there.
- Links from `README.md`, `docs/granting-access.md` and
  `terraform/README.md`'s existing "known gotcha" sections to the new
  doc and module, replacing the previous one-line pointer at Google's
  generic reference.

### Status — read before using `terraform/org-policy-exception`

**This has not been run against an organisation that enforces the
constraint.** Our own organisation has it at `ALLOW`, so it could not be
exercised. The commands and resources follow Google's documented
behaviour. Route 2 (the allowlist) is the known-good fallback if Route 1
does not work for you. Full detail, including what was verified against
Google's documentation versus assumed, is in
[`terraform/org-policy-exception/README.md`](terraform/org-policy-exception/README.md).

### Unchanged

- `terraform/`, `grant-bobbin-access.sh`, `revoke-bobbin-access.sh` and
  every permission list are byte-for-byte what `v0.2.1` shipped. This
  release is additive only.

## v0.2.1 — 2026-09-15

Documentation only. The module, both scripts and every permission list
are byte-for-byte what `v0.2.0` shipped; what changed is three sentences
a security reviewer could falsify against Google's own references, and
one page that had fallen behind the product.

### Fixed

- `docs/slack-setup.md` described the app as two bot scopes with no event
  subscriptions and no interactivity, and said Bobby cannot read your
  Slack. Since 2026-09-11 the app asks for six bot scopes, subscribes to
  `app_mention` events so you can ask Bobby a follow-up in a thread, and
  has interactivity on for the card's buttons. The page now says exactly
  that, with what each scope is for, and what Bobby still cannot read: any
  message that does not name him.
- The `compute` family said its role "cannot read metadata or startup
  scripts". `compute.instances.get` returns the instance's `metadata`,
  startup script included; Bobbin's tool discards it through an
  allowlist, but the permission allows it. The doc, the script header and
  the role table now say which is which.
- The `kubernetes` family said its role "cannot connect to the cluster at
  all". `container.clusters.get` is the permission `get-credentials`
  uses, so an identity holding it can generate a kubeconfig; what is true
  is that the role carries no permission on any Kubernetes object and is
  authorised for nothing inside the cluster, and that
  `container.clusters.connect` is deliberately absent. Also noted: on a
  cluster still issuing a legacy client certificate, `clusters.get`
  returns it.
- `roles/run.viewer` was described as "Cloud Run service and revision
  configuration" without saying the response carries environment-variable
  values in plaintext. Bobbin reads names only and never persists a value;
  the permission allows reading them, and the README, the doc, the module
  README and the script header now say so beside the audit-log
  disclosure, which set the bar.

## v0.2.0 — 2026-09-14

### Added

- **Optional configuration roles, one per service** (ADR-0055 in the
  product repo). `grant-bobbin-access.sh --family <name>` (repeatable),
  the module's `families` input, and a by-hand section in
  [`docs/granting-access.md`](docs/granting-access.md). Each is a custom
  role defined in your project holding exactly the `get`/`list`
  permissions the product's tool calls: `managed-sql`, `cache`,
  `kubernetes`, `compute`, `networking`. Without the flag or the input,
  both paths do exactly what v0.1.0 did.
- `revoke-bobbin-access.sh` now removes any family role binding and
  deletes the role definition, unconditionally — nothing of ours is
  left in your project.
- Module outputs: `granted_roles` includes the family roles;
  `family_roles` lists each definition and its permissions.

### Noted

- For GKE the role is `container.clusters.get` and `.list` — the GKE API
  only. Bobbin never connects to your cluster.

## v0.1.0

### Fixed

- `docs/slack-setup.md` described the superseded Slack path — create your
  own app from a manifest, then send us the `xoxb-` bot token through a
  one-time link. Bobbin installs by **Add to Slack** now; the token goes
  from Slack to Bobbin without a person handling it. The page also
  understated the app's scopes: it asks for `chat:write` **and**
  `incoming-webhook`, the second being what puts the channel choice on
  Slack's consent screen.
- The four-role tables described `roles/logging.viewer` as "log entries"
  and said nothing about the **Admin Activity audit log**, which Bobbin
  reads through the same permission to answer "what changed" when the
  cause was a config or IAM change rather than a deploy. No permission
  changed; the disclosure did.
- The Terraform usage example pinned `?ref=v0.1.0` before that tag
  existed, so
  `terraform init` could not resolve it. The example now pins a commit
  SHA, which is immutable today and needs no release cut first.
- `revoke-bobbin-access.sh` printed the deleted-service-account member
  form unquoted, so the `?uid=` in it was a glob and zsh — macOS's default
  shell — refused the pasted line outright.
- `grant-bobbin-access.sh`'s header pointed at `docs/onboarding/grant-access.md`,
  a path in neither this repository nor the product's. It wraps
  `docs/granting-access.md`, beside it.

### Added

- `terraform/` — a Terraform module applying the same grants as
  [`docs/granting-access.md`](docs/granting-access.md) and
  [`grant-bobbin-access.sh`](grant-bobbin-access.sh): the four read-only
  roles for the tenant service account, and the Pub/Sub-type Cloud
  Monitoring notification channel. See `terraform/README.md` for inputs,
  outputs and a copy-paste example.
- `examples/single-project/` — a minimal working root module using
  `terraform/` against a single project.

### Changed

- `README.md` and `docs/granting-access.md` now present all three
  onboarding paths (doc, script, module) rather than doc and script
  only.
