# RPC privacy/security — verificatie 18 September 2026

## Scope en gewijzigde bestanden

Uitsluitend `D:\ChatGPT\MACHONCE-landing`, branch `feat/landing-v1`, remote
`https://github.com/Joxxx23/MACHONCE-landing.git`. De afzonderlijke app is niet gelezen
of gewijzigd. Er is niet gecommit, gepusht of gepubliceerd.

Gewijzigd in deze update:

1. `index.html` — compacte consenttekst; bestaande checkbox/links behouden.
2. `src/main.js` — exact `You’re in.` voor iedere geslaagde registratie.
3. `src/waitlist.js` — RPC in plaats van directe INSERT; v2; uitsluitend expliciete acknowledgement als succes.
4. `privacy/index.html` — nieuwe notice, datum en withdrawal-link.
5. `tests/waitlist.test.js` — RPC-contract, vaste response, fouten en consenthistorie.
6. `README.md` — actuele architectuur en verwijzingen.
7. `docs/privacy-launch.md` — uitvoervolgorde en productiecontroles.

Toegevoegd:

8. `database/waitlist-rpc.sql` — transactionele functie/rechten/RLS-cutover.
9. `database/waitlist-rpc-test.sql` — transactionele regressietest met ROLLBACK.
10. `database/waitlist-rpc-verify.sql` — read-only beheercontrole zonder adresoutput.
11. `docs/privacy/consent-history.md` — v1 behouden, goedgekeurde v2 toegevoegd.
12. `docs/privacy/security-verification.md` — dit verslag.

Geen stylesheet, logo, animatie, algemene layout, dependencies, Supabase-configuratie
of oude consentregistratie gewijzigd. De oorspronkelijke `docs/consent-versions.md`
blijft intact. De productiebuild en tijdelijke QA-bestanden zijn Git-ignored.

## Exacte zichtbare teksten

Consentversie **`waitlist-v2-2026-09-18`**, met goedkeuring van de eigenaar in deze taak:

> I’m 16+ and want MACHONCE early-access, closed-alpha and launch emails. I can unsubscribe anytime.

De v1-versie van 17 September blijft aan de oorspronkelijke langere tekst gekoppeld.
Beide teksten staan ongewijzigd per versie in `docs/privacy/consent-history.md`.
Duplicates schrijven bestaande consentversie/created_at niet over en vernieuwen
geen toestemming of bewaartermijn. Alleen nieuwe rows krijgen v2.

De volledige geïmplementeerde Privacy Notice staat in `privacy/index.html` en op
`/privacy`, met **Last updated: 18 September 2026** en alle dertien onderdelen uit
de aangeleverde tekst: verantwoordelijke/data controller, verzameling, doeleinden/
grondslagen, vrijwilligheid, bewaartermijn (inclusief 24 maanden), GitHub Pages en
Supabase, internationale doorgiften, beveiliging, rechten, e-mailcommunicatie,
cookies/tracking, geautomatiseerde besluitvorming en wijzigingen.

Redactionele verwerking van instructies in de aangeleverde notice:

- De instructie om een knop/link toe te voegen is uitgevoerd als **Withdraw consent**,
  `mailto:privacy@machonce.com?subject=Withdraw%20MACHONCE%20Early%20Access%20consent`.
  De URL bevat geen adres van de aanvrager of ander persoonsgegeven in de query.
- De zin over toekomstige trackers is publieksgericht geformuleerd als:
  “Before introducing Google Analytics, Meta Pixel, TikTok Pixel, advertising SDKs,
  session replay or similar technology, MACHONCE will review whether consent and an
  updated privacy/cookie notice are required.”
- De laatste zin luidt: “If a future change materially changes the purposes for
  which consent was originally obtained, MACHONCE will not assume the existing
  consent automatically covers that new purpose.”

Daarmee zijn uitvoeringsinstructies geen letterlijke opdrachten aan bezoekers.
De overige inhoud en de opgegeven juridische betekenis zijn behouden. Er is geen
e-mail verstuurd of mailbox ingesteld.

## Enumeratie: oude flow versus nieuwe RPC

