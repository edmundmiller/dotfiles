import { expect, test } from "bun:test";

import { parseCli } from "./packages/hunk/src/app/cli";
import { resolveConfiguredCliInput } from "./packages/hunk/src/core/run/config";
import { resolveExtensionCommands } from "./packages/hunk/src/extensions/apply";
import { getBundledUIRegistry } from "./packages/hunk/src/extensions/default/ui";
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
  const input = await parseCli([
    "bun",
    "hunk",
    "--extension",
    process.env.HUNK_TEST_EXTENSIONS!,
    "patch",
    "-",
    "--pager",
  ]);
  if (input.kind !== "patch") throw new Error("Expected a patch review");
  const configured = resolveConfiguredCliInput(input, { env: process.env });
  const loaded = await loadStartupExtensions({
    extensions: configured.extensions,
    cliExtensionPaths: configured.input.options.extensionPaths,
    env: process.env,
    projectRoot: configured.projectRoot,
  });

  expect(loaded.issues).toEqual([]);
  expect(loaded.loaded.map(({ id }) => id)).toContain("hunk-commit-log");
  expect(loaded.loaded.map(({ id }) => id)).toContain("jev-priority");
  expect(loaded.registry.changesetTransforms.map(({ extensionId }) => extensionId)).toContain(
    "jev-priority"
  );

  const registered = resolveExtensionCommands({
    commands: [...getBundledUIRegistry().commands, ...loaded.registry.commands],
  });
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

  expect(keymap.keys.get("hunk.review.nextNote")).toEqual([]);
  expect(keymap.keys.get("hunk.search.next")).toEqual(["n"]);
  expect(keymap.keys.get("hunk-commit-log.next")).toEqual(["ctrl+n"]);
});

test.each([
  [["--no-extensions"]],
  [["--disable-extension", "jev-priority"]],
  [["--disable-extension", "hunk-commit-log"]],
])("packaged extensions honor selection controls: %j", async (flags) => {
  const input = await parseCli([
    "bun",
    "hunk",
    "--extension",
    process.env.HUNK_TEST_EXTENSIONS!,
    "patch",
    "-",
    ...flags,
  ]);
  if (input.kind !== "patch") throw new Error("Expected a patch review");
  const configured = resolveConfiguredCliInput(input, { env: process.env });
  const loaded = await loadStartupExtensions({
    extensions: configured.extensions,
    cliExtensionPaths: configured.input.options.extensionPaths,
    cliSelectionOverrides: configured.input.options.extensionSelectionOverrides,
    env: process.env,
    projectRoot: configured.projectRoot,
  });
  expect(loaded.issues).toEqual([]);
  const ids = loaded.loaded.map(({ id }) => id);
  for (const id of ["hunk-commit-log", "jev-priority"]) {
    expect(ids.includes(id)).toBe(flags[0] !== "--no-extensions" && flags[1] !== id);
  }
});
