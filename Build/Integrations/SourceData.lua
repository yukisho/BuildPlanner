GravvyBuildPlannerSourceData = {}

local SourceData = GravvyBuildPlannerSourceData
local PRICE_ORDER = { "ttc", "esohub", "mm", "att" }

local priceLabels = {
    ttc = SI_GRAVVY_BUILD_PLANNER_SOURCE_TTC,
    esohub = SI_GRAVVY_BUILD_PLANNER_SOURCE_ESOHUB,
    mm = SI_GRAVVY_BUILD_PLANNER_SOURCE_MM,
    att = SI_GRAVVY_BUILD_PLANNER_SOURCE_ATT,
}

local setTypeChecks = {
    { "IsMonsterSet", SI_GRAVVY_BUILD_PLANNER_SOURCE_MONSTER },
    { "IsTrialSet", SI_GRAVVY_BUILD_PLANNER_SOURCE_TRIAL },
    { "IsArenaSet", SI_GRAVVY_BUILD_PLANNER_SOURCE_ARENA },
    { "IsDungeonSet", SI_GRAVVY_BUILD_PLANNER_SOURCE_DUNGEON },
    { "IsOverlandSet", SI_GRAVVY_BUILD_PLANNER_SOURCE_OVERLAND },
    { "IsPvPSet", SI_GRAVVY_BUILD_PLANNER_SOURCE_PVP },
    { "IsMythicSet", SI_GRAVVY_BUILD_PLANNER_SOURCE_MYTHIC },
}

local function safeCall(callback, ...)
    if type(callback) ~= "function" then return nil end
    local ok, value = pcall(callback, ...)
    return ok and value or nil
end

