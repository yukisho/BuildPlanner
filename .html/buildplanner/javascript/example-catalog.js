/*
 * Small demonstration catalog for the Build Planner developer form.
 *
 * These records demonstrate form integration only. They are not a complete or
 * authoritative ESO catalog. Replace the IDs, names, and icon paths with data
 * maintained by your website before publishing a real build editor.
 */
(function (root) {
    "use strict";

    root.BuildPlannerExampleCatalog = {
        notice: "Sample data only. Swap these records for the ESO data maintained by your site.",
        gear: {
            armor: [
                { label: "Example · Whorl of the Depths Sash", value: { setId: 602, setName: "Whorl of the Depths", itemName: "Whorl of the Depths Sash", armorType: 1, traitType: 18 } }
            ],
            jewelry: [
                { label: "Example · Highland Sentinel Ring", value: { setId: 734, setName: "Highland Sentinel", itemName: "Highland Sentinel Ring", traitType: 35 } }
            ],
            weapon: [
                { label: "Example · Order's Wrath Dagger (one-handed)", value: { setId: 619, setName: "Order's Wrath", itemName: "Order's Wrath Dagger", weaponType: 11, traitType: 3 } },
                { label: "Example · Order's Wrath Shield (off-hand)", value: { setId: 619, setName: "Order's Wrath", itemName: "Order's Wrath Shield", weaponType: 14, traitType: 5 } },
                { label: "Example · Null Arca Greatsword (two-handed)", value: { setName: "Null Arca", itemName: "Null Arca Greatsword", weaponType: 6, traitType: 2 } }
            ]
        },
        skills: {
            active: [
                { label: "Example · Deep Fissure", value: { abilityId: 1001, name: "Deep Fissure", icon: "/esoui/art/icons/ability_warden_007.dds" } },
                { label: "Example · Cutting Dive", value: { abilityId: 1002, name: "Cutting Dive", icon: "/esoui/art/icons/ability_warden_001.dds" } },
                { label: "Example · Bull Netch", value: { abilityId: 1013, name: "Bull Netch", icon: "/esoui/art/icons/ability_warden_011_b.dds" } }
            ],
            ultimate: [
                { label: "Example · Wild Guardian", value: { abilityId: 1006, name: "Wild Guardian", icon: "/esoui/art/icons/ability_warden_006_b.dds" } },
                { label: "Example · Flawless Dawnbreaker", value: { abilityId: 1016, name: "Flawless Dawnbreaker", icon: "/esoui/art/icons/ability_fightersguild_001_b.dds" } }
            ]
        },
        champion: {
            craft: [
                { label: "Example · Steed's Blessing", value: { skillId: 2001, name: "Steed's Blessing", points: 50, isSlottable: true, icon: "/esoui/art/champion/champion_points_stamina_icon-hud.dds" } }
            ],
            warfare: [
                { label: "Example · Wrathful Strikes", value: { skillId: 2101, name: "Wrathful Strikes", points: 50, isSlottable: true, icon: "/esoui/art/champion/champion_points_magicka_icon-hud.dds" } }
            ],
            fitness: [
                { label: "Example · Boundless Vitality", value: { skillId: 2201, name: "Boundless Vitality", points: 50, isSlottable: true, icon: "/esoui/art/champion/champion_points_health_icon-hud.dds" } }
            ]
        },
        consumables: [
            { label: "Example · Lava Foot Soup-and-Saltrice (food)", value: { category: "food", name: "Lava Foot Soup-and-Saltrice", quantity: 20 } },
            { label: "Example · Witchmother's Potent Brew (drink)", value: { category: "drink", name: "Witchmother's Potent Brew", quantity: 20 } },
            { label: "Example · Essence of Weapon Power (potion)", value: { category: "potion", name: "Essence of Weapon Power", quantity: 100 } },
            { label: "Example · Damage Health Poison IX (poison)", value: { category: "poison", name: "Damage Health Poison IX", quantity: 100 } },
            { label: "Example · Alliance Battle Draught (other)", value: { category: "other", name: "Alliance Battle Draught", quantity: 5 } }
        ],
        checklist: [
            { label: "Example · Advanced Species (passive)", value: { category: "passive", name: "Advanced Species", targetRank: 2, detection: { kind: "passive", id: 5002 } } },
            { label: "Example · Fighters Guild rank (skill line)", value: { category: "skillLine", name: "Fighters Guild Rank", targetRank: 10, detection: { kind: "skillLine", skillType: 3, skillLineIndex: 1 } } },
            { label: "Example · Wild Guardian unlock", value: { category: "unlock", name: "Unlock Wild Guardian", abilityId: 1006, detection: { kind: "ability", id: 1006 } } },
            { label: "Example · Wrathful Strikes slotted", value: { category: "unlock", name: "Slot Wrathful Strikes", detection: { kind: "championSlotted", id: 2101 } } },
            { label: "Example · Divines research", value: { category: "other", name: "Research Divines", detection: { kind: "trait", craftingType: 2, researchLineIndex: 3, traitIndex: 8 } } }
        ]
    };
})(typeof globalThis !== "undefined" ? globalThis : this);
