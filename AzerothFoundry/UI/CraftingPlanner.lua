-- Craft planning viewer. Fully local account snapshots; no automated item moves.
local _, AF = ...
local UI = AF.UI
local P = UI.palette
local function Timestamp(t)
    if not t then return 'Not visited' end
    return type(date)=='function' and date('%b %d, %H:%M',t) or 'Recorded'
end

function UI:InitializeCraftPlanner()
    if self.craftFrame then return end
    local frame=self:NewFrame('Frame',self.frame or UIParent,'AzerothFoundryCraftPlanner')
    frame:SetFrameStrata('FULLSCREEN_DIALOG')
    frame:SetSize(710,530)
    frame:SetPoint('CENTER',self.frame or UIParent,'CENTER')
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart',function(f) f:StartMoving() end)
    frame:SetScript('OnDragStop',function(f) f:StopMovingOrSizing() end)
    self:Background(frame,P.dark,true)
    frame:Hide()
    self.craftFrame=frame
    if UISpecialFrames then table.insert(UISpecialFrames,'AzerothFoundryCraftPlanner') end

    local heading=self:Text(frame,'title',P.gold)
    heading:SetPoint('TOPLEFT',18,-15);heading:SetSize(575,26)
    heading:SetText('CRAFTING PLAN')
    self.craftHeading=heading
    local close=CreateFrame('Button',nil,frame,'UIPanelCloseButton')
    close:SetPoint('TOPRIGHT',-9,-9); close:SetSize(30,30)
    close:SetScript('OnClick',function() frame:Hide() end)

    local left=self:Card(frame)
    left:SetPoint('TOPLEFT',12,-60);left:SetPoint('BOTTOMRIGHT',-234,60)
    local right=self:Card(frame)
    right:SetPoint('TOPRIGHT',-12,-60);right:SetPoint('BOTTOMRIGHT',-12,60)
    right:SetWidth(211)
    local title=self:SectionTitle(left,'Required Ingredients')
    title:SetPoint('TOPLEFT',12,-10);title:SetPoint('TOPRIGHT',-12,-10)
    self.craftTree=self:List(left,46)
    self.craftTree:SetPoint('TOPLEFT',12,-48)
    self.craftTree:SetPoint('BOTTOMRIGHT',-23,16)
    -- Distinguish actual recipe reagents from possible conversions for missing
    -- components. This is a presentation split, not a change in crafting math.
    local optTitle=self:SectionTitle(left,'Optional Craft')
    optTitle:SetPoint('TOPLEFT',12,-202)
    optTitle:SetPoint('TOPRIGHT',-12,-202)
    optTitle:SetJustifyH('CENTER')
    optTitle:Hide()
    self.craftOptionalTitle=optTitle
    local optExplanation=self:Text(left,'small',P.ink,'CENTER')
    optExplanation:SetPoint('TOPLEFT',12,-236)
    optExplanation:SetPoint('TOPRIGHT',-12,-236)
    optExplanation:SetHeight(33)
    optExplanation:SetText('An alternative way to produce a missing ingredient; not an additional recipe requirement.')
    optExplanation:Hide()
    self.craftOptionalExplanation=optExplanation
    local optionalList=self:List(left,43)
    optionalList:SetPoint('TOPLEFT',12,-275)
    optionalList:SetPoint('BOTTOMRIGHT',-23,16)
    optionalList:Hide()
    self.craftOptionalTree=optionalList

    local subt=self:SectionTitle(right,'Planning Options')
    subt:SetPoint('TOPLEFT',11,-10);subt:SetPoint('TOPRIGHT',-11,-10)
    local scope=self:Button(right,'All Alts',function()
        UI.craftScope=UI.craftScope=='all' and 'expedition' or 'all'
        UI:RefreshCraftPlanner()
    end)
    scope:SetPoint('TOPLEFT',11,-47);scope:SetPoint('TOPRIGHT',-11,-47)
    self.craftScopeButton=scope
    local amountLabel=self:Text(right,'small',P.ink)
    amountLabel:SetPoint('TOPLEFT',14,-93);amountLabel:SetPoint('TOPRIGHT',-11,-93)
    amountLabel:SetHeight(20);amountLabel:SetText('Craft attempts (1-99)')
    local amount=self:Input(right,80)
    amount:SetPoint('TOPLEFT',12,-117);amount:SetPoint('TOPRIGHT',-12,-117)
    amount:SetText('1')
    self.craftAmountInput=amount
    amount:SetScript('OnEnterPressed',function(e) e:ClearFocus();UI:RefreshCraftPlanner() end)
    local update=self:Button(right,'Update Plan',function() UI:RefreshCraftPlanner() end)
    update:SetPoint('TOPLEFT',12,-155);update:SetPoint('TOPRIGHT',-12,-155)
    local summary=self:Text(right,'small',P.ink)
    summary:SetPoint('TOPLEFT',13,-215);summary:SetPoint('BOTTOMRIGHT',-13,92)
    summary:SetJustifyV('TOP')
    self.craftSummary=summary

    local message=self:Text(frame,'small',P.pale)
    message:SetPoint('BOTTOMLEFT',22,12);message:SetPoint('BOTTOMRIGHT',-22,12)
    message:SetHeight(37);message:SetJustifyV('TOP')
    message:SetText('Green means recorded materials cover the amount, not that you can craft from every location. Recheck bags and bank.')
    local save=self:Button(right,'Create Crafting Goal',function()
        if not UI.craftPlan or UI.craftPlan.unknown and #UI.craftPlan.steps==0 then
            AF.Print('No complete crafting inputs available for a project.')
            return
        end
        local project=AF:SaveCraftingProject(UI.craftPlan)
        if project then
            UI.selectedProjectId=project.id
            frame:Hide()
            UI:Switch('Projects')
            AF.Print('Added a crafting goal and its material checklist.')
        end
    end)
    save:SetPoint('BOTTOMLEFT',12,13);save:SetPoint('BOTTOMRIGHT',-12,13)
    self.craftSaveButton=save
