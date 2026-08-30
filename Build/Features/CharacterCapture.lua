GravvyBuildPlannerCharacterCapture = {}

local Capture = GravvyBuildPlannerCharacterCapture
local Slots = GravvyBuildPlannerSlots

local function wholeNumber(value, fallback)
    value = tonumber(value)
    if not value or value < 0 then
        return fallback or 0
    end
    return math.floor(value)
end

local function itemName(itemLink)
    local name = GetItemLinkName and GetItemLinkName(itemLink) or ""
    if name ~= "" and SI_TOOLTIP_ITEM_NAME then
        name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
    end
    return name
end

local function itemRequirement(owner, slotKey, itemLink)
    local definition = Slots:Get(slotKey)
    local requirement = {
        itemLink = itemLink,
        itemId = wholeNumber(GetItemLinkItemId and GetItemLinkItemId(itemLink), 0),
        itemName = itemName(itemLink),
        quality = wholeNumber(GetItemLinkDisplayQuality
            and GetItemLinkDisplayQuality(itemLink), ITEM_QUALITY_NORMAL or 1),
        level = wholeNumber(GetItemLinkRequiredLevel
            and GetItemLinkRequiredLevel(itemLink), 1),
        championPoints = wholeNumber(GetItemLinkRequiredChampionPoints
            and GetItemLinkRequiredChampionPoints(itemLink), 0),
    }

    if GetItemLinkSetInfo then
        local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)
        if hasSet and setId and setId > 0 then
            requirement.setId = setId
            requirement.setName = setName or ""
        end
    end

    if definition.family == "armor" and GetItemLinkArmorType then
        local armorType = GetItemLinkArmorType(itemLink)
        if armorType and armorType ~= (ARMORTYPE_NONE or 0) then
            requirement.armorType = armorType
        end
    elseif definition.family == "weapon" and GetItemLinkWeaponType then
        local weaponType = GetItemLinkWeaponType(itemLink)
        if weaponType and weaponType ~= (WEAPONTYPE_NONE or 0) then
            requirement.weaponType = weaponType
        end
    end

    if GetItemLinkTraitInfo then
        requirement.traitType = wholeNumber(GetItemLinkTraitInfo(itemLink), 0)
    end

    local enchantId, enchantmentCategory
    if owner.itemResolver then
        enchantId, enchantmentCategory = owner.itemResolver:GetEnchantInfo(itemLink)
    elseif GetItemLinkFinalEnchantId and GetEnchantSearchCategoryType then
        enchantId = GetItemLinkFinalEnchantId(itemLink)
        enchantmentCategory = enchantId and GetEnchantSearchCategoryType(enchantId)
    end
    if enchantId and enchantId > 0 then
        requirement.enchantmentId = enchantId
    end
    if enchantmentCategory and enchantmentCategory > 0 then
        requirement.enchantmentCategory = enchantmentCategory
        requirement.enchantmentName = GravvyBuildPlannerEnchantments:GetName(
            enchantmentCategory
        ) or ""
    end
    return requirement
end

local function captureEquipment(owner, report)
    local equipment = {}
    local occupied = {}
    if not GetItemLink or not BAG_WORN then
        return equipment
    end

    for _, slotKey in ipairs(Slots.ORDER) do
        if not occupied[slotKey] then
            local definition = Slots:Get(slotKey)
            local itemLink = GetItemLink(BAG_WORN, definition.equipSlot, LINK_STYLE_DEFAULT)
            if itemLink and itemLink ~= "" then
                local requirement = itemRequirement(owner, slotKey, itemLink)
                equipment[slotKey] = requirement
                report.gear = report.gear + 1
                local offHand = Slots:GetOccupiedOffHand(slotKey, requirement.weaponType)
                if offHand then
                    occupied[offHand] = true
                end
            end
        end
    end
    return equipment
end

local function getAbilityBarRange()
    if GetAssignableAbilityBarStartAndEndSlots then
        return GetAssignableAbilityBarStartAndEndSlots()
    end
    return ACTION_BAR_FIRST_NORMAL_SLOT_INDEX or 3,
        (ACTION_BAR_ULTIMATE_SLOT_INDEX and ACTION_BAR_ULTIMATE_SLOT_INDEX + 1) or 8
end

