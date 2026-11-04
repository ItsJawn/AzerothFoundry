-- Azeroth Foundry v0.5.16 — Adventurer's Notebook.
-- A layout-only replacement for the original Notes page. Original note fields,
-- auto-save semantics, record IDs and character ownership are preserved.
local _, AF = ...
local UI = AF.UI
local P = UI.palette

local CATEGORIES = {'General','Questing','Crafting','Exploration','Collections','Characters','Other'}
local FILTERS = {'All categories','General','Questing','Crafting','Exploration','Collections','Characters','Other'}
local function Now() return type(time)=='function' and time() or 0 end
local function B(parent,label,fn,warning)
    return UI.WorkshopButton(parent,label,fn,warning and 'caution' or nil)
end
local function Label(parent,text,size,color)
    local label=UI:Text(parent,size or 'small',color or P.ink)
    label:SetText(text or '')
    label:SetJustifyV('MIDDLE')
    return label
end
local function Section(parent,text)
    local s=UI:SectionTitle(parent,text)
    s:SetPoint('TOPLEFT',parent,'TOPLEFT',13,-10)
    s:SetPoint('TOPRIGHT',parent,'TOPRIGHT',-12,-10)
    return s
end
local function Trim(s)
    return tostring(s or ''):match('^%s*(.-)%s*$')
end
local function Short(s,max)
    s=tostring(s or '')
    max=max or 45
    return #s<=max and s or (s:sub(1,max-3)..'...')
end
local function Stamp(t)
    if not t or t==0 then return 'Not recorded' end
    if type(date)=='function' then return date('%b %d, %Y %H:%M',t) end
    return 'Saved'
end
local function NoteCategory(n)
    for _,name in ipairs(CATEGORIES) do if n.afCategory==name then return name end end
    return 'General'
end
local function NoteLinks(n)
    if type(n.afReferences)~='table' then n.afReferences={} end
    return n.afReferences
end
local function NoteText(n)
    return table.concat({n.title or '',n.body or '',n.afTags or '',NoteCategory(n)},' '):lower()
