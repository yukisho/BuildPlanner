#!/usr/bin/env python3
"""
Build Planner GBP1 generator — Python

Command line:
    python gbp1.py build.json

Application code:
    from gbp1 import encode_build
    code = encode_build(build_dict)

Minimal build_dict:
    build_dict = {
        "name": "Stamina Warden",
        "classId": 4,
        "selectedSetup": 1,
        "setups": [{
            "name": "Base Setup",
            "equipment": {
                "waist": {
                    "setId": 602,
                    "setName": "Whorl of the Depths",
                    "armorType": 1,
                }
            },
        }],
    }

The build dictionary must follow the schema documented in ../README.md.
encode_build returns a GBP1: string or raises ValueError for invalid input.
The generator has no third-party dependencies.
"""

import json
import sys

VERSION = 9
PREFIX = "GBP1:"
ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
SLOTS = ["head", "shoulders", "chest", "hands", "waist", "legs", "feet", "neck", "ring1", "ring2", "frontMain", "frontOff", "backMain", "backOff"]
TWO_HANDED = {4, 5, 6, 8, 9, 12, 13, 15}
REQ_STRINGS = ["setName", "itemName", "itemLink", "enchantmentName", "note"]
REQ_NUMBERS = ["setId", "itemId", "armorType", "weaponType", "traitType", "enchantmentId", "enchantmentCategory", "quality", "level", "championPoints"]
ROUTES = {"buy": 1, "craft": 2, "farm": 3, "reconstruct": 4, "transmute": 5, "unknown": 6}
CONSUMABLES = {"food": 1, "drink": 2, "potion": 3, "poison": 4, "other": 5}
CHECKLIST = {"passive": 1, "skillLine": 2, "unlock": 3, "other": 4}
DETECTION = {"passive": 1, "skillLine": 2, "ability": 3, "champion": 4, "championSlotted": 5, "trait": 6}


def obj(value, name):
    if not isinstance(value, dict):
        raise ValueError(f"{name} must be an object")
    return value


def arr(value, name, maximum):
    value = [] if value is None else value
    if not isinstance(value, list) or len(value) > maximum:
        raise ValueError(f"{name} must be an array of at most {maximum}")
    return value


def integer(value, minimum, maximum, name):
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum or value > maximum:
        raise ValueError(f"{name} is out of range")
    return value


def encoded_text(value, name, maximum, required=False):
    value = "" if value is None else str(value)
    result = value.encode("utf-8")
    if len(result) > maximum or (required and not value.strip()):
        raise ValueError(f"{name} is invalid")
    return result


class Writer:
    def __init__(self):
        self.data = bytearray()

    def byte(self, value):
        self.data.append(integer(value, 0, 255, "byte"))

    def u16(self, value):
        self.data.extend(integer(value, 0, 65535, "u16").to_bytes(2, "big"))

    def u32(self, value):
        self.data.extend(integer(value, 0, 4294967295, "u32").to_bytes(4, "big"))

    def optional(self, value, name):
        self.u32(0 if value is None else integer(value, 0, 4294967294, name) + 1)

    def string(self, value, name, maximum, required=False):
        value = encoded_text(value, name, maximum, required)
        self.u16(len(value))
        self.data.extend(value)


def write_requirement(writer, value, name, include_route):
    value = obj(value, name)
    for key in REQ_STRINGS:
        maximum = 2048 if key == "itemLink" else 4000 if key == "note" else 512
        writer.string(value.get(key), f"{name}.{key}", maximum)
    for key in REQ_NUMBERS:
        writer.optional(value.get(key), f"{name}.{key}")
    if include_route:
        route_name = value.get("preferredRoute")
        if route_name is not None and route_name not in ROUTES:
            raise ValueError(f"{name}.preferredRoute is invalid")
        writer.byte(ROUTES.get(route_name, 0))


def write_skill_bars(writer, setup):
    skill_bars = setup.get("skillBars") or {}
    for bar_name in ("front", "back"):
        bar = arr(skill_bars.get(bar_name), f"skillBars.{bar_name}", 6)
        mask = sum(2 ** index for index in range(6) if index < len(bar) and bar[index])
        writer.byte(mask)
        for index in range(6):
            skill = bar[index] if index < len(bar) else None
            if skill:
                skill = obj(skill, f"{bar_name} skill")
                writer.u32(integer(skill.get("abilityId"), 1, 4294967295, "abilityId"))
                writer.string(skill.get("name"), "skill name", 100)
                writer.string(skill.get("icon"), "skill icon", 512)


