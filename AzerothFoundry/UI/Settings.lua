-- Azeroth Foundry 0.5.9 - integrated Settings and developer tools.
-- UI-only module. All existing data, Atlas, recipes, collections, and
-- modular Overview engines retain their current saved-variable contracts.
local _, AF = ...
local UI = AF.UI
local unpack=unpack or table.unpack
local GOLD = {0.91, 0.69, 0.35}
-- Player-facing pages only. Existing SavedVariables IDs from removed pages
-- are mapped to their nearest retained destination at selection time.
local CATEGORIES = {
    {"general", "General"},
    {"modules", "Modules"},
    {"themes", "Theme Studio"},
    {"maintenance", "Data & Tools"},
}

local function Fill(parent, r, g, b, a, semanticRole)
    local region = parent:CreateTexture(nil,"BACKGROUND")
    region:SetAllPoints(parent)
    region:SetColorTexture(r,g,b,a or 1)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(region,function(tex,t)
        local c
        if semanticRole=="data" then c=t.dataSurface
        elseif semanticRole=="dataRow" then
            local base=t.dataSurface
            local other=t.paper
            c={base[1]*.88+other[1]*.12,base[2]*.88+other[2]*.12,base[3]*.88+other[3]*.12,1}
        elseif r<.105 then c=t.shell
        elseif r<.120 then c=t.nav
        elseif r<.155 then c=t.paper
        elseif r<.250 then
            if t.light or t.mode=="sprinkles" or t.mode=="classic" or t.mode=="forever" then
                c=t.paper
            else c=t.raised end
        else c=t.navActive end
        tex:SetColorTexture(c[1],c[2],c[3],a or 1)
    end) end
    return region
end
local function Text(parent, content, font, r,g,b)
    local t=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
    t:SetText(content or "")
    t:SetTextColor(r or .83,g or .79,b or .73)
    -- GameFont* templates may carry a black shadow intended for light type.
    -- A palette can make this text dark, where the inherited shadow looks
    -- like muddy/doubled lettering. All Settings text uses clean type.
    if t.SetShadowOffset then t:SetShadowOffset(0,0) end
    if t.SetShadowColor then t:SetShadowColor(0,0,0,0) end
    local surface=parent and parent.afThemeSurfaceRole
    -- Nested Settings sections inherit the main content's data-surface role.
    -- An explicit nav/button/paper role takes priority for local controls.
    if not surface and parent and parent.GetParent then
        local node=parent:GetParent()
        for _=1,8 do
            if not node then break end
            surface=node.afThemeSurfaceRole
            if surface then break end
            node=node.GetParent and node:GetParent() or nil
        end
    end
    local heading=(r or .83)>.88 and (g or .79)>.63 and (g or .79)<.89 and (b or .73)<.70
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(t,function(label,tokens)
        -- The owning Settings button renders its own normal/hover/pressed text;
        -- a generic text callback must not repaint it in an arbitrary order.
        if label.afSettingsButtonLabel then return end
        local bg=surface=="nav" and tokens.nav or surface=="button" and tokens.buttonFace
            or surface=="paper" and tokens.paper or surface=="dataRow" and tokens.dataSurface
            or tokens.dataSurface
        local pref=surface=="nav" and tokens.navText or surface=="button" and tokens.buttonText
            or heading and tokens.accent2 or surface=="paper" and tokens.ink or tokens.dataText
        local c=UI.ThemeReadableText and UI:ThemeReadableText(bg,pref) or pref
        label:SetTextColor(c[1],c[2],c[3],1)
    end) end
    t:SetJustifyH("LEFT")
    t:SetJustifyV("MIDDLE")
    return t
end
local function Line(parent,y)
    local t=parent:CreateTexture(nil,"BORDER")
    t:SetColorTexture(.83,.60,.30,.28)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(t,function(tex,tokens)
        local c=tokens.divider;tex:SetColorTexture(c[1],c[2],c[3],.45)
    end) end
    t:SetPoint("TOPLEFT",parent,"TOPLEFT",12,y)
    t:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-12,y)
    t:SetHeight(1)
