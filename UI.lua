GravvyBuildPlannerUI = {}

local UI = GravvyBuildPlannerUI
local Slots = GravvyBuildPlannerSlots
local WINDOW_WIDTH = 980
local WINDOW_HEIGHT = 700
local SLOT_ROW_HEIGHT = 35
local SUGGESTION_ROWS = 6
local DEFAULT_VALUE = -1

local slotStringIds = {
    head = SI_GRAVVY_BUILD_PLANNER_SLOT_HEAD,
    shoulders = SI_GRAVVY_BUILD_PLANNER_SLOT_SHOULDERS,
    chest = SI_GRAVVY_BUILD_PLANNER_SLOT_CHEST,
    hands = SI_GRAVVY_BUILD_PLANNER_SLOT_HANDS,
    waist = SI_GRAVVY_BUILD_PLANNER_SLOT_WAIST,
    legs = SI_GRAVVY_BUILD_PLANNER_SLOT_LEGS,
    feet = SI_GRAVVY_BUILD_PLANNER_SLOT_FEET,
    neck = SI_GRAVVY_BUILD_PLANNER_SLOT_NECK,
    ring1 = SI_GRAVVY_BUILD_PLANNER_SLOT_RING1,
    ring2 = SI_GRAVVY_BUILD_PLANNER_SLOT_RING2,
    frontMain = SI_GRAVVY_BUILD_PLANNER_SLOT_FRONTMAIN,
    frontOff = SI_GRAVVY_BUILD_PLANNER_SLOT_FRONTOFF,
    backMain = SI_GRAVVY_BUILD_PLANNER_SLOT_BACKMAIN,
    backOff = SI_GRAVVY_BUILD_PLANNER_SLOT_BACKOFF,
}

local function slotName(slotKey)
    return GetString(slotStringIds[slotKey])
end

local function makeLabel(parent, text, x, y, width, font)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(font or "ZoFontGame")
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
    button:SetFont("ZoFontGame")
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
    edit:SetFont("ZoFontGame")
    edit:SetMaxInputChars(maxChars or 100)
    edit:SetNewLineEnabled(false)
    edit:SetSelectAllOnFocus(true)
    if numeric then
        edit:SetTextType(TEXT_TYPE_NUMERIC)
    end
    return edit, backdrop
end

local function makeNoteEdit(parent, name, x, y, width, height)
    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(name .. "Backdrop", parent, "ZO_EditBackdrop")
    backdrop:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    backdrop:SetDimensions(width, height)

    local edit = WINDOW_MANAGER:CreateControlFromVirtual(
        name,
        backdrop,
        "ZO_DefaultEditMultiLineForBackdrop"
    )
    edit:ClearAnchors()
    edit:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 5, 4)
    edit:SetAnchor(BOTTOMRIGHT, backdrop, BOTTOMRIGHT, -5, -4)
    edit:SetFont("ZoFontGame")
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
    return combo, container
end

local function setComboChoices(combo, choices, selectedValue, onChanged)
    combo:ClearItems()
    combo.selectedValue = selectedValue
    local selectedLabel
    for _, choice in ipairs(choices) do
        local label = choice.label
        local value = choice.value
        combo:AddItem(combo:CreateItemEntry(label, function()
            combo.selectedValue = value
            if onChanged then
                onChanged(value)
            end
        end))
        if value == selectedValue then
            selectedLabel = label
        end
    end
    if not selectedLabel and choices[1] then
        combo.selectedValue = choices[1].value
        selectedLabel = choices[1].label
    end
    combo:SetSelectedItem(selectedLabel or "")
end

local function addEnumChoice(choices, stringTable, value)
    if value == nil then
        return
    end
    local label = GetString(stringTable, value)
    if label and label ~= "" then
        choices[#choices + 1] = { label = label, value = value }
    end
end

local function getTypeChoices(slotKey)
    local definition = Slots:Get(slotKey)
    local choices = {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_ANY_TYPE), value = 0 },
    }
    if definition.family == "armor" then
        addEnumChoice(choices, "SI_ARMORTYPE", ARMORTYPE_LIGHT)
        addEnumChoice(choices, "SI_ARMORTYPE", ARMORTYPE_MEDIUM)
        addEnumChoice(choices, "SI_ARMORTYPE", ARMORTYPE_HEAVY)
    elseif definition.family == "weapon" then
        local weaponTypes = {
            WEAPONTYPE_AXE,
            WEAPONTYPE_HAMMER,
            WEAPONTYPE_SWORD,
            WEAPONTYPE_DAGGER,
            WEAPONTYPE_SHIELD,
            WEAPONTYPE_TWO_HANDED_AXE,
            WEAPONTYPE_TWO_HANDED_HAMMER,
            WEAPONTYPE_TWO_HANDED_SWORD,
            WEAPONTYPE_BOW,
            WEAPONTYPE_FIRE_STAFF,
            WEAPONTYPE_FROST_STAFF,
            WEAPONTYPE_LIGHTNING_STAFF,
            WEAPONTYPE_HEALING_STAFF,
        }
        for _, weaponType in ipairs(weaponTypes) do
            if Slots:IsRequirementCompatible(slotKey, { weaponType = weaponType }) then
                addEnumChoice(choices, "SI_WEAPONTYPE", weaponType)
            end
        end
    end
    return choices
end

local function getArmorTypeChoices(armorTypes)
    local choices = {}
    for _, armorType in ipairs(armorTypes) do
        addEnumChoice(choices, "SI_ARMORTYPE", armorType)
    end
    return choices
end

