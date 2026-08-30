local UI = GravvyBuildPlannerUI
local ROW_COUNT = 10
local EMPTY_TEXTURE = "EsoUI/Art/Skills/skill_typeIcon_class_up.dds"
local COMPLETE_MARKER = "|t16:16:EsoUI/Art/Buttons/accept_up.dds|t"

local categoryStringIds = {
    passive = SI_GRAVVY_BUILD_PLANNER_CHECKLIST_PASSIVE,
    skillLine = SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SKILL_LINE,
    unlock = SI_GRAVVY_BUILD_PLANNER_CHECKLIST_UNLOCK,
    other = SI_GRAVVY_BUILD_PLANNER_CHECKLIST_OTHER,
}

local function makeLabel(parent, text, x, y, width, font)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    GravvyBuildPlannerAccessibility:SetFont(label, font or "ZoFontGame")
    label:SetColor(0.88, 0.86, 0.8, 1)
    label:SetText(text or "")
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    label:SetDimensions(width or 120, 30)
    GravvyBuildPlannerAccessibility:RegisterTextGeometry(label, width or 120, 30)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return label
end

local function makeButton(parent, text, width)
    local button = WINDOW_MANAGER:CreateControl(nil, parent, CT_BUTTON)
    button:SetDimensions(width, 28)
    GravvyBuildPlannerAccessibility:RegisterTextGeometry(button, width, 28)
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

local function makeNoteEdit(parent, name, x, y, width, height)
    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(name .. "Backdrop", parent, "ZO_EditBackdrop")
    backdrop:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    backdrop:SetDimensions(width, height)
    local edit = WINDOW_MANAGER:CreateControlFromVirtual(name, backdrop, "ZO_DefaultEditMultiLineForBackdrop")
    edit:ClearAnchors()
    edit:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 5, 4)
    edit:SetAnchor(BOTTOMRIGHT, backdrop, BOTTOMRIGHT, -5, -4)
    GravvyBuildPlannerAccessibility:SetFont(edit, "ZoFontGame")
    edit:SetMaxInputChars(4000)
    edit:SetNewLineEnabled(true)
    return edit
end

local function makeCombo(parent, name, x, y, width)
    local container = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_ComboBox")
    container:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    container:SetDimensions(width, 30)
    local combo = ZO_ComboBox_ObjectFromContainer(container)
    combo:SetSortsItems(false)
    return combo
end

local function setChoices(combo, choices, selectedValue, changed)
    combo:ClearItems()
    combo.selectedValue = selectedValue
    local selectedLabel
    for _, choice in ipairs(choices) do
        local value = choice.value
        combo:AddItem(combo:CreateItemEntry(choice.label, function()
            combo.selectedValue = value
            if changed then
                changed(value)
            end
        end))
        if value == selectedValue then
            selectedLabel = choice.label
        end
    end
    combo:SetSelectedItem(selectedLabel or choices[1].label)
end

local function categoryChoices()
    local choices = {}
    for _, key in ipairs({ "passive", "skillLine", "unlock", "other" }) do
        choices[#choices + 1] = { label = GetString(categoryStringIds[key]), value = key }
    end
    return choices
end

local function statusChoices()
    return {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_INCOMPLETE), value = false },
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_COMPLETE), value = true },
    }
end

