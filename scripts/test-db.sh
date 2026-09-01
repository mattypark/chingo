#!/usr/bin/env bash
# ChinGo — prove the database, not the client, is what keeps people safe.
#
# Runs supabase/tests/rls_test.sql inside the local Postgres container. The whole thing is
# wrapped in a transaction that rolls back, so it leaves nothing behind and is safe to run
# against a database you are actively developing on.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! docker ps --format '{{.Names}}' | grep -q '^supabase_db_chingo$'; then
  echo "ChinGo's database isn't running. Start it with:  supabase start" >&2
  exit 1
fi

output=$(docker exec -i supabase_db_chingo \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -f - \
  < supabase/tests/rls_test.sql 2>&1)

echo "$output" | grep -E 'PASS|FAIL|ERROR' | sed 's/^psql:<stdin>:[0-9]*: NOTICE:  //'

if echo "$output" | grep -qE 'FAIL|ERROR'; then
  echo
  echo "RLS tests failed. Do not ship this." >&2
  exit 1
fi