local function getTraitChoices(family)
    local choices = {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_ANY_TRAIT), value = ITEM_TRAIT_TYPE_NONE },
    }
    if not GetItemTraitTypeCategory then
        return choices
    end

    local category = family == "armor" and ITEM_TRAIT_TYPE_CATEGORY_ARMOR
        or family == "weapon" and ITEM_TRAIT_TYPE_CATEGORY_WEAPON
        or ITEM_TRAIT_TYPE_CATEGORY_JEWELRY
    local first = ITEM_TRAIT_TYPE_ITERATION_BEGIN or 1
    local last = ITEM_TRAIT_TYPE_ITERATION_END or 64
    local traits = {}
    for traitType = first, last do
        if traitType ~= ITEM_TRAIT_TYPE_NONE and GetItemTraitTypeCategory(traitType) == category then
            local label = GetString("SI_ITEMTRAITTYPE", traitType)
            if label and label ~= "" then
                traits[#traits + 1] = { label = label, value = traitType }
            end
        end
    end
    table.sort(traits, function(left, right) return left.label < right.label end)
    for _, trait in ipairs(traits) do
        choices[#choices + 1] = trait
    end
    return choices
end

local function getQualityChoices()
    local choices = {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_DEFAULT), value = DEFAULT_VALUE },
    }
    for _, quality in ipairs({
        ITEM_QUALITY_NORMAL,
        ITEM_QUALITY_MAGIC,
        ITEM_QUALITY_ARCANE,
        ITEM_QUALITY_ARTIFACT,
        ITEM_QUALITY_LEGENDARY,
    }) do
        addEnumChoice(choices, "SI_ITEMQUALITY", quality)
    end
    return choices
end

function UI:New(owner)
    return setmetatable({
        owner = owner,
        rows = {},
        selectedSlot = "head",
        suggestions = {},
        suggestionOffset = 0,
        suggestionIndex = 1,
    }, { __index = self })
end

function UI:Initialize()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("GravvyBuildPlannerWindow")
    window:SetDimensions(WINDOW_WIDTH, WINDOW_HEIGHT)
    local geometry = self.owner.data:GetSettings().window
    if geometry.left and geometry.top then
        window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, geometry.left, geometry.top)
    else
        window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    window:SetClampedToScreen(true)
    window:SetMouseEnabled(true)
    window:SetMovable(true)
    window:SetHidden(true)
    window:SetHandler("OnMoveStop", function() self:SavePosition() end)
    self.window = window

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, window, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(window)
    backdrop:SetCenterColor(0.035, 0.035, 0.045, 0.98)
    backdrop:SetEdgeColor(0.5, 0.42, 0.28, 0.95)

    local title = makeLabel(window, GetString(SI_GRAVVY_BUILD_PLANNER_TITLE), 18, 8, 280, "ZoFontWinH2")
    title:SetMouseEnabled(true)
    title:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            window:StartMoving()
        end
    end)
    title:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            window:StopMovingOrResizing()
            self:SavePosition()
        end
    end)

    local close = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_CLOSE), 70)
    close:SetAnchor(TOPRIGHT, window, TOPRIGHT, -14, 10)
    close:SetHandler("OnClicked", function() self:Hide() end)

    local undo = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_UNDO), 110)
    undo:SetAnchor(TOPRIGHT, close, TOPLEFT, -8, 0)
    undo:SetHandler("OnClicked", function() self:UndoDeletion() end)

    self:CreateBuildControls()
    self:CreateSlotRows()
    self:CreateEditor()
    self:CreateNameDialog()
    self:CreateConfirmDialog()
    self:CreateSlotActionDialog()

    self.status = makeLabel(window, "", 18, 661, WINDOW_WIDTH - 36, "ZoFontGameSmall")
    self:Refresh()
end

function UI:CreateBuildControls()
    local window = self.window
    makeLabel(window, GetString(SI_GRAVVY_BUILD_PLANNER_BUILD), 18, 46, 65)
    self.buildCombo = makeCombo(window, "GravvyBuildPlannerBuildCombo", 82, 46, 275)

    local buildNew = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_NEW), 58)
    buildNew:SetAnchor(TOPLEFT, window, TOPLEFT, 367, 47)
    buildNew:SetHandler("OnClicked", function()
        self:OpenNameDialog("", function(name)
            return self.owner.data:CreateBuild(name)
        end)
    end)
    local buildCopy = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_COPY), 58)
    buildCopy:SetAnchor(LEFT, buildNew, RIGHT, 4, 0)
    buildCopy:SetHandler("OnClicked", function()
        local build = self.owner.data:GetCurrentBuild()
        local result, message = self.owner.data:DuplicateBuild(build.id)
        self:FinishAction(result, message)
    end)
    local buildRename = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_RENAME), 76)
    buildRename:SetAnchor(LEFT, buildCopy, RIGHT, 4, 0)
    buildRename:SetHandler("OnClicked", function()
        local build = self.owner.data:GetCurrentBuild()
        self:OpenNameDialog(build.name, function(name)
            return self.owner.data:RenameBuild(build.id, name)
        end)
    end)
    local buildDelete = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_DELETE), 68)
    buildDelete:SetAnchor(LEFT, buildRename, RIGHT, 4, 0)
    buildDelete:SetHandler("OnClicked", function()
        local build = self.owner.data:GetCurrentBuild()
        self:OpenConfirm(zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_CONFIRM_DELETE_BUILD,
            build.name
        ), function()
            return self.owner.data:DeleteBuild(build.id)
        end)
    end)

    makeLabel(window, GetString(SI_GRAVVY_BUILD_PLANNER_SETUP), 18, 84, 65)
    self.setupCombo = makeCombo(window, "GravvyBuildPlannerSetupCombo", 82, 84, 275)

    local setupNew = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_NEW), 58)
    setupNew:SetAnchor(TOPLEFT, window, TOPLEFT, 367, 85)
    setupNew:SetHandler("OnClicked", function()
        local build = self.owner.data:GetCurrentBuild()
        self:OpenNameDialog("", function(name)
            return self.owner.data:CreateSetup(build.id, name)
        end)
    end)
    local setupCopy = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_COPY), 58)
    setupCopy:SetAnchor(LEFT, setupNew, RIGHT, 4, 0)
    setupCopy:SetHandler("OnClicked", function()
        local setup, build = self.owner.data:GetCurrentSetup()
        local result, message = self.owner.data:DuplicateSetup(build.id, setup.id)
        self:FinishAction(result, message)
    end)
    local setupRename = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_RENAME), 76)
    setupRename:SetAnchor(LEFT, setupCopy, RIGHT, 4, 0)
    setupRename:SetHandler("OnClicked", function()
        local setup, build = self.owner.data:GetCurrentSetup()
        self:OpenNameDialog(setup.name, function(name)
            return self.owner.data:RenameSetup(build.id, setup.id, name)
        end)
    end)
    local setupDelete = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_DELETE), 68)
    setupDelete:SetAnchor(LEFT, setupRename, RIGHT, 4, 0)
    setupDelete:SetHandler("OnClicked", function()
        local setup, build = self.owner.data:GetCurrentSetup()
        self:OpenConfirm(zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_CONFIRM_DELETE_SETUP,
            setup.name
        ), function()
            return self.owner.data:DeleteSetup(build.id, setup.id)
        end)
    end)

    local divider = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    divider:SetAnchor(TOPLEFT, window, TOPLEFT, 14, 124)
    divider:SetDimensions(WINDOW_WIDTH - 28, 1)
    divider:SetColor(0.5, 0.42, 0.28, 0.7)