function UI:CreateChecklistPlanner()
    local panel = WINDOW_MANAGER:CreateControl("GravvyBuildPlannerChecklist", self.window, CT_CONTROL)
    panel:SetAnchor(TOPLEFT, self.window, TOPLEFT, 18, self.CONTENT_TOP)
    panel:SetDimensions(942, 530)
    panel:SetHidden(true)
    self.checklistPanel = panel
    self.checklistOffset = 0

    local backdrop = GravvyBuildPlannerUIHelpers:CreateFromVirtual(
        panel,
        "ZO_DefaultBackdrop",
        "ChecklistBackdrop"
    )
    backdrop:SetAnchorFill(panel)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.018, 0.018, 0.026, 0.9 },
        { 0.28, 0.24, 0.18, 0.85 }
    )

    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_REQUIREMENTS), 22, 18, 450, "ZoFontWinH3")
    local add = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_ADD), 150)
    add:SetAnchor(TOPLEFT, panel, TOPLEFT, 312, 20)
    add:SetHandler("OnClicked", function()
        self.selectedChecklistIndex = nil
        self:LoadChecklistEditor()
    end)
    self.checklistRows = {}
    for rowIndex = 1, ROW_COUNT do
        local row = makeButton(panel, "", 438)
        row:SetHeight(36)
        row:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        row:SetAnchor(TOPLEFT, panel, TOPLEFT, 24, 58 + ((rowIndex - 1) * 38))
        row:SetHandler("OnClicked", function() self:SelectChecklistRow(rowIndex) end)
        row:SetHandler("OnMouseEnter", function(control)
            self:ShowChecklistTooltip(control, control.abilityId, control.targetRank)
        end)
        row:SetHandler("OnMouseExit", function() self:HideChecklistTooltip() end)
        self.checklistRows[rowIndex] = row
    end
    local previous = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_PREVIOUS), 100)
    previous:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 24, -14)
    previous:SetHandler("OnClicked", function() self:PageChecklist(-1) end)
    local nextPage = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_NEXT), 100)
    nextPage:SetAnchor(LEFT, previous, RIGHT, 8, 0)
    nextPage:SetHandler("OnClicked", function() self:PageChecklist(1) end)
    self.checklistPageLabel = makeLabel(panel, "", 244, 486, 218, "ZoFontGameSmall")
    self.checklistPageLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    local divider = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
    divider:SetAnchor(TOPLEFT, panel, TOPLEFT, 484, 18)
    divider:SetDimensions(1, 494)
    divider:SetColor(0.5, 0.42, 0.28, 0.7)

    self.checklistEditorTitle = makeLabel(panel, "", 514, 20, 395, "ZoFontWinH3")
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_CATEGORY), 514, 62, 110)
    self.checklistCategoryCombo = makeCombo(panel, "GravvyBuildPlannerChecklistCategory", 630, 62, 279)
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_NAME), 514, 104, 110)
    self.checklistNameEdit = makeEdit(panel, "GravvyBuildPlannerChecklistName", 514, 136, 395, false, 100)
    self.checklistNameEdit:SetHandler("OnTextChanged", function() self:OnChecklistTextChanged() end)
    self.checklistNameEdit:SetHandler("OnKeyDown", function(_, key) self:OnChecklistKeyDown(key) end)
    self.checklistNameEdit:SetHandler("OnFocusLost", function() self:ResolveChecklistPassive() end)
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_TARGET_RANK), 514, 178, 110)
    self.checklistRankEdit = makeEdit(panel, "GravvyBuildPlannerChecklistRank", 630, 178, 90, true, 2)
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_STATUS), 514, 220, 110)
    self.checklistStatusCombo = makeCombo(panel, "GravvyBuildPlannerChecklistStatus", 630, 220, 279)
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_NOTES), 514, 262, 110)
    self.checklistNoteEdit = makeNoteEdit(panel, "GravvyBuildPlannerChecklistNote", 514, 294, 395, 90)

    self.checklistPreview = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
    self.checklistPreview:SetDimensions(52, 52)
    self.checklistPreview:SetAnchor(TOPLEFT, panel, TOPLEFT, 514, 399)
    self.checklistPreview:SetMouseEnabled(true)
    self.checklistPreview:SetHandler("OnMouseEnter", function(control)
        local entry = self.selectedChecklistPassive or self.selectedChecklistEntry
        self:ShowChecklistTooltip(control, entry and entry.abilityId,
            tonumber(self.checklistRankEdit:GetText()) or (entry and entry.targetRank))
    end)
    self.checklistPreview:SetHandler("OnMouseExit", function() self:HideChecklistTooltip() end)
    self.checklistPreviewName = makeLabel(panel, "", 578, 406, 331, "ZoFontGame")

    local toggle = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_MARK_COMPLETE), 170)
    toggle:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 514, -20)
    toggle:SetHandler("OnClicked", function() self:ToggleChecklistCompleted() end)
    self.checklistToggleButton = toggle
    local remove = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_REMOVE), 110)
    remove:SetAnchor(LEFT, toggle, RIGHT, 4, 0)
    remove:SetHandler("OnClicked", function() self:RemoveChecklistEntry() end)
    local save = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SAVE), 110)
    save:SetAnchor(LEFT, remove, RIGHT, 4, 0)
    save:SetHandler("OnClicked", function() self:SaveChecklistEntry() end)

    local suggestions = WINDOW_MANAGER:CreateControl(nil, panel, CT_CONTROL)
    suggestions:SetDimensions(395, 152)
    suggestions:SetAnchor(TOPLEFT, self.checklistNameEdit, BOTTOMLEFT, 0, 2)
    suggestions:SetHidden(true)
    suggestions:SetDrawTier(DT_HIGH)
    self.checklistSuggestionPanel = suggestions
    local suggestionBackdrop = GravvyBuildPlannerUIHelpers:CreateFromVirtual(
        suggestions,
        "ZO_DefaultBackdrop",
        "ChecklistSuggestionsBackdrop"
    )
    suggestionBackdrop:SetAnchorFill(suggestions)
    self.checklistSuggestionButtons = {}
    for index = 1, 6 do
        local button = makeButton(suggestions, "", 385)
        button:SetHeight(24)
        button:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        button:SetAnchor(TOPLEFT, suggestions, TOPLEFT, 5, 4 + ((index - 1) * 24))
        button:SetHandler("OnClicked", function() self:ChooseChecklistSuggestion(index) end)
        self.checklistSuggestionButtons[index] = button
    end
