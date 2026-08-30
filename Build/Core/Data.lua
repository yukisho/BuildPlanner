GravvyBuildPlannerData = {}

local Data = GravvyBuildPlannerData
local SCHEMA_VERSION = 14
local MAX_RECOVERY_SNAPSHOTS = 5
local MAX_DELETED_ACTIONS = 20
local MAX_REVISIONS = 20
local MAX_REVISION_BYTES = 2097152
local MAX_REVISION_NAME = 100
local MAX_NOTE_LENGTH = 4000
local MAX_ALTERNATIVES = 8
local MAX_SUBCLASS_NAME = 100
local MAX_RACE_ID = 10
local MAX_CHAMPION_ALLOCATIONS = 200
local MAX_CHAMPION_POINTS = 1000
local MAX_CONSUMABLES = 20
local MAX_CONSUMABLE_QUANTITY = 9999
local MAX_CHECKLIST_ENTRIES = 100
local MAX_CHECKLIST_RANK = 50
local MAX_STAT_CONTEXTS = 12
local DEFAULT_QUALITY = ITEM_QUALITY_LEGENDARY or 5
local Validation = GravvyBuildPlannerValidation
local MAX_BUILDS = Validation.MAX_BUILDS
local MAX_SETUPS = Validation.MAX_SETUPS
local MAX_STRING_LENGTH = Validation.MAX_STRING
local MAX_NAME_LENGTH = Validation.MAX_NAME
local MAX_ID = Validation.MAX_ID
local validAcquisitionRoutes = {
    buy = true,
    craft = true,
    farm = true,
    reconstruct = true,
    transmute = true,
    unknown = true,
}
local validConsumableCategories = {
    food = true,
    drink = true,
    potion = true,
    poison = true,
    other = true,
}
local validChecklistCategories = {
    passive = true,
    skillLine = true,
    unlock = true,
    other = true,
}
local validChecklistDetectionKinds = {
    passive = true,
    skillLine = true,
    ability = true,
    champion = true,
    championSlotted = true,
    trait = true,
}
local validStatSnapshotKeys = {
    maxMagicka = true,
    magickaRecovery = true,
    maxHealth = true,
    healthRecovery = true,
    maxStamina = true,
    staminaRecovery = true,
    spellDamage = true,
    spellCritical = true,
    spellPenetration = true,
    weaponDamage = true,
    weaponCritical = true,
    physicalPenetration = true,
    spellResistance = true,
    physicalResistance = true,
    criticalResistance = true,
}

local defaults = {
    schemaVersion = SCHEMA_VERSION,
    language = GetCVar and GetCVar("language.2") or "",
    nextBuildId = 1,
    nextSetupId = 1,
    selectedBuildId = nil,
    deletedActions = {},
    builds = {},
    settings = {
        window = {},
        fontScale = 1,
        highContrast = false,
        nonColorIndicators = false,
    },
}

local recoveryDefaults = {
    nextId = 1,
    snapshots = {},
}

local stringFields = {
    "setName",
    "itemName",
    "itemLink",
    "enchantmentName",
    "note",
}

