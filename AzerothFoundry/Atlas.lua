-- v0.4.0: Account-aware, locally recorded atlas visits. Never edits Blizzard's map.
local _, AF = ...
local function Now() return type(time)=="function" and time() or 0 end
local function MapInfo(mapID)
    if type(mapID) ~= 'number' or not C_Map or not C_Map.GetMapInfo then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    if ok and type(info)=='table' and info.mapID then return info end
end

function AF:InitializeAtlas()
    self.db.exploration=type(self.db.exploration)=='table' and self.db.exploration or {}
    local db=self.db.exploration
    db.characters=type(db.characters)=='table' and db.characters or {}
    db.historyLimit=200
    self.db.settings.atlas=type(self.db.settings.atlas)=='table' and self.db.settings.atlas or {}
    local s=self.db.settings.atlas
    if s.scope ~= 'all' and s.scope ~= 'character' and s.scope ~= 'expedition' then s.scope='character' end
    if type(s.mapID)~='number' then s.mapID=nil end
    if s.showExploration==nil then s.showExploration=true end
    if s.showQuestPins==nil then s.showQuestPins=true end
    s.playerArrowSize=math.max(10,math.min(44,tonumber(s.playerArrowSize) or 17))
    if s.section~='Zones' and s.section~='Quests' and s.section~='History' and s.section~='Discoveries' and s.section~='Quest Recap' then s.section='Zones' end
end

function AF:GetAtlasMapInfo(mapID) return MapInfo(mapID) end

function AF:GetAtlasCurrentMap()
    if not C_Map or not C_Map.GetBestMapForUnit then return nil end
    local ok, mapID=pcall(C_Map.GetBestMapForUnit, 'player')
    if ok then return mapID end
end

function AF:GetAtlasZone(mapID)
    local seen={}
    for _=1,12 do
        local info=MapInfo(mapID)
        if not info or seen[mapID] then return nil end
        if info.mapType==3 then return mapID,info end
        if not info.parentMapID or info.parentMapID==0 then return nil end
        seen[mapID]=true
        mapID=info.parentMapID
    end
end

function AF:GetAtlasContinent(mapID)
    local seen={}
    for _=1,12 do
        local info=MapInfo(mapID)
        if not info or seen[mapID] then return nil end
        if info.mapType==2 then return mapID,info end
        if not info.parentMapID or info.parentMapID==0 then return nil end
        seen[mapID]=true
        mapID=info.parentMapID
    end
end

function AF:GetAtlasContinents()
    local entries, named={},{}
    local function Add(mapID)
        local info=MapInfo(mapID)
        if info and info.mapType==2 and not named[info.name] then
            named[info.name]=true
            entries[#entries+1]={key=mapID,label=info.name,mapID=mapID}
        end
    end
    -- Prefer the player's current map tree; the Classic and Modern map IDs
    -- differ, so all guesses below are validated against C_Map.GetMapInfo.
    Add(self:GetAtlasContinent(self:GetAtlasCurrentMap()))
    for _, mapID in ipairs({1414,1415,12,13}) do Add(mapID) end
    -- Other available continents can be browsed using the map parent button.
    return entries
end

function AF:GetAtlasDefaultMap()
    return self:GetAtlasContinent(self:GetAtlasCurrentMap()) or self:GetAtlasCurrentMap()
        or (MapInfo(1414) and 1414) or (MapInfo(12) and 12)
end

function AF:GetAtlasMapChildren(mapID)
    if not C_Map or not C_Map.GetMapChildrenInfo then return {} end
    local ok, children=pcall(C_Map.GetMapChildrenInfo,mapID)
    if not ok or type(children)~='table' then return {} end
    local result={}
    for _, info in ipairs(children) do
        if info.mapID and info.name and (info.mapType==3 or info.mapType==2 or info.mapType==4) then
            result[#result+1]={key=info.mapID, mapID=info.mapID, label=info.name}
        end
    end
    table.sort(result,function(a,b) return a.label<b.label end)
    return result
end

function AF:RecordCurrentAtlasZone()
    if not self.db or not self.db.exploration then return end
    local mapID,info=self:GetAtlasZone(self:GetAtlasCurrentMap())
    if not mapID or not info then return end
    local key=self:GetCurrentKey()
    if not key then return end
    local ex=self.db.exploration
    local record=ex.characters[key]
    if type(record)~='table' then
        record={zones={},history={}}
        ex.characters[key]=record
    end
    record.zones=type(record.zones)=='table' and record.zones or {}
    record.history=type(record.history)=='table' and record.history or {}
    local zone=record.zones[mapID] or record.zones[tostring(mapID)]
    local newlyRecorded=type(zone)~='table'
    if newlyRecorded then
        zone={name=info.name,firstSeen=Now(),lastSeen=Now(),visits=0}
        record.zones[mapID]=zone
    end
    zone.name=info.name
    zone.lastSeen=Now()
    -- Repeated events in one area must not inflate the history/visit counter.
    if self.atlasLastMapID~=mapID then
        zone.visits=(tonumber(zone.visits) or 0)+1
        record.history[#record.history+1]={mapID=mapID,name=info.name,at=Now()}
        if #record.history>(ex.historyLimit or 200) then table.remove(record.history,1) end
        self.atlasLastMapID=mapID
    end
    if newlyRecorded and self.ObserveMilestoneNewAtlasZone then
        self:ObserveMilestoneNewAtlasZone(mapID,info.name,key)
    end
end

function AF:IsAtlasMapDescendant(mapID, ancestorID)
    if not mapID or not ancestorID then return false end
    local seen={}
    for _=1,12 do
        if mapID==ancestorID then return true end
        local info=MapInfo(mapID)
        if not info or seen[mapID] then break end
        seen[mapID]=true
        mapID=info.parentMapID
        if not mapID or mapID==0 then break end
    end
    return false
end

function AF:GetAtlasZoneSummary(mapID,scope)
    local found,first,last,visits=0,nil,nil,0
    local key=self:GetCurrentKey()
    for charKey, record in pairs(self.db.exploration.characters or {}) do
        local eligible=scope=='all' or (scope=='expedition' and self.IsExpeditionMember and self:IsExpeditionMember(charKey))
            or (scope=='character' and charKey==key)
        if eligible then
            for id, entry in pairs(record.zones or {}) do
                if id==mapID or self:IsAtlasMapDescendant(id,mapID) then
                    found=found+1
                    if entry.firstSeen and (not first or entry.firstSeen<first) then first=entry.firstSeen end
                    if entry.lastSeen and (not last or entry.lastSeen>last) then last=entry.lastSeen end
                    visits=visits+(tonumber(entry.visits) or 0)
                end
            end
        end
    end
    return {areas=found,firstSeen=first,lastSeen=last,visits=visits}
end

function AF:GetAtlasHistory(scope,mapID,limit)
    local list={}
    local key=self:GetCurrentKey()
    for charKey, record in pairs(self.db.exploration.characters or {}) do
        local eligible=scope=='all' or (scope=='expedition' and self.IsExpeditionMember and self:IsExpeditionMember(charKey))
            or (scope=='character' and charKey==key)
        if eligible then
            for _,entry in ipairs(record.history or {}) do
                if not mapID or self:IsAtlasMapDescendant(entry.mapID,mapID) then
                    list[#list+1]={name=entry.name,mapID=entry.mapID,at=entry.at,charKey=charKey}
                end
            end
        end
    end
    table.sort(list,function(a,b) return (a.at or 0)>(b.at or 0) end)
    while #list>(limit or 12) do table.remove(list) end
    return list
end
