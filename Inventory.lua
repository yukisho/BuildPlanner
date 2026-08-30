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
        matchFingerprints = {},
        refreshSerial = 0,
        itemsLoaded = false,
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
        function()
            if self.owner.setCatalog then self.owner.setCatalog:QueueStaticRefresh() end
            self:QueueViewRefresh()
        end
    )
    self:QueueRefresh(250)
end

function Inventory:QueueViewRefresh(delayMs)
    self.viewRefreshSerial = (self.viewRefreshSerial or 0) + 1
    local serial = self.viewRefreshSerial
    zo_callLater(function()
        if serial == self.viewRefreshSerial then
            self:NotifyViews()
        end
    end, delayMs or 100)
end

function Inventory:QueueRefresh(delayMs)
    self.refreshSerial = self.refreshSerial + 1
    local serial = self.refreshSerial
    zo_callLater(function()
        if serial == self.refreshSerial then
            self:Refresh(true)
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

local function addFlowEdge(graph, from, to, capacity, cost, match, itemIndex)
    local forward = {
        to = to,
        rev = #graph[to] + 1,
        capacity = capacity,
        cost = cost,
        match = match,
        itemIndex = itemIndex,
    }
    local reverse = {
        to = from,
        rev = #graph[from] + 1,
        capacity = 0,
        cost = -cost,
    }
    graph[from][#graph[from] + 1] = forward
    graph[to][#graph[to] + 1] = reverse
end

local function augmentBestPath(graph, source, sink)
    local distance = {}
    local previousNode = {}
    local previousEdge = {}
    local queued = {}
    local queue = { source }
    local first = 1
    distance[source] = 0
    queued[source] = true

    while first <= #queue do
        local node = queue[first]
        first = first + 1
        queued[node] = false
        for edgeIndex, edge in ipairs(graph[node]) do
            if edge.capacity > 0 then
                local nextDistance = distance[node] + edge.cost
                if distance[edge.to] == nil or nextDistance < distance[edge.to] then
                    distance[edge.to] = nextDistance
                    previousNode[edge.to] = node
                    previousEdge[edge.to] = edgeIndex
                    if not queued[edge.to] then
                        queue[#queue + 1] = edge.to
                        queued[edge.to] = true
                    end
                end
            end
        end
    end

    if distance[sink] == nil or distance[sink] >= 0 then
        return false
    end
    local node = sink
    while node ~= source do
        local from = previousNode[node]
        local edge = graph[from][previousEdge[node]]
        edge.capacity = edge.capacity - 1
        local reverse = graph[node][edge.rev]
        reverse.capacity = reverse.capacity + 1
        node = from
    end
    return true
end

local function matchScore(match, candidateIndex)
    local score = 10000
    if match.exact then
        score = score + 1000000
    end
    score = score + math.max(0, 10 - candidateIndex) * 10
    score = score + math.max(0, 10 - #(match.differences or {}))
    return score
end

function Inventory:MatchSetup(setup)
    local planned = {}
    for _, slotKey in ipairs(Slots.ORDER) do
        local requirement = setup.equipment[slotKey]
        if requirement then
            local candidates = { requirement }
            for _, alternative in ipairs(
                (setup.alternatives and setup.alternatives[slotKey]) or {}
            ) do
                candidates[#candidates + 1] = alternative
            end
            planned[#planned + 1] = { slotKey = slotKey, candidates = candidates }
        end
    end
    if #planned == 0 or #self.items == 0 then
        return {}
    end

    local source = 1
    local slotStart = 2
    local itemStart = slotStart + #planned
    local sink = itemStart + #self.items
    local graph = {}
    for node = source, sink do
        graph[node] = {}
    end

    for slotIndex, entry in ipairs(planned) do
        local slotNode = slotStart + slotIndex - 1
        addFlowEdge(graph, source, slotNode, 1, 0)
        for itemIndex, item in ipairs(self.items) do
            local bestMatch
            local bestScore
            for candidateIndex, requirement in ipairs(entry.candidates) do
                local match = self.owner.acquisition:CompareItem(
                    entry.slotKey,
                    requirement,
                    setup,
                    item.itemLink
                )
                if match then
                    match.location = item.location
                    match.bagId = item.bagId
                    match.slotIndex = item.slotIndex
                    match.alternativeIndex = candidateIndex > 1
                        and candidateIndex - 1
                        or nil
                    match.requirement = requirement
                    local score = matchScore(match, candidateIndex)
                    if not bestScore or score > bestScore then
                        bestMatch = match
                        bestScore = score
                    end
                end
            end
            if bestMatch then
                addFlowEdge(
                    graph,
                    slotNode,
                    itemStart + itemIndex - 1,
                    1,
                    -bestScore,
                    bestMatch,
                    itemIndex
                )
            end
        end
    end
    for itemIndex, item in ipairs(self.items) do
        addFlowEdge(
            graph,
            itemStart + itemIndex - 1,
            sink,
            math.max(1, tonumber(item.count) or 1),
            0
        )
    end
    while augmentBestPath(graph, source, sink) do
    end

    local matches = {}
    for slotIndex, entry in ipairs(planned) do
        local slotNode = slotStart + slotIndex - 1
        for _, edge in ipairs(graph[slotNode]) do
            if edge.match and edge.capacity == 0 then
                matches[entry.slotKey] = edge.match
                break
            end
        end
    end
    return matches
end

function Inventory:GetMatchedRequirement(setupId, slotKey, setup)
    self:EnsureSetup(setup or setupId)
    local match = self.matches[setupId] and self.matches[setupId][slotKey]
    if match and match.requirement then
        return match.requirement, match.alternativeIndex
    end
    return setup and setup.equipment[slotKey], nil
end

function Inventory:FindSetup(setupId)
    for _, build in ipairs(self.owner.data:GetBuilds()) do
        for _, setup in ipairs(build.setups) do
            if setup.id == setupId then return setup end
        end
    end
end

function Inventory:BuildProgress(setup, matches)
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
    return progress
end

function Inventory:EnsureSetup(setupOrId)
    local setup = type(setupOrId) == "table" and setupOrId or self:FindSetup(setupOrId)
    if not setup then return nil end
    local currentFingerprint = self.owner.data:GetSetupFingerprint(setup)
    if self.matches[setup.id] and self.matchFingerprints[setup.id] == currentFingerprint then
        return setup
    end
    local matches = self:MatchSetup(setup)
    self.matches[setup.id] = matches
    self.progress[setup.id] = self:BuildProgress(setup, matches)
    self.matchFingerprints[setup.id] = currentFingerprint
    return setup
end

function Inventory:NotifyViews()
    if self.owner.ui then
        self.owner.ui:RefreshOwnedStatus()
    end
    if self.owner.gamepad then
        self.owner.gamepad:Refresh()
    end
end

function Inventory:Refresh(readBags)
    if readBags ~= false or not self.itemsLoaded then
        self.items = self:ReadItems()
        self.itemsLoaded = true
        if self.owner.consumableCatalog then
            self.owner.consumableCatalog:Refresh()
        end
    end
    self.matches = {}
    self.progress = {}
    self.matchFingerprints = {}
    self:EnsureSetup(self.owner.data:GetCurrentSetup())
    self:NotifyViews()
end

function Inventory:RefreshSetup(setup)
    setup = setup or self.owner.data:GetCurrentSetup()
    if not setup then return end
    self:EnsureSetup(setup)
    self:NotifyViews()
end

function Inventory:GetProgress(setupId)
    self:EnsureSetup(setupId)
    return self.progress[setupId]
        or { planned = 0, ready = 0, adjustable = 0, missing = 0 }
end

function Inventory:GetMatch(setupId, slotKey, requirement, setup)
    self:EnsureSetup(setup or setupId)
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
