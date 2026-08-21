GravvyBuildPlannerAcquisition = {}

local Acquisition = GravvyBuildPlannerAcquisition

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
