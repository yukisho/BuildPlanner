dofile("Tests/DataTests.lua")

local function expect(value, message)
    if not value then
        error(message or "expectation failed", 2)
    end
end

local function expectEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

ARMORTYPE_LIGHT = 1
ARMORTYPE_MEDIUM = 2
ARMORTYPE_HEAVY = 3
WEAPONTYPE_HAMMER = 11
WEAPONTYPE_SWORD = 12
WEAPONTYPE_DAGGER = 13
ITEM_TRAIT_TYPE_NONE = 0
ITEM_TRAIT_TYPE_ITERATION_BEGIN = 21
ITEM_TRAIT_TYPE_ITERATION_END = 23
ITEM_TRAIT_TYPE_CATEGORY_ARMOR = 1
ITEM_TRAIT_TYPE_CATEGORY_WEAPON = 2
ITEM_TRAIT_TYPE_CATEGORY_JEWELRY = 3
ITEM_QUALITY_NORMAL = 1
ITEM_QUALITY_MAGIC = 2
ITEM_QUALITY_ARCANE = 3
ITEM_QUALITY_ARTIFACT = 4

function GetItemTraitTypeCategory(traitType)
    return traitType - 20
end

TOPLEFT = "TOPLEFT"
TOPRIGHT = "TOPRIGHT"
BOTTOMLEFT = "BOTTOMLEFT"
BOTTOMRIGHT = "BOTTOMRIGHT"
LEFT = "LEFT"
RIGHT = "RIGHT"
CENTER = "CENTER"
CT_LABEL = 1
CT_BUTTON = 2
CT_CONTROL = 3
CT_TEXTURE = 4
TEXT_ALIGN_CENTER = 1
TEXT_ALIGN_LEFT = 2
TEXT_ALIGN_TOP = 3
TEXT_TYPE_NUMERIC = 1
DT_HIGH = 2
MOUSE_BUTTON_INDEX_LEFT = 1
KEY_UP = 1
KEY_DOWN = 2
KEY_ENTER = 3
KEY_ESCAPE = 4

local controlIndex = 0
local function newControl(name, parent)
    controlIndex = controlIndex + 1
    local control = {
        name = name or ("Control" .. tostring(controlIndex)),
        parent = parent,
        hidden = false,
        text = "",
        handlers = {},
        left = 100,
        top = 100,
    }

    function control:GetName() return self.name end
    function control:SetDimensions(width, height) self.width, self.height = width, height end
    function control:SetHeight(height) self.height = height end
    function control:SetAnchor() end
    function control:ClearAnchors() end
    function control:SetAnchorFill() end
    function control:SetClampedToScreen() end
    function control:SetMouseEnabled() end
    function control:SetMovable() end
    function control:SetDrawTier() end
    function control:SetCenterColor() end
    function control:SetEdgeColor() end
    function control:SetFont() end
    function control:SetColor() end
    function control:SetVerticalAlignment() end
    function control:SetHorizontalAlignment() end
    function control:SetNormalFontColor() end
    function control:SetMouseOverFontColor() end
    function control:SetPressedFontColor() end
    function control:SetMaxInputChars() end
    function control:SetNewLineEnabled() end
    function control:SetSelectAllOnFocus() end
    function control:SetTextType() end
    function control:SetEnabled(value) self.enabled = value end
    function control:SetAlpha(value) self.alpha = value end
    function control:SetHidden(value) self.hidden = value end
    function control:IsHidden() return self.hidden end
    function control:SetHandler(event, callback) self.handlers[event] = callback end
    function control:SetText(value) self.text = value or "" end
    function control:GetText() return self.text end
    function control:GetLeft() return self.left end
    function control:GetTop() return self.top end
    function control:StartMoving() end
    function control:StopMovingOrResizing() end
    function control:TakeFocus() end
    function control:SelectAll() end
    return control
end

