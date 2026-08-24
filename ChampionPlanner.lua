local UI = GravvyBuildPlannerUI
local ROW_COUNT = 9
local EMPTY_STAR_TEXTURE = "EsoUI/Art/Champion/Stars/slottable.dds"

local disciplineStringIds = {
    craft = SI_GRAVVY_BUILD_PLANNER_CHAMPION_CRAFT,
    warfare = SI_GRAVVY_BUILD_PLANNER_CHAMPION_WARFARE,
    fitness = SI_GRAVVY_BUILD_PLANNER_CHAMPION_FITNESS,
}

local function makeLabel(parent, text, x, y, width, font)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    GravvyBuildPlannerAccessibility:SetFont(label, font or "ZoFontGame")
    label:SetColor(0.88, 0.86, 0.8, 1)
    label:SetText(text or "")
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    label:SetDimensions(width or 120, 30)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return label
end

local function makeButton(parent, text, width)
    local button = WINDOW_MANAGER:CreateControl(nil, parent, CT_BUTTON)
    button:SetDimensions(width, 28)
    GravvyBuildPlannerAccessibility:SetFont(button, "ZoFontGame")
    button:SetText(text)
    button:SetNormalFontColor(0.85, 0.78, 0.62, 1)
    button:SetMouseOverFontColor(1, 1, 1, 1)
    button:SetPressedFontColor(0.65, 0.55, 0.35, 1)
    return button
end

local function makeEdit(parent, name, x, y, width, numeric, maxChars)
    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(name .. "Backdrop", parent, "ZO_EditBackdrop")
    backdrop:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    backdrop:SetDimensions(width, 30)
    local edit = WINDOW_MANAGER:CreateControlFromVirtual(name, backdrop, "ZO_DefaultEditForBackdrop")
    edit:ClearAnchors()
    edit:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 3, 2)
    edit:SetAnchor(BOTTOMRIGHT, backdrop, BOTTOMRIGHT, -3, -2)
    GravvyBuildPlannerAccessibility:SetFont(edit, "ZoFontGame")
    edit:SetMaxInputChars(maxChars or 100)
    edit:SetNewLineEnabled(false)
    edit:SetSelectAllOnFocus(true)
    if numeric then
        edit:SetTextType(TEXT_TYPE_NUMERIC)
    end
    return edit
end

local function makeCombo(parent, name, x, y, width)
    local container = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_ComboBox")
    container:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    container:SetDimensions(width, 30)
    local combo = ZO_ComboBox_ObjectFromContainer(container)
    combo:SetSortsItems(false)
    return combo, container
end

local function setComboChoices(combo, choices, selectedValue)
    combo:ClearItems()
    combo.selectedValue = selectedValue
    local selectedLabel
    for _, choice in ipairs(choices) do
        local value = choice.value
        combo:AddItem(combo:CreateItemEntry(choice.label, function()
            combo.selectedValue = value
        end))
        if value == selectedValue then
            selectedLabel = choice.label
        end
    end
    combo:SetSelectedItem(selectedLabel or choices[1].label)
end

local function findAllocation(discipline, skillId)
    for index, allocation in ipairs(discipline.allocations) do
        if allocation.skillId == skillId then
            return allocation, index
        end
    end
end

