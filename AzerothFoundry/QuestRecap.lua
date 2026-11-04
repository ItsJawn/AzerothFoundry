-- Azeroth Foundry v0.4.2.3: navigable regional story and quest records.
-- No generated lore, no invented historical dates, no automatic SaveVariables migration.
local _, AF = ...
local function ID(raw)
    local id=tonumber(raw)
    if id and id>0 and id<math.huge and id==math.floor(id) then return id end
end
-- v0.4.2.5: older or partially damaged SavedVariables must not break the
-- Recap. Normalize timestamps before comparisons, sorting, date formatting,
-- or session clustering. Never fabricate a timestamp for undated completions.
local function Timestamp(raw)
    local at=tonumber(raw)
    if at and at>0 and at<math.huge and at==at and at<100000000000 then
        return at
    end
end
local function TableOrEmpty(value)
    return type(value)=='table' and value or {}
end
local function SortTitle(a,b)
    local x,y=tostring(a.title or ''):lower(),tostring(b.title or ''):lower()
    if x~=y then return x<y end
    return tostring(a.key or a.id or '')<tostring(b.key or b.id or '')
end
local function Matches(q,search)
    search=tostring(search or ''):lower():match('^%s*(.-)%s*$')
    return search=='' or tostring(q or ''):lower():find(search,1,true)~=nil
