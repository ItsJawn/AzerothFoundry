-- Living Workshop: one navigation area for previously separate profession,
-- recipe, production queue and material-snapshot views. No new inventory claims.
local _, AF = ...
local UI = AF.UI
local P = UI.palette

local TABS = {"Professions", "Training", "Recipes", "Crafting Queue", "Materials"}

-- WoW protects CancelShapeshiftForm: it cannot be called from addon Lua.
-- We instead present a secure cancelaura action directly over each Craft
-- button only while a craft-blocking form is active. The player's click
-- leaves the form; the next normal Craft click executes CraftRecipe.
-- No macro slots, insecure /cancelform, timer casts, or automatic retry.
local function BlockingCraftFormSpell()
    if type(UnitClass)~='function' or type(GetShapeshiftForm)~='function' or
        type(GetShapeshiftFormInfo)~='function' then return nil end
    local _,class=UnitClass('player')
    -- Warrior stances and unrelated auras do not need cancelling. The
    -- families below include every druid form, Ghost Wolf, Shadowform,
    -- Stealth and Metamorphosis if exposed by the current client.
    if class~='DRUID' and class~='SHAMAN' and class~='PRIEST'
        and class~='ROGUE' and class~='WARLOCK' then return nil end
    local okIndex,index=pcall(GetShapeshiftForm)
    if not okIndex or type(index)~='number' or index<1 then return nil end
    local ok,icon,active,castable,spellID=pcall(GetShapeshiftFormInfo,index)
    if not ok or not active or not tonumber(spellID) then return nil end
    if class=='SHAMAN' and type(GetShapeshiftFormID)=='function' then
        local okID,formID=pcall(GetShapeshiftFormID)
        if okID and tonumber(formID)~=16 then return nil end
    end
    local name=nil
    if type(C_Spell)=='table' and type(C_Spell.GetSpellInfo)=='function' then
        local okSpell,info=pcall(C_Spell.GetSpellInfo,spellID)
        if okSpell and type(info)=='table' then name=info.name end
    end
    if not name and type(GetSpellInfo)=='function' then
        local okSpell,got=pcall(GetSpellInfo,spellID)
        if okSpell then name=got end
    end
    if type(name)~='string' or name=='' then return nil end
    return name
end

local function Caption(parent, name)
    local f=UI:SectionTitle(parent,name)
    f:SetPoint('TOPLEFT',14,-12);f:SetPoint('TOPRIGHT',-12,-12)
end
local function Columns(page, leftWidth, rightWidth)
    local left=UI:Card(page)
    left:SetPoint('TOPLEFT',12,-12);left:SetPoint('BOTTOMLEFT',12,12)
    left:SetWidth(leftWidth or 245)
    local right=UI:Card(page)
    right:SetPoint('TOPRIGHT',-12,-12);right:SetPoint('BOTTOMRIGHT',-12,12)
    right:SetWidth(rightWidth or 270)
    local center=UI:Card(page)
    center:SetPoint('TOPLEFT',left,'TOPRIGHT',8,0)
    center:SetPoint('BOTTOMRIGHT',right,'BOTTOMLEFT',-8,0)
    return left,center,right
end
local function Text(parent, y, h)
    local f=UI:Text(parent,'small',P.ink)
    f:SetPoint('TOPLEFT',17,-y);f:SetPoint('TOPRIGHT',-15,-y)
    f:SetHeight(h or 45);f:SetJustifyV('TOP')
    return f
end

-- Workshop v0.5.12: shared restrained native-looking layout primitives.
-- Only presentation/layout code. Underlying profession, recipe, crafting and
-- inventory scans/assignments are deliberately left in their existing engines.
local function WorkshopButton(parent,label,click,kind)
    local b=UI:Button(parent,label,click,'row')
    b.label:SetJustifyH('CENTER')
    b.label:SetTextColor(0.97,0.87,0.69)
    local backing=b:CreateTexture(nil,'BACKGROUND',nil,-1)
    backing:SetPoint('TOPLEFT',b,'TOPLEFT',1,-1)
    backing:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-1,1)
    backing:SetColorTexture(.17,.105,.064,.94)
    local borderTop=b:CreateTexture(nil,'BORDER')
    borderTop:SetPoint('TOPLEFT',b,'TOPLEFT',2,-2)
    borderTop:SetPoint('TOPRIGHT',b,'TOPRIGHT',-2,-2)
    borderTop:SetHeight(1)
    borderTop:SetColorTexture(.54,.38,.20,.74)
    local borderBottom=b:CreateTexture(nil,'BORDER')
    borderBottom:SetPoint('BOTTOMLEFT',b,'BOTTOMLEFT',2,2)
    borderBottom:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-2,2)
    borderBottom:SetHeight(1)
    borderBottom:SetColorTexture(.38,.27,.16,.66)
    local accent=b:CreateTexture(nil,'BORDER')
    accent:SetPoint('TOPLEFT',b,'TOPLEFT',1,-3)
    accent:SetPoint('BOTTOMLEFT',b,'BOTTOMLEFT',1,3)
    accent:SetWidth(3)
    accent:SetColorTexture(kind=='caution' and .76 or .52, kind=='caution' and .37 or .48, .23,.91)
    b.afWorkshopQuiet=true
    b.afThemeButtonTextRole="buttonText"
    if b.rowBase then b.rowBase:Hide() end
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(b,function(_,t)
        local c=t.buttonFace;backing:SetColorTexture(c[1],c[2],c[3],.97)
        local edge=t.divider
        borderTop:SetColorTexture(edge[1],edge[2],edge[3],.72)
        borderBottom:SetColorTexture(edge[1],edge[2],edge[3],.50)
        local mark=kind=='caution' and t.accent3 or t.accent
        accent:SetColorTexture(mark[1],mark[2],mark[3],.94)
        b.label:SetTextColor(unpack(t.buttonText))
    end) end
    return b
