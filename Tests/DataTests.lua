local strings = {}
local timestamp = 1000

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, entry in pairs(value) do
        result[copy(key)] = copy(entry)
    end
    return result
end

function ZO_CreateStringId(name, value)
    _G[name] = name
    strings[name] = value
end

function GetString(id, index)
    if index ~= nil then
        return tostring(id) .. " " .. tostring(index)
    end
    return strings[id]
end

function zo_strtrim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function zo_strlower(value)
    return string.lower(value)
end

function zo_strformat(id, ...)
    local result = GetString(id) or "<<1>>"
    for index = 1, select("#", ...) do
        result = result:gsub("<<" .. tostring(index) .. ">>", tostring(select(index, ...)))
    end
    return result
end

function zo_clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function GetTimeStamp()
    timestamp = timestamp + 1
    return timestamp
end

function GetWorldName()
    return "Test"
end

GENDER_MALE = 1
function GetRaceName(_, raceId)
    local races = {
        "Breton", "Redguard", "Orc", "Dark Elf", "Nord",
        "Argonian", "High Elf", "Wood Elf", "Khajiit", "Imperial",
    }
    return races[raceId] or ""
end

ITEM_QUALITY_LEGENDARY = 5
ARMORTYPE_NONE = 0
WEAPONTYPE_NONE = 0
WEAPONTYPE_SHIELD = 1
WEAPONTYPE_AXE = 2
WEAPONTYPE_TWO_HANDED_AXE = 3
WEAPONTYPE_TWO_HANDED_HAMMER = 4
WEAPONTYPE_TWO_HANDED_SWORD = 5
WEAPONTYPE_BOW = 6
WEAPONTYPE_FIRE_STAFF = 7
WEAPONTYPE_FROST_STAFF = 8
WEAPONTYPE_LIGHTNING_STAFF = 9
WEAPONTYPE_HEALING_STAFF = 10

EQUIP_SLOT_HEAD = 1
EQUIP_SLOT_SHOULDERS = 2
EQUIP_SLOT_CHEST = 3
EQUIP_SLOT_HAND = 4
EQUIP_SLOT_WAIST = 5
EQUIP_SLOT_LEGS = 6
EQUIP_SLOT_FEET = 7
EQUIP_SLOT_NECK = 8
EQUIP_SLOT_RING1 = 9
EQUIP_SLOT_RING2 = 10
EQUIP_SLOT_MAIN_HAND = 11
EQUIP_SLOT_OFF_HAND = 12
EQUIP_SLOT_BACKUP_MAIN = 13
EQUIP_SLOT_BACKUP_OFF = 14

ZO_SavedVars = {}
function ZO_SavedVars:NewAccountWide(_, _, _, defaults)
    if TEST_SAVED then
        local saved = TEST_SAVED
        TEST_SAVED = nil
        return saved
    end
    return copy(defaults)
end

local function expect(value, message)
    if not value then
        error(message or "expectation failed", 2)
    end
end

local function expectEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

dofile("Localization/en.lua")
dofile("EquipmentSlots.lua")
dofile("ModelValidation.lua")
dofile("Data.lua")
dofile("Share.lua")

