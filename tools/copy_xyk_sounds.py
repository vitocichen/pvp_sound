#!/usr/bin/env python3
"""Generate EnemyBuffSpellIds + SpellSoundMap (enemy helpful buffs only, no CC)."""
import re
import shutil
import subprocess
import sys
from pathlib import Path

WOW = Path(__file__).resolve().parents[2]
MOP_SPELLLIST = WOW / "GladiatorlosSA2_mop_v1.0.0.3" / "GladiatorlosSA2" / "spelllist.lua"
RETAIL_SPELLLIST = WOW / "GSA2_5.0" / "GladiatorlosSA2" / "spelllist.lua"
ENEMY_IDS_FILE = WOW / "pvp_sound" / "Data" / "EnemyBuffSpellIds.lua"
XYK_DIR = WOW / "GladiatorlosSA2_mop_v1.0.0.3" / "GladiatorlosSA2" / "夏一可"
MEDIA_DIR = WOW / "pvp_sound" / "Media"
OUT_MAP = WOW / "pvp_sound" / "Data" / "SpellSoundMap.lua"
ANNOTATE = WOW / "pvp_sound" / "tools" / "annotate_spell_map.py"

# 在职业区块里误列为 auraApplied、实为控/减益的 spellID
EXTRA_EXCLUDE: set[int] = {
    1330, 1833, 6770,  # 锁喉 / 偷袭 / 闷棍
    3355, 117526, 356727, 357021, 202335,  # 冰冻陷阱 / 束缚射击 / 蜘蛛钉刺 等
    163505,  # 斜掠眩晕
    82691, 353084, 389794, 389831,  # 法师控场减益
    91797, 91800, 212332, 212337,  # 宠物击晕
    87204, 196364,  # 驱散反伤（Backlash 段）
    305497,  # 荆棘（减益型）
    209753,  # 旋风 debuff
}

ALIASES: dict[str, str] = {
    "frenziedregen": "frenziedregeneration",
    "predatorswiftness": "predatorsswiftness",
    "trinket1": "battlemaster",
    "bindingshotbound": "bindingshot",
    "fortifyingbrew": "sfortifyingbrew",
    "naturesvigil": "naturevigil",
    "archangelhealing": "archangel",
    "archangeldamage": "archangel",
    "unendingresolve2": "unendingresolve",
}


def extract_block(text: str, marker: str) -> str:
    m = re.search(rf"{re.escape(marker)}\s*=\s*\{{", text)
    if not m:
        return ""
    start = m.end()
    depth = 1
    i = start
    while i < len(text) and depth:
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
        i += 1
    return text[start : i - 1]


def parse_retail_section(block: str) -> tuple[dict[int, str], dict[int, str | None]]:
    sounds: dict[int, str] = {}
    comments: dict[int, str | None] = {}
    for line in block.splitlines():
        if line.strip().startswith("--"):
            continue
        mm = re.match(
            r'\s*\[(\d+)\]\s*=\s*"([^"]+)"\s*,?\s*(?:--\s*(.+))?\s*$',
            line,
        )
        if mm:
            sid = int(mm.group(1))
            sounds[sid] = mm.group(2)
            comments[sid] = mm.group(3).strip() if mm.group(3) else None
    return sounds, comments


def parse_mop_spelllist(text: str) -> dict[int, str]:
    return {
        int(m.group(1)): m.group(2)
        for m in re.finditer(r'\[(\d+)\]\s*=\s*\{\s*soundName\s*=\s*"([^"]+)"', text)
    }


def parse_enemy_buff_ids_from_retail(block: str) -> list[int]:
    """Skip GSA Crowd Controls + Backlash sections; keep General + class buffs."""
    skip = False
    ids: list[int] = []
    for line in block.splitlines():
        stripped = line.strip()
        if "-- Crowd Controls" in line:
            skip = True
            continue
        if skip and stripped.startswith("-- Death Knight"):
            skip = False
        if skip or stripped.startswith("--"):
            continue
        mm = re.match(r'\s*\[(\d+)\]\s*=\s*"([^"]+)"', line)
        if mm:
            ids.append(int(mm.group(1)))
    return sorted(set(ids) - EXTRA_EXCLUDE)


