-- Azeroth Foundry modular Overview integration preview (validated AF Layout Lab v0.1.2).
-- Responsive resize + one-click Fit Layout patch: automatic scaling is reversible
-- because canonical relative geometry is kept separate from rendered bounds.
-- Layout settings ONLY are stored at AF.db.settings.overviewLayout.
-- Core systems, Forever compatibility paths, and the old Overview renderer stay intact.
-- No dependency on the separate AF_OverviewLab addon.
local _, AF = ...
local UI = AF.UI
local min, max, floor, abs = math.min, math.max, math.floor, math.abs
local unpack = unpack or table.unpack

local PALETTE = {
    background = {0.070, 0.065, 0.060, 0.97},
    panel = {0.105, 0.094, 0.077, 0.91},
    leaf = {0.092, 0.082, 0.069, 0.99},
    gold = {0.85, 0.64, 0.32, 1},
    light = {0.97, 0.87, 0.70, 1},
    subdued = {0.77, 0.73, 0.65, 1},
    button = {0.20, 0.17, 0.13, 1},
    active = {0.25, 0.39, 0.33, 1},
    gap = {0.15, 0.12, 0.09, 1},
}

local WIDGETS = {
    character = {title="Current Character", section="Characters", description="Character identity and professions"},
    alts = {title="Character Roster", section="Characters", description="Registered adventurers and alts"},
    account = {title="Account Summary", section="Characters", description="Account-wide progress snapshot"},
    goals = {title="Pinned Goals", section="Progress", description="Important ongoing goals"},
    workshop = {title="Living Workshop", section="Progress", description="Planned crafts and material readiness"},
    exploration = {title="Exploration", section="Progress", description="Zone and discoveries summary"},
    collections = {title="Collections", section="Progress", description="Discovered collectibles only"},
    notes = {title="Journal Notes", section="Personal", description="Recent notes"},
    selffound = {title="Self-Found", section="Personal", description="Expedition membership status"},
}
local ORDER = {"character","alts","account","goals","workshop","exploration","collections","notes","selffound"}
local VALID_EDGE = {LEFT=true, RIGHT=true, TOP=true, BOTTOM=true}
local MIN_LEAF_W, MIN_LEAF_H = 160, 96
local MIN_GROUP_W, MIN_GROUP_H = 210, 155
local SPLIT_GAP = 8
local SNAP_DISTANCE = 58
local SNAP_OVERLAP = 58
local LabFrame, Canvas, LibraryPanel, Picker, EditButton, FitButton, ResetButton, SnapButton, Status, SnapPreview, SnapLabel, PresetPanel
local editing = false
local snapEnabled = true -- preference only: manual edge + docking still works
local groups = {}
local views = {}
local nextId = 1
local selectedDock
local RenderAll, LayoutGroup, Store, RemoveWidget, UndockWidget, TryDock, ShowSnapCandidate
local RefreshBodies
local WidgetPulse -- declared before display truncation uses it
local displayCache = {}
local pulseCache = {}
-- Art Lab compatibility: expose stable semantic texture targets, independent of
-- the number, size, location, or docking state of Overview widgets.  This is a
-- soft interface: AF_ForeverArtLab is NEVER required, loaded, or modified here.
-- Art Lab versions that understand the registry can discover widget backgrounds
-- under Pages.Overview.Widget.<id>.Background and .Header.Background.
-- Older Overview aliases remain available when their corresponding widgets exist.
local artTargets = {}
local artTransfer = {}
local LEGACY_OVERVIEW_TARGETS = {
    ["Pages.Overview.Left.Background"] = "account",
    ["Pages.Overview.Center.Background"] = "goals",
    ["Pages.Overview.Right.Background"] = "notes",
}
local function RegisterArtTarget(key, region)
    if not key or not region then return end
    region.afArtLabSlot = key
    artTargets[key] = region
end
local function TextureSnapshot(region)
    if not region then return nil end
    local t = {}
    if region.GetAtlas then
        local ok, v = pcall(region.GetAtlas, region)
        if ok and type(v)=="string" and v~="" then t.atlas=v end
    end
    if not t.atlas and region.GetTexture then
        local ok, v = pcall(region.GetTexture, region)
        if ok and (type(v)=="string" or type(v)=="number") then t.texture=v end
    end
    if not t.texture and not t.atlas and region.GetColorTexture then
        local ok,r,g,b,a = pcall(region.GetColorTexture,region)
        if ok and type(r)=="number" and type(g)=="number" and type(b)=="number" then
            t.color = {r,g,b,type(a)=="number" and a or 1}
        end
    end
    if region.GetTexCoord then
        local ok,a,b,c,d = pcall(region.GetTexCoord,region)
        if ok and type(a)=="number" and type(b)=="number" and type(c)=="number" and type(d)=="number" then
            t.coords={a,b,c,d}
        end
    end
    if region.GetVertexColor then
        local ok,r,g,b,a = pcall(region.GetVertexColor,region)
        if ok and type(r)=="number" then t.vertex={r,g,b,a or 1} end
    end
    if region.GetAlpha then
        local ok,alpha=pcall(region.GetAlpha,region)
        if ok and type(alpha)=="number" then t.alpha=alpha end
    end
    return t
end
local function RestoreTexture(region,style)
    if not region or not style then return end
    if style.atlas and region.SetAtlas then
        -- Local Forever catalog entries may be path-backed, not native atlases.
        local ok=pcall(region.SetAtlas,region,style.atlas)
        if not ok and style.texture then pcall(region.SetTexture,region,style.texture) end
    elseif style.texture and region.SetTexture then
        -- Art Lab's SetTexture may retain a previously reported color backing;
        -- recover the explicit image first when rebuilding a docked widget.
        region:SetTexture(style.texture)
    elseif style.color and region.SetColorTexture then
        region:SetColorTexture(unpack(style.color))
    end
    if style.coords and region.SetTexCoord then region:SetTexCoord(unpack(style.coords)) end
    if style.vertex and region.SetVertexColor then region:SetVertexColor(unpack(style.vertex)) end
    if style.alpha and region.SetAlpha then region:SetAlpha(style.alpha) end
end
local function PublishArtTargets()
    -- External add-ons can use either the visible journal frame or the UI table.
    -- Both references resolve to the SAME live registry; never store these
    -- userdata references in SavedVariables.
    UI.afOverviewArtTargets = artTargets
    UI.GetOverviewArtTarget = function(_,key) return artTargets[key] end
    local journal=UI.frame
    if journal then
        journal.afOverviewArtTargets=artTargets
        journal.GetOverviewArtTarget=function(_,key) return artTargets[key] end
    end
end
local function SameTextureSnapshot(a,b)
    if not a or not b then return false end
    for _,field in ipairs({"atlas","texture","alpha","color","coords","vertex"}) do
        local av,bv=a[field],b[field]
        if type(av)~=type(bv) then return false end
        if type(av)=="table" then
            for i=1,4 do
                if type(av[i])=="number" and type(bv[i])=="number" then
                    if math.abs(av[i]-bv[i])>0.002 then return false end
                elseif av[i]~=bv[i] then return false end
            end
        elseif av~=bv then return false end
    end
    return true
end
local function ReplaceArtTargets()
    for key,region in pairs(artTargets) do
        if key:find("^Pages%.Overview%.Widget%.") then
            -- A theme's own solid-color paint is NOT an Art Lab override.
            -- Only carry a genuinely modified texture across docking rebuilds.
            local style=TextureSnapshot(region)
            if region.afOverviewThemeSnapshot and SameTextureSnapshot(style,region.afOverviewThemeSnapshot) then
                artTransfer[key]=nil
            elseif style then
                artTransfer[key]=style
            end
            artTargets[key]=nil
        end
    end
    for alias in pairs(LEGACY_OVERVIEW_TARGETS) do artTargets[alias]=nil end
end
local function FinalizeArtTargets()
    for alias,widgetId in pairs(LEGACY_OVERVIEW_TARGETS) do
        local key="Pages.Overview.Widget."..widgetId..".Background"
        if artTargets[key] then artTargets[alias]=artTargets[key] end
    end
    PublishArtTargets()
end
local function Settings()
    if not AF.db or not AF.db.settings then return nil end
    local s = AF.db.settings
    s.overviewLayout = type(s.overviewLayout)=='table' and s.overviewLayout or {}
    return s.overviewLayout
end

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end
local function Say(message)
    if Status then Status:SetText(message) end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffddb76eAF Overview:|r " .. message)
    end
end
local function Clamp(x, low, high)
    if high < low then return low end
    return max(low, min(high, x))
end
local function Paint(parent, layer, color)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints(parent)
    if texture.SetColorTexture then texture:SetColorTexture(unpack(color))
    else texture:SetTexture("Interface\\Buttons\\WHITE8X8"); texture:SetVertexColor(unpack(color)) end
    return texture
end
-- The full Overview uses the same semantic surface/ink pairing as the rest
-- of Foundry. Light Mode and Custom themes borrowing Light backgrounds use
-- light cards with dark text; other themes retain rich dark data panels.
local function OverviewCardStyle(t)
    local card=t.light and t.paper or t.dataSurface
    local ink=t.light and t.ink or t.dataText
    local title=t.raised
    local titleInk=t.light and t.ink or t.dataText
    if UI.ThemeReadableText then
        ink=UI:ThemeReadableText(card,ink)
        titleInk=UI:ThemeReadableText(title,titleInk)
    end
    return card,ink,title,titleInk
end
local function ThemeLabelFor(surface,preferred)
    return UI.ThemeReadableText and UI:ThemeReadableText(surface,preferred) or preferred
end
local function Label(parent, text, size, color, anchor)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local font = (GameFontNormal and select(1, GameFontNormal:GetFont())) or "Fonts\\FRIZQT__.TTF"
    fs:SetFont(font, size or 12, "")
    fs:SetTextColor(unpack(color or PALETTE.light))
    fs:SetJustifyH(anchor or "LEFT")
    fs:SetText(text or "")
    return fs
end
local function Button(parent, title, w, h, handler, size)
    local b
    if w >= 34 and UI.Button then
        -- The shared Foundry button already uses precisely cropped Blizzard
        -- UI-Panel-Button textures; this replaces the old flat rectangles.
        b=UI:Button(parent,title,handler)
        b:SetSize(w,h)
        if b.label and b.label.GetFont and b.label.SetFont then
            local face=select(1,b.label:GetFont())
            if face then b.label:SetFont(face,size or 12,"") end
        end
    else
        b=CreateFrame("Button",nil,parent)
        b:SetSize(w,h)
        b.afOverviewMiniFill=Paint(b,"BACKGROUND",PALETTE.button)
        local t=Label(b,title,size or 12,PALETTE.light,"CENTER")
        t:SetPoint("CENTER",b,"CENTER")
        t:SetWidth(max(5,w-6))
        b.label=t
        b:SetScript("OnClick",handler)
    end
    if not b.afStyle then
        -- Tiny undock/lock/hide controls use ONE surface/foreground pair for
        -- both normal and hover states, including bright custom palettes.
        local function update(hover)
            local t=UI.ThemeTokens and UI:ThemeTokens()
            if not t then return end
            local c=hover and t.hover or t.buttonFace
            if b.afOverviewMiniFill then
                b.afOverviewMiniFill:SetColorTexture(c[1],c[2],c[3],.99)
            end
            b.label:SetTextColor(unpack(ThemeLabelFor(c,t.buttonText)))
        end
        if UI.RegisterThemeTarget then UI:RegisterThemeTarget(b,function()update(b.afOverviewMiniHover)end) end
        b:SetScript("OnEnter",function()b.afOverviewMiniHover=true;update(true)end)
        b:SetScript("OnLeave",function()b.afOverviewMiniHover=false;update(false)end)
    end
    return b
end
local function NewLeaf(id) return {widget=id} end
local function Split(axis, ratio, a, b)
    return {axis=axis, ratio=ratio, a=a, b=b}
