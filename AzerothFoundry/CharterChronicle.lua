-- v0.6.2.2: presentation-only Expedition Chronicle helpers.
-- Never mutate records or reinterpret unobserved behavior as rule compliance.
local _, AF = ...
local ICON = "Interface\\Icons\\"
local ENTRIES = {
    charter_started={"Expedition Established","charter","charter","INV_Misc_Book_09","The voluntary Expedition charter was activated. Earlier activity remains outside the observation period."},
    charter_ended={"Expedition Concluded","charter","charter","INV_Misc_Book_09","The voluntary charter was ended. Its historical records remain available."},
    rules_revised={"Charter Rules Revised","charter","charter","INV_Scroll_03","A new charter version was published. Earlier versions remain unchanged."},
    member_period_started={"Adventurer Enrolled","charter","charter","INV_Misc_GroupLooking","An observation period began for this enrolled adventurer. Earlier activity is not covered."},
    member_period_ended={"Adventurer Departed","charter","charter","INV_Misc_GroupLooking","This adventurer's current charter observation period ended."},
    acknowledged_auction_buy_notice={"Auction Warning Acknowledged","auction","observed","INV_Misc_Note_01","The charter reminder was acknowledged to view the Buy page. This is not a purchase."},
    observed_trade_window={"Trade Window Opened","trade","observed","INV_Misc_Coin_02","A trade interface opened. Neither the other player nor a completed exchange was verified."},
    observed_trade_accepted={"Trade Acceptance Observed","trade","review","INV_Misc_Coin_02","Both players' accept states were observed. A successful exchange or outsider relationship was not established."},
    observed_trade_closed={"Trade Window Closed","trade","observed","INV_Misc_Coin_02","The trade window closed. This alone cannot confirm a transfer."},
    observed_auction_browsing={"Auction House Visited","auction","observed","INV_Misc_Note_01","The Auction House was opened. Browsing alone is not a purchase, listing, or bid."},
    observed_auction_purchase={"Auction Purchase Event","auction","review","INV_Misc_Coin_01","The client reported an auction purchase-success event. Source and delivery may still need review."},
    observed_commodity_purchase={"Commodity Purchase Event","auction","review","INV_Misc_Coin_01","The client reported a commodity purchase-success event. Item origin still requires review."},
    observed_auction_listing={"Auction Listing Created","auction","review","INV_Misc_Note_01","The client reported an auction listing. This does not establish a sale."},
    observed_auction_bid={"Auction Bid Placed","auction","review","INV_Misc_Coin_01","The client reported a bid. This does not establish item receipt."},
    observed_mailbox_open={"Mailbox Visited","mail","observed","INV_Letter_15","A mailbox was opened. No attachment receipt or mail delivery is established."},
    observed_mail_sent={"Mail Sent","mail","review","INV_Letter_15","A successful mail-send event was reported. Recipient membership and contents are not verified."},
    observed_guild_bank_open={"Guild Bank Visited","storage","observed","INV_Misc_Bag_10","The guild bank was opened. No deposit or withdrawal is established."},
    observed_bank_open={"Bank Visited","storage","observed","INV_Misc_Bag_10","A bank interface was opened. Shared-resource use and provenance are not established."},
    observed_group_roster={"Group Roster Changed","group","observed","INV_Misc_GroupLooking","The party or raid roster changed. This does not prove outside assistance or a carry."},
    observed_merchant_open={"Merchant Visited","vendor","observed","INV_Misc_Coin_02","An NPC merchant was opened. No purchase or sale was established."},
    review_declared={"Activity Note Added","review","declared","INV_Scroll_03","A player-authored activity declaration was added to the local review ledger."},
    review_review={"Activity Flagged for Review","review","review","INV_Misc_Note_01","The player declared an activity needing review. This is not an independently confirmed violation."},
    review_conflict={"Conflict Self-Reported","review","declared","INV_Misc_Note_01","The player declared a conflict with their charter. This is a self-report, not independent verification."},
    milestone_first_harvest={"First Harvest","milestone","declared","INV_Misc_Herb_01","Player declared a gathering accomplishment. Provenance is not independently verified."},
    milestone_forged_by_hands={"Forged by Your Own Hands","milestone","observed","Trade_BlackSmithing","The client emitted a successful craft-result event for an enrolled adventurer. Material provenance is unknown."},
    milestone_cartographers_journey={"Cartographer's Journey","milestone","observed","INV_Misc_Map_01","Foundry recorded the first new Atlas zone entry for this character during the active charter. Not proof of 100% exploration."},
    milestone_company_of_adventurers={"A Company of Adventurers","milestone","charter","INV_Misc_GroupLooking","Three or more characters were enrolled in the active Expedition roster."},
    review_closed={"Activity Reviewed","review","declared","INV_Scroll_03","The player marked a review item as reviewed. The original record is retained."},
}
local CATEGORY_LABELS={charter="Charter",trade="Trading",auction="Auction House",mail="Mail",storage="Storage",group="Cooperation",vendor="NPC Economy",review="Rule Review",milestone="Milestones",other="Other"}
AF.CHARTER_CHRONICLE_CATEGORIES=CATEGORY_LABELS
local EVIDENCE_LABELS={client_event="Client Event",player_declared="Player Declared",local_record="Local Record"}
local function readable(s)
    if type(s)~="string" then return "Unidentified Activity" end
    s=s:gsub("_"," "):gsub("(%l)(%u)","%1 %2")
    return (s:gsub("(%a)([%w']*)",function(a,b)return a:upper()..b end))
