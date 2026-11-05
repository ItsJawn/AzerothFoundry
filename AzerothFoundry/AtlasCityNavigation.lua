-- City navigation: capture actual guard POIs without asserting that every
-- city has a complete, queryable directory of unvisited guard destinations.
-- No Blizzard art, third-party databases, or guessed coordinates are bundled.
local _, AF = ...
local City = {}
AF.AtlasCityNavigation = City

local cityNames = {
    ['stormwind city']=true, ['stormwind']=true, ['orgrimmar']=true,
    ['ironforge']=true, ['darnassus']=true, ['undercity']=true,
    ['thunder bluff']=true, ['the exodar']=true, ['exodar']=true,
    ['silvermoon city']=true, ['silvermoon']=true, ['shattrath city']=true,
    ['dalaran']=true,
}
local function CityName(name)
    return type(name)=='string' and cityNames[name:lower()] or false
end
local function Position(pos)
    if not pos then return end
    local x,y
    if type(pos.GetXY)=='function' then
        local ok,a,b=pcall(pos.GetXY,pos)
        if ok then x,y=a,b end
    elseif type(pos)=='table' then x,y=pos.x,pos.y end
    if type(x)=='number' and type(y)=='number' and x>=0 and x<=1 and y>=0 and y<=1 then
        return x,y
    end
end
local function IsCity(id,info)
    if info and CityName(info.name) then return true end
    if C_Map and type(C_Map.IsCityMap)=='function' then
        local ok,yes=pcall(C_Map.IsCityMap,id)
        return ok and yes==true or false
    end
    return false
end
local function GetInfo(id)
    if not (C_Map and type(C_Map.GetMapInfo)=='function') then return end
    local ok,info=pcall(C_Map.GetMapInfo,id)
    if ok and type(info)=='table' then return info end
end

function AF:GetAtlasCityMap()
    if not (C_Map and type(C_Map.GetBestMapForUnit)=='function') then return end
    local ok,id=pcall(C_Map.GetBestMapForUnit,'player')
    if not ok or type(id)~='number' then return end
    local seen={}
    for _=1,14 do
        if seen[id] then break end
        seen[id]=true
        local info=GetInfo(id)
        if not info then break end
        if IsCity(id,info) then return id,info.name end
        if not info.parentMapID or info.parentMapID==0 then break end
        id=info.parentMapID
    end
    -- Some Forever builds return the surrounding zone while inside a city;
    -- do not invent a city map ID based on a text-only zone name.
end
function AF:IsAtlasCityMap(mapID)
    local info=GetInfo(mapID)
    return info and IsCity(mapID,info) or false
end
local function Saved(cityID)
    if not (AF.db and type(cityID)=='number') then return end
    AF.db.atlasCityNavigation=type(AF.db.atlasCityNavigation)=='table' and AF.db.atlasCityNavigation or {}
    local key=tostring(cityID)
    local data=AF.db.atlasCityNavigation[key]
    if type(data)~='table' then data={};AF.db.atlasCityNavigation[key]=data end
    return data
end
local function Notify()
    local page=AF.UI and AF.UI.atlasCityPage
    if page and page.IsShown and page:IsShown() and page.RefreshCityNavigation then
        page:RefreshCityNavigation()
    end
end
local function GuardLike(name,opts)
    local unit=type(name)=='string' and name:lower() or ''
    if unit:find('guard',1,true) or unit:find('sentinel',1,true)
        or unit:find('peacekeeper',1,true) then return true end
    -- A fallback for guards named differently: only recognize a menu with
    -- multiple standard city-service categories, never a single quest NPC.
    local count=0
    for _,entry in ipairs(opts) do
        local label=type(entry.name)=='string' and entry.name:lower() or ''
        if label:find('bank',1,true) or label:find('auction',1,true)
            or label:find('trainer',1,true) or label:find('flight master',1,true)
            or label:find('inn',1,true) or label:find('stable master',1,true)
            or label:find('mailbox',1,true) then count=count+1 end
    end
    return count>=3
end
function City:GetLiveOptions(cityID)
    if self.gossipCity~=cityID or not self.gossipOpen then return {} end
    return self.options or {}