end
local function DefaultGroups()
    return {
        {id=1, x=12, y=12, w=860, h=340, locked=false,
         tree=Split("H", 0.61,
             Split("V",0.27,NewLeaf("character"), Split("V",0.63,NewLeaf("goals"),NewLeaf("workshop"))),
             Split("V",0.51,NewLeaf("account"),NewLeaf("notes")))},
    }
end
-- Curated starting arrangements; these are the existing nine widget IDs and
-- existing docking trees, not a parallel layout or a new SavedVariables schema.
-- A choice is committed only after the player's explicit confirmation.
local LAYOUT_PRESETS = {
    {id="classic", label="Classic Dashboard", detail="Character, goals, workshop, account and notes", tree=function()
        return DefaultGroups()[1].tree
    end},
    {id="compact", label="Compact", detail="Character, tracked goals, and crafting", tree=function()
        return Split("H",.39,NewLeaf("character"),Split("V",.49,NewLeaf("goals"),NewLeaf("workshop")))
    end},
    {id="completionist", label="Completionist", detail="Exploration, collections, goals, feats and progress", tree=function()
        return Split("H",.55,
            Split("V",.52,Split("H",.50,NewLeaf("exploration"),NewLeaf("collections")),
                Split("H",.50,NewLeaf("goals"),NewLeaf("selffound"))),
            Split("V",.49,Split("H",.50,NewLeaf("character"),NewLeaf("account")),NewLeaf("workshop")))
    end},
    {id="expanded", label="Expanded Dashboard", detail="Every one of the nine existing widgets", tree=function()
        return Split("H",.31,Split("V",.50,NewLeaf("character"),NewLeaf("alts")),
            Split("H",.51,Split("V",.33,NewLeaf("account"),Split("V",.50,NewLeaf("goals"),NewLeaf("workshop"))),
                Split("V",.32,NewLeaf("exploration"),Split("V",.34,NewLeaf("collections"),
                    Split("V",.50,NewLeaf("notes"),NewLeaf("selffound"))))))
    end},
    {id="blank", label="Blank Canvas", detail="Hide all widgets; add them back with Widgets +", tree=function() return nil end},
}
local function CopyTree(node)
    if node.widget then return {widget=node.widget} end
    return Split(node.axis, node.ratio, CopyTree(node.a), CopyTree(node.b))
end
local function SanitizeTree(t, depth, used)
    if type(t) ~= "table" or depth > 9 then return nil end
    if type(t.widget)=="string" and WIDGETS[t.widget] and not used[t.widget] then
        used[t.widget]=true
        return NewLeaf(t.widget)
    end
    if t.axis ~= "H" and t.axis ~= "V" then return nil end
    local a=SanitizeTree(t.a, depth+1, used)
    local b=SanitizeTree(t.b, depth+1, used)
    if not a then return b end
    if not b then return a end
    local ratio=type(t.ratio)=="number" and t.ratio or 0.5
    return Split(t.axis, Clamp(ratio,0.13,0.87),a,b)
