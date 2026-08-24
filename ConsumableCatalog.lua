GravvyBuildPlannerConsumableCatalog = {}

local Catalog = GravvyBuildPlannerConsumableCatalog

local function normalize(value)
    return zo_strlower(zo_strtrim(value or ""))
end

local function getCategory(itemLink)
    if not GetItemLinkItemType then
        return nil
    end
    local itemType = GetItemLinkItemType(itemLink)
    if itemType == ITEMTYPE_FOOD then
        return "food"
    elseif itemType == ITEMTYPE_DRINK then
        return "drink"
    elseif itemType == ITEMTYPE_POTION then
        return "potion"
    elseif itemType == ITEMTYPE_POISON then
        return "poison"
    end
end

function Catalog:GetCategory(itemLink)
    return getCategory(itemLink)
end

function Catalog:New(data)
    return setmetatable({ data = data, entries = {} }, { __index = self })
end

function Catalog:Add(entry, seen)
    local name = zo_strtrim(entry.name or "")
    if name == "" then
        return
    end
    local key = entry.itemId and ("id:" .. tostring(entry.itemId))
        or entry.category .. ":" .. normalize(name)
    if seen[key] then
        return
    end
    seen[key] = true
    self.entries[#self.entries + 1] = {
        category = entry.category or "other",
        name = name,
        itemId = entry.itemId,
        itemLink = entry.itemLink,
        icon = entry.icon or "",
    }
end

function Catalog:Refresh()
    self.entries = {}
    local seen = {}
    for _, build in ipairs(self.data:GetBuilds()) do
        for _, setup in ipairs(build.setups) do
            for _, entry in ipairs(setup.consumables or {}) do
                self:Add(entry, seen)
            end
        end
    end

    if GetBagSize and GetItemLink then
        for _, bagId in ipairs({ BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK, BAG_VIRTUAL }) do
            for slotIndex = 0, (GetBagSize(bagId) or 0) - 1 do
                local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
                local category = itemLink ~= "" and getCategory(itemLink)
                if category then
                    self:Add({
                        category = category,
                        name = GetItemLinkName(itemLink),
                        itemId = GetItemLinkItemId(itemLink),
                        itemLink = itemLink,
                        icon = GetItemLinkIcon(itemLink),
                    }, seen)
                end
            end
        end
    end
    table.sort(self.entries, function(left, right)
        return normalize(left.name) < normalize(right.name)
    end)
end

function Catalog:Search(query, category, limit)
    query = normalize(query)
    local results = {}
    if query == "" then
        return results
    end
    for _, entry in ipairs(self.entries) do
        if entry.category == category
            and string.find(normalize(entry.name), query, 1, true) then
            results[#results + 1] = entry
            if limit and #results >= limit then
                break
            end
        end
    end
    return results
end

function Catalog:FindExact(name, category)
    local wanted = normalize(name)
    for _, entry in ipairs(self.entries) do
        if normalize(entry.name) == wanted and entry.category == category then
            return entry
        end
    end
end
