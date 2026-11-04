-- Azeroth Foundry 0.5.11.1 / Account tracker choices for the Characters page.
-- View-only statistics from existing locally observed snapshots. No server
-- queries for offline characters, no new tracking engines, no guessed totals.
local _, AF = ...
local UI = AF.UI
local floor, max = math.floor, math.max

local DEFAULTS = {"current", "characters", "expedition", "gold", "played"}
local ORDER = {
    "current", "characters", "expedition", "independent", "gold", "played",
    "highestLevel", "averageLevel", "richest", "mostPlayed", "lastSeen",
    "main", "classes", "activeGoals", "trackedGoals", "completedGoals",
}
local DEFINITIONS = {
    -- menu label, tooltip, compact card label
    current        = {"Current Adventurer", "Character you're playing now", "Current Character"},
    characters     = {"Registered", "Characters Foundry has encountered", "Registered"},
    expedition     = {"Expedition Members", "Registered Expedition members", "Expedition"},
    independent    = {"Independent", "Registered adventurers outside the Expedition", "Independent"},
    gold           = {"Recorded Gold", "Combined observed character gold, not bank gold", "Recorded Gold"},
    played         = {"Recorded Playtime", "Server-reported playtime of scanned characters", "Recorded Time"},
    highestLevel   = {"Highest Level", "Highest recorded character level", "Highest Level"},
    averageLevel   = {"Average Level", "Average recorded level across registered characters", "Average Level"},
    richest        = {"Wealthiest Adventurer", "Largest recorded character gold balance", "Most Gold"},
    mostPlayed     = {"Most Played", "Character with greatest recorded /played", "Most Played"},
    lastSeen       = {"Last Active", "Most recently scanned character", "Last Active"},
    main           = {"Main Adventurer", "Character designated as Expedition main", "Main Adventurer"},
    classes        = {"Classes Represented", "Distinct classes among registered characters", "Class Variety"},
    activeGoals    = {"Active Goals", "Recorded goals not marked completed", "Active Goals"},
    trackedGoals   = {"Tracked Goals", "Goals pinned to Foundry's tracker", "Tracked Goals"},
    completedGoals = {"Completed Goals", "Goals explicitly marked done", "Completed Goals"},
}

local function money(copper)
    if type(copper)~="number" then return "Not recorded" end
    local gold=floor(copper/10000)
    if gold>=1000000 then return string.format("%.1fm g",gold/1000000) end
    if gold>=10000 then return string.format("%.1fk g",gold/1000) end
    return tostring(gold).."g"
end
local function played(sec)
    if type(sec)~="number" then return "Not recorded" end
    local d=floor(sec/86400)
    local h=floor((sec%86400)/3600)
    if d>0 then return string.format("%dd %dh",d,h) end
    if h>0 then return string.format("%dh %dm",h,floor((sec%3600)/60)) end
    return string.format("%dm",floor(sec/60))
end
local function characterName(c) return (c and c.name) or "Unknown" end
local function recentDate(stamp)
    if type(stamp)~="number" or stamp<=0 then return "Not recorded" end
    if type(date)=="function" then return date("%b %d, %Y",stamp) end
    return "Recorded"
end

