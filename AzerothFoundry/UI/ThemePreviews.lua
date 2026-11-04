-- Azeroth Foundry v0.7.0.1: read-only live previews of curated global styles.
-- Previews are not developer Art Lab inspectors and never change SavedVariables.
local _, AF = ...
local UI = AF.UI
local unpack = unpack or table.unpack

local function Fill(frame, r,g,b,a)
    local tex=frame:CreateTexture(nil,"BACKGROUND")
    tex:SetAllPoints(frame)
    tex:SetColorTexture(r,g,b,a or 1)
    return tex
end
local function Line(frame, edge, width)
    local tex=frame:CreateTexture(nil,"OVERLAY")
    if edge=="TOP" or edge=="BOTTOM" then
        tex:SetPoint(edge.."LEFT",frame,edge.."LEFT",0,0)
        tex:SetPoint(edge.."RIGHT",frame,edge.."RIGHT",0,0)
        tex:SetHeight(width or 1)
    else
        tex:SetPoint("TOP"..edge,frame,"TOP"..edge,0,0)
        tex:SetPoint("BOTTOM"..edge,frame,"BOTTOM"..edge,0,0)
        tex:SetWidth(width or 1)
    end
    return tex
end
local function Label(frame, text, size, center)
    local s=frame:CreateFontString(nil,"OVERLAY",size=="small" and "GameFontNormalSmall" or "GameFontHighlightSmall")
    s:SetText(text)
    s:SetTextColor(.96,.89,.77,1)
    if s.SetShadowOffset then s:SetShadowOffset(0,0) end
    if s.SetShadowColor then s:SetShadowColor(0,0,0,0) end
    s:SetJustifyH(center and "CENTER" or "LEFT")
    s:SetJustifyV("MIDDLE")
    return s
end

-- Built to fit a fixed-height Settings row. The preview never captures mouse
-- input and uses ThemeTokens, the same state used by live Foundry controls.
function UI:CreateThemeFamilyPreview(parent, family)
    local f=CreateFrame("Frame",nil,parent)
    f:SetSize(190,34)
    f:EnableMouse(false)
    local shade=Fill(f,.085,.077,.068,1)
    local rim={}
    for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        rim[#rim+1]=Line(f,side,1)
    end
    local update
    if family=="border" then
        local panel=CreateFrame("Frame",nil,f)
        panel:SetPoint("TOPLEFT",f,"TOPLEFT",7,-5)
        panel:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-7,5)
        local surface=Fill(panel,.15,.12,.09,1)
        local label=Label(panel,"Panel border", "small",true)
        label:SetAllPoints(panel)
        if self.FoundryQuestBorder then
            self:FoundryQuestBorder(panel,{cap=8,alpha=.95})
        end
        update=function(tokens)
            surface:SetColorTexture(unpack(tokens.shell))
            label:SetTextColor(unpack(tokens.text))
        end
    elseif family=="background" then
        local dark=CreateFrame("Frame",nil,f)
        dark:SetPoint("TOPLEFT",f,"TOPLEFT",6,-5)
        dark:SetSize(85,24)
        local ink=Fill(dark,.10,.08,.06,1)
        local a=Label(dark,"Data", "small",true)
        a:SetAllPoints(dark)
        local paper=CreateFrame("Frame",nil,f)
        paper:SetPoint("TOPRIGHT",f,"TOPRIGHT",-6,-5)
        paper:SetSize(85,24)
        local parchment=Fill(paper,.8,.7,.5,1)
        local b=Label(paper,"Reading", "small",true)
        b:SetAllPoints(paper)
        update=function(tokens)
            ink:SetColorTexture(unpack(tokens.shell))
            parchment:SetColorTexture(unpack(tokens.paper))
            a:SetTextColor(unpack(tokens.text))
            b:SetTextColor(unpack(tokens.ink))
        end
    elseif family=="button" then
        local normal=self:Button(f,"Normal",nil)
        normal:SetSize(82,23)
        normal:SetPoint("LEFT",f,"LEFT",6,0)
        normal:EnableMouse(false)
        local hover=self:Button(f,"Hover",nil)
        hover:SetSize(82,23)
        hover:SetPoint("RIGHT",f,"RIGHT",-6,0)
        hover:EnableMouse(false)
        local glint=hover:CreateTexture(nil,"OVERLAY")
        glint:SetAllPoints(hover)
        glint:SetColorTexture(1,.85,.48,.14)
        hover.afThemeHover=true
        update=function(tokens)
            UI:ApplyThemeButton(normal,tokens)
            UI:ApplyThemeButton(hover,tokens)
            glint:SetShown(false)
        end
    elseif family=="navigation" then
        local normal=CreateFrame("Frame",nil,f)
        normal:SetPoint("TOPLEFT",f,"TOPLEFT",6,-5)
        normal:SetSize(85,24)
        local selected=CreateFrame("Frame",nil,f)
        selected:SetPoint("TOPRIGHT",f,"TOPRIGHT",-6,-5)
        selected:SetSize(85,24)
        local nbg=Fill(normal,.18,.15,.12,1)
        local sbg=Fill(selected,.23,.20,.15,1)
        local active=selected:CreateTexture(nil,"OVERLAY")
        active:SetPoint("TOPLEFT",selected,"TOPLEFT",0,0)
        active:SetPoint("BOTTOMLEFT",selected,"BOTTOMLEFT",0,0)
        active:SetWidth(3)
        local nlab=Label(normal,"Normal","small",true)
        nlab:SetAllPoints(normal)
        local slab=Label(selected,"Selected","small",true)
        slab:SetAllPoints(selected)
        update=function(tokens)
            nbg:SetColorTexture(.15,.18,.21,.98)
            sbg:SetColorTexture(.25,.28,.32,1)
            active:SetColorTexture(unpack(tokens.accent))
            nlab:SetTextColor(unpack(tokens.text))
            slab:SetTextColor(unpack(tokens.accent))
        end
    elseif family=="accent" then
        local sample=Label(f,"Foundry title", "small",false)
        sample:SetPoint("TOPLEFT",f,"TOPLEFT",10,-4)
        sample:SetSize(160,16)
        local bar=f:CreateTexture(nil,"ARTWORK")
        bar:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",10,7)
        bar:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-10,7)
        bar:SetHeight(2)
        update=function(tokens)
            sample:SetTextColor(unpack(tokens.accent))
            bar:SetColorTexture(unpack(tokens.rainbow and tokens.accent2 or tokens.accent))
        end
    else
        update=function() end
    end
    self:RegisterThemeTarget(f,function(_,tokens)
        for _,edge in ipairs(rim) do edge:SetColorTexture(unpack(tokens.border)) end
        shade:SetColorTexture(.080,.070,.061,1)
        update(tokens)
    end)
    return f
end
