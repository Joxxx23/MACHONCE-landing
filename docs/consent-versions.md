# MACHONCE waitlist consent versions

## waitlist-v1-2026-09-17

**Version:** `waitlist-v1-2026-09-17`

**Effective date:** 17 September 2026

**Exact consent text:**

> Yes, I’d like to receive MACHONCE early-access, closed-alpha and launch emails. I confirm that I am 16 or older. I can unsubscribe at any time.

Purpose: consent to MACHONCE early-access, closed-alpha and closely related launch
emails, including the person's confirmation that they are 16 or older. The Privacy
Notice is provided for information; the checkbox does not ask agreement to it.

Store the version with the normalized email. The database-generated `created_at`
records the registration/consent time. The effective date is a version label, not
evidence of consent before someone actually checks the box and submits. Never
backfill this version onto older registrations. Preserve this text when adding
future versions.
