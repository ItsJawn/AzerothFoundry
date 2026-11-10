-- Azeroth Foundry: bundled release notes. This window is presentation-only.
-- Data is bundled in Lua because game addons cannot read changelog files at runtime.
local _, AF = ...
local UI = AF.UI
local unpack = unpack or table.unpack
local max, min = math.max, math.min

local RELEASE = {
    version = '1.0.31',
    subtitle = 'Training Guides, Smart Alternatives & Stability',
    sections = {
        {
            title = 'Training Routes 1 - 300',
            icon = 'Interface\\Icons\\Trade_LeatherWorking',
            bullets = {
                'Eight independently maintained guides: Leatherworking, Alchemy, Blacksmithing, Enchanting, Engineering, Tailoring, Cooking and First Aid.',
                'Extended curated milestones through skill 300; special trainer, vendor, book and manual unlocks are identified where documented.',
                'Corrected selected Tailoring, Leatherworking and Blacksmithing skill transitions using Forever-specific reference thresholds.',
                'Unknown client recipe requirements remain flagged; guide coverage is not proof that every step is learned or craftable.',
            },
        },
        {
            title = 'Cleaner Training Tree',
            icon = 'Interface\\Icons\\INV_Misc_Map_01',
            bullets = {
                'Consecutive uses of the same recipe are consolidated into one overview node, without combining live crafting batches.',
                'Focused milestones keep selectable underlying skill bands, material branches, native icons, cast progress and Craft 1 / Craft All.',
                'Route Review flags unusually long recipe stretches and recipes reused after an interruption.',
                'Three-stage overview/detail/focus zoom, easing, panning and optional milestone fanfare are retained.',
            },
        },
        {
            title = 'Prices & Personal Alternatives',
            icon = 'Interface\\Icons\\INV_Misc_Coin_01',
            bullets = {
                'Training comparisons now consider Auctionator quotes and observed vendor purchase prices, with labeled reference prices for common supplies.',
                'A green Recommended Alternative requires a learned recipe, complete quotes, lower expected total cost and equal-or-better skill-up odds throughout the band.',
                'Alternatives never silently replace the curated guide. Missing prices, uncertain difficulty and potential AH sale margins are not guaranteed savings.',
            },
        },
        {
            title = 'Stability & Compatibility',
            icon = 'Interface\\Icons\\INV_Misc_Gear_01',
            bullets = {
                'Fixed the Training profession-selector Lua error and improved profession switching and native scan preparation.',
                'Reduced repeated graph rebuilds during zoom animations while preserving the existing crafting and scanning safety checks.',
                'Profession guide data now resides in separate Lua files with shared validation and calculation helpers.',
                'No SavedVariables reset is required. All existing Foundry themes, collections, Atlas, characters, goals and Workshop pages remain available.',
            },
        },
        {
            title = 'New in v1.0.31',
            icon = 'Interface\\Icons\\INV_Misc_Note_04',
            bullets = {
                'A Changelog button beside the Adventurer\'s Guide opens these bundled release notes at any time.',
                'Completed release-candidate source, loading-order and data-integrity checks without changing the established Training route or crafting logic.',
            },
        },
    },
}
UI.releaseNotes = RELEASE

local function Tint(texture, color, alpha)
    if texture and color then
        texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
    end
end

