-- Azeroth Foundry / Workshop / Training (v1.0.30)
-- Upward-moving curated guide, context-sensitive production graph and inspector.
-- Pure presentation: never initiates a protected profession or crafting action on update.
local _, AF = ...
local UI, P = AF.UI, AF.UI.palette
local max,min,ceil,floor = math.max,math.min,math.ceil,math.floor
local unpack=unpack or table.unpack

local function Text(parent,s,x,y,w,h,kind)
    local t=UI:Text(parent,kind or 'small',P.pale)
    t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y)
    if w then t:SetWidth(w) end
    if h then t:SetHeight(h) end
    t:SetJustifyV('TOP')
    t:SetText(s or '')
    return t
end
local function Button(parent,text,callback)
    if UI.WorkshopButton then return UI.WorkshopButton(parent,text,callback) end
    return UI:Button(parent,text,callback)
end
local function Rule(parent,x,y,w,h,rgba)
    local t=parent:CreateTexture(nil,'ARTWORK')
    t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y)
    t:SetSize(w,h)
    local c=rgba or {.69,.50,.25,.8}
    t:SetColorTexture(c[1],c[2],c[3],c[4] or 1)
    return t
end
local function ThemedSurface(parent,rim)
    local surface=parent:CreateTexture(nil,'BACKGROUND')
    surface:SetAllPoints(parent)
    local edge={}
    if rim then
        for _,side in ipairs({'TOP','BOTTOM','LEFT','RIGHT'}) do
            local t=parent:CreateTexture(nil,'BORDER')
            if side=='TOP' then t:SetPoint('TOPLEFT');t:SetPoint('TOPRIGHT');t:SetHeight(1)
            elseif side=='BOTTOM' then t:SetPoint('BOTTOMLEFT');t:SetPoint('BOTTOMRIGHT');t:SetHeight(1)
            elseif side=='LEFT' then t:SetPoint('TOPLEFT');t:SetPoint('BOTTOMLEFT');t:SetWidth(1)
            else t:SetPoint('TOPRIGHT');t:SetPoint('BOTTOMRIGHT');t:SetWidth(1) end
            edge[#edge+1]=t
        end
    end
    local function Paint(_,c)
        local bg=c.dataSurface or {.09,.08,.07}
        local border=c.divider or c.border or {.46,.35,.22}
        surface:SetColorTexture(bg[1],bg[2],bg[3],.98)
        for _,t in ipairs(edge) do t:SetColorTexture(border[1],border[2],border[3],.64) end
    end
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(parent,Paint)
    else Paint(nil,{}) end
    return surface
end
local function ThemeRule(frame,texture,role,opacity)
    if not UI.RegisterThemeTarget then return end
    UI:RegisterThemeTarget(frame,function(_,c)
        local color=c[role] or c.accent2 or {1,.7,.3}
        texture:SetColorTexture(color[1],color[2],color[3],opacity or .85)
    end)
end
local function TypeSize(fontstring,size)
    local font=fontstring and fontstring:GetFont()
    if font then fontstring:SetFont(font,size,'') end
end
local function Item(id)
    local p=id and AF:GetItemPresentation(tonumber(id))
    return p and p.name or ('Item #'..tostring(id or '?')),
        p and p.icon or 'Interface\\Icons\\INV_Misc_QuestionMark'
end
local function Icon(parent,path,x,y,size)
    local t=parent:CreateTexture(nil,'ARTWORK')
    t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y)
    t:SetSize(size or 26,size or 26)
    t:SetTexture(path or 'Interface\\Icons\\INV_Misc_QuestionMark')
    return t
end
local function RecipeIcon(seg)
    if not seg then return 'Interface\\Icons\\INV_Misc_QuestionMark' end
    local id=seg.recipe and seg.recipe.outputItemID
    local _,icon=Item(id)
    return seg.record and seg.record.icon or seg.recipe and seg.recipe.icon or icon
end
-- Use only built-in WoW profession icons. No custom or generated item art.
local PROFESSION_ICONS={
    alchemy='Interface\\Icons\\Trade_Alchemy',
    blacksmithing='Interface\\Icons\\Trade_BlackSmithing',
    enchanting='Interface\\Icons\\Trade_Engraving',
    engineering='Interface\\Icons\\Trade_Engineering',
    leatherworking='Interface\\Icons\\Trade_LeatherWorking',
    tailoring='Interface\\Icons\\Trade_Tailoring',
    cooking='Interface\\Icons\\INV_Misc_Food_15',
    ['first aid']='Interface\\Icons\\INV_Misc_Bandage_15',
}
local function ProfessionIcon(prof)
    return PROFESSION_ICONS[tostring(prof or ''):lower()] or 'Interface\\Icons\\Trade_LeatherWorking'
end
local function SourceText(seg)
    if not seg or seg.learned then return 'Recipe learned' end
    local source=seg.guideAcquisition
    if source=='vendor' then return 'Acquire vendor formula before crafting' end
    if source=='book' then return 'Obtain the skill book or manual first' end
    return 'Visit trainer to learn'
end
local function SourceShort(seg)
    if not seg or seg.learned then return 'LEARNED' end
    if seg.guideAcquisition=='vendor' then return 'VENDOR RECIPE' end
    if seg.guideAcquisition=='book' then return 'BOOK / MANUAL' end
    return 'VISIT TRAINER'
end
local function Coins(value)
    if type(value)~='number' or value<0 then return 'price unknown' end
    local fn=(C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
    if type(fn)=='function' then
        local ok,str=pcall(fn,math.floor(value),13)
        if ok and type(str)=='string' and str~='' then return str end
    end
    -- Old-client fallback: reference Blizzard's existing coin textures.
    local copper=math.floor(value)
    local gold=math.floor(copper/10000)
    local silver=math.floor(copper%10000/100)
    local tiny=copper%100
    local result={}
    local function add(n,path)
        result[#result+1]=tostring(n)..'|TInterface\\MoneyFrame\\'..path..':12:12:0:0|t'
    end
    if gold>0 then add(gold,'UI-GoldIcon') end
    if silver>0 or gold>0 then add(silver,'UI-SilverIcon') end
    add(tiny,'UI-CopperIcon')
    return table.concat(result,' ')
end
local function CoinifyLabel(label)
    if type(label)~='string' then return label end
    -- Older guide recommendations store e.g. 'CHEAPER BY 2g 18s 4c'.
    -- Render those using the same native coin icons as the inspector prices.
    local icon='|TInterface\\MoneyFrame\\UI-%sIcon:12:12:0:0|t'
    label=label:gsub('(%d+)g',function(v)return v..string.format(icon,'Gold')end)
    label=label:gsub('(%d+)s',function(v)return v..string.format(icon,'Silver')end)
    label=label:gsub('(%d+)c',function(v)return v..string.format(icon,'Copper')end)
    return label
end
local DIFFICULTY_LABEL={[0]='Orange - guaranteed',[1]='Yellow - possible',[2]='Green - poor odds',[3]='Gray - no gain'}
local function NativeGuideStatus(seg,skill)
    local r=seg and seg.record
    local d=r and tonumber(r.relativeDifficulty)
    local observed=r and tonumber(r.scannedSkill)
    if d==nil or not observed then return nil end
    local label=DIFFICULTY_LABEL[d]
    if not label then return nil end
    if observed==tonumber(skill) then return '|TInterface\\Icons\\INV_Misc_Spyglass_02:14:14:0:0|t  Live scan: '..label end
    return '|TInterface\\Icons\\INV_Misc_Spyglass_02:14:14:0:0|t  Scan at skill '..tostring(observed)..': '..label
end
local function Node(parent,x,y,w,h,headline,detail,icon,accent)
    local f=CreateFrame('Frame',nil,parent)
    f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y)
    f:SetSize(w,h)
    ThemedSurface(f,true)
    local sheen=f:CreateTexture(nil,'ARTWORK')
    sheen:SetPoint('TOPLEFT',f,'TOPLEFT',3,-4)
    sheen:SetPoint('TOPRIGHT',f,'TOPRIGHT',-3,-4)
    sheen:SetHeight(30)
    local top=Rule(f,2,1,w-4,3,accent and {accent[1],accent[2],accent[3],.95} or nil)
    if not accent then ThemeRule(f,top,'accent2',.96) end
    if UI.RegisterThemeTarget then
        UI:RegisterThemeTarget(f,function(_,tokens)
            local c=tokens.raised or tokens.surface or {.21,.17,.13}
            sheen:SetColorTexture(c[1],c[2],c[3],.22)
        end)
    else sheen:SetColorTexture(.35,.27,.19,.18) end
    local indent=12
    if icon then
        local size=h<86 and 28 or 34
        Icon(f,icon,11,13,size)
        indent=20+size
    end
    local hd=Text(f,headline,indent,10,w-indent-10,31)
    local sep=Rule(f,12,45,max(1,w-24),1,{.45,.45,.45,.17})
    sep:SetShown(h>=94)
    local subY=h>=94 and 51 or 43
    local sub=Text(f,detail,12,subY,w-24,max(12,h-subY-8))
    TypeSize(hd,h<90 and 13 or 14)
    TypeSize(sub,h<90 and 11 or 12)
    if UI.RegisterThemeTarget then
        UI:RegisterThemeTarget(f,function(_,t)
            local tc=t.dataText or {1,.9,.75}
            local titlec=t.accent2 or tc
            hd:SetTextColor(titlec[1],titlec[2],titlec[3],1)
            sub:SetTextColor(tc[1],tc[2],tc[3],1)
            local sc=t.divider or tc
            sep:SetColorTexture(sc[1],sc[2],sc[3],.27)
        end)
    end
    return f,hd,sub
end
local function AlternateIcon(plan,a)
    if not a then return 'Interface\\Icons\\INV_Misc_QuestionMark' end
    for _,c in ipairs(plan and plan.candidates or {}) do
        if c.id==a.recipeID then
            if c.record and c.record.icon then return c.record.icon end
            if c.recipe and c.recipe.icon then return c.recipe.icon end
            local _,icon=Item(c.recipe and c.recipe.outputItemID)
            return icon
        end
    end
    return 'Interface\\Icons\\INV_Misc_QuestionMark'
end
local function AlternateCard(parent,plan,a,x,y,w,h,onClick)
    local b=CreateFrame('Button',nil,parent)
    b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y)
    b:SetSize(w,h)
    b.afTrainingAlternative=a.recipeID
    ThemedSurface(b,true)
    local rail=Rule(b,2,2,3,h-4,{.55,.57,.56,.9})
    ThemeRule(b,rail,'accent2',.90)
    local icon=Icon(b,AlternateIcon(plan,a),12,13,32)
    local title=Text(b,a.name or 'Alternative',53,10,w-63,28)
    TypeSize(title,13)
    local detail=Text(b,CoinifyLabel(a.label or 'Learned alternative')..' / '..(a.price and Coins(a.price) or 'price unknown'),12,44,w-24,h-51)
    TypeSize(detail,11)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(b,function(_,t)
        local ink=t.dataText or {1,.9,.7}
        local accent=t.accent2 or ink
        title:SetTextColor(accent[1],accent[2],accent[3],1)
        detail:SetTextColor(ink[1],ink[2],ink[3],1)
    end) end
    b:SetScript('OnClick',onClick)
    b:SetScript('OnEnter',function(self)
        if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
            GameTooltip:AddLine(a.name or 'Alternate recipe',1,.82,.5)
            GameTooltip:AddLine(CoinifyLabel(a.label or 'Learned alternative')..'\nReagents: '..(a.price and Coins(a.price) or 'auction price incomplete'),1,1,1,true)
            GameTooltip:Show() end
        rail:SetAlpha(1)
    end)
    b:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
    return b
