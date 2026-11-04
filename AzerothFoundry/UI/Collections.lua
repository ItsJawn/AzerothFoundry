-- Azeroth Foundry Collections centered cards and source-aware catalog filtering, v0.4.4.2.7.
local _, AF = ...
local UI=AF.UI
local P=UI.palette
local CAT={{'mounts','Mounts'},{'pets','Companions / Pets'},{'toys','Toys'},{'transmog','Transmog'}}
local MYSTERY_ICON='Interface\\Icons\\INV_Misc_QuestionMark'
local SOURCE_TYPES={[1]='Drop',[2]='Quest',[3]='Vendor',[4]='Profession',[5]='Pet battle / other',[6]='Achievement',[7]='World event',[8]='Promotion',[9]='Trading card',[10]='Shop',[11]='Discovery'}
local function HasSourceText(value)
    return type(value)=='string' and value:match('%S') ~= nil
end
local function SourceTypeLabel(value)
    local code=tonumber(value)
    if not code or code==0 then return 'Not categorized' end
    return SOURCE_TYPES[code] or ('Client category #'..code)
end
local unpack=unpack or table.unpack
local function Call(obj,method,...)
    if obj and type(obj[method])=='function' then
        local ok,a,b,c=pcall(obj[method],obj,...)
        if ok then return a,b,c end
    end
end
local function Label(parent,text,size,color)
    local l=UI:Text(parent,size or 'small',color or P.ink)
    l:SetText(text or '')
    l:SetJustifyV('TOP')
    l:SetWordWrap(true)
    return l
end
local function Card(parent) return UI:Card(parent) end
-- Quiet leather controls consistent with Characters and Workshop. The base
-- UI:Button supplies hit handling; we only add visual layers.
local function CollectionButton(parent, label, callback)
    local button=UI:Button(parent,label,callback,'row')
    UI:Background(button,P.leather,true)
    button.afThemeButtonTextRole="dataText"
    if button.rowBase then button.rowBase:Hide() end
    button.label:SetTextColor(unpack(P.pale))
    button.label:SetJustifyH('CENTER')
    local glow=button:CreateTexture(nil,'HIGHLIGHT')
    glow:SetPoint('TOPLEFT',button,'TOPLEFT',5,-4)
    glow:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',-5,4)
    glow:SetColorTexture(1,.74,.32,.13)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(button,function(_,t)
        local ink=UI.ThemeReadableText and UI:ThemeReadableText(t.dataSurface,t.dataText) or t.dataText
        button.label:SetTextColor(unpack(ink))
        local c=t.accent
        glow:SetColorTexture(c[1],c[2],c[3],.15)
    end) end
    return button
end
local function DisplayText(entry)
    if not entry then return '' end
    return '['..tostring(entry.id)..'] '..(entry.name or '?')
end
local function FormatMoney(price)
    if type(price)~='number' then return 'Price not recorded' end
    local g=math.floor(price/10000)
    local s=math.floor(price%10000/100)
    local c=price%100
    return tostring(g)..'g '..tostring(s)..'s '..tostring(c)..'c (last observed)'
end
local function HumanDate(ts)
    if type(ts)=='number' and ts>0 and type(date)=='function' then return date('%Y-%m-%d %H:%M',ts) end
    return 'Date unavailable'
end
local function PoseSummary(cat,id,entry)
    local pose=AF:CollectionModelPose(cat,id)
    return 'Category: '..tostring(cat)..'  ID: '..tostring(id)..'\n'
       ..'Display: '..tostring(entry and entry.displayID)..'  Scene: '..tostring(entry and entry.sceneID)..'\n'
       ..(cat=='transmog' and ('Wardrobe turn adjustment: '..tostring(pose.wardrobeFacingOffset or 0)..' degrees') or ('Facing: '..tostring(pose.facing)..' degrees'))
       ..'  Scale: '..tostring(pose.scale)
       ..'  Paused: '..tostring(pose.paused)..'  Icon-only: '..tostring(pose.iconOnly)
end

-- Treat invalid client icon tokens as unavailable, not as an empty grey square.
local function GoodTexture(tex)
    if type(tex)=='number' then return tex>0 and tex or nil end
    if type(tex)=='string' and tex~='' then return tex end
end
local function Try(fn,...)
    if type(fn)~='function' then return nil end
    local ok,a,b,c,d,e,f,g,h=pcall(fn,...)
    if ok then return a,b,c,d,e,f,g,h end
end
local function SourceID(value)
    if type(value)=='number' then return value end
    if type(value)=='table' then return tonumber(value.sourceID or value.itemModifiedAppearanceID) end
end
local function ItemFromLink(link)
    if type(link)=='string' then return tonumber(link:match('item:(%d+)')) end
end
-- Item metadata can arrive after the visual/icon data. Keep unresolved item
-- names distinct from unresolved appearances: the source linkage is already valid.
-- LibItemDB is an optional reference dependency; the WoW client remains the primary source of truth.
local requestedItemIDs={}
local pendingItemIDs={}
local function ItemLibrary()
    if not LibStub then return nil end
    local ok,lib=pcall(LibStub,'LibItemDB-1.0',true)
    if ok and type(lib)=='table' then return lib end
end
local function ItemName(id)
    if not id or id<=0 then return nil end
    local name=Try(GetItemInfo,id)
    if type(name)=='string' and name~='' then return name,'CLIENT_CACHE' end
    if C_Item then
        name=Try(C_Item.GetItemNameByID,id)
        if type(name)=='string' and name~='' then return name,'CLIENT_NAME' end
        name=Try(C_Item.GetItemInfo,id)
        if type(name)=='string' and name~='' then return name,'CLIENT_ITEM' end
    end
    local lib=ItemLibrary()
    if lib and type(lib.GetName)=='function' then
        name=Try(lib.GetName,lib,id)
        if type(name)=='string' and name~='' then return name,'LIBITEMDB' end
    end
    return nil
end
local function RequestItemName(id)
    if not id or id<=0 or requestedItemIDs[id] then return end
    requestedItemIDs[id]=true
    if C_Item and type(C_Item.RequestLoadItemDataByID)=='function' then
        local ok=pcall(C_Item.RequestLoadItemDataByID,id)
        if ok then pendingItemIDs[id]=true end
    end
