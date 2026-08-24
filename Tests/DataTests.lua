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
    traitType = 12,
    enchantmentName = "Magicka",
})
expect(ok, "armor requirement should be accepted")
ok = data:SetPreferredRoute(build.id, setup.id, "waist", "buy")
expect(ok, "a supported acquisition route should be saved")
expectEqual(setup.acquisition.waist.preferredRoute, "buy", "the preferred route should remain separate from equipment")
expect(not data:SetPreferredRoute(build.id, setup.id, "waist", "teleport"), "unknown acquisition routes should be rejected")

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
expect(variant.alternativeGroups ~= setup.alternativeGroups, "future alternate groups should be copied independently")
expectEqual(next(variant.acquisition), nil, "setup copy should not copy acquisition state")

local duplicate = data:DuplicateBuild(build.id)
expect(duplicate, "build should be duplicated")
expectEqual(#duplicate.setups, #build.setups, "all setups should be copied")
expect(duplicate.setups[1].equipment ~= build.setups[1].equipment, "build equipment should be copied")
expect(
    duplicate.setups[1].alternativeGroups ~= build.setups[1].alternativeGroups,
    "build copies should not share future alternate groups"
)
expectEqual(next(duplicate.setups[1].acquisition), nil, "build copy should not copy acquisition state")

ok = data:DeleteBuild(duplicate.id)
expect(ok, "build should be deleted")
ok = data:UndoLastDeletion()
expect(ok, "deleted build should be restored")
expect(data:FindBuild(duplicate.id), "restored build should retain its id")

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
local damaged = shareCode:sub(1, -2) .. (shareCode:sub(-1) == "A" and "B" or "A")
expectEqual(GravvyBuildPlannerShare.DecodeCode(damaged), nil, "damaged share codes should fail their checksum")
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
                { id = 8, name = "Setup", equipment = { invalid = {}, frontOff = { weaponType = WEAPONTYPE_BOW } } },
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
    type(repaired.saved.builds[1].setups[1].alternativeGroups) == "table",
    "migration should add the alternate-group extension point"
)
expectEqual(repaired.saved.schemaVersion, 2, "migration should advance the saved-data schema")
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

BuildPlannerTestData = data
BuildPlannerTestCatalog = catalog

print("Build Planner data tests passed")
