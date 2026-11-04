// What a terminal is on, one rule for Focus cards, the agents list, tabs and pane headers:
// its Pi session, then (agents only) a tab someone named, then a telling terminal title, else the program.
import { terminals, spaces } from "herdr";

const clean = (s) => (s ?? "").replace(/^[^\p{L}\p{N}]+/u, "").trim();

// Snapshot once per render; the returned function takes an agent or a pane (status set = an agent).
export function namer() {
  const term = new Map(terminals().map((k) => [k.address, k]));
  const tabs = new Map(spaces().flatMap((s) => s.tabs.map((c) => [c.id, c])));
  return (x) => {
    const address = x.address ?? x.terminal;
    const tab = tabs.get(x.tab);
    const live = clean(x.title);
    const telling =
      live &&
      live !== x.program?.name &&
      live.toLowerCase() !== x.program?.key &&
      !/^[~/]|^[A-Za-z]:\\/.test(live) &&
      !live.includes("@");
    return (
      term.get(address)?.labels?.["pi.session"] ||
      (x.status != null && tab?.named && tab.name) ||
      (telling && live) ||
      x.program?.name ||
      address ||
      "shell"
    );
  };
}
