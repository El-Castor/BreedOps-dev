#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
if [[ -z "$TARGET" || ! -d "$TARGET" ]]; then
  echo "Usage: $0 <release-snapshot-directory>" >&2
  exit 2
fi

TARGET="$(cd "$TARGET" && pwd)"

python3 - "$TARGET" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])

# Only text/source files. Binary assets are intentionally untouched.
extensions = {
    ".ts", ".tsx", ".js", ".mjs", ".cjs", ".json", ".sql", ".R",
    ".md", ".yml", ".yaml", ".toml", ".txt"
}
names = {
    "tsconfig.json", "eslint.config.js", "package.json", ".gitignore",
    ".env.example"
}

# Neutral replacements. These remove internal provenance references without
# altering executable semantics.
replacements = [
    ("CLAUDE.md", "the versioned migration policy"),
    ("PROMPT.md", "the BreedOps functional specification"),
    ("agend.md", "the BreedOps design rationale"),
    ("AGENTS.md", "the project contribution rules"),
]

for path in root.rglob("*"):
    if not path.is_file():
        continue
    if path.suffix not in extensions and path.name not in names:
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue

    original = text
    for old, new in replacements:
        text = text.replace(old, new)

    # Release config should not carry exclusions for development-only agent
    # directories that are absent from the distribution.
    if path.name == "tsconfig.json":
        for token in [
            '    ".beads",\n',
            '    ".beads.backup-20260827",\n',
            '    ".serena",\n',
        ]:
            text = text.replace(token, "")

    if path.name == "eslint.config.js":
        for token in [
            '      ".beads/**",\n',
            '      ".beads.backup-20260827/**",\n',
            '      ".serena/**",\n',
        ]:
            text = text.replace(token, "")

    if text != original:
        path.write_text(text, encoding="utf-8")

PY

echo "Release sanitization complete: $TARGET"
