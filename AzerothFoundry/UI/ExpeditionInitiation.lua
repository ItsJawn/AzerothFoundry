-- Azeroth Foundry v0.6.2.1.1: a first-in-world Expedition choice for newly
-- registered characters. This is NOT the game's character-creation interface.
local _, AF = ...
local UI = AF.UI
local P = UI.palette

local function writing(parent,body,size,color)
    local t=UI:Text(parent,size or "small",color or P.pale)
    t:SetJustifyH("LEFT")
    t:SetJustifyV("TOP")
    t:SetWordWrap(true)
    t:SetText(body or "")
    return t
end
local function action(parent,caption,texture,description,y,onClick)
    local b=CreateFrame("Button",nil,parent)
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",21,y)
    b:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-21,y)
    b:SetHeight(67)
    b:RegisterForClicks("LeftButtonUp")
    UI:Background(b,P.leather,true)
    local glow=b:CreateTexture(nil,"HIGHLIGHT")
    glow:SetPoint("TOPLEFT",b,"TOPLEFT",7,-6)
    glow:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",-7,6)
    glow:SetColorTexture(.91,.67,.26,.12)
    local emblem=b:CreateTexture(nil,"ARTWORK")
    emblem:SetTexture(texture)
    emblem:SetSize(35,35)
    emblem:SetPoint("LEFT",b,"LEFT",13,0)
    local captionText=writing(b,caption,"small",P.gold)
    captionText:SetPoint("TOPLEFT",b,"TOPLEFT",60,-12)
    captionText:SetPoint("TOPRIGHT",b,"TOPRIGHT",-9,-12)
    captionText:SetHeight(20)
    local detail=writing(b,description,"small",P.pale)
    detail:SetPoint("TOPLEFT",b,"TOPLEFT",60,-33)
    detail:SetPoint("TOPRIGHT",b,"TOPRIGHT",-12,-33)
    detail:SetHeight(30)
    b:SetScript("OnClick",onClick)
    return b
end

