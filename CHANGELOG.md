# Changelog

Notable changes to this repository, written by hand as changes land, and
reconstructed from `git log` where it fell behind.

A tag here is meant to be the `ref` you pin in the Terraform module's
GitHub source
(`github.com/thoughtgears/bobbin-onboarding//terraform?ref=vX.Y.Z`).
**No tag has been cut yet** — `v0.1.0` below is the version the unreleased
work is heading for, not something you can resolve. Until it exists, pin a
commit SHA: `?ref=<full sha>` accepts one, and it is immutable in exactly
the way the advice cares about. See
[`terraform/README.md`](terraform/README.md#usage).

## [Unreleased] — v0.1.0

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
