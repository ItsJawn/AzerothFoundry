-- Azeroth Foundry 0.4.0.15: temporary raw-terrain inspection; 0.4.0.11: full-size revealed masks and stable terrain zoom.
-- Tile IDs and the 533.333-yard grid are adapted from MIT-licensed OpenMap.
-- Terrain is masked with exploration artwork explicitly revealed by the
-- selected scope: current character or saved union of registered characters.
-- The static terrain tile index never counts as evidence of discovery.
-- Tiles lacking a mask are NOT rendered (fail-closed).
local _, AF = ...
-- Slots represent tile x reveal-mask pairs, not unique minimap tile IDs.
-- A single map tile often needs multiple explored-mask pieces. 32 was too small.
-- Maximum is a hard ceiling; we allocate only onscreen pieces + up to 16 prefetch.
local T = {maxTiles=96,prefetchTiles=16,threshold=2.5,fullBlend=3.5,manifests={}}
AF.AtlasTerrain=T
local min,max,abs,floor=math.min,math.max,math.abs,math.floor
local TILE=533.3333333333

-- Forever-only experimental tile resolution for Zephras Isle. The island is a
-- separate instance (world 2991), outside OpenMap's older continent index.
-- Look up its *client-owned* terrain files by path instead of shipping BLP art,
-- guessing FileDataIDs, or touching the working continent indexes.
-- C_UIFileAsset.GetFileID is the modern FileAsset path resolver. If the Forever
-- client does not publish these paths, fail closed to the native illustrated map.
local ZEPHRAS_WORLD=2991
local zephrasLookupStatus=nil
local zephrasLookupAttempted=false
local function zephrasTiles(x0,y0,x1,y1,x2,y2)
    if zephrasLookupAttempted then return nil end
    zephrasLookupAttempted=true
    if not (C_UIFileAsset and type(C_UIFileAsset.GetFileID)=='function') then
        zephrasLookupStatus='C_UIFileAsset.GetFileID unavailable'
        return nil
    end
    local x3,y3=x1+x2-x0,y1+y2-y0
    local minX,maxX=min(x0,x1,x2,x3),max(x0,x1,x2,x3)
    local minY,maxY=min(y0,y1,y2,y3),max(y0,y1,y2,y3)
    -- Map grid key is x*64+y. Like the existing tile index, the first
    -- minimap filename coordinate follows world Y; the second follows world X.
    local colLo=max(0,floor(32-maxY/TILE)-1)
    local colHi=min(63,floor(32-minY/TILE)+1)
    local rowLo=max(0,floor(32-maxX/TILE)-1)
    local rowHi=min(63,floor(32-minX/TILE)+1)
    if colHi<colLo or rowHi<rowLo then
        zephrasLookupStatus='Zephras world projection has no valid tile range'
        return nil
    end
    local result,count,lookups={},0,0
    local getID=C_UIFileAsset.GetFileID
    for col=colLo,colHi do
        for row=rowLo,rowHi do
            local basename=string.format('map%02d_%02d.blp',col,row)
            -- The modern asset lookup accepts forward- or backslash paths;
            -- query a second spelling only when the first cannot be resolved.
            local names={
                'world/minimaps/2991/'..basename,
                'World\\Minimaps\\2991\\'..basename,
            }
            local fileID
            for _,name in ipairs(names) do
                lookups=lookups+1
                local ok,id=pcall(getID,name)
                if ok and type(id)=='number' and id>0 then
                    fileID=id
                    break
                end
            end
            if fileID then
                result[col*64+row]=fileID
                count=count+1
            end
        end
    end
    zephrasLookupStatus=string.format('Zephras tile filenames resolved: %d from %d coordinate candidates (%d queries)',
        count,(colHi-colLo+1)*(rowHi-rowLo+1),lookups)
    if count==0 then
        zephrasLookupStatus=zephrasLookupStatus..' (lookup unsupported; no terrain index yet)'
        return nil
    end
    return result
end

local function vec(p)
    if not p then return end
    if type(p.GetXY)=='function' then
        local ok,x,y=pcall(p.GetXY,p)
        if ok and type(x)=='number' and type(y)=='number' then return x,y end
    end
    if type(p)=='table' then return tonumber(p.x),tonumber(p.y) end
