-- Azeroth Foundry v0.6.0: voluntary Expedition Charter and local evidence log.
-- Client-side journal only. NOT server enforcement or independent certification.
local _, AF = ...

local function now() return type(time)=="function" and time() or 0 end
local function copy(src)
    local out = {}
    if type(src)=="table" then for k,v in pairs(src) do out[k]=v end end
    return out
end
local function text(value, maxLen)
    local s=type(value)=="string" and value or ""
    s=s:gsub("[%c]", " ")
    return s:sub(1,maxLen or 500)
end

AF.CHARTER_RULE_DEFS = {
    -- Existing IDs MUST remain unchanged for saved charters and earlier version records.
    {id="outsideTrade", group="Trading", label="Trading with outsiders", note="Direct player-to-player item or gold trades with someone outside the enrolled Expedition. Opening a trade window by itself proves nothing."},
    {id="auctionPurchase", group="Auction House", label="Auction House purchases", note="Buyout and commodity purchases from the Auction House. Merely browsing is not a purchase."},
    {id="outsideMail", group="Mail & Storage", label="Mail from outsiders", note="Receiving player mail, gold or items from outside your Expedition. Mail headers alone do not prove acceptance of attachments."},
    {id="altShare", group="Mail & Storage", label="Sharing between enrolled alts", note="Transfer of items or gold among your enrolled characters. Available only within the charter's member scope."},
    {id="outsideParty", group="Cooperation", label="Grouping with outsiders", note="Joining a party or raid with non-enrolled players. Group presence does not prove receiving outside help."},
    {id="outsideHelp", group="Cooperation", label="Outside gifts and assistance", note="Accepting donated items, carries, paid services or other outside help. Not all forms are observable through addon events."},
    {id="vendor", group="NPC Economy", label="NPC vendor purchases", note="Buying items from ordinary NPC merchants. Opening a vendor window is not proof of a purchase."},
    -- New optional rules: new keys are NOT added to an already published charter
    -- until the player publishes a revision (the old published version remains unchanged).
    {id="outsideMailSend", group="Mail & Storage", label="Sending mail to outsiders", note="Sending items, gold or mail to characters who are not enrolled. A successful mail event does not expose a reliable recipient to this observer."},
    {id="auctionPost", group="Auction House", label="Posting auctions", note="Creating player-run Auction House listings. Posting is different from selling or buying items."},
    {id="auctionBid", group="Auction House", label="Bidding on auctions", note="Placing bids on auctions. A bid is not evidence that an item was received."},
    {id="guildBank", group="Mail & Storage", label="Guild bank resources", note="Taking or depositing materials in a guild bank. Opening it does not prove a transfer."},
    {id="warbandShare", group="Mail & Storage", label="Non-enrolled shared storage", note="Using account/warband storage to obtain items from characters outside the Expedition. Ownership cannot be proven from bag snapshots."},
    {id="outsideCraft", group="Cooperation", label="Outsider crafting services", note="Having a non-enrolled player craft or enchant an item for you. Requires direct evidence or player declaration."},
    {id="outsideCarry", group="Cooperation", label="Outsider dungeon carries", note="Accepting progress or loot from a carried dungeon/raid. Grouping alone does not prove a carry."},
    {id="outsiderLoot", group="Cooperation", label="Outsider loot transfers", note="Receiving loot that originated with an outsider. Ordinary loot events do not guarantee provenance."},
    {id="vendorSell", group="NPC Economy", label="Selling to NPC vendors", note="Selling items to ordinary NPC merchants. Vendor visits alone are not evidence of a sale."},
}
local PRESETS = {
    solo = {outsideTrade=false, auctionPurchase=false, outsideMail=false, altShare=false,
        outsideParty=false, outsideHelp=false, vendor=true, outsideMailSend=false,
        auctionPost=false, auctionBid=false, guildBank=false, warbandShare=false,
        outsideCraft=false, outsideCarry=false, outsiderLoot=false, vendorSell=true},
    account = {outsideTrade=false, auctionPurchase=false, outsideMail=false, altShare=true,
        outsideParty=true, outsideHelp=false, vendor=true, outsideMailSend=false,
        auctionPost=false, auctionBid=false, guildBank=false, warbandShare=false,
        outsideCraft=false, outsideCarry=false, outsiderLoot=false, vendorSell=true},
    custom = {outsideTrade=false, auctionPurchase=false, outsideMail=false, altShare=true,
        outsideParty=true, outsideHelp=false, vendor=true, outsideMailSend=false,
        auctionPost=false, auctionBid=false, guildBank=false, warbandShare=false,
        outsideCraft=false, outsideCarry=false, outsiderLoot=false, vendorSell=true},
}
AF.CHARTER_PRESET_NAMES = {solo="Solo Self-Found",account="Account Self-Found",custom="Custom Expedition"}
local function normalizeRules(rules, preset)
    local clean={}
    local base=PRESETS[preset] or PRESETS.account
    for _,def in ipairs(AF.CHARTER_RULE_DEFS) do
        if type(rules)=="table" and type(rules[def.id])=="boolean" then
            clean[def.id]=rules[def.id]
        else
            clean[def.id]=base[def.id]
        end
    end
    return clean