def write_champion(writer, setup):
    champion = setup.get("champion") or {}
    seen = set()
    for key in ("craft", "warfare", "fitness"):
        discipline = champion.get(key) or {}
        allocations = arr(discipline.get("allocations"), f"{key} allocations", 200)
        writer.u16(len(allocations))
        slottable = set()
        for raw in allocations:
            entry = obj(raw, "Champion allocation")
            skill_id = integer(entry.get("skillId"), 1, 4294967295, "Champion skillId")
            if skill_id in seen:
                raise ValueError("Champion skillId is duplicated")
            seen.add(skill_id)
            writer.u32(skill_id)
            writer.u16(integer(entry.get("points"), 1, 1000, "Champion points"))
            is_slottable = entry.get("isSlottable") is True
            writer.byte(1 if is_slottable else 0)
            if is_slottable:
                slottable.add(skill_id)
            writer.string(entry.get("name"), "Champion name", 100, True)
            writer.string(entry.get("icon"), "Champion icon", 512)
        slots = arr(discipline.get("slottables"), f"{key} slottables", 4)
        used = set()
        for index in range(4):
            skill_id = slots[index] if index < len(slots) and slots[index] is not None else 0
            skill_id = integer(skill_id, 0, 4294967295, "slottable")
            if skill_id and (skill_id not in slottable or skill_id in used):
                raise ValueError("invalid Champion slottable")
            if skill_id:
                used.add(skill_id)
            writer.u32(skill_id)


