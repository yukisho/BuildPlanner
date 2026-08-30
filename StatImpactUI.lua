local UI = GravvyBuildPlannerUI
local EFFECT_ROWS = 5

local function makeLabel(parent, text, x, y, width, height, font)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    GravvyBuildPlannerAccessibility:SetFont(label, font or "ZoFontGame")
    label:SetColor(0.88, 0.86, 0.8, 1)
    label:SetText(text or "")
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    label:SetDimensions(width or 120, height or 30)
    GravvyBuildPlannerAccessibility:RegisterTextGeometry(label, width or 120, height or 30)
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
    if combo.m_dropdown then
        combo.m_dropdown:SetDrawTier(DT_HIGH)
    end
    return combo
end

local function finishCombo(combo)
    if combo.UpdateItems then
        combo:UpdateItems()
    end
end

function UI:CreateStatImpactDialog()
    local dialog = WINDOW_MANAGER:CreateTopLevelWindow("GravvyBuildPlannerStatImpactWindow")
    dialog:SetDimensions(1180, 760)
    dialog:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    dialog:SetClampedToScreen(true)
    dialog:SetMouseEnabled(true)
    dialog:SetMovable(true)
    dialog:SetDrawTier(DT_HIGH)
    dialog:SetHidden(true)
    self.statImpactDialog = dialog
    self:RegisterDialog(dialog)
    self.statImpactBar = "front"
    self.statImpactContextKey = "general"
    self.statImpactContextName = GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CONTEXT_GENERAL)
    self.statImpactEffectOffset = 0

    local backdrop = GravvyBuildPlannerUIHelpers:CreateFromVirtual(
        dialog,
        "ZO_DefaultBackdrop",
        "StatImpactBackdrop"
    )
    backdrop:SetAnchorFill(dialog)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.025, 0.025, 0.034, 0.99 },
        { 0.5, 0.42, 0.28, 0.95 }
    )

    local title = makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_TITLE),
        18,
        8,
        360,
        34,
        "ZoFontWinH2"
    )
    title:SetMouseEnabled(true)
    title:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            dialog:StartMoving()
        end
    end)
    title:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            dialog:StopMovingOrResizing()
        end
    end)

    makeLabel(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_SETUP), 18, 48, 58)
    self.statImpactSetupCombo = makeCombo(
        dialog,
        "GravvyBuildPlannerStatImpactSetupCombo",
        76,
        48,
        240
    )
    makeLabel(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_COMPARE_WITH), 328, 48, 70)
    self.statImpactCompareCombo = makeCombo(
        dialog,
        "GravvyBuildPlannerStatImpactCompareCombo",
        398,
        48,
        240
    )
    makeLabel(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CONTEXT_LABEL), 650, 48, 65)
    self.statImpactContextCombo = makeCombo(
        dialog,
        "GravvyBuildPlannerStatImpactContextCombo",
        715,
        48,
        170
    )
    self.statImpactAddContext = makeButton(dialog, "+", 32)
    self.statImpactAddContext:SetAnchor(TOPLEFT, dialog, TOPLEFT, 891, 49)
    self.statImpactAddContext:SetHandler("OnClicked", function() self:AddStatImpactContext() end)
    makeLabel(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_ACTIVE_BAR), 930, 48, 100)
    self.statImpactBarCombo = makeCombo(
        dialog,
        "GravvyBuildPlannerStatImpactBarCombo",
        1020,
        48,
        140
    )

    self.statImpactHelp = makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_HELP),
        18,
        82,
        1144,
        44,
        "ZoFontGameSmall"
    )
    self.statImpactHelp:SetVerticalAlignment(TEXT_ALIGN_TOP)

    makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_EXACT_TITLE),
        20,
        126,
        430,
        30,
        "ZoFontWinH3"
    )
    makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_EFFECTS_TITLE),
        474,
        126,
        546,
        30,
        "ZoFontWinH3"
    )

    local statHeader = WINDOW_MANAGER:CreateControl(nil, dialog, CT_CONTROL)
    statHeader:SetAnchor(TOPLEFT, dialog, TOPLEFT, 18, 158)
    statHeader:SetDimensions(430, 28)
    local statHeaderBackdrop = WINDOW_MANAGER:CreateControlFromVirtual(
        nil,
        statHeader,
        "ZO_DefaultBackdrop"
    )
    statHeaderBackdrop:SetAnchorFill(statHeader)
    statHeaderBackdrop:SetCenterColor(0.08, 0.07, 0.05, 0.95)
    makeLabel(statHeader, GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_STAT), 7, 0, 182, 28, "ZoFontGameBold")
    self.statImpactLiveHeader = makeLabel(
        statHeader,
        GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_LIVE),
        194,
        0,
        72,
        28,
        "ZoFontGameBold"
    )
    self.statImpactSnapshotHeader = makeLabel(
        statHeader,
        GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_SNAPSHOT),
        270,
        0,
        86,
        28,
        "ZoFontGameBold"
    )
    makeLabel(statHeader, GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CHANGE), 360, 0, 64, 28, "ZoFontGameBold")

    self.statImpactRows = {}
    for index, stat in ipairs(self.owner.statImpact:GetStatRows()) do
        local row = WINDOW_MANAGER:CreateControl(nil, dialog, CT_CONTROL)
        row:SetAnchor(TOPLEFT, dialog, TOPLEFT, 18, 188 + ((index - 1) * 27))
        row:SetDimensions(430, 26)
        local rowBackdrop = GravvyBuildPlannerUIHelpers:CreateFromVirtual(
            row,
            "ZO_DefaultBackdrop",
            "StatImpactRowBackdrop"
        )
        rowBackdrop:SetAnchorFill(row)
        local shade = index % 2 == 0 and 0.035 or 0.018
        rowBackdrop:SetCenterColor(shade, shade, shade + 0.008, 0.88)
        row.stat = stat
        row.name = makeLabel(row, GetString(stat.label), 7, 0, 182, 26, "ZoFontGameSmall")
        row.live = makeLabel(row, "", 194, 0, 72, 26, "ZoFontGameSmall")
        row.snapshot = makeLabel(row, "", 270, 0, 86, 26, "ZoFontGameSmall")
        row.change = makeLabel(row, "", 360, 0, 64, 26, "ZoFontGameSmall")
        row.live:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        row.snapshot:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        row.change:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        self.statImpactRows[index] = row
    end

    self.statImpactSnapshotLabel = makeLabel(dialog, "", 18, 600, 430, 100, "ZoFontGameSmall")
    self.statImpactSnapshotLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)

    self.statImpactCoverageLabel = makeLabel(dialog, "", 474, 158, 546, 50, "ZoFontGame")
    self.statImpactCoverageLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    self.statImpactEffectRows = {}
    for index = 1, EFFECT_ROWS do
        local label = makeLabel(
            dialog,
            "",
            474,
            210 + ((index - 1) * 74),
            546,
            72,
            "ZoFontGame"
        )
        label:SetVerticalAlignment(TEXT_ALIGN_TOP)
        self.statImpactEffectRows[index] = label
    end
    self.statImpactEffectsEmpty = makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_NO_EFFECTS),
        554,
        300,
        386,
        60,
        "ZoFontGame"
    )
    self.statImpactEffectsEmpty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.statImpactEffectsEmpty:SetHidden(true)

    local previous = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_PREVIOUS), 90)
    previous:SetAnchor(TOPLEFT, dialog, TOPLEFT, 474, 594)
    previous:SetHandler("OnClicked", function() self:PageStatImpactEffects(-1) end)
    local nextPage = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_NEXT), 90)
    nextPage:SetAnchor(LEFT, previous, RIGHT, 6, 0)
    nextPage:SetHandler("OnClicked", function() self:PageStatImpactEffects(1) end)
    self.statImpactPageLabel = makeLabel(dialog, "", 788, 594, 230, 28, "ZoFontGameSmall")
    self.statImpactPageLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.statImpactCaptureProgress = makeLabel(
        dialog,
        "",
        474,
        626,
        546,
        76,
        "ZoFontGameSmall"
    )
    self.statImpactCaptureProgress:SetVerticalAlignment(TEXT_ALIGN_TOP)

    local capture = makeButton(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CAPTURE),
        190
    )
    capture:SetAnchor(BOTTOMLEFT, dialog, BOTTOMLEFT, 18, -14)
    capture:SetHandler("OnClicked", function() self:RequestStatImpactCapture() end)
    local clear = makeButton(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CLEAR),
        150
    )
    clear:SetAnchor(LEFT, capture, RIGHT, 8, 0)
    clear:SetHandler("OnClicked", function() self:RequestStatImpactClear() end)
    local refresh = makeButton(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_REFRESH),
        130
    )
    refresh:SetAnchor(LEFT, clear, RIGHT, 8, 0)
    refresh:SetHandler("OnClicked", function() self:RefreshStatImpact() end)
    local close = makeButton(dialog, GetString(SI_DIALOG_CLOSE), 90)
    close:SetAnchor(BOTTOMRIGHT, dialog, BOTTOMRIGHT, -18, -14)
    close:SetHandler("OnClicked", function() dialog:SetHidden(true) end)