function UI:GetAccountTrackerChoices()
    local list={}
    for _,id in ipairs(ORDER) do
        list[#list+1]={id=id,label=DEFINITIONS[id][1],description=DEFINITIONS[id][2]}
    end
    return list
end

function UI:EnsureAccountTrackerSettings()
    local s=AF.db and AF.db.settings
    if not s then return DEFAULTS,5 end
    local count=(s.charactersTrackerCount==4) and 4 or 5
    s.charactersTrackerCount=count
    if type(s.charactersTrackers)~="table" then s.charactersTrackers={} end
    local used={}
    for i=1,5 do
        local id=s.charactersTrackers[i]
        if not DEFINITIONS[id] or used[id] then
            id=DEFAULTS[i]
            if used[id] then
                for _,choice in ipairs(ORDER) do
                    if not used[choice] then id=choice;break end
                end
            end
        end
        s.charactersTrackers[i]=id
        used[id]=true
    end
    return s.charactersTrackers,count
end

function UI:SelectAccountTracker(slot,id)
    local prefs=self:EnsureAccountTrackerSettings()
    if type(slot)~="number" or slot<1 or slot>5 or not DEFINITIONS[id] then return false end
    -- Keep five distinct quick-look values; choosing another occupied slot
    -- swaps the two values instead of silently duplicating a tracker.
    for i=1,5 do
        if i~=slot and prefs[i]==id then
            prefs[i],prefs[slot]=prefs[slot],prefs[i]
            return true
        end
    end
    prefs[slot]=id
    return true
end

function UI:ReadAccountTracker(id)
    local definition=DEFINITIONS[id]
    if not definition then return "Unavailable","Unknown tracker","" end
    local db=AF.db or {}
    local chars=(type(AF.GetCharacters)=="function" and AF:GetCharacters()) or {}
    local total, members, knownGold, knownPlayed, sumGold, sumPlayed= #chars,0,0,0,0,0
    local levels,levelCount,peakLevel,peakChar=0,0,0,nil
    local richest,veteran,latest=nil,nil,nil
    local classCount,classes=0,{}
    for _,c in ipairs(chars) do
        if AF.IsExpeditionMember and AF:IsExpeditionMember(c.key) then members=members+1 end
        local copper=c.afMoneyCopper
        if type(copper)=="number" and copper>=0 then
            knownGold=knownGold+1;sumGold=sumGold+copper
            if not richest or copper>richest.afMoneyCopper then richest=c end
        end
        local seconds=c.afPlayedSeconds
        if type(seconds)=="number" and seconds>=0 then
            knownPlayed=knownPlayed+1;sumPlayed=sumPlayed+seconds
            if not veteran or seconds>veteran.afPlayedSeconds then veteran=c end
        end
        if type(c.level)=="number" and c.level>0 then
            levels=levels+c.level;levelCount=levelCount+1
            if c.level>peakLevel then peakLevel=c.level;peakChar=c end
        end
        if type(c.lastSeen)=="number" and c.lastSeen>0 then
            if not latest or c.lastSeen>latest.lastSeen then latest=c end
        end
        if type(c.class)=="string" and c.class~="" and not classes[c.class] then
            classes[c.class]=true;classCount=classCount+1
        end
    end
    local value,detail
    if id=="current" then
        local c=AF.CurrentCharacter and AF:CurrentCharacter()
        value=characterName(c)
        detail=c and ("Level "..tostring(c.level or "?").." "..(c.class or "").." · "..(AF.IsExpeditionMember and AF:IsExpeditionMember(c.key) and "Expedition" or "Independent")) or "Log in to register"
    elseif id=="characters" then
        value=tostring(total)
        detail="Registered adventurers"
    elseif id=="expedition" then
        value=tostring(members)
        detail=tostring(total-members).." independent"
    elseif id=="independent" then
        value=tostring(total-members)
        detail=tostring(members).." in Expedition"
    elseif id=="gold" then
        value=knownGold>0 and money(sumGold) or "Not recorded"
        detail=tostring(knownGold).." / "..total.." balances scanned"
    elseif id=="played" then
        value=knownPlayed>0 and played(sumPlayed) or "Not recorded"
        detail=tostring(knownPlayed).." / "..total.." playtimes recorded"
    elseif id=="highestLevel" then
        value=peakChar and ("Lv "..peakLevel) or "Not recorded"
        detail=peakChar and characterName(peakChar) or "No level snapshots"
    elseif id=="averageLevel" then
        value=levelCount>0 and tostring(floor(levels/levelCount+0.5)) or "Not recorded"
        detail=tostring(levelCount).." / "..total.." levels recorded"
    elseif id=="richest" then
        value=richest and money(richest.afMoneyCopper) or "Not recorded"
        detail=(richest and characterName(richest).." · " or "")..knownGold.." / "..total.." scanned"
    elseif id=="mostPlayed" then
        value=veteran and played(veteran.afPlayedSeconds) or "Not recorded"
        detail=(veteran and characterName(veteran).." · " or "")..knownPlayed.." / "..total.." recorded"
    elseif id=="lastSeen" then
        value=latest and characterName(latest) or "Not recorded"
        detail=latest and recentDate(latest.lastSeen) or "No saved activity"
    elseif id=="main" then
        local c=db.characters and db.characters[db.mainKey]
        value=c and characterName(c) or "Not assigned"
        detail=c and ("Lv "..tostring(c.level or "?").." "..(c.class or "")) or "Choose a main in the dossier"
    elseif id=="classes" then
        value=tostring(classCount)
        detail=tostring(total).." registered characters"
    else
        local active,complete=0,0
        for _,project in ipairs(db.projects or {}) do
            if project.done==true then complete=complete+1 else active=active+1 end
        end
        local tracked=0
        local trackedIds=db.settings and db.settings.guided and db.settings.guided.tracked or {}
        if type(trackedIds)=="table" then
            for _,pid in ipairs(trackedIds) do
                local exists=false
                for _,p in ipairs(db.projects or {}) do if p.id==pid then exists=true;break end end
                if exists then tracked=tracked+1 end
            end
        end
        if id=="activeGoals" then value=tostring(active);detail="Unfinished Foundry goals"
        elseif id=="trackedGoals" then value=tostring(tracked);detail="Pinned in goal tracker"
        elseif id=="completedGoals" then value=tostring(complete);detail="Marked completed"
        end
    end
    return value or "Not recorded",detail or "",definition[3] or definition[1]
end
