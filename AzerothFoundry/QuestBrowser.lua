-- v0.4.1.6: searchable, scoped quest browser. Pure presentation; does not mutate saved quests.
local _, AF = ...
local function Num(v) local n=tonumber(v); if n and n>0 then return n end end
local function Trim(v) return tostring(v or ''):match('^%s*(.-)%s*$') end
local function SortKeys(a,b) return a.label:lower()<b.label:lower() end
local filterOptions={
    active={{'all','All active'},{'ready','Ready to turn in'},{'inprogress','In progress'}},
    completed={{'all','All completed'},{'recovered','Date unknown'},{'dated','Dated turn-ins'}},
    history={{'all','All events'},{'accepted','Accepted'},{'turned-in','Turned in'},{'observed','First observed'}}
}
function AF:GetQuestBrowserFilters(tab) return filterOptions[tab] or filterOptions.active end
function AF:GetQuestBrowserScopes()
    local mine=self:GetCurrentKey()
    local all={{key='current',label='This character'},{key='all',label='All recorded characters'}}
    local chars=(self.db and self.db.questRecords and self.db.questRecords.characters) or {}
    local others={}
    for key,r in pairs(chars) do
        if key~=mine and type(r)=='table' then
            local c=self.db and self.db.characters and self.db.characters[key]
            local name=c and c.name or (type(key)=='string' and key:match('^([^%-]+)%-')) or 'Unknown'
            local realm=c and c.realm or ''
            others[#others+1]={key=key,label=name..(realm~='' and (' - '..realm) or '')}
        end
    end
    table.sort(others,SortKeys)
    for _,c in ipairs(others) do all[#all+1]=c end
    return all
end
function AF:GetQuestBrowserCharacterLabel(key)
    if key==self:GetCurrentKey() then
        local c=self.db and self.db.characters and self.db.characters[key]
        return c and c.name or 'Current character'
    end
    local c=self.db and self.db.characters and self.db.characters[key]
    if c and c.name then return c.name end
    return tostring(key or 'Unknown character')
end
local function HasText(entry,needle)
    if needle=='' then return true end
    return tostring(entry.title or ''):lower():find(needle,1,true)~=nil
        or tostring(entry.id or ''):find(needle,1,true)~=nil
        or (entry.ownerLabel and entry.ownerLabel:lower():find(needle,1,true)~=nil)
end
local function Keep(e,tab,filter)
    if filter=='all' then return true end
    if tab=='active' then return (filter=='ready' and e.ready) or (filter=='inprogress' and not e.ready) end
    if tab=='completed' then return (filter=='recovered' and not e.at) or (filter=='dated' and e.at) end
    if tab=='history' then return e.kind==filter end
    return true
end
local function QuestName(q,id)
    local t=q and q.title
    if type(t)=='string' and t~='' then return t end
    return 'Quest #'..tostring(id)
end
-- UI picks a representative saved record when the same quest is present on
-- more than one character; ownerKeys always list the complete ownership set.
function AF:GetQuestBrowserEntries(scope,tab,query,filter)
    tab=filterOptions[tab] and tab or 'active'
    local allowed=false
    for _,opt in ipairs(filterOptions[tab]) do if opt[1]==filter then allowed=true end end
    filter=allowed and filter or 'all'
    local needle=Trim(query):lower()
    local mine=self:GetCurrentKey()
    local characters=(self.db and self.db.questRecords and self.db.questRecords.characters) or {}
    local owners={}
    if scope=='all' then
        for key,record in pairs(characters) do
            if type(record)=='table' then owners[#owners+1]=key end
        end
        table.sort(owners,function(a,b) return tostring(a)<tostring(b) end)
    else
        local key=(scope=='current' or not scope) and mine or scope
        if characters[key] then owners[1]=key end
    end
    local all,entries={},{}
    local totals={active=0,completed=0,history=0,ready=0,characters=#owners,filtered=0}
    if tab=='history' then
        for _,key in ipairs(owners) do
            local record=characters[key]
            local active=type(record.active)=='table' and record.active or {}
            local completed=type(record.completed)=='table' and record.completed or {}
            for i,ev in ipairs(type(record.history)=='table' and record.history or {}) do
                if type(ev)=='table' and Num(ev.id) then
                    local q=active[ev.id] or completed[ev.id]
                    local e={id=Num(ev.id),title=QuestName(q or ev,ev.id),level=q and q.level or ev.level,
                        at=ev.at,kind=ev.kind or 'observed',ownerKey=key,ownerLabel=self:GetQuestBrowserCharacterLabel(key),
                        eventIndex=i,rowKey='h:'..tostring(key)..':'..i}
                    all[#all+1]=e
                end
            end
        end
        table.sort(all,function(a,b)
            if (a.at or 0)~=(b.at or 0) then return (a.at or 0)>(b.at or 0) end
            return a.rowKey>b.rowKey
        end)
        totals.history=#all
    else
        local merged={}
        for _,key in ipairs(owners) do
            local record=characters[key]
            local source=type(record[tab])=='table' and record[tab] or {}
            for rawID,q in pairs(source) do
                local id=Num(rawID) or (type(q)=='table' and Num(q.id))
                if id and type(q)=='table' then
                    local e=merged[id]
                    if not e then
                        e={id=id,title=QuestName(q,id),level=q.level,ready=q.readyToTurnIn==true,
                            at=q.at,source=q.source,kind=tab,ownerKey=key,ownerKeys={},rowKey='q:'..id}
                        merged[id]=e
                    else
                        -- Prefer real titles and confirmed turn-in dates, without
                        -- changing any saved records for the contributing characters.
                        if e.title=='Quest #'..id and q.title and q.title~='' then e.title=q.title end
                        if not e.level and q.level then e.level=q.level end
                        if (q.at or 0)>(e.at or 0) then e.at=q.at;e.source=q.source;e.ownerKey=key end
                        if q.readyToTurnIn then
                            if not e.ready and tab=='active' then e.ownerKey=key end
                            e.ready=true
                        end
                    end
                    e.ownerKeys[#e.ownerKeys+1]=key
                end
            end
        end
        for _,e in pairs(merged) do
            local labels={}
            for _,key in ipairs(e.ownerKeys) do labels[#labels+1]=self:GetQuestBrowserCharacterLabel(key) end
            e.ownerLabel=table.concat(labels,', ')
            all[#all+1]=e
            if e.ready then totals.ready=totals.ready+1 end
        end
        table.sort(all,function(a,b)
            local x,y=a.title:lower(),b.title:lower()
            if x~=y then return x<y end
            return a.id<b.id
        end)
        totals[tab]=#all
    end
    for _,e in ipairs(all) do
        if Keep(e,tab,filter) and HasText(e,needle) then entries[#entries+1]=e end
    end
    totals.filtered=#entries
    return entries,totals
end
