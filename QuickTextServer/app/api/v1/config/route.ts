import { NextRequest, NextResponse } from "next/server";
import { requireIdentity } from "@/lib/auth";
import { errorResponse } from "@/lib/http";

export async function GET(request: NextRequest) {
  try {
    await requireIdentity(request);
    return NextResponse.json({
      workflows: ["transcribe", "improve", "calm", "emoji"],
      limits: {
        maxDirectAudioBytes: 4_000_000,
        maxRewriteCharacters: 12_000,
        requestsPerMinutePerFamily: 20,
      },
    });
  } catch (error) {
    return errorResponse(error);
  }
}