end
local function Owners(self,scope)
    local owners={}
    local questChars=TableOrEmpty(self.db and self.db.questRecords and self.db.questRecords.characters)
    local exploreChars=TableOrEmpty(self.db and self.db.exploration and self.db.exploration.characters)
    if scope=='all' then
        local unique={}
        for key in pairs(questChars) do unique[key]=true end
        for key in pairs(exploreChars) do unique[key]=true end
        for key in pairs(unique) do owners[#owners+1]=key end
        table.sort(owners,function(a,b) return tostring(a)<tostring(b) end)
    else
        local key=scope=='current' and self:GetCurrentKey() or scope
        if key then owners[1]=key end
    end
    return owners
end
function AF:GetQuestRecapScopes()
    if self.GetQuestBrowserScopes then return self:GetQuestBrowserScopes() end
    return {{key='current',label='This character'},{key='all',label='All recorded characters'}}
end
function AF:GetQuestRecapStories(scope,query)
    local chars=TableOrEmpty(self.db and self.db.questRecords and self.db.questRecords.characters)
    local merged={}
    for _,owner in ipairs(Owners(self,scope)) do
        local r=chars[owner]
        if type(r)=='table' then
            for _,kind in ipairs({'completed','active'}) do
                for raw,q in pairs(TableOrEmpty(r[kind])) do
                    local id=ID(raw) or (type(q)=='table' and ID(q.id))
                    if id and type(q)=='table' then
                        local e=merged[id]
                        if not e then
                            e={id=id,title=q.title or ('Quest #'..id),level=q.level,
                                owners={},completed=false,active=false,date=nil}
                            merged[id]=e
                        end
                        if (not e.title or e.title=='Quest #'..id) and q.title then e.title=q.title end
                        e.level=e.level or q.level
                        if kind=='completed' then
                            e.completed=true
                            local dated=Timestamp(q.at)
                            if dated and (not e.date or dated>e.date) then e.date=dated end
                        else e.active=true end
                        e.owners[owner]=true
                    end
                end
            end
        end
    end
    local entries={}
    for _,e in pairs(merged) do entries[#entries+1]=e end
    table.sort(entries,SortTitle)
    local rows={}
    if self.BuildQuestJournalGroups then
        local output=self:BuildQuestJournalGroups(entries,{})
        for _,row in ipairs(output or {}) do
            if row.rowType=='group' then
                local group=row.group
                local ids={}
                for _,member in ipairs(group.members or {}) do ids[#ids+1]=member.id end
                rows[#rows+1]={kind='story',key=row.groupKey,title=group.title,
                    ids=ids,groupKind=group.kind}
            elseif row.rowType=='quest' then
                rows[#rows+1]={kind='story',key='quest:'..row.id,title=row.title,ids={row.id}}
            end
        end
    else
        for _,e in ipairs(entries) do
            rows[#rows+1]={kind='story',key='quest:'..e.id,title=e.title,ids={e.id}}
        end
    end
    local shown={}
    for _,row in ipairs(rows) do
        local complete,active=0,0
        for _,id in ipairs(row.ids) do
            local e=merged[id]
            if e and e.completed then complete=complete+1 end
            if e and e.active and not e.completed then active=active+1 end
        end
        row.completed=complete;row.active=active;row.total=#row.ids
        local include=Matches(row.title,query)
        if not include then
            for _,id in ipairs(row.ids) do
                local e=merged[id]
                if e and (Matches(e.title,query) or Matches(tostring(id),query)) then include=true;break end
            end
        end
        if include then shown[#shown+1]=row end
    end
    table.sort(shown,SortTitle)
    return shown,merged
end
function AF:GetQuestRecapTimeline(scope,query)
    local result={}
    local quests=TableOrEmpty(self.db and self.db.questRecords and self.db.questRecords.characters)
    local exploration=TableOrEmpty(self.db and self.db.exploration and self.db.exploration.characters)
    for _,key in ipairs(Owners(self,scope)) do
        local q=quests[key]
        if type(q)=='table' then
            for i,event in ipairs(TableOrEmpty(q.history)) do
                if type(event)=='table' and ID(event.id) and Timestamp(event.at) then
                    local title=type(event.title)=='string' and event.title or ('Quest #'..event.id)
                    if Matches(title,query) or Matches(event.id,query) then
                        result[#result+1]={kind='quest',key='q:'..tostring(key)..':'..i,
                            questID=ID(event.id),title=title,questEvent=event.kind,
                            level=event.level,at=Timestamp(event.at),owner=key}
                    end
                end
            end
        end
        local ex=exploration[key]
        if type(ex)=='table' then
            for i,event in ipairs(TableOrEmpty(ex.history)) do
                if type(event)=='table' and Timestamp(event.at) then
                    local name=type(event.name)=='string' and event.name or 'Visited zone'
                    if Matches(name,query) then
                        result[#result+1]={kind='visit',key='v:'..tostring(key)..':'..i,
                            mapID=ID(event.mapID),title=name,at=Timestamp(event.at),owner=key}
                    end
                end
            end
        end
    end
    table.sort(result,function(a,b)
        if a.at~=b.at then return a.at>b.at end
        return a.key>b.key
    end)
    return result
end
-- Only client-supplied quest map IDs are accepted. Do not infer locations from
-- quest text/NPC names; a quest can send the player to several different areas.
local questMapCache={}
function AF:ClearRecapQuestMapCache() questMapCache={} end
function AF:GetRecapQuestZoneID(questID)
    questID=ID(questID)
    if not questID then return nil end
    if questMapCache[questID] then return questMapCache[questID] end
    local mapID
    if C_QuestLog then
        for _,method in ipairs({'GetQuestUiMapID','GetQuestZoneID'}) do
            if type(C_QuestLog[method])=='function' then
                local ok,result=pcall(C_QuestLog[method],questID)
                if ok and ID(result) then mapID=ID(result);break end
            end
        end
    end
    if not mapID and type(GetQuestUiMapID)=='function' then
        local ok,result=pcall(GetQuestUiMapID,questID)
        if ok then mapID=ID(result) end
    end
    local zone=mapID and self.GetAtlasZone and self:GetAtlasZone(mapID)
    -- Do not memoize misses: a quest may become available after a log update
    -- or when the player switches character.
    if zone then questMapCache[questID]=zone end
    return zone
end
-- Compact dated sessions without losing underlying events. Consecutive or
-- repeated visits to a zone during one calendar day become one expandable
-- record, with every actual visit timestamp retained in visitTimes.
local function DayOf(at)
    if type(date)=='function' then
        -- Client date() can reject out-of-range legacy timestamps. A readable
        -- fallback is safer than losing the entire timeline UI.
        local ok,key=pcall(date,'%Y-%m-%d',at)
        local ok2,label=pcall(date,'%d %b %Y',at)
        if ok and ok2 and type(key)=='string' and type(label)=='string' then
            return key,label
        end
    end
    local day=tostring(math.floor((tonumber(at) or 0)/86400))
    return day,'Recorded day '..day
end
function AF:GetQuestRecapTimelineDays(scope,query,openDays)
    local events=self:GetQuestRecapTimeline(scope,query)
    local dayIndex,days={},{}
    for _,event in ipairs(events) do
        local key,label=DayOf(event.at)
        local day=dayIndex[key]
        if not day then
            day={key=key,title=label,events={},visitGroups={},visits=0,quests=0,
                newest=event.at,oldest=event.at}
            dayIndex[key]=day;days[#days+1]=day
        end
        if event.at<day.oldest then day.oldest=event.at end
        if event.kind=='visit' and event.mapID then
            local visitKey=tostring(event.owner)..':'..event.mapID
            local existing=day.visitGroups[visitKey]
            if not existing then
                existing={kind='visit-group',key='visits:'..key..':'..visitKey,
                    title=event.title,owner=event.owner,mapID=event.mapID,
                    at=event.at,visitTimes={},count=0}
                day.visitGroups[visitKey]=existing
                day.events[#day.events+1]=existing
            end
            existing.count=existing.count+1
            existing.visitTimes[#existing.visitTimes+1]=event.at
            day.visits=day.visits+1
        else
            day.events[#day.events+1]=event
            if event.kind=='quest' then day.quests=day.quests+1
            else day.visits=day.visits+1 end
        end
    end
    local rows={}
    for i,day in ipairs(days) do
        local opened=(openDays and openDays[day.key])
        if opened==nil then opened=(i==1 or (query and query~='')) end
        local header={kind='day',dayKey=day.key,key='day:'..day.key,
            title=day.title,at=day.newest,dayEvents=day.quests+day.visits,
            questEvents=day.quests,zoneVisits=day.visits,opened=opened}
        rows[#rows+1]=header
        if opened then
            table.sort(day.events,function(a,b)
                if a.at~=b.at then return a.at>b.at end
                return a.key>b.key
            end)
            for _,event in ipairs(day.events) do rows[#rows+1]=event end
        end
    end
    return rows,#events,#days
end


-- v0.4.2.4: An inferred activity session is a cluster of *recorded events*
-- for one character on one local calendar day, separated from another
-- cluster by more than 90 minutes. It is NOT evidence of actual login/logout
-- or total game-play duration. No historical quest completion is dated here.
local SESSION_GAP_SECONDS=90*60
function AF:GetQuestRecapTimelineSessions(scope,query,openDays,openSessions)
    -- Session boundaries must be computed on ALL known dated events, not on
    -- the filtered subset. Otherwise searching for a quest would silently
    -- change the inferred sessions and imply different play history.
    local complete=self:GetQuestRecapTimeline(scope,'')
    local matching={}
    if query and tostring(query):match('%S') then
        for _,e in ipairs(self:GetQuestRecapTimeline(scope,query)) do
            matching[e.key]=true
        end
    end
    local byOwner={}
    for _,event in ipairs(complete) do
        local owner=tostring(event.owner or '')
        byOwner[owner]=byOwner[owner] or {}
        byOwner[owner][#byOwner[owner]+1]=event
    end
    local candidates={}
    for owner,events in pairs(byOwner) do
        table.sort(events,function(a,b)
            if a.at~=b.at then return a.at<b.at end
            return a.key<b.key
        end)
        local last
        for _,event in ipairs(events) do
            local dayKey=DayOf(event.at)
            if not last or last.dayKey~=dayKey or event.at-last.lastAt>SESSION_GAP_SECONDS then
                last={kind='session',owner=owner,dayKey=dayKey,
                    key='session:'..owner..':'..dayKey..':'..tostring(event.at)..':'..event.key,
                    startAt=event.at,lastAt=event.at,events={}}
                candidates[#candidates+1]=last
            end
            last.events[#last.events+1]=event
            last.lastAt=event.at
        end
    end
    local daysByKey,days={},{}
    local eventTotal,sessionTotal=0,0
    for _,session in ipairs(candidates) do
        local visible={}
        for _,event in ipairs(session.events) do
            if not (query and tostring(query):match('%S')) or matching[event.key] then
                visible[#visible+1]=event
            end
        end
        if #visible>0 then
            local label=DayOf(session.startAt)
            local day=daysByKey[session.dayKey]
            if not day then
                day={key=session.dayKey,title=select(2,DayOf(session.startAt)),sessions={},
                    events=0,visits=0,quests=0,newest=session.lastAt}
                daysByKey[session.dayKey]=day
                days[#days+1]=day
            end
            day.sessions[#day.sessions+1]=session
            if session.lastAt>day.newest then day.newest=session.lastAt end
            session.visibleEvents=visible
            session.questEvents=0;session.zoneVisits=0;session.zoneNames={}
            local zones={}
            for _,e in ipairs(visible) do
                if e.kind=='quest' then session.questEvents=session.questEvents+1
                else
                    session.zoneVisits=session.zoneVisits+1
                    local zoneKey=e.mapID and tostring(e.mapID) or tostring(e.title)
                    if not zones[zoneKey] then
                        zones[zoneKey]=true
                        session.zoneNames[#session.zoneNames+1]=e.title
                    end
                end
            end
            table.sort(session.zoneNames)
            session.eventCount=#visible
            day.events=day.events+#visible
            day.quests=day.quests+session.questEvents
            day.visits=day.visits+session.zoneVisits
            eventTotal=eventTotal+#visible
            sessionTotal=sessionTotal+1
        end
    end
    table.sort(days,function(a,b)
        if a.newest~=b.newest then return a.newest>b.newest end
        return a.key>b.key
    end)
    local rows={}
    for i,day in ipairs(days) do
        local opened=openDays and openDays[day.key]
        if opened==nil then opened=(i==1 or (query and query~='')) end
        rows[#rows+1]={kind='day',key='day:'..day.key,dayKey=day.key,
            title=day.title,at=day.newest,dayEvents=day.events,
            questEvents=day.quests,zoneVisits=day.visits,
            sessionCount=#day.sessions,opened=opened}
        if opened then
            table.sort(day.sessions,function(a,b)
                if a.lastAt~=b.lastAt then return a.lastAt>b.lastAt end
                return a.key>b.key
            end)
            for j,session in ipairs(day.sessions) do
                local sessionOpened=openSessions and openSessions[session.key]
                if sessionOpened==nil then sessionOpened=(j==1) end
                session.opened=sessionOpened
                session.at=session.lastAt
                session.title='Recorded activity — '..tostring(session.owner)
                rows[#rows+1]=session
                if sessionOpened then
                    local eventRows,visitGroups={},{}
                    for _,event in ipairs(session.visibleEvents) do
                        if event.kind=='visit' and event.mapID then
                            local key=tostring(event.mapID)
                            local group=visitGroups[key]
                            if not group then
                                group={kind='visit-group',key='visit-session:'..session.key..':'..key,
                                    title=event.title,owner=event.owner,mapID=event.mapID,
                                    at=event.at,count=0,visitTimes={}}
                                visitGroups[key]=group
                                eventRows[#eventRows+1]=group
                            end
                            group.count=group.count+1
                            group.visitTimes[#group.visitTimes+1]=event.at
                            if event.at>group.at then group.at=event.at end
                        else
                            eventRows[#eventRows+1]=event
                        end
                    end
                    table.sort(eventRows,function(a,b)
                        if a.at~=b.at then return a.at>b.at end
                        return a.key>b.key
                    end)
                    for _,event in ipairs(eventRows) do
                        if event.kind=='visit-group' then
                            table.sort(event.visitTimes,function(a,b) return a>b end)
                        end
                        rows[#rows+1]=event
                    end
                end
            end
        end
    end
    return rows,eventTotal,#days,sessionTotal
end

-- LibQuestDB zoneOrSort stores an AreaTable ID, NOT a UIMapID. A name can
-- link that area to a validated zone map; raw numeric IDs must never be
-- treated as interchangeable (important on WoW Forever's new maps).
local function LibQuest()
    if not LibStub then return nil end
    -- LibStub is commonly a callable table, not a Lua function.
    local ok,lib=pcall(function()
        if type(LibStub)=='table' and type(LibStub.GetLibrary)=='function' then
            return LibStub:GetLibrary('LibQuestDB-1.0',true)
        elseif type(LibStub)=='function' then
            return LibStub('LibQuestDB-1.0',true)
        end
    end)
    return ok and type(lib)=='table' and lib or nil
end
local function CleanName(name)
    if type(name)~='string' then return nil end
    return name:lower():gsub('^%s+',''):gsub('%s+$',''):gsub('%s+',' ')
end
local function AreaName(areaID,lib)
    if type(C_Map)=='table' and type(C_Map.GetAreaInfo)=='function' then
        local ok,result=pcall(C_Map.GetAreaInfo,areaID)
        if ok and type(result)=='string' and result~='' then return result end
    end
    if lib and type(lib.GetArea)=='function' then
        local ok,result=pcall(lib.GetArea,lib,areaID)
        if ok and type(result)=='table' then return result.name or result.title end
        if ok and type(result)=='string' and result~='' then return result end
    end
end
local function MapInfoFor(self,mapID)
    return self.GetAtlasMapInfo and self:GetAtlasMapInfo(mapID) or nil
end
local function KnownZones(self,existing)
    -- Match by verified names across visited zones and accessible continent
    -- children. Exploration is not required before a quest can have a region.
    local byName,ambiguous={},{}
    local function Add(id,name)
        id=ID(id);if not id then return end
        local info=MapInfoFor(self,id)
        if not info or info.mapType~=3 then return end
        local normalized=CleanName(name or info.name)
        if normalized then
            if byName[normalized] and byName[normalized]~=id then ambiguous[normalized]=true
            else byName[normalized]=id end
        end
    end
    for id,z in pairs(existing) do Add(id,z.title) end
    local continents={}
    if type(self.GetAtlasContinents)=='function' then
        local ok,list=pcall(self.GetAtlasContinents,self)
        if ok and type(list)=='table' then
            for _,info in ipairs(list) do
                continents[#continents+1]=info.mapID or info.key
            end
        end
    end
    for _,id in ipairs({1414,1415,12,13}) do continents[#continents+1]=id end
    local seen={}
    if type(self.GetAtlasMapChildren)=='function' then
        for _,continent in ipairs(continents) do
            if ID(continent) and not seen[continent] then
                seen[continent]=true
                local ok,children=pcall(self.GetAtlasMapChildren,self,continent)
                if ok and type(children)=='table' then
                    for _,child in ipairs(children) do
                        Add(child.mapID or child.key,child.label)
                    end
                end
            end
        end
    end
    for name in pairs(ambiguous) do byName[name]=nil end
    return byName
end
local function DatabaseArea(lib,questID)
    if not lib or type(lib.GetQuest)~='function' then return nil end
    local ok,q=pcall(lib.GetQuest,lib,questID)
    if not ok or type(q)~='table' then return nil end
    -- positive IDs = world AreaTable areas; negative = categories/sorts.
    return ID(q.zoneOrSort or q.zoneID or q.areaID)
end
-- Prefer persisted per-character quest regions over current-client lookups.
-- An account-wide view must work after the character who recorded a quest
-- has logged out. Source names tell the player where the match came from.
local function StoredQuestRegions(self,id,owners)
    local qdb=self.db and self.db.questRecords or {}
    local byOwner=qdb.characters or {}
    local found={}
    local seen={}
    for _,owner in ipairs(owners) do
        local rec=byOwner[owner]
        if type(rec)=='table' then
            for _,kind in ipairs({'active','completed'}) do
                local q=type(rec[kind])=='table' and rec[kind][id]
                local map=type(q)=='table' and ID(q.mapID)
                local zone=map and self.GetAtlasZone and self:GetAtlasZone(map)
                if zone and not seen[zone] then
                    found[#found+1]={mapID=zone,source='Saved quest zone'}
                    seen[zone]=true
                end
            end
        end
    end
    local accountZone=qdb.questZones and ID(qdb.questZones[id])
    local fallback=accountZone and self.GetAtlasZone and self:GetAtlasZone(accountZone)
    if fallback and not seen[fallback] then
        found[#found+1]={mapID=fallback,source='Saved quest zone (account)'}
    end
    return found
end
function AF:GetQuestRecapZones(scope,query)
    local zones={}
    local exploration=TableOrEmpty(self.db and self.db.exploration and self.db.exploration.characters)
    local quests=TableOrEmpty(self.db and self.db.questRecords and self.db.questRecords.characters)
    local owners=Owners(self,scope)
    -- Capture newly resolvable live quest zones before merging saved alts.
    -- This does not add events or rewrite quest completion history.
    if type(self.CaptureCurrentQuestZones)=='function' then
        self:CaptureCurrentQuestZones()
    end
    local function Zone(mapID,name)
        mapID=ID(mapID)
        if not mapID then return end
        local info=MapInfoFor(self,mapID)
        if not info or info.mapType~=3 then return end
        local z=zones[mapID]
        if not z then
            z={kind='zone',key='zone:'..mapID,mapID=mapID,title=name or info.name or ('Zone #'..mapID),
                visits=0,firstSeen=nil,lastSeen=nil,owners={},quests={}}
            zones[mapID]=z
        end
        return z
    end
    for _,owner in ipairs(owners) do
        local record=exploration[owner]
        if type(record)=='table' then
            for raw,visit in pairs(type(record.zones)=='table' and record.zones or {}) do
                local z=type(visit)=='table' and Zone(raw,visit.name)
                if z then
                    z.visits=z.visits+math.max(0,tonumber(visit.visits) or 0)
                    local first,last=tonumber(visit.firstSeen),tonumber(visit.lastSeen)
                    if first and first>0 and (not z.firstSeen or first<z.firstSeen) then z.firstSeen=first end
                    if last and last>0 and (not z.lastSeen or last>z.lastSeen) then z.lastSeen=last end
                    z.owners[owner]=true
                end
            end
        end
    end
    local areas=KnownZones(self,zones)
    local lib=LibQuest()
    local allStories,entryByID=self:GetQuestRecapStories(scope)
    local questZones={}
    for id,entry in pairs(entryByID) do
        local located=StoredQuestRegions(self,id,owners)
        if #located==0 then
            local mapID=self:GetRecapQuestZoneID(id)
            if mapID then located[1]={mapID=mapID,source='Client quest map'} end
        end
        if #located==0 then
            local areaID=DatabaseArea(lib,id)
            local name=areaID and AreaName(areaID,lib)
            local match=name and areas[CleanName(name)]
            if match then located[1]={mapID=match,source='LibQuestDB region'} end
        end
        for _,place in ipairs(located) do
            local mapID=place.mapID
            if Zone(mapID) then
                local z=zones[mapID]
                z.quests[id]={id=id,title=entry.title,completed=entry.completed,
                    active=entry.active,source=place.source,owners=entry.owners}
                questZones[id]=questZones[id] or {}
                questZones[id][mapID]=true
            end
        end
    end
    -- Convert linked quest IDs into readable recorded story groups. These are
    -- reference region associations, NOT evidence of completing in that area.
    for _,story in ipairs(allStories) do
        local buckets={}
        for _,id in ipairs(story.ids) do
            for mapID in pairs(questZones[id] or {}) do
                buckets[mapID]=buckets[mapID] or {ids={},completed=0,active=0}
                local b=buckets[mapID]
                b.ids[#b.ids+1]=id
                local q=entryByID[id]
                if q.completed then b.completed=b.completed+1 end
                if q.active and not q.completed then b.active=b.active+1 end
            end
        end
        for mapID,b in pairs(buckets) do
            local z=zones[mapID]
            z.stories=z.stories or {}
            -- Preserve the parent story identity so regional chapters can
            -- open the exact existing Story reader; a chain may span zones.
            z.stories[#z.stories+1]={key=story.key,title=story.title,
                kind=story.groupKind,ids=b.ids,completed=b.completed,
                active=b.active,regionCount=#b.ids,totalCount=story.total}
        end
    end
    local result={}
    for _,z in pairs(zones) do
        z.questCount=0;z.completedCount=0;z.activeCount=0
        for _,q in pairs(z.quests) do
            z.questCount=z.questCount+1
            if q.completed then z.completedCount=z.completedCount+1
            elseif q.active then z.activeCount=z.activeCount+1 end
        end
        table.sort(z.stories or {},SortTitle)
        z.storyCount=#(z.stories or {})
        z.chainCount=0
        for _,group in ipairs(z.stories or {}) do
            if group.kind=='chain' then z.chainCount=z.chainCount+1 end
        end
        local include=Matches(z.title,query)
        if not include then
            for _,group in ipairs(z.stories or {}) do
                if Matches(group.title,query) then include=true;break end
            end
        end
        if not include then
            for _,q in pairs(z.quests) do
                if Matches(q.title,query) or Matches(q.id,query) then include=true;break end
            end
        end
        if include then result[#result+1]=z end
    end
    table.sort(result,SortTitle)
    return result
end
function AF:GetQuestRecapRecord(id,owner)
    local chars=TableOrEmpty(self.db and self.db.questRecords and self.db.questRecords.characters)
    if owner and chars[owner] then
        local c=chars[owner]
        return (c.completed and c.completed[id]) or (c.active and c.active[id])
    end
    for _,c in pairs(chars) do
        local q=(c.completed and c.completed[id]) or (c.active and c.active[id])
        if q then return q end
    end
end
