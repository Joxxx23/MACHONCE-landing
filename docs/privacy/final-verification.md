# Finale live waitlist-verificatie — 18 september 2026

**WAITLIST TECHNICALLY READY FOR DEPLOYMENT**

Dit verslag vervangt de eerdere voorlopige live status in
`security-verification.md`. De eerdere verslagen blijven historische informatie.
Getest: de productiebuild op `http://127.0.0.1:4173/` tegen het echte Supabase-project
`nnxiznuhowblhmcxpfoh`. Database-metadata en opruiming zijn gecontroleerd via de
ingelogde Supabase SQL Editor. Er zijn geen migrations opnieuw uitgevoerd.

## Resultaten

1. **Repository:** uitsluitend `D:\ChatGPT\MACHONCE-landing` gebruikt. Root en
   remote `https://github.com/Joxxx23/MACHONCE-landing.git` gecontroleerd. De
   afzonderlijke MACHONCE-app is niet gelezen of gewijzigd.
2. **Branch:** `feat/landing-v1`. Niet gecommit, gepusht of gepubliceerd.
3. **Nieuwe registratie:** via het echte formulier een uniek technisch
   `@example.com`-adres met hoofdletters en omringende spaties ingestuurd. Eén POST
   naar `/rest/v1/rpc/join_waitlist`, met alleen `email` en `consent_version`.
   HTTP 200, succes in de UI. Vooraf bestonden nul bijbehorende records; na beide
   inzendingen precies één, getrimd en lowercase, met `waitlist-v2-2026-09-18`.
   UUID `a1f1d5f3-7390-430f-a4fc-553c3d615020` en
   `created_at = 2026-09-18T20:43:59.402566+00:00` zijn door de database gegenereerd:
   de request bevatte deze velden niet en de actuele defaults zijn
   `gen_random_uuid()` en `now()`.
4. **Duplicate:** hetzelfde adres opnieuw via het formulier ingediend. Eén POST,
   opnieuw HTTP 200, dezelfde response en volledige formulierstatus. De database
   bevatte na beide inzendingen één record. Geen tweede insert vanuit de client,
   lookup, upsert of update; de bestaande SQL gebruikt `ON CONFLICT DO NOTHING`.
5. **Consentvalidatie:** nieuw bezoek standaard uitgevinkt. Geldig adres zonder
   checkbox geeft duidelijke consentvalidatie en nul requests; ongeldig adres met
   checkbox geeft e-mailvalidatie en nul requests. Geldige inzending bevat v2.
   De eigenaar heeft in deze taak expliciet bevestigd dat de huidige compacte
   v2 moet worden geverifieerd en ongewijzigd blijft; v1-historie blijft behouden.
6. **Publieke response:** beide succesvolle POSTs retourneerden exact
   `{"accepted": true}` met `application/json; charset=utf-8` en
   `Content-Range: 0-0/*`. Geen row, ID, tijdstip, duplicatevlag of databasefout.
   Een aparte ongeldige RPC-invoer gaf HTTP 200 met `{"accepted":false}`.
7. **Onderscheid nieuw/bestaand:** geen bestaansindicator in de geteste status,
   responsebody of UI. Beide tonen exact de bestaande tekst **`You’re in.`**
   (typografische apostrof, ongewijzigd). De formulier-HTML was ook gelijk.
   Dit is verificatie van het publieke responsecontract, geen bewijs van constante
   verwerkingstijd. Algemene fouten blijven de bestaande algemene UI-fout geven.
8. **Tabelrechten:** PUBLIC heeft geen tabelgrants; anon en authenticated hebben
   geen SELECT, INSERT, UPDATE, DELETE of TRUNCATE, ook geen losse
   SELECT/INSERT/UPDATE-kolomrechten. Echte publieke HTTP-probes voor SELECT,
   INSERT, UPDATE en DELETE gaven elk **401 / 42501**. TRUNCATE is gecontroleerd
   via de actuele privilege-metadata, zonder een TRUNCATE uit te voeren.
9. **RPC EXECUTE:** `join_waitlist(text,text)` is uitvoerbaar door anon en de
   function owner; niet door PUBLIC of authenticated. Er bestaat daarnaast een
   publiek uitvoerbare `rls_auto_enable()`-hulpfunctie: zie de precieze uitzondering
   hieronder. Er is geen andere aangetroffen publieke functie die waitlistdata
   leest of teruggeeft.
10. **RLS:** actief op `public.waitlist`, table owner `postgres`. Writer-policies
    beperken INSERT tot genormaliseerde adressen met v2 en staan de interne
    conflictcontrole toe. Een oude policy `Public can join waitlist` voor anon
    INSERT bestaat nog. Zonder INSERT-grant verleent deze geen toegang; dit is
    ook met de echte geweigerde HTTP-insert vastgesteld. Niet gewijzigd.
11. **Function security:** `join_waitlist` gebruikt SECURITY DEFINER, owner
    `machonce_waitlist_writer`, lege `search_path` en expliciete schemanamen.
    De interne NOLOGIN/NOINHERIT-rol heeft geen superuser, BYPASSRLS, CREATEDB,
    CREATEROLE of replicatierechten. Alleen de benodigde kolomrechten voor INSERT
    en conflictcontrole zijn verleend. Anon/authenticated zijn geen lid. De
    twee membership-entries betreffen allebei dezelfde beheerder `postgres`,
    verleend door verschillende grantors; geen tweede persoon of publieke rol.
    De live function body komt overeen met de voorbereide architectuur en
    retourneert bij opgevangen fouten alleen `{"accepted":false}`.
