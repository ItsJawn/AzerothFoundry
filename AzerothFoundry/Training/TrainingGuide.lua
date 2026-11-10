-- Azeroth Foundry - curated training guides with optional personal comparisons.
-- Guide steps are editorial reference bands, NOT evidence of a learned recipe.
-- Curated reference data is maintained in Training/Guides/*.lua.
-- No gathering-only route is invented. Curated professions now cover 1-300.
-- Recipes requiring vendor patterns or rank books are explicitly flagged.
-- Learned alternative recipes NEVER silently replace the trainer baseline.
local _, AF = ...
local floor,ceil,max,min=math.floor,math.ceil,math.max,math.min

-- Each guide file contains independently maintained reference steps. The skill ranges
-- are targets, and the craft totals are conservative reference estimates;
-- the client may change thresholds and yellow skill-ups are probabilistic.
-- Avoid large descriptive passages from third-party guides in data packs.
-- Every entry: {skillFrom, skillTo, recipeName, estimatedCrafts, acquisition?, note?}
-- Built as native-to-Foundry reference milestones; live recipe data and
-- the player's learned list determine which requirements are confirmed.
-- Profession datasets are loaded separately from Training/Guides/*.lua.
-- Preserve the same AF.TrainingGuides table consumed by the UI and the route
-- calculator; saved goals and chosen alternatives do not need migration.
AF.TrainingGuides=AF.TrainingGuides or {}
local STEPS=AF.TrainingGuides

function AF:RegisterTrainingGuide(profession,entries)
    local key=tostring(profession or ''):lower()
    assert(key~='', 'Training guide registration requires a profession name')
    assert(type(entries)=='table' and #entries>0,
        'Training guide '..key..' requires an ordered list of milestone bands')
    assert(STEPS[key]==nil, 'Duplicate training guide: '..key)
    -- Reject malformed data at load time, not while rendering Training.
    local last
    for i,row in ipairs(entries) do
        assert(type(row)=='table' and type(row[1])=='number' and
            type(row[2])=='number' and row[2]>row[1] and
            type(row[3])=='string' and row[3]~='' and
            type(row[4])=='number' and row[4]>=0,
            'Invalid milestone '..i..' in training guide '..key)
        assert(not last or row[1]==last,
            'Skill gap or overlap at milestone '..i..' in training guide '..key)
        last=row[2]
    end
    STEPS[key]=entries
end
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
-- Price and skill-up comparisons should never promote a cheaper recipe that
-- requires worse skill-up odds. Both recipes must have usable evidence for every
-- skill point in this exact band; uncertain colors remain ordinary alternatives.
local function SameOrBetterSkillUps(baseline,alternative,startSkill,endSkill)
    if not baseline or not alternative or not baseline.tiers or not alternative.tiers then
        return false
    end
    for skill=startSkill,endSkill-1 do
        local base=GuideChance(baseline,skill)
        local other=GuideChance(alternative,skill)
        -- Green/gray and unknown odds do not qualify for a recommendation.
        if not base or not other or base<.5 or other<.5 or other+.000001<base then
            return false
        end
    end
    return true
end
local function Quote(self,c)
    local cost,missing=0,0
    if not c or not c.hasReagents then return nil end
    for _,r in ipairs(c.recipe.reagents or {}) do
        local q=self:GetTrainingMaterialQuote(r.itemID,r.quantity)
        if not q or q.cost==nil then missing=missing+1 else cost=cost+q.cost end
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
-- Presentation and guide-quality analysis only. These helpers MUST NOT merge
-- plan.segments: each simulated skill band remains the authoritative unit for
-- per-band crafting, route alternatives, skill-change events and queue export.
local function VisualIdentity(seg)
    if not seg then return nil end
    local id=tonumber(seg.recipeID)
    if id then return 'id:'..tostring(id) end
    return 'name:'..NameKey(seg.name or seg.guideSourceName)
end
local function VisualCompatible(a,b)
    if not a or not b or tonumber(a.endSkill)~=tonumber(b.startSkill) then return false end
    if VisualIdentity(a)~=VisualIdentity(b) then return false end
    if (a.guideAcquisition or 'trainer')~=(b.guideAcquisition or 'trainer') then return false end
    if (not not a.learned) ~= (not not b.learned) then return false end
    if (not not a.overridden) ~= (not not b.overridden) then return false end
    if (not not a.conditionalUnlock) ~= (not not b.conditionalUnlock) then return false end
    if (not not a.guideExpectedTrainer) ~= (not not b.guideExpectedTrainer) then return false end
    -- Do not conflate different vendor/manual unlocks even if their output
    -- happens to have the same display name.
    if tostring(a.guideAcquisitionNote or '')~=tostring(b.guideAcquisitionNote or '') then return false end
    return true
end
function AF:BuildTrainingGuideVisualGroups(plan)
    local segments=plan and plan.segments or {}
    local groups,indexMap,warnings={},{},{}
    for i,seg in ipairs(segments) do
        local previous=groups[#groups]
        if previous and VisualCompatible(previous.lastSegment,seg) then
            previous.endSkill=seg.endSkill
            previous.lastIndex=i
            previous.lastSegment=seg
            previous.crafts=previous.crafts+(tonumber(seg.quantity) or 0)
            previous.parts[#previous.parts+1]={index=i,segment=seg}
            previous.needsVerification=previous.needsVerification or seg.guideUnverified or seg.guideMissingData
            previous.unlearned=previous.unlearned or not seg.learned
        else
            previous={name=seg.name,startSkill=seg.startSkill,endSkill=seg.endSkill,
                firstIndex=i,lastIndex=i,firstSegment=seg,lastSegment=seg,
                crafts=tonumber(seg.quantity) or 0,
                parts={{index=i,segment=seg}},needsVerification=seg.guideUnverified or seg.guideMissingData,
                unlearned=not seg.learned}
            groups[#groups+1]=previous
        end
        indexMap[i]=#groups
        -- Deduplicate alternates by recipe ID: separate skill bands may have
        -- overlapping discovered options but should not inflate the badge.
        previous.alternateIDs=previous.alternateIDs or {}
        if (seg.recommendedAlternativeCount or 0)>0 then
            previous.recommendedBands=(previous.recommendedBands or 0)+1
        end
        if seg.selectedRecommended then
            previous.selectedRecommendedBands=(previous.selectedRecommendedBands or 0)+1
        end
        for _,alt in ipairs(seg.alternatives or {}) do
            local altID=tostring(alt.recipeID or alt.name or '?')
            if not previous.alternateIDs[altID] then
                previous.alternateIDs[altID]=alt
                previous.alternateCount=(previous.alternateCount or 0)+1
                previous.firstAlternative=previous.firstAlternative or alt
            end
            if alt.recommended then
                previous.firstRecommendedAlternative=previous.firstRecommendedAlternative or alt
            end
        end
    end
    local lastSeen={}
    for gi,g in ipairs(groups) do
        local skillSpan=(tonumber(g.endSkill) or 0)-(tonumber(g.startSkill) or 0)
        if skillSpan>=20 then
            warnings[#warnings+1]={code='LONG_STRETCH',groupIndex=gi,index=g.firstIndex,
                startSkill=g.startSkill,endSkill=g.endSkill,name=g.name,
                message=tostring(g.name)..' spans '..skillSpan..' skill points ('..
                    tostring(g.startSkill)..'-'..tostring(g.endSkill)..'); verify its orange/yellow thresholds.'}
        end
        local id=VisualIdentity(g.firstSegment)
        local old=lastSeen[id]
        if old and old.groupIndex~=gi then
            warnings[#warnings+1]={code='INTERRUPTED_REUSE',groupIndex=gi,index=g.firstIndex,
                startSkill=g.startSkill,endSkill=g.endSkill,name=g.name,
                message=tostring(g.name)..' returns at '..tostring(g.startSkill)..'-'..
                    tostring(g.endSkill)..' after another recipe (previously '..
                    tostring(old.startSkill)..'-'..tostring(old.endSkill)..'). Review the route choice.'}
        end
        lastSeen[id]={groupIndex=gi,startSkill=g.startSkill,endSkill=g.endSkill}
    end
    return groups,indexMap,warnings
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
    if not target or target~=floor(target) or target<=current or target>300 then
        return nil,'Choose a whole-number goal above your current skill (maximum 300).'
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
                                totalCost=quote and quote*count or nil,margin=margin,
                                sameOrBetterSkillUps=SameOrBetterSkillUps(baseline,c,s,e)}
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
                local selectedRecommended,selectedSavings=false,nil
                local recommendedInBand=0
                for _,alt in ipairs(learnedAlternatives) do
                    local savings=baselineTotal and alt.totalCost and
                        (baselineTotal-alt.totalCost) or nil
                    local recommended=savings~=nil and savings>0 and alt.sameOrBetterSkillUps
                    if chosen and alt.candidate.id==chosen.id then
                        if overridden and recommended then
                            selectedRecommended,selectedSavings=true,savings
                        end
                    else
                        local label='ALTERNATE LEARNED'
                        if recommended then
                            label='RECOMMENDED - SAVE '..self.TrainingFormatCoin(savings)
                            recommendedInBand=recommendedInBand+1
                        elseif savings and savings>0 then
                            -- The cheaper estimate alone is not proof of equal
                            -- skill gains. Always keep these branches neutral.
                            label='LOWER COST - SKILL ODDS DIFFER/UNKNOWN'
                        elseif alt.margin and alt.margin>0 then
                            label='POTENTIAL AH MARGIN +'..self.TrainingFormatCoin(alt.margin)..'/craft'
                        end
                        other[#other+1]={recipeID=alt.candidate.id,
                            name=alt.candidate.name,label=label,
                            untilSkill=e,priced=alt.totalCost~=nil,
                            price=alt.totalCost,orange=alt.first==1 and alt.last==1,
                            learned=true,score=alt.totalCost or alt.count,
                            savings=recommended and savings or nil,
                            recommended=not not recommended,
                            equalSkillUps=not not alt.sameOrBetterSkillUps}
                    end
                end
                table.sort(other,function(a,b)
                    if a.recommended~=b.recommended then return a.recommended end
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
                    alternatives=other,alternative=other[1],
                    recommendedAlternativeCount=recommendedInBand,
                    selectedRecommended=selectedRecommended,selectedSavings=selectedSavings}
                if seg.guideUnverified or seg.guideMissingData then
                    plan.guideWarnings=plan.guideWarnings+1
                end
                if seg.alternative or selectedRecommended then
                    plan.alternativeCount=plan.alternativeCount+1
                end
                if recommendedInBand>0 or selectedRecommended then
                    plan.betterCostCount=plan.betterCostCount+1
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
        plan.notes[#plan.notes+1]=plan.alternativeCount..' route band(s) have learned alternatives. Prices use Auctionator and vendor observations/reference prices; AH sales are not guaranteed.'
    end
    if plan.betterCostCount>0 then
        plan.notes[#plan.notes+1]=plan.betterCostCount..' band(s) have a cheaper learned alternative with equal or better estimated skill-up chances. Green recommendations are optional and use recorded prices that may change.'
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
        local quote=self:GetTrainingMaterialQuote(id,row.missing)
        row.price=quote and quote.unit or nil
        row.quoteSource=quote and quote.source or 'unknown'
        row.quoteReference=quote and quote.reference or false
        row.quoteCost=quote and quote.cost or nil
        if row.missing>0 then
            if quote and quote.cost~=nil then total=total+quote.cost
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
    plan.notes[#plan.notes+1]='Curated 1-300 reference route, not a guaranteed cheapest path. Some professions require vendor formulas, manuals, targets or workstations; orange grants one point, yellow is probabilistic.'
    -- Visual consolidation is not a crafting/calculation operation. Audit notes
    -- advise maintainers; they never change the selected recipe or queue.
    plan.displayGroups,plan.displayIndex,plan.routeAudit=self:BuildTrainingGuideVisualGroups(plan)
    return plan
end
