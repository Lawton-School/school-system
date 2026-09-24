import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function getServiceKey(): string | null {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;

  const raw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!raw) return null;

  try {
    const parsed = JSON.parse(raw);
    return typeof parsed.default === "string" ? parsed.default : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return json({ error: "Authenticated session required" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = getServiceKey();

  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json({ error: "Server authentication is not configured" }, 503);
  }

  let profileId: string | null = null;
  try {
    const body = await req.json();
    profileId = typeof body?.profile_id === "string" ? body.profile_id : null;
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  if (!profileId || !/^[0-9a-fA-F-]{36}$/.test(profileId)) {
    return json({ error: "A valid profile_id is required" }, 400);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const token = authHeader.slice("Bearer ".length);
  const { data: userData, error: userError } = await userClient.auth.getUser(token);

  if (userError || !userData.user) {
    return json({ error: "Invalid authenticated session" }, 401);
  }

  const { data: profile, error: profileError } = await userClient
    .from("profiles")
    .select("id,school_id,role,status,first_name,last_name")
    .eq("id", profileId)
    .eq("user_id", userData.user.id)
    .is("deleted_at", null)
    .eq("status", "active")
    .maybeSingle();

  if (profileError) {
    console.error("profile lookup failed", profileError.message);
    return json({ error: "Could not validate profile" }, 500);
  }

  if (!profile) {
    return json({ error: "Profile not found or not authorized" }, 403);
  }

  const adminClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const existingAppMetadata =
    userData.user.app_metadata && typeof userData.user.app_metadata === "object"
      ? userData.user.app_metadata
      : {};

  const nextAppMetadata = {
    ...existingAppMetadata,
    school_id: profile.school_id,
    role: profile.role,
    profile_id: profile.id,
  };

  const { error: updateError } = await adminClient.auth.admin.updateUserById(
    userData.user.id,
    { app_metadata: nextAppMetadata },
  );

  if (updateError) {
    console.error("profile claim update failed", updateError.message);
    return json({ error: "Could not switch profile" }, 500);
  }

  return json({
    active_profile: {
      profile_id: profile.id,
      school_id: profile.school_id,
      role: profile.role,
      first_name: profile.first_name,
      last_name: profile.last_name,
    },
    refresh_session: true,
  });
});
