local UI = GravvyBuildPlannerUI
local ROWS = 8

local function label(parent, text, x, y, width, height, font)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    GravvyBuildPlannerAccessibility:SetFont(control, font or "ZoFontGame")
    control:SetColor(0.88, 0.86, 0.8, 1)
    control:SetText(text or "")
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    control:SetDimensions(width, height)
    GravvyBuildPlannerAccessibility:RegisterTextGeometry(control, width, height)
    control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
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
    control:SetPressedFontColor(0.65, 0.55, 0.35, 1)
    return control
end

function UI:CreateReadinessDialog()
    local dialog = WINDOW_MANAGER:CreateTopLevelWindow("GravvyBuildPlannerReadinessWindow")
    dialog:SetDimensions(1040, 700)
    dialog:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    dialog:SetClampedToScreen(true)
    dialog:SetMouseEnabled(true)
    dialog:SetMovable(true)
    dialog:SetDrawTier(DT_HIGH)
    dialog:SetHidden(true)
    self.readinessDialog = dialog
    self.readinessOffset = 0
    self:RegisterDialog(dialog)
    local backdrop = GravvyBuildPlannerUIHelpers:CreateFromVirtual(
        dialog, "ZO_DefaultBackdrop", "ReadinessBackdrop"
    )
    backdrop:SetAnchorFill(dialog)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop, { 0.025, 0.025, 0.034, 0.99 }, { 0.5, 0.42, 0.28, 0.95 }
    )
    local title = label(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_READINESS_TITLE),
        18, 8, 420, 34, "ZoFontWinH2")
    title:SetMouseEnabled(true)
    title:SetHandler("OnMouseDown", function(_, mouseButton)
        if mouseButton == MOUSE_BUTTON_INDEX_LEFT then dialog:StartMoving() end
    end)
    title:SetHandler("OnMouseUp", function(_, mouseButton)
        if mouseButton == MOUSE_BUTTON_INDEX_LEFT then dialog:StopMovingOrResizing() end
    end)
    self.readinessSummary = label(dialog, "", 20, 50, 1000, 30, "ZoFontGameBold")
    self.readinessRoutes = label(dialog, "", 20, 82, 1000, 30, "ZoFontGame")
    self.readinessMaterials = label(dialog, "", 20, 114, 1000, 44, "ZoFontGameSmall")
    self.readinessShopping = label(dialog, "", 20, 154, 1000, 30, "ZoFontGameSmall")

    local headers = {
        { SI_GRAVVY_BUILD_PLANNER_READINESS_COLUMN_SLOT, 8, 132 },
        { SI_GRAVVY_BUILD_PLANNER_READINESS_COLUMN_STATUS, 142, 112 },
        { SI_GRAVVY_BUILD_PLANNER_READINESS_COLUMN_ROUTE, 258, 118 },
        { SI_GRAVVY_BUILD_PLANNER_READINESS_COLUMN_LOCATION, 380, 140 },
        { SI_GRAVVY_BUILD_PLANNER_READINESS_COLUMN_WORK, 524, 468 },
    }
    local header = WINDOW_MANAGER:CreateControl(nil, dialog, CT_CONTROL)
    header:SetAnchor(TOPLEFT, dialog, TOPLEFT, 20, 188)
    header:SetDimensions(1000, 30)
    for _, entry in ipairs(headers) do
        label(header, GetString(entry[1]), entry[2], 0, entry[3], 30, "ZoFontGameBold")
    end
    self.readinessRows = {}
    for index = 1, ROWS do
        local row = WINDOW_MANAGER:CreateControl(nil, dialog, CT_CONTROL)
        row:SetAnchor(TOPLEFT, dialog, TOPLEFT, 20, 222 + ((index - 1) * 52))
        row:SetDimensions(1000, 48)
        local rowBackdrop = GravvyBuildPlannerUIHelpers:CreateFromVirtual(
            row, "ZO_DefaultBackdrop", "ReadinessRowBackdrop"
        )
        rowBackdrop:SetAnchorFill(row)
        local shade = index % 2 == 0 and 0.035 or 0.018
        rowBackdrop:SetCenterColor(shade, shade, shade + 0.008, 0.9)
        row.slot = label(row, "", 8, 0, 132, 48, "ZoFontGameSmall")
        row.status = label(row, "", 142, 0, 112, 48, "ZoFontGameSmall")
        row.route = label(row, "", 258, 0, 118, 48, "ZoFontGameSmall")
        row.location = label(row, "", 380, 0, 140, 48, "ZoFontGameSmall")
        row.work = label(row, "", 524, 0, 468, 48, "ZoFontGameSmall")
        self.readinessRows[index] = row
    end
    local previous = button(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_PREVIOUS), 100)
    previous:SetAnchor(BOTTOMLEFT, dialog, BOTTOMLEFT, 18, -14)
    previous:SetHandler("OnClicked", function() self:PageReadiness(-1) end)
    local nextPage = button(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_NEXT), 100)
    nextPage:SetAnchor(LEFT, previous, RIGHT, 8, 0)
    nextPage:SetHandler("OnClicked", function() self:PageReadiness(1) end)
    self.readinessPage = label(dialog, "", 236, 654, 220, 28, "ZoFontGameSmall")
    local shopping = button(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT), 150)
    shopping:SetAnchor(BOTTOMRIGHT, dialog, BOTTOMRIGHT, -120, -14)
    shopping:SetHandler("OnClicked", function() self:OpenExportDialog() end)
    local close = button(dialog, GetString(SI_DIALOG_CLOSE), 90)
    close:SetAnchor(BOTTOMRIGHT, dialog, BOTTOMRIGHT, -18, -14)
    close:SetHandler("OnClicked", function() dialog:SetHidden(true) end)
