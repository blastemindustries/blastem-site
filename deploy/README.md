# Publishing blastemindustries.com on our server

This moves `blastemindustries.com` from Google Sites to our own Linux server.
It takes about 30 minutes of work, plus waiting for DNS to update.

**What changes:** only the website address records (`@` and `www`).
**What must not change:** email (MX, SPF/DKIM TXT records), `sentinel.`, `sams.`
and any other subdomain records. They keep working as they are.

---

## 0. Before you start

- **Server IP.** Note the server's public IP address, for example `203.0.113.10`.
- **Lower the DNS TTL.** At GoDaddy or Namecheap, set the TTL of the `@` and `www`
  records to 600 seconds (10 minutes), a day ahead if you can. Switching over and
  rolling back are then both quick.
- **Screenshot the current DNS records.** This is your rollback plan.

## 1. Set up the server (once)

Copy the repository, or just the `deploy/` folder, to the server. Then run on the server:

```bash
sudo bash deploy/setup-server.sh admin@blastemindustries.com
```

The script:

- installs nginx and certbot;
- creates `/var/www/blastemindustries.com`;
- adds an nginx site that answers **only** for `blastemindustries.com` and `www.`, leaving
  other sites on the server (`sentinel.`, `sams.`) untouched;
- checks DNS. While DNS still points at Google, it stops before requesting certificates.
  That is expected.

If port 80 is already used by Apache, the script stops without changing anything.
Ask for an Apache version in that case.

## 2. Upload the site

On your own computer, inside this repository:

```bash
./deploy/deploy.sh ubuntu@203.0.113.10        # your SSH user and server IP
```

This uploads only the public files: the pages, the logos and `assets/`.

**Test it before switching DNS.** Point just your own computer at the server: add this
line to `/etc/hosts` (Mac/Linux) or `C:\Windows\System32\drivers\etc\hosts` (Windows):

```
203.0.113.10  blastemindustries.com www.blastemindustries.com
```

Then open http://blastemindustries.com. Remove the line when you are done.

## 3. Switch DNS (GoDaddy / Namecheap)

In the domain's DNS settings:

| Type | Name | Action |
|---|---|---|
| A | `@` | Set to the **server IP**. Delete any other `@` A records (Google Sites uses `216.239.32.21`, `.34.21`, `.36.21`, `.38.21`). |
| AAAA | `@` | Delete Google's (`2001:4860:4802:…`). Add the server's IPv6 only if it has one. |
| CNAME | `www` | Delete `ghs.googlehosted.com`. |
| A | `www` | Add, pointing at the **server IP**. |
| Forwarding | — | If the domain has "forwarding" to www turned on, turn it off. |

**Do not touch:**

- **MX** records (email)
- **TXT** records (`v=spf1…`, `google-site-verification…`)
- **CNAME** records named `google._domainkey` or similar
- the `sentinel` and `sams` records, and any other subdomain

## 4. Turn on HTTPS

After about 10–30 minutes, check that the domain resolves to the server:

```bash
nslookup blastemindustries.com
```

Then re-run the setup on the server:

```bash
sudo bash deploy/setup-server.sh admin@blastemindustries.com
```

This time it gets free Let's Encrypt certificates and redirects http to https.
Certificates renew automatically.

## 5. Tidy up

- **Google Sites:** go to Settings → Custom domains and remove `blastemindustries.com`,
  so Google stops claiming the address.
- **TrackWise:** the app and the store listings currently link to the GitHub Pages copy of
  the policies. Those URLs keep working. The pages are now also at
  `https://blastemindustries.com/trackwise-privacy.html` and `/trackwise-terms.html`.
  Switch the apps to these in a future release, and keep the old URLs alive until then.

## Updating the site later

```bash
git pull
./deploy/deploy.sh ubuntu@203.0.113.10
```

Changes are live as soon as the script finishes, and the script checks the main pages
respond.

## Rolling back

Put the `@` and `www` records back as they were in your screenshot. With a 600-second TTL,
the Google Sites version is back within minutes.
