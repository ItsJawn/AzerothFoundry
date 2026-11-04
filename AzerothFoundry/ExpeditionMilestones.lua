-- v0.6.4 Expedition Milestones. Local, per-charter accomplishments; NOT WoW achievements
-- or a certificate that the rules of a self-found run were obeyed.
local _, AF = ...
local function Now() return type(time)=="function" and time() or 0 end
local function SafeText(value)
    if type(value)~="string" then return "" end
    return value:gsub("[%c]"," "):sub(1,500)
end
AF.EXPEDITION_MILESTONE_DEFS = {
    {id="first_harvest",category="Gathering",title="First Harvest",short="Record your first harvest interaction",
        description="Record your first gathering accomplishment. A correlated Herbalism or Mining cast and loot event, or a known herb/ore from a GameObject loot source, can record this automatically; alternatively declare it yourself. Neither proves item provenance.",
        method="manual",icon="Interface\\Icons\\INV_Misc_Herb_01"},

    {id="first_herb",category="Gathering",title="Green Thumb",short="Observe your first herbalism harvest",
        description="Observe a Herbalism gathering cast followed by loot, or known herb loot from a GameObject source. This records an observed gathering interaction, not proof the items reached your bags or were self-found.",
        method="gather",icon="Interface\\Icons\\INV_Misc_Herb_06"},
    {id="first_ore",category="Gathering",title="Strike the Vein",short="Observe your first ore gathering",
        description="Observe a Mining gathering cast followed by loot, or known ore loot from a GameObject source. This establishes a likely ore-node interaction, not independent verification of item provenance.",
        method="gather",icon="Interface\\Icons\\INV_Ore_Copper_01"},
    {id="first_skinning",category="Gathering",title="First Hide",short="Observe your first skinning interaction",
        description="Observe a Skinning gathering spell followed by an open loot window. This is a local observation, not proof of a specific hide entering your bags.",
        method="gather",icon="Interface\\Icons\\INV_Misc_Pelt_Wolf_01"},
    {id="first_fish",category="Gathering",title="First Catch",short="Observe your first fishing interaction",
        description="Observe a Fishing action associated with a loot window. This is a local fishing observation and does not establish that a particular fish was received.",
        method="gather",icon="Interface\\Icons\\Trade_Fishing"},
    {id="first_disenchant",category="Crafting",title="Dust to Dust",short="Observe your first disenchant cast",
        description="Observe a successful Disenchant spellcast from an enrolled character during this charter. This is a spell event, not proof of the materials recovered.",
        method="disenchant",icon="Interface\\Icons\\INV_Enchant_DustStrange"},
    {id="forged_by_hands",category="Crafting",metric="craft_count",threshold=1,title="Forged by Your Own Hands",short="Observe 1 successful craft",
        description="Record the first successful craft-result callback for an enrolled adventurer during the active charter. It establishes a local craft event, not that all ingredients were self-found.",
        method="craft",icon="Interface\\Icons\\Trade_BlackSmithing"},
    {id="craft_apprentice",category="Crafting",metric="craft_count",threshold=10,title="Apprentice Artisan",short="Observe 10 successful crafts",
        description="Observe ten successful craft-result callbacks during this charter run.",method="craft",icon="Interface\\Icons\\Trade_BlackSmithing"},
    {id="craft_journeyman",category="Crafting",metric="craft_count",threshold=25,title="Journeyman Artisan",short="Observe 25 successful crafts",
        description="Observe twenty-five successful craft-result callbacks during this charter run.",method="craft",icon="Interface\\Icons\\Trade_BlackSmithing"},
    {id="craft_master",category="Crafting",metric="craft_count",threshold=50,title="Master of the Bench",short="Observe 50 successful crafts",
        description="Observe fifty successful craft-result callbacks during this charter run.",method="craft",icon="Interface\\Icons\\Trade_BlackSmithing"},

    {id="trade_apprentice",category="Professions",metric="profession_skill",threshold=75,title="Trade Apprentice",short="Reach profession skill 75",
        description="Raise an observed profession to at least skill 75 during the active charter. Existing profession skill at the moment observation begins is not backfilled.",
        method="progress",icon="Interface\\Icons\\INV_Hammer_09"},
    {id="trade_journeyman",category="Professions",metric="profession_skill",threshold=150,title="Trade Journeyman",short="Reach profession skill 150",
        description="Raise an observed profession to at least skill 150 during the active charter.",method="progress",icon="Interface\\Icons\\INV_Hammer_09"},
    {id="trade_expert",category="Professions",metric="profession_skill",threshold=225,title="Trade Expert",short="Reach profession skill 225",
        description="Raise an observed profession to at least skill 225 during the active charter.",method="progress",icon="Interface\\Icons\\INV_Hammer_09"},
    {id="trade_master",category="Professions",metric="profession_skill",threshold=300,title="Trade Master",short="Reach profession skill 300",
        description="Raise an observed profession to at least skill 300 during the active charter.",method="progress",icon="Interface\\Icons\\INV_Hammer_09"},

    {id="cartographers_journey",category="Exploration",metric="atlas_count",threshold=1,title="Cartographer's Journey",short="Record 1 new region visit",
        description="Visit a region not previously in this character's Foundry Atlas records while the charter is active. This is a newly recorded zone visit, not 100% exploration or proof of first discovery in WoW.",
        method="atlas",icon="Interface\\Icons\\INV_Misc_Map_01"},
    {id="trailblazer",category="Exploration",metric="atlas_count",threshold=5,title="Trailblazer",short="Record 5 new region visits",
        description="Record five newly discovered Atlas regions during this charter run.",method="atlas",icon="Interface\\Icons\\INV_Misc_Map_01"},
    {id="pathfinder",category="Exploration",metric="atlas_count",threshold=15,title="Pathfinder",short="Record 15 new region visits",
        description="Record fifteen newly discovered Atlas regions during this charter run.",method="atlas",icon="Interface\\Icons\\INV_Misc_Map_01"},
    {id="worldwalker",category="Exploration",metric="atlas_count",threshold=30,title="Worldwalker",short="Record 30 new region visits",
        description="Record thirty newly discovered Atlas regions during this charter run.",method="atlas",icon="Interface\\Icons\\INV_Misc_Map_01"},
    {id="grand_explorer",category="Exploration",metric="atlas_count",threshold=60,title="Grand Explorer",short="Record 60 new region visits",
        description="Record sixty newly discovered Atlas regions during this charter run.",method="atlas",icon="Interface\\Icons\\INV_Misc_Map_01"},

    {id="first_contract",category="Questing",metric="quest_count",threshold=1,title="First Contract",short="Turn in 1 quest during the charter",
        description="Observe the turn-in of your first quest while the charter is active.",method="quest",icon="Interface\\Icons\\INV_Scroll_03"},
    {id="adventurers_start",category="Questing",metric="quest_count",threshold=10,title="Adventurer's Start",short="Turn in 10 quests during the charter",
        description="Observe ten quest turn-ins while the charter is active.",method="quest",icon="Interface\\Icons\\INV_Scroll_03"},
    {id="proven_adventurer",category="Questing",metric="quest_count",threshold=25,title="Proven Adventurer",short="Turn in 25 quests during the charter",
        description="Observe twenty-five quest turn-ins while the charter is active.",method="quest",icon="Interface\\Icons\\INV_Scroll_03"},
    {id="chapter_complete",category="Questing",metric="quest_count",threshold=50,title="Chapter Complete",short="Turn in 50 quests during the charter",
        description="Observe fifty quest turn-ins while the charter is active.",method="quest",icon="Interface\\Icons\\INV_Scroll_03"},
    {id="saga_in_motion",category="Questing",metric="quest_count",threshold=100,title="Saga in Motion",short="Turn in 100 quests during the charter",
        description="Observe one hundred quest turn-ins while the charter is active.",method="quest",icon="Interface\\Icons\\INV_Scroll_03"},

    {id="level_10",category="Character",metric="level_threshold",threshold=10,title="Into the Wilds",short="Reach level 10 during the charter",
        description="An enrolled adventurer reached at least level 10 while being observed by the active charter. Levels already held before observation are not backfilled.",
        method="progress",icon="Interface\\Icons\\Ability_Rogue_Sprint"},
    {id="level_20",category="Character",metric="level_threshold",threshold=20,title="Seasoned Adventurer",short="Reach level 20 during the charter",
        description="An enrolled adventurer reached at least level 20 during the active charter.",method="progress",icon="Interface\\Icons\\Ability_Rogue_Sprint"},
    {id="level_40",category="Character",metric="level_threshold",threshold=40,title="Veteran of the Road",short="Reach level 40 during the charter",
        description="An enrolled adventurer reached at least level 40 during the active charter.",method="progress",icon="Interface\\Icons\\Ability_Rogue_Sprint"},
    {id="level_60",category="Character",metric="level_threshold",threshold=60,title="Hero of the Expedition",short="Reach level 60 during the charter",
        description="An enrolled adventurer reached at least level 60 during the active charter.",method="progress",icon="Interface\\Icons\\Ability_Rogue_Sprint"},

    {id="company_of_adventurers",category="Roster",metric="roster_max",threshold=3,title="A Company of Adventurers",short="Enroll 3 adventurers",
        description="Have at least three enrolled characters in an active Expedition charter simultaneously. This is a Foundry roster snapshot, not proof they each played under the rules.",
        method="roster",icon="Interface\\Icons\\INV_Misc_GroupLooking"},
    {id="full_company",category="Roster",metric="roster_max",threshold=5,title="Full Company",short="Enroll 5 adventurers",
        description="Have at least five enrolled characters in the active Expedition roster at the same time.",method="roster",icon="Interface\\Icons\\INV_Misc_GroupLooking"},
    -- Milestone expansion (Forever; observable progression only)
    {id="craft_variety_5",category="Crafting",title="Five Fingers of the Forge",short="Craft 5 different items",
        description="Five distinct crafted item IDs observed from successful crafting result events in this charter. Quantities and repeat crafts do not count twice.",method="progress",metric="craft_variety",threshold=5,icon="Interface\\Icons\\Trade_BlackSmithing"},
    {id="craft_variety_20",category="Crafting",title="Workshop of Wonders",short="Craft 20 different items",
        description="Twenty distinct successfully crafted item types observed during the charter. This does not verify their ingredients were self-found.",method="progress",metric="craft_variety",threshold=20,icon="Interface\\Icons\\INV_Hammer_09"},
    {id="craft_variety_50",category="Rare Feats",title="The Fifty-Fold Forge",short="Craft 50 different items",
        description="Fifty different crafted item IDs observed in a single Expedition run. A rare feat of crafting breadth, not provenance.",method="progress",metric="craft_variety",threshold=50,icon="Interface\\Icons\\INV_Hammer_09"},
    {id="profession_breadth_2",category="Professions",title="Two Trades, One Journey",short="Improve 2 different professions",
        description="During the charter, record an increase in at least two different profession skills after their first observed baseline.",method="progress",metric="profession_breadth",threshold=2,icon="Interface\\Icons\\Trade_BlackSmithing"},
    {id="profession_breadth_3",category="Professions",title="A Hand in Every Craft",short="Improve 3 different professions",
        description="During the charter, improve at least three distinct profession skills beyond their recorded baselines. Secondary professions count.",method="progress",metric="profession_breadth",threshold=3,icon="Interface\\Icons\\INV_Hammer_09"},
    {id="double_expert",category="Professions",title="Twin Experts",short="Raise 2 professions to 225",
        description="Observe two separate professions advance to skill 225 or higher during the active Expedition. Preexisting levels are not backfilled.",method="progress",metric="profession_225",threshold=2,icon="Interface\\Icons\\Trade_BlackSmithing"},
    {id="double_master",category="Rare Feats",title="Master of Two Disciplines",short="Raise 2 professions to 300",
        description="Observe two different professions reach skill 300 in this charter run, after each had an earlier recorded baseline.",method="progress",metric="profession_300",threshold=2,icon="Interface\\Icons\\INV_Hammer_09"},
    {id="continental_crossing",category="Exploration",title="The Great Crossing",short="Visit 2 different continents",
        description="Record new Foundry Atlas regions on two distinct, API-identified continents while this charter is active.",method="progress",metric="continent_variety",threshold=2,icon="Interface\\Icons\\INV_Misc_Map_01"},
    {id="sole_explorer_5",category="Exploration",title="The Lone Trail",short="Discover 5 regions on one character",
        description="Record five newly discovered Atlas regions on the same enrolled character during this Expedition.",method="progress",metric="character_atlas_max",threshold=5,icon="Interface\\Icons\\INV_Misc_Map_01"},
    {id="sole_explorer_15",category="Rare Feats",title="The Tireless Wanderer",short="Discover 15 regions on one character",
        description="Record fifteen newly discovered Atlas regions on one enrolled adventurer during this charter.",method="progress",metric="character_atlas_max",threshold=15,icon="Interface\\Icons\\INV_Misc_Map_01"},
    {id="atlas_double_trail",category="Rare Feats",title="Paths of Two Worlds",short="Cross continents and find 20 regions",
        description="Record new zones on two different continents and discover at least twenty Atlas regions in this Expedition. Both conditions must be met.",method="progress",metric="atlas_continent_combo",threshold=1,icon="Interface\\Icons\\INV_Misc_Map_01"},
    {id="quest_unique_10",category="Questing",title="Ten Different Tales",short="Turn in 10 different quests",
        description="Observe successful turn-ins of ten distinct quest IDs during this charter. Repeating a quest does not advance this milestone.",method="progress",metric="quest_variety",threshold=10,icon="Interface\\Icons\\INV_Scroll_03"},
    {id="quest_unique_50",category="Questing",title="Tales of the Road",short="Turn in 50 different quests",
        description="Observe fifty unique quest ID turn-ins during this charter run.",method="progress",metric="quest_variety",threshold=50,icon="Interface\\Icons\\INV_Scroll_03"},
    {id="quest_unique_150",category="Rare Feats",title="The Living Chronicle",short="Turn in 150 different quests",
        description="Record one hundred fifty different quest ID turn-ins during a single Expedition.",method="progress",metric="quest_variety",threshold=150,icon="Interface\\Icons\\INV_Misc_Book_09"},
    {id="quest_day_10",category="Questing",title="A Day of Deeds",short="Turn in 10 quests on one day",
        description="Observe ten quest turn-ins during the same calendar day while an Expedition is active. Repeatables count as individual turn-ins.",method="progress",metric="quest_daily_max",threshold=10,icon="Interface\\Icons\\INV_Scroll_03"},
    {id="quest_day_25",category="Rare Feats",title="A Hero Does Not Rest",short="Turn in 25 quests on one day",
        description="Observe twenty-five quest turn-ins on the same calendar day while the charter is active.",method="progress",metric="quest_daily_max",threshold=25,icon="Interface\\Icons\\INV_Scroll_03"},
    {id="quest_days_7",category="Questing",title="Seven Days of Stories",short="Turn in quests on 7 distinct days",
        description="Observe at least one quest turned in on seven different calendar dates during the Expedition.",method="progress",metric="quest_days",threshold=7,icon="Interface\\Icons\\INV_Misc_Book_09"},
    {id="quest_zone_5",category="Questing",title="Stories of Five Lands",short="Finish quests in 5 zones",
        description="Observe quest turn-ins while standing in five different Atlas zones, without assuming their narrative quest zones.",method="progress",metric="quest_zone_variety",threshold=5,icon="Interface\\Icons\\INV_Misc_Map_01"},
    {id="quest_character_50",category="Rare Feats",title="A Single Hero's Saga",short="Turn in 50 quests on one adventurer",
        description="Observe fifty quest turn-ins from the same enrolled character during this Expedition.",method="progress",metric="quest_character_max",threshold=50,icon="Interface\\Icons\\INV_Misc_Book_09"},
    {id="dungeon_first",category="Dungeons",title="Into the Depths",short="Visit your first dungeon",
        description="Record the current enrolled character inside a dungeon instance during the active charter. This is a visit, not a completion.",method="progress",metric="dungeon_variety",threshold=1,icon="Interface\\Icons\\INV_Misc_Key_03"},
    {id="dungeon_three",category="Dungeons",title="Through Three Dark Doors",short="Visit 3 different dungeons",
        description="Visit three distinct dungeon instance IDs during the charter. Entering does not establish completing them.",method="progress",metric="dungeon_variety",threshold=3,icon="Interface\\Icons\\INV_Misc_Key_03"},
    {id="dungeon_ten",category="Rare Feats",title="Keeper of Ten Keys",short="Visit 10 different dungeons",
        description="Record visits to ten different dungeon instances during the charter.",method="progress",metric="dungeon_variety",threshold=10,icon="Interface\\Icons\\INV_Misc_Key_03"},
    {id="dungeon_first_boss",category="Dungeons",title="The First Fallen",short="Defeat 1 dungeon boss",
        description="Observe one successful dungeon boss encounter through ENCOUNTER_END or BOSS_KILL while in a dungeon.",method="progress",metric="dungeon_boss_kills",threshold=1,icon="Interface\\Icons\\INV_Sword_04"},
    {id="dungeon_boss_10",category="Dungeons",title="Dungeon Breaker",short="Defeat 10 dungeon bosses",
        description="Observe ten successful dungeon boss encounters in this charter. Defeats and duplicate notifications do not count.",method="progress",metric="dungeon_boss_kills",threshold=10,icon="Interface\\Icons\\INV_Sword_04"},
    {id="dungeon_boss_30",category="Rare Feats",title="Scourge of the Depths",short="Defeat 30 dungeon bosses",
        description="Observe thirty successful dungeon boss encounters over an Expedition run.",method="progress",metric="dungeon_boss_kills",threshold=30,icon="Interface\\Icons\\INV_Sword_04"},
    {id="dungeon_boss_variety_5",category="Dungeons",title="Five Fortresses Broken",short="Defeat bosses in 5 different dungeons",
        description="Record successful boss encounters in five different dungeon instances during the charter.",method="progress",metric="dungeon_boss_instance_variety",threshold=5,icon="Interface\\Icons\\INV_Misc_Key_03"},
    {id="dungeon_three_bosses",category="Dungeons",title="Threefold Trial",short="Defeat 3 distinct bosses in one dungeon",
        description="Record successful kills of three different encounter IDs in the same dungeon during the charter. Does not claim a full clear.",method="progress",metric="dungeon_boss_same_instance_max",threshold=3,icon="Interface\\Icons\\INV_Sword_04"},
    {id="raid_first",category="Dungeons",title="Trial by Raid",short="Defeat a raid boss",
        description="Observe your first successful encounter in a raid instance during the active Expedition.",method="progress",metric="raid_boss_kills",threshold=1,icon="Interface\\Icons\\INV_Misc_Head_Dragon_01"},
    {id="raid_five",category="Rare Feats",title="Raidbreaker",short="Defeat 5 raid bosses",
        description="Observe five successful raid boss encounters during this charter.",method="progress",metric="raid_boss_kills",threshold=5,icon="Interface\\Icons\\INV_Misc_Head_Dragon_01"},
    {id="raid_instances_2",category="Rare Feats",title="Beyond Two Thrones",short="Defeat bosses in 2 different raids",
        description="Record a successful boss encounter in two distinct raid instances in this Expedition.",method="progress",metric="raid_boss_instance_variety",threshold=2,icon="Interface\\Icons\\INV_Misc_Head_Dragon_01"},
    {id="total_boss_40",category="Rare Feats",title="The Unyielding",short="Defeat 40 dungeon or raid bosses",
        description="Observe forty successful dungeon or raid encounters within one active Expedition.",method="progress",metric="all_boss_kills",threshold=40,icon="Interface\\Icons\\INV_Sword_04"},
    {id="five_pillars",category="Rare Feats",title="Five Pillars of the Foundry",short="Craft, quest, explore, train, defeat a boss",
        description="During one Expedition observe a successful craft, a quest turn-in, a new Atlas region, an increase in a profession beyond baseline, and one successful dungeon or raid boss encounter.",method="progress",metric="five_pillars",threshold=5,icon="Interface\\Icons\\INV_Misc_Book_09"},
}


