GravvyBuildPlannerUI = {}

local UI = GravvyBuildPlannerUI
local Slots = GravvyBuildPlannerSlots
local WINDOW_WIDTH = 980
local WINDOW_HEIGHT = 700
local SUGGESTION_ROWS = 6
local DEFAULT_VALUE = -1
local AUTOMATIC_ROUTE = "automatic"
local EMPTY_SKILL_TEXTURE = "EsoUI/Art/ActionBar/abilityInset.dds"

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
    return edit, backdrop
end

local function makeNoteEdit(parent, name, x, y, width, height, maxChars)
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
    GravvyBuildPlannerAccessibility:SetFont(edit, "ZoFontGame")
    edit:SetMaxInputChars(maxChars or 4000)
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

local function getRaceChoices()
    local choices = {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED), value = 0 },
    }
    if not GetRaceName then
        return choices
    end
    for raceId = 1, 10 do
        local name = GetRaceName(GENDER_MALE or 1, raceId)
        if name and name ~= "" then
            choices[#choices + 1] = { label = name, value = raceId }
        end
    end
    return choices
end

local function getMundusChoices()
    local choices = {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED), value = 0 },
    }
    for mundus = 1, 13 do
        local name = GetString("SI_MUNDUSSTONE", mundus)
        if name and name ~= "" then
            choices[#choices + 1] = { label = name, value = mundus }
        end
    end
    return choices
end

local function getCurseChoices()
    return {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_CURSE_NONE), value = 0 },
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_CURSE_VAMPIRE), value = 1 },
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_CURSE_WEREWOLF), value = 2 },
    }
end

function UI:New(owner)
    return setmetatable({
        owner = owner,
        rows = {},
        selectedSlot = "head",
        suggestions = {},
        suggestionOffset = 0,
        suggestionIndex = 1,
        activeView = "gear",
        selectedSkillBar = "front",
        selectedSkillSlot = 1,
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
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.035, 0.035, 0.045, 0.98 },
        { 0.5, 0.42, 0.28, 0.95 }
    )

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

    local export = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT), 135)
    export:SetAnchor(TOPRIGHT, undo, TOPLEFT, -8, 0)
    export:SetHandler("OnClicked", function() self:OpenExportDialog() end)
    local help = makeButton(window, "?", 34)
    help:SetAnchor(TOPRIGHT, export, TOPLEFT, -8, 0)
    help:SetHandler("OnClicked", function() self:ShowHelp() end)
    local share = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE), 90)
    share:SetAnchor(TOPRIGHT, help, TOPLEFT, -8, 0)
    share:SetHandler("OnClicked", function() self.owner.share:Open() end)

    self:CreateBuildControls()
    self:CreateSlotRows()
    self:CreateEditor()
    self:CreateSkillPlanner()
    self:CreateCharacterPlanner()
    self:CreateNameDialog()
    self:CreateConfirmDialog()
    self:CreateSlotActionDialog()
    self:CreateExportDialog()
    self:CreateCodeDialog()
    self:CreateHelpDialog()
    self:RegisterFocusEvent()

    self.status = makeLabel(window, "", 18, 668, WINDOW_WIDTH - 36, "ZoFontGameSmall")
    self:Refresh()
    self:SetView(self.activeView)
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

    self.progressLabel = makeLabel(window, "", 660, 84, 300, "ZoFontGameSmall")
    self.progressLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    self.gearTab = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_GEAR), 90)
    self.gearTab:SetAnchor(TOPLEFT, window, TOPLEFT, 660, 47)
    self.gearTab:SetHandler("OnClicked", function() self:SetView("gear") end)
    self.skillsTab = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_SKILLS), 90)
    self.skillsTab:SetAnchor(LEFT, self.gearTab, RIGHT, 8, 0)
    self.skillsTab:SetHandler("OnClicked", function() self:SetView("skills") end)
    self.characterTab = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_CHARACTER), 100)
    self.characterTab:SetAnchor(LEFT, self.skillsTab, RIGHT, 8, 0)
    self.characterTab:SetHandler("OnClicked", function() self:SetView("character") end)

    local divider = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    divider:SetAnchor(TOPLEFT, window, TOPLEFT, 14, 124)
    divider:SetDimensions(WINDOW_WIDTH - 28, 1)
    divider:SetColor(0.5, 0.42, 0.28, 0.7)
end

function UI:CreateCharacterPlanner()
    local panel = WINDOW_MANAGER:CreateControl("GravvyBuildPlannerCharacter", self.window, CT_CONTROL)
    panel:SetAnchor(TOPLEFT, self.window, TOPLEFT, 18, 137)
    panel:SetDimensions(942, 530)
    panel:SetHidden(true)
    self.characterPanel = panel

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, panel, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(panel)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.018, 0.018, 0.026, 0.9 },
        { 0.28, 0.24, 0.18, 0.85 }
    )

    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_ATTRIBUTES), 28, 22, 390, "ZoFontWinH3")
    self.attributeEdits = {}
    for index, entry in ipairs({
        { "health", SI_GRAVVY_BUILD_PLANNER_HEALTH },
        { "magicka", SI_GRAVVY_BUILD_PLANNER_MAGICKA },
        { "stamina", SI_GRAVVY_BUILD_PLANNER_STAMINA },
    }) do
        local y = 68 + ((index - 1) * 52)
        makeLabel(panel, GetString(entry[2]), 28, y, 135)
        local edit = makeEdit(
            panel,
            "GravvyBuildPlanner" .. entry[1] .. "Attribute",
            168,
            y,
            90,
            true,
            2
        )
        edit:SetHandler("OnTextChanged", function() self:RefreshAttributeTotal() end)
        self.attributeEdits[entry[1]] = edit
    end
    self.attributeTotal = makeLabel(panel, "", 28, 232, 300, "ZoFontGame")

    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_RACE), 500, 30, 125)
    self.raceCombo = makeCombo(panel, "GravvyBuildPlannerRaceCombo", 630, 30, 270)

    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_MUNDUS), 500, 90, 125)
    self.mundusCombo = makeCombo(panel, "GravvyBuildPlannerMundusCombo", 630, 90, 270)
    self.mundusIcon = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
    self.mundusIcon:SetDimensions(48, 48)
    self.mundusIcon:SetAnchor(TOPLEFT, panel, TOPLEFT, 630, 126)

    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CURSE), 500, 190, 125)
    self.curseCombo = makeCombo(panel, "GravvyBuildPlannerCurseCombo", 630, 190, 270)

    local divider = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
    divider:SetAnchor(TOPLEFT, panel, TOPLEFT, 24, 282)
    divider:SetDimensions(894, 1)
    divider:SetColor(0.5, 0.42, 0.28, 0.7)
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_SUBCLASS_LINES), 28, 294, 390, "ZoFontWinH3")
    self.subclassEdits = {}
    for index = 1, 3 do
        local y = 340 + ((index - 1) * 48)
        makeLabel(panel, zo_strformat(SI_GRAVVY_BUILD_PLANNER_SUBCLASS_LINE, index), 28, y, 135)
        self.subclassEdits[index] = makeEdit(
            panel,
            "GravvyBuildPlannerSubclass" .. tostring(index),
            168,
            y,
            360,
            false,
            100
        )
    end
    local hint = makeLabel(
        panel,
        GetString(SI_GRAVVY_BUILD_PLANNER_SUBCLASS_HINT),
        550,
        340,
        350,
        "ZoFontGameSmall"
    )
    hint:SetHeight(90)
    hint:SetVerticalAlignment(TEXT_ALIGN_TOP)

    local save = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_SAVE_CHARACTER), 160)
    save:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -20, -20)
    save:SetHandler("OnClicked", function() self:SaveCharacter() end)
