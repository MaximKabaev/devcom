import { z } from "zod";

const schema = z.object({
  HOST: z.string().default("127.0.0.1"),
  PORT: z.coerce.number().int().min(1).max(65535).default(8080),
  PUBLIC_URL: z.string().url(),
  DATA_FILE: z.string().default("./data/devcom.json"),
  ADMIN_USERNAME: z.string().min(1).default("admin"),
  ADMIN_PASSWORD_HASH: z.string().min(20),
  AGENT_API_TOKEN: z.string().min(32),
  CONFIG_ENCRYPTION_KEY: z.string().transform((value, context) => {
    const key = Buffer.from(value, "base64");
    if (key.length !== 32) {
      context.addIssue({ code: "custom", message: "must decode to exactly 32 bytes" });
      return z.NEVER;
    }
    return key;
  }),
  JWT_SECRET: z.string().transform((value, context) => {
    const key = Buffer.from(value, "base64");
    if (key.length < 32) {
      context.addIssue({ code: "custom", message: "must decode to at least 32 bytes" });
      return z.NEVER;
    }
    return key;
  }),
  APNS_TEAM_ID: z.string().optional(),
  APNS_KEY_ID: z.string().optional(),
  APNS_BUNDLE_ID: z.string().optional(),
  APNS_PRIVATE_KEY: z.string().optional(),
  APNS_SANDBOX_KEY_ID: z.string().optional(),
  APNS_SANDBOX_PRIVATE_KEY: z.string().optional(),
  APNS_PRODUCTION_KEY_ID: z.string().optional(),
  APNS_PRODUCTION_PRIVATE_KEY: z.string().optional()
});

export type Config = z.infer<typeof schema>;

export function loadConfig(environment: NodeJS.ProcessEnv = process.env): Config {
  const parsed = schema.safeParse(environment);
  if (!parsed.success) {
    const errors = parsed.error.issues.map((issue) => `${issue.path.join(".")}: ${issue.message}`).join("\n");
    throw new Error(`Invalid environment configuration:\n${errors}`);
  }
  return parsed.data;
}
