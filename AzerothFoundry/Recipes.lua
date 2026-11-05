-- Azeroth Foundry: local recipe observations and optional ProfessionDB adapter.
-- A reference database entry NEVER establishes that a character learned a recipe.
local _, AF = ...
local function Now() return type(time) == 'function' and time() or 0 end
local function Number(v) return type(v) == 'number' and v or nil end
local function Safe(method, ...)
    if type(method) ~= 'function' then return nil end
    local ok, value = pcall(method, ...)
    if ok then return value end
    return nil
end

function AF:InitializeRecipes()
    local db = self.db
    db.recipeSnapshots = type(db.recipeSnapshots) == 'table' and db.recipeSnapshots or {}
    db.settings.recipes = type(db.settings.recipes) == 'table' and db.settings.recipes or {}
    local opts = db.settings.recipes
    if opts.status ~= 'learned' and opts.status ~= 'unlearned' then opts.status = 'learned' end
    if opts.scope ~= 'all' and opts.scope ~= 'expedition' then opts.scope = 'all' end
    opts.showFullCatalog = opts.showFullCatalog == true  -- reserved; never used in v0.3.1 listing
    db.schema = math.max(tonumber(db.schema) or 1, 4)
end

-- ProfessionDB is optional. Missing library data never blocks native recipe scans.
-- No library data is copied into SavedVariables; the library owns its own data.
function AF:GetProfessionReference()
    -- LibStub is normally a TABLE with a __call metamethod, not a function.
    -- Use its documented GetLibrary method; function-style test doubles are
    -- accepted as a fallback without assuming the real global has that type.
    local stub = LibStub
    local ok, lib
    if type(stub) == 'table' and type(stub.GetLibrary) == 'function' then
        ok, lib = pcall(stub.GetLibrary, stub, 'LibProfessionDB-1.0', true)
    elseif type(stub) == 'function' then
        ok, lib = pcall(stub, 'LibProfessionDB-1.0', true)
    else
        return nil
    end
    if not ok or not lib or type(lib.IsReady) ~= 'function' then return nil end
    local ready = Safe(lib.IsReady, lib)
    if not ready then return nil end
    if type(lib.GetGameVersion) == 'function' then
        local game = Safe(lib.GetGameVersion, lib)
        if type(game) == 'string' then
            local family = self.Compatibility and self.Compatibility.GetClient()
                or 'Forever'
            local reported = game:lower()
            local accepted = family == 'Retail' and (reported == 'retail' or reported == 'mainline')
                or family == 'Forever' and (reported == 'forever' or reported == 'camelot')
            if not accepted then return nil end
        end
    end
    return lib
end

