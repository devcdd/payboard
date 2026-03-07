#!/usr/bin/env bash
set -euo pipefail

print_usage() {
  cat <<'USAGE'
Generate Sign in with Apple client secret (JWT) for Supabase.

Usage:
  ./scripts/supabase/generate_apple_client_secret.sh \
    --team-id <APPLE_TEAM_ID> \
    --key-id <APPLE_KEY_ID> \
    --client-id <APPLE_SERVICES_ID> \
    --p8-file <PATH_TO_AUTHKEY_P8> \
    [--expires-days 180] \
    [--out /path/to/client_secret.txt]

Required:
  --team-id      Apple Developer Team ID
  --key-id       Apple Sign in with Apple Key ID
  --client-id    Apple Services ID (used as client_id / sub)
  --p8-file      Path to AuthKey_XXXXXX.p8

Optional:
  --expires-days JWT lifetime in days (max 180, default: 180)
  --out          Write token to file instead of stdout
USAGE
}

TEAM_ID=""
KEY_ID=""
CLIENT_ID=""
P8_FILE=""
EXPIRES_DAYS="180"
OUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-id)
      TEAM_ID="${2:-}"
      shift 2
      ;;
    --key-id)
      KEY_ID="${2:-}"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="${2:-}"
      shift 2
      ;;
    --p8-file)
      P8_FILE="${2:-}"
      shift 2
      ;;
    --expires-days)
      EXPIRES_DAYS="${2:-}"
      shift 2
      ;;
    --out)
      OUT_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "[error] unknown argument: $1" >&2
      print_usage
      exit 1
      ;;
  esac
done

if [[ -z "$TEAM_ID" || -z "$KEY_ID" || -z "$CLIENT_ID" || -z "$P8_FILE" ]]; then
  echo "[error] missing required arguments" >&2
  print_usage
  exit 1
fi

if [[ ! -f "$P8_FILE" ]]; then
  echo "[error] p8 file not found: $P8_FILE" >&2
  exit 1
fi

if ! [[ "$EXPIRES_DAYS" =~ ^[0-9]+$ ]]; then
  echo "[error] --expires-days must be a positive integer" >&2
  exit 1
fi

if (( EXPIRES_DAYS < 1 || EXPIRES_DAYS > 180 )); then
  echo "[error] --expires-days must be between 1 and 180" >&2
  exit 1
fi

if ! command -v ruby >/dev/null 2>&1; then
  echo "[error] ruby is required but not found" >&2
  exit 1
fi

JWT_TOKEN="$(
  ruby - "$TEAM_ID" "$KEY_ID" "$CLIENT_ID" "$P8_FILE" "$EXPIRES_DAYS" <<'RUBY'
require 'openssl'
require 'json'
require 'base64'

team_id, key_id, client_id, p8_file, expires_days = ARGV

now = Time.now.to_i
exp = now + (expires_days.to_i * 24 * 60 * 60)

header = {
  alg: 'ES256',
  kid: key_id
}

payload = {
  iss: team_id,
  iat: now,
  exp: exp,
  aud: 'https://appleid.apple.com',
  sub: client_id
}

def base64url(data)
  Base64.strict_encode64(data).tr('+/', '-_').delete('=')
end

header_part = base64url(header.to_json)
payload_part = base64url(payload.to_json)
signing_input = "#{header_part}.#{payload_part}"

private_key = OpenSSL::PKey::EC.new(File.read(p8_file))
signature = private_key.dsa_sign_asn1(signing_input)
signature_part = base64url(signature)

puts "#{signing_input}.#{signature_part}"
RUBY
)"

if [[ -n "$OUT_FILE" ]]; then
  printf '%s\n' "$JWT_TOKEN" > "$OUT_FILE"
  echo "[done] client secret written to: $OUT_FILE"
else
  printf '%s\n' "$JWT_TOKEN"
fi
