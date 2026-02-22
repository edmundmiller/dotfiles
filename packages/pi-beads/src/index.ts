import type { ExtensionAPI } from "@mariozechner/pi-coding-agent"

import registerExtension from "./extension.ts"

export default function (pi: ExtensionAPI) {
  registerExtension(pi)
}
