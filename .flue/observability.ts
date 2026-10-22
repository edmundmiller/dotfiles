import { initLogger, toLoggerConfig } from "evlog";
import { writeToFs } from "evlog/fs";
import { installFlueEvlog } from "flue-evlog";
import config from "./evlog.config";

export function installObservability(dir = process.env.FLUE_LOG_DIR ?? ".evlog/logs") {
  const telemetry = installFlueEvlog({
    service: "dotfiles-flue",
    drain: ({ event }) => writeToFs(event, { dir, pretty: false }),
    metadata: {
      repository: process.env.GITHUB_REPOSITORY,
      commit: process.env.FLUE_COMMIT,
      ciRun: process.env.GITHUB_RUN_ID,
      ciAttempt: process.env.GITHUB_RUN_ATTEMPT,
      pr: process.env.PR_NUMBER,
      target: process.env.TARGET,
    },
  });
  // Application logging policy is separate from unsampled model accounting.
  initLogger({ ...toLoggerConfig(config), drain: telemetry.drain });
  return telemetry;
}