local function abilityForSlot(actionSlotIndex, hotbarCategory)
    if not GetSlotBoundId then
        return nil
    end
    local actionType = GetSlotType and GetSlotType(actionSlotIndex, hotbarCategory)
    local abilityId = GetSlotBoundId(actionSlotIndex, hotbarCategory)
    if not abilityId or abilityId <= 0 then
        return nil
    end

    if ACTION_TYPE_CRAFTED_ABILITY and actionType == ACTION_TYPE_CRAFTED_ABILITY then
        if GetCraftedAbilityRepresentativeAbilityId then
            abilityId = GetCraftedAbilityRepresentativeAbilityId(abilityId)
        elseif GetAbilityIdForCraftedAbilityId then
            abilityId = GetAbilityIdForCraftedAbilityId(abilityId)
        end
    elseif actionType and ACTION_TYPE_ABILITY and actionType ~= ACTION_TYPE_ABILITY then
        return nil
    end

    if not abilityId or abilityId <= 0 then
        return nil
    end
    local name = GetAbilityName and GetAbilityName(abilityId) or ""
    if name == "" and GetSlotName then
        name = GetSlotName(actionSlotIndex, hotbarCategory) or ""
    end
    if name == "" then
        return nil
    end
    local icon = GetAbilityIcon and GetAbilityIcon(abilityId) or ""
    if icon == "" and GetSlotTexture then
        icon = GetSlotTexture(actionSlotIndex, hotbarCategory) or ""
    end
    return abilityId, name, icon
end

local function captureSkillBars(report)
    local bars = { front = {}, back = {} }
    local firstSlot, lastSlot = getAbilityBarRange()
    if not firstSlot or not lastSlot then
        return bars
    end

    for _, entry in ipairs({
        { key = "front", category = HOTBAR_CATEGORY_PRIMARY },
        { key = "back", category = HOTBAR_CATEGORY_BACKUP },
    }) do
        if entry.category then
            for actionSlotIndex = firstSlot, math.min(lastSlot, firstSlot + 5) do
                local abilityId, name, icon = abilityForSlot(
                    actionSlotIndex,
                    entry.category
                )
                if abilityId then
                    local slotIndex = actionSlotIndex - firstSlot + 1
                    bars[entry.key][slotIndex] = {
                        abilityId = abilityId,
                        name = name,
                        icon = icon,
                        isUltimate = slotIndex == 6,
                    }
                    report.skills = report.skills + 1
                end
            end
        end
    end
    return bars
end

local function captureMundus()
    if not GetUnitActiveMundusStoneBuffIndices
        or not GetUnitBuffInfo
        or not GetAbilityMundusStoneType then
        return 0
    end
    local buffIndex = GetUnitActiveMundusStoneBuffIndices("player")
    if not buffIndex then
        return 0
    end
    local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo(
        "player",
        buffIndex
    )
    local mundus = abilityId and GetAbilityMundusStoneType(abilityId)
    if mundus == MUNDUS_STONE_INVALID then
        return 0
    end
    return wholeNumber(mundus, 0)
end

local function captureCurse()
    local curse = GetPlayerCurseType and GetPlayerCurseType() or 0
    if CURSE_TYPE_VAMPIRE and curse == CURSE_TYPE_VAMPIRE then
        return 1
    elseif CURSE_TYPE_WEREWOLF and curse == CURSE_TYPE_WEREWOLF then
        return 2
    end
    return 0
end

local function captureClassLines()
    local lines = { "", "", "" }
    if not SKILLS_DATA_MANAGER or not SKILLS_DATA_MANAGER.SkillTypeIterator then
        return lines
    end
    local index = 1
    for _, skillType in SKILLS_DATA_MANAGER:SkillTypeIterator() do
        for _, skillLine in skillType:SkillLineIterator() do
            local isClassLine = skillLine.IsClassSkillLine
                and skillLine:IsClassSkillLine()
            local isActive = skillLine.IsActive and skillLine:IsActive()
            local isMastery = skillLine.IsClassMastery
                and skillLine:IsClassMastery()
            if isClassLine and isActive and not isMastery then
                lines[index] = skillLine:GetName() or ""
                index = index + 1
                if index > 3 then
                    return lines
                end
            end
        end
    end
    return lines
end

local function captureCharacter()
    return {
        attributes = {
            health = wholeNumber(GetAttributeSpentPoints
                and GetAttributeSpentPoints(ATTRIBUTE_HEALTH), 0),
            magicka = wholeNumber(GetAttributeSpentPoints
                and GetAttributeSpentPoints(ATTRIBUTE_MAGICKA), 0),
            stamina = wholeNumber(GetAttributeSpentPoints
                and GetAttributeSpentPoints(ATTRIBUTE_STAMINA), 0),
        },
        raceId = wholeNumber(GetUnitRaceId and GetUnitRaceId("player"), 0),
        mundus = captureMundus(),
        curse = captureCurse(),
        subclassLines = captureClassLines(),
    }
end

local function disciplineKey(disciplineType)
    if disciplineType == CHAMPION_DISCIPLINE_TYPE_WORLD then
        return "craft"
    elseif disciplineType == CHAMPION_DISCIPLINE_TYPE_COMBAT then
        return "warfare"
    elseif disciplineType == CHAMPION_DISCIPLINE_TYPE_CONDITIONING then
        return "fitness"
    end
