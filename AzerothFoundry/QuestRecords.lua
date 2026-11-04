-- Azeroth Foundry v0.4.1.4: quest completion backfill and honest event history.
-- LibQuestDB is optional. Historical completion APIs do NOT provide completion dates.
local _, AF = ...
local function Clock() return type(time)=='function' and time() or 0 end
local function ValidID(v)
    v=tonumber(v)
    return v and v>0 and math.floor(v)==v and v or nil
end

function AF:GetQuestReference(questID)
    questID=ValidID(questID)
    if not questID then return nil end
    local lib
    if LibStub then
        local ok,result=pcall(LibStub,'LibQuestDB-1.0',true)
        if ok then lib=result end
    end
    if not lib then return nil end
    local entry={id=questID,source='LibQuestDB'}
    for _,field in ipairs({'GetQuest','GetQuestText','GetRewards'}) do
        if type(lib[field])=='function' then
            local ok,result=pcall(lib[field],lib,questID)
            if ok and type(result)=='table' then
                if field=='GetQuest' then entry.quest=result
                elseif field=='GetQuestText' then entry.text=result
                else entry.rewards=result end
            end
        end
    end
    if not entry.quest and not entry.text and not entry.rewards then return nil end
    return entry
end

function AF:InitializeQuestRecords()
    if not self.db then return end
    self.db.questRecords=type(self.db.questRecords)=='table' and self.db.questRecords or {}
    self.db.questRecords.characters=type(self.db.questRecords.characters)=='table' and self.db.questRecords.characters or {}
end

function AF:GetCharacterQuestRecords(key)
    if not self.db then return nil end
    self:InitializeQuestRecords()
    key=key or self:GetCurrentKey()
    local t=self.db.questRecords.characters
    if type(t[key])~='table' then t[key]={active={},completed={},history={}} end
    local r=t[key]
    r.active=type(r.active)=='table' and r.active or {}
    r.completed=type(r.completed)=='table' and r.completed or {}
    r.history=type(r.history)=='table' and r.history or {}
    r.dialogue=type(r.dialogue)=='table' and r.dialogue or {}
    return r
end

-- Persist the *zone* reported for a currently available quest. Forever's
-- GetQuestUiMapID can depend on the active character/log; an offline alt's
-- location cannot reliably be re-queried after a character switch.
-- Never infer a quest zone from the player's current position.
local function QuestZoneForActiveID(id)
    if not id then return nil end
    local raw
    if type(C_QuestLog)=='table' then
        for _,method in ipairs({'GetQuestUiMapID','GetQuestZoneID'}) do
            if type(C_QuestLog[method])=='function' then
                local ok,v=pcall(C_QuestLog[method],id)
                if ok and ValidID(v) then raw=ValidID(v);break end
            end
        end
    end
    if not raw and type(GetQuestUiMapID)=='function' then
        local ok,v=pcall(GetQuestUiMapID,id)
        if ok then raw=ValidID(v) end
    end
    if raw and type(AF.GetAtlasZone)=='function' then
        local ok,zone=pcall(AF.GetAtlasZone,AF,raw)
        if ok then return ValidID(zone) end
    end
end
local function StoreQuestZone(self,id,entry,zone)
    zone=ValidID(zone)
    if not zone then return end
    if type(entry)=='table' and not ValidID(entry.mapID) then entry.mapID=zone end
    local qdb=self.db and self.db.questRecords
    if qdb then
        qdb.questZones=type(qdb.questZones)=='table' and qdb.questZones or {}
        -- A known quest ID has a shared reference zone. The per-character
        -- snapshot is still authoritative when both are available.
        if not ValidID(qdb.questZones[id]) then qdb.questZones[id]=zone end
    end
end
function AF:CaptureQuestZone(id,entry)
    id=ValidID(id)
    if not id then return end
    local zone=QuestZoneForActiveID(id)
    if zone then StoreQuestZone(self,id,entry,zone) end
    return zone
end
-- Passive enrichment for saved active quests; does not add history entries.
function AF:CaptureCurrentQuestZones()
    if not self.db then return 0 end
    local rec=self:GetCharacterQuestRecords()
    local count=0
    for raw,quest in pairs(rec.active or {}) do
        local id=ValidID(raw) or (type(quest)=='table' and ValidID(quest.id))
        if id and type(quest)=='table' then
            if ValidID(quest.mapID) then
                StoreQuestZone(self,id,quest,quest.mapID)
                count=count+1
            elseif self:CaptureQuestZone(id,quest) then count=count+1 end
        end
    end
    return count