end
local function Hint(frame,title,body)
    frame:EnableMouse(true)
    frame:SetScript('OnEnter',function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
        GameTooltip:AddLine(title or '',1,.81,.42,true)
        if body then GameTooltip:AddLine(body,.96,.93,.82,true) end
        GameTooltip:Show()
    end)
    frame:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
end
local function MaterialQuote(id,qty)
    if AF.GetTrainingMaterialQuote then return AF:GetTrainingMaterialQuote(id,qty) end
    local price=AF:GetTrainingAuctionPrice(id)
    return price and {source='auction',cost=price*qty,unit=price} or {source='unknown'}
end
local function QuoteLabel(quote)
    if quote and quote.cost~=nil then
        return Coins(quote.cost)..(quote.source=='vendor' and '  (Vendor)' or '  (AH)')
    end
    return 'price unavailable'
end
local function CrafterBags(owner,id)
    local inventory=AF.db and AF.db.inventory and AF.db.inventory[owner]
    local bags=inventory and inventory.bags and inventory.bags.counts
    local recorded=type(bags)=='table' and tonumber(bags[tonumber(id)]) or nil
    if owner==AF:GetCurrentKey() then
        local fn=(C_Item and C_Item.GetItemCount) or GetItemCount
        if type(fn)=='function' then
            local ok,value=pcall(fn,tonumber(id),false,false)
            if ok and type(value)=='number' then return max(0,value),true end
        end
    end
    return max(0,recorded or 0), recorded~=nil
end
local function CheckMark(complete,partial)
    if complete then return '|TInterface\\RaidFrame\\ReadyCheck-Ready:17:17:0:0|t' end
    if partial then return '|TInterface\\RaidFrame\\ReadyCheck-Waiting:16:16:0:0|t' end
    return '|TInterface\\RaidFrame\\ReadyCheck-NotReady:15:15:0:0|t'
end
local function CostForStep(seg)
    local sum,known=0,true
    for _,r in ipairs(seg and seg.recipe and seg.recipe.reagents or {}) do
        local id=tonumber(r.itemID)
        local qty=(tonumber(r.quantity) or 1)*(tonumber(seg.quantity) or 0)
        local quote=id and MaterialQuote(id,qty)
        if not quote or quote.cost==nil then known=false else sum=sum+quote.cost end
    end
    return sum,known
end
local function GuideStepProgress(prof,skill)
    local rows=AF.TrainingGuides and AF.TrainingGuides[tostring(prof or ''):lower()]
    for _,r in ipairs(rows or {}) do
        if skill>=r[1] and skill<r[2] then
            return r[1],r[2],max(0,min(1,(skill-r[1])/max(1,r[2]-r[1])))
        end
    end
    return skill,skill+1,0
