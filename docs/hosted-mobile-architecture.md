# Hosted Family Server And Mobile Plan

## Goal

Run Quick Text on multiple family devices without distributing the OpenAI API
key. Every client authenticates to a shared backend. Only the backend can read
the OpenAI key and call OpenAI.

The existing direct-key mode should remain available as an explicit fallback.
Local transcription should continue to bypass the hosted backend entirely.

## Important Finding

A simple Vercel proxy works for short, compressed push-to-talk recordings, but
Vercel Functions currently limit request and response bodies to 4.5 MB. OpenAI
accepts audio uploads up to 25 MB.

Recommended approach:

- Short recordings below a strict client-side limit: upload directly to the
  Vercel API.
- Longer recordings: upload directly to private temporary object storage using
  a short-lived signed upload URL, then let the backend forward the audio to
  OpenAI and immediately delete the object.
- Alternatively, host the audio proxy on a service without Vercel's request
  body limit, while keeping the admin UI and auth layer on Vercel.

## Recommended Architecture

```text
macOS / Windows / Flutter app / native keyboard extensions
                    |
                    | Supabase Auth JWT
                    v
          Vercel Next.js API and admin UI
                    |
          +---------+----------+
          |                    |
          v                    v
 Supabase Postgres       OpenAI API key
 family/device/usage     stored only as a
 records with RLS        sensitive Vercel env var
          |
          v
 private temporary audio storage
 deleted immediately after processing
```

### Why Supabase Auth

Supabase Auth supports password, magic-link, OTP, social login, and JWTs. It
also integrates with Postgres Row Level Security. For a family deployment,
magic-link sign-in plus an owner-managed family membership is simpler and safer
than sharing one permanent app password.

### Why Not Only A Shared App Password

A single shared password cannot identify devices or family members. If it leaks,
the only recovery is changing it on every device. It also makes per-device
revocation, usage limits, and abuse investigation difficult.

For a very small first MVP, a shared app password is acceptable only if the
server exchanges it once for a revocable per-device token. Store only a strong
password hash on the server, never the plaintext password.

## Backend Components

Create a new `QuickTextServer/` Next.js project deployed to Vercel.

### Required API Endpoints

| Endpoint | Purpose |
|---|---|
| `GET /api/v1/config` | Returns supported workflows, models, and limits |
| `POST /api/v1/transcriptions` | Accepts short compressed audio and returns text |
| `POST /api/v1/uploads` | Creates a signed private upload URL for larger audio |
| `POST /api/v1/transcriptions/from-upload` | Processes and deletes uploaded audio |
| `POST /api/v1/rewrite` | Runs improve, calmer-message, or emoji workflow |
| `POST /api/v1/devices/register` | Registers a named device |
| `DELETE /api/v1/devices/:id` | Revokes a device |
| `GET /api/v1/usage` | Returns family/device usage totals without content |

### Required Database Tables

- `families`: owner and family-level limits
- `family_members`: membership and role
- `devices`: device name, platform, last seen, revoked timestamp
- `usage_events`: request type, model, byte count, token count, estimated cost,
  status, and timestamps
- `server_settings`: allowed models and maximum recording duration

Do not store audio, transcripts, prompts, or generated output in usage tables.
Enable RLS on every exposed Supabase table.

### Required Vercel Secrets

- `OPENAI_API_KEY`: sensitive, production only
- `SUPABASE_SERVICE_ROLE_KEY`: sensitive, server only
- `NEXT_PUBLIC_SUPABASE_URL`: public
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`: public
- Optional signed-upload/storage credentials

Never expose `OPENAI_API_KEY` or `SUPABASE_SERVICE_ROLE_KEY` to a client or a
`NEXT_PUBLIC_` variable.

### Security Requirements

- Verify the user's JWT on every endpoint.
- Verify active family membership and non-revoked device status.
- Restrict accepted workflows and models server-side; clients must not select an
  arbitrary OpenAI model.
- Enforce maximum audio bytes, duration, text length, requests per minute,
  daily family budget, and monthly family budget.
- Reject unexpected MIME types and malformed multipart payloads.
- Do not log authorization headers, audio, transcript text, prompt text, or
  generated output.
- Delete temporary audio in a `finally` block.
- Return generic client errors while keeping content-free operational logs.
- Add owner controls for device revocation and an emergency server-disable
  switch.
- Configure OpenAI project budgets and alerts as a second line of defense.

## Desktop App Changes

Add a remote provider boundary shared conceptually across macOS and Windows:

```text
RemoteProvider
  transcribe(audio, language, terms)
  rewrite(text, workflow, settings)

