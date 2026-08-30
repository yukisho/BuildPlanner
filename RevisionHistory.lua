local UI = GravvyBuildPlannerUI
local ROW_COUNT = 9

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

local function savedDate(timestamp)
    if GetDateStringFromTimestamp then
        return GetDateStringFromTimestamp(timestamp)
    end
    return tostring(timestamp or "")
end

function UI:CreateRevisionDialog()
    local dialog = WINDOW_MANAGER:CreateTopLevelWindow(
        "GravvyBuildPlannerRevisionDialog"
    )
    dialog:SetDimensions(720, 560)
    dialog:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    dialog:SetClampedToScreen(true)
    dialog:SetMouseEnabled(true)
    dialog:SetHidden(true)
    dialog:SetDrawTier(DT_HIGH)
    self.revisionDialog = dialog
    self:RegisterDialog(dialog)
    self.revisionOffset = 0

    local backdrop = GravvyBuildPlannerUIHelpers:CreateFromVirtual(
        dialog,
        "ZO_DefaultBackdrop",
        "RevisionDialogBackdrop"
    )
    backdrop:SetAnchorFill(dialog)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.025, 0.025, 0.035, 1 },
        { 0.5, 0.42, 0.28, 1 }
    )

    makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_REVISION_TITLE),
        18,
        10,
        684,
        "ZoFontWinH2"
    )
    local help = makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_REVISION_HELP),
        20,
        45,
        680,
        "ZoFontGameSmall"
    )
    help:SetHeight(58)
    help:SetVerticalAlignment(TEXT_ALIGN_TOP)

    local save = makeButton(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_REVISION_SAVE),
        170
    )
    save:SetAnchor(TOPLEFT, dialog, TOPLEFT, 20, 106)
    save:SetHandler("OnClicked", function() self:SaveCurrentRevision() end)
    self.revisionCountLabel = makeLabel(
        dialog,
        "",
        500,
        106,
        200,
        "ZoFontGameSmall"
    )
    self.revisionCountLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    local divider = WINDOW_MANAGER:CreateControl(nil, dialog, CT_TEXTURE)
    divider:SetAnchor(TOPLEFT, dialog, TOPLEFT, 370, 145)
    divider:SetDimensions(1, 350)
    divider:SetColor(0.5, 0.42, 0.28, 0.7)

    self.revisionRows = {}
    for index = 1, ROW_COUNT do
        local row = makeButton(dialog, "", 330)
        row:SetHeight(32)
        row:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        row:SetAnchor(TOPLEFT, dialog, TOPLEFT, 20, 145 + ((index - 1) * 36))
        row:SetHandler("OnClicked", function() self:SelectRevisionRow(index) end)
        self.revisionRows[index] = row
    end

    self.revisionDetailTitle = makeLabel(dialog, "", 394, 150, 300, "ZoFontWinH3")
    self.revisionPatchLabel = makeLabel(dialog, "", 394, 198, 300)
    self.revisionDateLabel = makeLabel(dialog, "", 394, 234, 300)
    self.revisionSetupLabel = makeLabel(dialog, "", 394, 270, 300)
    self.revisionEmptyLabel = makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_REVISION_EMPTY),
        394,
        320,
        300,
        "ZoFontWinH3"
    )

    local previous = makeButton(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_PREVIOUS),
        100
    )
    previous:SetAnchor(BOTTOMLEFT, dialog, BOTTOMLEFT, 20, -14)
    previous:SetHandler("OnClicked", function() self:PageRevisions(-1) end)
    local nextPage = makeButton(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_NEXT),
        100
    )
    nextPage:SetAnchor(LEFT, previous, RIGHT, 8, 0)
    nextPage:SetHandler("OnClicked", function() self:PageRevisions(1) end)

    self.revisionDeleteButton = makeButton(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_REVISION_DELETE),
        150
    )
    self.revisionDeleteButton:SetAnchor(
        BOTTOMRIGHT,
        dialog,
        BOTTOMRIGHT,
        -248,
        -14
    )
    self.revisionDeleteButton:SetHandler("OnClicked", function()
        self:ConfirmDeleteRevision()
    end)
    self.revisionRestoreButton = makeButton(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_REVISION_RESTORE),
        110
    )
    self.revisionRestoreButton:SetAnchor(
        LEFT,
        self.revisionDeleteButton,
        RIGHT,
        8,
        0
    )
    self.revisionRestoreButton:SetHandler("OnClicked", function()
        self:ConfirmRestoreRevision()
    end)
    local close = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_CLOSE), 100)
    close:SetAnchor(BOTTOMRIGHT, dialog, BOTTOMRIGHT, -18, -14)
    close:SetHandler("OnClicked", function() dialog:SetHidden(true) end)
end

function UI:OpenRevisionDialog()
    self.revisionOffset = 0
    local build = self.owner.data:GetCurrentBuild()
    local revisions = self.owner.data:GetRevisions(build.id)
    self.selectedRevisionId = revisions[1] and revisions[1].id
    self:RefreshRevisionDialog()
    self.revisionDialog:SetHidden(false)
