-- Azeroth Foundry v0.6.1.2: queued observer toasts and repeatable Auction House Buy-page reminder.
-- This module NEVER replaces or invokes a protected Auction House purchase action.
-- The cover is only an advisory overlay on Blizzard's visible Buy workspace.
local _, AF = ...
local min,max=math.min,math.max

local function charter(self)
    return self.GetExpeditionCharter and self:GetExpeditionCharter()
end
local function scoped(self)
    local c=charter(self)
    if not c or c.state~="active" or c.rules.auctionPurchase~=false then return false end
    local key=self.GetCurrentKey and self:GetCurrentKey()
    return key and self.IsCharterScopedMember and self:IsCharterScopedMember(key) or false
end
local function enabled(c,kind)
    if not c then return false end
    if kind=="chat" then
        if c.observerChatAlerts~=nil then return c.observerChatAlerts~=false end
    elseif kind=="toast" then
        if c.observerToastAlerts~=nil then return c.observerToastAlerts~=false end
    elseif kind=="gate" then
        return c.observerAuctionGate~=false
    end
    -- An old v0.6.1 user who disabled observer warnings stays opted out
    -- of *both* notification surfaces until they enable one themselves.
    return c.observerWarnings~=false
end
function AF:CharterAlertEnabled(kind)
    return enabled(charter(self),kind)
end
function AF:SetCharterAlertEnabled(kind,flag)
    local c=charter(self)
    if not c then return false end
    if kind=="chat" then c.observerChatAlerts=not not flag
    elseif kind=="toast" then c.observerToastAlerts=not not flag
    elseif kind=="gate" then c.observerAuctionGate=not not flag
    else return false end
    if kind=="gate" then self:RefreshCharterAuctionGate() end
    if kind=="toast" and not flag and self.charterToast then
        self.charterToast.pending={}
        self.charterToast:Hide()
    end
    if self.RefreshUI then self:RefreshUI() end
    return true
end

local function font(parent,size,color,justify)
    local fs=parent:CreateFontString(nil,"OVERLAY",size or "GameFontNormal")
    fs:SetTextColor(unpack(color))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetJustifyV("MIDDLE")
    return fs
end
local function fill(parent,r,g,b,a)
    local t=parent:CreateTexture(nil,"BACKGROUND")
    t:SetAllPoints(parent)
    t:SetColorTexture(r,g,b,a)
    return t
end
local function border(parent,r,g,b)
    local t=parent:CreateTexture(nil,"BORDER")
    t:SetHeight(2)
    t:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",2,2)
    t:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-2,2)
    t:SetColorTexture(r,g,b,.9)
end
-- Queue rapid, distinct observations rather than replacing an alert before it can be read.
-- Event-level deduplication belongs to the observer, not the presentation layer.
local function presentToast(frame,entry)
    local c=(entry.severity=="review" and {.92,.30,.25}) or (entry.severity=="caution" and {1,.67,.23}) or {.51,.80,.55}
    frame.accent:SetColorTexture(c[1],c[2],c[3],1)
    frame.heading:SetText(entry.title or "Expedition Notice")
    frame.message:SetText(entry.message or "")
    frame.elapsed=0
    frame:SetAlpha(0)
    frame:Show()