end

function UI:CreateSkillPlanner()
    local panel = WINDOW_MANAGER:CreateControl("GravvyBuildPlannerSkills", self.window, CT_CONTROL)
    panel:SetAnchor(TOPLEFT, self.window, TOPLEFT, 18, 137)
    panel:SetDimensions(942, 530)
    panel:SetHidden(true)
    self.skillPanel = panel

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, panel, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(panel)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.018, 0.018, 0.026, 0.9 },
        { 0.28, 0.24, 0.18, 0.85 }
    )

    self.skillButtons = { front = {}, back = {} }
    for barNumber, barKey in ipairs({ "front", "back" }) do
        local y = barNumber == 1 and 22 or 185
        makeLabel(
            panel,
            GetString(barKey == "front"
                and SI_GRAVVY_BUILD_PLANNER_FRONT_BAR
                or SI_GRAVVY_BUILD_PLANNER_BACK_BAR),
            22,
            y,
            440,
            "ZoFontWinH3"
        )
        for slotIndex = 1, 6 do
            local button = WINDOW_MANAGER:CreateControl(nil, panel, CT_BUTTON)
            button:SetDimensions(62, 62)
            button:SetAnchor(TOPLEFT, panel, TOPLEFT, 24 + ((slotIndex - 1) * 74), y + 42)
            button:SetHandler("OnClicked", function()
                self.selectedSkillBar = barKey
                self.selectedSkillSlot = slotIndex
                self:LoadSkillEditor()
                self:RefreshSkillBars()
            end)
            button:SetHandler("OnMouseEnter", function(control)
                self:ShowSkillTooltip(control, barKey, slotIndex)
            end)
            button:SetHandler("OnMouseExit", function() self:HideSkillTooltip() end)
            local edge = WINDOW_MANAGER:CreateControlFromVirtual(nil, button, "ZO_DefaultBackdrop")
            edge:SetAnchorFill(button)
            edge:SetCenterColor(0.025, 0.025, 0.035, 0.96)
            local icon = WINDOW_MANAGER:CreateControl(nil, button, CT_TEXTURE)
            icon:SetAnchor(TOPLEFT, button, TOPLEFT, 4, 4)
            icon:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, -4, -4)
            button.backdrop = edge
            button.icon = icon
            button.number = makeLabel(
                button,
                slotIndex == 6 and "U" or tostring(slotIndex),
                2,
                35,
                22,
                "ZoFontGameSmall"
            )
            self.skillButtons[barKey][slotIndex] = button
        end
    end

    local divider = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
    divider:SetAnchor(TOPLEFT, panel, TOPLEFT, 488, 18)
    divider:SetDimensions(1, 494)
    divider:SetColor(0.5, 0.42, 0.28, 0.7)
    self.skillEditorTitle = makeLabel(panel, "", 520, 24, 390, "ZoFontWinH3")
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_ABILITY), 520, 76, 100)
    self.skillEdit = makeEdit(panel, "GravvyBuildPlannerSkillEdit", 520, 110, 390)
    self.skillEdit:SetHandler("OnTextChanged", function() self:OnSkillTextChanged() end)
    self.skillEdit:SetHandler("OnKeyDown", function(_, key) self:OnSkillKeyDown(key) end)
    self.skillEdit:SetHandler("OnFocusLost", function() self:ResolveTypedSkill() end)
    self.skillPreview = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
    self.skillPreview:SetDimensions(64, 64)
    self.skillPreview:SetAnchor(TOPLEFT, panel, TOPLEFT, 520, 165)
    self.skillName = makeLabel(panel, "", 600, 176, 310, "ZoFontGame")
    local clear = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_CLEAR_SKILL), 130)
    clear:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -158, -22)
    clear:SetHandler("OnClicked", function() self:ClearSkill() end)
    local save = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_SAVE_SKILL), 130)
    save:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -18, -22)
    save:SetHandler("OnClicked", function() self:SaveSkill() end)

    local suggestions = WINDOW_MANAGER:CreateControl(nil, panel, CT_CONTROL)
    suggestions:SetDimensions(390, 152)
    suggestions:SetAnchor(TOPLEFT, self.skillEdit, BOTTOMLEFT, 0, 2)
    suggestions:SetHidden(true)
    suggestions:SetDrawTier(DT_HIGH)
    self.skillSuggestionPanel = suggestions
    local suggestionBackdrop = WINDOW_MANAGER:CreateControlFromVirtual(
        nil,
        suggestions,
        "ZO_DefaultBackdrop"
    )
    suggestionBackdrop:SetAnchorFill(suggestions)
    self.skillSuggestionButtons = {}
    for index = 1, 6 do
        local button = makeButton(suggestions, "", 380)
        button:SetHeight(24)
        button:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        button:SetAnchor(TOPLEFT, suggestions, TOPLEFT, 5, 4 + ((index - 1) * 24))
        button:SetHandler("OnClicked", function() self:ChooseSkillSuggestion(index) end)
        self.skillSuggestionButtons[index] = button
    end
end