end

function UI:CreateSlotRows()
    for index, slotKey in ipairs(Slots.ORDER) do
        local button = makeButton(self.window, "", 490)
        button:SetHeight(31)
        button:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        button:SetAnchor(TOPLEFT, self.window, TOPLEFT, 18, 137 + ((index - 1) * SLOT_ROW_HEIGHT))
        button:SetHandler("OnClicked", function() self:EditSlot(slotKey) end)
        button:SetHandler("OnMouseEnter", function(control) self:ShowSlotTooltip(slotKey, control) end)
        button:SetHandler("OnMouseExit", function() self:HideItemTooltip() end)
        self.rows[slotKey] = button
    end
end

function UI:CreateEditor()
    local panel = WINDOW_MANAGER:CreateControl("GravvyBuildPlannerEditor", self.window, CT_CONTROL)
    panel:SetAnchor(TOPRIGHT, self.window, TOPRIGHT, -18, 137)
    panel:SetDimensions(430, 490)
    self.editor = panel

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, panel, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(panel)
    backdrop:SetCenterColor(0.025, 0.025, 0.035, 0.92)
    backdrop:SetEdgeColor(0.32, 0.28, 0.2, 0.9)

    self.editorTitle = makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_SLOT_EDITOR), 14, 5, 402, "ZoFontWinH3")
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_SET), 14, 45, 105)
    self.setEdit = makeEdit(panel, "GravvyBuildPlannerSetEdit", 122, 45, 290)
    self.setEdit:SetHandler("OnTextChanged", function() self:OnSetTextChanged() end)
    self.setEdit:SetHandler("OnKeyDown", function(_, key) self:OnSetKeyDown(key) end)
    self.setEdit:SetHandler("OnFocusLost", function() self:ResolveTypedSet() end)

    self.typeLabel = makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_TYPE), 14, 85, 105)
    self.typeCombo, self.typeContainer = makeCombo(panel, "GravvyBuildPlannerTypeCombo", 122, 85, 290)

    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_TRAIT), 14, 125, 105)
    self.traitCombo = makeCombo(panel, "GravvyBuildPlannerTraitCombo", 122, 125, 290)

    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_ENCHANTMENT), 14, 165, 105)
    self.enchantmentCombo = makeCombo(panel, "GravvyBuildPlannerEnchantmentCombo", 122, 165, 290)

    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_QUALITY), 14, 205, 105)
    self.qualityCombo = makeCombo(panel, "GravvyBuildPlannerQualityCombo", 122, 205, 290)

    self.levelLabel = makeLabel(
        panel,
        GetString(SI_GRAVVY_BUILD_PLANNER_LEVEL),
        14,
        245,
        125,
        "ZoFontGameSmall"
    )
    self.levelEdit = makeEdit(panel, "GravvyBuildPlannerLevelEdit", 142, 245, 52, true, 3)
    self.cpLabel = makeLabel(
        panel,
        GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_POINTS),
        208,
        245,
        125,
        "ZoFontGameSmall"
    )
    self.cpEdit = makeEdit(panel, "GravvyBuildPlannerCPEdit", 340, 245, 72, true, 4)
    self.levelEdit:SetHandler("OnTextChanged", function()
        if not self.loadingEditor then
            self:RefreshEditorPreview()
        end
    end)
    self.cpEdit:SetHandler("OnTextChanged", function()
        if not self.loadingEditor then
            self:RefreshEditorPreview()
        end
    end)

    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_NOTES), 14, 285, 105)
    self.noteEdit = makeNoteEdit(panel, "GravvyBuildPlannerNoteEdit", 122, 285, 290, 82)

    self.previewButton = WINDOW_MANAGER:CreateControl(
        "GravvyBuildPlannerPreviewButton",
        panel,
        CT_BUTTON
    )
    self.previewButton:SetDimensions(48, 48)
    self.previewButton:SetAnchor(TOPLEFT, panel, TOPLEFT, 14, 370)
    self.previewButton:SetHandler("OnMouseEnter", function(control)
        if self.previewLink then
            self:ShowItemTooltip(control, self.previewLink, self.previewRequirement)
        end
    end)
    self.previewButton:SetHandler("OnMouseExit", function() self:HideItemTooltip() end)

    local previewBackdrop = WINDOW_MANAGER:CreateControlFromVirtual(
        nil,
        self.previewButton,
        "ZO_DefaultBackdrop"
    )
    previewBackdrop:SetAnchorFill(self.previewButton)
    previewBackdrop:SetCenterColor(0.025, 0.025, 0.035, 0.95)
    previewBackdrop:SetEdgeColor(0.5, 0.42, 0.28, 1)

    self.previewIcon = WINDOW_MANAGER:CreateControl(nil, self.previewButton, CT_TEXTURE)
    self.previewIcon:SetAnchorFill(self.previewButton)

    self.previewUnavailable = makeLabel(
        panel,
        GetString(SI_GRAVVY_BUILD_PLANNER_PREVIEW_UNAVAILABLE),
        72,
        382,
        344,
        "ZoFontGameSmall"
    )

    local save = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_SAVE), 120)
    save:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -14, -14)
    save:SetHandler("OnClicked", function() self:SaveSlot() end)
    local clear = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CLEAR), 120)
    clear:SetAnchor(RIGHT, save, LEFT, -8, 0)
    clear:SetHandler("OnClicked", function() self:ClearSlot() end)
    self.slotActionButton = makeButton(
        panel,
        GetString(SI_GRAVVY_BUILD_PLANNER_COPY_MOVE),
        120
    )
    self.slotActionButton:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 14, -14)
    self.slotActionButton:SetHandler("OnClicked", function() self:OpenSlotActionDialog() end)

    self:CreateSuggestions()
