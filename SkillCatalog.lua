GravvyBuildPlannerSkillCatalog = {}

local Catalog = GravvyBuildPlannerSkillCatalog

local function normalize(value)
    return zo_strlower(zo_strtrim(value or ""))
end

function Catalog:New()
    return setmetatable({ entries = {}, byName = {}, byId = {} }, { __index = self })
end

function Catalog:AddAbility(abilityId, isUltimate)
    abilityId = tonumber(abilityId)
    if not abilityId or abilityId <= 0 then
        return
    end
    local name = GetAbilityName(abilityId)
    if not name or name == "" then
        return
    end
    local key = normalize(name)
    if self.byName[key] then
        return
    end
    local entry = {
        abilityId = abilityId,
        name = name,
        icon = GetAbilityIcon(abilityId),
        isUltimate = isUltimate == true,
    }
    self.entries[#self.entries + 1] = entry
    self.byName[key] = entry
    self.byId[abilityId] = entry
end

function Catalog:Refresh()
    self.entries = {}
    self.byName = {}
    self.byId = {}
    if not SKILLS_DATA_MANAGER then
        return
    end
    for _, skillType in SKILLS_DATA_MANAGER:SkillTypeIterator() do
        for _, skillLine in skillType:SkillLineIterator() do
            for _, skill in skillLine:SkillIterator() do
                if not skill:IsPassive() then
                    if skill.GetMorphData and MORPH_SLOT_ITERATION_BEGIN then
                        for morph = MORPH_SLOT_ITERATION_BEGIN, MORPH_SLOT_ITERATION_END do
                            local progression = skill:GetMorphData(morph)
                            if progression then
                                self:AddAbility(progression:GetAbilityId(), skill:IsUltimate())
                            end
                        end
                    else
                        local progression = skill:GetCurrentProgressionData()
                        if progression then
                            self:AddAbility(progression:GetAbilityId(), skill:IsUltimate())
                        end
                    end
                end
            end
        end
    end
    table.sort(self.entries, function(left, right) return left.name < right.name end)
end

function Catalog:FindExact(name)
    return self.byName[normalize(name)]
end

function Catalog:FindById(abilityId)
    return self.byId[tonumber(abilityId)]
end

function Catalog:Search(text, ultimate, limit)
    local query = normalize(text)
    local matches = {}
    if query == "" then
        return matches
    end
    for _, entry in ipairs(self.entries) do
        local name = normalize(entry.name)
        if entry.isUltimate == ultimate and string.find(name, query, 1, true) then
            matches[#matches + 1] = entry
            if #matches >= (limit or 8) then
                break
            end
        end
    end
    return matches
end
