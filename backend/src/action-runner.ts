import type { ActionEvent } from "./types.js";

const responseLimit = 64 * 1024;

export interface ActionResult {
  ok: boolean;
  status: number;
  durationMs: number;
  response: string;
  truncated: boolean;
}

export async function runAction(action: ActionEvent): Promise<ActionResult> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);
  const startedAt = performance.now();
  try {
    const request: RequestInit = {
      method: action.method,
      headers: action.headers,
      redirect: "manual",
      signal: controller.signal
    };
    if (action.method !== "GET" && action.method !== "DELETE" && action.body !== null) {
      request.body = action.body;
    }
    const response = await fetch(action.url, request);

    const reader = response.body?.getReader();
    const chunks: Uint8Array[] = [];
    let size = 0;
    let truncated = false;
    if (reader) {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        const remaining = responseLimit - size;
        if (value.byteLength > remaining) {
          if (remaining > 0) chunks.push(value.slice(0, remaining));
          truncated = true;
          await reader.cancel();
          break;
        }
        chunks.push(value);
        size += value.byteLength;
      }
    }

    return {
      ok: response.ok,
      status: response.status,
      durationMs: Math.round(performance.now() - startedAt),
      response: new TextDecoder().decode(Buffer.concat(chunks)),
      truncated
    };
  } finally {
    clearTimeout(timeout);
  }
}