end

function UI:CreateSuggestions()
    local panel = WINDOW_MANAGER:CreateControl("GravvyBuildPlannerSuggestions", self.window, CT_CONTROL)
    panel:SetDimensions(290, (SUGGESTION_ROWS * 24) + 8)
    panel:SetAnchor(TOPLEFT, self.setEdit, BOTTOMLEFT, 0, 2)
    panel:SetHidden(true)
    panel:SetDrawTier(DT_HIGH)
    panel:SetMouseEnabled(true)
    panel:SetHandler("OnMouseWheel", function(_, delta) self:ScrollSuggestions(-delta) end)
    self.suggestionPanel = panel

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, panel, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(panel)
    backdrop:SetCenterColor(0.02, 0.02, 0.03, 1)
    backdrop:SetEdgeColor(0.5, 0.42, 0.28, 1)

    self.suggestionButtons = {}
    for index = 1, SUGGESTION_ROWS do
        local button = makeButton(panel, "", 280)
        button:SetHeight(24)
        button:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        button:SetAnchor(TOPLEFT, panel, TOPLEFT, 5, 4 + ((index - 1) * 24))
        button:SetHandler("OnClicked", function() self:ChooseSuggestion(index) end)
        button:SetHandler("OnMouseWheel", function(_, delta) self:ScrollSuggestions(-delta) end)
        self.suggestionButtons[index] = button
    end
end

function UI:CreateNameDialog()
    local dialog = WINDOW_MANAGER:CreateTopLevelWindow("GravvyBuildPlannerNameDialog")
    dialog:SetDimensions(390, 145)
    dialog:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    dialog:SetClampedToScreen(true)
    dialog:SetMouseEnabled(true)
    dialog:SetHidden(true)
    dialog:SetDrawTier(DT_HIGH)
    self.nameDialog = dialog

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, dialog, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(dialog)
    backdrop:SetCenterColor(0.035, 0.035, 0.045, 1)
    backdrop:SetEdgeColor(0.5, 0.42, 0.28, 1)
    makeLabel(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_ENTER_NAME), 18, 10, 350, "ZoFontWinH3")
    self.nameEdit = makeEdit(dialog, "GravvyBuildPlannerNameEdit", 18, 49, 354)

    local accept = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_SAVE_NAME), 100)
    accept:SetAnchor(BOTTOMRIGHT, dialog, BOTTOMRIGHT, -18, -13)
    accept:SetHandler("OnClicked", function() self:AcceptNameDialog() end)
    local cancel = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_CANCEL), 100)
    cancel:SetAnchor(RIGHT, accept, LEFT, -8, 0)
    cancel:SetHandler("OnClicked", function() dialog:SetHidden(true) end)
    self.nameEdit:SetHandler("OnEnter", function() self:AcceptNameDialog() end)
    self.nameEdit:SetHandler("OnEscape", function() dialog:SetHidden(true) end)
end

function UI:CreateConfirmDialog()
    local dialog = WINDOW_MANAGER:CreateTopLevelWindow("GravvyBuildPlannerConfirmDialog")
    dialog:SetDimensions(430, 165)
    dialog:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    dialog:SetClampedToScreen(true)
    dialog:SetMouseEnabled(true)
    dialog:SetHidden(true)
    dialog:SetDrawTier(DT_HIGH)
    self.confirmDialog = dialog

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, dialog, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(dialog)
    backdrop:SetCenterColor(0.035, 0.035, 0.045, 1)
    backdrop:SetEdgeColor(0.55, 0.25, 0.2, 1)
    self.confirmText = makeLabel(dialog, "", 20, 16, 390, "ZoFontWinH3")
    self.confirmText:SetHeight(70)
    self.confirmText:SetVerticalAlignment(TEXT_ALIGN_TOP)

    local accept = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_DELETE), 100)
    accept:SetAnchor(BOTTOMRIGHT, dialog, BOTTOMRIGHT, -18, -14)
    accept:SetHandler("OnClicked", function() self:AcceptConfirm() end)
    local cancel = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_CANCEL), 100)
    cancel:SetAnchor(RIGHT, accept, LEFT, -8, 0)
    cancel:SetHandler("OnClicked", function() dialog:SetHidden(true) end)
end

function UI:CreateSlotActionDialog()
    local dialog = WINDOW_MANAGER:CreateTopLevelWindow("GravvyBuildPlannerSlotActionDialog")
    dialog:SetDimensions(430, 180)
    dialog:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    dialog:SetClampedToScreen(true)
    dialog:SetMouseEnabled(true)
    dialog:SetHidden(true)
    dialog:SetDrawTier(DT_HIGH)
    self.slotActionDialog = dialog

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, dialog, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(dialog)
    backdrop:SetCenterColor(0.035, 0.035, 0.045, 1)
    backdrop:SetEdgeColor(0.5, 0.42, 0.28, 1)
    makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_COPY_MOVE_TITLE),
        18,
        10,
        394,
        "ZoFontWinH3"
    )
    makeLabel(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_DESTINATION), 18, 52, 105)
    self.slotTargetCombo = makeCombo(
        dialog,
        "GravvyBuildPlannerSlotTargetCombo",
        123,
        52,
        289
    )

    local move = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_MOVE), 100)
    move:SetAnchor(BOTTOMRIGHT, dialog, BOTTOMRIGHT, -18, -14)
    move:SetHandler("OnClicked", function() self:TransferSlot(true) end)
    local copy = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_COPY), 100)
    copy:SetAnchor(RIGHT, move, LEFT, -8, 0)
    copy:SetHandler("OnClicked", function() self:TransferSlot(false) end)
    local cancel = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_CANCEL), 100)
    cancel:SetAnchor(RIGHT, copy, LEFT, -8, 0)
    cancel:SetHandler("OnClicked", function() dialog:SetHidden(true) end)
