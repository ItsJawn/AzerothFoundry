-- Azeroth Foundry v0.6.1.2: per-action alerts without session/90-second warning suppression.
-- Events are not certification or server-level restrictions. Unknown outcomes
-- become review requests, NEVER automatic confirmed rule violations.
local _, AF = ...
local function timestamp() return type(time)=="function" and time() or 0 end
local function asText(value)
    if type(value)=="string" then return value:sub(1,150) end
    if type(value)=="number" then return tostring(value) end
    return ""
end
local EVENT_PROBES = {
    TRADE_SHOW={"trade","trade_window"},
    TRADE_ACCEPT_UPDATE={"trade","trade_accepted"},
    TRADE_CLOSED={"trade","trade_closed"},
    AUCTION_HOUSE_SHOW={"auction","auction_browsing"},
    AUCTION_HOUSE_PURCHASE_COMPLETED={"auction","auction_purchase"},
    COMMODITY_PURCHASE_SUCCEEDED={"auction","commodity_purchase"},
    AUCTION_HOUSE_AUCTION_CREATED={"auction","auction_listing"},
    BID_ADDED={"auction","auction_bid"},
    MAIL_SHOW={"mail","mailbox_open"},
    MAIL_SEND_SUCCESS={"mail","mail_sent"},
    GUILDBANKFRAME_OPENED={"storage","guild_bank_open"},
    BANKFRAME_OPENED={"storage","bank_open"},
    GROUP_ROSTER_UPDATE={"group","group_roster"},
    MERCHANT_SHOW={"vendor","merchant_open"},
}
AF.CHARTER_OBSERVER_EVENTS=EVENT_PROBES
local function warn(self,message,severity)
    local c=self:GetExpeditionCharter()
    if not c then return end
    -- v0.6.1.1: chat and screen messages are independently configurable.
    local chat=c.observerWarnings~=false
    if self.CharterAlertEnabled then chat=self:CharterAlertEnabled("chat") end
    if chat and type(self.Print)=="function" then self.Print("Charter: "..message) end
    if self.ShowCharterToast then
        local heading=(severity=="review" and "Expedition: Review Needed") or "Expedition Rule Reminder"
        self:ShowCharterToast(heading,message,severity or "caution")
    end
end
-- Restriction status must come from the CURRENT PUBLISHED VERSION only.
-- Missing rule keys in old published versions mean unconfigured, not denied.
local function restricted(self,rule)
    local c=self:GetExpeditionCharter()
    return c and c.state=="active" and c.rules[rule]==false
end
local function activeMember(self)
    local c=self:GetExpeditionCharter()
    if not c or c.state~="active" then return false end
    local key=self:GetCurrentKey()
    if not key or not self:IsCharterScopedMember(key) then return false end
    return true,key,c
end
local function refreshVisible(self)
    if self.UI and self.UI.currentPage=="Self-Found" then self:RefreshUI() end
