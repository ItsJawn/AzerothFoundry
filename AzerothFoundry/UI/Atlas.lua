-- v0.4.0.15: live map debugging; v0.4.0.14: restored exploration artwork after regression in 0.4.0.13; v0.4.0.12: Guard illustrated map art geometry; brighter native region highlight.
local _, AF = ...
local UI=AF.UI
local min,max,ceil,abs=math.min,math.max,math.ceil,math.abs

local function DateStamp(t)
    if not t or t<=0 then return 'Not recorded' end
    if type(date)=='function' then return date('%b %d %Y, %H:%M',t) end
    return 'Recorded'
end
-- Exploration navigation uses the same subdued leather/bronze controls as
-- Workshop. This is presentation only; the map renderer and all map APIs
-- remain entirely unchanged.
local function AtlasAction(parent,label,callback)
    local b=UI:Button(parent,label,callback,'row')
    b.label:SetJustifyH('CENTER')
    b.label:SetTextColor(.98,.87,.68)
    b.afThemeButtonTextRole="buttonText"
    if b.rowBase then b.rowBase:Hide() end
    local fill=b:CreateTexture(nil,'BACKGROUND',nil,-1)
    fill:SetPoint('TOPLEFT',b,'TOPLEFT',1,-1)
    fill:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-1,1)
    fill:SetColorTexture(.16,.108,.069,.96)
    local edgeTop=b:CreateTexture(nil,'BORDER')
    edgeTop:SetPoint('TOPLEFT',b,'TOPLEFT',2,-2)
    edgeTop:SetPoint('TOPRIGHT',b,'TOPRIGHT',-2,-2)
    edgeTop:SetHeight(1)
    edgeTop:SetColorTexture(.60,.42,.23,.82)
    local edgeBottom=b:CreateTexture(nil,'BORDER')
    edgeBottom:SetPoint('BOTTOMLEFT',b,'BOTTOMLEFT',2,2)
    edgeBottom:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-2,2)
    edgeBottom:SetHeight(1)
    edgeBottom:SetColorTexture(.34,.23,.15,.75)
    if UI.RegisterThemeTarget then
        UI:RegisterThemeTarget(b,function(_,tokens)
            local face=tokens.buttonFace
            local border=tokens.divider
            fill:SetColorTexture(face[1],face[2],face[3],.98)
            edgeTop:SetColorTexture(border[1],border[2],border[3],.85)
            edgeBottom:SetColorTexture(border[1],border[2],border[3],.55)
            b.label:SetTextColor(unpack(tokens.buttonText))
        end)
    end
    return b
end
local function Cursor()
    if not GetCursorPosition then return nil,nil end
    local x,y=GetCursorPosition()
    local scale=UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    return x/scale,y/scale
end
local function SafePlayerPosition(mapID)
    if not C_Map or not C_Map.GetPlayerMapPosition then return nil end
    local ok,p=pcall(C_Map.GetPlayerMapPosition,mapID,'player')
    if ok and p and p.GetXY then
        local valid,x,y=pcall(p.GetXY,p)
        if valid and type(x)=='number' and type(y)=='number' and x>=0 and x<=1 and y>=0 and y<=1 then
            return x,y
        end
    end
end
local function GetArt(mapID)
    if not C_Map or not C_Map.GetMapArtLayers or not C_Map.GetMapArtLayerTextures then return nil end
    local ok,layers=pcall(C_Map.GetMapArtLayers,mapID)
    if not ok or type(layers)~='table' then return nil end
    -- The base-resolution layer is enough for the first atlas experiment.
    -- Later we can add native detail-layer zoom and fog-of-war overlays.
    for index,layer in ipairs(layers) do
        if layer.layerWidth and layer.layerHeight and layer.tileWidth and layer.tileHeight
            and layer.layerWidth>0 and layer.layerHeight>0 and layer.tileWidth>0 and layer.tileHeight>0 then
            local yes,files=pcall(C_Map.GetMapArtLayerTextures,mapID,index)
            if yes and type(files)=='table' and #files>0 then return layer,files end
        end
    end
end

