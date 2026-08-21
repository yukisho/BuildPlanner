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
BIND_TYPE_NONE = 0
BIND_TYPE_ON_EQUIP = 1
BIND_TYPE_ON_PICKUP = 2
BIND_TYPE_ON_PICKUP_BACKPACK = 3
ITEM_SET_TYPE_NONE = 0
ITEM_SET_TYPE_CRAFTED = 1
ITEM_SET_TYPE_DUNGEON = 2
ITEM_SET_TYPE_MONSTER = 3
ITEM_SET_TYPE_WEAPON = 4
ITEM_SET_TYPE_WORLD = 5
ITEM_TRAIT_TYPE_ARMOR_DIVINES = 21
ITEM_TRAIT_TYPE_WEAPON_PRECISE = 22
ITEM_TRAIT_TYPE_JEWELRY_ARCANE = 23
LINK_STYLE_DEFAULT = 0
BAG_WORN = 1
BAG_BACKPACK = 2
BAG_BANK = 3
BAG_SUBSCRIBER_BANK = 4

EQUIP_TYPE_HEAD = 1
EQUIP_TYPE_SHOULDERS = 2
EQUIP_TYPE_CHEST = 3
EQUIP_TYPE_HAND = 4
EQUIP_TYPE_WAIST = 5
EQUIP_TYPE_LEGS = 6
EQUIP_TYPE_FEET = 7
EQUIP_TYPE_NECK = 8
EQUIP_TYPE_RING = 9
EQUIP_TYPE_TWO_HAND = 10

local enchantmentNames = {
    "ABSORB_HEALTH", "ABSORB_MAGICKA", "ABSORB_STAMINA", "BEFOULED_WEAPON",
    "BERSERKER", "CHARGED_WEAPON", "DAMAGE_HEALTH", "DAMAGE_SHIELD",
    "DECREASE_PHYSICAL_DAMAGE", "DECREASE_SPELL_DAMAGE", "DISEASE_RESISTANT",
    "FIERY_WEAPON", "FIRE_RESISTANT", "FROST_RESISTANT", "FROZEN_WEAPON",
    "HEALTH", "HEALTH_REGEN", "INCREASE_BASH_DAMAGE", "INCREASE_PHYSICAL_DAMAGE",
    "INCREASE_POTION_EFFECTIVENESS", "INCREASE_SPELL_DAMAGE", "MAGICKA",
    "MAGICKA_REGEN", "POISONED_WEAPON", "POISON_RESISTANT", "PRISMATIC_DEFENSE",
    "PRISMATIC_ONSLAUGHT", "PRISMATIC_REGEN", "REDUCE_ARMOR",
    "REDUCE_BLOCK_AND_BASH", "REDUCE_FEAT_COST", "REDUCE_POTION_COOLDOWN",
    "REDUCE_POWER", "REDUCE_SPELL_COST", "SHOCK_RESISTANT", "STAMINA",
    "STAMINA_REGEN",
}
for index, name in ipairs(enchantmentNames) do
    _G["ENCHANTMENT_SEARCH_CATEGORY_" .. name] = 100 + index
end

function GetItemTraitTypeCategory(traitType)
    return traitType - 20
end

TOPLEFT = "TOPLEFT"
TOPRIGHT = "TOPRIGHT"
BOTTOMLEFT = "BOTTOMLEFT"
BOTTOMRIGHT = "BOTTOMRIGHT"
LEFT = "LEFT"
RIGHT = "RIGHT"
LEFT = "LEFT"
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
    function control:SetTexture(value) self.texture = value end
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
    function combo:SetEnabled(value) self.enabled = value end
    return combo
end

GuiRoot = newControl("GuiRoot")

