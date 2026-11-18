#!/usr/bin/env bash
# One-time setup of the web server for blastemindustries.com. Run ON the server:
#
#   sudo bash setup-server.sh you@example.com
#
# The email is for Let's Encrypt expiry notices. Safe to re-run.
# Assumes Ubuntu/Debian. It only adds a site for blastemindustries.com and
# www.blastemindustries.com; existing nginx sites (e.g. sentinel., sams.) are not touched.
set -euo pipefail

EMAIL="${1:?usage: sudo bash setup-server.sh <email-for-ssl-notices>}"
DOMAIN="blastemindustries.com"
ROOT="/var/www/$DOMAIN"
HERE="$(cd "$(dirname "$0")" && pwd)"

[ "$(id -u)" = 0 ] || { echo "Run with sudo."; exit 1; }

# If another web server (e.g. Apache) already owns port 80, stop rather than fight it.
if command -v ss >/dev/null && ss -ltnp 2>/dev/null | grep -E ':80\s' | grep -vq nginx; then
  echo "Port 80 is used by something other than nginx:"; ss -ltnp | grep -E ':80\s'
  echo "This server needs an Apache setup instead. Stopping without changes."; exit 1
fi

echo "== Installing nginx and certbot (skipped if present)"
apt-get update -qq
apt-get install -y -qq nginx certbot python3-certbot-nginx rsync

echo "== Web root $ROOT"
mkdir -p "$ROOT"
# The deploy user (whoever ran sudo) owns the files, so deploys need no sudo.
OWNER="${SUDO_USER:-root}"
chown -R "$OWNER":"$OWNER" "$ROOT"
[ -f "$ROOT/index.html" ] || echo '<!doctype html><title>Blastem Industries</title><p>Deploying…</p>' > "$ROOT/index.html"

echo "== nginx site"
CONF=/etc/nginx/sites-available/$DOMAIN
if [ -f "$CONF" ] && grep -q "ssl_certificate" "$CONF"; then
  echo "   $CONF already has HTTPS from certbot; leaving it as is."
else
  install -m 644 "$HERE/nginx/$DOMAIN.conf" "$CONF"
fi
ln -sf "$CONF" /etc/nginx/sites-enabled/$DOMAIN
nginx -t
systemctl reload nginx

echo "== Firewall (only if ufw is active)"
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then ufw allow 'Nginx Full'; fi

echo "== Checking DNS points here before asking for certificates"
MYIP=$(curl -fsS https://api.ipify.org || true)
for h in "$DOMAIN" "www.$DOMAIN"; do
  got=$(getent ahostsv4 "$h" | awk 'NR==1{print $1}')
  echo "   $h -> ${got:-nothing}   (this server: ${MYIP:-unknown})"
  if [ -n "$MYIP" ] && [ "$got" != "$MYIP" ]; then
    echo
    echo "DNS for $h does not point at this server yet. Update the A records (see deploy/README.md),"
    echo "wait for them to propagate, then re-run this script to get HTTPS."
    exit 0
  fi
done

echo "== HTTPS certificates (Let's Encrypt)"
certbot --nginx --non-interactive --agree-tos -m "$EMAIL" \
  -d "$DOMAIN" -d "www.$DOMAIN" --redirect
systemctl reload nginx
echo
echo "Done. https://$DOMAIN is served from $ROOT. Certificates renew automatically."
