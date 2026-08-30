local UI = GravvyBuildPlannerUI

local function label(parent, text, x, y, width, height, font)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    GravvyBuildPlannerAccessibility:SetFont(control, font or "ZoFontGame")
    control:SetText(text or "")
    control:SetColor(0.88, 0.86, 0.8, 1)
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    control:SetDimensions(width, height)
    GravvyBuildPlannerAccessibility:RegisterTextGeometry(control, width, height)
    control:SetVerticalAlignment(TEXT_ALIGN_TOP)
    return control
end

local function button(parent, text, width)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_BUTTON)
    control:SetDimensions(width, 28)
    GravvyBuildPlannerAccessibility:RegisterTextGeometry(control, width, 28)
    GravvyBuildPlannerAccessibility:SetFont(control, "ZoFontGame")
    control:SetText(text)
    control:SetNormalFontColor(0.85, 0.78, 0.62, 1)
    control:SetMouseOverFontColor(1, 1, 1, 1)
    return control
end

local function detailCard(parent, headingId, y, height)
    local card = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    card:SetAnchor(TOPLEFT, parent, TOPLEFT, 22, y)
    card:SetDimensions(936, height)
    local backdrop = GravvyBuildPlannerUIHelpers:CreateFromVirtual(
        card, "ZO_DefaultBackdrop", "WalkthroughCard"
    )
    backdrop:SetAnchorFill(card)
    backdrop:SetCenterColor(0.035, 0.035, 0.045, 0.92)
    backdrop:SetEdgeColor(0.28, 0.24, 0.18, 0.9)
    local heading = label(card, GetString(headingId), 12, 5, 908, 26, "ZoFontGameBold")
    heading:SetColor(0.93, 0.72, 0.32, 1)
    local value = label(card, "", 12, 31, 908, height - 37, "ZoFontGame")
    return value
end

function UI:CreateWalkthroughDialog()
    local dialog = WINDOW_MANAGER:CreateTopLevelWindow(
        "GravvyBuildPlannerWalkthroughWindow"
    )
    dialog:SetDimensions(980, 700)
    dialog:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    dialog:SetClampedToScreen(true)
    dialog:SetMouseEnabled(true)
    dialog:SetMovable(true)
    dialog:SetDrawTier(DT_HIGH)
    dialog:SetHidden(true)
    self.walkthroughDialog = dialog
    self:RegisterDialog(dialog)
    local backdrop = GravvyBuildPlannerUIHelpers:CreateFromVirtual(
        dialog, "ZO_DefaultBackdrop", "WalkthroughBackdrop"
    )
    backdrop:SetAnchorFill(dialog)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop, { 0.025, 0.025, 0.034, 0.99 }, { 0.5, 0.42, 0.28, 0.95 }
    )
    label(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_TITLE),
        18, 10, 944, 34, "ZoFontWinH2")
    self.walkthroughProgress = label(dialog, "", 20, 48, 940, 30, "ZoFontGameBold")
    self.walkthroughPhase = label(dialog, "", 24, 80, 716, 28, "ZoFontGame")
    self.walkthroughStatus = label(dialog, "", 748, 80, 210, 28, "ZoFontGameBold")
    self.walkthroughStatus:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.walkthroughStepTitle = label(dialog, "", 24, 116, 934, 46, "ZoFontWinH2")
    self.walkthroughPlanned = detailCard(
        dialog,
        SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_PLANNED_LABEL,
        170,
        130
    )
    self.walkthroughCurrent = detailCard(
        dialog,
        SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_CURRENT_LABEL,
        310,
        95
    )
    self.walkthroughInstruction = detailCard(
        dialog,
        SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_NEXT_ACTION_LABEL,
        415,
        155
    )

    local previous = button(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_PREVIOUS), 110)
    previous:SetAnchor(BOTTOMLEFT, dialog, BOTTOMLEFT, 18, -14)
    previous:SetHandler("OnClicked", function() self:PageWalkthrough(-1) end)
    self.walkthroughPrevious = previous
    local nextStep = button(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_NEXT), 110)
    nextStep:SetAnchor(LEFT, previous, RIGHT, 8, 0)
    nextStep:SetHandler("OnClicked", function() self:PageWalkthrough(1) end)
    self.walkthroughNext = nextStep
    local nextNeeded = button(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_NEXT_NEEDED),
        140
    )
    nextNeeded:SetAnchor(LEFT, nextStep, RIGHT, 8, 0)
    nextNeeded:SetHandler("OnClicked", function() self:NextNeededWalkthrough() end)
    self.walkthroughNextNeeded = nextNeeded
    local open = button(dialog, "", 210)
    open:SetAnchor(BOTTOMRIGHT, dialog, BOTTOMRIGHT, -112, -14)
    open:SetHandler("OnClicked", function() self:OpenWalkthroughStep() end)
    self.walkthroughOpen = open
    local close = button(dialog, GetString(SI_DIALOG_CLOSE), 90)
    close:SetAnchor(BOTTOMRIGHT, dialog, BOTTOMRIGHT, -18, -14)
    close:SetHandler("OnClicked", function() dialog:SetHidden(true) end)
