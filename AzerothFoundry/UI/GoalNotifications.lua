-- Azeroth Foundry v0.3.6: resizable, scrollable unlimited world tracker and toast.
-- No external textures or networking. The demo toast has ZERO persistence effects.
local _, AF = ...
local UI=AF.UI
local function Settings() return AF.db and AF.db.settings and AF.db.settings.guided end
local function Decor(frame,r,g,b,a)
    local t=frame:CreateTexture(nil,'BACKGROUND');t:SetAllPoints(frame)
    t:SetColorTexture(r,g,b,a);return t
end

function UI:EnsureGoalToast()
    if self.goalToast then return self.goalToast end
    local f=CreateFrame('Frame','AzerothFoundryMilestoneToast',UIParent)
    f:SetFrameStrata('HIGH');f:SetSize(340,72)
    f:SetPoint('TOP',UIParent,'TOP',0,-155)
    f:EnableMouse(false)
    Decor(f,0.10,0.075,0.045,0.83)
    local stripe=f:CreateTexture(nil,'ARTWORK');stripe:SetColorTexture(0.77,0.59,0.30,0.95)
    stripe:SetPoint('TOPLEFT',2,-2);stripe:SetPoint('BOTTOMLEFT',2,2);stripe:SetWidth(4)
    local title=self:Text(f,'small',{1,0.79,0.39,1})
    title:SetPoint('TOPLEFT',15,-8);title:SetPoint('TOPRIGHT',-13,-8);title:SetHeight(22)
    local text=self:Text(f,'small',{0.99,0.94,0.82,1})
    text:SetPoint('TOPLEFT',15,-32);text:SetPoint('TOPRIGHT',-15,-32);text:SetHeight(32)
    f.title=title;f.message=text;f.elapsed=0;f:Hide()
    f:SetScript('OnUpdate',function(self,delta)
        self.elapsed=self.elapsed+delta
        local t=self.elapsed
        local alpha=t<0.30 and t/0.30 or (t<3.8 and 1 or (t<4.35 and (4.35-t)/0.55 or 0))
        self:SetAlpha(math.max(0,math.min(1,alpha)))
        if t>=4.35 then self:Hide() end
    end)
    self.goalToast=f
    return f
end

function UI:ShowGoalToast(title,message)
    local f=self:EnsureGoalToast()
    f.title:SetText(title or 'Azeroth Foundry')
    f.message:SetText(message or '')
    f.elapsed=0;f:SetAlpha(0);f:Show()
end

function UI:TestGoalToast(kind)
    -- Pure presentation preview; does NOT call SyncGuidedGoals, toggle tasks,
    -- append history, advance crafting, or write SavedVariables.
    if kind=='complete' then
        self:ShowGoalToast('Goal Complete! [TEST]', 'Preview only — no goal progress changed.')
    else
        self:ShowGoalToast('Milestone Complete! [TEST]', 'Preview only — no goal progress changed.')
    end
end

function UI:GoalMilestoneToast(project,milestone)
    local s=Settings()
    if s and s.notifications==false then return end
    self:ShowGoalToast('Goal Milestone Complete!',
        (project.title or 'Guided Goal')..' — '..(milestone.text or 'Milestone complete'))
end

-- Tracker lists as many pinned goals as the account has.  The size and
-- position are stored locally; a scroll thumb appears only for overflow.
local ROW_HEIGHT=62
local function Clamp(n,lo,hi) return math.max(lo,math.min(hi,n)) end

