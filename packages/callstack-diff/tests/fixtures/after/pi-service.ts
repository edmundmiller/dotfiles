// Fixture mirroring the "after" state of the reference call-stack diff.
import { createCodingTools } from "./tools.ts";

export class PiService {
  static async createAgentSession(options: { sessionId?: string }) {
    WorkspaceService.getLayout();
    const services = PiService.getServices();
    if (!options.sessionId) {
      SessionManager.create();
    } else {
      SessionManager.list();
      SessionManager.open();
    }
    return createAgentSession({ services });
  }

  static getServices() {
    AuthStorage.create();
    const registry = new ModelRegistry();
    SettingsManager.create();
    const loader = new DefaultResourceLoader();
    loader.reload();
    return createCodingTools();
  }
}

export function createAgentSession(input: unknown) {
  return input;
}

class ModelRegistry {}
class DefaultResourceLoader {
  reload() {}
}
const WorkspaceService = { getLayout() {} };
const AuthStorage = { create() {} };
const SettingsManager = { create() {} };
const SessionManager = { create() {}, list() {}, open() {} };
