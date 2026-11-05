local _, AF = ...
local UI = AF.UI
local unpack = unpack or table.unpack

-- Shared sidebar navigation. These are views of existing pages, not
-- additional records or tracking engines. Each parent owns a persistent tree.
local NAVIGATION = {
    { name = "Overview",    icon = "Interface\\Icons\\INV_Misc_Book_11" },
    { name = "Characters",  icon = "Interface\\Icons\\INV_Misc_GroupLooking" },
    { name = "Workshop",    route = "Living Workshop", icon = "Interface\\Icons\\Trade_BlackSmithing" },
    { name = "Exploration", icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { name = "Collections", icon = "Interface\\Icons\\INV_Misc_Bag_10" },
    { name = "Self-Found",  icon = "Interface\\Icons\\INV_Misc_Key_14" },
    { name = "Goals",       icon = "Interface\\Icons\\INV_Misc_Note_04" },
    { name = "Notes",       icon = "Interface\\Icons\\INV_Scroll_03" },
    { name = "Settings",    icon = "Interface\\Icons\\INV_Gizmo_02" },
}
-- These are native WoW Interface/Icons texture paths. Keeping names centralized
-- makes it straightforward to replace an icon if Forever doesn't supply it.
local NAV_TREES = {
    Workshop = {
        setting = "workshopTreeExpanded",
        children = {
            {name="Professions", icon="Interface\\Icons\\Trade_BlackSmithing"},
            {name="Recipes", icon="Interface\\Icons\\INV_Misc_Book_09"},
            {name="Crafting Queue", icon="Interface\\Icons\\INV_Gizmo_02"},
            {name="Materials", icon="Interface\\Icons\\INV_Misc_Bag_10"},
        },
    },
    Collections = {
        setting = "collectionsTreeExpanded",
        children = {
            {name="Mounts", icon="Interface\\Icons\\Ability_Mount_RidingHorse"},
            {name="Companions", icon="Interface\\Icons\\Ability_Hunter_BeastCall"},
            {name="Toys", icon="Interface\\Icons\\INV_Misc_Dice_01"},
            {name="Transmog", icon="Interface\\Icons\\INV_Chest_Cloth_17"},
        },
    },
}
local COLLECTION_LABELS = {mounts="Mounts",pets="Companions",toys="Toys",transmog="Transmog"}
local COLLECTION_ROUTES = {Mounts="mounts",Companions="pets",Toys="toys",Transmog="transmog"}
local GOAL_ROUTES = {Active=true, Tracked=true, Completed=true}

local GOLD = {0.88, 0.67, 0.32}

local function Surface(frame, r, g, b, a, layer)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints(frame)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function NavLabel(parent, text, font, r, g, b)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetText(text)
    label:SetJustifyH("LEFT")
    label:SetTextColor(r or 0.82, g or 0.79, b or 0.72)
    return label
end

-- Only rearranges buttons; no page or tracker is re-created when refreshing.
function UI:RefreshNavigation()
    if not self.navFrame or not self.navListChild or not AF.db or not AF.db.settings then return end
    local settings = AF.db.settings
    local theme = self.ThemeTokens and self:ThemeTokens() or nil
    local accent = theme and theme.accent or GOLD
    local collapsed = settings.navigationCollapsed == true
    local selected = self.currentPage
    if selected == "Living Workshop" then selected = "Workshop" end
    local selectedChildren = {
        Workshop = settings.workshopTab or "Professions",
        Collections = COLLECTION_LABELS[AF.db.collections and AF.db.collections.settings and AF.db.collections.settings.category] or "Mounts",
    }
    self.navFrame:SetWidth(collapsed and 60 or 198)
    self.navHeading:SetShown(not collapsed)
    self.navToggleText:SetText(collapsed and ">" or "<")
    local y = 3
    self.navPositions = {}
    for entryIndex,entry in ipairs(NAVIGATION) do
        local button = self.tabs[entry.name]
        local enabled=entry.name~="Self-Found" or AF:IsModuleEnabled("selfFound")
        button:SetShown(enabled)
        if enabled then
        local active = selected == entry.name
        local height = collapsed and 44 or 40
        local step = collapsed and 46 or 45
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.navListChild, "TOPLEFT", 3, -y)
        button:SetSize(collapsed and 49 or 187, height)
        button.icon:ClearAllPoints()
        button.icon:SetPoint("LEFT", button, "LEFT", 12, 0)
        button.caption:SetShown(not collapsed)
        button.caption:ClearAllPoints()
        button.caption:SetPoint("LEFT", button, "LEFT", 47, 0)
        button.activeLine:SetShown(active and not collapsed)
        local navAccent=theme and theme.rainbow and
            (entryIndex%4==1 and theme.accent or entryIndex%4==2 and theme.accent2 or
            entryIndex%4==3 and theme.accent3 or theme.accent4) or accent
        button.activeLine:SetColorTexture(navAccent[1],navAccent[2],navAccent[3],.98)
        if theme then
            local c=active and theme.navActive or theme.nav
            button.bg:SetColorTexture(c[1],c[2],c[3],collapsed and .32 or (active and 1 or .83))
            local labelColor=active and theme.navSelectedText or theme.navText
            button.caption:SetTextColor(labelColor[1],labelColor[2],labelColor[3],1)
        end
        button.icon:SetVertexColor(active and 1 or .84, active and 1 or .84, active and 1 or .84)
        self.navPositions[entry.name] = {top=y, bottom=y+height}
        local tree=NAV_TREES[entry.name]
        local expanded=tree and settings[tree.setting] ~= false
        if button.treeToggle then
            button.treeToggle:SetShown(not collapsed)
            button.treeToggleText:SetText(expanded and "v" or ">")
        end
        local parentY=y
        y=y+step
        if tree then
            local lastChildMid
            local children=self.treeNavButtons[entry.name]
            for _,child in ipairs(tree.children) do
                local b=children[child.name]
                if expanded then
                    local isActive=active and selectedChildren[entry.name]==child.name
                    local childHeight=collapsed and 34 or 29
                    local left=collapsed and 15 or 40
                    b:Show()
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT",self.navListChild,"TOPLEFT",left,-y)
                    b:SetSize(collapsed and 37 or 151,childHeight)
                    b.icon:ClearAllPoints()
                    b.icon:SetPoint("LEFT",b,"LEFT",collapsed and 9 or 5,0)
                    b.caption:SetShown(not collapsed)
                    -- All color-first themes use their actual navigation palette;
                    -- never leave the old silver side-tab artwork visible.
                    if theme then
                        local c=isActive and theme.navActive or theme.nav
                        local labelColor=isActive and theme.navSelectedText or theme.navText
                        b.caption:SetTextColor(labelColor[1],labelColor[2],labelColor[3],1)
                        b.bg:SetColorTexture(c[1],c[2],c[3],isActive and .98 or .78)
                    end
                    b.icon:SetVertexColor(isActive and 1 or .83,isActive and 1 or .83,isActive and 1 or .83)
                    b.branch:ClearAllPoints()
                    b.branch:SetPoint("TOPLEFT",self.navListChild,"TOPLEFT",collapsed and 8 or 28,
                        -(y+math.floor(childHeight/2)))
                    b.branch:SetWidth(collapsed and 9 or 12)
                    b.branch:SetColorTexture(navAccent[1],navAccent[2],navAccent[3],.53)
                    b.branch:Show()
                    self.navPositions[entry.name.."/"..child.name]={top=y,bottom=y+childHeight}
                    lastChildMid=y+math.floor(childHeight/2)
                    y=y+(collapsed and 35 or 32)
                else
                    b:Hide()
                    b.branch:Hide()
                end
            end
            local line=self.navTreeLines[entry.name]
            if expanded and lastChildMid then
                local initialY=parentY+(collapsed and 37 or 34)
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT",self.navListChild,"TOPLEFT",collapsed and 8 or 28,-initialY)
                line:SetHeight(math.max(1,lastChildMid-initialY))
                line:SetColorTexture(navAccent[1],navAccent[2],navAccent[3],.53)
                line:Show()
            else
                line:Hide()
            end
        end
        end -- optional navigation module
    end
    self.navListChild:SetSize(collapsed and 54 or 194,y+5)
    self:ClampNavigationScroll()
