# Fase 2 — implementatie en verificatie

Gecontroleerd op 18 September 2026. Uitsluitend gewerkt in
`D:\ChatGPT\MACHONCE-landing`, branch `feat/landing-v1`, remote
`https://github.com/Joxxx23/MACHONCE-landing.git`. De afzonderlijke app is niet geopend
of gewijzigd. Dit verslag beschrijft lokale code en tests; er is niet gepubliceerd.

## Bestanden van deze fase

Gewijzigd:

- `index.html` — verplichte checkbox en twee Privacy-links.
- `src/main.js` — consentvalidatie, loading/reset en toegankelijke foutstatus.
- `src/waitlist.js` — expliciete consentvoorwaarde en versie in INSERT-payload.
- `src/styles.css` — minimale integratie van checkbox en footer.
- `tests/waitlist.test.js` — payload, consentblokkering en tekst/versie-regressies.
- `README.md` — koppeling en privacy-/database-instructies.

Toegevoegd:

- `privacy/index.html` — semantische Privacy Notice met twaalf onderdelen.
- `src/privacy.css` — responsive opmaak voor de notice.
- `vite.config.js` — tweede statische buildpagina en `/privacy`-directoryredirect
  voor de lokale dev-server en preview.
- `docs/consent-versions.md` — exacte tekst, versie en ingangsdatum.
- `database/waitlist-consent-preflight.sql` — read-only beheercontrole.
- `database/waitlist-consent.sql` — transactionele schemawijziging zonder backfill.
- `docs/privacy-launch.md` — precieze handmatige stappen en livegangvoorwaarden.
- `docs/privacy-verification.md` — dit verslag.

De bestaande intro, assets, slogan, Supabase-clientconfiguratie en dependencyversies
zijn niet gewijzigd. De repository bevat ook nog niet-gecommitteerde bestanden uit
eerdere fasen; deze lijst beschrijft uitsluitend fase 2. Tijdelijke QA-bestanden en
de gegenereerde `dist/` vallen onder de bestaande `.gitignore`.

## Consent en publieke ervaring

**Version:** `waitlist-v1-2026-09-17`  
**Effective date:** 17 September 2026

> Yes, I’d like to receive MACHONCE early-access, closed-alpha and launch emails. I confirm that I am 16 or older. I can unsubscribe at any time.

De checkbox is standaard uitgevinkt, heeft een gekoppeld label en werkt met het
toetsenbord. Zonder geldig e-mailadres of aangevinkte toestemming verstuurt het
formulier geen Supabase-request. Ook de servicelaag weigert ontbrekende toestemming.
Dit betreft de formulierflow; een publieke API bewijst geen identiteit of leeftijd.

Alleen `{ email, consent_version }` gaat in de payload. Het adres wordt nog steeds
getrimd en naar lowercase omgezet. Geen eigen IP-, user-agent- of fingerprintvelden,
logging of aanvullende persoonsgegevens zijn toegevoegd. `id` en `created_at`
blijven databaseverantwoordelijkheid.

Een geslaagde INSERT en specifiek `23505` geven identieke `You're in.`-tekst en
formulierstatus. Dit is in de browser op exact gelijke formulier-HTML gecontroleerd.
Er is één INSERT per submit, zonder retry, SELECT, upsert of UPDATE. Andere fouten
houden de bestaande algemene melding. De bestaande netwerkstatuscodes 201 en 409
blijven inspecteerbaar: volledige ononderscheidbaarheid op API-niveau is met deze
ongewijzigde architectuur niet aangetoond.

## Lokale controles

| Controle | Resultaat |
| --- | --- |
| Bestaande en uitgebreide Node-tests | 15/15 geslaagd |
| Productiepagina in headless Edge | 13/13 browsercontroles geslaagd |
| ESLint, nul waarschuwingen | Geslaagd |
| TypeScript checkJs/typecheck | Geslaagd |
| Vite production build | Geslaagd; beide HTML-pagina's aanwezig |
| `/privacy`, `/privacy/`, direct openen en refresh | Geslaagd in dev en productiepreview |
| Formulierlink, footerlink, teruglink en mailto-links | Geslaagd |
| Privacy Notice zonder JavaScript | Geslaagd |
| Layout 320, 390, 600, 768, 1680 en 1920 px | Geen horizontale overflow |
| Visuele controle landing en notice | Desktop en mobiel gecontroleerd |

De browsercontroles testen ook: unchecked bij laden/herladen, toetsenbordfocus en
Space, geen request zonder consent/ongeldig adres, exacte genormaliseerde payload,
loading/dubbele-submitblokkering, reset na succes, duplicate-regressie en algemene
foutmeldingen bij permission-, overige database- en netwerkfouten. Succes/duplicate
zijn hier met gesimuleerde HTTP-responses getest, niet als bewijs van live opslag.

## Live database/security — stand vóór migration

De repository bevat geen SQL-beheerverbinding. Alleen de bestaande publieke Data API
is gebruikt. De onderstaande checks hebben geen nieuwe rij aangemaakt of oude rij
gewijzigd/verwijderd:

