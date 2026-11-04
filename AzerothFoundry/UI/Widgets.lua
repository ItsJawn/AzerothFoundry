-- Shared visual widgets.  v0.1.1 intentionally does not modify saved data.
local _, AF = ...
AF.UI = {}
local UI = AF.UI
local unpack = unpack or table.unpack

UI.palette = {
    dark = { 0.11, 0.072, 0.041, 1 },
    leather = { 0.20, 0.123, 0.067, 1 },
    brass = { 0.56, 0.36, 0.15, 1 },
    parchment = { 0.80, 0.68, 0.47, 1 },
    parchmentLight = { 0.91, 0.80, 0.58, 1 },
    gold = { 1.00, 0.78, 0.36, 1 },
    ink = { 0.16, 0.105, 0.055, 1 },
    pale = { 0.98, 0.89, 0.71, 1 },
    green = { 0.18, 0.48, 0.24, 1 },
    jade = { 0.66, 0.86, 0.74, 1 },
}

-- BackdropTemplate is shipped by modern WoW builds. Fall back to 1px edges if
-- it is unavailable on a future Forever client (no third-party dependencies).
function UI:NewFrame(kind, parent, name)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    return CreateFrame(kind or "Frame", name, parent, template)
end

local function Color(texture, color)
    texture:SetColorTexture(unpack(color))
end

