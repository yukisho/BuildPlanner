GravvyBuildPlannerBuildValidation = {}

local BuildValidation = GravvyBuildPlannerBuildValidation
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

local weaponLines = {
    [1] = "twoHanded",
    [2] = "oneHandShield",
    [3] = "dualWield",
    [4] = "bow",
    [5] = "destructionStaff",
    [6] = "restorationStaff",
}

local weaponLineNames = {
    ["two handed"] = "twoHanded",
    ["one hand and shield"] = "oneHandShield",
    ["dual wield"] = "dualWield",
    ["bow"] = "bow",
    ["destruction staff"] = "destructionStaff",
    ["restoration staff"] = "restorationStaff",
}

local function lower(value)
    value = tostring(value or "")
    return zo_strlower and zo_strlower(value) or string.lower(value)
end

local function slotName(slotKey)
    return GetString(slotStringIds[slotKey])
end

local function hasValue(value, ...)
    for index = 1, select("#", ...) do
        local candidate = select(index, ...)
        if candidate ~= nil and value == candidate then
            return true
        end
    end
    return false
end

local function isOccupiedOffHand(setup, slotKey)
    local mainHand = Slots:GetMainHand(slotKey)
    local main = mainHand and setup.equipment and setup.equipment[mainHand]
    return main and (main.occupiesOffHand or Slots:IsTwoHanded(main.weaponType))
end

local function pieceWeight(slotKey, requirement)
    return (slotKey == "frontMain" or slotKey == "backMain")
        and Slots:IsTwoHanded(requirement.weaponType) and 2 or 1
end

local function addIssue(report, severity, text, key)
    report.issues[#report.issues + 1] = {
        severity = severity,
        text = text,
        key = key,
    }
    report[severity] = report[severity] + 1
end

function BuildValidation:New(owner)
    return setmetatable({ owner = owner }, { __index = self })
end