end
function AF:EnsureCharterToast()
    if self.charterToast then return self.charterToast end
    local f=CreateFrame("Frame",nil,UIParent)
    f:SetFrameStrata("HIGH")
    f:SetSize(430,88)
    f:SetPoint("TOP",UIParent,"TOP",0,-125)
    f:EnableMouse(false)
    fill(f,.10,.071,.045,.96)
    border(f,.68,.48,.27)
    local accent=f:CreateTexture(nil,"ARTWORK")
    accent:SetPoint("TOPLEFT",f,"TOPLEFT",0,0)
    accent:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",0,0)
    accent:SetWidth(5)
    local heading=font(f,"GameFontNormal",{1,.79,.43,1})
    heading:SetPoint("TOPLEFT",f,"TOPLEFT",17,-8)
    heading:SetPoint("TOPRIGHT",f,"TOPRIGHT",-14,-8)
    heading:SetHeight(20)
    local message=font(f,"GameFontHighlightSmall",{.96,.90,.78,1})
    message:SetPoint("TOPLEFT",f,"TOPLEFT",17,-28)
    message:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-14,8)
    message:SetJustifyV("TOP")
    f.accent=accent;f.heading=heading;f.message=message;f.elapsed=0;f.pending={};f.overflow=0
    f:SetScript("OnUpdate",function(frame,dt)
        local current=charter(self)
        local member=self.GetCurrentKey and self.IsCharterScopedMember and self:IsCharterScopedMember(self:GetCurrentKey())
        if not current or current.state~="active" or not member then
            frame.pending={};frame.overflow=0;frame:Hide()
            return
        end
        frame.elapsed=frame.elapsed+min(dt,.25)
        local t=frame.elapsed
        local a=(t<.18 and t/.18) or (t<3.25 and 1) or (t<3.9 and (3.9-t)/.65) or 0
        frame:SetAlpha(max(0,min(1,a)))
        if t>=3.9 then
            if #frame.pending>0 then
                presentToast(frame,table.remove(frame.pending,1))
            elseif frame.overflow>0 then
                local skipped=frame.overflow
                frame.overflow=0
                presentToast(frame,{title="Expedition Activity",message=skipped.." additional notices occurred; see the Chronicle for each recorded event.",severity="observed"})
            else frame:Hide() end
        end
    end)
    f:Hide()
    self.charterToast=f
    return f
end
function AF:ShowCharterToast(title,message,severity)
    if not self:CharterAlertEnabled("toast") then return end
    local f=self:EnsureCharterToast()
    local entry={title=title,message=message,severity=severity}
    if f:IsShown() then
        -- Bound the UI queue during exceptional event bursts; all event entries
        -- remain in the Chronicle. Overflow is summarized instead of silently lost.
        if #f.pending<20 then f.pending[#f.pending+1]=entry
        else f.overflow=f.overflow+1 end
    else
        presentToast(f,entry)
    end
end

local BUY_MODES={"Buy","ItemBuy","CommoditiesBuy","WoWTokenBuy"}
local function isBuyView(ah)
    if not ah or not ah.IsShown or not ah:IsShown() then return false end
    local modes=_G.AuctionHouseFrameDisplayMode
    if modes and ah.displayMode then
        for _,id in ipairs(BUY_MODES) do
            if ah.displayMode==modes[id] then return true end
        end
        return false
    end
    -- No mode metadata: use only known Blizzard frame visibility.
    for _,field in ipairs({"BrowseResultsFrame","ItemBuyFrame","CommoditiesBuyFrame","WoWTokenResults"}) do
        local sub=ah[field]
        if sub and sub.IsShown and sub:IsShown() then return true end
    end
    return false
end
local function quietButton(parent,caption,onClick)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetHeight(27)
    b:SetText(caption)
    b:SetScript("OnClick",onClick)
    return b
end
local function makeGate(self,ah)
    local outer=CreateFrame("Frame",nil,ah)
    outer:SetFrameStrata("DIALOG")
    outer:SetFrameLevel(max(150,ah:GetFrameLevel()+60))
    -- Leave Blizzard's tabs and close control accessible. Never parent to or
    -- change a protected buy button, and never synthesize native button clicks.
    outer:SetPoint("TOPLEFT",ah,"TOPLEFT",8,-43)
    outer:SetPoint("BOTTOMRIGHT",ah,"BOTTOMRIGHT",-8,38)
    outer:EnableMouse(true)
    fill(outer,.04,.027,.020,.84)
    local card=CreateFrame("Frame",nil,outer)
    card:SetSize(428,196)
    card:SetPoint("CENTER",outer,"CENTER",0,0)
    fill(card,.16,.10,.066,.98)
    border(card,.72,.50,.28)
    local headline=font(card,"GameFontNormalLarge",{1,.75,.44,1},"CENTER")
    headline:SetPoint("TOPLEFT",card,"TOPLEFT",17,-16)
    headline:SetPoint("TOPRIGHT",card,"TOPRIGHT",-17,-16)
    headline:SetHeight(31)
    headline:SetText("Expedition Charter Warning")
    local copy=font(card,"GameFontHighlight",{.95,.87,.74,1},"CENTER")
    copy:SetPoint("TOPLEFT",card,"TOPLEFT",26,-55)
    copy:SetPoint("TOPRIGHT",card,"TOPRIGHT",-26,-55)
    copy:SetHeight(69)
    copy:SetJustifyV("TOP")
    copy:SetText("Your active Self-Found charter restricts Auction House purchases.\n\nBrowsing is not a breach. This is a reminder, not a game restriction.")
    local instruction=font(card,"GameFontHighlightSmall",{.79,.68,.49,1},"CENTER")
    instruction:SetPoint("TOPLEFT",card,"TOPLEFT",14,-127)
    instruction:SetPoint("TOPRIGHT",card,"TOPRIGHT",-14,-127)
    instruction:SetHeight(20)
    instruction:SetText("Confirmation only reveals the Buy page; it does not purchase anything.")
    local later=quietButton(card,"Leave AH",function()
        -- Leave without consenting to this Buy page. Never invoke a buy API.
        if type(HideUIPanel)=="function" then pcall(HideUIPanel,ah) end
        if ah and ah.IsShown and ah:IsShown() and ah.Hide then pcall(ah.Hide,ah) end
    end)
    later:SetPoint("BOTTOMLEFT",card,"BOTTOMLEFT",18,12)
    later:SetSize(135,29)
    local proceed=quietButton(card,"I Understand / View Buy",function()
        self.charterAuctionAcknowledged=true
        -- Explicit consent to VIEW is not consent to buy, and is not a breach.
        if scoped(self) and self.RecordCharterEvent then
            self:RecordCharterEvent("acknowledged_auction_buy_notice",self:GetCurrentKey(),
                "Player acknowledged the Auction House Buy-page reminder; no purchase established.","player_acknowledged")
        end
        outer:Hide()
    end)
    proceed:SetPoint("BOTTOMRIGHT",card,"BOTTOMRIGHT",-18,12)
    proceed:SetSize(238,29)
    outer:Hide()
    self.charterAuctionGateFrame=outer
    self.charterAuctionGateHost=ah
    return outer
