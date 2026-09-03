import type { FastifyBaseLogger } from "fastify";
import { runAction } from "./action-runner.js";
import type { Store } from "./store.js";

const pollIntervalMs = 15_000;

export function startScheduler(store: Store, log: FastifyBaseLogger): () => void {
  let running = false;

  const tick = async (): Promise<void> => {
    if (running) return;
    running = true;
    try {
      const due = await store.claimDueActions(new Date());
      await Promise.all(due.map(async ({ action, scheduleKey, runAt }) => {
        try {
          const result = await runAction(action);
          const status = result.ok ? "succeeded" : "failed";
          const error = result.ok ? null : `HTTP ${result.status}`;
          await store.recordScheduledRun(action.id, scheduleKey, runAt, status, error);
          await store.addHistory({ kind: "action", eventId: action.id, eventName: action.name, source: "scheduled", status, statusCode: result.status, occurredAt: new Date().toISOString(), durationMs: result.durationMs, error });
          log.info({ actionId: action.id, status: result.status }, "Scheduled action completed");
        } catch (error) {
          const message = error instanceof Error ? error.message : "Request failed";
          await store.recordScheduledRun(action.id, scheduleKey, runAt, "failed", message.slice(0, 500));
          await store.addHistory({ kind: "action", eventId: action.id, eventName: action.name, source: "scheduled", status: "failed", statusCode: null, occurredAt: new Date().toISOString(), durationMs: null, error: message.slice(0, 500) });
          log.warn({ actionId: action.id, error }, "Scheduled action failed");
        }
      }));
    } catch (error) {
      log.error({ error }, "Scheduler tick failed");
    } finally {
      running = false;
    }
  };

  void tick();
  const timer = setInterval(() => void tick(), pollIntervalMs);
  timer.unref();
  return () => clearInterval(timer);
}
