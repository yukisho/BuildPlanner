GravvyBuildPlannerInventory = {}

local Inventory = GravvyBuildPlannerInventory
local Slots = GravvyBuildPlannerSlots

local function addBag(bags, bagId, location)
    if bagId ~= nil then
        bags[#bags + 1] = { id = bagId, location = location }
    end
end

function Inventory:New(owner)
    local inventory = setmetatable({
        owner = owner,
        items = {},
        matches = {},
        progress = {},
        refreshSerial = 0,
    }, { __index = self })
    inventory.bags = {}
    addBag(inventory.bags, BAG_WORN, "equipped")
    addBag(inventory.bags, BAG_BACKPACK, "backpack")
    addBag(inventory.bags, BAG_BANK, "bank")
    addBag(inventory.bags, BAG_SUBSCRIBER_BANK, "bank")
    return inventory
end

function Inventory:Initialize()
    self.bagIds = {}
    for _, bag in ipairs(self.bags) do
        self.bagIds[bag.id] = true
    end

    EVENT_MANAGER:RegisterForEvent(
        "GravvyBuildPlanner_InventorySlot",
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        function(_, bagId)
            if self.bagIds[bagId] then
                self:QueueRefresh()
            end
        end
    )
    EVENT_MANAGER:RegisterForEvent(
        "GravvyBuildPlanner_InventoryFull",
        EVENT_INVENTORY_FULL_UPDATE,
        function() self:QueueRefresh() end
    )
    EVENT_MANAGER:RegisterForEvent(
        "GravvyBuildPlanner_InventoryBank",
        EVENT_OPEN_BANK,
        function() self:QueueRefresh() end
    )
    EVENT_MANAGER:RegisterForEvent(
        "GravvyBuildPlanner_InventoryActivated",
        EVENT_PLAYER_ACTIVATED,
        function() self:QueueRefresh(250) end
    )
    EVENT_MANAGER:RegisterForEvent(
        "GravvyBuildPlanner_CollectionUpdated",
        EVENT_ITEM_SET_COLLECTION_UPDATED,
        function() self:QueueRefresh() end
    )
    self:QueueRefresh(250)
end

function Inventory:QueueRefresh(delayMs)
    self.refreshSerial = self.refreshSerial + 1
    local serial = self.refreshSerial
    zo_callLater(function()
        if serial == self.refreshSerial then
            self:Refresh()
        end
    end, delayMs or 100)
end

function Inventory:ReadItems()
    local items = {}
    for _, bag in ipairs(self.bags) do
        local size = GetBagSize(bag.id) or 0
        for slotIndex = 0, size - 1 do
            local itemLink = GetItemLink(bag.id, slotIndex, LINK_STYLE_DEFAULT)
            if itemLink and itemLink ~= "" then
                items[#items + 1] = {
                    bagId = bag.id,
                    slotIndex = slotIndex,
                    location = bag.location,
                    itemLink = itemLink,
                    count = math.max(1, GetSlotStackSize(bag.id, slotIndex) or 1),
                }
            end
        end
    end
    return items
end

local function getRequirementOrder(setup)
    local ordered = {}
    for index, slotKey in ipairs(Slots.ORDER) do
        local requirement = setup.equipment[slotKey]
        if requirement then
            local priority = 0
            if requirement.traitType and requirement.traitType ~= ITEM_TRAIT_TYPE_NONE then
                priority = priority + 2
            end
            if requirement.enchantmentCategory then
                priority = priority + 1
            end
            ordered[#ordered + 1] = {
                slotKey = slotKey,
                requirement = requirement,
                priority = priority,
                index = index,
            }
        end
    end
    table.sort(ordered, function(left, right)
        if left.priority == right.priority then
            return left.index < right.index
        end
        return left.priority > right.priority
    end)
    return ordered
end

function Inventory:MatchSetup(setup)
    local matches = {}
    local remaining = {}
    for index, item in ipairs(self.items) do
        remaining[index] = item.count
    end

    local ordered = getRequirementOrder(setup)
    for _, wantExact in ipairs({ true, false }) do
        for _, planned in ipairs(ordered) do
            if not matches[planned.slotKey] then
                for index, item in ipairs(self.items) do
                    if remaining[index] > 0 then
                        local match = self.owner.acquisition:CompareItem(
                            planned.slotKey,
                            planned.requirement,
                            setup,
                            item.itemLink
                        )
                        if match and match.exact == wantExact then
                            match.location = item.location
                            match.bagId = item.bagId
                            match.slotIndex = item.slotIndex
                            matches[planned.slotKey] = match
                            remaining[index] = remaining[index] - 1
                            break
                        end
                    end
                end
            end
        end
    end
    return matches
end

function Inventory:Refresh()
    self.items = self:ReadItems()
    self.matches = {}
    self.progress = {}
    for _, build in ipairs(self.owner.data:GetBuilds()) do
        for _, setup in ipairs(build.setups) do
            local matches = self:MatchSetup(setup)
            self.matches[setup.id] = matches
            local progress = { planned = 0, ready = 0, adjustable = 0, missing = 0 }
            for _, slotKey in ipairs(Slots.ORDER) do
                if setup.equipment[slotKey] then
                    progress.planned = progress.planned + 1
                    local match = matches[slotKey]
                    if match and match.exact then
                        progress.ready = progress.ready + 1
                    elseif match then
                        progress.adjustable = progress.adjustable + 1
                    else
                        progress.missing = progress.missing + 1
                    end
                end
            end
            self.progress[setup.id] = progress
        end
    end
    if self.owner.ui then
        self.owner.ui:RefreshOwnedStatus()
    end
    if self.owner.gamepad then
        self.owner.gamepad:Refresh()
    end
end

function Inventory:GetProgress(setupId)
    return self.progress[setupId]
        or { planned = 0, ready = 0, adjustable = 0, missing = 0 }
end

function Inventory:GetMatch(setupId, slotKey, requirement, setup)
    local setupMatches = self.matches[setupId]
    local match = setupMatches and setupMatches[slotKey]
    if not match or not requirement or not setup then
        return match
    end

    local current = self.owner.acquisition:CompareItem(
        slotKey,
        requirement,
        setup,
        match.itemLink
    )
    if not current then
        return nil
    end
    current.location = match.location
    current.bagId = match.bagId
    current.slotIndex = match.slotIndex
    return current
end
