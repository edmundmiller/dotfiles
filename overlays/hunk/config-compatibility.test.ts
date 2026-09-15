import { expect, test } from "bun:test";

import { resolveConfiguredCliInput } from "./packages/hunk/src/core/run/config";
import { resolveExtensionCommands } from "./packages/hunk/src/extensions/apply";
import { loadStartupExtensions } from "./packages/hunk/src/extensions/startup";
import {
  builtinCommandKeyDefaults,
  builtinCommandMatchProbes,
} from "./packages/hunk/src/ui/lib/appCommands";
import {
  buildExtensionAppCommands,
  extensionCommandKeyDefaults,
} from "./packages/hunk/src/ui/lib/extensionCommands";
import { resolveCommandKeys } from "./packages/hunk/src/ui/lib/keymap";

test("deployed config loads every extension command without key collisions", async () => {
  const configured = resolveConfiguredCliInput(
    { kind: "patch", file: "-", options: { pager: true } },
    { env: process.env }
  );
  const loaded = await loadStartupExtensions({
    extensions: configured.extensions,
    env: process.env,
    projectRoot: configured.projectRoot,
  });

  expect(loaded.issues).toEqual([]);
  expect(loaded.loaded.map(({ id }) => id)).toContain("hunk-commit-log");

  const registered = resolveExtensionCommands(loaded.registry);
  expect(registered.issues).toEqual([]);

  const keymap = resolveCommandKeys({
    defaults: [...builtinCommandKeyDefaults(), ...extensionCommandKeyDefaults(registered.commands)],
    userBindings: configured.keybindings,
  });
  expect(keymap.issues).toEqual([]);

  const resolved = buildExtensionAppCommands({
    registered: registered.commands,
    builtins: builtinCommandMatchProbes(keymap.keys),
    resolvedKeys: keymap.keys,
    runCommand: () => {},
  });
  expect(resolved.conflicts).toEqual([]);

  expect(keymap.keys.get("hunk.review.nextNote")).toEqual(["n"]);
  expect(keymap.keys.get("hunk-commit-log.next")).toEqual(["ctrl+n"]);
});
