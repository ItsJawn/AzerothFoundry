-- v0.6.1: expanded charter rule badges, capability report, observed activity review.
local _, AF = ...
local UI=AF.UI
local P=UI.palette
local min,max=math.min,math.max
local unpack=unpack or table.unpack
local function mixColor(a,b,ratio)
    return {a[1]*(1-ratio)+b[1]*ratio,a[2]*(1-ratio)+b[2]*ratio,a[3]*(1-ratio)+b[3]*ratio,1}
end

local function when(t)
    if not t or t<=0 then return "Not recorded" end
    if type(date)=="function" then return date("%b %d %Y, %H:%M",t) end
    return "Recorded"
end
local function quiet(parent,caption,callback)
    local b=CreateFrame("Button",nil,parent)
    b:SetHeight(27)
    local bg=b:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(b)
    bg:SetColorTexture(.16,.105,.065,.98)
    local rule=b:CreateTexture(nil,"BORDER")
    rule:SetHeight(1);rule:SetPoint("BOTTOMLEFT",2,1);rule:SetPoint("BOTTOMRIGHT",-2,1)
    rule:SetColorTexture(.65,.45,.23,.8)
    local label=UI:Text(b,"small",P.pale,"CENTER")
    label:SetAllPoints(b)
    label:SetWordWrap(false)
    label:SetText(caption or "")
    b.label=label
    label.afThemeColorManaged=true
    b.afQuietSelected=false
    local function themedSurface(t,hover)
        local base=t.buttonFace
        if t.light then base=mixColor(t.paper,t.header,.22) end
        if b.afQuietSelected then
            base=t.light and mixColor(t.buttonFace,t.navActive,.38) or t.buttonFace
        elseif hover then
            base=t.light and mixColor(base,t.navActive,.18) or t.hover
        end
        return base
    end
    local function update(hover)
        if not UI.ThemeTokens then return end
        local t=UI:ThemeTokens()
        local c=themedSurface(t,hover)
        bg:SetColorTexture(c[1],c[2],c[3],.98)
        local br=t.divider;rule:SetColorTexture(br[1],br[2],br[3],.74)
        local preferred=b.afQuietSelected and (t.light and t.ink or t.accent2) or (t.light and t.ink or t.buttonText)
        local ink=UI.ThemeReadableText and UI:ThemeReadableText(c,preferred) or preferred
        label:SetTextColor(unpack(ink))
        label:SetAlpha(b:IsEnabled() and 1 or .62)
    end
    function b:SetSelected(selected)
        self.afQuietSelected=selected and true or false
        update((self.IsMouseOver and self:IsMouseOver()) or false)
    end
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(b,function()update(false)end) end
    b:SetScript("OnEnter",function()update(true)end)
    b:SetScript("OnLeave",function()update(false)end)
    b:SetScript("OnEnable",function()update(false)end)
    b:SetScript("OnDisable",function()update(false)end)
    b:SetScript("OnClick",callback)
    return b
end
local function label(parent,txt,size,color)
    local t=UI:Text(parent,size or "small",color or P.ink)
    t:SetText(txt or "")
    t:SetJustifyV("TOP")
    return t
end
local function section(parent,name)
    local s=UI:SectionTitle(parent,name)
    s:SetPoint("TOPLEFT",parent,"TOPLEFT",14,-8)
    s:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-12,-8)
    return s
end
local function safeMessage(msg)
    if AF.Print then AF.Print(msg) end
    if UI and UI.charterNotice then UI.charterNotice:SetText(msg) end
end
local function confirm(id,description,callback)
    if not StaticPopupDialogs or not StaticPopup_Show then
        safeMessage("Confirmation UI unavailable; no changes made.")
        return
    end
    if not StaticPopupDialogs[id] then
        StaticPopupDialogs[id]={text=description,button1=YES or "Confirm",button2=NO or "Cancel",
            timeout=0,whileDead=1,hideOnEscape=1,preferredIndex=3,
            OnAccept=function(_,data)if data and data.callback then data.callback() end end}
    end
    StaticPopup_Show(id,nil,nil,{callback=callback})
end

