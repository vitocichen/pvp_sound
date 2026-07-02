#!/usr/bin/env python3
"""Add Chinese comments to SpellSoundMap.lua."""
import re
from pathlib import Path

WOW = Path(__file__).resolve().parents[2]
GSA_SPELLLIST = WOW / "GSA2_5.0" / "GladiatorlosSA2" / "spelllist.lua"
XYK_TABLE = WOW / "GladiatorlosSA2_mop_v1.0.0.3" / "GladiatorlosSA2" / "技能语音文件对应表.txt"
SPELL_MAP = WOW / "pvp_sound" / "Data" / "SpellSoundMap.lua"

# spellID -> 国服常用中文名（优先于其它来源）
SPELL_ID_CN: dict[int, str] = {
    118: "变形术：绵羊",
    339: "纠缠根须",
    498: "圣佑术",
    605: "精神控制",
    642: "圣盾术",
    871: "盾墙",
    1022: "保护之手",
    1044: "自由之手",
    1330: "锁喉沉默",
    1513: "恐吓野兽",
    1833: "偷袭",
    1850: "疾奔",
    1966: "佯攻",
    2637: "休眠",
    2983: "疾跑",
    5006: "进食饮水",
    5277: "闪避",
    5782: "恐惧术",
    6770: "闷棍",
    10060: "能量灌注",
    12042: "奥术强化",
    12292: "浴血奋战",
    12472: "冰冷血脉",
    12975: "破釜沉舟",
    13877: "剑刃乱舞",
    16166: "元素掌握",
    18499: "狂暴之怒",
    19263: "威慑",
    19386: "翼龙钉刺",
    20066: "忏悔",
    22812: "树皮术",
    22842: "狂暴回复",
    23920: "法术反射",
    28271: "变形术：龟",
    28272: "变形术：猪",
    29166: "激活",
    31224: "暗影斗篷",
    31842: "复仇之怒",
    31884: "复仇之怒",
    33206: "痛苦压制",
    33786: "旋风",
    33891: "化身：生命之树",
    34709: "暗影之眼",
    45438: "寒冰屏障",
    46924: "剑刃风暴",
    47585: "消散",
    47788: "守护之魂",
    48707: "反魔法护罩",
    48792: "冰封之韧",
    49039: "巫妖之躯",
    51271: "冰霜之柱",
    51514: "妖术",
    51690: "杀戮盛宴",
    53271: "主人的召唤",
    53480: "牺牲咆哮",
    55233: "吸血鬼之血",
    61025: "变形术：蛇",
    61305: "变形术：黑猫",
    61336: "生存本能",
    61721: "变形术：兔子",
    61780: "变形术：火鸡",
    69369: "掠食者的迅捷",
    79206: "灵魂行者的恩赐",
    82691: "深度冻结",
    86659: "远古列王守卫",
    86949: "炽热屏障",
    87024: "炽热屏障",
    87204: "吸血鬼之触反伤恐惧",
    91797: "巨兽打击",
    91800: "巨兽打击",
    102342: "铁木树皮",
    102351: "塞纳里奥结界",
    102543: "化身：丛林之王",
    102558: "化身：乌索克之子",
    102560: "化身：艾露恩之选",
    104270: "进食饮水",
    104773: "无尽决心",
    105809: "神圣复仇者",
    106951: "狂暴",
    107574: "天神下凡",
    108271: "星界转移",
    108291: "野性之心",
    108292: "野性之心",
    108293: "野性之心",
    108294: "野性之心",
    108978: "变幻时光",
    110909: "变幻时光",
    112071: "超凡之盟",
    113858: "黑暗灵魂",
    113860: "黑暗灵魂",
    114050: "升腾",
    114051: "升腾",
    114052: "升腾",
    115176: "禅悟冥想",
    115203: "壮胆酒",
    116849: "作茧缚命",
    116888: "炼狱",
    117526: "束缚射击",
    118038: "剑在人在",
    118699: "恐惧术",
    121471: "暗影之刃",
    122278: "躯不坏",
    122470: "业报之触",
    122783: "散魔功",
    124974: "自然守护",
    125174: "业报之触",
    126819: "变形术：豪猪",
    132158: "自然迅捷",
    147833: "援护",
    161353: "变形术：北极熊",
    161354: "变形术：猴子",
    161355: "变形术：企鹅",
    161372: "变形术：孔雀",
    162264: "恶魔变形",
    163505: "斜掠眩晕",
    167152: "进食饮水",
    184364: "狂怒回复",
    185313: "暗影之舞",
    185422: "暗影之舞",
    186265: "灵龟守护",
    187827: "恶魔变形(复仇)",
    190319: "燃烧",
    194223: "超凡之盟",
    194679: "符文分流",
    195901: "PVP饰品",
    196098: "黑暗灵魂",
    196364: "痛苦无常反伤沉默",
    196762: "内心专注",
    197862: "执政官之怒(治疗)",
    197871: "执政官之怒(伤害)",
    197908: "法力茶",
    198111: "时间护盾",
    201318: "壮胆酒",
    204288: "大地之盾",
    204293: "灵魂链接图腾",
    209753: "旋风",
    210294: "神圣之恩",
    210873: "妖术：恐龙",
    211004: "妖术：蜘蛛",
    211010: "妖术：蛇",
    211015: "妖术：蟑螂",
    212332: "巨兽打击",
    212337: "巨兽打击",
    212641: "远古列王守卫",
    214027: "PVP饰品",
    223658: "捍卫",
    227847: "剑刃风暴",
    235963: "纠缠根须(野性)",
    243435: "壮胆酒",
    252216: "猛虎冲刺",
    257427: "进食饮水",
    257428: "进食饮水",
    260708: "横扫攻击",
    262568: "进食饮水",
    269352: "妖术：骸骨幼龙",
    272819: "进食饮水",
    274194: "进食饮水",
    274913: "进食饮水",
    277778: "妖术：赞达拉箭棘龙",
    277784: "妖术：柳魔",
    277787: "变形术：角鹰兽",
    277792: "变形术：大黄蜂",
    279739: "进食饮水",
    287254: "冷酷严冬",
    305395: "荆棘术",
    309328: "妖术：活蜂蜜",
    319454: "野性之心",
    330279: "法术反射",
    336139: "PVP饰品",
    342246: "变幻时光",
    345231: "战斗大师",
    353361: "虚化",
    360806: "梦游",
    378081: "自然迅捷",
    383121: "群体变形",
    383410: "超凡之盟",
    386196: "战斗姿态",
    386208: "防御姿态",
    391622: "变形术：鸭子",
    391631: "变形术：鸭子",
    408558: "渐隐术",
    410126: "灼热凝视",
    410358: "反魔法护罩(法术守卫)",
    443454: "自然迅捷",
}

