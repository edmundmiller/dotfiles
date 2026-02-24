import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { resolve } from "node:path";
import type { Task, TaskStatus } from "../../models/task.ts";
import type {
  CreateTaskInput,
  TaskAdapter,
  TaskAdapterInitializer,
  TaskStatusMap,
  TaskUpdate,
} from "../api.ts";

const MAX_LIST_RESULTS = 100;
const STATUS_MAP = {
  open: "open",
  inProgress: "in_progress",
  blocked: "blocked",
  deferred: "deferred",
  closed: "closed",
} satisfies TaskStatusMap;
const TASK_TYPES = ["task", "feature", "bug", "chore", "epic"];
const PRIORITIES = ["p0", "p1", "p2", "p3", "p4"];
const PRIORITY_HOTKEYS: Record<string, string> = {
  "0": "p0",
  "1": "p1",
  "2": "p2",
  "3": "p3",
  "4": "p4",
};

function makeListArgs(status: string): string[] {
  return ["list", "--status", status, "--limit", String(MAX_LIST_RESULTS), "--json"];
}

interface BeadsIssue {
  id: string;
  title: string;
  description?: string;
  status: string;
  priority?: number;
  issue_type?: string;
  owner?: string;
  created_at?: string;
  due_at?: string;
  due?: string;
  updated_at?: string;
  dependency_count?: number;
  dependent_count?: number;
  comment_count?: number;
}

function toPriorityLabel(value: number | undefined): string | undefined {
  if (value === undefined) return undefined;
  const label = `p${value}`;
  return PRIORITIES.includes(label) ? label : undefined;
}

function toPriorityValue(label: string | undefined): number | undefined {
  if (!label) return undefined;
  const match = label.toLowerCase().match(/^p(\d)$/);
  if (!match) return undefined;
  return Number(match[1]);
}

function toRequiredPriorityValue(label: string): number {
  const value = toPriorityValue(label);
  if (value === undefined) {
    throw new Error(`Unsupported priority for beads backend: ${label}`);
  }
  return value;
}

function fromBackendStatus(status: string): TaskStatus {
  for (const [internalStatus, backendStatus] of Object.entries(STATUS_MAP)) {
    if (backendStatus === status) return internalStatus as TaskStatus;
  }
  return "open";
}

function toBackendStatus(status: TaskStatus): string {
  const mapped = STATUS_MAP[status];
  if (!mapped) throw new Error(`Unsupported status for beads backend: ${status}`);
  return mapped;
}

function toTask(beadsIssue: BeadsIssue): Task {
  const task: Task = {
    ref: beadsIssue.id,
    id: beadsIssue.id,
    title: beadsIssue.title,
    description: beadsIssue.description ?? "",
    status: fromBackendStatus(beadsIssue.status),
    owner: beadsIssue.owner,
    priority: toPriorityLabel(beadsIssue.priority),
  };

  if (beadsIssue.issue_type !== undefined) task.taskType = beadsIssue.issue_type;
  if (beadsIssue.created_at !== undefined) task.createdAt = beadsIssue.created_at;
  if (beadsIssue.due_at !== undefined) task.dueAt = beadsIssue.due_at;
  if (beadsIssue.due !== undefined) task.dueAt = beadsIssue.due;
  if (beadsIssue.updated_at !== undefined) task.updatedAt = beadsIssue.updated_at;
  if (beadsIssue.dependency_count !== undefined) task.dependencyCount = beadsIssue.dependency_count;
  if (beadsIssue.dependent_count !== undefined) task.dependentCount = beadsIssue.dependent_count;
  if (beadsIssue.comment_count !== undefined) task.commentCount = beadsIssue.comment_count;

  return task;
}

function taskStatusSortRank(status: Task["status"]): number {
  if (status === "inProgress") return 0;
  if (status === "open") return 1;
  if (status === "blocked") return 2;
  return 3;
}

function taskPrioritySortRank(priority: string | undefined): number {
  if (!priority) return PRIORITIES.length + 1;
  const index = PRIORITIES.indexOf(priority);
  return index >= 0 ? index : PRIORITIES.length;
}

function sortActiveTasks(tasks: Task[]): Task[] {
  return [...tasks].sort((left, right) => {
    const statusOrder = taskStatusSortRank(left.status) - taskStatusSortRank(right.status);
    if (statusOrder !== 0) return statusOrder;

    const priorityOrder =
      taskPrioritySortRank(left.priority) - taskPrioritySortRank(right.priority);
    if (priorityOrder !== 0) return priorityOrder;

    return left.ref.localeCompare(right.ref);
  });
}