function UI:CreateChampionPlanner()
    local panel = WINDOW_MANAGER:CreateControl("GravvyBuildPlannerChampion", self.window, CT_CONTROL)
    panel:SetAnchor(TOPLEFT, self.window, TOPLEFT, 18, 137)
    panel:SetDimensions(942, 530)
    panel:SetHidden(true)
    self.championPanel = panel
    self.championDiscipline = "warfare"
    self.championOffset = 0

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, panel, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(panel)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.018, 0.018, 0.026, 0.9 },
        { 0.28, 0.24, 0.18, 0.85 }
    )

    self.championDisciplineButtons = {}
    for index, key in ipairs({ "craft", "warfare", "fitness" }) do
        local button = makeButton(panel, GetString(disciplineStringIds[key]), 145)
        button:SetAnchor(TOPLEFT, panel, TOPLEFT, 22 + ((index - 1) * 152), 16)
        button:SetHandler("OnClicked", function() self:SetChampionDiscipline(key) end)
        self.championDisciplineButtons[key] = button
    end

    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_SLOTTABLES), 22, 52, 440, "ZoFontWinH3")
    self.championSlotButtons = {}
    for slotIndex = 1, 4 do
        local button = WINDOW_MANAGER:CreateControl(nil, panel, CT_BUTTON)
        button:SetDimensions(104, 70)
        button:SetAnchor(TOPLEFT, panel, TOPLEFT, 22 + ((slotIndex - 1) * 111), 87)
        local edge = WINDOW_MANAGER:CreateControlFromVirtual(nil, button, "ZO_DefaultBackdrop")
        edge:SetAnchorFill(button)
        edge:SetCenterColor(0.025, 0.025, 0.035, 0.96)
        local icon = WINDOW_MANAGER:CreateControl(nil, button, CT_TEXTURE)
        icon:SetDimensions(42, 42)
        icon:SetAnchor(TOPLEFT, button, TOPLEFT, 5, 5)
        local name = makeLabel(button, "", 50, 3, 50, "ZoFontGameSmall")
        name:SetHeight(58)
        name:SetVerticalAlignment(TEXT_ALIGN_TOP)
        local number = makeLabel(button, tostring(slotIndex), 6, 46, 32, "ZoFontGameSmall")
        button.icon = icon
        button.nameLabel = name
        button.numberLabel = number
        button:SetHandler("OnClicked", function() self:SelectChampionSlot(slotIndex) end)
        button:SetHandler("OnMouseEnter", function(control)
            self:ShowChampionTooltip(control, control.skillId)
        end)
        button:SetHandler("OnMouseExit", function() self:HideChampionTooltip() end)
        self.championSlotButtons[slotIndex] = button
    end

    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_ALLOCATIONS), 22, 163, 440, "ZoFontWinH3")
    local add = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_ADD), 170)
    add:SetAnchor(TOPLEFT, panel, TOPLEFT, 292, 164)
    add:SetHandler("OnClicked", function()
        self.selectedChampionSkillId = nil
        self:LoadChampionEditor()
    end)
    self.championRows = {}
    for rowIndex = 1, ROW_COUNT do
        local row = makeButton(panel, "", 438)
        row:SetHeight(30)
        row:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        row:SetAnchor(TOPLEFT, panel, TOPLEFT, 24, 196 + ((rowIndex - 1) * 31))
        row:SetHandler("OnClicked", function() self:SelectChampionRow(rowIndex) end)
        row:SetHandler("OnMouseEnter", function(control)
            self:ShowChampionTooltip(control, control.skillId)
        end)
        row:SetHandler("OnMouseExit", function() self:HideChampionTooltip() end)
        self.championRows[rowIndex] = row
    end
    local previous = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_PREVIOUS), 100)
    previous:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 24, -14)
    previous:SetHandler("OnClicked", function() self:PageChampionAllocations(-1) end)
    local nextPage = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_NEXT), 100)
    nextPage:SetAnchor(LEFT, previous, RIGHT, 8, 0)
    nextPage:SetHandler("OnClicked", function() self:PageChampionAllocations(1) end)
    self.championPageLabel = makeLabel(panel, "", 244, 486, 218, "ZoFontGameSmall")
    self.championPageLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    local divider = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
    divider:SetAnchor(TOPLEFT, panel, TOPLEFT, 484, 18)
    divider:SetDimensions(1, 494)
    divider:SetColor(0.5, 0.42, 0.28, 0.7)

    self.championEditorTitle = makeLabel(panel, "", 514, 22, 400, "ZoFontWinH3")
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_STAR), 514, 66, 110)
    self.championStarEdit = makeEdit(panel, "GravvyBuildPlannerChampionStar", 514, 98, 395, false, 100)
    self.championStarEdit:SetHandler("OnTextChanged", function() self:OnChampionTextChanged() end)
    self.championStarEdit:SetHandler("OnKeyDown", function(_, key) self:OnChampionKeyDown(key) end)
    self.championStarEdit:SetHandler("OnFocusLost", function() self:ResolveChampionStar() end)
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_POINTS), 514, 144, 100)
    self.championPointsEdit = makeEdit(panel, "GravvyBuildPlannerChampionPoints", 620, 144, 90, true, 4)
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_SLOT), 514, 188, 100)
    self.championSlotCombo, self.championSlotContainer = makeCombo(
        panel,
        "GravvyBuildPlannerChampionSlotCombo",
        620,
        188,
        289
    )
    self.championPreview = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
    self.championPreview:SetDimensions(64, 64)
    self.championPreview:SetAnchor(TOPLEFT, panel, TOPLEFT, 514, 242)
    self.championPreviewName = makeLabel(panel, "", 592, 250, 317, "ZoFontGame")
    self.championPreviewDetail = makeLabel(panel, "", 592, 278, 317, "ZoFontGameSmall")

    local remove = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_REMOVE), 150)
    remove:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -180, -20)
    remove:SetHandler("OnClicked", function() self:RemoveChampionAllocation() end)
    local save = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_SAVE), 150)
    save:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -20, -20)
    save:SetHandler("OnClicked", function() self:SaveChampionAllocation() end)

    local suggestions = WINDOW_MANAGER:CreateControl(nil, panel, CT_CONTROL)
    suggestions:SetDimensions(395, 152)
    suggestions:SetAnchor(TOPLEFT, self.championStarEdit, BOTTOMLEFT, 0, 2)
    suggestions:SetHidden(true)
    suggestions:SetDrawTier(DT_HIGH)
    self.championSuggestionPanel = suggestions
    local suggestionBackdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, suggestions, "ZO_DefaultBackdrop")
    suggestionBackdrop:SetAnchorFill(suggestions)
    self.championSuggestionButtons = {}
    for index = 1, 6 do
        local button = makeButton(suggestions, "", 385)
        button:SetHeight(24)
        button:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        button:SetAnchor(TOPLEFT, suggestions, TOPLEFT, 5, 4 + ((index - 1) * 24))
        button:SetHandler("OnClicked", function() self:ChooseChampionSuggestion(index) end)
        self.championSuggestionButtons[index] = button
    end
