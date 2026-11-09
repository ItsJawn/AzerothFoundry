-- Azeroth Foundry - curated training guides with optional personal comparisons.
-- Guide steps are editorial reference bands, NOT evidence of a learned recipe.
-- Curated 1-225 reference coverage: eight crafting/secondary professions.
-- No gathering-only route is invented. 225-300 requires a later verified pack.
-- Recipes requiring vendor patterns or rank books are explicitly flagged.
-- Learned alternative recipes NEVER silently replace the trainer baseline.
local _, AF = ...
local floor,ceil,max,min=math.floor,math.ceil,math.max,math.min

-- Each entry is an independently maintained reference step. The skill ranges
-- are targets, and the craft totals are conservative reference estimates;
-- the client may change thresholds and yellow skill-ups are probabilistic.
-- Avoid large descriptive passages from third-party guides in data packs.
-- Every entry: {skillFrom, skillTo, recipeName, estimatedCrafts, acquisition?, note?}
-- Built as native-to-Foundry reference milestones; live recipe data and
-- the player's learned list determine which requirements are confirmed.
local STEPS={
    leatherworking={
        {1,30,'Light Armor Kit',29},
        {30,55,'Cured Light Hide',27},
        {55,75,'Embossed Leather Gloves',21},
        {75,80,'Medium Leather',8},
        {80,90,'Cured Medium Hide',10},
        {90,100,'Fine Leather Belt',16},
        {100,115,'Light Leather Pants',22},
        {115,125,'Dark Leather Belt',10},
        {125,130,'Heavy Leather',7},
        {130,140,'Cured Heavy Hide',20},
        {140,155,"Hillman's Leather Gloves",20},
        {155,165,'Barbaric Shoulders',10},
        {165,175,'Guardian Gloves',10},
        {175,195,'Thick Armor Kit',20},
        {195,210,'Nightscape Headband',20},
        {210,225,'Nightscape Pants',15},
    },
    alchemy={
        {1,10,'Minor Arcane Elixir',9},
        {10,55,'Elixir of Minor Defense',45},
        {55,65,'Minor Mana Potion',10},
        {65,90,'Elixir of Minor Fortitude',27},
        {90,120,'Elixir of Wisdom',30},
        {120,130,'Lesser Mana Potion',10},
        {130,150,'Fire Oil',20},
        {150,165,'Elixir of Fire Power',15},
        {165,195,'Mana Potion',36},
        {195,225,'Nature Protection Potion',36,'vendor','Requires vendor recipe; not taught directly by an Alchemy trainer.'},
    },
    blacksmithing={
        {1,25,'Rough Sharpening Stone',30},
        {25,50,'Rough Grinding Stone',30},
        {50,67,'Coarse Grinding Stone',36},
        {67,75,'Runed Copper Gauntlets',8},
        {75,95,'Runed Copper Belt',23},
        {95,100,'Patterned Bronze Bracers',5},
        {100,112,'Heavy Grinding Stone',20},
        {112,125,'Patterned Bronze Bracers',13},
        {125,140,'Bronze Shortsword',24},
        {140,170,'Bronze Warhammer',39},
        {170,175,'Green Iron Bracers',9},
        {175,180,'Solid Grinding Stone',8},
        {180,195,'Golden Scale Bracers',20},
        {195,210,'Heavy Mithril Gauntlet',21},
        {210,215,'Heavy Mithril Axe',6},
        {215,225,'Heavy Mithril Breastplate',10},
    },
    enchanting={
        {1,2,'Runed Copper Rod',1},
        {2,20,'Enchant Bracer - Inferior Stamina',18},
        {20,70,'Enchant Chest - Inferior Stamina',50},
        {70,100,'Enchant Bracer - Minor Stamina',30},
        {100,109,'Enchant Cloak - Minor Protection',9},
        {109,110,'Runed Silver Rod',1},
        {110,130,'Enchant Cloak - Minor Protection',32},
        {130,150,'Enchant Boots - Minor Stamina',20},
        {150,151,'Runed Golden Rod',1},
        {151,165,'Minor Mana Oil',16,'vendor','Formula sold by enchanting supply vendors.'},
        {165,200,'Enchant Boots - Lesser Agility',47},
        {200,201,'Runed Truesilver Rod',1},
        {201,220,'Lesser Wizard Oil',25,'vendor','Formula sold by enchanting supply vendors.'},
        {220,225,'Enchant Cloak - Greater Defense',5},
    },
    engineering={
        {1,30,'Rough Blasting Powder',60},
        {30,50,'Handful of Copper Bolts',30},
        {50,51,'Arclight Spanner',1},
        {51,75,'Rough Copper Bomb',30},
        {75,90,'Coarse Blasting Powder',60},
        {90,100,'Coarse Dynamite',20},
        {100,105,'Silver Contact',5},
        {105,125,'Bronze Tube',25},
        {125,135,'Standard Scope',10},
        {135,145,'Heavy Blasting Powder',20},
        {145,150,'Whirring Bronze Gizmo',15},
        {150,160,'Bronze Framework',15},
        {160,175,'Explosive Sheep',15},
        {175,194,'Solid Blasting Powder',60},
        {194,195,'Gyromatic Micro-Adjustor',1},
        {195,200,'Mithril Tube',6},
        {200,215,'Unstable Trigger',20},
        {215,225,'Mithril Casing',17},
    },
    tailoring={
        {1,30,'Bolt of Linen Cloth',30},
        {30,55,'Linen Belt',28},
        {55,80,'Bolt of Woolen Cloth',45},
        {80,95,'Woolen Cape',22},
        {95,100,'Double-stitched Woolen Shoulders',5},
        {100,120,'Bolt of Silk Cloth',54},
        {120,140,'Gloves of Meditation',29},
        {140,150,'Bolt of Mageweave',23},
        {150,170,'Crimson Silk Vest',20},
        {170,190,'Crimson Silk Pantaloons',26},
        {190,215,'Black Mageweave Gloves',38},
        {215,225,'Mageweave Bag',26},
    },
    cooking={
        {1,50,'Charred Wolf Meat',55},
        {50,100,'Boiled Clams',55},
        {100,130,'Crab Cake',40},
        {130,150,'Goblin Deviled Clams',25},
        {150,175,'Crocolisk Gumbo',29,'vendor','Recipe sold by cooking recipe vendors; Expert Cookbook also required.'},
        {175,200,'Rockscale Cod',27,'vendor','Recipe sold by fishing/cooking vendors; not directly trainer-taught.'},
        {200,225,'Spider Sausage',25},
    },
    ['first aid']={
        {1,40,'Linen Bandage',50},
        {40,80,'Heavy Linen Bandage',52},
        {80,115,'Wool Bandage',50},
        {115,150,'Heavy Wool Bandage',50},
        {150,180,'Silk Bandage',42,'trainer','Expert First Aid rank requires the Under Wraps book, sold by First Aid book vendors.'},
        {180,210,'Heavy Silk Bandage',46,'book','Manual: Heavy Silk Bandage sold by First Aid book vendors.'},
        {210,225,'Mageweave Bandage',19,'book','Manual: Mageweave Bandage sold by First Aid book vendors.'},
    },
}
AF.TrainingGuides=STEPS
function AF:HasCuratedTrainingGuide(profession)
    return STEPS[tostring(profession or ''):lower()]~=nil
