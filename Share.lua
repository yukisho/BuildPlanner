GravvyBuildPlannerShare = {}

local Share = GravvyBuildPlannerShare
local Slots = GravvyBuildPlannerSlots
local PREFIX = "GBP1:"
local FORMAT_VERSION = 7
local MAX_CODE_LENGTH = 100000
local MAX_SETUPS = 100
local MAX_STRING = 512
local MAX_NOTE = 4000
local MAX_LINK = 2048
local MAX_SUBCLASS_NAME = 100
local MAX_RACE_ID = 10
local MAX_CHAMPION_ALLOCATIONS = 200
local MAX_CHAMPION_POINTS = 1000
local MAX_CONSUMABLES = 20
local MAX_CHECKLIST_ENTRIES = 100
local MAX_U32 = 4294967295
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local DECODE = {}

local buildStrings = {
    { key = "name", max = MAX_STRING, required = true },
    { key = "role", max = MAX_STRING },
    { key = "patch", max = MAX_STRING },
    { key = "author", max = MAX_STRING },
    { key = "sourceUrl", max = MAX_STRING },
    { key = "notes", max = MAX_NOTE },
}
local requirementStrings = {
    { key = "setName", max = MAX_STRING },
    { key = "itemName", max = MAX_STRING },
    { key = "itemLink", max = MAX_LINK },
    { key = "enchantmentName", max = MAX_STRING },
    { key = "note", max = MAX_NOTE },
}
local requirementNumbers = {
    "setId",
    "itemId",
    "armorType",
    "weaponType",
    "traitType",
    "enchantmentId",
    "enchantmentCategory",
    "quality",
    "level",
    "championPoints",
}
local routeValues = {
    buy = 1,
    craft = 2,
    farm = 3,
    reconstruct = 4,
    transmute = 5,
    unknown = 6,
}
local routeNames = {}
for name, value in pairs(routeValues) do
    routeNames[value] = name
end
local consumableCategoryValues = {
    food = 1,
    drink = 2,
    potion = 3,
    poison = 4,
    other = 5,
}
local consumableCategoryNames = {}
for name, value in pairs(consumableCategoryValues) do
    consumableCategoryNames[value] = name
end
local checklistCategoryValues = {
    passive = 1,
    skillLine = 2,
    unlock = 3,
    other = 4,
}
local checklistCategoryNames = {}
for name, value in pairs(checklistCategoryValues) do
    checklistCategoryNames[value] = name
end

Share.PREFIX = PREFIX
Share.MAX_CODE_LENGTH = MAX_CODE_LENGTH

for index = 1, #ALPHABET do
    DECODE[string.sub(ALPHABET, index, index)] = index - 1
end

local function trim(value)
    return string.match(value or "", "^%s*(.-)%s*$")
end