end

function UI:RefreshBuildCombo()
    local current = self.owner.data:GetCurrentBuild()
    self.buildCombo:ClearItems()
    for _, build in ipairs(self.owner.data:GetBuilds()) do
        local buildId = build.id
        self.buildCombo:AddItem(self.buildCombo:CreateItemEntry(build.name, function()
            self.owner.data:SelectBuild(buildId)
            self:Refresh()
        end))
    end
    self.buildCombo:SetSelectedItem(current.name)
end

function UI:RefreshSetupCombo()
    local current, build = self.owner.data:GetCurrentSetup()
    self.setupCombo:ClearItems()
    for _, setup in ipairs(build.setups) do
        local setupId = setup.id
        self.setupCombo:AddItem(self.setupCombo:CreateItemEntry(setup.name, function()
            self.owner.data:SelectSetup(build.id, setupId)
            self:Refresh()
        end))
    end
    self.setupCombo:SetSelectedItem(current.name)
end

function UI:GetRequirementSummary(requirement)
    if not requirement then
        return GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED)
    end
    local name = requirement.itemName ~= "" and requirement.itemName or requirement.setName
    if not name or name == "" then
        name = GetString(SI_GRAVVY_BUILD_PLANNER_INCOMPLETE)
    end

    local details = {}
    if requirement.armorType and requirement.armorType ~= ARMORTYPE_NONE then
        details[#details + 1] = GetString("SI_ARMORTYPE", requirement.armorType)
    elseif requirement.weaponType and requirement.weaponType ~= WEAPONTYPE_NONE then
        details[#details + 1] = GetString("SI_WEAPONTYPE", requirement.weaponType)
    end
    if requirement.traitType and requirement.traitType ~= ITEM_TRAIT_TYPE_NONE then
        details[#details + 1] = GetString("SI_ITEMTRAITTYPE", requirement.traitType)
    end
    if #details > 0 then
        return name .. " — " .. table.concat(details, ", ")
    end
    return name
end

function UI:RefreshRows()
    local setup = self.owner.data:GetCurrentSetup()
    for _, slotKey in ipairs(Slots.ORDER) do
        local row = self.rows[slotKey]
        local mainHand = Slots:GetMainHand(slotKey)
        local mainRequirement = mainHand and setup.equipment[mainHand]
        local occupied = mainRequirement and mainRequirement.occupiesOffHand
        local summary
        if occupied then
            summary = zo_strformat(SI_GRAVVY_BUILD_PLANNER_OCCUPIED, slotName(mainHand))
        else
            summary = self:GetRequirementSummary(setup.equipment[slotKey])
        end
        row:SetText(slotName(slotKey) .. ":  " .. summary)
        row:SetEnabled(not occupied)
        row:SetAlpha(occupied and 0.55 or 1)
    end
end

function UI:Refresh()
    self:RefreshBuildCombo()
    self:RefreshSetupCombo()
    self:RefreshRows()
    self:LoadEditor()
end

function UI:EditSlot(slotKey)
    self.selectedSlot = slotKey
    self:LoadEditor()
end

function UI:LoadEditor()
    self.loadingEditor = true
    local setup = self.owner.data:GetCurrentSetup()
    local requirement = setup.equipment[self.selectedSlot] or {}
    local definition = Slots:Get(self.selectedSlot)
    self.editorTitle:SetText(slotName(self.selectedSlot))

    self.suppressSetSearch = true
    self.setEdit:SetText(requirement.setName or "")
    self.suppressSetSearch = false
    self.selectedSetId = requirement.setId
    self.selectedSetName = requirement.setName
    self.suggestionPanel:SetHidden(true)

    local isJewelry = definition.family == "jewelry"
    self.typeLabel:SetHidden(isJewelry)
    self.typeContainer:SetHidden(isJewelry)
    self:RefreshTypeChoices(requirement)
    local requirementFamily = self:GetEditorRequirementFamily()
    setComboChoices(
        self.traitCombo,
        getTraitChoices(requirementFamily),
        requirement.traitType or ITEM_TRAIT_TYPE_NONE,
        function() self:RefreshEditorPreview() end
    )
    setComboChoices(
        self.qualityCombo,
        getQualityChoices(),
        requirement.quality or DEFAULT_VALUE,
        function() self:RefreshEditorPreview() end
    )
    self.legacyEnchantmentName = requirement.enchantmentCategory == nil
        and requirement.enchantmentName
        or nil
    local selectedEnchantment = requirement.enchantmentCategory
        or (self.legacyEnchantmentName and GravvyBuildPlannerEnchantments.CUSTOM)
        or GravvyBuildPlannerEnchantments.DEFAULT
    setComboChoices(
        self.enchantmentCombo,
        GravvyBuildPlannerEnchantments:GetChoices(
            requirementFamily,
            self.legacyEnchantmentName
        ),
        selectedEnchantment,
        function() self:RefreshEditorPreview() end
    )
    self.levelEdit:SetText(requirement.level and tostring(requirement.level) or "")
    self.cpEdit:SetText(requirement.championPoints and tostring(requirement.championPoints) or "")
    self.levelLabel:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_LEVEL_DEFAULT,
        setup.defaultLevel
    ))
    self.cpLabel:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CHAMPION_POINTS_DEFAULT,
        setup.defaultChampionPoints
    ))
    self.noteEdit:SetText(requirement.note or "")
    self.slotActionButton:SetEnabled(setup.equipment[self.selectedSlot] ~= nil)
    self.slotActionButton:SetAlpha(setup.equipment[self.selectedSlot] and 1 or 0.55)
    self.loadingEditor = false
    self:RefreshEditorPreview()
