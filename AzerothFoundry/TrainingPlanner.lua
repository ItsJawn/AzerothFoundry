-- Azeroth Foundry: target-reaching profession training route planner.
-- Informational estimates ONLY. Never invokes protected crafting or trainer actions.
-- Prices are recorded Auctionator quotes, not live market availability.
local _, AF = ...
local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil

local function Safe(fn,...)
    if type(fn)~='function' then return nil end
    local ok,a,b,c,d=pcall(fn,...)
    if ok then return a,b,c,d end
    return nil
end
local function ExactTiers(value)
    if type(value)~='table' then return nil end
    local a=tonumber(value.orange or value.orangeSkill or value[1])
    local b=tonumber(value.yellow or value.yellowSkill or value[2])
    local c=tonumber(value.green or value.greenSkill or value[3])
    local d=tonumber(value.gray or value.grey or value.trivial or value[4])
    if not (a and b and c and d and a>=0 and a<=b and b<=c and c<=d and d<=1000) then return nil end
    -- Placeholder tiers are not a defensible basis for 50-skill projections.
    if a==b and b==c and c==d then return nil end
    return {a,b,c,d}
end
-- LibProfessionDB marks some unanchored DBC tiers with an orange threshold
-- of 1 when requiredSkill is missing. It explicitly documents this conjunction
-- as a placeholder, not evidence that a recipe is orange at skill 1.
local function ReliableTiers(value,requiredSkill,requiredBorrowed)
    local tiers=ExactTiers(value)
    if not tiers then return nil end
    -- In Forever an orange=1 start can be an UNANCHORED PLACEHOLDER when
    -- requiredSkill is absent or borrowed. That DOES NOT invalidate the
    -- measured yellow/green/gray transitions. Older code discarded the entire
    -- recipe, including perfectly usable yellow data, and made real trainer
    -- recipes disappear from the planner. Retain the thresholds, but never
    -- claim an unverified orange-start number is a confirmed learn level.
    tiers.unanchoredOrange=tiers[1]==1 and (tonumber(requiredSkill)==nil or requiredBorrowed) or false
    return tiers
end
local function SkillChance(tiers,skill)
    if not tiers or skill>=tiers[4] or skill<tiers[1] then return 0 end
    if skill<tiers[2] then return 1 end
    -- Training intentionally does NOT select green/gray recipes. Yellow
    -- probabilities are only estimates: interpolate within the YELLOW band
    -- instead of extending a near-gray probability curve through it. This
    -- keeps a yellow step at 50-100% and never claims fractional skill XP.
    if skill>=tiers[3] then return 0 end
    local width=tiers[3]-tiers[2]
    if width<=0 then return 0 end
    return max(.5,min(1,1-.5*(skill-tiers[2])/width))
end
local function SkillColor(tiers,skill)
    if not tiers or skill<tiers[1] or skill>=tiers[4] then return 'gray' end
    if skill<tiers[2] then return 'orange' end
    if skill<tiers[3] then return 'yellow' end
    return 'green'
end
-- Forever's yellow/green boundaries can be valid even when the orange
-- *starting* threshold is a placeholder. Before the yellow boundary, only
-- use an unanchored orange stage when the player's own LIVE profession scan
-- actually observed this learned recipe as orange (native enum 0).
-- For an unlearned recipe a borrowed trainer requirement is not proof that
-- it can be bought at that rank. Never label its hypothetical orange as 100%.
local function CandidateColor(candidate,skill)
    local color=SkillColor(candidate.tiers,skill)
    if color=='orange' and candidate.tiers and candidate.tiers.unanchoredOrange then
        if not (candidate.learned and candidate.nativeDifficulty==0
            and candidate.nativeCanSkillUp~=false) then
            return 'unknown'
        end
    end
    return color
end

-- Two different questions must not be conflated:
-- (1) would crafting this recipe give skill at the projected skill rank?
-- (2) can this character learn the recipe from a Forever trainer at that rank?
-- LibProfessionDB's Forever difficulty thresholds come from the game files,
-- but many trainer learn requirements are borrowed from Vanilla. A borrowed
-- requirement is a useful *lead*, NOT proof the recipe is actually offered.
-- When the evidence cannot confirm trainer availability, offer a clearly
-- CONDITIONAL preview rather than silently deleting all later orange recipes.
-- The UI must require a trainer visit + rescan before any queue export.
local function TrainingEligibility(candidate,skill,allowConditional)
    local color=CandidateColor(candidate,skill)
    local usableColor=color=='orange' or color=='yellow'
    local canLearn=candidate.learned or (candidate.requiredSkill and
        candidate.requiredSkill<=skill)
    if usableColor and canLearn then
        return color,SkillChance(candidate.tiers,skill),false
    end
    if not allowConditional or candidate.learned or not candidate.trainerOnly
        or not candidate.tiers then return nil,0,false end
    -- Only an unlearned trainer-only recipe may use this fallback, and only
    -- when the ambiguity is actually documented by the library. Recipes with
    -- a verified, higher Forever unlock requirement remain locked.
    local uncertainUnlock=candidate.requiredSkillBorrowed or
        candidate.requiredSkill==nil
    if not uncertainUnlock then return nil,0,false end
    if color=='unknown' and candidate.tiers.unanchoredOrange and
        skill>=candidate.tiers[1] and skill<candidate.tiers[2] then
        return 'orange',1,true
    end
    if usableColor then
        return color,SkillChance(candidate.tiers,skill),true
    end
    return nil,0,false
