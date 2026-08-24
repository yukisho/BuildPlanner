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
ITEMTYPE_FOOD = 20
ITEMTYPE_DRINK = 21
ITEMTYPE_POTION = 22
ITEMTYPE_POISON = 23
ITEM_TRAIT_TYPE_ARMOR_DIVINES = 21
ITEM_TRAIT_TYPE_WEAPON_PRECISE = 22
ITEM_TRAIT_TYPE_JEWELRY_ARCANE = 23
LINK_STYLE_DEFAULT = 0
BAG_WORN = 1
BAG_BACKPACK = 2
BAG_BANK = 3
BAG_SUBSCRIBER_BANK = 4
CHAMPION_DISCIPLINE_TYPE_WORLD = 1
CHAMPION_DISCIPLINE_TYPE_COMBAT = 2
CHAMPION_DISCIPLINE_TYPE_CONDITIONING = 3
HOTBAR_CATEGORY_PRIMARY = 1
HOTBAR_CATEGORY_BACKUP = 2
HOTBAR_CATEGORY_CHAMPION = 3
ACTION_TYPE_NOTHING = 0
ACTION_TYPE_ABILITY = 1
ACTION_TYPE_CHAMPION_SKILL = 2
ACTION_TYPE_CRAFTED_ABILITY = 3
ATTRIBUTE_HEALTH = 1
ATTRIBUTE_MAGICKA = 2
ATTRIBUTE_STAMINA = 3
CURSE_TYPE_NONE = 0
CURSE_TYPE_VAMPIRE = 1
CURSE_TYPE_WEREWOLF = 2
MUNDUS_STONE_INVALID = 0

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

function GetAbilityIcon(abilityId)
    return "champion-" .. tostring(abilityId) .. ".dds"
end

local championPoints = { [3001] = 10, [3002] = 50, [3003] = 20, [3004] = 30 }
local function championSkill(skillId, abilityId, name, maxPoints, slottable)
    return {
        GetId = function() return skillId end,
        GetAbilityId = function() return abilityId end,
        GetRawName = function() return name end,
        GetMaxPossiblePoints = function() return maxPoints end,
        IsTypeSlottable = function() return slottable end,
        GetNumSavedPoints = function() return championPoints[skillId] or 0 end,
        GetNextJumpPoint = function(_, points) return math.min(maxPoints, points + 1) end,
    }
end

local championDisciplines = {
    {
        GetType = function() return CHAMPION_DISCIPLINE_TYPE_WORLD end,
        ChampionSkillDataIterator = function()
            return ipairs({ championSkill(3001, 4001, "Homemaker", 50, true) })
        end,
    },
    {
        GetType = function() return CHAMPION_DISCIPLINE_TYPE_COMBAT end,
        ChampionSkillDataIterator = function()
            return ipairs({
                championSkill(3002, 4002, "Fighting Finesse", 50, true),
                championSkill(3003, 4003, "Precision", 20, false),
            })
        end,
    },
    {
        GetType = function() return CHAMPION_DISCIPLINE_TYPE_CONDITIONING end,
        ChampionSkillDataIterator = function()
            return ipairs({ championSkill(3004, 4004, "Boundless Vitality", 50, true) })
        end,
    },
}
CHAMPION_DATA_MANAGER = {
    ChampionDisciplineDataIterator = function()
        return ipairs(championDisciplines)
    end,
}

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
EVENT_GAME_FOCUS_CHANGED = 7
EVENT_GAMEPAD_PREFERRED_MODE_CHANGED = 8

SI_GAMEPAD_SELECT_OPTION = "SI_GAMEPAD_SELECT_OPTION"
SI_GAMEPAD_BACK_OPTION = "SI_GAMEPAD_BACK_OPTION"
SI_DIALOG_CANCEL = "SI_DIALOG_CANCEL"
SI_DIALOG_CONFIRM = "SI_DIALOG_CONFIRM"
SI_DIALOG_CLOSE = "SI_DIALOG_CLOSE"
GAMEPAD_DIALOGS = { BASIC = 1, PARAMETRIC = 2 }
GAMEPAD_LEFT_TOOLTIP = 1
KEYBIND_STRIP_ALIGN_LEFT = 1
UI_ALERT_CATEGORY_ERROR = 1
ZO_COMBOBOX_SUPPRESS_UPDATE = true
SOUNDS = {
    GAMEPAD_OPEN_WINDOW = "open",
    GAMEPAD_CLOSE_WINDOW = "close",
    GAMEPAD_PAGE_BACK = "back",
    GAMEPAD_PAGE_FORWARD = "forward",
    NEGATIVE_CLICK = "negative",
}

local cameraUIMode = false
function IsGameCameraUIModeActive() return cameraUIMode end
function SetGameCameraUIMode(active) cameraUIMode = active end
function zo_callLater(callback) callback() end
EVENT_MANAGER = {
    callbacks = {},
    RegisterForEvent = function(self, name, eventId, callback)
        self.callbacks[eventId] = callback
    end,
}

local testFont = {
    GetFontInfo = function() return "test-font", 18, "soft-shadow-thin" end,
}
ZoFontGame = testFont
ZoFontGameSmall = testFont
ZoFontWinH2 = testFont
ZoFontWinH3 = testFont

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
    function control:GetNamedChild(childName)
        self.children = self.children or {}
        if not self.children[childName] then
            self.children[childName] = newControl(self.name .. childName, self)
        end
        return self.children[childName]
    end
    function control:SetDimensions(width, height) self.width, self.height = width, height end
    function control:SetHeight(height) self.height = height end
    function control:SetAnchor() end
    function control:ClearAnchors() end
    function control:SetAnchorFill() end
    function control:SetClampedToScreen() end
    function control:SetMouseEnabled() end
    function control:SetMovable() end
    function control:SetDrawTier() end
    function control:SetCenterColor(...) self.centerColor = { ... } end
    function control:SetEdgeColor(...) self.edgeColor = { ... } end
    function control:SetFont(value) self.font = value end
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

local gamepadPreferred = false
function IsInGamepadPreferredMode() return gamepadPreferred end
function PlaySound(sound) lastSound = sound end
function ZO_Alert(_, _, message) lastAlert = message end
function ZO_GetDefaultParametricListEditBoxNarrationText() return "" end
function ZO_SharedGamepadEntry_OnSetup() end
function ZO_GamepadMenuEntryTemplateParametricListFunction() end

SCREEN_NARRATION_MANAGER = {
    RegisterDialogDropdown = function() end,
}

