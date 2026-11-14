#!/usr/bin/env bash
# Download Sonarr's iCal feed, commit it if it changed, and push.
# Config comes from .env next to this script (gitignored):
#   SONARR_API_KEY=...
# Set DRY_RUN=1 to fetch and compare without committing or pushing.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$REPO_DIR/Sonarr.ics"

ENV_FILE="$REPO_DIR/.env"
[[ -f "$ENV_FILE" ]] || { echo "missing config: $ENV_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
. "$ENV_FILE"
: "${SONARR_API_KEY:?SONARR_API_KEY not set}"

FEED_URL="https://sonarr.home.joejr.dev/feed/v3/calendar/Sonarr.ics?apikey=${SONARR_API_KEY}"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

meta="$(curl -fsSL --max-time 60 --retry 3 \
  -w '%{http_code} %{content_type}' \
  "$FEED_URL" -o "$tmp")"

# Allow an optional UTF-8 BOM before BEGIN:VCALENDAR.
if ! head -c 64 "$tmp" | sed '1s/^\xEF\xBB\xBF//' | grep -q '^BEGIN:VCALENDAR'; then
  echo "response is not an iCal file (status/type: $meta)" >&2
  echo "first 300 bytes of response:" >&2
  head -c 300 "$tmp" >&2; echo >&2
  exit 1
fi

cd "$REPO_DIR"
[[ -n "${DRY_RUN:-}" ]] || git pull --ff-only --quiet

# DTSTAMP changes on every fetch; skip the commit if nothing else differs.
# Strip CRs so line-ending differences don't count as changes.
normalize() { tr -d '\r' < "$1" | grep -v '^DTSTAMP:'; }
if [[ -f "$OUT" ]] && diff -q <(normalize "$OUT") <(normalize "$tmp") >/dev/null; then
  echo "$(date '+%F %T') no changes"
  exit 0
fi

if [[ -n "${DRY_RUN:-}" ]]; then
  echo "$(date '+%F %T') DRY_RUN: calendar changed, would commit and push:"
  diff <(normalize "$OUT") <(normalize "$tmp") | grep -E '^[<>] SUMMARY' || true
  exit 0
fi

cp "$tmp" "$OUT"
git add Sonarr.ics
git commit --quiet -m "$(date '+%a %m/%d/%Y %H:%M:%S')"
git push --quiet
echo "$(date '+%F %T') updated and pushed"