-- An even parchment surface avoids the hard vertical crop/seam from QuestBG.
-- DialogFrame border art remains Blizzard-native; no external image assets.
function UI:Background(frame, color, bordered)
    color = color or self.palette.parchment
    local base = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    base:SetAllPoints(frame)
    Color(base, color)
    -- Preserve the native RGBA source for optional Art Lab edits and Reset.
    -- Retail does not expose a reliable GetColorTexture getter, so an
    -- unlabeled color-only region was previously rejected by Art Lab.
    base.afSkinDefaultColor = {color[1],color[2],color[3],color[4] or 1}

    local isPaper = color == self.palette.parchment or color == self.palette.parchmentLight
    local glow,art
    if isPaper then
        -- Subtle page tint, deliberately not QuestBG: that asset has illustrated
        -- edges and visibly crops when stretched over these tall, narrow panels.
        glow = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -9)
        glow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -9, -9)
        glow:SetHeight(42)
        glow:SetColorTexture(1, 0.91, 0.71, 0.16)
    else
        art = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        art:SetAllPoints(frame)
        art:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
        art:SetVertexColor(0.85, 0.72, 0.54, 0.33)
        art:SetAlpha(0.38)
    end

    -- Set the whole surface family when a theme changes (not just its edge).
    -- Historic Art Lab colors are still captured in afSkinDefaultColor.
    local role = isPaper and "paper" or (color==self.palette.leather and "data" or "dark")
    if frame.afStyle and not frame.afThemeButtonTextRole then
        frame.afThemeButtonTextRole=(role=="paper" and "ink") or "dataText"
    end
    if self.RegisterThemeTarget then
        self:RegisterThemeTarget(base,function(tex,tokens)
            local c=role=="paper" and tokens.paper or (role=="data" and tokens.dataSurface or tokens.surface)
            if frame.afThemeSurfaceVariant=="intro" and self.ThemeIntroColors then
                c=self:ThemeIntroColors(tokens)
            end
            tex:SetColorTexture(unpack(c))
        end)
    end
    if glow and self.RegisterThemeTarget then
        self:RegisterThemeTarget(glow,function(tex,t) tex:SetShown(t.classicArtwork) end)
    end
    if art and self.RegisterThemeTarget then
        self:RegisterThemeTarget(art,function(tex,t) tex:SetShown(t.classicArtwork) end)
    end
    if bordered then
        local themeStrips={}
        if frame.SetBackdrop then
            frame:SetBackdrop({
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                edgeSize = 22,
                insets = { left = 6, right = 6, top = 6, bottom = 6 },
            })
            frame:SetBackdropBorderColor(0.64, 0.46, 0.23, 0.95)
        end
        do
            for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
                local strip = frame:CreateTexture(nil, "BORDER")
                Color(strip, self.palette.brass)
                themeStrips[#themeStrips+1]=strip
                if edge == "TOP" or edge == "BOTTOM" then
                    strip:SetHeight(2)
                    strip:SetPoint(edge.."LEFT", frame, edge.."LEFT")
                    strip:SetPoint(edge.."RIGHT", frame, edge.."RIGHT")
                else
                    strip:SetWidth(2)
                    strip:SetPoint("TOP"..edge, frame, "TOP"..edge)
                    strip:SetPoint("BOTTOM"..edge, frame, "BOTTOM"..edge)
                end
            end
        end
        frame.afThemeEdgeStrips=themeStrips
        if self.RegisterThemeTarget then
            self:RegisterThemeTarget(frame,function(target,tokens)
                for _,edge in ipairs(themeStrips) do edge:SetShown(not tokens.classicArtwork) end
                if target.SetBackdropBorderColor then
                    local b=tokens.border
                    target:SetBackdropBorderColor(b[1],b[2],b[3],tokens.classicArtwork and b[4] or 0)
                end
            end)
        end
        if self.RegisterThemeTarget then
            self:RegisterThemeTarget(frame,function(target,tokens) UI:ThemeBorder(target,tokens) end)
        end
    end
    return base
end

function UI:Text(parent, size, color, justify)
    local t = parent:CreateFontString(nil, "OVERLAY")
    local font = size == "title" and (QuestTitleFont or GameFontNormalLarge)
              or size == "small" and GameFontNormalSmall
              or GameFontNormal
    t:SetFontObject(font)
    -- Some Blizzard fonts include a dark shadow/outline designed for bright text.
    -- Both produce the doubled, muddy glyphs seen on the v0.1 parchment screenshot.
    -- Retain the installed, localized font face while removing those effects.
    if font and font.GetFont then
        local face, originalSize = font:GetFont()
        if face then
            local target = size == "title" and 17 or (size == "small" and 12 or 14)
            t:SetFont(face, target, "")
        end
    end
    t:SetShadowOffset(0, 0)
    t:SetShadowColor(0, 0, 0, 0)
    local original=color or self.palette.ink
    t:SetTextColor(unpack(original))
    local role=(original==self.palette.ink and "ink") or
        (original==self.palette.pale and "dataText") or
        (original==self.palette.gold and "accent") or
        (original==self.palette.jade and "accent2") or
        (original==self.palette.green and "success")
    if role and self.RegisterThemeTarget then
        self:RegisterThemeTarget(t,function(label,tokens)
            -- Labels inside buttons are painted by the matching button skin.
            -- The generic text role cannot subsequently override their contrast.
            if not label.afThemeButtonLabel and not label.afThemeColorManaged and tokens[role] then
                label:SetTextColor(unpack(tokens[role]))
            end
        end)
    end
    t:SetJustifyH(justify or "LEFT")
    t:SetJustifyV("MIDDLE")
    t:SetWordWrap(true)
    return t
end

-- The stock UI-Panel-Button-Up file is an atlas-like texture with unused
-- pixels. Passing the whole file to SetNormalTexture rendered only a narrow red
-- strip in v0.1.1. Three explicitly cropped native slices scale to any width.
-- This is compatible with the original button.label and OnClick contracts.
local function ButtonSlice(button, file, layer)
    local left = button:CreateTexture(nil, layer)
    left:SetTexture(file)
    left:SetTexCoord(0, 0.09375, 0, 0.6875)
    left:SetPoint("TOPLEFT", button, "TOPLEFT")
    left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT")
    left:SetWidth(12)

    local right = button:CreateTexture(nil, layer)
    right:SetTexture(file)
    right:SetTexCoord(0.53125, 0.625, 0, 0.6875)
    right:SetPoint("TOPRIGHT", button, "TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
    right:SetWidth(12)

    local middle = button:CreateTexture(nil, layer)
    middle:SetTexture(file)
    middle:SetTexCoord(0.09375, 0.53125, 0, 0.6875)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    return {left, middle, right}
end

local function ToggleSlices(slices, shown)
    if not slices then return end
    for _, texture in ipairs(slices) do
        if shown then texture:Show() else texture:Hide() end
    end
end

function UI:Button(parent, label, callback, style)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(style == "tab" and 42 or 29)
    b:RegisterForClicks("LeftButtonUp")
    b.afStyle = style or "action"
    self.themeButtonSerial=(self.themeButtonSerial or 0)+1
    b.afThemeColorIndex=self.themeButtonSerial
    if style ~= "row" then
        local tint=b:CreateTexture(nil,"BACKGROUND",nil,1)
        tint:SetAllPoints(b)
        tint:SetColorTexture(.31,.22,.13,.99)
        tint:Hide()
        b.afThemeFill=tint
    end

    if style == "tab" then
        -- Original bookmark-shaped art. Unlike panel button textures it scales
        -- to any tab width without showing empty sprite-sheet pixels.
        local art = b:CreateTexture(nil, "BACKGROUND")
        art:SetAllPoints(b)
        b.tabArt = art
        b.tabSelected = false
        b:SetScript("OnEnter", function(self)
            if not self.tabSelected then
                self.tabArt:SetTexture("Interface\\AddOns\\AzerothFoundry\\Media\\TabHover")
            end
        end)
        b:SetScript("OnLeave", function(self)
            self.tabArt:SetTexture(self.tabSelected
                and "Interface\\AddOns\\AzerothFoundry\\Media\\TabSelected"
                or "Interface\\AddOns\\AzerothFoundry\\Media\\TabNormal")
        end)
        b:SetScript("OnMouseDown", function(self)
            self.tabArt:SetVertexColor(0.86, 0.86, 0.86)
        end)
        b:SetScript("OnMouseUp", function(self)
            self.tabArt:SetVertexColor(1, 1, 1)
        end)
        art:SetTexture("Interface\\AddOns\\AzerothFoundry\\Media\\TabNormal")
    elseif style == "row" then
        local rest = b:CreateTexture(nil, "BACKGROUND")
        rest:SetAllPoints(b)
        rest:SetColorTexture(0.43, 0.28, 0.12, 0.055)
        b.rowBase=rest
        local selected = b:CreateTexture(nil, "ARTWORK")
        selected:SetAllPoints(b)
        selected:SetColorTexture(0.85, 0.61, 0.24, 0.21)
        selected:Hide()
        b.selectedTexture = selected
        local bar = b:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
        bar:SetWidth(3)
        bar:SetColorTexture(0.73, 0.43, 0.14, 0.85)
        bar:Hide()
        b.selectedBar = bar
    else
        local up = "Interface\\Buttons\\UI-Panel-Button-Up"
        local down = "Interface\\Buttons\\UI-Panel-Button-Down"
        b.normalSlices = ButtonSlice(b, up, "BACKGROUND")
        b.pressedSlices = ButtonSlice(b, down, "BACKGROUND")
        ToggleSlices(b.pressedSlices, false)
        local selected = b:CreateTexture(nil, "ARTWORK")
        selected:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -5)
        selected:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -10, 5)
        selected:SetColorTexture(0.96, 0.69, 0.26, 0.11)
        selected:Hide()
        b.selectedTexture = selected
        if style == "tab" then
            local line = b:CreateTexture(nil, "ARTWORK")
            line:SetHeight(2)
            line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 10, 2)
            line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -10, 2)
            line:SetColorTexture(1, 0.74, 0.28, 1)
            line:Hide()
            b.selectedBar = line
        end
        b:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                ToggleSlices(self.normalSlices, false)
                ToggleSlices(self.pressedSlices, true)
            end
        end)
        b:SetScript("OnMouseUp", function(self)
            ToggleSlices(self.pressedSlices, false)
            ToggleSlices(self.normalSlices, true)
        end)
        b:SetScript("OnHide", function(self)
            ToggleSlices(self.pressedSlices, false)
            ToggleSlices(self.normalSlices, true)
        end)
    end
    if style ~= "tab" then
        local hover = b:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(b)
        hover:SetColorTexture(1, 0.85, 0.48, style == "row" and 0.13 or 0.10)
    end
    b.label = self:Text(b, "small", (style == "row") and self.palette.ink or self.palette.pale,
        style == "row" and "LEFT" or "CENTER")
    b.label:SetPoint("TOPLEFT", b, "TOPLEFT", style == "row" and 10 or 8,
        style == "tab" and -4 or -1)
    b.label:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -8,
        style == "tab" and 12 or 1)
    b.label:SetText(label or "")
    b.label.afThemeButtonLabel=true
    b:SetScript("OnClick", callback)
    if self.RegisterThemeTarget then
        self:RegisterThemeTarget(b,function(button,tokens) UI:ApplyThemeButton(button,tokens) end)
    end
    -- Keep the native button look for Classic. Nonclassic themes handle
    -- both presses and pointer feedback through one family-wide style.
    if style ~= "row" then
        local oldEnter=b:GetScript("OnEnter")
        local oldLeave=b:GetScript("OnLeave")
        local oldDown=b:GetScript("OnMouseDown")
        local oldUp=b:GetScript("OnMouseUp")
        local oldHide=b:GetScript("OnHide")
        b:SetScript("OnEnter",function(button,...)
            button.afThemeHover=true
            if oldEnter and UI:ThemeSelection().button=="classic" then oldEnter(button,...) end
            UI:ApplyThemeButton(button,UI:ThemeTokens())
        end)
        b:SetScript("OnLeave",function(button,...)
            button.afThemeHover=false
            if oldLeave and UI:ThemeSelection().button=="classic" then oldLeave(button,...) end
            UI:ApplyThemeButton(button,UI:ThemeTokens())
        end)
        b:SetScript("OnMouseDown",function(button,...)
            button.afThemePressed=true
            if oldDown and UI:ThemeSelection().button=="classic" then oldDown(button,...) end
            UI:ApplyThemeButton(button,UI:ThemeTokens())
        end)
        b:SetScript("OnMouseUp",function(button,...)
            button.afThemePressed=false
            if oldUp and UI:ThemeSelection().button=="classic" then oldUp(button,...) end
            UI:ApplyThemeButton(button,UI:ThemeTokens())
        end)
        b:SetScript("OnHide",function(button,...)
            button.afThemePressed=false
            button.afThemeHover=false
            if oldHide and UI:ThemeSelection().button=="classic" then oldHide(button,...) end
        end)
    end
    return b
