import { describe, test, expect } from "bun:test";
import { scanForSecrets, scanUrl, scanHeaders } from "../src/secrets";

describe("scanForSecrets", () => {
  test("detects GitHub PAT", () => {
    const m = scanForSecrets("token: ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789");
    expect(m).not.toBeNull();
    expect(m!.name).toBe("GitHub PAT (classic)");
  });

  test("detects AWS key", () => {
    const m = scanForSecrets("AKIAIOSFODNN7EXAMPLE");
    expect(m).not.toBeNull();
    expect(m!.name).toBe("AWS Access Key ID");
  });

  test("detects Stripe live key", () => {
    const m = scanForSecrets("sk_live_" + "ABCDEFGHIJKLMNOPQRSTUVWx");
    expect(m).not.toBeNull();
    expect(m!.name).toBe("Stripe Live Key");
  });

  test("detects private key header", () => {
    const m = scanForSecrets("-----BEGIN RSA PRIVATE KEY-----");
    expect(m).not.toBeNull();
    expect(m!.name).toBe("Private Key");
  });

  test("returns null for clean text", () => {
    expect(scanForSecrets("hello world, no secrets here")).toBeNull();
  });
});

describe("scanUrl", () => {
  test("detects secret in query param", () => {
    const r = scanUrl("https://example.com/api?key=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789");
    expect(r.found).toBe(true);
  });

  test("passes clean URL", () => {
    const r = scanUrl("https://example.com/page?q=hello");
    expect(r.found).toBe(false);
  });
});

describe("scanHeaders", () => {
  test("skips Authorization header", () => {
    const r = scanHeaders({ Authorization: "Bearer ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" });
    expect(r.found).toBe(false);
  });

  test("detects secret in custom header", () => {
    const r = scanHeaders({ "X-Api-Key": "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" });
    expect(r.found).toBe(true);
  });
});
