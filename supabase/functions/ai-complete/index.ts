// ============================================================================
//  Purrperty — Edge Function: ai-complete
// ============================================================================
//  The only thing in the system that holds a provider API key.
//
//  The iOS app sends one normalised request shape; this function translates it
//  for whichever vendor is named, calls them, and normalises the answer back.
//  Adding a provider is a change here plus one secret — never an app release.
//
//  It also does the three things a client cannot be trusted to do:
//
//   1. Resolve the caller's organization from their JWT. The app never sends
//      an org id, so it cannot spend another workspace's budget.
//   2. Enforce the monthly budget before calling out. A client-side cap is a
//      suggestion; this is the control that stops a runaway loop.
//   3. Record the invocation. Logging on the server means an audit row cannot
//      be dropped by an app that crashed mid-call.
//
//  Deploy:  supabase functions deploy ai-complete
//  Secrets: supabase secrets set OPENAI_API_KEY=... ANTHROPIC_API_KEY=... \
//                                GEMINI_API_KEY=...
// ============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

// ── Model selection ─────────────────────────────────────────────────────────
//  The capability→model mapping lives here, server-side, so a model
//  deprecation is a config change rather than an app update. This is the
//  table that keeps model names out of the Swift codebase entirely.

const MODELS: Record<string, Record<string, string>> = {
  openai: {
    fast: "gpt-4o-mini",
    reasoning: "gpt-4o",
    longContext: "gpt-4o",
  },
  anthropic: {
    fast: "claude-haiku-4-5-20251001",
    reasoning: "claude-opus-5",
    longContext: "claude-sonnet-5",
  },
  gemini: {
    fast: "gemini-2.5-flash",
    reasoning: "gemini-2.5-pro",
    longContext: "gemini-2.5-pro",
  },
};

// Rough USD per 1M tokens, for budget accounting. Approximate on purpose —
// the goal is a cap that works, not an invoice.
const PRICING: Record<string, { input: number; output: number }> = {
  "gpt-4o-mini": { input: 0.15, output: 0.60 },
  "gpt-4o": { input: 2.50, output: 10.00 },
  "claude-haiku-4-5-20251001": { input: 1.00, output: 5.00 },
  "claude-opus-5": { input: 15.00, output: 75.00 },
  "claude-sonnet-5": { input: 3.00, output: 15.00 },
  "gemini-2.5-flash": { input: 0.30, output: 2.50 },
  "gemini-2.5-pro": { input: 1.25, output: 10.00 },
};

interface Message {
  role: "system" | "user" | "assistant" | "tool";
  content: string;
  tool_call_id?: string;
  tool_name?: string;
}

