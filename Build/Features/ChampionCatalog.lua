GravvyBuildPlannerChampionCatalog = {}

local Catalog = GravvyBuildPlannerChampionCatalog

local function normalize(value)
    return zo_strlower(zo_strtrim(value or ""))
end

local function disciplineKey(disciplineType)
    if disciplineType == CHAMPION_DISCIPLINE_TYPE_WORLD then
        return "craft"
    elseif disciplineType == CHAMPION_DISCIPLINE_TYPE_COMBAT then
        return "warfare"
    elseif disciplineType == CHAMPION_DISCIPLINE_TYPE_CONDITIONING then
        return "fitness"
    end
end

function Catalog:New()
    return setmetatable({
        entries = {},
        byId = {},
        byDiscipline = { craft = {}, warfare = {}, fitness = {} },
    }, { __index = self })
end

function Catalog:Refresh()
    self.entries = {}
    self.byId = {}
    self.byDiscipline = { craft = {}, warfare = {}, fitness = {} }
    if not CHAMPION_DATA_MANAGER
        or not CHAMPION_DATA_MANAGER.ChampionDisciplineDataIterator then
        return
    end

    for _, disciplineData in CHAMPION_DATA_MANAGER:ChampionDisciplineDataIterator() do
        local key = disciplineKey(disciplineData:GetType())
        if key then
            for _, skillData in disciplineData:ChampionSkillDataIterator() do
                local skillId = skillData:GetId()
                local name = skillData:GetRawName()
                local maxPoints = skillData:GetMaxPossiblePoints()
                if skillId and skillId > 0 and name and name ~= "" and maxPoints > 0 then
                    local abilityId = skillData:GetAbilityId()
                    local entry = {
                        skillId = skillId,
                        abilityId = abilityId,
                        name = name,
                        icon = GetAbilityIcon and GetAbilityIcon(abilityId) or "",
                        discipline = key,
                        maxPoints = maxPoints,
                        isSlottable = skillData:IsTypeSlottable(),
                        skillData = skillData,
                    }
                    self.entries[#self.entries + 1] = entry
                    self.byId[skillId] = entry
                    self.byDiscipline[key][#self.byDiscipline[key] + 1] = entry
                end
            end
        end
    end
    local function byName(left, right)
        return normalize(left.name) < normalize(right.name)
    end
    table.sort(self.entries, byName)
    for _, entries in pairs(self.byDiscipline) do
        table.sort(entries, byName)
    end
end

function Catalog:FindById(skillId)
    return self.byId[tonumber(skillId)]
end

function Catalog:FindExact(name, discipline)
    local wanted = normalize(name)
    if wanted == "" then
        return nil
    end
    for _, entry in ipairs(self.byDiscipline[discipline] or {}) do
        if normalize(entry.name) == wanted then
            return entry
        end
    end
end

function Catalog:FindExactAny(name)
    local wanted = normalize(name)
    if wanted == "" then
        return nil
    end
    for _, entry in ipairs(self.entries) do
        if normalize(entry.name) == wanted then
            return entry
        end
    end
end

function Catalog:Search(query, discipline, slottableOnly, limit)
    query = normalize(query)
    local results = {}
    if query == "" then
        return results
    end
    for _, entry in ipairs(self.byDiscipline[discipline] or {}) do
        if (not slottableOnly or entry.isSlottable)
            and string.find(normalize(entry.name), query, 1, true) then
            results[#results + 1] = entry
            if limit and #results >= limit then
                break
            end
        end
    end
    return results
end
