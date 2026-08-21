GravvyBuildPlannerAcquisition = {}

local Acquisition = GravvyBuildPlannerAcquisition

local function normalize(value)
    value = zo_strtrim(type(value) == "string" and value or "")
    return zo_strlower(value)
end

local function matchesSet(requirement, itemLink)
    local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)
    if requirement.setId then
        return hasSet and setId == requirement.setId
    end
    if requirement.setName and requirement.setName ~= "" then
        return hasSet and normalize(setName) == normalize(requirement.setName)
    end
    if requirement.itemId then
        return GetItemLinkItemId(itemLink) == requirement.itemId
    end
    return false
end

function Acquisition:New(itemResolver)
    return setmetatable({ itemResolver = itemResolver }, { __index = self })
end

function Acquisition:Classify(slotKey, requirement, setup, resolved)
    requirement = requirement or {}
    resolved = resolved or self.itemResolver:Resolve(slotKey, requirement, setup)
    local itemLink = resolved and resolved.itemLink or requirement.itemLink
    local pieceId = resolved and resolved.pieceId
    local state = {
        itemLink = itemLink,
        pieceId = pieceId,
        collectionSlot = resolved and resolved.collectionSlot,
        crafted = false,
        tradeable = false,
        bindOnPickup = false,
        reconstructable = false,
        unknown = true,
    }

    if requirement.setId and GetItemSetType then
        state.setType = GetItemSetType(requirement.setId)
        state.crafted = ITEM_SET_TYPE_CRAFTED ~= nil
            and state.setType == ITEM_SET_TYPE_CRAFTED
    end
    if itemLink and itemLink ~= "" then
        if IsItemLinkCrafted and IsItemLinkCrafted(itemLink) then
            state.crafted = true
        end
        if GetItemLinkBindType then
            state.bindType = GetItemLinkBindType(itemLink)
            state.tradeable = state.bindType == BIND_TYPE_NONE
                or state.bindType == BIND_TYPE_ON_EQUIP
            state.bindOnPickup = state.bindType == BIND_TYPE_ON_PICKUP
                or state.bindType == BIND_TYPE_ON_PICKUP_BACKPACK
        end
    end
    if not state.crafted and pieceId and IsItemSetCollectionPieceUnlocked then
        state.reconstructable = IsItemSetCollectionPieceUnlocked(pieceId)
    end

    state.unknown = not state.crafted
        and not state.tradeable
        and not state.bindOnPickup
        and not state.reconstructable
    return state
end

function Acquisition:GetSummary(state)
    local labels = {}
    if state.crafted then
        labels[#labels + 1] = GetString(SI_GRAVVY_BUILD_PLANNER_ACQUISITION_CRAFT)
    end
    if state.tradeable then
        labels[#labels + 1] = GetString(SI_GRAVVY_BUILD_PLANNER_ACQUISITION_GUILD_STORE)
    end
    if state.reconstructable then
        labels[#labels + 1] = GetString(SI_GRAVVY_BUILD_PLANNER_ACQUISITION_RECONSTRUCT)
    end
    if state.bindOnPickup then
        labels[#labels + 1] = GetString(SI_GRAVVY_BUILD_PLANNER_ACQUISITION_BIND_ON_PICKUP)
    end
    if #labels == 0 then
        return GetString(SI_GRAVVY_BUILD_PLANNER_ACQUISITION_UNKNOWN)
    end
    return table.concat(labels, " / ")
end

function Acquisition:CompareItem(slotKey, requirement, setup, itemLink)
    if not itemLink
        or itemLink == ""
        or not matchesSet(requirement, itemLink)
        or not self.itemResolver:MatchesSlot(slotKey, requirement, itemLink)
        or not self.itemResolver:MatchesRequestedLevel(itemLink, requirement, setup) then
        return nil
    end

    local differences = {}
    if requirement.traitType
        and requirement.traitType ~= ITEM_TRAIT_TYPE_NONE
        and GetItemLinkTraitInfo(itemLink) ~= requirement.traitType then
        differences[#differences + 1] = "trait"
    end
    if requirement.enchantmentCategory then
        local _, category = self.itemResolver:GetEnchantInfo(itemLink)
        if category ~= requirement.enchantmentCategory then
            differences[#differences + 1] = "enchantment"
        end
    end

    local targetQuality = requirement.quality or setup.defaultQuality
    if targetQuality
        and GetItemLinkDisplayQuality(itemLink) < targetQuality then
        differences[#differences + 1] = "quality"
    end

    return {
        exact = #differences == 0,
        differences = differences,
        itemLink = itemLink,
    }
end

function Acquisition:GetOwnedSummary(match)
    if not match then
        return nil
    end

    local locationId = match.location == "equipped"
        and SI_GRAVVY_BUILD_PLANNER_OWNED_EQUIPPED
        or match.location == "backpack"
            and SI_GRAVVY_BUILD_PLANNER_OWNED_BACKPACK
            or SI_GRAVVY_BUILD_PLANNER_OWNED_BANK
    local location = GetString(locationId)
    if match.exact then
        return zo_strformat(SI_GRAVVY_BUILD_PLANNER_OWNED_EXACT, location)
    end

    local labels = {}
    local differenceIds = {
        trait = SI_GRAVVY_BUILD_PLANNER_NEEDS_TRAIT,
        enchantment = SI_GRAVVY_BUILD_PLANNER_NEEDS_ENCHANTMENT,
        quality = SI_GRAVVY_BUILD_PLANNER_NEEDS_QUALITY,
    }
    for _, difference in ipairs(match.differences) do
        labels[#labels + 1] = GetString(differenceIds[difference])
    end
    return zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_OWNED_NEEDS_WORK,
        location,
        table.concat(labels, ", ")
    )
end
