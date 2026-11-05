-- Azeroth Foundry: bootstrap and account-wide data (WoW: Forever / Interface 16001)
local ADDON_NAME, AF = ...
AF.name = ADDON_NAME
AF.version = "1.0.12"
AF.events = CreateFrame("Frame")

local function Print(message)
    print("|cffffd18a[Azeroth Foundry]|r " .. tostring(message))
end
AF.Print = Print

function AF:InitializeDatabase()
    -- Offer the general guide only for a genuinely new SavedVariables file.
    -- Existing installations retain their prior settings with no popup.
    local freshInstall=type(AzerothFoundryDB)~="table" or next(AzerothFoundryDB)==nil
    if type(AzerothFoundryDB) ~= "table" then
        AzerothFoundryDB = {}
    end
    self.db = AzerothFoundryDB
    local db = self.db
    db.schema = tonumber(db.schema) or 1
    db.characters = type(db.characters) == "table" and db.characters or {}
    db.notes = type(db.notes) == "table" and db.notes or {}
    db.projects = type(db.projects) == "table" and db.projects or {}
    db.settings = type(db.settings) == "table" and db.settings or {}
    -- Preserve existing users' Expedition access; only fresh installations start
    -- with the optional Self-Found feature out of navigation.
    db.settings.modules = type(db.settings.modules)=="table" and db.settings.modules or {}
    if type(db.settings.modules.selfFound)~="boolean" then
        db.settings.modules.selfFound=not freshInstall
    end
    if type(db.settings.guidePrompted)~="boolean" then
        db.settings.guidePrompted=not freshInstall
    end
    db.settings.guideStep=math.max(1,math.min(13,math.floor(tonumber(db.settings.guideStep) or 1)))
    db.settings.width = tonumber(db.settings.width) or 1080
    db.settings.height = tonumber(db.settings.height) or 690
    db.settings.page = db.settings.page or "Overview"
    -- New navigation/presentation preferences are isolated from core tracking.
    if type(db.settings.navigationCollapsed) ~= "boolean" then db.settings.navigationCollapsed=false end
    if type(db.settings.workshopTreeExpanded) ~= "boolean" then db.settings.workshopTreeExpanded=true end
    if type(db.settings.collectionsTreeExpanded) ~= "boolean" then db.settings.collectionsTreeExpanded=true end
    if type(db.settings.goalsTreeExpanded) ~= "boolean" then db.settings.goalsTreeExpanded=true end
    if db.settings.navigationTabTint ~= "bronze" and db.settings.navigationTabTint ~= "slate" then
        db.settings.navigationTabTint="bronze"
    end
    if type(db.settings.showNavigationTooltips) ~= "boolean" then db.settings.showNavigationTooltips=true end
    if type(db.settings.rememberFoundryPage) ~= "boolean" then db.settings.rememberFoundryPage=true end
    if type(db.settings.devMode) ~= "boolean" then db.settings.devMode=false end
    db.settings.interfaceScale = math.max(.80, math.min(1.15, tonumber(db.settings.interfaceScale) or 1))
    -- Display-only migration. Legacy page labels stay valid for slash commands
    -- and hyperlinks; NO character, recipe, project or inventory data is moved.
    if db.settings.page == "Recipes" then
        db.settings.page = "Living Workshop"
        db.settings.workshopTab = "Recipes"
    elseif db.settings.page == "Workshop" then
        db.settings.page = "Living Workshop"
        db.settings.workshopTab = db.settings.workshopTab or "Professions"
    elseif db.settings.page == "Projects" then
        db.settings.page = "Goals"
    end
    local allowedTabs = {Professions=true, Recipes=true, ["Crafting Queue"]=true, Materials=true}
    if not allowedTabs[db.settings.workshopTab] then db.settings.workshopTab="Professions" end
    db.sequence = tonumber(db.sequence) or 0
    if self.InitializeExpeditions then self:InitializeExpeditions() end
    if self.InitializeExpeditionCharter then self:InitializeExpeditionCharter() end
    if self.InitializeExpeditionMilestones then self:InitializeExpeditionMilestones() end
    if self.InitializeExpeditionInitiation then self:InitializeExpeditionInitiation() end
    if self.InitializeWorkshop then self:InitializeWorkshop() end
    if self.InitializeRecipes then self:InitializeRecipes() end
    if self.InitializeInventory then self:InitializeInventory() end
    if self.InitializeCrafting then self:InitializeCrafting() end
    if self.InitializeCraftingQueue then self:InitializeCraftingQueue() end
    if self.InitializeGuidedGoals then self:InitializeGuidedGoals() end
    if self.InitializeAtlas then self:InitializeAtlas() end
    if self.InitializeQuestRecords then self:InitializeQuestRecords() end
    if self.InitializeCollections then self:InitializeCollections() end
