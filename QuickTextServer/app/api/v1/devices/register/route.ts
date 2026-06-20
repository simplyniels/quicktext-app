import { NextRequest, NextResponse } from "next/server";
import { ApiError, assertJsonObject, errorResponse } from "@/lib/http";
import { createAdminClient } from "@/lib/supabase";

export async function POST(request: NextRequest) {
  try {
    const authorization = request.headers.get("authorization");
    if (!authorization?.startsWith("Bearer ")) {
      throw new ApiError(401, "Anmeldung fehlt");
    }
    const admin = createAdminClient();
    const { data, error } = await admin.auth.getUser(
      authorization.slice("Bearer ".length),
    );
    if (error || !data.user) {
      throw new ApiError(401, "Anmeldung ungültig");
    }

    const { data: membership } = await admin
      .from("family_members")
      .select("family_id")
      .eq("user_id", data.user.id)
      .maybeSingle();
    if (!membership) {
      throw new ApiError(403, "Keine Familienmitgliedschaft");
    }

    const body: unknown = await request.json();
    assertJsonObject(body);
    const name = typeof body.name === "string" ? body.name.trim() : "";
    const platform = typeof body.platform === "string" ? body.platform : "";
    if (name.length < 2 || !["macos", "windows", "android", "ios"].includes(platform)) {
      throw new ApiError(400, "Gerätename oder Plattform ungültig");
    }

    const { data: device, error: deviceError } = await admin
      .from("devices")
      .insert({
        family_id: membership.family_id,
        user_id: data.user.id,
        name,
        platform,
      })
      .select("id")
      .single();
    if (deviceError || !device) {
      throw new ApiError(500, "Gerät konnte nicht registriert werden");
    }
    return NextResponse.json({ deviceId: device.id }, { status: 201 });
  } catch (error) {
    return errorResponse(error);
  }
}
