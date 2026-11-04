-- Azeroth Foundry v0.3.5.1: local, conservative guided milestones.
-- Reference recipes never prove a character has learned anything.  A goal's
-- explicit crafting result (or a user's manual choice) closes a craft goal.
local _, AF = ...
local function Now() return type(time)=='function' and time() or 0 end
local function Num(v) return tonumber(v) end
local function SafeClock() return Now()>0 and Now() or nil end

function AF:InitializeGuidedGoals()
    local db=self.db
    db.settings.guided=type(db.settings.guided)=='table' and db.settings.guided or {}
    local settings=db.settings.guided
    settings.tracked=type(settings.tracked)=='table' and settings.tracked or {}
    if settings.collapsed==nil then settings.collapsed=false end
    if settings.trackerVisible==nil then settings.trackerVisible=true end
    if settings.goalsView~='Active' and settings.goalsView~='Tracked' and settings.goalsView~='Completed' then
        settings.goalsView='Active'
    end
    settings.trackerWidth=math.max(240,math.min(720,tonumber(settings.trackerWidth) or 320))
    settings.trackerHeight=math.max(125,math.min(650,tonumber(settings.trackerHeight) or 195))
    -- Existing tracker IDs are retained; the old two-goal cap is removed.
    local used,clean={},{}
    for _,id in ipairs(settings.tracked) do
        if not used[id] and self:FindRecord(db.projects,id) then
            clean[#clean+1]=id;used[id]=true
        end
    end
    settings.tracked=clean
    db.schema=math.max(tonumber(db.schema) or 1,10)
    if type(settings.goalOrder)~='table' then
        -- Goals have an independent order; queue entries are never Goals.
        settings.goalOrder={}
        for i=#db.projects,1,-1 do
            local p=db.projects[i]
            settings.goalOrder[#settings.goalOrder+1]=p.id
        end
    end
    -- v0.3.5.1: Backfill completion provenance for existing completed goals.
    -- This is a quiet migration, not a new craft event. In particular, never
    -- trigger congratulations again merely because a saved goal was loaded.
    for _,project in ipairs(db.projects or {}) do
        local g=project.guided
        if g and project.done then
            g.milestoneSeen=type(g.milestoneSeen)=='table' and g.milestoneSeen or {}
            if not g.completion then
                local target=math.max(1,tonumber(g.quantity) or 1)
                local observed=g.kind=='craft' and (tonumber(g.crafted) or 0)>=target
                g.completion={source=observed and 'craft_result' or 'manual',
                    at=tonumber(project.updated) or SafeClock(),migrated=true}
            end
            -- Prevent new toast events for already-finished goals when data
            -- becomes available again after a reload or alt login.
            for _,m in ipairs(self:GuidedMilestones(project)) do
                if m.status=='confirmed' then g.milestoneSeen[m.id]=true end
            end
        end
        -- Copy only recorded completion timestamps from the prior Guided Goal
        -- evidence, after the 0.3.5.1 provenance migration has run. Ordinary
        -- legacy checklists remain completed with their date unrecorded.
        if project.done and not project.completedAt then
            project.completedAt=(g and g.completion and g.completion.at) or nil
        end
    end
    -- Existing ordinary and recipe-based projects are deliberately unchanged.
end

function AF:FindGuidedRecipe(g)
    if not g or not self.db then return nil end
    local byCharacter=self.db.recipeSnapshots and self.db.recipeSnapshots[g.characterKey]
    if not byCharacter then return nil end
    for _,snapshot in pairs(byCharacter) do
        if snapshot.professionID==g.professionID then
            local recipes=snapshot.recipes or {}
            local record=recipes[g.recipeID] or recipes[tostring(g.recipeID)]
            if not record then
                for _,entry in pairs(recipes) do
                    if entry.id==g.recipeID then record=entry;break end
                end
            end
            return snapshot,record
        end
    end
    return nil
end

function AF:GuidedMilestones(project)
    local g=project and project.guided
    if not g then return {} end
    local c=self.db.characters[g.characterKey]
    local snapshot,record=self:FindGuidedRecipe(g)
    local learned=record and record.learned==true or false
    local skill,skillObserved
    if c then
        local profession=(c.professions or {})[g.professionName]
        if profession then skill=tonumber(profession.skill); skillObserved=true end
    end
    local milestones={}
    local function Add(id,text,status,detail,required)
        milestones[#milestones+1]={id=id,text=text,status=status,detail=detail,required=required~=false}
    end
    if g.requiredSkill and g.requiredSkill>0 then
        Add('skill','Reach '..tostring(g.requiredSkill)..' '..(g.professionName or 'profession'),
            not skillObserved and 'unknown' or
                skill>=g.requiredSkill and (g.requiredSkillBorrowed and 'recorded' or 'confirmed') or 'pending',
            skillObserved and (skill..' / '..g.requiredSkill..(g.requiredSkillBorrowed and ' • unverified Forever reference' or '')) or 'Character profession not scanned')
    end
    if g.equipLevel and g.equipLevel>0 then
        local level=c and tonumber(c.level)
        Add('level','Reach level '..g.equipLevel..' to equip',
            not level and 'unknown' or level>=g.equipLevel and 'confirmed' or 'pending',
            level and (level..' / '..g.equipLevel) or 'Character not scanned',false)
    end
    Add('learn','Learn '..(g.recipeName or 'the recipe'),
        learned and 'confirmed' or (record and 'pending' or 'unknown'),
        learned and 'Learned on last profession scan' or (record and 'Not learned yet' or 'No recipe scan available'))
    if g.kind=='craft' then
        local ready={kind='unknown',label='Recipe not learned yet'}
        if learned and snapshot then
            ready=self:GetRecipeReadiness(snapshot,record,g.characterKey,g.scope,g.quantity or 1)
        end
        local got=math.max(0,tonumber(g.crafted) or 0)
        local target=math.max(1,tonumber(g.quantity) or 1)
        -- Inventory readiness is a *live* fact, whereas completing an item
        -- craft is historical proof that its ingredients were prepared.
        -- Consuming them must not undo a successfully earned milestone.
        local craftObserved=got>=target
        local finished=project.done==true
        local materialsStatus=(finished or craftObserved) and 'confirmed' or
            (ready.kind=='bags') and 'confirmed' or
            (ready.kind=='recorded') and 'recorded' or
            (ready.kind=='missing') and 'pending' or 'unknown'
        local materialsDetail=(finished or craftObserved) and
            (craftObserved and 'Satisfied by confirmed crafting; reagents were consumed.'
             or 'Satisfied by manual goal completion; crafting was not independently verified.')
            or ready.label
        Add('materials','Prepare crafting reagents',materialsStatus,materialsDetail)
        local craftDetail=(got>=target) and (got..' / '..target..' successfully crafted') or
            (finished and 'Marked complete by player; craft result not observed' or
                got..' / '..target..' crafted')
        Add('craft','Craft '..target..'x '..(g.recipeName or 'item'),
            (craftObserved or finished) and 'confirmed' or 'pending',craftDetail)
    end
    -- Completed goals are historical accomplishments. A profession unlearned
    -- later, expired inventory snapshot, or missing old recipe data must not
    -- reopen completed prerequisites. Never claim an old scan verified these:
    -- the detail explicitly distinguishes game-observed and manual endings.
    if project.done then
        local observed=(g.kind=='craft' and (tonumber(g.crafted) or 0)>=math.max(1,tonumber(g.quantity) or 1))
        for _,m in ipairs(milestones) do
            if m.required and m.status~='confirmed' then
                m.status='confirmed'
                m.detail=observed and 'Satisfied by the confirmed successful craft.'
                    or 'Accepted on completed goal (player-confirmed; not independently verified).'
            end
        end
    end
    return milestones
end

function AF:GuidedMilestoneSummary(project)
    local result=self:GuidedMilestones(project)
    local count,done=0,0
    for _,m in ipairs(result) do
        if m.required then
            count=count+1
            if m.status=='confirmed' then done=done+1 end
        end
    end
    return done,count,result
end

function AF:CreateGuidedGoal(snapshot,recipe,characterKey,kind,topPriority,scope)
    if not snapshot or not recipe or not characterKey or not self.db.characters[characterKey] then
        return nil,'Choose a scanned recipe and a registered character first.'
    end
    kind=(kind=='learn') and 'learn' or 'craft'
    scope=(scope=='expedition') and 'expedition' or 'all'
    if scope=='expedition' and not self:WorkshopCharacterAllowed(characterKey,scope) then
        return nil,'That character is not in the selected Expedition.'
    end
    local detail=self:GetRecipeDetails(snapshot,recipe)
    local output=detail.outputItemID and self:GetItemPresentation(detail.outputItemID)
    local p=self:AddProject()
    p.title=(kind=='learn' and 'Learn ' or 'Craft 1x ')..(recipe.name or 'recipe')
    p.owner=characterKey
    p.description='Guided goal • Created from the recorded Recipe Library.\nAdd your own notes using Edit Goal / Notes.'
    p.guided={kind=kind,characterKey=characterKey,recipeID=recipe.id,
        professionID=snapshot.professionID,professionName=snapshot.professionName,
        recipeName=recipe.name,outputItemID=detail.outputItemID,
        requiredSkill=tonumber(detail.requiredSkill),requiredSkillBorrowed=detail.requiredSkillBorrowed==true,
        equipLevel=output and tonumber(output.minLevel),
        scope=scope,quantity=1,crafted=0,created=SafeClock(),highPriority=topPriority==true,
        milestoneSeen={},events={}}
    if kind=='craft' and recipe.learned==true then
        p.crafting={scope=scope,recipeID=recipe.id,professionID=snapshot.professionID,
            quantity=1,routes={},created=SafeClock()}
    end
    if self.NormalizeCraftingQueue then self:NormalizeCraftingQueue() end
    -- Preserve one master priority sequence. Other projects remain in original
    -- insertion order until explicitly prioritized by their owner.
    local ordered=self.db.settings.guided.goalOrder
    if type(ordered)~='table' then ordered={};self.db.settings.guided.goalOrder=ordered end
    if topPriority then table.insert(ordered,1,p.id) else ordered[#ordered+1]=p.id end
    if kind=='craft' and topPriority and p.crafting then
        self:MoveCraftingProject(p.id,1)
    end
    -- Baseline prevents congratulating the player for already-known recipes.
    for _,m in ipairs(self:GuidedMilestones(p)) do
        p.guided.milestoneSeen[m.id]=(m.status=='confirmed')
    end
    self:RefreshUI()
    return p
end

function AF:GetGoalOrderedProjects()
    local out,seen={},{}
    local order=self.db.settings.guided and self.db.settings.guided.goalOrder or {}
    for _,id in ipairs(order) do
        local p=self:FindRecord(self.db.projects,id)
        if p and not seen[p.id] then out[#out+1]=p;seen[p.id]=true end
    end
    for i=#self.db.projects,1,-1 do
        local p=self.db.projects[i]
        if not seen[p.id] then out[#out+1]=p end
    end
    return out
end

-- Align crafting projects in the master goal order with the resource-priority
-- queue while retaining slots occupied by non-crafting personal goals.
-- Compatibility shim: queue priority no longer mutates the Goals order.
function AF:SyncCraftingGoalPriority()
    return false
end

function AF:PinGuidedGoal(id)
    local p=self:FindRecord(self.db.projects,id)
    if not p then return false,'Goal not found.' end
    local s=self.db.settings.guided
    local ids=s.tracked
    for i=#ids,1,-1 do
        if not self:FindRecord(self.db.projects,ids[i]) then table.remove(ids,i) end
    end
    for i,n in ipairs(ids) do
        if n==id then table.remove(ids,i); if self.UI and self.UI.RefreshGoalTracker then self.UI:RefreshGoalTracker() end; return true,'Untracked' end
    end
    ids[#ids+1]=id
    if self.UI and self.UI.RefreshGoalTracker then self.UI:RefreshGoalTracker() end
    return true,'Tracked'
end

-- All views share one database. Tracking is a separate flag from completion.
function AF:GetGoalsForView(view)
    view=(view=='Tracked' or view=='Completed') and view or 'Active'
    local result={}
    for _,project in ipairs(self:GetGoalOrderedProjects()) do
        if (view=='Active' and not project.done)
            or (view=='Completed' and project.done)
            or (view=='Tracked' and self:GoalIsPinned(project.id)) then
            result[#result+1]=project
        end
    end
    return result
end

local function CopyTable(source)
    if type(source)~='table' then return source end
    local copy={}
    for k,v in pairs(source) do copy[k]=CopyTable(v) end
    return copy
end

function AF:RepeatGoal(id)
    local old=self:FindRecord(self.db.projects,id)
    if not old or not old.done then return nil,'Select a completed goal.' end
    if old.expeditionMilestone then return nil,'Expedition milestones belong to one charter run and cannot be repeated.' end
    if old.guided and old.guided.kind=='learn' then
        return nil,'This recipe is already learned. Repeating a Learn Recipe goal would finish immediately.'
    end
    local repeated=self:AddProject()
    repeated.title=old.title
    repeated.description=old.description or ''
    repeated.owner=old.owner
    repeated.done=false
    repeated.tasks=CopyTable(old.tasks or {})
    repeated.personal=CopyTable(old.personal)
    if repeated.personal then repeated.personal.current=0 end
    for _,task in ipairs(repeated.tasks) do task.id=self:NextID();task.done=false end
    repeated.workshopGoal=nil -- Don't link to the same one-time skill objective.
    repeated.crafting=CopyTable(old.crafting)
    if repeated.crafting then repeated.crafting.created=Now() end
    repeated.guided=CopyTable(old.guided)
    if repeated.guided then
        repeated.guided.created=Now()
        repeated.guided.crafted=0
        repeated.guided.milestoneSeen={}
        repeated.guided.events={}
        repeated.guided.completion=nil
        repeated.guided.highPriority=false
        for _,milestone in ipairs(self:GuidedMilestones(repeated)) do
            if milestone.status=='confirmed' then
                repeated.guided.milestoneSeen[milestone.id]=true
            end
        end
    end
    repeated.completedAt=nil
    self.db.settings.guided.goalOrder[#self.db.settings.guided.goalOrder+1]=repeated.id
    if repeated.crafting then self:NormalizeCraftingQueue() end
    return repeated
end

function AF:GoalIsPinned(id)
    local g=self.db.settings.guided
    for _,value in ipairs(g.tracked or {}) do if value==id then return true end end
    return false
end

function AF:SyncGuidedGoals(allowNotifications)
    if not self.db or not self.db.projects then return end
    local changed=false
    for _,p in ipairs(self.db.projects) do
        local g=p.guided
        if g then
            local snapshot,recipe=self:FindGuidedRecipe(g)
            if snapshot and recipe then
                local info=self:GetRecipeDetails(snapshot,recipe)
                if info then
                    if not g.requiredSkill and info.requiredSkill then
                        g.requiredSkill=tonumber(info.requiredSkill)
                        g.requiredSkillBorrowed=info.requiredSkillBorrowed==true
                    end
                    if not g.outputItemID and info.outputItemID then
                        g.outputItemID=tonumber(info.outputItemID)
                    end
                    if not g.equipLevel and g.outputItemID then
                        local item=self:GetItemPresentation(g.outputItemID)
                        g.equipLevel=item and tonumber(item.minLevel) or nil
                    end
                end
            end
            if g.kind=='craft' and recipe and recipe.learned and not p.crafting and not p.done then
                p.crafting={scope=g.scope,recipeID=g.recipeID,professionID=g.professionID,
                    quantity=g.quantity or 1,routes={},created=SafeClock()}
                self:NormalizeCraftingQueue()
                if g.highPriority then self:MoveCraftingProject(p.id,1) end
                changed=true
            end
            g.milestoneSeen=type(g.milestoneSeen)=='table' and g.milestoneSeen or {}
            for _,m in ipairs(self:GuidedMilestones(p)) do
                if m.status=='confirmed' and not g.milestoneSeen[m.id] then
                    g.milestoneSeen[m.id]=true
                    -- A completion recorded in an earlier session is not a
                    -- *new* milestone. Keep history free of invented events.
                    if not p.done then
                        g.events=type(g.events)=='table' and g.events or {}
                        g.events[#g.events+1]={id=m.id,at=SafeClock(),name=m.text}
                        if allowNotifications and self.UI then
                            if self.UI.GoalMilestoneToast then self.UI:GoalMilestoneToast(p,m) end
                            if self.UI.MarkTrackerAttention then self.UI:MarkTrackerAttention(p.id) end
                        end
                    end
                    changed=true
                end
            end
            if g.kind=='learn' and not p.done then
                local _,_,all=self:GuidedMilestoneSummary(p)
                for _,m in ipairs(all) do
                    if m.id=='learn' and m.status=='confirmed' then
                        p.done=true;p.updated=Now();p.completedAt=p.updated;changed=true
                        break
                    end
                end
            end
        end
    end
    if changed then
        self:RefreshUI()
        if self.UI and self.UI.RefreshGoalTracker then self.UI:RefreshGoalTracker() end
    end
end

-- Craft-result events have an output item ID, but generally not a recipe ID.
-- Assign a matching result to ONE eligible incomplete crafting goal, ordered
-- by current crafting priority. Never credit unrelated results twice.
function AF:RecordGuidedCraftResult(data)
    if type(data)~='table' or not tonumber(data.itemID) or not self.db then return false end
    local id=tonumber(data.itemID)
    local count=tonumber(data.quantity)
    if not count or count<1 then return false end
    local n=math.max(1,math.floor(count))
    local key=self:GetCurrentKey()
    local candidates={}
    for _,p in ipairs(self.db.projects) do
        local g=p.guided
        if g and g.kind=='craft' and not p.done and g.characterKey==key
            and tonumber(g.outputItemID)==id then
            local _,recipe=self:FindGuidedRecipe(g)
            if recipe and recipe.learned then candidates[#candidates+1]=p end
        end
    end
    -- Goal priorities come from their own saved order, not the crafting queue.
    local goalPositions={}
    for i,p in ipairs(self:GetGoalOrderedProjects()) do goalPositions[p.id]=i end
    table.sort(candidates,function(a,b)
        return (goalPositions[a.id] or 99999)<(goalPositions[b.id] or 99999)
    end)
    local p=candidates[1]
    if not p then return false end
    local g=p.guided
    g.crafted=math.min(g.quantity or 1,(g.crafted or 0)+n)
    p.updated=Now()
    if g.crafted>=g.quantity then
        p.done=true;p.completedAt=Now()
        g.completion={source='craft_result',at=SafeClock(),itemID=id,quantity=g.crafted}
        self:SyncGuidedGoals(false)
        if self.UI and self.UI.ShowGoalToast then
            self.UI:ShowGoalToast('Goal Complete!',p.title or 'Crafted item')
        end
        if self.UI and self.UI.MarkTrackerAttention then self.UI:MarkTrackerAttention(p.id) end
    else
        self:SyncGuidedGoals(true)
    end
    return true
end