local byId, byMetric = {}, {}
for _,def in ipairs(AF.EXPEDITION_MILESTONE_DEFS) do
    byId[def.id]=def
    if def.metric then
        byMetric[def.metric]=byMetric[def.metric] or {}
        table.insert(byMetric[def.metric],def)
    end
end
for _,defs in pairs(byMetric) do
    table.sort(defs,function(a,b)
        if (a.threshold or 0)~=(b.threshold or 0) then return (a.threshold or 0)<(b.threshold or 0) end
        return (a.title or a.id)<(b.title or b.id)
    end)
end
function AF:GetExpeditionMilestoneDef(id) return byId[id] end

local function NormalizeRun(run)
    if type(run)~="table" then return end
    run.milestones=type(run.milestones)=="table" and run.milestones or {}
    run.milestoneGoals=type(run.milestoneGoals)=="table" and run.milestoneGoals or {}
    run.milestoneStats=type(run.milestoneStats)=="table" and run.milestoneStats or {}
    local s=run.milestoneStats
    s.craftCount=tonumber(s.craftCount) or 0
    s.questCount=tonumber(s.questCount) or 0
    s.atlasCount=tonumber(s.atlasCount) or 0
    s.rosterMax=tonumber(s.rosterMax) or 0
    s.levelMax=tonumber(s.levelMax) or 0
    s.professionMax=tonumber(s.professionMax) or 0
    s.levelSeen=type(s.levelSeen)=="table" and s.levelSeen or {}
    s.professionSeen=type(s.professionSeen)=="table" and s.professionSeen or {}
    -- Additive per-run metrics; do not reconstruct a run's earlier progress
    -- from character snapshots or old completed-quest APIs.
    s.feats=type(s.feats)=="table" and s.feats or {}
    local f=s.feats
    for _,field in ipairs({"craftItems","professionRanks","professionIncreases",
        "continents","atlasByCharacter","questIDs","questDays","questZones",
        "questByCharacter","dungeons","dungeonBossInstances","raidBossInstances",
        "bossIDsByDungeon"}) do
        if type(f[field])~="table" then f[field]={} end
    end
    f.dungeonBossKills=tonumber(f.dungeonBossKills) or 0
    f.raidBossKills=tonumber(f.raidBossKills) or 0
