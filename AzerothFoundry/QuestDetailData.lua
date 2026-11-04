-- v0.4.1.5.2: historical reference fallbacks and quest NPC identification; no save migration.
-- LibQuestDB is optional; active quest APIs are authoritative for live progress.
local _, AF = ...
local function Call(fn,...)
    if type(fn)~='function' then return nil end
    local ok,a,b,c,d,e,f,g=pcall(fn,...)
    if ok then return a,b,c,d,e,f,g end
end
local function Number(v)
    local n=tonumber(v); if n and n>0 and n==math.floor(n) then return n end
end
local function QuestLib()
    if type(LibStub)~='function' then return nil end
    local ok,lib=pcall(LibStub,'LibQuestDB-1.0',true)
    if ok and type(lib)=='table' then return lib end
end
local function LibraryCall(lib,method,...)
    if lib and type(lib[method])=='function' then return Call(lib[method],lib,...) end
end
local function FriendlyMarkup(text)
    if type(text)~='string' then return nil end
    local unit='player'
    local name=type(UnitName)=='function' and UnitName(unit) or 'Adventurer'
    local class=type(UnitClass)=='function' and select(1,UnitClass(unit)) or 'adventurer'
    local race=type(UnitRace)=='function' and select(1,UnitRace(unit)) or 'traveler'
    text=text:gsub('%$[Nn]',function() return name or 'Adventurer' end)
        :gsub('%$[Cc]',function() return class or 'adventurer' end)
        :gsub('%$[Rr]',function() return race or 'traveler' end)
        :gsub('%$[Bb]','\n')
    text=text:gsub('%$[Gg]([^:;]-):([^;]-);',function(male,female)
        return type(UnitSex)=='function' and UnitSex(unit)==3 and female or male
    end)
    return text
end
local function RewardEntry(id,count,kind,name,icon,quality)
    if AF.ResolveQuestRewardItem then
        return AF:ResolveQuestRewardItem(id,count,kind,name,icon,quality)
    end
    id=Number(id)
    if not id and not icon then return nil end
    return {id=id,count=tonumber(count) or 1,kind=kind,
        name=name or (id and ('Item #'..id) or 'Quest reward'),
        icon=icon or 'Interface\\Icons\\INV_Misc_QuestionMark',quality=quality}
