-- Azeroth Foundry v0.6.2.1.1: reliable first-in-world Expedition initiation.
-- Account-wide SavedVariables; no character-creation-screen injection.
-- This module deliberately does NOT activate a Self-Found charter automatically.
local _, AF = ...
local function now() return type(time)=="function" and time() or 0 end
local VALID_PREF = {ask=true,suggest=true,off=true}
local VALID_PRESET = {solo=true,account=true,custom=true}

function AF:InitializeExpeditionInitiation()
    local db=self.db
    if not db then return end
    db.expeditionInitiation = type(db.expeditionInitiation)=="table" and db.expeditionInitiation or {}
    local init=db.expeditionInitiation
    init.decisions = type(init.decisions)=="table" and init.decisions or {}
    if not VALID_PREF[init.preference] then init.preference="ask" end
    -- Existing Foundry users must never be mistaken for freshly created alts.
    -- This runs during ADDON_LOADED, BEFORE the current character is scanned.
    if not init.migrated then
        for key in pairs(db.characters or {}) do
            if not init.decisions[key] then
                init.decisions[key]={choice="preexisting", timestamp=now()}
            end
        end
        init.migrated=true
    end
end

function AF:GetInitiationPreference()
    local init=self.db and self.db.expeditionInitiation
    return init and init.preference or "ask"
end
function AF:SetInitiationPreference(preference)
    if not VALID_PREF[preference] or not self.db then return false end
    self.db.expeditionInitiation.preference=preference
    self:RefreshUI()
    return true
end

-- Decisions, not registration timing, determine whether the initiation is due.
-- A new character can be registered by another startup listener BEFORE our
-- PLAYER_LOGIN callback. The v0.6.2.1 "alreadyRegistered" check then suppressed
-- the prompt even though that character had never made a choice.
-- Previous characters were explicitly marked 'preexisting' during migration.
-- 'offered' is NOT a completed choice: early-login UI could be hidden by loading.
function AF:ShouldOfferExpeditionInitiation(key)
    if self.IsModuleEnabled and not self:IsModuleEnabled("selfFound") then return false end
    local init=self.db and self.db.expeditionInitiation
    if not init or not key or not self.db.characters or not self.db.characters[key] then return false end
    local decision=init.decisions[key]
    if decision and decision.choice~="offered" then return false end
    if init.preference=="off" then
        init.decisions[key]={choice="prompts_disabled",timestamp=now()}
        return false
    end
    return true
end

function AF:MarkExpeditionInitiationShown(key)
    local init=self.db and self.db.expeditionInitiation
    if not init then return false end
    local decision=init.decisions[key]
    if decision and decision.choice~="offered" then return false end
    init.decisions[key]={choice="offered",timestamp=now()}
    return true
end

function AF:CompleteExpeditionInitiation(key, choice, preset)
    local db=self.db
    if not db or not db.characters or not db.characters[key] then
        return false,"Character is not registered in Foundry"
    end
    if key~=self:GetCurrentKey() then return false,"Only the logged-in character can choose its first-login path" end
    local init=db.expeditionInitiation
    if not init then return false,"Initiation database is not initialized" end
    if choice~="independent" and choice~="join" and choice~="charter" and choice~="later" then
        return false,"Unknown initiation choice"
    end
    if choice=="charter" then
        if not VALID_PRESET[preset] then return false,"Choose a ruleset first" end
        local c=self:GetExpeditionCharter()
        if not c then return false,"Charter database unavailable" end
        if c.state=="active" then return false,"An active charter already exists. Join it or remain independent." end
        local members=self:GetExpeditionMembers()
        if preset=="solo" then
            for _,member in ipairs(members) do
                if member.key~=key then
                    return false,"Solo requires that no other adventurers remain enrolled. You can adjust the roster in Characters."
                end
            end
        end
        -- Don't archive an ended run until a valid new-charter action is chosen.
        if c.state=="ended" then
            local ok,reason=self:PrepareNewCharter()
            if not ok then return false,reason end
        end
        if not self:IsExpeditionMember(key) then
            local ok,reason
            if not db.mainKey then ok,reason=self:ChooseExpeditionMain(key)
            else ok,reason=self:JoinExpedition(key) end
            if not ok then return false,reason end
        end
        if not db.mainKey then
            local ok,reason=self:ChooseExpeditionMain(key)
            if not ok then return false,reason end
        end
        local ok,reason=self:ChooseCharterPreset(preset)
        if not ok then return false,reason end
    elseif choice=="join" then
        if not self:IsExpeditionMember(key) then
            local ok,reason
            if not db.mainKey then ok,reason=self:ChooseExpeditionMain(key)
            else ok,reason=self:JoinExpedition(key) end
            if not ok then return false,reason end
        end
    end
    -- Choosing Independent/Later never enrolls or changes the main character.
    init.decisions[key]={choice=choice,preset=choice=="charter" and preset or nil,timestamp=now()}
    db.settings.welcomed=true -- Old welcome flow is superseded; do not reintroduce it.
    self:RefreshUI()
    return true
end
