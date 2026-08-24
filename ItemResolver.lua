GravvyBuildPlannerItemResolver = {}

local Resolver = GravvyBuildPlannerItemResolver
local Slots = GravvyBuildPlannerSlots

local armorEquipTypes = {
    head = EQUIP_TYPE_HEAD,
    shoulders = EQUIP_TYPE_SHOULDERS,
    chest = EQUIP_TYPE_CHEST,
    hands = EQUIP_TYPE_HAND,
    waist = EQUIP_TYPE_WAIST,
    legs = EQUIP_TYPE_LEGS,
    feet = EQUIP_TYPE_FEET,
}

local jewelryEquipTypes = {
    neck = EQUIP_TYPE_NECK,
    ring1 = EQUIP_TYPE_RING,
    ring2 = EQUIP_TYPE_RING,
}

local defaultTraits = {
    armor = ITEM_TRAIT_TYPE_ARMOR_DIVINES,
    jewelry = ITEM_TRAIT_TYPE_JEWELRY_ARCANE,
    weapon = ITEM_TRAIT_TYPE_WEAPON_PRECISE,
}

-- Base glyph item ids. The representative item link supplies the level and quality.
local glyphItemIds = {
    [ENCHANTMENT_SEARCH_CATEGORY_FIERY_WEAPON] = 26848,
    [ENCHANTMENT_SEARCH_CATEGORY_FROZEN_WEAPON] = 5365,
    [ENCHANTMENT_SEARCH_CATEGORY_CHARGED_WEAPON] = 26844,
    [ENCHANTMENT_SEARCH_CATEGORY_POISONED_WEAPON] = 26587,
    [ENCHANTMENT_SEARCH_CATEGORY_BEFOULED_WEAPON] = 26841,
    [ENCHANTMENT_SEARCH_CATEGORY_DAMAGE_HEALTH] = 45869,
    [ENCHANTMENT_SEARCH_CATEGORY_BERSERKER] = 54484,
    [ENCHANTMENT_SEARCH_CATEGORY_REDUCE_POWER] = 26591,
    [ENCHANTMENT_SEARCH_CATEGORY_DAMAGE_SHIELD] = 5366,
    [ENCHANTMENT_SEARCH_CATEGORY_REDUCE_ARMOR] = 26845,
    [ENCHANTMENT_SEARCH_CATEGORY_ABSORB_MAGICKA] = 45868,
    [ENCHANTMENT_SEARCH_CATEGORY_ABSORB_HEALTH] = 43573,
    [ENCHANTMENT_SEARCH_CATEGORY_ABSORB_STAMINA] = 45867,
    [ENCHANTMENT_SEARCH_CATEGORY_PRISMATIC_ONSLAUGHT] = 68344,

    [ENCHANTMENT_SEARCH_CATEGORY_MAGICKA] = 26582,
    [ENCHANTMENT_SEARCH_CATEGORY_HEALTH] = 26580,
    [ENCHANTMENT_SEARCH_CATEGORY_STAMINA] = 26588,
    [ENCHANTMENT_SEARCH_CATEGORY_PRISMATIC_DEFENSE] = 68343,

    [ENCHANTMENT_SEARCH_CATEGORY_FIRE_RESISTANT] = 26849,
    [ENCHANTMENT_SEARCH_CATEGORY_FROST_RESISTANT] = 5364,
    [ENCHANTMENT_SEARCH_CATEGORY_SHOCK_RESISTANT] = 43570,
    [ENCHANTMENT_SEARCH_CATEGORY_POISON_RESISTANT] = 26586,
    [ENCHANTMENT_SEARCH_CATEGORY_DISEASE_RESISTANT] = 26847,
    [ENCHANTMENT_SEARCH_CATEGORY_DECREASE_SPELL_DAMAGE] = 45886,
    [ENCHANTMENT_SEARCH_CATEGORY_DECREASE_PHYSICAL_DAMAGE] = 45885,
    [ENCHANTMENT_SEARCH_CATEGORY_INCREASE_SPELL_DAMAGE] = 45884,
    [ENCHANTMENT_SEARCH_CATEGORY_INCREASE_PHYSICAL_DAMAGE] = 45883,
    [ENCHANTMENT_SEARCH_CATEGORY_INCREASE_BASH_DAMAGE] = 45872,
    [ENCHANTMENT_SEARCH_CATEGORY_INCREASE_POTION_EFFECTIVENESS] = 45874,
    [ENCHANTMENT_SEARCH_CATEGORY_REDUCE_POTION_COOLDOWN] = 45875,
    [ENCHANTMENT_SEARCH_CATEGORY_REDUCE_SPELL_COST] = 45870,
    [ENCHANTMENT_SEARCH_CATEGORY_REDUCE_FEAT_COST] = 45871,
    [ENCHANTMENT_SEARCH_CATEGORY_REDUCE_BLOCK_AND_BASH] = 45873,
    [ENCHANTMENT_SEARCH_CATEGORY_MAGICKA_REGEN] = 26583,
    [ENCHANTMENT_SEARCH_CATEGORY_HEALTH_REGEN] = 26581,
    [ENCHANTMENT_SEARCH_CATEGORY_STAMINA_REGEN] = 26589,
}