end
local function NameKey(s)
    return tostring(s or ''):lower():gsub('[^%w]','')
end
local function GuideChance(c,skill)
    if not c then return nil end
    local observed=c.record and tonumber(c.record.scannedSkill)
    local difficulty=c.record and tonumber(c.record.relativeDifficulty)
    if observed==skill and difficulty~=nil then
        if difficulty==0 then return 1 end
        if difficulty==1 then
            -- Yellow is not guaranteed; estimated when no confirmed curve.
            if not c.tiers then return .75 end
        elseif difficulty==2 or difficulty==3 then return 0 end
    end
    if not c.tiers then return nil end
    local t=c.tiers
    if skill<t[1] or skill>=t[3] then return 0 end
    if skill<t[2] then
        -- A borrowed/placeholder orange start must not be sold as certainty.
        if t.unanchoredOrange then return nil end
        return 1
    end
    local span=t[3]-t[2]
    if span<=0 then return 0 end
    return max(.5,min(1,1-.5*(skill-t[2])/span))
end
local function Quote(self,c)
    local cost,missing=0,0
    if not c or not c.hasReagents then return nil end
    for _,r in ipairs(c.recipe.reagents or {}) do
        local price=self:GetTrainingAuctionPrice(r.itemID)
        if price==nil then missing=missing+1 else cost=cost+price*r.quantity end
    end
    return missing==0 and cost or nil
