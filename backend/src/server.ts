import "dotenv/config";
import { randomBytes, randomUUID } from "node:crypto";
import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import Fastify, { type FastifyReply, type FastifyRequest } from "fastify";
import { z } from "zod";
import { runAction } from "./action-runner.js";
import { APNSClient } from "./apns.js";
import { createSession, isAuthorized, verifyPassword } from "./auth.js";
import { loadConfig } from "./config.js";
import { docsHTML, openApiDocument } from "./docs.js";
import { Store } from "./store.js";
import { httpMethods, type Listener } from "./types.js";

const config = loadConfig();
const store = new Store(config.DATA_FILE, config.CONFIG_ENCRYPTION_KEY);
const apns = new APNSClient(config);

const app = Fastify({
  logger: { redact: ["req.headers.authorization"] },
  disableRequestLogging: true,
  bodyLimit: 256 * 1024
});

await app.register(helmet);
await app.register(cors, { origin: false });
await app.register(rateLimit, { global: true, max: 120, timeWindow: "1 minute" });
app.addContentTypeParser("text/plain", { parseAs: "string" }, (_request, body, done) => done(null, body));
app.addContentTypeParser("*", { parseAs: "string" }, (_request, body, done) => done(null, body));

async function requireAuth(request: FastifyRequest, reply: FastifyReply): Promise<void | FastifyReply> {
  if (!(await isAuthorized(request.headers.authorization, config))) {
    return reply.code(401).send({ error: "Unauthorized" });
  }
}

function webhookURL(event: Listener): string {
  return `${config.PUBLIC_URL.replace(/\/$/, "")}/v1/hooks/${event.id}/${event.secret}`;
}

function publicListener(event: Listener) {
  return { id: event.id, kind: event.kind, name: event.name, webhookURL: webhookURL(event), createdAt: event.createdAt, updatedAt: event.updatedAt };
}

const credentialsSchema = z.object({ username: z.string().min(1), password: z.string().min(1).max(256) });
const actionSchema = z.object({
  name: z.string().trim().min(1).max(80),
  method: z.enum(httpMethods),
  url: z.string().url().refine((url) => url.startsWith("http://") || url.startsWith("https://"), "Only HTTP(S) URLs are supported"),
  headers: z.record(z.string(), z.string().max(8_192)).default({}),
  body: z.string().max(200_000).nullable().default(null)
});
const listenerSchema = z.object({ name: z.string().trim().min(1).max(80) });
const deviceSchema = z.object({
  token: z.string().regex(/^[a-fA-F0-9]{64,}$/),
  environment: z.enum(["sandbox", "production"])
});

app.get("/health", async () => ({ ok: true }));

app.get("/docs", async (_request, reply) => reply.type("text/html; charset=utf-8").send(docsHTML));
app.get("/docs/", async (_request, reply) => reply.type("text/html; charset=utf-8").send(docsHTML));
app.get("/openapi.json", async (_request, reply) => reply.type("application/json").send(openApiDocument));

app.post("/v1/auth/login", { config: { rateLimit: { max: 8, timeWindow: "15 minutes" } } }, async (request, reply) => {
  const parsed = credentialsSchema.safeParse(request.body);
  if (!parsed.success || parsed.data.username !== config.ADMIN_USERNAME || !(await verifyPassword(parsed.data.password, config))) {
    return reply.code(401).send({ error: "Invalid username or password" });
  }
  return { token: await createSession(config) };
});

app.get("/v1/events", { preHandler: requireAuth }, async () => ({
  actions: store.listActions(),
  listeners: store.listListeners().map(publicListener)
}));

app.post("/v1/actions", { preHandler: requireAuth }, async (request, reply) => {
  const parsed = actionSchema.safeParse(request.body);
  if (!parsed.success) return reply.code(400).send({ error: "Invalid action", details: parsed.error.flatten() });
  const timestamp = new Date().toISOString();
  const action = { id: randomUUID(), kind: "action" as const, ...parsed.data, createdAt: timestamp, updatedAt: timestamp };
  await store.addAction(action);
  return reply.code(201).send(action);
});

