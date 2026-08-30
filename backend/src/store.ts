import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import type { ActionEvent, Device, ListenEvent, StoredData } from "./types.js";

const emptyData = (): StoredData => ({ version: 1, actions: [], listens: [], devices: [] });

export class Store {
  private data: StoredData = emptyData();
  private writeQueue: Promise<void> = Promise.resolve();

  constructor(private readonly file: string, private readonly key: Buffer) {}

  async load(): Promise<void> {
    try {
      const envelope = JSON.parse(await readFile(this.file, "utf8")) as { iv: string; tag: string; ciphertext: string };
      const decipher = createDecipheriv("aes-256-gcm", this.key, Buffer.from(envelope.iv, "base64"));
      decipher.setAuthTag(Buffer.from(envelope.tag, "base64"));
      const plaintext = Buffer.concat([
        decipher.update(Buffer.from(envelope.ciphertext, "base64")),
        decipher.final()
      ]);
      this.data = JSON.parse(plaintext.toString("utf8")) as StoredData;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
      await this.persist();
    }
  }

  listActions(): ActionEvent[] { return structuredClone(this.data.actions); }
  listListens(): ListenEvent[] { return structuredClone(this.data.listens); }
  listDevices(): Device[] { return structuredClone(this.data.devices); }
  findAction(id: string): ActionEvent | undefined { return structuredClone(this.data.actions.find((item) => item.id === id)); }
  findListen(id: string): ListenEvent | undefined { return structuredClone(this.data.listens.find((item) => item.id === id)); }

  async addAction(event: ActionEvent): Promise<void> {
    this.data.actions.push(event);
    await this.persist();
  }

  async addListen(event: ListenEvent): Promise<void> {
    this.data.listens.push(event);
    await this.persist();
  }

  async removeAction(id: string): Promise<boolean> {
    const before = this.data.actions.length;
    this.data.actions = this.data.actions.filter((item) => item.id !== id);
    if (this.data.actions.length !== before) await this.persist();
    return this.data.actions.length !== before;
  }

  async removeListen(id: string): Promise<boolean> {
    const before = this.data.listens.length;
    this.data.listens = this.data.listens.filter((item) => item.id !== id);
    if (this.data.listens.length !== before) await this.persist();
    return this.data.listens.length !== before;
  }

  async upsertDevice(device: Device): Promise<void> {
    this.data.devices = this.data.devices.filter((item) => item.token !== device.token);
    this.data.devices.push(device);
    await this.persist();
  }

  async removeDevice(token: string): Promise<void> {
    this.data.devices = this.data.devices.filter((item) => item.token !== token);
    await this.persist();
  }

  private async persist(): Promise<void> {
    this.writeQueue = this.writeQueue.then(async () => {
      const iv = randomBytes(12);
      const cipher = createCipheriv("aes-256-gcm", this.key, iv);
      const ciphertext = Buffer.concat([cipher.update(JSON.stringify(this.data)), cipher.final()]);
      const envelope = JSON.stringify({
        iv: iv.toString("base64"),
        tag: cipher.getAuthTag().toString("base64"),
        ciphertext: ciphertext.toString("base64")
      });
      await mkdir(dirname(this.file), { recursive: true });
      const temporaryFile = `${this.file}.tmp`;
      await writeFile(temporaryFile, envelope, { encoding: "utf8", mode: 0o600 });
      await rename(temporaryFile, this.file);
    });
    return this.writeQueue;
  }
}

