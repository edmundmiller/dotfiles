// flue-blueprint: sandbox/docker-exec@1
import { spawn } from "node:child_process";
import { createSandboxSessionEnv } from "@flue/runtime";
import type { FileStat, SandboxApi, SandboxFactory, SessionEnv } from "@flue/runtime";

const quote = (value: string) => `'${value.replace(/'/g, `'\\''`)}'`;

class DockerSandboxApi implements SandboxApi {
  private readonly container: string;

  constructor(container: string) {
    this.container = container;
  }

  async exec(
    command: string,
    options?: {
      cwd?: string;
      env?: Record<string, string>;
      timeoutMs?: number;
      signal?: AbortSignal;
    }
  ): Promise<{ stdout: string; stderr: string; exitCode: number }> {
    const args = ["exec"];
    if (options?.cwd) args.push("--workdir", options.cwd);
    for (const [name, value] of Object.entries(options?.env ?? {})) {
      args.push("--env", `${name}=${value}`);
    }
    args.push(this.container);
    if (options?.timeoutMs) {
      args.push("timeout", String(options.timeoutMs / 1000));
    }
    args.push("bash", "-lc", command);

    const { promise, resolve, reject } = Promise.withResolvers<{
      stdout: string;
      stderr: string;
      exitCode: number;
    }>();
    const child = spawn("docker", args, {
      env: {
        DOCKER_CONFIG: process.env.DOCKER_CONFIG,
        DOCKER_CONTEXT: process.env.DOCKER_CONTEXT,
        DOCKER_HOST: process.env.DOCKER_HOST,
        HOME: process.env.HOME,
        PATH: process.env.PATH,
      },
      signal: options?.signal,
      stdio: ["ignore", "pipe", "pipe"],
    });
    const stdout: Buffer[] = [];
    const stderr: Buffer[] = [];
    child.stdout.on("data", (chunk) => stdout.push(chunk));
    child.stderr.on("data", (chunk) => stderr.push(chunk));
    child.on("error", reject);
    child.on("close", (code) => {
      resolve({
        stdout: Buffer.concat(stdout).toString("utf8"),
        stderr: Buffer.concat(stderr).toString("utf8"),
        exitCode: code ?? 1,
      });
    });
    return promise;
  }

  async readFile(path: string): Promise<string> {
    const result = await this.exec(`cat -- ${quote(path)}`);
    if (result.exitCode !== 0) throw new Error(result.stderr);
    return result.stdout;
  }

  async readFileBuffer(path: string): Promise<Uint8Array> {
    const result = await this.exec(`base64 < ${quote(path)}`);
    if (result.exitCode !== 0) throw new Error(result.stderr);
    return Uint8Array.from(Buffer.from(result.stdout.replace(/\s+/g, ""), "base64"));
  }

  async writeFile(path: string, content: string | Uint8Array): Promise<void> {
    const encoded = Buffer.from(content).toString("base64");
    const result = await this.exec(
      `mkdir -p "$(dirname ${quote(path)})" && printf %s '${encoded}' | base64 -d > ${quote(path)}`
    );
    if (result.exitCode !== 0) throw new Error(result.stderr);
  }

  async stat(path: string): Promise<FileStat> {
    const result = await this.exec(`stat -c '%F|%s|%Y' ${quote(path)}`);
    if (result.exitCode !== 0) throw new Error(result.stderr);
    const [type, size, modified] = result.stdout.trim().split("|");
    if (!type || !size || !modified) throw new Error(`Malformed stat output: ${result.stdout}`);
    return {
      isFile: type.startsWith("regular"),
      isDirectory: type === "directory",
      isSymbolicLink: type === "symbolic link",
      size: Number(size),
      mtime: new Date(Number(modified) * 1000),
    };
  }

  async readdir(path: string): Promise<string[]> {
    const result = await this.exec(`ls -A1 -- ${quote(path)}`);
    if (result.exitCode !== 0) throw new Error(result.stderr);
    return result.stdout.split("\n").filter(Boolean);
  }

  async exists(path: string): Promise<boolean> {
    return (await this.exec(`test -e ${quote(path)}`)).exitCode === 0;
  }

  async mkdir(path: string, options?: { recursive?: boolean }): Promise<void> {
    const result = await this.exec(`mkdir ${options?.recursive ? "-p " : ""}${quote(path)}`);
    if (result.exitCode !== 0) throw new Error(result.stderr);
  }

  async rm(path: string, options?: { recursive?: boolean; force?: boolean }): Promise<void> {
    const flags = `${options?.recursive ? "r" : ""}${options?.force ? "f" : ""}`;
    const result = await this.exec(`rm ${flags ? `-${flags} ` : ""}${quote(path)}`);
    if (result.exitCode !== 0) throw new Error(result.stderr);
  }
}

export function dockerSandbox(container: string): SandboxFactory {
  if (!/^[A-Za-z0-9_.-]+$/.test(container)) {
    throw new Error(`Invalid Docker container name: ${container}`);
  }
  return {
    async createSessionEnv(): Promise<SessionEnv> {
      return createSandboxSessionEnv(new DockerSandboxApi(container), "/workspace");
    },
  };
}