local function splitItemLink(itemLink)
    local prefix, data, suffix = itemLink:match("^(|H%d+:item:)([^|]+)(|h.*|h)$")
    if not prefix then
        return nil
    end

    local fields = {}
    for value in data:gmatch("([^:]+)") do
        fields[#fields + 1] = value
    end
    if #fields < 6 then
        return nil
    end
    return prefix, fields, suffix
end

local function joinItemLink(prefix, fields, suffix)
    return prefix .. table.concat(fields, ":") .. suffix
end

local function validLevel(value)
    local maxLevel = GetMaxLevel and GetMaxLevel() or 50
    return zo_clamp(math.floor(tonumber(value) or maxLevel), 1, maxLevel)
end

local function validChampionPoints(value)
    local gearCap = GetChampionPointsPlayerProgressionCap
        and GetChampionPointsPlayerProgressionCap()
        or 160
    value = math.floor((tonumber(value) or 0) / 10) * 10
    return zo_clamp(value, 0, gearCap)
end

function Resolver:New()
    return setmetatable({ armorTypeCache = {} }, { __index = self })
end

function Resolver:GetAvailableArmorTypes(slotKey, setId)
    if not setId or not armorEquipTypes[slotKey] then
        return {}
    end

    local cacheKey = tostring(setId) .. ":" .. slotKey
    if self.armorTypeCache[cacheKey] then
        return self.armorTypeCache[cacheKey]
    end

    local found = {}
    if GetNumItemSetCollectionPieces
        and GetItemSetCollectionPieceInfo
        and GetItemSetCollectionPieceItemLink then
        local count = GetNumItemSetCollectionPieces(setId) or 0
        for index = 1, count do
            local pieceId = GetItemSetCollectionPieceInfo(setId, index)
            if pieceId then
                local itemLink = GetItemSetCollectionPieceItemLink(
                    pieceId,
                    LINK_STYLE_DEFAULT,
                    ITEM_TRAIT_TYPE_ARMOR_DIVINES,
                    ITEM_QUALITY_NORMAL
                )
                if itemLink
                    and itemLink ~= ""
                    and GetItemLinkEquipType(itemLink) == armorEquipTypes[slotKey] then
                    local armorType = GetItemLinkArmorType(itemLink)
                    if armorType and armorType ~= ARMORTYPE_NONE then
                        found[armorType] = true
                    end
                end
            end
        end
    end

    if LibSets and LibSets.GetSetArmorTypes then
        for armorType, available in pairs(LibSets.GetSetArmorTypes(setId) or {}) do
            if available then
                found[armorType] = true
            end
        end
    end

    local armorTypes = {}
    for _, armorType in ipairs({ ARMORTYPE_LIGHT, ARMORTYPE_MEDIUM, ARMORTYPE_HEAVY }) do
        if found[armorType] then
            armorTypes[#armorTypes + 1] = armorType
        end
    end
    self.armorTypeCache[cacheKey] = armorTypes
    return armorTypes
end

function Resolver:MatchesSlot(slotKey, requirement, itemLink)
    local definition = Slots:Get(slotKey)
    if definition.family == "armor" then
        if GetItemLinkEquipType(itemLink) ~= armorEquipTypes[slotKey] then
            return false
        end
        local armorType = GetItemLinkArmorType(itemLink)
        if requirement.armorType and requirement.armorType ~= ARMORTYPE_NONE then
            return armorType == requirement.armorType
        end
        return armorType ~= ARMORTYPE_NONE
    elseif definition.family == "jewelry" then
        return GetItemLinkEquipType(itemLink) == jewelryEquipTypes[slotKey]
    end

    local weaponType = GetItemLinkWeaponType(itemLink)
    if not Slots:IsRequirementCompatible(slotKey, { weaponType = weaponType }) then
        return false
    end
    if requirement.weaponType and requirement.weaponType ~= WEAPONTYPE_NONE then
        return weaponType == requirement.weaponType
    end
    return weaponType ~= WEAPONTYPE_NONE
end

function Resolver:GetEnchantInfo(itemLink)
    if not GetItemLinkFinalEnchantId or not GetEnchantSearchCategoryType then
        return nil, nil
    end
    local enchantId = GetItemLinkFinalEnchantId(itemLink)
    if not enchantId or enchantId == 0 then
        return nil, nil
    end
    return enchantId, GetEnchantSearchCategoryType(enchantId)
end

function Resolver:GetRequestedLevel(requirement, setup)
    local championPoints = tonumber(requirement.championPoints)
    local level = tonumber(requirement.level)
    if championPoints and championPoints > 0 then
        return 50, validChampionPoints(championPoints)
    elseif level then
        return validLevel(level), 0
    end

    championPoints = tonumber(setup.defaultChampionPoints)
    if championPoints and championPoints > 0 then
        return 50, validChampionPoints(championPoints)
    end
    return validLevel(setup.defaultLevel), 0
end

-- ESO folds level and quality into the subtype; the ranges follow LibItemLink 9.4.0.
function Resolver:CreateSubTypes(level, championPoints, quality)
    local qualityOffset = zo_clamp(
        math.floor(tonumber(quality) or ITEM_QUALITY_NORMAL),
        ITEM_QUALITY_NORMAL,
        ITEM_QUALITY_LEGENDARY
    ) - 1
    level = validLevel(level)
    championPoints = validChampionPoints(championPoints)

    if championPoints == 0 then
        local base = level < 4 and 30 or (level < 6 and 25 or 20)
        return base + qualityOffset, base + qualityOffset
    end

    local base
    if championPoints < 110 then
        championPoints = math.max(10, championPoints)
        base = 124 + math.floor(championPoints / 10)
        return base + qualityOffset * 10, base + qualityOffset * 10
    elseif championPoints < 130 then
        base = 236 + math.floor((championPoints - 110) / 10) * 18
    elseif championPoints < 150 then
        base = 272 + math.floor((championPoints - 130) / 10) * 18
    else
        base = 308 + math.floor((championPoints - 150) / 10) * 58
    end
    return base + qualityOffset, base + qualityOffset
end

function Resolver:MatchesRequestedLevel(itemLink, requirement, setup)
    if not GetItemLinkRequiredLevel or not GetItemLinkRequiredChampionPoints then
        return true
    end
    local level, championPoints = self:GetRequestedLevel(requirement, setup)
    local actualChampionPoints = GetItemLinkRequiredChampionPoints(itemLink) or 0
    if championPoints > 0 then
        return actualChampionPoints == championPoints
    end
    return actualChampionPoints == 0 and GetItemLinkRequiredLevel(itemLink) == level
end

function Resolver:ApplyPlannedLevel(itemLink, requirement, setup, quality)
    local prefix, fields, suffix = splitItemLink(itemLink)
    if not prefix then
        return nil
    end

    local level, championPoints = self:GetRequestedLevel(requirement, setup)
    local itemSubType, enchantSubType = self:CreateSubTypes(
        level,
        championPoints,
        quality
    )
    fields[2] = tostring(itemSubType)
    fields[3] = tostring(level)
    if tonumber(fields[4]) and tonumber(fields[4]) ~= 0 then
        fields[5] = tostring(enchantSubType)
        fields[6] = tostring(level)
    end

    local leveledLink = joinItemLink(prefix, fields, suffix)
    if not self:MatchesRequestedLevel(leveledLink, requirement, setup) then
        return nil
    end
    return leveledLink
end

function Resolver:ApplyPlannedEnchantment(itemLink, category)
    local glyphItemId = glyphItemIds[category]
    if not glyphItemId then
        return nil
    end

    local prefix, fields, suffix = splitItemLink(itemLink)
    if not prefix then
        return nil
    end

    fields[4] = tostring(glyphItemId)
    fields[5] = fields[2]
    fields[6] = fields[3]
    local enchantedLink = joinItemLink(prefix, fields, suffix)

    if GetItemLinkAppliedEnchantId and GetItemLinkAppliedEnchantId(enchantedLink) == 0 then
        return nil
    end
    local enchantId, enchantmentCategory = self:GetEnchantInfo(enchantedLink)
    if enchantmentCategory ~= category then
        return nil
    end
    return enchantedLink, enchantId
end

function Resolver:CreateGlyphLink(category, requirement, setup, quality)
    local glyphItemId = glyphItemIds[category]
    if not glyphItemId then
        return nil
    end

    local level, championPoints = self:GetRequestedLevel(requirement, setup)
    local itemSubType = self:CreateSubTypes(
        level,
        championPoints,
        quality or requirement.quality or setup.defaultQuality
    )
    local itemLink = string.format(
        "|H1:item:%d:%d:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h",
        glyphItemId,
        itemSubType,
        level
    )
    local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink) or "")
    if name == "" then
        return nil
    end
    return itemLink, name
