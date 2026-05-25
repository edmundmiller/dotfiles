import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { setupDumbZoneHook } from "./the-dumb-zone";

export function setupDumbZoneHooks(pi: ExtensionAPI) {
  setupDumbZoneHook(pi);
}