# 英文 GSA 注释 -> 中文
COMMENT_CN: dict[str, str] = {
    "Sheep": "变形术：绵羊",
    "Turtle": "变形术：龟",
    "Pig": "变形术：猪",
    "Black Cat": "变形术：黑猫",
    "Rabbit": "变形术：兔子",
    "Serpent": "变形术：蛇",
    "Turkey": "变形术：火鸡",
    "Peacock": "变形术：孔雀",
    "Penguin": "变形术：企鹅",
    "Polar Bear Cub": "变形术：北极熊",
    "Monkey": "变形术：猴子",
    "Porcupine": "变形术：豪猪",
    "Direhorn": "变形术：角鹰兽",
    "Bumblebee": "变形术：大黄蜂",
    "Duck": "变形术：鸭子",
    "Duck 2": "变形术：鸭子",
    "Mass": "群体变形",
    "Frog": "妖术",
    "Compy": "妖术：恐龙",
    "Spider": "妖术：蜘蛛",
    "Cockroach": "妖术：蟑螂",
    "Snake": "妖术：蛇",
    "Skeletal Hatchling": "妖术：骸骨幼龙",
    "Zandalari Tendonripper": "妖术：赞达拉箭棘龙",
    "Wicker Mongrel": "妖术：柳魔",
    "Living Honey": "妖术：活蜂蜜",
    "Fear (Warlock)": "恐惧术",
    "Fear (Warlock) because different spellID for some stupid reason": "恐惧术",
    "Cyclone (Druid)": "旋风",
    "Wyvern Sting (Hunter)": "翼龙钉刺",
    "Repentence (Paladin)": "忏悔",
    "Mind Control (Priest)": "精神控制",
    "Hibernate (Druid)": "休眠",
    "Scare Beast (Hunter)": "恐吓野兽",
    "Entangling Roots": "纠缠根须",
    "Entangling Roots Feral Talent": "纠缠根须(野性)",
    "Sleepwalk (Evoker)": "梦游",
    "Searing Glare (Paladin)": "灼热凝视",
    "Vampiric Touch Dispel (Priest)": "吸血鬼之触反伤恐惧",
    "Unstable Affliction Dispel (Warlock)": "痛苦无常反伤沉默",
    "success": "控制成功",
    "drinking": "进食饮水",
    "trinket1": "PVP饰品",
    "battlemaster": "战斗大师",
    "shadowSight": "暗影之眼",
}


