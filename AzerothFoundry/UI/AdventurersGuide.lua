-- Azeroth Foundry: optional, account-wide Adventurer's Guide.
-- This guide never enrolls a character, starts a craft, or changes gameplay data.
local _, AF = ...
local UI = AF.UI
local unpack = unpack or table.unpack

local STEPS = {
    { title="Welcome to Foundry", nav="Start Here", icon="Interface\\Icons\\INV_Misc_Book_11", route="Overview",
      lead="One journal for your account, characters, and adventures.",
      body="Azeroth Foundry records information that the client makes available while you play. You can track your characters, recipes, crafting plans, exploration, discoveries, goals and notes in one window.\n\nYour records are stored locally in WoW SavedVariables, not uploaded to a server. You can explore at your own pace: every major activity is optional.",
      tip="Start with Overview, then visit any section using the left navigation." },
    { title="Overview", nav="Overview", icon="Interface\\Icons\\INV_Misc_Book_11", route="Overview",
      lead="Your customizable, at-a-glance dashboard.",
      body="Overview is a customizable welcome-back dashboard for characters, goals, crafting, exploration, collections and notes. Optional Self-Found adds Expedition information. Use Presets or add, resize, dock and hide individual widgets.\n\nThe arrangement is saved automatically. Applying a new preset replaces the current arrangement only after you confirm.",
      tip="Click a widget header to visit the corresponding page." },
    { title="Characters", nav="Characters", icon="Interface\\Icons\\INV_Misc_GroupLooking", route="Characters",
      lead="View the registered adventurers on this account.",
      body="Characters collects recorded information about your adventurers, including account trackers, profession details and playtime. Switch between alts to see their last recorded activity.\n\nIf you enable the optional Self-Found module, this page also adds Expedition membership and history. You do not need that module to use Foundry.",
      tip="Information from offline characters reflects their last recorded snapshot." },
    { title="Professions", nav="Professions", icon="Interface\\Icons\\Trade_BlackSmithing", route="Professions",
      lead="Compare skills and training progress across crafters.",
      body="The Professions page shows recorded skills for your characters, including their current progress and training goals. Foundry updates information when available through the client and profession windows.\n\nSwitch characters to gather additional profession data. Some reference databases are optional and need not be installed to use the journal.",
      tip="A skill or recipe that hasn't been scanned is not automatically unlearned." },
    { title="Recipes", nav="Recipes", icon="Interface\\Icons\\INV_Misc_Book_09", route="Recipes",
      lead="Find known recipes, inspect reagents and choose what happens next.",
      body="Search recorded recipes, filter them by crafter or profession, and inspect recorded reagents. From a learned recipe you can add a normal craft to Crafting Queue, create a crafting Goal, or make a Guided Goal.\n\nThese are separate actions. Adding a recipe to the queue does not create a Goal.",
      tip="The library is discovery-based; it does not list every recipe in the game." },
    { title="Crafting Queue", nav="Crafting Queue", icon="Interface\\Icons\\INV_Gizmo_02", route="Crafting Queue",
      lead="Turn your planned crafts into produced items.",
      body="Prioritize and reorder queued items, then use Craft 1 or Craft All from the selected craft. Foundry prepares an available profession context and tracks queue progress from actual crafted-item results. You can also remove a queued craft without deleting a Goal.\n\nThe native profession interface may open invisibly while crafting. Open Profession reveals it whenever you want. Different queued recipes are separate player-controlled actions.",
      tip="Account-wide material estimates are not the same as reagents available in this character's bags." },
    { title="Materials", nav="Materials", icon="Interface\\Icons\\INV_Misc_Bag_10", route="Materials",
      lead="An inventory snapshot and ledger for your crafters.",
      body="Explore recorded supplies from character bags and bank visits, with profession filters and combined-name display options. Review where the addon last observed a reagent before planning a craft.\n\nOffline characters and bank contents may have changed since their last scan. Materials shown as recorded are not automatically usable by the current crafter.",
      tip="Use the bag rescan in Settings when you need a fresher current-character snapshot." },
    { title="Atlas & Quests", nav="Exploration & Quests", icon="Interface\\Icons\\INV_Misc_Map_01", route="Exploration",
      lead="Track where you've been and which stories you've observed.",
      body="The Atlas displays map regions, recorded exploration, fog, quest markers and visit information where the game client provides them. The Quest Journal and Recap let you revisit recorded quest text and progression.\n\nThe available map layers and exploration criteria depend on the WoW client and its exposed APIs; unsupported information is not invented.",
      tip="Use the Atlas to navigate to an observed quest or explore an area without revealing everything first." },
    { title="Collections", nav="Collections", icon="Interface\\Icons\\INV_Misc_Bag_10", route="Collections",
      lead="A discovery-first gallery for mounts, companions and more.",
      body="Browse recorded mounts, companions, toys and appearances using cards and detail previews. Owned and observed discoveries are separate from the optional broader reference views.\n\nFoundry's default is designed not to spoil every collectible you haven't encountered. Recorded discoveries are not a complete account of everything that exists in the world.",
      tip="Select a card to inspect its details and use the gallery filters to change what you see." },
    { title="Goals", nav="Goals", icon="Interface\\Icons\\INV_Misc_Note_04", route="Goals",
      lead="Keep track of ambitions you intentionally choose.",
      body="Create personal projects and Guided Goals, organize their steps, and track their progress. Goals are separate from ordinary Crafting Queue entries: crafting something does not automatically mean it should become a long-term objective.\n\nGoals can be active, tracked or completed, and may be connected to other pages in your journal.",
      tip="Use Goals for things you want to accomplish, not every routine craft." },
    { title="Self-Found", nav="Self-Found", icon="Interface\\Icons\\INV_Misc_Key_14", route="Self-Found",
      lead="An optional Expedition challenge with milestones and a Chronicle.",
      body="Self-Found is an optional built-in module, OFF by default for new players. Enable it here or in Settings > Modules whenever you want Expedition challenges. Other features work normally without it.\n\nWith Self-Found enabled, create a voluntary Charter, enroll characters, review rule observations, and earn milestones. Its Chronicle records only what Foundry observed; it cannot prove compliance or reconstruct earlier play.",
      tip="Enable Self-Found when you want it. Your other journal data is never affected." },
    { title="Notes", nav="Notes", icon="Interface\\Icons\\INV_Scroll_03", route="Notes",
      lead="Your own written record of the adventure.",
      body="Write notes, keep discoveries and reminders, and attach supported references to parts of your journal. Notes remain available across the registered characters on this WoW account.\n\nNotes are stored locally alongside your other SavedVariables. Back up your SavedVariables when moving installations or reinstalling WoW.",
      tip="Use notes for context that isn't captured by automatic tracking." },
    { title="Theme Studio & Settings", nav="Themes & Settings", icon="Interface\\Icons\\INV_Gizmo_02", route="Settings", section="themes",
      lead="Make Foundry comfortable to use.",
      body="Theme Studio offers Classic, Forever, Modern, class-colored and playful visual presets, plus Custom combinations. General Settings controls scale and navigation.\n\nSettings > Modules controls the optional built-in Self-Found feature. Data & Tools provides rescans and diagnostics.",
      tip="This guide can be reopened any time with ? Guide or /af guide." },
}
UI.adventurersGuideSteps=STEPS

