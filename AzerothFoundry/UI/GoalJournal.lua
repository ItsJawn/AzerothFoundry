-- v0.5.15 Unified Goal Journal.
-- UI-only replacement for BuildGoals; deliberately preserves every existing
-- project record, guided milestone, exploration goal, tracker and crafting plan.
local _, AF = ...
local UI = AF.UI
local P = UI.palette
local min, max, floor = math.min, math.max, math.floor

local STATUS = {"All", "Active", "Tracked", "Completed"}
local TYPES = {"All types", "Personal", "Crafting", "Profession", "Exploration", "Expedition"}
local PERSONAL_CATEGORIES = {'General','Adventure','Leveling','Collecting','Exploration','Crafting','Other'}
local PRIORITIES = {'Normal','High','Low'}
local function IsPersonal(p)
    return p and not (p.explorationGoal or p.workshopGoal or p.guided or p.crafting or p.expeditionMilestone)
end
local function PersonalData(p,create)
    if not IsPersonal(p) then return nil end
    if create and type(p.personal)~='table' then p.personal={} end
    return type(p.personal)=='table' and p.personal or nil
end
local function PersonalProgress(p)
    local g=PersonalData(p,false)
    local target=g and math.floor(tonumber(g.target) or 0) or 0
    local current=g and math.floor(tonumber(g.current) or 0) or 0
    target=math.max(0,target)
    current=math.max(0,math.min(current,target))
    return current,target
