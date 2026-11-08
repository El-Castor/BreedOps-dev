#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DENYLIST="${SCRIPT_DIR}/release-denylist.txt"
PATTERNS="${SCRIPT_DIR}/forbidden-patterns.txt"

if [[ -z "$TARGET" || ! -d "$TARGET" ]]; then
  echo "Usage: $0 <release-snapshot-directory>" >&2
  exit 2
fi

TARGET="$(cd "$TARGET" && pwd)"
echo "Scanning release snapshot: $TARGET"

failed=0

while IFS= read -r entry || [[ -n "$entry" ]]; do
  [[ -z "$entry" || "$entry" =~ ^[[:space:]]*# ]] && continue
  if [[ -e "$TARGET/$entry" ]]; then
    echo "ERROR: denied path present: $entry" >&2
    failed=1
  fi
done < "$DENYLIST"

# No nested Git metadata may be exported.
if find "$TARGET" -name .git -print -quit | grep -q .; then
  echo "ERROR: nested .git metadata found in release snapshot." >&2
  failed=1
fi

# Search only text-like source/documentation/configuration files.
while IFS= read -r pattern || [[ -n "$pattern" ]]; do
  [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
  if grep -RInIi \
      --exclude='package-lock.json' \
      --exclude='scan-report.txt' \
      --exclude='LICENSE' \
      -- "$pattern" "$TARGET" >/tmp/breedops-release-scan.$$ 2>/dev/null; then
    echo "ERROR: forbidden internal reference found: $pattern" >&2
    cat /tmp/breedops-release-scan.$$ >&2
    failed=1
  fi
done < "$PATTERNS"
rm -f /tmp/breedops-release-scan.$$ || true

# Common secret-shaped files.
if find "$TARGET" -type f \( \
    -name '.env' -o \
    -name '.env.local' -o \
    -name '*.pem' -o \
    -name '*.key' -o \
    -name '*.p12' -o \
    -name '*.pfx' \
  \) -print | grep -q .; then
  echo "ERROR: credential-like file found in snapshot." >&2
  find "$TARGET" -type f \( \
    -name '.env' -o \
    -name '.env.local' -o \
    -name '*.pem' -o \
    -name '*.key' -o \
    -name '*.p12' -o \
    -name '*.pfx' \
  \) -print >&2
  failed=1
fi

if [[ ! -f "$TARGET/LICENSE" ]]; then
  echo "ERROR: LICENSE is missing." >&2
  failed=1
fi

if [[ ! -f "$TARGET/README.md" ]]; then
  echo "ERROR: README.md is missing." >&2
  failed=1
fi

if [[ "$failed" -ne 0 ]]; then
  echo "RELEASE SCAN: FAIL" >&2
  exit 1
fi

echo "RELEASE SCAN: PASS"