def write_setup(writer, value):
    value = obj(value, "setup")
    writer.string(value.get("name"), "setup name", 100, True)
    writer.string(value.get("note"), "setup note", 4000)
    writer.u16(integer(value.get("defaultQuality", 5), 1, 5, "defaultQuality"))
    writer.u16(integer(value.get("defaultLevel", 50), 1, 50, "defaultLevel"))
    writer.u32(integer(value.get("defaultChampionPoints", 160), 0, 160, "defaultChampionPoints"))

    equipment = obj(value.get("equipment") or {}, "equipment")
    for main_slot, off_slot in (("frontMain", "frontOff"), ("backMain", "backOff")):
        main = equipment.get(main_slot)
        if isinstance(main, dict) and main.get("weaponType") in TWO_HANDED and equipment.get(off_slot) is not None:
            raise ValueError(f"{main_slot} is two-handed, so {off_slot} must be empty")
    equipped = [slot for slot in SLOTS if equipment.get(slot) is not None]
    writer.byte(len(equipped))
    for slot in equipped:
        writer.byte(SLOTS.index(slot) + 1)
        write_requirement(writer, equipment[slot], f"equipment.{slot}", True)

    alternatives = obj(value.get("alternatives") or {}, "alternatives")
    alternative_slots = [slot for slot in SLOTS if isinstance(alternatives.get(slot), list)
                         and alternatives[slot]]
    writer.byte(len(alternative_slots))
    for slot in alternative_slots:
        if slot not in equipment:
            raise ValueError("alternatives require primary equipment")
        entries = arr(alternatives[slot], f"alternatives.{slot}", 8)
        writer.byte(SLOTS.index(slot) + 1)
        writer.byte(len(entries))
        for index, entry in enumerate(entries):
            write_requirement(writer, entry, f"alternatives.{slot}[{index}]", False)

    write_skill_bars(writer, value)
    character = value.get("character") or {}
    attributes = character.get("attributes") or {}
    points = [integer(attributes.get(key, 0), 0, 64, key)
              for key in ("health", "magicka", "stamina")]
    if sum(points) > 64:
        raise ValueError("attribute total exceeds 64")
    points.extend([integer(character.get("raceId", 0), 0, 10, "raceId"),
                   integer(character.get("mundus", 0), 0, 13, "mundus"),
                   integer(character.get("curse", 0), 0, 2, "curse")])
    for point in points:
        writer.byte(point)
    subclass = arr(character.get("subclassLines"), "subclassLines", 3)
    for index in range(3):
        writer.string(subclass[index] if index < len(subclass) else None, "subclass line", 100)

    write_champion(writer, value)
    consumables = arr(value.get("consumables"), "consumables", 20)
    writer.byte(len(consumables))
    for raw in consumables:
        entry = obj(raw, "consumable")
        if entry.get("category") not in CONSUMABLES:
            raise ValueError("invalid consumable category")
        writer.byte(CONSUMABLES[entry["category"]])
        writer.string(entry.get("name"), "consumable name", 100, True)
        writer.string(entry.get("itemLink"), "consumable itemLink", 2048)
        writer.string(entry.get("icon"), "consumable icon", 512)
        writer.u16(integer(entry.get("quantity", 1), 1, 9999, "quantity"))
        writer.string(entry.get("note"), "consumable note", 4000)
        writer.optional(entry.get("itemId"), "consumable itemId")

    checklist = arr(value.get("checklist"), "checklist", 100)
    writer.byte(len(checklist))
    for raw in checklist:
        entry = obj(raw, "checklist entry")
        if entry.get("category") not in CHECKLIST:
            raise ValueError("invalid checklist category")
        writer.byte(CHECKLIST[entry["category"]])
        writer.string(entry.get("name"), "checklist name", 100, True)
        writer.byte(0 if entry.get("targetRank") is None else
                    integer(entry["targetRank"], 1, 50, "targetRank"))
        writer.byte(1 if entry.get("completed") is True else 0)
        writer.optional(entry.get("abilityId"), "abilityId")
        writer.string(entry.get("icon"), "checklist icon", 512)
        writer.string(entry.get("note"), "checklist note", 4000)
        detection = entry.get("detection")
        if detection and detection.get("kind") not in DETECTION:
            raise ValueError("invalid checklist detection")
        writer.byte(DETECTION[detection["kind"]] if detection else 0)
        for key in ("id", "skillType", "skillLineIndex", "craftingType",
                    "researchLineIndex", "traitIndex"):
            writer.optional(detection.get(key) if detection else None, f"detection.{key}")

    assumptions = value.get("buffAssumptions") or {}
    writer.string(assumptions.get("food"), "assumption food", 512)
    writer.string(assumptions.get("potion"), "assumption potion", 512)
    for key in ("selfBuffs", "groupBuffs", "targetConditions"):
        entries = arr(assumptions.get(key), key, 20)
        writer.byte(len(entries))
        for entry in entries:
            writer.string(entry, key, 512, True)


def adler32(data):
    first, second = 1, 0
    for byte in data:
        first = (first + byte) % 65521
        second = (second + first) % 65521
    return second * 65536 + first


def base64_url(data):
    result = []
    for position in range(0, len(data), 3):
        chunk = data[position:position + 3]
        packed = chunk[0] * 65536 + (chunk[1] * 256 if len(chunk) > 1 else 0) + (chunk[2] if len(chunk) > 2 else 0)
        result.extend((ALPHABET[packed // 262144], ALPHABET[(packed // 4096) % 64]))
        if len(chunk) > 1:
            result.append(ALPHABET[(packed // 64) % 64])
        if len(chunk) > 2:
            result.append(ALPHABET[packed % 64])
    return "".join(result)


def encode_build(raw):
    build = obj(raw, "build")
    setups = arr(build.get("setups"), "setups", 100)
    if not setups:
        raise ValueError("at least one setup is required")
    writer = Writer()
    writer.byte(VERSION)
    writer.string(build.get("name"), "build name", 100, True)
    for key in ("role", "patch", "author", "sourceUrl"):
        writer.string(build.get(key), key, 512)
    writer.string(build.get("notes"), "notes", 4000)
    writer.optional(build.get("classId"), "classId")
    writer.u16(len(setups))
    writer.u16(integer(build.get("selectedSetup", 1), 1, len(setups), "selectedSetup"))
    for setup in setups:
        write_setup(writer, setup)
    writer.u32(adler32(writer.data))
    return PREFIX + base64_url(writer.data)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python gbp1.py build.json", file=sys.stderr)
        sys.exit(1)
    try:
        with open(sys.argv[1], "r", encoding="utf-8") as handle:
            print(encode_build(json.load(handle)))
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