local function encodeBase64(value)
    local result = {}
    for position = 1, #value, 3 do
        local first = string.byte(value, position)
        local second = string.byte(value, position + 1)
        local third = string.byte(value, position + 2)
        local packed = (first * 65536) + ((second or 0) * 256) + (third or 0)
        result[#result + 1] = string.sub(ALPHABET, math.floor(packed / 262144) + 1, math.floor(packed / 262144) + 1)
        result[#result + 1] = string.sub(ALPHABET, (math.floor(packed / 4096) % 64) + 1, (math.floor(packed / 4096) % 64) + 1)
        if second then
            result[#result + 1] = string.sub(ALPHABET, (math.floor(packed / 64) % 64) + 1, (math.floor(packed / 64) % 64) + 1)
        end
        if third then
            result[#result + 1] = string.sub(ALPHABET, (packed % 64) + 1, (packed % 64) + 1)
        end
    end
    return table.concat(result)
end

local function decodeBase64(value)
    if value == "" or #value % 4 == 1 then
        return nil
    end
    local result = {}
    for position = 1, #value, 4 do
        local first = DECODE[string.sub(value, position, position)]
        local second = DECODE[string.sub(value, position + 1, position + 1)]
        local thirdCharacter = string.sub(value, position + 2, position + 2)
        local fourthCharacter = string.sub(value, position + 3, position + 3)
        local third = thirdCharacter ~= "" and DECODE[thirdCharacter] or nil
        local fourth = fourthCharacter ~= "" and DECODE[fourthCharacter] or nil
        if first == nil or second == nil
            or (thirdCharacter ~= "" and third == nil)
            or (fourthCharacter ~= "" and fourth == nil) then
            return nil
        end
        local packed = (first * 262144) + (second * 4096)
            + ((third or 0) * 64) + (fourth or 0)
        result[#result + 1] = string.char(math.floor(packed / 65536) % 256)
        if third ~= nil then
            result[#result + 1] = string.char(math.floor(packed / 256) % 256)
        end
        if fourth ~= nil then
            result[#result + 1] = string.char(packed % 256)
        end
    end
    return table.concat(result)
end

local function appendU16(parts, value)
    parts[#parts + 1] = string.char(math.floor(value / 256) % 256, value % 256)
end

local function appendU32(parts, value)
    parts[#parts + 1] = string.char(
        math.floor(value / 16777216) % 256,
        math.floor(value / 65536) % 256,
        math.floor(value / 256) % 256,
        value % 256
    )
end

local function appendString(parts, value)
    appendU16(parts, #value)
    parts[#parts + 1] = value
end

local function checksum(value)
    local first = 1
    local second = 0
    for index = 1, #value do
        first = (first + string.byte(value, index)) % 65521
        second = (second + first) % 65521
    end
    return (second * 65536) + first
end

local function wholeNumber(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= math.floor(value) or value < minimum or value > maximum then
        return nil
    end
    return value
end

local function appendOptionalU32(parts, value)
    if value == nil then
        appendU32(parts, 0)
        return true
    end
    value = wholeNumber(value, 0, MAX_U32 - 1)
    if not value then
        return false
    end
    appendU32(parts, value + 1)
    return true
end

local function makeReader(payload)
    local position = 1
    local reader = {}
    function reader:Byte()
        local value = string.byte(payload, position)
        position = position + 1
        return value
    end
    function reader:U16()
        local first, second = self:Byte(), self:Byte()
        return first and second and ((first * 256) + second) or nil
    end
    function reader:U32()
        local first, second, third, fourth = self:Byte(), self:Byte(), self:Byte(), self:Byte()
        return first and second and third and fourth
            and ((first * 16777216) + (second * 65536) + (third * 256) + fourth)
            or nil
    end
    function reader:String(maxLength, required)
        local length = self:U16()
        if not length or length > maxLength or position + length - 1 > #payload then
            return nil
        end
        local value = string.sub(payload, position, position + length - 1)
        position = position + length
        if required and trim(value) == "" then
            return nil
        end
        return value
    end
    function reader:IsDone()
        return position == #payload + 1
    end
    return reader
end

local function readOptionalU32(reader)
    local value = reader:U32()
    if value == 0 then
        return nil, true
    end
    return value and value - 1 or nil, value ~= nil
end

function Share.EncodeBuild(build)
    if type(build) ~= "table" or type(build.setups) ~= "table"
        or #build.setups == 0 or #build.setups > MAX_SETUPS then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
    end

    local parts = { string.char(FORMAT_VERSION) }
    for _, field in ipairs(buildStrings) do
        local value = tostring(build[field.key] or "")
        if #value > field.max or (field.required and trim(value) == "") then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        appendString(parts, value)
    end
    if not appendOptionalU32(parts, build.classId) then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
    end
    appendU16(parts, #build.setups)
    local selectedSetupIndex = 1
    for index, setup in ipairs(build.setups) do
        if setup.id == build.selectedSetupId then
            selectedSetupIndex = index
            break
        end
    end
    appendU16(parts, selectedSetupIndex)

    for _, setup in ipairs(build.setups) do
        local setupName = tostring(setup.name or "")
        local setupNote = tostring(setup.note or "")
        local quality = wholeNumber(setup.defaultQuality, 0, 65535)
        local level = wholeNumber(setup.defaultLevel, 1, 65535)
        local championPoints = wholeNumber(setup.defaultChampionPoints, 0, MAX_U32)
        if trim(setupName) == "" or #setupName > MAX_STRING or #setupNote > MAX_NOTE
            or not quality or not level or not championPoints
            or type(setup.equipment) ~= "table" then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        appendString(parts, setupName)
        appendString(parts, setupNote)
        appendU16(parts, quality)
        appendU16(parts, level)
        appendU32(parts, championPoints)

        local count = 0
        for slotKey, requirement in pairs(setup.equipment) do
            if not Slots:IsValid(slotKey)
                or type(requirement) ~= "table"
                or not Slots:IsRequirementCompatible(slotKey, requirement) then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
        end
        for _, slotKey in ipairs(Slots.ORDER) do
            if setup.equipment[slotKey] then
                count = count + 1
            end
        end
        parts[#parts + 1] = string.char(count)
        for slotIndex, slotKey in ipairs(Slots.ORDER) do
            local requirement = setup.equipment[slotKey]
            if requirement then
                parts[#parts + 1] = string.char(slotIndex)
                for _, field in ipairs(requirementStrings) do
                    local value = tostring(requirement[field.key] or "")
                    if #value > field.max then
                        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                    end
                    appendString(parts, value)
                end
                for _, key in ipairs(requirementNumbers) do
                    if not appendOptionalU32(parts, requirement[key]) then
                        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                    end
                end
                local state = setup.acquisition and setup.acquisition[slotKey]
                local route = state and routeValues[state.preferredRoute] or 0
                if state and not route then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                parts[#parts + 1] = string.char(route)
            end
        end

        local alternativeSlotCount = 0
        for slotKey, alternatives in pairs(setup.alternatives or {}) do
            if not Slots:IsValid(slotKey) or not setup.equipment[slotKey]
                or type(alternatives) ~= "table" or #alternatives > 8 then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            if #alternatives > 0 then
                alternativeSlotCount = alternativeSlotCount + 1
            end
        end
        parts[#parts + 1] = string.char(alternativeSlotCount)
        for slotIndex, slotKey in ipairs(Slots.ORDER) do
            local alternatives = setup.alternatives and setup.alternatives[slotKey]
            if alternatives and #alternatives > 0 then
                parts[#parts + 1] = string.char(slotIndex)
                parts[#parts + 1] = string.char(#alternatives)
                for _, requirement in ipairs(alternatives) do
                    if type(requirement) ~= "table"
                        or not Slots:IsRequirementCompatible(slotKey, requirement) then
                        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                    end
                    for _, field in ipairs(requirementStrings) do
                        local value = tostring(requirement[field.key] or "")
                        if #value > field.max then
                            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                        end
                        appendString(parts, value)
                    end
                    for _, key in ipairs(requirementNumbers) do
                        if not appendOptionalU32(parts, requirement[key]) then
                            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                        end
                    end
                end
            end
        end
        for _, barKey in ipairs({ "front", "back" }) do
            local bar = setup.skillBars and setup.skillBars[barKey] or {}
            local mask = 0
            for slotIndex = 1, 6 do
                if bar[slotIndex] then
                    mask = mask + (2 ^ (slotIndex - 1))
                end
            end
            parts[#parts + 1] = string.char(mask)
            for slotIndex = 1, 6 do
                local skill = bar[slotIndex]
                if skill then
                    local abilityId = wholeNumber(skill.abilityId, 1, MAX_U32)
                    local name = tostring(skill.name or "")
                    local icon = tostring(skill.icon or "")
                    if not abilityId or #name > MAX_STRING or #icon > MAX_STRING
                        or skill.isUltimate ~= (slotIndex == 6) then
                        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                    end
                    appendU32(parts, abilityId)
                    appendString(parts, name)
                    appendString(parts, icon)
                end
            end
        end

        local character = setup.character or {}
        local attributes = character.attributes or {}
        local health = wholeNumber(attributes.health or 0, 0, 64)
        local magicka = wholeNumber(attributes.magicka or 0, 0, 64)
        local stamina = wholeNumber(attributes.stamina or 0, 0, 64)
        local raceId = wholeNumber(character.raceId or 0, 0, MAX_RACE_ID)
        local mundus = wholeNumber(character.mundus or 0, 0, 13)
        local curse = wholeNumber(character.curse or 0, 0, 2)
        if not health or not magicka or not stamina or health + magicka + stamina > 64
            or not raceId or not mundus or not curse then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        parts[#parts + 1] = string.char(health, magicka, stamina, raceId, mundus, curse)
        local subclassLines = character.subclassLines or {}
        for index = 1, 3 do
            local lineName = tostring(subclassLines[index] or "")
            if #lineName > MAX_SUBCLASS_NAME then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            appendString(parts, lineName)
        end

        local champion = setup.champion or {}
        local seenChampionSkills = {}
        for _, disciplineKey in ipairs({ "craft", "warfare", "fitness" }) do
            local discipline = champion[disciplineKey] or {}
            local allocations = discipline.allocations or {}
            if type(allocations) ~= "table" or #allocations > MAX_CHAMPION_ALLOCATIONS then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            appendU16(parts, #allocations)
            local slottableIds = {}
            for _, allocation in ipairs(allocations) do
                local skillId = wholeNumber(allocation.skillId, 1, MAX_U32)
                local points = wholeNumber(allocation.points, 1, MAX_CHAMPION_POINTS)
                local name = tostring(allocation.name or "")
                local icon = tostring(allocation.icon or "")
                if not skillId or seenChampionSkills[skillId] or not points
                    or name == "" or #name > MAX_SUBCLASS_NAME or #icon > MAX_STRING
                    or type(allocation.isSlottable) ~= "boolean" then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                seenChampionSkills[skillId] = true
                slottableIds[skillId] = allocation.isSlottable
                appendU32(parts, skillId)
                appendU16(parts, points)
                parts[#parts + 1] = string.char(allocation.isSlottable and 1 or 0)
                appendString(parts, name)
                appendString(parts, icon)
            end
            local seenSlots = {}
            for slotIndex = 1, 4 do
                local skillId = wholeNumber(
                    discipline.slottables and discipline.slottables[slotIndex] or 0,
                    0,
                    MAX_U32
                )
                if not skillId or (skillId > 0
                    and (not slottableIds[skillId] or seenSlots[skillId])) then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                seenSlots[skillId] = skillId > 0 or nil
                appendU32(parts, skillId)
            end
        end

        local consumables = setup.consumables or {}
        if type(consumables) ~= "table" or #consumables > MAX_CONSUMABLES then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        parts[#parts + 1] = string.char(#consumables)
        local seenConsumables = {}
        for _, entry in ipairs(consumables) do
            local category = consumableCategoryValues[entry.category]
            local name = tostring(entry.name or "")
            local itemLink = tostring(entry.itemLink or "")
            local icon = tostring(entry.icon or "")
            local note = tostring(entry.note or "")
            local quantity = wholeNumber(entry.quantity or 1, 1, 9999)
            local itemId = entry.itemId == nil or wholeNumber(entry.itemId, 1, MAX_U32 - 1)
            local key = category and tostring(category) .. "\31" .. zo_strlower(name)
            if not category or seenConsumables[key] or name == "" or #name > MAX_SUBCLASS_NAME
                or #itemLink > MAX_LINK or #icon > MAX_STRING or #note > MAX_NOTE
                or not quantity or not itemId then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            seenConsumables[key] = true
            parts[#parts + 1] = string.char(category)
            appendString(parts, name)
            appendString(parts, itemLink)
            appendString(parts, icon)
            appendU16(parts, quantity)
            appendString(parts, note)
            appendOptionalU32(parts, entry.itemId)
        end

        local checklist = setup.checklist or {}
        if type(checklist) ~= "table" or #checklist > MAX_CHECKLIST_ENTRIES then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        parts[#parts + 1] = string.char(#checklist)
        local seenChecklist = {}
        for _, entry in ipairs(checklist) do
            local category = checklistCategoryValues[entry.category]
            local name = tostring(entry.name or "")
            local note = tostring(entry.note or "")
            local icon = tostring(entry.icon or "")
            local targetRank = entry.targetRank
                and wholeNumber(entry.targetRank, 1, 50)
            local abilityId = entry.abilityId
                and wholeNumber(entry.abilityId, 1, MAX_U32 - 1)
            local key = category and tostring(category) .. "\31" .. zo_strlower(name)
            if not category or seenChecklist[key] or name == ""
                or #name > MAX_SUBCLASS_NAME or #note > MAX_NOTE or #icon > MAX_STRING
                or (entry.targetRank ~= nil and not targetRank)
                or (entry.abilityId ~= nil and not abilityId) then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            seenChecklist[key] = true
            parts[#parts + 1] = string.char(category)
            appendString(parts, name)
            parts[#parts + 1] = string.char(targetRank or 0)
            parts[#parts + 1] = string.char(entry.completed == true and 1 or 0)
            appendOptionalU32(parts, abilityId)
            appendString(parts, icon)
            appendString(parts, note)
        end
    end

    local body = table.concat(parts)
    local payload = { body }
    appendU32(payload, checksum(body))
    local code = PREFIX .. encodeBase64(table.concat(payload))
    if #code > MAX_CODE_LENGTH then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_LONG)
    end
    return code
end

function Share.DecodeCode(code)
    code = trim(code)
    if #code > MAX_CODE_LENGTH then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_LONG)
    end
    if string.sub(code, 1, #PREFIX) ~= PREFIX then
        return nil, zo_strformat(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_PREFIX, PREFIX)
    end
    local payload = decodeBase64(string.sub(code, #PREFIX + 1))
    if not payload or #payload < 5 then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_INVALID)
    end
    local body = string.sub(payload, 1, #payload - 4)
    local checksumReader = makeReader(string.sub(payload, #payload - 3))
    if checksumReader:U32() ~= checksum(body) then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_INVALID)
    end

    local reader = makeReader(body)
    local version = reader:Byte()
    if not version or version < 1 or version > FORMAT_VERSION then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_VERSION)
    end
    local build = { setups = {} }
    for _, field in ipairs(buildStrings) do
        build[field.key] = reader:String(field.max, field.required)
        if build[field.key] == nil then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
    end
    local classId, classOk = readOptionalU32(reader)
    local setupCount = reader:U16()
    local selectedSetupIndex = reader:U16()
    if not classOk or not setupCount or setupCount < 1 or setupCount > MAX_SETUPS then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
    end
    if not selectedSetupIndex or selectedSetupIndex < 1 or selectedSetupIndex > setupCount then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
    end
    build.classId = classId
    build.selectedSetupIndex = selectedSetupIndex

    for _ = 1, setupCount do
        local setup = {
            name = reader:String(MAX_STRING, true),
            note = reader:String(MAX_NOTE, false),
            defaultQuality = reader:U16(),
            defaultLevel = reader:U16(),
            defaultChampionPoints = reader:U32(),
            equipment = {},
            alternatives = {},
            skillBars = { front = {}, back = {} },
            character = {
                attributes = { health = 0, magicka = 0, stamina = 0 },
                raceId = 0,
                mundus = 0,
                curse = 0,
                subclassLines = { "", "", "" },
            },
            champion = {
                craft = { allocations = {}, slottables = { 0, 0, 0, 0 } },
                warfare = { allocations = {}, slottables = { 0, 0, 0, 0 } },
                fitness = { allocations = {}, slottables = { 0, 0, 0, 0 } },
            },
            consumables = {},
            checklist = {},
            acquisition = {},
        }
        local equipmentCount = reader:Byte()
        if not setup.name or setup.note == nil or not setup.defaultQuality
            or not setup.defaultLevel or setup.defaultLevel < 1
            or not setup.defaultChampionPoints or not equipmentCount
            or equipmentCount > #Slots.ORDER then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        local seenSlots = {}
        for _ = 1, equipmentCount do
            local slotIndex = reader:Byte()
            local slotKey = slotIndex and Slots.ORDER[slotIndex]
            if not slotKey or seenSlots[slotKey] then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            seenSlots[slotKey] = true
            local requirement = {}
            for _, field in ipairs(requirementStrings) do
                local value = reader:String(field.max, false)
                if value == nil then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                if value ~= "" then
                    requirement[field.key] = value
                end
            end
            for _, key in ipairs(requirementNumbers) do
                local value, ok = readOptionalU32(reader)
                if not ok then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                requirement[key] = value
            end
            local route = reader:Byte()
            if route == nil or (route ~= 0 and not routeNames[route]) then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            if not Slots:IsRequirementCompatible(slotKey, requirement) then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            setup.equipment[slotKey] = requirement
            if route ~= 0 then
                setup.acquisition[slotKey] = { preferredRoute = routeNames[route] }
            end
        end
        if version >= 2 then
            local alternativeSlotCount = reader:Byte()
            if not alternativeSlotCount or alternativeSlotCount > #Slots.ORDER then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            local seenAlternativeSlots = {}
            for _ = 1, alternativeSlotCount do
                local slotIndex = reader:Byte()
                local slotKey = slotIndex and Slots.ORDER[slotIndex]
                local alternativeCount = reader:Byte()
                if not slotKey or seenAlternativeSlots[slotKey]
                    or not setup.equipment[slotKey]
                    or not alternativeCount or alternativeCount < 1
                    or alternativeCount > 8 then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                seenAlternativeSlots[slotKey] = true
                setup.alternatives[slotKey] = {}
                for _ = 1, alternativeCount do
                    local requirement = {}
                    for _, field in ipairs(requirementStrings) do
                        local value = reader:String(field.max, false)
                        if value == nil then
                            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                        end
                        if value ~= "" then
                            requirement[field.key] = value
                        end
                    end
                    for _, key in ipairs(requirementNumbers) do
                        local value, ok = readOptionalU32(reader)
                        if not ok then
                            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                        end
                        requirement[key] = value
                    end
                    if not Slots:IsRequirementCompatible(slotKey, requirement) then
                        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                    end
                    setup.alternatives[slotKey][#setup.alternatives[slotKey] + 1] = requirement
                end
            end
        end
        if version >= 3 then
            for _, barKey in ipairs({ "front", "back" }) do
                local mask = reader:Byte()
                if not mask or mask > 63 then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                for slotIndex = 1, 6 do
                    if math.floor(mask / (2 ^ (slotIndex - 1))) % 2 == 1 then
                        local abilityId = reader:U32()
                        local name = reader:String(MAX_STRING, false)
                        local icon = reader:String(MAX_STRING, false)
                        if not abilityId or abilityId < 1 or name == nil or icon == nil then
                            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                        end
                        setup.skillBars[barKey][slotIndex] = {
                            abilityId = abilityId,
                            name = name,
                            icon = icon,
                            isUltimate = slotIndex == 6,
                        }
                    end
                end
            end
        end
        if version >= 4 then
            local health = reader:Byte()
            local magicka = reader:Byte()
            local stamina = reader:Byte()
            local raceId = reader:Byte()
            local mundus = reader:Byte()
            local curse = reader:Byte()
            if not health or health > 64 or not magicka or magicka > 64
                or not stamina or stamina > 64 or health + magicka + stamina > 64
                or not raceId or raceId > MAX_RACE_ID or not mundus or mundus > 13
                or not curse or curse > 2 then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            setup.character.attributes.health = health
            setup.character.attributes.magicka = magicka
            setup.character.attributes.stamina = stamina
            setup.character.raceId = raceId
            setup.character.mundus = mundus
            setup.character.curse = curse
            for index = 1, 3 do
                local lineName = reader:String(MAX_SUBCLASS_NAME, false)
                if lineName == nil then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                setup.character.subclassLines[index] = lineName
            end
        end
        if version >= 5 then
            local seenChampionSkills = {}
            for _, disciplineKey in ipairs({ "craft", "warfare", "fitness" }) do
                local discipline = setup.champion[disciplineKey]
                local allocationCount = reader:U16()
                if not allocationCount or allocationCount > MAX_CHAMPION_ALLOCATIONS then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                local allocationsById = {}
                for _ = 1, allocationCount do
                    local skillId = reader:U32()
                    local points = reader:U16()
                    local flags = reader:Byte()
                    local name = reader:String(MAX_SUBCLASS_NAME, true)
                    local icon = reader:String(MAX_STRING, false)
                    if not skillId or skillId < 1 or seenChampionSkills[skillId]
                        or not points or points < 1 or points > MAX_CHAMPION_POINTS
                        or flags == nil or flags > 1 or not name or icon == nil then
                        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                    end
                    local allocation = {
                        skillId = skillId,
                        points = points,
                        name = name,
                        icon = icon,
                        isSlottable = flags == 1,
                    }
                    seenChampionSkills[skillId] = true
                    allocationsById[skillId] = allocation
                    discipline.allocations[#discipline.allocations + 1] = allocation
                end
                local seenSlots = {}
                for slotIndex = 1, 4 do
                    local skillId = reader:U32()
                    local allocation = skillId and skillId > 0 and allocationsById[skillId]
                    if skillId == nil or (skillId > 0 and (not allocation
                        or not allocation.isSlottable or seenSlots[skillId])) then
                        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                    end
                    if skillId > 0 then
                        seenSlots[skillId] = true
                    end
                    discipline.slottables[slotIndex] = skillId
                end
            end
        end
        if version >= 6 then
            local count = reader:Byte()
            if not count or count > MAX_CONSUMABLES then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            local seenConsumables = {}
            for _ = 1, count do
                local categoryValue = reader:Byte()
                local category = categoryValue and consumableCategoryNames[categoryValue]
                local name = reader:String(MAX_SUBCLASS_NAME, true)
                local itemLink = reader:String(MAX_LINK, false)
                local icon = reader:String(MAX_STRING, false)
                local quantity = reader:U16()
                local note = reader:String(MAX_NOTE, false)
                local itemId, itemIdOk = readOptionalU32(reader)
                local key = category and tostring(categoryValue) .. "\31" .. zo_strlower(name or "")
                if not category or seenConsumables[key] or not name
                    or itemLink == nil or icon == nil or not quantity
                    or quantity < 1 or quantity > 9999 or note == nil or not itemIdOk then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                seenConsumables[key] = true
                setup.consumables[#setup.consumables + 1] = {
                    category = category,
                    name = name,
                    itemId = itemId,
                    itemLink = itemLink ~= "" and itemLink or nil,
                    icon = icon,
                    quantity = quantity,
                    note = note,
                }
            end
        end
        if version >= 7 then
            local count = reader:Byte()
            if not count or count > MAX_CHECKLIST_ENTRIES then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            local seenChecklist = {}
            for _ = 1, count do
                local categoryValue = reader:Byte()
                local category = categoryValue and checklistCategoryNames[categoryValue]
                local name = reader:String(MAX_SUBCLASS_NAME, true)
                local targetRank = reader:Byte()
                local completed = reader:Byte()
                local abilityId, abilityIdOk = readOptionalU32(reader)
                local icon = reader:String(MAX_STRING, false)
                local note = reader:String(MAX_NOTE, false)
                local key = category and tostring(categoryValue) .. "\31"
                    .. zo_strlower(name or "")
                if not category or seenChecklist[key] or not name or not targetRank
                    or targetRank > 50 or (completed ~= 0 and completed ~= 1)
                    or not abilityIdOk or icon == nil or note == nil then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                seenChecklist[key] = true
                setup.checklist[#setup.checklist + 1] = {
                    category = category,
                    name = name,
                    targetRank = targetRank > 0 and targetRank or nil,
                    completed = completed == 1,
                    abilityId = abilityId,
                    icon = icon,
                    note = note,
                }
            end
        end
        build.setups[#build.setups + 1] = setup
    end
    if not reader:IsDone() then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_INVALID)
    end
    return build
end

local function makeLabel(parent, text, x, y, width, font)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    GravvyBuildPlannerAccessibility:SetFont(label, font or "ZoFontGame")
    label:SetText(text or "")
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    label:SetDimensions(width, 30)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return label
end

local function makeButton(parent, text, width)
    local button = WINDOW_MANAGER:CreateControl(nil, parent, CT_BUTTON)
    button:SetDimensions(width, 28)
    GravvyBuildPlannerAccessibility:SetFont(button, "ZoFontGame")
    button:SetText(text)
    button:SetNormalFontColor(0.85, 0.78, 0.62, 1)
    button:SetMouseOverFontColor(1, 1, 1, 1)
    return button
end

function Share:New(owner)
    return setmetatable({ owner = owner }, { __index = self })
end

function Share:Initialize()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("GravvyBuildPlannerShareWindow")
    window:SetDimensions(700, 390)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetMouseEnabled(true)
    window:SetMovable(true)
    window:SetHidden(true)
    window:SetDrawTier(DT_HIGH)
    self.window = window

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, window, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(window)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.035, 0.035, 0.045, 0.99 },
        { 0.5, 0.42, 0.28, 0.95 }
    )
    local title = makeLabel(
        window,
        GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_TITLE),
        18,
        10,
        664,
        "ZoFontWinH2"
    )
    title:SetMouseEnabled(true)
    title:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            window:StartMoving()
        end
    end)
    title:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            window:StopMovingOrResizing()
        end
    end)
    local help = makeLabel(window, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_HELP), 18, 48, 664)
    help:SetHeight(52)
    help:SetVerticalAlignment(TEXT_ALIGN_TOP)

    local editBackdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, window, "ZO_EditBackdrop")
    editBackdrop:SetAnchor(TOPLEFT, window, TOPLEFT, 18, 106)
    editBackdrop:SetDimensions(664, 190)
    local edit = WINDOW_MANAGER:CreateControlFromVirtual(nil, editBackdrop, "ZO_DefaultEditMultiLineForBackdrop")
    edit:ClearAnchors()
    edit:SetAnchor(TOPLEFT, editBackdrop, TOPLEFT, 5, 4)
    edit:SetAnchor(BOTTOMRIGHT, editBackdrop, BOTTOMRIGHT, -5, -4)
    GravvyBuildPlannerAccessibility:SetFont(edit, "ZoFontGame")
    edit:SetMaxInputChars(MAX_CODE_LENGTH)
    edit:SetNewLineEnabled(true)
    edit:SetSelectAllOnFocus(true)
    edit:SetHandler("OnEscape", function() self:Hide() end)
    self.codeEdit = edit

    self.status = makeLabel(window, "", 18, 302, 664, "ZoFontGameSmall")
    local export = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_EXPORT), 120)
    export:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 18, -16)
    export:SetHandler("OnClicked", function() self:ExportCurrent() end)
    local selectCode = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_SELECT), 100)
    selectCode:SetAnchor(LEFT, export, RIGHT, 8, 0)
    selectCode:SetHandler("OnClicked", function() self:SelectCode() end)
    local import = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_IMPORT), 120)
    import:SetAnchor(LEFT, selectCode, RIGHT, 8, 0)
    import:SetHandler("OnClicked", function() self:ImportCode() end)
    local close = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_CLOSE), 80)
    close:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -18, -16)
    close:SetHandler("OnClicked", function() self:Hide() end)
end

function Share:SetStatus(message, isError)
    if self.owner.accessibility then
        message = self.owner.accessibility:FormatStatus(message, isError)
    end
    self.status:SetText(message or "")
    self.status:SetColor(isError and 1 or 0.65, isError and 0.35 or 0.82, isError and 0.35 or 0.55, 1)
end

function Share:Open()
    self.window:SetHidden(false)
    self:ExportCurrent()
end

function Share:Hide()
    if self.codeEdit.LoseFocus then
        self.codeEdit:LoseFocus()
    end
    self.window:SetHidden(true)
end

function Share:SelectCode()
    self.codeEdit:TakeFocus()
    if self.codeEdit.SelectAll then
        self.codeEdit:SelectAll()
    end
    self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_COPY_HINT))
end

function Share:ExportCurrent()
    local code, message = Share.EncodeBuild(self.owner.data:GetCurrentBuild())
    if not code then
        self:SetStatus(message, true)
        return
    end
    self.codeEdit:SetText(code)
    self:SelectCode()
end

function Share:ImportCode()
    local decoded, message = Share.DecodeCode(self.codeEdit:GetText())
    if not decoded then
        self:SetStatus(message, true)
        return
    end
    local build, importMessage = self.owner.data:ImportBuild(decoded)
    if not build then
        self:SetStatus(importMessage, true)
        return
    end
    self.owner.setCatalog:Refresh()
    self.owner.consumableCatalog:Refresh()
    self.owner.inventory:QueueRefresh(0)
    self.owner.ui:Refresh()
    self.owner.gamepad:Refresh(true)
    self:Hide()
    self.owner.ui:SetStatus(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_SHARE_IMPORTED,
        build.name,
        #build.setups
    ))
end
