# Devcom

Devcom is a private development companion with two event types:

- **Actions** call a saved HTTP endpoint from the VPS when you tap Run in the iOS app.
- **Listeners** expose a secret webhook URL. A POST to that URL becomes an Apple push notification whose title and message come from the request.

The repository contains a SwiftUI iOS app in `devcom/` and a TypeScript/Fastify backend in `backend/`.

The deployed API reference is available at `https://devcom.maximkabaev.com/docs`; agents can consume the machine-readable contract at `https://devcom.maximkabaev.com/openapi.json`.

## V1 security model

- The iOS app signs in with the single owner username/password and keeps its 30-day session in Keychain.
- Automation uses a separate, long random `AGENT_API_TOKEN`. It has owner-level event access, so only give it to trusted agents.
- Every listener has an unguessable 256-bit secret in its webhook URL. No account token is required when calling that URL.
- Saved action configuration, including headers and bodies, is AES-256-GCM encrypted on disk.
- The server binds to localhost in `compose.yaml`; put an HTTPS reverse proxy in front of it.
- Redirects are not followed when an action runs, requests time out after 15 seconds, and response previews stop at 64 KB.

Action URLs are intentionally allowed to reach private networks because calling private services is a core use case. Treat anyone holding the owner or agent credential as fully trusted, and do not expose either credential in logs or prompts.

## Backend setup

Requirements: Docker Compose, a public HTTPS hostname, and an Apple Push Notification service key (`.p8`).

1. Copy `backend/.env.example` to `backend/.env`.
2. Set all required values. Generate the secrets using the commands documented in that file, and create the password hash with the documented bcrypt command.
3. Create `backend/secrets`, copy the Apple `.p8` key to `backend/secrets/AuthKey.p8`, and set the Apple team ID, key ID, and app bundle ID. Compose mounts that directory read-only at `/run/secrets`; the example environment already points there.
4. Point `PUBLIC_URL` at the public HTTPS origin with no path, for example `https://devcom.example.com`.
5. Have your reverse proxy forward that hostname to `127.0.0.1:8080`, preserving the request body and `X-Devcom-*` headers.
6. Start the Compose project yourself with `docker compose up -d --build`.

A minimal Caddy site block is:

```caddyfile
devcom.example.com {
    reverse_proxy 127.0.0.1:8080
}
```

The persistent Docker volume contains one encrypted data file. Back up both that volume and `CONFIG_ENCRYPTION_KEY`; the data cannot be read without the same key.

## iOS setup

1. Open `devcom/devcom.xcodeproj`.
2. Select the `devcom` target, choose your Apple Developer team, and confirm the bundle identifier matches `APNS_BUNDLE_ID`.
3. Under Signing & Capabilities, add **Push Notifications**. The entitlement file is already connected to both build configurations.
4. Build onto a physical iPhone. APNs device registration is not available in every simulator configuration.
5. Sign in with the HTTPS backend URL and the configured owner credentials. Notification permission is requested after the first successful sign-in.

Debug builds register their device token with the APNs sandbox; Release builds use production APNs.

## Agent quickstart

All management calls use the same header:

```http
Authorization: Bearer YOUR_AGENT_API_TOKEN
Content-Type: application/json
```

Create an action:

```http
POST /v1/actions

{
  "name": "Restart API",
  "method": "POST",
  "url": "http://api.internal:9000/admin/restart",
  "headers": {
    "Authorization": "Bearer SERVICE_TOKEN",
    "Content-Type": "application/json"
  },
  "body": "{\"reason\":\"manual\"}"
}
```

The returned `id` can be invoked with `POST /v1/actions/{id}/run`.

Create a listener:

```http
POST /v1/listeners

{
  "name": "Deploy finished"
}
```

The response includes `webhookURL`. Save it in the source service and call it without an Authorization header:

```http
POST /v1/hooks/{id}/{secret}
Content-Type: application/json

{
  "title": "Deploy complete",
  "message": "api.example.com is live"
}
```

Alternatively, send any plain-text body and set `X-Devcom-Title`; or set both `X-Devcom-Title` and `X-Devcom-Message`. Titles are limited to 120 characters and messages to 700 characters; the backend also bounds the encoded APNs payload to 4 KB.

## API summary

| Method | Path | Authentication | Purpose |
| --- | --- | --- | --- |
| `GET` | `/health` | None | Reverse-proxy health check |
| `POST` | `/v1/auth/login` | Username/password body | Create an app session |
| `GET` | `/v1/events` | Owner or agent bearer token | List both event types |
| `POST` | `/v1/actions` | Owner or agent bearer token | Create an action |
| `POST` | `/v1/actions/:id/run` | Owner or agent bearer token | Run an action |
| `DELETE` | `/v1/actions/:id` | Owner or agent bearer token | Delete an action |
| `POST` | `/v1/listeners` | Owner or agent bearer token | Create a listener |
| `DELETE` | `/v1/listeners/:id` | Owner or agent bearer token | Delete a listener |
| `POST` | `/v1/devices` | Owner or agent bearer token | Register an APNs device |
| `POST` | `/v1/hooks/:id/:secret` | Secret URL | Send a push notification |

## Local backend development

After creating `backend/.env`, install dependencies with `npm install` and use `npm run dev`. Production builds use `npm run build` and `npm start`.
