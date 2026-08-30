GravvyBuildPlannerValidation = {}

local Validation = GravvyBuildPlannerValidation

Validation.MAX_BUILDS = 100
Validation.MAX_SETUPS = 100
Validation.MAX_STRING = 512
Validation.MAX_NAME = 100
Validation.MAX_NOTE = 4000
Validation.MAX_LINK = 2048
Validation.MAX_ID = 4294967294
Validation.MIN_LEVEL = 1
Validation.MAX_LEVEL = 50
Validation.MAX_CHAMPION_POINTS = 160
Validation.MIN_QUALITY = 1
Validation.MAX_QUALITY = 5

local weaponConstants = {
    "WEAPONTYPE_SHIELD", "WEAPONTYPE_AXE", "WEAPONTYPE_HAMMER",
    "WEAPONTYPE_SWORD", "WEAPONTYPE_DAGGER", "WEAPONTYPE_TWO_HANDED_AXE",
    "WEAPONTYPE_TWO_HANDED_HAMMER", "WEAPONTYPE_TWO_HANDED_SWORD",
    "WEAPONTYPE_BOW", "WEAPONTYPE_FIRE_STAFF", "WEAPONTYPE_FROST_STAFF",
    "WEAPONTYPE_LIGHTNING_STAFF", "WEAPONTYPE_HEALING_STAFF",
}

local function wholeNumber(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= math.floor(value) or value < minimum or value > maximum then
        return nil
    end
    return value
end

function Validation:WholeNumber(value, minimum, maximum)
    return wholeNumber(value, minimum or 0, maximum or self.MAX_ID)
end

function Validation:SanitizePlainText(value, maximum, allowEmpty, multiline)
    if type(value) ~= "string" then
        return nil
    end
    -- Names and notes are rendered by ESO labels. Preserve the visible part of a
    -- pasted link, discard texture/color directives, then neutralize stray pipes.
    value = value:gsub("|[Hh][^|]-|h(.-)|h", "%1")
    value = value:gsub("|[Tt][^|]-|t", "")
    value = value:gsub("|[Cc]%x%x%x%x%x%x", "")
    value = value:gsub("|[Rr]", "")
    value = value:gsub("|", "")
    if multiline then
        value = value:gsub("[%z\1-\8\11\12\14-\31]", "")
    else
        value = value:gsub("%c", " ")
    end
    value = zo_strtrim(value)
    if maximum and #value > maximum then
        value = string.sub(value, 1, maximum)
    end
    if not allowEmpty and value == "" then
        return nil
    end
    return value
end

function Validation:IsItemLink(value)
    if type(value) ~= "string" or #value > self.MAX_LINK then
        return false
    end
    if value == "" then
        return true
    end
    if value:sub(1, 1) ~= "|" then
        return true
    end
    return value:find("|H%d+:item:", 1) ~= nil and value:find("|h|h", 1, true) ~= nil
end

function Validation:IsId(value, allowZero)
    return wholeNumber(value, allowZero and 0 or 1, self.MAX_ID) ~= nil
end

function Validation:IsArmorType(value, allowNone)
    value = tonumber(value)
    if allowNone and value == (ARMORTYPE_NONE or 0) then
        return true
    end
    local valid = {}
    for _, name in ipairs({ "ARMORTYPE_LIGHT", "ARMORTYPE_MEDIUM", "ARMORTYPE_HEAVY" }) do
        if _G[name] ~= nil then valid[_G[name]] = true end
    end
    if next(valid) == nil then
        return wholeNumber(value, 1, 3) ~= nil
    end
    return valid[value] == true
end

function Validation:IsWeaponType(value, allowNone)
    value = tonumber(value)
    if allowNone and value == (WEAPONTYPE_NONE or 0) then
        return true
    end
    local valid = {}
    for _, name in ipairs(weaponConstants) do
        if _G[name] ~= nil then valid[_G[name]] = true end
    end
    return valid[value] == true
end

function Validation:IsTraitType(value, family)
    value = tonumber(value)
    if value == (ITEM_TRAIT_TYPE_NONE or 0) then
        return true
    end
    if not wholeNumber(value, 1, 255) then
        return false
    end
    if not GetItemTraitTypeCategory then
        return true
    end
    local category = GetItemTraitTypeCategory(value)
    local expected = family == "armor" and ITEM_TRAIT_TYPE_CATEGORY_ARMOR
        or family == "weapon" and ITEM_TRAIT_TYPE_CATEGORY_WEAPON
        or family == "jewelry" and ITEM_TRAIT_TYPE_CATEGORY_JEWELRY
    return expected ~= nil and category == expected
end

function Validation:IsEnchantmentCategory(value, family)
    if not wholeNumber(value, 0, 255) then
        return false
    end
    if GravvyBuildPlannerEnchantments
        and GravvyBuildPlannerEnchantments.IsValidForFamily then
        return GravvyBuildPlannerEnchantments:IsValidForFamily(family, value)
    end
    return true
end

function Validation:IsQuality(value)
    return wholeNumber(value, self.MIN_QUALITY, self.MAX_QUALITY) ~= nil
end

function Validation:IsLevel(value)
    return wholeNumber(value, self.MIN_LEVEL, self.MAX_LEVEL) ~= nil
end

function Validation:IsChampionPoints(value)
    value = wholeNumber(value, 0, self.MAX_CHAMPION_POINTS)
    return value ~= nil and value % 10 == 0
end

function Validation:IsRequirement(slotKey, requirement)
    if type(requirement) ~= "table" then
        return false
    end
    local definition = GravvyBuildPlannerSlots:Get(slotKey)
    if not definition or not GravvyBuildPlannerSlots:IsRequirementCompatible(slotKey, requirement) then
        return false
    end
    if requirement.setId ~= nil and not self:IsId(requirement.setId, false) then return false end
    if requirement.itemId ~= nil and not self:IsId(requirement.itemId, false) then return false end
    if requirement.armorType ~= nil and not self:IsArmorType(requirement.armorType, true) then return false end
    if requirement.weaponType ~= nil and not self:IsWeaponType(requirement.weaponType, true) then return false end
    local family = definition.family
    if family == "weapon" and WEAPONTYPE_SHIELD
        and requirement.weaponType == WEAPONTYPE_SHIELD then
        family = "armor"
    end
    if requirement.traitType ~= nil and not self:IsTraitType(requirement.traitType, family) then return false end
    if requirement.enchantmentId ~= nil and not self:IsId(requirement.enchantmentId, false) then return false end
    if requirement.enchantmentCategory ~= nil
        and not self:IsEnchantmentCategory(requirement.enchantmentCategory, family) then return false end
    if requirement.quality ~= nil and not self:IsQuality(requirement.quality) then return false end
    if requirement.level ~= nil and not self:IsLevel(requirement.level) then return false end
    if requirement.championPoints ~= nil and not self:IsChampionPoints(requirement.championPoints) then return false end
    return true
end
