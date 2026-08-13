/**
 * Shared test utilities for the review-box bridge CLI test suite.
 *
 * Creates isolated temp environments with stub gh/herdr/git binaries at the
 * PATH boundary, temp XDG_STATE_HOME/XDG_CONFIG_HOME, a local git fixture,
 * and a helper to spawn the CLI as a subprocess capturing stdout/stderr/exit.
 */

import {
  mkdirSync,
  mkdtempSync,
  writeFileSync,
  existsSync,
  readFileSync,
  rmSync,
  readdirSync,
  statSync,
  unlinkSync,
  realpathSync,
} from "node:fs";
import { join, dirname, basename } from "node:path";
import { tmpdir } from "node:os";

const REPO_ROOT = dirname(dirname(import.meta.dir));
const CLI_PATH = join(REPO_ROOT, "pi-review-box", "src", "cli.ts");

// ─── Types ───────────────────────────────────────────────────────────

export type StubGhProfile = {
  /** PR info to return from `gh pr view`. */
  pr: {
    number: number;
    title: string;
    baseRefName: string;
    headRefName: string;
    headRefOid: string;
    url: string;
    state: string;
  };
  /** Exit code for gh. Default 0. */
  exitCode?: number;
  /** Stderr to print. */
  stderr?: string;
  /** Delay in ms before responding (for timeout tests). */
  delayMs?: number;
  /** If true, emulate `gh pr checkout` by writing HEAD to a ref file. */
  statefulCheckout?: boolean;
};

export type StubHerdrProfile = {
  /** Workspace ID to return from `workspace create`. */
  workspaceId?: string;
  /** Whether `workspace get` succeeds (workspace is live). Default true. */
  workspaceAlive?: boolean;
  /** If set, herdr exits with this code for all calls. */
  failExitCode?: number;
  /** Delay in ms before responding (for timeout tests). */
  delayMs?: number;
};

export type CliResult = {
  stdout: string;
  stderr: string;
  exitCode: number;
};

export type Env = {
  home: string;
  stateHome: string;
  configHome: string;
  repoRoot: string;
  stubDir: string;
  ghLog: string;
  herdrLog: string;
  gitLog: string;
  ghResponseFile: string;
  herdrIdFile: string;
  herdrDeadFile: string;
  gitRepoRootEnv: string;
  gitHeadOidEnv: string;
  stateDir: string;
  configDir: string;
  cleanup: () => void;
};

// ─── Environment setup ───────────────────────────────────────────────

export function setupEnv(opts: { repo?: string; configMappings?: Record<string, string> }): Env {
  const base = mkdtempSync(join(tmpdir(), "review-box-test-"));
  const home = join(base, "home");
  const stateHome = join(base, "state");
  const configHome = join(base, "config");
  const repoRootRaw = join(base, "repo");
  const stubDir = join(base, "stubs");

  const stateDir = join(stateHome, "pi-herdr", "review-boxes");
  const configDir = join(configHome, "review-box");

  for (const dir of [home, stateHome, configHome, repoRootRaw, stubDir, stateDir, configDir]) {
    mkdirSync(dir, { recursive: true });
  }

  // Resolve symlinks (macOS /var -> /private/var) so config and git stub agree
  const repoRoot = realpathSync(repoRootRaw);

  // Create a minimal git repo fixture
  mkdirSync(join(repoRoot, ".git"), { recursive: true });

  // Write config.json
  const mappings = opts.configMappings ?? {};
  if (opts.repo) {
    mappings[opts.repo] = repoRoot;
  }
  writeFileSync(join(configDir, "config.json"), JSON.stringify(mappings, null, 2) + "\n");

  const ghLog = join(stubDir, "gh-calls.log");
  const herdrLog = join(stubDir, "herdr-calls.log");
  const gitLog = join(stubDir, "git-calls.log");
  const ghResponseFile = join(stubDir, "gh-response.json");
  const herdrIdFile = join(stubDir, "herdr-workspace-id.txt");
  const herdrDeadFile = join(stubDir, "herdr-workspace-dead");
  const gitRepoRootEnv = repoRoot;
  const gitHeadOidEnv = join(stubDir, "git-head-oid.txt");

  // Write default workspace ID
  writeFileSync(herdrIdFile, "w-stub-001");

  createGhStub(stubDir, ghLog, ghResponseFile);
  createHerdrStub(stubDir, herdrLog, herdrIdFile, herdrDeadFile);
  createGitStub(stubDir, gitLog, gitRepoRootEnv, gitHeadOidEnv, repoRoot);

  return {
    home,
    stateHome,
    configHome,
    repoRoot,
    stubDir,
    ghLog,
    herdrLog,
    gitLog,
    ghResponseFile,
    herdrIdFile,
    herdrDeadFile,
    gitRepoRootEnv,
    gitHeadOidEnv,
    stateDir,
    configDir,
    cleanup: () => rmSync(base, { recursive: true, force: true }),
  };
}

// ─── Stub binary creation ────────────────────────────────────────────

