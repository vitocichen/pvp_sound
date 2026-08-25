#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Local PVP Sound voice-pack preview. Parse catalogs, serve Media/*.ogg."""

from __future__ import annotations

import json
import os
import re
import sys
import threading
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import URLError
from urllib.parse import unquote
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
MEDIA = ROOT / "Media"
HERE = Path(__file__).resolve().parent
CACHE = HERE / "cache"
NAME_CACHE = CACHE / "spell-meta.json"
PORT = int(os.environ.get("PVP_SOUND_PREVIEW_PORT", "18080"))

CLASS_ZH = {
    "General": "通用",
    "DeathKnight": "死亡骑士",
    "DemonHunter": "恶魔猎手",
    "Druid": "德鲁伊",
    "Evoker": "唤魔师",
    "Hunter": "猎人",
    "Mage": "法师",
    "Monk": "武僧",
    "Paladin": "圣骑士",
    "Priest": "牧师",
    "Rogue": "潜行者",
    "Shaman": "萨满祭司",
    "Warlock": "术士",
    "Warrior": "战士",
    "Other": "其他",
}

CLASS_ORDER = [
    "General",
    "DeathKnight",
    "DemonHunter",
    "Druid",
    "Evoker",
    "Hunter",
    "Mage",
    "Monk",
    "Paladin",
    "Priest",
    "Rogue",
    "Shaman",
    "Warlock",
    "Warrior",
    "Other",
]

PACK_LABELS = {
    "夏一可": "夏一可",
    "夏一可1.25x": "夏一可 1.25x",
    "夏一可1.5x": "夏一可 1.5x",
    "晓晓": "晓晓",
    "晓晓1.25x": "晓晓 1.25x",
    "晓晓1.5x": "晓晓 1.5x",
    "英语女声": "英语女声",
    "英语女声1.25x": "英语女声 1.25x",
    "英语女声1.5x": "英语女声 1.5x",
}

EXTRA_LABELS = {
    "HealerCcAlert.ogg": "治疗被控",
    "interrupted.ogg": "打断成功",
}

ID_FILE_RE = re.compile(r"\{\s*Id\s*=\s*(\d+)\s*,\s*File\s*=\s*\"([^\"]+)\"")
LABEL_RE = re.compile(r"Label\s*=\s*\"([^\"]+)\"")
NAME_RE = re.compile(r"Name\s*=\s*\"([^\"]+)\"")
CLASS_RE = re.compile(
    r"\{\s*Key\s*=\s*\"([^\"]+)\"\s*,\s*Name\s*=\s*\"([^\"]+)\"\s*,\s*Spells\s*=\s*\{",
    re.S,
)
COMMENT_ZH_RE = re.compile(r"--\s*([\u4e00-\u9fff][^/\n]*)")
COMMENT_EN_RE = re.compile(r"--\s*([A-Za-z][^/\n]*)")


def extract_table(text: str, open_brace: int) -> tuple[str, int]:
    """Return substring of the `{ ... }` table starting at open_brace, and end index."""
    depth = 0
    i = open_brace
    n = len(text)
    in_str = False
    while i < n:
        ch = text[i]
        if in_str:
            if ch == "\\" and i + 1 < n:
                i += 2
                continue
            if ch == '"':
                in_str = False
            i += 1
            continue
        if ch == '"':
            in_str = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[open_brace : i + 1], i + 1
        i += 1
    return text[open_brace:], n


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def parse_class_catalog(path: Path, mode: str) -> list[dict]:
    text = read_text(path)
    starts = list(CLASS_RE.finditer(text))
    classes = []
    for i, m in enumerate(starts):
        end = starts[i + 1].start() if i + 1 < len(starts) else len(text)
        block = text[m.end() : end]
        spells = []
        pos = 0
        while True:
            sm = ID_FILE_RE.search(block, pos)
            if not sm:
                break
            table, nxt = extract_table(block, sm.start())
            pos = nxt
            line_tail = block[nxt : block.find("\n", nxt) if block.find("\n", nxt) >= 0 else nxt]
            snippet = table + " " + line_tail
            lm = LABEL_RE.search(table)
            nm = NAME_RE.search(table)
            zh_c = COMMENT_ZH_RE.search(snippet)
            en_c = COMMENT_EN_RE.search(snippet)
            spells.append(
                {
                    "id": int(sm.group(1)),
                    "file": sm.group(2),
                    "label": lm.group(1) if lm else None,
                    "name": nm.group(1) if nm else None,
                    "commentZh": zh_c.group(1).strip() if zh_c else None,
                    "commentEn": en_c.group(1).strip() if en_c else None,
                    "mode": mode,
                }
            )
        classes.append(
            {
                "key": m.group(1),
                "name": m.group(2),
                "spells": spells,
            }
        )
    return classes


