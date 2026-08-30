GravvyBuildPlannerStatImpact = {}

local StatImpact = GravvyBuildPlannerStatImpact
local Slots = GravvyBuildPlannerSlots

local statRows = {
    { key = "maxMagicka", constant = "STAT_MAGICKA_MAX", label = SI_GRAVVY_BUILD_PLANNER_STAT_MAX_MAGICKA },
    { key = "magickaRecovery", constant = "STAT_MAGICKA_REGEN_COMBAT", label = SI_GRAVVY_BUILD_PLANNER_STAT_MAGICKA_RECOVERY },
    { key = "maxHealth", constant = "STAT_HEALTH_MAX", label = SI_GRAVVY_BUILD_PLANNER_STAT_MAX_HEALTH },
    { key = "healthRecovery", constant = "STAT_HEALTH_REGEN_COMBAT", label = SI_GRAVVY_BUILD_PLANNER_STAT_HEALTH_RECOVERY },
    { key = "maxStamina", constant = "STAT_STAMINA_MAX", label = SI_GRAVVY_BUILD_PLANNER_STAT_MAX_STAMINA },
    { key = "staminaRecovery", constant = "STAT_STAMINA_REGEN_COMBAT", label = SI_GRAVVY_BUILD_PLANNER_STAT_STAMINA_RECOVERY },
    { key = "spellDamage", constant = "STAT_SPELL_POWER", label = SI_GRAVVY_BUILD_PLANNER_STAT_SPELL_DAMAGE },
    { key = "spellCritical", constant = "STAT_SPELL_CRITICAL", label = SI_GRAVVY_BUILD_PLANNER_STAT_SPELL_CRITICAL, critical = true },
    { key = "spellPenetration", constant = "STAT_SPELL_PENETRATION", label = SI_GRAVVY_BUILD_PLANNER_STAT_SPELL_PENETRATION },
    { key = "weaponDamage", constant = "STAT_POWER", label = SI_GRAVVY_BUILD_PLANNER_STAT_WEAPON_DAMAGE },
    { key = "weaponCritical", constant = "STAT_CRITICAL_STRIKE", label = SI_GRAVVY_BUILD_PLANNER_STAT_WEAPON_CRITICAL, critical = true },
    { key = "physicalPenetration", constant = "STAT_PHYSICAL_PENETRATION", label = SI_GRAVVY_BUILD_PLANNER_STAT_PHYSICAL_PENETRATION },
    { key = "spellResistance", constant = "STAT_SPELL_RESIST", label = SI_GRAVVY_BUILD_PLANNER_STAT_SPELL_RESISTANCE },
    { key = "physicalResistance", constant = "STAT_PHYSICAL_RESIST", label = SI_GRAVVY_BUILD_PLANNER_STAT_PHYSICAL_RESISTANCE },
    { key = "criticalResistance", constant = "STAT_CRITICAL_RESISTANCE", label = SI_GRAVVY_BUILD_PLANNER_STAT_CRITICAL_RESISTANCE },
}

local function round(value)
    value = tonumber(value) or 0
    return value < 0 and math.ceil(value - 0.5) or math.floor(value + 0.5)
end

local function lower(value)
    value = tostring(value or "")
    return zo_strlower and zo_strlower(value) or string.lower(value)
end

local function captureMundus()
    if not GetUnitActiveMundusStoneBuffIndices
        or not GetUnitBuffInfo
        or not GetAbilityMundusStoneType then
        return 0
    end
    local indices = { GetUnitActiveMundusStoneBuffIndices("player") }
    for _, buffIndex in ipairs(indices) do
        local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo(
            "player",
            buffIndex
        )
        local mundus = abilityId and GetAbilityMundusStoneType(abilityId)
        if mundus and mundus ~= MUNDUS_STONE_INVALID then
            return mundus
        end
    end
    return 0
end

local function plannedFoodNames(setup)
    local names = {}
    for _, entry in ipairs(setup and setup.consumables or {}) do
        if entry.category == "food" or entry.category == "drink" then
            if entry.name and entry.name ~= "" then
                names[lower(entry.name)] = true
            end
            if entry.itemLink and entry.itemLink ~= "" and GetItemLinkOnUseAbilityInfo then
                local hasAbility, abilityName = GetItemLinkOnUseAbilityInfo(entry.itemLink)
                if hasAbility and abilityName and abilityName ~= "" then
                    names[lower(abilityName)] = true
                end
            end
        end
    end
    return names
end