end

function UI:ClampNavigationScroll()
    if not self.navScroller or not self.navListChild then return end
    local limit = math.max(0, self.navListChild:GetHeight() - self.navScroller:GetHeight())
    self.navScroller:SetVerticalScroll(math.min(limit, math.max(0,self.navScroller:GetVerticalScroll() or 0)))
end

function UI:RevealNavigationSelection()
    if not self.navPositions or not self.navScroller or not AF.db then return end
    local settings=AF.db.settings
    local name=self.currentPage
    local parent,child
    if name=="Living Workshop" then
        parent,child="Workshop",settings.workshopTab or "Professions"
    elseif name=="Collections" then
        parent,child="Collections",COLLECTION_LABELS[AF.db.collections and AF.db.collections.settings and AF.db.collections.settings.category] or "Mounts"
    end
    if parent then
        local tree=NAV_TREES[parent]
        name=(tree and settings[tree.setting] ~= false) and (parent.."/"..child) or parent
    end
    local pos=self.navPositions[name]
    if not pos then return end
    local top=self.navScroller:GetVerticalScroll() or 0
    local visible=self.navScroller:GetHeight()
    if visible<=0 then return end
    if pos.top<top then
        self.navScroller:SetVerticalScroll(math.max(0,pos.top-5))
    elseif pos.bottom>top+visible then
        self.navScroller:SetVerticalScroll(math.max(0,pos.bottom-visible+5))
    end
    self:ClampNavigationScroll()
end

function UI:SavePosition()
    if not self.frame or not AF.db then return end
    local x, y = self.frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if x and y and parentX and parentY then
        -- Offsets are in UI-parent coordinates and remain local SavedVariables.
        AF.db.settings.positionX = math.floor(x - parentX + 0.5)
        AF.db.settings.positionY = math.floor(y - parentY + 0.5)
    end
end