function UI:SetView(view)
    self.activeView = (view == "skills" or view == "character") and view or "gear"
    local skills = self.activeView == "skills"
    local character = self.activeView == "character"
    self.paperDoll:SetHidden(skills or character)
    self.editor:SetHidden(skills or character)
    self.skillPanel:SetHidden(not skills)
    self.characterPanel:SetHidden(not character)
    self.gearTab:SetAlpha((skills or character) and 0.65 or 1)
    self.skillsTab:SetAlpha(skills and 1 or 0.65)
    self.characterTab:SetAlpha(character and 1 or 0.65)
    if skills then
        self:RefreshSkillBars()
        self:LoadSkillEditor()
    elseif character then
        self:LoadCharacterEditor()
    end
end

function UI:CreateSlotRows()
    local panel = WINDOW_MANAGER:CreateControl("GravvyBuildPlannerPaperDoll", self.window, CT_CONTROL)
    panel:SetAnchor(TOPLEFT, self.window, TOPLEFT, 18, 137)
    panel:SetDimensions(490, 530)
    self.paperDoll = panel

    local panelBackdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, panel, "ZO_DefaultBackdrop")
    panelBackdrop:SetAnchorFill(panel)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        panelBackdrop,
        { 0.018, 0.018, 0.026, 0.78 },
        { 0.28, 0.24, 0.18, 0.75 }
    )

    local function addSection(title, y)
        local divider = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
        divider:SetTexture("EsoUI/Art/CharacterWindow/characterWindow_leftSide_divider.dds")
        divider:SetDimensions(460, 4)
        divider:SetAnchor(TOPLEFT, panel, TOPLEFT, 15, y)
        local label = makeLabel(panel, title, 16, y + 3, 200, "ZoFontHeader")
        label:SetHeight(25)
    end

    addSection(GetString(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_ARMOR), 0)
    addSection(GetString(SI_GRAVVY_BUILD_PLANNER_JEWELRY), 292)
    addSection(GetString(SI_GRAVVY_BUILD_PLANNER_WEAPONS), 382)

    local silhouette = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
    silhouette:SetDimensions(64, 250)
    silhouette:SetAnchor(TOP, panel, TOP, 0, 110)
    if GetUnitSilhouetteTexture then
        silhouette:SetTexture(GetUnitSilhouetteTexture("player"))
    end
    silhouette:SetAlpha(0.9)
    self.paperDollSilhouette = silhouette

    local positions = {
        head = { 219, 31 },
        shoulders = { 88, 91 },
        hands = { 88, 158 },
        legs = { 88, 225 },
        chest = { 350, 91 },
        waist = { 350, 158 },
        feet = { 350, 225 },
        neck = { 150, 326 },
        ring1 = { 219, 326 },
        ring2 = { 288, 326 },
        frontMain = { 150, 412 },
        frontOff = { 219, 412 },
        backMain = { 150, 468 },
        backOff = { 219, 468 },
    }

    local frontBar = makeLabel(panel, "1", 119, 422, 24, "ZoFontWinH3")
    frontBar:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local backBar = makeLabel(panel, "2", 119, 478, 24, "ZoFontWinH3")
    backBar:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    for _, slotKey in ipairs(Slots.ORDER) do
        local position = positions[slotKey]
        local button = WINDOW_MANAGER:CreateControl(
            "GravvyBuildPlannerPaperDoll" .. slotKey,
            panel,
            CT_BUTTON
        )
        button:SetDimensions(52, 52)
        button:SetAnchor(TOPLEFT, panel, TOPLEFT, position[1], position[2])
        button:SetHandler("OnClicked", function()
            self:EditSlot(button.occupiedBy or slotKey)
        end)
        button:SetHandler("OnMouseEnter", function(control)
            self:ShowSlotTooltip(slotKey, control)
        end)
        button:SetHandler("OnMouseExit", function() self:HideItemTooltip() end)

        local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, button, "ZO_DefaultBackdrop")
        backdrop:SetAnchorFill(button)
        backdrop:SetCenterColor(0.025, 0.025, 0.035, 0.96)
        backdrop:SetEdgeColor(0.36, 0.32, 0.24, 0.95)
        button.backdrop = backdrop

        local icon = WINDOW_MANAGER:CreateControl(nil, button, CT_TEXTURE)
        icon:SetAnchor(TOPLEFT, button, TOPLEFT, 3, 3)
        icon:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, -3, -3)
        button.icon = icon

        local status = makeLabel(button, "", 34, -3, 20, "ZoFontWinH4")
        status:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        status:SetDrawTier(DT_HIGH)
        button.status = status
        self.rows[slotKey] = button
    end
end

function UI:CreateEditor()
    local panel = WINDOW_MANAGER:CreateControl("GravvyBuildPlannerEditor", self.window, CT_CONTROL)
    panel:SetAnchor(TOPRIGHT, self.window, TOPRIGHT, -18, 137)
    panel:SetDimensions(430, 530)
    self.editor = panel

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, panel, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(panel)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.025, 0.025, 0.035, 0.92 },
        { 0.32, 0.28, 0.2, 0.9 }
    )

    self.editorTitle = makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_SLOT_EDITOR), 14, 5, 165, "ZoFontWinH3")
    self.alternativeCombo = makeCombo(
        panel,
        "GravvyBuildPlannerAlternativeCombo",
        181,
        7,
        136
    )
    self.setAlternativeButton = makeButton(
        panel,
        GetString(SI_GRAVVY_BUILD_PLANNER_SET_WIDE),
        88
    )
    self.setAlternativeButton:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -14, 8)
    self.setAlternativeButton:SetHandler("OnClicked", function()
        self:ApplySetAlternative()
    end)
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
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        previewBackdrop,
        { 0.025, 0.025, 0.035, 0.95 },
        { 0.5, 0.42, 0.28, 1 }
    )

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
    self.acquisitionLabel = makeLabel(panel, "", 14, 418, 402, "ZoFontGameSmall")
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_ROUTE), 14, 450, 105)
    self.routeCombo, self.routeContainer = makeCombo(
        panel,
        "GravvyBuildPlannerRouteCombo",
        122,
        450,
        290
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
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.02, 0.02, 0.03, 1 },
        { 0.5, 0.42, 0.28, 1 }
    )

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
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.035, 0.035, 0.045, 1 },
        { 0.5, 0.42, 0.28, 1 }
    )
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
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.035, 0.035, 0.045, 1 },
        { 0.55, 0.25, 0.2, 1 }
    )
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
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.035, 0.035, 0.045, 1 },
        { 0.5, 0.42, 0.28, 1 }
    )
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

