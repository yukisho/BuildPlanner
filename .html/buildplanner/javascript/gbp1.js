/*
 * Build Planner GBP1 generator — JavaScript
 *
 * Command line:
 *   node gbp1.js build.json
 *
 * Browser:
 *   <script src="gbp1.js"></script>
 *   const code = GBP1.encodeBuild(buildObject);
 *
 * Node module:
 *   const { encodeBuild } = require("./gbp1.js");
 *   const code = encodeBuild(buildObject);
 *
 * Minimal buildObject:
 *   const buildObject = {
 *     name: "Stamina Warden",
 *     classId: 4,
 *     selectedSetup: 1,
 *     setups: [{
 *       name: "Base Setup",
 *       equipment: {
 *         waist: { setId: 602, setName: "Whorl of the Depths", armorType: 1 }
 *       }
 *     }]
 *   };
 *
 * The build object must follow the schema documented in ../README.md.
 * encodeBuild returns a GBP1: string or throws an Error for invalid input.
 */

(function (root, factory) {
    const api = factory();
    if (typeof module === "object" && module.exports) module.exports = api;
    if (root) root.GBP1 = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
    "use strict";

    const VERSION = 9;
    const PREFIX = "GBP1:";
    const SLOTS = ["head", "shoulders", "chest", "hands", "waist", "legs", "feet", "neck", "ring1", "ring2", "frontMain", "frontOff", "backMain", "backOff"];
    const TWO_HANDED = new Set([4, 5, 6, 8, 9, 12, 13, 15]);
    const ARMOR_SLOTS = new Set(SLOTS.slice(0, 7));
    const JEWELRY_SLOTS = new Set(SLOTS.slice(7, 10));
    const ARMOR_TYPES = new Set([1, 2, 3]);
    const WEAPON_TYPES = new Set([1, 2, 3, 4, 5, 6, 8, 9, 11, 12, 13, 14, 15]);
    const TRAITS = {
        armor: new Set([11, 12, 13, 14, 15, 16, 17, 18, 19]),
        jewelry: new Set([21, 22, 23, 30, 31, 32, 33, 34, 35]),
        weapon: new Set([1, 2, 3, 4, 5, 6, 7, 8, 26])
    };
    const REQ_STRINGS = ["setName", "itemName", "itemLink", "enchantmentName", "note"];
    const REQ_NUMBERS = ["setId", "itemId", "armorType", "weaponType", "traitType", "enchantmentId", "enchantmentCategory", "quality", "level", "championPoints"];
    const ROUTES = { buy: 1, craft: 2, farm: 3, reconstruct: 4, transmute: 5, unknown: 6 };
    const CONSUMABLES = { food: 1, drink: 2, potion: 3, poison: 4, other: 5 };
    const CHECKLIST = { passive: 1, skillLine: 2, unlock: 3, other: 4 };
    const DETECTION = { passive: 1, skillLine: 2, ability: 3, champion: 4, championSlotted: 5, trait: 6 };
    const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    const encoder = new TextEncoder();

    function fail(message) { throw new Error(message); }
    function object(value, name) {
        if (!value || typeof value !== "object" || Array.isArray(value)) fail(name + " must be an object");
        return value;
    }

    function array(value, name, maximum) {
        value = value == null ? [] : value;
        if (!Array.isArray(value) || value.length > maximum) fail(name + " must be an array of at most " + maximum);
        return value;
    }

    function integer(value, minimum, maximum, name) {
        if (!Number.isInteger(value) || value < minimum || value > maximum) fail(name + " is out of range");
        return value;
    }

    function text(value, name, maximum, required) {
        if (value != null && typeof value !== "string") fail(name + " must be a string");
        value = value == null ? "" : value;
        const bytes = encoder.encode(value);
        if (bytes.length > maximum || (required && value.trim() === "")) fail(name + " is invalid");
        return bytes;
    }

    function validateHttpUrl(value, name) {
        if (value == null || value === "") return;
        if (typeof value !== "string") fail(name + " must be a string");
        let parsed;
        try { parsed = new URL(value); } catch (_) { fail(name + " must be an absolute HTTP or HTTPS URL"); }
        if (parsed.protocol !== "http:" && parsed.protocol !== "https:") fail(name + " must use HTTP or HTTPS");
    }

    function validateIcon(value, name) {
        if (value == null || value === "") return;
        if (typeof value !== "string" || /[\u0000-\u001f]/.test(value) || value.startsWith("//")) fail(name + " is invalid");
        const scheme = value.match(/^([a-z][a-z0-9+.-]*):/i);
        if (scheme && !/^https?$/i.test(scheme[1])) fail(name + " must be an ESO path or HTTP/HTTPS URL");
    }

    function validateItemLink(value, name) {
        if (value == null || value === "") return;
        if (typeof value !== "string" || !/^(?:\|c[0-9a-f]{6})?\|H\d+:item:[^|\r\n]+\|h[^|\r\n]*\|h(?:\|r)?$/i.test(value)) {
            fail(name + " must be an ESO item link");
        }
    }

    function optionalInteger(value, minimum, maximum, name) {
        if (value != null) integer(value, minimum, maximum, name);
    }

    function validateRequirement(value, slot, name) {
        const family = ARMOR_SLOTS.has(slot) ? "armor" : JEWELRY_SLOTS.has(slot) ? "jewelry" : "weapon";
        if (family === "armor") {
            if (value.weaponType != null) fail(name + ".weaponType is not valid for an armor slot");
            if (value.armorType != null && !ARMOR_TYPES.has(value.armorType)) fail(name + ".armorType is invalid");
        } else if (family === "jewelry") {
            if (value.armorType != null || value.weaponType != null) fail(name + " cannot have armorType or weaponType");
        } else {
            if (value.armorType != null) fail(name + ".armorType is not valid for a weapon slot");
            if (value.weaponType != null && !WEAPON_TYPES.has(value.weaponType)) fail(name + ".weaponType is invalid");
        }
        if (value.traitType != null && !TRAITS[family].has(value.traitType)) fail(name + ".traitType is invalid for this slot");
        for (const key of ["setId", "itemId", "enchantmentId"]) optionalInteger(value[key], 0, 4294967294, name + "." + key);
        optionalInteger(value.enchantmentCategory, 0, 255, name + ".enchantmentCategory");
        optionalInteger(value.quality, 1, 5, name + ".quality");
        optionalInteger(value.level, 1, 50, name + ".level");
        optionalInteger(value.championPoints, 0, 160, name + ".championPoints");
        if (value.championPoints != null && value.championPoints % 10 !== 0) fail(name + ".championPoints must use increments of 10");
        validateItemLink(value.itemLink, name + ".itemLink");
    }

    class Writer {
        constructor() { this.bytes = []; }
        byte(value) { this.bytes.push(integer(value, 0, 255, "byte")); }
        u16(value) { value = integer(value, 0, 65535, "u16"); this.bytes.push(value >>> 8, value & 255); }

        u32(value) {
            value = integer(value, 0, 4294967295, "u32");
            this.bytes.push(Math.floor(value / 16777216) & 255, Math.floor(value / 65536) & 255,
            Math.floor(value / 256) & 255, value & 255);
        }

        optional(value, name) {
            if (value == null) this.u32(0);
            else this.u32(integer(value, 0, 4294967294, name) + 1);
        }

        string(value, name, maximum, required) {
            const bytes = text(value, name, maximum, required);
            this.u16(bytes.length);
            this.bytes.push(...bytes);
        }
    }

    function requirement(writer, value, name, includeRoute, slot) {
        value = object(value, name);
        validateRequirement(value, slot, name);

        for (const key of REQ_STRINGS) writer.string(value[key], name + "." + key, key === "itemLink" ? 2048 : key === "note" ? 4000 : 512, false);
        for (const key of REQ_NUMBERS) writer.optional(value[key], name + "." + key);

        if (includeRoute) {
            const route = value.preferredRoute == null ? 0 : ROUTES[value.preferredRoute];
            if (route == null) fail(name + ".preferredRoute is invalid");
            writer.byte(route);
        }
    }

    function skillBars(writer, setup) {
        for (const barName of ["front", "back"]) {
            const bar = array((setup.skillBars || {})[barName], "skillBars." + barName, 6);
            let mask = 0;

            for (let index = 0; index < 6; index++) if (bar[index]) mask += 2 ** index;

            writer.byte(mask);

            for (let index = 0; index < 6; index++) if (bar[index]) {
                const skill = object(bar[index], barName + " skill");
                writer.u32(integer(skill.abilityId, 1, 4294967295, "abilityId"));
                writer.string(skill.name, "skill name", 100, false);
                validateIcon(skill.icon, "skill icon");
                writer.string(skill.icon, "skill icon", 512, false);
            }
        }
    }

    function champion(writer, setup) {
        const champion = setup.champion || {};
        const seen = new Set();

        for (const key of ["craft", "warfare", "fitness"]) {
            const discipline = champion[key] || {};
            const allocations = array(discipline.allocations, key + " allocations", 200);
            writer.u16(allocations.length);
            const slottable = new Set();

            for (const value of allocations) {
                const entry = object(value, "Champion allocation");
                const skillId = integer(entry.skillId, 1, 4294967295, "Champion skillId");
                if (seen.has(skillId)) fail("Champion skillId is duplicated");
                seen.add(skillId);
                writer.u32(skillId);
                writer.u16(integer(entry.points, 1, 1000, "Champion points"));
                writer.byte(entry.isSlottable === true ? 1 : 0);
                if (entry.isSlottable === true) slottable.add(skillId);
                writer.string(entry.name, "Champion name", 100, true);
                validateIcon(entry.icon, "Champion icon");
                writer.string(entry.icon, "Champion icon", 512, false);
            }

            const slots = array(discipline.slottables, key + " slottables", 4);
            const used = new Set();

            for (let index = 0; index < 4; index++) {
                const skillId = slots[index] == null ? 0 : integer(slots[index], 0, 4294967295, "slottable");
                if (skillId && (!slottable.has(skillId) || used.has(skillId))) fail("invalid Champion slottable");
                if (skillId) used.add(skillId);
                writer.u32(skillId);
            }
        }
    }

    function setup(writer, value, setupIndex) {
        value = object(value, "setup");
        writer.string(value.name, "setup name", 100, true);
        writer.string(value.note, "setup note", 4000, false);
        writer.u16(integer(value.defaultQuality == null ? 5 : value.defaultQuality, 1, 5, "defaultQuality"));
        writer.u16(integer(value.defaultLevel == null ? 50 : value.defaultLevel, 1, 50, "defaultLevel"));
        writer.u32(integer(value.defaultChampionPoints == null ? 160 : value.defaultChampionPoints, 0, 160, "defaultChampionPoints"));

        const equipment = value.equipment || {};
        object(equipment, "equipment");
        for (const [main, off] of [["frontMain", "frontOff"], ["backMain", "backOff"]]) {
            if (equipment[main] && TWO_HANDED.has(equipment[main].weaponType) && equipment[off]) {
                fail(main + " is two-handed, so " + off + " must be empty");
            }
        }
        const equippedSlots = SLOTS.filter((slot) => equipment[slot] != null);
        writer.byte(equippedSlots.length);

        for (const slot of equippedSlots) {
            writer.byte(SLOTS.indexOf(slot) + 1);
            requirement(writer, equipment[slot], "equipment." + slot, true, slot);
        }

        const alternatives = value.alternatives || {};
        object(alternatives, "alternatives");
        const alternativeSlots = SLOTS.filter((slot) => Array.isArray(alternatives[slot]) && alternatives[slot].length);
        writer.byte(alternativeSlots.length);

        for (const slot of alternativeSlots) {
            if (!equipment[slot]) fail("alternatives require primary equipment");

            const entries = array(alternatives[slot], "alternatives." + slot, 8);
            writer.byte(SLOTS.indexOf(slot) + 1);
            writer.byte(entries.length);
            entries.forEach((entry, index) => requirement(writer, entry,"alternatives." + slot + "[" + index + "]", false, slot));
        }

        skillBars(writer, value);
        const character = value.character || {};
        const attributes = character.attributes || {};
        const health = integer(attributes.health || 0, 0, 64, "health");
        const magicka = integer(attributes.magicka || 0, 0, 64, "magicka");
        const stamina = integer(attributes.stamina || 0, 0, 64, "stamina");

        if (health + magicka + stamina > 64) fail("attribute total exceeds 64");

        [health, magicka, stamina,integer(character.raceId || 0, 0, 10, "raceId"),integer(character.mundus || 0, 0, 13, "mundus"),integer(character.curse || 0, 0, 2, "curse")].forEach((entry) => writer.byte(entry));

        const subclass = array(character.subclassLines, "subclassLines", 3);

        for (let index = 0; index < 3; index++) writer.string(subclass[index], "subclass line", 100, false);

        champion(writer, value);
        const consumables = array(value.consumables, "consumables", 20);
        writer.byte(consumables.length);

        for (const raw of consumables) {
            const entry = object(raw, "consumable");

            if (!CONSUMABLES[entry.category]) fail("invalid consumable category");

            writer.byte(CONSUMABLES[entry.category]);
            writer.string(entry.name, "consumable name", 100, true);
            validateItemLink(entry.itemLink, "consumable itemLink");
            writer.string(entry.itemLink, "consumable itemLink", 2048, false);
            validateIcon(entry.icon, "consumable icon");
            writer.string(entry.icon, "consumable icon", 512, false);
            writer.u16(integer(entry.quantity == null ? 1 : entry.quantity, 1, 9999, "quantity"));
            writer.string(entry.note, "consumable note", 4000, false);
            writer.optional(entry.itemId, "consumable itemId");
        }

        const checklist = array(value.checklist, "checklist", 100);
        writer.byte(checklist.length);
        for (const raw of checklist) {
            const entry = object(raw, "checklist entry");

            if (!CHECKLIST[entry.category]) fail("invalid checklist category");

            writer.byte(CHECKLIST[entry.category]);
            writer.string(entry.name, "checklist name", 100, true);
            writer.byte(entry.targetRank == null ? 0 : integer(entry.targetRank, 1, 50, "targetRank"));
            writer.byte(entry.completed === true ? 1 : 0);
            writer.optional(entry.abilityId, "abilityId");
            validateIcon(entry.icon, "checklist icon");
            writer.string(entry.icon, "checklist icon", 512, false);
            writer.string(entry.note, "checklist note", 4000, false);
            const detection = entry.detection;

            if (detection && !DETECTION[detection.kind]) fail("invalid checklist detection");

            writer.byte(detection ? DETECTION[detection.kind] : 0);

            for (const key of ["id", "skillType", "skillLineIndex", "craftingType", "researchLineIndex", "traitIndex"])

            writer.optional(detection && detection[key], "detection." + key);
        }

        const assumptions = value.buffAssumptions || {};
        writer.string(assumptions.food, "assumption food", 512, false);
        writer.string(assumptions.potion, "assumption potion", 512, false);

        for (const key of ["selfBuffs", "groupBuffs", "targetConditions"]) {
            const entries = array(assumptions[key], key, 20);
            writer.byte(entries.length);
            entries.forEach((entry) => writer.string(entry, key, 512, true));
        }
    }

    function checksum(bytes) {
        let first = 1, second = 0;
        for (const byte of bytes) { first = (first + byte) % 65521; second = (second + first) % 65521; }
        return second * 65536 + first;
    }

    function base64(bytes) {
        let result = "";
        for (let position = 0; position < bytes.length; position += 3) {
            const second = position + 1 < bytes.length, third = position + 2 < bytes.length;
            const packed = bytes[position] * 65536 + (second ? bytes[position + 1] * 256 : 0) + (third ? bytes[position + 2] : 0);
            result += ALPHABET[Math.floor(packed / 262144)] + ALPHABET[Math.floor(packed / 4096) % 64];
            if (second) result += ALPHABET[Math.floor(packed / 64) % 64];
            if (third) result += ALPHABET[packed % 64];
        }
        return result;
    }

    function encodeBuild(raw) {
        const build = object(raw, "build");
        const setups = array(build.setups, "setups", 100);
        if (!setups.length) fail("at least one setup is required");

        const writer = new Writer();

        writer.byte(VERSION);
        writer.string(build.name, "build name", 100, true);
        writer.string(build.role, "role", 512, false);
        writer.string(build.patch, "patch", 512, false);
        writer.string(build.author, "author", 512, false);
        validateHttpUrl(build.sourceUrl, "sourceUrl");
        writer.string(build.sourceUrl, "sourceUrl", 512, false);
        writer.string(build.notes, "notes", 4000, false);
        writer.optional(build.classId, "classId");
        writer.u16(setups.length);
        writer.u16(integer(build.selectedSetup == null ? 1 : build.selectedSetup, 1, setups.length, "selectedSetup"));
        setups.forEach((entry, index) => setup(writer, entry, index));
        const sum = checksum(writer.bytes);
        writer.u32(sum);

        return PREFIX + base64(writer.bytes);
    }

    return { encodeBuild, VERSION, PREFIX };
});

if (typeof require === "function" && typeof module === "object" && require.main === module) {
    const fs = require("fs");
    const file = process.argv[2];

    if (!file) { console.error("Usage: node gbp1.js build.json"); process.exit(1); }

    try {
        process.stdout.write(module.exports.encodeBuild(JSON.parse(fs.readFileSync(file, "utf8"))) + "\n");
    } catch (error) { console.error(error.message); process.exit(1); }
}