end

function UI:GetStatImpactSetup()
    local build = self.owner.data:GetCurrentBuild()
    local setup = self.statImpactSetupId
        and self.owner.data:FindSetup(build, self.statImpactSetupId)
    if not setup then
        setup = self.owner.data:GetCurrentSetup()
        self.statImpactSetupId = setup.id
    end
    return setup, build
end

function UI:OpenStatImpact(setupId)
    local build = self.owner.data:GetCurrentBuild()
    local setup = self.owner.data:GetCurrentSetup()
    local compareSetup = setupId and self.owner.data:FindSetup(build, setupId)
    self.statImpactCompareSetupId = compareSetup and compareSetup.id ~= setup.id
        and compareSetup.id or nil
    self.statImpactSetupId = setup.id
    self.statImpactEffectOffset = 0
    self.statImpactDialog:SetHidden(false)
    self:RefreshStatImpact()
end

function UI:SelectStatImpactSetup(setupId)
    self.statImpactSetupId = setupId
    if self.statImpactCompareSetupId == setupId then self.statImpactCompareSetupId = nil end
    self.statImpactEffectOffset = 0
    self:RefreshStatImpact()
end

function UI:SelectStatImpactComparison(setupId)
    self.statImpactCompareSetupId = setupId
    self.statImpactEffectOffset = 0
    self:RefreshStatImpact()
