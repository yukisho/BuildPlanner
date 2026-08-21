GravvyBuildPlannerEnchantments = {}

local Enchantments = GravvyBuildPlannerEnchantments

Enchantments.DEFAULT = -1
Enchantments.CUSTOM = -2

local categories = {
    armor = {
        ENCHANTMENT_SEARCH_CATEGORY_HEALTH,
        ENCHANTMENT_SEARCH_CATEGORY_MAGICKA,
        ENCHANTMENT_SEARCH_CATEGORY_STAMINA,
        ENCHANTMENT_SEARCH_CATEGORY_PRISMATIC_DEFENSE,
    },
    jewelry = {
        ENCHANTMENT_SEARCH_CATEGORY_HEALTH_REGEN,
        ENCHANTMENT_SEARCH_CATEGORY_MAGICKA_REGEN,
        ENCHANTMENT_SEARCH_CATEGORY_STAMINA_REGEN,
        ENCHANTMENT_SEARCH_CATEGORY_INCREASE_PHYSICAL_DAMAGE,
        ENCHANTMENT_SEARCH_CATEGORY_INCREASE_SPELL_DAMAGE,
        ENCHANTMENT_SEARCH_CATEGORY_DECREASE_PHYSICAL_DAMAGE,
        ENCHANTMENT_SEARCH_CATEGORY_DECREASE_SPELL_DAMAGE,
        ENCHANTMENT_SEARCH_CATEGORY_INCREASE_BASH_DAMAGE,
        ENCHANTMENT_SEARCH_CATEGORY_REDUCE_FEAT_COST,
        ENCHANTMENT_SEARCH_CATEGORY_REDUCE_SPELL_COST,
        ENCHANTMENT_SEARCH_CATEGORY_REDUCE_BLOCK_AND_BASH,
        ENCHANTMENT_SEARCH_CATEGORY_INCREASE_POTION_EFFECTIVENESS,
        ENCHANTMENT_SEARCH_CATEGORY_REDUCE_POTION_COOLDOWN,
        ENCHANTMENT_SEARCH_CATEGORY_FIRE_RESISTANT,
        ENCHANTMENT_SEARCH_CATEGORY_FROST_RESISTANT,
        ENCHANTMENT_SEARCH_CATEGORY_SHOCK_RESISTANT,
        ENCHANTMENT_SEARCH_CATEGORY_POISON_RESISTANT,
        ENCHANTMENT_SEARCH_CATEGORY_DISEASE_RESISTANT,
        ENCHANTMENT_SEARCH_CATEGORY_PRISMATIC_REGEN,
    },
    weapon = {
        ENCHANTMENT_SEARCH_CATEGORY_ABSORB_HEALTH,
        ENCHANTMENT_SEARCH_CATEGORY_ABSORB_MAGICKA,
        ENCHANTMENT_SEARCH_CATEGORY_ABSORB_STAMINA,
        ENCHANTMENT_SEARCH_CATEGORY_BERSERKER,
        ENCHANTMENT_SEARCH_CATEGORY_FIERY_WEAPON,
        ENCHANTMENT_SEARCH_CATEGORY_FROZEN_WEAPON,
        ENCHANTMENT_SEARCH_CATEGORY_CHARGED_WEAPON,
        ENCHANTMENT_SEARCH_CATEGORY_POISONED_WEAPON,
        ENCHANTMENT_SEARCH_CATEGORY_BEFOULED_WEAPON,
        ENCHANTMENT_SEARCH_CATEGORY_DAMAGE_HEALTH,
        ENCHANTMENT_SEARCH_CATEGORY_DAMAGE_SHIELD,
        ENCHANTMENT_SEARCH_CATEGORY_REDUCE_ARMOR,
        ENCHANTMENT_SEARCH_CATEGORY_REDUCE_POWER,
        ENCHANTMENT_SEARCH_CATEGORY_PRISMATIC_ONSLAUGHT,
    },
}

function Enchantments:GetName(category)
    if not category or category < 0 then
        return nil
    end
    local name = GetString("SI_ENCHANTMENTSEARCHCATEGORYTYPE", category)
    if name and name ~= "" then
        return name
    end
end

function Enchantments:GetChoices(family, customName)
    local choices = {
        {
            label = GetString(SI_GRAVVY_BUILD_PLANNER_ITEM_DEFAULT_ENCHANTMENT),
            value = self.DEFAULT,
        },
    }
    if customName and customName ~= "" then
        choices[#choices + 1] = { label = customName, value = self.CUSTOM }
    end
    for _, category in ipairs(categories[family] or {}) do
        local name = self:GetName(category)
        if name then
            choices[#choices + 1] = { label = name, value = category }
        end
    end
    table.sort(choices, function(left, right)
        if left.value == self.DEFAULT then
            return true
        elseif right.value == self.DEFAULT then
            return false
        elseif left.value == self.CUSTOM then
            return true
        elseif right.value == self.CUSTOM then
            return false
        end
        return left.label < right.label
    end)
    return choices
end