DirectOpenAIProvider
HostedQuickTextProvider
```

Settings should support:

- Connection mode: hosted family server, direct OpenAI key, or local
- Server URL
- Sign in / sign out
- Device name
- Connection test
- Usage and family budget status
- Server certificate/TLS errors shown clearly

The hosted client sends a user JWT, not the OpenAI key. Secrets and refresh
tokens remain in macOS Keychain or Windows Credential Manager.

## Mobile Platform Decision

Use Flutter for the shared mobile containing app, and native code only where
the operating systems require it.

This gives one shared implementation for onboarding, Supabase sign-in, server
settings, push-to-talk recording, workflow selection, snippets, usage display,
and result copy/share. Fully native Android and iOS apps would give the most
platform control, but they would double most product work before the core
server workflow has proven itself.

Native code is still required for the system-wide input layer:

- Android: native Kotlin `InputMethodService`
- iOS: native Swift/UIKit Custom Keyboard Extension

The recommended mobile stack is therefore hybrid: Flutter app shell first,
native keyboard/IME integrations second.

## Flutter Mobile App

Yes, a shared Flutter app can provide:

- onboarding and family sign-in
- server connection and device registration
- push-to-talk recording
- the four Quick Text workflows
- custom terms, prompts, snippets, and settings synchronized through the server
- copy/share result
- usage and budget display

Recommended layout:

```text
QuickTextMobile/
  lib/
    core/api/
    core/auth/
    features/recording/
    features/workflows/
    features/settings/
    features/snippets/
  android/   native Android IME integration
  ios/       containing app plus native keyboard extension
```

### Android System-Wide Input

Android supports a system-wide Input Method Editor through
`InputMethodService`. Build the keyboard/voice input surface natively in Kotlin
and communicate with the Flutter containing app and shared backend client.

This can provide a Wispr-Flow-like experience in most text fields after the user
explicitly enables Quick Text as an input method.

### iOS System-Wide Input

iOS requires a native Custom Keyboard Extension. Flutter can power the
containing settings/workflow app, but the keyboard extension itself should be
Swift/UIKit.

Important iOS constraints:

- Users must explicitly enable the custom keyboard.
- Network access requires the keyboard's open-access permission.
- Some apps can reject custom keyboards.
- Custom keyboards are unavailable in secure and phone-pad fields.
- Apple documents significant extension sandbox and memory restrictions.
- A voice-recording design inside the keyboard extension needs an early
  on-device proof of concept and App Store policy review. If microphone capture
  is blocked or unreliable in the extension, use the containing app plus
  clipboard/share-sheet insertion as the fallback.

Do not promise identical system-wide behavior across iOS, Android, macOS, and
Windows until the iOS keyboard proof of concept has passed on a physical device.

## Suggested Delivery Order

### Phase 1: Family Server MVP

- Vercel Next.js API
- Supabase Auth, database, and RLS
- short compressed audio endpoint
- rewrite endpoint
- usage limits and content-free logs
- hosted mode in macOS and Windows apps

### Phase 2: Robust Audio And Admin

- private signed audio uploads for larger files
- owner admin page
- device revocation
- per-member and per-device usage
- daily/monthly budget limits
- key rotation and emergency disable

### Phase 3: Flutter Mobile App

- Flutter containing app for iOS and Android
- sign-in, recording, workflows, settings, copy/share
- synchronized custom terms and snippets

### Phase 4: System-Wide Mobile Input

- Android native IME
- iOS native keyboard-extension proof of concept
- platform-specific onboarding and permission flows
- physical-device and store-policy validation

## Definition Of Done

- The OpenAI key never appears in any client binary, settings file, log, or
  network response.
- A revoked device immediately loses access.
- Family owners can see and cap usage without seeing transcript content.
- Audio is deleted after processing.
- Direct-key and local modes continue to work.
- macOS, Windows, Android, and iOS share the same workflow contract.
- Android system-wide input works through an enabled IME.
- iOS behavior is documented accurately based on a physical-device keyboard
  extension test.

## Supabase Database Decision

Yes, the Supabase database is required for hosted mode. Supabase Auth alone can
prove who signed in, but it does not model the Quick Text product state:

- which family a user belongs to
- which devices are registered or revoked
- who is owner vs member
- request limits and spending caps
- usage totals without storing transcript content
- emergency disable and later admin controls

The first server implementation keeps all product tables private to the Vercel
backend. Clients authenticate with Supabase Auth, then call the Quick Text
server. The server uses the Supabase service role key only on the backend and
checks membership, device status, and limits before calling OpenAI.