function UI:OpenChangelog()
    if not self.frame then return false end
    if not self.frame:IsShown() then self:Open() end
    if self.adventurersGuide and self.adventurersGuide:IsShown() then
        self.adventurersGuide:Hide()
    end
    if self.changelogOverlay then
        self.changelogOverlay:Show()
        if self.changelogScroll then self.changelogScroll:SetVerticalScroll(0) end
        if self.changelogSlider then self.changelogSlider:SetValue(0) end
        return true
    end

    local veil = CreateFrame('Frame', 'AzerothFoundryChangelog', self.frame)
    veil:SetAllPoints(self.frame)
    veil:SetFrameStrata('FULLSCREEN_DIALOG')
    veil:SetFrameLevel(self.frame:GetFrameLevel()+72)
    veil:EnableMouse(true)
    local dim = veil:CreateTexture(nil,'BACKGROUND')
    dim:SetAllPoints(veil)
    dim:SetColorTexture(0,0,0,.74)

    local panel = CreateFrame('Frame',nil,veil)
    panel:SetFrameStrata('FULLSCREEN_DIALOG')
    panel:SetFrameLevel(veil:GetFrameLevel()+2)
    panel:SetSize(850,594)
    panel:SetPoint('CENTER',self.frame,'CENTER')
    panel:EnableMouse(true)
    self:Background(panel,self.palette.leather,true)

    local function Label(parent,style,txt,x,y,width,height)
        local f=self:Text(parent,style,self.palette.pale)
        f.afThemeColorManaged=true
        f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y)
        f:SetSize(width,height)
        f:SetJustifyV('TOP')
        f:SetText(txt)
        return f
    end
    local title = Label(panel,'title','AZEROTH FOUNDRY  /  CHANGELOG',23,17,625,30)
    local subtitle = Label(panel,'small','v'..RELEASE.version..'  -  '..RELEASE.subtitle,23,50,690,24)
    local close = self:Button(panel,'Close',function() veil:Hide() end)
    close:SetPoint('TOPRIGHT',panel,'TOPRIGHT',-22,-19)
    close:SetSize(92,28)
    local rule = panel:CreateTexture(nil,'ARTWORK')
    rule:SetPoint('TOPLEFT',panel,'TOPLEFT',20,-86)
    rule:SetPoint('TOPRIGHT',panel,'TOPRIGHT',-20,-86)
    rule:SetHeight(2)

    local scroll = CreateFrame('ScrollFrame',nil,panel)
    scroll:SetPoint('TOPLEFT',panel,'TOPLEFT',23,-105)
    scroll:SetPoint('BOTTOMRIGHT',panel,'BOTTOMRIGHT',-52,52)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame('Frame',nil,scroll)
    content:SetSize(755,1)
    scroll:SetScrollChild(content)
    local sectionTitles,sectionText,sectionRules={},{},{}
    local y=10
    for _,section in ipairs(RELEASE.sections) do
        local icon=content:CreateTexture(nil,'ARTWORK')
        icon:SetTexture(section.icon)
        icon:SetPoint('TOPLEFT',content,'TOPLEFT',4,-y)
        icon:SetSize(22,22)
        local head=Label(content,'title',section.title,37,y-2,689,28)
        sectionTitles[#sectionTitles+1]=head
        y=y+35
        for _,bullet in ipairs(section.bullets) do
            local line=Label(content,'small','-  '..bullet,18,y,718,18)
            -- Text wrapping is measured after setting width, before advancing.
            local measured=line.GetStringHeight and line:GetStringHeight() or 0
            local lines=max(1,math.ceil((#bullet+4)/98))
            local height=max(21,math.ceil(measured)+4,lines*17+3)
            line:SetHeight(height)
            sectionText[#sectionText+1]=line
            y=y+height+5
        end
        local separator=content:CreateTexture(nil,'ARTWORK')
        separator:SetPoint('TOPLEFT',content,'TOPLEFT',13,-y)
        separator:SetSize(717,1)
        sectionRules[#sectionRules+1]=separator
        y=y+23
    end
    content:SetHeight(max(10,y))

    local rail=panel:CreateTexture(nil,'BACKGROUND')
    rail:SetPoint('TOPLEFT',scroll,'TOPRIGHT',7,0)
    rail:SetPoint('BOTTOMRIGHT',scroll,'BOTTOMRIGHT',18,0)
    local slider=CreateFrame('Slider',nil,panel)
    slider:SetOrientation('VERTICAL')
    slider:SetPoint('TOPRIGHT',scroll,'TOPRIGHT',16,-6)
    slider:SetPoint('BOTTOMRIGHT',scroll,'BOTTOMRIGHT',16,6)
    slider:SetWidth(12)
    slider:SetMinMaxValues(0,max(0,y-435))
    slider:SetValueStep(1)
    local knob=slider:CreateTexture(nil,'OVERLAY')
    knob:SetSize(12,37)
    knob:SetColorTexture(.75,.57,.28,.9)
    slider:SetThumbTexture(knob)
    slider:SetScript('OnValueChanged',function(_,v)
        scroll:SetVerticalScroll(v)
    end)
    local function UpdateScroll()
        local maximum=max(0,content:GetHeight()-scroll:GetHeight())
        slider:SetMinMaxValues(0,maximum)
        slider:SetShown(maximum>0)
        rail:SetShown(maximum>0)
        slider:SetValue(min(maximum,slider:GetValue() or 0))
    end
    scroll:SetScript('OnMouseWheel',function(_,delta)
        local value=slider:GetValue() or 0
        slider:SetValue(value-delta*49)
    end)
    scroll:SetScript('OnSizeChanged',UpdateScroll)
    veil:SetScript('OnShow',function()
        UpdateScroll()
        scroll:SetVerticalScroll(0)
        slider:SetValue(0)
    end)

    local footer=Label(panel,'small',
        'Release notes reflect this installed addon. No game data is modified by opening this window.',
        24,553,790,24)

    if self.RegisterThemeTarget then
        self:RegisterThemeTarget(veil,function(_,t)
            local headerInk=self:ThemeReadableText(t.dataSurface,t.accent2)
            local bodyInk=self:ThemeReadableText(t.dataSurface,t.dataText)
            title:SetTextColor(unpack(headerInk))
            subtitle:SetTextColor(unpack(bodyInk))
            footer:SetTextColor(unpack(bodyInk))
            for _,heading in ipairs(sectionTitles) do heading:SetTextColor(unpack(headerInk)) end
            for _,body in ipairs(sectionText) do body:SetTextColor(unpack(bodyInk)) end
            for _,separator in ipairs(sectionRules) do Tint(separator,t.divider,.40) end
            Tint(rule,t.accent2,.75)
            Tint(rail,t.raised,.95)
            Tint(knob,t.accent2,.9)
        end)
    end
    if UISpecialFrames then table.insert(UISpecialFrames,'AzerothFoundryChangelog') end
    self.changelogOverlay=veil
    self.changelogScroll=scroll
    self.changelogSlider=slider
    UpdateScroll()
    return true
end