end
local function SelectedStep(plan,index)
    if not plan then return nil,nil end
    local segments=plan.segments or {}
    local i=max(1,min(#segments,tonumber(index) or 1))
    return segments[i],i
end

function UI:BuildTrainingPlanner(page)
    UI.trainingTargetDrafts=UI.trainingTargetDrafts or {}
    UI.trainingOverrides=UI.trainingOverrides or {}
    UI.trainingMode=UI.trainingMode or 'cheap'
    UI.trainingGraphZoom=UI.trainingGraphZoom or .75
    UI.trainingFocusZoom=UI.trainingFocusZoom or 1.0
    UI.trainingGraphFocus=UI.trainingGraphFocus or false
    UI.trainingGraphStep=UI.trainingGraphStep or 1
    local function DraftKey(owner,prof) return tostring(owner)..'\t'..tostring(prof) end
    local function Calculate(owner,prof,goal)
        if not (AF.HasCuratedTrainingGuide and AF:HasCuratedTrainingGuide(prof)) then
            return nil,'No curated crafting route for '..tostring(prof)..' has been verified yet.'
        end
        return AF:CalculateTrainingGuide(owner,prof,goal,UI.trainingMode,UI.trainingOverrides)
    end

    local heading=CreateFrame('Frame',nil,page)
    heading:SetPoint('TOPLEFT',page,'TOPLEFT',12,-7)
    heading:SetPoint('TOPRIGHT',page,'TOPRIGHT',-12,-7)
    heading:SetHeight(40)
    local headerBg=heading:CreateTexture(nil,'BACKGROUND');headerBg:SetAllPoints(heading)
    headerBg:SetColorTexture(.14,.097,.068,.94)
    local head=Text(heading,'|TInterface\\Icons\\Trade_LeatherWorking:16:16:0:0|t  Profession Training Guide',12,3,nil,17)
    local tagline=Text(heading,'Crafting milestones     |     Trainer unlocks     |     Discovered alternatives',12,22,nil,16)
    tagline:SetTextColor(.79,.68,.50)
    local hr=Rule(heading,7,39,1,1)
    hr:ClearAllPoints();hr:SetPoint('BOTTOMLEFT',heading,'BOTTOMLEFT',7,0)
    hr:SetPoint('BOTTOMRIGHT',heading,'BOTTOMRIGHT',-7,0)
    if UI.ThemeWorkshopIntro then UI:ThemeWorkshopIntro(heading,headerBg,head,tagline,hr) end

    -- The guide occupies the entire left workspace. The former character/sidebar
    -- column is removed; all target editing lives INSIDE the guide header.
    local right=UI:Card(page)
    right:SetWidth(354)
    right:SetPoint('TOPRIGHT',page,'TOPRIGHT',-12,-55)
    right:SetPoint('BOTTOMRIGHT',page,'BOTTOMRIGHT',-12,11)
    local board=UI:Card(page,P.leather)
    board:SetPoint('TOPLEFT',page,'TOPLEFT',12,-55)
    board:SetPoint('BOTTOMRIGHT',right,'BOTTOMLEFT',-10,0)

    local boardTitle=Text(board,'Select a crafter',14,10,252,23)
    boardTitle.afThemeColorManaged=true
    TypeSize(boardTitle,15)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(boardTitle,function(label,c)
        local ink=c.dataText or {1,.9,.75}
        label:SetTextColor(ink[1],ink[2],ink[3],1)
    end) end
    local goalText=Text(board,'TARGET',0,13,62,18)
    goalText:ClearAllPoints()
    goalText:SetPoint('TOPRIGHT',board,'TOPRIGHT',-276,-14)
    local goalInput=UI:Input(board,72)
    goalInput:SetPoint('TOPRIGHT',board,'TOPRIGHT',-198,-8)
    goalInput:SetMaxLetters(3)
    goalInput:SetSize(67,27)
    local applyGoal,clearGoal
    local prevPair
    local function SetMessage(str) UI.trainingMessage=str end
    local function Rebuild(resetChoices)
        local owner,prof=UI.trainingOwner,UI.trainingProfession
        if not owner or not prof then return end
        if resetChoices then UI.trainingOverrides={} end
        local plan,msg=Calculate(owner,prof,goalInput:GetText())
        UI.trainingPlan=plan
        UI.trainingPlanOwner=DraftKey(owner,prof)
        SetMessage(msg)
        if page.Refresh then page:Refresh(true) end
    end
    applyGoal=Button(board,'Set Goal',function()
        local owner,prof=UI.trainingOwner,UI.trainingProfession
        if not owner or not prof then return end
        local val=goalInput:GetText()
        local ok,msg=AF:SetWorkshopGoal(owner,prof,val)
        if not ok then SetMessage(msg);page:Refresh(true);return end
        UI.trainingTargetDrafts[DraftKey(owner,prof)]=val
        Rebuild(true)
    end)
    applyGoal:SetSize(94,27)
    applyGoal:SetPoint('TOPRIGHT',board,'TOPRIGHT',-98,-8)
    clearGoal=Button(board,'Clear',function()
        local owner,prof=UI.trainingOwner,UI.trainingProfession
        if owner and prof then AF:ClearWorkshopGoal(owner,prof) end
        UI.trainingTargetDrafts[DraftKey(owner,prof)]=nil
        prevPair=nil
        UI.trainingPlan=nil
        page:Refresh()
    end)
    clearGoal:SetSize(83,27)
    clearGoal:SetPoint('TOPRIGHT',board,'TOPRIGHT',-10,-8)

    local soundButton=Button(board,'Fanfare: ON',function()
        if not AF.db or not AF.db.settings then return end
        AF.db.settings.workshop=AF.db.settings.workshop or {}
        local settings=AF.db.settings.workshop
        settings.trainingMilestoneSound=not (settings.trainingMilestoneSound~=false)
        page:Refresh(true)
    end)
    soundButton:SetSize(119,26)
    soundButton:SetPoint('TOPLEFT',board,'TOPLEFT',277,-8)
    local progressText=Text(board,'',14,42,nil,18)
    local progressTrack=Rule(board,14,67,1,7,{.26,.23,.19,1})
    progressTrack:ClearAllPoints()
    progressTrack:SetPoint('TOPLEFT',board,'TOPLEFT',14,-65)
    progressTrack:SetPoint('TOPRIGHT',board,'TOPRIGHT',-14,-65)
    progressTrack:SetHeight(7)
    local progressFill=board:CreateTexture(nil,'OVERLAY')
    progressFill:SetPoint('TOPLEFT',progressTrack,'TOPLEFT')
    progressFill:SetColorTexture(.35,.67,.41,1)
    progressFill:SetHeight(7)
    local flash=board:CreateTexture(nil,'OVERLAY')
    flash:SetPoint('TOPLEFT',progressTrack,'TOPLEFT')
    flash:SetPoint('BOTTOMRIGHT',progressTrack,'BOTTOMRIGHT')
    flash:SetColorTexture(1,.79,.28,0)
    local achievement=Text(board,'',14,78,nil,16)
    local focusButton=Button(board,'Focus Current Step',function()
        -- This is another explicit player click suitable for protected native
        -- profession preparation, including after a cold login or close.
        local owner,prof=UI.trainingOwner,UI.trainingProfession
        if owner and prof and owner==AF:GetCurrentKey() and AF.PrepareWorkshopProfessionForScan then
            local ok,msg=AF:PrepareWorkshopProfessionForScan(prof,owner)
            if msg then UI.trainingMessage=msg end
            if ok==false and AF.Print and msg then AF.Print(msg) end
        end
        UI.trainingGraphFocus=true
        UI.trainingGraphStep=1
        if page.DrawGuide then page:DrawGuide(true) end
        page:Refresh(true)
    end)
    focusButton:SetSize(143,24)
    focusButton:SetPoint('TOPLEFT',board,'TOPLEFT',14,-99)
    local previous=Button(board,'<',function()
        UI.trainingGraphFocus=true
        UI.trainingGraphStep=max(1,UI.trainingGraphStep-1)
        if page.DrawGuide then page:DrawGuide(true) end
        page:Refresh(true)
    end)
    previous:SetSize(26,24)
    previous:SetPoint('LEFT',focusButton,'RIGHT',6,0)
    local next=Button(board,'>',function()
        UI.trainingGraphFocus=true
        UI.trainingGraphStep=min(#(UI.trainingPlan and UI.trainingPlan.segments or {}),UI.trainingGraphStep+1)
        if page.DrawGuide then page:DrawGuide(true) end
        page:Refresh(true)
    end)
    next:SetSize(26,24);next:SetPoint('LEFT',previous,'RIGHT',5,0)
    local overview=Button(board,'Overview',function()
        UI.trainingGraphFocus=false
        if page.DrawGuide then page:DrawGuide(true) end
        page:Refresh(true)
    end)
    overview:SetSize(86,24);overview:SetPoint('LEFT',next,'RIGHT',5,0)
    local zoomOut,zoomIn,zoomInfo=nil,nil,nil

    local viewport=CreateFrame('ScrollFrame',nil,board)
    viewport:SetPoint('TOPLEFT',board,'TOPLEFT',12,-136)
    viewport:SetPoint('BOTTOMRIGHT',board,'BOTTOMRIGHT',-12,13)
    viewport:EnableMouse(true)
    viewport:EnableMouseWheel(true)
    local stage,world,worldW,worldH
    local dragX,dragY,dragging
    local panTargetX,panTargetY
    local revealTime=1
    local revealFromScale=1
    local lastDrawnZoom,lastDrawnFocus
    local function Limits()
        return max(0,(stage and stage:GetWidth() or 0)-viewport:GetWidth()),
               max(0,(stage and stage:GetHeight() or 0)-viewport:GetHeight())
    end
    local function ScrollTo(x,y,immediate)
        local maxX,maxY=Limits()
        x=max(0,min(maxX,x or 0));y=max(0,min(maxY,y or 0))
        if immediate then
            panTargetX,panTargetY=nil,nil
            viewport:SetHorizontalScroll(x);viewport:SetVerticalScroll(y)
        else panTargetX,panTargetY=x,y end
    end
    local function PanBy(dx,dy)
        local x=panTargetX or viewport:GetHorizontalScroll() or 0
        local y=panTargetY or viewport:GetVerticalScroll() or 0
        ScrollTo(x+dx,y+dy,true)
    end
    local function MouseDown(_,button)
        if button~='LeftButton' and button~='RightButton' then return end
        if type(GetCursorPosition)~='function' then return end
        dragX,dragY=GetCursorPosition()
        dragging=true
        panTargetX,panTargetY=nil,nil
    end
    local function MouseUp() dragging=false end
    local function DragUpdate()
        if not dragging or not GetCursorPosition then return end
        if IsMouseButtonDown and not (IsMouseButtonDown('LeftButton') or IsMouseButtonDown('RightButton')) then
            dragging=false;return
        end
        local x,y=GetCursorPosition()
        local scale=max(.01,viewport:GetEffectiveScale() or 1)
        PanBy((dragX-x)/scale,(y-dragY)/scale)
        dragX,dragY=x,y
    end
    -- Each mouse-wheel notch moves five percent. The two views retain
    -- separate zoom targets; Focus NEVER becomes Overview from wheel input.
    local targetZoom=UI.trainingGraphZoom or .75
    local targetFocusZoom=UI.trainingFocusZoom or 1.0
    function page:ZoomGuide(delta,reset)
        local focusing=UI.trainingGraphFocus
        if focusing then
            targetFocusZoom=reset and 1.0 or max(.70,min(1.50,targetFocusZoom+(tonumber(delta) or 0)))
        else
            targetZoom=reset and .75 or max(.50,min(1.60,targetZoom+(tonumber(delta) or 0)))
        end
    end
    local function Wheel(_,delta)
        if IsShiftKeyDown and IsShiftKeyDown() then PanBy(-delta*95,0)
        else page:ZoomGuide(delta*.05,false) end
    end
    viewport:SetScript('OnMouseWheel',Wheel)
    viewport:SetScript('OnMouseDown',MouseDown)
    viewport:SetScript('OnMouseUp',MouseUp)
    viewport:SetScript('OnHide',MouseUp)
    local zoomRedrawElapsed=0
    viewport:SetScript('OnUpdate',function(_,dt)
        DragUpdate()
        if page:IsShown() and UI.trainingGraphFocus then
            local old=UI.trainingFocusZoom or 1.0
            local delta=targetFocusZoom-old
            if math.abs(delta)>.00025 then
                local nextZoom=old+delta*(1-math.exp(-math.min(.10,max(0,dt))*14))
                if math.abs(targetFocusZoom-nextZoom)<.001 then nextZoom=targetFocusZoom end
                UI.trainingFocusZoom=nextZoom
                -- Preserve the world coordinate under the center of the viewport.
                -- The stage handles scrolling while its child scales smoothly.
                if stage and world and worldW and worldH then
                    local vw,vh=viewport:GetWidth(),viewport:GetHeight()
                    local cx=((viewport:GetHorizontalScroll() or 0)+vw*.5)/old
                    local cy=((viewport:GetVerticalScroll() or 0)+vh*.5)/old
                    stage:SetSize(worldW*nextZoom,worldH*nextZoom)
                    world:SetScale(nextZoom)
                    if viewport.UpdateScrollChildRect then viewport:UpdateScrollChildRect() end
                    ScrollTo(cx*nextZoom-vw*.5,cy*nextZoom-vh*.5,true)
                end
            end
        end
        if page:IsShown() and not UI.trainingGraphFocus then
            local before=UI.trainingGraphZoom or .75
            local diff=targetZoom-before
            if math.abs(diff)>.0003 then
                local nextZoom=before+diff*(1-math.exp(-math.min(.1,math.max(0,dt))*18))
                if math.abs(targetZoom-nextZoom)<.002 then nextZoom=targetZoom end
                UI.trainingGraphZoom=nextZoom
                -- Animate the visible tree every frame, but rebuild crisp
                -- native-resolution cards only a few times per transition.
                if world and lastDrawnZoom and lastDrawnZoom>0 then
                    world:SetScale(max(.80,min(1.20,nextZoom/lastDrawnZoom)))
                end
                zoomRedrawElapsed=zoomRedrawElapsed+dt
                if zoomRedrawElapsed>=.11 or nextZoom==targetZoom then
                    zoomRedrawElapsed=0
                    page:DrawGuide(true)
                end
            end
        end
        if panTargetX then
            local k=1-math.exp(-max(0,dt)*13)
            local x=viewport:GetHorizontalScroll() or 0
            local y=viewport:GetVerticalScroll() or 0
            local nx=x+(panTargetX-x)*k
            local ny=y+(panTargetY-y)*k
            viewport:SetHorizontalScroll(nx);viewport:SetVerticalScroll(ny)
            if math.abs(nx-panTargetX)<.8 and math.abs(ny-panTargetY)<.8 then
                ScrollTo(panTargetX,panTargetY,true)
            end
        end
        if revealTime<1 and world then
            revealTime=min(1,revealTime+max(0,dt)*5.5)
            local t=1-(1-revealTime)^3
            world:SetAlpha(t)
            world:SetScale((UI.trainingGraphFocus and (UI.trainingFocusZoom or 1) or 1)*
                (revealFromScale+(1-revealFromScale)*t))
        end
    end)
    ThemedSurface(viewport,false)

    -- Right: character selector, total material/cost inspector, then selected-step
    -- materials and price. This is deliberately a compact control surface.
    local crafterHeader=UI:Text(right,'small',P.ink)
    crafterHeader:SetPoint('TOPLEFT',right,'TOPLEFT',13,-11)
    crafterHeader:SetText('|TInterface\\Icons\\INV_Misc_Note_01:15:15:0:0|t  ACTIVE CRAFTER')
    TypeSize(crafterHeader,13)
    local scanButton=Button(right,'|TInterface\\Icons\\INV_Misc_Spyglass_02:13:13:0:0|t Scan',function()
        local owner,prof=UI.trainingOwner,UI.trainingProfession
        if not owner or not prof then return end
        if owner~=AF:GetCurrentKey() then
            UI.trainingMessage='Offline character: log into that character to scan.'
        elseif AF.PrepareWorkshopProfessionForScan then
            local ok,msg=AF:PrepareWorkshopProfessionForScan(prof,owner)
            UI.trainingMessage=msg
            if not ok and AF.Print then AF.Print(msg) end
        end
        if page.Refresh then page:Refresh(true) end
    end)
    scanButton:SetSize(83,23)
    scanButton:SetPoint('TOPRIGHT',right,'TOPRIGHT',-11,-6)
    local choose=Button(right,'Choose profession',function()
        if right.chooser then right.chooser:SetShown(not right.chooser:IsShown()) end
    end)
    choose:SetPoint('TOPLEFT',right,'TOPLEFT',11,-32)
    choose:SetPoint('TOPRIGHT',right,'TOPRIGHT',-11,-32)
    choose:SetHeight(37)
    local chooser=UI:Card(right)
    chooser:SetPoint('TOPLEFT',right,'TOPLEFT',10,-71)
    chooser:SetPoint('TOPRIGHT',right,'TOPRIGHT',-10,-71)
    chooser:SetHeight(205)
    chooser:SetFrameStrata('DIALOG')
    chooser:SetFrameLevel(right:GetFrameLevel()+25)
    chooser:Hide()
    right.chooser=chooser
    local selector=UI:List(chooser,41)
    if UI.InsetWorkshopScrollBar then UI:InsetWorkshopScrollBar(selector) end
    selector:SetPoint('TOPLEFT',chooser,'TOPLEFT',6,-6)
    selector:SetPoint('BOTTOMRIGHT',chooser,'BOTTOMRIGHT',-24,7)
    local status=UI:Text(right,'small',P.ink)
    status:SetPoint('TOPLEFT',right,'TOPLEFT',13,-82)
    status:SetPoint('TOPRIGHT',right,'TOPRIGHT',-10,-82)
    status:SetHeight(56)
    status:SetJustifyV('TOP')

    -- Adjustable division: total shopping requirements above, selected-step
    -- requirements below. Persist as fraction of the sidebar's usable height.
    local totalPane=UI:Card(right,P.leather)
    local stepPane=UI:Card(right,P.leather)
    local splitter=CreateFrame('Button',nil,right)
    splitter:EnableMouse(true)
    splitter:SetHeight(15)
    -- Same Azeroth Foundry diamond artwork as the shared resize grabbers,
    -- turned into a horizontal three-diamond handle for the stacked panes.
    local diamond='Interface\\AddOns\\AzerothFoundry\\Media\\ResizeDiamond.tga'
    for _,v in ipairs({{x=-14,size=8,alpha=.82},{x=0,size=13,alpha=1},{x=14,size=8,alpha=.82}}) do
        local deco=splitter:CreateTexture(nil,'OVERLAY')
        deco:SetPoint('CENTER',splitter,'CENTER',v.x,0)
        deco:SetSize(v.size,v.size)
        deco:SetTexture(diamond)
        deco:SetAlpha(v.alpha)
    end
    local splitterTrack=splitter:CreateTexture(nil,'ARTWORK')
    splitterTrack:SetPoint('LEFT',splitter,'LEFT',5,0)
    splitterTrack:SetPoint('RIGHT',splitter,'RIGHT',-5,0)
    splitterTrack:SetHeight(1)
    ThemeRule(splitter,splitterTrack,'accent2',.65)
    local splitSettings=AF.db and AF.db.settings and AF.db.settings.workshop
    local splitRatio=UI.trainingSidebarSplitRatio or (splitSettings and tonumber(splitSettings.trainingSidebarSplitRatio)) or .57
    local splitDragging,startCursorY,startSplitY
    local function ApplySplit(ratio)
        local hh=max(480,right:GetHeight() or 600)
        local lower=min(312,hh*.51)
        local upper=max(lower,hh-285)
        local absolute=max(lower,min(upper,hh*(ratio or .57)))
        splitRatio=absolute/hh
        totalPane:ClearAllPoints()
        totalPane:SetPoint('TOPLEFT',right,'TOPLEFT',9,-141)
        totalPane:SetPoint('BOTTOMRIGHT',right,'TOPRIGHT',-9,-(absolute-8))
        stepPane:ClearAllPoints()
        stepPane:SetPoint('TOPLEFT',right,'TOPLEFT',9,-(absolute+8))
        stepPane:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-9,45)
        splitter:ClearAllPoints()
        splitter:SetPoint('TOPLEFT',right,'TOPLEFT',9,-(absolute-7))
        splitter:SetPoint('TOPRIGHT',right,'TOPRIGHT',-9,-(absolute-7))
    end
    ApplySplit(splitRatio)
    splitter:SetScript('OnMouseDown',function(_,button)
        if button~='LeftButton' or type(GetCursorPosition)~='function' then return end
        local _,y=GetCursorPosition()
        startCursorY=y
        startSplitY=splitRatio*max(480,right:GetHeight() or 600)
        splitDragging=true
        if GameTooltip then GameTooltip:Hide() end
    end)
    local function EndSplit()
        if not splitDragging then return end
        splitDragging=false
        UI.trainingSidebarSplitRatio=splitRatio
        if AF.db and AF.db.settings then
            AF.db.settings.workshop=AF.db.settings.workshop or {}
            AF.db.settings.workshop.trainingSidebarSplitRatio=splitRatio
        end
    end
    splitter:SetScript('OnMouseUp',function(_,button) if button=='LeftButton' then EndSplit() end end)
    splitter:SetScript('OnHide',EndSplit)
    splitter:SetScript('OnUpdate',function()
        if not splitDragging or type(GetCursorPosition)~='function' then return end
        if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then EndSplit();return end
        local _,y=GetCursorPosition()
        local scale=max(.01,right:GetEffectiveScale() or 1)
        local hh=max(480,right:GetHeight() or 600)
        ApplySplit((startSplitY+(startCursorY-y)/scale)/hh)
    end)
    if right.HookScript then right:HookScript('OnSizeChanged',function() ApplySplit(splitRatio) end) end
    Hint(splitter,'Resize material inspectors','Drag this handle to allocate more space to total materials or the selected training step.')

    local titleTotal=Text(totalPane,'|TInterface\\Icons\\INV_Misc_Bag_08:16:16:0:0|t  GOAL MATERIALS',12,12,nil,22)
    TypeSize(titleTotal,14)
    local titleRule=Rule(totalPane,11,36,250,2)
    titleRule:ClearAllPoints();titleRule:SetPoint('TOPLEFT',totalPane,'TOPLEFT',11,-36)
    titleRule:SetPoint('TOPRIGHT',totalPane,'TOPRIGHT',-11,-36)
    ThemeRule(totalPane,titleRule,'accent2',.60)
    local totalPrice=Text(totalPane,'Awaiting guide',11,43,nil,23)
    local totalMeta=Text(totalPane,'',11,67,nil,20)
    local totalList=UI:List(totalPane,56)
    if UI.InsetWorkshopScrollBar then UI:InsetWorkshopScrollBar(totalList) end
    totalList:SetPoint('TOPLEFT',totalPane,'TOPLEFT',6,-93)
    totalList:SetPoint('BOTTOMRIGHT',totalPane,'BOTTOMRIGHT',-23,8)

    local titleStep=Text(stepPane,'|TInterface\\Icons\\Trade_LeatherWorking:16:16:0:0|t  MILESTONE MATERIALS & CRAFTING',12,12,nil,20)
    TypeSize(titleStep,14)
    local stepRule=Rule(stepPane,11,36,250,2)
    stepRule:ClearAllPoints();stepRule:SetPoint('TOPLEFT',stepPane,'TOPLEFT',11,-36)
    stepRule:SetPoint('TOPRIGHT',stepPane,'TOPRIGHT',-11,-36)
    ThemeRule(stepPane,stepRule,'accent2',.60)
    local stepHeading=Text(stepPane,'No step selected',11,43,310,31)
    local stepPrice=Text(stepPane,'',11,75,310,25)
    local stepNotes=Text(stepPane,'',11,104,310,40)
    local stepList=UI:List(stepPane,56)
    if UI.InsetWorkshopScrollBar then UI:InsetWorkshopScrollBar(stepList) end
    stepList:SetPoint('TOPLEFT',stepPane,'TOPLEFT',6,-195)
    stepList:SetPoint('BOTTOMRIGHT',stepPane,'BOTTOMRIGHT',-24,8)
    local craftNotice=Text(stepPane,'',12,137,310,18)
    local craftOne=Button(stepPane,'Craft 1',function()
        if page.CraftTrainingStep then page:CraftTrainingStep(false) end
    end)
    craftOne:SetPoint('TOPLEFT',stepPane,'TOPLEFT',11,-159)
    craftOne:SetPoint('TOPRIGHT',stepPane,'TOP',-5,-159)
    craftOne:SetHeight(28)
    local craftAll=Button(stepPane,'Craft All',function()
        if page.CraftTrainingStep then page:CraftTrainingStep(true) end
    end)
    craftAll:SetPoint('TOPLEFT',stepPane,'TOP',5,-159)
    craftAll:SetPoint('TOPRIGHT',stepPane,'TOPRIGHT',-12,-159)
    craftAll:SetHeight(28)
    Hint(craftAll,'Craft estimated milestone batch',
        'Craft All requests the estimated remaining batch, limited by live materials. Yellow recipes may grant more or fewer skill-ups. The game, not Foundry, confirms results.')
    function page:CraftTrainingStep(all)
        local plan=UI.trainingPlan
        local seg=SelectedStep(plan,UI.trainingGraphFocus and UI.trainingGraphStep or 1)
        local project,msg=AF:GetTrainingMilestoneCraftProject(plan,seg)
        if not project then UI.trainingCraftNotice=msg;self:Refresh(true);return end
        if AF.GetWorkshopCraftCastProgress and AF:GetWorkshopCraftCastProgress() then
            UI.trainingCraftNotice='A profession craft is still in progress.'
            self:Refresh(true);return
        end
        local ok,response=AF:TryQueuedCraftQuick(project,all)
        if ok and ProfessionsFrame and ProfessionsFrame.IsShown and ProfessionsFrame:IsShown()
            and AF.HideQueueNativeProfession then
            AF:HideQueueNativeProfession()
        end
        UI.trainingCraftNotice=response or (ok and 'Craft requested.' or 'Craft not ready.')
        if AF.Print and response then AF.Print(response) end
        self:Refresh(true)
    end
    local queue=Button(right,'Queue Verified Crafts',function()
        local plan=UI.trainingPlan
        if plan and tonumber(goalInput:GetText())~=plan.target then
            SetMessage('Apply the new target before queuing.');page:Refresh(true);return
        end
        if not plan or not plan.complete or not plan.guideVerified or
            plan.requiresTraining or plan.rankBreakpoint or plan.lowConfidence then
            SetMessage('Train and verify required recipes, then recalculate before queuing.')
            page:Refresh(true);return
        end
        if not StaticPopupDialogs or not StaticPopup_Show then return end
        if not StaticPopupDialogs.AZEROTHFOUNDRY_QUEUE_TRAINING then
            StaticPopupDialogs.AZEROTHFOUNDRY_QUEUE_TRAINING={
                text='Add planned %s crafts to the queue? Yellow skill-ups are estimates; no crafting starts automatically.',
                button1=YES or 'Queue',button2=NO or 'Cancel',
                timeout=0,whileDead=1,hideOnEscape=1,preferredIndex=3,
                OnAccept=function(_,data)
                    if not data or not data.plan then return end
                    local ok,msg=AF:QueueTrainingPath(data.plan)
                    UI.trainingMessage=msg
                    if ok and UI.Switch then UI:Switch('Crafting Queue')
                    elseif data.page then data.page:Refresh(true) end
                end,
            }
        end
        StaticPopup_Show('AZEROTHFOUNDRY_QUEUE_TRAINING',plan.profession,nil,{plan=plan,page=page})
    end)
    queue:SetPoint('BOTTOMLEFT',right,'BOTTOMLEFT',11,11)
    queue:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-11,11)
    queue:SetHeight(27)
    queue:Hide()

    local lastDrawKey,lastRenderedPlan
    local function StepTooltip(seg)
        local str='Skill '..tostring(seg.startSkill)..' to '..tostring(seg.endSkill)..
            '\n~'..tostring(seg.quantity)..' crafts'
        if not seg.learned then str=str..'\n'..SourceText(seg)..'; verify source in Forever.' end
        if seg.guideAcquisitionNote then str=str..'\n'..seg.guideAcquisitionNote end
        if seg.guideUnverified then str=str..'\nGuide step requires live recipe verification.' end
        local cost,known=CostForStep(seg)
        str=str..'\nReagent value: '..(known and Coins(cost) or Coins(cost)..' + unknown quotes')
        return str
    end
    local function AlternateCost(seg,a)
        if a.price then return Coins(a.price) end
        return 'price not available'
    end
    local function UseAlternate(plan,seg,a)
        UI.trainingOverrides=UI.trainingOverrides or {}
        UI.trainingOverrides[seg.startSkill]=a.recipeID
        Rebuild(false)
        UI.trainingGraphFocus=true
        UI.trainingGraphStep=max(1,min(UI.trainingGraphStep,#(UI.trainingPlan and UI.trainingPlan.segments or {})))
        page:DrawGuide(true)
    end
    local function ResetAlternate(seg)
        UI.trainingOverrides=UI.trainingOverrides or {}
        UI.trainingOverrides[seg.startSkill]=nil
        Rebuild(false)
        UI.trainingGraphFocus=true
        page:DrawGuide(true)
    end
    local function ClickFocus(index)
        UI.trainingGraphStep=index
        UI.trainingGraphFocus=true
        page:DrawGuide(true)
        page:Refresh(true)
    end
    function page:DrawGuide(force,scrollToCurrent)
        local plan=UI.trainingPlan
        local zoom=UI.trainingGraphZoom or .85
        local focusing=UI.trainingGraphFocus
        local idx=UI.trainingGraphStep or 1
        local density=zoom>=.90 and 'detail' or zoom>=.70 and 'medium' or 'compact'
        local sig=tostring(plan)..':'..tostring(focusing)..':'..idx..':'..density..':'..tostring(zoom)
        if not force and sig==lastDrawKey then return end
        -- Do not clear active cast/controls refs on the MANY no-op refreshes.
        -- This was why Queue progress worked but Training progress did not.
        UI.trainingFocusedProgressTrack=nil
        UI.trainingFocusedProgressFill=nil
        UI.trainingFocusedProgressLabel=nil
        UI.trainingFocusedCraftNotice=nil
        UI.trainingFocusedCraftOne=nil
        UI.trainingFocusedCraftAll=nil
        lastDrawKey=sig
        local focusChanged=lastDrawnFocus~=nil and lastDrawnFocus~=focusing
        if focusChanged then
            revealFromScale=focusing and .94 or 1.04
        else revealFromScale=1 end
        lastDrawnZoom,lastDrawnFocus=zoom,focusing
        local oldY=viewport:GetVerticalScroll() or 0
        local oldMaxY=select(2,Limits())
        local oldFraction=oldMaxY>0 and oldY/oldMaxY or 1
        local newlyPlanned=lastRenderedPlan~=plan
        lastRenderedPlan=plan
        if stage then stage:Hide();stage:SetParent(nil) end
        local segs=plan and plan.segments or {}
        local vw=tonumber(viewport:GetWidth()) or 0
        local vh=tonumber(viewport:GetHeight()) or 0
        if vw<160 then vw=max(650,(board:GetWidth() or 0)-24) end
        if vh<180 then vh=max(520,(board:GetHeight() or 0)-150) end
        -- Semantic zoom: all artwork and text are rasterized at native UI scale.
        -- Changing zoom changes layout density instead of shrinking glyphs.
        local compact=zoom<.70
        local detail=zoom>=.90
        local factor=max(0,min(1,(zoom-.50)/.65))
        local gap=floor(78+98*factor+.5)
        local nodeW=floor(235+94*factor+.5)
        local nodeH=floor(72+60*factor+.5)
        local topY=98
        local contentHeight=topY+#segs*gap+100
        local w,h
        if focusing then
            w=max(1300,vw)
            local seg=segs[max(1,min(#segs,idx))]
            local altCount=seg and #(seg.alternatives or {}) or 0
            h=max(vh,540+max(0,altCount-3)*81)
        else
            local sideRoom=detail and 262 or 175
            w=max(vw,nodeW+sideRoom*2+64)
            h=max(vh,contentHeight)
        end
        -- In a short, fully visible overview, balance the tree in the viewport
        -- instead of leaving the milestone stack stuck against an edge.
        local centerOffset=not focusing and max(0,(h-contentHeight)*.5) or 0
        stage=CreateFrame('Frame',nil,viewport)
        local focusScale=focusing and (UI.trainingFocusZoom or 1.0) or 1.0
        stage:SetSize(w*focusScale,h*focusScale)
        stage:EnableMouse(true)
        world=CreateFrame('Frame',nil,stage)
        world:SetPoint('CENTER',stage,'CENTER',0,0)
        world:SetSize(w,h)
        world:SetScale(focusScale)
        world:EnableMouse(true)
        for _,f in ipairs({stage,world}) do
            f:SetScript('OnMouseDown',MouseDown)
            f:SetScript('OnMouseUp',MouseUp)
            f:SetScript('OnMouseWheel',Wheel)
            f:EnableMouseWheel(true)
        end
        worldW,worldH=w,h
        viewport:SetScrollChild(stage)
        if viewport.UpdateScrollChildRect then viewport:UpdateScrollChildRect() end
        for x=0,w,132 do
            local grid=Rule(world,x,0,1,h,{.35,.35,.38,.075})
            ThemeRule(world,grid,'divider',.09)
        end
        for y=0,h,104 do
            local grid=Rule(world,0,y,w,1,{.35,.35,.38,.075})
            ThemeRule(world,grid,'divider',.09)
        end
        if #segs==0 then
            local completed=UI.trainingGoalAchieved
            local boxW=min(580,w-48)
            local card=Node(world,(w-boxW)/2,(h-165)/2,boxW,165,
                completed and 'TRAINING GOAL ACHIEVED' or 'CURATED TRAINING DATA NEEDED',
                completed and (tostring(completed.skill)..' / '..tostring(completed.target)..
                    ' skill reached. Set another goal to continue the journey.') or
                (UI.trainingMessage or 'Choose a profession with a verified guide, then set your training goal.'),
                completed and 'Interface\\Icons\\Achievement_General_StayClassy' or
                'Interface\\Icons\\INV_Misc_QuestionMark',
                completed and {.31,.78,.45} or nil)
            ScrollTo(0,0,true)
        elseif focusing then
            local seg=segs[max(1,min(#segs,idx))]
            local innerX=(w-1270)/2
            local subcraftX=innerX+3
            local materialX=innerX+262
            local mainX=innerX+527
            local altX=innerX+911
            local title=Text(world,'MILESTONE  '..tostring(idx)..' / '..tostring(#segs),innerX+18,24,700,27,'title')
            TypeSize(title,19)
            Text(world,tostring(seg.startSkill)..'  -  '..tostring(seg.endSkill)..'  '..tostring(plan.profession)..
                '   /   curated crafting guide with learned alternatives',innerX+18,56,930,28)
            local line=Rule(world,innerX+18,96,958,2)
            ThemeRule(world,line,'accent2',.85)
            local cost,known=CostForStep(seg)
            local live=NativeGuideStatus(seg,plan.current)
            local certainty=seg.estimatedChance==1 and seg.endChance==1 and 'Guaranteed orange' or
                (seg.guideUnverified and (live or 'Future skill colors unverified') or
                ('YELLOW / ESTIMATED '..floor((seg.estimatedChance or 0)*100+.5)..'-'..
                floor((seg.endChance or 0)*100+.5)..'% CHANCE'))
            local sub='Skill '..tostring(seg.startSkill)..' - '..tostring(seg.endSkill)..
                '\n|T'..ProfessionIcon(plan.profession)..':13:13:0:0|t  ~'..tostring(seg.quantity)..' expected crafts'..
                '\n'..certainty..'\n'..SourceText(seg)..
                '\nReagent estimate: '..(known and Coins(cost) or 'incomplete auction prices')
            local recipeCard=Node(world,mainX,163,352,260,seg.name,sub,RecipeIcon(seg))
            local statusStripe=Rule(recipeCard,13,190,326,3)
            ThemeRule(recipeCard,statusStripe,seg.learned and 'success' or 'accent2',.75)
            local cardProgressTrack=Rule(recipeCard,14,199,324,8,{.23,.20,.16,1})
            local cardProgressFill=recipeCard:CreateTexture(nil,'OVERLAY')
            cardProgressFill:SetPoint('TOPLEFT',cardProgressTrack,'TOPLEFT')
            cardProgressFill:SetHeight(8)
            cardProgressFill:SetColorTexture(.31,.78,.45,1)
            local cardProgressLabel=Text(recipeCard,'',14,211,322,16)
            TypeSize(cardProgressLabel,11)
            local focusNotice=Text(recipeCard,'',14,228,322,16)
            TypeSize(focusNotice,11)
            local focusCraftOne=Button(recipeCard,'Craft 1',function() if page.CraftTrainingStep then page:CraftTrainingStep(false) end end)
            focusCraftOne:SetPoint('TOPLEFT',recipeCard,'TOPLEFT',14,-236)
            focusCraftOne:SetPoint('TOPRIGHT',recipeCard,'TOP',-4,-236)
            focusCraftOne:SetHeight(22)
            local focusCraftAll=Button(recipeCard,'Craft All',function() if page.CraftTrainingStep then page:CraftTrainingStep(true) end end)
            focusCraftAll:SetPoint('TOPLEFT',recipeCard,'TOP',4,-236)
            focusCraftAll:SetPoint('TOPRIGHT',recipeCard,'TOPRIGHT',-14,-236)
            focusCraftAll:SetHeight(22)
            UI.trainingFocusedProgressTrack=cardProgressTrack
            UI.trainingFocusedProgressFill=cardProgressFill
            UI.trainingFocusedProgressLabel=cardProgressLabel
            UI.trainingFocusedCraftNotice=focusNotice
            UI.trainingFocusedCraftOne=focusCraftOne
            UI.trainingFocusedCraftAll=focusCraftAll
            local matCard=Node(world,materialX,163,243,260,'MATERIAL INPUTS',
                'Need / Own / Get    -    Select to expand',nil)
            local materials=seg.recipe and seg.recipe.reagents or {}
            local totalBuy,missingQuote=0,false
            local activeBranch=tonumber(UI.trainingMaterialBranch)
            local branchRow
            for i=1,min(#materials,4) do
                local r=materials[i]
                local needed=(tonumber(r.quantity) or 1)*seg.quantity
                local stock=AF:GetInventoryEstimate(r.itemID,'all',plan.characterKey)
                local own=tonumber(stock and stock.total) or 0
                local toGet=max(0,needed-own)
                local price=MaterialQuote(r.itemID,toGet)
                if price.cost then totalBuy=totalBuy+price.cost else missingQuote=missingQuote or toGet>0 end
                local name,icon=Item(r.itemID)
                local ry=72+(i-1)*39
                local b=CreateFrame('Button',nil,matCard)
                b:SetPoint('TOPLEFT',matCard,'TOPLEFT',10,-ry)
                b:SetSize(223,37)
                local iconSize=25
                Icon(b,icon,1,2,iconSize)
                local lbl=Text(b,name,33,0,161,17)
                TypeSize(lbl,12)
                local qty=Text(b,'Need '..needed..' / Own '..own..' / Get '..toGet,33,18,180,18)
                TypeSize(qty,10)
                local inBags,bagsKnown=CrafterBags(plan.characterKey,r.itemID)
                local checked=Text(b,CheckMark(bagsKnown and inBags>=needed,
                    bagsKnown and inBags>0),196,3,22,22)
                Hint(b,name,'Need '..needed..' / Own '..own..' / Get '..toGet..'\n'..
                    'Crafter bags: '..(bagsKnown and tostring(inBags) or 'not scanned')..'\n'..
                    'Missing materials: '..QuoteLabel(price)..'\nClick to inspect possible subcrafts.')
                b:SetScript('OnClick',function()
                    UI.trainingMaterialBranch=activeBranch==tonumber(r.itemID) and nil or tonumber(r.itemID)
                    page:DrawGuide(true)
                end)
                if activeBranch==tonumber(r.itemID) then branchRow={id=r.itemID,qty=toGet,y=ry+20,name=name} end
            end
            local footer=Text(matCard,
                'Estimated AH: '..Coins(totalBuy)..(missingQuote and ' + unpriced' or ''),
                12,229,220,22)
            TypeSize(footer,10)
            if #materials>4 then footer:SetText('Estimated AH: '..Coins(totalBuy)..' + '..tostring(#materials-4)..' more (see sidebar)') end
            if branchRow then
                local choices=AF:GetTrainingMaterialSubcrafts(plan.characterKey,branchRow.id,max(1,branchRow.qty))
                local source=MaterialQuote(branchRow.id,branchRow.qty)
                local title='CRAFT MATERIAL'
                local details='Get '..branchRow.qty..'x '..branchRow.name..'\nBuy missing: '..QuoteLabel(source)
                local branch=Node(world,subcraftX,163,241,260,title,details,
                    'Interface\\Icons\\Trade_LeatherWorking')
                if #choices>0 then
                    local option=choices[1]
                    local comparison=option.cost and source.cost and
                        (option.cost<source.cost and 'Crafting saves '..Coins(source.cost-option.cost) or
                        'Buying saves '..Coins(option.cost-source.cost)) or 'Costs incomplete'
                    local line=Text(branch,'Recipe: '..option.name..'\n'..
                        tostring(option.crafts)..' crafts / '..tostring(option.yield)..' per craft\n'..
                        'Craft value: '..(option.cost and Coins(option.cost) or
                        ('at least '..Coins(option.pricedFloor)..' + unknown'))..'\n'..
                        comparison,12,110,215,92)
                    TypeSize(line,11)
                    local comp={}
                    for i=1,min(#option.materials,3) do
                        comp[#comp+1]=option.materials[i].quantity..'x '..option.materials[i].name
                    end
                    local req=Text(branch,table.concat(comp,'\n'),12,202,217,48)
                    TypeSize(req,10)
                else
                    Text(branch,'No learned subcraft for this material.\nAdditional recipes may become available after scanning.',12,112,215,100)
                end
                local link=Rule(world,subcraftX+241,163+branchRow.y,21,2)
                ThemeRule(world,link,'accent2',.70)
            end
            local matLink=Rule(world,materialX+243,275,40,2)
            ThemeRule(world,matLink,'accent2',.68)
            Text(world,'|TInterface\\Icons\\INV_Misc_Book_11:18:18:0:0|t  DISCOVERED RECIPES',altX,126,309,27,'title')
            local branch=Rule(world,mainX+352,275,32,2)
            ThemeRule(world,branch,'accent2',.70)
            local alternatives=seg.alternatives or {}
            if #alternatives>0 then
                for i=1,#alternatives do
                    local a=alternatives[i]
                    AlternateCard(world,plan,a,altX,165+(i-1)*81,312,72,function() UseAlternate(plan,seg,a) end)
                end
            else
                Node(world,altX,167,312,91,'NO LEARNED ALTERNATIVES',
                    'Discover additional patterns to compare cost and materials.',nil)
            end
            if seg.overridden then
                local reset=Button(world,'Restore Trainer Baseline',function() ResetAlternate(seg) end)
                reset:SetPoint('TOPLEFT',world,'TOPLEFT',mainX,-441)
                reset:SetSize(351,31)
            end
            if not seg.learned then
                local trainerTitle=seg.guideAcquisition=='vendor' and 'ACQUIRE VENDOR RECIPE' or
                    seg.guideAcquisition=='book' and 'OBTAIN BOOK / MANUAL' or
                    ('VISIT '..tostring(plan.profession):upper()..' TRAINER')
                local trainer=Text(world,trainerTitle,mainX,487,480,22)
                TypeSize(trainer,14)
                Text(world,(seg.guideAcquisitionNote or 'Learn or verify the recipe in Forever.')..
                    '\nRequired skill: '..tostring(seg.requiredSkill or seg.startSkill)..'. Recalculate before queueing.',mainX,515,500,54)
            end
            ScrollTo(max(0,(w*(UI.trainingFocusZoom or 1)-vw)/2),0,true)
        else
            -- Native-resolution overview; space and metadata increase at each
            -- zoom tier without changing the actual rendered font resolution.
            local cx=floor(w/2)
            topY=topY+centerOffset
            local spine=Rule(world,cx-1,topY-18,2,#segs*gap+32)
            ThemeRule(world,spine,'accent2',.65)
            local goal=Node(world,cx-103,topY-91,206,66,
                'TRAINING TARGET  '..tostring(plan.target),
                plan.complete and 'Planned milestone' or 'Coverage incomplete',nil)
            for i=#segs,1,-1 do
                local seg=segs[i]
                local y=topY+(#segs-i)*gap
                local nodeX=cx-floor(nodeW/2)
                local state=SourceShort(seg)
                local range=tostring(seg.startSkill)..' - '..tostring(seg.endSkill)
                local oneLine=range..'   /   ~'..tostring(seg.quantity)..' crafts'
                local chance=seg.estimatedChance==1 and seg.endChance==1 and 'ORANGE' or
                    (seg.guideUnverified and (NativeGuideStatus(seg,plan.current) or 'DATA UNVERIFIED') or 'YELLOW')
                local desc=detail and (oneLine..'\n'..chance..'   /   '..state) or oneLine
                local node=Node(world,nodeX,y,nodeW,nodeH,seg.name,desc,RecipeIcon(seg),
                    seg.overridden and {.33,.70,.79} or nil)
                local focus=Button(world,detail and 'INSPECT STEP' or 'INSPECT',function() ClickFocus(i) end)
                focus:SetSize(detail and 107 or 74,compact and 20 or 24)
                focus:SetPoint('BOTTOMRIGHT',node,'BOTTOMRIGHT',-7,compact and 4 or 6)
                Hint(focus,seg.name,StepTooltip(seg))
                if not seg.learned and not compact then
                    local label=Text(world,seg.guideAcquisition=='book' and 'MANUAL' or
                        seg.guideAcquisition=='vendor' and 'VENDOR' or 'TRAINER',nodeX-83,y+22,76,24)
                    TypeSize(label,11)
                    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(label,function(t,c)
                        local a=c.accent2 or {1,.7,.3}
                        t:SetTextColor(a[1],a[2],a[3],1)
                    end) end
                end
                local alternatives=seg.alternatives or {}
                if #alternatives>0 then
                    local branchX=nodeX+nodeW+24
                    local branchLine=Rule(world,nodeX+nodeW,y+nodeH/2,24,2)
                    ThemeRule(world,branchLine,'accent2',.75)
                    if compact then
                        local a=alternatives[1]
                        local branchCard=Node(world,branchX,y+5,164,57,
                            tostring(#alternatives)..' DISCOVERED',
                            'Inspect choices',AlternateIcon(plan,a))
                        local hit=CreateFrame('Button',nil,branchCard)
                        hit:SetAllPoints(branchCard)
                        hit:SetScript('OnClick',function() ClickFocus(i) end)
                        Hint(hit,'Discovered recipe branches','Click to inspect '..tostring(#alternatives)..
                            ' alternate recipes and their material estimates.')
                    else
                        local a=alternatives[1]
                        local text=tostring(#alternatives)..' ALTERNATIVE'..(#alternatives==1 and '' or 'S')
                        local branchCard=Node(world,branchX,y+12,210,72,text,
                            a.name or 'Discovered recipe',AlternateIcon(plan,a))
                        local hit=CreateFrame('Button',nil,branchCard)
                        hit:SetAllPoints(branchCard)
                        hit:SetScript('OnClick',function() ClickFocus(i) end)
                        Hint(hit,'Discovered recipe branches','Focus to compare learned alternatives and their auction prices.')
                    end
                end
                if detail then
                    local mats=seg.recipe and seg.recipe.reagents or {}
                    local sum,complete=CostForStep(seg)
                    local side=Node(world,nodeX-226,y+16,201,95,'RECIPE INPUTS',
                        tostring(#mats)..' types  /  '..(complete and Coins(sum) or 'price incomplete'),nil)
                    local link=Rule(world,nodeX-25,y+nodeH/2,25,2)
                    ThemeRule(world,link,'accent2',.70)
                end
            end
            local startY=topY+#segs*gap
            local start=Node(world,cx-102,startY,204,68,'YOU ARE HERE',
                tostring(plan.current)..' skill',nil,{.30,.72,.47})
            local maxX,maxY=Limits()
            local targetY
            if newlyPlanned or scrollToCurrent then targetY=maxY
            else targetY=maxY*oldFraction end
            ScrollTo((w-vw)/2,targetY,true)
        end
        -- Eased visual reveal on each density/focus change. Everything is
        -- native-resolution at the end of the 180 ms transition.
        if focusChanged then
            revealTime=0
            world:SetAlpha(.18)
            world:SetScale((focusing and (UI.trainingFocusZoom or 1) or 1)*revealFromScale)
        else
            revealTime=1
            world:SetAlpha(1)
            world:SetScale(focusing and (UI.trainingFocusZoom or 1) or 1)
        end
    end

    -- Session-local milestone animation. It only celebrates real recorded
    -- skill increases, not loading cached data or merely clicking Craft.
    local lastSkill,lastSkillPair,animatedValue,desiredValue= nil,nil,0,0
    local flashTime=0
    local normalStatus=''
    local milestoneCelebration
    local carnival=CreateFrame('Frame',nil,board)
    carnival:SetAllPoints(viewport)
    carnival:SetFrameLevel(viewport:GetFrameLevel()+45)
    carnival:EnableMouse(false)
    carnival:Hide()
    local carnivalDim=carnival:CreateTexture(nil,'BACKGROUND')
    carnivalDim:SetAllPoints(carnival)
    carnivalDim:SetColorTexture(.10,.035,.18,.65)
    local ticket=CreateFrame('Frame',nil,carnival)
    ticket:SetSize(530,180)
    ticket:SetPoint('CENTER',carnival,'CENTER',0,30)
    local ticketBg=ticket:CreateTexture(nil,'BACKGROUND')
    ticketBg:SetAllPoints(ticket)
    ticketBg:SetColorTexture(.21,.075,.32,.98)
    local ticketBorder={}
    for _,side in ipairs({'TOP','BOTTOM','LEFT','RIGHT'}) do
        local t=ticket:CreateTexture(nil,'BORDER')
        if side=='TOP' then t:SetPoint('TOPLEFT');t:SetPoint('TOPRIGHT');t:SetHeight(3)
        elseif side=='BOTTOM' then t:SetPoint('BOTTOMLEFT');t:SetPoint('BOTTOMRIGHT');t:SetHeight(3)
        elseif side=='LEFT' then t:SetPoint('TOPLEFT');t:SetPoint('BOTTOMLEFT');t:SetWidth(3)
        else t:SetPoint('TOPRIGHT');t:SetPoint('BOTTOMRIGHT');t:SetWidth(3) end
        t:SetColorTexture(.99,.73,.24,.92)
        ticketBorder[#ticketBorder+1]=t
    end
    local ticketIcon=Icon(ticket,'Interface\\Icons\\INV_Misc_Ticket_Darkmoon_01',23,41,86)
    local showTitle=Text(ticket,'DARKMOON MILESTONE!',126,25,384,35,'title')
    TypeSize(showTitle,24)
    showTitle:SetTextColor(1,.79,.29,1)
    local showSkill=Text(ticket,'',128,67,382,29)
    TypeSize(showSkill,17)
    showSkill:SetTextColor(1,.94,.74,1)
    local showSub=Text(ticket,'',128,105,382,45)
    TypeSize(showSub,13)
    showSub:SetTextColor(.90,.80,1,1)
    local lights={}
    for i=1,30 do
        local particle=carnival:CreateTexture(nil,'OVERLAY')
        particle:SetTexture('Interface\\Cooldown\\star4')
        particle:SetBlendMode('ADD')
        particle:SetSize(11+(i%4)*4,11+(i%4)*4)
        local hue=i%3
        if hue==0 then particle:SetVertexColor(1,.76,.26,1)
        elseif hue==1 then particle:SetVertexColor(.69,.31,1,1)
        else particle:SetVertexColor(1,.94,.77,1) end
        lights[#lights+1]=particle
    end
    local function BeginMilestoneCelebration(prof,level,goal)
        if milestoneCelebration then return end
        milestoneCelebration={elapsed=0,phase='close',level=level,profession=prof,
            lastGoal=goal,startedFocused=UI.trainingGraphFocus,overview=false}
        ticket:SetAlpha(1)
        carnival:Show()
        showSkill:SetText(tostring(prof)..'  /  SKILL '..tostring(level))
        showSub:SetText(goal and level>=goal and
            'TRAINING GOAL COMPLETE  -  A STANDING OVATION!' or
            'STEP CLEARED! THE NEXT ACT AWAITS...')
        local settings=AF.db and AF.db.settings and AF.db.settings.workshop
        if not settings or settings.trainingMilestoneSound~=false then
            -- Try a client-provided Darkmoon Carousel cue; it is never
            -- bundled, and older clients fall back to an achievement stinger.
            local played=false
            if type(PlaySoundFile)=='function' and type(StopSound)=='function' then
                local ok,success,handle=pcall(PlaySoundFile,772749,'SFX')
                if ok and success then
                    milestoneCelebration.darkmoonSoundHandle=handle
                    played=true
                end
            end
            if not played and type(PlaySound)=='function' then
                local sound=SOUNDKIT and (SOUNDKIT.ACHIEVEMENT_EARNED or SOUNDKIT.UI_ACHIEVEMENT_TOAST)
                pcall(PlaySound,sound or 888,'SFX')
            end
        end
    end
    local function AnimateMilestoneCelebration(dt)
        local event=milestoneCelebration
        if not event then return end
        event.elapsed=event.elapsed+max(0,dt)
        local t=event.elapsed
        if not event.overview and t>=1.10 then
            event.overview=true
            event.phase='overview'
            UI.trainingGraphFocus=false
            UI.trainingGraphStep=1
            if page.DrawGuide then page:DrawGuide(true,true) end
            local settings=AF.db and AF.db.settings and AF.db.settings.workshop
            if (not settings or settings.trainingMilestoneSound~=false) and
                not event.darkmoonSoundHandle and type(PlaySound)=='function' then
                local sound=SOUNDKIT and (SOUNDKIT.LEVEL_UP or SOUNDKIT.UI_ACHIEVEMENT_TOAST)
                pcall(PlaySound,sound or 888,'SFX')
            end
            animatedValue=0
            desiredValue=(UI.trainingGoalAchieved and 1 or 0)
        end
        local alpha=t<.20 and t/.20 or (t>3.20 and max(0,(3.85-t)/.65) or 1)
        carnival:SetAlpha(alpha)
        -- Native UI textures only; deterministic confetti and starbursts, no
        -- custom art, music assets, or replacement game item icons.
        local sweep=min(1,t/2.5)
        for i,p in ipairs(lights) do
            local angle=(i*2.39996)+(t*.75*(i%2==0 and 1 or -1))
            local radius=(80+(i%6)*21)+sweep*(110+(i%4)*25)
            local x=math.cos(angle)*radius
            local y=math.sin(angle)*radius+(t*24*(i%3-1))
            p:ClearAllPoints()
            p:SetPoint('CENTER',ticket,'CENTER',x,y)
            p:SetAlpha(alpha*(.65+.35*math.sin(t*7+i)))
        end
        if not event.overview and world then
            local fade=t<.60 and 1 or max(0,1-(t-.60)/.50)
            world:SetAlpha(fade)
        end
        if t>=3.85 then
            if event.darkmoonSoundHandle and type(StopSound)=='function' then
                pcall(StopSound,event.darkmoonSoundHandle)
            end
            carnival:Hide()
            milestoneCelebration=nil
            if world then world:SetAlpha(1) end
            if page.Refresh then page:Refresh(true) end
        end
    end
    local function Feedback(skill,prof,owner)
        local key=DraftKey(owner,prof)
        local a,b,nextFraction=GuideStepProgress(prof,skill)
        local targetNumber=tonumber(goalInput:GetText())
        if targetNumber and targetNumber>a and targetNumber<b then
            b=targetNumber
            nextFraction=max(0,min(1,(skill-a)/max(1,b-a)))
        end
        local stepReached=false
        if key==lastSkillPair and lastSkill and skill>lastSkill then
            local _,oldEnd=GuideStepProgress(prof,lastSkill)
            if targetNumber and targetNumber<oldEnd then oldEnd=targetNumber end
            stepReached=skill>=oldEnd
            if stepReached then
                flashTime=1.25
                achievement:SetText('MILESTONE COMPLETE  /  '..tostring(oldEnd)..' '..tostring(prof))
                BeginMilestoneCelebration(prof,oldEnd,targetNumber)
            else
                achievement:SetText('SKILL ADVANCED  /  '..tostring(skill))
                flashTime=.6
            end
            -- Hold the just-completed step at 100% during the curtain-close
            -- rather than immediately resetting the bar to the next step.
        end
        if key~=lastSkillPair then animatedValue=nextFraction end
        if targetNumber and skill>=targetNumber then nextFraction=1 end
        lastSkillPair=key;lastSkill=skill
        desiredValue=(milestoneCelebration and not milestoneCelebration.overview) and 1 or nextFraction
        progressText:SetText(targetNumber and skill>=targetNumber and
            ('GOAL COMPLETE  /  '..tostring(skill)..' / '..tostring(targetNumber)..' skill') or
            ('CURRENT '..tostring(skill)..'  /  NEXT MILESTONE '..tostring(b)..
            '   ('..tostring(max(0,b-skill))..' skill points remaining)'))
    end
    local animation=CreateFrame('Frame',nil,board)
    animation:SetScript('OnUpdate',function(_,dt)
        if not board:IsShown() then return end
        AnimateMilestoneCelebration(dt)
        animatedValue=animatedValue+(desiredValue-animatedValue)*min(1,dt*6)
        progressFill:SetWidth(max(1,(progressTrack:GetWidth()>0 and progressTrack:GetWidth() or 700)*animatedValue))
        local cast=AF.GetWorkshopCraftCastProgress and AF:GetWorkshopCraftCastProgress() or nil
        if UI.trainingFocusedProgressFill and UI.trainingFocusedProgressTrack then
            local width=(UI.trainingFocusedProgressTrack:GetWidth()>0 and UI.trainingFocusedProgressTrack:GetWidth() or 1)
            UI.trainingFocusedProgressFill:SetWidth(max(1,width*((cast and cast.fraction) or 0)))
        end
        if UI.trainingFocusedProgressLabel then
            if cast then
                UI.trainingFocusedProgressLabel:SetText(string.format('%s  -  %.1fs remaining',
                    cast.name or 'Crafting',cast.remaining or 0))
            else
                local request=AF.lastQueueCraftRequest
                local activeRecipe=UI.trainingPlan and UI.trainingPlan.segments and
                    UI.trainingPlan.segments[UI.trainingGraphStep or 1]
                local requestId=activeRecipe and ('training-milestone-'..tostring(activeRecipe.recipeID))
                local pending=request and request.projectID==requestId and
                    (request.status=='request_sent' or request.status=='cast_started' or
                     request.status=='craft_started')
                UI.trainingFocusedProgressLabel:SetText(pending and
                    'Craft requested - waiting for cast timing / result...' or
                    'Craft timing appears here when the game starts a craft.')
            end
        end
        if flashTime>0 then
            flashTime=max(0,flashTime-dt)
            flash:SetColorTexture(1,.79,.28,.36*min(1,flashTime*2))
            achievement:SetAlpha(min(1,flashTime*3))
        else
            flash:SetColorTexture(1,.79,.28,0)
            achievement:SetText(normalStatus)
            achievement:SetAlpha(.85)
        end
    end)
    local poll=CreateFrame('Frame',nil,page)
    local pollSeconds=0
    poll:SetScript('OnUpdate',function(_,dt)
        if not page:IsShown() then return end
        pollSeconds=pollSeconds+dt
        if pollSeconds<.9 then return end
        pollSeconds=0
        local owner,prof=UI.trainingOwner,UI.trainingProfession
        local char=AF.db and AF.db.characters and AF.db.characters[owner]
        local profData=char and char.professions and char.professions[prof]
        local skill=tonumber(profData and profData.skill)
        if skill and lastSkillPair==DraftKey(owner,prof) and lastSkill and skill~=lastSkill then
            page:Refresh(true)
        end
    end)

    local auctionRefresh=CreateFrame('Frame',nil,page)
    auctionRefresh:RegisterEvent('AUCTION_HOUSE_CLOSED')
    auctionRefresh:SetScript('OnEvent',function()
        local plan=UI.trainingPlan
        if plan and plan.guideMode and UI.trainingOwner and UI.trainingProfession and
            tonumber(goalInput:GetText())==plan.target then
            local result=Calculate(UI.trainingOwner,UI.trainingProfession,goalInput:GetText())
            if result then UI.trainingPlan=result;page:Refresh(true) end
        end
    end)
    local options={}
    local function ChooseProfession(entry)
        UI.trainingOwner,UI.trainingProfession=entry.owner,entry.profession
        UI.workshopSelectedCharacter,UI.workshopSelectedProfession=entry.owner,entry.profession
        UI.trainingPlan=nil;UI.trainingOverrides={};UI.trainingGraphFocus=false;UI.trainingGraphStep=1
        chooser:Hide();prevPair=nil
        if entry.owner==AF:GetCurrentKey() then
            local ok,msg=EnsureTrainingScan('force')
            if msg then SetMessage(msg) end
            if ok==false and AF.Print then AF.Print(msg) end
        else SetMessage('Offline character: log into this character to refresh its recipes.') end
        page:Refresh()
    end
    goalInput:SetScript('OnTextChanged',function(self,userInput)
        if not userInput then return end
        if UI.trainingOwner and UI.trainingProfession then
            UI.trainingTargetDrafts[DraftKey(UI.trainingOwner,UI.trainingProfession)]=self:GetText()
        end
        SetMessage('Target changed. Set Goal to recalculate.')
    end)
    function page:Refresh(preserveInput)
        options={}
        for _,c in ipairs(AF:GetWorkshopCharacters('all')) do
            for name,p in pairs(c.professions or {}) do
                -- Gathering and fishing cannot level via craft recipes; leave
                -- those professions in the normal Professions page instead.
                if AF.HasCuratedTrainingGuide and AF:HasCuratedTrainingGuide(name) then
                    options[#options+1]={owner=c.key,profession=name,key=c.key..'\t'..name,
                        label=(c.name or 'Character')..' / '..name..'\n'..
                            tostring(p.skill or '?')..' / '..tostring(p.maximum or '?')..' skill'}
                end
            end
        end
        table.sort(options,function(a,b)return a.label<b.label end)
        local owner=UI.trainingOwner or UI.workshopSelectedCharacter
        local prof=UI.trainingProfession or UI.workshopSelectedProfession
        local found
        for _,o in ipairs(options) do
            if o.owner==owner and o.profession==prof then found=true;break end
        end
        if not found then
            local first
            for _,o in ipairs(options) do
                if o.owner==AF:GetCurrentKey() and AF:HasCuratedTrainingGuide(o.profession) then
                    first=o;break
                end
            end
            if not first then
                for _,o in ipairs(options) do if o.owner==AF:GetCurrentKey() then first=o;break end end
            end
            first=first or options[1]
            owner,prof=first and first.owner,first and first.profession
            UI.trainingOwner,UI.trainingProfession=owner,prof
        end
        UI:FillList(selector,options,ChooseProfession,DraftKey(owner,prof))
        local char=owner and AF.db and AF.db.characters and AF.db.characters[owner]
        local p=char and char.professions and char.professions[prof]
        local goal=p and AF:GetWorkshopGoal(owner,prof)
        local pair=DraftKey(owner,prof)
        if prevPair~=pair then
            goalInput:SetText(UI.trainingTargetDrafts[pair] or tostring(goal and goal.target or
                (p and min(999,(p.skill or 0)+25) or 150)))
            UI.trainingGraphFocus=false;UI.trainingGraphStep=1
        end
        prevPair=pair
        local workshopSettings=AF.db and AF.db.settings and AF.db.settings.workshop
        if soundButton.label then soundButton.label:SetText((not workshopSettings or workshopSettings.trainingMilestoneSound~=false)
            and 'Fanfare: ON' or 'Fanfare: OFF') end
        choose.label:SetText((char and char.name or 'Character')..' / '..tostring(prof or 'Profession')..
            '\n'..tostring(p and p.skill or '?')..' / '..tostring(p and p.maximum or '?')..' skill')
        clearGoal:SetShown(goal~=nil)
        boardTitle:SetText(tostring(prof or 'Profession')..'  /  GUIDE')
        head:SetText('|T'..ProfessionIcon(prof)..':16:16:0:0|t  Profession Training Guide')
        titleStep:SetText('|T'..ProfessionIcon(prof)..':16:16:0:0|t  CURRENT MILESTONE')
        local ready,reason=AF:GetProfessionReferenceStatus()
        local a=type(Auctionator)=='table' and Auctionator.API and Auctionator.API.v1 and
            type(Auctionator.API.v1.GetAuctionPriceByItemID)=='function'
        local ah=AF:GetTrainingAuctionFreshness(UI.trainingPlan and UI.trainingPlan.materials)
        status:SetText((ready and '|cff77cc77ProfessionDB ready|r' or
            '|cffffa15bProfessionDB incomplete|r')..'  /  '..(a and 'AH prices available' or 'No AH prices')..'\n'..
            tostring(ah or 'Scan freshness unavailable'))
        local plan=UI.trainingPlan
        if plan and (plan.characterKey~=owner or plan.profession~=prof) then plan=nil;UI.trainingPlan=nil end
        local recordedSkill=tonumber(p and p.skill) or 0
        local requestedGoal=tonumber(goalInput:GetText())
        local achieved=p and requestedGoal and recordedSkill>=requestedGoal
        UI.trainingGoalAchieved=achieved and {skill=recordedSkill,target=requestedGoal} or nil
        if achieved then
            plan=nil
            UI.trainingPlan=nil
            SetMessage('Training goal achieved! Choose a higher target to continue.')
        elseif plan and tonumber(goalInput:GetText())~=plan.target then
            SetMessage('Target changed. Set Goal to calculate the new route.')
        elseif not plan and p and tonumber(goalInput:GetText()) and
            tonumber(goalInput:GetText())>(tonumber(p.skill) or 0) then
            local result,msg=Calculate(owner,prof,goalInput:GetText())
            if result then plan=result;UI.trainingPlan=result else SetMessage(msg) end
        end
        if plan and tonumber(goalInput:GetText())==plan.target and
            AF:GetTrainingGuideSignature(owner,prof)~=plan.signature then
            local result,msg=Calculate(owner,prof,goalInput:GetText())
            if result then plan=result;UI.trainingPlan=result
            else plan=nil;UI.trainingPlan=nil;SetMessage(msg) end
        end
        local curr=tonumber(p and p.skill) or 0
        if p and owner then Feedback(curr,prof,owner) end
        local seg,segIndex=SelectedStep(plan,UI.trainingGraphFocus and UI.trainingGraphStep or 1)
        if plan then
            local stale=tonumber(goalInput:GetText())~=plan.target
            local goalTotal,missingPrice=0,false
            for _,mat in ipairs(plan.materials or {}) do
                local count=max(0,tonumber(mat.missing) or 0)
                if count>0 then
                    local q=MaterialQuote(mat.id,count)
                    if q.cost~=nil then goalTotal=goalTotal+q.cost else missingPrice=true end
                end
            end
            totalPrice:SetText('To get: '..(missingPrice and
                ('at least '..Coins(goalTotal)..' + unknown quotes') or Coins(goalTotal))..'  (AH/vendor)')
            totalMeta:SetText('~'..tostring(plan.craftCount or 0)..' crafts  |  '..
                tostring(#(plan.materials or {}))..' materials  |  '..
                (plan.guideWarnings>0 and plan.guideWarnings..' verify' or 'verified'))
            local totalRows={}
            for _,mat in ipairs(plan.materials or {}) do
                local name,icon=Item(mat.id)
                totalRows[#totalRows+1]={key=mat.id,icon=icon,
                    label=CheckMark(mat.owned>=mat.needed,mat.owned>0)..' '..name..'\nNeed '..mat.needed..' / Own '..mat.owned..' / Get '..mat.missing..'\n'..
                        QuoteLabel(MaterialQuote(mat.id,mat.missing))}
            end
            UI:FillList(totalList,totalRows,function(row)
                SetMessage('Material '..tostring(row.key)..' uses recorded inventory. Prices are recorded Auctionator quotes.')
            end)
            if seg then
                local full,completePrice=CostForStep(seg)
                stepHeading:SetText(tostring(seg.startSkill)..' - '..tostring(seg.endSkill)..'  '..seg.name)
                local neededCost,unknownCost=0,false
                for _,r in ipairs(seg.recipe.reagents or {}) do
                    local count=(tonumber(r.quantity) or 1)*seg.quantity
                    local stock=AF:GetInventoryEstimate(r.itemID,'all',plan.characterKey)
                    local own=tonumber(stock and stock.total) or 0
                    local q=MaterialQuote(r.itemID,max(0,count-own))
                    if q.cost then neededCost=neededCost+q.cost
                    elseif count>own then unknownCost=true end
                end
                stepPrice:SetText('~'..tostring(seg.quantity)..' crafts | Get: '..
                    (unknownCost and ('at least '..Coins(neededCost)..' + unknown') or Coins(neededCost)))
                stepNotes:SetText(SourceText(seg)..
                    (seg.overridden and ' | Personal choice' or ' | Curated guide')..
                    ' | '..tostring(#(seg.alternatives or {}))..' alternatives'..
                    '\n'..(NativeGuideStatus(seg,plan.current) or
                        (seg.guideUnverified and 'Verify future skill difficulty' or 'Recipe difficulty recorded')))
                local rows={}
                for _,r in ipairs(seg.recipe.reagents or {}) do
                    local name,icon=Item(r.itemID)
                    local qty=(r.quantity or 1)*seg.quantity
                    local stock=AF:GetInventoryEstimate(r.itemID,'all',owner)
                    local owned=tonumber(stock and stock.total) or 0
                    local missing=max(0,qty-owned)
                    local price=AF:GetTrainingAuctionPrice(r.itemID)
                    local inBags,bagsKnown=CrafterBags(plan.characterKey,r.itemID)
                    rows[#rows+1]={key=r.itemID,icon=icon,
                        label=CheckMark(bagsKnown and inBags>=qty,bagsKnown and inBags>0)..' '..name..'\nNeed '..qty..' / Own '..owned..' / Get '..missing..'\n'..
                            QuoteLabel(MaterialQuote(r.itemID,missing))}
                end
                UI:FillList(stepList,rows,function()end)
                local temporary,why=AF:GetTrainingMilestoneCraftProject(plan,seg)
                local quick=temporary and AF:GetQueuedCraftQuickAction(temporary)
                local busy=AF.GetWorkshopCraftCastProgress and AF:GetWorkshopCraftCastProgress()
                craftOne:Hide(); craftAll:Hide(); craftNotice:SetText('')
                local focusOne,focusAll,focusNotice=UI.trainingFocusedCraftOne,UI.trainingFocusedCraftAll,UI.trainingFocusedCraftNotice
                if focusOne and focusAll then
                    focusOne:SetEnabled(not busy and quick and quick.canQuickCraft==true or false)
                    focusAll:SetEnabled(not busy and quick and quick.canQuickCraft==true and
                        (quick.canCraftAll~=false or not quick.ready) or false)
                    local amount=quick and (quick.batchCount or 0) or 0
                    focusAll.label:SetText(amount>0 and ('Craft All ('..amount..')') or 'Craft All')
                    if focusNotice then focusNotice:SetText(UI.trainingCraftNotice or
                        (temporary and (quick and quick.ready and 'Recipe ready' or 'Click Craft to prepare recipe') or
                        'Craft available on the active learned milestone only')) end
                    Hint(focusOne,'Craft this milestone',quick and quick.reason or why or
                        'Learn the selected milestone recipe before crafting.')
                    Hint(focusAll,'Craft estimated milestone batch',
                        'Craft All requests the estimated remaining batch, limited by live materials. Yellow recipes may grant more or fewer skill-ups. The game, not Foundry, confirms results.')
                end
            end
            queue:SetShown(not stale and plan.complete and plan.guideVerified and
                not plan.requiresTraining and not plan.rankBreakpoint and not plan.lowConfidence)
            if UI.trainingGraphFocus then
                focusButton.label:SetText('Focused Step '..tostring(segIndex)..'/'..tostring(#plan.segments))
            else focusButton.label:SetText('Focus Current Step') end
            previous:SetEnabled(UI.trainingGraphFocus and segIndex>1)
            next:SetEnabled(UI.trainingGraphFocus and segIndex<#plan.segments)
            local warning=(plan.guideWarnings or 0)>0 and
                ('  /  '..tostring(plan.guideWarnings)..' guide steps need verification') or ''
            normalStatus=UI.trainingMessage or (plan.complete and
                'Curated route to '..plan.target..warning or
                'Guide coverage ends at '..tostring(plan.reached))
            if flashTime<=0 then achievement:SetText(normalStatus);achievement:SetAlpha(.85) end
        else
            totalPrice:SetText(UI.trainingGoalAchieved and 'Goal completed' or 'Guide unavailable')
            totalMeta:SetText('')
            stepHeading:SetText(UI.trainingGoalAchieved and 'Milestone achieved' or 'No training step')
            stepPrice:SetText('')
            stepNotes:SetText(UI.trainingMessage or 'Choose a profession with a curated guide.')
            UI:FillList(totalList,{},function()end)
            UI:FillList(stepList,{},function()end)
            craftOne:Hide(); craftAll:Hide(); craftNotice:SetText('')
            if UI.trainingFocusedCraftOne then UI.trainingFocusedCraftOne:SetEnabled(false) end
            if UI.trainingFocusedCraftAll then UI.trainingFocusedCraftAll:SetEnabled(false) end
            if UI.trainingFocusedCraftNotice then UI.trainingFocusedCraftNotice:SetText('') end
            queue:Hide()
            normalStatus=UI.trainingMessage or 'Choose a profession with a curated guide.'
            if flashTime<=0 then achievement:SetText(normalStatus) end
        end
        if zoomInfo and zoomInfo.label then zoomInfo.label:SetText(UI.trainingGraphFocus and 'FOCUS' or
            tostring(floor(targetZoom*100+.5))..'%') end
        -- Keep the just-completed focused card visible until the curtain
        -- closes. Otherwise the signature-triggered refresh instantly swaps
        -- in the next recipe before the success animation can finish.
        if not milestoneCelebration or milestoneCelebration.overview then
            self:DrawGuide()
        end
    end
    if viewport.HookScript then
        viewport:HookScript('OnSizeChanged',function()
            if page.DrawGuide and page:IsShown() then page:DrawGuide(true) end
        end)
    end
    -- No protected OpenTradeSkill in OnShow: it can be triggered by an
    -- asynchronous addon refresh without a hardware event. Training nav,
    -- opening Foundry by click, choosing a crafter, and Scan handle opening.
    page:Refresh()
end
