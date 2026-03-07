#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ENV_FILE="${1:-$ROOT_DIR/.env.supabase}"
SCHEMA_FILE="$ROOT_DIR/scripts/supabase/schema.sql"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[error] env file not found: $ENV_FILE" >&2
  echo "Copy $ROOT_DIR/.env.supabase.example -> $ROOT_DIR/.env.supabase and fill values." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "[error] SUPABASE_DB_URL is empty in $ENV_FILE" >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "[error] psql is not installed. Install postgres client first." >&2
  exit 1
fi

echo "[info] applying schema: $SCHEMA_FILE"
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "$SCHEMA_FILE"
echo "[done] schema applied successfully"