local numberFields = {
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

local function trim(value)
    return zo_strtrim(type(value) == "string" and value or "")
end

local function plain(value, maximum, allowEmpty)
    return Validation:SanitizePlainText(value, maximum, allowEmpty)
end

local function normalizeNote(value)
    return Validation:SanitizePlainText(
        tostring(value or ""),
        MAX_NOTE_LENGTH,
        true,
        true
    ) or ""
end

local function now()
    return GetTimeStamp and GetTimeStamp() or 0
end

local function deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for key, entry in pairs(value) do
        copy[deepCopy(key, seen)] = deepCopy(entry, seen)
    end
    return copy
end

local STATE_KEYS = {
    "schemaVersion",
    "language",
    "nextBuildId",
    "nextSetupId",
    "selectedBuildId",
    "deletedActions",
    "builds",
    "settings",
}

local function extractState(source)
    local state = {}
    if type(source) ~= "table" then return state end
    for _, key in ipairs(STATE_KEYS) do
        if source[key] ~= nil then state[key] = deepCopy(source[key]) end
    end
    return state
end

local function applyState(target, source)
    for _, key in ipairs(STATE_KEYS) do
        target[key] = deepCopy(source[key])
    end
end

local fingerprintRequirementKeys = {
    "setId", "setName", "itemId", "itemLink", "armorType", "weaponType",
    "traitType", "enchantmentId", "enchantmentCategory", "enchantmentName",
    "quality", "level", "championPoints", "occupiesOffHand",
}

local function stableValue(value)
    local valueType = type(value)
    if valueType == "nil" then return "n" end
    if valueType == "boolean" then return value and "b1" or "b0" end
    if valueType == "number" then return "d" .. tostring(value) end
    if valueType == "string" then return "s" .. tostring(#value) .. ":" .. value end
    if valueType ~= "table" then return "x" end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(left, right)
        local leftKey = type(left) .. ":" .. tostring(left)
        local rightKey = type(right) .. ":" .. tostring(right)
        return leftKey < rightKey
    end)
    local parts = { "{" }
    for _, key in ipairs(keys) do
        parts[#parts + 1] = stableValue(key)
        parts[#parts + 1] = stableValue(value[key])
    end
    parts[#parts + 1] = "}"
    return table.concat(parts)
end

local function fingerprint(value)
    local encoded = stableValue(value)
    local first, second = 1, 0
    for index = 1, #encoded do
        first = (first + string.byte(encoded, index)) % 65521
        second = (second + first) % 65521
    end
    return string.format("%08x", (second * 65536) + first)
end

local function requirementFingerprint(requirement)
    local result = {}
    for _, key in ipairs(fingerprintRequirementKeys) do
        if requirement[key] ~= nil then result[key] = requirement[key] end
    end
    return result
end

local function setupFingerprintPayload(setup)
    local payload = {
        defaultQuality = setup.defaultQuality,
        defaultLevel = setup.defaultLevel,
        defaultChampionPoints = setup.defaultChampionPoints,
        equipment = {},
        alternatives = {},
        skillBars = { front = {}, back = {} },
        character = setup.character,
        champion = {},
        consumables = {},
    }
    for _, slotKey in ipairs(GravvyBuildPlannerSlots.ORDER) do
        local requirement = setup.equipment and setup.equipment[slotKey]
        if requirement then payload.equipment[slotKey] = requirementFingerprint(requirement) end
        local alternatives = setup.alternatives and setup.alternatives[slotKey]
        if alternatives then
            payload.alternatives[slotKey] = {}
            for _, alternative in ipairs(alternatives) do
                payload.alternatives[slotKey][#payload.alternatives[slotKey] + 1]
                    = requirementFingerprint(alternative)
            end
        end
    end
    for _, entry in ipairs(setup.consumables or {}) do
        payload.consumables[#payload.consumables + 1] = {
            category = entry.category,
            name = entry.name,
            itemId = entry.itemId,
            itemLink = entry.itemLink,
        }
    end
    for _, barKey in ipairs({ "front", "back" }) do
        for slotIndex, skill in pairs((setup.skillBars and setup.skillBars[barKey]) or {}) do
            payload.skillBars[barKey][slotIndex] = {
                abilityId = skill.abilityId,
                isUltimate = skill.isUltimate,
            }
        end
    end
    for _, disciplineKey in ipairs({ "craft", "warfare", "fitness" }) do
        local discipline = setup.champion and setup.champion[disciplineKey] or {}
        local copy = { allocations = {}, slottables = {} }
        for _, allocation in ipairs(discipline.allocations or {}) do
            copy.allocations[#copy.allocations + 1] = {
                skillId = allocation.skillId,
                points = allocation.points,
                isSlottable = allocation.isSlottable,
            }
        end
        for index = 1, 4 do
            copy.slottables[index] = discipline.slottables and discipline.slottables[index] or 0
        end
        payload.champion[disciplineKey] = copy
    end
    return payload
end

local function sameName(left, right)
    return zo_strlower(trim(left)) == zo_strlower(trim(right))
end

local function makeUniqueName(seen, baseName)
    local name = baseName
    local suffix = 2
    while seen[zo_strlower(name)] do
        local ending = " " .. tostring(suffix)
        name = string.sub(baseName, 1, MAX_NAME_LENGTH - #ending) .. ending
        suffix = suffix + 1
    end
    seen[zo_strlower(name)] = true
    return name
end

local function makeBuildSnapshot(build)
    local selectedSetupIndex = 1
    for index, setup in ipairs(build.setups) do
        if setup.id == build.selectedSetupId then
            selectedSetupIndex = index
            break
        end
    end
    return {
        name = build.name,
        classId = build.classId,
        role = build.role,
        patch = build.patch,
        author = build.author,
        sourceUrl = build.sourceUrl,
        notes = build.notes,
        selectedSetupIndex = selectedSetupIndex,
        setups = deepCopy(build.setups),
    }
end

local function revisionSize(revision)
    return #stableValue(revision)
end

local function revisionHistorySize(revisions)
    local total = 0
    for _, revision in ipairs(revisions or {}) do
        total = total + revisionSize(revision)
    end
    return total
end

local function copyRequirement(source)
    if type(source) ~= "table" then
        return nil
    end

    local copy = {}
    for _, key in ipairs(stringFields) do
        local value = source[key]
        if value ~= nil then
            if type(value) ~= "string" then
                return nil
            end
            if key == "note" then
                copy[key] = normalizeNote(value)
            elseif key == "itemLink" then
                if not Validation:IsItemLink(value) then
                    return nil
                end
                copy[key] = value
            else
                copy[key] = plain(value, MAX_STRING_LENGTH, true)
            end
        end
    end
    for _, key in ipairs(numberFields) do
        local value = source[key]
        if value ~= nil then
            value = tonumber(value)
            if not value or value ~= math.floor(value) or value < 0 or value > MAX_ID then
                return nil
            end
            copy[key] = value
        end
    end
    if copy.setId ~= nil and not Validation:IsId(copy.setId, false) then return nil end
    if copy.itemId ~= nil and not Validation:IsId(copy.itemId, false) then return nil end
    if copy.enchantmentId ~= nil and not Validation:IsId(copy.enchantmentId, false) then return nil end
    if copy.quality ~= nil and not Validation:IsQuality(copy.quality) then return nil end
    if copy.level ~= nil and not Validation:IsLevel(copy.level) then return nil end
    if copy.championPoints ~= nil and not Validation:IsChampionPoints(copy.championPoints) then return nil end
    return copy
end

local function sameSet(left, right)
    if left.setId and right.setId then
        return left.setId == right.setId
    end
    local leftName = zo_strlower(trim(left.setName))
    local rightName = zo_strlower(trim(right.setName))
    return leftName ~= "" and leftName == rightName
end

local function normalizeAlternative(slotKey, source, primary)
    local requirement = copyRequirement(source)
    if not requirement or not Validation:IsRequirement(slotKey, requirement) then
        return nil
    end
    local occupiedOffHand = GravvyBuildPlannerSlots:GetOccupiedOffHand(
        slotKey,
        requirement.weaponType
    )
    requirement.occupiesOffHand = occupiedOffHand ~= nil
    if primary and requirement.occupiesOffHand ~= (primary.occupiesOffHand == true) then
        return nil
    end
    return requirement
end

local function copySkill(source, slotIndex)
    if type(source) ~= "table" then
        return nil
    end
    local abilityId = tonumber(source.abilityId)
    if not abilityId or abilityId ~= math.floor(abilityId) or abilityId < 1
        or type(source.name) ~= "string" or type(source.icon) ~= "string"
        or source.isUltimate ~= (slotIndex == 6) then
        return nil
    end
    local name = plain(source.name, MAX_NAME_LENGTH, false)
    if not name or #source.icon > MAX_STRING_LENGTH then
        return nil
    end
    return {
        abilityId = abilityId,
        name = name,
        icon = source.icon,
        isUltimate = source.isUltimate,
    }
end

local function copySkillBars(source, strict)
    local bars = { front = {}, back = {} }
    source = type(source) == "table" and source or {}
    for _, barKey in ipairs({ "front", "back" }) do
        local bar = source[barKey]
        if bar ~= nil and type(bar) ~= "table" then
            return strict and nil or bars
        end
        for slotIndex, entry in pairs(bar or {}) do
            slotIndex = tonumber(slotIndex)
            local skill = slotIndex and copySkill(entry, slotIndex)
            if skill and slotIndex >= 1 and slotIndex <= 6 then
                bars[barKey][slotIndex] = skill
            elseif strict then
                return nil
            end
        end
    end
    return bars
end

local function readWholeNumber(value, minimum, maximum)
    value = tonumber(value)
    maximum = maximum or MAX_ID
    if not value or value ~= math.floor(value) or value < minimum or value > maximum then
        return nil
    end
    return value
end

local function copyStatSnapshot(source)
    if source == nil then
        return nil
    end
    if type(source) ~= "table" or type(source.values) ~= "table" then
        return nil
    end
    local values = {}
    for key, value in pairs(source.values) do
        value = tonumber(value)
        if validStatSnapshotKeys[key] and value and value >= 0 and value <= 1000000000 then
            values[key] = value
        end
    end
    if next(values) == nil then
        return nil
    end
    local characterName = type(source.characterName) == "string"
        and plain(source.characterName, MAX_NAME_LENGTH, true)
        or ""
    local snapshot = {
        characterName = characterName,
        createdAt = readWholeNumber(source.createdAt, 0) or now(),
        values = values,
    }
    if type(source.captureTime) == "string" then
        snapshot.captureTime = plain(source.captureTime, 32, true)
    end
    if type(source.foodName) == "string" then
        snapshot.foodName = plain(source.foodName, MAX_NAME_LENGTH, true)
    end
    local foodAbilityId = readWholeNumber(source.foodAbilityId or 0, 0)
    if foodAbilityId then snapshot.foodAbilityId = foodAbilityId end
    local mundus = readWholeNumber(source.mundus or 0, 0, 13)
    if mundus then snapshot.mundus = mundus end
    snapshot.inCombat = source.inCombat == true
    if type(source.equippedCoverage) == "table" then
        local coverage = {}
        for _, key in ipairs({ "planned", "ready", "adjustable", "missing" }) do
            coverage[key] = readWholeNumber(source.equippedCoverage[key] or 0, 0, 14)
                or 0
        end
        if coverage.ready + coverage.adjustable + coverage.missing == coverage.planned then
            snapshot.equippedCoverage = coverage
        end
    end
    if type(source.fingerprint) == "string" and #source.fingerprint <= 32 then
        snapshot.fingerprint = source.fingerprint
    end
    if source.bar == "front" or source.bar == "back" then
        snapshot.bar = source.bar
    end
    return snapshot
end

local function copyStatSnapshots(source, legacy)
    local snapshots = {}
    if type(source) == "table" then
        snapshots.front = copyStatSnapshot(source.front)
        snapshots.back = copyStatSnapshot(source.back)
        if type(source.contexts) == "table" then
            local seen = {}
            local contexts = {}
            for _, sourceContext in ipairs(source.contexts) do
                local key = type(sourceContext) == "table"
                    and plain(sourceContext.key, MAX_NAME_LENGTH, false)
                local name = type(sourceContext) == "table"
                    and plain(sourceContext.name, MAX_NAME_LENGTH, false)
                local normalizedKey = key and zo_strlower(key)
                if key and name and not seen[normalizedKey] and #contexts < MAX_STAT_CONTEXTS then
                    local context = {
                        key = key,
                        name = name,
                        front = copyStatSnapshot(sourceContext.front),
                        back = copyStatSnapshot(sourceContext.back),
                    }
                    if context.front or context.back then
                        contexts[#contexts + 1] = context
                        seen[normalizedKey] = true
                    end
                end
            end
            snapshots.contexts = #contexts > 0 and contexts or nil
        end
    end
    if not snapshots.front and legacy then
        snapshots.front = copyStatSnapshot(legacy)
    end
    return next(snapshots) and snapshots or nil
end

local function blankCharacterPlan()
    return {
        attributes = { health = 0, magicka = 0, stamina = 0 },
        raceId = 0,
        mundus = 0,
        curse = 0,
        subclassLines = { "", "", "" },
    }
end

local function invalidCharacterPlan(strict, fallback)
    if strict then
        return nil
    end
    return fallback or blankCharacterPlan()
end

local function copyCharacterPlan(source, strict)
    if source == nil then
        return blankCharacterPlan()
    end
    if type(source) ~= "table" then
        return invalidCharacterPlan(strict)
    end

    local plan = blankCharacterPlan()
    local attributes = source.attributes
    if attributes ~= nil and type(attributes) ~= "table" then
        return invalidCharacterPlan(strict, plan)
    end
    attributes = type(attributes) == "table" and attributes or {}
    local total = 0
    for _, key in ipairs({ "health", "magicka", "stamina" }) do
        local value = readWholeNumber(attributes[key] or 0, 0)
        if not value or value > 64 then
            return invalidCharacterPlan(strict, plan)
        end
        plan.attributes[key] = value
        total = total + value
    end
    if total > 64 then
        return invalidCharacterPlan(strict, plan)
    end

    for _, entry in ipairs({
        { "raceId", 0, MAX_RACE_ID },
        { "mundus", 0, 13 },
        { "curse", 0, 2 },
    }) do
        local key, minimum, maximum = entry[1], entry[2], entry[3]
        local value = readWholeNumber(source[key] or 0, minimum)
        if not value or value > maximum then
            return invalidCharacterPlan(strict, plan)
        end
        plan[key] = value
    end

    local lines = source.subclassLines
    if lines ~= nil and type(lines) ~= "table" then
        return invalidCharacterPlan(strict, plan)
    end
    for index = 1, 3 do
        local value = type(lines) == "table" and lines[index] or ""
        if value ~= nil and type(value) ~= "string" then
            return invalidCharacterPlan(strict, plan)
        end
        value = plain(value, MAX_SUBCLASS_NAME, true)
        if #value > MAX_SUBCLASS_NAME then
            return invalidCharacterPlan(strict, plan)
        end
        plan.subclassLines[index] = value
    end
    return plan
end

local function blankChampionPlan()
    return {
        craft = { allocations = {}, slottables = { 0, 0, 0, 0 } },
        warfare = { allocations = {}, slottables = { 0, 0, 0, 0 } },
        fitness = { allocations = {}, slottables = { 0, 0, 0, 0 } },
    }
end

local function copyChampionAllocation(source)
    if type(source) ~= "table" then
        return nil
    end
    local skillId = readWholeNumber(source.skillId, 1)
    local points = readWholeNumber(source.points, 1)
    local name = type(source.name) == "string"
        and plain(source.name, MAX_SUBCLASS_NAME, false)
    if not skillId or not points or points > MAX_CHAMPION_POINTS
        or not name
        or type(source.icon) ~= "string"
        or #source.icon > 512
        or type(source.isSlottable) ~= "boolean" then
        return nil
    end
    return {
        skillId = skillId,
        name = name,
        icon = source.icon,
        points = points,
        isSlottable = source.isSlottable,
    }
end

local function copyChampionPlan(source, strict)
    local plan = blankChampionPlan()
    if source == nil then
        return plan
    end
    if type(source) ~= "table" then
        return invalidCharacterPlan(strict, plan)
    end
    local seenSkills = {}
    for _, disciplineKey in ipairs({ "craft", "warfare", "fitness" }) do
        local sourceDiscipline = source[disciplineKey]
        if sourceDiscipline ~= nil and type(sourceDiscipline) ~= "table" then
            return invalidCharacterPlan(strict, plan)
        end
        sourceDiscipline = sourceDiscipline or {}
        local sourceAllocations = sourceDiscipline.allocations
        if sourceAllocations ~= nil and type(sourceAllocations) ~= "table" then
            return invalidCharacterPlan(strict, plan)
        end
        if #(sourceAllocations or {}) > MAX_CHAMPION_ALLOCATIONS then
            return invalidCharacterPlan(strict, plan)
        end
        local discipline = plan[disciplineKey]
        local allocationsById = {}
        for _, sourceAllocation in ipairs(sourceAllocations or {}) do
            local allocation = copyChampionAllocation(sourceAllocation)
            if not allocation or seenSkills[allocation.skillId] then
                return invalidCharacterPlan(strict, plan)
            end
            seenSkills[allocation.skillId] = true
            allocationsById[allocation.skillId] = allocation
            discipline.allocations[#discipline.allocations + 1] = allocation
        end

        local sourceSlottables = sourceDiscipline.slottables
        if sourceSlottables ~= nil and type(sourceSlottables) ~= "table" then
            return invalidCharacterPlan(strict, plan)
        end
        local seenSlots = {}
        for slotIndex = 1, 4 do
            local sourceSkillId = sourceSlottables and sourceSlottables[slotIndex] or 0
            local skillId = readWholeNumber(sourceSkillId or 0, 0)
            local allocation = skillId and skillId > 0 and allocationsById[skillId]
            if not skillId or (skillId > 0
                and (not allocation or not allocation.isSlottable or seenSlots[skillId])) then
                return invalidCharacterPlan(strict, plan)
            end
            if skillId > 0 then
                seenSlots[skillId] = true
            end
            discipline.slottables[slotIndex] = skillId
        end
    end
    return plan
end

local function copyConsumable(source)
    if type(source) ~= "table" or not validConsumableCategories[source.category]
        or type(source.name) ~= "string" then
        return nil
    end
    local name = plain(source.name, MAX_NAME_LENGTH, false)
    if not name then return nil end
    local quantity = readWholeNumber(source.quantity or 1, 1)
    if not quantity or quantity > MAX_CONSUMABLE_QUANTITY then
        return nil
    end
    local entry = {
        category = source.category,
        name = name,
        quantity = quantity,
        note = normalizeNote(source.note),
    }
    if source.itemId ~= nil then
        entry.itemId = readWholeNumber(source.itemId, 1)
        if not entry.itemId then
            return nil
        end
    end
    if source.itemLink ~= nil then
        if not Validation:IsItemLink(source.itemLink) then
            return nil
        end
        entry.itemLink = source.itemLink
    end
    if source.icon ~= nil then
        if type(source.icon) ~= "string" or #source.icon > 512 then
            return nil
        end
        entry.icon = source.icon
    end
    return entry
end

local function copyConsumables(source, strict)
    if source == nil then
        return {}
    end
    if type(source) ~= "table" or #source > MAX_CONSUMABLES then
        if strict then
            return nil
        end
        return {}
    end
    local entries = {}
    local seen = {}
    for _, sourceEntry in ipairs(source) do
        local entry = copyConsumable(sourceEntry)
        local key = entry and entry.category .. "\31" .. zo_strlower(entry.name)
        if not entry or seen[key] then
            if strict then
                return nil
            end
        else
            seen[key] = true
            entries[#entries + 1] = entry
        end
    end
    return entries
end

local function copyChecklistEntry(source)
    if type(source) ~= "table" or not validChecklistCategories[source.category]
        or type(source.name) ~= "string" then
        return nil
    end
    local name = plain(source.name, MAX_NAME_LENGTH, false)
    if not name then return nil end
    local entry = {
        category = source.category,
        name = name,
        completed = source.completed == true,
        note = normalizeNote(source.note),
    }
    if source.targetRank ~= nil then
        entry.targetRank = readWholeNumber(source.targetRank, 1)
        if not entry.targetRank or entry.targetRank > MAX_CHECKLIST_RANK then
            return nil
        end
    end
    if source.abilityId ~= nil then
        entry.abilityId = readWholeNumber(source.abilityId, 1)
        if not entry.abilityId then
            return nil
        end
    end
    if source.icon ~= nil then
        if type(source.icon) ~= "string" or #source.icon > 512 then
            return nil
        end
        entry.icon = source.icon
    end
    if source.detection ~= nil then
        local detection = source.detection
        if type(detection) ~= "table" or not validChecklistDetectionKinds[detection.kind] then
            return nil
        end
        local normalized = { kind = detection.kind }
        for _, key in ipairs({
            "id",
            "skillType",
            "skillLineIndex",
            "craftingType",
            "researchLineIndex",
            "traitIndex",
        }) do
            if detection[key] ~= nil then
                normalized[key] = readWholeNumber(detection[key], 1)
                if not normalized[key] then
                    return nil
                end
            end
        end
        local kind = normalized.kind
        if ((kind == "passive" or kind == "ability" or kind == "champion"
                or kind == "championSlotted") and not normalized.id)
            or (kind == "skillLine" and (not normalized.skillType
                or not normalized.skillLineIndex))
            or (kind == "trait" and (not normalized.craftingType
                or not normalized.researchLineIndex or not normalized.traitIndex)) then
            return nil
        end
        entry.detection = normalized
    end
    return entry
end

local function copyChecklist(source, strict)
    if source == nil then
        return {}
    end
    if type(source) ~= "table" or #source > MAX_CHECKLIST_ENTRIES then
        if strict then
            return nil
        end
        return {}
    end
    local entries = {}
    local seen = {}
    for _, sourceEntry in ipairs(source) do
        local entry = copyChecklistEntry(sourceEntry)
        local key = entry and entry.category .. "\31" .. zo_strlower(entry.name)
        if not entry or seen[key] then
            if strict then
                return nil
            end
        else
            seen[key] = true
            entries[#entries + 1] = entry
        end
    end
    return entries
end

local function copyBuildChanges(values)
    if type(values) ~= "table" then
        return nil
    end

    local changes = {}
    if values.classId ~= nil then
        changes.classId = Validation:WholeNumber(values.classId, 0, 100)
        if not changes.classId then
            return nil
        end
    end
    for _, key in ipairs({ "role", "patch", "author", "sourceUrl" }) do
        if values[key] ~= nil then
            if type(values[key]) ~= "string" then
                return nil
            end
            changes[key] = plain(values[key], MAX_STRING_LENGTH, true)
        end
    end
    if values.notes ~= nil then
        if type(values.notes) ~= "string" then
            return nil
        end
        changes.notes = normalizeNote(values.notes)
    end
    return changes
end

local function copySetupChanges(values)
    if type(values) ~= "table" then
        return nil
    end

    local changes = {}
    if values.note ~= nil then
        if type(values.note) ~= "string" then
            return nil
        end
        changes.note = normalizeNote(values.note)
    end
    for _, entry in ipairs({
        { "defaultQuality", function(value) return Validation:IsQuality(value) end },
        { "defaultLevel", function(value) return Validation:IsLevel(value) end },
        { "defaultChampionPoints", function(value) return Validation:IsChampionPoints(value) end },
    }) do
        local key, validator = entry[1], entry[2]
        if values[key] ~= nil then
            changes[key] = tonumber(values[key])
            if not validator(changes[key]) then
                return nil
            end
        end
    end
    return changes
end

local function setupNameExists(build, name, exceptId)
    for _, setup in ipairs(build.setups) do
        if setup.id ~= exceptId and sameName(setup.name, name) then
            return true
        end
    end
    return false
end

local function uniqueSetupName(build, baseName, exceptId)
    local name = baseName
    local suffix = 2
    while setupNameExists(build, name, exceptId) do
        local ending = " " .. tostring(suffix)
        name = string.sub(baseName, 1, MAX_NAME_LENGTH - #ending) .. ending
        suffix = suffix + 1
    end
    return name
end

local function currentLanguage()
    return GetCVar and GetCVar("language.2") or ""
end

local function localizedSetName(setId)
    if not setId then return nil end
    if GetItemSetName then
        local ok, name = pcall(GetItemSetName, setId)
        if ok and type(name) == "string" and zo_strtrim(name) ~= "" then
            return zo_strtrim(name)
        end
    end
    if LibSets and LibSets.GetSetName then
        local ok, name = pcall(LibSets.GetSetName, setId)
        if ok and type(name) == "string" and zo_strtrim(name) ~= "" then
            return zo_strtrim(name)
        end
    end
end

local function refreshRequirementLanguage(requirement)
    local setName = localizedSetName(requirement.setId)
    if setName then requirement.setName = setName end
    if requirement.itemLink and requirement.itemLink ~= "" and GetItemLinkName then
        local ok, itemName = pcall(GetItemLinkName, requirement.itemLink)
        if ok and type(itemName) == "string" and zo_strtrim(itemName) ~= "" then
            requirement.itemName = zo_strformat(SI_TOOLTIP_ITEM_NAME, itemName)
        end
    end
end

function Data:New()
    local data = setmetatable({}, { __index = self })
    data.saved = ZO_SavedVars:NewAccountWide(
        "GravvyBuildPlanner_Data",
        1,
        nil,
        defaults,
        GetWorldName()
    )
    data.recovery = ZO_SavedVars:NewAccountWide(
        "GravvyBuildPlanner_RecoveryData",
        1,
        nil,
        recoveryDefaults,
        GetWorldName()
    )
    local sourceVersion = tonumber(data.saved.schemaVersion) or 1
    local snapshotted, snapshotMessage = data:CreateRecoverySnapshot(
        "startup",
        data.saved
    )
    local migrated, migrationMessage = data:Migrate()
    if not migrated then
        local recovered = data:RecoverLatestValidSnapshot()
        if recovered then
            data.startupMessage = GetString(
                SI_GRAVVY_BUILD_PLANNER_DATA_RECOVERED
            )
        else
            local fallback = data:PrepareCandidate(defaults)
            applyState(data.saved, fallback or deepCopy(defaults))
            data.startupMessage = migrationMessage
                or GetString(SI_GRAVVY_BUILD_PLANNER_DATA_MIGRATION_FAILED)
        end
    elseif sourceVersion < SCHEMA_VERSION then
        data:CreateRecoverySnapshot("post_migration", data.saved)
    elseif not snapshotted then
        data.startupMessage = snapshotMessage
    end
    return data
end

function Data:Normalize()
    local saved = self.saved
    local languageChanged = saved.language ~= currentLanguage()
    saved.builds = type(saved.builds) == "table" and saved.builds or {}
    saved.deletedActions = type(saved.deletedActions) == "table" and saved.deletedActions or {}
    saved.settings = type(saved.settings) == "table" and saved.settings or {}
    saved.settings.window = type(saved.settings.window) == "table" and saved.settings.window or {}
    saved.settings.fontScale = zo_clamp(
        tonumber(saved.settings.fontScale) or 1,
        0.9,
        1.4
    )
    saved.settings.highContrast = saved.settings.highContrast == true
    saved.settings.nonColorIndicators = saved.settings.nonColorIndicators == true
    local window = saved.settings.window
    window.left = tonumber(window.left)
    window.top = tonumber(window.top)
    while #saved.deletedActions > MAX_DELETED_ACTIONS do
        table.remove(saved.deletedActions, 1)
    end

    local builds = {}
    for _, build in ipairs(saved.builds) do
        if type(build) == "table" and #builds < MAX_BUILDS then
            builds[#builds + 1] = build
        end
    end
    saved.builds = builds

    local highestBuildId = 0
    local highestSetupId = 0
    local usedBuildIds = {}
    local usedSetupIds = {}
    local usedBuildNames = {}
    for _, build in ipairs(saved.builds) do
        local buildId = Validation:WholeNumber(build.id, 1, MAX_ID)
        if not buildId or usedBuildIds[buildId] then
            buildId = highestBuildId + 1
        end
        build.id = buildId
        usedBuildIds[buildId] = true
        highestBuildId = math.max(highestBuildId, build.id)
        build.name = plain(tostring(build.name or ""), MAX_NAME_LENGTH, true)
        if not build.name or build.name == "" then
            build.name = GetString(SI_GRAVVY_BUILD_PLANNER_DEFAULT_BUILD)
        end
        build.name = makeUniqueName(usedBuildNames, build.name)
        build.classId = Validation:WholeNumber(build.classId or 0, 0, 100) or 0
        build.role = plain(tostring(build.role or ""), MAX_STRING_LENGTH, true) or ""
        build.patch = plain(tostring(build.patch or ""), MAX_STRING_LENGTH, true) or ""
        build.author = plain(tostring(build.author or ""), MAX_STRING_LENGTH, true) or ""
        build.sourceUrl = plain(tostring(build.sourceUrl or ""), MAX_STRING_LENGTH, true) or ""
        build.notes = normalizeNote(build.notes)
        build.createdAt = readWholeNumber(build.createdAt, 0) or now()
        build.updatedAt = readWholeNumber(build.updatedAt, 0) or build.createdAt
        local revisions = {}
        local usedRevisionIds = {}
        local highestRevisionId = 0
        if type(build.revisions) == "table" then
            for _, sourceRevision in ipairs(build.revisions) do
                if #revisions >= MAX_REVISIONS then
                    break
                end
                local snapshot = type(sourceRevision) == "table"
                    and sourceRevision.snapshot
                local revisionName = type(sourceRevision) == "table"
                    and plain(tostring(sourceRevision.name or ""), MAX_REVISION_NAME, true)
                    or ""
                if revisionName ~= "" and #revisionName <= MAX_REVISION_NAME
                    and type(snapshot) == "table"
                    and type(snapshot.setups) == "table"
                    and #snapshot.setups > 0 then
                    local revisionId = Validation:WholeNumber(sourceRevision.id, 1, MAX_ID)
                    if not revisionId or usedRevisionIds[revisionId] then
                        revisionId = highestRevisionId + 1
                    end
                    usedRevisionIds[revisionId] = true
                    highestRevisionId = math.max(highestRevisionId, revisionId)
                    snapshot = deepCopy(snapshot)
                    snapshot.revisions = nil
                    snapshot.nextRevisionId = nil
                    revisions[#revisions + 1] = {
                        id = revisionId,
                        name = revisionName,
                        patch = plain(tostring(sourceRevision.patch or snapshot.patch or ""), MAX_STRING_LENGTH, true) or "",
                        createdAt = readWholeNumber(sourceRevision.createdAt, 0)
                            or build.updatedAt,
                        snapshot = snapshot,
                    }
                end
            end
        end
        build.revisions = revisions
        build.nextRevisionId = math.max(
            readWholeNumber(build.nextRevisionId, 1) or 1,
            highestRevisionId + 1
        )
        local setups = {}
        if type(build.setups) == "table" then
            for _, setup in ipairs(build.setups) do
                if type(setup) == "table" and #setups < MAX_SETUPS then
                    setups[#setups + 1] = setup
                end
            end
        end
        build.setups = setups

        local usedSetupNames = {}
        for _, setup in ipairs(build.setups) do
            local setupId = Validation:WholeNumber(setup.id, 1, MAX_ID)
            if not setupId or usedSetupIds[setupId] then
                setupId = highestSetupId + 1
            end
            setup.id = setupId
            usedSetupIds[setupId] = true
            highestSetupId = math.max(highestSetupId, setup.id)
            setup.name = plain(tostring(setup.name or ""), MAX_NAME_LENGTH, true)
            if not setup.name or setup.name == "" then
                setup.name = GetString(SI_GRAVVY_BUILD_PLANNER_DEFAULT_SETUP)
            end
            setup.name = makeUniqueName(usedSetupNames, setup.name)
            setup.note = normalizeNote(setup.note)
            setup.defaultQuality = Validation:IsQuality(setup.defaultQuality)
                and tonumber(setup.defaultQuality) or DEFAULT_QUALITY
            setup.defaultLevel = Validation:IsLevel(setup.defaultLevel)
                and tonumber(setup.defaultLevel) or 50
            setup.defaultChampionPoints = Validation:IsChampionPoints(setup.defaultChampionPoints)
                and tonumber(setup.defaultChampionPoints) or 160
            setup.equipment = type(setup.equipment) == "table" and setup.equipment or {}
            setup.alternatives = type(setup.alternatives) == "table"
                and setup.alternatives
                or {}
            setup.alternativeGroups = nil
            setup.skillBars = copySkillBars(setup.skillBars, false)
            setup.character = copyCharacterPlan(setup.character, false)
            setup.champion = copyChampionPlan(setup.champion, false)
            setup.consumables = copyConsumables(setup.consumables, false)
            setup.checklist = copyChecklist(setup.checklist, false)
            setup.statSnapshots = copyStatSnapshots(setup.statSnapshots, setup.statSnapshot)
            setup.statSnapshot = nil
            setup.acquisition = type(setup.acquisition) == "table" and setup.acquisition or {}
            setup.slotStates = nil
            setup.createdAt = readWholeNumber(setup.createdAt, 0) or now()
            setup.updatedAt = readWholeNumber(setup.updatedAt, 0) or setup.createdAt

            for slotKey, requirement in pairs(setup.equipment) do
                if not GravvyBuildPlannerSlots:IsValid(slotKey) then
                    setup.equipment[slotKey] = nil
                else
                    requirement = copyRequirement(requirement)
                    if requirement and Validation:IsRequirement(slotKey, requirement) then
                        if languageChanged then
                            refreshRequirementLanguage(requirement)
                        end
                        setup.equipment[slotKey] = requirement
                    else
                        setup.equipment[slotKey] = nil
                    end
                end
            end
            for slotKey, state in pairs(setup.acquisition) do
                if not GravvyBuildPlannerSlots:IsValid(slotKey) or type(state) ~= "table" then
                    setup.acquisition[slotKey] = nil
                elseif not setup.equipment[slotKey]
                    or not validAcquisitionRoutes[state.preferredRoute] then
                    setup.acquisition[slotKey] = nil
                else
                    setup.acquisition[slotKey] = {
                        preferredRoute = state.preferredRoute,
                    }
                end
            end
            for _, mainHand in ipairs({ "frontMain", "backMain" }) do
                local requirement = setup.equipment[mainHand]
                local offHand = requirement and GravvyBuildPlannerSlots:GetOccupiedOffHand(
                    mainHand,
                    requirement.weaponType
                )
                if offHand then
                    requirement.occupiesOffHand = true
                    setup.equipment[offHand] = nil
                end
            end
            for slotKey, entries in pairs(setup.alternatives) do
                local primary = setup.equipment[slotKey]
                if not primary or type(entries) ~= "table" then
                    setup.alternatives[slotKey] = nil
                else
                    local alternatives = {}
                    for _, entry in ipairs(entries) do
                        local requirement = normalizeAlternative(slotKey, entry, primary)
                        if requirement and #alternatives < MAX_ALTERNATIVES then
                            if languageChanged then
                                refreshRequirementLanguage(requirement)
                            end
                            alternatives[#alternatives + 1] = requirement
                        end
                    end
                    setup.alternatives[slotKey] = #alternatives > 0 and alternatives or nil
                end
            end
        end
    end

    saved.nextBuildId = math.max(
        math.floor(tonumber(saved.nextBuildId) or 1),
        highestBuildId + 1
    )
    saved.nextSetupId = math.max(
        math.floor(tonumber(saved.nextSetupId) or 1),
        highestSetupId + 1
    )
    for _, build in ipairs(saved.builds) do
        local revisions = {}
        for _, revision in ipairs(build.revisions or {}) do
            local normalized = self:NormalizeRevisionSnapshot(revision.snapshot, build.id)
            if normalized then
                revision.snapshot = normalized
                if revisionSize(revision) <= MAX_REVISION_BYTES then
                    revisions[#revisions + 1] = revision
                end
            end
        end
        build.revisions = revisions
        self:TrimRevisionHistory(build)
    end
    saved.schemaVersion = SCHEMA_VERSION
    saved.language = currentLanguage()

    if #saved.builds == 0 then
        self:CreateBuild(GetString(SI_GRAVVY_BUILD_PLANNER_DEFAULT_BUILD))
        return
    end

    for _, build in ipairs(saved.builds) do
        if #build.setups == 0 then
            self:CreateSetup(build.id, GetString(SI_GRAVVY_BUILD_PLANNER_DEFAULT_SETUP))
        elseif not self:FindSetup(build, build.selectedSetupId) then
            build.selectedSetupId = build.setups[1].id
        end
    end
    if not self:FindBuild(saved.selectedBuildId) then
        saved.selectedBuildId = saved.builds[1].id
    end
end

local function finiteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

function Data:ValidateState(saved)
    if type(saved) ~= "table"
        or saved.schemaVersion ~= SCHEMA_VERSION
        or type(saved.language) ~= "string"
        or type(saved.builds) ~= "table"
        or #saved.builds < 1
        or #saved.builds > MAX_BUILDS
        or type(saved.deletedActions) ~= "table"
        or #saved.deletedActions > MAX_DELETED_ACTIONS
        or type(saved.settings) ~= "table"
        or type(saved.settings.window) ~= "table"
        or not finiteNumber(saved.settings.fontScale)
        or saved.settings.fontScale < 0.9
        or saved.settings.fontScale > 1.4
    then
        return false
    end
    local window = saved.settings.window
    if (window.left ~= nil and not finiteNumber(window.left))
        or (window.top ~= nil and not finiteNumber(window.top)) then
        return false
    end

    local buildIds = {}
    local setupIds = {}
    local highestBuildId = 0
    local highestSetupId = 0
    for _, build in ipairs(saved.builds) do
        if type(build) ~= "table"
            or not Validation:WholeNumber(build.id, 1, MAX_ID)
            or buildIds[build.id]
            or type(build.name) ~= "string"
            or build.name == ""
            or type(build.setups) ~= "table"
            or #build.setups < 1
            or #build.setups > MAX_SETUPS
            or type(build.revisions) ~= "table"
            or #build.revisions > MAX_REVISIONS then
            return false
        end
        buildIds[build.id] = true
        highestBuildId = math.max(highestBuildId, build.id)
        local selectedSetupFound = false
        for _, setup in ipairs(build.setups) do
            if type(setup) ~= "table"
                or not Validation:WholeNumber(setup.id, 1, MAX_ID)
                or setupIds[setup.id]
                or type(setup.name) ~= "string"
                or setup.name == ""
                or not Validation:IsQuality(setup.defaultQuality)
                or not Validation:IsLevel(setup.defaultLevel)
                or not Validation:IsChampionPoints(setup.defaultChampionPoints)
                or type(setup.equipment) ~= "table"
                or type(setup.alternatives) ~= "table" then
                return false
            end
            setupIds[setup.id] = true
            highestSetupId = math.max(highestSetupId, setup.id)
            if setup.id == build.selectedSetupId then selectedSetupFound = true end
            for slotKey, requirement in pairs(setup.equipment) do
                if not GravvyBuildPlannerSlots:IsValid(slotKey)
                    or not Validation:IsRequirement(slotKey, requirement) then
                    return false
                end
            end
            for slotKey, alternatives in pairs(setup.alternatives) do
                if not setup.equipment[slotKey]
                    or type(alternatives) ~= "table"
                    or #alternatives > MAX_ALTERNATIVES then
                    return false
                end
                for _, requirement in ipairs(alternatives) do
                    if not Validation:IsRequirement(slotKey, requirement) then
                        return false
                    end
                end
            end
        end
        if not selectedSetupFound then return false end
    end
    return buildIds[saved.selectedBuildId] == true
        and Validation:WholeNumber(saved.nextBuildId, highestBuildId + 1, MAX_ID)
        and Validation:WholeNumber(saved.nextSetupId, highestSetupId + 1, MAX_ID)
end

function Data:PrepareCandidate(source)
    local candidateSaved = extractState(source)
    local version = tonumber(candidateSaved.schemaVersion) or 1
    if version ~= math.floor(version) or version < 1 or version > SCHEMA_VERSION then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_DATA_SCHEMA_UNSUPPORTED)
    end
    local candidate = setmetatable({ saved = candidateSaved }, { __index = self })
    local ok = pcall(function() candidate:Normalize() end)
    if not ok or not candidate:ValidateState(candidate.saved) then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_DATA_MIGRATION_FAILED)
    end
    return candidate.saved
end

function Data:Migrate()
    local candidate, message = self:PrepareCandidate(self.saved)
    if not candidate then return false, message end
    applyState(self.saved, candidate)
    return true
end

function Data:CreateRecoverySnapshot(kind, source)
    local recovery = self.recovery
    if type(recovery) ~= "table" then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_RECOVERY_CREATE_FAILED)
    end
    recovery.snapshots = type(recovery.snapshots) == "table"
        and recovery.snapshots or {}
    recovery.nextId = math.max(1, math.floor(tonumber(recovery.nextId) or 1))
    local snapshot = extractState(source or self.saved)
    if type(snapshot.builds) ~= "table" then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_RECOVERY_CREATE_FAILED)
    end
    recovery.snapshots[#recovery.snapshots + 1] = {
        id = recovery.nextId,
        kind = tostring(kind or "checkpoint"),
        createdAt = now(),
        sourceSchema = tonumber(snapshot.schemaVersion) or 1,
        world = GetWorldName(),
        data = snapshot,
    }
    recovery.nextId = recovery.nextId + 1
    while #recovery.snapshots > MAX_RECOVERY_SNAPSHOTS do
        table.remove(recovery.snapshots, 1)
    end
    return true
end

function Data:GetRecoverySnapshots()
    return type(self.recovery) == "table"
        and type(self.recovery.snapshots) == "table"
        and self.recovery.snapshots or {}
end

function Data:RecoverLatestValidSnapshot()
    local snapshots = self:GetRecoverySnapshots()
    for index = #snapshots, 1, -1 do
        local candidate = self:PrepareCandidate(snapshots[index].data)
        if candidate then
            applyState(self.saved, candidate)
            self:CreateRecoverySnapshot("automatic_restore", self.saved)
            return true, snapshots[index]
        end
    end
    return false
end

function Data:RestoreRecoverySnapshot(id)
    for _, snapshot in ipairs(self:GetRecoverySnapshots()) do
        if snapshot.id == id then
            local candidate, message = self:PrepareCandidate(snapshot.data)
            if not candidate then return false, message end
            local saved, snapshotMessage = self:CreateRecoverySnapshot(
                "pre_restore",
                self.saved
            )
            if not saved then return false, snapshotMessage end
            applyState(self.saved, candidate)
            return true
        end
    end
    return false, GetString(SI_GRAVVY_BUILD_PLANNER_RECOVERY_MISSING)
end

function Data:GetBuilds()
    return self.saved.builds
end

function Data:GetSettings()
    return self.saved.settings
end

function Data:FindBuild(id)
    for index, build in ipairs(self.saved.builds) do
        if build.id == id then
            return build, index
        end
    end
end

function Data:FindSetup(build, id)
    if not build then
        return nil
    end
    for index, setup in ipairs(build.setups) do
        if setup.id == id then
            return setup, index
        end
    end
end

function Data:GetCurrentBuild()
    local build = self:FindBuild(self.saved.selectedBuildId)
    if not build then
        build = self.saved.builds[1]
        self.saved.selectedBuildId = build.id
    end
    return build
end

function Data:GetCurrentSetup()
    local build = self:GetCurrentBuild()
    local setup = self:FindSetup(build, build.selectedSetupId)
    if not setup then
        setup = build.setups[1]
        build.selectedSetupId = setup.id
    end
    return setup, build
end

function Data:BuildNameExists(name, exceptId)
    for _, build in ipairs(self.saved.builds) do
        if build.id ~= exceptId and sameName(build.name, name) then
            return true
        end
    end
    return false
end

function Data:GetUniqueBuildName(baseName, exceptId)
    baseName = plain(tostring(baseName or ""), MAX_NAME_LENGTH, true) or ""
    local name = baseName
    local suffix = 2
    while self:BuildNameExists(name, exceptId) do
        local ending = " " .. tostring(suffix)
        name = string.sub(baseName, 1, MAX_NAME_LENGTH - #ending) .. ending
        suffix = suffix + 1
    end
    return name
end

function Data:CreateBuild(name, values)
    if #self.saved.builds >= MAX_BUILDS then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_LIMIT)
    end
    name = plain(name, MAX_NAME_LENGTH, false)
    if not name then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_NAME)
    end
    if self:BuildNameExists(name) then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_EXISTS)
    end
    local changes = copyBuildChanges(values or {})
    if not changes then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REQUIREMENT)
    end

    local build = {
        id = self.saved.nextBuildId,
        name = name,
        classId = changes.classId,
        role = changes.role or "",
        patch = changes.patch or "",
        author = changes.author or "",
        sourceUrl = changes.sourceUrl or "",
        notes = changes.notes or "",
        setups = {},
        revisions = {},
        nextRevisionId = 1,
        createdAt = now(),
        updatedAt = now(),
    }
    self.saved.nextBuildId = self.saved.nextBuildId + 1
    self.saved.builds[#self.saved.builds + 1] = build
    self.saved.selectedBuildId = build.id

    local setup = self:CreateSetup(build.id, GetString(SI_GRAVVY_BUILD_PLANNER_DEFAULT_SETUP))
    build.selectedSetupId = setup.id
    return build
end

function Data:UpdateBuild(id, values)
    local build = self:FindBuild(id)
    if not build then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING)
    end
    local changes = copyBuildChanges(values)
    if not changes then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REQUIREMENT)
    end
    if values.name ~= nil then
        local name = plain(values.name, MAX_NAME_LENGTH, false)
        if not name then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_NAME)
        end
        if self:BuildNameExists(name, build.id) then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_EXISTS)
        end
        build.name = name
    end

    for key, value in pairs(changes) do
        build[key] = value
    end
    build.updatedAt = now()
    return true, build
end

function Data:RenameBuild(id, name)
    return self:UpdateBuild(id, { name = name })
end

function Data:DuplicateBuild(id, name)
    local source = self:FindBuild(id)
    if not source then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING)
    end

    if name ~= nil and type(name) ~= "string" then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_NAME)
    end
    if #self.saved.builds >= MAX_BUILDS then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_LIMIT)
    end
    name = type(name) == "string" and plain(name, MAX_NAME_LENGTH, true) or ""
    if name == "" then
        name = self:GetUniqueBuildName(zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_COPIED_BUILD_NAME,
            source.name
        ))
    end
    if self:BuildNameExists(name) then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_EXISTS)
    end

    local timestamp = now()
    local build = {
        id = self.saved.nextBuildId,
        name = name,
        classId = source.classId,
        role = source.role,
        patch = source.patch,
        author = source.author,
        sourceUrl = source.sourceUrl,
        notes = source.notes,
        setups = {},
        revisions = {},
        nextRevisionId = 1,
        createdAt = timestamp,
        updatedAt = timestamp,
    }
    self.saved.nextBuildId = self.saved.nextBuildId + 1

    for _, sourceSetup in ipairs(source.setups) do
        local setup = {
            id = self.saved.nextSetupId,
            name = sourceSetup.name,
            note = sourceSetup.note,
            defaultQuality = sourceSetup.defaultQuality,
            defaultLevel = sourceSetup.defaultLevel,
            defaultChampionPoints = sourceSetup.defaultChampionPoints,
            equipment = deepCopy(sourceSetup.equipment),
            alternatives = deepCopy(sourceSetup.alternatives),
            skillBars = deepCopy(sourceSetup.skillBars) or { front = {}, back = {} },
            character = copyCharacterPlan(sourceSetup.character, false),
            champion = copyChampionPlan(sourceSetup.champion, false),
            consumables = copyConsumables(sourceSetup.consumables, false),
            checklist = copyChecklist(sourceSetup.checklist, false),
            acquisition = {},
            createdAt = timestamp,
            updatedAt = timestamp,
        }
        self.saved.nextSetupId = self.saved.nextSetupId + 1
        build.setups[#build.setups + 1] = setup
        if sourceSetup.id == source.selectedSetupId then
            build.selectedSetupId = setup.id
        end
    end
    build.selectedSetupId = build.selectedSetupId or build.setups[1].id

    self.saved.builds[#self.saved.builds + 1] = build
    self.saved.selectedBuildId = build.id
    return build
end

function Data:NormalizeImportedBuild(source, exceptBuildId)
    if type(source) ~= "table" or type(source.setups) ~= "table"
        or #source.setups == 0 or #source.setups > MAX_SETUPS then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
    end

    local name = plain(source.name, MAX_NAME_LENGTH, false)
    local changes = copyBuildChanges(source)
    if not name or not changes then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
    end

    local timestamp = now()
    local build = {
        id = self.saved.nextBuildId,
        name = self:GetUniqueBuildName(name, exceptBuildId),
        classId = changes.classId,
        role = changes.role or "",
        patch = changes.patch or "",
        author = changes.author or "",
        sourceUrl = changes.sourceUrl or "",
        notes = changes.notes or "",
        setups = {},
        revisions = {},
        nextRevisionId = 1,
        createdAt = timestamp,
        updatedAt = timestamp,
    }

    local usedNames = {}
    for _, sourceSetup in ipairs(source.setups) do
        if type(sourceSetup) ~= "table" or type(sourceSetup.equipment) ~= "table" then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        local setupName = plain(sourceSetup.name, MAX_NAME_LENGTH, false)
        local setupChanges = copySetupChanges(sourceSetup)
        if not setupName or not setupChanges then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        setupName = makeUniqueName(usedNames, setupName)

        local equipment = {}
        for slotKey, sourceRequirement in pairs(sourceSetup.equipment) do
            local requirement = copyRequirement(sourceRequirement)
            if not GravvyBuildPlannerSlots:IsValid(slotKey)
                or not requirement
                or not Validation:IsRequirement(slotKey, requirement) then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            equipment[slotKey] = requirement
        end
        for _, mainHand in ipairs({ "frontMain", "backMain" }) do
            local requirement = equipment[mainHand]
            local offHand = requirement and GravvyBuildPlannerSlots:GetOccupiedOffHand(
                mainHand,
                requirement.weaponType
            )
            if offHand then
                if equipment[offHand] then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                requirement.occupiesOffHand = true
            end
        end

        local acquisition = {}
        if sourceSetup.acquisition ~= nil and type(sourceSetup.acquisition) ~= "table" then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        for slotKey, state in pairs(sourceSetup.acquisition or {}) do
            if equipment[slotKey]
                and type(state) == "table"
                and validAcquisitionRoutes[state.preferredRoute] then
                acquisition[slotKey] = { preferredRoute = state.preferredRoute }
            else
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
        end

        local alternatives = {}
        if sourceSetup.alternatives ~= nil and type(sourceSetup.alternatives) ~= "table" then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        for slotKey, entries in pairs(sourceSetup.alternatives or {}) do
            local primary = equipment[slotKey]
            if not primary or type(entries) ~= "table" or #entries > MAX_ALTERNATIVES then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            alternatives[slotKey] = {}
            for _, entry in ipairs(entries) do
                local requirement = normalizeAlternative(slotKey, entry, primary)
                if not requirement then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                alternatives[slotKey][#alternatives[slotKey] + 1] = requirement
            end
        end
        local skillBars = copySkillBars(sourceSetup.skillBars, true)
        if not skillBars then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        local character = copyCharacterPlan(sourceSetup.character, true)
        if not character then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        local champion = copyChampionPlan(sourceSetup.champion, true)
        if not champion then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        local consumables = copyConsumables(sourceSetup.consumables, true)
        if not consumables then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        local checklist = copyChecklist(sourceSetup.checklist, true)
        if not checklist then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end

        build.setups[#build.setups + 1] = {
            id = self.saved.nextSetupId + #build.setups,
            name = setupName,
            note = setupChanges.note or "",
            defaultQuality = setupChanges.defaultQuality or DEFAULT_QUALITY,
            defaultLevel = setupChanges.defaultLevel or 50,
            defaultChampionPoints = setupChanges.defaultChampionPoints or 160,
            equipment = equipment,
            alternatives = alternatives,
            skillBars = skillBars,
            character = character,
            champion = champion,
            consumables = consumables,
            checklist = checklist,
            statSnapshots = copyStatSnapshots(
                sourceSetup.statSnapshots,
                sourceSetup.statSnapshot
            ),
            acquisition = acquisition,
            createdAt = timestamp,
            updatedAt = timestamp,
        }
    end

    local selectedIndex = source.selectedSetupIndex == nil
        and 1
        or readWholeNumber(source.selectedSetupIndex, 1)
    if not selectedIndex or selectedIndex > #build.setups then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
    end
    build.selectedSetupId = build.setups[selectedIndex].id
    return build
end

function Data:ImportBuild(source)
    if #self.saved.builds >= MAX_BUILDS then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_LIMIT)
    end
    local build, message = self:NormalizeImportedBuild(source)
    if not build then
        return nil, message
    end
    self.saved.nextBuildId = self.saved.nextBuildId + 1
    self.saved.nextSetupId = self.saved.nextSetupId + #build.setups
    self.saved.builds[#self.saved.builds + 1] = build
    self.saved.selectedBuildId = build.id
    return build
end

function Data:NormalizeRevisionSnapshot(source, buildId)
    local normalized, message = self:NormalizeImportedBuild(source, buildId)
    if not normalized then
        return nil, message
    end
    local selectedSetupIndex = 1
    for index, setup in ipairs(normalized.setups) do
        if setup.id == normalized.selectedSetupId then
            selectedSetupIndex = index
            break
        end
    end
    local usedIds = {}
    for index, setup in ipairs(normalized.setups) do
        local sourceSetup = source.setups[index]
        local setupId = sourceSetup and Validation:WholeNumber(sourceSetup.id, 1, MAX_ID)
        if not setupId or usedIds[setupId] then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        setup.id = setupId
        usedIds[setupId] = true
    end
    normalized.id = nil
    normalized.revisions = nil
    normalized.nextRevisionId = nil
    normalized.selectedSetupIndex = selectedSetupIndex
    normalized.selectedSetupId = nil
    return normalized
end

function Data:TrimRevisionHistory(build, protectedRevisionId)
    local evicted = 0
    while #build.revisions > MAX_REVISIONS
        or revisionHistorySize(build.revisions) > MAX_REVISION_BYTES do
        local removeIndex
        for index = #build.revisions, 1, -1 do
            if build.revisions[index].id ~= protectedRevisionId then
                removeIndex = index
                break
            end
        end
        if not removeIndex then break end
        table.remove(build.revisions, removeIndex)
        evicted = evicted + 1
    end
    return evicted
end

function Data:GetRevisions(buildId)
    local build = self:FindBuild(buildId)
    return build and build.revisions or {}
end

function Data:FindRevision(build, revisionId)
    if not build then
        return nil
    end
    for index, revision in ipairs(build.revisions or {}) do
        if revision.id == revisionId then
            return revision, index
        end
    end
end

function Data:RevisionNameExists(build, name)
    for _, revision in ipairs(build.revisions or {}) do
        if sameName(revision.name, name) then
            return true
        end
    end
    return false
end

function Data:GetUniqueRevisionName(build, baseName)
    baseName = plain(tostring(baseName or ""), MAX_REVISION_NAME, true) or ""
    if #baseName > MAX_REVISION_NAME then
        baseName = string.sub(baseName, 1, MAX_REVISION_NAME)
    end
    local name = baseName
    local suffix = 2
    while self:RevisionNameExists(build, name) do
        local ending = " " .. tostring(suffix)
        name = string.sub(baseName, 1, MAX_REVISION_NAME - #ending) .. ending
        suffix = suffix + 1
    end
    return name
end

function Data:CreateRevision(buildId, name)
    local build = self:FindBuild(buildId)
    if not build then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING)
    end
    name = plain(name, MAX_REVISION_NAME, false)
    if not name then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REVISION_NAME)
    end
    if self:RevisionNameExists(build, name) then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REVISION_EXISTS)
    end

    local revision = {
        id = build.nextRevisionId,
        name = name,
        patch = build.patch,
        createdAt = now(),
        snapshot = makeBuildSnapshot(build),
    }
    if revisionSize(revision) > MAX_REVISION_BYTES then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REVISION_TOO_LARGE)
    end
    build.nextRevisionId = build.nextRevisionId + 1
    table.insert(build.revisions, 1, revision)
    local evicted = self:TrimRevisionHistory(build, revision.id)
    local messageId = evicted > 0
        and SI_GRAVVY_BUILD_PLANNER_REVISION_SAVED_EVICTED
        or SI_GRAVVY_BUILD_PLANNER_REVISION_SAVED
    return revision, zo_strformat(messageId, name, evicted)
end

function Data:DeleteRevision(buildId, revisionId)
    local build = self:FindBuild(buildId)
    local revision, index = self:FindRevision(build, revisionId)
    if not revision then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REVISION_MISSING)
    end
    table.remove(build.revisions, index)
    return true, zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_REVISION_DELETED,
        revision.name
    )
end

function Data:RestoreRevision(buildId, revisionId)
    local build = self:FindBuild(buildId)
    local revision = self:FindRevision(build, revisionId)
    if not revision then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REVISION_MISSING)
    end

    local imported, message = self:NormalizeImportedBuild(
        deepCopy(revision.snapshot),
        build.id
    )
    if not imported then
        self.saved.selectedBuildId = build.id
        return nil, message
    end

    local reservedSetupIds = {}
    for _, otherBuild in ipairs(self.saved.builds) do
        if otherBuild.id ~= build.id then
            for _, otherSetup in ipairs(otherBuild.setups) do
                reservedSetupIds[otherSetup.id] = true
            end
        end
    end
    local restoredIds = {}
    for index, importedSetup in ipairs(imported.setups) do
        local sourceId = Validation:WholeNumber(
            revision.snapshot.setups[index].id,
            1,
            MAX_ID
        )
        if not sourceId or reservedSetupIds[sourceId] or restoredIds[sourceId] then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        importedSetup.id = sourceId
        restoredIds[sourceId] = true
    end
    local selectedIndex = revision.snapshot.selectedSetupIndex or 1
    imported.selectedSetupId = imported.setups[selectedIndex].id
    local backupName = self:GetUniqueRevisionName(build, zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_REVISION_BEFORE_RESTORE,
        revision.name
    ))
    local backupCandidate = {
        id = build.nextRevisionId,
        name = backupName,
        patch = build.patch,
        createdAt = now(),
        snapshot = makeBuildSnapshot(build),
    }
    if revisionSize(revision) + revisionSize(backupCandidate) > MAX_REVISION_BYTES then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REVISION_TOO_LARGE)
    end
    local backup, backupError = self:CreateRevision(build.id, backupName)
    if not backup then
        self.saved.selectedBuildId = build.id
        return nil, backupError
    end
    if not self:FindRevision(build, revision.id) then
        table.insert(build.revisions, 2, revision)
        self:TrimRevisionHistory(build, revision.id)
    end

    build.name = self:GetUniqueBuildName(revision.snapshot.name, build.id)
    build.classId = imported.classId
    build.role = imported.role
    build.patch = imported.patch
    build.author = imported.author
    build.sourceUrl = imported.sourceUrl
    build.notes = imported.notes
    build.setups = imported.setups
    build.selectedSetupId = imported.selectedSetupId
    build.updatedAt = now()
    self.saved.selectedBuildId = build.id
    return build, zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_REVISION_RESTORED,
        revision.name
    )