local function positivePrice(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value <= 0 then
        return nil
    end
    return math.max(1, math.floor(value + 0.5))
end

local function ttcPrice(itemLink)
    if type(TamrielTradeCentrePrice) ~= "table" then return nil end
    local info = safeCall(TamrielTradeCentrePrice.GetPriceInfo,
        TamrielTradeCentrePrice, itemLink)
    return positivePrice(info and (info.SuggestedPrice or info.Avg))
end

local function esoHubPrice(itemLink)
    if type(LibEsoHubPrices) ~= "table" then return nil end
    return positivePrice(safeCall(LibEsoHubPrices.GetSimpleItemPrice, itemLink))
end

local function masterMerchantPrice(itemLink)
    if type(MasterMerchant) == "table" then
        local info = safeCall(MasterMerchant.GetTooltipStats,
            MasterMerchant, itemLink, true, false)
        local price = positivePrice(info and info.avgPrice)
        if price then return price end
    end
    if type(LibPrice) == "table" then
        return positivePrice(safeCall(LibPrice.ItemLinkToPriceGold,
            itemLink, "mm"))
    end
end

local function arkadiusPrice(itemLink)
    local sales = type(ArkadiusTradeTools) == "table"
        and type(ArkadiusTradeTools.Modules) == "table"
        and ArkadiusTradeTools.Modules.Sales or nil
    if type(sales) == "table" then
        for _, days in ipairs({ 3, 90 }) do
            local price = positivePrice(safeCall(sales.GetAveragePricePerItem,
                sales, itemLink, GetTimeStamp() - ((ZO_ONE_DAY_IN_SECONDS or 86400) * days)))
            if price then return price end
        end
    end
    if type(LibPrice) == "table" then
        return positivePrice(safeCall(LibPrice.ItemLinkToPriceGold,
            itemLink, "att"))
    end
end

local priceReaders = {
    ttc = ttcPrice,
    esohub = esoHubPrice,
    mm = masterMerchantPrice,
    att = arkadiusPrice,
}

local function collectIds(value)
    local result, seen = {}, {}
    local function add(id)
        id = tonumber(id)
        if id and id > 0 and id == math.floor(id) and not seen[id] then
            seen[id] = true
            result[#result + 1] = id
        end
    end
    if type(value) == "number" then
        add(value)
    elseif type(value) == "table" then
        for key, entry in pairs(value) do
            if type(entry) == "number" then
                add(entry)
            elseif entry == true then
                add(key)
            end
        end
    end
    table.sort(result)
    return result
end

local function travelNodeName(nodeId)
    if type(GetFastTravelNodeInfo) ~= "function" then return nil end
    local values = { pcall(GetFastTravelNodeInfo, nodeId) }
    if not values[1] then return nil end
    for index = 2, #values do
        if type(values[index]) == "string" and values[index] ~= "" then
            return values[index]
        end
    end
end

local function addUnique(result, seen, value)
    if type(value) == "string" then value = zo_strtrim(value) end
    if not value or value == "" then return end
    local key = zo_strlower(value)
    if not seen[key] then
        seen[key] = true
        result[#result + 1] = value
    end
end

local function limitedList(values)
    if #values <= 3 then return table.concat(values, ", ") end
    return table.concat({ values[1], values[2], values[3] }, ", ")
        .. " " .. zo_strformat(SI_GRAVVY_BUILD_PLANNER_SOURCE_MORE, #values - 3)
end

function SourceData:New()
    return setmetatable({}, { __index = self })
end

function SourceData:GetPrice(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then return nil end
    for _, source in ipairs(PRICE_ORDER) do
        local price = priceReaders[source](itemLink)
        if price then
            return {
                price = price,
                source = source,
                sourceName = GetString(priceLabels[source]),
            }
        end
    end
end

function SourceData:GetSetLocations(setId, crafted)
    if not setId or type(LibSets) ~= "table" then return {} end
    local result, seen = {}, {}
    if crafted and type(LibSets.GetSetWayshrineIds) == "function" then
        for _, nodeId in ipairs(collectIds(safeCall(LibSets.GetSetWayshrineIds, setId))) do
            addUnique(result, seen, travelNodeName(nodeId))
        end
    end
    if type(LibSets.GetSetZoneIds) == "function" and type(GetZoneNameById) == "function" then
        for _, zoneId in ipairs(collectIds(safeCall(LibSets.GetSetZoneIds, setId))) do
            addUnique(result, seen, safeCall(GetZoneNameById, zoneId))
        end
    end
    return result
end

function SourceData:GetSetType(setId)
    if not setId or type(LibSets) ~= "table" then
        return GetString(SI_GRAVVY_BUILD_PLANNER_SOURCE_SET)
    end
    for _, check in ipairs(setTypeChecks) do
        if safeCall(LibSets[check[1]], setId) == true then
            return GetString(check[2])
        end
    end
    return GetString(SI_GRAVVY_BUILD_PLANNER_SOURCE_SET)
end

function SourceData:GetGuidance(route, requirement, state, resolved)
    requirement = requirement or {}
    state = state or {}
    local setId = requirement.setId
    local locations = self:GetSetLocations(setId, state.crafted)
    local locationText = #locations > 0 and limitedList(locations)
        or GetString(SI_GRAVVY_BUILD_PLANNER_SOURCE_LOCATION_UNKNOWN)

    if route == "craft" then
        local traits = type(LibSets) == "table" and type(LibSets.GetSetTraitsNeeded) == "function"
            and tonumber(safeCall(LibSets.GetSetTraitsNeeded, setId)) or nil
        local traitText = traits and traits > 0 and zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_SOURCE_TRAITS, traits) or ""
        return zo_strformat(SI_GRAVVY_BUILD_PLANNER_SOURCE_CRAFT,
            locationText, traitText)
    elseif route == "farm" or route == "unknown" then
        return zo_strformat(SI_GRAVVY_BUILD_PLANNER_SOURCE_FARM,
            self:GetSetType(setId), locationText)
    elseif route == "buy" then
        local itemLink = resolved and resolved.itemLink or requirement.itemLink
        local suggestion = self:GetPrice(itemLink)
        local buyText
        if suggestion then
            local amount = ZO_CommaDelimitNumber and ZO_CommaDelimitNumber(suggestion.price)
                or tostring(suggestion.price)
            buyText = zo_strformat(SI_GRAVVY_BUILD_PLANNER_SOURCE_BUY_PRICE,
                amount, suggestion.sourceName)
        else
            buyText = GetString(SI_GRAVVY_BUILD_PLANNER_SOURCE_BUY)
        end
        if #locations > 0 then
            buyText = buyText .. "\n" .. zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_SOURCE_FARM,
                self:GetSetType(setId), locationText
            )
        end
        return buyText
    elseif route == "reconstruct" then
        return GetString(SI_GRAVVY_BUILD_PLANNER_SOURCE_RECONSTRUCT)
    elseif route == "transmute" then
        return GetString(SI_GRAVVY_BUILD_PLANNER_SOURCE_TRANSMUTE)
    end
    return nil
end