-- The Forever profession APIs may omit schematic reagent details for some
-- recipes. LibProfessionDB can provide a local, offline fallback.
local function CopyReagents(source)
    if type(source) ~= 'table' then return nil end
    local result = {}
    for key, entry in pairs(source) do
        local itemID, count
        if type(entry) == 'table' then
            itemID = Number(entry.itemID) or Number(entry.itemId) or Number(entry.id) or Number(entry[1])
            count = Number(entry.quantity) or Number(entry.count) or Number(entry.amount) or Number(entry[2])
        elseif type(key) == 'number' and type(entry) == 'number' then
            itemID, count = key, entry
        end
        if itemID and itemID > 0 then
            result[#result + 1] = { itemID = itemID, quantity = math.max(1, count or 1) }
        end
    end
    table.sort(result, function(a,b) return a.itemID < b.itemID end)
    return #result > 0 and result or nil
end

local function SchematicReagents(schematic)
    if type(schematic) ~= 'table' or type(schematic.reagentSlotSchematics) ~= 'table' then return nil end
    local result, incomplete = {}, false
    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        if type(slot) == 'table' and type(slot.reagents) == 'table' then
            -- Alternative reagents cannot safely be flattened into one recipe
            -- requirement. Only record slots containing exactly one item.
            if #slot.reagents == 1 then
                local reagent = slot.reagents[1]
                local itemID = type(reagent) == 'table' and Number(reagent.itemID)
                if itemID and itemID > 0 then
                    result[#result+1] = {itemID=itemID, quantity=math.max(1, Number(slot.quantityRequired) or 1)}
                else
                    incomplete = true
                end
            elseif #slot.reagents > 1 then
                incomplete = true
            end
        end
    end
    return #result > 0 and result or nil, incomplete
end

function AF:GetRecipeReference(professionID, recipeID)
    local lib = self:GetProfessionReference()
    if not lib or not professionID or not recipeID or type(lib.GetRecipe) ~= 'function' then return nil end
    return Safe(lib.GetRecipe, lib, professionID, recipeID)
end

-- Returns a UI-ready record (copy) enriched with optional reference data.
function AF:GetRecipeDetails(snapshot, record)
    if not record then return nil end
    local result = {}
    for k,v in pairs(record) do result[k] = v end
    local ref = self:GetRecipeReference(snapshot and snapshot.professionID, record.id)
    local lib = self:GetProfessionReference()
    if type(ref) == 'table' then
        result.name = result.name or ref.name
        result.outputItemID = result.outputItemID or Number(ref.craftedItemId) or Number(ref.craftedItemID)

        result.requiredSkill = result.requiredSkill or Number(ref.requiredSkill)
        result.reagents = result.reagents or CopyReagents(ref.reagents)
        result.referenceAvailable = true
        result.effect = ref.effect
    end
    if lib then
        if not result.requiredSkill and type(lib.GetRequiredSkill) == 'function' then
            result.requiredSkill = Number(Safe(lib.GetRequiredSkill, lib,
                snapshot and snapshot.professionID, record.id))
        end
        if not result.outputItemID and type(lib.GetCraftedItemID) == 'function' then
            result.outputItemID = Number(Safe(lib.GetCraftedItemID, lib,
                snapshot and snapshot.professionID, record.id))
        end
        if not result.reagents and type(lib.GetReagents) == 'function' then
            result.reagents = CopyReagents(Safe(lib.GetReagents, lib,
                snapshot and snapshot.professionID, record.id))
        end
        if type(lib.IsBorrowed) == 'function' then
            result.requiredSkillBorrowed = Safe(lib.IsBorrowed, lib, record.id, 'requiredSkill')
        end
    end
    return result
end

function AF:RecipeSnapshotsForScope(scope, professionFilter, characterFilter, statusFilter, search)
    local matches, unique, positions = {}, {}, {}
    search = (search or ''):lower()
    -- Multiple historic profession snapshots can reference the same recipe.
    -- Avoid duplicated rows, keeping the newest complete and named snapshot.
    -- No SavedVariables are deleted by this presentation-only cleanup.
    local function SnapshotRank(snap)
        local score = (type(snap.professionName)=='string' and
            snap.professionName:match('%S') and 10000000000 or 0)
        if type(snap.professionID)=='number' and snap.professionID>0 then
            score=score+1000000000
        end
        return score + math.max(0,tonumber(snap.scanned) or 0)
    end
    for _, c in ipairs(self:GetWorkshopCharacters(scope or 'all')) do
        if not characterFilter or characterFilter == c.key then
            local byProfession = self.db.recipeSnapshots[c.key] or {}
            for _, snapshot in pairs(byProfession) do
                if type(snapshot)=='table' and
                    (not professionFilter or professionFilter == snapshot.professionID) then
                    for _, r in pairs(snapshot.recipes or {}) do
                        if type(r)=='table' and r.id and
                            (statusFilter == nil or (statusFilter == 'learned' and r.learned == true)
                                or (statusFilter == 'unlearned' and r.learned == false))
                            and (search == '' or (r.name or ''):lower():find(search, 1, true)
                                or tostring(r.id):find(search, 1, true)) then
                            local k=tostring(c.key)..':'..tostring(r.id)
                            local candidate={character=c,snapshot=snapshot,recipe=r}
                            local previous=unique[k]
                            if not previous or SnapshotRank(snapshot)>SnapshotRank(previous.snapshot) then
                                unique[k]=candidate
                                if not positions[k] then
                                    matches[#matches+1]=candidate
                                    positions[k]=#matches
                                else
                                    matches[positions[k]]=candidate
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(matches, function(a,b)
        local an,bn = (a.recipe.name or ''):lower(), (b.recipe.name or ''):lower()
        if an ~= bn then return an < bn end
        return (a.character.name or '') < (b.character.name or '')
    end)
    return matches
end

-- Optional characterKey limits the profession directory to the selected
-- crafter. The Recipes view must not show unrelated alts' professions when
-- its character filter is active; the account-wide view stays unchanged.
function AF:GetRecipeProfessions(scope, characterKey)
    local result, lookup = {}, {}
    for _, c in ipairs(self:GetWorkshopCharacters(scope or 'all')) do
        if not characterKey or c.key == characterKey then
        for _, snapshot in pairs(self.db.recipeSnapshots[c.key] or {}) do
            local k = snapshot.professionID
            if k and not lookup[k] then
                local row = {id=k, name=snapshot.professionName or ('Profession '..k), icon=snapshot.icon}
                lookup[k] = row
                result[#result+1] = row
            end
        end
        end
    end
    table.sort(result, function(a,b) return a.name < b.name end)
    return result
end

-- Called only for the OPEN profession, never to infer another character's
-- learning state from the reference library. Empty/unavailable scans are not
-- considered a successful snapshot and cannot destroy existing data.
function AF:ScanOpenRecipes(silent)
    local api = C_TradeSkillUI
    if type(api) ~= 'table' or type(api.GetBaseProfessionInfo) ~= 'function'
        or type(api.GetAllRecipeIDs) ~= 'function' or type(api.GetRecipeInfo) ~= 'function' then
        self.recipeScanMessage = 'Recipe API unavailable in this client.'
        return false, self.recipeScanMessage
    end
    local info = Safe(api.GetBaseProfessionInfo)
    if type(info) ~= 'table' or not Number(info.professionID) or not info.professionName then
        self.recipeScanMessage = 'Open a profession window to scan its recipes.'
        return false, self.recipeScanMessage
    end
    local ids = Safe(api.GetAllRecipeIDs)
    if type(ids) ~= 'table' or #ids == 0 then
        self.recipeScanMessage = 'No recipe list yet. Open the profession and try again.'
        return false, self.recipeScanMessage
    end
    local key = self:GetCurrentKey()
    if not self.db.characters[key] then return false, 'Character not registered.' end
    local byID = {}
    local learned, missing, failed = 0, 0, 0
    for _, id in ipairs(ids) do
        if type(id) == 'number' then
            local r = Safe(api.GetRecipeInfo, id)
            if type(r) == 'table' and type(r.name) == 'string' and type(r.learned) == 'boolean' then
                local row = {id=id, name=r.name, learned=r.learned, icon=r.icon, scanned=Now(),
                    -- Forever's native profession difficulty is authoritative
                    -- for the *scanning character at scan time*. Never infer
                    -- a different alt's current skill-up chance from it.
                    relativeDifficulty=Number(r.relativeDifficulty),
                    numSkillUps=Number(r.numSkillUps),
                    canSkillUp=r.canSkillUp,
                    recipeLink=type(r.hyperlink)=='string' and r.hyperlink or nil}
                local schematic = Safe(api.GetRecipeSchematic, id, false)
                if type(schematic) == 'table' then
                    row.outputItemID = Number(schematic.outputItemID)
                    row.reagents, row.reagentsIncomplete = SchematicReagents(schematic)
                    row.quantityMin = Number(schematic.quantityMin)
                end
                -- Resolve an item link only if the schematic omitted its
                -- output; avoid an expensive extra link lookup on every recipe.
                if not row.outputItemID and type(api.GetRecipeItemLink)=='function' then
                    local outputLink=Safe(api.GetRecipeItemLink,id)
                    if type(outputLink)=='string' and outputLink:find('|Hitem:',1,true) then
                        row.outputItemLink=outputLink
                        row.outputItemID=tonumber(outputLink:match('item:(%d+)'))
                    end
                end
                byID[id] = row
                if r.learned then learned=learned+1 else missing=missing+1 end
            else
                failed=failed+1
            end
        end
    end
    if learned + missing == 0 or failed > 0 then
        -- A partial snapshot is dangerous: it may falsely imply known recipes
        -- disappeared. Preserve the last complete scan, prompt retry.
        self.recipeScanMessage = 'Incomplete scan ('..failed..' unavailable entries). Previous recipes kept.'
        return false, self.recipeScanMessage
    end
    local charRecipes = self.db.recipeSnapshots[key]
    if type(charRecipes) ~= 'table' then
        charRecipes={}
        self.db.recipeSnapshots[key] = charRecipes
    end
    local prior = charRecipes[info.professionID]
    -- A successful TradeSkill scan can still be filtered by the client's
    -- visible recipe list. Preserve previously observed entries absent from
    -- this response, just as we preserve recorded professions across alts.
    -- Only the logged-in owner's profession snapshot is ever touched here.
    for id, old in pairs((prior and prior.recipes) or {}) do
        if type(old)=="table" and byID[id]==nil then
            byID[id]=old
        elseif type(old)=="table" and byID[id] and old.learned and not byID[id].learned then
            -- Avoid turning a transient "unlearned" view into a lost recipe.
            byID[id].learned=true
        end
    end
    learned,missing=0,0
    for _,record in pairs(byID) do
        if record.learned then learned=learned+1 else missing=missing+1 end
    end
    charRecipes[info.professionID] = {
        professionID=info.professionID,
        professionName=info.professionName,
        scanned=Now(),
        learned=learned,
        unlearned=missing,
        recipes=byID,
    }
    self.recipeScanMessage = string.format('%s: %d learned, %d unlearned entries recorded.',
        info.professionName, learned, missing)
    if not silent and self.Print then self.Print(self.recipeScanMessage) end
    if self.SyncGuidedGoals then self:SyncGuidedGoals(true) end
    if self.UI and self.UI.RefreshGoalTracker then self.UI:RefreshGoalTracker() end
    self:RefreshUI()
    return true, self.recipeScanMessage
end

function AF:ScheduleRecipeScan()
    -- A profession can emit TRADE_SKILL_SHOW before its data populates.
    -- Two short retries give the client a chance to finish loading.
    if not C_Timer or type(C_Timer.After) ~= 'function' then
        self:ScanOpenRecipes(true)
        return
    end
    self.recipeScanTicket = (self.recipeScanTicket or 0)+1
    local ticket = self.recipeScanTicket
    local delays={0.2, 1.0}
    for _, seconds in ipairs(delays) do
        C_Timer.After(seconds, function()
            if ticket ~= self.recipeScanTicket then return end
            local ok = self:ScanOpenRecipes(true)
            if ok then self.recipeScanTicket = self.recipeScanTicket+1 end
        end)
    end
end
