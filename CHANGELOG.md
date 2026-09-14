# Changelog

Notable changes to this repository. A tag here is the `ref` you pin in
the Terraform module's GitHub source
(`github.com/thoughtgears/bobbin-onboarding//terraform?ref=vX.Y.Z`) —
pin a tag rather than tracking a branch, so an upstream change never
lands in your plan unannounced.

## [Unreleased] — v0.2.0

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
