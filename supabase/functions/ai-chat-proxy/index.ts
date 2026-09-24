import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const DEFAULT_MODEL = Deno.env.get("AI_MODEL") ?? "deepseek/deepseek-chat";
const MAX_MESSAGES = 24;
const MAX_MESSAGE_CHARS = 12000;
const MAX_TOTAL_CHARS = 50000;
const MAX_OUTPUT_TOKENS = 2500;
const DEFAULT_REQUESTS_PER_HOUR = 60;

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

type ChatMessage = {
  role: "user" | "assistant";
  content: string;
};

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

  const apiKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!apiKey) {
    return json({ error: "AI provider is not configured" }, 503);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = getServiceKey();
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json({ error: "AI authentication backend is not configured" }, 503);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const adminClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const token = authHeader.slice("Bearer ".length);
  const { data: userData, error: userError } = await userClient.auth.getUser(token);
  if (userError || !userData.user) {
    return json({ error: "Invalid authenticated session" }, 401);
  }

  const profileId =
    typeof userData.user.app_metadata?.profile_id === "string"
      ? userData.user.app_metadata.profile_id
      : null;

  if (!profileId) {
    return json({ error: "Select an active profile before using AI" }, 409);
  }

  const { data: profile, error: profileError } = await userClient
    .from("profiles")
    .select("id,school_id,role,status")
    .eq("id", profileId)
    .eq("user_id", userData.user.id)
    .is("deleted_at", null)
    .eq("status", "active")
    .maybeSingle();

  if (profileError) {
    console.error("AI profile validation failed", profileError.message);
    return json({ error: "Could not validate active profile" }, 500);
  }

  if (!profile || !["student", "teacher"].includes(profile.role)) {
    return json({ error: "AI access is available to active student and teacher profiles" }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const requestedMode =
    typeof body.mode === "string" && body.mode.trim()
      ? body.mode.trim()
      : profile.role === "teacher"
        ? "teacher_copilot"
        : "student_tutor";

  const teacherModes = new Set([
    "teacher_copilot",
    "lesson_planner",
    "quiz_exam",
    "report_remarks",
  ]);
  const studentModes = new Set(["student_tutor"]);

  if (
    (profile.role === "teacher" && !teacherModes.has(requestedMode)) ||
    (profile.role === "student" && !studentModes.has(requestedMode))
  ) {
    return json({ error: "AI mode is not available for this profile role" }, 403);
  }

  const rawMessages = body.messages;
  if (!Array.isArray(rawMessages) || rawMessages.length === 0) {
    return json({ error: "messages must be a non-empty array" }, 400);
  }
  if (rawMessages.length > MAX_MESSAGES) {
    return json({ error: `Too many messages; maximum is ${MAX_MESSAGES}` }, 400);
  }

  let totalChars = 0;
  const messages: ChatMessage[] = [];
  for (const raw of rawMessages) {
    if (!raw || typeof raw !== "object") {
      return json({ error: "Invalid message" }, 400);
    }
    const role = (raw as Record<string, unknown>).role;
    const content = (raw as Record<string, unknown>).content;
    if (!["user", "assistant"].includes(String(role))) {
      return json({ error: "Only user and assistant message roles are accepted" }, 400);
    }
    if (typeof content !== "string" || content.trim().length === 0) {
      return json({ error: "Message content must be non-empty text" }, 400);
    }
    if (content.length > MAX_MESSAGE_CHARS) {
      return json({ error: "A message is too long" }, 400);
    }
    totalChars += content.length;
    if (totalChars > MAX_TOTAL_CHARS) {
      return json({ error: "Conversation is too large" }, 400);
    }
    messages.push({ role: role as ChatMessage["role"], content });
  }

  const requestsPerHourRaw = Number(Deno.env.get("AI_REQUESTS_PER_HOUR") ?? DEFAULT_REQUESTS_PER_HOUR);
  const requestsPerHour =
    Number.isFinite(requestsPerHourRaw) && requestsPerHourRaw > 0
      ? Math.floor(requestsPerHourRaw)
      : DEFAULT_REQUESTS_PER_HOUR;

  const since = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count: recentCount, error: countError } = await adminClient
    .from("ai_usage_events")
    .select("id", { count: "exact", head: true })
    .eq("profile_id", profile.id)
    .gte("created_at", since)
    .in("status", ["started", "succeeded"]);

  if (countError) {
    console.error("AI rate-limit lookup failed", countError.message);
  } else if ((recentCount ?? 0) >= requestsPerHour) {
    await adminClient.from("ai_usage_events").insert({
      user_id: userData.user.id,
      school_id: profile.school_id,
      profile_id: profile.id,
      role: profile.role,
      mode: requestedMode,
      model: DEFAULT_MODEL,
      input_chars: totalChars,
      status: "rate_limited",
      completed_at: new Date().toISOString(),
    });
    return json({ error: "AI hourly usage limit reached. Please try again later." }, 429);
  }

  const systemPrompt =
    profile.role === "teacher"
      ? "You are the ZivoConnect Teacher Copilot. Support lesson planning, assessment design, feedback, and pedagogy. Be accurate, practical, curriculum-aware, and clearly label uncertainty. Do not claim official curriculum compliance unless the supplied source material supports it."
      : "You are the ZivoConnect Student AI Tutor. Teach clearly, encourage understanding, and help the learner reason through schoolwork. Be age-appropriate and avoid pretending to know school-specific facts that were not provided.";

  const requestedMaxTokens =
    typeof body.max_tokens === "number" && Number.isFinite(body.max_tokens)
      ? Math.floor(body.max_tokens)
      : 1200;
  const maxTokens = Math.max(64, Math.min(requestedMaxTokens, MAX_OUTPUT_TOKENS));

  const requestedTemperature =
    typeof body.temperature === "number" && Number.isFinite(body.temperature)
      ? body.temperature
      : 0.4;
  const temperature = Math.max(0, Math.min(requestedTemperature, 1.2));

  const { data: usageRow, error: usageInsertError } = await adminClient
    .from("ai_usage_events")
    .insert({
      user_id: userData.user.id,
      school_id: profile.school_id,
      profile_id: profile.id,
      role: profile.role,
      mode: requestedMode,
      model: DEFAULT_MODEL,
      input_chars: totalChars,
      status: "started",
    })
    .select("id")
    .single();

  if (usageInsertError) {
    console.error("AI usage insert failed", usageInsertError.message);
  }

  try {
    const providerResponse = await fetch(OPENROUTER_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "X-Title": "ZivoConnect EMS",
      },
      body: JSON.stringify({
        model: DEFAULT_MODEL,
        messages: [
          { role: "system", content: systemPrompt },
          ...messages,
        ],
        max_tokens: maxTokens,
        temperature,
      }),
    });

    const providerText = await providerResponse.text();

    if (!providerResponse.ok) {
      console.error("AI provider error", providerResponse.status, providerText.slice(0, 500));
      if (usageRow?.id) {
        await adminClient
          .from("ai_usage_events")
          .update({
            status: "failed",
            provider_status: providerResponse.status,
            completed_at: new Date().toISOString(),
          })
          .eq("id", usageRow.id);
      }
      return json(
        { error: "AI provider request failed", provider_status: providerResponse.status },
        providerResponse.status >= 500 ? 502 : 400,
      );
    }

    let providerData: Record<string, unknown>;
    try {
      providerData = JSON.parse(providerText);
    } catch {
      if (usageRow?.id) {
        await adminClient
          .from("ai_usage_events")
          .update({ status: "failed", completed_at: new Date().toISOString() })
          .eq("id", usageRow.id);
      }
      return json({ error: "Invalid AI provider response" }, 502);
    }

    const choices = providerData.choices;
    const firstChoice =
      Array.isArray(choices) && choices.length > 0
        ? (choices[0] as Record<string, unknown>)
        : null;
    const message =
      firstChoice && typeof firstChoice.message === "object"
        ? (firstChoice.message as Record<string, unknown>)
        : null;
    const content =
      message && typeof message.content === "string" ? message.content : null;

    if (!content) {
      if (usageRow?.id) {
        await adminClient
          .from("ai_usage_events")
          .update({ status: "failed", completed_at: new Date().toISOString() })
          .eq("id", usageRow.id);
      }
      return json({ error: "AI provider returned no response text" }, 502);
    }

    const usage =
      providerData.usage && typeof providerData.usage === "object"
        ? (providerData.usage as Record<string, unknown>)
        : {};

    if (usageRow?.id) {
      await adminClient
        .from("ai_usage_events")
        .update({
          status: "succeeded",
          provider_status: 200,
          output_chars: content.length,
          prompt_tokens: typeof usage.prompt_tokens === "number" ? usage.prompt_tokens : null,
          completion_tokens: typeof usage.completion_tokens === "number" ? usage.completion_tokens : null,
          total_tokens: typeof usage.total_tokens === "number" ? usage.total_tokens : null,
          completed_at: new Date().toISOString(),
        })
        .eq("id", usageRow.id);
    }

    return json({
      content,
      mode: requestedMode,
      model: typeof providerData.model === "string" ? providerData.model : DEFAULT_MODEL,
      usage: providerData.usage ?? null,
    });
  } catch (error) {
    console.error("AI proxy failure", error);
    if (usageRow?.id) {
      await adminClient
        .from("ai_usage_events")
        .update({ status: "failed", completed_at: new Date().toISOString() })
        .eq("id", usageRow.id);
    }
    return json({ error: "AI service is temporarily unavailable" }, 502);
  }
});
