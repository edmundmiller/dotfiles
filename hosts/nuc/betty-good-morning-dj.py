import asyncio
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from urllib.parse import urlparse



def env(*names: str, default: str = "") -> str:
    for name in names:
        value = (os.environ.get(name) or "").strip()
        if value:
            return value
    return default


def ha_call(path: str, data=None):
    token = env("HA_TOKEN", "HASS_TOKEN")
    base = env("HASS_URL", "HA_URL", default="http://127.0.0.1:8123").rstrip("/")
    body = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(
        f"{base}{path}",
        data=body,
        method="GET" if data is None else "POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode(errors="replace")


def media_key(uri: str | None, kind: str | None = None) -> str | None:
    if not uri:
        return None
    u = str(uri).strip()
    m = re.search(r"spotify:(track|playlist):([A-Za-z0-9]+)", u)
    if m:
        key = f"{m.group(1)}:{m.group(2)}"
    else:
        m = re.search(r"spotify--[^:/]+://(track|playlist)/([A-Za-z0-9]+)", u)
        if m:
            key = f"{m.group(1)}:{m.group(2)}"
        else:
            m = re.search(r"open\.spotify\.com/(track|playlist)/([A-Za-z0-9]+)", u)
            if not m:
                return None
            key = f"{m.group(1)}:{m.group(2)}"
    if kind and not key.startswith(f"{kind}:"):
        return None
    return key


def track_key(uri: str | None) -> str | None:
    return media_key(uri, "track")


def playlist_key(uri: str | None) -> str | None:
    return media_key(uri, "playlist")


def via_ma(source, content_id, provider) -> bool:
    source_l = (source or "").lower()
    content_l = (content_id or "").lower()
    provider_l = (provider or "").lower()
    if "music assistant" in source_l:
        return True
    if provider_l.startswith("spotify") or "music_assistant" in provider_l:
        return True
    return content_l.startswith("spotify--") or content_l.startswith("library://")


class MassClient:
    def __init__(self):
        self.token = env("MUSIC_ASSISTANT_TOKEN")
        if not self.token:
            raise SystemExit("betty good-morning-dj: MUSIC_ASSISTANT_TOKEN missing")
        base = env("MUSIC_ASSISTANT_URL", default="http://127.0.0.1:8095").rstrip("/")
        parsed = urlparse(base)
        scheme = "wss" if parsed.scheme == "https" else "ws"
        host = parsed.hostname or "127.0.0.1"
        port = parsed.port or (443 if scheme == "wss" else 80)
        self.ws_url = f"{scheme}://{host}:{port}/ws"
        self._mid = 0
        self._ws = None

    async def __aenter__(self):
        import websockets

        self._ws = await websockets.connect(self.ws_url, open_timeout=10, max_size=8_000_000)
        await self._ws.recv()  # hello
        auth = await self.cmd("auth", token=self.token)
        if auth.get("error_code") is not None:
            raise SystemExit(f"betty good-morning-dj: MA auth failed: {auth.get('details')}")
        return self

    async def __aexit__(self, *exc):
        if self._ws is not None:
            await self._ws.close()

    async def cmd(self, command: str, **args):
        assert self._ws is not None
        self._mid += 1
        mid = str(self._mid)
        msg = {"message_id": mid, "command": command}
        if args:
            msg["args"] = args
        await self._ws.send(json.dumps(msg))
        while True:
            raw = await asyncio.wait_for(self._ws.recv(), timeout=30)
            data = json.loads(raw)
            if data.get("message_id") == mid:
                return data

    async def kitchen_queue_id(self) -> str:
        for entity_id in PLAYERS:
            code, resp = ha_call(
                "/api/services/music_assistant/get_queue?return_response",
                {"entity_id": entity_id},
            )
            if code != 200 or not isinstance(resp, dict):
                continue
            qid = ((resp.get("service_response") or {}).get(entity_id) or {}).get("queue_id")
            if qid:
                return qid
        raise SystemExit(
            "betty good-morning-dj: could not resolve Kitchen MA queue_id "
            f"from {', '.join(PLAYERS)}"
        )

    async def queue_items(self, queue_id: str) -> list:
        meta = (await self.cmd("player_queues/get", queue_id=queue_id)).get("result") or {}
        total = int(meta.get("items") or 0)
        items: list = []
        offset = 0
        page = 100
        # Page through the full reported count (bounded), not a hard 200 cap.
        while offset < max(total, page) and offset < 5000:
            resp = await self.cmd(
                "player_queues/items", queue_id=queue_id, limit=page, offset=offset
            )
            chunk = resp.get("result") or []
            if not isinstance(chunk, list) or not chunk:
                break
            items.extend(chunk)
            offset += len(chunk)
            if len(chunk) < page or (total and offset >= total):
                break
        return items

    def playlist_lookup_parts(self, playlist_uri: str) -> tuple[str, str]:
        """Return (item_id, provider_instance_id_or_domain) for a receipt playlist URI."""
        u = str(playlist_uri).strip()
        m = re.search(r"spotify--([^:/]+)://playlist/([A-Za-z0-9]+)", u)
        if m:
            return m.group(2), m.group(1)
        m = re.search(r"spotify:playlist:([A-Za-z0-9]+)", u)
        if m:
            return m.group(1), "spotify"
        m = re.search(r"open\.spotify\.com/playlist/([A-Za-z0-9]+)", u)
        if m:
            return m.group(1), "spotify"
        raise SystemExit(f"betty good-morning-dj: cannot parse playlist uri: {playlist_uri!r}")

    async def resolve_exact_playlist(self, name: str, receipt_playlist_uri: str, receipt_playlist_key: str) -> dict:
        item_id, provider = self.playlist_lookup_parts(receipt_playlist_uri)
        # Prefer the provider instance encoded in MA URIs; fall back to domain "spotify".
        providers = [provider]
        if provider != "spotify":
            providers.append("spotify")
        last_err = None
        for prov in providers:
            meta = await self.cmd(
                "music/playlists/get_playlist",
                item_id=item_id,
                provider_instance_id_or_domain=prov,
            )
            if meta.get("error_code") is not None:
                last_err = meta.get("details")
                continue
            resolved = meta.get("result") or {}
            resolved_name = (resolved.get("name") or "").strip()
            if resolved_name != name:
                raise SystemExit(
                    f"betty good-morning-dj: receipt playlist resolves to {resolved_name!r}, not {name!r}"
                )
            resolved_key = playlist_key(resolved.get("uri"))
            if resolved_key != receipt_playlist_key:
                raise SystemExit(
                    "betty good-morning-dj: resolved playlist URI mismatch "
                    f"({receipt_playlist_key} != {resolved_key})"
                )
            if not resolved.get("item_id"):
                resolved["item_id"] = item_id
            if not resolved.get("provider"):
                resolved["provider"] = prov
            return resolved
        raise SystemExit(
            f"betty good-morning-dj: MA playlist lookup failed for receipt URI: {last_err!r}"
        )

    async def playlist_track_keys(self, playlist: dict) -> set[str]:
        item_id = playlist.get("item_id")
        provider = playlist.get("provider")
        if not item_id or not provider:
            raise SystemExit("betty good-morning-dj: playlist missing item_id/provider")
        tracks_resp = await self.cmd(
            "music/playlists/playlist_tracks",
            item_id=item_id,
            provider_instance_id_or_domain=provider,
        )
        if tracks_resp.get("error_code") is not None:
            raise SystemExit(
                f"betty good-morning-dj: MA playlist tracks failed: {tracks_resp.get('details')!r}"
            )
        tracks = tracks_resp.get("result") or []
        keys: set[str] = set()
        for track in tracks:
            if not isinstance(track, dict):
                continue
            key = track_key(track.get("uri"))
            if key:
                keys.add(key)
        if not keys:
            raise SystemExit("betty good-morning-dj: resolved Good Morning playlist has no tracks")
        return keys


PLAYERS = ["media_player.kitchen_2", "media_player.kitchen"]


async def prepare() -> None:
    if not env("HA_TOKEN", "HASS_TOKEN"):
        raise SystemExit("betty good-morning-dj: HA_TOKEN/HASS_TOKEN missing before oneshot")
    status, _ = ha_call("/api/services/media_player/media_stop", {"entity_id": PLAYERS})
    if status >= 300:
        raise SystemExit(f"betty good-morning-dj: failed to stop Kitchen (HTTP {status})")
    async with MassClient() as mass:
        qid = await mass.kitchen_queue_id()
        await mass.cmd("player_queues/clear", queue_id=qid)
        print(f"betty good-morning-dj: cleared MA queue {qid}")
    deadline = time.time() + 20
    while time.time() < deadline:
        idle = True
        for entity_id in PLAYERS:
            code, state = ha_call(f"/api/states/{entity_id}")
            if code != 200 or not isinstance(state, dict) or state.get("state") == "playing":
                idle = False
                break
        if idle:
            print("betty good-morning-dj: Kitchen players idle")
            return
        time.sleep(1)
    raise SystemExit("betty good-morning-dj: Kitchen did not become idle before oneshot")


def parse_receipt(raw: str) -> dict:
    raw = (raw or "").strip()
    if not raw:
        raise SystemExit("betty good-morning-dj: empty oneshot receipt")
    try:
        data = json.loads(raw)
        if isinstance(data, dict):
            return data
    except json.JSONDecodeError:
        pass
    for match in reversed(list(re.finditer(r"\{.*\}", raw, flags=re.S))):
        try:
            data = json.loads(match.group(0))
        except json.JSONDecodeError:
            continue
        if isinstance(data, dict):
            return data
    print(raw[:500], file=sys.stderr)
    raise SystemExit("betty good-morning-dj: oneshot receipt is not JSON")


def assert_queue_matches_playlist(needed: list[str], queue_keys: set[str], playlist_keys: set[str]) -> None:
    """Pure postcondition used by verify and the offline self-check."""
    missing = [key for key in needed if key not in queue_keys]
    if missing:
        raise SystemExit(
            "betty good-morning-dj: receipt tracks not present in MA queue: " + ", ".join(missing)
        )
    non_added = sorted(queue_keys - set(needed))
    if not non_added:
        raise SystemExit(
            "betty good-morning-dj: MA queue has only the five added tracks; "
            "exact Good Morning playlist content is missing"
        )
    foreign = [key for key in non_added if key not in playlist_keys]
    if foreign:
        raise SystemExit(
            "betty good-morning-dj: non-added queue tracks are not from exact Good Morning playlist: "
            + ", ".join(foreign)
        )


async def verify(receipt_path: str) -> None:
    with open(receipt_path, encoding="utf-8") as fh:
        receipt = parse_receipt(fh.read())
    if not receipt.get("ok"):
        raise SystemExit(f"betty good-morning-dj: agent reported failure: {receipt.get('error')!r}")
    playlist = (receipt.get("playlist") or "").strip()
    if playlist != "Good Morning":
        raise SystemExit(f"betty good-morning-dj: receipt playlist {playlist!r} != 'Good Morning'")
    receipt_playlist_key = playlist_key(receipt.get("playlist_uri"))
    if not receipt_playlist_key:
        raise SystemExit("betty good-morning-dj: receipt playlist_uri missing/invalid")
    added = receipt.get("added_uris") or []
    if not isinstance(added, list) or len(added) != 5:
        raise SystemExit(f"betty good-morning-dj: receipt needs exactly 5 added_uris, got {added!r}")
    needed = []
    for uri in added:
        key = track_key(str(uri))
        if not key:
            raise SystemExit(f"betty good-morning-dj: added uri not a track: {uri!r}")
        if key not in needed:
            needed.append(key)
    if len(needed) != 5:
        raise SystemExit(
            f"betty good-morning-dj: receipt needs exactly 5 distinct track uris, got {needed!r}"
        )

    if not env("HA_TOKEN", "HASS_TOKEN"):
        raise SystemExit("betty good-morning-dj: HA_TOKEN/HASS_TOKEN missing after oneshot")

    playing_entity = None
    current_track = None
    for entity_id in PLAYERS:
        code, state = ha_call(f"/api/states/{entity_id}")
        if code != 200 or not isinstance(state, dict) or state.get("state") != "playing":
            continue
        attrs = state.get("attributes") or {}
        qcode, qresp = ha_call(
            "/api/services/music_assistant/get_queue?return_response",
            {"entity_id": entity_id},
        )
        provider = None
        content_id = attrs.get("media_content_id")
        current_uri = None
        if qcode == 200 and isinstance(qresp, dict):
            queue = ((qresp.get("service_response") or {}).get(entity_id) or {})
            current = queue.get("current_item") or {}
            provider = (current.get("stream_details") or {}).get("provider")
            current_uri = ((current.get("media_item") or {}).get("uri")) or None
            content_id = current_uri or content_id
        if via_ma(attrs.get("source"), content_id, provider):
            playing_entity = entity_id
            current_track = track_key(current_uri) or track_key(content_id)
            break
    if not playing_entity:
        raise SystemExit("betty good-morning-dj: Kitchen not playing via Music Assistant")

    async with MassClient() as mass:
        resolved = await mass.resolve_exact_playlist(
            "Good Morning",
            str(receipt.get("playlist_uri")),
            receipt_playlist_key,
        )
        playlist_keys = await mass.playlist_track_keys(resolved)
        qid = await mass.kitchen_queue_id()
        items = await mass.queue_items(qid)

    queue_keys: set[str] = set()
    if current_track:
        queue_keys.add(current_track)
    for item in items:
        media = item.get("media_item") or {}
        key = track_key(media.get("uri"))
        if key:
            queue_keys.add(key)

    assert_queue_matches_playlist(needed, queue_keys, playlist_keys)

    print(
        "betty good-morning-dj: verified exact Good Morning playlist + receipt tracks "
        f"on {playing_entity} (playlist_uri={receipt_playlist_key}, added={len(needed)}, "
        f"queue_items={len(items)}, playlist_tracks={len(playlist_keys)})"
    )


def selfcheck() -> None:
    # Red path: five added tracks alone must not pass without playlist base content.
    needed = [f"track:a{i}" for i in range(5)]
    playlist_keys = {f"track:p{i}" for i in range(10)}
    try:
        assert_queue_matches_playlist(needed, set(needed), playlist_keys)
    except SystemExit:
        pass
    else:
        raise SystemExit("selfcheck: expected failure when queue is only added tracks")

    # Red path: foreign non-added track must not pass.
    try:
        assert_queue_matches_playlist(
            needed,
            set(needed) | {"track:foreign"},
            playlist_keys,
        )
    except SystemExit:
        pass
    else:
        raise SystemExit("selfcheck: expected failure on foreign non-added track")

    # Green path: playlist base + five adds.
    assert_queue_matches_playlist(
        needed,
        set(needed) | {"track:p0", "track:p1"},
        playlist_keys,
    )
    if playlist_key("spotify:playlist:abc123") != "playlist:abc123":
        raise SystemExit("selfcheck: playlist_key failed")
    if track_key("spotify--x://track/zzz") != "track:zzz":
        raise SystemExit("selfcheck: track_key failed")
    # playlist_lookup_parts is pure enough via a dummy instance __new__
    client = MassClient.__new__(MassClient)
    item_id, provider = client.playlist_lookup_parts("spotify:playlist:abc123")
    if (item_id, provider) != ("abc123", "spotify"):
        raise SystemExit(f"selfcheck: spotify playlist parse failed: {(item_id, provider)}")
    item_id, provider = client.playlist_lookup_parts("spotify--inst://playlist/xyz789")
    if (item_id, provider) != ("xyz789", "inst"):
        raise SystemExit(f"selfcheck: ma playlist parse failed: {(item_id, provider)}")
    print("betty good-morning-dj: selfcheck ok")


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: betty-good-morning-dj.py prepare|verify|selfcheck <receipt>", file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "prepare":
        asyncio.run(prepare())
        return 0
    if cmd == "verify":
        if len(argv) < 3:
            print("verify requires receipt path", file=sys.stderr)
            return 2
        asyncio.run(verify(argv[2]))
        return 0
    if cmd == "selfcheck":
        selfcheck()
        return 0
    print(f"unknown command: {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