local function captureFood(setup)
    if not GetNumBuffs or not GetUnitBuffInfo then
        return "", 0
    end
    local plannedNames = plannedFoodNames(setup)
    local iconCandidate
    for buffIndex = 1, GetNumBuffs("player") do
        local name, _, _, _, _, icon, _, _, _, _, abilityId = GetUnitBuffInfo(
            "player",
            buffIndex
        )
        if name and name ~= "" then
            if plannedNames[lower(name)] then
                return name, tonumber(abilityId) or 0
            end
            if lower(icon):find("icon_potion_full", 1, true) then
                iconCandidate = iconCandidate or {
                    name = name,
                    abilityId = tonumber(abilityId) or 0,
                }
            end
        end
    end
    return iconCandidate and iconCandidate.name or "",
        iconCandidate and iconCandidate.abilityId or 0
end

local function itemLinkForRequirement(owner, slotKey, requirement, setup)
    local resolved = owner.itemResolver:Resolve(slotKey, requirement, setup)
    if resolved and resolved.itemLink and resolved.itemLink ~= "" then
        local traitMatches = not requirement.traitType
            or requirement.traitType == ITEM_TRAIT_TYPE_NONE
            or not GetItemLinkTraitInfo
            or GetItemLinkTraitInfo(resolved.itemLink) == requirement.traitType
        return resolved.itemLink, resolved.enchantmentMatches ~= false, traitMatches
    end
    if requirement.itemLink and requirement.itemLink ~= "" then
        local enchantmentMatches = true
        if requirement.enchantmentCategory then
            local _, category = owner.itemResolver:GetEnchantInfo(requirement.itemLink)
            enchantmentMatches = category == requirement.enchantmentCategory
        end
        local traitMatches = not requirement.traitType
            or requirement.traitType == ITEM_TRAIT_TYPE_NONE
            or not GetItemLinkTraitInfo
            or GetItemLinkTraitInfo(requirement.itemLink) == requirement.traitType
        return requirement.itemLink, enchantmentMatches, traitMatches
    end
end

local function pieceWeight(slotKey, requirement, itemLink)
    if slotKey ~= "frontMain" and slotKey ~= "backMain" then
        return 1
    end
    if requirement and (requirement.occupiesOffHand
        or Slots:IsTwoHanded(requirement.weaponType)) then
        return 2
    end
    if itemLink and GetItemLinkWeaponType
        and Slots:IsTwoHanded(GetItemLinkWeaponType(itemLink)) then
        return 2
    end
    return 1
end