end

-- This first packaged feature is a visibility/participation gate, not a
-- downloadable addon or an unloadable runtime dependency. Never delete records.
function AF:IsModuleEnabled(id)
    if id~="selfFound" then return false end
    local modules=self.db and self.db.settings and self.db.settings.modules
    return not modules or modules.selfFound~=false
end

function AF:SetModuleEnabled(id,enabled)
    if id~="selfFound" or not self.db then return false,"Unknown module" end
    enabled=(enabled==true)
    if not enabled and self:IsModuleEnabled("selfFound") then
        local run=self.GetExpeditionCharter and self:GetExpeditionCharter()
        if run and run.state=="active" then
            return false,"End the active Expedition charter before hiding Self-Found. Your records will be preserved."
        end
    end
    self.db.settings.modules.selfFound=enabled
    if self.UI and self.UI.currentPage=="Self-Found" and not enabled then
        self.UI:Switch("Characters")
    end
    self:RefreshUI()
    return true
end

function AF:NextID()
    self.db.sequence = self.db.sequence + 1
    return self.db.sequence
end

function AF:RefreshUI()
    if self.UI and self.UI.frame and self.UI.frame:IsShown() then
        self.UI:Refresh()
    end
end

-- The welcome belongs AFTER the world load, not in PLAYER_LOGIN while the
-- loading screen / UI bootstrap may still be transitioning. Never use a fixed
-- suppression cooldown: uncompleted 'offered' decisions remain retryable.
function AF:ScheduleExpeditionInitiation()
    if not self._initWorldReady or self._initShownThisLogin or self._initScheduled
       or not self.db or not self.UI or not self.UI.frame
       or not self.UI.ShowExpeditionInitiation then return end
    local key=self:GetCurrentKey()
    if not self:ShouldOfferExpeditionInitiation(key) then return end
    local token=self._initLoginToken
    self._initScheduled=true
    local function offer()
        if AF._initLoginToken~=token then return end
        AF._initScheduled=false
        if AF._initShownThisLogin or AF:GetCurrentKey()~=key
           or not AF:ShouldOfferExpeditionInitiation(key) then return end
        if type(InCombatLockdown)=="function" and InCombatLockdown() then
            -- Try again on PLAYER_REGEN_ENABLED. Never open over combat UI.
            return
        end
        local ok,shown=pcall(AF.UI.ShowExpeditionInitiation,AF.UI,key,false)
        if ok and shown==true then
            AF._initShownThisLogin=true
        elseif not ok then
            Print("Expedition initiation UI error: "..tostring(shown))
        else
            Print("Expedition initiation could not open; type /af initiation to retry.")
        end
    end
    if C_Timer and type(C_Timer.After)=="function" then
        C_Timer.After(1.5,offer)
    else
        offer() -- Compatible fallback for builds without C_Timer.After.
    end
end

-- One-time welcome appears after the first world load on a *fresh* install.
-- Existing SavedVariables / completed guide choices are never interrupted.
function AF:ScheduleGuideWelcome()
    if not self.db or not self.db.settings or self.db.settings.guidePrompted~=false
        or not self.UI or not self.UI.frame or self._guideWelcomeScheduled then return end
    self._guideWelcomeScheduled=true
    local token=self._initLoginToken
    local function show()
        AF._guideWelcomeScheduled=false
        if token~=AF._initLoginToken or not AF.db or AF.db.settings.guidePrompted~=false then return end
        if type(InCombatLockdown)=="function" and InCombatLockdown() then return end
        if AF.UI and AF.UI.frame then AF.UI:Open() end
    end
    if C_Timer and type(C_Timer.After)=="function" then C_Timer.After(1.5,show)
    else show() end
end

