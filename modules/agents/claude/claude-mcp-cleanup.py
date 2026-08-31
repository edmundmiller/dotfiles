import json
import pathlib
import shutil
import sys


path = pathlib.Path(sys.argv[1])
try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception:
    data = {}

if not isinstance(data, dict):
    raise SystemExit(0)

server_names = ["code" + "graph", "agent-cards"]
servers = data.get("mcpServers")
changed = False
if isinstance(servers, dict):
    for server_name in server_names:
        if server_name in servers:
            servers.pop(server_name, None)
            changed = True
if changed:
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

plugin_root = path.parent / "plugins"
for context7_path in plugin_root.glob("**/*context7*"):
    if context7_path.is_dir():
        shutil.rmtree(context7_path, ignore_errors=True)
    else:
        context7_path.unlink(missing_ok=True)