end
function AF:RefreshCharterAuctionGate()
    local ah=_G.AuctionHouseFrame
    local old=self.charterAuctionGateFrame
    if old and self.charterAuctionGateHost~=ah then old:Hide();old=nil;self.charterAuctionGateFrame=nil end
    if not isBuyView(ah) then
        -- Each return to Buy is a new acknowledgement, even in the same AH visit.
        self.charterAuctionAcknowledged=nil
        if old then old:Hide() end
        return
    end
    if not scoped(self) or not self:CharterAlertEnabled("gate") or self.charterAuctionAcknowledged then
        if old then old:Hide() end
        return
    end
    local frame=old or makeGate(self,ah)
    frame:Show()
end
function AF:ResetCharterAuctionSession()
    self.charterAuctionAcknowledged=nil
    if self.charterAuctionGateFrame then self.charterAuctionGateFrame:Hide() end
end
function AF:DeferredCharterAuctionCheck()
    if C_Timer and type(C_Timer.After)=="function" then
        C_Timer.After(0,function()if self.db then self:RefreshCharterAuctionGate() end end)
    else
        -- A single frame tick, for Forever builds without C_Timer.After.
        if not self.charterAuctionDefer then self.charterAuctionDefer=CreateFrame("Frame") end
        local driver=self.charterAuctionDefer
        driver:SetScript("OnUpdate",function(f)
            f:SetScript("OnUpdate",nil)
            if self.db then self:RefreshCharterAuctionGate() end
        end)
    end
end
function AF:InstallCharterAuctionHooks()
    local ah=_G.AuctionHouseFrame
    if not ah or self.charterAuctionHookHost==ah then return end
    self.charterAuctionHookHost=ah
    ah:HookScript("OnHide",function()self:ResetCharterAuctionSession() end)
    ah:HookScript("OnShow",function()
        self:DeferredCharterAuctionCheck()
    end)
    if type(hooksecurefunc)=="function" and type(ah.SetDisplayMode)=="function" then
        -- Secure post-hook: never replace the Blizzard method or change its args.
        pcall(hooksecurefunc,ah,"SetDisplayMode",function()
            self:DeferredCharterAuctionCheck()
        end)
    end
    for _,field in ipairs({"BrowseResultsFrame","ItemBuyFrame","CommoditiesBuyFrame","WoWTokenResults"}) do
        local sub=ah[field]
        if sub and type(sub.HookScript)=="function" then
            sub:HookScript("OnShow",function()self:DeferredCharterAuctionCheck()end)
        end
    end
end
function AF:OnCharterAuctionHouseShow()
    self:InstallCharterAuctionHooks()
    self:DeferredCharterAuctionCheck()
end