end
function AF:GetCharterObserverCapability()
    local report={supported={},unsupported={}}
    for event in pairs(EVENT_PROBES) do
        if self.observerSupported and self.observerSupported[event] then
            report.supported[#report.supported+1]=event
        else
            report.unsupported[#report.unsupported+1]=event
        end
    end
    table.sort(report.supported);table.sort(report.unsupported)
    return report
end
function AF:SetCharterObserverWarnings(shouldWarn)
    local c=self:GetExpeditionCharter()
    if not c then return false end
    c.observerWarnings=shouldWarn and true or false
    c.observerChatAlerts=shouldWarn and true or false
    self:RefreshUI()
    return true
end
-- All rule links are *contextual reminders*, not assertions that the linked
-- violation occurred. A generic interface cannot identify recipients, loot
-- origins or which members are outsiders.
local RULE_CONTEXT = {
    trade_window={"outsideTrade","outsideHelp","altShare","outsideCraft","outsiderLoot"},
    trade_accepted={"outsideTrade","outsideHelp","altShare","outsideCraft","outsiderLoot"},
    auction_browsing={"auctionPurchase","auctionPost","auctionBid"},
    auction_purchase={"auctionPurchase"}, commodity_purchase={"auctionPurchase"},
    auction_listing={"auctionPost"}, auction_bid={"auctionBid"},
    mailbox_open={"outsideMail","outsideMailSend","altShare"},
    mail_sent={"outsideMailSend"},
    guild_bank_open={"guildBank"},
    bank_open={"warbandShare"},
    group_roster={"outsideParty","outsideHelp","outsideCarry","outsiderLoot"},
    merchant_open={"vendor","vendorSell"},
}
local RULE_SHORT = {
    outsideTrade="outside trades", outsideHelp="outside assistance", altShare="alt sharing",
    outsiderLoot="outsider loot", outsideCraft="outsider crafting services", auctionPurchase="AH buying", auctionPost="AH listings",
    auctionBid="AH bidding", outsideMail="outside mail",outsideMailSend="mail to outsiders",
    guildBank="guild bank", warbandShare="non-enrolled shared storage",
    outsideParty="outside groups",outsideCarry="outside carries",
    vendor="vendor buying",vendorSell="vendor selling",
}
local ACTION_SUMMARY = {
    trade_window="Trade opened; partner and outcome are unknown.",
    trade_accepted="Both accepted; the trade may still fail or be canceled.",
    trade_closed="Trade closed; completion has not been established.",
    auction_browsing="Auction House opened; browsing is not a transaction.",
    auction_purchase="Auction purchase-success event received; source still needs review.",
    commodity_purchase="Commodity purchase-success event received; source needs review.",
    auction_listing="Auction listing event received; sale not established.",
    auction_bid="Auction bid event received; item receipt not established.",
    mailbox_open="Mailbox opened; no attachments received or sent were established.",
    mail_sent="Mail sent; recipient membership and contents are unknown.",
    guild_bank_open="Guild bank opened; no transfer established.",
    bank_open="Bank opened; account-shared resource use is not established.",
    group_roster="Party/raid roster changed; help or carries are not established.",
    merchant_open="Merchant opened; no purchase or sale established.",
}
local function contextualRules(self,action,primary)
    local c=self:GetExpeditionCharter()
    local ids=RULE_CONTEXT[action] or (primary and {primary}) or {}
    local relevant,restrictedIds,labels={}, {}, {}
    for _,id in ipairs(ids) do
        if c.rules[id]~=nil then
            relevant[#relevant+1]=id
            if c.rules[id]==false then
                restrictedIds[#restrictedIds+1]=id
                labels[#labels+1]=RULE_SHORT[id] or id
            end
        end
    end
    return relevant,restrictedIds,labels
end
local function briefRules(labels)
    if #labels==0 then return "" end
    local names={}
    for i=1,math.min(2,#labels) do names[#names+1]=labels[i] end
    local text=table.concat(names,", ")
    if #labels>2 then text=text.." +"..(#labels-2).." more" end
    return text
end
function AF:ObserveCharterActivity(action,rule,detail,event,needsReview)
    local ok,key,c=activeMember(self)
    if not ok then return false end
    -- There is deliberately no timed deduplication here. Separate interactions
    -- can occur seconds apart; all need individual Chronicle records/reminders.
    -- Only the GROUP_ROSTER_UPDATE handler checks an unchanged roster fingerprint.
    local t=timestamp()
    local relevant,deniedIds,deniedLabels=contextualRules(self,action,rule)
    local denied=#deniedIds>0
    local note=detail
    if #relevant>0 then
        note=note.." [Charter rules: "..table.concat(relevant,", ").."]"
    end
    if denied then note=note.." [Restricted: "..table.concat(deniedIds,", ").."]" end
    local record=self:RecordCharterEvent("observed_"..action,key,note,"client_event")
    if record then
        record.sourceEvent=event;record.ruleId=rule
        record.ruleIds=relevant;record.restrictedRules=deniedIds;record.outcome="unverified"
    end
    if denied and needsReview then
        local review={id=self:NextID(),timestamp=t,
            kind=(EVENT_PROBES[event] and EVENT_PROBES[event][1] or "other"),
            detail=note,level="review",status="open",key=key,version=c.version,
            evidence="client_event",ruleId=rule,ruleIds=deniedIds,sourceEvent=event,
            note="Review needed: event evidence does not independently establish a prohibited transfer or outsider source."}
        if record then record.reviewId=review.id;review.eventId=record.id end
        c.reviews[#c.reviews+1]=review
        warn(self,"Needs review: "..(ACTION_SUMMARY[action] or action).." ("..briefRules(deniedLabels)..")","review")
    elseif denied then
        -- Every new relevant interface/roster observation gets a fresh reminder,
        -- not a 90-second or once-per-visit warning. No automatic conviction.
        warn(self,(ACTION_SUMMARY[action] or detail).." Rules: "..briefRules(deniedLabels)..".","caution")
    elseif self.ShowCharterToast then
        -- Permitted/unconfigured actions are still observed in the Chronicle,
        -- and may show a low-severity toast when that surface is enabled.
        self:ShowCharterToast("Expedition Activity",ACTION_SUMMARY[action] or detail,"observed")
    end
    refreshVisible(self)
    return true
end
local function rosterFingerprint()
    if type(IsInGroup)~="function" or not IsInGroup() then return "none" end
    local count=(type(GetNumGroupMembers)=="function" and GetNumGroupMembers()) or 0
    local names={}
    local prefix=(type(IsInRaid)=="function" and IsInRaid()) and "raid" or "party"
    for i=1,count do
        local unit=prefix..i
        local id=(type(UnitGUID)=="function" and UnitGUID(unit))
            or (type(UnitName)=="function" and UnitName(unit))
        if id then names[#names+1]=tostring(id) end
    end
    table.sort(names)
    return prefix..":"..tostring(count)..":"..table.concat(names,"|")
end
function AF:OnCharterObserverEvent(event,...)
    if event=="ADDON_LOADED" then
        if ...=="Blizzard_AuctionHouseUI" and self.InstallCharterAuctionHooks then
            self:InstallCharterAuctionHooks()
            if self.DeferredCharterAuctionCheck then self:DeferredCharterAuctionCheck() end
        end
        return
    end
    if event=="AUCTION_HOUSE_CLOSED" then
        if self.ResetCharterAuctionSession then self:ResetCharterAuctionSession() end
        return
    end
    if event=="AUCTION_HOUSE_SHOW" and self.OnCharterAuctionHouseShow then
        self:OnCharterAuctionHouseShow()
    end
    if not activeMember(self) then return end
    if event=="TRADE_SHOW" then
        self.observerTrade={openedAt=timestamp(),accepted=false}
        self:ObserveCharterActivity("trade_window","outsideTrade","Trade interface opened; outcome and partner not verified.",event,false)
    elseif event=="TRADE_ACCEPT_UPDATE" then
        local a,b=...
        -- Acceptance is NOT transaction completion. Even both accepted may be
        -- followed by cancellation or error; no confirmed conflict recorded.
        self.observerTrade=self.observerTrade or {}
        if a==1 and b==1 then
            -- Some clients emit the same accepted state repeatedly. Record
            -- one attempt per transition, not one per redundant callback.
            if not self.observerTrade.accepted then
                self.observerTrade.accepted=true
                self:ObserveCharterActivity("trade_accepted","outsideTrade","Both trade acceptances observed; completion and partner membership unknown.",event,true)
            end
        else
            self.observerTrade.accepted=false
        end
    elseif event=="TRADE_CLOSED" then
        if self.observerTrade then
            self:ObserveCharterActivity("trade_closed",nil,"Trade interface closed; successful exchange NOT established.",event,false)
        end
        self.observerTrade=nil
    elseif event=="AUCTION_HOUSE_SHOW" then
        self:ObserveCharterActivity("auction_browsing","auctionPurchase","Auction House opened; browsing is not a purchase.",event,false)
    elseif event=="AUCTION_HOUSE_PURCHASE_COMPLETED" or event=="COMMODITY_PURCHASE_SUCCEEDED" then
        self:ObserveCharterActivity(event=="AUCTION_HOUSE_PURCHASE_COMPLETED" and "auction_purchase" or "commodity_purchase",
            "auctionPurchase","Auction purchase-success event received; item provenance and delivery still require review.",event,true)
    elseif event=="AUCTION_HOUSE_AUCTION_CREATED" then
        self:ObserveCharterActivity("auction_listing","auctionPost","Auction listing creation event received; sale not established.",event,true)
    elseif event=="BID_ADDED" then
        self:ObserveCharterActivity("auction_bid","auctionBid","Auction bid-added event received; item acquisition not established.",event,true)
    elseif event=="MAIL_SHOW" then
        self:ObserveCharterActivity("mailbox_open","outsideMail","Mailbox opened; no receipt or attachment acceptance established.",event,false)
    elseif event=="MAIL_SEND_SUCCESS" then
        self:ObserveCharterActivity("mail_sent","outsideMailSend","Mail successfully sent; recipient affiliation and contents not verified.",event,true)
    elseif event=="GUILDBANKFRAME_OPENED" then
        self:ObserveCharterActivity("guild_bank_open","guildBank","Guild bank interface opened; no transfer observed.",event,false)
    elseif event=="BANKFRAME_OPENED" then
        self:ObserveCharterActivity("bank_open","warbandShare","Bank opened; shared-storage access or provenance not established.",event,false)
    elseif event=="GROUP_ROSTER_UPDATE" then
        -- This client event can be emitted repeatedly for an unchanged roster.
        -- Only a *changed* membership fingerprint merits a fresh observation.
        local fingerprint=tostring(self:GetCurrentKey())..":"..tostring(self:GetExpeditionCharter().id)..":"..rosterFingerprint()
        if self.observerGroupFingerprint~=fingerprint then
            self.observerGroupFingerprint=fingerprint
            if fingerprint:sub(-5)~=":none" then
                self:ObserveCharterActivity("group_roster","outsideParty","Group roster changed; outsider presence, carried progress, and loot provenance not verified.",event,false)
            end
        end
    elseif event=="MERCHANT_SHOW" then
        self:ObserveCharterActivity("merchant_open","vendor","NPC merchant opened; purchase or sale not established.",event,false)
    end
end
function AF:InitializeCharterRuleObserver()
    if self.observerFrame then return end
    local frame=CreateFrame("Frame")
    self.observerFrame=frame
    self.observerSupported={}
    for _,event in ipairs({"ADDON_LOADED","AUCTION_HOUSE_CLOSED"}) do
        pcall(frame.RegisterEvent,frame,event)
    end
    if self.InstallCharterAuctionHooks then self:InstallCharterAuctionHooks() end
    for event in pairs(EVENT_PROBES) do
        -- Forever rejects unknown events; this is a feature probe, NOT proof
        -- that the event will actually fire for every relevant game action.
        local ok=pcall(frame.RegisterEvent,frame,event)
        if ok then self.observerSupported[event]=true end
    end
    frame:SetScript("OnEvent",function(_,event,...)
        if self.db and self.GetExpeditionCharter then
            local safe,err=pcall(self.OnCharterObserverEvent,self,event,...)
            if not safe and not self.observerErrorShown then
                self.observerErrorShown=true
                if self.Print then self.Print("Rule Observer disabled an event due to an API error; other systems remain operational. "..asText(err)) end
            end
        end
    end)
end
