-- Azeroth Foundry v0.7.0.3: pure-color theme collection (no new atlas imports).
-- Classic/Forever/Modern, class-color collections, and fun preset palettes.
-- Class RGB values follow Blizzard's standard RAID_CLASS_COLORS values.
local _, AF = ...
local UI = AF.UI
local unpack = unpack or table.unpack
local KEYS = {"border", "background", "button", "navigation", "accent"}
local OPTIONS = {
    border = { {"quest", "Ornate Bronze"}, {"iron", "Black Iron"}, {"minimal", "Clean Line"} },
    background = { {"classic", "Warm Parchment"}, {"leather", "Dark Leather"}, {"slate", "Cool Slate"} },
    button = { {"classic", "Classic Crimson"}, {"bronze", "Forged Bronze"}, {"slate", "Flat Color"} },
    navigation = { {"bookmarks", "Classic Tabs"}, {"flat", "Flat Navigation"} },
    accent = { {"gold", "Warcraft Gold"}, {"silver", "Silver"}, {"arcane", "Arcane Blue"},
        {"forest", "Forest Green"}, {"pink", "Sprinkles Pink"}, {"matrix", "Matrix Green"} },
}
local PRESET_LIST = {
    {id="classic", label="Classic", group="WARCRAFT", desc="Aged parchment, bronze, oak brown and cream."},
    {id="forever", label="Forever", group="WARCRAFT", desc="Obsidian, blackened leather and restrained gold."},
    {id="modern", label="Modern", group="WARCRAFT", desc="Graphite, slate, steel and cool blue highlights."},
    {id="deathknight", label="Death Knight", group="CLASS THEMES", hex="C41E3A"},
    {id="demonhunter", label="Demon Hunter", group="CLASS THEMES", hex="A330C9"},
    {id="druid", label="Druid", group="CLASS THEMES", hex="FF7C0A"},
    {id="evoker", label="Evoker", group="CLASS THEMES", hex="33937F"},
    {id="hunter", label="Hunter", group="CLASS THEMES", hex="AAD372"},
    {id="mage", label="Mage", group="CLASS THEMES", hex="3FC7EB"},
    {id="monk", label="Monk", group="CLASS THEMES", hex="00FF98"},
    {id="paladin", label="Paladin", group="CLASS THEMES", hex="F48CBA"},
    {id="priest", label="Priest", group="CLASS THEMES", hex="FFFFFF"},
    {id="rogue", label="Rogue", group="CLASS THEMES", hex="FFF468"},
    {id="shaman", label="Shaman", group="CLASS THEMES", hex="0070DD"},
    {id="warlock", label="Warlock", group="CLASS THEMES", hex="8788EE"},
    {id="warrior", label="Warrior", group="CLASS THEMES", hex="C69B6D"},
    {id="matrix", label="Matrix", group="JUST FOR FUN", desc="Near-black surfaces with luminous terminal green."},
    {id="sprinkles", label="Sprinkles", group="JUST FOR FUN", desc="Pastel violet, cotton candy, pink and turquoise."},
    {id="light", label="Light Mode", group="JUST FOR FUN", desc="Warm whites, ivory and dark readable lettering."},
    {id="dark", label="Dark Mode", group="JUST FOR FUN", desc="Near-black neutral surfaces and cool silver."},
    {id="midnight", label="Midnight", group="JUST FOR FUN", desc="Deep indigo and soft celestial purple."},
    {id="ember", label="Ember", group="JUST FOR FUN", desc="Coal, warm copper and fiery orange."},
}
local PRESETS = {}
for _,p in ipairs(PRESET_LIST) do PRESETS[p.id]=p end
-- Keep the existing curated selections (and SavedVariables IDs) intact.
-- Each component family can additionally borrow the exact visual role from
-- any theme preset, without changing the remaining four families.
for _,family in ipairs(KEYS) do
    for _,preset in ipairs(PRESET_LIST) do
        OPTIONS[family][#OPTIONS[family]+1] = {"preset:"..preset.id,preset.label.." Palette"}
    end
end
local DEFAULT={border="quest",background="classic",button="classic",navigation="bookmarks",accent="gold"}
local MODERN={border="minimal",background="slate",button="slate",navigation="flat",accent="arcane"}
local DEFAULTS={classic=DEFAULT, forever={border="iron",background="leather",button="bronze",navigation="flat",accent="gold"},modern=MODERN}
local EXTRA_ACCENTS={gold="D7A95C",silver="C5CFD9",arcane="62BAEB",forest="80CF8A",pink="F5A5D2",matrix="4BFF8A"}
local function rgb(hex)
    return {tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,
        tonumber(hex:sub(5,6),16)/255,1}
end
local function rgba(hex,a) local c=rgb(hex);c[4]=a or 1;return c end
local function mix(a,b,ratio,alpha)
    return {a[1]*(1-ratio)+b[1]*ratio,a[2]*(1-ratio)+b[2]*ratio,
        a[3]*(1-ratio)+b[3]*ratio,alpha or 1}
end
local function lighten(c,weight) return mix(c,{1,1,1,1},weight) end
local function contrastAccent(c)
    local lum=.2126*c[1]+.7152*c[2]+.0722*c[3]
    if lum<.42 then return lighten(c,math.min(.48,(.49-lum)*.88)) end
    return c
end
local function palette(shell,header,nav,bar,body,border,accent,text,muted,navActive,buttonFace,light)
    return {shell=rgb(shell),header=rgb(header),nav=rgb(nav),bar=rgb(bar),body=rgb(body),
        border=rgb(border),accent=rgb(accent),text=rgb(text),muted=rgb(muted),
        navActive=rgb(navActive),buttonFace=rgb(buttonFace),light=light or false}
end
local PALETTES={
    classic=palette("281B12","352619","211B16","34271B","E4C895","97703B","D5A359","F6DEAE","C4AF8C","48321E","6F2821"),
    forever=palette("181513","27221D","171615","24201C","D9C59C","9E7844","E5BB66","F0DFC1","B0A18A","362A1C","37312B"),
    modern=palette("141A23","1C2632","151C26","202B38","DDE3EB","63788F","69B6E9","EEF4FA","ACBCCB","2A4055","293847"),
    matrix=palette("020503","071009","030704","07140A","061008","13632B","00FF66","B3FFBF","72C48B","0B2B14","0A351B"),
    sprinkles=palette("211A38","30224B","241A42","483064","FFF4F5","AA77E8","FF77BA","FCE8FF","C6B6DA","53326F","7845A7"),
    light=palette("F0EDE7","F8F6F0","E6E4DF","E6E1D8","FFFDF8","A99C88","78582B","302B27","695F56","D9CBAF","E4DACE",true),
    dark=palette("111215","1D1E23","15161A","24252B","E8E5DF","555963","C0C7D2","F1F2F4","AEB2BB","343943","2B2C34"),
    midnight=palette("0E1122","171B36","11162D","1B2342","D8D9F0","6466A3","B8A5FF","EAE9FF","AEB4DD","292D5A","34366A"),
    ember=palette("1D1410","302018","211713","36241B","E8D0B3","B36E46","F7A35C","F8DDC5","D0A98F","553222","673520"),
}
local CLASS_STYLE={}
for _,p in ipairs(PRESET_LIST) do
    if p.hex then
        local c=rgb(p.hex)
        local base=PALETTES.dark
        local accent=contrastAccent(c)
        CLASS_STYLE[p.id]={
            shell=mix(base.shell,c,.10),header=mix(base.header,c,.13),nav=mix(base.nav,c,.10),
            bar=mix(base.bar,c,.18),body=base.body,border=mix(base.border,c,.55),
            accent=accent,text=rgb("F2ECE7"),muted=rgb("B9B8C0"),
            navActive=mix(base.navActive,c,.32),buttonFace=mix(base.buttonFace,c,.26),light=false,
        }
    end
end
local function relativeLuminance(color)
    local function linear(x)
        return x<=0.04045 and x/12.92 or ((x+0.055)/1.055)^2.4
    end
    return .2126*linear(color[1])+.7152*linear(color[2])+.0722*linear(color[3])
end
local function contrast(a,b)
    local x,y=relativeLuminance(a),relativeLuminance(b)
    return (math.max(x,y)+.05)/(math.min(x,y)+.05)
end
local SOFT_WHITE=rgb("FFFFFF")
local SOFT_BLACK=rgb("000000")
local function readableText(background,preferred)
    if contrast(background,preferred)>=4.5 then return preferred end
    if contrast(background,SOFT_WHITE)>contrast(background,SOFT_BLACK) then
        return SOFT_WHITE
    end
    return SOFT_BLACK
end
function UI:ThemeReadableText(background,preferred)
    return readableText(background,preferred)
end
local function copyColor(c) return {c[1],c[2],c[3],c[4] or 1} end
local function copyPalette(c)
    local t={light=c.light}
    for k,v in pairs(c) do if type(v)=="table" then t[k]=copyColor(v) end end
    return t
end
local function style(mode)
    local class=CLASS_STYLE[mode]
    return copyPalette(class or PALETTES[mode] or PALETTES.classic)
end
local function validOption(family,choice)
    for _,entry in ipairs(OPTIONS[family] or {}) do if entry[1]==choice then return true end end
    return false
end
function UI:ThemeOptions(family) return OPTIONS[family] or {} end
function UI:ThemePresets() return PRESET_LIST end
function UI:ThemePresetInfo(id) return PRESETS[id] end
function UI:ThemeMode()
    local s=AF.db and AF.db.settings
    local mode=s and s.themeMode
    if mode=="custom" or PRESETS[mode] then return mode end
    return "classic"
end
function UI:ThemeSelection()
    local mode=self:ThemeMode()
    local s=AF.db and AF.db.settings
    if mode~="custom" then return DEFAULTS[mode] or MODERN end
    local from=DEFAULTS[s and s.themeBase] or MODERN
    local chosen=s and s.themeCustom or {}
    local result={}
    for _,family in ipairs(KEYS) do
        result[family]=validOption(family,chosen[family]) and chosen[family] or from[family]
    end
    return result
end
function UI:ThemeTokens(previewPreset)
    -- Optional preset argument is internal and read-only: used for composing
    -- custom families without switching themes or touching SavedVariables.
    local mode=(previewPreset and PRESETS[previewPreset]) and previewPreset or self:ThemeMode()
    local s=AF.db and AF.db.settings
    local base=mode=="custom" and (s and s.themeBase or "classic") or mode
    local p=style(base)
    local values=(previewPreset and PRESETS[previewPreset])
        and (DEFAULTS[previewPreset] or MODERN) or self:ThemeSelection()
    if mode=="custom" then
        -- New custom themes inherit every value of the chosen preset until
        -- that particular family is explicitly changed. Legacy pre-0.7.0.3
        -- custom saves (with no override flags) retain all previous picks.
        local overrides=s and s.themeOverrides
        local function overridden(family)
            return type(overrides)~="table" or overrides[family]==true
        end
        local backgrounds={
            classic={"281B12","352619","211B16","34271B","E4C895"},
            leather={"181513","27221D","171615","24201C","D9C59C"},
            slate={"141A23","1C2632","151C26","202B38","DDE3EB"},
        }
        local bd=backgrounds[values.background]
        if bd and overridden("background") then
            p.shell=rgb(bd[1]);p.header=rgb(bd[2]);p.nav=rgb(bd[3]);p.bar=rgb(bd[4]);p.body=rgb(bd[5])
            p.light=false
            p.text=rgb("F0E4D4");p.muted=rgb("B5AA9D")
        end
        local borders={quest="97703B",iron="68717B",minimal="66666A"}
        if overridden("border") then p.border=rgb(borders[values.border] or "97703B") end
        if overridden("accent") and EXTRA_ACCENTS[values.accent] then
            p.accent=rgb(EXTRA_ACCENTS[values.accent])
        end
        if overridden("button") then
            if values.button=="bronze" then p.buttonFace=rgb("654125")
            elseif values.button=="classic" then p.buttonFace=rgb("6F2821")
            else p.buttonFace=rgb("293847") end
        end
    end
    p.values=values
    p.mode=mode
    -- Color-first themes: Classic and Forever retain their palette identity,
    -- not old stretched BLP washes, native dialog frames, or selected-tab crops.
    -- Keep the compatibility flag for existing targets, but never enable it
    -- for preset themes. Game/map/item artwork is handled independently.
    p.classicArtwork=false
    -- Cohesive semantic surfaces: paper uses contrasting ink; data panels use
    -- contrasting foreground, so theme switching does not leave gold-on-ivory
    -- or black-on-black labels. These are visual-only derived tokens.
    local light=base=="light" or base=="classic" or base=="forever" or base=="sprinkles"
    if mode=="custom" then light=p.light or base=="classic" or base=="forever" end
    p.paper=p.body
    p.ink=light and rgb("32251B") or rgb("D6F6DD")
    p.dataSurface=rgb("1A1818")
    p.dataText=rgb("F6E7D2")
    p.surface=mix(p.shell,p.header,.36)
    p.raised=mix(p.header,p.navActive,.40)
    p.secondary=mix(p.nav,p.bar,.55)
    p.hover=mix(p.navActive,p.accent,.24)
    p.paperMuted=light and rgb("655443") or rgb("8DBB99")
    p.divider=mix(p.border,p.accent,.38)
    p.accent2=mix(p.accent,rgb("FFFFFF"),.30)
    p.accent3=mix(p.accent,p.border,.45)
    p.accent4=p.accent
    p.success=rgb("65D79A")
    p.navText=light and rgb("F1E8D7") or p.text
    p.navSelectedText=p.accent
    p.buttonText=p.text
    p.rainbow=false
    if base=="classic" then
        p.paper=rgb("B9A181");p.ink=rgb("382516");p.paperMuted=rgb("58432E")
        p.dataSurface=rgb("211711");p.dataText=rgb("F5E5C7")
        p.accent2=rgb("E5C287");p.accent3=rgb("9B6536")
    elseif base=="forever" then
        p.paper=rgb("B5A28B");p.ink=rgb("2D231B");p.paperMuted=rgb("554535")
        p.dataSurface=rgb("171513");p.dataText=rgb("F2DFC3")
        p.accent2=rgb("F0CC88");p.accent3=rgb("7F6546")
    elseif base=="light" then
        p.ink=rgb("292522");p.paperMuted=rgb("615B56")
        p.dataSurface=rgb("383630");p.dataText=rgb("FBFAF5")
        p.navText=rgb("282724");p.navSelectedText=rgb("50381B")
        p.buttonText=rgb("292522");p.accent2=rgb("946C4F")
    elseif base=="matrix" then
        p.paper=rgb("020603");p.ink=rgb("B5FFBA");p.paperMuted=rgb("75C585")
        p.dataSurface=rgb("010301");p.dataText=rgb("ACFFB5")
        p.surface=rgb("020703");p.raised=rgb("0B1B0D")
        p.accent=rgb("00FF66");p.accent2=rgb("8CFFAD");p.accent3=rgb("16883C")
        p.navText=rgb("8CECA3");p.navSelectedText=rgb("B8FFCE")
        p.border=rgb("126D31");p.divider=rgb("1EDB61")
        p.buttonFace=rgb("071A0B");p.buttonText=rgb("B2FFC0")
        p.success=rgb("00FF66")
    elseif base=="sprinkles" then
        p.rainbow=true
        p.paper=rgb("BEAFCA");p.ink=rgb("352143");p.paperMuted=rgb("554361")
        p.dataSurface=rgb("332449");p.dataText=rgb("FFF0FF")
        p.raised=rgb("46315F");p.surface=rgb("291F45")
        p.navText=rgb("F9EBFF");p.navSelectedText=rgb("FFF3B0")
        p.accent=rgb("FF83BB");p.accent2=rgb("6EE7E5")
        p.accent3=rgb("FEE27D");p.accent4=rgb("A2EAA2")
        p.divider=rgb("9F83EC");p.border=rgb("B487EA")
        p.buttonFace=rgb("573873");p.buttonText=rgb("FFFFFF")
        p.success=rgb("9AE9AF")
    else
        p.paper=p.light and rgb("D2CABE") or p.body
        p.ink=p.light and rgb("2B2D36") or rgb("E6ECF5")
        p.paperMuted=p.light and rgb("626577") or rgb("ACB9C9")
        p.dataSurface=p.light and rgb("333947") or mix(p.shell,rgb("000000"),.34)
        p.dataText=rgb("F3F4FC")
        p.accent2=mix(p.accent,rgb("FFFFFF"),.38)
        p.accent3=mix(p.accent,p.border,.36)
        if base=="modern" then p.paper=rgb("1B2636");p.ink=rgb("E8F1FF");p.paperMuted=rgb("ABBDD1") end
        if base=="dark" then p.paper=rgb("181A20");p.ink=rgb("E9EAF0");p.paperMuted=rgb("B7BBC6") end
        if base=="midnight" then p.paper=rgb("1A1D37");p.ink=rgb("EEE9FF");p.paperMuted=rgb("BDB2E0") end
        if base=="ember" then p.paper=rgb("251A15");p.ink=rgb("F4E5D5");p.paperMuted=rgb("BDA48F") end
        if CLASS_STYLE[base] then
            p.paper=mix(p.shell,p.bar,.55);p.ink=rgb("F2F2F5")
            p.paperMuted=rgb("BCC1CA")
        end
    end
    -- Custom family overrides remain family-scoped: a background selection
    -- also picks the matching ink, rather than keeping unreadable old text.
    if mode=="custom" and type(s and s.themeOverrides)=="table" and s.themeOverrides.background then
        if values.background=="classic" then
            p.paper=rgb("B9A181");p.ink=rgb("382516");p.paperMuted=rgb("58432E")
        elseif values.background=="leather" then
            p.paper=rgb("271F1B");p.ink=rgb("F2E5D6");p.paperMuted=rgb("C1ADA0")
        elseif values.background=="slate" then
            p.paper=rgb("222B39");p.ink=rgb("EAF2FA");p.paperMuted=rgb("B2C5D4")
        end
    end
    -- The journal body and shared reading cards use one coordinated surface.
    -- This prevents a large bright rectangle behind otherwise dark pages.
    p.body=copyColor(p.paper)
    if mode=="custom" then
        local overrides=s and s.themeOverrides
        for _,family in ipairs(KEYS) do
            local choice=values[family]
            local target=type(choice)=="string" and choice:match("^preset:(.+)$")
            if target and PRESETS[target] and
                (type(overrides)~="table" or overrides[family]) then
                -- A pure preset is calculated separately, then ONLY the
                -- selected role is copied. No edits to global theme state.
                local source=self:ThemeTokens(target)
                local roles={
                    background={"shell","header","nav","bar","body","paper",
                        "ink","paperMuted","dataSurface","dataText","surface",
                        "raised","secondary","light","navText"},
                    border={"border","divider"},
                    button={"buttonFace","buttonText","hover"},
                    navigation={"nav","navActive","navText","navSelectedText"},
                    accent={"accent","accent2","accent3","accent4","divider","success","rainbow"},
                }
                for _,role in ipairs(roles[family] or {}) do
                    local value=source[role]
                    p[role]=type(value)=="table" and copyColor(value) or value
                end
            end
        end
    end
    -- Custom families may come from different palettes. Their foregrounds
    -- must still contrast with the *rendered* button, nav, and paper surfaces.
    p.buttonText=readableText(p.buttonFace,p.buttonText)
    p.navText=readableText(p.nav,p.navText)
    p.ink=readableText(p.paper,p.ink)
    p.dataText=readableText(p.dataSurface,p.dataText)
    return p
end
local function applyLightModeTypographyRule(frame,tokens)
    if not frame or not tokens or tokens.mode~="light" then return end
    local ok,objType=pcall(function() return frame:GetObjectType() end)
    if not ok or objType~="FontString" then return end
    if frame.SetShadowOffset then frame:SetShadowOffset(0,0) end
    if frame.SetShadowColor then frame:SetShadowColor(0,0,0,0) end
end

function UI:RegisterThemeTarget(frame,apply)
    if not frame or not apply then return end
    self.themeTargets=self.themeTargets or setmetatable({}, {__mode="k"})
    local handlers=self.themeTargets[frame]
    if not handlers then handlers={};self.themeTargets[frame]=handlers end
    handlers[#handlers+1]=apply
    local tokens=self:ThemeTokens()
    apply(frame,tokens)
    applyLightModeTypographyRule(frame,tokens)
end
function UI:ApplyTheme()
    local tokens=self:ThemeTokens()
    for frame,handlers in pairs(self.themeTargets or {}) do
        for _,apply in ipairs(handlers) do
            apply(frame,tokens)
            applyLightModeTypographyRule(frame,tokens)
        end
    end
    if self.RefreshNavigation then self:RefreshNavigation() end
    if self.RefreshThemeSettings then self:RefreshThemeSettings() end
    if self.RefreshOverviewHeaderDecorations then self:RefreshOverviewHeaderDecorations() end
end
function UI:SetThemeMode(mode)
    if mode~="custom" and not PRESETS[mode] then return false end
    if not AF.db or not AF.db.settings then return false end
    local s=AF.db.settings
    if mode=="custom" and s.themeMode~="custom" then
        s.themeBase=PRESETS[s.themeMode] and s.themeMode or "classic"
        local original=self:ThemeSelection()
        s.themeCustom={}
        s.themeOverrides={}
        for _,family in ipairs(KEYS) do s.themeCustom[family]=original[family] end
    end
    s.themeMode=mode
    self:ApplyTheme()
    return true
end
function UI:SetThemeFamily(family,choice)
    if not validOption(family,choice) or not AF.db or not AF.db.settings then return false end
    local s=AF.db.settings
    if self:ThemeMode()~="custom" then
        local from=self:ThemeSelection()
        s.themeBase=self:ThemeMode()
        s.themeCustom={}
        s.themeOverrides={}
        for _,key in ipairs(KEYS) do s.themeCustom[key]=from[key] end
    end
    if type(s.themeCustom)~="table" then s.themeCustom={} end
    if type(s.themeOverrides)=="table" then s.themeOverrides[family]=true end
    s.themeCustom[family]=choice
    s.themeMode="custom"
    self:ApplyTheme()
    return true
end
function UI:CycleThemeFamily(family,step)
    local list=OPTIONS[family]
    if not list or #list==0 then return false end
    local selected=self:ThemeSelection()[family]
    local pos=1
    for i,entry in ipairs(list) do if entry[1]==selected then pos=i;break end end
    return self:SetThemeFamily(family,list[((pos-1+(step or 1))%#list)+1][1])
end
function UI:ThemeFamilyLabel(family)
    local mode=self:ThemeMode()
    local base=mode=="custom" and (AF.db and AF.db.settings and AF.db.settings.themeBase) or mode
    local info=PRESETS[base]
    local settings=AF.db and AF.db.settings
    local overridden=mode=="custom" and (type(settings.themeOverrides)~="table" or settings.themeOverrides[family])
    if mode=="custom" and not overridden and info then
        return info.label.." (Inherited)"
    end
    local choice=self:ThemeSelection()[family]
    for _,entry in ipairs(OPTIONS[family] or {}) do if entry[1]==choice then return entry[2] end end
    return "Default"
end
-- Unified page intro/hero surface. Dark palettes keep a raised header;
-- light palettes use a muted paper/header blend and dark legible lettering.
-- This prevents individual pages from choosing mismatched dark or pale bars.
function UI:ThemeIntroColors(tokens)
    tokens=tokens or self:ThemeTokens()
    local surface=tokens.light and mix(tokens.paper,tokens.header,.18) or tokens.raised
    local title=self:ThemeReadableText(surface,tokens.accent2)
    local subtitle=self:ThemeReadableText(surface,tokens.light and tokens.ink or tokens.dataText)
    return surface,title,subtitle
end

-- A single skin for the four Workshop intro bars. Professions used to keep a
-- hard-coded dark header, while Recipes and Materials received different theme
-- updates. Matching both surface and text to the SAME semantic role prevents
-- gold-on-brown, white-on-paper, and unreadable mixed-Custom combinations.
-- The caller retains full ownership of its layout and any gameplay actions.
function UI:ThemeWorkshopIntro(frame, fill, heading, subtitle, divider)
    if not frame or not fill then return end
    if heading then heading.afThemeColorManaged=true end
    if subtitle then subtitle.afThemeColorManaged=true end
    if not self.RegisterThemeTarget then return end
    self:RegisterThemeTarget(frame,function(_,tokens)
        local surface,headInk,bodyInk=self:ThemeIntroColors(tokens)
        fill:SetColorTexture(surface[1],surface[2],surface[3],.98)
        if heading then heading:SetTextColor(unpack(headInk)) end
        if subtitle then subtitle:SetTextColor(unpack(bodyInk)) end
        if divider then
            local edge=tokens.divider
            divider:SetColorTexture(edge[1],edge[2],edge[3],.65)
        end
    end)
end

function UI:ThemeBorder(frame,tokens)
    if not frame then return end
    local b=tokens.border
    if frame.SetBackdropBorderColor and frame.GetBackdrop then
        frame:SetBackdropBorderColor(b[1],b[2],b[3],tokens.classicArtwork and b[4] or 0)
    end
    if frame.afThemeEdgeStrips then
        for _,strip in ipairs(frame.afThemeEdgeStrips) do strip:SetColorTexture(unpack(b)) end
    end
end
function UI:ApplyThemeButton(button,tokens)
    if not button or not button.afStyle then return end
    local family=tokens.values.button
    local isClassic=family=="classic" and tokens.classicArtwork
    local accent=tokens.accent
    if button.afStyle=="row" then
        if button.rowBase then
            local c=tokens.navActive
            -- An unboxed row is one solid themed surface, so the color used
            -- to select its label also matches its actual visible background.
            local customSurface=button.afThemeButtonTextRole~=nil
            button.rowBase:SetShown(not customSurface)
            if not customSurface then
                button.rowBase:SetColorTexture(c[1],c[2],c[3],.96)
            end
        end
        if button.selectedTexture then button.selectedTexture:SetColorTexture(accent[1],accent[2],accent[3],.20) end
        if button.label and button.label.SetTextColor then
            local role=button.afThemeButtonTextRole or "ink"
            local color=tokens[role] or tokens.ink
            local surface=role=="dataText" and tokens.dataSurface
                or role=="buttonText" and tokens.buttonFace
                or tokens.navActive
            button.label:SetTextColor(unpack(readableText(surface,color)))
        end
        return
    end
    if button.afStyle=="tab" then
        if button.tabArt then button.tabArt:SetShown(isClassic) end
    else
        if button.normalSlices then
            for _,tx in ipairs(button.normalSlices) do tx:SetShown(isClassic and not button.afThemePressed) end
        end
        if button.pressedSlices then
            for _,tx in ipairs(button.pressedSlices) do tx:SetShown(isClassic and button.afThemePressed or false) end
        end
    end
    local fill=button.afThemeFill
    if fill then
        fill:SetShown(not isClassic)
        if not isClassic then
            local base=tokens.buttonFace
            if tokens.rainbow then
                local variants={"573873","5F3548","28546E","356044","755D30","79442B","453A70"}
                base=rgb(variants[((button.afThemeColorIndex or 1)-1)%#variants+1])
            end
            local pressed=button.afThemePressed==true
            local selected=button.tabSelected==true
            local hovered=button.afThemeHover==true
            local lightening=pressed and -.045 or (selected and .13 or (hovered and .085 or 0))
            local function adjust(n) return math.max(0,math.min(1,n+lightening)) end
            fill:SetColorTexture(adjust(base[1]),adjust(base[2]),adjust(base[3]),.99)
        end
    end
    if button.label and button.label.SetTextColor then
        if isClassic then
            if button.afStyle=="tab" then button.label:SetTextColor(unpack(button.tabSelected and UI.palette.jade or UI.palette.pale))
            else button.label:SetTextColor(unpack(button.selectedTexture and button.selectedTexture:IsShown()
                and UI.palette.gold or UI.palette.pale)) end
        elseif button.afStyle=="tab" and button.tabSelected then
            button.label:SetTextColor(unpack(tokens.accent))
        else
            button.label:SetTextColor(unpack(tokens.buttonText))
        end
    end
end

-- Shared visual-only skin for custom controls. Use this instead of forcing
-- default parchment ink onto a locally painted dark button.
function UI:ThemeQuietButton(button,fill,edges,options)
    if not button then return end
    options=options or {}
    if button.afStyle then
        button.afThemeButtonTextRole=options.role or "buttonText"
        if button.rowBase then button.rowBase:Hide() end
    end
    if not self.RegisterThemeTarget then return end
    self:RegisterThemeTarget(button,function(target,t)
        local c=t[options.surface or "buttonFace"] or t.buttonFace
        if fill then fill:SetColorTexture(c[1],c[2],c[3],options.alpha or .98) end
        local edge=t[options.border or "divider"] or t.divider
        for _,tex in ipairs(edges or {}) do
            tex:SetColorTexture(edge[1],edge[2],edge[3],.72)
        end
        if button.label then
            local ink=t[options.role or "buttonText"] or t.buttonText
            ink=readableText(c,ink)
            button.label:SetTextColor(unpack(ink))
        end
    end)
end
