/** @type {Promise<import('@supabase/supabase-js').SupabaseClient> | undefined} */
let clientPromise;

/** Load the public, unauthenticated client only when someone submits the form. */
export function getSupabaseClient() {
  const url = import.meta.env.VITE_SUPABASE_URL?.trim();
  const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim();

  if (!url || !key?.startsWith('sb_publishable_')) {
    throw new Error('Waitlist is unavailable.');
  }

  if (!clientPromise) {
    clientPromise = import('@supabase/supabase-js')
      .then(({ createClient }) => createClient(url, key, {
        db: { schema: 'public' },
        auth: {
          persistSession: false,
          autoRefreshToken: false,
          detectSessionInUrl: false,
        },
      }))
      .catch(() => {
        clientPromise = undefined;
        throw new Error('Waitlist is unavailable.');
      });
  }

  return clientPromise;
}