end

function AF:InitializeExpeditionMilestones()
    local exp=self:GetExpedition()
    if not exp then return end
    NormalizeRun(exp.charter)
    for _,run in ipairs(exp.charterArchive or {}) do NormalizeRun(run) end
    local function SyncExisting(run)
        if run and type(run.milestones)=="table" then
            for id in pairs(run.milestones) do
                if byId[id] then self:SyncExpeditionMilestoneGoal(run,id) end
            end
        end
    end
    SyncExisting(exp.charter)
    for _,run in ipairs(exp.charterArchive or {}) do SyncExisting(run) end
end
function AF:GetMilestoneRun(runID)
    local exp=self:GetExpedition()
    if not exp then return nil end
    local current=exp.charter
    if current and current.id==runID then return current end
    for _,run in ipairs(exp.charterArchive or {}) do
        if run.id==runID then return run end
    end
    return nil
end
function AF:GetExpeditionMilestoneAward(run,id)
    return run and type(run.milestones)=="table" and run.milestones[id] or nil
end
function AF:GetExpeditionMilestoneGoal(run,id)
    if not run or not run.id or not self.db then return nil end
    local projectId=type(run.milestoneGoals)=="table" and run.milestoneGoals[id] or nil
    local p=projectId and self:FindRecord(self.db.projects,projectId)
    if p and type(p.expeditionMilestone)=="table"
        and p.expeditionMilestone.runId==run.id and p.expeditionMilestone.id==id then return p end
    for _,candidate in ipairs(self.db.projects or {}) do
        local m=candidate.expeditionMilestone
        if type(m)=="table" and m.runId==run.id and m.id==id then
            run.milestoneGoals=type(run.milestoneGoals)=="table" and run.milestoneGoals or {}
            run.milestoneGoals[id]=candidate.id
            return candidate
        end
    end