end

function UI:RefreshTypeChoices(requirement)
    local definition = Slots:Get(self.selectedSlot)
    if definition.family == "jewelry" then
        return
    end

    requirement = requirement or self:ReadEditorRequirement()
    local choices = getTypeChoices(self.selectedSlot)
    local selectedType = definition.family == "armor"
        and (requirement.armorType or 0)
        or (requirement.weaponType or 0)
    local locked = false

    if definition.family == "armor" and requirement.setId then
        local armorTypes = self.owner.itemResolver:GetAvailableArmorTypes(
            self.selectedSlot,
            requirement.setId
        )
        if #armorTypes > 0 then
            choices = getArmorTypeChoices(armorTypes)
            local isAvailable = false
            for _, armorType in ipairs(armorTypes) do
                if selectedType == armorType then
                    isAvailable = true
                    break
                end
            end
            if not isAvailable then
                selectedType = armorTypes[1]
            end
            locked = #armorTypes == 1
        end
    end

    setComboChoices(self.typeCombo, choices, selectedType, function()
        self:OnEquipmentTypeChanged()
    end)
    self.typeCombo:SetEnabled(not locked)
    self.typeContainer:SetAlpha(locked and 0.65 or 1)
end

function UI:GetEditorRequirementFamily()
    local definition = Slots:Get(self.selectedSlot)
    if definition.family == "weapon"
        and self.typeCombo.selectedValue == WEAPONTYPE_SHIELD then
        return "armor"
    end
    return definition.family
end

function UI:OnEquipmentTypeChanged()
    local family = self:GetEditorRequirementFamily()
    setComboChoices(
        self.traitCombo,
        getTraitChoices(family),
        self.traitCombo.selectedValue or ITEM_TRAIT_TYPE_NONE,
        function() self:RefreshEditorPreview() end
    )
    setComboChoices(
        self.enchantmentCombo,
        GravvyBuildPlannerEnchantments:GetChoices(family, self.legacyEnchantmentName),
        self.enchantmentCombo.selectedValue or GravvyBuildPlannerEnchantments.DEFAULT,
        function() self:RefreshEditorPreview() end
    )
    self:RefreshEditorPreview()
end

function UI:ReadEditorRequirement()
    local definition = Slots:Get(self.selectedSlot)
    local setName = zo_strtrim(self.setEdit:GetText())
    local level = zo_strtrim(self.levelEdit:GetText())
    local championPoints = zo_strtrim(self.cpEdit:GetText())
    local requirement = {
        setName = setName,
        note = self.noteEdit:GetText(),
    }

    if self.selectedSetName then
        requirement.setId = self.selectedSetId
        requirement.setName = self.selectedSetName
    else
        local exactSet = self.owner.setCatalog:FindExact(setName)
        if exactSet then
            requirement.setId = exactSet.setId
            requirement.setName = exactSet.name
        end
    end
    if definition.family == "armor" and self.typeCombo.selectedValue ~= 0 then
        requirement.armorType = self.typeCombo.selectedValue
    elseif definition.family == "weapon" and self.typeCombo.selectedValue ~= 0 then
        requirement.weaponType = self.typeCombo.selectedValue
    end
    if self.traitCombo.selectedValue ~= ITEM_TRAIT_TYPE_NONE then
        requirement.traitType = self.traitCombo.selectedValue
    end
    local enchantmentCategory = self.enchantmentCombo.selectedValue
    if enchantmentCategory == GravvyBuildPlannerEnchantments.CUSTOM then
        requirement.enchantmentName = self.legacyEnchantmentName
    elseif enchantmentCategory ~= GravvyBuildPlannerEnchantments.DEFAULT then
        requirement.enchantmentCategory = enchantmentCategory
        requirement.enchantmentName = GravvyBuildPlannerEnchantments:GetName(
            enchantmentCategory
        )
    end
    if self.qualityCombo.selectedValue ~= DEFAULT_VALUE then
        requirement.quality = self.qualityCombo.selectedValue
    end
    if level ~= "" then
        requirement.level = zo_clamp(math.floor(tonumber(level) or 1), 1, 50)
    end
    if championPoints ~= "" then
        local gearCap = GetChampionPointsPlayerProgressionCap
            and GetChampionPointsPlayerProgressionCap()
            or 160
        requirement.championPoints = zo_clamp(
            math.floor((tonumber(championPoints) or 0) / 10) * 10,
            0,
            gearCap
        )
    end
    return requirement
end

function UI:RefreshEditorPreview(requirement)
    local setup = self.owner.data:GetCurrentSetup()
    requirement = requirement or self:ReadEditorRequirement()
    local resolved = self.owner.itemResolver:Resolve(self.selectedSlot, requirement, setup)
    self.previewLink = resolved and resolved.itemLink or requirement.itemLink
    self.previewRequirement = requirement

    if self.previewLink and self.previewLink ~= "" then
        self.previewIcon:SetTexture(GetItemLinkIcon(self.previewLink))
        self.previewButton:SetHidden(false)
        self.previewUnavailable:SetHidden(true)
    else
        self.previewIcon:SetTexture(nil)
        self.previewButton:SetHidden(true)
        self.previewUnavailable:SetHidden(false)
    end
end

