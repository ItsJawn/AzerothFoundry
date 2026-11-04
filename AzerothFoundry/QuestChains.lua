-- v0.4.1.4.1: UI-only chain / same-title grouping for the Quest Journal.
-- Quest IDs and completion records are never merged in SavedVariables.
local _, AF = ...

local function ID(value)
    value=tonumber(value)
    if value and value>0 and value==math.floor(value) then return value end
end

local function SortQuest(a,b)
    local an=(a.title or ''):lower()
    local bn=(b.title or ''):lower()
    if an~=bn then return an<bn end
    return (tonumber(a.id) or 0)<(tonumber(b.id) or 0)
end

local function QuestLibrary()
    if not LibStub then return end
    local ok,lib=pcall(LibStub,'LibQuestDB-1.0',true)
    if ok and type(lib)=='table' then return lib end
end

-- Only explicit step-to-step links count as a true chain. A common optional
-- prerequisite does not automatically make every related quest one giant chain.
local function LinkIDs(data)
    local links={}
    if type(data)~='table' then return links end
    local function Append(v)
        local n=ID(v)
        if n then links[#links+1]=n end
    end
    for _,key in ipairs({'nextQuestInChain','previousQuestInChain','prevQuestInChain',
        'parentQuest','nextQuest','previousQuest','next','prev','previous'}) do
        Append(data[key])
    end
    -- Some library rows encode a sole direct predecessor as a one-item list.
    for _,key in ipairs({'preQuestSingle','preQuestGroup'}) do
        local v=data[key]
        if type(v)=='table' and #v==1 then Append(v[1]) end
    end
    return links
end

local function GatherLinks(lib,id)
    local found,successors,predecessors={},{},{}
    if not lib then return found,successors,predecessors end
    local function Collect(data)
        for _,s in ipairs(LinkIDs(data)) do found[s]=true end
        for _,key in ipairs({'nextQuestInChain','nextQuest','next'}) do
            local n=ID(data[key]); if n then successors[n]=true end
        end
        for _,key in ipairs({'previousQuestInChain','prevQuestInChain','previousQuest',
            'parentQuest','previous','prev'}) do
            local n=ID(data[key]); if n then predecessors[n]=true end
        end
        for _,key in ipairs({'preQuestSingle','preQuestGroup'}) do
            local v=data[key]
            if type(v)=='table' and #v==1 then
                local n=ID(v[1]); if n then predecessors[n]=true end
            end
        end
    end
    local function Read(method)
        if type(lib[method])=='function' then
            local ok,result=pcall(lib[method],lib,id)
            if ok and type(result)=='table' then
                Collect(result)
                for _,sub in ipairs({'chain','prerequisites'}) do
                    if type(result[sub])=='table' then Collect(result[sub]) end
                end
            end
        end
    end
    Read('GetChain')
    Read('GetQuest')
    return found,successors,predecessors
end

function AF:BuildQuestJournalGroups(questEntries,expanded)
    expanded=expanded or {}
    local byID,parent,nextSteps={}, {}, {}
    for _,entry in ipairs(questEntries or {}) do
        local id=ID(entry.id)
        if id then byID[id]=entry;parent[id]=id;nextSteps[id]={} end
    end
    local function Root(id)
        if parent[id]~=id then parent[id]=Root(parent[id]) end
        return parent[id]
    end
    local function Connect(a,b)
        if a~=b and parent[b] then
            parent[Root(a)]=Root(b)
        end
    end
    local lib=QuestLibrary()
    if lib then
        for id in pairs(byID) do
            local related,successors,predecessors=GatherLinks(lib,id)
            for neighbor in pairs(related) do Connect(id,neighbor) end
            for neighbor in pairs(successors) do
                if nextSteps[neighbor] then nextSteps[id][neighbor]=true end
            end
            for neighbor in pairs(predecessors) do
                if nextSteps[neighbor] then nextSteps[neighbor][id]=true end
            end
        end
    end
    local connected={}
    for id,entry in pairs(byID) do
        local root=Root(id)
        connected[root]=connected[root] or {}
        connected[root][#connected[root]+1]=entry
    end
    -- Stable, chronological order whenever direct step links are known.
    -- Unrelated branches fall back to alphabetic order.
    local function OrderSteps(members)
        local indegree,memberSet={},{}
        for _,entry in ipairs(members) do
            memberSet[entry.id]=true;indegree[entry.id]=0
        end
        for from,targets in pairs(nextSteps) do
            if memberSet[from] then
                for target in pairs(targets) do
                    if memberSet[target] then indegree[target]=indegree[target]+1 end
                end
            end
        end
        local remaining,ordered={},{}
        for _,entry in ipairs(members) do remaining[entry.id]=entry end
        while next(remaining) do
            local eligible={}
            for id,entry in pairs(remaining) do
                if indegree[id]==0 then eligible[#eligible+1]=entry end
            end
            if #eligible==0 then
                -- Malformed/cyclic source data: display every quest, never loop.
                for _,entry in pairs(remaining) do eligible[#eligible+1]=entry end
            end
            table.sort(eligible,SortQuest)
            local choice=eligible[1]
            ordered[#ordered+1]=choice
            remaining[choice.id]=nil
            for target in pairs(nextSteps[choice.id] or {}) do
                if indegree[target] then indegree[target]=indegree[target]-1 end
            end
        end
        return ordered
    end
    local groups,singles={},{}
    local assigned={}
    for _,members in pairs(connected) do
        if #members>1 then
            members=OrderSteps(members)
            local smallest=members[1].id
            for _,entry in ipairs(members) do
                assigned[entry.id]=true
                if entry.id<smallest then smallest=entry.id end
            end
            groups[#groups+1]={key='chain:'..smallest,kind='chain',members=members}
        end
    end
    -- Repeated Forever quests may have identical names but completely different
    -- quest IDs. Collapse them for readability, but label them as variants, NOT
    -- as database-confirmed chain steps. Never throw away their individual IDs.
    local titles={}
    for _,entry in ipairs(questEntries or {}) do
        if entry.id and not assigned[entry.id] then
            local title=(entry.title or ''):gsub('^%s+',''):gsub('%s+$','')
            local key=title:lower()
            if key~='' and not title:match('^Quest #%d+$') then
                titles[key]=titles[key] or {}
                titles[key][#titles[key]+1]=entry
            else
                singles[#singles+1]=entry
            end
        end
    end
    for key,members in pairs(titles) do
        if #members>1 then
            table.sort(members,SortQuest)
            groups[#groups+1]={key='variants:'..key,kind='variants',members=members}
        else
            singles[#singles+1]=members[1]
        end
    end
    local catalog={}
    for _,group in ipairs(groups) do
        group.title=group.members[1].title
        group.count=#group.members
        catalog[group.key]=group
    end
    local top={}
    for _,entry in ipairs(singles) do top[#top+1]={kind='quest',entry=entry,title=entry.title,id=entry.id} end
    for _,group in ipairs(groups) do top[#top+1]={kind='group',group=group,title=group.title,key=group.key} end
    table.sort(top,function(a,b)
        local aTitle=(a.title or ''):lower()
        local bTitle=(b.title or ''):lower()
        if aTitle~=bTitle then return aTitle<bTitle end
        return tostring(a.key or a.id)<tostring(b.key or b.id)
    end)
    local rows={}
    for _,item in ipairs(top) do
        if item.kind=='group' then
            rows[#rows+1]={rowType='group',groupKey=item.key,group=item.group,title=item.title}
            if expanded[item.key] then
                for _,member in ipairs(item.group.members) do
                    rows[#rows+1]={rowType='child',id=member.id,title=member.title,level=member.level,
                        at=member.at,source=member.source,ready=member.ready,groupKey=item.key,
                        showID=(item.group.kind=='variants')}
                end
            end
        else
            local e=item.entry
            rows[#rows+1]={rowType='quest',id=e.id,title=e.title,level=e.level,
                at=e.at,source=e.source,ready=e.ready}
        end
    end
    return rows,catalog
end