function UI:BuildSelfFoundCharter(page)
    local selectedTab="Overview"
    local milestoneArchiveIndex=0
    local selectedMilestone="first_harvest"
    local milestoneCategory="all"
    local milestoneStatus="all"
    local selectedKey=nil
    local selectedEvent=nil
    local archiveIndex=0
    local selectedReview=nil
    local chronicleSearch=""
    local chronicleSearchBox=nil
    local chronicleCategory="all"
    local chronicleStatus="all"
    local chronicleCharacter="all"
    local chronicleDays=nil
    local showTechnical=false
    local reviewKind="note"
    local reviewLevels={"declared","review","conflict"}
    local reviewLevel="declared"

    local header=CreateFrame("Frame",nil,page)
    header:SetPoint("TOPLEFT",page,"TOPLEFT",10,-9)
    header:SetPoint("TOPRIGHT",page,"TOPRIGHT",-10,-9)
    header:SetHeight(69)
    header.afThemeSurfaceVariant="intro"
    UI:Background(header,P.leather,true)
    local name=label(header,"THE EXPEDITION CHARTER", "title",P.gold)
    name:SetPoint("TOPLEFT",header,"TOPLEFT",15,-7)
    name:SetSize(430,23)
    local intro=label(header,"An optional challenge for your adventurers. The Chronicle is a local journal, not proof of compliance.","small",P.pale)
    intro:SetPoint("TOPLEFT",header,"TOPLEFT",16,-34)
    intro:SetPoint("TOPRIGHT",header,"TOPRIGHT",-16,-34)
    intro:SetHeight(28)
    intro:SetWordWrap(false)
    name.afThemeColorManaged=true
    intro.afThemeColorManaged=true
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(header,function(_,tokens)
        local _,titleInk,subInk=UI:ThemeIntroColors(tokens)
        name:SetTextColor(unpack(titleInk))
        intro:SetTextColor(unpack(subInk))
    end) end

    local tracker=CreateFrame("Frame",nil,page)
    tracker:SetPoint("TOPLEFT",header,"BOTTOMLEFT",0,-5)
    tracker:SetPoint("TOPRIGHT",header,"BOTTOMRIGHT",0,-5)
    tracker:SetHeight(55)
    local statusTexts={}
    for i=1,4 do
        local tile=CreateFrame("Frame",nil,tracker)
        UI:Background(tile,P.leather,true)
        local head=label(tile,"","small",P.pale)
        head:SetPoint("TOPLEFT",tile,"TOPLEFT",11,-5)
        head:SetPoint("TOPRIGHT",tile,"TOPRIGHT",-8,-5)
        head:SetHeight(17)
        local val=label(tile,"","small",P.gold)
        val:SetPoint("TOPLEFT",tile,"TOPLEFT",11,-24)
        val:SetPoint("TOPRIGHT",tile,"TOPRIGHT",-8,-24)
        val:SetHeight(21)
        val:SetWordWrap(false)
        val.afThemeColorManaged=true
        if UI.RegisterThemeTarget then UI:RegisterThemeTarget(val,function(label,tokens)
            local ink=UI:ThemeReadableText(tokens.dataSurface,tokens.accent2)
            label:SetTextColor(unpack(ink))
        end) end
        statusTexts[i]={frame=tile,head=head,value=val}
    end
    local function positionTrackers()
        local width=tracker:GetWidth() or 1100
        if width<100 then return end
        local gap=6
        local item=(width-gap*3)/4
        for i,entry in ipairs(statusTexts) do
            entry.frame:ClearAllPoints()
            entry.frame:SetPoint("TOPLEFT",tracker,"TOPLEFT",(i-1)*(item+gap),0)
            entry.frame:SetSize(item,55)
        end
    end
    tracker:SetScript("OnSizeChanged",positionTrackers)
    positionTrackers()

    local nav=CreateFrame("Frame",nil,page)
    nav:SetPoint("TOPLEFT",tracker,"BOTTOMLEFT",0,-6)
    nav:SetPoint("TOPRIGHT",tracker,"BOTTOMRIGHT",0,-6)
    nav:SetHeight(30)
    local tabs={}
    for i,tab in ipairs({"Overview","Milestones","Rulebook","Chronicle","Rule Review"}) do
        local b=quiet(nav,tab,function()selectedTab=tab;page:Refresh()end)
        b:SetPoint("TOPLEFT",nav,"TOPLEFT",(i-1)*152,0)
        b:SetSize(147,29)
        tabs[i]={button=b,name=tab}
    end

    local area=CreateFrame("Frame",nil,page)
    area:SetPoint("TOPLEFT",nav,"BOTTOMLEFT",0,-3)
    area:SetPoint("BOTTOMRIGHT",page,"BOTTOMRIGHT",-10,10)

    local overview=CreateFrame("Frame",nil,area)
    overview:SetAllPoints(area)
    local roster=UI:Card(overview)
    roster:SetPoint("TOPLEFT",overview,"TOPLEFT",0,0)
    roster:SetPoint("BOTTOMLEFT",overview,"BOTTOMLEFT",0,0)
    roster:SetWidth(345)
    section(roster,"The Adventuring Company")
    local rosterList=UI:List(roster,47)
    rosterList:SetPoint("TOPLEFT",roster,"TOPLEFT",13,-45)
    rosterList:SetPoint("BOTTOMRIGHT",roster,"BOTTOMRIGHT",-30,93)
    UI:InsetWorkshopScrollBar(rosterList)
    local memberHint=label(roster,"Choose a character to manage Expedition membership.","small")
    memberHint:SetPoint("BOTTOMLEFT",roster,"BOTTOMLEFT",14,60)
    memberHint:SetPoint("BOTTOMRIGHT",roster,"BOTTOMRIGHT",-12,60)
    memberHint:SetHeight(25)
    local manage=quiet(roster,"Enroll / Leave Selected",function()
        if not selectedKey then safeMessage("Select a registered character first.");return end
        if UI.ConfirmExpeditionChange then UI:ConfirmExpeditionChange(selectedKey,not AF:IsExpeditionMember(selectedKey))
        else UI:Switch("Characters") end
    end)
    manage:SetPoint("BOTTOMLEFT",roster,"BOTTOMLEFT",14,33)
    manage:SetPoint("BOTTOMRIGHT",roster,"BOTTOMRIGHT",-14,33)
    local charLink=quiet(roster,"Open Character Roster",function()UI:Switch("Characters")end)
    charLink:SetPoint("BOTTOMLEFT",roster,"BOTTOMLEFT",14,7)
    charLink:SetPoint("BOTTOMRIGHT",roster,"BOTTOMRIGHT",-14,7)

    local charterPanel=UI:Card(overview)
    charterPanel:SetPoint("TOPLEFT",roster,"TOPRIGHT",9,0)
    charterPanel:SetPoint("BOTTOMRIGHT",overview,"BOTTOMRIGHT",0,0)
    section(charterPanel,"Your Expedition Charter")
    local charterHeading=label(charterPanel,"", "title")
    charterHeading:SetPoint("TOPLEFT",charterPanel,"TOPLEFT",18,-52)
    charterHeading:SetPoint("TOPRIGHT",charterPanel,"TOPRIGHT",-18,-52)
    charterHeading:SetHeight(26)
    local charterDesc=label(charterPanel,"",nil)
    charterDesc:SetPoint("TOPLEFT",charterPanel,"TOPLEFT",18,-85)
    charterDesc:SetPoint("TOPRIGHT",charterPanel,"TOPRIGHT",-18,-85)
    charterDesc:SetHeight(67)
    local scopeHead=label(charterPanel,"CHARTER BOUNDARIES", "small")
    scopeHead:SetPoint("TOPLEFT",charterPanel,"TOPLEFT",18,-171)
    scopeHead:SetSize(300,23)
    local rulePreview={}
    local importantRules={"outsideTrade","auctionPurchase","altShare","outsideHelp"}
    for i=1,#importantRules do
        local r=label(charterPanel,"","small")
        r:SetPoint("TOPLEFT",charterPanel,"TOPLEFT",20,-199-(i-1)*26)
        r:SetPoint("TOPRIGHT",charterPanel,"TOPRIGHT",-15,-199-(i-1)*26)
        r:SetHeight(25)
        r:SetWordWrap(false)
        rulePreview[i]=r
    end
    local statement=label(charterPanel,"", "small")
    statement:SetPoint("BOTTOMLEFT",charterPanel,"BOTTOMLEFT",18,52)
    statement:SetPoint("BOTTOMRIGHT",charterPanel,"BOTTOMRIGHT",-18,52)
    statement:SetHeight(72)
    local openRules=quiet(charterPanel,"Read / Configure Rulebook",function()selectedTab="Rulebook";page:Refresh()end)
    openRules:SetPoint("BOTTOMLEFT",charterPanel,"BOTTOMLEFT",17,14)
    openRules:SetSize(240,28)
    local openHistory=quiet(charterPanel,"View Chronicle",function()selectedTab="Chronicle";page:Refresh()end)
    openHistory:SetPoint("BOTTOMRIGHT",charterPanel,"BOTTOMRIGHT",-15,14)
    openHistory:SetSize(180,28)

    -- v0.6.4: a broader, gallery-style milestone ledger. These are still
    -- local Foundry accomplishments per charter run, not Blizzard achievements
    -- and not proof that every self-found restriction was obeyed.
    local milestonePage=CreateFrame("Frame",nil,area)
    milestonePage:SetAllPoints(area)
    local milestoneLeft=UI:Card(milestonePage)
    milestoneLeft:SetPoint("TOPLEFT",milestonePage,"TOPLEFT",0,0)
    milestoneLeft:SetPoint("BOTTOMLEFT",milestonePage,"BOTTOMLEFT",0,0)
    local milestonePanelWidth=548
    local function applyMilestonePanelWidth(requested)
        local available=tonumber(milestonePage:GetWidth()) or 0
        if available<700 then available=1200 end
        local upper=math.max(360,available-355)
        milestonePanelWidth=math.floor(math.max(350,math.min(upper,tonumber(requested) or milestonePanelWidth))+0.5)
        milestoneLeft:SetWidth(milestonePanelWidth)
    end
    local settings=AF.db and AF.db.settings
    applyMilestonePanelWidth(settings and settings.milestoneGalleryWidth or 548)
    section(milestoneLeft,"Expedition Milestones")
    local milestoneRunButton=quiet(milestoneLeft,"Run: Current",function()
        local expedition=AF:GetExpedition()
        local archives=expedition and expedition.charterArchive or {}
        milestoneArchiveIndex=(milestoneArchiveIndex+1)%(#archives+1)
        selectedMilestone="first_harvest"
        page:Refresh()
    end)
    milestoneRunButton:SetPoint("TOPLEFT",milestoneLeft,"TOPLEFT",14,-50)
    milestoneRunButton:SetPoint("TOPRIGHT",milestoneLeft,"TOPRIGHT",-14,-50)
    local milestoneFilterCategory=quiet(milestoneLeft,"Category: All",function() end)
    milestoneFilterCategory:SetPoint("TOPLEFT",milestoneLeft,"TOPLEFT",14,-83)
    milestoneFilterCategory:SetPoint("TOPRIGHT",milestoneLeft,"TOP",-5,-83)
    local milestoneFilterStatus=quiet(milestoneLeft,"Status: All",function() end)
    milestoneFilterStatus:SetPoint("TOPLEFT",milestoneLeft,"TOP",5,-83)
    milestoneFilterStatus:SetPoint("TOPRIGHT",milestoneLeft,"TOPRIGHT",-14,-83)
    local milestoneCount=label(milestoneLeft,"", "small",P.ink)
    milestoneCount:SetPoint("TOPLEFT",milestoneLeft,"TOPLEFT",16,-116)
    milestoneCount:SetPoint("TOPRIGHT",milestoneLeft,"TOPRIGHT",-15,-116)
    milestoneCount:SetHeight(28)
    milestoneCount:SetWordWrap(false)
    local milestoneGallery=CreateFrame("ScrollFrame",nil,milestoneLeft,"UIPanelScrollFrameTemplate")
    milestoneGallery:SetPoint("TOPLEFT",milestoneLeft,"TOPLEFT",13,-148)
    milestoneGallery:SetPoint("BOTTOMRIGHT",milestoneLeft,"BOTTOMRIGHT",-29,63)
    UI:InsetWorkshopScrollBar(milestoneGallery)
    local milestoneGalleryChild=CreateFrame("Frame",nil,milestoneGallery)
    milestoneGalleryChild:SetSize(240,200)
    milestoneGallery:SetScrollChild(milestoneGalleryChild)
    local milestoneCards={}
    local milestoneLegal=label(milestoneLeft,"Local journal records only. No compliance certification.","small",P.ink)
    milestoneLegal:SetPoint("BOTTOMLEFT",milestoneLeft,"BOTTOMLEFT",15,15)
    milestoneLegal:SetPoint("BOTTOMRIGHT",milestoneLeft,"BOTTOMRIGHT",-14,15)
    milestoneLegal:SetHeight(40)
    local function ensureMilestoneCard(i)
        local card=milestoneCards[i]
        if card then return card end
        card=CreateFrame("Button",nil,milestoneGalleryChild)
        UI:Background(card,P.leather,true)
        card.hover=card:CreateTexture(nil,"ARTWORK",nil,-1)
        card.hover:SetPoint("TOPLEFT",card,"TOPLEFT",5,-5)
        card.hover:SetPoint("BOTTOMRIGHT",card,"BOTTOMRIGHT",-5,5)
        card.hover:SetColorTexture(1,.80,.44,.10)
        card.hover:Hide()
        card.selectedShade=card:CreateTexture(nil,"ARTWORK")
        card.selectedShade:SetPoint("TOPLEFT",card,"TOPLEFT",5,-5)
        card.selectedShade:SetPoint("BOTTOMRIGHT",card,"BOTTOMRIGHT",-5,5)
        card.selectedShade:SetColorTexture(.89,.66,.26,.18)
        card.selectedShade:Hide()
        card.stripe=card:CreateTexture(nil,"ARTWORK")
        card.stripe:SetPoint("TOPLEFT",card,"TOPLEFT",6,-7)
        card.stripe:SetPoint("BOTTOMLEFT",card,"BOTTOMLEFT",6,7)
        card.stripe:SetWidth(4)
        card.iconBack=card:CreateTexture(nil,"BACKGROUND")
        card.iconBack:SetPoint("TOPLEFT",card,"TOPLEFT",16,-14)
        card.iconBack:SetSize(42,42)
        card.iconBack:SetColorTexture(.08,.055,.035,.95)
        card.icon=card:CreateTexture(nil,"OVERLAY")
        card.icon:SetPoint("CENTER",card.iconBack,"CENTER",0,0)
        card.icon:SetSize(36,36)
        card.title=label(card,"","small",P.pale)
        card.title:SetPoint("TOPLEFT",card,"TOPLEFT",68,-11)
        card.title:SetPoint("TOPRIGHT",card,"TOPRIGHT",-11,-11)
        card.title:SetHeight(18)
        card.title:SetWordWrap(false)
        card.meta=label(card,"","small",{.80,.71,.57,1})
        card.meta:SetPoint("TOPLEFT",card,"TOPLEFT",68,-31)
        card.meta:SetPoint("TOPRIGHT",card,"TOPRIGHT",-11,-31)
        card.meta:SetHeight(15)
        card.meta:SetWordWrap(false)
        card.short=label(card,"","small",P.pale)
        card.short:SetPoint("TOPLEFT",card,"TOPLEFT",68,-48)
        card.short:SetPoint("BOTTOMRIGHT",card,"BOTTOMRIGHT",-11,10)
        card.short:SetWordWrap(true)
        card:SetScript("OnEnter",function(self) self.hover:Show() end)
        card:SetScript("OnLeave",function(self) self.hover:Hide() end)
        milestoneCards[i]=card
        return card
    end
    local function renderMilestoneGallery(entries)
        local width=(milestoneGallery:GetWidth() or 420)-8
        local cols=width>=430 and 2 or 1
        local gap=10
        local innerWidth=math.max(170,width-6)
        local cardW=cols==2 and math.floor((innerWidth-gap)/2) or innerWidth
        local cardH=86
        local rows=math.max(1,math.ceil((#entries)/cols))
        milestoneGalleryChild:SetWidth(innerWidth)
        milestoneGalleryChild:SetHeight(math.max(1,rows*(cardH+gap)-gap+6))
        for i,entry in ipairs(entries) do
            local card=ensureMilestoneCard(i)
            local column=(i-1)%cols
            local row=math.floor((i-1)/cols)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT",milestoneGalleryChild,"TOPLEFT",column*(cardW+gap),-(row*(cardH+gap)))
            card:SetSize(cardW,cardH)
            card.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            card.title:SetText(entry.title or "Unknown")
            card.meta:SetText((entry.category or "General").."  -  "..(entry.stateLabel or "Pending"))
        card.meta:SetTextColor(unpack(entry.recorded and {.92,.80,.55,1} or {.80,.72,.60,1}))
            card.short:SetText(entry.short or "")
            card.stripe:SetColorTexture(unpack(entry.recorded and {0.88,0.69,0.31,1} or {.42,.31,.20,.84}))
            card.selectedShade:SetShown(entry.key==selectedMilestone)
            card:SetScript("OnClick",function()
                selectedMilestone=entry.key
                page:Refresh()
            end)
            card:Show()
        end
        for i=#entries+1,#milestoneCards do milestoneCards[i]:Hide() end
        local bar=UI:ListScrollBar(milestoneGallery)
        if bar then bar:SetShown((milestoneGalleryChild:GetHeight() or 0)>(milestoneGallery:GetHeight() or 0)+3) end
    end

    local milestoneRight=UI:Card(milestonePage)
    milestoneRight:SetPoint("TOPLEFT",milestoneLeft,"TOPRIGHT",9,0)
    milestoneRight:SetPoint("BOTTOMRIGHT",milestonePage,"BOTTOMRIGHT",0,0)
    -- Collections-style draggable gutter: save only the layout width, never alter milestone data.
    local milestoneSplitter=CreateFrame("Frame",nil,milestonePage)
    milestoneSplitter:SetPoint("TOPLEFT",milestoneLeft,"TOPRIGHT",-4,0)
    milestoneSplitter:SetPoint("BOTTOMRIGHT",milestoneLeft,"BOTTOMRIGHT",13,0)
    milestoneSplitter:EnableMouse(true)
    milestoneSplitter:SetFrameLevel(math.max(milestoneLeft:GetFrameLevel(),milestoneRight:GetFrameLevel())+8)
    UI:StyleResizeGrip(milestoneSplitter,"OVERLAY")
    local dragMilestoneX,dragMilestoneWidth
    local function stopMilestoneDrag()
        if not dragMilestoneX then return end
        dragMilestoneX,dragMilestoneWidth=nil,nil
        if AF.db and AF.db.settings then AF.db.settings.milestoneGalleryWidth=milestonePanelWidth end
        if selectedTab=="Milestones" then page:Refresh() end
    end
    milestoneSplitter:SetScript("OnMouseDown",function(_,button)
        if button~="LeftButton" or type(GetCursorPosition)~="function" then return end
        dragMilestoneX=GetCursorPosition()
        dragMilestoneWidth=milestonePanelWidth
    end)
    milestoneSplitter:SetScript("OnMouseUp",function(_,button)
        if button=="LeftButton" then stopMilestoneDrag() end
    end)
    milestoneSplitter:SetScript("OnUpdate",function()
        if not dragMilestoneX or type(GetCursorPosition)~="function" then return end
        if type(IsMouseButtonDown)=="function" and not IsMouseButtonDown("LeftButton") then stopMilestoneDrag();return end
        local x=GetCursorPosition()
        if type(x)~="number" then return end
        local scale=math.max(.01,milestonePage:GetEffectiveScale() or 1)
        local requested=dragMilestoneWidth+(x-dragMilestoneX)/scale
        if math.abs(requested-milestonePanelWidth)>1 then
            applyMilestonePanelWidth(requested)
            -- The gallery reflows between one and two columns on drag release.
        end
    end)
    milestonePage:HookScript("OnHide",stopMilestoneDrag)
    section(milestoneRight,"Accomplishment Record")
    local milestoneIcon=milestoneRight:CreateTexture(nil,"OVERLAY")
    milestoneIcon:SetPoint("TOPLEFT",milestoneRight,"TOPLEFT",18,-47)
    milestoneIcon:SetSize(42,42)
    local milestoneTitle=label(milestoneRight,"Choose a milestone","title",P.ink)
    milestoneTitle:SetPoint("TOPLEFT",milestoneRight,"TOPLEFT",72,-48)
    milestoneTitle:SetPoint("TOPRIGHT",milestoneRight,"TOPRIGHT",-17,-48)
    milestoneTitle:SetHeight(31)
    local milestoneMeta=label(milestoneRight,"", "small",P.ink)
    milestoneMeta:SetPoint("TOPLEFT",milestoneRight,"TOPLEFT",72,-82)
    milestoneMeta:SetPoint("TOPRIGHT",milestoneRight,"TOPRIGHT",-17,-82)
    milestoneMeta:SetHeight(62)
    local milestoneDesc=label(milestoneRight,"", "small",P.ink)
    milestoneDesc:SetPoint("TOPLEFT",milestoneRight,"TOPLEFT",18,-153)
    milestoneDesc:SetPoint("TOPRIGHT",milestoneRight,"TOPRIGHT",-17,-153)
    milestoneDesc:SetHeight(102)
    milestoneDesc:SetWordWrap(true)
    local milestoneEvidence=label(milestoneRight,"", "small",P.ink)
    milestoneEvidence:SetPoint("TOPLEFT",milestoneRight,"TOPLEFT",18,-268)
    milestoneEvidence:SetPoint("BOTTOMRIGHT",milestoneRight,"BOTTOMRIGHT",-18,126)
    milestoneEvidence:SetWordWrap(true)
    local milestoneDeclare=quiet(milestoneRight,"Declare First Harvest",function()
        local expedition=AF:GetExpedition()
        local run=expedition and expedition.charter
        if milestoneArchiveIndex~=0 or not run or run.state~="active" then
            safeMessage("Only the active charter accepts new declarations.");return
        end
        confirm("AZEROTHFOUNDRY_MILESTONE_HARVEST",
            "Declare that you personally gathered materials in this charter? This records YOUR statement, not independently verified provenance.",
            function()
                local ok,reason=AF:DeclareExpeditionHarvest()
                if not ok then safeMessage(reason) end
                page:Refresh()
            end)
    end)
    milestoneDeclare:SetPoint("BOTTOMLEFT",milestoneRight,"BOTTOMLEFT",17,17)
    milestoneDeclare:SetSize(174,28)
    local milestoneChronicle=quiet(milestoneRight,"Show Chronicle Entry",function()
        local expedition=AF:GetExpedition()
        local archives=expedition and expedition.charterArchive or {}
        local run=milestoneArchiveIndex==0 and expedition.charter or archives[#archives-milestoneArchiveIndex+1]
        local award=AF:GetExpeditionMilestoneAward(run,selectedMilestone)
        if not award or not award.eventId then return end
        archiveIndex=milestoneArchiveIndex
        selectedEvent=award.eventId
        chronicleCategory="all";chronicleStatus="all";chronicleDays=nil;chronicleCharacter="all"
        chronicleSearch=""
        if chronicleSearchBox then chronicleSearchBox:SetText("") end
        selectedTab="Chronicle"
        page:Refresh()
    end)
    milestoneChronicle:SetPoint("BOTTOMLEFT",milestoneRight,"BOTTOMLEFT",17,53)
    milestoneChronicle:SetSize(174,28)
    local milestoneGoal=quiet(milestoneRight,"Add to Goals",function()
        local expedition=AF:GetExpedition()
        local archives=expedition and expedition.charterArchive or {}
        local run=milestoneArchiveIndex==0 and expedition.charter or archives[#archives-milestoneArchiveIndex+1]
        local project,reason=AF:MakeExpeditionMilestoneGoal(run,selectedMilestone)
        if not project then safeMessage(reason or "Cannot create milestone goal") end
        page:Refresh()
    end)
    milestoneGoal:SetPoint("BOTTOMRIGHT",milestoneRight,"BOTTOMRIGHT",-16,17)
    milestoneGoal:SetSize(168,28)
    local milestoneOpenGoal=quiet(milestoneRight,"Open in Goals",function()
        local expedition=AF:GetExpedition()
        local archives=expedition and expedition.charterArchive or {}
        local run=milestoneArchiveIndex==0 and expedition.charter or archives[#archives-milestoneArchiveIndex+1]
        local project=AF:GetExpeditionMilestoneGoal(run,selectedMilestone)
        if not project then return end
        UI.selectedProjectId=project.id
        local settings=AF.db.settings.goalJournal
        if type(settings)=="table" then
            settings.status="All";settings.kind="All types";settings.owner="All characters"
        end
        UI:Switch("Goals")
    end)
    milestoneOpenGoal:SetPoint("BOTTOMRIGHT",milestoneRight,"BOTTOMRIGHT",-16,53)
    milestoneOpenGoal:SetSize(168,28)
    local milestoneTrackGoal=quiet(milestoneRight,"Track on Screen",function()
        local expedition=AF:GetExpedition()
        local archives=expedition and expedition.charterArchive or {}
        local run=milestoneArchiveIndex==0 and expedition.charter or archives[#archives-milestoneArchiveIndex+1]
        local project=AF:GetExpeditionMilestoneGoal(run,selectedMilestone)
        if not project then return end
        local ok,reason=AF:PinGuidedGoal(project.id)
        if not ok then safeMessage(reason or "Unable to track goal") end
        page:Refresh()
    end)
    milestoneTrackGoal:SetPoint("BOTTOMRIGHT",milestoneRight,"BOTTOMRIGHT",-16,89)
    milestoneTrackGoal:SetSize(168,28)
    local function refreshMilestones()
        local exp=AF:GetExpedition()
        local archives=exp and exp.charterArchive or {}
        if milestoneArchiveIndex>#archives then milestoneArchiveIndex=0 end
        local run=exp and (milestoneArchiveIndex==0 and exp.charter or archives[#archives-milestoneArchiveIndex+1])
        if not run then return end
        milestoneRunButton.label:SetText(milestoneArchiveIndex==0 and "Run: Current Charter  v"..tostring(run.version or 0)
            or ("Run: Previous #"..tostring(milestoneArchiveIndex).."  (read-only)"))
        local categoryName={all="All",Gathering="Gathering",Crafting="Crafting",Professions="Professions",
            Exploration="Exploration",Questing="Questing",Character="Character",Roster="Roster"}
        local statusName={all="All",pending="Pending",recorded="Recorded"}
        milestoneFilterCategory.label:SetText("Category: "..(categoryName[milestoneCategory] or tostring(milestoneCategory)))
        milestoneFilterStatus.label:SetText("Status: "..(statusName[milestoneStatus] or tostring(milestoneStatus)))
        local completed,entries,total=0,{},0
        for _,def in ipairs(AF.EXPEDITION_MILESTONE_DEFS or {}) do
            total=total+1
            local award=AF:GetExpeditionMilestoneAward(run,def.id)
            if award then completed=completed+1 end
            local statusOk=milestoneStatus=="all" or (milestoneStatus=="recorded" and award) or (milestoneStatus=="pending" and not award)
            local categoryOk=milestoneCategory=="all" or def.category==milestoneCategory
            if statusOk and categoryOk then
                entries[#entries+1]={key=def.id,icon=def.icon,title=def.title,short=def.short,
                    category=def.category or "General",recorded=award~=nil,
                    stateLabel=award and "Recorded" or "Pending"}
            end
        end
        if #entries==0 and milestoneCategory~="all" then
            selectedMilestone=nil
        elseif #entries>0 then
            local found=false
            for _,entry in ipairs(entries) do if entry.key==selectedMilestone then found=true;break end end
            if not found then selectedMilestone=entries[1].key end
        end
        milestoneCount:SetText(tostring(completed).." of "..tostring(total).." accomplishments recorded"
            ..(#entries~=total and ("  •  Showing "..tostring(#entries)) or "")
            ..(run.state=="draft" and "  |  Charter not active" or ""))
        renderMilestoneGallery(entries)
        local def=AF:GetExpeditionMilestoneDef(selectedMilestone)
        if not def then def=AF.EXPEDITION_MILESTONE_DEFS[1];selectedMilestone=def and def.id or nil end
        if not def then return end
        local award=AF:GetExpeditionMilestoneAward(run,def.id)
        local progress,target,progressLabel=AF:GetExpeditionMilestoneProgress(run,def.id)
        local evidenceName={client_event="Client event",local_record="Foundry local record",player_declared="Player declaration"}
        local stateText=award and "RECORDED" or "PENDING"
        local stateMeta=award and (when(award.awardedAt).."  •  "..(evidenceName[award.evidence] or "Local record"))
            or (run.state=="active" and "Active charter" or (run.state=="draft" and "Activate a charter first" or "Run ended"))
        local progressLine=(def.method=="manual") and (award and "Declaration saved" or "Awaiting declaration")
            or (tostring(progress or 0).." / "..tostring(target or 1).." "..tostring(progressLabel or "progress"))
        milestoneIcon:SetTexture(def.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        milestoneTitle:SetText(def.title)
        milestoneMeta:SetText(stateText.."  •  "..(def.category or "General").."\n"..stateMeta.."\nProgress: "..progressLine)
        milestoneDesc:SetText(def.description)
        local project=AF:GetExpeditionMilestoneGoal(run,def.id)
        milestoneEvidence:SetText("TRACKING NOTES\n"
            ..(award and ((award.detail or "No detail saved").."\nRecorded under charter version "..tostring(award.version or "?")..".")
                or "This milestone has not yet been recorded in this charter run.")
            .."\n\nGOAL LINK\n"
            ..(project and ("Linked Goal #"..tostring(project.id)..(project.done and "  •  Completed" or "  •  Active"))
                or "Not yet added to your Goals journal.")
            .."\n\nThese are local Foundry accomplishments for the active or archived charter. Earlier play, disconnected periods, and material provenance are not independently verified.")
        local mayDeclare=milestoneArchiveIndex==0 and run.state=="active" and not award and
            def.method=="manual" and AF:IsCharterScopedMember(AF:GetCurrentKey())
        milestoneDeclare:SetShown(mayDeclare==true)
        milestoneChronicle:SetShown(award~=nil and award.eventId~=nil)
        milestoneGoal:SetShown(run.id~=nil and project==nil)
        milestoneOpenGoal:SetShown(project~=nil)
        milestoneTrackGoal:SetShown(project~=nil)
        if project then
            milestoneTrackGoal.label:SetText(AF:GoalIsPinned(project.id) and "Untrack Goal" or "Track on Screen")
        end
    end
    local function sizeMilestonePanels()
        local w=milestonePage:GetWidth() or 0
        if w<300 then return end
        applyMilestonePanelWidth(milestonePanelWidth)
        if selectedTab=="Milestones" then refreshMilestones() end
    end
    milestonePage:SetScript("OnSizeChanged",sizeMilestonePanels)
    local rulebook=CreateFrame("Frame",nil,area)
    rulebook:SetAllPoints(area)
    local left=UI:Card(rulebook)
    left:SetPoint("TOPLEFT",rulebook,"TOPLEFT",0,0)
    left:SetPoint("BOTTOMLEFT",rulebook,"BOTTOMLEFT",0,0)
    left:SetWidth(325)
    section(left,"Ruleset")
    local draftHint=label(left,"",nil)
    draftHint:SetPoint("TOPLEFT",left,"TOPLEFT",15,-49)
    draftHint:SetPoint("TOPRIGHT",left,"TOPRIGHT",-15,-49)
    draftHint:SetHeight(85)
    local presetButtons={}
    for i,id in ipairs({"solo","account","custom"}) do
        local b=quiet(left,AF.CHARTER_PRESET_NAMES[id],function()
            local ok,reason=AF:ChooseCharterPreset(id)
            if not ok then safeMessage(reason) end
            page:Refresh()
        end)
        b:SetPoint("TOPLEFT",left,"TOPLEFT",15,-144-(i-1)*37)
        b:SetPoint("TOPRIGHT",left,"TOPRIGHT",-15,-144-(i-1)*37)
        presetButtons[i]={id=id,button=b}
    end
    local revision=quiet(left,"Edit Charter Rules",function()
        local ok,reason=AF:BeginCharterRevision();if not ok then safeMessage(reason) end
        page:Refresh()
    end)
    revision:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",15,119)
    revision:SetPoint("BOTTOMRIGHT",left,"BOTTOMRIGHT",-15,119)
    local publish=quiet(left,"Activate Charter",function()
        local c=AF:GetExpeditionCharter()
        if not c or not c.draft then return end
        local isStart=c.state=="draft"
        local id=isStart and "AZEROTHFOUNDRY_CHARTER_START" or "AZEROTHFOUNDRY_CHARTER_REVISE"
        local msg=isStart and "Start a voluntary Expedition charter? Earlier gameplay is unverified. Foundry cannot enforce all restrictions or certify compliance."
            or "Publish new charter rules? This creates a new permanent ruleset version. Earlier recorded versions remain unchanged."
        confirm(id,msg,function()
            local ok,why
            if isStart then ok,why=AF:StartCharter() else ok,why=AF:PublishCharterRevision() end
            if not ok then safeMessage(why) end
            page:Refresh()
        end)
    end)
    publish:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",15,84)
    publish:SetPoint("BOTTOMRIGHT",left,"BOTTOMRIGHT",-15,84)
    local discard=quiet(left,"Discard Rule Changes",function()AF:DiscardCharterRevision();page:Refresh()end)
    discard:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",15,49)
    discard:SetPoint("BOTTOMRIGHT",left,"BOTTOMRIGHT",-15,49)
    local endRun=quiet(left,"End Charter / New Run",function()
        local c=AF:GetExpeditionCharter()
        if c and c.state=="active" then
            confirm("AZEROTHFOUNDRY_CHARTER_END",
                "End the active Expedition charter? The local Chronicle and previous rule versions remain, and this run cannot resume.",
                function()local ok,why=AF:EndCharter();if not ok then safeMessage(why) end;page:Refresh()end)
        elseif c and c.state=="ended" then
            confirm("AZEROTHFOUNDRY_CHARTER_NEW",
                "Archive the finished run and prepare a NEW charter? Past records stay saved and this run begins unobserved.",
                function()local ok,why=AF:PrepareNewCharter();if not ok then safeMessage(why) end;page:Refresh()end)
        end
    end)
    endRun:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",15,14)
    endRun:SetPoint("BOTTOMRIGHT",left,"BOTTOMRIGHT",-15,14)
    local right=UI:Card(rulebook)
    right:SetPoint("TOPLEFT",left,"TOPRIGHT",9,0)
    right:SetPoint("BOTTOMRIGHT",rulebook,"BOTTOMRIGHT",0,0)
    section(right,"Expedition Rules")
    local ruleHeading=label(right,"", "small")
    ruleHeading:SetPoint("TOPLEFT",right,"TOPLEFT",16,-47)
    ruleHeading:SetPoint("TOPRIGHT",right,"TOPRIGHT",-17,-47)
    ruleHeading:SetHeight(43)
    -- These two pictograms ship with Foundry so they remain legible even when
    -- a particular Forever font lacks Unicode checkmarks or crosses.
    local allowedIcon="Interface\\AddOns\\AzerothFoundry\\Media\\CharterAllowed.tga"
    local restrictedIcon="Interface\\AddOns\\AzerothFoundry\\Media\\CharterRestricted.tga"
    local allowColor={.48,.89,.47}
    local denyColor={.96,.46,.36}
    local unknownColor={.73,.69,.59}
    local ruleScroll=CreateFrame("ScrollFrame",nil,right,"UIPanelScrollFrameTemplate")
    ruleScroll:SetPoint("TOPLEFT",right,"TOPLEFT",16,-94)
    ruleScroll:SetPoint("BOTTOMRIGHT",right,"BOTTOMRIGHT",-29,70)
    local ruleChild=CreateFrame("Frame",nil,ruleScroll)
    ruleChild:SetSize(500,365)
    ruleScroll:SetScrollChild(ruleChild)
    UI:InsetWorkshopScrollBar(ruleScroll)
    local rows={}
    for i,def in ipairs(AF.CHARTER_RULE_DEFS) do
        -- Each badge is one clickable surface. Reading/hovering the rule never
        -- changes SavedVariables; only a click in an editable draft can do so.
        local badge=CreateFrame("Button",nil,ruleChild)
        UI:Background(badge,P.leather,true)
        local hover=badge:CreateTexture(nil,"ARTWORK",nil,-1)
        hover:SetPoint("TOPLEFT",badge,"TOPLEFT",5,-5)
        hover:SetPoint("BOTTOMRIGHT",badge,"BOTTOMRIGHT",-5,5)
        hover:SetColorTexture(1,.80,.44,.11)
        hover:Hide()
        local stripe=badge:CreateTexture(nil,"ARTWORK")
        stripe:SetPoint("TOPLEFT",badge,"TOPLEFT",6,-7)
        stripe:SetPoint("BOTTOMLEFT",badge,"BOTTOMLEFT",6,7)
        stripe:SetWidth(3)
        local emblem=badge:CreateTexture(nil,"OVERLAY")
        emblem:SetPoint("TOPLEFT",badge,"TOPLEFT",16,-18)
        emblem:SetSize(27,27)
        local head=label(badge,def.label,"small",P.pale)
        head:SetPoint("TOPLEFT",badge,"TOPLEFT",51,-12)
        head:SetPoint("TOPRIGHT",badge,"TOPRIGHT",-9,-12)
        head:SetHeight(31)
        head:SetWordWrap(true)
        local state=label(badge,"", "small")
        state:SetPoint("BOTTOMLEFT",badge,"BOTTOMLEFT",51,10)
        state:SetPoint("BOTTOMRIGHT",badge,"BOTTOMRIGHT",-11,10)
        state:SetHeight(16)
        state:SetWordWrap(false)
        badge:SetScript("OnEnter",function(self)
            hover:Show()
            if not GameTooltip or not GameTooltip.SetOwner then return end
            local charter=AF:GetExpeditionCharter()
            local draft=charter and charter.draft
            local effective=draft and draft.rules or (charter and charter.rules)
            local permitted=effective and effective[def.id]
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:AddLine(def.label,1,.79,.43)
            local rgb=permitted==nil and unknownColor or (permitted and allowColor or denyColor)
            GameTooltip:AddLine(permitted==nil and "NOT IN CHARTER" or (permitted and "ALLOWED" or "RESTRICTED"),
                rgb[1],rgb[2],rgb[3])
            GameTooltip:AddLine("Category: "..(def.group or "General"),.72,.71,.64)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(def.note,1,.9,.73,true)
            GameTooltip:AddLine(" ")
            if draft then
                GameTooltip:AddLine("Click this badge to change the draft rule. Changes take effect only when you activate or publish it.",.83,.72,.53,true)
            else
                GameTooltip:AddLine("Published rules are read-only. Choose Edit Charter Rules to create a revision.",.83,.72,.53,true)
            end
            if permitted==nil then GameTooltip:AddLine("This restriction was introduced after your active charter was published. It has no effect until explicitly added in a new version.",.93,.75,.45,true) end
            GameTooltip:AddLine("The observer can detect some client events but cannot certify or block gameplay.",.69,.68,.61,true)
            GameTooltip:Show()
        end)
        badge:SetScript("OnLeave",function()
            hover:Hide()
            if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
        end)
        badge:SetScript("OnClick",function()
            local c=AF:GetExpeditionCharter()
            if not c or not c.draft then
                safeMessage("Choose Edit Charter Rules to make a revision.")
                return
            end
            local ok,why=AF:SetCharterDraftRule(def.id,not c.draft.rules[def.id])
            if not ok then safeMessage(why or "Unable to change charter rule") end
            page:Refresh()
        end)
        rows[i]={badge=badge,id=def.id,group=def.group,emblem=emblem,stripe=stripe,state=state}
    end
    -- Category dividers keep the expanded sixteen-rule book legible while
    -- retaining the same responsive 3 / 2 / 1-column badge styling.
    local ruleGroups={"Trading","Auction House","Mail & Storage","Cooperation","NPC Economy"}
    local groupHeadings={}
    for _,group in ipairs(ruleGroups) do
        local title=label(ruleChild,group:upper(),"small",P.ink)
        title:SetHeight(19)
        groupHeadings[group]=title
    end
    local function layoutRuleBadges()
        local width=ruleScroll:GetWidth() or 0
        if width<200 then width=500 end
        width=math.max(230,width-8)
        local columns=width>=835 and 3 or width>=515 and 2 or 1
        local gap=9
        local tileWidth=(width-gap*(columns-1)-2)/columns
        local tileHeight=78
        local y=0
        for _,group in ipairs(ruleGroups) do
            local category={}
            for _,entry in ipairs(rows) do
                if entry.group==group then category[#category+1]=entry end
            end
            if #category>0 then
                local head=groupHeadings[group]
                head:ClearAllPoints()
                head:SetPoint("TOPLEFT",ruleChild,"TOPLEFT",5,-y)
                head:SetPoint("TOPRIGHT",ruleChild,"TOPRIGHT",-5,-y)
                head:SetText(group:upper().."  ("..#category..")")
                y=y+23
                for i,entry in ipairs(category) do
                    local col=(i-1)%columns
                    local row=math.floor((i-1)/columns)
                    entry.badge:ClearAllPoints()
                    entry.badge:SetPoint("TOPLEFT",ruleChild,"TOPLEFT",1+col*(tileWidth+gap),-y-row*(tileHeight+gap))
                    entry.badge:SetSize(tileWidth,tileHeight)
                end
                y=y+math.ceil(#category/columns)*(tileHeight+gap)+6
            end
        end
        ruleChild:SetWidth(width)
        ruleChild:SetHeight(math.max(90,y+3))
    end
    ruleScroll:SetScript("OnSizeChanged",layoutRuleBadges)
    layoutRuleBadges()
    local ruleFooter=label(right,"Rule Observer is advisory. These settings do not block actions; incomplete events create review items, not certified violations. Older charter versions remain unchanged.","small")
    ruleFooter:SetPoint("BOTTOMLEFT",right,"BOTTOMLEFT",15,13)
    ruleFooter:SetPoint("BOTTOMRIGHT",right,"BOTTOMRIGHT",-15,13)
    ruleFooter:SetHeight(53)

    -- Chronicle: searchable, date-grouped timeline; local read-only presentation.
    local chronicle=CreateFrame("Frame",nil,area)
    chronicle:SetAllPoints(area)
    local chronicleLeft=UI:Card(chronicle)
    chronicleLeft:SetPoint("TOPLEFT",chronicle,"TOPLEFT",0,0)
    chronicleLeft:SetPoint("BOTTOMLEFT",chronicle,"BOTTOMLEFT",0,0)
    chronicleLeft:SetWidth(475)
    section(chronicleLeft,"Expedition Chronicle")
    local archiveToggle=quiet(chronicleLeft,"Previous Runs",function()
        local exp=AF:GetExpedition()
        local size=exp and exp.charterArchive and #exp.charterArchive or 0
        archiveIndex=(archiveIndex+1)%(size+1)
        selectedEvent=nil
        chronicleCharacter="all"
        page:Refresh()
    end)
    archiveToggle:SetPoint("TOPRIGHT",chronicleLeft,"TOPRIGHT",-13,-9)
    archiveToggle:SetSize(135,26)
    local searchBox=UI:Input(chronicleLeft,220)
    chronicleSearchBox=searchBox
    searchBox:SetPoint("TOPLEFT",chronicleLeft,"TOPLEFT",20,-47)
    searchBox:SetPoint("TOPRIGHT",chronicleLeft,"TOPRIGHT",-17,-47)
    if searchBox.SetText then searchBox:SetText("") end
    if searchBox.SetMaxLetters then searchBox:SetMaxLetters(75) end
    local searchCaption=label(chronicleLeft,"Search events, adventurers, rules, or dates","small",P.ink)
    searchCaption:SetPoint("TOPLEFT",chronicleLeft,"TOPLEFT",19,-76)
    searchCaption:SetPoint("TOPRIGHT",chronicleLeft,"TOPRIGHT",-18,-76)
    searchCaption:SetHeight(16)
    -- Four genuine single-choice flyouts, implemented with basic Frames and the
    -- native ScrollFrame template rather than Retail-only dropdown APIs.
    -- A shared flyout ensures selecting a second filter closes the first.
    local filterMenu=CreateFrame("Frame",nil,area) -- shared by Chronicle and Milestones; Chronicle is hidden while milestones are active
    UI:Background(filterMenu,P.leather,true)
    filterMenu:SetFrameStrata("DIALOG")
    filterMenu:SetFrameLevel(math.max(35,(chronicle:GetFrameLevel() or 1)+28))
    filterMenu:Hide()
    local menuScroll=CreateFrame("ScrollFrame",nil,filterMenu,"UIPanelScrollFrameTemplate")
    menuScroll:SetPoint("TOPLEFT",filterMenu,"TOPLEFT",7,-7)
    menuScroll:SetPoint("BOTTOMRIGHT",filterMenu,"BOTTOMRIGHT",-28,7)
    local menuChild=CreateFrame("Frame",nil,menuScroll)
    menuChild:SetSize(155,1)
    menuScroll:SetScrollChild(menuChild)
    UI:InsetWorkshopScrollBar(menuScroll)
    menuScroll:EnableMouseWheel(true)
    menuScroll:SetScript("OnMouseWheel",function(self,delta)
        local remaining=math.max(0,(menuChild:GetHeight() or 0)-(self:GetHeight() or 0))
        self:SetVerticalScroll(math.max(0,math.min(remaining,(self:GetVerticalScroll() or 0)-delta*32)))
    end)
    local menuRows={}
    local function hideFilters()
        filterMenu:Hide()
        filterMenu.anchor=nil
    end
    local function openFilter(anchor,options,current,assign)
        if filterMenu:IsShown() and filterMenu.anchor==anchor then
            hideFilters()
            return
        end
        hideFilters()
        local width=math.max(174,math.floor(anchor:GetWidth() or 180))
        local visible=math.min(#options,9)
        filterMenu:SetSize(width,14+visible*25)
        filterMenu:ClearAllPoints()
        filterMenu:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-2)
        filterMenu.anchor=anchor
        menuChild:SetSize(width-38,math.max(1,#options*25+2))
        for i,entry in ipairs(options) do
            local row=menuRows[i]
            if not row then
                row=quiet(menuChild,"")
                row:SetHeight(24)
                row:SetPoint("TOPLEFT",menuChild,"TOPLEFT",0,-(i-1)*25)
                row:SetPoint("TOPRIGHT",menuChild,"TOPRIGHT",0,-(i-1)*25)
                menuRows[i]=row
            end
            row.label:SetText(entry.label)
            row.label:SetTextColor(unpack(entry.value==current and P.gold or P.pale))
            row:SetScript("OnClick",function()
                hideFilters()
                assign(entry.value)
                selectedEvent=nil
                page:Refresh()
            end)
            row:Show()
        end
        for i=#options+1,#menuRows do menuRows[i]:Hide() end
        local bar=UI:ListScrollBar(menuScroll)
        if bar then bar:SetShown(#options>visible) end
        menuScroll:SetVerticalScroll(0)
        filterMenu:Show()
    end
    chronicle:SetScript("OnHide",hideFilters)
    milestonePage:HookScript("OnHide",hideFilters)
    local categoryOptions={{value="all",label="All Activities"},
        {value="charter",label="Charter"},{value="trade",label="Trading"},
        {value="auction",label="Auction House"},{value="mail",label="Mail"},
        {value="storage",label="Storage"},{value="group",label="Cooperation"},
        {value="vendor",label="NPC Economy"},{value="review",label="Rule Review"},
        {value="milestone",label="Milestones"},
        {value="other",label="Other"}}
    local statusOptions={{value="all",label="All Statuses"},
        {value="observed",label="Observed"},{value="review",label="Needs Review"},
        {value="reviewed",label="Reviewed"},{value="declared",label="Declared"},
        {value="charter",label="Charter Record"}}
    local dateOptions={{value="all",label="All Dates"},
        {value=0,label="Today"},{value=7,label="Last 7 Days"},
        {value=30,label="Last 30 Days"}}
    local milestoneCategoryOptions={{value="all",label="All Categories"},
        {value="Gathering",label="Gathering"},{value="Crafting",label="Crafting"},
        {value="Professions",label="Professions"},{value="Exploration",label="Exploration"},
        {value="Questing",label="Questing"},{value="Character",label="Character"},
        {value="Roster",label="Roster"},{value="Dungeons",label="Dungeons"},
        {value="Rare Feats",label="Rare Feats"}}
    local milestoneStatusOptions={{value="all",label="All States"},
        {value="pending",label="Pending"},{value="recorded",label="Recorded"}}
    milestoneFilterCategory:SetScript("OnClick",function(self)
        openFilter(self,milestoneCategoryOptions,milestoneCategory,function(value) milestoneCategory=value end)
    end)
    milestoneFilterStatus:SetScript("OnClick",function(self)
        openFilter(self,milestoneStatusOptions,milestoneStatus,function(value) milestoneStatus=value end)
    end)
    local filterCategory=quiet(chronicleLeft,"Activity: All",function(self)
        openFilter(self,categoryOptions,chronicleCategory,function(value)chronicleCategory=value end)
    end)
    local filterStatus=quiet(chronicleLeft,"Status: All",function(self)
        openFilter(self,statusOptions,chronicleStatus,function(value)chronicleStatus=value end)
    end)
    local filterCharacter=quiet(chronicleLeft,"Adventurer: All",function(self)
        local exp=AF:GetExpedition()
        local archives=exp and exp.charterArchive or {}
        local source=archiveIndex==0 and AF:GetExpeditionCharter() or archives[#archives-archiveIndex+1]
        local names,seen={},{}
        for _,e in ipairs(source and source.events or {}) do
            local n=e.character or "Expedition"
            if not seen[n] then names[#names+1]=n;seen[n]=true end
        end
        table.sort(names)
        local options={{value="all",label="All Adventurers"}}
        for _,name in ipairs(names) do options[#options+1]={value=name,label=name} end
        openFilter(self,options,chronicleCharacter,function(value)chronicleCharacter=value end)
    end)
    local filterDate=quiet(chronicleLeft,"Dates: All",function(self)
        openFilter(self,dateOptions,chronicleDays==nil and "all" or chronicleDays,function(value)
            if value=="all" then chronicleDays=nil else chronicleDays=value end
        end)
    end)
    -- Triangle glyph sits at the far edge while labels stay compact.
    for _,button in ipairs({filterCategory,filterStatus,filterCharacter,filterDate,milestoneFilterCategory,milestoneFilterStatus}) do
        button.label:ClearAllPoints()
        button.label:SetPoint("TOPLEFT",button,"TOPLEFT",4,0)
        button.label:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-19,0)
        local arrow=UI:Text(button,"small",P.gold,"RIGHT")
        arrow:SetPoint("TOPRIGHT",button,"TOPRIGHT",-8,-2)
        arrow:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-8,2)
        arrow:SetWidth(12)
        arrow:SetText("v") -- ASCII fallback caret; avoids missing-glyph square boxes on some WoW client fonts.
    end
    for _,btn in ipairs({filterCategory,filterStatus,filterCharacter,filterDate}) do btn:SetHeight(27) end
    filterCategory:SetPoint("TOPLEFT",chronicleLeft,"TOPLEFT",13,-96)
    filterCategory:SetPoint("TOPRIGHT",chronicleLeft,"TOP",-4,-96)
    filterStatus:SetPoint("TOPLEFT",chronicleLeft,"TOP",4,-96)
    filterStatus:SetPoint("TOPRIGHT",chronicleLeft,"TOPRIGHT",-13,-96)
    filterCharacter:SetPoint("TOPLEFT",chronicleLeft,"TOPLEFT",13,-126)
    filterCharacter:SetPoint("TOPRIGHT",chronicleLeft,"TOP",-4,-126)
    filterDate:SetPoint("TOPLEFT",chronicleLeft,"TOP",4,-126)
    filterDate:SetPoint("TOPRIGHT",chronicleLeft,"TOPRIGHT",-13,-126)
    local eventList=UI:List(chronicleLeft,43)
    eventList:SetPoint("TOPLEFT",chronicleLeft,"TOPLEFT",13,-160)
    eventList:SetPoint("BOTTOMRIGHT",chronicleLeft,"BOTTOMRIGHT",-29,41)
    UI:InsetWorkshopScrollBar(eventList)
    local countLabel=label(chronicleLeft,"", "small",P.ink)
    countLabel:SetPoint("BOTTOMLEFT",chronicleLeft,"BOTTOMLEFT",16,16)
    countLabel:SetPoint("BOTTOMRIGHT",chronicleLeft,"BOTTOMRIGHT",-15,16)
    countLabel:SetHeight(19)
    local chronicleRight=UI:Card(chronicle)
    chronicleRight:SetPoint("TOPLEFT",chronicleLeft,"TOPRIGHT",9,0)
    chronicleRight:SetPoint("BOTTOMRIGHT",chronicle,"BOTTOMRIGHT",0,0)
    section(chronicleRight,"Recorded Event")
    local eventHeading=label(chronicleRight,"Select an event","title",P.ink)
    eventHeading:SetPoint("TOPLEFT",chronicleRight,"TOPLEFT",17,-48)
    eventHeading:SetPoint("TOPRIGHT",chronicleRight,"TOPRIGHT",-16,-48)
    eventHeading:SetHeight(29)
    local eventMeta=label(chronicleRight,"", "small",P.ink)
    eventMeta:SetPoint("TOPLEFT",chronicleRight,"TOPLEFT",17,-83)
    eventMeta:SetPoint("TOPRIGHT",chronicleRight,"TOPRIGHT",-17,-83)
    eventMeta:SetHeight(44)
    local detailsScroll=CreateFrame("ScrollFrame",nil,chronicleRight,"UIPanelScrollFrameTemplate")
    detailsScroll:SetPoint("TOPLEFT",chronicleRight,"TOPLEFT",15,-139)
    detailsScroll:SetPoint("BOTTOMRIGHT",chronicleRight,"BOTTOMRIGHT",-30,112)
    -- The native scrollbar sits 6 units beyond the ScrollFrame edge. Match
    -- the inset used by the Chronicle list and other Foundry panes.
    UI:InsetWorkshopScrollBar(detailsScroll)
    local detailsChild=CreateFrame("Frame",nil,detailsScroll)
    detailsChild:SetSize(240,200)
    detailsScroll:SetScrollChild(detailsChild)
    local eventText=label(detailsChild,"",nil,P.ink)
    eventText:SetPoint("TOPLEFT",detailsChild,"TOPLEFT",0,0)
    eventText:SetJustifyH("LEFT")
    eventText:SetWordWrap(true)
    local function resizeEventDetail()
        local w=detailsScroll:GetWidth() or 300
        if w<80 then return end
        detailsChild:SetWidth(w-6)
        eventText:SetWidth(w-12)
        local measured=eventText.GetStringHeight and eventText:GetStringHeight() or 320
        local h=math.max(140,math.ceil(measured)+30)
        eventText:SetHeight(h)
        detailsChild:SetHeight(h+3)
        local bar=UI:ListScrollBar(detailsScroll)
        if bar then bar:SetShown(h+3>(detailsScroll:GetHeight() or 0)+3) end
    end
    detailsScroll:SetScript("OnSizeChanged",resizeEventDetail)
    local detailToggle=quiet(chronicleRight,"Technical Details: Hidden",function()
        showTechnical=not showTechnical
        page:Refresh()
    end)
    detailToggle:SetPoint("BOTTOMLEFT",chronicleRight,"BOTTOMLEFT",15,75)
    detailToggle:SetSize(176,26)
    local reviewLink=quiet(chronicleRight,"Open Rule Review",function()
        if archiveIndex>0 then return end
        local c=AF:GetExpeditionCharter()
        if c and selectedEvent then
            for _,e in ipairs(c.events or {}) do
                if e.id==selectedEvent then selectedReview=e.reviewId;break end
            end
        end
        selectedTab="Rule Review"
        page:Refresh()
    end)
    reviewLink:SetPoint("BOTTOMRIGHT",chronicleRight,"BOTTOMRIGHT",-16,75)
    reviewLink:SetSize(168,26)
    local historyHint=label(chronicleRight,"Local history is editable outside WoW. Missing records do not prove compliance.","small")
    historyHint:SetPoint("BOTTOMLEFT",chronicleRight,"BOTTOMLEFT",17,15)
    historyHint:SetPoint("BOTTOMRIGHT",chronicleRight,"BOTTOMRIGHT",-17,15)
    historyHint:SetHeight(48)
    local function sizeChroniclePanels()
        local w=chronicle:GetWidth() or 0
        if w<200 then return end
        chronicleLeft:SetWidth(math.max(385,math.min(490,math.floor(w*.39))))
        resizeEventDetail()
    end
    chronicle:SetScript("OnSizeChanged",sizeChroniclePanels)
    searchBox:SetScript("OnTextChanged",function(self)
        local value=self:GetText() or ""
        if value~=chronicleSearch then
            chronicleSearch=value
            selectedEvent=nil
            if selectedTab=="Chronicle" then page:Refresh() end
        end
    end)

    local review=CreateFrame("Frame",nil,area)
    review:SetAllPoints(area)
    local reviewLeft=UI:Card(review)
    reviewLeft:SetPoint("TOPLEFT",review,"TOPLEFT",0,0)
    reviewLeft:SetPoint("BOTTOMLEFT",review,"BOTTOMLEFT",0,0)
    reviewLeft:SetWidth(380)
    section(reviewLeft,"Activity Declarations")
    local reviewHint=label(reviewLeft,"Client-event observations can flag uncertain actions for review. You can also make a manual declaration. Neither is proof of full compliance.","small")
    reviewHint:SetPoint("TOPLEFT",reviewLeft,"TOPLEFT",15,-49)
    reviewHint:SetPoint("TOPRIGHT",reviewLeft,"TOPRIGHT",-15,-49)
    reviewHint:SetHeight(85)
    local kinds={"note","trade","mail","auction","storage","group","vendor","assistance","other"}
    local kindButton=quiet(reviewLeft,"Category: Note",function()
        local index=1
        for i,v in ipairs(kinds) do if reviewKind==v then index=i;break end end
        reviewKind=kinds[(index % #kinds)+1]
        page:Refresh()
    end)
    kindButton:SetPoint("TOPLEFT",reviewLeft,"TOPLEFT",16,-141)
    kindButton:SetPoint("TOPRIGHT",reviewLeft,"TOPRIGHT",-16,-141)
    local levelButton=quiet(reviewLeft,"Evidence: Player Declared",function()
        local index=1
        for i,v in ipairs(reviewLevels) do if reviewLevel==v then index=i;break end end
        reviewLevel=reviewLevels[(index%#reviewLevels)+1]
        page:Refresh()
    end)
    levelButton:SetPoint("TOPLEFT",reviewLeft,"TOPLEFT",16,-180)
    levelButton:SetPoint("TOPRIGHT",reviewLeft,"TOPRIGHT",-16,-180)
    local explanationLabel=label(reviewLeft,"Explanation", "small")
    explanationLabel:SetPoint("TOPLEFT",reviewLeft,"TOPLEFT",16,-224)
    explanationLabel:SetSize(220,20)
    local explanation=UI:Input(reviewLeft,225)
    explanation:SetPoint("TOPLEFT",reviewLeft,"TOPLEFT",16,-248)
    explanation:SetPoint("TOPRIGHT",reviewLeft,"TOPRIGHT",-16,-248)
    local record=quiet(reviewLeft,"Add to Chronicle",function()
        local ok,why=AF:RecordCharterReview(reviewKind,explanation:GetText(),reviewLevel,AF:GetCurrentKey())
        if not ok then safeMessage(why)
        else explanation:SetText("");page:Refresh() end
    end)
    record:SetPoint("TOPLEFT",reviewLeft,"TOPLEFT",16,-290)
    record:SetPoint("TOPRIGHT",reviewLeft,"TOPRIGHT",-16,-290)
    local notice=label(reviewLeft,"", "small")
    notice:SetPoint("BOTTOMLEFT",reviewLeft,"BOTTOMLEFT",16,15)
    notice:SetPoint("BOTTOMRIGHT",reviewLeft,"BOTTOMRIGHT",-16,15)
    notice:SetHeight(106)
    UI.charterNotice=notice
    local warningToggle=quiet(reviewLeft,"Chat Warnings: ON",function()
        if AF.SetCharterAlertEnabled then
            AF:SetCharterAlertEnabled("chat",not AF:CharterAlertEnabled("chat"))
        end
        page:Refresh()
    end)
    warningToggle:SetPoint("BOTTOMLEFT",reviewLeft,"BOTTOMLEFT",16,133)
    warningToggle:SetPoint("BOTTOMRIGHT",reviewLeft,"BOTTOMRIGHT",-16,133)
    local toastToggle=quiet(reviewLeft,"Screen Toasts: ON",function()
        if AF.SetCharterAlertEnabled then
            AF:SetCharterAlertEnabled("toast",not AF:CharterAlertEnabled("toast"))
        end
        page:Refresh()
    end)
    toastToggle:SetPoint("BOTTOMLEFT",reviewLeft,"BOTTOMLEFT",16,165)
    toastToggle:SetPoint("BOTTOMRIGHT",reviewLeft,"BOTTOMRIGHT",-16,165)
    local gateToggle=quiet(reviewLeft,"Auction Buy Reminder: ON",function()
        if AF.SetCharterAlertEnabled then
            AF:SetCharterAlertEnabled("gate",not AF:CharterAlertEnabled("gate"))
        end
        page:Refresh()
    end)
    gateToggle:SetPoint("BOTTOMLEFT",reviewLeft,"BOTTOMLEFT",16,197)
    gateToggle:SetPoint("BOTTOMRIGHT",reviewLeft,"BOTTOMRIGHT",-16,197)
    local reviewRight=UI:Card(review)
    reviewRight:SetPoint("TOPLEFT",reviewLeft,"TOPRIGHT",9,0)
    reviewRight:SetPoint("BOTTOMRIGHT",review,"BOTTOMRIGHT",0,0)
    section(reviewRight,"Review Ledger")
    local reviewList=UI:List(reviewRight,43)
    reviewList:SetPoint("TOPLEFT",reviewRight,"TOPLEFT",13,-45)
    reviewList:SetPoint("BOTTOMRIGHT",reviewRight,"BOTTOMRIGHT",-29,158)
    UI:InsetWorkshopScrollBar(reviewList)
    local reviewDetail=label(reviewRight,"", "small")
    reviewDetail:SetPoint("BOTTOMLEFT",reviewRight,"BOTTOMLEFT",17,76)
    reviewDetail:SetPoint("BOTTOMRIGHT",reviewRight,"BOTTOMRIGHT",-15,76)
    reviewDetail:SetHeight(72)
    local resolve=quiet(reviewRight,"Mark Reviewed (Retain Record)",function()
        if not selectedReview then return end
        local ok,why=AF:ResolveCharterReview(selectedReview,"Reviewed by player; no independent verification.")
        if not ok then safeMessage(why) end
        page:Refresh()
    end)
    resolve:SetPoint("BOTTOMLEFT",reviewRight,"BOTTOMLEFT",17,22)
    resolve:SetPoint("BOTTOMRIGHT",reviewRight,"BOTTOMRIGHT",-17,22)
    local reviewChronicleLink=quiet(reviewRight,"View Related Chronicle Entry",function()
        local c=AF:GetExpeditionCharter()
        if not c then return end
        for _,r in ipairs(c.reviews or {}) do
            if r.id==selectedReview and r.eventId then
                selectedEvent=r.eventId
                archiveIndex=0
                chronicleCategory="all";chronicleStatus="all";chronicleCharacter="all";chronicleDays=nil
                chronicleSearch=""
                searchBox:SetText("")
                selectedTab="Chronicle"
                showTechnical=false
                page:Refresh()
                return
            end
        end
    end)
    reviewChronicleLink:SetPoint("BOTTOMLEFT",reviewRight,"BOTTOMLEFT",17,54)
    reviewChronicleLink:SetPoint("BOTTOMRIGHT",reviewRight,"BOTTOMRIGHT",-17,54)

    local function refreshOverview(c)
        local members,nonmembers=AF:GetExpeditionMembers()
        if not selectedKey and members[1] then selectedKey=members[1].key end
        local rows={}
        for _,member in ipairs(members) do
            rows[#rows+1]={key=member.key,icon="Interface\\Icons\\INV_Misc_Key_14",
                label=(member.name or "Unknown").."  Lv "..(member.level or "?").."  [Enrolled]"}
        end
        for _,member in ipairs(nonmembers) do
            rows[#rows+1]={key=member.key,icon="Interface\\Icons\\INV_Misc_GroupLooking",
                label=(member.name or "Unknown").."  Lv "..(member.level or "?").."  [Independent]"}
        end
        UI:FillList(rosterList,rows,function(e)selectedKey=e.key;page:Refresh()end,selectedKey)
        local chosen=selectedKey and AF.db.characters[selectedKey]
        memberHint:SetText(chosen and ((chosen.name or "Unknown").."  -  "..(AF:IsExpeditionMember(selectedKey) and "Enrolled" or "Independent")) or "No registered characters yet")
        manage.label:SetText(selectedKey and (AF:IsExpeditionMember(selectedKey) and "Leave Expedition" or "Join Expedition") or "Select an Adventurer")
        charterHeading:SetText(AF.CHARTER_PRESET_NAMES[c.preset] or "Expedition")
        local status=(c.state=="draft" and "Not activated" or c.state=="active" and "Charter active" or "Charter ended")
        charterDesc:SetText(status.."  |  Version "..c.version.."  |  Began: "..when(c.startedAt).."\n\nEnrollment and current rule scope are separate. Only activity after activation is part of this journal's observation period.")
        for i,id in ipairs(importantRules) do
            for _,def in ipairs(AF.CHARTER_RULE_DEFS) do
                if def.id==id then rulePreview[i]:SetText((c.rules[id] and "[Allowed] " or "[Restricted] ")..def.label);break end
            end
        end
        local capability=AF.GetCharterObserverCapability and AF:GetCharterObserverCapability() or {supported={}}
        statement:SetText("LOCAL RECORD ONLY  |  Observer: "..#capability.supported.." registered event types\nEvent availability does not prove outcomes. Time offline, before enrollment, and unexposed actions remain unobserved.")
    end
    local function refreshRulebook(c)
        local draft=c.draft
        local effective=draft and draft.rules or c.rules
        draftHint:SetText(draft and "Editable draft. Changes have no effect until activated or published.\n\nRules below specify permissions, not guaranteed client restrictions."
            or c.state=="active" and "Active charter is read-only. Choose Edit Charter Rules to create a new version."
            or "This run has ended. Start a new charter to set rules again.")
        for _,entry in ipairs(presetButtons) do
            entry.button:SetShown(draft~=nil)
            entry.button.label:SetText((draft and draft.preset==entry.id and "[Selected] " or "")..AF.CHARTER_PRESET_NAMES[entry.id])
        end
        revision:SetShown(c.state=="active" and draft==nil)
        publish:SetShown(draft~=nil)
        publish.label:SetText(c.state=="draft" and "Activate Charter" or "Publish New Version")
        discard:SetShown(draft~=nil and c.state=="active")
        endRun:SetShown(c.state~="draft")
        endRun.label:SetText(c.state=="ended" and "Prepare New Charter" or "End Active Charter")
        ruleHeading:SetText((draft and "EDITING DRAFT  -  " or "CURRENT RULES  -  ")..
            (AF.CHARTER_PRESET_NAMES[draft and draft.preset or c.preset] or "Custom")..
            "\nHover for rule details. "..(draft and "Click a badge to change the draft." or "Rules are read-only until you edit the charter."))
        for _,entry in ipairs(rows) do
            local permitted=effective[entry.id]
            local rgb=permitted==nil and unknownColor or (permitted and allowColor or denyColor)
            entry.emblem:SetTexture(permitted==nil and "Interface\\Icons\\INV_Misc_QuestionMark" or (permitted and allowedIcon or restrictedIcon))
            entry.stripe:SetColorTexture(rgb[1],rgb[2],rgb[3],.9)
            entry.state:SetText(permitted==nil and "NOT IN CHARTER" or (permitted and "ALLOWED" or "RESTRICTED"))
            entry.state:SetTextColor(rgb[1],rgb[2],rgb[3],1)
            entry.badge:SetAlpha(1)
        end
        layoutRuleBadges()
    end
    local function refreshChronicle(c)
        local exp=AF:GetExpedition()
        local archives=exp and exp.charterArchive or {}
        if archiveIndex>#archives then archiveIndex=0;selectedEvent=nil end
        archiveToggle:SetShown(#archives>0)
        archiveToggle.label:SetText(archiveIndex==0 and "Previous Runs" or ("Archived Run "..archiveIndex))
        local source=archiveIndex==0 and c or archives[#archives-archiveIndex+1]
        if not source then return end
        local filters={search=chronicleSearch,category=chronicleCategory,status=chronicleStatus,
            character=chronicleCharacter,days=chronicleDays}
        local filtered=AF:FilterCharterChronicle(source.events or {},source,filters)
        local rows,lastDay={},nil
        local found=false
        local chosen,chosenInfo
        for _,item in ipairs(filtered) do
            local e,info=item.event,item.info
            local day=type(date)=="function" and type(e.timestamp)=="number" and date("%A, %b %d, %Y",e.timestamp) or "Date unavailable"
            if day~=lastDay then
                rows[#rows+1]={key="day:"..day,header=true,label=day}
                lastDay=day
            end
            local hhmm=type(date)=="function" and type(e.timestamp)=="number" and date("%H:%M",e.timestamp) or "--:--"
            rows[#rows+1]={key=e.id,source=e,info=info,icon=info.icon,
                label=hhmm.."  "..info.title.."  |  "..(e.character or "Expedition")}
            if selectedEvent==e.id then found=true;chosen=e;chosenInfo=info end
        end
        if not found then
            chosen=filtered[1] and filtered[1].event or nil
            chosenInfo=filtered[1] and filtered[1].info or nil
            selectedEvent=chosen and chosen.id or nil
        end
        UI:FillList(eventList,rows,function(entry)
            if entry.header then return end
            selectedEvent=entry.key
            showTechnical=false
            page:Refresh()
        end,selectedEvent)
        -- Muted section dividers and alert accents retain the native Foundry row style.
        for i,entry in ipairs(rows) do
            local row=eventList.rows and eventList.rows[i]
            if row and row.label and row.label.SetTextColor then
                if entry.header then row.label:SetTextColor(.46,.30,.13,1)
                elseif entry.info and entry.info.status=="review" then row.label:SetTextColor(.66,.23,.12,1)
                elseif entry.info and entry.info.status=="reviewed" then row.label:SetTextColor(.24,.43,.21,1)
                end
            end
        end
        countLabel:SetText(tostring(#filtered).." of "..tostring(#(source.events or {})).." events"..
            (archiveIndex>0 and "  |  Archived, read-only" or ""))
        local categories=AF.CHARTER_CHRONICLE_CATEGORIES or {}
        filterCategory.label:SetText("Activity: "..(chronicleCategory=="all" and "All" or (categories[chronicleCategory] or "Other")))
        local statuses={all="All",observed="Observed",review="Needs Review",reviewed="Reviewed",declared="Declared",charter="Charter"}
        filterStatus.label:SetText("Status: "..(statuses[chronicleStatus] or "All"))
        filterCharacter.label:SetText(chronicleCharacter=="all" and "Adventurer: All" or chronicleCharacter)
        local dates={[0]="Today",[7]="Last 7 Days",[30]="Last 30 Days"}
        filterDate.label:SetText("Dates: "..(dates[chronicleDays] or "All"))
        if not chosen then
            eventHeading:SetText("No Matching Events")
            eventMeta:SetText("Try adjusting the search or filters.")
            eventText:SetText("The saved Chronicle has not been changed. Filters only affect the visible timeline.")
            detailToggle:Hide();reviewLink:Hide()
        else
            eventHeading:SetText(chosenInfo.title)
            local statusText={observed="Observed Activity",review="Needs Review",reviewed="Player Reviewed",declared="Player Declared",charter="Charter Record"}
            eventMeta:SetText(when(chosen.timestamp).."   |   "..(chosen.character or "Expedition").."\n"..
                chosenInfo.categoryLabel.."   |   "..(statusText[chosenInfo.status] or "Local Record").."   |   "..chosenInfo.evidence)
            local textLines={chosenInfo.summary,"","CHARTER AT THE TIME OF THIS EVENT",
                "Version "..tostring(chosen.version or "unknown")..(chosenInfo.version and ("  |  "..(AF.CHARTER_PRESET_NAMES[chosenInfo.version.preset] or "Custom")) or "  |  Historical snapshot unavailable")}
            if #chosenInfo.ruleLines>0 then
                textLines[#textLines+1]=""
                for _,line in ipairs(chosenInfo.ruleLines) do textLines[#textLines+1]=line end
            else
                textLines[#textLines+1]="No specific rule was linked to this event."
            end
            if chosenInfo.review then
                local r=chosenInfo.review
                textLines[#textLines+1]=""
                textLines[#textLines+1]="RELATED RULE REVIEW"
                textLines[#textLines+1]=(r.status=="open" and "Needs Review" or (r.status=="reviewed" and "Reviewed by player" or "Player declaration"))
                textLines[#textLines+1]=r.note or r.detail or ""
                if r.resolution and r.resolution~="" then textLines[#textLines+1]="Player note: "..r.resolution end
            end
            if showTechnical then
                textLines[#textLines+1]=""
                textLines[#textLines+1]="TECHNICAL DETAILS (LOCAL RECORD)"
                textLines[#textLines+1]="Event ID: "..tostring(chosen.id or "unknown")
                textLines[#textLines+1]="Raw event: "..tostring(chosen.kind or "unknown")
                textLines[#textLines+1]="Source callback: "..tostring(chosen.sourceEvent or "not recorded")
                textLines[#textLines+1]="Evidence: "..tostring(chosen.evidence or "local_record")
                textLines[#textLines+1]="Outcome: "..tostring(chosen.outcome or "not independently established")
                textLines[#textLines+1]="Original note: "..tostring(chosen.detail or "")
            end
            eventText:SetText(table.concat(textLines,"\n"))
            detailToggle:Show()
            detailToggle.label:SetText(showTechnical and "Technical Details: Shown" or "Technical Details: Hidden")
            reviewLink:SetShown(archiveIndex==0 and (chosenInfo.review~=nil or chosenInfo.status=="review" or (chosen.kind or ""):find("^review_")~=nil))
            reviewLink.label:SetText(chosenInfo.review and "Open Linked Review" or "Open Rule Review")
        end
        resizeEventDetail()
        if detailsScroll.SetVerticalScroll then detailsScroll:SetVerticalScroll(0) end
    end
    local function refreshReview(c)
        local capability=AF.GetCharterObserverCapability and AF:GetCharterObserverCapability() or {supported={},unsupported={}}
        warningToggle.label:SetText("Chat Warnings: "..(AF.CharterAlertEnabled and AF:CharterAlertEnabled("chat") and "ON" or "OFF"))
        toastToggle.label:SetText("Screen Toasts: "..(AF.CharterAlertEnabled and AF:CharterAlertEnabled("toast") and "ON" or "OFF"))
        gateToggle.label:SetText("Auction Buy Reminder: "..(AF.CharterAlertEnabled and AF:CharterAlertEnabled("gate") and "ON" or "OFF"))
        warningToggle:SetShown(c.state=="active")
        toastToggle:SetShown(c.state=="active")
        gateToggle:SetShown(c.state=="active")
        if not notice.overrideNote then
            notice:SetText("Observer: "..#capability.supported.." event types registered; "..#capability.unsupported.." unsupported.\nOnly enrolled characters under an active charter are observed. Review items are never automatic convictions.")
        end
        kindButton.label:SetText("Category: "..reviewKind)
        levelButton.label:SetText("Declaration: "..(reviewLevel=="review" and "Needs Review" or reviewLevel=="conflict" and "Self-Reported Conflict" or "Journal Note"))
        local entries={}
        for i=#c.reviews,1,-1 do
            local item=c.reviews[i]
            entries[#entries+1]={key=item.id,source=item,label=when(item.timestamp).."  |  "..(item.status=="open" and "Needs Review" or item.status=="reviewed" and "Reviewed" or item.level=="conflict" and "Declared Conflict" or "Player Note").."  |  "..item.kind}
        end
        if not selectedReview and entries[1] then selectedReview=entries[1].key end
        UI:FillList(reviewList,entries,function(entry)selectedReview=entry.key;page:Refresh()end,selectedReview)
        local r
        for _,entry in ipairs(entries) do if entry.key==selectedReview then r=entry.source;break end end
        reviewDetail:SetText(r and ((r.level or "declared").."  |  "..(r.evidence or "player_declared").."\n"..(r.detail or ""))
            or "No manual or automatically flagged reviews. The Chronicle includes routine observed activity, but none of it proves complete compliance.")
        resolve:SetShown(r and r.level=="review" and r.status=="open" or false)
        reviewChronicleLink:SetShown(r and r.eventId~=nil or false)
    end
    -- Allow the first-login charter flow to lead directly to its Rulebook.
    function page:SelectCharterTab(tab)
        if tab~="Overview" and tab~="Milestones" and tab~="Rulebook" and tab~="Chronicle" and tab~="Rule Review" then return end
        selectedTab=tab
        self:Refresh()
    end

    function page:Refresh()
        local c=AF:GetExpeditionCharter()
        if not c then return end
        local members=AF:GetCharterMemberCount()
        local open,conflicts=AF:GetCharterReviewCounts()
        local stats={{"Status",c.state=="active" and "ACTIVE" or c.state=="ended" and "ENDED" or "NOT STARTED"},
            {"Ruleset",AF.CHARTER_PRESET_NAMES[c.preset]},
            {"Adventurers",tostring(members).." enrolled"},
            {"Rule Review",tostring(open).." open  |  "..tostring(conflicts).." declared conflicts"}}
        for i,row in ipairs(statusTexts) do row.head:SetText(stats[i][1]);row.value:SetText(stats[i][2]) end
        for _,b in ipairs(tabs) do
            local selected=selectedTab==b.name
            b.button.label:SetText(selected and ("[ "..b.name.." ]") or b.name)
            if b.button.SetSelected then b.button:SetSelected(selected) end
        end
        overview:SetShown(selectedTab=="Overview")
        milestonePage:SetShown(selectedTab=="Milestones")
        rulebook:SetShown(selectedTab=="Rulebook")
        chronicle:SetShown(selectedTab=="Chronicle")
        review:SetShown(selectedTab=="Rule Review")
        if selectedTab=="Overview" then refreshOverview(c)
        elseif selectedTab=="Milestones" then refreshMilestones()
        elseif selectedTab=="Rulebook" then refreshRulebook(c)
        elseif selectedTab=="Chronicle" then refreshChronicle(c)
        else refreshReview(c) end
    end
end
