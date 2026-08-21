GravvyBuildPlannerAcquisition = {}

local Acquisition = GravvyBuildPlannerAcquisition

Acquisition.ROUTES = {
    OWNED = "owned",
    BUY = "buy",
    CRAFT = "craft",
    FARM = "farm",
    RECONSTRUCT = "reconstruct",
    TRANSMUTE = "transmute",
    UNKNOWN = "unknown",
}

local routeStringIds = {
    owned = SI_GRAVVY_BUILD_PLANNER_ROUTE_OWNED,
    buy = SI_GRAVVY_BUILD_PLANNER_ROUTE_BUY,
    craft = SI_GRAVVY_BUILD_PLANNER_ROUTE_CRAFT,
    farm = SI_GRAVVY_BUILD_PLANNER_ROUTE_FARM,
    reconstruct = SI_GRAVVY_BUILD_PLANNER_ROUTE_RECONSTRUCT,
    transmute = SI_GRAVVY_BUILD_PLANNER_ROUTE_TRANSMUTE,
    unknown = SI_GRAVVY_BUILD_PLANNER_ROUTE_UNKNOWN,
}

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

function Acquisition:GetAvailableRoutes(state, match)
    if match then
        if not match.exact then
            for _, difference in ipairs(match.differences) do
                if difference == "trait" then
                    return { self.ROUTES.TRANSMUTE }
                end
            end
        end
        return { self.ROUTES.OWNED }
    end

    local routes = {}
    if state.crafted then
        routes[#routes + 1] = self.ROUTES.CRAFT
    end
    if state.tradeable then
        routes[#routes + 1] = self.ROUTES.BUY
    end
    if state.reconstructable then
        routes[#routes + 1] = self.ROUTES.RECONSTRUCT
    end
    if state.bindOnPickup then
        routes[#routes + 1] = self.ROUTES.FARM
    end
    if #routes == 0 then
        routes[1] = self.ROUTES.UNKNOWN
    end
    return routes
end

function Acquisition:GetRouteLabel(route)
    return GetString(routeStringIds[route] or SI_GRAVVY_BUILD_PLANNER_ROUTE_UNKNOWN)
end

function Acquisition:ChooseRoute(routes, preferredRoute)
    if preferredRoute then
        for _, route in ipairs(routes) do
            if route == preferredRoute then
                return route
            end
        end
    end
    return routes[1] or self.ROUTES.UNKNOWN
end

function Acquisition:GetStatus(state, match, preferredRoute)
    if match then
        if match.exact then
            return self:GetOwnedSummary(match)
        end
        for _, difference in ipairs(match.differences) do
            if difference == "trait" then
                local otherDifferences = {}
                for _, other in ipairs(match.differences) do
                    if other ~= "trait" then
                        otherDifferences[#otherDifferences + 1] = GetString(({
                            enchantment = SI_GRAVVY_BUILD_PLANNER_NEEDS_ENCHANTMENT,
                            quality = SI_GRAVVY_BUILD_PLANNER_NEEDS_QUALITY,
                        })[other])
                    end
                end
                local location = match.location == "equipped"
                    and GetString(SI_GRAVVY_BUILD_PLANNER_OWNED_EQUIPPED)
                    or match.location == "backpack"
                        and GetString(SI_GRAVVY_BUILD_PLANNER_OWNED_BACKPACK)
                        or GetString(SI_GRAVVY_BUILD_PLANNER_OWNED_BANK)
                if #otherDifferences > 0 then
                    return zo_strformat(
                        SI_GRAVVY_BUILD_PLANNER_TRANSMUTE_NEEDS_WORK,
                        location,
                        table.concat(otherDifferences, ", ")
                    )
                end
                return zo_strformat(SI_GRAVVY_BUILD_PLANNER_TRANSMUTE, location)
            end
        end
        return self:GetOwnedSummary(match)
    end

    local routes = self:GetAvailableRoutes(state, nil)
    local route = self:ChooseRoute(routes, preferredRoute)
    return zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_ACQUISITION,
        self:GetRouteLabel(route)
    )
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
