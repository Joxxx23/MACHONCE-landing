# Waitlist-verificatie — 17 september 2026

Uitgevoerd vanuit `MACHONCE-landing`, branch `feat/landing-v1`, met uitsluitend de
aangeleverde Project URL en Publishable Key. `.env.local` is gecontroleerd als
Git-ignored. Er zijn geen databasepolicies of permissions gewijzigd.

## Echte Supabase-controles

| Controle | Waargenomen resultaat |
| --- | --- |
| Nieuwe inschrijving via de productiepreview | HTTP 201; `You're in.` |
| Normalisatie | Alleen `{ email }` verstuurd, getrimd en lowercase |
| Hetzelfde adres opnieuw | HTTP 409, PostgreSQL `23505`; `Early access already confirmed.` |
| Publieke SELECT | HTTP 401, PostgreSQL `42501` (permission denied) |
| Publieke UPDATE | HTTP 401, PostgreSQL `42501` (permission denied) |
| Publieke DELETE | HTTP 401, PostgreSQL `42501` (permission denied) |

De permission-probes waren gefilterd op uitsluitend de nieuw aangemaakte testrow.
Er zijn geen bestaande inschrijvingen aangepast. De INSERT vroeg geen row terug en
stuurde geen `id` of `created_at`; beide velden zijn aan de database overgelaten.
De concrete gegenereerde waarden zijn niet uitgelezen, omdat de publieke client
terecht geen SELECT-recht heeft. Een controle daarvan in het beheerdersdashboard
is niet uitgevoerd.

Deze herkenbare testinschrijving blijft aanwezig, omdat publieke DELETE terecht
geblokkeerd is. Desgewenst kan de eigenaar haar in het Supabase-dashboard verwijderen:

`machonce-qa-6d591aff-2db0-4111-9e39-b3a939f4bd4e@example.com`

## Lokale controles

- 13 herhaalbare servicetests met `npm test`, de echte Supabase-client en een
  gesimuleerd HTTP-transport: normalisatie, minimale INSERT, duplicate-code,
  verschillende API-fouten, netwerkfout, ongeldige respons, timeout en configuratiefouten.
- 10 browsertests met onderschepte API-requests: ongeldige invoer zonder request,
  loading/dubbele submits, success, duplicate, algemene fouten, herstel na fouten,
  ontbrekende configuratie en geen auth-cookies of localStorage-sessie.
- Lint, JavaScript-typecheck en productiebuild geslaagd.
- Geen Supabase-secret-keyliteral in de productie-JavaScript aangetroffen; uitsluitend
  de bedoelde publieke configuratie is opgenomen.
- Layout, styling, intro en assets zijn voor deze koppeling ongewijzigd gebleven.

Gesimuleerde tests bewijzen geen databasebeveiliging; daarvoor zijn hierboven de
afzonderlijke echte permission-checks opgenomen. Deze resultaten gelden voor de
geteste configuratie op deze datum. Herhaal de live controles na policywijzigingen.
