-- Shared account-wide profession capabilities and optional Expedition visibility.
-- No trading restrictions or self-found certification are performed here.
local _, AF = ...

local function Now()
    return type(time) == "function" and time() or 0
end

function AF:InitializeWorkshop()
    if not self.db then return end
    local db = self.db
    db.workshopGoals = type(db.workshopGoals) == "table" and db.workshopGoals or {}
    -- Reserved for later character-specific recipe discovery.  Empty in v0.3.0.
    db.recipeSnapshots = type(db.recipeSnapshots) == "table" and db.recipeSnapshots or {}
    local settings = db.settings
    settings.workshop = type(settings.workshop) == "table" and settings.workshop or {}
    local ws = settings.workshop
    if ws.browse ~= "profession" and ws.browse ~= "character" then ws.browse = "profession" end
    if ws.scope ~= "all" and ws.scope ~= "expedition" then ws.scope = "all" end
    db.schema = math.max(tonumber(db.schema) or 1, 3)
end

-- Central scope test: future crafting and recipe systems must use this API
-- instead of independently consulting expeditionId.
function AF:WorkshopCharacterAllowed(key, scope)
    if not self.db or not self.db.characters[key] then return false, "Unknown character" end
    if scope == "expedition" and not self:IsExpeditionMember(key) then
        return false, "Outside Expedition"
    end
    return true, scope == "expedition" and "Expedition member" or "Registered character"
end

function AF:GetWorkshopCharacters(scope)
    local result = {}
    for _, c in ipairs(self:GetCharacters()) do
        if self:WorkshopCharacterAllowed(c.key, scope) then result[#result+1] = c end
    end
    return result
end

function AF:GetWorkshopProfessions(scope)
    local byName = {}
    for _, c in ipairs(self:GetWorkshopCharacters(scope)) do
        for name, prof in pairs(c.professions or {}) do
            local summary = byName[name]
            if not summary then
                summary = {name=name, icon=prof.icon, maxSkill=0, maximum=0, characters={}}
                byName[name] = summary
            end
            summary.icon = summary.icon or prof.icon
            summary.maxSkill = math.max(summary.maxSkill, tonumber(prof.skill) or 0)
            summary.maximum = math.max(summary.maximum, tonumber(prof.maximum) or 0)
            summary.characters[#summary.characters+1] = {character=c, profession=prof}
        end
    end
    local result = {}
    for _, summary in pairs(byName) do
        table.sort(summary.characters, function(a,b)
            local askill, bskill = tonumber(a.profession.skill) or 0, tonumber(b.profession.skill) or 0
            if askill ~= bskill then return askill > bskill end
            return (a.character.name or "") < (b.character.name or "")
        end)
        result[#result+1] = summary
    end
    table.sort(result, function(a,b) return a.name < b.name end)
    return result
end

function AF:GetWorkshopGoal(key, profession)
    local byCharacter = self.db and self.db.workshopGoals and self.db.workshopGoals[key]
    return byCharacter and byCharacter[profession] or nil
end

function AF:GetWorkshopGoalProject(goal)
    if not goal or not goal.projectId then return nil end
    return self:FindRecord(self.db.projects, goal.projectId)
end

function AF:SyncWorkshopGoals(key)
    if not self.db or not self.db.workshopGoals then return end
    local c = self.db.characters[key]
    if not c then return end
    for name, goal in pairs(self.db.workshopGoals[key] or {}) do
        local prof = c.professions and c.professions[name]
        local project = self:GetWorkshopGoalProject(goal)
        if prof then
            goal.current = tonumber(prof.skill) or 0
            goal.lastScan = prof.updated or c.professionsScanned
            goal.complete = goal.current >= (tonumber(goal.target) or 0)
            if project and project.done ~= goal.complete then
                project.done = goal.complete
                project.updated = Now()
            end
        end
    end
end

function AF:SetWorkshopGoal(key, profession, target)
    local c = self.db and self.db.characters[key]
    local prof = c and c.professions and c.professions[profession]
    target = tonumber(target)
    if not prof then return false, "Profession not recorded on that character" end
    if not target or target < 1 or target > 999 or target ~= math.floor(target) then
        return false, "Enter a whole-number skill target between 1 and 999"
    end
    local list = self.db.workshopGoals[key]
    if not list then list = {}; self.db.workshopGoals[key] = list end
    local goal = list[profession]
    if not goal then
        goal = {characterKey=key, profession=profession, created=Now()}
        list[profession] = goal
    end
    goal.target = target
    goal.updated = Now()
    local project = self:GetWorkshopGoalProject(goal)
    if not project then
        project = self:AddProject()
        goal.projectId = project.id
        project.workshopGoal = {characterKey=key, profession=profession}
        project.owner = key
        project.description = "Workshop profession goal. Progress updates when this character is scanned."
    end
    project.title = "Reach " .. profession .. " " .. target .. " (" .. (c.name or "Character") .. ")"
    project.updated = Now()
    self:SyncWorkshopGoals(key)
    self:RefreshUI()
    return true, goal
end

function AF:ClearWorkshopGoal(key, profession)
    local list = self.db and self.db.workshopGoals[key]
    if not list or not list[profession] then return false end
    local goal = list[profession]
    local project = self:GetWorkshopGoalProject(goal)
    if project then
        -- Never silently delete a player project or its manually edited notes.
        project.workshopGoal = nil
        project.description = (project.description or "") .. "\n(Workshop goal removed; project retained for review.)"
        project.updated = Now()
    end
    list[profession] = nil
    if not next(list) then self.db.workshopGoals[key] = nil end
    self:RefreshUI()
    return true
end