local function addGroupedEffect(groups, order, key, label, description)
    if not description or description == "" then
        return
    end
    local group = groups[key]
    if group then
        group.count = group.count + 1
        return
    end
    group = {
        label = label,
        description = description,
        count = 1,
    }
    groups[key] = group
    order[#order + 1] = group
end

function StatImpact:New(owner)
    return setmetatable({ owner = owner }, { __index = self })
end

function StatImpact:GetStatRows()
    return statRows
end

function StatImpact:GetLiveStats()
    local values = {}
    if not GetPlayerStat then
        return values
    end
    local bonusOption = STAT_BONUS_OPTION_APPLY_BONUS or 1
    for _, row in ipairs(statRows) do
        local statType = _G[row.constant]
        if statType ~= nil then
            local value = GetPlayerStat(statType, bonusOption)
            if type(value) == "number" then
                values[row.key] = value
            end
        end
    end
    return values
end

function StatImpact:GetLiveBar()
    if not GetActiveWeaponPairInfo then
        return nil
    end
    local weaponPair = GetActiveWeaponPairInfo()
    if weaponPair == ACTIVE_WEAPON_PAIR_MAIN then
        return "front"
    elseif weaponPair == ACTIVE_WEAPON_PAIR_BACKUP then
        return "back"
    end
end

function StatImpact:GetEquippedCoverage(setup, bar)
    local coverage = { planned = 0, ready = 0, adjustable = 0, missing = 0 }
    for _, slotKey in ipairs(Slots:GetActiveSlotKeys(bar)) do
        local requirement = setup.equipment and setup.equipment[slotKey]
        local mainHand = Slots:GetMainHand(slotKey)
        local occupied = mainHand and setup.equipment and setup.equipment[mainHand]
        if requirement and not (occupied and (occupied.occupiesOffHand
            or Slots:IsTwoHanded(occupied.weaponType))) then
            coverage.planned = coverage.planned + 1
            local definition = Slots:Get(slotKey)
            local itemLink = definition and GetItemLink and GetItemLink(
                BAG_WORN,
                definition.equipSlot,
                LINK_STYLE_DEFAULT
            )
            local bestMatch
            if itemLink and itemLink ~= "" then
                local candidates = { requirement }
                for _, alternative in ipairs(
                    (setup.alternatives and setup.alternatives[slotKey]) or {}
                ) do
                    candidates[#candidates + 1] = alternative
                end
                for _, candidate in ipairs(candidates) do
                    local match = self.owner.acquisition:CompareItem(
                        slotKey,
                        candidate,
                        setup,
                        itemLink
                    )
                    if match and (not bestMatch or match.exact) then
                        bestMatch = match
                    end
                    if bestMatch and bestMatch.exact then
                        break
                    end
                end
            end
            if bestMatch and bestMatch.exact then
                coverage.ready = coverage.ready + 1
            elseif bestMatch then
                coverage.adjustable = coverage.adjustable + 1
            else
                coverage.missing = coverage.missing + 1
            end
        end
    end
    return coverage
end

function StatImpact:MakeSnapshot(setup, bar, coverage)
    local characterName = ""
    if GetRawUnitName then
        characterName = GetRawUnitName("player") or ""
    elseif GetUnitName then
        characterName = GetUnitName("player") or ""
    end
    local foodName, foodAbilityId = captureFood(setup)
    local inCombat = IsUnitInCombat and IsUnitInCombat("player")
    if inCombat == nil and IsPlayerInCombat then
        inCombat = IsPlayerInCombat()
    end
    return {
        characterName = characterName,
        createdAt = GetTimeStamp and GetTimeStamp() or 0,
        captureTime = GetTimeString and GetTimeString() or "",
        foodName = foodName,
        foodAbilityId = foodAbilityId,
        mundus = captureMundus(),
        inCombat = inCombat == true,
        equippedCoverage = coverage or self:GetEquippedCoverage(setup, bar),
        values = self:GetLiveStats(),
    }
end

function StatImpact:FormatValue(row, value)
    if type(value) ~= "number" then
        return "—"
    end
    if row.critical and GetCriticalStrikeChance then
        return string.format("%.1f%%", GetCriticalStrikeChance(value))
    end
    return ZO_CommaDelimitNumber and ZO_CommaDelimitNumber(round(value))
        or tostring(round(value))
end

function StatImpact:FormatChange(row, liveValue, snapshotValue)
    if type(liveValue) ~= "number" or type(snapshotValue) ~= "number" then
        return "—"
    end
    local difference = snapshotValue - liveValue
    if row.critical and GetCriticalStrikeChance then
        local chance = GetCriticalStrikeChance(math.abs(difference))
        if difference == 0 then
            return string.format("%.1f%%", chance)
        end
        return string.format("%+.1f%%", difference < 0 and -chance or chance)
    end
    local value = round(difference)
    local formatted = ZO_CommaDelimitNumber and ZO_CommaDelimitNumber(math.abs(value))
        or tostring(math.abs(value))
    return (value > 0 and "+" or value < 0 and "-" or "") .. formatted
end

function StatImpact:GetPlannedLinks(setup, bar)
    local links = {}
    local planned = 0
    local resolved = 0
    for _, slotKey in ipairs(Slots:GetActiveSlotKeys(bar)) do
        local requirement = setup.equipment and setup.equipment[slotKey]
        local mainHand = Slots:GetMainHand(slotKey)
        local occupied = mainHand and setup.equipment and setup.equipment[mainHand]
        if requirement and not (occupied and (occupied.occupiesOffHand
            or Slots:IsTwoHanded(occupied.weaponType))) then
            planned = planned + 1
            local itemLink, enchantmentMatches, traitMatches = itemLinkForRequirement(
                self.owner,
                slotKey,
                requirement,
                setup
            )
            if itemLink and itemLink ~= "" then
                resolved = resolved + 1
                links[#links + 1] = {
                    slotKey = slotKey,
                    itemLink = itemLink,
                    weight = pieceWeight(slotKey, requirement, itemLink),
                    showEnchantment = requirement.enchantmentCategory ~= nil
                        and enchantmentMatches,
                    showTrait = requirement.traitType ~= nil
                        and requirement.traitType ~= ITEM_TRAIT_TYPE_NONE
                        and traitMatches,
                }
            end
        end
    end
    return links, resolved, planned
end

function StatImpact:GetEquippedLinks(bar)
    local links = {}
    if not GetItemLink then
        return links
    end
    for _, slotKey in ipairs(Slots:GetActiveSlotKeys(bar)) do
        local definition = Slots:Get(slotKey)
        local itemLink = definition and GetItemLink(
            BAG_WORN,
            definition.equipSlot,
            LINK_STYLE_DEFAULT
        )
        if itemLink and itemLink ~= "" then
            links[#links + 1] = {
                slotKey = slotKey,
                itemLink = itemLink,
                weight = pieceWeight(slotKey, nil, itemLink),
            }
        end
    end
    return links
end

function StatImpact:GetEquipmentValues(links)
    local armor = 0
    local weaponPower = 0
    local hasArmor = GetItemLinkArmorRating ~= nil
    local hasWeaponPower = GetItemLinkWeaponPower ~= nil
    for _, entry in ipairs(links) do
        local definition = Slots:Get(entry.slotKey)
        if hasArmor and definition then
            armor = armor + (tonumber(GetItemLinkArmorRating(entry.itemLink, false)) or 0)
        end
        if hasWeaponPower and definition and definition.family == "weapon" then
            weaponPower = weaponPower + (tonumber(GetItemLinkWeaponPower(entry.itemLink)) or 0)
        end
    end
    return {
        armor = hasArmor and armor or nil,
        weaponPower = hasWeaponPower and weaponPower or nil,
    }
end

function StatImpact:BuildEffects(setup, bar, plannedLinks)
    local effects = {}
    local currentValues = self:GetEquipmentValues(self:GetEquippedLinks(bar))
    local plannedValues = self:GetEquipmentValues(plannedLinks)

    local function addEquipmentValue(labelId, current, planned)
        if current == nil or planned == nil then
            return
        end
        local difference = round(planned - current)
        local change = (difference > 0 and "+" or "") .. tostring(difference)
        effects[#effects + 1] = {
            label = GetString(labelId),
            description = zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_EQUIPMENT_VALUE,
                round(current),
                round(planned),
                change
            ),
        }
    end

    addEquipmentValue(
        SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_ARMOR_RATING,
        currentValues.armor,
        plannedValues.armor
    )
    addEquipmentValue(
        SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_WEAPON_POWER,
        currentValues.weaponPower,
        plannedValues.weaponPower
    )

    local sets = {}
    for _, entry in ipairs(plannedLinks) do
        if GetItemLinkSetInfo then
            local hasSet, setName, numBonuses, _, _, setId = GetItemLinkSetInfo(entry.itemLink, false)
            if hasSet then
                local key = (setId and setId ~= 0) and tostring(setId) or tostring(setName)
                local set = sets[key]
                if not set then
                    set = {
                        name = setName,
                        itemLink = entry.itemLink,
                        pieces = 0,
                        numBonuses = tonumber(numBonuses) or 0,
                    }
                    sets[key] = set
                end
                set.pieces = set.pieces + (entry.weight or 1)
            end
        end
    end
    local orderedSets = {}
    for _, set in pairs(sets) do
        orderedSets[#orderedSets + 1] = set
    end
    table.sort(orderedSets, function(left, right)
        return tostring(left.name) < tostring(right.name)
    end)
    if GetItemLinkSetBonusInfo then
        for _, set in ipairs(orderedSets) do
            local maximum = set.numBonuses > 0 and set.numBonuses or 12
            for index = 1, maximum do
                local required, description = GetItemLinkSetBonusInfo(set.itemLink, false, index)
                required = tonumber(required)
                if not required or required < 1 or not description or description == "" then
                    if set.numBonuses == 0 then
                        break
                    end
                elseif required <= set.pieces then
                    effects[#effects + 1] = {
                        label = zo_strformat(
                            SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_SET_BONUS,
                            set.name,
                            required
                        ),
                        description = description,
                    }
                end
            end
        end
    end

    local groups = {}
    local groupOrder = {}
    for _, entry in ipairs(plannedLinks) do
        if entry.showEnchantment and GetItemLinkEnchantInfo then
            local _, header, description = GetItemLinkEnchantInfo(entry.itemLink)
            if header and header ~= "" and description and description ~= "" then
                addGroupedEffect(
                    groups,
                    groupOrder,
                    "enchant:" .. header .. ":" .. description,
                    header,
                    description
                )
            end
        end
        if entry.showTrait and GetItemLinkTraitInfo then
            local traitType, description = GetItemLinkTraitInfo(entry.itemLink)
            if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE
                and description and description ~= "" then
                addGroupedEffect(
                    groups,
                    groupOrder,
                    "trait:" .. tostring(traitType) .. ":" .. description,
                    GetString("SI_ITEMTRAITTYPE", traitType),
                    description
                )
            end
        end
    end
    table.sort(groupOrder, function(left, right)
        return tostring(left.label) < tostring(right.label)
    end)
    for _, group in ipairs(groupOrder) do
        if group.count > 1 then
            group.label = zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_EFFECT_COUNT,
                group.label,
                group.count
            )
        end
        effects[#effects + 1] = group
    end
    return effects
end

function StatImpact:BuildReport(setup, bar)
    bar = bar == "back" and "back" or "front"
    local plannedLinks, resolved, planned = self:GetPlannedLinks(setup, bar)
    local equippedCoverage = self:GetEquippedCoverage(setup, bar)
    return {
        live = self:GetLiveStats(),
        snapshot = setup.statSnapshots and setup.statSnapshots[bar],
        effects = self:BuildEffects(setup, bar, plannedLinks),
        resolved = resolved,
        planned = planned,
        equippedCoverage = equippedCoverage,
        bar = bar,
        liveBar = self:GetLiveBar(),
        snapshotStale = self.owner.data:IsStatSnapshotStale(setup, bar),
    }
end

function StatImpact:GetCaptureStatus(setup, bar)
    local snapshot = setup.statSnapshots and setup.statSnapshots[bar]
    if not snapshot then
        return "missing", SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_NOT_CAPTURED_SHORT
    end
    if self.owner.data:IsStatSnapshotStale(setup, bar) then
        return "stale", SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_STALE_SHORT
    end
    return "current", SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CURRENT
end

function StatImpact:GetNextCaptureBar(setup, capturedBar)
    local otherBar = capturedBar == "front" and "back" or "front"
    local otherStatus = self:GetCaptureStatus(setup, otherBar)
    if otherStatus ~= "current" then
        return otherBar
    end
    local currentStatus = self:GetCaptureStatus(setup, capturedBar)
    return currentStatus ~= "current" and capturedBar or nil
end

function StatImpact:FormatCaptureProgress(setup)
    local _, frontStatusId = self:GetCaptureStatus(setup, "front")
    local _, backStatusId = self:GetCaptureStatus(setup, "back")
    local text = zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CAPTURE_PROGRESS,
        GetString(frontStatusId),
        GetString(backStatusId)
    )
    local nextBar = self:GetNextCaptureBar(setup, "back")
    if nextBar then
        text = text .. "\n" .. zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CAPTURE_NEXT,
            GetString(nextBar == "back"
                and SI_GRAVVY_BUILD_PLANNER_BACK_BAR
                or SI_GRAVVY_BUILD_PLANNER_FRONT_BAR)
        )
    else
        text = text .. "\n" .. GetString(
            SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CAPTURE_COMPLETE
        )
    end
    return text