def parse_consumables(path: Path) -> list[dict]:
    text = read_text(path)
    out = []
    for m in re.finditer(
        r"\{\s*zh\s*=\s*\"([^\"]+)\"\s*,\s*en\s*=\s*\"([^\"]+)\"[^}]*file\s*=\s*\"([^\"]+)\"",
        text,
    ):
        out.append(
            {
                "id": 0,
                "file": m.group(3),
                "label": m.group(1),
                "name": m.group(2),
                "commentZh": m.group(1),
                "commentEn": m.group(2),
                "mode": "consumable",
            }
        )
    return out


def parse_manifest(path: Path) -> list[str]:
    text = read_text(path)
    return re.findall(r"\"([^\"]+)\"", text)


def dedupe(spells: list[dict]) -> list[dict]:
    order = []
    by_file: dict[str, dict] = {}
    for sp in spells:
        key = sp["file"] or f"id:{sp['id']}"
        group = by_file.get(key)
        if not group:
            group = {
                "id": sp["id"],
                "file": sp["file"],
                "label": sp.get("label"),
                "name": sp.get("name"),
                "commentZh": sp.get("commentZh"),
                "commentEn": sp.get("commentEn"),
                "modes": [],
                "ids": [],
            }
            by_file[key] = group
            order.append(group)
        mode = sp.get("mode") or "enemy"
        if mode not in group["modes"]:
            group["modes"].append(mode)
        if mode == "selfcc":
            group["id"] = sp["id"]
        if sp.get("label") and not group.get("label"):
            group["label"] = sp["label"]
        if sp.get("name") and not group.get("name"):
            group["name"] = sp["name"]
        if sp.get("commentZh") and not group.get("commentZh"):
            group["commentZh"] = sp["commentZh"]
        sid = sp["id"]
        if sid and sid not in group["ids"]:
            group["ids"].append(sid)
    return order


def list_packs() -> list[str]:
    manifest_path = ROOT / "Data" / "VoicePackManifest.lua"
    names = parse_manifest(manifest_path) if manifest_path.exists() else []
    if MEDIA.exists():
        for p in sorted(MEDIA.iterdir(), key=lambda x: x.name):
            if p.is_dir() and not p.name.startswith("_") and p.name not in names:
                names.append(p.name)
    return [n for n in names if (MEDIA / n).is_dir()]


def pack_files(pack: str) -> set[str]:
    folder = MEDIA / pack
    if not folder.is_dir():
        return set()
    return {f.name for f in folder.iterdir() if f.suffix.lower() in {".ogg", ".mp3"}}