end

function UI:GetChecklist()
    return self.owner.data:GetCurrentSetup().checklist
end

function UI:RefreshChecklistPlanner()
    local entries = self:GetChecklist()
    local lastOffset = #entries > 0 and math.floor((#entries - 1) / ROW_COUNT) * ROW_COUNT or 0
    self.checklistOffset = zo_clamp(self.checklistOffset, 0, lastOffset)
    local complete = 0
    for _, entry in ipairs(entries) do
        complete = complete + (entry.completed and 1 or 0)
    end
    for rowIndex = 1, ROW_COUNT do
        local row = self.checklistRows[rowIndex]
        local entry = entries[self.checklistOffset + rowIndex]
        row.abilityId = entry and entry.abilityId
        row.targetRank = entry and entry.targetRank
        row:SetHidden(not entry)
        if entry then
            local marker = entry.completed and COMPLETE_MARKER or "-"
            local rank = entry.targetRank and (" · " .. zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_CHECKLIST_RANK_VALUE,
                entry.targetRank
            )) or ""
            row:SetText(zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SUMMARY,
                marker,
                GetString(categoryStringIds[entry.category]),
                entry.name,
                rank
            ))
        else
            row:SetText("")
        end
    end
    local first = #entries == 0 and 0 or self.checklistOffset + 1
    local last = math.min(#entries, self.checklistOffset + ROW_COUNT)
    self.checklistPageLabel:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CHAMPION_PAGE,
        first,
        last,
        #entries
    ) .. " · " .. zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CHECKLIST_PROGRESS,
        complete,
        #entries
    ))
    self:LoadChecklistEditor()
end

function UI:PageChecklist(direction)
    local entries = self:GetChecklist()
    local lastOffset = #entries > 0 and math.floor((#entries - 1) / ROW_COUNT) * ROW_COUNT or 0
    self.checklistOffset = zo_clamp(
        self.checklistOffset + (direction * ROW_COUNT),
        0,
        lastOffset
    )
    self:RefreshChecklistPlanner()
end

