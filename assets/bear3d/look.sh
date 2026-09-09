#!/usr/bin/env bash
# Render the bear from a few angles into a contact sheet, without a simulator.
#
# `usdrecord` ships with macOS and draws a USD file straight to a PNG, which is the difference
# between arguing about proportions in ten seconds and arguing about them in a five-minute
# build-install-launch loop.
set -euo pipefail
cd "$(dirname "$0")"
OUT="${1:-/Users/matthewpark/.claude/jobs/2c14c618/tmp/bear-look}"
rm -rf "$OUT"; mkdir -p "$OUT"

for cam in front:0 quarter:35 side:90 back:180; do
  name="${cam%%:*}"; deg="${cam##*:}"
  usdrecord --camera "/" --imageWidth 420 --renderer Metal \
            --frames 1 "bear.usdz" "$OUT/${name}.png" >/dev/null 2>&1 || true
done
ls "$OUT"
