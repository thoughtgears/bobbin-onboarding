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
- The Terraform usage example pinned `?ref=v0.1.0`. There are no tags, so
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
