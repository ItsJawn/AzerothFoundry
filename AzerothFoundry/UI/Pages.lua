local _, AF = ...
local UI = AF.UI
local P = UI.palette
local unpack = unpack or table.unpack

local function CreateColumns(page, leftWidth, rightWidth)
    local left = UI:Card(page)
    left:SetPoint("TOPLEFT", 12, -12)
    left:SetPoint("BOTTOMLEFT", 12, 12)
    left:SetWidth(leftWidth or 248)
    local right = UI:Card(page)
    right:SetPoint("TOPRIGHT", -12, -12)
    right:SetPoint("BOTTOMRIGHT", -12, 12)
    right:SetWidth(rightWidth or 255)
    local mid = UI:Card(page)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", -8, 0)
    -- Let side columns breathe at large window sizes without overwhelming
    -- the central content; minimum widths preserve edit-box usability.
    page:SetScript("OnSizeChanged", function(_, width)
        if width and width > 0 then
            left:SetWidth(math.max(leftWidth or 248, math.min(315, math.floor(width * 0.245))))
            right:SetWidth(math.max(rightWidth or 255, math.min(315, math.floor(width * 0.245))))
        end
    end)
    return left, mid, right
end

local function Section(panel, title, offset)
    local label = UI:SectionTitle(panel, title)
    label:SetPoint("TOPLEFT", 14, -(offset or 12))
    label:SetPoint("TOPRIGHT", -12, -(offset or 12))
    return label
end

local function Line(parent, y, font, height, width)
    local l = UI:Text(parent, font, P.ink)
    l:SetPoint("TOPLEFT", 16, -y)
    l:SetPoint("TOPRIGHT", -(width or 12), -y)
    l:SetHeight(height or 24)
    l:SetJustifyV("MIDDLE")
    return l
end

local function PanelScroll(panel, top, bottom)
    local scroll = UI:List(panel, 37)
    scroll:SetPoint("TOPLEFT", 12, -top)
    scroll:SetPoint("BOTTOMRIGHT", -22, bottom or 16)
    return scroll
end

local function TimeLabel(timestamp)
    if not timestamp then return "Not scanned" end
    if date then return date("%b %d %Y, %H:%M", timestamp) end
    return "Recorded"
end

local function ProgressText(project)
    local done, total = AF:CountTasks(project)
    if total == 0 then return project.done and "Completed" or "Not started" end
    return tostring(done) .. "/" .. tostring(total) .. " steps"
end

function UI:BuildOverview(page)
    local left, center, right = CreateColumns(page, 245, 256)
    Section(left, "Account Summary")
    local mainLabel = Line(left, 58, nil, 54)
    mainLabel:SetJustifyV("TOP")
    local statLabels = {}
    for i = 1, 5 do statLabels[i] = Line(left, 139 + (i - 1) * 38, nil, 28) end
    local help = Line(left, 365, "small", 100)
    help:SetJustifyV("TOP")
    help:SetText("Your journal grows as you log into more characters. Account-wide projects and notes stay available on every alt.")
    local mainButton = self:Button(left, "Manage Characters", function() self:Switch("Characters") end)
    mainButton:SetPoint("BOTTOMLEFT", 15, 17)
    mainButton:SetPoint("BOTTOMRIGHT", -15, 17)

    Section(center, "Current Expedition")
    local current = Line(center, 58, nil, 64)
    current:SetJustifyV("TOP")
    local prof = Line(center, 117, "small", 59)
    prof:SetJustifyV("TOP")
    local projectsHead = Section(center, "Pinned Goals", 177)
    local active = {}
    for i = 1, 6 do
        local b = self:Button(center, "", nil, "row")
        b:SetPoint("TOPLEFT", 15, -215 - (i-1)*40)
        b:SetPoint("TOPRIGHT", -15, -215 - (i-1)*40)
        b:SetHeight(34)
        active[i] = b
    end
    local newProject = self:Button(center, "+ New Goal", function()
        local p = AF:AddProject()
        self.selectedProjectId = p.id
        self:Switch("Projects")
    end)
    newProject:SetPoint("BOTTOMRIGHT", -14, 16)
    newProject:SetSize(155, 30)

    Section(right, "Latest Notes")
    local notes = {}
    for i = 1, 4 do
        local b = self:Button(right, "", nil, "row")
        b:SetPoint("TOPLEFT", 13, -53 - (i-1)*43)
        b:SetPoint("TOPRIGHT", -13, -53 - (i-1)*43)
        b:SetHeight(36)
        notes[i] = b
    end
    local notesButton = self:Button(right, "+ Add Note", function()
        local n = AF:AddNote()
        self.selectedNoteId = n.id
        self:Switch("Notes")
    end)
    notesButton:SetPoint("TOPLEFT", 13, -245)
    notesButton:SetPoint("TOPRIGHT", -13, -245)
    local insight = Line(right, 305, "small", 80)
    insight:SetJustifyV("TOP")
    insight:SetText("Notes are available on every registered character. Choose an entry to open it in the notebook.")

    function page:Refresh()
        local chars = AF:GetCharacters()
        local main = AF.db.characters[AF.db.mainKey]
        mainLabel:SetText("|cff704718Main character|r\n" .. (main and (main.name .. "  -  Lv " .. tostring(main.level)) or "Not selected"))
        local professionCount = #AF:ProfessionSummary()
        local done = 0
        for _, item in ipairs(AF.db.projects) do if item.done then done = done + 1 end end
        local lines = {
            "Characters:  " .. #chars,
            "Professions discovered:  " .. professionCount,
            "Goals:  " .. #AF.db.projects,
            "Completed projects:  " .. done,
            "Journal notes:  " .. #AF.db.notes,
        }
        for i, t in ipairs(lines) do statLabels[i]:SetText(t) end
        local c = AF:CurrentCharacter()
        current:SetText(c and ("|cff704718" .. c.name .. "|r\n" .. "Level " .. tostring(c.level or "?") .. " " .. (c.class or "")) or "Current character not detected")
        local professions = {}
        if c then
            for _, v in pairs(c.professions or {}) do
                professions[#professions+1] = v.name .. "  " .. tostring(v.skill) .. "/" .. tostring(v.maximum)
            end
        end
        table.sort(professions)
        prof:SetText(#professions > 0 and table.concat(professions, "\n") or "No professions recorded yet. Try /af scan after learning one.")
        local list = {}
        for _, p in ipairs(AF.db.projects) do if not p.done then list[#list+1] = p end end
        table.sort(list, function(a,b) return (a.updated or 0) > (b.updated or 0) end)
        for i, button in ipairs(active) do
            local p = list[i]
            if p then
                button:Show()
                button.label:SetText((p.title or "Untitled") .. "   -   " .. ProgressText(p))
                button:SetScript("OnClick", function()
                    UI.selectedProjectId = p.id
                    UI:Switch("Projects")
                end)
            else button:Hide() end
        end
        for i, button in ipairs(notes) do
            local n = AF.db.notes[#AF.db.notes - i + 1]
            if n then
                button:Show(); button.label:SetText(n.title or "Untitled")
                button:SetScript("OnClick", function()
                    UI.selectedNoteId = n.id
                    UI:Switch("Notes")
                end)
            else button:Hide() end
        end
    end
end

-- Expedition character management.  Membership is explicit; a character who
-- leaves is not silently made eligible again by changing the selected main.
function UI:ConfirmExpeditionChange(key, joining)
    local c = AF.db and AF.db.characters[key]
    if not c then return end
    if not StaticPopupDialogs or not StaticPopup_Show then
        AF.Print("Confirmation UI unavailable. No membership was changed.")
        return
    end
    local previous = AF:CharacterHasExpeditionHistory(key)
    local dialogID = joining and (previous and "AZEROTHFOUNDRY_REJOIN" or "AZEROTHFOUNDRY_INVITE")
        or "AZEROTHFOUNDRY_DEPART"
    if not StaticPopupDialogs[dialogID] then
        local messages = {
            AZEROTHFOUNDRY_INVITE = "Invite %s to the Foundry Expedition?\n\nThis character begins a NEW tracked membership period. Earlier gameplay is unverified. A Chronicle entry will be saved locally.",
            AZEROTHFOUNDRY_REJOIN = "Re-invite %s to the Foundry Expedition?\n\nWarning: this character previously left. Its history will retain that departure, and this enrollment will begin a SEPARATE tracking period. Outside activity cannot be certified.",
            AZEROTHFOUNDRY_DEPART = "Remove %s from the Foundry Expedition?\n\nThis character leaves the Expedition roster and its future self-found rule scope. A dated local departure entry will be recorded. Returning later starts a new period. Existing journal notes and projects remain.",
        }
        StaticPopupDialogs[dialogID] = {
            text = messages[dialogID], button1 = YES or "Confirm", button2 = NO or "Cancel",
            OnAccept = function(_, data)
                if not data or not data.key then return end
                local ok, reason
                if data.joining then ok, reason = AF:JoinExpedition(data.key)
                else ok, reason = AF:LeaveExpedition(data.key) end
                if not ok then AF.Print(reason or "Could not change membership.") end
                AF:RefreshUI()
            end,
            timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
        }
    end
    StaticPopup_Show(dialogID, c.name or "this character", nil, {key = key, joining = joining})
end

local function ClassIcon(texture, char)
    if char and char.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[char.class] then
        texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        texture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[char.class]))
    else
        texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function ClassColor(char)
    local color = char and RAID_CLASS_COLORS and RAID_CLASS_COLORS[char.class]
    if color then return color.r, color.g, color.b end
    return unpack(P.ink)
end

local function MakeRosterHeader(child)
    local text = UI:Text(child, "small", P.ink)
    text:SetHeight(24)
    local rule = child:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetColorTexture(0.57, 0.34, 0.12, 0.4)
    return {text = text, rule = rule}
end

local function MakeRosterButton(child)
    local b = UI:Button(child, "", nil, "row")
    b:SetHeight(54)
    b.label:Hide()
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(35, 35)
    icon:SetPoint("LEFT", 7, 0)
    b.icon = icon
    local name = UI:Text(b, nil, P.ink)
    name:SetPoint("TOPLEFT", b, "TOPLEFT", 52, -6)
    name:SetPoint("TOPRIGHT", b, "TOPRIGHT", -5, -6)
    name:SetHeight(22)
    local details = UI:Text(b, "small", P.ink)
    details:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 52, 6)
    details:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, 6)
    details:SetHeight(16)
    return {button=b, icon=icon, name=name, details=details}
end

