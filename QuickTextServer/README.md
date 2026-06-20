# Quick Text Family Server

Private Vercel backend for sharing one OpenAI project across registered Quick
Text family devices without distributing the OpenAI API key.

## Authentication Decision

Users sign in through Supabase Auth with their email address and an exactly
eight-digit numeric PIN. Supabase hashes the PIN; the Quick Text database does
not store a second copy.

An eight-digit PIN is less secure than a generated password. This deployment
therefore requires:

- Supabase Auth rate limits
- verified/owner-created accounts only; public signup disabled
- registered and individually revocable devices
- API request and spending limits
- short access-token lifetimes

## Setup

1. Create a Supabase project.
2. Run `supabase/migrations/20260607193000_initial_family_server.sql` in its SQL
   editor.
3. Disable public user signup in Supabase Auth.
4. Configure email/password auth with minimum length 8 and no mixed-character
   requirement, because PINs are numeric.
5. Configure strict Auth rate limits and production SMTP.
6. Add the variables from `.env.example` to Vercel.
7. Deploy `QuickTextServer/` as the Vercel project root.
8. Call `POST /api/v1/setup` once with the setup secret to create the owner.

Example owner setup body:

```json
{
  "email": "owner@example.com",
  "pin": "12345678",
  "familyName": "Meine Familie"
}
```

Delete or rotate `QUICKTEXT_SETUP_SECRET` after initial setup.

## Client Login Flow

1. Sign in through Supabase Auth using email and PIN.
2. Send the resulting access token to `POST /api/v1/devices/register`.
3. Store the returned device ID and Supabase refresh token in the platform
   credential store.
4. Send `Authorization: Bearer <access-token>` and
   `X-QuickText-Device-ID: <device-id>` with every server API request.

Audio and transcript content is forwarded to OpenAI and never stored in the
Quick Text database.