app.post("/v1/actions/:id/run", { preHandler: requireAuth }, async (request, reply) => {
  const id = (request.params as { id: string }).id;
  const action = store.findAction(id);
  if (!action) return reply.code(404).send({ error: "Action not found" });
  try {
    return await runAction(action);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Request failed";
    return reply.code(502).send({ error: message });
  }
});

app.delete("/v1/actions/:id", { preHandler: requireAuth }, async (request, reply) => {
  const removed = await store.removeAction((request.params as { id: string }).id);
  return removed ? reply.code(204).send() : reply.code(404).send({ error: "Action not found" });
});

const createListener = async (request: FastifyRequest, reply: FastifyReply) => {
  const parsed = listenerSchema.safeParse(request.body);
  if (!parsed.success) return reply.code(400).send({ error: "Invalid listener", details: parsed.error.flatten() });
  const timestamp = new Date().toISOString();
  const event: Listener = {
    id: randomUUID(),
    kind: "listener",
    name: parsed.data.name,
    secret: randomBytes(32).toString("base64url"),
    createdAt: timestamp,
    updatedAt: timestamp
  };
  await store.addListener(event);
  return reply.code(201).send(publicListener(event));
};

app.post("/v1/listeners", { preHandler: requireAuth }, createListener);
app.post("/v1/listens", { preHandler: requireAuth }, createListener);

const deleteListener = async (request: FastifyRequest, reply: FastifyReply) => {
  const removed = await store.removeListener((request.params as { id: string }).id);
  return removed ? reply.code(204).send() : reply.code(404).send({ error: "Listener not found" });
};

app.delete("/v1/listeners/:id", { preHandler: requireAuth }, deleteListener);
app.delete("/v1/listens/:id", { preHandler: requireAuth }, deleteListener);

app.post("/v1/devices", { preHandler: requireAuth }, async (request, reply) => {
  const parsed = deviceSchema.safeParse(request.body);
  if (!parsed.success) return reply.code(400).send({ error: "Invalid device token" });
  await store.upsertDevice({ ...parsed.data, updatedAt: new Date().toISOString() });
  return reply.code(204).send();
});

app.delete("/v1/devices/:token", { preHandler: requireAuth }, async (request, reply) => {
  await store.removeDevice((request.params as { token: string }).token);
  return reply.code(204).send();
});

app.post("/v1/hooks/:id/:secret", { config: { rateLimit: { max: 30, timeWindow: "1 minute" } } }, async (request, reply) => {
  const { id, secret } = request.params as { id: string; secret: string };
  const event = store.findListener(id);
  if (!event || event.secret !== secret) return reply.code(404).send({ error: "Listener not found" });

  const body = request.body;
  const json = body && typeof body === "object" ? body as Record<string, unknown> : undefined;
  const title = String(request.headers["x-devcom-title"] ?? json?.title ?? event.name).slice(0, 120);
  const message = String(
    request.headers["x-devcom-message"] ?? json?.message ?? json?.body ?? (typeof body === "string" ? body : "Event received")
  ).slice(0, 700);

  const devices = store.listDevices();
  const results = await Promise.allSettled(devices.map((device) => apns.send(device, { title, body: message })));
  for (const result of results) {
    if (result.status === "fulfilled" && result.value.invalidToken) await store.removeDevice(result.value.token);
    if (result.status === "rejected") app.log.warn({ error: result.reason }, "APNs request failed");
    if (result.status === "fulfilled" && !result.value.delivered) {
      app.log.warn({ reason: result.value.reason ?? "Unknown APNs error" }, "Push was not delivered");
    }
  }
  const delivered = results.filter((result) => result.status === "fulfilled" && result.value.delivered).length;
  return reply.code(202).send({ accepted: true, delivered, failed: devices.length - delivered, devices: devices.length });
});

await store.load();
await app.listen({ host: config.HOST, port: config.PORT });
