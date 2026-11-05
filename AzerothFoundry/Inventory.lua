-- Local, last-observed bag/bank snapshots for WoW Forever. No outgoing messages.
-- The bank is only inspected while its own frame is open. Nothing is inferred
-- about unvisited characters, mail, shared/warband storage or trade transfers.
local _, AF = ...
local function Now() return type(time) == 'function' and time() or 0 end
local function Call(f, ...)
    if type(f) ~= 'function' then return nil, false end
    local ok, v = pcall(f, ...)
    return ok and v or nil, ok
end

function AF:InitializeInventory()
    self.db.inventory = type(self.db.inventory) == 'table' and self.db.inventory or {}
    self.db.schema = math.max(tonumber(self.db.schema) or 1, 5)
end

local function ScanContainers(indices)
    local api = C_Container
    local slots = api and api.GetContainerNumSlots or GetContainerNumSlots
    local get = api and api.GetContainerItemInfo or GetContainerItemInfo
    if type(slots) ~= 'function' or type(get) ~= 'function' then return nil end
    local foundContainer, all = false, {}
    for _, bag in ipairs(indices) do
        local count, valid = Call(slots, bag)
        if valid and type(count) == 'number' and count >= 0 then
            -- A real bank can return zero slots while the bank isn't open;
            -- the caller checks bankOpen and requires at least one usable container.
            if count > 0 then foundContainer = true end
            for slot=1, math.min(count, 200) do
                local data, ok = Call(get, bag, slot)
                if not ok then return nil end -- Do not overwrite with a partial scan
                if type(data) == 'table' then
                    local id = tonumber(data.itemID)
                    local quantity = tonumber(data.stackCount) or 1
                    if id and id > 0 and quantity > 0 then
                        all[id] = (all[id] or 0) + quantity
                    end
                end
            end
        end
    end
    return foundContainer and all or nil
end

function AF:ScanBags()
    if not self.db or self.inventoryShutdown then return false end
    local bagLimit = tonumber(NUM_BAG_SLOTS) or 4
    bagLimit = math.max(0, math.min(bagLimit, 5))
    local indices,used={},{}
    local function AddBag(index)
        index=tonumber(index)
        if index and index>=0 and not used[index] then
            used[index]=true
            indices[#indices+1]=index
        end
    end
    for i=0,bagLimit do AddBag(i) end
    -- Forever inherits Mainline's optional reagent bag (normally index 5).
    -- Feature-detect its enum instead of assuming the Classic bag layout.
    local bagEnum=Enum and Enum.BagIndex
    if type(bagEnum)=='table' then AddBag(bagEnum.ReagentBag) end
    local counts = ScanContainers(indices)
    if not counts then return false end
    local key = self:GetCurrentKey()
    self.db.inventory[key] = self.db.inventory[key] or {}
    self.db.inventory[key].bags = {counts=counts, scanned=Now()}
    return true
end

function AF:ScanBank()
    if not self.db or self.inventoryShutdown or not self.bankOpen then return false end
    -- Forever uses Mainline-style character bank tabs, with a different
    -- index range from Retail on some builds. Numeric Classic bank-bag
    -- assumptions can misread the reagent bag and miss purchased tabs.
    -- Enumerate only named CHARACTER bank tabs; never include account bank.
    local indices,seen={},{}
    local bagEnum=Enum and Enum.BagIndex
    if type(bagEnum)=='table' then
        for name,index in pairs(bagEnum) do
            if type(name)=='string' and name:match('^CharacterBankTab_%d+$')
                and type(index)=='number' and not seen[index] then
                seen[index]=true
                indices[#indices+1]=index
            end
        end
        table.sort(indices)
    end
    if #indices==0 then
        -- Do not guess Classic bag IDs on a Mainline bank implementation.
        -- Preserve the previous snapshot until the client exposes its tabs.
        if type(C_Bank)=='table' then return false end
        local bagCount=math.max(0,math.min(tonumber(NUM_BAG_SLOTS) or 4,5))
        local bankCount=math.max(0,math.min(tonumber(NUM_BANKBAGSLOTS) or 7,8))
        indices={tonumber(BANK_CONTAINER) or -1}
        for i=bagCount+1,bagCount+bankCount do indices[#indices+1]=i end
    end
    local counts=ScanContainers(indices)
    if not counts then return false end
    local key=self:GetCurrentKey()
    self.db.inventory[key]=self.db.inventory[key] or {}
    self.db.inventory[key].bank={counts=counts, scanned=Now()}
    return true
end

function AF:ScheduleInventoryScan()
    if not self.db then return end
    if self.inventoryRefreshQueued then return end
    self.inventoryRefreshQueued=true
    local function scan()
        self.inventoryRefreshQueued=nil
        self:ScanBags()
        if self.bankOpen then self:ScanBank() end
        if self.SyncGuidedGoals then self:SyncGuidedGoals(true) end
        if self.UI and self.UI.RefreshGoalTracker then self.UI:RefreshGoalTracker() end
        if self.UI and self.UI.RefreshCraftPlanner then self.UI:RefreshCraftPlanner() end
        if self.db and self.db.settings and (self.db.settings.page=='Living Workshop' or self.db.settings.page=='Goals') then self:RefreshUI() end
    end
    if C_Timer and type(C_Timer.After)=='function' then
        C_Timer.After(0.2, scan)
    else scan() end
end

-- Snapshots are estimates; a count from yesterday must never be displayed
-- as though it were an authoritative current inventory count.
function AF:GetInventoryEstimate(itemID, scope, ownerKey)
    local result={total=0, characters={}, anyScanned=false, oldest=nil, newest=nil}
    for _, char in ipairs(self:GetPlanningResourceCharacters(scope or 'all',ownerKey)) do
        local data=self.db.inventory[char.key] or {}
        local own=0
        local countData=0
        for _, section in ipairs({'bags','bank'}) do
            local snap=data[section]
            if type(snap)=='table' and type(snap.counts)=='table' then
                countData=countData+1
                own=own+(tonumber(snap.counts[itemID]) or 0)
                if snap.scanned then
                    result.oldest=math.min(result.oldest or snap.scanned,snap.scanned)
                    result.newest=math.max(result.newest or snap.scanned,snap.scanned)
                end
            end
        end
        if countData>0 then
            result.total=result.total+own
            result.anyScanned=true
            result.characters[#result.characters+1]={character=char,count=own,
                bags=data.bags and data.bags.scanned,bank=data.bank and data.bank.scanned,
                bankKnown=data.bank ~= nil}
        end
    end
    return result
end