end

function UI:SetChampionDiscipline(key)
    self.championDiscipline = key
    self.championOffset = 0
    self.selectedChampionSkillId = nil
    self:RefreshChampionPlanner()
end

function UI:GetChampionDiscipline()
    local setup = self.owner.data:GetCurrentSetup()
    return setup.champion[self.championDiscipline]
end

function UI:RefreshChampionPlanner()
    if not self.championPanel then
        return
    end
    local discipline = self:GetChampionDiscipline()
    for key, button in pairs(self.championDisciplineButtons) do
        button:SetAlpha(key == self.championDiscipline and 1 or 0.65)
    end
    for slotIndex = 1, 4 do
        local button = self.championSlotButtons[slotIndex]
        local skillId = discipline.slottables[slotIndex]
        local allocation = skillId and skillId > 0 and findAllocation(discipline, skillId)
        local catalogEntry = allocation and self.owner.championCatalog:FindById(allocation.skillId)
        button.skillId = allocation and allocation.skillId
        local icon = catalogEntry and catalogEntry.icon or allocation and allocation.icon
        button.icon:SetTexture(icon and icon ~= "" and icon or EMPTY_STAR_TEXTURE)
        button.nameLabel:SetText(catalogEntry and catalogEntry.name
            or allocation and allocation.name
            or GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED))
    end
    self.championOffset = zo_clamp(
        self.championOffset,
        0,
        math.max(0, #discipline.allocations - ROW_COUNT)
    )
    for rowIndex = 1, ROW_COUNT do
        local row = self.championRows[rowIndex]
        local allocation = discipline.allocations[self.championOffset + rowIndex]
        local catalogEntry = allocation and self.owner.championCatalog:FindById(allocation.skillId)
        row.skillId = allocation and allocation.skillId
        row:SetHidden(not allocation)
        row:SetText(allocation and zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_CHAMPION_ALLOCATION,
            catalogEntry and catalogEntry.name or allocation.name,
            allocation.points
        ) or "")
    end
    local first = #discipline.allocations == 0 and 0 or self.championOffset + 1
    local last = math.min(#discipline.allocations, self.championOffset + ROW_COUNT)
    self.championPageLabel:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CHAMPION_PAGE,
        first,
        last,
        #discipline.allocations
    ))
    self:LoadChampionEditor()
end