end
-- Resolve a visual appearance via unfiltered *source IDs*, which are not item IDs.
-- Results are session-only; catalog browsing NEVER records personal discovery.
-- Resolve only visible cards, and retry pending item names after their cache loads.
local function ResolveAppearance(entry)
    local C=C_TransmogCollection
    if not C or type(entry)~='table' or not tonumber(entry.id) then return end
    local ids,seen={},{}
    local function append(v)
        local id=SourceID(v)
        if id and id>0 and not seen[id] then seen[id]=true;ids[#ids+1]=id end
    end
    local all=Try(C.GetAllAppearanceSources,entry.id)
    if type(all)=='table' then for _,v in ipairs(all) do append(v) end end
    if #ids==0 then
        local sources=Try(C.GetAppearanceSources,entry.id,entry.categoryID)
        if type(sources)=='table' then for _,v in ipairs(sources) do append(v) end end
    end
    if #ids==0 then
        local sources=Try(C.GetAppearanceSources,entry.id)
        if type(sources)=='table' then for _,v in ipairs(sources) do append(v) end end
    end
    entry.sourceCount=#ids
    entry.sourceIDs=ids
    entry.sourceItems={}
    entry.resolutionStatus=#ids==0 and 'NO_SOURCES' or 'SOURCES_NO_ITEM_DATA'
    entry.needsItemData=false
    local bestQuality=-1
    local bestName,bestIcon,bestID,bestSource,bestNameOrigin
    local sourceLimit=math.min(#ids,24)
    for i=1,sourceLimit do
        local sourceID=ids[i]
        local info=Try(C.GetSourceInfo,sourceID)
        if type(info)~='table' then info=nil end
        if not info or not info.visualID or tonumber(info.visualID)==entry.id then
            local itemID=info and tonumber(info.itemID) or nil
            if not itemID then itemID=tonumber(Try(C.GetSourceItemID,sourceID)) end
            local sourceName=info and info.name
            local nameOrigin=(type(sourceName)=='string' and sourceName~='') and 'TRANSMOG_SOURCE' or nil
            local icon=GoodTexture(Try(C.GetSourceIcon,sourceID))
            local srcInfo=Try(C.GetAppearanceSourceInfo,sourceID)
            if type(srcInfo)=='table' then
                icon=icon or GoodTexture(srcInfo.icon)
                itemID=itemID or ItemFromLink(srcInfo.itemLink)
            else
                -- Earlier client APIs return icon as the fourth result.
                local _,_,_,oldIcon,_,itemLink=Try(C.GetAppearanceSourceInfo,sourceID)
                icon=icon or GoodTexture(oldIcon)
                itemID=itemID or ItemFromLink(itemLink)
            end
            if itemID and itemID>0 then
                local clientName,origin=ItemName(itemID)
                if clientName then sourceName=clientName;nameOrigin=origin end
                if not clientName and not nameOrigin then
                    entry.needsItemData=true
                    RequestItemName(itemID)
                end
                if not icon then
                    icon=GoodTexture(Try(GetItemIcon,itemID))
                        or GoodTexture(C_Item and Try(C_Item.GetItemIconByID,itemID))
                end
            end
            local name=(type(sourceName)=='string' and sourceName~='') and sourceName or nil
            local quality=(name and 3 or 0)+(icon and 2 or 0)+(itemID and 1 or 0)
            entry.sourceItems[#entry.sourceItems+1]={sourceID=sourceID,itemID=itemID,name=name,icon=icon}
            if quality>bestQuality then
                bestQuality=quality;bestName=name;bestIcon=icon;bestID=itemID
                bestSource=sourceID;bestNameOrigin=nameOrigin
            end
            if name and icon then break end
        end
    end
    if bestSource then
        entry.sourceID=bestSource;entry.itemID=bestID
        entry.name=bestName or entry.name
        entry.icon=bestIcon or entry.icon
        entry.nameOrigin=bestNameOrigin
        if bestName and bestIcon then entry.resolutionStatus='NAME_AND_ICON_RESOLVED'
        elseif bestIcon then entry.resolutionStatus='ICON_ONLY_NAME_PENDING'
        elseif bestName then entry.resolutionStatus='NAME_ONLY'
        else entry.resolutionStatus='SOURCE_FOUND_NO_DETAILS' end
        -- If our displayed source has its name, no further refresh is needed.
        if bestName then entry.needsItemData=false end
    end
    entry.sourceChecked=math.min(#ids,sourceLimit)
end
-- Transmog visuals are item appearances, not creature display IDs. Use a
-- DressUpModel with the player's race/body and apply the verified source ID.
-- TryOn may legitimately reject another class's gear, or return data-pending.
-- A failed preview must leave the original 2D collection icon visible.
local function DressTryOn(model,value)
    if not model or type(model.TryOn)~='function' then return false,'TryOn unavailable' end
    local ok,result=pcall(model.TryOn,model,value)
    if not ok then return false,tostring(result) end
    -- 0=Success, 1=WrongRace, 2=NotEquippable, 3=DataPending.
    -- Older APIs may return nil on a successful application.
    if result==false or (type(result)=='number' and result~=0) then
        return false,'TryOn result '..tostring(result)
    end
    return true,'TryOn accepted '..tostring(value)..' ('..tostring(result)..')'
end
-- The wardrobe treats weapons differently from armor: they are standalone
-- appearance objects rather than items dressed onto the player mannequin.
-- GetCategoryInfo returns a category-wide isWeapon flag; this is more reliable
-- than guessing based on the selected item name. Keep guarded item fallbacks.
local function IsWeaponTransmog(entry)
    if not entry or entry.category~='transmog' then return false end
    local C=C_TransmogCollection
    if C and tonumber(entry.categoryID) then
        local name,isWeapon=Try(C.GetCategoryInfo,tonumber(entry.categoryID))
        if isWeapon==true then return true,'Category API' end
        if type(name)=='string' then
            local lower=name:lower()
            for _,part in ipairs({'weapon','sword','axe','mace','dagger','bow','gun','wand','staff','stave',
                'polearm','fist','crossbow','shield','off-hand','offhand','held'}) do
                if lower:find(part,1,true) then return true,'Category name' end
            end
        end
        if isWeapon==false then return false,'Category API (armor)' end
    end
    local itemID=tonumber(entry.itemID)
    if itemID then
        local infoFn=(C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        local _,_,_,equipLoc,_,classID=Try(infoFn,itemID)
        if classID==2 or equipLoc=='INVTYPE_SHIELD' or equipLoc=='INVTYPE_HOLDABLE' then
            return true,'Item inventory class'
        end
    end
    return false,'Armor/default'
end
-- Blizzard wardrobe appearance tiles use a specific model-camera preset per visual.
-- A full-body DressUpModel without that camera is technically correct but makes
-- chest/helmet previews tiny and often off-center. Prefer the client's presets,
-- and retain our icon/dress-up fallback when they're absent.
local function WardrobeCameraID(entry)
    local C=C_TransmogCollection
    if not C then return nil,'No collection camera API' end
    local camera=Try(C.GetAppearanceCameraID,tonumber(entry.id))
    if type(camera)=='number' and camera>0 then return camera,'appearance' end
    camera=Try(C.GetAppearanceCameraIDBySource,tonumber(entry.sourceID))
    if type(camera)=='number' and camera>0 then return camera,'source' end
    return nil,'Unavailable'
end
-- The stock wardrobe pairs a UI camera with a mannequin setup. The camera
-- already defines an intended yaw; forcing our old arbitrary 45-degree pose
-- *after* applying it turned the camera's nicely cropped view into a side view.
-- GetUICameraInfo returns the camera's yaw (radians) when supported. Use that,
-- otherwise let Model_ApplyUICamera own facing rather than overwriting it.
-- Without a native camera use conservative, slot-aware front/three-quarter
-- fallback values; these are TEST defaults, not claims of Blizzard's angles.
local function FallbackWardrobeFacing(entry)
    local category=tonumber(entry and entry.categoryID)
    local name=category and C_TransmogCollection and
        Try(C_TransmogCollection.GetCategoryInfo,category)
    name=type(name)=='string' and name:lower() or ''
    if name:find('shoulder',1,true) then return -78,'shoulders' end
    if name:find('hand',1,true) or name:find('glove',1,true) or
       name:find('wrist',1,true) or name:find('bracer',1,true) then
        return -82,'hands/wrists'
    end
    if name:find('foot',1,true) or name:find('feet',1,true) or
       name:find('boot',1,true) then return -82,'boots' end
    if name:find('weapon',1,true) or name:find('sword',1,true) or
       name:find('axe',1,true) or name:find('mace',1,true) then
        return -82,'weapons'
    end
    return -90,'centered body'
end
local function ReadUICameraFacing(camera)
    if not camera or type(GetUICameraInfo)~='function' then return nil end
    local _,_,_,yaw=Try(GetUICameraInfo,camera)
    if type(yaw)=='number' and yaw==yaw and math.abs(yaw)<=math.pi*2 then
        return yaw
    end
end
local function ApplyFacingAfterCamera(model)
    local offset=tonumber(model.afWardrobeFacingOffset) or 0
    local camera=model.afWardrobeCameraID
    local yaw=camera and ReadUICameraFacing(camera) or nil
    if yaw then
        local facing=yaw+math.rad(offset)
        Call(model,'SetFacing',facing)
        model.afWardrobeFinalFacing=facing
        model.afWardrobeFacingMode='Native camera yaw + '..offset..' degree adjustment'
    elseif model.afWardrobeCameraApplied and offset==0 then
        -- Preserve the native camera result. A manual SetFacing here was the bug.
        model.afWardrobeFinalFacing=Call(model,'GetFacing')
        model.afWardrobeFacingMode='Native camera (unmodified yaw)'
    else
        local fallback,slot=FallbackWardrobeFacing(model.afWardrobeEntry)
        local facing=math.rad(fallback+offset)
        Call(model,'SetFacing',facing)
        model.afWardrobeFinalFacing=facing
        model.afWardrobeFacingMode='Slot fallback '..slot..' ('..fallback..' degrees) + '..offset
    end
end
-- Preserve the native weapon camera but move somewhat closer. A modest
-- default 1.3x weapon-only scale is intentionally separate from saved user
-- adjustments and from all armor/mannequin presentation settings.
local function ApplyWeaponFraming(model,pose)
    if not model or not model.afWardrobeWeaponOnly then return end
    local scale=math.max(0.3,math.min(3,tonumber(pose and pose.scale) or 1))
    local zoom=1.30 * scale
    Call(model,'SetModelScale',zoom)
    model.afWeaponPreviewScale=zoom
    if model.afWardrobeEntry then model.afWardrobeEntry.previewWeaponScale=zoom end
end
local function ApplyWardrobeCamera(model,entry,pose)
    local camera,origin=WardrobeCameraID(entry)
    model.afWardrobeCameraID=camera
    model.afWardrobeEntry=entry
    model.afWardrobeFacingOffset=tonumber(pose and pose.wardrobeFacingOffset) or 0
    model.afWardrobeCameraApplied=false
    entry.previewCameraID=camera
    entry.previewCameraOrigin=origin
    if camera and type(Model_ApplyUICamera)=='function' then
        -- A pooled frame must not retain the previous item's camera or facing.
        Call(model,'RefreshCamera')
        local ok=pcall(Model_ApplyUICamera,model,camera)
        if ok then
            model.afWardrobeCameraApplied=true
            ApplyFacingAfterCamera(model)
            ApplyWeaponFraming(model,pose)
            entry.previewFacingMode=model.afWardrobeFacingMode
            entry.previewFacingDegrees=model.afWardrobeFinalFacing and math.deg(model.afWardrobeFinalFacing)
            return 'Wardrobe camera '..camera..' ('..origin..')'..'; '..model.afWardrobeFacingMode
        end
    end
    -- Guarded fallback for Forever builds without a usable native camera.
    Call(model,'RefreshCamera')
    Call(model,'SetCamDistanceScale',0.72)
    Call(model,'SetPortraitZoom',0.45)
    ApplyFacingAfterCamera(model)
    ApplyWeaponFraming(model,pose)
    entry.previewFacingMode=model.afWardrobeFacingMode
    entry.previewFacingDegrees=model.afWardrobeFinalFacing and math.deg(model.afWardrobeFinalFacing)
    return 'Camera fallback ('..tostring(origin)..'); '..model.afWardrobeFacingMode
end
local function SetupWardrobeModel(model,weaponOnly)
    -- Armor has the dark mannequin; weapons use the native standalone item
    -- renderer, with no unit dressed on the model (and no mannequin limbs).
    Call(model,'SetAutoDress',false)
    Call(model,'SetUseTransmogSkin',not weaponOnly)
    model.afWardrobeWeaponOnly=weaponOnly and true or false
    Call(model,'SetUseTransmogChoices',true)
    Call(model,'SetObeyHideInTransmogFlag',true)
    Call(model,'SetDoBlend',false)
    if not model.afCameraCallbackInstalled and type(model.SetScript)=='function' then
        -- Native wardrobe re-applies camera when models finish loading.
        local ok=pcall(model.SetScript,model,'OnModelLoaded',function(self)
            local id=self.afWardrobeCameraID
            if id and type(Model_ApplyUICamera)=='function' then
                local ok=pcall(Model_ApplyUICamera,self,id)
                self.afWardrobeCameraApplied=ok
            end
            ApplyFacingAfterCamera(self)
            ApplyWeaponFraming(self,{scale=self.afWardrobeUserScale or 1})
        end)
        model.afCameraCallbackInstalled=ok
    end
end
local function LoadDressedAppearance(model,entry,pose,animate)
    if not model or not entry or entry.category~='transmog' then return false,'Not a dress-up model' end
    if type(model.SetUnit)~='function' or type(model.TryOn)~='function' then
        return false,'DressUpModel missing SetUnit or TryOn'
    end
    if not entry.sourceID and not entry.itemID then return false,'No resolved item/source ID' end
    -- Clear the prior entry's camera before SetUnit can reload its model.
    model.afWardrobeCameraID=nil
    model.afWardrobeEntry=entry
    model.afWardrobeFacingOffset=tonumber(pose.wardrobeFacingOffset) or 0
    model.afWardrobeCameraApplied=false
    model.afWardrobeUserScale=tonumber(pose.scale) or 1
    SetupWardrobeModel(model,false)
    entry.previewRenderPath='ARMOR_MANNEQUIN_TRYON'
    local unitOK,unitResult=pcall(model.SetUnit,model,'player',false)
    if not unitOK or unitResult==false then return false,'Unable to initialize character model' end
    -- Reset the mannequin so reused model frames do not retain the previous item.
    if type(model.Undress)=='function' then pcall(model.Undress,model) end
    local candidates,used={},{}
    local function add(v)
        if v~=nil and not used[tostring(v)] then
            candidates[#candidates+1]=v;used[tostring(v)]=true
        end
    end
    add(tonumber(entry.sourceID))
    -- Some sources are only usable by certain classes. Try other sources of
    -- the same visual before falling back to an ordinary item hyperlink.
    if type(entry.sourceIDs)=='table' then
        for i=1,math.min(#entry.sourceIDs,6) do add(tonumber(entry.sourceIDs[i])) end
    end
    if tonumber(entry.itemID) then add('item:'..tostring(entry.itemID)) end
    local reason='No usable appearance source'
    for _,candidate in ipairs(candidates) do
        local ok,why=DressTryOn(model,candidate)
        if ok then
            local cameraStatus=ApplyWardrobeCamera(model,entry,pose)
            -- Camera framing AND camera-facing are now applied as one operation.
            -- In particular, do not restore the legacy 45-degree creature pose.
            Call(model,'SetModelScale',pose.scale or 1)
            Call(model,'SetPaused',not animate and pose.paused or false)
            return true,why..' | '..cameraStatus
        end
        reason=why
    end
    return false,reason
end

-- Weapons MUST use the wardrobe's standalone item renderer. In particular,
-- do not initialize SetUnit('player') or use TryOn(), as that creates the arms,
-- torso and legs seen in the 0.4.4.1.5 weapon screenshot. Reuse a DIFFERENT
-- DressUpModel than armor, so model pooling never leaks the previous mannequin.
local function LoadWeaponAppearance(model,entry,pose,animate)
    if not model or not entry or entry.category~='transmog' then return false,'Not a transmog weapon' end
    if type(model.SetItemAppearance)~='function' and type(model.SetItem)~='function' then
        return false,'Standalone item APIs unavailable'
    end
    pose=pose or {}
    model.afWardrobeCameraID=nil
    model.afWardrobeEntry=entry
    model.afWardrobeFacingOffset=tonumber(pose.wardrobeFacingOffset) or 0
    model.afWardrobeCameraApplied=false
    model.afWardrobeUserScale=tonumber(pose.scale) or 1
    SetupWardrobeModel(model,true)
    -- Starting clean is essential when the pooled frame previously showed
    -- a different weapon. ClearModel is a guarded native method.
    Call(model,'ClearModel')
    local reason='No supported weapon visual or item ID'
    local visualID=tonumber(entry.id)
    local ok,result
    if visualID and type(model.SetItemAppearance)=='function' then
        ok,result=pcall(model.SetItemAppearance,model,visualID)
        if ok and result~=false then
            entry.previewRenderPath='WEAPON_STANDALONE_APPEARANCE'
            local cameraStatus=ApplyWardrobeCamera(model,entry,pose)
            Call(model,'SetPaused',not animate and pose.paused or false)
            return true,'Standalone weapon appearance '..visualID..' | '..cameraStatus
        end
        reason=ok and 'SetItemAppearance refused visual '..visualID or tostring(result)
    end
    local itemID=tonumber(entry.itemID)
    if itemID and type(model.SetItem)=='function' then
        Call(model,'ClearModel')
        ok,result=pcall(model.SetItem,model,itemID)
        if ok and result~=false then
            entry.previewRenderPath='WEAPON_STANDALONE_ITEM'
            local cameraStatus=ApplyWardrobeCamera(model,entry,pose)
            Call(model,'SetPaused',not animate and pose.paused or false)
            return true,'Standalone weapon item '..itemID..' | '..cameraStatus
        end
        reason=ok and 'SetItem refused item '..itemID or tostring(result)
    end
    entry.previewRenderPath='WEAPON_ICON_FALLBACK'
    return false,reason
end
local function LoadTransmogPreview(model,entry,pose,animate)
    local weapon,origin=IsWeaponTransmog(entry)
    entry.previewTypeSource=origin
    if weapon then return LoadWeaponAppearance(model,entry,pose,animate) end
    return LoadDressedAppearance(model,entry,pose,animate)
end

local function EntryDiagnostics(entry)
    if not entry then return 'No collection selected' end
    local rec=AF:CollectionDiscovery(entry.category,entry.id)
    local savedSources=type(rec)=='table' and rec.sources or nil
    local savedCount=0
    if type(savedSources)=='table' then
        for _,source in pairs(savedSources) do
            if type(source)=='table' then savedCount=savedCount+1 end
        end
    end
    local recent=rec and savedSources and rec.lastSourceKey and savedSources[rec.lastSourceKey]
    local lines={PoseSummary(entry.category,entry.id,entry),
        'Name: '..tostring(entry.name),
        'Icon: '..tostring(entry.icon),
        'Owned: '..tostring(entry.owned)..' | Personally observed: '..tostring(rec~=nil),
        'Saved observation sources: '..tostring(savedCount)..' | Last vendor: '..tostring(recent and recent.npcName),
        'Last observed item: '..tostring(recent and recent.itemID)..' | Map: '..tostring(recent and recent.mapID),
        'Source type: '..tostring(entry.sourceType)..' | Client hidden: '..tostring(entry.clientHidden),
        'Client source: '..tostring(entry.source),
        'Appearance sources: '..tostring(entry.sourceCount)..' | Checked: '..tostring(entry.sourceChecked),
        'Source ID: '..tostring(entry.sourceID)..' | Item ID: '..tostring(entry.itemID),
        'Resolution: '..tostring(entry.resolutionStatus or 'Not applicable'),
        '3D preview: '..tostring(entry.previewStatus or 'Not attempted; hover with 3D ON'),
        'Preview path: '..tostring(entry.previewRenderPath)..' | classified by: '..tostring(entry.previewTypeSource),
        'Wardrobe camera: '..tostring(entry.previewCameraID)..' | source: '..tostring(entry.previewCameraOrigin),
        'Preview facing: '..tostring(entry.previewFacingDegrees)..' deg | mode: '..tostring(entry.previewFacingMode),
        'Weapon preview scale: '..tostring(entry.previewWeaponScale or 'n/a'),
        'Name origin: '..tostring(entry.nameOrigin)..' | Item data pending: '..tostring(entry.needsItemData),
        'Mount source status: '..tostring(entry.availabilityStatus or 'Not applicable')}
    if type(entry.sourceIDs)=='table' and #entry.sourceIDs>0 then
        local ids={}
        for i=1,math.min(#entry.sourceIDs,10) do ids[#ids+1]=tostring(entry.sourceIDs[i]) end
        lines[#lines+1]='Source IDs (first 10): '..table.concat(ids,', ')
    end
    return table.concat(lines,'\n')
end

function UI:OpenCollectionModelLab(entry)
    if not entry then return end
    if entry.category~='transmog' and not entry.displayID
        and not (entry.category=='pets' and entry.creatureID) then
        AF.Print('No confirmed display ID for this collectible; use the native icon.')
        return
    end
    local lab=self.collectionModelLab
    if not lab then
        lab=UI:NewFrame('Frame',UIParent,'AzerothFoundryCollectionModelLab')
        self.collectionModelLab=lab
        lab:SetSize(400,490)
        lab:SetPoint('CENTER',UIParent,'CENTER',220,0)
        lab:SetFrameStrata('DIALOG');lab:SetToplevel(true)
        lab:EnableMouse(true);lab:SetMovable(true);lab:SetClampedToScreen(true)
        UI:Background(lab,P.leather,true)
        local top=UI:NewFrame('Frame',lab)
        top:SetPoint('TOPLEFT',6,-7);top:SetPoint('TOPRIGHT',-6,-7);top:SetHeight(40)
        top:EnableMouse(true);top:RegisterForDrag('LeftButton')
        top:SetScript('OnDragStart',function() lab:StartMoving() end)
        top:SetScript('OnDragStop',function() lab:StopMovingOrSizing() end)
        local heading=Label(top,'Collection Model Laboratory','title',P.pale)
        heading:SetPoint('LEFT',12,0);heading:SetSize(300,26)
        local close=CreateFrame('Button',nil,top,'UIPanelCloseButton')
        close:SetPoint('RIGHT',-7,0);close:SetSize(27,27)
        close:SetScript('OnClick',function() lab:Hide() end)
        local viewport=UI:NewFrame('Frame',lab)
        viewport:SetPoint('TOPLEFT',14,-49);viewport:SetPoint('TOPRIGHT',-14,-49)
        viewport:SetHeight(238)
        UI:Background(viewport,P.dark,true)
        lab.viewport=viewport
        local modelOK,model=pcall(CreateFrame,'PlayerModel',nil,viewport)
        if modelOK and model then
            model:SetAllPoints(viewport)
            model:EnableMouse(false)
            lab.model=model
            model:Hide()
        else
            lab.model=nil
        end
        -- Armor/weapons require a dress-up mannequin. PlayerModel:SetDisplayInfo
        -- only understands creature models, so it cannot preview a transmog ID.
        local dressedOK,dressed=pcall(CreateFrame,'DressUpModel',nil,viewport)
        if dressedOK and dressed then
            dressed:SetAllPoints(viewport)
            dressed:EnableMouse(false)
            dressed:Hide()
            lab.dressModel=dressed
        end
        -- A dedicated weapon-only preview avoids mannequin leftovers even
        -- after inspecting armor in the same laboratory session.
        local weaponOK,weaponModel=pcall(CreateFrame,'DressUpModel',nil,viewport)
        if weaponOK and weaponModel then
            weaponModel:SetAllPoints(viewport)
            weaponModel:EnableMouse(false)
            weaponModel:Hide()
            lab.weaponModel=weaponModel
        end
        local status=Label(lab,'No model selected.','small',P.pale)
        status:SetPoint('TOPLEFT',16,-296);status:SetPoint('TOPRIGHT',-16,-296)
        status:SetHeight(48);lab.status=status
        local controls={}
        local specs={{'Turn left',-15,0},{'Turn right',15,0},{'Smaller',0,-0.1},{'Larger',0,0.1}}
        for i,spec in ipairs(specs) do
            local b=UI:Button(lab,spec[1],function()
                if not lab.entry then return end
                local p=AF:CollectionModelPose(lab.entry.category,lab.entry.id)
                if lab.entry.category=='transmog' then
                    p.wardrobeFacingOffset=math.max(-180,math.min(180,
                        (tonumber(p.wardrobeFacingOffset) or 0)+spec[2]))
                else
                    p.facing=(p.facing+spec[2])%360
                end
                p.scale=math.max(0.35,math.min(2.5,p.scale+spec[3]))
                UI:RefreshCollectionModelLab()
            end)
            b:SetSize(88,26)
            b:SetPoint('TOPLEFT',16+(i-1)*93,-352)
            controls[i]=b
        end
        local pause=UI:Button(lab,'Pause / Resume',function()
            local e=lab.entry;if not e then return end
            local p=AF:CollectionModelPose(e.category,e.id)
            p.paused=not p.paused
            UI:RefreshCollectionModelLab()
        end)
        pause:SetSize(115,27);pause:SetPoint('BOTTOMLEFT',16,13)
        local snap=UI:Button(lab,'Manual screenshot',function()
            if not lab.entry then return end
            AF.Print('Screenshot will capture the WHOLE game screen, not an image file usable as an addon texture.')
            if type(Screenshot)=='function' then Screenshot() else AF.Print('Screenshot() not available.') end
        end)
        snap:SetSize(141,27);snap:SetPoint('LEFT',pause,'RIGHT',9,0)
        local reset=UI:Button(lab,'Reset pose',function()
            local e=lab.entry;if not e then return end
            local p=AF:CollectionModelPose(e.category,e.id)
            p.facing=45;p.wardrobeFacingOffset=0;p.scale=1;p.paused=true
            UI:RefreshCollectionModelLab()
        end)
        reset:SetSize(97,27);reset:SetPoint('LEFT',snap,'RIGHT',8,0)
        -- A successful SetDisplayInfo call is not proof the client has a usable asset.
        -- The Forever client can show a checkerboard placeholder. Allow the tester
        -- to opt this specific collectible out of live model cards permanently.
        local fallback=UI:Button(lab,'Use icon on cards',function()
            if not lab.entry then return end
            local e=lab.entry
            local pose=AF:CollectionModelPose(e.category,e.id)
            pose.iconOnly=not pose.iconOnly
            UI:RefreshCollectionModelLab()
            local page=UI.pageViews and UI.pageViews.Collections
            if page and page.Refresh then page:Refresh() end
        end)
        fallback:SetSize(178,27);fallback:SetPoint('BOTTOMLEFT',16,60)
        lab.fallbackButton=fallback
        local caution=Label(lab,'If the model is a blue checkerboard, choose Use icon on cards. This does not affect ownership or discovery.','small',P.pale)
        caution:SetPoint('BOTTOMLEFT',205,57);caution:SetSize(180,43)
        if UISpecialFrames then table.insert(UISpecialFrames,'AzerothFoundryCollectionModelLab') end
        lab:Hide()
    end
    lab.entry=entry
    lab:Show();lab:Raise()
    self:RefreshCollectionModelLab()
end

function UI:RefreshCollectionModelLab()
    local lab=self.collectionModelLab
    if not lab or not lab.entry then return end
    local e=lab.entry
    local p=AF:CollectionModelPose(e.category,e.id)
    local m=lab.model
    local dressed=lab.dressModel
    local weapon=lab.weaponModel
    if m then m:Hide() end
    if dressed then dressed:Hide() end
    if weapon then weapon:Hide() end
    local ok,description
    if e.category=='transmog' then
        local isWeapon=IsWeaponTransmog(e)
        local viewer=isWeapon and weapon or dressed
        -- The weapon frame never invokes SetUnit, unlike the armor mannequin.
        if viewer then viewer:Show() end
        ok,description=LoadTransmogPreview(viewer,e,p,false)
        e.previewStatus=description
        if not ok and viewer then viewer:Hide() end
    else
        if m and tonumber(e.displayID) and type(m.SetDisplayInfo)=='function' then
            local accepted,result=pcall(m.SetDisplayInfo,m,e.displayID)
            ok=accepted and result~=false
        end
        if not ok and m and e.category=='pets' and tonumber(e.creatureID)
            and type(m.SetCreature)=='function' then
            local accepted,result=pcall(m.SetCreature,m,e.creatureID)
            ok=accepted and result~=false
        end
        if ok then
            Call(m,'SetFacing',math.rad(p.facing))
            Call(m,'SetModelScale',p.scale)
            Call(m,'SetPaused',p.paused)
            m:Show()
        end
        description=ok and 'API accepted display ID; verify visually' or 'Creature model unavailable'
    end
    lab.status:SetText(PoseSummary(e.category,e.id,e)..'\nModel: '..tostring(description))
    if lab.fallbackButton and lab.fallbackButton.label then
        lab.fallbackButton.label:SetText(p.iconOnly and 'Retry 3D on cards' or 'Use icon on cards')
    end
end

function UI:BuildCollections(page)
    -- Build only on first visit. All high-risk APIs run in guarded callbacks.
    -- Category selection is now in the nested Collections sidebar tree.
    local filters=CreateFrame('Frame',nil,page)
    filters:SetPoint('TOPLEFT',12,-10);filters:SetPoint('TOPRIGHT',-12,-10)
    filters:SetHeight(36)
    -- Explicit, spoiler-safe selection. Cycling used to force the player to
    -- reveal the entire catalog just to return to My Discoveries.
    local visibilityMenu
    local visibility=CollectionButton(filters,'My Discoveries  v',function()
        if visibilityMenu then
            visibilityMenu:SetShown(not visibilityMenu:IsShown())
            if visibilityMenu:IsShown() then
                if page.slotMenu then page.slotMenu:Hide() end
                if page.classMenu then page.classMenu:Hide() end
                visibilityMenu:Raise()
            end
        end
    end)
    visibility:SetSize(189,28);visibility:SetPoint('LEFT',filters,'LEFT',0,0)
    visibilityMenu=Card(page)
    visibilityMenu:SetFrameStrata('DIALOG')
    visibilityMenu:SetFrameLevel(math.max(30,(page:GetFrameLevel() or 1)+25))
    visibilityMenu:SetSize(189,94)
    visibilityMenu:SetPoint('TOPLEFT',visibility,'BOTTOMLEFT',0,-2)
    visibilityMenu:Hide()
    page.visibilityMenu=visibilityMenu
    for i,opt in ipairs({
        {'discovered','My Discoveries'},
        {'collected','Collected Only'},
        {'all','Reveal All (spoilers)'}
    }) do
        local choice=CollectionButton(visibilityMenu,opt[2],function()
            visibilityMenu:Hide()
            local settings=AF.db.collections.settings
            if opt[1]=='all' and not settings.revealAll then
                page:AskReveal() -- requires the existing typed confirmation
                return
            end
            settings.visibility=opt[1]=='all' and 'all' or opt[1]
            settings.revealAll=opt[1]=='all'
            page.selected=nil;page.pageNumber=1;page:Refresh()
        end)
        choice:SetPoint('TOPLEFT',6,-6-(i-1)*29)
        choice:SetPoint('TOPRIGHT',-6,-6-(i-1)*29)
        choice:SetHeight(26)
    end
    page:HookScript('OnHide',function() visibilityMenu:Hide();if page.slotMenu then page.slotMenu:Hide() end end)
    local search=UI:Input(filters,157)
    search:SetPoint('LEFT',visibility,'RIGHT',12,0)
    search:SetScript('OnTextChanged',function() page.pageNumber=1;page.selected=nil;page:Refresh() end)
    -- The gallery/details split is a LAYOUT preference only. Nothing about
    -- collectible ownership, discoveries, source data or model poses changes.
    local left=Card(page)
    local right=Card(page)
    local detailWidth=tonumber(AF.db.collections.settings.detailPanelWidth) or 272
    local function SetDetailWidth(width)
        local available=tonumber(page:GetWidth()) or 0
        -- Keep a usable gallery as well as a readable details/3D pane.
        local maxWidth=available>0 and math.max(255,available-410) or 620
        detailWidth=math.floor(math.max(255,math.min(maxWidth,tonumber(width) or 272))+0.5)
        left:ClearAllPoints()
        left:SetPoint('TOPLEFT',page,'TOPLEFT',12,-51)
        left:SetPoint('BOTTOMRIGHT',page,'BOTTOMRIGHT',-(detailWidth+19),61)
        right:ClearAllPoints()
        right:SetPoint('TOPLEFT',left,'TOPRIGHT',8,0)
        right:SetPoint('BOTTOMRIGHT',page,'BOTTOMRIGHT',-11,61)
    end
    SetDetailWidth(detailWidth)
    -- Page controls belong to the gallery, not the global Collections toolbar.
    -- Their anchors follow the gallery as the details divider moves.
    local galleryFooter=CreateFrame('Frame',nil,left)
    galleryFooter:SetPoint('BOTTOMLEFT',left,'BOTTOMLEFT',12,11)
    galleryFooter:SetPoint('BOTTOMRIGHT',left,'BOTTOMRIGHT',-12,11)
    galleryFooter:SetHeight(27)
    local prev=CollectionButton(galleryFooter,'<',function()
        page.pageNumber=math.max(1,(page.pageNumber or 1)-1)
        page:Refresh()
    end)
    prev:SetSize(29,24)
    prev:SetPoint('RIGHT',galleryFooter,'RIGHT',-100,0)
    local nextB=CollectionButton(galleryFooter,'>',function()
        page.pageNumber=(page.pageNumber or 1)+1
        page:Refresh()
    end)
    nextB:SetSize(29,24)
    nextB:SetPoint('RIGHT',galleryFooter,'RIGHT',0,0)
    local pages=Label(galleryFooter,'1/1','small',P.ink)
    pages:SetJustifyH('CENTER')
    pages:SetSize(66,22)
    pages:SetPoint('RIGHT',nextB,'LEFT',-3,0)
    local cardSizeTitle=Label(galleryFooter,'Card size','small',P.ink)
    cardSizeTitle:SetSize(70,20)
    cardSizeTitle:SetPoint('LEFT',galleryFooter,'LEFT',0,0)
    -- A subtle grab handle placed IN the gutter, not on either card. Three
    -- vertical dots at the middle indicate the movable inner-frame divider.
    local splitter=CreateFrame('Frame',nil,page)
    splitter:SetPoint('TOPLEFT',left,'TOPRIGHT',-5,0)
    splitter:SetPoint('BOTTOMRIGHT',left,'BOTTOMRIGHT',13,0)
    splitter:EnableMouse(true)
    splitter:SetFrameLevel(math.max(left:GetFrameLevel(),right:GetFrameLevel())+7)
    local grip=splitter:CreateTexture(nil,'ARTWORK')
    grip:SetSize(10,40)
    grip:SetPoint('CENTER',splitter,'CENTER',0,0)
    grip:SetColorTexture(0.35,0.23,0.10,0.20)
    UI:StyleResizeGrip(splitter,"OVERLAY")
    splitter:SetScript('OnEnter',function(self)
        grip:SetColorTexture(0.40,0.25,0.11,0.42)
        if GameTooltip then
            GameTooltip:SetOwner(self,'ANCHOR_CURSOR')
            GameTooltip:AddLine('Resize Collections panels')
            GameTooltip:AddLine('Drag left or right to resize the gallery and details. The width is saved.',1,1,1,true)
            GameTooltip:Show()
        end
    end)
    splitter:SetScript('OnLeave',function()
        grip:SetColorTexture(0.35,0.23,0.10,0.20)
        if GameTooltip and GameTooltip:IsOwned(splitter) then GameTooltip:Hide() end
    end)
    local dragStartX,dragStartWidth
    local function EndSplitDrag()
        if not dragStartX then return end
        dragStartX,dragStartWidth=nil,nil
        page.resizingCollectionPanels=nil
        AF.db.collections.settings.detailPanelWidth=detailWidth
        if page.Refresh then page:Refresh() end
    end
    splitter:SetScript('OnMouseDown',function(_,button)
        if button~='LeftButton' or type(GetCursorPosition)~='function' then return end
        dragStartX=GetCursorPosition()
        dragStartWidth=detailWidth
        page.resizingCollectionPanels=true
        if GameTooltip then GameTooltip:Hide() end
    end)
    splitter:SetScript('OnMouseUp',function(_,button)
        if button=='LeftButton' then EndSplitDrag() end
    end)
    splitter:SetScript('OnUpdate',function()
        if not dragStartX or type(GetCursorPosition)~='function' then return end
        if type(IsMouseButtonDown)=='function' and not IsMouseButtonDown('LeftButton') then
            EndSplitDrag();return
        end
        local x=GetCursorPosition()
        if type(x)~='number' then return end
        local scale=math.max(.01,page:GetEffectiveScale() or 1)
        local nextWidth=dragStartWidth-(x-dragStartX)/scale
        if math.abs(nextWidth-detailWidth)>1 then SetDetailWidth(nextWidth) end
    end)
    page:HookScript('OnHide',function() EndSplitDrag() end)
    page:HookScript('OnSizeChanged',function() SetDetailWidth(detailWidth) end)
    -- Recycled, viewport-sized cards. Unlike the initial nine-card 3x3 test,
    -- this uses the available gallery width without allocating models for
    -- off-screen cards. The pool is fixed and only pages through native data.
    local MAX_CARDS=60
    page.experimentalCardModels=false -- opt-in single-model hover, unchanged
    page.allModelCards=false -- opt-in current-page STRESS TEST; never persist
    page.allModelAttempts=0
    page.allModelShown=0
    local allModelSlots={} -- lazy, bounded pool indexed by visible card position
    local cardFrames={}
    local hoverModel -- One pooled creature model, for mounts/companions.
    local hoverDress -- One pooled dress-up mannequin for armor.
    local hoverWeapon -- One pooled standalone item frame for weapons.
    local hoveredCard
    local function HideHoverModel()
        if hoverModel then hoverModel:Hide() end
        if hoverDress then hoverDress:Hide() end
        if hoverWeapon then hoverWeapon:Hide() end
        if hoveredCard and hoveredCard.entry then hoveredCard.icon:Show() end
        hoveredCard=nil
    end
    local function PlaceHover(model,card)
        model:SetParent(card)
        model:ClearAllPoints()
        model:SetPoint('TOPLEFT',card.backdrop,'TOPLEFT',0,0)
        model:SetPoint('BOTTOMRIGHT',card.backdrop,'BOTTOMRIGHT',0,0)
    end
    local function ShowHoverModel(card)
        if page.allModelCards then
            -- Display All owns the card's model; avoid a second competing hover frame.
            if card and card.allModel then Call(card.allModel,'SetPaused',false) end
            return
        end
        HideHoverModel()
        if not page.experimentalCardModels or not card or not card.entry or card.mystery then return end
        local e=card.entry
        local pose=AF:CollectionModelPose(e.category,e.id)
        if pose.iconOnly then return end
        local model,ok,why
        if e.category=='transmog' then
            -- Weapon visuals use a separate standalone item frame; armor alone
            -- uses the dressed mannequin. Both are pooled, one visible at once.
            local weapon=IsWeaponTransmog(e)
            if weapon then
                if not hoverWeapon then
                    local success,m=pcall(CreateFrame,'DressUpModel',nil,card)
                    if not success or not m then
                        e.previewStatus='WEAPON_FRAME_UNAVAILABLE';return
                    end
                    hoverWeapon=m;hoverWeapon:EnableMouse(false);hoverWeapon:Hide()
                end
                model=hoverWeapon
            else
                if not hoverDress then
                    local success,m=pcall(CreateFrame,'DressUpModel',nil,card)
                    if not success or not m then
                        e.previewStatus='DRESSUP_FRAME_UNAVAILABLE';return
                    end
                    hoverDress=m;hoverDress:EnableMouse(false);hoverDress:Hide()
                end
                model=hoverDress
            end
            PlaceHover(model,card)
            model:Show()
            ok,why=LoadTransmogPreview(model,e,pose,true)
            e.previewStatus=why
            if not ok then model:Hide() end
        else
            if (type(e.displayID)~='number' or e.displayID<=0)
                and not (e.category=='pets' and tonumber(e.creatureID)) then return end
            if not hoverModel then
                local success,m=pcall(CreateFrame,'PlayerModel',nil,card)
                if not success or not m then return end
                hoverModel=m;hoverModel:EnableMouse(false);hoverModel:Hide()
            end
            model=hoverModel
            PlaceHover(model,card)
            if tonumber(e.displayID) and type(model.SetDisplayInfo)=='function' then
                local accepted,result=pcall(model.SetDisplayInfo,model,e.displayID)
                ok=accepted and result~=false
            end
            if not ok and e.category=='pets' and tonumber(e.creatureID)
                and type(model.SetCreature)=='function' then
                local accepted,result=pcall(model.SetCreature,model,e.creatureID)
                ok=accepted and result~=false
            end
            if ok then
                Call(model,'SetFacing',math.rad(pose.facing))
                Call(model,'SetModelScale',pose.scale)
                Call(model,'SetPaused',false)
            end
        end
        if not ok then return end
        model:Show()
        hoveredCard=card
        card.icon:Hide()
    end
    -- STRESS TEST: at most one paused 3D model per visible card on the active
    -- gallery page. Frames are created lazily and reused on page changes; never
    -- allocate a model for entries outside the visible page or an unknown card.
    -- Each slot may own creature, armor and weapon variants to avoid stale
    -- mannequin geometry when changing categories.
    local gridCols,gridRows,gridSize=5,3,15
    local function HideAllCardModels()
        for _,card in ipairs(cardFrames) do
            card.allModel=nil
            if card.icon then card.icon:Show() end
        end
        for _,slot in ipairs(allModelSlots) do
            for _,model in pairs(slot) do
                if model then
                    Call(model,'SetPaused',true)
                    model:Hide()
                end
            end
        end
        page.allModelAttempts=0
        page.allModelShown=0
    end
    local function GetAllCardModel(index,kind,card)
        local slot=allModelSlots[index]
        if not slot then slot={}; allModelSlots[index]=slot end
        local model=slot[kind]
        if not model then
            local frameType=kind=='creature' and 'PlayerModel' or 'DressUpModel'
            local ok,newModel=pcall(CreateFrame,frameType,nil,card)
            if not ok or not newModel then return nil end
            model=newModel; slot[kind]=model
            model:EnableMouse(false)
            model:Hide()
        end
        PlaceHover(model,card)
        return model
    end
    local function RefreshAllCardModels()
        if not page.allModelCards then return end
        -- Restrict all allocations to the already-paginated gallery, MAX_CARDS.
        for i=1,math.min(gridSize or 0,MAX_CARDS) do
            local card=cardFrames[i]
            local entry=card and card.entry
            if card and card:IsShown() and entry and not entry.mystery then
                local pose=AF:CollectionModelPose(entry.category,entry.id)
                if not pose.iconOnly then
                    local kind
                    if entry.category=='transmog' then
                        kind=IsWeaponTransmog(entry) and 'weapon' or 'armor'
                    elseif (entry.category=='mounts' or entry.category=='pets')
                        and (type(entry.displayID)=='number' and entry.displayID>0
                            or entry.category=='pets' and tonumber(entry.creatureID)) then
                        kind='creature'                     end
                    if kind then
                        page.allModelAttempts=page.allModelAttempts+1
                        local model=GetAllCardModel(i,kind,card)
                        if model then
                            local ok
                            if kind=='creature' then
                                if tonumber(entry.displayID) and type(model.SetDisplayInfo)=='function' then
                                    local setOK,result=pcall(model.SetDisplayInfo,model,entry.displayID)
                                    ok=setOK and result~=false
                                end
                                if not ok and entry.category=='pets' and tonumber(entry.creatureID)
                                    and type(model.SetCreature)=='function' then
                                    local setOK,result=pcall(model.SetCreature,model,entry.creatureID)
                                    ok=setOK and result~=false
                                end
                                if ok then
                                    Call(model,'SetFacing',math.rad(pose.facing))
                                    Call(model,'SetModelScale',pose.scale)
                                end
                            else
                                -- The exact same tested armor/weapon loader as hover.
                                -- Only the animation state differs: paused until hover.
                                model:Show()
                                ok=LoadTransmogPreview(model,entry,pose,false)
                            end
                            if ok then
                                card.allModel=model
                                model:Show()
                                Call(model,'SetPaused',true)
                                card.icon:Hide()
                                page.allModelShown=page.allModelShown+1
                            else
                                model:Hide()
                                card.icon:Show()
                            end
                        end
                    end
                end
            end
        end
    end
    local matrix=CreateFrame('Frame',nil,left)
    matrix:SetPoint('TOPLEFT',11,-14);matrix:SetPoint('BOTTOMRIGHT',-11,45)
    local function Edge(parent,anchor,w,h)
        local t=parent:CreateTexture(nil,'OVERLAY')
        t:SetColorTexture(.44,.30,.13,.8)
        if anchor=='TOP' then t:SetPoint('TOPLEFT');t:SetPoint('TOPRIGHT');t:SetHeight(h)
        elseif anchor=='BOTTOM' then t:SetPoint('BOTTOMLEFT');t:SetPoint('BOTTOMRIGHT');t:SetHeight(h)
        elseif anchor=='LEFT' then t:SetPoint('TOPLEFT');t:SetPoint('BOTTOMLEFT');t:SetWidth(w)
        else t:SetPoint('TOPRIGHT');t:SetPoint('BOTTOMRIGHT');t:SetWidth(w) end
        return t
    end
    for i=1,MAX_CARDS do
        local b=CreateFrame('Button',nil,matrix)
        b:Hide()
        local bg=b:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints(b)
        bg:SetColorTexture(.31,.20,.10,.18)
        local backdrop=b:CreateTexture(nil,'BORDER');backdrop:SetPoint('TOPLEFT',4,-4)
        backdrop:SetPoint('TOPRIGHT',-4,-4)
        backdrop:SetColorTexture(.12,.085,.057,.96)
        b.backdrop=backdrop
        local icon=b:CreateTexture(nil,'ARTWORK');icon:SetPoint('TOP',0,-6)
        local name=Label(b,'','small',P.ink)
        name:SetJustifyH('CENTER')
        name:SetJustifyV('MIDDLE')
        name:SetPoint('BOTTOMLEFT',5,9);name:SetPoint('BOTTOMRIGHT',-5,9)
        name:SetHeight(31)
        -- A full-width underline replaces the easy-to-miss 8px ownership dot.
        -- Green = collected, amber = personally discovered, slate = catalog only.
        -- Keep it beneath the text and model, not on top of the collectible.
        local state=b:CreateTexture(nil,'OVERLAY')
        state:SetHeight(4)
        state:SetPoint('BOTTOMLEFT',6,4);state:SetPoint('BOTTOMRIGHT',-6,4)
        Edge(b,'TOP',0,1);Edge(b,'BOTTOM',0,1);Edge(b,'LEFT',1,0);Edge(b,'RIGHT',1,0)
        local selected=b:CreateTexture(nil,'OVERLAY')
        selected:SetPoint('TOPLEFT',2,-2);selected:SetPoint('BOTTOMRIGHT',-2,2)
        selected:SetColorTexture(1,.79,.33,.14)
        selected:Hide()
        b.selectedArt=selected
        b.icon=icon;b.name=name;b.state=state;b.afModel=nil
        local hover=b:CreateTexture(nil,'HIGHLIGHT');hover:SetAllPoints(b)
        hover:SetColorTexture(1,.75,.27,.16)
        b:SetScript('OnEnter',function(self)
            ShowHoverModel(self)
            if self.mystery and GameTooltip then
                GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
                GameTooltip:AddLine('Mystery card — tutorial placeholder',1,.82,.25)
                GameTooltip:AddLine('This is NOT a missing item or an uncollected class appearance. It illustrates how undiscovered collectibles will be handled.',1,1,1,true)
                GameTooltip:AddLine('Click for an explanation. No collectible or source is attached.',.78,.76,.70,true)
                GameTooltip:Show()
            end
            if self.entry and not self.mystery and GameTooltip then
                GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
                GameTooltip:AddLine(self.entry.name or 'Unknown')
                local observed=AF:CollectionDiscovery(self.entry.category,self.entry.id)
                local tooltipStatus=self.entry.owned and 'Collected'
                    or (observed and 'Discovered, not collected' or 'Full catalog reference — not discovered')
                GameTooltip:AddLine(tooltipStatus,
                    self.entry.owned and .25 or .90,self.entry.owned and .85 or .75,.30)
                local settings=AF.db and AF.db.collections and AF.db.collections.settings
                local mayShowSource=(settings and settings.revealAll) or self.entry.owned
                    or (observed and observed.lastSourceKey)
                if mayShowSource then
                    if self.entry.category=='mounts' then
                        GameTooltip:AddLine('Client acquisition: '..SourceTypeLabel(self.entry.sourceType),.85,.82,.71,true)
                        if settings and settings.revealAll and AF.GetCollectionSourceReference then
                            local ext=AF:GetCollectionSourceReference('mounts',self.entry.id)
                            if ext then GameTooltip:AddLine('External reference: '..tostring(ext.source or ext.label),.80,.80,.55,true) end
                        end
                        if HasSourceText(self.entry.source) then
                            GameTooltip:AddLine(self.entry.source,.86,.79,.62,true)
                        else
                            GameTooltip:AddLine('Exact source/location not supplied by client.',.68,.65,.61,true)
                        end
                        if self.entry.clientHidden then
                            GameTooltip:AddLine('Client-hidden; availability unverified.',1,.64,.3,true)
                        end
                    elseif self.entry.category=='pets' and HasSourceText(self.entry.source) then
                        GameTooltip:AddLine('Client source: '..self.entry.source,.86,.79,.62,true)
                    elseif self.entry.category=='transmog' then
                        local sourceInfo=self.entry.sourceItems and self.entry.sourceItems[1]
                        if sourceInfo then
                            GameTooltip:AddLine('Source item: '..tostring(sourceInfo.name or sourceInfo.itemID or 'Unknown'),.86,.79,.62,true)
                        end
                    end
                    if observed and observed.lastSourceKey and observed.sources then
                        local origin=observed.sources[observed.lastSourceKey]
                        if origin then GameTooltip:AddLine('Encountered at: '..tostring(origin.npcName or 'Unknown vendor'),.27,.85,.48,true) end
                    end
                end
                GameTooltip:AddLine('Click to inspect. Model availability varies by client.',.85,.82,.71,true)
                GameTooltip:Show()
            end
        end)
        b:SetScript('OnLeave',function(self)
            if page.allModelCards and self.allModel then Call(self.allModel,'SetPaused',true) end
            if hoveredCard==self then
                HideHoverModel()
                if self.entry then self.icon:Show() end
            end
            if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        b:SetScript('OnClick',function(self)
            if not self.entry then return end
            page.selected=self.entry
            page:ShowDetail(self.entry)
            -- Only update highlights rather than rebuilding the whole catalog.
            for _,c in ipairs(cardFrames) do
                c.selectedArt:SetShown(c.entry and
                    ((c.entry.mystery and c.entry==page.selected)
                    or (not c.entry.mystery and c.entry.id==page.selected.id and c.entry.category==page.selected.category)) or false)
            end
        end)
        cardFrames[i]=b
    end
    local emptyMessage=Label(matrix,'','small',P.ink)
    emptyMessage:SetJustifyH('CENTER')
    emptyMessage:SetPoint('TOPLEFT',20,-176)
    emptyMessage:SetPoint('TOPRIGHT',-20,-176)
    emptyMessage:SetHeight(82)
    emptyMessage:Hide()
    local function LayoutCards()
        local width,height=matrix:GetWidth(),matrix:GetHeight()
        if not width or width<240 then width=615 end
        if not height or height<130 then height=405 end
        local gap=8
        -- Saved preferred card size. Columns/rows derive from available space;
        -- this changes page size, not ownership, discoveries or data records.
        local size=math.max(88,math.min(180,tonumber(AF.db.collections.settings.cardSize) or 128))
        gridCols=math.max(3,math.min(10,math.floor((width+gap)/(size+gap))))
        local cardWidth=math.max(1,math.floor((width-gap*(gridCols-1))/gridCols))
        local cardHeight=math.max(112,math.floor((cardWidth+23)*1.25+0.5))
        gridRows=math.max(1,math.min(5,math.floor((height+gap)/(cardHeight+gap))))
        gridSize=math.min(MAX_CARDS,gridRows*gridCols)
        for i,b in ipairs(cardFrames) do
            b:ClearAllPoints()
            local row=math.floor((i-1)/gridCols);local col=(i-1)%gridCols
            b:SetSize(cardWidth,cardHeight)
            b:SetPoint('TOPLEFT',matrix,'TOPLEFT',col*(cardWidth+gap),-row*(cardHeight+gap))
            local previewSize=math.max(52,cardHeight-45)
            b.backdrop:SetHeight(previewSize+4)
            b.icon:ClearAllPoints()
            b.icon:SetPoint('CENTER',b.backdrop,'CENTER',0,0)
            local iconSize=math.max(42,math.min(previewSize-8,cardWidth-18))
            b.icon:SetSize(iconSize,iconSize)
        end
    end
    local cardSizeSlider=CreateFrame('Slider',nil,galleryFooter)
    cardSizeSlider:SetOrientation('HORIZONTAL')
    cardSizeSlider:SetSize(118,18)
    cardSizeSlider:SetPoint('LEFT',cardSizeTitle,'RIGHT',3,0)
    cardSizeSlider:SetMinMaxValues(88,180)
    cardSizeSlider:SetValueStep(4)
    if cardSizeSlider.SetObeyStepOnDrag then cardSizeSlider:SetObeyStepOnDrag(true) end
    local sliderTrack=cardSizeSlider:CreateTexture(nil,'BACKGROUND')
    sliderTrack:SetHeight(5)
    sliderTrack:SetPoint('LEFT',cardSizeSlider,'LEFT',0,0)
    sliderTrack:SetPoint('RIGHT',cardSizeSlider,'RIGHT',0,0)
    sliderTrack:SetColorTexture(.36,.22,.10,.85)
    local sliderThumb=cardSizeSlider:CreateTexture(nil,'OVERLAY')
    sliderThumb:SetSize(14,20)
    sliderThumb:SetTexture('Interface\\Buttons\\UI-SliderBar-Button-Horizontal')
    cardSizeSlider:SetThumbTexture(sliderThumb)
    local sizeValue=Label(galleryFooter,'','small',P.ink)
    sizeValue:SetSize(36,18)
    sizeValue:SetPoint('LEFT',cardSizeSlider,'RIGHT',5,0)
    cardSizeSlider:SetScript('OnValueChanged',function(self,value)
        value=math.max(88,math.min(180,math.floor((tonumber(value) or 128)/4+0.5)*4))
        AF.db.collections.settings.cardSize=value
        sizeValue:SetText(tostring(value))
        -- Fast, geometry-only preview during a drag; no catalog scans or model
        -- creation until the drag is finished.
        LayoutCards()
    end)
    cardSizeSlider:SetScript('OnMouseUp',function()
        page.pageNumber=1
        if page.Refresh then page:Refresh() end
    end)
    cardSizeSlider:SetValue(tonumber(AF.db.collections.settings.cardSize) or 128)
    local function RefreshLayout()
        LayoutCards()
        if page.Refresh then page:Refresh() end
    end
    matrix:SetScript('OnSizeChanged',function()
        -- Relayout existing cards while dragging; defer expensive catalog,
        -- appearance and model work until the mouse is released.
        if page.resizingCollectionPanels then LayoutCards()
        elseif page.Refresh then RefreshLayout() end
    end)
    LayoutCards()
    local head=Label(right,'Select a collection card','title',P.ink)
    head:SetPoint('TOPLEFT',14,-12);head:SetPoint('TOPRIGHT',-13,-12);head:SetHeight(35)
    -- Details-panel viewer is INDEPENDENT from the working gallery hover/model
    -- pools. One selected-item model at a time; never allocate for entire grid.
    local viewer=UI:NewFrame('Frame',right)
    viewer:SetPoint('TOPLEFT',right,'TOPLEFT',14,-53)
    viewer:SetPoint('TOPRIGHT',right,'TOPRIGHT',-14,-53)
    -- Start with a familiar size, then grow the model viewport as the player
    -- makes the details pane wider. Vertical space for the text and buttons is
    -- reserved in UpdateDetailViewerSize below.
    viewer:SetHeight(190)
    UI:Background(viewer,P.leather,true)
    local itemIcon=viewer:CreateTexture(nil,'ARTWORK');itemIcon:SetSize(78,78)
    itemIcon:SetPoint('CENTER',viewer,'CENTER',0,0);itemIcon:SetTexture(MYSTERY_ICON)
    local viewerModels={}
    local viewerSelected,viewerKind
    -- The mount-special control is independent of the model camera and pose.
    -- Changing the selected entry invalidates any pending idle-reset callback.
    local mountSpecialButton
    local mountSpecialSerial=0
    local viewAngle,viewZoom,viewPanX,viewPanY=0,1,0,0
    local viewerBaseFacing,viewerBaseScale=0,1
    local viewerBaseViewX,viewerBaseViewY
    local viewerHelp=Label(right,'Left drag: rotate     Right drag: pan     Wheel: zoom','small',P.ink)
    -- This help row moves WITH the preview when the panel is resized.
    viewerHelp:SetPoint('TOPLEFT',viewer,'BOTTOMLEFT',1,-5)
    viewerHelp:SetPoint('TOPRIGHT',viewer,'BOTTOMRIGHT',-1,-5)
    viewerHelp:SetHeight(18);viewerHelp:SetJustifyH('CENTER')
    if viewerHelp.GetFont and viewerHelp.SetFont then
        local face=viewerHelp:GetFont()
        if face then viewerHelp:SetFont(face,10,'') end
    end
    -- Transparent input layer: handles both mouse buttons without interfering
    -- with model loading or Blizzard's model-camera callbacks.
    local modelInput=CreateFrame('Frame',nil,viewer)
    modelInput:SetAllPoints(viewer)
    modelInput:EnableMouse(true)
    modelInput:EnableMouseWheel(true)
    modelInput:SetFrameLevel(viewer:GetFrameLevel()+5)
    local function CurrentModel() return viewerKind and viewerModels[viewerKind] end
    local function ApplyView()
        local model=CurrentModel()
        if not model or not model:IsShown() then return end
        local facing=viewerBaseFacing
        if viewerKind~='creature' and type(model.afWardrobeFinalFacing)=='number' then
            facing=model.afWardrobeFinalFacing
        end
        Call(model,'SetFacing',facing+viewAngle)
        Call(model,'SetModelScale',viewerBaseScale*viewZoom)
        -- Shift the CAMERA VIEW in screen-space, NOT the model's world/XYZ
        -- position. SetPosition moved the model/pivot instead of panning the
        -- viewport. SetViewTranslation takes UI units and is available on
        -- Forever's Model / PlayerModel / DressUpModel API.
        if type(model.SetViewTranslation)=='function' and viewerBaseViewX then
            Call(model,'SetViewTranslation',viewerBaseViewX+viewPanX,viewerBaseViewY+viewPanY)
        end
    end
    local function CaptureViewerTranslation(model)
        -- Preserve a native wardrobe camera's initial view translation.
        local x,y=Call(model,'GetViewTranslation')
        viewerBaseViewX=type(x)=='number' and x or 0
        viewerBaseViewY=type(y)=='number' and y or 0
        model.afDetailBaseViewX=viewerBaseViewX
        model.afDetailBaseViewY=viewerBaseViewY
    end
    local function ResetView()
        viewAngle,viewZoom,viewPanX,viewPanY=0,1,0,0
        ApplyView()
    end
    -- One-shot mount animation clips freeze on their final pose. Do not make
    -- them wait for a fixed timer to return to idle: the actual clip duration
    -- varies between creature models. PlayerModel can notify us when it ends.
    local function FinishMountSpecial(model)
        local token=model.afMountSpecialToken
        if not token or token~=mountSpecialSerial
            or model~=CurrentModel() or not model:IsShown()
            or model.afMountSpecialEntry~=viewerSelected then return end
        -- Clear BEFORE SetAnimation(0); idle-related callbacks must not loop.
        model.afMountSpecialToken=nil
        model.afMountSpecialEntry=nil
        Call(model,'SetAnimation',0)
    end
    local function GetViewerModel(kind)
        if viewerModels[kind] then return viewerModels[kind] end
        local frameKind=(kind=='creature') and 'PlayerModel' or 'DressUpModel'
        local ok,model=pcall(CreateFrame,frameKind,nil,viewer)
        if not ok or not model then return nil end
        model:SetAllPoints(viewer)
        model:SetFrameLevel(viewer:GetFrameLevel()+2)
        model:EnableMouse(false)
        model:Hide()
        viewerModels[kind]=model
        if kind=='creature' then
            -- Returning to idle on OnAnimFinished eliminates the frozen gap
            -- left by the old 4-second reset. Register only once per pooled
            -- creature model; do not overwrite any Blizzard scripts.
            local hooked=false
            if type(model.HookScript)=='function' then
                local success,result=pcall(model.HookScript,model,'OnAnimFinished',FinishMountSpecial)
                hooked=success and result~=false
            end
            if not hooked and type(model.SetScript)=='function' then
                pcall(model.SetScript,model,'OnAnimFinished',FinishMountSpecial)
            end
        end
        -- SetupWardrobeModel's OnModelLoaded reinstalls Blizzard camera/facing;
        -- reapply our *temporary* user adjustments afterwards, not to saved poses.
        if type(model.HookScript)=='function' then
            pcall(model.HookScript,model,'OnModelLoaded',function(self)
                if self==CurrentModel() then
                    -- Blizzard's native wardrobe camera may change the
                    -- view translation during an asynchronous model load.
                    -- Capture that new origin before reapplying user panning.
                    if self.afDetailAwaitingView then
                        CaptureViewerTranslation(self)
                        self.afDetailAwaitingView=nil
                    end
                    ApplyView()
                end
            end)
        end
        return model
    end
    local function RefreshViewer(entry)
        mountSpecialSerial=mountSpecialSerial+1
        viewerSelected=entry
        if mountSpecialButton then mountSpecialButton:Hide() end
        for _,m in pairs(viewerModels) do
            m.afMountSpecialToken=nil
            m.afMountSpecialEntry=nil
            -- Pooled model frames must not pass the previous item's camera
            -- translation to the next item (especially wardrobe cameras).
            if type(m.SetViewTranslation)=='function' and m.afDetailBaseViewX then
                Call(m,'SetViewTranslation',m.afDetailBaseViewX,m.afDetailBaseViewY)
            end
            m.afDetailAwaitingView=nil
            m:Hide()
        end
        viewerKind=nil
        viewerBaseViewX,viewerBaseViewY=nil,nil
        itemIcon:SetTexture((entry and GoodTexture(entry.icon)) or MYSTERY_ICON)
        itemIcon:Show()
        ResetView()
        if not entry or entry.mystery then
            viewerHelp:SetText('Select a collectible to preview')
            return
        end
        local pose=AF:CollectionModelPose(entry.category,entry.id)
        if pose.iconOnly then
            viewerHelp:SetText('Icon-only preview; see Technical options for model tools')
            return
        end
        local kind
        if entry.category=='transmog' then
            kind=IsWeaponTransmog(entry) and 'weapon' or 'armor'
        elseif (entry.category=='mounts' or entry.category=='pets')
            and ((tonumber(entry.displayID) and tonumber(entry.displayID)>0)
                or (entry.category=='pets' and tonumber(entry.creatureID))) then
            kind='creature'         elseif entry.category=='toys' and tonumber(entry.id) and tonumber(entry.id)>0 then
            -- Toy entries are itemIDs. Many do not expose a displayable 3D
            -- object (some are spells/effects); use SetItem when supported and
            -- fall back to the icon otherwise. Never create a fake creature.
            kind='toy'
        end
        if not kind then
            viewerHelp:SetText('3D preview not available for this collectible')
            return
        end
        local model=GetViewerModel(kind)
        if not model then
            viewerHelp:SetText('Model frame not available in this client')
            return
        end
        viewerKind=kind
        model.afDetailAwaitingView=true
        -- Gallery 3D Display All already does this: the native DressUpModel
        -- must be visible BEFORE SetUnit / TryOn / camera initialization.
        -- Loading the right-hand model while hidden made armor (and some
        -- weapon appearances) return a false negative, even while the exact
        -- same entry was visibly rendering in the gallery.
        model:Show()
        viewerBaseFacing=math.rad(tonumber(pose.facing) or 45)
        viewerBaseScale=tonumber(pose.scale) or 1
        local ok,why
        if kind=='creature' then
            if tonumber(entry.displayID) and type(model.SetDisplayInfo)=='function' then
                local accepted,result=pcall(model.SetDisplayInfo,model,entry.displayID)
                ok=accepted and result~=false
            end
            if not ok and entry.category=='pets' and tonumber(entry.creatureID)
                and type(model.SetCreature)=='function' then
                local accepted,result=pcall(model.SetCreature,model,entry.creatureID)
                ok=accepted and result~=false
            end
            if ok then
                Call(model,'SetFacing',viewerBaseFacing)
                Call(model,'SetModelScale',viewerBaseScale)
                Call(model,'SetPaused',false)
            end
        elseif kind=='toy' then
            -- Use the existing item-model API, exactly as the standalone
            -- weapon viewer does. Toy use-effects are NOT model assets; the
            -- fallback icon is deliberate when this client cannot render one.
            Call(model,'ClearModel')
            if type(model.SetItem)=='function' then
                local accepted,result=pcall(model.SetItem,model,tonumber(entry.id))
                ok=accepted and result~=false
            end
            if ok then
                Call(model,'SetFacing',viewerBaseFacing)
                Call(model,'SetModelScale',viewerBaseScale)
                Call(model,'SetPaused',false)
                why='Toy item display (not its use-effect)'
            else
                why='No usable toy item model in this client'
            end
        else
            ok,why=LoadTransmogPreview(model,entry,pose,true)
            if kind=='weapon' then viewerBaseScale=viewerBaseScale*1.30 end
            if type(model.afWardrobeFinalFacing)=='number' then
                viewerBaseFacing=model.afWardrobeFinalFacing
            end
        end
        if not ok then
            entry.previewStatus=why or 'Detail model failed to load'
            model:Hide() -- keep the existing icon fallback for unsupported assets
            viewerKind=nil
            viewerHelp:SetText('Preview unavailable; the item icon is shown')
            return
        end
        model:Show()
        -- Capture the fully initialized camera even when loading has already
        -- fired OnModelLoaded synchronously. If it loads again asynchronously,
        -- OnModelLoaded captures the final camera's translation as well.
        CaptureViewerTranslation(model)
        itemIcon:Hide()
        ApplyView()
        if mountSpecialButton and entry.category=='mounts' and kind=='creature' then
            mountSpecialButton:Show()
        end
        if type(model.SetViewTranslation)=='function' then
            viewerHelp:SetText('Left drag: rotate     Right drag: pan view     Wheel: zoom')
        else
            viewerHelp:SetText('Left drag: rotate     Wheel: zoom     Pan unavailable')
        end
    end
    local downX,downY,dragButton
    modelInput:SetScript('OnMouseDown',function(_,button)
        if not CurrentModel() or type(GetCursorPosition)~='function' then return end
        if button~='LeftButton' and button~='RightButton' then return end
        dragButton=button
        downX,downY=GetCursorPosition()
    end)
    modelInput:SetScript('OnMouseUp',function() dragButton=nil end)
    modelInput:SetScript('OnHide',function() dragButton=nil end)
    modelInput:SetScript('OnUpdate',function()
        if not dragButton or not CurrentModel() or type(GetCursorPosition)~='function' then return end
        if type(IsMouseButtonDown)=='function' and not IsMouseButtonDown(dragButton) then
            dragButton=nil;return
        end
        local x,y=GetCursorPosition()
        if not x or not y or not downX or not downY then return end
        local scale=math.max(0.01,viewer:GetEffectiveScale() or 1)
        local dx,dy=(x-downX)/scale,(y-downY)/scale
        downX,downY=x,y
        if dragButton=='LeftButton' then
            viewAngle=viewAngle+dx*0.015
        else
            -- UI units rather than model/world coordinates. Dragging shifts
            -- the viewport's projected image; the model pivot stays fixed.
            local limitX=math.max(80,(viewer:GetWidth() or 220)*0.80)
            local limitY=math.max(65,(viewer:GetHeight() or 190)*0.80)
            viewPanX=math.max(-limitX,math.min(limitX,viewPanX+dx))
            viewPanY=math.max(-limitY,math.min(limitY,viewPanY+dy))
        end
        ApplyView()
    end)
    modelInput:SetScript('OnMouseWheel',function(_,delta)
        if not CurrentModel() then return end
        viewZoom=math.max(0.45,math.min(2.6,viewZoom*(delta>0 and 1.13 or (1/1.13))))
        ApplyView()
    end)
    -- Scroll native source text without disturbing bottom controls.
    local detailScroll=CreateFrame('ScrollFrame',nil,right)
    -- Follow the preview bottom, rather than the old fixed 190px viewport.
    -- Resizing the divider now grows the *height* of the 3D viewport without
    -- pushing the scroll area over the pinned bottom controls.
    detailScroll:SetPoint('TOPLEFT',viewer,'BOTTOMLEFT',0,-37)
    detailScroll:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-14,150)
    detailScroll:EnableMouseWheel(true)
    local detailBody=CreateFrame('Frame',nil,detailScroll)
    detailBody:SetSize(170,200)
    detailScroll:SetScrollChild(detailBody)
    -- Readable parchment contrast: standard ink for body text (not Blizzard's
    -- light/gold fonts), slightly larger than the gallery's small labels.
    local detail=Label(detailBody,'Select a card to see collection information.','normal',P.ink)
    if detail.GetFont and detail.SetFont then
        local face=detail:GetFont()
        if face then detail:SetFont(face,13,'') end
    end
    if type(detail.SetSpacing)=='function' then detail:SetSpacing(3) end
    detail:SetPoint('TOPLEFT',0,0);detail:SetPoint('TOPRIGHT',0,0)
    detail:SetHeight(190)
    -- A small, native-looking scroll indicator makes the below-the-fold source
    -- and diagnostic sections discoverable without reserving another column.
    local scrollTrack=right:CreateTexture(nil,'BORDER')
    scrollTrack:SetPoint('TOPRIGHT',viewer,'BOTTOMRIGHT',7,-37)
    scrollTrack:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-7,150)
    scrollTrack:SetWidth(3)
    scrollTrack:SetColorTexture(0.33,0.23,0.13,0.15)
    local scrollThumb=right:CreateTexture(nil,'ARTWORK')
    scrollThumb:SetWidth(3)
    scrollThumb:SetColorTexture(0.40,0.27,0.13,0.8)
    local function UpdateDetailScrollIndicator()
        local viewport=math.max(1,detailScroll:GetHeight() or 1)
        local content=math.max(viewport,detailBody:GetHeight() or viewport)
        local available=content-viewport
        if available<2 then scrollThumb:Hide();scrollTrack:Hide();return end
        scrollTrack:Show();scrollThumb:Show()
        local trackHeight=math.max(1,scrollTrack:GetHeight() or viewport)
        local thumbHeight=math.max(22,math.min(trackHeight,trackHeight*viewport/content))
        local fraction=math.max(0,math.min(1,(detailScroll:GetVerticalScroll() or 0)/available))
        scrollThumb:SetHeight(thumbHeight)
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint('TOP',scrollTrack,'TOP',0,-(trackHeight-thumbHeight)*fraction)
    end
    local function ResizeDetailText()
        -- WoW measures font strings against their current bounding rectangle.
        -- The previous fixed 190px height could make GetStringHeight return a
        -- clipped result, hiding all but the first detail line. Measure with a
        -- temporary tall area, then shrink the scroll child to the real height.
        local width=math.max(70,detailScroll:GetWidth() or 170)
        detailBody:SetWidth(width)
        detail:ClearAllPoints()
        detail:SetPoint('TOPLEFT',detailBody,'TOPLEFT',0,0)
        detail:SetWidth(width-8)
        detail:SetHeight(4096)
        local measured=tonumber(detail:GetStringHeight()) or 0
        local h=math.max(40,math.min(4096,measured+24))
        detail:SetHeight(h)
        detailBody:SetHeight(math.max(h, detailScroll:GetHeight() or 0))
        if detailScroll.UpdateScrollChildRect then detailScroll:UpdateScrollChildRect() end
        local limit=math.max(0,detailBody:GetHeight()-detailScroll:GetHeight())
        detailScroll:SetVerticalScroll(math.min(limit,detailScroll:GetVerticalScroll() or 0))
        UpdateDetailScrollIndicator()
    end
    detailScroll:SetScript('OnSizeChanged',ResizeDetailText)
    -- The pane's horizontal splitter changes width while the window height
    -- stays constant. An aspect-based viewer height makes the extra width
    -- genuinely useful instead of stretching a 190px-tall letterbox.
    local function UpdateDetailViewerSize()
        local innerWidth=math.max(1,(right:GetWidth() or 0)-28)
        local paneHeight=tonumber(right:GetHeight()) or 0
        if paneHeight<400 then return end -- layout not resolved yet
        -- Preserve at least 105px for readable source text, and leave the
        -- bottom 150px to the four controls. The viewport is never allowed to
        -- extend over those controls on small game windows.
        local heightCap=math.max(130,paneHeight-53-37-150-105)
        local target=math.max(190,math.min(500,innerWidth*0.64))
        target=math.min(target,heightCap)
        if math.abs((viewer:GetHeight() or 0)-target)>1 then
            viewer:SetHeight(target)
        end
        -- The size/anchor change triggers the scroll frame's OnSizeChanged
        -- handler, which reflows the description and its scrollbar. This
        -- direct call also covers native builds which don't trigger it for an
        -- anchor-only geometry change.
        ResizeDetailText()
    end
    right:HookScript('OnSizeChanged',UpdateDetailViewerSize)
    UpdateDetailViewerSize()
    detailScroll:SetScript('OnMouseWheel',function(self,delta)
        local maximum=math.max(0,detailBody:GetHeight()-self:GetHeight())
        self:SetVerticalScroll(math.max(0,math.min(maximum,(self:GetVerticalScroll() or 0)-(delta*36))))
        UpdateDetailScrollIndicator()
    end)
    if detailScroll.HasScript and detailScroll:HasScript('OnVerticalScroll') then
        detailScroll:HookScript('OnVerticalScroll',UpdateDetailScrollIndicator)
    end
    local technicalShown=false
    local preview,copied
    local technicalToggle=CollectionButton(right,'Technical options +',function(self)
        technicalShown=not technicalShown
        self.label:SetText(technicalShown and 'Technical options -' or 'Technical options +')
        if preview then preview:SetShown(technicalShown) end
        if copied then copied:SetShown(technicalShown) end
        detailScroll:ClearAllPoints()
        detailScroll:SetPoint('TOPLEFT',viewer,'BOTTOMLEFT',0,-37)
        detailScroll:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-14,technicalShown and 150 or 50)
        scrollTrack:ClearAllPoints()
        scrollTrack:SetPoint('TOPRIGHT',viewer,'BOTTOMRIGHT',7,-37)
        scrollTrack:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-7,technicalShown and 150 or 50)
        if page.selected then page:ShowDetail(page.selected) end
        ResizeDetailText()
    end)
    technicalToggle:SetPoint('BOTTOMLEFT',14,16)
    technicalToggle:SetPoint('BOTTOMRIGHT',-14,16)
    technicalToggle:SetHeight(25)
    local resetView=CollectionButton(right,'Reset 3D view',function() ResetView() end)
    resetView:SetSize(113,23)
    resetView:SetPoint('TOPRIGHT',viewer,'TOPRIGHT',-8,-8)
    resetView:SetFrameLevel(modelInput:GetFrameLevel()+2)

    -- The actual mount special is animation 94 (MountSpecial), not the
    -- /mountspecial slash command: the latter would animate the player's
    -- live mount, rather than the selected model inside this preview.
    -- Some newer self-mount models use 636/637; only try them when advertised
    -- as supported by HasAnimation. Never animate pets/toys/transmog here.
    mountSpecialButton=CollectionButton(right,'Mount Special',function()
        local entry=viewerSelected
        local model=CurrentModel()
        if not entry or entry.category~='mounts' or viewerKind~='creature'
            or not model or not model:IsShown() or type(model.SetAnimation)~='function' then
            return
        end
        local animation=94 -- MountSpecial
        if type(model.HasAnimation)=='function' then
            local ok,available=pcall(model.HasAnimation,model,animation)
            if ok and available==false then
                animation=nil
                for _,candidate in ipairs({636,637}) do -- MountSelfSpecial / FlyMountSelfSpecial
                    local canCheck,has=pcall(model.HasAnimation,model,candidate)
                    if canCheck and has then animation=candidate;break end
                end
                if not animation then
                    if AF.Print then AF.Print('No mount special animation for this model.') end
                    return
                end
            end
        end
        mountSpecialSerial=mountSpecialSerial+1
        local token=mountSpecialSerial
        Call(model,'SetPaused',false)
        model.afMountSpecialToken=token
        model.afMountSpecialEntry=entry
        local success,accepted=pcall(model.SetAnimation,model,animation)
        if not success or accepted==false then
            model.afMountSpecialToken=nil
            model.afMountSpecialEntry=nil
            return
        end
        -- OnAnimFinished returns to idle exactly when this mount's one-shot
        -- ends. Keep the previous 4-second timeout only as a fallback on
        -- clients/models that do not fire that callback. Replaying or picking
        -- another mount invalidates the old callback via the token guard.
        if C_Timer and type(C_Timer.After)=='function' then
            C_Timer.After(4.0,function()
                if model.afMountSpecialToken==token then
                    FinishMountSpecial(model)
                end
            end)
        end
    end)
    mountSpecialButton:SetSize(112,23)
    mountSpecialButton:SetPoint('TOPLEFT',viewer,'TOPLEFT',8,-8)
    mountSpecialButton:SetFrameLevel(modelInput:GetFrameLevel()+2)
    mountSpecialButton:SetScript('OnEnter',function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self,'ANCHOR_TOP')
            GameTooltip:SetText('Mount Special')
            GameTooltip:AddLine('Play the selected mount\'s special animation in the 3D preview.',1,1,1,true)
            GameTooltip:Show()
        end
    end)
    mountSpecialButton:SetScript('OnLeave',function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    mountSpecialButton:Hide()
    -- A separate Model Lab is retained for identifying bad model assets.
    preview=CollectionButton(right,'Model diagnostics / pose lab',function()
        if page.selected then
            if page.selected.category=='transmog' then page:ResolveTransmog(page.selected) end
            UI:OpenCollectionModelLab(page.selected)
        end
    end)
    preview:SetPoint('BOTTOMLEFT',14,82);preview:SetPoint('BOTTOMRIGHT',-14,82)
    preview:Hide()
    copied=CollectionButton(right,'Copy item diagnostics',function()
        if not page.selected then return end
        if page.selected.category=='transmog' then page:ResolveTransmog(page.selected) end
        local text=EntryDiagnostics(page.selected)
        page:ShowReport(text)
    end)
    copied:SetPoint('BOTTOMLEFT',14,49);copied:SetPoint('BOTTOMRIGHT',-14,49)
    copied:Hide()
    -- The ordinary collection detail view needs only one compact button.
    -- Advanced tools are optional and their extra bottom margin is reclaimed.
    detailScroll:ClearAllPoints()
    detailScroll:SetPoint('TOPLEFT',viewer,'BOTTOMLEFT',0,-37)
    detailScroll:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-14,50)
    scrollTrack:ClearAllPoints()
    scrollTrack:SetPoint('TOPRIGHT',viewer,'BOTTOMRIGHT',7,-37)
    scrollTrack:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-7,50)
    local displayAll=CollectionButton(filters,'3D all: OFF',function()
        page.allModelCards=not page.allModelCards
        if page.allModelCards then
            page.experimentalCardModels=false
        end
        page:Refresh()
    end)
    displayAll:SetSize(112,27)
    displayAll:SetPoint('RIGHT',filters,'RIGHT',-2,0)
    displayAll:SetScript('OnEnter',function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
            GameTooltip:AddLine('3D Display All — performance stress test')
            GameTooltip:AddLine('Renders every eligible card on THIS PAGE with a paused model. Hover one to animate it. OFF by default; click again to stop.',1,1,1,true)
            GameTooltip:AddLine('Can reduce frame rate. Hidden/unsupported models use their icons.',1,.70,.40,true)
            GameTooltip:Show()
        end
    end)
    displayAll:SetScript('OnLeave',function(self)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    local bottom=CreateFrame('Frame',nil,page)
    bottom:SetPoint('BOTTOMLEFT',12,10);bottom:SetPoint('BOTTOMRIGHT',-11,10)
    bottom:SetHeight(38)
    local status=Label(bottom,'Laboratory ready','small',P.ink)
    local perfMonitor=CreateFrame('Frame',nil,page)
    local baseStatus=''
    local function ShowPerfStatus()
        if not page.allModelCards then return end
        local fps=(type(GetFramerate)=='function' and GetFramerate()) or nil
        local frameRate=(type(fps)=='number' and fps==fps) and string.format(' | FPS %.0f',fps) or ''
        status:SetText(baseStatus..' | 3D '..page.allModelShown..'/'..page.allModelAttempts..frameRate)
    end
    local sampleTime=0
    perfMonitor:SetScript('OnUpdate',function(_,elapsed)
        if not page.allModelCards then return end
        sampleTime=sampleTime+(tonumber(elapsed) or 0)
        if sampleTime>=1 then sampleTime=0;ShowPerfStatus() end
    end)
    status:SetPoint('LEFT',0,0);status:SetSize(420,37)
    local vendor=CollectionButton(bottom,'Scan merchant',function()
        local ok,count,msg=pcall(AF.CaptureMerchantCollections,AF)
        if not ok then AF.Print('Merchant diagnostic: '..tostring(count))
        else AF.Print(msg or 'Merchant scan attempted') end
        page:Refresh()
    end)
    vendor:SetPoint('RIGHT',bottom,'RIGHT',-158,0);vendor:SetSize(145,29)
    local diagnostic=CollectionButton(bottom,'Diagnostics',function()
        page:ShowReport(page:BuildDiagnostics())
    end)
    diagnostic:SetPoint('RIGHT',bottom,'RIGHT',0,0);diagnostic:SetSize(149,29)
    -- The modal is intentionally internal to Collections: no risk to other windows.
    local modal=UI:NewFrame('Frame',page)
    modal:SetPoint('CENTER',page,'CENTER',0,0);modal:SetSize(480,244)
    modal:SetFrameStrata('FULLSCREEN_DIALOG');modal:SetFrameLevel(400)
    UI:Background(modal,P.leather,true)
    local warning=Label(modal,'Reveal ALL collection entries and their available acquisition information? This can spoil mounts, pets, toys, appearances, secrets and locations you have not discovered.\n\nThis changes viewing only; it does NOT mark any entry discovered. Type CONFIRM to continue.','small',P.pale)
    warning:SetPoint('TOPLEFT',18,-16);warning:SetPoint('TOPRIGHT',-18,-16);warning:SetHeight(127)
    local confirmEdit=UI:Input(modal,195)
    confirmEdit:SetPoint('BOTTOMLEFT',20,53)
    local cancel=CollectionButton(modal,'Cancel',function()modal:Hide();confirmEdit:SetText('') end)
    cancel:SetSize(100,28);cancel:SetPoint('BOTTOMRIGHT',-151,16)
    local unlock=CollectionButton(modal,'Reveal All',function()
        if confirmEdit:GetText()~='CONFIRM' then
            AF.Print('Type CONFIRM exactly to reveal the complete catalog.');return
        end
        AF.db.collections.settings.revealAll=true
        AF.db.collections.settings.visibility='all'
        modal:Hide();confirmEdit:SetText('')
        page.selected=nil;page.pageNumber=1;page:Refresh()
    end)
    unlock:SetSize(123,28);unlock:SetPoint('BOTTOMRIGHT',-18,16)
    modal:Hide();page.revealModal=modal
    function page:AskReveal()
        confirmEdit:SetText('');modal:Show();modal:Raise();confirmEdit:SetFocus()
    end
    local report=UI:NewFrame('Frame',page)
    report:SetSize(560,210);report:SetPoint('CENTER',page,'CENTER')
    report:SetFrameStrata('FULLSCREEN_DIALOG');report:SetFrameLevel(420)
    UI:Background(report,P.leather,true)
    local title=Label(report,'Collections diagnostic report (Ctrl+C to copy)','small',P.pale)
    title:SetPoint('TOPLEFT',13,-12);title:SetSize(515,30)
    local rEdit=UI:Input(report,513);rEdit:SetHeight(37)
    rEdit:SetPoint('TOPLEFT',14,-58)
    local reportText=Label(report,'','small',P.pale)
    reportText:SetPoint('TOPLEFT',14,-101);reportText:SetPoint('TOPRIGHT',-14,-101)
    reportText:SetHeight(75)
    local rClose=CollectionButton(report,'Close',function()report:Hide() end)
    rClose:SetSize(90,27);rClose:SetPoint('BOTTOMRIGHT',-13,12)
    report:Hide()
    function page:ShowReport(text)
        rEdit:SetText((text or ''):gsub('\n',' | '));rEdit:HighlightText();rEdit:SetFocus()
        reportText:SetText(text or '')
        report:Show();report:Raise()
    end
    function page:BuildDiagnostics()
        local c=AF.db.collections
        local lines={'AF Collections v0.4.4.2.10; '..tostring(c.settings.category),
            '3D all visible page: '..tostring(page.allModelCards)..' | shown/attempted: '..page.allModelShown..'/'..page.allModelAttempts,
            'FPS now: '..tostring(type(GetFramerate)=='function' and GetFramerate() or 'unavailable'),
            'Mount API '..tostring(C_MountJournal and type(C_MountJournal.GetMountIDs)),
            'Pet API '..tostring(C_PetJournal and type(C_PetJournal.GetNumPets)),
            'Toy API '..tostring(C_ToyBox and type(C_ToyBox.GetNumFilteredToys)),
            'Transmog API '..tostring(C_TransmogCollection and type(C_TransmogCollection.GetCategoryAppearances)),
            'Merchant API '..tostring(C_MerchantFrame and type(C_MerchantFrame.GetItemInfo)),
            'LibItemDB: '..tostring(AF.GetCollectionItemDBStatus and AF:GetCollectionItemDBStatus() or 'not integrated'),
            'Last merchant '..tostring(c.lastMerchantScan and c.lastMerchantScan.name or 'none'),
            'Last merchant scan: '..tostring(c.lastMerchantScan and c.lastMerchantScan.slots or 'unknown')..' slots / '..tostring(c.lastMerchantScan and c.lastMerchantScan.matched or 'unknown')..' matches',
            'All appearance sources API '..tostring(C_TransmogCollection and type(C_TransmogCollection.GetAllAppearanceSources)),
            'Source icon API '..tostring(C_TransmogCollection and type(C_TransmogCollection.GetSourceIcon)),
            'Transmog class selection: '..tostring(AF.GetCollectionTransmogClassChoice and AF:GetCollectionTransmogClassChoice()),
            'Class source validator '..tostring(C_TransmogCollection and type(C_TransmogCollection.GetValidAppearanceSourcesForClass)),
            'Class check: '..tostring(AF.collectionClassDiagnostics and AF.collectionClassDiagnostics.method)..' matched/scanned '..tostring(AF.collectionClassDiagnostics and AF.collectionClassDiagnostics.valid)..'/'..tostring(AF.collectionClassDiagnostics and AF.collectionClassDiagnostics.scanned),
            'Native class filter getter '..tostring(C_TransmogCollection and type(C_TransmogCollection.GetClassFilter)),
            'Native class filter setter '..tostring(C_TransmogCollection and type(C_TransmogCollection.SetClassFilter)),
            'DressUpModel supported: experiment via hover / model lab'}
        return table.concat(lines,'\n')
    end
    local modelCards=CollectionButton(filters,'3D hover: OFF',function()
        page.experimentalCardModels=not page.experimentalCardModels
        if page.experimentalCardModels then page.allModelCards=false end
        HideHoverModel()
        page:Refresh()
    end)
    modelCards:SetSize(119,27);modelCards:SetPoint('RIGHT',displayAll,'LEFT',-6,0)
    -- Use category names from the client's native wardrobe where present.
    -- Explicit fallbacks match Enum.TransmogCollectionType IDs (1 through 29).
    local slotFallback={
        'Head','Shoulders','Back','Chest','Shirt','Tabard','Wrists',
        'Hands','Waist','Legs','Feet','Wands','One-Handed Axes',
        'One-Handed Swords','One-Handed Maces','Daggers','Fist Weapons',
        'Shields','Held in Off-Hand','Two-Handed Axes',
        'Two-Handed Swords','Two-Handed Maces','Staves','Polearms',
        'Bows','Guns','Crossbows','Warglaives','Paired Weapons'
    }
    local function SlotLabel(id)
        local api=C_TransmogCollection
        local name=api and Try(api.GetCategoryInfo,id)
        if type(name)=='string' and name~='' then return name end
        return slotFallback[id] or ('Slot '..tostring(id))
    end
    local slotMenu
    local mogControl=CollectionButton(filters,'Slot: Head  v',function()
        if not slotMenu then return end
        slotMenu:SetShown(not slotMenu:IsShown())
        if slotMenu:IsShown() then
            visibilityMenu:Hide()
            if page.classMenu then page.classMenu:Hide() end
            slotMenu:Raise()
        end
    end)
    mogControl:SetSize(116,28);mogControl:SetPoint('LEFT',search,'RIGHT',10,0)
    slotMenu=Card(page)
    slotMenu:SetFrameStrata('DIALOG')
    slotMenu:SetFrameLevel(math.max(31,(page:GetFrameLevel() or 1)+27))
    slotMenu:SetSize(198,324)
    slotMenu:SetPoint('TOPLEFT',mogControl,'BOTTOMLEFT',0,-2)
    slotMenu:Hide()
    page.slotMenu=slotMenu
    local slotScroll=CreateFrame('ScrollFrame',nil,slotMenu)
    slotScroll:SetPoint('TOPLEFT',slotMenu,'TOPLEFT',6,-7)
    slotScroll:SetPoint('BOTTOMRIGHT',slotMenu,'BOTTOMRIGHT',-9,7)
    slotScroll:EnableMouseWheel(true)
    local slotBody=CreateFrame('Frame',nil,slotScroll)
    slotBody:SetWidth(178)
    local slotButtons={}
    local y=4
    for id=1,29 do
        if id==1 or id==12 then
            local group=Label(slotBody,id==1 and 'ARMOR' or 'WEAPONS','small',P.brass)
            group:SetPoint('TOPLEFT',slotBody,'TOPLEFT',8,-y)
            group:SetSize(161,18)
            y=y+19
        end
        local chosen=id
        local choice=CollectionButton(slotBody,SlotLabel(id),function()
            AF.db.collections.settings.transmogCategory=chosen
            slotMenu:Hide()
            page.selected=nil;page.pageNumber=1;page:Refresh()
        end)
        choice:SetPoint('TOPLEFT',slotBody,'TOPLEFT',4,-y)
        choice:SetSize(170,24)
        slotButtons[id]=choice
        y=y+25
    end
    slotBody:SetHeight(y+5)
    slotScroll:SetScrollChild(slotBody)
    slotScroll:SetScript('OnMouseWheel',function(self,delta)
        local maximum=math.max(0,slotBody:GetHeight()-self:GetHeight())
        self:SetVerticalScroll(math.max(0,math.min(maximum,(self:GetVerticalScroll() or 0)-(delta*45))))
    end)
    -- The class selector is a Blizzard-style, single-choice flyout. It is
    -- deliberately separate from the player's actual class and does not set
    -- Blizzard's saved wardrobe preference (the backend restores that value).
    local classButton=CollectionButton(filters,'Class: Current',function()
        if page.classMenu and page.classMenu:IsShown() then
            page.classMenu:Hide()
        elseif page.classMenu then
            if page.slotMenu then page.slotMenu:Hide() end
            page.classMenu:Show()
        end
    end)
    classButton:SetSize(137,28)
    classButton:SetPoint('LEFT',search,'RIGHT',136,0)
    local classMenu=Card(page)
    classMenu:SetFrameStrata('DIALOG')
    classMenu:SetFrameLevel(math.max(30,(page:GetFrameLevel() or 1)+25))
    classMenu:SetSize(164,350)
    classMenu:SetPoint('TOPLEFT',classButton,'BOTTOMLEFT',0,-2)
    classMenu:Hide()
    page.classMenu=classMenu
    local function ClassOptions()
        local options={{0,'All Classes'}}
        local num=tonumber(type(GetNumClasses)=='function' and GetNumClasses()) or 0
        local seen={}
        for i=1,math.min(20,num) do
            local name,_,id
            if type(GetClassInfo)=='function' then name,_,id=GetClassInfo(i) end
            if type(name)=='string' and tonumber(id) and not seen[id] then
                seen[id]=true
                options[#options+1]={tonumber(id),name}
            end
        end
        if #options<3 and C_CreatureInfo and type(C_CreatureInfo.GetClassInfo)=='function' then
            for id=1,13 do
                local info=Try(C_CreatureInfo.GetClassInfo,id)
                if type(info)=='table' and type(info.className)=='string' and not seen[id] then
                    seen[id]=true
                    options[#options+1]={id,info.className}
                end
            end
        end
        -- Even if the beta does not enumerate the classes, always include the
        -- player class so the selector matches the character being played.
        if type(UnitClass)=='function' then
            local playerName,token,playerID=Try(UnitClass,'player')
            local tokenIDs={WARRIOR=1,PALADIN=2,HUNTER=3,ROGUE=4,PRIEST=5,SHAMAN=7,MAGE=8,WARLOCK=9,DRUID=11}
            playerID=tonumber(playerID) or tokenIDs[token]
            if playerID and not seen[playerID] then
                options[#options+1]={playerID,playerName or token or ('Class '..playerID)}
            end
        end
        return options
    end
    local classOptions=ClassOptions()
    classMenu:SetHeight(math.min(375,8+#classOptions*25))
    local classNames={[0]='All Classes'}
    for i,opt in ipairs(classOptions) do
        local id,label=opt[1],opt[2]
        if id then classNames[id]=label end
        local choice=CollectionButton(classMenu,label,function()
            local api=C_TransmogCollection
            if id~=nil and not (api and type(api.GetClassFilter)=='function' and type(api.SetClassFilter)=='function') then
                if UI and UI.Print then UI:Print('Forever class filtering unavailable in this client.') end
                classMenu:Hide()
                return
            end
            AF:SetCollectionTransmogClassChoice(id)
            classMenu:Hide()
            page.selected=nil;page.pageNumber=1;page:Refresh()
        end)
        choice:SetSize(148,23)
        choice:SetPoint('TOPLEFT',8,-5-(i-1)*25)
    end
    local transmogCache={}
    -- The model-icon lookup may succeed before GetItemInfo can resolve a name.
    -- Only invalidate pending cards for the item whose data actually arrived.
    local itemUpdates=CreateFrame('Frame',nil,page)
    itemUpdates:RegisterEvent('GET_ITEM_INFO_RECEIVED')
    itemUpdates:RegisterEvent('ITEM_DATA_LOAD_RESULT')
    itemUpdates:SetScript('OnEvent',function(_,event,itemID,success)
        itemID=tonumber(itemID)
        if not itemID or not pendingItemIDs[itemID] then return end
        if success==false then
            -- Failed requests should not trigger an endless series of lookups.
            pendingItemIDs[itemID]=nil
            return
        end
        pendingItemIDs[itemID]=nil
        local needsRefresh=false
        for key,v in pairs(transmogCache) do
            if v and v.needsItemData and type(v.sourceItems)=='table' then
                for _,src in ipairs(v.sourceItems) do
                    if src.itemID==itemID then transmogCache[key]=nil;needsRefresh=true;break end
                end
            end
        end
        if needsRefresh and page:IsShown() and page.Refresh then page:Refresh() end
    end)
    function page:ResolveTransmog(entry)
        if not entry or entry.category~='transmog' then return end
        local key=tostring(entry.categoryID)..':'..tostring(entry.id)
        local cached=transmogCache[key]
        if not cached or (cached.needsItemData and cached.itemID and ItemName(cached.itemID)) then
            local temp={id=entry.id,categoryID=entry.categoryID,icon=entry.icon,name=entry.name}
            ResolveAppearance(temp)
            cached=temp
            transmogCache[key]=cached
        end
        -- Copy only descriptive metadata. Collection status and discovery remain
        -- separate and are NEVER inferred from source resolution.
        for _,k in ipairs({'icon','name','itemID','sourceID','sourceIDs','sourceItems',
            'sourceCount','sourceChecked','resolutionStatus','nameOrigin','needsItemData'}) do
            entry[k]=cached[k]
        end
    end
    -- Strong contrast on light parchment: data and provenance stay distinct.
    -- The section layout intentionally uses one measured, scrollable FontString
    -- instead of spawning hundreds of font objects when rapidly changing cards.
    local function DetailHeader(text)
        return '|cff49301b'..text..'|r'
    end
    local function DetailLabel(label,value)
        return '|cff614026'..label..'|r'..tostring(value or 'Unknown')
    end
    local function DetailNote(text)
        return '|cff584632'..text..'|r'
    end
    local function ClientMapLabel(mapID)
        if mapID and C_Map and type(C_Map.GetMapInfo)=='function' then
            local ok,info=pcall(C_Map.GetMapInfo,mapID)
            if ok and type(info)=='table' and type(info.name)=='string' and info.name~='' then
                return info.name
            end
        end
        return mapID and ('Map #'..tostring(mapID)) or 'Location not recorded'
    end
    local function PersonalSources(rec)
        local result={}
        if rec and type(rec.sources)=='table' then
            for key,row in pairs(rec.sources) do
                if type(row)=='table' then result[#result+1]={key=tostring(key),data=row} end
            end
        end
        table.sort(result,function(a,b)
            local at=tonumber(a.data.lastSeen) or 0
            local bt=tonumber(b.data.lastSeen) or 0
            if at~=bt then return at>bt end
            return a.key<b.key
        end)
        return result
    end
    function page:ShowDetail(entry)
        if not entry then
            head:SetText('Select a collection card')
            detail:SetText('Select a collectible to inspect its information and your recorded discoveries.')
            detailScroll:SetVerticalScroll(0)
            ResizeDetailText()
            RefreshViewer(nil)
            return
        end
        if entry.mystery then
            head:SetText('Mystery Card (tutorial)')
            RefreshViewer(entry)
            detail:SetText('This is a tutorial placeholder, not a real collectible.\n\nFoundry does not count it toward your collection. Visit a vendor or obtain a collectible to begin cataloging discoveries. Reveal All offers separate reference information.')
            detailScroll:SetVerticalScroll(0)
            ResizeDetailText()
            return
        end
        page:ResolveTransmog(entry)
        local rec=AF:CollectionDiscovery(entry.category,entry.id)
        local observed=PersonalSources(rec)
        local reveal=AF.db.collections.settings.revealAll==true
        -- A saved observation is discovery even if the beta does not expose a native source.
        local knowsSource=entry.owned or rec~=nil or (#observed>0) or reveal
        head:SetText(entry.name or ('#'..entry.id))
        local lines={}
        local function line(text) lines[#lines+1]=text end
        local function section(title)
            if #lines>0 then line('') end
            line(DetailHeader(title))
        end
        section('COLLECTION STATUS')
        if entry.owned then
            line('|cff24612eCollected|r')
        elseif rec then
            line('|cff855114Discovered  /  Not yet collected|r')
        else
            line('Not collected or personally discovered.')
        end
        if reveal then
            line(DetailNote('Reveal All: references below are not personal discoveries.'))
        end

        section('WHERE TO FIND IT')
        if not knowsSource then
            line('Acquisition hints are hidden in My Discoveries until you encounter a source.')
            line(DetailNote('Reveal All can display available reference information without marking anything discovered.'))
        else
            local specific=false
            local categoryOnly=false
            -- Actual player encounters take priority over incomplete client source metadata.
            -- Personal discoveries must not be hidden below a contradictory "no source" notice.
            if #observed>0 then
                for _,found in ipairs(observed) do
                    local src=found.data
                    if src.kind=='vendor' then
                        line(DetailLabel('Merchant: ',src.npcName or 'Unidentified merchant'))
                        line(DetailLabel('Location: ',ClientMapLabel(src.mapID)))
                        specific=true
                    elseif src.kind then
                        line(DetailLabel('Personally observed source: ',src.kind))
                        specific=true
                    end
                end
            end
            if entry.category=='mounts' then
                local sourceType=tonumber(entry.sourceType)
                if sourceType and sourceType>0 then
                    line(DetailLabel('Game category: ',SourceTypeLabel(sourceType)))
                    categoryOnly=true
                end
                if HasSourceText(entry.source) then
                    line(DetailLabel('Game Journal: ',entry.source))
                    specific=true
                end
                local external=reveal and AF.GetCollectionSourceReference and AF:GetCollectionSourceReference('mounts',entry.id)
                if type(external)=='table' then
                    line(DetailLabel('Reference: ',external.source or external.label or 'Unverified source'))
                    if external.label and external.source then
                        line(DetailLabel('Acquisition item: ',external.label))
                    end
                    if external.note then line(DetailNote(external.note)) end
                    if external.url then line(DetailLabel('More information: ',external.url)) end
                    line(DetailNote('External reference - verify against the Forever beta.'))
                    specific=true
                end
            elseif entry.category=='pets' then
                if HasSourceText(entry.source) then
                    line(DetailLabel('Game Journal: ',entry.source))
                    specific=true
                end
            elseif entry.category=='transmog' then
                if reveal and type(entry.sourceItems)=='table' and #entry.sourceItems>0 then
                    line(DetailLabel('Linked appearance items: ',tostring(#entry.sourceItems)))
                    for i=1,math.min(#entry.sourceItems,8) do
                        local item=entry.sourceItems[i]
                        if type(item)=='table' then
                            line('  - '..tostring(item.name or (item.itemID and ('Item #'..item.itemID) or 'Unnamed item')))
                        end
                    end
                    if #entry.sourceItems>8 then line(DetailNote('Additional linked item IDs appear under Technical / API Details.')) end
                    line(DetailNote('A linked item is not proof of a vendor or drop location.'))
                end
            end
            -- These are references, not a scan or a personal source record.
            -- Consult the library on EACH detail selection so updated DB tables
            -- can be picked up without changing SavedVariables or the gallery.
            if reveal and AF.GetCollectionAcquisitionReferences then
                local refs,state=AF:GetCollectionAcquisitionReferences(entry)
                if type(refs)=='table' and #refs>0 then
                    line(DetailLabel('LibItemDB sources: ',''))
                    for _,row in ipairs(refs) do line('  - '..tostring(row)) end
                    line(DetailNote('Library references - not personally discovered.'))
                    specific=true
                elseif state and entry.category~='mounts' then
                    -- Mounts often have no acquisition item mapping; avoid
                    -- overwhelming their human-facing panel with DB messages.
                    line(DetailNote('LibItemDB: '..tostring(state)))
                end
            end
            if not specific then
                if categoryOnly then
                    line('The game identifies a source category, but does not specify an exact vendor, drop, quest or location.')
                elseif entry.category=='mounts' then
                    line('No acquisition source is linked for this mount in the current Forever beta data.')
                else
                    line('No specific acquisition source is currently linked in the game or available library data.')
                end
                line(DetailNote('Unknown source does not mean unobtainable. Foundry checks supported links again when you inspect this entry.'))
            end
        end
        if HasSourceText(entry.description) then
            section('DESCRIPTION')
            line(entry.description)
        end

        section('DISCOVERY HISTORY')
        if #observed>0 then
            for i,found in ipairs(observed) do
                local src=found.data
                if src.kind=='vendor' then
                    -- Acquisition already lists the vendor/location above.
                    -- Keep discovery history focused on when it was observed.
                    if #observed>1 then line(DetailLabel('Merchant: ',src.npcName or 'Unidentified merchant')) end
                    if src.firstSeen then line(DetailLabel('First seen: ',HumanDate(src.firstSeen))) end
                    line(DetailLabel('Last seen: ',HumanDate(src.lastSeen)))
                    if tonumber(src.price) and tonumber(src.price)>0 then
                        line(DetailLabel('Price at last visit: ',FormatMoney(src.price)))
                    end
                else
                    line(DetailLabel('Observed source: ',src.kind or 'Unknown source'))
                    line(DetailLabel('Last seen: ',HumanDate(src.lastSeen)))
                end
                if i<#observed then line('') end
            end
        elseif entry.owned then
            line('Collected. Foundry did not record the original acquisition source.')
        elseif rec then
            line('Discovered, but no acquisition location has been recorded.')
        else
            line('No personal acquisition source recorded yet.')
        end

        if technicalShown then
        section('TECHNICAL / API DETAILS')
        line(DetailNote('Diagnostic identifiers only; these are not acquisition hints.'))
        line(DetailLabel('Collection: ',tostring(entry.category)..' #'..tostring(entry.id)))
        if entry.category=='mounts' then
            if knowsSource then
                line(DetailLabel('Source category code: ',tostring(entry.sourceType or 'nil')))
            else
                line('Source identifiers withheld in Discovery Mode.')
            end
            line(DetailLabel('Client hidden flag: ',tostring(entry.clientHidden)))
            line(DetailLabel('Client availability status: ',tostring(entry.availabilityStatus or 'Unverified')))
            line(DetailLabel('Display ID: ',tostring(entry.displayID or 'nil')))
            if not HasSourceText(entry.source) and knowsSource then line('Client source description: not provided') end
        elseif entry.category=='transmog' then
            line(DetailLabel('Appearance resolution: ',entry.resolutionStatus or 'Not resolved'))
            line(DetailLabel('Linked source count: ',tostring(entry.sourceCount or 0)))
            line(DetailLabel('Representative item ID: ',entry.itemID and tostring(entry.itemID) or 'Unknown'))
            line(DetailLabel('Representative source ID: ',entry.sourceID and tostring(entry.sourceID) or 'Unknown'))
            if entry.nameOrigin then line(DetailLabel('Item name from: ',entry.nameOrigin)) end
            if (entry.sourceCount or 0)==0 then line('Client returned no linked source for this appearance.') end
            if reveal and type(entry.sourceItems)=='table' and #entry.sourceItems>0 then
                line(DetailLabel('Item/source ID pairs: ',''))
                for i=1,#entry.sourceItems do
                    local item=entry.sourceItems[i]
                    if type(item)=='table' then
                        line('  - '..tostring(item.itemID or '?')..' / '..tostring(item.sourceID or '?'))
                    end
                end
            end
        elseif entry.category=='pets' then
            line(DetailLabel('Display ID: ',tostring(entry.displayID or 'nil')))
        elseif entry.category=='toys' then
            line(DetailLabel('Item ID: ',tostring(entry.id)))
        end
        for _,found in ipairs(observed) do
            local src=found.data
            if src.mapID then line(DetailLabel('Observed map ID: ',tostring(src.mapID))) end
            if src.x and src.y then line(DetailLabel('Observed coordinates: ',tostring(src.x)..', '..tostring(src.y))) end
            if src.itemID then line(DetailLabel('Observed item ID: ',tostring(src.itemID))) end
        end
        end -- technical details are opt-in; also available via Copy item diagnostics
        detail:SetText(table.concat(lines,'\n'))
        technicalToggle.label:SetText(technicalShown and 'Technical options -' or 'Technical options +')
        -- Opening the debug section does not reset the user's 3D inspection.
        if viewerSelected~=entry then RefreshViewer(entry) end
        detailScroll:SetVerticalScroll(0)
        ResizeDetailText()
    end
    page.pageNumber=1
    function page:Select(category)
        if category~='mounts' and category~='pets' and category~='toys' and category~='transmog' then
            category='mounts'
        end
        if AF.db.collections.settings.category~=category then
            AF.db.collections.settings.category=category
            if self.visibilityMenu then self.visibilityMenu:Hide() end
            if self.slotMenu then self.slotMenu:Hide() end
            if self.classMenu then self.classMenu:Hide() end
            self.selected=nil
            self.pageNumber=1
        end
        self:Refresh()
        UI:RefreshNavigation()
    end
    function page:Refresh()
        if not AF.db or not AF.db.collections then return end
        local s=AF.db.collections.settings
        local category=s.category or 'mounts'
        mogControl:SetShown(category=='transmog')
        classButton:SetShown(category=='transmog')
        if category~='transmog' then classMenu:Hide();slotMenu:Hide() end
        local cls=AF:GetCollectionTransmogClassChoice()
        local displayName=classNames[cls]
        if not displayName and type(UnitClass)=='function' then
            local name,_,id=Try(UnitClass,'player')
            if tonumber(id)==cls then displayName=name end
        end
        classButton.label:SetText('Class: '..tostring(displayName or ('#'..tostring(cls or '?'))) ..' v')
        local slotID=math.max(1,math.min(29,tonumber(s.transmogCategory) or 1))
        mogControl.label:SetText('Slot: '..SlotLabel(slotID)..'  v')
        for id,button in ipairs(slotButtons) do
            button.label:SetText((id==slotID and '> ' or '')..SlotLabel(id))
        end
        modelCards.label:SetText(page.experimentalCardModels and '3D hover: ON' or '3D hover: OFF')
        displayAll.label:SetText(page.allModelCards and '3D all: ON' or '3D all: OFF')
        visibility.label:SetText((s.revealAll and 'Reveal All (spoilers)' or (s.visibility=='collected' and 'Collected Only' or 'My Discoveries'))..'  v')
        local ok, catalog=pcall(AF.GetCollectionCatalog,AF,category)
        if not ok or type(catalog)~='table' then
            status:SetText('Catalog not available: '..tostring(catalog))
            catalog={}
        end
        local visible={}
        local hiddenWithoutSource=0
        local needle=string.lower(search:GetText() or '')
        local knownCount=0
        for _,e in ipairs(catalog) do
            local observed=AF:CollectionDiscovery(category,e.id)
            if e.owned or observed then knownCount=knownCount+1 end
            -- Applies to Collected, My Discoveries and Reveal All. A personally
            -- seen mount always survives, even if the client's hidden flag is set.
            if not AF:ShouldShowCollectionEntry(e) then hiddenWithoutSource=hiddenWithoutSource+1 end
            if AF:ShouldShowCollectionEntry(e) and (e.owned or observed or s.revealAll)
                and (needle=='' or string.find(string.lower(e.name or ''),needle,1,true) or tostring(e.id)==needle) then
                visible[#visible+1]=e
            end
        end
        -- Empty discovery categories use an explanatory text state, not fake
        -- question-mark collectible cards. Mystery placeholders caused players
        -- to mistake tutorial art for missing real collection entries.
        if s.visibility=='collected' and not s.revealAll then
            local only={};for _,e in ipairs(visible) do if e.owned then only[#only+1]=e end end
            visible=only
        end
        local pagesNeeded=math.max(1,math.ceil(#visible/math.max(1,gridSize)))
        page.pageNumber=math.max(1,math.min(page.pageNumber or 1,pagesNeeded))
        pages:SetText(tostring(page.pageNumber)..'/'..tostring(pagesNeeded))
        prev:SetEnabled(page.pageNumber>1)
        nextB:SetEnabled(page.pageNumber<pagesNeeded)
        -- A zero-data view should teach discovery without misleading cards.
        if #visible==0 then
            if s.revealAll then
                emptyMessage:SetText('No '..category..' entries available in this catalog view.\nTry another class or slot, or check client catalog coverage.')
            elseif s.visibility=='collected' then
                emptyMessage:SetText('No collected '..category..' recorded yet.\nTry My Discoveries to review observed but unowned collectibles.')
            else
                emptyMessage:SetText('No '..category..' discovered yet.\nFoundry will remember the collectibles and vendors you encounter.\nReveal All is optional and exposes undiscovered catalog information.')
            end
            emptyMessage:Show()
        else
            emptyMessage:Hide()
        end
        HideHoverModel()
        HideAllCardModels()
        for i,b in ipairs(cardFrames) do
            local e=i<=gridSize and visible[(page.pageNumber-1)*gridSize+i]
            if e then
                if not e.mystery and (e.owned or s.revealAll) then page:ResolveTransmog(e) end
                b:Show();b.entry=e;b.mystery=e.mystery
                b.icon:SetTexture(e.mystery and MYSTERY_ICON or (GoodTexture(e.icon) or MYSTERY_ICON))
                b.icon:SetDesaturated(not(e.owned or e.mystery))
                b.icon:SetVertexColor(e.mystery and .65 or 1,e.mystery and .65 or 1,e.mystery and .65 or 1)
                local observed=not e.mystery and AF:CollectionDiscovery(category,e.id)
                if e.mystery then b.state:SetColorTexture(.24,.23,.21,1)
                elseif e.owned then b.state:SetColorTexture(.17,.66,.27,1)
                elseif observed then b.state:SetColorTexture(.85,.59,.19,1)
                else b.state:SetColorTexture(.42,.42,.42,1) end
                -- Gallery thumbnails are native icons; a SINGLE pooled PlayerModel
                -- appears over whichever supported mount/pet is hovered. No first-three cap.
                b.icon:Show()
                b.selectedArt:SetShown(page.selected and
                    ((e.mystery and page.selected==e)
                    or (not e.mystery and page.selected.id==e.id and page.selected.category==e.category)) or false)
                b.name:SetText(e.mystery and '???' or e.name)
            else
                b:Hide();b.entry=nil
                -- Model viewer is pooled at page scope; no per-card frames.
            end
        end
        RefreshAllCardModels()
        if page.selected then page:ShowDetail(page.selected) else page:ShowDetail(nil) end
        local mode=page.allModelCards and 'ALL visible (stress test)'
            or (page.experimentalCardModels and '1 hover model' or '2D icons')
        baseStatus=#visible..' entries | '..category..' | '..gridCols..'x'..gridRows..' cards | '..mode
        if category=='transmog' then
            local chosen=AF:GetCollectionTransmogClassChoice()
            baseStatus=baseStatus..' | class: '..tostring(classNames[chosen] or chosen)
            local diag=AF.collectionClassDiagnostics
            if diag then baseStatus=baseStatus..' | class check: '..diag.method..' ('..tostring(diag.valid)..'/'..tostring(diag.scanned)..')' end
            if chosen~=nil and not (C_TransmogCollection and type(C_TransmogCollection.SetClassFilter)=='function') then
                baseStatus=baseStatus..' (native filtering unavailable)'
            end
        end
        if s.revealAll and category=='pets' then
            local petDiag=AF.collectionPetCatalogDiagnostics
            if petDiag then
                baseStatus=baseStatus..' | native pet references: '..tostring(petDiag.native or 0)
                if (petDiag.native or 0)==0 then
                    baseStatus=baseStatus..' (client catalog unavailable)'
                end
            end
        end
        if s.revealAll and category=='toys' then
            local toyDiag=AF.collectionToyCatalogDiagnostics
            if toyDiag then
                baseStatus=baseStatus..' | native toy references: '..tostring(toyDiag.native or 0)
                if toyDiag.total then baseStatus=baseStatus..'/'..tostring(toyDiag.total)..' total' end
                if toyDiag.error then baseStatus=baseStatus..' (catalog scan error)' end
            end
        end
        if s.revealAll and category=='mounts' and hiddenWithoutSource>0 then
            baseStatus=baseStatus..' | '..hiddenWithoutSource..' hidden without source omitted'
        end
        if page.allModelCards then ShowPerfStatus() else status:SetText(baseStatus) end
    end
    page:Refresh()
end
