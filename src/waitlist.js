import { getSupabaseClient } from './supabase.js';

export const CONSENT_VERSION = 'waitlist-v2-2026-09-18';

/** @param {string} email @param {boolean} consentGiven @returns {Promise<'accepted'>} */
export async function submitEmail(email, consentGiven) {
  if (consentGiven !== true) throw new Error('Consent is required.');
  const normalizedEmail = email.trim().toLowerCase();
  const supabase = await getSupabaseClient();

  // The RPC returns the same acknowledgement for a new or existing address.
  const { data, error } = await supabase
    .rpc('join_waitlist', { email: normalizedEmail, consent_version: CONSENT_VERSION })
    .retry(false)
    .abortSignal(AbortSignal.timeout(10000));

  if (error || data?.accepted !== true) throw new Error('Waitlist request failed.');
  return 'accepted';
}
