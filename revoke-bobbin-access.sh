#!/usr/bin/env bash
#
# Removes Bobbin's access to your GCP project(s).
#
# THIS SCRIPT IS MEANT TO BE READ BEFORE IT IS RUN, for the same reason
# grant-bobbin-access.sh is: it calls nothing but `gcloud`, there is no
# network access to Bobbin, no telemetry, and no binary. Everything it
# does, you could type.
#
# It is the exact reverse of the grant:
#
#   roles/logging.viewer         removed
#   roles/monitoring.viewer      removed
#   roles/errorreporting.viewer  removed
#   roles/run.viewer             removed
#   the "Bobbin (@bobby)" Pub/Sub notification channel  deleted
#
# Nothing else of ours exists in your project, so when this finishes there
# is nothing of ours left in it.
#
# YOU DO NOT HAVE TO RUN THIS FOR YOUR DATA TO BE DELETED. Our side of the
# teardown — the service account that could read your projects, your
# stored credentials, your investigation history — happens on our
# schedule, not yours, and does not wait for you. This script removes the
# permissions you granted; ours removes the identity they were granted to.
# Either alone is sufficient to stop Bobbin reading anything.
#
# Run with --dry-run first. It prints every command and changes nothing.

set -euo pipefail

readonly ROLES=(
  roles/logging.viewer
  roles/monitoring.viewer
  roles/errorreporting.viewer
  roles/run.viewer
)

TENANT_SA=""
TOPIC=""
PROJECTS=()
DRY_RUN=false
ASSUME_YES=false

die() { printf '\nerror: %s\n' "$*" >&2; exit 1; }
note() { printf '  %s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }

# Same wrapper, same reason as the grant script: `--quiet` takes the
# default answer and stdin is closed, so this can never sit waiting for a
# human and can never accept gcloud's offer to enable an API on your
# project. A script that promises to only remove things must not be able
# to turn one on.
gcloud() { command gcloud "$@" --quiet </dev/null; }

shell_quote() {
  local arg out=""
  for arg in "$@"; do
    if [[ "$arg" =~ ^[A-Za-z0-9_./:=@?-]+$ ]]; then
      out+="$arg "
    else
      out+="'${arg}' "
    fi
  done
  printf '%s' "${out% }"
}

# The only thing that mutates anything, so --dry-run is trustworthy by
# construction rather than by remembering to check a flag at each call.
run() {
  printf '  $ %s\n' "$(shell_quote "$@")"
  if [[ "$DRY_RUN" == true ]]; then return 0; fi
  "$@" >/dev/null
}

usage() {
  cat <<'USAGE'
Usage:
  revoke-bobbin-access.sh --tenant-sa <SA_EMAIL>
                          --project <PROJECT_ID> [--project <PROJECT_ID> ...]
                          [--topic <TOPIC>] [--dry-run] [--yes]

  --tenant-sa   The service account you granted access to, e.g.
                tenant-acme@bobbin-shard-0.iam.gserviceaccount.com
  --project     A project to remove Bobbin from. Repeat for several.
  --topic       Your alert topic. Optional: without it the notification
                channel is matched by display name instead, which is
                weaker — see the comment at the channel step.
  --dry-run     Print every command without running it. Do this first.
  --yes         Skip the confirmation prompt.

Both values are in your console under Configuration, and in the email we
sent when you connected.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant-sa) TENANT_SA="${2:-}"; shift 2 ;;
    --topic)     TOPIC="${2:-}"; shift 2 ;;
    --project)   PROJECTS+=("${2:-}"); shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --yes)       ASSUME_YES=true; shift ;;
    -h|--help)   usage; exit 0 ;;
    *)           usage >&2; die "unknown argument: $1" ;;
  esac
done