end

function UI:OpenCraftPlanner(snapshot,recipe,characterKey,scope)
    self:InitializeCraftPlanner()
    self.craftSnapshot=snapshot
    self.craftRecipe=recipe
    self.craftCharacterKey=characterKey
    self.craftScope=scope=='expedition' and 'expedition' or 'all'
    self.craftAmountInput:SetText('1')
    self.craftFrame:Show()
    self:RefreshCraftPlanner()
end

function UI:RefreshCraftPlanner()
    if not self.craftFrame or not self.craftFrame:IsShown() then return end
    local count=tonumber(self.craftAmountInput:GetText()) or 1
    if count~=math.floor(count) or count<1 or count>99 then
        self.craftSummary:SetText('Enter a whole number from 1 through 99.')
        self:FillList(self.craftTree,{},function() end)
        self:FillList(self.craftOptionalTree,{},function() end)
        self.craftOptionalTitle:Hide();self.craftOptionalExplanation:Hide();self.craftOptionalTree:Hide()
        self.craftPlan=nil
        self.craftSaveButton:Disable()
        return
    end
    self.craftSaveButton:Enable()
    self.craftScopeButton.label:SetText(self.craftScope=='expedition' and 'Expedition Only' or 'All Alts')
    local plan,reason=AF:MakeCraftingPlan(self.craftSnapshot,self.craftRecipe,
        self.craftCharacterKey,self.craftScope,count)
    self.craftPlan=plan
    if not plan then
        self.craftHeading:SetText('CRAFTING PLAN')
        self.craftSummary:SetText(reason or 'No plan available')
        self:FillList(self.craftTree,{},function() end)
        self:FillList(self.craftOptionalTree,{},function() end)
        self.craftOptionalTitle:Hide();self.craftOptionalExplanation:Hide();self.craftOptionalTree:Hide()
        self.craftSaveButton:Disable()
        return
    end
    self.craftHeading:SetText('CRAFTING PLAN  •  '..(plan.recipeName or 'Unknown recipe'))
    local entries,optionalEntries={},{}
    local parentCraft=nil
    for i,step in ipairs(plan.steps) do
        local item=AF:GetItemPresentation(step.itemID)
        local label=item and item.name or ('Item #'..step.itemID)
        local explanation
        if step.kind=='snapshot' then
            explanation=step.used..'/'..step.needed..' accounted • |cff22824b[Materials available]|r'
        elseif step.kind=='craftable' then
            parentCraft=label
            explanation=step.used..'/'..step.needed..' accounted • |cff9b5e15[Can make missing: see below]|r '..step.missing..' ('..step.crafter..')'..
                (step.alternatives>1 and (' • '..step.alternatives..' crafter options') or '')
        elseif step.kind=='unknown-reagents' then
            explanation='Recorded '..step.used..' / '..step.needed..' • '..step.crafter..' knows a recipe (inputs unknown)'
        elseif step.kind=='cycle' then
            explanation='Circular recipe dependency; review manually'
        elseif step.kind=='limit' then
            explanation='Additional dependencies not expanded'
        else
            explanation=(step.optional and 'If using subcraft: ' or '')..step.used..'/'..step.needed..' accounted • need '..step.missing..' (source unverified)'
        end
        if step.optional then
            optionalEntries[#optionalEntries+1]={key=i,icon=item and item.icon,
                label=label..' ×'..step.needed..'  •  for '..(parentCraft or 'a missing ingredient')..'\n'..explanation}
        else
            entries[#entries+1]={key=i,icon=item and item.icon,
                label=label..' ×'..step.needed..'\n'..explanation}
        end
    end
    self.craftTree:ClearAllPoints()
    self.craftTree:SetPoint('TOPLEFT',12,-48)
    if #optionalEntries>0 then
        self.craftTree:SetPoint('BOTTOMRIGHT',self.craftTree:GetParent(),'TOPRIGHT',-23,-192)
        self.craftOptionalTitle:Show()
        self.craftOptionalExplanation:Show()
        self.craftOptionalTree:Show()
        self:FillList(self.craftOptionalTree,optionalEntries,function() end)
    else
        self.craftTree:SetPoint('BOTTOMRIGHT',-23,16)
        self.craftOptionalTitle:Hide()
        self.craftOptionalExplanation:Hide()
        self.craftOptionalTree:Hide()
        self:FillList(self.craftOptionalTree,{},function() end)
    end
    self:FillList(self.craftTree,entries,function() end)
    local ready=AF:GetRecipeReadiness(self.craftSnapshot,self.craftRecipe,self.craftCharacterKey,self.craftScope,count)
    local coverage=0
    for _ in pairs(plan.snapshots or {}) do coverage=coverage+1 end
    local lines={
        'Craft attempts: '..count,
        'Materials: '..(ready.label or 'Not verified'),
        'Scope: '..(self.craftScope=='expedition' and 'Expedition only' or 'All registered alts'),
        '',
        'Recorded inventory sources: '..coverage,
        'Bags update while playing; bank is recorded at a banker.',
        '',
        plan.unknown and 'Some ingredients lack complete data.' or 'All listed recipe paths expanded as far as recorded.',
        '',
        'Oldest snapshots may be stale or count items already transferred.',
        'No transferability, station or specialization checks yet.',
    }
    self.craftSummary:SetText(table.concat(lines,'\n'))
end
