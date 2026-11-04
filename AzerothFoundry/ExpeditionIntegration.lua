-- v0.6.2 - Charter-aware, read-only resource eligibility for Foundry planning.
-- An enrolled character's possession is NOT evidence of self-found provenance.
-- Account browsing remains untouched; only explicit Expedition planning is scoped.
local _, AF = ...

function AF:GetExpeditionPlanningPolicy(scope, ownerKey)
    local c=self.GetExpeditionCharter and self:GetExpeditionCharter() or nil
    local active=c and c.state=='active'
    if scope~='expedition' then
        return {mode='account',active=active==true,owner=ownerKey,
            label='All Alts (not charter-qualified)',
            note='Account-wide records are for browsing and general planning, not Self-Found compliance.'}
    end
    if not active then
        return {mode='roster',active=false,owner=ownerKey,
            label='Expedition roster (no active charter)',
            note='Only enrolled characters are shown; no active charter restricts sharing.'}
    end
    local key=ownerKey or (self.GetCurrentKey and self:GetCurrentKey())
    if not key or not self.IsCharterScopedMember or not self:IsCharterScopedMember(key) then
        return {mode='excluded',active=true,owner=key,label='Outside active charter',
            note='This character has no active charter observation period. No resources are eligible for an Expedition plan.'}
    end
    -- Missing published rules (older version) are NOT assumed permissive.
    if c.rules and c.rules.altShare==true then
        return {mode='shared',active=true,owner=key,label='Enrolled character pool',
            note='Recorded stock from currently enrolled members may contribute to Expedition planning; item origins remain unverified.'}
    end
    return {mode='personal',active=true,owner=key,label='Personal resources only',
        note=(c.rules and c.rules.altShare==false) and
            'The charter restricts alt sharing: only the assigned crafter\'s saved bags and bank can contribute.' or
            'This charter has no published alt-sharing permission: only the assigned crafter\'s saved resources can contribute.'}
end

function AF:CanUseRecordedResources(sourceKey, ownerKey, scope)
    if not self.db or not self.db.characters or not self.db.characters[sourceKey] then
        return false,'Unregistered character'
    end
    if scope~='expedition' then return true,'Account-only estimate; not charter-qualified' end
    if not self:IsExpeditionMember(sourceKey) then return false,'Outside Expedition roster' end
    local p=self:GetExpeditionPlanningPolicy(scope,ownerKey)
    if p.mode=='excluded' then return false,p.note end
    if p.mode=='roster' then return true,'Membership-only; charter inactive' end
    if not self:IsCharterScopedMember(sourceKey) then return false,'No active observation period' end
    if p.mode=='personal' and sourceKey~=p.owner then return false,'Alt sharing not permitted' end
    return true,'Eligible by roster and permission; provenance unverified'
end

function AF:GetPlanningResourceCharacters(scope,ownerKey)
    local result={}
    for _,char in ipairs(self:GetWorkshopCharacters(scope or 'all')) do
        if self:CanUseRecordedResources(char.key,ownerKey,scope) then
            result[#result+1]=char
        end
    end
    return result
end

function AF:GetExpeditionParticipation(key)
    local c=self.GetExpeditionCharter and self:GetExpeditionCharter() or nil
    if not key or not self:IsExpeditionMember(key) then return 'Independent','Not enrolled in the Expedition' end
    if not c or c.state~='active' then return 'Enrolled (charter inactive)','Membership alone is not Self-Found compliance' end
    if not self:IsCharterScopedMember(key) then return 'Enrolled (unobserved)','No active observation period; do not count as monitored' end
    local periods=c.periods and c.periods[key]
    local period=periods and periods[#periods]
    return 'Charter participant', 'Charter v'..tostring(c.version or '?')..' | Observed since '..
        (period and type(date)=='function' and date('%b %d %Y, %H:%M',period.startedAt) or 'unknown')..
        ' | Local records do not certify compliance'
end
