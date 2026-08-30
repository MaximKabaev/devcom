export const httpMethods = ["GET", "POST", "PUT", "PATCH", "DELETE"] as const;
export type HTTPMethod = (typeof httpMethods)[number];

export interface ActionEvent {
  id: string;
  kind: "action";
  name: string;
  method: HTTPMethod;
  url: string;
  headers: Record<string, string>;
  body: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface Listener {
  id: string;
  kind: "listener";
  name: string;
  secret: string;
  createdAt: string;
  updatedAt: string;
}

export interface Device {
  token: string;
  environment: "sandbox" | "production";
  updatedAt: string;
}

export interface StoredData {
  version: 1;
  actions: ActionEvent[];
  listeners: Listener[];
  devices: Device[];
}
