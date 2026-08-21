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

function zo_strformat(id, value)
    return GetString(id):gsub("<<1>>", value)
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

local data = GravvyBuildPlannerData:New()
local firstBuild = data:GetCurrentBuild()
local firstSetup = data:GetCurrentSetup()
expectEqual(#data:GetBuilds(), 1, "clean install should create one build")
expectEqual(firstSetup.defaultChampionPoints, 160, "default CP")
expectEqual(firstSetup.defaultQuality, ITEM_QUALITY_LEGENDARY, "default quality")

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

ok = data:SetEquipment(build.id, setup.id, "waist", { weaponType = WEAPONTYPE_AXE })
expect(not ok, "weapon type should not be accepted in an armor slot")

ok = data:SetEquipment(build.id, setup.id, "frontOff", { weaponType = WEAPONTYPE_AXE })
expect(ok, "one-handed off-hand should be accepted")
local _, twoHanded, clearedSlot = data:SetEquipment(build.id, setup.id, "frontMain", {
    setName = "Perfected Merciless Charge",
    weaponType = WEAPONTYPE_TWO_HANDED_SWORD,
})
expect(twoHanded, "two-handed main weapon should be accepted")
expectEqual(clearedSlot, "frontOff", "two-handed weapon should clear off-hand")
expectEqual(setup.equipment.frontOff, nil, "off-hand should be empty")
ok = data:SetEquipment(build.id, setup.id, "frontOff", { weaponType = WEAPONTYPE_AXE })
expect(not ok, "occupied off-hand should reject requirements")
ok = data:SetEquipment(build.id, setup.id, "frontMain", { weaponType = WEAPONTYPE_AXE })
expect(ok, "one-handed main weapon should replace two-handed weapon")
ok = data:SetEquipment(build.id, setup.id, "frontOff", { weaponType = WEAPONTYPE_SHIELD })
expect(ok, "shield should be accepted off-hand")
ok = data:SetEquipment(build.id, setup.id, "frontMain", { weaponType = WEAPONTYPE_SHIELD })
expect(not ok, "shield should not be accepted main-hand")

local oldName = build.name
ok = data:UpdateBuild(build.id, { name = "Changed", role = 7 })
expect(not ok, "invalid metadata update should fail")
expectEqual(build.name, oldName, "failed update should not partially rename build")

local variant = data:DuplicateSetup(build.id, setup.id)
expect(variant, "setup should be duplicated")
expect(variant.equipment.waist ~= setup.equipment.waist, "equipment should be copied")
expectEqual(next(variant.acquisition), nil, "setup copy should not copy acquisition state")

local duplicate = data:DuplicateBuild(build.id)
expect(duplicate, "build should be duplicated")
expectEqual(#duplicate.setups, #build.setups, "all setups should be copied")
expect(duplicate.setups[1].equipment ~= build.setups[1].equipment, "build equipment should be copied")
expectEqual(next(duplicate.setups[1].acquisition), nil, "build copy should not copy acquisition state")

ok = data:DeleteBuild(duplicate.id)
expect(ok, "build should be deleted")
ok = data:UndoLastDeletion()
expect(ok, "deleted build should be restored")
expect(data:FindBuild(duplicate.id), "restored build should retain its id")

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
expect(repaired:FindBuild(repaired.saved.selectedBuildId), "selected build should be repaired")

local collectionSets = {
    [12] = "Order's Wrath",
    [34] = "Pillar of Nirn",
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
expectEqual(catalog:Search("nirn")[1].name, "Pillar of Nirn", "set search should match within names")

BuildPlannerTestData = data
BuildPlannerTestCatalog = catalog

print("Build Planner data tests passed")