end

function UI:SetButtonSelected(button, selected)
    if not button then return end
    if button.afStyle == "tab" then
        button.tabSelected = selected and true or false
        button.tabArt:SetTexture(selected
            and "Interface\\AddOns\\AzerothFoundry\\Media\\TabSelected"
            or "Interface\\AddOns\\AzerothFoundry\\Media\\TabNormal")
        button.tabArt:SetVertexColor(1, 1, 1)
        button.label:SetTextColor(unpack(selected and self.palette.jade or self.palette.pale))
        if self.ApplyThemeButton then self:ApplyThemeButton(button,self:ThemeTokens()) end
        return
    end
    if button.selectedTexture then
        if selected then button.selectedTexture:Show() else button.selectedTexture:Hide() end
    end
    if button.selectedBar then
        if selected then button.selectedBar:Show() else button.selectedBar:Hide() end
    end
    if button.afStyle == "row" then
        button.label:SetTextColor(unpack(self.palette.ink))
    else
        button.label:SetTextColor(unpack(selected and self.palette.gold or self.palette.pale))
    end
    if self.ApplyThemeButton then self:ApplyThemeButton(button,self:ThemeTokens()) end
end

function UI:Input(parent, width)
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetAutoFocus(false)
    edit:SetHeight(28)
    edit:SetWidth(width or 200)
    edit:SetFontObject(ChatFontNormal)
    edit:SetTextInsets(7, 7, 0, 0)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return edit