end
local function Button(parent, caption, onClick, width)
    local b=CreateFrame("Button",nil,parent)
    b:SetSize(width or 165,30)
    b:RegisterForClicks("LeftButtonUp")
    -- Do not call the themed Fill() helper here. Its own separate theme
    -- listener previously repainted buttons as generic paper AFTER their
    -- button listener had chosen the normal fill. This made the fill vanish
    -- until pointer hover, and could return in a different state on leave.
    local bg=b:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(b)
    bg:SetColorTexture(.20,.19,.19,.97)
    b.afThemeSurfaceRole="button"
    b.afSettingsButtonBackground=bg
    local label=Text(b,caption,"GameFontHighlightSmall",.98,.86,.63)
    label:SetPoint("CENTER",0,0)
    label.afSettingsButtonLabel=true
    b.label=label
    local function refresh()
        if not UI.ThemeTokens then return end
        local t=UI:ThemeTokens()
        local c=b.afSettingsPressed and t.raised or
            (b.afSettingsHover and t.hover or (b.afSettingsSelected and t.navActive or t.buttonFace))
        bg:SetColorTexture(c[1],c[2],c[3],1)
        local preferred=b.afSettingsSelected and t.navSelectedText or t.buttonText
        local fg=UI.ThemeReadableText and UI:ThemeReadableText(c,preferred) or preferred
        label:SetTextColor(unpack(fg))
    end
    b:SetScript("OnEnter",function() b.afSettingsHover=true;refresh() end)
    b:SetScript("OnLeave",function() b.afSettingsHover=false;b.afSettingsPressed=false;refresh() end)
    b:SetScript("OnMouseDown",function(_,mouse)
        if mouse=="LeftButton" then b.afSettingsPressed=true;refresh() end
    end)
    b:SetScript("OnMouseUp",function()
        b.afSettingsPressed=false;refresh()
    end)
    b:SetScript("OnHide",function()
        b.afSettingsHover=false;b.afSettingsPressed=false
    end)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(b,refresh) else refresh() end
    function b:SetSelected(selected)
        self.afSettingsSelected=selected and true or false
        refresh()
    end
    b:SetScript("OnClick",onClick)
    return b
end
local function Print(message)
    if AF.Print then AF.Print(message) end
end

