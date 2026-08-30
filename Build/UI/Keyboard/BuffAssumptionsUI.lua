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

local function edit(parent, purpose, x, y, width, height, multiline)
    local control = GravvyBuildPlannerUIHelpers:CreateFromVirtual(
        parent,
        "ZO_DefaultEditForBackdrop",
        purpose
    )
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    control:SetDimensions(width, height)
    control:SetMaxInputChars(multiline and 4000 or 512)
    control:SetNewLineEnabled(multiline == true)
    control:SetSelectAllOnFocus(true)
    GravvyBuildPlannerAccessibility:SetFont(control, "ZoFontGame")
    return control
end

function UI:CreateBuffAssumptionsDialog()
    local dialog = WINDOW_MANAGER:CreateTopLevelWindow(
        "GravvyBuildPlannerBuffAssumptionsWindow"
    )
    dialog:SetDimensions(780, 690)
    dialog:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    dialog:SetClampedToScreen(true)
    dialog:SetMouseEnabled(true)
    dialog:SetMovable(true)
    dialog:SetDrawTier(DT_HIGH)
    dialog:SetHidden(true)
    self.buffAssumptionsDialog = dialog
    self:RegisterDialog(dialog)

    local backdrop = GravvyBuildPlannerUIHelpers:CreateFromVirtual(
        dialog, "ZO_DefaultBackdrop", "BuffAssumptionsBackdrop"
    )
    backdrop:SetAnchorFill(dialog)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop, { 0.025, 0.025, 0.034, 0.99 }, { 0.5, 0.42, 0.28, 0.95 }
    )
    label(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_TITLE),
        18, 10, 744, 34, "ZoFontWinH2")
    label(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_HELP),
        18, 48, 744, 48, "ZoFontGameSmall")

    local fields = {
        { key = "food", id = SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_FOOD, y = 106, h = 36 },
        { key = "potion", id = SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_POTION, y = 158, h = 36 },
        { key = "selfBuffs", id = SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_SELF, y = 210, h = 94, list = true },
        { key = "groupBuffs", id = SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_GROUP, y = 320, h = 94, list = true },
        { key = "targetConditions", id = SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_TARGET, y = 430, h = 150, list = true },
    }
    self.buffAssumptionEdits = {}
    for _, field in ipairs(fields) do
        label(dialog, GetString(field.id), 20, field.y, 170, 30, "ZoFontGame")
        self.buffAssumptionEdits[field.key] = edit(
            dialog,
            "BuffAssumption" .. field.key,
            196,
            field.y,
            562,
            field.h,
            field.list
        )
    end
    label(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_LIST_HELP),
        196, 586, 562, 34, "ZoFontGameSmall")
    local save = button(dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_SAVE), 120)
    save:SetAnchor(BOTTOMRIGHT, dialog, BOTTOMRIGHT, -112, -14)
    save:SetHandler("OnClicked", function() self:SaveBuffAssumptions() end)
    local close = button(dialog, GetString(SI_DIALOG_CLOSE), 90)
    close:SetAnchor(BOTTOMRIGHT, dialog, BOTTOMRIGHT, -18, -14)
    close:SetHandler("OnClicked", function() dialog:SetHidden(true) end)
end

function UI:OpenBuffAssumptions(setupId)
    local build = self.owner.data:GetCurrentBuild()
    local setup = setupId and self.owner.data:FindSetup(build, setupId)
        or self.owner.data:GetCurrentSetup()
    self.buffAssumptionSetupId = setup.id
    local values = setup.buffAssumptions or {}
    self.buffAssumptionEdits.food:SetText(values.food or "")
    self.buffAssumptionEdits.potion:SetText(values.potion or "")
    self.buffAssumptionEdits.selfBuffs:SetText(
        GravvyBuildPlannerBuffAssumptions:Join(values.selfBuffs)
    )
    self.buffAssumptionEdits.groupBuffs:SetText(
        GravvyBuildPlannerBuffAssumptions:Join(values.groupBuffs)
    )
    self.buffAssumptionEdits.targetConditions:SetText(
        GravvyBuildPlannerBuffAssumptions:Join(values.targetConditions)
    )
    self.buffAssumptionsDialog:SetHidden(false)
end

function UI:SaveBuffAssumptions()
    local build = self.owner.data:GetCurrentBuild()
    local setup = self.owner.data:FindSetup(build, self.buffAssumptionSetupId)
    if not setup then return end
    local ok, message = self.owner.data:SetBuffAssumptions(build.id, setup.id, {
        food = self.buffAssumptionEdits.food:GetText(),
        potion = self.buffAssumptionEdits.potion:GetText(),
        selfBuffs = GravvyBuildPlannerBuffAssumptions:Split(
            self.buffAssumptionEdits.selfBuffs:GetText()
        ),
        groupBuffs = GravvyBuildPlannerBuffAssumptions:Split(
            self.buffAssumptionEdits.groupBuffs:GetText()
        ),
        targetConditions = GravvyBuildPlannerBuffAssumptions:Split(
            self.buffAssumptionEdits.targetConditions:GetText()
        ),
    })
    if not ok then
        self:SetStatus(message, true)
        return
    end
    self.buffAssumptionsDialog:SetHidden(true)
    if self.statImpactDialog and not self.statImpactDialog:IsHidden() then
        self:RefreshStatImpact()
    end
    if self.activeView == "comparison" then self:RefreshComparisonPlanner() end
    self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_SAVED))
end
