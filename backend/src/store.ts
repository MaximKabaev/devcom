import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import type { ActionEvent, Device, Listener, Project, StoredData } from "./types.js";

const emptyData = (): StoredData => ({ version: 1, actions: [], listeners: [], projects: [], devices: [] });

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
      const decoded = JSON.parse(plaintext.toString("utf8")) as StoredData & {
        listens?: Array<Omit<Listener, "kind"> & { kind: "listen" }>;
      };
      const legacyListeners = decoded.listens ?? [];
      this.data = {
        version: 1,
        actions: (decoded.actions ?? []).map((item) => ({ ...item, projectId: item.projectId ?? null })),
        listeners: (decoded.listeners ?? legacyListeners).map((item) => ({ ...item, kind: "listener", projectId: item.projectId ?? null })),
        projects: decoded.projects ?? [],
        devices: decoded.devices ?? []
      };
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
      await this.persist();
    }
  }

  listActions(): ActionEvent[] { return structuredClone(this.data.actions); }
  listListeners(): Listener[] { return structuredClone(this.data.listeners); }
  listProjects(): Project[] { return structuredClone(this.data.projects); }
  listDevices(): Device[] { return structuredClone(this.data.devices); }
  findAction(id: string): ActionEvent | undefined { return structuredClone(this.data.actions.find((item) => item.id === id)); }
  findListener(id: string): Listener | undefined { return structuredClone(this.data.listeners.find((item) => item.id === id)); }
  findProject(id: string): Project | undefined { return structuredClone(this.data.projects.find((item) => item.id === id)); }

  async addAction(event: ActionEvent): Promise<void> {
    this.data.actions.push(event);
    await this.persist();
  }

  async addListener(event: Listener): Promise<void> {
    this.data.listeners.push(event);
    await this.persist();
  }

  async addProject(project: Project): Promise<void> {
    this.data.projects.push(project);
    await this.persist();
  }

  async updateAction(
    id: string,
    update: Partial<Pick<ActionEvent, "name" | "method" | "url" | "headers" | "body" | "projectId">>
  ): Promise<ActionEvent | undefined> {
    const index = this.data.actions.findIndex((item) => item.id === id);
    const current = this.data.actions[index];
    if (index < 0 || !current) return undefined;
    const updated: ActionEvent = { ...current, ...update, updatedAt: new Date().toISOString() };
    this.data.actions[index] = updated;
    await this.persist();
    return structuredClone(updated);
  }

  async updateListener(
    id: string,
    update: Pick<Listener, "name"> & Partial<Pick<Listener, "projectId">>
  ): Promise<Listener | undefined> {
    const index = this.data.listeners.findIndex((item) => item.id === id);
    const current = this.data.listeners[index];
    if (index < 0 || !current) return undefined;
    const updated: Listener = { ...current, ...update, updatedAt: new Date().toISOString() };
    this.data.listeners[index] = updated;
    await this.persist();
    return structuredClone(updated);
  }

  async updateProject(
    id: string,
    update: Partial<Pick<Project, "name" | "color">>
  ): Promise<Project | undefined> {
    const index = this.data.projects.findIndex((item) => item.id === id);
    const current = this.data.projects[index];
    if (index < 0 || !current) return undefined;
    const updated: Project = { ...current, ...update, updatedAt: new Date().toISOString() };
    this.data.projects[index] = updated;
    await this.persist();
    return structuredClone(updated);
  }

  async removeAction(id: string): Promise<boolean> {
    const before = this.data.actions.length;
    this.data.actions = this.data.actions.filter((item) => item.id !== id);
    if (this.data.actions.length !== before) await this.persist();
    return this.data.actions.length !== before;
  }

  async removeListener(id: string): Promise<boolean> {
    const before = this.data.listeners.length;
    this.data.listeners = this.data.listeners.filter((item) => item.id !== id);
    if (this.data.listeners.length !== before) await this.persist();
    return this.data.listeners.length !== before;
  }

  async removeProject(id: string): Promise<boolean> {
    const before = this.data.projects.length;
    this.data.projects = this.data.projects.filter((item) => item.id !== id);
    if (this.data.projects.length === before) return false;
    const timestamp = new Date().toISOString();
    this.data.actions = this.data.actions.map((item) => item.projectId === id ? { ...item, projectId: null, updatedAt: timestamp } : item);
    this.data.listeners = this.data.listeners.map((item) => item.projectId === id ? { ...item, projectId: null, updatedAt: timestamp } : item);
    await this.persist();
    return true;
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
