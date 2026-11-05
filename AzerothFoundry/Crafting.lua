-- Observed recipe graph; shows possible production chains, not verified
-- transferability, item provenance, or guaranteed crafting availability.
local _, AF = ...
local function Now() return type(time)=='function' and time() or 0 end
local function Num(v) return type(v)=='number' and v or nil end
local function Safe(fn, ...)
    if type(fn)~='function' then return nil end
    local ok,value=pcall(fn,...)
    return ok and value or nil
end

function AF:InitializeCrafting()
    self.db.craftingPlans = type(self.db.craftingPlans)=='table' and self.db.craftingPlans or {}
    self.db.schema = math.max(tonumber(self.db.schema) or 1, 5)
end

-- Index only CONFIRMED learned recipes from eligible, scanned characters.
-- The reference library may fill missing output IDs but must never turn an
-- unlearned recipe into an available crafter.
function AF:BuildKnownOutputIndex(scope, ownerKey)
    local index={}
    for _, char in ipairs(self:GetPlanningResourceCharacters(scope or 'all',ownerKey)) do
        for _, snap in pairs(self.db.recipeSnapshots[char.key] or {}) do
            for _, recipe in pairs(snap.recipes or {}) do
                if recipe.learned==true then
                    local detail=self:GetRecipeDetails(snap,recipe)
                    local itemID=detail and Num(detail.outputItemID)
                    if itemID and itemID>0 then
                        index[itemID]=index[itemID] or {}
                        index[itemID][#index[itemID]+1]={
                            character=char, snapshot=snap,recipe=detail,
                            outputCount=math.max(1,Num(detail.quantityMin) or 1),
                        }
                    end
                end
            end
        end
    end
    for _, candidates in pairs(index) do
        table.sort(candidates,function(a,b)
            local as=a.recipe.reagents and #a.recipe.reagents>0 and 1 or 0
            local bs=b.recipe.reagents and #b.recipe.reagents>0 and 1 or 0
            if as~=bs then return as>bs end
            return (a.character.name or '')<(b.character.name or '')
        end)
    end
    return index
end

local function NewStock(AF,scope,ownerKey)
    local stock={}
    local seen={}
    for _, char in ipairs(AF:GetPlanningResourceCharacters(scope,ownerKey)) do
        local data=AF.db.inventory[char.key] or {}
        for _,name in ipairs({'bags','bank'}) do
            local snap=data[name]
            if type(snap)=='table' and type(snap.counts)=='table' then
                seen[char.key..':'..name]=snap.scanned
                for itemID,n in pairs(snap.counts) do
                    stock[itemID]=(stock[itemID] or 0)+(tonumber(n) or 0)
                end
            end
        end
    end
    return stock,seen
end

-- The Add to Crafting Queue dialog's Max button is a CURRENT-CHARACTER
-- calculation. Account/bank/alt snapshots are planning information, not proof
-- that an item can be crafted now. Never silently treat stale stock as live.
-- Returns: integer 0..99, source message; nil means the limit is unknown.
function AF:GetRecipeQueueMaxAttempts(snapshot,recipe,characterKey)
    if not snapshot or not recipe or not recipe.id or recipe.learned~=true then
        return nil,'Select a learned recipe first.'
    end
    if characterKey~=self:GetCurrentKey() then
        return nil,'Max uses the current crafter only. Log onto that character for an accurate material count.'
    end
    local recipeID=tonumber(recipe.id)
    local api=C_TradeSkillUI
    -- The native game is authoritative when THIS profession is open, not
    -- merely when cached recipe info is available from a different skill line.
    if type(api)=='table' and type(api.GetCraftableCount)=='function' and
        type(api.GetBaseProfessionInfo)=='function' and
        type(api.GetRecipeInfo)=='function' then
        local okBase,base=pcall(api.GetBaseProfessionInfo)
        local professionID=tonumber(snapshot.professionID)
        if okBase and type(base)=='table' and professionID and
            (tonumber(base.professionID)==professionID or
             tonumber(base.parentProfessionID)==professionID) then
            local okInfo,info=pcall(api.GetRecipeInfo,recipeID)
            if okInfo and type(info)=='table' and info.learned==true then
                local okCount,count=pcall(api.GetCraftableCount,recipeID)
                if okCount and type(count)=='number' and count==count and count>=0 then
                    return math.max(0,math.min(99,math.floor(count))),
                        'Native profession limit from currently available reagents (capped at 99).'
                end
            end
        end
    end
    -- Works without opening a profession, using the LIVE local bag/reagent
    -- bag counts. Skip alternative, optional, currency and unknown slots:
    -- those need native GetCraftableCount for a trustworthy answer.
    local detail=self:GetRecipeDetails(snapshot,recipe)
    if type(detail)~='table' or detail.reagentsIncomplete or
        type(detail.reagents)~='table' or #detail.reagents==0 then
        return nil,'Recipe reagents are incomplete. Open its profession and try Max again.'
    end
    local byID={}
    for _,r in ipairs(detail.reagents) do
        local id,needed=tonumber(r.itemID),tonumber(r.quantity)
        if not id or id<1 or not needed or needed<=0 then
            return nil,'Recipe reagents are not fully known. Open its profession for native Max.'
        end
        byID[id]=(byID[id] or 0)+needed
    end
    local getCount=(type(C_Item)=='table' and C_Item.GetItemCount) or GetItemCount
    if type(getCount)~='function' then
        return nil,'The client does not expose live bag item counts.'
    end
    local maximum=99
    for itemID,required in pairs(byID) do
        local ok,count=pcall(getCount,itemID,false)
        if not ok or type(count)~='number' or count<0 or count~=count then
            return nil,'Could not read current bag counts. Open the profession for native Max.'
        end
        maximum=math.min(maximum,math.floor(count/required))
    end
    return math.max(0,maximum),
        'Calculated from reagents in the current character\'s bags (capped at 99).'