end

function Data:SelectBuild(id)
    local build = self:FindBuild(id)
    if not build then
        return false
    end
    self.saved.selectedBuildId = build.id
    return true
end

function Data:MoveBuild(id, direction)
    direction = tonumber(direction)
    if not direction or direction == 0 then
        return false
    end
    direction = direction < 0 and -1 or 1
    local _, index = self:FindBuild(id)
    local target = index and zo_clamp(index + direction, 1, #self.saved.builds)
    if not target or target == index then
        return false
    end
    local builds = self.saved.builds
    builds[index], builds[target] = builds[target], builds[index]
    return true
end

function Data:CreateSetup(buildId, name, source)
    local build = self:FindBuild(buildId)
    if not build then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING)
    end
    if #build.setups >= MAX_SETUPS then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_LIMIT)
    end
    name = plain(name, MAX_NAME_LENGTH, false)
    if not name then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_NAME)
    end
    if setupNameExists(build, name) then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_EXISTS)
    end
    if source ~= nil and type(source) ~= "table" then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REQUIREMENT)
    end
    if source then
        local sourceCopy = deepCopy(source)
        sourceCopy.name = name
        local normalized = self:NormalizeImportedBuild({
            name = build.name,
            classId = build.classId,
            role = build.role,
            patch = build.patch,
            author = build.author,
            sourceUrl = build.sourceUrl,
            notes = build.notes,
            selectedSetupIndex = 1,
            setups = { sourceCopy },
        }, build.id)
        if not normalized then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REQUIREMENT)
        end
        source = normalized.setups[1]
    end

    local setup = {
        id = self.saved.nextSetupId,
        name = name,
        note = source and normalizeNote(source.note) or "",
        defaultQuality = source and source.defaultQuality or DEFAULT_QUALITY,
        defaultLevel = source and source.defaultLevel or 50,
        defaultChampionPoints = source and source.defaultChampionPoints or 160,
        equipment = source and deepCopy(source.equipment) or {},
        alternatives = source and deepCopy(source.alternatives) or {},
        skillBars = source and deepCopy(source.skillBars) or { front = {}, back = {} },
        character = source and copyCharacterPlan(source.character, false) or blankCharacterPlan(),
        champion = source and copyChampionPlan(source.champion, false) or blankChampionPlan(),
        consumables = source and copyConsumables(source.consumables, false) or {},
        checklist = source and copyChecklist(source.checklist, false) or {},
        acquisition = {},
        createdAt = now(),
        updatedAt = now(),
    }
    self.saved.nextSetupId = self.saved.nextSetupId + 1
    build.setups[#build.setups + 1] = setup
    build.selectedSetupId = setup.id
    build.updatedAt = now()
    return setup
end

function Data:DuplicateSetup(buildId, setupId, name)
    local build = self:FindBuild(buildId)
    if not build then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING)
    end
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    if name ~= nil and type(name) ~= "string" then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_NAME)
    end
    name = type(name) == "string" and plain(name, MAX_NAME_LENGTH, true) or ""
    if name == "" then
        name = uniqueSetupName(build, zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_COPIED_SETUP_NAME,
            setup.name
        ))
    end
    return self:CreateSetup(build.id, name, setup)