| Aanvraag | Werkelijk resultaat |
| --- | --- |
| INSERT met email + consent_version | HTTP 400, `PGRST204`: nieuwe kolom nog niet beschikbaar |
| Publieke SELECT | HTTP 401, `42501`: geblokkeerd |
| Publieke UPDATE | HTTP 401, `42501`: geblokkeerd |
| Publieke DELETE | HTTP 401, `42501`: geblokkeerd |
| Live duplicate met nieuwe payload | Nog niet te testen door ontbrekende kolom |
| Opgeslagen consent_version, id en created_at | Nog door beheerder te controleren na migration |
| Actuele RLS-flag | Niet via publieke sleutel uitleesbaar; preflight vereist |

Er zijn geen grants of policies gewijzigd. De gevraagde INSERT-only architectuur
blijft behouden in code en SQL; de huidige publieke read/update/delete-weigeringen
zijn opnieuw bewezen. Een werkende nieuwe INSERT is **nog geen geslaagde live test**.

De voorbereide SQL controleert dat RLS aanstaat, blokkeert oude inserts tijdens de
transactionele wijziging en voegt `consent_version text NOT NULL` zonder default toe.
Zij stopt als oude rows zonder aantoonbare consentversie overblijven en verzint geen
historische toestemming. Geen oude rows zijn door deze fase verwijderd of backfilled.
De bekende technische testrow en de beoordeling van overige rows staan in
[`privacy-launch.md`](privacy-launch.md).

## Cookies, opslag, resources en secrets

De productiebuild is in een nieuwe Edge-context gecontroleerd, inclusief een echte
Supabase-submit met technische testdata (afgewezen door de ontbrekende kolom).

- **Browsercookies:** vóór en na submit geen opgeslagen cookies.
- **Providerresponse:** Supabase stuurde wel `Set-Cookie: __cf_bm` via Cloudflare,
  met Secure, HttpOnly en SameSite=None. De client gebruikte fetch-credentials
  `same-origin`; de browser nam deze cross-origin cookie niet over. Er worden geen
  cookiewaarden in dit verslag of de applicatie gelogd.
- Cloudflare beschrijft `__cf_bm` als botbeveiliging en niet als cross-site tracking.
  Dit is een providerverklaring, geen algemene claim dat alle hosting cookievrij is.
  Zie de [officiële Cloudflare-documentatie](https://developers.cloudflare.com/fundamentals/reference/policies-compliances/cloudflare-cookies/).
- **localStorage en sessionStorage:** beide leeg na laden, submit en navigatie.
- **Derden:** alleen de bestaande HTTPS Supabase Data API, pas bij geldige submit.
  Vóór submit alleen lokale resources. Geen aparte CDN-scripts of externe fonts;
  fonts komen uit het systeem. De Supabase-client wordt lokaal gebundeld.
- **Tracking:** geen analytics, pixels, session replay, heatmaps of eigen profiling
  aangetroffen in applicatiecode of geobserveerde requests; niets daarvan toegevoegd.
- **Console:** geen e-mailadressen, consentdata of eigen logging; geen JS-runtimefouten.
- **Secrets:** broncode, build, lokale configuratie en huidige Git-geschiedenis
  gecontroleerd op secret/service-role keys en gangbare private-key/connection-string
  patronen; niets aangetroffen. De frontend gebruikt alleen de publishable key.
  `.env.local`, `dist/` en `.qa/` zijn aantoonbaar genegeerd door Git.

Geen cookiebanner toegevoegd. De notice doet bewust geen absolute claim dat de site
nooit cookies gebruikt. Herhaal deze audit op de uiteindelijke HTTPS-host: diens
configuratie en toegevoegde resources zijn lokaal niet verifieerbaar.

## Openstaande livegangvoorwaarden en afwijkingen

1. De eigenaar moet legacy-rows beoordelen en de voorbereide SQL uitvoeren. Daarna
   volgen echte insert-/duplicate-/NOT-NULL-/securitytests en controle van opgeslagen
   waarden/defaults via de beheeromgeving. Publiceer niet vóór deze stap.
2. De Supabase-projectregio is niet betrouwbaar geverifieerd. Daarom staat de
   EU-regioclaim **niet** in de notice; dashboardcontrole blijft open.
3. De uiteindelijke host moet HTTPS en beide privacy-URL's correct afhandelen.
   De lokale Vite-redirect wordt niet als hostingconfiguratie meegebouwd.
4. Werking/opvolging van `privacy@machonce.com` en provider-/doorgifteafspraken zijn
   handmatige controles. Er is geen e-mail verstuurd.
5. Vóór de eerste echte mailing is een eenvoudige gratis unsubscribe-flow nodig;
   die is conform opdracht niet gebouwd.

De databasewijziging is voorbereid in plaats van uitgevoerd, zoals de opdracht bij
ontbrekende beheerverbinding toestaat. De volledige API-ononderscheidbaarheid uit
de prompt is niet hetzelfde als de reeds bestaande gelijke UI; die architectuur is
conform instructie intact gelaten. Geen overige scope-uitbreidingen.
