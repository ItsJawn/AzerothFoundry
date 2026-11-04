-- Azeroth Foundry v0.4.2.3: regional story navigation with original quest text.
-- Read-only summaries: history timestamps are actual recorded event times only.
local _, AF = ...
local UI=AF.UI
local panel
local tab='stories'
local scope='current'
local query=''
local selectedKey
local chapter=1
local storyFilter='all'
local timelineOpen={}
local timelineSessionsOpen={} -- session group expansion; in-memory only
local timelineMode='sessions' -- switchable to original day-grouped history
local storyExpanded={} -- UI state only: never saved and never alters quest records
local zoneExpanded={} -- expanded region keys, ephemeral UI state only
local zoneGroupsExpanded={} -- expanded region/story pairs
local readMode='chapter' -- 'chapter' or 'full'; full is for verified chains only
local storyByKey={}
local rows={}
local currentStories={}
local function Stamp(value)
    if type(value)~='number' or value<=0 then return 'Date unknown' end
    if type(date)=='function' then return date('%d %b %Y, %H:%M',value) end
    return tostring(value)
end
local function Name(owner)
    if AF.GetQuestBrowserCharacterLabel then return AF:GetQuestBrowserCharacterLabel(owner) end
    return tostring(owner or 'Character')
end
local function Text(parent,label,font,role)
    local node=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall')
    node:SetText(label or '')
    node:SetJustifyH('LEFT');node:SetJustifyV('TOP')
    if node.SetWordWrap then node:SetWordWrap(true) end
    if node.SetMaxLines then pcall(node.SetMaxLines,node,0) end
    if node.SetShadowOffset then node:SetShadowOffset(0,0) end
    if node.SetShadowColor then node:SetShadowColor(0,0,0,0) end
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(node,function(label,t)
        if label.afPreserveQuestColor then return end
        -- Quest windows have dark reading surfaces even in parchment/light
        -- presets. Match text to the surface it is actually painted on.
        local surface=role=='shell' and t.shell or t.dataSurface
        local preferred=role=='shell' and t.text or t.dataText
        local c=UI.ThemeReadableText and UI:ThemeReadableText(surface,preferred) or preferred
        label:SetTextColor(c[1],c[2],c[3],1)
    end) end
    return node
end
local function QuestRecord(id)
    local chars=AF.db and AF.db.questRecords and AF.db.questRecords.characters or {}
    if scope~='all' then
        local key=scope=='current' and AF:GetCurrentKey() or scope
        local r=chars[key]
        if r then
            return (r.completed and r.completed[id]) or (r.active and r.active[id])
        end
        return nil
    end
    -- Prefer the current character in the account view when available.
    local mine=chars[AF:GetCurrentKey()]
    local preferred=mine and ((mine.completed and mine.completed[id]) or (mine.active and mine.active[id]))
    if preferred then return preferred end
    return AF.GetQuestRecapRecord and AF:GetQuestRecapRecord(id) or nil
end
local function QuestTitle(id)
    local q=QuestRecord(id)
    local title=q and q.title
    if not title or title==('Quest #'..tostring(id)) then
        local ref=AF.GetQuestReference and AF:GetQuestReference(id)
        title=(ref and ((ref.text and ref.text.title) or (ref.quest and ref.quest.title)))
            or (AF.GetQuestRecordTitle and AF:GetQuestRecordTitle(id)) or title
    end
    return title or ('Quest #'..tostring(id)),q