function UI:CreateExportDialog()
    local dialog = WINDOW_MANAGER:CreateTopLevelWindow("GravvyBuildPlannerExportDialog")
    dialog:SetDimensions(570, 335)
    dialog:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    dialog:SetHidden(true)
    dialog:SetDrawTier(DT_HIGH)
    dialog:SetMouseEnabled(true)
    self.exportDialog = dialog

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, dialog, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(dialog)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.025, 0.025, 0.035, 1 },
        { 0.5, 0.42, 0.28, 1 }
    )

    makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_TITLE),
        18,
        10,
        534,
        "ZoFontWinH2"
    )
    self.exportSummary = makeLabel(dialog, "", 18, 49, 534, "ZoFontGame")

    makeLabel(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_OWNED), 18, 92, 220)
    self.exportOwnedCombo = makeCombo(
        dialog,
        "GravvyBuildPlannerExportOwnedCombo",
        248,
        92,
        304
    )
    makeLabel(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_GLYPHS), 18, 132, 220)
    self.exportGlyphCombo = makeCombo(
        dialog,
        "GravvyBuildPlannerExportGlyphCombo",
        248,
        132,
        304
    )

    self.exportHelp = makeLabel(dialog, "", 18, 174, 534, "ZoFontGameSmall")
    self.exportHelp:SetVerticalAlignment(TEXT_ALIGN_TOP)
    self.exportHelp:SetHeight(92)

    self.exportAccept = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_CREATE), 145)
    self.exportAccept:SetAnchor(BOTTOMRIGHT, dialog, BOTTOMRIGHT, -18, -14)
    self.exportAccept:SetHandler("OnClicked", function() self:ExecuteExport() end)
    local cancel = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_CANCEL), 100)
    cancel:SetAnchor(RIGHT, self.exportAccept, LEFT, -8, 0)
    cancel:SetHandler("OnClicked", function() dialog:SetHidden(true) end)
end

function UI:CreateCodeDialog()
    local dialog = WINDOW_MANAGER:CreateTopLevelWindow("GravvyBuildPlannerCodeDialog")
    dialog:SetDimensions(680, 430)
    dialog:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    dialog:SetHidden(true)
    dialog:SetDrawTier(DT_HIGH)
    dialog:SetMouseEnabled(true)
    self.codeDialog = dialog

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, dialog, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(dialog)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.025, 0.025, 0.035, 1 },
        { 0.5, 0.42, 0.28, 1 }
    )

    makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_CODE_TITLE),
        18,
        10,
        644,
        "ZoFontWinH2"
    )
    local help = makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_CODE_HELP),
        18,
        48,
        644,
        "ZoFontGameSmall"
    )
    help:SetVerticalAlignment(TEXT_ALIGN_TOP)
    help:SetHeight(70)
    self.codeEdit = makeNoteEdit(
        dialog,
        "GravvyBuildPlannerCodeEdit",
        18,
        120,
        644,
        240,
        20000
    )

    local close = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_CLOSE), 100)
    close:SetAnchor(BOTTOMRIGHT, dialog, BOTTOMRIGHT, -18, -14)
    close:SetHandler("OnClicked", function() dialog:SetHidden(true) end)
    local page = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_OPEN_ADDON_PAGE), 190)
    page:SetAnchor(BOTTOMLEFT, dialog, BOTTOMLEFT, 18, -14)
    page:SetHandler("OnClicked", function() self:OpenAddonPage() end)
end

function UI:OpenAddonPage()
    if RequestOpenUnsafeURL then
        RequestOpenUnsafeURL(self.owner.shopping:GetAddonURL())
    else
        self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_URL_UNAVAILABLE), true)
    end
end

function UI:CreateHelpDialog()
    local dialog = WINDOW_MANAGER:CreateTopLevelWindow("GravvyBuildPlannerHelpDialog")
    dialog:SetDimensions(700, 700)
    dialog:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    dialog:SetHidden(true)
    dialog:SetDrawTier(DT_HIGH)
    dialog:SetMouseEnabled(true)
    self.helpDialog = dialog

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, dialog, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(dialog)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.025, 0.025, 0.035, 1 },
        { 0.5, 0.42, 0.28, 1 }
    )
    makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_HELP_TITLE),
        18,
        10,
        664,
        "ZoFontWinH2"
    )
    local content = makeLabel(
        dialog,
        GetString(SI_GRAVVY_BUILD_PLANNER_HELP_CONTENT)
            .. GetString(SI_GRAVVY_BUILD_PLANNER_HELP_ALTERNATIVES)
            .. GetString(SI_GRAVVY_BUILD_PLANNER_HELP_SKILLS)
            .. GetString(SI_GRAVVY_BUILD_PLANNER_HELP_CHARACTER),
        22,
        52,
        656,
        "ZoFontGameSmall"
    )
    content:SetVerticalAlignment(TEXT_ALIGN_TOP)
    content:SetHeight(580)

    local close = makeButton(dialog, GetString(SI_GRAVVY_BUILD_PLANNER_CLOSE), 100)
    close:SetAnchor(BOTTOMRIGHT, dialog, BOTTOMRIGHT, -18, -14)
    close:SetHandler("OnClicked", function() self:CloseHelp() end)
end

function UI:ShowHelp()
    self.helpDialog:SetHidden(false)
    if self.window:IsHidden() then
        self.helpRequestedMouse = true
        self:AcquireMouse()
    end
end

function UI:CloseHelp()
    self.helpDialog:SetHidden(true)
    if self.helpRequestedMouse and self.window:IsHidden() then
        self:ReleaseMouse()
    end
    self.helpRequestedMouse = false
end

function UI:OpenExportDialog()
    self.exportIncludeOwned = false
    self.exportIncludeGlyphs = false
    setComboChoices(
        self.exportOwnedCombo,
        {
            { label = GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_EXCLUDE), value = false },
            { label = GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_INCLUDE), value = true },
        },
        false,
        function(value)
            self.exportIncludeOwned = value
            self:RefreshExportReview()
        end
    )
    setComboChoices(
        self.exportGlyphCombo,
        {
            { label = GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_NO_GLYPHS), value = false },
            { label = GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_ADD_GLYPHS), value = true },
        },
        false,
        function(value)
            self.exportIncludeGlyphs = value
            self:RefreshExportReview()
        end
    )
    self:RefreshExportReview()
    self.exportDialog:SetHidden(false)
end

