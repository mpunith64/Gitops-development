#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <environment> <service> <new-version>"
  echo "Example: $0 pre-prod website 0.2.0"
  exit 1
fi

ENV="$1"
SERVICE="$2"
VERSION="$3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || (cd "$SCRIPT_DIR/../../../.." && pwd))"
PACKAGE_FILE="$REPO_ROOT/argocd/package-$ENV.json"

echo "=== GitOps Service Version Promotion ==="
echo "Repository Root: $REPO_ROOT"
echo "Environment    : $ENV"
echo "Service        : $SERVICE"
echo "New Version    : $VERSION"

if [ ! -f "$PACKAGE_FILE" ]; then
  echo "Error: Package file not found: $PACKAGE_FILE" >&2
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  tmp=$(mktemp)
  jq --arg svc "$SERVICE" --arg ver "$VERSION" '.services[$svc] = $ver' "$PACKAGE_FILE" > "$tmp" && mv "$tmp" "$PACKAGE_FILE"
  echo "Successfully updated $PACKAGE_FILE using jq."
else
  echo "jq not found, attempting python fallback..."
  python3 -c "import json; p='$PACKAGE_FILE'; data=json.load(open(p)); data.setdefault('services',{})['$SERVICE']='$VERSION'; json.dump(data, open(p,'w'), indent=2)"
  echo "Successfully updated $PACKAGE_FILE using python."
fi