end
local function WorkshopSelected(button,chosen)
    UI:SetButtonSelected(button,chosen)
    if button and button.label and button.afWorkshopQuiet then
        if UI.ThemeTokens then
            local t=UI:ThemeTokens()
            button.label:SetTextColor(unpack(chosen and t.accent2 or t.buttonText))
        elseif chosen then button.label:SetTextColor(1,.83,.47)
        else button.label:SetTextColor(.97,.87,.69) end
    end
end
UI.WorkshopButton=WorkshopButton
UI.WorkshopSetSelected=WorkshopSelected

local function WorkspaceIntro(page,title,subtitle)
    local f=CreateFrame('Frame',nil,page)
    f:SetPoint('TOPLEFT',page,'TOPLEFT',12,-8)
    f:SetPoint('TOPRIGHT',page,'TOPRIGHT',-12,-8)
    f:SetHeight(42)
    local bg=f:CreateTexture(nil,'BACKGROUND')
    bg:SetAllPoints(f)
    bg:SetColorTexture(.14,.097,.068,.94)
    local rule=f:CreateTexture(nil,'BORDER')
    rule:SetPoint('BOTTOMLEFT',f,'BOTTOMLEFT',7,1)
    rule:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',-7,1)
    rule:SetHeight(1)
    rule:SetColorTexture(.68,.48,.23,.6)
    local head=UI:Text(f,'small',P.gold)
    head:SetPoint('TOPLEFT',f,'TOPLEFT',12,-4)
    head:SetPoint('TOPRIGHT',f,'TOPRIGHT',-12,-4)
    head:SetHeight(17)
    head:SetText(title)
    local sub=UI:Text(f,'small',P.pale)
    sub:SetPoint('TOPLEFT',f,'TOPLEFT',12,-21)
    sub:SetPoint('TOPRIGHT',f,'TOPRIGHT',-12,-21)
    sub:SetHeight(16)
    sub:SetWordWrap(false)
    sub:SetText(subtitle)
    UI:ThemeWorkshopIntro(f,bg,head,sub,rule)
    return f
end

local function WorkshopPanels(page,id,leftRatio,rightRatio)
    local settings=AF.db.settings
    settings.workshopLayout=settings.workshopLayout or {}
    local pref=settings.workshopLayout[id]
    if type(pref)~='table' then pref={left=leftRatio or .26,right=rightRatio};settings.workshopLayout[id]=pref end
    local title=WorkspaceIntro(page,
        id=='Professions' and 'Professions & Skill Goals' or id=='Recipes' and 'Recipe Library' or id=='Crafting Queue' and 'Crafting Priority' or 'Account Materials',
        id=='Professions' and 'Find a crafter, inspect skill progress, or set a profession goal.' or
        id=='Recipes' and 'Search observed recipes, verify their materials, and plan a craft.' or
        id=='Crafting Queue' and 'Reorder planned crafts; recorded materials are allocated by priority.' or
        'Browse recorded material snapshots. Offline quantities may be out of date.')
    local left=UI:Card(page)
    left:SetPoint('TOPLEFT',page,'TOPLEFT',12,-57)
    left:SetPoint('BOTTOMLEFT',page,'BOTTOMLEFT',12,11)
    local center,right
    local gap=11
    if rightRatio then
        right=UI:Card(page)
        right:SetPoint('TOPRIGHT',page,'TOPRIGHT',-12,-57)
        right:SetPoint('BOTTOMRIGHT',page,'BOTTOMRIGHT',-12,11)
        center=UI:Card(page)
        center:SetPoint('TOPLEFT',left,'TOPRIGHT',gap,0)
        center:SetPoint('BOTTOMRIGHT',right,'BOTTOMLEFT',-gap,0)
    else
        center=UI:Card(page)
        center:SetPoint('TOPLEFT',left,'TOPRIGHT',gap,0)
        center:SetPoint('BOTTOMRIGHT',page,'BOTTOMRIGHT',-12,11)
    end
    local function handle(target,edge,label,callback)
        local grip=CreateFrame('Button',nil,page)
        grip:SetWidth(11)
        grip:SetPoint('TOPLEFT',target,'TOPRIGHT',0,0)
        grip:SetPoint('BOTTOMLEFT',target,'BOTTOMRIGHT',0,0)
        grip:SetFrameLevel(target:GetFrameLevel()+8)
        UI:StyleResizeGrip(grip)
        grip:RegisterForDrag('LeftButton')
        grip:SetScript('OnDragStart',function(self)
            self:SetScript('OnUpdate',function()
                local x=GetCursorPosition()
                local scale=page:GetEffectiveScale() or 1
                local origin=page:GetLeft()
                if x and origin then callback(x/scale-origin-12,false) end
            end)
        end)
        grip:SetScript('OnDragStop',function(self)
            self:SetScript('OnUpdate',nil)
            if callback then callback(nil,true) end
        end)
        grip:SetScript('OnHide',function(self) self:SetScript('OnUpdate',nil) end)
        return grip
    end
    local function applyWidths()
        local width=page:GetWidth() or 1000
        local usable=math.max(600,width-24)
        local minLeft=right and 185 or 225
        local minCenter=right and 265 or 360
        local minRight=right and 225 or 0
        local l=math.max(minLeft,math.min(usable-minCenter-minRight-2*gap,usable*(tonumber(pref.left) or leftRatio or .26)))
        left:SetWidth(math.max(170,l))
        if right then
            local r=math.max(minRight,math.min(usable-left:GetWidth()-minCenter-2*gap,usable*(tonumber(pref.right) or rightRatio)))
            right:SetWidth(math.max(205,r))
        end
    end
    local function leftMove(pos,done)
        local width=math.max(600,(page:GetWidth() or 1000)-24)
        if pos then
            left:SetWidth(math.max(right and 185 or 225,math.min(width-(right and (right:GetWidth()+265+22) or 360+11),pos)))
        elseif done then pref.left=left:GetWidth()/width end
    end
    handle(left,'LEFT','Directory',leftMove)
    if right then
        -- The second grip lives beside the right column and adjusts its width.
        local grip=CreateFrame('Button',nil,page)
        grip:SetWidth(11)
        grip:SetPoint('TOPRIGHT',right,'TOPLEFT',0,0)
        grip:SetPoint('BOTTOMRIGHT',right,'BOTTOMLEFT',0,0)
        grip:SetFrameLevel(right:GetFrameLevel()+8)
        UI:StyleResizeGrip(grip)
        grip:RegisterForDrag('LeftButton')
        grip:SetScript('OnDragStart',function(self)
            self:SetScript('OnUpdate',function()
                local x=GetCursorPosition()
                local scale=page:GetEffectiveScale() or 1
                local x0=page:GetLeft()
                local total=page:GetWidth() or 1000
                if x and x0 then
                    local desired=total-(x/scale-x0)-12
                    local available=total-left:GetWidth()-265-44
                    right:SetWidth(math.max(205,math.min(available,desired)))
                end
            end)
        end)
        grip:SetScript('OnDragStop',function(self)
            self:SetScript('OnUpdate',nil)
            pref.right=right:GetWidth()/math.max(600,(page:GetWidth() or 1000)-24)
        end)
        grip:SetScript('OnHide',function(self)self:SetScript('OnUpdate',nil)end)
    end
    page:HookScript('OnSizeChanged',function()applyWidths()end)
    applyWidths()
    return left,center,right,title
