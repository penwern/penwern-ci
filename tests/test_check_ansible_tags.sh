# shellcheck shell=bash
# check-ansible-tags.sh against a stub deploy repo and a stub ansible-playbook.
_ct="$(mktmp)"; mkdir -p "$_ct/bin" "$_ct/repo/scripts"
cat > "$_ct/bin/ansible-playbook" <<'STUB'
#!/usr/bin/env bash
[ "${STUB_TAGS:-}" = "none" ] && { echo "playbook: $1"; exit 0; }
echo "playbook: $1"
echo "      TASK TAGS: [always, cells, cells-config, infra]"
STUB
chmod +x "$_ct/bin/ansible-playbook"
_ctrun() { PATH="$_ct/bin:$PATH" bash scripts/check-ansible-tags.sh "$_ct/repo" 2>&1; }

printf 'ansible-playbook curate.yml --tags infra\nansible-playbook curate.yml -t cells,cells-config\nansible-playbook x --skip-tags=cells -l <host> --tags <tag>\n' > "$_ct/repo/README.md"
printf 'if [[ -t 0 ]]; then :; fi\n' > "$_ct/repo/scripts/a.sh"
out="$(_ctrun)"; ec=$?
assert_exit "$ec" 0 "check-ansible-tags: all documented tags exist"

printf 'ansible-playbook curate.yml --tags infrastructure\n' >> "$_ct/repo/README.md"
out="$(_ctrun)"; ec=$?
assert_exit "$ec" 1 "check-ansible-tags: missing tag fails"
assert_contains "$out" "infrastructure" "check-ansible-tags: names the missing tag"

printf 'nothing here\n' > "$_ct/repo/README.md"
out="$(_ctrun)"; ec=$?
assert_exit "$ec" 2 "check-ansible-tags: zero documented tags fails"

printf 'ansible-playbook curate.yml --tags infra\n' > "$_ct/repo/README.md"
out="$(STUB_TAGS=none _ctrun)"; ec=$?
assert_exit "$ec" 2 "check-ansible-tags: zero playbook tags fails"

printf 'ansible-playbook curate.yml --tags "infra, missing"\n' > "$_ct/repo/README.md"
out="$(_ctrun)"; ec=$?
assert_exit "$ec" 1 "check-ansible-tags: quoted tags with spaces are read"
assert_contains "$out" "tag not in any playbook: missing" "check-ansible-tags: names tag after quoted space"

printf 'ansible-playbook curate.yml --tags infra,missing.tag\n' > "$_ct/repo/README.md"
out="$(_ctrun)"; ec=$?
assert_exit "$ec" 1 "check-ansible-tags: dotted tag is checked"
assert_contains "$out" "missing.tag" "check-ansible-tags: names the dotted tag"

printf 'ansible-playbook curate.yml --tags \\\n  missing\n' > "$_ct/repo/README.md"
out="$(_ctrun)"; ec=$?
assert_exit "$ec" 1 "check-ansible-tags: continued tag argument is read"
assert_contains "$out" "tag not in any playbook: missing" "check-ansible-tags: names the continued tag"

printf 'ansible-playbook curate.yml --tags\tmissing\nansible-playbook curate.yml -t\tmissing2\n' > "$_ct/repo/README.md"
out="$(_ctrun)"; ec=$?
assert_exit "$ec" 1 "check-ansible-tags: tab-separated tags are read"
assert_contains "$out" "tag not in any playbook: missing2" "check-ansible-tags: names the tab-separated -t tag"

printf 'ansible-playbook curate.yml --tags infra.\n' > "$_ct/repo/README.md"
out="$(_ctrun)"; ec=$?
assert_exit "$ec" 0 "check-ansible-tags: sentence-ending dot is stripped"

printf 'ansible-playbook curate.yml --tags infra\n' > "$_ct/repo/README.md"
cat > "$_ct/bin/ansible-playbook" <<'STUB'
#!/usr/bin/env bash
[ "$1" = "monitoring.yml" ] && { echo "boom" >&2; exit 1; }
echo "      TASK TAGS: [infra]"
STUB
out="$(_ctrun)"; ec=$?
assert_exit "$ec" 2 "check-ansible-tags: one failed listing exits 2"