function UI:InitializeGoalTracker()
    if self.goalTracker or not Settings() then return end
    local s=Settings()
    local f=CreateFrame('Frame','AzerothFoundryGoalTracker',UIParent)
    f:SetFrameStrata('MEDIUM')
    f:SetMovable(true);f:SetClampedToScreen(true);f:SetResizable(true)
    f:EnableMouse(true)
    if f.SetResizeBounds then f:SetResizeBounds(240,125,720,650)
    elseif f.SetMinResize then f:SetMinResize(240,125); if f.SetMaxResize then f:SetMaxResize(720,650) end end
    f:SetSize(s.trackerWidth or 320,s.collapsed and 28 or (s.trackerHeight or 195))
    f:SetPoint('CENTER',UIParent,'CENTER',tonumber(s.trackerX) or 370,tonumber(s.trackerY) or 115)
    self.goalTracker=f
    Decor(f,0.09,0.075,0.050,0.72)

    local header=CreateFrame('Button',nil,f)
    header:SetPoint('TOPLEFT',0,0);header:SetPoint('TOPRIGHT',0,0);header:SetHeight(28)
    header:EnableMouse(true);header:RegisterForDrag('LeftButton')
    header:SetScript('OnDragStart',function() f:StartMoving() end)
    header:SetScript('OnDragStop',function()
        f:StopMovingOrSizing()
        local x,y=f:GetCenter();local px,py=UIParent:GetCenter()
        if x and y and px and py then
            s.trackerX=math.floor(x-px+0.5);s.trackerY=math.floor(y-py+0.5)
        end
    end)
    header:SetScript('OnClick',function()
        s.collapsed=not s.collapsed
        if not s.collapsed then s.attention=false end
        UI:RefreshGoalTracker()
    end)
    local label=self:Text(header,'small',{1,0.81,0.50,1})
    label:SetPoint('LEFT',10,0);label:SetPoint('RIGHT',-54,0);label:SetHeight(24)
    label:SetText('Azeroth Foundry • Tracked Goals')
    local arrow=self:Text(header,'small',{1,0.85,0.58,1},'CENTER')
    arrow:SetPoint('RIGHT',-10,0);arrow:SetSize(16,22)
    local attention=self:Text(header,'small',{1,0.73,0.18,1},'CENTER')
    attention:SetPoint('RIGHT',-32,0);attention:SetSize(20,22)
    f.arrow=arrow;f.attention=attention

    -- ScrollFrame intentionally does not use UIPanelScrollFrameTemplate:
    -- its built-in scroll buttons would be displayed even for short lists.
    local scroll=CreateFrame('ScrollFrame',nil,f)
    scroll:SetPoint('TOPLEFT',7,-30);scroll:SetPoint('BOTTOMRIGHT',-21,8)
    local child=CreateFrame('Frame',nil,scroll)
    child:SetSize(250,1);scroll:SetScrollChild(child)
    f.scroll=scroll;f.scrollChild=child;f.rows={}
    local scrollbar=CreateFrame('Slider',nil,f)
    scrollbar:SetOrientation('VERTICAL');scrollbar:SetMinMaxValues(0,0)
    scrollbar:SetValueStep(ROW_HEIGHT/2)
    if scrollbar.SetObeyStepOnDrag then scrollbar:SetObeyStepOnDrag(false) end
    scrollbar:SetWidth(9)
    scrollbar:SetPoint('TOPRIGHT',-7,-34)
    scrollbar:SetPoint('BOTTOMRIGHT',-7,11)
    local track=scrollbar:CreateTexture(nil,'BACKGROUND');track:SetAllPoints(scrollbar)
    track:SetColorTexture(0.25,0.20,0.12,0.35)
    local thumb=scrollbar:CreateTexture(nil,'OVERLAY')
    thumb:SetColorTexture(0.78,0.58,0.29,0.85);thumb:SetSize(9,24)
    scrollbar:SetThumbTexture(thumb)
    scrollbar:SetScript('OnValueChanged',function(_,value) scroll:SetVerticalScroll(value) end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript('OnMouseWheel',function(_,delta)
        if scrollbar:IsShown() then
            scrollbar:SetValue(Clamp(scrollbar:GetValue()-delta*ROW_HEIGHT/2,0,f.maxScroll or 0))
        end
    end)
    f.scrollbar=scrollbar

    local corner=CreateFrame('Button',nil,f)
    corner:SetSize(17,17);corner:SetPoint('BOTTOMRIGHT',-1,1)
    corner:SetNormalTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
    corner:SetHighlightTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight')
    corner:SetPushedTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down')
    corner:SetAlpha(0.65)
    corner:SetScript('OnMouseDown',function(_,button)
        if button=='LeftButton' and not s.collapsed then f:StartSizing('BOTTOMRIGHT') end
    end)
    corner:SetScript('OnMouseUp',function()
        f:StopMovingOrSizing()
        s.trackerWidth=math.floor(f:GetWidth()+0.5)
        s.trackerHeight=math.floor(f:GetHeight()+0.5)
        UI:RefreshGoalTracker()
    end)
    f.corner=corner
    local empty=self:Text(child,'small',{0.92,0.86,0.72,1},'CENTER')
    empty:SetPoint('TOPLEFT',8,-5);empty:SetPoint('TOPRIGHT',-8,-5)
    empty:SetHeight(37);empty:SetText('Track any number of goals from Goals.')
    f.empty=empty
    f:SetScript('OnSizeChanged',function(frame,w,h)
        if not s.collapsed and w>=240 and h>=125 then
            s.trackerWidth=math.floor(w+0.5);s.trackerHeight=math.floor(h+0.5)
        end
        if UI.RefreshGoalTracker then UI:RefreshGoalTracker() end
    end)
    self:RefreshGoalTracker()
end

function UI:MarkTrackerAttention(projectId)
    if not Settings() or not AF:GoalIsPinned(projectId) then return end
    if Settings().collapsed then Settings().attention=true end
    self:RefreshGoalTracker()
end

function UI:RefreshGoalTracker()
    if not self.goalTracker or not Settings() then return end
    local f=self.goalTracker;local s=Settings()
    if s.trackerVisible==false then f:Hide();return end
    f:Show()
    f.arrow:SetText(s.collapsed and '>' or 'v')
    f.attention:SetText(s.attention and '!' or '')
    if s.collapsed then
        f.scroll:Hide();f.scrollbar:Hide();f.corner:Hide()
        if f:GetHeight()~=28 then f:SetHeight(28) end
        return
    end
    -- Resize back to the previous expanded height on opening.
    if math.abs(f:GetHeight()-(s.trackerHeight or 195))>1 then f:SetHeight(s.trackerHeight or 195) end
    f.scroll:Show();f.corner:Show()
    local valid={};local seen={}
    for _,id in ipairs(s.tracked or {}) do
        local p=AF:FindRecord(AF.db.projects,id)
        if p and not seen[id] then valid[#valid+1]=p;seen[id]=true end
    end
    f.empty:SetShown(#valid==0)
    for i=1,math.max(#valid,#f.rows) do
        local row=f.rows[i]
        if not row then
            row=CreateFrame('Button',nil,f.scrollChild)
            row:SetHeight(ROW_HEIGHT-4)
            row:SetPoint('TOPLEFT',3,-2-(i-1)*ROW_HEIGHT)
            row:SetPoint('TOPRIGHT',-3,-2-(i-1)*ROW_HEIGHT)
            row:RegisterForClicks('LeftButtonUp')
            local label=self:Text(row,'small',{0.97,0.92,0.78,1})
            label:SetPoint('TOPLEFT',5,-3);label:SetPoint('BOTTOMRIGHT',-5,2)
            label:SetJustifyV('TOP')
            row.label=label;f.rows[i]=row
        end
        local p=valid[i]
        if p then
            local lines={p.title or 'Untitled Goal'}
            if p.guided then
                local done,total,steps=AF:GuidedMilestoneSummary(p)
                lines[#lines+1]=done..'/'..total..' requirements met'
                if p.done then
                    lines[#lines+1]='Completed'
                else
                    local pending
                    for _,m in ipairs(steps) do
                        if m.required and m.status~='confirmed' then pending=m;break end
                    end
                    if pending then lines[#lines+1]='Next: '..pending.text end
                end
            else
                local done,total=AF:CountTasks(p)
                lines[#lines+1]=done..'/'..total..' checklist tasks'
                if p.done then lines[#lines+1]='Completed' end
            end
            row.label:SetText(table.concat(lines,'\n'))
            row:SetScript('OnClick',function()
                UI.selectedProjectId=p.id
                if AF.db and AF.db.settings and AF.db.settings.guided then
                    AF.db.settings.guided.goalsView=p.done and 'Completed' or 'Tracked'
                end
                if UI.Open then UI:Open('Goals') end
            end)
            row:Show()
        else
            row:Hide()
        end
    end
    local contentH=math.max(1,#valid*ROW_HEIGHT+6)
    local viewH=math.max(1,f.scroll:GetHeight())
    local range=math.max(0,contentH-viewH)
    f.maxScroll=range
    f.scrollChild:SetHeight(contentH)
    f.scrollChild:SetWidth(math.max(1,f.scroll:GetWidth()-3))
    if range>1 then
        f.scrollbar:Show()
        f.scrollbar:SetMinMaxValues(0,range)
        f.scrollbar:SetValue(Clamp(f.scrollbar:GetValue(),0,range))
    else
        f.scrollbar:SetValue(0);f.scrollbar:Hide()
    end
end

-- v0.6.4.4 Expedition accomplishment celebration. A standalone presentation
-- layer: never writes SavedVariables or changes the underlying milestone.
local function ExpeditionToastBorder(frame, r, g, b, alpha)
    for _,side in ipairs({'TOP','BOTTOM','LEFT','RIGHT'}) do
        local edge=frame:CreateTexture(nil,'BORDER')
        edge:SetColorTexture(r,g,b,alpha or 1)
        if side=='TOP' or side=='BOTTOM' then
            edge:SetHeight(2)
            edge:SetPoint(side..'LEFT',frame,side..'LEFT',0,0)
            edge:SetPoint(side..'RIGHT',frame,side..'RIGHT',0,0)
        else
            edge:SetWidth(2)
            edge:SetPoint('TOP'..side,frame,'TOP'..side,0,0)
            edge:SetPoint('BOTTOM'..side,frame,'BOTTOM'..side,0,0)
        end
    end
end

local function ExpeditionToastPresent(frame,entry)
    frame.icon:SetTexture(entry.icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
    frame.kicker:SetText(entry.preview and 'EXPEDITION MILESTONE - PREVIEW' or 'EXPEDITION MILESTONE EARNED')
    frame.title:SetText(entry.title or 'Milestone Complete')
    frame.message:SetText(entry.message or 'Your accomplishment was recorded.')
    frame.elapsed=0
    frame:SetAlpha(0)
    frame:SetScale(0.96)
    frame:Show()
end

function UI:EnsureExpeditionMilestoneToast()
    if self.expeditionMilestoneToast then return self.expeditionMilestoneToast end
    local f=CreateFrame('Frame','AzerothFoundryExpeditionMilestoneToast',UIParent)
    f:SetFrameStrata('HIGH')
    f:SetSize(455,102)
    f:SetPoint('TOP',UIParent,'TOP',0,-122)
    f:EnableMouse(false)
    Decor(f,0.10,0.072,0.041,0.96)
    ExpeditionToastBorder(f,0.71,0.50,0.23,0.96)
    local brassTop=f:CreateTexture(nil,'ARTWORK')
    brassTop:SetColorTexture(0.97,0.75,0.32,0.96)
    brassTop:SetPoint('TOPLEFT',f,'TOPLEFT',3,-3)
    brassTop:SetPoint('TOPRIGHT',f,'TOPRIGHT',-3,-3)
    brassTop:SetHeight(3)
    local brassSide=f:CreateTexture(nil,'ARTWORK')
    brassSide:SetColorTexture(0.91,0.63,0.28,0.95)
    brassSide:SetPoint('TOPLEFT',f,'TOPLEFT',3,-5)
    brassSide:SetPoint('BOTTOMLEFT',f,'BOTTOMLEFT',3,5)
    brassSide:SetWidth(5)

    local iconFrame=CreateFrame('Frame',nil,f)
    iconFrame:SetPoint('TOPLEFT',f,'TOPLEFT',17,-17)
    iconFrame:SetSize(60,60)
    Decor(iconFrame,0.22,0.14,0.08,0.95)
    ExpeditionToastBorder(iconFrame,0.85,0.64,0.29,0.95)
    local icon=f:CreateTexture(nil,'ARTWORK')
    icon:SetPoint('CENTER',iconFrame,'CENTER',0,0)
    icon:SetSize(52,52)

    local kicker=self:Text(f,'small',{1,0.83,0.49,1})
    kicker:SetPoint('TOPLEFT',f,'TOPLEFT',94,-13)
    kicker:SetPoint('TOPRIGHT',f,'TOPRIGHT',-14,-13)
    kicker:SetHeight(18)
    local title=self:Text(f,'title',self.palette.gold)
    title:SetPoint('TOPLEFT',f,'TOPLEFT',94,-34)
    title:SetPoint('TOPRIGHT',f,'TOPRIGHT',-13,-34)
    title:SetHeight(28)
    local message=self:Text(f,'small',{0.97,0.90,0.76,1})
    message:SetPoint('TOPLEFT',f,'TOPLEFT',94,-64)
    message:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',-12,9)
    message:SetJustifyV('TOP')

    local glow=f:CreateTexture(nil,'OVERLAY')
    glow:SetPoint('TOPLEFT',f,'TOPLEFT',9,-8)
    glow:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',-9,8)
    glow:SetColorTexture(1,0.82,0.37,0.12)
    glow:SetAlpha(0)

    f.icon=icon;f.kicker=kicker;f.title=title;f.message=message;f.glow=glow
    f.elapsed=0;f.pending={};f.overflow=0
    f:SetScript('OnUpdate',function(frame,elapsed)
        frame.elapsed=frame.elapsed+math.min(elapsed,0.25)
        local t=frame.elapsed
        local alpha=t<0.25 and t/0.25 or (t<3.85 and 1 or (t<4.5 and (4.5-t)/0.65 or 0))
        frame:SetAlpha(math.max(0,math.min(1,alpha)))
        local scale=t<0.22 and (0.96+0.06*t/0.22) or (t<0.46 and (1.02-0.02*(t-0.22)/0.24) or 1)
        frame:SetScale(scale)
        frame.glow:SetAlpha(math.max(0,0.65*(1-math.min(t/1.2,1))))
        if t>=4.5 then
            local nextEntry=table.remove(frame.pending,1)
            if nextEntry then
                ExpeditionToastPresent(frame,nextEntry)
            elseif frame.overflow>0 then
                local skipped=frame.overflow
                frame.overflow=0
                ExpeditionToastPresent(frame,{title='More Milestones Earned',
                    message=tostring(skipped)..' more accomplishments were recorded. View your Expedition Milestones for details.'})
            else
                frame:Hide()
            end
        end
    end)
    f:Hide()
    self.expeditionMilestoneToast=f
    return f
end

function UI:ShowExpeditionMilestoneToast(def,award,preview)
    if not def then return end
    local f=self:EnsureExpeditionMilestoneToast()
    local subtitle=(def.category or 'Expedition')..'  -  '..(def.short or 'Accomplishment recorded')
    local entry={icon=def.icon,title=def.title,message=subtitle,preview=preview==true}
    if f:IsShown() then
        if #f.pending<16 then f.pending[#f.pending+1]=entry
        else f.overflow=f.overflow+1 end
    else
        ExpeditionToastPresent(f,entry)
    end
end

function UI:PreviewExpeditionMilestoneToast()
    -- Preview only: no award, goal, event, progress or SavedVariables changes.
    local def=AF.GetExpeditionMilestoneDef and AF:GetExpeditionMilestoneDef('first_ore')
    if not def then
        def={title='Strike the Vein',category='Gathering',short='First mining accomplishment',
            icon='Interface\\Icons\\INV_Ore_Copper_01'}
    end
    self:ShowExpeditionMilestoneToast(def,nil,true)
end
