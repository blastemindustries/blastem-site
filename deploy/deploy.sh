#!/usr/bin/env bash
# Publishes the site to the server. Run from your computer, in this repository:
#
#   ./deploy/deploy.sh user@your-server-ip
#
# Copies only the public site files (pages, logos, assets/) over SSH, then checks
# the key URLs respond. Anything removed locally is removed on the server too.
set -euo pipefail

TARGET="${1:?usage: ./deploy/deploy.sh user@server [ssh-port]}"
PORT="${2:-22}"
ROOT="/var/www/blastemindustries.com"
SITE="https://blastemindustries.com"
cd "$(dirname "$0")/.."

# Fail early rather than publish a half-broken site.
for f in index.html sentinel.html zeronet.html trackwise-privacy.html trackwise-terms.html \
         assets/site.css assets/site.js blastem-logo.png blastem-mark.png; do
  [ -f "$f" ] || { echo "Missing $f; not deploying."; exit 1; }
done

echo "== Uploading to $TARGET:$ROOT"
rsync -avz --delete --delete-excluded -e "ssh -p $PORT" \
  --include='*.html' --include='*.png' \
  --include='assets/***' \
  --exclude='*' \
  ./ "$TARGET:$ROOT/"

echo "== Checking the live site"
fail=0
for path in / /sentinel.html /zeronet.html /trackwise-privacy.html /trackwise-terms.html /assets/site.css /assets/sentinel/device.webp; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$SITE$path" || echo 000)
  printf "  %-30s %s\n" "$path" "$code"
  [ "$code" = 200 ] || fail=1
done
[ "$fail" = 0 ] && echo "Live: $SITE" || echo "Some URLs did not return 200 (normal before DNS/HTTPS are set up; see deploy/README.md)."
