GravvyBuildPlannerChecklistDetection = {}

local Detection = GravvyBuildPlannerChecklistDetection

local function normalize(value)
    return zo_strlower(zo_strtrim(value or ""))
end

local function currentAbilityId(skill)
    local progression = skill and skill.GetCurrentProgressionData
        and skill:GetCurrentProgressionData()
    return progression and progression.GetAbilityId and progression:GetAbilityId() or nil
end

function Detection:New(owner)
    return setmetatable({ owner = owner, research = {}, researchByName = {} }, { __index = self })
end

function Detection:RefreshResearch()
    self.research = {}
    self.researchByName = {}
    if not GetNumSmithingResearchLines or not GetSmithingResearchLineInfo
        or not GetSmithingResearchLineTraitInfo then
        return
    end
    local craftingTypes = {}
    local function addCraft(craftingType)
        if craftingType then craftingTypes[#craftingTypes + 1] = craftingType end
    end
    addCraft(CRAFTING_TYPE_BLACKSMITHING)
    addCraft(CRAFTING_TYPE_CLOTHIER)
    addCraft(CRAFTING_TYPE_WOODWORKING)
    addCraft(CRAFTING_TYPE_JEWELRYCRAFTING)
    for _, craftingType in ipairs(craftingTypes) do
        if craftingType then
            local craftName = GetString and GetString("SI_TRADESKILLTYPE", craftingType) or ""
            for researchLineIndex = 1, GetNumSmithingResearchLines(craftingType) do
                local lineName, icon, numTraits = GetSmithingResearchLineInfo(
                    craftingType,
                    researchLineIndex
                )
                for traitIndex = 1, (numTraits or 0) do
                    local traitType = GetSmithingResearchLineTraitInfo(
                        craftingType,
                        researchLineIndex,
                        traitIndex
                    )
                    local traitName = GetString and GetString("SI_ITEMTRAITTYPE", traitType) or ""
                    if traitName ~= "" and lineName and lineName ~= "" then
                        local name = traitName .. " · " .. lineName
                        if craftName ~= "" then
                            name = name .. " · " .. craftName
                        end
                        local entry = {
                            name = name,
                            detail = GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SOURCE_TRAIT),
                            icon = icon or "",
                            targetRank = nil,
                            detection = {
                                kind = "trait",
                                craftingType = craftingType,
                                researchLineIndex = researchLineIndex,
                                traitIndex = traitIndex,
                            },
                        }
                        self.research[#self.research + 1] = entry
                        self.researchByName[normalize(name)] = entry
                    end
                end
            end
        end
    end
    table.sort(self.research, function(left, right)
        return normalize(left.name) < normalize(right.name)
    end)
end

function Detection:Initialize()
    self:RefreshResearch()
    local function refresh()
        local ui = self.owner.ui
        if ui and ui.activeView == "checklist" and ui.IsShowing and ui:IsShowing() then
            ui:RefreshChecklistPlanner()
        end
        local gamepad = self.owner.gamepad
        if gamepad and gamepad.activeView == "checklist" and gamepad:IsShowing() then
            gamepad:Refresh(true)
        end
    end
    local eventIndex = 0
    local function addEvent(eventId)
        if eventId then
            eventIndex = eventIndex + 1
            EVENT_MANAGER:RegisterForEvent(
                "GravvyBuildPlanner_ChecklistDetection" .. tostring(eventIndex),
                eventId,
                refresh
            )
        end
    end
    addEvent(EVENT_SKILL_POINTS_CHANGED)
    addEvent(EVENT_SKILL_RANK_UPDATE)
    addEvent(EVENT_SKILL_LINE_ADDED)
    addEvent(EVENT_SKILL_LINE_RANK_UPDATE)
    addEvent(EVENT_CHAMPION_POINT_GAINED)
    addEvent(EVENT_CHAMPION_PURCHASE_RESULT)
    addEvent(EVENT_ACTION_SLOT_UPDATED)
    addEvent(EVENT_ACTION_SLOTS_FULL_UPDATE)
    addEvent(EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED)
end

local function descriptor(kind, entry, detail, targetRank, extra)
    local detection = { kind = kind, id = entry.abilityId or entry.skillId }
    if extra then
        for key, value in pairs(extra) do
            detection[key] = value
        end
    end
    return {
        name = entry.name,
        detail = detail,
        icon = entry.icon or "",
        targetRank = targetRank,
        detection = detection,
    }
end

function Detection:Search(category, text, limit)
    local query = normalize(text)
    local results = {}
    if query == "" then
        return results
    end
    local function add(entry)
        if string.find(normalize(entry.name), query, 1, true) then
            results[#results + 1] = entry
            return #results >= (limit or 6)
        end
        return false
    end
    if category == "passive" then
        for _, entry in ipairs(self.owner.skillCatalog.passiveEntries) do
            if add(descriptor(
                "passive",
                entry,
                entry.skillLine,
                entry.maxRank,
                { skillType = entry.skillType, skillLineIndex = entry.skillLineIndex }
            )) then break end
        end
    elseif category == "skillLine" then
        for _, entry in ipairs(self.owner.skillCatalog.skillLines) do
            if add({
                name = entry.name,
                detail = GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SOURCE_SKILL_LINE),
                icon = "",
                detection = {
                    kind = "skillLine",
                    skillType = entry.skillType,
                    skillLineIndex = entry.skillLineIndex,
                },
            }) then break end
        end
    elseif category == "unlock" then
        for _, entry in ipairs(self.owner.skillCatalog.entries) do
            if add(descriptor(
                "ability",
                entry,
                entry.skillLine,
                nil,
                { skillType = entry.skillType, skillLineIndex = entry.skillLineIndex }
            )) then return results end
        end
        for _, entry in ipairs(self.owner.championCatalog.entries) do
            if string.find(normalize(entry.name), query, 1, true) then
                local allocation = descriptor(
                    "champion",
                    entry,
                    GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SOURCE_CHAMPION),
                    entry.maxPoints,
                    { id = entry.skillId }
                )
                results[#results + 1] = allocation
                if #results >= (limit or 6) then return results end
                if entry.isSlottable then
                    local slotted = descriptor(
                        "championSlotted",
                        entry,
                        GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SOURCE_CHAMPION_SLOTTED),
                        entry.maxPoints,
                        { id = entry.skillId }
                    )
                    slotted.name = entry.name .. " · "
                        .. GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SLOTTED)
                    results[#results + 1] = slotted
                    if #results >= (limit or 6) then return results end
                end
            end
        end
        for _, entry in ipairs(self.research) do
            if add(entry) then break end
        end
    end
    return results
end

function Detection:Resolve(category, name)
    local wanted = normalize(name)
    if wanted == "" then return nil end
    if category == "passive" then
        local entry = self.owner.skillCatalog:FindPassiveExact(name)
        if entry then
            return descriptor(
                "passive",
                entry,
                entry.skillLine,
                entry.maxRank,
                { skillType = entry.skillType, skillLineIndex = entry.skillLineIndex }
            )
        end
    elseif category == "skillLine" then
        local entry = self.owner.skillCatalog:FindSkillLineExact(name)
        if entry then
            return {
                name = entry.name,
                detail = GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SOURCE_SKILL_LINE),
                icon = "",
                detection = {
                    kind = "skillLine",
                    skillType = entry.skillType,
                    skillLineIndex = entry.skillLineIndex,
                },
            }
        end
    elseif category == "unlock" then
        local ability = self.owner.skillCatalog:FindExact(name)
        if ability then
            return descriptor(
                "ability",
                ability,
                ability.skillLine,
                nil,
                { skillType = ability.skillType, skillLineIndex = ability.skillLineIndex }
            )
        end
        local champion = self.owner.championCatalog:FindExactAny(name)
        if champion then
            return descriptor(
                "champion",
                champion,
                GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SOURCE_CHAMPION),
                champion.maxPoints,
                { id = champion.skillId }
            )
        end
        local research = self.researchByName[wanted]
        if research then return research end
        local suffix = " · " .. normalize(GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SLOTTED))
        if string.sub(wanted, -#suffix) == suffix then
            local baseName = string.sub(name, 1, #name - #suffix)
            champion = self.owner.championCatalog:FindExactAny(baseName)
            if champion and champion.isSlottable then
                local result = descriptor(
                    "championSlotted",
                    champion,
                    GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SOURCE_CHAMPION_SLOTTED),
                    champion.maxPoints,
                    { id = champion.skillId }
                )
                result.name = champion.name .. " · "
                    .. GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SLOTTED)
                return result
            end
        end
    end
    local matches = self:Search(category, name, 20)
    for _, entry in ipairs(matches) do
        if normalize(entry.name) == wanted then
            return entry
        end
    end
