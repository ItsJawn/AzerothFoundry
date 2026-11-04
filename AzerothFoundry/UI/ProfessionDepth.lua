-- Azeroth Foundry v0.5.12.5 — Professions depth pass.
-- Presentation-only override: original profession/recipe/goal data functions
-- and scanner remain authoritative. No new scan events or snapshot mutations.
local _, AF = ...
local UI = AF.UI
local P = UI.palette
local unpack = unpack or table.unpack
local min, max, floor = math.min, math.max, math.floor

local function Msg(frame, font, color, height)
    local t=UI:Text(frame,font or 'small',color or P.ink)
    t:SetHeight(height or 20)
    t:SetJustifyV('MIDDLE')
    return t
end
local function Header(frame,label)
    local title=UI:SectionTitle(frame,label)
    title:SetPoint('TOPLEFT',frame,'TOPLEFT',14,-10)
    title:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-14,-10)
    return title
end
local function B(frame,label,callback)
    return UI.WorkshopButton(frame,label,callback)
end
local function Percent(rank,cap)
    rank,cap=tonumber(rank) or 0,tonumber(cap) or 0
    if cap <= 0 then return 0 end
    return max(0,min(1,rank/cap))
end
local function Stamp(value)
    if type(value)~='number' or value<=0 then return 'Not scanned' end
    return type(date)=='function' and date('%b %d %Y, %H:%M',value) or 'Previously scanned'
end
local function ObservedRecipes(key,name)
    local byOwner=(AF.db.recipeSnapshots or {})[key] or {}
    local observed,learned=0,0
    local wanted=tostring(name or ''):lower()
    for _,snapshot in pairs(byOwner) do
        if type(snapshot)=='table' and tostring(snapshot.professionName or ''):lower()==wanted then
            for _,r in pairs(snapshot.recipes or {}) do
                if type(r)=='table' then
                    observed=observed+1
                    if r.learned==true then learned=learned+1 end
                end
            end
        end
    end
    return observed,learned
end
local function StyleProgress(parent,x1,x2,y,width)
    local track=parent:CreateTexture(nil,'ARTWORK')
    track:SetColorTexture(.20,.13,.085,.79)
    track:SetHeight(9)
    track:SetPoint('TOPLEFT',parent,'TOPLEFT',x1,-y)
    track:SetPoint('TOPRIGHT',parent,'TOPRIGHT',-x2,-y)
    local fill=parent:CreateTexture(nil,'OVERLAY')
    fill:SetColorTexture(.30,.52,.36,1)
    fill:SetHeight(7)
    fill:SetPoint('TOPLEFT',track,'TOPLEFT',1,-1)
    local function set(v)
        -- SetWidth must be updated after layout or it can extend beyond card.
        local trackWidth=track:GetWidth() or width or 120
        fill:SetWidth(max(1,(trackWidth>8 and trackWidth-2 or 120)*max(0,min(1,v or 0))))
    end
    return set,track
end

