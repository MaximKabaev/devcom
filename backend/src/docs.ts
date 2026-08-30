export const openApiDocument = {
  openapi: "3.1.0",
  info: {
    title: "Devcom API",
    version: "0.1.0",
    description: "Create and run outbound action events, or create listeners that deliver inbound APNs notifications."
  },
  servers: [{ url: "https://devcom.maximkabaev.com" }],
  tags: [
    { name: "System" },
    { name: "Authentication" },
    { name: "Events" },
    { name: "Actions" },
    { name: "Listeners" },
    { name: "Devices" }
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: "http",
        scheme: "bearer",
        description: "Use either an owner session JWT or the AGENT_API_TOKEN."
      }
    },
    schemas: {
      Error: {
        type: "object",
        required: ["error"],
        properties: { error: { type: "string" } }
      },
      ActionInput: {
        type: "object",
        required: ["name", "method", "url"],
        properties: {
          name: { type: "string", maxLength: 80 },
          method: { type: "string", enum: ["GET", "POST", "PUT", "PATCH", "DELETE"] },
          url: { type: "string", format: "uri", pattern: "^https?://" },
          headers: { type: "object", additionalProperties: { type: "string" }, default: {} },
          body: { type: ["string", "null"], maxLength: 200000, default: null }
        }
      },
      ListenerInput: {
        type: "object",
        required: ["name"],
        properties: { name: { type: "string", maxLength: 80 } }
      },
      DeviceInput: {
        type: "object",
        required: ["token", "environment"],
        properties: {
          token: { type: "string", pattern: "^[a-fA-F0-9]{64,}$" },
          environment: { type: "string", enum: ["sandbox", "production"] }
        }
      },
      WebhookInput: {
        type: "object",
        properties: {
          title: { type: "string", maxLength: 120 },
          message: { type: "string", maxLength: 700 },
          body: { type: "string", maxLength: 700, description: "Alias for message." }
        }
      }
    }
  },
  paths: {
    "/health": {
      get: {
        tags: ["System"],
        summary: "Check service health",
        responses: { "200": { description: "Service is available." } }
      }
    },
    "/v1/auth/login": {
      post: {
        tags: ["Authentication"],
        summary: "Create an owner session",
        requestBody: {
          required: true,
          content: { "application/json": { schema: { type: "object", required: ["username", "password"], properties: { username: { type: "string" }, password: { type: "string" } } } } }
        },
        responses: {
          "200": { description: "A 30-day bearer token." },
          "401": { description: "Credentials were rejected." }
        }
      }
    },
    "/v1/events": {
      get: {
        tags: ["Events"],
        summary: "List actions and listeners",
        security: [{ bearerAuth: [] }],
        responses: { "200": { description: "Both event collections." }, "401": { description: "Bearer token required." } }
      }
    },
    "/v1/actions": {
      post: {
        tags: ["Actions"],
        summary: "Create an outbound action",
        security: [{ bearerAuth: [] }],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/ActionInput" } } } },
        responses: { "201": { description: "The saved action." }, "400": { description: "Invalid action configuration." } }
      }
    },
    "/v1/actions/{id}/run": {
      post: {
        tags: ["Actions"],
        summary: "Run a saved action",
        security: [{ bearerAuth: [] }],
        parameters: [{ name: "id", in: "path", required: true, schema: { type: "string", format: "uuid" } }],
        responses: { "200": { description: "Upstream status, duration, and a response preview." }, "502": { description: "The upstream request failed." } }
      }
    },
    "/v1/actions/{id}": {
      delete: {
        tags: ["Actions"],
        summary: "Delete an action",
        security: [{ bearerAuth: [] }],
        parameters: [{ name: "id", in: "path", required: true, schema: { type: "string", format: "uuid" } }],
        responses: { "204": { description: "Deleted." }, "404": { description: "Action not found." } }
      }
    },
    "/v1/listeners": {
      post: {
        tags: ["Listeners"],
        summary: "Create an inbound listener",
        security: [{ bearerAuth: [] }],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/ListenerInput" } } } },
        responses: { "201": { description: "The listener and its secret webhookURL." } }
      }
    },
    "/v1/listeners/{id}": {
      delete: {
        tags: ["Listeners"],
        summary: "Delete a listener",
        security: [{ bearerAuth: [] }],
        parameters: [{ name: "id", in: "path", required: true, schema: { type: "string", format: "uuid" } }],
        responses: { "204": { description: "Deleted." }, "404": { description: "Listener not found." } }
      }
    },
    "/v1/devices": {
      post: {
        tags: ["Devices"],
        summary: "Register an APNs device token",
        security: [{ bearerAuth: [] }],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/DeviceInput" } } } },
        responses: { "204": { description: "Device registered." } }
      }
    },
    "/v1/devices/{token}": {
      delete: {
        tags: ["Devices"],
        summary: "Remove an APNs device token",
        security: [{ bearerAuth: [] }],
        parameters: [{ name: "token", in: "path", required: true, schema: { type: "string" } }],
        responses: { "204": { description: "Device removed." } }
      }
    },
    "/v1/hooks/{id}/{secret}": {
      get: {
        tags: ["Listeners"],
        summary: "Inspect listener webhook usage",
        description: "Opening a valid webhook URL returns POST instructions without sending a notification.",
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "string", format: "uuid" } },
          { name: "secret", in: "path", required: true, schema: { type: "string" } }
        ],
        responses: { "200": { description: "Listener name and accepted POST formats." }, "404": { description: "Webhook URL is not valid." } }
      },
      post: {
        tags: ["Listeners"],
        summary: "Deliver a push notification through a listener",
        description: "The URL secret is the credential. JSON, plain text, X-Devcom-Title, and X-Devcom-Message are accepted.",
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "string", format: "uuid" } },
          { name: "secret", in: "path", required: true, schema: { type: "string" } },
          { name: "X-Devcom-Title", in: "header", required: false, schema: { type: "string", maxLength: 120 } },
          { name: "X-Devcom-Message", in: "header", required: false, schema: { type: "string", maxLength: 700 } }
        ],
        requestBody: { content: { "application/json": { schema: { $ref: "#/components/schemas/WebhookInput" } }, "text/plain": { schema: { type: "string" } } } },
        responses: { "202": { description: "Notification accepted; includes delivered, failed, and devices counts." }, "404": { description: "Webhook URL is not valid." } }
      }
    }
  }
} as const;