end

-- Readiness is an informational estimate, not proof of being able to craft.
-- "In bags" is only used for the currently logged-in character; older
-- character and bank snapshots are clearly labelled as recorded stock.
function AF:GetRecipeReadiness(snapshot, recipe, characterKey, scope, quantity)
    if not recipe or recipe.learned ~= true then return {kind='unknown', label='Recipe not learned'} end
    quantity = math.max(1, math.floor(tonumber(quantity) or 1))
    scope = scope == 'expedition' and 'expedition' or 'all'
    if not self:WorkshopCharacterAllowed(characterKey, scope) then
        return {kind='out-of-scope',label='Outside selected scope'}
    end
    if scope=='expedition' and self:GetExpeditionPlanningPolicy(scope,characterKey).mode=='excluded' then
        return {kind='out-of-scope',label='Outside active charter period'}
    end
    local detail = self:GetRecipeDetails(snapshot, recipe)
    if not detail or detail.reagentsIncomplete or type(detail.reagents)~='table' or #detail.reagents==0 then
        return {kind='unknown',label='Requirements incomplete'}
    end
    local own = self.db.inventory[characterKey] or {}
    local bags=own.bags and own.bags.counts
    local currentlyPlaying=(characterKey==self:GetCurrentKey())
    local bagsCover=currentlyPlaying and type(bags)=='table'
    local recordedCover=true
    local hasScannedAll=true
    local missingTotal=0
    local itemsMissing=0
    for _,r in ipairs(detail.reagents) do
        local id, need=tonumber(r.itemID),tonumber(r.quantity)
        if not id or not need or need<1 then return {kind='unknown',label='Requirements incomplete'} end
        need=need*quantity
        if not bags or (tonumber(bags[id]) or 0)<need then bagsCover=false end
        local estimate=self:GetInventoryEstimate(id,scope,characterKey)
        if not estimate.anyScanned then hasScannedAll=false end
        local deficit=math.max(0,need-estimate.total)
        if deficit>0 then recordedCover=false;missingTotal=missingTotal+deficit;itemsMissing=itemsMissing+1 end
    end
    if bagsCover then
        return {kind='bags',label='Materials in bags',count=quantity,estimated=false}
    elseif recordedCover and hasScannedAll then
        return {kind='recorded',label=scope=='expedition' and (self:GetExpeditionPlanningPolicy(scope,characterKey).mode=='personal' and 'Recorded for this crafter only' or 'Recorded for eligible members') or 'Materials recorded across alts',count=quantity,estimated=true}
    elseif not hasScannedAll then
        return {kind='unknown',label='Inventory not scanned',count=quantity,estimated=true}
    else
        return {kind='missing',label='Missing recorded materials',missing=missingTotal,itemsMissing=itemsMissing,estimated=true}
    end
end

