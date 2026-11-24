#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "=========================================="
echo "   GitOps Repository Validation Suite     "
echo "=========================================="
echo "Repository Root: $REPO_ROOT"

FAILED=0
TOTAL=0

# Step 1: Validate JSON files
echo ""
echo "[1/3] Validating JSON files..."
for f in "$REPO_ROOT"/argocd/package-*.json; do
  [ -f "$f" ] || continue
  TOTAL=$((TOTAL + 1))
  name="$(basename "$f")"
  if command -v jq >/dev/null 2>&1; then
    if jq . "$f" >/dev/null 2>&1; then
      echo "  [PASS] $name"
    else
      echo "  [FAIL] $name"
      FAILED=$((FAILED + 1))
    fi
  else
    echo "  [SKIP] jq not installed, skipping $name"
  fi
done

# Step 2: Lint Helm charts
echo ""
echo "[2/3] Linting Helm charts..."
while IFS= read -r -d '' chart; do
  TOTAL=$((TOTAL + 1))
  dir="$(dirname "$chart")"
  rel="${dir#$REPO_ROOT/}"
  if helm lint "$dir" >/dev/null 2>&1; then
    echo "  [PASS] $rel"
  else
    echo "  [FAIL] $rel"
    FAILED=$((FAILED + 1))
  fi
done < <(find "$REPO_ROOT" -name "Chart.yaml" -not -path "*/.*/*" -print0)

# Step 3: Render ArgoCD templates
echo ""
echo "[3/3] Testing ArgoCD template rendering..."
for env_file in "$REPO_ROOT"/argocd/values-*.yaml; do
  [ -f "$env_file" ] || continue
  TOTAL=$((TOTAL + 1))
  env_name="$(basename "$env_file" .yaml)"
  env_name="${env_name#values-}"
  if helm template "$REPO_ROOT/argocd" -f "$REPO_ROOT/argocd/values.yaml" -f "$env_file" >/dev/null 2>&1; then
    echo "  [PASS] argocd ($env_name)"
  else
    echo "  [FAIL] argocd ($env_name)"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "=========================================="
if [ "$FAILED" -eq 0 ]; then
  echo "Validation SUCCEEDED: All $TOTAL checks passed!"
  echo "=========================================="
  exit 0
else
  echo "Validation FAILED: $FAILED of $TOTAL checks failed."
  echo "=========================================="
  exit 1
fi
