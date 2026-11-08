#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ALLOWLIST="${SCRIPT_DIR}/release-allowlist.txt"
TARGET="${1:-${SOURCE_ROOT}/.release-export/BreedOps}"

if [[ ! -f "${SOURCE_ROOT}/README.release.md" ]]; then
  echo "ERROR: README.release.md is missing from BreedOps-dev root." >&2
  exit 1
fi

if [[ ! -f "${SCRIPT_DIR}/LICENSE" ]]; then
  echo "ERROR: release/LICENSE is missing." >&2
  echo "Copy and edit release/LICENSE.proprietary-template first, after confirming the copyright holder." >&2
  exit 1
fi

if [[ "$TARGET" == "$SOURCE_ROOT" || "$TARGET" == "/" ]]; then
  echo "ERROR: refusing unsafe target: $TARGET" >&2
  exit 1
fi

rm -rf "$TARGET"
mkdir -p "$TARGET"

copy_path() {
  local rel="$1"
  local src="${SOURCE_ROOT}/${rel}"
  local dst="${TARGET}/${rel}"

  if [[ ! -e "$src" ]]; then
    echo "ERROR: allowlisted path does not exist: $rel" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$dst")"

  if [[ -d "$src" ]]; then
    mkdir -p "$dst"
    rsync -a --exclude='.git' --exclude='.DS_Store' "$src/" "$dst/"
  else
    cp -p "$src" "$dst"
  fi
}

while IFS= read -r entry || [[ -n "$entry" ]]; do
  [[ -z "$entry" || "$entry" =~ ^[[:space:]]*# ]] && continue
  copy_path "$entry"
done < "$ALLOWLIST"

# Normalize release-only names/layout.
mv "$TARGET/README.release.md" "$TARGET/README.md"
mv "$TARGET/release/LICENSE" "$TARGET/LICENSE"
mv "$TARGET/release/THIRD_PARTY_NOTICES.md" "$TARGET/THIRD_PARTY_NOTICES.md"

rm -rf "$TARGET/docs"
mv "$TARGET/docs-release" "$TARGET/docs"

# release/ is build machinery for BreedOps-dev, not part of the release repository.
rm -rf "$TARGET/release"

# Ensure generated service-worker output is absent before validation/build.
rm -f \
  "$TARGET/public/sw.js" \
  "$TARGET/public/sw.js.map" \
  "$TARGET"/public/swe-worker-*.js \
  "$TARGET"/public/swe-worker-*.js.map 2>/dev/null || true

"${SCRIPT_DIR}/scan-release.sh" "$TARGET"

echo
echo "Release snapshot created:"
echo "  $TARGET"
echo
echo "Next:"
echo "  cd \"$TARGET\""
echo "  npm ci"
echo "  npm run release:check"
