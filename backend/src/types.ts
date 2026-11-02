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

export interface ActionSchedules {
  once: ActionSchedule | null;
  recurring: ActionSchedule | null;
}

export type HistoryKind = "action" | "listener";
export type HistorySource = "manual" | "scheduled" | "webhook" | "agent";
export type HistoryStatus = "succeeded" | "failed" | "accepted";
/** How a request reached the server: the iOS app, any other API client with a
 * bearer token, an inbound webhook URL, or the server's own scheduler. */
export type HistoryChannel = "app" | "api" | "webhook" | "scheduler";

export interface HistoryCaller {
  channel: HistoryChannel;
  /** Client address as seen behind the reverse proxy; null for the scheduler. */
  ip: string | null;
  userAgent: string | null;
  /** Self-reported label from the app (X-Devcom-Client), e.g. "Devcom iOS 1.0 · iPhone17,1 · iOS 26.1". */
  client: string | null;
}

export interface HistoryEntry {
  id: string;
  kind: HistoryKind;
  eventId: string;
  eventName: string;
  source: HistorySource;
  status: HistoryStatus;
  statusCode: number | null;
  occurredAt: string;
  durationMs: number | null;
  response: string | null;
  error: string | null;
  // Added later: absent on older records, so every one is optional.
  caller?: HistoryCaller | null;
  /** Action runs: the request that was sent (snapshot, the action may change later). */
  method?: HTTPMethod | null;
  url?: string | null;
  /** Notifications: the text that was pushed. */
  title?: string | null;
  message?: string | null;
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
  schedule: ActionSchedules;
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
  history: HistoryEntry[];
}
