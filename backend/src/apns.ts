import { connect, type ClientHttp2Session } from "node:http2";
import { readFile } from "node:fs/promises";
import { importPKCS8, SignJWT } from "jose";
import type { Config } from "./config.js";
import type { Device } from "./types.js";

interface PushMessage { title: string; body: string }
export interface PushResult { token: string; delivered: boolean; invalidToken: boolean; reason?: string }
type APNSEnvironment = Device["environment"];
interface APNSCredentials { keyId: string; privateKey: string }

function notificationPayload(message: PushMessage): string {
  const body = Array.from(message.body);
  let payload = JSON.stringify({ aps: { alert: { title: message.title, body: body.join("") }, sound: "default" } });
  while (Buffer.byteLength(payload, "utf8") > 4_096 && body.length > 0) {
    body.pop();
    payload = JSON.stringify({ aps: { alert: { title: message.title, body: body.join("") }, sound: "default" } });
  }
  return payload;
}

export class APNSClient {
  private readonly keys = new Map<string, CryptoKey>();
  private readonly providerTokens = new Map<string, { value: string; createdAt: number }>();

  constructor(private readonly config: Config) {}

  isConfigured(environment?: APNSEnvironment): boolean {
    if (!this.config.APNS_TEAM_ID || !this.config.APNS_BUNDLE_ID) return false;
    if (environment) return Boolean(this.credentialsFor(environment));
    return Boolean(this.credentialsFor("sandbox") || this.credentialsFor("production"));
  }

  async send(device: Device, message: PushMessage): Promise<PushResult> {
    const credentials = this.credentialsFor(device.environment);
    if (!this.isConfigured(device.environment) || !credentials) {
      return {
        token: device.token,
        delivered: false,
        invalidToken: false,
        reason: `APNs is not configured for ${device.environment}`
      };
    }

    const host = device.environment === "production"
      ? "https://api.push.apple.com"
      : "https://api.sandbox.push.apple.com";
    const client = connect(host);
    client.on("error", () => {});
    try {
      const token = await this.getProviderToken(credentials);
      return await this.performRequest(client, device.token, token, message);
    } finally {
      client.close();
    }
  }

  private credentialsFor(environment: APNSEnvironment): APNSCredentials | undefined {
    const environmentKeyId = environment === "sandbox"
      ? this.config.APNS_SANDBOX_KEY_ID
      : this.config.APNS_PRODUCTION_KEY_ID;
    const environmentPrivateKey = environment === "sandbox"
      ? this.config.APNS_SANDBOX_PRIVATE_KEY
      : this.config.APNS_PRODUCTION_PRIVATE_KEY;
    if (environmentKeyId && environmentPrivateKey) {
      return { keyId: environmentKeyId, privateKey: environmentPrivateKey };
    }
    if (this.config.APNS_KEY_ID && this.config.APNS_PRIVATE_KEY) {
      return { keyId: this.config.APNS_KEY_ID, privateKey: this.config.APNS_PRIVATE_KEY };
    }
    return undefined;
  }

  private async getProviderToken(credentials: APNSCredentials): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    const cacheKey = `${credentials.keyId}:${credentials.privateKey}`;
    const providerToken = this.providerTokens.get(cacheKey);
    if (providerToken && now - providerToken.createdAt < 50 * 60) return providerToken.value;

    let key = this.keys.get(cacheKey);
    if (!key) {
      const configuredKey = credentials.privateKey;
      const pem = configuredKey.includes("BEGIN PRIVATE KEY")
        ? configuredKey.replaceAll("\\n", "\n")
        : await readFile(configuredKey, "utf8");
      key = await importPKCS8(pem, "ES256");
      this.keys.set(cacheKey, key);
    }

    const value = await new SignJWT({})
      .setProtectedHeader({ alg: "ES256", kid: credentials.keyId })
      .setIssuer(this.config.APNS_TEAM_ID!)
      .setIssuedAt(now)
      .sign(key);
    this.providerTokens.set(cacheKey, { value, createdAt: now });
    return value;
  }

  private performRequest(
    client: ClientHttp2Session,
    deviceToken: string,
    providerToken: string,
    message: PushMessage
  ): Promise<PushResult> {
    return new Promise((resolve, reject) => {
      const request = client.request({
        ":method": "POST",
        ":path": `/3/device/${deviceToken}`,
        authorization: `bearer ${providerToken}`,
        "apns-topic": this.config.APNS_BUNDLE_ID!,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-expiration": "0"
      });
      let status = 0;
      let responseBody = "";
      let settled = false;
      const finish = (result: PushResult) => {
        if (settled) return;
        settled = true;
        clearTimeout(timeout);
        resolve(result);
      };
      const fail = (error: Error) => {
        if (settled) return;
        settled = true;
        clearTimeout(timeout);
        reject(error);
      };
      const timeout = setTimeout(() => {
        finish({ token: deviceToken, delivered: false, invalidToken: false, reason: "APNs request timed out" });
        request.close();
      }, 10_000);
      request.setEncoding("utf8");
      request.on("response", (headers) => { status = Number(headers[":status"] ?? 0); });
      request.on("data", (chunk: string) => { responseBody += chunk; });
      request.on("end", () => {
        let reason: string | undefined;
        try { reason = (JSON.parse(responseBody) as { reason?: string }).reason; } catch { reason = undefined; }
        const invalidToken = status === 410 || reason === "BadDeviceToken" || reason === "Unregistered";
        finish({
          token: deviceToken,
          delivered: status === 200,
          invalidToken,
          ...(reason ? { reason } : {})
        });
      });
      request.on("error", fail);
      request.end(notificationPayload(message));
    });
  }
}