function UI:BuildSettings(page)
    local settings=AF.db.settings
    local bg=Fill(page,.090,.086,.083,1)
    -- Keep stable semantic targets for Art Lab's region inspector.
    bg.afArtLabSlot="Pages.Settings.Background"
    page.sections={}
    local left=CreateFrame("Frame",nil,page)
    left.afThemeSurfaceRole="nav"
    left:SetPoint("TOPLEFT",page,"TOPLEFT",9,-9)
    left:SetPoint("BOTTOMLEFT",page,"BOTTOMLEFT",9,9)
    left:SetWidth(184)
    Fill(left,.112,.110,.114,.99)
    local body=CreateFrame("Frame",nil,page)
    body:SetPoint("TOPLEFT",left,"TOPRIGHT",10,0)
    body:SetPoint("BOTTOMRIGHT",page,"BOTTOMRIGHT",-9,9)
    body.afThemeSurfaceRole="data"
    Fill(body,.126,.122,.120,.99,"data")
    local navButtons={}
    local refreshers={}
    local PREVIOUS_SECTIONS={appearance="general",overview="general",atlas="maintenance",
        data="maintenance",developer="maintenance",about="maintenance"}
    local selected=PREVIOUS_SECTIONS[settings.settingsSection] or settings.settingsSection or "general"

    local function Heading(panel,title,subtitle)
        local name=Text(panel,title,"GameFontNormalLarge",1,.82,.49)
        name:SetPoint("TOPLEFT",18,-15)
        local desc=Text(panel,subtitle,"GameFontHighlightSmall",.63,.62,.61)
        desc:SetPoint("TOPLEFT",18,-43)
        desc:SetPoint("TOPRIGHT",-15,-43)
        desc:SetHeight(42)
        desc:SetJustifyV("TOP")
        Line(panel,-91)
    end
    local function Note(panel,content,y,height)
        local t=Text(panel,content,"GameFontHighlightSmall",.72,.70,.67)
        t:SetPoint("TOPLEFT",18,y)
        t:SetPoint("TOPRIGHT",-18,y)
        t:SetHeight(height or 48)
        t:SetJustifyV("TOP")
        return t
    end
    local function HeadingRow(panel,title,desc,y)
        local panelRow=CreateFrame("Frame",nil,panel)
        panelRow:SetPoint("TOPLEFT",17,y)
        panelRow:SetPoint("TOPRIGHT",-17,y)
        panelRow:SetHeight(54)
        panelRow.afThemeSurfaceRole="dataRow"
        Fill(panelRow,.17,.17,.18,.90,"dataRow")
        local main=Text(panelRow,title,"GameFontNormalSmall",.94,.82,.65)
        main:SetPoint("TOPLEFT",12,-9)
        local detail=Text(panelRow,desc,"GameFontHighlightSmall",.62,.62,.62)
        detail:SetPoint("TOPLEFT",12,-29)
        detail:SetPoint("RIGHT",-10,0)
        return panelRow
    end
    local function Check(panel,key,title,description,y,callback,column)
        local row=CreateFrame("Button",nil,panel)
        if column=="left" then
            row:SetPoint("TOPLEFT",panel,"TOPLEFT",18,y)
            row:SetPoint("TOPRIGHT",panel,"TOP",-6,y)
        elseif column=="right" then
            row:SetPoint("TOPLEFT",panel,"TOP",6,y)
            row:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-18,y)
        else
            row:SetPoint("TOPLEFT",18,y)
            row:SetPoint("TOPRIGHT",-18,y)
        end
        row:SetHeight(51)
        row:RegisterForClicks("LeftButtonUp")
        row.afThemeSurfaceRole="dataRow"
        Fill(row,.18,.17,.16,.88,"dataRow")
        local square=CreateFrame("Frame",nil,row)
        square:SetSize(20,20)
        square:SetPoint("LEFT",11,0)
        Fill(square,.065,.065,.065,1)
        local check=Text(square,"","GameFontNormalLarge",1,.80,.36)
        check:SetPoint("CENTER",0,0)
        local titleLabel=Text(row,title,"GameFontHighlightSmall",.96,.88,.74)
        titleLabel:SetPoint("TOPLEFT",42,-8)
        local hint=Text(row,description,"GameFontHighlightSmall",.57,.56,.55)
        hint:SetPoint("TOPLEFT",42,-29)
        hint:SetPoint("RIGHT",-8,0)
        local function Refresh() check:SetText(settings[key] and "x" or "") end
        row:SetScript("OnClick",function()
            settings[key]=not settings[key]
            Refresh()
            if callback then callback(settings[key]) end
        end)
        refreshers[#refreshers+1]=Refresh
        Refresh()
        return row
    end
    local function RowButtons(panel,y,buttons)
        local prev=nil
        for _, item in ipairs(buttons) do
            local b=Button(panel,item[1],item[2],item[3])
            if prev then b:SetPoint("LEFT",prev,"RIGHT",8,0)
            else b:SetPoint("TOPLEFT",19,y) end
            prev=b
        end
    end

    local function Select(id)
        id=PREVIOUS_SECTIONS[id] or id
        if not page.sections[id] then id="general" end
        selected=id
        settings.settingsSection=id
        for key,f in pairs(page.sections) do f:SetShown(key==id) end
        for key,btn in pairs(navButtons) do
            local active=key==id
            local theme=UI.ThemeTokens and UI:ThemeTokens()
            local bgColor=theme and (active and theme.navActive or theme.nav) or {active and .34 or .16,.16,.17}
            btn.bg:SetColorTexture(bgColor[1],bgColor[2],bgColor[3],active and 1 or .5)
            local textColor=theme and (active and theme.navSelectedText or theme.navText) or {1,.83,.48}
            btn.label:SetTextColor(textColor[1],textColor[2],textColor[3],1)
        end
        for _,refresh in ipairs(refreshers) do refresh() end
    end
    self.RefreshThemeSettings=function()
        if page and page.IsShown and page:IsShown() then Select(selected) end
    end
    local navTitle=Text(left,"SETTINGS","GameFontNormalSmall",.73,.62,.47)
    navTitle:SetPoint("TOPLEFT",12,-15)
    Line(left,-41)
    local navFooter=Text(left,"Azeroth Foundry  /  v"..tostring(AF.version or "1.0.14"),"GameFontHighlightSmall",.70,.66,.61)
    navFooter:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",12,15)
    navFooter:SetPoint("BOTTOMRIGHT",left,"BOTTOMRIGHT",-8,15)
    navFooter:SetHeight(20)
    for i,entry in ipairs(CATEGORIES) do
        local id,name=entry[1],entry[2]
        local row=CreateFrame("Button",nil,left)
        row:SetPoint("TOPLEFT",7,-55-(i-1)*44)
        row:SetPoint("TOPRIGHT",-7,-55-(i-1)*44)
        row:SetHeight(40)
        row:RegisterForClicks("LeftButtonUp")
        row.bg=Fill(row,.16,.16,.17,.12)
        row.afThemeSurfaceRole="nav"
        row.label=Text(row,name,"GameFontHighlightSmall",.81,.78,.72)
        row.label:SetPoint("LEFT",9,0)
        row:SetScript("OnClick",function()Select(id)end)
        navButtons[id]=row
        local content=CreateFrame("Frame",nil,body)
        content:SetAllPoints(body)
        page.sections[id]=content
        content:Hide()
    end
    -- Everyday controls live together instead of scattering a few buttons
    -- across Appearance, Overview and other single-purpose pages.
    do
        local p=page.sections.general
        Heading(p,"General","How Foundry opens, looks and welcomes new adventurers.")
        Check(p,"rememberFoundryPage","Remember my last page",
            "Reopen Foundry where you left off instead of always opening Overview.",-108)
        Check(p,"showNavigationTooltips","Navigation tooltips",
            "Show page names while hovering the sidebar.",-165,nil,"left")
        Check(p,"autoHideInCombat","Auto-hide in combat",
            "Hide the journal in combat; restore it afterward.",-165,
            function(enabled)
                if enabled and type(InCombatLockdown)=="function" and InCombatLockdown()
                    and UI.HandleCombatVisibility then UI:HandleCombatVisibility(true) end
            end,"right")

        local scaleTitle=Text(p,"INTERFACE","GameFontNormalSmall",.93,.78,.51)
        scaleTitle:SetPoint("TOPLEFT",19,-241)
        local scaleHint=Text(p,"SCALE","GameFontHighlightSmall",.73,.70,.66)
        scaleHint:SetPoint("TOPLEFT",19,-262)
        local scaleValue=Text(p,"","GameFontHighlightSmall",1,.83,.50)
        scaleValue:SetPoint("TOPLEFT",p,"TOPLEFT",195,-279)
        scaleValue:SetSize(90,30)
        local function RefreshScale()
            scaleValue:SetText(tostring(math.floor((settings.interfaceScale or 1)*100+.5)).."%")
        end
        local function ChangeScale(delta,reset)
            local old=tonumber(settings.interfaceScale) or 1
            local value=reset and 1 or old+delta
            settings.interfaceScale=math.max(.80,math.min(1.15,math.floor(value*100+.5)/100))
            if UI.frame and UI.frame.SetScale then UI.frame:SetScale(settings.interfaceScale) end
            RefreshScale()
        end
        RowButtons(p,-280,{
            {"- 5%",function()ChangeScale(-.05)end,69},
            {"+ 5%",function()ChangeScale(.05)end,69},
            {"Reset",function()ChangeScale(0,true)end,80},
        })
        scaleValue:ClearAllPoints()
        scaleValue:SetPoint("TOPLEFT",p,"TOPLEFT",274,-280)
        scaleValue:SetHeight(30)
        refreshers[#refreshers+1]=RefreshScale
        RefreshScale()

        local opacityTitle=Text(p,"WINDOW OPACITY","GameFontHighlightSmall",.73,.70,.66)
        opacityTitle:SetPoint("TOPLEFT",397,-262)
        local opacitySlider=CreateFrame("Slider",nil,p)
        opacitySlider:SetOrientation("HORIZONTAL")
        opacitySlider:SetPoint("TOPLEFT",p,"TOPLEFT",402,-289)
        opacitySlider:SetSize(213,19)
        opacitySlider:SetMinMaxValues(.40,1)
        opacitySlider:SetValueStep(.05)
        if opacitySlider.SetObeyStepOnDrag then opacitySlider:SetObeyStepOnDrag(true) end
        opacitySlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        local opacityTrack=opacitySlider:CreateTexture(nil,"BACKGROUND")
        opacityTrack:SetPoint("LEFT",opacitySlider,"LEFT",0,0)
        opacityTrack:SetPoint("RIGHT",opacitySlider,"RIGHT",0,0)
        opacityTrack:SetHeight(7)
        opacityTrack:SetColorTexture(.29,.26,.24,1)
        local opacityValue=Text(p,"","GameFontHighlightSmall",1,.83,.50)
        opacityValue:SetPoint("TOPLEFT",p,"TOPLEFT",633,-280)
        opacityValue:SetSize(65,30)
        local settingOpacity=false
        local function RefreshOpacity()
            local current=settings.windowOpacity or 1
            opacityValue:SetText(tostring(math.floor(current*100+.5)).."%")
            settingOpacity=true
            opacitySlider:SetValue(current)
            settingOpacity=false
        end
        opacitySlider:SetScript("OnValueChanged",function(_,rawValue)
            if settingOpacity then return end
            local value=math.max(.40,math.min(1,math.floor(rawValue*20+.5)/20))
            settings.windowOpacity=value
            if UI.ApplyWindowOpacity then UI:ApplyWindowOpacity() end
            opacityValue:SetText(tostring(math.floor(value*100+.5)).."%")
        end)
        if UI.RegisterThemeTarget then UI:RegisterThemeTarget(opacityTrack,function(tex,t)
            local color=t.divider or t.accent
            tex:SetColorTexture(color[1],color[2],color[3],.72)
        end) end
        refreshers[#refreshers+1]=RefreshOpacity
        RefreshOpacity()
        Line(p,-343)

        local introTitle=Text(p,"SELF-FOUND CHARACTER PROMPTS","GameFontNormalSmall",.93,.78,.51)
        introTitle:SetPoint("TOPLEFT",19,-367)
        local promptNote=Note(p,"Once Self-Found is enabled, opening its tab offers an introduction to newly registered characters.",-390,43)
        local promptButtons={}
        local function RefreshPrompt()
            local preference=AF.GetInitiationPreference and AF:GetInitiationPreference() or "ask"
            for _,entry in ipairs(promptButtons) do entry.button:SetSelected(entry.key==preference) end
        end
        local promptOptions={{"ask","Ask on first visit",151},{"suggest","Suggest joining",137},{"off","No prompt",117}}
        local previous=nil
        for _,entry in ipairs(promptOptions) do
            local key=entry[1]
            local button=Button(p,entry[2],function()
                if AF.SetInitiationPreference then AF:SetInitiationPreference(key) end
                RefreshPrompt()
            end,entry[3])
            if previous then button:SetPoint("LEFT",previous,"RIGHT",8,0)
            else button:SetPoint("TOPLEFT",19,-439) end
            promptButtons[#promptButtons+1]={key=key,button=button}
            previous=button
        end
        refreshers[#refreshers+1]=RefreshPrompt
        RefreshPrompt()
        local preferenceNote=Note(p,"This preference affects future Self-Found introductions, not character memberships or charter rules.",-488,52)
        local preview=Button(p,"Preview welcome screen",function()
            local key=AF.GetCurrentKey and AF:GetCurrentKey()
            if key and UI.ShowExpeditionInitiation then
                UI:ShowExpeditionInitiation(key,true)
            else Print("The first-login preview is not available for this character.") end
        end,202)
        preview:SetPoint("TOPLEFT",19,-551)
        local guide=Button(p,"Read Adventurer's Guide",function()
            if UI.OpenAdventurersGuide then UI:OpenAdventurersGuide() end
        end,217)
        guide:SetPoint("LEFT",preview,"RIGHT",10,0)
        local offNote=Note(p,"Self-Found is hidden. Enable it in Settings > Modules if you want Expedition challenges.",-390,65)
        local function ShowPromptSettings()
            local enabled=AF:IsModuleEnabled("selfFound")
            introTitle:SetShown(enabled)
            promptNote:SetShown(enabled)
            preferenceNote:SetShown(enabled)
            preview:SetShown(enabled)
            for _,item in ipairs(promptButtons) do item.button:SetShown(enabled) end
            offNote:SetShown(not enabled)
            guide:ClearAllPoints()
            if enabled then guide:SetPoint("LEFT",preview,"RIGHT",10,0)
            else guide:SetPoint("TOPLEFT",p,"TOPLEFT",19,-471) end
        end
        refreshers[#refreshers+1]=ShowPromptSettings
        ShowPromptSettings()
    end
    do
        local p=page.sections.modules
        Heading(p,"Modules","Choose which optional Foundry features appear in your journal.")
        HeadingRow(p,"SELF-FOUND EXPEDITIONS  |  INCLUDED",
            "Optional charter rules, character enrollment, Chronicle and milestones.",-109)
        local toggle=Button(p,"",function()
            local enabled=not AF:IsModuleEnabled("selfFound")
            local ok,err=AF:SetModuleEnabled("selfFound",enabled)
            if not ok then Print(err);return end
            if p.RefreshModule then p:RefreshModule() end
        end,218)
        toggle:SetPoint("TOPLEFT",19,-181)
        local open=Button(p,"Open Self-Found",function() UI:Switch("Self-Found") end,188)
        open:SetPoint("LEFT",toggle,"RIGHT",10,0)
        Note(p,"On a new install Self-Found starts hidden. Enabling it adds its journal tab and offers an introduction when you open it. Disabling only hides its interface; no saved membership or milestone data is deleted.",-238,76)
        Note(p,"To protect an active challenge, finish its current Charter before disabling the module. Changes take effect immediately; a reload is not required.",-331,66)
        Line(p,-417)
        Note(p,"Future optional companion addons may be listed here after their own integration is developed. This screen does not load or install separate addons.",-438,78)
        p.RefreshModule=function()
            local enabled=AF:IsModuleEnabled("selfFound")
            toggle.label:SetText(enabled and "Disable Self-Found" or "Enable Self-Found")
            open:SetShown(enabled)
        end
        refreshers[#refreshers+1]=p.RefreshModule
        p:RefreshModule()
    end
    do
        -- Player choices are curated color palettes, not UV/atlas recipes.
        -- Art Lab remains a private authoring tool and is not loaded here.
        local p=page.sections.themes
        Heading(p,"Theme Studio","Choose a complete color palette, or mix global component families.")
        local name=Text(p,"THEME COLLECTION","GameFontNormalSmall",.94,.81,.52)
        name:SetPoint("TOPLEFT",19,-108)
        local presetButton=Button(p,"",function() end,310)
        presetButton:SetPoint("TOPLEFT",19,-132)
        presetButton:SetHeight(32)
        local customButton=Button(p,"Customize this theme",function()
            UI:SetThemeMode("custom")
            if p.RefreshThemeStudio then p:RefreshThemeStudio() end
        end,171)
        customButton:SetPoint("LEFT",presetButton,"RIGHT",9,0)
        local swatchFrame=CreateFrame("Frame",nil,p)
        swatchFrame:SetPoint("LEFT",customButton,"RIGHT",13,0)
        swatchFrame:SetSize(115,29)
        local swatches={}
        for i=1,6 do
            local t=swatchFrame:CreateTexture(nil,"ARTWORK")
            t:SetSize(17,25)
            t:SetPoint("LEFT",swatchFrame,"LEFT",(i-1)*19,0)
            swatches[i]=t
        end
        local modeHelp=Note(p,"",-174,36)
        local familyTitle=Text(p,"GLOBAL COMPONENT FAMILIES  -  LIVE EXAMPLES","GameFontNormalSmall",.94,.81,.52)
        familyTitle:SetPoint("TOPLEFT",19,-213)

        local ids={"border","background","button","navigation","accent"}
        local names={border="Window and Panel Borders",background="Backgrounds",button="Buttons and States",
            navigation="Navigation Tabs",accent="Accent Colors"}
        local display={}
        local openMenu=nil
        local function CloseMenu()
            if openMenu then openMenu:Hide();openMenu=nil end
        end
        local selectMenus={}
        for i,family in ipairs(ids) do
            local y=-235-(i-1)*48
            local row=CreateFrame("Frame",nil,p)
            row:SetPoint("TOPLEFT",19,y)
            row:SetPoint("TOPRIGHT",-19,y)
            row:SetHeight(42)
            row.afThemeSurfaceRole="dataRow"
            Fill(row,.16,.14,.125,.85,"dataRow")
            local label=Text(row,names[family],"GameFontHighlightSmall",.95,.86,.70)
            label:SetPoint("LEFT",10,0)
            label:SetWidth(186)
            local menu=CreateFrame("Frame",nil,p)
            local options=UI.ThemeOptions and UI:ThemeOptions(family) or {}
            -- All 22 presets may be used for each family; contain the flyout
            -- in a scroll viewport rather than creating a screen-high menu.
            local viewportHeight=235
            menu:SetSize(278,viewportHeight+12)
            menu:SetFrameLevel(p:GetFrameLevel()+115)
            if i>=3 then menu:SetPoint("BOTTOMRIGHT",row,"TOPRIGHT",-7,-2)
            else menu:SetPoint("TOPRIGHT",row,"BOTTOMRIGHT",-7,2) end
            Fill(menu,.115,.087,.061,1,"data")
            menu.afThemeSurfaceRole="data"
            if UI.Background then UI:Background(menu,UI.palette.leather,true) end
            menu:Hide()
            local dropdownScroll=CreateFrame("ScrollFrame",nil,menu)
            dropdownScroll:SetPoint("TOPLEFT",menu,"TOPLEFT",7,-6)
            dropdownScroll:SetPoint("BOTTOMRIGHT",menu,"BOTTOMRIGHT",-18,6)
            local dropdownChild=CreateFrame("Frame",nil,dropdownScroll)
            dropdownChild:SetWidth(248)
            dropdownChild:SetHeight(math.max(1,#options*31+6))
            dropdownScroll:SetScrollChild(dropdownChild)
            local maxMenuScroll=math.max(0,#options*31+6-viewportHeight)
            dropdownScroll:EnableMouseWheel(true)
            dropdownScroll:SetScript("OnMouseWheel",function(_,delta)
                dropdownScroll:SetVerticalScroll(math.max(0,math.min(maxMenuScroll,
                    (dropdownScroll:GetVerticalScroll() or 0)-delta*62)))
            end)
            local scrollTrack=menu:CreateTexture(nil,"ARTWORK")
            scrollTrack:SetPoint("TOPRIGHT",menu,"TOPRIGHT",-8,-10)
            scrollTrack:SetPoint("BOTTOMRIGHT",menu,"BOTTOMRIGHT",-8,10)
            scrollTrack:SetWidth(3)
            scrollTrack:SetColorTexture(.5,.43,.37,.6)
            local selectButton=Button(row,"",function()
                if openMenu==menu and menu:IsShown() then CloseMenu();return end
                CloseMenu();dropdownScroll:SetVerticalScroll(0);menu:Show();openMenu=menu
            end,264)
            selectButton:SetHeight(28)
            selectButton:SetPoint("RIGHT",row,"RIGHT",-8,0)
            if UI.CreateThemeFamilyPreview then
                local sample=UI:CreateThemeFamilyPreview(row,family)
                sample:SetPoint("RIGHT",selectButton,"LEFT",-12,0)
            end
            for j,entry in ipairs(options) do
                local choice=entry[1]
                local item=Button(dropdownChild,entry[2],function()
                    CloseMenu()
                    if UI.SetThemeFamily then UI:SetThemeFamily(family,choice) end
                    if p.RefreshThemeStudio then p:RefreshThemeStudio() end
                end,242)
                item:SetHeight(28)
                item:SetPoint("TOPLEFT",dropdownChild,"TOPLEFT",3,-3-(j-1)*31)
            end
            display[family]=selectButton.label
            selectMenus[#selectMenus+1]=menu
        end

        -- Scrollable theme chooser: all 22 presets remain visible/accessible,
        -- without dozens of oversized buttons overflowing the Settings page.
        local presets=UI.ThemePresets and UI:ThemePresets() or {}
        local presetMenu=CreateFrame("Frame",nil,p)
        presetMenu:SetPoint("TOPLEFT",presetButton,"BOTTOMLEFT",0,-3)
        presetMenu:SetSize(335,305)
        presetMenu:SetFrameLevel(p:GetFrameLevel()+100)
        Fill(presetMenu,.094,.09,.095,1,"data")
        presetMenu.afThemeSurfaceRole="data"
        if UI.Background then UI:Background(presetMenu,UI.palette.leather,true) end
        local scroll=CreateFrame("ScrollFrame",nil,presetMenu)
        scroll:SetPoint("TOPLEFT",presetMenu,"TOPLEFT",6,-6)
        scroll:SetPoint("BOTTOMRIGHT",presetMenu,"BOTTOMRIGHT",-18,6)
        local child=CreateFrame("Frame",nil,scroll)
        child:SetSize(309,1)
        scroll:SetScrollChild(child)
        local y=0
        local lastGroup=nil
        for _,info in ipairs(presets) do
            if info.group~=lastGroup then
                local heading=Text(child,info.group,"GameFontNormalSmall",.94,.72,.47)
                heading:SetPoint("TOPLEFT",child,"TOPLEFT",8,-(y+5))
                heading:SetSize(272,20)
                y=y+26
                lastGroup=info.group
            end
            local line=CreateFrame("Button",nil,child)
            line:RegisterForClicks("LeftButtonUp")
            line:SetHeight(30)
            line:SetPoint("TOPLEFT",child,"TOPLEFT",4,-y)
            line:SetPoint("TOPRIGHT",child,"TOPRIGHT",-4,-y)
            line.afThemeSurfaceRole="dataRow"
            local lbg=Fill(line,.17,.16,.17,1,"dataRow")
            local mark=line:CreateTexture(nil,"ARTWORK")
            mark:SetPoint("LEFT",line,"LEFT",8,0)
            mark:SetSize(20,20)
            local label=Text(line,info.label,"GameFontHighlightSmall",.95,.91,.85)
            label:SetPoint("LEFT",line,"LEFT",36,0)
            label:SetPoint("RIGHT",line,"RIGHT",-7,0)
            local function paintOption(hover)
                local t=UI:ThemeTokens()
                local c=hover and t.hover or t.dataSurface
                lbg:SetColorTexture(c[1],c[2],c[3],1)
                local fg=UI.ThemeReadableText and UI:ThemeReadableText(c,t.dataText) or t.dataText
                label:SetTextColor(unpack(fg))
            end
            line:SetScript("OnEnter",function()paintOption(true)end)
            line:SetScript("OnLeave",function()paintOption(false)end)
            if UI.RegisterThemeTarget then UI:RegisterThemeTarget(line,function()paintOption(false)end) end
            line:SetScript("OnClick",function()
                CloseMenu()
                UI:SetThemeMode(info.id)
                if p.RefreshThemeStudio then p:RefreshThemeStudio() end
            end)
            -- A preview of the actual source class/accent color.
            local current=info.hex
            if current then
                mark:SetColorTexture(tonumber(current:sub(1,2),16)/255,
                    tonumber(current:sub(3,4),16)/255,tonumber(current:sub(5,6),16)/255,1)
            else
                local c={classic={.78,.52,.28},forever={.75,.59,.36},modern={.33,.61,.84},
                    matrix={.3,1,.52},sprinkles={.95,.65,.84},light={.93,.92,.88},
                    dark={.28,.29,.33},midnight={.59,.50,.88},ember={.94,.48,.26}}
                local v=c[info.id] or {.7,.7,.7}
                mark:SetColorTexture(v[1],v[2],v[3],1)
            end
            y=y+31
        end
        child:SetHeight(y+8)
        local maxOffset=math.max(0,y+8-293)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel",function(_,delta)
            local v=(scroll:GetVerticalScroll() or 0)-delta*65
            scroll:SetVerticalScroll(math.max(0,math.min(maxOffset,v)))
        end)
        presetMenu:Hide()
        presetButton:SetScript("OnClick",function()
            if openMenu==presetMenu and presetMenu:IsShown() then CloseMenu();return end
            CloseMenu();presetMenu:Show();openMenu=presetMenu
        end)
        p.RefreshThemeStudio=function()
            CloseMenu()
            if not UI.ThemeMode then return end
            local mode=UI:ThemeMode()
            local info=UI:ThemePresetInfo(mode)
            local tokens=UI:ThemeTokens()
            presetButton.label:SetText((info and info.label or "Custom").."  v")
            modeHelp:SetText(info and (info.desc or (info.group=="CLASS THEMES" and
                "Official Warcraft class color with a coordinated dark interface." or "Color palette."))
                or "Custom theme - mix the five component families below.")
            for i,col in ipairs({tokens.shell,tokens.paper,tokens.accent,tokens.accent2,tokens.accent3,tokens.accent4}) do
                swatches[i]:SetColorTexture(col[1],col[2],col[3],1)
            end
            for _,family in ipairs(ids) do display[family]:SetText(UI:ThemeFamilyLabel(family).."  v") end
        end
        refreshers[#refreshers+1]=p.RefreshThemeStudio
        p:RefreshThemeStudio()
        local reset=Button(p,"Restore Classic",function()
            UI:SetThemeMode("classic")
            p:RefreshThemeStudio()
        end,201)
        reset:SetPoint("TOPLEFT",19,-480)
        Note(p,"Mix any preset's colors for each component. No atlas crops or journal-data changes.",-512,50)
    end
    -- Diagnostics are optional and kept out of the routine pages.
    -- The legacy renderer remains available here as a safe fallback.
    do
        local p=page.sections.maintenance
        Heading(p,"Data & Tools","Refresh recorded information and access optional diagnostics.")
        HeadingRow(p,"Current character snapshot",
            "Refresh character details or bags without deleting stored history.",-108)
        RowButtons(p,-187,{
            {"Rescan Character",function()
                if AF.ScanCharacter then AF:ScanCharacter() end
                if AF.RefreshUI then AF:RefreshUI() end
                Print("Current character snapshot refreshed.")
            end,165},
            {"Rescan Bags",function()
                if AF.ScanBags then AF:ScanBags() end
                if AF.RefreshUI then AF:RefreshUI() end
                Print("Available bag information refreshed.")
            end,135},
        })
        Note(p,"These actions do not erase Expedition records, discoveries, professions, saved layouts or goals.",-242,55)
        Line(p,-318)
        local developerTitle=Text(p,"DEVELOPER & TROUBLESHOOTING","GameFontNormalSmall",.93,.78,.51)
        developerTitle:SetPoint("TOPLEFT",19,-338)
        Check(p,"devMode","Enable developer controls",
            "Show debugging, test notifications and compatibility recovery tools.",-367,
            function() if p.ShowDeveloperControls then p:ShowDeveloperControls() end end)
        local tools={}
        local function Tool(label,x,y,width,callback)
            local b=Button(p,label,callback,width or 165)
            b:SetPoint("TOPLEFT",p,"TOPLEFT",x,y)
            tools[#tools+1]=b
            return b
        end
        -- The private Art Lab authoring workflow is intentionally not exposed
        -- through the player addon, even with developer controls enabled.
        Tool("Atlas Debugger",19,-444,155,function()
            UI:Switch("Exploration")
            local atlas=UI.pageViews and UI.pageViews.Exploration
            if atlas and atlas.ToggleMapDebug then
                local ok,err=pcall(atlas.ToggleMapDebug,atlas)
                if not ok then Print("Atlas debugger: "..tostring(err)) end
            else Print("Atlas debugger is not available in this client.") end
        end)
        Tool("Atlas Diagnostics",184,-444,155,function()
            if SlashCmdList and SlashCmdList.AZEROTHFOUNDRY then
                SlashCmdList.AZEROTHFOUNDRY("atlasdebug")
            end
        end)
        Tool("Test Milestone",19,-481,155,function()
            if UI.TestGoalToast then UI:TestGoalToast("milestone") end
        end)
        Tool("Test Completion",184,-481,155,function()
            if UI.TestGoalToast then UI:TestGoalToast("complete") end
        end)
        local legacy=Tool("",19,-518,185,function()
            settings.legacyOverview=not settings.legacyOverview
            Print("Overview renderer changed. Type /reload to apply.")
            if p.RefreshLegacy then p:RefreshLegacy() end
        end)
        p.RefreshLegacy=function()
            legacy.label:SetText(settings.legacyOverview and "Restore modular Overview" or "Use legacy Overview")
        end
        refreshers[#refreshers+1]=p.RefreshLegacy
        p:RefreshLegacy()
        local developerHelp=Note(p,"Legacy Overview is an emergency fallback. It needs /reload; your modular widget layout is retained.",-562,43)
        function p:ShowDeveloperControls()
            local enabled=settings.devMode==true
            for _,control in ipairs(tools) do control:SetShown(enabled) end
            developerHelp:SetShown(enabled)
        end
        refreshers[#refreshers+1]=function()p:ShowDeveloperControls()end
        p:ShowDeveloperControls()
        Note(p,"Settings save automatically. No global reset or data deletion is performed here.",-291,24)
    end
    page.SelectSettingsSection=function(first,second)
        -- Support both page.SelectSettingsSection("themes") and
        -- page:SelectSettingsSection("themes") without mismapping the ID.
        Select(second or first)
    end
    page.Refresh=function(self)
        for _,fn in ipairs(refreshers) do fn() end
    end
    Select(selected)
end