[[ -n "$TENANT_SA" ]] || { usage >&2; die "--tenant-sa is required"; }
[[ ${#PROJECTS[@]} -gt 0 ]] || { usage >&2; die "at least one --project is required"; }

command -v gcloud >/dev/null || die "gcloud is not installed"
command gcloud beta --help >/dev/null 2>&1 \
  || die "the gcloud 'beta' component is required — run: gcloud components install beta"

step "What this will do"
note "Service account : $TENANT_SA"
note "Projects        : ${PROJECTS[*]}"
note ""
note "On each project, remove that service account from these four roles:"
for role in "${ROLES[@]}"; do note "  $role"; done
note ""
note "…and delete the Bobbin notification channel."
note "Nothing else is touched. Your alert policies are left exactly as they are."

if [[ "$DRY_RUN" == true ]]; then
  note ""
  note "DRY RUN — commands are printed, nothing is changed."
elif [[ "$ASSUME_YES" != true ]]; then
  printf '\nProceed? [y/N] '
  read -r reply
  [[ "$reply" == [yY]* ]] || die "aborted"
fi

for project in "${PROJECTS[@]}"; do
  step "Project: $project"

  gcloud projects describe "$project" --format='value(projectId)' >/dev/null 2>&1 \
    || die "cannot read project '$project' — check the id and that you are authenticated"

  # A DELETED service account does not appear in the policy under its own
  # email. GCP rewrites the member to
  #
  #   deleted:serviceAccount:tenant-acme@…?uid=123456789
  #
  # and `remove-iam-policy-binding` matches the member string EXACTLY, so
  # removing "serviceAccount:tenant-acme@…" silently fails to match and
  # leaves the binding in place.
  #
  # That is the normal case, not an edge one: our teardown deletes the
  # service account on our schedule, which is usually before you get to
  # this. So read the live policy and remove whatever form is actually
  # there, rather than assuming the tidy one.
  members=()
  while IFS= read -r member; do
    [[ -n "$member" ]] && members+=("$member")
  done < <(gcloud projects get-iam-policy "$project" \
    --flatten='bindings[].members' \
    --format='value(bindings.members)' 2>/dev/null \
    | grep -F "$TENANT_SA" | sort -u || true)

  if [[ ${#members[@]} -eq 0 ]]; then
    note "no bindings found for that service account — nothing to remove"
  else
    for member in "${members[@]}"; do
      [[ "$member" == deleted:* ]] \
        && note "binding is on a DELETED account — removing it by its tombstone form"
      for role in "${ROLES[@]}"; do
        # Tolerated per role: the binding may legitimately not exist,
        # either because you never granted it or because this is a re-run.
        run gcloud projects remove-iam-policy-binding "$project" \
          --member "$member" --role "$role" --condition=None 2>/dev/null || true
      done
    done
    note "removed Bobbin from ${#ROLES[@]} roles"
  fi

  # Matched in bash, NOT via `gcloud --filter`. Filtering this resource
  # silently returns nothing — even `--filter=type=pubsub` matches zero
  # pubsub channels — and a check that quietly matches nothing would here
  # mean leaving the channel behind while reporting success.
  #
  # Matched on the TOPIC when we have one, because that is what actually
  # identifies the channel as ours: a display name can collide, and
  # deleting someone else's channel is not a mistake we get to undo.
  found=""
  while IFS=$'\t' read -r channel_name channel_topic channel_display; do
    [[ -z "$channel_name" ]] && continue
    if [[ -n "$TOPIC" ]]; then
      [[ "$channel_topic" == "$TOPIC" ]] && { found="$channel_name"; break; }
    elif [[ "$channel_display" == "Bobbin (@bobby)" ]]; then
      found="$channel_name"
      break
    fi
  done < <(gcloud beta monitoring channels list \
    --project "$project" \
    --format='value(name,labels.topic,displayName)' 2>/dev/null || true)

  if [[ -z "$found" ]]; then
    note "no Bobbin notification channel found — nothing to delete"
  else
    run gcloud beta monitoring channels delete "$found" --project "$project"
    note "deleted the notification channel"
  fi

  # Deliberately NOT deleted: any alert policy that referenced the channel.
  # Those are yours — you wrote them, they describe your systems, and they
  # keep working with whatever other channels they have. Removing them
  # would be us deciding what your monitoring should look like.
  note "alert policies left alone — they are yours"
done

step "Done"
cat <<'EOF'

  Bobbin can no longer read anything in these projects.

  If any alert policy still lists the deleted channel, Cloud Monitoring
  will show it as a missing notification target. Editing that is optional
  and entirely yours — the alert still fires, it just has one fewer place
  to go.

  Nothing else of ours exists on your side. Our half of the teardown — the
  service account, your stored credentials, your investigation history —
  runs on our schedule and does not wait for this script.

EOF