end
function AF:CharterEventInfo(event,source)
    event=type(event)=="table" and event or {}
    local spec=ENTRIES[event.kind] or {}
    local dynamicIcon=nil
    if not spec[1] and type(event.kind)=="string" and event.kind:find("^milestone_") and self.GetExpeditionMilestoneDef then
        local def=self:GetExpeditionMilestoneDef(event.kind:gsub("^milestone_",""))
        if def then
            spec={def.title,"milestone",event.evidence=="player_declared" and "declared" or event.evidence=="client_event" and "observed" or "charter",nil,
                def.description or "A local Expedition milestone record."}
            dynamicIcon=def.icon
        end
    end
    local title=spec[1] or readable(event.kind)
    local category=spec[2] or "other"
    local status=spec[3] or (event.evidence=="client_event" and "observed" or event.evidence=="player_declared" and "declared" or "charter")
    local summary=spec[5] or "This historical entry is retained as recorded. See Technical Details for its original description."
    local version,ruleNames,ruleLines=nil,{},{}
    if source and type(source.versions)=="table" then
        for _,v in ipairs(source.versions) do
            if tonumber(v.number)==tonumber(event.version) then version=v;break end
        end
    end
    local ids=type(event.ruleIds)=="table" and event.ruleIds or (event.ruleId and {event.ruleId} or {})
    local seen={}
    for _,id in ipairs(ids) do
        if not seen[id] then
            seen[id]=true
            local name=id
            for _,def in ipairs(self.CHARTER_RULE_DEFS or {}) do if def.id==id then name=def.label;break end end
            ruleNames[#ruleNames+1]=name
            local state=version and type(version.rules)=="table" and version.rules[id]
            local result=not version and "Historical version unavailable" or (state==nil and "Not in this version" or (state and "Allowed" or "Restricted"))
            ruleLines[#ruleLines+1]=name.." — "..result
        end
    end
    local review
    if event.reviewId and source and type(source.reviews)=="table" then
        for _,item in ipairs(source.reviews) do if item.id==event.reviewId then review=item;break end end
    end
    if event.kind and event.kind:find("^observed_") and status=="review" and not review then status="observed" end
    if review and review.level=="review" and event.kind~="review_closed" then
        status=review.status=="reviewed" and "reviewed" or "review"
    end
    local iconPath=dynamicIcon or ((spec[4] and spec[4]:find("\\") and spec[4]) or (ICON..(spec[4] or "INV_Misc_Note_01")))
    return {title=title,category=category,categoryLabel=CATEGORY_LABELS[category] or "Other",
        status=status,summary=summary,icon=iconPath,
        evidence=EVIDENCE_LABELS[event.evidence] or readable(event.evidence or "local_record"),
        ruleLines=ruleLines,ruleNames=ruleNames,version=version,review=review,
        reviewId=event.reviewId,detail=event.detail or ""}
end
-- Read-only filtering: never remove stored events or change their order in SavedVariables.
function AF:FilterCharterChronicle(events,source,filters)
    filters=filters or {}
    local result={}
    local search=type(filters.search)=="string" and filters.search:lower() or ""
    local now=type(time)=="function" and time() or 0
    for i=#events,1,-1 do
        local e=events[i]
        if type(e)=="table" then
            local info=self:CharterEventInfo(e,source)
            local categoryOk=not filters.category or filters.category=="all" or info.category==filters.category
            local characterOk=not filters.character or filters.character=="all" or (e.character or "Expedition")==filters.character
            local statusOk=not filters.status or filters.status=="all" or info.status==filters.status
            local dateOk=true
            local t=tonumber(e.timestamp)
            if filters.days and filters.days>0 then dateOk=t and t>0 and t>=now-filters.days*86400 and t<=now+120 end
            if filters.days==0 then
                dateOk=t and t>0 and type(date)=="function" and date("%Y-%m-%d",t)==date("%Y-%m-%d",now)
            end
            local recordedDate=""
            if t and t>0 and type(date)=="function" then
                recordedDate=date("%Y-%m-%d %b %d %Y",t)
            end
            local searchable=table.concat({info.title,info.categoryLabel,e.kind or "",e.character or "Expedition",
                e.detail or "",info.evidence,recordedDate,unpack(info.ruleNames)}," "):lower()
            if categoryOk and characterOk and statusOk and dateOk and (search=="" or searchable:find(search,1,true)) then
                result[#result+1]={event=e,info=info}
            end
        end
    end
    return result
end
