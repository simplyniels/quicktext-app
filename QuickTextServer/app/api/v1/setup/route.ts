import { NextRequest, NextResponse } from "next/server";
import { ApiError, assertJsonObject, errorResponse } from "@/lib/http";
import { serverEnv } from "@/lib/env";
import { createAdminClient } from "@/lib/supabase";

export async function POST(request: NextRequest) {
  try {
    if (request.headers.get("authorization") !== `Bearer ${serverEnv().setupSecret}`) {
      throw new ApiError(401, "Setup-Schlüssel ungültig");
    }

    const body: unknown = await request.json();
    assertJsonObject(body);
    const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
    const pin = typeof body.pin === "string" ? body.pin : "";
    const familyName = typeof body.familyName === "string" ? body.familyName.trim() : "";
    if (!email.includes("@") || !/^\d{8}$/.test(pin) || familyName.length < 2) {
      throw new ApiError(400, "E-Mail, Familienname oder achtstelliger PIN ungültig");
    }

    const admin = createAdminClient();
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      password: pin,
      email_confirm: true,
    });
    if (createError || !created.user) {
      throw new ApiError(409, "Benutzer konnte nicht angelegt werden");
    }

    const { data: family, error: familyError } = await admin
      .from("families")
      .insert({ name: familyName, owner_user_id: created.user.id })
      .select("id")
      .single();
    if (familyError || !family) {
      await admin.auth.admin.deleteUser(created.user.id);
      throw new ApiError(500, "Familie konnte nicht angelegt werden");
    }

    const { error: membershipError } = await admin.from("family_members").insert({
      family_id: family.id,
      user_id: created.user.id,
      role: "owner",
    });
    if (membershipError) {
      throw new ApiError(500, "Mitgliedschaft konnte nicht angelegt werden");
    }

    return NextResponse.json(
      { familyId: family.id, userId: created.user.id },
      { status: 201 },
    );
  } catch (error) {
    return errorResponse(error);
  }
}