function UI:PageChampionAllocations(direction)
    local discipline = self:GetChampionDiscipline()
    self.championOffset = zo_clamp(
        self.championOffset + (direction * ROW_COUNT),
        0,
        math.max(0, #discipline.allocations - ROW_COUNT)
    )
    self:RefreshChampionPlanner()
end

function UI:SelectChampionRow(rowIndex)
    local allocation = self:GetChampionDiscipline().allocations[self.championOffset + rowIndex]
    self.selectedChampionSkillId = allocation and allocation.skillId
    self:LoadChampionEditor()
end

function UI:SelectChampionSlot(slotIndex)
    local skillId = self:GetChampionDiscipline().slottables[slotIndex]
    self.selectedChampionSkillId = skillId and skillId > 0 and skillId or nil
    self:LoadChampionEditor()
end

function UI:LoadChampionEditor()
    local discipline = self:GetChampionDiscipline()
    local allocation = self.selectedChampionSkillId
        and findAllocation(discipline, self.selectedChampionSkillId)
    local catalogEntry = allocation and self.owner.championCatalog:FindById(allocation.skillId)
    self.loadingChampion = true
    self.selectedChampionEntry = catalogEntry
    self.championEditorTitle:SetText(GetString(disciplineStringIds[self.championDiscipline]))
    self.championStarEdit:SetText(catalogEntry and catalogEntry.name or allocation and allocation.name or "")
    self.championPointsEdit:SetText(allocation and tostring(allocation.points) or "")
    local selectedSlot = 0
    if allocation then
        for slotIndex = 1, 4 do
            if discipline.slottables[slotIndex] == allocation.skillId then
                selectedSlot = slotIndex
                break
            end
        end
    end
    local choices = {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_NOT_SLOTTED), value = 0 },
    }
    for slotIndex = 1, 4 do
        choices[#choices + 1] = {
            label = zo_strformat(SI_GRAVVY_BUILD_PLANNER_CHAMPION_SLOT_NUMBER, slotIndex),
            value = slotIndex,
        }
    end
    setComboChoices(self.championSlotCombo, choices, selectedSlot)
    self.championSlotContainer:SetHidden(not (allocation and allocation.isSlottable)
        and not (catalogEntry and catalogEntry.isSlottable))
    local icon = catalogEntry and catalogEntry.icon or allocation and allocation.icon
    self.championPreview:SetTexture(icon and icon ~= "" and icon or EMPTY_STAR_TEXTURE)
    self.championPreviewName:SetText(catalogEntry and catalogEntry.name
        or allocation and allocation.name
        or GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED))
    self.championPreviewDetail:SetText(allocation and zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CHAMPION_POINTS_ASSIGNED,
        allocation.points
    ) or "")
    self.championSuggestionPanel:SetHidden(true)
    self.loadingChampion = false
end