end
local function AddLink(note,ref)
    local refs=NoteLinks(note)
    if #refs>=90 then return false,'This note has reached its reference limit (90).' end
    for _,r in ipairs(refs) do
        if r.kind==ref.kind and r.id==ref.id and (ref.kind~='location' or (r.mapID==ref.mapID and math.abs((r.x or 0)-(ref.x or 0))<.0001 and math.abs((r.y or 0)-(ref.y or 0))<.0001)) then
            return false,'Already linked to this note.'
        end
    end
    refs[#refs+1]=ref
    note.updated=Now()
    return true
end
local function MapLocation()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil,'Map coordinates unavailable on this client.' end
    local ok,mapID=pcall(C_Map.GetBestMapForUnit,'player')
    if not ok or type(mapID)~='number' then return nil,'Current map unavailable.' end
    local success,vec=pcall(C_Map.GetPlayerMapPosition,mapID,'player')
    if not success or not vec then return nil,'Player coordinates unavailable here.' end
    local x,y
    if type(vec.GetXY)=='function' then
        local valid; valid,x,y=pcall(vec.GetXY,vec)
        if not valid then x=nil end
    else x,y=vec.x,vec.y end
    if type(x)~='number' or type(y)~='number' or x<0 or x>1 or y<0 or y>1 then
        return nil,'Position is not currently reported by the map.'
    end
    local name=type(GetZoneText)=='function' and GetZoneText() or 'Location'
    if C_Map.GetMapInfo then
        local yes,info=pcall(C_Map.GetMapInfo,mapID)
        if yes and info and type(info.name)=='string' then name=info.name end
    end
    return {kind='location',id='map:'..mapID..':'..math.floor(x*10000)..':'..math.floor(y*10000),
        mapID=mapID,x=x,y=y,label=name..(' (%.1f, %.1f)'):format(x*100,y*100),created=Now()}
end
local function TargetNPC()
    if not UnitExists or not UnitExists('target') then return nil,'Target an NPC first.' end
    if UnitIsPlayer and UnitIsPlayer('target') then return nil,'Player targets are not NPCs.' end
    local name=type(UnitName)=='function' and UnitName('target') or nil
    if not name or name=='' then return nil,'NPC name unavailable.' end
    local guid=type(UnitGUID)=='function' and UnitGUID('target') or nil
    local npcID
    if type(guid)=='string' then
        local parts={}
        for part in guid:gmatch('[^-]+') do parts[#parts+1]=part end
        if parts[1]=='Creature' or parts[1]=='Vehicle' then npcID=tonumber(parts[6]) end
    end
    return {kind='npc',id=npcID and tostring(npcID) or ('name:'..name),npcID=npcID,
        label=name,created=Now()}
end
local function LinkFromText(value,kind)
    local s=Trim(value)
    if kind=='npc' then
        if #s<2 or #s>90 then return nil,'Enter an NPC name (2-90 characters).' end
        return {kind='npc',id='name:'..s:lower(),label=s,created=Now()}
    end
    local id=tonumber(s:match('|Hitem:(%d+)') or s:match('^item:(%d+)') or s:match('^(%d+)$'))
    if kind=='quest' then
        id=tonumber(s:match('|Hquest:(%d+)') or s:match('^quest:(%d+)') or s:match('^(%d+)$'))
    end
    if not id or id<1 or id>200000000 or id~=math.floor(id) then
        return nil,kind=='item' and 'Paste an item link or numeric item ID.' or 'Enter a numeric quest ID.'
    end
    local label=(kind=='item' and 'Item #' or 'Quest #')..id
    local hyperlink
    if kind=='item' and type(GetItemInfo)=='function' then
        local ok,name,link=pcall(GetItemInfo,id)
        if ok then
            if type(name)=='string' and name~='' then label=name end
            if type(link)=='string' then hyperlink=link end
        end
    elseif kind=='quest' then
        if C_QuestLog and C_QuestLog.GetTitleForQuestID then
            local ok,name=pcall(C_QuestLog.GetTitleForQuestID,id)
            if ok and type(name)=='string' and name~='' then label=name end
        end
        if type(GetQuestLink)=='function' then
            local ok,link=pcall(GetQuestLink,id)
            if ok and type(link)=='string' then hyperlink=link end
        end
    end
    return {kind=kind,id=tostring(id),label=label,hyperlink=hyperlink,created=Now()}
end
-- Linked References are actionable rows, not just labels. Tooltips are
-- informational and never modify a note, character record, or the item cache.
local function ReferenceTooltip(frame,ref)
    if not (frame and type(ref)=='table' and GameTooltip and GameTooltip.SetOwner) then return false end
    GameTooltip:SetOwner(frame,'ANCHOR_RIGHT')
    if ref.kind=='item' then
        local link=ref.hyperlink or ('item:'..tostring(ref.id or ''))
        if GameTooltip.SetHyperlink then
            local ok=pcall(GameTooltip.SetHyperlink,GameTooltip,link)
            if ok then GameTooltip:Show();return true end
        end
        if GameTooltip.SetItemByID and tonumber(ref.id) then
            local ok=pcall(GameTooltip.SetItemByID,GameTooltip,tonumber(ref.id))
            if ok then GameTooltip:Show();return true end
        end
    elseif ref.kind=='quest' then
        if GameTooltip.SetHyperlink then
            local link=ref.hyperlink or ('quest:'..tostring(ref.id or ''))
            local ok=pcall(GameTooltip.SetHyperlink,GameTooltip,link)
            if ok then GameTooltip:Show();return true end
        end
    elseif ref.kind=='npc' and type(UnitExists)=='function' and UnitExists('target') then
        local targetName=type(UnitName)=='function' and UnitName('target') or nil
        local targetID
        if type(UnitGUID)=='function' then
            local guid=UnitGUID('target')
            if type(guid)=='string' then targetID=tonumber(guid:match('^[^-]+%-[^-]+%-[^-]+%-[^-]+%-(%d+)%-')) end
        end
        local match=(ref.npcID and targetID and tonumber(ref.npcID)==targetID)
            or (not ref.npcID and type(targetName)=='string' and targetName:lower()==tostring(ref.label or ''):lower())
        if match and GameTooltip.SetUnit then
            local ok=pcall(GameTooltip.SetUnit,GameTooltip,'target')
            if ok then GameTooltip:Show();return true end
        end
    end
    if not GameTooltip.SetText then return false end
    GameTooltip:SetText(tostring(ref.label or ref.kind or 'Reference'),1,.81,.44)
    if GameTooltip.AddLine then
        if ref.kind=='npc' then
            GameTooltip:AddLine('Saved NPC reference',.83,.79,.69)
            if ref.npcID then GameTooltip:AddLine('NPC ID: '..tostring(ref.npcID),.83,.79,.69) end
            GameTooltip:AddLine('Live NPC information requires targeting this NPC.',.72,.72,.72,true)
        elseif ref.kind=='location' then
            GameTooltip:AddLine('Saved map: '..tostring(ref.mapID or 'unknown'),.83,.79,.69)
            if type(ref.x)=='number' and type(ref.y)=='number' then
                GameTooltip:AddLine(('Coordinates: %.1f, %.1f'):format(ref.x*100,ref.y*100),.83,.79,.69)
            end
            GameTooltip:AddLine('Click to open this map in the Atlas.',.72,.72,.72,true)
        elseif ref.kind=='quest' then
            GameTooltip:AddLine('Quest ID: '..tostring(ref.id or 'unknown'),.83,.79,.69)
            GameTooltip:AddLine('Click to open its saved Quest Journal entry.',.72,.72,.72,true)
        else
            GameTooltip:AddLine('Item ID: '..tostring(ref.id or 'unknown'),.83,.79,.69)
            GameTooltip:AddLine('Native item tooltip unavailable until the client resolves it.',.72,.72,.72,true)
        end
    end
    GameTooltip:Show()
    return true
end
local function OpenReference(ref,frame)
    if type(ref)~='table' then return false end
    if ref.kind=='item' then
        local payload=type(ref.hyperlink)=='string' and ref.hyperlink:match('|H(.-)|h')
            or ('item:'..tostring(ref.id or ''))
        local caption=ref.hyperlink or ('|H'..payload..'|h['..tostring(ref.label or 'Item')..']|h')
        if type(SetItemRef)=='function' then
            local ok=pcall(SetItemRef,payload,caption,'LeftButton')
            if ok then return true end
        end
        return ReferenceTooltip(frame,ref)
    elseif ref.kind=='quest' then
        if UI.OpenQuestJournalAtQuest and tonumber(ref.id) then
            local ok=pcall(UI.OpenQuestJournalAtQuest,UI,tonumber(ref.id))
            if ok then return true end
        end
        return ReferenceTooltip(frame,ref)
    elseif ref.kind=='location' then
        if type(ref.mapID)~='number' then return ReferenceTooltip(frame,ref) end
        if type(AF.db.settings.atlas)~='table' then AF.db.settings.atlas={} end
        AF.db.settings.atlas.mapID=ref.mapID
        UI:Switch('Exploration')
        local atlas=UI.pageViews and UI.pageViews.Exploration
        if atlas and atlas.Navigate then atlas:Navigate(ref.mapID) end
        -- The saved coordinates are shown in the linked-reference tooltip and
        -- detail pane; opening a map does not claim to create a custom map pin.
        return true
    elseif ref.kind=='npc' then
        return ReferenceTooltip(frame,ref)
    end
    return ReferenceTooltip(frame,ref)
end
-- These helpers are deliberately independent of the view, so data handling can
-- be exercised using simulated clients without constructing the UI.
AF.NoteJournalAddReference=AddLink
AF.NoteJournalCaptureLocation=MapLocation
AF.NoteJournalCaptureTarget=TargetNPC
AF.NoteJournalParseLink=LinkFromText
AF.NoteJournalInspectReference=OpenReference
AF.NoteJournalReferenceTooltip=ReferenceTooltip

function UI:BuildNotes(page)
    local state=AF.db.settings.notebook or {}
    AF.db.settings.notebook=state
    state.filter=state.filter or 'All categories'
    state.scope=state.scope or 'All notes'
    state.search=state.search or ''
    state.listWidth=tonumber(state.listWidth) or 260
    local busy=false
    local currentID=nil
    local pickedReference=nil
    local shownNotes={}
    local displayedLinks={}
    local header=CreateFrame('Frame',nil,page)
    header:SetPoint('TOPLEFT',page,'TOPLEFT',9,-5)
    header:SetPoint('TOPRIGHT',page,'TOPRIGHT',-9,-5)
    header:SetHeight(51)
    header.afThemeSurfaceVariant="intro"
    UI:Background(header,P.leather,true)
    local headerTitle=Label(header,"Adventurer's Notebook",'small',P.gold)
    headerTitle:SetPoint('TOPLEFT',header,'TOPLEFT',12,-7)
    headerTitle:SetSize(250,18)
    local headerInfo=Label(header,'Collect thoughts, record discoveries, and attach references.','small',P.pale)
    headerInfo:SetPoint('TOPLEFT',headerTitle,'BOTTOMLEFT',0,-1)
    headerInfo:SetPoint('RIGHT',header,'RIGHT',-150,0)
    headerInfo:SetHeight(17)
    headerTitle.afThemeColorManaged=true
    headerInfo.afThemeColorManaged=true
    local add=B(header,'+ New Note',function()
        local n=AF:AddNote()
        n.afCategory='General'
        UI.selectedNoteId=n.id
        page:Refresh()
    end)
    add:SetPoint('TOPRIGHT',header,'TOPRIGHT',-10,-11)
    add:SetSize(128,28)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(header,function(_,t)
        local surface,headInk,infoInk=UI:ThemeIntroColors(t)
        headerTitle:SetTextColor(unpack(headInk))
        headerInfo:SetTextColor(unpack(infoInk))
    end) end

    local left=UI:Card(page)
    local mid=UI:Card(page)
    local right=UI:Card(page)
    local grip=CreateFrame('Button',nil,page)
    grip:SetWidth(18)
    grip:SetPoint('TOP',left,'TOPRIGHT',7,0)
    grip:SetPoint('BOTTOM',left,'BOTTOMRIGHT',7,0)
    grip:RegisterForDrag('LeftButton')
    UI:StyleResizeGrip(grip)
    grip:EnableMouse(true)
    local function Layout()
        local width=math.max(720,page:GetWidth() or 980)
        local available=width-48
        local l=math.min(math.max(210,state.listWidth),math.min(365,available-550))
        local r=math.max(222,math.min(285,available*.265))
        if available-l-r<320 then l=math.max(198,available-r-320) end
        left:ClearAllPoints();left:SetPoint('TOPLEFT',page,'TOPLEFT',9,-64)
        left:SetPoint('BOTTOMLEFT',page,'BOTTOMLEFT',9,10);left:SetWidth(l)
        right:ClearAllPoints();right:SetPoint('TOPRIGHT',page,'TOPRIGHT',-9,-64)
        right:SetPoint('BOTTOMRIGHT',page,'BOTTOMRIGHT',-9,10);right:SetWidth(r)
        mid:ClearAllPoints();mid:SetPoint('TOPLEFT',left,'TOPRIGHT',20,0)
        mid:SetPoint('BOTTOMRIGHT',right,'BOTTOMLEFT',-8,0)
        state.listWidth=l
    end
    Layout()
    page:SetScript('OnSizeChanged',function() Layout() end)
    local dragX,origWidth
    grip:SetScript('OnDragStart',function()
        dragX=GetCursorPosition and GetCursorPosition() or 0
        origWidth=left:GetWidth()
    end)
    grip:SetScript('OnDragStop',function()
        dragX=nil
        state.listWidth=left:GetWidth()
    end)
    grip:SetScript('OnUpdate',function()
        if not dragX or not GetCursorPosition then return end
        local x=GetCursorPosition()
        local scale=page:GetEffectiveScale()
        state.listWidth=math.max(198,math.min(365,origWidth+(x-dragX)/math.max(.01,scale)))
        Layout()
    end)

    Section(left,'Notebook Library')
    local search=UI:Input(left)
    search:SetPoint('TOPLEFT',left,'TOPLEFT',14,-49)
    search:SetPoint('TOPRIGHT',left,'TOPRIGHT',-14,-49)
    search:SetHeight(27)
    search:SetText(state.search)
    local scope=B(left,'Scope: All notes',function()
        state.scope=state.scope=='All notes' and 'Account-wide' or (state.scope=='Account-wide' and 'Current alt' or 'All notes')
        page:Refresh()
    end)
    scope:SetPoint('TOPLEFT',left,'TOPLEFT',14,-83)
    scope:SetPoint('TOPRIGHT',left,'TOPRIGHT',-14,-83)
    scope:SetHeight(26)
    local category=B(left,'Category: All categories',function()
        local idx=1
        for i,k in ipairs(FILTERS) do if k==state.filter then idx=i;break end end
        state.filter=FILTERS[idx%#FILTERS+1]
        page:Refresh()
    end)
    category:SetPoint('TOPLEFT',left,'TOPLEFT',14,-113)
    category:SetPoint('TOPRIGHT',left,'TOPRIGHT',-14,-113)
    category:SetHeight(26)
    local count=Label(left,'','small',P.ink)
    count:SetPoint('TOPLEFT',left,'TOPLEFT',16,-146)
    count:SetPoint('TOPRIGHT',left,'TOPRIGHT',-12,-146)
    count:SetHeight(20)
    local list=UI:List(left,44)
    list:SetPoint('TOPLEFT',left,'TOPLEFT',12,-173)
    list:SetPoint('BOTTOMRIGHT',left,'BOTTOMRIGHT',-29,40)
    if UI.InsetWorkshopScrollBar then UI:InsetWorkshopScrollBar(list) end
    local foot=Label(left,'Pinned notes first  |  Drag divider to resize','small',P.ink)
    foot:SetPoint('BOTTOMLEFT',left,'BOTTOMLEFT',13,12)
    foot:SetPoint('BOTTOMRIGHT',left,'BOTTOMRIGHT',-10,12)
    foot:SetHeight(20)

    Section(mid,'Writing Desk')
    local title=UI:Input(mid)
    title:SetPoint('TOPLEFT',mid,'TOPLEFT',16,-50)
    title:SetPoint('TOPRIGHT',mid,'TOPRIGHT',-14,-50)
    title:SetHeight(29)
    local owner=B(mid,'Account-wide',function()
        local n=AF:FindRecord(AF.db.notes,UI.selectedNoteId)
        if not n then return end
        n.owner=AF:CycleOwner(n.owner);n.updated=Now();page:Refresh()
    end)
    owner:SetPoint('TOPLEFT',mid,'TOPLEFT',15,-91)
    owner:SetPoint('TOPRIGHT',mid,'TOP',-4,-91)
    owner:SetHeight(25)
    local setCategory=B(mid,'General',function()
        local n=AF:FindRecord(AF.db.notes,UI.selectedNoteId)
        if not n then return end
        local idx=1
        for i,name in ipairs(CATEGORIES) do if name==NoteCategory(n) then idx=i;break end end
        n.afCategory=CATEGORIES[idx%#CATEGORIES+1];n.updated=Now();page:Refresh()
    end)
    setCategory:SetPoint('TOPLEFT',mid,'TOP',4,-91)
    setCategory:SetPoint('TOPRIGHT',mid,'TOPRIGHT',-15,-91)
    setCategory:SetHeight(25)
    local tagsLabel=Label(mid,'Tags (comma-separated)','small',P.ink)
    tagsLabel:SetPoint('TOPLEFT',mid,'TOPLEFT',16,-131)
    tagsLabel:SetSize(245,19)
    local tags=UI:Input(mid)
    tags:SetPoint('TOPLEFT',mid,'TOPLEFT',16,-155)
    tags:SetPoint('TOPRIGHT',mid,'TOPRIGHT',-15,-155)
    tags:SetHeight(28)
    local bodyLabel=Label(mid,'Journal entry','small',P.ink)
    bodyLabel:SetPoint('TOPLEFT',mid,'TOPLEFT',16,-196)
    bodyLabel:SetPoint('TOPRIGHT',mid,'TOPRIGHT',-166,-196)
    bodyLabel:SetHeight(20)
    local body
    local mode=B(mid,'Lock / Read',function()
        local n=AF:FindRecord(AF.db.notes,UI.selectedNoteId)
        if not n then return end
        if not n.afLocked then
            -- Commit the editor buffer before hiding it. The original note text
            -- is retained, including WoW hyperlink escapes and line breaks.
            n.body=body.edit:GetText() or ''
            body.edit:ClearFocus()
            title:ClearFocus()
            tags:ClearFocus()
        end
        n.afLocked=not n.afLocked
        n.updated=Now()
        page:Refresh()
    end)
    mode:SetPoint('TOPRIGHT',mid,'TOPRIGHT',-15,-191)
    mode:SetSize(144,26)
    body=UI:Multiline(mid)
    body:SetPoint('TOPLEFT',mid,'TOPLEFT',17,-225)
    body:SetPoint('BOTTOMRIGHT',mid,'BOTTOMRIGHT',-28,56)
    body:SetScript('OnSizeChanged',function() UI:ResizeEditor(body.edit) end)
    if UI.InsetWorkshopScrollBar then UI:InsetWorkshopScrollBar(body) end

    -- The original small ChatFontNormal has an outline/heavy weight that can
    -- be difficult to read on parchment. Prefer Blizzard's own clean body
    -- font at a slightly larger size; don't bundle or replace any fonts.
    local cleanFont=(GameFontNormal and GameFontNormal.GetFont and select(1,GameFontNormal:GetFont())) or STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF'
    if body.edit.SetFont then body.edit:SetFont(cleanFont,15,'') end
    body.edit:SetTextColor(.18,.12,.065)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(body.edit,function(editor,t)
        local c=t.ink;editor:SetTextColor(c[1],c[2],c[3],1)
    end) end
    if body.edit.SetTextInsets then body.edit:SetTextInsets(8,8,8,7) end
    if body.edit.SetSpacing then body.edit:SetSpacing(3) end
    -- In edit mode, hyperlinks behave like text, so clicking them positions
    -- the insertion cursor instead of opening an item unintentionally.
    if body.edit.SetHyperlinksEnabled then body.edit:SetHyperlinksEnabled(false) end
    body:EnableMouse(true)
    body:SetScript('OnMouseDown',function(self,button)
        local n=AF:FindRecord(AF.db.notes,UI.selectedNoteId)
        if button=='LeftButton' and n and not n.afLocked then body.edit:SetFocus() end
    end)

    -- Reading uses a separate scrollable FontString, not a disabled EditBox.
    -- This preserves native WoW hyperlink hit-testing and tooltips while the
    -- editor remains fully editable when unlocked.
    local reading=CreateFrame('ScrollFrame',nil,mid,'UIPanelScrollFrameTemplate')
    reading:SetPoint('TOPLEFT',body,'TOPLEFT',0,0)
    reading:SetPoint('BOTTOMRIGHT',body,'BOTTOMRIGHT',0,0)
    local readingBg=reading:CreateTexture(nil,'BACKGROUND')
    readingBg:SetAllPoints(reading)
    readingBg:SetColorTexture(.99,.92,.76,.50)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(readingBg,function(tex,t)
        local c=t.paper;tex:SetColorTexture(c[1],c[2],c[3],.96)
    end) end
    local readChild=CreateFrame('Frame',nil,reading)
    readChild:SetSize(400,200)
    reading:SetScrollChild(readChild)
    local readText=readChild:CreateFontString(nil,'ARTWORK')
    readText:SetPoint('TOPLEFT',readChild,'TOPLEFT',9,-10)
    readText:SetPoint('TOPRIGHT',readChild,'TOPRIGHT',-9,-10)
    readText:SetJustifyH('LEFT')
    readText:SetJustifyV('TOP')
    readText:SetTextColor(.18,.12,.065)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(readText,function(label,t)
        local c=t.ink;label:SetTextColor(c[1],c[2],c[3],1)
    end) end
    if readText.SetFont then readText:SetFont(cleanFont,15,'') end
    if readText.SetSpacing then readText:SetSpacing(3) end
    if readChild.SetHyperlinksEnabled then readChild:SetHyperlinksEnabled(true) end
    local function showTip(self,link)
        if not GameTooltip or type(link)~='string' or not GameTooltip.SetHyperlink then return end
        GameTooltip:SetOwner(self,'ANCHOR_CURSOR')
        if pcall(GameTooltip.SetHyperlink,GameTooltip,link) then GameTooltip:Show()
        else GameTooltip:Hide() end
    end
    readChild:SetScript('OnHyperlinkEnter',function(self,link) showTip(self,link) end)
    readChild:SetScript('OnHyperlinkLeave',function() if GameTooltip then GameTooltip:Hide() end end)
    readChild:SetScript('OnHyperlinkClick',function(self,link,text,button)
        if type(SetItemRef)=='function' and type(link)=='string' then
            pcall(SetItemRef,link,text,button,self)
        else showTip(self,link) end
    end)
    local function ResizeReading()
        local width=math.max(140,(reading:GetWidth() or 0)-24)
        readChild:SetWidth(width)
        local textHeight=readText.GetStringHeight and readText:GetStringHeight() or 0
        readChild:SetHeight(math.max(reading:GetHeight() or 200, (textHeight or 0)+26, 200))
        if reading.UpdateScrollChildRect then reading:UpdateScrollChildRect() end
    end
    reading:SetScript('OnSizeChanged',ResizeReading)
    if UI.InsetWorkshopScrollBar then UI:InsetWorkshopScrollBar(reading) end
    reading:Hide()
    local pin=B(mid,'Pin note',function()
        local n=AF:FindRecord(AF.db.notes,UI.selectedNoteId)
        if n then n.afPinned=not n.afPinned;n.updated=Now();page:Refresh() end
    end)
    pin:SetPoint('BOTTOMLEFT',mid,'BOTTOMLEFT',15,16)
    pin:SetSize(110,27)
    local edited=Label(mid,'Changes are saved automatically','small',P.ink)
    edited:SetPoint('BOTTOMLEFT',pin,'BOTTOMRIGHT',8,3)
    edited:SetPoint('BOTTOMRIGHT',mid,'BOTTOMRIGHT',-138,17)
    edited:SetHeight(24)
    local remove=B(mid,'Delete...',function()
        local id=UI.selectedNoteId
        if not id then return end
        local n=AF:FindRecord(AF.db.notes,id)
        if n and n.afLocked then AF.Print('Unlock the note before deleting it.');return end
        UI:ConfirmDelete('note',id,function() UI.selectedNoteId=nil;page:Refresh() end)
    end,true)
    remove:SetPoint('BOTTOMRIGHT',mid,'BOTTOMRIGHT',-15,16)
    remove:SetSize(110,27)

    Section(right,'Linked References')
    local instructions=Label(right,'Attach items, NPCs, quests, and maps. Click a reference to open or inspect it.','small',P.ink)
    instructions:SetPoint('TOPLEFT',right,'TOPLEFT',14,-47)
    instructions:SetPoint('TOPRIGHT',right,'TOPRIGHT',-12,-47)
    instructions:SetHeight(35)
    instructions:SetJustifyV('TOP')
    local target=B(right,'Target NPC',function()
        local n=AF:FindRecord(AF.db.notes,UI.selectedNoteId)
        if not n then return end
        local ref,err=TargetNPC()
        if ref then local ok,problem=AddLink(n,ref);if not ok then AF.Print(problem) end;page:Refresh() else AF.Print(err) end
    end)
    target:SetPoint('TOPLEFT',right,'TOPLEFT',14,-89)
    target:SetPoint('TOPRIGHT',right,'TOP',-3,-89)
    target:SetHeight(27)
    local location=B(right,'Here / Map',function()
        local n=AF:FindRecord(AF.db.notes,UI.selectedNoteId)
        if not n then return end
        local ref,err=MapLocation()
        if ref then local ok,problem=AddLink(n,ref);if not ok then AF.Print(problem) end;page:Refresh() else AF.Print(err) end
    end)
    location:SetPoint('TOPLEFT',right,'TOP',3,-89)
    location:SetPoint('TOPRIGHT',right,'TOPRIGHT',-14,-89)
    location:SetHeight(27)
    local refMode='item'
    local switch
    switch=B(right,'Link type: Item',function()
        refMode=refMode=='item' and 'quest' or (refMode=='quest' and 'npc' or 'item')
        switch.label:SetText('Link type: '..(refMode=='item' and 'Item' or (refMode=='quest' and 'Quest' or 'NPC name')))
    end)
    switch:SetPoint('TOPLEFT',right,'TOPLEFT',14,-123)
    switch:SetPoint('TOPRIGHT',right,'TOPRIGHT',-14,-123)
    switch:SetHeight(25)
    local refEntry=UI:Input(right)
    refEntry:SetPoint('TOPLEFT',right,'TOPLEFT',14,-156)
    refEntry:SetPoint('TOPRIGHT',right,'TOPRIGHT',-14,-156)
    refEntry:SetHeight(26)
    local attach=B(right,'Attach Link / ID',function()
        local n=AF:FindRecord(AF.db.notes,UI.selectedNoteId)
        if not n then return end
        local ref,err=LinkFromText(refEntry:GetText(),refMode)
        if not ref then AF.Print(err);return end
        local ok,problem=AddLink(n,ref)
        if not ok then AF.Print(problem);return end
        refEntry:SetText('')
        page:Refresh()
    end)
    attach:SetPoint('TOPLEFT',right,'TOPLEFT',14,-188)
    attach:SetPoint('TOPRIGHT',right,'TOPRIGHT',-14,-188)
    attach:SetHeight(27)
    local referenceCount=Label(right,'References','small',P.ink)
    referenceCount:SetPoint('TOPLEFT',right,'TOPLEFT',15,-227)
    referenceCount:SetPoint('TOPRIGHT',right,'TOPRIGHT',-10,-227)
    referenceCount:SetHeight(19)
    local refs=UI:List(right,39)
    refs:SetPoint('TOPLEFT',right,'TOPLEFT',12,-255)
    refs:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-28,156)
    if UI.InsetWorkshopScrollBar then UI:InsetWorkshopScrollBar(refs) end
    local refDetails=Label(right,'Select a link to inspect it.','small',P.ink)
    refDetails:SetPoint('BOTTOMLEFT',right,'BOTTOMLEFT',15,89)
    refDetails:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-15,89)
    refDetails:SetHeight(60)
    refDetails:SetJustifyV('TOP')
    local open=B(right,'Open / Inspect',function()
        local n=AF:FindRecord(AF.db.notes,UI.selectedNoteId)
        local ref=n and pickedReference and NoteLinks(n)[pickedReference]
        if ref then OpenReference(ref,open) end
    end)
    open:SetPoint('BOTTOMLEFT',right,'BOTTOMLEFT',14,48)
    open:SetPoint('BOTTOMRIGHT',right,'BOTTOM',-3,48)
    open:SetHeight(27)
    local unlink=B(right,'Remove Link',function()
        local n=AF:FindRecord(AF.db.notes,UI.selectedNoteId)
        if not n or n.afLocked or not pickedReference then return end
        table.remove(NoteLinks(n),pickedReference)
        n.updated=Now();pickedReference=nil;page:Refresh()
    end,true)
    unlink:SetPoint('BOTTOMLEFT',right,'BOTTOM',3,48)
    unlink:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-14,48)
    unlink:SetHeight(27)
    local insert=B(right,'Insert in Note',function()
        local n=AF:FindRecord(AF.db.notes,UI.selectedNoteId)
        local ref=n and NoteLinks(n)[pickedReference]
        if not n or not ref then return end
        if n.afLocked then AF.Print('Unlock the note before inserting a reference.');return end
        local str
        if ref.kind=='item' then str=ref.hyperlink or ('[Item #'..tostring(ref.id)..']')
        elseif ref.kind=='quest' then str=ref.hyperlink or ('[Quest: '..tostring(ref.label)..' #'..tostring(ref.id)..']')
        elseif ref.kind=='npc' then str='[NPC: '..tostring(ref.label)..(ref.npcID and (' #'..ref.npcID) or '')..']'
        else str='[Map: '..tostring(ref.label)..']' end
        if body.edit.Insert then body.edit:Insert(' '..str..' ')
        else body.edit:SetText((body.edit:GetText() or '')..' '..str..' ') end
        n.body=body.edit:GetText()
        n.updated=Now()
        edited:SetText('Auto-saved  |  '..Stamp(n.updated))
    end)
    insert:SetPoint('BOTTOMLEFT',right,'BOTTOMLEFT',14,13)
    insert:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-14,13)
    insert:SetHeight(27)

    search:SetScript('OnTextChanged',function(self,userInput)
        if not userInput or busy then return end
        state.search=self:GetText()
        page:Refresh()
    end)
    title:SetScript('OnTextChanged',function(self,userInput)
        if not userInput or busy then return end
        local n=AF:FindRecord(AF.db.notes,UI.selectedNoteId)
        if n and not n.afLocked then n.title=self:GetText();n.updated=Now();page:RefreshList() end
    end)
    tags:SetScript('OnTextChanged',function(self,userInput)
        if not userInput or busy then return end
        local n=AF:FindRecord(AF.db.notes,UI.selectedNoteId)
        if n and not n.afLocked then n.afTags=Short(self:GetText(),220);n.updated=Now() end
    end)
    body.edit:SetScript('OnTextChanged',function(self,userInput)
        if not userInput or busy then return end
        local n=AF:FindRecord(AF.db.notes,UI.selectedNoteId)
        if n and not n.afLocked then n.body=self:GetText();n.updated=Now() end
        UI:ResizeEditor(self)
    end)
    function page:RefreshList()
        local visible={}
        local query=Trim(state.search):lower()
        local currentKey=AF:GetCurrentKey()
        for _,n in ipairs(AF.db.notes) do
            local allowed=(state.filter=='All categories' or NoteCategory(n)==state.filter)
            if state.scope=='Account-wide' then allowed=allowed and not n.owner
            elseif state.scope=='Current alt' then allowed=allowed and n.owner==currentKey end
            if allowed and (query=='' or NoteText(n):find(query,1,true)) then visible[#visible+1]=n end
        end
        table.sort(visible,function(a,b)
            if (a.afPinned==true)~=(b.afPinned==true) then return a.afPinned==true end
            if (a.updated or 0)~=(b.updated or 0) then return (a.updated or 0)>(b.updated or 0) end
            return (a.id or 0)>(b.id or 0)
        end)
        shownNotes=visible
        local rows={}
        for _,n in ipairs(visible) do
            rows[#rows+1]={key=n.id,label=(n.afPinned and '* ' or '')..Short(n.title or 'Untitled',36)..'  -  '..NoteCategory(n)}
        end
        UI:FillList(list,rows,function(row)
            UI.selectedNoteId=row.key
            pickedReference=nil
            page:Refresh()
        end,UI.selectedNoteId)
        count:SetText(#visible..' matching notes  |  '..#AF.db.notes..' total')
    end
    function page:RefreshReferences(n)
        displayedLinks={}
        if n then for _,r in ipairs(NoteLinks(n)) do displayedLinks[#displayedLinks+1]=r end end
        local rows={}
        for i,r in ipairs(displayedLinks) do
            local kind=r.kind=='location' and 'Map' or (r.kind=='npc' and 'NPC' or (r.kind=='quest' and 'Quest' or 'Item'))
            rows[#rows+1]={key=i,label=kind..': '..Short(r.label or tostring(r.id),24)..'  >'}
        end
        if pickedReference and not displayedLinks[pickedReference] then pickedReference=nil end
        UI:FillList(refs,rows,function(row)
            pickedReference=row.key
            page:RefreshReferences(n)
            -- Single-click is the action. The old implementation only
            -- highlighted a row and required a second unrelated button.
            local ref=displayedLinks[row.key]
            if ref then OpenReference(ref,(refs.rows or {})[row.key] or open) end
        end,pickedReference)
        for i,row in ipairs(refs.rows or {}) do
            local ref=displayedLinks[i]
            if ref then
                row:SetScript('OnEnter',function(self) ReferenceTooltip(self,ref) end)
                row:SetScript('OnLeave',function(self)
                    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
                end)
            else
                row:SetScript('OnEnter',nil)
                row:SetScript('OnLeave',nil)
            end
        end
        referenceCount:SetText('References  ('..#displayedLinks..')')
        local ref=pickedReference and displayedLinks[pickedReference]
        if not ref then
            refDetails:SetText('Click a reference to open it.\nHover for item, quest, NPC, or map details.')
        elseif ref.kind=='location' then
            refDetails:SetText(ref.label..'\nMap ID: '..tostring(ref.mapID)..'  |  Saved coordinates')
        elseif ref.kind=='npc' then
            refDetails:SetText((ref.label or 'NPC')..'\nNPC ID: '..tostring(ref.npcID or 'not available')..'  |  Captured from target')
        else
            refDetails:SetText((ref.label or ref.kind)..'\n'..ref.kind..' ID: '..tostring(ref.id)..(ref.hyperlink and '  |  Link available' or '  |  Uncached'))
        end
        open:SetEnabled(ref~=nil)
        unlink:SetEnabled(ref~=nil and not (n and n.afLocked))
        insert:SetEnabled(ref~=nil and not (n and n.afLocked))
    end
    function page:Refresh()
        page:RefreshList()
        local n=AF:FindRecord(AF.db.notes,UI.selectedNoteId)
        local shown=false
        for _,v in ipairs(shownNotes) do if n and n.id==v.id then shown=true;break end end
        if not shown then
            n=shownNotes[1]
            UI.selectedNoteId=n and n.id or nil
        end
        if not n then
            busy=true;title:SetText('');tags:SetText('');body.edit:SetText('');busy=false
            currentID=nil
            title:Disable();tags:Disable();body.edit:Disable()
            body:Show();reading:Hide();mode:Hide()
            owner:Hide();setCategory:Hide();pin:Hide();remove:Hide()
            target:SetEnabled(false);location:SetEnabled(false);attach:SetEnabled(false)
            page:RefreshReferences(nil)
            edited:SetText('Create a note to begin.')
                return
        end
        mode:Show()
        local locked=n.afLocked==true
        if locked then
            title:Disable();tags:Disable();body.edit:Disable()
            body:Hide();reading:Show()
            readText:SetText((n.body and n.body~='') and n.body or 'This page is blank. Select Edit Note to write.')
            ResizeReading()
            mode.label:SetText('Edit Note')
            bodyLabel:SetText('Reading Mode')
        else
            title:Enable();tags:Enable();body.edit:Enable()
            reading:Hide();body:Show()
            UI:ResizeEditor(body.edit)
            mode.label:SetText('Lock / Read')
            bodyLabel:SetText('Journal entry')
        end
        owner:SetEnabled(not locked);setCategory:SetEnabled(not locked)
        target:SetEnabled(not locked);location:SetEnabled(not locked);attach:SetEnabled(not locked)
        owner:Show();setCategory:Show();pin:Show();remove:Show()
        if currentID~=n.id then
            currentID=n.id
            busy=true
            title:ClearFocus();tags:ClearFocus();body.edit:ClearFocus()
            title:SetText(n.title or '')
            tags:SetText(n.afTags or '')
            body.edit:SetText(n.body or '')
            UI:ResizeEditor(body.edit)
            busy=false
            pickedReference=nil
        else
            busy=true
            if not title:HasFocus() then title:SetText(n.title or '') end
            if not tags:HasFocus() then tags:SetText(n.afTags or '') end
            busy=false
        end
        owner.label:SetText(Short(AF:CharacterLabel(n.owner),31))
        setCategory.label:SetText('Type: '..NoteCategory(n))
        pin.label:SetText(n.afPinned and 'Unpin' or 'Pin Note')
        edited:SetText('Auto-saved  |  '..Stamp(n.updated))
        scope.label:SetText('Scope: '..state.scope)
        category.label:SetText(Short('Category: '..state.filter,35))
        page:RefreshReferences(n)
        remove:SetEnabled(not locked)
    end
end