AF.events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon ~= ADDON_NAME then return end
        AF:InitializeDatabase()
    elseif event == "PLAYER_LOGIN" then
        AF.inventoryShutdown=false
        if not AF.db then AF:InitializeDatabase() end
        AF._initLoginToken=(AF._initLoginToken or 0)+1
        AF._initWorldReady=false
        AF._initScheduled=false
        AF._initShownThisLogin=false
        AF._guideWelcomeScheduled=false
        AF:ScanCharacter()
        if AF.InitializeCharterRuleObserver then AF:InitializeCharterRuleObserver() end
        if AF.RecordCurrentAtlasZone then AF:RecordCurrentAtlasZone() end
        if AF.CaptureRecordedAtlasDiscovery then AF:CaptureRecordedAtlasDiscovery() end
        if AF.CaptureCurrentAtlasDiscovery then AF:CaptureCurrentAtlasDiscovery() end
        if AF.ScanQuestRecords then AF:ScanQuestRecords() end
        if AF.BackfillCompletedQuestRecords then AF:BackfillCompletedQuestRecords() end
        if AF.ScanBags then AF:ScanBags() end
        if AF.SyncGuidedGoals then AF:SyncGuidedGoals(false) end
        if AF.SyncExplorationGoals then AF:SyncExplorationGoals(false) end
        -- Initialize the minimap independently of page rendering. An Atlas UI
        -- failure must not prevent the journal shortcut or a login diagnostic.
        if AF.CreateMinimapButton then
            local ok,err=pcall(AF.CreateMinimapButton,AF)
            if not ok then Print('Minimap button error: '..tostring(err)) end
        end
        local initialized,uiError=pcall(AF.UI.Initialize,AF.UI)
        if initialized then
            if AF.UI.InitializeGoalTracker then
                local ok,err=pcall(AF.UI.InitializeGoalTracker,AF.UI)
                if not ok then Print('Goal tracker error: '..tostring(err)) end
            end
            -- Do not show the new-adventurer dialog yet. PLAYER_ENTERING_WORLD
            -- plus a short delay is the first safe opportunity after loading.
            Print('Ready. Type |cff8adcfb/af|r to open your Adventurer\'s Journal.')
        else
            Print('Journal UI error: '..tostring(uiError)..' (minimap shortcut remains available)')
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if AF._initWorldReady then AF:ScheduleGuideWelcome() end
        if AF.RestoreQueuedNativeProfessionAfterCombat then
            AF:RestoreQueuedNativeProfessionAfterCombat()
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
        if AF.ObserveMilestoneInstance then AF:ObserveMilestoneInstance() end
        if AF.db and AF.RecordCurrentAtlasZone then
            AF:RecordCurrentAtlasZone()
            if AF.CaptureCurrentAtlasDiscovery then AF:CaptureCurrentAtlasDiscovery() end
            if AF.SyncExplorationGoals then AF:SyncExplorationGoals(true) end
            if AF.UI and AF.UI.currentPage=="Exploration" then AF:RefreshUI() end
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LEVEL_UP"
        or event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_SHOW" then
        if AF.db then
            local scanned=AF:ScanCharacter()
            if AF.ObserveMilestoneLevel and (event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_LEVEL_UP") then
                AF:ObserveMilestoneLevel((scanned and scanned.level) or UnitLevel("player"), AF:GetCurrentKey())
            end
            if event=="PLAYER_ENTERING_WORLD" or event=="SKILL_LINES_CHANGED" or event=="TRADE_SKILL_SHOW" then
                if AF.ObserveMilestoneProfessionProgress then AF:ObserveMilestoneProfessionProgress(AF:GetCurrentKey()) end
                if AF.ObserveMilestoneProfessionFeats then AF:ObserveMilestoneProfessionFeats(AF:GetCurrentKey()) end
            end
            if event=="PLAYER_ENTERING_WORLD" and AF.ObserveMilestoneInstance then AF:ObserveMilestoneInstance() end
            if event=="PLAYER_ENTERING_WORLD" then
                if AF.CheckExpeditionCompanyMilestone then AF:CheckExpeditionCompanyMilestone() end
                AF._initWorldReady=true
                AF:ScheduleGuideWelcome()
            end
            if event == "PLAYER_ENTERING_WORLD" and AF.BackfillCompletedQuestRecords then
                AF:BackfillCompletedQuestRecords()
                if AF.UI and AF.UI.RefreshQuestJournal then AF.UI:RefreshQuestJournal() end
            end
            if AF.RecordCurrentAtlasZone then AF:RecordCurrentAtlasZone() end
            if event=='PLAYER_ENTERING_WORLD' and AF.CaptureCurrentAtlasDiscovery then AF:CaptureCurrentAtlasDiscovery() end
            if AF.SyncGuidedGoals then AF:SyncGuidedGoals(true) end
            if AF.SyncExplorationGoals then AF:SyncExplorationGoals(false) end
            if AF.UI and AF.UI.RefreshGoalTracker then AF.UI:RefreshGoalTracker() end
            AF:RefreshUI()
        end
    elseif event == "ENCOUNTER_END" or event == "BOSS_KILL" then
        if AF.ObserveMilestoneBossEvent then
            if event == "ENCOUNTER_END" then
                local encounterID,encounterName,_,_,success=...
                AF:ObserveMilestoneBossEvent(event,encounterID,encounterName,success)
            else
                local encounterID,encounterName=...
                AF:ObserveMilestoneBossEvent(event,encounterID,encounterName,1)
            end
        end
    elseif event == "MAP_EXPLORATION_UPDATED" or event == "CRITERIA_UPDATE"
        or event == "ACHIEVEMENT_EARNED" then
        if AF.db and AF.CaptureCurrentAtlasDiscovery then AF:CaptureCurrentAtlasDiscovery() end
    elseif event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        if AF.CaptureQuestNPCDialogue then AF:CaptureQuestNPCDialogue(event) end
        if AF.CaptureQuestRewardReferences then AF:CaptureQuestRewardReferences(event) end
    elseif event == "QUEST_ACCEPTED" then
        if AF.RecordQuestAccepted then AF:RecordQuestAccepted(...) end
        if AF.ScanQuestRecords then AF:ScanQuestRecords() end
        if AF.UI and AF.UI.RefreshQuestJournal then AF.UI:RefreshQuestJournal() end
    elseif event == "QUEST_TURNED_IN" then
        if AF.RecordQuestTurnIn then AF:RecordQuestTurnIn(...) end
        if AF.ObserveMilestoneQuestTurnIn then AF:ObserveMilestoneQuestTurnIn(...) end
        if AF.ScanQuestRecords then AF:ScanQuestRecords() end
        if AF.SyncExplorationGoals then AF:SyncExplorationGoals(true) end
        if AF.UI and AF.UI.RefreshQuestJournal then AF.UI:RefreshQuestJournal() end
    elseif event == "QUEST_LOG_UPDATE" then
        if AF.ScanQuestRecords then AF:ScanQuestRecords() end
        if AF.SyncExplorationGoals then AF:SyncExplorationGoals(false) end
        if AF.UI and AF.UI.RefreshQuestJournal then AF.UI:RefreshQuestJournal() end
    elseif event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        if AF.ObserveQueueCraftSignal then AF:ObserveQueueCraftSignal(event,...) end
        if AF.RecordGuidedCraftResult then AF:RecordGuidedCraftResult(...) end
        local credited=AF.ObserveQueuedCraftResult and AF:ObserveQueuedCraftResult(...)
        if AF.ObserveQueueCraftItemCredit then AF:ObserveQueueCraftItemCredit(credited) end
        if AF.ObserveMilestoneCraftResult then AF:ObserveMilestoneCraftResult(...) end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if AF.ObserveQueueCraftSignal then AF:ObserveQueueCraftSignal(event,...) end
        if AF.ObserveMilestoneGatherCast then AF:ObserveMilestoneGatherCast("success",...) end
    elseif event == "UNIT_SPELLCAST_START" then
        if AF.ObserveQueueCraftSignal then AF:ObserveQueueCraftSignal(event,...) end
        if AF.ObserveMilestoneGatherCast then AF:ObserveMilestoneGatherCast("start",...) end
    elseif event == "UNIT_SPELLCAST_SENT" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "TRADE_SKILL_CRAFT_BEGIN"
        or event == "UPDATE_TRADESKILL_CAST_COMPLETE" or event == "UPDATE_TRADESKILL_CAST_STOPPED"
        or event == "UI_ERROR_MESSAGE" or event == "ADDON_ACTION_BLOCKED"
        or event == "ADDON_ACTION_FORBIDDEN" then
        if AF.ObserveQueueCraftSignal then AF:ObserveQueueCraftSignal(event,...) end
    elseif event == "LOOT_READY" or event == "LOOT_OPENED" or event == "LOOT_SLOT_CLEARED" then
        if AF.ObserveMilestoneLootWindow then AF:ObserveMilestoneLootWindow(event) end
    elseif event == "CHAT_MSG_LOOT" then
        if AF.ObserveMilestoneGatherChatLoot then AF:ObserveMilestoneGatherChatLoot(...) end
    elseif event == "BAG_UPDATE_DELAYED" then
        if AF.ScheduleInventoryScan then AF:ScheduleInventoryScan() end
    elseif event == "BANKFRAME_OPENED" then
        AF.bankOpen=true
        if AF.ScheduleInventoryScan then AF:ScheduleInventoryScan() end
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        if AF.bankOpen and AF.ScheduleInventoryScan then AF:ScheduleInventoryScan() end
    elseif event == "BANKFRAME_CLOSED" then
        if AF.bankOpen and AF.ScanBank then AF:ScanBank() end
        AF.bankOpen=false
    elseif event == "TRADE_SKILL_LIST_UPDATE" or event == "NEW_RECIPE_LEARNED" then
        if AF.db and AF.ScheduleRecipeScan then AF:ScheduleRecipeScan() end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if AF.UI and AF.UI.OnQuestItemInfoReceived then AF.UI:OnQuestItemInfoReceived(...) end
        if AF.SyncGuidedGoals then AF:SyncGuidedGoals(false) end
        -- Item details load asynchronously. Only refresh the visible recipe page
        -- and coalesce several cache events into one UI update.
        if AF.UI and AF.UI.frame and AF.UI.frame:IsShown()
            and AF.db and (AF.db.settings.page == "Living Workshop" or AF.db.settings.page == "Goals") then
            if not AF.itemRefreshPending then
                AF.itemRefreshPending = true
                local function refresh()
                    AF.itemRefreshPending = nil
                    if AF.db and (AF.db.settings.page == "Living Workshop" or AF.db.settings.page == "Goals") then
                        AF:RefreshUI()
                        if AF.UI and AF.UI.RefreshCraftPlanner then AF.UI:RefreshCraftPlanner() end
                    end
                end
                if C_Timer and type(C_Timer.After) == "function" then
                    C_Timer.After(0.15, refresh)
                else
                    refresh()
                end
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        -- Bag APIs can return incomplete transitional data while logging out.
        -- BAG_UPDATE_DELAYED and live scans have already recorded current
        -- stock; preserve the last verified per-character snapshot here.
        AF.inventoryShutdown=true
        if AF.db then
            if AF.CaptureCurrentAtlasDiscovery then AF:CaptureCurrentAtlasDiscovery() end
            AF:ScanCharacter()
        end
    end
end)