end

function Detection:IsChampionSlotted(skillId)
    if not GetSlotBoundId or not GetAssignableChampionBarStartAndEndSlots
        or not HOTBAR_CATEGORY_CHAMPION then
        return false
    end
    local first, last = GetAssignableChampionBarStartAndEndSlots()
    if not first or not last then return false end
    for slotIndex = first, last do
        if GetSlotBoundId(slotIndex, HOTBAR_CATEGORY_CHAMPION) == skillId then
            return true
        end
    end
    return false
end

function Detection:Evaluate(entry)
    local detection = entry and entry.detection
    if not detection and entry and entry.category == "passive" and entry.abilityId then
        detection = { kind = "passive", id = entry.abilityId }
    end
    if not detection then
        return { automatic = false, complete = entry and entry.completed == true }
    end
    local kind = detection.kind
    local current = 0
    local target = tonumber(entry.targetRank) or 1
    if kind == "passive" then
        local catalogEntry = self.owner.skillCatalog:FindPassiveById(detection.id or entry.abilityId)
        if not catalogEntry or not catalogEntry.skill or not catalogEntry.skill.GetCurrentRank then
            return { automatic = false, complete = entry.completed == true }
        end
        current = catalogEntry.skill:GetCurrentRank() or 0
    elseif kind == "skillLine" then
        local catalogEntry = self.owner.skillCatalog:FindSkillLine(
            detection.skillType,
            detection.skillLineIndex
        )
        if not catalogEntry or not catalogEntry.skillLine.GetCurrentRank then
            return { automatic = false, complete = entry.completed == true }
        end
        current = catalogEntry.skillLine:GetCurrentRank() or 0
    elseif kind == "ability" then
        local catalogEntry = self.owner.skillCatalog:FindById(detection.id)
        if not catalogEntry or not catalogEntry.skill then
            return { automatic = false, complete = entry.completed == true }
        end
        local points = catalogEntry.skill.GetNumPointsAllocated
            and catalogEntry.skill:GetNumPointsAllocated() or 0
        local activeId = currentAbilityId(catalogEntry.skill)
        local baseMorph = MORPH_SLOT_BASE or 0
        current = points > 0 and (catalogEntry.morphSlot == baseMorph
            or activeId == catalogEntry.abilityId) and 1 or 0
        target = 1
    elseif kind == "champion" or kind == "championSlotted" then
        local catalogEntry = self.owner.championCatalog:FindById(detection.id)
        if not catalogEntry or not catalogEntry.skillData
            or not catalogEntry.skillData.GetNumSavedPoints then
            return { automatic = false, complete = entry.completed == true }
        end
        current = catalogEntry.skillData:GetNumSavedPoints() or 0
        if kind == "championSlotted" and not self:IsChampionSlotted(detection.id) then
            return { automatic = true, complete = false, current = current, target = target, slotted = false }
        end
    elseif kind == "trait" then
        if not GetSmithingResearchLineTraitInfo then
            return { automatic = false, complete = entry.completed == true }
        end
        local _, _, known = GetSmithingResearchLineTraitInfo(
            detection.craftingType,
            detection.researchLineIndex,
            detection.traitIndex
        )
        return { automatic = true, complete = known == true, known = known == true }
    else
        return { automatic = false, complete = entry.completed == true }
    end
    return {
        automatic = true,
        complete = current >= target,
        current = current,
        target = target,
        slotted = kind == "championSlotted" and true or nil,
    }
end

function Detection:StatusText(result)
    if not result or not result.automatic then
        return GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_MANUAL)
    end
    if result.known ~= nil then
        return GetString(result.known
            and SI_GRAVVY_BUILD_PLANNER_CHECKLIST_DETECTED_COMPLETE
            or SI_GRAVVY_BUILD_PLANNER_CHECKLIST_DETECTED_INCOMPLETE)
    end
    local text = zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CHECKLIST_DETECTED_PROGRESS,
        result.current or 0,
        result.target or 1
    )
    if result.slotted == false then
        text = text .. " · " .. GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_NOT_SLOTTED)
    elseif result.slotted == true then
        text = text .. " · " .. GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SLOTTED)
    end
    return text
end