end

function Data:RenameSetup(buildId, setupId, name)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    name = plain(name, MAX_NAME_LENGTH, false)
    if not name then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_NAME)
    end
    if setupNameExists(build, name, setup.id) then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_EXISTS)
    end
    setup.name = name
    setup.updatedAt = now()
    return true, setup
end

function Data:UpdateSetup(buildId, setupId, values)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    local changes = copySetupChanges(values)
    if not changes then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REQUIREMENT)
    end
    for key, value in pairs(changes) do
        setup[key] = value
    end
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true, setup
end

function Data:SetStatSnapshot(buildId, setupId, bar, snapshot)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    if bar ~= "front" and bar ~= "back" then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_STAT_BAR)
    end
    local copy = copyStatSnapshot(snapshot)
    if not copy then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CAPTURE_UNAVAILABLE)
    end
    local contextKey = type(snapshot.contextKey) == "string"
        and plain(snapshot.contextKey, MAX_NAME_LENGTH, false) or "general"
    local contextName = type(snapshot.contextName) == "string"
        and plain(snapshot.contextName, MAX_NAME_LENGTH, false) or contextKey
    if not contextKey or not contextName then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CONTEXT_INVALID)
    end
    setup.statSnapshots = setup.statSnapshots or {}
    copy.bar = bar
    copy.fingerprint = self:GetSetupFingerprint(setup)
    if zo_strlower(contextKey) == "general" then
        setup.statSnapshots[bar] = copy
    else
        setup.statSnapshots.contexts = setup.statSnapshots.contexts or {}
        local context
        for _, entry in ipairs(setup.statSnapshots.contexts) do
            if zo_strlower(entry.key) == zo_strlower(contextKey) then
                context = entry
                break
            end
        end
        if not context then
            if #setup.statSnapshots.contexts >= MAX_STAT_CONTEXTS then
                return false, GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CONTEXT_LIMIT)
            end
            context = { key = contextKey, name = contextName }
            setup.statSnapshots.contexts[#setup.statSnapshots.contexts + 1] = context
        end
        context.name = contextName
        context[bar] = copy
    end
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true, setup
end

function Data:ClearStatSnapshot(buildId, setupId, bar, contextKey)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    if bar ~= "front" and bar ~= "back" then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_STAT_BAR)
    end
    contextKey = type(contextKey) == "string" and zo_strlower(contextKey) or "general"
    if setup.statSnapshots then
        if contextKey == "general" then
            setup.statSnapshots[bar] = nil
        else
            for index, context in ipairs(setup.statSnapshots.contexts or {}) do
                if zo_strlower(context.key) == contextKey then
                    context[bar] = nil
                    if not context.front and not context.back then
                        table.remove(setup.statSnapshots.contexts, index)
                    end
                    break
                end
            end
            if setup.statSnapshots.contexts and #setup.statSnapshots.contexts == 0 then
                setup.statSnapshots.contexts = nil
            end
        end
        if next(setup.statSnapshots) == nil then
            setup.statSnapshots = nil
        end
    end
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true, setup
end

