local UI = GravvyBuildPlannerUI
local ISSUE_ROWS = 8

local function makeLabel(parent, text, x, y, width, height, font)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    GravvyBuildPlannerAccessibility:SetFont(label, font or "ZoFontGame")
    label:SetColor(0.88, 0.86, 0.8, 1)
    label:SetText(text or "")
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    label:SetDimensions(width, height)
    GravvyBuildPlannerAccessibility:RegisterTextGeometry(label, width, height)
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

local function makeCombo(parent, name, x, y, width)
    local container = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_ComboBox")
    container:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    container:SetDimensions(width, 30)
    local combo = ZO_ComboBox_ObjectFromContainer(container)
    combo:SetSortsItems(false)
    if combo.m_dropdown then combo.m_dropdown:SetDrawTier(DT_HIGH) end
    return combo
end

function UI:CreateValidationDialog()
    local dialog = WINDOW_MANAGER:CreateTopLevelWindow("GravvyBuildPlannerValidationWindow")
    dialog:SetDimensions(880, 700)
    dialog:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    dialog:SetClampedToScreen(true)
    dialog:SetMouseEnabled(true)
    dialog:SetMovable(true)
    dialog:SetDrawTier(DT_HIGH)
    dialog:SetHidden(true)
    self.validationDialog = dialog
    self.validationOffset = 0
    self:RegisterDialog(dialog)

    local backdrop = GravvyBuildPlannerUIHelpers:CreateFromVirtual(
        dialog,
        "ZO_DefaultBackdrop",
        "ValidationBackdrop"
    )
    backdrop:SetAnchorFill(dialog)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.025, 0.025, 0.034, 0.99 },
        { 0.5, 0.42, 0.28, 0.95 }
    )

    local title = makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_VALIDATION_TITLE),
        18,
        8,
        360,
        34,
        "ZoFontWinH2"
    )
    title:SetMouseEnabled(true)
    title:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then dialog:StartMoving() end
    end)
    title:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then dialog:StopMovingOrResizing() end
    end)

    makeLabel(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_SETUP), 18, 50, 58, 30)
    self.validationSetupCombo = makeCombo(
        dialog,
        "GravvyBuildPlannerValidationSetupCombo",
        76,
        50,
        330
    )
    self.validationSummary = makeLabel(dialog, "", 430, 50, 430, 30, "ZoFontGameBold")
    self.validationSummary:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    self.validationFrontSets = makeLabel(dialog, "", 20, 92, 840, 46, "ZoFontGame")
    self.validationFrontSets:SetVerticalAlignment(TEXT_ALIGN_TOP)
    self.validationBackSets = makeLabel(dialog, "", 20, 136, 840, 46, "ZoFontGame")
    self.validationBackSets:SetVerticalAlignment(TEXT_ALIGN_TOP)

    local divider = WINDOW_MANAGER:CreateControl(nil, dialog, CT_TEXTURE)
    divider:SetAnchor(TOPLEFT, dialog, TOPLEFT, 20, 180)
    divider:SetDimensions(840, 1)
    divider:SetColor(0.5, 0.42, 0.28, 0.7)

    self.validationRows = {}
    for index = 1, ISSUE_ROWS do
        local row = WINDOW_MANAGER:CreateControl(nil, dialog, CT_CONTROL)
        row:SetAnchor(TOPLEFT, dialog, TOPLEFT, 20, 190 + ((index - 1) * 56))
        row:SetDimensions(840, 52)
        local rowBackdrop = GravvyBuildPlannerUIHelpers:CreateFromVirtual(
            row,
            "ZO_DefaultBackdrop",
            "ValidationRowBackdrop"
        )
        rowBackdrop:SetAnchorFill(row)
        local shade = index % 2 == 0 and 0.035 or 0.018
        rowBackdrop:SetCenterColor(shade, shade, shade + 0.008, 0.9)
        row.severity = makeLabel(row, "", 8, 0, 92, 52, "ZoFontGameBold")
        row.text = makeLabel(row, "", 106, 0, 724, 52, "ZoFontGame")
        self.validationRows[index] = row
    end

    self.validationEmpty = makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_VALIDATION_CLEAN),
        150,
        360,
        580,
        60,
        "ZoFontWinH3"
    )
    self.validationEmpty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local previous = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_PREVIOUS), 100)
    previous:SetAnchor(BOTTOMLEFT, dialog, BOTTOMLEFT, 18, -14)
    previous:SetHandler("OnClicked", function() self:PageValidation(-1) end)
    local nextPage = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_NEXT), 100)
    nextPage:SetAnchor(LEFT, previous, RIGHT, 8, 0)
    nextPage:SetHandler("OnClicked", function() self:PageValidation(1) end)
    self.validationPageLabel = makeLabel(dialog, "", 236, 654, 260, 28, "ZoFontGameSmall")
    local close = makeButton(dialog, GetString(SI_DIALOG_CLOSE), 90)
    close:SetAnchor(BOTTOMRIGHT, dialog, BOTTOMRIGHT, -18, -14)
    close:SetHandler("OnClicked", function() dialog:SetHidden(true) end)