function UI:BuildAtlas(page)
    local pal=self.palette
    local left=self:Card(page,pal.parchmentLight)
    left:SetPoint('TOPLEFT',page,'TOPLEFT',10,-12)
    left:SetPoint('BOTTOMLEFT',page,'BOTTOMLEFT',10,11)
    left:SetWidth(181)
    local right=self:Card(page,pal.parchmentLight)
    right:SetPoint('TOPRIGHT',page,'TOPRIGHT',-10,-12)
    right:SetPoint('BOTTOMRIGHT',page,'BOTTOMRIGHT',-10,11)
    right:SetWidth(181)
    local center=self:Card(page,pal.parchmentLight)
    center:SetPoint('TOPLEFT',left,'TOPRIGHT',9,0)
    center:SetPoint('BOTTOMRIGHT',right,'BOTTOMLEFT',-9,0)

    local lt=self:SectionTitle(left,'Map Navigation')
    lt:SetPoint('TOPLEFT',12,-11); lt:SetPoint('TOPRIGHT',-11,-11)
    local current=AtlasAction(left,'My Location',function()
        local id=AF:GetAtlasCurrentMap()
        if id then page:Navigate(id) end
    end)
    current:SetPoint('TOPLEFT',12,-51);current:SetPoint('TOPRIGHT',-12,-51);current:SetHeight(27)
    local continentButtons={}
    for i=1,2 do
        local button=AtlasAction(left,'',function()
            if continentButtons[i].mapID then page:Navigate(continentButtons[i].mapID) end
        end)
        button:SetPoint('TOPLEFT',12,-84-(i-1)*31)
        button:SetPoint('TOPRIGHT',-12,-84-(i-1)*31)
        button:SetHeight(27)
        continentButtons[i]=button
    end
    local regionTitle=self:SectionTitle(left,'Nearby Regions')
    regionTitle:SetPoint('TOPLEFT',12,-159);regionTitle:SetPoint('TOPRIGHT',-12,-159)
    local zoneList=self:List(left,31)
    zoneList:SetPoint('TOPLEFT',12,-197)
    zoneList:SetPoint('BOTTOMRIGHT',-28,80)
    local scope=AtlasAction(left,'',function()
        local s=AF.db.settings.atlas
        s.scope= s.scope=='character' and 'all' or s.scope=='all' and 'expedition' or 'character'
        page:Refresh()
    end)
    scope:SetPoint('BOTTOMLEFT',12,19);scope:SetPoint('BOTTOMRIGHT',-12,19);scope:SetHeight(30)
    local scopeLabel=self:Text(left,'small',pal.ink,'CENTER')
    scopeLabel:SetPoint('BOTTOMLEFT',12,53);scopeLabel:SetPoint('BOTTOMRIGHT',-12,53);scopeLabel:SetHeight(19)

    -- The separate Zones and History buttons merely duplicated the center
    -- Zone Journal. The old Discoveries text was a stale placeholder from
    -- before the working native exploration tracking. Do NOT remove or alter
    -- any saved zone, history, or exploration records.
    local rt=self:SectionTitle(right,'Quest Journal')
    rt:SetPoint('TOPLEFT',12,-11);rt:SetPoint('TOPRIGHT',-12,-11)
    local quests=AtlasAction(right,'Quests',function()
        if UI.ToggleQuestJournal then UI:ToggleQuestJournal() end
    end)
    quests:SetHeight(29)
    quests:SetPoint('TOPLEFT',right,'TOPLEFT',12,-48)
    quests:SetPoint('TOPRIGHT',right,'TOPRIGHT',-12,-48)
    local recap=AtlasAction(right,'Quest Recap',function()
        if UI.ToggleQuestRecap then UI:ToggleQuestRecap() end
    end)
    recap:SetHeight(29)
    recap:SetPoint('TOPLEFT',right,'TOPLEFT',12,-84)
    recap:SetPoint('TOPRIGHT',right,'TOPRIGHT',-12,-84)
    local recordTitle=self:SectionTitle(right,'Selected Region')
    recordTitle:SetPoint('TOPLEFT',12,-137)
    recordTitle:SetPoint('TOPRIGHT',-12,-137)
    local rightText=self:Text(right,'small',pal.ink)
    rightText:SetPoint('TOPLEFT',right,'TOPLEFT',13,-174)
    rightText:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-13,273)
    rightText:SetJustifyV('TOP')
    local goalTitle=self:SectionTitle(right,'Exploration Goals')
    goalTitle:SetPoint('BOTTOMLEFT',right,'BOTTOMLEFT',12,230)
    goalTitle:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-12,230)
    -- Goals still use the existing exact visit / known quest APIs; they never
    -- infer all possible quests or 100-percent completion from recorded visits.
    local function AddAtlasGoal(kind)
        local sc=AF.db.settings.atlas.scope
        if sc=='expedition' then
            AF.Print('Switch Atlas scope to This character or All registered to create an Exploration Goal.')
            return
        end
        local project,reason=AF:CreateExplorationGoal(page.mapID,kind,sc=='all' and 'all' or 'character')
        if not project then AF.Print(reason or 'Unable to create Exploration Goal.');return end
        UI.selectedProjectId=project.id
        if UI.Open then UI:Open('Goals') end
    end
    local visitGoal=AtlasAction(right,'Goal: Visit Zone',function() AddAtlasGoal('visit') end)
    visitGoal:SetPoint('BOTTOMLEFT',right,'BOTTOMLEFT',12,190)
    visitGoal:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-12,190)
    visitGoal:SetHeight(29)
    local questGoal=AtlasAction(right,'Goal: Known Quests',function() AddAtlasGoal('quests') end)
    questGoal:SetPoint('BOTTOMLEFT',right,'BOTTOMLEFT',12,155)
    questGoal:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-12,155)
    questGoal:SetHeight(29)
    -- AtlasTerrain attaches its own terrain toggle/status below these goals.
    -- Keep the native terrain diagnostics area free of overlapping buttons.
    local rightFooter=self:Text(right,'small',pal.ink,'CENTER')
    rightFooter:SetPoint('BOTTOMLEFT',right,'BOTTOMLEFT',12,15)
    rightFooter:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-12,15)
    rightFooter:SetHeight(30)
    rightFooter:SetText('Recorded locally')

    local ct=self:SectionTitle(center,'World Map')
    ct:SetPoint('TOPLEFT',13,-11);ct:SetPoint('TOPRIGHT',-13,-11)
    local up=AtlasAction(center,'Up',function() page:Up() end)
    up:SetSize(60,25);up:SetPoint('TOPLEFT',13,-43)
    local home=AtlasAction(center,'Continent',function()
        local id=AF:GetAtlasContinent(page.mapID)
        if id then page:Navigate(id) else page:Navigate(AF:GetAtlasDefaultMap()) end
    end)
    home:SetSize(98,25);home:SetPoint('LEFT',up,'RIGHT',6,0)
    local world=AtlasAction(center,'Open M Map',function()
        if type(ToggleWorldMap)=='function' then ToggleWorldMap()
        elseif WorldMapFrame and WorldMapFrame.Show then WorldMapFrame:Show()
        else AF.Print('Blizzard world map is unavailable right now.') end
    end)
    world:SetSize(111,25);world:SetPoint('TOPRIGHT',-13,-43)
    local mapName=self:Text(center,'small',pal.ink,'CENTER')
    mapName:SetPoint('LEFT',home,'RIGHT',7,0)
    mapName:SetPoint('RIGHT',world,'LEFT',-7,0)
    mapName:SetHeight(27)

    local viewport=self:NewFrame('Frame',center)
    viewport:SetPoint('TOPLEFT',13,-77)
    viewport:SetPoint('BOTTOMRIGHT',-13,157)
    if viewport.SetClipsChildren then viewport:SetClipsChildren(true) end
    local under=viewport:CreateTexture(nil,'BACKGROUND')
    under:SetAllPoints(viewport);under:SetColorTexture(0.12,0.10,0.065,1)
    local mapCanvas=CreateFrame('Frame',nil,viewport)
    mapCanvas:SetSize(10,10);mapCanvas:SetPoint('CENTER',viewport,'CENTER')
    local mapTiles={}
    local playerArrow=mapCanvas:CreateTexture(nil,'OVERLAY')
    playerArrow:SetTexture('Interface\\Minimap\\MinimapArrow')
    playerArrow:SetSize(17,17);playerArrow:Hide()
    local missing=self:Text(viewport,'small',pal.pale,'CENTER')
    missing:SetPoint('CENTER',viewport,'CENTER');missing:SetWidth(310);missing:SetHeight(70)
    missing:SetText('Select a region to view Blizzard map artwork.')
    local hover=self:Text(viewport,'small',pal.gold,'CENTER')
    hover:SetPoint('TOP',viewport,'TOP',0,-7);hover:SetSize(320,24)
    local mapHint=self:Text(center,'small',pal.ink,'CENTER')
    mapHint:SetPoint('TOPLEFT',viewport,'BOTTOMLEFT',0,-4)
    mapHint:SetPoint('TOPRIGHT',viewport,'BOTTOMRIGHT',0,-4)
    mapHint:SetHeight(22)
    mapHint:SetText('Click a region to enter  •  Right-click: back  •  Drag: pan  •  Wheel: zoom')
    -- v0.4.3.1: concise, live Explorer-criteria progress immediately below
    -- the map controls. This is intentionally not a Goals/project progress bar.
    local explorationRow=self:NewFrame('Frame',center)
    explorationRow:SetPoint('TOPLEFT',mapHint,'BOTTOMLEFT',0,-2)
    explorationRow:SetPoint('TOPRIGHT',mapHint,'BOTTOMRIGHT',0,-2)
    explorationRow:SetHeight(20)
    local explorationLabel=self:Text(explorationRow,'small',pal.ink,'LEFT')
    explorationLabel:SetPoint('LEFT',explorationRow,'LEFT',1,0)
    explorationLabel:SetSize(105,18)
    explorationLabel:SetText('Exploration')
    local explorationCount=self:Text(explorationRow,'small',pal.ink,'RIGHT')
    explorationCount:SetPoint('RIGHT',explorationRow,'RIGHT',-1,0)
    explorationCount:SetSize(135,18)
    local explorationTrack=explorationRow:CreateTexture(nil,'BACKGROUND')
    explorationTrack:SetColorTexture(.34,.26,.16,.9)
    explorationTrack:SetPoint('LEFT',explorationLabel,'RIGHT',5,0)
    explorationTrack:SetPoint('RIGHT',explorationCount,'LEFT',-6,0)
    explorationTrack:SetHeight(10)
    local explorationFill=explorationRow:CreateTexture(nil,'ARTWORK')
    explorationFill:SetColorTexture(.72,.57,.29,1)
    explorationFill:SetPoint('LEFT',explorationTrack,'LEFT',0,0)
    explorationFill:SetHeight(10)
    explorationFill:SetWidth(1)
    explorationRow:EnableMouse(true)
    explorationRow:SetScript('OnEnter',function(frame)
        if not GameTooltip then return end
        GameTooltip:SetOwner(frame,'ANCHOR_TOP')
        local record=page.explorationRecord
        GameTooltip:AddLine('Zone exploration')
        local view=AF.db and AF.db.settings.atlas.scope or 'character'
        GameTooltip:AddLine(view=='all' and 'Combined discoveries — all registered characters'
            or view=='expedition' and 'Combined discoveries — Expedition characters'
            or 'This character only',.85,.72,.44)
        if record then
            GameTooltip:AddLine(string.format('%d / %d areas discovered (%d%%)',record.done,record.total,record.percent),1,1,1)
            GameTooltip:AddLine(string.format('%d area%s remaining',record.remaining,record.remaining==1 and '' or 's'),1,1,1)
            GameTooltip:AddLine('From Explorer achievement criteria',.62,.62,.62)
            if view~='character' then
                GameTooltip:AddLine('Includes discoveries saved when other characters played with Foundry.',.62,.62,.62,true)
                GameTooltip:AddLine(string.format('%d character snapshot(s) for this zone',record.characters or 0),.85,.72,.44)
                GameTooltip:AddLine('Log into each alt once to archive its discoveries.',.62,.62,.62,true)
            end
        else
            GameTooltip:AddLine('Progress unavailable for this zone',1,1,1)
        end
        GameTooltip:Show()
    end)
    explorationRow:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
    function page:RefreshExplorationProgress()
        local zone=AF:GetAtlasMapInfo(self.mapID)
        if not zone or tonumber(zone.mapType)~=3 then
            explorationRow:Hide()
            self.explorationRecord=nil
            return
        end
        explorationRow:Show()
        local scope=AF.db and AF.db.settings.atlas.scope or 'character'
        local ok,record,reason=pcall(AF.GetAtlasExplorationProgress,AF,self.mapID,scope)
        if not ok then record=nil;reason='Progress unavailable' end
        self.explorationRecord=record
        if record then
            explorationCount:SetText(string.format('%d/%d  %d%%',record.done,record.total,record.percent))
            local w=explorationTrack:GetWidth()
            explorationFill:SetWidth(math.max(1,(w>1 and w or 120)*record.done/record.total))
            if record.done>0 then explorationFill:Show() else explorationFill:Hide() end
        else
            explorationCount:SetText(reason or 'Progress unavailable')
            explorationFill:Hide()
        end
    end
    explorationTrack:GetParent():HookScript('OnSizeChanged',function() if page.mapID then page:RefreshExplorationProgress() end end)
    local summaryTitle=self:SectionTitle(center,'Zone Journal')
    summaryTitle:SetPoint('TOPLEFT',13,-2)
    summaryTitle:ClearAllPoints();summaryTitle:SetPoint('TOPLEFT',explorationRow,'BOTTOMLEFT',0,-2)
    summaryTitle:SetPoint('TOPRIGHT',explorationRow,'BOTTOMRIGHT',0,-2)
    local summary=self:Text(center,'small',pal.ink)
    summary:SetPoint('TOPLEFT',summaryTitle,'BOTTOMLEFT',0,-7)
    summary:SetPoint('BOTTOMRIGHT',center,'BOTTOMRIGHT',-14,10)
    summary:SetJustifyV('TOP')

    page.mapID=nil
    page.tiles=mapTiles
    page.viewport=viewport
    page.mapCanvas=mapCanvas
    page.mapMissing=missing
    page.mapPlayer=playerArrow
    page.zoom=1
    page.offsetX=0
    page.offsetY=0
    page.drawnMap=nil

    function page:Up()
        local info=AF:GetAtlasMapInfo(self.mapID)
        if info and info.parentMapID and info.parentMapID~=0 then self:Navigate(info.parentMapID) end
    end
    function page:Navigate(id)
        local info=AF:GetAtlasMapInfo(id)
        if not info then return end
        self.mapID=id
        self.zoom=1
        self.offsetX=0;self.offsetY=0
        self.drawnMap=nil
        AF.db.settings.atlas.mapID=id
        self:Refresh()
    end
    function page:RepositionTiles()
        if not self.layer then return end
        local vw,vh=viewport:GetWidth(),viewport:GetHeight()
        if vw<10 or vh<10 then return end
        local aspect=self.layer.layerWidth/self.layer.layerHeight
        local fitW=min(vw-8,(vh-8)*aspect)
        local fitH=fitW/aspect
        local w,h=fitW*self.zoom,fitH*self.zoom
        mapCanvas:ClearAllPoints()
        -- Don't let dragging the whole texture entirely outside the viewport.
        local maxX=max(0,(w-vw)/2)+24
        local maxY=max(0,(h-vh)/2)+24
        self.offsetX=max(-maxX,min(maxX,self.offsetX))
        self.offsetY=max(-maxY,min(maxY,self.offsetY))
        mapCanvas:SetPoint('CENTER',viewport,'CENTER',self.offsetX,self.offsetY)
        mapCanvas:SetSize(w,h)
        local nativeW,nativeH=self.layer.layerWidth,self.layer.layerHeight
        local cols=ceil(nativeW/self.layer.tileWidth)
        for i,tile in ipairs(mapTiles) do
            if i<=(self.baseTileCount or 0) then
                local col=(i-1)%cols
                local row=math.floor((i-1)/cols)
                local tx=col*self.layer.tileWidth
                local ty=row*self.layer.tileHeight
                local actualW=min(self.layer.tileWidth,nativeW-tx)
                local actualH=min(self.layer.tileHeight,nativeH-ty)
                if actualW>0 and actualH>0 then
                    tile:ClearAllPoints()
                    tile:SetPoint('TOPLEFT',mapCanvas,'TOPLEFT',tx/nativeW*w,-ty/nativeH*h)
                    tile:SetSize(actualW/nativeW*w,actualH/nativeH*h)
                end
            end
        end
        local px,py=SafePlayerPosition(self.mapID)
        if px then
            playerArrow:ClearAllPoints()
            playerArrow:SetPoint('CENTER',mapCanvas,'TOPLEFT',w*px,-h*py)
            playerArrow:Show()
        else playerArrow:Hide() end
    end
    function page:RenderMap()
        local layer,files=GetArt(self.mapID)
        self.layer=layer
        self.baseTileCount=0
        for _,t in ipairs(mapTiles) do t:Hide() end
        if not layer then
            missing:SetText('Native map art unavailable for this area.\nUse Open M Map or select another region.')
            missing:Show();playerArrow:Hide();return
        end
        local cols=ceil(layer.layerWidth/layer.tileWidth)
        local rows=ceil(layer.layerHeight/layer.tileHeight)
        local count=min(#files,cols*rows,200)
        if count<1 then
            missing:SetText('Map textures were not returned by the client.')
            missing:Show();return
        end
        missing:Hide()
        self.baseTileCount=count
        for i=1,count do
            local tile=mapTiles[i]
            if not tile then tile=mapCanvas:CreateTexture(nil,'ARTWORK');mapTiles[i]=tile end
            tile:SetTexture(files[i])
            local col=(i-1)%cols
            local row=math.floor((i-1)/cols)
            local tw=min(layer.tileWidth,layer.layerWidth-col*layer.tileWidth)
            local th=min(layer.tileHeight,layer.layerHeight-row*layer.tileHeight)
            tile:SetTexCoord(0,tw/layer.tileWidth,0,th/layer.tileHeight)
            tile:Show()
        end
        self:RepositionTiles()
    end
    local function NormalizedPoint()
        local x,y=Cursor()
        if not x or not mapCanvas:GetLeft() or not mapCanvas:GetTop() then return nil end
        local w,h=mapCanvas:GetWidth(),mapCanvas:GetHeight()
        if w<=0 or h<=0 then return nil end
        local px=(x-mapCanvas:GetLeft())/w
        local py=(mapCanvas:GetTop()-y)/h
        if px>=0 and px<=1 and py>=0 and py<=1 then return px,py end
    end
    local function MapAtCursor()
        local nx,ny=NormalizedPoint()
        if not nx or not C_Map or not C_Map.GetMapInfoAtPosition then return nil end
        local ok,info=pcall(C_Map.GetMapInfoAtPosition,page.mapID,nx,ny)
        if ok and type(info)=='table' and info.mapID then return info end
    end
    viewport:EnableMouse(true)
    viewport:EnableMouseWheel(true)
    viewport:SetScript('OnMouseWheel',function(_,delta)
        local old=page.zoom
        page.zoom=max(1,min(3,page.zoom+(delta>0 and 0.25 or -0.25)))
        if old~=page.zoom then page:RepositionTiles() end
    end)
    viewport:SetScript('OnMouseDown',function(_,button)
        if button=='RightButton' then page:Up();return end
        if button~='LeftButton' then return end
        if page.DebugPickArmed then
            page.DebugPickPending=true
            page.mouseDown=false
            return
        end
        page.mouseDown=true
        page.dragged=false
        page.startX,page.startY=Cursor()
        page.panStartX,page.panStartY=page.offsetX,page.offsetY
    end)
    viewport:SetScript('OnMouseUp',function(_,button)
        if button~='LeftButton' then return end
        if page.DebugPickPending then
            page.DebugPickPending=false
            if page.DebugCaptureCursor then page:DebugCaptureCursor() end
            return
        end
        if not page.mouseDown then return end
        page.mouseDown=false
        if not page.dragged then
            local info=MapAtCursor()
            if info and info.mapID~=page.mapID then page:Navigate(info.mapID) end
        end
    end)
    viewport:SetScript('OnHide',function() page.mouseDown=false end)
    local tick=0
    viewport:SetScript('OnUpdate',function(_,elapsed)
        if page.mouseDown then
            local x,y=Cursor()
            if x and page.startX then
                local dx,dy=x-page.startX,y-page.startY
                if abs(dx)>4 or abs(dy)>4 then page.dragged=true end
                if page.dragged then
                    page.offsetX=page.panStartX+dx
                    page.offsetY=page.panStartY+dy
                    page:RepositionTiles()
                end
            end
        end
        tick=tick+(elapsed or 0)
        if tick>0.28 then
            tick=0
            if not page.mouseDown then
                local info=MapAtCursor()
                hover:SetText(info and info.mapID~=page.mapID and info.name or '')
            end
        end
    end)
    viewport:SetScript('OnSizeChanged',function()
        if page.layer then page:RepositionTiles() end
    end)

    function page:Refresh()
        local settings=AF.db.settings.atlas
        local id=self.mapID or settings.mapID or AF:GetAtlasDefaultMap()
        if not AF:GetAtlasMapInfo(id) then id=AF:GetAtlasDefaultMap() end
        if not id then return end
        self.mapID=id
        settings.mapID=id
        local info=AF:GetAtlasMapInfo(id)
        mapName:SetText(info and info.name or 'Unknown map')
        if self.RefreshExplorationProgress then self:RefreshExplorationProgress() end
        local scopeChanged=self.lastExplorationScope~=settings.scope
        self.lastExplorationScope=settings.scope
        visitGoal:SetEnabled(info and info.mapType==3 or false)
        questGoal:SetEnabled(info and info.mapType==3 or false)
        up:SetEnabled(info and info.parentMapID and info.parentMapID~=0 and AF:GetAtlasMapInfo(info.parentMapID)~=nil or false)
        local continents=AF:GetAtlasContinents()
        for i,button in ipairs(continentButtons) do
            local entry=continents[i]
            button.mapID=entry and entry.mapID
            button.label:SetText(entry and entry.label or '—')
            button:SetEnabled(entry~=nil)
        end
        local children=AF:GetAtlasMapChildren(id)
        UI:FillList(zoneList,children,function(entry) self:Navigate(entry.mapID) end,id)
        if self.drawnMap~=id then
            self.drawnMap=id
            self:RenderMap()
        else self:RepositionTiles() end
        -- Switching scope changes both the revealed artwork and the terrain
        -- mask manifest even when the selected map itself hasn't changed.
        if scopeChanged and self.drawnMap==id then
            if self.RefreshLayers then self:RefreshLayers() end
            if self.DebugTerrainModeChanged then self:DebugTerrainModeChanged(true) end
        end
        local labels={character='This character',all='All registered',expedition='Expedition'}
        scope.label:SetText('View: '..(labels[settings.scope] or 'This character'))
        scopeLabel:SetText('Atlas view / discoveries')
        local scopeName=labels[settings.scope] or 'This character'
        local summaryData=AF:GetAtlasZoneSummary(id,settings.scope)
        local areaLine=summaryData.areas>0 and tostring(summaryData.areas)..' recorded zone(s)' or 'No visits recorded for this view'
        summary:SetText((info and info.name or 'Unknown region')..'  •  '..scopeName..'\n'
            ..areaLine..'  |  First seen: '..DateStamp(summaryData.firstSeen)
            ..'\nLast seen: '..DateStamp(summaryData.lastSeen)
            ..'  |  Recorded visits: '..tostring(summaryData.visits))
        -- The center Zone Journal already owns the detailed visit history.
        -- The sidebar provides a concise record and the two actual quest tools.
        local zoneName=info and info.name or 'Unknown region'
        local recordLines={zoneName,areaLine}
        if summaryData.visits and summaryData.visits>0 then
            recordLines[#recordLines+1]='Recorded visits: '..tostring(summaryData.visits)
            recordLines[#recordLines+1]='Last seen: '..DateStamp(summaryData.lastSeen)
        else
            recordLines[#recordLines+1]='No local visit history yet'
        end
        rightText:SetText(table.concat(recordLines,'\n'))
    end
    page:Refresh()
    -- Refresh the Explorer bar on actual client discovery/achievement changes;
    -- never poll or recalculate exploration from revealed map textures.
    local explorationWatcher=CreateFrame('Frame',nil,page)
    for _,event in ipairs({'MAP_EXPLORATION_UPDATED','CRITERIA_UPDATE',
        'ACHIEVEMENT_EARNED','PLAYER_ENTERING_WORLD'}) do
        pcall(explorationWatcher.RegisterEvent,explorationWatcher,event)
    end
    explorationWatcher:SetScript('OnEvent',function(_,event)
        if event=='PLAYER_ENTERING_WORLD' and AF.ClearAtlasExplorationLookup then
            AF:ClearAtlasExplorationLookup()
        end
        if AF.CaptureCurrentAtlasDiscovery then AF:CaptureCurrentAtlasDiscovery() end
        if page:IsShown() then
            page:RefreshExplorationProgress()
            if page.RefreshLayers then page:RefreshLayers() end
            if page.DebugTerrainModeChanged then page:DebugTerrainModeChanged(true) end
        end
    end)

    -- v0.4.0.2: Optional map layers are installed only AFTER the complete
    -- v0.4.0 map has been built and populated.  An overlay failure must never
    -- interrupt PLAYER_LOGIN or break native map navigation.
    local function OptionalError(stage,reason)
        if page.afOverlayError then return end -- report once per view, no spam
        page.afOverlayError=tostring(stage)..': '..tostring(reason)
        if AF.Print then AF.Print('Atlas enhancement disabled ('..page.afOverlayError..'). Base map remains available; /af atlasdebug for details.') end
    end
    local function Safely(stage,func,...)
        local ok,result=pcall(func,...)
        if not ok then OptionalError(stage,result) end
        return ok,result
    end
    local function SetupExtras()
        local baseRender=page.RenderMap
        local basePosition=page.RepositionTiles
        local exploredTiles,questTiles,questData={},{},{}
        local capitalPins,capitalData={},{}
        local function DebugOn(key)
            local d=page.afMapDebug
            return not d or not d.flags or d.flags[key]~=false
        end
        -- Higher-resolution *world-map art* is safe to blend at closer zoom.
        -- This is NOT the client minimap terrain: its file IDs and exploration
        -- masks require a separate aligned dataset. Do not expose terrain here.
        local detailTiles,detailLayer,detailCount={},{},0
        -- Region hover is a separate native texture from the working quest
        -- blob layer. Its source art may include an opaque black background,
        -- so ADD compositing keeps black pixels invisible while preserving the
        -- lit blue boundary. No artificial rectangular/cursor fallback exists.
        local regionHighlight=mapCanvas:CreateTexture(nil,'ARTWORK',nil,5)
        regionHighlight:SetBlendMode('ADD')
        regionHighlight:SetVertexColor(.76,1,1,1) -- brighter cyan-blue additive outline, without opaque black
        regionHighlight:Hide()
        page.regionHighlight=regionHighlight
        page.hoverStatus='ready'
        local highlightKey=nil
        local highlightTick=0
        page.detailTiles=detailTiles
        page.exploredTiles=exploredTiles
        page.questTiles=questTiles
        page.questPinData=questData
        page.capitalPins=capitalPins
        page.capitalPinData=capitalData
        page.afOverlayError=nil
        local function Opts()
            local settings=AF.db and AF.db.settings and AF.db.settings.atlas
            if not settings then return {} end
            if settings.showExploration==nil then settings.showExploration=true end
            if settings.showQuestPins==nil then settings.showQuestPins=true end
            settings.playerArrowSize=max(10,min(44,tonumber(settings.playerArrowSize) or 17))
            return settings
        end
        local function ApplyArrowSize()
            -- Slider remains the 1x baseline; zoom grows the arrow in screen
            -- pixels so it remains legible against enlarged map detail.
            local baseline=Opts().playerArrowSize or 17
            local multiplier=math.sqrt(max(1,page.zoom or 1))
            local size=max(10,min(72,math.floor(baseline*multiplier+.5)))
            playerArrow:SetSize(size,size)
        end
        local function UpdateArrow()
            if not DebugOn('arrow') then playerArrow:Hide();return end
            ApplyArrowSize()
            local px,py=SafePlayerPosition(page.mapID)
            if px and py and page.layer then
                local w,h=mapCanvas:GetWidth(),mapCanvas:GetHeight()
                if w>0 and h>0 then
                    playerArrow:ClearAllPoints()
                    playerArrow:SetPoint('CENTER',mapCanvas,'TOPLEFT',w*px,-h*py)
                    playerArrow:Show()
                end
            else playerArrow:Hide() end
            if type(GetPlayerFacing)=='function' and type(playerArrow.SetRotation)=='function' then
                local ok,angle=pcall(GetPlayerFacing)
                if ok and type(angle)=='number' then playerArrow:SetRotation(angle) end
            end
        end
        local function UpdateDetailOpacity()
            if detailCount==0 then return end
            -- Fade a second native map-art layer in as you zoom, avoiding the
            -- ugly enlargement of only the base map. Zone maps only.
            local info=AF:GetAtlasMapInfo(page.mapID)
            local isZone=info and tonumber(info.mapType)==3
            local alpha=isZone and max(0,min(1,(page.zoom-1.45)/1.3)) or 0
            -- The high-res illustrated map is NOT the explored minimap terrain.
            -- Never blend both at once: they may have independent art crops.
            local settings=AF.db and AF.db.settings and AF.db.settings.atlas
            if settings and settings.terrainEnabled and not
                (page.afMapDebug and page.afMapDebug.flags.forceDetail) then alpha=0 end
            if not DebugOn('detail') then alpha=0 end
            for i=1,detailCount do detailTiles[i]:SetAlpha(alpha) end
        end
        local function PositionDetail()
            if detailCount==0 or not detailLayer then return end
            local nw,nh=detailLayer.layerWidth,detailLayer.layerHeight
            local w,h=mapCanvas:GetWidth(),mapCanvas:GetHeight()
            if not nw or not nh or nw<=0 or nh<=0 then return end
            local cols=ceil(nw/detailLayer.tileWidth)
            for i=1,detailCount do
                local tex=detailTiles[i]
                local col=(i-1)%cols
                local row=math.floor((i-1)/cols)
                local tx,ty=col*detailLayer.tileWidth,row*detailLayer.tileHeight
                local tw=min(detailLayer.tileWidth,nw-tx)
                local th=min(detailLayer.tileHeight,nh-ty)
                tex:ClearAllPoints()
                local d=page.afMapDebug and page.afMapDebug.adjust.detail
                local sx,sy=d and d.sx or 1,d and d.sy or 1
                local dx,dy=d and d.x or 0,d and d.y or 0
                local nx,ny=tx/nw,ty/nh
                tex:SetPoint('TOPLEFT',mapCanvas,'TOPLEFT',((nx-.5)*sx+.5)*w+dx,-(((ny-.5)*sy+.5)*h+dy))
                tex:SetSize(tw/nw*w*sx,th/nh*h*sy)
            end
            UpdateDetailOpacity()
        end
        local function LoadDetail()
            for _,tex in ipairs(detailTiles) do tex:Hide() end
            detailLayer=nil
            detailCount=0
            page.debugDetailLayer=nil
            page.debugDetailCount=0
            if not page.layer or not C_Map or not C_Map.GetMapArtLayers or not C_Map.GetMapArtLayerTextures then return end
            local info=AF:GetAtlasMapInfo(page.mapID)
            if not info or tonumber(info.mapType)~=3 then return end
            local ok,layers=pcall(C_Map.GetMapArtLayers,page.mapID)
            if not ok or type(layers)~='table' then return end
            local basePixels=page.layer.layerWidth*page.layer.layerHeight
            local chosenFiles
            -- Prefer the most detailed art index, never the same resolution.
            for index,layer in ipairs(layers) do
                local pixels=(tonumber(layer.layerWidth) or 0)*(tonumber(layer.layerHeight) or 0)
                if pixels>basePixels and (not detailLayer or pixels>detailLayer.layerWidth*detailLayer.layerHeight)
                    and (tonumber(layer.tileWidth) or 0)>0 and (tonumber(layer.tileHeight) or 0)>0 then
                    local worked,files=pcall(C_Map.GetMapArtLayerTextures,page.mapID,index)
                    if worked and type(files)=='table' and #files>0 and #files<=200 then
                        detailLayer=layer;chosenFiles=files
                    end
                end
            end
            if not detailLayer or not chosenFiles then return end
            -- Some Forever art layers have different image proportions/crops.
            -- Scaling those over a base map stretches landmarks and introduces
            -- repeated strips. Fall back to one stable map-art layer instead.
            local baseAspect=page.layer.layerWidth/page.layer.layerHeight
            local detailAspect=detailLayer.layerWidth/detailLayer.layerHeight
            if abs(detailAspect/baseAspect-1)>.005 then
                detailLayer=nil
                return
            end
            local cols=ceil(detailLayer.layerWidth/detailLayer.tileWidth)
            local rows=ceil(detailLayer.layerHeight/detailLayer.tileHeight)
            detailCount=min(#chosenFiles,cols*rows,200)
            page.debugDetailLayer=detailLayer
            page.debugDetailCount=detailCount
            for i=1,detailCount do
                local tex=detailTiles[i]
                if not tex then tex=mapCanvas:CreateTexture(nil,'ARTWORK',nil,1);detailTiles[i]=tex end
                tex:SetTexture(chosenFiles[i])
                local col=(i-1)%cols;local row=math.floor((i-1)/cols)
                local tw=min(detailLayer.tileWidth,detailLayer.layerWidth-col*detailLayer.tileWidth)
                local th=min(detailLayer.tileHeight,detailLayer.layerHeight-row*detailLayer.tileHeight)
                tex:SetTexCoord(0,tw/detailLayer.tileWidth,0,th/detailLayer.tileHeight)
                tex:Show()
            end
            PositionDetail()
        end
        local function HideRegionHover()
            regionHighlight:Hide()
        end
        local function UpdateRegionHighlight()
            if not DebugOn('highlight') then HideRegionHover();return end
            if page.mouseDown or not page.layer or not C_Map or
                type(C_Map.GetMapHighlightInfoAtPosition)~='function' then
                HideRegionHover();return
            end
            local cx,cy=Cursor()
            local left,right,bottom,top=viewport:GetLeft(),viewport:GetRight(),viewport:GetBottom(),viewport:GetTop()
            local ml,mt=mapCanvas:GetLeft(),mapCanvas:GetTop()
            if not cx or not left or not right or not bottom or not top
                or cx<left or cx>right or cy<bottom or cy>top or not ml or not mt then
                HideRegionHover();return
            end
            local w,h=mapCanvas:GetWidth(),mapCanvas:GetHeight()
            if not w or not h or w<=0 or h<=0 then HideRegionHover();return end
            local nx,ny=(cx-ml)/w,(mt-cy)/h
            if nx<0 or nx>1 or ny<0 or ny>1 then HideRegionHover();return end
            local ok,fileID,atlasID,pctX,pctY,sizeX,sizeY,originX,originY=
                pcall(C_Map.GetMapHighlightInfoAtPosition,page.mapID,nx,ny)
            if not ok or not ((type(fileID)=='number' and fileID>0) or
                (type(atlasID)=='string' and atlasID~='')) or
                type(sizeX)~='number' or type(sizeY)~='number' or
                type(originX)~='number' or type(originY)~='number' or
                sizeX<=0 or sizeY<=0 then
                HideRegionHover();return
            end
            local nw,nh=page.layer.layerWidth,page.layer.layerHeight
            if not nw or not nh or nw<=0 or nh<=0 then HideRegionHover();return end
            -- Blizzard's highlight sizes and scroll offsets are normally map
            -- fractions. Accept native-pixel values on other Forever clients.
            local sx=sizeX<=1 and sizeX*nw or sizeX
            local sy=sizeY<=1 and sizeY*nh or sizeY
            local ox=abs(originX)<=1 and originX*nw or originX
            local oy=abs(originY)<=1 and originY*nh or originY
            if sx<1 or sy<1 or sx>nw*2 or sy>nh*2 then
                HideRegionHover();return
            end
            local key=tostring(fileID)..'/'..tostring(atlasID)..'/'..tostring(pctX)..'/'..tostring(pctY)
            if highlightKey~=key then
                local applied=false
                if type(fileID)=='number' and fileID>0 then
                    local good=pcall(regionHighlight.SetTexture,regionHighlight,fileID)
                    if good then
                        regionHighlight:SetTexCoord(0,max(.001,min(1,tonumber(pctX) or 1)),
                            0,max(.001,min(1,tonumber(pctY) or 1)))
                        applied=true
                    end
                elseif type(atlasID)=='string' and atlasID~='' and regionHighlight.SetAtlas then
                    local good,result=pcall(regionHighlight.SetAtlas,regionHighlight,atlasID)
                    applied=good and result~=false
                end
                if not applied then HideRegionHover();page.hoverStatus='unsupported art';return end
                highlightKey=key
            end
            regionHighlight:ClearAllPoints()
            regionHighlight:SetPoint('TOPLEFT',mapCanvas,'TOPLEFT',ox/nw*w,-oy/nh*h)
            regionHighlight:SetSize(sx/nw*w,sy/nh*h)
            regionHighlight:Show()
            page.hoverStatus='native additive highlight'
        end
        -- Native quest-area blobs render the exact shape computed by the client.
        -- This is an optional, non-interactive child of the map canvas; if the
        -- Forever client rejects the widget or quest blob method, disable it
        -- without affecting pins, quest popups, or terrain.
        local questBlob=nil
        local questBlobID=nil
        local questBlobWidth,questBlobHeight=nil,nil
        local questBlobStatus='unavailable'
        local blobOk,createdBlob=pcall(CreateFrame,'QuestPOIFrame',nil,mapCanvas)
        if blobOk and createdBlob and type(createdBlob.DrawBlob)=='function'
            and type(createdBlob.SetMapID)=='function' then
            questBlob=createdBlob
            questBlob:EnableMouse(false)
            questBlob:ClearAllPoints()
            questBlob:SetPoint('TOPLEFT',mapCanvas,'TOPLEFT',0,0)
            questBlob:SetSize(mapCanvas:GetWidth(),mapCanvas:GetHeight())
            pcall(questBlob.SetFillTexture,questBlob,'Interface\\WorldMap\\UI-QuestBlob-Inside')
            pcall(questBlob.SetBorderTexture,questBlob,'Interface\\WorldMap\\UI-QuestBlob-Outside')
            if questBlob.SetFillAlpha then pcall(questBlob.SetFillAlpha,questBlob,128) end
            if questBlob.SetBorderAlpha then pcall(questBlob.SetBorderAlpha,questBlob,192) end
            if questBlob.SetBorderScalar then pcall(questBlob.SetBorderScalar,questBlob,1) end
            questBlob:Hide()
            questBlobStatus='ready'
        end
        page.questBlobStatus=function() return questBlobStatus end
        local function HideQuestArea()
            if not questBlob then return end
            pcall(questBlob.DrawNone,questBlob)
            questBlobID=nil
            questBlob:Hide()
        end
        local function PositionQuestArea()
            if not questBlob then return end
            local bw,bh=mapCanvas:GetWidth(),mapCanvas:GetHeight()
            if questBlobWidth==bw and questBlobHeight==bh then return end
            questBlobWidth,questBlobHeight=bw,bh
            questBlob:SetSize(bw,bh)
            if questBlobID then
                local ok=pcall(questBlob.DrawNone,questBlob)
                if ok then ok=pcall(questBlob.DrawBlob,questBlob,questBlobID,true) end
                if not ok then
                    questBlobStatus='native blob call failed'
                    HideQuestArea()
                end
            end
        end
        local function ShowQuestArea(q)
            HideQuestArea()
            if not DebugOn('blob') or not questBlob or not q or not q.questID or q.isQuestStart then return end
            if not page.mapID then return end
            local ok=pcall(questBlob.SetMapID,questBlob,page.mapID)
            if ok then ok=pcall(questBlob.DrawBlob,questBlob,q.questID,true) end
            if ok then
                questBlobID=q.questID
                questBlobStatus='native blob requested'
                questBlob:Show()
            else
                questBlobStatus='native quest blob unavailable for this quest/map'
                HideQuestArea()
            end
        end

        -- Capital city pins are derived from the client's actual map IDs and
        -- coordinate transforms, not hard-coded continent percentages. Classic
        -- and Forever can use different UiMapIDs for the same city.
        local capitals={
            {'Stormwind City',84,1453}, {'Ironforge',87,1455},
            {'Darnassus',89,1457}, {'Orgrimmar',85,1454},
            {'Thunder Bluff',88,1456}, {'Undercity',90,1458},
        }
        local function CapitalPos(childID,parentID)
            if C_Map and type(C_Map.GetMapRectOnMap)=='function' then
                local ok,l,r,t,b=pcall(C_Map.GetMapRectOnMap,childID,parentID)
                if ok and type(l)=='number' and type(r)=='number'
                    and type(t)=='number' and type(b)=='number'
                    and r>l and b>t and l>=0 and r<=1 and t>=0 and b<=1 then
                    return (l+r)*.5,(t+b)*.5
                end
            end
            if C_Map and type(C_Map.GetWorldPosFromMapPos)=='function'
                and type(C_Map.GetMapPosFromWorldPos)=='function'
                and type(CreateVector2D)=='function' then
                local ok,continent,world=pcall(C_Map.GetWorldPosFromMapPos,childID,CreateVector2D(.5,.5))
                if ok and type(continent)=='number' and world then
                    local good,_,pos=pcall(C_Map.GetMapPosFromWorldPos,continent,world,parentID)
                    if good and pos and type(pos.GetXY)=='function' then
                        local yes,x,y=pcall(pos.GetXY,pos)
                        if yes and type(x)=='number' and type(y)=='number'
                            and x>=0 and x<=1 and y>=0 and y<=1 then return x,y end
                    end
                end
            end
        end
        local function PinTooltip(frame,title,body)
            if not GameTooltip or not GameTooltip.SetOwner then return end
            GameTooltip:SetOwner(frame,'ANCHOR_RIGHT')
            GameTooltip:SetText(title or 'Unknown location',1,.82,.42)
            if body and body~='' then GameTooltip:AddLine(body,1,1,1,true) end
            GameTooltip:Show()
        end
        local function HideTooltip()
            if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
        end
        local function MakeCapital(index)
            local b=CreateFrame('Button',nil,mapCanvas)
            b:SetSize(24,24)
            b:RegisterForClicks('LeftButtonUp')
            -- The gold circular badge is deliberately independent of unknown
            -- client-specific atlas names; it works on every Forever build.
            local bg=b:CreateTexture(nil,'ARTWORK')
            bg:SetPoint('CENTER',b,'CENTER');bg:SetSize(22,22)
            bg:SetTexture('Interface\\AddOns\\AzerothFoundry\\Media\\CapitalCity')
            b:SetScript('OnEnter',function(self)
                if self.afCity then PinTooltip(self,self.afCity.name,'Click to open the city map') end
            end)
            b:SetScript('OnLeave',HideTooltip)
            b:SetScript('OnClick',function(self)
                if self.afCity then page:Navigate(self.afCity.mapID) end
            end)
            capitalPins[index]=b
            return b
        end
        local function RefreshCapitals()
            for _,b in ipairs(capitalPins) do b:Hide() end
            for i=#capitalData,1,-1 do capitalData[i]=nil end
            local info=AF:GetAtlasMapInfo(page.mapID)
            if not DebugOn('capitals') or not info or tonumber(info.mapType)~=2 then return end
            for _,choices in ipairs(capitals) do
                local name=choices[1]
                local foundID=nil
                for i=2,#choices do
                    local ci=AF:GetAtlasMapInfo(choices[i])
                    if ci and ci.name and (ci.name:lower()==name:lower()
                        or name=='Stormwind City' and ci.name:lower()=='stormwind')
                        and AF:IsAtlasMapDescendant(choices[i],page.mapID) then
                        foundID=choices[i];break
                    end
                end
                if foundID then
                    local x,y=CapitalPos(foundID,page.mapID)
                    if x and y then
                        local n=#capitalData+1
                        capitalData[n]={name=name,mapID=foundID,x=x,y=y}
                        local b=capitalPins[n] or MakeCapital(n)
                        b.afCity=capitalData[n]
                        b:Show()
                    end
                end
            end
        end
        local function QuestTitle(questID)
            if not questID then return 'Quest' end
            if C_QuestLog and type(C_QuestLog.GetTitleForQuestID)=='function' then
                local ok,title=pcall(C_QuestLog.GetTitleForQuestID,questID)
                if ok and type(title)=='string' and title~='' then return title end
            end
            if type(GetQuestLogIndexByID)=='function' and type(GetQuestLogTitle)=='function' then
                local ok,index=pcall(GetQuestLogIndexByID,questID)
                if ok and type(index)=='number' and index>0 then
                    local yes,title=pcall(GetQuestLogTitle,index)
                    if yes and type(title)=='string' then return title end
                end
            end
            return 'Quest #'..tostring(questID)
        end
        -- A self-contained journal panel; no Blizzard quest log is opened and
        -- no global quest-log selection is modified. Descriptions are displayed
        -- only when the client actually supplies them for accepted quests.
        local questPanel=UI:Card(center,pal.parchmentLight)
        questPanel:SetSize(373,332)
        questPanel:SetPoint('TOPRIGHT',viewport,'TOPRIGHT',-14,-15)
        questPanel:SetFrameLevel(center:GetFrameLevel()+45)
        questPanel:EnableMouse(true)
        questPanel:Hide()
        page.questDetailPopup=questPanel
        local questHeader=UI:SectionTitle(questPanel,'Quest Details')
        questHeader:SetPoint('TOPLEFT',questPanel,'TOPLEFT',13,-10)
        questHeader:SetPoint('TOPRIGHT',questPanel,'TOPRIGHT',-85,-10)
        local closeQuest=UI:Button(questPanel,'Close',function() questPanel:Hide() end)
        closeQuest:SetSize(65,23)
        closeQuest:SetPoint('TOPRIGHT',questPanel,'TOPRIGHT',-12,-7)
        local questName=UI:Text(questPanel,'normal',pal.ink,'LEFT')
        questName:SetPoint('TOPLEFT',questPanel,'TOPLEFT',16,-45)
        questName:SetPoint('TOPRIGHT',questPanel,'TOPRIGHT',-16,-45)
        questName:SetHeight(38)
        questName:SetJustifyV('TOP')
        local questMeta=UI:Text(questPanel,'small',pal.ink,'LEFT')
        questMeta:SetPoint('TOPLEFT',questName,'BOTTOMLEFT',0,-2)
        questMeta:SetPoint('TOPRIGHT',questName,'BOTTOMRIGHT',0,-2)
        questMeta:SetHeight(24)
        local questScroll=CreateFrame('ScrollFrame',nil,questPanel)
        questScroll:SetPoint('TOPLEFT',questMeta,'BOTTOMLEFT',0,-7)
        questScroll:SetPoint('BOTTOMRIGHT',questPanel,'BOTTOMRIGHT',-37,15)
        if questScroll.SetClipsChildren then questScroll:SetClipsChildren(true) end
        questScroll:EnableMouseWheel(true)
        local questContent=CreateFrame('Frame',nil,questScroll)
        questContent:SetSize(318,1200)
        questScroll:SetScrollChild(questContent)
        local questBody=UI:Text(questContent,'small',pal.ink,'LEFT')
        questBody:SetPoint('TOPLEFT',questContent,'TOPLEFT',1,-3)
        questBody:SetPoint('TOPRIGHT',questContent,'TOPRIGHT',-7,-3)
        questBody:SetJustifyV('TOP')
        questBody:SetHeight(1100)
        questScroll:SetScript('OnMouseWheel',function(self,delta)
            local limit=self:GetVerticalScrollRange() or 0
            self:SetVerticalScroll(max(0,min(limit,(self:GetVerticalScroll() or 0)-delta*38)))
        end)
        -- On remote desktop, wheel events may not reach WoW. These always work.
        local scrollUp=UI:Button(questPanel,'^',function()
            questScroll:SetVerticalScroll(max(0,(questScroll:GetVerticalScroll() or 0)-70))
        end)
        scrollUp:SetSize(22,24)
        scrollUp:SetPoint('TOPRIGHT',questPanel,'TOPRIGHT',-12,-119)
        local scrollDown=UI:Button(questPanel,'v',function()
            questScroll:SetVerticalScroll(min(questScroll:GetVerticalScrollRange() or 0,
                (questScroll:GetVerticalScroll() or 0)+70))
        end)
        scrollDown:SetSize(22,24)
        scrollDown:SetPoint('BOTTOMRIGHT',questPanel,'BOTTOMRIGHT',-12,16)
        local function QuestIndex(id)
            if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID)=='function' then
                local ok,i=pcall(C_QuestLog.GetLogIndexForQuestID,id)
                if ok and tonumber(i) and i>0 then return i end
            end
            if type(GetQuestLogIndexByID)=='function' then
                local ok,i=pcall(GetQuestLogIndexByID,id)
                if ok and tonumber(i) and i>0 then return i end
            end
        end
        local function QuestObjectives(id)
            if id and C_QuestLog and type(C_QuestLog.GetQuestObjectives)=='function' then
                local ok,objectives=pcall(C_QuestLog.GetQuestObjectives,id)
                if ok and type(objectives)=='table' then return objectives end
            end
            return {}
        end
        local function ShowQuestPanel(q)
            if not q or not q.questID then return end
            local id=q.questID
            questName:SetText(QuestTitle(id))
            local zone=AF:GetAtlasMapInfo(page.mapID)
            local meta={zone and zone.name or 'Unknown region', 'Quest #'..tostring(id)}
            if C_QuestLog and type(C_QuestLog.GetQuestDifficultyLevel)=='function' then
                local ok,lvl=pcall(C_QuestLog.GetQuestDifficultyLevel,id)
                if ok and type(lvl)=='number' and lvl>0 then meta[#meta+1]='Level '..lvl end
            end
            questMeta:SetText(table.concat(meta,'  |  '))
            local lines={}
            lines[#lines+1]=q.isQuestStart and 'AVAILABLE QUEST' or
                (q.isComplete and 'READY TO TURN IN' or 'QUEST OBJECTIVES')
            local index=QuestIndex(id)
            local description,objectiveText
            if index and type(GetQuestLogQuestText)=='function' then
                local ok,d,o=pcall(GetQuestLogQuestText,index)
                if ok then description,objectiveText=d,o end
            end
            if type(objectiveText)=='string' and objectiveText~='' then
                lines[#lines+1]='\nObjectives\n'..objectiveText
            end
            local objectives=QuestObjectives(id)
            if #objectives>0 then
                lines[#lines+1]='\nProgress'
                for i=1,min(15,#objectives) do
                    local o=objectives[i]
                    if o and type(o.text)=='string' and o.text~='' then
                        local status=o.finished and '[Done] ' or '[ ] '
                        local counts=''
                        if type(o.numFulfilled)=='number' and type(o.numRequired)=='number' and o.numRequired>0 then
                            counts=' ('..o.numFulfilled..'/'..o.numRequired..')'
                        end
                        lines[#lines+1]=status..o.text..counts
                    end
                end
            end
            if type(description)=='string' and description~='' then
                lines[#lines+1]='\nQuest Story\n'..description
            elseif not index then
                lines[#lines+1]='\nFull quest dialogue is not available from the active quest log for this quest. Accept it to view any story text supplied by the client.'
            end
            if #lines==1 then lines[#lines+1]='\nNo additional quest details supplied by the client.' end
            questBody:SetText(table.concat(lines,'\n'))
            -- Font string height can be invalid during the first show; leave
            -- enough scroll content even if the client has not laid out text.
            local contentHeight=math.max(220, (questBody.GetStringHeight and questBody:GetStringHeight() or 0)+30)
            questBody:SetHeight(contentHeight)
            questContent:SetHeight(contentHeight+12)
            questScroll:SetVerticalScroll(0)
            questPanel:Show()
        end
        local function QuestTooltip(b)
            local q=b.afQuest
            if not q then return end
            PinTooltip(b,QuestTitle(q.questID),nil)
            if not GameTooltip then return end
            GameTooltip:AddLine(q.isQuestStart and 'Available quest' or
                (q.isComplete and 'Ready to turn in' or 'Quest objective'),1,.84,.4)
            for i,o in ipairs(QuestObjectives(q.questID)) do
                if i>4 then break end
                if o and o.text and o.text~='' then
                    GameTooltip:AddLine(o.text,o.finished and .5 or 1,o.finished and .8 or .95,.52,true)
                end
            end
            GameTooltip:AddLine('Click for Azeroth Foundry quest details',.7,.7,.7)
            GameTooltip:Show()
        end
        local function MakeQuestPin(index)
            local b=CreateFrame('Button',nil,mapCanvas)
            b:SetSize(27,27)
            b:RegisterForClicks('LeftButtonUp')
            local icon=b:CreateTexture(nil,'ARTWORK')
            icon:SetPoint('CENTER',b,'CENTER');icon:SetSize(24,24)
            b.icon=icon
            local glow=b:CreateTexture(nil,'OVERLAY')
            glow:SetPoint('CENTER',b,'CENTER');glow:SetSize(23,23)
            glow:SetTexture('Interface\\Buttons\\UI-ActionButton-Border')
            glow:SetBlendMode('ADD');glow:SetVertexColor(1,.75,.18,.35)
            glow:Hide();b.glow=glow
            b:SetScript('OnEnter',function(self)
                self.glow:Show()
                ShowQuestArea(self.afQuest)
                QuestTooltip(self)
            end)
            b:SetScript('OnLeave',function(self)
                self.glow:Hide()
                HideQuestArea()
                HideTooltip()
            end)
            b:SetScript('OnClick',function(self)
                if self.afQuest and self.afQuest.questID then ShowQuestPanel(self.afQuest) end
            end)
            questTiles[index]=b
            return b
        end
        local function RepositionOverlays()
            if not page.layer then return end
            local nw,nh=page.layer.layerWidth,page.layer.layerHeight
            local w,h=mapCanvas:GetWidth(),mapCanvas:GetHeight()
            if not nw or not nh or nw==0 or nh==0 then return end
            for _,tile in ipairs(exploredTiles) do
                if tile:IsShown() and tile.afOverlay then
                    local p=tile.afOverlay
                    tile:ClearAllPoints()
                    local d=page.afMapDebug and page.afMapDebug.adjust.exploration
                    local sx,sy=d and d.sx or 1,d and d.sy or 1
                    local dx,dy=d and d.x or 0,d and d.y or 0
                    tile:SetPoint('TOPLEFT',mapCanvas,'TOPLEFT',((p.x/nw-.5)*sx+.5)*w+dx,-(((p.y/nh-.5)*sy+.5)*h+dy))
                    tile:SetSize(p.w/nw*w*sx,p.h/nh*h*sy)
                end
            end
            for i,tile in ipairs(questTiles) do
                local q=questData[i]
                if tile:IsShown() and q then
                    tile:ClearAllPoints()
                    tile:SetPoint('CENTER',mapCanvas,'TOPLEFT',w*q.x,-h*q.y)
                end
            end
            for i,b in ipairs(capitalPins) do
                local c=capitalData[i]
                if b:IsShown() and c then
                    b:ClearAllPoints()
                    b:SetPoint('CENTER',mapCanvas,'TOPLEFT',w*c.x,-h*c.y)
                end
            end
            PositionDetail()
            if questBlob then PositionQuestArea() end
            UpdateArrow()
            UpdateRegionHighlight()
        end
        -- Partial exploration textures use power-of-two storage dimensions.
        -- Full tiles keep their original 256px UV range; edge pieces must be
        -- sampled against their own storage dimensions instead of 256px.
        local function ExplorationStorageSize(n)
            local size=1
            while size<n do size=size*2 end
            return size
        end
        local function RefreshOverlays()
            HideQuestArea()
            for _,tile in ipairs(exploredTiles) do tile:Hide() end
            for _,tile in ipairs(questTiles) do tile:Hide() end
            for i=#questData,1,-1 do questData[i]=nil end
            if not page.layer or not page.mapID then return end
            RefreshCapitals()
            local settings=Opts()
            -- Counters are nonpersistent and only used by the debug panel.
            page.debugExplorationStats={pieces=0,edgePieces=0,groups=0,invalidGroups=0}
            local explorationStats=page.debugExplorationStats
            if settings.showExploration and DebugOn('exploration') and C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures then
                local scope=AF.db and AF.db.settings.atlas.scope or 'character'
                local ok,overlays=pcall(AF.GetAtlasExplorationOverlays,AF,page.mapID,scope)
                if ok and type(overlays)=='table' then
                    local count=0
                    for _,p in ipairs(overlays) do
                        local tw,th=tonumber(p.textureWidth),tonumber(p.textureHeight)
                        local ox,oy=tonumber(p.offsetX),tonumber(p.offsetY)
                        local ids=p.fileDataIDs
                        if tw and th and ox and oy and tw>0 and th>0 and type(ids)=='table' then
                            explorationStats.groups=explorationStats.groups+1
                            local cols=ceil(tw/page.layer.tileWidth)
                            local rows=ceil(th/page.layer.tileHeight)
                            for j=1,min(#ids,cols*rows) do
                                if count>=250 then break end
                                local file=ids[j]
                                local col=(j-1)%cols
                                local row=math.floor((j-1)/cols)
                                local cw=min(page.layer.tileWidth,tw-col*page.layer.tileWidth)
                                local ch=min(page.layer.tileHeight,th-row*page.layer.tileHeight)
                                if file and cw>0 and ch>0 then
                                    count=count+1
                                    local texture=exploredTiles[count]
                                    if not texture then
                                        texture=mapCanvas:CreateTexture(nil,'ARTWORK',nil,3)
                                        exploredTiles[count]=texture
                                    end
                                    texture:SetTexture(file)
                                    -- Exploration edge pieces can be stored in a smaller
                                    -- power-of-two texture (e.g. 28px content in a 32px file).
                                    -- Using the parent map tile width (256) as the UV
                                    -- denominator magnifies just 3.5 pixels into 28 pixels,
                                    -- producing repeated vertical bands at overlay edges.
                                    -- Keep a live legacy switch for side-by-side confirmation.
                                    local d=page.afMapDebug
                                    local legacy=d and d.legacyExplorationUV
                                    local uvw=legacy and page.layer.tileWidth or ExplorationStorageSize(cw)
                                    local uvh=legacy and page.layer.tileHeight or ExplorationStorageSize(ch)
                                    explorationStats.pieces=explorationStats.pieces+1
                                    if cw<page.layer.tileWidth or ch<page.layer.tileHeight then
                                        explorationStats.edgePieces=explorationStats.edgePieces+1
                                    end
                                    texture:SetTexCoord(0,cw/uvw,0,ch/uvh)
                                    texture.afOverlay={x=ox+col*page.layer.tileWidth,y=oy+row*page.layer.tileHeight,w=cw,h=ch,file=file,
                                        uvw=uvw,uvh=uvh,texRight=cw/uvw,texBottom=ch/uvh,
                                        groupOffsetX=ox,groupOffsetY=oy,groupWidth=tw,groupHeight=th,index=j}
                                    texture:Show()
                                end
                            end
                        else
                            explorationStats.invalidGroups=explorationStats.invalidGroups+1
                        end
                        if count>=250 then break end
                    end
                end
            end
            if settings.showQuestPins and DebugOn('quests') and C_QuestLog and C_QuestLog.GetQuestsOnMap then
                local ok,quests=pcall(C_QuestLog.GetQuestsOnMap,page.mapID)
                if ok and type(quests)=='table' then
                    for _,q in ipairs(quests) do
                        local x,y=tonumber(q.x),tonumber(q.y)
                        if (not x or not y) and type(q.position)=='table' then
                            x,y=tonumber(q.position.x),tonumber(q.position.y)
                        end
                        if x and y and x>=0 and x<=1 and y>=0 and y<=1 and #questData<90 then
                            local i=#questData+1
                            local complete=false
                            if q.questID and C_QuestLog and type(C_QuestLog.IsComplete)=='function' then
                                local yes,value=pcall(C_QuestLog.IsComplete,q.questID)
                                complete=yes and value==true
                            end
                            questData[i]={x=x,y=y,questID=q.questID,isQuestStart=q.isQuestStart,
                                isComplete=complete}
                            local pin=questTiles[i] or MakeQuestPin(i)
                            pin.afQuest=questData[i]
                            pin.icon:SetTexture('Interface\\AddOns\\AzerothFoundry\\Media\\'
                                ..(q.isQuestStart and 'QuestAvailable'
                                    or complete and 'QuestComplete' or 'QuestObjective'))
                            pin:Show()
                        end
                    end
                end
            end
            RepositionOverlays()
        end
        page.RepositionTiles=function(self)
            basePosition(self)
            Safely('overlay positioning',RepositionOverlays)
        end
        page.RenderMap=function(self)
            baseRender(self)
            HideRegionHover()
            HideQuestArea()
            if page.questDetailPopup then page.questDetailPopup:Hide() end
            Safely('map detail artwork',LoadDetail)
            Safely('map overlay rendering',RefreshOverlays)
        end
        page.RefreshLayers=function(self)
            Safely('map layer refresh',RefreshOverlays)
        end
        page.DebugRefreshArtwork=function()
            Safely('debug exploration positioning',RepositionOverlays)
            Safely('debug detail positioning',PositionDetail)
            if not DebugOn('blob') then HideQuestArea() end
            if not DebugOn('arrow') then playerArrow:Hide() end
            if not DebugOn('highlight') then HideRegionHover() end
        end
        -- Layer switches are intentionally built after the base map is usable.
        local fogToggle,questToggle
        -- Both switches use the same full-button grayscale OFF state.
        local function StyleMapSwitch(button,isOn,caption)
            button.label:SetText(caption..(isOn and ': ON' or ': OFF'))
            local tint=isOn and 1 or .38
            for _,slice in ipairs(button.normalSlices or {}) do
                slice:SetVertexColor(tint,tint,tint)
            end
            for _,slice in ipairs(button.pressedSlices or {}) do
                slice:SetVertexColor(tint,tint,tint)
            end
            local tokens=UI.ThemeTokens and UI:ThemeTokens()
            if tokens then
                local text=tokens.buttonText
                button.label:SetTextColor(text[1],text[2],text[3],isOn and 1 or .82)
                if UI.ApplyThemeButton then UI:ApplyThemeButton(button,tokens) end
            else
                button.label:SetTextColor(isOn and 1 or .66,isOn and .87 or .66,isOn and .58 or .66)
            end
            if button.selectedTexture then button.selectedTexture:Hide() end
        end
        local function ApplySwitches()
            local st=Opts()
            StyleMapSwitch(fogToggle,st.showExploration,'Explore')
            StyleMapSwitch(questToggle,st.showQuestPins,'Quests')
        end
        fogToggle=self:Button(center,'Explore: ON',function()
            local st=Opts();st.showExploration=not st.showExploration
            page:RefreshLayers();ApplySwitches()
        end)
        fogToggle:SetSize(101,25);fogToggle:SetPoint('LEFT',home,'RIGHT',7,0)
        questToggle=self:Button(center,'Quests: ON',function()
            local st=Opts();st.showQuestPins=not st.showQuestPins
            page:RefreshLayers();ApplySwitches()
        end)
        questToggle:SetSize(92,25);questToggle:SetPoint('LEFT',fogToggle,'RIGHT',5,0)
        mapName:ClearAllPoints()
        mapName:SetPoint('LEFT',questToggle,'RIGHT',6,0)
        mapName:SetPoint('RIGHT',world,'LEFT',-7,0)
        mapName:SetHeight(27)
        local st=Opts()
        ApplySwitches()
        -- Slider is optional. Failure creating it must not break the atlas.
        local function InstallSlider()
            mapHint:ClearAllPoints()
            mapHint:SetPoint('TOPLEFT',viewport,'BOTTOMLEFT',0,-4)
            mapHint:SetPoint('TOPRIGHT',viewport,'BOTTOMRIGHT',-248,-4)
            local text=self:Text(center,'small',pal.ink,'RIGHT')
            text:SetPoint('TOPRIGHT',viewport,'BOTTOMRIGHT',-153,-6)
            text:SetSize(90,19);text:SetText('Player icon')
            local slider=CreateFrame('Slider',nil,center)
            slider:SetSize(135,16)
            slider:SetPoint('TOPRIGHT',viewport,'BOTTOMRIGHT',-12,-6)
            slider:SetOrientation('HORIZONTAL')
            slider:SetMinMaxValues(10,44)
            slider:SetValueStep(1)
            local track=slider:CreateTexture(nil,'BACKGROUND')
            track:SetColorTexture(.37,.27,.15,.9)
            track:SetPoint('LEFT',slider,'LEFT',0,0)
            track:SetPoint('RIGHT',slider,'RIGHT',0,0)
            track:SetHeight(5)
            slider:SetThumbTexture('Interface\\Buttons\\UI-SliderBar-Button-Horizontal')
            local thumb=slider:GetThumbTexture()
            if thumb then thumb:SetSize(16,20) end
            slider:SetScript('OnValueChanged',function(_,value)
                local settings=Opts()
                settings.playerArrowSize=max(10,min(44,math.floor((tonumber(value) or 17)+.5)))
                ApplyArrowSize()
            end)
            slider:SetValue(Opts().playerArrowSize)
            page.arrowSlider=slider
        end
        Safely('player icon slider',InstallSlider)
        -- A map zoom slider is essential on remote-desktop systems where the
        -- mouse wheel isn't transmitted. It controls exactly the wheel zoom.
        local zoomSlider,zoomReadout
        local function ZoomLimit()
            local info=AF:GetAtlasMapInfo(page.mapID)
            return info and tonumber(info.mapType)==3 and 4.5 or 3
        end
        local function SyncZoomSlider()
            if not zoomSlider then return end
            zoomSlider:SetMinMaxValues(1,ZoomLimit())
            if abs((zoomSlider:GetValue() or 1)-page.zoom)>.001 then
                zoomSlider:SetValue(page.zoom)
            end
            if zoomReadout then zoomReadout:SetText(string.format('%.2fx',page.zoom)) end
        end
        function page:SetMapZoom(value)
            local requested=tonumber(value) or self.zoom or 1
            local snapped=math.floor(requested*4+.5)/4
            local updated=max(1,min(ZoomLimit(),snapped))
            if abs(updated-self.zoom)>.001 then
                self.zoom=updated
                self:RepositionTiles()
            else SyncZoomSlider() end
        end
        local function InstallZoomSlider()
            local zoomText=self:Text(center,'small',pal.ink,'LEFT')
            zoomText:SetPoint('TOPLEFT',viewport,'BOTTOMLEFT',6,-6)
            zoomText:SetSize(63,19)
            zoomText:SetText('Map zoom')
            local slider=CreateFrame('Slider',nil,center)
            slider:SetSize(125,16)
            slider:SetPoint('LEFT',zoomText,'RIGHT',5,0)
            slider:SetOrientation('HORIZONTAL')
            slider:SetMinMaxValues(1,ZoomLimit())
            slider:SetValueStep(.25)
            local track=slider:CreateTexture(nil,'BACKGROUND')
            track:SetColorTexture(.37,.27,.15,.9)
            track:SetPoint('LEFT',slider,'LEFT',0,0)
            track:SetPoint('RIGHT',slider,'RIGHT',0,0)
            track:SetHeight(5)
            slider:SetThumbTexture('Interface\\Buttons\\UI-SliderBar-Button-Horizontal')
            local thumb=slider:GetThumbTexture()
            if thumb then thumb:SetSize(16,20) end
            zoomReadout=self:Text(center,'small',pal.ink,'LEFT')
            zoomReadout:SetPoint('LEFT',slider,'RIGHT',6,0)
            zoomReadout:SetSize(46,19)
            slider:SetScript('OnValueChanged',function(_,value) page:SetMapZoom(value) end)
            zoomSlider=slider
            page.zoomSlider=slider
            -- Keep the hint short enough to sit between the two slider groups.
            mapHint:SetText('Click: enter  •  Drag: pan')
            mapHint:ClearAllPoints()
            mapHint:SetPoint('TOPLEFT',viewport,'BOTTOMLEFT',253,-4)
            mapHint:SetPoint('TOPRIGHT',viewport,'BOTTOMRIGHT',-248,-4)
            SyncZoomSlider()
        end
        Safely('map zoom slider',InstallZoomSlider)
        -- Both user input methods now share the same clamping and positioning.
        viewport:SetScript('OnMouseWheel',function(_,delta)
            page:SetMapZoom(page.zoom+(delta>0 and .25 or -.25))
        end)
        local positionWithExtras=page.RepositionTiles
        page.RepositionTiles=function(self)
            positionWithExtras(self)
            Safely('player arrow sizing',ApplyArrowSize)
            SyncZoomSlider()
        end
        local baseUpdate=viewport:GetScript('OnUpdate')
        local tick=0
        viewport:SetScript('OnUpdate',function(frame,elapsed)
            if baseUpdate then baseUpdate(frame,elapsed) end
            tick=tick+(elapsed or 0)
            highlightTick=highlightTick+(elapsed or 0)
            if tick>=.14 then
                tick=0
                Safely('live player arrow',UpdateArrow)
            end
            if highlightTick>=.10 then
                highlightTick=0
                Safely('native region hover',UpdateRegionHighlight)
            end
        end)
        viewport:HookScript('OnLeave',HideRegionHover)
        local watcher=CreateFrame('Frame',nil,page)
        for _,event in ipairs({'MAP_EXPLORATION_UPDATED','QUEST_LOG_UPDATE','QUEST_POI_UPDATE','ZONE_CHANGED_NEW_AREA'}) do
            pcall(watcher.RegisterEvent,watcher,event)
        end
        watcher:SetScript('OnEvent',function()
            if page:IsShown() then page:RefreshLayers() end
        end)
        Safely('initial native map detail',LoadDetail)
        page:RefreshLayers()
        -- Attach terrain only after the base map and existing optional layers
        -- have completed setup. Its errors cannot block the rest of the addon.
        if AF.AtlasTerrain and AF.AtlasTerrain.Attach then
            Safely('optional minimap terrain',function()
                AF.AtlasTerrain:Attach(page,viewport,mapCanvas,right,UI,pal)
                -- Quest/record sidebar already reserves the terrain controls.
            end)
            local originalReposition=page.RepositionTiles
            page.RepositionTiles=function(self)
                originalReposition(self)
                if self.RefreshTerrain then Safely('terrain reposition',self.RefreshTerrain,self) end
            end
            local originalRender=page.RenderMap
            page.RenderMap=function(self)
                originalRender(self)
                if self.RefreshTerrain then Safely('terrain map switch',self.RefreshTerrain,self,true) end
            end
        end
        -- Temporary diagnostic UI is independent of the ordinary atlas and
        -- never prevents map loading if a particular client API is absent.
        if AF.AtlasDebug and AF.AtlasDebug.Attach then
            Safely('temporary map debugging',function()
                AF.AtlasDebug:Attach(page,viewport,mapCanvas,right,UI,pal)
            end)
        end
    end
    -- Build is already fully successful. Even a client-specific slider error
    -- cannot prevent the minimap button, welcome message, or core map.
    Safely('optional Atlas setup',SetupExtras)
end