function UI:SelectChecklistRow(rowIndex)
    local index = self.checklistOffset + rowIndex
    self.selectedChecklistIndex = self:GetChecklist()[index] and index or nil
    self:LoadChecklistEditor()
end

function UI:LoadChecklistEditor()
    local entry = self.selectedChecklistIndex and self:GetChecklist()[self.selectedChecklistIndex]
    self.loadingChecklist = true
    self.selectedChecklistEntry = entry
    self.selectedChecklistPassive = entry and entry.abilityId
        and self.owner.skillCatalog:FindPassiveById(entry.abilityId)
        or nil
    self.checklistEditorTitle:SetText(GetString(entry
        and SI_GRAVVY_BUILD_PLANNER_CHECKLIST_EDIT
        or SI_GRAVVY_BUILD_PLANNER_CHECKLIST_NEW))
    setChoices(self.checklistCategoryCombo, categoryChoices(),
        entry and entry.category or "passive", function()
            self.selectedChecklistPassive = nil
            self:OnChecklistTextChanged()
        end)
    self.checklistNameEdit:SetText(entry and entry.name or "")
    self.checklistRankEdit:SetText(entry and entry.targetRank and tostring(entry.targetRank) or "")
    setChoices(self.checklistStatusCombo, statusChoices(), entry and entry.completed or false)
    self.checklistNoteEdit:SetText(entry and entry.note or "")
    self.checklistPreview:SetTexture(entry and entry.icon ~= "" and entry.icon or EMPTY_TEXTURE)
    self.checklistPreviewName:SetText(entry and entry.name
        or GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED))
    self.checklistSuggestionPanel:SetHidden(true)
    self.checklistToggleButton:SetText(GetString(entry and entry.completed
        and SI_GRAVVY_BUILD_PLANNER_CHECKLIST_MARK_INCOMPLETE
        or SI_GRAVVY_BUILD_PLANNER_CHECKLIST_MARK_COMPLETE))
    self.loadingChecklist = false
end

function UI:OnChecklistTextChanged()
    if self.loadingChecklist then
        return
    end
    self.selectedChecklistPassive = nil
    if self.checklistCategoryCombo.selectedValue ~= "passive" then
        self.checklistSuggestionPanel:SetHidden(true)
        return
    end
    local results = self.owner.skillCatalog:SearchPassives(self.checklistNameEdit:GetText(), 6)
    self.checklistSuggestionData = results
    self.checklistSuggestionIndex = 1
    self.checklistSuggestionPanel:SetHidden(#results == 0)
    for index, button in ipairs(self.checklistSuggestionButtons) do
        local entry = results[index]
        button:SetHidden(not entry)
        button:SetText(entry and (entry.name .. " · " .. entry.skillLine) or "")
    end
end

function UI:ChooseChecklistSuggestion(index)
    local entry = self.checklistSuggestionData and self.checklistSuggestionData[index]
    if not entry then
        return
    end
    self.selectedChecklistPassive = entry
    self.loadingChecklist = true
    self.checklistNameEdit:SetText(entry.name)
    self.checklistRankEdit:SetText(tostring(entry.maxRank))
    self.loadingChecklist = false
    self.checklistPreview:SetTexture(entry.icon ~= "" and entry.icon or EMPTY_TEXTURE)
    self.checklistPreviewName:SetText(entry.name .. " · " .. entry.skillLine)
    self.checklistSuggestionPanel:SetHidden(true)
end

function UI:ResolveChecklistPassive()
    if self.checklistCategoryCombo.selectedValue ~= "passive" then
        return nil
    end
    if not self.selectedChecklistPassive then
        self.selectedChecklistPassive = self.owner.skillCatalog:FindPassiveExact(
            self.checklistNameEdit:GetText()
        )
    end
    local entry = self.selectedChecklistPassive
    if entry then
        self.checklistPreview:SetTexture(entry.icon ~= "" and entry.icon or EMPTY_TEXTURE)
        self.checklistPreviewName:SetText(entry.name .. " · " .. entry.skillLine)
    end
    return entry
end

function UI:OnChecklistKeyDown(key)
    if self.checklistSuggestionPanel:IsHidden() then
        return
    end
    local count = math.min(6, #(self.checklistSuggestionData or {}))
    if key == KEY_DOWN then
        self.checklistSuggestionIndex = math.min(count, self.checklistSuggestionIndex + 1)
    elseif key == KEY_UP then
        self.checklistSuggestionIndex = math.max(1, self.checklistSuggestionIndex - 1)
    elseif key == KEY_ENTER then
        self:ChooseChecklistSuggestion(self.checklistSuggestionIndex)
    elseif key == KEY_ESCAPE then
        self.checklistSuggestionPanel:SetHidden(true)
    end
end

function UI:SaveChecklistEntry()
    local name = zo_strtrim(self.checklistNameEdit:GetText())
    local rankText = zo_strtrim(self.checklistRankEdit:GetText())
    local rank = rankText ~= "" and tonumber(rankText) or nil
    local passive = self:ResolveChecklistPassive()
    if name == "" or (rankText ~= "" and (not rank or rank ~= math.floor(rank)
        or rank < 1 or rank > 50)) or (passive and rank and rank > passive.maxRank) then
        self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHECKLIST), true)
        return
    end
    local progression = passive and rank
        and self.owner.skillCatalog:GetPassiveProgression(passive, rank)
        or nil
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, result = self.owner.data:SetChecklistEntry(
        build.id,
        setup.id,
        self.selectedChecklistIndex,
        {
            category = self.checklistCategoryCombo.selectedValue,
            name = passive and passive.name or name,
            targetRank = rank,
            completed = self.checklistStatusCombo.selectedValue == true,
            abilityId = progression and progression.abilityId
                or passive and passive.abilityId,
            icon = progression and progression.icon or passive and passive.icon or "",
            note = self.checklistNoteEdit:GetText(),
        }
    )
    if not ok then
        self:SetStatus(result, true)
        return
    end
    self.selectedChecklistIndex = result
    self:RefreshChecklistPlanner()
    self:SetStatus(zo_strformat(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SAVED,
        passive and passive.name or name))
