#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-pre-prod}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || (cd "$SCRIPT_DIR/../../../.." && pwd))"
CHART_DIR="$REPO_ROOT/argocd"

echo "=== ArgoCD Helm Template Validation ==="
echo "Repository Root: $REPO_ROOT"
echo "Target Chart   : $CHART_DIR"
echo "Environment    : $ENV"

VALUES_DEFAULT="$CHART_DIR/values.yaml"
VALUES_ENV="$CHART_DIR/values-$ENV.yaml"
PACKAGE_FILE="$CHART_DIR/package-$ENV.json"

if [ ! -f "$VALUES_DEFAULT" ]; then
  echo "Error: Default values not found at $VALUES_DEFAULT" >&2
  exit 1
fi

if [ ! -f "$VALUES_ENV" ]; then
  echo "Error: Environment values not found at $VALUES_ENV" >&2
  exit 1
fi

if [ ! -f "$PACKAGE_FILE" ]; then
  echo "Error: Package file not found at $PACKAGE_FILE" >&2
  exit 1
fi

echo "Validating package JSON..."
if command -v jq >/dev/null 2>&1; then
  jq . "$PACKAGE_FILE" > /dev/null
  echo "JSON syntax is valid."
fi

echo "Rendering templates..."
helm template "$CHART_DIR" -f "$VALUES_DEFAULT" -f "$VALUES_ENV"
echo "ArgoCD template render successful for $ENV!"
