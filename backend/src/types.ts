export const httpMethods = ["GET", "POST", "PUT", "PATCH", "DELETE"] as const;
export type HTTPMethod = (typeof httpMethods)[number];
export const projectColors = ["blue", "violet", "mint", "amber", "rose", "slate"] as const;
export type ProjectColor = (typeof projectColors)[number];

export type ScheduleFrequency = "once" | "weekly";
export type ScheduleRunStatus = "succeeded" | "failed";

export interface ActionSchedule {
  frequency: ScheduleFrequency;
  enabled: boolean;
  runAt: string | null;
  weekdays: number[];
  timeOfDay: string | null;
  timeZone: string;
  nextRunAt: string | null;
  lastRunAt: string | null;
  lastRunStatus: ScheduleRunStatus | null;
  lastError: string | null;
}

export interface Project {
  id: string;
  name: string;
  color: ProjectColor;
  createdAt: string;
  updatedAt: string;
}

export interface ActionEvent {
  id: string;
  kind: "action";
  name: string;
  method: HTTPMethod;
  url: string;
  headers: Record<string, string>;
  body: string | null;
  projectId: string | null;
  schedule: ActionSchedule | null;
  createdAt: string;
  updatedAt: string;
}

export interface Listener {
  id: string;
  kind: "listener";
  name: string;
  secret: string;
  projectId: string | null;
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
  projects: Project[];
  devices: Device[];
}