end
local function SanitizeGroups(raw)
    local restored, used = {}, {}
    if type(raw) ~= "table" then return nil end
    for i=1,min(#raw,16) do
        local g=raw[i]
        if type(g)=="table" then
            local tree=SanitizeTree(g.tree,0,used)
            if tree then
                restored[#restored+1]={
                    id=nextId, x=Clamp(tonumber(g.x) or 20,0,2500),
                    y=Clamp(tonumber(g.y) or 20,0,2500),
                    w=Clamp(tonumber(g.w) or 350,MIN_GROUP_W,2500),
                    h=Clamp(tonumber(g.h) or 240,MIN_GROUP_H,2500),
                    locked=g.locked==true, tree=tree,
                    -- Optional v2 relative geometry. Old v1 layouts still load.
                    _norm=(type(g.norm) == "table" and
                        type(g.norm.x) == "number" and type(g.norm.y) == "number" and
                        type(g.norm.w) == "number" and type(g.norm.h) == "number") and
                        {x=Clamp(g.norm.x,0,1),y=Clamp(g.norm.y,0,1),
                         w=Clamp(g.norm.w,0.001,4),h=Clamp(g.norm.h,0.001,4)} or nil}
                nextId=nextId+1
            end
        end
    end
    -- Explicitly hiding every widget should stay hidden after /reload.
    -- Invalid/nonempty saved configurations still recover the default.
    if #restored == 0 then return (#raw==0) and {} or nil end
    return restored
end
local function SerializedTree(n)
    if n.widget then return {widget=n.widget} end
    return {axis=n.axis, ratio=n.ratio, a=SerializedTree(n.a), b=SerializedTree(n.b)}
end
-- Relative geometry is the canonical copy of the layout. A Canvas resize
-- projects these values onto the new window but must NOT rewrite them: doing so
-- would permanently lose the prior arrangement after a shrink/clamp cycle.
local function RememberGeometry(g, canvasW, canvasH)
    if not canvasW or not canvasH or canvasW < 100 or canvasH < 100 then return end
    g._norm={x=g.x/canvasW,y=g.y/canvasH,w=g.w/canvasW,h=g.h/canvasH}
end
local function RememberAllGeometry()
    if not Canvas then return end
    local w,h=Canvas:GetSize()
    for _,g in ipairs(groups) do RememberGeometry(g,w,h) end
end
Store = function(geometryChanged)
    local settings=Settings()
    if not settings then return end
    -- Only explicit user changes (move, drag resize, add/dock, reset, Fit)
    -- update the canonical positions. Snap toggle, splitter drags, page hide,
    -- and automatic window resizing preserve the saved relative rectangle.
    if geometryChanged then RememberAllGeometry() end
    local out={}
    local W,H
    if Canvas then W,H=Canvas:GetSize() end
    for _,g in ipairs(groups) do
        if not g._norm then RememberGeometry(g,W,H) end
        local n=g._norm
        out[#out+1]={id=g.id,x=g.x,y=g.y,w=g.w,h=g.h,locked=g.locked,
            norm=n and {x=n.x,y=n.y,w=n.w,h=n.h} or nil,
            tree=SerializedTree(g.tree)}
    end
    settings.schema=2 -- backwards-compatible extension: original tree/geometry kept
    settings.snapEnabled=snapEnabled
    settings.groups=out
end
local function FindGroup(id)
    for _,g in ipairs(groups) do if g.id==id then return g end end
end
local function FindWidget(widget)
    local function Visit(n)
        if n.widget==widget then return true end
        if not n.widget then return Visit(n.a) or Visit(n.b) end
        return false
    end
    for _,g in ipairs(groups) do if Visit(g.tree) then return g end end
end
local function CountLeaves(n)
    if n.widget then return 1 end
    return CountLeaves(n.a)+CountLeaves(n.b)
end
local function FindNode(n, widget)
    if n.widget==widget then return n end
    if not n.widget then return FindNode(n.a,widget) or FindNode(n.b,widget) end
end
local function ReplaceNode(n, widget, value)
    if n.widget==widget then return value, true end
    if n.widget then return n,false end
    local newA,found=ReplaceNode(n.a,widget,value)
    if found then n.a=newA; return n,true end
    local newB,foundB=ReplaceNode(n.b,widget,value)
    if foundB then n.b=newB end
    return n,foundB
end
local function PruneNode(n, widget)
    if n.widget then
        if n.widget==widget then return nil,true end
        return n,false
    end
    local a,ok=PruneNode(n.a,widget)
    if ok then if not a then return n.b,true end; n.a=a;return n,true end
    local b,okB=PruneNode(n.b,widget)
    if okB then if not b then return n.a,true end; n.b=b end
    return n,okB
end
local function RequiredSize(n)
    if n.widget then return MIN_LEAF_W, MIN_LEAF_H end
    local aw,ah=RequiredSize(n.a)
    local bw,bh=RequiredSize(n.b)
    if n.axis=="H" then return aw+bw+SPLIT_GAP, max(ah,bh) end
    return max(aw,bw), ah+bh+SPLIT_GAP
end
-- Edge buttons no longer disappear just because the current leaf is small.
-- A successful dock can grow/reflow the *whole* group to accommodate the split.

local function OverviewPresetGroups(id,w,h)
    for _,preset in ipairs(LAYOUT_PRESETS) do
        if preset.id==id then
            local tree=preset.tree()
            if not tree then return {},preset end
            local neededW,neededH=RequiredSize(tree)
            -- Refuse, rather than squeeze, any layout whose widget minimums
            -- don't fit the current canvas. Existing SavedVariables stay safe.
            if w<neededW+24 or h<neededH+24 then return nil,preset,"This preset needs a larger Overview window." end
            return {{id=1,x=12,y=12,w=w-24,h=h-24,locked=false,tree=tree}},preset
        end
    end
    return nil,nil,"Unknown layout preset"
end
local function CanAddSplit(region, edge)
    return region and VALID_EDGE[edge] == true
end
local function ProposedTree(target, widget, edge, addition)
    local newTree=CopyTree(target.tree)
    local old=NewLeaf(widget)
    local added=NewLeaf(addition)
    local before=(edge=="LEFT" or edge=="TOP")
    local axis=(edge=="LEFT" or edge=="RIGHT") and "H" or "V"
    local split=Split(axis,0.5,before and added or old,before and old or added)
    newTree=select(1,ReplaceNode(newTree,widget,split))
    return newTree
end
local function CanFitDock(target, targetWidget, edge, addition)
    if not target or target.locked or not VALID_EDGE[edge] or not FindNode(target.tree,targetWidget) then return nil end
    if not Canvas then return nil end
    local tree=ProposedTree(target,targetWidget,edge,addition)
    local reqW,reqH=RequiredSize(tree)
    local canvasW,canvasH=Canvas:GetSize()
    -- Only promise a dock when its full tree will fit at *minimum legible sizes*.
    if reqW+8>canvasW-8 or reqH+8>canvasH-8 then return nil end
    return tree,max(target.w,reqW+8),max(target.h,reqH+8)
end
-- Entire connected groups can be docked to the OUTSIDE of another connected group.
-- Unlike leaf docking, this wraps the target's whole binary layout in a new root
-- split, so a new right panel spans the complete target group height.
local function GroupJoinPlan(target, moving, edge)
    if not target or not moving or target.id==moving.id or target.locked or moving.locked
        or not VALID_EDGE[edge] or not Canvas then return nil end
    local leftRight=(edge=="LEFT" or edge=="RIGHT")
    local before=(edge=="LEFT" or edge=="TOP")
    local a=before and CopyTree(moving.tree) or CopyTree(target.tree)
    local b=before and CopyTree(target.tree) or CopyTree(moving.tree)
    local tree=Split(leftRight and "H" or "V",0.5,a,b)
    local reqW,reqH=RequiredSize(tree)
    local W,H=Canvas:GetSize()
    if reqW+8>W-8 or reqH+8>H-8 then return nil end
    local desiredW=leftRight and (target.w+moving.w+SPLIT_GAP) or max(target.w,moving.w)
    local desiredH=leftRight and max(target.h,moving.h) or (target.h+moving.h+SPLIT_GAP)
    local w=Clamp(desiredW,max(MIN_GROUP_W,reqW+8),W-8)
    local h=Clamp(desiredH,max(MIN_GROUP_H,reqH+8),H-8)
    local extent=leftRight and (w-8-SPLIT_GAP) or (h-8-SPLIT_GAP)
    local wantedA=leftRight and (before and moving.w or target.w) or (before and moving.h or target.h)
    local wantedB=leftRight and (before and target.w or moving.w) or (before and target.h or moving.h)
    local amin=leftRight and select(1,RequiredSize(a)) or select(2,RequiredSize(a))
    local bmin=leftRight and select(1,RequiredSize(b)) or select(2,RequiredSize(b))
    local aSize=Clamp(extent*wantedA/max(1,wantedA+wantedB),amin,extent-bmin)
    tree.ratio=aSize/max(1,extent)
    local x=target.x+(edge=="LEFT" and (target.w-w) or 0)
    local y=target.y+(edge=="TOP" and (target.h-h) or 0)
    x=Clamp(x,0,max(0,W-w))
    y=Clamp(y,0,max(0,H-h))
    -- Predicted bounds of the ATTACHED outer panel, not a single child leaf.
    local panel={}
    if leftRight then
        local first=extent*tree.ratio
        local second=extent-first
        panel.x=x+4+(before and 0 or first+SPLIT_GAP)
        panel.y=y+4
        panel.w=before and first or second
        panel.h=h-8
    else
        local first=extent*tree.ratio
        local second=extent-first
        panel.x=x+4
        panel.y=y+4+(before and 0 or first+SPLIT_GAP)
        panel.w=w-8
        panel.h=before and first or second
    end
    return {tree=tree,x=x,y=y,w=w,h=h,panel=panel}
end

local function ClampToCanvas(g)
    if not Canvas then return end
    local W,H=Canvas:GetSize()
    W=max(W,350);H=max(H,250)
    local requiredW,requiredH=RequiredSize(g.tree)
    g.w=Clamp(g.w,max(MIN_GROUP_W,requiredW+8),W-8)
    g.h=Clamp(g.h,max(MIN_GROUP_H,requiredH+8),H-8)
    g.x=Clamp(g.x,0,max(0,W-g.w))
    g.y=Clamp(g.y,0,max(0,H-g.h))
end
-- Project canonical relative bounds whenever the journal window changes.
-- Rounding is applied only to rendered geometry, never to the canonical ratios.
local function ReflowResponsive(g, canvasW, canvasH)
    if not g._norm then RememberGeometry(g,canvasW,canvasH) end
    if not g._norm then return end
    local n=g._norm
    g.x=floor(n.x*canvasW+0.5)
    g.y=floor(n.y*canvasH+0.5)
    g.w=floor(n.w*canvasW+0.5)
    g.h=floor(n.h*canvasH+0.5)
    ClampToCanvas(g)
end

-- Fit ALL floating/docked group rectangles as a single layout composition.
-- Preserves dock trees, split ratios, panel ordering, intentional overlaps,
-- and whether snapping is enabled. Only outer rectangles are transformed.
local function FitLayoutToWindow()
    if not editing then Say("Turn on Edit Layout to fit widgets.");return end
    if InCombat() then Say("Layout fitting is unavailable during combat.");return end
    if not Canvas then return end
    if #groups==0 then Say("No widgets to fit. Open Widgets + to add some.");return end
    local W,H=Canvas:GetSize()
    if W < 100 or H < 100 then Say("Overview space is not ready yet.");return end
    local minX,minY,maxX,maxY
    for _,g in ipairs(groups) do
        minX=minX and min(minX,g.x) or g.x
        minY=minY and min(minY,g.y) or g.y
        maxX=maxX and max(maxX,g.x+g.w) or (g.x+g.w)
        maxY=maxY and max(maxY,g.y+g.h) or (g.y+g.h)
    end
    local contentW=max(1,maxX-minX)
    local contentH=max(1,maxY-minY)
    local margin=12
    local sx=max(1,W-2*margin)/contentW
    local sy=max(1,H-2*margin)/contentH
    local planned={}
    for i,g in ipairs(groups) do
        local newW=floor(g.w*sx+0.5)
        local newH=floor(g.h*sy+0.5)
        local reqW,reqH=RequiredSize(g.tree)
        -- Refuse an impossible fit rather than overlapping neighbors or
        -- silently breaking the widget minimum sizes.
        if newW < max(MIN_GROUP_W,reqW+8) or newH < max(MIN_GROUP_H,reqH+8) then
            Say("Fit needs more room for some widgets. Resize the journal, undock, or hide a widget first.")
            return
        end
        planned[i]={x=floor(margin+(g.x-minX)*sx+0.5),
            y=floor(margin+(g.y-minY)*sy+0.5),w=newW,h=newH}
    end
    for i,g in ipairs(groups) do
        local p=planned[i]
        g.x,g.y,g.w,g.h=p.x,p.y,p.w,p.h
        ClampToCanvas(g)
    end
    Store(true)
    RenderAll()
    Say("Fit Layout: all visible widget groups fitted to the Overview window.")
end

-- Extract only information that has already been recorded by the addon.
-- This function is called by page:Refresh, never during live splitter movement.
local function DataLines(key)
    local lines = {}
    local function Put(value) lines[#lines+1]=tostring(value or "") end
    if not AF.db then return {"Journal data is loading."} end
    local db=AF.db
    if key=="character" then
        local c=AF:CurrentCharacter()
        if not c then return {"Current character not yet registered."} end
        Put((c.name or "Unknown").."  -  Level "..tostring(c.level or "?").." "..tostring(c.class or ""))
        if AF:IsModuleEnabled("selfFound") and AF.IsExpeditionMember then Put(AF:IsExpeditionMember(c.key) and "Expedition member" or "Outside Expedition") end
        local profs={}
        for _,p in pairs(c.professions or {}) do
            if type(p)=="table" then
                profs[#profs+1]=(p.name or "Profession").." "..tostring(p.skill or "?").."/"..tostring(p.maximum or "?")
            end
        end
        table.sort(profs)
        for i=1,math.min(#profs,5) do Put(profs[i]) end
        if #profs==0 then Put("No professions recorded yet") end
    elseif key=="alts" then
        local chars=AF:GetCharacters()
        Put(tostring(#chars).." registered character(s)")
        local current=AF:GetCurrentKey()
        local n=0
        for _,c in ipairs(chars) do
            if c.key~=current then
                n=n+1
                Put((c.name or "Unknown").."  Lv "..tostring(c.level or "?").." "..(c.class or ""))
                if n>=7 then break end
            end
        end
        if n==0 then Put("No additional characters registered") end
    elseif key=="account" then
        local chars=AF:GetCharacters()
        local profs=AF:ProfessionSummary()
        local completed=0
        for _,p in ipairs(db.projects or {}) do if p.done then completed=completed+1 end end
        Put("Characters: "..#chars)
        Put("Professions discovered: "..#profs)
        Put("Goals: "..#(db.projects or {}))
        Put("Completed projects: "..completed)
        Put("Journal notes: "..#(db.notes or {}))
    elseif key=="goals" then
        -- Tracked (pinned) goals are a distinct group from all active projects.
        local tracked={}
        if type(AF.GetGoalsForView)=="function" then
            tracked=AF:GetGoalsForView("Tracked")
        else
            for _,p in ipairs(db.projects or {}) do
                if type(p)=="table" and not p.done then tracked[#tracked+1]=p end
            end
        end
        Put(tostring(#tracked).." tracked goal(s)")
        for i=1,math.min(6,#tracked) do
            local p=tracked[i]
            local done,total=AF:CountTasks(p)
            local status=p.done and "Complete" or (total>0 and (done.."/"..total) or "Not started")
            Put((p.title or "Untitled").."  -  "..status)
        end
        if #tracked==0 then Put("Track goals from the Goals tab") end
    elseif key=="workshop" then
        -- The existing priority-aware, reservation-aware evaluation is the sole source
        -- of readiness; we never infer it from raw bag counts.
        if type(AF.GetCraftingQueueProjects)=="function" then
            local queue=AF:GetCraftingQueueProjects()
            Put(tostring(#queue).." planned craft(s)")
            local report
            if #queue>0 and type(AF.EvaluateCraftingQueue)=="function" then
                local ok,result=pcall(AF.EvaluateCraftingQueue,AF)
                if ok and type(result)=="table" then report=result end
            end
            for i=1,math.min(6,#queue) do
                local p=queue[i]
                local entry=report and report.byId and report.byId[p.id]
                local status=entry and entry.status
                local label=status and AF:CraftStatusLabel(status) or "Readiness unverified"
                Put((p.title or "Untitled craft").."  -  "..label)
            end
            if #queue==0 then Put("No planned crafts yet") end
        else Put("Crafting planner unavailable") end
    elseif key=="notes" then
        local notes=db.notes or {}
        Put(tostring(#notes).." note(s)")
        for i=#notes,math.max(1,#notes-5),-1 do
            local n=notes[i]
            if type(n)=="table" then Put(n.title or "Untitled") end
        end
        if #notes==0 then Put("No journal notes yet") end
    elseif key=="exploration" then
        local zone=(type(GetRealZoneText)=="function" and GetRealZoneText()) or
            (type(GetZoneText)=="function" and GetZoneText()) or "Current zone"
        Put(zone)
        local mapID=type(C_Map)=="table" and type(C_Map.GetBestMapForUnit)=="function" and C_Map.GetBestMapForUnit("player")
        if mapID and type(AF.GetAtlasExplorationProgress)=="function" then
            local ok,progress=pcall(AF.GetAtlasExplorationProgress,AF,mapID,"character")
            if ok and type(progress)=="table" and progress.total then
                Put("Exploration: "..tostring(progress.done or 0).."/"..tostring(progress.total).." ("..tostring(progress.percent or 0).."%)")
            else Put("No native zone criteria available") end
        else Put("Open Exploration for zone details") end
    elseif key=="collections" then
        local discoveries=db.collections and db.collections.discoveries or {}
        local counts,total={},0
        for _,record in pairs(discoveries) do
            if type(record)=="table" and type(record.category)=="string" then
                counts[record.category]=(counts[record.category] or 0)+1
                total=total+1
            end
        end
        Put(tostring(total).." recorded discovery/discoveries")
        for _,kind in ipairs({"mounts","pets","toys","appearances"}) do
            if counts[kind] and counts[kind]>0 then Put(kind..": "..counts[kind]) end
        end
        Put("Only previously discovered entries are counted")
    elseif key=="selffound" then
        if not AF:IsModuleEnabled("selfFound") then
            Put("Optional Self-Found module is hidden")
            Put("Enable it in Settings > Modules")
            return lines
        end
        local current=AF:CurrentCharacter()
        local joined=current and AF.IsExpeditionMember and AF:IsExpeditionMember(current.key)
        Put(joined and "Current character: Expedition member" or "Current character: not enrolled")
        if type(AF.GetExpeditionMembers)=="function" then
            local inside,outside=AF:GetExpeditionMembers()
            Put("Enrolled: "..#inside.."  |  Outside: "..#outside)
        end
        local charter=AF.GetExpeditionCharter and AF:GetExpeditionCharter()
        Put(charter and charter.state=='active' and ('Charter active  |  v'..tostring(charter.version or '?')) or 'No active charter')
        if current then
            local title=AF:GetExpeditionParticipation(current.key)
            Put(title)
            if charter and charter.state=='active' and joined then
                Put(AF:GetExpeditionPlanningPolicy('expedition',current.key).label)
            end
        end
        Put("Local observation is not proof of compliance")
    end
    return lines
end

-- A visual overview of observed quantities. We only draw percent-complete
-- bars when a real denominator exists; collections / account counts are not
-- interpreted as completion percentages or as unobserved missing items.
WidgetPulse=function(key)
    if not AF.db then return nil end
    local db=AF.db
    if key=="character" then
        local c=AF:CurrentCharacter()
        local sum,count=0,0
        for _,p in pairs(c and c.professions or {}) do
            if type(p)=="table" then
                local skill,cap=tonumber(p.skill),tonumber(p.maximum)
                if skill and cap and cap>0 then
                    sum=sum+Clamp(skill/cap,0,1);count=count+1
                end
            end
        end
        if count>0 then return {label=("%d recorded skill%s"):format(count,count==1 and "" or "s"),fraction=sum/count} end
    elseif key=="goals" then
        local tracked=type(AF.GetGoalsForView)=="function" and AF:GetGoalsForView("Tracked") or {}
        local done,total=0,0
        for _,goal in ipairs(tracked or {}) do
            if type(goal)=="table" and type(AF.CountTasks)=="function" then
                local d,t=AF:CountTasks(goal)
                done=done+(tonumber(d) or 0);total=total+(tonumber(t) or 0)
            end
        end
        if total>0 then return {label=done.."/"..total.." tracked tasks",fraction=Clamp(done/total,0,1)} end
        return {label=#(tracked or {}).." tracked goals"}
    elseif key=="exploration" then
        local mapID=type(C_Map)=="table" and type(C_Map.GetBestMapForUnit)=="function" and C_Map.GetBestMapForUnit("player")
        if mapID and type(AF.GetAtlasExplorationProgress)=="function" then
            local ok,v=pcall(AF.GetAtlasExplorationProgress,AF,mapID,"character")
            if ok and type(v)=="table" and tonumber(v.total) and tonumber(v.total)>0 then
                return {label=(tonumber(v.done) or 0).."/"..v.total.." zone criteria",fraction=Clamp((tonumber(v.done) or 0)/v.total,0,1)}
            end
        end
        return {label="Zone criteria unavailable"}
    elseif key=="selffound" then
        if not AF:IsModuleEnabled("selfFound") then return nil end
        local exp=type(AF.GetExpedition)=="function" and AF:GetExpedition()
        local run=exp and exp.charter
        if run and type(run.milestones)=="table" and type(AF.EXPEDITION_MILESTONE_DEFS)=="table" then
            local count,total=0,0
            for _,def in ipairs(AF.EXPEDITION_MILESTONE_DEFS) do
                total=total+1
                if run.milestones[def.id] then count=count+1 end
            end
            if total>0 then return {label=count.."/"..total.." expedition milestones",fraction=Clamp(count/total,0,1)} end
        end
        return {label="Expedition milestone journal"}
    elseif key=="collections" then
        local discoveries=db.collections and db.collections.discoveries or {}
        local total=0
        for _,r in pairs(discoveries) do if type(r)=="table" and type(r.category)=="string" then total=total+1 end end
        return {label=total.." recorded discoveries"}
    elseif key=="alts" then
        local chars=AF:GetCharacters() or {}
        return {label=#chars.." registered characters"}
    elseif key=="account" then
        return {label=#(db.projects or {}).." journal goals"}
    elseif key=="notes" then
        return {label=#(db.notes or {}).." recorded notes"}
    elseif key=="workshop" then
        if type(AF.GetCraftingQueueProjects)=="function" then
            local queue=AF:GetCraftingQueueProjects() or {}
            if #queue>0 and type(AF.EvaluateCraftingQueue)=="function" then
                local ok,report=pcall(AF.EvaluateCraftingQueue,AF)
                if ok and type(report)=="table" and type(report.byId)=="table" then
                    local ready=0
                    for _,proj in ipairs(queue) do
                        local entry=report.byId[proj.id]
                        if entry and entry.status=="ready" then ready=ready+1 end
                    end
                    return {label=ready.."/"..#queue.." crafts material-ready",fraction=Clamp(ready/#queue,0,1)}
                end
            end
            return {label=#queue.." planned crafts"}
        end
    end
    return nil
end
local function RefreshDataCache()
    -- Only visible widgets ask the gameplay systems for a summary. This keeps
    -- expensive crafting evaluation and native map lookups out of hidden tabs.
    local used={}
    local function collect(node)
        if node.widget then used[node.widget]=true
        else collect(node.a);collect(node.b) end
    end
    for _,g in ipairs(groups) do collect(g.tree) end
    for _,key in ipairs(ORDER) do
        displayCache[key]=used[key] and DataLines(key) or nil
        pulseCache[key]=used[key] and WidgetPulse(key) or nil
    end
end
local function DisplayLeafText(node)
    local key=node.widget
    local lines=displayCache[key] or {"Loading journal..."}
    local region=node._frame
    local height=region and region:GetHeight() or 240
    local width=region and region:GetWidth() or 330
    local pulse=pulseCache[key]
    local reserve=(pulse and height>=145 and width>=185) and (type(pulse.fraction)=="number" and height>=165 and 91 or 74) or 50
    local maxLines=math.max(1,math.min(#lines,math.floor((height-reserve)/15)))
    local maxChars=math.max(15, math.floor((width-24)/6.2))
    local result={}
    for i=1,maxLines do
        local s=lines[i] or ""
        if #s>maxChars then s=s:sub(1,maxChars-3).."..." end
        result[#result+1]=s
    end
    return table.concat(result,"\n")
end
local function UpdateLeafPulse(n)
    if not n._pulseText then return end
    local pulse=pulseCache[n.widget]
    local height=n._frame and n._frame:GetHeight() or 200
    local width=n._frame and n._frame:GetWidth() or 200
    local visible=pulse and height>=145 and width>=185
    local withBar=visible and type(pulse.fraction)=="number" and height>=165
    n._pulseText:SetShown(visible and true or false)
    n._pulseTrack:SetShown(withBar and true or false)
    n._pulseFill:SetShown(withBar and true or false)
    if visible then n._pulseText:SetText(pulse.label or "") end
    if withBar then
        n._pulseFill:SetWidth(max(1,(width-32)*Clamp(pulse.fraction,0,1)))
    end
    n._body:ClearAllPoints()
    n._body:SetPoint("TOPLEFT",n._header,"BOTTOMLEFT",5,(withBar and -40 or visible and -23 or -8))
    n._body:SetPoint("BOTTOMRIGHT",n._frame,"BOTTOMRIGHT",-8,8)
end
RefreshBodies=function()
    if not Canvas then return end
    RefreshDataCache()
    local function visit(n)
        if n.widget then
            if n._body then
                UpdateLeafPulse(n)
                n._body:SetText(DisplayLeafText(n))
            end
            return
        end
        visit(n.a);visit(n.b)
    end
    for _,g in ipairs(groups) do visit(g.tree) end
end
local function GetCursorInFrameScale(frame)
    if type(GetCursorPosition)~="function" then return nil end
    local x,y=GetCursorPosition()
    local scale=(frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    if scale==0 then scale=1 end
    return x/scale,y/scale
end
local function UpdateTitlebar() -- forward declaration not needed; controls read editing on click
    if EditButton and EditButton.label then
        EditButton.label:SetText(editing and "Finish Editing" or "Edit Layout")
    end
    if SnapButton and SnapButton.label then
        SnapButton.label:SetText(snapEnabled and "Snap: ON" or "Snap: OFF")
    end
    if FitButton then FitButton:SetShown(editing) end
    if SnapButton and ResetButton and FitButton then
        SnapButton:ClearAllPoints()
        SnapButton:SetPoint("RIGHT",editing and FitButton or ResetButton,"LEFT",-6,0)
    end
end
local function StartEdit(value)
    if InCombat() then Say("Layout editing is unavailable during combat.");return end
    editing=value
    if Picker then Picker:Hide() end
    if ShowSnapCandidate then ShowSnapCandidate(nil) end
    UpdateTitlebar()
    if RenderAll then RenderAll() end
end
local function CaptureFramePosition(g, f)
    if not Canvas or not f then return end
    local l,t=Canvas:GetLeft(),Canvas:GetTop()
    local fl,ft=f:GetLeft(),f:GetTop()
    if not l or not t or not fl or not ft then return end
    g.x=fl-l;g.y=t-ft
    g.w,g.h=f:GetSize()
    ClampToCanvas(g)
end
local function MakeFloating(widget, x, y)
    if FindWidget(widget) then Say("That widget is already in use.");return end
    local g={id=nextId,x=x or 60,y=y or 55,w=310,h=206,locked=false,tree=NewLeaf(widget)}
    nextId=nextId+1
    ClampToCanvas(g)
    groups[#groups+1]=g
    Store(true);RenderAll()
    Say(WIDGETS[widget].title.." added as a floating widget.")
end

RemoveWidget = function(widget)
    for i,g in ipairs(groups) do
        if FindNode(g.tree,widget) then
            local tree=PruneNode(g.tree,widget)
            if tree then g.tree=tree else table.remove(groups,i) end
            Store(true);RenderAll();Say(WIDGETS[widget].title.." hidden (available in Widgets).")
            return
        end
    end
end
UndockWidget = function(widget)
    local g=FindWidget(widget)
    if not g or g.tree.widget then return end
    if g.locked then Say("Unlock the group before undocking.");return end
    local target=FindNode(g.tree,widget)
    local centerX,centerY=g.x+g.w*0.5,g.y+g.h*0.5
    if target and target._region then
        centerX=g.x+target._region.x+target._region.w*0.5
        centerY=g.y+target._region.y+target._region.h*0.5
    end
    local newer=PruneNode(g.tree,widget)
    if not newer then return end
    g.tree=newer
    local ng={id=nextId,x=centerX-150,y=centerY-105,w=300,h=210,locked=false,tree=NewLeaf(widget)}
    nextId=nextId+1
    ClampToCanvas(ng)
    groups[#groups+1]=ng
    Store(true);RenderAll()
    Say(WIDGETS[widget].title.." undocked. Drag its header toward another panel edge to dock.")
end
local function DockWidget(targetId, targetWidget, edge, addition)
    if not WIDGETS[addition] or FindWidget(addition) then
        Say("That widget is already displayed. Use its U button to detach it first.")
        return false
    end
    local target=FindGroup(targetId)
    if not target or target.locked then Say("Destination is locked or unavailable.");return false end
    local replacement,newW,newH=CanFitDock(target,targetWidget,edge,addition)
    if not replacement then
        Say("Dock would exceed available space. Widget can still be added floating.")
        return false
    end
    target.tree=replacement
    target.w,target.h=newW,newH
    ClampToCanvas(target)
    Store(true);RenderAll()
    Say(WIDGETS[addition].title.." docked "..edge:lower().." of "..WIDGETS[targetWidget].title..".")
    return true
end
local function LeafRegions(n, out)
    if n.widget then
        if n._frame and n._frame.IsVisible and n._frame:IsVisible() then out[#out+1]=n end
        return
    end
    LeafRegions(n.a,out);LeafRegions(n.b,out)
end
-- A floating widget's *rectangle*, not just the cursor's hotspot, is compared
-- with visible widget surfaces. This allows magnetic release near any edge.
local function FindLeafSnapCandidate(moving, movingFrame)
    if not moving or not moving.tree.widget or not movingFrame then return nil end
    local ml,mr,mt,mb=movingFrame:GetLeft(),movingFrame:GetRight(),movingFrame:GetTop(),movingFrame:GetBottom()
    if not ml or not mr or not mt or not mb then return nil end
    local best,bestScore
    for _,g in ipairs(groups) do
        if g.id~=moving.id and not g.locked then
            local leaves={};LeafRegions(g.tree,leaves)
            for _,node in ipairs(leaves) do
                local f=node._frame
                local l,r,t,b=f:GetLeft(),f:GetRight(),f:GetTop(),f:GetBottom()
                if l and r and t and b then
                    local verticalOverlap=min(mt,t)-max(mb,b)
                    local horizontalOverlap=min(mr,r)-max(ml,l)
                    local options={
                        {edge="RIGHT",gap=ml-r,overlap=verticalOverlap},
                        {edge="LEFT",gap=l-mr,overlap=verticalOverlap},
                        {edge="TOP",gap=mb-t,overlap=horizontalOverlap},
                        {edge="BOTTOM",gap=b-mt,overlap=horizontalOverlap},
                    }
                    for _,option in ipairs(options) do
                        local gap=option.gap
                        -- Accept slightly overlapping edges and small positive gaps,
                        -- but never snap a panel dropped in the middle of another.
                        if option.overlap>=24 and gap>=-SNAP_OVERLAP and gap<=SNAP_DISTANCE then
                            local score=abs(gap)+max(0,50-option.overlap)*0.15
                            if (not bestScore or score<bestScore) and
                                CanFitDock(g,node.widget,option.edge,moving.tree.widget) then
                                bestScore=score
                                best={group=g,node=node,edge=option.edge,score=score}
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end
-- Snap target: one of the four *outer boundaries* of a whole group.
-- Prefer group docking near its outside perimeter; preserve leaf docking when
-- dragging into an internal card edge instead.
local function FindGroupSnapCandidate(moving, movingFrame)
    if not moving or not movingFrame then return nil end
    local ml,mr,mt,mb=movingFrame:GetLeft(),movingFrame:GetRight(),movingFrame:GetTop(),movingFrame:GetBottom()
    if not ml or not mr or not mt or not mb then return nil end
    local best,bestScore
    for _,g in ipairs(groups) do
        if g.id~=moving.id and not g.locked and views[g.id] then
            local f=views[g.id]
            local l,r,t,b=f:GetLeft(),f:GetRight(),f:GetTop(),f:GetBottom()
            if l and r and t and b then
                local vOverlap=min(mt,t)-max(mb,b)
                local hOverlap=min(mr,r)-max(ml,l)
                local options={
                    {edge="RIGHT",gap=ml-r,overlap=vOverlap,threshold=min(moving.h,g.h)*0.2},
                    {edge="LEFT",gap=l-mr,overlap=vOverlap,threshold=min(moving.h,g.h)*0.2},
                    {edge="TOP",gap=mb-t,overlap=hOverlap,threshold=min(moving.w,g.w)*0.2},
                    {edge="BOTTOM",gap=b-mt,overlap=hOverlap,threshold=min(moving.w,g.w)*0.2},
                }
                for _,option in ipairs(options) do
                    local gap=option.gap
                    if option.overlap>=max(32,option.threshold)
                        and gap>=-SNAP_OVERLAP and gap<=SNAP_DISTANCE then
                        local plan=GroupJoinPlan(g,moving,option.edge)
                        if plan then
                            local score=abs(gap)+max(0,50-option.overlap)*0.15
                            if not bestScore or score<bestScore then
                                bestScore=score
                                best={kind="group",group=g,edge=option.edge,plan=plan,score=score}
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end
local function FindSnapCandidate(moving,movingFrame,groupOnly)
    if not snapEnabled then return nil end
    local groupMatch=FindGroupSnapCandidate(moving,movingFrame)
    if groupMatch then return groupMatch end
    if groupOnly then return nil end
    -- Single floating cards can still enter individual subdivisions as before.
    return FindLeafSnapCandidate(moving,movingFrame)
end

ShowSnapCandidate = function(candidate)
    if not SnapPreview then return end
    if not candidate or not editing or not snapEnabled then SnapPreview:Hide();return end
    if candidate.kind=="group" then
        local panel=candidate.plan and candidate.plan.panel
        if not panel then SnapPreview:Hide();return end
        SnapPreview:ClearAllPoints()
        SnapPreview:SetPoint("TOPLEFT",Canvas,"TOPLEFT",panel.x,-panel.y)
        SnapPreview:SetSize(max(16,panel.w),max(16,panel.h))
        if SnapLabel then SnapLabel:SetText("Dock FULL group "..candidate.edge:lower()) end
        SnapPreview:Show()
        return
    end
    local n=candidate.node
    if not n or not n._frame then SnapPreview:Hide();return end
    local edge=candidate.edge
    local frame=n._frame
    SnapPreview:ClearAllPoints()
    -- Preview occupies the corresponding side of the recipient surface.
    if edge=="RIGHT" then
        SnapPreview:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
        SnapPreview:SetSize(max(32,frame:GetWidth()*0.5),frame:GetHeight())
    elseif edge=="LEFT" then
        SnapPreview:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0)
        SnapPreview:SetSize(max(32,frame:GetWidth()*0.5),frame:GetHeight())
    elseif edge=="TOP" then
        SnapPreview:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0)
        SnapPreview:SetSize(frame:GetWidth(),max(32,frame:GetHeight()*0.5))
    else
        SnapPreview:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0)
        SnapPreview:SetSize(frame:GetWidth(),max(32,frame:GetHeight()*0.5))
    end
    if SnapLabel then SnapLabel:SetText("Dock "..edge:lower()) end
    SnapPreview:Show()
end
TryDock = function(moving, movingFrame, candidate)
    if not moving or not snapEnabled then return false end
    local match=candidate or FindSnapCandidate(moving,movingFrame)
    ShowSnapCandidate(nil)
    if not match then return false end
    local destination=FindGroup(match.group.id)
    local index
    for i,g in ipairs(groups) do if g.id==moving.id then index=i;break end end
    if not index or not destination then return false end
    if match.kind=="group" then
        -- Check once more at mouse-release time. Do not delete the source
        -- group until the complete new tree has been proven to fit.
        local plan=GroupJoinPlan(destination,moving,match.edge)
        if not plan then return false end
        table.remove(groups,index)
        destination.tree=plan.tree
        destination.x,destination.y=plan.x,plan.y
        destination.w,destination.h=plan.w,plan.h
        ClampToCanvas(destination)
        Store(true);RenderAll()
        Say("Whole group docked "..match.edge:lower().." of the connected layout.")
        return true
    end
    if not moving.tree.widget or not match.node then return false end
    local added=moving.tree.widget
    local replacement,newW,newH=CanFitDock(destination,match.node.widget,match.edge,added)
    if not replacement then return false end
    table.remove(groups,index)
    destination.tree=replacement
    destination.w,destination.h=newW,newH
    ClampToCanvas(destination)
    Store(true);RenderAll()
    Say(WIDGETS[added].title.." snapped "..match.edge:lower().." of "..WIDGETS[match.node.widget].title..".")
    return true
end
-- Dock a newly chosen library widget as a full-width/full-height outer branch.
local function DockWidgetToGroup(targetId,edge,widget)
    if not WIDGETS[widget] or FindWidget(widget) then return false end
    local destination=FindGroup(targetId)
    local phantom={id=-1,w=310,h=206,locked=false,tree=NewLeaf(widget)}
    local plan=GroupJoinPlan(destination,phantom,edge)
    if not plan then return false end
    destination.tree=plan.tree
    destination.x,destination.y=plan.x,plan.y
    destination.w,destination.h=plan.w,plan.h
    ClampToCanvas(destination)
    Store(true);RenderAll()
    Say(WIDGETS[widget].title.." attached to OUTER "..edge:lower().." edge of group.")
    return true
end

local function OpenPicker(groupId, widget, edge)
    if not editing or InCombat() then return end
    selectedDock={mode="leaf",groupId=groupId,widget=widget,edge=edge}
    if Picker and Picker.title then
        Picker.title:SetText("Attach "..edge:lower().." of "..WIDGETS[widget].title)
        Picker:Show()
        if Picker.Refresh then Picker:Refresh() end
    end
end
local function OpenGroupPicker(groupId,edge)
    if not editing or InCombat() then return end
    selectedDock={mode="group",groupId=groupId,edge=edge}
    if Picker and Picker.title then
        Picker.title:SetText("Attach outside entire group ("..edge:lower()..")")
        Picker:Show()
        if Picker.Refresh then Picker:Refresh() end
    end
end
local function NewWidgetHeader(leaf, g, groupFrame)
    local widgetId=leaf.widget
    local h=CreateFrame("Button",nil,leaf._frame)
    h:SetHeight(30);h:SetPoint("TOPLEFT",leaf._frame,"TOPLEFT",4,-3);h:SetPoint("TOPRIGHT",leaf._frame,"TOPRIGHT",-4,-3)
    local headerBackground=Paint(h,"BACKGROUND",PALETTE.button)
    local titleRule=h:CreateTexture(nil,"ARTWORK")
    titleRule:SetPoint("BOTTOMLEFT",h,"BOTTOMLEFT",9,0)
    titleRule:SetPoint("BOTTOMRIGHT",h,"BOTTOMRIGHT",-9,0)
    titleRule:SetHeight(1)
    titleRule:SetColorTexture(.78,.55,.27,.46)
    local headerKey="Pages.Overview.Widget."..widgetId..".Header.Background"
    RestoreTexture(headerBackground,artTransfer[headerKey])
    RegisterArtTarget(headerKey,headerBackground)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(h,function(_,t)
        local c=t.rainbow and t.accent2 or t.divider
        titleRule:SetColorTexture(c[1],c[2],c[3],.72)
        if not artTransfer[headerKey] then
            local _,_,c=OverviewCardStyle(t)
            headerBackground:SetColorTexture(c[1],c[2],c[3],.99)
            headerBackground.afOverviewThemeSnapshot=TextureSnapshot(headerBackground)
        end
    end) end
    local name=Label(h,WIDGETS[widgetId].title,12,PALETTE.light)
    name:SetPoint("LEFT",h,"LEFT",14,0);name:SetPoint("RIGHT",h,"RIGHT",-86,0)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(name,function(label,t)
        local _,_,_,ink=OverviewCardStyle(t)
        label:SetTextColor(unpack(ink))
    end) end
    name:SetWordWrap(false)
    local undock=Button(h,"^",22,21,function()
        if editing then UndockWidget(widgetId) end
    end,13)
    undock:SetPoint("RIGHT",h,"RIGHT",-55,0)
    local lock=Button(h,g.locked and "U" or "L",22,21,function()
        if not editing or InCombat() then return end
        g.locked=not g.locked;Store();RenderAll()
        Say(g.locked and "Group locked." or "Group unlocked.")
    end,11)
    lock:SetPoint("RIGHT",h,"RIGHT",-30,0)
    local hide=Button(h,"x",22,21,function()
        if editing and not InCombat() then RemoveWidget(widgetId) end
    end,12)
    hide:SetPoint("RIGHT",h,"RIGHT",-5,0)
    h:SetScript("OnClick",function()
        if editing then return end
        local destination={character="Characters",alts="Characters",account="Characters",
            goals="Goals",workshop="Living Workshop",exploration="Exploration",
            collections="Collections",notes="Notes",selffound="Self-Found"}
        local tab=destination[widgetId]
        if tab and UI.Switch then UI:Switch(tab) end
    end)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart",function()
        if not editing or g.locked or InCombat() then return end
        if not g.tree.widget then
            Say("This widget is docked. Use its undock (^) button to make it independently movable.")
            return
        end
        if groupFrame.Raise then groupFrame:Raise() end
        groupFrame:StartMoving()
        groupFrame._moving=true
        groupFrame:SetScript("OnUpdate",function(self)
            self._snapCandidate=FindSnapCandidate(g,self)
            ShowSnapCandidate(self._snapCandidate)
        end)
    end)
    h:SetScript("OnDragStop",function()
        if not groupFrame._moving then return end
        groupFrame._moving=false
        groupFrame:SetScript("OnUpdate",nil)
        groupFrame:StopMovingOrSizing()
        CaptureFramePosition(g,groupFrame)
        if not TryDock(g,groupFrame,FindSnapCandidate(g,groupFrame)) then
            groupFrame:ClearAllPoints()
            groupFrame:SetPoint("TOPLEFT",Canvas,"TOPLEFT",g.x,-g.y)
            Store(true)
        end
        groupFrame._snapCandidate=nil
    end)
    h:SetScript("OnEnter",function()
        if editing then
            if GameTooltip then
                GameTooltip:SetOwner(h,"ANCHOR_TOP")
                GameTooltip:SetText("Drag floating widget to move. U = undock; L = lock group; x = hide widget")
                GameTooltip:Show()
            end
        end
    end)
    h:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    leaf._header=h; leaf._headerTitle=name
    leaf._undock=undock;leaf._lock=lock;leaf._hide=hide
    local text=Label(leaf._frame,DisplayLeafText(leaf),12,PALETTE.subdued)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(text,function(label,t)
        local _,ink=OverviewCardStyle(t)
        label:SetTextColor(unpack(ink))
    end) end
    text:SetPoint("TOPLEFT",h,"BOTTOMLEFT",5,-8)
    text:SetPoint("BOTTOMRIGHT",leaf._frame,"BOTTOMRIGHT",-8,8)
    text:SetJustifyV("TOP")
    leaf._body=text
    local pulseText=Label(leaf._frame,"",10,PALETTE.subdued)
    pulseText:SetPoint("TOPLEFT",h,"BOTTOMLEFT",12,-4)
    pulseText:SetPoint("TOPRIGHT",h,"BOTTOMRIGHT",-9,-4)
    pulseText:SetHeight(16)
    local pulseTrack=leaf._frame:CreateTexture(nil,"ARTWORK")
    pulseTrack:SetPoint("TOPLEFT",h,"BOTTOMLEFT",12,-23)
    pulseTrack:SetPoint("TOPRIGHT",h,"BOTTOMRIGHT",-12,-23)
    pulseTrack:SetHeight(5)
    local pulseFill=leaf._frame:CreateTexture(nil,"OVERLAY")
    pulseFill:SetPoint("TOPLEFT",pulseTrack,"TOPLEFT")
    pulseFill:SetHeight(5)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(pulseText,function(label,t)
        local _,ink=OverviewCardStyle(t)
        label:SetTextColor(unpack(ink))
        local track=t.light and t.divider or t.navActive
        pulseTrack:SetColorTexture(track[1],track[2],track[3],t.light and .68 or .95)
        pulseFill:SetColorTexture(t.accent[1],t.accent[2],t.accent[3],1)
    end) end
    leaf._pulseText=pulseText;leaf._pulseTrack=pulseTrack;leaf._pulseFill=pulseFill
    leaf._edges={}
    for _,edge in ipairs({"LEFT","RIGHT","TOP","BOTTOM"}) do
        local plus=Button(leaf._frame,"+",20,20,function() OpenPicker(g.id,widgetId,edge) end,14)
        if edge=="LEFT" then plus:SetPoint("LEFT",leaf._frame,"LEFT",-6,0)
        elseif edge=="RIGHT" then plus:SetPoint("RIGHT",leaf._frame,"RIGHT",6,0)
        elseif edge=="TOP" then plus:SetPoint("TOP",leaf._frame,"TOP",0,5)
        else plus:SetPoint("BOTTOM",leaf._frame,"BOTTOM",0,-5) end
        plus:SetFrameLevel(leaf._frame:GetFrameLevel()+5)
        leaf._edges[edge]=plus
    end
end
local function BuildVisuals(n,g,groupFrame)
    if n.widget then
        local f=CreateFrame("Frame",nil,groupFrame)
        f:SetFrameLevel(groupFrame:GetFrameLevel()+2)
        local widgetBackground=Paint(f,"BACKGROUND",PALETTE.leaf)
        -- No large washed-out rock/marble sheets stretched over a widget;
        -- the approved dark data surface is a solid fill and border.
        -- Curated shared leaf: a consistent dark data background for all
        -- widgets. Previously this put full-size parchment, quest-sheet and
        -- spellbook crops behind three arbitrary widgets, causing floating
        -- edges and unreadable text after resize. Saved custom art targets
        -- still restore below, preserving user-authored overrides.
        n._frame=f
        local backgroundKey="Pages.Overview.Widget."..n.widget..".Background"
        RestoreTexture(widgetBackground,artTransfer[backgroundKey])
        RegisterArtTarget(backgroundKey,widgetBackground)
        -- Cards follow the theme as a complete surface/text pair. Preserve
        -- actual Art Lab overrides, but never turn our own theme paint into a
        -- fake external override on the next dock/resize rebuild.
        if not artTransfer[backgroundKey] and UI.RegisterThemeTarget then
            UI:RegisterThemeTarget(widgetBackground,function(texture,tokens)
                local c=OverviewCardStyle(tokens)
                texture:SetColorTexture(c[1],c[2],c[3],.99)
                texture.afOverviewThemeSnapshot=TextureSnapshot(texture)
            end)
        end
        -- Use the color-first theme border without decorative image sheets.
        if UI.FoundryQuestBorder then
            UI:FoundryQuestBorder(f,{cap=20,alpha=.74,outset=1})
        end
        NewWidgetHeader(n,g,groupFrame)
        return
    end
    BuildVisuals(n.a,g,groupFrame);BuildVisuals(n.b,g,groupFrame)
    local s=CreateFrame("Button",nil,groupFrame)
    s:SetFrameLevel(groupFrame:GetFrameLevel()+6)
    local gapFill=Paint(s,"BACKGROUND",PALETTE.gap)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(gapFill,function(tex,t)
        local c=t.divider
        tex:SetColorTexture(c[1],c[2],c[3],.32)
    end) end
    n._splitter=s
    s:RegisterForClicks("LeftButtonUp")
    s:SetScript("OnMouseDown",function(_,button)
        if button~="LeftButton" or not editing or g.locked or InCombat() then return end
        s._drag=true
        s:SetScript("OnUpdate",function()
            if not s._drag or not n._region then return end
            local mouseX,mouseY=GetCursorInFrameScale(groupFrame)
            local left,top=groupFrame:GetLeft(),groupFrame:GetTop()
            if not left or not top or not mouseX then return end
            local region=n._region
            local extent=n.axis=="H" and region.w or region.h
            local cursorOffset=n.axis=="H" and (mouseX-left-region.x) or (top-mouseY-region.y)
            local minA, minB
            if n.axis=="H" then
                minA=select(1,RequiredSize(n.a));minB=select(1,RequiredSize(n.b))
            else
                minA=select(2,RequiredSize(n.a));minB=select(2,RequiredSize(n.b))
            end
            if extent<minA+minB+SPLIT_GAP then return end
            n.ratio=Clamp(cursorOffset/extent,minA/extent,1-minB/extent)
            LayoutGroup(g,groupFrame)
        end)
    end)
    s:SetScript("OnMouseUp",function()
        s._drag=false;s:SetScript("OnUpdate",nil)
        Store()
    end)
    s:SetScript("OnHide",function() s._drag=false;s:SetScript("OnUpdate",nil) end)
end
local function DisableVisuals(n)
    if n.widget then
        if n._frame then n._frame:Hide() end
        n._frame=nil
        n._region=nil
        return
    end
    DisableVisuals(n.a);DisableVisuals(n.b)
    if n._splitter then n._splitter:Hide() end
    n._splitter=nil
    n._region=nil
end
local function Position(n,g,groupFrame,x,y,w,h)
    n._region={x=x,y=y,w=w,h=h}
    if n.widget then
        local f=n._frame
        f:ClearAllPoints();f:SetPoint("TOPLEFT",groupFrame,"TOPLEFT",x,-y)
        f:SetSize(max(1,w),max(1,h))
        f:Show()
        if n._body then
            UpdateLeafPulse(n)
            n._body:SetText(DisplayLeafText(n))
        end
        local controls=editing
        n._hide:SetShown(controls)
        n._lock:SetShown(controls)
        n._undock:SetShown(controls and not g.tree.widget)
        n._lock.label:SetText(g.locked and "U" or "L")
        n._headerTitle:SetPoint("RIGHT",n._header,"RIGHT",controls and -86 or -8,0)
        for _,edge in ipairs({"LEFT","RIGHT","TOP","BOTTOM"}) do
            local p=n._edges[edge]
            p:SetShown(controls and not g.locked and CanAddSplit(n._region,edge))
        end
        return
    end
    local r=Clamp(tonumber(n.ratio) or 0.5,0.16,0.84)
    if n.axis=="H" then
        local avail=max(2,w-SPLIT_GAP)
        local amin=select(1,RequiredSize(n.a))
        local bmin=select(1,RequiredSize(n.b))
        local a=Clamp(floor(avail*r),amin,max(amin,avail-bmin))
        if avail<amin+bmin then a=floor(avail*amin/(amin+bmin)) end
        local b=avail-a
        -- Preserve the preferred split ratio when minimum sizes temporarily clamp it.
        -- A later window expansion should restore the user's divider proportions.
        Position(n.a,g,groupFrame,x,y,a,h)
        Position(n.b,g,groupFrame,x+a+SPLIT_GAP,y,b,h)
        n._splitter:ClearAllPoints()
        n._splitter:SetPoint("TOPLEFT",groupFrame,"TOPLEFT",x+a,-y)
        n._splitter:SetSize(SPLIT_GAP,h)
    else
        local avail=max(2,h-SPLIT_GAP)
        local amin=select(2,RequiredSize(n.a))
        local bmin=select(2,RequiredSize(n.b))
        local a=Clamp(floor(avail*r),amin,max(amin,avail-bmin))
        if avail<amin+bmin then a=floor(avail*amin/(amin+bmin)) end
        local b=avail-a
        -- Preserve the preferred split ratio when minimum sizes temporarily clamp it.
        -- A later window expansion should restore the user's divider proportions.
        Position(n.a,g,groupFrame,x,y,w,a)
        Position(n.b,g,groupFrame,x,y+a+SPLIT_GAP,w,b)
        n._splitter:ClearAllPoints()
        n._splitter:SetPoint("TOPLEFT",groupFrame,"TOPLEFT",x,-y-a)
        n._splitter:SetSize(w,SPLIT_GAP)
    end
    n._splitter:SetShown(editing and not g.locked)
end
LayoutGroup = function(g,groupFrame)
    if not groupFrame or not g.tree or not g.tree._frame and not g.tree._splitter then return end
    local w,h=groupFrame:GetSize()
    Position(g.tree,g,groupFrame,4,4,max(1,w-8),max(1,h-8))
    if groupFrame.grip then groupFrame.grip:SetShown(editing and not g.locked) end
    if groupFrame.moveHandle then groupFrame.moveHandle:SetShown(editing and not g.locked) end
    if groupFrame.outerButtons then
        for _,button in pairs(groupFrame.outerButtons) do
            button:SetShown(editing and not g.locked)
        end
    end
end
local function SizeGrip(g,frame)
    local b=Button(frame,"R",20,20,function() end,13)
    b:SetFrameLevel(frame:GetFrameLevel()+12)
    b:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    b:SetScript("OnMouseDown",function(_,button)
        if button=="LeftButton" and editing and not g.locked and not InCombat() then
            frame:StartSizing("BOTTOMRIGHT")
            frame._sizing=true
        end
    end)
    b:SetScript("OnMouseUp",function()
        if not frame._sizing then return end
        frame._sizing=false
        frame:StopMovingOrSizing()
        local width,height=frame:GetSize()
        g.w=width;g.h=height
        ClampToCanvas(g)
        frame:SetSize(g.w,g.h)
        Store(true);LayoutGroup(g,frame)
    end)
    return b
end
local function NewGroupFrame(g)
    local f=CreateFrame("Frame",nil,Canvas)
    f.model=g
    f:SetMovable(true);f:SetResizable(true);f:EnableMouse(true)
    local needW,needH=RequiredSize(g.tree)
    needW=max(MIN_GROUP_W,needW+8);needH=max(MIN_GROUP_H,needH+8)
    if f.SetResizeBounds then f:SetResizeBounds(needW,needH,1500,1100)
    elseif f.SetMinResize then f:SetMinResize(needW,needH) end
    f:SetFrameLevel(Canvas:GetFrameLevel()+5)
    local groupBase=Paint(f,"BACKGROUND",PALETTE.panel)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(groupBase,function(tex,t)
        local c=t.surface;tex:SetColorTexture(c[1],c[2],c[3],.99)
    end) end
    -- The group keeps a quiet 1px edge; individual leaves carry the actual
    -- carved borders, so docked cards look related rather than double-boxed.
    local groupRule=f:CreateTexture(nil,"BORDER")
    groupRule:SetPoint("TOPLEFT",f,"TOPLEFT",3,-1)
    groupRule:SetPoint("TOPRIGHT",f,"TOPRIGHT",-3,-1)
    groupRule:SetHeight(1)
    groupRule:SetColorTexture(.74,.52,.25,.26)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(groupRule,function(tex,t)
        local c=t.divider;tex:SetColorTexture(c[1],c[2],c[3],.37)
    end) end
    f.grip=SizeGrip(g,f)
    local handle=Button(f,"M",22,19,function() end,11)
    handle:SetPoint("TOPLEFT",f,"TOPLEFT",-7,7)
    handle:SetFrameLevel(f:GetFrameLevel()+13)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart",function()
        if editing and not g.locked and not InCombat() then
            if f.Raise then f:Raise() end
            f:StartMoving();f._movingGroup=true
            f:SetScript("OnUpdate",function(self)
                self._snapCandidate=FindSnapCandidate(g,self,true)
                ShowSnapCandidate(self._snapCandidate)
            end)
        end
    end)
    handle:SetScript("OnDragStop",function()
        if not f._movingGroup then return end
        f._movingGroup=false
        f:SetScript("OnUpdate",nil)
        f:StopMovingOrSizing()
        local candidate=FindSnapCandidate(g,f,true)
        CaptureFramePosition(g,f)
        if not TryDock(g,f,candidate) then
            f:ClearAllPoints();f:SetPoint("TOPLEFT",Canvas,"TOPLEFT",g.x,-g.y)
            Store(true)
        end
        f._snapCandidate=nil
        ShowSnapCandidate(nil)
    end)
    f.moveHandle=handle
    f.outerButtons={}
    for _,edge in ipairs({"LEFT","RIGHT","TOP","BOTTOM"}) do
        local b=Button(f,"G+",22,20,function() OpenGroupPicker(g.id,edge) end,10)
        b:SetFrameLevel(f:GetFrameLevel()+14)
        if edge=="LEFT" then b:SetPoint("LEFT",f,"LEFT",-13,0)
        elseif edge=="RIGHT" then b:SetPoint("RIGHT",f,"RIGHT",13,0)
        elseif edge=="TOP" then b:SetPoint("TOP",f,"TOP",0,9)
        else b:SetPoint("BOTTOM",f,"BOTTOM",0,-9) end
        b:SetScript("OnEnter",function()
            if GameTooltip then
                GameTooltip:SetOwner(b,"ANCHOR_TOP")
                GameTooltip:SetText("Add a full-height or full-width panel to this GROUP's "..edge:lower().." edge")
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        f.outerButtons[edge]=b
    end
    f:SetScript("OnSizeChanged",function(self)
        if self._drawing then return end
        LayoutGroup(g,self)
    end)
    return f
end
RenderAll = function()
    if not Canvas then return end
    ReplaceArtTargets()
    if Picker then Picker:Hide() end
    if ShowSnapCandidate then ShowSnapCandidate(nil) end
    for _,g in ipairs(groups) do
        if views[g.id] then DisableVisuals(g.tree) end
    end
    for _,f in pairs(views) do f:Hide();f:SetScript("OnSizeChanged",nil) end
    views={}
    for _,g in ipairs(groups) do
        ClampToCanvas(g)
        local f=NewGroupFrame(g)
        views[g.id]=f
        f._drawing=true
        f:SetSize(g.w,g.h)
        f:SetPoint("TOPLEFT",Canvas,"TOPLEFT",g.x,-g.y)
        BuildVisuals(g.tree,g,f)
        f._drawing=false
        LayoutGroup(g,f)
        f:Show()
    end
    if LibraryPanel and LibraryPanel.Refresh then LibraryPanel:Refresh() end
    FinalizeArtTargets()
    -- Refresh after a newly added widget has a real backing frame and size.
    if RefreshBodies then RefreshBodies() end
end

local function BuildLibrary(parent, compact)
    local panel=CreateFrame("Frame",nil,parent)
    local libraryBase=Paint(panel,"BACKGROUND",PALETTE.background)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(libraryBase,function(tex,t)
        local c=t.dataSurface;tex:SetColorTexture(c[1],c[2],c[3],1)
    end) end
    local heading=Label(panel, compact and "Choose a widget" or "Widget Library",16,PALETTE.gold)
    heading:SetPoint("TOPLEFT",panel,"TOPLEFT",12,-13)
    local close=Button(panel,"x",22,22,function() panel:Hide() end)
    close:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-8,-8)
    panel.title=heading
    local lines={}
    for i,key in ipairs(ORDER) do
        local entry=CreateFrame("Button",nil,panel)
        entry:SetSize(250,30)
        entry:SetPoint("TOPLEFT",panel,"TOPLEFT",12,-40-(i-1)*35)
        local entryBase=Paint(entry,"BACKGROUND",PALETTE.button)
        if UI.RegisterThemeTarget then UI:RegisterThemeTarget(entryBase,function(tex,t)
            local c=t.buttonFace;tex:SetColorTexture(c[1],c[2],c[3],.97)
        end) end
        local txt=Label(entry,"",12,PALETTE.light)
        txt:SetPoint("LEFT",entry,"LEFT",9,0)
        local hint=Label(entry,"",12,PALETTE.gold)
        hint:SetPoint("RIGHT",entry,"RIGHT",-8,0)
        entry:SetScript("OnClick",function()
            if not editing then StartEdit(true) end
            if InCombat() then Say("Not in combat.");return end
            if compact and selectedDock then
                local attached
                if selectedDock.mode=="group" then
                    attached=DockWidgetToGroup(selectedDock.groupId,selectedDock.edge,key)
                else
                    attached=DockWidget(selectedDock.groupId,selectedDock.widget,selectedDock.edge,key)
                end
                if attached then
                    panel:Hide()
                elseif not FindWidget(key) then
                    -- Never trap a player in a dead-end + menu. If the entire
                    -- dock group cannot fit, preserve their add as a floater.
                    local target=FindGroup(selectedDock.groupId)
                    local offsetX=target and (target.x+target.w+16) or 60
                    local offsetY=target and target.y or 55
                    MakeFloating(key,offsetX,offsetY)
                    panel:Hide()
                    Say("Attached space is full; added floating instead. Resize/rearrange to dock it.")
                end
            else
                MakeFloating(key,60+(#groups*22)%180,55+(#groups*19)%110)
                panel:Refresh()
            end
        end)
        lines[#lines+1]={key=key,entry=entry,text=txt,hint=hint}
    end
    function panel:Refresh()
        local t=UI.ThemeTokens and UI:ThemeTokens()
        for _,l in ipairs(lines) do
            local exists=FindWidget(l.key)~=nil
            l.entry:SetShown(l.key~="selffound" or AF:IsModuleEnabled("selfFound"))
            l.text:SetText(WIDGETS[l.key].title)
            l.hint:SetText(exists and "Added" or "+")
            l.entry:EnableMouse(not exists)
            if t then
                local text=ThemeLabelFor(t.buttonFace,t.buttonText)
                l.text:SetTextColor(unpack(text))
                l.text:SetAlpha(exists and .62 or 1)
                l.hint:SetTextColor(unpack(text))
            end
        end
    end
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(panel,function(_,t)
        heading:SetTextColor(unpack(ThemeLabelFor(t.dataSurface,t.accent2)))
        local buttonText=ThemeLabelFor(t.buttonFace,t.buttonText)
        for _,l in ipairs(lines) do
            l.text:SetTextColor(unpack(buttonText))
            l.hint:SetTextColor(unpack(buttonText))
        end
    end) end
    return panel
end
local function ResetLayout()
    if InCombat() then Say("Not during combat.");return end
    groups=DefaultGroups();nextId=2
    for _,g in ipairs(groups) do ClampToCanvas(g) end
    Store(true);RenderAll();Say("Default modular Overview arrangement restored; journal data unchanged.")
end
-- Presets are explicit actions, not an alternate storage system. The selected
-- docking tree simply replaces settings.overviewLayout.groups after confirmation.
local function ApplyOverviewPreset(id)
    if InCombat() then Say("Layout presets are unavailable during combat.");return false end
    if not Canvas then return false end
    local w,h=Canvas:GetSize()
    if w<100 or h<100 then Say("The Overview needs to finish sizing first.");return false end
    local newGroups,preset,reason=OverviewPresetGroups(id,w,h)
    if not newGroups then Say(reason or "This preset does not fit the Overview.");return false end
    if editing then StartEdit(false) end
    groups=newGroups;nextId=2
    for _,g in ipairs(groups) do ClampToCanvas(g) end
    Store(true)
    RenderAll()
    RefreshBodies()
    Say(preset.label.." layout applied and saved. Your journal records are unchanged.")
    return true
end
local function BuildPresetPanel(parent,button)
    local panel=CreateFrame("Frame",nil,parent)
    panel:SetSize(346,315)
    panel:SetPoint("TOPRIGHT",button,"BOTTOMRIGHT",0,-6)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(parent:GetFrameLevel()+70)
    panel:EnableMouse(true)
    local surface=Paint(panel,"BACKGROUND",PALETTE.background)
    local border={}
    for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local t=panel:CreateTexture(nil,"BORDER")
        if side=="TOP" then t:SetPoint("TOPLEFT",0,0);t:SetPoint("TOPRIGHT",0,0);t:SetHeight(2)
        elseif side=="BOTTOM" then t:SetPoint("BOTTOMLEFT",0,0);t:SetPoint("BOTTOMRIGHT",0,0);t:SetHeight(2)
        elseif side=="LEFT" then t:SetPoint("TOPLEFT",0,0);t:SetPoint("BOTTOMLEFT",0,0);t:SetWidth(2)
        else t:SetPoint("TOPRIGHT",0,0);t:SetPoint("BOTTOMRIGHT",0,0);t:SetWidth(2) end
        border[#border+1]=t
    end
    local heading=Label(panel,"LAYOUT PRESETS",14,PALETTE.gold)
    heading:SetPoint("TOPLEFT",panel,"TOPLEFT",12,-12)
    local close=Button(panel,"x",22,22,function()panel:Hide() end,12)
    close:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-8,-8)
    local description=Label(panel,"Choose a new arrangement. Your current layout will be replaced only after confirmation.",11,PALETTE.subdued)
    description:SetPoint("TOPLEFT",panel,"TOPLEFT",12,-38)
    description:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-12,-38)
    description:SetHeight(31);description:SetJustifyV("TOP")
    description:SetWordWrap(true)
    local entries={}
    for i,preset in ipairs(LAYOUT_PRESETS) do
        local entry=Button(panel,preset.label,320,34,function()
            panel.pending=preset.id
            panel.confirmLabel:SetText("Replace your current layout with "..preset.label.."? This won't change journal records.")
            panel.confirmArea:Show()
        end,12)
        entry:SetPoint("TOPLEFT",panel,"TOPLEFT",12,-77-(i-1)*43)
        entry:SetSize(320,36)
        local hint=Label(entry,preset.detail,10,PALETTE.subdued)
        hint:SetPoint("TOPLEFT",entry,"TOPLEFT",11,-23)
        hint:SetPoint("TOPRIGHT",entry,"TOPRIGHT",-9,-23)
        hint:SetHeight(11)
        entry.label:ClearAllPoints()
        entry.label:SetPoint("TOPLEFT",entry,"TOPLEFT",10,-3)
        entry.label:SetPoint("TOPRIGHT",entry,"TOPRIGHT",-10,-3)
        entry.label:SetHeight(17)
        entry.label:SetJustifyH("LEFT")
        entries[#entries+1]={frame=entry,hint=hint}
    end
    -- The preset entries remain parented to the panel; confirmation hides
    -- their actual buttons instead of moving them between frame parents.
    panel.confirmArea=CreateFrame("Frame",nil,panel)
    panel.confirmArea:SetAllPoints(panel)
    local confirmLabel=Label(panel.confirmArea,"",13,PALETTE.light)
    confirmLabel:SetPoint("TOPLEFT",panel.confirmArea,"TOPLEFT",14,-93)
    confirmLabel:SetPoint("TOPRIGHT",panel.confirmArea,"TOPRIGHT",-14,-93)
    confirmLabel:SetHeight(78)
    confirmLabel:SetWordWrap(true)
    panel.confirmLabel=confirmLabel
    local apply=Button(panel.confirmArea,"Apply Preset",148,29,function()
        if panel.pending and ApplyOverviewPreset(panel.pending) then
            panel:Hide()
        end
    end,12)
    apply:SetPoint("TOPLEFT",panel.confirmArea,"TOPLEFT",15,-194)
    local cancel=Button(panel.confirmArea,"Cancel",148,29,function()
        panel.pending=nil
        panel.confirmArea:Hide()
        for _,entry in ipairs(entries) do entry.frame:Show() end
    end,12)
    cancel:SetPoint("TOPRIGHT",panel.confirmArea,"TOPRIGHT",-15,-194)
    function panel:Open()
        self.pending=nil
        self.confirmArea:Hide()
        for _,entry in ipairs(entries) do entry.frame:Show() end
        self:Show()
    end
    panel.confirmArea:Hide()
    -- To avoid giving a child full-screen hitbox over the preset choices,
    -- show/hide the buttons themselves when toggling confirmation.
    panel.confirmArea:SetScript("OnShow",function()
        for _,entry in ipairs(entries) do entry.frame:Hide() end
    end)
    panel.confirmArea:SetScript("OnHide",function()
        for _,entry in ipairs(entries) do entry.frame:Show() end
    end)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(panel,function(_,t)
        local c=t.dataSurface
        surface:SetColorTexture(c[1],c[2],c[3],1)
        local edge=t.divider
        for _,v in ipairs(border) do v:SetColorTexture(edge[1],edge[2],edge[3],.9) end
        heading:SetTextColor(unpack(ThemeLabelFor(c,t.accent2)))
        local ink=ThemeLabelFor(c,t.dataText)
        description:SetTextColor(unpack(ink))
        confirmLabel:SetTextColor(unpack(ink))
        local buttonInk=ThemeLabelFor(t.buttonFace,t.buttonText)
        for _,entry in ipairs(entries) do entry.hint:SetTextColor(unpack(buttonInk)) end
    end) end
    panel:Hide()
    return panel
end
-- Live journal page, not a separate window. The original page remains unchanged
-- elsewhere so it can be reinstated in a one-line fallback if necessary.
function UI:BuildModularOverview(page)
    if not page or not AF.db then return end
    LabFrame=page
    local toolBar=CreateFrame("Frame",nil,page)
    toolBar:SetPoint("TOPLEFT",page,"TOPLEFT",8,-5)
    toolBar:SetPoint("TOPRIGHT",page,"TOPRIGHT",-8,-5)
    toolBar:SetHeight(48)
    local toolBarSurface=Paint(toolBar,"BACKGROUND",{0.12,0.10,0.08,0.96})
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(toolBarSurface,function(tex,t)
        tex:SetColorTexture(t.header[1],t.header[2],t.header[3],.98)
    end) end
    if UI.FoundryQuestBorder then UI:FoundryQuestBorder(toolBar,{cap=18,alpha=.32}) end
    local heading=Label(toolBar,"YOUR FOUNDRY",16,PALETTE.gold)
    heading:SetPoint("TOPLEFT",toolBar,"TOPLEFT",12,-8)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(heading,function(label,t)
        label:SetTextColor(unpack(ThemeLabelFor(t.header,t.accent)))
    end) end
    local help=Label(toolBar,"Click a widget title to open its tab. Edit to move, dock, resize, lock or hide.",11,PALETTE.subdued)
    help:SetPoint("TOPLEFT",toolBar,"TOPLEFT",12,-29)
    help:SetWidth(540)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(help,function(label,t)
        label:SetTextColor(unpack(ThemeLabelFor(t.header,t.muted)))
    end) end

    EditButton=Button(toolBar,"Edit Layout",100,24,function() StartEdit(not editing) end,11)
    EditButton:SetPoint("TOPRIGHT",toolBar,"TOPRIGHT",-8,-8)
    local widgets=Button(toolBar,"Widgets +",83,24,function()
        if not editing then StartEdit(true) end
        if LibraryPanel:IsShown() then LibraryPanel:Hide() else LibraryPanel:Refresh();LibraryPanel:Show() end
    end,11)
    widgets:SetPoint("RIGHT",EditButton,"LEFT",-6,0)
    ResetButton=Button(toolBar,"Reset",56,22,ResetLayout,11)
    ResetButton:SetPoint("RIGHT",widgets,"LEFT",-6,0)
    FitButton=Button(toolBar,"Fit Layout",80,22,FitLayoutToWindow,11)
    FitButton:SetPoint("RIGHT",ResetButton,"LEFT",-6,0)
    FitButton:Hide() -- shown only while editing
    SnapButton=Button(toolBar,"Snap: ON",81,22,function()
        snapEnabled=not snapEnabled
        ShowSnapCandidate(nil)
        Store();UpdateTitlebar()
        Say(snapEnabled and "Magnetic snapping ON" or "Magnetic snapping OFF; floating overlap enabled")
    end,11)
    SnapButton:SetPoint("RIGHT",FitButton,"LEFT",-6,0)
    local presetButton=Button(toolBar,"Presets",78,22,function()
        if InCombat() then Say("Layout presets are unavailable during combat.");return end
        if PresetPanel then
            if PresetPanel:IsShown() then PresetPanel:Hide() else PresetPanel:Open() end
        end
    end,11)
    presetButton:SetPoint("RIGHT",SnapButton,"LEFT",-6,0)
    local importButton=Button(toolBar,"Import Lab",86,22,function()
        if InCombat() then Say("Import unavailable in combat.");return end
        local saved=type(AFOverviewLabDB)=="table" and AFOverviewLabDB
        if not saved or type(saved.groups)~="table" then
            Say("No saved standalone Layout Lab groups found. Your Overview is unchanged.")
            return
        end
        nextId=1
        local imported=SanitizeGroups(saved.groups)
        if not imported then
            Say("Layout Lab arrangement invalid; nothing imported.")
            return
        end
        groups=imported
        snapEnabled=(saved.snapEnabled~=false)
        for _,g in ipairs(groups) do ClampToCanvas(g) end
        Store(true);RenderAll();UpdateTitlebar();RefreshBodies()
        Say("Imported Layout Lab arrangement. Gameplay records were not copied.")
    end,10)
    importButton:SetPoint("RIGHT",presetButton,"LEFT",-6,0)
    importButton:SetShown(AF.db and AF.db.settings and AF.db.settings.devMode == true
        and type(AFOverviewLabDB)=="table" and type(AFOverviewLabDB.groups)=="table")

    Canvas=CreateFrame("Frame",nil,page)
    Canvas:SetPoint("TOPLEFT",page,"TOPLEFT",10,-64)
    Canvas:SetPoint("BOTTOMRIGHT",page,"BOTTOMRIGHT",-10,25)
    Canvas:SetFrameLevel(page:GetFrameLevel()+2)
    local canvasBackground=Paint(Canvas,"BACKGROUND",{0.075,0.069,0.061,0.97})
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(canvasBackground,function(tex,t)
        local c=t.light and t.shell or t.surface
        tex:SetColorTexture(c[1],c[2],c[3],.99)
    end) end
    RegisterArtTarget("Pages.Overview.Background",canvasBackground)
    if UI.FoundryQuestBorder then UI:FoundryQuestBorder(Canvas,{cap=18,alpha=.37,outset=1}) end
    PublishArtTargets()
    SnapPreview=CreateFrame("Frame",nil,Canvas)
    SnapPreview:SetFrameLevel(Canvas:GetFrameLevel()+90)
    SnapPreview:EnableMouse(false)
    Paint(SnapPreview,"BACKGROUND",{0.20,0.65,0.45,0.38})
    SnapLabel=Label(SnapPreview,"Dock here",12,PALETTE.light,"CENTER")
    SnapLabel:SetPoint("CENTER",SnapPreview,"CENTER",0,0)
    SnapPreview:Hide()
    local footer=CreateFrame("Frame",nil,page)
    footer:SetPoint("BOTTOMLEFT",page,"BOTTOMLEFT",8,4)
    footer:SetPoint("BOTTOMRIGHT",page,"BOTTOMRIGHT",-8,4)
    footer:SetHeight(18)
    local footerBase=Paint(footer,"BACKGROUND",{0.11,0.09,0.08,0.90})
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(footerBase,function(tex,t)
        local c=t.bar;tex:SetColorTexture(c[1],c[2],c[3],.97)
    end) end
    Status=Label(footer,"Drag header = widget  |  M = move group  |  G+ = attach outer panel",11,PALETTE.gold)
    Status:SetPoint("LEFT",footer,"LEFT",6,0)
    if UI.RegisterThemeTarget then UI:RegisterThemeTarget(Status,function(label,t)
        label:SetTextColor(unpack(t.accent))
    end) end
    Status:SetWidth(690)
    LibraryPanel=BuildLibrary(page,false)
    LibraryPanel:SetSize(280,383)
    LibraryPanel:SetPoint("TOPRIGHT",page,"TOPRIGHT",-12,-67)
    LibraryPanel:SetFrameLevel(page:GetFrameLevel()+55)
    LibraryPanel:Hide()
    Picker=BuildLibrary(page,true)
    Picker:SetSize(280,383)
    Picker:SetPoint("CENTER",page,"CENTER",0,0)
    Picker:SetFrameLevel(page:GetFrameLevel()+65)
    Picker:Hide()
    PresetPanel=BuildPresetPanel(page,presetButton)

    local saved=Settings() or {}
    nextId=1
    snapEnabled=(saved.snapEnabled~=false)
    groups=SanitizeGroups(saved.groups) or DefaultGroups()
    if nextId==1 then nextId=2 end
    RefreshDataCache()
    RenderAll()
    UpdateTitlebar()
    Store()
    local function RelayoutExisting()
        if not Canvas or not Canvas:IsVisible() then return end
        local W,H=Canvas:GetSize()
        if W < 100 or H < 100 then return end
        for _,g in ipairs(groups) do
            ReflowResponsive(g,W,H)
            local f=views[g.id]
            if f then
                f:SetSize(g.w,g.h)
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT",Canvas,"TOPLEFT",g.x,-g.y)
                LayoutGroup(g,f)
            end
        end
    end
    Canvas:SetScript("OnSizeChanged",function() RelayoutExisting() end)
    -- Saved dimensions may be from a smaller or larger window. Apply the
    -- canonical relative geometry immediately, not only on a later resize.
    RelayoutExisting()
    page:SetScript("OnShow",function() RefreshBodies();RelayoutExisting() end)
    page:SetScript("OnHide",function()
        if editing then StartEdit(false) end
        if Picker then Picker:Hide() end
        if LibraryPanel then LibraryPanel:Hide() end
        if PresetPanel then PresetPanel:Hide() end
        if SnapPreview then SnapPreview:Hide() end
        Store()
    end)
    function page:Refresh() RefreshBodies() end
end

-- Optional Art Lab diagnostic.  Detect by the actual add-on name and avoid
-- calling into its private globals or assuming a particular Art Lab version.
SLASH_AFOVERVIEWART1="/afartbridge"
SlashCmdList.AFOVERVIEWART = function()
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    local ok,loaded = pcall(function() return isLoaded and isLoaded("AF_ForeverArtLab") end)
    local count = 0
    for _ in pairs(artTargets) do count=count+1 end
    Say("Art Lab "..((ok and loaded) and "loaded" or "not detected")..
        "; modular Overview exposes "..count.." live texture slots.")
    Say("Old Overview aliases: Left=Account Summary; Center=Pinned Goals; Right=Journal Notes.")
end

-- Emergency, non-destructive fallback for live testing: keep the original
-- three-column implementation available without reinstalling files.
SLASH_AFMODULAROVERVIEW1="/aflegacyoverview"
SlashCmdList.AFMODULAROVERVIEW=function()
    local settings=AF.db and AF.db.settings
    if not settings then return end
    settings.legacyOverview=not settings.legacyOverview
    if AF.Print then AF.Print(settings.legacyOverview and
        "Original Overview enabled. Type /reload to apply." or
        "Modular Overview enabled. Type /reload to apply.") end
end

-- Pure, read-only summaries for developer checks; no saved state is changed.
function UI:GetOverviewWidgetPulseInfo(id)
    if not WIDGETS[id] then return nil end
    return WidgetPulse(id)
end
function UI:GetOverviewLayoutPresetInfo(id,w,h)
    local planned,preset,err=OverviewPresetGroups(id,w or 1200,h or 720)
    if not preset then return nil,err end
    local names={}
    local function visit(n)
        if n.widget then names[#names+1]=n.widget;return end
        visit(n.a);visit(n.b)
    end
    if planned and planned[1] then visit(planned[1].tree) end
    return {name=preset.label,widgets=names,fits=planned~=nil,reason=err}
end
function UI:GetOverviewLayoutPresetNames()
    local out={}
    for _,preset in ipairs(LAYOUT_PRESETS) do out[#out+1]=preset.label end
    return out
end