end


-- v0.4.2.5.1: Preserve original Forever quest prose as the client supplies it.
-- Unlike quest IDs or objectives, full text for newly added Forever quests
-- is often unavailable in third-party offline quest databases after turn-in.
local dialogueFields={story=true,objectives=true,progress=true,turnIn=true}
local function SaveDialogueField(entry,field,value)
    if not dialogueFields[field] or type(value)~='string' then return false end
    if not value:find('%S') or #value>16000 then return false end
    -- Do not let a later failed/shortened lookup overwrite known source text.
    if type(entry[field])=='string' and entry[field]:find('%S') then return false end
    entry[field]=value
    return true
end
function AF:CaptureQuestDialogue(id,source,fields)
    id=ValidID(id)
    if not id or type(fields)~='table' or not self.db then return false end
    local r=self:GetCharacterQuestRecords()
    local entry=type(r.dialogue[id])=='table' and r.dialogue[id] or {}
    local changed=false
    for field,value in pairs(fields) do
        if SaveDialogueField(entry,field,value) then changed=true end
    end
    if changed then
        entry.source='client'
        entry.firstCapturedAt=entry.firstCapturedAt or Clock()
        entry.lastCapturedAt=Clock()
        r.dialogue[id]=entry
    end
    return changed
end
function AF:CaptureQuestLogDialogue(id,index)
    id=ValidID(id)
    if not id or type(GetQuestLogQuestText)~='function' then return end
    if not (type(index)=='number' and index>0) and
        C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID)=='function' then
        local ok,result=pcall(C_QuestLog.GetLogIndexForQuestID,id)
        if ok then index=result end
    end
    if type(index)~='number' or index<1 then return end
    local ok,story,objectives=pcall(GetQuestLogQuestText,index)
    if ok then
        self:CaptureQuestDialogue(id,'quest-log',{story=story,objectives=objectives})
    end
end
function AF:CaptureQuestNPCDialogue(event)
    if type(GetQuestID)~='function' then return end
    local ok,id=pcall(GetQuestID)
    if not ok or not ValidID(id) then return end
    local function Read(fn)
        if type(fn)~='function' then return nil end
        local success,value=pcall(fn)
        return success and value or nil
    end
    if event=='QUEST_DETAIL' then
        self:CaptureQuestDialogue(id,'npc',{story=Read(GetQuestText),objectives=Read(GetObjectiveText)})
    elseif event=='QUEST_PROGRESS' then
        self:CaptureQuestDialogue(id,'npc',{progress=Read(GetProgressText)})
    elseif event=='QUEST_COMPLETE' then
        self:CaptureQuestDialogue(id,'npc',{turnIn=Read(GetRewardText)})
    end
end
function AF:GetRecordedQuestDialogue(id,owner)
    id=ValidID(id)
    if not id then return nil end
    local chars=self.db and self.db.questRecords and self.db.questRecords.characters
    if type(chars)~='table' then return nil end
    local preferred=owner or (self.GetCurrentKey and self:GetCurrentKey())
    local function Find(key)
        local r=chars[key]
        local dialogue=r and r.dialogue and r.dialogue[id]
        return type(dialogue)=='table' and dialogue or nil
    end
    local chosen=preferred and Find(preferred)
    if chosen then return chosen end
    -- Original quest text captured by an alt is useful as reference for the
    -- same quest ID. Never claim that this character personally saw it.
    for key in pairs(chars) do
        if key~=preferred then
            local found=Find(key)
            if found then return found end
        end
    end
end

-- Do not eagerly load thousands of quest descriptions during the backfill.
-- The client title lookup is optional and may return nil for uncached/hidden IDs.
function AF:GetQuestRecordTitle(id)
    id=ValidID(id)
    if not id then return nil end
    if C_QuestLog and type(C_QuestLog.GetTitleForQuestID)=='function' then
        local ok,title=pcall(C_QuestLog.GetTitleForQuestID,id)
        if ok and type(title)=='string' and title~='' then return title end
    end
    return nil