function UI:BuildCharacters(page)
    local left, center, right = CreateColumns(page, 285, 264)
    Section(left, "The Adventuring Company")
    local teamLine = self:Text(left, "small", P.ink)
    teamLine:SetPoint("TOPLEFT", 15, -47)
    teamLine:SetPoint("TOPRIGHT", -14, -47)
    teamLine:SetHeight(24)
    local roster = self:List(left, 60)
    roster:SetPoint("TOPLEFT", 13, -78)
    roster:SetPoint("BOTTOMRIGHT", -23, 81)
    roster.partyHeaders = {}
    roster.partyRows = {}
    local footer = self:Text(left, "small", P.ink)
    footer:SetPoint("BOTTOMLEFT", 16, 11)
    footer:SetPoint("BOTTOMRIGHT", -16, 11)
    footer:SetHeight(56)
    footer:SetJustifyV("TOP")
    footer:SetText("Select a character to inspect their Expedition membership.")

    Section(center, "Character Profile")
    -- A roomy identity card. The current character gets a live Blizzard unit
    -- portrait; offline alts get an honest class-icon fallback (not a saved
    -- screenshot, which addons cannot persist through SavedVariables).
    local hero = self:NewFrame("Frame", center)
    hero:SetPoint("TOPLEFT", 15, -53)
    hero:SetPoint("TOPRIGHT", -15, -53)
    hero:SetHeight(132)
    self:Background(hero, P.leather, true)

    local portraitFrame = self:NewFrame("Frame", hero)
    portraitFrame:SetSize(109, 109)
    portraitFrame:SetPoint("TOPLEFT", hero, "TOPLEFT", 13, -11)
    self:Background(portraitFrame, P.dark, true)
    local portrait = portraitFrame:CreateTexture(nil, "ARTWORK")
    portrait:SetPoint("TOPLEFT", portraitFrame, "TOPLEFT", 8, -8)
    portrait:SetPoint("BOTTOMRIGHT", portraitFrame, "BOTTOMRIGHT", -8, 8)
    local classIcon = portraitFrame:CreateTexture(nil, "OVERLAY")
    classIcon:SetSize(29, 29)
    classIcon:SetPoint("BOTTOMRIGHT", portraitFrame, "BOTTOMRIGHT", 1, -1)
    local emblemBackdrop = portraitFrame:CreateTexture(nil, "BORDER")
    emblemBackdrop:SetSize(34, 34)
    emblemBackdrop:SetPoint("CENTER", classIcon, "CENTER")
    emblemBackdrop:SetColorTexture(0.06, 0.04, 0.02, 0.98)

    local nameText = self:Text(hero, "title", P.gold)
    nameText:SetPoint("TOPLEFT", 137, -11)
    nameText:SetPoint("TOPRIGHT", -14, -11)
    nameText:SetHeight(28)
    local identity = self:Text(hero, nil, P.pale)
    identity:SetPoint("TOPLEFT", 139, -43)
    identity:SetPoint("TOPRIGHT", -13, -43)
    identity:SetHeight(20)
    local location = self:Text(hero, "small", P.pale)
    location:SetPoint("TOPLEFT", 139, -69)
    location:SetPoint("TOPRIGHT", -13, -69)
    location:SetHeight(20)
    local portraitSource = self:Text(hero, "small", P.pale)
    portraitSource:SetPoint("TOPLEFT", 139, -96)
    portraitSource:SetPoint("TOPRIGHT", -13, -96)
    portraitSource:SetHeight(19)

    -- Small printed status seals replace the checkbox-looking text glyphs.
    -- Their widths fit even when the center panel is fairly narrow.
    local function StatusSeal(parent, width, text, colors)
        local seal = UI:NewFrame("Frame", parent)
        seal:SetSize(width, 23)
        local fill = seal:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints(seal)
        fill:SetColorTexture(colors[1], colors[2], colors[3], 0.95)
        local topEdge = seal:CreateTexture(nil, "BORDER")
        topEdge:SetHeight(1)
        topEdge:SetPoint("TOPLEFT", 1, -1)
        topEdge:SetPoint("TOPRIGHT", -1, -1)
        topEdge:SetColorTexture(0.83, 0.66, 0.34, 0.67)
        local label = UI:Text(seal, "small", P.pale, "CENTER")
        label:SetAllPoints(seal)
        label:SetText(text)
        seal.fill = fill
        return seal, label
    end
    local expeditionSeal, expeditionSealText = StatusSeal(center, 157, "Expedition Member", {0.19, 0.36, 0.25})
    expeditionSeal:SetPoint("TOPLEFT", 17, -196)
    local mainSeal = StatusSeal(center, 117, "Main Character", {0.46, 0.31, 0.13})
    mainSeal:SetPoint("LEFT", expeditionSeal, "RIGHT", 8, 0)
    local memberInfo = self:Text(center, "small", P.ink)
    memberInfo:SetPoint("TOPLEFT", 18, -225)
    memberInfo:SetPoint("TOPRIGHT", -14, -225)
    memberInfo:SetHeight(20)

    local mainBtn = self:Button(center, "Set as Main", function()
        local key = UI.selectedCharacterKey
        if key and AF:IsExpeditionMember(key) then AF:SetMain(key) end
    end)
    mainBtn:SetPoint("TOPLEFT", 16, -254)
    mainBtn:SetSize(132, 29)
    local memberBtn = self:Button(center, "Invite to Expedition", function()
        local key = UI.selectedCharacterKey
        if key then UI:ConfirmExpeditionChange(key, not AF:IsExpeditionMember(key)) end
    end)
    memberBtn:SetPoint("TOPRIGHT", -16, -254)
    memberBtn:SetSize(158, 29)

    local roleLabel = self:Text(center, "small", P.ink)
    roleLabel:SetPoint("TOPLEFT", 18, -303)
    roleLabel:SetHeight(23)
    roleLabel:SetWidth(60)
    roleLabel:SetText("Party role")
    local roleButton = self:Button(center, "Adventurer", function()
        local key = UI.selectedCharacterKey
        if key then AF:CycleExpeditionRole(key) end
    end)
    roleButton:SetPoint("TOPLEFT", 91, -300)
    roleButton:SetSize(154, 27)
    local lastSeen = self:Text(center, "small", P.ink)
    lastSeen:SetPoint("TOPLEFT", 17, -337)
    lastSeen:SetPoint("TOPRIGHT", -13, -337)
    lastSeen:SetHeight(35)
    lastSeen:SetJustifyV("TOP")

    Section(center, "Membership Chronicle", 384)
    local historyScroll = self:List(center, 48)
    historyScroll:SetPoint("TOPLEFT", 16, -419)
    historyScroll:SetPoint("BOTTOMRIGHT", -22, 50)
    local historyTip = self:Text(center, "small", P.ink)
    historyTip:SetPoint("BOTTOMLEFT", 17, 12)
    historyTip:SetPoint("BOTTOMRIGHT", -17, 12)
    historyTip:SetHeight(33)
    historyTip:SetJustifyV("TOP")
    historyTip:SetText("Journal records are local. This does not verify gameplay outside the addon.")

    local function UpdatePortrait(char)
        -- Do not display the *current* player's face on another character.
        ClassIcon(classIcon, char)
        if char and char.key == AF:GetCurrentKey() and type(SetPortraitTexture) == "function" then
            -- The fallback uses an atlas crop; reset UVs for the whole 2D face.
            portrait:SetTexCoord(0, 1, 0, 1)
            local ok = pcall(SetPortraitTexture, portrait, "player")
            if ok then
                portraitSource:SetText("Live character portrait")
                return
            end
        end
        ClassIcon(portrait, char)
        portraitSource:SetText("Class emblem  •  Offline alt")
    end
    local portraitWatcher = self:NewFrame("Frame", page)
    portraitWatcher:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    portraitWatcher:RegisterEvent("UNIT_MODEL_CHANGED")
    portraitWatcher:SetScript("OnEvent", function(_, _, unit)
        if unit ~= "player" then return end
        if UI.selectedCharacterKey and AF.db and AF.db.characters[UI.selectedCharacterKey] then
            UpdatePortrait(AF.db.characters[UI.selectedCharacterKey])
        end
    end)

    Section(right, "Known Professions")
    local professionRows = {}
    for i = 1, 6 do
        local y = 52 + (i - 1) * 42
        local icon = right:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", right, "TOPLEFT", 15, -y)
        icon:SetSize(29, 29)
        local label = self:Text(right, "small", P.ink)
        label:SetPoint("TOPLEFT", right, "TOPLEFT", 51, -y)
        label:SetPoint("TOPRIGHT", right, "TOPRIGHT", -12, -y)
        label:SetHeight(20)
        local progress = self:Text(right, "small", P.ink)
        progress:SetPoint("TOPLEFT", right, "TOPLEFT", 51, -(y+20))
        progress:SetPoint("TOPRIGHT", right, "TOPRIGHT", -12, -(y+20))
        progress:SetHeight(17)
        professionRows[i] = {icon=icon,label=label,progress=progress}
    end
    local noProf = self:Text(right, "small", P.ink)
    noProf:SetPoint("TOPLEFT", 17, -63)
    noProf:SetPoint("TOPRIGHT", -13, -63)
    noProf:SetHeight(73)
    noProf:SetJustifyV("TOP")

    Section(right, "Assigned Goals", 328)
    local projectRows = {}
    for i=1, 3 do
        local btn = self:Button(right, "", nil, "row")
        btn:SetPoint("TOPLEFT", 15, -369-(i-1)*39)
        btn:SetPoint("TOPRIGHT", -15, -369-(i-1)*39)
        btn:SetHeight(33)
        projectRows[i] = btn
    end
    local projectHelp = self:Text(right, "small", P.ink)
    projectHelp:SetPoint("BOTTOMLEFT", 17, 12)
    projectHelp:SetPoint("BOTTOMRIGHT", -17, 12)
    projectHelp:SetHeight(52)
    projectHelp:SetJustifyV("TOP")
    projectHelp:SetText("Goals assigned to this character appear here. Open Goals to add more.")

    local function RefreshPartyList()
        local inside, outside = AF:GetExpeditionMembers()
        teamLine:SetText("|cff386549Expedition|r  " .. #inside .. "     |cff7a5b33Independent|r  " .. #outside)
        local child = roster.child
        local width = child:GetWidth() or 200
        local y, i, groupIdx = 0, 0, 0
        for _, group in ipairs({
            {title="YOUR EXPEDITION", characters=inside},
            {title="INDEPENDENT ADVENTURERS", characters=outside},
        }) do
            groupIdx = groupIdx + 1
            local header = roster.partyHeaders[groupIdx]
            if not header then
                header = MakeRosterHeader(child)
                roster.partyHeaders[groupIdx] = header
            end
            header.text:ClearAllPoints()
            header.text:SetPoint("TOPLEFT", child, "TOPLEFT", 8, -y-2)
            header.text:SetWidth(math.max(90, width-10))
            header.text:SetText(group.title .. " (" .. #group.characters .. ")")
            header.rule:ClearAllPoints()
            header.rule:SetPoint("TOPLEFT", child, "TOPLEFT", 8, -y-28)
            header.rule:SetWidth(math.max(90, width-12))
            y = y + 39
            for _, c in ipairs(group.characters) do
                i = i + 1
                local row = roster.partyRows[i]
                if not row then
                    row = MakeRosterButton(child)
                    roster.partyRows[i] = row
                    roster.rows[#roster.rows+1] = row.button
                end
                local b = row.button
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", child, "TOPLEFT", 3, -y)
                b:SetWidth(math.max(100, width-8))
                b:Show()
                ClassIcon(row.icon, c)
                row.name:SetText((c.key == AF.db.mainKey and "|cffffc55d★ |r" or "") .. (c.name or "Unknown"))
                row.name:SetTextColor(ClassColor(c))
                local detail = "Lv " .. tostring(c.level or "?") .. " " .. (c.class or "")
                if AF:IsExpeditionMember(c.key) then
                    detail = detail .. "  •  " .. (c.expeditionRole or "Adventurer")
                else
                    detail = detail .. "  •  Independent"
                end
                row.details:SetText(detail)
                UI:SetButtonSelected(b, c.key == UI.selectedCharacterKey)
                b:SetScript("OnClick", function()
                    UI.selectedCharacterKey = c.key
                    page:Refresh()
                end)
                y = y + 59
            end
            y = y + 8
        end
        for j = i+1, #roster.partyRows do roster.partyRows[j].button:Hide() end
        roster.afContentHeight = math.max(1, y+5)
        child:SetHeight(roster.afContentHeight)
        UI:UpdateListScroll(roster)
    end

    function page:Refresh()
        local chars = AF:GetCharacters()
        if not UI.selectedCharacterKey or not AF.db.characters[UI.selectedCharacterKey] then
            UI.selectedCharacterKey = AF:GetCurrentKey()
        end
        RefreshPartyList()
        local c = AF.db.characters[UI.selectedCharacterKey]
        if not c then return end
        UpdatePortrait(c)
        nameText:SetText(c.name or "Unknown")
        nameText:SetTextColor(ClassColor(c))
        identity:SetText("Level " .. tostring(c.level or "?") .. " " .. (c.class or ""))
        local race = c.race and (c.race .. "  •  ") or ""
        location:SetText(race .. (c.faction or "Unknown faction") .. "  •  " .. (c.realm or "Unknown realm"))
        local member = AF:IsExpeditionMember(c.key)
        local main = c.key == AF.db.mainKey
        expeditionSeal:Show()
        mainSeal:SetShown(main)
        expeditionSealText:SetText(member and "Expedition Member" or "Independent Adventurer")
        if member then
            expeditionSeal.fill:SetColorTexture(0.19, 0.36, 0.25, 0.95)
            memberInfo:SetText("Enrolled: " .. TimeLabel(c.expeditionJoinedAt))
        else
            expeditionSeal.fill:SetColorTexture(0.41, 0.30, 0.19, 0.95)
            memberInfo:SetText("Outside Expedition rules  •  Earlier activity unverified")
        end
        mainBtn:SetShown(member and not main)
        memberBtn:SetShown(not main)
        memberBtn.label:SetText(member and "Leave Expedition" or "Invite to Expedition")
        roleButton.label:SetText(c.expeditionRole or "Adventurer")
        roleButton:SetShown(member)
        roleLabel:SetShown(member)
        lastSeen:SetText("Last scanned: " .. TimeLabel(c.lastSeen) .. "\n" ..
            "Tracking: membership only; gameplay compliance is not monitored yet.")
        local events = AF:CharacterExpeditionEvents(c.key, 30)
        local items = {}
        for _, event in ipairs(events) do
            local types = {import="Enrolled after upgrade", join="Joined Expedition", rejoin="Rejoined (new period)",
                depart="Departed Expedition", leader="Named Main Adventurer"}
            items[#items+1] = {
                key=event.id,
                label=(types[event.event] or event.event) .. "  •  " .. TimeLabel(event.timestamp),
            }
        end
        UI:FillList(historyScroll, items, function(entry)
            for _, event in ipairs(events) do
                if event.id == entry.key then
                    historyTip:SetText(event.detail or "No additional details.")
                    return
                end
            end
        end)
        historyTip:SetText(#events == 0 and "No membership changes recorded. Prior gameplay cannot be certified."
            or "Click a Chronicle entry for details. Records are local, not tamper-proof.")
        local professions = {}
        for _, p in pairs(c.professions or {}) do professions[#professions+1] = p end
        table.sort(professions, function(a,b) return a.name < b.name end)
        noProf:SetShown(#professions == 0)
        if #professions == 0 then noProf:SetText("No professions recorded. Log onto this character to update its profession skills.") end
        for i, row in ipairs(professionRows) do
            local p = professions[i]
            row.icon:SetShown(p ~= nil)
            row.label:SetShown(p ~= nil)
            row.progress:SetShown(p ~= nil)
            if p then
                row.icon:SetTexture(p.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.label:SetText(p.name or "Unknown")
                row.progress:SetText(tostring(p.skill or 0) .. " / " .. tostring(p.maximum or 0))
            end
        end
        local assigned = {}
        for _, project in ipairs(AF.db.projects or {}) do
            if project.owner == c.key and not project.done then assigned[#assigned+1] = project end
        end
        for i, btn in ipairs(projectRows) do
            local project = assigned[i]
            local enoughHeight = (right:GetHeight() or 550) > (i == 3 and 535 or (i == 2 and 485 or 435))
            btn:SetShown(project ~= nil and enoughHeight)
            if project then
                btn.label:SetText(project.title or "Untitled project")
                btn:SetScript("OnClick", function()
                    UI.selectedProjectId = project.id
                    UI:Switch("Projects")
                end)
            end
        end
    end
end

-- v0.3.0 Workshop: character-first or profession-first browsing over the same
-- SavedVariables records. Eligibility scope changes what is displayed, not
-- the stored character data or a character's compliance status.
function UI:BuildWorkshop(page)
    local left, center, right = UI.WorkshopPanels(page,"Professions",.225,.285)
    Section(left, "Profession Directory")
    local modeProf = UI.WorkshopButton(left, "Professions", function()
        AF.db.settings.workshop.browse = "profession"
        page:Refresh()
    end)
    modeProf:SetPoint("TOPLEFT", 13, -50)
    modeProf:SetPoint("TOPRIGHT", left, "TOP", -3, -50)
    modeProf:SetHeight(29)
    local modeChar = UI.WorkshopButton(left, "Characters", function()
        AF.db.settings.workshop.browse = "character"
        page:Refresh()
    end)
    modeChar:SetPoint("TOPLEFT", left, "TOP", 3, -50)
    modeChar:SetPoint("TOPRIGHT", -13, -50)
    modeChar:SetHeight(29)

    local scopeAll = UI.WorkshopButton(left, "All Alts", function()
        AF.db.settings.workshop.scope = "all"
        page:Refresh()
    end)
    scopeAll:SetPoint("TOPLEFT", 13, -92)
    scopeAll:SetPoint("TOPRIGHT", left, "TOP", -3, -92)
    scopeAll:SetHeight(27)
    local scopeExp = UI.WorkshopButton(left, "Expedition", function()
        AF.db.settings.workshop.scope = "expedition"
        page:Refresh()
    end)
    scopeExp:SetPoint("TOPLEFT", left, "TOP", 3, -92)
    scopeExp:SetPoint("TOPRIGHT", -13, -92)
    scopeExp:SetHeight(27)
    local directoryHint = Line(left, 131, "small", 36)
    directoryHint:SetJustifyV("TOP")
    local directory = PanelScroll(left, 177, 75)
    UI:InsetWorkshopScrollBar(directory)
    -- Keep the default Blizzard scrollbar clear of the outer panel lip.
    directory:ClearAllPoints()
    directory:SetPoint("TOPLEFT", left, "TOPLEFT", 12, -177)
    directory:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -30, 75)
    local rescan = UI.WorkshopButton(left, "Rescan Current", function()
        AF:ScanCharacter()
        page:Refresh()
    end)
    rescan:SetPoint("BOTTOMLEFT", 13, 15)
    rescan:SetPoint("BOTTOMRIGHT", -13, 15)
    local lastScanned = self:Text(left, "small", P.ink, "CENTER")
    lastScanned:SetPoint("BOTTOMLEFT", 13, 51)
    lastScanned:SetPoint("BOTTOMRIGHT", -13, 51)
    lastScanned:SetHeight(19)

    Section(center, "Workshop Bench")
    local benchIcon = center:CreateTexture(nil, "ARTWORK")
    benchIcon:SetSize(41, 41)
    benchIcon:SetPoint("TOPLEFT", 17, -57)
    local benchTitle = self:Text(center, "title", P.ink)
    benchTitle:SetPoint("TOPLEFT", 69, -57)
    benchTitle:SetPoint("TOPRIGHT", -12, -57)
    benchTitle:SetHeight(25)
    local benchSub = self:Text(center, "small", P.ink)
    benchSub:SetPoint("TOPLEFT", 69, -87)
    benchSub:SetPoint("TOPRIGHT", -12, -87)
    benchSub:SetHeight(32)
    benchSub:SetJustifyV("TOP")
    Section(center, "Choose a Crafter or Skill", 130)
    local benchList = self:List(center, 58)
    UI:InsetWorkshopScrollBar(benchList)
    benchList:SetPoint("TOPLEFT", 13, -174)
    benchList:SetPoint("BOTTOMRIGHT", -30, 107)
    local benchHelp = self:Text(center, "small", P.ink)
    benchHelp:SetPoint("BOTTOMLEFT", 17, 16)
    benchHelp:SetPoint("BOTTOMRIGHT", -17, 16)
    benchHelp:SetHeight(79)
    benchHelp:SetJustifyV("TOP")
    benchHelp:SetText("Select a crafter or profession to inspect its last recorded skill and goal. Open Recipes for learned crafts and material requirements.")

    Section(right, "Selected Crafter")
    local crafterIcon = right:CreateTexture(nil, "ARTWORK")
    crafterIcon:SetSize(30, 30)
    crafterIcon:SetPoint("TOPLEFT", 16, -56)
    local crafter = self:Text(right, nil, P.ink)
    crafter:SetPoint("TOPLEFT", 55, -55)
    crafter:SetPoint("TOPRIGHT", -14, -55)
    crafter:SetHeight(28)
    local crafterDetail = self:Text(right, "small", P.ink)
    crafterDetail:SetPoint("TOPLEFT", 16, -93)
    crafterDetail:SetPoint("TOPRIGHT", -15, -93)
    crafterDetail:SetHeight(61)
    crafterDetail:SetJustifyV("TOP")
    Section(right, "Profession Progress", 151)
    local skillText = Line(right, 193, "small", 25)
    local meterBase = right:CreateTexture(nil, "ARTWORK")
    meterBase:SetPoint("TOPLEFT", 17, -227)
    meterBase:SetPoint("TOPRIGHT", -18, -227)
    meterBase:SetHeight(10)
    meterBase:SetColorTexture(0.30, 0.20, 0.11, 0.60)
    local meterFill = right:CreateTexture(nil, "OVERLAY")
    meterFill:SetPoint("TOPLEFT", meterBase, "TOPLEFT", 1, -1)
    meterFill:SetPoint("BOTTOMLEFT", meterBase, "BOTTOMLEFT", 1, 1)
    meterFill:SetColorTexture(0.24, 0.52, 0.37, 1)
    local capText = Line(right, 244, "small", 32)
    capText:SetJustifyV("TOP")
    capText:SetWordWrap(true)
    local function fitProfessionCaptions()
        if capText.GetStringHeight then
            local h=tonumber(capText:GetStringHeight()) or 0
            capText:SetHeight(math.max(28,math.min(50,h+6)))
        end
    end
    -- The header and all controls BELOW it follow the preceding copy. This
    -- prevents a narrow right pane from printing text across "Skill Goal".
    local skillGoalTitle = Section(right, "Skill Goal", 280)
    skillGoalTitle:ClearAllPoints()
    skillGoalTitle:SetPoint("TOPLEFT",capText,"BOTTOMLEFT",0,-5)
    skillGoalTitle:SetPoint("TOPRIGHT",capText,"BOTTOMRIGHT",0,-5)
    local goalDescription = Line(right, 312, "small", 34)
    goalDescription:ClearAllPoints()
    goalDescription:SetPoint("TOPLEFT",skillGoalTitle,"BOTTOMLEFT",0,-7)
    goalDescription:SetPoint("TOPRIGHT",skillGoalTitle,"BOTTOMRIGHT",0,-7)
    goalDescription:SetJustifyV("TOP")
    local function fitGoalCopy()
        fitProfessionCaptions()
        if goalDescription.GetStringHeight then
            local h=tonumber(goalDescription:GetStringHeight()) or 0
            goalDescription:SetHeight(math.max(34,math.min(52,h+5)))
        end
    end
    if right.HookScript then right:HookScript("OnSizeChanged",fitGoalCopy) end
    local target = self:Input(right, 80)
    target:SetPoint("TOPLEFT",goalDescription,"BOTTOMLEFT",0,-7)
    target:SetPoint("TOPRIGHT",goalDescription,"BOTTOMRIGHT",0,-7)
    target:SetHeight(27)
    target:SetMaxLetters(3)
    local goalStatus
    local capEditorOpen = false
    local setGoal = UI.WorkshopButton(right, "Save Skill Goal", function()
        local key, name = UI.workshopSelectedCharacter, UI.workshopSelectedProfession
        local success, reason = AF:SetWorkshopGoal(key, name, target:GetText())
        if success then
            UI.workshopSelectedGoal = key .. ":" .. name
            page:Refresh()
        else
            goalStatus:SetText(reason or "Unable to save goal")
        end
    end)
    setGoal:SetPoint("TOPLEFT",target,"BOTTOMLEFT",0,-6)
    setGoal:SetPoint("TOPRIGHT",target,"BOTTOMRIGHT",0,-6)
    setGoal:SetHeight(28)
    local clearGoal = UI.WorkshopButton(right, "Clear Goal", function()
        AF:ClearWorkshopGoal(UI.workshopSelectedCharacter, UI.workshopSelectedProfession)
        target:SetText("")
        page:Refresh()
    end)
    clearGoal:SetPoint("TOPLEFT",setGoal,"BOTTOMLEFT",0,-5)
    clearGoal:SetPoint("TOPRIGHT",setGoal,"BOTTOMRIGHT",0,-5)
    clearGoal:SetHeight(28)
    -- A capped skill is already complete for its *recorded* training tier.
    -- Keep an explicit way to plan beyond that tier without asking everyone
    -- at 100/100 to enter an unnecessary goal.
    local capAction = UI.WorkshopButton(right, "Plan Beyond Cap", function()
        if not UI.workshopSelectedCharacter or not UI.workshopSelectedProfession then return end
        capEditorOpen = not capEditorOpen
        page:Refresh()
    end)
    capAction:SetHeight(28)
    capAction:Hide()
    goalStatus = self:Text(right, "small", P.ink)
    goalStatus:SetPoint("TOPLEFT",clearGoal,"BOTTOMLEFT",0,-5)
    goalStatus:SetPoint("TOPRIGHT",clearGoal,"BOTTOMRIGHT",0,-5)
    goalStatus:SetHeight(34)
    goalStatus:SetJustifyV("TOP")
    local linkedProject = UI.WorkshopButton(right, "Open Linked Goal", function()
        local goal = AF:GetWorkshopGoal(UI.workshopSelectedCharacter, UI.workshopSelectedProfession)
        local project = AF:GetWorkshopGoalProject(goal)
        if project then
            UI.selectedProjectId = project.id
            UI:Switch("Projects")
        end
    end)
    linkedProject:SetPoint("BOTTOMLEFT", 17, 16)
    linkedProject:SetPoint("BOTTOMRIGHT", -17, 16)
    linkedProject:SetHeight(28)
    local priorSelection

    target:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        setGoal:Click()
    end)

    local function SelectPair(key, name)
        UI.workshopSelectedCharacter = key
        UI.workshopSelectedProfession = name
        page:Refresh()
    end

    local function CurrentItem(charKey, profName)
        local c = charKey and AF.db.characters[charKey]
        return c, c and c.professions and c.professions[profName]
    end

    function page:Refresh()
        if not AF.db or not AF.db.settings.workshop then return end
        local w = AF.db.settings.workshop
        local chars = AF:GetWorkshopCharacters(w.scope)
        local profs = AF:GetWorkshopProfessions(w.scope)
        UI.WorkshopSetSelected(modeProf, w.browse == "profession")
        UI.WorkshopSetSelected(modeChar, w.browse == "character")
        UI.WorkshopSetSelected(scopeAll, w.scope == "all")
        UI.WorkshopSetSelected(scopeExp, w.scope == "expedition")
        directoryHint:SetText(w.scope == "all" and "Browsing recorded professions for all registered alts." or
            "Expedition members only. This is not verification of self-found rules.")
        local entries = {}
        local benchEntries = {}
        local selectedChar, selectedProf
        local shownProf

        if w.browse == "profession" then
            for _, p in ipairs(profs) do
                entries[#entries+1] = {key=p.name, label=p.name .. "  (" .. #p.characters .. ")", icon=p.icon}
            end
            local chosen
            for _, p in ipairs(profs) do
                if p.name == UI.workshopSelectedProfession then chosen = p; break end
            end
            if not chosen then chosen = profs[1] end
            UI.workshopSelectedProfession = chosen and chosen.name or nil
            UI:FillList(directory, entries, function(entry)
                UI.workshopSelectedProfession = entry.key
                UI.workshopSelectedCharacter = nil
                page:Refresh()
            end, UI.workshopSelectedProfession)
            if chosen then
                shownProf = chosen
                benchTitle:SetText(chosen.name)
                benchSub:SetText("Known on " .. #chosen.characters .. " registered character(s) in this view")
                benchIcon:SetTexture(chosen.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                for _, item in ipairs(chosen.characters) do
                    local c, prof = item.character, item.profession
                    benchEntries[#benchEntries+1] = {
                        key=c.key,
                        label=(c.name or "Unknown") .. "  •  " .. tostring(prof.skill or 0) .. "/" .. tostring(prof.maximum or 0) ..
                            "\n" .. (AF:IsExpeditionMember(c.key) and "Expedition member" or "Independent alt") ..
                            (AF:GetWorkshopGoal(c.key, chosen.name) and "  •  Goal set" or ""),
                        class=c.class,
                    }
                end
                local found = false
                for _, item in ipairs(chosen.characters) do
                    if item.character.key == UI.workshopSelectedCharacter then found=true; break end
                end
                if not found then UI.workshopSelectedCharacter = chosen.characters[1].character.key end
                selectedChar, selectedProf = UI.workshopSelectedCharacter, chosen.name
            else
                benchTitle:SetText("No professions recorded")
                benchSub:SetText("Log onto an alt with a profession, then use Rescan.")
                benchIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                UI.workshopSelectedCharacter = nil
                selectedChar, selectedProf = nil, nil
            end
            UI:FillList(benchList, benchEntries, function(entry)
                SelectPair(entry.key, UI.workshopSelectedProfession)
            end, selectedChar)
        else
            for _, c in ipairs(chars) do
                entries[#entries+1] = {key=c.key, label=(c.name or "Unknown") .. "  •  Lv " .. tostring(c.level or "?"), class=c.class}
            end
            local current
            for _, c in ipairs(chars) do
                if c.key == UI.workshopSelectedCharacter then current = c; break end
            end
            if not current then current = chars[1] end
            UI.workshopSelectedCharacter = current and current.key or nil
            UI:FillList(directory, entries, function(entry)
                UI.workshopSelectedCharacter = entry.key
                UI.workshopSelectedProfession = nil
                page:Refresh()
            end, UI.workshopSelectedCharacter)
            if current then
                benchTitle:SetText(current.name or "Unknown")
                benchSub:SetText("Level " .. tostring(current.level or "?") .. " " .. (current.class or "") ..
                    "  •  " .. (AF:IsExpeditionMember(current.key) and "Expedition" or "Independent"))
                benchIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
                if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[current.class] then
                    benchIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[current.class]))
                else benchIcon:SetTexCoord(0,1,0,1) end
                local sorted = {}
                for name, prof in pairs(current.professions or {}) do
                    sorted[#sorted+1] = {name=name, prof=prof}
                end
                table.sort(sorted, function(a,b) return a.name < b.name end)
                for _, item in ipairs(sorted) do
                    benchEntries[#benchEntries+1] = {
                        key=item.name, icon=item.prof.icon,
                        label=item.name .. "  •  " .. tostring(item.prof.skill or 0) .. "/" .. tostring(item.prof.maximum or 0) ..
                            (AF:GetWorkshopGoal(current.key, item.name) and "\nSkill goal recorded" or "\nNo skill goal yet"),
                    }
                end
                local found = false
                for _, item in ipairs(sorted) do
                    if item.name == UI.workshopSelectedProfession then found=true; break end
                end
                if not found then UI.workshopSelectedProfession = sorted[1] and sorted[1].name or nil end
                selectedChar, selectedProf = current.key, UI.workshopSelectedProfession
            else
                benchTitle:SetText("No characters in this view")
                benchSub:SetText("Choose All Alts or invite a character to your Expedition.")
                benchIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                benchIcon:SetTexCoord(0,1,0,1)
                UI.workshopSelectedProfession = nil
            end
            UI:FillList(benchList, benchEntries, function(entry)
                SelectPair(UI.workshopSelectedCharacter, entry.key)
            end, selectedProf)
        end

        -- No character or profession is selected in an empty list.
        local character, skill = CurrentItem(selectedChar, selectedProf)
        local enabled = character ~= nil and skill ~= nil
        crafterIcon:SetShown(enabled)
        meterBase:SetShown(enabled)
        meterFill:SetShown(enabled)
        target:SetShown(enabled)
        setGoal:SetShown(enabled)
        clearGoal:SetShown(enabled)
        capAction:Hide()
        if not enabled then
            skillGoalTitle:SetText("Skill Goal")
            capEditorOpen = false
            crafter:SetText("No skill selected")
            crafterDetail:SetText("Select a character and a learned profession to set a goal.")
            skillText:SetText("")
            capText:SetText("")
            goalDescription:SetText("No current profession selected.")
            fitGoalCopy()
            goalStatus:SetText("No skill record selected.")
            linkedProject:Hide()
            priorSelection = nil
            benchIcon:SetTexCoord(0, 1, 0, 1)
            lastScanned:SetText("Profession data updates on login")
            return
        end
        if w.browse == "profession" then benchIcon:SetTexCoord(0, 1, 0, 1) end
        local key = selectedChar .. "\t" .. selectedProf
        if priorSelection ~= key then capEditorOpen = false end
        local goal = AF:GetWorkshopGoal(selectedChar, selectedProf)
        crafter:SetText(character.name or "Unknown")
        crafterIcon:SetTexture(skill.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        crafterDetail:SetText(selectedProf .. "\n" .. (AF:IsExpeditionMember(character.key) and "Expedition member" or "Independent alt") ..
            "  •  Last scanned " .. TimeLabel(skill.updated or character.professionsScanned))
        local rank, cap = tonumber(skill.skill) or 0, tonumber(skill.maximum) or 0
        skillText:SetText("Recorded skill: " .. rank .. " / " .. (cap > 0 and cap or "unknown"))
        local targetRank = goal and tonumber(goal.target)
        local denom = (targetRank and targetRank > 0) and math.max(targetRank, rank) or math.max(cap, rank, 1)
        local portion = math.min(1, rank / denom)
        meterFill:SetWidth(math.max(1, (meterBase:GetWidth() > 10 and meterBase:GetWidth()-2 or 200) * portion))
        local atCap = cap > 0 and rank >= cap
        local pendingBeyondCap = atCap and targetRank and targetRank > rank
        capText:SetText(targetRank and ("Goal " .. targetRank .. (rank >= targetRank and "  -  Reached" or "  -  In progress"))
            or (atCap and ("Recorded training cap: " .. rank .. "/" .. cap)
                or "Set a skill goal to create a Project."))
        skillGoalTitle:SetText(atCap and "At Skill Cap" or "Skill Goal")
        if atCap then
            goalDescription:SetText("Recorded " .. rank .. "/" .. cap .. ". Visit a trainer if a higher rank is available; otherwise this training tier is complete.")
        else
            goalDescription:SetText("Your target skill level for " .. (character.name or "this character") .. "'s " .. selectedProf .. ":")
        end
        fitGoalCopy()
        if priorSelection ~= key then
            if target.ClearFocus then target:ClearFocus() end
            target:SetText(targetRank and tostring(targetRank) or "")
            priorSelection = key
        elseif not target:HasFocus() then
            target:SetText(targetRank and tostring(targetRank) or "")
        end
        local project = AF:GetWorkshopGoalProject(goal)
        goalStatus:SetText(goal and (goal.complete and "Target reached! " or "In progress. ") ..
            (project and "Linked Project available." or "Linked Project was deleted.") or
            (atCap and "Current recorded training tier completed. No goal is required." or
            "No goal set. Skill targets may exceed your current trainer cap."))
        -- Keep future goals editable even when the last recorded training tier
        -- has reached its cap. Other capped skills show a compact success state
        -- with an optional goal editor opened intentionally by the player.
        local showGoalEditor = (not atCap) or pendingBeyondCap or capEditorOpen
        target:SetShown(showGoalEditor)
        setGoal:SetShown(showGoalEditor)
        capAction:SetShown(atCap and not pendingBeyondCap)
        capAction.label:SetText(capEditorOpen and "Hide Future Goal" or "Plan Beyond Cap")
        capAction:ClearAllPoints()
        if showGoalEditor then
            capAction:SetPoint("TOPLEFT",setGoal,"BOTTOMLEFT",0,-5)
            capAction:SetPoint("TOPRIGHT",setGoal,"BOTTOMRIGHT",0,-5)
        else
            capAction:SetPoint("TOPLEFT",goalDescription,"BOTTOMLEFT",0,-7)
            capAction:SetPoint("TOPRIGHT",goalDescription,"BOTTOMRIGHT",0,-7)
        end
        local hasGoal = goal ~= nil
        clearGoal:SetShown(hasGoal)
        clearGoal:ClearAllPoints()
        local aboveClear = (atCap and not pendingBeyondCap) and capAction or setGoal
        clearGoal:SetPoint("TOPLEFT",aboveClear,"BOTTOMLEFT",0,-5)
        clearGoal:SetPoint("TOPRIGHT",aboveClear,"BOTTOMRIGHT",0,-5)
        goalStatus:ClearAllPoints()
        local aboveStatus = hasGoal and clearGoal or ((atCap and not pendingBeyondCap) and capAction or setGoal)
        goalStatus:SetPoint("TOPLEFT",aboveStatus,"BOTTOMLEFT",0,-6)
        goalStatus:SetPoint("TOPRIGHT",aboveStatus,"BOTTOMRIGHT",0,-6)
        linkedProject:SetShown(project ~= nil)
        lastScanned:SetText("Current alt: " .. (AF:CurrentCharacter() and AF:CurrentCharacter().name or "Unknown"))
    end
end

function UI:BuildProjects(page)
    local left, center, right = CreateColumns(page, 244, 271)
    Section(left, "Goals & Crafting Queue")
    local add = self:Button(left, "+ New Goal", function()
        AF.db.settings.guided.goalsView='Active'
        local project = AF:AddProject()
        UI.selectedProjectId = project.id
        if UI.pageViews and UI.pageViews.Goals then UI.pageViews.Goals:Refresh() else page:Refresh() end
    end)
    add:SetPoint("TOPLEFT", 13, -49); add:SetPoint("TOPRIGHT", -13, -49)
    local queueHelp = Line(left, 117, "small", 23)
    queueHelp:SetText("Drag [=] handle or move selected craft.")
    -- Diagnostic toast controls moved into Settings > Developer Tools.
    local projectList = PanelScroll(left, 145, 21)

    Section(center, "Goal Details")
    local titleLabel = Line(center, 49, "small", 20)
    titleLabel:SetText("Goal title")
    local titleEdit = self:Input(center, 310)
    titleEdit:SetPoint("TOPLEFT", 15, -76)
    titleEdit:SetPoint("TOPRIGHT", -15, -76)
    titleEdit:SetScript("OnTextChanged", function(self, userInput)
        if not userInput or UI.settingProject then return end
        local p = AF:FindRecord(AF.db.projects, UI.selectedProjectId)
        if p then p.title = self:GetText(); p.updated = time() end
    end)
    local ownerButton = self:Button(center, "", function()
        local p = AF:FindRecord(AF.db.projects, UI.selectedProjectId)
        if p then
            -- Crafting plans are bound to a recipe known by their owner. Moving
            -- the assignment without changing its recipe can invalidate it.
            if p.explorationGoal then
                AF.Print('Exploration Goal scope is fixed at creation. Make a new goal for another character or scope.')
                return
            end
            if p.crafting then
                AF.Print("Crafting plan owner is fixed to its recipe. Create a new plan on the other crafter.")
                return
            end
            p.owner = AF:CycleOwner(p.owner); p.updated = time(); page:Refresh()
        end
    end)
    ownerButton:SetPoint("TOPLEFT", 16, -124)
    ownerButton:SetPoint("TOPRIGHT", -16, -124)

    local descriptionLabel = Line(center, 170, "small", 22)
    descriptionLabel:SetText("Project description")
    local desc = self:Multiline(center)
    desc:SetPoint("TOPLEFT", 17, -204)
    desc:SetPoint("BOTTOMRIGHT", -29, 105)
    desc:SetScript("OnSizeChanged", function(self,w) UI:ResizeEditor(desc.edit) end)
    desc.edit:SetScript("OnTextChanged", function(self, userInput)
        if not userInput or UI.settingProject then return end
        local p = AF:FindRecord(AF.db.projects, UI.selectedProjectId)
        if p then p.description = self:GetText(); p.updated = time() end
        UI:ResizeEditor(self)
    end)

    -- Keep editing separate from the goal dashboard. Prior project titles and
    -- descriptions retain their original fields; there is no database migration.
    local editor=self:NewFrame('Frame',self.frame or UIParent,'AzerothFoundryGoalEditor')
    editor:SetFrameStrata('FULLSCREEN_DIALOG')
    editor:SetSize(585,470)
    editor:SetPoint('CENTER',self.frame or UIParent,'CENTER')
    self:Background(editor,P.parchmentLight,true)
    editor:EnableMouse(true)
    editor:Hide()
    self.goalEditor=editor
    if UISpecialFrames then table.insert(UISpecialFrames,'AzerothFoundryGoalEditor') end
    local editHead=self:SectionTitle(editor,'Edit Goal')
    editHead:SetPoint('TOPLEFT',19,-16);editHead:SetPoint('TOPRIGHT',-48,-16)
    local editClose=CreateFrame('Button',nil,editor,'UIPanelCloseButton')
    editClose:SetPoint('TOPRIGHT',-9,-8);editClose:SetSize(30,30)
    editClose:SetScript('OnClick',function() editor:Hide();page:Refresh() end)
    titleLabel:SetParent(editor)
    titleLabel:ClearAllPoints();titleLabel:SetPoint('TOPLEFT',17,-65);titleLabel:SetPoint('TOPRIGHT',-17,-65)
    titleEdit:SetParent(editor)
    titleEdit:ClearAllPoints();titleEdit:SetPoint('TOPLEFT',16,-94);titleEdit:SetPoint('TOPRIGHT',-16,-94)
    descriptionLabel:SetParent(editor)
    descriptionLabel:ClearAllPoints();descriptionLabel:SetPoint('TOPLEFT',17,-145);descriptionLabel:SetPoint('TOPRIGHT',-17,-145)
    descriptionLabel:SetText('Personal notes and description')
    desc:SetParent(editor)
    desc:ClearAllPoints();desc:SetPoint('TOPLEFT',17,-178);desc:SetPoint('BOTTOMRIGHT',-29,65)
    local finishEdit=self:Button(editor,'Done Editing',function() editor:Hide();page:Refresh() end)
    finishEdit:SetPoint('BOTTOMRIGHT',-18,18);finishEdit:SetSize(155,30)
    local editButton=self:Button(center,'Edit Goal / Notes',function()
        if AF:FindRecord(AF.db.projects,UI.selectedProjectId) then
            editor:Show();editor:Raise()
        end
    end)
    editButton:SetPoint('BOTTOMLEFT',16,82);editButton:SetSize(172,28)
    local pinButton=self:Button(center,'Track on Screen',function()
        local id=UI.selectedProjectId
        if not id then return end
        local ok,msg=AF:PinGuidedGoal(id)
        if not ok then AF.Print(msg or 'Unable to track this goal.') end
        page:Refresh()
    end)
    pinButton:SetPoint('BOTTOMRIGHT',-17,82);pinButton:SetSize(154,28)
    local goalHeadline=self:Text(center,'title',P.ink)
    goalHeadline:SetPoint('TOPLEFT',17,-52);goalHeadline:SetPoint('TOPRIGHT',-15,-52)
    goalHeadline:SetHeight(61);goalHeadline:SetJustifyV('TOP')
    local goalProgressTitle=self:SectionTitle(center,'Goal Progress & Next Steps')
    goalProgressTitle:SetPoint('TOPLEFT',14,-173)
    goalProgressTitle:SetPoint('TOPRIGHT',-14,-173)
    local goalProgress=self:List(center,47)
    goalProgress:SetPoint('TOPLEFT',12,-211)
    goalProgress:SetPoint('BOTTOMRIGHT',-22,191)

    -- Purely informational: never marks a checklist task complete.
    local queueSummary = UI:Text(center, "small", P.ink)
    queueSummary:SetPoint("BOTTOMLEFT", 17, 115)
    queueSummary:SetPoint("BOTTOMRIGHT", -18, 115)
    queueSummary:SetHeight(85)
    queueSummary:SetJustifyV("TOP")
    queueSummary:Hide()
    local priorityUp = self:Button(left, "Move Up", function()
        local index=AF:GetCraftingQueuePosition(UI.selectedProjectId)
        if index and AF:MoveCraftingProject(UI.selectedProjectId,index-1) then page:Refresh() end
    end)
    priorityUp:SetSize(104, 27)
    priorityUp:SetPoint("TOPLEFT", left, "TOPLEFT", 13, -79)
    local priorityDown = self:Button(left, "Move Down", function()
        local index=AF:GetCraftingQueuePosition(UI.selectedProjectId)
        if index and AF:MoveCraftingProject(UI.selectedProjectId,index+1) then page:Refresh() end
    end)
    priorityDown:SetSize(104,27)
    priorityDown:SetPoint("TOPRIGHT", left, "TOPRIGHT", -13, -79)

    local complete = self:Button(center, "Mark Complete", function()
        local p = AF:FindRecord(AF.db.projects, UI.selectedProjectId)
        if p and p.explorationGoal then
            AF.Print('Exploration Goals update from recorded evidence. To mark something manually, use a Personal Goal.')
            return
        end
        if p then
            p.done = not p.done; p.updated = time()
            p.completedAt=p.done and p.updated or nil
            if AF.NormalizeCraftingQueue then AF:NormalizeCraftingQueue() end
            if p.done and UI.ShowGoalToast then
                UI:ShowGoalToast('Goal Complete!', p.title or 'Goal')
            end
            if AF.SyncGuidedGoals then AF:SyncGuidedGoals(false) end
            page:Refresh()
        end
    end)
    complete:SetPoint("BOTTOMLEFT", 16, 46)
    complete:SetSize(155, 29)
    local delete = self:Button(center, "Delete Goal...", function()
        local p = AF:FindRecord(AF.db.projects, UI.selectedProjectId)
        if p then
            UI:ConfirmDelete("project", p.id, function()
                UI.selectedProjectId = nil
                page:Refresh()
            end)
        end
    end)
    delete:SetPoint("BOTTOMRIGHT", -17, 46)
    delete:SetSize(137, 29)
    local repeatGoal=self:Button(center,'Repeat Goal',function()
        local repeated,err=AF:RepeatGoal(UI.selectedProjectId)
        if not repeated then AF.Print(err or 'Unable to repeat this goal.');return end
        UI.selectedProjectId=repeated.id
        AF.db.settings.guided.goalsView='Active'
        if UI.pageViews and UI.pageViews.Goals then UI.pageViews.Goals:Refresh() end
    end)
    repeatGoal:SetPoint('BOTTOM',center,'BOTTOM',0,46)
    repeatGoal:SetSize(136,29)
    local selectedCount = Line(center, 0, "small", 24)
    selectedCount:ClearAllPoints(); selectedCount:SetPoint("BOTTOMLEFT", 17, 13); selectedCount:SetPoint("BOTTOMRIGHT", -15, 13)

    Section(right, "Checklist & Craft Routes")
    local taskInput = self:Input(right, 150)
    taskInput:SetPoint("TOPLEFT", 14, -56); taskInput:SetPoint("TOPRIGHT", -67, -56)
    local addTask = self:Button(right, "Add", function()
        local p = AF:FindRecord(AF.db.projects, UI.selectedProjectId)
        local t = taskInput:GetText():match("^%s*(.-)%s*$")
        if p and t and t ~= "" then
            table.insert(p.tasks, {id=AF:NextID(), text=t, done=false})
            p.updated = time()
            taskInput:SetText("")
            page:Refresh()
        end
    end)
    addTask:SetPoint("TOPRIGHT", -11, -56); addTask:SetSize(49, 27)
    taskInput:SetScript("OnEnterPressed", function(self) self:ClearFocus(); addTask:Click() end)
    local tasks = self:List(right, 39)
    tasks:SetPoint("TOPLEFT", 10, -99); tasks:SetPoint("BOTTOMRIGHT", -22, 15)

    local routeItemIndex = 1
    local routeItem=self:Button(right,"Choose Ingredient",function()
        local plan=UI.selectedQueuePlan
        if not plan or #plan.steps==0 then return end
        routeItemIndex=(routeItemIndex % #plan.steps)+1
        page:Refresh()
    end)
    routeItem:SetPoint("BOTTOMLEFT", 12, 57);routeItem:SetPoint("BOTTOMRIGHT",-12,57)
    local routeMode=self:Button(right,"Route: Auto",function()
        local plan=UI.selectedQueuePlan
        local step=plan and plan.steps[routeItemIndex]
        if step then
            AF:SetCraftingRoute(UI.selectedProjectId,step.itemID,
                step.route=='direct' and 'auto' or 'direct')
            page:Refresh()
        end
    end)
    routeMode:SetPoint("BOTTOMLEFT",12,21);routeMode:SetPoint("BOTTOMRIGHT",-12,21)

    local lastSelected = nil
    function page:Refresh()
        local projects=AF.db.projects
        local queue=AF:EvaluateCraftingQueue()
        local visible=AF:GetGoalsForView(AF.db.settings.guided.goalsView)
        local selected=AF:FindRecord(visible,UI.selectedProjectId)
        if not selected then
            selected=visible[1]
            UI.selectedProjectId=selected and selected.id or nil
        end
        local entries={}
        local craftList=AF:GetCraftingQueueProjects()
        local craftPosition={}
        for i,p in ipairs(craftList) do craftPosition[p.id]=i end
        for _,p in ipairs(visible) do
            local i=craftPosition[p.id]
            if i then
                local status=queue.byId[p.id]
                entries[#entries+1]={key=p.id,crafting=true,
                    label='[=] '..i..'. '..(p.title or 'Crafting goal')..'  ['..AF:CraftStatusLabel(status and status.status)..']'}
            else
                entries[#entries+1]={key=p.id,
                    label=(p.done and '[Done] ' or '')..(p.title or 'Untitled goal')}
            end
        end
        UI:FillList(projectList,entries,function(entry)
            UI.selectedProjectId=entry.key
            page:Refresh()
        end,UI.selectedProjectId)
        -- WoW buttons support OnDragStart/OnDragStop. Keep the Up/Down controls
        -- as an accessible fallback if the client doesn't dispatch a drag.
        for i,entry in ipairs(entries) do
            local row=projectList.rows[i]
            if row and entry.crafting then
                row:RegisterForDrag('LeftButton')
                row:SetScript('OnDragStart',function(self)
                    UI.dragCraftId=entry.key
                    if self.SetAlpha then self:SetAlpha(0.6) end
                end)
                row:SetScript('OnDragStop',function(self)
                    if self.SetAlpha then self:SetAlpha(1) end
                    local moving=UI.dragCraftId
                    UI.dragCraftId=nil
                    if not moving then return end
                    local target
                    for j,other in ipairs(entries) do
                        local item=projectList.rows[j]
                        if other.crafting and item and item.IsMouseOver and item:IsMouseOver() then
                            target=other.key;break
                        end
                    end
                    if target and target~=moving and AF:MoveCraftingProjectOnto(moving,target) then
                        page:Refresh()
                    end
                end)
            elseif row then
                row:SetScript('OnDragStart',nil)
                row:SetScript('OnDragStop',nil)
                if row.SetAlpha then row:SetAlpha(1) end
            end
        end
        if not selected then
            UI.settingProject=true;titleEdit:SetText('');desc.edit:SetText('');UI.settingProject=false
            titleEdit:Disable();desc.edit:Disable()
            ownerButton:Hide();complete:Hide();delete:Hide();addTask:Hide();taskInput:Hide();editButton:Hide();pinButton:Hide();repeatGoal:Hide()
            goalHeadline:SetText('No goal selected')
            UI:FillList(goalProgress,{},function() end)
            if editor:IsShown() then editor:Hide() end
            priorityUp:Hide();priorityDown:Hide();queueSummary:Hide()
            lastSelected=nil
            routeItem:Hide();routeMode:Hide()
            selectedCount:SetText('Create a goal to begin.')
            UI:FillList(tasks,{},function() end)
            return
        end
        titleEdit:Enable();desc.edit:Enable()
        ownerButton:Show();complete:Show();delete:Show();addTask:Show();taskInput:Show();editButton:Show();pinButton:Show()
        repeatGoal:SetShown(selected.done and not selected.explorationGoal)
        complete:SetShown(not selected.explorationGoal)
        pinButton.label:SetText(AF:GoalIsPinned(selected.id) and 'Untrack Goal' or 'Track on Screen')
        if lastSelected~=selected.id then
            titleEdit:ClearFocus();desc.edit:ClearFocus()
            UI.settingProject=true
            titleEdit:SetText(selected.title or '')
            desc.edit:SetText(selected.description or '')
            UI:ResizeEditor(desc.edit)
            UI.settingProject=false
            lastSelected=selected.id
            routeItemIndex=1
        elseif not titleEdit:HasFocus() then
            UI.settingProject=true;titleEdit:SetText(selected.title or '');UI.settingProject=false
        end
        ownerButton.label:SetText('Assigned: '..AF:CharacterLabel(selected.owner)..
            (selected.crafting and '  (recipe-bound)' or '  (click to change)'))
        complete.label:SetText(selected.done and 'Mark Incomplete' or 'Mark Complete')
        local selectedPlan=queue.byId[selected.id] or (selected.crafting and AF:EvaluateIndependentCraftingGoal(selected))
        local taskEntries, autoCount, autoReady, manualCount, manualDone={},0,0,0,0
        for _,item in ipairs(selected.tasks or {}) do
            local automatic,status=AF:GetCraftingMaterialTaskStatus(selected,item,selectedPlan)
            if automatic then
                autoCount=autoCount+1
                if status=='inbags' then autoReady=autoReady+1 end
                taskEntries[#taskEntries+1]={key=item.id,automatic=true,label=automatic}
            else
                manualCount=manualCount+1
                if item.done then manualDone=manualDone+1 end
                taskEntries[#taskEntries+1]={key=item.id,label=(item.done and '[x]  ' or '[ ]  ')..(item.text or '')}
            end
        end
        if selected.crafting then
            selectedCount:SetText('Auto-checks: '..autoReady..'/'..autoCount..' in bags  |  Manual: '..manualDone..'/'..manualCount)
        else
            selectedCount:SetText('Checklist progress: '..ProgressText(selected))
        end
        UI:FillList(tasks,taskEntries,function(entry)
            if entry.automatic then return end -- Derived indicator; never rewrite manual completion.
            for _,item in ipairs(selected.tasks) do
                if item.id==entry.key then item.done=not item.done;break end
            end
            selected.updated=time();page:Refresh()
        end)
        local crafted=selected.crafting~=nil
        -- The central page presents goal data. The multiline editor lives in
        -- its own modal and is never squeezed into the main dashboard.
        local headline=(selected.title and selected.title~='') and selected.title or 'Untitled goal'
        goalHeadline:SetText(headline..'\n'..(selected.done and
            ('Completed'..(selected.completedAt and (' • '..(date and date('%b %d %Y',selected.completedAt) or 'dated')) or ' • date not recorded'))
            or (selected.explorationGoal and 'Auto-tracked Atlas goal' or crafted and 'Crafting goal' or 'Personal goal')))
        local progressRows={}
        if selected.explorationGoal then
            local state=AF:GetExplorationGoalState(selected)
            local g=selected.explorationGoal
            progressRows[#progressRows+1]={key='exploration-head',label='Atlas Goal: '..(g.kind=='visit' and 'Recorded zone visit' or 'Known regional quests')..'  •  '..(state and state.current or 0)..'/'..(state and state.total or 0)}
            progressRows[#progressRows+1]={key='exploration-scope',label='Scope: '..(g.scope=='all' and 'All recorded characters' or AF:CharacterLabel(g.characterKey))..'\n'..(state and state.detail or 'No supporting observations yet.')}
            for i,m in ipairs((state and state.milestones) or {}) do
                progressRows[#progressRows+1]={key='exploration-'..i,
                    label=(m.status=='confirmed' and '|cff25834d[x]|r ' or '[ ] ')..m.text..'\n'..(m.detail or '')}
            end
        elseif selected.guided then
            local d,total,milestones=AF:GuidedMilestoneSummary(selected)
            progressRows[#progressRows+1]={key='guided',label='Guided Goal: '..(selected.guided.kind=='craft' and 'Craft the Item' or 'Learn the Recipe')..'   •   '..d..'/'..total..' required milestones'}
            for i,m in ipairs(milestones) do
                local marker=m.status=='confirmed' and '|cff25834d[x]|r' or
                    (m.status=='recorded' and '|cff9a703c[~]|r' or '[ ]')
                progressRows[#progressRows+1]={key='guided-'..i,
                    label=marker..'  '..m.text..'\n'..(m.detail or '')..(not m.required and ' • optional' or '')}
            end
        elseif crafted then
            progressRows[#progressRows+1]={key='recipe',label='Crafting target: '..tostring(selected.crafting.quantity or 1)..' attempt(s)\nRecipe ID: '..tostring(selected.crafting.recipeID or '?')}
            if selectedPlan and selectedPlan.status then
                progressRows[#progressRows+1]={key='state',label='Production readiness: '..AF:CraftStatusLabel(selectedPlan.status)}
                for index,step in ipairs(selectedPlan.steps or {}) do
                    progressRows[#progressRows+1]={key='ing-'..index,
                        icon=(AF:GetItemPresentation(step.itemID) or {}).icon,
                        label=(step.name or 'Ingredient')..': '..step.covered..'/'..step.needed..' allocated'..
                            (step.missing>0 and ('  •  need '..step.missing) or '')}
                end
            end
        elseif selected.workshopGoal then
            local g=AF:GetWorkshopGoal(selected.workshopGoal.characterKey,selected.workshopGoal.profession)
            progressRows[#progressRows+1]={key='skill',label='Profession milestone: '..(selected.workshopGoal.profession or '')..'\n'..
                (g and (tostring(g.current or 0)..' / '..tostring(g.target or '?')) or 'Goal record no longer available')}
        else
            progressRows[#progressRows+1]={key='custom',label='Personal goal • Track custom checklist entries on the right.'}
        end
        if selected.description and selected.description~='' then
            local short=selected.description:gsub('\n','  ')
            if #short>180 then short=short:sub(1,177)..'...' end
            progressRows[#progressRows+1]={key='notes',label='Notes preview: '..short}
        end
        UI:FillList(goalProgress,progressRows,function() end)
        UI:ResizeEditor(desc.edit)
        queueSummary:SetShown(crafted)
        local inQueue=AF:GetCraftingQueuePosition(selected.id)
        priorityUp:SetShown(crafted and inQueue~=nil);priorityDown:SetShown(crafted and inQueue~=nil)
        routeItem:SetShown(crafted);routeMode:SetShown(crafted)
        if crafted then
            tasks:ClearAllPoints()
            tasks:SetPoint('TOPLEFT',10,-99);tasks:SetPoint('BOTTOMRIGHT',-22,103)
            local index=AF:GetCraftingQueuePosition(selected.id)
            priorityUp:SetEnabled(index and index>1 or false)
            priorityDown:SetEnabled(index and index<#craftList or false)
            local plan=selectedPlan
            UI.selectedQueuePlan=plan
            local lines={(index and ('QUEUE #'..index) or 'CRAFTING GOAL (not queued)')..'  •  '..AF:CraftStatusLabel(plan and plan.status)}
            if plan and plan.reasons[1] then lines[#lines+1]=plan.reasons[1] end
            if plan then
                for _,step in ipairs(plan.steps or {}) do
                    lines[#lines+1]=step.name..': '..step.covered..'/'..step.needed..' accounted'..
                        (step.missing>0 and (' • need '..step.missing) or '')
                end
                if #plan.conflicts>0 then
                    lines[#lines+1]='Some material stock is allocated to higher-priority crafts.'
                end
                if #plan.crafts>0 then
                    local x=plan.crafts[1]
                    lines[#lines+1]='Next: craft '..AF:GetItemPresentation(x.itemID).name..' with '..x.crafter..'.'
                end
            end
            lines[#lines+1]='Virtual allocations only; bag/bank counts may be stale.'
            queueSummary:SetText(table.concat(lines,'\n'))
            if plan and #plan.steps>0 then
                if routeItemIndex>#plan.steps then routeItemIndex=1 end
                local step=plan.steps[routeItemIndex]
                routeItem.label:SetText('Ingredient: '..step.name)
                routeMode.label:SetText('Route: '..(step.route=='direct' and 'Obtain directly' or 'Auto subcraft'))
            else
                routeItem.label:SetText('No ingredients to choose')
                routeMode.label:SetText('Route unavailable')
            end
            routeItem:SetEnabled(plan and #plan.steps>0 or false)
            routeMode:SetEnabled(plan and #plan.steps>0 or false)
        else
            UI.selectedQueuePlan=nil
            tasks:ClearAllPoints()
            tasks:SetPoint('TOPLEFT',10,-99);tasks:SetPoint('BOTTOMRIGHT',-22,15)
        end
    end
end

function UI:BuildNotes(page)
    local left, center, right = CreateColumns(page, 248, 239)
    Section(left, "Notebook")
    local add = self:Button(left, "+ New Note", function()
        local n = AF:AddNote()
        UI.selectedNoteId = n.id
        page:Refresh()
    end)
    add:SetPoint("TOPLEFT", 13, -48); add:SetPoint("TOPRIGHT", -13, -48)
    local noteList = PanelScroll(left, 88, 15)

    Section(center, "Your Notes")
    local titleLabel = Line(center, 52, "small", 20)
    titleLabel:SetText("Title")
    local title = self:Input(center)
    title:SetPoint("TOPLEFT", 16, -78); title:SetPoint("TOPRIGHT", -16, -78)
    local owner = self:Button(center, "Account-wide", function()
        local n = AF:FindRecord(AF.db.notes, UI.selectedNoteId)
        if n then n.owner = AF:CycleOwner(n.owner); n.updated = time(); page:Refresh() end
    end)
    owner:SetPoint("TOPLEFT", 16, -121); owner:SetPoint("TOPRIGHT", -16, -121)
    local bodyLabel = Line(center, 169, "small", 20)
    bodyLabel:SetText("Note")
    local scroll = self:Multiline(center)
    scroll:SetPoint("TOPLEFT", 18, -201); scroll:SetPoint("BOTTOMRIGHT", -29, 68)
    scroll:SetScript("OnSizeChanged", function(self,w) UI:ResizeEditor(scroll.edit) end)
    local delete = self:Button(center, "Delete Note...", function()
        if UI.selectedNoteId then
            UI:ConfirmDelete("note", UI.selectedNoteId, function()
                UI.selectedNoteId = nil
                page:Refresh()
            end)
        end
    end)
    delete:SetPoint("BOTTOMRIGHT", -17, 20); delete:SetSize(138, 28)
    local changed = Line(center, 0, "small", 25)
    changed:ClearAllPoints()
    changed:SetPoint("BOTTOMLEFT", 17, 21)
    changed:SetPoint("BOTTOMRIGHT", -163, 21)

    Section(right, "Journal Tips")
    local tips = Line(right, 59, "small", 282)
    tips:SetJustifyV("TOP")
    tips:SetText("Notes are account-wide by default.\n\nAssign notes to an alt to keep that character's plans organized.\n\nNotes are saved automatically to WoW's SavedVariables when you log out or reload.\n\nLater versions will let you link notes directly to recipes, items, zones, and projects.")
    local dateLabel = Line(right, 367, "small", 70)
    dateLabel:SetJustifyV("TOP")
    local lastSelected = nil
    title:SetScript("OnTextChanged", function(self, userInput)
        if not userInput or UI.settingNote then return end
        local n = AF:FindRecord(AF.db.notes, UI.selectedNoteId)
        if n then n.title = self:GetText(); n.updated = time() end
    end)
    scroll.edit:SetScript("OnTextChanged", function(self, userInput)
        if not userInput or UI.settingNote then return end
        local n = AF:FindRecord(AF.db.notes, UI.selectedNoteId)
        if n then n.body = self:GetText(); n.updated = time() end
        UI:ResizeEditor(self)
    end)

    function page:Refresh()
        local notes = AF.db.notes
        local n = AF:FindRecord(notes, UI.selectedNoteId)
        if not n then n=notes[#notes]; UI.selectedNoteId=n and n.id or nil end
        local entries = {}
        for i=#notes,1,-1 do
            local note=notes[i]
            entries[#entries+1]={key=note.id,label=note.title or "Untitled note"}
        end
        UI:FillList(noteList, entries, function(entry)
            UI.selectedNoteId=entry.key
            page:Refresh()
        end, UI.selectedNoteId)
        if not n then
            UI.settingNote = true; title:SetText(""); scroll.edit:SetText(""); UI.settingNote = false
            title:Disable(); scroll.edit:Disable(); owner:Hide(); delete:Hide()
            changed:SetText("Create a note to begin."); dateLabel:SetText("")
            return
        end
        title:Enable(); scroll.edit:Enable(); owner:Show(); delete:Show()
        if lastSelected ~= n.id then
            title:ClearFocus(); scroll.edit:ClearFocus()
            UI.settingNote = true
            title:SetText(n.title or "")
            scroll.edit:SetText(n.body or "")
            UI:ResizeEditor(scroll.edit)
            UI.settingNote = false
            lastSelected = n.id
        elseif not title:HasFocus() then
            UI.settingNote = true; title:SetText(n.title or ""); UI.settingNote = false
        end
        owner.label:SetText("Linked to: " .. AF:CharacterLabel(n.owner) .. "  (click to change)")
        changed:SetText("Edits save automatically")
        dateLabel:SetText("Last edited:\n" .. TimeLabel(n.updated))
    end
end

-- v0.3.1: Player-observed Recipe Library. Full external catalog is intentionally
-- not exposed. The offline ProfessionDB reference enriches observed recipes.
function UI:BuildRecipes(page)
    local left, center, right = UI.WorkshopPanels(page,"Recipes",.205,.32)
    Section(left, "Recipe Filters")
    local filtersExpanded=true
    local filterToggle=UI.WorkshopButton(left,'Hide Filters  -',function()
        filtersExpanded=not filtersExpanded
        page:Refresh()
    end)
    filterToggle:SetPoint('TOPLEFT',left,'TOPLEFT',13,-46)
    filterToggle:SetPoint('TOPRIGHT',left,'TOPRIGHT',-13,-46)
    filterToggle:SetHeight(25)
    local learnedButton = UI.WorkshopButton(left, "Learned", function()
        AF.db.settings.recipes.status = "learned"; UI.recipeSelectedID=nil; page:Refresh()
    end)
    learnedButton:SetPoint("TOPLEFT", 13, -83)
    learnedButton:SetPoint("TOPRIGHT", left, "TOP", -3, -83)
    local unlearnedButton = UI.WorkshopButton(left, "Unlearned", function()
        AF.db.settings.recipes.status = "unlearned"; UI.recipeSelectedID=nil; page:Refresh()
    end)
    unlearnedButton:SetPoint("TOPLEFT", left, "TOP", 3, -83)
    unlearnedButton:SetPoint("TOPRIGHT", -13, -83)
    local allButton = UI.WorkshopButton(left, "All Alts", function()
        AF.db.settings.recipes.scope="all"; page:Refresh()
    end)
    allButton:SetPoint("TOPLEFT", 13, -120)
    allButton:SetPoint("TOPRIGHT", left, "TOP", -3, -120)
    local expeditionButton = UI.WorkshopButton(left, "Expedition", function()
        AF.db.settings.recipes.scope="expedition"; page:Refresh()
    end)
    expeditionButton:SetPoint("TOPLEFT", left, "TOP", 3, -120)
    expeditionButton:SetPoint("TOPRIGHT", -13, -120)
    local charButton = UI.WorkshopButton(left, "All Characters", nil)
    charButton:SetPoint("TOPLEFT", 13, -159)
    charButton:SetPoint("TOPRIGHT", -13, -159)
    -- ASCII caret is deliberately used here: several Forever/Retail fonts
    -- display Unicode dropdown triangles as empty square glyphs.
    charButton.label:ClearAllPoints()
    charButton.label:SetPoint("TOPLEFT", charButton, "TOPLEFT", 4, -1)
    charButton.label:SetPoint("BOTTOMRIGHT", charButton, "BOTTOMRIGHT", -23, 1)
    local charCaret = self:Text(charButton, "small", P.gold, "RIGHT")
    charCaret:SetPoint("TOPRIGHT", charButton, "TOPRIGHT", -9, -2)
    charCaret:SetPoint("BOTTOMRIGHT", charButton, "BOTTOMRIGHT", -9, 2)
    charCaret:SetWidth(13)
    charCaret:SetText("v")

    -- The character selector uses the same safe native ScrollFrame/flyout
    -- approach as Chronicle, not the old click-to-cycle behavior.
    local characterMenu = CreateFrame("Frame", nil, page)
    self:Background(characterMenu, P.leather, true)
    characterMenu:SetFrameStrata("DIALOG")
    characterMenu:SetFrameLevel(math.max(35, (page:GetFrameLevel() or 1) + 28))
    characterMenu:EnableMouse(true)
    characterMenu:Hide()
    local characterScroll = CreateFrame("ScrollFrame", nil, characterMenu, "UIPanelScrollFrameTemplate")
    characterScroll:SetPoint("TOPLEFT", characterMenu, "TOPLEFT", 7, -7)
    characterScroll:SetPoint("BOTTOMRIGHT", characterMenu, "BOTTOMRIGHT", -28, 7)
    local characterChild = CreateFrame("Frame", nil, characterScroll)
    characterChild:SetSize(155, 1)
    characterScroll:SetScrollChild(characterChild)
    self:InsetWorkshopScrollBar(characterScroll)
    characterScroll:EnableMouseWheel(true)
    characterScroll:SetScript("OnMouseWheel", function(scroll, delta)
        local limit = math.max(0, (characterChild:GetHeight() or 0) - (scroll:GetHeight() or 0))
        scroll:SetVerticalScroll(math.max(0, math.min(limit, (scroll:GetVerticalScroll() or 0) - delta * 30)))
    end)
    local characterRows = {}
    local function closeCharacterMenu()
        characterMenu:Hide()
    end
    local function openCharacterMenu()
        if characterMenu:IsShown() then
            closeCharacterMenu()
            return
        end
        local opts = AF.db and AF.db.settings and AF.db.settings.recipes
        if not opts then return end
        local options = {{key=false, label="All Characters"}}
        for _, c in ipairs(AF:GetWorkshopCharacters(opts.scope)) do
            options[#options+1] = {key=c.key, label=c.name or AF:CharacterLabel(c.key)}
        end
        -- Keep the menu inside the panel at shorter window sizes.
        local available = math.max(3, math.floor(((left:GetHeight() or 620) - 220) / 27))
        local visible = math.min(#options, 9, available)
        local width = math.max(174, math.floor(charButton:GetWidth() or 190))
        characterMenu:SetSize(width, 14 + visible * 27)
        characterMenu:ClearAllPoints()
        characterMenu:SetPoint("TOPLEFT", charButton, "BOTTOMLEFT", 0, -2)
        characterChild:SetSize(width - 38, math.max(1, #options * 27 + 2))
        for i, option in ipairs(options) do
            local row = characterRows[i]
            if not row then
                row = UI.WorkshopButton(characterChild, "", nil)
                row:SetHeight(26)
                row:SetPoint("TOPLEFT", characterChild, "TOPLEFT", 0, -(i-1)*27)
                row:SetPoint("TOPRIGHT", characterChild, "TOPRIGHT", 0, -(i-1)*27)
                characterRows[i] = row
            end
            local key = option.key
            row.label:SetText(option.label)
            UI.WorkshopSetSelected(row, (UI.recipeCharacterFilter or false) == key)
            row:SetScript("OnClick", function()
                closeCharacterMenu()
                UI.recipeCharacterFilter = key or nil
                UI.recipeSelectedID = nil
                page:Refresh()
            end)
            row:Show()
        end
        for i=#options+1, #characterRows do characterRows[i]:Hide() end
        local bar = UI:ListScrollBar(characterScroll)
        if bar then bar:SetShown(#options > visible) end
        characterScroll:SetVerticalScroll(0)
        characterMenu:Show()
    end
    charButton:SetScript("OnClick", openCharacterMenu)
    page:HookScript("OnHide", closeCharacterMenu)
    local sideHint = Line(left, 201, "small", 38)
    sideHint:SetJustifyV("TOP")
    local filterProfessionHeading = Section(left, "Scanned Professions", 245)
    local professions = PanelScroll(left, 280, 88)
    UI:InsetWorkshopScrollBar(professions)
    professions:ClearAllPoints()
    professions:SetPoint("TOPLEFT",left,"TOPLEFT",12,-280)
    professions:SetPoint("BOTTOMRIGHT",left,"BOTTOMRIGHT",-35,88)
    local manualScan = UI.WorkshopButton(left, "Scan Open Profession", function()
        local ok, reason = AF:ScanOpenRecipes(false)
        if not ok then AF.Print(reason) end
        page:Refresh()
    end)
    manualScan:SetPoint("BOTTOMLEFT", 13, 16)
    manualScan:SetPoint("BOTTOMRIGHT", -13, 16)
    local libState = self:Text(left, "small", P.ink, "CENTER")
    libState:SetPoint("BOTTOMLEFT", 14, 50)
    libState:SetPoint("BOTTOMRIGHT", -14, 50)
    libState:SetHeight(28)

    Section(center, "Recorded Recipes")
    -- Captured from the owner's open profession. Difficulty is intentionally
    -- saved per character, not inferred from another character's skill rank.
    local skillColors = {
        [0]={1,.39,.16, 'Orange — best chance of a skill-up'},
        [1]={1,.80,.19, 'Yellow — likely to grant a skill-up'},
        [2]={.32,.83,.42, 'Green — lower chance of a skill-up'},
        [3]={.62,.62,.62, 'Gray — no skill-up'},
    }
    local function SkillIndicator(recipe)
        if not recipe or not recipe.learned then return end
        local difficulty=tonumber(recipe.relativeDifficulty)
        local c=skillColors[difficulty]
        if not c then return end
        if difficulty==3 or recipe.canSkillUp==false then return nil,c end
        local gained=tonumber(recipe.numSkillUps) or 1
        return math.max(1,math.floor(gained)), c
    end
    local function RecipeHover(button, match)
        if not match or not match.recipe or not GameTooltip then return end
        local recipe=AF:GetRecipeDetails(match.snapshot,match.recipe)
        GameTooltip:SetOwner(button,'ANCHOR_RIGHT')
        local displayed=false
        -- Prefer the actual crafted item, including its variant link if saved;
        -- item tooltips trigger Blizzard's built-in gear comparison support.
        local itemID=tonumber(recipe.outputItemID)
        local itemLink=recipe.outputItemLink
        if (type(itemLink)=='string' and itemLink:find('|Hitem:',1,true)) or itemID then
            local value=itemLink or ('item:'..itemID)
            if type(GameTooltip.SetHyperlink)=='function' then
                displayed=pcall(GameTooltip.SetHyperlink,GameTooltip,value)
            elseif itemID and type(GameTooltip.SetItemByID)=='function' then
                displayed=pcall(GameTooltip.SetItemByID,GameTooltip,itemID)
            end
        end
        if not displayed and type(recipe.recipeLink)=='string' and type(GameTooltip.SetHyperlink)=='function' then
            displayed=pcall(GameTooltip.SetHyperlink,GameTooltip,recipe.recipeLink)
        end
        if not displayed then
            GameTooltip:SetText(recipe.name or ('Recipe '..tostring(recipe.id)),1,.83,.48)
            GameTooltip:AddLine('Crafted item tooltip is not yet available from the client.',.77,.7,.62,true)
        end
        local _,c=SkillIndicator(recipe)
        if c then
            GameTooltip:AddLine(' ',1,1,1)
            GameTooltip:AddLine(c[4]..' (at last profession scan)',c[1],c[2],c[3],true)
        end
        GameTooltip:Show()
        -- Respect the player's normal WoW comparison preference:
        -- automatic when enabled, otherwise hold Shift to compare.
        local modified=type(IsModifiedClick)=='function' and IsModifiedClick('COMPAREITEMS')
        local always=(C_CVar and type(C_CVar.GetCVarBool)=='function' and
            C_CVar.GetCVarBool('alwaysCompareItems')) or
            (type(GetCVarBool)=='function' and GetCVarBool('alwaysCompareItems'))
        if itemID and displayed and (modified or always)
            and type(GameTooltip_ShowCompareItem)=='function' then
            pcall(GameTooltip_ShowCompareItem,GameTooltip)
        end
    end
    local function RecipeHoverLeave()
        if type(GameTooltip_HideShoppingTooltips)=='function' then
            pcall(GameTooltip_HideShoppingTooltips,GameTooltip)
        end
        if GameTooltip then GameTooltip:Hide() end
    end
    local searchLabel = Line(center, 49, "small", 23)
    searchLabel:SetText("Search recipe, reagent, or ID")
    local search = self:Input(center, 280)
    search:SetPoint("TOPLEFT", 16, -82)
    search:SetPoint("TOPRIGHT", -17, -82)
    search:SetHeight(27)
    local countLabel = Line(center, 120, "small", 35)
    countLabel:SetJustifyV("TOP")
    local list = self:List(center, 52)
    UI:InsetWorkshopScrollBar(list)
    list:SetPoint("TOPLEFT", 13, -167)
    list:SetPoint("BOTTOMRIGHT", -30, 88)
    local centerHelp = self:Text(center, "small", P.ink)
    centerHelp:SetPoint("BOTTOMLEFT", 17, 15)
    centerHelp:SetPoint("BOTTOMRIGHT", -17, 15)
    centerHelp:SetHeight(66)
    centerHelp:SetJustifyV("TOP")

    Section(right, "Recipe Details")
    local icon = right:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 16, -57)
    icon:SetSize(42, 42)
    local name = self:Text(right, "title", P.ink)
    name:SetPoint("TOPLEFT", 68, -58)
    name:SetPoint("TOPRIGHT", -14, -58)
    name:SetHeight(45)
    name:SetJustifyV("TOP")
    local details = Line(right, 112, "small", 91)
    details:SetJustifyV("TOP")
    local function fitRecipeDetails()
        if details.GetStringHeight then
            local h=tonumber(details:GetStringHeight()) or 0
            details:SetHeight(math.max(91,math.min(126,h+6)))
        end
    end
    if right.HookScript then right:HookScript("OnSizeChanged",fitRecipeDetails) end
    local requiredHeading = Section(right, "Required Reagents", 210)
    requiredHeading:ClearAllPoints()
    requiredHeading:SetPoint("TOPLEFT",details,"BOTTOMLEFT",0,-8)
    requiredHeading:SetPoint("TOPRIGHT",details,"BOTTOMRIGHT",0,-8)
    local reagents = self:List(right, 43)
    UI:InsetWorkshopScrollBar(reagents)
    reagents:SetPoint("TOPLEFT",requiredHeading,"BOTTOMLEFT",-3,-10)
    reagents:SetPoint("BOTTOMRIGHT", -27, 212)
    local hint = self:Text(right, "small", P.ink)
    hint:SetPoint("BOTTOMLEFT", 17, 159)
    hint:SetPoint("BOTTOMRIGHT", -16, 159)
    hint:SetHeight(44)
    hint:SetJustifyV("TOP")
    local openWorkshop = UI.WorkshopButton(right, "View Crafter in Workshop", function()
        if not UI.recipeSelectedCharacter or not UI.recipeSelectedProfessionName then return end
        UI.workshopSelectedCharacter=UI.recipeSelectedCharacter
        UI.workshopSelectedProfession=UI.recipeSelectedProfessionName
        UI:Switch("Workshop")
    end)
    local craftPlanButton = UI.WorkshopButton(right, "Open Crafting Plan", function()
        local selectedSnapshot=UI.craftSelectedSnapshot
        local selectedRecipe=UI.craftSelectedRecipe
        local selectedOwner=UI.recipeSelectedCharacter
        if selectedSnapshot and selectedRecipe and selectedOwner then
            UI:OpenCraftPlanner(selectedSnapshot,selectedRecipe,selectedOwner,AF.db.settings.recipes.scope)
        end
    end)
    -- Guided goals use the SAME recorded recipe as this page; a library-only
    -- entry can never be treated as learned by this character.
    local guidedDialog=self:NewFrame('Frame',self.frame or UIParent,'AzerothFoundryGuidedGoalDialog')
    guidedDialog:SetFrameStrata('FULLSCREEN_DIALOG')
    guidedDialog:SetSize(435,260)
    guidedDialog:SetPoint('CENTER',self.frame or UIParent,'CENTER')
    self:Background(guidedDialog,P.parchmentLight,true)
    guidedDialog:EnableMouse(true)
    guidedDialog:Hide()
    self.goalGuideDialog=guidedDialog
    if UISpecialFrames then table.insert(UISpecialFrames,'AzerothFoundryGuidedGoalDialog') end
    local guidedHeader=self:SectionTitle(guidedDialog,'New Guided Goal')
    guidedHeader:SetPoint('TOPLEFT',16,-13);guidedHeader:SetPoint('TOPRIGHT',-55,-13)
    local guidedClose=CreateFrame('Button',nil,guidedDialog,'UIPanelCloseButton')
    guidedClose:SetPoint('TOPRIGHT',-8,-7);guidedClose:SetSize(29,29)
    guidedClose:SetScript('OnClick',function() guidedDialog:Hide() end)
    local guidedDescription=self:Text(guidedDialog,'small',P.ink)
    guidedDescription:SetPoint('TOPLEFT',18,-61);guidedDescription:SetPoint('TOPRIGHT',-18,-61)
    guidedDescription:SetHeight(50);guidedDescription:SetJustifyV('TOP')
    local goalMode='craft'
    local modeButton
    modeButton=UI.WorkshopButton(guidedDialog,'Goal: Craft the Item',function()
        goalMode=goalMode=='craft' and 'learn' or 'craft'
        modeButton.label:SetText(goalMode=='craft' and 'Goal: Craft the Item' or 'Goal: Learn the Recipe')
    end)
    modeButton:SetPoint('TOPLEFT',20,-119);modeButton:SetPoint('TOPRIGHT',-20,-119)
    local function CommitGuided(highPriority)
        if not UI.craftSelectedSnapshot or not UI.craftSelectedRecipe or not UI.recipeSelectedCharacter then return end
        local project,reason=AF:CreateGuidedGoal(UI.craftSelectedSnapshot,UI.craftSelectedRecipe,
            UI.recipeSelectedCharacter,goalMode,highPriority,AF.db.settings.recipes.scope)
        if not project then AF.Print(reason or 'Unable to create Guided Goal.');return end
        guidedDialog:Hide()
        UI.selectedProjectId=project.id
        UI:Switch('Goals')
    end
    local ordinaryGoal=UI.WorkshopButton(guidedDialog,'Make Goal',function() CommitGuided(false) end)
    ordinaryGoal:SetPoint('BOTTOMLEFT',18,20);ordinaryGoal:SetSize(183,30)
    local priorityGoal=UI.WorkshopButton(guidedDialog,'Make Top Priority',function() CommitGuided(true) end)
    priorityGoal:SetPoint('BOTTOMRIGHT',-18,20);priorityGoal:SetSize(183,30)
    local makeGuided=UI.WorkshopButton(right,'Make Guided Goal...',function()
        if not UI.craftSelectedRecipe then return end
        goalMode='craft';modeButton.label:SetText('Goal: Craft the Item')
        guidedDescription:SetText('Target: '..(UI.craftSelectedRecipe.name or 'Recipe')..'\nCrafting the item is the default; click the mode to switch to collecting the recipe.')
        guidedDialog:Show();guidedDialog:Raise()
    end)
    -- Queueing is distinct from Guided Goals. Players can add an ordinary
    -- craft to the existing priority queue without entering the Goals journal.
    -- The quantity is a planning request; actual crafting still happens from
    -- the Queue's explicit player-clicked Craft controls.
    local queueDialog=self:NewFrame('Frame',self.frame or UIParent,'AzerothFoundryRecipeQueueDialog')
    queueDialog:SetFrameStrata('FULLSCREEN_DIALOG')
    queueDialog:SetSize(475,238)
    queueDialog:SetPoint('CENTER',self.frame or UIParent,'CENTER')
    self:Background(queueDialog,P.parchmentLight,true)
    queueDialog:EnableMouse(true)
    queueDialog:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames,'AzerothFoundryRecipeQueueDialog') end
    local queueTitle=self:SectionTitle(queueDialog,'Add to Crafting Queue')
    queueTitle:SetPoint('TOPLEFT',16,-13);queueTitle:SetPoint('TOPRIGHT',-55,-13)
    local queueClose=CreateFrame('Button',nil,queueDialog,'UIPanelCloseButton')
    queueClose:SetPoint('TOPRIGHT',-8,-7);queueClose:SetSize(29,29)
    queueClose:SetScript('OnClick',function()queueDialog:Hide()end)
    local queueInfo=self:Text(queueDialog,'small',P.ink)
    queueInfo:SetPoint('TOPLEFT',18,-58);queueInfo:SetPoint('TOPRIGHT',-18,-58)
    queueInfo:SetHeight(45);queueInfo:SetJustifyV('TOP')
    local queueAmountLabel=self:Text(queueDialog,'small',P.ink)
    queueAmountLabel:SetPoint('TOPLEFT',18,-114)
    queueAmountLabel:SetSize(115,24);queueAmountLabel:SetText('Craft attempts')
    local queueAmount=self:Input(queueDialog,80)
    queueAmount:SetPoint('TOPLEFT',145,-113)
    queueAmount:SetSize(83,28)
    queueAmount:SetText('1')
    local function adjustQueueAmount(delta)
        local old=math.floor(tonumber(queueAmount:GetText()) or 1)
        queueAmount:SetText(tostring(math.max(1,math.min(99,old+delta))))
    end
    local queueLess=UI.WorkshopButton(queueDialog,'-',function()adjustQueueAmount(-1)end)
    queueLess:SetPoint('LEFT',queueAmount,'RIGHT',8,0);queueLess:SetSize(47,28)
    local queueMore=UI.WorkshopButton(queueDialog,'+',function()adjustQueueAmount(1)end)
    queueMore:SetPoint('LEFT',queueLess,'RIGHT',7,0);queueMore:SetSize(47,28)
    local function AddSelectedCraftToQueue()
        local snapshot,recipe,owner=UI.craftSelectedSnapshot,UI.craftSelectedRecipe,UI.recipeSelectedCharacter
        local opts=AF.db and AF.db.settings and AF.db.settings.recipes
        if not snapshot or not recipe or not owner or not opts then
            AF.Print('Select a recipe before adding it to the queue.');return
        end
        if recipe.learned~=true then AF.Print('Only learned recipes can be queued.');return end
        local qty=tonumber(queueAmount:GetText())
        if not qty or qty<1 or qty>99 or qty~=math.floor(qty) then
            AF.Print('Enter a whole number of craft attempts from 1 to 99.');return
        end
        local plan,reason=AF:MakeCraftingPlan(snapshot,recipe,owner,opts.scope,qty)
        if not plan then AF.Print(reason or 'Could not plan this craft.');return end
        local project=AF:AddQueuedCraft(plan)
        if not project then AF.Print('Could not add the craft to the queue.');return end
        UI.workshopQueueSelected=project.id
        queueDialog:Hide()
        AF.Print('Added '..qty..'x '..(recipe.name or 'recipe')..' to the Crafting Queue.')
        UI:Switch('Crafting Queue')
    end
    local queueNotice
    local queueMax=UI.WorkshopButton(queueDialog,'Queue Max',function()
        local snapshot,recipe,owner=UI.craftSelectedSnapshot,UI.craftSelectedRecipe,UI.recipeSelectedCharacter
        if type(AF.GetRecipeQueueMaxAttempts)~='function' then return end
        local qty,source=AF:GetRecipeQueueMaxAttempts(snapshot,recipe,owner)
        if type(qty)=='number' and qty>=1 then
            queueAmount:SetText(tostring(qty))
            AddSelectedCraftToQueue()
        elseif qty==0 then
            queueNotice:SetText('Max: 0 craftable right now. Check reagents or the active profession.')
        else
            queueNotice:SetText(tostring(source or 'Max cannot be determined for this recipe.'))
        end
    end)
    queueMax:SetPoint('LEFT',queueMore,'RIGHT',7,0);queueMax:SetSize(92,28)
    queueNotice=self:Text(queueDialog,'small',P.ink)
    queueNotice:SetPoint('TOPLEFT',18,-148);queueNotice:SetPoint('TOPRIGHT',-18,-148)
    queueNotice:SetHeight(33)
    queueNotice:SetText('Quantity 1–99. Queue Max calculates live materials and adds the maximum.')
    local queueCancel=UI.WorkshopButton(queueDialog,'Cancel',function()queueDialog:Hide()end)
    queueCancel:SetPoint('BOTTOMLEFT',18,15);queueCancel:SetSize(145,29)
    local queueConfirm=UI.WorkshopButton(queueDialog,'Add to Queue',AddSelectedCraftToQueue)
    queueConfirm:SetPoint('BOTTOMRIGHT',-18,15);queueConfirm:SetSize(216,29)
    local addToQueue=UI.WorkshopButton(right,'Add to Crafting Queue...',function()
        local recipe=UI.craftSelectedRecipe
        if not recipe or recipe.learned~=true then return end
        local owner=UI.recipeSelectedCharacter
        local display=owner and AF:CharacterLabel(owner) or 'selected crafter'
        queueInfo:SetText((recipe.name or 'Recipe')..'  |  '..display..'\nChoose the number of crafts to plan for this recipe.')
        queueAmount:SetText('1')
        queueNotice:SetText('Quantity 1–99. Queue Max calculates live materials and adds the maximum.')
        queueDialog:Show();queueDialog:Raise()
    end)
    addToQueue:SetPoint('BOTTOMLEFT',14,124)
    addToQueue:SetPoint('BOTTOMRIGHT',-14,124)
    makeGuided:SetPoint('BOTTOMLEFT',14,88)
    makeGuided:SetPoint('BOTTOMRIGHT',-14,88)
    craftPlanButton:SetPoint("BOTTOMLEFT",14,52)
    craftPlanButton:SetPoint("BOTTOMRIGHT",-14,52)
    openWorkshop:SetPoint("BOTTOMLEFT",14,16)
    openWorkshop:SetPoint("BOTTOMRIGHT",-14,16)
    page:HookScript('OnHide',function()
        queueDialog:Hide()
        guidedDialog:Hide()
    end)

    local function SelectRecipe(entry)
        UI.recipeSelectedID = entry.recipe.id
        UI.recipeSelectedCharacter = entry.character.key
        UI.recipeSelectedProfession = entry.snapshot.professionID
        page:Refresh()
    end

    search:SetScript("OnTextChanged", function(_, userInput)
        if userInput then UI.recipeSelectedID=nil; page:Refresh() end
    end)

    local filterTitle=left:CreateTexture(nil,'BORDER')
    filterTitle:SetPoint('TOPLEFT',left,'TOPLEFT',12,-77)
    filterTitle:SetPoint('TOPRIGHT',left,'TOPRIGHT',-12,-77)
    filterTitle:SetHeight(1)
    filterTitle:SetColorTexture(.52,.35,.17,.55)
    local function refreshFilterPlacement()
        if not filtersExpanded then closeCharacterMenu() end
        filterToggle.label:SetText(filtersExpanded and 'Hide Filters  -' or 'Show Filters  +')
        for _,button in ipairs({learnedButton,unlearnedButton,allButton,expeditionButton,charButton}) do button:SetShown(filtersExpanded) end
        sideHint:SetShown(filtersExpanded)
        filterTitle:SetShown(filtersExpanded)
        local top=filtersExpanded and -286 or -98
        local headingY=filtersExpanded and -245 or -62
        local heading=filterProfessionHeading
        if heading then
            heading:ClearAllPoints()
            heading:SetPoint('TOPLEFT',left,'TOPLEFT',14,headingY)
            heading:SetPoint('TOPRIGHT',left,'TOPRIGHT',-12,headingY)
        end
        professions:ClearAllPoints()
        professions:SetPoint('TOPLEFT',left,'TOPLEFT',12,top)
        professions:SetPoint('BOTTOMRIGHT',left,'BOTTOMRIGHT',-22,88)
    end
    function page:Refresh()
        closeCharacterMenu()
        if not AF.db or not AF.db.settings.recipes then return end
        refreshFilterPlacement()
        local opts=AF.db.settings.recipes
        UI.WorkshopSetSelected(learnedButton, opts.status=='learned')
        UI.WorkshopSetSelected(unlearnedButton, opts.status=='unlearned')
        UI.WorkshopSetSelected(allButton, opts.scope=='all')
        UI.WorkshopSetSelected(expeditionButton, opts.scope=='expedition')
        local char=UI.recipeCharacterFilter and AF.db.characters[UI.recipeCharacterFilter]
        if char and not AF:WorkshopCharacterAllowed(char.key,opts.scope) then
            UI.recipeCharacterFilter=nil; char=nil
        end
        charButton.label:SetText(char and ('Crafter: '..(char.name or 'Unknown')) or 'All Characters')
        local profs=AF:GetRecipeProfessions(opts.scope,char and char.key or nil)
        local profEntries={{key=0,label='All Scanned Professions'}}
        for _,prof in ipairs(profs) do profEntries[#profEntries+1]={key=prof.id,label=prof.name,icon=prof.icon} end
        local hasSelected=false
        for _,prof in ipairs(profEntries) do if UI.recipeProfessionFilter==prof.key then hasSelected=true end end
        if not hasSelected then UI.recipeProfessionFilter=0 end
        UI:FillList(professions,profEntries,function(entry)
            UI.recipeProfessionFilter=entry.key
            UI.recipeSelectedID=nil
            page:Refresh()
        end, UI.recipeProfessionFilter)
        local matches=AF:RecipeSnapshotsForScope(opts.scope,
            UI.recipeProfessionFilter~=0 and UI.recipeProfessionFilter or nil,
            UI.recipeCharacterFilter, opts.status, search:GetText())
        local entries={}
        for _,item in ipairs(matches) do
            local suffix=''
            if item.recipe.learned then
                local ready=AF:GetRecipeReadiness(item.snapshot,item.recipe,item.character.key,opts.scope,1)
                if ready.kind=='bags' then suffix='  |cff25874b[In bags]|r'
                elseif ready.kind=='recorded' then suffix='  |cff866224[Recorded mats]|r'
                elseif ready.kind=='missing' then suffix='  |cff8d5c27[Needs materials]|r'
                else suffix='  |cff665c4c[Not checked]|r' end
            end
            entries[#entries+1]={key=item.character.key..':'..item.recipe.id,
                label=item.recipe.name..suffix..'\n'..item.character.name..'  •  '..item.snapshot.professionName,
                icon=item.recipe.icon, item=item}
        end
        local selectedKey = UI.recipeSelectedID and UI.recipeSelectedCharacter
            and (UI.recipeSelectedCharacter..':'..UI.recipeSelectedID) or nil
        UI:FillList(list,entries,function(entry) SelectRecipe(entry.item) end,selectedKey)
        -- List rows are recycled by FillList: reset/replace scripts and arrows
        -- every refresh so tooltips never refer to an old recipe after filters.
        for i,entry in ipairs(entries) do
            local button=list.rows[i]
            if button then
                local indicator,color=SkillIndicator(entry.item.recipe)
                if not button.afRecipeSkillArrow then
                    -- Make a small arrow out of 3 native color textures.
                    -- The Forever font renders the Unicode up-arrow as a box.
                    local arrow=CreateFrame('Frame',nil,button)
                    arrow:SetSize(22,22)
                    arrow:SetPoint('RIGHT',button,'RIGHT',-7,0)
                    local function stroke(w,h,x,y,rotation)
                        local texture=arrow:CreateTexture(nil,'OVERLAY')
                        texture:SetColorTexture(1,1,1,1)
                        texture:SetSize(w,h)
                        texture:SetPoint('CENTER',arrow,'CENTER',x,y)
                        if rotation then texture:SetRotation(rotation) end
                        return texture
                    end
                    arrow.parts={
                        stroke(3,13,0,-2),
                        stroke(3,10,-4,5,-math.pi/4),
                        stroke(3,10,4,5,math.pi/4),
                    }
                    local amount=arrow:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
                    amount:SetPoint('RIGHT',arrow,'LEFT',0,0)
                    amount:SetTextColor(1,1,1)
                    arrow.amount=amount
                    button.afRecipeSkillArrow=arrow
                end
                local arrow=button.afRecipeSkillArrow
                if indicator then
                    for _,part in ipairs(arrow.parts) do
                        part:SetColorTexture(color[1],color[2],color[3],1)
                    end
                    arrow.amount:SetText(indicator>1 and tostring(indicator) or '')
                    arrow:Show()
                    button.label:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',-40,1)
                else
                    arrow:Hide()
                    button.label:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',-7,1)
                end
                local match=entry.item
                button:SetScript('OnEnter',function(self) RecipeHover(self,match) end)
                button:SetScript('OnLeave',RecipeHoverLeave)
            end
        end
        local selected
        for _,item in ipairs(matches) do
            if item.recipe.id==UI.recipeSelectedID and item.character.key==UI.recipeSelectedCharacter then
                selected=item; break
            end
        end
        if not selected then selected=matches[1] end
        if selected then
            UI.recipeSelectedID=selected.recipe.id
            UI.recipeSelectedCharacter=selected.character.key
            UI.recipeSelectedProfession=selected.snapshot.professionID
            UI.recipeSelectedProfessionName=selected.snapshot.professionName
            UI.craftSelectedSnapshot=selected.snapshot
            UI.craftSelectedRecipe=selected.recipe
            craftPlanButton:SetShown(selected.recipe.learned==true)
            addToQueue:SetShown(selected.recipe.learned==true)
            makeGuided:Show()
            local row=AF:GetRecipeDetails(selected.snapshot,selected.recipe)
            local outputItem = row.outputItemID and AF:GetItemPresentation(row.outputItemID)
            local title = row.name or ('Recipe '..row.id)
            if outputItem and not outputItem.pending then
                title = '|c'..(outputItem.color or 'ffffffff')..title..'|r'
            end
            name:SetText(title)
            icon:SetTexture((outputItem and outputItem.icon) or row.icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
            local requirement = row.requiredSkill and tostring(row.requiredSkill) or 'Not documented'
            if row.requiredSkillBorrowed then requirement = requirement..' (unconfirmed for Forever)' end
            local outputLine = 'Output: '..(outputItem and AF:ItemColoredName(outputItem) or 'Not specified')
            local levelLine = ''
            if outputItem and not outputItem.pending then
                if type(outputItem.itemLevel)=='number' and outputItem.itemLevel > 0 then
                    levelLine = levelLine..'Item level: '..outputItem.itemLevel..'  '
                end
                if type(outputItem.minLevel)=='number' and outputItem.minLevel > 0 then
                    levelLine = levelLine..'Equip level: '..outputItem.minLevel
                end
            end
            local lines = {
                (row.learned and 'LEARNED' or 'UNLEARNED')..' • '..selected.character.name,
                selected.snapshot.professionName..' | Spell ID '..row.id,
                'Profession skill: '..requirement,
                outputLine,
            }
            if levelLine ~= '' then lines[#lines+1]=levelLine end
            local difficulty=skillColors[tonumber(row.relativeDifficulty)]
            if difficulty then
                lines[#lines+1]='Skill-up: '..difficulty[4]..' (last scanned)'
            end
            lines[#lines+1] = 'Scanned: '..TimeLabel(selected.snapshot.scanned)
            if selected.recipe.learned then
                local ready=AF:GetRecipeReadiness(selected.snapshot,selected.recipe,selected.character.key,opts.scope,1)
                lines[#lines+1]='Materials: '..(ready.label or 'Not verified')
            end
            details:SetText(table.concat(lines,'\n'))
            fitRecipeDetails()
            local ingredients={}
            for i,r in ipairs(row.reagents or {}) do
                local item = AF:GetItemPresentation(r.itemID)
                local display = item and AF:ItemColoredName(item) or ('Item #'..r.itemID)
                local estimate=AF:GetInventoryEstimate(r.itemID, opts.scope,selected.character.key)
                local need=tonumber(r.quantity) or 1
                local have
                if estimate.anyScanned then
                    local count=estimate.total
                    local tag=count>=need and '|cff22824b[recorded enough]|r' or '|cff8d5c27[need '..(need-count)..']|r'
                    have='  •  recorded '..count..'  '..tag
                else
                    have='  •  inventory unscanned'
                end
                ingredients[#ingredients+1]={key=i, itemID=r.itemID,
                    icon=item and item.icon, label=display..'  ×'..tostring(r.quantity or 1)..have}
            end
            UI:FillList(reagents, ingredients, function() end, nil)
            for i,entry in ipairs(ingredients) do
                local button = reagents.rows[i]
                if button then
                    button:SetScript('OnEnter', function(self)
                        if GameTooltip and GameTooltip.SetOwner and GameTooltip.SetHyperlink then
                            GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                            local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, 'item:'..entry.itemID)
                            if ok then GameTooltip:Show() else GameTooltip:Hide() end
                        end
                    end)
                    button:SetScript('OnLeave', function()
                        if GameTooltip then GameTooltip:Hide() end
                    end)
                end
            end
            if #ingredients==0 then
                hint:SetText('No reagent details available for this entry.\nOpen the profession window again to refresh this record.')
            else
                hint:SetText('Recorded counts are last-seen bag/bank snapshots. Green statuses indicate quantities, not transfer or crafting readiness.')
            end
            openWorkshop:Show()
        else
            UI.recipeSelectedID=nil
            UI.recipeSelectedCharacter=nil
            UI.craftSelectedSnapshot=nil
            UI.craftSelectedRecipe=nil
            craftPlanButton:Hide()
            addToQueue:Hide()
            makeGuided:Hide()
            name:SetText('No recipes found')
            icon:SetTexture('Interface\\Icons\\INV_Misc_Book_09')
            details:SetText('Open a crafting profession to capture learned and visible unlearned recipes.\nPrevious scans stay available across alts.')
            fitRecipeDetails()
            UI:FillList(reagents,{},function() end,nil)
            hint:SetText('If a profession is open but no recipes appear, click Scan Open Profession and check the chat message.')
            openWorkshop:Hide()
        end
        countLabel:SetText(#matches..' recipe entries • '..(opts.status=='learned' and 'learned' or 'unlearned')..
            '\n'..(AF.recipeScanMessage or 'Scans occur when profession windows open.'))
        sideHint:SetText('Shows observed recipes only. A complete undiscovered catalog is intentionally hidden.')
        local status = AF.Compatibility and AF.Compatibility.GetDependency('ProfessionDB')
        libState:SetText('ProfessionDB: '..(status and status.label or 'optional; not detected'))
        centerHelp:SetText('Unlearned means observed in a profession window, not every recipe available in the world.')
    end
end

function UI:BuildPlanned(page, section)
    local left, center, right = CreateColumns(page, 241, 249)
    Section(left, "Journal Sections")
    local linkNames = { "Overview", "Characters", "Living Workshop", "Goals", "Notes" }
    for i, name in ipairs(linkNames) do
        local b = self:Button(left, name, function() self:Switch(name) end)
        b:SetPoint("TOPLEFT", 13, -54 - (i-1)*43)
        b:SetPoint("TOPRIGHT", -13, -54 - (i-1)*43)
    end
    Section(center, section)
    local text = Line(center, 65, nil, 170)
    text:SetJustifyV("TOP")
    text:SetText(section .. " is planned for a later release.\n\nThe journal foundation focuses on the journal foundation, cross-character data, notes, profession snapshots, and projects. This tab reserves its future home in the journal.")
    Section(right, "Available Now")
    local available = Line(right, 67, "small", 180)
    available:SetJustifyV("TOP")
    available:SetText("Character roster\nProfession levels\nPersonal projects and checklists\nAccount-wide notes\nPersistence between sessions")
    function page:Refresh() end
end

-- The Goals filter formerly lived in a top tab strip. Its controls now live
-- in the shared sidebar; this function still builds the original goal system.
function UI:BuildGoals(page)
    self:BuildProjects(page)
    function page:Select(name)
        if name~="Active" and name~="Tracked" and name~="Completed" then name="Active" end
        AF.db.settings.guided.goalsView=name
        self:Refresh()
        UI:RefreshNavigation()
    end
    page:Select(AF.db.settings.guided.goalsView or "Active")
end

function UI:BuildPage(name, page)
    if name == "Overview" then
        if AF.db and AF.db.settings and AF.db.settings.legacyOverview then
            self:BuildOverview(page)
        elseif self.BuildModularOverview then
            self:BuildModularOverview(page)
        else
            self:BuildOverview(page)
        end
    elseif name == "Characters" then self:BuildCharacters(page)
    elseif name == "Living Workshop" then self:BuildLivingWorkshop(page)
    elseif name == "Goals" then self:BuildGoals(page)
    elseif name == "Notes" then self:BuildNotes(page)
    elseif name == "Exploration" then self:BuildAtlas(page)
    elseif name == "Collections" then self:BuildCollections(page)
    elseif name == "Settings" then self:BuildSettings(page)
    elseif name == "Self-Found" and self.BuildSelfFoundCharter then self:BuildSelfFoundCharter(page)
    else self:BuildPlanned(page, name) end
end

function UI:ConfirmDelete(kind, id, callback)
    if not StaticPopupDialogs or not StaticPopup_Show then
        AF.Print("Delete confirmation window unavailable; no changes were made.")
        return
    end
    if not StaticPopupDialogs.AZEROTHFOUNDRY_CONFIRM_DELETE then
        StaticPopupDialogs.AZEROTHFOUNDRY_CONFIRM_DELETE = {
            text = "Delete this journal entry permanently?",
            button1 = YES,
            button2 = NO,
            OnAccept = function(_, data)
                if not data then return end
                local collection = data.kind == "note" and AF.db.notes or AF.db.projects
                AF:DeleteRecord(collection, data.id)
                if data.callback then data.callback() end
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = 3,
        }
    end
    StaticPopup_Show("AZEROTHFOUNDRY_CONFIRM_DELETE", nil, nil,
        {kind=kind, id=id, callback=callback})
end
