-- Azeroth Foundry v0.5.12.9 / Compact lower-corner inventory counts
-- View-only classification of *recorded* inventory snapshots. Never mutates
-- bags, bank records, crafting allocations, recipes or other characters.
local _, AF = ...
local UI = AF.UI
local P = UI.palette
local floor, max, min = math.floor, math.max, math.min
local unpack = unpack or table.unpack
local ITEM_CLASSES = {CONSUMABLE=0,WEAPON=2,GEM=3,ARMOR=4,REAGENT=5,TRADE=7,RECIPE=9,PROFESSION=19}
-- Prefer the client's official item-quality palette. Unknown or unloaded item
-- data gets neutral leather/bronze styling, never an invented rarity.
local FALLBACK_QUALITY = {
    [0]={.62,.62,.62}, [1]={.88,.85,.76}, [2]={.12,.90,.10},
    [3]={.05,.47,.92}, [4]={.70,.32,.95}, [5]={1,.52,.08},
    [6]={.94,.84,.55}, [7]={.10,.80,1},
}
local QUALITY_LABELS = {
    [0]='Poor',[1]='Common',[2]='Uncommon',[3]='Rare',
    [4]='Epic',[5]='Legendary',[6]='Artifact',[7]='Heirloom',
}
local function qualityColor(q)
    if type(q)~='number' then return .57,.43,.27,false end
    local client=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if client and type(client.r)=='number' then
        return client.r,client.g,client.b,true
    end
    local fallback=FALLBACK_QUALITY[q]
    if fallback then return fallback[1],fallback[2],fallback[3],true end
    return .57,.43,.27,false
end
-- A fixed 2px border around the actual icon is much easier to read than
-- tinting an entire material tile (and it does not alter the item artwork).
local function rarityBorder(parent,anchor,pad)
    local parts={}
    pad=pad or 2
    for _,side in ipairs({'TOP','BOTTOM','LEFT','RIGHT'}) do
        local t=parent:CreateTexture(nil,'OVERLAY')
        if side=='TOP' then
            t:SetPoint('TOPLEFT',anchor,'TOPLEFT',-pad,pad)
            t:SetPoint('TOPRIGHT',anchor,'TOPRIGHT',pad,pad)
            t:SetHeight(2)
        elseif side=='BOTTOM' then
            t:SetPoint('BOTTOMLEFT',anchor,'BOTTOMLEFT',-pad,-pad)
            t:SetPoint('BOTTOMRIGHT',anchor,'BOTTOMRIGHT',pad,-pad)
            t:SetHeight(2)
        elseif side=='LEFT' then
            t:SetPoint('TOPLEFT',anchor,'TOPLEFT',-pad,pad)
            t:SetPoint('BOTTOMLEFT',anchor,'BOTTOMLEFT',-pad,-pad)
            t:SetWidth(2)
        else
            t:SetPoint('TOPRIGHT',anchor,'TOPRIGHT',pad,pad)
            t:SetPoint('BOTTOMRIGHT',anchor,'BOTTOMRIGHT',pad,-pad)
            t:SetWidth(2)
        end
        parts[#parts+1]=t
    end
    return parts
end
local function paintRarity(parts,q)
    local r,g,b,known=qualityColor(q)
    for _,t in ipairs(parts) do
        t:SetColorTexture(r,g,b,known and .95 or .43)
    end
    return r,g,b,known
end

local function Info(id)
    local item=AF:GetItemPresentation(id) or {}
    local api=C_Item
    local getInfo=(api and api.GetItemInfo) or GetItemInfo
    local class,subclass,equip,quality,reagent,subname
    if type(getInfo)=='function' then
        local ok,_,_,q,_,_,_,sub,_,eq,_,_,cl,sc,_,_,_,isReagent=pcall(getInfo,id)
        if ok then class,subclass,equip,quality,reagent,subname=cl,sc,eq,q,isReagent,sub end
    end
    if class==nil then
        local instant=(api and api.GetItemInfoInstant) or GetItemInfoInstant
        if type(instant)=='function' then
            local ok,_,_,_,eq,_,cl,sc=pcall(instant,id)
            if ok then class,subclass,equip=cl,sc,eq end
        end
    end
    return {id=id, name=item.name or ('Item #'..id),icon=item.icon,
        link=item.link,quality=quality or item.quality,class=class,subclass=subclass,
        subname=subname or '',equip=equip or '',reagent=reagent,
        pending=item.pending or class==nil}
end

local HINTS={
    Mining={'ore','stone','bar','ingot','metal','mineral'},
    Herbalism={'herb','flower','plant','root','leaf'},
    Skinning={'leather','hide','scale'},
    Enchanting={'dust','essence','shard','crystal','rune'},
    Tailoring={'cloth','thread','silk','linen','wool'},
    Fishing={'fish','seafood'},
    Cooking={'fish','meat','food','spice','flour'},
    Blacksmithing={'ore','bar','ingot','stone','metal'},
    Alchemy={'herb','flower','plant','potion','flask','vial'},
    Engineering={'bolt','mechanical','gear','metal','stone','ore'},
    Inscription={'ink','pigment','herb','parchment'},
    Jewelcrafting={'gem','jewel','ore','stone'},
    Leatherworking={'leather','hide','scale','thread'},
}
local function inferredProfession(meta,profession)
    if not profession or profession=='all' then return true end
    local terms=HINTS[profession]
    if not terms then return false end
    local s=((meta.subname or '')..' '..(meta.name or '')):lower()
    for _,part in ipairs(terms) do if s:find(part,1,true) then return true end end
    return false
end
local function classification(meta,referenced)
    if referenced or meta.reagent==true or meta.class==ITEM_CLASSES.TRADE
            or meta.class==ITEM_CLASSES.REAGENT or meta.class==ITEM_CLASSES.PROFESSION then return 'reagents' end
    if meta.class==ITEM_CLASSES.CONSUMABLE then return 'consumables' end
    if (meta.class==ITEM_CLASSES.WEAPON or meta.class==ITEM_CLASSES.ARMOR)
            and type(meta.quality)=='number' and meta.quality>=2 and meta.quality<=4
            and meta.equip~='' then return 'disenchant' end
    if meta.class==nil then return 'unknown' end
    return 'other'
end
-- Test-friendly, pure classification entry point. 'disenchant' means possible
-- candidates ONLY; true eligibility requires rules we cannot infer from snapshots.
function UI:ClassifyRecordedMaterial(meta, isRecordedReagent)
    return classification(meta,isRecordedReagent)
end
local function quiet(parent,label,callback)
    local b=UI:Button(parent,label,callback,'row')
    b.label:SetTextColor(.98,.88,.7)
    local bg=b:CreateTexture(nil,'BACKGROUND',nil,-1)
    bg:SetAllPoints(b);bg:SetColorTexture(.18,.11,.075,.95)
    local edge=b:CreateTexture(nil,'BORDER')
    edge:SetPoint('BOTTOMLEFT',b,'BOTTOMLEFT',2,2)
    edge:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-2,2)
    edge:SetHeight(1);edge:SetColorTexture(.58,.42,.22,.63)
    if UI.ThemeQuietButton then UI:ThemeQuietButton(b,bg,{edge}) end
    return b