end

function StatImpact:FormatCaptureConfirmation(setup, bar, coverage)
    coverage = coverage or self:GetEquippedCoverage(setup, bar)
    return zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CONFIRM_CAPTURE,
        setup.name,
        GetString(bar == "back"
            and SI_GRAVVY_BUILD_PLANNER_BACK_BAR
            or SI_GRAVVY_BUILD_PLANNER_FRONT_BAR),
        coverage.ready,
        coverage.adjustable,
        coverage.missing
    )
end

function StatImpact:FormatSnapshotDetails(snapshot, bar, stale)
    if not snapshot then
        return GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_NOT_CAPTURED)
    end
    local characterName = snapshot.characterName ~= ""
        and snapshot.characterName
        or GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_UNKNOWN_CHARACTER)
    local capturedAt = GetDateStringFromTimestamp
        and GetDateStringFromTimestamp(snapshot.createdAt)
        or tostring(snapshot.createdAt or "")
    if snapshot.captureTime and snapshot.captureTime ~= "" then
        capturedAt = capturedAt .. " " .. snapshot.captureTime
    end
    local details = zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_SNAPSHOT_DETAILS,
        characterName,
        capturedAt,
        GetString(bar == "back"
            and SI_GRAVVY_BUILD_PLANNER_BACK_BAR
            or SI_GRAVVY_BUILD_PLANNER_FRONT_BAR),
        GetString(stale
            and SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_STALE
            or SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CURRENT)
    )
    local food = snapshot.foodName and snapshot.foodName ~= ""
        and snapshot.foodName
        or GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_NO_FOOD)
    local mundus = snapshot.mundus and snapshot.mundus > 0
        and GetString("SI_MUNDUSSTONE", snapshot.mundus)
        or GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_NO_MUNDUS)
    return details .. "\n" .. zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CONTEXT,
        food,
        mundus,
        GetString(snapshot.inCombat
            and SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_IN_COMBAT
            or SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_OUT_OF_COMBAT)
    )
end