function UI:ShowItemTooltip(control, itemLink, requirement)
    if not ItemTooltip or not InitializeTooltip then
        return
    end
    InitializeTooltip(ItemTooltip, control, LEFT, -8, 0, RIGHT)
    ItemTooltip:SetLink(itemLink)

    if requirement and requirement.enchantmentCategory then
        local _, previewCategory = self.owner.itemResolver:GetEnchantInfo(itemLink)
        if previewCategory ~= requirement.enchantmentCategory and ItemTooltip.AddLine then
            ItemTooltip:AddLine(
                zo_strformat(
                    SI_GRAVVY_BUILD_PLANNER_PREVIEW_ENCHANTMENT_NOTE,
                    requirement.enchantmentName
                ),
                "ZoFontGameSmall",
                0.95,
                0.72,
                0.35
            )
        end
    end

    local setup = self.owner.data:GetCurrentSetup()
    if requirement
        and not self.owner.itemResolver:MatchesRequestedLevel(itemLink, requirement, setup)
        and ItemTooltip.AddLine then
        local level, championPoints = self.owner.itemResolver:GetRequestedLevel(
            requirement,
            setup
        )
        local plannedLevel = championPoints > 0
            and zo_strformat(SI_GRAVVY_BUILD_PLANNER_CHAMPION_VALUE, championPoints)
            or zo_strformat(SI_GRAVVY_BUILD_PLANNER_LEVEL_VALUE, level)
        ItemTooltip:AddLine(
            zo_strformat(SI_GRAVVY_BUILD_PLANNER_PREVIEW_LEVEL_NOTE, plannedLevel),
            "ZoFontGameSmall",
            0.95,
            0.72,
            0.35
        )
    end
end

function UI:HideItemTooltip()
    if ItemTooltip and ClearTooltip then
        ClearTooltip(ItemTooltip)
    end
end

function UI:ShowSlotTooltip(slotKey, control)
    local setup = self.owner.data:GetCurrentSetup()
    local requirement = setup.equipment[slotKey]
    if requirement and requirement.itemLink and requirement.itemLink ~= "" then
        self:ShowItemTooltip(control, requirement.itemLink, requirement)
    end
end

function UI:SaveSlot()
    local setup, build = self.owner.data:GetCurrentSetup()
    local requirement = self:ReadEditorRequirement()
    local resolved = self.owner.itemResolver:Resolve(self.selectedSlot, requirement, setup)
    if resolved then
        requirement.itemLink = resolved.itemLink
        requirement.itemId = resolved.itemId
        requirement.itemName = resolved.itemName
        if resolved.enchantmentMatches and requirement.enchantmentCategory then
            requirement.enchantmentId = resolved.enchantmentId
        end
    end

    local ok, message = self.owner.data:SetEquipment(build.id, setup.id, self.selectedSlot, requirement)
    if not ok then
        self:SetStatus(message, true)
        return
    end
    self.owner.setCatalog:Refresh()
    self:RefreshRows()
    self:LoadEditor()
    self:SetStatus(zo_strformat(SI_GRAVVY_BUILD_PLANNER_SLOT_SAVED, slotName(self.selectedSlot)))
end

function UI:ClearSlot()
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, message = self.owner.data:SetEquipment(build.id, setup.id, self.selectedSlot, nil)
    if not ok then
        self:SetStatus(message, true)
        return
    end
    self:RefreshRows()
    self:LoadEditor()
    self:SetStatus(zo_strformat(SI_GRAVVY_BUILD_PLANNER_SLOT_CLEARED, slotName(self.selectedSlot)))
end

function UI:GetTransferTargets(requirement)
    local setup = self.owner.data:GetCurrentSetup()
    local choices = {}
    for _, slotKey in ipairs(Slots.ORDER) do
        local mainHand = Slots:GetMainHand(slotKey)
        local mainRequirement = mainHand and setup.equipment[mainHand]
        if Slots:IsTransferCompatible(self.selectedSlot, slotKey, requirement)
            and not (mainRequirement and mainRequirement.occupiesOffHand) then
            choices[#choices + 1] = { label = slotName(slotKey), value = slotKey }
        end
    end
    return choices
end

function UI:OpenSlotActionDialog()
    local setup = self.owner.data:GetCurrentSetup()
    local requirement = setup.equipment[self.selectedSlot]
    if not requirement then
        self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SOURCE_SLOT_EMPTY), true)
        return
    end

    local choices = self:GetTransferTargets(requirement)
    if #choices == 0 then
        self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_NO_TRANSFER_SLOT), true)
        return
    end
    setComboChoices(self.slotTargetCombo, choices, choices[1].value)
    self.slotActionDialog:SetHidden(false)
end

function UI:TransferSlot(move)
    local setup = self.owner.data:GetCurrentSetup()
    local sourceSlot = self.selectedSlot
    local targetSlot = self.slotTargetCombo.selectedValue
    local requirement = setup.equipment[sourceSlot]
    if not requirement or not targetSlot then
        self.slotActionDialog:SetHidden(true)
        self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SOURCE_SLOT_EMPTY), true)
        return
    end

    local targetOffHand = Slots:GetOccupiedOffHand(targetSlot, requirement.weaponType)
    local replacesTarget = setup.equipment[targetSlot] ~= nil
    local clearsOffHand = targetOffHand and setup.equipment[targetOffHand] ~= nil
    local function finishTransfer()
        local currentSetup, build = self.owner.data:GetCurrentSetup()
        local ok, message
        if move then
            ok, message = self.owner.data:MoveEquipment(
                build.id,
                currentSetup.id,
                sourceSlot,
                targetSlot
            )
        else
            ok, message = self.owner.data:CopyEquipment(
                build.id,
                currentSetup.id,
                sourceSlot,
                targetSlot
            )
        end
        if not ok then
            return false, message
        end
        self.slotActionDialog:SetHidden(true)
        self.selectedSlot = targetSlot
        self:RefreshRows()
        self:LoadEditor()
        self:SetStatus(zo_strformat(
            move and SI_GRAVVY_BUILD_PLANNER_SLOT_MOVED or SI_GRAVVY_BUILD_PLANNER_SLOT_COPIED,
            slotName(sourceSlot),
            slotName(targetSlot)
        ))
        return true
    end

    if replacesTarget or clearsOffHand then
        local message
        if clearsOffHand then
            message = zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_CONFIRM_TRANSFER_TWO_HAND,
                slotName(targetSlot),
                slotName(targetOffHand)
            )
        else
            message = zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_CONFIRM_REPLACE_SLOT,
                slotName(targetSlot)
            )
        end
        self:OpenConfirm(message, finishTransfer, true)
        return
    end
    local ok, message = finishTransfer()
    if not ok then
        self:SetStatus(message, true)
    end
