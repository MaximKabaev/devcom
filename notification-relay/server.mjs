import http from "node:http";

const port = Number(process.env.PORT || 8090);
const maxBodyBytes = 64 * 1024;
const requestTimeoutMs = 15_000;

function sendJson(response, status, payload) {
  const body = JSON.stringify(payload);
  response.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(body)
  });
  response.end(body);
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    let size = 0;
    let body = "";
    request.setEncoding("utf8");
    request.on("data", (chunk) => {
      size += Buffer.byteLength(chunk);
      if (size > maxBodyBytes) {
        reject(new Error("Request body is too large"));
        request.destroy();
        return;
      }
      body += chunk;
    });
    request.on("end", () => resolve(body));
    request.on("error", reject);
  });
}

const server = http.createServer(async (request, response) => {
  if (request.method === "GET" && request.url === "/health") {
    return sendJson(response, 200, { ok: true });
  }

  if (request.method !== "POST" || request.url !== "/trigger") {
    return sendJson(response, 404, { error: "Not found" });
  }

  try {
    const parsed = JSON.parse(await readBody(request));
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return sendJson(response, 400, { error: "JSON object required" });
    }
    const webhookURL = typeof parsed.webhookURL === "string" ? parsed.webhookURL : "";
    if (!webhookURL) return sendJson(response, 400, { error: "webhookURL is required" });
    let target;
    try {
      target = new URL(webhookURL);
    } catch {
      return sendJson(response, 400, { error: "webhookURL must be a valid URL" });
    }
    if (target.protocol !== "http:" && target.protocol !== "https:") {
      return sendJson(response, 400, { error: "webhookURL must use HTTP or HTTPS" });
    }

    const title = typeof parsed.title === "string" ? parsed.title : undefined;
    const message = typeof parsed.message === "string" ? parsed.message : undefined;
    if (title === undefined && message === undefined) {
      return sendJson(response, 400, { error: "Provide title or message" });
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), requestTimeoutMs);
    let upstream;
    try {
      upstream = await fetch(target, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ ...(title === undefined ? {} : { title }), ...(message === undefined ? {} : { message }) }),
        redirect: "error",
        signal: controller.signal
      });
    } finally {
      clearTimeout(timeout);
    }

    const text = await upstream.text();
    let upstreamPayload;
    try {
      upstreamPayload = JSON.parse(text);
    } catch {
      upstreamPayload = text.slice(0, maxBodyBytes);
    }
    return sendJson(response, upstream.status, {
      targetStatus: upstream.status,
      targetResponse: upstreamPayload
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Relay request failed";
    return sendJson(response, 502, { error: message.slice(0, 500) });
  }
});

server.listen(port, "0.0.0.0", () => {
  console.log(`notification relay listening on ${port}`);
});