end

function UI:GetSelectedRevision()
    local build = self.owner.data:GetCurrentBuild()
    return self.owner.data:FindRevision(build, self.selectedRevisionId)
end

function UI:RefreshRevisionDialog()
    local build = self.owner.data:GetCurrentBuild()
    local revisions = self.owner.data:GetRevisions(build.id)
    local lastOffset = #revisions > 0
        and math.floor((#revisions - 1) / ROW_COUNT) * ROW_COUNT
        or 0
    self.revisionOffset = zo_clamp(self.revisionOffset or 0, 0, lastOffset)
    if not self.owner.data:FindRevision(build, self.selectedRevisionId) then
        self.selectedRevisionId = revisions[1] and revisions[1].id
    end

    for rowIndex = 1, ROW_COUNT do
        local row = self.revisionRows[rowIndex]
        local revision = revisions[self.revisionOffset + rowIndex]
        row.revisionId = revision and revision.id
        row:SetHidden(not revision)
        if revision then
            local patch = revision.patch ~= "" and (" - " .. revision.patch) or ""
            row:SetText(revision.name .. patch)
            row:SetAlpha(revision.id == self.selectedRevisionId and 1 or 0.72)
        end
    end

    local revision = self:GetSelectedRevision()
    local hasRevision = revision ~= nil
    self.revisionEmptyLabel:SetHidden(hasRevision)
    self.revisionDetailTitle:SetHidden(not hasRevision)
    self.revisionPatchLabel:SetHidden(not hasRevision)
    self.revisionDateLabel:SetHidden(not hasRevision)
    self.revisionSetupLabel:SetHidden(not hasRevision)
    self.revisionRestoreButton:SetEnabled(hasRevision)
    self.revisionDeleteButton:SetEnabled(hasRevision)
    if revision then
        self.revisionDetailTitle:SetText(revision.name)
        self.revisionPatchLabel:SetText(zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_REVISION_PATCH,
            revision.patch ~= "" and revision.patch
                or GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED)
        ))
        self.revisionDateLabel:SetText(zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_REVISION_DATE,
            savedDate(revision.createdAt)
        ))
        self.revisionSetupLabel:SetText(zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_REVISION_SETUP_COUNT,
            #revision.snapshot.setups
        ))
    end
    self.revisionCountLabel:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_REVISION_COUNT,
        #revisions,
        20
    ))
end

function UI:SelectRevisionRow(rowIndex)
    local row = self.revisionRows[rowIndex]
    if row and row.revisionId then
        self.selectedRevisionId = row.revisionId
        self:RefreshRevisionDialog()
    end
end

function UI:PageRevisions(direction)
    self.revisionOffset = self.revisionOffset + (direction * ROW_COUNT)
    self:RefreshRevisionDialog()
    local firstRow = self.revisionRows[1]
    if firstRow and firstRow.revisionId then
        self.selectedRevisionId = firstRow.revisionId
        self:RefreshRevisionDialog()
    end
end

function UI:SaveCurrentRevision()
    local build = self.owner.data:GetCurrentBuild()
    self:OpenNameDialog("", function(name)
        local revision, message = self.owner.data:CreateRevision(build.id, name)
        if revision then
            self.selectedRevisionId = revision.id
            self.revisionOffset = 0
            self:RefreshRevisionDialog()
        end
        return revision, message
    end, SI_GRAVVY_BUILD_PLANNER_REVISION_NAME)
end

function UI:ConfirmRestoreRevision()
    local revision = self:GetSelectedRevision()
    if not revision then
        return
    end
    self:OpenConfirm(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CONFIRM_RESTORE_REVISION,
        revision.name
    ), function()
        local build = self.owner.data:GetCurrentBuild()
        local restored, message = self.owner.data:RestoreRevision(
            build.id,
            revision.id
        )
        if restored then
            self.owner.setCatalog:Refresh()
            self.owner.consumableCatalog:RefreshSaved()
            self.owner.inventory:RefreshSetup()
            self:Refresh()
            self:RefreshRevisionDialog()
            self:SetStatus(message)
        end
        return restored, message
    end, true, SI_GRAVVY_BUILD_PLANNER_REVISION_RESTORE)
end

function UI:ConfirmDeleteRevision()
    local revision = self:GetSelectedRevision()
    if not revision then
        return
    end
    self:OpenConfirm(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CONFIRM_DELETE_REVISION,
        revision.name
    ), function()
        local build = self.owner.data:GetCurrentBuild()
        local ok, message = self.owner.data:DeleteRevision(build.id, revision.id)
        if ok then
            self.selectedRevisionId = nil
            self:RefreshRevisionDialog()
            self:SetStatus(message)
        end
        return ok, message
    end, true, SI_GRAVVY_BUILD_PLANNER_REVISION_DELETE)
end
