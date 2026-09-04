#!/usr/bin/env bash
#
# Grants Bobbin read-only access to your GCP project(s).
#
# THIS SCRIPT IS MEANT TO BE READ BEFORE IT IS RUN. It wraps the steps in
# docs/onboarding/grant-access.md one-for-one and calls nothing but
# `gcloud`. There is no network access to Bobbin, no telemetry, no
# install step, and no binary. Everything it does, you could type.
#
# What it grants, in full:
#
#   roles/logging.viewer         read log entries
#   roles/monitoring.viewer      read metrics and alert policies
#   roles/errorreporting.viewer  read error groups
#   roles/run.viewer             read Cloud Run service and revision config
#
# All four are read-only Google-managed roles. Bobbin cannot change
# anything in your project, and asks for no role that would let it.
#
# Run with --dry-run first. It prints every command and changes nothing.

set -euo pipefail

readonly ROLES=(
  roles/logging.viewer
  roles/monitoring.viewer
  roles/errorreporting.viewer
  roles/run.viewer
)

readonly CHANNEL_NAME="Bobbin (@bobby)"
readonly DOMAIN_POLICY_DOCS="https://cloud.google.com/resource-manager/docs/organization-policy/restricting-domains"

TENANT_SA=""
TOPIC=""
PROJECTS=()
DRY_RUN=false
ASSUME_YES=false

die() { printf '\nerror: %s\n' "$*" >&2; exit 1; }
note() { printf '  %s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }

# "granted" is a lie in dry-run mode. Takes both tenses rather than
# trying to conjugate: $1 is what happened, $2 is what would happen.
did() { if [[ "$DRY_RUN" == true ]]; then note "would $2"; else note "$1"; fi; }

# Every gcloud call here is read-only or an IAM grant, and none of them may
# prompt. `--quiet` takes the default answer and stdin is closed, so the
# script can never sit waiting for a human — and, more importantly, can
# never accept gcloud's offer to enable an API on your project. An earlier
# version checked your org policy and gcloud offered to turn on the Org
# Policy API to do it: a write, on your project, from a script that
# promises to change nothing.
gcloud() { command gcloud "$@" --quiet </dev/null; }

# Quote an argument the way you would have to type it, so everything
# printed below is copy-pasteable. Without this, an argument containing
# spaces prints as `--display-name Bobbin (@bobby)`, which is a syntax
# error if you paste it.
shell_quote() {
  local arg out=""
  for arg in "$@"; do
    if [[ "$arg" =~ ^[A-Za-z0-9_./:=@-]+$ ]]; then
      out+="$arg "
    else
      out+="'${arg}' "
    fi
  done
  printf '%s' "${out% }"
}

# `run` is the only thing that mutates anything. Every change goes through
# it, so --dry-run is trustworthy by construction rather than by us having
# remembered to check a flag in each place.
#
# It swallows command output but NEVER the printed command. An earlier
# version let call sites add `>/dev/null`, which silenced the echo too and
# hid the IAM grants from the one mode that exists to show them.
run() {
  printf '  $ %s\n' "$(shell_quote "$@")"
  if [[ "$DRY_RUN" == true ]]; then return 0; fi
  "$@" >/dev/null
}

usage() {
  cat <<'USAGE'
Usage:
  grant-bobbin-access.sh --tenant-sa <SA_EMAIL> --topic <TOPIC> \
                         --project <PROJECT_ID> [--project <PROJECT_ID> ...]
                         [--dry-run] [--yes]

  --tenant-sa   The service account we gave you, e.g.
                tenant-acme@bobbin-shard-N.iam.gserviceaccount.com
  --topic       Your alert intake topic, e.g.
                projects/bobbin-hub-N/topics/tenant-acme-alerts
  --project     A project Bobbin should investigate. Repeat for several.
  --dry-run     Print every command without running it. Do this first.
  --yes         Skip the confirmation prompt (for reruns).

Both values come from Bobbin during onboarding. If you do not have them,
stop — this script cannot be used without them.
USAGE
}

explain_domain_policy() {
  cat <<MSG

  This is almost certainly iam.allowedPolicyMemberDomains — domain-restricted
  sharing, which blocks IAM grants to service accounts outside your org. It
  is a deliberate setting, not a mistake, and it needs an exception for
  Bobbin's organization before onboarding can continue. Ask us for the org id.

    $DOMAIN_POLICY_DOCS

  Nothing is left half-done: re-run this script once the exception is in
  place and it will pick up where it stopped.
MSG
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant-sa) TENANT_SA="${2:-}"; shift 2 ;;
    --topic)     TOPIC="${2:-}"; shift 2 ;;
    --project)   PROJECTS+=("${2:-}"); shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --yes)       ASSUME_YES=true; shift ;;
    -h|--help)   usage; exit 0 ;;
    *)           usage; die "unknown argument: $1" ;;
  esac
done