function BuildValidation:CountActiveSets(setup, bar)
    local grouped = {}
    for _, slotKey in ipairs(Slots:GetActiveSlotKeys(bar)) do
        local requirement = setup.equipment and setup.equipment[slotKey]
        if requirement and not isOccupiedOffHand(setup, slotKey) then
            local name = requirement.setName or ""
            local setId = tonumber(requirement.setId) or 0
            if name == "" and setId > 0 and GetItemSetName then
                name = GetItemSetName(setId) or ""
            end
            if setId > 0 or name ~= "" then
                local key = setId > 0 and "id:" .. tostring(setId) or "name:" .. lower(name)
                local entry = grouped[key]
                if not entry then
                    entry = {
                        setId = setId,
                        name = name ~= "" and name
                            or GetString(SI_GRAVVY_BUILD_PLANNER_VALIDATION_UNKNOWN_SET),
                        pieces = 0,
                    }
                    grouped[key] = entry
                end
                entry.pieces = entry.pieces + pieceWeight(slotKey, requirement)
            end
        end
    end
    local counts = {}
    for _, entry in pairs(grouped) do
        counts[#counts + 1] = entry
    end
    table.sort(counts, function(left, right)
        if left.pieces == right.pieces then
            return lower(left.name) < lower(right.name)
        end
        return left.pieces > right.pieces
    end)
    return counts
end

function BuildValidation:FormatSetCounts(counts)
    if #counts == 0 then
        return GetString(SI_GRAVVY_BUILD_PLANNER_VALIDATION_NO_ACTIVE_SETS)
    end
    local labels = {}
    for _, entry in ipairs(counts) do
        labels[#labels + 1] = zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_VALIDATION_SET_COUNT,
            entry.name,
            entry.pieces
        )
    end
    return table.concat(labels, " · ")
end

function BuildValidation:ValidateEquipment(setup, report)
    local mythicSlots = {}
    local monsterSets = {}
    for _, slotKey in ipairs(Slots.ORDER) do
        local requirement = setup.equipment and setup.equipment[slotKey]
        local occupied = isOccupiedOffHand(setup, slotKey)
        if occupied and requirement then
            addIssue(report, "errors", zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_VALIDATION_OCCUPIED_OFFHAND,
                slotName(slotKey)
            ), "occupied:" .. slotKey)
        elseif not occupied and not requirement then
            addIssue(report, "warnings", zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_VALIDATION_EMPTY_SLOT,
                slotName(slotKey)
            ), "empty:" .. slotKey)
        elseif requirement then
            local missing = {}
            local definition = Slots:Get(slotKey)
            local hasIdentity = (tonumber(requirement.setId) or 0) > 0
                or (tonumber(requirement.itemId) or 0) > 0
                or (requirement.setName and requirement.setName ~= "")
                or (requirement.itemName and requirement.itemName ~= "")
            if not hasIdentity then
                missing[#missing + 1] = GetString(
                    SI_GRAVVY_BUILD_PLANNER_VALIDATION_DETAIL_ITEM
                )
            end
            if definition.family == "armor"
                and (not requirement.armorType or requirement.armorType == ARMORTYPE_NONE) then
                missing[#missing + 1] = GetString(
                    SI_GRAVVY_BUILD_PLANNER_VALIDATION_DETAIL_TYPE
                )
            elseif definition.family == "weapon"
                and (not requirement.weaponType or requirement.weaponType == WEAPONTYPE_NONE) then
                missing[#missing + 1] = GetString(
                    SI_GRAVVY_BUILD_PLANNER_VALIDATION_DETAIL_TYPE
                )
            end
            if not requirement.traitType or requirement.traitType == ITEM_TRAIT_TYPE_NONE then
                missing[#missing + 1] = GetString(
                    SI_GRAVVY_BUILD_PLANNER_VALIDATION_DETAIL_TRAIT
                )
            end
            if not requirement.enchantmentCategory
                and not requirement.enchantmentId
                and (not requirement.enchantmentName or requirement.enchantmentName == "") then
                missing[#missing + 1] = GetString(
                    SI_GRAVVY_BUILD_PLANNER_VALIDATION_DETAIL_ENCHANTMENT
                )
            end
            if #missing > 0 then
                addIssue(report, "warnings", zo_strformat(
                    SI_GRAVVY_BUILD_PLANNER_VALIDATION_SLOT_DETAILS,
                    slotName(slotKey),
                    table.concat(missing, ", ")
                ), "details:" .. slotKey)
            end

            local setId = tonumber(requirement.setId) or 0
            local setType = setId > 0 and GetItemSetType and GetItemSetType(setId)
            if ITEM_SET_TYPE_MYTHIC and setType == ITEM_SET_TYPE_MYTHIC then
                mythicSlots[#mythicSlots + 1] = slotName(slotKey)
            elseif ITEM_SET_TYPE_MONSTER and setType == ITEM_SET_TYPE_MONSTER then
                local monster = monsterSets[setId]
                if not monster then
                    monster = {
                        name = requirement.setName or (GetItemSetName
                            and GetItemSetName(setId))
                            or GetString(SI_GRAVVY_BUILD_PLANNER_VALIDATION_UNKNOWN_SET),
                        pieces = 0,
                    }
                    monsterSets[setId] = monster
                end
                monster.pieces = monster.pieces + 1
            end
        end
    end
    if #mythicSlots > 1 then
        addIssue(report, "errors", zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_VALIDATION_MYTHICS,
            table.concat(mythicSlots, ", ")
        ), "mythics")
    end
    for setId, monster in pairs(monsterSets) do
        if monster.pieces == 1 then
            addIssue(report, "warnings", zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_VALIDATION_MONSTER_INCOMPLETE,
                monster.name
            ), "monster:" .. tostring(setId))
        elseif monster.pieces > 2 then
            addIssue(report, "errors", zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_VALIDATION_MONSTER_TOO_MANY,
                monster.name,
                monster.pieces
            ), "monster:" .. tostring(setId))
        end
    end
end

function BuildValidation:GetWeaponLine(entry)
    if not entry then
        return nil
    end
    if SKILL_TYPE_WEAPON and entry.skillType ~= SKILL_TYPE_WEAPON then
        return nil
    end
    return weaponLines[tonumber(entry.skillLineIndex)]
        or weaponLineNames[lower(entry.skillLine)]
end

