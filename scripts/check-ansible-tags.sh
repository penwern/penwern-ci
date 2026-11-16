#!/usr/bin/env bash
# Usage: check-ansible-tags.sh <deploy-repo-root>
# Fails if a tag named after --tags/--skip-tags/-t in the deploy repo's scripts/*.sh,
# README.md or CLAUDE.md is not a tag that `--list-tags` reports for curate.yml or
# monitoring.yml. An empty scope (no documented tags, no playbook tags) is a broken
# check and fails too. Exit: 0 clean, 1 missing tags, 2 infra/empty scope.
# Blind spot: --list-tags reads tags statically. Tags that a role sets inside a file
# pulled in by include_tasks are invisible to it unless the include itself carries them
# (import_tasks and role-level tags are visible). A documented tag that only exists
# that way is reported missing; add the tag to the include to fix it.
set -u
. "$(dirname "$0")/lib.sh"

root="${1:-}"; [ -d "$root" ] || die "usage: check-ansible-tags.sh <deploy-repo-root>" 2
cd "$root" || exit 2

playbooks="curate.yml monitoring.yml"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

# Tags the playbooks define. 'TAGS: [a, b]' lines cover play-level and task-level tags.
for pb in $playbooks; do
  out="$(ansible-playbook "$pb" --list-tags 2>&1)" || { echo "$out" >&2; die "ansible-playbook --list-tags failed for $pb" 2; }
  printf '%s\n' "$out" | grep -E 'TAGS: \[' | sed -E 's/.*TAGS: \[(.*)\].*/\1/' | tr ',' '\n'
done | tr -d ' ' | grep -v '^$' | sort -u > "$work/defined"
[ -s "$work/defined" ] || die "no tags reported by --list-tags for: $playbooks" 2

# Tags the docs name. -t is only read on lines that run a playbook, so shell tests like [[ -t 0 ]] are ignored.
files=""
for f in scripts/*.sh README.md CLAUDE.md; do [ -f "$f" ] && files="$files $f"; done
# shellcheck disable=SC2086
{
  grep -hoE -- '(--tags|--skip-tags)([= ]+)[^[:space:]]+' $files
  grep -hE 'ansible-playbook|deploy\.sh' $files | grep -hoE -- '(^|[[:space:]])-t[[:space:]]+[^[:space:]]+'
} 2>/dev/null | sed -E 's/^[[:space:]]*(--tags|--skip-tags|-t)[= ]+//' | tr -d "\"'\`" \
  | sed -E 's/[.;:)]+$//' | tr ',' '\n' | grep -v '^$' | sort -u > "$work/raw"

# Placeholders and shell syntax are not tags.
grep -E '^[A-Za-z0-9_-]+$' "$work/raw" > "$work/documented"
grep -vE '^[A-Za-z0-9_-]+$' "$work/raw" | sed 's/^/[penwern-ci] ignoring non-tag token: /' >&2
[ -s "$work/documented" ] || die "no documented tags found in: $files" 2

# all/tagged/untagged/never are Ansible's own selectors.
missing="$(comm -23 "$work/documented" "$work/defined" | grep -vxE 'all|tagged|untagged|never')"
if [ -n "$missing" ]; then
  while read -r t; do log "documented tag not in any playbook: $t"; done <<< "$missing"
  exit 1
fi
log "ok: $(wc -l < "$work/documented") documented tags all exist ($(wc -l < "$work/defined") defined)"