function UI:RefreshExportReview()
    self.exportReview = self.owner.shopping:BuildReview(
        self.exportIncludeOwned,
        self.exportIncludeGlyphs
    )
    local review = self.exportReview
    self.exportSummary:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_EXPORT_SUMMARY,
        review.included,
        review.glyphs,
        review.excluded,
        review.owned
    ))

    local _, apiState = self.owner.shopping:GetAPI()
    if apiState == "ready" then
        self.exportHelp:SetText(GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_API_READY))
        self.exportAccept:SetText(GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_CREATE))
    elseif apiState == "old" then
        self.exportHelp:SetText(GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_API_OLD))
        self.exportAccept:SetText(GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_SHOW_CODE))
    else
        self.exportHelp:SetText(GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_API_MISSING))
        self.exportAccept:SetText(GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_SHOW_CODE))
    end
    local hasItems = #review.items > 0
    self.exportAccept:SetEnabled(hasItems)
    self.exportAccept:SetAlpha(hasItems and 1 or 0.55)
end

function UI:ExecuteExport()
    local review = self.exportReview
    if not review or #review.items == 0 then
        self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_NOTHING), true)
        return
    end

    local api = self.owner.shopping:GetAPI()
    if api then
        local ok, result, itemIndex = self.owner.shopping:CreateList(review)
        if ok then
            self.exportDialog:SetHidden(true)
            self:SetStatus(zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_EXPORT_CREATED,
                result.name,
                #review.items
            ))
            return
        elseif result ~= "NOT_READY" then
            local detail = itemIndex and (tostring(result) .. " #" .. tostring(itemIndex))
                or tostring(result)
            self:SetStatus(zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_EXPORT_FAILED,
                detail
            ), true)
            return
        end
    end
    self:ShowExportCode(review)
end

function UI:ShowExportCode(review)
    local code = self.owner.shopping:Encode(review)
    if not code then
        self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_CODE_FAILED), true)
        return
    end
    self.exportDialog:SetHidden(true)
    self.codeEdit:SetText(code)
    self.codeDialog:SetHidden(false)
    self.codeEdit:TakeFocus()
    self.codeEdit:SelectAll()
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

function UI:GetAlternativeChoices(setup, slotKey)
    local choices = {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_PRIMARY), value = 0 },
    }
    local alternatives = self.owner.data:GetAlternatives(setup, slotKey)
    for index = 1, #alternatives do
        choices[#choices + 1] = {
            label = zo_strformat(SI_GRAVVY_BUILD_PLANNER_ALTERNATIVE, index),
            value = index,
        }
    end
    if setup.equipment[slotKey] and #alternatives < 8 then
        choices[#choices + 1] = {
            label = GetString(SI_GRAVVY_BUILD_PLANNER_NEW_ALTERNATIVE),
            value = #alternatives + 1,
        }
    end
    return choices
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
        local requirement = occupied and mainRequirement or setup.equipment[slotKey]
        local itemLink = requirement and requirement.itemLink
        if requirement and (not itemLink or itemLink == "") then
            local resolved = self.owner.itemResolver:Resolve(slotKey, requirement, setup)
            itemLink = resolved and resolved.itemLink
        end
        local definition = Slots:Get(slotKey)
        local emptyTexture = ZO_Character_GetEmptyEquipSlotTexture
            and ZO_Character_GetEmptyEquipSlotTexture(definition.equipSlot)
            or nil
        row.icon:SetTexture(itemLink and itemLink ~= "" and GetItemLinkIcon(itemLink) or emptyTexture)
        row.icon:SetAlpha(occupied and 0.45 or 1)
        if row.icon.SetDesaturation then
            row.icon:SetDesaturation(occupied and 1 or 0)
        end

        local marker = ""
        local edge = { 0.36, 0.32, 0.24, 0.95 }
        if requirement and not occupied then
            local match = self.owner.inventory
                and self.owner.inventory:GetMatch(setup.id, slotKey)
            if match and match.exact then
                marker = "✓"
                edge = { 0.3, 0.78, 0.3, 1 }
                row.status:SetColor(0.45, 1, 0.45, 1)
            elseif match then
                marker = "~"
                edge = { 0.95, 0.65, 0.2, 1 }
                row.status:SetColor(1, 0.78, 0.3, 1)
            else
                marker = "!"
                edge = { 0.8, 0.3, 0.25, 1 }
                row.status:SetColor(1, 0.45, 0.4, 1)
            end
        end
        row.occupiedBy = occupied and mainHand or nil
        if self.selectedSlot == slotKey or row.occupiedBy == self.selectedSlot then
            edge = { 1, 0.76, 0.28, 1 }
        end
        row.backdrop:SetEdgeColor(edge[1], edge[2], edge[3], edge[4])
        row.status:SetText(marker)
        local alternativeCount = #self.owner.data:GetAlternatives(setup, slotKey)
        if alternativeCount > 0 then
            summary = zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_SUMMARY_ALTERNATIVES,
                summary,
                alternativeCount
            )
        end
        row.slotSummary = slotName(slotKey) .. ":  " .. summary
        row:SetText("")
        row:SetEnabled(true)
        row:SetAlpha(occupied and 0.55 or 1)
    end
end

function UI:Refresh()
    self:RefreshBuildCombo()
    self:RefreshSetupCombo()
    self:RefreshRows()
    self:RefreshSkillBars()
    self:RefreshProgress()
    if self.activeView == "skills" then
        self:LoadSkillEditor()
    elseif self.activeView == "character" then
        self:LoadCharacterEditor()
    else
        self:LoadEditor()
    end
end

function UI:SetMundusIcon(mundus)
    local icons = ZO_STAT_MUNDUS_ICONS
    self.mundusIcon:SetTexture(icons and icons[mundus] or "")
end

function UI:LoadCharacterEditor()
    if not self.characterPanel then
        return
    end
    local setup = self.owner.data:GetCurrentSetup()
    local character = setup.character or {}
    local attributes = character.attributes or {}
    self.loadingCharacter = true
    for _, key in ipairs({ "health", "magicka", "stamina" }) do
        self.attributeEdits[key]:SetText(tostring(attributes[key] or 0))
    end
    setComboChoices(self.raceCombo, getRaceChoices(), character.raceId or 0)
    setComboChoices(
        self.mundusCombo,
        getMundusChoices(),
        character.mundus or 0,
        function(value) self:SetMundusIcon(value) end
    )
    setComboChoices(self.curseCombo, getCurseChoices(), character.curse or 0)
    for index = 1, 3 do
        self.subclassEdits[index]:SetText(
            character.subclassLines and character.subclassLines[index] or ""
        )
    end
    self:SetMundusIcon(character.mundus or 0)
    self.loadingCharacter = false
    self:RefreshAttributeTotal()
end