function Data:GetStatSnapshot(setup, bar, contextKey)
    if not setup or not setup.statSnapshots then return nil end
    contextKey = type(contextKey) == "string" and zo_strlower(contextKey) or "general"
    if contextKey == "general" then return setup.statSnapshots[bar] end
    for _, context in ipairs(setup.statSnapshots.contexts or {}) do
        if zo_strlower(context.key) == contextKey then return context[bar], context end
    end
end

function Data:GetStatContexts(setup)
    return setup and setup.statSnapshots and setup.statSnapshots.contexts or {}
end

function Data:GetSetupFingerprint(setup)
    return setup and fingerprint(setupFingerprintPayload(setup)) or nil
end

function Data:IsStatSnapshotStale(setup, bar, contextKey)
    local snapshot = self:GetStatSnapshot(setup, bar, contextKey)
    if not snapshot then
        return nil
    end
    return snapshot.bar ~= bar
        or snapshot.fingerprint == nil
        or snapshot.fingerprint ~= self:GetSetupFingerprint(setup)
end

function Data:SelectSetup(buildId, setupId)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return false
    end
    self.saved.selectedBuildId = build.id
    build.selectedSetupId = setup.id
    return true
end

function Data:MoveSetup(buildId, setupId, direction)
    local build = self:FindBuild(buildId)
    direction = tonumber(direction)
    if not build or not direction or direction == 0 then
        return false
    end
    direction = direction < 0 and -1 or 1
    local _, index = self:FindSetup(build, setupId)
    local target = index and zo_clamp(index + direction, 1, #build.setups)
    if not target or target == index then
        return false
    end
    build.setups[index], build.setups[target] = build.setups[target], build.setups[index]
    build.updatedAt = now()
    return true
end

function Data:SetEquipment(buildId, setupId, slotKey, values)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    if not GravvyBuildPlannerSlots:IsValid(slotKey) then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SLOT)
    end
    if values == nil then
        setup.equipment[slotKey] = nil
        setup.alternatives[slotKey] = nil
        setup.acquisition[slotKey] = nil
        setup.updatedAt = now()
        build.updatedAt = setup.updatedAt
        return true
    end

    local requirement = copyRequirement(values)
    if not requirement or not Validation:IsRequirement(slotKey, requirement) then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REQUIREMENT)
    end

    local mainHand = GravvyBuildPlannerSlots:GetMainHand(slotKey)
    if mainHand then
        local mainRequirement = setup.equipment[mainHand]
        if mainRequirement and mainRequirement.occupiesOffHand then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SLOT_OCCUPIED)
        end
    end

    local clearedOffHand = GravvyBuildPlannerSlots:GetOccupiedOffHand(
        slotKey,
        requirement.weaponType
    )
    requirement.occupiesOffHand = clearedOffHand ~= nil
    setup.equipment[slotKey] = requirement
    local alternatives = setup.alternatives[slotKey]
    if alternatives then
        local compatible = {}
        for _, alternative in ipairs(alternatives) do
            alternative = normalizeAlternative(slotKey, alternative, requirement)
            if alternative then
                compatible[#compatible + 1] = alternative
            end
        end
        setup.alternatives[slotKey] = #compatible > 0 and compatible or nil
    end
    if clearedOffHand then
        setup.equipment[clearedOffHand] = nil
        setup.alternatives[clearedOffHand] = nil
        setup.acquisition[clearedOffHand] = nil
    end
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true, requirement, clearedOffHand
end

function Data:GetAlternatives(setup, slotKey)
    return setup and setup.alternatives and setup.alternatives[slotKey] or {}
end

function Data:SetSkill(buildId, setupId, barKey, slotIndex, values)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    slotIndex = tonumber(slotIndex)
    if not setup or (barKey ~= "front" and barKey ~= "back")
        or not slotIndex or slotIndex ~= math.floor(slotIndex)
        or slotIndex < 1 or slotIndex > 6 then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SKILL_SLOT)
    end
    setup.skillBars = setup.skillBars or { front = {}, back = {} }
    if values == nil then
        setup.skillBars[barKey][slotIndex] = nil
    else
        local skill = copySkill(values, slotIndex)
        if not skill then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SKILL)
        end
        for otherSlot, otherSkill in pairs(setup.skillBars[barKey]) do
            if otherSlot ~= slotIndex and otherSkill.abilityId == skill.abilityId then
                return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SKILL_DUPLICATE)
            end
        end
        setup.skillBars[barKey][slotIndex] = skill
    end
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true
end