-- Core lifecycle events are required. All other registrations are optional
-- because Retail and Forever expose different observer events between builds.
-- A missing optional event must not prevent the journal from loading.
AF.events:RegisterEvent("ADDON_LOADED")
AF.events:RegisterEvent("PLAYER_LOGIN")
AF._unsupportedEventRegistrations={}
local function RegisterCompatibleEvent(event)
    local ok,err=pcall(AF.events.RegisterEvent,AF.events,event)
    if not ok then
        AF._unsupportedEventRegistrations[#AF._unsupportedEventRegistrations+1]={name=event,error=tostring(err)}
    end
end
RegisterCompatibleEvent("PLAYER_REGEN_ENABLED")
RegisterCompatibleEvent("MAP_EXPLORATION_UPDATED")
RegisterCompatibleEvent("CRITERIA_UPDATE")
RegisterCompatibleEvent("ACHIEVEMENT_EARNED")
RegisterCompatibleEvent("PLAYER_ENTERING_WORLD")
RegisterCompatibleEvent("ZONE_CHANGED_NEW_AREA")
RegisterCompatibleEvent("ZONE_CHANGED")
RegisterCompatibleEvent("PLAYER_LEVEL_UP")
RegisterCompatibleEvent("SKILL_LINES_CHANGED")
RegisterCompatibleEvent("TRADE_SKILL_SHOW")
RegisterCompatibleEvent("TRADE_SKILL_LIST_UPDATE")
RegisterCompatibleEvent("NEW_RECIPE_LEARNED")
RegisterCompatibleEvent("PLAYER_LOGOUT")
RegisterCompatibleEvent("QUEST_DETAIL")
RegisterCompatibleEvent("QUEST_PROGRESS")
RegisterCompatibleEvent("QUEST_COMPLETE")
RegisterCompatibleEvent("QUEST_ACCEPTED")
RegisterCompatibleEvent("QUEST_LOG_UPDATE")
RegisterCompatibleEvent("QUEST_TURNED_IN")
RegisterCompatibleEvent("GET_ITEM_INFO_RECEIVED")
RegisterCompatibleEvent("BAG_UPDATE_DELAYED")
RegisterCompatibleEvent("BANKFRAME_OPENED")
RegisterCompatibleEvent("PLAYERBANKSLOTS_CHANGED")
RegisterCompatibleEvent("BANKFRAME_CLOSED")
RegisterCompatibleEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")
AF._milestoneGatherRegistrations={}
for _,name in ipairs({"UNIT_SPELLCAST_START","UNIT_SPELLCAST_SUCCEEDED","LOOT_READY","LOOT_OPENED","LOOT_SLOT_CLEARED","CHAT_MSG_LOOT","ENCOUNTER_END","BOSS_KILL"}) do
    -- Forever APIs can differ by client build; optional observer is fail-closed.
    local ok,err=pcall(AF.events.RegisterEvent,AF.events,name)
    AF._milestoneGatherRegistrations[#AF._milestoneGatherRegistrations+1]={name=name,ok=ok,error=ok and nil or tostring(err)}
end

AF._queueCraftDiagnosticsRegistrations={}
for _,name in ipairs({"UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_INTERRUPTED",
    "TRADE_SKILL_CRAFT_BEGIN","UPDATE_TRADESKILL_CAST_COMPLETE","UPDATE_TRADESKILL_CAST_STOPPED",
    "UI_ERROR_MESSAGE","ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN"}) do
    -- Optional diagnostic events. Clients may not implement every event.
    local ok,err=pcall(AF.events.RegisterEvent,AF.events,name)
    AF._queueCraftDiagnosticsRegistrations[#AF._queueCraftDiagnosticsRegistrations+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
end

SLASH_AZEROTHFOUNDRY1 = "/af"
SLASH_AZEROTHFOUNDRY2 = "/foundry"
SlashCmdList.AZEROTHFOUNDRY = function(arg)
    local command = tostring(arg or ""):lower():match("^%s*(.-)%s*$")
    if command == "guide" or command == "tutorial" or command == "tour" then
        if AF.UI and AF.UI.OpenAdventurersGuide then
            AF.UI:OpenAdventurersGuide()
        else
            Print("Adventurer's Guide is unavailable until the journal finishes loading.")
        end
        return
    elseif command == "gatherdebug" or command == "gatherdebug on" or command == "gatherdebug off" then
        if AF.SetMilestoneGatherDebug then
            local value=command=="gatherdebug on" or
                (command=="gatherdebug" and not (AF._gatherDiagnostics and AF._gatherDiagnostics.enabled))
            AF:SetMilestoneGatherDebug(value)
        end
        return
    elseif command:match('^toycheck%s+') then
        local value=tostring(arg or ''):match('^%s*%S+%s+(.+)$') or ''
        local itemID=tonumber(value:match('item:(%d+)')) or tonumber(value:match('(%d+)'))
        if not itemID then Print('Usage: /af toycheck <item ID or item link>')
        elseif AF.ObserveOwnedToyItem then
            local ok,msg=AF:ObserveOwnedToyItem(itemID,'manual')
            local function probe(fn,...)
                if type(fn)~='function' then return 'unavailable' end
                local ok,value=pcall(fn,...)
                if ok then return value end
                return 'unavailable'
            end
            local total=probe(C_ToyBox and C_ToyBox.GetNumToys)
            local listed=probe(C_ToyBox and C_ToyBox.GetNumFilteredToys)
            local owned=probe(PlayerHasToy,itemID)
            Print('Toy #'..itemID..': '..tostring(msg)..' | owned='..tostring(owned)
                ..' | Forever catalog='..tostring(listed)..'/'..tostring(total))
            if ok and AF.UI and AF.UI.currentPage=='Collections' then AF:RefreshUI() end
        end
        return
    elseif command == 'discoverystatus' then
        local c=AF.db and AF.db.collections or {}
        local last=c.lastMerchantScan or {}
        local methods=last.mountMethods or {}
        Print('Last vendor: '..tostring(last.name or 'none')..' | slots='..tostring(last.slots or 0)
            ..' | matched='..tostring(last.matched or 0)..' | new='..tostring(last.newlyDiscovered or 0)
            ..' | unresolved='..tostring(last.unresolved or 0)..' | unmatched='..tostring(last.unmatched or 0))
        Print('Mount matches: item='..tostring(methods.item or 0)..' spell='..tostring(methods.spell or 0)
            ..' exact-name='..tostring(methods['exact-name'] or 0))
        local count,examples=0,{}
        for _,rec in pairs(c.discoveries or {}) do
            if type(rec)=='table' and rec.category=='mounts' and type(rec.sources)=='table' then
                for _,src in pairs(rec.sources) do
                    if type(src)=='table' and src.kind=='vendor' and src.npcName==last.name then
                        count=count+1
                        if #examples<6 then examples[#examples+1]=tostring(rec.name or rec.id) end
                        break
                    end
                end
            end
        end
        Print('Discovered mounts at last vendor: '..count..' | '..table.concat(examples,', '))
        return
    elseif command == 'discoveryscan' then
        if AF.CaptureMerchantCollections then
            local count,message=AF:CaptureMerchantCollections()
            Print(message or ('Recorded '..tostring(count)..' collectibles'))
            if AF.UI and AF.UI.currentPage=='Collections' then AF:RefreshUI() end
        end
        return
    elseif command == "toystatus" then
        local d=AF.collectionToyCatalogDiagnostics or {}
        Print('Toy catalog: visible='..tostring(d.native)..' total='..tostring(d.total)
            ..' | PlayerHasToy='..tostring(type(PlayerHasToy))
            ..' | Toy tooltip='..tostring(C_TooltipInfo and type(C_TooltipInfo.GetToyByItemID)))
        if AF.GetToyDiscoveryAudit then
            local valid,hidden=AF:GetToyDiscoveryAudit()
            Print('Saved toy discoveries: verified='..tostring(valid)..' | unverified hidden='..tostring(hidden)
                ..' (original records preserved for later revalidation)')
        end
        return
    elseif command == "craftstatus" then
        local projects=AF.GetCraftingQueueProjects and AF:GetCraftingQueueProjects() or {}
        local selected=AF.UI and AF.UI.workshopQueueSelected
        local entry=selected and AF:FindRecord(projects,selected) or projects[1]
        if not entry then
            Print('Crafting Queue empty. Add a recipe in Workshop > Recipes first.')
        elseif AF.GetQueueCraftDiagnostic then
            for _,line in ipairs(AF:GetQueueCraftDiagnostic(entry)) do Print(line) end
        else
            Print('Craft diagnostics unavailable in this version.')
        end
        return
    elseif command == "gatherstatus" then
        if AF.PrintMilestoneGatherStatus then AF:PrintMilestoneGatherStatus() end
        return
    end
    if command == "initiation" or command == "initiationretry" then
        -- Explicit recovery route for new characters affected by old login
        -- timing, or existing characters who want to opt in voluntarily.
        local init=AF.db and AF.db.expeditionInitiation
        local key=AF:GetCurrentKey()
        local decision=init and init.decisions and init.decisions[key]
        local choice=decision and decision.choice
        if choice=="join" or choice=="charter" or choice=="independent" or choice=="later" then
            Print("Your first-login choice is already recorded. Change membership in Characters.")
            return
        end
        if AF.UI and AF.UI.ShowExpeditionInitiation and AF.db then
            local ok,shown=pcall(AF.UI.ShowExpeditionInitiation,AF.UI,key,false)
            if ok and shown then AF._initShownThisLogin=true
            else Print("Could not open initiation: "..tostring(shown)) end
        else
            Print("Journal is still loading.")
        end
        return
    elseif command == "initiationstatus" then
        local init=AF.db and AF.db.expeditionInitiation
        local record=init and init.decisions and init.decisions[AF:GetCurrentKey()]
        Print("Initiation: preference="..tostring(init and init.preference)
            ..", decision="..tostring(record and record.choice or "none")
            ..", worldReady="..tostring(AF._initWorldReady)
            ..", shownThisLogin="..tostring(AF._initShownThisLogin))
        return
    end
    if command == "initiationpreview" or command == "welcomepreview" then
        if AF.UI and AF.UI.ShowExpeditionInitiation and AF.db then
            AF.UI:ShowExpeditionInitiation(AF:GetCurrentKey(),true)
        end
        return
    end
    if command == "recap" or command == "questrecap" then
        if AF.UI and AF.UI.ToggleQuestRecap then AF.UI:ToggleQuestRecap() end
        return
    end
    if command == "quests" or command == "questjournal" then
        if AF.UI and AF.UI.ToggleQuestJournal then AF.UI:ToggleQuestJournal() end
        return
    elseif command == "questscan" then
        local ok,result=AF:ScanQuestRecords()
        Print(ok and ("Quest scan complete: "..result.active.." active, "..result.observed.." newly observed.") or ("Quest scan failed: "..tostring(result)))
        return
    elseif command == "questbackfill" then
        local ok,result=AF:BackfillCompletedQuestRecords()
        if ok then Print("Completed-quest backfill: "..result.added.." newly recovered, "..result.total.." completed IDs reported by the client.")
        else Print("Quest backfill unavailable: "..tostring(result)) end
        if AF.UI and AF.UI.RefreshQuestJournal then AF.UI:RefreshQuestJournal() end
        return
    elseif command == 'deps' or command == 'compat' or command == 'compatibility' then
        if AF.Compatibility then AF.Compatibility.PrintReport() end
        return
    elseif command == "queststatus" then
        Print(AF:QuestReferenceStatus())
        return
    elseif command == "help" then
        Print("/af - journal, /af guide, /af theme, /af initiation, /af initiationpreview, /af settings, /af deps, /af atlas, /af recap, /af goals (or projects), /af workshop, /af recipes, /af queue, /af materials, /af notes, /af gatherdebug, /af gatherstatus, /af craftstatus, /af toycheck <itemID>, /af toystatus, /af discoverystatus, /af discoveryscan, /af recipescan, /af bags, /af scan, /af minimap, /af testtoast, /af testmilestonetoast, /af testcomplete, /af tracker.")
    elseif command == 'mapdebug' then
        local page=AF.UI and AF.UI.pageViews and AF.UI.pageViews.Exploration
        if page and page.ToggleMapDebug then
            local ok,err=pcall(page.ToggleMapDebug,page)
            if not ok then Print('Map debug window error: '..tostring(err)) end
        else
            Print(page and ('Map debugger unavailable: '..tostring(page.afOverlayError or 'initialization did not complete')) or 'Open Exploration first to use /af mapdebug.')
        end
        return
    elseif command == 'mapreport' then
        local page=AF.UI and AF.UI.pageViews and AF.UI.pageViews.Exploration
        if page and page.PrintMapDebug then page:PrintMapDebug()
        else Print('Open Exploration first to use /af mapreport.') end
        return
    elseif command == 'atlasdebug' then
        local page=AF.UI and AF.UI.pageViews and AF.UI.pageViews.Exploration
        local reason=page and page.afOverlayError
        Print(reason and ('Atlas diagnostics: '..reason) or 'No Atlas overlay error recorded in this session.')
        if page and page.hoverStatus then
            Print('Region hover: '..tostring(page.hoverStatus))
        end
        if page and page.questBlobStatus then
            Print('Quest area highlight: '..tostring(page.questBlobStatus()))
        end
        if page and page.PrintTerrainDiagnostic then
            page.PrintTerrainDiagnostic()
        else
            Print('Terrain diagnostics unavailable. Open Exploration once, then retry.')
        end
        return
    elseif command == 'testmilestonetoast' or command == 'testexpeditiontoast' then
        if AF.UI and AF.UI.PreviewExpeditionMilestoneToast then
            AF.UI:PreviewExpeditionMilestoneToast()
        else
            Print('Expedition milestone toast unavailable; verify the UI module loaded.')
        end
    elseif command == 'testtoast' or command == 'testcomplete' then
        if AF.UI and AF.UI.TestGoalToast then AF.UI:TestGoalToast(command=='testcomplete' and 'complete' or 'milestone') end
    elseif command == "tracker" then
        if AF.db and AF.db.settings.guided then
            AF.db.settings.guided.trackerVisible=not AF.db.settings.guided.trackerVisible
            if AF.UI and AF.UI.RefreshGoalTracker then AF.UI:RefreshGoalTracker() end
        end
    elseif command == "minimap" then
        if AF.ToggleMinimapButton then AF:ToggleMinimapButton() end
    elseif command == "bags" or command == "inventory" then
        if AF.ScanBags and AF:ScanBags() then
            Print('Bag snapshot updated. Bank contents are scanned when visiting a banker.')
            AF:RefreshUI()
        else
            Print('Bag contents unavailable; prior inventory snapshot kept.')
        end
    elseif command == "recipescan" then
        if AF.ScanOpenRecipes then
            local ok, message = AF:ScanOpenRecipes()
            if not ok then Print(message) end
        end
    elseif command == "scan" then
        AF:ScanCharacter()
        if AF.ScanBags then AF:ScanBags() end
        AF:RefreshUI()
        Print("Character and available profession data refreshed.")
    else
        if not AF.UI or not AF.UI.frame then
            Print("Journal is still loading.")
            return
        end
        if command == "settings" or command == "prefs" or command == "preferences" or command == "theme" then
            AF.UI:Open("Settings")
            if command=="theme" then
                local page=AF.UI.pageViews and AF.UI.pageViews.Settings
                if page and page.SelectSettingsSection then page.SelectSettingsSection("themes") end
            end
        elseif command == "notes" then
            AF.UI:Open("Notes")
        elseif command == "projects" or command == "goals" then
            AF.UI:Open("Goals")
        elseif command == "chars" then
            AF.UI:Open("Characters")
        elseif command == "workshop" then
            AF.UI:Open("Workshop")
        elseif command == "recipes" then
            AF.UI:Open("Recipes")
        elseif command == "queue" or command == "crafting" then
            AF.UI:Open("Crafting Queue")
        elseif command == "materials" then
            AF.UI:Open("Materials")
        else
            AF.UI:Toggle()
        end
    end
end

-- Integrated Settings shortcut (no collision with optional AF_SettingsUXLab /afsettings).
SLASH_AFINTEGRATEDPREFS1 = "/afprefs"
SlashCmdList.AFINTEGRATEDPREFS = function()
    if AF.UI and AF.UI.frame then AF.UI:Open("Settings")
    elseif AF.Print then AF.Print("Settings are still loading.") end
end