function UI:RefreshAttributeTotal()
    if not self.attributeTotal or self.loadingCharacter then
        return
    end
    local total = 0
    for _, key in ipairs({ "health", "magicka", "stamina" }) do
        total = total + (tonumber(self.attributeEdits[key]:GetText()) or 0)
    end
    self.attributeTotal:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_ATTRIBUTE_TOTAL,
        total,
        64
    ))
    if total > 64 then
        self.attributeTotal:SetColor(1, 0.35, 0.3, 1)
    else
        self.attributeTotal:SetColor(0.75, 0.9, 0.65, 1)
    end
end

function UI:SaveCharacter()
    local setup, build = self.owner.data:GetCurrentSetup()
    local values = {
        attributes = {
            health = tonumber(self.attributeEdits.health:GetText()) or 0,
            magicka = tonumber(self.attributeEdits.magicka:GetText()) or 0,
            stamina = tonumber(self.attributeEdits.stamina:GetText()) or 0,
        },
        raceId = self.raceCombo.selectedValue or 0,
        mundus = self.mundusCombo.selectedValue or 0,
        curse = self.curseCombo.selectedValue or 0,
        subclassLines = {},
    }
    for index = 1, 3 do
        values.subclassLines[index] = self.subclassEdits[index]:GetText()
    end
    local ok, message = self.owner.data:UpdateCharacter(build.id, setup.id, values)
    if not ok then
        self:SetStatus(message, true)
        self:RefreshAttributeTotal()
        return
    end
    self:LoadCharacterEditor()
    self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_CHARACTER_SAVED))
end

function UI:RefreshSkillBars()
    if not self.skillButtons then
        return
    end
    local setup = self.owner.data:GetCurrentSetup()
    local bars = setup.skillBars or { front = {}, back = {} }
    for _, barKey in ipairs({ "front", "back" }) do
        for slotIndex = 1, 6 do
            local button = self.skillButtons[barKey][slotIndex]
            local skill = bars[barKey] and bars[barKey][slotIndex]
            button.icon:SetTexture(skill and skill.icon or EMPTY_SKILL_TEXTURE)
            local selected = barKey == self.selectedSkillBar
                and slotIndex == self.selectedSkillSlot
            button.backdrop:SetEdgeColor(
                selected and 1 or 0.36,
                selected and 0.76 or 0.32,
                selected and 0.28 or 0.24,
                1
            )
        end
    end
end

function UI:LoadSkillEditor()
    if not self.skillEdit then
        return
    end
    local setup = self.owner.data:GetCurrentSetup()
    local bar = setup.skillBars and setup.skillBars[self.selectedSkillBar] or {}
    local skill = bar[self.selectedSkillSlot]
    self.loadingSkill = true
    self.selectedAbility = skill
    self.skillEdit:SetText(skill and skill.name or "")
    self.skillEditorTitle:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_SKILL_SLOT_TITLE,
        GetString(self.selectedSkillBar == "front"
            and SI_GRAVVY_BUILD_PLANNER_FRONT_BAR
            or SI_GRAVVY_BUILD_PLANNER_BACK_BAR),
        self.selectedSkillSlot == 6
            and GetString(SI_GRAVVY_BUILD_PLANNER_ULTIMATE)
            or tostring(self.selectedSkillSlot)
    ))
    self.skillPreview:SetTexture(skill and skill.icon or EMPTY_SKILL_TEXTURE)
    self.skillName:SetText(skill and skill.name or GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED))
    self.skillSuggestionPanel:SetHidden(true)
    self.loadingSkill = false
end

function UI:OnSkillTextChanged()
    if self.loadingSkill then
        return
    end
    self.selectedAbility = nil
    self.skillSuggestionData = self.owner.skillCatalog:Search(
        self.skillEdit:GetText(),
        self.selectedSkillSlot == 6,
        20
    )
    self.skillSuggestionIndex = 1
    self:RenderSkillSuggestions()
end

function UI:RenderSkillSuggestions()
    local data = self.skillSuggestionData or {}
    for index, button in ipairs(self.skillSuggestionButtons) do
        local entry = data[index]
        button:SetHidden(not entry)
        if entry then
            button:SetText(entry.name)
            button:SetNormalFontColor(
                index == self.skillSuggestionIndex and 1 or 0.85,
                index == self.skillSuggestionIndex and 0.82 or 0.78,
                index == self.skillSuggestionIndex and 0.4 or 0.62,
                1
            )
        end
    end
    self.skillSuggestionPanel:SetHidden(#data == 0)
end

function UI:ChooseSkillSuggestion(index)
    local entry = self.skillSuggestionData and self.skillSuggestionData[index]
    if not entry then
        return
    end
    self.selectedAbility = entry
    self.loadingSkill = true
    self.skillEdit:SetText(entry.name)
    self.loadingSkill = false
    self.skillPreview:SetTexture(entry.icon)
    self.skillName:SetText(entry.name)
    self.skillSuggestionPanel:SetHidden(true)
end

function UI:ResolveTypedSkill()
    if self.selectedAbility then
        return self.selectedAbility
    end
    local entry = self.owner.skillCatalog:FindExact(self.skillEdit:GetText())
    if entry and entry.isUltimate == (self.selectedSkillSlot == 6) then
        self.selectedAbility = entry
        self.skillPreview:SetTexture(entry.icon)
        self.skillName:SetText(entry.name)
        return entry
    end
end

function UI:OnSkillKeyDown(key)
    if self.skillSuggestionPanel:IsHidden() then
        return
    end
    local count = math.min(6, #(self.skillSuggestionData or {}))
    if key == KEY_DOWN then
        self.skillSuggestionIndex = math.min(count, self.skillSuggestionIndex + 1)
        self:RenderSkillSuggestions()
    elseif key == KEY_UP then
        self.skillSuggestionIndex = math.max(1, self.skillSuggestionIndex - 1)
        self:RenderSkillSuggestions()
    elseif key == KEY_ENTER then
        self:ChooseSkillSuggestion(self.skillSuggestionIndex)
    elseif key == KEY_ESCAPE then
        self.skillSuggestionPanel:SetHidden(true)
    end
end

function UI:SaveSkill()
    local skill = self:ResolveTypedSkill()
    if not skill then
        self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SKILL), true)
        return
    end
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, message = self.owner.data:SetSkill(
        build.id,
        setup.id,
        self.selectedSkillBar,
        self.selectedSkillSlot,
        skill
    )
    if not ok then
        self:SetStatus(message, true)
        return
    end
    self:RefreshSkillBars()
    self:LoadSkillEditor()
    self:SetStatus(zo_strformat(SI_GRAVVY_BUILD_PLANNER_SKILL_SAVED, skill.name))
end