12. **Secrets:** broncode, productiebuild, lokale configuratie en de beschikbare
    Git-geschiedenis gescand: geen secret key, service-role JWT, private key of
    credentialhoudende database-URL gevonden. Alleen Project URL en publishable
    key in de frontendconfiguratie. `.env.local` is Git-ignored; `.env.example`
    heeft uitsluitend lege placeholders. Geen volledige keys opgenomen.
13. **Logging/storage/cookies/tracking:** in de echte browserflow geen e-mailadres
    of database-detail in de console, geen JavaScript-runtimefouten, geen
    opgeslagen cookies, lege localStorage en sessionStorage. De applicatiecode
    logt geen adressen of fouten. Geen eigen applicatiebackend/logger aanwezig;
    infrastructuurlogs van hosting/Supabase vallen buiten die broncodecontrole.
    Supabase stuurde op beide responses een **`__cf_bm` Set-Cookie-header**;
    de browser sloeg die in deze flow niet op. Vóór submit alleen eigen resources,
    na submit alleen Supabase als externe origin; geen externe fonts, trackers
    of analytics aangetroffen.
14. **Privacy-regressie:** `/privacy` direct en na refresh werkt; formulierlink,
    footerlink en teruglink werken. De withdrawal-link bevat alleen het vaste
    onderwerp. Privacy Notice werkt ook zonder JavaScript. Mobiel visueel
    gecontroleerd; leesbare tekst, checkbox via label/toetsenbord en zichtbare
    focus. Geen horizontale overflow op 320, 390, 600, 768, 1680 en 1920 px.
15. **Opruiming:** uitsluitend de ene fixture van deze verificatie verwijderd,
    met exacte UUID, adres, consentversie en timestamp als voorwaarden. DELETE
    rapporteerde **1 verwijderd**; een afzonderlijke nacontrole rapporteerde
    **0 resterende records** voor dit adres. Geen onbekende of eerdere data gewist.
16. **Projectchecks na E2E:** 21/21 servicetests, 14/14 bestaande
    browserregressiechecks met lokale SQL en gesimuleerd HTTP-transport, lint,
    typecheck en production build geslaagd. De afzonderlijke echte live E2E-run
    had 8/8 geslaagde controles. Geen fout in de implementatie gevonden.
17. **E-maildefault:** `email` heeft inderdaad `DEFAULT ''::text` en NOT NULL.
    De beschikbare schemahistorie verklaart de herkomst niet. De default is niet
    nodig: de RPC levert altijd zelf een gevalideerd adres aan en publieke
    tabelinserts zijn geblokkeerd. Advies: vóór livegang als afzonderlijke kleine
    schema-opruiming verwijderen, zodat ook een onvolledige beheerinsert duidelijk
    faalt. Geen blokkade voor de geteste publieke flow; conform opdracht niet
    automatisch gewijzigd. `consent_version` is NOT NULL en heeft geen default.
18. **Resterende livegangspunten:** geen aangetoonde technische blokkade in de
    waitlist-integratie. De echte publieke deployment/HTTPS en routes moeten op
    de uiteindelijke host nog worden gecontroleerd; de huidige build veronderstelt
    publicatie op de domeinroot. Mailbox `privacy@machonce.com`, afhandeling van
    intrekking/rechten, retentie en provider-/doorgifteafspraken zijn afzonderlijke
    operationele/juridische punten. De dashboardregio is **West Europe (London),
    eu-west-2**; dit verslag doet geen claim dat de database binnen de EU staat.
    READY betreft uitsluitend de technisch geteste waitlist-integratie.

## Bestaande helper: afwijking op de brede formulering van EXECUTE

Een absolute claim dat maar één functie in `public` publiek EXECUTE heeft, zou
onjuist zijn. Naast de bedoelde RPC bestaat `public.rls_auto_enable()`, owner
`postgres`, SECURITY DEFINER met `search_path=pg_catalog`, returntype
`event_trigger`. Die hangt aan event trigger `ensure_rls` op `ddl_command_end`.
De gecontroleerde body schakelt RLS in bij tabelcreatie en bevat geen toegang tot
waitlistregistraties. Een publieke POST naar de helper gaf **HTTP 400 / 0A000**,
`cannot display a value of type event_trigger`; hij levert geen waitlistdata of
registratieresultaat. Deze bestaande DDL-helper is geen alternatieve registratie-
of uitleesroute. Geen function grants of triggerinstellingen aangepast.

## Ongewijzigde consenttekst

> I’m 16+ and want MACHONCE early-access, closed-alpha and launch emails. I can unsubscribe anytime.

Versie: `waitlist-v2-2026-09-18`. De v1-historie is ongewijzigd.

## Wijzigingen en bewijs

Alleen dit verslag toegevoegd en de README-verwijzing naar de actuele verificatie
bijgewerkt. Applicatie, styling, dependencies, config en SQL-migrations ongewijzigd;
SHA-256-vergelijking bevestigt dezelfde 11 vooraf vastgelegde runtime-/configbestanden.
De databasewijziging was uitsluitend het tijdelijk aanmaken en verwijderen van
de eigen technische fixture.

Tijdelijke testhulpbestanden en resultaten staan onder de bestaande Git-ignored
`.qa/`, waaronder `final-e2e.cjs`, `final-e2e-results.json`, `final-run.json`,
`final-static-audit.mjs`, `final-static-audit.json` en de mobiele screenshot.
De gegevens hierboven over live rechten, de opgeslagen fixture en opruiming zijn
afgelezen uit de daadwerkelijk uitgevoerde SQL Editor-resultaten.

**Prompt-feedback:** de verificatiescope was duidelijk. De prompt verwees nog naar
de lange v1 terwijl compacte v2 al was goedgekeurd. Vermeld bij toekomstige
verificaties de actuele goedgekeurde tekst/versie; dit is hier vooraf afgestemd.