end
local function newCharter()
    return {
        schema=1, state="draft", id=nil, preset="account", rules=copy(PRESETS.account),
        draft={preset="account", rules=copy(PRESETS.account)},
        version=0, versions={}, events={}, reviews={}, periods={},
        createdAt=now(), startedAt=nil, endedAt=nil,
    }
end
function AF:InitializeExpeditionCharter()
    local exp=self:GetExpedition()
    if not exp then return end
    exp.charterArchive=type(exp.charterArchive)=="table" and exp.charterArchive or {}
    if type(exp.charter)~="table" then exp.charter=newCharter() end
    local c=exp.charter
    if c.state~="active" and c.state~="ended" then c.state="draft" end
    if not PRESETS[c.preset] then c.preset="account" end
    -- Preserve the EXACT published key set. Newly defined permissions must be
    -- explicitly published in a new revision, not silently added at login.
    if c.state=="draft" then c.rules=normalizeRules(c.rules,c.preset)
    else c.rules=type(c.rules)=="table" and c.rules or {} end
    c.versions=type(c.versions)=="table" and c.versions or {}
    c.events=type(c.events)=="table" and c.events or {}
    c.reviews=type(c.reviews)=="table" and c.reviews or {}
    c.periods=type(c.periods)=="table" and c.periods or {}
    c.version=math.max(0,tonumber(c.version) or 0)
    if c.state=="draft" then
        c.draft=type(c.draft)=="table" and c.draft or {preset=c.preset,rules=copy(c.rules)}
    end
    if c.draft then
        if not PRESETS[c.draft.preset] then c.draft.preset=c.preset end
        c.draft.rules=normalizeRules(c.draft.rules,c.draft.preset)
    end
end
function AF:GetExpeditionCharter()
    local exp=self:GetExpedition()
    return exp and exp.charter
end
function AF:GetCharterMemberCount()
    local members=self:GetExpeditionMembers()
    return #members
end
function AF:CharterDraft()
    local c=self:GetExpeditionCharter()
    return c and c.draft
end
function AF:ChooseCharterPreset(preset)
    if not PRESETS[preset] then return false,"Unknown ruleset" end
    local c=self:GetExpeditionCharter()
    if not c or c.state=="ended" then return false,"Start a new charter first" end
    c.draft={preset=preset,rules=copy(PRESETS[preset])}
    self:RefreshUI()
    return true
end
function AF:BeginCharterRevision()
    local c=self:GetExpeditionCharter()
    if not c or c.state~="active" then return false,"Only an active charter can be revised" end
    c.draft={preset=c.preset,rules=normalizeRules(c.rules,c.preset)}
    self:RefreshUI()
    return true
end
function AF:DiscardCharterRevision()
    local c=self:GetExpeditionCharter()
    if not c then return false end
    if c.state=="active" then c.draft=nil
    elseif c.state=="draft" then c.draft={preset=c.preset,rules=copy(c.rules)} end
    self:RefreshUI()
    return true
end
function AF:SetCharterDraftRule(id,value)
    local c=self:GetExpeditionCharter()
    if not c or not c.draft or type(value)~="boolean" then return false,"No editable ruleset" end
    local found=false
    for _,def in ipairs(self.CHARTER_RULE_DEFS) do if def.id==id then found=true;break end end
    if not found then return false,"Unknown rule" end
    c.draft.rules[id]=value
    if c.draft.preset~="custom" then c.draft.preset="custom" end
    self:RefreshUI()
    return true