function Data:UpdateCharacter(buildId, setupId, values)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    local character = copyCharacterPlan(values, true)
    if not character then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHARACTER)
    end
    setup.character = character
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true, character
end

function Data:SetChampionAllocation(buildId, setupId, disciplineKey, values)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    local discipline = setup and setup.champion and setup.champion[disciplineKey]
    if not discipline then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHAMPION)
    end
    local skillId = values and readWholeNumber(values.skillId, 1)
    if not skillId then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHAMPION)
    end
    local existingIndex
    for index, allocation in ipairs(discipline.allocations) do
        if allocation.skillId == skillId then
            existingIndex = index
            break
        end
    end
    if values.remove == true then
        if existingIndex then
            table.remove(discipline.allocations, existingIndex)
            for index = 1, 4 do
                if discipline.slottables[index] == skillId then
                    discipline.slottables[index] = 0
                end
            end
        end
    else
        local allocation = copyChampionAllocation(values)
        if not allocation then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHAMPION)
        end
        for key, otherDiscipline in pairs(setup.champion) do
            if key ~= disciplineKey then
                for _, other in ipairs(otherDiscipline.allocations) do
                    if other.skillId == skillId then
                        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHAMPION_DUPLICATE)
                    end
                end
            end
        end
        if existingIndex then
            discipline.allocations[existingIndex] = allocation
        elseif #discipline.allocations < MAX_CHAMPION_ALLOCATIONS then
            discipline.allocations[#discipline.allocations + 1] = allocation
        else
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHAMPION_LIMIT)
        end
        if not allocation.isSlottable then
            for index = 1, 4 do
                if discipline.slottables[index] == skillId then
                    discipline.slottables[index] = 0
                end
            end
        end
    end
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true
end

