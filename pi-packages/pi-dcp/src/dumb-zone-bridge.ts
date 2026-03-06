/**
 * Bridge to pi-dumb-zone's globalThis signal.
 *
 * No hard dependency — if pi-dumb-zone isn't loaded, readDumbZoneSignal()
 * returns undefined and DCP behaves as before.
 */

export interface DumbZoneSignal {
  inZone: boolean;
  utilization: number;
  severity: "warning" | "danger" | "critical";
  compacted: boolean;
  timestamp: number;
}

const SIGNAL_KEY = "__piDumbZoneSignal";

/** Read dumb zone signal. Returns undefined if pi-dumb-zone not loaded. */
export function readDumbZoneSignal(): DumbZoneSignal | undefined {
  return (globalThis as any)[SIGNAL_KEY];
}