function BuildValidation:WeaponLineMatches(setup, bar, line)
    local main = setup.equipment and setup.equipment[bar .. "Main"]
    local off = setup.equipment and setup.equipment[bar .. "Off"]
    local mainType = main and main.weaponType
    local offType = off and off.weaponType
    if not mainType or mainType == WEAPONTYPE_NONE then
        return nil
    end
    if line == "twoHanded" then
        return hasValue(mainType, WEAPONTYPE_TWO_HANDED_AXE,
            WEAPONTYPE_TWO_HANDED_HAMMER, WEAPONTYPE_TWO_HANDED_SWORD)
    elseif line == "oneHandShield" then
        local oneHanded = hasValue(mainType, WEAPONTYPE_AXE, WEAPONTYPE_HAMMER,
            WEAPONTYPE_SWORD, WEAPONTYPE_DAGGER)
        return oneHanded and offType == WEAPONTYPE_SHIELD
    elseif line == "dualWield" then
        local mainOneHanded = hasValue(mainType, WEAPONTYPE_AXE, WEAPONTYPE_HAMMER,
            WEAPONTYPE_SWORD, WEAPONTYPE_DAGGER)
        local offOneHanded = hasValue(offType, WEAPONTYPE_AXE, WEAPONTYPE_HAMMER,
            WEAPONTYPE_SWORD, WEAPONTYPE_DAGGER)
        return mainOneHanded and offOneHanded
    elseif line == "bow" then
        return mainType == WEAPONTYPE_BOW
    elseif line == "destructionStaff" then
        return hasValue(mainType, WEAPONTYPE_FIRE_STAFF, WEAPONTYPE_FROST_STAFF,
            WEAPONTYPE_LIGHTNING_STAFF)
    elseif line == "restorationStaff" then
        return mainType == WEAPONTYPE_HEALING_STAFF
    end
end

function BuildValidation:ValidateSkills(setup, report)
    for _, bar in ipairs({ "front", "back" }) do
        local reported = {}
        for _, skill in pairs(setup.skillBars and setup.skillBars[bar] or {}) do
            local entry = self.owner.skillCatalog:FindById(skill.abilityId)
            local line = self:GetWeaponLine(entry)
            if line and not reported[line] then
                local matches = self:WeaponLineMatches(setup, bar, line)
                if matches == false then
                    reported[line] = true
                    addIssue(report, "errors", zo_strformat(
                        SI_GRAVVY_BUILD_PLANNER_VALIDATION_WEAPON_SKILL,
                        entry.skillLine ~= "" and entry.skillLine or entry.name,
                        GetString(bar == "back"
                            and SI_GRAVVY_BUILD_PLANNER_BACK_BAR
                            or SI_GRAVVY_BUILD_PLANNER_FRONT_BAR)
                    ), "skill:" .. bar .. ":" .. line)
                end
            end
        end
    end
end

function BuildValidation:ValidateCharacter(setup, report)
    local attributes = setup.character and setup.character.attributes or {}
    local total = (tonumber(attributes.health) or 0)
        + (tonumber(attributes.magicka) or 0)
        + (tonumber(attributes.stamina) or 0)
    local expectsFullAttributes = (tonumber(setup.defaultLevel) or 50) >= 50
    if total == 0 and expectsFullAttributes then
        addIssue(report, "warnings", GetString(
            SI_GRAVVY_BUILD_PLANNER_VALIDATION_ATTRIBUTES_EMPTY
        ), "attributes")
    elseif expectsFullAttributes and total ~= 64 then
        addIssue(report, total > 64 and "errors" or "warnings", zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_VALIDATION_ATTRIBUTES_TOTAL,
            total
        ), "attributes")
    end
end

