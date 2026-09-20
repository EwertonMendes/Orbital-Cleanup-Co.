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
ARTIFACT_NAME="occ-web-build"

find_successful_pr_run() {
  local head_sha="$1"
  gh api     "repos/${GITHUB_REPOSITORY}/actions/workflows/web.yml/runs?event=pull_request&head_sha=${head_sha}&status=success&per_page=10"     --jq '.workflow_runs[0].id // empty' 2>/dev/null || true
}

write_unpublished_root() {
  mkdir -p "$OUTPUT_DIR"
  cat > "$OUTPUT_DIR/index.html" <<'EOF'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Orbital Cleanup Co.</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#071424;color:#eaf8ff;font:16px system-ui,sans-serif}.card{max-width:620px;margin:24px;padding:32px;border:1px solid #2d6c83;border-radius:20px;background:#0a1c2b}.tag{color:#9af8d7;font-weight:800;letter-spacing:.12em;font-size:12px}h1{font-size:42px;margin:10px 0}.muted{color:#9fb6c2}</style></head>
<body><main class="card"><div class="tag">ORBITAL CLEANUP CO. // PRODUCTION</div><h1>Production build not published yet.</h1><p class="muted">The first playable build is being reviewed in a pull request preview. Production remains intentionally empty until that PR is approved and merged.</p></main></body>
</html>
EOF
}

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

if [[ "$SOURCE_EVENT" == "push" ]]; then
  cp -a "$CURRENT_BUILD_DIR/." "$OUTPUT_DIR/"
else
  MASTER_RUN_ID="$(gh run list     --repo "$GITHUB_REPOSITORY"     --workflow web.yml     --branch "$DEFAULT_BRANCH"     --event push     --status success     --limit 1     --json databaseId     --jq '.[0].databaseId // empty' || true)"

  if [[ -n "$MASTER_RUN_ID" ]]; then
    mkdir -p /tmp/occ-production
    rm -rf /tmp/occ-production/*
    gh run download "$MASTER_RUN_ID"       --repo "$GITHUB_REPOSITORY"       --name "$ARTIFACT_NAME"       --dir /tmp/occ-production
    cp -a /tmp/occ-production/. "$OUTPUT_DIR/"
  else
    echo "::notice::No successful production Web build exists yet; publishing an intentional placeholder root."
    write_unpublished_root
  fi
fi

echo "Restoring previews for open same-repository pull requests."
while IFS=$'\t' read -r pr_number head_sha head_repo; do
  [[ -n "$pr_number" && -n "$head_sha" && -n "$head_repo" ]] || continue
  [[ "$head_repo" == "$GITHUB_REPOSITORY" ]] || continue
  [[ -z "$CURRENT_PR_NUMBER" || "$pr_number" != "$CURRENT_PR_NUMBER" ]] || continue

  run_id="$(find_successful_pr_run "$head_sha")"
  if [[ -z "$run_id" ]]; then
    echo "::warning::No successful Web build found for open PR #${pr_number} at ${head_sha}; skipping."
    continue
  fi

  preview_dir="$OUTPUT_DIR/pr-${pr_number}"
  rm -rf "$preview_dir"
  mkdir -p "$preview_dir"
  if ! gh run download "$run_id" --repo "$GITHUB_REPOSITORY" --name "$ARTIFACT_NAME" --dir "$preview_dir"; then
    rm -rf "$preview_dir"
    echo "::warning::Could not restore preview artifact for PR #${pr_number}."
    continue
  fi
done < <(
  gh api --paginate "repos/${GITHUB_REPOSITORY}/pulls?state=open&per_page=100"     --jq '.[] | [.number, .head.sha, .head.repo.full_name] | @tsv'
)

if [[ -n "$CURRENT_PR_NUMBER" ]]; then
  preview_dir="$OUTPUT_DIR/pr-${CURRENT_PR_NUMBER}"
  rm -rf "$preview_dir"
  mkdir -p "$preview_dir"
  cp -a "$CURRENT_BUILD_DIR/." "$preview_dir/"
  cat > "$preview_dir/preview-build.txt" <<EOF
Orbital Cleanup Co. pull request preview
PR: #${CURRENT_PR_NUMBER}
Commit: ${CURRENT_HEAD_SHA}
Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
Provider: debug
EOF
fi

test -s "$OUTPUT_DIR/index.html"
if [[ "$SOURCE_EVENT" == "push" ]]; then
  test -s "$OUTPUT_DIR/index.wasm"
fi

echo "Pages site composed successfully."
find "$OUTPUT_DIR" -maxdepth 1 -mindepth 1 -type d -name 'pr-*' -printf '%f\n' | sort -V || true