export const docsHTML = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="Complete Devcom HTTP API reference for humans and agents.">
  <link rel="alternate" type="application/json" href="/openapi.json" title="Devcom OpenAPI">
  <title>Devcom · API contract</title>
  <style>
    :root { color-scheme: light dark; --paper:#f4f6f8; --surface:#fff; --ink:#111820; --muted:#64717d; --line:#d9e0e6; --blue:#1f6feb; --amber:#b86509; --code:#151a20; }
    * { box-sizing:border-box; }
    html { scroll-behavior:smooth; }
    body { margin:0; background:var(--paper); color:var(--ink); font:16px/1.6 ui-sans-serif,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; }
    a { color:var(--blue); text-underline-offset:3px; }
    code,pre,.method,.eyebrow { font-family:ui-monospace,SFMono-Regular,Menlo,monospace; }
    .shell { width:min(1120px,calc(100% - 32px)); margin:auto; }
    header { padding:72px 0 56px; border-bottom:1px solid var(--line); }
    .eyebrow { color:var(--muted); font-size:12px; letter-spacing:.16em; font-weight:700; }
    h1 { margin:14px 0 16px; max-width:780px; font-size:clamp(44px,8vw,88px); line-height:.92; letter-spacing:-.055em; }
    .lede { max-width:650px; color:var(--muted); font-size:19px; }
    .signal { display:grid; grid-template-columns:1fr 1fr; gap:8px; width:152px; margin-bottom:40px; }
    .signal span { height:8px; border-radius:8px; transform:skewX(-24deg); }
    .signal .out { background:var(--blue); }
    .signal .in { background:var(--amber); }
    .links { display:flex; flex-wrap:wrap; gap:10px; margin-top:26px; }
    .links a { padding:9px 13px; border:1px solid var(--line); border-radius:10px; background:var(--surface); text-decoration:none; font-weight:650; }
    main { display:grid; grid-template-columns:220px minmax(0,1fr); gap:48px; padding:48px 0 88px; }
    nav { position:sticky; top:24px; align-self:start; display:grid; gap:6px; }
    nav a { color:var(--muted); text-decoration:none; padding:5px 0; }
    nav a:hover,nav a:focus-visible { color:var(--ink); }
    section { margin-bottom:64px; scroll-margin-top:24px; }
    h2 { font-size:30px; letter-spacing:-.025em; margin:0 0 18px; }
    h3 { margin:32px 0 10px; font-size:20px; }
    .note { border-left:4px solid var(--amber); background:color-mix(in srgb,var(--amber) 8%,var(--surface)); padding:14px 16px; border-radius:0 10px 10px 0; }
    table { width:100%; border-collapse:collapse; background:var(--surface); border:1px solid var(--line); }
    th,td { text-align:left; padding:13px 14px; border-bottom:1px solid var(--line); vertical-align:top; }
    th { color:var(--muted); font-size:12px; letter-spacing:.08em; text-transform:uppercase; }
    .method { font-size:12px; font-weight:800; color:var(--blue); }
    article { min-width:0; }
    pre { max-width:100%; overflow:auto; margin:12px 0 24px; padding:18px; background:var(--code); color:#eef3f7; border-radius:12px; font-size:13px; line-height:1.55; }
    p code,li code,td code { background:color-mix(in srgb,var(--muted) 12%,transparent); padding:.12em .35em; border-radius:5px; font-size:.9em; }
    footer { padding:24px 0 40px; border-top:1px solid var(--line); color:var(--muted); font-size:13px; }
    @media (prefers-color-scheme:dark) { :root { --paper:#101316; --surface:#191d21; --ink:#f2f5f7; --muted:#9ba6af; --line:#30373e; --blue:#58a6ff; --amber:#e5a84b; } }
    @media (max-width:760px) { header{padding:48px 0 38px} main{grid-template-columns:minmax(0,1fr);gap:24px} nav{position:static;grid-template-columns:repeat(2,minmax(0,1fr));padding-bottom:24px;border-bottom:1px solid var(--line)} table{display:block;max-width:100%;overflow-x:auto} }
  </style>
</head>
<body>
  <header><div class="shell">
    <div class="signal" aria-hidden="true"><span class="out"></span><span class="in"></span></div>
    <div class="eyebrow">DEVCOM / HTTP CONTRACT / V1</div>
    <h1>Send commands.<br>Receive signals.</h1>
    <p class="lede">The complete public contract for wiring services and agents into Devcom. Use actions for outbound HTTP calls and listeners for inbound push notifications.</p>
    <div class="links"><a href="/openapi.json">OpenAPI JSON</a><a href="/health">Service health</a></div>
  </div></header>
  <main class="shell">
    <nav aria-label="Documentation"><a href="#auth">Authentication</a><a href="#map">Endpoint map</a><a href="#actions">Actions</a><a href="#listeners">Listeners</a><a href="#devices">Devices</a><a href="#limits">Limits</a></nav>
    <article>
      <section id="auth"><h2>Authentication</h2>
        <p>Management endpoints accept either the long-lived agent token or an owner session JWT:</p>
        <pre>Authorization: Bearer YOUR_AGENT_API_TOKEN
Content-Type: application/json</pre>
        <p>Agents should use <code>AGENT_API_TOKEN</code>. The iOS app obtains a 30-day owner token from <code>POST /v1/auth/login</code>.</p>
        <p class="note">Treat the agent token and each listener webhook URL as credentials. Do not place either value in public logs, issues, or documentation.</p>
      </section>
      <section id="map"><h2>Endpoint map</h2>
        <table><thead><tr><th>Method</th><th>Path</th><th>Auth</th><th>Purpose</th></tr></thead><tbody>
          <tr><td class="method">GET</td><td><code>/health</code></td><td>Public</td><td>Service health</td></tr>
          <tr><td class="method">POST</td><td><code>/v1/auth/login</code></td><td>Credentials</td><td>Create owner session</td></tr>
          <tr><td class="method">GET</td><td><code>/v1/events</code></td><td>Bearer</td><td>List actions and listeners</td></tr>
          <tr><td class="method">POST</td><td><code>/v1/actions</code></td><td>Bearer</td><td>Create an action</td></tr>
          <tr><td class="method">POST</td><td><code>/v1/actions/:id/run</code></td><td>Bearer</td><td>Run an action</td></tr>
          <tr><td class="method">DELETE</td><td><code>/v1/actions/:id</code></td><td>Bearer</td><td>Delete an action</td></tr>
          <tr><td class="method">POST</td><td><code>/v1/listeners</code></td><td>Bearer</td><td>Create a listener</td></tr>
          <tr><td class="method">DELETE</td><td><code>/v1/listeners/:id</code></td><td>Bearer</td><td>Delete a listener</td></tr>
          <tr><td class="method">GET</td><td><code>/v1/hooks/:id/:secret</code></td><td>URL secret</td><td>View webhook usage</td></tr>
          <tr><td class="method">POST</td><td><code>/v1/hooks/:id/:secret</code></td><td>URL secret</td><td>Deliver a push</td></tr>
          <tr><td class="method">POST</td><td><code>/v1/devices</code></td><td>Bearer</td><td>Register APNs device</td></tr>
          <tr><td class="method">DELETE</td><td><code>/v1/devices/:token</code></td><td>Bearer</td><td>Remove APNs device</td></tr>
        </tbody></table>
      </section>
      <section id="actions"><h2>Actions</h2><p>An action stores an HTTP request. Running it makes the request from the VPS.</p>
        <h3>Create</h3><pre>curl -X POST https://devcom.maximkabaev.com/v1/actions \\
  -H "Authorization: Bearer $AGENT_API_TOKEN" \\
  -H "Content-Type: application/json" \\
  -d '{
    "name": "Restart API",
    "method": "POST",
    "url": "http://api.internal:9000/admin/restart",
    "headers": {"Authorization": "Bearer SERVICE_TOKEN"},
    "body": "{\"reason\":\"manual\"}"
  }'</pre>
        <h3>Run</h3><pre>curl -X POST https://devcom.maximkabaev.com/v1/actions/ACTION_ID/run \\
  -H "Authorization: Bearer $AGENT_API_TOKEN"</pre>
        <p>Run responses include <code>ok</code>, upstream <code>status</code>, <code>durationMs</code>, <code>response</code>, and <code>truncated</code>. Redirects are returned without being followed.</p>
      </section>
      <section id="listeners"><h2>Listeners</h2><p>Create a listener once, then give its returned <code>webhookURL</code> to the source service.</p>
        <h3>Create</h3><pre>curl -X POST https://devcom.maximkabaev.com/v1/listeners \\
  -H "Authorization: Bearer $AGENT_API_TOKEN" \\
  -H "Content-Type: application/json" \\
  -d '{"name":"Deploy finished"}'</pre>
        <h3>Deliver with JSON</h3><pre>curl -X POST 'WEBHOOK_URL' \\
  -H 'Content-Type: application/json' \\
  -d '{"title":"Deploy complete","message":"api.example.com is live"}'</pre>
        <h3>Deliver with headers and text</h3><pre>curl -X POST 'WEBHOOK_URL' \\
  -H 'Content-Type: text/plain' \\
  -H 'X-Devcom-Title: Backup complete' \\
  --data '12.4 GB copied in 83 seconds'</pre>
        <p>For JSON, <code>message</code> and <code>body</code> are equivalent. <code>X-Devcom-Message</code> overrides both. The response reports <code>delivered</code>, <code>failed</code>, and registered <code>devices</code>. Opening the webhook URL in a browser returns these usage instructions without sending a notification.</p>
      </section>
      <section id="devices"><h2>Devices</h2><p>The iOS client manages this automatically. Manual registration accepts a hexadecimal APNs token and <code>sandbox</code> or <code>production</code>.</p>
        <pre>POST /v1/devices
{"token":"HEX_APNS_TOKEN","environment":"sandbox"}</pre>
      </section>
      <section id="limits"><h2>Behavior and limits</h2><ul>
        <li>Action request timeout: 15 seconds.</li><li>Action response preview: 64 KB.</li><li>Action body: 200,000 characters.</li><li>Notification title: 120 characters.</li><li>Notification message: 700 characters.</li><li>Webhook rate limit: 30 requests per minute per client.</li><li>Global API rate limit: 120 requests per minute per client.</li>
      </ul><p>Error responses use <code>{"error":"Human-readable message"}</code>. See the <a href="/openapi.json">OpenAPI document</a> for schemas and response codes.</p></section>
    </article>
  </main>
  <footer><div class="shell">Devcom V1 · private development companion</div></footer>
</body>
</html>`;
