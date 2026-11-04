-- Azeroth Foundry / color-first visual primitives.
-- No bundled client artwork is required. These borders are entirely colored
-- textures and follow the active Foundry theme.
local _, AF = ...
local UI = AF.UI
local unpack = unpack or table.unpack

function UI:FoundryQuestBorder(frame, opts)
    if not frame or not frame.CreateTexture then return end
    opts=opts or {}
    local layer=opts.layer or "BORDER"
    local outset=opts.outset or 0
    local edges={}
    for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local edge=frame:CreateTexture(nil,layer)
        if side=="TOP" or side=="BOTTOM" then
            edge:SetPoint(side.."LEFT",frame,side.."LEFT",-outset,0)
            edge:SetPoint(side.."RIGHT",frame,side.."RIGHT",outset,0)
            edge:SetHeight(1)
        else
            edge:SetPoint("TOP"..side,frame,"TOP"..side,0,outset)
            edge:SetPoint("BOTTOM"..side,frame,"BOTTOM"..side,0,-outset)
            edge:SetWidth(1)
        end
        -- Safe appearance even if the theme engine is unavailable.
        edge:SetColorTexture(.65,.49,.29,1)
        edges[#edges+1]=edge
    end
    if self.RegisterThemeTarget then
        self:RegisterThemeTarget(frame,function(_,tokens)
            for _,edge in ipairs(edges) do
                edge:SetColorTexture(unpack(tokens.border))
            end
        end)
    end
    return edges
end

function UI:FoundryHeadingRule(parent, anchor)
    local rule=parent:CreateTexture(nil,"BORDER")
    rule:SetColorTexture(.79,.56,.26,.43)
    rule:SetHeight(1)
    if anchor then
        rule:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-4)
        rule:SetPoint("TOPRIGHT",anchor,"BOTTOMRIGHT",0,-4)
    else
        rule:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",13,0)
        rule:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-13,0)
    end
    return rule
end
