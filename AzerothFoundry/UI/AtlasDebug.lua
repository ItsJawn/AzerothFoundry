-- Azeroth Foundry 0.4.0.15: temporary in-game Map Debug Updater.
-- This file deliberately does not touch SavedVariables; Reset restores the
-- map appearance that existed when the debugging panel was attached.
local _, AF = ...
local Debug = {}
AF.AtlasDebug = Debug
local min,max,abs,floor=math.min,math.max,math.abs,math.floor
local unpack=unpack or table.unpack

local layerInfo={
    {'base','Base illustrated map'},
    {'exploration','Explored artwork (roads / towns)'},
    {'detail','High-res illustrated layer'},
    {'forceDetail','Force high-res over terrain'},
    {'terrain','Minimap terrain'},
    {'mask','Terrain masks (fog clipping)'},
    {'highlight','Blue region highlight'},
    {'blob','Quest-area blob'},
    {'quests','Quest markers'},
    {'capitals','Capital markers'},
    {'arrow','Player arrow'},
}
local function Coordinates(x,y)
    return string.format('%.4f / %.4f',x or 0,y or 0)
end
local function Cursor()
    if not GetCursorPosition then return end
    local x,y=GetCursorPosition()
    local scale=UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    return x/scale,y/scale
end
local function Txt(parent,text,size,r,g,b)
    local t=parent:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
    if t.SetFontObject then t:SetFontObject(size=='large' and 'GameFontNormal' or 'GameFontNormalSmall') end
    t:SetTextColor(r or 1,g or .87,b or .64)
    t:SetJustifyH('LEFT');t:SetJustifyV('TOP');t:SetText(text or '')
    return t
end
local function Pretty(n)
    if type(n)=='number' then return string.format('%.3f',n) end
    return tostring(n or '?')
end
local function RectContains(r,x,y)
    return r and x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h
end
local function AdjustRect(rect,a,cw,ch)
    local sx,sy=a.sx,a.sy
    return {x=(rect.x-.5)*sx+.5+a.x/cw,y=(rect.y-.5)*sy+.5+a.y/ch,
        w=rect.w*sx,h=rect.h*sy}
end