end
function AF:SyncExpeditionMilestoneGoal(run,id)
    local p=self:GetExpeditionMilestoneGoal(run,id)
    if not p then return end
    local award=self:GetExpeditionMilestoneAward(run,id)
    if award and not p.done then
        p.done=true
        p.completedAt=award.awardedAt
        p.updated=Now()
        p.expeditionMilestone.completion={source=award.evidence,at=award.awardedAt,
            note="Local Foundry milestone; not certified self-found compliance"}
        if self.UI and self.UI.RefreshGoalTracker then self.UI:RefreshGoalTracker() end
    end
end
function AF:MakeExpeditionMilestoneGoal(run,id)
    local def=byId[id]
    if not def or not run or not run.id then return nil,"Activate a charter before adding milestone goals." end
    local found=self:GetExpeditionMilestoneGoal(run,id)
    if found then return found,false end
    local p=self:AddProject()
    local award=self:GetExpeditionMilestoneAward(run,id)
    p.title=def.title
    p.description=def.description.."\nExpedition milestone in charter run #"..tostring(run.id)..". "..
        "This is a local journal record, not a Blizzard achievement or proof of compliance."
    p.owner=nil
    p.expeditionMilestone={runId=run.id,id=id,created=Now(),category=def.category}
    run.milestoneGoals=type(run.milestoneGoals)=="table" and run.milestoneGoals or {}
    run.milestoneGoals[id]=p.id
    if award then
        p.done=true;p.completedAt=award.awardedAt;p.updated=Now()
        p.expeditionMilestone.completion={source=award.evidence,at=award.awardedAt}
    end
    local guided=self.db.settings and self.db.settings.guided
    if guided then
        guided.goalOrder=type(guided.goalOrder)=="table" and guided.goalOrder or {}
        table.insert(guided.goalOrder,1,p.id)
    end
    self:RefreshUI()
    return p,true
end

local function Award(self,run,def,evidence,detail,key)
    NormalizeRun(run)
    if run.milestones[def.id] then return false,run.milestones[def.id] end
    local award={id=def.id,awardedAt=Now(),evidence=evidence,detail=SafeText(detail),
        characterKey=key,version=run.version}
    run.milestones[def.id]=award
    local e=self:RecordCharterEvent("milestone_"..def.id,key,award.detail,evidence)
    if e then award.eventId=e.id end
    self:SyncExpeditionMilestoneGoal(run,def.id)
    -- Keep recording authoritative even if the visual toast fails to render.
    if self.UI and type(self.UI.ShowExpeditionMilestoneToast)=="function" then
        local ok,err=pcall(self.UI.ShowExpeditionMilestoneToast,self.UI,def,award)
        if not ok and type(self.Print)=="function" then
            self.Print("Expedition milestone was recorded, but its toast could not render: "..tostring(err))
        end
    end
    return true,award
end

function AF:RecordExpeditionMilestone(id,evidence,detail,key)
    local def=byId[id]
    local run=self:GetExpeditionCharter()
    if not def or not run or run.state~="active" or not run.id then return false,"No active charter" end
    NormalizeRun(run)
    if run.milestones[id] then return false,"Already recorded" end
    if def.method~="roster" and def.method~="progress" and (not key or not self:IsCharterScopedMember(key)) then
        return false,"Only active enrolled adventurers can earn this milestone"
    end
    if def.method=="manual" and evidence~="player_declared" and evidence~="local_record" then return false,"Declaration or gathering observation required" end
    if def.method=="craft" and evidence~="client_event" then return false,"Client craft event required" end
    if def.method=="atlas" and evidence~="local_record" then return false,"New Atlas visit required" end
    if def.method=="quest" and evidence~="local_record" then return false,"Quest turn-in required" end
    if def.method=="gather" and evidence~="local_record" then return false,"Gathering observation required" end
    if def.method=="disenchant" and evidence~="client_event" then return false,"Disenchant spell observation required" end
    if def.method=="roster" and evidence~="local_record" then return false,"Roster observation required" end
    local ok,award=Award(self,run,def,evidence,detail,key)
    if ok then self:RefreshUI() end
    return ok,award
end

local function GetMetricProgress(self,run,def)
    local s=run and run.milestoneStats or {}
    if def.method=="manual" or def.method=="gather" or def.method=="disenchant" then
        return self:GetExpeditionMilestoneAward(run,def.id) and 1 or 0,1,
            def.method=="manual" and "Player declaration" or "first observed event"
    elseif def.metric=="craft_count" then
        return tonumber(s.craftCount) or 0, def.threshold or 1, "successful crafts observed"
    elseif def.metric=="quest_count" then
        return tonumber(s.questCount) or 0, def.threshold or 1, "quest turn-ins observed"
    elseif def.metric=="atlas_count" then
        return tonumber(s.atlasCount) or 0, def.threshold or 1, "new regions recorded"
    elseif def.metric=="roster_max" then
        return tonumber(s.rosterMax) or 0, def.threshold or 1, "enrolled adventurers observed"
    elseif def.metric=="level_threshold" then
        return tonumber(s.levelMax) or 0, def.threshold or 1, "highest observed charter level"
    elseif def.metric=="profession_skill" then
        return tonumber(s.professionMax) or 0, def.threshold or 1, "highest observed profession skill"
    end
    local f=type(s.feats)=="table" and s.feats or {}
    local function Count(tbl)
        local n=0
        if type(tbl)=="table" then for _ in pairs(tbl) do n=n+1 end end
        return n
    end
    local function MaxValue(tbl)
        local highest=0
        if type(tbl)=="table" then
            for _,value in pairs(tbl) do
                value=tonumber(value) or 0
                if value>highest then highest=value end
            end
        end
        return highest
    end
    local m=def.metric
    local result=0
    if m=="craft_variety" then result=Count(f.craftItems)
    elseif m=="profession_breadth" then result=Count(f.professionIncreases)
    elseif m=="profession_225" or m=="profession_300" then
        for profId,rank in pairs(f.professionRanks or {}) do
            local threshold=m=="profession_225" and 225 or 300
            local initial=f.professionBaselines and tonumber(f.professionBaselines[profId])
            if initial and initial<threshold and (tonumber(rank) or 0)>=threshold then result=result+1 end
        end
    elseif m=="continent_variety" then result=Count(f.continents)
    elseif m=="character_atlas_max" then result=MaxValue(f.atlasByCharacter)
    elseif m=="atlas_continent_combo" then
        result=(Count(f.continents)>=2 and (tonumber(s.atlasCount) or 0)>=20) and 1 or 0
    elseif m=="quest_variety" then result=Count(f.questIDs)
    elseif m=="quest_daily_max" then result=MaxValue(f.questDays)
    elseif m=="quest_days" then result=Count(f.questDays)
    elseif m=="quest_zone_variety" then result=Count(f.questZones)
    elseif m=="quest_character_max" then result=MaxValue(f.questByCharacter)
    elseif m=="dungeon_variety" then result=Count(f.dungeons)
    elseif m=="dungeon_boss_kills" then result=tonumber(f.dungeonBossKills) or 0
    elseif m=="dungeon_boss_instance_variety" then result=Count(f.dungeonBossInstances)
    elseif m=="dungeon_boss_same_instance_max" then
        for _,bosses in pairs(f.bossIDsByDungeon or {}) do
            local n=Count(bosses)
            if n>result then result=n end
        end
    elseif m=="raid_boss_kills" then result=tonumber(f.raidBossKills) or 0
    elseif m=="raid_boss_instance_variety" then result=Count(f.raidBossInstances)
    elseif m=="all_boss_kills" then
        result=(tonumber(f.dungeonBossKills) or 0)+(tonumber(f.raidBossKills) or 0)
    elseif m=="five_pillars" then
        result=((tonumber(s.craftCount) or 0)>0 and 1 or 0)
            +((tonumber(s.questCount) or 0)>0 and 1 or 0)
            +((tonumber(s.atlasCount) or 0)>0 and 1 or 0)
            +(Count(f.professionIncreases)>0 and 1 or 0)
            +(((tonumber(f.dungeonBossKills) or 0)+(tonumber(f.raidBossKills) or 0))>0 and 1 or 0)
    end
    return result,def.threshold or 1,"observed progress"