De oude code deed rechtstreeks `.insert()` en verwerkte `23505` client-side. De UI
verborg daarmee het verschil, maar status/body/errorobject konden een duplicate
onthullen. Die route is uit de client verwijderd; er is geen directe fallback.

De nieuwe functie trimt/lowercaset, valideert het adres en de actuele consentversie,
en gebruikt `INSERT ... ON CONFLICT (email) DO NOTHING`. Zij retourneert voor nieuw
en bestaand adres hetzelfde JSON-object: `{"accepted":true}`. Geen row, ID, datum,
telling, duplicate-indicator of databasefout wordt teruggestuurd. Afgewezen input
en onverwachte fouten binnen de functie geven alleen `{"accepted":false}`; de UI
houdt de bestaande algemene foutmelding. Er worden geen adressen/errors gelogd.

De lokale browsercontrole gebruikt de echte SQL-functie in een tijdelijke PostgreSQL-
runtime (PGlite 0.5.8), met gesimuleerd PostgREST-transport. Nieuw/duplicate kregen
beide HTTP 200, dezelfde responsebody/contenttype, hetzelfde clientresultaat en
exact dezelfde formulier-HTML. Als beheerder is vervolgens precies één rij met
genormaliseerd adres, v2, UUID en created_at vastgesteld.

**Dit is nog geen bewijs van de live Supabase-API.** De migration moet daar eerst
worden uitgevoerd. Normale status/body geven met de voorbereide RPC geen bestaans-
indicator; een formele constante-tijdgarantie of identiteitscontrole is niet gebouwd.
PostgREST-/proxyfouten buiten de functie kunnen niet door deze SQL worden afgevangen.

## Rechten na de migration — lokaal daadwerkelijk gecontroleerd

| Rol | Directe tabel-/kolomrechten | join_waitlist EXECUTE |
| --- | --- | --- |
| PUBLIC | Geen | Nee |
| anon | Geen SELECT/INSERT/UPDATE/DELETE, ook geen losse kolomrechten | Ja |
| authenticated | Geen SELECT/INSERT/UPDATE/DELETE, ook geen losse kolomrechten | Nee |
| machonce_waitlist_writer | INSERT(email, consent_version), SELECT(email) | Eigenaar |

De interne NOLOGIN-owner heeft geen superuser-, CREATEROLE-, CREATEDB-, replicatie-
of BYPASSRLS-rechten. Alleen beheerder postgres is lid van de rol. De minimale
SELECT(email)-kolomrechten en SELECT-policy zijn intern nodig voor `ON CONFLICT`;
publieke rollen krijgen deze niet. Functie: SECURITY DEFINER met lege search_path,
expliciete schemanamen en selectieve EXECUTE-grant. RLS is na de lokale migration
actief. Oude publieke INSERT-policies geven zonder grants geen tabeltoegang meer.

De migration is ook tweemaal succesvol getest onder een niet-superuser CREATEROLE-
beheerder die het schema bezit (alleen diens rolnaam aangepast in de testkopie).
De productiescripts zelf zijn niet via een beheerverbinding uitgevoerd.

## Tests en werkelijke live stand

| Controle | Resultaat |
| --- | --- |
| Node servicetests | 21/21 geslaagd |
| Browsercontroles met echte lokale SQL | 14/14 geslaagd |
| Transactionele SQL-regressietests | Geslaagd; alle fixtures teruggedraaid |
| Migration opnieuw uitvoeren | Geslaagd |
| Lint / typecheck / productiebuild | Alle geslaagd |
| RLS/rechten/één row/defaults/consent | Lokaal geslaagd; live beheercontrole nog nodig |
| Live RPC | HTTP 404, PGRST202: functie nog niet beschikbaar |
| Live directe INSERT-probe, null email | Laatste controle HTTP 400, 23502: de API herkent consent_version inmiddels, maar weigert op NOT NULL in plaats van toegangsrechten |
| Live publieke SELECT / UPDATE / DELETE | Alle HTTP 401, 42501 |

