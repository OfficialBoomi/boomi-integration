#!/usr/bin/env bash
# Check which .env variables are set without revealing values
# Usage: bash scripts/boomi-env-check.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/boomi-common.sh"

load_env

echo "=== .env Variable Status ==="
grep -v '^\s*#' .env | grep -v '^\s*$' | while IFS='=' read -r name _rest; do
  name=$(echo "$name" | xargs)  # trim whitespace
  if [[ -n "${!name:-}" ]]; then
    echo "  $name=SET"
  else
    echo "  $name=UNSET"
  fi
done
