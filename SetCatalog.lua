GravvyBuildPlannerSetCatalog = {}

local Catalog = GravvyBuildPlannerSetCatalog
local MAX_RESULTS = 40

local function normalize(value)
    value = zo_strtrim(type(value) == "string" and value or "")
    return zo_strlower(value)
end

function Catalog:New(data)
    local catalog = setmetatable({ data = data, entries = {} }, { __index = self })
    catalog:Refresh()
    return catalog
end

function Catalog:Add(seen, setId, name)
    name = zo_strtrim(name or "")
    if name == "" then
        return
    end

    local key = normalize(name)
    local existing = seen[key]
    if existing then
        if not existing.setId and setId then
            existing.setId = setId
        end
        return
    end

    local entry = { setId = setId, name = name, searchName = key }
    seen[key] = entry
    self.entries[#self.entries + 1] = entry
end

function Catalog:Refresh()
    self.entries = {}
    local seen = {}

    if GetNextItemSetCollectionId and GetItemSetName then
        local setId
        local count = 0
        repeat
            setId = GetNextItemSetCollectionId(setId)
            if setId then
                self:Add(seen, setId, GetItemSetName(setId))
                count = count + 1
            end
        until not setId or count >= 5000
    end

    for _, build in ipairs(self.data:GetBuilds()) do
        for _, setup in ipairs(build.setups) do
            for _, requirement in pairs(setup.equipment) do
                self:Add(seen, requirement.setId, requirement.setName)
            end
        end
    end

    table.sort(self.entries, function(left, right)
        return left.searchName < right.searchName
    end)
end

function Catalog:FindExact(name)
    local searchName = normalize(name)
    for _, entry in ipairs(self.entries) do
        if entry.searchName == searchName then
            return entry
        end
    end
end

function Catalog:Search(text)
    local query = normalize(text)
    if #query < 2 then
        return {}
    end

    local startsWith = {}
    local contains = {}
    for _, entry in ipairs(self.entries) do
        local position = string.find(entry.searchName, query, 1, true)
        if position == 1 then
            startsWith[#startsWith + 1] = entry
        elseif position then
            contains[#contains + 1] = entry
        end
    end

    local results = {}
    for _, group in ipairs({ startsWith, contains }) do
        for _, entry in ipairs(group) do
            results[#results + 1] = entry
            if #results == MAX_RESULTS then
                return results
            end
        end
    end
    return results
end