function UI:ClearSkill()
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, message = self.owner.data:SetSkill(
        build.id,
        setup.id,
        self.selectedSkillBar,
        self.selectedSkillSlot,
        nil
    )
    if not ok then
        self:SetStatus(message, true)
        return
    end
    self:RefreshSkillBars()
    self:LoadSkillEditor()
    self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_SKILL_CLEARED))
end

function UI:ShowSkillTooltip(control, barKey, slotIndex)
    local setup = self.owner.data:GetCurrentSetup()
    local skill = setup.skillBars and setup.skillBars[barKey]
        and setup.skillBars[barKey][slotIndex]
    if skill and SkillTooltip and InitializeTooltip then
        InitializeTooltip(SkillTooltip, control, LEFT, -8, 0, RIGHT)
        local catalogEntry = self.owner.skillCatalog:FindById(skill.abilityId)
        if catalogEntry and catalogEntry.progression
            and catalogEntry.progression.SetKeyboardTooltip then
            catalogEntry.progression:SetKeyboardTooltip(
                SkillTooltip,
                false,
                false,
                false,
                false
            )
        else
            SkillTooltip:LayoutSimpleAbility(skill.abilityId)
        end
    end
end

function UI:HideSkillTooltip()
    if SkillTooltip and ClearTooltip then
        ClearTooltip(SkillTooltip)
    end
end

function UI:EditSlot(slotKey)
    self.selectedSlot = slotKey
    self.editorAlternativeIndex = nil
    self:LoadEditor()
    self:RefreshRows()
end

function UI:LoadEditor()
    self.loadingEditor = true
    local setup = self.owner.data:GetCurrentSetup()
    local alternatives = self.owner.data:GetAlternatives(setup, self.selectedSlot)
    if self.editorAlternativeIndex and self.editorAlternativeIndex > #alternatives + 1 then
        self.editorAlternativeIndex = nil
    end
    local requirement = self.editorAlternativeIndex
        and (alternatives[self.editorAlternativeIndex]
            or setup.equipment[self.selectedSlot])
        or setup.equipment[self.selectedSlot]
        or {}
    local definition = Slots:Get(self.selectedSlot)
    self.editorTitle:SetText(slotName(self.selectedSlot))
    setComboChoices(
        self.alternativeCombo,
        self:GetAlternativeChoices(setup, self.selectedSlot),
        self.editorAlternativeIndex or 0,
        function(value)
            self.editorAlternativeIndex = value ~= 0 and value or nil
            self:LoadEditor()
        end
    )
    local savedAlternative = self.editorAlternativeIndex
        and alternatives[self.editorAlternativeIndex]
    self.setAlternativeButton:SetEnabled(savedAlternative ~= nil)
    self.setAlternativeButton:SetAlpha(savedAlternative and 1 or 0.55)

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
    local acquisition = setup.acquisition[self.selectedSlot]
    self.editorPreferredRoute = acquisition and acquisition.preferredRoute or nil
    local editingPrimary = self.editorAlternativeIndex == nil
    self.slotActionButton:SetEnabled(editingPrimary and setup.equipment[self.selectedSlot] ~= nil)
    self.slotActionButton:SetAlpha(
        editingPrimary and setup.equipment[self.selectedSlot] and 1 or 0.55
    )
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
    local setup = self.owner.data:GetCurrentSetup()
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
    local saved = self.editorAlternativeIndex
        and self.owner.data:GetAlternatives(setup, self.selectedSlot)[self.editorAlternativeIndex]
        or setup.equipment[self.selectedSlot]
    if saved
        and zo_strlower(zo_strtrim(saved.setName or ""))
            == zo_strlower(zo_strtrim(requirement.setName or "")) then
        requirement.itemLink = saved.itemLink
        requirement.itemId = saved.itemId
        requirement.itemName = saved.itemName
    end
    return requirement
end

function UI:RefreshEditorPreview(requirement)
    local setup = self.owner.data:GetCurrentSetup()
    requirement = requirement or self:ReadEditorRequirement()
    local resolved = self.owner.itemResolver:Resolve(self.selectedSlot, requirement, setup)
    self.previewLink = resolved and resolved.itemLink or requirement.itemLink
    self.previewRequirement = requirement

    local acquisition = self.owner.acquisition:Classify(
        self.selectedSlot,
        requirement,
        setup,
        resolved
    )
    local owned = self.owner.inventory
        and self.owner.inventory:GetMatch(
            setup.id,
            self.selectedSlot,
            requirement,
            setup
        )
    local routes = self.owner.acquisition:GetAvailableRoutes(acquisition, owned)
    local routeChoices = {}
    if #routes > 1 then
        routeChoices[1] = {
            label = GetString(SI_GRAVVY_BUILD_PLANNER_ROUTE_AUTOMATIC),
            value = AUTOMATIC_ROUTE,
        }
    end
    local preferredAvailable = false
    for _, route in ipairs(routes) do
        routeChoices[#routeChoices + 1] = {
            label = self.owner.acquisition:GetRouteLabel(route),
            value = route,
        }
        preferredAvailable = preferredAvailable or route == self.editorPreferredRoute
    end
    if not preferredAvailable then
        self.editorPreferredRoute = nil
    end
    setComboChoices(
        self.routeCombo,
        routeChoices,
        #routes > 1 and (self.editorPreferredRoute or AUTOMATIC_ROUTE) or routes[1],
        function(route)
            self.editorPreferredRoute = route ~= AUTOMATIC_ROUTE and route or nil
            local currentSetup, currentBuild = self.owner.data:GetCurrentSetup()
            if currentSetup.equipment[self.selectedSlot] then
                self.owner.data:SetPreferredRoute(
                    currentBuild.id,
                    currentSetup.id,
                    self.selectedSlot,
                    self.editorPreferredRoute
                )
            end
            self:RefreshEditorPreview()
        end
    )
    self.routeCombo:SetEnabled(#routes > 1)
    self.routeContainer:SetAlpha(#routes > 1 and 1 or 0.65)
    self.acquisitionLabel:SetText(self.owner.acquisition:GetStatus(
        acquisition,
        owned,
        self.editorPreferredRoute
    ))

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

function UI:RefreshOwnedStatus()
    if self.window and not self.window:IsHidden() then
        self:RefreshRows()
        self:RefreshProgress()
        self:RefreshEditorPreview()
    end
end

function UI:RefreshProgress()
    if not self.progressLabel then
        return
    end
    local setup = self.owner.data:GetCurrentSetup()
    local progress = self.owner.inventory and self.owner.inventory:GetProgress(setup.id)
        or { planned = 0, ready = 0, adjustable = 0, missing = 0 }
    self.progressLabel:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_SETUP_PROGRESS,
        progress.ready,
        progress.planned,
        progress.adjustable,
        progress.missing
    ))
