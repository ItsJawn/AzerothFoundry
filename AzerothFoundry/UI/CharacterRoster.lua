-- Azeroth Foundry 0.5.11 / Characters: Expedition ledger + alt roster.
-- Replaces the original fixed three-column page; NO expedition engine changes.
-- The selected character is separate from the logged-in current character.
local _, AF = ...
local UI = AF.UI
local P = UI.palette
local unpack = unpack or table.unpack
local floor, max, min = math.floor, math.max, math.min

local function formatMoney(copper)
    if type(copper)~="number" then return "Not recorded" end
    local g=floor(copper/10000)
    local s=floor((copper%10000)/100)
    local c=copper%100
    return string.format("%dg %02ds %02dc",g,s,c)
end
local function formatPlayed(sec)
    if type(sec)~="number" then return "Not recorded" end
    local days=floor(sec/86400)
    local hours=floor((sec%86400)/3600)
    local minutes=floor((sec%3600)/60)
    if days>0 then return string.format("%dd %dh",days,hours) end
    if hours>0 then return string.format("%dh %dm",hours,minutes) end
    return string.format("%dm",minutes)
end
local function when(timestamp)
    if type(timestamp)~="number" or timestamp<=0 then return "Not scanned" end
    if type(date)=="function" then return date("%b %d %Y, %H:%M",timestamp) end
    return "Recorded"
end
local function icon(texture,c)
    if c and c.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[c.class] then
        texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        texture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[c.class]))
    else
        texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        texture:SetTexCoord(0,1,0,1)
    end
end
local function coloredName(c)
    local clr=c and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
    if clr then return string.format("|cff%02x%02x%02x%s|r",floor(clr.r*255),floor(clr.g*255),floor(clr.b*255),c.name or "Unknown") end
    return c and c.name or "Unknown"
end
local function line(parent, x,y, width, height, size, color)
    local t=UI:Text(parent,size or "small",color or P.ink)
    t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    t:SetSize(width,height)
    return t
end
local function title(parent, text)
    local t=UI:SectionTitle(parent,text)
    t:SetPoint("TOPLEFT",parent,"TOPLEFT",15,-12)
    t:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-14,-12)
    return t
