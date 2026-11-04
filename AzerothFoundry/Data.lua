local _, AF = ...

local function Now()
    if type(time) == "function" then return time() end
    return 0
end

function AF:GetCurrentKey()
    local guid = UnitGUID("player")
    if guid and guid ~= "" then return guid end
    local name, realm = UnitFullName("player")
    name = name or UnitName("player") or "Unknown"
    realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or "UnknownRealm"
    return name .. "-" .. realm
end

function AF:CurrentCharacter()
    return self.db and self.db.characters[self:GetCurrentKey()]
end

function AF:ScanCharacter()
    if not self.db then return end
    local key = self:GetCurrentKey()
    local c = self.db.characters[key]
    if not c then
        c = { key = key, professions = {} }
        self.db.characters[key] = c
    end
    local name, realm = UnitFullName("player")
    local _, class = UnitClass("player")
    c.name = name or UnitName("player") or "Unknown"
    c.realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or "Unknown Realm"
    c.class = class or "WARRIOR"
    c.level = UnitLevel("player") or c.level or 1
    c.faction = UnitFactionGroup("player") or c.faction
    if type(UnitRace) == "function" then
        local race = UnitRace("player")
        c.race = race or c.race
    end
    c.lastSeen = Now()
    c.professions = type(c.professions) == "table" and c.professions or {}

    -- Profession availability is not atomic during login / character switches.
    -- GetProfessions() can transiently return all nil slots, or only part of
    -- the character's learned skills. Replacing the entire saved table on
    -- those scans incorrectly deletes another alt's previously recorded data.
    -- Each verified GetProfessionInfo result is authoritative for THAT SKILL;
    -- missing results are not proof that a learned skill was unlearned.
    -- The ledger is therefore last-observed-per-skill. Explicit verification
    -- of unlearned professions can be introduced separately when the client's
    -- full skill list can be trusted, but background login scans must not erase it.
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        local ok, first, second, archaeology, fishing, cooking, firstAid = pcall(GetProfessions)
        if ok then
            local slots = { first or false, second or false, archaeology or false,
                            fishing or false, cooking or false, firstAid or false }
            local seenIndices = 0
            local observed = 0
            for _, idx in ipairs(slots) do
                -- Index 0 is not a valid profession. Treat it as unloaded too.
                if type(idx)=="number" and idx>0 then
                    seenIndices = seenIndices+1
                    local success, skillName, icon, rank, maximum = pcall(GetProfessionInfo, idx)
                    if success and type(skillName)=="string" and skillName~=""
                        and type(rank)=="number" and rank>=0 then
                        -- Preserve other recorded professions when the API is
                        -- temporarily incomplete; only refresh this one skill.
                        c.professions[skillName] = {
                            name = skillName,
                            skill = rank,
                            maximum = type(maximum)=="number" and maximum or 0,
                            icon = icon,
                            updated = Now(),
                        }
                        observed = observed+1
                    end
                end
            end
            if observed>0 then
                c.professionsScanned = Now()
                c.professionsScanIncomplete = observed < seenIndices
            elseif seenIndices>0 then
                c.professionsScanIncomplete = true
            elseif next(c.professions) then
                -- Do not turn a transient empty login response into an
                -- account-wide deletion. The saved record remains visible.
                c.professionsScanIncomplete = true
            end
        end
    end
    if self.SyncWorkshopGoals then self:SyncWorkshopGoals(key) end
    return c
end

function AF:GetCharacters()
    local chars = {}
    if not self.db then return chars end
    for _, c in pairs(self.db.characters) do
        table.insert(chars, c)
    end
    table.sort(chars, function(a, b)
        if a.key == self.db.mainKey then return true end
        if b.key == self.db.mainKey then return false end
        if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
        return (a.name or "") < (b.name or "")
    end)
    return chars
end

function AF:SetMain(key)
    if self.db.characters[key] then
        if self.ChooseExpeditionMain then
            self:ChooseExpeditionMain(key)
        else
            self.db.mainKey = key
            self:RefreshUI()
        end
    end
end

function AF:CharacterLabel(key)
    if not key then return "Account-wide" end
    local c = self.db.characters[key]
    if not c then return "Unknown character" end
    return (c.name or "Unknown") .. " - " .. (c.realm or "Unknown Realm")
end

function AF:CycleOwner(current)
    local owners = { false }
    for _, c in ipairs(self:GetCharacters()) do
        table.insert(owners, c.key)
    end
    local index = 1
    for i, key in ipairs(owners) do
        if (key or false) == (current or false) then index = i break end
    end
    return owners[(index % #owners) + 1] or nil
end

function AF:AddProject()
    local project = {
        id = self:NextID(), title = "New project", description = "",
        owner = nil, done = false, tasks = {}, created = Now(), updated = Now(),
    }
    table.insert(self.db.projects, project)
    return project
end

function AF:AddNote()
    local note = {
        id = self:NextID(), title = "New note", body = "", owner = nil,
        created = Now(), updated = Now(),
    }
    table.insert(self.db.notes, note)
    return note
end

function AF:FindRecord(list, id)
    for _, item in ipairs(list) do
        if item.id == id then return item end
    end
end

function AF:DeleteRecord(list, id)
    for i, item in ipairs(list) do
        if item.id == id then
            table.remove(list, i)
            return
        end
    end
end

function AF:CountTasks(project)
    local total, done = 0, 0
    for _, task in ipairs(project.tasks or {}) do
        total = total + 1
        if task.done then done = done + 1 end
    end
    return done, total
end

function AF:ProfessionSummary()
    local byName = {}
    for _, char in ipairs(self:GetCharacters()) do
        for name, prof in pairs(char.professions or {}) do
            local existing = byName[name]
            if not existing then
                existing = { name = name, maxSkill = prof.skill or 0, maximum = prof.maximum or 0, characters = {} }
                byName[name] = existing
            end
            table.insert(existing.characters, { character = char, profession = prof })
            existing.maxSkill = math.max(existing.maxSkill, prof.skill or 0)
            existing.maximum = math.max(existing.maximum, prof.maximum or 0)
        end
    end
    local names = {}
    for _, p in pairs(byName) do table.insert(names, p) end
    table.sort(names, function(a, b) return a.name < b.name end)
    return names
end