end

function UI:OpenReadiness()
    self.readinessOffset = 0
    self.readinessDialog:SetHidden(false)
    self:RefreshReadiness()
end

function UI:RefreshReadiness()
    local setup = self.owner.data:GetCurrentSetup()
    local report = self.owner.readiness:BuildReport(setup)
    self.readinessReport = report
    self.readinessSummary:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_READINESS_SUMMARY,
        report.ready, report.adjustable, report.missing, report.conflicting
    ))
    self.readinessRoutes:SetText(self.owner.readiness:FormatRoutes(report))
    self.readinessMaterials:SetText(self.owner.readiness:FormatMaterials(report))
    self.readinessShopping:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_READINESS_BUYABLE,
        report.shopping.included,
        report.shopping.glyphs
    ))
    local lastOffset = #report.entries > 0
        and math.floor((#report.entries - 1) / ROWS) * ROWS or 0
    self.readinessOffset = zo_clamp(self.readinessOffset, 0, lastOffset)
    local statusIds = {
        ready = SI_GRAVVY_BUILD_PLANNER_READINESS_READY,
        adjustable = SI_GRAVVY_BUILD_PLANNER_READINESS_ADJUSTABLE,
        missing = SI_GRAVVY_BUILD_PLANNER_READINESS_MISSING,
        conflicting = SI_GRAVVY_BUILD_PLANNER_READINESS_CONFLICTING,
    }
    for index, row in ipairs(self.readinessRows) do
        local entry = report.entries[self.readinessOffset + index]
        row:SetHidden(not entry)
        if entry then
            row.slot:SetText(entry.slot)
            row.status:SetText(GetString(statusIds[entry.status]))
            row.route:SetText(self.owner.acquisition:GetRouteLabel(entry.route))
            row.location:SetText(entry.location)
            row.work:SetText(entry.work)
        end
    end
    local first = #report.entries == 0 and 0 or self.readinessOffset + 1
    local last = math.min(#report.entries, self.readinessOffset + ROWS)
    self.readinessPage:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CHAMPION_PAGE, first, last, #report.entries
    ))
end

function UI:PageReadiness(direction)
    local entries = self.readinessReport and self.readinessReport.entries or {}
    local lastOffset = #entries > 0
        and math.floor((#entries - 1) / ROWS) * ROWS or 0
    self.readinessOffset = zo_clamp(
        self.readinessOffset + (direction * ROWS), 0, lastOffset
    )
    self:RefreshReadiness()
end