end

function UI:OpenWalkthrough()
    self.walkthroughIndex = 1
    self.walkthroughStartAtNeeded = true
    self.walkthroughDialog:SetHidden(false)
    self:RefreshWalkthrough()
end

function UI:RefreshWalkthrough()
    local setup = self.owner.data:GetCurrentSetup()
    self.walkthroughReport = self.owner.walkthrough:Build(setup)
    local report = self.walkthroughReport
    if self.walkthroughStartAtNeeded then
        for index, candidate in ipairs(report.steps) do
            if not candidate.complete then
                self.walkthroughIndex = index
                break
            end
        end
        self.walkthroughStartAtNeeded = false
    end
    self.walkthroughIndex = zo_clamp(self.walkthroughIndex or 1, 1, math.max(1, report.total))
    local step = report.steps[self.walkthroughIndex]
    self.walkthroughProgress:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_PROGRESS,
        report.complete,
        report.total,
        self.walkthroughIndex
    ))
    if not step then return end
    self.walkthroughPhase:SetText(step.phaseProgress or step.phase)
    self.walkthroughStatus:SetText(GetString(step.complete
        and SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_COMPLETE
        or SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_INCOMPLETE))
    self.walkthroughStatus:SetColor(step.complete and 0.55 or 1, step.complete and 0.9 or 0.65,
        step.complete and 0.45 or 0.25, 1)
    self.walkthroughStepTitle:SetText(step.title)
    self.walkthroughPlanned:SetText(step.planned)
    self.walkthroughCurrent:SetText(step.current)
    self.walkthroughInstruction:SetText(step.instruction)
    self.walkthroughOpen:SetText(GetString(
        step.actionLabel or SI_GRAVVY_BUILD_PLANNER_WALKTHROUGH_OPEN_STEP
    ))
    self.walkthroughPrevious:SetEnabled(self.walkthroughIndex > 1)
    self.walkthroughNext:SetEnabled(self.walkthroughIndex < report.total)
    self.walkthroughNextNeeded:SetEnabled(report.complete < report.total)
end

function UI:PageWalkthrough(direction)
    self.walkthroughIndex = zo_clamp(
        (self.walkthroughIndex or 1) + direction,
        1,
        math.max(1, self.walkthroughReport and self.walkthroughReport.total or 1)
    )
    self:RefreshWalkthrough()
end

function UI:NextNeededWalkthrough()
    local report = self.walkthroughReport
    if not report or report.total == 0 then return end
    for offset = 1, report.total do
        local index = ((self.walkthroughIndex - 1 + offset) % report.total) + 1
        if not report.steps[index].complete then
            self.walkthroughIndex = index
            self:RefreshWalkthrough()
            return
        end
    end
end

function UI:OpenWalkthroughStep()
    local step = self.walkthroughReport
        and self.walkthroughReport.steps[self.walkthroughIndex]
    if not step then return end
    self.walkthroughDialog:SetHidden(true)
    if step.action == "readiness" then
        self:OpenReadiness(step.value)
    elseif step.action == "assumptions" then
        self:OpenBuffAssumptions()
    elseif step.action == "skills" then
        self.selectedSkillBar = step.value or self.selectedSkillBar
        self.selectedSkillSlot = 1
        self:SetView("skills")
    elseif step.action == "checklist" then
        self.selectedChecklistIndex = step.value
        if step.value then
            local rowCount = #self.checklistRows
            if rowCount > 0 then
                self.checklistOffset = math.floor((step.value - 1) / rowCount) * rowCount
            end
        end
        self:SetView("checklist")
    elseif step.action == "champion" then
        self:SetView("champion")
    elseif step.action == "statImpact" then
        self:OpenStatImpact()
        self:SelectStatImpactBar(step.value)
    end
end
