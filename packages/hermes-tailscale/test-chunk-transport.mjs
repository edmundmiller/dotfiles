import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

const pluginPath = process.argv[2];
const testModulePath = `${process.env.TMPDIR}/hermes-tailscale-plugin-test.mjs`;
const replacements = [
  ['import * as sdk from "@hermes/plugin-sdk";', "const sdk = globalThis.__hermesTailscaleSdk;"],
  [
    'import { Fragment, useEffect, useMemo, useRef, useState } from "react";',
    "const { Fragment, useEffect, useMemo, useRef, useState } = globalThis.__hermesTailscaleReact;",
  ],
  [
    'import { jsx, jsxs } from "react/jsx-runtime";',
    "const { jsx, jsxs } = globalThis.__hermesTailscaleJsx;",
  ],
];

let source = await readFile(pluginPath, "utf8");
for (const [original, replacement] of replacements) {
  assert.ok(source.includes(original), `missing test seam: ${original}`);
  source = source.replace(original, replacement);
}
await writeFile(testModulePath, source);

const raw = JSON.stringify({
  BackendState: "Running",
  Padding: "tailnet-π-".repeat(900),
});
const payload = Buffer.from(raw, "utf8");
const token = "a".repeat(32);
const commands = [];
let deleted = false;

globalThis.__hermesTailscaleSdk = {
  host: {
    async request(method, { command }) {
      assert.equal(method, "shell.exec");
      commands.push(command);

      if (command.includes("hermes-json snapshot status")) {
        return {
          code: 0,
          stdout: JSON.stringify({ token, bytes: payload.length }),
          stderr: "",
        };
      }

      const chunk = command.match(/hermes-json chunk ([0-9a-f]{32}) ([0-9]+)/);
      if (chunk) {
        assert.equal(chunk[1], token);
        const offset = Number(chunk[2]);
        return {
          code: 0,
          stdout: payload.subarray(offset, offset + 2048).toString("base64"),
          stderr: "",
        };
      }

      if (command.includes(`hermes-json delete ${token}`)) {
        deleted = true;
        return { code: 0, stdout: "", stderr: "" };
      }

      throw new Error(`unexpected shell command: ${command}`);
    },
  },
  atom(initial) {
    let value = initial;
    return {
      get: () => value,
      set: (next) => {
        value = next;
      },
    };
  },
  useValue: () => undefined,
  ROUTES_AREA: "routes",
  SIDEBAR_NAV_AREA: "sidebar",
  PALETTE_AREA: "palette",
  STATUSBAR_AREAS: {},
  Tip: null,
  haptic: null,
};
globalThis.__hermesTailscaleReact = {
  Fragment: Symbol("Fragment"),
  useEffect: () => undefined,
  useMemo: () => undefined,
  useRef: () => undefined,
  useState: () => undefined,
};
globalThis.__hermesTailscaleJsx = {
  jsx: () => undefined,
  jsxs: () => undefined,
};

const plugin = await import(pathToFileURL(testModulePath));
const reconstructed = await plugin.__test.readRestrictedJson(
  { path: "tailscale" },
  "linux",
  "status"
);

assert.equal(reconstructed, raw);
assert.ok(payload.length > 4096, "fixture must exceed Hermes' shell output cap");
assert.ok(commands.filter((command) => command.includes("hermes-json chunk")).length > 1);
assert.equal(deleted, true, "snapshot must be deleted after reconstruction");