end

function Resolver:BuildResult(itemLink, requirement, setup, quality, pieceId, collectionSlot)
    local leveledLink = self:ApplyPlannedLevel(itemLink, requirement, setup, quality)
    if leveledLink then
        itemLink = leveledLink
    end

    local enchantId, enchantmentCategory = self:GetEnchantInfo(itemLink)
    local enchantmentMatches = not requirement.enchantmentCategory
        or requirement.enchantmentCategory == enchantmentCategory
    if not enchantmentMatches then
        local enchantedLink, plannedEnchantId = self:ApplyPlannedEnchantment(
            itemLink,
            requirement.enchantmentCategory
        )
        if enchantedLink then
            itemLink = enchantedLink
            enchantId = plannedEnchantId
            enchantmentCategory = requirement.enchantmentCategory
            enchantmentMatches = true
        end
    end

    return {
        itemLink = itemLink,
        itemId = GetItemLinkItemId(itemLink),
        itemName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink)),
        pieceId = pieceId,
        collectionSlot = collectionSlot,
        enchantmentId = enchantId,
        enchantmentCategory = enchantmentCategory,
        enchantmentMatches = enchantmentMatches,
    }
end

function Resolver:ResolveWithLibSets(slotKey, requirement, setup, traitType, quality)
    if not LibSets or not LibSets.GetSetItemId or not LibSets.buildItemLink then
        return nil
    end

    local definition = Slots:Get(slotKey)
    local equipType
    local armorType
    local weaponType
    if definition.family == "armor" then
        equipType = armorEquipTypes[slotKey]
        armorType = requirement.armorType
        if armorType == ARMORTYPE_NONE then
            armorType = nil
        end
    elseif definition.family == "jewelry" then
        equipType = jewelryEquipTypes[slotKey]
    else
        weaponType = requirement.weaponType
        if weaponType == WEAPONTYPE_NONE then
            weaponType = nil
        end
    end

    local itemId = LibSets.GetSetItemId(
        requirement.setId,
        false,
        equipType,
        traitType,
        nil,
        armorType,
        weaponType
    )
    local itemLink = itemId and LibSets.buildItemLink(itemId, 366)
    if not itemLink or itemLink == "" or not self:MatchesSlot(slotKey, requirement, itemLink) then
        return nil
    end
    return self:BuildResult(itemLink, requirement, setup, quality)