end
local function text(parent,content,size,color)
    local t=UI:Text(parent,size or 'small',color or P.ink)
    if content then t:SetText(content) end
    return t
end
local function drawButton(parent,label,callback)
    local btn=quiet(parent,label,callback)
    btn:SetHeight(24)
    return btn
end
local function timeText(t)
    if type(t)~='number' or t<=0 then return 'Unknown' end
    if type(date)=='function' then return date('%b %d, %H:%M',t) end
    return 'Recorded'
end
local function knownReagentSources(characters)
    local ids,byProfession={},{}
    local snapshots=(AF.db and AF.db.recipeSnapshots) or {}
    for _,c in ipairs(characters) do
        for _,snap in pairs(snapshots[c.key] or {}) do
            if type(snap)=='table' then
                local prof=snap.professionName
                for _,record in pairs(snap.recipes or {}) do
                    if type(record)=='table' and type(record.reagents)=='table' then
                        for _,r in ipairs(record.reagents) do
                            local id=tonumber(r.itemID)
                            if id then
                                ids[id]=true
                                if prof then
                                    byProfession[id]=byProfession[id] or {}
                                    byProfession[id][prof]=true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return ids,byProfession
end
local function buildSnapshots(scope,storage)
    local chars=scope=='eligible' and AF:GetPlanningResourceCharacters('expedition',AF:GetCurrentKey()) or AF:GetWorkshopCharacters(scope)
    local totals,owners,scans,latest={},{},0,0
    for _,c in ipairs(chars) do
        local snapshots=((AF.db.inventory or {})[c.key] or {})
        for _,where in ipairs({'bags','bank'}) do
            if storage=='all' or storage==where then
                local snap=snapshots[where]
                if type(snap)=='table' and type(snap.counts)=='table' then
                    scans=scans+1
                    latest=max(latest,tonumber(snap.scanned) or 0)
                    for rawId,rawCount in pairs(snap.counts) do
                        local id,count=tonumber(rawId),tonumber(rawCount)
                        if id and id>0 and count and count>0 then
                            totals[id]=(totals[id] or 0)+count
                            owners[id]=owners[id] or {bags=0,bank=0,chars={}}
                            owners[id][where]=owners[id][where]+count
                            local by=owners[id].chars
                            by[c.key]=by[c.key] or {name=c.name,bags=0,bank=0,scanned=0}
                            by[c.key][where]=by[c.key][where]+count
                            by[c.key].scanned=max(by[c.key].scanned,tonumber(snap.scanned) or 0)
                        end
                    end
                end
            end
        end
    end
    return totals,owners,scans,latest,chars
end

