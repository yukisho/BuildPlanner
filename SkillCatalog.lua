GravvyBuildPlannerSkillCatalog = {}

local Catalog = GravvyBuildPlannerSkillCatalog

local function normalize(value)
    return zo_strlower(zo_strtrim(value or ""))
end

function Catalog:New()
    return setmetatable({
        entries = {},
        byName = {},
        byId = {},
        passiveEntries = {},
        passiveByName = {},
        passiveById = {},
    }, { __index = self })
end

function Catalog:AddAbility(abilityId, isUltimate, progression, skillLineInfo)
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
        progression = progression,
        skillType = skillLineInfo and skillLineInfo.skillType,
        skillLineIndex = skillLineInfo and skillLineInfo.skillLineIndex,
        skillLine = skillLineInfo and skillLineInfo.name or "",
    }
    self.entries[#self.entries + 1] = entry
    self.byName[key] = entry
    self.byId[abilityId] = entry
end

function Catalog:AddPassive(name, skillLine, maxRank, progressions)
    name = zo_strtrim(name or "")
    maxRank = tonumber(maxRank)
    if name == "" or not maxRank or maxRank < 1 or type(progressions) ~= "table" then
        return
    end
    local last = progressions[maxRank]
    if not last or not last.abilityId then
        return
    end
    local entry = {
        name = name,
        skillLine = skillLine or "",
        maxRank = maxRank,
        abilityId = last.abilityId,
        icon = last.icon or GetAbilityIcon(last.abilityId),
        progressions = progressions,
    }
    self.passiveEntries[#self.passiveEntries + 1] = entry
    local key = normalize(name)
    if not self.passiveByName[key] then
        self.passiveByName[key] = entry
    end
    for _, progression in pairs(progressions) do
        self.passiveById[progression.abilityId] = entry
    end
end

function Catalog:Refresh()
    self.entries = {}
    self.byName = {}
    self.byId = {}
    self.passiveEntries = {}
    self.passiveByName = {}
    self.passiveById = {}
    if not SKILLS_DATA_MANAGER then
        return
    end
    for skillTypeIndex, skillType in SKILLS_DATA_MANAGER:SkillTypeIterator() do
        local skillTypeId = skillType.GetSkillType and skillType:GetSkillType()
            or skillTypeIndex
        for skillLineIndex, skillLine in skillType:SkillLineIterator() do
            local skillLineInfo = {
                skillType = skillTypeId,
                skillLineIndex = skillLineIndex,
                name = skillLine:GetName(),
            }
            for _, skill in skillLine:SkillIterator() do
                if skill:IsPassive() then
                    local progressions = {}
                    local numRanks = skill:GetNumRanks()
                    for rank = 1, numRanks do
                        local progression = skill:GetRankData(rank)
                        if progression then
                            progressions[rank] = {
                                abilityId = progression:GetAbilityId(),
                                icon = progression.GetIcon and progression:GetIcon()
                                    or GetAbilityIcon(progression:GetAbilityId()),
                                progression = progression,
                            }
                        end
                    end
                    local last = progressions[numRanks]
                    if last then
                        self:AddPassive(
                            GetAbilityName(last.abilityId),
                            skillLine:GetName(),
                            numRanks,
                            progressions
                        )
                    end
                else
                    if skill.GetMorphData and MORPH_SLOT_ITERATION_BEGIN then
                        for morph = MORPH_SLOT_ITERATION_BEGIN, MORPH_SLOT_ITERATION_END do
                            local progression = skill:GetMorphData(morph)
                            if progression then
                                self:AddAbility(
                                    progression:GetAbilityId(),
                                    skill:IsUltimate(),
                                    progression,
                                    skillLineInfo
                                )
                            end
                        end
                    else
                        local progression = skill:GetCurrentProgressionData()
                        if progression then
                            self:AddAbility(
                                progression:GetAbilityId(),
                                skill:IsUltimate(),
                                progression,
                                skillLineInfo
                            )
                        end
                    end
                end
            end
        end
    end
    table.sort(self.entries, function(left, right) return left.name < right.name end)
    table.sort(self.passiveEntries, function(left, right)
        if left.name == right.name then
            return left.skillLine < right.skillLine
        end
        return left.name < right.name
    end)
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

function Catalog:FindPassiveExact(name)
    return self.passiveByName[normalize(name)]
end

function Catalog:FindPassiveById(abilityId)
    return self.passiveById[tonumber(abilityId)]
end

function Catalog:GetPassiveProgression(entry, rank)
    entry = type(entry) == "table" and entry or self:FindPassiveById(entry)
    rank = tonumber(rank)
    return entry and rank and entry.progressions[rank]
end

function Catalog:SearchPassives(text, limit)
    local query = normalize(text)
    local matches = {}
    if query == "" then
        return matches
    end
    for _, entry in ipairs(self.passiveEntries) do
        if string.find(normalize(entry.name), query, 1, true)
            or string.find(normalize(entry.skillLine), query, 1, true) then
            matches[#matches + 1] = entry
            if #matches >= (limit or 8) then
                break
            end
        end
    end
    return matches
end
