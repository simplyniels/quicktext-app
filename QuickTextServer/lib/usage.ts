import type { SupabaseClient } from "@supabase/supabase-js";
import { ApiError } from "./http";
import type { RequestIdentity } from "./auth";

export async function enforceRequestLimit(
  admin: SupabaseClient,
  identity: RequestIdentity,
) {
  const since = new Date(Date.now() - 60_000).toISOString();
  const { count, error } = await admin
    .from("usage_events")
    .select("id", { count: "exact", head: true })
    .eq("family_id", identity.familyId)
    .gte("created_at", since);
  if (error) {
    throw new ApiError(503, "Nutzungslimit konnte nicht geprüft werden");
  }
  if ((count ?? 0) >= 20) {
    throw new ApiError(429, "Zu viele Anfragen. Bitte kurz warten.");
  }
}

export async function recordUsage(
  admin: SupabaseClient,
  identity: RequestIdentity,
  event: {
    requestType: "transcription" | "rewrite";
    model: string;
    inputBytes?: number;
    inputCharacters?: number;
    status: "succeeded" | "failed";
  },
) {
  const { error } = await admin.from("usage_events").insert({
    family_id: identity.familyId,
    user_id: identity.userId,
    device_id: identity.deviceId,
    request_type: event.requestType,
    model: event.model,
    input_bytes: event.inputBytes ?? 0,
    input_characters: event.inputCharacters ?? 0,
    status: event.status,
  });
  if (error) {
    console.error("Usage event could not be recorded", { code: error.code });
  }
}