end
local function CycleValue(values,current)
    for i,value in ipairs(values) do
        if value==current then return values[(i % #values)+1] end
    end
    return values[1]
end
local function ValidateDueDate(value)
    value=(value or ''):match('^%s*(.-)%s*$')
    if value=='' then return '' end
    local y,m,d=value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y,m,d=tonumber(y),tonumber(m),tonumber(d)
    if not y or y<2000 or y>2100 or not m or m<1 or m>12 or not d or d<1 then return nil end
    local days={31,28,31,30,31,30,31,31,30,31,30,31}
    if m==2 and y%4==0 and (y%100~=0 or y%400==0) then days[2]=29 end
    if d>days[m] then return nil end
    return value
end
local function Btn(parent, text, callback, caution)
    return UI.WorkshopButton(parent,text,callback,caution and 'caution' or nil)
end
local function Label(parent, text, color, size)
    local t=UI:Text(parent,size or 'small',color or P.ink)
    t:SetText(text or '')
    t:SetJustifyV('MIDDLE')
    return t
end
local function Pane(parent, title)
    local box=UI:Card(parent)
    local cap=UI:SectionTitle(box,title)
    cap:SetPoint('TOPLEFT',box,'TOPLEFT',15,-9)
    cap:SetPoint('TOPRIGHT',box,'TOPRIGHT',-15,-9)
    return box,cap
end
local function Kind(p)
    if p.expeditionMilestone then return 'Expedition' end
    if p.explorationGoal then return 'Exploration' end
    if p.workshopGoal then return 'Profession' end
    if p.guided or p.crafting then return 'Crafting' end
    return 'Personal'
end
local function TimeStamp(ts)
    if type(ts)~='number' or ts<=0 then return 'Not recorded' end
    return date and date('%b %d %Y',ts) or 'Recorded'
end
local function Progress(p)
    local total,done=0,0
    if p.expeditionMilestone then return p.done and 1 or 0,1 end
    if p.explorationGoal and AF.GetExplorationGoalState then
        local info=AF:GetExplorationGoalState(p)
        if info then
            return tonumber(info.current) or 0,tonumber(info.total) or 0
        end
    elseif p.guided and AF.GuidedMilestoneSummary then
        local n,m=AF:GuidedMilestoneSummary(p)
        return tonumber(n) or 0, tonumber(m) or 0
    elseif p.workshopGoal and AF.GetWorkshopGoal then
        local g=AF:GetWorkshopGoal(p.workshopGoal.characterKey,p.workshopGoal.profession)
        if g then return tonumber(g.current) or 0,tonumber(g.target) or 0 end
    elseif p.crafting then
        -- Crafted quantity isn't inferred from current stock. Only completed
        -- goals are known finished; otherwise show verified manual checklist.
        if p.done then return 1,1 end
    end
    if IsPersonal(p) then
        local manual,goal=PersonalProgress(p)
        if goal>0 then return manual,goal end
    end
    done,total=AF:CountTasks(p)
    return done,total
end
local function Clean(s)
    s=tostring(s or ''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('\n',' ')
    return s
end
local function GoalLines(p)
    local rows={}
    local function add(key,text)
        rows[#rows+1]={key=key,label=text}
    end
    if p.expeditionMilestone then
        local e=p.expeditionMilestone
        local run=AF:GetMilestoneRun(e.runId)
        local def=AF:GetExpeditionMilestoneDef(e.id)
        local award=AF:GetExpeditionMilestoneAward(run,e.id)
        add("milestone",(def and def.title or "Expedition milestone").."  |  Run #"..tostring(e.runId or "?").."\n"..
            (award and ("Recorded "..TimeStamp(award.awardedAt).."  |  "..(award.evidence or "local_record").."\n"..(award.detail or ""))
                or "Awaiting an accomplishment record in the active charter. Not independently certified."))
    elseif p.explorationGoal then
        local e=p.explorationGoal
        local state=AF:GetExplorationGoalState(p)
        add('intro','Atlas objective: '..(e.kind=='visit' and 'Visit the recorded region' or 'Known regional quests'))
        add('scope','Scope: '..(e.scope=='all' and 'All registered characters' or AF:CharacterLabel(e.characterKey))..'\n'..(state and state.detail or 'Awaiting recorded evidence'))
        for i,m in ipairs((state and state.milestones) or {}) do
            add('e'..i,(m.status=='confirmed' and '[x] ' or '[ ] ')..(m.text or '')..'\n'..(m.detail or ''))
        end
    elseif p.guided then
        local n,total,milestones=AF:GuidedMilestoneSummary(p)
        add('intro','Guided '..(p.guided.kind=='craft' and 'crafting' or 'recipe')..' objective  |  '..n..'/'..total..' milestones')
        for i,m in ipairs(milestones or {}) do
            local mark=m.status=='confirmed' and '[x] ' or (m.status=='recorded' and '[~] ' or '[ ] ')
            add('g'..i,mark..(m.text or '')..'\n'..(m.detail or '')..(not m.required and ' (optional)' or ''))
        end
    elseif p.workshopGoal then
        local w=p.workshopGoal
        local g=AF:GetWorkshopGoal(w.characterKey,w.profession)
        add('skill','Profession: '..(w.profession or '?')..'\n'..(g and ('Recorded skill '..tostring(g.current or 0)..' / target '..tostring(g.target or '?')) or 'Linked skill goal no longer available'))
    elseif p.crafting then
        add('craft','Craft '..tostring(p.crafting.quantity or 1)..' item(s); recipe '..tostring(p.crafting.recipeID or '?'))
        add('route','Full crafting priority, allocations and routes are managed in Workshop / Crafting Queue.')
    else
        local g=PersonalData(p,false) or {}
        local current,target=PersonalProgress(p)
        add('custom','Personal objective  |  '..(g.category or 'General')..'  |  '..(g.priority or 'Normal')..' priority')
        if target>0 then add('manual','Manual progress: '..current..' / '..target..'  |  Adjust with the progress controls above.') end
        if g.dueDate and g.dueDate~='' then add('due','Target date: '..g.dueDate..'  |  Personal reminder only; no in-game notification is scheduled.') end
        local checked,total=AF:CountTasks(p)
        if total>0 then add('checklist','Checklist: '..checked..' / '..total..' steps done.') end
    end
    return rows
end
local function SummarizeQueue(p,queue)
    if not (p and p.crafting) then return '' end
    local plan=queue and queue.byId and queue.byId[p.id]
    if not plan then return 'Crafting plan not evaluated; open Workshop for details.' end
    local status=AF:CraftStatusLabel(plan.status)
    local text={'Readiness: '..status}
    if plan.reasons and plan.reasons[1] then text[#text+1]=Clean(plan.reasons[1]) end
    local missing=0
    for _,step in ipairs(plan.steps or {}) do missing=missing+(tonumber(step.missing) or 0) end
    text[#text+1]=missing>0 and ('Missing materials: '..missing) or 'No missing requirements recorded'
    text[#text+1]='Allocations are virtual; stored inventory may be stale.'
    return table.concat(text,'\n')
end

function UI:BuildGoals(page)
    local settings=AF.db.settings
    settings.goalJournal=type(settings.goalJournal)=='table' and settings.goalJournal or {}
    local pref=settings.goalJournal
    if not pref.status then pref.status=settings.guided and settings.guided.goalsView or 'Active' end
    if pref.status~='All' and pref.status~='Active' and pref.status~='Tracked' and pref.status~='Completed' then pref.status='Active' end
    if not pref.kind then pref.kind='All types' end
    if pref.kind~='All types' and pref.kind~='Personal' and pref.kind~='Crafting' and pref.kind~='Profession' and pref.kind~='Exploration' and pref.kind~='Expedition' then pref.kind='All types' end
    if pref.rosterRatio==nil then pref.rosterRatio=.35 end
    if pref.owner==nil then pref.owner='All characters' end

    local banner=CreateFrame('Frame',nil,page)
    banner:SetPoint('TOPLEFT',page,'TOPLEFT',12,-8)
    banner:SetPoint('TOPRIGHT',page,'TOPRIGHT',-12,-8)
    banner:SetHeight(40)
    local bannerBg=banner:CreateTexture(nil,'BACKGROUND')
    bannerBg:SetAllPoints(banner);bannerBg:SetColorTexture(.14,.095,.062,.96)
    local intro=Label(banner,'Goal Journal',P.gold)
    intro:SetPoint('TOPLEFT',banner,'TOPLEFT',11,-4)
    intro:SetHeight(17)
    local sub=Label(banner,'Choose an ambition, follow its steps, and keep a record of what you finish.',P.pale)
    sub:SetPoint('TOPLEFT',banner,'TOPLEFT',11,-22)
    sub:SetHeight(15)
    intro.afThemeColorManaged=true
    sub.afThemeColorManaged=true

    local function selectGoal(id)
        UI.selectedProjectId=id
        page:Refresh()
    end
    local newGoal=Btn(banner,'+ New Goal',function()
        local p=AF:AddProject()
        UI.selectedProjectId=p.id
        p.title='New Goal'
        pref.status='Active';pref.kind='All types';pref.owner='All characters'
        if page.OpenEditor then page:OpenEditor(p.id) end
        page:Refresh()
    end)
    newGoal:SetPoint('RIGHT',banner,'RIGHT',-9,0)
    newGoal:SetSize(154,25)
    local function mixColor(a,b,ratio)
        return {a[1]*(1-ratio)+b[1]*ratio,a[2]*(1-ratio)+b[2]*ratio,a[3]*(1-ratio)+b[3]*ratio,1}
    end
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(banner,function(_,t)
        local c,titleInk,subInk=UI:ThemeIntroColors(t)
        bannerBg:SetColorTexture(c[1],c[2],c[3],.98)
        intro:SetTextColor(unpack(titleInk))
        sub:SetTextColor(unpack(subInk))
    end) end

    -- The three informative counters now share the Journal header with the
    -- Create action.  There is no second summary strip taking up page space.
    -- Use compact badges rather than buttons: the actual status filters remain
    -- in the Goal Journal sidebar, and counters should not suggest a click.
    local totals={}
    local metricBadges={}
    local metricOrder={'Active','Tracked','Completed'}
    local nextTo=newGoal
    for i=#metricOrder,1,-1 do
        local name=metricOrder[i]
        local f=CreateFrame('Frame',nil,banner)
        f:SetPoint('RIGHT',nextTo,'LEFT',-6,0)
        f:SetHeight(26)
        local background=f:CreateTexture(nil,'BACKGROUND')
        background:SetAllPoints(f)
        background:SetColorTexture(.23,.15,.09,.94)
        local edge=f:CreateTexture(nil,'BORDER')
        edge:SetPoint('TOPLEFT',f,'TOPLEFT',0,0)
        edge:SetPoint('BOTTOMLEFT',f,'BOTTOMLEFT',0,0)
        edge:SetWidth(2)
        edge:SetColorTexture(.70,.47,.23,.85)
        local t=Label(f,name..'  0',P.pale)
        t:SetAllPoints(f)
        t:SetJustifyH('CENTER')
        t:SetWordWrap(false)
        t.afThemeColorManaged=true
        totals[name]=t
        metricBadges[i]=f
        if UI.RegisterThemeTarget then UI:RegisterThemeTarget(f,function(_,tokens)
            local surface=tokens.light and mixColor(tokens.paper,tokens.header,.24) or tokens.dataSurface
            background:SetColorTexture(surface[1],surface[2],surface[3],.96)
            local br=tokens.divider
            edge:SetColorTexture(br[1],br[2],br[3],.82)
            local ink=UI.ThemeReadableText and UI:ThemeReadableText(surface,tokens.light and tokens.ink or tokens.dataText) or (tokens.light and tokens.ink or tokens.dataText)
            t:SetTextColor(unpack(ink))
        end) end
        nextTo=f
    end
    -- Header descriptions and badges have distinct horizontal space.  On a
    -- narrower journal, short badge labels preserve the button and text.
    local compactBadges=false
    local function LayoutHeaderBadges()
        local w=banner:GetWidth() or 0
        if w<=0 then return end
        compactBadges=w<790
        local badgeWidth=w<790 and 58 or (w<1030 and 84 or 104)
        for _,badge in ipairs(metricBadges) do badge:SetWidth(badgeWidth) end
        newGoal:SetWidth(w<690 and 116 or (w<850 and 134 or 154))
        local buttonWidth=w<690 and 116 or (w<850 and 134 or 154)
        local textWidth=max(120,w-(buttonWidth+3*badgeWidth+4*6+32))
        intro:SetWidth(textWidth)
        sub:SetWidth(textWidth)
        sub:SetWordWrap(false)
        sub:SetText(w<790 and 'Follow your goals and milestones.'
            or 'Choose an ambition, follow its steps, and keep a record of what you finish.')
        -- A resize must not freeze the displayed counts until a future refresh.
        if type(page.goalHeaderCounts)=='table' then
            for _,name in ipairs(metricOrder) do
                local count=page.goalHeaderCounts[name] or 0
                local prefix=compactBadges and string.sub(name,1,1) or name
                totals[name]:SetText(prefix..'  '..count)
            end
        end
    end
    banner:HookScript('OnSizeChanged',LayoutHeaderBadges)
    LayoutHeaderBadges()
    local left=Pane(page,'Goal Journal')
    local right=Pane(page,'Goal Details')
    local separator=CreateFrame('Button',nil,page)
    separator:SetWidth(18)
    separator:EnableMouse(true)
    separator:RegisterForDrag('LeftButton')
    if UI.StyleResizeGrip then UI:StyleResizeGrip(separator) end
    local leftWidth=350
    local function Relayout()
        local w=page:GetWidth()
        if not w or w<500 then return end
        leftWidth=max(265,min(w-340,floor((w-32)*max(.27,min(.51,tonumber(pref.rosterRatio) or .35)))))
        left:ClearAllPoints();right:ClearAllPoints();separator:ClearAllPoints()
        left:SetPoint('TOPLEFT',page,'TOPLEFT',12,-57)
        left:SetPoint('BOTTOMLEFT',page,'BOTTOMLEFT',12,12)
        left:SetWidth(leftWidth)
        right:SetPoint('TOPLEFT',left,'TOPRIGHT',12,0)
        right:SetPoint('BOTTOMRIGHT',page,'BOTTOMRIGHT',-12,12)
        separator:SetPoint('TOPLEFT',left,'TOPRIGHT',-3,-48)
        separator:SetPoint('BOTTOMLEFT',left,'BOTTOMRIGHT',-3,42)
    end
    page:HookScript('OnSizeChanged',function() Relayout() end)
    separator:SetScript('OnDragStart',function(self)
        self:SetScript('OnUpdate',function()
            if not GetCursorPosition or not page.GetLeft then return end
            local scale=page:GetEffectiveScale() or 1
            local x=GetCursorPosition()/scale
            local origin=page:GetLeft() or 0
            local w=page:GetWidth() or 1000
            pref.rosterRatio=max(.27,min(.51,(x-origin-12)/(w-32)))
            Relayout()
        end)
    end)
    separator:SetScript('OnDragStop',function(self)self:SetScript('OnUpdate',nil);Relayout() end)
    separator:SetScript('OnHide',function(self)self:SetScript('OnUpdate',nil) end)
    Relayout()

    local filterBar=CreateFrame('Frame',nil,left)
    filterBar:SetPoint('TOPLEFT',left,'TOPLEFT',13,-47)
    filterBar:SetPoint('TOPRIGHT',left,'TOPRIGHT',-13,-47)
    filterBar:SetHeight(71)
    local statusBtns={}
    for i,status in ipairs(STATUS) do
        local btn=Btn(filterBar,status,function()pref.status=status;page:Refresh() end)
        -- Exact positions are applied in Refresh after the parent receives its width.
        statusBtns[i]=btn
    end
    filterBar:HookScript('OnSizeChanged',function(self)
        local w=self:GetWidth() or 300
        for i,b in ipairs(statusBtns) do
            local width=(w-6)/4
            b:ClearAllPoints()
            b:SetPoint('TOPLEFT',self,'TOPLEFT',(i-1)*width,0)
            b:SetSize(width-2,25)
        end
    end)
    local kindButton=Btn(filterBar,'Type: All',function()
        local n=1
        for i,v in ipairs(TYPES) do if v==pref.kind then n=i;break end end
        pref.kind=TYPES[(n % #TYPES)+1]
        if pref.kind=='Expedition' and not AF:IsModuleEnabled('selfFound') then pref.kind='All types' end
        page:Refresh()
    end)
    kindButton:SetPoint('TOPLEFT',filterBar,'TOPLEFT',0,-32)
    kindButton:SetPoint('TOPRIGHT',filterBar,'TOPRIGHT',-5,-32)
    kindButton:SetHeight(25)

    local searchCaption=Label(left,'Search goal names or notes',P.ink)
    searchCaption:SetPoint('TOPLEFT',left,'TOPLEFT',19,-111)
    searchCaption:SetPoint('TOPRIGHT',left,'TOPRIGHT',-15,-111)
    searchCaption:SetHeight(14)
    local search=UI:Input(left,140)
    search:SetPoint('TOPLEFT',left,'TOPLEFT',16,-128)
    search:SetPoint('TOPRIGHT',left,'TOPRIGHT',-16,-128)
    search:SetHeight(24)
    search:SetText(pref.query or '')
    search:SetScript('OnTextChanged',function(self,user)
        if user then pref.query=self:GetText() or '';page:Refresh() end
    end)
    local ownerButton=Btn(left,'Character: All',function()
        local options={'All characters'}
        for _,c in ipairs(AF:GetCharacters() or {}) do options[#options+1]=c.key end
        local n=1
        for i,v in ipairs(options) do if v==pref.owner then n=i;break end end
        pref.owner=options[(n % #options)+1]
        page:Refresh()
    end)
    ownerButton:SetPoint('TOPLEFT',left,'TOPLEFT',14,-164)
    ownerButton:SetPoint('TOPRIGHT',left,'TOPRIGHT',-14,-164)
    ownerButton:SetHeight(23)

    local list=UI:List(left,58)
    list:SetPoint('TOPLEFT',left,'TOPLEFT',13,-195)
    list:SetPoint('BOTTOMRIGHT',left,'BOTTOMRIGHT',-24,28)
    if UI.InsetWorkshopScrollBar then UI:InsetWorkshopScrollBar(list) end
    local listHint=Label(left,'Select an objective to inspect its recorded progress.',P.ink)
    listHint:SetPoint('BOTTOMLEFT',left,'BOTTOMLEFT',15,8)
    listHint:SetPoint('BOTTOMRIGHT',left,'BOTTOMRIGHT',-14,8)
    listHint:SetHeight(17)

    -- Goal details and progress stay in one wider panel, not an empty third column.
    local headline=Label(right,'Select a goal',P.ink,'title')
    headline:SetPoint('TOPLEFT',right,'TOPLEFT',17,-48)
    headline:SetPoint('TOPRIGHT',right,'TOPRIGHT',-20,-48)
    headline:SetHeight(31)
    local meta=Label(right,'',P.ink)
    meta:SetPoint('TOPLEFT',right,'TOPLEFT',18,-83)
    meta:SetPoint('TOPRIGHT',right,'TOPRIGHT',-18,-83)
    meta:SetHeight(20)
    local track=right:CreateTexture(nil,'ARTWORK')
    track:SetPoint('TOPLEFT',right,'TOPLEFT',17,-111)
    track:SetPoint('TOPRIGHT',right,'TOPRIGHT',-17,-111)
    track:SetHeight(9);track:SetColorTexture(.30,.22,.15,.70)
    local progressFill=right:CreateTexture(nil,'OVERLAY')
    progressFill:SetPoint('TOPLEFT',track,'TOPLEFT',1,-1)
    progressFill:SetHeight(7);progressFill:SetColorTexture(.26,.52,.34,.94)
    local progressLabel=Label(right,'',P.ink)
    progressLabel:SetPoint('TOPLEFT',right,'TOPLEFT',18,-123)
    progressLabel:SetPoint('TOPRIGHT',right,'TOPRIGHT',-130,-123)
    progressLabel:SetHeight(19)


    -- For personal targets, +/- edit the recorded manual count, not a recipe,
    -- Atlas milestone, or profession's automatically checked progression.
    local decrement=Btn(right,'- 1',function()
        local p=AF:FindRecord(AF.db.projects,UI.selectedProjectId)
        if not IsPersonal(p) then return end
        local g=PersonalData(p,true)
        local current,target=PersonalProgress(p)
        if target<1 then return end
        g.current=math.max(0,current-1);p.updated=time();page:Refresh()
    end)
    decrement:SetPoint('TOPRIGHT',right,'TOPRIGHT',-72,-124)
    decrement:SetSize(49,22)
    local increment=Btn(right,'+ 1',function()
        local p=AF:FindRecord(AF.db.projects,UI.selectedProjectId)
        if not IsPersonal(p) then return end
        local g=PersonalData(p,true)
        local current,target=PersonalProgress(p)
        if target<1 then return end
        g.current=math.min(target,current+1);p.updated=time();page:Refresh()
    end)
    increment:SetPoint('TOPRIGHT',right,'TOPRIGHT',-17,-124)
    increment:SetSize(49,22)

    local detailTitle=UI:SectionTitle(right,'Progress & Next Steps')
    detailTitle:SetPoint('TOPLEFT',right,'TOPLEFT',17,-151)
    detailTitle:SetPoint('TOPRIGHT',right,'TOPRIGHT',-17,-151)
    local steps=UI:List(right,49)
    steps:SetPoint('TOPLEFT',right,'TOPLEFT',14,-187)
    steps:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-25,248)
    if UI.InsetWorkshopScrollBar then UI:InsetWorkshopScrollBar(steps) end

    local checklistPane=CreateFrame('Frame',nil,right)
    checklistPane:SetPoint('BOTTOMLEFT',right,'BOTTOMLEFT',15,83)
    checklistPane:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-15,83)
    checklistPane:SetHeight(157)
    local rule=checklistPane:CreateTexture(nil,'BACKGROUND')
    rule:SetPoint('TOPLEFT',checklistPane,'TOPLEFT',0,0)
    rule:SetPoint('TOPRIGHT',checklistPane,'TOPRIGHT',0,0)
    rule:SetHeight(1);rule:SetColorTexture(.59,.38,.17,.52)
    local checklistTitle=Label(checklistPane,'Checklist',P.ink,'title')
    checklistTitle:SetPoint('TOPLEFT',checklistPane,'TOPLEFT',0,-5)
    checklistTitle:SetSize(230,24)
    local manageSteps=Btn(checklistPane,'Manage Steps',function()
        if page.OpenStepManager then page:OpenStepManager(UI.selectedProjectId) end
    end)
    manageSteps:SetPoint('TOPRIGHT',checklistPane,'TOPRIGHT',0,-6)
    manageSteps:SetSize(115,22)
    local addTaskInput=UI:Input(checklistPane,155)
    addTaskInput:SetPoint('TOPLEFT',checklistPane,'TOPLEFT',2,-35)
    addTaskInput:SetPoint('TOPRIGHT',checklistPane,'TOPRIGHT',-77,-35)
    addTaskInput:SetHeight(25)
    local addTask=Btn(checklistPane,'Add Step',function()
        local p=AF:FindRecord(AF.db.projects,UI.selectedProjectId)
        if not p then return end
        local t=(addTaskInput:GetText() or ''):match('^%s*(.-)%s*$')
        if t=='' then return end
        p.tasks=p.tasks or {}
        p.tasks[#p.tasks+1]={id=AF:NextID(),text=t,done=false}
        p.updated=time();addTaskInput:SetText('');page:Refresh()
    end)
    addTask:SetPoint('RIGHT',checklistPane,'RIGHT',-2,28)
    addTask:SetSize(71,25)
    addTaskInput:SetScript('OnEnterPressed',function(self)self:ClearFocus();addTask:Click() end)
    local taskList=UI:List(checklistPane,30)
    taskList:SetPoint('TOPLEFT',checklistPane,'TOPLEFT',1,-67)
    taskList:SetPoint('BOTTOMRIGHT',checklistPane,'BOTTOMRIGHT',-15,5)
    if UI.InsetWorkshopScrollBar then UI:InsetWorkshopScrollBar(taskList) end
    local craftingInfo=Label(checklistPane,'',P.ink)
    craftingInfo:SetPoint('TOPLEFT',checklistPane,'TOPLEFT',2,-36)
    craftingInfo:SetPoint('TOPRIGHT',checklistPane,'TOPRIGHT',-10,-36)
    craftingInfo:SetHeight(28)
    craftingInfo:SetJustifyV('TOP')
    craftingInfo:Hide()

    local footer=CreateFrame('Frame',nil,right)
    footer:SetPoint('BOTTOMLEFT',right,'BOTTOMLEFT',14,15)
    footer:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-14,15)
    footer:SetHeight(59)
    local edit=Btn(footer,'Edit / Notes',function() if page.OpenEditor then page:OpenEditor(UI.selectedProjectId) end end)
    local pin=Btn(footer,'Track on Screen',function()
        if not UI.selectedProjectId then return end
        local ok,msg=AF:PinGuidedGoal(UI.selectedProjectId)
        if not ok then AF.Print(msg or 'Could not track goal') end
        page:Refresh()
    end)
    local complete=Btn(footer,'Mark Complete',function()
        local p=AF:FindRecord(AF.db.projects,UI.selectedProjectId)
        if not p then return end
        if p.explorationGoal or p.expeditionMilestone then AF.Print('Recorded milestones are completed through their source records, not manually in Goals.');return end
        p.done=not p.done;p.updated=time();p.completedAt=p.done and p.updated or nil
        if AF.NormalizeCraftingQueue then AF:NormalizeCraftingQueue() end
        if AF.SyncGuidedGoals then AF:SyncGuidedGoals(false) end
        if p.done and UI.ShowGoalToast then UI:ShowGoalToast('Goal Complete!',p.title or 'Goal') end
        page:Refresh()
    end)
    local repeatGoal=Btn(footer,'Repeat Goal',function()
        local repeated,err=AF:RepeatGoal(UI.selectedProjectId)
        if not repeated then AF.Print(err or 'Could not repeat goal');return end
        UI.selectedProjectId=repeated.id
        pref.status='Active';page:Refresh()
    end)
    local related=Btn(footer,'Open Workshop',function()
        local p=AF:FindRecord(AF.db.projects,UI.selectedProjectId)
        if not p then return end
        if p.expeditionMilestone then
            UI:Switch('Self-Found')
            local charter=UI.pageViews and UI.pageViews['Self-Found']
            if charter and charter.SelectCharterTab then charter:SelectCharterTab('Milestones') end
        elseif p.explorationGoal then UI:Switch('Exploration')
        elseif p.workshopGoal then UI:Switch('Professions')
        elseif p.crafting or p.guided then UI:Switch(p.crafting and 'Crafting Queue' or 'Recipes') end
    end)
    local remove=Btn(footer,'Delete...',function()
        local p=AF:FindRecord(AF.db.projects,UI.selectedProjectId)
        if p then UI:ConfirmDelete('project',p.id,function()UI.selectedProjectId=nil;page:Refresh() end) end
    end,true)
    local buttons={edit,pin,complete,repeatGoal,related,remove}
    local function LayoutActions()
        local w=footer:GetWidth() or 550
        local gap=6
        local cols=3
        local visible={}
        for _,b in ipairs(buttons) do if b:IsShown() then visible[#visible+1]=b end end
        local width=max(92,(w-gap*(cols-1))/cols)
        for i,b in ipairs(visible) do
            b:ClearAllPoints()
            local row=floor((i-1)/cols)
            local col=(i-1)%cols
            b:SetPoint('TOPLEFT',footer,'TOPLEFT',col*(width+gap),-row*30)
            b:SetSize(width,25)
        end
    end
    footer:HookScript('OnSizeChanged',LayoutActions)
    LayoutActions()

    -- Editor is a modal rather than a permanent text-heavy third column.
    local modal=UI:NewFrame('Frame',UI.frame or UIParent,'AzerothFoundryUnifiedGoalEditor')
    modal:SetFrameStrata('FULLSCREEN_DIALOG')
    modal:SetSize(630,600)
    modal:SetPoint('CENTER',UI.frame or UIParent,'CENTER')
    UI:Background(modal,P.parchmentLight,true)
    modal:EnableMouse(true);modal:Hide()
    UI.goalEditor=modal
    if UISpecialFrames then table.insert(UISpecialFrames,'AzerothFoundryUnifiedGoalEditor') end
    local modalHeader=UI:SectionTitle(modal,'Edit Goal / Notes')
    modalHeader:SetPoint('TOPLEFT',modal,'TOPLEFT',18,-14)
    modalHeader:SetPoint('TOPRIGHT',modal,'TOPRIGHT',-50,-14)
    local close=CreateFrame('Button',nil,modal,'UIPanelCloseButton')
    close:SetPoint('TOPRIGHT',modal,'TOPRIGHT',-7,-7);close:SetSize(30,30)
    close:SetScript('OnClick',function()modal:Hide();page:Refresh() end)
    local nameLabel=Label(modal,'Goal name',P.ink)
    nameLabel:SetPoint('TOPLEFT',modal,'TOPLEFT',18,-53);nameLabel:SetSize(160,22)
    local nameEdit=UI:Input(modal,390)
    nameEdit:SetPoint('TOPLEFT',modal,'TOPLEFT',19,-77)
    nameEdit:SetPoint('TOPRIGHT',modal,'TOPRIGHT',-18,-90)
    local ownerValue=nil
    local modalOwner
    modalOwner=Btn(modal,'Assigned to: Account',function()
        local p=AF:FindRecord(AF.db.projects,UI.selectedProjectId)
        if not p then return end
        if p.explorationGoal then AF.Print('Exploration scope is fixed at creation');return end
        if p.crafting then AF.Print('Crafting plan is recipe-bound; change its owner in Workshop');return end
        ownerValue=AF:CycleOwner(ownerValue)
        modalOwner.label:SetText('Assigned to: '..AF:CharacterLabel(ownerValue))
    end)
    modalOwner:SetPoint('TOPLEFT',modal,'TOPLEFT',18,-119)
    modalOwner:SetPoint('TOPRIGHT',modal,'TOPRIGHT',-18,-119)
    modalOwner:SetHeight(27)

    -- The personal-goal builder is intentionally NOT shown on generated
    -- crafting, Atlas, or profession objectives. Their engine-owned state is
    -- kept separate from these manually editable controls.
    local personalPanel=CreateFrame('Frame',nil,modal)
    personalPanel:SetPoint('TOPLEFT',modal,'TOPLEFT',18,-158)
    personalPanel:SetPoint('TOPRIGHT',modal,'TOPRIGHT',-18,-158)
    personalPanel:SetHeight(143)
    local personalTitle=Label(personalPanel,'Personal Goal Options',P.ink,'title')
    personalTitle:SetPoint('TOPLEFT',personalPanel,'TOPLEFT',2,0)
    personalTitle:SetSize(250,22)
    local personalRule=personalPanel:CreateTexture(nil,'BORDER')
    personalRule:SetPoint('TOPLEFT',personalPanel,'TOPLEFT',0,-24)
    personalRule:SetPoint('TOPRIGHT',personalPanel,'TOPRIGHT',0,-24)
    personalRule:SetHeight(1);personalRule:SetColorTexture(.56,.35,.17,.5)
    local categoryValue='General'
    local priorityValue='Normal'
    local categoryBtn
    categoryBtn=Btn(personalPanel,'Category: General',function()
        categoryValue=CycleValue(PERSONAL_CATEGORIES,categoryValue)
        categoryBtn.label:SetText('Category: '..categoryValue)
    end)
    categoryBtn:SetPoint('TOPLEFT',personalPanel,'TOPLEFT',0,-33)
    categoryBtn:SetWidth(270);categoryBtn:SetHeight(25)
    local priorityBtn
    priorityBtn=Btn(personalPanel,'Priority: Normal',function()
        priorityValue=CycleValue(PRIORITIES,priorityValue)
        priorityBtn.label:SetText('Priority: '..priorityValue)
    end)
    priorityBtn:SetPoint('TOPLEFT',categoryBtn,'TOPRIGHT',8,0)
    priorityBtn:SetPoint('TOPRIGHT',personalPanel,'TOPRIGHT',0,-33)
    priorityBtn:SetHeight(25)
    local targetLabel=Label(personalPanel,'Target (optional)',P.ink)
    targetLabel:SetPoint('TOPLEFT',personalPanel,'TOPLEFT',2,-67)
    targetLabel:SetSize(125,18)
    local targetEdit=UI:Input(personalPanel,65)
    targetEdit:SetPoint('TOPLEFT',personalPanel,'TOPLEFT',124,-64)
    targetEdit:SetSize(76,26)
    local currentLabel=Label(personalPanel,'Progress',P.ink)
    currentLabel:SetPoint('TOPLEFT',personalPanel,'TOPLEFT',222,-67)
    currentLabel:SetSize(68,18)
    local currentEdit=UI:Input(personalPanel,64)
    currentEdit:SetPoint('TOPLEFT',personalPanel,'TOPLEFT',292,-64)
    currentEdit:SetSize(68,26)
    local dueLabel=Label(personalPanel,'Due (YYYY-MM-DD)',P.ink)
    dueLabel:SetPoint('TOPLEFT',personalPanel,'TOPLEFT',2,-108)
    dueLabel:SetSize(155,19)
    local dueEdit=UI:Input(personalPanel,110)
    dueEdit:SetPoint('TOPLEFT',personalPanel,'TOPLEFT',153,-104)
    dueEdit:SetSize(130,26)
    local dueHelp=Label(personalPanel,'Optional date; no reminders are scheduled.',P.ink)
    dueHelp:SetPoint('TOPLEFT',personalPanel,'TOPLEFT',292,-106)
    dueHelp:SetPoint('TOPRIGHT',personalPanel,'TOPRIGHT',0,-106)
    dueHelp:SetHeight(25)
    local validation=Label(modal,'',P.ink)
    validation:SetPoint('BOTTOMLEFT',modal,'BOTTOMLEFT',19,50)
    validation:SetPoint('BOTTOMRIGHT',modal,'BOTTOMRIGHT',-18,50)
    validation:SetHeight(18)
    validation:SetTextColor(0.62,0.18,0.1)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(validation,function(label,t)
        -- Error state retains semantic red, but increases brightness on dark
        -- reading surfaces instead of becoming dark red on near-black.
        if t.light or t.mode=='classic' or t.mode=='forever' then
            label:SetTextColor(.64,.18,.12,1)
        else
            label:SetTextColor(1,.49,.42,1)
        end
    end) end

    local notesLabel=Label(modal,'Personal notes and description',P.ink)
    notesLabel:SetPoint('TOPLEFT',modal,'TOPLEFT',18,-312)
    notesLabel:SetSize(310,23)
    local notes=UI:Multiline(modal)
    notes:SetPoint('TOPLEFT',modal,'TOPLEFT',18,-344)
    notes:SetPoint('BOTTOMRIGHT',modal,'BOTTOMRIGHT',-28,75)
    notes:SetScript('OnSizeChanged',function() UI:ResizeEditor(notes.edit) end)
    if notes.edit.SetTextInsets then notes.edit:SetTextInsets(8,8,7,8) end
    if GameFontNormal and GameFontNormal.GetFont and notes.edit.SetFont then
        local face=GameFontNormal:GetFont()
        if face then notes.edit:SetFont(face,13,'') end
    end
    if notes.edit.SetShadowOffset then notes.edit:SetShadowOffset(0,0) end
    local editing=false
    notes.edit:SetScript('OnTextChanged',function(self)
        UI:ResizeEditor(self)
    end)
    local function SaveGoalEditor()
        local p=AF:FindRecord(AF.db.projects,UI.selectedProjectId)
        if not p then return false end
        if IsPersonal(p) then
            local targetText=(targetEdit:GetText() or ''):match('^%s*(.-)%s*$')
            local currentText=(currentEdit:GetText() or ''):match('^%s*(.-)%s*$')
            if targetText~='' and (not targetText:match('^%d+$') or tonumber(targetText)>100000000) then
                validation:SetText('Target must be a whole number from 0 to 100,000,000.');return false
            end
            if currentText~='' and (not currentText:match('^%d+$') or tonumber(currentText)>100000000) then
                validation:SetText('Progress must be a nonnegative whole number.');return false
            end
            local target=tonumber(targetText) or 0
            local current=tonumber(currentText) or 0
            if target==0 and current>0 then
                validation:SetText('Choose a target greater than zero before recording progress.');return false
            end
            if current>target then
                validation:SetText('Progress cannot exceed the target.');return false
            end
            local due=ValidateDueDate(dueEdit:GetText())
            if due==nil then
                validation:SetText('Due date must be a valid YYYY-MM-DD date, or blank.');return false
            end
            local data=PersonalData(p,true)
            data.category=categoryValue
            data.priority=priorityValue
            data.target=target
            data.current=current
            data.dueDate=due
        end
        local changedName=(nameEdit:GetText() or ''):match('^%s*(.-)%s*$')
        if changedName~='' then p.title=changedName end
        p.owner=ownerValue
        p.description=notes.edit:GetText() or ''
        p.updated=time()
        return true
    end
    local doneEdit=Btn(modal,'Save Goal',function()
        if not SaveGoalEditor() then return end
        modal:Hide();page:Refresh()
    end)
    doneEdit:SetPoint('BOTTOMRIGHT',modal,'BOTTOMRIGHT',-18,17)
    doneEdit:SetSize(148,30)
    local cancelEdit=Btn(modal,'Cancel',function()modal:Hide();page:Refresh() end)
    cancelEdit:SetPoint('RIGHT',doneEdit,'LEFT',-8,0)
    cancelEdit:SetSize(108,30)
    function page:OpenEditor(id)
        local p=AF:FindRecord(AF.db.projects,id)
        if not p then return end
        UI.selectedProjectId=p.id
        editing=false
        ownerValue=p.owner
        local isPersonal=IsPersonal(p)
        personalPanel:SetShown(isPersonal)
        validation:SetText('')
        local data=PersonalData(p,false) or {}
        categoryValue=data.category or 'General'
        priorityValue=data.priority or 'Normal'
        categoryBtn.label:SetText('Category: '..categoryValue)
        priorityBtn.label:SetText('Priority: '..priorityValue)
        targetEdit:SetText(tostring(data.target or ''))
        currentEdit:SetText(tostring(data.current or ''))
        dueEdit:SetText(data.dueDate or '')
        notesLabel:ClearAllPoints()
        notes:ClearAllPoints()
        if isPersonal then
            notesLabel:SetPoint('TOPLEFT',modal,'TOPLEFT',18,-312)
            notes:SetPoint('TOPLEFT',modal,'TOPLEFT',18,-344)
        else
            notesLabel:SetPoint('TOPLEFT',modal,'TOPLEFT',18,-165)
            notes:SetPoint('TOPLEFT',modal,'TOPLEFT',18,-198)
        end
        notes:SetPoint('BOTTOMRIGHT',modal,'BOTTOMRIGHT',-28,75)
        modalHeader:SetText(isPersonal and 'Create / Edit Personal Goal' or 'Edit Goal / Notes')
        nameEdit:SetText(p.title or '')
        notes.edit:SetText(p.description or '')
        modalOwner.label:SetText('Assigned to: '..AF:CharacterLabel(ownerValue))
        editing=true
        UI:ResizeEditor(notes.edit)
        modal:Show();modal:Raise()
    end

    -- A separate step manager keeps the main journal uncluttered. Its actions
    -- apply only to personal steps and never mutate generated milestones.
    local stepModal=UI:NewFrame('Frame',UI.frame or UIParent,'AzerothFoundryPersonalStepsEditor')
    stepModal:SetFrameStrata('FULLSCREEN_DIALOG')
    stepModal:SetSize(510,445)
    stepModal:SetPoint('CENTER',UI.frame or UIParent,'CENTER')
    UI:Background(stepModal,P.parchmentLight,true)
    stepModal:EnableMouse(true)
    stepModal:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames,'AzerothFoundryPersonalStepsEditor') end
    local stepHeading=UI:SectionTitle(stepModal,'Manage Personal Checklist')
    stepHeading:SetPoint('TOPLEFT',stepModal,'TOPLEFT',16,-13)
    stepHeading:SetPoint('TOPRIGHT',stepModal,'TOPRIGHT',-45,-13)
    local closeStep=CreateFrame('Button',nil,stepModal,'UIPanelCloseButton')
    closeStep:SetPoint('TOPRIGHT',stepModal,'TOPRIGHT',-6,-6)
    closeStep:SetSize(30,30)
    closeStep:SetScript('OnClick',function()stepModal:Hide();page:Refresh() end)
    local managerHint=Label(stepModal,'Select a step to edit, move, or remove it.',P.ink)
    managerHint:SetPoint('TOPLEFT',stepModal,'TOPLEFT',20,-50)
    managerHint:SetPoint('TOPRIGHT',stepModal,'TOPRIGHT',-18,-50)
    managerHint:SetHeight(21)
    local managerList=UI:List(stepModal,36)
    managerList:SetPoint('TOPLEFT',stepModal,'TOPLEFT',17,-77)
    managerList:SetPoint('BOTTOMRIGHT',stepModal,'BOTTOMRIGHT',-37,152)
    if UI.InsetWorkshopScrollBar then UI:InsetWorkshopScrollBar(managerList) end
    local stepInput=UI:Input(stepModal,420)
    stepInput:SetPoint('BOTTOMLEFT',stepModal,'BOTTOMLEFT',20,110)
    stepInput:SetPoint('BOTTOMRIGHT',stepModal,'BOTTOMRIGHT',-20,110)
    stepInput:SetHeight(28)
    local chosenStep=nil
    local stepProjectId=nil
    local function CurrentPersonal()
        local p=AF:FindRecord(AF.db.projects,stepProjectId)
        return IsPersonal(p) and p or nil
    end
    local function RefreshStepManager()
        local p=CurrentPersonal()
        if not p then return end
        local rows={}
        for _,task in ipairs(p.tasks or {}) do
            rows[#rows+1]={key=task.id,label=(task.done and '[x] ' or '[ ] ')..(task.text or '')}
        end
        UI:FillList(managerList,rows,function(row)
            chosenStep=row.key
            for _,t in ipairs(p.tasks or {}) do
                if t.id==chosenStep then stepInput:SetText(t.text or '');break end
            end
            RefreshStepManager()
        end,chosenStep)
    end
    local function StepAction(fn)
        local p=CurrentPersonal()
        if not p then return end
        fn(p)
        p.updated=time()
        RefreshStepManager()
        page:Refresh()
    end
    local addOrUpdate=Btn(stepModal,'Add / Update',function()
        local text=(stepInput:GetText() or ''):match('^%s*(.-)%s*$')
        if text=='' then managerHint:SetText('Enter a step description first.');return end
        StepAction(function(p)
            local found
            for _,t in ipairs(p.tasks or {}) do
                if t.id==chosenStep then t.text=text;found=true;break end
            end
            if not found then
                p.tasks=p.tasks or {}
                p.tasks[#p.tasks+1]={id=AF:NextID(),text=text,done=false}
            end
        end)
        chosenStep=nil;stepInput:SetText('');managerHint:SetText('Step saved.')
        RefreshStepManager()
    end)
    addOrUpdate:SetPoint('BOTTOMLEFT',stepModal,'BOTTOMLEFT',20,75)
    addOrUpdate:SetSize(132,26)
    local newStep=Btn(stepModal,'New Step',function()
        chosenStep=nil;stepInput:SetText('');managerHint:SetText('Enter the new step, then choose Add / Update.')
        RefreshStepManager()
    end)
    newStep:SetPoint('LEFT',addOrUpdate,'RIGHT',7,0)
    newStep:SetSize(100,26)
    local removeStep=Btn(stepModal,'Remove',function()
        if not chosenStep then return end
        StepAction(function(p)
            for i,t in ipairs(p.tasks or {}) do
                if t.id==chosenStep then table.remove(p.tasks,i);break end
            end
        end)
        chosenStep=nil;stepInput:SetText('');managerHint:SetText('Step removed.')
        RefreshStepManager()
    end,true)
    removeStep:SetPoint('BOTTOMRIGHT',stepModal,'BOTTOMRIGHT',-20,75)
    removeStep:SetSize(90,26)
    local function MoveStep(direction)
        if not chosenStep then return end
        StepAction(function(p)
            for i,t in ipairs(p.tasks or {}) do
                if t.id==chosenStep then
                    local other=i+direction
                    if other>=1 and other<=#p.tasks then
                        p.tasks[i],p.tasks[other]=p.tasks[other],p.tasks[i]
                    end
                    break
                end
            end
        end)
    end
    local moveUp=Btn(stepModal,'Move Up',function()MoveStep(-1) end)
    moveUp:SetPoint('BOTTOMLEFT',stepModal,'BOTTOMLEFT',20,37)
    moveUp:SetSize(105,25)
    local moveDown=Btn(stepModal,'Move Down',function()MoveStep(1) end)
    moveDown:SetPoint('LEFT',moveUp,'RIGHT',7,0)
    moveDown:SetSize(105,25)
    local doneSteps=Btn(stepModal,'Done',function()stepModal:Hide();page:Refresh() end)
    doneSteps:SetPoint('BOTTOMRIGHT',stepModal,'BOTTOMRIGHT',-20,15)
    doneSteps:SetSize(108,27)
    function page:OpenStepManager(id)
        local p=AF:FindRecord(AF.db.projects,id)
        if not IsPersonal(p) then return end
        stepProjectId=id;chosenStep=nil;stepInput:SetText('')
        managerHint:SetText('Select a step to edit, move, or remove it.')
        RefreshStepManager()
        stepModal:Show();stepModal:Raise()
    end

    function page:Select(status)
        if status=='Active' or status=='Tracked' or status=='Completed' or status=='All' then
            pref.status=status
            if status~='All' then AF.db.settings.guided.goalsView=status end
        end
        self:Refresh()
    end
    function page:Refresh()
        if not AF.db or not AF.db.projects then return end
        local active,tracked,completed=0,0,0
        for _,p in ipairs(AF.db.projects) do
            if not p.expeditionMilestone or AF:IsModuleEnabled("selfFound") then
                if p.done then completed=completed+1 else active=active+1 end
                if AF:GoalIsPinned(p.id) then tracked=tracked+1 end
            end
        end
        page.goalHeaderCounts={Active=active,Tracked=tracked,Completed=completed}
        for _,name in ipairs(metricOrder) do
            local prefix=compactBadges and string.sub(name,1,1) or name
            totals[name]:SetText(prefix..'  '..page.goalHeaderCounts[name])
        end
        local totalWidth=filterBar:GetWidth() or 300
        for i,b in ipairs(statusBtns) do
            local w=(totalWidth-6)/4
            b:ClearAllPoints()
            b:SetPoint('TOPLEFT',filterBar,'TOPLEFT',(i-1)*w,0)
            b:SetSize(w-2,25)
            UI.WorkshopSetSelected(b,pref.status==STATUS[i])
        end
        if pref.kind=='Expedition' and not AF:IsModuleEnabled('selfFound') then pref.kind='All types' end
        kindButton.label:SetText('Type: '..(pref.kind or 'All types'))
        ownerButton.label:SetText('Character: '..(pref.owner=='All characters' and 'All' or AF:CharacterLabel(pref.owner)))
        local query=string.lower(pref.query or '')
        local visible={}
        for _,p in ipairs(AF:GetGoalOrderedProjects()) do
            local pinned=AF:GoalIsPinned(p.id)
            local validStatus=(pref.status=='All') or (pref.status=='Active' and not p.done) or
                (pref.status=='Completed' and p.done) or (pref.status=='Tracked' and pinned)
            local validKind=(not p.expeditionMilestone or AF:IsModuleEnabled('selfFound')) and (pref.kind=='All types' or Kind(p)==pref.kind)
            local validOwner=(pref.owner=='All characters' or p.owner==pref.owner or
                (p.explorationGoal and p.explorationGoal.characterKey==pref.owner) or
                (p.workshopGoal and p.workshopGoal.characterKey==pref.owner))
            local hay=string.lower((p.title or '')..' '..(p.description or '')..' '..Kind(p))
            if validStatus and validKind and validOwner and (query=='' or hay:find(query,1,true)) then
                visible[#visible+1]=p
            end
        end
        local selected=AF:FindRecord(visible,UI.selectedProjectId)
        if not selected then selected=visible[1];UI.selectedProjectId=selected and selected.id or nil end
        local rows={}
        for _,p in ipairs(visible) do
            local cur,cap=Progress(p)
            local state=p.done and 'Completed' or (AF:GoalIsPinned(p.id) and 'Tracked' or 'Active')
            local g=PersonalData(p,false)
            local suffix=g and (tonumber(g.target) or 0)>0 and ' progress' or ' steps'
            local result=(cap>0 and (cur..'/'..cap..suffix) or (p.done and 'Completed' or 'No recorded steps'))
            local personal=PersonalData(p,false)
            local extra=(personal and personal.priority=='High') and '  |  High priority' or ''
            rows[#rows+1]={key=p.id,label=(p.title or 'Untitled')..'\n'..Kind(p)..'  |  '..state..'  |  '..result..extra,
                icon=Kind(p)=='Crafting' and 'Interface\\Icons\\Trade_BlackSmithing' or
                    Kind(p)=='Exploration' and 'Interface\\Icons\\INV_Misc_Map_01' or
                    Kind(p)=='Expedition' and 'Interface\\Icons\\INV_Misc_Book_09' or
                    Kind(p)=='Profession' and 'Interface\\Icons\\INV_Misc_Book_09' or 'Interface\\Icons\\INV_Misc_Note_04'}
        end
        UI:FillList(list,rows,function(row)selectGoal(row.key) end,UI.selectedProjectId)
        listHint:SetText(#visible==0 and 'No matching goals. Create one or change the filters.' or (#visible..' goal(s) shown  |  Click to inspect'))
        local buttonsShow=selected~=nil
        for _,b in ipairs(buttons) do b:SetShown(buttonsShow) end
        if not selected then
            headline:SetText('Your next adventure starts here')
            meta:SetText('Create a personal goal, or make a guided objective from Workshop or Exploration.')
            progressLabel:SetText('No goals match the current filters')
            progressFill:SetWidth(1)
            UI:FillList(steps,{},function() end)
            UI:FillList(taskList,{},function() end)
            addTask:Hide();addTaskInput:Hide();taskList:Show();craftingInfo:Hide()
            increment:Hide();decrement:Hide();manageSteps:Hide()
            checklistTitle:SetText('Checklist & Notes')
            LayoutActions()
            return
        end
        headline:SetText(selected.title or 'Untitled Goal')
        local category=Kind(selected)
        local owner=selected.explorationGoal and (selected.explorationGoal.scope=='all' and 'All characters' or AF:CharacterLabel(selected.explorationGoal.characterKey)) or
            selected.workshopGoal and AF:CharacterLabel(selected.workshopGoal.characterKey) or AF:CharacterLabel(selected.owner)
        local state=selected.done and ('Completed '..TimeStamp(selected.completedAt)) or (AF:GoalIsPinned(selected.id) and 'Tracked on screen' or 'Active')
        local personal=PersonalData(selected,false)
        meta:SetText(category..'  |  '..owner..'  |  '..state)
        local d,n=Progress(selected)
        progressLabel:SetText(n>0 and ('Progress  '..d..' / '..n) or (selected.done and 'Goal completed' or 'No milestones recorded'))
        local width=track:GetWidth() or 250
        progressFill:SetWidth(max(1,(width-2)*(selected.done and 1 or (n>0 and max(0,min(1,d/n)) or 0))))
        local progressRows=GoalLines(selected)
        if selected.description and selected.description~='' then
            local short=Clean(selected.description)
            if #short>145 then short=short:sub(1,142)..'...' end
            progressRows[#progressRows+1]={key='notes',label='Notes: '..short}
        end
        local queue=(selected.crafting or selected.guided) and AF:EvaluateCraftingQueue() or nil
        if selected.crafting and queue and queue.byId and queue.byId[selected.id] then
            local plan=queue.byId[selected.id]
            local readiness='Craft readiness: '..AF:CraftStatusLabel(plan.status)
            if plan.reasons and plan.reasons[1] then readiness=readiness..'\n'..Clean(plan.reasons[1]) end
            progressRows[#progressRows+1]={key='readiness',label=readiness}
            for i,step in ipairs(plan.steps or {}) do
                progressRows[#progressRows+1]={key='ingredient-'..i,
                    icon=(AF.GetItemPresentation and AF:GetItemPresentation(step.itemID) or {}).icon,
                    label=(step.name or 'Material')..': '..tostring(step.covered or 0)..' / '..tostring(step.needed or '?')..' allocated'..
                        ((tonumber(step.missing) or 0)>0 and ('  |  Need '..step.missing) or '')}
            end
        end
        UI:FillList(steps,progressRows,function()end)
        checklistTitle:SetText(category=='Crafting' and 'Checklist & Craft Plan' or 'Personal Checklist')
        local tasks={}
        for _,t in ipairs(selected.tasks or {}) do
            local automatic=AF.GetCraftingMaterialTaskStatus and AF:GetCraftingMaterialTaskStatus(selected,t,queue and queue.byId and queue.byId[selected.id])
            if automatic then
                -- Derived reagent status is read-only. Never rewrite it as
                -- user-confirmed completion just because its row was clicked.
                tasks[#tasks+1]={key=t.id,automatic=true,label=automatic}
            else
                tasks[#tasks+1]={key=t.id,label=(t.done and '[x]  ' or '[ ]  ')..(t.text or '')}
            end
        end
        UI:FillList(taskList,tasks,function(row)
            if selected.explorationGoal or row.automatic then return end
            for _,t in ipairs(selected.tasks or {}) do
                if t.id==row.key then t.done=not t.done;selected.updated=time();break end
            end
            page:Refresh()
        end)
        manageSteps:SetShown(IsPersonal(selected))
        addTask:SetShown(not selected.explorationGoal and not selected.expeditionMilestone)
        addTaskInput:SetShown(not selected.explorationGoal and not selected.expeditionMilestone)
        taskList:SetShown(true)
        craftingInfo:SetShown(selected.explorationGoal~=nil)
        if selected.explorationGoal then
            craftingInfo:SetText('Atlas milestones update from recorded exploration; they cannot be manually checked.')
        elseif category=='Crafting' then
            local craftText=SummarizeQueue(selected,queue)
            if craftText~='' then checklistTitle:SetText('Checklist & Steps') end
        end
        pin.label:SetText(AF:GoalIsPinned(selected.id) and 'Untrack Goal' or 'Track on Screen')
        complete.label:SetText(selected.done and 'Mark Incomplete' or 'Mark Complete')
        complete:SetShown(not selected.explorationGoal and not selected.expeditionMilestone)
        repeatGoal:SetShown(selected.done and not selected.explorationGoal and not selected.expeditionMilestone)
        related:SetShown(category~='Personal')
        related.label:SetText(category=='Expedition' and 'Open Milestones' or
            category=='Exploration' and 'Open Atlas' or
            category=='Profession' and 'Open Professions' or
            (selected.crafting and 'Open Crafting Queue' or 'Open Recipes'))
        local _,target=PersonalProgress(selected)
        local showManual=IsPersonal(selected) and target>0 and not selected.done
        increment:SetShown(showManual)
        decrement:SetShown(showManual)
        progressLabel:ClearAllPoints()
        progressLabel:SetPoint('TOPLEFT',right,'TOPLEFT',18,-123)
        progressLabel:SetPoint('TOPRIGHT',right,'TOPRIGHT',showManual and -130 or -18,-123)
        progressLabel:SetHeight(19)
        LayoutActions()
    end
    page:Refresh()
end