local itemLinks = {}
local function getLinkFields(link)
    local data = link:match("^|H%d+:item:([^|]+)|h")
    if not data then
        return nil
    end
    local fields = {}
    for value in data:gmatch("([^:]+)") do
        fields[#fields + 1] = value
    end
    return fields
end

function GetNumItemSetCollectionPieces(setId)
    return (setId == 12 or setId == 34 or setId == 56) and 3 or 0
end
function GetItemSetCollectionPieceInfo(setId, index)
    if index >= 1 and index <= 3 then
        return (setId * 100) + index, index
    end
end
function GetItemSetCollectionPieceItemLink(pieceId, _, traitType, quality)
    local link = "item:" .. tostring(pieceId)
    local suffix = pieceId % 100
    local setId = math.floor(pieceId / 100)
    if pieceId >= 5601 and pieceId <= 5603 then
        itemLinks[link] = {
            itemId = pieceId,
            name = "Monster Helm",
            equipType = EQUIP_TYPE_HEAD,
            armorType = suffix,
            weaponType = WEAPONTYPE_NONE,
            enchantId = 501,
        }
    elseif suffix == 1 then
        itemLinks[link] = {
            itemId = pieceId,
            name = pieceId == 3401 and "Helm of Pillar of Nirn" or "Helm of Order's Wrath",
            equipType = EQUIP_TYPE_HEAD,
            armorType = pieceId == 3401 and ARMORTYPE_MEDIUM or ARMORTYPE_LIGHT,
            weaponType = WEAPONTYPE_NONE,
            enchantId = 501,
        }
    elseif suffix == 2 then
        itemLinks[link] = {
            itemId = pieceId,
            name = "Ring of Pillar of Nirn",
            equipType = EQUIP_TYPE_RING,
            armorType = ARMORTYPE_NONE,
            weaponType = WEAPONTYPE_NONE,
            enchantId = 502,
        }
    else
        itemLinks[link] = {
            itemId = pieceId,
            name = "Greatsword of Pillar of Nirn",
            equipType = EQUIP_TYPE_TWO_HAND,
            armorType = ARMORTYPE_NONE,
            weaponType = WEAPONTYPE_TWO_HANDED_SWORD,
            enchantId = 503,
        }
    end
    local item = itemLinks[link]
    item.setId = setId
    item.setName = setId == 12 and "Order's Wrath"
        or setId == 34 and "Pillar of Nirn"
        or "Monster Set"
    item.traitType = traitType or ITEM_TRAIT_TYPE_NONE
    item.quality = quality or ITEM_QUALITY_NORMAL
    item.level = 50
    item.championPoints = 160
    return link
end
function GetItemLinkEquipType(link) return itemLinks[link].equipType end
function GetItemLinkArmorType(link) return itemLinks[link].armorType end
function GetItemLinkWeaponType(link) return itemLinks[link].weaponType end
function GetItemLinkItemId(link) return itemLinks[link].itemId end
function GetItemLinkName(link) return itemLinks[link].name end
function GetItemLinkIcon(link) return "icon:" .. link end
function GetItemLinkTraitInfo(link) return itemLinks[link].traitType end
function GetItemLinkDisplayQuality(link) return itemLinks[link].quality end
function GetItemLinkSetInfo(link)
    local item = itemLinks[link]
    if item and item.setId then
        return true, item.setName, 0, 0, 0, item.setId, 0
    end
    return false, "", 0, 0, 0, 0, 0
end
function IsItemLinkCrafted(link) return link == "crafted:item" end
function GetItemLinkBindType(link)
    if link == "crafted:item" then
        return BIND_TYPE_NONE
    end
    local item = itemLinks[link]
    if item and item.itemId >= 1200 and item.itemId < 1300 then
        return BIND_TYPE_ON_EQUIP
    end
    return BIND_TYPE_ON_PICKUP
end
function GetItemSetType(setId)
    if setId == 12 then
        return ITEM_SET_TYPE_WORLD
    elseif setId == 34 then
        return ITEM_SET_TYPE_DUNGEON
    elseif setId == 56 then
        return ITEM_SET_TYPE_MONSTER
    end
    return ITEM_SET_TYPE_NONE
end
function IsItemSetCollectionPieceUnlocked(pieceId)
    return pieceId == 3401
end
local function getLinkedGlyphId(link)
    local fields = getLinkFields(link)
    if not fields then
        return nil
    end
    return tonumber(fields[4])
end
function GetItemLinkRequiredLevel(link)
    if itemLinks[link] then
        return itemLinks[link].level
    end
    local fields = getLinkFields(link)
    return fields and tonumber(fields[3]) or 50
end
function GetItemLinkRequiredChampionPoints(link)
    if itemLinks[link] then
        return itemLinks[link].championPoints
    end
    local fields = getLinkFields(link)
    if not fields then
        return 160
    end
    local subType = tonumber(fields[2])
    if subType >= 366 and subType <= 370 then
        return 160
    elseif subType >= 308 and subType <= 312 then
        return 150
    end
    return 0
end
function GetItemLinkAppliedEnchantId(link)
    return getLinkedGlyphId(link) or 0
end
function GetItemLinkFinalEnchantId(link)
    return getLinkedGlyphId(link) or (itemLinks[link] and itemLinks[link].enchantId) or 0
end
function GetEnchantSearchCategoryType(enchantId)
    if enchantId == 501 then
        return ENCHANTMENT_SEARCH_CATEGORY_HEALTH
    elseif enchantId == 502 then
        return ENCHANTMENT_SEARCH_CATEGORY_HEALTH_REGEN
    elseif enchantId == 503 then
        return ENCHANTMENT_SEARCH_CATEGORY_BERSERKER
    elseif enchantId == 26588 then
        return ENCHANTMENT_SEARCH_CATEGORY_STAMINA
    end
end

local testBags = {}
function GetBagSize(bagId)
    return #(testBags[bagId] or {})
end
function GetItemLink(bagId, slotIndex)
    local bag = testBags[bagId] or {}
    return bag[slotIndex + 1] or ""
end
function GetSlotStackSize(bagId, slotIndex)
    return GetItemLink(bagId, slotIndex) ~= "" and 1 or 0
end

ItemTooltip = newControl("ItemTooltip")
function ItemTooltip:SetLink(link) self.link = link end
function ItemTooltip:AddLine(text) self.extraLine = text end
function InitializeTooltip() end
function ClearTooltip(tooltip) tooltip.link = nil end

dofile("Enchantments.lua")
dofile("ItemResolver.lua")
dofile("Acquisition.lua")
dofile("Inventory.lua")
dofile("UI.lua")

local owner = {
    data = BuildPlannerTestData,
    setCatalog = BuildPlannerTestCatalog,
    itemResolver = GravvyBuildPlannerItemResolver:New(),
}
owner.acquisition = GravvyBuildPlannerAcquisition:New(owner.itemResolver)
owner.inventory = GravvyBuildPlannerInventory:New(owner)
local ui = GravvyBuildPlannerUI:New(owner)
ui:Initialize()

local resolverSetup = BuildPlannerTestData:GetCurrentSetup()
local matchingEnchant = owner.itemResolver:Resolve("head", {
    setId = 34,
    armorType = ARMORTYPE_MEDIUM,
    enchantmentCategory = ENCHANTMENT_SEARCH_CATEGORY_HEALTH,
}, resolverSetup)
expect(matchingEnchant.enchantmentMatches, "resolver should recognize a matching default enchantment")
expectEqual(matchingEnchant.pieceId, 3401, "resolver should retain the collection piece id")
expectEqual(matchingEnchant.collectionSlot, 1, "resolver should retain the collection slot")
local tradeableState = owner.acquisition:Classify("head", {
    setId = 12,
    armorType = ARMORTYPE_LIGHT,
}, resolverSetup)
expect(tradeableState.tradeable, "bind-on-equip pieces should be guild-store eligible")
expect(not tradeableState.bindOnPickup, "bind-on-equip pieces should not be marked bind-on-pickup")
expect(not tradeableState.reconstructable, "uncollected pieces should not be reconstructable")
local reconstructState = owner.acquisition:Classify("head", {
    setId = 34,
    armorType = ARMORTYPE_MEDIUM,
}, resolverSetup)
expect(reconstructState.bindOnPickup, "dungeon pieces should retain their bind policy")
expect(not reconstructState.tradeable, "bind-on-pickup pieces should not be guild-store eligible")
expect(reconstructState.reconstructable, "unlocked collection pieces should be reconstructable")
local craftedState = owner.acquisition:Classify("head", {
    itemLink = "crafted:item",
}, resolverSetup)
expect(craftedState.crafted, "crafted links should be recognized")
expect(craftedState.tradeable, "unbound crafted links should be guild-store eligible")
local unknownState = owner.acquisition:Classify("head", {}, resolverSetup)
expect(unknownState.unknown, "unresolved requirements should remain unknown")
local monsterArmorTypes = owner.itemResolver:GetAvailableArmorTypes("head", 56)
expectEqual(#monsterArmorTypes, 3, "monster sets should retain every available armor weight")
local plannedEnchantLink = owner.itemResolver:ApplyPlannedEnchantment(
    "|H1:item:3401:370:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h",
    ENCHANTMENT_SEARCH_CATEGORY_STAMINA
)
expect(plannedEnchantLink, "resolver should build a validated planned enchantment link")
expect(plannedEnchantLink:find(":26588:370:50:", 1, true), "planned link should carry the stamina glyph")
local levelThirtyLink = owner.itemResolver:ApplyPlannedLevel(
    "|H1:item:3401:370:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h",
    { level = 30 },
    resolverSetup,
    ITEM_QUALITY_LEGENDARY
)
expect(levelThirtyLink, "resolver should build a validated level 30 link")
expect(levelThirtyLink:find(":24:30:0:", 1, true), "level 30 link should use the legendary low-level subtype")
local levelThirtyStaminaLink = owner.itemResolver:ApplyPlannedEnchantment(
    levelThirtyLink,
    ENCHANTMENT_SEARCH_CATEGORY_STAMINA
)
expect(
    levelThirtyStaminaLink:find(":26588:24:30:", 1, true),
    "planned enchantments should inherit the preview level and quality"
)
local cpOneFiftyLink = owner.itemResolver:ApplyPlannedLevel(
    "|H1:item:3401:370:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h",
    { championPoints = 150 },
    resolverSetup,
    ITEM_QUALITY_LEGENDARY
)
expect(cpOneFiftyLink, "resolver should build a validated CP 150 link")
expect(cpOneFiftyLink:find(":312:50:0:", 1, true), "CP 150 link should use the legendary CP 150 subtype")
expect(owner.itemResolver:Resolve("ring1", { setId = 34 }, resolverSetup), "resolver should find jewelry pieces")
expect(owner.itemResolver:Resolve("frontMain", {
    setId = 34,
    weaponType = WEAPONTYPE_TWO_HANDED_SWORD,
}, resolverSetup), "resolver should find matching two-handed weapons")
expectEqual(owner.itemResolver:Resolve("frontOff", {
    setId = 34,
    weaponType = WEAPONTYPE_TWO_HANDED_SWORD,
}, resolverSetup), nil, "resolver should reject two-handed off-hand weapons")

ui:EditSlot("frontOff")
ui.typeCombo.selectedValue = WEAPONTYPE_SHIELD
ui:OnEquipmentTypeChanged()
expectEqual(#ui.traitCombo.items, 2, "shields should use armor traits")
expectEqual(#ui.enchantmentCombo.items, 5, "shields should use armor enchantments")

ui:EditSlot("waist")
expectEqual(ui.enchantmentCombo.selectedValue, GravvyBuildPlannerEnchantments.CUSTOM, "older free-text enchantments should remain selectable")
ui:SaveSlot()
expectEqual(BuildPlannerTestData:GetCurrentSetup().equipment.waist.enchantmentName, "Magicka", "saving should preserve a legacy enchantment")

expectEqual(#GravvyBuildPlannerSlots.ORDER, 14, "planner should expose all canonical slots")
expect(ui.window:IsHidden(), "planner should start hidden")
ui:Toggle()
expect(not ui.window:IsHidden(), "toggle should show planner")

ui:EditSlot("head")
expect(#ui.enchantmentCombo.items >= 5, "armor slots should offer contextual enchantments")
expect(ui.levelLabel.text:find("50", 1, true), "level label should show the setup default")
expect(ui.cpLabel.text:find("160", 1, true), "CP label should show the setup default")
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
expectEqual(ui.typeCombo.selectedValue, ARMORTYPE_MEDIUM, "fixed-weight sets should select their available weight")
expectEqual(ui.typeCombo.enabled, false, "fixed-weight set armor controls should be locked")
ui.typeCombo.selectedValue = ARMORTYPE_MEDIUM
ui.traitCombo.selectedValue = 21
ui.qualityCombo.selectedValue = ITEM_QUALITY_LEGENDARY
ui.cpEdit:SetText("155")
expectEqual(ui:ReadEditorRequirement().championPoints, 150, "CP overrides should use valid ten-point steps")
ui.cpEdit:SetText("160")
ui.enchantmentCombo.selectedValue = ENCHANTMENT_SEARCH_CATEGORY_STAMINA
ui:RefreshEditorPreview()
expect(ui.previewIcon.texture, "resolved previews should use the item's icon")
ui:SaveSlot()

local setup = BuildPlannerTestData:GetCurrentSetup()
expectEqual(setup.equipment.head.setId, 34, "selected set id should be saved")
expectEqual(setup.equipment.head.armorType, ARMORTYPE_MEDIUM, "selected armor type should be saved")
expectEqual(setup.equipment.head.championPoints, 160, "numeric editor values should be saved")
expectEqual(setup.equipment.head.enchantmentCategory, ENCHANTMENT_SEARCH_CATEGORY_STAMINA, "enchantment category should be saved")
expect(setup.equipment.head.itemLink, "matching collection piece should be resolved")
expect(ui.acquisitionLabel.text:find(
    GetString(SI_GRAVVY_BUILD_PLANNER_ACQUISITION_RECONSTRUCT),
    1,
    true
), "saved collection pieces should show reconstruction availability")
ui:ShowSlotTooltip("head", ui.rows.head)
expectEqual(ItemTooltip.link, setup.equipment.head.itemLink, "slot hover should show the native item tooltip")
expect(ItemTooltip.extraLine, "tooltip should identify a planned enchantment that differs from the preview")

ui:OpenSlotActionDialog()
local hasShoulders = false
local hasRing = false
for _, entry in ipairs(ui.slotTargetCombo.items) do
    hasShoulders = hasShoulders or entry.label == GetString(SI_GRAVVY_BUILD_PLANNER_SLOT_SHOULDERS)
    hasRing = hasRing or entry.label == GetString(SI_GRAVVY_BUILD_PLANNER_SLOT_RING1)
end
expect(hasShoulders, "armor transfer picker should include compatible armor slots")
expect(not hasRing, "armor transfer picker should exclude jewelry slots")
ui.slotTargetCombo.selectedValue = "shoulders"
ui:TransferSlot(false)
expect(setup.equipment.head, "copy action should keep its source")
expect(setup.equipment.shoulders, "copy action should fill its destination")
expectEqual(setup.equipment.shoulders.itemLink, nil, "copied UI requirements should resolve for their new slot")

ui:OpenSlotActionDialog()
ui.slotTargetCombo.selectedValue = "hands"
ui:TransferSlot(true)
expectEqual(setup.equipment.shoulders, nil, "move action should clear its source")
expect(setup.equipment.hands, "move action should fill its destination")

itemLinks["owned:head"] = {
    itemId = 3401,
    name = "Helm of Pillar of Nirn",
    setId = 34,
    setName = "Pillar of Nirn",
    equipType = EQUIP_TYPE_HEAD,
    armorType = ARMORTYPE_MEDIUM,
    weaponType = WEAPONTYPE_NONE,
    traitType = ITEM_TRAIT_TYPE_ARMOR_DIVINES,
    quality = ITEM_QUALITY_LEGENDARY,
    level = 50,
    championPoints = 160,
    enchantId = 26588,
}
itemLinks["owned:hands"] = {
    itemId = 3404,
    name = "Gauntlets of Pillar of Nirn",
    setId = 34,
    setName = "Pillar of Nirn",
    equipType = EQUIP_TYPE_HAND,
    armorType = ARMORTYPE_MEDIUM,
    weaponType = WEAPONTYPE_NONE,
    traitType = ITEM_TRAIT_TYPE_NONE,
    quality = ITEM_QUALITY_ARTIFACT,
    level = 50,
    championPoints = 160,
    enchantId = 501,
}
itemLinks["owned:waist"] = {
    itemId = 9905,
    name = "Sash of Whorl of the Depths",
    setId = 99,
    setName = "Whorl of the Depths",
    equipType = EQUIP_TYPE_WAIST,
    armorType = ARMORTYPE_LIGHT,
    weaponType = WEAPONTYPE_NONE,
    traitType = 12,
    quality = ITEM_QUALITY_LEGENDARY,
    level = 50,
    championPoints = 160,
    enchantId = 501,
}
itemLinks["owned:ring"] = {
    itemId = 3402,
    name = "Ring of Pillar of Nirn",
    setId = 34,
    setName = "Pillar of Nirn",
    equipType = EQUIP_TYPE_RING,
    armorType = ARMORTYPE_NONE,
    weaponType = WEAPONTYPE_NONE,
    traitType = ITEM_TRAIT_TYPE_NONE,
    quality = ITEM_QUALITY_LEGENDARY,
    level = 50,
    championPoints = 160,
    enchantId = 502,
}
itemLinks["owned:low-level-head"] = {
    itemId = 3401,
    name = "Helm of Pillar of Nirn",
    setId = 34,
    setName = "Pillar of Nirn",
    equipType = EQUIP_TYPE_HEAD,
    armorType = ARMORTYPE_MEDIUM,
    weaponType = WEAPONTYPE_NONE,
    traitType = ITEM_TRAIT_TYPE_ARMOR_DIVINES,
    quality = ITEM_QUALITY_LEGENDARY,
    level = 40,
    championPoints = 0,
    enchantId = 26588,
}
testBags[BAG_WORN] = { "owned:head" }
testBags[BAG_BACKPACK] = { "owned:hands", "owned:ring" }
testBags[BAG_BANK] = { "owned:waist" }

expectEqual(owner.acquisition:CompareItem(
    "head",
    setup.equipment.head,
    setup,
    "owned:low-level-head"
), nil, "under-level gear should not count as an adjustable match")

local _, currentBuild = BuildPlannerTestData:GetCurrentSetup()
BuildPlannerTestData:SetEquipment(currentBuild.id, setup.id, "ring2", {
    setName = "Pillar of Nirn",
})
owner.inventory:Refresh()
local headMatch = owner.inventory:GetMatch(setup.id, "head")
expect(headMatch and headMatch.exact, "equipped exact pieces should satisfy a planned slot")
expectEqual(headMatch.location, "equipped", "equipped matches should retain their location")
local handMatch = owner.inventory:GetMatch(setup.id, "hands")
expect(handMatch and not handMatch.exact, "repairable pieces should be kept as adjustable matches")
expectEqual(#handMatch.differences, 3, "adjustable match should report trait, enchantment, and quality")
local waistMatch = owner.inventory:GetMatch(setup.id, "waist")
expect(waistMatch and waistMatch.exact, "manual set names should match banked pieces")
expectEqual(waistMatch.location, "bank", "bank matches should retain their location")
local ringMatches = (owner.inventory:GetMatch(setup.id, "ring1") and 1 or 0)
    + (owner.inventory:GetMatch(setup.id, "ring2") and 1 or 0)
expectEqual(ringMatches, 1, "one owned ring should not satisfy two planned slots")

ui:EditSlot("hands")
expect(ui.acquisitionLabel.text:find(
    GetString(SI_GRAVVY_BUILD_PLANNER_NEEDS_QUALITY),
    1,
    true
), "editor should show work needed by an owned piece")
ui.setEdit:SetText("Unowned Test Set")
ui:OnSetTextChanged()
expect(ui.acquisitionLabel.text:find(
    GetString(SI_GRAVVY_BUILD_PLANNER_OWNED_BACKPACK),
    1,
    true
) == nil, "unsaved edits should not show ownership for the previously saved requirement")

ui:EditSlot("head")
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
EVENT_INVENTORY_SINGLE_SLOT_UPDATE = 2
EVENT_INVENTORY_FULL_UPDATE = 3
EVENT_OPEN_BANK = 4
EVENT_PLAYER_ACTIVATED = 5
EVENT_ITEM_SET_COLLECTION_UPDATED = 6
function zo_callLater(callback) callback() end
EVENT_MANAGER = {
    RegisterForEvent = function(self, _, _, callback) self.addOnLoaded = callback end,
    UnregisterForEvent = function() end,
}
dofile("GravvyBuildPlanner.lua")
EVENT_MANAGER.addOnLoaded(nil, "GravvyBuildPlanner")
expect(SLASH_COMMANDS["/buildplanner"], "long slash command should be registered")
expect(SLASH_COMMANDS["/gbp"], "short slash command should be registered")

print("Build Planner UI tests passed")
