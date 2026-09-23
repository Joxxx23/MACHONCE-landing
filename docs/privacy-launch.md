# Waitlist — veilige RPC en livegang

De frontend vereist nu `join_waitlist(email, consent_version)`, met
`waitlist-v2-2026-09-18`. Publiceer haar pas na de databasewijziging en live tests.
Er is geen terugval naar directe INSERT. De bestaande publieke sleutel kan het
schema niet beheren; gebruik de Supabase SQL Editor als `postgres`. Zet geen
databasewachtwoord of service-role key in de repository/frontend.

## Exacte volgorde in Supabase

1. Voer [`waitlist-consent-preflight.sql`](../database/waitlist-consent-preflight.sql)
   uit als de vorige consent-migration nog niet is afgerond. Beoordeel bestaande rows
   binnen het dashboard. De bekende technische row uit de eerste fase was
   `machonce-qa-6d591aff-2db0-4111-9e39-b3a939f4bd4e@example.com`; controleer of die
   nog bestaat. Behandel technische tests niet als toestemming van een persoon.
   Verwijder onbekende/echte adressen niet blind en verzin geen historische consent.
2. Ontbreekt `consent_version text NOT NULL` zonder default, voer dan na verantwoorde
   afhandeling van legacy-rows [`waitlist-consent.sql`](../database/waitlist-consent.sql)
   uit. Dit script stopt bij oude rows zonder consentversie; niets wordt backfilled.
3. Voer [`waitlist-rpc.sql`](../database/waitlist-rpc.sql) als één geheel uit.
   De transactionele wijziging maakt de RPC, zet RLS aan en trekt directe tabel- én
   kolomrechten van PUBLIC/anon/authenticated in. Zij stopt bij ongeschikte bestaande
   normalisatie, schema, role-inheritance of onverwachte functieoverloads. Er worden
   geen rows verwijderd, bijgewerkt of opnieuw van toestemming voorzien.
4. Voer [`waitlist-rpc-test.sql`](../database/waitlist-rpc-test.sql) uit. Deze test
   gebruikt uitsluitend herkenbare, willekeurige technische fixtures en eindigt met
   ROLLBACK. Zij test de echte SQL-functie onder anon, dubbele normalisatie naar één
   rij, id/created_at/versie, behouden v1-bewijs, RLS/rechten, inputvalidatie en een
   geforceerde interne fout. Verwacht als laatste resultaat `PASS: ...`.
   Bij een fout: voer `ROLLBACK;` uit, beoordeel de fout en publiceer nog niet.
5. Voer [`waitlist-rpc-verify.sql`](../database/waitlist-rpc-verify.sql) uit. Verwacht:
   RLS `true`; anon alleen RPC-EXECUTE; alle directe tabel- en kolomrechten voor
   anon/authenticated `false`; authenticated ook geen EXECUTE. De interne writer
   mag INSERT(email, consent_version) en SELECT(email) voor conflictcontrole, zonder
   login/superuser/RLS-bypass. Alleen de beheerder is lid van die rol. Bekijk ook
   eventuele andere publieke functies die de waitlist noemen: geen alternatieve
   route mag adressen of hun bestaan onthullen.
6. Test via de echte browser en public key: één nieuw technisch adres, nogmaals
   hetzelfde adres en een variant met hoofdletters/spaties. Verwacht steeds HTTP 200
   met exact `{"accepted":true}` en `You’re in.`. Geen `23505`, constraintnaam of
   bestaansvlag in response of console. Controleer via de beheeromgeving één rij met
   lowercase email, UUID, database-created_at en v2. Houd de publieke SELECT gesloten.
   Verwijder de herkenbare technische testrow daarna via de beheeromgeving.
7. Controleer via de publieke Data API opnieuw dat SELECT, UPDATE, DELETE en directe
   INSERT expliciet worden geweigerd. Ontbrekende of onjuiste consentversies mogen
   via de RPC uitsluitend `{"accepted":false}` geven en geen rij aanmaken.

Voer de scripts niet als losse willekeurige fragmenten uit. Een oude frontend die
nog directe INSERT gebruikt zal na de cutover falen; publiceer de nieuwe build aansluitend.
De vaste RPC-response bevat geen rij, ID, timestamp, telling of duplicate-indicator.
Een herhaalde inschrijving wijzigt de oorspronkelijke consentversie/datum niet.

## GitHub Pages, mailbox en privacyproces

- De opdracht noemt GitHub Pages als host. Er is hier geen Pages-workflow/CNAME of
  geverifieerde publieke site-URL beschikbaar. Publiceer de volledige `dist/` en
  controleer HTTPS, `/privacy`, `/privacy/`, direct openen, refresh en alle assets.
  De huidige absolute rootpaden passen bij een rootdomein; een Pages-projectsite op
  `/MACHONCE-landing/` vereist eerst een passende base-URL voor alle paden.
- Vite's lokale directoryredirect is geen productiehostingconfiguratie. Herhaal de
  browser-, cookie-, storage- en netwerkaudit op de echte Pages-URL.
- Stel alleen de bestaande publieke Vite-configuratie in de buildomgeving in.
  Publiceer geen `.env.local`, testfixtures of source/configuratie met private credentials.
- `privacy@machonce.com` moet vóór livegang als mailbox/alias bestaan en worden
  gemonitord. De code toont contactlinks; zij configureert of test geen mailbox.
  `Withdraw consent` opent een mail met een vast onderwerp, zonder het adres van de
  aanvrager in queryparameters. De gebruiker moet de mail zelf opstellen/verzenden.
- Richt de afhandeling van intrekking, inzage/correctie/verwijdering en de opgegeven
  bewaartermijn in. De notice noemt maximaal 24 maanden, naast eerdere beëindiging
  of intrekking. Controleer tijdig `created_at`; een duplicate verlengt deze termijn
  niet. Deze wijziging bouwt geen retentiejob of automatische verwijdering.
- Iedere latere relevante mail moet een eenvoudige gratis uitschrijfmogelijkheid
  hebben, de afzender duidelijk maken en eerdere intrekkingen respecteren. Er is
  geen mailingprovider, confirmation-email of unsubscribe-backend toegevoegd.
- Verifieer providerafspraken, toepasselijke doorgiftemechanismen en feitelijke
  Supabase-regio. Er wordt geen EU-regioclaim gedaan; technische implementatie alleen
  is geen beoordeling van juridische naleving.

## Grenzen van de controle

De lokale PostgreSQL-tests en browsertests bewijzen de voorbereide implementatie,
niet dat de migration al op Supabase draait. PostgREST-/proxyfouten buiten de functie
(zoals een nog ontbrekende RPC) vallen niet onder haar foutafhandeling. Normale
databasefouten binnen de functie worden teruggebracht tot een vast failure-object.
Identieke status/body zijn getest; er is geen formele constante-tijdgarantie voor
alle infrastructuur- of storingssituaties. Een publieke registratie bewijst ook
niet wie eigenaar is van het opgegeven adres of hoe oud die persoon is.
