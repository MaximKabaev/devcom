import type { ActionSchedule } from "./types.js";

export type ScheduleInput =
  | { frequency: "once"; enabled: boolean; runAt: string; timeZone: string }
  | { frequency: "weekly"; enabled: boolean; weekdays: number[]; timeOfDay: string; timeZone: string };

const weekdayFormatter = new Map<string, Intl.DateTimeFormat>();
const timeFormatter = new Map<string, Intl.DateTimeFormat>();

function formatters(timeZone: string): { weekday: Intl.DateTimeFormat; time: Intl.DateTimeFormat } {
  let weekday = weekdayFormatter.get(timeZone);
  let time = timeFormatter.get(timeZone);
  if (!weekday) {
    weekday = new Intl.DateTimeFormat("en-US", { timeZone, weekday: "short" });
    weekdayFormatter.set(timeZone, weekday);
  }
  if (!time) {
    time = new Intl.DateTimeFormat("en-GB", {
      timeZone,
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23"
    });
    timeFormatter.set(timeZone, time);
  }
  return { weekday, time };
}

const weekdayNumbers: Record<string, number> = {
  Sun: 0,
  Mon: 1,
  Tue: 2,
  Wed: 3,
  Thu: 4,
  Fri: 5,
  Sat: 6
};

export function isValidTimeZone(timeZone: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone }).format();
    return true;
  } catch {
    return false;
  }
}

export function nextWeeklyRun(
  weekdays: number[],
  timeOfDay: string,
  timeZone: string,
  after: Date
): string {
  const wantedDays = new Set(weekdays);
  const { weekday, time } = formatters(timeZone);
  const cursor = new Date(after.getTime());
  cursor.setUTCSeconds(0, 0);
  cursor.setUTCMinutes(cursor.getUTCMinutes() + 1);

  // Eight UTC days cover every weekly occurrence, including daylight-saving transitions.
  for (let minute = 0; minute < 8 * 24 * 60; minute += 1) {
    const day = weekdayNumbers[weekday.format(cursor)];
    if (day !== undefined && wantedDays.has(day) && time.format(cursor) === timeOfDay) {
      return cursor.toISOString();
    }
    cursor.setUTCMinutes(cursor.getUTCMinutes() + 1);
  }
  throw new Error("Could not calculate the next scheduled run");
}

export function createSchedule(input: ScheduleInput, now = new Date()): ActionSchedule {
  if (input.frequency === "once") {
    const runAt = new Date(input.runAt).toISOString();
    return {
      frequency: "once",
      enabled: input.enabled,
      runAt,
      weekdays: [],
      timeOfDay: null,
      timeZone: input.timeZone,
      nextRunAt: input.enabled ? runAt : null,
      lastRunAt: null,
      lastRunStatus: null,
      lastError: null
    };
  }

  return {
    frequency: "weekly",
    enabled: input.enabled,
    runAt: null,
    weekdays: [...new Set(input.weekdays)].sort((a, b) => a - b),
    timeOfDay: input.timeOfDay,
    timeZone: input.timeZone,
    nextRunAt: input.enabled ? nextWeeklyRun(input.weekdays, input.timeOfDay, input.timeZone, now) : null,
    lastRunAt: null,
    lastRunStatus: null,
    lastError: null
  };
}