end
local function clock()
    if type(debugprofilestop)=='function' then
        local ok,v=pcall(debugprofilestop)
        if ok and type(v)=='number' then return v end
    end
end
local function mapProjection(mapID)
    if not C_Map or type(C_Map.GetWorldPosFromMapPos)~='function'
        or type(CreateVector2D)~='function' then return nil,'Map world coordinates unavailable' end
    local function get(u,v)
        local ok,cont,p=pcall(C_Map.GetWorldPosFromMapPos,mapID,CreateVector2D(u,v))
        if not ok then return end
        local x,y=vec(p)
        if x and y and type(cont)=='number' then return cont,x,y end
    end
    local c,x0,y0=get(0,0)
    local c1,x1,y1=get(1,0)
    local c2,x2,y2=get(0,1)
    if not c or c~=c1 or c~=c2 then
        return nil,'World projection unavailable or inconsistent' end
    if c==ZEPHRAS_WORLD and AF.MapMinimap and not AF.MapMinimap[c] then
        AF.MapMinimap[c]=zephrasTiles(x0,y0,x1,y1,x2,y2)
    end
    if not AF.MapMinimap or not AF.MapMinimap[c] then
        return nil,(c==ZEPHRAS_WORLD and zephrasLookupStatus) or 'No indexed terrain on this continent' end
    local ax,ay,bx,by=x1-x0,y1-y0,x2-x0,y2-y0
    local determinant=ax*by-ay*bx
    if abs(determinant)<1e-3 then return nil,'Map world projection degenerate' end
    local function norm(x,y)
        local dx,dy=x-x0,y-y0
        return (dx*by-bx*dy)/determinant,(ax*dy-ay*dx)/determinant
    end
    return {continent=c,toMap=norm}
end