function createGhStub(dir: string, logFile: string, responseFile: string): void {
  const script = `#!/usr/bin/env bash
echo "$@" >> "${logFile}"
# Handle pr checkout (stateful or no-op)
if [[ "$1" == "pr" && "$2" == "checkout" ]]; then
  exit 0
fi
# Handle pr view
if [[ "$1" == "pr" && "$2" == "view" ]]; then
  if [[ -f "${responseFile}" ]]; then
    cat "${responseFile}"
    exit 0
  fi
  echo "gh: no response file" >&2
  exit 1
fi
exit 0
`;
  const path = join(dir, "gh");
  writeFileSync(path, script, { mode: 0o755 });
}

function createHerdrStub(dir: string, logFile: string, idFile: string, deadFile: string): void {
  const script = `#!/usr/bin/env bash
echo "$@" >> "${logFile}"
case "$1" in
  workspace)
    case "$2" in
      create)
        COUNTER_FILE="${logFile}.counter"
        COUNTER=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
        COUNTER=$((COUNTER + 1))
        echo "$COUNTER" > "$COUNTER_FILE"
        WS_ID="w-stub-$(printf '%03d' $COUNTER)"
        echo "{\\"workspace_id\\":\\"$WS_ID\\"}"
        exit 0
        ;;
      get)
        if [[ -f "${deadFile}" ]]; then
          echo "workspace not found" >&2
          exit 1
        fi
        echo "{\\"workspace_id\\":\\"w-stub-alive\\"}"
        exit 0
        ;;
      close|focus)
        exit 0
        ;;
    esac
    ;;
  tab)
    case "$2" in
      create)
        TAB_COUNT=$(wc -l < "${logFile}" 2>/dev/null || echo 1)
        echo "{\\"pane_id\\":\\"p-stub-$TAB_COUNT\\"}"
        exit 0
        ;;
    esac
    ;;
  pane)
    exit 0
    ;;
esac
exit 0
`;
  const path = join(dir, "herdr");
  writeFileSync(path, script, { mode: 0o755 });
}

function createGitStub(
  dir: string,
  logFile: string,
  repoRoot: string,
  headOidFile: string,
  actualRepoRoot: string
): void {
  const script = `#!/usr/bin/env bash
echo "$@" >> "${logFile}"
case "$1" in
  rev-parse)
    if [[ "$2" == "--show-toplevel" ]]; then
      echo "$PWD"
      exit 0
    elif [[ "$2" == "--path-format=absolute" ]]; then
      echo "$PWD/.git"
      exit 0
    elif [[ "$2" == "HEAD" ]]; then
      if [[ -f "${headOidFile}" ]]; then
        cat "${headOidFile}"
      else
        echo "abc123def456789012345678901234567890abcd"
      fi
      exit 0
    fi
    ;;
  fetch)
    exit 0
    ;;
  worktree)
    if [[ "$2" == "add" ]]; then
      mkdir -p "$4"
      exit 0
    elif [[ "$2" == "prune" ]]; then
      exit 0
    fi
    ;;
esac
exit 0
`;
  const path = join(dir, "git");
  writeFileSync(path, script, { mode: 0o755 });
}

// ─── Stub configuration ──────────────────────────────────────────────

export function setGhProfile(env: Env, profile: StubGhProfile): void {
  writeFileSync(env.ghResponseFile, JSON.stringify(profile.pr) + "\n");
  if (profile.delayMs) {
    // Rewrite gh stub with delay
    const script = `#!/usr/bin/env bash
echo "$@" >> "${env.ghLog}"
if [[ "$1" == "pr" && "$2" == "checkout" ]]; then exit 0; fi
if [[ "$1" == "pr" && "$2" == "view" ]]; then
  sleep ${profile.delayMs / 1000}
  cat "${env.ghResponseFile}"
  exit 0
fi
exit 0
`;
    writeFileSync(join(env.stubDir, "gh"), script, { mode: 0o755 });
  }
  if (profile.exitCode && profile.exitCode !== 0) {
    const script = `#!/usr/bin/env bash
echo "$@" >> "${env.ghLog}"
if [[ "$1" == "pr" && "$2" == "checkout" ]]; then exit 0; fi
if [[ "$1" == "pr" && "$2" == "view" ]]; then
  ${profile.stderr ? `echo ${shellQuote(profile.stderr)} >&2` : ""}
  exit ${profile.exitCode}
fi
exit 0
`;
    writeFileSync(join(env.stubDir, "gh"), script, { mode: 0o755 });
  }
}

