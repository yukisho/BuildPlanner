GravvyBuildPlannerWalkthrough = {}

local Walkthrough = GravvyBuildPlannerWalkthrough

local function add(
    steps,
    phase,
    title,
    planned,
    current,
    instruction,
    complete,
    action,
    value,
    actionLabel
)
    steps[#steps + 1] = {
        phase = phase,
        title = title,
        planned = planned,
        current = current,
        instruction = instruction,
        complete = complete == true,
        action = action,
        value = value,
        actionLabel = actionLabel,
    }
end

local function requirementSummary(requirement, setup)
    local name = requirement.itemName ~= "" and requirement.itemName
        or requirement.setName
    if not name or name == "" then
        name = GetString(SI_GRAVVY_BUILD_PLANNER_INCOMPLETE)
    end
    local parts = { name }
    if requirement.armorType and requirement.armorType ~= ARMORTYPE_NONE then
        parts[#parts + 1] = GetString("SI_ARMORTYPE", requirement.armorType)
    elseif requirement.weaponType and requirement.weaponType ~= WEAPONTYPE_NONE then
        parts[#parts + 1] = GetString("SI_WEAPONTYPE", requirement.weaponType)
    end
    if requirement.traitType and requirement.traitType ~= ITEM_TRAIT_TYPE_NONE then
        parts[#parts + 1] = GetString("SI_ITEMTRAITTYPE", requirement.traitType)
    end
    local enchantment = requirement.enchantmentName
    if (not enchantment or enchantment == "") and requirement.enchantmentCategory then
        enchantment = GravvyBuildPlannerEnchantments:GetName(
            requirement.enchantmentCategory
        )
    end
    if enchantment and enchantment ~= "" then parts[#parts + 1] = enchantment end
    local quality = requirement.quality or setup.defaultQuality
    if quality then parts[#parts + 1] = GetString("SI_ITEMQUALITY", quality) end
    local championPoints = requirement.championPoints
    if championPoints == nil then championPoints = setup.defaultChampionPoints end
    if championPoints and championPoints > 0 then
        parts[#parts + 1] = "CP " .. tostring(championPoints)
    else
        parts[#parts + 1] = GetString(SI_GRAVVY_BUILD_PLANNER_LEVEL) .. " "
            .. tostring(requirement.level or setup.defaultLevel)
    end
    return table.concat(parts, " · ")
end

local routeActionIds = {
    buy = SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_BUY,
    craft = SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_CRAFT,
    farm = SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_FARM,
    reconstruct = SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_RECONSTRUCT,
    transmute = SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_TRANSMUTE,
    unknown = SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_FIND,
}

local function gearCurrent(entry)
    if entry.status == "ready" then
        return zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_CURRENT_READY,
            entry.location
        )
    elseif entry.status == "adjustable" then
        return zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_CURRENT_ADJUSTABLE,
            entry.location
        )
    elseif entry.status == "conflicting" then
        return GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_CURRENT_CONFLICT)
    end
    return GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_CURRENT_MISSING)
end

local function gearInstruction(entry, setup)
    local instructions = {}
    local requirement = entry.requirement or {}
    if entry.status == "ready" then
        instructions[1] = GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_READY)
    elseif entry.status == "conflicting" then
        instructions[1] = GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_CONFLICT)
    elseif entry.status == "missing" then
        instructions[1] = GetString(
            routeActionIds[entry.route]
                or SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_FIND
        )
    else
        for _, difference in ipairs(entry.differences or {}) do
            if difference == "trait" and requirement.traitType then
                instructions[#instructions + 1] = zo_strformat(
                    SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_TRAIT,
                    GetString("SI_ITEMTRAITTYPE", requirement.traitType)
                )
            elseif difference == "enchantment" then
                local enchantment = requirement.enchantmentName
                    or GravvyBuildPlannerEnchantments:GetName(
                        requirement.enchantmentCategory
                    )
                instructions[#instructions + 1] = zo_strformat(
                    SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_ENCHANT,
                    enchantment or GetString(SI_GRAVVY_BUILD_PLANNER_ENCHANTMENT)
                )
            elseif difference == "quality" then
                instructions[#instructions + 1] = zo_strformat(
                    SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_QUALITY,
                    GetString("SI_ITEMQUALITY", requirement.quality
                        or setup.defaultQuality)
                )
            end
        end
        if #instructions == 0 then
            instructions[1] = GetString(
                SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_REVIEW_GEAR
            )
        end
    end
    if #(entry.sharedUses or {}) > 0 then
        instructions[#instructions + 1] = zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_SHARED,
            #entry.sharedUses
        )
    end
    return table.concat(instructions, " ")
end

local function joinLimited(values)
    local shown = {}
    for index = 1, math.min(6, #values) do shown[index] = values[index] end
    if #values > #shown then
        shown[#shown + 1] = zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_MORE,
            #values - #shown
        )
    end
    return table.concat(shown, " · ")
end

local function liveSkillMatches(planned, bar)
    if not GetSlotBoundId then return 0, 0 end
    local first = GetAssignableAbilityBarStartAndEndSlots
        and GetAssignableAbilityBarStartAndEndSlots()
        or ACTION_BAR_FIRST_NORMAL_SLOT_INDEX or 3
    local category = bar == "back" and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    local plannedCount, matched = 0, 0
    for slotIndex = 1, 6 do
        local skill = planned[slotIndex]
        if skill then
            plannedCount = plannedCount + 1
            if category and GetSlotBoundId(first + slotIndex - 1, category) == skill.abilityId then
                matched = matched + 1
            end
        end
    end
    return matched, plannedCount
end

function Walkthrough:New(owner)
    return setmetatable({ owner = owner }, { __index = self })
end

function Walkthrough:Build(setup)
    local steps = {}
    local gearPhase = GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_GEAR)
    local readiness = self.owner.readiness:BuildReport(setup)
    for _, entry in ipairs(readiness.entries) do
        add(
            steps,
            gearPhase,
            zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_PREPARE_SLOT,
                entry.slot
            ),
            requirementSummary(entry.requirement, setup),
            gearCurrent(entry),
            gearInstruction(entry, setup),
            entry.status == "ready",
            "readiness",
            entry.slotKey,
            SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_OPEN_GEAR
        )
    end

    local hasAssumptions = GravvyBuildPlannerBuffAssumptions:HasAny(setup)
    add(
        steps,
        GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ASSUMPTIONS),
        GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ASSUMPTIONS_TITLE),
        GravvyBuildPlannerBuffAssumptions:Format(setup),
        GetString(hasAssumptions
            and SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_CURRENT_ASSUMPTIONS
            or SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_CURRENT_NO_ASSUMPTIONS),
        GetString(hasAssumptions
            and SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_ASSUMPTIONS_READY
            or SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_ASSUMPTIONS),
        hasAssumptions,
        "assumptions",
        nil,
        SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_OPEN_ASSUMPTIONS
    )

    for _, bar in ipairs({ "front", "back" }) do
        local matched, planned = liveSkillMatches(setup.skillBars[bar] or {}, bar)
        local plannedSkills = {}
        for slotIndex = 1, 6 do
            local skill = setup.skillBars[bar] and setup.skillBars[bar][slotIndex]
            if skill then
                plannedSkills[#plannedSkills + 1] = tostring(slotIndex) .. ". " .. skill.name
            end
        end
        local complete = planned > 0 and matched == planned
        add(
            steps,
            GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_SKILLS),
            zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_SKILLS_TITLE,
                GetString(bar == "back" and SI_GRAVVY_BUILD_PLANNER_BACK_BAR
                    or SI_GRAVVY_BUILD_PLANNER_FRONT_BAR)
            ),
            #plannedSkills > 0 and joinLimited(plannedSkills)
                or GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_SKILLS_NOT_PLANNED),
            zo_strformat(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_SKILL_PROGRESS,
                matched, planned),
            GetString(complete
                and SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_SKILLS_READY
                or planned > 0
                    and SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_SKILLS_EQUIP
                    or SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_SKILLS_PLAN),
            complete,
            "skills",
            bar,
            SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_OPEN_SKILLS
        )
    end

    local championPlanned, championReady = 0, 0
    local championSlotted, championSlotsReady = 0, 0
    local championEntries = {}
    for _, disciplineKey in ipairs({ "craft", "warfare", "fitness" }) do
        local discipline = setup.champion[disciplineKey]
        local slotted = {}
        for _, skillId in ipairs(discipline.slottables or {}) do
            if skillId and skillId > 0 then slotted[skillId] = true end
        end
        for _, allocation in ipairs(discipline.allocations or {}) do
            championPlanned = championPlanned + 1
            championEntries[#championEntries + 1] = allocation.name .. " "
                .. tostring(allocation.points)
                .. (slotted[allocation.skillId]
                    and " (" .. GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SLOTTED)
                        .. ")" or "")
            local catalog = self.owner.championCatalog:FindById(allocation.skillId)
            local current = catalog and catalog.skillData and catalog.skillData.GetNumSavedPoints
                and catalog.skillData:GetNumSavedPoints() or 0
            if current >= allocation.points then championReady = championReady + 1 end
            if slotted[allocation.skillId] then
                championSlotted = championSlotted + 1
                if self.owner.checklistDetection:IsChampionSlotted(allocation.skillId) then
                    championSlotsReady = championSlotsReady + 1
                end
            end
        end
    end
    local championComplete = championPlanned > 0
        and championReady == championPlanned
        and championSlotsReady == championSlotted
    add(
        steps,
        GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_PROGRESSION),
        GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_CHAMPION_TITLE),
        #championEntries > 0 and joinLimited(championEntries)
            or GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_CHAMPION_NOT_PLANNED),
        zo_strformat(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_CHAMPION_PROGRESS,
            championReady, championPlanned, championSlotsReady, championSlotted),
        GetString(championComplete
            and SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_CHAMPION_READY
            or championPlanned > 0
                and SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_CHAMPION
                or SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_CHAMPION_PLAN),
        championComplete,
        "champion",
        nil,
        SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_OPEN_CHAMPION
    )

    for index, entry in ipairs(setup.checklist or {}) do
        local result = self.owner.checklistDetection:Evaluate(entry)
        local planned = {}
        if entry.targetRank then
            planned[#planned + 1] = zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_CHECKLIST_RANK_VALUE,
                entry.targetRank
            )
        end
        if entry.note and entry.note ~= "" then planned[#planned + 1] = entry.note end
        if #planned == 0 then
            planned[1] = GetString(
                SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_CHECKLIST_REQUIREMENT
            )
        end
        local current = result.automatic
            and self.owner.checklistDetection:StatusText(result)
            or GetString(entry.completed
                and SI_GRAVVY_BUILD_PLANNER_CHECKLIST_COMPLETE
                or SI_GRAVVY_BUILD_PLANNER_CHECKLIST_INCOMPLETE)
        add(
            steps,
            GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_PROGRESSION),
            zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_CHECKLIST_TITLE,
                entry.name
            ),
            table.concat(planned, " · "),
            current,
            GetString(result.complete
                and SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_CHECKLIST_READY
                or SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_CHECKLIST),
            result.complete,
            "checklist",
            index,
            SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_OPEN_CHECKLIST
        )
    end

    for _, bar in ipairs({ "front", "back" }) do
        local status, statusId = self.owner.statImpact:GetCaptureStatus(setup, bar, "general")
        local barName = GetString(bar == "back" and SI_GRAVVY_BUILD_PLANNER_BACK_BAR
            or SI_GRAVVY_BUILD_PLANNER_FRONT_BAR)
        add(
            steps,
            GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_CAPTURE),
            zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_CAPTURE_TITLE,
                barName
            ),
            zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_CAPTURE_PLANNED,
                barName
            ),
            GetString(statusId),
            GetString(status == "current"
                and SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_CAPTURE_READY
                or SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_ACTION_CAPTURE),
            status == "current",
            "statImpact",
            bar,
            SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_OPEN_CAPTURE
        )
    end

    local complete = 0
    local phaseTotals = {}
    for _, step in ipairs(steps) do
        if step.complete then complete = complete + 1 end
        local phase = phaseTotals[step.phase]
        if not phase then
            phase = { complete = 0, total = 0 }
            phaseTotals[step.phase] = phase
        end
        phase.total = phase.total + 1
        if step.complete then phase.complete = phase.complete + 1 end
    end
    for _, step in ipairs(steps) do
        local phase = phaseTotals[step.phase]
        step.phaseProgress = zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_PHASE_PROGRESS,
            step.phase,
            phase.complete,
            phase.total
        )
    end
    return { setup = setup, steps = steps, complete = complete, total = #steps }
end
