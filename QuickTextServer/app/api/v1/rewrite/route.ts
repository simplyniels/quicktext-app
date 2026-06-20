import { NextRequest, NextResponse } from "next/server";
import { requireIdentity } from "@/lib/auth";
import { ApiError, assertJsonObject, errorResponse } from "@/lib/http";
import { serverEnv } from "@/lib/env";
import { createAdminClient } from "@/lib/supabase";
import { enforceRequestLimit, recordUsage } from "@/lib/usage";
import { requireWorkflow, workflows } from "@/lib/workflows";

export async function POST(request: NextRequest) {
  let identity;
  let textLength = 0;
  let model = "gpt-4o-mini";
  const admin = createAdminClient();
  try {
    identity = await requireIdentity(request);
    await enforceRequestLimit(admin, identity);
    const body: unknown = await request.json();
    assertJsonObject(body);
    const text = typeof body.text === "string" ? body.text.trim() : "";
    const workflow = requireWorkflow(body.workflow);
    textLength = text.length;
    if (!text || text.length > 12_000) {
      throw new ApiError(400, "Text fehlt oder ist zu lang");
    }
    model = workflow === "calm" ? "gpt-4o" : "gpt-4o-mini";

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        authorization: `Bearer ${serverEnv().openAiApiKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: workflows[workflow] },
          { role: "user", content: text },
        ],
      }),
    });
    if (!response.ok) {
      throw new ApiError(502, "Text konnte nicht verarbeitet werden");
    }
    const result = (await response.json()) as {
      choices?: Array<{ message?: { content?: string } }>;
    };
    const output = result.choices?.[0]?.message?.content?.trim();
    if (!output) {
      throw new ApiError(502, "Leere Antwort vom Sprachmodell");
    }
    await recordUsage(admin, identity, {
      requestType: "rewrite",
      model,
      inputCharacters: textLength,
      status: "succeeded",
    });
    return NextResponse.json({ text: output });
  } catch (error) {
    if (identity) {
      await recordUsage(admin, identity, {
        requestType: "rewrite",
        model,
        inputCharacters: textLength,
        status: "failed",
      });
    }
    return errorResponse(error);
  }
}