def load_name_cache() -> dict:
    if NAME_CACHE.exists():
        try:
            return json.loads(NAME_CACHE.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {}
    return {}


def save_name_cache(data: dict) -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    NAME_CACHE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def fetch_wowhead(spell_id: int) -> dict | None:
    url = f"https://nether.wowhead.com/tooltip/spell/{spell_id}?locale=4"
    req = Request(url, headers={"User-Agent": "PVP-Sound-voice-preview/1.0"})
    try:
        with urlopen(req, timeout=8) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
        data = json.loads(raw)
        name = data.get("name")
        icon = data.get("icon")
        if not name:
            return None
        return {"zh": name, "icon": icon}
    except (URLError, TimeoutError, json.JSONDecodeError, OSError, ValueError):
        return None


def enrich_names(spells: list[dict], cache: dict) -> None:
    missing = []
    seen = set()
    for sp in spells:
        sid = sp.get("id") or 0
        if not sid or sid in seen:
            continue
        seen.add(sid)
        if str(sid) not in cache:
            missing.append(sid)
    if not missing:
        return
    print(f"Fetching {len(missing)} spell names from Wowhead (zhCN)…", flush=True)
    lock = threading.Lock()

    def work(sid: int) -> None:
        meta = fetch_wowhead(sid)
        if not meta:
            return
        with lock:
            cache[str(sid)] = meta

    threads = []
    for sid in missing:
        t = threading.Thread(target=work, args=(sid,), daemon=True)
        threads.append(t)
        t.start()
        if len(threads) >= 8:
            for t in threads:
                t.join()
            threads = []
    for t in threads:
        t.join()
    save_name_cache(cache)
    print("Spell-name cache updated.", flush=True)


def display_name(sp: dict, cache: dict) -> str:
    if sp.get("label"):
        return sp["label"]
    if sp.get("commentZh"):
        return re.split(r"[（(]", sp["commentZh"], 1)[0].strip()
    meta = cache.get(str(sp["id"])) or {}
    if meta.get("zh"):
        return meta["zh"]
    if sp.get("name"):
        return sp["name"]
    if sp.get("commentEn"):
        return sp["commentEn"].split("(")[0].strip()
    stem = Path(sp["file"]).stem
    return stem


def icon_url(sp: dict, cache: dict) -> str | None:
    meta = cache.get(str(sp["id"])) or {}
    icon = meta.get("icon")
    if icon:
        return f"https://wow.zamimg.com/images/wow/icons/small/{icon}.jpg"
    return None


def build_index() -> dict:
    enemy = parse_class_catalog(ROOT / "Data" / "EnemyBuffCatalog.lua", "enemy")
    selfcc = parse_class_catalog(ROOT / "Data" / "SelfCcCatalog.lua", "selfcc")
    consumables = parse_consumables(ROOT / "Data" / "Consumables.lua")

    by_key: dict[str, dict] = {}

    def ensure(key: str, name: str) -> dict:
        if key not in by_key:
            by_key[key] = {"key": key, "name": name, "zh": CLASS_ZH.get(key, name), "spells": []}
        return by_key[key]

    for src in enemy + selfcc:
        entry = ensure(src["key"], src["name"])
        entry["spells"].extend(src["spells"])

    general = ensure("General", "General")
    general["spells"].extend(consumables)

    packs = list_packs()
    files_by_pack = {p: pack_files(p) for p in packs}
    all_media_files: set[str] = set()
    for fs in files_by_pack.values():
        all_media_files |= fs

    catalog_files = set()
    for entry in by_key.values():
        entry["spells"] = dedupe(entry["spells"])
        for sp in entry["spells"]:
            catalog_files.add(sp["file"])

    all_spells = []
    for key in CLASS_ORDER:
        if key in by_key:
            all_spells.extend(by_key[key]["spells"])

    cache = load_name_cache()
    enrich_names(all_spells, cache)

    file_title = {
        sp["file"].lower(): display_name(sp, cache)
        for entry in by_key.values()
        for sp in entry["spells"]
    }

    extras = []
    for fname in sorted(all_media_files, key=str.lower):
        if fname in catalog_files:
            continue
        stem = Path(fname).stem
        label = EXTRA_LABELS.get(fname)
        low = fname.lower()
        keep = fname in EXTRA_LABELS
        if low.endswith("down.ogg"):
            base = fname[:-8] + ".ogg"
            parent = file_title.get(base.lower())
            if parent:
                label = f"{parent}（结束）"
                keep = True
        if not keep:
            continue
        extras.append(
            {
                "id": 0,
                "file": fname,
                "label": label,
                "name": stem,
                "commentZh": label,
                "commentEn": stem,
                "modes": ["extra"],
                "ids": [],
            }
        )
    if extras:
        other = ensure("Other", "Other")
        other["spells"] = extras

    classes = []
    for key in CLASS_ORDER:
        entry = by_key.get(key)
        if not entry or not entry["spells"]:
            continue
        buffs, ccs, pots, extra = [], [], [], []
        for sp in entry["spells"]:
            row = {
                "id": sp["id"],
                "ids": sp.get("ids") or ([sp["id"]] if sp["id"] else []),
                "file": sp["file"],
                "name": display_name(sp, cache),
                "en": sp.get("name") or sp.get("commentEn") or "",
                "icon": icon_url(sp, cache),
                "modes": sp.get("modes") or [],
                "missing": sorted(
                    p for p in packs if sp["file"] not in files_by_pack.get(p, set())
                ),
            }
            modes = set(sp.get("modes") or [])
            if "consumable" in modes:
                pots.append(row)
            elif "extra" in modes:
                extra.append(row)
            elif "selfcc" in modes:
                ccs.append(row)
            else:
                buffs.append(row)
        classes.append(
            {
                "key": entry["key"],
                "zh": entry["zh"],
                "groups": [
                    g
                    for g in (
                        {"key": "buffs", "title": "敌方buff增益效果监控", "spells": buffs},
                        {"key": "ccs", "title": "我方debuff减益效果监控", "spells": ccs},
                        {"key": "pots", "title": "药水检测（仅野外喊话）", "spells": pots},
                        {"key": "extra", "title": "其他语音（结束音 / 打断 / 未分类）", "spells": extra},
                    )
                    if g["spells"]
                ],
            }
        )

    return {
        "packs": [{"id": p, "label": PACK_LABELS.get(p, p)} for p in packs],
        "classes": classes,
    }


INDEX: dict = {}


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("[preview] " + (fmt % args) + "\n")

    def do_GET(self) -> None:  # noqa: N802
        path = self.path.split("?", 1)[0]
        if path in ("/", "/index.html"):
            self._send_file(HERE / "index.html", "text/html; charset=utf-8")
            return
        if path == "/api/data":
            body = json.dumps(INDEX, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if path.startswith("/media/"):
            rel = unquote(path[len("/media/") :])
            rel = rel.replace("\\", "/")
            parts = [p for p in rel.split("/") if p and p not in (".", "..")]
            target = self._resolve_media(parts)
            if target is None:
                self.send_error(404)
                return
            ctype = "audio/ogg" if target.suffix.lower() == ".ogg" else "audio/mpeg"
            self._send_file(target, ctype)
            return
        self.send_error(404)

    def _resolve_media(self, parts: list[str]) -> Path | None:
        if len(parts) < 2:
            return None
        pack_name, file_name = parts[0], parts[-1]
        folder = MEDIA / pack_name
        if not folder.is_dir():
            wanted = pack_name.casefold()
            folder = next((p for p in MEDIA.iterdir() if p.is_dir() and p.name.casefold() == wanted), None)
        if folder is None or not folder.is_dir():
            return None
        target = folder / file_name
        if not target.is_file():
            wanted = file_name.casefold()
            target = next((p for p in folder.iterdir() if p.is_file() and p.name.casefold() == wanted), None)
            if target is None:
                return None
        resolved = target.resolve()
        if MEDIA.resolve() not in resolved.parents:
            return None
        return resolved

    def _send_file(self, path: Path, content_type: str) -> None:
        data = path.read_bytes()
        total = len(data)
        rng = self.headers.get("Range")
        start, end = 0, total - 1
        status = 200
        if rng and rng.startswith("bytes=") and total:
            spec = rng.split("=", 1)[1].split(",")[0].strip()
            left, _, right = spec.partition("-")
            try:
                if left == "":
                    start = max(total - int(right), 0)
                else:
                    start = int(left)
                    if right:
                        end = min(int(right), total - 1)
            except ValueError:
                start, end = 0, total - 1
            else:
                if start < total and start <= end:
                    status = 206
                else:
                    start, end = 0, total - 1
        chunk = data[start : end + 1]
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(chunk)))
        if status == 206:
            self.send_header("Content-Range", f"bytes {start}-{end}/{total}")
        self.end_headers()
        self.wfile.write(chunk)


def main() -> None:
    os.chdir(HERE)
    print("Building spell index…", flush=True)
    global INDEX
    INDEX = build_index()
    n = sum(
        len(g["spells"])
        for c in INDEX["classes"]
        for g in c["groups"]
    )
    print(f"  packs={len(INDEX['packs'])}  rows={n}", flush=True)
    port = PORT
    httpd = None
    last_err = None
    for candidate in (port, 18081, 28080, 5500, 0):
        try:
            httpd = ThreadingHTTPServer(("127.0.0.1", candidate), Handler)
            port = httpd.server_address[1]
            break
        except OSError as err:
            last_err = err
            httpd = None
    if httpd is None:
        raise last_err
    url = f"http://127.0.0.1:{port}/"
    print(f"Voice preview: {url}", flush=True)
    print("Close this window to stop.", flush=True)
    threading.Timer(0.6, lambda: webbrowser.open(url)).start()
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.", flush=True)


if __name__ == "__main__":
    main()