function UI:Initialize()
    if self.frame then return end
    local settings = AF.db.settings
    local frame = self:NewFrame("Frame", UIParent, "AzerothFoundryJournal")
    self.frame = frame
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetResizable(true)
    frame:SetClampedToScreen(true)
    frame:SetToplevel(true)
    -- An expanded sidebar needs additional width for original three-column pages.
    frame:SetSize(math.max(1120, tonumber(settings.width) or 1120),
        math.max(710, tonumber(settings.height) or 710))
    if frame.SetResizeBounds then frame:SetResizeBounds(1120, 710, 1640, 1040)
    elseif frame.SetMinResize then frame:SetMinResize(1120, 710) end
    frame:SetScale(settings.interfaceScale or 1)
    local x, y = tonumber(settings.positionX), tonumber(settings.positionY)
    frame:SetPoint("CENTER", UIParent, "CENTER", x or 0, y or 0)
    local shellTexture=self:Background(frame, self.palette.dark, true)
    if self.RegisterThemeTarget then
        self:RegisterThemeTarget(shellTexture,function(texture,tokens)
            texture:SetColorTexture(unpack(tokens.shell))
        end)
    end

    local header = self:NewFrame("Frame", frame)
    header:SetPoint("TOPLEFT", 7, -7)
    header:SetPoint("TOPRIGHT", -7, -7)
    header:SetHeight(69)
    local headerSurface=Surface(header, 0.105, 0.092, 0.078, .99)
    if self.RegisterThemeTarget then
        self:RegisterThemeTarget(headerSurface,function(texture,tokens)
            texture:SetColorTexture(unpack(tokens.header))
        end)
    end
    local rainbowStrips={}
    for i=1,5 do
        local strip=header:CreateTexture(nil,"OVERLAY")
        strip:SetPoint("BOTTOMLEFT",header,"BOTTOMLEFT",0,0)
        strip:SetPoint("BOTTOMRIGHT",header,"BOTTOMRIGHT",0,0)
        strip:SetHeight(3)
        rainbowStrips[i]=strip
    end
    local headerRule=header:CreateTexture(nil,"BORDER")
    headerRule:SetHeight(1)
    headerRule:SetPoint("BOTTOMLEFT", 0, 0)
    headerRule:SetPoint("BOTTOMRIGHT", 0, 0)
    headerRule:SetColorTexture(GOLD[1],GOLD[2],GOLD[3],.53)
    local function layoutRainbow()
        local width=header:GetWidth() or 0
        if width<1 then return end
        for i,strip in ipairs(rainbowStrips) do
            strip:ClearAllPoints()
            strip:SetPoint("BOTTOMLEFT",header,"BOTTOMLEFT",(i-1)*width/5,0)
            strip:SetSize(width/5+1,3)
        end
    end
    header:SetScript("OnSizeChanged",layoutRainbow)
    if self.RegisterThemeTarget then
        self:RegisterThemeTarget(header,function(_,t)
            for i,strip in ipairs(rainbowStrips) do
                strip:SetShown(t.rainbow)
                local colors={t.accent,t.accent3,t.accent4,t.accent2,t.divider}
                local c=colors[i];strip:SetColorTexture(c[1],c[2],c[3],1)
            end
            layoutRainbow()
        end)
    end
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        UI:SavePosition()
    end)
    local medallion=CreateFrame("Frame",nil,header)
    medallion:SetSize(48,48)
    medallion:SetPoint("LEFT",header,"LEFT",11,0)
    Surface(medallion,.075,.069,.058,.94)
    self:FoundryQuestBorder(medallion,{cap=13,alpha=.88,outset=1})
    local innerGlow = medallion:CreateTexture(nil,"ARTWORK")
    innerGlow:SetPoint("TOPLEFT",medallion,"TOPLEFT",5,-5)
    innerGlow:SetPoint("BOTTOMRIGHT",medallion,"BOTTOMRIGHT",-5,5)
    innerGlow:SetColorTexture(.85,.62,.24,.08)
    if self.RegisterThemeTarget then
        self:RegisterThemeTarget(header,function(_,tokens)
            headerRule:SetColorTexture(tokens.accent[1],tokens.accent[2],tokens.accent[3],.53)
        end)
    end
    local mark = NavLabel(medallion, "AF", "GameFontNormalLarge", 1, .84, .36)
    mark:SetPoint("CENTER",medallion,"CENTER",0,0)
    if self.RegisterThemeTarget then self:RegisterThemeTarget(mark,function(label,t)
        label:SetTextColor(unpack(t.accent))
    end) end
    self.title = NavLabel(header, "AZEROTH FOUNDRY", "GameFontNormalLarge", .99, .82, .54)
    self.title:SetPoint("TOPLEFT", 75, -12)
    if self.RegisterThemeTarget then self:RegisterThemeTarget(self.title,function(label,t)
        label:SetTextColor(unpack(t.accent))
        label:SetText(t.mode=="matrix" and "> AZEROTH FOUNDRY_" or "AZEROTH FOUNDRY")
    end) end
    local subtitle = NavLabel(header, "Adventurer's Journal  |  Account Self-Sufficiency", "GameFontHighlightSmall", .67, .65, .59)
    subtitle:SetPoint("TOPLEFT", 75, -39)
    if self.RegisterThemeTarget then self:RegisterThemeTarget(subtitle,function(label,t)
        label:SetTextColor(unpack(t.muted))
    end) end
    self.charIcon = header:CreateTexture(nil,"ARTWORK")
    self.charIcon:SetSize(28,28)
    self.charIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    self.charTitle = NavLabel(header,"","GameFontHighlightSmall",.86,.82,.71)
    self.charTitle:SetPoint("TOPRIGHT",-56,-22)
    self.charTitle:SetSize(198,25)
    if self.RegisterThemeTarget then self:RegisterThemeTarget(self.charTitle,function(label,t)
        label:SetTextColor(unpack(t.text))
    end) end
    self.charIcon:SetPoint("RIGHT",self.charTitle,"LEFT",-8,0)
    local close=CreateFrame("Button",nil,header,"UIPanelCloseButton")
    close:SetSize(31,31)
    close:SetPoint("TOPRIGHT",-8,-19)
    close:SetScript("OnClick",function()frame:Hide()end)
    local guideButton=self:Button(header,"? Guide",function()
        if UI.OpenAdventurersGuide then UI:OpenAdventurersGuide() end
    end)
    guideButton:SetPoint("TOPRIGHT",header,"TOPRIGHT",-302,-22)
    guideButton:SetSize(90,28)
    self.guideButton=guideButton

    local nav = CreateFrame("Frame",nil,frame)
    nav:SetPoint("TOPLEFT", 12, -84)
    nav:SetPoint("BOTTOMLEFT", 12, 16)
    local navSurface=Surface(nav,.095,.095,.10,.99)
    if self.RegisterThemeTarget then
        self:RegisterThemeTarget(navSurface,function(texture,tokens)
            texture:SetColorTexture(unpack(tokens.nav))
        end)
    end
    self.navFrame=nav
    local navHeading=NavLabel(nav,"NAVIGATION","GameFontNormalSmall",.70,.61,.47)
    navHeading:SetPoint("TOPLEFT",13,-17)
    self.navHeading=navHeading
    if self.RegisterThemeTarget then self:RegisterThemeTarget(navHeading,function(label,t)
        label:SetTextColor(unpack(t.muted))
    end) end
    local navToggle=CreateFrame("Button",nil,nav)
    navToggle:SetSize(34,29)
    navToggle:SetPoint("TOPRIGHT",-8,-11)
    local navToggleBg=Surface(navToggle,.17,.17,.19,.96)
    self.navToggleText=NavLabel(navToggle,"<","GameFontHighlightSmall",1,.94,.84)
    self.navToggleText:SetPoint("CENTER",0,0)
    if self.RegisterThemeTarget then
        self:RegisterThemeTarget(navToggle,function(_,tokens)
            local c=tokens.raised
            navToggleBg:SetColorTexture(c[1],c[2],c[3],1)
            self.navToggleText:SetTextColor(unpack(tokens.navText))
        end)
    end
    navToggle:SetScript("OnClick",function()
        settings.navigationCollapsed=not settings.navigationCollapsed
        UI:RefreshNavigation()
        -- Resizing the content region is left to native anchors and Overview's
        -- already-tested responsive layout; no widget model is recreated here.
        if UI.currentPage and UI.pageViews[UI.currentPage] then
            local page=UI.pageViews[UI.currentPage]
            if page.Refresh then page:Refresh() end
        end
    end)
    navToggle:SetScript("OnEnter",function(self)
        if settings.showNavigationTooltips then
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText("Collapse / expand navigation")
            GameTooltip:Show()
        end
    end)
    navToggle:SetScript("OnLeave",function()GameTooltip:Hide()end)
    -- Scroll clipping matters at the minimum window height. An expanded tree
    -- must never cover Settings or spill beyond the bottom of the Foundry.
    local scroll = CreateFrame("ScrollFrame", nil, nav)
    scroll:SetPoint("TOPLEFT", 2, -46)
    scroll:SetPoint("BOTTOMRIGHT", -2, 10)
    local navList = CreateFrame("Frame", nil, scroll)
    navList:SetSize(194, 565)
    scroll:SetScrollChild(navList)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local maxScroll = math.max(0,navList:GetHeight()-scroll:GetHeight())
        scroll:SetVerticalScroll(math.max(0, math.min(maxScroll,scroll:GetVerticalScroll()-delta*46)))
    end)
    scroll:SetScript("OnSizeChanged", function() UI:ClampNavigationScroll() end)
    self.navScroller=scroll
    self.navListChild=navList
    self.tabs={}
    self.treeNavButtons={}
    self.navTreeLines={}
    local function MakeNavButton(name, iconPath, subpage)
        local button=CreateFrame("Button",nil,navList)
        button:RegisterForClicks("LeftButtonUp","RightButtonUp")
        button.bg=Surface(button,.16,.16,.16,0)
        local line=button:CreateTexture(nil,"ARTWORK")
        line:SetPoint("TOPLEFT",0,-4)
        line:SetPoint("BOTTOMLEFT",0,4)
        line:SetWidth(3)
        line:SetColorTexture(1,.76,.34,.95)
        button.activeLine=line
        local icon=button:CreateTexture(nil,"OVERLAY")
        icon:SetSize(subpage and 18 or 24, subpage and 18 or 24)
        icon:SetTexture(iconPath)
        icon:SetTexCoord(.08,.92,.08,.92)
        button.icon=icon
        local caption=NavLabel(button,name,"GameFontHighlightSmall",.8,.78,.73)
        caption:SetPoint("LEFT",button,"LEFT",subpage and 28 or 47,0)
        button.caption=caption
        button:SetScript("OnEnter",function(self)
            if settings.showNavigationTooltips and settings.navigationCollapsed then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetText(name,1,.84,.54)
                if NAV_TREES[name] then
                    GameTooltip:AddLine("Right-click to show or hide "..name.." branches",.78,.76,.69)
                end
                GameTooltip:Show()
            end
            if not settings.navigationCollapsed then
                local t=UI:ThemeTokens()
                local c=t.navActive
                self.bg:SetColorTexture(c[1],c[2],c[3],.95)
            end
        end)
        button:SetScript("OnLeave",function()
            GameTooltip:Hide()
            UI:RefreshNavigation()
        end)
        return button
    end
    -- One connector per group; all are non-interactive border-layer textures.
    for _,entry in ipairs(NAVIGATION) do
        local button=MakeNavButton(entry.name,entry.icon,false)
        local tree=NAV_TREES[entry.name]
        button:SetScript("OnClick",function(_,mouseButton)
            if tree and mouseButton=="RightButton" then
                settings[tree.setting]=not (settings[tree.setting] ~= false)
                UI:RefreshNavigation()
                UI:RevealNavigationSelection()
                return
            end
            if tree then settings[tree.setting]=true end
            UI:Switch(entry.route or entry.name)
        end)
        if tree then
            local toggle=CreateFrame("Button",nil,button)
            toggle:SetSize(23,27)
            toggle:SetPoint("RIGHT",button,"RIGHT",-5,0)
            toggle:SetFrameLevel(button:GetFrameLevel()+2)
            local arrow=NavLabel(toggle,"v","GameFontHighlightSmall",.91,.75,.47)
            arrow:SetPoint("CENTER",0,0)
            button.treeToggle=toggle
            button.treeToggleText=arrow
            toggle:SetScript("OnClick",function()
                settings[tree.setting]=not (settings[tree.setting] ~= false)
                UI:RefreshNavigation()
                UI:RevealNavigationSelection()
            end)
            toggle:SetScript("OnEnter",function(self)
                if settings.showNavigationTooltips then
                    GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                    GameTooltip:SetText("Expand / collapse "..entry.name,1,.84,.54)
                    GameTooltip:Show()
                end
            end)
            toggle:SetScript("OnLeave",function()GameTooltip:Hide()end)
            local line=navList:CreateTexture(nil,"BORDER")
            line:SetWidth(1)
            self.navTreeLines[entry.name]=line
            self.treeNavButtons[entry.name]={}
            for _,child in ipairs(tree.children) do
                local sub=MakeNavButton(child.name,child.icon,true)
                local branch=navList:CreateTexture(nil,"BORDER")
                branch:SetHeight(1)
                sub.branch=branch
                sub:SetScript("OnClick",function()
                    UI:Switch(child.name)
                    -- This actual navigation click is a hardware event: use
                    -- it to prepare the queue's selected profession *before*
                    -- the separate Craft button is clicked. No crafting is
                    -- initiated here, and slash-command/UI refresh routes
                    -- do not silently attempt protected profession actions.
                    if child.name=='Crafting Queue' and AF.PrepareQueuedCraftOnSelection then
                        local project=AF:FindRecord(AF:GetCraftingQueueProjects(),UI.workshopQueueSelected)
                        if project then
                            local ok,msg=AF:PrepareQueuedCraftOnSelection(project)
                            UI.workshopQueueNotice=msg
                            local workshop=UI.pageViews and UI.pageViews['Living Workshop']
                            local queue=workshop and workshop.subViews and workshop.subViews['Crafting Queue']
                            if queue and queue.Refresh then queue:Refresh() end
                        end
                    end
                end)
                self.treeNavButtons[entry.name][child.name]=sub
            end
        end
        self.tabs[entry.name]=button
    end
    self.contentTop=CreateFrame("Frame",nil,frame)
    self.contentTop:SetPoint("TOPLEFT",nav,"TOPRIGHT",10,0)
    self.contentTop:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-14,-84)
    self.contentTop:SetHeight(45)
    local barSurface=Surface(self.contentTop,.095,.087,.079,.98)
    if self.RegisterThemeTarget then
        self:RegisterThemeTarget(barSurface,function(texture,tokens)
            texture:SetColorTexture(unpack(tokens.bar))
        end)
    end
    -- Overview-only header artwork; hidden on Characters/Workshop/etc.
    local overviewDecorations={}
    -- No stretched ornament sheet on this narrow page header.
    -- Reintroduce the compact decorated page title seen in the original
    -- screenshots. It is an intentional fixed-size PLAQUE inside a fluid bar.
    -- The wide backdrop behind it (above) is still four-side anchored.
    local titlePlate=self.contentTop:CreateTexture(nil,"ARTWORK",nil,0)
    titlePlate:SetPoint("TOPLEFT",self.contentTop,"TOPLEFT",1,-2)
    titlePlate:SetSize(187,41)
    titlePlate:SetColorTexture(.088,.117,.098,.83)
    overviewDecorations[#overviewDecorations+1]=titlePlate
    local plateHighlight=self.contentTop:CreateTexture(nil,"ARTWORK",nil,1)
    overviewDecorations[#overviewDecorations+1]=plateHighlight
    plateHighlight:SetPoint("TOPLEFT",titlePlate,"TOPLEFT",2,-1)
    plateHighlight:SetPoint("TOPRIGHT",titlePlate,"TOPRIGHT",-2,-1)
    plateHighlight:SetHeight(2)
    plateHighlight:SetColorTexture(.57,.43,.20,.74)
    local plateBottom=self.contentTop:CreateTexture(nil,"ARTWORK",nil,1)
    overviewDecorations[#overviewDecorations+1]=plateBottom
    plateBottom:SetPoint("BOTTOMLEFT",titlePlate,"BOTTOMLEFT",2,1)
    plateBottom:SetPoint("BOTTOMRIGHT",titlePlate,"BOTTOMRIGHT",-2,1)
    plateBottom:SetHeight(2)
    plateBottom:SetColorTexture(.49,.38,.19,.76)
    local plateLeft=self.contentTop:CreateTexture(nil,"ARTWORK",nil,1)
    overviewDecorations[#overviewDecorations+1]=plateLeft
    plateLeft:SetPoint("TOPLEFT",titlePlate,"TOPLEFT",0,-1)
    plateLeft:SetPoint("BOTTOMLEFT",titlePlate,"BOTTOMLEFT",0,1)
    plateLeft:SetWidth(2)
    plateLeft:SetColorTexture(.55,.41,.19,.78)
    -- Removed the detached marine cap: it was a tiny atlas crop stretched
    -- into a 40x35 plaque ornament and left a floating dark rectangle.
    local pageIcon=self.contentTop:CreateTexture(nil,"ARTWORK")
    pageIcon:SetSize(22,22)
    pageIcon:SetPoint("TOPLEFT",self.contentTop,"TOPLEFT",13,-11)
    pageIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_11")
    pageIcon:SetTexCoord(.08,.92,.08,.92)
    self.pageIcon=pageIcon
    local pageTitle=NavLabel(self.contentTop,"","GameFontNormalLarge",1,.83,.53)
    pageTitle:SetPoint("TOPLEFT",42,-9)
    self.pageTitle=pageTitle
    if self.RegisterThemeTarget then self:RegisterThemeTarget(pageTitle,function(label,t)
        label:SetTextColor(unpack(t.accent))
    end) end
    -- Characters' utility action lives in the contextual page bar, not inside
    -- the editable Expedition/role controls. It is hidden on other pages.
    local scanCharacter=UI:Button(self.contentTop,"Rescan Current",function()
        if AF.ScanCharacter then AF:ScanCharacter() end
        if AF.RecordCurrentCharacterMoney then AF:RecordCurrentCharacterMoney() end
        if AF.RequestCurrentCharacterPlayed then AF:RequestCurrentCharacterPlayed() end
        if UI.Refresh then UI:Refresh() end
    end)
    scanCharacter:SetSize(132,26)
    scanCharacter:SetPoint("TOPRIGHT",self.contentTop,"TOPRIGHT",-11,-9)
    scanCharacter:Hide()
    self.characterScanButton=scanCharacter
    self:FoundryHeadingRule(self.contentTop)
    self.overviewHeaderDecorations=overviewDecorations

    self.body=self:NewFrame("Frame",frame)
    self.body:SetPoint("TOPLEFT",nav,"TOPRIGHT",10,-49)
    self.body:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-14,16)
    local bodySurface=self:Background(self.body,self.palette.parchment,true)
    if self.RegisterThemeTarget then
        self:RegisterThemeTarget(bodySurface,function(texture,tokens)
            texture:SetColorTexture(unpack(tokens.body))
        end)
    end
    local resize=CreateFrame("Button",nil,frame)
    resize:SetSize(20,20)
    resize:SetPoint("BOTTOMRIGHT",-3,3)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown",function(_,button)
        if button=="LeftButton" then frame:StartSizing("BOTTOMRIGHT") end
    end)
    resize:SetScript("OnMouseUp",function()
        frame:StopMovingOrSizing()
        UI:SavePosition()
        UI:Refresh()
    end)
    frame:SetScript("OnSizeChanged",function(_,width,height)
        if AF.db then
            AF.db.settings.width=math.floor(width+.5)
            AF.db.settings.height=math.floor(height+.5)
        end
    end)
    frame:SetScript("OnShow",function()self:Refresh()end)
    -- Release concealed profession state on intentional journal closure.
    -- Auto-opened sessions close without showing the native window; a
    -- profession the user opened themselves is restored instead.
    -- Do not hook the queue child: crafting results can hide it temporarily.
    frame:HookScript("OnHide",function()
        if AF.IsQueueCompactNativeProfession and AF:IsQueueCompactNativeProfession() then
            if AF.ReleaseQueueNativeProfession then AF:ReleaseQueueNativeProfession() end
        end
    end)
    frame:Hide()
    self.pageViews={}
    self.currentPage=nil
    if UISpecialFrames then table.insert(UISpecialFrames,"AzerothFoundryJournal") end
    if self.ApplyTheme then self:ApplyTheme() end
    self:RefreshNavigation()
    self:Switch(settings.rememberFoundryPage and settings.page or "Overview")
end

function UI:RefreshOverviewHeaderDecorations()
    if not self.overviewHeaderDecorations then return end
    local tokens=self.ThemeTokens and self:ThemeTokens()
    local active=(self.currentPage=="Overview") and
        (not tokens or tokens.classicArtwork)
    for _,texture in ipairs(self.overviewHeaderDecorations) do
        texture:SetShown(active)
    end
end

function UI:Switch(name)
    if not self.frame then return end
    local redirectToModules=name=="Self-Found" and not AF:IsModuleEnabled("selfFound")
    if redirectToModules then
        AF.db.settings.settingsSection="modules"
        name="Settings"
    end
    -- Compatibility routes preserve the older /af commands and existing links.
    local destination = {Professions="Professions", Recipes="Recipes",
        Projects="Goals", ["Crafting Queue"]="Crafting Queue", Materials="Materials"}
    if name == "Workshop" then name = "Living Workshop" end
    local subpage = destination[name]
    if subpage and subpage ~= "Goals" then
        name = "Living Workshop"
        AF.db.settings.workshopTab = subpage
    elseif subpage == "Goals" then
        name = "Goals"
    end
    if name == "Crafting" then name="Living Workshop"; AF.db.settings.workshopTab="Crafting Queue" end
    local collectionCategory=COLLECTION_ROUTES[name]
    local goalView=GOAL_ROUTES[name] and name or nil
    if collectionCategory then name="Collections" end
    if goalView then name="Goals" end
    if name~="Living Workshop" and AF.IsQueueCompactNativeProfession and
        AF:IsQueueCompactNativeProfession() then
        if AF.ReleaseQueueNativeProfession then AF:ReleaseQueueNativeProfession() end
    end
    local page = self.pageViews[name]
    if not page then
        page = CreateFrame("Frame", nil, self.body)
        page:SetAllPoints(self.body)
        self.pageViews[name] = page
        self:BuildPage(name, page)
    end
    for otherName, other in pairs(self.pageViews) do
        if otherName == name then other:Show() else other:Hide() end
    end
    if name ~= "Goals" and self.goalEditor then self.goalEditor:Hide() end
    if self.goalGuideDialog and name ~= 'Living Workshop' then self.goalGuideDialog:Hide() end
    self.currentPage = name
    self:RefreshOverviewHeaderDecorations()
    if AF.db.settings.rememberFoundryPage then AF.db.settings.page = name end
    if self.pageIcon then
        local lookup=name=="Living Workshop" and "Workshop" or name
        for _,entry in ipairs(NAVIGATION) do
            if entry.name==lookup then self.pageIcon:SetTexture(entry.icon); break end
        end
    end
    if self.characterScanButton then self.characterScanButton:SetShown(name=="Characters") end
    if self.pageIcon then self.pageIcon:SetShown(name~="Characters" and name~="Goals") end
    if self.pageTitle then
        self.pageTitle:ClearAllPoints()
        self.pageTitle:SetPoint("TOPLEFT",(name=="Characters" or name=="Goals") and 13 or 42,-9)
        local title=name
        if name=="Characters" then title=AF:IsModuleEnabled("selfFound") and "Adventurers  |  Your roster, membership and history" or "Adventurers  |  Your character roster"
        elseif name=="Living Workshop" then title="Workshop  /  "..(AF.db.settings.workshopTab or "Professions")
        elseif name=="Collections" then title="Collections  /  "..(COLLECTION_LABELS[AF.db.collections and AF.db.collections.settings and AF.db.collections.settings.category] or "Mounts")
        elseif name=="Goals" then title="Adventurer's Goals  |  Plan, track and remember"
        elseif name=="Self-Found" then title="Self-Found  |  Your Expedition Charter" end
        self.pageTitle:SetText(title)
    end
    if redirectToModules and page.SelectSettingsSection then
        page:SelectSettingsSection("modules")
    end
    if name == "Living Workshop" and page.Select then
        page:Select(AF.db.settings.workshopTab or "Professions")
    elseif name == "Collections" and collectionCategory and page.Select then
        page:Select(collectionCategory)
    elseif name == "Goals" and goalView and page.Select then
        page:Select(goalView)
    end
    self:RefreshNavigation()
    self:RevealNavigationSelection()
    self:Refresh()
    if name=="Self-Found" then self:TryShowSelfFoundInitiation() end
end

function UI:TryShowSelfFoundInitiation()
    if self._openingExpeditionInitiation or not AF:IsModuleEnabled("selfFound")
        or not self.frame or not self.frame:IsShown() or not AF.db then return false end
    if self.adventurersGuide and self.adventurersGuide:IsShown() then return false end
    if self.guideInvitation and self.guideInvitation:IsShown() then return false end
    if self.initiationOverlay and self.initiationOverlay:IsShown() then return false end
    local key=AF:GetCurrentKey()
    if not AF.ShouldOfferExpeditionInitiation or not AF:ShouldOfferExpeditionInitiation(key) then return false end
    self._openingExpeditionInitiation=true
    local ok,shown=pcall(self.ShowExpeditionInitiation,self,key,false)
    self._openingExpeditionInitiation=false
    if not ok and AF.Print then AF.Print("Self-Found introduction error: "..tostring(shown)) end
    return ok and shown==true
end

function UI:Refresh()
    if not self.frame or not AF.db then return end
    local current = AF:CurrentCharacter()
    if current then
        self.charTitle:SetText((current.name or "Unknown") .. "  |  Lv " .. tostring(current.level or "?") .. " " .. (current.class or ""))
        if current.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[current.class] then
            self.charIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            self.charIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[current.class]))
        end
    end
    local page = self.pageViews[self.currentPage]
    if page and page.Refresh then page:Refresh() end
    if self.pageTitle then
        if self.currentPage=="Living Workshop" then
            self.pageTitle:SetText("Workshop  /  "..(AF.db.settings.workshopTab or "Professions"))
        elseif self.currentPage=="Collections" then
            self.pageTitle:SetText("Collections  /  "..(COLLECTION_LABELS[AF.db.collections and AF.db.collections.settings and AF.db.collections.settings.category] or "Mounts"))
        elseif self.currentPage=="Goals" then
            self.pageTitle:SetText("Adventurer's Goals  |  Plan, track and remember")
        end
    end
    self:RefreshNavigation()