function UI:OnChampionTextChanged()
    if self.loadingChampion then
        return
    end
    self.selectedChampionEntry = nil
    local results = self.owner.championCatalog:Search(
        self.championStarEdit:GetText(),
        self.championDiscipline,
        false,
        6
    )
    self.championSuggestionData = results
    self.championSuggestionIndex = 1
    self.championSuggestionPanel:SetHidden(#results == 0)
    for index, button in ipairs(self.championSuggestionButtons) do
        button:SetHidden(not results[index])
        button:SetText(results[index] and results[index].name or "")
    end
end

function UI:ChooseChampionSuggestion(index)
    local entry = self.championSuggestionData and self.championSuggestionData[index]
    if not entry then
        return
    end
    self.selectedChampionEntry = entry
    self.loadingChampion = true
    self.championStarEdit:SetText(entry.name)
    self.loadingChampion = false
    self.championSuggestionPanel:SetHidden(true)
    self.championPreview:SetTexture(entry.icon ~= "" and entry.icon or EMPTY_STAR_TEXTURE)
    self.championPreviewName:SetText(entry.name)
    self.championPointsEdit:SetText(tostring(entry.maxPoints))
    self.championSlotContainer:SetHidden(not entry.isSlottable)
end

function UI:ResolveChampionStar()
    if self.selectedChampionEntry then
        return self.selectedChampionEntry
    end
    self.selectedChampionEntry = self.owner.championCatalog:FindExact(
        self.championStarEdit:GetText(),
        self.championDiscipline
    )
    return self.selectedChampionEntry
end

function UI:OnChampionKeyDown(key)
    if self.championSuggestionPanel:IsHidden() then
        return
    end
    local count = math.min(6, #(self.championSuggestionData or {}))
    if key == KEY_DOWN then
        self.championSuggestionIndex = math.min(count, self.championSuggestionIndex + 1)
    elseif key == KEY_UP then
        self.championSuggestionIndex = math.max(1, self.championSuggestionIndex - 1)
    elseif key == KEY_ENTER then
        self:ChooseChampionSuggestion(self.championSuggestionIndex)
    elseif key == KEY_ESCAPE then
        self.championSuggestionPanel:SetHidden(true)
    end
end

function UI:SaveChampionAllocation()
    local entry = self:ResolveChampionStar()
    local points = tonumber(self.championPointsEdit:GetText())
    if not entry or not points or points ~= math.floor(points)
        or points < 1 or points > entry.maxPoints then
        self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHAMPION), true)
        return
    end
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, message = self.owner.data:SetChampionAllocation(
        build.id,
        setup.id,
        self.championDiscipline,
        {
            skillId = entry.skillId,
            name = entry.name,
            icon = entry.icon,
            points = points,
            isSlottable = entry.isSlottable,
        }
    )
    if not ok then
        self:SetStatus(message, true)
        return
    end
    local previousSkillId = self.selectedChampionSkillId
    if previousSkillId and previousSkillId ~= entry.skillId then
        self.owner.data:SetChampionAllocation(
            build.id,
            setup.id,
            self.championDiscipline,
            { skillId = previousSkillId, remove = true }
        )
    end
    local discipline = setup.champion[self.championDiscipline]
    for slotIndex = 1, 4 do
        if discipline.slottables[slotIndex] == entry.skillId
            and slotIndex ~= self.championSlotCombo.selectedValue then
            self.owner.data:SetChampionSlottable(
                build.id,
                setup.id,
                self.championDiscipline,
                slotIndex,
                nil
            )
        end
    end
    local wantedSlot = entry.isSlottable and self.championSlotCombo.selectedValue or 0
    if wantedSlot and wantedSlot > 0 then
        ok, message = self.owner.data:SetChampionSlottable(
            build.id,
            setup.id,
            self.championDiscipline,
            wantedSlot,
            entry.skillId
        )
        if not ok then
            self:SetStatus(message, true)
            return
        end
    end
    self.selectedChampionSkillId = entry.skillId
    self:RefreshChampionPlanner()
    self:SetStatus(zo_strformat(SI_GRAVVY_BUILD_PLANNER_CHAMPION_SAVED, entry.name))
end

function UI:RemoveChampionAllocation()
    if not self.selectedChampionSkillId then
        return
    end
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, message = self.owner.data:SetChampionAllocation(
        build.id,
        setup.id,
        self.championDiscipline,
        { skillId = self.selectedChampionSkillId, remove = true }
    )
    if not ok then
        self:SetStatus(message, true)
        return
    end
    self.selectedChampionSkillId = nil
    self:RefreshChampionPlanner()
    self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_REMOVED))
end

function UI:ShowChampionTooltip(control, skillId)
    local entry = skillId and self.owner.championCatalog:FindById(skillId)
    local allocation = skillId and findAllocation(self:GetChampionDiscipline(), skillId)
    if entry and ChampionSkillTooltip and InitializeTooltip then
        InitializeTooltip(ChampionSkillTooltip, control, LEFT, -8, 0, RIGHT)
        local points = allocation and allocation.points or 0
        local nextPoint = entry.skillData and entry.skillData:GetNextJumpPoint(points) or points
        local slotted = false
        local discipline = self:GetChampionDiscipline()
        for slotIndex = 1, 4 do
            if discipline.slottables[slotIndex] == entry.skillId then
                slotted = true
                break
            end
        end
        ChampionSkillTooltip:SetChampionSkill(entry.skillId, points, nextPoint, slotted)
    end
end

function UI:HideChampionTooltip()
    if ChampionSkillTooltip and ClearTooltip then
        ClearTooltip(ChampionSkillTooltip)
    end
end
