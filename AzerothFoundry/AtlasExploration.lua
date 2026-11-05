-- v0.4.3.3: Stabilized per-character exploration snapshots and optional account-wide sharing.
-- The native Explorer criteria determine progress, never the visible art count.
-- Illustrated discovery overlays are separately archived and safely unioned by
-- map ID and their native geometry. This does not alter the Blizzard world map.
local _, AF = ...
local knownAchievements = {
    [1411] = 728, -- Durotar
    [1412] = 736, -- Mulgore
}
local achievementIndex, missingNames = nil, {}
local floor, min = math.floor, math.min
-- A legacy SavedVariables entry can be missing or have an unexpected type.
-- Treat these as no saved evidence instead of aborting the whole Atlas view.
local function SavedCharacters(self)
    local exploration=self.db and self.db.exploration
    local chars=type(exploration)=='table' and exploration.characters
    return type(chars)=='table' and chars or {}
end
local function SavedZone(record,mapID)
    if type(record)~='table' or type(record.discovery)~='table' then return nil end
    local zone=record.discovery[mapID] or record.discovery[tostring(mapID)]
    return type(zone)=='table' and zone or nil
end
local function SortedKeys(t)
    local keys={}
    if type(t)~='table' then return keys end
    for key in pairs(t) do keys[#keys+1]=key end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    return keys
end

local function Normalize(name)
    if type(name) ~= 'string' then return nil end
    return (name:lower():gsub('^%s+',''):gsub('%s+$',''):gsub('%s+',' '))
end
local function Now()
    return type(time)=='function' and time() or 0
end
local function AchievementMatches(achievementID, zoneName)
    if type(GetAchievementInfo)~='function' or not zoneName then return false end
    local ok,_,name=pcall(GetAchievementInfo,achievementID)
    if not ok or type(name)~='string' then return false end
    local normalized,zone=Normalize(name),Normalize(zoneName)
    return normalized==('explore '..zone) or normalized==zone
end
local function BuildAchievementIndex()
    if achievementIndex then return end
    achievementIndex={}
    if type(GetCategoryList)~='function' or
        type(GetCategoryNumAchievements)~='function' or
        type(GetAchievementInfo)~='function' then return end
    local ok,categories=pcall(GetCategoryList)
    if not ok or type(categories)~='table' then return end
    for _,categoryID in ipairs(categories) do
        local success,count=pcall(GetCategoryNumAchievements,categoryID,true)
        if success and type(count)=='number' then
            for i=1,math.min(count,500) do
                local yes,id,name=pcall(GetAchievementInfo,categoryID,i)
                if yes and type(id)=='number' and type(name)=='string' then
                    local normalized=Normalize(name)
                    if normalized then achievementIndex[normalized]=id end
                end
            end
        end
    end
end
function AF:ClearAtlasExplorationLookup()
    achievementIndex=nil
    missingNames={}
end
local function FindAchievement(mapID,zoneName)
    local direct=knownAchievements[mapID]
    if direct and AchievementMatches(direct,zoneName) then return direct end
    local norm=Normalize(zoneName)
    if not norm then return nil end
    if not missingNames[norm] then
        BuildAchievementIndex()
        local candidate=achievementIndex and achievementIndex['explore '..norm]
        if candidate and AchievementMatches(candidate,zoneName) then
            knownAchievements[mapID]=candidate;return candidate
        end
        local zoneOnly=achievementIndex and achievementIndex[norm]
        if zoneOnly and AchievementMatches(zoneOnly,zoneName) then
            knownAchievements[mapID]=zoneOnly;return zoneOnly
        end
        missingNames[norm]=true
    end
end
local function ZoneInfo(self,mapID)
    local info=self.GetAtlasMapInfo and self:GetAtlasMapInfo(mapID)
    return info and tonumber(info.mapType)==3 and info or nil
end
local function RecordForCurrent(self,mapID)
    if not self.db or type(self.db.exploration)~='table' then return nil end
    local key=self.GetCurrentKey and self:GetCurrentKey()
    if not key then return nil end
    local chars=self.db.exploration.characters
    if type(chars)~='table' then return nil end
    local record=chars[key]
    if type(record)~='table' then record={zones={},history={}};chars[key]=record end
    record.discovery=type(record.discovery)=='table' and record.discovery or {}
    local snapshot=record.discovery[mapID]
    if type(snapshot)~='table' then
        snapshot={};record.discovery[mapID]=snapshot
    end
    return snapshot
end
local function Eligible(self,scope,charKey)
    if scope=='all' then return true end
    if scope=='expedition' then
        return self.IsExpeditionMember and self:IsExpeditionMember(charKey)
    end
    return charKey==(self.GetCurrentKey and self:GetCurrentKey())
end
local function CriteriaFromClient(self,mapID)
    local info=ZoneInfo(self,mapID)
    if not info then return nil,'Select a zone' end
    if type(GetAchievementNumCriteria)~='function' or type(GetAchievementCriteriaInfo)~='function' then
        return nil,'Progress unavailable'
    end
    local achievementID=FindAchievement(mapID,info.name)
    -- Some Forever-only regions (e.g., Zephras Isle) have discovery overlays
    -- but are not part of any Explorer achievement. Do not invent a percent.
    if not achievementID then return nil,'No Explorer achievement for this zone' end
    local ok,total=pcall(GetAchievementNumCriteria,achievementID)
    if not ok or type(total)~='number' or total<1 or total>500 then
        return nil,'Progress unavailable'
    end
    local entries,completedNames,completedIDs={}, {}, {}
    local done=0
    for i=1,total do
        local good,name,_,completed,_,_,_,_,_,_,criteriaID=pcall(GetAchievementCriteriaInfo,achievementID,i)
        if not good or type(name)~='string' or type(completed)~='boolean' then
            return nil,'Progress unavailable'
        end
        local norm=Normalize(name)
        if not norm then return nil,'Progress unavailable' end
        local id=type(criteriaID)=='number' and criteriaID>0 and criteriaID or nil
        entries[i]={name=norm,id=id,done=completed}
        if completed then
            done=done+1
            completedNames[norm]=true
            if id then completedIDs[id]=true end
        end
    end
    return {done=done,total=total,remaining=total-done,
        percent=floor(done*100/total+.5),achievementID=achievementID,
        entries=entries,completedNames=completedNames,completedIDs=completedIDs,
        source='Forever Explorer achievement'}
end
local function SaveCriteria(self,mapID,live)
    local snapshot=RecordForCurrent(self,mapID)
    if not snapshot or not live then return end
    local old=snapshot.criteria
    if type(old)~='table' or old.achievementID~=live.achievementID then
        old={achievementID=live.achievementID,names={},ids={}}
        snapshot.criteria=old
    end
    old.names=type(old.names)=='table' and old.names or {}
    old.ids=type(old.ids)=='table' and old.ids or {}
    for name in pairs(live.completedNames) do old.names[name]=true end
    for id in pairs(live.completedIDs) do old.ids[id]=true end
    old.total=live.total
    old.captured=Now()
end
-- Geometry is the same key used by map exploration overlays. Each group
-- contains its original file IDs and positions, NOT a flattened screenshot.
local function GeometryKey(e)
    return table.concat({e.textureWidth,e.textureHeight,e.offsetX,e.offsetY},':')
end
local function SanitizeOverlays(overlays)
    if type(overlays)~='table' then return nil end
    local groups={}
    for i=1,min(#overlays,250) do
        local p=overlays[i]
        if type(p)=='table' then
            local w,h=tonumber(p.textureWidth),tonumber(p.textureHeight)
            local x,y=tonumber(p.offsetX),tonumber(p.offsetY)
            if w and h and x and y and w>0 and h>0 and w<=8192 and h<=8192
                and math.abs(x)<=16384 and math.abs(y)<=16384 and
                type(p.fileDataIDs)=='table' then
                local ids={}
                for j=1,min(#p.fileDataIDs,256) do
                    local id=tonumber(p.fileDataIDs[j])
                    if not id or id<=0 or id~=floor(id) then break end
                    ids[#ids+1]=id
                end
                if #ids>0 then
                    local row={textureWidth=w,textureHeight=h,offsetX=x,offsetY=y,
                        fileDataIDs=ids,sourceOrder=i}
                    groups[GeometryKey(row)]=row
                end
            end
        end
    end
    return groups
end
local function OverlaysFromClient(mapID)
    if not C_MapExplorationInfo or
        type(C_MapExplorationInfo.GetExploredMapTextures)~='function' then return nil end
    local ok,data=pcall(C_MapExplorationInfo.GetExploredMapTextures,mapID)
    if not ok then return nil end
    return SanitizeOverlays(data)
end
local function SaveOverlays(self,mapID,live)
    local snapshot=RecordForCurrent(self,mapID)
    if not snapshot or not live then return end
    local stored=snapshot.overlays
    if type(stored)~='table' then stored={};snapshot.overlays=stored end
    for key,row in pairs(live) do stored[key]=row end
    snapshot.overlayCaptured=Now()
end

-- Capture the CURRENT CHARACTER only. Called on zone changes, discovery
-- events, and Atlas navigation; never writes to an offline alt's records.
function AF:CaptureAtlasExplorationMap(mapID)
    if not ZoneInfo(self,mapID) then return end
    local criteria=CriteriaFromClient(self,mapID)
    if criteria then SaveCriteria(self,mapID,criteria) end
    local overlays=OverlaysFromClient(mapID)
    if overlays then SaveOverlays(self,mapID,overlays) end
end
function AF:CaptureCurrentAtlasDiscovery()
    if not self.GetAtlasZone or not self.GetAtlasCurrentMap then return end
    local zoneID=self:GetAtlasZone(self:GetAtlasCurrentMap())
    if zoneID then self:CaptureAtlasExplorationMap(zoneID) end
end

-- When a recorded character logs in, capture exploration of the zones it
-- previously visited with Foundry, even if currently standing elsewhere.
-- This can recover older discovered areas on that alt without revisiting them.
function AF:CaptureRecordedAtlasDiscovery()
    local key=self.GetCurrentKey and self:GetCurrentKey()
    local characters=self.db and self.db.exploration and self.db.exploration.characters
    local record=key and type(characters)=='table' and characters[key]
    if type(record)~='table' or type(record.zones)~='table' then return end
    local count=0
    for _,rawID in ipairs(SortedKeys(record.zones)) do
        local zoneID=rawID
        if count>=100 then break end
        zoneID=tonumber(zoneID)
        if zoneID and ZoneInfo(self,zoneID) then
            self:CaptureAtlasExplorationMap(zoneID)
            count=count+1
        end
    end
end

function AF:GetAtlasExplorationProgress(mapID,scope)
    if not ZoneInfo(self,mapID) then return nil,'Select a zone' end
    local live,reason=CriteriaFromClient(self,mapID)
    if not live then return nil,reason end
    SaveCriteria(self,mapID,live)
    if not scope or scope=='character' then return live end
    local combined,contributing=0,0
    local records=SavedCharacters(self)
    for charKey,record in pairs(records) do
        if Eligible(self,scope,charKey) then
            local zone=SavedZone(record,mapID)
            local saved=zone and zone.criteria
            if type(saved)=='table' and saved.achievementID==live.achievementID then
                contributing=contributing+1
            end
        end
    end
    local includeCurrent=(scope~='expedition') or Eligible(self,scope,self:GetCurrentKey())
    for _,entry in ipairs(live.entries) do
        local done=includeCurrent and entry.done
        if not done then
            for charKey,record in pairs(records) do
                if Eligible(self,scope,charKey) then
                    local zone=SavedZone(record,mapID)
                    local saved=zone and zone.criteria
                    if type(saved)=='table' and saved.achievementID==live.achievementID then
                        local hasIDs=type(saved.ids)=='table' and next(saved.ids)~=nil
                        if (entry.id and hasIDs and saved.ids[entry.id]) or
                            (not (entry.id and hasIDs) and type(saved.names)=='table' and saved.names[entry.name]) then
                            done=true;break
                        end
                    end
                end
            end
        end
        if done then combined=combined+1 end
    end
    return {done=combined,total=live.total,remaining=live.total-combined,
        percent=floor(combined*100/live.total+.5),achievementID=live.achievementID,
        source='Shared recorded Explorer criteria',characters=contributing,
        scope=scope}
end

-- Never trust older stored texture rows without the same limits imposed at
-- capture time. Keys are rebuilt from validated native geometry.
local function ReadStoredOverlays(stored)
    local clean={}
    if type(stored)~='table' then return clean end
    local read=0
    for _,key in ipairs(SortedKeys(stored)) do
        if read>=250 then break end
        local entry=stored[key]
        if type(entry)=='table' then
            local validated=SanitizeOverlays({entry})
            for geometry,row in pairs(validated or {}) do
                local n=tonumber(entry.sourceOrder)
                if n and n>=1 and n<=250 and n==floor(n) then row.sourceOrder=n end
                clean[geometry]=row
                read=read+1
            end
        end
    end
    return clean
end
-- Returns only the shapes the character(s) actually revealed, with the exact
-- native placement and file IDs. Current character shapes win on conflicts.
function AF:GetAtlasExplorationOverlays(mapID,scope)
    if not ZoneInfo(self,mapID) then return {} end
    local current=OverlaysFromClient(mapID)
    if current then
        SaveOverlays(self,mapID,current)
    else
        -- During a transient client map-data miss, keep showing the current
        -- character's own previously captured art instead of a blank map.
        local key=self.GetCurrentKey and self:GetCurrentKey()
        local zone=key and SavedZone(SavedCharacters(self)[key],mapID)
        current=ReadStoredOverlays(zone and zone.overlays)
    end
    if not scope or scope=='character' then
        if not current then return {} end
        local list={}
        for _,v in pairs(current) do list[#list+1]=v end
        table.sort(list,function(a,b)
            local ai,bi=a.sourceOrder or 100000,b.sourceOrder or 100000
            if ai~=bi then return ai<bi end
            if a.offsetY==b.offsetY then return a.offsetX<b.offsetX end
            return a.offsetY<b.offsetY
        end)
        return list
    end
    local combined={}
    local records=SavedCharacters(self)
    -- A stable merge order prevents different offline texture groups with the
    -- same native geometry from swapping at random across UI refreshes.
    for _,charKey in ipairs(SortedKeys(records)) do
        if Eligible(self,scope,charKey) then
            local zone=SavedZone(records[charKey],mapID)
            local saved=ReadStoredOverlays(zone and zone.overlays)
            for _,key in ipairs(SortedKeys(saved)) do
                if not combined[key] then combined[key]=saved[key] end
            end
        end
    end
    if current and (scope~='expedition' or Eligible(self,scope,self:GetCurrentKey())) then
        for key,entry in pairs(current) do combined[key]=entry end
    end
    local list={}
    for _,v in pairs(combined) do list[#list+1]=v end
    table.sort(list,function(a,b)
        if a.offsetY==b.offsetY then return a.offsetX<b.offsetX end
        return a.offsetY<b.offsetY
    end)
    return list
end