local data = GravvyBuildPlannerData:New()
local firstBuild = data:GetCurrentBuild()
local firstSetup = data:GetCurrentSetup()
expectEqual(#data:GetBuilds(), 1, "clean install should create one build")
expectEqual(firstSetup.defaultChampionPoints, 160, "default CP")
expectEqual(firstSetup.defaultQuality, ITEM_QUALITY_LEGENDARY, "default quality")
expectEqual(data:GetSettings().fontScale, 1, "default font scale")
expectEqual(data:GetSettings().highContrast, false, "high contrast should be opt-in")
expectEqual(data:GetSettings().nonColorIndicators, false, "text status prefixes should be opt-in")
expectEqual(firstSetup.character.attributes.health, 0, "new setups should have an empty character plan")
expectEqual(firstSetup.champion.warfare.slottables[1], 0, "new setups should have empty Champion slots")
expectEqual(#firstSetup.consumables, 0, "new setups should have no consumable requirements")
expectEqual(#firstSetup.checklist, 0, "new setups should have an empty progression checklist")

local build = data:CreateBuild("Warden DPS", {
    classId = 5,
    role = "Damage",
    patch = "Update 50",
    author = "Example",
    sourceUrl = "https://example.com/build",
    notes = "Light setup",
})
expect(build, "build should be created")
expectEqual(build.classId, 5, "class metadata")

local setup = data:GetCurrentSetup()
local ok = data:SetEquipment(build.id, setup.id, "waist", {
    setName = "Whorl of the Depths",
    armorType = 1,
    traitType = 21,
    enchantmentName = "Magicka",
})
expect(ok, "armor requirement should be accepted")
ok = data:SetAlternative(build.id, setup.id, "waist", nil, {
    setName = "Order's Wrath",
    armorType = 1,
    traitType = 21,
    enchantmentName = "Magicka",
})
expect(ok, "a compatible slot alternative should be accepted")
expectEqual(#data:GetAlternatives(setup, "waist"), 1, "alternatives should retain their order")
ok = data:SetAlternative(build.id, setup.id, "waist", nil, {
    setName = "Invalid Weapon",
    weaponType = WEAPONTYPE_AXE,
})
expect(not ok, "slot alternatives should use the same equipment family as their primary")
ok = data:SetPreferredRoute(build.id, setup.id, "waist", "buy")
expect(ok, "a supported acquisition route should be saved")
expectEqual(setup.acquisition.waist.preferredRoute, "buy", "the preferred route should remain separate from equipment")
expect(not data:SetPreferredRoute(build.id, setup.id, "waist", "teleport"), "unknown acquisition routes should be rejected")
ok = data:SetSkill(build.id, setup.id, "front", 1, {
    abilityId = 1001,
    name = "Deep Fissure",
    icon = "deep-fissure.dds",
    isUltimate = false,
})
expect(ok, "front-bar active skills should be saved")
expect(not data:SetSkill(build.id, setup.id, "front", 2, {
    abilityId = 1001,
    name = "Deep Fissure",
    icon = "deep-fissure.dds",
    isUltimate = false,
}), "a skill should not occupy two positions on the same bar")
ok = data:SetSkill(build.id, setup.id, "front", 6, {
    abilityId = 1006,
    name = "Wild Guardian",
    icon = "wild-guardian.dds",
    isUltimate = true,
})
expect(ok, "the sixth skill slot should accept an ultimate")
expect(not data:SetSkill(build.id, setup.id, "back", 1, {
    abilityId = 1006,
    name = "Wild Guardian",
    icon = "wild-guardian.dds",
    isUltimate = true,
}), "normal skill slots should reject ultimates")

ok = data:UpdateCharacter(build.id, setup.id, {
    attributes = { health = 0, magicka = 14, stamina = 50 },
    raceId = 9,
    mundus = 10,
    curse = 1,
    subclassLines = { "Animal Companions", "Winter's Embrace", "Grave Lord" },
})
expect(ok, "character plans should be saved")
expectEqual(setup.character.attributes.stamina, 50, "attribute plans should retain their allocation")
expectEqual(setup.character.mundus, 10, "Mundus choices should be saved")
expectEqual(setup.character.subclassLines[3], "Grave Lord", "subclass lines should be saved")
expect(not data:UpdateCharacter(build.id, setup.id, {
    attributes = { health = 20, magicka = 20, stamina = 25 },
}), "attribute plans should reject totals above 64")
expectEqual(setup.character.attributes.stamina, 50, "failed character updates should not change saved data")

ok = data:SetChampionAllocation(build.id, setup.id, "warfare", {
    skillId = 2001,
    name = "Wrathful Strikes",
    icon = "wrathful.dds",
    points = 50,
    isSlottable = true,
})
expect(ok, "Champion allocations should be saved")
ok = data:SetChampionSlottable(build.id, setup.id, "warfare", 2, 2001)
expect(ok, "slottable Champion Stars should retain their position")
ok = data:SetChampionAllocation(build.id, setup.id, "warfare", {
    skillId = 2002,
    name = "Precision",
    icon = "precision.dds",
    points = 20,
    isSlottable = false,
})
expect(ok, "passive Champion allocations should be saved")
expect(not data:SetChampionSlottable(build.id, setup.id, "warfare", 1, 2002),
    "passive Champion Stars should not be slotted")
expect(not data:SetChampionAllocation(build.id, setup.id, "craft", {
    skillId = 2001,
    name = "Wrathful Strikes",
    icon = "wrathful.dds",
    points = 50,
    isSlottable = true,
}), "a Champion Star should not be duplicated across disciplines")

local supplySaved, supplyIndex = data:SetConsumable(build.id, setup.id, nil, {
    category = "food",
    name = "Braised Rabbit with Spring Vegetables",
    itemId = 12345,
    itemLink = "food:item",
    icon = "food.dds",
    quantity = 20,
    note = "Use for parsing",
})
expect(supplySaved, "consumable requirements should be saved")
expectEqual(supplyIndex, 1, "new consumables should retain their ordered position")
expect(not data:SetConsumable(build.id, setup.id, nil, {
    category = "food",
    name = "Braised Rabbit with Spring Vegetables",
    quantity = 1,
}), "duplicate consumables should be rejected within a category")
expect(not data:SetConsumable(build.id, setup.id, 0, {
    category = "drink",
    name = "Dubious Camoran Throne",
    quantity = 1,
}), "invalid consumable positions should not append a new entry")

local checklistSaved, checklistIndex = data:SetChecklistEntry(build.id, setup.id, nil, {
    category = "passive",
    name = "Advanced Species",
    targetRank = 2,
    abilityId = 5002,
    icon = "advanced-species.dds",
    completed = false,
    note = "Animal Companions",
})
expect(checklistSaved, "passive and progression steps should be saved")
expectEqual(checklistIndex, 1, "new checklist steps should retain their ordered position")
expect(data:SetChecklistCompleted(build.id, setup.id, checklistIndex, true),
    "checklist completion should update independently")
expect(setup.checklist[1].completed, "checklist completion should be retained")
expect(not data:SetChecklistEntry(build.id, setup.id, nil, {
    category = "passive",
    name = "Advanced Species",
}), "duplicate checklist steps should be rejected within a category")

ok = data:SetEquipment(build.id, setup.id, "waist", { weaponType = WEAPONTYPE_AXE })
expect(not ok, "weapon type should not be accepted in an armor slot")

ok = data:SetEquipment(build.id, setup.id, "frontOff", { weaponType = WEAPONTYPE_AXE })
expect(ok, "one-handed off-hand should be accepted")
data:SetPreferredRoute(build.id, setup.id, "frontOff", "buy")
local _, twoHanded, clearedSlot = data:SetEquipment(build.id, setup.id, "frontMain", {
    setName = "Perfected Merciless Charge",
    weaponType = WEAPONTYPE_TWO_HANDED_SWORD,
})
expect(twoHanded, "two-handed main weapon should be accepted")
expectEqual(clearedSlot, "frontOff", "two-handed weapon should clear off-hand")
expectEqual(setup.equipment.frontOff, nil, "off-hand should be empty")
expectEqual(setup.acquisition.frontOff, nil, "clearing an occupied off-hand should clear its route")
ok = data:SetEquipment(build.id, setup.id, "frontOff", { weaponType = WEAPONTYPE_AXE })
expect(not ok, "occupied off-hand should reject requirements")
ok = data:SetEquipment(build.id, setup.id, "frontMain", { weaponType = WEAPONTYPE_AXE })
expect(ok, "one-handed main weapon should replace two-handed weapon")
ok = data:SetEquipment(build.id, setup.id, "frontOff", { weaponType = WEAPONTYPE_SHIELD })
expect(ok, "shield should be accepted off-hand")
ok = data:SetEquipment(build.id, setup.id, "frontMain", { weaponType = WEAPONTYPE_SHIELD })
expect(not ok, "shield should not be accepted main-hand")

ok = data:SetEquipment(build.id, setup.id, "feet", {
    setName = "Whorl of the Depths",
    itemName = "Shoes of Whorl of the Depths",
    itemLink = "saved feet link",
    itemId = 1234,
    armorType = 1,
    enchantmentId = 5678,
})
expect(ok, "saved armor requirement should be accepted")
ok = data:ApplySetAlternative(build.id, setup.id, "waist", 1)
expect(ok, "a saved replacement set should apply to matching primary-set slots")
expectEqual(
    data:GetAlternatives(setup, "feet")[1].setName,
    "Order's Wrath",
    "set-wide alternatives should keep each matching slot's other requirements"
)
ok = data:CopyEquipment(build.id, setup.id, "feet", "head")
expect(ok, "armor requirements should copy to other armor slots")
expect(setup.equipment.feet, "copy should preserve the source slot")
expectEqual(setup.equipment.head.setName, "Whorl of the Depths", "copy should retain the plan")
expectEqual(setup.equipment.head.itemLink, nil, "copy should discard a slot-specific item link")
expectEqual(setup.equipment.head.itemId, nil, "copy should discard a slot-specific item id")
expectEqual(setup.equipment.head.itemName, nil, "copy should let the destination item name resolve")
expectEqual(setup.equipment.head.enchantmentId, nil, "copy should let the destination enchant resolve")
data:SetPreferredRoute(build.id, setup.id, "head", "craft")
ok = data:MoveEquipment(build.id, setup.id, "head", "chest")
expect(ok, "armor requirements should move to other armor slots")
expectEqual(setup.equipment.head, nil, "move should clear the source slot")
expect(setup.equipment.chest, "move should fill the destination slot")
expectEqual(setup.acquisition.head, nil, "moving a requirement should clear its source route")
expectEqual(setup.acquisition.chest.preferredRoute, "craft", "moving a requirement should carry its route")

ok = data:SetEquipment(build.id, setup.id, "ring1", { setName = "Pillar of Nirn" })
expect(ok, "jewelry requirement should be accepted")
ok = data:CopyEquipment(build.id, setup.id, "ring1", "head")
expect(not ok, "transfers should stay within the source slot family")
expect(setup.equipment.ring1, "failed transfer should preserve the source")

ok = data:SetEquipment(build.id, setup.id, "backOff", { weaponType = WEAPONTYPE_AXE })
expect(ok, "back-bar off-hand should accept a one-handed weapon")
ok = data:SetEquipment(build.id, setup.id, "frontMain", {
    setName = "Perfected Merciless Charge",
    weaponType = WEAPONTYPE_TWO_HANDED_SWORD,
})
expect(ok, "two-handed source requirement should be accepted")
local copied, _, clearedBackSlot = data:CopyEquipment(
    build.id,
    setup.id,
    "frontMain",
    "backMain"
)
expect(copied, "two-handed requirements should copy between main-hand slots")
expectEqual(clearedBackSlot, "backOff", "copied two-handed weapon should occupy the new off-hand")
expectEqual(setup.equipment.backOff, nil, "copying a two-handed weapon should clear the destination off-hand")
expect(setup.equipment.frontMain, "two-handed copy should preserve its source")
ok = data:SetEquipment(build.id, setup.id, "backMain", { weaponType = WEAPONTYPE_AXE })
expect(ok, "one-handed weapon should free the back-bar off-hand")
ok = data:SetEquipment(build.id, setup.id, "backOff", { weaponType = WEAPONTYPE_AXE })
expect(ok, "freed back-bar off-hand should accept a requirement")
ok = data:CopyEquipment(build.id, setup.id, "backOff", "frontOff")
expect(not ok, "transfer should reject an off-hand occupied by a two-handed weapon")
expect(setup.equipment.backOff, "failed occupied-slot transfer should preserve the source")

local oldName = build.name
ok = data:UpdateBuild(build.id, { name = "Changed", role = 7 })
expect(not ok, "invalid metadata update should fail")
expectEqual(build.name, oldName, "failed update should not partially rename build")

local variant = data:DuplicateSetup(build.id, setup.id)
expect(variant, "setup should be duplicated")
expect(variant.equipment.waist ~= setup.equipment.waist, "equipment should be copied")
expect(variant.alternatives ~= setup.alternatives, "slot alternatives should be copied independently")
expect(variant.skillBars ~= setup.skillBars, "skill bars should be copied independently")
expect(variant.character ~= setup.character, "character plans should be copied independently")
expect(variant.champion ~= setup.champion, "Champion plans should be copied independently")
expect(variant.consumables ~= setup.consumables, "consumable plans should be copied independently")
expect(variant.checklist ~= setup.checklist, "progression checklists should be copied independently")
expectEqual(next(variant.acquisition), nil, "setup copy should not copy acquisition state")

local duplicate = data:DuplicateBuild(build.id)
expect(duplicate, "build should be duplicated")
expectEqual(#duplicate.setups, #build.setups, "all setups should be copied")
expect(duplicate.setups[1].equipment ~= build.setups[1].equipment, "build equipment should be copied")
expect(
    duplicate.setups[1].alternatives ~= build.setups[1].alternatives,
    "build copies should not share slot alternatives"
)
expectEqual(next(duplicate.setups[1].acquisition), nil, "build copy should not copy acquisition state")
expectEqual(#duplicate.revisions, 0, "build copies should start with separate revision history")

ok = data:DeleteBuild(duplicate.id)
expect(ok, "build should be deleted")
ok = data:UndoLastDeletion()
expect(ok, "deleted build should be restored")
expect(data:FindBuild(duplicate.id), "restored build should retain its id")

local localSnapshotSaved = data:SetStatSnapshot(build.id, build.setups[1].id, "front", {
    characterName = "Local Warden",
    createdAt = 4000,
    values = { maxHealth = 31000 },
})
expect(localSnapshotSaved, "a setup should accept a local stat snapshot")
local shareCode = GravvyBuildPlannerShare.EncodeBuild(build)
expect(shareCode and shareCode:sub(1, 5) == "GBP1:", "builds should encode as GBP1 codes")
local decodedBuild = GravvyBuildPlannerShare.DecodeCode(shareCode)
expect(decodedBuild, "a generated build code should decode")
expectEqual(decodedBuild.name, build.name, "share codes should retain the build name")
expectEqual(#decodedBuild.setups, #build.setups, "share codes should retain every setup")
expectEqual(decodedBuild.selectedSetupIndex, 2, "share codes should retain the selected setup")
expectEqual(
    decodedBuild.setups[1].equipment.waist.setName,
    build.setups[1].equipment.waist.setName,
    "share codes should retain equipment requirements"
)
expectEqual(
    decodedBuild.setups[1].alternatives.waist[1].setName,
    "Order's Wrath",
    "share codes should retain ordered slot alternatives"
)
expectEqual(
    decodedBuild.setups[1].skillBars.front[1].abilityId,
    1001,
    "share codes should retain planned skill bars"
)
expectEqual(decodedBuild.setups[1].character.raceId, 9, "share codes should retain race choices")
expectEqual(decodedBuild.setups[1].character.attributes.stamina, 50, "share codes should retain attributes")
expectEqual(decodedBuild.setups[1].character.subclassLines[3], "Grave Lord", "share codes should retain subclass lines")
expectEqual(decodedBuild.setups[1].champion.warfare.allocations[1].skillId, 2001,
    "share codes should retain Champion allocations")
expectEqual(decodedBuild.setups[1].champion.warfare.slottables[2], 2001,
    "share codes should retain Champion slot positions")
expectEqual(decodedBuild.setups[1].consumables[1].quantity, 20,
    "share codes should retain consumable quantities")
expectEqual(decodedBuild.setups[1].checklist[1].abilityId, 5002,
    "share codes should retain passive-skill identity")
expect(decodedBuild.setups[1].checklist[1].completed,
    "share codes should retain checklist completion")
expectEqual(decodedBuild.setups[1].statSnapshots, nil,
    "share codes should exclude character-specific stat snapshots")
local buildCount = #data:GetBuilds()
local imported = data:ImportBuild(decodedBuild)
expect(imported, "decoded builds should import")
expectEqual(#data:GetBuilds(), buildCount + 1, "import should add exactly one build")
expect(imported.name ~= build.name, "import should resolve a duplicate build name")
expectEqual(
    imported.setups[1].acquisition.waist.preferredRoute,
    "buy",
    "share codes should retain preferred acquisition routes"
)
expectEqual(imported.selectedSetupId, imported.setups[2].id, "import should restore the selected setup")
expectEqual(
    imported.setups[1].alternatives.waist[1].setName,
    "Order's Wrath",
    "import should preserve shared alternatives"
)
expectEqual(
    imported.setups[1].skillBars.front[6].abilityId,
    1006,
    "import should preserve planned ultimates"
)
expectEqual(imported.setups[1].character.mundus, 10, "import should preserve character plans")
expectEqual(imported.setups[1].champion.warfare.allocations[2].points, 20,
    "import should preserve passive Champion allocations")
expectEqual(imported.setups[1].consumables[1].itemId, 12345,
    "import should preserve resolved consumable identity")
expectEqual(imported.setups[1].checklist[1].targetRank, 2,
    "import should preserve progression targets")
local damaged = shareCode:sub(1, -2) .. (shareCode:sub(-1) == "A" and "B" or "A")
expectEqual(GravvyBuildPlannerShare.DecodeCode(damaged), nil, "damaged share codes should fail their checksum")
local hostileCases = {
    { key = "armorType", value = 99, slot = "head" },
    { key = "weaponType", value = 999, slot = "frontMain" },
    { key = "traitType", value = 999, slot = "head" },
    { key = "enchantmentCategory", value = 999, slot = "head" },
    { key = "quality", value = 99, slot = "head" },
    { key = "level", value = 51, slot = "head" },
    { key = "championPoints", value = 155, slot = "head" },
    { key = "setId", value = 0, slot = "head" },
}
for _, hostileCase in ipairs(hostileCases) do
    local hostile = copy(decodedBuild)
    hostile.setups[1].equipment[hostileCase.slot] = hostile.setups[1].equipment[hostileCase.slot]
        or { armorType = 1 }
    hostile.setups[1].equipment[hostileCase.slot][hostileCase.key] = hostileCase.value
    local validateRequirement = GravvyBuildPlannerValidation.IsRequirement
    GravvyBuildPlannerValidation.IsRequirement = function() return true end
    local hostileCode = GravvyBuildPlannerShare.EncodeBuild(hostile)
    GravvyBuildPlannerValidation.IsRequirement = validateRequirement
    expect(hostileCode, "hostile import fixtures should still carry a valid checksum")
    expectEqual(GravvyBuildPlannerShare.DecodeCode(hostileCode), nil,
        "checksummed imports should still reject invalid enum and numeric values")
end
local nextBuildId = data.saved.nextBuildId
expectEqual(data:ImportBuild({ name = "Bad", setups = {} }), nil, "invalid imports should fail")
expectEqual(data.saved.nextBuildId, nextBuildId, "failed imports should not consume ids")
expectEqual(data:ImportBuild({
    name = "Contradictory",
    setups = {{
        name = "Base",
        equipment = {
            frontMain = { weaponType = WEAPONTYPE_TWO_HANDED_SWORD },
            frontOff = { weaponType = WEAPONTYPE_AXE },
        },
    }},
}), nil, "imports should reject a filled off-hand beside a two-handed weapon")
expectEqual(data.saved.nextBuildId, nextBuildId, "contradictory imports should remain transactional")

local revision, revisionMessage = data:CreateRevision(build.id, "Update 50 baseline")
expect(revision, revisionMessage)
expectEqual(#data:GetRevisions(build.id), 1, "named revisions should be stored on their build")
expectEqual(revision.snapshot.selectedSetupIndex, 2,
    "revision snapshots should retain the selected setup")
expectEqual(data:CreateRevision(build.id, "Update 50 baseline"), nil,
    "revision names should be unique within a build")
local buildCodeWithHistory = GravvyBuildPlannerShare.EncodeBuild(build)
local decodedWithoutHistory = GravvyBuildPlannerShare.DecodeCode(buildCodeWithHistory)
expectEqual(decodedWithoutHistory.revisions, nil,
    "revision history should remain local instead of inflating share codes")

data:UpdateBuild(build.id, { patch = "Update 51" })
data:SetEquipment(build.id, setup.id, "waist", {
    setName = "Changed Set",
    armorType = 1,
})
local buildIdBeforeRestore = data.saved.nextBuildId
local setupIdBeforeRestore = data.saved.nextSetupId
local restored, restoredMessage = data:RestoreRevision(build.id, revision.id)
expect(restored, restoredMessage)
expectEqual(data.saved.nextBuildId, buildIdBeforeRestore,
    "revision restore should not consume a temporary build id")
expectEqual(data.saved.nextSetupId, setupIdBeforeRestore,
    "revision restore should not consume temporary setup ids")
expectEqual(restored.id, build.id, "restoring should preserve the build identity")
expectEqual(restored.patch, "Update 50", "restoring should recover build metadata")
expectEqual(restored.setups[1].equipment.waist.setName, "Whorl of the Depths",
    "restoring should recover setup contents")
expectEqual(restored.setups[1].statSnapshots.front.values.maxHealth, 31000,
    "local revision restores should retain exact stat snapshots")
expectEqual(#restored.revisions, 2,
    "restoring should preserve a backup of the replaced build")
expectEqual(restored.revisions[1].snapshot.patch, "Update 51",
    "the automatic backup should contain the pre-restore state")

local brokenRevision = data:CreateRevision(build.id, "Broken checkpoint")
brokenRevision.snapshot.setups = {}
local buildsBeforeBrokenRestore = #data:GetBuilds()
expectEqual(data:RestoreRevision(build.id, brokenRevision.id), nil,
    "invalid revision snapshots should fail validation")
expectEqual(#data:GetBuilds(), buildsBeforeBrokenRestore,
    "failed restores should not leave a temporary imported build")
expectEqual(build.patch, "Update 50",
    "failed restores should not alter the current build")
expect(data:DeleteRevision(build.id, brokenRevision.id),
    "saved revisions should be removable")

local evictionMessage
for index = 1, 22 do
    local _, message = data:CreateRevision(build.id, "Checkpoint " .. tostring(index))
    evictionMessage = message
end
expectEqual(#data:GetRevisions(build.id), 20,
    "revision history should discard its oldest entries at the limit")
expect(evictionMessage and evictionMessage:find("older revision", 1, true),
    "revision saves should explain history eviction")
local oldestRevision = data:GetRevisions(build.id)[20]
local restoredAtLimit, restoredAtLimitMessage = data:RestoreRevision(
    build.id,
    oldestRevision.id
)
expect(restoredAtLimit, restoredAtLimitMessage)
expect(data:FindRevision(restoredAtLimit, oldestRevision.id),
    "restoring the oldest full-history checkpoint should not evict it")
expectEqual(#data:GetRevisions(build.id), 20,
    "automatic restore backups should retain the history limit")

local snapshotSetup, snapshotBuild = data:GetCurrentSetup()
local snapshotSaved, snapshotMessage = data:SetStatSnapshot(snapshotBuild.id, snapshotSetup.id, "front", {
    characterName = "Test Warden",
    createdAt = 4242,
    captureTime = "20:15",
    foodName = "Bewitched Sugar Skulls",
    foodAbilityId = 9002,
    mundus = 10,
    inCombat = true,
    equippedCoverage = { planned = 3, ready = 1, adjustable = 1, missing = 1 },
    values = {
        maxHealth = 32000,
        weaponDamage = 5400,
        ignoredValue = 99,
    },
})
expect(snapshotSaved, snapshotMessage)
expectEqual(data:IsStatSnapshotStale(snapshotSetup, "front"), false,
    "a newly captured snapshot should match its setup fingerprint")
expectEqual(snapshotSetup.statSnapshots.front.values.maxHealth, 32000,
    "stat snapshots should retain supported character-sheet values")
expectEqual(snapshotSetup.statSnapshots.front.values.ignoredValue, nil,
    "stat snapshots should discard unknown values")
expectEqual(snapshotSetup.statSnapshots.front.captureTime, "20:15",
    "stat snapshots should retain capture time")
expectEqual(snapshotSetup.statSnapshots.front.foodName, "Bewitched Sugar Skulls",
    "stat snapshots should retain active food context")
expectEqual(snapshotSetup.statSnapshots.front.foodAbilityId, 9002,
    "stat snapshots should retain active food identity")
expectEqual(snapshotSetup.statSnapshots.front.mundus, 10,
    "stat snapshots should retain Mundus context")
expectEqual(snapshotSetup.statSnapshots.front.inCombat, true,
    "stat snapshots should retain combat context")
expectEqual(snapshotSetup.statSnapshots.front.equippedCoverage.adjustable, 1,
    "stat snapshots should retain valid equipped coverage")
data:UpdateSetup(snapshotBuild.id, snapshotSetup.id, { note = "route notes do not affect stats" })
expectEqual(data:IsStatSnapshotStale(snapshotSetup, "front"), false,
    "setup notes should not stale an exact stat snapshot")
data:SetEquipment(snapshotBuild.id, snapshotSetup.id, "head", {
    setName = "Fingerprint Test",
    armorType = 1,
})
expectEqual(data:IsStatSnapshotStale(snapshotSetup, "front"), true,
    "gear changes should stale exact stat snapshots")
data:SetStatSnapshot(snapshotBuild.id, snapshotSetup.id, "front", {
    characterName = "Test Warden",
    createdAt = 4243,
    values = { maxHealth = 32000 },
})
data:SetPreferredRoute(snapshotBuild.id, snapshotSetup.id, "head", "buy")
expectEqual(data:IsStatSnapshotStale(snapshotSetup, "front"), false,
    "acquisition routes should not stale exact stat snapshots")
data:UpdateCharacter(snapshotBuild.id, snapshotSetup.id, {
    attributes = { health = 1, magicka = 0, stamina = 0 },
    raceId = 0,
    mundus = 0,
    curse = 0,
    subclassLines = { "", "", "" },
})
expectEqual(data:IsStatSnapshotStale(snapshotSetup, "front"), true,
    "character choices should stale exact stat snapshots")
local invalidBarOk, invalidBarMessage = data:SetStatSnapshot(
    snapshotBuild.id,
    snapshotSetup.id,
    "side",
    { values = { maxHealth = 1 } }
)
expectEqual(invalidBarOk, false, "invalid stat snapshot bars should fail")
expectEqual(invalidBarMessage, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_STAT_BAR),
    "invalid stat snapshot bars should return their own error")
local copiedSnapshotSetup = data:DuplicateSetup(snapshotBuild.id, snapshotSetup.id, "Snapshot Copy")
expectEqual(copiedSnapshotSetup.statSnapshots, nil,
    "copied setups should not inherit character-specific stat snapshots")
local snapshotCleared = data:ClearStatSnapshot(snapshotBuild.id, snapshotSetup.id, "front")
expect(snapshotCleared, "stat snapshots should be removable")
expectEqual(snapshotSetup.statSnapshots, nil, "clearing should remove the snapshot")

local markedBuild = data:CreateBuild("|cFF0000Marked Build|r")
expect(markedBuild and markedBuild.name == "Marked Build",
    "ordinary user names should neutralize ESO color markup")
data:DeleteBuild(markedBuild.id)
local invalidRequirementCases = {
    { slot = "head", value = { armorType = 99 } },
    { slot = "frontMain", value = { weaponType = 999 } },
    { slot = "head", value = { armorType = 1, traitType = 999 } },
    { slot = "head", value = { armorType = 1, enchantmentCategory = 999 } },
    { slot = "head", value = { armorType = 1, quality = 99 } },
    { slot = "head", value = { armorType = 1, level = 51 } },
    { slot = "head", value = { armorType = 1, championPoints = 155 } },
    { slot = "head", value = { armorType = 1, setId = 0 } },
}
for _, case in ipairs(invalidRequirementCases) do
    expectEqual(data:SetEquipment(snapshotBuild.id, snapshotSetup.id, case.slot, case.value), false,
        "invalid equipment enum and numeric values should be rejected")
end
local excessiveSetups = { name = "Too Many", setups = {} }
for index = 1, 101 do
    excessiveSetups.setups[index] = { name = "Setup " .. tostring(index), equipment = {} }
end
expectEqual(data:ImportBuild(excessiveSetups), nil,
    "model imports should enforce the setup-count limit")

TEST_SAVED = {
    nextBuildId = 1,
    nextSetupId = 1,
    selectedBuildId = 99,
    deletedActions = {},
    builds = {
        "invalid",
        {
            id = 4,
            name = "Duplicate",
            setups = {
                {
                    id = 8,
                    name = "Setup",
                    equipment = { invalid = {}, frontOff = { weaponType = WEAPONTYPE_BOW } },
                    statSnapshot = {
                        characterName = "Legacy Warden",
                        createdAt = 900,
                        values = { maxHealth = 30000 },
                    },
                },
                { id = 8, name = "Setup", equipment = {} },
            },
        },
        { id = 4, name = "Duplicate", setups = {} },
    },
}

local repaired = GravvyBuildPlannerData:New()
expectEqual(#repaired.saved.builds, 2, "invalid build records should be removed")
expect(repaired.saved.builds[1].id ~= repaired.saved.builds[2].id, "duplicate build ids should be repaired")
expect(repaired.saved.builds[1].name ~= repaired.saved.builds[2].name, "duplicate build names should be repaired")
expect(repaired.saved.builds[1].setups[1].id ~= repaired.saved.builds[1].setups[2].id, "duplicate setup ids should be repaired")
expect(repaired.saved.builds[1].setups[1].name ~= repaired.saved.builds[1].setups[2].name, "duplicate setup names should be repaired")
expectEqual(repaired.saved.builds[1].setups[1].equipment.frontOff, nil, "invalid two-handed off-hand should be removed")
expect(
    type(repaired.saved.builds[1].setups[1].alternatives) == "table",
    "migration should add ordered slot alternatives"
)
expectEqual(repaired.saved.schemaVersion, 11, "migration should advance the saved-data schema")
expectEqual(#repaired.saved.builds[1].revisions, 0,
    "migration should add empty revision history")
expectEqual(repaired.saved.builds[1].setups[1].character.raceId, 0, "migration should add character defaults")
expectEqual(repaired.saved.builds[1].setups[1].champion.craft.slottables[4], 0,
    "migration should add Champion defaults")
expectEqual(#repaired.saved.builds[1].setups[1].consumables, 0,
    "migration should add consumable defaults")
expectEqual(#repaired.saved.builds[1].setups[1].checklist, 0,
    "migration should add checklist defaults")
expectEqual(repaired.saved.builds[1].setups[1].statSnapshots.front.values.maxHealth,
    30000, "migration should move legacy exact stats to the front-bar snapshot")
expect(repaired:FindBuild(repaired.saved.selectedBuildId), "selected build should be repaired")

local collectionSets = {
    [12] = "Order's Wrath",
    [34] = "Pillar of Nirn",
}
LibSets = {
    checkIfSetsAreLoadedProperly = function() return true end,
    GetAllSetIds = function()
        return { [12] = true, [34] = true, [101] = true }
    end,
    GetSetName = function(setId)
        return collectionSets[setId] or (setId == 101 and "Highland Sentinel")
    end,
    IsCraftedSet = function(setId) return setId == 101 end,
}
function GetNextItemSetCollectionId(lastId)
    if lastId == nil then
        return 12
    elseif lastId == 12 then
        return 34
    end
end

function GetItemSetName(setId)
    return collectionSets[setId]
end

dofile("SetCatalog.lua")
local catalog = GravvyBuildPlannerSetCatalog:New(data)
expectEqual(catalog:FindExact("pillar of nirn").setId, 34, "set lookup should ignore case")
expect(catalog:FindExact("Whorl of the Depths"), "saved manual sets should be searchable")
expectEqual(catalog:FindExact("Highland Sentinel").setId, 101, "LibSets crafted sets should be searchable")
expectEqual(catalog:Search("nirn")[1].name, "Pillar of Nirn", "set search should match within names")
local catalogBuild = data:CreateBuild("Catalog Alternative Test")
local catalogSetup = data:GetCurrentSetup()
data:SetEquipment(catalogBuild.id, catalogSetup.id, "head", {
    setName = "Catalog Primary",
    armorType = 1,
})
data:SetAlternative(catalogBuild.id, catalogSetup.id, "head", nil, {
    setName = "Website Alternative Only",
    armorType = 1,
})
catalog:Refresh()
expect(catalog:FindExact("Website Alternative Only"),
    "alternative-only saved sets should be rebuilt into autocomplete")
data:DeleteBuild(catalogBuild.id)
catalog:Refresh()

BuildPlannerTestData = data
BuildPlannerTestCatalog = catalog

print("Build Planner data tests passed")
