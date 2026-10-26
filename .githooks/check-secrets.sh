#!/usr/bin/env bash
# Blocks sensitive files and secret-looking content from entering Git.
# Usage: check-secrets.sh staged            (pre-commit: staged changes)
#        check-secrets.sh range <git-range> (pre-push and CI: every commit in range)
set -u

# File names that must never be tracked. Matched against the full path.
BLOCKED_PATHS='(^|/)\.env($|\.)|(^|/)\.ai-brain(/|$)|(^|/)(CLAUDE|AGENTS|NEXT-SESSION)\.md$|\.(pem|key|p12|pfx|jks|keystore|mobileprovision|cer|der|crt|ppk|gpg|asc|kdbx)$|(^|/)id_(rsa|dsa|ecdsa|ed25519)|(^|/)(auth|credentials|secrets?|service-account[^/]*|serviceAccount[^/]*)\.json$|(^|/)google-services\.json$|(^|/)GoogleService-Info\.plist$|(^|/)key\.properties$|(^|/)\.netrc$|(^|/)\.htpasswd$|\.(sqlite|sqlite3|db)$|\.(sql|dump)(\.gz)?$|(^|/)\.(aws|ssh|kube)(/|$)'
ALLOWED_PATHS='(^|/)\.env\.example$'

# Content that looks like a real secret.
SECRET_PATTERNS='-----BEGIN ([A-Z]+ )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|gh[ousr]_[A-Za-z0-9]{30,}|xox[abprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|sk_live_[0-9A-Za-z]{16,}|sk-[A-Za-z0-9]{32,}|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|APP_KEY=base64:[A-Za-z0-9+/=]{20,}|[a-z]+://[^/[:space:]:@]+:[^/[:space:]@]{4,}@[^/[:space:]]+'
# Looser rule: a quoted value of 16+ characters assigned to a secret-like name. Skipped in docs.
GENERIC_PATTERN='(password|passwd|secret|token|api[_-]?key|private[_-]?key|auth[_-]?token)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9/+=_.-]{16,}["'"'"']'
# Fake-looking lines the loose rule may skip. `secret-scan:ignore` on a line allows it on purpose.
PLACEHOLDERS='example|placeholder|changeme|your[_-]|xxxx|<[a-z_ -]+>|\$\{|env\(|config\('
IGNORE_MARK='secret-scan:ignore'

# A pipe runs loops in a subshell, so failures are recorded in a file.
FAILFILE="$(mktemp)"
trap 'rm -f "$FAILFILE"' EXIT

report() { echo "BLOCKED: $1" >&2; echo 1 >> "$FAILFILE"; }

scan_paths() {
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    if echo "$path" | grep -Eq "$ALLOWED_PATHS"; then continue; fi
    if echo "$path" | grep -Eq "$BLOCKED_PATHS"; then
      report "sensitive file: $path"
    fi
  done
}

scan_content() {
  local file="" line
  while IFS= read -r line; do
    case "$line" in
      "+++ b/"*) file="${line#+++ b/}" ;;
      "+++ "*) ;;
      "+"*)
        case "$file" in composer.lock|*/composer.lock|package-lock.json|*/package-lock.json) continue ;; esac
        body="${line#+}"
        case "$body" in *"$IGNORE_MARK"*) continue ;; esac
        if echo "$body" | grep -Eq -e "$SECRET_PATTERNS"; then
          report "possible secret in ${file:-unknown}: $(echo "$body" | cut -c1-60)..."
        elif [[ "$file" != *.md ]] && echo "$body" | grep -Eqi -e "$GENERIC_PATTERN" && ! echo "$body" | grep -Eqi -e "$PLACEHOLDERS"; then
          report "possible secret in ${file:-unknown}: $(echo "$body" | cut -c1-60)..."
        fi
        ;;
    esac
  done
}

case "${1:-}" in
  staged)
    git diff --cached --name-only --diff-filter=ACMR | scan_paths
    git diff --cached -U0 --no-color --diff-filter=ACMR | scan_content
    ;;
  range)
    range="${2:?range required}"
    git log --name-only --format= --diff-filter=ACMR $range | sort -u | scan_paths
    git log -p -U0 --no-color --format= --diff-filter=ACMR $range | scan_content
    ;;
  *)
    echo "usage: $0 staged | range <git-range>" >&2
    exit 2
    ;;
esac

if [ -s "$FAILFILE" ]; then
  echo "" >&2
  echo "Commit or push stopped. Remove the secret, rotate it if it was ever real, then try again." >&2
  exit 1
fi