end

function UI:GetValidationSetup()
    local build = self.owner.data:GetCurrentBuild()
    local setup = self.validationSetupId
        and self.owner.data:FindSetup(build, self.validationSetupId)
    if not setup then
        setup = self.owner.data:GetCurrentSetup()
        self.validationSetupId = setup.id
    end
    return setup, build
end

function UI:OpenValidation(setupId)
    local build = self.owner.data:GetCurrentBuild()
    local setup = setupId and self.owner.data:FindSetup(build, setupId)
        or self.owner.data:GetCurrentSetup()
    self.validationSetupId = setup.id
    self.validationOffset = 0
    self.validationDialog:SetHidden(false)
    self:RefreshValidation()
end

function UI:SelectValidationSetup(setupId)
    self.validationSetupId = setupId
    self.validationOffset = 0
    self:RefreshValidation()
end

function UI:RefreshValidation()
    local setup, build = self:GetValidationSetup()
    self.validationSetupCombo:ClearItems()
    for _, choice in ipairs(build.setups) do
        local setupId = choice.id
        self.validationSetupCombo:AddItem(self.validationSetupCombo:CreateItemEntry(
            choice.name,
            function() self:SelectValidationSetup(setupId) end
        ), ZO_COMBOBOX_SUPPRESS_UPDATE)
    end
    if self.validationSetupCombo.UpdateItems then self.validationSetupCombo:UpdateItems() end
    self.validationSetupCombo:SetSelectedItem(setup.name)

    local report = self.owner.buildValidation:BuildReport(setup)
    self.validationReport = report
    self.validationSummary:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_VALIDATION_SUMMARY,
        report.errors,
        report.warnings
    ))
    self.validationSummary:SetColor(report.errors > 0 and 1 or 0.88,
        report.errors > 0 and 0.45 or 0.86,
        report.errors > 0 and 0.35 or 0.8, 1)
    self.validationFrontSets:SetText("|cEFB760"
        .. GetString(SI_GRAVVY_BUILD_PLANNER_FRONT_BAR) .. "|r · "
        .. self.owner.buildValidation:FormatSetCounts(report.sets.front))
    self.validationBackSets:SetText("|cEFB760"
        .. GetString(SI_GRAVVY_BUILD_PLANNER_BACK_BAR) .. "|r · "
        .. self.owner.buildValidation:FormatSetCounts(report.sets.back))

    local lastOffset = #report.issues > 0
        and math.floor((#report.issues - 1) / ISSUE_ROWS) * ISSUE_ROWS or 0
    self.validationOffset = zo_clamp(self.validationOffset, 0, lastOffset)
    for index, row in ipairs(self.validationRows) do
        local issue = report.issues[self.validationOffset + index]
        row:SetHidden(not issue)
        if issue then
            local isError = issue.severity == "errors"
            row.severity:SetText(GetString(isError
                and SI_GRAVVY_BUILD_PLANNER_VALIDATION_ERROR
                or SI_GRAVVY_BUILD_PLANNER_VALIDATION_WARNING))
            if isError then
                row.severity:SetColor(1, 0.42, 0.35, 1)
            else
                row.severity:SetColor(1, 0.72, 0.3, 1)
            end
            row.text:SetText(issue.text)
        end
    end
    self.validationEmpty:SetHidden(#report.issues > 0)
    local first = #report.issues == 0 and 0 or self.validationOffset + 1
    local last = math.min(#report.issues, self.validationOffset + ISSUE_ROWS)
    self.validationPageLabel:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CHAMPION_PAGE,
        first,
        last,
        #report.issues
    ))
end

function UI:PageValidation(direction)
    local issues = self.validationReport and self.validationReport.issues or {}
    local lastOffset = #issues > 0
        and math.floor((#issues - 1) / ISSUE_ROWS) * ISSUE_ROWS or 0
    self.validationOffset = zo_clamp(
        self.validationOffset + (direction * ISSUE_ROWS),
        0,
        lastOffset
    )
    self:RefreshValidation()
end