end
UI.WorkshopPanels=WorkshopPanels

function UI:BuildWorkshopQueue(page)
    local left,detail=UI.WorkshopPanels(page,'Crafting Queue',.31)
    Caption(left,'Production Priority')
    local up=WorkshopButton(left,'Move Up',function()
        local id=UI.workshopQueueSelected
        local i=AF:GetCraftingQueuePosition(id)
        if i and AF:MoveCraftingProject(id,i-1) then page:Refresh() end
    end)
    up:SetPoint('TOPLEFT',left,'TOPLEFT',14,-49);up:SetPoint('TOPRIGHT',left,'TOP',-3,-49);up:SetHeight(27)
    local down=WorkshopButton(left,'Move Down',function()
        local id=UI.workshopQueueSelected
        local i=AF:GetCraftingQueuePosition(id)
        if i and AF:MoveCraftingProject(id,i+1) then page:Refresh() end
    end)
    down:SetPoint('TOPLEFT',left,'TOP',3,-49);down:SetPoint('TOPRIGHT',left,'TOPRIGHT',-14,-49);down:SetHeight(27)
    local guide=Text(left,83,47)
    guide:SetText('Drag [=] to reorder. Higher queued crafts reserve recorded materials first.')
    local list=self:List(left,46)
    UI:InsetWorkshopScrollBar(list)
    list:SetPoint('TOPLEFT',left,'TOPLEFT',12,-132)
    list:SetPoint('BOTTOMRIGHT',left,'BOTTOMRIGHT',-29,19)

    Caption(detail,'Selected Craft')
    local header=Text(detail,57,72)
    local function fitQueueCopy()
        if header.GetStringHeight then
            local h=tonumber(header:GetStringHeight()) or 0
            header:SetHeight(math.max(72,math.min(94,h+5)))
        end
    end
    if detail.HookScript then detail:HookScript('OnSizeChanged',fitQueueCopy) end
    local removeCraft=WorkshopButton(detail,'Remove from Queue',function()
        local selected=AF:FindRecord(AF:GetCraftingQueueProjects(),UI.workshopQueueSelected)
        if not selected then return end
        if not StaticPopupDialogs or not StaticPopup_Show then
            if AF.Print then AF.Print('Confirmation dialog unavailable; queue entry was not removed.') end
            return
        end
        if not StaticPopupDialogs.AZEROTHFOUNDRY_REMOVE_QUEUE then
            StaticPopupDialogs.AZEROTHFOUNDRY_REMOVE_QUEUE={
                text='Remove %s from Crafting Queue? Goals remain unchanged. This does not stop an active craft.',
                button1=YES or 'Remove',button2=NO or 'Cancel',
                timeout=0,whileDead=1,hideOnEscape=1,preferredIndex=3,
                OnAccept=function(_,data)
                    if not data or not data.id then return end
                    if AF:RemoveQueuedCraft(data.id) then
                        if UI.workshopQueueSelected==data.id then UI.workshopQueueSelected=nil end
                        UI.workshopQueueNotice='Removed from queue. Goals were not changed.'
                        if page.Refresh then page:Refresh() end
                    end
                end,
            }
        end
        StaticPopup_Show('AZEROTHFOUNDRY_REMOVE_QUEUE',selected.title or 'selected craft',nil,{id=selected.id})
    end,'caution')
    removeCraft:SetSize(177,27)
    removeCraft:SetPoint('TOPRIGHT',detail,'TOPRIGHT',-16,-48)
    local rule=detail:CreateTexture(nil,'ARTWORK')
    rule:SetHeight(1)
    rule:SetPoint('TOPLEFT',header,'BOTTOMLEFT',-1,-7)
    rule:SetPoint('TOPRIGHT',header,'BOTTOMRIGHT',-1,-7)
    rule:SetColorTexture(.52,.36,.14,.56)
    local stepsLabel=UI:Text(detail,'small',P.ink)
    stepsLabel:SetPoint('TOPLEFT',rule,'BOTTOMLEFT',1,-8)
    stepsLabel:SetText('REQUIRED MATERIALS / ALLOCATIONS')
    stepsLabel:SetHeight(23)
    local details=self:List(detail,43)
    UI:InsetWorkshopScrollBar(details)
    details:SetPoint('TOPLEFT',stepsLabel,'BOTTOMLEFT',-5,-9)
    details:SetPoint('BOTTOMRIGHT',detail,'BOTTOMRIGHT',-30,376)
    local statusPanel=UI:NewFrame('Frame',detail)
    statusPanel:SetPoint('BOTTOMLEFT',detail,'BOTTOMLEFT',14,20)
    statusPanel:SetPoint('BOTTOMRIGHT',detail,'BOTTOMRIGHT',-14,20)
    statusPanel:SetHeight(340)
    UI:Background(statusPanel,P.leather,true)
    local panelHeading=UI:Text(statusPanel,'small',P.gold)
    panelHeading:SetPoint('TOPLEFT',statusPanel,'TOPLEFT',12,-8)
    panelHeading:SetText('RESOURCE READINESS')
    panelHeading:SetHeight(20)
    local readiness=UI:Text(statusPanel,'small',P.pale)
    readiness:SetPoint('TOPLEFT',statusPanel,'TOPLEFT',12,-34)
    readiness:SetPoint('BOTTOMRIGHT',statusPanel,'BOTTOMRIGHT',-12,190)
    readiness:SetJustifyV('TOP')
    local footer=UI:Text(statusPanel,'small',P.pale)
    footer:SetPoint('BOTTOMLEFT',statusPanel,'BOTTOMLEFT',12,150)
    footer:SetPoint('BOTTOMRIGHT',statusPanel,'BOTTOMRIGHT',-12,150)
    footer:SetHeight(24)
    footer:SetJustifyV('TOP')
    footer:SetText('Craft timing appears here when the game starts a profession cast.')
    -- Live craft cast progress is read from UnitCastingInfo("player"); no
    -- inferred duration or premature queue credit. Parent OnUpdate runs only
    -- while the Crafting Queue page is visible.
    local castTrack=CreateFrame('StatusBar',nil,statusPanel)
    castTrack:SetPoint('BOTTOMLEFT',statusPanel,'BOTTOMLEFT',12,123)
    castTrack:SetPoint('BOTTOMRIGHT',statusPanel,'BOTTOMRIGHT',-12,123)
    castTrack:SetHeight(14)
    castTrack:SetMinMaxValues(0,1)
    castTrack:SetValue(0)
    castTrack:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar')
    castTrack:SetStatusBarColor(.35,.65,.44,1)
    local castBackground=castTrack:CreateTexture(nil,'BACKGROUND')
    castBackground:SetAllPoints(castTrack)
    castBackground:SetColorTexture(.11,.08,.055,.9)
    local castBorder=castTrack:CreateTexture(nil,'BORDER')
    castBorder:SetPoint('TOPLEFT',castTrack,'TOPLEFT',0,1)
    castBorder:SetPoint('BOTTOMRIGHT',castTrack,'BOTTOMRIGHT',0,-1)
    castBorder:SetColorTexture(.59,.40,.18,.25)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(castTrack,function(_,t)
        local color=t.accent or {.35,.65,.44}
        castTrack:SetStatusBarColor(color[1],color[2],color[3],1)
    end) end
    local castUpdate=CreateFrame('Frame',nil,statusPanel)
    castUpdate:SetAllPoints(castTrack)
    local throttle=0
    castUpdate:SetScript('OnUpdate',function(_,dt)
        throttle=throttle+(tonumber(dt) or 0)
        if throttle<.05 then return end
        throttle=0
        local active=AF.GetWorkshopCraftCastProgress and AF:GetWorkshopCraftCastProgress()
        if active then
            castTrack:SetValue(active.fraction)
            footer:SetText(string.format('%s  -  %.1fs remaining',active.name,active.remaining))
        else
            castTrack:SetValue(0)
            local r=AF.lastQueueCraftRequest
            local status=r and r.status
            if status=='request_sent' or status=='cast_started' or status=='craft_started' then
                footer:SetText('Craft requested - waiting for live cast timing / result...')
            else
                footer:SetText('Craft timing appears here when the game starts a profession cast.')
            end
        end
    end)
    -- Only five everyday controls. Native recipe selection is automatic for
    -- ordinary crafts; advanced diagnostics remain available via /af craftstatus.
    local openProfession=WorkshopButton(statusPanel,'Open Profession',function()
        local project=AF:FindRecord(AF:GetCraftingQueueProjects(),UI.workshopQueueSelected)
        local ok,msg=AF:ShowQueuedCraftProfession(project)
        UI.workshopQueueNotice=msg
        if AF.Print then AF.Print(msg) end
        page:Refresh()
    end)
    openProfession:SetHeight(28)
    openProfession:SetPoint('BOTTOMLEFT',statusPanel,'BOTTOMLEFT',12,17)
    openProfession:SetPoint('BOTTOMRIGHT',statusPanel,'BOTTOMRIGHT',-12,17)
    local craftOne=WorkshopButton(statusPanel,'Craft 1',function()
        local project=AF:FindRecord(AF:GetCraftingQueueProjects(),UI.workshopQueueSelected)
        local ok,msg=AF:TryQueuedCraftQuick(project,false)
        -- Prepare/execute is always initiated by THIS player click. Keep the
        -- profession frame's session alive without a full-size animation.
        if ok and ProfessionsFrame and ProfessionsFrame.IsShown and ProfessionsFrame:IsShown()
            and AF.HideQueueNativeProfession then
            local concealed,why=AF:HideQueueNativeProfession()
            if not concealed and why then msg=tostring(msg or '')..' | '..why end
        end
        UI.workshopQueueNotice=msg
        if AF.Print then AF.Print(msg) end
        page:Refresh()
    end)
    craftOne:SetHeight(28)
    craftOne:SetPoint('BOTTOMLEFT',statusPanel,'BOTTOMLEFT',12,89)
    craftOne:SetPoint('BOTTOMRIGHT',statusPanel,'BOTTOM',-4,89)
    local craftAll=WorkshopButton(statusPanel,'Craft All',function()
        local project=AF:FindRecord(AF:GetCraftingQueueProjects(),UI.workshopQueueSelected)
        local ok,msg=AF:TryQueuedCraftQuick(project,true)
        -- Prepare/execute is always initiated by THIS player click. Keep the
        -- profession frame's session alive without a full-size animation.
        if ok and ProfessionsFrame and ProfessionsFrame.IsShown and ProfessionsFrame:IsShown()
            and AF.HideQueueNativeProfession then
            local concealed,why=AF:HideQueueNativeProfession()
            if not concealed and why then msg=tostring(msg or '')..' | '..why end
        end
        UI.workshopQueueNotice=msg
        if AF.Print then AF.Print(msg) end
        page:Refresh()
    end)
    craftAll:SetHeight(28)
    craftAll:SetPoint('BOTTOMLEFT',statusPanel,'BOTTOM',4,89)
    craftAll:SetPoint('BOTTOMRIGHT',statusPanel,'BOTTOMRIGHT',-12,89)
    -- The secure action is intentionally a sibling overlay, not a mutation of
    -- the existing tested Craft buttons. It is shown only out of combat when
    -- an actual form spell can be resolved, and consumes the first Craft click
    -- to leave form. It never sends a craft request on the same click.
    local formOverlays={}
    -- The insecure action template is secure for player-clicked actions only
    -- outside combat; unlike SecureActionButtonTemplate it does not protect
    -- the entire Foundry frame hierarchy. Use a guarded fallback on clients
    -- where that template is unavailable.
    local function MakeLeaveFormOverlay(target)
        local ok,b=pcall(CreateFrame,'Button',nil,statusPanel,'InsecureActionButtonTemplate')
        if not ok or not b then
            b=CreateFrame('Button',nil,statusPanel,'SecureActionButtonTemplate')
        end
        b:SetAllPoints(target)
        b:SetFrameLevel(target:GetFrameLevel()+5)
        b:RegisterForClicks('LeftButtonUp')
        b:SetAttribute('type','cancelaura')
        b:EnableMouse(true)
        local bg=b:CreateTexture(nil,'BACKGROUND')
        bg:SetAllPoints(b)
        bg:SetColorTexture(.69,.10,.11,.98)
        local title=b:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
        title:SetAllPoints(b)
        title:SetText('Leave Form')
        title:SetTextColor(1,.96,.92)
        -- This is an actionable safety cue, not a themed Craft button:
        -- keep it visibly red in Classic, Forever, Light, Matrix and custom themes.
        if UI.RegisterThemeTarget then
            UI:RegisterThemeTarget(b,function()
                bg:SetColorTexture(.69,.10,.11,.98)
                title:SetTextColor(1,.96,.92)
            end)
        end
        b:Hide()
        formOverlays[#formOverlays+1]=b
        return b
    end
    MakeLeaveFormOverlay(craftOne)
    MakeLeaveFormOverlay(craftAll)
    local formEvent=CreateFrame('Frame',nil,statusPanel)
    formEvent:RegisterEvent('UPDATE_SHAPESHIFT_FORM')
    formEvent:RegisterEvent('UPDATE_SHAPESHIFT_FORMS')
    formEvent:RegisterEvent('PLAYER_REGEN_ENABLED')
    local function RefreshLeaveForm()
        -- Protected button attributes and visibility cannot be changed in
        -- combat. Crafting itself already refuses to start in combat.
        if InCombatLockdown and InCombatLockdown() then return end
        local spell=BlockingCraftFormSpell()
        for _,b in ipairs(formOverlays) do
            if spell then
                b:SetAttribute('spell',spell)
                b:Show()
            else
                b:Hide()
                b:SetAttribute('spell',nil)
            end
        end
    end
    formEvent:SetScript('OnEvent',function()RefreshLeaveForm()end)
    statusPanel:HookScript('OnShow',RefreshLeaveForm)
    RefreshLeaveForm()
    local nextCraft=WorkshopButton(statusPanel,'Next Queued Craft',function()
        local projects=AF:GetCraftingQueueProjects()
        local old=UI.workshopQueueSelected
        local position=AF:GetCraftingQueuePosition(old) or 0
        local picked=nil
        for offset=1,#projects do
            local i=(position-1+offset)%#projects+1
            local project=projects[i]
            if project.owner==AF:GetCurrentKey() and project.id~=old then
                picked=project;break
            end
        end
        if picked then
            UI.workshopQueueSelected=picked.id
            -- This button click can pre-open the selected profession, without
            -- crafting or changing persistent queue progress.
            local ok,msg=AF:PrepareQueuedCraftOnSelection(picked)
            UI.workshopQueueNotice=ok and ('Next queued recipe selected. '..tostring(msg))
                or ('Next queued recipe selected. '..tostring(msg or 'Open its profession to craft.'))
        else
            UI.workshopQueueNotice='No other queued recipe assigned to the current character.'
        end
        page:Refresh()
    end)
    nextCraft:SetHeight(28)
    nextCraft:SetPoint('BOTTOMLEFT',statusPanel,'BOTTOMLEFT',12,53)
    nextCraft:SetPoint('BOTTOMRIGHT',statusPanel,'BOTTOM',-4,53)
    local stopBatch=WorkshopButton(statusPanel,'Stop',function()
        local ok,msg=AF:StopQueuedCraftRepeat()
        UI.workshopQueueNotice=msg
        if AF.Print then AF.Print(msg) end
        page:Refresh()
    end)
    stopBatch:SetHeight(28)
    stopBatch:SetPoint('BOTTOMLEFT',statusPanel,'BOTTOMRIGHT',-88,53)
    stopBatch:SetPoint('BOTTOMRIGHT',statusPanel,'BOTTOMRIGHT',-12,53)
    function page:Refresh()
        if AF.MaintainQueueCompactNativeProfession then AF:MaintainQueueCompactNativeProfession() end
        local queue=AF:EvaluateCraftingQueue()
        local projects=AF:GetCraftingQueueProjects()
        local chosen=AF:FindRecord(projects,UI.workshopQueueSelected) or projects[1]
        UI.workshopQueueSelected=chosen and chosen.id or nil
        local rows={}
        for i,project in ipairs(projects) do
            local state=queue.byId[project.id]
            local c=project.crafting or {}
            local progress=math.max(0,math.floor(tonumber(c.completed) or
                (project.guided and tonumber(project.guided.crafted)) or 0))
            rows[#rows+1]={key=project.id,craft=true,label='[=] '..i..'. '..(project.title or 'Craft')..'\n'..AF:CraftStatusLabel(state and state.status)..'  |  '..progress..'/'..tostring(c.quantity or 1)..' crafted'}
        end
        UI:FillList(list,rows,function(row)
            UI.workshopQueueSelected=row.key
            local selected=AF:FindRecord(projects,row.key)
            local ok,msg=AF:PrepareQueuedCraftOnSelection(selected)
            UI.workshopQueueNotice=ok and msg or
                (msg and 'Profession not prepared: '..tostring(msg) or nil)
            page:Refresh()
        end,UI.workshopQueueSelected)
        for i,row in ipairs(rows) do
            local b=list.rows[i]
            if b then
                b:RegisterForDrag('LeftButton')
                b:SetScript('OnDragStart',function(button)
                    UI.workshopDragCraft=row.key
                    if button.SetAlpha then button:SetAlpha(.55) end
                end)
                b:SetScript('OnDragStop',function(button)
                    if button.SetAlpha then button:SetAlpha(1) end
                    local moving=UI.workshopDragCraft
                    UI.workshopDragCraft=nil
                    local target
                    for j,candidate in ipairs(rows) do
                        local other=list.rows[j]
                        if other and other.IsMouseOver and other:IsMouseOver() then
                            target=candidate.key;break
                        end
                    end
                    if moving and target and moving~=target and AF:MoveCraftingProjectOnto(moving,target) then page:Refresh() end
                end)
            end
        end
        if not chosen then
            header:SetText('Crafting Queue is empty.\nAdd a learned recipe from Recipes to begin.')
            fitQueueCopy()
            UI:FillList(details,{},function()end)
            readiness:SetText('Your production queue is empty. Add a craft from Recipes to begin.')
            up:Disable();down:Disable();removeCraft:Hide()
            -- Completed queue can still leave the native profession session
            -- concealed. Keep the reveal control available for that case.
            openProfession:SetEnabled(AF.IsQueueCompactNativeProfession and AF:IsQueueCompactNativeProfession() or false)
            craftOne:Disable();craftAll:Disable();nextCraft:Disable()
            stopBatch:SetEnabled(C_TradeSkillUI and type(C_TradeSkillUI.StopRecipeRepeat)=='function')
            return
        end
        removeCraft:Show()
        local position=AF:GetCraftingQueuePosition(chosen.id)
        up:SetEnabled(position and position>1 or false)
        down:SetEnabled(position and position<#projects or false)
        local state=queue.byId[chosen.id]
        header:SetText((chosen.title or 'Untitled')..'\nAssigned: '..AF:CharacterLabel(chosen.owner))
        fitQueueCopy()
        local steps={}
        for i,s in ipairs(state and state.steps or {}) do
            steps[#steps+1]={key=i,icon=(AF:GetItemPresentation(s.itemID) or {}).icon,
                label=(s.name or ('Item #'..s.itemID))..'  •  '..s.covered..'/'..s.needed..' allocated'..(s.missing>0 and ('  •  need '..s.missing) or '')}
        end
        UI:FillList(details,steps,function()end)
        local lines={
            'Priority: '..tostring(position)..'   |   '..AF:CraftStatusLabel(state and state.status),
        }
        if state and state.reasons and state.reasons[1] then lines[#lines+1]=state.reasons[1] end
        if state and state.conflicts and #state.conflicts>0 then lines[#lines+1]='Recorded materials reserved to higher queue items.' end
        local action=AF:GetQueueCraftAction(chosen)
        if chosen.crafting then
            local done=math.max(0,math.floor(tonumber(chosen.crafting.completed) or
                (chosen.guided and tonumber(chosen.guided.crafted)) or 0))
            lines[#lines+1]='Craft progress: '..done..'/'..tostring(chosen.crafting.quantity or 1)..' observed'
        end
        local quick=AF:GetQueuedCraftQuickAction(chosen)
        lines[#lines+1]=(quick.canQuickCraft and not action.ready and quick.reason) or action.reason or 'Cannot check current crafting state.'
        lines[#lines+1]='Selecting a queued craft prepares its profession. Craft 1 / Craft All sends the craft only after the native session is ready.'
        if UI.workshopQueueNotice then lines[#lines+1]=UI.workshopQueueNotice end
        local liveMessage=AF.GetQueueCraftRequestMessage and AF:GetQueueCraftRequestMessage(chosen)
        if liveMessage then lines[#lines+1]='Execution: '..liveMessage end
        readiness:SetText(table.concat(lines,'\n'))
        openProfession:SetEnabled(action.canOpen==true or
            (AF.IsQueueCompactNativeProfession and AF:IsQueueCompactNativeProfession()) or false)
        craftOne:SetEnabled(quick.canQuickCraft==true)
        craftAll:SetEnabled(quick.canQuickCraft==true and (not action.ready or action.canCraftAll==true))
        local count=tonumber(action.batchCount) or 0
        craftAll.label:SetText(count>0 and ('Craft All ('..count..')') or 'Craft All')
        nextCraft:SetEnabled(#projects>1)
        stopBatch:SetEnabled(C_TradeSkillUI and type(C_TradeSkillUI.StopRecipeRepeat)=='function')
    end
end

function UI:BuildWorkshopMaterials(page)
    local left,detail=UI.WorkshopPanels(page,'Materials',.32)
    Caption(left,'Recorded Inventory')
    local scope='all'
    local selectedID
    local sortBy='name'
    local toggle=WorkshopButton(left,'All Alts  v',function()
        if AF:IsModuleEnabled('selfFound') then scope=scope=='all' and 'expedition' or 'all' end
        page:Refresh()
    end)
    toggle:SetPoint('TOPLEFT',left,'TOPLEFT',14,-49)
    toggle:SetPoint('TOPRIGHT',left,'TOPRIGHT',-14,-49)
    toggle:SetHeight(27)
    local note=Text(left,88,55)
    note:SetText('Search saved bag/bank records. These are snapshots, not live shared storage.')
    local search=self:Input(left,150)
    search:SetPoint('TOPLEFT',left,'TOPLEFT',14,-151)
    search:SetPoint('TOPRIGHT',left,'TOPRIGHT',-103,-151)
    search:SetHeight(25)
    search:SetScript('OnTextChanged',function(_,userInput)
        if userInput then page:Refresh() end
    end)
    local sort=WorkshopButton(left,'Sort: Name',function()
        sortBy=sortBy=='name' and 'quantity' or 'name'
        page:Refresh()
    end)
    sort:SetPoint('TOPRIGHT',left,'TOPRIGHT',-13,-151)
    sort:SetSize(84,25)
    local itemList=self:List(left,41)
    UI:InsetWorkshopScrollBar(itemList)
    itemList:SetPoint('TOPLEFT',left,'TOPLEFT',12,-190)
    itemList:SetPoint('BOTTOMRIGHT',left,'BOTTOMRIGHT',-30,18)

    Caption(detail,'Material Ledger')
    local summary=Text(detail,54,60)
    summary:SetJustifyV('TOP')
    local function fitMaterialSummary()
        if summary.GetStringHeight then
            local h=tonumber(summary:GetStringHeight()) or 0
            summary:SetHeight(math.max(60,math.min(95,h+6)))
        end
    end
    if detail.HookScript then detail:HookScript('OnSizeChanged',fitMaterialSummary) end
    local ledgerHeader=UI:Text(detail,'small',P.ink)
    ledgerHeader:SetText('RECORDED LOCATIONS  •  CHARACTER / STORAGE / QUANTITY')
    ledgerHeader:SetPoint('TOPLEFT',summary,'BOTTOMLEFT',1,-8)
    ledgerHeader:SetPoint('TOPRIGHT',summary,'BOTTOMRIGHT',-1,-8)
    ledgerHeader:SetHeight(22)
    local byChar=self:List(detail,48)
    UI:InsetWorkshopScrollBar(byChar)
    byChar:SetPoint('TOPLEFT',ledgerHeader,'BOTTOMLEFT',-6,-8)
    byChar:SetPoint('BOTTOMRIGHT',detail,'BOTTOMRIGHT',-30,169)

    local statusPanel=UI:NewFrame('Frame',detail)
    statusPanel:SetPoint('BOTTOMLEFT',detail,'BOTTOMLEFT',14,20)
    statusPanel:SetPoint('BOTTOMRIGHT',detail,'BOTTOMRIGHT',-14,20)
    statusPanel:SetHeight(135)
    UI:Background(statusPanel,P.leather,true)
    local statusTitle=UI:Text(statusPanel,'small',P.gold)
    statusTitle:SetPoint('TOPLEFT',statusPanel,'TOPLEFT',13,-8)
    statusTitle:SetHeight(19)
    statusTitle:SetText('SNAPSHOT COVERAGE')
    local status=UI:Text(statusPanel,'small',P.pale)
    status:SetPoint('TOPLEFT',statusPanel,'TOPLEFT',13,-31)
    status:SetPoint('BOTTOMRIGHT',statusPanel,'BOTTOMRIGHT',-175,12)
    status:SetJustifyV('TOP')
    local refresh=WorkshopButton(statusPanel,'Rescan Bags',function()
        if AF.ScanBags then AF:ScanBags() end
        page:Refresh()
    end)
    refresh:SetPoint('BOTTOMRIGHT',statusPanel,'BOTTOMRIGHT',-12,13)
    refresh:SetSize(146,29)

    function page:Refresh()
        if not AF:IsModuleEnabled('selfFound') then scope='all' end
        toggle:SetShown(AF:IsModuleEnabled('selfFound'))
        toggle.label:SetText(scope=='all' and 'All Alts  v' or 'Expedition  v')
        sort.label:SetText(sortBy=='name' and 'Sort: Name' or 'Sort: Qty')
        local totals,locations,cover={},{},0
        local chars=AF:GetWorkshopCharacters(scope)
        for _,c in ipairs(chars) do
            local snapshots=((AF.db.inventory or {})[c.key] or {})
            for _,place in ipairs({'bags','bank'}) do
                local snap=snapshots[place]
                if type(snap)=='table' and type(snap.counts)=='table' then
                    cover=cover+1
                    for rawID,rawCount in pairs(snap.counts) do
                        local id,count=tonumber(rawID),tonumber(rawCount)
                        if id and count and count>0 then
                            totals[id]=(totals[id] or 0)+count
                            locations[id]=locations[id] or {}
                            locations[id][#locations[id]+1]={character=c.name,location=place,quantity=count,scanned=snap.scanned}
                        end
                    end
                end
            end
        end
        local ids={}
        local query=(search:GetText() or ''):lower()
        for id in pairs(totals) do
            local name=((AF:GetItemPresentation(id) or {}).name or ('Item #'..id)):lower()
            if query=='' or name:find(query,1,true) then ids[#ids+1]=id end
        end
        table.sort(ids,function(a,b)
            local na=(AF:GetItemPresentation(a) or {}).name or ''
            local nb=(AF:GetItemPresentation(b) or {}).name or ''
            if sortBy=='quantity' and totals[a]~=totals[b] then return totals[a]>totals[b] end
            return na==nb and a<b or na<nb
        end)
        local visible=false
        for _,id in ipairs(ids) do if id==selectedID then visible=true;break end end
        if not visible then selectedID=ids[1] end
        local entries={}
        for _,id in ipairs(ids) do
            local item=AF:GetItemPresentation(id)
            entries[#entries+1]={key=id,icon=item and item.icon,
                label=((item and item.name) or ('Item #'..id))..'  ×'..totals[id]}
        end
        UI:FillList(itemList,entries,function(entry) selectedID=entry.key;page:Refresh() end,selectedID)
        status:SetText('Registered characters: '..#chars..'\nObserved storage snapshots: '..cover..'\n\nBank and offline-alt quantities may have changed since their scan.')
        if not selectedID then
            summary:SetText(query~='' and 'No matching recorded materials.' or 'No saved items in this scope.\nLog into an alt to scan bags, or open its bank for a bank scan.')
            fitMaterialSummary()
            UI:FillList(byChar,{},function()end)
            return
        end
        local item=AF:GetItemPresentation(selectedID)
        summary:SetText(((item and item.name) or ('Item #'..selectedID))..'\nRecorded total: '..totals[selectedID])
        fitMaterialSummary()
        local records={}
        for i,record in ipairs(locations[selectedID] or {}) do
            records[#records+1]={key=i,
                label=record.character..'  |  '..(record.location=='bank' and 'Bank' or 'Bags')..'  |  ×'..record.quantity..'\n'..
                    (record.scanned and (date and date('%b %d %Y, %H:%M',record.scanned) or 'Saved snapshot') or 'No timestamp')}
        end
        UI:FillList(byChar,records,function()end)
    end
end

function UI:BuildLivingWorkshop(page)
    -- The sidebar's nested Workshop tree is the only visible subnavigation.
    -- Keep these exact subpage names: the existing /af routes, widget links,
    -- saved selection and all four page builders use them.
    local body=CreateFrame('Frame',nil,page)
    body:SetAllPoints(page)
    local views={}
    page.subViews=views
    function page:Select(name)
        local supported={Professions=true,Training=true,Recipes=true,['Crafting Queue']=true,Materials=true}
        if not supported[name] then name='Professions' end
        if name=='Materials' and AF.IsQueueCompactNativeProfession and
            AF:IsQueueCompactNativeProfession() then
            if AF.ReleaseQueueNativeProfession then AF:ReleaseQueueNativeProfession() end
        end
        AF.db.settings.workshopTab=name
        if UI.pageTitle then UI.pageTitle:SetText('Workshop  /  '..name) end
        local view=views[name]
        if not view then
            view=CreateFrame('Frame',nil,body)
            view:SetAllPoints(body)
            views[name]=view
            if name=='Professions' then UI:BuildWorkshop(view)
            elseif name=='Training' then UI:BuildTrainingPlanner(view)
            elseif name=='Recipes' then UI:BuildRecipes(view)
            elseif name=='Crafting Queue' then UI:BuildWorkshopQueue(view)
            else UI:BuildWorkshopMaterials(view) end
        end
        for label,f in pairs(views) do f:SetShown(label==name) end
        if UI.RefreshNavigation then UI:RefreshNavigation() end
        if view.Refresh then view:Refresh() end
    end
    function page:Refresh()
        local view=views[AF.db.settings.workshopTab]
        if view and view.Refresh then view:Refresh() end
    end
end