end

function UI:SelectStatImpactContext(key, name)
    self.statImpactContextKey = key or "general"
    self.statImpactContextName = name or key
    self.statImpactEffectOffset = 0
    self:RefreshStatImpact()
end

function UI:AddStatImpactContext()
    self:OpenNameDialog("", function(value)
        value = zo_strtrim(value or "")
        if value == "" or #value > 90 then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CONTEXT_INVALID)
        end
        self.statImpactContextKey = "custom:" .. zo_strlower(value)
        self.statImpactContextName = value
        self:RefreshStatImpact()
        return true
    end, SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CONTEXT_NEW)
end

function UI:SelectStatImpactBar(bar)
    self.statImpactBar = bar == "back" and "back" or "front"
    self.statImpactEffectOffset = 0
    self:RefreshStatImpact()
end

function UI:RefreshStatImpact()
    local setup, build = self:GetStatImpactSetup()
    self.statImpactSetupCombo:ClearItems()
    for _, choice in ipairs(build.setups) do
        local setupId = choice.id
        self.statImpactSetupCombo:AddItem(self.statImpactSetupCombo:CreateItemEntry(
            choice.name,
            function() self:SelectStatImpactSetup(setupId) end
        ), ZO_COMBOBOX_SUPPRESS_UPDATE)
    end
    finishCombo(self.statImpactSetupCombo)
    self.statImpactSetupCombo:SetSelectedItem(setup.name)

    local compareSetup = self.statImpactCompareSetupId
        and self.owner.data:FindSetup(build, self.statImpactCompareSetupId)
    self.statImpactCompareCombo:ClearItems()
    self.statImpactCompareCombo:AddItem(self.statImpactCompareCombo:CreateItemEntry(
        GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_LIVE_CHARACTER),
        function() self:SelectStatImpactComparison(nil) end
    ), ZO_COMBOBOX_SUPPRESS_UPDATE)
    for _, choice in ipairs(build.setups) do
        if choice.id ~= setup.id then
            local setupId = choice.id
            self.statImpactCompareCombo:AddItem(self.statImpactCompareCombo:CreateItemEntry(
                choice.name,
                function() self:SelectStatImpactComparison(setupId) end
            ), ZO_COMBOBOX_SUPPRESS_UPDATE)
        end
    end
    finishCombo(self.statImpactCompareCombo)
    self.statImpactCompareCombo:SetSelectedItem(compareSetup and compareSetup.name
        or GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_LIVE_CHARACTER))

    local contexts = {
        { key = "general", name = GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CONTEXT_GENERAL) },
        { key = "unbuffed", name = GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CONTEXT_UNBUFFED) },
        { key = "food", name = GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CONTEXT_FOOD) },
        { key = "trial", name = GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CONTEXT_TRIAL) },
    }
    local seen = { general = true, unbuffed = true, food = true, trial = true }
    local function addContexts(source)
        for _, context in ipairs(self.owner.data:GetStatContexts(source)) do
            local key = zo_strlower(context.key)
            if not seen[key] then
                contexts[#contexts + 1] = { key = context.key, name = context.name }
                seen[key] = true
            end
        end
    end
    addContexts(setup)
    addContexts(compareSetup)
    if not seen[zo_strlower(self.statImpactContextKey)] then
        contexts[#contexts + 1] = {
            key = self.statImpactContextKey,
            name = self.statImpactContextName,
        }
    end
    self.statImpactContextCombo:ClearItems()
    for _, context in ipairs(contexts) do
        local key, name = context.key, context.name
        self.statImpactContextCombo:AddItem(self.statImpactContextCombo:CreateItemEntry(
            name,
            function() self:SelectStatImpactContext(key, name) end
        ), ZO_COMBOBOX_SUPPRESS_UPDATE)
    end
    finishCombo(self.statImpactContextCombo)
    self.statImpactContextCombo:SetSelectedItem(self.statImpactContextName)

    self.statImpactBarCombo:ClearItems()
    local barChoices = {
        { key = "front", label = GetString(SI_GRAVVY_BUILD_PLANNER_FRONT_BAR) },
        { key = "back", label = GetString(SI_GRAVVY_BUILD_PLANNER_BACK_BAR) },
    }
    for _, choice in ipairs(barChoices) do
        local barKey = choice.key
        self.statImpactBarCombo:AddItem(self.statImpactBarCombo:CreateItemEntry(
            choice.label,
            function() self:SelectStatImpactBar(barKey) end
        ), ZO_COMBOBOX_SUPPRESS_UPDATE)
    end
    finishCombo(self.statImpactBarCombo)
    self.statImpactBarCombo:SetSelectedItem(
        GetString(self.statImpactBar == "back"
            and SI_GRAVVY_BUILD_PLANNER_BACK_BAR
            or SI_GRAVVY_BUILD_PLANNER_FRONT_BAR)
    )

    local report = self.owner.statImpact:BuildReport(
        setup,
        self.statImpactBar,
        self.statImpactContextKey,
        compareSetup
    )
    local liveBar = report.liveBar or report.bar
    self.statImpactLiveHeader:SetText(compareSetup and setup.name or zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_LIVE_BAR,
        liveBar == "back" and 2 or 1
    ))
    self.statImpactSnapshotHeader:SetText(compareSetup and compareSetup.name
        or GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_SNAPSHOT))
    local leftValues
    if compareSetup then
        leftValues = report.snapshot and report.snapshot.values or {}
    else
        leftValues = report.live
    end
    local rightSnapshot = compareSetup and report.compareSnapshot or report.snapshot
    local rightValues = rightSnapshot and rightSnapshot.values or {}
    local comparable
    if compareSetup then
        comparable = report.snapshot ~= nil and report.compareSnapshot ~= nil
            and not report.snapshotStale and not report.compareSnapshotStale
    else
        comparable = report.snapshot ~= nil and not report.snapshotStale
            and (not report.liveBar or report.liveBar == report.bar)
    end
    for _, row in ipairs(self.statImpactRows) do
        local liveValue = leftValues and leftValues[row.stat.key]
        local snapshotValue = rightValues[row.stat.key]
        row.live:SetText(self.owner.statImpact:FormatValue(row.stat, liveValue))
        row.snapshot:SetText(self.owner.statImpact:FormatValue(row.stat, snapshotValue))
        row.change:SetText(comparable
            and self.owner.statImpact:FormatChange(row.stat, liveValue, snapshotValue)
            or "—")
        local difference = comparable
            and type(liveValue) == "number" and type(snapshotValue) == "number"
            and snapshotValue - liveValue
            or 0
        if difference > 0 then
            row.change:SetColor(0.55, 0.9, 0.45, 1)
        elseif difference < 0 then
            row.change:SetColor(1, 0.48, 0.4, 1)
        else
            row.change:SetColor(0.88, 0.86, 0.8, 1)
        end
    end

    self.statImpactSnapshotLabel:SetText(self.owner.statImpact:FormatSnapshotDetails(
        report.snapshot,
        report.bar,
        report.snapshotStale,
        self.statImpactContextName
    ) .. (compareSetup and "\n" .. self.owner.statImpact:FormatSnapshotDetails(
        report.compareSnapshot,
        report.bar,
        report.compareSnapshotStale,
        self.statImpactContextName
    ) or ""))
    if report.snapshotStale or report.compareSnapshotStale then
        self.statImpactSnapshotLabel:SetColor(1, 0.55, 0.3, 1)
    else
        self.statImpactSnapshotLabel:SetColor(0.88, 0.86, 0.8, 1)
    end

    local coverage = report.equippedCoverage
    self.statImpactCoverageLabel:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_COVERAGE,
        report.resolved,
        report.planned,
        GetString(report.bar == "back"
            and SI_GRAVVY_BUILD_PLANNER_BACK_BAR
            or SI_GRAVVY_BUILD_PLANNER_FRONT_BAR)
    ) .. "\n" .. zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_EQUIPPED_COVERAGE,
        coverage.ready,
        coverage.adjustable,
        coverage.missing
    ))
    self.statImpactCaptureProgress:SetText(
        self.owner.statImpact:FormatCaptureProgress(setup, self.statImpactContextKey)
    )
    local effects = {}
    for _, change in ipairs(report.changes or {}) do
        effects[#effects + 1] = {
            label = change.section .. " · " .. change.label,
            description = change.left .. " → " .. change.right,
        }
    end
    for _, effect in ipairs(report.effects) do effects[#effects + 1] = effect end
    self.statImpactEffects = effects
    local lastOffset = #effects > 0
        and math.floor((#effects - 1) / EFFECT_ROWS) * EFFECT_ROWS
        or 0
    self.statImpactEffectOffset = zo_clamp(self.statImpactEffectOffset, 0, lastOffset)
    for index, label in ipairs(self.statImpactEffectRows) do
        local effect = effects[self.statImpactEffectOffset + index]
        label:SetHidden(not effect)
        if effect then
            label:SetText("|cEFB760" .. effect.label .. "|r\n" .. effect.description)
        end
    end
    self.statImpactEffectsEmpty:SetHidden(#effects > 0)
    local first = #effects == 0 and 0 or self.statImpactEffectOffset + 1
    local last = math.min(#effects, self.statImpactEffectOffset + EFFECT_ROWS)
    self.statImpactPageLabel:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CHAMPION_PAGE,
        first,
        last,
        #effects
    ))
end

function UI:PageStatImpactEffects(direction)
    local effects = self.statImpactEffects or {}
    local lastOffset = #effects > 0
        and math.floor((#effects - 1) / EFFECT_ROWS) * EFFECT_ROWS
        or 0
    self.statImpactEffectOffset = zo_clamp(
        self.statImpactEffectOffset + (direction * EFFECT_ROWS),
        0,
        lastOffset
    )
    self:RefreshStatImpact()
end

function UI:RequestStatImpactCapture()
    local setup, build = self:GetStatImpactSetup()
    local liveBar = self.owner.statImpact:GetLiveBar()
    if liveBar and liveBar ~= self.statImpactBar then
        self:SetStatus(zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_SWITCH_TO_BAR,
            GetString(self.statImpactBar == "back"
                and SI_GRAVVY_BUILD_PLANNER_BACK_BAR
                or SI_GRAVVY_BUILD_PLANNER_FRONT_BAR)
        ), true)
        return
    end
    local captureBar = self.statImpactBar
    local coverage = self.owner.statImpact:GetEquippedCoverage(setup, captureBar)
    self:OpenConfirm(
        self.owner.statImpact:FormatCaptureConfirmation(
            setup,
            captureBar,
            coverage,
            self.statImpactContextName
        ),
        function()
            local snapshot = self.owner.statImpact:MakeSnapshot(setup, captureBar, coverage)
            snapshot.contextKey = self.statImpactContextKey
            snapshot.contextName = self.statImpactContextName
            local ok, message = self.owner.data:SetStatSnapshot(
                build.id,
                setup.id,
                captureBar,
                snapshot
            )
            if not ok then
                return false, message
            end
            local nextBar = self.owner.statImpact:GetNextCaptureBar(
                setup,
                captureBar,
                self.statImpactContextKey
            )
            if nextBar then
                self.statImpactBar = nextBar
            end
            self:RefreshStatImpact()
            self:SetStatus(nextBar and zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CAPTURED_NEXT,
                GetString(captureBar == "back"
                    and SI_GRAVVY_BUILD_PLANNER_BACK_BAR
                    or SI_GRAVVY_BUILD_PLANNER_FRONT_BAR),
                GetString(nextBar == "back"
                    and SI_GRAVVY_BUILD_PLANNER_BACK_BAR
                    or SI_GRAVVY_BUILD_PLANNER_FRONT_BAR)
            ) or zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CAPTURED,
                setup.name
            ))
            return true
        end,
        true,
        SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CAPTURE_ACTION
    )
end

function UI:RequestStatImpactClear()
    local setup, build = self:GetStatImpactSetup()
    if not self.owner.data:GetStatSnapshot(
        setup,
        self.statImpactBar,
        self.statImpactContextKey
    ) then
        self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_NOT_CAPTURED))
        return
    end
    self:OpenConfirm(
        zo_strformat(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CONFIRM_CLEAR, setup.name),
        function()
            local ok, message = self.owner.data:ClearStatSnapshot(
                build.id,
                setup.id,
                self.statImpactBar,
                self.statImpactContextKey
            )
            if not ok then
                return false, message
            end
            self:RefreshStatImpact()
            self:SetStatus(zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CLEARED,
                setup.name
            ))
            return true
        end,
        true
    )
end