function fromTaskUpdateToBeadsArgs(update: TaskUpdate): string[] {
  const args: string[] = [];

  if (update.title !== undefined) {
    args.push("--title", update.title.trim());
  }

  if (update.description !== undefined) {
    args.push("--description", update.description);
  }

  if (update.status !== undefined) {
    args.push("--status", toBackendStatus(update.status));
  }

  if (update.priority !== undefined) {
    args.push("--priority", String(toRequiredPriorityValue(update.priority)));
  }

  if (update.taskType !== undefined) {
    args.push("--type", update.taskType || TASK_TYPES[0]);
  }

  if (update.dueAt !== undefined) {
    args.push("--due", update.dueAt);
  }

  return args;
}

function parseJsonArray<T>(stdout: string, context: string): T[] {
  try {
    const parsed = JSON.parse(stdout);
    if (!Array.isArray(parsed)) throw new Error("expected JSON array");
    return parsed as T[];
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new Error(`Failed to parse bd output (${context}): ${msg}`);
  }
}

function parseJsonObject<T>(stdout: string, context: string): T {
  try {
    const parsed = JSON.parse(stdout);
    if (parsed === null || Array.isArray(parsed) || typeof parsed !== "object") {
      throw new Error("expected JSON object");
    }
    return parsed as T;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new Error(`Failed to parse bd output (${context}): ${msg}`);
  }
}

function isApplicable(): boolean {
  if (!existsSync(resolve(process.cwd(), ".beads"))) return false;

  const result = spawnSync("bd", ["--version"], {
    stdio: "ignore",
  });

  return !result.error;
}

function initialize(pi: ExtensionAPI): TaskAdapter {
  async function execBd(args: string[], timeout = 30_000): Promise<string> {
    const result = await pi.exec("bd", args, { timeout });
    if (result.code !== 0) {
      const details = (result.stderr || result.stdout || "").trim();
      throw new Error(
        details.length > 0 ? details : `bd ${args.join(" ")} failed (code ${result.code})`
      );
    }
    return result.stdout;
  }

  async function update(ref: string, update: TaskUpdate): Promise<void> {
    const args = fromTaskUpdateToBeadsArgs(update);
    if (args.length === 0) return;

    await execBd(["update", ref, ...args]);
  }

  return {
    id: "beads",
    statusMap: STATUS_MAP,
    taskTypes: TASK_TYPES,
    priorities: PRIORITIES,
    priorityHotkeys: PRIORITY_HOTKEYS,

    async list(): Promise<Task[]> {
      // Sequential — bd uses dolt, which panics on concurrent DB access
      const openOut = await execBd(makeListArgs(STATUS_MAP.open));
      const inProgressOut = await execBd(makeListArgs(STATUS_MAP.inProgress!));
      const blockedOut = await execBd(makeListArgs(STATUS_MAP.blocked!));

      const openIssues = parseJsonArray<BeadsIssue>(openOut, "list open");
      const inProgressIssues = parseJsonArray<BeadsIssue>(inProgressOut, "list in_progress");
      const blockedIssues = parseJsonArray<BeadsIssue>(blockedOut, "list blocked");

      const dedupedById = new Map<string, Task>();
      for (const issue of [...inProgressIssues, ...openIssues, ...blockedIssues]) {
        dedupedById.set(issue.id, toTask(issue));
      }

      return sortActiveTasks([...dedupedById.values()]).slice(0, MAX_LIST_RESULTS);
    },

    async show(ref: string): Promise<Task> {
      const out = await execBd(["show", ref, "--json"]);
      const beadsIssues = parseJsonArray<BeadsIssue>(out, `show ${ref}`);
      const task = beadsIssues[0];
      if (!task) throw new Error(`Task not found: ${ref}`);
      return toTask(task);
    },

    update,

    async create(input: CreateTaskInput): Promise<Task> {
      const title = input.title.trim();
      const status = input.status ?? "open";
      const selectedPriority = input.priority ?? PRIORITIES[Math.floor(PRIORITIES.length / 2)];
      const createArgs = [
        "create",
        "--title",
        title,
        "--priority",
        String(toRequiredPriorityValue(selectedPriority)),
        "--type",
        input.taskType || TASK_TYPES[0],
        "--json",
      ];

      if (input.description && input.description.length > 0) {
        createArgs.splice(3, 0, "--description", input.description);
      }

      if (input.dueAt && input.dueAt.length > 0) {
        createArgs.splice(3, 0, "--due", input.dueAt);
      }

      const out = await execBd(createArgs);
      const created = toTask(parseJsonObject<BeadsIssue>(out, "create"));

      if (status !== "open") {
        await update(created.ref, { status });
        created.status = status;
      }

      created.title = title;
      created.description = input.description ?? "";

      if (input.priority !== undefined) {
        created.priority = input.priority;
      }

      if (input.taskType !== undefined) {
        created.taskType = input.taskType;
      }

      if (input.dueAt !== undefined) {
        created.dueAt = input.dueAt;
      }

      return created;
    },
  };
}

export default {
  id: "beads",
  isApplicable,
  initialize,
} satisfies TaskAdapterInitializer;