function UI:ShowExpeditionInitiation(key, preview)
    -- One overlay at a time. Do not mistake a preview for a live initiation:
    -- /af initiation must replace an already-open preview with real choices.
    if self.initiationOverlay and self.initiationOverlay:IsShown() then
        if self.initiationOverlayPreview==(preview==true) and self.initiationOverlayKey==key then
            return true
        end
        self.initiationOverlay:Hide()
    end
    local c=AF.db and AF.db.characters and AF.db.characters[key]
    if not c or not AF.db.expeditionInitiation then return false end
    self:Open("Self-Found")
    if self.initiationOverlay then self.initiationOverlay:Hide() end
    local veil=CreateFrame("Frame",nil,self.frame)
    veil:SetAllPoints(self.frame)
    veil:SetFrameStrata("FULLSCREEN_DIALOG")
    veil:SetFrameLevel(self.frame:GetFrameLevel()+55)
    veil:EnableMouse(true)
    local dim=veil:CreateTexture(nil,"BACKGROUND")
    dim:SetAllPoints(veil)
    dim:SetColorTexture(.025,.018,.012,.72)

    local panel=self:NewFrame("Frame",veil)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel(veil:GetFrameLevel()+2)
    panel:SetSize(610,453)
    panel:SetPoint("CENTER",self.frame,"CENTER",0,0)
    self:Background(panel,P.parchmentLight,true)
    if self.FoundryQuestBorder then self:FoundryQuestBorder(panel,{cap=21,alpha=.70}) end
    self.initiationOverlay=veil
    self.initiationOverlayPreview=(preview==true)
    self.initiationOverlayKey=key

    local header=CreateFrame("Frame",nil,panel)
    header:SetPoint("TOPLEFT",panel,"TOPLEFT",9,-9)
    header:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-9,-9)
    header:SetHeight(74)
    self:Background(header,P.leather,true)
    local emblem=header:CreateTexture(nil,"ARTWORK")
    emblem:SetTexture("Interface\\Icons\\INV_Misc_Key_14")
    emblem:SetSize(43,43)
    emblem:SetPoint("LEFT",header,"LEFT",15,0)
    local title=writing(header,"AZEROTH FOUNDRY  /  BEGIN YOUR ADVENTURE","title",P.gold)
    title:SetPoint("TOPLEFT",header,"TOPLEFT",70,-10)
    title:SetPoint("TOPRIGHT",header,"TOPRIGHT",-9,-10)
    title:SetHeight(28)
    local sub=writing(header,(c.name or "Your adventurer").." has entered Azeroth. Choose how this journey begins.","small",P.pale)
    sub:SetPoint("TOPLEFT",header,"TOPLEFT",70,-38)
    sub:SetPoint("TOPRIGHT",header,"TOPRIGHT",-10,-38)
    sub:SetHeight(32)

    local intro=writing(panel,"This choice is voluntary. Foundry only observes activity after you activate a charter; earlier play cannot be verified.","small",P.ink)
    intro:SetPoint("TOPLEFT",panel,"TOPLEFT",24,-93)
    intro:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-24,-93)
    intro:SetHeight(37)

    local status=writing(panel,"","small",P.ink)
    status:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",22,52)
    status:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-22,52)
    status:SetHeight(30)
    local dismiss=self:Button(panel,preview and "Close Preview" or "Decide Later",function()
        if preview then veil:Hide(); return end
        local ok,err=AF:CompleteExpeditionInitiation(key,"later")
        if not ok then status:SetText(tostring(err)); return end
        veil:Hide()
        UI:Switch("Characters")
    end,"action")
    dismiss:SetSize(135,26)
    dismiss:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-20,17)
    local small=writing(panel,"One-time prompt. You can change membership anytime in Characters.","small",P.ink)
    small:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",22,17)
    small:SetWidth(390)
    small:SetHeight(26)

    local choices=CreateFrame("Frame",nil,panel)
    choices:SetPoint("TOPLEFT",panel,"TOPLEFT",0,-127)
    choices:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",0,91)
    local presets=CreateFrame("Frame",nil,panel)
    presets:SetAllPoints(choices)
    presets:Hide()

    local charter=AF:GetExpeditionCharter()
    local active=charter and charter.state=="active"
    local existing=AF:GetCharterMemberCount()
    local mode=charter and (AF.CHARTER_PRESET_NAMES[charter.preset] or "Custom Expedition") or "Account Self-Found"
    local suggested=AF:GetInitiationPreference()=="suggest"
    local joinTitle=active and ("Join Existing Expedition  -  "..mode) or "Join Foundry Expedition"
    if suggested then joinTitle=joinTitle.."  (Suggested)" end
    action(choices,joinTitle,"Interface\\Icons\\INV_Misc_GroupLooking",
        "Join the enrolled roster. If a charter is active, its current rules and observation period apply.",-2,function()
            if preview then status:SetText("Preview only: no enrollment was changed."); return end
            local ok,err=AF:CompleteExpeditionInitiation(key,"join")
            if not ok then status:SetText(tostring(err)); return end
            veil:Hide()
            UI:Switch("Self-Found")
        end)
    action(choices,"Establish a New Charter","Interface\\Icons\\INV_Misc_Book_11",
        "Choose Solo, Account, or Custom Self-Found. Review the draft rules before activating.",-76,function()
            if active then
                status:SetText("A charter is already active. End that run in Self-Found before establishing another.")
                return
            end
            status:SetText("Select a charter preset. Rules are NOT active until you activate them in Rulebook.")
            choices:Hide();presets:Show()
        end)
    action(choices,"Independent Adventurer","Interface\\Icons\\INV_Misc_Map_01",
        "Use all other Foundry tools without enrolling in this Expedition.",-150,function()
            if preview then status:SetText("Preview only: your character remains unchanged."); return end
            local ok,err=AF:CompleteExpeditionInitiation(key,"independent")
            if not ok then status:SetText(tostring(err)); return end
            veil:Hide()
            UI:Switch("Characters")
        end)

    local function choosePreset(preset)
        if preview then status:SetText("Preview only: "..(AF.CHARTER_PRESET_NAMES[preset] or preset).." selected. No charter changed."); return end
        local ok,err=AF:CompleteExpeditionInitiation(key,"charter",preset)
        if not ok then status:SetText(tostring(err)); return end
        veil:Hide()
        UI:Switch("Self-Found")
        local page=UI.pageViews and UI.pageViews["Self-Found"]
        if page and page.SelectCharterTab then page:SelectCharterTab("Rulebook") end
        if AF.Print then AF.Print("Charter draft prepared. Review the rules and explicitly activate when ready.") end
    end
    action(presets,"Solo Self-Found","Interface\\Icons\\INV_Misc_Key_14",
        "One enrolled character. Outside trade and shared-alt resources restricted.",-2,function()choosePreset("solo")end)
    action(presets,"Account Self-Found","Interface\\Icons\\INV_Misc_GroupLooking",
        "Enrolled alts may share their resources; outside trade remains restricted.",-76,function()choosePreset("account")end)
    action(presets,"Custom Expedition","Interface\\Icons\\INV_Misc_Book_09",
        "Start from the Custom preset, then set individual allowed and restricted rules.",-150,function()choosePreset("custom")end)
    local back=self:Button(presets,"Back",function()
        presets:Hide();choices:Show();status:SetText("")
    end,"action")
    back:SetSize(75,24)
    back:SetPoint("BOTTOMLEFT",presets,"BOTTOMLEFT",22,4)

    if not preview and AF.MarkExpeditionInitiationShown then AF:MarkExpeditionInitiationShown(key) end
    veil:Show()
    return true
end