end

function UI:RemoveChecklistEntry()
    if not self.selectedChecklistIndex then
        return
    end
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, message = self.owner.data:SetChecklistEntry(
        build.id,
        setup.id,
        self.selectedChecklistIndex,
        nil
    )
    if not ok then
        self:SetStatus(message, true)
        return
    end
    self.selectedChecklistIndex = nil
    self:RefreshChecklistPlanner()
    self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_REMOVED))
end

function UI:ToggleChecklistCompleted()
    if not self.selectedChecklistIndex then
        return
    end
    local setup, build = self.owner.data:GetCurrentSetup()
    local entry = setup.checklist[self.selectedChecklistIndex]
    local ok, message = self.owner.data:SetChecklistCompleted(
        build.id,
        setup.id,
        self.selectedChecklistIndex,
        not entry.completed
    )
    if not ok then
        self:SetStatus(message, true)
        return
    end
    self:RefreshChecklistPlanner()
end

function UI:ShowChecklistTooltip(control, abilityId, rank)
    local entry = abilityId and self.owner.skillCatalog:FindPassiveById(abilityId)
    local progression = entry and self.owner.skillCatalog:GetPassiveProgression(entry, rank)
    progression = progression or (entry and entry.progressions[entry.maxRank])
    if not progression or not SkillTooltip or not InitializeTooltip then
        return
    end
    InitializeTooltip(SkillTooltip, control, LEFT, -8, 0, RIGHT)
    if progression.progression and progression.progression.SetKeyboardTooltip then
        progression.progression:SetKeyboardTooltip(SkillTooltip, false)
    elseif SkillTooltip.LayoutSimpleAbility then
        SkillTooltip:LayoutSimpleAbility(progression.abilityId)
    end
end

function UI:HideChecklistTooltip()
    if SkillTooltip and ClearTooltip then
        ClearTooltip(SkillTooltip)
    end
end