end
local function PrettyLines(info,title,completed)
    local lines={}
    local function Section(name,value)
        if type(value)=='string' and value:match('%S') then
            lines[#lines+1]=''
            lines[#lines+1]='|cffffd16b'..name..'|r'
            lines[#lines+1]=value
        end
    end
    if not info then
        lines[#lines+1]='Reference text is unavailable for this quest.'
        return lines
    end
    Section(info.capturedFields and info.capturedFields.description and 'STORY (CAPTURED IN GAME)' or 'STORY',info.description)
    Section('OBJECTIVES',info.objectivesText)
    Section(info.capturedFields and info.capturedFields.progressText and 'PROGRESS DIALOGUE (RECORDED)' or 'PROGRESS DIALOGUE (REFERENCE)',info.progressText)
    if completed then
        Section(info.capturedFields and info.capturedFields.turnInText and 'TURN-IN DIALOGUE (RECORDED)' or 'TURN-IN NOTES (REFERENCE)',info.turnInText)
        Section('ENDING DIALOGUE (REFERENCE)',info.endText)
    elseif (info.turnInText and info.turnInText~='') or (info.endText and info.endText~='') then
        lines[#lines+1]=''
        lines[#lines+1]='|cffbfa887Completion dialogue is hidden until this quest has been recorded as completed.|r'
    end
    if #lines==0 then
        lines[#lines+1]='Full dialogue is unavailable for '..tostring(title)..'. Foundry can preserve text when a quest is viewed or accepted in-game, but cannot reconstruct older text absent from the database.'
    end
    return lines
end
local function FindRow()
    if tab=='stories' then return storyByKey[selectedKey] end
    for _,r in ipairs(rows) do if r.key==selectedKey then return r end end
end
local function QuestChapterLines(story,index,full)
    local id=story.ids[index]
    local name,record=QuestTitle(id)
    local state=currentStories and currentStories[id]
    local completed=state and state.completed
    local lines={}
    if full then lines[#lines+1]='|cffffd16bCHAPTER '..index..' — '..name..'|r' end
    if not full then lines[#lines+1]='|cffffd16bCHAPTER '..index..' OF '..#story.ids..'|r' end
    lines[#lines+1]=name..'  |cffbfa887(#'..tostring(id)..')|r'
    if completed then
        lines[#lines+1]=state.date and ('|cff88dd99Recorded turn-in: '..Stamp(state.date)..'|r')
            or '|cffd6b77bCompleted before tracking — exact date unknown|r'
    elseif state and state.active then
        lines[#lines+1]='|cff85baffActive / observed — completion dialogue hidden|r'
    elseif record then lines[#lines+1]='|cffbbbbbbRecorded quest|r' end
    lines[#lines+1]='|cffbfa887Original text below comes from available quest references or dialogue captured in-game; no events are reconstructed.|r'
    local info=AF.GetRichQuestDetails and AF:GetRichQuestDetails(id,false)
    for _,line in ipairs(PrettyLines(info,name,completed)) do lines[#lines+1]=line end
    return lines
end
local function Setup()
    if panel then return end
    panel=CreateFrame('Frame','AzerothFoundryQuestRecap',UIParent)
    panel:SetSize(830,625)
    panel:SetPoint('CENTER',UIParent,'CENTER',-10,-15)
    panel:SetFrameStrata('TOOLTIP');panel:SetFrameLevel(270)
    panel:SetClampedToScreen(true);panel:EnableMouse(true)
    panel:SetMovable(true);panel:RegisterForDrag('LeftButton')
    panel:SetScript('OnDragStart',function(self) self:StartMoving() end)
    panel:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
    local bg=panel:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.09,.075,.055,.97) -- recolored by theme below
    local trim=panel:CreateTexture(nil,'BORDER');trim:SetHeight(3)
    trim:SetPoint('TOPLEFT');trim:SetPoint('TOPRIGHT');trim:SetColorTexture(.75,.55,.25,1)
    local icon=panel:CreateTexture(nil,'ARTWORK');icon:SetSize(19,19)
    icon:SetPoint('TOPLEFT',13,-14);icon:SetTexture('Interface\\GossipFrame\\AvailableQuestIcon')
    local title=Text(panel,'QUEST RECAP','GameFontNormalLarge','shell')
    title:SetPoint('TOPLEFT',37,-13)
    local close=UI:Button(panel,'X',function() panel:Hide() end)
    close:SetSize(34,25);close:SetPoint('TOPRIGHT',-12,-11)
    panel.status=Text(panel,'','GameFontNormalSmall','shell');panel.status:SetPoint('TOPLEFT',15,-46)
    panel.status:SetWidth(775);panel.status:SetHeight(18)
    panel.tabs={}
    local tabs={{'stories','Stories'},{'timeline','Timeline'},{'zones','Zones'}}
    for i,entry in ipairs(tabs) do
        local key=entry[1]
        local button=UI:Button(panel,entry[2],function()
            tab=key;selectedKey=nil;chapter=1;readMode='chapter'
            panel.listScroll:SetVerticalScroll(0);panel.detailScroll:SetVerticalScroll(0)
            panel:Refresh()
        end)
        button:SetSize(111,25);button:SetPoint('TOPLEFT',15+(i-1)*117,-75)
        panel.tabs[key]=button
    end
    local storyView=UI:Button(panel,'Stories: All',function()
        if tab~='stories' then return end
        local choices={'all','chains','singles','variants'}
        local index=1
        for i,v in ipairs(choices) do if v==storyFilter then index=i;break end end
        storyFilter=choices[index%#choices+1]
        selectedKey=nil;chapter=1;readMode='chapter';panel.listScroll:SetVerticalScroll(0)
        panel:Refresh()
    end)
    -- Allow full labels such as 'Stories: Standalone' to fit on one line.
    storyView:SetSize(168,25);storyView:SetPoint('TOPLEFT',384,-75)
    panel.storyView=storyView
    local timelineView=UI:Button(panel,'Timeline: Sessions',function()
        if tab~='timeline' then return end
        timelineMode=(timelineMode=='sessions') and 'days' or 'sessions'
        selectedKey=nil;panel.listScroll:SetVerticalScroll(0)
        panel.detailScroll:SetVerticalScroll(0)
        panel:Refresh()
    end)
    timelineView:SetSize(168,25);timelineView:SetPoint('TOPLEFT',384,-75)
    panel.timelineView=timelineView
    local refresh=UI:Button(panel,'Refresh records',function()
        if AF.ScanQuestRecords then AF:ScanQuestRecords() end
        if AF.BackfillCompletedQuestRecords then AF:BackfillCompletedQuestRecords() end
        if AF.ClearRecapQuestMapCache then AF:ClearRecapQuestMapCache() end
        selectedKey=nil;panel:Refresh()
    end)
    refresh:SetSize(147,25);refresh:SetPoint('TOPRIGHT',-15,-75)
    local search=CreateFrame('EditBox',nil,panel,'InputBoxTemplate')
    search:SetSize(246,26);search:SetPoint('TOPLEFT',23,-110)
    panel.search=search
    search:SetAutoFocus(false);search:SetText('')
    search:SetScript('OnTextChanged',function(self,userInput)
        if not userInput then return end
        query=self:GetText() or ''
        selectedKey=nil;chapter=1;readMode='chapter'
        panel.listScroll:SetVerticalScroll(0);panel:Refresh()
    end)
    search:SetScript('OnEnterPressed',function(self) self:ClearFocus() end)
    search:SetScript('OnEscapePressed',function(self)
        if self:GetText()~='' then self:SetText('') else self:ClearFocus() end
    end)
    local label=Text(panel,'Search stories, events, or zones','GameFontNormalSmall','shell')
    label:SetPoint('TOPLEFT',278,-115)
    label:SetWidth(205);label:SetHeight(19)
    local choose=UI:Button(panel,'Character: this',function()
        local scopes=AF:GetQuestRecapScopes()
        local i=1
        for j,v in ipairs(scopes) do if v.key==scope then i=j;break end end
        scope=scopes[i%#scopes+1].key
        selectedKey=nil;chapter=1;readMode='chapter';panel.listScroll:SetVerticalScroll(0);panel:Refresh()
    end)
    choose:SetSize(239,26);choose:SetPoint('TOPRIGHT',-18,-108)
    panel.scopeButton=choose
    local left=CreateFrame('Frame',nil,panel)
    left:SetPoint('TOPLEFT',14,-147);left:SetPoint('BOTTOMLEFT',14,36);left:SetWidth(298)
    local leftBG=left:CreateTexture(nil,'BACKGROUND');leftBG:SetAllPoints();leftBG:SetColorTexture(.18,.135,.09,.93) -- recolored by theme below
    local right=CreateFrame('Frame',nil,panel)
    right:SetPoint('TOPLEFT',left,'TOPRIGHT',9,0);right:SetPoint('BOTTOMRIGHT',-14,36)
    local rightBG=right:CreateTexture(nil,'BACKGROUND');rightBG:SetAllPoints();rightBG:SetColorTexture(.16,.12,.08,.95)
    -- Theme the floating recap itself, not just buttons and labels.
    -- Dark data panes keep quest-reference markup legible in every preset;
    -- the outer shell and accent border follow the selected theme.
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(panel,function(_,t)
        local shell=t.shell
        bg:SetColorTexture(shell[1],shell[2],shell[3],.99)
        local edgeColor=t.divider
        trim:SetColorTexture(edgeColor[1],edgeColor[2],edgeColor[3],1)
        local data=t.dataSurface
        local nav=t.navActive
        leftBG:SetColorTexture(data[1]*.86+nav[1]*.14,data[2]*.86+nav[2]*.14,data[3]*.86+nav[3]*.14,1)
        rightBG:SetColorTexture(data[1],data[2],data[3],1)
    end) end
    panel.detailTitle=Text(right,'Select a story','GameFontNormal')
    panel.detailTitle:SetPoint('TOPLEFT',12,-10);panel.detailTitle:SetPoint('TOPRIGHT',-18,-10)
    panel.detailTitle:SetHeight(29)
    local prev=UI:Button(right,'<',function()
        chapter=math.max(1,chapter-1)
        panel.detailScroll:SetVerticalScroll(0)
        panel:RefreshListHighlights()
    end)
    prev:SetSize(36,24);prev:SetPoint('TOPLEFT',13,-46)
    local nextButton=UI:Button(right,'>',function()
        chapter=chapter+1
        panel.detailScroll:SetVerticalScroll(0)
        panel:RefreshListHighlights()
    end)
    nextButton:SetSize(36,24);nextButton:SetPoint('LEFT',prev,'RIGHT',6,0)
    local step=Text(right,'','GameFontNormalSmall')
    step:SetPoint('LEFT',nextButton,'RIGHT',9,0);step:SetSize(122,22)
    local locate=UI:Button(right,'Atlas',function()
        local selected=FindRow()
        if not selected then return end
        if tab=='stories' then
            local questID=selected.ids and selected.ids[chapter]
            if questID and UI.FocusAtlasQuest then UI:FocusAtlasQuest(questID) end
        elseif tab=='timeline' then
            if selected.questID and UI.FocusAtlasQuest then UI:FocusAtlasQuest(selected.questID)
            elseif selected.mapID and UI.OpenQuestRecapAtlasZone then UI:OpenQuestRecapAtlasZone(selected.mapID) end
        elseif tab=='zones' then
            if selected.questID and UI.FocusAtlasQuest then
                UI:FocusAtlasQuest(selected.questID)
            elseif selected.mapID and UI.OpenQuestRecapAtlasZone then
                UI:OpenQuestRecapAtlasZone(selected.mapID)
            end
        end
    end)
    locate:SetSize(67,24);locate:SetPoint('TOPRIGHT',-13,-46)
    local journal=UI:Button(right,'Journal',function()
        local selected=FindRow()
        if not selected then return end
        local questID
        if tab=='stories' then questID=selected.ids and selected.ids[chapter]
        elseif tab=='zones' or tab=='timeline' then questID=selected.questID or (selected.ids and selected.ids[1]) end
        if questID and UI.OpenQuestJournalAtQuest then UI:OpenQuestJournalAtQuest(questID) end
    end)
    journal:SetSize(73,24);journal:SetPoint('RIGHT',locate,'LEFT',-5,0)
    local reading=UI:Button(right,'Read all',function()
        local selected=FindRow()
        if tab~='stories' or not selected or selected.groupKind~='chain' or #selected.ids<=1 then return end
        readMode=(readMode=='chapter') and 'full' or 'chapter'
        panel.detailScroll:SetVerticalScroll(0)
        panel:RefreshDetail()
    end)
    reading:SetSize(92,24);reading:SetPoint('RIGHT',journal,'LEFT',-5,0)
    local openStory=UI:Button(right,'Read story',function()
        local selected=FindRow()
        if (tab~='zones' and tab~='timeline') or not selected then return end
        local id=selected.questID or (selected.ids and selected.ids[1])
        if id and UI.OpenQuestRecapAtQuest then UI:OpenQuestRecapAtQuest(id,scope) end
    end)
    openStory:SetSize(92,24);openStory:SetPoint('RIGHT',journal,'LEFT',-5,0)
    panel.prev=prev;panel.next=nextButton;panel.step=step;panel.locate=locate
    panel.journal=journal;panel.reading=reading;panel.openStory=openStory
    local detailScroll=CreateFrame('ScrollFrame',nil,right,'UIPanelScrollFrameTemplate')
    detailScroll:SetPoint('TOPLEFT',10,-80);detailScroll:SetPoint('BOTTOMRIGHT',-30,9)
    local detailContent=CreateFrame('Frame',nil,detailScroll)
    detailContent:SetSize(440,400);detailScroll:SetScrollChild(detailContent)
    local detail=Text(detailContent,'','GameFontHighlightSmall')
    detail:SetPoint('TOPLEFT',2,-3);detail:SetWidth(430);detail:SetHeight(1000)
    panel.detail=detail;panel.detailContent=detailContent;panel.detailScroll=detailScroll
    panel.fullChapterNodes={} -- recycled text blocks, not one giant potentially clipped font string
    local listScroll=CreateFrame('ScrollFrame',nil,left,'UIPanelScrollFrameTemplate')
    listScroll:SetPoint('TOPLEFT',5,-7);listScroll:SetPoint('BOTTOMRIGHT',-29,9)
    local listContent=CreateFrame('Frame',nil,listScroll)
    listContent:SetSize(257,400);listScroll:SetScrollChild(listContent)
    panel.listContent=listContent;panel.listScroll=listScroll
    panel.buttons={}
    for i=1,18 do
        local button=CreateFrame('Button',nil,listContent)
        button:SetSize(256,33)
        local shade=button:CreateTexture(nil,'BACKGROUND');shade:SetAllPoints()
        shade:SetColorTexture(.43,.29,.13,i%2==0 and .28 or .17)
        if UI.RegisterThemeTarget then UI:RegisterThemeTarget(button,function(_,t)
            local c=t.accent3 or t.accent
            shade:SetColorTexture(c[1],c[2],c[3],i%2==0 and .19 or .10)
        end) end
        local name=Text(button,'','GameFontHighlightSmall')
        name:SetPoint('LEFT',6,0);name:SetPoint('RIGHT',-6,0);name:SetHeight(29)
        button.label=name
        button:SetScript('OnClick',function(self)
            local clicked
            for _,r in ipairs(rows) do
                if r.key==self.rowKey then clicked=r;break end
            end
            if clicked and clicked.kind=='day' then
                timelineOpen[clicked.dayKey]=not clicked.opened
                selectedKey=clicked.key
                panel:Refresh()
                return
            elseif clicked and tab=='timeline' and clicked.kind=='session' then
                timelineSessionsOpen[clicked.key]=not clicked.opened
                selectedKey=clicked.key
                panel:Refresh()
                return
            elseif clicked and tab=='zones' and clicked.kind=='zone' then
                selectedKey=clicked.key
                zoneExpanded[clicked.key]=not clicked.opened
                panel.detailScroll:SetVerticalScroll(0)
                panel:Refresh()
                return
            elseif clicked and tab=='zones' and clicked.kind=='zone-story' then
                selectedKey=clicked.key
                zoneGroupsExpanded[clicked.key]=not clicked.opened
                panel.detailScroll:SetVerticalScroll(0)
                panel:Refresh()
                return
            elseif clicked and tab=='zones' and clicked.kind=='zone-chapter' then
                selectedKey=clicked.key
                panel.detailScroll:SetVerticalScroll(0)
                panel:RefreshDetail()
                return
            elseif clicked and tab=='stories' and clicked.kind=='chapter' then
                selectedKey=clicked.parentKey;chapter=clicked.chapterIndex
                readMode='chapter'
                panel.detailScroll:SetVerticalScroll(0)
                panel:RefreshListHighlights()
                return
            elseif clicked and tab=='stories' then
                if selectedKey~=clicked.key then chapter=1;readMode='chapter' end
                selectedKey=clicked.key;chapter=math.max(1,math.min(chapter,#clicked.ids))
                panel.detailScroll:SetVerticalScroll(0)
                storyExpanded[clicked.key]=not clicked.opened
                panel:Refresh()
                return
            end
            selectedKey=self.rowKey;chapter=1
            panel.detailScroll:SetVerticalScroll(0)
            panel:RefreshDetail()
        end)
        panel.buttons[i]=button
    end
    local footer=Text(panel,'Recorded quests and zone visits only. Undated completions stay undated.','GameFontHighlightSmall','shell')
    footer:SetPoint('BOTTOMLEFT',16,11);footer:SetPoint('BOTTOMRIGHT',-16,11);footer:SetHeight(18)
    panel.footer=footer
    function panel:RefreshDetail()
        local selected=FindRow()
        self.prev:Hide();self.next:Hide();self.step:SetText('')
        self.locate:Hide();self.journal:Hide();self.reading:Hide();self.openStory:Hide()
        self.detail:Show()
        for _,node in ipairs(self.fullChapterNodes) do node:Hide() end
        if not selected then
            self.detailTitle:SetText('Nothing selected')
            self.detail:SetText(#rows==0 and 'No recorded entries match the current view.' or 'Select an entry on the left.')
            self.detailContent:SetHeight(400)
            return
        end
        self.detailTitle:SetText(selected.title)
        local lines={}
        if tab=='stories' then
            if type(selected.ids)~='table' or #selected.ids==0 then
                self.detail:SetText('No recorded chapters are available for this story.')
                self.detailContent:SetHeight(400)
                return
            end
            chapter=math.max(1,math.min(chapter,#selected.ids))
            local isChain=selected.groupKind=='chain' and #selected.ids>1
            lines[#lines+1]='|cffffd16bSTORY PROGRESS|r'
            lines[#lines+1]=string.format('%d recorded chapter(s)  |  %d completed  |  %d active',
                selected.total,selected.completed,selected.active)
            if selected.groupKind=='variants' then
                lines[#lines+1]='|cffbfa887These are same-title variants, not a verified quest sequence.|r'
            elseif isChain then
                lines[#lines+1]='|cffbfa887Chapter order follows available LibQuestDB links; branches with no ordering link use title order.|r'
            end
            self.journal:Show();self.locate:Show()
            if isChain then
                self.reading:Show()
                self.reading.label:SetText(readMode=='full' and 'One chapter' or 'Read all')
            else readMode='chapter' end
            if readMode=='full' and isChain then
                self.detailTitle:SetText(selected.title..' — Full Story')
                -- Separate strings per quest avoid WoW FontString text-size limits
                -- and permit the entire recorded chain to scroll together.
                self.detail:Hide()
                local y=2
                local intro=string.format('|cffffd16bFULL RECORDED STORY|r\n%s\n%d recorded chapters | %d completed | %d active\n|cffbfa887Original quest-reference wording; unknown dates remain unknown.|r',
                    selected.title,selected.total,selected.completed,selected.active)
                for index=0,#selected.ids do
                    local node=self.fullChapterNodes[index+1]
                    if not node then
                        node=Text(self.detailContent,'','GameFontHighlightSmall')
                        node:SetWidth(430)
                        self.fullChapterNodes[index+1]=node
                    end
                    node:ClearAllPoints()
                    node:SetPoint('TOPLEFT',self.detailContent,'TOPLEFT',2,-y)
                    node:SetHeight(6000)
                    node:SetText(index==0 and intro or table.concat(QuestChapterLines(selected,index,true),'\n'))
                    node:Show()
                    local actual=node.GetStringHeight and node:GetStringHeight() or 100
                    local height=math.max(22,(tonumber(actual) or 0)+16)
                    node:SetHeight(height)
                    y=y+height+14
                end
                self.detailContent:SetHeight(math.max(400,y+15))
                self.step:SetText('All '..#selected.ids..' chapters')
            else
                for _,line in ipairs(QuestChapterLines(selected,chapter,false)) do lines[#lines+1]=line end
                if #selected.ids>1 then
                    self.prev:Show();self.next:Show()
                    if self.prev.SetEnabled then self.prev:SetEnabled(chapter>1) end
                    if self.next.SetEnabled then self.next:SetEnabled(chapter<#selected.ids) end
                    self.step:SetText('Chapter '..chapter..' / '..#selected.ids)
                end
            end
        elseif tab=='timeline' then
            if selected.kind=='session' then
                lines[#lines+1]='|cffffd16bESTIMATED ACTIVITY SESSION|r'
                lines[#lines+1]='Character: '..Name(selected.owner)
                lines[#lines+1]='First recorded activity: '..Stamp(selected.startAt)
                lines[#lines+1]='Last recorded activity: '..Stamp(selected.lastAt)
                lines[#lines+1]=''
                lines[#lines+1]=string.format('%d recorded events  |  %d quest events  |  %d zone entries',
                    selected.eventCount or 0,selected.questEvents or 0,selected.zoneVisits or 0)
                if selected.zoneNames and #selected.zoneNames>0 then
                    lines[#lines+1]=''
                    lines[#lines+1]='|cffffd16bZONES RECORDED IN THIS CLUSTER|r'
                    for _,name in ipairs(selected.zoneNames) do
                        lines[#lines+1]='  '..name
                    end
                end
                lines[#lines+1]=''
                lines[#lines+1]='|cffbfa887Inferred from recorded activity on one character, separated by gaps greater than 90 minutes. These are NOT confirmed login/logout times or measured playtime.|r'
                lines[#lines+1]='|cffbfa887Click this session to '..(selected.opened and 'collapse' or 'expand')..' its events.|r'
            elseif selected.kind=='day' then
                lines[#lines+1]='|cffffd16bADVENTURE DAY|r'
                lines[#lines+1]=selected.title
                lines[#lines+1]=string.format('%d recorded events | %d quest events | %d zone entries',
                    selected.dayEvents,selected.questEvents,selected.zoneVisits)
                lines[#lines+1]=''
                if timelineMode=='sessions' then
                    lines[#lines+1]=tostring(selected.sessionCount or 0)..' inferred activity session(s)'
                    lines[#lines+1]='Click the date to reveal sessions, then expand a session to inspect actual recorded events.'
                    lines[#lines+1]='|cffbfa887A 90-minute inactivity gap separates clusters. This is not a login/logout log or measured playtime.|r'
                else
                    lines[#lines+1]='Click this date to '..(selected.opened and 'collapse' or 'expand')..' its individual events.'
                end
                lines[#lines+1]='|cffbfa887Only records captured while Foundry was running have dates. Recovered historical completions are not assigned to a day.|r'
            else
            lines[#lines+1]='|cffffd16bRECORDED EVENT|r'
            lines[#lines+1]=Stamp(selected.at)
            lines[#lines+1]='Character: '..Name(selected.owner)
            lines[#lines+1]=''
            if selected.kind=='visit-group' then
                lines[#lines+1]='|cffdbb879Entered zone ('..selected.count..' recorded visit'..(selected.count==1 and '' or 's')..')|r'
                lines[#lines+1]=selected.title
                lines[#lines+1]='|cffbfa887Actual recorded times:|r'
                for _,at in ipairs(selected.visitTimes or {}) do
                    lines[#lines+1]='  '..Stamp(at)
                end
                if selected.mapID then self.locate:Show() end
            elseif selected.kind=='visit' then
                lines[#lines+1]='|cffdbb879Entered zone|r'
                lines[#lines+1]=selected.title
                lines[#lines+1]='|cffbfa887This time was recorded by Azeroth Foundry during play.|r'
                if selected.mapID then self.locate:Show() end
            else
                local labels={accepted='|cff63baffAccepted|r',observed='|cffbbbbbbFirst observed|r',
                    ['turned-in']='|cff77da87Turned in|r'}
                lines[#lines+1]=labels[selected.questEvent] or 'Quest recorded'
                lines[#lines+1]=selected.title..'  |cffbfa887(#'..selected.questID..')|r'
                if selected.questEvent=='observed' then
                    lines[#lines+1]='This is when Foundry first saw the quest, not necessarily when it was accepted.'
                end
                self.journal:Show();self.openStory:Show()
                local ref=AF.GetRichQuestDetails and AF:GetRichQuestDetails(selected.questID,false)
                for _,line in ipairs(PrettyLines(ref,selected.title,selected.questEvent=='turned-in')) do lines[#lines+1]=line end
                self.locate:Show()
            end
            end
        elseif tab=='zones' then
            self.locate:Show()
            if selected.kind=='zone-chapter' then
                self.detailTitle:SetText(selected.title)
                self.journal:Show();self.openStory:Show()
                lines[#lines+1]='|cffffd16bREGIONAL QUEST CHAPTER|r'
                lines[#lines+1]=selected.title..'  |cffbfa887(#'..selected.questID..')|r'
                if selected.completed then
                    lines[#lines+1]='|cff88dd99Completed|r — original completion date may be unknown'
                elseif selected.active then
                    lines[#lines+1]='|cff85baffActive quest|r'
                end
                lines[#lines+1]='Associated region: '..selected.zoneTitle
                lines[#lines+1]='|cffbfa887Location source: '..tostring(selected.source or 'Recorded region')..'|r'
                lines[#lines+1]='|cffbfa887This association is not proof of where the quest was completed.|r'
                local info=AF.GetRichQuestDetails and AF:GetRichQuestDetails(selected.questID,false)
                for _,line in ipairs(PrettyLines(info,selected.title,selected.completed)) do
                    lines[#lines+1]=line
                end
                lines[#lines+1]=''
                lines[#lines+1]='|cffbfa887Use Read story to open this quest inside its recorded storyline, or Journal for rewards and objectives.|r'
            elseif selected.kind=='zone-story' then
                self.journal:Show();self.openStory:Show()
                lines[#lines+1]='|cffffd16bREGIONAL QUEST GROUP|r'
                lines[#lines+1]=selected.title
                local typeName=selected.groupKind=='chain' and 'Linked storyline' or
                    (selected.groupKind=='variants' and 'Same-name quest variants' or 'Recorded quest')
                lines[#lines+1]=typeName
                lines[#lines+1]=string.format('%d quest(s) associated with %s  |  %d completed  |  %d active',
                    #selected.ids,selected.zoneTitle,selected.completed,selected.active)
                if selected.totalCount and selected.totalCount>#selected.ids then
                    lines[#lines+1]='|cffbfa887This recorded story also contains chapters associated with other or unknown regions.|r'
                end
                lines[#lines+1]='|cffbfa887Regional associations are provided by client quest maps or LibQuestDB; they are not timestamps or proof of a quest turn-in here.|r'
                lines[#lines+1]=''
                lines[#lines+1]='|cffffd16bRECORDED QUESTS|r'
                for i,id in ipairs(selected.ids) do
                    local q=selected.questEntries and selected.questEntries[id]
                    if q then
                        lines[#lines+1]=string.format('%d. %s |cffbfa887(#%d)|r — %s',i,q.title,id,
                            q.completed and '|cff88dd99Completed|r' or '|cff85baffActive|r')
                    end
                end
                lines[#lines+1]=''
                lines[#lines+1]='|cffbfa887Expand this group on the left to select an individual quest. Read story opens the original chapter reader.|r'
            else
                lines[#lines+1]='|cffffd16bREGIONAL ADVENTURE|r'
                lines[#lines+1]=selected.title
                if selected.visits>0 then
                    lines[#lines+1]='First recorded visit: '..Stamp(selected.firstSeen)
                    lines[#lines+1]='Last recorded visit: '..Stamp(selected.lastSeen)
                    lines[#lines+1]='Recorded visits: '..tostring(selected.visits)
                else
                    lines[#lines+1]='|cffbfa887No visits recorded since tracking began.|r'
                end
                lines[#lines+1]=''
                lines[#lines+1]='|cffffd16bKNOWN REGIONAL QUEST PROGRESS|r'
                lines[#lines+1]=string.format('%d recorded quests  |  %d completed  |  %d active',
                    selected.questCount or 0,selected.completedCount or 0,selected.activeCount or 0)
                lines[#lines+1]=string.format('%d recorded quest groups  |  %d linked storylines',
                    selected.storyCount or 0,selected.chainCount or 0)
                lines[#lines+1]='|cffbfa887These totals include only Foundry-recorded quests with a reliable region association. They do not measure every available quest in this zone.|r'
                lines[#lines+1]=''
                lines[#lines+1]='|cffffd16bSTORIES IN THIS REGION|r'
                if #(selected.stories or {})==0 then
                    lines[#lines+1]='No regional quest references available. Some Forever quests lack location metadata.'
                else
                    for i,story in ipairs(selected.stories) do
                        if i>28 then lines[#lines+1]='Additional groups available in the list.';break end
                        local kind=story.kind=='chain' and 'Storyline' or
                            (story.kind=='variants' and 'Variants' or 'Quest')
                        lines[#lines+1]=string.format('%s: %s |cffbfa887(%d/%d complete)|r',
                            kind,story.title,story.completed,#story.ids)
                    end
                end
                lines[#lines+1]=''
                lines[#lines+1]='|cffbfa887Click the zone on the left to expand its story groups, then expand a group to select a specific quest and open its original text.|r'
                lines[#lines+1]='|cffbfa887Region associations describe reference locations, not necessarily where the player accepted or completed a quest.|r'
            end
        end
        if tab=='stories' and readMode=='full' and selected.groupKind=='chain' and #selected.ids>1 then
            return -- full-mode child font strings already measured/positioned
        end
        self.detail:SetText(table.concat(lines,'\n'))
        -- Explicit generous provisional height prevents single-line truncation
        -- when WordWrap is first measured in the WoW client.
        self.detail:SetHeight(6000)
        local actual=self.detail.GetStringHeight and self.detail:GetStringHeight() or 350
        self.detail:SetHeight(math.max(45,actual+16))
        self.detailContent:SetHeight(math.max(400,actual+40))
    end
    function panel:Refresh()
        local totalEvents,dayCount,sessionCount
        if tab=='stories' then
            local allRows
            allRows,currentStories=AF:GetQuestRecapStories(scope,query)
            rows={};storyByKey={}
            for _,r in ipairs(allRows) do
                local show=(storyFilter=='all') or
                    (storyFilter=='chains' and r.groupKind=='chain') or
                    (storyFilter=='variants' and r.groupKind=='variants') or
                    (storyFilter=='singles' and not r.groupKind)
                if show then
                    storyByKey[r.key]=r
                    r.opened=storyExpanded[r.key]==true
                    rows[#rows+1]=r
                    if #r.ids>1 and r.opened then
                        for i,id in ipairs(r.ids) do
                            rows[#rows+1]={kind='chapter',key=r.key..':chapter:'..id,
                                parentKey=r.key,chapterIndex=i,questID=id,title=QuestTitle(id)}
                        end
                    end
                end
            end
        elseif tab=='timeline' then
            storyByKey={}
            if timelineMode=='sessions' then
                rows,totalEvents,dayCount,sessionCount=AF:GetQuestRecapTimelineSessions(scope,query,timelineOpen,timelineSessionsOpen)
            else
                rows,totalEvents,dayCount=AF:GetQuestRecapTimelineDays(scope,query,timelineOpen)
            end
        else
            storyByKey={};rows={}
            local zones=AF:GetQuestRecapZones(scope,query)
            for _,z in ipairs(zones) do
                z.opened=zoneExpanded[z.key]==true
                rows[#rows+1]=z
                if z.opened then
                    for _,story in ipairs(z.stories or {}) do
                        local groupKey=z.key..':story:'..tostring(story.key or story.title)
                        local regional={kind='zone-story',key=groupKey,parentKey=z.key,
                            mapID=z.mapID,zoneTitle=z.title,title=story.title,ids=story.ids,
                            groupKind=story.kind,completed=story.completed,active=story.active,
                            totalCount=story.totalCount,questEntries=z.quests,
                            opened=zoneGroupsExpanded[groupKey]==true}
                        rows[#rows+1]=regional
                        if regional.opened then
                            for i,id in ipairs(story.ids) do
                                local q=z.quests[id]
                                if q then
                                    rows[#rows+1]={kind='zone-chapter',
                                        key=groupKey..':quest:'..tostring(id),parentKey=groupKey,
                                        mapID=z.mapID,zoneTitle=z.title,title=q.title,questID=id,
                                        chapterIndex=i,completed=q.completed,active=q.active,
                                        source=q.source}
                                end
                            end
                        end
                    end
                end
            end
        end
        self.storyView:SetShown(tab=='stories')
        self.timelineView:SetShown(tab=='timeline')
        self.timelineView.label:SetText(timelineMode=='sessions' and 'Timeline: Sessions' or 'Timeline: Days')
        local filterNames={all='All',chains='Storylines',singles='Standalone',variants='Variants'}
        -- UI:Button draws its caption using button.label, not Button:SetText.
        -- Calling SetText on the Button itself changes no visible text.
        self.storyView.label:SetText('Stories: '..filterNames[storyFilter])
        for key,b in pairs(self.tabs) do
            if UI.SetButtonSelected then UI:SetButtonSelected(b,key==tab) end
        end
        local options=AF:GetQuestRecapScopes()
        local label='This character'
        for _,s in ipairs(options) do if s.key==scope then label=s.label;break end end
        self.scopeButton.label:SetText('Character: '..label)
        local countText=tab=='timeline' and
            (timelineMode=='sessions' and
                string.format('%d dated events  |  %d inferred sessions  |  %d days',totalEvents or 0,sessionCount or 0,dayCount or 0)
                or string.format('%d dated events across %d days',totalEvents or 0,dayCount or 0))
            or (tab=='stories' and (function() local n=0 for _ in pairs(storyByKey) do n=n+1 end return n..' story groups' end)() or (function() local n=0 for _,r in ipairs(rows) do if r.kind=='zone' then n=n+1 end end return n..' known zones' end)())
        -- Reflect all active filters in the status row as well as the buttons.
        local filterStatus=tab=='stories' and ('  |  '..filterNames[storyFilter]) or ''
        self.status:SetText(label..filterStatus..'  |  '..countText)
        local rowHeight=tab=='timeline' and 44 or 36
        local viewport=(self.listScroll.GetHeight and self.listScroll:GetHeight()) or 405
        if viewport<100 then viewport=405 end
        self.listContent:SetHeight(math.max(viewport,#rows*rowHeight))
        local function Visible()
            local first=math.floor((self.listScroll:GetVerticalScroll() or 0)/rowHeight)
            for i,b in ipairs(self.buttons) do
                local index=first+i
                local r=rows[index]
                if r then
                    b.rowKey=r.key
                    b:SetHeight(rowHeight-3)
                    b:ClearAllPoints();b:SetPoint('TOPLEFT',self.listContent,'TOPLEFT',0,-(index-1)*rowHeight)
                    local label=r.title
                    if tab=='stories' then
                        if r.kind=='chapter' then
                            local id=r.questID
                            local state=currentStories and currentStories[id]
                            local level=QuestRecord(id)
                            local lvl=level and level.level and level.level>0 and ('['..level.level..'] ') or ''
                            local status=state and state.completed and '|cff88dd99Done|r' or
                                (state and state.active and '|cff85baffActive|r' or '|cffbbbbbbSeen|r')
                            label=(selectedKey==r.parentKey and chapter==r.chapterIndex and '|cffffd16b> |r' or '  ')
                                ..'  '..r.chapterIndex..'. '..lvl..r.title..'  '..status
                        else
                            local arrow=#r.ids>1 and (r.opened and 'v  ' or '>  ') or '   '
                            local marker=r.groupKind=='chain' and '|cffffd16b[Story]|r ' or
                                (r.groupKind=='variants' and '|cffbda17b[Variants]|r ' or '')
                            label=arrow..marker..label..' |cffbda17b('..r.completed..'/'..r.total..' done)|r'
                        end
                    elseif tab=='timeline' then
                        if r.kind=='day' then
                            label=(r.opened and 'v  ' or '>  ')..r.title..
                                ' |cffbda17b('..r.dayEvents..' events'..
                                (timelineMode=='sessions' and ', '..(r.sessionCount or 0)..' sessions' or '')..')|r'
                        elseif r.kind=='session' then
                            label='  '..(r.opened and 'v  ' or '>  ')..'|cffffd16b'..Name(r.owner)..'|r'..
                                ' |cffbda17b('..(r.eventCount or 0)..' events)|r\n'..
                                '  '..Stamp(r.startAt)..' - '..Stamp(r.lastAt)
                        else
                            local labelKind=(r.kind=='visit' or r.kind=='visit-group') and '|cffd8b17aZone|r' or
                                (r.questEvent=='turned-in' and '|cff77d99aTurned in|r' or
                                (r.questEvent=='accepted' and '|cff69bfffAccepted|r' or '|cffc3c3c3Seen|r'))
                            local repeatCount=r.kind=='visit-group' and r.count>1 and (' ('..r.count..' visits)') or ''
                            label='  '..labelKind..' |cffbda17b'..Stamp(r.at)..'|r\n'..label..repeatCount
                        end
                    else
                        if r.kind=='zone-story' then
                            local arrow=r.opened and 'v  ' or '>  '
                            local typeLabel=r.groupKind=='chain' and '[Story] ' or
                                (r.groupKind=='variants' and '[Variants] ' or '')
                            label='  '..arrow..typeLabel..label..' |cffbda17b('..r.completed..'/'..#r.ids..' done)|r'
                        elseif r.kind=='zone-chapter' then
                            local state=r.completed and '|cff88dd99Done|r' or
                                (r.active and '|cff85baffActive|r' or '|cffbfa887Recorded|r')
                            label='      '..r.chapterIndex..'. '..label..' '..state
                        else
                            label=(r.opened and 'v  ' or '>  ')..label..' |cffbda17b('..
                                (r.visits or 0)..' visits, '..(r.questCount or 0)..' quests)|r'
                        end
                    end
                    b.label:SetHeight(rowHeight-5)
                    b.label:SetText(label);b:Show()
                else b:Hide();b.rowKey=nil end
            end
        end
        self.UpdateVisibleRows=Visible
        self.listScroll:SetScript('OnVerticalScroll',function(s,value)
            s:SetVerticalScroll(math.max(0,math.min(math.max(0,#rows*rowHeight-viewport),value)))
            Visible()
        end)
        local offset=self.listScroll:GetVerticalScroll() or 0
        self.listScroll:SetVerticalScroll(math.max(0,math.min(offset,math.max(0,#rows*rowHeight-viewport))))
        Visible()
        local found=false
        if tab=='stories' then found=storyByKey[selectedKey]~=nil
        else for _,r in ipairs(rows) do if r.key==selectedKey then found=true;break end end end
        if not found then
            selectedKey=rows[1] and (rows[1].parentKey or rows[1].key) or nil
            chapter=1;readMode='chapter'
        end
        self:RefreshDetail()
    end
    function panel:ScrollToSelectedChapter()
        if tab~='stories' then return end
        for i,row in ipairs(rows) do
            if row.kind=='chapter' and row.parentKey==selectedKey and row.chapterIndex==chapter then
                local viewport=(self.listScroll.GetHeight and self.listScroll:GetHeight()) or 405
                local maximum=math.max(0,#rows*36-viewport)
                local scroll=math.min(maximum,math.max(0,(i-4)*36))
                self.listScroll:SetVerticalScroll(scroll)
                return
            end
        end
    end
    function panel:RefreshListHighlights()
        -- A chapter arrow changes only the displayed chapter and its row
        -- highlight. Avoid a full Recap data rebuild (which may re-query
        -- quest maps and libraries) on each Previous/Next click.
        self:RefreshDetail()
        self:ScrollToSelectedChapter()
        if self.UpdateVisibleRows then self:UpdateVisibleRows() end
    end
    panel:Hide()
end
function UI:OpenQuestRecapAtlasZone(mapID)
    if not (mapID and AF.GetAtlasMapInfo and AF:GetAtlasMapInfo(mapID)) then
        if AF.Print then AF.Print('This zone has no available Atlas map.') end
        return
    end
    self:Open('Exploration')
    local atlas=self.pageViews and self.pageViews.Exploration
    if atlas and atlas.Navigate then atlas:Navigate(mapID)
    elseif AF.Print then AF.Print('Atlas map is not ready.') end
end
-- Open a specific recorded chapter from the Quest Journal. Searching by
-- quest ID avoids conflating Forever same-title variants and chain steps.
function UI:OpenQuestRecapAtQuest(questID,preferredScope)
    questID=tonumber(questID)
    if not questID or questID<=0 then return end
    Setup()
    local function Locate(where)
        local stories=AF:GetQuestRecapStories(where,'')
        for _,story in ipairs(stories or {}) do
            for i,id in ipairs(story.ids or {}) do
                if id==questID then return story.key,i end
            end
        end
    end
    -- Regional links preserve the chosen account/character perspective.
    -- Existing Journal links omit preferredScope and retain current-first behavior.
    local initial=preferredScope or 'current'
    local key,index=Locate(initial)
    scope=initial
    if not key and initial~='current' then
        scope='current';key,index=Locate('current')
    end
    if not key then scope='all';key,index=Locate('all') end
    tab='stories';storyFilter='all';readMode='chapter'
    query=''
    if panel.search then panel.search:SetText('') end
    selectedKey=key;chapter=index or 1
    if key then storyExpanded[key]=true end
    panel.listScroll:SetVerticalScroll(0)
    panel.detailScroll:SetVerticalScroll(0)
    panel:Refresh()
    if panel.ScrollToSelectedChapter then panel:ScrollToSelectedChapter() end
    panel:Show();panel:SetFrameStrata('TOOLTIP');panel:SetFrameLevel(330)
    if panel.Raise then panel:Raise() end
    if not key and AF.Print then AF.Print('No recorded story chapter for Quest #'..questID..'.') end
end
function UI:ToggleQuestRecap()
    Setup()
    if panel:IsShown() then panel:Hide();return end
    if AF.ScanQuestRecords then AF:ScanQuestRecords() end
    if AF.BackfillCompletedQuestRecords then AF:BackfillCompletedQuestRecords() end
    panel:Refresh()
    panel:Show();panel:SetFrameStrata('TOOLTIP');panel:SetFrameLevel(270)
    if panel.Raise then panel:Raise() end
end
function UI:RefreshQuestRecap()
    if panel and panel:IsShown() then panel:Refresh() end
end