[[ -n "$TENANT_SA" ]] || { usage; die "--tenant-sa is required"; }
[[ -n "$TOPIC" ]] || { usage; die "--topic is required"; }
[[ ${#PROJECTS[@]} -gt 0 ]] || { usage; die "at least one --project is required"; }

[[ "$TENANT_SA" == *@*.iam.gserviceaccount.com ]] \
  || die "--tenant-sa does not look like a service account: $TENANT_SA"
[[ "$TOPIC" == projects/*/topics/* ]] \
  || die "--topic must be a full path (projects/PROJECT/topics/NAME), got: $TOPIC"

command -v gcloud >/dev/null || die "gcloud is not installed"

# The notification-channel commands live in the beta surface. If it is
# missing, gcloud prompts to install it mid-run; check up front so the
# decision is yours, made before anything has happened.
command gcloud beta --help >/dev/null 2>&1 \
  || die "the gcloud 'beta' component is required — run: gcloud components install beta"

step "What this will do"
note "Service account : $TENANT_SA"
note "Alert topic     : $TOPIC"
note "Projects        : ${PROJECTS[*]}"
note ""
note "On each project, grant that service account these four roles:"
for role in "${ROLES[@]}"; do note "  $role"; done
note ""
note "…and create one Pub/Sub notification channel named \"$CHANNEL_NAME\"."
note "Nothing else. No write access is requested and none is granted."

if [[ "$DRY_RUN" == true ]]; then
  note ""
  note "DRY RUN — commands are printed, nothing is changed."
elif [[ "$ASSUME_YES" != true ]]; then
  printf '\nProceed? [y/N] '
  read -r reply
  [[ "$reply" == [yY]* ]] || die "aborted"
fi

# Collected for the final handshake. Alerts cannot flow until Bobbin grants
# your project's monitoring agent publish rights on the topic, and it needs
# these numbers to do it.
PROJECT_NUMBERS=()

for project in "${PROJECTS[@]}"; do
  step "Project: $project"

  gcloud projects describe "$project" --format='value(projectId)' >/dev/null 2>&1 \
    || die "cannot read project '$project' — check the id and that you are authenticated"

  # We deliberately do NOT pre-check the org policy that most often blocks
  # this (see the gcloud wrapper above). Try the grant; explain the failure.
  #
  # add-iam-policy-binding is idempotent, so re-running after fixing a
  # policy — or to add a project — is safe and does nothing twice.
  errfile=$(mktemp)
  for role in "${ROLES[@]}"; do
    if ! run gcloud projects add-iam-policy-binding "$project" \
      --member "serviceAccount:$TENANT_SA" \
      --role "$role" \
      --condition=None 2>"$errfile"; then
      err=$(cat "$errfile"); rm -f "$errfile"
      printf '\n%s\n' "$err" >&2
      if [[ "$err" == *FAILED_PRECONDITION* || "$err" == *allowedPolicyMemberDomains* ]]; then
        explain_domain_policy >&2
      fi
      die "granting $role on $project failed — see above"
    fi
  done
  rm -f "$errfile"
  did "granted ${#ROLES[@]} read-only roles" "grant ${#ROLES[@]} read-only roles"

  # Channel creation is NOT idempotent — creating twice gives two channels
  # and two notifications per alert, so this check is load-bearing.
  #
  # Matching happens in bash, NOT via `gcloud --filter`. Filtering this
  # resource silently returns nothing (even `--filter=type=pubsub` matches
  # zero pubsub channels), and a check that quietly matches nothing is
  # worse than no check: it reports success and creates a duplicate every
  # run. Found by running this script twice, 2026-08-06.
  #
  # We match on the TOPIC, not the display name: two channels pointing at
  # the same topic is what actually doubles the notifications.
  existing=""
  while IFS=$'\t' read -r channel_name channel_topic; do
    if [[ "$channel_topic" == "$TOPIC" ]]; then existing="$channel_name"; break; fi
  done < <(gcloud beta monitoring channels list \
    --project "$project" \
    --format='value(name,labels.topic)' 2>/dev/null || true)

  if [[ -n "$existing" ]]; then
    note "notification channel already exists — leaving it alone"
    note "  $existing"
  else
    run gcloud beta monitoring channels create \
      --project "$project" \
      --display-name "$CHANNEL_NAME" \
      --type pubsub \
      --channel-labels "topic=$TOPIC"
    did "created the notification channel" "create the notification channel"
  fi

  PROJECT_NUMBERS+=("$project=$(gcloud projects describe "$project" --format='value(projectNumber)')")
done

step "Done — one thing left, and it is on our side"
cat <<EOF

  Alerts cannot reach Bobbin until we grant your project's monitoring
  agent permission to publish to the topic. Send us these numbers:

EOF
for entry in "${PROJECT_NUMBERS[@]}"; do printf '    %s\n' "$entry"; done
cat <<EOF

  Then attach the "$CHANNEL_NAME" channel to whichever alert policies you
  want investigated — all of them is a reasonable choice. One incident
  becomes one investigation in one Slack thread; storms fold together
  rather than spamming the channel.

  To remove Bobbin entirely: reverse the grants with
  'gcloud projects remove-iam-policy-binding' for the four roles above,
  and delete the notification channel. Nothing else exists on your side.

EOF
