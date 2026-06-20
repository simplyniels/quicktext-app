import { NextRequest, NextResponse } from "next/server";
import { requireIdentity } from "@/lib/auth";
import { ApiError, errorResponse } from "@/lib/http";
import { serverEnv } from "@/lib/env";
import { createAdminClient } from "@/lib/supabase";
import { enforceRequestLimit, recordUsage } from "@/lib/usage";

const allowedTypes = new Set([
  "audio/m4a",
  "audio/mp4",
  "audio/mpeg",
  "audio/wav",
  "audio/webm",
  "audio/x-m4a",
]);

export async function POST(request: NextRequest) {
  let identity;
  let audioBytes = 0;
  const admin = createAdminClient();
  try {
    identity = await requireIdentity(request);
    await enforceRequestLimit(admin, identity);
    const form = await request.formData();
    const audio = form.get("audio");
    const language = form.get("language");
    if (!(audio instanceof File) || !allowedTypes.has(audio.type)) {
      throw new ApiError(400, "Unterstützte Audiodatei fehlt");
    }
    audioBytes = audio.size;
    if (audio.size === 0 || audio.size > 4_000_000) {
      throw new ApiError(413, "Audiodatei ist leer oder zu groß");
    }

    const openAiForm = new FormData();
    openAiForm.set("file", audio, audio.name || "recording.m4a");
    openAiForm.set("model", "whisper-1");
    if (typeof language === "string" && /^[a-z]{2}$/.test(language)) {
      openAiForm.set("language", language);
    }
    const response = await fetch("https://api.openai.com/v1/audio/transcriptions", {
      method: "POST",
      headers: { authorization: `Bearer ${serverEnv().openAiApiKey}` },
      body: openAiForm,
    });
    if (!response.ok) {
      throw new ApiError(502, "Audio konnte nicht transkribiert werden");
    }
    const result = (await response.json()) as { text?: string };
    if (!result.text?.trim()) {
      throw new ApiError(502, "Leere Transkription");
    }
    await recordUsage(admin, identity, {
      requestType: "transcription",
      model: "whisper-1",
      inputBytes: audioBytes,
      status: "succeeded",
    });
    return NextResponse.json({ text: result.text.trim() });
  } catch (error) {
    if (identity) {
      await recordUsage(admin, identity, {
        requestType: "transcription",
        model: "whisper-1",
        inputBytes: audioBytes,
        status: "failed",
      });
    }
    return errorResponse(error);
  }
}
