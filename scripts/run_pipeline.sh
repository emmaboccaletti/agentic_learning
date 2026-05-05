#!/usr/bin/env bash
# Run the full four-stage pipeline end-to-end, manually-spawned style.
# Each stage is a separate Hermes session.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Ensure venv is active so agents inherit pandas/xgboost.
if [[ -z "${VIRTUAL_ENV:-}" ]]; then
  if [[ -f .venv/bin/activate ]]; then
    # shellcheck disable=SC1091
    source .venv/bin/activate
  else
    echo "error: no venv active and .venv/ not found" >&2
    exit 1
  fi
fi

stage() {
  local n="$1" role="$2" toolsets="$3" prompt="$4"
  echo
  echo "=========================================================="
  echo "  $n. $role"
  echo "  prompt: $prompt"
  echo "=========================================================="
  date
  hermes -p "$role" chat -t "$toolsets" -q "$prompt" --yolo
  date
}

INPUT="${1:-data/raw/telco-churn.csv}"
TARGET="${2:-Churn}"

stage "1/4" preprocessor terminal,file "Process $INPUT with target=$TARGET"
stage "2/4" architect    file          "Read data/clean/profile.json and queue 2-3 configs"
stage "3/4" trainer      terminal,file "Drain runs/queue/"
stage "4/4" reporter     terminal,file "Render the final report"

echo
echo "=========================================================="
echo "  DONE"
echo "=========================================================="
ls -la reports/ 2>/dev/null || echo "(no reports/)"
