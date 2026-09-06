#!/usr/bin/env bash
# One-time setup for the App Store Connect MCP.
#
# Run this AFTER creating an API key in App Store Connect:
#   Users and Access > Integrations > Team Keys > +
#   Role: App Manager.  Download the .p8 — Apple allows that exactly once.
#
#   ./scripts/asc-setup.sh ~/Downloads/AuthKey_XXXXXXXXXX.p8 <KEY_ID> <ISSUER_ID>
#
# It moves the key somewhere private, writes the config with tight permissions, and registers
# the MCP server scoped to TestFlight work only.
#
# The .p8 is never copied into the repo, never printed, and never committed. It is moved to
# ~/.keys and locked to your user.
set -euo pipefail

KEY_FILE="${1:-}"
KEY_ID="${2:-}"
ISSUER_ID="${3:-}"

if [[ -z "$KEY_FILE" || -z "$KEY_ID" || -z "$ISSUER_ID" ]]; then
  cat >&2 <<USAGE
Usage: ./scripts/asc-setup.sh <path-to-AuthKey.p8> <KEY_ID> <ISSUER_ID>

Get all three from App Store Connect:
  Users and Access > Integrations > Team Keys
USAGE
  exit 1
fi

if [[ ! -f "$KEY_FILE" ]]; then
  echo "No .p8 at: $KEY_FILE" >&2
  exit 1
fi

mkdir -p ~/.config/asc-mcp ~/.keys
chmod 700 ~/.config/asc-mcp ~/.keys

DEST="$HOME/.keys/$(basename "$KEY_FILE")"
mv "$KEY_FILE" "$DEST"
chmod 600 "$DEST"

# altool will not take a path to the key. It searches a fixed set of directories for a file
# named AuthKey_<KEYID>.p8, so the same key is linked into one of them — which means this one
# credential covers both uploading builds and the MCP, instead of needing two.
mkdir -p ~/.appstoreconnect/private_keys
chmod 700 ~/.appstoreconnect ~/.appstoreconnect/private_keys
ln -sf "$DEST" "$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"

cat > ~/.config/asc-mcp/companies.json <<JSON
{
  "companies": [
    {
      "id": "hmu",
      "name": "HMU, INC.",
      "key_id": "$KEY_ID",
      "issuer_id": "$ISSUER_ID",
      "key_path": "$DEST"
    }
  ]
}
JSON
chmod 600 ~/.config/asc-mcp/companies.json

# Where the upload script finds the IDs. Not secret — the .p8 is the secret, and it stays in
# ~/.keys with 0600.
cat > ~/.config/asc-mcp/asc.env <<ENV
export ASC_KEY_ID=$KEY_ID
export ASC_ISSUER_ID=$ISSUER_ID
ENV
chmod 600 ~/.config/asc-mcp/asc.env

echo "Key stored at $DEST (0600)"
echo "Linked for altool at ~/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"
echo "Config written to ~/.config/asc-mcp/companies.json (0600)"
echo
echo "Registering the MCP server, scoped to TestFlight..."

# Deliberately NOT every worker. The key itself can do anything the role allows, but the
# server only exposes the tools listed here, so an accident cannot reach pricing,
# subscriptions, in-app purchases, users, or provisioning.
#
#   apps              find the app
#   builds            processing state, and the beta sub-workers it pulls in
#   beta_app          "what to test", beta descriptions
#   beta_groups       internal and external tester groups
#   beta_testers      adding and removing people
#   beta_feedback     crash reports and screenshots testers send back
#   pre_release       pre-release versions
#   export_compliance marking a build compliant so it becomes testable
#   reviews           customer reviews, once it is public
WORKERS="apps,builds,beta_app,beta_groups,beta_testers,beta_feedback,pre_release,export_compliance,reviews"

claude mcp remove asc-mcp --scope user >/dev/null 2>&1 || true
claude mcp add --transport stdio --scope user asc-mcp \
  -- "$HOME/.mint/bin/asc-mcp" --workers "$WORKERS"

echo
echo "Done. Two things now work with that one key:"
echo "  ./scripts/testflight.sh --upload   builds and uploads"
echo "  the asc-mcp server                 testers, feedback, reviews"
echo
echo "Restart Claude Code so it picks up the MCP server."