local function paint(tex,color,alpha)
    if not tex or not color then return end
    tex:SetColorTexture(color[1],color[2],color[3],alpha or 1)
end
local function label(parent,size,justify)
    local f=UI:Text(parent,size or "small",UI.palette.pale,justify or "LEFT")
    f.afThemeColorManaged=true
    if f.SetShadowOffset then f:SetShadowOffset(0,0) end
    if f.SetShadowColor then f:SetShadowColor(0,0,0,0) end
    return f
end
local function background(parent,layer)
    local tex=parent:CreateTexture(nil,layer or "BACKGROUND")
    tex:SetAllPoints(parent)
    return tex
end

function UI:OpenAdventurersGuide(startStep)
    if not self.frame then return false end
    if AF.db and AF.db.settings then AF.db.settings.guidePrompted=true end
    if not self.frame:IsShown() then self:Open() end
    if self.guideInvitation then self.guideInvitation:Hide() end
    if self.adventurersGuide and self.adventurersGuide:IsShown() then
        if startStep then self.adventurersGuide:SetGuideStep(startStep) end
        return true
    end
    if self.adventurersGuide then
        self.adventurersGuide:Show()
        self.adventurersGuide:SetGuideStep(startStep or (AF.db.settings.guideStep or 1))
        return true
    end
    local veil=CreateFrame("Frame",nil,self.frame)
    veil:SetAllPoints(self.frame)
    veil:SetFrameStrata("FULLSCREEN_DIALOG")
    veil:SetFrameLevel(self.frame:GetFrameLevel()+65)
    veil:EnableMouse(true)
    local dim=background(veil)
    dim:SetColorTexture(0,0,0,.70)
    local panel=CreateFrame("Frame",nil,veil)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel(veil:GetFrameLevel()+2)
    panel:SetSize(810,570)
    panel:SetPoint("CENTER",self.frame,"CENTER")
    self:Background(panel,self.palette.leather,true)
    local surround=background(panel)

    local heading=label(panel,"title")
    heading:SetPoint("TOPLEFT",panel,"TOPLEFT",23,-19)
    heading:SetWidth(620);heading:SetHeight(28)
    heading:SetText("THE ADVENTURER'S GUIDE")
    local close=self:Button(panel,"Close",function()veil:Hide()end)
    close:SetSize(90,27)
    close:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-22,-18)
    local summary=label(panel,"small")
    summary:SetPoint("TOPLEFT",panel,"TOPLEFT",23,-55)
    summary:SetSize(725,21)
    summary:SetText("Optional help for every major part of Azeroth Foundry. Nothing here changes your records.")
    local rule=panel:CreateTexture(nil,"BORDER")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT",panel,"TOPLEFT",20,-82)
    rule:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-20,-82)
    local left=CreateFrame("Frame",nil,panel)
    left:SetPoint("TOPLEFT",panel,"TOPLEFT",20,-94)
    left:SetSize(218,421)
    local leftBg=background(left)
    local right=CreateFrame("Frame",nil,panel)
    right:SetPoint("TOPLEFT",left,"TOPRIGHT",10,0)
    right:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-20,55)
    local rightBg=background(right)
    local stepButtons={}
    local active=1
    local title=label(right,"title")
    title:SetPoint("TOPLEFT",right,"TOPLEFT",22,-22)
    title:SetPoint("TOPRIGHT",right,"TOPRIGHT",-20,-22)
    title:SetHeight(25)
    local icon=right:CreateTexture(nil,"ARTWORK")
    icon:SetPoint("TOPRIGHT",right,"TOPRIGHT",-20,-55)
    icon:SetSize(44,44)
    local lead=label(right,"small")
    lead:SetPoint("TOPLEFT",right,"TOPLEFT",22,-62)
    lead:SetPoint("TOPRIGHT",right,"TOPRIGHT",-78,-62)
    lead:SetHeight(45);lead:SetJustifyV("TOP")
    local body=label(right,"small")
    body:SetPoint("TOPLEFT",right,"TOPLEFT",22,-130)
    body:SetPoint("BOTTOMRIGHT",right,"BOTTOMRIGHT",-22,88)
    body:SetJustifyV("TOP");body:SetWordWrap(true)
    local tipBg=right:CreateTexture(nil,"BACKGROUND")
    tipBg:SetPoint("BOTTOMLEFT",right,"BOTTOMLEFT",17,15)
    tipBg:SetPoint("BOTTOMRIGHT",right,"BOTTOMRIGHT",-17,15)
    tipBg:SetHeight(65)
    local tip=label(right,"small")
    tip:SetPoint("TOPLEFT",tipBg,"TOPLEFT",11,-9)
    tip:SetPoint("BOTTOMRIGHT",tipBg,"BOTTOMRIGHT",-10,8)
    tip:SetJustifyV("TOP");tip:SetWordWrap(true)
    local progress=label(panel,"small")
    progress:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",24,17)
    progress:SetSize(170,23)
    local back=self:Button(panel,"< Back",function()veil:SetGuideStep(active-1)end)
    back:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-392,15);back:SetSize(100,28)
    local nextButton=self:Button(panel,"Next >",function()
        if active==#STEPS then veil:Hide() else veil:SetGuideStep(active+1) end
    end)
    nextButton:SetPoint("LEFT",back,"RIGHT",8,0);nextButton:SetSize(100,28)
    local go=self:Button(panel,"Open This Tab",function()
        local step=STEPS[active]
        if step and step.route=="Self-Found" and not AF:IsModuleEnabled("selfFound") then
            local ok,err=AF:SetModuleEnabled("selfFound",true)
            if not ok then AF.Print(err);return end
            veil.afOpenSelfFoundAfter=true
            veil:SetGuideStep(active)
            return
        end
        -- Direct navigation takes priority over a pending post-guide invitation.
        veil.afOpenSelfFoundAfter=false
        veil:Hide()
        if step and step.route then
            UI:Switch(step.route)
            if step.section and UI.pageViews and UI.pageViews.Settings then
                local settings=UI.pageViews.Settings
                if settings.SelectSettingsSection then settings.SelectSettingsSection(step.section) end
            end
        end
    end)
    go:SetPoint("LEFT",nextButton,"RIGHT",8,0);go:SetSize(160,28)
    local function draw()
        local t=UI.ThemeTokens and UI:ThemeTokens() or nil
        if not t then return end
        paint(surround,t.dataSurface)
        paint(leftBg,t.nav)
        paint(rightBg,t.surface)
        paint(rule,t.divider)
        paint(tipBg,t.raised)
        local light=t.dataText
        local bodyInk=UI.ThemeReadableText and UI:ThemeReadableText(t.surface,t.dataText) or t.dataText
        local tipInk=UI.ThemeReadableText and UI:ThemeReadableText(t.raised,t.dataText) or t.dataText
        heading:SetTextColor(unpack(UI:ThemeReadableText(t.dataSurface,t.accent2)))
        summary:SetTextColor(unpack(UI:ThemeReadableText(t.dataSurface,light)))
        progress:SetTextColor(unpack(UI:ThemeReadableText(t.dataSurface,light)))
        title:SetTextColor(unpack(UI:ThemeReadableText(t.surface,t.accent2)))
        lead:SetTextColor(unpack(bodyInk));body:SetTextColor(unpack(bodyInk))
        tip:SetTextColor(unpack(tipInk))
        for i,entry in ipairs(stepButtons) do
            local chosen=i==active
            local bg=chosen and t.navActive or t.nav
            paint(entry.base,bg,chosen and 1 or .72)
            entry.name:SetTextColor(unpack(UI:ThemeReadableText(bg,chosen and t.navSelectedText or t.navText)))
            paint(entry.mark,t.accent,chosen and 1 or 0)
        end
    end
    function veil:SetGuideStep(index)
        local i=math.min(#STEPS,math.max(1,math.floor(tonumber(index) or 1)))
        active=i
        if AF.db and AF.db.settings then AF.db.settings.guideStep=i end
        local step=STEPS[i]
        title:SetText(step.title)
        lead:SetText(step.lead)
        body:SetText(step.body)
        tip:SetText("TIP: "..step.tip)
        icon:SetTexture(step.icon)
        progress:SetText(i.." of "..#STEPS)
        back:SetEnabled(i>1)
        nextButton.label:SetText(i==#STEPS and "Finish" or "Next >")
        go.label:SetText(step.route=="Self-Found" and not AF:IsModuleEnabled("selfFound") and "Enable Self-Found" or "Open This Tab")
        draw()
    end
    for i,step in ipairs(STEPS) do
        local entry=CreateFrame("Button",nil,left)
        entry:SetPoint("TOPLEFT",left,"TOPLEFT",7,-8-(i-1)*30)
        entry:SetPoint("TOPRIGHT",left,"TOPRIGHT",-7,-8-(i-1)*30)
        entry:SetHeight(28)
        entry:RegisterForClicks("LeftButtonUp")
        entry.base=background(entry)
        entry.mark=entry:CreateTexture(nil,"ARTWORK")
        entry.mark:SetPoint("TOPLEFT",entry,"TOPLEFT",0,0)
        entry.mark:SetPoint("BOTTOMLEFT",entry,"BOTTOMLEFT",0,0)
        entry.mark:SetWidth(3)
        entry.name=label(entry,"small")
        entry.name:SetPoint("TOPLEFT",entry,"TOPLEFT",10,-1)
        entry.name:SetPoint("BOTTOMRIGHT",entry,"BOTTOMRIGHT",-5,1)
        entry.name:SetText(step.nav)
        entry:SetScript("OnClick",function()veil:SetGuideStep(i)end)
        entry:SetScript("OnEnter",function()draw()end)
        stepButtons[i]=entry
    end
    if self.RegisterThemeTarget then self:RegisterThemeTarget(veil,function()draw()end) end
    self.adventurersGuide=veil
    veil:SetScript("OnHide",function()
        local shouldOpen=veil.afOpenSelfFoundAfter
        veil.afOpenSelfFoundAfter=false
        -- Parent window may have been closed instead of the Guide itself.
        if shouldOpen and UI.frame and UI.frame:IsShown() then
            UI:Open("Self-Found")
        end
    end)
    veil:SetGuideStep(startStep or (AF.db.settings.guideStep or 1))
    return true
end

function UI:ShowGuideInvitation()
    local settings=AF.db and AF.db.settings
    if not settings or settings.guidePrompted~=false or not self.frame then return false end
    if self.guideInvitation then self.guideInvitation:Show();return true end
    local veil=CreateFrame("Frame",nil,self.frame)
    veil:SetAllPoints(self.frame)
    veil:SetFrameStrata("FULLSCREEN_DIALOG")
    veil:SetFrameLevel(self.frame:GetFrameLevel()+70)
    veil:EnableMouse(true)
    local dim=background(veil)
    dim:SetColorTexture(0,0,0,.69)
    local panel=CreateFrame("Frame",nil,veil)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel(veil:GetFrameLevel()+2)
    panel:SetSize(525,215)
    panel:SetPoint("CENTER",self.frame,"CENTER")
    self:Background(panel,self.palette.leather,true)
    local title=label(panel,"title")
    title:SetPoint("TOPLEFT",panel,"TOPLEFT",23,-20)
    title:SetSize(470,29)
    title:SetText("Welcome to Azeroth Foundry")
    local body=label(panel,"small")
    body:SetPoint("TOPLEFT",panel,"TOPLEFT",23,-61)
    body:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-23,-61)
    body:SetHeight(66)
    body:SetJustifyV("TOP")
    body:SetText("Welcome! Foundry is a journal for characters, crafting, exploration and goals. Take a short tour, or jump straight in. Self-Found challenges are optional and can be enabled later in Settings > Modules.")
    local start=self:Button(panel,"Start Guide",function()
        settings.guidePrompted=true
        veil:Hide()
        UI:OpenAdventurersGuide(1)
    end)
    start:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",23,22);start:SetSize(195,32)
    local skip=self:Button(panel,"Not Now",function()
        settings.guidePrompted=true
        veil:Hide()
    end)
    skip:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-23,22);skip:SetSize(140,32)
    if self.RegisterThemeTarget then self:RegisterThemeTarget(veil,function(_,t)
        title:SetTextColor(unpack(UI:ThemeReadableText(t.dataSurface,t.accent2)))
        body:SetTextColor(unpack(UI:ThemeReadableText(t.dataSurface,t.dataText)))
    end) end
    self.guideInvitation=veil
    return true
end