export function setHerdrProfile(env: Env, profile: StubHerdrProfile): void {
  if (profile.workspaceId) {
    writeFileSync(env.herdrIdFile, profile.workspaceId);
  }
  if (profile.workspaceAlive === false) {
    writeFileSync(env.herdrDeadFile, "1");
  } else {
    try {
      unlinkSync(env.herdrDeadFile);
    } catch {}
  }
  if (profile.failExitCode) {
    const script = `#!/usr/bin/env bash
echo "$@" >> "${env.herdrLog}"
${profile.delayMs ? `sleep ${profile.delayMs / 1000}` : ""}
echo "herdr: simulated failure" >&2
exit ${profile.failExitCode}
`;
    writeFileSync(join(env.stubDir, "herdr"), script, { mode: 0o755 });
  } else if (profile.delayMs) {
    const baseId = existsSync(env.herdrIdFile)
      ? readFileSync(env.herdrIdFile, "utf8").trim()
      : "w-stub-001";
    const deadExists = existsSync(env.herdrDeadFile);
    const script = `#!/usr/bin/env bash
echo "$@" >> "${env.herdrLog}"
sleep ${profile.delayMs / 1000}
case "$1" in
  workspace)
    case "$2" in
      create) echo "{\\"workspace_id\\":\\"${baseId}\\"}"; exit 0 ;;
      get) ${deadExists ? 'echo "workspace not found" >&2; exit 1' : `echo "{\\"workspace_id\\":\\"${baseId}\\"}"; exit 0`} ;;
      close|focus) exit 0 ;;
    esac ;;
  tab) case "$2" in create) echo "{\\"pane_id\\":\\"p-stub-1\\"}"; exit 0 ;; esac ;;
  pane) exit 0 ;;
esac
exit 0
`;
    writeFileSync(join(env.stubDir, "herdr"), script, { mode: 0o755 });
  } else {
    // Restore the default herdr stub
    createHerdrStub(env.stubDir, env.herdrLog, env.herdrIdFile, env.herdrDeadFile);
  }
}

function shellQuote(s: string): string {
  return `'${s.replace(/'/g, "'\\''")}'`;
}

// ─── CLI invocation ──────────────────────────────────────────────────

export async function runCli(
  env: Env,
  opts: {
    stdin?: string;
    args?: string[];
    extraEnv?: Record<string, string>;
    tty?: boolean;
  }
): Promise<CliResult> {
  const path = [env.stubDir, process.env.PATH ?? ""].join(":");

  const spawnEnv: Record<string, string> = {
    ...process.env,
    PATH: path,
    HOME: env.home,
    XDG_STATE_HOME: env.stateHome,
    XDG_CONFIG_HOME: env.configHome,
    ...opts.extraEnv,
  };

  // Remove REVIEW_BOX_REPO_ROOT if not explicitly set
  if (!opts.extraEnv?.REVIEW_BOX_REPO_ROOT) {
    delete spawnEnv.REVIEW_BOX_REPO_ROOT;
  }

  const cmd = ["bun", "run", CLI_PATH, ...(opts.args ?? [])];

  const proc = Bun.spawn({
    cmd,
    stdin: opts.stdin !== undefined ? new TextEncoder().encode(opts.stdin) : "ignore",
    stdout: "pipe",
    stderr: "pipe",
    env: spawnEnv,
    cwd: env.repoRoot,
  });

  const [exitCode, stdout, stderr] = await Promise.all([
    proc.exited,
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);

  return { stdout: stdout.trimEnd(), stderr: stderr.trimEnd(), exitCode };
}

// ─── Assertion helpers ───────────────────────────────────────────────

export function readLog(path: string): string[] {
  if (!existsSync(path)) return [];
  return readFileSync(path, "utf8")
    .trim()
    .split("\n")
    .filter((l) => l.length > 0);
}

export function readManifest(env: Env, key: string): Record<string, unknown> | undefined {
  const path = join(env.stateDir, `${key}.json`);
  if (!existsSync(path)) return undefined;
  return JSON.parse(readFileSync(path, "utf8"));
}

export function manifestExists(env: Env, key: string): boolean {
  return existsSync(join(env.stateDir, `${key}.json`));
}

export function listStateFiles(env: Env): string[] {
  if (!existsSync(env.stateDir)) return [];
  return readdirSync(env.stateDir).filter((f) => f.endsWith(".json"));
}

export function statMode(env: Env, key: string): string {
  const stat = statSync(join(env.stateDir, `${key}.json`));
  return (stat.mode & 0o777).toString(8).padStart(3, "0");
}

// ─── Standard PR fixture ─────────────────────────────────────────────

export const STD_PR = {
  repository: "edmundmiller/dotfiles",
  number: 216,
  headRefOid: "9044c42cf123456789012345678901234567890a",
  headRefName: "feature-branch",
  title: "Add review box prototype",
  url: "https://github.com/edmundmiller/dotfiles/pull/216",
} as const;

export const STD_PR_JSON = JSON.stringify(STD_PR);

export const STD_GH_RESPONSE = {
  number: 216,
  title: "Add review box prototype",
  baseRefName: "main",
  headRefName: "feature-branch",
  headRefOid: "9044c42cf123456789012345678901234567890a",
  url: "https://github.com/edmundmiller/dotfiles/pull/216",
  state: "OPEN",
};

export const STD_MANIFEST_KEY = "edmundmiller-dotfiles-pr-216";