-- This is a VIEW-ONLY grouping layer. Saved counts and any recipe/crafting
-- allocation keys always remain the original numeric item IDs. Some Forever
-- items have different item IDs yet display the same name. In the combined
-- view we add their visible quantities, but keep parts[] so the individual
-- IDs, ownership and counts remain accessible.
-- Different qualities or classification types never share a display group.
local function groupRecordedEntries(entries)
    local byName,result={},{}
    for _,entry in ipairs(entries) do
        local meta=entry.meta or {}
        local name=type(meta.name)=='string' and meta.name:lower():gsub('^%s+',''):gsub('%s+$',''):gsub('%s+',' ') or ''
        local groupable=name~='' and not name:match('^item #%d+$')
        local key=groupable and (name..'\31'..tostring(meta.quality or '?')..'\31'..tostring(entry.kind or '')) or ('id:'..tostring(entry.id))
        local group=byName[key]
        if not group then
            group={id=entry.id,count=0,meta=entry.meta,kind=entry.kind,
                bags=0,bank=0,altCount=0,owners={},parts={}}
            byName[key]=group
            result[#result+1]=group
        end
        group.parts[#group.parts+1]=entry
        if entry.id<group.id then group.id=entry.id;group.meta=entry.meta end
        group.count=group.count+(entry.count or 0)
        group.bags=group.bags+(entry.bags or 0)
        group.bank=group.bank+(entry.bank or 0)
        for charKey,record in pairs(entry.owners or {}) do
            local owner=group.owners[charKey]
            if not owner then
                owner={name=record.name,bags=0,bank=0,scanned=0}
                group.owners[charKey]=owner
                group.altCount=group.altCount+1
            end
            owner.bags=owner.bags+(record.bags or 0)
            owner.bank=owner.bank+(record.bank or 0)
            owner.scanned=max(owner.scanned,record.scanned or 0)
        end
    end
    for _,group in ipairs(result) do
        table.sort(group.parts,function(a,b) return a.id<b.id end)
    end
    return result
end
function UI:GroupRecordedMaterialsForDisplay(entries)
    return groupRecordedEntries(entries)
end
local function entryContainsId(entry,id)
    if entry.id==id then return true end
    for _,part in ipairs(entry.parts or {}) do if part.id==id then return true end end
    return false
end
function UI:BuildWorkshopMaterials(page)
    local settings=AF.db.settings
    settings.materialsWorkbench=type(settings.materialsWorkbench)=='table' and settings.materialsWorkbench or {}
    local opts=settings.materialsWorkbench
    if opts.view~='ledger' then opts.view='inventory' end
    if opts.scope~='expedition' and opts.scope~='eligible' then opts.scope='all' end
    if opts.storage~='bags' and opts.storage~='bank' then opts.storage='all' end
    if opts.sort~='quantity' then opts.sort='name' end
    if opts.showReagents==nil then opts.showReagents=true end
    for _,k in ipairs({'showConsumables','showDisenchant','showOther','showUnknown'}) do
        opts[k]=opts[k]==true
    end
    if type(opts.profession)~='string' then opts.profession='all' end
    if opts.combineNames==nil then opts.combineNames=true end
    local current={entries={},selected=nil,owners={},recorded=0,scans=0}
    local intro=CreateFrame('Frame',nil,page)
    intro:SetPoint('TOPLEFT',page,'TOPLEFT',12,-8)
    intro:SetPoint('TOPRIGHT',page,'TOPRIGHT',-12,-8)
    intro:SetHeight(42)
    local strip=intro:CreateTexture(nil,'BACKGROUND')
    strip:SetAllPoints(intro);strip:SetColorTexture(.14,.097,.068,.94)
    local title=text(intro,'Materials Workbench','small',P.gold)
    title:SetPoint('TOPLEFT',intro,'TOPLEFT',12,-4);title:SetHeight(18)
    local subtitle=text(intro,'Crafting supplies from recorded bags and banks. Offline totals may be stale.','small',P.pale)
    subtitle:SetPoint('TOPLEFT',intro,'TOPLEFT',12,-22)
    subtitle:SetPoint('TOPRIGHT',intro,'TOPRIGHT',-12,-22)
    subtitle:SetHeight(16);subtitle:SetWordWrap(false)
    UI:ThemeWorkshopIntro(intro,strip,title,subtitle)
    intro:EnableMouse(true)
    intro:SetScript('OnEnter',function(self)
        if not GameTooltip then return end
        local policy=AF:GetExpeditionPlanningPolicy('expedition',AF:GetCurrentKey())
        GameTooltip:SetOwner(self,'ANCHOR_CURSOR')
        GameTooltip:SetText(AF:IsModuleEnabled('selfFound') and 'Expedition material scope' or 'Recorded material scope',1,.84,.50)
        GameTooltip:AddLine(policy.note,.9,.83,.7,true)
        GameTooltip:AddLine('Ownership is based on last-recorded bag and bank snapshots; item origin is never certified.',.8,.78,.68,true)
        GameTooltip:Show()
    end)
    intro:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end)

    local main=UI:Card(page)
    main:SetPoint('TOPLEFT',page,'TOPLEFT',12,-57)
    main:SetPoint('BOTTOMRIGHT',page,'BOTTOMRIGHT',-12,11)
    local head=UI:SectionTitle(main,'Material Inventory')
    head:SetPoint('TOPLEFT',main,'TOPLEFT',14,-11)
    head:SetPoint('TOPRIGHT',main,'TOPRIGHT',-14,-11)
    -- Compact two-row Materials toolbar. The atlas viewer style buttons stay
    -- in the title line; search is intentionally short rather than spanning
    -- the workbench. Anchors are refreshed on panel resize, not tied to the
    -- last window size or Art Lab texture dimensions.
    local modeInventory=drawButton(main,'Inventory',function()opts.view='inventory';page:Refresh()end)
    local modeLedger=drawButton(main,'Ledger',function()opts.view='ledger';page:Refresh()end)
    local combineNames=drawButton(main,'Combine: On',function()
        opts.combineNames=not opts.combineNames
        page:Refresh()
    end)
    local scope=drawButton(main,'All Alts',function()
        if not AF:IsModuleEnabled('selfFound') then opts.scope='all'
        elseif opts.scope=='all' then opts.scope='expedition'
        elseif opts.scope=='expedition' then opts.scope='eligible'
        else opts.scope='all' end
        page:Refresh()
    end)
    local storage=drawButton(main,'Bags + Bank',function()
        opts.storage=opts.storage=='all' and 'bags' or (opts.storage=='bags' and 'bank' or 'all');page:Refresh()
    end)
    local professionMenu
    local profession=drawButton(main,'Profession: All',function()
        if professionMenu then professionMenu:SetShown(not professionMenu:IsShown()) end
    end)
    professionMenu=UI:Card(main)
    professionMenu:SetPoint('TOPLEFT',profession,'BOTTOMLEFT',0,-3)
    professionMenu:SetSize(200,268)
    professionMenu:SetFrameLevel(main:GetFrameLevel()+15)
    local profScroll=UI:List(professionMenu,29)
    if UI.InsetWorkshopScrollBar then UI:InsetWorkshopScrollBar(profScroll) end
    profScroll:SetPoint('TOPLEFT',professionMenu,'TOPLEFT',8,-9)
    profScroll:SetPoint('BOTTOMRIGHT',professionMenu,'BOTTOMRIGHT',-23,9)
    professionMenu:Hide()
    local toggles={
        {'Reagents','showReagents'},{'Consumables','showConsumables'},
        {'Potential DE','showDisenchant'},{'Other','showOther'},{'Unknown','showUnknown'}
    }
    local filterBtns={}
    for _,pair in ipairs(toggles) do
        local b=drawButton(main,'',function()opts[pair[2]]=not opts[pair[2]];page:Refresh()end)
        filterBtns[#filterBtns+1]={b=b,label=pair[1],key=pair[2]}
    end
    local search=UI:Input(main,190)
    search:SetHeight(25)
    local searchHint=text(main,'Find item or ID','small',{.47,.36,.22,1})
    searchHint:SetPoint('LEFT',search,'LEFT',10,0)
    searchHint:SetHeight(19)
    if searchHint.EnableMouse then searchHint:EnableMouse(false) end
    local sort=drawButton(main,'Sort: Name',function()
        opts.sort=opts.sort=='name' and 'quantity' or 'name';page:Refresh()
    end)
    local refresh=drawButton(main,'Rescan Bags',function()
        if AF.ScanBags then AF:ScanBags() end
        page:Refresh()
    end)
    local summary=text(main,'', 'small',P.ink)
    summary:SetPoint('TOPLEFT',main,'TOPLEFT',16,-108)
    summary:SetPoint('TOPRIGHT',main,'TOPRIGHT',-16,-108)
    summary:SetHeight(19)
    local function layoutToolbar()
        local usable=max(540,(main:GetWidth() or 870)-28)
        local wide=usable>=775
        local gap=6
        local y1,y2=-43,-74
        -- The title's display-mode controls deliberately remain small.
        modeLedger:ClearAllPoints()
        modeLedger:SetPoint('TOPRIGHT',main,'TOPRIGHT',-14,-8)
        modeLedger:SetSize(76,24)
        modeInventory:ClearAllPoints()
        modeInventory:SetPoint('RIGHT',modeLedger,'LEFT',-6,0)
        modeInventory:SetSize(87,24)
        combineNames:ClearAllPoints()
        combineNames:SetPoint('RIGHT',modeInventory,'LEFT',-8,0)
        combineNames:SetSize(112,24)
        local controls={{scope,89},{storage,105},{profession,155},{search,0}}
        if wide then controls[#controls+1]={sort,98} end
        controls[#controls+1]={refresh,108}
        local totalFixed=0
        for _,pair in ipairs(controls) do totalFixed=totalFixed+pair[2] end
        local searchWidth=max(130,min(218,usable-totalFixed-gap*(#controls-1)))
        local x=14
        for _,pair in ipairs(controls) do
            local control,w=pair[1],pair[2]
            if control==search then w=searchWidth end
            control:ClearAllPoints()
            control:SetPoint('TOPLEFT',main,'TOPLEFT',x,y1)
            control:SetSize(w,25)
            x=x+w+gap
        end
        local sortSpace=0
        if not wide then
            sortSpace=103+gap
            sort:ClearAllPoints()
            sort:SetPoint('TOPRIGHT',main,'TOPRIGHT',-14,y2)
            sort:SetSize(103,24)
        end
        local filtersWidth=usable-sortSpace
        local buttonGap=6
        local filterW=(filtersWidth-(#filterBtns-1)*buttonGap)/#filterBtns
        local filterX=14
        for _,f in ipairs(filterBtns) do
            f.b:ClearAllPoints()
            f.b:SetPoint('TOPLEFT',main,'TOPLEFT',filterX,y2)
            f.b:SetSize(filterW,24)
            filterX=filterX+filterW+buttonGap
        end
    end
    main:SetScript('OnSizeChanged',layoutToolbar)
    layoutToolbar()
    -- The two browsing canvases share exactly the same geometry. Only one
    -- remains visible; neither affects the snapshot schema.
    local inventory=CreateFrame('Frame',nil,main)
    inventory:SetPoint('TOPLEFT',main,'TOPLEFT',15,-132)
    inventory:SetPoint('BOTTOMRIGHT',main,'BOTTOMRIGHT',-15,110)
    local ledger=CreateFrame('Frame',nil,main)
    ledger:SetAllPoints(inventory)
    local function surface(frame)
        local tx=frame:CreateTexture(nil,'BACKGROUND')
        tx:SetAllPoints(frame);tx:SetColorTexture(.80,.68,.47,.20)
        return tx
    end
    surface(inventory);surface(ledger)
    local function createScroll(host,top)
        UI.listSerial=(UI.listSerial or 0)+1
        local name='AFMaterialList'..UI.listSerial
        local sc=CreateFrame('ScrollFrame',name,host,'UIPanelScrollFrameTemplate')
        sc:SetPoint('TOPLEFT',host,'TOPLEFT',3,-top)
        sc:SetPoint('BOTTOMRIGHT',host,'BOTTOMRIGHT',-26,2)
        sc.afScrollBar=(_G and _G[name..'ScrollBar']) or sc.ScrollBar
        if UI.InsetWorkshopScrollBar then UI:InsetWorkshopScrollBar(sc) end
        local child=CreateFrame('Frame',nil,sc)
        child:SetSize(200,1);sc:SetScrollChild(child)
        return sc,child
    end
    local gridScroll,gridChild=createScroll(inventory,0)
    local tableHead=CreateFrame('Frame',nil,ledger)
    tableHead:SetPoint('TOPLEFT',ledger,'TOPLEFT',4,-1)
    tableHead:SetPoint('TOPRIGHT',ledger,'TOPRIGHT',-26,-1)
    tableHead:SetHeight(24)
    local headingBG=tableHead:CreateTexture(nil,'BACKGROUND')
    headingBG:SetAllPoints(tableHead);headingBG:SetColorTexture(.25,.17,.095,.75)
    local coldefs={{'Material',.05},{'Total',.55},{'Bags',.66},{'Bank',.75},{'Alts',.84}}
    for _,col in ipairs(coldefs) do
        local label=text(tableHead,col[1],'small',P.pale)
        label:SetPoint('LEFT',tableHead,'LEFT',10,0) -- positioned precisely by headerLayout
        label:SetHeight(22)
        label.afFraction=col[2]
        tableHead[col[1]]=label
    end
    local ledgerScroll,ledgerChild=createScroll(ledger,27)
    -- Selected material always has its own short location ledger, regardless
    -- of whether the browsing mode is icon grid or table.
    local selectedBar=CreateFrame('Frame',nil,main)
    selectedBar:SetPoint('BOTTOMLEFT',main,'BOTTOMLEFT',16,18)
    selectedBar:SetPoint('BOTTOMRIGHT',main,'BOTTOMRIGHT',-16,18)
    selectedBar:SetHeight(82)
    UI:Background(selectedBar,P.leather,true)
    local selectedIcon=selectedBar:CreateTexture(nil,'ARTWORK')
    selectedIcon:SetPoint('TOPLEFT',selectedBar,'TOPLEFT',11,-11);selectedIcon:SetSize(35,35)
    local selectedRarity=rarityBorder(selectedBar,selectedIcon,1)
    local selectedQuality=text(selectedBar,'','small',P.pale)
    selectedQuality:SetPoint('TOPRIGHT',selectedBar,'TOPRIGHT',-12,-9)
    selectedQuality:SetSize(85,18)
    selectedQuality:SetJustifyH('RIGHT')
    local selectedName=text(selectedBar,'Select a recorded material','small',P.gold)
    selectedName:SetPoint('TOPLEFT',selectedBar,'TOPLEFT',53,-9)
    selectedName:SetPoint('TOPRIGHT',selectedBar,'TOPRIGHT',-100,-9)
    selectedName:SetHeight(18)
    selectedName:SetWordWrap(false)
    local detail=text(selectedBar,'','small',P.pale)
    detail:SetPoint('TOPLEFT',selectedBar,'TOPLEFT',53,-29)
    detail:SetPoint('BOTTOMRIGHT',selectedBar,'BOTTOMRIGHT',-10,5)
    detail:SetJustifyV('TOP')
    local gridPool,ledgerPool={},{}
    local CELL_H,CELL_W,ROW_H=87,86,31
    local currentRows={}
    local function toolTip(self,entry)
        if not GameTooltip or not entry then return end
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
        local grouped=entry.parts and #entry.parts>1
        if not grouped and entry.meta.link and GameTooltip.SetHyperlink then
            local ok=pcall(GameTooltip.SetHyperlink,GameTooltip,entry.meta.link)
            if not ok then GameTooltip:SetText(entry.meta.name or 'Item') end
        else GameTooltip:SetText(entry.meta.name or ('Item #'..entry.id),1,.82,.5) end
        GameTooltip:AddLine('Recorded: '..entry.count..'  (bags '..entry.bags..', bank '..entry.bank..')',.9,.85,.7)
        if grouped then
            GameTooltip:AddLine(#entry.parts..' separate item IDs grouped for display',1,.81,.48,true)
            for i,part in ipairs(entry.parts) do
                if i>5 then GameTooltip:AddLine('...and '..(#entry.parts-i+1)..' more IDs',.78,.73,.64);break end
                GameTooltip:AddLine('ID '..part.id..': x'..part.count,.88,.80,.66)
            end
            GameTooltip:AddLine('Crafting requirements still use each original item ID.',.70,.80,.67,true)
        end
        if entry.kind=='disenchant' then GameTooltip:AddLine('Potential disenchant candidate - not verified',1,.71,.38,true) end
        GameTooltip:AddLine('Snapshots may be stale',.75,.7,.6)
        GameTooltip:Show()
    end
    local function makeGridCell()
        local b=CreateFrame('Button',nil,gridChild)
        b:SetSize(CELL_W-6,CELL_H-4)
        local back=b:CreateTexture(nil,'BACKGROUND')
        back:SetAllPoints(b);back:SetColorTexture(.27,.19,.115,.88)
        b.back=back
        local tex=b:CreateTexture(nil,'ARTWORK')
        tex:SetSize(37,37);tex:SetPoint('TOP',b,'TOP',0,-7);b.icon=tex
        b.rarity=rarityBorder(b,tex,2)
        local accent=b:CreateTexture(nil,'BORDER')
        accent:SetPoint('TOPLEFT',b,'TOPLEFT',0,-1)
        accent:SetPoint('BOTTOMLEFT',b,'BOTTOMLEFT',0,1)
        accent:SetWidth(3);b.accent=accent
        -- A compact count badge is anchored to the *icon*, not the tile.
        -- Its lower-right placement uses the space beside/below the icon and
        -- leaves the rarity frame and most of the artwork unobstructed.
        local badge=CreateFrame('Frame',nil,b)
        badge:SetFrameLevel(b:GetFrameLevel()+2)
        badge:SetPoint('BOTTOMRIGHT',tex,'BOTTOMRIGHT',8,-5)
        badge:SetSize(20,16)
        local badgeBack=badge:CreateTexture(nil,'BACKGROUND')
        badgeBack:SetAllPoints(badge)
        badgeBack:SetColorTexture(.08,.055,.037,.94)
        local badgeRule=badge:CreateTexture(nil,'BORDER')
        badgeRule:SetPoint('BOTTOMLEFT',badge,'BOTTOMLEFT',1,1)
        badgeRule:SetPoint('BOTTOMRIGHT',badge,'BOTTOMRIGHT',-1,1)
        badgeRule:SetHeight(1)
        badgeRule:SetColorTexture(.82,.64,.34,.72)
        local count=text(badge,'','small',P.pale)
        count:SetAllPoints(badge)
        count:SetJustifyH('CENTER')
        count:SetJustifyV('MIDDLE')
        count:SetWordWrap(false)
        b.count=count;b.countBadge=badge
        local name=text(b,'','small',P.pale)
        name:SetPoint('BOTTOMLEFT',b,'BOTTOMLEFT',3,3)
        name:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-3,3)
        name:SetHeight(25);name:SetJustifyH('CENTER');name:SetWordWrap(true);b.name=name
        b:SetScript('OnClick',function(self)
            if self.entry then current.selected=self.entry.id;page:Refresh() end
        end)
        b:SetScript('OnEnter',function(self)toolTip(self,self.entry)end)
        b:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end)
        return b
    end
    local function makeLedgerRow()
        local b=CreateFrame('Button',nil,ledgerChild)
        b:SetHeight(ROW_H-2)
        local back=b:CreateTexture(nil,'BACKGROUND')
        back:SetAllPoints(b);back:SetColorTexture(.83,.72,.51,.35);b.back=back
        local ic=b:CreateTexture(nil,'ARTWORK');ic:SetPoint('LEFT',b,'LEFT',7,0);ic:SetSize(23,23);b.icon=ic
        b.rarity=rarityBorder(b,ic,1)
        local accent=b:CreateTexture(nil,'BORDER')
        accent:SetPoint('TOPLEFT',b,'TOPLEFT',0,-1)
        accent:SetPoint('BOTTOMLEFT',b,'BOTTOMLEFT',0,1)
        accent:SetWidth(3);b.accent=accent
        b.cells={}
        for i=1,5 do
            local c=text(b,'','small',P.ink)
            c:SetHeight(22);c:SetWordWrap(false)
            b.cells[i]=c
        end
        b:SetScript('OnClick',function(self)
            if self.entry then current.selected=self.entry.id;page:Refresh() end
        end)
        b:SetScript('OnEnter',function(self)toolTip(self,self.entry)end)
        b:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end)
        return b
    end
    local rendering=false
    local function renderLists()
        if rendering or not page:IsShown() then return end
        rendering=true
        local entries=current.entries or {}
        local width=max(200,gridScroll:GetWidth() or 800)
        local columns=max(2,floor((width-8)/CELL_W))
        local gridRowCount=math.ceil(#entries/columns)
        gridChild:SetWidth(width);gridChild:SetHeight(max(1,gridRowCount*CELL_H))
        local y=gridScroll:GetVerticalScroll() or 0
        local start=max(0,floor(y/CELL_H)-1)
        local visibleRows=max(2,math.ceil((gridScroll:GetHeight() or 330)/CELL_H)+2)
        local visibleCount=visibleRows*columns
        for i=1,visibleCount do
            local rowStart=start+floor((i-1)/columns)
            local col=(i-1)%columns
            local entry=entries[rowStart*columns+col+1]
            local b=gridPool[i]
            if not b then b=makeGridCell();gridPool[i]=b end
            if entry then
                b.entry=entry;b:ClearAllPoints()
                b:SetPoint('TOPLEFT',gridChild,'TOPLEFT',5+col*CELL_W,-rowStart*CELL_H)
                b:SetWidth(CELL_W-6)
                b.icon:SetTexture(entry.meta.icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
                local qr,qg,qb,qKnown=paintRarity(b.rarity,entry.meta.quality)
                b.accent:SetColorTexture(qr,qg,qb,qKnown and .9 or .32)
                b.name:SetTextColor(qKnown and qr or P.pale[1],qKnown and qg or P.pale[2],qKnown and qb or P.pale[3])
                local stackLabel=entry.count>1 and ('x'..entry.count) or ''
                b.count:SetText(stackLabel)
                if entry.count>1 then
                    -- Measure the rendered FontString, never reserve a fixed
                    -- 42px strip for small stacks like x2 or x5.
                    local labelWidth=b.count:GetStringWidth()
                    if type(labelWidth)~='number' or labelWidth<=0 then
                        labelWidth=#stackLabel*7
                    end
                    b.countBadge:SetWidth(max(19,min(53,math.ceil(labelWidth+8))))
                    b.countBadge:Show()
                else
                    b.countBadge:Hide()
                end
                b.name:SetText(entry.meta.name)
                if entry.id==current.selected then b.back:SetColorTexture(.57,.37,.15,.90)
                else b.back:SetColorTexture(.27,.19,.115,.88) end
                b:Show()
            else b.entry=nil;b:Hide() end
        end
        for i=visibleCount+1,#gridPool do gridPool[i]:Hide() end
        local ledgerW=max(230,ledgerScroll:GetWidth() or 850)
        ledgerChild:SetWidth(ledgerW);ledgerChild:SetHeight(max(1,#entries*ROW_H))
        local ly=ledgerScroll:GetVerticalScroll() or 0
        local first=max(0,floor(ly/ROW_H)-1)
        local needed=max(2,math.ceil((ledgerScroll:GetHeight() or 320)/ROW_H)+2)
        for i=1,needed do
            local idx=first+i
            local entry=entries[idx]
            local b=ledgerPool[i]
            if not b then b=makeLedgerRow();ledgerPool[i]=b end
            if entry then
                b.entry=entry;b:ClearAllPoints()
                b:SetPoint('TOPLEFT',ledgerChild,'TOPLEFT',2,-(idx-1)*ROW_H)
                b:SetWidth(ledgerW-4)
                b.icon:SetTexture(entry.meta.icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
                local qr,qg,qb,qKnown=paintRarity(b.rarity,entry.meta.quality)
                b.accent:SetColorTexture(qr,qg,qb,qKnown and .91 or .27)
                b.cells[1]:SetText(entry.meta.name..((entry.parts and #entry.parts>1) and ('  ('..#entry.parts..' IDs)') or ''))
                b.cells[2]:SetText(tostring(entry.count))
                b.cells[3]:SetText(tostring(entry.bags))
                b.cells[4]:SetText(tostring(entry.bank))
                b.cells[5]:SetText(tostring(entry.altCount))
                local startX={34,.56*ledgerW,.67*ledgerW,.76*ledgerW,.85*ledgerW}
                local endX={.54*ledgerW,.65*ledgerW,.74*ledgerW,.83*ledgerW,ledgerW-7}
                for j=1,5 do
                    local t=b.cells[j]
                    t:ClearAllPoints();t:SetPoint('LEFT',b,'LEFT',startX[j],0)
                    t:SetWidth(max(30,endX[j]-startX[j]))
                    t:SetJustifyH(j==1 and 'LEFT' or 'RIGHT')
                end
                if entry.id==current.selected then b.back:SetColorTexture(.76,.57,.30,.68)
                else b.back:SetColorTexture(.83,.72,.51,(idx%2==0) and .24 or .43) end
                b:Show()
            else b.entry=nil;b:Hide() end
        end
        for i=needed+1,#ledgerPool do ledgerPool[i]:Hide() end
        if UI.ListScrollBar then
            for _,sc in ipairs({gridScroll,ledgerScroll}) do
                local bar=UI:ListScrollBar(sc)
                if bar then bar:SetShown(sc==gridScroll and gridRowCount*CELL_H>(sc:GetHeight() or 0)+3 or
                    sc==ledgerScroll and #entries*ROW_H>(sc:GetHeight() or 0)+3) end
            end
        end
        rendering=false
    end
    for _,sc in ipairs({gridScroll,ledgerScroll}) do
        if sc.HookScript then
            sc:HookScript('OnVerticalScroll',function()renderLists()end)
            sc:HookScript('OnSizeChanged',function()renderLists()end)
        end
    end
    local function headerLayout()
        local w=tableHead:GetWidth() or 850
        local fractions={.045,.56,.67,.76,.85}
        for i,col in ipairs(coldefs) do
            local t=tableHead[col[1]]
            if t then
                t:ClearAllPoints();t:SetPoint('LEFT',tableHead,'LEFT',fractions[i]*w,0)
                t:SetWidth(i==1 and .47*w or max(45,.09*w))
            end
        end
        renderLists()
    end
    tableHead:SetScript('OnSizeChanged',headerLayout)
    page:HookScript('OnHide',function() professionMenu:Hide() end)
    search:SetScript('OnTextChanged',function(self,userInput)
        searchHint:SetShown((self:GetText() or '')=='')
        if userInput then page:Refresh() end
    end)
    searchHint:SetShown((search:GetText() or '')=='')
    local itemLoad=CreateFrame('Frame',nil,page)
    itemLoad:RegisterEvent('GET_ITEM_INFO_RECEIVED')
    itemLoad:SetScript('OnEvent',function()
        if page:IsShown() and page.Refresh then page:Refresh() end
    end)
    function page:Refresh()
        inventory:SetShown(opts.view=='inventory')
        ledger:SetShown(opts.view=='ledger')
        UI:SetButtonSelected(modeInventory,opts.view=='inventory')
        UI:SetButtonSelected(modeLedger,opts.view=='ledger')
        local themedText=UI.ThemeTokens and UI:ThemeTokens().buttonText or P.pale
        modeInventory.label:SetTextColor(unpack(themedText))
        modeLedger.label:SetTextColor(unpack(themedText))
        combineNames.label:SetText(opts.combineNames and 'Combine: On' or 'Combine: Off')
        UI:SetButtonSelected(combineNames,opts.combineNames)
        combineNames.label:SetTextColor(unpack(themedText))
        if not AF:IsModuleEnabled('selfFound') then opts.scope='all' end
        scope:SetShown(AF:IsModuleEnabled('selfFound'))
        scope.label:SetText(opts.scope=='all' and 'All Alts' or (opts.scope=='expedition' and 'Enrolled' or 'Eligible'))
        storage.label:SetText(opts.storage=='all' and 'Bags + Bank' or opts.storage=='bags' and 'Bags only' or 'Bank only')
        profession.label:SetText('Profession: '..(opts.profession=='all' and 'All' or opts.profession))
        local profEntries={{key='all',label='All professions'}}
        for _,prof in ipairs(AF:GetWorkshopProfessions(opts.scope=='eligible' and 'expedition' or opts.scope)) do
            profEntries[#profEntries+1]={key=prof.name,label=prof.name}
        end
        UI:FillList(profScroll,profEntries,function(e)
            opts.profession=e.key
            professionMenu:Hide()
            page:Refresh()
        end,opts.profession)
        sort.label:SetText(opts.sort=='name' and 'Sort: Name' or 'Sort: Qty')
        for _,f in ipairs(filterBtns) do
            f.b.label:SetText((opts[f.key] and '[x] ' or '[ ] ')..f.label)
            UI:SetButtonSelected(f.b,opts[f.key])
            f.b.label:SetTextColor(unpack(UI.ThemeTokens and UI:ThemeTokens().buttonText or P.pale))
        end
        local totals,owners,scans,_,chars=buildSnapshots(opts.scope,opts.storage)
        local policy=AF:GetExpeditionPlanningPolicy('expedition',AF:GetCurrentKey())
        if opts.scope=='all' then
            subtitle:SetText('All recorded alts. This inventory view is not charter-qualified.')
        elseif opts.scope=='expedition' then
            subtitle:SetText(policy.mode=='personal' and 'Enrolled roster: totals include alts whose stock is NOT shareable.' or
                'Enrolled roster: membership only; item provenance not verified.')
        else
            subtitle:SetText('Eligible for current adventurer: '..policy.label..'. Origins unverified.')
        end
        local recipeInputs,byProfession=knownReagentSources(chars)
        local query=(search:GetText() or ''):lower()
        local entries={}
        for id,total in pairs(totals) do
            local meta=Info(id)
            local kind=classification(meta,recipeInputs[id])
            local matched=(opts.profession=='all' or (byProfession[id] and byProfession[id][opts.profession])
                or (kind=='reagents' and inferredProfession(meta,opts.profession)))
            if opts['show'..({reagents='Reagents',consumables='Consumables',disenchant='Disenchant',other='Other',unknown='Unknown'})[kind]]
                and matched and (query=='' or meta.name:lower():find(query,1,true) or tostring(id):find(query,1,true)) then
                local ownersFor=owners[id] or {bags=0,bank=0,chars={}}
                local altCount=0
                for _ in pairs(ownersFor.chars) do altCount=altCount+1 end
                entries[#entries+1]={id=id,count=total,meta=meta,kind=kind,
                    bags=ownersFor.bags,bank=ownersFor.bank,altCount=altCount,owners=ownersFor.chars}
            end
        end
        local originalTypes=#entries
        if opts.combineNames then entries=groupRecordedEntries(entries) end
        table.sort(entries,function(a,b)
            if opts.sort=='quantity' and a.count~=b.count then return a.count>b.count end
            local an,bn=a.meta.name:lower(),b.meta.name:lower()
            return an==bn and a.id<b.id or an<bn
        end)
        current.entries=entries;current.scans=scans
        local selectedEntry
        for _,e in ipairs(entries) do
            if entryContainsId(e,current.selected) then selectedEntry=e;break end
        end
        current.selected=selectedEntry and selectedEntry.id or (entries[1] and entries[1].id)
        local total=0
        for _,e in ipairs(entries) do total=total+e.count end
        local typeLabel=(opts.combineNames and originalTypes~=#entries) and
            string.format('%d groups / %d item IDs',#entries,originalTypes) or
            string.format('%d material types',#entries)
        summary:SetText(string.format('%s  |  %d recorded items  |  %d storage snapshots  |  %d registered adventurers',
            typeLabel,total,scans,#chars))
        local active
        for _,e in ipairs(entries) do if e.id==current.selected then active=e;break end end
        if active then
            selectedIcon:SetTexture(active.meta.icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
            local qr,qg,qb,qKnown=paintRarity(selectedRarity,active.meta.quality)
            selectedQuality:SetText((qKnown and QUALITY_LABELS[active.meta.quality]) or '')
            selectedQuality:SetTextColor(qr,qg,qb)
            selectedName:SetText(active.meta.name..'  x'..active.count)
            selectedName:SetTextColor(qKnown and qr or P.gold[1],qKnown and qg or P.gold[2],qKnown and qb or P.gold[3])
            local ownersText={}
            local people={}
            for _,c in ipairs(chars) do if active.owners[c.key] then people[#people+1]=active.owners[c.key] end end
            for i,rec in ipairs(people) do
                if i>4 then ownersText[#ownersText+1]='+'..(#people-i+1)..' others';break end
                ownersText[#ownersText+1]=rec.name..' (bags '..rec.bags..', bank '..rec.bank..'; '..timeText(rec.scanned)..')'
            end
            local desc=table.concat(ownersText,'  |  ')
            if opts.scope=='eligible' then desc='Eligibility only; item origin UNVERIFIED.  '..desc end
            if active.parts and #active.parts>1 then
                local parts={}
                for i,part in ipairs(active.parts) do
                    if i>4 then parts[#parts+1]='+'..(#active.parts-i+1)..' IDs';break end
                    parts[#parts+1]='#'..part.id..' x'..part.count
                end
                desc=#active.parts..' distinct item IDs ('..table.concat(parts,', ')..')  |  '..desc
            end
            if active.kind=='disenchant' then desc='Potential DE only; eligibility not verified.  '..desc end
            detail:SetText(desc)
        else
            selectedIcon:SetTexture('Interface\\Icons\\INV_Misc_QuestionMark')
            paintRarity(selectedRarity,nil)
            selectedQuality:SetText('')
            selectedName:SetTextColor(P.gold[1],P.gold[2],P.gold[3])
            selectedName:SetText('No matching recorded materials')
            detail:SetText(scans==0 and 'Log into a character and scan bags or visit the bank to record its contents.' or
                'Try enabling another category, choosing All professions, or clearing search.')
        end
        if gridScroll.SetVerticalScroll then
            -- Keep user position while filtering but clamp to new range.
            local cols=max(2,floor((max(200,gridScroll:GetWidth() or 800)-8)/CELL_W))
            local h=math.ceil(#entries/cols)*CELL_H
            gridScroll:SetVerticalScroll(min(gridScroll:GetVerticalScroll() or 0,max(0,h-(gridScroll:GetHeight() or 0))))
            ledgerScroll:SetVerticalScroll(min(ledgerScroll:GetVerticalScroll() or 0,max(0,#entries*ROW_H-(ledgerScroll:GetHeight() or 0))))
        end
        renderLists()
    end
    -- Lay out native ledger column headers on the first render, even if the
    -- frame's initial size was resolved before OnSizeChanged was installed.
    headerLayout()
    page:Refresh()
end
