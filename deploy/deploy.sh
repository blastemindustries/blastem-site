#!/usr/bin/env bash
# Publishes this site to blastemindustries.com. Run from your computer, in this repository:
#
#   ./deploy/deploy.sh                      # deploy (asks before changing existing pages)
#   ./deploy/deploy.sh --dry-run            # show what would change, change nothing
#   ./deploy/deploy.sh --rollback           # switch back to the previous release
#
# How the server works (matches what runs today):
#   blastem-nginx (Docker, ports 80/443, HTTPS)  ->  blastem-website (Docker, nginx, :8080)
#   blastem-website serves /opt/blastem-website/current, a symlink to releases/<timestamp>.
#
# A deploy never edits the live folder. It copies the live release into a new release
# folder, adds/updates the site files there, checks it, then switches the symlink in one
# step. Nothing on the live site is deleted, and pages that differ from the live copy are
# listed and need your confirmation first. Every previous release is kept for rollback.
#
# Settings (override with environment variables):
#   DEPLOY_HOST=root@67.211.221.155  DEPLOY_KEY=~/.ssh/trackwise_deploy
set -euo pipefail

HOST="${DEPLOY_HOST:-root@67.211.221.155}"
KEY="${DEPLOY_KEY:-$HOME/.ssh/trackwise_deploy}"
BASE="/opt/blastem-website"
SITE="https://blastemindustries.com"
SSH=(ssh -i "$KEY" -o BatchMode=yes -o ConnectTimeout=15 "$HOST")
cd "$(dirname "$0")/.."

MODE="deploy"
case "${1:-}" in
  --dry-run) MODE="dry" ;;
  --rollback) MODE="rollback" ;;
  "") ;;
  *) echo "usage: $0 [--dry-run | --rollback]"; exit 1 ;;
esac

# The public files. Repository tooling (deploy/, *.md, *.py, *.sh) never leaves this computer.
FILES=(index.html sentinel.html zeronet.html trackwise-privacy.html trackwise-terms.html
       zeronet-privacy.html zeronet-terms.html zeronet-licenses.html zeronet-help.html zeronet-legal.css
       app-ads.txt blastem-logo.png blastem-mark.png assets)
# Checked after every deploy. app-ads.txt must stay at the root for AdMob.
URLS=(/ /sentinel /zeronet /trackwise-privacy.html /trackwise-terms.html
      /zeronet-privacy.html /zeronet-terms.html /zeronet-licenses.html /zeronet-help.html
      /zeronet-legal.css /app-ads.txt /assets/site.css)

check_live() {
  local fail=0 code path
  for path in "${URLS[@]}"; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "$SITE$path" || echo 000)
    printf "  %-28s %s\n" "$path" "$code"
    [ "$code" = 200 ] || fail=1
  done
  if ! curl -s "$SITE/app-ads.txt" | grep -q "pub-5531828470553936"; then
    echo "  app-ads.txt does not contain the AdMob publisher line"; fail=1
  fi
  return $fail
}

if [ "$MODE" = "rollback" ]; then
  "${SSH[@]}" "set -e; cd $BASE
    cur=\$(readlink current); prev=\$(ls -1d releases/*/ | sed 's#/\$##' | grep -vx \"\$cur\" | tail -1)
    [ -n \"\$prev\" ] || { echo 'No earlier release to roll back to.'; exit 1; }
    ln -sfn \"\$prev\" current.tmp && mv -T current.tmp current
    echo \"Rolled back: \$cur -> \$prev\""
  check_live && echo "Live: $SITE" || echo "Some URLs did not return 200."
  exit 0
fi

for f in "${FILES[@]}"; do [ -e "$f" ] || { echo "Missing $f; not deploying."; exit 1; }; done
grep -q "pub-5531828470553936" app-ads.txt || { echo "app-ads.txt lost its AdMob line; not deploying."; exit 1; }

echo "== Comparing with the live site"
LIVE=$("${SSH[@]}" "readlink -f $BASE/current")
# rsync itemises what it would send: new files and files whose content differs.
CHANGES=$(rsync -rcin --out-format='%i %n' -e "ssh -i $KEY -o BatchMode=yes" "${FILES[@]}" "$HOST:$LIVE/" | grep -v '/$' || true)
NEW=$(echo "$CHANGES" | awk '$1 ~ /\+\+\+\+/ {print $2}')
CHANGED=$(echo "$CHANGES" | awk '$1 !~ /\+\+\+\+/ && NF {print $2}')
echo "New files:";     [ -n "$NEW" ] && echo "$NEW" | sed 's/^/  + /' || echo "  (none)"
echo "Changed files:"; [ -n "$CHANGED" ] && echo "$CHANGED" | sed 's/^/  ~ /' || echo "  (none)"

[ -z "$NEW$CHANGED" ] && { echo "Live site already matches. Nothing to do."; exit 0; }
[ "$MODE" = "dry" ] && { echo "Dry run: nothing was changed."; exit 0; }

if [ -n "$CHANGED" ]; then
  echo
  echo "The pages marked ~ will replace what is live now. If someone edited them on the"
  echo "server, copy those edits into this repository first, or they will be lost."
  read -r -p "Replace them? [y/N] " ok
  [ "$ok" = "y" ] || [ "$ok" = "Y" ] || { echo "Cancelled. Nothing was changed."; exit 1; }
fi

REL="releases/$(date -u +%Y%m%dT%H%M%SZ)"
echo "== Building $REL from the live release"
"${SSH[@]}" "set -e; cd $BASE; cp -a \"$LIVE\" \"$REL\""
rsync -rlt --chmod=D755,F644 -e "ssh -i $KEY -o BatchMode=yes" "${FILES[@]}" "$HOST:$BASE/$REL/"
"${SSH[@]}" "set -e; cd $BASE/$REL; chown -R --reference=\"$LIVE\" .; [ -s index.html ] && [ -s app-ads.txt ]"

echo "== Switching live to $REL"
"${SSH[@]}" "set -e; cd $BASE; ln -sfn \"$REL\" current.tmp && mv -T current.tmp current"

echo "== Checking the live site"
if check_live; then
  echo "Live: $SITE   (undo with: ./deploy/deploy.sh --rollback)"
else
  echo "Some URLs did not return 200. Undo with: ./deploy/deploy.sh --rollback"
  exit 1
fi