end
local function verify(charter, draft, memberCount)
    if not draft then return false,"No draft to publish" end
    if draft.preset=="solo" and memberCount~=1 then
        return false,"Solo requires exactly one enrolled character. Update the Expedition roster in Characters first."
    end
    if memberCount<1 then return false,"Enroll at least one character in Characters first." end
    return true
end
function AF:RecordCharterEvent(kind,key,detail,evidence)
    local c=self:GetExpeditionCharter()
    if not c then return end
    local member=self.db and self.db.characters and self.db.characters[key]
    local e={ id=self:NextID(), timestamp=now(), kind=text(kind,36),
        key=key, character=member and member.name or (key and tostring(key) or "Expedition"),
        detail=text(detail,800), evidence=evidence or "local_record", version=c.version }
    c.events[#c.events+1]=e
    return e
end
function AF:StartCharter()
    local c=self:GetExpeditionCharter()
    if not c or c.state~="draft" then return false,"Charter is not in draft state" end
    local ok,reason=verify(c,c.draft,self:GetCharterMemberCount())
    if not ok then return false,reason end
    c.preset=c.draft.preset
    c.rules=normalizeRules(c.draft.rules,c.preset)
    c.version=1
    c.id=self:NextID()
    c.startedAt=now()
    c.state="active"
    c.versions[1]={number=1,startedAt=c.startedAt,preset=c.preset,rules=copy(c.rules)}
    c.draft=nil
    self:RecordCharterEvent("charter_started",nil,
        "Voluntary challenge started. Previous play and periods when the addon was not running are unobserved.","player_declared")
    local members=self:GetExpeditionMembers()
    for _,member in ipairs(members) do self:BeginCharterMemberPeriod(member.key,"Member at charter activation") end
    if self.CheckExpeditionCompanyMilestone then self:CheckExpeditionCompanyMilestone() end
    local currentKey=self.GetCurrentKey and self:GetCurrentKey()
    if currentKey and self:IsCharterScopedMember(currentKey) then
        if self.ObserveMilestoneLevel then self:ObserveMilestoneLevel(UnitLevel("player"),currentKey) end
        if self.ObserveMilestoneProfessionProgress then self:ObserveMilestoneProfessionProgress(currentKey) end
    end
    self:RefreshUI()
    return true
end
function AF:PublishCharterRevision()
    local c=self:GetExpeditionCharter()
    if not c or c.state~="active" then return false,"Charter is not active" end
    local ok,reason=verify(c,c.draft,self:GetCharterMemberCount())
    if not ok then return false,reason end
    -- No retroactive change to prior versions or earlier audit records.
    c.version=c.version+1
    c.preset=c.draft.preset
    c.rules=normalizeRules(c.draft.rules,c.preset)
    c.versions[#c.versions+1]={number=c.version,startedAt=now(),preset=c.preset,rules=copy(c.rules)}
    c.draft=nil
    self:RecordCharterEvent("rules_revised",nil,
        "Ruleset changed to "..(self.CHARTER_PRESET_NAMES[c.preset] or "Custom")..". Earlier versions retained.","player_declared")
    self:RefreshUI()
    return true
end
function AF:BeginCharterMemberPeriod(key,reason)
    local c=self:GetExpeditionCharter()
    if not c or c.state~="active" or not self:IsExpeditionMember(key) then return false end
    c.periods[key]=type(c.periods[key])=="table" and c.periods[key] or {}
    local records=c.periods[key]
    if #records>0 and not records[#records].endedAt then return false end
    local p={startedAt=now(),startedVersion=c.version,endedAt=nil}
    records[#records+1]=p
    self:RecordCharterEvent("member_period_started",key,
        (reason or "Enrolled")..". Prior activity was not observed.","local_record")
    local currentKey=self.GetCurrentKey and self:GetCurrentKey()
    if key and currentKey and key==currentKey then
        if self.ObserveMilestoneLevel then self:ObserveMilestoneLevel(UnitLevel("player"),key) end
        if self.ObserveMilestoneProfessionProgress then self:ObserveMilestoneProfessionProgress(key) end
    end
    return true
end
function AF:EndCharterMemberPeriod(key,reason)
    local c=self:GetExpeditionCharter()
    if not c or c.state~="active" then return false end
    local records=c.periods[key]
    if type(records)~="table" or #records==0 or records[#records].endedAt then return false end
    records[#records].endedAt=now()
    records[#records].endedVersion=c.version
    self:RecordCharterEvent("member_period_ended",key,reason or "Enrollment ended.","local_record")
    return true
end
function AF:OnExpeditionMembershipChanged(key,joined)
    local c=self:GetExpeditionCharter()
    if not c or c.state~="active" then return end
    if joined then
        self:BeginCharterMemberPeriod(key,"Character joined the Expedition")
        if self.CheckExpeditionCompanyMilestone then self:CheckExpeditionCompanyMilestone() end
    else self:EndCharterMemberPeriod(key,"Character departed the Expedition") end
end
function AF:CanJoinExpeditionUnderCharter(key)
    local c=self:GetExpeditionCharter()
    if c and c.state=="active" and c.preset=="solo" and not self:IsExpeditionMember(key)
        and self:GetCharterMemberCount()>=1 then
        return false,"The Solo charter permits one enrolled adventurer. End this charter or revise the rules first."
    end
    return true
end
function AF:EndCharter()
    local c=self:GetExpeditionCharter()
    if not c or c.state~="active" then return false,"No active charter" end
    for key,records in pairs(c.periods) do
        if type(records)=="table" and #records>0 and not records[#records].endedAt then
            self:EndCharterMemberPeriod(key,"Charter ended")
        end
    end
    self:RecordCharterEvent("charter_ended",nil,"Voluntary challenge ended by the player.","player_declared")
    c.endedAt=now()
    c.state="ended"
    c.draft=nil
    self:RefreshUI()
    return true
end
function AF:PrepareNewCharter()
    local exp=self:GetExpedition()
    if not exp or not exp.charter or exp.charter.state~="ended" then return false,"End the current charter first." end
    exp.charterArchive[#exp.charterArchive+1]=exp.charter
    exp.charter=newCharter()
    self:RefreshUI()
    return true
end
function AF:GetCharterRuleValue(id)
    local c=self:GetExpeditionCharter()
    return c and c.state=="active" and c.rules[id] or nil
end
function AF:IsCharterScopedMember(key)
    local c=self:GetExpeditionCharter()
    if not c or c.state~="active" or not self:IsExpeditionMember(key) then return false end
    local periods=c.periods[key]
    return type(periods)=="table" and #periods>0 and not periods[#periods].endedAt
end
function AF:RecordCharterReview(kind,detail,level,key)
    local c=self:GetExpeditionCharter()
    if not c or c.state~="active" then return false,"Activate the charter before recording challenge activity." end
    local valid={note=true,trade=true,mail=true,auction=true,assistance=true,storage=true,group=true,vendor=true,other=true}
    if not valid[kind] or (level~="declared" and level~="review" and level~="conflict") then
        return false,"Invalid review category"
    end
    detail=text(detail,650)
    if detail:match("^%s*$") then return false,"Enter a short explanation first." end
    local review={id=self:NextID(), timestamp=now(), kind=kind, detail=detail,
        level=level, status=level=="review" and "open" or "recorded", key=key,
        version=c.version, evidence="player_declared"}
    c.reviews[#c.reviews+1]=review
    local event=self:RecordCharterEvent("review_"..level,key,kind..": "..detail,"player_declared")
    if event then review.eventId=event.id;event.reviewId=review.id end
    self:RefreshUI()
    return true
end
function AF:ResolveCharterReview(id,note)
    local c=self:GetExpeditionCharter()
    if not c then return false,"No charter" end
    for _,entry in ipairs(c.reviews) do
        if entry.id==id and entry.level=="review" and entry.status=="open" then
            entry.status="reviewed"
            entry.reviewedAt=now()
            entry.resolution=text(note,400)
            local event=self:RecordCharterEvent("review_closed",entry.key,
                "Player reviewed entry #"..tostring(id)..". "..entry.resolution,"player_declared")
            if event then event.reviewId=entry.id end
            self:RefreshUI()
            return true
        end
    end
    return false,"No open review with that ID"
end
function AF:GetCharterReviewCounts()
    local c=self:GetExpeditionCharter()
    local open, conflicts=0,0
    if c then for _,entry in ipairs(c.reviews) do
        if entry.status=="open" then open=open+1 end
        if entry.level=="conflict" then conflicts=conflicts+1 end
    end end
    return open,conflicts
end