interface EdgeRequest {
  vendor: keyof typeof MODELS;
  preference: string;
  messages: Message[];
  response_schema?: Record<string, unknown>;
  tools?: { name: string; description: string; parameters: Record<string, unknown> }[];
  max_output_tokens: number;
  temperature: number;
  subject_type?: string;
  subject_id?: string;
}

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function fail(code: string, message: string, status = 200) {
  // Returned as 200 with an error envelope: the app distinguishes provider
  // failures from transport failures, and a 500 would collapse the two.
  return new Response(JSON.stringify({ error: { code, message } }), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    // ── Identity ────────────────────────────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return fail("not_configured", "Missing authorization", 401);

    // Created with the caller's JWT so every query below runs under their RLS.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: userData } = await supabase.auth.getUser();
    const user = userData?.user;
    if (!user) return fail("not_configured", "Not authenticated", 401);

    // The org comes from the database, never from the request body.
    const { data: profile } = await supabase
      .from("users")
      .select("organization_id")
      .eq("id", user.id)
      .single();

    const organizationId = profile?.organization_id;
    if (!organizationId) return fail("not_configured", "No organization for this user");

    // ── Budget ──────────────────────────────────────────────────────────────
    const { data: mayProceed } = await supabase.rpc("ai_may_proceed", {
      p_organization_id: organizationId,
    });
    if (mayProceed === false) {
      return fail("budget_exceeded", "Monthly AI budget reached");
    }

    // ── Dispatch ────────────────────────────────────────────────────────────
    const body: EdgeRequest = await req.json();
    const vendor = body.vendor;
    const model = MODELS[vendor]?.[body.preference] ?? MODELS[vendor]?.fast;
    if (!model) return fail("not_configured", `Unknown vendor '${vendor}'`);

    const started = Date.now();
    let result: { text: string; input: number; output: number; finish: string; structured?: unknown };

    switch (vendor) {
      case "openai":
        result = await callOpenAI(body, model);
        break;
      case "anthropic":
        result = await callAnthropic(body, model);
        break;
      case "gemini":
        result = await callGemini(body, model);
        break;
      default:
        return fail("not_configured", `Unsupported vendor '${vendor}'`);
    }

    const price = PRICING[model] ?? { input: 0, output: 0 };
    const cost = (result.input / 1_000_000) * price.input +
                 (result.output / 1_000_000) * price.output;
    const latency = Date.now() - started;

    // ── Audit ───────────────────────────────────────────────────────────────
    // Best-effort: a lost log row must not fail a request the user is waiting
    // on. The client also logs, so a gap here is visible rather than silent.
    await supabase.from("ai_invocations").insert({
      actor_user_id: user.id,
      task_kind: inferTaskKind(body),
      prompt_version: "edge",
      provider_id: vendor,
      model_id: model,
      preference: body.preference,
      subject_type: body.subject_type ?? null,
      subject_id: body.subject_id ?? null,
      input_tokens: result.input,
      output_tokens: result.output,
      estimated_cost_usd: cost,
      latency_ms: latency,
      decoded_ok: true,
      status: "auto_applied",
      prompt_digest: "edge",
    }).then(undefined, () => {/* ignore */});

    return new Response(
      JSON.stringify({
        text: result.text,
        structured: result.structured ?? null,
        finish_reason: result.finish,
        model,
        usage: {
          input_tokens: result.input,
          output_tokens: result.output,
          estimated_cost_usd: cost,
        },
      }),
      { headers: { ...CORS, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return fail("transport", String(error));
  }
});

// The app sends the task kind implicitly via the subject; a dedicated field
// would be better and is the obvious next change here.
function inferTaskKind(body: EdgeRequest): string {
  if (body.subject_type === "maintenance_request") return "maintenance_classification";
  if (body.subject_type === "lease") return "lease_summarization";
  if (body.subject_type === "document") return "document_summary";
  if (body.subject_type === "conversation") return "suggested_reply";
  if (body.subject_type === "property") return "property_health";
  return "portfolio_copilot";
}

// ── OpenAI ──────────────────────────────────────────────────────────────────

async function callOpenAI(body: EdgeRequest, model: string) {
  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) throw new Error("OPENAI_API_KEY not set");

  const payload: Record<string, unknown> = {
    model,
    messages: body.messages.map((m) => ({
      role: m.role === "tool" ? "tool" : m.role,
      content: m.content,
      ...(m.tool_call_id ? { tool_call_id: m.tool_call_id } : {}),
    })),
    max_completion_tokens: body.max_output_tokens,
    temperature: body.temperature,
  };

  if (body.response_schema) {
    payload.response_format = {
      type: "json_schema",
      json_schema: { name: "result", strict: true, schema: body.response_schema },
    };
  }

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  if (response.status === 429) throw new Error("rate_limited");
  const json = await response.json();
  const text = json.choices?.[0]?.message?.content ?? "";

  return {
    text,
    structured: body.response_schema ? safeParse(text) : undefined,
    finish: json.choices?.[0]?.finish_reason ?? "stop",
    input: json.usage?.prompt_tokens ?? 0,
    output: json.usage?.completion_tokens ?? 0,
  };
}

// ── Anthropic ───────────────────────────────────────────────────────────────

async function callAnthropic(body: EdgeRequest, model: string) {
  const key = Deno.env.get("ANTHROPIC_API_KEY");
  if (!key) throw new Error("ANTHROPIC_API_KEY not set");

  // Anthropic takes the system prompt as a top-level field, not a message.
  const system = body.messages.filter((m) => m.role === "system")
    .map((m) => m.content).join("\n\n");
  const messages = body.messages.filter((m) => m.role !== "system")
    .map((m) => ({
      role: m.role === "assistant" ? "assistant" : "user",
      content: m.content,
    }));

  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": key,
      "anthropic-version": "2023-06-01",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      system: body.response_schema
        // Anthropic has no JSON-schema mode, so the contract is stated in the
        // prompt and validated on the way out.
        ? `${system}\n\nRespond with JSON only, matching this schema:\n${JSON.stringify(body.response_schema)}`
        : system,
      messages,
      max_tokens: body.max_output_tokens,
      temperature: body.temperature,
    }),
  });

  if (response.status === 429) throw new Error("rate_limited");
  const json = await response.json();
  const text = json.content?.map((c: { text?: string }) => c.text ?? "").join("") ?? "";

  return {
    text,
    structured: body.response_schema ? safeParse(text) : undefined,
    finish: json.stop_reason === "max_tokens" ? "length" : "stop",
    input: json.usage?.input_tokens ?? 0,
    output: json.usage?.output_tokens ?? 0,
  };
}

// ── Gemini ──────────────────────────────────────────────────────────────────

async function callGemini(body: EdgeRequest, model: string) {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) throw new Error("GEMINI_API_KEY not set");

  const system = body.messages.filter((m) => m.role === "system")
    .map((m) => m.content).join("\n\n");
  const contents = body.messages.filter((m) => m.role !== "system").map((m) => ({
    role: m.role === "assistant" ? "model" : "user",
    parts: [{ text: m.content }],
  }));

  const generationConfig: Record<string, unknown> = {
    maxOutputTokens: body.max_output_tokens,
    temperature: body.temperature,
  };
  if (body.response_schema) {
    generationConfig.responseMimeType = "application/json";
    generationConfig.responseSchema = stripUnsupported(body.response_schema);
  }

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        systemInstruction: system ? { parts: [{ text: system }] } : undefined,
        contents,
        generationConfig,
      }),
    },
  );

  if (response.status === 429) throw new Error("rate_limited");
  const json = await response.json();
  const text = json.candidates?.[0]?.content?.parts
    ?.map((p: { text?: string }) => p.text ?? "").join("") ?? "";

  return {
    text,
    structured: body.response_schema ? safeParse(text) : undefined,
    finish: json.candidates?.[0]?.finishReason === "MAX_TOKENS" ? "length" : "stop",
    input: json.usageMetadata?.promptTokenCount ?? 0,
    output: json.usageMetadata?.candidatesTokenCount ?? 0,
  };
}

// Gemini rejects `additionalProperties`, which OpenAI's strict mode requires.
// One schema, two dialects — normalising here is exactly the vendor-specific
// work that must not leak into the app.
function stripUnsupported(schema: unknown): unknown {
  if (Array.isArray(schema)) return schema.map(stripUnsupported);
  if (schema && typeof schema === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(schema)) {
      if (k === "additionalProperties") continue;
      out[k] = stripUnsupported(v);
    }
    return out;
  }
  return schema;
}

function safeParse(text: string): unknown {
  try {
    const start = text.search(/[{[]/);
    if (start < 0) return null;
    const end = Math.max(text.lastIndexOf("}"), text.lastIndexOf("]"));
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return null;
  }
}
