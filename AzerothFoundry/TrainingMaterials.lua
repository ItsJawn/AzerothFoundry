-- Azeroth Foundry / Workshop / Training material and milestone helpers (v1.0.29.13)
-- Optional, read-only material calculations; crafting runs ONLY on a player's button click.
local _, AF = ...
local floor,ceil,max,min = math.floor,math.ceil,math.max,math.min
local function Stamp() return type(time)=='function' and time() or 0 end
local function MaterialName(self,id)
    local p=self.GetItemPresentation and self:GetItemPresentation(id)
    return p and p.name or ('Item #'..tostring(id))
end

-- Merchant BUY prices are distinct from GetItemInfo's vendor SELL price.
-- Only actual observed, non-extended-cost merchant offers can be quoted.
function AF:ObserveTrainingVendorPrices()
    if not self.db or type(GetMerchantNumItems)~='function' or
       type(GetMerchantItemInfo)~='function' or type(GetMerchantItemLink)~='function' then return end
    local store=self.db.trainingVendorQuotes or {}
    self.db.trainingVendorQuotes=store
    local count=tonumber(GetMerchantNumItems()) or 0
    for i=1,min(300,count) do
        local ok,name,texture,price,quantity,available,usable,extended=pcall(GetMerchantItemInfo,i)
        if ok and not extended and type(price)=='number' and price>=0 and
           type(quantity)=='number' and quantity>=1 then
            local okLink,link=pcall(GetMerchantItemLink,i)
            local id=okLink and type(link)=='string' and tonumber(link:match('item:(%d+)'))
            if id then
                store[id]={price=price,bundle=quantity,at=Stamp(),
                    vendor=(type(UnitName)=='function' and UnitName('npc')) or nil}
            end
        end
    end
end

function AF:GetTrainingMaterialQuote(itemID,quantity)
    itemID=tonumber(itemID)
    quantity=max(0,ceil(tonumber(quantity) or 0))
    if not itemID then return {source='unknown'} end
    local ah=self.GetTrainingAuctionPrice and self:GetTrainingAuctionPrice(itemID) or nil
    local quote=self.db and self.db.trainingVendorQuotes and self.db.trainingVendorQuotes[itemID]
    local bundle=quote and tonumber(quote.bundle)
    local vendorPrice=quote and tonumber(quote.price)
    local vendorCost=bundle and bundle>=1 and vendorPrice and vendorPrice>=0 and
        ceil(quantity/bundle)*vendorPrice or nil
    local auctionCost=ah and ah*quantity or nil
    if vendorCost and (not auctionCost or vendorCost<=auctionCost) then
        return {source='vendor',cost=vendorCost,unit=vendorPrice/bundle,
            bundle=bundle,vendor=quote.vendor,observed=quote.at,
            alternativeAH=auctionCost}
    end
    if auctionCost then return {source='auction',cost=auctionCost,unit=ah,
        alternativeVendor=vendorCost} end
    return {source='unknown'}
end

-- One material deep, restricted to recipes actually recorded as LEARNED by
-- this crafter; speculative library/trainer recipes never become subcrafts.
function AF:GetTrainingMaterialSubcrafts(owner,itemID,quantity)
    itemID=tonumber(itemID)
    quantity=max(1,ceil(tonumber(quantity) or 1))
    local choices={}
    if not itemID then return choices end
    local snapshots=self.db and self.db.recipeSnapshots and self.db.recipeSnapshots[owner] or {}
    for _,snap in pairs(snapshots) do
        if type(snap)=='table' then
            for id,record in pairs(snap.recipes or {}) do
                if type(record)=='table' and record.learned==true then
                    local detail=self:GetRecipeDetails(snap,record)
                    if detail and tonumber(detail.outputItemID)==itemID and
                       type(detail.reagents)=='table' and #detail.reagents>0 and
                       not detail.reagentsIncomplete then
                        local valid=true
                        local yield=max(1,floor(tonumber(detail.quantityMin) or 1))
                        local crafts=ceil(quantity/yield)
                        local materials={}
                        local total,known=0,true
                        for _,r in ipairs(detail.reagents) do
                            local reagentID=tonumber(r.itemID)
                            local each=tonumber(r.quantity)
                            if not reagentID or reagentID==itemID or not each or each<=0 then
                                valid=false;break
                            end
                            local need=ceil(each*crafts)
                            local quote=self:GetTrainingMaterialQuote(reagentID,need)
                            if quote.cost then total=total+quote.cost else known=false end
                            materials[#materials+1]={id=reagentID,name=MaterialName(self,reagentID),
                                quantity=need,quote=quote}
                        end
                        if valid then
                            choices[#choices+1]={recipeID=tonumber(record.id) or tonumber(id),
                                professionID=tonumber(snap.professionID),
                                name=detail.name or record.name or MaterialName(self,itemID),
                                crafts=crafts,yield=yield,quantity=quantity,materials=materials,
                                cost=known and total or nil,pricedFloor=total,complete=known}
                        end
                    end
                end
            end
        end
    end
    table.sort(choices,function(a,b)
        if (a.cost~=nil)~=(b.cost~=nil) then return a.cost~=nil end
        if a.cost and b.cost and a.cost~=b.cost then return a.cost<b.cost end
        if a.crafts~=b.crafts then return a.crafts<b.crafts end
        return a.name<b.name
    end)
    return choices
end

function AF:GetTrainingMilestoneCraftProject(plan,seg)
    if not plan or not seg or not seg.learned or not seg.recipeID then
        return nil,'This training milestone is not a learned recipe.'
    end
    if plan.characterKey~=self:GetCurrentKey() then
        return nil,'Log into the selected crafter to craft this milestone.'
    end
    if not (plan.current>=seg.startSkill and plan.current<seg.endSkill) then
        return nil,'Select the active milestone; future milestones are not ready.'
    end
    local snapshot,record=self:FindQueueRecipe({owner=plan.characterKey,
        crafting={recipeID=seg.recipeID,professionID=seg.professionID}})
    if not snapshot or not record or not record.learned then
        return nil,'Open the native profession and scan this learned recipe first.'
    end
    local qty=max(1,min(99,floor(tonumber(seg.quantity) or 1)))
    return {id='training-milestone-'..tostring(seg.recipeID),
        owner=plan.characterKey,title=seg.name,done=false,
        crafting={recipeID=seg.recipeID,professionID=seg.professionID,
            quantity=qty,completed=0,scope='all',routes={}}}
end

-- Listen only for observed merchant item lists; no automation and no buying.
if type(CreateFrame)=='function' then
    local watcher=CreateFrame('Frame')
    watcher:RegisterEvent('MERCHANT_SHOW')
    watcher:RegisterEvent('MERCHANT_UPDATE')
    watcher:SetScript('OnEvent',function()
        if AF.db then AF:ObserveTrainingVendorPrices() end
    end)
end