end
function City:GetSavedDestinations(cityID)
    local data=Saved(cityID) or {}
    local result={}
    for key,item in pairs(data) do
        if type(item)=='table' and Position(item) and type(item.name)=='string' then
            result[#result+1]={key=key,name=item.name,mapID=tonumber(item.mapID) or cityID,
                x=item.x,y=item.y,observed=item.observed}
        end
    end
    table.sort(result,function(a,b) return a.name:lower()<b.name:lower() end)
    return result
end
function City:ReadGossip()
    local cityID=AF:GetAtlasCityMap()
    if not cityID or not (C_GossipInfo and type(C_GossipInfo.GetOptions)=='function') then
        self.gossipOpen=false;self.options={};Notify();return
    end
    local ok,opts=pcall(C_GossipInfo.GetOptions)
    if not ok or type(opts)~='table' then return end
    if not (self.gossipOpen and self.gossipCity==cityID) and
        not GuardLike(UnitName and UnitName('npc'),opts) then
        self.gossipOpen=false;self.options={};Notify();return
    end
    self.gossipCity=cityID
    self.gossipOpen=true
    self.options={}
    self.optionLookup={}
    for _,entry in ipairs(opts) do
        local id=tonumber(entry.gossipOptionID)
        if id and type(entry.name)=='string' then
            local option={id=id,name=entry.name}
            self.options[#self.options+1]=option
            self.optionLookup[id]=entry.name
        end
    end
    Notify()
end
function City:SelectedGuardOption(optionID)
    if self.gossipOpen and self.optionLookup then
        self.pendingOption=self.optionLookup[tonumber(optionID)] or self.pendingOption
    end
end
function City:ReadPOI()
    local cityID=AF:GetAtlasCityMap()
    if not cityID or not (C_GossipInfo and type(C_GossipInfo.GetPoiForUiMapID)=='function'
            and type(C_GossipInfo.GetPoiInfo)=='function') then return end
    local candidates={cityID}
    local current=AF.GetAtlasCurrentMap and AF:GetAtlasCurrentMap()
    if current and current~=cityID then candidates[#candidates+1]=current end
    for _,mapID in ipairs(candidates) do
        local ok,poiID=pcall(C_GossipInfo.GetPoiForUiMapID,mapID)
        if ok and type(poiID)=='number' then
            local found,info=pcall(C_GossipInfo.GetPoiInfo,mapID,poiID)
            if found and type(info)=='table' then
                local x,y=Position(info.position)
                if x then
                    local label=type(info.name)=='string' and info.name~='' and info.name
                        or self.pendingOption or ('Guard destination '..poiID)
                    local point={name=label,mapID=mapID,x=x,y=y,
                        observed=type(time)=='function' and time() or 0}
                    self.currentDestination=point
                    local data=Saved(cityID)
                    if data then
                        local key=tostring(mapID)..':'..tostring(poiID)
                        data[key]=point
                    end
                    self.pendingOption=nil
                    -- Guard POIs already carry real client coordinates. Activate
                    -- navigation immediately, even if the Foundry window is closed.
                    self:SelectDestination(point)
                    return point
                end
            end
        end
    end
end
function City:SelectOption(option)
    if not (option and self.gossipOpen and C_GossipInfo
        and type(C_GossipInfo.SelectOption)=='function') then return false end
    local matched=self.optionLookup and self.optionLookup[tonumber(option.id)]
    if not matched or matched~=option.name then return false end
    self.pendingOption=option.name
    local ok=pcall(C_GossipInfo.SelectOption,option.id)
    if not ok then self.pendingOption=nil end
    return ok
end
-- Guard destinations and previously recorded directions use the same
-- built-in waypoint path. A map pin does not automatically super-track.
function City:SelectDestination(point)
    if not point or not Position(point) then return false end
    self.currentDestination=point
    self.destinationCityID=AF:GetAtlasCityMap()
    self.nativeWaypointStatus='unsupported'
    if C_Map and type(C_Map.SetUserWaypoint)=='function' then
        local permitted=true
        if type(C_Map.CanSetUserWaypointOnMap)=='function' then
            local ok,value=pcall(C_Map.CanSetUserWaypointOnMap,point.mapID)
            permitted=ok and value==true
        end
        if permitted then
            local position
            if type(CreateVector2D)=='function' then position=CreateVector2D(point.x,point.y) end
            if position then
                local target={uiMapID=point.mapID,position=position}
                if UiMapPoint and type(UiMapPoint.CreateFromVector2D)=='function' then
                    local ok,value=pcall(UiMapPoint.CreateFromVector2D,point.mapID,position)
                    if ok and value then target=value end
                end
                local ok,wasSet=pcall(C_Map.SetUserWaypoint,target)
                if ok and wasSet==true then
                    self.nativeWaypointStatus='set'
                    if C_SuperTrack and type(C_SuperTrack.SetSuperTrackedUserWaypoint)=='function' then
                        local tracked=pcall(C_SuperTrack.SetSuperTrackedUserWaypoint,true)
                        if tracked then self.nativeWaypointStatus='supertracked' end
                    end
                else
                    self.nativeWaypointStatus=ok and 'rejected' or 'error'
                end
            else self.nativeWaypointStatus='no-vector' end
        else self.nativeWaypointStatus='blocked-on-map' end
    end
    -- The native Forever navigation marker may be hidden by the game client.
    -- Our small minimap arrow is independent of that UI preference.
    self:EnableMinimapGuidance()
    Notify()
    return true
end

-- WoW world axes are North (+X) and West (+Y). Minimap defaults North-up;
-- rotating minimaps instead display the player's facing at the top.
-- Only a verified same-continent world vector is used; no guessed floor/zone
-- coordinates, and no guidance through instances with unavailable positions.
-- A world-position vector has no requirement to be normalized to 0..1,
-- unlike a UiMapPoint. Supports both Vector2D and plain tables from Forever.
local function PositionWorld(pos)
    if not pos then return end
    if type(pos.GetXY)=='function' then
        local ok,x,y=pcall(pos.GetXY,pos)
        if ok and type(x)=='number' and type(y)=='number' then return x,y end
    end
    if type(pos)=='table' and type(pos.x)=='number' and type(pos.y)=='number' then
        return pos.x,pos.y
    end
end


function City:GetMinimapGuidanceVector()
    local point=self.currentDestination
    if not point or not Position(point) or not self.destinationCityID then return end
    local cityID=AF:GetAtlasCityMap()
    if cityID~=self.destinationCityID then return end
    if not (C_Map and type(C_Map.GetWorldPosFromMapPos)=='function'
        and type(C_Map.GetPlayerMapPosition)=='function') then return end
    local ok,instance,target=pcall(C_Map.GetWorldPosFromMapPos,point.mapID,{x=point.x,y=point.y})
    if not ok or type(instance)~='number' or not target then return end
    local playerMap=point.mapID
    local got,pos=pcall(C_Map.GetPlayerMapPosition,playerMap,'player')
    if not got or not pos then
        local have,fallback=pcall(C_Map.GetBestMapForUnit or function() end,'player')
        if not have or type(fallback)~='number' then return end
        playerMap=fallback
        got,pos=pcall(C_Map.GetPlayerMapPosition,playerMap,'player')
        if not got or not pos then return end
    end
    local fine,playerInstance,player=pcall(C_Map.GetWorldPosFromMapPos,playerMap,pos)
    if not fine or playerInstance~=instance or not player then return end
    local tx,ty=PositionWorld(target)
    local px,py=PositionWorld(player)
    if not tx or not px then return end
    local north,west=tx-px,ty-py
    local distance=math.sqrt(north*north+west*west)
    if distance<10 then return nil,nil,distance end
    if distance==0 then return end
    north,west=north/distance,west/distance
    if type(GetCVar)=='function' and GetCVar('rotateMinimap')=='1' then
        local ok,facing=pcall(type(GetPlayerFacing)=='function' and GetPlayerFacing or function() end)
        if not ok or type(facing)~='number' then return end
        local c,s=math.cos(facing),math.sin(facing)
        north,west=north*c+west*s,west*c-north*s
    end
    return -west,north,distance
end

function City:UpdateMinimapGuidance()
    local icon=self.minimapArrow
    if not icon then return end
    local dx,dy,distance=self:GetMinimapGuidanceVector()
    self.lastMinimapDistance=distance
    if not dx or not dy or not Minimap or not Minimap.IsShown or not Minimap:IsShown() then
        icon:Hide()
        return
    end
    local w,h=Minimap:GetWidth(),Minimap:GetHeight()
    if not w or not h or w<=0 or h<=0 then icon:Hide();return end
    -- Small and inside the circle, avoiding the outer border and map controls.
    local radius=math.max(10,math.min(w,h)*0.39)
    icon:ClearAllPoints()
    icon:SetPoint('CENTER',Minimap,'CENTER',dx*radius,dy*radius)
    local angle
    if math.atan2 then angle=math.atan2(-dx,dy)
    elseif type(atan2)=='function' then angle=atan2(-dx,dy)
    elseif dy==0 then angle=dx>0 and -math.pi/2 or math.pi/2
    else
        angle=math.atan(-dx/dy)
        if dy<0 then angle=angle+(dx>0 and -math.pi or math.pi) end
    end
    icon:SetRotation(angle)
    icon:Show()
end
function City:EnableMinimapGuidance()
    if not (Minimap and Minimap.CreateTexture and type(CreateFrame)=='function') then return end
    if not self.minimapArrow then
        local icon=Minimap:CreateTexture(nil,'OVERLAY',nil,7)
        icon:SetSize(21,21)
        -- This atlas is part of Blizzard's client, not redistributed artwork.
        local atlasAvailable=false
        if C_Texture and type(C_Texture.GetAtlasInfo)=='function' then
            local ok,info=pcall(C_Texture.GetAtlasInfo,'Navigation-Tracked-Arrow')
            atlasAvailable=ok and info~=nil
        end
        if atlasAvailable then
            icon:SetAtlas('Navigation-Tracked-Arrow',false)
        else
            icon:SetTexture('Interface\\Minimap\\MinimapArrow')
        end
        icon:SetVertexColor(1,.72,.20,1)
        icon:Hide()
        self.minimapArrow=icon
        local ticker=CreateFrame('Frame',nil,Minimap)
        ticker.elapsed=0
        ticker:SetScript('OnUpdate',function(frame,elapsed)
            frame.elapsed=frame.elapsed+elapsed
            if frame.elapsed<.15 then return end
            frame.elapsed=0
            City:UpdateMinimapGuidance()
            if not AF:GetAtlasCityMap() or not City.currentDestination then
                frame:Hide()
            end
        end)
        self.minimapTicker=ticker
    end
    self.minimapTicker.elapsed=0
    self.minimapTicker:Show()
    self:UpdateMinimapGuidance()
end

-- Events are lightweight. No periodic scanning and no guessing POI coordinates.
local watcher=CreateFrame('Frame')
for _,event in ipairs({'GOSSIP_SHOW','GOSSIP_OPTIONS_REFRESHED','GOSSIP_CLOSED','DYNAMIC_GOSSIP_POI_UPDATED',
    'ZONE_CHANGED_NEW_AREA','PLAYER_ENTERING_WORLD'}) do
    pcall(watcher.RegisterEvent,watcher,event)
end
watcher:SetScript('OnEvent',function(_,event)
    if event=='GOSSIP_SHOW' or event=='GOSSIP_OPTIONS_REFRESHED' then City:ReadGossip()
    elseif event=='GOSSIP_CLOSED' then
        City.gossipOpen=false;City.options={};City.optionLookup={}
        Notify()
    elseif event=='DYNAMIC_GOSSIP_POI_UPDATED' then City:ReadPOI()
    else
        City.gossipOpen=false;City.options={};City.optionLookup={}
        Notify()
        if City.minimapTicker then
            City.minimapTicker:SetShown(AF:GetAtlasCityMap()~=nil and City.currentDestination~=nil)
            City:UpdateMinimapGuidance()
        end
    end
end)
if type(hooksecurefunc)=='function' and C_GossipInfo then
    if type(C_GossipInfo.SelectOption)=='function' then
        pcall(hooksecurefunc,C_GossipInfo,'SelectOption',function(id) City:SelectedGuardOption(id) end)
    end
    if type(C_GossipInfo.SelectOptionByIndex)=='function' then
        pcall(hooksecurefunc,C_GossipInfo,'SelectOptionByIndex',function(id) City:SelectedGuardOption(id) end)
    end
end