function Data:SetChampionSlottable(buildId, setupId, disciplineKey, slotIndex, skillId)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    local discipline = setup and setup.champion and setup.champion[disciplineKey]
    slotIndex = readWholeNumber(slotIndex, 1)
    if not discipline or not slotIndex or slotIndex > 4 then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHAMPION_SLOT)
    end
    if skillId == nil then
        discipline.slottables[slotIndex] = 0
    else
        skillId = readWholeNumber(skillId, 1)
        local allocation
        for _, entry in ipairs(discipline.allocations) do
            if entry.skillId == skillId then
                allocation = entry
                break
            end
        end
        if not allocation or not allocation.isSlottable then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHAMPION_SLOT)
        end
        for index, otherSkillId in ipairs(discipline.slottables) do
            if otherSkillId == skillId and index ~= slotIndex then
                return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHAMPION_DUPLICATE)
            end
        end
        discipline.slottables[slotIndex] = skillId
    end
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true
end

function Data:SetConsumable(buildId, setupId, index, values)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    if index ~= nil then
        index = readWholeNumber(index, 1)
        if not index then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CONSUMABLE)
        end
    end
    if index and index > #setup.consumables then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CONSUMABLE)
    end
    if values == nil then
        if not index then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CONSUMABLE)
        end
        table.remove(setup.consumables, index)
    else
        local entry = copyConsumable(values)
        if not entry then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CONSUMABLE)
        end
        for otherIndex, other in ipairs(setup.consumables) do
            if otherIndex ~= index and other.category == entry.category
                and zo_strlower(other.name) == zo_strlower(entry.name) then
                return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CONSUMABLE_DUPLICATE)
            end
        end
        if index then
            setup.consumables[index] = entry
        elseif #setup.consumables < MAX_CONSUMABLES then
            setup.consumables[#setup.consumables + 1] = entry
            index = #setup.consumables
        else
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CONSUMABLE_LIMIT)
        end
    end
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true, index
end