end
local function NormalizeCollection(dest,source,kind)
    if type(source)~='table' then return end
    for _,entry in ipairs(source) do
        if type(entry)=='table' then
            local item=RewardEntry(entry.id or entry.itemID,entry.count or entry.quantity,kind,entry.name,entry.icon,entry.quality)
            if item then dest[#dest+1]=item end
        end
    end
end
local function PushNPC(lib,list,seen,id,role)
    id=Number(id)
    if not id or seen[id] or #list>=12 then return end
    local n=LibraryCall(lib,'GetNPC',id)
    if type(n)~='table' then return end
    seen[id]=true
    list[#list+1]={id=id,name=type(n.name)=='string' and n.name or ('NPC #'..id),role=role,
        minLevel=n.minLevel,maxLevel=n.maxLevel}
end
local function NPCValue(lib,list,seen,value,role,depth)
    depth=depth or 0
    if depth>3 then return end
    if type(value)=='number' then PushNPC(lib,list,seen,value,role)
    elseif type(value)=='table' then
        if role=='Objective' and Number(value[1]) and type(value[2])=='number' then
            -- Objective tuple {creatureID, count, ...}; count is not an NPC.
            PushNPC(lib,list,seen,value[1],role)
            return
        end
        if Number(value.id or value.npcID or value.creatureID) then
            PushNPC(lib,list,seen,value.id or value.npcID or value.creatureID,role)
        else
            for _,entry in ipairs(value) do NPCValue(lib,list,seen,entry,role,depth+1) end
            for _,key in ipairs({'npc','npcs','creatures','monsters','NPC','creature'}) do
                if value[key] then NPCValue(lib,list,seen,value[key],role,depth+1) end
            end
        end
    end
end
function AF:GetRichQuestDetails(questID,isActive)
    questID=Number(questID)
    if not questID then return nil end
    local ref=self.GetQuestReference and self:GetQuestReference(questID)
    local lib=QuestLib()
    local text=ref and ref.text or nil
    local quest=ref and ref.quest or nil
    local rewards=ref and ref.rewards or nil
    local result={id=questID,description=text and FriendlyMarkup(text.details),
        objectivesText=text and FriendlyMarkup(text.objectives),
        turnInText=text and FriendlyMarkup(text.offerReward),
        progressText=text and FriendlyMarkup(text.requestItems),
        endText=text and FriendlyMarkup(text.endText),
        objectives={},items={},npcs={},rewardSource=nil}
    -- Offline databases currently cover many Forever quests with only an
    -- objective. Fill gaps from quest text actually observed in game.
    local captured=self.GetRecordedQuestDialogue and self:GetRecordedQuestDialogue(questID)
    local capturedFields={}
    if type(captured)=='table' then
        for _,pair in ipairs({{'description','story'}, {'objectivesText','objectives'},
                {'progressText','progress'}, {'turnInText','turnIn'}}) do
            local displayField,sourceField=pair[1],pair[2]
            if (type(result[displayField])~='string' or not result[displayField]:find('%S'))
                and type(captured[sourceField])=='string' and captured[sourceField]:find('%S') then
                result[displayField]=FriendlyMarkup(captured[sourceField])
                capturedFields[displayField]=true
            end
        end
    end
    result.capturedFields=capturedFields
    result.historical=not isActive
    -- Forever quests and recovered historical IDs can have partial static
    -- coverage. Use available reference copy and never invent a past reward.
    if not result.description and type(quest)=='table' then
        result.description=FriendlyMarkup(quest.description or quest.details)
    end
    if not result.objectivesText and type(quest)=='table' then
        result.objectivesText=FriendlyMarkup(quest.objectivesText or quest.objectiveText)
    end
    if not result.objectivesText and type(text)=='table' and type(text.objectiveTexts)=='table' then
        local lines={}
        for _,line in ipairs(text.objectiveTexts) do
            if type(line)=='string' and line~='' then lines[#lines+1]=FriendlyMarkup(line) end
        end
        if #lines>0 then result.objectivesText=table.concat(lines,'\n') end
    end
    if isActive and type(GetQuestLogQuestText)=='function' and
        C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID)=='function' and
        (not result.description or not result.objectivesText) then
        local index=Call(C_QuestLog.GetLogIndexForQuestID,questID)
        if type(index)=='number' and index>0 then
            local desc,obj=Call(GetQuestLogQuestText,index)
            if not result.description then result.description=FriendlyMarkup(desc) end
            if not result.objectivesText then result.objectivesText=FriendlyMarkup(obj) end
        end
    end
    -- A completed quest is not in the live quest log; don't show misleading 0/0.
    if isActive and C_QuestLog then
        local rows=Call(C_QuestLog.GetQuestObjectives,questID)
        if type(rows)=='table' then
            for _,v in ipairs(rows) do
                if type(v)=='table' then
                    result.objectives[#result.objectives+1]={text=v.text,kind=v.type,
                        done=v.finished==true,have=tonumber(v.numFulfilled),need=tonumber(v.numRequired)}
                end
            end
        end
    end
    if isActive then
        local n=Call(GetNumQuestLogRewards,questID)
        if type(n)=='number' then
            for i=1,math.min(n,16) do
                local name,icon,count,quality,_,id=Call(GetQuestLogRewardInfo,i,questID)
                local item=RewardEntry(id,count,'Guaranteed',name,icon,quality)
                if item then result.items[#result.items+1]=item end
            end
        end
        local choices=Call(GetNumQuestLogChoices,questID)
        if type(choices)=='number' then
            for i=1,math.min(choices,16) do
                local name,icon,count,quality,_,id=Call(GetQuestLogChoiceInfo,i,questID)
                local item=RewardEntry(id,count,'Choose one',name,icon,quality)
                if item then result.items[#result.items+1]=item end
            end
        end
        if #result.items>0 then result.rewardSource='Client' end
    end
    if #result.items==0 and type(rewards)=='table' then
        NormalizeCollection(result.items,rewards.items,'Guaranteed')
        NormalizeCollection(result.items,rewards.choices,'Choose one')
        if #result.items>0 then result.rewardSource='LibQuestDB (possible rewards)' end
    end
    result.missingItemCount=0
    for _,item in ipairs(result.items) do
        if item.missingName or item.missingIcon then
            result.missingItemCount=result.missingItemCount+1
        end
    end
    local xp=isActive and Call(GetQuestLogRewardXP,questID) or nil
    if type(xp)=='number' and xp>0 then result.xp=xp
    elseif type(rewards)=='table' then
        local level=type(UnitLevel)=='function' and UnitLevel('player') or nil
        local dbxp=level and LibraryCall(lib,'GetQuestXP',questID,level)
        if type(dbxp)=='number' and dbxp>0 and not (type(level)=='number' and level>=60 and not isActive) then
            result.xp=dbxp;result.xpEstimate=true
        end
    end
    local money=isActive and Call(GetQuestLogRewardMoney,questID) or nil
    if type(money)=='number' and money~=0 then result.money=money
    elseif type(rewards)=='table' and type(rewards.money)=='number' and rewards.money~=0 then
        result.money=rewards.money;result.moneyEstimate=true
    end
    if type(rewards)=='table' and type(rewards.rep)=='table' then
        result.reputation={}
        for _,rep in ipairs(rewards.rep) do
            if type(rep)=='table' then
                local v=tonumber(rep.value)
                if v and rep.faction then
                    local factionName
                    local factionID=Number(rep.faction)
                    if factionID then
                        local data=C_Reputation and Call(C_Reputation.GetFactionDataByID,factionID)
                        factionName=type(data)=='table' and data.name or nil
                        if not factionName then factionName=Call(GetFactionInfoByID,factionID) end
                    end
                    result.reputation[#result.reputation+1]={faction=rep.faction,
                        name=factionName,value=v}
                end
            end
        end
    end
    if type(quest)=='table' and lib then
        local seen={}
        local function CreatureSide(side)
            if type(side)~='table' then return side end
            -- Some quest databases use {[1]=creatures,[2]=gameobjects,[3]=items}.
            -- Never interpret object/item IDs as creatures just because their
            -- numeric ID also happens to exist in GetNPC.
            return side.npc or side.npcs or side.creatures or side.NPC
                or (type(side[1])=='table' and side[1]) or side
        end
        NPCValue(lib,result.npcs,seen,CreatureSide(quest.startedBy),'Quest giver')
        NPCValue(lib,result.npcs,seen,CreatureSide(quest.finishedBy),'Turn-in')
        -- Only explicit creature objectives are safe to interpret as NPC IDs.
        if type(quest.objectives)=='table' then
            NPCValue(lib,result.npcs,seen,quest.objectives.creatures or quest.objectives.monsters or quest.objectives.npcs or quest.objectives[1], 'Objective')
        end
    end
    result.hasHistoricalDetails=not not (
        (result.description and result.description~='') or
        (result.objectivesText and result.objectivesText~='') or
        (result.turnInText and result.turnInText~='') or
        (result.endText and result.endText~='') or
        #result.items>0 or #result.npcs>0 or result.money or result.xp)
    return result
end