end

function UI:Open(page)
    if not self.frame then return end
    if page then self:Switch(page) end
    self.frame:Show()
    self.frame:Raise()
    if page=="Self-Found" then self:TryShowSelfFoundInitiation() end
    -- The optional first-run tour appears only on an ordinary journal open,
    -- never over the new-character Expedition invitation (which supplies page).
    if not page and AF.db and AF.db.settings and AF.db.settings.guidePrompted==false
        and self.ShowGuideInvitation then
        self:ShowGuideInvitation()
    end
end

function UI:Toggle()
    if self.frame:IsShown() then self.frame:Hide() else self:Open() end
end

function UI:ShowWelcome()
    self:Open("Overview")
    if self.welcome then self.welcome:Show(); return end
    local overlay = self:NewFrame("Frame", self.frame)
    self.welcome = overlay
    overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    overlay:SetSize(540, 265)
    overlay:SetPoint("CENTER", self.frame, "CENTER")
    self:Background(overlay, self.palette.parchmentLight, true)
    local title = self:SectionTitle(overlay, "Welcome to Azeroth Foundry")
    title:SetPoint("TOPLEFT", 25, -22)
    title:SetWidth(480)
    local body = self:Text(overlay, nil, self.palette.ink)
    body:SetPoint("TOPLEFT", 25, -67)
    body:SetSize(490, 115)
    body:SetJustifyV("TOP")
    body:SetText("Your journal follows your characters across this WoW account. Notes, checklists, and projects stay local.\n\nSetting a main also enrolls that character in your Expedition. Other characters can remain independent until you invite them.")
    local makeMain = self:Button(overlay, "Set this character as Main", function()
        AF:SetMain(AF:GetCurrentKey())
        AF.db.settings.welcomed = true
        overlay:Hide()
    end)
    makeMain:SetSize(235, 32)
    makeMain:SetPoint("BOTTOMLEFT", 25, 23)
    local later = self:Button(overlay, "Choose Later", function()
        AF.db.settings.welcomed = true
        overlay:Hide()
    end)
    later:SetSize(160, 32)
    later:SetPoint("BOTTOMRIGHT", -25, 23)
