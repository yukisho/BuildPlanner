GravvyBuildPlannerComparison = {}

local Comparison = GravvyBuildPlannerComparison
local Slots = GravvyBuildPlannerSlots

local slotStringIds = {
    head = SI_GRAVVY_BUILD_PLANNER_SLOT_HEAD,
    shoulders = SI_GRAVVY_BUILD_PLANNER_SLOT_SHOULDERS,
    chest = SI_GRAVVY_BUILD_PLANNER_SLOT_CHEST,
    hands = SI_GRAVVY_BUILD_PLANNER_SLOT_HANDS,
    waist = SI_GRAVVY_BUILD_PLANNER_SLOT_WAIST,
    legs = SI_GRAVVY_BUILD_PLANNER_SLOT_LEGS,
    feet = SI_GRAVVY_BUILD_PLANNER_SLOT_FEET,
    neck = SI_GRAVVY_BUILD_PLANNER_SLOT_NECK,
    ring1 = SI_GRAVVY_BUILD_PLANNER_SLOT_RING1,
    ring2 = SI_GRAVVY_BUILD_PLANNER_SLOT_RING2,
    frontMain = SI_GRAVVY_BUILD_PLANNER_SLOT_FRONTMAIN,
    frontOff = SI_GRAVVY_BUILD_PLANNER_SLOT_FRONTOFF,
    backMain = SI_GRAVVY_BUILD_PLANNER_SLOT_BACKMAIN,
    backOff = SI_GRAVVY_BUILD_PLANNER_SLOT_BACKOFF,
}

local checklistStringIds = {
    passive = SI_GRAVVY_BUILD_PLANNER_CHECKLIST_PASSIVE,
    skillLine = SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SKILL_LINE,
    unlock = SI_GRAVVY_BUILD_PLANNER_CHECKLIST_UNLOCK,
    other = SI_GRAVVY_BUILD_PLANNER_CHECKLIST_OTHER,
}

local supplyStringIds = {
    food = SI_GRAVVY_BUILD_PLANNER_SUPPLY_FOOD,
    drink = SI_GRAVVY_BUILD_PLANNER_SUPPLY_DRINK,
    potion = SI_GRAVVY_BUILD_PLANNER_SUPPLY_POTION,
    poison = SI_GRAVVY_BUILD_PLANNER_SUPPLY_POISON,
    other = SI_GRAVVY_BUILD_PLANNER_SUPPLY_OTHER,
}

local disciplineStringIds = {
    craft = SI_GRAVVY_BUILD_PLANNER_CHAMPION_CRAFT,
    warfare = SI_GRAVVY_BUILD_PLANNER_CHAMPION_WARFARE,
    fitness = SI_GRAVVY_BUILD_PLANNER_CHAMPION_FITNESS,
}

local function sameFields(left, right, fields)
    if left == nil or right == nil then
        return left == right
    end
    for _, field in ipairs(fields) do
        if left[field] ~= right[field] then
            return false
        end
    end
    return true
end

local requirementFields = {
    "setId", "setName", "itemName", "armorType", "weaponType", "traitType",
    "enchantmentCategory", "enchantmentName", "quality", "level",
    "championPoints", "note", "occupiesOffHand",
}

local function sameRequirement(left, right)
    return sameFields(left, right, requirementFields)
end

local function sameAlternatives(left, right)
    if #left ~= #right then
        return false
    end
    for index = 1, #left do
        if not sameRequirement(left[index], right[index]) then
            return false
        end
    end
    return true
end

local function clean(value)
    value = zo_strtrim(tostring(value or ""))
    value = value:gsub("[\r\n]+", " ")
    return value ~= "" and value or GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED)
end

local function shorten(value)
    value = clean(value)
    return #value > 140 and string.sub(value, 1, 137) .. "..." or value
end