function Debug:Attach(page,viewport,canvas,right,UI,palette)
    local d={flags={},adjust={},target='exploration',tab='layers',unmasked=false,legacyExplorationUV=false,
        outline=false,hoverInspect=true,frozen=false,selection=nil,initialTerrain=AF.db.settings.atlas.terrainEnabled}
    for _,item in ipairs(layerInfo) do d.flags[item[1]]=item[1]~='forceDetail' end
    for _,target in ipairs({'exploration','terrain','detail'}) do
        d.adjust[target]={x=0,y=0,sx=1,sy=1}
    end
    page.afMapDebug=d
    local panel=CreateFrame('Frame','AzerothFoundryMapDebugger',UIParent)
    -- Keep the controls above even FULLSCREEN journal frames and map highlights.
    panel:SetFrameStrata('TOOLTIP');panel:SetFrameLevel(150)
    if panel.SetToplevel then panel:SetToplevel(true) end
    if panel.SetScale then panel:SetScale(1) end
    local screenH=(UIParent and UIParent:GetHeight()) or 768
    panel:SetSize(428,max(460,min(610,screenH-80)))
    panel:SetPoint('CENTER',UIParent,'CENTER',0,0)
    if panel.SetClampedToScreen then panel:SetClampedToScreen(true) end
    panel:SetMovable(true);panel:EnableMouse(true)
    panel:RegisterForDrag('LeftButton')
    panel:SetScript('OnDragStart',function(self) self:StartMoving() end)
    panel:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
    local background=panel:CreateTexture(nil,'BACKGROUND')
    background:SetAllPoints(panel)
    background:SetColorTexture(.075,.062,.052,.98)
    local topEdge=panel:CreateTexture(nil,'BORDER')
    topEdge:SetColorTexture(.71,.51,.24,.98)
    topEdge:SetHeight(3)
    topEdge:SetPoint('TOPLEFT',panel,'TOPLEFT',0,0)
    topEdge:SetPoint('TOPRIGHT',panel,'TOPRIGHT',0,0)
    local bottomEdge=panel:CreateTexture(nil,'BORDER')
    bottomEdge:SetColorTexture(.71,.51,.24,.98)
    bottomEdge:SetHeight(3)
    bottomEdge:SetPoint('BOTTOMLEFT',panel,'BOTTOMLEFT',0,0)
    bottomEdge:SetPoint('BOTTOMRIGHT',panel,'BOTTOMRIGHT',0,0)
    local title=Txt(panel,'MAP DEBUG UPDATER  |  v0.4.0.18','large',1,.84,.48)
    title:SetPoint('TOPLEFT',panel,'TOPLEFT',14,-13)
    title:SetSize(325,22)
    local function Btn(parent,caption,w,h,anchor,...)
        local b=UI:Button(parent,caption,function() end)
        b:SetSize(w,h);b:SetPoint(anchor,...)
        return b
    end
    local close=Btn(panel,'X',29,24,'TOPRIGHT',panel,'TOPRIGHT',-9,-8)
    close:SetScript('OnClick',function() panel:Hide();page.DebugPickArmed=false end)
    local tabs={}
    local frames={}
    local function SelectTab(key)
        d.tab=key
        for name,f in pairs(frames) do
            if name==key then f:Show() else f:Hide() end
        end
        for name,b in pairs(tabs) do
            if UI.SetButtonSelected then UI:SetButtonSelected(b,name==key) end
        end
    end
    local captions={{'layers','Layers'},{'alignment','Alignment'},{'inspector','Tile Inspector'}}
    for i,t in ipairs(captions) do
        local b=Btn(panel,t[2],125,27,'TOPLEFT',panel,'TOPLEFT',13+(i-1)*134,-43)
        tabs[t[1]]=b
        b:SetScript('OnClick',function() SelectTab(t[1]) end)
        local content=CreateFrame('Frame',nil,panel)
        content:SetPoint('TOPLEFT',panel,'TOPLEFT',13,-83)
        content:SetPoint('BOTTOMRIGHT',panel,'BOTTOMRIGHT',-14,149)
        frames[t[1]]=content
    end
    local function Note(f,label,y,height)
        local t=Txt(f,label)
        t:SetPoint('TOPLEFT',f,'TOPLEFT',4,y)
        t:SetPoint('TOPRIGHT',f,'TOPRIGHT',-4,y)
        t:SetHeight(height or 18)
        return t
    end
    local function Action(label,callback,parent,x,y,w,h)
        local b=Btn(parent,label,w or 124,h or 25,'TOPLEFT',parent,'TOPLEFT',x,y)
        b:SetScript('OnClick',callback)
        return b
    end
    -- Keep all map controls out of SavedVariables except the existing terrain
    -- switch. The existing switch's original value is restored by Reset.
    local controls={}
    local function ControlTint(button,on)
        if button.label then button.label:SetTextColor(on and 1 or .55,on and .82 or .55,on and .45 or .55) end
        local tint=on and 1 or .42
        for _,part in ipairs(button.normalSlices or {}) do part:SetVertexColor(tint,tint,tint) end
    end
    local function ApplyBase()
        for i,t in ipairs(page.tiles or {}) do
            if i<=(page.baseTileCount or 0) and d.flags.base then t:Show() else t:Hide() end
        end
    end
    local function RefreshGeometry(refreshData)
        if refreshData and page.RefreshLayers then page:RefreshLayers() end
        if page.RepositionTiles then page:RepositionTiles() end
        if page.DebugRefreshArtwork then page:DebugRefreshArtwork() end
        if page.DebugTerrainModeChanged then page:DebugTerrainModeChanged(false)
        elseif page.RefreshTerrain then page:RefreshTerrain(true) end
        ApplyBase()
    end
    local function ApplyLayer(key,on)
        if key=='terrain' then
            AF.db.settings.atlas.terrainEnabled=on
        elseif key=='mask' then
            d.unmasked=not on
        else
            d.flags[key]=on
        end
        if key=='exploration' or key=='quests' or key=='capitals' or key=='blob' then
            RefreshGeometry(true)
        else
            RefreshGeometry(false)
        end
    end
    local function State(key)
        if key=='terrain' then return AF.db.settings.atlas.terrainEnabled==true end
        if key=='mask' then return not d.unmasked end
        return d.flags[key]~=false
    end
    local function RefreshControls()
        for key,b in pairs(controls) do
            local on=State(key)
            b.label:SetText((on and '[ON]  ' or '[OFF]  ')..(b.caption or key))
            ControlTint(b,on)
        end
    end
    local function RestoreDefaults()
        for _,item in ipairs(layerInfo) do d.flags[item[1]]=item[1]~='forceDetail' end
        for _,a in pairs(d.adjust) do a.x=0;a.y=0;a.sx=1;a.sy=1 end
        d.unmasked=false;d.legacyExplorationUV=false;d.frozen=false;d.selection=nil;d.outline=false;d.soloFile=nil
        page.DebugPickArmed=false;d.target='exploration'
        AF.db.settings.atlas.terrainEnabled=d.initialTerrain
        RefreshGeometry(true)
        RefreshControls()
        if d.RefreshInspectorButtons then d.RefreshInspectorButtons() end
        if page.DebugDrawTileEdges then page:DebugDrawTileEdges() end
    end

    local layers=frames.layers
    Note(layers,'Toggle one pass at a time. OFF is not permanent.',-2,18)
    for i,item in ipairs(layerInfo) do
        local y=-22-(i-1)*25
        local b=Action('',function()
            ApplyLayer(item[1],not State(item[1]));RefreshControls()
        end,layers,4,y,375,25)
        b.caption=item[2]
        controls[item[1]]=b
    end
    Note(layers,'Mask OFF exposes raw minimap tiles.\nForce hi-res overrides the usual fade rule.',-310,35)
    Action('Reset all',RestoreDefaults,layers,4,-348,137,26)
    Action('Inspector',function() SelectTab('inspector') end,layers,153,-348,137,26)
    -- Toggle the old cropping math for A/B testing at the same map coordinate.
    local uvBtn
    uvBtn=Action('Edge UV: FIX',function()
        d.legacyExplorationUV=not d.legacyExplorationUV
        uvBtn.label:SetText(d.legacyExplorationUV and 'Edge UV: OLD' or 'Edge UV: FIX')
        RefreshGeometry(true)
    end,layers,298,-348,99,26)


    local align=frames.alignment
    Note(align,'Move / scale the suspected layer independently.',-3)
    local targetButtons={}
    local alignTargets={{'exploration','Exploration'},{'terrain','Terrain'},{'detail','High-res art'}}
    for i,item in ipairs(alignTargets) do
        local b=Action(item[2],function()
            d.target=item[1]
            for _,slider in pairs(d.sliders or {}) do
                if slider.Sync then slider:Sync() end
            end
            for name,button in pairs(targetButtons) do ControlTint(button,name==d.target) end
        end,align,4+(i-1)*130,-27,122,27)
        targetButtons[item[1]]=b
    end
    d.sliders={}
    local defs={
        {'x','X offset (pixels)',-256,256,1},
        {'y','Y offset (pixels)',-256,256,1},
        {'sx','Width adjustment (%)',-40,40,1},
        {'sy','Height adjustment (%)',-40,40,1},
    }
    for i,info in ipairs(defs) do
        local key,label,lo,hi,step=unpack(info)
        local y=-75-(i-1)*62
        local caption=Note(align,label,y,19)
        local value=Txt(align,'0','small',1,.86,.58)
        value:SetPoint('TOPRIGHT',align,'TOPRIGHT',-7,y)
        value:SetSize(98,18);value:SetJustifyH('RIGHT')
        local slider=CreateFrame('Slider',nil,align)
        slider:SetOrientation('HORIZONTAL');slider:SetSize(341,16)
        slider:SetPoint('TOPLEFT',align,'TOPLEFT',20,y-22)
        slider:SetMinMaxValues(lo,hi);slider:SetValueStep(step)
        local line=slider:CreateTexture(nil,'BACKGROUND')
        line:SetColorTexture(.48,.38,.22,1)
        line:SetHeight(5);line:SetPoint('LEFT',slider,'LEFT');line:SetPoint('RIGHT',slider,'RIGHT')
        slider:SetThumbTexture('Interface\\Buttons\\UI-SliderBar-Button-Horizontal')
        if slider:GetThumbTexture() then slider:GetThumbTexture():SetSize(19,23) end
        slider.Sync=function(self)
            local cur=d.adjust[d.target][key]
            local v=(key=='sx' or key=='sy') and floor((cur-1)*100+.5) or cur
            self:SetValue(v)
            value:SetText(string.format('%+d%s',v,(key=='sx' or key=='sy') and '%%' or ' px'))
        end
        slider:SetScript('OnValueChanged',function(self,v)
            v=floor(v+.5)
            d.adjust[d.target][key]=(key=='sx' or key=='sy') and (1+v/100) or v
            value:SetText(string.format('%+d%s',v,(key=='sx' or key=='sy') and '%%' or ' px'))
            if page.RepositionTiles then page:RepositionTiles() end
            if page.DebugRefreshArtwork then page:DebugRefreshArtwork() end
            if page.DebugTerrainModeChanged then page:DebugTerrainModeChanged(false) end
            if page.DebugDrawTileEdges then page:DebugDrawTileEdges() end
        end)
        d.sliders[key]=slider
    end
    local function SyncAlign()
        for _,slider in pairs(d.sliders) do slider:Sync() end
        for name,button in pairs(targetButtons) do ControlTint(button,name==d.target) end
    end
    Action('Reset this layer',function()
        d.adjust[d.target]={x=0,y=0,sx=1,sy=1}
        SyncAlign();RefreshGeometry(false)
    end,align,4,-323,173,28)
    Action('Reset all debug',function() RestoreDefaults();SyncAlign() end,align,190,-323,174,28)
    Note(align,'Offsets accept negative / positive pixels; sizes range -40% to +40%. Zero and 0% are original rendering.',-360,35)

    -- World and image data for the tile under the cursor.
    local inspect=frames.inspector
    local InspectAt
    local inspectLine=Note(inspect,'Hover over the MAP for tile IDs and map coordinates.',-3,20)
    local readout=Note(inspect,'',-102,245)
    readout:SetTextColor(.94,.87,.70)
    local pick
    pick=Action('Click to pick: OFF',function()
        page.DebugPickArmed=not page.DebugPickArmed
        pick.label:SetText(page.DebugPickArmed and 'Click to pick: ON' or 'Click to pick: OFF')
    end,inspect,4,-28,183,28)
    local freeze
    freeze=Action('Freeze: OFF',function()
        d.frozen=not d.frozen
        if not d.frozen then d.selection=nil end
        freeze.label:SetText(d.frozen and 'Freeze: ON' or 'Freeze: OFF')
    end,inspect,196,-28,185,28)
    local outline
    outline=Action('Tile outlines: OFF',function()
        d.outline=not d.outline
        outline.label:SetText(d.outline and 'Tile outlines: ON' or 'Tile outlines: OFF')
        if page.DebugDrawTileEdges then page:DebugDrawTileEdges() end
    end,inspect,4,-64,183,28)
    Action('Capture cursor now',function()
        if page.DebugCaptureCursor then page:DebugCaptureCursor() end
    end,inspect,196,-64,185,28)
    Action('Inspect player tile',function()
        if not C_Map or not C_Map.GetPlayerMapPosition then return end
        local ok,pos=pcall(C_Map.GetPlayerMapPosition,page.mapID,'player')
        if ok and pos and pos.GetXY then
            local yes,x,y=pcall(pos.GetXY,pos)
            if yes and x and y and x>=0 and x<=1 and y>=0 and y<=1 then
                d.selection=InspectAt and InspectAt(x,y) or nil
                d.frozen=true
                freeze.label:SetText('Freeze: ON')
                if page.DebugUpdateInspector then page:DebugUpdateInspector(true) end
            else AF.Print('Player coordinates are not valid on this map.') end
        else AF.Print('Player coordinates are unavailable for this map.') end
    end,inspect,4,-350,183,26)
    local solo
    solo=Action('Solo explored tile: OFF',function()
        if d.soloFile then d.soloFile=nil
        elseif d.selection and d.selection.explorationFile then d.soloFile=d.selection.explorationFile
        else AF.Print('Hover an explored artwork tile and Capture cursor first.');return end
        if page.RefreshLayers then page:RefreshLayers() end
        solo.label:SetText(d.soloFile and 'Solo explored tile: ON' or 'Solo explored tile: OFF')
    end,inspect,196,-350,185,26)

    d.RefreshInspectorButtons=function()
        pick.label:SetText(page.DebugPickArmed and 'Click to pick: ON' or 'Click to pick: OFF')
        freeze.label:SetText(d.frozen and 'Freeze: ON' or 'Freeze: OFF')
        outline.label:SetText(d.outline and 'Tile outlines: ON' or 'Tile outlines: OFF')
        solo.label:SetText(d.soloFile and 'Solo explored tile: ON' or 'Solo explored tile: OFF')
    end

    -- Persistent screen bounds help the user copy exact texture identifiers
    -- without scrolling chat or writing them down from a screenshot.
    local reportTitle=Txt(panel,'Diagnostic capture (Ctrl+A / Ctrl+C)')
    reportTitle:SetPoint('BOTTOMLEFT',panel,'BOTTOMLEFT',14,112)
    reportTitle:SetSize(370,18)
    local reportBox=CreateFrame('EditBox',nil,panel)
    reportBox:SetMultiLine(true);reportBox:SetAutoFocus(false)
    reportBox:SetFontObject('ChatFontNormal')
    reportBox:SetTextColor(.96,.9,.72)
    reportBox:SetSize(389,78)
    reportBox:SetPoint('BOTTOMLEFT',panel,'BOTTOMLEFT',18,31)
    reportBox:SetText('Press Capture to collect map and tile data.')
    reportBox:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    local editBackground=panel:CreateTexture(nil,'BORDER')
    editBackground:SetPoint('TOPLEFT',reportBox,'TOPLEFT',-5,4)
    editBackground:SetPoint('BOTTOMRIGHT',reportBox,'BOTTOMRIGHT',5,-4)
    editBackground:SetColorTexture(.13,.12,.11,1)
    local function CursorNorm()
        local x,y=Cursor()
        local l,r,b,t=viewport:GetLeft(),viewport:GetRight(),viewport:GetBottom(),viewport:GetTop()
        if not x or not l or not r or not b or not t or x<l or x>r or y<b or y>t then return nil end
        local cl,ct=canvas:GetLeft(),canvas:GetTop()
        local cw,ch=canvas:GetWidth(),canvas:GetHeight()
        if not cl or not ct or not cw or not ch or cw<=0 or ch<=0 then return nil end
        local nx,ny=(x-cl)/cw,(ct-y)/ch
        if nx<0 or nx>1 or ny<0 or ny>1 then return nil end
        return nx,ny
    end
    InspectAt=function(nx,ny)
        if not nx or not page.layer then return nil end
        local layer=page.layer
        local w,h=layer.layerWidth,layer.layerHeight
        local cw,ch=canvas:GetWidth(),canvas:GetHeight()
        if not cw or not ch or cw<=0 or ch<=0 then return nil end
        local result={x=nx,y=ny,mapID=page.mapID,zoom=page.zoom,
            source='none',file='-',rect=nil,extra=''}
        -- Base art geometry is a deterministic grid; it stays diagnostic even
        -- if the base texture is temporarily hidden.
        local col=floor(nx*w/layer.tileWidth)
        local row=floor(ny*h/layer.tileHeight)
        local cols=math.ceil(w/layer.tileWidth)
        local index=row*cols+col+1
        local base=page.tiles[index]
        result.base=string.format('base #%d  r%d c%d  file=%s',index,row,col,
            tostring(base and base:GetTexture() or '?'))
        result.rect={x=col*layer.tileWidth/w,y=row*layer.tileHeight/h,
            w=min(layer.tileWidth,w-col*layer.tileWidth)/w,
            h=min(layer.tileHeight,h-row*layer.tileHeight)/h}
        result.file=base and base:GetTexture() or '?'
        result.source='base'
        -- Record ALL sources intersecting the sampled pixel, not just the top
        -- one. This helps identify duplicated art over otherwise valid roads.
        local hits={result.base}
        local preferred=nil
        local dExplore=d.adjust.exploration
        for _,tile in ipairs(page.exploredTiles or {}) do
            if tile:IsShown() and tile.afOverlay then
                local a=tile.afOverlay
                local rect=AdjustRect({x=a.x/w,y=a.y/h,w=a.w/w,h=a.h/h},dExplore,cw,ch)
                if RectContains(rect,nx,ny) then
                    local text=string.format('EXP file=%s piece=%d group=(%s,%s) size=%sx%s',
                        tostring(a.file),a.index or 0,Pretty(a.groupOffsetX),Pretty(a.groupOffsetY),
                        Pretty(a.groupWidth),Pretty(a.groupHeight))
                    text=text..string.format(' UV=%.4f,%.4f storage=%sx%s edge=%s',
                        a.texRight or 1,a.texBottom or 1,tostring(a.uvw or '?'),
                        tostring(a.uvh or '?'),tostring(a.w<(page.layer.tileWidth or 256) or a.h<(page.layer.tileHeight or 256)))
                    hits[#hits+1]=text
                    result.explorationFile=a.file
                    preferred={source='exploration',file=a.file,rect=rect,extra=text}
                end
            end
        end
        local data=page.debugTerrainPool
        for _,slot in ipairs(data or {}) do
            if slot.texture:IsShown() and slot.debugEntry then
                local e=slot.debugEntry
                local rect=AdjustRect(e.segment,d.adjust.terrain,cw,ch)
                if RectContains(rect,nx,ny) then
                    local text=string.format('TERRAIN file=%s grid=%s mask=%s',
                        tostring(e.tile.texture),tostring(e.tile.key),tostring(e.mask and e.mask.file or 'OFF'))
                    hits[#hits+1]=text
                    preferred={source='terrain',file=e.tile.texture,rect=rect,extra=text}
                end
            end
        end
        -- Optional high-res map art; image IDs remain visible even when alpha
        -- is faded to zero, so use that layer's actual visible opacity.
        local detail=page.debugDetailLayer
        if detail and page.detailTiles and detail.layerWidth and detail.tileWidth then
            local a=d.adjust.detail
            local ux=(nx-.5-a.x/cw)/a.sx+.5
            local uy=(ny-.5-a.y/ch)/a.sy+.5
            local dc=floor(ux*detail.layerWidth/detail.tileWidth)
            local dr=floor(uy*detail.layerHeight/detail.tileHeight)
            local count=math.ceil(detail.layerWidth/detail.tileWidth)
            local di=dr*count+dc+1
            local tex=page.detailTiles[di]
            if ux>=0 and ux<=1 and uy>=0 and uy<=1 and tex and tex:IsShown() and tex:GetAlpha()>.01 then
                local text=string.format('DETAIL #%d file=%s',di,tostring(tex:GetTexture()))
                hits[#hits+1]=text
                preferred={source='detail',file=tex:GetTexture(),rect=AdjustRect({
                    x=dc*detail.tileWidth/detail.layerWidth,
                    y=dr*detail.tileHeight/detail.layerHeight,
                    w=min(detail.tileWidth,detail.layerWidth-dc*detail.tileWidth)/detail.layerWidth,
                    h=min(detail.tileHeight,detail.layerHeight-dr*detail.tileHeight)/detail.layerHeight},a,cw,ch),extra=text}
            end
        end
        if preferred then
            result.source=preferred.source;result.file=preferred.file
            result.rect=preferred.rect;result.extra=preferred.extra
        end
        result.hits=hits
        local getPos=C_Map and C_Map.GetWorldPosFromMapPos
        if type(getPos)=='function' and type(CreateVector2D)=='function' then
            local ok,cont,p=pcall(getPos,page.mapID,CreateVector2D(nx,ny))
            if ok and p and p.GetXY then
                local yes,wx,wy=pcall(p.GetXY,p)
                if yes then result.world=string.format('%s / %s  (continent %s)',Pretty(wx),Pretty(wy),tostring(cont)) end
            end
        end
        return result
    end
    local borders={}
    local function CreateBorder()
        local b={}
        for k=1,4 do
            local tex=canvas:CreateTexture(nil,'OVERLAY')
            tex:SetColorTexture(1,.36,.06,.88)
            b[k]=tex
        end
        return b
    end
    local function Paint(b,r,rgb)
        local cw,ch=canvas:GetWidth(),canvas:GetHeight()
        if not r or not cw or not ch then
            for _,tex in ipairs(b) do tex:Hide() end
            return
        end
        local x,y=r.x*cw,-r.y*ch
        local w,h=r.w*cw,r.h*ch
        if w<1 or h<1 then for _,tex in ipairs(b) do tex:Hide() end;return end
        local hue=rgb or {1,.45,.06}
        for _,tex in ipairs(b) do tex:SetColorTexture(hue[1],hue[2],hue[3],.86);tex:ClearAllPoints() end
        b[1]:SetPoint('TOPLEFT',canvas,'TOPLEFT',x,y);b[1]:SetSize(w,2)
        b[2]:SetPoint('TOPLEFT',canvas,'TOPLEFT',x,y-h+2);b[2]:SetSize(w,2)
        b[3]:SetPoint('TOPLEFT',canvas,'TOPLEFT',x,y);b[3]:SetSize(2,h)
        b[4]:SetPoint('TOPLEFT',canvas,'TOPLEFT',x+w-2,y);b[4]:SetSize(2,h)
        for _,tex in ipairs(b) do tex:Show() end
    end
    local selectedBorder=CreateBorder()
    local edges={}
    function page:DebugDrawTileEdges()
        for _,b in ipairs(edges) do Paint(b,nil) end
        if not d.outline or not page.layer then return end
        local active=0
        local cw,ch=canvas:GetWidth(),canvas:GetHeight()
        local function ShowRect(rect,rgb)
            if active>=40 then return end
            if rect.x>1 or rect.y>1 or rect.x+rect.w<0 or rect.y+rect.h<0 then return end
            active=active+1
            if not edges[active] then edges[active]=CreateBorder() end
            Paint(edges[active],rect,rgb)
        end
        local layer=page.layer
        if d.flags.base then
            local cols=math.ceil(layer.layerWidth/layer.tileWidth)
            for i=1,min(page.baseTileCount or 0,16) do
                local col=(i-1)%cols;local row=floor((i-1)/cols)
                ShowRect({x=col*layer.tileWidth/layer.layerWidth,y=row*layer.tileHeight/layer.layerHeight,
                    w=min(layer.tileWidth,layer.layerWidth-col*layer.tileWidth)/layer.layerWidth,
                    h=min(layer.tileHeight,layer.layerHeight-row*layer.tileHeight)/layer.layerHeight},{.72,.67,.34})
            end
        end
        if d.flags.exploration then
            for _,tile in ipairs(page.exploredTiles or {}) do
                if tile:IsShown() and tile.afOverlay then
                    local a=tile.afOverlay
                    ShowRect(AdjustRect({x=a.x/layer.layerWidth,y=a.y/layer.layerHeight,
                        w=a.w/layer.layerWidth,h=a.h/layer.layerHeight},d.adjust.exploration,cw,ch),{.08,.85,1})
                end
            end
        end
        for _,slot in ipairs(page.debugTerrainPool or {}) do
            if slot.texture:IsShown() and slot.debugEntry then
                ShowRect(AdjustRect(slot.debugEntry.segment,d.adjust.terrain,cw,ch),{1,.26,.5})
            end
        end
    end
    local function FormatSelection(s)
        if not s then return 'Move cursor over the Atlas map.\nChoose Click to pick, or Capture cursor.' end
        local info=AF:GetAtlasMapInfo(page.mapID)
        local lines={
            'Map '..tostring(page.mapID)..'  '..tostring(info and info.name or ''),
            string.format('Cursor X %.3f  Y %.3f  zoom %.2fx',s.x,s.y,page.zoom or 1),
            'Selected '..tostring(s.source)..'  file '..tostring(s.file),
            s.base or '',
        }
        for _,h in ipairs(s.hits or {}) do
            if h~=s.base then lines[#lines+1]=h end
        end
        if s.world then lines[#lines+1]='World '..s.world end
        local stats=page.terrainStats
        if stats then
            lines[#lines+1]='Terrain: '..tostring(stats.reason)
            lines[#lines+1]=string.format('Tiles %d active / %d created / %d deferred',stats.visible or 0,stats.created or 0,stats.clipped or 0)
        end
        return table.concat(lines,'\n')
    end
    local function UpdateSample(force)
        if not panel:IsShown() or not page:IsShown() then return end
        local nx,ny=CursorNorm()
        if not d.frozen and nx then d.selection=InspectAt(nx,ny) end
        local s=d.selection
        if d.tab=='inspector' then
            readout:SetText(FormatSelection(s))
            inspectLine:SetText(nx and 'Map cursor '..Coordinates(nx,ny) or 'Cursor is outside the map')
        end
        Paint(selectedBorder,s and s.rect,{1,.8,.1})
        if force and page.DebugDrawTileEdges then page:DebugDrawTileEdges() end
    end
    function page:DebugCaptureCursor()
        local nx,ny=CursorNorm()
        if not nx then
            AF.Print('Move your cursor over the Atlas map, then click Capture cursor or pick a tile.')
            return
        end
        d.selection=InspectAt(nx,ny)
        d.frozen=true
        freeze.label:SetText('Freeze: ON')
        UpdateSample(true)
    end
    page.DebugUpdateInspector=UpdateSample
    local function BuildReport()
        local info=AF:GetAtlasMapInfo(page.mapID)
        local out={'AF Map Debug v0.4.0.18 | map '..tostring(page.mapID)..' '..tostring(info and info.name or '?'),
            'zoom '..Pretty(page.zoom)..' | canvas '..Pretty(canvas:GetWidth())..' x '..Pretty(canvas:GetHeight()),
            'base art '..tostring(page.layer and page.layer.layerWidth)..'x'..tostring(page.layer and page.layer.layerHeight),
            'terrain: '..tostring(AF.db.settings.atlas.terrainEnabled)..', raw/no masks: '..tostring(d.unmasked)..', exploration edge UV legacy: '..tostring(d.legacyExplorationUV)}
        local stats=page.debugExplorationStats
        if stats then
            out[#out+1]=string.format('exploration pieces=%d edge=%d groups=%d invalid=%d',
                stats.pieces or 0,stats.edgePieces or 0,stats.groups or 0,stats.invalidGroups or 0)
        end
        local p=C_Map and C_Map.GetPlayerMapPosition
        if type(p)=='function' then
            local ok,pos=pcall(p,page.mapID,'player')
            if ok and pos and pos.GetXY then
                local yes,x,y=pcall(pos.GetXY,pos)
                if yes then out[#out+1]='player x='..Pretty(x)..' y='..Pretty(y) end
            end
        end
        for _,item in ipairs(layerInfo) do out[#out+1]=item[1]..'='..tostring(State(item[1])) end
        for _,name in ipairs({'exploration','terrain','detail'}) do
            local a=d.adjust[name]
            out[#out+1]=name..' offset='..a.x..','..a.y..' scale='..Pretty(a.sx)..','..Pretty(a.sy)
        end
        out[#out+1]=FormatSelection(d.selection)
        return table.concat(out,' | ')
    end
    local function Capture()
        local report=BuildReport()
        reportBox:SetText(report)
        reportBox:SetFocus()
        reportBox:HighlightText()
        AF.Print('Diagnostic captured. Ctrl+C in the selection box, then paste it here with a screenshot.')
    end
    local capture=Btn(panel,'Capture report',166,24,'BOTTOMLEFT',panel,'BOTTOMLEFT',14,4)
    capture:SetScript('OnClick',Capture)
    local reset=Btn(panel,'Reset debug',165,24,'BOTTOMRIGHT',panel,'BOTTOMRIGHT',-13,4)
    reset:SetScript('OnClick',function() RestoreDefaults();SyncAlign();UpdateSample(true) end)
    local oldReposition=page.RepositionTiles
    page.RepositionTiles=function(self,...)
        oldReposition(self,...)
        ApplyBase()
        if panel:IsShown() then self:DebugDrawTileEdges() end
    end
    local oldRender=page.RenderMap
    page.RenderMap=function(self,...)
        oldRender(self,...)
        ApplyBase()
        if panel:IsShown() then self:DebugDrawTileEdges() end
    end
    local oldLayers=page.RefreshLayers
    page.RefreshLayers=function(self,...)
        if oldLayers then oldLayers(self,...) end
        if d.soloFile then
            for _,tile in ipairs(page.exploredTiles or {}) do
                if tile.afOverlay and tostring(tile.afOverlay.file)~=tostring(d.soloFile) then tile:Hide() end
            end
        end
        if panel:IsShown() then self:DebugDrawTileEdges() end
    end
    local timer=0
    panel:SetScript('OnUpdate',function(_,elapsed)
        timer=timer+(elapsed or 0)
        if timer<.20 then return end
        timer=0
        UpdateSample(false)
    end)
    panel:SetScript('OnHide',function()
        Paint(selectedBorder,nil)
        for _,b in ipairs(edges) do Paint(b,nil) end
        page.DebugPickArmed=false
    end)
    page:HookScript('OnHide',function() panel:Hide();page.DebugPickArmed=false end)
    function page:ToggleMapDebug(forceOpen)
        if panel:IsShown() and not forceOpen then
            panel:Hide();self.DebugPickArmed=false
            return true
        end
        panel:ClearAllPoints()
        panel:SetPoint('CENTER',UIParent,'CENTER',0,0)
        panel:SetFrameStrata('TOOLTIP');panel:SetFrameLevel(150)
        panel:Show()
        if panel.Raise then panel:Raise() end
        local ok,err=pcall(function()
            if d.RefreshInspectorButtons then d.RefreshInspectorButtons() end
            UpdateSample(true)
        end)
        if not ok and AF.Print then AF.Print('Map debug opened; inspector refresh error: '..tostring(err)) end
        if AF.Print then AF.Print('Map Debug window: '..(panel:IsShown() and 'OPEN' or 'NOT VISIBLE')..' (use /af mapdebug to toggle).') end
        return panel:IsShown()
    end
    function page:PrintMapDebug()
        local report=BuildReport()
        if AF.Print then AF.Print(report) end
        return report
    end
    page.debugPanel=panel
    SyncAlign();RefreshControls();SelectTab('layers')
    panel:Hide()
end
