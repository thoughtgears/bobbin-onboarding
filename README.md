# Connecting Bobbin

Everything you need to connect [Bobbin](https://getbobbin.dev) to your
GCP project and your Slack workspace.

**This repository exists to be read.** Bobbin asks for read access to your
production infrastructure, so the honest way to ask is to show you exactly
what is being requested, in code you can check, before you run anything.
There is no installer, no binary, and no step that phones home.

## What Bobbin gets

Four Google-managed **read-only** roles, on the projects you choose:

| Role | What it reads |
| --- | --- |
| `roles/logging.viewer` | Log entries |
| `roles/monitoring.viewer` | Metrics and alert policies |
| `roles/errorreporting.viewer` | Error groups |
| `roles/run.viewer` | Cloud Run service and revision configuration |

That is the complete list. Bobbin cannot change anything in your project,
and asks for no role that would let it. It reads at the moment an alert
fires and keeps no copy of your telemetry.

## The two halves

Connecting Bobbin has a GCP half and a Slack half. They are independent —
do them in either order.

1. **[Granting access](docs/granting-access.md)** — the four roles above
   and a notification channel. Three ways to apply them, all doing
   exactly the same thing (ADR-0003 in the product repo):
   - the doc itself — numbered `gcloud` steps, run by hand
   - `./grant-bobbin-access.sh` — the same steps wrapped in a readable,
     auditable script; the default on a live onboarding call
   - **[`terraform/`](terraform/)** — a plain-HCL module, for IaC-native
     shops that would rather `plan` and `apply` than run bash
2. **[Slack setup](docs/slack-setup.md)** — install the Bobbin app in
   your workspace and choose a channel.

## Start here

```bash
./grant-bobbin-access.sh \
  --tenant-sa "<the service account we gave you>" \
  --topic "<the topic we gave you>" \
  --project "<your project id>" \
  --dry-run
```

`--dry-run` prints every command it would run and changes nothing. Run it
first, read the output, then run it again without the flag. A successful
run ends with "Done — one thing left, and it is on our side" followed by
a project number per project — send us those numbers; alerts cannot flow
until we grant your projects' Cloud Monitoring service agent publish
rights on your topic.

Prefer Terraform? Skip to [`terraform/`](terraform/) — same grants, same
roles, no `gcloud` required.

## Removing Bobbin

```bash
./revoke-bobbin-access.sh --tenant-sa "<…>" --project "<…>" --dry-run
```

The exact reverse of the grant, and readable the same way. Details in
[granting access](docs/granting-access.md). Used the Terraform module
instead? `terraform destroy` is the exact reverse there — see
[`terraform/README.md`](terraform/README.md#removing-bobbin). Either way,
nothing else of ours exists in your project.

Your data is deleted whether or not you run it — our side of the teardown
does not wait for yours.

## Questions

Anything at all, including "why do you need this role" — ask.