end

local function captureChampion(owner, report)
    local plan = {
        craft = { allocations = {}, slottables = { 0, 0, 0, 0 } },
        warfare = { allocations = {}, slottables = { 0, 0, 0, 0 } },
        fitness = { allocations = {}, slottables = { 0, 0, 0, 0 } },
    }
    local allocationsById = {}
    for _, entry in ipairs(owner.championCatalog and owner.championCatalog.entries or {}) do
        local skillData = entry.skillData
        local points = skillData and skillData.GetNumSavedPoints
            and wholeNumber(skillData:GetNumSavedPoints(), 0)
            or 0
        local discipline = plan[entry.discipline]
        if points > 0 and discipline then
            local allocation = {
                skillId = entry.skillId,
                name = entry.name,
                icon = entry.icon or "",
                points = math.min(points, entry.maxPoints or points),
                isSlottable = entry.isSlottable == true,
            }
            discipline.allocations[#discipline.allocations + 1] = allocation
            allocationsById[entry.skillId] = allocation
            report.champion = report.champion + 1
        end
    end

    if not GetAssignableChampionBarStartAndEndSlots
        or not GetRequiredChampionDisciplineIdForSlot
        or not GetChampionDisciplineType
        or not GetSlotBoundId then
        return plan
    end
    local nextSlot = { craft = 1, warfare = 1, fitness = 1 }
    local firstSlot, lastSlot = GetAssignableChampionBarStartAndEndSlots()
    for actionSlotIndex = firstSlot, lastSlot do
        local disciplineId = GetRequiredChampionDisciplineIdForSlot(
            actionSlotIndex,
            HOTBAR_CATEGORY_CHAMPION
        )
        local key = disciplineKey(GetChampionDisciplineType(disciplineId))
        local slotIndex = key and nextSlot[key]
        if slotIndex and slotIndex <= 4 then
            local actionType = GetSlotType
                and GetSlotType(actionSlotIndex, HOTBAR_CATEGORY_CHAMPION)
            local skillId = GetSlotBoundId(actionSlotIndex, HOTBAR_CATEGORY_CHAMPION)
            local allocation = allocationsById[skillId]
            if allocation and allocation.isSlottable
                and (not ACTION_TYPE_CHAMPION_SKILL
                    or not actionType
                    or actionType == ACTION_TYPE_CHAMPION_SKILL) then
                plan[key].slottables[slotIndex] = skillId
            end
            nextSlot[key] = slotIndex + 1
        end
    end
    return plan
end

function Capture:New(owner)
    return setmetatable({ owner = owner }, { __index = self })
end

function Capture:BuildSnapshot()
    if not GetItemLink and not GetSlotBoundId and not GetAttributeSpentPoints then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_CAPTURE_UNAVAILABLE)
    end

    local report = { gear = 0, skills = 0, champion = 0 }
    local characterName = GetRawUnitName and GetRawUnitName("player") or ""
    if characterName == "" then
        characterName = GetString(SI_GRAVVY_BUILD_PLANNER_CHARACTER)
    end
    local defaultLevel = GetMaxLevel and GetMaxLevel() or 50
    local defaultChampionPoints = GetChampionPointsPlayerProgressionCap
        and GetChampionPointsPlayerProgressionCap()
        or 160
    local source = {
        name = zo_strformat(SI_GRAVVY_BUILD_PLANNER_CAPTURE_BUILD_NAME, characterName),
        classId = wholeNumber(GetUnitClassId and GetUnitClassId("player"), 0),
        role = "",
        patch = "",
        author = "",
        sourceUrl = "",
        notes = GetString(SI_GRAVVY_BUILD_PLANNER_CAPTURE_BUILD_NOTE),
        selectedSetupIndex = 1,
        setups = {
            {
                name = GetString(SI_GRAVVY_BUILD_PLANNER_CAPTURE_SETUP_NAME),
                note = GetString(SI_GRAVVY_BUILD_PLANNER_CAPTURE_SETUP_NOTE),
                defaultQuality = ITEM_QUALITY_LEGENDARY or 5,
                defaultLevel = defaultLevel,
                defaultChampionPoints = defaultChampionPoints,
                equipment = captureEquipment(self.owner, report),
                alternatives = {},
                skillBars = captureSkillBars(report),
                character = captureCharacter(),
                champion = captureChampion(self.owner, report),
                consumables = {},
                checklist = {},
                acquisition = {},
            },
        },
    }
    return source, report
end

function Capture:Capture()
    local source, report = self:BuildSnapshot()
    if not source then
        return nil, report
    end
    local build, message = self.owner.data:ImportBuild(source)
    if not build then
        return nil, message
    end
    return build, zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CAPTURED,
        build.name,
        report.gear,
        report.skills,
        report.champion
    ), report
end