local function requirementSummary(requirement)
    if not requirement then
        return GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED)
    end
    local parts = {
        clean(requirement.itemName ~= "" and requirement.itemName or requirement.setName),
    }
    if requirement.armorType and requirement.armorType ~= ARMORTYPE_NONE then
        parts[#parts + 1] = GetString("SI_ARMORTYPE", requirement.armorType)
    elseif requirement.weaponType and requirement.weaponType ~= WEAPONTYPE_NONE then
        parts[#parts + 1] = GetString("SI_WEAPONTYPE", requirement.weaponType)
    end
    if requirement.traitType and requirement.traitType ~= ITEM_TRAIT_TYPE_NONE then
        parts[#parts + 1] = GetString("SI_ITEMTRAITTYPE", requirement.traitType)
    end
    if requirement.enchantmentName and requirement.enchantmentName ~= "" then
        parts[#parts + 1] = requirement.enchantmentName
    end
    if requirement.quality then
        parts[#parts + 1] = GetString("SI_ITEMQUALITY", requirement.quality)
    end
    if requirement.championPoints ~= nil then
        parts[#parts + 1] = "CP " .. tostring(requirement.championPoints)
    elseif requirement.level ~= nil then
        parts[#parts + 1] = GetString(SI_GRAVVY_BUILD_PLANNER_LEVEL) .. " "
            .. tostring(requirement.level)
    end
    if requirement.note and requirement.note ~= "" then
        parts[#parts + 1] = requirement.note
    end
    return shorten(table.concat(parts, " · "))
end

local function alternativesSummary(alternatives)
    if not alternatives or #alternatives == 0 then
        return GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED)
    end
    local parts = {}
    for index, requirement in ipairs(alternatives) do
        parts[#parts + 1] = tostring(index) .. ". " .. requirementSummary(requirement)
    end
    return shorten(table.concat(parts, "; "))
end

local function skillSummary(skill)
    return skill and clean(skill.name) or GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED)
end

local function checklistSummary(entry)
    if not entry then
        return GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED)
    end
    local parts = {
        GetString(entry.completed
            and SI_GRAVVY_BUILD_PLANNER_CHECKLIST_COMPLETE
            or SI_GRAVVY_BUILD_PLANNER_CHECKLIST_INCOMPLETE),
    }
    if entry.targetRank then
        parts[#parts + 1] = zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_CHECKLIST_RANK_VALUE,
            entry.targetRank
        )
    end
    if entry.note and entry.note ~= "" then
        parts[#parts + 1] = entry.note
    end
    return shorten(table.concat(parts, " · "))
end

local function supplySummary(entry)
    if not entry then
        return GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED)
    end
    local value = zo_strformat(SI_GRAVVY_BUILD_PLANNER_COMPARE_QUANTITY, entry.quantity)
    if entry.note and entry.note ~= "" then
        value = value .. " · " .. entry.note
    end
    return shorten(value)
end

local function add(rows, sectionId, label, left, right)
    rows[#rows + 1] = {
        section = GetString(sectionId),
        label = label,
        left = shorten(left),
        right = shorten(right),
    }
end

local function mapByName(entries)
    local result = {}
    for _, entry in ipairs(entries or {}) do
        result[entry.category .. "\31" .. zo_strlower(entry.name)] = entry
    end
    return result
end

local function sortedKeys(left, right)
    local found = {}
    local keys = {}
    for key in pairs(left) do
        found[key] = true
        keys[#keys + 1] = key
    end
    for key in pairs(right) do
        if not found[key] then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    return keys
end

function Comparison:GetDefaultTarget(build, currentSetupId)
    for _, setup in ipairs(build.setups) do
        if setup.id ~= currentSetupId then
            return setup
        end
    end
end

function Comparison:Build(left, right)
    local rows = {}
    if not left or not right then
        return rows
    end

    for _, field in ipairs({
        { "defaultQuality", SI_GRAVVY_BUILD_PLANNER_QUALITY },
        { "defaultLevel", SI_GRAVVY_BUILD_PLANNER_LEVEL },
        { "defaultChampionPoints", SI_GRAVVY_BUILD_PLANNER_CHAMPION_POINTS },
        { "note", SI_GRAVVY_BUILD_PLANNER_NOTES },
    }) do
        if left[field[1]] ~= right[field[1]] then
            local leftValue = left[field[1]]
            local rightValue = right[field[1]]
            if field[1] == "defaultQuality" then
                leftValue = GetString("SI_ITEMQUALITY", leftValue)
                rightValue = GetString("SI_ITEMQUALITY", rightValue)
            end
            add(rows, SI_GRAVVY_BUILD_PLANNER_COMPARE_SECTION_SETUP,
                GetString(field[2]), leftValue, rightValue)
        end
    end

    for _, slotKey in ipairs(Slots.ORDER) do
        local leftRequirement = left.equipment[slotKey]
        local rightRequirement = right.equipment[slotKey]
        if not sameRequirement(leftRequirement, rightRequirement) then
            add(rows, SI_GRAVVY_BUILD_PLANNER_COMPARE_SECTION_GEAR,
                GetString(slotStringIds[slotKey]), requirementSummary(leftRequirement),
                requirementSummary(rightRequirement))
        end
        local leftAlternatives = left.alternatives and left.alternatives[slotKey] or {}
        local rightAlternatives = right.alternatives and right.alternatives[slotKey] or {}
        if not sameAlternatives(leftAlternatives, rightAlternatives) then
            add(rows, SI_GRAVVY_BUILD_PLANNER_COMPARE_SECTION_GEAR,
                zo_strformat(SI_GRAVVY_BUILD_PLANNER_COMPARE_ALTERNATIVES,
                    GetString(slotStringIds[slotKey])),
                alternativesSummary(leftAlternatives), alternativesSummary(rightAlternatives))
        end
    end

    for _, barKey in ipairs({ "front", "back" }) do
        for slotIndex = 1, 6 do
            local leftSkill = left.skillBars[barKey][slotIndex]
            local rightSkill = right.skillBars[barKey][slotIndex]
            if not sameFields(leftSkill, rightSkill, { "abilityId", "isUltimate" }) then
                local barName = GetString(barKey == "front"
                    and SI_GRAVVY_BUILD_PLANNER_FRONT_BAR
                    or SI_GRAVVY_BUILD_PLANNER_BACK_BAR)
                local slotName = slotIndex == 6
                    and GetString(SI_GRAVVY_BUILD_PLANNER_ULTIMATE)
                    or tostring(slotIndex)
                add(rows, SI_GRAVVY_BUILD_PLANNER_COMPARE_SECTION_SKILLS,
                    zo_strformat(SI_GRAVVY_BUILD_PLANNER_SKILL_SLOT_TITLE,
                        barName, slotName), skillSummary(leftSkill), skillSummary(rightSkill))
            end
        end
    end

    local leftCharacter = left.character
    local rightCharacter = right.character
    for _, attribute in ipairs({ "health", "magicka", "stamina" }) do
        if leftCharacter.attributes[attribute] ~= rightCharacter.attributes[attribute] then
            local id = attribute == "health" and SI_GRAVVY_BUILD_PLANNER_HEALTH
                or attribute == "magicka" and SI_GRAVVY_BUILD_PLANNER_MAGICKA
                or SI_GRAVVY_BUILD_PLANNER_STAMINA
            add(rows, SI_GRAVVY_BUILD_PLANNER_COMPARE_SECTION_CHARACTER,
                GetString(id), leftCharacter.attributes[attribute],
                rightCharacter.attributes[attribute])
        end
    end
    if leftCharacter.raceId ~= rightCharacter.raceId then
        add(rows, SI_GRAVVY_BUILD_PLANNER_COMPARE_SECTION_CHARACTER,
            GetString(SI_GRAVVY_BUILD_PLANNER_RACE),
            leftCharacter.raceId > 0
                and GetRaceName(GENDER_MALE or 1, leftCharacter.raceId) or nil,
            rightCharacter.raceId > 0
                and GetRaceName(GENDER_MALE or 1, rightCharacter.raceId) or nil)
    end
    if leftCharacter.mundus ~= rightCharacter.mundus then
        add(rows, SI_GRAVVY_BUILD_PLANNER_COMPARE_SECTION_CHARACTER,
            GetString(SI_GRAVVY_BUILD_PLANNER_MUNDUS),
            leftCharacter.mundus > 0 and GetMundusStoneName(leftCharacter.mundus) or nil,
            rightCharacter.mundus > 0 and GetMundusStoneName(rightCharacter.mundus) or nil)
    end
    if leftCharacter.curse ~= rightCharacter.curse then
        local curseIds = {
            [0] = SI_GRAVVY_BUILD_PLANNER_CURSE_NONE,
            [1] = SI_GRAVVY_BUILD_PLANNER_CURSE_VAMPIRE,
            [2] = SI_GRAVVY_BUILD_PLANNER_CURSE_WEREWOLF,
        }
        add(rows, SI_GRAVVY_BUILD_PLANNER_COMPARE_SECTION_CHARACTER,
            GetString(SI_GRAVVY_BUILD_PLANNER_CURSE),
            GetString(curseIds[leftCharacter.curse]), GetString(curseIds[rightCharacter.curse]))
    end
    for index = 1, 3 do
        if leftCharacter.subclassLines[index] ~= rightCharacter.subclassLines[index] then
            add(rows, SI_GRAVVY_BUILD_PLANNER_COMPARE_SECTION_CHARACTER,
                zo_strformat(SI_GRAVVY_BUILD_PLANNER_SUBCLASS_LINE, index),
                leftCharacter.subclassLines[index], rightCharacter.subclassLines[index])
        end
    end

    for _, disciplineKey in ipairs({ "craft", "warfare", "fitness" }) do
        local leftDiscipline = left.champion[disciplineKey]
        local rightDiscipline = right.champion[disciplineKey]
        local leftAllocations = {}
        local rightAllocations = {}
        for _, allocation in ipairs(leftDiscipline.allocations) do
            leftAllocations[allocation.skillId] = allocation
        end
        for _, allocation in ipairs(rightDiscipline.allocations) do
            rightAllocations[allocation.skillId] = allocation
        end
        for _, skillId in ipairs(sortedKeys(leftAllocations, rightAllocations)) do
            local leftAllocation = leftAllocations[skillId]
            local rightAllocation = rightAllocations[skillId]
            if not sameFields(leftAllocation, rightAllocation,
                { "skillId", "points", "isSlottable" }) then
                local allocation = leftAllocation or rightAllocation
                add(rows, SI_GRAVVY_BUILD_PLANNER_COMPARE_SECTION_CHAMPION,
                    GetString(disciplineStringIds[disciplineKey]) .. " · " .. allocation.name,
                    leftAllocation and tostring(leftAllocation.points) or nil,
                    rightAllocation and tostring(rightAllocation.points) or nil)
            end
        end
        for slotIndex = 1, 4 do
            local leftSkillId = leftDiscipline.slottables[slotIndex]
            local rightSkillId = rightDiscipline.slottables[slotIndex]
            if leftSkillId ~= rightSkillId then
                local leftAllocation = leftAllocations[leftSkillId]
                local rightAllocation = rightAllocations[rightSkillId]
                add(rows, SI_GRAVVY_BUILD_PLANNER_COMPARE_SECTION_CHAMPION,
                    zo_strformat(SI_GRAVVY_BUILD_PLANNER_COMPARE_CHAMPION_SLOT,
                        GetString(disciplineStringIds[disciplineKey]), slotIndex),
                    leftAllocation and leftAllocation.name or nil,
                    rightAllocation and rightAllocation.name or nil)
            end
        end
    end

    local leftSupplies = mapByName(left.consumables)
    local rightSupplies = mapByName(right.consumables)
    for _, key in ipairs(sortedKeys(leftSupplies, rightSupplies)) do
        local leftEntry = leftSupplies[key]
        local rightEntry = rightSupplies[key]
        if not sameFields(leftEntry, rightEntry,
            { "category", "name", "itemId", "quantity", "note" }) then
            local entry = leftEntry or rightEntry
            add(rows, SI_GRAVVY_BUILD_PLANNER_COMPARE_SECTION_SUPPLIES,
                GetString(supplyStringIds[entry.category]) .. " · " .. entry.name,
                supplySummary(leftEntry), supplySummary(rightEntry))
        end
    end

    local leftChecklist = mapByName(left.checklist)
    local rightChecklist = mapByName(right.checklist)
    for _, key in ipairs(sortedKeys(leftChecklist, rightChecklist)) do
        local leftEntry = leftChecklist[key]
        local rightEntry = rightChecklist[key]
        if not sameFields(leftEntry, rightEntry,
            { "category", "name", "targetRank", "completed", "abilityId", "note" }) then
            local entry = leftEntry or rightEntry
            add(rows, SI_GRAVVY_BUILD_PLANNER_COMPARE_SECTION_CHECKLIST,
                GetString(checklistStringIds[entry.category]) .. " · " .. entry.name,
                checklistSummary(leftEntry), checklistSummary(rightEntry))
        end
    end
    return rows
end
