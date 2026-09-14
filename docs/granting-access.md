# Granting Bobbin read-only access

_Bobbin receives four viewer roles — and, per service you name, one more
read-only role only if you choose to give it. It can never change anything
in your project. `./grant-bobbin-access.sh` does exactly what is written
here, one command for one step, so you can check it against this page
before running it._

You will have received two values from us during onboarding:

- `TENANT_SA` — your dedicated service account, e.g.
  `tenant-acme-prod@bobbin-shard-N.iam.gserviceaccount.com`
- `TOPIC` — your alert intake topic, e.g.
  `projects/bobbin-hub-N/topics/tenant-acme-prod-alerts`

Prefer Terraform? [`../terraform`](../terraform) applies the same two
steps below as a module — see its README for inputs, outputs and a
copy-paste example.

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

**Success looks like:** each of the four commands prints the project's
updated IAM policy, ending in a line for `serviceAccount:$TENANT_SA`
under the role you just granted. To check all four landed in one go:

```bash
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten='bindings[].members' \
  --format='table(bindings.role)' \
  --filter="bindings.members:serviceAccount:$TENANT_SA"
```

That should list all four roles from the block above, and nothing else.

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

**Success looks like:** `gcloud` prints the created channel's resource
name, shaped `projects/<id>/notificationChannels/<n>` — that name
existing is what proves the channel was created. Re-running the `list`
command from above should now show it.

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

## Optional: a configuration role per service

The four roles read telemetry — logs, metrics, error groups, Cloud Run
revisions — and only telemetry. Some questions are not in the telemetry:
a PostgreSQL instance pinned at 100 connections is either under load or
at a `max_connections` of 100, and that flag lives in the instance's
settings. Bobby reports what he saw and says what would confirm it; he
does not guess.

For each service below, **one more read-only role** lets him read the
settings as well. It is optional — nothing stops working without it and
Bobby never asks for it in advance — and it is **per service**: the role
reads the configuration of the service the alert was about, never the
project. Each is a **custom role defined in your project** holding
exactly the `get`/`list` permissions the tool behind it calls, because
Google's predefined viewers for these services carry verbs that are not
reads (`roles/cloudsql.viewer` can export the database,
`roles/compute.viewer` can read a VM's serial console,
`roles/container.clusterViewer` can connect to a cluster).

| `--family`    | Role id                        | Reads                                                                                              | Cannot                                                                                   |
| ------------- | ------------------------------ | -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `managed-sql` | `bobbinManagedSqlConfigViewer` | Cloud SQL instance settings and database flags                                                     | change them, read or export any data, connect, or log in                                 |
| `cache`       | `bobbinCacheConfigViewer`      | Memorystore (Redis, Valkey, Memcached) instance settings                                           | change them, read cached data, or connect                                                |
| `kubernetes`  | `bobbinKubernetesConfigViewer` | GKE cluster settings from the GKE API (`container.clusters.get`, `.list`)                          | change them, or **connect to the cluster at all** — no pod, workload, ConfigMap or Secret |
| `compute`     | `bobbinComputeConfigViewer`    | Compute Engine instance, managed instance group and autoscaler settings, recent zone operations    | change them, or read the serial console, screenshots, metadata or startup scripts        |
| `networking`  | `bobbinNetworkingConfigViewer` | load balancer backend health with the reason, timeouts, balancing mode, health checks, URL maps    | change them, or read instance internals                                                  |

The exact permission list of each role is the `family_permissions` table
in [`../grant-bobbin-access.sh`](../grant-bobbin-access.sh) and
`local.family_roles` in [`../terraform/main.tf`](../terraform/main.tf);
they are the same list, and the product's own test suite asserts that
list equals what its tool calls.

**GKE, plainly:** Bobbin reads the GKE API and Cloud Logging and never
connects to your cluster's control plane — not with this role, not with
any other. The GKE API has no pods, Deployments, ConfigMaps or Secrets;
those live behind your cluster's API server, and that is a door Bobbin
does not have a key to.

### By script

One repeatable flag. Without it the script does exactly what it does
above; with it, after the four roles, it defines the role (or updates an
older definition to this list) and binds it:

```bash
./grant-bobbin-access.sh \
  --tenant-sa "$TENANT_SA" --topic "$TOPIC" \
  --project "$PROJECT_ID" --family managed-sql --dry-run
```

### By hand

```bash
gcloud iam roles create bobbinManagedSqlConfigViewer --project "$PROJECT_ID" \
  --title "Bobbin Cloud SQL configuration viewer" --stage GA \
  --permissions cloudsql.instances.get,cloudsql.instances.list
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$TENANT_SA" \
  --role "projects/$PROJECT_ID/roles/bobbinManagedSqlConfigViewer" --condition=None
```

**Success looks like:** `roles create` prints the role with its
`includedPermissions`, and the binding command prints the policy with a
line for `serviceAccount:$TENANT_SA` under
`projects/$PROJECT_ID/roles/bobbinManagedSqlConfigViewer`.

**The gotcha:** defining a custom role needs `iam.roles.create` on the
project, which `roles/resourcemanager.projectIamAdmin` does **not**
carry (`roles/iam.roleAdmin` and `roles/owner` do). The account that
granted the four roles is frequently not one that can define a fifth.
Nothing is half-done if that step is refused: the four roles and the
channel are in place, and re-running with `--family` as someone who
holds `roles/iam.roleAdmin` picks up there.

### With Terraform

The module's `families` input — see
[`../terraform/README.md`](../terraform/README.md). Your next `plan`
shows one role definition and one binding per project and family, and
nothing else.

## Removing access

```bash
./revoke-bobbin-access.sh \
  --tenant-sa "<the service account>" \
  --project "<your project id>" \
  --dry-run
```

Same contract as the grant: `--dry-run` prints every command and changes
nothing, and it calls nothing but `gcloud`. It removes the four role
bindings, removes any optional family role binding **and deletes the
role definition** — whether or not you pass `--family`, because
revocation should not require you to remember what you granted — and
deletes the notification channel. Your alert policies are left alone —
you wrote them, and they keep working with whatever other channels they
have.

**You do not have to run it for your data to be deleted.** Our half of the
teardown — the service account that could read your projects, your stored
credentials, your investigation history — runs on our schedule and does
not wait for you. This script removes the permissions you granted; ours
removes the identity they were granted to. Either alone stops Bobbin
reading anything.

One thing worth knowing if you run it after we have already torn down our
side: a deleted service account stops appearing in your IAM policy under
its own name and shows up as `deleted:serviceAccount:…?uid=…` instead. The
script reads your live policy and removes whichever form is actually
there, so it works either way round.

Used the Terraform module instead of the script? `terraform destroy` is
the exact reverse — see
[`../terraform/README.md`](../terraform/README.md#removing-bobbin).