def parse_aura_applied(text: str) -> dict[int, tuple[str, str | None]]:
    m = re.search(r"auraApplied\s*=\s*\{", text)
    if not m:
        return {}
    start = m.end()
    depth = 1
    i = start
    while i < len(text) and depth:
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
        i += 1
    block = text[start : i - 1]
    out: dict[int, tuple[str, str | None]] = {}
    for line in block.splitlines():
        mm = re.match(r'\s*\[(\d+)\]\s*=\s*"([^"]+)"(?:\s*,\s*--\s*(.+))?\s*$', line)
        if mm:
            out[int(mm.group(1))] = (mm.group(2), mm.group(3))
    return out


def parse_xyk_table(path: Path) -> dict[str, str]:
    stem_to_cn: dict[str, str] = {}
    if not path.exists():
        return stem_to_cn
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        cn = parts[0]
        file_stem = Path(parts[-1]).stem
        if file_stem.lower().endswith("down"):
            continue
        stem_to_cn[file_stem.lower()] = cn
    return stem_to_cn


def cn_for_spell(spell_id: int, sound: str, comment: str | None, stem_to_cn: dict[str, str]) -> str:
    if spell_id in SPELL_ID_CN:
        return SPELL_ID_CN[spell_id]
    if comment:
        c = comment.strip()
        if c in COMMENT_CN:
            return COMMENT_CN[c]
        if c.startswith("Fear"):
            return "恐惧术"
    if sound == "success":
        return "控制成功"
    key = Path(sound).stem.lower() if "." in sound else sound.lower()
    if key in stem_to_cn:
        return stem_to_cn[key]
  # fallback: strip extension from map value handled by caller
    return sound


def main() -> None:
    gsa = parse_aura_applied(GSA_SPELLLIST.read_text(encoding="utf-8"))
    stem_to_cn = parse_xyk_table(XYK_TABLE)

    text = SPELL_MAP.read_text(encoding="utf-8")
    entries = re.findall(r'\[(\d+)\]\s*=\s*"([^"]+)"', text)

    lines = [
        "--- spellID -> Media filename (enemy helpful buffs only + 夏一可 voice pack)",
        "--- CC / 敌人被控不在此表；友方被控走 TTS",
        "--- 行尾中文备注便于测试对照",
        "---@type string, Addon",
        "local _, addon = ...",
        "---@class SpellSoundMap",
        "local M = {}",
        "M.SPELL_TO_SOUND = {",
    ]

    for sid_s, fname in entries:
        sid = int(sid_s)
        sound_key, comment = gsa.get(sid, ("", None))
        cn = cn_for_spell(sid, fname, comment, stem_to_cn)
        lines.append(f'\t[{sid}] = "{fname}", -- {cn}')

    lines.extend(["}", "addon.Data.SpellSoundMap = M", "return M", ""])
    SPELL_MAP.write_text("\n".join(lines), encoding="utf-8")
    print(f"annotated {len(entries)} entries")


if __name__ == "__main__":
    main()