end

function Resolver:Resolve(slotKey, requirement, setup)
    if not requirement.setId then
        return nil
    end

    local definition = Slots:Get(slotKey)
    local traitFamily = definition.family
    if requirement.weaponType == WEAPONTYPE_SHIELD then
        traitFamily = "armor"
    end
    local traitType = requirement.traitType or defaultTraits[traitFamily]
    local quality = requirement.quality or setup.defaultQuality
    local fallback
    if GetNumItemSetCollectionPieces
        and GetItemSetCollectionPieceInfo
        and GetItemSetCollectionPieceItemLink then
        local count = GetNumItemSetCollectionPieces(requirement.setId) or 0
        for index = 1, count do
            local pieceId, collectionSlot = GetItemSetCollectionPieceInfo(
                requirement.setId,
                index
            )
            if pieceId then
                local itemLink = GetItemSetCollectionPieceItemLink(
                    pieceId,
                    LINK_STYLE_DEFAULT,
                    traitType,
                    quality
                )
                if itemLink and itemLink ~= "" and self:MatchesSlot(slotKey, requirement, itemLink) then
                    local result = self:BuildResult(
                        itemLink,
                        requirement,
                        setup,
                        quality,
                        pieceId,
                        collectionSlot
                    )
                    if not fallback then
                        fallback = result
                    end
                    if result.enchantmentMatches then
                        return result
                    end
                end
            end
        end
    end
    return fallback or self:ResolveWithLibSets(
        slotKey,
        requirement,
        setup,
        traitType,
        quality
    )
end