function BuildValidation:ValidateChampion(setup, report)
    local anyPlanned = false
    for _, disciplineKey in ipairs({ "craft", "warfare", "fitness" }) do
        local discipline = setup.champion and setup.champion[disciplineKey] or {}
        local allocations = {}
        for _, allocation in ipairs(discipline.allocations or {}) do
            anyPlanned = true
            if allocations[allocation.skillId] then
                addIssue(report, "errors", zo_strformat(
                    SI_GRAVVY_BUILD_PLANNER_VALIDATION_CHAMPION_DUPLICATE,
                    allocation.name or tostring(allocation.skillId)
                ), "cp:duplicate:" .. tostring(allocation.skillId))
            end
            allocations[allocation.skillId] = allocation
            local catalogEntry = self.owner.championCatalog:FindById(allocation.skillId)
            if catalogEntry and allocation.points > catalogEntry.maxPoints then
                addIssue(report, "errors", zo_strformat(
                    SI_GRAVVY_BUILD_PLANNER_VALIDATION_CHAMPION_POINTS,
                    catalogEntry.name,
                    allocation.points,
                    catalogEntry.maxPoints
                ), "cp:points:" .. tostring(allocation.skillId))
            end
        end
        local slotted = {}
        for _, skillId in ipairs(discipline.slottables or {}) do
            if skillId and skillId > 0 then
                anyPlanned = true
                local catalogEntry = self.owner.championCatalog:FindById(skillId)
                if slotted[skillId] then
                    addIssue(report, "warnings", zo_strformat(
                        SI_GRAVVY_BUILD_PLANNER_VALIDATION_CHAMPION_SLOTTED_TWICE,
                        catalogEntry and catalogEntry.name or tostring(skillId)
                    ), "cp:slotted:" .. tostring(skillId))
                elseif not allocations[skillId] or allocations[skillId].points < 1 then
                    addIssue(report, "errors", zo_strformat(
                        SI_GRAVVY_BUILD_PLANNER_VALIDATION_CHAMPION_UNFUNDED,
                        catalogEntry and catalogEntry.name or tostring(skillId)
                    ), "cp:unfunded:" .. tostring(skillId))
                elseif catalogEntry and not catalogEntry.isSlottable then
                    addIssue(report, "errors", zo_strformat(
                        SI_GRAVVY_BUILD_PLANNER_VALIDATION_CHAMPION_NOT_SLOTTABLE,
                        catalogEntry.name
                    ), "cp:not-slottable:" .. tostring(skillId))
                end
                slotted[skillId] = true
            end
        end
    end
    if not anyPlanned and (tonumber(setup.defaultChampionPoints) or 160) > 0 then
        addIssue(report, "warnings", GetString(
            SI_GRAVVY_BUILD_PLANNER_VALIDATION_CHAMPION_EMPTY
        ), "champion")
    end
end

function BuildValidation:BuildReport(setup)
    local report = {
        setup = setup,
        issues = {},
        errors = 0,
        warnings = 0,
        sets = {
            front = self:CountActiveSets(setup, "front"),
            back = self:CountActiveSets(setup, "back"),
        },
    }
    self:ValidateEquipment(setup, report)
    self:ValidateSkills(setup, report)
    self:ValidateCharacter(setup, report)
    self:ValidateChampion(setup, report)
    return report
end

function BuildValidation:FormatReport(report, issueLimit)
    local lines = {
        zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_VALIDATION_SUMMARY,
            report.errors,
            report.warnings
        ),
        "",
        GetString(SI_GRAVVY_BUILD_PLANNER_FRONT_BAR) .. ": "
            .. self:FormatSetCounts(report.sets.front),
        GetString(SI_GRAVVY_BUILD_PLANNER_BACK_BAR) .. ": "
            .. self:FormatSetCounts(report.sets.back),
        "",
    }
    if #report.issues == 0 then
        lines[#lines + 1] = GetString(SI_GRAVVY_BUILD_PLANNER_VALIDATION_CLEAN)
    else
        local maximum = math.min(#report.issues, issueLimit or #report.issues)
        for index = 1, maximum do
            local issue = report.issues[index]
            lines[#lines + 1] = GetString(issue.severity == "errors"
                and SI_GRAVVY_BUILD_PLANNER_VALIDATION_ERROR
                or SI_GRAVVY_BUILD_PLANNER_VALIDATION_WARNING)
                .. ": " .. issue.text
        end
        if maximum < #report.issues then
            lines[#lines + 1] = zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_VALIDATION_MORE,
                #report.issues - maximum
            )
        end
    end
    return table.concat(lines, "\n")
end
