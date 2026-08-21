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

function Resolver:New()
    return setmetatable({}, { __index = self })
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

function Resolver:ApplyPlannedEnchantment(itemLink, category)
    local glyphItemId = glyphItemIds[category]
    if not glyphItemId then
        return nil
    end

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

    fields[4] = tostring(glyphItemId)
    fields[5] = fields[2]
    fields[6] = fields[3]
    local enchantedLink = prefix .. table.concat(fields, ":") .. suffix

    if GetItemLinkAppliedEnchantId and GetItemLinkAppliedEnchantId(enchantedLink) == 0 then
        return nil
    end
    local enchantId, enchantmentCategory = self:GetEnchantInfo(enchantedLink)
    if enchantmentCategory ~= category then
        return nil
    end
    return enchantedLink, enchantId
end

function Resolver:Resolve(slotKey, requirement, setup)
    if not requirement.setId
        or not GetNumItemSetCollectionPieces
        or not GetItemSetCollectionPieceInfo
        or not GetItemSetCollectionPieceItemLink then
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
    local count = GetNumItemSetCollectionPieces(requirement.setId) or 0
    for index = 1, count do
        local pieceId = GetItemSetCollectionPieceInfo(requirement.setId, index)
        if pieceId then
            local itemLink = GetItemSetCollectionPieceItemLink(
                pieceId,
                LINK_STYLE_DEFAULT,
                traitType,
                quality
            )
            if itemLink and itemLink ~= "" and self:MatchesSlot(slotKey, requirement, itemLink) then
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
                local result = {
                    itemLink = itemLink,
                    itemId = GetItemLinkItemId(itemLink),
                    itemName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink)),
                    enchantmentId = enchantId,
                    enchantmentCategory = enchantmentCategory,
                    enchantmentMatches = enchantmentMatches,
                }
                if not fallback then
                    fallback = result
                end
                if enchantmentMatches then
                    return result
                end
            end
        end
    end
    return fallback
end
