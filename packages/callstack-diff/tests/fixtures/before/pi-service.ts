// Fixture mirroring the "before" state of the reference call-stack diff:
// services were constructed inline, before getServices() was extracted.
import { createCodingTools } from "./tools.ts";

export class PiService {
  static async createAgentSession(options: { sessionId?: string }) {
    WorkspaceService.getLayout();
    AuthStorage.create();
    const registry = new ModelRegistry();
    const services = createCodingTools();
    if (!options.sessionId) {
      SessionManager.create();
    } else {
      SessionManager.list();
      SessionManager.open();
    }
    return createAgentSession({ services });
  }
}

export function createAgentSession(input: unknown) {
  return input;
}

class ModelRegistry {}
const WorkspaceService = { getLayout() {} };
const AuthStorage = { create() {} };
const SessionManager = { create() {}, list() {}, open() {} };