function UI:BuildWorkshop(page)
    local settings=AF.db.settings
    settings.workshopLayout=settings.workshopLayout or {}
    local pref=settings.workshopLayout.ProfessionsDepth
    if type(pref)~='table' then
        pref={directoryRatio=.285,trainingRatio=.365}
        settings.workshopLayout.ProfessionsDepth=pref
    end
    local heading=CreateFrame('Frame',nil,page)
    heading:SetPoint('TOPLEFT',page,'TOPLEFT',12,-8)
    heading:SetPoint('TOPRIGHT',page,'TOPRIGHT',-12,-8)
    heading:SetHeight(40)
    local hb=heading:CreateTexture(nil,'BACKGROUND')
    hb:SetAllPoints(heading);hb:SetColorTexture(.14,.097,.068,.94)
    local topLabel=Msg(heading,'small',P.gold,16)
    topLabel:SetPoint('TOPLEFT',heading,'TOPLEFT',12,-4)
    topLabel:SetPoint('TOPRIGHT',heading,'TOPRIGHT',-12,-4)
    topLabel:SetText('Profession Workshop')
    local topHint=Msg(heading,'small',P.pale,16)
    topHint:SetPoint('TOPLEFT',heading,'TOPLEFT',12,-21)
    topHint:SetPoint('TOPRIGHT',heading,'TOPRIGHT',-12,-21)
    topHint:SetText('Compare your registered crafters, inspect skill progress, and plan their next training goal.')
    local topRule=heading:CreateTexture(nil,'BORDER')
    topRule:SetHeight(1)
    topRule:SetPoint('BOTTOMLEFT',heading,'BOTTOMLEFT',8,0)
    topRule:SetPoint('BOTTOMRIGHT',heading,'BOTTOMRIGHT',-8,0)
    topRule:SetColorTexture(.67,.47,.23,.59)
    UI:ThemeWorkshopIntro(heading,hb,topLabel,topHint,topRule)

    local directory=UI:Card(page)
    local compare=UI:Card(page)
    local training=UI:Card(page)
    directory:SetPoint('TOPLEFT',page,'TOPLEFT',12,-55)
    compare:SetPoint('TOPLEFT',directory,'TOPRIGHT',12,0)
    compare:SetPoint('TOPRIGHT',page,'TOPRIGHT',-12,-55)
    training:SetPoint('BOTTOMLEFT',page,'BOTTOMLEFT',12,11)
    training:SetPoint('BOTTOMRIGHT',page,'BOTTOMRIGHT',-12,11)
    directory:SetPoint('BOTTOMLEFT',training,'TOPLEFT',0,11)
    compare:SetPoint('BOTTOMRIGHT',training,'TOPRIGHT',0,11)

    -- The two lower panels are docked above Training. Keep a usable list area
    -- above and leave room for its buttons below. Unlike the original hard
    -- 210 / (height-270) clamp, these bounds do not collapse to a single
    -- height at ordinary smaller window sizes.
    local function trainingBounds()
        local h=page:GetHeight() or 0
        if h<1 then h=600 end
        local minTraining=178 -- title, skill/goal controls; secondary footnotes fold below 205
        local topReserve=55+11+190+11 -- intro, panel gap, comparison list, bottom inset
        local maxTraining=max(minTraining,h-topReserve)
        return minTraining,maxTraining,h
    end
    local function clampTraining(value)
        local low,high=trainingBounds()
        return max(low,min(high,value))
    end
    local function layout()
        local width=page:GetWidth() or 960
        local height=page:GetHeight() or 600
        if height<1 then height=600 end
        local availableW=max(690,width-24)
        directory:SetWidth(max(205,min(availableW-415,availableW*(tonumber(pref.directoryRatio) or .285))))
        training:SetHeight(clampTraining(height*(tonumber(pref.trainingRatio) or .365)))
    end
    page:HookScript('OnSizeChanged',layout)
    layout()

    local hGrip=CreateFrame('Button',nil,page)
    hGrip:SetWidth(12)
    hGrip:SetPoint('TOPLEFT',directory,'TOPRIGHT',0,0)
    hGrip:SetPoint('BOTTOMLEFT',directory,'BOTTOMRIGHT',0,0)
    hGrip:SetFrameLevel(directory:GetFrameLevel()+8)
    UI:StyleResizeGrip(hGrip)
    hGrip:RegisterForDrag('LeftButton')
    hGrip:SetScript('OnDragStart',function(self)
        self:SetScript('OnUpdate',function()
            local cx=GetCursorPosition()
            local x=page:GetLeft()
            if not cx or not x then return end
            local target=cx/(page:GetEffectiveScale() or 1)-x-12
            directory:SetWidth(max(205,min((page:GetWidth() or 960)-439,target)))
        end)
    end)
    hGrip:SetScript('OnDragStop',function(self)
        self:SetScript('OnUpdate',nil)
        pref.directoryRatio=directory:GetWidth()/max(690,(page:GetWidth() or 960)-24)
    end)
    hGrip:SetScript('OnHide',function(self)self:SetScript('OnUpdate',nil)end)

    local vGrip=CreateFrame('Button',nil,page)
    vGrip:SetHeight(12)
    vGrip:SetPoint('BOTTOMLEFT',training,'TOPLEFT',0,0)
    vGrip:SetPoint('BOTTOMRIGHT',training,'TOPRIGHT',0,0)
    vGrip:SetFrameLevel(training:GetFrameLevel()+8)
    -- Horizontal divider: three genuine diamonds rather than a rotated square.
    local diamond='Interface\\AddOns\\AzerothFoundry\\Media\\ResizeDiamond.tga'
    for _,p in ipairs({{x=0,size=12},{x=-16,size=8},{x=16,size=8}}) do
        local t=vGrip:CreateTexture(nil,'OVERLAY');t:SetTexture(diamond)
        t:SetSize(p.size,p.size);t:SetPoint('CENTER',vGrip,'CENTER',p.x,0)
    end
    -- Drag RELATIVELY from the initial pointer and panel height. Deriving
    -- an absolute height from GetCursorPosition/page:GetBottom previously
    -- caused jumps on differently scaled clients. Up = taller Training;
    -- down = taller Comparison. Releasing stores the actual final ratio.
    vGrip:EnableMouse(true)
    vGrip:RegisterForDrag('LeftButton')
    local dragY,dragHeight,dragScale
    local function updateVerticalDrag()
        if not dragY or not GetCursorPosition then return end
        local _,cursorY=GetCursorPosition()
        if type(cursorY)~='number' then return end
        local scale=dragScale or 1
        if scale<=0 then scale=1 end
        training:SetHeight(clampTraining(dragHeight+(cursorY-dragY)/scale))
    end
    local function finishVerticalDrag(self,save)
        if save and dragY then updateVerticalDrag() end
        dragY,dragHeight,dragScale=nil,nil,nil
        self:SetScript('OnUpdate',nil)
        if save then
            local h=page:GetHeight() or 0
            if h>0 then pref.trainingRatio=training:GetHeight()/h end
        end
    end
    vGrip:SetScript('OnDragStart',function(self)
        if not GetCursorPosition then return end
        local _,y=GetCursorPosition()
        if type(y)~='number' then return end
        dragY=y
        dragHeight=training:GetHeight()
        dragScale=page:GetEffectiveScale() or 1
        self:SetScript('OnUpdate',updateVerticalDrag)
    end)
    vGrip:SetScript('OnDragStop',function(self) finishVerticalDrag(self,true) end)
    vGrip:SetScript('OnHide',function(self) finishVerticalDrag(self,false) end)
    vGrip:SetScript('OnEnter',function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self,'ANCHOR_CURSOR')
            GameTooltip:SetText('Resize Profession Workspace',1,.83,.49)
            GameTooltip:AddLine('Drag up: more room for Training & Progress',.93,.85,.68)
            GameTooltip:AddLine('Drag down: more room for Crafter Comparison',.93,.85,.68)
            GameTooltip:Show()
        end
    end)
    vGrip:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)

    -- DIRECTORY: profession-first and character-first are views of the SAME
    -- persistent per-character profession records, never separate databases.
    Header(directory,'Profession Directory')
    local modeProf=B(directory,'By Profession',function()
        settings.workshop.browse='profession';page:Refresh()
    end)
    modeProf:SetPoint('TOPLEFT',directory,'TOPLEFT',12,-46)
    modeProf:SetPoint('TOPRIGHT',directory,'TOP',-3,-46)
    modeProf:SetHeight(24)
    local modeChar=B(directory,'By Character',function()
        settings.workshop.browse='character';page:Refresh()
    end)
    modeChar:SetPoint('TOPLEFT',directory,'TOP',3,-46)
    modeChar:SetPoint('TOPRIGHT',directory,'TOPRIGHT',-12,-46)
    modeChar:SetHeight(24)
    local scopeAll=B(directory,'All Alts',function()
        settings.workshop.scope='all';page:Refresh()
    end)
    scopeAll:SetPoint('TOPLEFT',directory,'TOPLEFT',12,-76)
    scopeAll:SetPoint('TOPRIGHT',directory,'TOP',-3,-76)
    scopeAll:SetHeight(24)
    local scopeExp=B(directory,'Expedition',function()
        settings.workshop.scope='expedition';page:Refresh()
    end)
    scopeExp:SetPoint('TOPLEFT',directory,'TOP',3,-76)
    scopeExp:SetPoint('TOPRIGHT',directory,'TOPRIGHT',-12,-76)
    scopeExp:SetHeight(24)
    local dirHint=Msg(directory,'small',P.ink,30)
    dirHint:SetPoint('TOPLEFT',directory,'TOPLEFT',14,-105)
    dirHint:SetPoint('TOPRIGHT',directory,'TOPRIGHT',-14,-105)
    dirHint:SetJustifyV('TOP')
    local dirList=UI:List(directory,41)
    UI:InsetWorkshopScrollBar(dirList)
    dirList:SetPoint('TOPLEFT',directory,'TOPLEFT',12,-144)
    dirList:SetPoint('BOTTOMRIGHT',directory,'BOTTOMRIGHT',-35,49)
    local scan=B(directory,'Rescan Current',function()
        AF:ScanCharacter();page:Refresh()
    end)
    scan:SetPoint('BOTTOMLEFT',directory,'BOTTOMLEFT',12,12)
    scan:SetPoint('BOTTOMRIGHT',directory,'BOTTOMRIGHT',-12,12)
    scan:SetHeight(25)

    -- COMPARISON: progress and recipe *observations* from each recorded alt.
    Header(compare,'Crafter Comparison')
    local profIcon=compare:CreateTexture(nil,'ARTWORK')
    profIcon:SetSize(39,39)
    profIcon:SetPoint('TOPLEFT',compare,'TOPLEFT',17,-47)
    local profTitle=Msg(compare,'title',P.ink,23)
    profTitle:SetPoint('TOPLEFT',profIcon,'TOPRIGHT',10,0)
    profTitle:SetPoint('TOPRIGHT',compare,'TOPRIGHT',-12,-47)
    local profSub=Msg(compare,'small',P.ink,22)
    profSub:SetPoint('TOPLEFT',profTitle,'BOTTOMLEFT',0,-2)
    profSub:SetPoint('TOPRIGHT',profTitle,'BOTTOMRIGHT',0,-2)
    local rowHead=Msg(compare,'small',P.ink,18)
    rowHead:SetPoint('TOPLEFT',compare,'TOPLEFT',16,-97)
    rowHead:SetPoint('TOPRIGHT',compare,'TOPRIGHT',-14,-97)
    local crafterList=UI:List(compare,63)
    UI:InsetWorkshopScrollBar(crafterList)
    crafterList:SetPoint('TOPLEFT',compare,'TOPLEFT',12,-118)
    crafterList:SetPoint('BOTTOMRIGHT',compare,'BOTTOMRIGHT',-34,43)
    local recipeButton=B(compare,'View Recorded Recipes',function()
        if UI.workshopSelectedCharacter then UI.recipeCharacterFilter=UI.workshopSelectedCharacter end
        UI:Switch('Recipes')
    end)
    recipeButton:SetPoint('BOTTOMRIGHT',compare,'BOTTOMRIGHT',-13,11)
    recipeButton:SetSize(176,25)
    local overviewLabel=Msg(compare,'small',P.ink,20)
    overviewLabel:SetPoint('BOTTOMLEFT',compare,'BOTTOMLEFT',16,14)
    overviewLabel:SetPoint('RIGHT',recipeButton,'LEFT',-7,0)

    -- BOTTOM WORKSPACE: selected crafter on the left, actions on the right.
    Header(training,'Selected Crafter  -  Training & Progress')
    local divider=training:CreateTexture(nil,'BORDER')
    divider:SetColorTexture(.51,.35,.18,.55);divider:SetWidth(1)
    divider:SetPoint('TOP',training,'TOP',0,-44)
    divider:SetPoint('BOTTOM',training,'BOTTOM',0,10)
    local leftLower=CreateFrame('Frame',nil,training)
    leftLower:SetPoint('TOPLEFT',training,'TOPLEFT',14,-46)
    leftLower:SetPoint('BOTTOMRIGHT',training,'BOTTOM',-10,11)
    local rightLower=CreateFrame('Frame',nil,training)
    rightLower:SetPoint('TOPLEFT',training,'TOP',10,-46)
    rightLower:SetPoint('BOTTOMRIGHT',training,'BOTTOMRIGHT',-13,11)
    local selectedIcon=leftLower:CreateTexture(nil,'ARTWORK')
    selectedIcon:SetSize(32,32);selectedIcon:SetPoint('TOPLEFT',leftLower,'TOPLEFT',0,0)
    local selectedLabel=Msg(leftLower,'title',P.ink,24)
    selectedLabel:SetPoint('TOPLEFT',selectedIcon,'TOPRIGHT',10,0)
    selectedLabel:SetPoint('TOPRIGHT',leftLower,'TOPRIGHT',-5,0)
    local selectedContext=Msg(leftLower,'small',P.ink,28)
    selectedContext:SetPoint('TOPLEFT',selectedLabel,'BOTTOMLEFT',0,0)
    selectedContext:SetPoint('TOPRIGHT',selectedLabel,'BOTTOMRIGHT',0,0)
    selectedContext:SetJustifyV('TOP')
    local skillLabel=Msg(leftLower,'small',P.ink,17)
    skillLabel:SetPoint('TOPLEFT',leftLower,'TOPLEFT',0,-66)
    skillLabel:SetPoint('TOPRIGHT',leftLower,'TOPRIGHT',-4,-66)
    local progressSet,track=StyleProgress(leftLower,0,12,85,220)
    local status=Msg(leftLower,'small',P.ink,33)
    status:SetPoint('TOPLEFT',leftLower,'TOPLEFT',0,-100)
    status:SetPoint('TOPRIGHT',leftLower,'TOPRIGHT',-6,-100)
    status:SetJustifyV('TOP')
    local scanLabel=Msg(leftLower,'small',P.ink,16)
    scanLabel:SetPoint('BOTTOMLEFT',leftLower,'BOTTOMLEFT',0,7)
    scanLabel:SetPoint('BOTTOMRIGHT',leftLower,'BOTTOMRIGHT',-4,7)
    local goalHead=Msg(rightLower,'title',P.ink,24)
    goalHead:SetPoint('TOPLEFT',rightLower,'TOPLEFT',0,0)
    goalHead:SetPoint('TOPRIGHT',rightLower,'TOPRIGHT',-160,0)
    goalHead:SetText('Training Goal')
    local goalCopy=Msg(rightLower,'small',P.ink,34)
    goalCopy:SetPoint('TOPLEFT',goalHead,'BOTTOMLEFT',0,-4)
    goalCopy:SetPoint('TOPRIGHT',goalHead,'BOTTOMRIGHT',0,-4)
    goalCopy:SetJustifyV('TOP')
    local goalInput=UI:Input(rightLower,80)
    goalInput:SetPoint('TOPLEFT',goalCopy,'BOTTOMLEFT',0,-5)
    goalInput:SetPoint('TOPRIGHT',goalCopy,'BOTTOMRIGHT',0,-5)
    goalInput:SetHeight(25);goalInput:SetMaxLetters(3)
    local goalState
    local save=B(rightLower,'Save Goal',function()
        local key,prof=UI.workshopSelectedCharacter,UI.workshopSelectedProfession
        if not key or not prof then return end
        local ok,why=AF:SetWorkshopGoal(key,prof,goalInput:GetText())
        if ok then page:Refresh() else goalState:SetText(why or 'Unable to save goal') end
    end)
    save:SetPoint('TOPLEFT',rightLower,'TOPLEFT',0,-98)
    save:SetPoint('TOPRIGHT',rightLower,'TOP',-3,-98)
    save:SetHeight(25)
    local clear=B(rightLower,'Clear Goal',function()
        if AF:ClearWorkshopGoal(UI.workshopSelectedCharacter,UI.workshopSelectedProfession) then
            goalInput:SetText('');page:Refresh()
        end
    end)
    clear:SetPoint('TOPLEFT',rightLower,'TOP',3,-94)
    clear:SetPoint('TOPRIGHT',rightLower,'TOPRIGHT',-2,-94)
    clear:SetHeight(25)
    local beyond=B(rightLower,'Plan Beyond Cap',function()
        rightLower.afOpenFuture=not rightLower.afOpenFuture
        page:Refresh()
    end)
    beyond:SetPoint('TOPLEFT',goalCopy,'BOTTOMLEFT',0,-5)
    beyond:SetPoint('TOPRIGHT',goalCopy,'BOTTOMRIGHT',0,-5)
    beyond:SetHeight(27)
    local goalState=Msg(rightLower,'small',P.ink,26)
    goalState:SetPoint('TOPLEFT',rightLower,'TOPLEFT',0,-127)
    goalState:SetPoint('TOPRIGHT',rightLower,'TOPRIGHT',-4,-127)
    goalState:SetJustifyV('TOP')
    local linked=B(rightLower,'Open Linked Goal',function()
        local goal=AF:GetWorkshopGoal(UI.workshopSelectedCharacter,UI.workshopSelectedProfession)
        local p=AF:GetWorkshopGoalProject(goal)
        if p then UI.selectedProjectId=p.id;UI:Switch('Projects') end
    end)
    linked:SetPoint('TOPRIGHT',rightLower,'TOPRIGHT',-1,0)
    linked:SetSize(151,25)

    local function layoutCompactTraining()
        local compact=(training:GetHeight() or 0)<205
        -- Preserve the primary skill values, goal editor and buttons.
        -- Only the supplementary scan/source and goal status footnotes fold.
        if compact then
            scanLabel:Hide()
            goalState:Hide()
        else
            scanLabel:Show()
            goalState:Show()
        end
    end
    training:HookScript('OnSizeChanged',layoutCompactTraining)
    local previousSelection
    local function choose(key,prof)
        UI.workshopSelectedCharacter=key
        UI.workshopSelectedProfession=prof
        page:Refresh()
    end
    goalInput:SetScript('OnEnterPressed',function(self)
        self:ClearFocus();save:Click()
    end)
    local function RefreshProgressRows(entries,selected)
        UI:FillList(crafterList,entries,function(item)
            choose(item.characterKey,item.professionName)
        end,selected)
        -- Native, unobtrusive progress stripes are attached to rows rather
        -- than to fixed page coordinates: resizing never breaks alignment.
        for i,row in ipairs(crafterList.rows or {}) do
            local item=entries[i]
            if item then
                if not row.afProfTrack then
                    row.afProfTrack=row:CreateTexture(nil,'ARTWORK')
                    row.afProfTrack:SetColorTexture(.28,.20,.12,.70)
                    row.afProfTrack:SetHeight(6)
                    row.afProfTrack:SetPoint('BOTTOMLEFT',row,'BOTTOMLEFT',39,6)
                    row.afProfTrack:SetPoint('BOTTOMRIGHT',row,'BOTTOMRIGHT',-11,6)
                    row.afProfFill=row:CreateTexture(nil,'OVERLAY')
                    row.afProfFill:SetColorTexture(.30,.51,.35,1)
                    row.afProfFill:SetHeight(5)
                    row.afProfFill:SetPoint('BOTTOMLEFT',row.afProfTrack,'BOTTOMLEFT',0,0)
                end
                row.afProfTrack:Show();row.afProfFill:Show()
                row.afProgressFraction=item.progress
                local function updateBar(self)
                    local trackWidth=self.afProfTrack and self.afProfTrack:GetWidth() or 100
                    self.afProfFill:SetWidth(max(1,(trackWidth>8 and trackWidth-1 or 100)*(self.afProgressFraction or 0)))
                end
                if not row.afProgressResizeHook and row.HookScript then
                    row:HookScript('OnSizeChanged',updateBar)
                    row.afProgressResizeHook=true
                end
                updateBar(row)
                if row.label then
                    row.label:ClearAllPoints()
                    row.label:SetPoint('TOPLEFT',row,'TOPLEFT',(item.class or item.icon) and 38 or 10,-1)
                    row.label:SetPoint('BOTTOMRIGHT',row,'BOTTOMRIGHT',-8,16)
                    row.label:SetJustifyV('TOP')
                end
            else
                if row.afProfTrack then row.afProfTrack:Hide();row.afProfFill:Hide() end
            end
        end
    end
    function page:Refresh()
        if not AF.db or not AF.db.characters then return end
        local w=settings.workshop or {}
        local scope=w.scope=='expedition' and 'expedition' or 'all'
        local byCharacter=w.browse=='character'
        UI.WorkshopSetSelected(modeProf,not byCharacter)
        UI.WorkshopSetSelected(modeChar,byCharacter)
        UI.WorkshopSetSelected(scopeAll,scope=='all')
        UI.WorkshopSetSelected(scopeExp,scope=='expedition')
        dirHint:SetText(scope=='all' and 'Known professions across your registered alts.' or
            'Enrolled skills only; charter permissions may restrict sharing.')
        local chars=AF:GetWorkshopCharacters(scope)
        local groups=AF:GetWorkshopProfessions(scope)
        local directoryRows={}
        local chosenChar,chosenProf
        local benchRows={}
        if not byCharacter then
            for _,g in ipairs(groups) do
                directoryRows[#directoryRows+1]={key=g.name,icon=g.icon,label=g.name..'  ('..#g.characters..')'}
            end
            local group
            for _,g in ipairs(groups) do if g.name==UI.workshopSelectedProfession then group=g;break end end
            group=group or groups[1]
            chosenProf=group and group.name or nil
            UI.workshopSelectedProfession=chosenProf
            local found=false
            if group then
                for _,entry in ipairs(group.characters) do
                    if entry.character.key==UI.workshopSelectedCharacter then found=true;break end
                end
                if not found then UI.workshopSelectedCharacter=group.characters[1].character.key end
                chosenChar=UI.workshopSelectedCharacter
                profIcon:SetTexture(group.icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
                profIcon:SetTexCoord(0,1,0,1)
                profTitle:SetText(group.name)
                profSub:SetText(#group.characters..' registered crafter(s)  |  Top recorded '..group.maxSkill..'/'..group.maximum)
                rowHead:SetText('Crafter skills  |  Select a character to manage training')
                for _,entry in ipairs(group.characters) do
                    local c,p=entry.character,entry.profession
                    local observed,learned=ObservedRecipes(c.key,chosenProf)
                    benchRows[#benchRows+1]={key=c.key,characterKey=c.key,professionName=chosenProf,
                        class=c.class,progress=Percent(p.skill,p.maximum),
                        label=(c.name or 'Unknown')..'    '..tostring(p.skill or 0)..'/'..tostring(p.maximum or '?')..
                            '\n'..(AF:GetWorkshopGoal(c.key,chosenProf) and 'Training goal active' or 'No goal')..
                            '  |  '..learned..' learned / '..observed..' observed'}
                end
            end
            UI:FillList(dirList,directoryRows,function(entry)
                UI.workshopSelectedProfession=entry.key
                UI.workshopSelectedCharacter=nil
                page:Refresh()
            end,chosenProf)
        else
            for _,c in ipairs(chars) do
                directoryRows[#directoryRows+1]={key=c.key,class=c.class,label=(c.name or 'Unknown')..'  Lv '..tostring(c.level or '?')}
            end
            local owner
            for _,c in ipairs(chars) do if c.key==UI.workshopSelectedCharacter then owner=c;break end end
            owner=owner or chars[1]
            chosenChar=owner and owner.key or nil
            UI.workshopSelectedCharacter=chosenChar
            if owner then
                local known={}
                for name,p in pairs(owner.professions or {}) do known[#known+1]={name=name,p=p} end
                table.sort(known,function(a,b)return a.name<b.name end)
                local exists=false
                for _,entry in ipairs(known) do if entry.name==UI.workshopSelectedProfession then exists=true end end
                if not exists then UI.workshopSelectedProfession=known[1] and known[1].name end
                chosenProf=UI.workshopSelectedProfession
                profIcon:SetTexture('Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES')
                if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[owner.class] then
                    profIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[owner.class]))
                else profIcon:SetTexCoord(0,1,0,1) end
                profTitle:SetText(owner.name or 'Unknown')
                profSub:SetText('Lv '..tostring(owner.level or '?')..' '..(owner.class or '')..'  |  '..#known..' recorded skill(s)')
                rowHead:SetText('Known skills  |  Select a profession to manage training')
                for _,entry in ipairs(known) do
                    local observed,learned=ObservedRecipes(owner.key,entry.name)
                    benchRows[#benchRows+1]={key=entry.name,characterKey=owner.key,professionName=entry.name,
                        icon=entry.p.icon,progress=Percent(entry.p.skill,entry.p.maximum),
                        label=entry.name..'    '..tostring(entry.p.skill or 0)..'/'..tostring(entry.p.maximum or '?')..
                            '\n'..(AF:GetWorkshopGoal(owner.key,entry.name) and 'Training goal active' or 'No goal')..
                            '  |  '..learned..' learned / '..observed..' observed'}
                end
            end
            UI:FillList(dirList,directoryRows,function(entry)
                UI.workshopSelectedCharacter=entry.key
                UI.workshopSelectedProfession=nil
                page:Refresh()
            end,chosenChar)
        end
        if not chosenChar then UI.workshopSelectedCharacter=nil end
        if not chosenProf then UI.workshopSelectedProfession=nil end
        if not chosenChar then
            profIcon:SetTexture('Interface\\Icons\\INV_Misc_QuestionMark')
            profIcon:SetTexCoord(0,1,0,1)
            profTitle:SetText('No professions recorded')
            profSub:SetText('Log onto a registered character and scan its professions.')
            rowHead:SetText('No comparison available')
        end
        RefreshProgressRows(benchRows,byCharacter and chosenProf or chosenChar)
        overviewLabel:SetText(#benchRows..' recorded '..(byCharacter and 'skill(s)' or 'crafter(s)'))
        recipeButton:SetEnabled(chosenChar~=nil and chosenProf~=nil)
        local c=chosenChar and AF.db.characters[chosenChar]
        local skill=c and c.professions and c.professions[chosenProf]
        local enabled=c~=nil and skill~=nil
        selectedIcon:SetShown(enabled)
        track:SetShown(enabled)
        if not enabled then
            selectedLabel:SetText('Choose a crafter and skill')
            selectedContext:SetText('Select from the directory and comparison list above.')
            skillLabel:SetText('')
            status:SetText('Recorded progress appears here.')
            scanLabel:SetText('Only visited characters can be scanned.')
            goalHead:SetText('Training Goal')
            goalCopy:SetText('No profession selected.')
            goalInput:Hide();save:Hide();clear:Hide();beyond:Hide();linked:Hide()
            goalState:SetText('')
            previousSelection=nil;rightLower.afOpenFuture=false
            return
        end
        local pair=chosenChar..'\t'..chosenProf
        if previousSelection~=pair then rightLower.afOpenFuture=false end
        selectedIcon:SetTexture(skill.icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
        selectedIcon:SetTexCoord(0,1,0,1)
        selectedLabel:SetText((c.name or 'Unknown')..'  -  '..chosenProf)
        selectedContext:SetText((AF:IsExpeditionMember(chosenChar) and 'Expedition' or 'Independent')..
            '  |  '..Stamp(skill.updated or c.professionsScanned))
        local rank,cap=tonumber(skill.skill) or 0,tonumber(skill.maximum) or 0
        skillLabel:SetText('Recorded progress: '..rank..' / '..(cap>0 and cap or 'unknown'))
        progressSet(Percent(rank,cap))
        local observed,learned=ObservedRecipes(chosenChar,chosenProf)
        status:SetText(learned..' learned / '..observed..' observed recipes  |  '..
            (cap>0 and rank>=cap and 'Current tier complete' or 'Skill progression available'))
        scanLabel:SetText(chosenChar==AF:GetCurrentKey() and 'Live character: use Rescan Current for updates.' or
            'Offline alt: showing the last saved snapshot.')
        local goal=AF:GetWorkshopGoal(chosenChar,chosenProf)
        local target=goal and tonumber(goal.target)
        local atCap=cap>0 and rank>=cap
        local aboveCap=atCap and target and target>rank
        goalHead:SetText(atCap and 'Recorded Skill Cap Reached' or 'Training Goal')
        goalCopy:SetText(target and ('Goal: '..target..(rank>=target and '  -  Reached' or '  -  In progress')) or
            (atCap and 'Training tier completed. Plan beyond your current cap if desired.' or
                'Set a target skill to create a linked Foundry goal.'))
        if previousSelection~=pair or not goalInput:HasFocus() then
            goalInput:SetText(target and tostring(target) or '')
        end
        previousSelection=pair
        local editing=(not atCap) or aboveCap or rightLower.afOpenFuture
        goalInput:SetShown(editing);save:SetShown(editing)
        beyond:SetShown(atCap and not aboveCap)
        beyond.label:SetText(rightLower.afOpenFuture and 'Hide Future Goal' or 'Plan Beyond Cap')
        clear:SetShown(goal~=nil)
        -- Show the cap button where the input would normally be. Goal actions
        -- stay in their dedicated workspace, never float over comparison rows.
        goalState:SetText(goal and (goal.complete and 'Target achieved' or 'Progress updates when this alt is scanned')
            or (atCap and 'No new goal required at this tier.' or 'No goal recorded yet.'))
        local p=AF:GetWorkshopGoalProject(goal)
        linked:SetShown(p~=nil)
        layoutCompactTraining()
    end
    page:Refresh()
end
