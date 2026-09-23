# GitHub Pages deployment

Alleen `Joxxx23/MACHONCE-landing`. Hosting: GitHub Pages; DNS en zakelijke e-mail:
mijn.host. Primaire URL: `https://machonce.com`. `machonce.nl` valt buiten scope.

## Build en publicatie

`.github/workflows/deploy-pages.yml` controleert pushes op `feat/landing-v1` en
`main` met Node 24, `npm ci` en `npm run check`. Alleen `main` publiceert via de
officiële configure-pages, upload-pages-artifact en deploy-pages Actions. Er wordt
uitsluitend `dist/` geüpload. Handmatig opnieuw uitvoeren kan via Actions.

GitHub repository → Settings → Secrets and variables → Actions → Variables:

- `VITE_SUPABASE_URL`: de bestaande HTTPS Project URL.
- `VITE_SUPABASE_PUBLISHABLE_KEY`: de bestaande publieke publishable key.

De workflow gebruikt repository variables, niet hardcoded waarden. Ontbrekende of
ongeschikte configuratie stopt de build. Geen secret/service-role key gebruiken.
`.env.local`, `.qa/`, `node_modules/` en `dist/` blijven buiten Git.

Vite gebruikt de standaardbase `/`. De output bevat een echte statische
`privacy/index.html`; er is geen SPA-404-fallback nodig. Houd de rootbase voor het
custom domein. De standaard Pages-project-URL is geen vervanging voor een werkend
custom domein zolang rootpaden of de domeinredirect daar nog niet werken.

## GitHub en domein

Repository → Settings → Pages:

1. Source: **GitHub Actions**.
2. Custom domain: **machonce.com**, opslaan vóór de website-DNS wordt gewijzigd.
3. Accountinstellingen → Pages: lees zo nodig de exacte domeinverificatie-TXT van
   GitHub af; gebruik nooit een zelfbedachte verificatiewaarde.
4. Activeer **Enforce HTTPS** zodra het certificaat beschikbaar is.

Bij custom Actions-publicatie is geen CNAME-bestand in de build vereist; de
domeinkoppeling staat in Pages Settings.

## Website-DNS bij mijn.host

Onderstaande doelwaarden zijn afkomstig uit de actuele
[GitHub Pages-documentatie](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site).
Voer ze pas in nadat `machonce.com` in de juiste Pages-repository staat.

| Type | Host | Doel |
| --- | --- | --- |
| A | @ | 185.199.108.153 |
| A | @ | 185.199.109.153 |
| A | @ | 185.199.110.153 |
| A | @ | 185.199.111.153 |
| AAAA | @ | 2606:50c0:8000::153 |
| AAAA | @ | 2606:50c0:8001::153 |
| AAAA | @ | 2606:50c0:8002::153 |
| AAAA | @ | 2606:50c0:8003::153 |
| CNAME | www | joxxx23.github.io |

IPv6 is optioneel, maar laat bij gebruik geen oude conflicterende apex-AAAA staan.
De CNAME verwijst naar de account-hostname, zonder repositorypad. Met `machonce.com`
als primaire Pages-domain kan GitHub `www` naar het primaire domein doorsturen.
TTL: de bestaande 900 seconden of de standaard van mijn.host is bruikbaar.

Op 22 september 2026 waren voor de website nog zichtbaar:
`A @ = 217.180.14.67` en `AAAA @ = 2a11:4881:1:60eb::1`; die conflicteren met Pages.
Een directe CNAME-query voor `www` leverde geen CNAME-antwoord op. Controleer de
website-records in het dashboard voordat je ze vervangt.

**Laat MX, SPF, DKIM, DMARC en alle mailgerelateerde TXT/CNAME-records intact.**
Deze deployment wijzigt geen mailconfiguratie. De eigenaar heeft bevestigd dat
`privacy@machonce.com` operationeel is en getest is.

## Verificatie na DNS en certificaat

Controleer `https://machonce.com`, HTTP→HTTPS, `www`→apex, logo/video/CSS/JS en
`/privacy` direct, na refresh en zonder JavaScript. Controleer de compacte notice
van 22 september en de v2-consenttekst. Alleen de footer Privacy-link is aanwezig,
volgens de laatst goedgekeurde ontwerpwijziging.

Gebruik één herkenbare `@example.com`-fixture voor de echte browserregistratie en
de duplicate. Beide moeten HTTP 200 met `{"accepted":true}` en `You’re in.` geven.
Controleer via beheer precies één genormaliseerd record met v2 en gegenereerde
UUID/tijd. Verwijder uitsluitend die eigen fixture en bevestig nul resterende
records. Zonder geldig adres of aangevinkte toestemming mag geen request ontstaan.

Herhaal de publieke SELECT/INSERT/UPDATE/DELETE-probes, controleer console,
storage, cookies, geen tracking en geen overflow op mobiel. Noem de site pas live
als deze controles op `https://machonce.com` werkelijk zijn geslaagd.

De gebundelde Supabase-library bevat generieke localhost-standaarden voor auth;
de gebruikte client overschrijft die met de HTTPS Project URL. Dit zijn geen
runtime-afhankelijkheden van een lokale server. De netwerkaudit moet bevestigen
dat de gepubliceerde pagina alleen de eigen origin en Supabase benadert.
