local UI = GravvyBuildPlannerUI
local ROW_COUNT = 10

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

local function makeCombo(parent, name, x, y, width)
    local container = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_ComboBox")
    container:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    container:SetDimensions(width, 30)
    local combo = ZO_ComboBox_ObjectFromContainer(container)
    combo:SetSortsItems(false)
    return combo
end

function UI:CreateComparisonPlanner()
    local panel = WINDOW_MANAGER:CreateControl("GravvyBuildPlannerComparison", self.window, CT_CONTROL)
    panel:SetAnchor(TOPLEFT, self.window, TOPLEFT, 18, 137)
    panel:SetDimensions(942, 530)
    panel:SetHidden(true)
    self.comparisonPanel = panel
    self.comparisonOffset = 0

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, panel, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(panel)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.018, 0.018, 0.026, 0.9 },
        { 0.28, 0.24, 0.18, 0.85 }
    )

    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_COMPARE_WITH), 22, 16, 120)
    self.comparisonSetupCombo = makeCombo(panel, "GravvyBuildPlannerComparisonSetup", 142, 16, 300)
    self.comparisonCountLabel = makeLabel(panel, "", 660, 16, 250, "ZoFontGameSmall")
    self.comparisonCountLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    local header = WINDOW_MANAGER:CreateControlFromVirtual(nil, panel, "ZO_DefaultBackdrop")
    header:SetAnchor(TOPLEFT, panel, TOPLEFT, 18, 58)
    header:SetDimensions(906, 34)
    header:SetCenterColor(0.08, 0.07, 0.05, 0.95)
    makeLabel(header, GetString(SI_GRAVVY_BUILD_PLANNER_COMPARE_COLUMN_CHANGE), 8, 2, 280, "ZoFontGameBold")
    self.comparisonLeftHeader = makeLabel(header, "", 294, 2, 292, "ZoFontGameBold")
    self.comparisonRightHeader = makeLabel(header, "", 594, 2, 302, "ZoFontGameBold")

    self.comparisonRows = {}
    for rowIndex = 1, ROW_COUNT do
        local row = WINDOW_MANAGER:CreateControl(nil, panel, CT_CONTROL)
        row:SetAnchor(TOPLEFT, panel, TOPLEFT, 18, 96 + ((rowIndex - 1) * 39))
        row:SetDimensions(906, 37)
        local rowBackdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, row, "ZO_DefaultBackdrop")
        rowBackdrop:SetAnchorFill(row)
        rowBackdrop:SetCenterColor(
            rowIndex % 2 == 0 and 0.035 or 0.02,
            rowIndex % 2 == 0 and 0.035 or 0.02,
            rowIndex % 2 == 0 and 0.045 or 0.03,
            0.9
        )
        local section = makeLabel(row, "", 8, 0, 92, "ZoFontGameSmall")
        section:SetColor(0.95, 0.69, 0.28, 1)
        local name = makeLabel(row, "", 102, 0, 184, "ZoFontGameSmall")
        local left = makeLabel(row, "", 294, 0, 292, "ZoFontGameSmall")
        left:SetColor(0.72, 0.86, 1, 1)
        local right = makeLabel(row, "", 594, 0, 302, "ZoFontGameSmall")
        right:SetColor(1, 0.82, 0.42, 1)
        row.sectionLabel = section
        row.nameLabel = name
        row.leftLabel = left
        row.rightLabel = right
        self.comparisonRows[rowIndex] = row
    end

    self.comparisonEmptyLabel = makeLabel(panel, "", 120, 220, 702, "ZoFontWinH3")
    self.comparisonEmptyLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local previous = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_PREVIOUS), 100)
    previous:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 18, -14)
    previous:SetHandler("OnClicked", function() self:PageComparison(-1) end)
    local nextPage = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_NEXT), 100)
    nextPage:SetAnchor(LEFT, previous, RIGHT, 8, 0)
    nextPage:SetHandler("OnClicked", function() self:PageComparison(1) end)
    self.comparisonPageLabel = makeLabel(panel, "", 234, 486, 250, "ZoFontGameSmall")
end

function UI:SetComparisonTarget(setupId)
    self.comparisonSetupId = setupId
    self.comparisonOffset = 0
    self:RefreshComparisonPlanner()
end

function UI:RefreshComparisonPlanner()
    local current, build = self.owner.data:GetCurrentSetup()
    local target = self.comparisonSetupId and self.owner.data:FindSetup(build, self.comparisonSetupId)
    if not target or target.id == current.id then
        target = GravvyBuildPlannerComparison:GetDefaultTarget(build, current.id)
        self.comparisonSetupId = target and target.id
    end

    self.comparisonSetupCombo:ClearItems()
    for _, setup in ipairs(build.setups) do
        if setup.id ~= current.id then
            local setupId = setup.id
            self.comparisonSetupCombo:AddItem(self.comparisonSetupCombo:CreateItemEntry(
                setup.name,
                function() self:SetComparisonTarget(setupId) end
            ))
        end
    end
    self.comparisonSetupCombo:SetSelectedItem(target and target.name or "")
    self.comparisonLeftHeader:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_COMPARE_CURRENT,
        current.name
    ))
    self.comparisonRightHeader:SetText(target and target.name or "")

    local differences = GravvyBuildPlannerComparison:Build(current, target)
    self.comparisonDifferences = differences
    local lastOffset = #differences > 0
        and math.floor((#differences - 1) / ROW_COUNT) * ROW_COUNT
        or 0
    self.comparisonOffset = zo_clamp(self.comparisonOffset, 0, lastOffset)
    self.comparisonCountLabel:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_COMPARE_DIFFERENCES,
        #differences
    ))
    local emptyText
    if not target then
        emptyText = GetString(SI_GRAVVY_BUILD_PLANNER_COMPARE_NEEDS_SETUP)
    elseif #differences == 0 then
        emptyText = GetString(SI_GRAVVY_BUILD_PLANNER_COMPARE_NONE)
    end
    self.comparisonEmptyLabel:SetText(emptyText or "")
    self.comparisonEmptyLabel:SetHidden(not emptyText)

    for rowIndex = 1, ROW_COUNT do
        local row = self.comparisonRows[rowIndex]
        local difference = differences[self.comparisonOffset + rowIndex]
        row:SetHidden(not difference)
        if difference then
            row.sectionLabel:SetText(difference.section)
            row.nameLabel:SetText(difference.label)
            row.leftLabel:SetText(difference.left)
            row.rightLabel:SetText(difference.right)
        end
    end
    local first = #differences == 0 and 0 or self.comparisonOffset + 1
    local last = math.min(#differences, self.comparisonOffset + ROW_COUNT)
    self.comparisonPageLabel:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CHAMPION_PAGE,
        first,
        last,
        #differences
    ))
end

function UI:PageComparison(direction)
    local differences = self.comparisonDifferences or {}
    local lastOffset = #differences > 0
        and math.floor((#differences - 1) / ROW_COUNT) * ROW_COUNT
        or 0
    self.comparisonOffset = zo_clamp(
        self.comparisonOffset + (direction * ROW_COUNT),
        0,
        lastOffset
    )
    self:RefreshComparisonPlanner()
end