WINDOW_MANAGER = {}
function WINDOW_MANAGER:CreateTopLevelWindow(name)
    return newControl(name)
end
function WINDOW_MANAGER:CreateControl(name, parent)
    return newControl(name, parent)
end
function WINDOW_MANAGER:CreateControlFromVirtual(name, parent)
    return newControl(name, parent)
end

function ZO_ComboBox_ObjectFromContainer(container)
    local combo = { container = container, items = {} }
    function combo:SetSortsItems() end
    function combo:ClearItems() self.items = {} end
    function combo:CreateItemEntry(label, callback)
        return { label = label, callback = callback }
    end
    function combo:AddItem(item) self.items[#self.items + 1] = item end
    function combo:SetSelectedItem(label) self.selectedLabel = label end
    return combo
end

GuiRoot = newControl("GuiRoot")

dofile("UI.lua")

local owner = {
    data = BuildPlannerTestData,
    setCatalog = BuildPlannerTestCatalog,
}
local ui = GravvyBuildPlannerUI:New(owner)
ui:Initialize()

expectEqual(#GravvyBuildPlannerSlots.ORDER, 14, "planner should expose all canonical slots")
expect(ui.window:IsHidden(), "planner should start hidden")
ui:Toggle()
expect(not ui.window:IsHidden(), "toggle should show planner")

ui:EditSlot("head")
ui.setEdit:SetText("or")
ui:OnSetTextChanged()
expectEqual(#ui.suggestionData, 2, "autocomplete should include prefix and substring matches")
ui:OnSetKeyDown(KEY_DOWN)
ui:OnSetKeyDown(KEY_ENTER)
expectEqual(ui.setEdit:GetText(), "Whorl of the Depths", "keyboard selection should choose the highlighted set")

ui.setEdit:SetText("Pillar of Nirn")
ui:OnSetTextChanged()
expect(not ui.suggestionPanel:IsHidden(), "matching sets should show suggestions")
ui:ChooseSuggestion(1)
ui.typeCombo.selectedValue = ARMORTYPE_MEDIUM
ui.traitCombo.selectedValue = 21
ui.qualityCombo.selectedValue = ITEM_QUALITY_LEGENDARY
ui.cpEdit:SetText("160")
ui.enchantmentEdit:SetText("Maximum Stamina")
ui:SaveSlot()

local setup = BuildPlannerTestData:GetCurrentSetup()
expectEqual(setup.equipment.head.setId, 34, "selected set id should be saved")
expectEqual(setup.equipment.head.armorType, ARMORTYPE_MEDIUM, "selected armor type should be saved")
expectEqual(setup.equipment.head.championPoints, 160, "numeric editor values should be saved")

ui:ClearSlot()
expectEqual(setup.equipment.head, nil, "clear button should remove the requirement")

dofile("MainMenu.lua")
GravvyBuildPlannerMainMenu:Initialize(owner)
LibMainMenu2 = {
    Init = function(self) self.initialized = true end,
    AddMenuItem = function(self, name, definition)
        self.itemName = name
        self.definition = definition
    end,
}
GravvyBuildPlannerMainMenu:Initialize(owner)
expect(LibMainMenu2.initialized, "main menu library should be initialized when available")
expectEqual(LibMainMenu2.definition.binding, "GRAVVY_BUILD_PLANNER_TOGGLE", "main menu should use the addon keybind")

SLASH_COMMANDS = {}
EVENT_ADD_ON_LOADED = 1
EVENT_MANAGER = {
    RegisterForEvent = function(self, _, _, callback) self.addOnLoaded = callback end,
    UnregisterForEvent = function() end,
}
dofile("GravvyBuildPlanner.lua")
EVENT_MANAGER.addOnLoaded(nil, "GravvyBuildPlanner")
expect(SLASH_COMMANDS["/buildplanner"], "long slash command should be registered")
expect(SLASH_COMMANDS["/gbp"], "short slash command should be registered")

print("Build Planner UI tests passed")