end

local function QuestLogRows()
    local rows={}
    if not C_QuestLog or type(C_QuestLog.GetNumQuestLogEntries)~='function' or type(C_QuestLog.GetInfo)~='function' then
        return nil,'Client quest log API not available'
    end
    local ok,count=pcall(C_QuestLog.GetNumQuestLogEntries)
    if not ok or type(count)~='number' then return nil,'Quest log count unavailable' end
    for i=1,math.min(count,1500) do
        local yes,info=pcall(C_QuestLog.GetInfo,i)
        if yes and type(info)=='table' and not info.isHeader then
            local id=ValidID(info.questID)
            if id then
                rows[id]={id=id,title=type(info.title)=='string' and info.title or ('Quest #'..id),
                    level=tonumber(info.level),isComplete=info.isComplete==true or info.isComplete==1,
                    logIndex=i}
            end
        end
    end
    return rows
end

local function LatestRecentEvent(history,id,now)
    -- QUEST_LOG_UPDATE can arrive immediately before QUEST_ACCEPTED; upgrade
    -- an initial observation instead of generating a false second acceptance.
    for i=#history,math.max(1,#history-12),-1 do
        local e=history[i]
        if e and e.id==id and e.kind=='observed' and type(e.at)=='number' and
            now>=e.at and now-e.at<=10 then
            return e
        end
    end
end

