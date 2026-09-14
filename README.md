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
| `roles/logging.viewer` | Log entries, and the Admin Activity audit log |
| `roles/monitoring.viewer` | Metrics and alert policies |
| `roles/errorreporting.viewer` | Error groups |
| `roles/run.viewer` | Cloud Run service and revision configuration |

That is the complete list for reading telemetry. Bobbin cannot change
anything in your project, and asks for no role that would let it. It
reads at the moment an alert fires and keeps no copy of your telemetry.

Optionally, per service you name, **one more read-only role** lets Bobbin
read that service's settings as well — a custom role holding exactly the
`get`/`list` permissions its tool calls, deleted again by the revoke
script. For GKE that is the GKE API and never the cluster. See
[Optional: a configuration role per service](docs/granting-access.md#optional-a-configuration-role-per-service).

The audit-log half of `logging.viewer` is worth calling out rather than
leaving you to infer it from the role name. When an incident was caused by
a configuration or IAM change rather than a deploy, the only place that
says so is your Admin Activity audit log, so Bobbin reads it: what changed,
when, and the email address of whoever changed it. It is the same
`logging.logEntries.list` the role already grants — no extra permission —
but it is a different sentence, and you should have it before you run
anything. Data Access audit logs are a separate permission
(`logging.privateLogEntries.list`) and Bobbin is never granted it.

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
2. **[Slack setup](docs/slack-setup.md)** — click **Add to Slack** in
   your console and choose a channel on Slack's own consent screen.

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

The exact reverse of the grant, and readable the same way — including
deleting any optional family role it finds, whether or not you name one.
Details in [granting access](docs/granting-access.md). Used the Terraform module
instead? `terraform destroy` is the exact reverse there — see
[`terraform/README.md`](terraform/README.md#removing-bobbin). Either way,
nothing else of ours exists in your project.

Your data is deleted whether or not you run it — our side of the teardown
does not wait for yours.

## Questions

Anything at all, including "why do you need this role" — ask.
