import { createHash, timingSafeEqual } from "node:crypto";
import { compare } from "bcryptjs";
import { jwtVerify, SignJWT } from "jose";
import type { Config } from "./config.js";

function safeEqual(left: string, right: string): boolean {
  const a = createHash("sha256").update(left).digest();
  const b = createHash("sha256").update(right).digest();
  return timingSafeEqual(a, b);
}

export async function verifyPassword(password: string, config: Config): Promise<boolean> {
  return compare(password, config.ADMIN_PASSWORD_HASH);
}

export async function createSession(config: Config): Promise<string> {
  return new SignJWT({ role: "owner" })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(config.ADMIN_USERNAME)
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(config.JWT_SECRET);
}

export async function isAuthorized(header: string | undefined, config: Config): Promise<boolean> {
  if (!header?.startsWith("Bearer ")) return false;
  const token = header.slice(7);
  if (safeEqual(token, config.AGENT_API_TOKEN)) return true;
  try {
    const result = await jwtVerify(token, config.JWT_SECRET, { algorithms: ["HS256"] });
    return result.payload.role === "owner";
  } catch {
    return false;
  }
}

