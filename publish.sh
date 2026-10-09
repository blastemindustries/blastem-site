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

cat <<EOF

Done. The first build takes a minute or two, then these are live:

  Privacy policy : $BASE/trackwise-privacy.html
  Terms of use   : $BASE/trackwise-terms.html

Two things to do with them:

1. Paste the privacy URL into Play Console (App content → Privacy policy) and
   App Store Connect (App Information → Privacy Policy URL).

2. Point the apps at the same base URL, replacing the placeholder in both:

   iOS      PayWise/TrackWise/UI/Common/LegalConsent.swift      -> Legal.baseURL
   Android  E_track/.../ui/legal/LegalConsent.kt                -> Legal.BASE

   Set both to: $BASE

   Then rebuild. The first-run consent screen links to these pages, so they must
   resolve before you ship a build.
EOF
