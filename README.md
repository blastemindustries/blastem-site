# Blastem Industries — site

Static pages served by GitHub Pages.

| Page | Purpose |
|---|---|
| `index.html` | Blastem Industries home: domains, Sentinel FO flagship, every development, live app demos |
| `sentinel.html` | Sentinel FO deep-dive: concept, device, decision simulator, emergency flow, platform consoles |
| `assets/site.css`, `assets/site.js` | Shared styles and behaviour (loader, cursor, nav, reveals, counters) |
| `assets/sentinel/` | Sentinel FO images taken from the pitch deck |
| `zeronet.html` | Zeronet product page (was `index.html`) |
| `blastem-logo.png`, `blastem-mark.png` | Full logo, and the cropped mark used for the nav and favicon |
| `trackwise-privacy.html` | TrackWise privacy policy — **submitted to the App Store and Google Play** |
| `trackwise-terms.html` | TrackWise terms of use — linked from the app's first-run consent screen |
| `zeronet-privacy.html` | Zeronet privacy policy — **used in the Google Play / App Store listings and AdMob consent messages** |
| `zeronet-terms.html`, `zeronet-licenses.html`, `zeronet-legal.css` | Zeronet terms of use and open-source licences. Source of truth is `legal/site/` in the Zeronet repo (bundled in the apps); re-copy from there when they change |

The TrackWise and Zeronet legal pages are referenced from inside the shipped apps and from both store
listings. Their URLs must not change, and they must not 404: a dead privacy policy URL is a
compliance failure against a live app on both stores.

## Publishing

To host the site on our own server at blastemindustries.com, see [`deploy/README.md`](deploy/README.md).