end
local function CraftEstimate(c,startSkill,endSkill,reference)
    local range=endSkill-startSkill
    if range<=0 then return 0,nil,nil,false end
    local expected=0
    local first,last
    local verified=true
    for skill=startSkill,endSkill-1 do
        local chance=GuideChance(c,skill)
        if not chance or chance<=0 then
            verified=false
            break
        end
        first=first or chance
        last=chance
        expected=expected+1/chance
    end
    if verified then
        return max(range,ceil(expected-.00001)),first,last,true
    end
    -- The guide can still display a research estimate if game source data is
    -- incomplete, but it must be marked UNVERIFIED and never auto-queued.
    return max(range,ceil(reference or range)),nil,nil,false
end
function AF:GetTrainingGuideSignature(owner,profession)
    local prof=self.db and self.db.characters and self.db.characters[owner]
    prof=prof and prof.professions and prof.professions[profession]
    local x=(tonumber(prof and prof.skill) or 0)*7919
    local snapshots=(self.db and self.db.recipeSnapshots and self.db.recipeSnapshots[owner]) or {}
    for _,snap in pairs(snapshots) do
        if type(snap)=='table' and NameKey(snap.professionName)==NameKey(profession) then
            for _,rec in pairs(snap.recipes or {}) do
                if type(rec)=='table' and tonumber(rec.id) then
                    x=(x+tonumber(rec.id)*(rec.learned and 3 or 1) +
                        (tonumber(rec.scannedSkill) or 0)*13 +
                        (tonumber(rec.relativeDifficulty) or 0)*37)%2147483647
                end
            end
        end
    end
    return x