end
local function statBlock(parent, heading, index)
    local frame=CreateFrame("Frame",nil,parent)
    UI:Background(frame,P.leather,true)
    if UI.FoundryQuestBorder then UI:FoundryQuestBorder(frame,{cap=16,alpha=.46,outset=0}) end
    local topGlow=frame:CreateTexture(nil,"ARTWORK",nil,-1)
    topGlow:SetPoint("TOPLEFT",frame,"TOPLEFT",7,-7)
    topGlow:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-7,-7)
    topGlow:SetHeight(20)
    topGlow:SetColorTexture(.95,.84,.63,.08)
    local rule=frame:CreateTexture(nil,"BORDER")
    rule:SetPoint("TOPLEFT",frame,"TOPLEFT",10,-27)
    rule:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-10,-27)
    rule:SetHeight(1)
    rule:SetColorTexture(.88,.70,.34,.32)
    local head=UI:Text(frame,"small",P.pale)
    head:SetPoint("TOPLEFT",frame,"TOPLEFT",10,-8)
    head:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-26,-8)
    head:SetHeight(18)
    head:SetText(heading)
    -- Three non-overlapping rows within the 85px badge: heading 8-26,
    -- number 33-53, detail 59-78. Anchoring the last row to the top
    -- prevents it drifting into the number when WoW resolves font metrics.
    local value=UI:Text(frame,nil,P.gold)
    value:SetPoint("TOPLEFT",frame,"TOPLEFT",10,-33)
    value:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-10,-33)
    value:SetHeight(20)
    value:SetWordWrap(false)
    local sub=UI:Text(frame,"small",P.pale)
    sub:SetPoint("TOPLEFT",frame,"TOPLEFT",10,-59)
    sub:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-10,-59)
    sub:SetHeight(19)
    sub:SetJustifyV("MIDDLE")
    sub:SetWordWrap(false)
    if UI.RegisterThemeTarget then
        UI:RegisterThemeTarget(frame,function(_,t)
            local cols={t.accent,t.accent2,t.accent3,t.accent4,t.divider}
            local c=t.rainbow and cols[((index or 1)-1)%#cols+1] or t.divider
            rule:SetColorTexture(c[1],c[2],c[3],.67)
            topGlow:SetColorTexture(t.accent[1],t.accent[2],t.accent[3],t.rainbow and .12 or .06)
        end)
    end
    return frame,value,sub,head
end

function UI:BuildCharacters(page)
    local settings=AF.db.settings
    -- The old fixed character portrait + three totals is now a set of five
    -- player-selected account trackers. These are compact status cards, not
    -- draggable Overview widgets; the rest of the Characters page is fixed.
    local upper=UI:Card(page)
    upper:SetPoint("TOPLEFT",page,"TOPLEFT",10,-10)
    upper:SetPoint("TOPRIGHT",page,"TOPRIGHT",-10,-10)
    upper:SetHeight(134)
    title(upper,"Account Trackers")
    local trackerCount=UI:Button(upper,"Show 4",function()
        settings.charactersTrackerCount=(settings.charactersTrackerCount==4) and 5 or 4
        page:Refresh()
    end,"row")
    trackerCount:SetSize(76,23)
    trackerCount:SetPoint("TOPRIGHT",upper,"TOPRIGHT",-16,-9)
    local metrics={}
    local picker=UI:Card(page)
    picker:SetSize(288,340)
    picker:SetFrameLevel(page:GetFrameLevel()+32)
    picker:SetPoint("TOPRIGHT",upper,"BOTTOMRIGHT",-12,2)
    local pickerHeading=UI:Text(picker,"small",P.ink)
    pickerHeading:SetPoint("TOPLEFT",picker,"TOPLEFT",15,-13)
    pickerHeading:SetPoint("TOPRIGHT",picker,"TOPRIGHT",-38,-13)
    pickerHeading:SetHeight(22)
    local dismiss=UI:Button(picker,"x",function() picker:Hide() end,"row")
    dismiss:SetSize(26,24)
    dismiss:SetPoint("TOPRIGHT",picker,"TOPRIGHT",-11,-9)
    local pickerScroll=CreateFrame("ScrollFrame",nil,picker,"UIPanelScrollFrameTemplate")
    pickerScroll:SetPoint("TOPLEFT",picker,"TOPLEFT",13,-43)
    pickerScroll:SetPoint("BOTTOMRIGHT",picker,"BOTTOMRIGHT",-34,14)
    local choices=UI:GetAccountTrackerChoices()
    local pickChild=CreateFrame("Frame",nil,pickerScroll)
    pickChild:SetSize(225,#choices*31+8)
    pickerScroll:SetScrollChild(pickChild)
    local selectedSlot=1
    local pickerOptions={}
    for i,choice in ipairs(choices) do
        local option=UI:Button(pickChild,choice.label,function()
            UI:SelectAccountTracker(selectedSlot,choice.id)
            picker:Hide()
            page:Refresh()
        end,"row")
        option:SetPoint("TOPLEFT",pickChild,"TOPLEFT",2,-(i-1)*31-2)
        option:SetPoint("TOPRIGHT",pickChild,"TOPRIGHT",-2,-(i-1)*31-2)
        option:SetHeight(29)
        pickerOptions[i]=option
        option.label:SetWordWrap(false)
        option:SetScript("OnEnter",function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetText(choice.label,1,.82,.45)
                GameTooltip:AddLine(choice.description,.92,.86,.7,true)
                GameTooltip:Show()
            end
        end)
        option:SetScript("OnLeave",function()
            if GameTooltip then GameTooltip:Hide() end
        end)
    end
    picker:Hide()
    page:SetScript("OnHide",function() picker:Hide() end)
    -- No global region picker: each card's understated three-dot control edits
    -- only its own slot; metric choices are persisted per account.
    local function openPicker(slot)
        if picker:IsShown() and selectedSlot==slot then picker:Hide();return end
        selectedSlot=slot
        local chosen=settings.charactersTrackers and settings.charactersTrackers[slot]
        local label="Tracker "..slot
        for _,entry in ipairs(choices) do
            if entry.id==chosen then label=entry.label;break end
        end
        pickerHeading:SetText("Replace: "..label)
        for i,entry in ipairs(choices) do UI:SetButtonSelected(pickerOptions[i],entry.id==chosen) end
        pickerScroll:SetVerticalScroll(0)
        picker:Show()
    end
    for i=1,5 do
        local holder,value,sub,heading=statBlock(upper,"",i)
        local selection=CreateFrame("Button",nil,holder)
        selection:SetSize(24,22)
        selection:SetPoint("TOPRIGHT",holder,"TOPRIGHT",-3,-2)
        local buttonLabel=UI:Text(selection,"small",P.pale,"CENTER")
        buttonLabel:SetAllPoints(selection)
        buttonLabel:SetText("...")
        local hover=selection:CreateTexture(nil,"HIGHLIGHT")
        hover:SetAllPoints(selection)
        hover:SetColorTexture(1,.74,.32,.20)
        selection:SetScript("OnClick",function()openPicker(i)end)
        selection:SetScript("OnEnter",function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self,"ANCHOR_TOP")
                GameTooltip:SetText("Choose account tracker")
                GameTooltip:Show()
            end
        end)
        selection:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        -- Give the top-right edit affordance its own space without obscuring
        -- the metric heading, even on the minimum supported journal width.
        value:SetWordWrap(false)
        heading:SetPoint("TOPRIGHT",holder,"TOPRIGHT",-28,-8)
        heading:SetWordWrap(false)
        metrics[i]={frame=holder,value=value,sub=sub,selection=selection,heading=heading}
    end
    local function metricsLayout()
        local _,count=UI:EnsureAccountTrackerSettings()
        local width=upper:GetWidth() or 960
        local gap=8
        local inner=math.max(700,width-34)
        local cell=(inner-gap*(count-1))/count
        for i,row in ipairs(metrics) do
            row.frame:ClearAllPoints()
            if i<=count then
                row.frame:SetPoint("TOPLEFT",upper,"TOPLEFT",17+(i-1)*(cell+gap),-38)
                row.frame:SetSize(cell,85)
                row.frame:Show()
            else
                row.frame:Hide()
            end
        end
    end
    upper:SetScript("OnSizeChanged",metricsLayout)

    local rosterPanel=UI:Card(page)
    rosterPanel:SetPoint("TOPLEFT",upper,"BOTTOMLEFT",0,-9)
    rosterPanel:SetPoint("BOTTOMLEFT",page,"BOTTOMLEFT",10,10)
    rosterPanel:SetWidth(max(216,min(400,tonumber(settings.charactersRosterWidth) or 286)))
    local rosterTitle=title(rosterPanel,"Expedition & Alts")
    local rosterHint=UI:Text(rosterPanel,"small",P.ink)
    rosterHint:SetPoint("TOPLEFT",rosterPanel,"TOPLEFT",16,-43)
    rosterHint:SetPoint("TOPRIGHT",rosterPanel,"TOPRIGHT",-13,-43)
    rosterHint:SetHeight(21)
    -- Compact roster controls; sorting doesn't alter underlying character records.
    local options={{"Name","name"},{"Level","level"},{"Gold","gold"},{"Played","played"}}
    local sorts={}
    for i,item in ipairs(options) do
        local btn=UI:Button(rosterPanel,item[1],function()
            settings.charactersSort=item[2]
            page:Refresh()
        end,"row")
        btn:SetHeight(24)
        btn:SetPoint("TOPLEFT",rosterPanel,"TOPLEFT",12+(i-1)*65,-68)
        btn:SetWidth(63)
        sorts[i]=btn
    end
    local scroll=UI:List(rosterPanel,52)
    scroll:SetPoint("TOPLEFT",rosterPanel,"TOPLEFT",13,-105)
    scroll:SetPoint("BOTTOMRIGHT",rosterPanel,"BOTTOMRIGHT",-23,43)
    local rosterFoot=UI:Text(rosterPanel,"small",P.ink)
    rosterFoot:SetPoint("BOTTOMLEFT",rosterPanel,"BOTTOMLEFT",16,11)
    rosterFoot:SetPoint("BOTTOMRIGHT",rosterPanel,"BOTTOMRIGHT",-15,11)
    rosterFoot:SetHeight(25)
    rosterFoot:SetText("Click an adventurer for details. Drag the divider to resize.")
    local rosterRows={}
    local rosterHeaders={}
    local function rosterRefresh()
        local source=AF:GetCharacters()
        local inside,outside={},{}
        for _,c in ipairs(source) do
            if AF:IsExpeditionMember(c.key) then inside[#inside+1]=c else outside[#outside+1]=c end
        end
        local sorter=settings.charactersSort or "level"
        local function val(c)
            if sorter=="gold" then return c.afMoneyCopper or -1 end
            if sorter=="played" then return c.afPlayedSeconds or -1 end
            if sorter=="level" then return c.level or 0 end
            return (c.name or ""):lower()
        end
        local function compare(a,b)
            if val(a)~=val(b) then
                if sorter=="name" then return val(a)<val(b) end
                return val(a)>val(b)
            end
            return (a.name or "")<(b.name or "")
        end
        table.sort(inside,compare);table.sort(outside,compare)
        local all=source
        table.sort(all,compare)
        local groups=AF:IsModuleEnabled("selfFound")
            and {{name="EXPEDITION",members=inside},{name="INDEPENDENT",members=outside}}
            or {{name="ADVENTURERS",members=all}}
        for i,btn in ipairs(sorts) do UI:SetButtonSelected(btn,sorter==options[i][2]) end
        local child=scroll.child
        local width=max(175,(child:GetWidth() or rosterPanel:GetWidth()-36))
        local y=0
        local rowIdx,headIdx=0,0
        for _,grp in ipairs(groups) do
            headIdx=headIdx+1
            local head=rosterHeaders[headIdx]
            if not head then
                head=UI:Text(child,"small",P.ink)
                rosterHeaders[headIdx]=head
            end
            head:ClearAllPoints();head:SetPoint("TOPLEFT",child,"TOPLEFT",7,-y)
            head:SetSize(width-10,24)
            head:SetText(grp.name.."  ("..#grp.members..")")
            head:Show()
            y=y+29
            for _,c in ipairs(grp.members) do
                rowIdx=rowIdx+1
                local row=rosterRows[rowIdx]
                if not row then
                    local btn=UI:Button(child,"",nil,"row")
                    btn:SetHeight(48)
                    btn.label:Hide()
                    local tex=btn:CreateTexture(nil,"ARTWORK")
                    tex:SetSize(30,30)
                    tex:SetPoint("LEFT",btn,"LEFT",7,0)
                    local name=UI:Text(btn,"small",P.ink)
                    name:SetPoint("TOPLEFT",btn,"TOPLEFT",45,-4)
                    name:SetPoint("TOPRIGHT",btn,"TOPRIGHT",-5,-4)
                    name:SetHeight(19)
                    local meta=UI:Text(btn,"small",P.ink)
                    meta:SetPoint("BOTTOMLEFT",btn,"BOTTOMLEFT",45,5)
                    meta:SetPoint("BOTTOMRIGHT",btn,"BOTTOMRIGHT",-5,5)
                    meta:SetHeight(18)
                    row={button=btn,icon=tex,name=name,meta=meta}
                    rosterRows[rowIdx]=row
                end
                row.button:ClearAllPoints()
                row.button:SetPoint("TOPLEFT",child,"TOPLEFT",4,-y)
                row.button:SetWidth(width-8)
                row.button:Show()
                icon(row.icon,c)
                row.name:SetText((AF:IsModuleEnabled("selfFound") and c.key==AF.db.mainKey and "|cffffc55d* |r" or "")..coloredName(c))
                local descriptor="Lv "..tostring(c.level or "?").."  "..(c.class or "")
                if sorter=="gold" then descriptor=descriptor.."  |  "..(c.afMoneyCopper and formatMoney(c.afMoneyCopper) or "Gold ?") end
                if sorter=="played" then descriptor=descriptor.."  |  "..(c.afPlayedSeconds and formatPlayed(c.afPlayedSeconds) or "Time ?") end
                if c.key==AF:GetCurrentKey() then descriptor=descriptor.."  (Here)" end
                row.meta:SetText(descriptor)
                UI:SetButtonSelected(row.button,c.key==UI.selectedCharacterKey)
                row.button:SetScript("OnClick",function()
                    UI.selectedCharacterKey=c.key
                    page:Refresh()
                end)
                y=y+51
            end
            y=y+8
        end
        for i=rowIdx+1,#rosterRows do rosterRows[i].button:Hide() end
        for i=headIdx+1,#rosterHeaders do rosterHeaders[i]:Hide() end
        child:SetHeight(max(1,y+4))
        scroll.afContentHeight=max(1,y+4)
        UI:UpdateListScroll(scroll)
    end

    local details=UI:Card(page)
    details:SetPoint("TOPLEFT",rosterPanel,"TOPRIGHT",11,0)
    details:SetPoint("BOTTOMRIGHT",page,"BOTTOMRIGHT",-10,10)
    local grip=CreateFrame("Button",nil,page)
    grip:SetWidth(12)
    grip:SetPoint("TOPLEFT",rosterPanel,"TOPRIGHT",0,0)
    grip:SetPoint("BOTTOMLEFT",rosterPanel,"BOTTOMRIGHT",0,0)
    grip:SetFrameLevel(rosterPanel:GetFrameLevel()+6)
    UI:StyleResizeGrip(grip)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart",function(self)
        self.afDragging=true
        self:SetScript("OnUpdate",function()
            local x=GetCursorPosition()
            local scale=page:GetEffectiveScale() or 1
            local left=page:GetLeft()
            if not x or not left then return end
            local width=page:GetWidth() or 900
            local proposed=max(216,min(min(400,width-390),x/scale-left-10))
            rosterPanel:SetWidth(proposed)
        end)
    end)
    grip:SetScript("OnDragStop",function(self)
        self.afDragging=false
        self:SetScript("OnUpdate",nil)
        settings.charactersRosterWidth=rosterPanel:GetWidth()
        page:Refresh()
    end)
    grip:SetScript("OnHide",function(self)self:SetScript("OnUpdate",nil)end)
    local function layoutRosterControls()
        local w=rosterPanel:GetWidth() or 286
        local btnW=max(43,(w-30)/4)
        for i,btn in ipairs(sorts) do
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT",rosterPanel,"TOPLEFT",12+(i-1)*btnW,-68)
            btn:SetWidth(btnW-2)
        end
    end
    rosterPanel:SetScript("OnSizeChanged",layoutRosterControls)
    page:SetScript("OnSizeChanged",function(_,w)
        if w then rosterPanel:SetWidth(min(400,max(216,min(w-390,tonumber(settings.charactersRosterWidth) or 286)))) end
    end)

    title(details,"Adventurer Dossier")
    -- This is a fixed-purpose dossier, not an Overview widget. Its only
    -- customization is the saved proportional split between identity and
    -- character-owned pursuits. Both halves follow the parent size.
    local dossierTop=CreateFrame("Frame",nil,details)
    dossierTop:SetPoint("TOPLEFT",details,"TOPLEFT",15,-44)
    dossierTop:SetPoint("TOPRIGHT",details,"TOPRIGHT",-15,-44)
    dossierTop:SetHeight(199)

    local hero=UI:NewFrame("Frame",dossierTop)
    hero:SetPoint("TOPLEFT",dossierTop,"TOPLEFT",0,0)
    hero:SetPoint("BOTTOMLEFT",dossierTop,"BOTTOMLEFT",0,0)
    hero:SetWidth(340) -- recalculated by layoutDossier() below
    UI:Background(hero,P.leather,true)

    local pursuits=UI:NewFrame("Frame",dossierTop)
    pursuits:SetPoint("TOPLEFT",hero,"TOPRIGHT",12,0)
    pursuits:SetPoint("BOTTOMRIGHT",dossierTop,"BOTTOMRIGHT",0,0)
    UI:Background(pursuits,P.leather,true)
    local pursuitsHeading=UI:Text(pursuits,"small",P.gold)
    pursuitsHeading:SetPoint("TOPLEFT",pursuits,"TOPLEFT",12,-9)
    pursuitsHeading:SetPoint("TOPRIGHT",pursuits,"TOPRIGHT",-10,-9)
    pursuitsHeading:SetHeight(21)
    pursuitsHeading:SetText("CURRENT PURSUITS")
    local pursuitsRule=pursuits:CreateTexture(nil,"BORDER")
    pursuitsRule:SetColorTexture(.83,.63,.30,.43)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(pursuitsRule,function(tex,t)
        tex:SetColorTexture(t.divider[1],t.divider[2],t.divider[3],.56)
    end) end
    pursuitsRule:SetPoint("TOPLEFT",pursuits,"TOPLEFT",11,-33)
    pursuitsRule:SetPoint("TOPRIGHT",pursuits,"TOPRIGHT",-11,-33)
    pursuitsRule:SetHeight(1)

    local pursuitRows={}
    local function pursuitRow(index,label,onClick)
        local row=CreateFrame("Button",nil,pursuits)
        row:SetPoint("TOPLEFT",pursuits,"TOPLEFT",10,-(38+(index-1)*50))
        row:SetPoint("TOPRIGHT",pursuits,"TOPRIGHT",-10,-(38+(index-1)*50))
        row:SetHeight(47)
        row:RegisterForClicks("LeftButtonUp")
        local bg=row:CreateTexture(nil,"BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetColorTexture(.07,.043,.026,.23)
        local highlight=row:CreateTexture(nil,"HIGHLIGHT")
        highlight:SetAllPoints(row)
        highlight:SetColorTexture(.93,.72,.35,.16)
        local name=UI:Text(row,"small",P.pale)
        name:SetPoint("TOPLEFT",row,"TOPLEFT",7,-4)
        name:SetPoint("TOPRIGHT",row,"TOPRIGHT",-43,-4)
        name:SetHeight(18)
        name:SetWordWrap(false)
        name:SetText(label)
        local count=UI:Text(row,"small",P.gold,"RIGHT")
        count:SetPoint("TOPRIGHT",row,"TOPRIGHT",-7,-4)
        count:SetSize(34,18)
        local preview=UI:Text(row,"small",P.pale)
        preview:SetPoint("TOPLEFT",row,"TOPLEFT",7,-25)
        preview:SetPoint("TOPRIGHT",row,"TOPRIGHT",-7,-25)
        preview:SetHeight(16)
        preview:SetWordWrap(false)
        row:SetScript("OnClick",onClick)
        row:SetScript("OnEnter",function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetText(label,1,.84,.51)
                GameTooltip:AddLine("View the selected character's recorded "..label:lower().." in Foundry.",.92,.85,.73,true)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide() end end)
        pursuitRows[index]={count=count,preview=preview,row=row}
    end
    local firstGoal,firstCraft,firstNote
    pursuitRow(1,"Goals",function()
        if firstGoal then UI.selectedProjectId=firstGoal.id end
        if AF.db.settings.guided then AF.db.settings.guided.goalsView="Active" end
        UI:Switch("Goals")
    end)
    pursuitRow(2,"Crafting",function()
        if firstCraft then UI.selectedProjectId=firstCraft.id end
        UI:Switch("Crafting") -- established compatibility route -> Workshop / Crafting Queue
    end)
    pursuitRow(3,"Notes",function()
        if firstNote then UI.selectedNoteId=firstNote.id end
        UI:Switch("Notes")
    end)

    local portraitBox=UI:NewFrame("Frame",hero)
    portraitBox:SetPoint("TOPLEFT",hero,"TOPLEFT",10,-10)
    portraitBox:SetSize(79,79)
    UI:Background(portraitBox,P.dark,true)
    local portrait=portraitBox:CreateTexture(nil,"ARTWORK")
    portrait:SetPoint("TOPLEFT",portraitBox,"TOPLEFT",8,-8)
    portrait:SetPoint("BOTTOMRIGHT",portraitBox,"BOTTOMRIGHT",-8,8)
    local classBadge=portraitBox:CreateTexture(nil,"OVERLAY")
    classBadge:SetSize(24,24)
    classBadge:SetPoint("BOTTOMRIGHT",portraitBox,"BOTTOMRIGHT",0,0)

    local function shortRow(y,side,height,color,font)
        local t=UI:Text(hero,font or "small",color or P.pale)
        local x=side and 99 or 12
        t:SetPoint("TOPLEFT",hero,"TOPLEFT",x,-y)
        t:SetPoint("TOPRIGHT",hero,"TOPRIGHT",-10,-y)
        t:SetHeight(height or 18)
        t:SetWordWrap(false)
        t:SetJustifyV("MIDDLE")
        return t
    end
    local selectedName=shortRow(9,true,25,P.gold,"title")
    local selectedInfo=shortRow(38,true,19)
    local selectedStatus=shortRow(62,true,19)
    local divider=hero:CreateTexture(nil,"BORDER")
    divider:SetPoint("TOPLEFT",hero,"TOPLEFT",11,-96)
    divider:SetPoint("TOPRIGHT",hero,"TOPRIGHT",-11,-96)
    divider:SetHeight(1)
    divider:SetColorTexture(.86,.63,.30,.40)
    local selectedGold=shortRow(102,false,18)
    local selectedPlayed=shortRow(125,false,18)
    local seen=shortRow(150,false,17)
    local joined=shortRow(173,false,17)
    local charterHint=CreateFrame('Frame',nil,hero)
    charterHint:SetPoint('TOPLEFT',selectedStatus,'TOPLEFT',0,0)
    charterHint:SetPoint('BOTTOMRIGHT',selectedStatus,'BOTTOMRIGHT',0,0)
    charterHint:EnableMouse(true)
    charterHint:SetScript('OnEnter',function(self)
        if not GameTooltip then return end
        local key=UI.selectedCharacterKey
        local name,detail=AF:GetExpeditionParticipation(key)
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
        GameTooltip:SetText(name,1,.83,.50)
        GameTooltip:AddLine(detail,.90,.83,.71,true)
        if key and AF:IsExpeditionMember(key) then
            GameTooltip:AddLine(AF:GetExpeditionPlanningPolicy('expedition',key).note,.77,.90,.74,true)
        end
        GameTooltip:Show()
    end)
    charterHint:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end)


    -- Drag only a small three-dot grip, never the portrait, notes, or buttons.
    -- Store a ratio rather than pixels so the split survives overall resizing.
    local splitGrip=CreateFrame("Button",nil,dossierTop)
    splitGrip:SetWidth(12)
    splitGrip:SetPoint("TOPLEFT",hero,"TOPRIGHT",0,0)
    splitGrip:SetPoint("BOTTOMLEFT",hero,"BOTTOMRIGHT",0,0)
    splitGrip:SetFrameLevel(dossierTop:GetFrameLevel()+9)
    UI:StyleResizeGrip(splitGrip)
    splitGrip:EnableMouse(true)
    splitGrip:RegisterForDrag("LeftButton")
    splitGrip:SetScript("OnEnter",function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self,"ANCHOR_CURSOR")
            GameTooltip:SetText("Resize Dossier / Pursuits",1,.83,.49)
            GameTooltip:AddLine("Drag the divider to give either panel more room.",.88,.80,.67,true)
            GameTooltip:Show()
        end
    end)
    splitGrip:SetScript("OnLeave",function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    local dragRatio
    local function layoutDossier()
        local w=dossierTop:GetWidth() or 0
        if w < 120 then return end -- parent frame may not be laid out yet
        -- 12px belongs to the separator, not either content panel.
        local usable=max(1,w-12)
        local minLeft=min(290,usable*.58)
        local minRight=min(198,usable*.40)
        local largest=max(minLeft,usable-minRight)
        local ratio=dragRatio or tonumber(settings.charactersDossierRatio) or .56
        ratio=max(.15,min(.85,ratio))
        local left=max(minLeft,min(largest,usable*ratio))
        hero:SetWidth(left)
    end
    dossierTop:SetScript("OnSizeChanged",layoutDossier)
    splitGrip:SetScript("OnDragStart",function(self)
        if not GetCursorPosition then return end
        self.afDragging=true
        self:SetScript("OnUpdate",function()
            if not self.afDragging then return end
            local cursor=GetCursorPosition()
            local scale=dossierTop:GetEffectiveScale() or 1
            local left=dossierTop:GetLeft()
            local width=dossierTop:GetWidth()
            if cursor and left and width and width>12 and scale>0 then
                dragRatio=(cursor/scale-left)/(width-12)
                layoutDossier()
            end
        end)
    end)
    splitGrip:SetScript("OnDragStop",function(self)
        self.afDragging=false
        self:SetScript("OnUpdate",nil)
        if dragRatio then
            settings.charactersDossierRatio=max(.15,min(.85,hero:GetWidth()/max(1,(dossierTop:GetWidth() or 500)-12)))
            dragRatio=nil
            layoutDossier()
        end
    end)
    splitGrip:SetScript("OnHide",function(self)
        self.afDragging=false;self:SetScript("OnUpdate",nil);dragRatio=nil
    end)
    layoutDossier()

    -- Expedition actions use a compact native-bronze treatment instead of
    -- three unrelated bright red panel buttons. Only presentation changes:
    -- the original enrollment, main and role callbacks are preserved.
    local actionBar=CreateFrame("Frame",nil,details)
    actionBar:SetPoint("TOPLEFT",details,"TOPLEFT",15,-251)
    actionBar:SetPoint("TOPRIGHT",details,"TOPRIGHT",-15,-251)
    actionBar:SetHeight(48)
    UI:Background(actionBar,P.leather,true)
    local barTitle=UI:Text(actionBar,"small",P.pale)
    barTitle:SetPoint("LEFT",actionBar,"LEFT",12,0)
    barTitle:SetSize(93,23)
    barTitle:SetText("EXPEDITION")
    barTitle:SetWordWrap(false)

    local function expeditionAction(label,width,accent,click)
        local btn=CreateFrame("Button",nil,actionBar)
        btn:SetSize(width,30)
        btn:RegisterForClicks("LeftButtonUp")
        local bg=btn:CreateTexture(nil,"BACKGROUND")
        bg:SetPoint("TOPLEFT",btn,"TOPLEFT",1,-1)
        bg:SetPoint("BOTTOMRIGHT",btn,"BOTTOMRIGHT",-1,1)
        bg:SetColorTexture(.125,.088,.058,.96)
        if UI.FoundryQuestBorder then UI:FoundryQuestBorder(btn,{cap=12,alpha=.70}) end
        local accentLine=btn:CreateTexture(nil,"ARTWORK")
        accentLine:SetSize(2,16)
        accentLine:SetPoint("LEFT",btn,"LEFT",7,0)
        accentLine:SetColorTexture(accent[1],accent[2],accent[3],.90)
        local lbl=UI:Text(btn,"small",P.pale,"CENTER")
        lbl:SetPoint("TOPLEFT",btn,"TOPLEFT",14,-2)
        lbl:SetPoint("BOTTOMRIGHT",btn,"BOTTOMRIGHT",-10,2)
        lbl:SetWordWrap(false)
        lbl:SetText(label)
        local hi=btn:CreateTexture(nil,"HIGHLIGHT")
        hi:SetPoint("TOPLEFT",btn,"TOPLEFT",5,-5)
        hi:SetPoint("BOTTOMRIGHT",btn,"BOTTOMRIGHT",-5,5)
        hi:SetColorTexture(accent[1],accent[2],accent[3],.19)
        btn.label=lbl
        btn:SetScript("OnClick",click)
        return btn
    end

    local invite=expeditionAction("Invite to Expedition",157,{.73,.33,.22},function()
        local key=UI.selectedCharacterKey
        if key then UI:ConfirmExpeditionChange(key,not AF:IsExpeditionMember(key)) end
    end)
    invite:SetPoint("LEFT",barTitle,"RIGHT",8,0)
    local main=expeditionAction("Set as Main",124,{.92,.70,.31},function()
        local key=UI.selectedCharacterKey
        if key and AF:IsExpeditionMember(key) then AF:SetMain(key) end
    end)
    main:SetPoint("LEFT",invite,"RIGHT",6,0)
    local role=expeditionAction("Role: Adventurer",166,{.62,.74,.62},function()
        local key=UI.selectedCharacterKey
        if key then AF:CycleExpeditionRole(key) end
    end)
    role:SetPoint("LEFT",main,"RIGHT",6,0)

    local function layoutActions()
        -- Don't leave empty gaps when the selected character is the main.
        local available=actionBar:GetWidth()-112
        local shown={}
        for _,control in ipairs({invite,main,role}) do
            if control.afDesiredVisible then shown[#shown+1]=control end
        end
        local count=#shown
        if count==0 then return end
        local gap=6
        -- Use native-feeling, content-sized badges. In particular, don't
        -- expand a lone Role button to fill the entire action bar.
        local preferred={[invite]=164,[main]=132,[role]=168}
        local requested=gap*(count-1)
        for _,control in ipairs(shown) do requested=requested+preferred[control] end
        local scale=requested>0 and math.min(1,math.max(0,available)/requested) or 1
        for i,control in ipairs(shown) do
            control:ClearAllPoints()
            control:SetSize(math.max(86,preferred[control]*scale),30)
            if i==1 then control:SetPoint("LEFT",barTitle,"RIGHT",8,0)
            else control:SetPoint("LEFT",shown[i-1],"RIGHT",gap,0) end
        end
    end
    actionBar:SetScript("OnSizeChanged",layoutActions)
    local chronicleLabel=UI:SectionTitle(details,"Membership Chronicle")
    chronicleLabel:SetPoint("TOPLEFT",details,"TOPLEFT",15,-310)
    chronicleLabel:SetPoint("TOPRIGHT",details,"TOPRIGHT",-14,-310)
    local chronicle=UI:List(details,43)
    chronicle:SetPoint("TOPLEFT",details,"TOPLEFT",16,-349)
    chronicle:SetPoint("BOTTOMRIGHT",details,"BOTTOMRIGHT",-23,70)
    local ordinaryInfo=UI:Text(details,"small",P.ink)
    ordinaryInfo:SetPoint("TOPLEFT",details,"TOPLEFT",17,-317)
    ordinaryInfo:SetPoint("TOPRIGHT",details,"TOPRIGHT",-17,-317)
    ordinaryInfo:SetHeight(96)
    ordinaryInfo:SetJustifyV("TOP")
    ordinaryInfo:SetWordWrap(true)
    ordinaryInfo:SetText("Your adventurers are listed together, with their recorded goals, crafts, notes, professions and snapshots. Enable Self-Found in Settings > Modules to add Expedition membership and its Chronicle.")
    local chronicleDetail=UI:Text(details,"small",P.ink)
    chronicleDetail:SetPoint("BOTTOMLEFT",details,"BOTTOMLEFT",17,12)
    chronicleDetail:SetPoint("BOTTOMRIGHT",details,"BOTTOMRIGHT",-17,12)
    chronicleDetail:SetHeight(47)
    chronicleDetail:SetJustifyV("TOP")

    local watcher=CreateFrame("Frame",nil,page)
    watcher:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    watcher:RegisterEvent("UNIT_MODEL_CHANGED")
    watcher:SetScript("OnEvent",function(_,_,unit)
        if unit=="player" and page:IsShown() then page:Refresh() end
    end)

    function page:Refresh()
        if not AF.db or not AF.db.characters then return end
        -- Every tracker reads from actual Foundry records; incomplete gold
        -- and playtime observations remain explicitly marked incomplete.
        local selected,count=UI:EnsureAccountTrackerSettings()
        trackerCount.label:SetText(count==4 and "Show 5" or "Show 4")
        for i,row in ipairs(metrics) do
            local value,detail,label=UI:ReadAccountTracker(selected[i])
            row.heading:SetText(label)
            row.value:SetText(value)
            row.sub:SetText(detail)
        end
        metricsLayout()
        local moduleOn=AF:IsModuleEnabled("selfFound")
        rosterTitle:SetText(moduleOn and "Expedition & Alts" or "Your Adventurers")
        actionBar:SetShown(moduleOn)
        chronicleLabel:SetShown(moduleOn)
        chronicle:SetShown(moduleOn)
        chronicleDetail:SetShown(moduleOn)
        ordinaryInfo:SetShown(not moduleOn)
        charterHint:SetShown(moduleOn)
        rosterHint:SetText("Sort adventurers by:")
        if not UI.selectedCharacterKey or not AF.db.characters[UI.selectedCharacterKey] then
            UI.selectedCharacterKey=AF:GetCurrentKey()
        end
        rosterRefresh()
        local c=AF.db.characters[UI.selectedCharacterKey]
        if not c then return end
        -- Explicitly never use the live character's face for offline characters.
        icon(classBadge,c)
        if c.key==AF:GetCurrentKey() and type(SetPortraitTexture)=="function" then
            portrait:SetTexCoord(0,1,0,1)
            if not pcall(SetPortraitTexture,portrait,"player") then icon(portrait,c) end
        else icon(portrait,c) end
        selectedName:SetText(coloredName(c))
        selectedInfo:SetText("Level "..tostring(c.level or "?").." "..(c.class or "").."  |  "..(c.realm or "Unknown realm"))
        local member=AF:IsExpeditionMember(c.key)
        local isMain=c.key==AF.db.mainKey
        local participation=AF:GetExpeditionParticipation(c.key)
        selectedStatus:SetText(moduleOn and ((member and 'Expedition Member' or 'Independent')..
            (isMain and '  |  Main' or '')..(participation=='Charter participant' and '  |  Charter Active' or ''))
            or "Registered Adventurer")
        selectedGold:SetText("Gold: "..formatMoney(c.afMoneyCopper))
        selectedPlayed:SetText("Played: "..formatPlayed(c.afPlayedSeconds))
        seen:SetText("Last seen: "..when(c.lastSeen))
        joined:SetText(member and ("Joined: "..when(c.expeditionJoinedAt)) or "Not enrolled in Expedition")
        joined:SetShown(moduleOn)
        -- Only explicitly assigned projects/notes belong to this character.
        -- Account-wide journal entries are not relabeled as personal data.
        local goalsCount,craftCount,notesCount=0,0,0
        firstGoal,firstCraft,firstNote=nil,nil,nil
        for _,project in ipairs(AF.db.projects or {}) do
            if project.owner==c.key and not project.done then
                if type(project.crafting)=="table" then
                    craftCount=craftCount+1
                    if not firstCraft then firstCraft=project end
                else
                    goalsCount=goalsCount+1
                    if not firstGoal then firstGoal=project end
                end
            end
        end
        for _,note in ipairs(AF.db.notes or {}) do
            if note.owner==c.key then
                notesCount=notesCount+1
                if not firstNote then firstNote=note end
            end
        end
        local summaries={
            {goalsCount,firstGoal and firstGoal.title or "No assigned goals"},
            {craftCount,firstCraft and firstCraft.title or "No crafting plans"},
            {notesCount,firstNote and firstNote.title or "No personal notes"},
        }
        for i,row in ipairs(pursuitRows) do
            row.count:SetText(tostring(summaries[i][1]))
            row.preview:SetText(summaries[i][2] or "Untitled")
        end
        invite.afDesiredVisible=not isMain
        invite:SetShown(invite.afDesiredVisible)
        invite.label:SetText(member and "Leave Expedition" or "Invite to Expedition")
        main.afDesiredVisible=member and not isMain
        main:SetShown(main.afDesiredVisible)
        role.afDesiredVisible=member
        role:SetShown(role.afDesiredVisible)
        role.label:SetText("Role: "..(c.expeditionRole or "Adventurer"))
        layoutActions()
        local events=AF:CharacterExpeditionEvents(c.key,40)
        local items={}
        local labels={import="Enrolled after upgrade",join="Joined Expedition",rejoin="Rejoined (new period)",depart="Departed Expedition",leader="Named Main Adventurer"}
        for _,event in ipairs(events) do
            items[#items+1]={key=event.id,label=(labels[event.event] or event.event).."  -  "..when(event.timestamp)}
        end
        UI:FillList(chronicle,items,function(item)
            for _,ev in ipairs(events) do
                if ev.id==item.key then chronicleDetail:SetText(ev.detail or "No additional details") return end
            end
        end)
        chronicleDetail:SetText(#events==0 and "No membership events recorded. Gameplay outside the addon is not verified."
            or "Select a Chronicle entry for details. These are local journal records, not proof of rule compliance.")
    end
    page:Refresh()
end
