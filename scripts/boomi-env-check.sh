#!/usr/bin/env bash
# Check which .env variables are set without revealing values, and which CLI tools are installed
# Usage: bash scripts/boomi-env-check.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/boomi-common.sh"

load_env

echo "=== .env Variable Status ==="
grep -v '^\s*#' .env | grep -v '^\s*$' | while IFS='=' read -r name _rest; do
  name=$(echo "$name" | xargs)  # trim whitespace
  if var_is_set "$name"; then
    echo "  $name=SET"
  else
    echo "  $name=UNSET"
  fi
done

echo ""
echo "=== Required Tools ==="
missing_tools=0
for tool in curl jq unzip; do
  if command -v "$tool" &>/dev/null; then
    echo "  $tool=INSTALLED"
  else
    echo "  $tool=MISSING"
    missing_tools=1
  fi
done

if (( missing_tools )); then
  echo ""
  echo "WARN: Install the tools marked MISSING before running the CLI tools." >&2
  echo "  curl, jq: required by every tool. unzip: required by boomi-execution-query.sh --logs." >&2
fi
