GravvyBuildPlannerSlots = {}

local Slots = GravvyBuildPlannerSlots

Slots.ORDER = {
    "head",
    "shoulders",
    "chest",
    "hands",
    "waist",
    "legs",
    "feet",
    "neck",
    "ring1",
    "ring2",
    "frontMain",
    "frontOff",
    "backMain",
    "backOff",
}

Slots.DEFINITIONS = {
    head = { family = "armor", equipSlot = EQUIP_SLOT_HEAD },
    shoulders = { family = "armor", equipSlot = EQUIP_SLOT_SHOULDERS },
    chest = { family = "armor", equipSlot = EQUIP_SLOT_CHEST },
    hands = { family = "armor", equipSlot = EQUIP_SLOT_HAND },
    waist = { family = "armor", equipSlot = EQUIP_SLOT_WAIST },
    legs = { family = "armor", equipSlot = EQUIP_SLOT_LEGS },
    feet = { family = "armor", equipSlot = EQUIP_SLOT_FEET },
    neck = { family = "jewelry", equipSlot = EQUIP_SLOT_NECK },
    ring1 = { family = "jewelry", equipSlot = EQUIP_SLOT_RING1 },
    ring2 = { family = "jewelry", equipSlot = EQUIP_SLOT_RING2 },
    frontMain = { family = "weapon", equipSlot = EQUIP_SLOT_MAIN_HAND },
    frontOff = { family = "weapon", equipSlot = EQUIP_SLOT_OFF_HAND },
    backMain = { family = "weapon", equipSlot = EQUIP_SLOT_BACKUP_MAIN },
    backOff = { family = "weapon", equipSlot = EQUIP_SLOT_BACKUP_OFF },
}

local twoHanded = {}
local function addTwoHanded(weaponType)
    if weaponType ~= nil then
        twoHanded[weaponType] = true
    end
end

addTwoHanded(WEAPONTYPE_TWO_HANDED_AXE)
addTwoHanded(WEAPONTYPE_TWO_HANDED_HAMMER)
addTwoHanded(WEAPONTYPE_TWO_HANDED_SWORD)
addTwoHanded(WEAPONTYPE_BOW)
addTwoHanded(WEAPONTYPE_FIRE_STAFF)
addTwoHanded(WEAPONTYPE_FROST_STAFF)
addTwoHanded(WEAPONTYPE_LIGHTNING_STAFF)
addTwoHanded(WEAPONTYPE_HEALING_STAFF)

local offHandForMain = {
    frontMain = "frontOff",
    backMain = "backOff",
}

function Slots:IsValid(slotKey)
    return self.DEFINITIONS[slotKey] ~= nil
end

function Slots:Get(slotKey)
    return self.DEFINITIONS[slotKey]
end

function Slots:IsTwoHanded(weaponType)
    return twoHanded[weaponType] == true
end

function Slots:GetOccupiedOffHand(slotKey, weaponType)
    if self:IsTwoHanded(weaponType) then
        return offHandForMain[slotKey]
    end
end

function Slots:GetMainHand(slotKey)
    if slotKey == "frontOff" then
        return "frontMain"
    elseif slotKey == "backOff" then
        return "backMain"
    end
end

function Slots:IsRequirementCompatible(slotKey, requirement)
    local definition = self:Get(slotKey)
    if not definition or type(requirement) ~= "table" then
        return false
    end

    local armorType = requirement.armorType
    local weaponType = requirement.weaponType
    local hasArmorType = armorType ~= nil and armorType ~= (ARMORTYPE_NONE or 0)
    local hasWeaponType = weaponType ~= nil and weaponType ~= (WEAPONTYPE_NONE or 0)

    if definition.family == "armor" then
        return not hasWeaponType
    elseif definition.family == "jewelry" then
        return not hasArmorType and not hasWeaponType
    end

    if hasArmorType then
        return false
    end
    if self:IsTwoHanded(weaponType) and self:GetMainHand(slotKey) then
        return false
    end
    if WEAPONTYPE_SHIELD and weaponType == WEAPONTYPE_SHIELD and not self:GetMainHand(slotKey) then
        return false
    end
    return true
end