def write_enemy_buff_spell_ids(spell_ids: list[int]) -> None:
    lines = [
        "--- Enemy helpful buff spell IDs (GSA auraApplied, excludes CC/debuff).",
        "--- Used for AddPrivateAuraAppliedSound on enemy units only.",
        "---@type string, Addon",
        "local _, addon = ...",
        "---@class EnemyBuffSpellIds",
        "local M = {}",
        "M.SPELL_IDS = {",
    ]
    row: list[str] = []
    for sid in spell_ids:
        row.append(str(sid))
        if len(row) == 8:
            lines.append("\t" + ", ".join(row) + ",")
            row = []
    if row:
        lines.append("\t" + ", ".join(row) + ",")
    lines.extend(["}", "addon.Data.EnemyBuffSpellIds = M", "return M", ""])
    ENEMY_IDS_FILE.write_text("\n".join(lines), encoding="utf-8")


def resolve_sound_name(
    sid: int,
    mop: dict[int, str],
    aura: dict[int, str],
    cast_start: dict[int, str],
    cast_success: dict[int, str],
) -> str | None:
    if sid in mop:
        name = mop[sid]
        if name.lower() != "success":
            return name
    for section in (aura, cast_start, cast_success):
        name = section.get(sid)
        if name and name.lower() != "success":
            return name
    return None


def build_file_index() -> dict[str, Path]:
    index: dict[str, Path] = {}
    for f in XYK_DIR.iterdir():
        if f.is_file() and f.suffix.lower() in (".ogg", ".mp3"):
            key = f.stem.lower()
            existing = index.get(key)
            if existing is None or (
                existing.suffix.lower() == ".mp3" and f.suffix.lower() == ".ogg"
            ):
                index[key] = f
    return index


def resolve_source(sound: str, file_index: dict[str, Path]) -> Path | None:
    if not sound or sound.lower() == "success":
        return None
    key = ALIASES.get(sound.lower(), sound.lower())
    src = file_index.get(key)
    if src and src.stem.lower().endswith("down"):
        return None
    return src


def main() -> None:
    retail_text = RETAIL_SPELLLIST.read_text(encoding="utf-8")
    aura_block = extract_block(retail_text, "auraApplied")
    spell_ids = parse_enemy_buff_ids_from_retail(aura_block)
    write_enemy_buff_spell_ids(spell_ids)

    mop = parse_mop_spelllist(MOP_SPELLLIST.read_text(encoding="utf-8"))
    aura, _ = parse_retail_section(aura_block)
    cast_start, _ = parse_retail_section(extract_block(retail_text, "castStart"))
    cast_success, _ = parse_retail_section(extract_block(retail_text, "castSuccess"))

    file_index = build_file_index()
    MEDIA_DIR.mkdir(parents=True, exist_ok=True)

    copied: dict[int, str] = {}
    missing: list[tuple[int, str | None, str]] = []

    for sid in spell_ids:
        sound = resolve_sound_name(sid, mop, aura, cast_start, cast_success)
        if not sound:
            missing.append((sid, None, "no_sound_name"))
            continue
        src = resolve_source(sound, file_index)
        if not src:
            missing.append((sid, sound, "no_audio_file"))
            continue
        dest = MEDIA_DIR / src.name
        if not dest.exists() or dest.stat().st_size != src.stat().st_size:
            shutil.copy2(src, dest)
        copied[sid] = src.name

    lines = [
        "--- spellID -> Media filename (enemy helpful buffs only + 夏一可 voice pack)",
        "--- CC / enemy debuff 不在此表；友方被控走 TTS",
        "---@type string, Addon",
        "local _, addon = ...",
        "---@class SpellSoundMap",
        "local M = {}",
        "M.SPELL_TO_SOUND = {",
    ]
    for sid in sorted(copied):
        fn = copied[sid].replace("\\", "\\\\")
        lines.append(f'\t[{sid}] = "{fn}",')
    lines.extend(["}", "addon.Data.SpellSoundMap = M", "return M", ""])
    OUT_MAP.write_text("\n".join(lines), encoding="utf-8")

    print(f"enemy buff spell_ids: {len(spell_ids)}")
    print(f"mapped+copied: {len(copied)}")
    print(f"missing audio: {len(missing)}")
    for item in missing:
        print(f"  {item}")

    if ANNOTATE.exists():
        subprocess.run([sys.executable, str(ANNOTATE)], check=True)


if __name__ == "__main__":
    main()
