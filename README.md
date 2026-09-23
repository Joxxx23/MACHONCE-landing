# MACHONCE landing

Uitsluitend de tijdelijke publieke MACHONCE-landingspagina. `MACHONCE-app` is een
volledig apart project; deze repository gebruikt daar geen code, configuratie of assets van.

## Lokaal

Node.js 22.13+ (22 LTS) of 24+ met npm. HTML, CSS en gewone JavaScript-modules, met Vite als ontwikkel-
en buildtool. Geen frontend-framework. De enige directe runtime-dependency is de
officiële `@supabase/supabase-js` client; deze wordt pas bij submit geladen.

```sh
npm ci
npm run dev
```

`npm run lint`, `npm run typecheck` (JavaScript met JSDoc), `npm test` en `npm run build`
controleren de implementatie. `npm run check` voert ze alle vier uit. `npm run preview` toont de
productiebuild. Publiceer later alleen de inhoud van `dist/` op een statische host.

## Assets en intro

- `public/assets/machonce-logo.png`: ongewijzigd origineel, 2172 × 718, circa 651 KiB.
- `public/assets/machonce-intro.mp4`: ongewijzigd origineel, 2172 × 718, 2,6 s, circa 263 KiB.
- `public/assets/machonce-intro-poster.png`: exacte stilstaande kopie van het eerste
  videoframe (2172 × 718), voor directe weergave voordat de animatie begint.
- Beide hebben aspectratio 1086:359 (circa 3,025:1). Hun zichtbare logo's hebben dezelfde
  positie en omvang; CSS verbergt alleen lege verticale canvasruimte, zonder de bestanden te wijzigen.

Het eerste videobeeld is meteen zichtbaar als poster. Alleen de beweging start na
1 seconde, muted en inline, en speelt eenmaal. De officiële PNG wordt vooraf
gedecodeerd en blijft volledig dekkend onder de video. Na afloop vervaagt alleen de
videolaag in 120 ms; zo ontstaat geen helderheidsdip bij de overgang. De video wordt
pas na de fade vrijgegeven. De container reserveert vooraf de ruimte.
Bij reduced motion, een laadfout, geweigerde autoplay of vastgelopen video verschijnt
de PNG. Reduced motion en uitgeschakeld JavaScript laden de MP4 niet.

## Supabase waitlist via RPC

Kopieer `.env.example` naar `.env.local` en vul de bestaande `VITE_SUPABASE_URL`
en `VITE_SUPABASE_PUBLISHABLE_KEY` in. Gebruik uitsluitend een publishable key,
nooit een secret/service-role key of databasewachtwoord. Het lokale env-bestand is
Git-ignored; beide publieke waarden worden tijdens de build client-side opgenomen.

`src/waitlist.js` roept alleen `join_waitlist(email, consent_version)` aan, zonder
rechtstreekse INSERT, lookup, upsert of UPDATE. De PostgreSQL-functie normaliseert en
valideert opnieuw, gebruikt `ON CONFLICT (email) DO NOTHING` en retourneert voor
nieuw én duplicate precies `{"accepted":true}`. De UI toont steeds `You’re in.`.
Onverwachte fouten binnen de functie geven alleen `{"accepted":false}`; de frontend
behoudt de algemene foutmelding. Er is geen retry of browserlogging van errors/adressen.

De function owner is een afzonderlijke NOLOGIN-rol zonder RLS-bypass, met alleen
kolomrechten voor de noodzakelijke INSERT en conflictcontrole. Alleen anon krijgt
EXECUTE op deze functie. Directe tabel- en kolomrechten van PUBLIC, anon en
authenticated worden ingetrokken. RLS blijft aan. SQL/defaults bepalen id/created_at.

**Dit werkt pas nadat de SQL is uitgevoerd.** Volg de volgorde in
[docs/privacy-launch.md](docs/privacy-launch.md). Er is geen directe INSERT-fallback.
`npm test` gebruikt de echte Supabase-client met fictieve configuratie en gesimuleerd
HTTP-transport. De transactionele SQL-regressietest staat in
[database/waitlist-rpc-test.sql](database/waitlist-rpc-test.sql).

## Privacy en consentgeschiedenis

De checkbox is standaard uitgevinkt en verplicht; alleen een geldig genormaliseerd
adres en expliciete toestemming starten de RPC. De payload bevat uitsluitend email
en `consent_version: "waitlist-v2-2026-09-18"`.

> I’m 16+ and want MACHONCE early-access, closed-alpha and launch emails. I can unsubscribe anytime.

De eigenaar heeft v2 goedgekeurd om de eerdere v1-tekst intact te houden. Beide teksten
staan in [docs/privacy/consent-history.md](docs/privacy/consent-history.md); het
originele v1-document blijft ongewijzigd. Duplicates vernieuwen geen oude toestemming.

De Privacy Notice op `/privacy` heeft datum 18 September 2026 en een `Withdraw consent`
mailto-link met uitsluitend een vast onderwerp. Vite bouwt `privacy/index.html` als
tweede statische pagina; de lokale server verwijst `/privacy` naar `/privacy/`.
Er zijn geen nieuwe runtime-dependencies, externe fonts, analytics of cookiebanners.

GitHub Pages publiceert via `.github/workflows/deploy-pages.yml` uitsluitend de
productiebuild van `main`. De featurebranch krijgt dezelfde buildcontroles zonder
publicatie. De root-URL's (`/privacy`, `/assets/…`) zijn bedoeld voor `machonce.com`.
Zie [docs/deployment.md](docs/deployment.md) voor buildvariabelen, domeinkoppeling,
website-DNS en de live controles. Publiceer geen bronbestanden of lokale env-files.

Zie [docs/privacy/final-verification.md](docs/privacy/final-verification.md)
voor de finale live HTTP-/databasecontroles, testresultaten en livegangspunten.
Eerdere verificatieverslagen zijn historische informatie; de voorlopige live
status in `docs/privacy/security-verification.md` is hiermee achterhaald.