Eerder gaf de INSERT-probe nog PGRST204 voor de ontbrekende consentkolom; tijdens de
handmatige uitvoering veranderde dit naar 23502. De column is dus inmiddels via de
API herkenbaar, maar echte opslag en de volledige constraints/defaults zijn nog niet
bevestigd. De live probes hebben geen row aangemaakt of gewijzigd/verwijderd. Zonder beschikbare
RPC is nieuwe/duplicate registratie met v2 live nog niet succesvol getest. De
INSERT-probe bewijst evenmin dat INSERT-rechten al ingetrokken zijn: daarvoor is
na de migration een expliciete permission denial nodig. De actuele RLS-flag en
opgeslagen consentvelden zijn zonder beheertoegang niet onafhankelijk bevestigd.

Browserchecks omvatten standaard uitgevinkt, geen request zonder consent/ongeldig
adres, labelklik en toetsenbord-Space, zichtbare focus, tekstcontrast minimaal 4.5:1,
leesbare lettergrootte, loading/dubbele-submitblokkering, algemene fouten, alle
Privacy/terug/mailto-links, direct refresh en notice zonder JavaScript. Geen
horizontale overflow op 320, 390, 600, 768, 1680 en 1920 px; desktop/mobiel visueel bekeken.

## Tracking, resources, cookies en secrets

- Broncode, dependencylijst en browserrequests gecontroleerd. Geen Google Analytics,
  GTM, Meta/Facebook Pixel, TikTok Pixel, Hotjar, Clarity, session replay, advertising
  SDK of third-party analytics-script aangetroffen. Geen cookiebanner toegevoegd.
- Alleen de bestaande gebundelde Supabase-client is runtime-dependency. Geen externe
  fonts/CDN-scripts; vóór submit uitsluitend eigen resources. Alleen Supabase wordt
  na submit als externe origin benaderd.
- Echte browsercontrole van de RPC-aanvraag: geen opgeslagen cookies vóór/na, lege
  localStorage/sessionStorage, fetch-credentials `same-origin`, geen adressen in de
  console en geen JS-runtimefouten. De huidige ontbrekende RPC geeft wel een algemene
  HTTP-resourcefout, geen duplicate/constraint-detail.
- De Supabase-response bevat een `__cf_bm` Set-Cookie-header, die de browser in deze
  flow niet opslaat. De [Cloudflare-documentatie](https://developers.cloudflare.com/fundamentals/reference/policies-compliances/cloudflare-cookies/)
  beschrijft deze als botbeveiliging. Er wordt geen absolute cookievrij-claim gedaan.
- Broncode, build, lokale configuratie en huidige Git-geschiedenis gescand op secret/
  service-role keys, private keys en credentialhoudende database-URL's. Geen gevonden.
  De client gebruikt uitsluitend de bestaande public publishable key. Geen eigen
  IP-, user-agent-, fingerprint- of telemetry-opslag toegevoegd.

## Openstaande handmatige/operationele punten

De uitvoervolgorde staat in [`../privacy-launch.md`](../privacy-launch.md). Eerst
legacy-rows/consent-schema afhandelen, dan RPC-migration, SQL-tests en verificatie,
daarna de echte API/browser testen en publiceren. Alle nieuwe publieke privileges
en RLS moeten in Supabase bevestigd worden; lokaal geteste rechten zijn geen live bewijs.

De opdracht noemt GitHub Pages als hosting. Deze checkout bevat geen Pages-workflow,
CNAME of geverifieerde publieke URL. Productie-HTTPS, root versus project-subpad,
privacyroutes en hostingresources moeten nog op de echte deployment gecontroleerd
worden. De notice gebruikt de opgegeven host; hostinginstellingen zijn niet aangepast.

`privacy@machonce.com` moet afzonderlijk bestaan en worden gemonitord vóór livegang.
Richt het afhandelen van rechten/intrekking en de genoemde 24-maandsretentie in.
De toekomstige mailingflow moet een gratis eenvoudige uitschrijving bevatten.
Provider-/doorgifteafspraken en feitelijke Supabase-regio blijven beheer-/juridische
controles. Deze oplevering doet geen algemene AVG/GDPR-complianceclaim.

**Prompt-feedback:** de opdracht is uitvoerbaar. Eén conflict is opgelost met de
eigenaar: de nieuwe korte tekst kon niet dezelfde historische versie krijgen als
de bestaande lange tekst; v2 is expliciet goedgekeurd en v1 blijft behouden.