end

-- Presented once to newly registered alts on an existing account. Characters
-- remain independent unless the player explicitly enrolls them.
function UI:ShowEnrollment()
    local key = AF:GetCurrentKey()
    local c = AF.db and AF.db.characters[key]
    if not c or AF:IsExpeditionMember(key) then return end
    self:Open("Characters")
    if self.enrollment then self.enrollment:Show(); return end
    local overlay = self:NewFrame("Frame", self.frame)
    self.enrollment = overlay
    overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    overlay:SetSize(550, 275)
    overlay:SetPoint("CENTER", self.frame, "CENTER")
    self:Background(overlay, self.palette.parchmentLight, true)
    local title = self:SectionTitle(overlay, "A New Adventurer Joins the Story")
    title:SetPoint("TOPLEFT", 24, -20)
    title:SetWidth(500)
    local body = self:Text(overlay, nil, self.palette.ink)
    body:SetPoint("TOPLEFT", 24, -64)
    body:SetSize(500, 130)
    body:SetJustifyV("TOP")
    body:SetText("Would you like to invite " .. (c.name or "this character") ..
        " into your Foundry Expedition?\n\nEnrolled characters share the Expedition's tracking history. Independent characters can play freely. Earlier activities cannot be retroactively verified.")
    local invite = self:Button(overlay, "Invite to Expedition", function()
        overlay:Hide()
        UI:ConfirmExpeditionChange(key, true)
    end)
    invite:SetSize(220, 32)
    invite:SetPoint("BOTTOMLEFT", 24, 24)
    local separate = self:Button(overlay, "Remain Independent", function()
        overlay:Hide()
    end)
    separate:SetSize(190, 32)
    separate:SetPoint("BOTTOMRIGHT", -24, 24)
end