function AF:RecordQuestAccepted(a,b)
    local id=ValidID(b) or ValidID(a) -- Supports both Forever's and older Classic payloads.
    if not id or not self.db then return end
    local r=self:GetCharacterQuestRecords()
    local now=Clock()
    local active=r.active[id]
    local title=(active and active.title) or self:GetQuestRecordTitle(id) or ('Quest #'..id)
    local level=active and active.level
    -- Prevent a duplicate "Observed" entry when a quest-log scan ran first.
    local recent=LatestRecentEvent(r.history,id,now)
    if recent then
        recent.kind='accepted';recent.at=now;recent.title=title;recent.level=level or recent.level
    else
        r.history[#r.history+1]={id=id,kind='accepted',title=title,level=level,at=now}
    end
    self.pendingQuestAcceptances=self.pendingQuestAcceptances or {}
    self.pendingQuestAcceptances[id]=now
    if active then active.acceptedAt=active.acceptedAt or now end
    self:CaptureQuestZone(id,active)
end

function AF:ScanQuestRecords()
    if not self.db then return false,'Database not initialized' end
    local rows,errorText=QuestLogRows()
    if not rows then return false,errorText end
    local record=self:GetCharacterQuestRecords()
    local now=Clock()
    local previous=record.active
    local newlyObserved=0
    for id,row in pairs(rows) do
        local old=previous[id]
        local accepted=self.pendingQuestAcceptances and self.pendingQuestAcceptances[id]
        row.firstSeen=(old and old.firstSeen) or now
        row.acceptedAt=(old and old.acceptedAt) or accepted
        row.lastSeen=now
        row.mapID=(old and ValidID(old.mapID)) or
            (record.completed[id] and ValidID(record.completed[id].mapID))
        if ValidID(row.mapID) then
            StoreQuestZone(self,id,row,row.mapID)
        else
            self:CaptureQuestZone(id,row)
        end
        if not old and not accepted then
            newlyObserved=newlyObserved+1
            record.history[#record.history+1]={id=id,kind='observed',title=row.title,level=row.level,at=now}
        end
        -- Capture the *original* quest-log prose while this quest remains active.
        -- Unlike its objectives, a full Forever description may not be in LibQuestDB.
        if self.CaptureQuestLogDialogue then self:CaptureQuestLogDialogue(id,row.logIndex) end
        row.logIndex=nil -- transient scan metadata, not persistent record state
        if accepted then
            -- Refine the event title and level from the actual quest log.
            for i=#record.history,math.max(1,#record.history-12),-1 do
                local e=record.history[i]
                if e.id==id and e.kind=='accepted' then
                    e.title=row.title;e.level=row.level;break
                end
            end
            self.pendingQuestAcceptances[id]=nil
        end
        -- Ready to turn in is not the same as actually turned in.
        if row.isComplete and not record.completed[id] then row.readyToTurnIn=true end
    end
    record.active=rows
    record.lastScan=now
    local n=0 for _ in pairs(rows) do n=n+1 end
    return true,{active=n,observed=newlyObserved,confirmedTurnIns=0}
end

-- Returns a set of completed IDs. The new Forever API returns an array,
-- while GetQuestsCompleted() on older clients returns a questID-keyed table.
local function CompletedIDs()
    if C_QuestLog and type(C_QuestLog.GetAllCompletedQuestIDs)=='function' then
        local ok,ids=pcall(C_QuestLog.GetAllCompletedQuestIDs)
        if ok and type(ids)=='table' then
            local found={}
            for _,raw in pairs(ids) do
                local id=ValidID(raw)
                if id then found[id]=true end
            end
            return found
        end
    end
    if type(GetQuestsCompleted)=='function' then
        local ok,ids=pcall(GetQuestsCompleted)
        if ok and type(ids)=='table' then
            local found={}
            for raw,completed in pairs(ids) do
                local id=ValidID(raw)
                if id and completed then found[id]=true end
            end
            return found
        end
    end
    return nil,'No usable completed-quest API on this client'
end

function AF:BackfillCompletedQuestRecords()
    if not self.db then return false,'Database not initialized' end
    local found,why=CompletedIDs()
    if not found then return false,why end
    local r=self:GetCharacterQuestRecords()
    local now=Clock()
    local added,total=0,0
    for id in pairs(found) do
        total=total+1
        if not r.completed[id] then
            local active=r.active[id]
            local title=(active and active.title) or self:GetQuestRecordTitle(id)
            r.completed[id]={id=id,title=title or ('Quest #'..id),
                level=active and active.level,mapID=active and active.mapID,
                source='historical',recoveredAt=now}
            -- No fabricated turn-in event: the game does not expose when it happened.
            added=added+1
        elseif not r.completed[id].title or r.completed[id].title==('Quest #'..id) then
            local title=self:GetQuestRecordTitle(id)
            if title then r.completed[id].title=title end
        end
    end
    r.lastBackfillAt=now
    r.lastBackfillTotal=total
    r.lastBackfillAdded=added
    return true,{added=added,total=total}
end

function AF:RecordQuestTurnIn(id)
    id=ValidID(id)
    if not id or not self.db then return end
    local r=self:GetCharacterQuestRecords()
    local now=Clock()
    local active=r.active[id]
    local existing=r.completed[id]
    local title=(active and active.title) or (existing and existing.title)
        or self:GetQuestRecordTitle(id) or ('Quest #'..id)
    local level=(active and active.level) or (existing and existing.level)
    if not existing then
        existing={id=id,firstConfirmedAt=now,source='QUEST_TURNED_IN',timesTurnedIn=0}
        r.completed[id]=existing
    end
    existing.title=title
    existing.level=level
    existing.mapID=existing.mapID or (active and active.mapID)
    -- This is the last opportunity to capture an active quest's region.
    if not existing.mapID then self:CaptureQuestZone(id,existing) end
    existing.at=now
    existing.firstConfirmedAt=existing.firstConfirmedAt or now
    existing.lastConfirmedAt=now
    existing.source='QUEST_TURNED_IN'
    existing.timesTurnedIn=(tonumber(existing.timesTurnedIn) or 0)+1
    r.history[#r.history+1]={id=id,kind='turned-in',title=title,level=level,at=now}
    r.active[id]=nil
    if self.pendingQuestAcceptances then self.pendingQuestAcceptances[id]=nil end
end

function AF:QuestReferenceStatus()
    local lib
    if LibStub then local ok,value=pcall(LibStub,'LibQuestDB-1.0',true); if ok then lib=value end end
    local r=self:GetCharacterQuestRecords()
    local active,completed,recovered,dated=0,0,0,0
    if r then
        for _ in pairs(r.active) do active=active+1 end
        for _,q in pairs(r.completed) do
            completed=completed+1
            if q.source=='historical' then recovered=recovered+1 end
            if type(q.at)=='number' and q.at>0 then dated=dated+1 end
        end
    end
    return (lib and 'LibQuestDB connected' or 'LibQuestDB not installed (optional; live tracking works)')
        ..' | Active: '..active..' | Completed: '..completed
        ..' ('..recovered..' recovered, '..dated..' with known dates)'
end