end
function AF:GetExpeditionMilestoneProgress(run,id)
    local def=byId[id]
    if not def or not run then return 0,1,"progress" end
    NormalizeRun(run)
    return GetMetricProgress(self,run,def)
end

local function EvaluateMetricMilestones(self,run,metric,evidence,detail,key)
    NormalizeRun(run)
    local defs=byMetric[metric] or {}
    for _,def in ipairs(defs) do
        if not run.milestones[def.id] then
            local progress, threshold = self:GetExpeditionMilestoneProgress(run,def.id)
            if (progress or 0) >= (threshold or 1) then
                Award(self,run,def,evidence,detail,key)
            end
        end
    end
end

-- Evaluate several metrics after each verified signal. Awards use the same
-- immutable run-scoped Chronicle/Goals/toast pipeline as the original set.
local function EvaluateFeats(self,run,metrics,evidence,detail,key)
    for _,metric in ipairs(metrics) do
        EvaluateMetricMilestones(self,run,metric,evidence,detail,key)
    end
end

function AF:DeclareExpeditionHarvest()
    local key=self:GetCurrentKey()
    local ok,award=self:RecordExpeditionMilestone("first_harvest","player_declared",
        "Player declared that they personally gathered materials during this charter. Source not independently established.",key)
    return ok,award
end

function AF:CheckExpeditionCompanyMilestone()
    local run=self:GetExpeditionCharter()
    if not run or run.state~="active" then return end
    NormalizeRun(run)
    local count=tonumber(self:GetCharterMemberCount()) or 0
    if count>(run.milestoneStats.rosterMax or 0) then run.milestoneStats.rosterMax=count end
    EvaluateMetricMilestones(self,run,"roster_max","local_record",
        tostring(count).." enrolled adventurers were present in the active charter roster.")
    self:RefreshUI()
end

function AF:ObserveMilestoneCraftResult(data)
    if type(data)~="table" then return end
    local itemID=tonumber(data.itemID)
    local quantity=tonumber(data.quantity)
    if not itemID or itemID<=0 or not quantity or quantity<1 then return end
    local run=self:GetExpeditionCharter()
    local key=self:GetCurrentKey()
    if not run or run.state~="active" or not self:IsCharterScopedMember(key) then return end
    NormalizeRun(run)
    run.milestoneStats.craftCount=(run.milestoneStats.craftCount or 0)+1
    local detail="Observed successful craft #"..tostring(run.milestoneStats.craftCount).." of item #"..tostring(itemID).." ("..tostring(math.floor(quantity)).."). Material provenance unknown."
    EvaluateMetricMilestones(self,run,"craft_count","client_event",detail,key)
    run.milestoneStats.feats.craftItems[tostring(itemID)]=true
    EvaluateFeats(self,run,{"craft_variety","five_pillars"},"client_event",detail,key)
    self:RefreshUI()
end

function AF:ObserveMilestoneNewAtlasZone(mapID,zoneName,key)
    if not tonumber(mapID) then return end
    local run=self:GetExpeditionCharter()
    if not run or run.state~="active" or not key or not self:IsCharterScopedMember(key) then return end
    NormalizeRun(run)
    run.milestoneStats.atlasCount=(run.milestoneStats.atlasCount or 0)+1
    local f=run.milestoneStats.feats
    f.atlasByCharacter[key]=(tonumber(f.atlasByCharacter[key]) or 0)+1
    if type(self.GetAtlasContinent)=="function" then
        local ok,continent=pcall(self.GetAtlasContinent,self,mapID)
        if ok and type(continent)=="number" and continent>0 then f.continents[tostring(continent)]=true end
    end
    local detail="New Atlas region #"..tostring(run.milestoneStats.atlasCount)..": "..SafeText(zoneName or "Unknown").." (map #"..tostring(mapID)..")."
    EvaluateMetricMilestones(self,run,"atlas_count","local_record",detail,key)
    EvaluateFeats(self,run,{"continent_variety","character_atlas_max","atlas_continent_combo","five_pillars"},"local_record",detail,key)
    self:RefreshUI()
end

function AF:ObserveMilestoneQuestTurnIn(questID)
    local run=self:GetExpeditionCharter()
    local key=self:GetCurrentKey()
    if not run or run.state~="active" or not key or not self:IsCharterScopedMember(key) then return end
    NormalizeRun(run)
    run.milestoneStats.questCount=(run.milestoneStats.questCount or 0)+1
    local f=run.milestoneStats.feats
    local id=tonumber(questID)
    if id and id>0 and id==math.floor(id) then f.questIDs[tostring(id)]=true end
    local day=type(date)=="function" and date("%Y-%m-%d",Now()) or tostring(math.floor(Now()/86400))
    if type(day)=="string" then f.questDays[day]=(tonumber(f.questDays[day]) or 0)+1 end
    f.questByCharacter[key]=(tonumber(f.questByCharacter[key]) or 0)+1
    if type(self.GetAtlasZone)=="function" and type(self.GetAtlasCurrentMap)=="function" then
        local ok,current=pcall(self.GetAtlasCurrentMap,self)
        if ok and current then
            local valid,zone=pcall(self.GetAtlasZone,self,current)
            if valid and type(zone)=="number" and zone>0 then f.questZones[tostring(zone)]=true end
        end
    end
    local detail="Observed quest turn-in #"..tostring(run.milestoneStats.questCount).." for quest #"..tostring(id or 0).." during the active charter."
    EvaluateMetricMilestones(self,run,"quest_count","local_record",detail,key)
    EvaluateFeats(self,run,{"quest_variety","quest_daily_max","quest_days","quest_zone_variety","quest_character_max","five_pillars"},"local_record",detail,key)
    self:RefreshUI()
end

function AF:ObserveMilestoneLevel(level,key)
    key=key or self:GetCurrentKey()
    level=tonumber(level)
    local run=self:GetExpeditionCharter()
    if not level or not run or run.state~="active" or not key or not self:IsCharterScopedMember(key) then return end
    NormalizeRun(run)
    local seen=run.milestoneStats.levelSeen
    local prev=tonumber(seen[key])
    if not prev then
        seen[key]=level
        return -- establish baseline; never backfill earlier levels
    end
    if level<=prev then return end
    seen[key]=level
    if level>(run.milestoneStats.levelMax or 0) then run.milestoneStats.levelMax=level end
    local char=self.db and self.db.characters and self.db.characters[key]
    local who=char and char.name or "An enrolled adventurer"
    EvaluateMetricMilestones(self,run,"level_threshold","local_record",
        SafeText(who).." reached level "..tostring(level).." during the active charter.",key)
    self:RefreshUI()
