-- Azeroth Foundry's small minimap bookmark button.
-- It uses only local game APIs, shares the journal's existing SavedVariables,
-- and does not send data or communicate with other addons.
local _, AF = ...

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi) end
    return y >= 0 and math.pi / 2 or -math.pi / 2
end

function AF:PositionMinimapButton()
    local button = self.minimapButton
    if not button or not Minimap then return end
    local angle = tonumber(self.db.settings.minimapAngle) or 215
    local radius = math.max(65, (Minimap:GetWidth() or 140) * 0.5 + 9)
    local radians = math.rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(radians) * radius, math.sin(radians) * radius)
end

function AF:CreateMinimapButton()
    if self.minimapButton or not Minimap or not self.db then return end
    local button = CreateFrame("Button", "AzerothFoundryMinimapButton", Minimap)
    self.minimapButton = button
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    button:SetSize(31, 31)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)
    button:SetHitRectInsets(0, 0, 0, 0)

    local fill = button:CreateTexture(nil, "BACKGROUND")
    button.fill = fill
    fill:SetPoint("CENTER", button, "TOPLEFT", 16.5, -16.5)
    fill:SetSize(20, 20)
    fill:SetColorTexture(0.06, 0.06, 0.06, 0.96)
    if fill.AddMaskTexture and button.CreateMaskTexture then
        local fillMask = button:CreateMaskTexture(nil, "BACKGROUND")
        if fillMask and fillMask.SetTexture then
            fillMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMaskSmall", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            fillMask:SetPoint("CENTER", fill, "CENTER")
            fillMask:SetSize(20, 20)
            fill:AddMaskTexture(fillMask)
            button.fillMask = fillMask
        end
    end

    local bg = button:CreateTexture(nil, "ARTWORK")
    button.bg = bg
    -- Blizzard's tracking-border art is off-center inside its 53x53 file.
    -- Match LibDBIcon's known-good top-left icon alignment instead of
    -- centering the two textures independently.
    -- Fine-tune the disc: nudge it 0.5 up/right and keep the fitted size.
    bg:SetPoint("CENTER", button, "TOPLEFT", 16.5, -16.5)
    bg:SetSize(29, 29)
    bg:SetTexture("Interface\\AddOns\\AzerothFoundry\\Media\\MinimapDisc")
    bg:SetVertexColor(1, 1, 1, 1)

    local border = button:CreateTexture(nil, "OVERLAY")
    button.border = border
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetVertexColor(0.96, 0.83, 0.54, 1)

    local label = button:CreateFontString(nil, "OVERLAY")
    button.label = label
    -- Keep AF letters at their former position; move only the circle.
    label:SetPoint("CENTER", button, "TOPLEFT", 17, -15.5)
    label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetText("AF")
    label:SetTextColor(1, 0.78, 0.36, 1)
    label:SetShadowOffset(1, -1)
    label:SetShadowColor(0, 0, 0, 0.85)

    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    button.hover = hover
    hover:SetAllPoints(button)
    hover:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hover:SetBlendMode("ADD")

    button:SetScript("OnMouseDown", function(self)
        self.afMoved = false
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if self.afMoved then
            self.afMoved = false
            return
        end
        if mouseButton == "LeftButton" and AF.UI and AF.UI.frame then
            AF.UI:Toggle()
        end
    end)
    button:SetScript("OnEnter", function(self)
        if self.bg then self.bg:SetSize(29, 29) end
        if self.border then self.border:SetVertexColor(1, 0.88, 0.58, 1) end
        if self.label then self.label:SetTextColor(1, 0.84, 0.44, 1) end
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Azeroth Foundry", 1, 0.78, 0.36)
        GameTooltip:AddLine("Click: Open or close Adventurer's Journal", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move around the minimap", 0.77, 0.83, 0.74)
        GameTooltip:AddLine("/af minimap: Hide or restore", 0.77, 0.83, 0.74)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        if self.bg then self.bg:SetSize(29, 29) end
        if self.border then self.border:SetVertexColor(0.96, 0.83, 0.54, 1) end
        if self.label then self.label:SetTextColor(1, 0.78, 0.36, 1) end
        if GameTooltip then GameTooltip:Hide() end
    end)

    button:SetScript("OnDragStart", function(self)
        self.afMoved = true
        self:SetScript("OnUpdate", function()
            local scale = (UIParent and UIParent:GetEffectiveScale()) or 1
            local x, y = GetCursorPosition()
            local centerX, centerY = Minimap:GetCenter()
            if not (x and y and centerX and centerY) then return end
            local angle = math.deg(Atan2(y / scale - centerY, x / scale - centerX))
            AF.db.settings.minimapAngle = angle
            AF:PositionMinimapButton()
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        -- The drag ends with a mouse release; do not treat it as a normal click.
        self.afMoved = true
        AF:PositionMinimapButton()
    end)

    self:PositionMinimapButton()
    button:SetShown(not self.db.settings.minimapHidden)
end

function AF:ToggleMinimapButton()
    if not self.db then return end
    self.db.settings.minimapHidden = not self.db.settings.minimapHidden
    if not self.minimapButton then self:CreateMinimapButton() end
    if self.minimapButton then
        self.minimapButton:SetShown(not self.db.settings.minimapHidden)
    end
    if self.Print then
        self.Print(self.db.settings.minimapHidden and
            "Minimap button hidden. Type /af minimap to restore it." or
            "Minimap button shown. Drag it to reposition.")
    end
end
