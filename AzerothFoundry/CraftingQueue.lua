-- Azeroth Foundry v0.3.3: persistent, ordered crafting plans.
-- This module models VIRTUAL reservations only: it never locks, moves, trades,
-- or consumes the player's actual items. Inventory is last-observed data.
local _, AF = ...
local function Now() return type(time)=='function' and time() or 0 end
local function Number(v) return tonumber(v) end
local function FloorPositive(v) return math.max(0,math.floor(Number(v) or 0)) end

-- v0.7.3.2: Queued crafts are PRODUCTION TASKS, never Goal records.
-- Former builds stored both in db.projects. Copy legacy active queue plans
-- once to independent queue entries without altering/deleting any saved Goals.
local function CopyTable(source)
    if type(source)~='table' then return source end
    local out={}
    for k,v in pairs(source) do out[k]=CopyTable(v) end
    return out
end
function AF:InitializeCraftingQueue()
    local db=self.db
    db.craftingQueue=type(db.craftingQueue)=='table' and db.craftingQueue or {}
    if type(db.craftingEntries)~='table' then
        db.craftingEntries={}
    end
    if not db.craftingQueueSeparated then
        local old={}
        for _,p in ipairs(db.projects or {}) do
            if type(p)=='table' and type(p.crafting)=='table' and p.id and not p.done then old[p.id]=p end
        end
        local ordered,seen={},{}
        for _,id in ipairs(db.craftingQueue) do
            if old[id] and not seen[id] then ordered[#ordered+1]=old[id];seen[id]=true end
        end
        for _,p in ipairs(db.projects or {}) do
            if old[p.id] and not seen[p.id] then ordered[#ordered+1]=p;seen[p.id]=true end
        end
        -- New queue ids come from the same global sequence for uniqueness.
        -- Old Goal ids and all other saved goal/track data stay unchanged.
        for _,p in ipairs(ordered) do
            local item={id=self:NextID(),title=p.title,owner=p.owner,
                created=p.created or Now(),updated=p.updated or Now(),done=false,
                crafting=CopyTable(p.crafting)}
            db.craftingEntries[#db.craftingEntries+1]=item
            db.craftingQueue[#db.craftingQueue+1]=item.id
        end
        -- Replace the legacy id list only after copying in the old order.
        local newOrder={}
        for _,item in ipairs(db.craftingEntries) do
            if item and item.id then newOrder[#newOrder+1]=item.id end
        end
        db.craftingQueue=newOrder
        db.craftingQueueSeparated=true
    end
    db.schema=math.max(Number(db.schema) or 1,11)
    self:NormalizeCraftingQueue()
end

function AF:NormalizeCraftingQueue()
    local entries,seen,clean={}, {}, {}
    for _,p in ipairs(self.db.craftingEntries or {}) do
        if type(p)=='table' and type(p.crafting)=='table' and not p.done and p.id then entries[p.id]=p end
    end
    for _,id in ipairs(self.db.craftingQueue or {}) do
        if entries[id] and not seen[id] then clean[#clean+1]=id;seen[id]=true end
    end
    for _,p in ipairs(self.db.craftingEntries or {}) do
        if entries[p.id] and not seen[p.id] then clean[#clean+1]=p.id;seen[p.id]=true end
    end
    self.db.craftingQueue=clean
    return clean
end

function AF:GetCraftingQueueProjects()
    local result={}
    for _,id in ipairs(self:NormalizeCraftingQueue()) do
        local p=self:FindRecord(self.db.craftingEntries,id)
        if p then result[#result+1]=p end
    end
    return result
end

-- A queue entry is a craft request, never a project/goal or guided objective.
function AF:AddQueuedCraft(plan)
    if not plan or not self.db or not plan.recipeID or not plan.characterKey then return nil end
    local count=tonumber(plan.quantity)
    if not count or count~=math.floor(count) or count<1 or count>99 then return nil end
    self.db.craftingEntries=type(self.db.craftingEntries)=='table' and self.db.craftingEntries or {}
    local entry={id=self:NextID(), title='Craft '..count..'x '..(plan.recipeName or 'Recipe'),
        owner=plan.characterKey, created=Now(),updated=Now(),done=false,
        crafting={scope=plan.scope=='expedition' and 'expedition' or 'all',
            recipeID=plan.recipeID,quantity=count,professionID=plan.professionID,
            created=Now(),completed=0,routes={}}}
    self.db.craftingEntries[#self.db.craftingEntries+1]=entry
    self:NormalizeCraftingQueue()
    if self.RefreshUI then self:RefreshUI() end
    return entry
end

-- Only a QUEUE record is removed. Never delete a record from db.projects.
function AF:RemoveQueuedCraft(id)
    if not self.db or not self.db.craftingEntries then return false end
    local removed=false
    for i,p in ipairs(self.db.craftingEntries) do
        if p.id==id then table.remove(self.db.craftingEntries,i);removed=true;break end
    end
    if not removed then return false end
    self:NormalizeCraftingQueue()
    if self.lastQueueCraftRequest and self.lastQueueCraftRequest.projectID==id then
        self.lastQueueCraftRequest=nil
    end
    if self.RefreshUI then self:RefreshUI() end
    return true
end

function AF:MoveCraftingProject(id,position)
    local q=self:NormalizeCraftingQueue()
    local old
    for i,v in ipairs(q) do if v==id then old=i;break end end
    if not old then return false end
    local destination
    if type(position)=='number' then
        destination=math.max(1,math.min(#q,position))
    else
        for i,v in ipairs(q) do if v==position then destination=i;break end end
    end
    if not destination or destination==old then return false end
    table.remove(q,old)
    table.insert(q,destination,id)
    self.db.craftingQueue=q
    return true
end

-- Project IDs and queue indices are both numbers. Keep the API unambiguous:
-- the up/down arrows use a numeric POSITION; dropping a craft uses an item ID
-- that is resolved to its current queue position before moving.
function AF:MoveCraftingProjectOnto(id,targetId)
    local q=self:NormalizeCraftingQueue()
    if id==targetId then return false end
    local index
    for i,v in ipairs(q) do
        if v==targetId then index=i;break end
    end
    return index and self:MoveCraftingProject(id,index) or false
end

function AF:GetCraftingQueuePosition(id)
    for i,p in ipairs(self:GetCraftingQueueProjects()) do if p.id==id then return i end end
end

function AF:SetCraftingRoute(projectID,itemID,route)
    local p=self:FindRecord(self.db.craftingEntries or {},projectID)
        or self:FindRecord(self.db.projects or {},projectID)
    if not p or type(p.crafting)~='table' then return false end
    if route~='direct' and route~='auto' then return false end
    p.crafting.routes=type(p.crafting.routes)=='table' and p.crafting.routes or {}
    p.crafting.routes[tostring(itemID)]=route=='direct' and 'direct' or nil
    p.updated=Now()
    return true
end

-- A shared per-character, per-storage pool prevents allocating the same bar
-- to two queued projects. This works even when their scopes differ.
local function NewLedger(AF)
    local ledger={pools={},initial={},claimedBy={},scans=0,oldest=nil}
    for _,c in ipairs(AF:GetWorkshopCharacters('all')) do
        local inventory=(AF.db.inventory or {})[c.key] or {}
        for _,location in ipairs({'bags','bank'}) do
            local snap=inventory[location]
            if type(snap)=='table' and type(snap.counts)=='table' then
                local pool={key=c.key,location=location,counts={},scanned=snap.scanned}
                for itemID,count in pairs(snap.counts) do
                    local id=Number(itemID)
                    if id and id>0 then
                        pool.counts[id]=FloorPositive(count)
                        ledger.initial[id]=(ledger.initial[id] or 0)+FloorPositive(count)
                    end
                end
                ledger.pools[#ledger.pools+1]=pool
                ledger.scans=ledger.scans+1
                if snap.scanned then
                    ledger.oldest=math.min(ledger.oldest or snap.scanned,snap.scanned)
                end
            end
        end
    end
    return ledger
end

local function Rollback(transactions,mark)
    for i=#transactions,mark+1,-1 do
        local tx=transactions[i]
        tx.pool.counts[tx.id]=(tx.pool.counts[tx.id] or 0)+tx.count
        transactions[i]=nil
    end
end
local function TrimTraces(traces,mark)
    for i=#traces,mark+1,-1 do traces[i]=nil end
end

local function TakeStock(ledger,allowed,id,count,owner,transactions)
    local covered=0
    -- Current crafter first, then other eligible characters; bags before bank.
    for pass=1,2 do
        for _,pool in ipairs(ledger.pools) do
            if (pass==1 and pool.key==owner or pass==2 and pool.key~=owner)
                and allowed[pool.key] then
                local has=pool.counts[id] or 0
                local amount=math.min(has,count-covered)
                if amount>0 then
                    pool.counts[id]=has-amount
                    transactions[#transactions+1]={pool=pool,id=id,count=amount}
                    covered=covered+amount
                    if covered>=count then return covered end
                end
            end
        end
    end
    return covered
end

local function AllowKeys(AF,scope,ownerKey)
    local keys={}
    for _,c in ipairs(AF:GetPlanningResourceCharacters(scope,ownerKey)) do keys[c.key]=true end
    return keys
end

function AF:FindQueueRecipe(p)
    local craft=p and p.crafting
    if not craft or not p.owner or not craft.recipeID then return nil end
    local byProfession=(self.db.recipeSnapshots or {})[p.owner] or {}
    if craft.professionID and byProfession[craft.professionID] then
        local snap=byProfession[craft.professionID]
        local r=snap.recipes and snap.recipes[craft.recipeID]
        if r and r.learned then return snap,r end
    end
    for _,snap in pairs(byProfession) do
        local r=snap.recipes and snap.recipes[craft.recipeID]
        if r and r.learned then return snap,r end
    end
    return nil
end

local function FriendlyName(AF,id)
    local p=AF:GetItemPresentation(id)
    return (p and p.name) or ('Item #'..tostring(id))
end

-- Returns an estimate with allocations applied to the shared ledger. Intermediate
-- production is attempted transactionally: a failed subcraft rolls back all
-- reagents it tentatively used, avoiding phantom reservations.
function AF:EvaluateQueuedCraft(p,ledger)
    local craft=p.crafting
    local scope=craft.scope=='expedition' and 'expedition' or 'all'
    local result={project=p,id=p.id,scope=scope,policy=self:GetExpeditionPlanningPolicy(scope,p.owner),quantity=FloorPositive(craft.quantity),
        steps={},crafts={},status='unknown',reasons={},allocated={},conflicts={}}
    if p.done then result.status='complete';return result end
    if result.quantity<1 or result.quantity>99 then
        result.reasons[1]='Craft quantity must be 1–99.';return result
    end
    if not self:WorkshopCharacterAllowed(p.owner,scope) then
        result.reasons[1]='Assigned crafter is outside this project scope.';return result
    end
    if scope=='expedition' and result.policy.mode=='excluded' then
        result.reasons[1]=result.policy.note;return result
    end
    local snapshot,record=self:FindQueueRecipe(p)
    if not snapshot then
        result.reasons[1]='Learned recipe snapshot unavailable; reopen the profession.'
        return result
    end
    local recipe=self:GetRecipeDetails(snapshot,record)
    if not recipe or recipe.reagentsIncomplete or type(recipe.reagents)~='table' or #recipe.reagents==0 then
        result.reasons[1]='Recipe reagents are incomplete or unavailable.'
        return result
    end
    local allowed=AllowKeys(self,scope,p.owner)
    local hasInventory=false
    for _,pool in ipairs(ledger.pools) do
        if allowed[pool.key] then hasInventory=true;break end
    end
    if not hasInventory then
        result.reasons[1]='No recorded inventory for eligible characters. Log in or visit a bank to scan.'
        return result
    end
    local producers=self:BuildKnownOutputIndex(scope,p.owner)
    local transactions,traces={},{}
    local nodeBudget=0
    local incomplete=false
    local function Fulfill(id,count,depth,ancestry,preferOwner,route)
        nodeBudget=nodeBudget+1
        if nodeBudget>450 then incomplete=true;return 0 end
        local direct=TakeStock(ledger,allowed,id,count,preferOwner,transactions)
        local covered=direct
        if covered>=count or depth>=4 or route=='direct' or ancestry[id] then
            if ancestry[id] and covered<count then incomplete=true end
            return covered
        end
        local choices=producers[id] or {}
        for _,candidate in ipairs(choices) do
            if covered>=count then break end
            local reagents=candidate.recipe and candidate.recipe.reagents
            if type(reagents)=='table' and #reagents>0 and not candidate.recipe.reagentsIncomplete then
                local output=math.max(1,FloorPositive(candidate.outputCount))
                local attempted=0
                while covered<count and attempted<200 and nodeBudget<450 do
                    attempted=attempted+1
                    local txMark,traceMark=#transactions,#traces
                    local viable=true
                    ancestry[id]=true
                    for _,r in ipairs(reagents) do
                        local required=FloorPositive(r.quantity)
                        if not Number(r.itemID) or required<1
                            or Fulfill(Number(r.itemID),required,depth+1,ancestry,candidate.character.key,nil)<required then
                            viable=false;break
                        end
                    end
                    ancestry[id]=nil
                    if viable then
                        local made=math.min(output,count-covered)
                        covered=covered+made
                        traces[#traces+1]={itemID=id,count=made,crafter=candidate.character.name,
                            crafterKey=candidate.character.key,profession=candidate.snapshot.professionName,
                            recipeID=candidate.recipe.id}
                    else
                        Rollback(transactions,txMark)
                        TrimTraces(traces,traceMark)
                        break
                    end
                end
                if attempted>=200 and covered<count then incomplete=true end
            end
        end
        return covered
    end

    local missingTotal=0
    for _,r in ipairs(recipe.reagents) do
        local id,perCraft=Number(r.itemID),FloorPositive(r.quantity)
        if not id or perCraft==0 then incomplete=true;break end
        local need=perCraft*result.quantity
        local txStart,traceStart=#transactions,#traces
        local selectedRoute=type(craft.routes)=='table' and craft.routes[tostring(id)] or nil
        local have=Fulfill(id,need,0,{},p.owner,selectedRoute)
        local craftsFor={}
        for j=traceStart+1,#traces do
            local t=traces[j]
            craftsFor[#craftsFor+1]=t
        end
        local previouslyClaimed=ledger.claimedBy[id] or {}
        local prior=0
        for _,claim in ipairs(previouslyClaimed) do prior=prior+claim.amount end
        local shortage=need-have
        if shortage>0 then missingTotal=missingTotal+shortage end
        local step={itemID=id,name=FriendlyName(self,id),needed=need,covered=have,
            missing=shortage,route=selectedRoute or 'auto',crafts=craftsFor,
            priorityConflict=shortage>0 and prior>0 and math.min(shortage,prior) or 0}
        result.steps[#result.steps+1]=step
        if step.priorityConflict>0 then
            result.conflicts[#result.conflicts+1]={itemID=id,count=step.priorityConflict}
        end
    end
    -- Reservations are only virtual. TakeStock altered this per-run ledger,
    -- not saved inventory or a real item. Record consumed sources for auditing.
    for _,tx in ipairs(transactions) do
        result.allocated[tx.id]=(result.allocated[tx.id] or 0)+tx.count
        ledger.claimedBy[tx.id]=ledger.claimedBy[tx.id] or {}
        ledger.claimedBy[tx.id][#ledger.claimedBy[tx.id]+1]={projectID=p.id,amount=tx.count}
    end
    result.crafts=traces
    result.missing=missingTotal
    if incomplete then
        result.status='unknown'
        result.reasons[1]='Some crafting requirements could not be evaluated safely.'
    elseif missingTotal>0 then result.status='missing'
    elseif #traces>0 then result.status='preparation'
    else result.status='ready' end
    return result
end


-- Crafting GOALS are separate from the production queue; they may still
-- inspect a plan and ingredient readiness without reserving queued stock.
function AF:EvaluateIndependentCraftingGoal(project)
    if not project or not project.crafting then return nil end
    return self:EvaluateQueuedCraft(project,NewLedger(self))
end

-- Called on page refresh and on-demand; does not mutate saved projects or
-- mark checklists complete. Completed projects relinquish their reservations.
function AF:EvaluateCraftingQueue()
    local ledger=NewLedger(self)
    local entries={}
    for _,p in ipairs(self:GetCraftingQueueProjects()) do
        entries[#entries+1]=self:EvaluateQueuedCraft(p,ledger)
    end
    return {entries=entries,byId=(function()
        local map={};for _,e in ipairs(entries) do map[e.id]=e end;return map
    end)(),sources=ledger.scans,oldest=ledger.oldest}
end

function AF:CraftStatusLabel(status)
    local labels={ready='Materials ready',preparation='Ready after crafting',
        missing='Resources missing',unknown='Cannot verify',complete='Completed'}
    return labels[status] or 'Cannot verify'
end


-- Existing checklists from v0.3.2 lack item IDs. Only recognize tasks with
-- the exact generated prefix and a matching top-level ingredient. Never
-- reinterpret manually authored tasks or their saved completion flags.
function AF:CraftingChecklistItemID(project,task,plan)
    if not project or not project.crafting or not task or not plan then return nil end
    if task.autoMaterial and tonumber(task.materialItemID) then
        return tonumber(task.materialItemID)
    end
    if task.done or type(task.text)~='string' then return nil end
    local name=task.text:match('^Verify %d+x (.-) %(')
        or task.text:match('^Obtain %d+x (.-) %(')
    if not name then return nil end
    for _,step in ipairs(plan.steps or {}) do
        if step.name==name then return step.itemID end
    end
    return nil
end

-- Called at render time, not persisted as task.done: getting materials is not
-- the same as actually crafting the item. Snapshot and priority awareness are
-- essential; the same resource cannot be declared ready for two queued crafts.
function AF:GetCraftingMaterialTaskStatus(project,task,plan)
    local id=self:CraftingChecklistItemID(project,task,plan)
    if not id then return nil end
    -- A finished crafting goal has consumed its materials. Queue evaluation
    -- therefore no longer contains reagent steps, but its structured auto-
    -- material tasks should not visually revert to unfinished. These are
    -- derived labels only; manually written tasks keep their own flags.
    if project.done and project.crafting and task.autoMaterial then
        local presentation=self:GetItemPresentation(id)
        local name=presentation and presentation.name or ('Item #'..tostring(id))
        local amount=type(task.text)=='string' and (task.text:match('^Verify (%d+)x ')
            or task.text:match('^Obtain (%d+)x ')) or nil
        local label=(amount and ('x'..amount..' ') or '')..name
        return '|cff20804b[x]|r '..label..' - goal completed; materials already used or confirmed', 'completed'
    end
    for _,step in ipairs(plan.steps or {}) do
        if step.itemID==id then
            local name=step.name or ('Item #'..tostring(id))
            local qty=step.needed or 0
            local label='x'..tostring(qty)..' '..name
            local bags=(((self.db.inventory or {})[project.owner] or {}).bags or {}).counts or {}
            local current=self.CurrentCharacter and self:CurrentCharacter()
            local currentBags=current and current.key==project.owner and (tonumber(bags[id]) or 0) or 0
            if step.missing==0 then
                if step.crafts and #step.crafts>0 then
                    return '|cff927331[~]|r '..label..' - ready after subcrafting', 'preparation'
                elseif currentBags>=qty then
                    return '|cff20804b[x]|r '..label..' - in current bags', 'inbags'
                else
                    return '|cff927331[~]|r '..label..' - recorded elsewhere; verify', 'recorded'
                end
            end
            local got=tonumber(step.covered) or 0
            if (step.priorityConflict or 0)>0 then
                return '[ ] '..label..' - stock allocated to higher craft', 'missing'
            end
            return '[ ] '..label..' - '..got..'/'..qty..' planned; need '..tostring(step.missing), 'missing'
        end
    end
    return nil
end


-- v0.7.3: real, user-clicked profession execution. Queue reservations are
-- VIRTUAL and may belong to other alts/banks; only the CURRENT character with
-- the matching OPEN profession and a learned recipe may send a cast request.
-- Each separate recipe requires another actual player click. Never chain
-- protected calls from timers, events, or OnUpdate.
local function LiveCall(fn,...)
    if type(fn)~='function' then return nil end
    local ok,result=pcall(fn,...)
    if ok then return result end
    return nil
end
-- Retail 12.1.5 removed the deprecated global GetItemCount. Both Retail
-- and Forever expose C_Item.GetItemCount(itemInfo, includeBank). Prefer it,
-- retaining the older global only as a compatibility fallback. Do not count
-- bank/reagent-bank/account-bank stock for a windowless craft request.
local function BagCountAPIName()
    if type(C_Item)=='table' and type(C_Item.GetItemCount)=='function' then
        return 'C_Item.GetItemCount'
    end
    if type(GetItemCount)=='function' then return 'GetItemCount (legacy)' end
    return 'unavailable'
end
local function CurrentBagItemCount(itemID)
    local count=nil
    if type(C_Item)=='table' and type(C_Item.GetItemCount)=='function' then
        count=LiveCall(C_Item.GetItemCount,itemID,false)
        if type(count)=='number' and count>=0 then return count end
    end
    if type(GetItemCount)=='function' then
        count=LiveCall(GetItemCount,itemID,false)
        if type(count)=='number' and count>=0 then return count end
    end
    return nil
end
local function IsRecipeInOpenList(api,recipeID)
    local ids=LiveCall(api.GetAllRecipeIDs)
    if type(ids)~='table' then return false end
    for _,id in ipairs(ids) do if tonumber(id)==recipeID then return true end end
    return false
end

-- Live profession state is authoritative for crafting. Saved recipe/snapshot
-- information is useful for selecting the right character and displaying the
-- plan, but cannot veto a native craft merely because reagent slots were not
-- captured (common on Retail-quality recipes and some Forever schematics).
local function CurrentProfessionMatches(opened,snapshot,craft)
    if type(opened)~='table' then return false end
    local id=tonumber(snapshot and snapshot.professionID) or tonumber(craft and craft.professionID)
    if not id then return false end
    return tonumber(opened.professionID)==id or tonumber(opened.parentProfessionID)==id
end

local function BagCraftableCount(detail)
    if type(detail)~='table' or detail.reagentsIncomplete or
        type(detail.reagents)~='table' or #detail.reagents==0 or
        BagCountAPIName()=='unavailable' then return nil end
    local byID={}
    for _,r in ipairs(detail.reagents) do
        local id,q=tonumber(r.itemID),tonumber(r.quantity)
        if not id or not q or id<1 or q<=0 then return nil end
        byID[id]=(byID[id] or 0)+q
    end
    local available=99
    for id,q in pairs(byID) do
        local count=CurrentBagItemCount(id)
        if type(count)~='number' then return nil end
        available=math.min(available,math.floor(count/q))
    end
    return math.max(0,available)
end

function AF:GetQueueCraftAction(project)
    local result={ready=false,canOpen=false,canCraftOne=false,canCraftAll=false,
        reason='Select a queued craft.',remaining=0,liveMax=0,recipeName='',professionName='',countSource='unavailable'}
    if not project or type(project.crafting)~='table' or project.done then return result end
    local craft=project.crafting
    local qty=math.max(1,math.min(99,math.floor(tonumber(craft.quantity) or 1)))
    local completed=math.max(0,math.floor(tonumber(craft.completed) or
        (project.guided and tonumber(project.guided.crafted)) or 0))
    result.remaining=math.max(0,qty-completed)
    if result.remaining==0 then result.reason='All planned crafts already recorded.';return result end
    if project.owner~=self:GetCurrentKey() then
        result.reason='This queue entry belongs to another character: '..self:CharacterLabel(project.owner)
        return result
    end
    local snapshot,stored=self:FindQueueRecipe(project)
    if not stored or not stored.learned then
        result.reason='Learned recipe not found in saved scans. Open its profession and rescan.';return result
    end
    local professionID=tonumber(snapshot.professionID) or tonumber(craft.professionID)
    local recipeID=tonumber(craft.recipeID)
    result.recipeName=stored.name or project.title or 'Recipe'
    result.professionName=snapshot.professionName or 'profession'
    local api=C_TradeSkillUI
    if type(api)~='table' then result.reason='C_TradeSkillUI not available on this client.';return result end
    result.canOpen=type(api.OpenTradeSkill)=='function' and professionID~=nil
    local opened=LiveCall(api.GetBaseProfessionInfo)
    local listMatch=recipeID and IsRecipeInOpenList(api,recipeID)
    -- Retail can expose an expansion-specific child SkillLineID, while the
    -- scanned snapshot was keyed to a parent ID. A recipe *confirmed in the
    -- live open profession list* is safer than comparing those IDs alone.
    if type(opened)~='table' or not (CurrentProfessionMatches(opened,snapshot,craft) or listMatch) then
        result.reason='Open '..result.professionName..' for the current character, then retry.'
        return result
    end
    if not recipeID or not listMatch then
        result.reason='The queued recipe is not in the open profession list. Select its expansion or rescan.'
        return result
    end
    local live=LiveCall(api.GetRecipeInfo,recipeID)
    if type(live)~='table' or live.learned~=true or live.disabled==true then
        result.reason='The game does not report this recipe as learned and enabled.';return result
    end
    if live.isRecraft or live.isEnchantingRecipe or live.isSalvageRecipe or live.isGatheringRecipe then
        result.reason='Special-target recipe: use the native profession UI for this craft.';return result
    end
    if live.craftable==false then
        result.reason=live.disabledReason or 'The game reports this recipe cannot currently be crafted.'
        return result
    end
    if type(api.CraftRecipe)~='function' then result.reason='CraftRecipe is unavailable.';return result end

    -- Native GetCraftableCount works on both Retail and Forever. It handles
    -- reagent variants that the saved snapshot cannot safely represent.
    local liveMax=LiveCall(api.GetCraftableCount,recipeID)
    if type(liveMax)=='number' and liveMax>=0 and liveMax==liveMax then
        result.liveMax=math.min(99,math.floor(liveMax))
        result.countSource='native'
        if result.liveMax<1 then
            result.reason='Game reports 0 craftable copies (check current bags, station and required reagents).'
            return result
        end
    else
        -- Fallback for client builds with no usable craftable count.
        local detail=self:GetRecipeDetails(snapshot,stored)
        local fromBags=BagCraftableCount(detail)
        if fromBags~=nil then
            result.liveMax=fromBags
            result.countSource='bag-check'
            if fromBags<1 then
                result.reason='Not enough reagents in current bags (based on recorded recipe requirements).'
                return result
            end
        else
            -- Single craft can still be attempted when the *live* recipe says
            -- craftable. Never issue an unbounded multi-craft request here.
            if live.craftable~=true then
                result.reason='Live craftable count and reagent details unavailable. Use the native profession UI.'
                return result
            end
            result.liveMax=1
            result.countSource='live-single'
        end
    end
    result.ready=true
    result.canCraftOne=true
    result.batchCount=math.min(result.remaining,result.liveMax)
    -- Craft All legitimately means 'craft everything currently possible',
    -- including when the queue only needs a single remaining craft.
    result.canCraftAll=live.canCreateMultiple~=false or result.batchCount==1
    if result.countSource=='live-single' then
        result.reason='Live recipe is craftable. Quantity unavailable; allowing one craft only.'
    else
        result.reason='Ready: '..result.batchCount..' craft(s), verified by '..result.countSource..'.'
        if result.batchCount<result.remaining then result.reason=result.reason..' Rest needs more reagents.' end
    end
    return result
end

local NativeQueueSchematicState
function AF:GetQueueCraftDiagnostic(project)
    local a=self:GetQueueCraftAction(project)
    local api=C_TradeSkillUI
    local craft=project and project.crafting or {}
    local recipeID=tonumber(craft.recipeID)
    local opened=type(api)=='table' and LiveCall(api.GetBaseProfessionInfo) or nil
    local live=type(api)=='table' and recipeID and LiveCall(api.GetRecipeInfo,recipeID) or nil
    local count=type(api)=='table' and recipeID and LiveCall(api.GetCraftableCount,recipeID) or nil
    local function word(v) if v==nil then return 'nil' end return tostring(v) end
    local registered,total=0,0
    for _,record in ipairs(self._queueCraftDiagnosticsRegistrations or {}) do
        total=total+1
        if record.ok then registered=registered+1 end
    end
    -- Preflight is diagnostic only. It does not establish that this client
    -- permits profession execution with the native window closed.
    local closedReady,closedReason=self:GetQueueWindowlessTestStatus(project)
    return {
        'Craft diagnosis: '..(a.reason or 'unknown'),
        'Owner match='..word(project and project.owner==self:GetCurrentKey())..' | recipe='..word(recipeID)..' | planned left='..word(a.remaining),
        'Open profession ID='..word(opened and opened.professionID)..' | parent='..word(opened and opened.parentProfessionID),
        'Active profession session='..word(self:IsQueueCraftSessionActive())..
            ' | native frame shown='..word(ProfessionsFrame and ProfessionsFrame.IsShown and ProfessionsFrame:IsShown())..
            ' | concealed='..word(self:IsQueueCompactNativeProfession()),
        'Recipe listed='..word(type(api)=='table' and recipeID and IsRecipeInOpenList(api,recipeID)),
        'Learned='..word(live and live.learned)..' | disabled='..word(live and live.disabled)..' | craftable='..word(live and live.craftable),
        'GetCraftableCount='..word(count)..' | available='..word(a.liveMax)..' | source='..word(a.countSource),
        'CraftRecipe API='..word(type(api)=='table' and type(api.CraftRecipe)=='function')..
            ' | diagnostic events='..tostring(registered)..'/'..tostring(total)..' registered',
        'Current-bag API='..BagCountAPIName()..' | windowless verification uses bags only',
        'Last attempt='..word(self.lastQueueCraftRequest and self.lastQueueCraftRequest.status)..
            ' | seconds ago='..word(self.lastQueueCraftRequest and math.max(0,Now()-(self.lastQueueCraftRequest.at or Now())))..
            ' | spell='..word(self.lastQueueCraftRequest and self.lastQueueCraftRequest.lastSpellID),
        'Last craft event='..word(self.lastQueueCraftRequest and self.lastQueueCraftRequest.lastEvent)..
            ' | UI error='..word(self.lastQueueCraftRequest and self.lastQueueCraftRequest.lastError),
        'Native selected recipe='..word(self.lastQueueCraftRequest and self.lastQueueCraftRequest.nativeSelectedRecipeID)..
            ' | native quantity set='..word(self.lastQueueCraftRequest and self.lastQueueCraftRequest.nativeQuantitySet),
        'Direct craft method='..word(self.lastQueueCraftRequest and self.lastQueueCraftRequest.method)..
            ' | allocated reagent entries='..word(self.lastQueueCraftRequest and self.lastQueueCraftRequest.reagentCount),
        'Native required basic slots='..word(self.lastQueueCraftRequest and self.lastQueueCraftRequest.requiredBasicSlots)..
            ' | reagent allocation ready='..word(recipeID and NativeQueueSchematicState and NativeQueueSchematicState(api,recipeID).ready),
        'Observed crafted result='..word(self.lastQueueCraftRequest and self.lastQueueCraftRequest.itemResult),
        'Closed-window preflight='..word(closedReady)..' | reason='..tostring(closedReason),
    }
end

-- v0.7.3.5: The Forever native Create button crafts through its selected
-- SchematicForm transaction. Direct CraftRecipe(recipeID,count) from our addon
-- returned silently without a cast on the verified live client, even though
-- the recipe and materials were craftable. Do not claim an execution request
-- was successful. Hand the selected recipe to Blizzard's native window and
-- require the user's own click on Blizzard Create/Create All. This preserves
-- hardware/untainted UI restrictions and current queue ownership semantics.
function AF:PrepareQueuedCraftInNativeUI(project,all)
    if project and project.owner==self:GetCurrentKey() then
        local eraReady,eraMessage=self:EnsureQueuedCraftEra(project)
        if not eraReady then return false,eraMessage end
    end
    local a=self:GetQueueCraftAction(project)
    if not a.canCraftOne or (all and not a.canCraftAll) then return false,a.reason end
    if InCombatLockdown and InCombatLockdown() then
        return false,'Crafting preparation unavailable in combat.'
    end
    local recipeID=tonumber(project and project.crafting and project.crafting.recipeID)
    local api=C_TradeSkillUI
    if not recipeID or type(api)~='table' or type(api.OpenRecipe)~='function' then
        return false,'This client has no native OpenRecipe action. Select the recipe manually in the profession window.'
    end
    local amount=all and math.max(1,math.min(99,math.floor(tonumber(a.batchCount) or 1))) or 1
    local name=a.recipeName or project.title or 'recipe'
    -- OpenRecipe changes selection only: it does NOT issue a crafting request.
    -- The native UI's Create button remains the player's hardware action.
    local ok,returned=pcall(api.OpenRecipe,recipeID)
    if not ok or returned==false then
        return false,'Could not select '..name..' in the native profession window: '..tostring(returned)
    end
    local selected=nil
    local page=ProfessionsFrame and ProfessionsFrame.CraftingPage
    local form=page and page.SchematicForm
    if form and type(form.GetRecipeInfo)=='function' then
        local got,info=pcall(form.GetRecipeInfo,form)
        if got and type(info)=='table' then selected=tonumber(info.recipeID) end
    end
    local confirmed=selected==recipeID
    local quantitySet=false
    -- Blizzard's recipe selection resets CreateMultipleInputBox to 1; the old
    -- Prepare Batch button only printed an instruction and never set it.
    -- Use the native widget's public SetValue after selecting the recipe.
    local numberBox=page and page.CreateMultipleInputBox
    if confirmed and all and numberBox and type(numberBox.SetValue)=='function' then
        local okSet=pcall(numberBox.SetValue,numberBox,amount)
        if okSet then
            if type(numberBox.GetValue)=='function' then
                local okValue,value=pcall(numberBox.GetValue,numberBox)
                quantitySet=okValue and tonumber(value)==amount
            else
                quantitySet=true
            end
        end
    end
    local request={projectID=project.id,recipeID=recipeID,amount=amount,at=Now(),
        status=confirmed and 'native_recipe_selected' or 'native_selection_requested',
        lastEvent=confirmed and 'Native schematic shows selected recipe' or 'Native OpenRecipe requested; verify schematic',
        nativeSelectedRecipeID=selected,nativeQuantitySet=quantitySet}
    self.lastQueueCraftRequest=request
    local instruction=all and (quantitySet and ('Native quantity set to '..amount..'. Click Blizzard Create All.')
            or ('Set the native quantity to '..amount..', then click Blizzard Create All.'))
        or 'Click Blizzard Create once.'
    local prefix=confirmed and ('Selected '..name..' in native professions.')
        or ('Requested '..name..' in native professions; verify the selected recipe.')
    return true,prefix..' '..instruction..' Only actual crafted-item results update the queue.'
end

-- Verify the selected transaction is actually prepared, not merely showing
-- the right recipe ID. Native recipe selection can update the displayed ID
-- before the schematic allocates its required basic reagents. Retail and
-- Forever both expose GetRecipeSchematic; slot fields may vary by build.
NativeQueueSchematicState=function(api,recipeID)
    local page=ProfessionsFrame and ProfessionsFrame.CraftingPage
    local form=page and page.SchematicForm
    local selected=nil
    if form and type(form.GetRecipeInfo)=='function' then
        local ok,info=pcall(form.GetRecipeInfo,form)
        if ok and type(info)=='table' then selected=tonumber(info.recipeID) end
    end
    local tx=form and form.transaction
    if form and type(form.GetTransaction)=='function' then
        local ok,got=pcall(form.GetTransaction,form)
        if ok and got then tx=got end
    end
    local reagents=nil
    if tx and type(tx.CreateCraftingReagentInfoTbl)=='function' then
        local ok,data=pcall(tx.CreateCraftingReagentInfoTbl,tx)
        if ok and type(data)=='table' then reagents=data end
    end
    local basicRequired=0
    if type(api)=='table' and type(api.GetRecipeSchematic)=='function' then
        local ok,schematic=pcall(api.GetRecipeSchematic,recipeID,false)
        if ok and type(schematic)=='table' then
            local basic=Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic or 1
            for _,slot in ipairs(schematic.reagentSlotSchematics or {}) do
                if (slot.reagentType==basic or slot.reagentType==nil) and
                    (tonumber(slot.quantityRequired) or 0)>0 and
                    type(slot.reagents)=='table' and #slot.reagents>0 then
                    basicRequired=basicRequired+1
                end
            end
        end
    end
    local ready=selected==recipeID and type(reagents)=='table' and
        not (basicRequired>0 and #reagents==0)
    return {page=page,form=form,transaction=tx,recipeID=selected,
        reagents=reagents,basicRequired=basicRequired,ready=ready}
end

local function TryAllocateNativeQueueBasics(state)
    if not state or state.basicRequired<1 or not state.transaction or
        type(state.reagents)~='table' or #state.reagents>0 then return false end
    if not Professions or type(Professions.AllocateAllBasicReagents)~='function' then return false end
    local best=false
    if type(Professions.ShouldAllocateBestQualityReagents)=='function' then
        local ok,v=pcall(Professions.ShouldAllocateBestQualityReagents,false)
        if ok then best=v and true or false end
    end
    return pcall(Professions.AllocateAllBasicReagents,state.transaction,best)
end

-- Use Blizzard's real crafting page recipe selection when possible. Retail's
-- own recipe list calls this method, which rebuilds the schematic transaction;
-- OpenRecipe alone may leave an uninitialized form even with a matching ID.
local function SelectNativeQueueRecipe(api,recipeID)
    local page=ProfessionsFrame and ProfessionsFrame.CraftingPage
    if page and type(page.SelectRecipe)=='function' and
        type(api.GetRecipeInfo)=='function' then
        local okInfo,info=pcall(api.GetRecipeInfo,recipeID)
        if okInfo and type(info)=='table' and tonumber(info.recipeID or recipeID)==recipeID then
            local ok=pcall(page.SelectRecipe,page,info)
            if ok then return true,'native-page' end
        end
    end
    if type(api.OpenRecipe)=='function' then
        local ok,v=pcall(api.OpenRecipe,recipeID)
        if ok and v~=false then return true,'OpenRecipe' end
    end
    return false,'unavailable'
end

-- v0.7.3.10: Standalone, recipe-specific allocation. The selected
-- ProfessionsFrame transaction can be empty after OpenRecipe/SelectRecipe even
-- if the recipe ID is correct (confirmed in live Retail diagnostics). Skillet
-- constructs a transaction from GetRecipeSchematic instead. Never borrow
-- reagent allocations from a *different* recipe or infer optional reagents.
local function QueueSchematicBasicSlots(schematic)
    local slots={}
    local basicType=Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic or 1
    for index,slot in ipairs(schematic.reagentSlotSchematics or {}) do
        local quantity=tonumber(slot.quantityRequired) or 0
        local basic=slot.reagentType==basicType or slot.reagentType==nil
        if basic and quantity>0 then
            local dataIndex=tonumber(slot.dataSlotIndex or slot.slotIndex or index)
            if not dataIndex then return nil,'A basic reagent has no usable slot index.' end
            slots[#slots+1]={index=dataIndex,quantity=quantity,choices=slot.reagents or {}}
        elseif quantity>0 and (slot.required or slot.reagentType~=nil and slot.reagentType~=basicType) then
            -- E.g. required modifying/finishing slots cannot be guessed.
            return nil,'Recipe needs a non-basic reagent selection.'
        end
    end
    return slots
end

local function QueueAllocationCoversBasics(reagents,slots)
    if type(reagents)~='table' then return false end
    local bySlot={}
    for _,r in ipairs(reagents) do
        local index=tonumber(r.dataSlotIndex)
        local count=tonumber(r.quantity)
        if index and count and count>0 then
            bySlot[index]=(bySlot[index] or 0)+count
        end
    end
    for _,slot in ipairs(slots) do
        if (bySlot[slot.index] or 0)<slot.quantity then return false end
    end
    return true
end

-- Returns reagent table, source label, or nil and reason. This does not open
-- or mutate Blizzard's native profession form, and it never initiates a cast.
local function MakeQueueRecipeReagents(api,recipeID,craftCount)
    if not api or type(api.GetRecipeSchematic)~='function' then
        return nil,'This client does not expose recipe schematic data.'
    end
    local schematic=LiveCall(api.GetRecipeSchematic,recipeID,false)
    if type(schematic)~='table' or
        (schematic.recipeID and tonumber(schematic.recipeID)~=recipeID) then
        return nil,'Recipe schematic is not available for this queued recipe.'
    end
    local slots,reason=QueueSchematicBasicSlots(schematic)
    if not slots then return nil,reason end
    if #slots==0 then
        return {},'schematic-no-basic'
    end
    -- Prefer Blizzard's allocation implementation so Retail reagent qualities
    -- are selected exactly the way its own transaction code does.
    if type(CreateProfessionsRecipeTransaction)=='function' then
        local ok,transaction=pcall(CreateProfessionsRecipeTransaction,schematic)
        if ok and transaction and type(transaction.CreateCraftingReagentInfoTbl)=='function' then
            if Professions and type(Professions.AllocateAllBasicReagents)=='function' then
                local preferBest=false
                if type(Professions.ShouldAllocateBestQualityReagents)=='function' then
                    local succeeded,result=pcall(Professions.ShouldAllocateBestQualityReagents,false)
                    if succeeded then preferBest=result and true or false end
                end
                pcall(Professions.AllocateAllBasicReagents,transaction,preferBest)
            end
            local got,allocated=pcall(transaction.CreateCraftingReagentInfoTbl,transaction)
            if got and QueueAllocationCoversBasics(allocated,slots) then
                -- Some clients expose HasMetQuantityRequirements. A false
                -- result must not be sent as a craft request.
                local valid=true
                if type(transaction.HasMetQuantityRequirements)=='function' then
                    local checked,met=pcall(transaction.HasMetQuantityRequirements,transaction)
                    if checked and met==false then valid=false end
                end
                if valid then return allocated,'standalone-transaction' end
            end
        end
    end
    -- Conservative fallback for unambiguous, fixed single-item basic slots.
    -- Does not arbitrarily choose amongst multiple quality reagent choices.
    local explicit={}
    local needs={}
    for _,slot in ipairs(slots) do
        if #slot.choices~=1 or type(slot.choices[1])~='table' then
            return nil,'A reagent slot has several possible items; native selection is required.'
        end
        local reagent=slot.choices[1]
        local itemID=tonumber(reagent.itemID)
        if not itemID or itemID<1 then
            return nil,'A required slot does not contain a known reagent item.'
        end
        needs[itemID]=(needs[itemID] or 0)+slot.quantity
        explicit[#explicit+1]={reagent={itemID=itemID},dataSlotIndex=slot.index,quantity=slot.quantity}
    end
    -- The native craftability check already guards available quantity, but
    -- when accessible also require enough CURRENT-BAG stock for the batch.
    if BagCountAPIName()~='unavailable' then
        for itemID,quantity in pairs(needs) do
            local count=CurrentBagItemCount(itemID)
            if type(count)=='number' and count < quantity*craftCount then
                return nil,'Not enough of reagent item '..itemID..' in current bags for the batch.'
            end
        end
    end
    return explicit,'fixed-basic-schematic'
end

function AF:TryQueuedCraftFromSchematic(project,all)
    local a=self:GetQueueCraftAction(project)
    if not a.canCraftOne or (all and not a.canCraftAll) then
        return false,a.reason
    end
    if InCombatLockdown and InCombatLockdown() then
        return false,'Crafting cannot be initiated in combat.'
    end
    local id=tonumber(project and project.crafting and project.crafting.recipeID)
    local amount=all and math.max(1,math.min(99,math.floor(tonumber(a.batchCount) or 1))) or 1
    local api=C_TradeSkillUI
    if not id or type(api)~='table' or type(api.CraftRecipe)~='function' then
        return false,'Crafting API unavailable.'
    end
    local reagents,source=MakeQueueRecipeReagents(api,id,amount)
    if not reagents then return false,source end
    local request={projectID=project.id,recipeID=id,amount=amount,at=Now(),
        status='request_sent',lastEvent='Standalone schematic craft requested; not yet confirmed',
        nativeSelectedRecipeID=nil,reagentCount=#reagents,requiredBasicSlots=nil,
        method=source}
    self.lastQueueCraftRequest=request
    local ok,err=pcall(api.CraftRecipe,id,amount,reagents)
    if not ok then
        request.status='rejected';request.lastError=tostring(err)
        return false,'Crafting API rejected standalone allocation: '..tostring(err)
    end
    return true,'Requested '..amount..'x '..(a.recipeName or 'recipe')..' using '..source..'. Awaiting the actual craft result.'
end

-- v0.7.3.11: One-click experimental check of whether the *profession window*
-- is required on this particular client/build. The v0.7.3.10 standalone
-- reagent transaction already works with a profession open; do not change
-- the proven normal Craft 1 / Craft All path until a real closed-window
-- result has been observed. Explicitly user-clicked, one craft only.
function AF:GetQueueWindowlessTestStatus(project)
    if type(project)~='table' or type(project.crafting)~='table' or project.done then
        return false,'Select an unfinished queued craft.'
    end
    if project.owner~=self:GetCurrentKey() then
        return false,'Queue item belongs to another character.'
    end
    local craft=project.crafting
    local remaining=math.floor(tonumber(craft.quantity) or 0)-math.floor(tonumber(craft.completed) or 0)
    if remaining<1 then return false,'Queue item already completed.' end
    local saved,stored=self:FindQueueRecipe(project)
    if not saved or not stored or stored.learned~=true then
        return false,'A learned recipe scan for this crafter is required.'
    end
    local api=C_TradeSkillUI
    if type(api)~='table' or type(api.CraftRecipe)~='function' or
        type(api.GetRecipeSchematic)~='function' then
        return false,'Client lacks recipe schematic / crafting API.'
    end
    if BagCountAPIName()=='unavailable' then
        return false,'Client exposes neither C_Item.GetItemCount nor legacy GetItemCount.'
    end
    return true,'Window-closed one-craft test available.'
end

function AF:TryQueuedCraftWindowlessTest(project)
    local eligible,reason=self:GetQueueWindowlessTestStatus(project)
    if not eligible then return false,reason end
    if InCombatLockdown and InCombatLockdown() then
        return false,'Unavailable in combat.'
    end
    local api=C_TradeSkillUI
    if type(api.IsTradeSkillReady)=='function' and LiveCall(api.IsTradeSkillReady)==true then
        return false,'Close the native profession window before testing this button.'
    end
    local id=tonumber(project.crafting.recipeID)
    if not id then return false,'Queued recipe has no usable recipe ID.' end
    local schematic=LiveCall(api.GetRecipeSchematic,id,false)
    if type(schematic)~='table' then
        return false,'The client does not expose this recipe schematic with professions closed.'
    end
    local itemType=Enum and Enum.TradeskillRecipeType and Enum.TradeskillRecipeType.Item
    if schematic.isRecraft or (itemType and schematic.recipeType and schematic.recipeType~=itemType) then
        return false,'Only ordinary item recipes can be tested without a profession window.'
    end
    local info=LiveCall(api.GetRecipeInfo,id)
    if type(info)=='table' then
        if info.learned==false or info.disabled==true or info.isRecraft or
            info.isEnchantingRecipe or info.isSalvageRecipe or info.isGatheringRecipe then
            return false,'The live client does not confirm a usable ordinary learned recipe.'
        end
    end
    local reagents,method=MakeQueueRecipeReagents(api,id,1)
    if not reagents then return false,'Cannot safely allocate this recipe: '..tostring(method) end
    -- The native craftability count may be zero/unavailable when the window
    -- is closed. Never use it as an approval here; require real current-bag
    -- quantities for every ingredient in this single-craft transaction.
    local needed={}
    for _,entry in ipairs(reagents) do
        local itemID=entry and entry.reagent and tonumber(entry.reagent.itemID)
        local qty=entry and tonumber(entry.quantity)
        if not itemID or itemID<1 or not qty or qty<1 then
            return false,'Reagent selection cannot be verified from current bags.'
        end
        needed[itemID]=(needed[itemID] or 0)+qty
    end
    for itemID,amount in pairs(needed) do
        local bagCount=CurrentBagItemCount(itemID)
        if type(bagCount)~='number' then
            return false,'The current-bag count for reagent '..itemID..' could not be read.'
        end
        if bagCount<amount then
            return false,'Not enough current-bag reagents for item '..itemID..' (need '
                ..amount..', have '..math.floor(bagCount)..').'
        end
    end
    local request={projectID=project.id,recipeID=id,amount=1,at=Now(),
        status='request_sent',method='window-closed-test/'..tostring(method),
        reagentCount=#reagents,lastEvent='Window-closed craft request; NOT yet confirmed'}
    self.lastQueueCraftRequest=request
    local ok,returned=pcall(api.CraftRecipe,id,1,reagents)
    if not ok or returned==false then
        request.status='rejected'
        request.lastError=not ok and tostring(returned) or 'CraftRecipe returned false'
        return false,'Client rejected the closed-window craft request: '..request.lastError
    end
    return true,'Test sent: 1x '..(project.title or 'queued craft')..' with native profession closed. Verify actual item creation and queue progress; an error-free call alone is NOT confirmation.'
end

-- v0.7.3.16: keep the active profession session, but conceal its full-size
-- Blizzard frame instead of scaling it to 2%. Scaling caused a visible flash
-- when Retail re-laid out its profession/crafting result frames. Cloaking does
-- NOT call Hide() or CloseTradeSkill(): those would invalidate the context that
-- the proven reagent-aware CraftRecipe needs. Restore exact visual and mouse
-- states when requested, navigating out of Crafting Queue, or closing Foundry.
-- No saved setting or change to user data. Does not cloak Crafting Results.
local compactNativeProfession={frame=nil,alpha=nil,mouseStates=nil,
    pendingRestore=false,pendingClose=false,openedByFoundry=false}
local function nativeMouseDescendants(root,states)
    local pending={root}
    local seen={}
    while #pending>0 do
        local node=table.remove(pending)
        if node and not seen[node] then
            seen[node]=true
            if type(node.IsMouseEnabled)=='function' and type(node.EnableMouse)=='function' then
                local ok,value=pcall(node.IsMouseEnabled,node)
                if ok and type(value)=='boolean' then
                    -- Store original state even for disabled widgets, to
                    -- restore precisely rather than blindly enabling input.
                    states[#states+1]={node,value}
                    if value then pcall(node.EnableMouse,node,false) end
                end
            end
            if type(node.GetChildren)=='function' then
                local ok,children=pcall(function() return {node:GetChildren()} end)
                if ok and type(children)=='table' then
                    for _,child in ipairs(children) do pending[#pending+1]=child end
                end
            end
        end
    end
end
function AF:IsQueueCompactNativeProfession()
    return compactNativeProfession.frame~=nil
end
function AF:MaintainQueueCompactNativeProfession()
    local state=compactNativeProfession
    local frame=state.frame
    if not frame or type(frame.SetAlpha)~='function' then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    -- Leave the frame shown: it holds the profession data and transaction.
    -- Even after results/UI transitions re-show it, force it to stay invisible.
    if frame.IsShown and not frame:IsShown() then return false end
    local ok=pcall(frame.SetAlpha,frame,0)
    if not ok then return false end
    for _,entry in ipairs(state.mouseStates or {}) do
        local node=entry[1]
        if node and type(node.EnableMouse)=='function' then
            pcall(node.EnableMouse,node,false)
        end
    end
    return true
end
function AF:RestoreQueueNativeProfession()
    local state=compactNativeProfession
    if not state.frame then return false,'Native profession window is not concealed.' end
    if InCombatLockdown and InCombatLockdown() then
        state.pendingRestore=true
        return false,'Will restore the native profession window automatically after combat.'
    end
    local frame,alpha,states=state.frame,state.alpha,state.mouseStates
    -- Restore even if one child throws: one bad Blizzard control must never
    -- strand the entire profession window invisible.
    local ok,err=true,nil
    if type(frame.SetAlpha)=='function' then ok,err=pcall(frame.SetAlpha,frame,alpha or 1) end
    for _,entry in ipairs(states or {}) do
        local node,enabled=entry[1],entry[2]
        if node and type(node.EnableMouse)=='function' then pcall(node.EnableMouse,node,enabled) end
    end
    state.frame=nil;state.alpha=nil;state.mouseStates=nil
    state.pendingRestore=false;state.pendingClose=false;state.openedByFoundry=false
    if not ok then return false,'Could not restore the native frame opacity: '..tostring(err) end
    return true,'Blizzard profession window restored.'
end

-- Foundry may conceal either a window the player opened themselves or a
-- profession session that a Craft button opened automatically. When the
-- journal closes, don't reveal a window that Foundry opened behind the scenes.
-- End only Foundry-owned sessions; player-opened windows are restored exactly.
function AF:ReleaseQueueNativeProfession()
    local state=compactNativeProfession
    if not state.frame then return false,'No concealed native profession.' end
    if not state.openedByFoundry then return self:RestoreQueueNativeProfession() end
    if InCombatLockdown and InCombatLockdown() then
        state.pendingClose=true
        state.pendingRestore=false
        return false,'Will close the automatically opened profession after combat.'
    end
    local frame=state.frame
    local api=C_TradeSkillUI
    -- Both Retail and Forever expose this native closure. Close while the
    -- Blizzard frame is still invisible, avoiding a visible reappearance.
    if api and type(api.CloseTradeSkill)=='function' then
        pcall(api.CloseTradeSkill)
    end
    local function stillShown()
        if not frame or type(frame.IsShown)~='function' then return false end
        local ok,shown=pcall(frame.IsShown,frame)
        return ok and shown or false
    end
    -- Some clients close the trade-skill session without hiding the top-level
    -- panel immediately. Finish closing the visual panel BEFORE restoring alpha.
    if stillShown() and type(HideUIPanel)=='function' then
        pcall(HideUIPanel,frame)
    end
    if stillShown() and type(frame.Hide)=='function' then
        pcall(frame.Hide,frame)
    end
    if stillShown() then
        -- Don't show a formerly hidden native frame if closure was refused.
        -- Keep the original state so Open Profession can still reveal it later.
        return false,'Native profession could not be closed; it remains concealed.'
    end
    self:RestoreQueueNativeProfession()
    return true,'Foundry-opened native profession closed without revealing its window.'
end
function AF:HideQueueNativeProfession(allowOpening)
    if self:IsQueueCompactNativeProfession() then
        self:MaintainQueueCompactNativeProfession()
        return true,'Native profession already concealed.'
    end
    if InCombatLockdown and InCombatLockdown() then
        return false,'Cannot conceal the profession window during combat.'
    end
    local frame=ProfessionsFrame
    if not frame or type(frame.IsShown)~='function' or
        (not frame:IsShown() and not allowOpening) then
        return false,'Open the profession first. Concealing it keeps the profession session open.'
    end
    -- Arm opacity before a user-clicked OpenTradeSkill call when Blizzard's
    -- frame exists but has not appeared yet. This prevents the full-size
    -- frame flashing during first-open on Retail. The saved alpha/mouse state
    -- is restored on failure, on Show Native, or when leaving the queue.
    if type(frame.GetAlpha)~='function' or type(frame.SetAlpha)~='function' then
        return false,'This client does not expose safe opacity controls for the profession window.'
    end
    local original=frame:GetAlpha()
    if type(original)~='number' then return false,'Cannot read native profession opacity.' end
    -- Set alpha first. If rejected, do not touch Blizzard mouse settings.
    local ok,err=pcall(frame.SetAlpha,frame,0)
    if not ok then return false,'Client rejected profession concealment: '..tostring(err) end
    local states={}
    nativeMouseDescendants(frame,states)
    compactNativeProfession.frame=frame
    compactNativeProfession.alpha=original
    compactNativeProfession.mouseStates=states
    compactNativeProfession.pendingRestore=false
    compactNativeProfession.pendingClose=false
    compactNativeProfession.openedByFoundry=false
    if frame.HookScript and not frame.afFoundryConcealShowHook then
        frame.afFoundryConcealShowHook=true
        frame:HookScript('OnShow',function()
            if AF and AF.MaintainQueueCompactNativeProfession then
                AF:MaintainQueueCompactNativeProfession()
            end
        end)
    end
    return true,'Native profession concealed but still open for crafting. Use Show Native or leave Crafting Queue to restore it.'
end
function AF:RestoreQueuedNativeProfessionAfterCombat()
    if compactNativeProfession.pendingClose and self:IsQueueCompactNativeProfession() then
        return self:ReleaseQueueNativeProfession()
    end
    if compactNativeProfession.pendingRestore and self:IsQueueCompactNativeProfession() then
        return self:RestoreQueueNativeProfession()
    end
    return false
end
function AF:ToggleQueueCompactNativeProfession()
    if self:IsQueueCompactNativeProfession() then return self:RestoreQueueNativeProfession() end
    return self:HideQueueNativeProfession()
end

-- Retail professions are split into expansion/era skill lines, for example
-- Classic Tailoring versus Cataclysm Tailoring. Resolve by queued RECIPE,
-- never by the last/default era selected in Blizzard's profession window.
-- Forever may report no child skill line; in that case no era switching occurs.
function AF:GetQueuedCraftEra(project)
    local api=C_TradeSkillUI
    local recipeID=tonumber(project and project.crafting and project.crafting.recipeID)
    if not recipeID or type(api)~='table' or
        type(api.GetTradeSkillLineForRecipe)~='function' then return nil,nil,nil end
    local ok,child,name,parent=pcall(api.GetTradeSkillLineForRecipe,recipeID)
    if not ok then return nil,nil,nil end
    child,parent=tonumber(child),tonumber(parent)
    if not child or child<1 or not parent or parent<1 or child==parent then
        return nil,nil,nil
    end
    return child,name,parent
end
function AF:EnsureQueuedCraftEra(project)
    local api=C_TradeSkillUI
    local child,name,parent=self:GetQueuedCraftEra(project)
    if not child then return true,nil end
    if type(api.GetTradeSkillLine)~='function' then return true,nil end
    local current=tonumber(LiveCall(api.GetTradeSkillLine))
    if current==child then return true,nil end
    local opened=LiveCall(api.GetBaseProfessionInfo)
    local base=tonumber(opened and opened.professionID)
    local openParent=tonumber(opened and opened.parentProfessionID)
    if not (parent==base or parent==openParent) then
        -- Opening the correct parent profession is handled by the existing
        -- crafting path. Don't switch an unrelated open profession's era.
        return true,nil
    end
    if type(api.SetProfessionChildSkillLineID)~='function' then
        return false,'This client does not expose automatic profession-era selection. Choose '..tostring(name or 'the recipe era')..' in the native profession window.'
    end
    if InCombatLockdown and InCombatLockdown() then
        return false,'Cannot change profession era during combat.'
    end
    local ok,err=pcall(api.SetProfessionChildSkillLineID,child)
    if not ok then return false,'Could not select the queued recipe era: '..tostring(err) end
    local after=tonumber(LiveCall(api.GetTradeSkillLine))
    if after~=child then
        return false,'Selected '..tostring(name or ('skill line '..child))..'. Wait for Retail to load this recipe era, then click Craft again.'
    end
    return true,'Selected '..tostring(name or ('skill line '..child))
end

-- v0.7.3.7: reagent-aware direct crafting was observed WORKING in Forever:
-- a user-initiated request produced 1 Bolt of Linen Cloth, followed by a
-- four-item batch in-game. Retain the tested transaction path exactly.
-- Skillet and Blizzard use a
-- fully prepared recipe transaction for modern crafting. Try that same
-- transaction in response to the user's real click. Never auto-start another
-- recipe from an event, timer, or queue progression, and NEVER mark the item
-- completed merely because this call returned without an error.
-- This is deliberately a separate action from the working native handoff.
function AF:TryQueuedCraftInWindow(project,all)
    local action=self:GetQueueCraftAction(project)
    if not action.canCraftOne or (all and not action.canCraftAll) then
        return false,action.reason
    end
    if InCombatLockdown and InCombatLockdown() then
        return false,'Crafting cannot be initiated in combat.'
    end
    local id=tonumber(project and project.crafting and project.crafting.recipeID)
    local amount=all and math.max(1,math.min(99,math.floor(tonumber(action.batchCount) or 1))) or 1
    local api=C_TradeSkillUI
    if type(api)~='table' or type(api.CraftRecipe)~='function' then
        return false,'This client does not expose CraftRecipe.'
    end
    local page=ProfessionsFrame and ProfessionsFrame.CraftingPage
    local form=page and page.SchematicForm
    local chosen=nil
    if form and type(form.GetRecipeInfo)=='function' then
        local okInfo,info=pcall(form.GetRecipeInfo,form)
        if okInfo and type(info)=='table' then chosen=tonumber(info.recipeID) end
    end
    -- Do not borrow another recipe's allocations. Prepare 1/Batch selects the
    -- correct schematic first, then the in-window Craft buttons may use it.
    if chosen~=id then
        return false,'Click Select Recipe for this queue entry, then click Craft 1 or Craft All.'
    end
    local transaction=form and form.transaction
    if form and type(form.GetTransaction)=='function' then
        local okTxn,got=pcall(form.GetTransaction,form)
        if okTxn and got then transaction=got end
    end
    if not transaction or type(transaction.CreateCraftingReagentInfoTbl)~='function' then
        return false,'Native schematic allocation was not available. Use Blizzard Create as fallback.'
    end
    local okInfo,reagents=pcall(transaction.CreateCraftingReagentInfoTbl,transaction)
    if not okInfo or type(reagents)~='table' then
        return false,'Unable to read the native reagent allocation. Use Blizzard Create.'
    end
    local state=NativeQueueSchematicState(api,id)
    if state.basicRequired>0 and #reagents==0 then
        -- Avoid another silent request when a newly selected recipe displays
        -- correctly but its native transaction has no required allocations.
        TryAllocateNativeQueueBasics(state)
        state=NativeQueueSchematicState(api,id)
        if not state.ready then
            self.lastQueueCraftRequest={projectID=project.id,recipeID=id,at=Now(),
                status='schematic_not_ready',lastEvent='Native reagent allocation incomplete; craft NOT sent',
                nativeSelectedRecipeID=state.recipeID,reagentCount=state.reagents and #state.reagents or nil,
                requiredBasicSlots=state.basicRequired}
            return false,'Recipe selected, but its required reagent allocation is not ready. '
                ..'Click Craft again after the native schematic initializes, or use Select Recipe.'
        end
        reagents=state.reagents
    end
    local request={projectID=project.id,recipeID=id,amount=amount,at=Now(),
        status='request_sent',lastEvent='Native-allocated CraftRecipe attempted; not confirmed',
        nativeSelectedRecipeID=chosen,reagentCount=#reagents,requiredBasicSlots=state.basicRequired,method='reagent-aware CraftRecipe'}
    self.lastQueueCraftRequest=request
    -- The click sends a SINGLE batch request for the selected recipe. This
    -- may still be refused by Forever's taint/protected-action system.
    local ok,err=pcall(api.CraftRecipe,id,amount,reagents)
    if not ok then
        request.status='rejected';request.lastError=tostring(err)
        return false,'Craft API rejected the request: '..tostring(err)
    end
    return true,'Requested '..amount..'x '..(action.recipeName or 'recipe')..' using native reagent allocation; waiting for a game-observed result. If none, use /af craftstatus or native Create.'
end

-- Backwards-compatible name for any existing caller; it prepares the native UI
-- rather than issuing the client-rejected crafting call. Never mark as crafted.
function AF:StartQueuedCraft(project,all)
    return self:PrepareQueuedCraftInNativeUI(project,all)
end

-- Observer for player-visible outcomes. Only a real click issues CraftRecipe;
-- these event handlers never craft and never mark a queue item as completed.
-- Not all Forever and Retail builds expose every optional event, so the
-- diagnosis is deliberately evidence-based rather than treating a silent
-- client as a proved failure.
function AF:ObserveQueueCraftSignal(event,...)
    local r=self.lastQueueCraftRequest
    if not r or not event then return end
    if r.status=='crafted' and event~='TRADE_SKILL_ITEM_CRAFTED_RESULT' then return end
    local age=Now()-(tonumber(r.at) or Now())
    if age<0 or age>90 then return end
    if event=='UNIT_SPELLCAST_START' or event=='UNIT_SPELLCAST_SENT' or
        event=='UNIT_SPELLCAST_SUCCEEDED' or event=='UNIT_SPELLCAST_FAILED' or
        event=='UNIT_SPELLCAST_INTERRUPTED' then
        local unit,castGUID,spellID=...
        if unit~='player' then return end
        local number=tonumber(spellID)
        -- An unrelated player spell should not confirm the queue request.
        if not number or number~=tonumber(r.recipeID) then return end
        r.lastSpellID=number
        r.lastEvent=event
        if event=='UNIT_SPELLCAST_FAILED' or event=='UNIT_SPELLCAST_INTERRUPTED' then
            r.status='cast_failed'
        elseif event=='UNIT_SPELLCAST_SUCCEEDED' then
            r.status='spell_succeeded' -- still awaiting an output result
        else
            r.status='cast_started'
        end
    elseif event=='TRADE_SKILL_CRAFT_BEGIN' then
        if age>15 then return end
        r.status='craft_started';r.lastEvent=event
    elseif event=='UPDATE_TRADESKILL_CAST_COMPLETE' then
        if age>60 then return end
        r.status='cast_complete';r.lastEvent=event
    elseif event=='UPDATE_TRADESKILL_CAST_STOPPED' then
        if age>60 then return end
        r.status='cast_stopped';r.lastEvent=event
    elseif event=='UI_ERROR_MESSAGE' then
        if age>8 or r.status=='crafted' then return end
        local _,message=...
        if type(message)=='string' and message~='' then
            r.lastError=message;r.lastEvent=event
            if r.status=='request_sent' then r.status='client_error' end
        end
    elseif event=='ADDON_ACTION_BLOCKED' or event=='ADDON_ACTION_FORBIDDEN' then
        local addon,action=...
        local text=type(action)=='string' and action or ''
        local owner=type(addon)=='string' and addon or ''
        if age<=8 and (owner:find('AzerothFoundry',1,true) or text:find('CraftRecipe',1,true)) then
            r.status='blocked';r.lastEvent=event;r.lastError=owner..': '..text
        end
    elseif event=='TRADE_SKILL_ITEM_CRAFTED_RESULT' then
        local info=...
        if type(info)=='table' then
            r.itemResult='item='..tostring(info.itemID)..' x'..tostring(info.quantity)
            r.lastEvent=event
        end
    end
end
function AF:ObserveQueueCraftItemCredit(credited)
    local r=self.lastQueueCraftRequest
    if not r or not credited or self.lastQueueCraftCreditProjectID~=r.projectID or Now()-(r.at or Now())>90 then return end
    r.status='crafted';r.lastEvent='TRADE_SKILL_ITEM_CRAFTED_RESULT (credited)'
end
function AF:GetQueueCraftRequestMessage(project)
    local r=self.lastQueueCraftRequest
    if not r or not project or r.projectID~=project.id then return nil end
    local status=r.status or 'unknown'
    if status=='request_sent' then
        local age=math.max(0,Now()-(r.at or Now()))
        return (age>=5 and 'Craft NOT confirmed after '..age..'s; check /af craftstatus or try native Create.'
            or 'Craft request sent; awaiting a game cast or crafted-item event.')
    end
    local labels={native_recipe_selected='Recipe selected in native professions; click Blizzard Create.',
        native_selection_requested='Recipe selection requested; verify native professions and click Blizzard Create.',
        cast_started='Player cast started (not yet crafted).',
        craft_started='Profession crafting began (waiting for item result).',
        spell_succeeded='Spell succeeded; waiting for crafted-item result.',
        cast_complete='Profession cast completed; waiting for crafted-item result.',
        cast_stopped='Profession cast stopped; item result not confirmed.',
        crafted='Crafted item result confirmed and credited to queue.',
        cast_failed='Player cast failed or was interrupted.',
        blocked='WoW blocked the crafting action.',
        client_error='Possible game error during craft request: '..tostring(r.lastError),
        rejected='Craft API call rejected: '..tostring(r.lastError)}
    return labels[status] or ('Craft request state: '..status)
end

function AF:OpenQueuedCraftProfession(project,conceal)
    local a=self:GetQueueCraftAction(project)
    if not a.canOpen then return false,a.reason end
    if InCombatLockdown and InCombatLockdown() then return false,'Unavailable in combat.' end
    local snapshot=self:FindQueueRecipe(project)
    local id=snapshot and tonumber(snapshot.professionID) or tonumber(project.crafting.professionID)
    local wasCloaked=self:IsQueueCompactNativeProfession()
    local wasShown=ProfessionsFrame and type(ProfessionsFrame.IsShown)=='function'
        and ProfessionsFrame:IsShown() or false
    -- Craft buttons: keep Blizzard's profession context alive, but conceal
    -- its frame BEFORE requesting the open so it need not visibly pop up.
    -- This is only a visual preparation, never an asynchronous craft action.
    if conceal and not wasCloaked and ProfessionsFrame then
        self:HideQueueNativeProfession(true)
    end
    local ok,result=pcall(C_TradeSkillUI.OpenTradeSkill,id)
    if not ok or result==false then
        if conceal and not wasCloaked and self:IsQueueCompactNativeProfession() then
            self:RestoreQueueNativeProfession()
        end
        return false,'Unable to open the profession automatically; use Open Profession or your spellbook.'
    end
    if conceal then
        -- Some clients initialize ProfessionsFrame as part of OpenTradeSkill.
        -- Conceal that newly created frame in the same player-click callback.
        if not self:IsQueueCompactNativeProfession() then self:HideQueueNativeProfession() end
        -- Ownership is assigned only when a Craft action opened a session that
        -- wasn't already shown; a player's own open window must be preserved.
        if not wasShown and self:IsQueueCompactNativeProfession() then
            compactNativeProfession.openedByFoundry=true
        end
        return true,'Preparing '..(a.professionName or 'profession')..' quietly. Click Craft again only if its recipe list is still loading.'
    end
    return true,'Opened '..(a.professionName or 'profession')..' in Blizzard UI.'
end

-- User-requested escape hatch: the Open Profession button always reveals
-- Blizzard's interface. It never starts a craft or changes the queue.
function AF:ShowQueuedCraftProfession(project)
    if self:IsQueueCompactNativeProfession() then
        local ok,message=self:RestoreQueueNativeProfession()
        if not ok then return false,message end
        if ProfessionsFrame and ProfessionsFrame.IsShown and ProfessionsFrame:IsShown() then
            return true,'Blizzard profession window shown.'
        end
    end
    if ProfessionsFrame and ProfessionsFrame.IsShown and ProfessionsFrame:IsShown() then
        return true,'Blizzard profession window is already visible.'
    end
    return self:OpenQueuedCraftProfession(project,false)
end

-- The profession API can retain recipe lists and GetCraftableCount values
-- after Blizzard's trade-skill window is closed. These CACHED records are
-- not evidence of an ACTIVE profession session: in Retail, a reagent-aware
-- CraftRecipe call with the window truly closed was observed to do nothing.
-- A fully shown, alpha=0 Foundry-cloaked frame is still an active window.
-- Check the real session BEFORE building or submitting the recipe transaction.
-- Use feature detection for Forever clients that may not expose the Retail
-- ProfessionsFrame; their live GetTradeSkillLine is documented to be nil when
-- the trade-skill window is closed. Never auto-craft from an unverifiable state.
function AF:IsQueueCraftSessionActive()
    local api=C_TradeSkillUI
    if type(api)~='table' then return false,'Profession API unavailable.' end
    local frame=ProfessionsFrame
    if frame and type(frame.IsShown)=='function' then
        local ok,shown=pcall(frame.IsShown,frame)
        if not ok or not shown then
            return false,'Blizzard profession window is closed (cached recipe data does not count as open).'
        end
    else
        if type(api.GetTradeSkillLine)~='function' then
            return false,'Cannot verify the native profession session on this client.'
        end
        local line=LiveCall(api.GetTradeSkillLine)
        if type(line)~='number' or line<=0 then
            return false,'No active trade-skill session reported by this client.'
        end
    end
    if type(api.IsTradeSkillReady)=='function' then
        local ok,ready=pcall(api.IsTradeSkillReady)
        if ok and ready==false then
            return false,'The open profession is still loading.'
        end
    end
    return true,'Native profession session open (visible or concealed).'
end

-- v0.7.3.8: Both Retail and Forever support OpenTradeSkill, OpenRecipe,
-- and CraftRecipe. A single REAL player click may attempt to prepare the
-- matching profession/recipe and send one reagent-aware craft batch, but UI
-- loading may be asynchronous. In that case STOP: NEVER craft from a stale
-- or unrelated schematic and NEVER retry from a timer or event callback.
-- This method does not consume or change any SavedVariables on click.
function AF:GetQueuedCraftQuickAction(project)
    local result=self:GetQueueCraftAction(project)
    result.canQuickCraft=result.canCraftOne==true
    if result.canQuickCraft then return result end
    if not project or type(project.crafting)~='table' or project.done then return result end
    local craft=project.crafting
    if project.owner~=self:GetCurrentKey() then return result end
    local qty=math.max(1,math.min(99,math.floor(tonumber(craft.quantity) or 1)))
    local done=math.max(0,math.floor(tonumber(craft.completed) or 0))
    if done>=qty then return result end
    local snapshot,stored=self:FindQueueRecipe(project)
    if not snapshot or not stored or not stored.learned then return result end
    local api=C_TradeSkillUI
    if type(api)~='table' or type(api.CraftRecipe)~='function' then return result end
    local recipeID=tonumber(craft.recipeID)
    if not recipeID then return result end
    local opened=LiveCall(api.GetBaseProfessionInfo)
    local present=IsRecipeInOpenList(api,recipeID)
    -- Already-open but uncraftable is a materials/disabled/station issue;
    -- reopening the profession cannot make an invalid craft valid.
    if present and type(opened)=='table' then return result end
    if not present and type(api.OpenTradeSkill)~='function' then
        return result
    end
    if type(api.OpenRecipe)~='function' then return result end
    result.canQuickCraft=true
    result.reason=present and 'Craft will select the recipe and start crafting.'
        or 'Craft will open the profession; a second click may be needed after recipes load.'
    result.remaining=qty-done
    return result
end

function AF:TryQueuedCraftQuick(project,all)
    if InCombatLockdown and InCombatLockdown() then
        return false,'Crafting is unavailable in combat.'
    end
    local launch=self:GetQueuedCraftQuickAction(project)
    if not launch.canQuickCraft then return false,launch.reason end
    local api=C_TradeSkillUI
    local recipeID=tonumber(project and project.crafting and project.crafting.recipeID)
    if not recipeID or type(api)~='table' then return false,'No usable crafting API.' end

    -- IMPORTANT: check the native SESSION before the normal recipe/readiness
    -- checks. GetAllRecipeIDs, GetRecipeInfo and GetCraftableCount may succeed
    -- with cached data while the profession window is closed. This was the
    -- v0.7.3.17 regression: a valid fixed-basic-schematic call silently did
    -- nothing because we skipped opening the actual profession session.
    local sessionReady,sessionReason=self:IsQueueCraftSessionActive()
    if not sessionReady then
        local opened,message=self:OpenQueuedCraftProfession(project,true)
        if not opened then return false,message end
        sessionReady,sessionReason=self:IsQueueCraftSessionActive()
        if not sessionReady then
            return false,'Preparing the native profession session for '..(project.title or 'this craft')..'. '
                ..tostring(sessionReason)..' Click Craft again once it has loaded.'
        end
    end

    -- Retail may have the wrong expansion era selected. Correct it only
    -- AFTER the profession session is actually active; otherwise a cached
    -- child skill-line can be mistaken for a live selection. Forever clients
    -- without the child skill-line API take the existing simple path.
    local eraReady,eraMessage=self:EnsureQueuedCraftEra(project)
    if not eraReady then return false,eraMessage end

    local readiness=self:GetQueueCraftAction(project)
    if not readiness.canCraftOne then
        return false,(eraMessage and eraMessage..'. ' or '')..
            'Profession opened, but the queued recipe is not ready. '..
            (readiness.reason or 'Wait for the list to load, then click Craft again.')
    end

    -- Do not let a profession UI transition (including a new era selection)
    -- close the active session between validation and the crafting request.
    sessionReady,sessionReason=self:IsQueueCraftSessionActive()
    if not sessionReady then
        return false,'Profession session changed while preparing the recipe: '..tostring(sessionReason)
    end

    local page=ProfessionsFrame and ProfessionsFrame.CraftingPage
    local form=page and page.SchematicForm
    local selected
    if form and type(form.GetRecipeInfo)=='function' then
        local ok,info=pcall(form.GetRecipeInfo,form)
        if ok and type(info)=='table' then selected=tonumber(info.recipeID) end
    end
    local state=NativeQueueSchematicState(api,recipeID)
    if selected~=recipeID or not state.ready then
        -- Prefer the already-live-tested standalone schematic allocation.
        -- It succeeds with a DIFFERENT recipe selected, provided the native
        -- profession SESSION is truly open (visible or cloaked).
        local crafted,detail=self:TryQueuedCraftFromSchematic(project,all)
        if crafted then return true,detail end
        local prepared,method=SelectNativeQueueRecipe(api,recipeID)
        if not prepared then
            return false,'Cannot initialize the native recipe. Select it in the profession window.'
        end
        state=NativeQueueSchematicState(api,recipeID)
        if not state.ready and state.recipeID==recipeID then
            TryAllocateNativeQueueBasics(state)
            state=NativeQueueSchematicState(api,recipeID)
        end
        if not state.ready then
            self.lastQueueCraftRequest={projectID=project.id,recipeID=recipeID,at=Now(),
                status='schematic_not_ready',lastEvent='Native recipe requested via '..method..'; craft NOT sent',
                nativeSelectedRecipeID=state.recipeID,reagentCount=state.reagents and #state.reagents or nil,
                requiredBasicSlots=state.basicRequired}
            return false,'Native reagent transaction is empty, and standalone crafting was unavailable ('
                ..tostring(detail)..'). The queue did not send a craft request. '
                ..'Select this recipe manually in professions to use the known working fallback.'
        end
    end
    return self:TryQueuedCraftInWindow(project,all)
end

-- A manual Stop affects only the client's active profession repeat, not the
-- SavedVariables queue. The current cast may finish before the stop takes effect.
function AF:StopQueuedCraftRepeat()
    local api=C_TradeSkillUI
    if not api or type(api.StopRecipeRepeat)~='function' then
        return false,'This client does not expose StopRecipeRepeat.'
    end
    local ok,err=pcall(api.StopRecipeRepeat)
    if not ok then return false,'Unable to stop repetition: '..tostring(err) end
    self.lastQueueCraftRequest=nil
    return true,'Stop requested. The current craft may still finish.'
end

-- The game's item-result event establishes produced ITEMS, not that the
-- original CraftRecipe call succeeded. Credit only an exact, uniquely assigned
-- output on the currently played crafter. Goals are a separate ledger; the same
-- observed result may contribute to a deliberately created Goal and a queue task.
function AF:ObserveQueuedCraftResult(data)
    local itemID,quantity=type(data)=='table' and tonumber(data.itemID),type(data)=='table' and tonumber(data.quantity)
    if not itemID or not quantity or quantity<=0 or not self.db then return false end
    local candidates={}
    local current=self:GetCurrentKey()
    for _,project in ipairs(self:GetCraftingQueueProjects()) do
        local craft=project.crafting
        if project.owner==current and not project.done and craft and not (project.guided and project.guided.kind=='craft') then
            local snap,recipe=self:FindQueueRecipe(project)
            if snap and recipe then
                local detail=self:GetRecipeDetails(snap,recipe)
                if detail and tonumber(detail.outputItemID)==itemID then candidates[#candidates+1]={p=project,recipe=detail} end
            end
        end
    end
    local matched=candidates[1]
    if not matched then return false end
    local project,recipe=matched.p,matched.recipe
    local yield=tonumber(recipe.quantityMin) or 1
    if yield<1 or yield~=math.floor(yield) or quantity%yield~=0 then return false end
    local count=math.floor(quantity/yield)
    local craft=project.crafting
    self.lastQueueCraftCreditProjectID=project.id
    craft.completed=math.min(99,(math.floor(tonumber(craft.completed) or 0)+count))
    local goal=math.max(1,math.floor(tonumber(craft.quantity) or 1))
    project.updated=Now()
    if craft.completed>=goal then
        project.done=true;project.completedAt=Now()
        if self.UI and self.UI.ShowGoalToast then self.UI:ShowGoalToast('Queue Craft Complete!',project.title or 'Craft') end
    end
    if self.RefreshUI then self:RefreshUI() end
    return true
end