end

function UI:Multiline(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    -- This lightly shaded backing is within the scroll frame so the text stays
    -- legible against the paper even at different UI scales.
    local fill = scroll:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(scroll)
    fill:SetColorTexture(0.99, 0.92, 0.76, 0.50)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetAutoFocus(false)
    edit:SetMultiLine(true)
    edit:SetFontObject(ChatFontNormal)
    edit:SetTextColor(0.17, 0.12, 0.07)
    edit:SetJustifyH("LEFT")
    edit:SetJustifyV("TOP")
    edit:SetWidth(400)
    edit:SetHeight(900)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnCursorChanged", function(self)
        if self.scroll and self.scroll.UpdateScrollChildRect then
            self.scroll:UpdateScrollChildRect()
        end
    end)
    -- Multiline notes are reading surfaces too. Avoid leaving a bright
    -- parchment rectangle and hardcoded brown ink under dark presets.
    if self.RegisterThemeTarget then
        self:RegisterThemeTarget(scroll,function(_,tokens)
            local c=tokens.paper
            fill:SetColorTexture(c[1],c[2],c[3],.96)
            edit:SetTextColor(unpack(tokens.ink))
        end)
    end
    edit.scroll = scroll
    scroll:SetScrollChild(edit)
    scroll.edit = edit
    return scroll
