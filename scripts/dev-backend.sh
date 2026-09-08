#!/usr/bin/env bash
# The whole backend on this machine, for nothing.
#
#   ./scripts/dev-backend.sh                start Postgres + Auth (Docker) and the presence worker
#   ./scripts/dev-backend.sh --config-only  just write the two local config files and exit
#   ./scripts/dev-backend.sh --stop         stop the containers
#
# Nothing here needs an account. Supabase runs in Docker via the CLI; the Cloudflare worker
# and its Durable Objects run in Miniflare via `wrangler dev`. Both are the same code that
# would deploy, minus the bill.
#
# Secrets: this script copies the LOCAL keys -- the ones every `supabase start` on earth
# shares -- into two gitignored files, and never prints them. It does not know about, and
# must never be pointed at, a hosted project.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--stop" ]]; then
  supabase stop
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running. Start Docker Desktop and run this again." >&2
  exit 1
fi

# --- Postgres, Auth, PostgREST ----------------------------------------------------------
if ! supabase status >/dev/null 2>&1; then
  echo "Starting Supabase (first run pulls images; a minute or two)..."
  supabase start >/dev/null
fi
echo "Supabase up."

# `supabase status -o env` prints KEY=VALUE lines. Everything below reads from that and
# writes to files; no value ever reaches a terminal.
status="$(supabase status -o env)"
value() { printf '%s\n' "$status" | sed -n "s/^$1=\"\{0,1\}\([^\"]*\)\"\{0,1\}$/\1/p" | head -1; }

api_url="$(value API_URL)"

# --- the worker's local secrets ---------------------------------------------------------
cat > worker/.dev.vars <<VARS
SUPABASE_URL=${api_url}
SUPABASE_SERVICE_ROLE_KEY=$(value SERVICE_ROLE_KEY)
SUPABASE_JWT_SECRET=$(value JWT_SECRET)
VARS
echo "worker/.dev.vars written (gitignored)."

# --- the app's local config ------------------------------------------------------------
# Rewritten only if this script wrote it. A hand-edited one -- say, pointed at a hosted
# project -- is left alone.
xcconfig="ios/ChinGo/Secrets.xcconfig"
marker="// Written by scripts/dev-backend.sh"
if [[ ! -f "$xcconfig" ]] || head -1 "$xcconfig" | grep -q "^${marker}"; then
  # xcconfig treats // as a comment. $() is an empty substitution; placing it between the
  # two slashes is the documented workaround (before them does not work -- tested).
  scheme="${api_url%%://*}"
  host="${api_url#*://}"
  cat > "$xcconfig" <<XC
${marker} for the LOCAL stack. Gitignored. Replace, or delete, when hosted.
SUPABASE_URL = ${scheme}:/\$()/${host}
SUPABASE_ANON_KEY = $(value ANON_KEY)
TILE_BASE_URL =
XC
  echo "$xcconfig written (gitignored). Run 'cd ios && xcodegen generate' once."
fi

if [[ "${1:-}" == "--config-only" ]]; then
  exit 0
fi

# --- the presence worker ---------------------------------------------------------------
if [[ ! -d worker/node_modules ]]; then
  (cd worker && npm install --no-audit --no-fund)
fi
echo
echo "Presence worker on http://127.0.0.1:8787  (Ctrl-C stops it; Supabase keeps running)"
echo "Prove it end to end in another terminal:  node scripts/smoke-presence.mjs"
echo
cd worker && exec npx wrangler dev --port 8787
