-- v0.4.1.7: finish-pass item resolution and missing-data presentation.
local _, AF = ...
local UI=AF.UI
local panel, activeTab, pickedID, currentRows, pickedEvent, pickedGroupKey, currentGroups
local pickedRowKey, pickedOwnerKey, currentTotals
local browserScope='current'
local filters={active='all',completed='all',history='all'}
local searchQuery=''
local expandedGroups={}
activeTab='active' 
local function Stamp(t)
    if type(t)~='number' or t<=0 then return 'Unknown' end
    if date then return date('%d %b %Y %H:%M',t) end
    return tostring(t)
end
local function Count(t)
    local n=0 for _ in pairs(t or {}) do n=n+1 end return n
end
local function Label(parent,value,font,role)
    local f=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontNormalSmall')
    f:SetText(value or '');f:SetJustifyH('LEFT');f:SetJustifyV('TOP')
    if f.SetShadowOffset then f:SetShadowOffset(0,0) end
    if f.SetShadowColor then f:SetShadowColor(0,0,0,0) end
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(f,function(label,t)
        if label.afPreserveQuestColor then return end
        -- Quest windows have dark reading surfaces even in parchment/light
        -- presets. Match text to the surface it is actually painted on.
        local surface=role=='shell' and t.shell or t.dataSurface
        local preferred=role=='shell' and t.text or t.dataText
        local c=UI.ThemeReadableText and UI:ThemeReadableText(surface,preferred) or preferred
        label:SetTextColor(c[1],c[2],c[3],1)
    end) end
    return f