end

function UI:OnSetTextChanged()
    if self.suppressSetSearch then
        return
    end
    self.selectedSetId = nil
    self.selectedSetName = nil
    self.suggestionData = self.owner.setCatalog:Search(self.setEdit:GetText())
    self.suggestionOffset = 0
    self.suggestionIndex = 1
    self:RenderSuggestions()
    self:RefreshTypeChoices()
    self:RefreshEditorPreview()
end

function UI:ResolveTypedSet()
    local entry = self.owner.setCatalog:FindExact(self.setEdit:GetText())
    self.selectedSetId = entry and entry.setId or nil
    self.selectedSetName = entry and entry.name or nil
    self:RefreshTypeChoices()
    self:RefreshEditorPreview()
end

function UI:RenderSuggestions()
    local data = self.suggestionData or {}
    local maxOffset = math.max(0, #data - SUGGESTION_ROWS)
    self.suggestionOffset = zo_clamp(self.suggestionOffset, 0, maxOffset)
    self.suggestionIndex = zo_clamp(self.suggestionIndex, 1, math.min(SUGGESTION_ROWS, math.max(1, #data)))

    for index, button in ipairs(self.suggestionButtons) do
        local entry = data[self.suggestionOffset + index]
        button:SetHidden(entry == nil)
        if entry then
            button:SetText(entry.name)
            if index == self.suggestionIndex then
                button:SetNormalFontColor(1, 0.9, 0.65, 1)
            else
                button:SetNormalFontColor(0.85, 0.78, 0.62, 1)
            end
        end
    end
    self.suggestionPanel:SetHidden(#data == 0)
end

function UI:ChooseSuggestion(index)
    local entry = self.suggestionData and self.suggestionData[self.suggestionOffset + index]
    if not entry then
        return
    end
    self.suppressSetSearch = true
    self.setEdit:SetText(entry.name)
    self.suppressSetSearch = false
    self.selectedSetId = entry.setId
    self.selectedSetName = entry.name
    self.suggestionPanel:SetHidden(true)
    self:RefreshTypeChoices()
    self:RefreshEditorPreview()
end

function UI:ScrollSuggestions(delta)
    local data = self.suggestionData or {}
    if #data <= SUGGESTION_ROWS then
        return
    end
    self.suggestionOffset = self.suggestionOffset + delta
    self:RenderSuggestions()
end

function UI:OnSetKeyDown(key)
    if self.suggestionPanel:IsHidden() then
        return
    end
    if key == KEY_UP then
        if self.suggestionIndex > 1 then
            self.suggestionIndex = self.suggestionIndex - 1
        elseif self.suggestionOffset > 0 then
            self.suggestionOffset = self.suggestionOffset - 1
        end
        self:RenderSuggestions()
    elseif key == KEY_DOWN then
        local visible = math.min(SUGGESTION_ROWS, #(self.suggestionData or {}))
        if self.suggestionIndex < visible then
            self.suggestionIndex = self.suggestionIndex + 1
        elseif self.suggestionOffset + visible < #(self.suggestionData or {}) then
            self.suggestionOffset = self.suggestionOffset + 1
        end
        self:RenderSuggestions()
    elseif key == KEY_ENTER then
        self:ChooseSuggestion(self.suggestionIndex)
    elseif key == KEY_ESCAPE then
        self.suggestionPanel:SetHidden(true)
    end
end

function UI:OpenNameDialog(initialValue, callback)
    self.nameCallback = callback
    self.nameEdit:SetText(initialValue or "")
    self.nameDialog:SetHidden(false)
    self.nameEdit:TakeFocus()
    self.nameEdit:SelectAll()
end

function UI:AcceptNameDialog()
    local result, message = self.nameCallback(self.nameEdit:GetText())
    if not result then
        self:SetStatus(message, true)
        return
    end
    self.nameDialog:SetHidden(true)
    self:FinishAction(result)
end

function UI:OpenConfirm(message, callback, callbackRefreshesUI)
    self.confirmCallback = callback
    self.confirmCallbackRefreshesUI = callbackRefreshesUI == true
    self.confirmText:SetText(message)
    self.confirmDialog:SetHidden(false)
end

function UI:AcceptConfirm()
    local result, message = self.confirmCallback()
    local callbackRefreshesUI = self.confirmCallbackRefreshesUI
    self.confirmCallbackRefreshesUI = nil
    if not result then
        self.confirmDialog:SetHidden(true)
        self:SetStatus(message, true)
        return
    end
    self.confirmDialog:SetHidden(true)
    if not callbackRefreshesUI then
        self:FinishAction(result)
    end
end

function UI:FinishAction(result, message)
    if not result then
        self:SetStatus(message, true)
        return
    end
    self.owner.setCatalog:Refresh()
    self:Refresh()
    self:SetStatus("")
end

function UI:UndoDeletion()
    local ok, message = self.owner.data:UndoLastDeletion()
    if not ok then
        self:SetStatus(message, true)
        return
    end
    self.owner.setCatalog:Refresh()
    self:Refresh()
    self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_RESTORED))
end

function UI:SetStatus(message, isError)
    self.status:SetText(message or "")
    if isError then
        self.status:SetColor(1, 0.35, 0.3, 1)
    else
        self.status:SetColor(0.75, 0.9, 0.65, 1)
    end
end

function UI:SavePosition()
    local geometry = self.owner.data:GetSettings().window
    geometry.left = self.window:GetLeft()
    geometry.top = self.window:GetTop()
end

function UI:Show()
    self:Refresh()
    self.window:SetHidden(false)
end

function UI:Hide()
    self.suggestionPanel:SetHidden(true)
    self.nameDialog:SetHidden(true)
    self.confirmDialog:SetHidden(true)
    self.slotActionDialog:SetHidden(true)
    self.window:SetHidden(true)
end

function UI:Toggle()
    if self.window:IsHidden() then
        self:Show()
    else
        self:Hide()
    end
end