end

function AF:ObserveMilestoneProfessionProgress(key)
    key=key or self:GetCurrentKey()
    local run=self:GetExpeditionCharter()
    if not run or run.state~="active" or not key or not self:IsCharterScopedMember(key) then return end
    local char=self.db and self.db.characters and self.db.characters[key]
    if not char or type(char.professions)~="table" then return end
    local bestSkill,bestName=0,nil
    for name,prof in pairs(char.professions or {}) do
        local skill=tonumber(type(prof)=="table" and prof.skill)
        if skill and skill>bestSkill then bestSkill=skill;bestName=name end
    end
    if bestSkill<=0 then return end
    NormalizeRun(run)
    local seen=run.milestoneStats.professionSeen
    local prev=tonumber(seen[key])
    if not prev then
        seen[key]=bestSkill
        return -- baseline only; never backfill earlier skill
    end
    if bestSkill<=prev then return end
    seen[key]=bestSkill
    if bestSkill>(run.milestoneStats.professionMax or 0) then run.milestoneStats.professionMax=bestSkill end
    local who=char.name or "An enrolled adventurer"
    EvaluateMetricMilestones(self,run,"profession_skill","local_record",
        SafeText(who).." raised "..SafeText(bestName or "a profession").." to skill "..tostring(bestSkill).." during the active charter.",key)
    self:RefreshUI()
end

-- Independent, per-profession baseline: tracks breadth without treating an old
-- character snapshot as a newly achieved skill rank. Only fresh skill growth
-- observed after a baseline may satisfy rank and discipline feats.
function AF:ObserveMilestoneProfessionFeats(key)
    key=key or self:GetCurrentKey()
    local run=self:GetExpeditionCharter()
    if not run or run.state~="active" or not key or not self:IsCharterScopedMember(key) then return end
    local char=self.db and self.db.characters and self.db.characters[key]
    if not char or type(char.professions)~="table" then return end
    NormalizeRun(run)
    local f=run.milestoneStats.feats
    local changed=false
    for name,prof in pairs(char.professions) do
        if type(name)=="string" and type(prof)=="table" then
            local skill=tonumber(prof.skill)
            if skill and skill>=0 and skill<=300 then
                local id=key.."|"..name
                local previous=tonumber(f.professionRanks[id])
                -- A separate baseline table is needed: the first observation
                -- is informational only, not an award.
                f.professionBaselines=type(f.professionBaselines)=="table" and f.professionBaselines or {}
                local baseline=tonumber(f.professionBaselines[id])
                if not baseline then
                    f.professionBaselines[id]=skill
                    f.professionRanks[id]=0
                elseif skill>math.max(tonumber(f.professionRanks[id]) or baseline,baseline) then
                    f.professionRanks[id]=skill
                    f.professionIncreases[id]=true
                    changed=true
                end
            end
        end
    end
    if changed then
        EvaluateFeats(self,run,{"profession_breadth","profession_225","profession_300","five_pillars"},"local_record",
            "New advancement in a registered profession, observed since this charter's baseline.",key)
        self:RefreshUI()
    end
end

-- Instance observation is read-only and fail-closed. A visit is never a
-- dungeon clear; a boss milestone requires success=1 from ENCOUNTER_END or
-- a matching BOSS_KILL notification, with duplicate suppression.
local function CurrentInstance()
    if type(GetInstanceInfo)~="function" then return nil end
    local ok,name,kind,id=pcall(function()
        local instanceName,instanceType,_,_,_,_,_,instanceID=GetInstanceInfo()
        return instanceName,instanceType,tonumber(instanceID)
    end)
    if not ok or (kind~="party" and kind~="raid") or type(name)~="string" or name=="" then return nil end
    if not id or id<=0 then return nil end
    return name,kind,tostring(id)
end
function AF:ObserveMilestoneInstance()
    local run=self:GetExpeditionCharter()
    local key=self.GetCurrentKey and self:GetCurrentKey()
    if not run or run.state~="active" or not key or not self:IsCharterScopedMember(key) then return end
    local name,kind,id=CurrentInstance()
    if not name or kind~="party" then return end
    NormalizeRun(run)
    local f=run.milestoneStats.feats
    if f.dungeons[id] then return end
    f.dungeons[id]=true
    EvaluateFeats(self,run,{"dungeon_variety"},"local_record","Observed an enrolled adventurer inside dungeon "..SafeText(name)..".",key)
    self:RefreshUI()