local function currentReveal(mapID,layer)
    if not C_MapExplorationInfo or type(C_MapExplorationInfo.GetExploredMapTextures)~='function'
       or not layer or not layer.layerWidth or not layer.layerHeight then
        return {},'Exploration mask API unavailable'
    end
    local scope=AF.db and AF.db.settings and AF.db.settings.atlas and AF.db.settings.atlas.scope or 'character'
    local ok,entries=pcall(AF.GetAtlasExplorationOverlays,AF,mapID,scope)
    if not ok or type(entries)~='table' then return {},'No saved exploration data' end
    local out={}
    local w,h=layer.layerWidth,layer.layerHeight
    local tw,th=layer.tileWidth,layer.tileHeight
    if not tw or not th or tw<=0 or th<=0 then return {},'Invalid map art dimensions' end
    for _,e in ipairs(entries) do
        local width,height=tonumber(e.textureWidth),tonumber(e.textureHeight)
        local ox,oy=tonumber(e.offsetX),tonumber(e.offsetY)
        if width and height and ox and oy and width>0 and height>0 and type(e.fileDataIDs)=='table' then
            local cols=math.ceil(width/tw)
            local rows=math.ceil(height/th)
            for i=1,min(#e.fileDataIDs,cols*rows) do
                local file=e.fileDataIDs[i]
                local x=(i-1)%cols*tw
                local y=floor((i-1)/cols)*th
                local rw,rh=min(tw,width-x),min(th,height-y)
                if type(file)=='number' and file>0 and rw>0 and rh>0 then
                    out[#out+1]={file=file,x=(ox+x)/w,y=(oy+y)/h,w=rw/w,h=rh/h,
                        -- Incomplete edge tiles use only the actual native pixels.
                        u=rw/tw,v=rh/th}
                end
            end
        end
    end
    return out,#out>0 and 'Explored art masks loaded ('..scope..')' or 'No revealed art for this map'
end

local function overlaps(a,b)
    return a.x<b.x+b.w and a.x+a.w>b.x and a.y<b.y+b.h and a.y+a.h>b.y
end
local function inRect(a,r)
    return a.x<r.right and a.x+a.w>r.left and a.y<r.bottom and a.y+a.h>r.top
end

function T:BuildManifest(mapID,layer)
    local projection,why=mapProjection(mapID)
    if not projection then return nil,why end
    local list=AF.MapMinimap[projection.continent]
    local entries={}
    for key,file in pairs(list) do
        local col,row=floor(key/64),key%64
        -- OpenMap's minimap grid: key=col*64+row; each tile is 533.33 yd.
        local u0,v0=projection.toMap((32-row)*TILE,(32-col)*TILE)
        local u1,v1=projection.toMap((31-row)*TILE,(31-col)*TILE)
        local x,y,w,h=min(u0,u1),min(v0,v1),abs(u1-u0),abs(v1-v0)
        if x<1 and x+w>0 and y<1 and y+h>0 and w>0 and h>0
            and type(file)=='number' and file>0 then
            entries[#entries+1]={texture=file,x=x,y=y,w=w,h=h,key=key}
        end
    end
    local masks,maskStatus=currentReveal(mapID,layer)
    return {mapID=mapID,tiles=entries,masks=masks,source=(projection.continent==ZEPHRAS_WORLD and 'Zephras client file lookup' or 'OpenMap v0.4.0-beta')..' + live client reveal',maskStatus=maskStatus},nil
end

-- Only consider the tile/mask *intersection*: a huge exploration piece may
-- overlap a tile while neither actually touches the displayed viewport.
local function intersection(a,b)
    local l,t=max(a.x,b.x),max(a.y,b.y)
    local r,btm=min(a.x+a.w,b.x+b.w),min(a.y+a.h,b.y+b.h)
    if r>l and btm>t then return {x=l,y=t,w=r-l,h=btm-t} end
end

local function withMargin(rect)
    local mx=(rect.right-rect.left)*.14
    local my=(rect.bottom-rect.top)*.14
    return {left=max(0,rect.left-mx),right=min(1,rect.right+mx),
            top=max(0,rect.top-my),bottom=min(1,rect.bottom+my)}
end

-- Return visible pieces FIRST and a small cache outside the viewport SECOND.
-- Stable identities let the texture pool preserve objects while the canvas pans.
function T:VisibleCandidates(manifest,rect,capacity,reuse)
    if not manifest then return {},0,0,0,0,0 end
    local padding=withMargin(rect)
    local result,potential,unmasked,onScreen={},0,0,0
    local cx,cy=(rect.left+rect.right)*.5,(rect.top+rect.bottom)*.5
    -- Most explored-region masks are elsewhere on the map. Eliminate them
    -- before doing tile-by-mask intersection tests on each pan.
    local nearbyMasks={}
    for _,mask in ipairs(manifest.masks) do
        if inRect(mask,padding) then nearbyMasks[#nearbyMasks+1]=mask end
    end
    for _,tile in ipairs(manifest.tiles) do
        if inRect(tile,padding) then
            local visible=inRect(tile,rect)
            if visible then potential=potential+1 end
            local hasScreenMask=false
            for _,mask in ipairs(nearbyMasks) do
                local segment=intersection(tile,mask)
                if segment and inRect(segment,padding) then
                    local on=inRect(segment,rect)
                    if on then hasScreenMask=true;onScreen=onScreen+1 end
                    local key=tostring(manifest.mapID or '')..':'..tostring(tile.key)..':'..tostring(mask.file)..':'..
                        tostring(mask.x)..':'..tostring(mask.y)
                    result[#result+1]={tile=tile,mask=mask,segment=segment,key=key,onscreen=on,
                        reused=reuse and reuse[key] and true or false,
                        d=(segment.x+segment.w*.5-cx)^2+(segment.y+segment.h*.5-cy)^2}
                end
            end
            if visible and not hasScreenMask then unmasked=unmasked+1 end
        end
    end
    table.sort(result,function(a,b)
        if a.onscreen~=b.onscreen then return a.onscreen end
        -- A small hysteresis bonus stops edge tiles being churned on each drag.
        local da=a.d-(a.reused and .0025 or 0)
        local db=b.d-(b.reused and .0025 or 0)
        if da~=db then return da<db end
        return a.key<b.key
    end)
    local budget=min(capacity or self.maxTiles,self.maxTiles,onScreen+self.prefetchTiles)
    local keep={}
    for i=1,min(#result,budget) do keep[i]=result[i] end
    return keep,potential,unmasked,#result,onScreen,max(0,onScreen-budget)
end

-- Debug only: list raw minimap tiles without requiring exploration masks.
-- These are still viewport-culled and respect the same 96-slot budget.
function T:UnmaskedCandidates(manifest,rect,capacity,reuse)
    local padding=withMargin(rect)
    local cx,cy=(rect.left+rect.right)*.5,(rect.top+rect.bottom)*.5
    local candidates,visible={},0
    for _,tile in ipairs(manifest.tiles) do
        if inRect(tile,padding) then
            local on=inRect(tile,rect)
            if on then visible=visible+1 end
            local key=tostring(manifest.mapID)..':RAW:'..tostring(tile.key)
            candidates[#candidates+1]={tile=tile,segment=tile,mask=nil,key=key,
                onscreen=on,reused=reuse and reuse[key] and true or false,
                d=(tile.x+tile.w*.5-cx)^2+(tile.y+tile.h*.5-cy)^2}
        end
    end
    table.sort(candidates,function(a,b)
        if a.onscreen~=b.onscreen then return a.onscreen end
        if a.d~=b.d then return a.d<b.d end
        return a.key<b.key
    end)
    local budget=min(capacity or self.maxTiles,self.maxTiles,visible+self.prefetchTiles)
    local chosen={}
    for i=1,min(#candidates,budget) do chosen[i]=candidates[i] end
    return chosen,visible,0,#candidates,visible,max(0,visible-budget)
end

function T:Attach(page,viewport,canvas,right,UI,palette)
    local settings=AF.db and AF.db.settings and AF.db.settings.atlas
    if not settings then return end
    if settings.terrainEnabled==nil then settings.terrainEnabled=false end
    local pool={}
    page.debugTerrainPool=pool
    local stats={visible=0,created=0,candidates=0,masked=0,eligible=0,
        required=0,clipped=0,reused=0,swaps=0,updates=0,skipped=0,lastMs=nil,
        reason='Terrain OFF',source='OpenMap tile index'}
    page.terrainStats=stats
    local manifestID,manifest,manifestErr=nil,nil,nil
    local previous,previousRender=nil,0
    -- A zoom resize is not an ordinary pan. It invalidates every terrain AND
    -- exploration-mask position; do not let the pan throttle leave stale sizes.
    local laidOutZoom,laidOutWidth,laidOutHeight=nil,nil,nil
    local settleNextFrame=false
    local inSettlePass=false
    local function SyncNativeDetail()
        local showing=stats.visible>0
        if page.afLastTerrainVisible~=showing then
            page.afLastTerrainVisible=showing
            if type(page.RefreshDetailOpacity)=='function' then
                page:RefreshDetailOpacity()
            end
        end
    end
    local function HideAll()
        for _,slot in ipairs(pool) do slot.texture:Hide();slot.key=nil end
        stats.visible=0
        SyncNativeDetail()
    end
    local function Fail(why)
        settings.terrainEnabled=false
        stats.reason='Disabled safely: '..tostring(why):sub(1,110)
        HideAll()
        if AF.Print then AF.Print('Atlas terrain safely disabled: '..tostring(why)) end
    end
    local function Make()
        if #pool>=T.maxTiles then return end
        -- Above explored parchment (sublayer 3), below hover (5) and pins.
        local texture=canvas:CreateTexture(nil,'ARTWORK',nil,4)
        local mask=canvas:CreateMaskTexture(nil,'ARTWORK')
        local slot={texture=texture,mask=mask,maskActive=false}
        pool[#pool+1]=slot
        stats.created=#pool
        return slot
    end
    local function ToggleSlotMask(slot,active)
        if slot.maskActive==active then return end
        if active then
            if slot.texture.AddMaskTexture then
                slot.texture:AddMaskTexture(slot.mask)
                slot.maskActive=true
            end
        else
            if slot.texture.RemoveMaskTexture then
                slot.texture:RemoveMaskTexture(slot.mask)
                slot.maskActive=false
            end
        end
    end
    local function DebugTransform()
        local d=page.afMapDebug
        local a=d and d.adjust and d.adjust.terrain
        return a and a.sx or 1,a and a.sy or 1,a and a.x or 0,a and a.y or 0
    end
    local function visibleRect()
        local cw,ch=canvas:GetWidth(),canvas:GetHeight()
        local vx,vy=viewport:GetLeft(),viewport:GetTop()
        local cx,cy=canvas:GetLeft(),canvas:GetTop()
        if not cw or not ch or cw<=0 or ch<=0 or not vx or not vy or not cx or not cy then return end
        return {left=max(0,(vx-cx)/cw),right=min(1,(viewport:GetRight()-cx)/cw),
                top=max(0,(cy-vy)/ch),bottom=min(1,(cy-viewport:GetBottom())/ch)}
    end
    -- Crop the visible TERRAIN texture to the intersection of its world tile
    -- and the revealed piece. Render the REVEAL MASK at its original map origin
    -- and scale: MaskTexture does not consistently support cropped TexCoords.
    -- The full mask still clips just the attached terrain texture; all
    -- unexplored pixels remain invisible.
    local function place(slot,entry,cw,ch)
        local tile,shape,segment=entry.tile,entry.mask,entry.segment
        local tex,mask=slot.texture,slot.mask
        local clamp=function(v) return max(0,min(1,v)) end
        local sx,sy,dx,dy=DebugTransform()
        local x=((segment.x-.5)*sx+.5)*cw+dx
        local y=((segment.y-.5)*sy+.5)*ch+dy
        local w,h=segment.w*cw*sx,segment.h*ch*sy
        tex:ClearAllPoints()
        tex:SetPoint('TOPLEFT',canvas,'TOPLEFT',x,-y)
        tex:SetSize(w,h)
        -- Cropping inside the original terrain TILE, without rescaling its
        -- full bitmap into a small mask region (which causes deformation).
        tex:SetTexCoord(
            clamp((segment.x-tile.x)/tile.w),
            clamp((segment.x+segment.w-tile.x)/tile.w),
            clamp((segment.y-tile.y)/tile.h),
            clamp((segment.y+segment.h-tile.y)/tile.h))
        -- Blizzard MaskTexture does not reliably support TexCoord cropping.
        -- The old code stretched the mask bitmap into the *intersection* and
        -- attempted to crop via SetTexCoord; on Forever this left a vertical
        -- band where exploration art had more than one tile. Keep the ENTIRE
        -- bitmap at its native logical position instead. Masks automatically
        -- have no effect outside their attached terrain texture's rectangle.
        -- For an incomplete edge tile (u/v < 1), its full underlying bitmap
        -- is wider/taller than the occupied region by precisely 1/u or 1/v.
        if shape then
            local fullWidth=shape.w/max(.001,shape.u or 1)*cw*sx
            local fullHeight=shape.h/max(.001,shape.v or 1)*ch*sy
            mask:ClearAllPoints()
            mask:SetPoint('TOPLEFT',canvas,'TOPLEFT',((shape.x-.5)*sx+.5)*cw+dx,-(((shape.y-.5)*sy+.5)*ch+dy))
            mask:SetSize(fullWidth,fullHeight)
        end
        slot.width,slot.height=cw,ch
    end
    local function getManifest(mapID)
        local scope=AF.db and AF.db.settings and AF.db.settings.atlas and AF.db.settings.atlas.scope or 'character'
        local cacheKey=tostring(mapID)..':'..scope
        if manifestID==cacheKey then return manifest,manifestErr end
        HideAll() -- Discard stale slot identities and fog textures on map changes.
        manifestID=cacheKey
        manifest,manifestErr=T:BuildManifest(mapID,page.layer)
        previous=nil
        return manifest,manifestErr
    end
    function page:RefreshTerrain(force)
        if not settings.terrainEnabled then
            HideAll();stats.reason='Terrain OFF';return
        end
        if not self:IsShown() then HideAll();stats.reason='Atlas hidden';return end
        local a=max(0,min(1,((self.zoom or 1)-T.threshold)/(T.fullBlend-T.threshold)))
        if a<=0 then
            HideAll();stats.reason='Zoom in further for terrain';return
        end
        local cw,ch=canvas:GetWidth(),canvas:GetHeight()
        local geometryChanged=laidOutZoom~=(self.zoom or 1)
            or not laidOutWidth or not laidOutHeight
            or abs(cw-laidOutWidth)>.1 or abs(ch-laidOutHeight)>.1
        if geometryChanged and not inSettlePass then
            -- Frame geometry can settle one frame AFTER SetSize/SetPoint in the
            -- WoW UI layout engine; schedule exactly one follow-up positioning.
            settleNextFrame=true
        end
        local now=clock()
        -- Pan updates remain limited to ~12/sec. Zoom and resize are urgent:
        -- masking textures at stale dimensions produces the observed offset.
        if not force and not geometryChanged and now and now-previousRender<85 then
            stats.skipped=stats.skipped+1;return
        end
        local data,why=getManifest(self.mapID)
        if not data then
            HideAll()
            stats.reason=(why or 'World projection unavailable')..'; native map art used'
            return
        end
        self.debugTerrainManifest=data
        local raw=page.afMapDebug and page.afMapDebug.unmasked==true
        if #data.masks==0 and not raw then
            HideAll();stats.reason=data.maskStatus or 'No explored-area masks';return
        end
        local rect=visibleRect()
        if not rect or rect.right<=rect.left or rect.bottom<=rect.top then
            HideAll();stats.reason='Map viewport not ready';return
        end
        local key=table.concat({self.mapID or 0,self.zoom or 1,self.offsetX or 0,self.offsetY or 0,
            cw or 0,ch or 0},':')
        if not force and previous==key then stats.skipped=stats.skipped+1;return end
        previous=key
        previousRender=now or previousRender
        local started=clock()

        local oldKeys={}
        for _,slot in ipairs(pool) do
            if slot.key then oldKeys[slot.key]=slot end
        end
        local choices,found,hidden,eligible,required,clipped
        if raw then
            choices,found,hidden,eligible,required,clipped=T:UnmaskedCandidates(data,rect,T.maxTiles,oldKeys)
        else
            choices,found,hidden,eligible,required,clipped=T:VisibleCandidates(data,rect,T.maxTiles,oldKeys)
        end
        stats.candidates=found;stats.masked=hidden;stats.eligible=eligible
        stats.required=required;stats.clipped=clipped

        -- KEEP existing tile->slot assignments. Old code overwrote every slot
        -- as the sorted list order changed, causing a visible texture pop.
        local wanted={}
        local pending={}
        local retained,swapped=0,0
        for _,entry in ipairs(choices) do
            wanted[entry.key]=true
            if oldKeys[entry.key] then
                entry.slot=oldKeys[entry.key]
                retained=retained+1
            else
                pending[#pending+1]=entry
            end
        end
        local free={}
        for _,slot in ipairs(pool) do
            if not slot.key or not wanted[slot.key] then
                slot.texture:Hide()
                slot.key=nil
                free[#free+1]=slot
            end
        end
        for _,entry in ipairs(pending) do
            local slot=table.remove(free)
            if not slot then slot=Make() end
            if slot then
                entry.slot=slot
            end
        end
        local displayed=0
        for _,entry in ipairs(choices) do
            local slot=entry.slot
            if slot then
                local ok,err=pcall(function()
                    local tex,mask=slot.texture,slot.mask
                    -- The mask is never TexCoord-cropped, even on incomplete
                    -- exploration edge tiles. This also supports Forever
                    -- clients where MaskTexture:SetTexCoord is not implemented.
                    if slot.key~=entry.key then
                        -- SetTexture only when a slot is assigned new art.
                        tex:SetTexture(entry.tile.texture,nil,nil,'LINEAR')
                        if entry.mask then mask:SetTexture(entry.mask.file) end
                        slot.key=entry.key
                        slot.width=nil
                        swapped=swapped+1
                    end
                    -- The debug mode deliberately allows removing ALL terrain masks.
                    -- Reattach them when the normal explored view is restored.
                    ToggleSlotMask(slot,not raw)
                    slot.debugEntry=entry
                    -- Forced debug refresh must also reposition on slider changes.
                    if force or slot.width~=cw or slot.height~=ch then place(slot,entry,cw,ch) end
                    tex:SetAlpha(a)
                    tex:Show()
                    displayed=displayed+1
                end)
                if not ok then Fail(err);return end
            end
        end
        stats.visible=displayed
        SyncNativeDetail()
        laidOutZoom=self.zoom or 1
        laidOutWidth,laidOutHeight=cw,ch
        stats.reused=retained
        stats.swaps=stats.swaps+swapped
        stats.updates=stats.updates+1
        if clipped>0 then
            stats.reason='Tile budget reached ('..clipped..' pieces deferred)'
        else
            stats.reason=displayed>0 and (raw and 'DEBUG: unmasked raw terrain' or 'Real masked minimap terrain') or
                (found==0 and 'No indexed terrain in view' or 'No explored terrain in view')
        end
        local ended=clock()
        if started and ended then stats.lastMs=max(0,ended-started) end
    end
    function page:DebugTerrainModeChanged(rebuild)
        previous=nil
        if rebuild then manifestID=nil end
        self:RefreshTerrain(true)
    end
    local button=UI:Button(right,'Terrain: OFF',function()
        settings.terrainEnabled=not settings.terrainEnabled
        previous=nil
        if settings.terrainEnabled then manifestID=nil end
        page:RefreshTerrain(true)
    end)
    button:SetPoint('BOTTOMLEFT',right,'BOTTOMLEFT',12,65)
    button:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-12,65)
    button:SetHeight(26)
    local label=UI:Text(right,'small',palette.ink,'CENTER')
    label:SetPoint('BOTTOMLEFT',right,'BOTTOMLEFT',12,92)
    label:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-12,92)
    label:SetHeight(42)
    local function relabel()
        button.label:SetText(settings.terrainEnabled and 'Terrain: ON' or 'Terrain: OFF')
        local tint=settings.terrainEnabled and 1 or .38
        for _,slice in ipairs(button.normalSlices or {}) do slice:SetVertexColor(tint,tint,tint) end
        label:SetText(stats.reason..'\nTiles '..stats.visible..'/'..T.maxTiles)
    end
    page.PrintTerrainDiagnostic=function()
        local fps=type(GetFramerate)=='function' and GetFramerate() or 'n/a'
        local kb=type(collectgarbage)=='function' and collectgarbage('count') or 'n/a'
        local addonKB='n/a'
        local get=(C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage
        if type(get)=='function' then
            if type(UpdateAddOnMemoryUsage)=='function' then pcall(UpdateAddOnMemoryUsage) end
            local ok,value=pcall(get,'AzerothFoundry')
            if ok and type(value)=='number' then addonKB=value end
        end
        local fmt=function(n) return type(n)=='number' and string.format('%.1f',n) or tostring(n) end
        local msg='Terrain: '..stats.reason..(zephrasLookupStatus and (' | '..zephrasLookupStatus) or '')..' | tiles '..stats.visible..'/'..T.maxTiles..
          ' (created '..stats.created..', in view '..stats.candidates..', required pieces '..stats.required..
          ', eligible '..stats.eligible..', deferred '..stats.clipped..', no mask '..stats.masked..
          ', retained '..stats.reused..', lifetime swaps '..stats.swaps..') | redraws '..stats.updates..
          ' skipped '..stats.skipped..' | addon KB '..fmt(addonKB)..
          ' / global Lua KB '..fmt(kb)..' | FPS '..fmt(fps)
        if stats.lastMs then msg=msg..' | last update '..fmt(stats.lastMs)..' ms' end
        if AF.Print then AF.Print(msg) end
        return msg
    end
    local elapsed=0
    local watcher=CreateFrame('Frame',nil,page)
    watcher:SetScript('OnUpdate',function(_,dt)
        elapsed=elapsed+(dt or 0)
        if elapsed<1 then return end
        elapsed=0
        if page:IsShown() then relabel() end
    end)
    for _,event in ipairs({'MAP_EXPLORATION_UPDATED','ZONE_CHANGED_NEW_AREA'}) do
        pcall(watcher.RegisterEvent,watcher,event)
    end
    watcher:SetScript('OnEvent',function()
        -- A new discovery invalidates the per-character reveal mask.
        manifestID=nil; previous=nil
        if page:IsShown() and settings.terrainEnabled then page:RefreshTerrain(true) end
    end)
    viewport:HookScript('OnMouseUp',function() if settings.terrainEnabled then page:RefreshTerrain(true) end end)
    viewport:HookScript('OnUpdate',function()
        if settleNextFrame then
            settleNextFrame=false
            if settings.terrainEnabled and page:IsShown() then
                -- The first redraw uses the new zoom immediately; this second
                -- pass reconciles any deferred client anchor/layout updates.
                inSettlePass=true
                page:RefreshTerrain(true)
                inSettlePass=false
            end
        end
    end)
    page:RefreshTerrain(true)
    relabel()
end