end

function UI:ResizeEditor(edit)
    local scroll = edit.scroll
    if not scroll then return end
    local width = math.max(140, scroll:GetWidth() - 25)
    edit:SetWidth(width)
    local charsPerLine = math.max(20, math.floor(width / 7.2))
    local text = edit:GetText() or ""
    local lines = 0
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines = lines + math.max(1, math.ceil(#line / charsPerLine))
    end
    edit:SetHeight(math.max(scroll:GetHeight(), 200, math.min(lines * 19 + 35, 100000)))
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
end

function UI:Card(parent, color)
    local card = self:NewFrame("Frame", parent)
    self:Background(card, color or self.palette.parchmentLight, true)
    return card
end

function UI:SectionTitle(parent, text)
    local title = self:Text(parent, "title", self.palette.ink)
    title:SetText(text)
    title:SetHeight(27)
    -- Small gold divider gives each column the familiar WoW quest-frame rhythm.
    local rule = parent:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    rule:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -2)
    rule:SetColorTexture(0.56, 0.36, 0.17, 0.47)
    self.themeSectionSerial=(self.themeSectionSerial or 0)+1
    local sectionIndex=self.themeSectionSerial
    if self.RegisterThemeTarget then self:RegisterThemeTarget(rule,function(tex,t)
        local colors={t.accent,t.accent2,t.accent3,t.accent4}
        local c=t.rainbow and colors[(sectionIndex-1)%#colors+1] or t.divider
        tex:SetColorTexture(c[1],c[2],c[3],.72)
    end) end
    return title
end

-- A single shared resize affordance used by Characters, Workshop and
-- Collections. The primary four-cornered diamond has a bright inset, with
-- smaller diamonds above and below. No PNGs, atlases or global frame names.
function UI:StyleResizeGrip(frame, layer)
    if not frame or not frame.CreateTexture then return end
    if frame.afResizeGripStyled then return end
    frame.afResizeGripStyled = true
    -- Native WoW texture regions rotate UVs, NOT the silhouette of a solid
    -- color square. A tiny alpha-masked TGA makes this a real diamond shape
    -- on both Retail and Forever and remains independent of the art atlas.
    local file = "Interface\\AddOns\\AzerothFoundry\\Media\\ResizeDiamond.tga"
    local artLayer=layer or "ARTWORK"
    for _,part in ipairs({{y=0,size=13,alpha=1},{y=14,size=8,alpha=.84},{y=-14,size=8,alpha=.84}}) do
        local sprite=frame:CreateTexture(nil,artLayer)
        sprite:SetPoint("CENTER",frame,"CENTER",0,part.y)
        sprite:SetSize(part.size,part.size)
        sprite:SetTexture(file)
        sprite:SetAlpha(part.alpha)
    end
end

-- Scrollbars in UIPanelScrollFrameTemplate can remain visible even when the
-- contents fit. Explicitly update their visibility and list width whenever
-- records change or the journal is resized.
function UI:ListScrollBar(scroll)
    if scroll.afScrollBar then return scroll.afScrollBar end
    local bar = scroll.ScrollBar
    if not bar and scroll.GetChildren then
        for _, child in ipairs({scroll:GetChildren()}) do
            if child and child.GetObjectType and child:GetObjectType() == "Slider" then
                bar = child
                break
            end
        end
    end
    scroll.afScrollBar = bar
    return bar
end

-- Workshop list scrollbars use Blizzard's native UIPanelScrollFrameTemplate,
-- whose slider is anchored +6 UI units OUTSIDE the scrollframe by default.
-- Moving the ScrollFrame alone never moves that native +6 offset.
-- Inset the actual slider (including its anchored arrow buttons / thumb)
-- without touching the list contents or global template for other pages.
function UI:InsetWorkshopScrollBar(scroll)
    if not scroll then return false end
    local bar = self:ListScrollBar(scroll)
    if not bar or not bar.ClearAllPoints or not bar.SetPoint then return false end
    bar:ClearAllPoints()
    -- From default +6 to -5: the thumb and arrows now sit 11 units farther
    -- left. They remain attached to the scrollframe during page resizing.
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", -5, -16)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", -5, 16)
    scroll.afWorkshopScrollBarInset = true
    return true
end

function UI:UpdateListScroll(scroll)
    if scroll.afUpdatingScroll then return end
    local child = scroll.child
    if not child then return end
    local available = scroll:GetHeight() or 0
    if available < 1 then return end
    scroll.afUpdatingScroll = true
    local overflow = (scroll.afContentHeight or 0) > available + 3
    local bar = self:ListScrollBar(scroll)
    if bar then bar:SetShown(overflow) end
    local width = math.max(100, (scroll:GetWidth() or 200) - (overflow and 25 or 4))
    if math.abs((child:GetWidth() or 0) - width) > 0.5 then
        child:SetWidth(width)
    end
    for _, row in ipairs(scroll.rows or {}) do
        row:SetWidth(width - 7)
    end
    if not overflow and scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
    scroll.afUpdatingScroll = false
end

function UI:List(parent, rowHeight)
    -- A named frame also gives older Blizzard templates a predictable global
    -- scrollbar identifier ("<name>ScrollBar") if .ScrollBar is not populated.
    self.listSerial = (self.listSerial or 0) + 1
    local name = "AzerothFoundryListScroll" .. self.listSerial
    local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scroll.afScrollBar = (_G and _G[name .. "ScrollBar"]) or scroll.ScrollBar
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(200, 1)
    scroll:SetScrollChild(child)
    scroll.child = child
    scroll.rows = {}
    scroll.rowHeight = rowHeight or 34
    scroll.afContentHeight = 1
    scroll:SetScript("OnSizeChanged", function(self)
        UI:UpdateListScroll(self)
    end)
    -- Preserve Blizzard's native scroll handling and correct scrollbar state
    -- after its own scroll-range script has run.
    if scroll.HookScript then
        scroll:HookScript("OnScrollRangeChanged", function(self)
            UI:UpdateListScroll(self)
        end)
    end
    return scroll
end

function UI:FillList(scroll, entries, onClick, selectedKey)
    local child = scroll.child
    local step = scroll.rowHeight
    local count = #entries
    local height = math.max(1, count * step + (count > 0 and 8 or 0))
    scroll.afContentHeight = height
    child:SetHeight(height)
    self:UpdateListScroll(scroll)
    local width = child:GetWidth()
    for i = 1, math.max(count, #scroll.rows) do
        local row = scroll.rows[i]
        if not row then
            row = self:Button(child, "", nil, "row")
            row:SetHeight(step - 4)
            row:SetPoint("TOPLEFT", 3, -3 - (i - 1) * step)
            scroll.rows[i] = row
        end
        local entry = entries[i]
        if entry then
            row:Show()
            row:SetWidth(width - 7)
            row.label:SetText(entry.label or "")
            if entry.icon or entry.class then
                if not row.afIcon then
                    row.afIcon = row:CreateTexture(nil, "ARTWORK")
                    row.afIcon:SetSize(23, 23)
                    row.afIcon:SetPoint("LEFT", row, "LEFT", 8, 0)
                end
                if entry.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[entry.class] then
                    row.afIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
                    row.afIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[entry.class]))
                else
                    row.afIcon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                    row.afIcon:SetTexCoord(0, 1, 0, 1)
                end
                row.afIcon:Show()
                row.label:ClearAllPoints()
                row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -1)
                row.label:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 1)
            else
                if row.afIcon then row.afIcon:Hide() end
                row.label:ClearAllPoints()
                row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -1)
                row.label:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 1)
            end
            self:SetButtonSelected(row, entry.key == selectedKey)
            row:SetScript("OnClick", function() onClick(entry) end)
        else
            row:Hide()
        end
    end
    self:UpdateListScroll(scroll)
end

function UI:Empty(parent, message)
    local label = self:Text(parent, "small", self.palette.ink, "CENTER")
    label:SetText(message)
    label:SetPoint("CENTER", parent, "CENTER")
    label:SetWidth(320)
    label:SetHeight(120)
    return label
end