end

local function Coin(price)
    if not price then return 'unknown' end
    local g=floor(price/10000)
    local s=floor((price%10000)/100)
    local c=floor(price%100)
    return (g>0 and (g..'g ') or '')..(s>0 and (s..'s ') or '')..c..'c'
end
AF.TrainingFormatCoin=Coin

function AF:GetTrainingAuctionPrice(itemID)
    local api=type(Auctionator)=='table' and Auctionator.API and Auctionator.API.v1
    if type(api)~='table' or type(api.GetAuctionPriceByItemID)~='function' then return nil end
    local value=Safe(api.GetAuctionPriceByItemID,'AzerothFoundry',itemID)
    if type(value)=='number' and value>=0 and value<1e12 then return floor(value) end
    return nil
end

-- Trainer acquisition is checked against LibProfessionDB's explicit source kinds.
-- Forever inherits many of these classifications from Vanilla; mark them as
-- unconfirmed rather than telling a player a trainer definitely has a recipe.
 local function TrainerEvidence(lib,spellID)
    if not lib or not spellID then return false,false,nil end
    local kinds=Safe(lib.GetRecipeSourceKinds,lib,spellID)
    if type(kinds)~='table' then
        local sources=Safe(lib.GetRecipeSources,lib,spellID)
        if type(sources)=='table' then
            kinds={}
            for key,v in pairs(sources) do
                if type(v)=='table' and ((tonumber(v.total) or #v)>0) then kinds[key]=true end
            end
        end
    end
    if type(kinds)~='table' or not kinds.trainer then return false,false,nil end
    -- A recipe sold by a vendor or dropped in the world is not trainer-only.
    for key,v in pairs(kinds) do
        if key~='trainer' and v then return false,false,nil end
    end
    if type(lib.IsHiddenRecipe)=='function' and Safe(lib.IsHiddenRecipe,lib,spellID) then return false,false,nil end
    if type(lib.IsAutoTaughtRecipe)=='function' and Safe(lib.IsAutoTaughtRecipe,lib,spellID) then return false,false,nil end
    local borrowed=type(lib.IsBorrowed)=='function' and Safe(lib.IsBorrowed,lib,spellID,'sources') or nil
    local sources=Safe(lib.GetRecipeSources,lib,spellID)
    local names={}
    if type(sources)=='table' and type(sources.trainer)=='table' then
        for _,npc in ipairs(sources.trainer) do
            if type(npc)=='table' and type(npc.name)=='string' and npc.name~='' then
                names[#names+1]=npc.name
                if #names>=3 then break end
            end
        end
    end
    return true,(borrowed~=nil and borrowed~=false),names
end

-- Auctionator's price API is supported; a precise full-scan timestamp is NOT
-- part of its stable v1 contract. Some older builds expose the saved global.
-- Newer builds expose per-item price age; never present that as a full scan.
function AF:GetTrainingAuctionFreshness(materials)
    local stamp=tonumber(AUCTIONATOR_LAST_SCAN_TIME)
    local now=type(time)=='function' and time() or nil
    if stamp and now and stamp>1000000000 and stamp<=now+300 then
        local label=type(date)=='function' and date('%Y-%m-%d %H:%M',stamp) or tostring(stamp)
        return 'Last AH full scan: '..label,'full_scan'
    end
    local api=type(Auctionator)=='table' and Auctionator.API and Auctionator.API.v1
    if type(api)=='table' and type(api.GetAuctionAgeByItemID)=='function' then
        local youngest,oldest,checked=nil,nil,0
        for _,row in ipairs(materials or {}) do
            local id=tonumber(row.id or row.itemID)
            if id and checked<40 then
                local age=tonumber(Safe(api.GetAuctionAgeByItemID,'AzerothFoundry',id))
                checked=checked+1
                if age and age>=0 and age<=36500 then
                    youngest=youngest and min(youngest,age) or age
                    oldest=oldest and max(oldest,age) or age
                end
            end
        end
        if youngest then
            local newest=now and type(date)=='function' and date('%b %d',now-floor(youngest)*86400) or '?'
            return 'AH full scan: unavailable\nNewest price: ~'..newest..' ('..tostring(floor(youngest))..
                'd; oldest '..tostring(floor(oldest))..'d)','item_age'
        end
    end
    return 'AH full scan: unavailable\nPrice age not exposed by Auctionator','unknown'
end

-- Snapshot lookup is limited to the CHOSEN owner; nobody else's learned
-- recipes are silently considered available to this character.
function AF:GetTrainingCandidates(owner,profession,trainerOnly)
    local result,seen={},{}
    local lib=self:GetProfessionReference()
    local profIDs={}
    local snapshots=(self.db.recipeSnapshots or {})[owner] or {}
    for _,snap in pairs(snapshots) do
        if type(snap)=='table' and tostring(snap.professionName or ''):lower()==tostring(profession or ''):lower() then
            local pid=tonumber(snap.professionID)
            if pid then profIDs[pid]=snap end
            for _,record in pairs(snap.recipes or {}) do
                local id=type(record)=='table' and tonumber(record.id)
                if id and not seen[id] then
                    seen[id]=true
                    local recipe=self:GetRecipeDetails(snap,record)
                    local tiers
                    if lib then
                        local ref=self:GetRecipeReference(snap.professionID,id)
                        tiers=type(ref)=='table' and ReliableTiers(ref.difficulty,recipe.requiredSkill or ref.requiredSkill,recipe.requiredSkillBorrowed) or nil
                        if not tiers then
                            local a,b,c,d=Safe(lib.GetDifficulty,lib,snap.professionID,id)
                            tiers=ReliableTiers(type(a)=='table' and a or {a,b,c,d},recipe.requiredSkill,recipe.requiredSkillBorrowed)
                        end
                    end
                    local trainerOnlySource,borrowed,npcs=TrainerEvidence(lib,id)
                    local hasReagents=type(recipe.reagents)=='table' and #recipe.reagents>0
                        and recipe.reagentsIncomplete~=true
                    if hasReagents then
                        for _,r in ipairs(recipe.reagents) do
                            if not tonumber(r.itemID) or not tonumber(r.quantity) or r.quantity<1 then
                                hasReagents=false;break
                            end
                        end
                    end
                    result[#result+1]={id=id,name=recipe.name or ('Recipe #'..id),
                        learned=record.learned==true,professionID=snap.professionID,
                        snapshot=snap,record=record,recipe=recipe,tiers=tiers,
                        trainerOnly=trainerOnlySource,trainerSourceBorrowed=borrowed,
                        trainerNames=npcs,requiredSkill=tonumber(recipe.requiredSkill),
                        requiredSkillBorrowed=recipe.requiredSkillBorrowed~=nil and recipe.requiredSkillBorrowed~=false,
                        nativeDifficulty=tonumber(record.relativeDifficulty),
                        nativeCanSkillUp=record.canSkillUp,
                        hasReagents=hasReagents,outputCount=max(1,tonumber(recipe.quantityMin) or 1)}
                end
            end
        end
    end
    -- The scan only records a subset on some clients. LibProfessionDB provides
    -- unlearned recipes for the same profession OFFLINE. Never mistake a database
    -- entry for proof that this character learned it.
    if lib and type(lib.GetRecipes)=='function' then
        for pid,snap in pairs(profIDs) do
            local catalog=Safe(lib.GetRecipes,lib,pid)
            if type(catalog)=='table' then
                for key,value in pairs(catalog) do
                    -- GetRecipes has appeared as a spellID-indexed map and a list in
                    -- client databases. A numeric list VALUE is the spell ID,
                    -- never its sequence index (1, 2, 3 ...).
                    local id=(type(value)=='table' and tonumber(value.id or value.spellID or value.spellId))
                    local keyID=tonumber(key)
                    if not id and type(value)=='number' then
                        local valueID=tonumber(value)
                        -- A numerical list contains spell IDs as values; a
                        -- keyed numeric map may contain tiny counts/flags.
                        -- Probe the actual recipe map to disambiguate.
                        if type(lib.GetRecipe)=='function' then
                            local valueRef=Safe(lib.GetRecipe,lib,pid,valueID)
                            local keyRef=keyID and Safe(lib.GetRecipe,lib,pid,keyID)
                            id=type(valueRef)=='table' and valueID or
                                (type(keyRef)=='table' and keyID) or nil
                        end
                        if not id then id=(valueID and valueID>1000 and valueID) or keyID end
                    end
                    id=id or keyID
                    if id and not seen[id] then
                        seen[id]=true
                        local trainer,borrowed,npcs=TrainerEvidence(lib,id)
                        if trainer then
                            local record={id=id,learned=false,name=type(value)=='table' and value.name or nil}
                            local recipe=self:GetRecipeDetails(snap,record)
                            local ref=self:GetRecipeReference(pid,id)
                            local tiers=type(ref)=='table' and ReliableTiers(ref.difficulty,recipe.requiredSkill or ref.requiredSkill,recipe.requiredSkillBorrowed) or nil
                            if not tiers then
                                local a,b,c,d=Safe(lib.GetDifficulty,lib,pid,id)
                                tiers=ReliableTiers(type(a)=='table' and a or {a,b,c,d},recipe.requiredSkill,recipe.requiredSkillBorrowed)
                            end
                            local okMaterials=type(recipe.reagents)=='table' and #recipe.reagents>0 and
                                recipe.reagentsIncomplete~=true
                            if okMaterials then
                                for _,r in ipairs(recipe.reagents) do
                                    if not tonumber(r.itemID) or not tonumber(r.quantity) or r.quantity<1 then
                                        okMaterials=false;break
                                    end
                                end
                            end
                            local required=tonumber(recipe.requiredSkill)
                            local specialized=type(ref)=='table' and ref.specialization
                            -- A missing Forever learn rank can be considered
                            -- conditionally at the trainer, but is NEVER
                            -- interpreted as a confirmed unlock or queueable.
                            if (not required or (required>=0 and required<=999))
                                and not specialized then
                                result[#result+1]={id=id,name=recipe.name or ('Recipe #'..id),
                                    learned=false,professionID=pid,snapshot=snap,
                                    record=record,recipe=recipe,tiers=tiers,
                                    trainerOnly=true,trainerSourceBorrowed=borrowed,
                                    trainerNames=npcs,requiredSkill=required,
                                    requiredSkillBorrowed=recipe.requiredSkillBorrowed~=nil and recipe.requiredSkillBorrowed~=false,
                                    hasReagents=okMaterials,outputCount=max(1,tonumber(recipe.quantityMin) or 1)}
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(result,function(a,b) return a.name<b.name end)
    return result
end

local function CandidateCost(self,candidate)
    local knownCost=0
    local missing=0
    for _,r in ipairs(candidate.recipe.reagents or {}) do
        local price=self:GetTrainingAuctionPrice(r.itemID)
        if price then knownCost=knownCost+price*r.quantity
        else missing=missing+1 end
    end
    return knownCost,missing
end

function AF:CalculateTrainingPath(owner,profession,target,mode,overrides,preferences)
    local character=self.db and self.db.characters and self.db.characters[owner]
    local p=character and character.professions and character.professions[profession]
    if not p then return nil,'Select a recorded profession first.' end
    local current=floor(tonumber(p.skill) or 0)
    target=tonumber(target)
    if not target or target~=floor(target) or target<=current or target>999 then
        return nil,'Choose a whole-number goal above your current skill (maximum 999).'
    end
    preferences=type(preferences)=='table' and preferences or {}
    -- The explicit toggle defaults ON for callers that do not pass settings.
    local prioritizeOrange=preferences.prioritizeOrange~=false
    -- STRICT SOURCE FILTER: when ON, the source must be exclusively trainer.
    -- A recipe already learned from a dungeon, vendor, quest or world drop
    -- is NOT permitted. Unknown and mixed sources are excluded as well.
    -- When OFF, any learned recipe plus unlearned trainer-only candidates
    -- may compete in the same training calculation.
    local trainerOnly=preferences.trainerOnly~=false
    -- Green and gray crafts never count toward a training path in either mode.
    -- Yellow probabilities are estimates and are simulated per skill point.
    local minPracticalChance=.25
    local candidates=self:GetTrainingCandidates(owner,profession,trainerOnly)
    local hasLib=self:GetProfessionReference()~=nil
    local hasPrices=type(Auctionator)=='table' and type(Auctionator.API)=='table'
        and type(Auctionator.API.v1)=='table'
        and type(Auctionator.API.v1.GetAuctionPriceByItemID)=='function'
    local plan={characterKey=owner,profession=profession,current=current,target=target,
        cap=tonumber(p.maximum) or 0,mode=mode=='fast' and 'fast' or 'cheap',
        candidates=candidates,segments={},materials={},notes={},hasLib=hasLib,
        hasPrices=hasPrices,complete=false,estimated=true,unknownQuotes=0,
        prioritizeOrange=prioritizeOrange,trainerOnly=trainerOnly,
        trainerBreakpoints={},trainerUnconfirmed=0,minPracticalChance=minPracticalChance,
        fallbackSteps=0,lowConfidence=false,blockedSkill=nil,sourceDiagnostics={},
        provisional=false,provisionalSteps=0,provisionalRecipes={}}
    if not hasLib then
        plan.notes[#plan.notes+1]='Install/enable LibProfessionDB for skill-color thresholds across future levels.'
    end
    if not hasPrices then
        plan.notes[#plan.notes+1]='Optional: install Auctionator and scan the Auction House for material prices.'
    end
    if owner~=self:GetCurrentKey() then
        plan.notes[#plan.notes+1]='Offline crafter: learning states and inventory may be outdated.'
    end
    if plan.cap>0 and target>plan.cap then
        plan.notes[#plan.notes+1]='Trainer breakpoint at skill '..plan.cap..': train a higher profession rank before progressing.'
    end
    local usable={}
    for _,c in ipairs(candidates) do
        if (not trainerOnly or c.trainerOnly)
            and (c.learned or c.trainerOnly)
            and c.tiers and c.hasReagents then
            c.unitCost,c.unpriced=CandidateCost(self,c)
            usable[#usable+1]=c
        end
    end
    plan.sourceDiagnostics.all=#candidates
    plan.sourceDiagnostics.usable=#usable
    plan.sourceDiagnostics.excludedByTrainer=0
    plan.sourceDiagnostics.learnedSkillUps=0
    plan.sourceDiagnostics.learnedTrainerSkillUps=0
    plan.sourceDiagnostics.trainerSource=0
    plan.sourceDiagnostics.trainerMissingTiers=0
    plan.sourceDiagnostics.trainerMissingReagents=0
    plan.sourceDiagnostics.trainerAtCurrent=0
    plan.sourceDiagnostics.examples={}
    for _,c in ipairs(candidates) do
        local isObserved=c.learned and c.nativeCanSkillUp~=false
            and c.nativeDifficulty~=nil and c.nativeDifficulty<=2
        if isObserved then
            plan.sourceDiagnostics.learnedSkillUps=plan.sourceDiagnostics.learnedSkillUps+1
            if c.trainerOnly then
                plan.sourceDiagnostics.learnedTrainerSkillUps=plan.sourceDiagnostics.learnedTrainerSkillUps+1
            elseif #plan.sourceDiagnostics.examples<3 then
                plan.sourceDiagnostics.examples[#plan.sourceDiagnostics.examples+1]=c.name
            end
        end
        if c.trainerOnly then
            plan.sourceDiagnostics.trainerSource=plan.sourceDiagnostics.trainerSource+1
            if not c.tiers then plan.sourceDiagnostics.trainerMissingTiers=plan.sourceDiagnostics.trainerMissingTiers+1 end
            if not c.hasReagents then plan.sourceDiagnostics.trainerMissingReagents=plan.sourceDiagnostics.trainerMissingReagents+1 end
            if c.tiers and (CandidateColor(c,current)=='orange'
                or CandidateColor(c,current)=='yellow') then
                plan.sourceDiagnostics.trainerAtCurrent=plan.sourceDiagnostics.trainerAtCurrent+1
            end
        end
    end
    if trainerOnly then
        for _,c in ipairs(candidates) do
            if not c.trainerOnly then
                plan.sourceDiagnostics.excludedByTrainer=plan.sourceDiagnostics.excludedByTrainer+1
            end
        end
    end
    plan.sourceDiagnostics.trainer=0
    for _,c in ipairs(usable) do if c.trainerOnly then
        plan.sourceDiagnostics.trainer=plan.sourceDiagnostics.trainer+1 end end
    if #usable==0 then
        plan.stopReason='missing_data'
        plan.stopSkill=current
        plan.reached=current
        plan.notes[#plan.notes+1]=trainerOnly and
            'No verified trainer-only candidate has usable skill thresholds and complete materials. This does not mean your recorded recipes lack skill-ups: their trainer source or future difficulty data may be missing. See source diagnostics.' or
            'No usable learned or trainer-exclusive recipes with valid skill tiers and reagents. Scan the profession and update ProfessionDB.'
        return plan
    end
    -- Sequential skill-state simulation, NOT a one-time recipe ranking:
    -- at skill S, only eligible orange/yellow recipes compete. Score their
    -- expected craft counts and price, advance to S+1, then independently
    -- recalculate all candidate colors and trainer requirements at S+1.
    -- Each craft can give at most ONE skill point; expected attempts != XP.
    -- This is a per-skill heuristic, not a global material-production solver.
    overrides=type(overrides)=='table' and overrides or {}
    -- Choose recipes using expected market cost per skill point, *not* the
    -- availability of stock on hand. Apply recorded inventory to the final
    -- shopping list, where it cannot bias the training route itself.
    local rank=current
    local last
    local steepSteps=0
    local uncertainPriceSteps=0
    while rank<target do
        if plan.cap>0 and rank>=plan.cap then
            -- Current skill cap is a *training* breakpoint. A full future
            -- route may be previewed, but can never be exported until the
            -- player trains their next rank and recalculates.
            if not plan.rankBreakpoint then plan.rankBreakpoint=rank end
        end
        local options={}
        for _,c in ipairs(usable) do
            local color,chance,conditional=TrainingEligibility(c,rank,true)
            if chance>0 then
                local avg=1/chance
                local quoteComplete=c.unpriced==0
                local score
                if mode=='fast' or not hasPrices then
                    score=avg
                elseif quoteComplete then
                    -- Market price per EXPECTED skill, even for ingredients
                    -- already owned. Otherwise a cheap-looking depleted stock
                    -- drives the planner into poor near-gray skill recipes.
                    -- Owned inventory is applied later to the shopping list.
                    score=c.unitCost*avg
                else
                    score=avg
                end
                options[#options+1]={candidate=c,chance=chance,expected=avg,
                    color=color,conditional=conditional,
                    score=score,priced=quoteComplete,price=c.unitCost*avg}
            end
        end
        -- An unpriced competing recipe makes "cheapest" unknowable. Rather
        -- than automatically penalizing it and forcing costly near-gray
        -- crafts, optimize for expected craft count at this skill point.
        if mode~='fast' and hasPrices then
            local incomplete=false
            for _,choice in ipairs(options) do
                if not choice.priced then incomplete=true;break end
            end
            if incomplete then
                uncertainPriceSteps=uncertainPriceSteps+1
                for _,choice in ipairs(options) do choice.score=choice.expected end
            end
        end
        table.sort(options,function(a,b)
            -- Confirmed access outranks a hypothetical trainer unlock.
            -- Never discard a usable known yellow recipe just to show an
            -- unlearned/borrowed orange recipe as "guaranteed".
            if a.conditional~=b.conditional then return not a.conditional end
            if prioritizeOrange then
                local ranks={orange=0,yellow=1}
                local ac=ranks[a.color] or 3
                local bc=ranks[b.color] or 3
                if ac~=bc then return ac<bc end
            end
            if a.score~=b.score then return a.score<b.score end
            if a.expected~=b.expected then return a.expected<b.expected end
            return a.candidate.id<b.candidate.id
        end)
        if #options==0 then
            plan.stopReason='no_orange_yellow'
            plan.stopSkill=rank
            plan.blockedSkill=rank
            plan.notes[#plan.notes+1]='NO ORANGE/YELLOW RECIPE at skill '..rank..(trainerOnly and
                ' in strict trainer-only mode' or '')..'. The target stays '..target..
                ', but there is no documented eligible recipe for the next skill point. No green/gray grinding was substituted; verify trainer sources or turn off the strict filter.'
            break
        end
        -- A complete route is only claimed when every simulated step has a
        -- verified orange/yellow candidate. Never invent a trainer recipe.
        local bestChance=0
        for _,choice in ipairs(options) do bestChance=max(bestChance,choice.chance) end
        if bestChance<minPracticalChance then
            plan.fallbackSteps=plan.fallbackSteps+1
            plan.lowConfidence=true
        end
        local picked=options[1]
        local requested=tonumber(overrides[rank])
        if requested then
            for _,choice in ipairs(options) do
                if choice.candidate.id==requested then picked=choice;break end
            end
        end
        local alternative
        for _,choice in ipairs(options) do
            if choice.candidate.id~=picked.candidate.id then alternative=choice;break end
        end
        if picked.chance<minPracticalChance then steepSteps=steepSteps+1 end
        local pickedColor=picked.color
        if picked.conditional then
            plan.provisional=true
            plan.provisionalSteps=plan.provisionalSteps+1
            plan.provisionalRecipes[picked.candidate.id]=true
        end
        local same=last and last.recipeID==picked.candidate.id
            and last.tierColor==pickedColor -- split at orange -> yellow
            and last.conditionalUnlock==picked.conditional
            and last.endSkill==rank
            and last.capBreak~=rank and not (plan.cap>0 and rank==plan.cap)
        if same then
            last.endSkill=rank+1
            last.expectedCrafts=last.expectedCrafts+picked.expected
            last.endChance=picked.chance
            last.overridden=last.overridden or requested==picked.candidate.id
        else
            last={startSkill=rank,endSkill=rank+1,
                recipeID=picked.candidate.id,professionID=picked.candidate.professionID,
                name=picked.candidate.name,recipe=picked.candidate.recipe,
                record=picked.candidate.record,snapshot=picked.candidate.snapshot,
                estimatedChance=picked.chance,endChance=picked.chance,
                tierColor=pickedColor,
                expectedCrafts=picked.expected,
                alternative=alternative and {recipeID=alternative.candidate.id,
                    name=alternative.candidate.name,expected=alternative.expected,
                    priced=alternative.priced,price=alternative.price} or nil,
                priceKnown=picked.priced,unitPrice=picked.candidate.unitCost,
                overridden=requested==picked.candidate.id,
                learned=picked.candidate.learned,
                conditionalUnlock=picked.conditional,
                trainerOnly=picked.candidate.trainerOnly,
                unanchoredOrange=picked.candidate.tiers and picked.candidate.tiers.unanchoredOrange or false,
                trainerSourceBorrowed=picked.candidate.trainerSourceBorrowed,
                trainerNames=picked.candidate.trainerNames,
                requiredSkill=picked.candidate.requiredSkill,
                requiredSkillBorrowed=picked.candidate.requiredSkillBorrowed,
                capBreak=plan.cap>0 and rank==plan.cap and rank or nil}
            plan.segments[#plan.segments+1]=last
        end
        rank=rank+1
        if #plan.segments>75 then
            plan.stopReason='route_limit'
            plan.stopSkill=rank
            plan.notes[#plan.notes+1]='Route exceeds 75 separate recipe stages. Data is incomplete for a compact full route; no crafting list is exported.'
            break
        end
    end
    plan.reached=rank
    plan.complete=rank>=target
    if plan.complete and plan.rankBreakpoint then
        plan.notes[#plan.notes+1]='Before skill '..plan.rankBreakpoint..', visit the profession trainer to increase the recorded profession cap. Recalculate after training.'
    end
    -- Rebuild branch suggestions after grouping skills. Alternatives may be
    -- valid for only part of a stage; display their actual usable endpoint.
    -- Always leave a 'reset choice' path on manually overridden segments.
    for _,seg in ipairs(plan.segments) do
        local eligible={}
        for _,c in ipairs(usable) do
            local color,chance,conditional=TrainingEligibility(c,seg.startSkill,true)
            if c.id~=seg.recipeID and chance>0 then
                local untilSkill=min(seg.endSkill,c.tiers[3]) -- never override into green
                local expected=1/chance
                local score=(mode=='fast' or c.unpriced>0 or not hasPrices)
                    and expected or c.unitCost*expected
                eligible[#eligible+1]={recipeID=c.id,name=c.name,untilSkill=untilSkill,
                    expected=expected,priced=c.unpriced==0,price=c.unitCost*expected,
                    score=score,orange=color=='orange',conditional=conditional}
            end
        end
        table.sort(eligible,function(a,b)
            if a.conditional~=b.conditional then return not a.conditional end
            if prioritizeOrange then
                if a.orange~=b.orange then return a.orange end
            end
            if a.score~=b.score then return a.score<b.score end
            if a.untilSkill~=b.untilSkill then return a.untilSkill>b.untilSkill end
            return a.recipeID<b.recipeID
        end)
        seg.alternatives=eligible
        seg.alternative=eligible[1]
    end
    -- Any recipe the character has not learned is a stop, not a craft order.
    -- Group repeated use of one recipe into one explicit trainer visit.
    local trainerSeen={}
    for _,seg in ipairs(plan.segments) do
        if not seg.learned and not trainerSeen[seg.recipeID] then
            trainerSeen[seg.recipeID]=true
            local visit={beforeSkill=seg.startSkill,recipeID=seg.recipeID,
                name=seg.name,requiredSkill=seg.requiredSkill,
                borrowed=seg.trainerSourceBorrowed or seg.requiredSkillBorrowed,
                conditional=seg.conditionalUnlock,
                trainers=seg.trainerNames,segment=seg}
            plan.trainerBreakpoints[#plan.trainerBreakpoints+1]=visit
            if visit.borrowed then plan.trainerUnconfirmed=plan.trainerUnconfirmed+1 end
        end
    end
    plan.requiresTraining=#plan.trainerBreakpoints>0
    if plan.provisional then
        plan.notes[#plan.notes+1]='PROVISIONAL TRAINER ROUTE: '..tostring(plan.provisionalSteps)..
            ' skill step(s) require an unverified trainer unlock. Difficulty is from Forever, but trainer access or learn ranks are absent/borrowed. Visit the trainer, learn the recipe, rescan, then recalculate. NEVER buy materials or queue this preview as a confirmed path.'
    end
    if plan.requiresTraining then
        plan.notes[#plan.notes+1]='Trainer learning fees and trainer travel are not priced in the material-only gold estimate.'
        plan.notes[#plan.notes+1]='Route includes '..#plan.trainerBreakpoints..
            ' trainer visit(s); learn these recipes and rescan before queueing crafts.'
    end
    if plan.trainerUnconfirmed>0 then
        plan.notes[#plan.notes+1]='Trainer sources/requirements for '..plan.trainerUnconfirmed..
            ' step(s) are borrowed from Vanilla; verify availability in Forever.'
    end
    plan.lowChanceSteps=steepSteps
    plan.uncertainPriceSteps=uncertainPriceSteps
    if uncertainPriceSteps>0 then
        plan.notes[#plan.notes+1]='Incomplete auction prices at '..uncertainPriceSteps..' skill step(s): chose fewer expected crafts instead of guessing which recipe was cheapest.'
    end
    if steepSteps>0 then
        plan.notes[#plan.notes+1]='Unusually low yellow probability estimates: '..steepSteps..' skill step(s). Verify the recipe data.'
    end
    plan.craftCount=0
    local supplies={}
    local byMaterial={}
    local function Supply(id)
        if supplies[id]==nil then
            local estimate=self:GetInventoryEstimate(id,'all',owner)
            supplies[id]=max(0,tonumber(estimate.total) or 0)
        end
        return supplies[id]
    end
    -- Work forward through actual planned whole craft attempts. Outputs from
    -- earlier route steps are available as inputs to later steps. Still do not
    -- assume unknown reagents, unlearned recipes or alternative inputs.
    for _,seg in ipairs(plan.segments) do
        seg.quantity=max(1,ceil(seg.expectedCrafts-0.00001))
        plan.craftCount=plan.craftCount+seg.quantity
        for _,r in ipairs(seg.recipe.reagents or {}) do
            local id=tonumber(r.itemID)
            local need=r.quantity*seg.quantity
            local row=byMaterial[id]
            if not row then
                local record=self:GetInventoryEstimate(id,'all',owner)
                row={id=id,needed=0,owned=max(0,tonumber(record.total) or 0),
                    missing=0,produced=0,stockObserved=record.anyScanned==true}
                byMaterial[id]=row
            end
            local have=Supply(id)
            row.needed=row.needed+need
            row.missing=row.missing+max(0,need-have)
            supplies[id]=max(0,have-need)
        end
        local outputID=tonumber(seg.recipe.outputItemID)
        if outputID and outputID>0 then
            local yieldCount=max(1,tonumber(seg.recipe.quantityMin) or 1)
            supplies[outputID]=Supply(outputID)+seg.quantity*yieldCount
            local row=byMaterial[outputID]
            if row then row.produced=row.produced+seg.quantity*yieldCount end
        end
    end
    local materialRows={}
    local totalCost=0
    local priceComplete=true
    for id,row in pairs(byMaterial) do
        local price=self:GetTrainingAuctionPrice(id)
        row.price=price
        if row.missing>0 then
            if price then totalCost=totalCost+row.missing*price
            else priceComplete=false;plan.unknownQuotes=plan.unknownQuotes+1 end
        end
        materialRows[#materialRows+1]=row
    end
    table.sort(materialRows,function(a,b)
        if a.missing~=b.missing then return a.missing>b.missing end
        return a.id<b.id
    end)
    plan.materials=materialRows
    plan.auctionFreshness=self:GetTrainingAuctionFreshness(materialRows)
    plan.estimatedMissingCost=priceComplete and totalCost or nil
    plan.pricedCostFloor=totalCost
    if not priceComplete then
        plan.notes[#plan.notes+1]='Some required materials lack auction prices. Gold total and cheapest path are unverified.'
    end
    local unanchoredInRoute=0
    for _,seg in ipairs(plan.segments) do
        if seg.unanchoredOrange and seg.tierColor=='orange' then
            unanchoredInRoute=unanchoredInRoute+1
        end
    end
    plan.unanchoredInRoute=unanchoredInRoute
    if unanchoredInRoute>0 then
        plan.notes[#plan.notes+1]='The orange starting threshold for '..unanchoredInRoute..
            ' route stage(s) is unanchored in ProfessionDB. Difficulty transitions are present, but trainer unlock/learn skill must be confirmed in Forever.'
    end
    plan.notes[#plan.notes+1]='Only orange (guaranteed) and yellow (estimated chance) skill-ups are considered; green/gray are excluded.'
    plan.notes[#plan.notes+1]='Yellow chance estimates interpolate inside the yellow skill band; actual Forever probabilities are not confirmed.'
    plan.notes[#plan.notes+1]='Material totals credit outputs from earlier planned crafts. Inventory records and skill chances remain estimates.'
    return plan
end

-- In-order queue of estimates, only for a complete plan. Confirmation belongs
-- to the UI: avoid surprises, preserve the original Training Goal separately.
function AF:QueueTrainingPath(plan)
    if plan and plan.guideMode and not plan.guideVerified then
        return false,'Guide references must be verified with current recipe scans before queueing.'
    end
    if not plan or not plan.complete or #plan.segments==0 then
        return false,'The training route has unresolved steps.'
    end
    if plan.provisional then
        return false,'The route assumes unverified trainer unlocks. Visit the trainer and rescan before queueing.'
    end
    if plan.requiresTraining then
        return false,'Learn required trainer recipes and recalculate before queueing.'
    end
    if plan.rankBreakpoint then
        return false,'Train a higher profession rank and recalculate before queuing.'
    end
    if plan.lowConfidence then
        return false,'The route uses very low-chance crafts; verify a newer trainer recipe before queuing a large speculative batch.'
    end
    local segments=plan.segments
    if #segments>75 then return false,'Too many steps to queue safely.' end
    local jobs={}
    for _,seg in ipairs(segments) do
        if not seg.record or seg.record.learned~=true then
            return false,'A recipe is not learned; rescan before queueing.'
        end
        if plan.trainerOnly and not seg.trainerOnly then
            return false,'Trainer-only plan includes an unverified/non-trainer recipe; recalculate.'
        end
        if seg.tierColor~='orange' and seg.tierColor~='yellow' then
            return false,'Training plans may only queue orange or yellow skill-up recipes.'
        end
        local count=seg.quantity
        while count>0 do
            local chunk=min(count,99)
            jobs[#jobs+1]={scope='all',characterKey=plan.characterKey,
                professionID=seg.professionID,recipeID=seg.recipeID,
                quantity=chunk,recipeName=seg.name}
            count=count-chunk
            if #jobs>60 then return false,'Route exceeds safe queue size.' end
        end
    end
    local added=0
    for _,job in ipairs(jobs) do
        if self:AddQueuedCraft(job) then added=added+1 else
            return false,'Queue stopped after '..added..' entries; review the queue.'
        end
    end
    return true,'Added '..added..' estimated crafting batches in training order. Review materials and stop when skill goals are reached.'
end
