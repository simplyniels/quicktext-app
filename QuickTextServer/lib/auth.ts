import { NextRequest } from "next/server";
import { ApiError } from "./http";
import { createAdminClient } from "./supabase";

export type RequestIdentity = {
  userId: string;
  familyId: string;
  deviceId: string;
};

export async function requireIdentity(
  request: NextRequest,
): Promise<RequestIdentity> {
  const authorization = request.headers.get("authorization");
  const deviceId = request.headers.get("x-quicktext-device-id");
  if (!authorization?.startsWith("Bearer ") || !deviceId) {
    throw new ApiError(401, "Anmeldung oder Geräte-ID fehlt");
  }

  const admin = createAdminClient();
  const token = authorization.slice("Bearer ".length);
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) {
    throw new ApiError(401, "Anmeldung ungültig");
  }

  const { data: membership, error: membershipError } = await admin
    .from("family_members")
    .select("family_id")
    .eq("user_id", data.user.id)
    .maybeSingle();
  if (membershipError || !membership) {
    throw new ApiError(403, "Keine aktive Familienmitgliedschaft");
  }

  const { data: device, error: deviceError } = await admin
    .from("devices")
    .select("id")
    .eq("id", deviceId)
    .eq("family_id", membership.family_id)
    .eq("user_id", data.user.id)
    .is("revoked_at", null)
    .maybeSingle();
  if (deviceError || !device) {
    throw new ApiError(403, "Gerät ist nicht registriert oder wurde gesperrt");
  }

  await admin
    .from("devices")
    .update({ last_seen_at: new Date().toISOString() })
    .eq("id", deviceId);

  return {
    userId: data.user.id,
    familyId: membership.family_id,
    deviceId,
  };
}
