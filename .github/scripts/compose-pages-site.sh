#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${1:?output directory is required}"
CURRENT_BUILD_DIR="${2:?current build directory is required}"
SOURCE_EVENT="${3:?source event is required}"
CURRENT_PR_NUMBER="${4:-}"
CURRENT_HEAD_SHA="${5:-unknown}"

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GH_TOKEN:?GH_TOKEN is required}"

DEFAULT_BRANCH="${DEFAULT_BRANCH:-master}"

write_unpublished_root() {
  mkdir -p "$OUTPUT_DIR"
  cat > "$OUTPUT_DIR/index.html" <<'EOF'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Orbital Cleanup Co.</title></head>
<body><main><h1>Orbital Cleanup Co.</h1><p>Production build not published yet.</p></main></body>
</html>
EOF
}

restore_production_root() {
  local run_id
  run_id="$(gh run list --repo "$GITHUB_REPOSITORY" --workflow web.yml --branch "$DEFAULT_BRANCH" --event push --status success --limit 1 --json databaseId --jq '.[0].databaseId // empty' || true)"
  if [[ -z "$run_id" ]]; then
    write_unpublished_root
    return
  fi

  mkdir -p /tmp/occ-production
  rm -rf /tmp/occ-production/*

  # New lean pipeline artifact first; old name is kept as a one-release
  # compatibility fallback so the migration PR still gets a playable preview.
  if ! gh run download "$run_id" --repo "$GITHUB_REPOSITORY" --name occ-web-production --dir /tmp/occ-production 2>/dev/null; then
    gh run download "$run_id" --repo "$GITHUB_REPOSITORY" --name occ-web-build --dir /tmp/occ-production 2>/dev/null || true
  fi

  if [[ -s /tmp/occ-production/index.html ]]; then
    cp -a /tmp/occ-production/. "$OUTPUT_DIR/"
  else
    write_unpublished_root
  fi
}

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

if [[ "$SOURCE_EVENT" == "push" ]]; then
  cp -a "$CURRENT_BUILD_DIR/." "$OUTPUT_DIR/"
else
  restore_production_root
  preview_dir="$OUTPUT_DIR/pr-${CURRENT_PR_NUMBER}"
  mkdir -p "$preview_dir"
  cp -a "$CURRENT_BUILD_DIR/." "$preview_dir/"
  cat > "$preview_dir/preview-build.txt" <<EOF
Orbital Cleanup Co. pull request preview
PR: #${CURRENT_PR_NUMBER}
Commit: ${CURRENT_HEAD_SHA}
Provider: debug
EOF
fi

test -s "$OUTPUT_DIR/index.html"
if [[ "$SOURCE_EVENT" == "push" ]]; then
  test -s "$OUTPUT_DIR/index.wasm"
else
  test -s "$OUTPUT_DIR/pr-${CURRENT_PR_NUMBER}/index.wasm"
fi