end
function AF:ObserveMilestoneBossEvent(event,encounterID,encounterName,success)
    local run=self:GetExpeditionCharter()
    local key=self.GetCurrentKey and self:GetCurrentKey()
    if not run or run.state~="active" or not key or not self:IsCharterScopedMember(key) then return end
    local safe,validID,validSuccess,validName=pcall(function()
        local id=tonumber(encounterID)
        local good=event=="BOSS_KILL" or success==1
        local n=type(encounterName)=="string" and encounterName or "Encounter"
        return id,good,n
    end)
    if not safe or not validID or validID<=0 or not validSuccess then return end
    local instanceName,kind,instanceID=CurrentInstance()
    if not instanceName then return end
    NormalizeRun(run)
    local f=run.milestoneStats.feats
    local now=Now()
    local token=kind..":"..instanceID..":"..tostring(validID)
    f.recentBossEvents=type(f.recentBossEvents)=="table" and f.recentBossEvents or {}
    if now-(tonumber(f.recentBossEvents[token]) or -10000)<18 then return end
    f.recentBossEvents[token]=now
    local detail="Successful "..(kind=="raid" and "raid" or "dungeon").." boss encounter: "..SafeText(validName).." in "..SafeText(instanceName).."."
    local metrics={"all_boss_kills","five_pillars"}
    if kind=="party" then
        f.dungeonBossKills=f.dungeonBossKills+1
        f.dungeonBossInstances[instanceID]=true
        f.bossIDsByDungeon[instanceID]=f.bossIDsByDungeon[instanceID] or {}
        f.bossIDsByDungeon[instanceID][tostring(validID)]=true
        metrics[#metrics+1]="dungeon_boss_kills"
        metrics[#metrics+1]="dungeon_boss_instance_variety"
        metrics[#metrics+1]="dungeon_boss_same_instance_max"
    else
        f.raidBossKills=f.raidBossKills+1
        f.raidBossInstances[instanceID]=true
        metrics[#metrics+1]="raid_boss_kills"
        metrics[#metrics+1]="raid_boss_instance_variety"
    end
    EvaluateFeats(self,run,metrics,"client_event",detail,key)
    self:RefreshUI()
end

-- v0.6.4.2: Forever gather observation; do not infer unrestricted ownership.
-- A single spellcast event isn't enough: observe a relevant cast (start or success)
-- AND a loot-ready/open/cleared notification, or read a known herb/ore item
-- linked to a GameObject loot source. No protected action or combat log access.
local GATHER_SPELL_IDS={
    [2366]="first_herb", [2368]="first_herb", [3570]="first_herb", [11993]="first_herb", [28695]="first_herb",
    -- Forever has additional on-node cast spells, separate from the skillbook ranks.
    -- 1272073 is a Forever server-scripted mining interaction with a forced castbar.
    -- 1235230 is a separate mining interaction; neither should award without loot.
    [2575]="first_ore", [2576]="first_ore", [2577]="first_ore", [2578]="first_ore", [2579]="first_ore",
    [3564]="first_ore", [10248]="first_ore", [29354]="first_ore",
    [1235230]="first_ore", [1272073]="first_ore",
    -- Retail development-client fallback. Not used for Forever leveling rules.
    [265837]="first_ore",
    [8613]="first_skinning", [8617]="first_skinning", [8618]="first_skinning", [10768]="first_skinning", [32678]="first_skinning",
    [7620]="first_fish", [7731]="first_fish", [7732]="first_fish", [18248]="first_fish", [33095]="first_fish",
}
local HERB_ITEMS={
    [765]=true,[785]=true,[2447]=true,[2449]=true,[2450]=true,[2452]=true,[2453]=true,
    [3355]=true,[3356]=true,[3357]=true,[3358]=true,[3369]=true,[3818]=true,[3819]=true,[3820]=true,[3821]=true,
    [4625]=true,[8831]=true,[8836]=true,[8838]=true,[8839]=true,[8845]=true,[8846]=true,
    [13463]=true,[13464]=true,[13465]=true,[13466]=true,[13467]=true,[13468]=true,
}
local ORE_ITEMS={
    [2770]=true,[2771]=true,[2772]=true,[2775]=true,[2776]=true,[3858]=true,
    [7911]=true,[10620]=true,[11370]=true,[22203]=true,
}
local function Clock()
    if type(GetTime)=="function" then
        local ok,n=pcall(GetTime)
        if ok and type(n)=="number" then return n end
    end
    return Now()
end
local function IsActiveScoped(self,key)
    local charter=self:GetExpeditionCharter()
    return charter and charter.state=="active" and key and self:IsCharterScopedMember(key)
end
local function Clean(value)
    if type(value)=="string" then
        local ok,v=pcall(function()return value:gsub("[%c]"," "):sub(1,90) end)
        if ok then return v end
    end
    return "unknown"
end
local function Diagnostic(self,event,description)
    local d=self._gatherDiagnostics
    if type(d)~="table" then
        d={enabled=false,counts={},history={}}
        self._gatherDiagnostics=d
    end
    event=tostring(event or "unknown")
    d.counts[event]=(d.counts[event] or 0)+1
    local line=event.." | "..Clean(description)
    d.last=line
    d.history[#d.history+1]=line
    while #d.history>12 do table.remove(d.history,1) end
    if d.enabled and self.Print then self.Print("Gather: "..line) end
end
function AF:SetMilestoneGatherDebug(enabled)
    local d=self._gatherDiagnostics or {enabled=false,counts={},history={}}
    self._gatherDiagnostics=d
    d.enabled=enabled==true
    if self.Print then self.Print("Gather diagnostics "..(d.enabled and "ON" or "OFF").."; /af gatherstatus shows recent events.") end
end
function AF:PrintMilestoneGatherStatus()
    local d=self._gatherDiagnostics or {counts={},history={}}
    local c=d.counts or {}
    local names={"cast_start","cast_success","cast_unmatched","loot_ready","loot_opened","loot_cleared","loot_wait","loot_unreadable","loot_gameobject","award","registration_failed"}
    local parts={}
    for _,name in ipairs(names) do parts[#parts+1]=name.."="..tostring(c[name] or 0) end
    if self.Print then
        self.Print("Gather observer: "..table.concat(parts," "))
        local run=self:GetExpeditionCharter()
        local scoped=IsActiveScoped(self,self:GetCurrentKey())
        self.Print("Charter "..tostring(run and run.state or "none").."; current adventurer enrolled="..tostring(scoped==true))
        if run then
            local function awardState(id)
                return self:GetExpeditionMilestoneAward(run,id) and "RECORDED" or "PENDING"
            end
            self.Print("Milestone status: Mining/Strike the Vein="..awardState("first_ore")
                .."; Herbalism/Green Thumb="..awardState("first_herb")
                .."; First Harvest="..awardState("first_harvest"))
        end
        local statuses={}
        for _,registration in ipairs(self._milestoneGatherRegistrations or {}) do
            statuses[#statuses+1]=registration.name.."="..(registration.ok and "ON" or "UNAVAILABLE")
            if not registration.ok then
                self.Print("Gather event unavailable: "..registration.name.." ("..Clean(registration.error)..")")
            end
        end
        self.Print("Event registrations: "..table.concat(statuses," "))
        self.Print("Last recognized gather cast: "..tostring(d.lastRecognized or "none"))
        local candidate=self._milestoneGatherCandidate
        if candidate then
            self.Print("Pending gather candidate: "..tostring(candidate.id).." #"..tostring(candidate.spellID or "?").." stage="..tostring(candidate.stage))
        end
        for _,line in ipairs(d.history or {}) do self.Print("Gather > "..line) end
    end
end
function AF:MilestoneGatherRegistration(event,ok,err)
    if not ok then Diagnostic(self,"registration_failed",event..": "..Clean(err)) end
end
local function GatherKind(spellID,name)
    local num=type(spellID)=="number" and spellID or tonumber(spellID)
    if num==13262 then return "first_disenchant" end
    local lower=type(name)=="string" and name:lower() or ""
    if lower=="disenchant" or lower=="disenchanting" then return "first_disenchant" end
    local known=num and GATHER_SPELL_IDS[num]
    if known then return known end
    -- Node cast IDs and localized profession spell IDs may differ from the
    -- skill-book IDs. Name recognition is deliberately limited to gathering.
    if lower=="herbalism" or lower=="herb gathering" or lower=="gather herbs" then return "first_herb" end
    if lower=="mining" or lower=="mine" or lower=="classic mining" then return "first_ore" end
    if lower=="skinning" or lower=="skin" then return "first_skinning" end
    if lower=="fishing" then return "first_fish" end
end
local function SpellName(spellID)
    if type(spellID)~="number" then return nil end
    if type(C_Spell)=="table" and type(C_Spell.GetSpellInfo)=="function" then
        local ok,info=pcall(C_Spell.GetSpellInfo,spellID)
        if ok and type(info)=="table" then
            local success,name=pcall(function()return info.name end)
            if success and type(name)=="string" then return name end
        end
    end
    if type(GetSpellInfo)=="function" then
        local ok,name=pcall(GetSpellInfo,spellID)
        if ok and type(name)=="string" then return name end
    end
end
local function DecodeSpellArgs(a,b,c,d)
    -- Current client: player, castGUID, spellID. Keep a guarded fallback for
    -- clients that pass a spell name earlier and spellID in a later argument.
    local id=nil
    for _,value in ipairs({c or false,d or false}) do
        if type(value)=="number" then id=value;break end
    end
    local label=nil
    if type(b)=="string" and not b:find("^Cast%-") then
        if #b<60 then label=b end
    end
    if not label and type(c)=="string" and #c<60 then label=c end
    if not label and id then label=SpellName(id) end
    -- Some Forever interactions expose a forced castbar while their spell ID
    -- is absent from the regular spellbook. The displayed spell name may be
    -- available via UnitCastingInfo even when C_Spell does not return it.
    if not label and type(UnitCastingInfo)=="function" then
        local ok,name=pcall(UnitCastingInfo,"player")
        if ok and type(name)=="string" and #name<60 then label=name end
    end
    return id,label
end
function AF:ObserveMilestoneGatherCast(stage,unit,castGUID,spellID,extra)
    if unit~="player" then return end
    local key=self:GetCurrentKey()
    if not IsActiveScoped(self,key) then return end
    local ok,id,name=pcall(DecodeSpellArgs,unit,castGUID,spellID,extra)
    if not ok then Diagnostic(self,"cast_unmatched","Unreadable spellcast data");return end
    local safeKind,kind=pcall(GatherKind,id,name)
    if not safeKind or not kind then
        -- Diagnostic mode logs only candidate spell casts as a count, rather
        -- than exposing every spell or flooding chat during ordinary combat.
        if (self._gatherDiagnostics or {}).enabled then Diagnostic(self,"cast_unmatched",tostring(id).." "..Clean(name)) end
        return
    end
    if kind=="first_disenchant" then
        if stage=="success" then
            self:RecordExpeditionMilestone(kind,"client_event",
                "Enrolled adventurer completed a Disenchant spellcast. Materials received are unverified.",key)
        end
        return
    end
    local prior=self._milestoneGatherCandidate
    if prior and prior.id==kind and prior.key==key and Clock()-(prior.at or 0)<15 then
        prior.stage=stage=="success" and "success" or prior.stage
        prior.spellID=id or prior.spellID
        prior.name=name or prior.name
    else
        self._milestoneGatherCandidate={id=kind,key=key,at=Clock(),stage=stage,spellID=id,name=name or "Gathering"}
    end
    local d=self._gatherDiagnostics or {enabled=false,counts={},history={}}
    d.lastRecognized=kind.." spell="..tostring(id or "?").." name="..Clean(name or "(no name)")
    self._gatherDiagnostics=d
    Diagnostic(self,stage=="success" and "cast_success" or "cast_start",(name or "gathering").." #"..tostring(id or "?"))
end
-- Retained public entry point for tools and old callers.
function AF:ObserveMilestoneGatherSpell(unit,castGUID,spellID,extra)
    self:ObserveMilestoneGatherCast("success",unit,castGUID,spellID,extra)
end

local function LootObservations()
    if type(GetNumLootItems)~="function" then return nil,nil,nil end
    local ok,count=pcall(GetNumLootItems)
    if not ok or type(count)~="number" then return nil,nil,nil end
    count=math.max(0,math.min(60,math.floor(count)))
    local found,objectFound,creatureFound=nil,false,false
    for i=1,count do
        local gameObject=false
        if type(GetLootSourceInfo)=="function" then
            -- Multiple loot sources are returned as (GUID, quantity) pairs;
            -- the first source alone may not be the relevant GameObject.
            local sources={pcall(GetLootSourceInfo,i)}
            if table.remove(sources,1) then
                for j=1,#sources,2 do
                    local guid=sources[j]
                    if type(guid)=="string" then
                        local valid,match=pcall(function()return guid:find("^GameObject%-")~=nil end)
                        if valid and match then gameObject=true;objectFound=true end
                        local creatureOk,creature=pcall(function()return guid:find("^Creature%-")~=nil end)
                        if creatureOk and creature then creatureFound=true end
                    end
                end
            end
        end
        if gameObject then
            local itemID
            if type(GetLootSlotLink)=="function" then
                local success,link=pcall(GetLootSlotLink,i)
                if success and type(link)=="string" then
                    local valid,n=pcall(function() return tonumber(link:match("item:(%d+)")) end)
                    if valid then itemID=n end
                end
            end
            if itemID and HERB_ITEMS[itemID] then found="first_herb" end
            if itemID and ORE_ITEMS[itemID] then found="first_ore" end
            -- GameObject + ore-like item names covers Forever's new ores that
            -- are not in the classic known-ID list. Never do this for mob loot.
            if not found and type(GetLootSlotInfo)=="function" then
                local success,_,itemName=pcall(GetLootSlotInfo,i)
                if success and type(itemName)=="string" then
                    local lower=itemName:lower()
                    if lower:match(" ore$") or lower:match(" ore ") then found="first_ore" end
                end
            end
        end
    end
    return count,found,objectFound,creatureFound
end
-- Some client builds auto-loot before the loot slot is readable by addons.
-- An observed mining cast and a subsequent personal ore loot chat message
-- are enough to record an interaction, but not to certify item provenance.
function AF:ObserveMilestoneGatherChatLoot(message)
    if type(message)~="string" then return end
    local candidate=self._milestoneGatherCandidate
    if not candidate or candidate.id~="first_ore" then return end
    local key=self:GetCurrentKey()
    local age=Clock()-(candidate.at or 0)
    if not IsActiveScoped(self,key) or candidate.key~=key or age<0 or age>18 then return end
    local id=tonumber(message:match("item:(%d+)"))
    if not (id and ORE_ITEMS[id]) then return end
    -- A chat loot event can also cover a rapid auto-loot path where
    -- LOOT_READY/LOOT_OPENED already lost item-slot data.
    self._milestoneGatherCandidate=nil
    local detail="Observed Mining cast followed by ore loot chat entry (item #"..tostring(id).."). Receipt is locally observed; self-found provenance is not certified."
    local awarded=self:RecordExpeditionMilestone("first_ore","local_record",detail,key)
    if awarded then
        Diagnostic(self,"award","first_ore (cast plus chat loot)")
        self:RecordExpeditionMilestone("first_harvest","local_record","First Harvest observed through Mining. "..detail,key)
    end
end

local function AwardHarvest(self,kind,key,detail)
    local awarded=self:RecordExpeditionMilestone(kind,"local_record",detail,key)
    if (kind=="first_ore" or kind=="first_herb") and awarded then
        self:RecordExpeditionMilestone("first_harvest","local_record",
            "First Harvest observed through "..(kind=="first_herb" and "Herbalism" or "Mining")..". "..detail,key)
    end
    if awarded then Diagnostic(self,"award",kind) end
end
function AF:ObserveMilestoneLootWindow(event)
    event=event or "LOOT_OPENED"
    local key=self:GetCurrentKey()
    local scoped=IsActiveScoped(self,key)
    local candidate=self._milestoneGatherCandidate
    local ckind=candidate and candidate.id
    local age=candidate and (Clock()-(candidate.at or 0)) or 999
    local validCandidate=scoped and candidate and candidate.key==key and age>=0 and age<=(ckind=="first_fish" and 45 or 14)
    local count,sourceKind,objectFound,creatureFound=LootObservations()
    Diagnostic(self,event=="LOOT_READY" and "loot_ready" or event=="LOOT_SLOT_CLEARED" and "loot_cleared" or "loot_opened",
        "slots="..tostring(count or "unavailable").." candidate="..tostring(validCandidate and ckind or "none").." object="..tostring(objectFound))
    if not scoped then return end
    if sourceKind then Diagnostic(self,"loot_gameobject",sourceKind) end
    -- LOOT_READY can precede LOOT_OPENED or auto-loot can clear the slot before
    -- OPENED. The two notifications must never create duplicate awards.
    -- Corpse loot is not a herb or ore node even when a gathering cast
    -- happened nearby; skinning is explicitly allowed on creature sources.
    local sourceMatches=not creatureFound or ckind=="first_skinning" or objectFound
    if validCandidate and sourceMatches and ((count and count>0) or event=="LOOT_SLOT_CLEARED") then
        self._milestoneGatherCandidate=nil
        local evidence="Observed "..Clean(candidate.name).." gathering cast ("..tostring(candidate.stage)..") followed by "..event..
            "; loot slots="..tostring(count or "unavailable")..". Receipt and provenance not certified."
        AwardHarvest(self,ckind,key,evidence)
    elseif sourceKind and (count or 0)>0 then
        -- A GameObject loot source containing a known herb or ore can be
        -- observed even if Forever does not expose the corresponding cast.
        AwardHarvest(self,sourceKind,key,"Observed GameObject loot source containing known "..
            (sourceKind=="first_herb" and "herbalism" or "mining").." material; no spellcast matched. Item receipt not independently verified.")
    elseif validCandidate then
        Diagnostic(self,"loot_wait",creatureFound and not sourceMatches and "Creature loot was not a mining/herb node" or
            "Loot notification arrived without readable slots; waiting for another loot event")
    elseif count==nil then
        Diagnostic(self,"loot_unreadable","Loot source API unavailable or restricted")
    end
end
