#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
assets_dir="$root_dir/Sources/JSBeautify/Assets"

log() {
  printf "%s\n" "$*"
}

die() {
  printf "Error: %s\n" "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_cmd curl
require_cmd git
require_cmd python3

if ! git -C "$root_dir" diff --quiet || ! git -C "$root_dir" diff --cached --quiet; then
  die "Working tree is dirty. Please commit or stash changes first."
fi

latest_version="$({
  curl -fsSL "https://api.cdnjs.com/libraries/js-beautify?fields=version";
} | python3 -c 'import json,sys; payload=json.load(sys.stdin); v=payload.get("version"); print(v) if v else sys.exit(1)')" \
  || die "Failed to determine latest version from cdnjs."

branch_name="update-js-beautify-${latest_version}"

log "Latest version: ${latest_version}"

if git -C "$root_dir" show-ref --verify --quiet "refs/heads/${branch_name}"; then
  die "Branch already exists: ${branch_name}"
fi

work_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

log "Downloading assets to ${work_dir}"

curl -fsSL "https://cdnjs.cloudflare.com/ajax/libs/js-beautify/${latest_version}/beautify.min.js" \
  -o "$work_dir/beautify.min.js"
curl -fsSL "https://cdnjs.cloudflare.com/ajax/libs/js-beautify/${latest_version}/beautify-css.min.js" \
  -o "$work_dir/beautify-css.min.js"
curl -fsSL "https://cdnjs.cloudflare.com/ajax/libs/js-beautify/${latest_version}/beautify-html.min.js" \
  -o "$work_dir/beautify-html.min.js"
curl -fsSL "https://raw.githubusercontent.com/beautifier/js-beautify/v${latest_version}/LICENSE" \
  -o "$work_dir/JSBeautify-LICENSE"

if cmp -s "$assets_dir/beautify.min.js" "$work_dir/beautify.min.js" && \
   cmp -s "$assets_dir/beautify-css.min.js" "$work_dir/beautify-css.min.js" && \
   cmp -s "$assets_dir/beautify-html.min.js" "$work_dir/beautify-html.min.js" && \
   cmp -s "$assets_dir/JSBeautify-LICENSE" "$work_dir/JSBeautify-LICENSE"; then
  log "Assets are already up to date."
  exit 0
fi

log "Creating branch ${branch_name}"
git -C "$root_dir" checkout -b "$branch_name"

log "Updating assets"
cp "$work_dir/beautify.min.js" "$assets_dir/beautify.min.js"
cp "$work_dir/beautify-css.min.js" "$assets_dir/beautify-css.min.js"
cp "$work_dir/beautify-html.min.js" "$assets_dir/beautify-html.min.js"
cp "$work_dir/JSBeautify-LICENSE" "$assets_dir/JSBeautify-LICENSE"

export ROOT_DIR="$root_dir"
export LATEST_VERSION="$latest_version"
python3 - <<'PY'
import os
import pathlib

root = pathlib.Path(os.environ["ROOT_DIR"])
latest_version = os.environ["LATEST_VERSION"]
readme = root / "README.md"
if readme.exists():
    text = readme.read_text(encoding="utf-8")
    text = text.replace("(1.14.9)", f"({latest_version})")
    readme.write_text(text, encoding="utf-8")
PY

log "Running tests"
( cd "$root_dir" && swift test )

log "Committing changes"
git -C "$root_dir" add "$assets_dir" "$root_dir/README.md" || true
git -C "$root_dir" commit -m "Update js-beautify assets to ${latest_version}"

if git -C "$root_dir" rev-parse "v${latest_version}" >/dev/null 2>&1; then
  die "Tag v${latest_version} already exists"
fi

git -C "$root_dir" tag -a "v${latest_version}" -m "js-beautify ${latest_version}"

if git -C "$root_dir" remote get-url origin >/dev/null 2>&1; then
  log "Pushing branch and tag"
  git -C "$root_dir" push -u origin "$branch_name"
  git -C "$root_dir" push origin "v${latest_version}"
else
  die "No git remote named origin."
fi

if command -v gh >/dev/null 2>&1; then
  log "Creating PR"
  gh pr create \
    --repo "$(git -C "$root_dir" remote get-url origin)" \
    --title "Update js-beautify to ${latest_version}" \
    --body "Updates bundled js-beautify assets to ${latest_version}." \
    --head "$branch_name"
else
  die "GitHub CLI (gh) not found. Install gh to create a PR."
fi
