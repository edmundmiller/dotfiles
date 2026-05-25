/**
 * Cross-extension signal for dumb zone state.
 *
 * Uses globalThis so other extensions (e.g. pi-dcp) can optionally
 * react to dumb zone state without a hard dependency.
 */

export interface DumbZoneSignal {
  inZone: boolean;
  utilization: number;
  severity: "warning" | "danger" | "critical";
  compacted: boolean;
  timestamp: number;
}

const SIGNAL_KEY = "__piDumbZoneSignal";

/** Publish current dumb zone state for other extensions to read. */
export function publishSignal(signal: DumbZoneSignal): void {
  (globalThis as any)[SIGNAL_KEY] = signal;
}

/** Read the current dumb zone signal (returns undefined if dumb-zone not loaded). */
export function readSignal(): DumbZoneSignal | undefined {
  return (globalThis as any)[SIGNAL_KEY];
}

/** Clear the signal (e.g. when leaving the dumb zone). */
export function clearSignal(): void {
  (globalThis as any)[SIGNAL_KEY] = undefined;
}
