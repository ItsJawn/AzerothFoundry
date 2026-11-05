-- Azeroth Foundry Collections acquisition reference bridge v0.4.4.2.3
-- Library data is NOT a personally observed discovery. No coordinates required.
-- Source lookups run only for the selected entry, never for the full gallery.
local _, AF = ...
local function Text(v)
    if type(v)=='string' and v:match('%S') then return v end
end
local function ID(v)
    if type(v)=='number' and v>0 and v==math.floor(v) then return v end
end
local function TryMethod(obj, name, ...)
    if type(obj)~='table' or type(obj[name])~='function' then return nil end
    local ok, result=pcall(obj[name], obj, ...)
    if ok then return result end
end
local function ItemLib()
    if not LibStub then return nil, 'LibItemDB not installed (optional; source details may be limited)' end
    local ok, db=pcall(LibStub,'LibItemDB-1.0',true)
    if not ok or type(db)~='table' then return nil, 'LibItemDB not installed (optional; source details may be limited)' end
    if type(db.IsReady)=='function' and not TryMethod(db,'IsReady') then
        return nil, 'LibItemDB not ready (optional; source details may be limited)'
    end
    return db, 'LibItemDB connected'
end
function AF:GetCollectionItemDBStatus()
    local db,reason=ItemLib()
    if not db then return reason, false end
    return reason, true
end
-- Quest rewards are not covered by the native transmog appearance source fields
-- when the client omits sourceType. Record only reward slots actually shown in
-- the player's quest interaction; never treat an offered choice as acquired.
-- This is reference information, NOT a personal collection discovery.
local VERIFIED_FOREVER_QUEST_REWARDS = {
    -- Multiple Forever quest/item references agree on these reward choices.
    -- Compact facts only; no copied database or proprietary implementation.
    [263408]={questID=92463,quest='The Cirrusfly Queen',zone='Zephras Isle',kind='choice'},
    [263409]={questID=92463,quest='The Cirrusfly Queen',zone='Zephras Isle',kind='choice'},
    [263410]={questID=92463,quest='The Cirrusfly Queen',zone='Zephras Isle',kind='choice'},
}
local function Guard(fn,...)
    if type(fn)~='function' then return nil end
    local ok,a,b,c,d,e,f=pcall(fn,...)
    if ok then return a,b,c,d,e,f end
end
function AF:CaptureQuestRewardReferences(event)
    if event~='QUEST_DETAIL' and event~='QUEST_COMPLETE' then return 0 end
    if not self.db or type(self.db.collections)~='table' then return 0 end
    local questID=tonumber(Guard(GetQuestID))
    if not questID or questID<1 then return 0 end
    local name=Guard(GetTitleText) or (C_QuestLog and Guard(C_QuestLog.GetTitleForQuestID,questID))
    if not Text(name) then name='Quest #'..questID end
    local store=self.db.collections
    store.questRewardReferences=type(store.questRewardReferences)=='table' and store.questRewardReferences or {}
    local added=0
    for _,kind in ipairs({'reward','choice'}) do
        local count=tonumber(Guard(kind=='reward' and GetNumQuestRewards or GetNumQuestChoices)) or 0
        for i=1,math.min(20,math.max(0,count)) do
            local _,_,_,_,_,itemID=Guard(GetQuestItemInfo,kind,i)
            itemID=ID(tonumber(itemID))
            if itemID then
                local itemRefs=store.questRewardReferences[itemID]
                if type(itemRefs)~='table' then itemRefs={};store.questRewardReferences[itemID]=itemRefs end
                local row=itemRefs[questID]
                if type(row)~='table' then
                    row={questID=questID,quest=name,kind=kind,firstSeen=Guard(time)}
                    itemRefs[questID]=row
                    added=added+1
                else
                    if Text(name) and name~=('Quest #'..questID) then row.quest=name end
                    row.kind=kind
                end
            end
        end
    end
    return added
end
function AF:GetCollectionQuestRewardReferences(entry)
    if type(entry)~='table' then return {} end
    local ids,seen,rows,used={},{},{},{}
    local function addID(v)
        local id=ID(tonumber(v))
        if id and not seen[id] and #ids<24 then seen[id]=true;ids[#ids+1]=id end
    end
    if entry.category=='transmog' then
        addID(entry.itemID)
        if type(entry.sourceItems)=='table' then
            for _,source in ipairs(entry.sourceItems) do
                if type(source)=='table' then addID(source.itemID) end
            end
        end
    elseif entry.category=='toys' then addID(entry.id)
    elseif entry.category=='mounts' or entry.category=='pets' then addID(entry.itemID) end
    local saved=self.db and self.db.collections and self.db.collections.questRewardReferences
    for _,itemID in ipairs(ids) do
        local itemRecords=type(saved)=='table' and saved[itemID] or nil
        if type(itemRecords)=='table' then
            for rawID,row in pairs(itemRecords) do
                if type(row)=='table' then
                    local id=ID(tonumber(row.questID or rawID))
                    if id and not used[id] then
                        used[id]=true
                        rows[#rows+1]={label=(row.kind=='choice' and 'Quest reward choice: ' or 'Quest reward: ')..(Text(row.quest) or ('Quest #'..id)),
                            questID=id, origin='Observed in your quest window'}
                    end
                end
            end
        end
        local reference=VERIFIED_FOREVER_QUEST_REWARDS[itemID]
        if reference and not used[reference.questID] then
            used[reference.questID]=true
            rows[#rows+1]={label='Quest reward choice: '..reference.quest..' ('..reference.zone..')',
                questID=reference.questID,origin='Forever quest reference; not a personal discovery'}
        end
    end
    table.sort(rows,function(a,b) return (a.questID or 0)<(b.questID or 0) end)
    return rows