end
local function PrettyText(v,depth)
    if type(v)=='string' then return v end
    if type(v)~='table' then return '' end
    depth=depth or 0
    if depth>2 then return '' end
    local out={}
    local preferred={'title','name','description','details','objectives','objective','progress','completionText','text','rewards'}
    local used={}
    for _,key in ipairs(preferred) do
        local item=v[key]
        if item~=nil then
            used[key]=true
            local s=PrettyText(item,depth+1)
            if s~='' then out[#out+1]=s end
        end
    end
    for key,item in pairs(v) do
        if not used[key] and type(item)=='string' and #item>2 and #item<2000 then
            out[#out+1]=item
        end
    end
    return table.concat(out,'\n\n')
end
local function Rows()
    local entries,totals=AF:GetQuestBrowserEntries(browserScope,activeTab,searchQuery,filters[activeTab])
    currentTotals=totals
    currentGroups={}
    if activeTab=='history' then return entries end
    if AF.BuildQuestJournalGroups then
        local overrides={}
        for k,v in pairs(expandedGroups) do overrides[k]=v end
        if searchQuery:match('%S') then
            -- Search results expose matching quest IDs even inside collapsed chains.
            local _,groups=AF:BuildQuestJournalGroups(entries,{})
            for key in pairs(groups or {}) do overrides[key]=true end
        end
        local rows,groups=AF:BuildQuestJournalGroups(entries,overrides)
        currentGroups=groups or {}
        local byID={}
        for _,entry in ipairs(entries) do byID[entry.id]=entry end
        for _,row in ipairs(rows) do
            if row.id and byID[row.id] then
                local info=byID[row.id]
                row.ownerKey=info.ownerKey
                row.ownerKeys=info.ownerKeys
                row.ownerLabel=info.ownerLabel
                row.rowKey=info.rowKey
                row.at=info.at
            end
        end
        return rows
    end
    return entries
end
local function CharacterRecord(key)
    local chars=AF.db and AF.db.questRecords and AF.db.questRecords.characters
    return chars and chars[key] or nil
end
local function SelectedRow()
    for _,entry in ipairs(currentRows or {}) do
        if entry.rowKey and entry.rowKey==pickedRowKey then return entry end
    end
end
local function CurrentFilterOptions()
    return AF:GetQuestBrowserFilters(activeTab)
end
local function Setup()
    if panel then return end
    panel=CreateFrame('Frame','AzerothFoundryQuestJournal',UIParent)
    panel:SetSize(790,603)
    panel:SetPoint('CENTER',UIParent,'CENTER',35,5)
    panel:SetFrameStrata('TOOLTIP');panel:SetFrameLevel(250)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true);panel:SetMovable(true)
    panel:RegisterForDrag('LeftButton')
    panel:SetScript('OnDragStart',function(self) self:StartMoving() end)
    panel:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
    local bg=panel:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.09,.075,.055,.97) -- recolored by theme below
    local edge=panel:CreateTexture(nil,'BORDER');edge:SetHeight(3);edge:SetPoint('TOPLEFT');edge:SetPoint('TOPRIGHT');edge:SetColorTexture(.75,.55,.25,1)
    local title=Label(panel,'QUEST JOURNAL','GameFontNormalLarge','shell');title:SetPoint('TOPLEFT',33,-14)
    local crest=panel:CreateTexture(nil,'ARTWORK');crest:SetSize(19,19);crest:SetPoint('TOPLEFT',11,-13);crest:SetTexture('Interface\\GossipFrame\\AvailableQuestIcon')
    local close=UI:Button(panel,'X',function() panel:Hide() end)
    close:SetSize(33,24);close:SetPoint('TOPRIGHT',-12,-10)
    panel.status=Label(panel,'','GameFontNormalSmall','shell');panel.status:SetPoint('TOPLEFT',16,-42)
    panel.status:SetPoint('RIGHT',-12,0);panel.status:SetHeight(18)
    local tabNames={{'active','Active'},{'completed','Completed'},{'history','History'}}
    panel.tabs={}
    for i,item in ipairs(tabNames) do
        local b=UI:Button(panel,item[2],function() activeTab=item[1];pickedID=nil;pickedEvent=nil;pickedGroupKey=nil;pickedRowKey=nil;pickedOwnerKey=nil;panel.listScroll:SetVerticalScroll(0);panel.detailScroll:SetVerticalScroll(0);panel:Refresh() end)
        b:SetPoint('TOPLEFT',14+(i-1)*105,-68);b:SetSize(100,26)
        panel.tabs[item[1]]=b
    end
    local scan=UI:Button(panel,'Scan current',function()
        if AF.ScanQuestRecords then
            local ok,err=AF:ScanQuestRecords()
            if not ok and AF.Print then AF.Print('Quest scan: '..tostring(err)) end
        end
        if AF.BackfillCompletedQuestRecords then
            local ok,result=AF:BackfillCompletedQuestRecords()
            if not ok and AF.Print then AF.Print('Completed quest import: '..tostring(result)) end
        end
        panel:Refresh()
    end)
    scan:SetPoint('TOPRIGHT',-14,-68);scan:SetSize(108,26)
    -- Search and filters are browser-only. They never modify recorded quests.
    local search=CreateFrame('EditBox',nil,panel,'InputBoxTemplate')
    search:SetSize(172,23);search:SetPoint('TOPLEFT',81,-108)
    search:SetAutoFocus(false)
    search:SetMaxLetters(80)
    search:SetText('')
    panel.search=search
    local searchLabel=Label(panel,'Search: name or quest ID','GameFontNormalSmall','shell')
    searchLabel:SetPoint('TOPLEFT',panel,'TOPLEFT',18,-114)
    search:SetScript('OnTextChanged',function(self,userInput)
        if not userInput then return end
        searchQuery=self:GetText() or ''
        pickedID=nil;pickedEvent=nil;pickedGroupKey=nil;pickedRowKey=nil;pickedOwnerKey=nil
        if panel.listScroll then panel.listScroll:SetVerticalScroll(0);panel:Refresh() end
    end)
    search:SetScript('OnEnterPressed',function(self) self:ClearFocus() end)
    search:SetScript('OnEscapePressed',function(self)
        if self:GetText()~='' then self:SetText('') else self:ClearFocus() end
    end)
    local scopeButton=UI:Button(panel,'Character: this',function()
        local scopes=AF:GetQuestBrowserScopes()
        local index=1
        for i,item in ipairs(scopes) do if item.key==browserScope then index=i;break end end
        browserScope=scopes[index%#scopes+1].key
        pickedID=nil;pickedEvent=nil;pickedGroupKey=nil;pickedRowKey=nil;pickedOwnerKey=nil
        panel.listScroll:SetVerticalScroll(0);panel:Refresh()
    end)
    scopeButton:SetSize(237,25);scopeButton:SetPoint('TOPLEFT',267,-107)
    panel.scopeButton=scopeButton
    local filterButton=UI:Button(panel,'Filter: all',function()
        local options=CurrentFilterOptions()
        local index=1
        for i,option in ipairs(options) do if option[1]==filters[activeTab] then index=i;break end end
        filters[activeTab]=options[index%#options+1][1]
        pickedID=nil;pickedEvent=nil;pickedGroupKey=nil;pickedRowKey=nil;pickedOwnerKey=nil
        panel.listScroll:SetVerticalScroll(0);panel:Refresh()
    end)
    filterButton:SetSize(218,25);filterButton:SetPoint('TOPLEFT',512,-107)
    panel.filterButton=filterButton
    local listBg=CreateFrame('Frame',nil,panel)
    listBg:SetPoint('TOPLEFT',14,-148);listBg:SetPoint('BOTTOMLEFT',14,35);listBg:SetWidth(280)
    local lt=listBg:CreateTexture(nil,'BACKGROUND');lt:SetAllPoints();lt:SetColorTexture(.18,.135,.09,.92) -- recolored by theme below
    local detailBg=CreateFrame('Frame',nil,panel)
    detailBg:SetPoint('TOPLEFT',listBg,'TOPRIGHT',9,0);detailBg:SetPoint('BOTTOMRIGHT',-14,35)
    local dt=detailBg:CreateTexture(nil,'BACKGROUND');dt:SetAllPoints();dt:SetColorTexture(.16,.12,.08,.94)
    -- Independent quest windows are outside Foundry's regular page skin.
    -- Their original hard-coded brown textures were never rethemed, while
    -- parchment presets assigned dark ink to dark reading panes.
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(panel,function(_,t)
        local shell=t.shell
        bg:SetColorTexture(shell[1],shell[2],shell[3],.99)
        local edgeColor=t.divider
        edge:SetColorTexture(edgeColor[1],edgeColor[2],edgeColor[3],1)
        local data=t.dataSurface
        local nav=t.navActive
        lt:SetColorTexture(data[1]*.86+nav[1]*.14,data[2]*.86+nav[2]*.14,data[3]*.86+nav[3]*.14,1)
        dt:SetColorTexture(data[1],data[2],data[3],1)
    end) end
    panel.detailTitle=Label(detailBg,'Select a quest','GameFontNormal')
    panel.detailTitle:SetPoint('TOPLEFT',10,-9);panel.detailTitle:SetPoint('TOPRIGHT',-87,-9);panel.detailTitle:SetHeight(30)
    local spy=UI:Button(detailBg,'@',function() if pickedID and UI.FocusAtlasQuest then UI:FocusAtlasQuest(pickedID) end end)
    spy:SetSize(29,25);spy:SetPoint('TOPRIGHT',-10,-7);spy:SetText('')
    local spyIcon=spy:CreateTexture(nil,'ARTWORK');spyIcon:SetSize(19,19);spyIcon:SetPoint('CENTER');spyIcon:SetTexture('Interface\\MINIMAP\\TRACKING\\None')
    -- Cross-reference the selected quest's original chapter without toggling
    -- either independent window closed.
    local storyButton=UI:Button(detailBg,'Story',function()
        if pickedID and UI.OpenQuestRecapAtQuest then UI:OpenQuestRecapAtQuest(pickedID) end
    end)
    storyButton:SetSize(56,25)
    storyButton:SetPoint('RIGHT',spy,'LEFT',-5,0)
    panel.detailTitle:ClearAllPoints()
    panel.detailTitle:SetPoint('TOPLEFT',10,-9)
    panel.detailTitle:SetPoint('TOPRIGHT',-106,-9)
    panel.detailTitle:SetHeight(30)
    -- Our floating journal uses TOOLTIP strata so it stays above AF; lift the
    -- actual tooltip above that journal temporarily, without changing the
    -- tooltip's normal frame level for the rest of the game.
    local originalTooltipStrata,originalTooltipLevel
    spy:SetScript('OnEnter',function(self)
        if not GameTooltip then return end
        originalTooltipStrata=GameTooltip:GetFrameStrata()
        originalTooltipLevel=GameTooltip:GetFrameLevel()
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
        GameTooltip:SetFrameStrata('TOOLTIP')
        GameTooltip:SetFrameLevel(math.max(panel:GetFrameLevel()+40,originalTooltipLevel or 0))
        GameTooltip:AddLine('Locate quest on Atlas',1,.82,0)
        GameTooltip:AddLine('Focuses the quest map when the client provides a location.',1,1,1,true)
        GameTooltip:Show()
    end)
    spy:SetScript('OnLeave',function()
        if not GameTooltip then return end
        GameTooltip:Hide()
        if originalTooltipStrata then GameTooltip:SetFrameStrata(originalTooltipStrata) end
        if originalTooltipLevel then GameTooltip:SetFrameLevel(originalTooltipLevel) end
        originalTooltipStrata=nil; originalTooltipLevel=nil
    end)
    local detailScroll=CreateFrame('ScrollFrame',nil,detailBg,'UIPanelScrollFrameTemplate')
    detailScroll:SetPoint('TOPLEFT',9,-45);detailScroll:SetPoint('BOTTOMRIGHT',-30,9)
    local detailContent=CreateFrame('Frame',nil,detailScroll)
    detailContent:SetWidth(420);detailContent:SetHeight(400)
    panel.details=Label(detailContent,'','GameFontHighlightSmall')
    panel.details:SetPoint('TOPLEFT',6,-6);panel.details:SetWidth(394)
    if panel.details.SetWordWrap then pcall(panel.details.SetWordWrap,panel.details,true) end
    detailScroll:SetScrollChild(detailContent)
    panel.detailContent=detailContent
    panel.detailScroll=detailScroll
    panel.richPools={text={},bar={},reward={}}
    panel.richCounts={}
    -- Reuse widgets by type; switching between very different quests does not
    -- allocate new frames every time an objective or reward count changes.
    function panel:HideRich()
        for _,pool in pairs(self.richPools) do
            for _,node in ipairs(pool) do node:Hide() end
        end
        self.richCounts={}
    end
    local function RichNode(owner,kind)
        local pool=owner.richPools[kind]
        local index=(owner.richCounts[kind] or 0)+1
        local node=pool[index]
        if not node then
            if kind=='text' then
                node=Label(owner.detailContent,'','GameFontHighlightSmall')
                node:SetWidth(392)
                if node.SetWordWrap then pcall(node.SetWordWrap,node,true) end
                if node.SetMaxLines then pcall(node.SetMaxLines,node,0) end
            elseif kind=='bar' then
                node=CreateFrame('Frame',nil,owner.detailContent)
                node:SetSize(389,9)
                local bg=node:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.22,.17,.10,1)
                local fill=node:CreateTexture(nil,'ARTWORK');fill:SetPoint('TOPLEFT');fill:SetPoint('BOTTOMLEFT');fill:SetColorTexture(.35,.66,.36,.95)
                node.fill=fill
                if UI.RegisterThemeTarget then UI:RegisterThemeTarget(node,function(_,t)
                    local c=t.secondary
                    bg:SetColorTexture(c[1],c[2],c[3],1)
                    local done=t.success
                    fill:SetColorTexture(done[1],done[2],done[3],.95)
                end) end
            elseif kind=='reward' then
                node=CreateFrame('Button',nil,owner.detailContent)
                node:SetSize(390,49)
                local bg=node:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.30,.225,.14,.64)
                if UI.RegisterThemeTarget then UI:RegisterThemeTarget(node,function(_,t)
                    local c=t.accent3 or t.accent
                    bg:SetColorTexture(c[1],c[2],c[3],.15)
                end) end
                local icon=node:CreateTexture(nil,'OVERLAY');icon:SetSize(32,32);icon:SetPoint('LEFT',3,0);node.icon=icon
                local outline=node:CreateTexture(nil,'BORDER');outline:SetSize(34,34);outline:SetPoint('CENTER',icon,'CENTER');outline:SetColorTexture(.38,.30,.17,.9);node.outline=outline
                local label=Label(node,'','GameFontHighlightSmall');label:SetPoint('TOPLEFT',43,-3);label:SetPoint('TOPRIGHT',-6,-3);label:SetHeight(29);if label.SetWordWrap then pcall(label.SetWordWrap,label,true) end;node.text=label
                local sub=Label(node,'','GameFontNormalSmall');sub:SetPoint('BOTTOMLEFT',43,4);sub:SetPoint('BOTTOMRIGHT',-6,4);sub:SetHeight(14);node.sub=sub
                node:RegisterForClicks('LeftButtonUp')
                node:SetScript('OnEnter',function(self)
                    if GameTooltip then
                        self.oldStrata=GameTooltip:GetFrameStrata()
                        self.oldLevel=GameTooltip:GetFrameLevel()
                        GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
                        GameTooltip:SetFrameStrata('TOOLTIP');GameTooltip:SetFrameLevel(owner:GetFrameLevel()+75)
                        local shown=false
                        if self.itemID and type(GameTooltip.SetHyperlink)=='function' then
                            local ok=pcall(GameTooltip.SetHyperlink,GameTooltip,'item:'..self.itemID)
                            shown=ok
                        end
                        if not shown then
                            GameTooltip:AddLine(self.itemName or 'Quest reward',1,.85,.45)
                            if self.itemID then GameTooltip:AddLine('Item ID '..self.itemID,.7,.7,.7) end
                        end
                        GameTooltip:Show()
                    end
                end)
                node:SetScript('OnLeave',function(self)
                    if GameTooltip then
                        GameTooltip:Hide()
                        if self.oldStrata then GameTooltip:SetFrameStrata(self.oldStrata) end
                        if self.oldLevel then GameTooltip:SetFrameLevel(self.oldLevel) end
                    end
                    self.oldStrata=nil;self.oldLevel=nil
                end)
                node:SetScript('OnClick',function(self)
                    if self.itemID and type(IsShiftKeyDown)=='function' and IsShiftKeyDown()
                        and type(GetItemInfo)=='function' and type(ChatEdit_InsertLink)=='function' then
                        local _,link=GetItemInfo(self.itemID)
                        link=link or self.itemLink
                        if link then ChatEdit_InsertLink(link) end
                    end
                end)
            end
            node.richKind=kind
            pool[index]=node
        end
        owner.richCounts[kind]=index
        node:Show()
        return node
    end
    function panel:RenderRich(info,summary)
        self:HideRich()
        self.details:Hide()
        local y=4
        local function Text(value,header,gap)
            if not value or value=='' then return end
            local node=RichNode(self,'text')
            node:SetFontObject(header and 'GameFontNormal' or 'GameFontHighlightSmall')
            if UI.ThemeTokens then
                local t=UI:ThemeTokens()
                local c=UI.ThemeReadableText and UI:ThemeReadableText(t.dataSurface,t.dataText) or t.dataText
                node:SetTextColor(c[1],c[2],c[3],1)
            end
            node:ClearAllPoints();node:SetPoint('TOPLEFT',self.detailContent,'TOPLEFT',7,-y)
            -- Height must be unconstrained BEFORE measuring wrapping. Previously
            -- the 15px initial height caused WoW to display long text as "...".
            node:SetHeight(1000)
            node:SetText(value)
            local measured=node:GetStringHeight() or 0
            local height=math.max(header and 17 or 15,measured)
            node:SetHeight(height+4)
            y=y+height+4+(gap or (header and 8 or 10))
        end
        Text('|cffffd16bQUEST RECORD|r',true,4)
        Text(summary, false,14)
        if info and info.description and info.description~='' then
            Text('|cffffd16bSTORY|r',true,5)
            Text(info.description,false,14)
        end
        if info and info.objectivesText and info.objectivesText~='' then
            Text('|cffffd16bOBJECTIVES|r',true,5)
            Text(info.objectivesText,false,9)
        end
        if info and #info.objectives>0 then
            Text('|cffffd16bLIVE PROGRESS|r',true,5)
            for _,objective in ipairs(info.objectives) do
                local have,need=objective.have,objective.need
                local color=objective.done and '|cff7ae08a' or '|cffe2d3b7'
                local suffix=(have and need and need>0) and ('  |cffd7b56f('..have..'/'..need..')|r') or ''
                Text(color..(objective.done and '|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t  ' or '-  ')..(objective.text or 'Objective')..'|r'..suffix,false,5)
                if have and need and need>0 then
                    local bar=RichNode(self,'bar');bar:ClearAllPoints();bar:SetPoint('TOPLEFT',self.detailContent,'TOPLEFT',7,-y)
                    bar.fill:SetWidth(389*math.max(0,math.min(1,have/need)))
                    y=y+16
                end
            end
            y=y+5
        end
        if info and info.progressText and info.progressText~='' and #info.objectives==0 then
            Text('|cffffd16bTURN-IN NOTES|r',true,5);Text(info.progressText,false,12)
        end
        if info and (#info.items>0 or info.xp or info.money or (info.reputation and #info.reputation>0)) then
            Text('|cffffd16bREWARDS|r',true,5)
            if info.rewardSource then Text('|cffbba17b'..info.rewardSource..'|r',false,3) end
            for _,item in ipairs(info.items) do
                local row=RichNode(self,'reward');row:ClearAllPoints();row:SetPoint('TOPLEFT',self.detailContent,'TOPLEFT',7,-y)
                row.itemID=item.id;row.itemName=item.name;row.itemLink=item.link
                row.icon:SetTexture(item.icon)
                local quality=ITEM_QUALITY_COLORS and item.quality and ITEM_QUALITY_COLORS[item.quality]
                if quality then row.outline:SetColorTexture(quality.r,quality.g,quality.b,1)
                else row.outline:SetColorTexture(.55,.44,.26,1) end
                row.text:SetText((item.count and item.count>1 and ('x'..item.count..' ') or '')..item.name)
                row.sub:SetText(item.kind)
                y=y+52
            end
            if info.missingItemCount and info.missingItemCount>0 then
                local note=AF.IsQuestItemLibraryConnected and AF:IsQuestItemLibraryConnected()
                    and 'Some reward item names/icons are not in the available client or item database.'
                    or 'Some reward items are uncached. Optional LibItemDB may supply missing names.'
                Text('|cffb9a48a'..note..'|r',false,8)
            end
            if info.xp then Text('|cffb8daffExperience|r  '..info.xp..(info.xpEstimate and ' |cff9c8c74(estimate at your current level)|r' or ''),false,5) end
            if info.money and info.money~=0 then
                local amount=math.abs(info.money)
                local formatted=type(GetCoinTextureString)=='function' and GetCoinTextureString(amount) or (amount..' copper')
                Text((info.money<0 and '|cffff8888Cost|r  ' or '|cffffd16bCoin|r  ')..formatted..(info.moneyEstimate and ' |cff9c8c74(database)|r' or ''),false,5)
            end
            for _,rep in ipairs(info.reputation or {}) do
                Text('|cffc5dcb6Reputation|r  '..tostring(rep.name or ('Faction '..tostring(rep.faction)))..': '..(rep.value>0 and '+' or '')..tostring(rep.value),false,5)
            end
            y=y+10
        end
        if info and #info.npcs>0 then
            Text('|cffffd16bQUEST CHARACTERS & TARGETS|r',true,5)
            -- Preserve useful LibQuestDB NPC identities without promising a
            -- model preview the Forever client has not reliably supported.
            for _,npc in ipairs(info.npcs) do
                local role=tostring(npc.role or 'NPC')
                local name=tostring(npc.name or ('NPC #'..tostring(npc.id or '?')))
                Text('|cffd6b479'..role..':|r  |cffb8dcff'..name..'|r',false,3)
            end
            y=y+6
        end
        if info and info.turnInText and info.turnInText~='' then
            y=y+8;Text('|cffffd16bTURN-IN DIALOGUE (REFERENCE)|r',true,4);Text(info.turnInText,false,10)
        end
        if info and info.endText and info.endText~='' then
            y=y+6;Text('|cffffd16bENDING (REFERENCE)|r',true,4);Text(info.endText,false,10)
        end
        if info and info.historical and not info.hasHistoricalDetails then
            y=y+8
            Text('|cffffd16bHISTORICAL RECORD LIMITATION|r',true,5)
            Text('Completed status was recovered, but this quest has no additional story, objectives or reward data in the installed library. The original completion dialogue and selected reward cannot be reconstructed from a completion ID.',false,8)
        elseif not info then
            Text('No additional quest reference data available.',false,8)
        end
        self.detailContent:SetHeight(math.max(400,y+15))
    end
    local scroll=CreateFrame('ScrollFrame',nil,listBg,'UIPanelScrollFrameTemplate')
    scroll:SetPoint('TOPLEFT',5,-8);scroll:SetPoint('BOTTOMRIGHT',-27,8)
    local content=CreateFrame('Frame',nil,scroll);content:SetSize(242,10);scroll:SetScrollChild(content)
    panel.listContent=content
    panel.rowButtons={}
    for i=1,16 do
        local idx=i
        local b=CreateFrame('Button',nil,content)
        b:SetSize(239,28);b:SetPoint('TOPLEFT',0,-(i-1)*30)
        local shade=b:CreateTexture(nil,'BACKGROUND');shade:SetAllPoints();shade:SetColorTexture(.43,.29,.13,i%2==0 and .28 or .15)
        if UI.RegisterThemeTarget then UI:RegisterThemeTarget(b,function(_,t)
            local c=t.accent3 or t.accent
            shade:SetColorTexture(c[1],c[2],c[3],i%2==0 and .19 or .10)
        end) end
        local label=Label(b,'','GameFontHighlightSmall');label:SetPoint('LEFT',5,0);label:SetPoint('RIGHT',-3,0);label:SetHeight(25)
        b.label=label
        b:SetScript('OnClick',function(self)
            panel.detailScroll:SetVerticalScroll(0)
            if self.groupKey and self.rowType=='group' then
                pickedGroupKey=self.groupKey;pickedID=nil;pickedEvent=nil;pickedRowKey=nil;pickedOwnerKey=nil
                expandedGroups[self.groupKey]=not expandedGroups[self.groupKey]
                panel:Refresh()
            else
                pickedGroupKey=nil;pickedID=self.questID;pickedEvent=self.questEvent;pickedRowKey=self.rowKey;pickedOwnerKey=self.ownerKey
                panel:RefreshDetails()
            end
        end)
        panel.rowButtons[i]=b
    end
    panel.listScroll=scroll
    panel.footer=Label(panel,'Completed: > expand groups, * recovered (date unknown). History: blue accepted, green turned in.','GameFontHighlightSmall','shell')
    panel.footer:SetPoint('BOTTOMLEFT',16,13);panel.footer:SetPoint('BOTTOMRIGHT',-15,13)
    panel.footer:SetHeight(17)
    function panel:RefreshDetails()
        if pickedGroupKey then
            local group=currentGroups and currentGroups[pickedGroupKey]
            if group then
                self:HideRich();self.details:Show()
                local sameTitle=group.kind=='variants'
                local heading=sameTitle and 'Quest Variants' or 'Quest Chain'
                self.detailTitle:SetText(group.title or heading)
                local lines={'|cffffd16b'..heading:upper()..'|r',
                    tostring(group.count)..' recorded quests',
                    sameTitle and 'Same quest name; these may be separate variants, not a confirmed chain.'
                        or 'Grouped from LibQuestDB quest relationships.',
                    '', '|cffffd16bQUESTS|r'}
                for i,entry in ipairs(group.members) do
                    local lvl=entry.level and entry.level>0 and ('['..entry.level..'] ') or ''
                    lines[#lines+1]=string.format('%d. %s%s  |cffb59a71(#%s)|r',i,lvl,tostring(entry.title),tostring(entry.id))
                end
                lines[#lines+1]=''
                lines[#lines+1]='|cffbbbbbbExpand the arrow on the left and select a quest to see its full details.|r'
                self.details:SetHeight(1000)
                self.details:SetText(table.concat(lines,'\n'))
                local h=self.details:GetStringHeight() or 0
                self.details:SetHeight(math.max(20,h+6))
                self.detailContent:SetHeight(math.max(400,h+20))
                return
            end
        end
        local selected=SelectedRow()
        local owner=selected and selected.ownerKey or AF:GetCurrentKey()
        local record=CharacterRecord(owner) or {active={},completed={},history={}}
        local q=(record.active or {})[pickedID] or (record.completed or {})[pickedID]
        local ref=pickedID and AF.GetQuestReference and AF:GetQuestReference(pickedID)
        local name=q and q.title or (selected and selected.title) or (pickedID and ('Quest #'..pickedID) or 'Select a quest')
        if pickedID and (not name or name==('Quest #'..pickedID)) then
            local clientTitle=AF.GetQuestRecordTitle and AF:GetQuestRecordTitle(pickedID)
            local refTitle=ref and ((ref.text and ref.text.title) or (ref.quest and ref.quest.title))
            name=clientTitle or refTitle or name
            if clientTitle and q then q.title=clientTitle end
        end
        local level=q and q.level or selected and selected.level
        if not level and ref and ref.quest then level=tonumber(ref.quest.questLevel or ref.quest.level) end
        if level and level>0 then name='['..level..'] '..name end
        self.detailTitle:SetText(name)
        local lines={}
        if pickedID then
            lines[#lines+1]='|cffbca480Quest ID|r  '..tostring(pickedID)
            if activeTab=='history' and selected then
                local events={['turned-in']='|cff44dd66TURNED IN|r',accepted='|cff44aaffACCEPTED|r',observed='|cffbbbbbbFIRST OBSERVED|r'}
                lines[#lines+1]=(events[selected.kind] or '|cffbbbbbbRECORDED|r')..'  '..Stamp(selected.at)
            end
            if level and level>0 then lines[#lines+1]='|cffbca480Quest level|r  '..tostring(level) end
            if record.completed and record.completed[pickedID] then
                local done=record.completed[pickedID]
                if type(done.at)=='number' and done.at>0 then
                    lines[#lines+1]='|cff77da87Turned in|r  '..Stamp(done.at)
                    if done.timesTurnedIn and done.timesTurnedIn>1 then
                        lines[#lines+1]='Observed turn-ins: '..tostring(done.timesTurnedIn)
                    end
                else
                    lines[#lines+1]='|cffffd16bCompleted before tracking|r  •  Date unknown'
                    if done.recoveredAt then lines[#lines+1]='|cffbca480Recovered|r  '..Stamp(done.recoveredAt) end
                end
            elseif record.active and record.active[pickedID] then
                lines[#lines+1]=q.readyToTurnIn and '|cff77da87Ready to turn in|r' or '|cffb4cfffActive quest|r'
                lines[#lines+1]='|cffbca480First observed|r  '..Stamp(q.firstSeen)
            else lines[#lines+1]='Previously observed event' end
        else lines[#lines+1]=currentRows and #currentRows==0 and 'No matching quests. Try another search or filter.' or 'Choose a quest on the left to view its details.' end
        if selected then
            if browserScope=='all' and selected.ownerKeys and #selected.ownerKeys>0 then
                local owners={}
                for _,key in ipairs(selected.ownerKeys) do owners[#owners+1]=AF:GetQuestBrowserCharacterLabel(key) end
                lines[#lines+1]='|cffbca480Recorded for|r  '..table.concat(owners,', ')
            elseif owner~=AF:GetCurrentKey() then
                lines[#lines+1]='|cffbca480Character|r  '..AF:GetQuestBrowserCharacterLabel(owner)
            end
            if owner~=AF:GetCurrentKey() and activeTab=='active' then
                lines[#lines+1]='|cffbca480Offline quest snapshot; live objectives unavailable.|r'
            end
        end
        local live=(owner==AF:GetCurrentKey() and activeTab=='active' and record.active[pickedID]~=nil)
        local rich=pickedID and AF.GetRichQuestDetails and AF:GetRichQuestDetails(pickedID,live)
        if rich and activeTab=='active' and not live then
            -- The quest is active on an offline character; static reference text
            -- is useful, but it is NOT a recovered completed quest.
            rich.historical=false
        end
        self:RenderRich(rich,table.concat(lines,'\n'))
    end
    function panel:Refresh()
        AF:GetCharacterQuestRecords() -- Ensure only the CURRENT character's record exists.
        local rows=Rows();currentRows=rows
        local rowHeight=activeTab=='history' and 46 or 30
        local totals=currentTotals or {}
        local statusTitle=(browserScope=='all') and ('All recorded ('..(totals.characters or 0)..' chars)')
            or (browserScope=='current' and 'This character' or AF:GetQuestBrowserCharacterLabel(browserScope))
        local total=totals[activeTab] or 0
        local readySummary=activeTab=='active' and ('  •  '..(totals.ready or 0)..' ready') or ''
        self.status:SetText(string.format('%s  |  %d %s%s%s',statusTitle,total,
            activeTab=='history' and 'events' or activeTab=='completed' and 'completed' or 'active',
            readySummary,
            (searchQuery:match('%S') or filters[activeTab]~='all') and ('  •  '..(totals.filtered or 0)..' shown') or ''))
        local selectedScope='This character'
        for _,option in ipairs(AF:GetQuestBrowserScopes()) do
            if option.key==browserScope then selectedScope=option.label;break end
        end
        -- UI:Button uses button.label for its visible caption (the Button's
        -- own SetText does not update the text drawn on screen).
        self.scopeButton.label:SetText('Character: '..selectedScope)
        local filterName='All'
        for _,option in ipairs(CurrentFilterOptions()) do
            if option[1]==filters[activeTab] then filterName=option[2];break end
        end
        self.filterButton.label:SetText('Filter: '..filterName)
        for k,b in pairs(self.tabs) do
            if UI.SetButtonSelected then UI:SetButtonSelected(b,k==activeTab) end
        end
        local old=self.listScroll:GetVerticalScroll() or 0
        local viewport=(self.listScroll.GetHeight and self.listScroll:GetHeight()) or 0
        if viewport<100 then viewport=390 end
        self.listContent:SetHeight(math.max(viewport,#rows*rowHeight))
        for i,b in ipairs(self.rowButtons) do b:Hide() end
        -- Recycle only visible rows even when the quest log contains hundreds of entries.
        local function UpdateVisible()
            local offset=math.floor((self.listScroll:GetVerticalScroll() or 0)/rowHeight)
            for i,b in ipairs(self.rowButtons) do
                local index=offset+i;local item=currentRows[index]
                if item then
                    b.questID=item.id;b.questEvent=item.eventIndex;b.rowKey=item.rowKey;b.ownerKey=item.ownerKey
                    b.groupKey=item.groupKey
                    b.rowType=item.rowType
                    b:SetHeight(activeTab=='history' and 43 or 28)
                    b.label:SetHeight(activeTab=='history' and 41 or 25)
                    b:ClearAllPoints();b:SetPoint('TOPLEFT',self.listContent,'TOPLEFT',0,-(index-1)*rowHeight)
                    local prefix=(item.level and item.level>0) and ('['..tostring(item.level)..'] ') or ''
                    if activeTab=='history' then
                        local color=item.kind=='turned-in' and '|cff55dd77' or (item.kind=='accepted' and '|cff63baff' or '|cffbbbbbb')
                        local event=item.kind=='turned-in' and 'Turned in' or (item.kind=='accepted' and 'Accepted' or 'First seen')
                        local who=(browserScope=='all') and (' |cffbaa888['..(item.ownerLabel or '?')..']|r') or ''
                        b.label:SetText(color..event..'|r  |cffd5b987'..Stamp(item.at)..'|r'..who..'\n|cffffffff'..prefix..tostring(item.title)..'|r')
                    else
                        if item.rowType=='group' then
                            local expanded=expandedGroups[item.groupKey]
                            local arrow=expanded and 'v' or '>'
                            b.label:SetText('|cffffd16b'..arrow..'|r  |cffffd16b'..tostring(item.title)..'|r |cffb8a289('..item.group.count..')|r')
                        else
                            local marker=(activeTab=='completed' and item.source=='historical') and '|cffd7b36c*|r ' or ''
                            local indent=item.rowType=='child' and '|cffb59a71  > |r' or ''
                            local showID=item.showID and (' |cff907f6b(#'..item.id..')|r') or ''
                            local owners=(browserScope=='all' and item.ownerKeys and #item.ownerKeys>1)
                                and (' |cffb8a289('..#item.ownerKeys..' chars)|r') or ''
                            b.label:SetText(indent..marker..prefix..tostring(item.title)..showID..owners)
                        end
                    end
                    b:Show()
                else b:Hide() end
            end
        end
        self.listScroll:SetScript('OnVerticalScroll',function(s,delta)
            local range=math.max(0,#currentRows*rowHeight-viewport)
            s:SetVerticalScroll(math.max(0,math.min(range,delta)))
            UpdateVisible()
        end)
        self.listScroll:SetVerticalScroll(math.max(0,math.min(old,math.max(0,#rows*rowHeight-viewport))))
        UpdateVisible()
        local valid=false
        if pickedGroupKey and currentGroups and currentGroups[pickedGroupKey] then
            for _,entry in ipairs(rows) do if entry.rowType=='group' and entry.groupKey==pickedGroupKey then valid=true;break end end
        elseif pickedRowKey then
            for _,entry in ipairs(rows) do if entry.rowKey==pickedRowKey then valid=true;break end end
        end
        if not valid then
            pickedID=nil;pickedEvent=nil;pickedGroupKey=nil;pickedRowKey=nil;pickedOwnerKey=nil
            if rows[1] then
                if rows[1].rowType=='group' then pickedGroupKey=rows[1].groupKey
                else
                    pickedID=rows[1].id;pickedEvent=rows[1].eventIndex
                    pickedRowKey=rows[1].rowKey;pickedOwnerKey=rows[1].ownerKey
                end
            end
        end
        self:RefreshDetails()
    end
    panel:Hide()
end
-- Called by Quest Recap's 'Journal' button. Select the actual quest ID,
-- not a same-name variant, and never toggle an already visible journal shut.
function UI:OpenQuestJournalAtQuest(questID)
    questID=tonumber(questID)
    if not questID or questID<=0 then return end
    Setup()
    local chosenScope,chosenTab='current',nil
    for _,candidate in ipairs({'completed','active'}) do
        local entries=AF:GetQuestBrowserEntries('current',candidate,'','all')
        for _,entry in ipairs(entries or {}) do
            if entry.id==questID then chosenTab=candidate;break end
        end
        if chosenTab then break end
    end
    if not chosenTab then
        chosenScope='all'
        for _,candidate in ipairs({'completed','active'}) do
            local entries=AF:GetQuestBrowserEntries('all',candidate,'','all')
            for _,entry in ipairs(entries or {}) do
                if entry.id==questID then chosenTab=candidate;break end
            end
            if chosenTab then break end
        end
    end
    browserScope=chosenScope
    activeTab=chosenTab or 'completed'
    filters[activeTab]='all'
    pickedID=nil;pickedEvent=nil;pickedGroupKey=nil;pickedRowKey=nil;pickedOwnerKey=nil
    searchQuery=tostring(questID)
    panel.search:SetText(searchQuery)
    panel.listScroll:SetVerticalScroll(0)
    panel:Refresh()
    local position
    for i,row in ipairs(currentRows or {}) do
        if row.id==questID and row.rowType~='group' then
            pickedID=questID;pickedRowKey=row.rowKey;pickedOwnerKey=row.ownerKey
            pickedGroupKey=nil;position=i;break
        end
    end
    if position then
        panel.listScroll:SetVerticalScroll(math.max(0,(position-3)*30))
        panel:RefreshDetails()
    elseif AF.Print then
        AF.Print('Quest #'..questID..' has no saved journal record in the selected scope.')
    end
    panel:Show();panel:SetFrameStrata('TOOLTIP')
    panel:SetFrameLevel(315)
    if panel.Raise then panel:Raise() end
end
function UI:ToggleQuestJournal()
    Setup()
    if panel:IsShown() then panel:Hide() else
        if AF.ScanQuestRecords then AF:ScanQuestRecords() end
        if AF.BackfillCompletedQuestRecords then AF:BackfillCompletedQuestRecords() end
        panel:Refresh();panel:Show();panel:SetFrameStrata('TOOLTIP');panel:SetFrameLevel(250)
        if panel.Raise then panel:Raise() end
    end
end
function UI:RefreshQuestJournal()
    if panel and panel:IsShown() then panel:Refresh() end
end
-- The item cache loads asynchronously. Only refresh the visible detail pane
-- for an item we explicitly requested from a displayed quest reward.
function UI:OnQuestItemInfoReceived(itemID)
    if not (panel and panel:IsShown()) then
        if AF.QuestRewardItemDataReceived then AF:QuestRewardItemDataReceived(itemID) end
        return
    end
    if not (AF.QuestRewardItemDataReceived and AF:QuestRewardItemDataReceived(itemID)) then return end
    if panel.itemRefreshQueued then return end
    panel.itemRefreshQueued=true
    local function RefreshDetails()
        panel.itemRefreshQueued=false
        if panel and panel:IsShown() and panel.RefreshDetails then
            local offset=panel.detailScroll and panel.detailScroll:GetVerticalScroll() or 0
            panel:RefreshDetails()
            if panel.detailScroll then panel.detailScroll:SetVerticalScroll(offset) end
        end
    end
    if C_Timer and type(C_Timer.After)=='function' then C_Timer.After(.15,RefreshDetails)
    else RefreshDetails() end
end

-- v0.4.1.2: Focus selected quest on the native map when a reliable map ID is available.
function UI:FocusAtlasQuest(questID)
    questID=tonumber(questID)
    if not questID then return end
    local mapID
    if C_QuestLog then
        for _,method in ipairs({'GetQuestUiMapID','GetQuestZoneID'}) do
            if type(C_QuestLog[method])=='function' then
                local ok,v=pcall(C_QuestLog[method],questID)
                if ok and tonumber(v) and v>0 then mapID=v;break end
            end
        end
    end
    if not mapID and type(GetQuestUiMapID)=='function' then
        local ok,v=pcall(GetQuestUiMapID,questID)
        if ok and tonumber(v) and v>0 then mapID=v end
    end
    if not mapID or not AF.GetAtlasMapInfo or not AF:GetAtlasMapInfo(mapID) then
        if AF.Print then AF.Print('No Atlas map location is available for quest #'..questID..'.') end
        return
    end
    self:Open('Exploration')
    local atlas=self.pageViews and self.pageViews.Exploration
    if not atlas or not atlas.Navigate then
        if AF.Print then AF.Print('Atlas map is not ready for quest focus.') end
        return
    end
    atlas:Navigate(mapID)
    if atlas.SetMapZoom then atlas:SetMapZoom(3) end
    -- A map ID is reliable; a specific quest position is not guaranteed by the client.
    -- Only use an exact POI coordinate when the corresponding quest ID matches.
    if C_QuestLog and type(C_QuestLog.GetQuestsOnMap)=='function' then
        local ok,rows=pcall(C_QuestLog.GetQuestsOnMap,mapID)
        if ok and type(rows)=='table' then
            for _,item in ipairs(rows) do
                if tonumber(item.questID)==questID then
                    local x,y=tonumber(item.x),tonumber(item.y)
                    if (not x or not y) and type(item.position)=='table' then
                        x,y=tonumber(item.position.x),tonumber(item.position.y)
                    end
                    if x and y and x>=0 and x<=1 and y>=0 and y<=1 and atlas.mapCanvas and atlas.viewport then
                        local w,h=atlas.mapCanvas:GetSize()
                        atlas.offsetX=(.5-x)*w
                        atlas.offsetY=(y-.5)*h
                        atlas:RepositionTiles()
                    end
                    break
                end
            end
        end
    end
end