end
-- The guide preserves fixed milestone bands and compares actual learned
-- recipes against them, rather than greedily replacing the entire path.
function AF:CalculateTrainingGuide(owner,profession,target,mode,overrides)
    local entries=STEPS[tostring(profession or ''):lower()]
    if not entries then return nil,'No curated crafting guide for '..tostring(profession)..' yet.' end
    local character=self.db and self.db.characters and self.db.characters[owner]
    local profile=character and character.professions and character.professions[profession]
    if not profile then return nil,'Select a recorded profession first.' end
    local current=floor(tonumber(profile.skill) or 0)
    target=tonumber(target)
    if not target or target~=floor(target) or target<=current or target>999 then
        return nil,'Choose a whole-number goal above your current skill.'
    end
    overrides=type(overrides)=='table' and overrides or {}
    local known=self:GetTrainingCandidates(owner,profession,false)
    local byName={}
    for _,c in ipairs(known) do
        local k=NameKey(c.name)
        if k:sub(1,6)=='recipe' and c.recipe and c.recipe.outputItemID and self.GetItemPresentation then
            local info=self:GetItemPresentation(c.recipe.outputItemID)
            if info and info.name then k=NameKey(info.name) end
        end
        if not byName[k] or (c.learned and not byName[k].learned) then byName[k]=c end
    end
    local plan={guideMode=true,guideVersion=2,characterKey=owner,profession=profession,
        current=current,target=target,cap=tonumber(profile.maximum) or 0,
        mode=mode=='fast' and 'fast' or 'cheap',segments={},candidates=known,
        materials={},notes={},complete=false,requiresTraining=false,
        trainerBreakpoints={},provisional=false,provisionalSteps=0,unknownQuotes=0,
        hasPrices=type(Auctionator)=='table' and type(Auctionator.API)=='table' and
            type(Auctionator.API.v1)=='table' and type(Auctionator.API.v1.GetAuctionPriceByItemID)=='function',
        signature=self:GetTrainingGuideSignature(owner,profession),
        rankBreakpoint=(tonumber(profile.maximum) or 0)<target and (tonumber(profile.maximum) or 0)>0 and tonumber(profile.maximum) or nil,
        guideWarnings=0,alternativeCount=0,betterCostCount=0,
        lowConfidence=false,sourceDiagnostics={}}
    local reached=current
    local rankBreaks={75,150,225}
    -- Keep long reference stretches digestible as ~10-skill visual milestones.
    -- A 5/10/15 point curated breakpoint remains intact if meaningful.
    local bands={}
    for _,row in ipairs(entries) do
        local a,b=row[1],row[2]
        if b-a>15 then
            while a<b do
                local nextSkill=min(b,a+10)
                bands[#bands+1]={a,nextSkill,row[3],row[4]*(nextSkill-a)/(row[2]-row[1]),row[5],row[6]}
                a=nextSkill
            end
        else
            bands[#bands+1]=row
        end
    end
    for _,row in ipairs(bands) do
        local left,right,name,crafts=row[1],row[2],row[3],row[4]
        local acquisition,acquisitionNote=row[5] or 'trainer',row[6]
        if right>current and left<target then
            local s=max(left,current)
            local e=min(right,target)
            if s>reached then
                plan.stopSkill=reached
                plan.stopReason='guide_gap'
                plan.notes[#plan.notes+1]='No curated crafting route covers skill '..reached..'.'
                break
            end
            if e>s then
                local baseline=byName[NameKey(name)]
                -- In-guide alternatives need to cover the ENTIRE band, not just
                -- have an orange arrow at the character's current skill.
                local learnedAlternatives={}
                for _,c in ipairs(known) do
                    if c.learned and c.hasReagents and c.tiers and
                        (not baseline or c.id~=baseline.id) then
                        local count,first,last,ok=CraftEstimate(c,s,e,e-s)
                        if ok then
                            local quote=Quote(self,c)
                            local outputPrice=c.recipe.outputItemID and
                                self:GetTrainingAuctionPrice(c.recipe.outputItemID) or nil
                            local margin=quote and outputPrice and
                                (outputPrice*(c.outputCount or 1)-quote) or nil
                            learnedAlternatives[#learnedAlternatives+1]={candidate=c,
                                count=count,first=first,last=last,unitCost=quote,
                                totalCost=quote and quote*count or nil,margin=margin}
                        end
                    end
                end
                local chosen=baseline
                local overridden=false
                local selectedID=tonumber(overrides[s])
                if selectedID then
                    for _,alt in ipairs(learnedAlternatives) do
                        if alt.candidate.id==selectedID then
                            chosen=alt.candidate; overridden=true;break
                        end
                    end
                end
                local guideCrafts=max(1,ceil(crafts*(e-s)/(right-left)))
                local qty,first,last,valid=CraftEstimate(chosen,s,e,guideCrafts)
                if chosen==baseline then
                    -- For a leveling guide, its curated reservation is a
                    -- starting estimate, not a guaranteed exact craft count.
                    qty=max(qty,guideCrafts)
                end
                -- Missing data must not turn a reference guide into an empty
                -- path; it remains a visible but NOT queueable research step.
                local recipe=chosen and chosen.recipe or {name=name,reagents={}}
                local cost=Quote(self,chosen)
                local baselinePrice=Quote(self,baseline)
                local baselineQty=baseline and
                    (select(1,CraftEstimate(baseline,s,e,guideCrafts))) or guideCrafts
                local baselineTotal=baselinePrice and
                    baselinePrice*max(guideCrafts,baselineQty) or nil
                local other={}
                for _,alt in ipairs(learnedAlternatives) do
                    if not chosen or alt.candidate.id~=chosen.id then
                        local label='ALTERNATE LEARNED'
                        local savings=baselineTotal and alt.totalCost and
                            (baselineTotal-alt.totalCost) or nil
                        if savings and savings>0 then
                            label='CHEAPER BY '..self.TrainingFormatCoin(savings)
                        elseif alt.margin and alt.margin>0 then
                            label='POTENTIAL AH MARGIN +'..self.TrainingFormatCoin(alt.margin)..'/craft'
                        end
                        other[#other+1]={recipeID=alt.candidate.id,
                            name=alt.candidate.name,label=label,
                            untilSkill=e,priced=alt.totalCost~=nil,
                            price=alt.totalCost,orange=alt.first==1 and alt.last==1,
                            learned=true,score=alt.totalCost or alt.count}
                    end
                end
                table.sort(other,function(a,b)
                    if mode=='fast' then
                        local ac,bc
                        for _,entry in ipairs(learnedAlternatives) do
                            if entry.candidate.id==a.recipeID then ac=entry.count end
                            if entry.candidate.id==b.recipeID then bc=entry.count end
                        end
                        if ac and bc and ac~=bc then return ac<bc end
                    end
                    if a.priced~=b.priced then return a.priced end
                    if a.priced and a.price~=b.price then return a.price<b.price end
                    return a.name<b.name
                end)
                local baselineName=baseline and baseline.name or name
                local seg={startSkill=s,endSkill=e,guideStart=left,guideEnd=right,
                    recipeID=chosen and chosen.id or nil,
                    professionID=chosen and chosen.professionID or nil,
                    name=chosen and chosen.name or name,recipe=recipe,
                    record=chosen and chosen.record or nil,
                    learned=chosen and chosen.learned or false,
                    snapshot=chosen and chosen.snapshot or nil,
                    requiredSkill=chosen and chosen.requiredSkill or nil,
                    trainerOnly=chosen and chosen.trainerOnly or false,
                    trainerSourceBorrowed=chosen and chosen.trainerSourceBorrowed or false,
                    requiredSkillBorrowed=chosen and chosen.requiredSkillBorrowed or false,
                    trainerNames=chosen and chosen.trainerNames or nil,
                    expectedCrafts=qty,quantity=qty,
                    estimatedChance=first or .0,endChance=last or .0,
                    tierColor=first==1 and last==1 and 'orange' or 'yellow',
                    guideSourceName=baselineName,guideReferenceEstimate=guideCrafts,
                    guideUnverified=not valid or not chosen or
                        (not overridden and acquisition=='trainer' and not chosen.trainerOnly) or
                        (chosen and not chosen.learned and (chosen.trainerSourceBorrowed or
                            chosen.requiredSkillBorrowed)),
                    guideMissingData=not chosen or not chosen.hasReagents,
                    guideBand=true,guideExpectedTrainer=acquisition=='trainer',overridden=overridden,
                    guideAcquisition=acquisition,guideAcquisitionNote=acquisitionNote,
                    conditionalUnlock=not overridden and (not chosen or
                        (not chosen.learned and (chosen.trainerSourceBorrowed or
                            chosen.requiredSkillBorrowed or not chosen.trainerOnly))),
                    alternatives=other,alternative=other[1]}
                if seg.guideUnverified or seg.guideMissingData then
                    plan.guideWarnings=plan.guideWarnings+1
                end
                if seg.alternative then
                    plan.alternativeCount=plan.alternativeCount+1
                    if seg.alternative.label:find('CHEAPER',1,true) then
                        plan.betterCostCount=plan.betterCostCount+1
                    end
                end
                if not seg.learned and seg.recipeID then
                    plan.requiresTraining=true
                    plan.trainerBreakpoints[#plan.trainerBreakpoints+1]={beforeSkill=s,
                        recipeID=seg.recipeID,name=seg.name,requiredSkill=seg.requiredSkill,
                        borrowed=seg.trainerSourceBorrowed or seg.requiredSkillBorrowed,
                        segment=seg}
                end
                for _,rank in ipairs(rankBreaks) do
                    if rank>=s and rank<e and (tonumber(plan.cap) or 0)<=rank then
                        seg.capBreak=rank
                    end
                end
                plan.segments[#plan.segments+1]=seg
                reached=e
            end
        end
        if reached>=target then break end
    end
    plan.reached=reached
    plan.complete=reached>=target
    if not plan.complete and not plan.stopReason then
        plan.stopReason='guide_coverage'
        plan.stopSkill=reached
        plan.notes[#plan.notes+1]='Curated '..profession..' guide currently ends at skill '..reached..
            '. A later guide release will cover additional verified recipes.'
    end
    if plan.guideWarnings>0 then
        plan.notes[#plan.notes+1]='Guide has '..plan.guideWarnings..' step(s) with incomplete or inconsistent live recipe data. Review in game before buying.'
    end
    if plan.alternativeCount>0 then
        plan.notes[#plan.notes+1]=plan.alternativeCount..' route band(s) have learned alternatives. Their prices are estimates from Auctionator, not guaranteed sales.'
    end
    -- Apply saved inventory and produced intermediate materials in craft order.
    local supplies,mat={},{ }
    local function Supply(id)
        if supplies[id]==nil then
            local r=self:GetInventoryEstimate(id,'all',owner)
            supplies[id]=max(0,tonumber(r and r.total) or 0)
        end
        return supplies[id]
    end
    plan.craftCount=0
    for _,seg in ipairs(plan.segments) do
        plan.craftCount=plan.craftCount+seg.quantity
        for _,r in ipairs(seg.recipe.reagents or {}) do
            local id=tonumber(r.itemID)
            if id then
                local needed=(tonumber(r.quantity) or 1)*seg.quantity
                local row=mat[id]
                if not row then
                    row={id=id,needed=0,owned=Supply(id),missing=0,produced=0}
                    mat[id]=row
                end
                local have=Supply(id)
                row.needed=row.needed+needed
                row.missing=row.missing+max(0,needed-have)
                supplies[id]=max(0,have-needed)
            end
        end
        local out=tonumber(seg.recipe.outputItemID)
        if out then
            local made=seg.quantity*max(1,tonumber(seg.recipe.quantityMin) or 1)
            supplies[out]=Supply(out)+made
            if mat[out] then mat[out].produced=mat[out].produced+made end
        end
    end
    local total,completePrices=0,true
    for id,row in pairs(mat) do
        row.price=self:GetTrainingAuctionPrice(id)
        if row.missing>0 then
            if row.price then total=total+row.missing*row.price
            else completePrices=false;plan.unknownQuotes=plan.unknownQuotes+1 end
        end
        plan.materials[#plan.materials+1]=row
    end
    table.sort(plan.materials,function(a,b)
        if a.missing~=b.missing then return a.missing>b.missing end
        return a.id<b.id
    end)
    plan.auctionFreshness=self:GetTrainingAuctionFreshness(plan.materials)
    -- A missing schematic means the numeric total is ONLY a lower bound.
    plan.estimatedMissingCost=completePrices and plan.guideWarnings==0 and total or nil
    plan.pricedCostFloor=total
    plan.guideVerified=plan.guideWarnings==0 and plan.complete
    plan.provisional=not plan.guideVerified
    plan.notes[#plan.notes+1]='Curated reference route, not a guaranteed cheapest path. Some professions require vendor formulas, manuals, targets or workstations; orange grants one point, yellow is probabilistic.'
    return plan
end
