from __future__ import annotations

try:
    import tomllib as _tomllib
except ModuleNotFoundError:  # pragma: no cover - exercised on Python < 3.11
    try:
        import tomli as _tomllib
    except ModuleNotFoundError:  # pragma: no cover - fallback parser covers local fixtures
        _tomllib = None


def loads(text: str) -> dict:
    if _tomllib is not None:
        return _tomllib.loads(text)
    return _loads_minimal(text)


def _loads_minimal(text: str) -> dict:
    root: dict = {}
    current: dict = root
    lines = text.splitlines()
    index = 0

    while index < len(lines):
        raw_line = lines[index]
        line = raw_line.strip()
        index += 1
        if not line or line.startswith("#"):
            continue

        if line.startswith("[[") and line.endswith("]]"):
            table = _resolve_table(root, line[2:-2], array=True)
            current = table
            continue

        if line.startswith("[") and line.endswith("]"):
            current = _resolve_table(root, line[1:-1], array=False)
            continue

        key, value = line.split("=", 1)
        key = _unquote(key.strip())
        value = value.strip()
        if value == '"""':
            chunks = []
            while index < len(lines):
                next_line = lines[index]
                index += 1
                if next_line == '"""':
                    break
                chunks.append(next_line)
            current[key] = "\n".join(chunks) + "\n"
        else:
            current[key] = _parse_value(value)

    return root


def _resolve_table(root: dict, dotted: str, *, array: bool) -> dict:
    current = root
    parts = _split_dotted(dotted)
    for part in parts[:-1]:
        current = current.setdefault(part, {})
    leaf = parts[-1]
    if array:
        entries = current.setdefault(leaf, [])
        table: dict = {}
        entries.append(table)
        return table
    return current.setdefault(leaf, {})


def _split_dotted(value: str) -> list[str]:
    parts: list[str] = []
    token: list[str] = []
    in_string = False
    escape = False
    for char in value:
        if escape:
            token.append(char)
            escape = False
        elif char == "\\" and in_string:
            escape = True
        elif char == '"':
            in_string = not in_string
            token.append(char)
        elif char == "." and not in_string:
            parts.append(_unquote("".join(token).strip()))
            token = []
        else:
            token.append(char)
    parts.append(_unquote("".join(token).strip()))
    return parts


def _unquote(value: str) -> str:
    if value.startswith('"') and value.endswith('"'):
        return value[1:-1]
    return value


def _parse_value(value: str):
    if value == "true":
        return True
    if value == "false":
        return False
    if value.startswith('"') and value.endswith('"'):
        return value[1:-1]
    if value.startswith("[") and value.endswith("]"):
        body = value[1:-1].strip()
        if not body:
            return []
        return [_parse_value(part.strip()) for part in _split_array(body)]
    try:
        return int(value)
    except ValueError:
        return value


def _split_array(value: str) -> list[str]:
    parts: list[str] = []
    token: list[str] = []
    in_string = False
    escape = False
    for char in value:
        if escape:
            token.append(char)
            escape = False
        elif char == "\\" and in_string:
            escape = True
        elif char == '"':
            in_string = not in_string
            token.append(char)
        elif char == "," and not in_string:
            parts.append("".join(token))
            token = []
        else:
            token.append(char)
    if token:
        parts.append("".join(token))
    return parts
