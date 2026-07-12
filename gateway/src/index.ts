/**
 * ALICE Gateway — Cloudflare Worker
 *
 * Proxy that holds API keys as secrets so nothing sensitive ships in the app.
 * Routes:
 *   POST /chat            → Claude (streaming SSE) or OpenAI (standard)
 *   POST /tts             → ElevenLabs text-to-speech
 *   POST /transcribe      → OpenAI Whisper transcription
 *   POST /transcribe-token → AssemblyAI upload URL
 *   GET  /transcribe/:id  → AssemblyAI transcript poll
 *   POST /computer-use    → Claude Computer Use element detection
 *
 * Secrets: ANTHROPIC_API_KEY, OPENAI_API_KEY, ASSEMBLYAI_API_KEY,
 *          ELEVENLABS_API_KEY, ELEVENLABS_VOICE_ID
 */

export interface Env {
  ANTHROPIC_API_KEY: string;
  OPENAI_API_KEY: string;
  ASSEMBLYAI_API_KEY: string;
  ELEVENLABS_API_KEY: string;
  ELEVENLABS_VOICE_ID: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    // CORS headers
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    };

    if (method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // ── Chat ──────────────────────────────────────────────
      if (path === "/chat" && method === "POST") {
        return handleChat(request, env, corsHeaders);
      }

      // ── TTS ───────────────────────────────────────────────
      if (path === "/tts" && method === "POST") {
        return handleTTS(request, env, corsHeaders);
      }

      // ── Transcribe (OpenAI Whisper) ───────────────────────
      if (path === "/transcribe" && method === "POST") {
        const contentType = request.headers.get("Content-Type") || "";
        if (contentType.includes("multipart/form-data")) {
          return handleOpenAITranscribe(request, env, corsHeaders);
        } else {
          // AssemblyAI submit
          return handleAssemblyAISubmit(request, env, corsHeaders);
        }
      }

      // ── Transcribe Token (AssemblyAI upload URL) ──────────
      if (path === "/transcribe-token" && method === "POST") {
        return handleAssemblyAIToken(request, env, corsHeaders);
      }

      // ── Transcribe Poll (AssemblyAI) ──────────────────────
      const transcribeMatch = path.match(/^\/transcribe\/([^/]+)$/);
      if (transcribeMatch && method === "GET") {
        return handleAssemblyAIPoll(transcribeMatch[1], env, corsHeaders);
      }

      // ── Computer Use ──────────────────────────────────────
      if (path === "/computer-use" && method === "POST") {
        return handleComputerUse(request, env, corsHeaders);
      }

      // ── 404 ───────────────────────────────────────────────
      return new Response(JSON.stringify({ error: "Not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    } catch (err) {
      return new Response(JSON.stringify({ error: err.message }), {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }
  },
};

// ═══════════════════════════════════════════════════════════════════════════
// Chat Handler (Claude + OpenAI)
// ═══════════════════════════════════════════════════════════════════════════

async function handleChat(request: Request, env: Env, cors: Record<string, string>): Promise<Response> {
  const body = await request.json() as any;
  const model: string = body.model || "claude-sonnet-4-6";
  const stream: boolean = body.stream ?? false;

  // ── Claude (Anthropic) ──────────────────────────────────
  if (model.startsWith("claude")) {
    const payload: any = {
      model,
      max_tokens: body.max_tokens || 1024,
      messages: body.messages,
    };

    if (body.system) {
      payload.system = body.system;
    }

    if (stream) {
      // Stream via SSE
      const upstream = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": env.ANTHROPIC_API_KEY,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({ ...payload, stream: true }),
      });

      // Pass through SSE stream
      return new Response(upstream.body, {
        headers: {
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
          ...cors,
        },
      });
    } else {
      const upstream = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": env.ANTHROPIC_API_KEY,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify(payload),
      });

      const data = await upstream.json();
      return new Response(JSON.stringify(data), {
        status: upstream.status,
        headers: { "Content-Type": "application/json", ...cors },
      });
    }
  }

  // ── OpenAI ──────────────────────────────────────────────
  if (model.startsWith("gpt")) {
    // Convert Claude-style messages to OpenAI format
    const messages: any[] = [];
    if (body.system) {
      messages.push({ role: "system", content: body.system });
    }
    for (const msg of body.messages) {
      messages.push(msg);
    }

    const payload = {
      model,
      max_completion_tokens: body.max_tokens || 1024,
      messages,
    };

    const upstream = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify(payload),
    });

    const data = await upstream.json();
    return new Response(JSON.stringify(data), {
      status: upstream.status,
      headers: { "Content-Type": "application/json", ...cors },
    });
  }

  return new Response(JSON.stringify({ error: "Unknown model" }), {
    status: 400,
    headers: { "Content-Type": "application/json", ...cors },
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// TTS Handler (ElevenLabs)
// ═══════════════════════════════════════════════════════════════════════════

async function handleTTS(request: Request, env: Env, cors: Record<string, string>): Promise<Response> {
  const body = await request.json() as any;
  const text: string = body.text || "";
  const voiceId = env.ELEVENLABS_VOICE_ID || "21m00Tcm4TlvDq8ikWAM";

  const upstream = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "audio/mpeg",
        "xi-api-key": env.ELEVENLABS_API_KEY,
      },
      body: JSON.stringify({
        text,
        model_id: body.model_id || "eleven_flash_v2_5",
        voice_settings: body.voice_settings || { stability: 0.5, similarity_boost: 0.75 },
      }),
    }
  );

  return new Response(upstream.body, {
    status: upstream.status,
    headers: {
      "Content-Type": "audio/mpeg",
      ...cors,
    },
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// OpenAI Transcription (Whisper)
// ═══════════════════════════════════════════════════════════════════════════

async function handleOpenAITranscribe(request: Request, env: Env, cors: Record<string, string>): Promise<Response> {
  const formData = await request.formData();
  const audioFile = formData.get("audio") as File;

  const upstreamFormData = new FormData();
  upstreamFormData.append("file", audioFile, "audio.wav");
  upstreamFormData.append("model", "whisper-1");

  const upstream = await fetch("https://api.openai.com/v1/audio/transcriptions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
    },
    body: upstreamFormData,
  });

  const data = await upstream.json();
  return new Response(JSON.stringify(data), {
    status: upstream.status,
    headers: { "Content-Type": "application/json", ...cors },
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// AssemblyAI Handlers
// ═══════════════════════════════════════════════════════════════════════════

async function handleAssemblyAIToken(request: Request, env: Env, cors: Record<string, string>): Promise<Response> {
  const upstream = await fetch("https://api.assemblyai.com/v2/upload", {
    method: "POST",
    headers: {
      Authorization: env.ASSEMBLYAI_API_KEY,
    },
  });

  const data = await upstream.json();
  return new Response(JSON.stringify({ upload_url: data.upload_url }), {
    status: upstream.status,
    headers: { "Content-Type": "application/json", ...cors },
  });
}

async function handleAssemblyAISubmit(request: Request, env: Env, cors: Record<string, string>): Promise<Response> {
  const body = await request.json() as any;

  const upstream = await fetch("https://api.assemblyai.com/v2/transcript", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: env.ASSEMBLYAI_API_KEY,
    },
    body: JSON.stringify({
      audio_url: body.audio_url,
    }),
  });

  const data = await upstream.json();
  return new Response(JSON.stringify(data), {
    status: upstream.status,
    headers: { "Content-Type": "application/json", ...cors },
  });
}

async function handleAssemblyAIPoll(id: string, env: Env, cors: Record<string, string>): Promise<Response> {
  const upstream = await fetch(`https://api.assemblyai.com/v2/transcript/${id}`, {
    method: "GET",
    headers: {
      Authorization: env.ASSEMBLYAI_API_KEY,
    },
  });

  const data = await upstream.json();
  return new Response(JSON.stringify(data), {
    status: upstream.status,
    headers: { "Content-Type": "application/json", ...cors },
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// Computer Use Handler (Claude element detection)
// ═══════════════════════════════════════════════════════════════════════════

async function handleComputerUse(request: Request, env: Env, cors: Record<string, string>): Promise<Response> {
  const body = await request.json() as any;
  const { model, max_tokens, display_width, display_height, screenshot, question } = body;

  const userPrompt = `The user asked this question while looking at their screen: "${question}"

Look at the screenshot. If there is a specific UI element (button, link, menu item, text field, icon, etc.) that the user should interact with or is asking about, click on that element.

If the question is purely conceptual and there's no specific element to point to, just respond with text saying "no specific element".`;

  const payload = {
    model: model || "claude-sonnet-4-6",
    max_tokens: max_tokens || 256,
    tools: [
      {
        type: "computer_20251124",
        name: "computer",
        display_width_px: display_width,
        display_height_px: display_height,
      },
    ],
    messages: [
      {
        role: "user",
        content: [
          {
            type: "image",
            source: {
              type: "base64",
              media_type: screenshot.media_type,
              data: screenshot.data,
            },
          },
          {
            type: "text",
            text: userPrompt,
          },
        ],
      },
    ],
  };

  const upstream = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "anthropic-beta": "computer-use-2025-11-24",
    },
    body: JSON.stringify(payload),
  });

  const data = await upstream.json();

  // Extract coordinate from tool_use block
  let coordinate: number[] | null = null;
  let label = "element";
  if (data.content) {
    for (const block of data.content) {
      if (block.type === "tool_use" && block.input?.coordinate) {
        coordinate = block.input.coordinate;
        break;
      }
    }
  }

  return new Response(JSON.stringify({
    coordinate,
    label,
    display: 1,
  }), {
    status: upstream.status,
    headers: { "Content-Type": "application/json", ...cors },
  });
}
