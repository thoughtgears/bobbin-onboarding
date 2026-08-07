# Granting Bobbin read-only access

_Bobbin receives four viewer roles and nothing else — it can never change
anything in your project. `./grant-bobbin-access.sh` does exactly what is
written here, one command for one step, so you can check it against this
page before running it._

You will have received two values from us during onboarding:

- `TENANT_SA` — your dedicated service account, e.g.
  `tenant-acme-prod@bobbin-shard-0.iam.gserviceaccount.com`
- `TOPIC` — your alert intake topic, e.g.
  `projects/bobbin-hub-64775/topics/tenant-acme-prod-alerts`

## 0. Prefer the script

`./grant-bobbin-access.sh` does everything below, and
`--dry-run` prints every command it would run without changing anything.
Read it first — that is what it is for.

```bash
./grant-bobbin-access.sh \
  --tenant-sa "$TENANT_SA" --topic "$TOPIC" \
  --project "$PROJECT_ID" --dry-run
```

It needs the `beta` gcloud component (`gcloud components install beta`)
for the notification channel, and it is safe to re-run: the IAM grants
are idempotent and it will not create a second channel.

The steps below are the same thing by hand.

## The known gotcha: domain-restricted sharing

If your org enforces `iam.allowedPolicyMemberDomains`, granting an
external service account fails with `FAILED_PRECONDITION` — and the raw
error does not mention the policy. If step 1 fails that way, add a
conditional exception for the Bobbin org (ask us for the org id) or a
project-level override, then re-run.
[Google's docs](https://cloud.google.com/resource-manager/docs/organization-policy/restricting-domains).

**We deliberately do not tell you to pre-check this.** Reading org policy
needs the Org Policy API, and if it is not enabled `gcloud` offers to
enable it for you — a write, on your project, prompted by a procedure
that promises to change nothing. Better to try the grant and read the
error.

## 1. Grant the four read-only roles

On every project Bobbin should investigate:

```bash
for ROLE in roles/logging.viewer roles/monitoring.viewer \
            roles/errorreporting.viewer roles/run.viewer; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member "serviceAccount:$TENANT_SA" --role "$ROLE" --condition=None
done
```

That is the complete access list. No write role is ever requested.

## 2. Create the alert notification channel

In your project, pointing at your Bobbin topic. **Check first if you are
doing this by hand** — creating it twice means two notifications for
every alert, and `channels create` will happily do that:

```bash
gcloud beta monitoring channels list --project "$PROJECT_ID" \
  --format='value(name,labels.topic)'
```

If a channel already points at your topic, skip this step. Otherwise:

```bash
gcloud beta monitoring channels create \
  --project "$PROJECT_ID" \
  --display-name "Bobbin (@bobby)" \
  --type pubsub \
  --channel-labels "topic=$TOPIC"
```

## 3. Tell us your project number

```bash
gcloud projects describe "$PROJECT_ID" --format 'value(projectNumber)'
```

We grant `service-<number>@gcp-sa-monitoring-notification.iam.gserviceaccount.com`
publish rights on your topic (our side) — alerts cannot flow until
this is done.

## 4. Attach the channel to alert policies

Add the "Bobbin (@bobby)" channel to any alert policy you want
investigated — or all of them. One incident becomes one investigation
in one Slack thread (storms fold; no channel spam).

## Removing access

Reverse step 1 (`remove-iam-policy-binding` per role) and delete the
notification channel. Nothing else exists on your side.