end

function UI:ShowSlotTooltip(slotKey, control)
    local setup = self.owner.data:GetCurrentSetup()
    local displaySlot = control.occupiedBy or slotKey
    local requirement = setup.equipment[displaySlot]
    local itemLink = requirement and requirement.itemLink
    if requirement and (not itemLink or itemLink == "") then
        local resolved = self.owner.itemResolver:Resolve(displaySlot, requirement, setup)
        itemLink = resolved and resolved.itemLink
    end
    if itemLink and itemLink ~= "" then
        self:ShowItemTooltip(control, itemLink, requirement)
        local alternativeCount = #self.owner.data:GetAlternatives(setup, displaySlot)
        if alternativeCount > 0 and ItemTooltip.AddLine then
            ItemTooltip:AddLine(
                zo_strformat(
                    SI_GRAVVY_BUILD_PLANNER_ALTERNATIVE_COUNT,
                    alternativeCount
                ),
                "ZoFontGameSmall",
                0.82,
                0.76,
                0.58
            )
        end
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

    local ok, message
    if self.editorAlternativeIndex then
        ok, message = self.owner.data:SetAlternative(
            build.id,
            setup.id,
            self.selectedSlot,
            self.editorAlternativeIndex,
            requirement
        )
    else
        ok, message = self.owner.data:SetEquipment(
            build.id,
            setup.id,
            self.selectedSlot,
            requirement
        )
    end
    if not ok then
        self:SetStatus(message, true)
        return
    end
    if not self.editorAlternativeIndex then
        self.owner.data:SetPreferredRoute(
            build.id,
            setup.id,
            self.selectedSlot,
            self.editorPreferredRoute
        )
    end
    self.owner.setCatalog:Refresh()
    if self.owner.inventory then
        self.owner.inventory:Refresh()
    end
    self:RefreshRows()
    self:LoadEditor()
    local statusId = self.editorAlternativeIndex
        and SI_GRAVVY_BUILD_PLANNER_ALTERNATIVE_SAVED
        or SI_GRAVVY_BUILD_PLANNER_SLOT_SAVED
    self:SetStatus(zo_strformat(statusId, slotName(self.selectedSlot)))
end

function UI:ClearSlot()
    local setup, build = self.owner.data:GetCurrentSetup()
    local clearingAlternative = self.editorAlternativeIndex ~= nil
    local ok, message
    if clearingAlternative then
        ok, message = self.owner.data:SetAlternative(
            build.id,
            setup.id,
            self.selectedSlot,
            self.editorAlternativeIndex,
            nil
        )
    else
        ok, message = self.owner.data:SetEquipment(
            build.id,
            setup.id,
            self.selectedSlot,
            nil
        )
    end
    if not ok then
        self:SetStatus(message, true)
        return
    end
    if clearingAlternative then
        self.editorAlternativeIndex = nil
    end
    if self.owner.inventory then
        self.owner.inventory:Refresh()
    end
    self:RefreshRows()
    self:LoadEditor()
    local statusId = clearingAlternative
        and SI_GRAVVY_BUILD_PLANNER_ALTERNATIVE_REMOVED
        or SI_GRAVVY_BUILD_PLANNER_SLOT_CLEARED
    self:SetStatus(zo_strformat(statusId, slotName(self.selectedSlot)))
end

function UI:ApplySetAlternative()
    if not self.editorAlternativeIndex then
        return
    end
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, result = self.owner.data:ApplySetAlternative(
        build.id,
        setup.id,
        self.selectedSlot,
        self.editorAlternativeIndex
    )
    if not ok then
        self:SetStatus(result, true)
        return
    end
    if self.owner.inventory then
        self.owner.inventory:Refresh()
    end
    self:RefreshRows()
    self:SetStatus(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_SET_ALTERNATIVE_APPLIED,
        result
    ))
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
        if self.owner.inventory then
            self.owner.inventory:Refresh()
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
    if self.owner.inventory then
        self.owner.inventory:Refresh()
    end
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
    self.status:SetText(self.owner.accessibility:FormatStatus(message, isError))
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

function UI:AcquireMouse()
    if IsGameCameraUIModeActive and not IsGameCameraUIModeActive() then
        self.ownsUIMode = true
        SetGameCameraUIMode(true)
        zo_callLater(function()
            if self.ownsUIMode
                and (not self.window:IsHidden() or not self.helpDialog:IsHidden()) then
                SetGameCameraUIMode(true)
            end
        end, 10)
    end
end

function UI:RestoreOwnedMouse(delayMs)
    if not self.ownsUIMode
        or (self.window:IsHidden() and self.helpDialog:IsHidden()) then
        return
    end
    zo_callLater(function()
        if self.ownsUIMode
            and (not self.window:IsHidden() or not self.helpDialog:IsHidden())
            and IsGameCameraUIModeActive
            and not IsGameCameraUIModeActive() then
            SetGameCameraUIMode(true)
        end
    end, delayMs or 10)
end

function UI:RegisterFocusEvent()
    EVENT_MANAGER:RegisterForEvent(
        "GravvyBuildPlanner_GameFocusChanged",
        EVENT_GAME_FOCUS_CHANGED,
        function(_, hasFocus)
            if hasFocus then
                self:RestoreOwnedMouse(50)
            end
        end
    )
end

function UI:ReleaseMouse()
    if not self.ownsUIMode then
        return
    end
    self.ownsUIMode = false
    if IsGameCameraUIModeActive and IsGameCameraUIModeActive() then
        SetGameCameraUIMode(false)
    end
end

function UI:Show()
    self.window:SetHidden(false)
    self:AcquireMouse()
    self:Refresh()
end

function UI:Hide()
    self.suggestionPanel:SetHidden(true)
    self.nameDialog:SetHidden(true)
    self.confirmDialog:SetHidden(true)
    self.slotActionDialog:SetHidden(true)
    self.exportDialog:SetHidden(true)
    self.codeDialog:SetHidden(true)
    self.helpDialog:SetHidden(true)
    if self.owner.share and self.owner.share.window then
        self.owner.share:Hide()
    end
    self.helpRequestedMouse = false
    self.window:SetHidden(true)
    self:ReleaseMouse()
end

function UI:Toggle()
    if self.window:IsHidden() then
        self:Show()
    else
        self:Hide()
    end
end
