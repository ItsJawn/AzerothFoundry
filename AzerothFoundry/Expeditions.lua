-- Expedition membership and its local, chronological audit trail.
-- This is an organizer, NOT certification of in-game self-found compliance.
local _, AF = ...

local function Now()
    return type(time) == "function" and time() or 0
end

local DEFAULT_ID = "foundry"
AF.DEFAULT_EXPEDITION = DEFAULT_ID

function AF:InitializeExpeditions()
    if not self.db then return end
    local db = self.db
    db.expeditions = type(db.expeditions) == "table" and db.expeditions or {}
    local exp = db.expeditions[DEFAULT_ID]
    if type(exp) ~= "table" then
        exp = { id = DEFAULT_ID, name = "Foundry Expedition", ruleset = "Account Self-Found", history = {} }
        db.expeditions[DEFAULT_ID] = exp
    end
    exp.history = type(exp.history) == "table" and exp.history or {}
    exp.name = type(exp.name) == "string" and exp.name or "Foundry Expedition"
    exp.ruleset = exp.ruleset or "Account Self-Found"

    -- Upgrade old account data.  Never silently enroll an existing alt.
    -- Only the previous main joins, with an explicit *unverified* legacy event.
    if not db.expeditionMigrationV2 then
        for _, char in pairs(db.characters or {}) do
            char.expeditionId = nil
            char.expeditionJoinCount = 0
        end
        local main = db.mainKey and db.characters[db.mainKey]
        if main then
            main.expeditionId = DEFAULT_ID
            main.expeditionJoinedAt = Now()
            main.expeditionJoinCount = 1
            self:RecordExpeditionEvent("import", main.key,
                "Existing main enrolled after upgrade; play before this date is unverified.")
        end
        db.expeditionMigrationV2 = true
    end
    db.schema = math.max(tonumber(db.schema) or 1, 2)
end

function AF:GetExpedition()
    return self.db and self.db.expeditions and self.db.expeditions[DEFAULT_ID]
end

function AF:IsExpeditionMember(key)
    local c = self.db and self.db.characters and self.db.characters[key]
    return c ~= nil and c.expeditionId == DEFAULT_ID
end

function AF:GetExpeditionMembers()
    local inside, outside = {}, {}
    for _, c in ipairs(self:GetCharacters()) do
        if self:IsExpeditionMember(c.key) then
            inside[#inside+1] = c
        else
            outside[#outside+1] = c
        end
    end
    return inside, outside
end

function AF:RecordExpeditionEvent(kind, key, explanation)
    local exp = self:GetExpedition()
    if not exp then return end
    local c = self.db.characters[key]
    exp.history[#exp.history+1] = {
        id = self:NextID(),
        timestamp = Now(),
        event = kind,
        characterKey = key,
        characterName = c and c.name or "Unknown",
        realm = c and c.realm or "Unknown",
        ruleset = exp.ruleset,
        detail = explanation or "",
    }
end

function AF:CharacterHasExpeditionHistory(key)
    local exp = self:GetExpedition()
    if not exp then return false end
    for _, event in ipairs(exp.history) do
        if event.characterKey == key and
            (event.event == "depart" or event.event == "join" or event.event == "rejoin") then
            return true
        end
    end
    return false
end

function AF:JoinExpedition(key)
    local c = self.db and self.db.characters[key]
    if not c then return false, "Unknown character" end
    if self:IsExpeditionMember(key) then return false, "Already a member" end
    local previous = (tonumber(c.expeditionJoinCount) or 0) > 0 or self:CharacterHasExpeditionHistory(key)
    if self.CanJoinExpeditionUnderCharter then
        local allowed, reason = self:CanJoinExpeditionUnderCharter(key)
        if not allowed then return false, reason end
    end
    c.expeditionId = DEFAULT_ID
    c.expeditionJoinedAt = Now()
    c.expeditionJoinCount = (tonumber(c.expeditionJoinCount) or 0) + 1
    if previous then
        self:RecordExpeditionEvent("rejoin", key,
            "New tracking period. Earlier departure and unobserved activity remain in history.")
    else
        self:RecordExpeditionEvent("join", key,
            "First enrollment. Activity before enrollment cannot be verified.")
    end
    if self.OnExpeditionMembershipChanged then self:OnExpeditionMembershipChanged(key,true) end
    self:RefreshUI()
    return true
end

function AF:LeaveExpedition(key)
    if not self:IsExpeditionMember(key) then return false, "Not a member" end
    if self.db.mainKey == key then
        return false, "Assign another enrolled member as the main character before removing this one."
    end
    local c = self.db.characters[key]
    c.expeditionId = nil
    c.expeditionJoinedAt = nil
    self:RecordExpeditionEvent("depart", key,
        "Membership ended. Outside activity is not monitored by this Expedition.")
    if self.OnExpeditionMembershipChanged then self:OnExpeditionMembershipChanged(key,false) end
    self:RefreshUI()
    return true
end

function AF:ChooseExpeditionMain(key)
    if not self.db.characters[key] then return false end
    if not self:IsExpeditionMember(key) then
        local ok, reason = self:JoinExpedition(key) -- Also used by the initial welcome flow.
        if not ok then return false, reason end
    end
    local prior = self.db.mainKey
    if prior ~= key then
        self.db.mainKey = key
        self:RecordExpeditionEvent("leader", key, "Designated as the Expedition main character.")
    end
    self:RefreshUI()
    return true
end

local ROLES = { "Adventurer", "Defender", "Healer", "Damage", "Crafter", "Gatherer", "Explorer" }
function AF:CycleExpeditionRole(key)
    local c = self.db and self.db.characters[key]
    if not c then return end
    local old = c.expeditionRole or ROLES[1]
    local index = 1
    for i, role in ipairs(ROLES) do if role == old then index = i; break end end
    c.expeditionRole = ROLES[(index % #ROLES) + 1]
    self:RefreshUI()
end

function AF:CharacterExpeditionEvents(key, limit)
    local exp = self:GetExpedition()
    local items = {}
    if not exp then return items end
    for i = #exp.history, 1, -1 do
        local e = exp.history[i]
        if e.characterKey == key then
            items[#items+1] = e
            if limit and #items >= limit then break end
        end
    end
    return items
end
