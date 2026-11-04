-- v0.4.3.0: Evidence-based Atlas-to-Goals bridge.
-- A "known quests" target is a FIXED SNAPSHOT of recorded quest IDs, NOT
-- a claim that all quests available in a zone have been discovered.
local _, AF = ...
local function Now() return type(time)=='function' and time() or 0 end
local function ValidID(raw)
    local n=tonumber(raw)
    if n and n>0 and n==math.floor(n) and n<math.huge then return n end
end
local function RecordFor(self,key)
    local all=self.db and self.db.questRecords and self.db.questRecords.characters
    return type(all)=='table' and all[key] or nil
end
local function KeysForGoal(self,g)
    if g.scope=='all' then
        local seen,keys={},{}
        for _,name in ipairs({'questRecords','exploration'}) do
            local source=self.db and self.db[name]
            local records=type(source)=='table' and source.characters
            for key in pairs(type(records)=='table' and records or {}) do
                if not seen[key] then keys[#keys+1]=key;seen[key]=true end
            end
        end
        return keys
    end
    return g.characterKey and {g.characterKey} or {}
end
local function HasCompleted(r,id)
    if type(r)~='table' or type(r.completed)~='table' then return false end
    return r.completed[id]~=nil or r.completed[tostring(id)]~=nil
end
function AF:GetExplorationGoalState(p)
    local g=p and p.explorationGoal
    if type(g)~='table' then return nil end
    local keys=KeysForGoal(self,g)
    if g.kind=='visit' then
        local first,visitCount=nil,0
        for _,key in ipairs(keys) do
            local record=self.db.exploration and self.db.exploration.characters and self.db.exploration.characters[key]
            local zones=type(record)=='table' and record.zones or nil
            local z=zones and (zones[g.mapID] or zones[tostring(g.mapID)])
            if type(z)=='table' then
                local n=tonumber(z.firstSeen)
                if n and n>0 and (not first or n<first) then first=n end
                visitCount=visitCount+math.max(0,tonumber(z.visits) or 0)
            end
        end
        local visited=(visitCount>0 or first~=nil)
        return {current=visited and 1 or 0,total=1,complete=visited,
            detail=visited and ('Recorded visits: '..visitCount..' | First observed: '..(first and (type(date)=='function' and date('%b %d %Y',first) or 'recorded') or 'date unknown'))
                or 'Not yet recorded visiting this zone.',
            milestones={{id='visit',text='Visit '..tostring(g.zoneName or 'selected zone'),
                status=visited and 'confirmed' or 'pending',detail=visited and 'Zone visit recorded by Foundry.' or 'Awaiting an observed visit.'}}}
    end
    if g.kind=='quests' then
        local done,total=0,0
        local rows,seen={},{}
        local ids=type(g.questIDs)=='table' and g.questIDs or {}
        for _,raw in ipairs(ids) do
            local id=ValidID(raw)
            -- Preserve old goal snapshots, but don't double-count duplicate
            -- quest IDs from a malformed legacy saved list.
            if id and not seen[id] then
                seen[id]=true
                total=total+1
                local complete=false
                for _,key in ipairs(keys) do
                    if HasCompleted(RecordFor(self,key),id) then complete=true;break end
                end
                if complete then done=done+1 end
                rows[#rows+1]={id='quest:'..id,text=(type(g.titles)=='table' and (g.titles[id] or g.titles[tostring(id)])) or ('Quest #'..id),
                    status=complete and 'confirmed' or 'pending',detail='Recorded quest ID '..id..(complete and ' | Completed in saved records.' or ' | Not confirmed complete.')}
            end
        end
        return {current=done,total=total,complete=total>0 and done==total,
            detail=done..' / '..total..' recorded regional quest IDs completed. Snapshot only; not full zone completion.',
            milestones=rows}
    end
end
function AF:CreateExplorationGoal(mapID,kind,scope)
    if not self.db then return nil,'Addon data is not initialized.' end
    kind=kind=='quests' and 'quests' or 'visit'
    scope=scope=='all' and 'all' or 'character'
    local zoneID,info=self:GetAtlasZone(ValidID(mapID))
    if not zoneID or not info then return nil,'Select an individual zone on the Atlas first.' end
    local owner=scope=='character' and self:GetCurrentKey() or nil
    if scope=='character' and not owner then return nil,'Current character unavailable.' end
    local g={kind=kind,mapID=zoneID,zoneName=info.name,scope=scope,characterKey=owner,created=Now()}
    if kind=='quests' then
        local zones=self:GetQuestRecapZones(scope=='all' and 'all' or 'current','')
        local selected
        for _,z in ipairs(zones or {}) do
            if tonumber(z.mapID)==zoneID then selected=z;break end
        end
        if not selected then return nil,'No reliably located recorded quests for this zone yet.' end
        g.questIDs={};g.titles={}
        for raw,q in pairs(selected.quests or {}) do
            local id=ValidID(raw)
            if id then
                g.questIDs[#g.questIDs+1]=id
                g.titles[id]=q.title or ('Quest #'..id)
            end
        end
        table.sort(g.questIDs)
        if #g.questIDs==0 then return nil,'No reliably located recorded quests for this zone yet.' end
    end
    local project=self:AddProject()
    project.title=kind=='visit' and ('Visit '..info.name) or ('Complete known quests: '..info.name)
    project.description=kind=='visit' and
        'Auto-tracked using actual recorded Atlas visits. This is not 100% map exploration.' or
        'Auto-tracked fixed snapshot of quest IDs currently associated with this region. The denominator will not silently expand; this is not all available zone quests.'
    project.owner=owner
    project.explorationGoal=g
    local settings=self.db.settings and self.db.settings.guided
    if settings then
        settings.goalOrder=type(settings.goalOrder)=='table' and settings.goalOrder or {}
        table.insert(settings.goalOrder,1,project.id)
        settings.goalsView='Active'
    end
    self:SyncExplorationGoals(false) -- existing evidence can satisfy a new goal; never announce an old event
    if project.done and settings then settings.goalsView='Completed' end
    return project
end
function AF:SyncExplorationGoals(notify)
    if not self.db then return end
    local changed=false
    for _,p in ipairs(self.db.projects or {}) do
        if type(p.explorationGoal)=='table' and not p.done then
            local status=self:GetExplorationGoalState(p)
            if status and status.complete then
                p.done=true;p.updated=Now();p.completedAt=p.updated
                p.explorationGoal.completion={source='saved_evidence',at=p.updated,
                    note='Evidence first satisfied/recognized by the addon; this is not a historical quest completion date.'}
                changed=true
                if notify and self.UI and self.UI.ShowGoalToast then
                    self.UI:ShowGoalToast('Exploration Goal Complete!',p.title or 'Regional goal')
                end
            end
        end
    end
    if changed then
        if self.UI and self.UI.RefreshGoalTracker then self.UI:RefreshGoalTracker() end
        self:RefreshUI()
    end
end
