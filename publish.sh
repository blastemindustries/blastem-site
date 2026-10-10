#!/usr/bin/env bash
# Publishes this folder to GitHub Pages and prints the two URLs the stores and the apps need.
#
# Run it from inside this folder, after authenticating once:
#
#   brew install gh          # if you don't have it
#   gh auth login            # opens a browser; pick HTTPS
#   ./publish.sh
#
# Re-running it after the first time just pushes the latest commit.

set -euo pipefail

REPO_NAME="${1:-blastem-site}"

command -v gh >/dev/null || { echo "gh is not installed. Run: brew install gh"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Not signed in. Run: gh auth login"; exit 1; }

OWNER=$(gh api user --jq .login)

if gh repo view "$OWNER/$REPO_NAME" >/dev/null 2>&1; then
  echo "Repository $OWNER/$REPO_NAME already exists — pushing to it."
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$OWNER/$REPO_NAME.git"
  git push -u origin main
else
  echo "Creating $OWNER/$REPO_NAME and pushing."
  gh repo create "$REPO_NAME" --public --source=. --remote=origin --push
fi

# Turn Pages on, serving the repository root of main. Harmless if it is already on.
gh api --silent -X POST "repos/$OWNER/$REPO_NAME/pages" \
  -f "source[branch]=main" -f "source[path]=/" 2>/dev/null \
  || gh api --silent -X PUT "repos/$OWNER/$REPO_NAME/pages" \
       -f "source[branch]=main" -f "source[path]=/" 2>/dev/null \
  || echo "note: could not set Pages automatically — turn it on under Settings → Pages (branch: main, folder: /root)."

BASE="https://$OWNER.github.io/$REPO_NAME"

# Point both apps at the site that was just published. The consent screen links these pages,
# so a stale placeholder here means shipping an app whose policy links 404 — which is an App
# Review rejection and, worse, asks people to agree to documents they cannot read.
IOS_LEGAL="$HOME/Desktop/CODING/PayWise/TrackWise/UI/Common/LegalConsent.swift"
ANDROID_LEGAL="$HOME/Desktop/CODING/E_track/app/src/main/java/com/etrack/budget/ui/legal/LegalConsent.kt"

patch_url() {
  local file="$1" pattern="$2"
  if [ -f "$file" ]; then
    # Only the URL inside the quotes changes; the surrounding declaration is left alone.
    /usr/bin/sed -i '' -E "s#(${pattern}\")[^\"]*(\")#\1${BASE}\2#" "$file"
    echo "  updated $(basename "$file")"
  else
    echo "  SKIPPED (not found): $file"
  fi
}

echo
echo "Pointing the apps at $BASE"
patch_url "$IOS_LEGAL" "static let baseURL = "
patch_url "$ANDROID_LEGAL" "private const val BASE = "

echo
echo "Verifying the pages are reachable (Pages can take a minute on a first publish)…"
for attempt in $(seq 1 10); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/trackwise-privacy.html" || echo 000)
  if [ "$code" = "200" ]; then
    echo "  live: $BASE/trackwise-privacy.html"
    break
  fi
  [ "$attempt" = "10" ] && echo "  still $code — check Settings → Pages, then re-run this script"
  sleep 15
done

cat <<EOF

Done.

  Privacy policy : $BASE/trackwise-privacy.html
  Terms of use   : $BASE/trackwise-terms.html

Both apps now point at these. Rebuild so the shipped binaries carry the real URLs, then
paste the privacy URL into Play Console (App content -> Privacy policy) and App Store
Connect (App Information -> Privacy Policy URL).
EOF
