// Supabase Edge Function: set-user-claims
// Triggered after a user logs in to inject school_id, role, and profile_id
// into the JWT app_metadata so RLS policies can use them efficiently.
//
// Deploy with: supabase functions deploy set-user-claims
//
// To use as an auth hook:
// 1. Go to Supabase Dashboard → Authentication → Hooks
// 2. Add a "Custom Access Token" hook pointing to this function

import { createClient } from 'npm:@supabase/supabase-js@2'

Deno.serve(async (req: Request) => {
  try {
    const body = await req.json()
    const { user_id, event } = body

    // Only run on sign-in events
    if (event !== 'login' && event !== 'token_refresh' && event !== 'user_updated') {
      return new Response(JSON.stringify({ message: 'skipped' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    if (!user_id) {
      return new Response(JSON.stringify({ error: 'user_id is required' }), { status: 400 })
    }

    // Use the service role key — this function runs server-side
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Fetch the first active profile for this user (default session)
    const { data: profile, error } = await supabase
      .from('profiles')
      .select('id, school_id, role, schools(name, subdomain)')
      .eq('user_id', user_id)
      .is('deleted_at', null)
      .eq('status', 'active')
      .order('created_at', { ascending: true })
      .limit(1)
      .single()

    if (error || !profile) {
      // User may not have a profile yet (just invited) — return empty claims
      return new Response(JSON.stringify({ app_metadata: {} }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // Inject claims into app_metadata (used by RLS helper functions)
    const claims = {
      school_id: profile.school_id,
      role: profile.role,
      profile_id: profile.id,
    }

    return new Response(JSON.stringify({ app_metadata: claims }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
