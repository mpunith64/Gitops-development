#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || (cd "$SCRIPT_DIR/../../../.." && pwd))"

echo "=== Helm Chart Linting ==="
echo "Repository Root: $REPO_ROOT"

FAILED=0
CHARTS=()

while IFS= read -r -d '' file; do
  CHARTS+=("$(dirname "$file")")
done < <(find "$REPO_ROOT" -name "Chart.yaml" -not -path "*/.*/*" -print0)

for chart in "${CHARTS[@]}"; do
  rel="${chart#$REPO_ROOT/}"
  echo ""
  echo "Linting chart: $rel ..."
  if helm lint "$chart"; then
    echo "[PASS] $rel"
  else
    echo "[FAIL] $rel"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "----------------------------------------"
if [ "$FAILED" -eq 0 ]; then
  echo "All ${#CHARTS[@]} chart(s) passed linting successfully!"
  exit 0
else
  echo "$FAILED chart(s) failed linting."
  exit 1
fi