end

local SOURCE_LABELS={atlasloot='Dungeon/Raid drop',drop='Drop',vendor='Vendor',quest='Quest',crafted='Crafted',pvp='PvP',reputation='Reputation',gathered='Gathered',chest='Chest',world='World drop',profession='Profession'}
local function RowDescription(row)
    if type(row)~='table' then return nil end
    local source=Text(row.source) or Text(row.kind) or Text(row.type) or 'reference'
    local label=SOURCE_LABELS[source:lower()] or source:gsub('^%l',string.upper)
    local boss=Text(row.boss) or Text(row.creature) or Text(row.npc) or Text(row.vendor) or Text(row.npcName)
    local where=Text(row.instance) or Text(row.zone) or Text(row.location)
        or Text(row.profession) or Text(row.skill) or Text(row.craftingProfession)
    local out=label
    if boss and where then out=out..': '..boss..' — '..where
    elseif boss or where then out=out..': '..(boss or where) end
    if type(row.rate)=='number' and row.rate>0 and row.rate<=100 then
        out=out..' ('..string.format('%.2g',row.rate)..'% reported)'
    end
    return out
end
function AF:GetCollectionAcquisitionReferences(entry)
    -- Only call this function from a view authorized to reveal reference information.
    if type(entry)~='table' then return {},'Invalid collection entry' end
    local db,state=ItemLib()
    if not db then return {},state end
    local ids,seen,rows,unique={},{},{},{}
    local function addID(id)
        id=ID(tonumber(id))
        if id and not seen[id] and #ids<24 then seen[id]=true;ids[#ids+1]=id end
    end
    if entry.category=='toys' then addID(entry.id) end
    if entry.category=='transmog' then
        addID(entry.itemID)
        if type(entry.sourceItems)=='table' then
            for _,source in ipairs(entry.sourceItems) do if type(source)=='table' then addID(source.itemID) end end
        end
        -- The gallery intentionally resolves only one representative source for
        -- card icons. The selected detail view may have many alternative item
        -- sources, including sources valid for other classes. Resolve those HERE
        -- rather than querying the whole appearance catalog on every page.
        local mog=C_TransmogCollection
        if mog then
            local ok,list=false,nil
            if type(mog.GetAllAppearanceSources)=='function' then
                ok,list=pcall(mog.GetAllAppearanceSources,entry.id)
            end
            if ok and type(list)=='table' then
                for i=1,math.min(#list,60) do
                    local row=list[i]
                    local sourceID=type(row)=='table' and tonumber(row.sourceID or row.itemModifiedAppearanceID) or tonumber(row)
                    if sourceID and sourceID>0 then
                        local info=type(mog.GetSourceInfo)=='function' and select(2,pcall(mog.GetSourceInfo,sourceID)) or nil
                        local itemID=type(info)=='table' and tonumber(info.itemID) or nil
                        if not itemID and type(mog.GetSourceItemID)=='function' then
                            local got,v=pcall(mog.GetSourceItemID,sourceID)
                            if got then itemID=tonumber(v) end
                        end
                        addID(itemID)
                    end
                end
            end
        end
    end
    if entry.category=='mounts' or entry.category=='pets' then
        addID(entry.itemID)
        addID(entry.mountItemID)
        local rec=self.CollectionDiscovery and self:CollectionDiscovery(entry.category,entry.id)
        if rec and type(rec.sources)=='table' then
            for _,s in pairs(rec.sources) do if type(s)=='table' then addID(s.itemID) end end
        end
        local curated=self.GetCollectionSourceReference and self:GetCollectionSourceReference(entry.category,entry.id)
        if type(curated)=='table' then
            addID(curated.itemID or (type(curated.label)=='string' and curated.label:match('item #%s*(%d+)')))
        end
    end
    if #ids==0 then return {},'No linked acquisition item ID is available for this collectible' end
    local function add(text)
        if not Text(text) or unique[text] or #rows>=30 then return end
        unique[text]=true;rows[#rows+1]=text
    end
    local hasSources=type(db.GetSources)=='function'
    for _,itemID in ipairs(ids) do
        local itemName=TryMethod(db,'GetName',itemID) or ('Item #'..itemID)
        local sources=hasSources and TryMethod(db,'GetSources',itemID) or nil
        if type(sources)=='table' then
            for _,source in pairs(sources) do
                if type(source)=='table' then
                    add('['..tostring(itemName)..'] '..(RowDescription(source) or 'Source details unavailable'))
                elseif Text(source) then
                    add('['..tostring(itemName)..'] '..source)
                end
            end
        end
        -- Forever currently lacks vendor/mob placement data in this library;
        -- future library updates may make these rows available automatically.
        local places=TryMethod(db,'GetItemPlaces',itemID)
        if type(places)=='table' then
            for _,place in ipairs(places) do
                if type(place)=='table' then
                    local vendor=Text(place.name) or Text(place.npcName) or Text(place.creature)
                    local zone=Text(place.zone) or Text(place.mapName)
                    local kind=Text(place.kind) or Text(place.type) or 'Location'
                    if vendor or zone then add('['..tostring(itemName)..'] '..kind..': '..(vendor or 'Source')..(zone and (' — '..zone) or '')) end
                end
            end
        end
    end
    return rows,(#rows>0 and 'LibItemDB references, not personally discovered' or 'LibItemDB has no specific acquisition record for these item IDs')
end