ZO_GamepadEntryData = {}
function ZO_GamepadEntryData:New(name)
    local entry = { name = name, subLabels = {} }
    function entry:AddSubLabel(value) self.subLabels[#self.subLabels + 1] = value end
    function entry:SetFontScaleOnSelection() end
    function entry:SetShowUnselectedSublabels() end
    return entry
end

ZO_GamepadVerticalItemParametricScrollList = {}
function ZO_GamepadVerticalItemParametricScrollList:New()
    local list = { entries = {}, selectedIndex = 1 }
    function list:AddDataTemplate() end
    function list:SetNoItemText(value) self.noItemText = value end
    function list:SetOnTargetDataChangedCallback(callback) self.targetChanged = callback end
    function list:Clear() self.entries = {} end
    function list:AddEntry(_, entry) self.entries[#self.entries + 1] = entry end
    function list:Commit()
        self.selectedIndex = zo_clamp(self.selectedIndex, 1, math.max(1, #self.entries))
        if self.targetChanged then self.targetChanged() end
    end
    function list:GetTargetData() return self.entries[self.selectedIndex] end
    function list:SetSelectedIndex(index)
        self.selectedIndex = index
        if self.targetChanged then self.targetChanged() end
    end
    function list:Activate() self.active = true end
    function list:Deactivate() self.active = false end
    return list
end

KEYBIND_STRIP = {
    PushKeybindGroupState = function() return {} end,
    RemoveDefaultExit = function() end,
    AddKeybindButtonGroup = function() end,
    RemoveKeybindButtonGroup = function() end,
    RestoreDefaultExit = function() end,
    PopKeybindGroupState = function() end,
    UpdateKeybindButtonGroup = function() end,
    GenerateGamepadBackButtonDescriptor = function(_, callback)
        return { keybind = "UI_SHORTCUT_NEGATIVE", callback = callback }
    end,
}

GAMEPAD_TOOLTIPS = {
    LayoutItemLink = function(self, _, link) self.link = link end,
    LayoutSimpleAbility = function(self, _, abilityId) self.abilityId = abilityId end,
    LayoutChampionSkill = function(self, _, skillData) self.championSkillId = skillData:GetId() end,
    ClearTooltip = function(self) self.link = nil end,
}

local gamepadDialogs = {}
local shownGamepadDialog
function ZO_Dialogs_RegisterCustomDialog(name, definition)
    gamepadDialogs[name] = definition
end
function ZO_Dialogs_ShowGamepadDialog(name)
    shownGamepadDialog = name
end
function ZO_Dialogs_ReleaseDialogOnButtonPress() end

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

function LibSets.GetSetArmorTypes(setId)
    if setId == 101 then
        return {
            [ARMORTYPE_LIGHT] = true,
            [ARMORTYPE_MEDIUM] = true,
            [ARMORTYPE_HEAVY] = true,
        }
    end
    return {}
end
function LibSets.GetSetItemId(setId, _, equipType, traitType, _, armorType)
    if setId ~= 101 or equipType ~= EQUIP_TYPE_HEAD or armorType ~= ARMORTYPE_LIGHT then
        return nil
    end
    itemLinks["item:10101"] = {
        itemId = 10101,
        name = "Highland Sentinel Hat",
        equipType = EQUIP_TYPE_HEAD,
        armorType = ARMORTYPE_LIGHT,
        weaponType = WEAPONTYPE_NONE,
        enchantId = 501,
        setId = 101,
        setName = "Highland Sentinel",
        traitType = traitType,
        quality = ITEM_QUALITY_NORMAL,
        level = 50,
        championPoints = 160,
    }
    return 10101
end
function LibSets.buildItemLink(itemId)
    return "item:" .. tostring(itemId)
end

function GetNumItemSetCollectionPieces(setId)
    return ({ [12] = true, [34] = true, [56] = true, [78] = true,
        [90] = true, [91] = true, [92] = true, [93] = true })[setId] and 3 or 0
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
    item.setName = ({
        [12] = "Overland Test Set",
        [34] = "Pillar of Nirn",
        [56] = "Monster Test Set",
        [78] = "Crafted Test Set",
        [90] = "Trial Test Set",
        [91] = "Mythic Test Set",
        [92] = "Arena Test Set",
        [93] = "Perfected Arena Test Set",
    })[setId]
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
function GetItemLinkItemType(link) return itemLinks[link].itemType end
function GetItemLinkName(link)
    if itemLinks[link] then
        return itemLinks[link].name
    end
    local fields = getLinkFields(link)
    if fields and tonumber(fields[1]) == 26588 then
        return "Truly Superb Glyph of Stamina"
    end
    return ""
end
function GetItemLinkIcon(link) return "icon:" .. link end
local abilities = {
    [1001] = { name = "Deep Fissure", icon = "deep-fissure.dds" },
    [1002] = { name = "Subterranean Assault", icon = "subterranean-assault.dds" },
    [1005] = { name = "Wield Soul", icon = "wield-soul.dds" },
    [1006] = { name = "Wild Guardian", icon = "wild-guardian.dds" },
    [5001] = { name = "Advanced Species", icon = "advanced-species.dds" },
    [5002] = { name = "Advanced Species", icon = "advanced-species.dds" },
}
function GetAbilityName(abilityId) return abilities[abilityId] and abilities[abilityId].name or "" end
function GetAbilityIcon(abilityId) return abilities[abilityId] and abilities[abilityId].icon or "" end
function GetUnitSilhouetteTexture() return "player-silhouette" end
function GetRawUnitName() return "Test Warden" end
function GetUnitClassId() return 5 end
function GetUnitRaceId() return 9 end
function GetAttributeSpentPoints(attribute)
    return ({ [ATTRIBUTE_HEALTH] = 4, [ATTRIBUTE_MAGICKA] = 10,
        [ATTRIBUTE_STAMINA] = 50 })[attribute] or 0
end
function GetPlayerCurseType() return CURSE_TYPE_VAMPIRE end
function GetUnitActiveMundusStoneBuffIndices() return 1 end
function GetUnitBuffInfo()
    return "The Thief", 0, 0, 0, 0, "", "", 0, 0, 0, 9001, false, false
end
function GetAbilityMundusStoneType(abilityId)
    return abilityId == 9001 and 10 or MUNDUS_STONE_INVALID
end
function GetMaxLevel() return 50 end
function GetChampionPointsPlayerProgressionCap() return 160 end

local classSkillLines = {}
for _, name in ipairs({ "Animal Companions", "Winter's Embrace", "Grave Lord" }) do
    classSkillLines[#classSkillLines + 1] = {
        IsClassSkillLine = function() return true end,
        IsActive = function() return true end,
        IsClassMastery = function() return false end,
        GetName = function() return name end,
        SkillIterator = function() return ipairs({}) end,
    }
end
SKILLS_DATA_MANAGER = {
    SkillTypeIterator = function()
        return ipairs({ {
            SkillLineIterator = function() return ipairs(classSkillLines) end,
        } })
    end,
}

local actionBarAbilities = {
    [HOTBAR_CATEGORY_PRIMARY] = { [3] = 1001, [4] = 7001, [8] = 1006 },
    [HOTBAR_CATEGORY_BACKUP] = { [3] = 1002 },
}
local championBar = { [20] = 3001, [24] = 3002, [28] = 3004 }
function GetAssignableAbilityBarStartAndEndSlots() return 3, 8 end
function GetAssignableChampionBarStartAndEndSlots() return 20, 31 end
function GetRequiredChampionDisciplineIdForSlot(slotIndex)
    if slotIndex < 24 then return 1 end
    if slotIndex < 28 then return 2 end
    return 3
end
function GetChampionDisciplineType(disciplineId)
    return ({ [1] = CHAMPION_DISCIPLINE_TYPE_WORLD,
        [2] = CHAMPION_DISCIPLINE_TYPE_COMBAT,
        [3] = CHAMPION_DISCIPLINE_TYPE_CONDITIONING })[disciplineId]
end
function GetSlotBoundId(slotIndex, hotbarCategory)
    if hotbarCategory == HOTBAR_CATEGORY_CHAMPION then
        return championBar[slotIndex] or 0
    end
    return actionBarAbilities[hotbarCategory]
        and actionBarAbilities[hotbarCategory][slotIndex]
        or 0
end
function GetSlotType(slotIndex, hotbarCategory)
    if hotbarCategory == HOTBAR_CATEGORY_CHAMPION then
        return championBar[slotIndex] and ACTION_TYPE_CHAMPION_SKILL
            or ACTION_TYPE_NOTHING
    end
    if hotbarCategory == HOTBAR_CATEGORY_PRIMARY and slotIndex == 4 then
        return ACTION_TYPE_CRAFTED_ABILITY
    end
    return GetSlotBoundId(slotIndex, hotbarCategory) > 0
        and ACTION_TYPE_ABILITY
        or ACTION_TYPE_NOTHING
end
function GetCraftedAbilityRepresentativeAbilityId(craftedAbilityId)
    return craftedAbilityId == 7001 and 1005 or 0
end
function ZO_Character_GetEmptyEquipSlotTexture(equipSlot)
    return "empty-slot:" .. tostring(equipSlot)
end
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
    if item and (item.setId == 101
        or (item.itemId >= 1200 and item.itemId < 1300)
        or (item.itemId >= 7800 and item.itemId < 7900)) then
        return BIND_TYPE_ON_EQUIP
    end
    return BIND_TYPE_ON_PICKUP
end
function GetItemSetType(setId)
    if setId == 12 then
        return ITEM_SET_TYPE_WORLD
    elseif setId == 78 then
        return ITEM_SET_TYPE_CRAFTED
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

itemLinks["capture:head"] = {
    itemId = 1201,
    name = "Highland Sentinel Hat",
    equipType = EQUIP_TYPE_HEAD,
    armorType = ARMORTYPE_LIGHT,
    weaponType = WEAPONTYPE_NONE,
    enchantId = 501,
    setId = 12,
    setName = "Overland Test Set",
    traitType = ITEM_TRAIT_TYPE_ARMOR_DIVINES,
    quality = ITEM_QUALITY_ARTIFACT,
    level = 50,
    championPoints = 160,
}
itemLinks["capture:twohand"] = {
    itemId = 9201,
    name = "Arena Greatsword",
    equipType = EQUIP_TYPE_TWO_HAND,
    armorType = ARMORTYPE_NONE,
    weaponType = WEAPONTYPE_TWO_HANDED_SWORD,
    enchantId = 503,
    setId = 92,
    setName = "Arena Test Set",
    traitType = ITEM_TRAIT_TYPE_WEAPON_PRECISE,
    quality = ITEM_QUALITY_ARTIFACT,
    level = 50,
    championPoints = 160,
}

local equippedBySlot = {
    [EQUIP_SLOT_HEAD] = "capture:head",
    [EQUIP_SLOT_MAIN_HAND] = "capture:twohand",
}
local testBags = {}
function GetBagSize(bagId)
    return #(testBags[bagId] or {})
end
function GetItemLink(bagId, slotIndex)
    if bagId == BAG_WORN and equippedBySlot[slotIndex] then
        return equippedBySlot[slotIndex]
    end
    local bag = testBags[bagId] or {}
    return bag[slotIndex + 1] or ""
end
function GetSlotStackSize(bagId, slotIndex)
    return GetItemLink(bagId, slotIndex) ~= "" and 1 or 0
end

ItemTooltip = newControl("ItemTooltip")
SkillTooltip = newControl("SkillTooltip")
ChampionSkillTooltip = newControl("ChampionSkillTooltip")
function ItemTooltip:SetLink(link) self.link = link end
function ItemTooltip:AddLine(text) self.extraLine = text end
function SkillTooltip:LayoutSimpleAbility(abilityId) self.abilityId = abilityId end
function ChampionSkillTooltip:SetChampionSkill(skillId, points, nextPoint, slotted)
    self.skillId = skillId
    self.points = points
    self.nextPoint = nextPoint
    self.slotted = slotted
end
function InitializeTooltip() end
function ClearTooltip(tooltip) tooltip.link = nil end

dofile("Enchantments.lua")
dofile("ItemResolver.lua")
dofile("Acquisition.lua")
dofile("Inventory.lua")
dofile("ShoppingIntegration.lua")
dofile("CharacterCapture.lua")
dofile("SkillCatalog.lua")
dofile("ChampionCatalog.lua")
dofile("ConsumableCatalog.lua")
dofile("Share.lua")
dofile("Accessibility.lua")
dofile("Comparison.lua")
dofile("UI.lua")
dofile("ChampionPlanner.lua")
dofile("SuppliesPlanner.lua")
dofile("ChecklistPlanner.lua")
dofile("ComparisonPlanner.lua")
dofile("Settings.lua")
dofile("Gamepad.lua")
dofile("GamepadDialogs.lua")

local owner = {
    data = BuildPlannerTestData,
    setCatalog = BuildPlannerTestCatalog,
    itemResolver = GravvyBuildPlannerItemResolver:New(),
}
owner.acquisition = GravvyBuildPlannerAcquisition:New(owner.itemResolver)
owner.inventory = GravvyBuildPlannerInventory:New(owner)
owner.shopping = GravvyBuildPlannerShoppingIntegration:New(owner)
owner.capture = GravvyBuildPlannerCharacterCapture:New(owner)
owner.skillCatalog = GravvyBuildPlannerSkillCatalog:New()
owner.skillCatalog:AddAbility(1001, false)
owner.skillCatalog:AddAbility(1002, false)
owner.skillCatalog:AddAbility(1006, true)
local nativePassiveTooltipUsed = false
owner.skillCatalog:AddPassive("Advanced Species", "Animal Companions", 2, {
    [1] = {
        abilityId = 5001,
        icon = "advanced-species.dds",
        progression = {
            SetKeyboardTooltip = function(_, tooltip, showCost)
                nativePassiveTooltipUsed = tooltip == SkillTooltip and showCost == false
                tooltip.abilityId = 5001
            end,
        },
    },
    [2] = {
        abilityId = 5002,
        icon = "advanced-species.dds",
        progression = {
            SetKeyboardTooltip = function(_, tooltip, showCost)
                nativePassiveTooltipUsed = tooltip == SkillTooltip and showCost == false
                tooltip.abilityId = 5002
            end,
        },
    },
})
owner.championCatalog = GravvyBuildPlannerChampionCatalog:New()
owner.championCatalog:Refresh()
owner.consumableCatalog = GravvyBuildPlannerConsumableCatalog:New(owner.data)
owner.consumableCatalog:Refresh()
local nativeSkillTooltipUsed = false
owner.skillCatalog:FindById(1001).progression = {
    SetKeyboardTooltip = function(_, tooltip, showCost, showUpgrade, showAdvised, showBadMorph)
        nativeSkillTooltipUsed = tooltip == SkillTooltip
            and showCost == false
            and showUpgrade == false
            and showAdvised == false
            and showBadMorph == false
        tooltip.abilityId = 1001
    end,
}
owner.accessibility = GravvyBuildPlannerAccessibility
owner.accessibility:Initialize(owner)
local ui = GravvyBuildPlannerUI:New(owner)
ui:Initialize()
owner.ui = ui
expect(ui.captureButton, "keyboard users should have a character capture action")
local originalBuild = BuildPlannerTestData:GetCurrentBuild()
local buildCount = #BuildPlannerTestData:GetBuilds()
ui.captureButton.handlers.OnClicked()
local capturedSetup, capturedBuild = BuildPlannerTestData:GetCurrentSetup()
expectEqual(#BuildPlannerTestData:GetBuilds(), buildCount + 1,
    "capture should create one separate build")
expectEqual(capturedBuild.classId, 5, "capture should retain the live class")
expectEqual(capturedSetup.equipment.head.itemId, 1201,
    "capture should retain exact equipped item identity")
expect(capturedSetup.equipment.frontMain.occupiesOffHand,
    "captured two-handed weapons should occupy their off-hand")
expectEqual(capturedSetup.skillBars.front[1].abilityId, 1001,
    "capture should retain front-bar abilities")
expectEqual(capturedSetup.skillBars.front[2].abilityId, 1005,
    "capture should resolve crafted abilities to their representative ability")
expectEqual(capturedSetup.skillBars.front[6].abilityId, 1006,
    "capture should retain the front-bar ultimate")
expectEqual(capturedSetup.skillBars.back[1].abilityId, 1002,
    "capture should retain back-bar abilities")
expectEqual(capturedSetup.character.attributes.stamina, 50,
    "capture should retain assigned attribute points")
expectEqual(capturedSetup.character.mundus, 10,
    "capture should retain the active Mundus Stone")
expectEqual(capturedSetup.character.subclassLines[3], "Grave Lord",
    "capture should retain active class skill lines")
expectEqual(capturedSetup.champion.warfare.allocations[1].points, 50,
    "capture should retain saved Champion allocations")
expectEqual(capturedSetup.champion.warfare.slottables[1], 3002,
    "capture should retain ordered Champion slottables")
expect(ui.status:GetText():find("2 gear pieces", 1, true),
    "capture should report the captured equipment count")
BuildPlannerTestData:SelectBuild(originalBuild.id)
ui:Refresh()
expect(ui.paperDoll, "keyboard equipment should use a paper-doll panel")
expectEqual(ui.paperDollSilhouette.texture, "player-silhouette", "paper doll should use ESO's player silhouette")
expectEqual(#GravvyBuildPlannerSlots.ORDER, 14, "paper doll should retain all equipment slots")
for _, slotKey in ipairs(GravvyBuildPlannerSlots.ORDER) do
    expect(ui.rows[slotKey] and ui.rows[slotKey].icon, slotKey .. " should have an icon control")
end
ui:SetView("skills")
expect(not ui.skillPanel:IsHidden(), "keyboard users should be able to open the skill-bar planner")
expectEqual(
    ui.skillButtons.front[2].icon.texture,
    "EsoUI/Art/ActionBar/abilityInset.dds",
    "empty skill slots should use ESO's native ability background"
)
ui.selectedSkillSlot = 2
ui:LoadSkillEditor()
expectEqual(
    ui.skillPreview.texture,
    "EsoUI/Art/ActionBar/abilityInset.dds",
    "an unplanned skill preview should use the native ability background"
)
ui.selectedSkillSlot = 1
ui:LoadSkillEditor()
ui.skillEdit:SetText("Deep")
ui:OnSkillTextChanged()
expectEqual(#ui.skillSuggestionData, 1, "skill names should autocomplete from active abilities")
ui:ChooseSkillSuggestion(1)
ui:SaveSkill()
expectEqual(
    BuildPlannerTestData:GetCurrentSetup().skillBars.front[1].abilityId,
    1001,
    "keyboard skill choices should persist on the front bar"
)
ui:ShowSkillTooltip(ui.skillButtons.front[1], "front", 1)
expectEqual(SkillTooltip.abilityId, 1001, "planned skills should use ESO's native ability tooltip")
expect(nativeSkillTooltipUsed, "keyboard skills should use their native progression tooltip")
ui.selectedSkillSlot = 6
ui:LoadSkillEditor()
ui.skillEdit:SetText("Wild")
ui:OnSkillTextChanged()
ui:ChooseSkillSuggestion(1)
ui:SaveSkill()
expectEqual(
    BuildPlannerTestData:GetCurrentSetup().skillBars.front[6].abilityId,
    1006,
    "ultimate choices should persist in the sixth bar slot"
)
ui:SetView("character")
expect(not ui.characterPanel:IsHidden(), "keyboard users should be able to open the character planner")
ui.attributeEdits.health:SetText("4")
ui.attributeEdits.magicka:SetText("10")
ui.attributeEdits.stamina:SetText("50")
ui.raceCombo.selectedValue = 9
ui.mundusCombo.selectedValue = 10
ui.curseCombo.selectedValue = 1
ui.subclassEdits[1]:SetText("Animal Companions")
ui.subclassEdits[2]:SetText("Winter's Embrace")
ui.subclassEdits[3]:SetText("Grave Lord")
ui:SaveCharacter()
expectEqual(
    BuildPlannerTestData:GetCurrentSetup().character.attributes.stamina,
    50,
    "keyboard character planning should persist attributes"
)
expectEqual(
    BuildPlannerTestData:GetCurrentSetup().character.subclassLines[3],
    "Grave Lord",
    "keyboard character planning should persist subclass lines"
)
ui:SetView("champion")
expect(not ui.championPanel:IsHidden(), "keyboard users should be able to open the Champion planner")
ui:SetChampionDiscipline("warfare")
ui.championStarEdit:SetText("Fighting")
ui:OnChampionTextChanged()
expectEqual(#ui.championSuggestionData, 1, "Champion Stars should autocomplete by discipline")
ui:ChooseChampionSuggestion(1)
ui.championPointsEdit:SetText("50")
ui.championSlotCombo.selectedValue = 1
ui:SaveChampionAllocation()
local keyboardChampion = BuildPlannerTestData:GetCurrentSetup().champion.warfare
expectEqual(keyboardChampion.slottables[1], 3002,
    "keyboard Champion planning should preserve slottable positions")
ui:ShowChampionTooltip(ui.championSlotButtons[1], 3002)
expectEqual(ChampionSkillTooltip.skillId, 3002,
    "planned Champion Stars should use ESO's native Champion tooltip")
ui:SetView("supplies")
expect(not ui.suppliesPanel:IsHidden(), "keyboard users should be able to open the Supplies planner")
expect(owner.consumableCatalog:FindExact(
    "Braised Rabbit with Spring Vegetables",
    "food"
), "saved consumables should remain available to autocomplete")
ui:SelectSupplyRow(1)
ui.supplyQuantityEdit:SetText("25")
ui:SaveSupply()
expectEqual(BuildPlannerTestData:GetCurrentSetup().consumables[1].quantity, 25,
    "keyboard consumable planning should persist quantities")
ui:ShowSupplyTooltip(ui.supplyRows[1], "food:item")
expectEqual(ItemTooltip.link, "food:item", "resolved consumables should use native item tooltips")
ui:SetView("checklist")
expect(not ui.checklistPanel:IsHidden(), "keyboard users should be able to open the progression checklist")
expectEqual(#owner.skillCatalog:SearchPassives("Advanced", 6), 1,
    "passive skills should autocomplete from ESO skill data")
ui:SelectChecklistRow(1)
ui:ShowChecklistTooltip(ui.checklistRows[1], 5002, 2)
expectEqual(SkillTooltip.abilityId, 5002, "passive steps should use their rank-specific tooltip")
expect(nativePassiveTooltipUsed, "passive steps should use ESO's native passive tooltip")
ui:ToggleChecklistCompleted()
expect(not BuildPlannerTestData:GetCurrentSetup().checklist[1].completed,
    "checklist completion should toggle from the planner")
ui:ToggleChecklistCompleted()
ui.selectedChecklistIndex = nil
ui:LoadChecklistEditor()
ui.checklistCategoryCombo.selectedValue = "unlock"
ui.checklistNameEdit:SetText("Undaunted Rank 9")
ui.checklistRankEdit:SetText("9")
ui.checklistNoteEdit:SetText("Unlock Undaunted Mettle")
ui:SaveChecklistEntry()
expectEqual(#BuildPlannerTestData:GetCurrentSetup().checklist, 2,
    "keyboard progression steps should persist")
ui:SetView("comparison")
expect(not ui.comparisonPanel:IsHidden(), "keyboard users should be able to compare setups")
expect(ui.comparisonSetupId, "comparison should select another setup automatically")
expect(#ui.comparisonDifferences > 0, "comparison should include only changed setup fields")
expect(not ui.comparisonRows[1]:IsHidden(), "changed fields should be visible in the comparison table")
expectEqual(#GravvyBuildPlannerComparison:Build(
    BuildPlannerTestData:GetCurrentSetup(),
    BuildPlannerTestData:GetCurrentSetup()
), 0, "comparison should omit every unchanged field")
ui:SetView("gear")
expect(not ui.paperDoll:IsHidden(), "switching back to Gear should restore the paper doll")
owner.share = GravvyBuildPlannerShare:New(owner)
owner.share:Initialize()
expect(owner.share.window:IsHidden(), "the build share window should start hidden")
owner.share:Open()
expect(owner.share.codeEdit:GetText():sub(1, 5) == "GBP1:", "the share window should generate the current build code")
owner.share:Hide()
GravvyBuildPlannerGamepadWindow = newControl("GravvyBuildPlannerGamepadWindow")
GravvyBuildPlannerGamepadWindow:SetHidden(true)
local gamepad = GravvyBuildPlannerGamepad:New(owner)
owner.gamepad = gamepad
gamepad:Initialize()
expectEqual(
    gamepadDialogs["GRAVVY_BUILD_PLANNER_GAMEPAD_MANAGE"].parametricList[2].text,
    SI_GRAVVY_BUILD_PLANNER_CAPTURE,
    "gamepad build management should expose character capture"
)

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
local craftedRoutes = owner.acquisition:GetAvailableRoutes(craftedState)
expectEqual(craftedRoutes[1], "craft", "crafted gear should prefer crafting automatically")
expectEqual(craftedRoutes[2], "buy", "tradeable crafted gear should also offer buying")
expectEqual(
    owner.acquisition:ChooseRoute(craftedRoutes, "buy"),
    "buy",
    "a compatible preferred route should override the automatic route"
)
local unknownState = owner.acquisition:Classify("head", {}, resolverSetup)
expect(unknownState.unknown, "unresolved requirements should remain unknown")
local monsterArmorTypes = owner.itemResolver:GetAvailableArmorTypes("head", 56)
expectEqual(#monsterArmorTypes, 3, "monster sets should retain every available armor weight")
local craftedArmorTypes = owner.itemResolver:GetAvailableArmorTypes("head", 101)
expectEqual(#craftedArmorTypes, 3, "LibSets crafted sets should expose every armor weight")
local craftedPreview = owner.itemResolver:Resolve("head", {
    setId = 101,
    armorType = ARMORTYPE_LIGHT,
}, resolverSetup)
expect(craftedPreview and craftedPreview.itemId == 10101, "LibSets crafted gear should produce a preview")
expectEqual(craftedPreview.pieceId, nil, "LibSets previews should not invent collection pieces")
local libSetsCraftedState = owner.acquisition:Classify("head", {
    setId = 101,
    armorType = ARMORTYPE_LIGHT,
}, resolverSetup, craftedPreview)
expect(libSetsCraftedState.crafted, "LibSets crafted metadata should drive acquisition")
expect(libSetsCraftedState.tradeable, "unbound LibSets crafted gear should be buyable")
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

local representativeGear = {
    { name = "overland", setId = 12, slotKey = "head", armorType = ARMORTYPE_LIGHT },
    { name = "dungeon", setId = 34, slotKey = "head", armorType = ARMORTYPE_MEDIUM },
    { name = "crafted", setId = 78, slotKey = "head", armorType = ARMORTYPE_LIGHT },
    { name = "monster", setId = 56, slotKey = "head", armorType = ARMORTYPE_LIGHT },
    { name = "trial", setId = 90, slotKey = "head", armorType = ARMORTYPE_LIGHT },
    { name = "mythic", setId = 91, slotKey = "ring1" },
    { name = "arena", setId = 92, slotKey = "frontMain", weaponType = WEAPONTYPE_TWO_HANDED_SWORD },
    { name = "perfected", setId = 93, slotKey = "frontMain", weaponType = WEAPONTYPE_TWO_HANDED_SWORD },
}
for _, sample in ipairs(representativeGear) do
    local requirement = {
        setId = sample.setId,
        armorType = sample.armorType,
        weaponType = sample.weaponType,
    }
    local resolved = owner.itemResolver:Resolve(sample.slotKey, requirement, resolverSetup)
    expect(resolved and resolved.itemLink, sample.name .. " gear should produce a representative link")
    ui:ShowItemTooltip(ui.rows[sample.slotKey], resolved.itemLink, requirement)
    expectEqual(ItemTooltip.link, resolved.itemLink, sample.name .. " gear should use ESO's item tooltip")
end

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
ui:ShowHelp()
expect(not ui.helpDialog:IsHidden(), "in-game help should be available from the planner")
expect(cameraUIMode, "standalone help should request ESO UI mode")
ui:CloseHelp()
expect(not cameraUIMode, "closing standalone help should release its UI mode")
BuildPlannerTestData:GetSettings().fontScale = 1.2
owner.accessibility:Refresh()
expect(ui.status.font:find("test%-font|22"), "font scaling should reapply registered control fonts")
BuildPlannerTestData:GetSettings().highContrast = true
owner.accessibility:Refresh()
local highContrastBackdrops = 0
for backdrop in pairs(owner.accessibility.backdrops) do
    if backdrop.centerColor and backdrop.centerColor[1] == 0
        and backdrop.edgeColor and backdrop.edgeColor[1] == 1 then
        highContrastBackdrops = highContrastBackdrops + 1
    end
end
expect(highContrastBackdrops > 0, "high contrast should update registered backdrops")
BuildPlannerTestData:GetSettings().nonColorIndicators = true
ui:SetStatus("Test failure", true)
expect(ui.status.text:find(GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_PREFIX):gsub("<<1>>", ""), 1, true), "errors should support a non-color text prefix")
BuildPlannerTestData:GetSettings().fontScale = 1
BuildPlannerTestData:GetSettings().highContrast = false
BuildPlannerTestData:GetSettings().nonColorIndicators = false
owner.accessibility:Refresh()
ui:Toggle()
expect(not ui.window:IsHidden(), "toggle should show planner")
expect(cameraUIMode, "opening the planner should make the mouse cursor available")
cameraUIMode = false
EVENT_MANAGER.callbacks[EVENT_GAME_FOCUS_CHANGED](nil, true)
expect(cameraUIMode, "the planner should restore its cursor after ESO regains focus")
ui:Hide()
expect(not cameraUIMode, "closing the planner should release the UI mode it requested")
cameraUIMode = true
ui:Show()
ui:Hide()
expect(cameraUIMode, "the planner should not release UI mode opened by another window")
cameraUIMode = false
ui:Show()

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
for _, entry in ipairs(ui.alternativeCombo.items) do
    if entry.label == GetString(SI_GRAVVY_BUILD_PLANNER_NEW_ALTERNATIVE) then
        entry.callback()
        break
    end
end
expectEqual(ui.editorAlternativeIndex, 1, "keyboard users should be able to start a slot alternative")
ui.setEdit:SetText("Order's Wrath")
ui:ResolveTypedSet()
ui:SaveSlot()
expectEqual(
    setup.alternatives.head[1].setId,
    12,
    "keyboard alternatives should save through the normal equipment editor"
)
expect(ui.setAlternativeButton.enabled, "saved alternatives should enable set-wide application")
ui.editorAlternativeIndex = nil
ui:LoadEditor()
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
expectEqual(
    setup.alternatives.shoulders[1].setId,
    12,
    "copying a slot should carry its fallback alternatives"
)

ui:OpenSlotActionDialog()
ui.slotTargetCombo.selectedValue = "hands"
ui:TransferSlot(true)
expectEqual(setup.equipment.shoulders, nil, "move action should clear its source")
expect(setup.equipment.hands, "move action should fill its destination")
expectEqual(setup.alternatives.shoulders, nil, "moving a slot should clear source alternatives")
expectEqual(setup.alternatives.hands[1].setId, 12, "moving a slot should carry its alternatives")

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
itemLinks["owned:alternative-feet"] = {
    itemId = 1207,
    name = "Shoes of Order's Wrath",
    setId = 12,
    setName = "Order's Wrath",
    equipType = EQUIP_TYPE_FEET,
    armorType = ARMORTYPE_LIGHT,
    weaponType = WEAPONTYPE_NONE,
    traitType = ITEM_TRAIT_TYPE_ARMOR_DIVINES,
    quality = ITEM_QUALITY_LEGENDARY,
    level = 50,
    championPoints = 160,
    enchantId = 501,
}
testBags[BAG_WORN] = { "owned:head" }
testBags[BAG_BACKPACK] = { "owned:hands", "owned:ring", "owned:alternative-feet" }
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
BuildPlannerTestData:SetEquipment(currentBuild.id, setup.id, "feet", {
    setId = 34,
    setName = "Pillar of Nirn",
    armorType = ARMORTYPE_MEDIUM,
    traitType = ITEM_TRAIT_TYPE_ARMOR_DIVINES,
})
BuildPlannerTestData:SetAlternative(currentBuild.id, setup.id, "feet", nil, {
    setId = 12,
    setName = "Order's Wrath",
    armorType = ARMORTYPE_LIGHT,
    traitType = ITEM_TRAIT_TYPE_ARMOR_DIVINES,
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
local feetMatch = owner.inventory:GetMatch(setup.id, "feet")
expect(feetMatch and feetMatch.exact, "an exact fallback item should satisfy its planned slot")
expectEqual(feetMatch.alternativeIndex, 1, "owned matches should identify the chosen alternative")
local ringMatches = (owner.inventory:GetMatch(setup.id, "ring1") and 1 or 0)
    + (owner.inventory:GetMatch(setup.id, "ring2") and 1 or 0)
expectEqual(ringMatches, 1, "one owned ring should not satisfy two planned slots")
local setupProgress = owner.inventory:GetProgress(setup.id)
expectEqual(
    setupProgress.ready + setupProgress.adjustable + setupProgress.missing,
    setupProgress.planned,
    "setup progress should account for every planned slot"
)
expect(setupProgress.ready >= 2, "setup progress should count exact owned gear")
expect(setupProgress.adjustable >= 1, "setup progress should count adjustable gear")
expect(ui.progressLabel.text:find(tostring(setupProgress.missing), 1, true), "the window should show the live missing count")

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

itemLinks["crafted:item"] = {
    itemId = 777,
    name = "Crafted Test Cuirass",
    equipType = EQUIP_TYPE_CHEST,
    armorType = ARMORTYPE_LIGHT,
    weaponType = WEAPONTYPE_NONE,
    traitType = ITEM_TRAIT_TYPE_NONE,
    quality = ITEM_QUALITY_ARTIFACT,
    level = 50,
    championPoints = 160,
    enchantId = 501,
}
BuildPlannerTestData:SetEquipment(currentBuild.id, setup.id, "chest", {
    setName = "Crafted Test",
    itemLink = "crafted:item",
    armorType = ARMORTYPE_LIGHT,
})
BuildPlannerTestData:SetEquipment(currentBuild.id, setup.id, "head", {
    setId = 12,
    setName = "Order's Wrath",
    armorType = ARMORTYPE_LIGHT,
    traitType = ITEM_TRAIT_TYPE_ARMOR_DIVINES,
    quality = ITEM_QUALITY_ARTIFACT,
    enchantmentCategory = ENCHANTMENT_SEARCH_CATEGORY_STAMINA,
    enchantmentName = "Stamina",
})
BuildPlannerTestData:SetEquipment(currentBuild.id, setup.id, "backMain", {
    setId = 34,
    setName = "Pillar of Nirn",
    weaponType = WEAPONTYPE_TWO_HANDED_SWORD,
})
BuildPlannerTestData:SetAlternative(currentBuild.id, setup.id, "backMain", nil, {
    setId = 12,
    setName = "Order's Wrath",
    weaponType = WEAPONTYPE_TWO_HANDED_SWORD,
})
owner.inventory:Refresh()

ui:EditSlot("chest")
expectEqual(#ui.routeCombo.items, 3, "automatic, craft, and buy routes should be selectable")
for _, entry in ipairs(ui.routeCombo.items) do
    if entry.label == GetString(SI_GRAVVY_BUILD_PLANNER_ROUTE_BUY) then
        entry.callback()
    end
end
expectEqual(
    setup.acquisition.chest.preferredRoute,
    "buy",
    "choosing an acquisition route should persist it without resaving the gear"
)

local review = owner.shopping:BuildReview(false, false)
expectEqual(review.included, 3, "missing tradeable equipment and viable fallbacks should be included")
expect(review.owned >= 1, "owned requirements should be reported separately")
expectEqual(review.glyphs, 0, "glyphs should be opt-in")
expectEqual(#review.items, 3, "each eligible slot should create only one gear entry")
expectEqual(review.items[1].match.qualityMode, "any", "lower-quality gear should remain eligible for upgrading")
local hasUnrestrictedTrait = false
local hasAlternative = false
for _, item in ipairs(review.items) do
    hasUnrestrictedTrait = hasUnrestrictedTrait
        or item.match.traitType == ITEM_TRAIT_TYPE_NONE
    hasAlternative = hasAlternative
        or item.note:find("Alternative 1", 1, true) ~= nil
end
expect(hasUnrestrictedTrait, "an unspecified trait should remain unrestricted")
expect(hasAlternative, "shopping export should identify a fallback chosen over a bound primary")

local glyphReview = owner.shopping:BuildReview(false, true)
expectEqual(glyphReview.glyphs, 2, "missing enchantments should be exported even when owned gear is skipped")
expectEqual(#glyphReview.items, 5, "glyph entries should be added to the equipment batch")
local shareCode = owner.shopping:Encode(glyphReview)
expect(shareCode and shareCode:find("SL2:", 1, true) == 1, "fallback exports should use the SL2 format")
ITEM_LINK_TYPE = "item"
function ZO_LinkHandler_ParseLink(link)
    if link and link ~= "" then
        return nil, nil, ITEM_LINK_TYPE
    end
end
ShoppingListData = {
    NormalizeName = function(value) return zo_strlower(zo_strtrim(value)) end,
}
dofile("F:/laragon/www/ShoppingList/Share.lua")
local decodedShare = ShoppingListShare.DecodeCode(shareCode)
expect(decodedShare, "Shopping List should decode Build Planner's fallback code")
expectEqual(#decodedShare.items, 5, "the decoded SL2 list should retain every exported entry")
expectEqual(decodedShare.items[1].match.qualityMode, "any", "SL2 should retain upgradeable gear quality matching")

GravvyShoppingList = { API = { GetVersion = function() return 1 end } }
local _, oldApiState = owner.shopping:GetAPI()
expectEqual(oldApiState, "old", "API v1 should use the fallback export")
GravvyShoppingList = nil
ui:OpenExportDialog()
ui:ExecuteExport()
expect(not ui.codeDialog:IsHidden(), "a missing Shopping List should show the selectable code window")
expect(ui.codeEdit:GetText():find("SL2:", 1, true) == 1, "the fallback field should contain the SL2 code")

local openedUrl
RequestOpenUnsafeURL = function(url) openedUrl = url end
ui:OpenAddonPage()
expectEqual(
    openedUrl,
    "https://www.esoui.com/downloads/info4775-ShoppingList.html",
    "the add-on button should use the published Shopping List page"
)

local createdSpec
GravvyShoppingList = { API = {
    GetVersion = function() return 2 end,
    CreateList = function(_, spec)
        createdSpec = spec
        return true, { id = 8, name = spec.name, itemIds = {} }
    end,
} }
ui:OpenExportDialog()
ui:ExecuteExport()
expect(createdSpec, "API v2 should receive a transactional list specification")
expectEqual(createdSpec.onNameConflict, "unique", "exports should not overwrite an existing list")
expectEqual(#createdSpec.items, 3, "the API batch should contain eligible equipment")
GravvyShoppingList = nil

ui:EditSlot("head")
ui:ClearSlot()
expectEqual(setup.equipment.head, nil, "clear button should remove the requirement")

expectEqual(
    (function()
        local count = 0
        for _ in pairs(gamepadDialogs) do count = count + 1 end
        return count
    end)(),
    14,
    "gamepad editing, management, sharing, export, and help dialogs should register"
)
gamepadPreferred = true
gamepad:Show()
expect(not gamepad.control:IsHidden(), "gamepad mode should open the native planner")
expectEqual(#gamepad.list.entries, 14, "the gamepad planner should show every equipment slot")
expectEqual(gamepad:GetTargetSlot(), "head", "the native list should begin on the head slot")
gamepad:TogglePlannerView()
expectEqual(#gamepad.list.entries, 12, "the gamepad skill planner should show both six-slot bars")
expectEqual(
    gamepad:GetTargetData().skillBar,
    "front",
    "the gamepad skill planner should begin on the front bar"
)
expectEqual(
    gamepad:GetTargetData().skillSlot,
    1,
    "the gamepad skill planner should begin on skill slot one"
)
gamepad.pendingSkillBar = "front"
gamepad.pendingSkillSlot = 2
gamepad.pendingAbilityId = 1002
local skillSaved, skillError = gamepad:SavePendingSkill()
expect(skillSaved, skillError)
expectEqual(
    BuildPlannerTestData:GetCurrentSetup().skillBars.front[2].abilityId,
    1002,
    "gamepad skill selection should persist planned abilities"
)
gamepad:TogglePlannerView()
expectEqual(#gamepad.list.entries, 9, "the gamepad character planner should show every planned field")
expectEqual(gamepad:GetTargetData().characterField, "health", "character navigation should begin on Health")
gamepad.pendingCharacter = {
    health = "0",
    magicka = "0",
    stamina = "64",
    raceId = 9,
    mundus = 10,
    curse = 1,
    subclassLines = { "Animal Companions", "Winter's Embrace", "Grave Lord" },
}
local characterSaved, characterError = gamepad:SavePendingCharacter()
expect(characterSaved, characterError)
expectEqual(
    BuildPlannerTestData:GetCurrentSetup().character.attributes.stamina,
    64,
    "gamepad character planning should persist attributes"
)
gamepad:TogglePlannerView()
expect(#gamepad.list.entries >= 3, "the gamepad Champion planner should show all three disciplines")
expectEqual(gamepad:GetTargetData().championDiscipline, "craft",
    "Champion navigation should begin with Craft")
gamepad.pendingChampion = {
    discipline = "warfare",
    skillId = 3002,
    points = "50",
    slotIndex = 2,
}
local championSaved, championError = gamepad:SavePendingChampion()
expect(championSaved, championError)
expectEqual(BuildPlannerTestData:GetCurrentSetup().champion.warfare.slottables[2], 3002,
    "gamepad Champion planning should preserve slottable positions")
gamepad:TogglePlannerView()
expect(#gamepad.list.entries >= 1, "the gamepad Supplies planner should include an add entry")
gamepad.pendingSupply = {
    category = "potion",
    name = "Essence of Weapon Power",
    quantity = "10",
    note = "Boss fights",
}
local supplyGamepadSaved, supplyGamepadError = gamepad:SavePendingSupply()
expect(supplyGamepadSaved, supplyGamepadError)
expectEqual(BuildPlannerTestData:GetCurrentSetup().consumables[2].category, "potion",
    "gamepad consumable planning should persist categories")
gamepad:TogglePlannerView()
expect(#gamepad.list.entries >= 2, "the gamepad progression checklist should include planned steps")
gamepad.pendingChecklist = {
    category = "skillLine",
    name = "Undaunted",
    targetRank = "9",
    completed = false,
    note = "For Undaunted Mettle",
}
local checklistGamepadSaved, checklistGamepadError = gamepad:SavePendingChecklist()
expect(checklistGamepadSaved, checklistGamepadError)
expectEqual(BuildPlannerTestData:GetCurrentSetup().checklist[3].category, "skillLine",
    "gamepad progression planning should persist checklist types")
gamepad:TogglePlannerView()
expect(#gamepad.list.entries >= 1, "the gamepad comparison should show changes or an empty-state row")
gamepad:TogglePlannerView()
expectEqual(gamepad:GetTargetSlot(), "head", "returning to Gear should restore equipment navigation")

gamepad:LoadPendingRequirement()
gamepad.pendingRequirement.setName = "Order's Wrath"
gamepad.pendingRequirement.armorType = ARMORTYPE_LIGHT
gamepad.pendingRequirement.traitType = ITEM_TRAIT_TYPE_ARMOR_DIVINES
gamepad.pendingRequirement.enchantmentCategory = ENCHANTMENT_SEARCH_CATEGORY_STAMINA
gamepad.pendingRequirement.quality = ITEM_QUALITY_LEGENDARY
gamepad.pendingRequirement.championPoints = "160"
local gamepadSaved, gamepadSaveError = gamepad:SavePendingRequirement()
expect(gamepadSaved, gamepadSaveError)
local gamepadSetup = BuildPlannerTestData:GetCurrentSetup()
expectEqual(
    gamepadSetup.equipment.head.enchantmentCategory,
    ENCHANTMENT_SEARCH_CATEGORY_STAMINA,
    "gamepad enchantment choices should persist the planned enchantment"
)
expect(gamepadSetup.equipment.head.itemLink, "gamepad edits should resolve a preview item link")
gamepad:LoadPendingRequirement(1)
gamepad.pendingRequirement.setName = "Pillar of Nirn"
gamepad.pendingRequirement.armorType = ARMORTYPE_MEDIUM
gamepadSaved, gamepadSaveError = gamepad:SavePendingRequirement()
expect(gamepadSaved, gamepadSaveError)
expectEqual(
    gamepadSetup.alternatives.head[1].setId,
    34,
    "gamepad users should be able to save ordered slot alternatives"
)
expectEqual(
    GAMEPAD_TOOLTIPS.link,
    gamepadSetup.equipment.head.itemLink,
    "the selected gamepad row should use ESO's native item tooltip"
)
gamepad.pendingTransferSlot = "head"
gamepad.pendingTransferTarget = "shoulders"
gamepad.pendingTransferMove = false
local transferOk, transferError = gamepad:FinishTransfer()
expect(transferOk, transferError)
expect(
    BuildPlannerTestData:GetCurrentSetup().equipment.shoulders ~= nil,
    "gamepad users should be able to copy a requirement to a compatible slot"
)
expectEqual(
    BuildPlannerTestData:GetCurrentSetup().alternatives.shoulders[1].setId,
    34,
    "gamepad transfers should carry slot alternatives"
)
gamepad.list:SetSelectedIndex(1)

local _, gamepadBuild = BuildPlannerTestData:GetCurrentSetup()
if #gamepadBuild.setups == 1 then
    BuildPlannerTestData:CreateSetup(gamepadBuild.id, "Gamepad Setup")
end
local originalSetupId = BuildPlannerTestData:GetCurrentSetup().id
gamepad:SwitchSetup(1)
expect(
    BuildPlannerTestData:GetCurrentSetup().id ~= originalSetupId,
    "shoulder navigation should switch setups"
)
gamepad:SwitchSetup(-1)
gamepad.list:SetSelectedIndex(3)
gamepad:CycleTargetRoute()
expectEqual(
    BuildPlannerTestData:GetCurrentSetup().acquisition.chest,
    nil,
    "cycling past the last route should restore automatic selection"
)
gamepad:CycleTargetRoute()
expectEqual(
    BuildPlannerTestData:GetCurrentSetup().acquisition.chest.preferredRoute,
    "craft",
    "gamepad users should be able to choose among available acquisition routes"
)
gamepad.list:SetSelectedIndex(1)
gamepad:ClearTargetSlot()
expectEqual(
    BuildPlannerTestData:GetCurrentSetup().equipment.head,
    nil,
    "the gamepad clear action should remove the selected requirement"
)
expectEqual(
    BuildPlannerTestData:GetCurrentSetup().alternatives.head,
    nil,
    "clearing a primary requirement should also remove its alternatives"
)

GravvyShoppingList = nil
gamepad.exportIncludeOwned = false
gamepad.exportIncludeGlyphs = false
gamepad:RefreshExportReview()
gamepad:ExecuteGamepadExport()
expectEqual(
    shownGamepadDialog,
    "GRAVVY_BUILD_PLANNER_GAMEPAD_CODE",
    "gamepad exports should show the SL2 fallback when Shopping List is unavailable"
)
expect(
    gamepad.pendingCode and gamepad.pendingCode:find("SL2:", 1, true) == 1,
    "the gamepad fallback should expose a selectable SL2 code"
)
openedUrl = nil
gamepad:OpenAddonPage()
expectEqual(
    openedUrl,
    "https://www.esoui.com/downloads/info4775-ShoppingList.html",
    "the gamepad fallback should open the Shopping List add-on page"
)
gamepad:Hide()
gamepadPreferred = false
ui:Show()
EVENT_MANAGER.callbacks[EVENT_GAMEPAD_PREFERRED_MODE_CHANGED](nil, true)
expect(
    ui.window:IsHidden(),
    "switching to gamepad mode should close the mouse-driven planner cleanly"
)

dofile("MainMenu.lua")
GravvyBuildPlannerMainMenu:Initialize(owner)
LibMainMenu2 = {
    Init = function(self) self.initialized = true end,
    AddMenuItem = function(self, name, definition)
        self.itemName = name
        self.definition = definition
    end,
}
LibAddonMenu2 = {
    RegisterAddonPanel = function(self, name, panel)
        self.panelName, self.panel = name, panel
    end,
    RegisterOptionControls = function(self, name, options)
        self.optionPanelName, self.options = name, options
    end,
}
GravvyBuildPlannerMainMenu:Initialize(owner)
expect(LibMainMenu2.initialized, "main menu library should be initialized when available")
expectEqual(LibMainMenu2.definition.binding, "GRAVVY_BUILD_PLANNER_TOGGLE", "main menu should use the addon keybind")
GravvyBuildPlannerSettings:Initialize(owner)
expectEqual(LibAddonMenu2.panelName, "GravvyBuildPlannerOptions", "accessibility settings should register when LibAddonMenu is available")
expectEqual(#LibAddonMenu2.options, 4, "the settings panel should expose the accessibility controls")

SLASH_COMMANDS = {}
EVENT_ADD_ON_LOADED = 1
EVENT_INVENTORY_SINGLE_SLOT_UPDATE = 2
EVENT_INVENTORY_FULL_UPDATE = 3
EVENT_OPEN_BANK = 4
EVENT_PLAYER_ACTIVATED = 5
EVENT_ITEM_SET_COLLECTION_UPDATED = 6
EVENT_MANAGER = {
    callbacks = {},
    RegisterForEvent = function(self, _, eventId, callback)
        if eventId == EVENT_ADD_ON_LOADED then
            self.addOnLoaded = callback
        else
            self.callbacks[eventId] = callback
        end
    end,
    UnregisterForEvent = function() end,
}
dofile("GravvyBuildPlanner.lua")
EVENT_MANAGER.addOnLoaded(nil, "GravvyBuildPlanner")
expect(SLASH_COMMANDS["/buildplanner"], "long slash command should be registered")
expect(SLASH_COMMANDS["/gbp"], "short slash command should be registered")
expect(SLASH_COMMANDS["/buildplannerhelp"], "help slash command should be registered")
gamepadPreferred = true
GravvyBuildPlanner:ToggleWindow()
expect(
    not GravvyBuildPlanner.gamepad.control:IsHidden(),
    "the main toggle should open the native planner in gamepad mode"
)
GravvyBuildPlanner:ToggleWindow()
expect(
    GravvyBuildPlanner.gamepad.control:IsHidden(),
    "the main toggle should close the native planner in gamepad mode"
)
SLASH_COMMANDS["/buildplannerhelp"]()
expectEqual(
    shownGamepadDialog,
    "GRAVVY_BUILD_PLANNER_GAMEPAD_HELP",
    "the help command should use the native gamepad dialog in gamepad mode"
)

print("Build Planner UI tests passed")