function AF:MakeCraftingPlan(snapshot,recipe,characterKey,scope,quantity)
    if not snapshot or not recipe then return nil,'Select a recipe first.' end
    if recipe.learned~=true then return nil,'A learned recipe is required for a crafting plan.' end
    scope=scope=='expedition' and 'expedition' or 'all'
    if not self:WorkshopCharacterAllowed(characterKey,scope) then
        return nil,'The selected character is outside this plan scope.'
    end
    if scope=='expedition' and self:GetExpeditionPlanningPolicy(scope,characterKey).mode=='excluded' then
        return nil,'This crafter has no active charter observation period.'
    end
    quantity=tonumber(quantity) or 1
    if quantity<1 or quantity>99 or math.floor(quantity)~=quantity then
        return nil,'Craft count must be a whole number from 1 to 99.'
    end
    local full=self:GetRecipeDetails(snapshot,recipe)
    local result={scope=scope, characterKey=characterKey, recipeID=recipe.id,
        recipeName=recipe.name, professionID=snapshot.professionID, quantity=quantity, created=Now(), steps={},
        notes={},unknown=full and full.reagentsIncomplete == true, estimated=true}
    if result.unknown then
        result.notes[#result.notes+1]='Some reagent slots have alternatives and could not be safely captured.'
    end
    local stock,seen=NewStock(self,scope,characterKey)
    result.snapshots=seen
    local producers=self:BuildKnownOutputIndex(scope,characterKey)
    if not full or not full.reagents or #full.reagents==0 then
        result.unknown=true
        result.notes[#result.notes+1]='Reagents unavailable; cannot calculate this recipe.'
        return result
    end
    local nodes=0
    local function Visit(id,needed,depth,parents,optional)
        nodes=nodes+1
        if nodes>120 then
            result.unknown=true
            result.steps[#result.steps+1]={itemID=id,needed=needed,depth=depth,kind='limit',message='Plan too large to expand safely'}
            return
        end
        local available=math.max(0,stock[id] or 0)
        local used=math.min(available,needed)
        stock[id]=available-used
        local deficit=needed-used
        local node={itemID=id,needed=needed,used=used,missing=deficit,depth=depth,kind='obtain',optional=optional==true}
        result.steps[#result.steps+1]=node
        if deficit<=0 then node.kind='snapshot' return end
        if depth>=4 then
            node.kind='limit';result.unknown=true;return
        end
        if parents[id] then node.kind='cycle';result.unknown=true;return end
        local choices=producers[id]
        if not choices or #choices==0 then
            node.kind='obtain';return
        end
        node.alternatives=#choices
        local chosen=choices[1]
        node.crafter=chosen.character.name
        node.crafterKey=chosen.character.key
        node.profession=chosen.snapshot.professionName
        node.recipeID=chosen.recipe.id
        node.craftCount=math.ceil(deficit/chosen.outputCount)
        if not chosen.recipe.reagents or #chosen.recipe.reagents==0 then
            node.kind='unknown-reagents';result.unknown=true;return
        end
        node.kind='craftable'
        if chosen.recipe.reagentsIncomplete then result.unknown=true end
        parents[id]=true
        for _,r in ipairs(chosen.recipe.reagents) do
            if Num(r.itemID) and Num(r.quantity) then
                Visit(r.itemID,r.quantity*node.craftCount,depth+1,parents,true)
            else result.unknown=true end
        end
        parents[id]=nil
    end
    for _, r in ipairs(full.reagents) do
        if Num(r.itemID) and Num(r.quantity) then
            Visit(r.itemID,r.quantity*quantity,0,{})
        else result.unknown=true end
    end
    if scope=='expedition' then
        local policy=self:GetExpeditionPlanningPolicy(scope,characterKey)
        result.notes[#result.notes+1]=policy.note
    else
        result.notes[#result.notes+1]='Account-wide plan: NOT charter-qualified.'
    end
    result.notes[#result.notes+1]='Bag and bank totals are snapshots, not a guaranteed live shared inventory.'
    return result
end

function AF:SaveCraftingProject(plan)
    if not plan or not self.db then return nil end
    local project=self:AddProject()
    project.title='Craft '..plan.quantity..'x '..plan.recipeName
    project.owner=plan.characterKey
    project.crafting={scope=plan.scope,recipeID=plan.recipeID,quantity=plan.quantity,
        created=Now(), professionID=plan.professionID, routes={}}
    project.description='Crafting plan • '..(plan.scope=='expedition' and 'Expedition' or 'All Alts')..'\n'..
        'Material quantities were estimated from last-recorded inventory. Review them before crafting.'..
        (plan.unknown and '\nWarning: recipe input information is incomplete.' or '')
    local alternatives={}
    for _,step in ipairs(plan.steps) do
        local presentation=self:GetItemPresentation(step.itemID)
        local name=presentation and presentation.name or ('Item #'..step.itemID)
        if step.optional then
            -- The listed subcraft is a suggested route, not a mandatory
            -- ingredient of the original recipe. Do not make it a compulsory
            -- checklist item (players can obtain its parent item another way).
            alternatives[#alternatives+1]='Optional route: '..(step.missing or step.needed)..'x '..name
        else
            local instructions
            if step.kind=='craftable' then
                instructions='Obtain '..step.missing..'x '..name..' (possible craft: '..step.crafter..'; other sources allowed)'
            elseif step.kind=='snapshot' then
                instructions='Verify '..step.needed..'x '..name..' (recorded as available)'
            else
                instructions='Obtain '..(step.missing or step.needed)..'x '..name..' (source not verified)'
            end
            project.tasks[#project.tasks+1]={id=self:NextID(),text=instructions,done=false,autoMaterial=true,materialItemID=step.itemID}
        end
    end
    if #alternatives>0 then
        project.description=project.description..'\n\nOptional crafting route details (not mandatory):\n'..
            table.concat(alternatives,'\n')
    end
    self:RefreshUI()
    return project
end