function Data:SetChecklistEntry(buildId, setupId, index, values)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    if index ~= nil then
        index = readWholeNumber(index, 1)
        if not index or index > #setup.checklist then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHECKLIST)
        end
    end
    if values == nil then
        if not index then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHECKLIST)
        end
        table.remove(setup.checklist, index)
    else
        local entry = copyChecklistEntry(values)
        if not entry then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHECKLIST)
        end
        for otherIndex, other in ipairs(setup.checklist) do
            if otherIndex ~= index and other.category == entry.category
                and zo_strlower(other.name) == zo_strlower(entry.name) then
                return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHECKLIST_DUPLICATE)
            end
        end
        if index then
            setup.checklist[index] = entry
        elseif #setup.checklist < MAX_CHECKLIST_ENTRIES then
            setup.checklist[#setup.checklist + 1] = entry
            index = #setup.checklist
        else
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHECKLIST_LIMIT)
        end
    end
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true, index
end

function Data:SetChecklistCompleted(buildId, setupId, index, completed)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    index = readWholeNumber(index, 1)
    local entry = setup and index and setup.checklist[index]
    if not entry then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHECKLIST)
    end
    entry.completed = completed == true
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true
end

function Data:SetAlternative(buildId, setupId, slotKey, index, values)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    local primary = setup and setup.equipment[slotKey]
    if not primary then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SOURCE_SLOT_EMPTY)
    end

    local alternatives = setup.alternatives[slotKey] or {}
    index = tonumber(index) or (#alternatives + 1)
    if index ~= math.floor(index) or index < 1 or index > #alternatives + 1
        or index > MAX_ALTERNATIVES then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_ALTERNATIVE_LIMIT)
    end
    if values == nil then
        if not alternatives[index] then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REQUIREMENT)
        end
        table.remove(alternatives, index)
        setup.alternatives[slotKey] = #alternatives > 0 and alternatives or nil
    else
        local requirement = normalizeAlternative(slotKey, values, primary)
        if not requirement then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_ALTERNATIVE)
        end
        alternatives[index] = requirement
        setup.alternatives[slotKey] = alternatives
    end
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true, values and alternatives[index] or nil
end

function Data:ApplySetAlternative(buildId, setupId, sourceSlot, alternativeIndex)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    local primary = setup and setup.equipment[sourceSlot]
    local source = primary and self:GetAlternatives(setup, sourceSlot)[alternativeIndex]
    if not source or trim(primary.setName) == "" or trim(source.setName) == "" then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_ALTERNATIVE)
    end

    local added = 0
    for _, slotKey in ipairs(GravvyBuildPlannerSlots.ORDER) do
        local planned = setup.equipment[slotKey]
        if planned and slotKey ~= sourceSlot and sameSet(planned, primary) then
            local replacement = copyRequirement(planned)
            replacement.setId = source.setId
            replacement.setName = source.setName
            replacement.itemLink = nil
            replacement.itemId = nil
            replacement.itemName = nil
            replacement.enchantmentId = nil
            local duplicate = false
            for _, existing in ipairs(self:GetAlternatives(setup, slotKey)) do
                if sameSet(existing, replacement) then
                    duplicate = true
                    break
                end
            end
            if not duplicate then
                local ok = self:SetAlternative(buildId, setupId, slotKey, nil, replacement)
                if ok then
                    added = added + 1
                end
            end
        end
    end
    return true, added
end

function Data:SetPreferredRoute(buildId, setupId, slotKey, route)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup or not setup.equipment[slotKey] then
        return false
    end
    if route ~= nil and not validAcquisitionRoutes[route] then
        return false
    end

    setup.acquisition[slotKey] = route and { preferredRoute = route } or nil
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true
end

local function transferEquipment(self, buildId, setupId, sourceSlot, targetSlot, move)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end

    local source = setup.equipment[sourceSlot]
    if not source then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SOURCE_SLOT_EMPTY)
    end
    if not GravvyBuildPlannerSlots:IsTransferCompatible(sourceSlot, targetSlot, source) then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_TRANSFER_SLOT)
    end

    local requirement = copyRequirement(source)
    requirement.itemLink = nil
    requirement.itemId = nil
    requirement.itemName = nil
    requirement.enchantmentId = nil

    local sourceAcquisition = setup.acquisition[sourceSlot]
    local targetAcquisition = setup.acquisition[targetSlot]
    local sourceAlternatives = deepCopy(setup.alternatives[sourceSlot] or {})
    local targetAlternatives = setup.alternatives[targetSlot]
    setup.acquisition[targetSlot] = nil
    setup.alternatives[targetSlot] = nil
    local ok, result, clearedOffHand = self:SetEquipment(
        buildId,
        setupId,
        targetSlot,
        requirement
    )
    if not ok then
        setup.acquisition[targetSlot] = targetAcquisition
        setup.alternatives[targetSlot] = targetAlternatives
        return false, result
    end
    for _, alternative in ipairs(sourceAlternatives) do
        alternative.itemLink = nil
        alternative.itemId = nil
        alternative.itemName = nil
        alternative.enchantmentId = nil
        self:SetAlternative(buildId, setupId, targetSlot, nil, alternative)
    end
    if move then
        setup.equipment[sourceSlot] = nil
        setup.alternatives[sourceSlot] = nil
        setup.acquisition[sourceSlot] = nil
        if sourceAcquisition and sourceAcquisition.preferredRoute then
            setup.acquisition[targetSlot] = {
                preferredRoute = sourceAcquisition.preferredRoute,
            }
        end
        setup.updatedAt = now()
        build.updatedAt = setup.updatedAt
    end
    return true, result, clearedOffHand
end

function Data:CopyEquipment(buildId, setupId, sourceSlot, targetSlot)
    return transferEquipment(self, buildId, setupId, sourceSlot, targetSlot, false)
end

function Data:MoveEquipment(buildId, setupId, sourceSlot, targetSlot)
    return transferEquipment(self, buildId, setupId, sourceSlot, targetSlot, true)
end

function Data:PushDeletedAction(action)
    action.deletedAt = now()
    local actions = self.saved.deletedActions
    actions[#actions + 1] = action
    while #actions > MAX_DELETED_ACTIONS do
        table.remove(actions, 1)
    end
end

function Data:DeleteBuild(id)
    local build, index = self:FindBuild(id)
    if not build then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING)
    end
    if #self.saved.builds == 1 then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_REQUIRED)
    end
    self:PushDeletedAction({ kind = "build", build = build, index = index })
    table.remove(self.saved.builds, index)
    self.saved.selectedBuildId = self.saved.builds[math.min(index, #self.saved.builds)].id
    return true, build
end

function Data:DeleteSetup(buildId, setupId)
    local build = self:FindBuild(buildId)
    if not build then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING)
    end
    local setup, index = self:FindSetup(build, setupId)
    if not setup then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    if #build.setups == 1 then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_REQUIRED)
    end
    self:PushDeletedAction({
        kind = "setup",
        buildId = build.id,
        setup = setup,
        index = index,
    })
    table.remove(build.setups, index)
    build.selectedSetupId = build.setups[math.min(index, #build.setups)].id
    build.updatedAt = now()
    return true, setup
end

function Data:UndoLastDeletion()
    local actions = self.saved.deletedActions
    local action = actions[#actions]
    if not action then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_NOTHING_TO_UNDO)
    end

    if action.kind == "build" and action.build then
        local build = action.build
        build.name = self:GetUniqueBuildName(build.name, build.id)
        local index = zo_clamp(action.index or (#self.saved.builds + 1), 1, #self.saved.builds + 1)
        table.insert(self.saved.builds, index, build)
        self.saved.selectedBuildId = build.id
    elseif action.kind == "setup" and action.setup then
        local build = self:FindBuild(action.buildId)
        if not build then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING)
        end
        local setup = action.setup
        setup.name = uniqueSetupName(build, setup.name, setup.id)
        local index = zo_clamp(action.index or (#build.setups + 1), 1, #build.setups + 1)
        table.insert(build.setups, index, setup)
        build.selectedSetupId = setup.id
        self.saved.selectedBuildId = build.id
    else
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_NOTHING_TO_UNDO)
    end

    table.remove(actions)
    return true, action
end

function Data:CanUndoDeletion()
    return #self.saved.deletedActions > 0
end
