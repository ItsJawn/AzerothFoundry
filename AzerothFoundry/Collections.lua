-- Azeroth Foundry: Collections discovery registry v0.4.4.2.3.
-- Display of catalog information does NOT constitute personal discovery.
local _, AF = ...
local CATEGORIES = { mounts = true, pets = true, toys = true, transmog = true }
local function Safe(fn, ...)
    if type(fn) ~= 'function' then return nil end
    local ok, a,b,c,d,e,f,g,h,i,j,k,l,m = pcall(fn,...)
    if ok then return a,b,c,d,e,f,g,h,i,j,k,l,m end
end
local function Now() return type(time)=='function' and time() or 0 end
local function K(cat,id) return tostring(cat)..':'..tostring(id) end
local function ItemID(link)
    if type(link)~='string' then return nil end
    return tonumber(link:match('item:(%d+)'))
end
local function AnyStr(s) return type(s)=='string' and s~='' and s or nil end
local function ToyOwned(itemID)
    itemID=tonumber(itemID)
    if not itemID or itemID<=0 then return false end
    -- Forever exposes the normal global ownership check, not necessarily a
    -- C_ToyBox.HasToy method (which is absent in documented 1.60.1 APIs).
    if type(PlayerHasToy)=='function' and Safe(PlayerHasToy,itemID)==true then return true end
    return C_ToyBox and Safe(C_ToyBox.HasToy,itemID)==true or false
end
local function ToyTooltipData(itemID)
    if not C_TooltipInfo or type(C_TooltipInfo.GetToyByItemID)~='function' then return nil end
    local data=Safe(C_TooltipInfo.GetToyByItemID,itemID)
    if type(data)~='table' then return nil end
    local kind=Enum and Enum.TooltipDataType and Enum.TooltipDataType.Toy or 19
    if tonumber(data.type)==tonumber(kind) then return data end
end
local function NativeToySource(itemID)
    local tooltip=ToyTooltipData(itemID)
    if not tooltip or type(tooltip.lines)~='table' then return nil end
    local sourceType=Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ToySource or 29
    for _,line in ipairs(tooltip.lines) do
        if type(line)=='table' and tonumber(line.type)==tonumber(sourceType) then
            local text=AnyStr(line.leftText) or AnyStr(line.rightText)
            if text then return text end
        end
    end
end
-- IMPORTANT: A cached item name or generic toy-shaped tooltip is not proof
-- of toy classification. Forever can echo ANY itemID through GetToyInfo and
-- C_TooltipInfo.GetToyByItemID can return a blank shell for an ordinary item.
-- Only a native Toy Box index, an actual toy link, confirmed ownership, or an
-- independently checked Forever toy itemID may establish this category.
-- Keep this tiny explicit exception for a Forever collector-edition toy when
-- the native Toy Box is empty. This only VALIDATES an item actually observed;
-- it never makes the item appear in the discovery list on its own.
local VERIFIED_FOREVER_TOY_ITEMS = { [280740] = true } -- Shen'dorei Windwell
local nativeToyIDs = {}
local verifiedToyIDs = {}
local function IsVerifiedToy(itemID)
    itemID=tonumber(itemID)
    if not itemID or itemID<=0 then return false end
    if VERIFIED_FOREVER_TOY_ITEMS[itemID] or nativeToyIDs[itemID] then return true end
    if ToyOwned(itemID) then verifiedToyIDs[itemID]=true;return true end
    if verifiedToyIDs[itemID] then return true end
    -- GetToyLink's documented result is nil for non-toys. The link must
    -- identify THIS item rather than merely being a nonempty generic string.
    local link=C_ToyBox and Safe(C_ToyBox.GetToyLink,itemID)
    if ItemID(link)==itemID then verifiedToyIDs[itemID]=true;return true end
    return false -- never trust GetToyInfo or a tooltip shell by itself
end
local function ToyItemInfo(itemID)
    itemID=tonumber(itemID)
    if not IsVerifiedToy(itemID) then return nil end
    local id,name,icon
    if C_ToyBox then id,name,icon=Safe(C_ToyBox.GetToyInfo,itemID) end
    if tonumber(id)==itemID then return name,icon,NativeToySource(itemID),true end
    local itemName=type(GetItemInfo)=='function' and Safe(GetItemInfo,itemID) or nil
    local itemIcon=type(GetItemIcon)=='function' and Safe(GetItemIcon,itemID) or nil
    return itemName,itemIcon,NativeToySource(itemID),true
end

-- Pet species lookup can be missing from the filtered beta journal even when
-- GetPetInfoByItemID still knows the species of a vendor's companion item.
-- The documented 12th return is creatureDisplayID; the 13th is speciesID.
local function PetFromItem(itemID)
    if not C_PetJournal then return nil end
    local name,icon,_,creatureID,source,description,_,_,_,_,_,displayID,speciesID=
        Safe(C_PetJournal.GetPetInfoByItemID,itemID)
    return tonumber(speciesID), AnyStr(name), icon, tonumber(displayID), tonumber(creatureID), source, description
end
local function PetFromSpecies(speciesID)
    if not C_PetJournal then return nil end
    local name,icon,_,creatureID,source,description,_,_,_,_,_,displayID=
        Safe(C_PetJournal.GetPetInfoBySpeciesID,speciesID)
    return AnyStr(name),icon,tonumber(displayID),tonumber(creatureID),source,description
end
local function KnownPetInfo(rec)
    if type(rec)~='table' or rec.category~='pets' then return end
    -- Repair observations saved by v0.4.4.2.7 without rescanning their vendors.
    local speciesName,speciesIcon,speciesDisplay,speciesCreature,source,description=PetFromSpecies(rec.id)
    if speciesName then rec.name=speciesName end
    if speciesIcon then rec.icon=speciesIcon end
    if speciesDisplay and speciesDisplay>0 then rec.displayID=speciesDisplay end
    if speciesCreature and speciesCreature>0 then rec.creatureID=speciesCreature end
    if AnyStr(source) then rec.source=source end
    if AnyStr(description) then rec.description=description end
    if type(rec.sources)=='table' then
        for _,observed in pairs(rec.sources) do
            if type(observed)=='table' and observed.kind=='vendor' and tonumber(observed.itemID) then
                local id,name,icon,display,creature,itemSource,itemDescription=PetFromItem(observed.itemID)
                if id == tonumber(rec.id) then
                    if name then rec.name=name end
                    if icon then rec.icon=icon end
                    if display and display>0 then rec.displayID=display end
                    if creature and creature>0 then rec.creatureID=creature end
                    if AnyStr(itemSource) then rec.source=itemSource end
                    if AnyStr(itemDescription) then rec.description=itemDescription end
                end
                -- Native merchant item names/icons are still useful when the
                -- Forever beta omits the descriptive pet-journal fields.
                if not AnyStr(rec.name) and type(GetItemInfo)=='function' then
                    rec.name=AnyStr(Safe(GetItemInfo,observed.itemID))
                end
                if not rec.icon and type(GetItemIcon)=='function' then
                    rec.icon=Safe(GetItemIcon,observed.itemID)
                end
            end
        end
    end
end
-- A client's hidden flag can include faction/character restrictions. It is not
-- proof of unreleased content. Remove a hidden catalog-only mount only when
-- neither native acquisition metadata nor a personal encounter is available.
-- Public acquisition references: never write these to the Discovery Registry.
-- Sparse, curated entries only; absence does NOT mean a collectible is unobtainable.
-- Their acquisition requirements may change in Forever, so they are explicitly
-- historical/unverified unless the client or player's own observations agree.
local PUBLIC_SOURCE_REFERENCES = {
    mounts = {
        [82] = {
            label = 'Horn of the Black War Wolf (item #18245)',
            itemID = 18245,
            source = 'Historical reference: PvP mount vendor; Rank 11 requirement reported',
            note = 'Exact Forever vendor and eligibility not confirmed by Foundry.',
            url = 'https://www.wowhead.com/forever/item=18245',
        },
        [18] = {
            label = 'Chestnut Mare Bridle (item #5655)',
            itemID = 5655,
            source = 'Forever item reference: horse vendor Katie Hunter at Eastvale Logging Camp, Elwynn Forest.',
            note = 'Vendor stock, eligibility and price must be verified in-game. This reference is not a personal discovery.',
            url = 'https://www.wowhead.com/forever/item=5655',
        },
    },
}
function AF:GetCollectionSourceReference(category, id)
    local refs = PUBLIC_SOURCE_REFERENCES[category]
    return refs and refs[tonumber(id)] or nil
end

local function MeaningfulSourceText(source)
    return type(source)=='string' and source:match('%S') ~= nil
end
function AF:ShouldShowCollectionEntry(entry)
    if type(entry)~='table' then return false end
    if entry.category~='mounts' or not entry.clientHidden then return true end
    if entry.owned or self:CollectionDiscovery('mounts',entry.id) then return true end
    local category=tonumber(entry.sourceType)
    if category and category>0 then return true end
    return MeaningfulSourceText(entry.source)
end

-- Use the character's actual class by default. Prior versions stored a single
-- account-wide class picker value; that incorrectly followed players onto alts.
-- A specific class or All Classes can still be selected per character.
local CLASS_IDS={WARRIOR=1,PALADIN=2,HUNTER=3,ROGUE=4,PRIEST=5,SHAMAN=7,MAGE=8,WARLOCK=9,DRUID=11,DEATHKNIGHT=6,MONK=10,DEMONHUNTER=12,EVOKER=13}
local function PlayerClassID()
    if type(UnitClass)~='function' then return nil end
    local _,token,id=Safe(UnitClass,'player')
    return tonumber(id) or CLASS_IDS[token]
end
function AF:GetCollectionTransmogClassChoice()
    local settings=self.db and self.db.collections and self.db.collections.settings
    local perCharacter=settings and settings.transmogClassByCharacter
    local key=self.GetCurrentKey and self:GetCurrentKey() or nil
    local chosen=key and type(perCharacter)=='table' and perCharacter[key]
    if type(chosen)=='number' and chosen>=0 then return chosen end
    return PlayerClassID()
end
function AF:SetCollectionTransmogClassChoice(classID)
    local settings=self.db and self.db.collections and self.db.collections.settings
    if not settings or type(classID)~='number' or classID<0 then return end
    settings.transmogClassByCharacter=type(settings.transmogClassByCharacter)=='table' and settings.transmogClassByCharacter or {}
    local key=self.GetCurrentKey and self:GetCurrentKey() or nil
    if key then settings.transmogClassByCharacter[key]=classID end
end

function AF:InitializeCollections()
    if not self.db then return end
    local c=self.db.collections
    if type(c)~='table' then c={} end
    self.db.collections=c
    c.discoveries=type(c.discoveries)=='table' and c.discoveries or {}
    c.vendorObservations=type(c.vendorObservations)=='table' and c.vendorObservations or {}
    c.modelPoses=type(c.modelPoses)=='table' and c.modelPoses or {}
    c.settings=type(c.settings)=='table' and c.settings or {}
    c.settings.category=CATEGORIES[c.settings.category] and c.settings.category or 'mounts'
    -- Never migrate a previous test flag into Reveal All. Deliberate confirmation is required.
    if c.settings.visibility~='collected' and c.settings.visibility~='discovered' then c.settings.visibility='discovered' end
    c.settings.revealAll=false
    c.settings.transmogClassByCharacter=type(c.settings.transmogClassByCharacter)=='table' and c.settings.transmogClassByCharacter or {}
    -- Retire legacy account-wide class selection; new selections belong to each alt.
    c.settings.transmogClassID=nil
end
function AF:CollectionsStore() return self.db and self.db.collections end
function AF:CollectionDiscovery(cat,id)
    local c=self:CollectionsStore()
    local rec=c and c.discoveries[K(cat,id)]
    -- v1.0.8-v1.0.11 may have stored ordinary vendor/bag items as toys.
    -- Quarantine is VIEW-ONLY: don't delete or rewrite old observations.
    -- A record automatically becomes visible again if valid toy evidence
    -- becomes available, preserving its original vendor, price and timestamps.
    if cat=='toys' and rec and not IsVerifiedToy(id) then return nil end
    return rec
end
function AF:GetToyDiscoveryAudit()
    local c=self:CollectionsStore()
    local recognized,unverified=0,0
    for _,rec in pairs(c and c.discoveries or {}) do
        if type(rec)=='table' and rec.category=='toys' then
            if IsVerifiedToy(rec.id) then recognized=recognized+1
            else unverified=unverified+1 end
        end
    end
    return recognized,unverified
end
function AF:ObserveCollectible(cat,id,observation)
    if not CATEGORIES[cat] or type(id)~='number' or id<=0 or not self:CollectionsStore() then return end
    local c=self.db.collections
    local key=K(cat,id)
    local rec=c.discoveries[key]
    if type(rec)~='table' then rec={category=cat,id=id,firstSeen=Now(),sources={}};c.discoveries[key]=rec end
    rec.lastSeen=Now()
    if type(rec.sources)~='table' then rec.sources={} end
    local s=observation or {}
    if s.kind == 'vendor' and s.itemID then
        local sourceKey = tostring(s.npcGUID or s.npcName or 'unknown') .. ':' .. tostring(s.itemID)
        local src = rec.sources[sourceKey] or {firstSeen=Now()}
        src.kind='vendor';src.itemID=s.itemID;src.npcName=AnyStr(s.npcName) or 'Unidentified merchant'
        src.mapID=tonumber(s.mapID);src.x=tonumber(s.x);src.y=tonumber(s.y)
        src.price=tonumber(s.price);src.quantity=tonumber(s.quantity)
        src.lastSeen=Now();src.observer=self.GetCurrentKey and self:GetCurrentKey() or nil
        rec.sources[sourceKey]=src
        rec.lastSourceKey=sourceKey
    end
    return rec
end
-- Recovery path for Forever clients whose native Toy Box catalog returns zero.
-- Only inventory-held items and positively verified ownership are recorded.
-- A filtered native catalog is never treated as proof of discovery.
function AF:GetNativeToySource(itemID) return NativeToySource(itemID) end
function AF:ObserveOwnedToyItem(itemID,reason)
    itemID=tonumber(itemID)
    local name,icon,source,valid=ToyItemInfo(itemID)
    if not valid then return false,'The client does not identify this item as a toy' end
    if reason=='manual' and not ToyOwned(itemID) then
        return false,'This item is not reported as learned in the Toy Box'
    end
    local old=self:CollectionDiscovery('toys',itemID)
    local rec=self:ObserveCollectible('toys',itemID)
    if not rec then return false,'Collection registry is unavailable' end
    rec.name=AnyStr(name) or rec.name or (type(GetItemInfo)=='function' and Safe(GetItemInfo,itemID))
    rec.icon=icon or rec.icon or (type(GetItemIcon)=='function' and Safe(GetItemIcon,itemID))
    if AnyStr(source) then rec.source=source end
    if type(rec.sources)~='table' then rec.sources={} end
    if reason=='inventory' then
        local key='inventory:'..tostring(self.GetCurrentKey and self:GetCurrentKey() or 'current')
        local observed=rec.sources[key] or {firstSeen=Now()}
        observed.kind='inventory';observed.itemID=itemID;observed.lastSeen=Now()
        rec.sources[key]=observed
        rec.lastSourceKey=key
    end
    return true,old==nil and 'Toy added to discoveries' or 'Toy discovery refreshed'
end
function AF:ScanCarriedToys()
    if not self:CollectionsStore() then return 0 end
    local cc=C_Container
    local getSlots=cc and cc.GetContainerNumSlots or GetContainerNumSlots
    local getID=cc and cc.GetContainerItemID or GetContainerItemID
    if type(getSlots)~='function' or type(getID)~='function' then return 0 end
    local bags={0,1,2,3,4}
    local reagent=Enum and Enum.BagIndex and tonumber(Enum.BagIndex.ReagentBag)
    if reagent and reagent>=0 and reagent~=0 and reagent~=1 and reagent~=2
        and reagent~=3 and reagent~=4 then bags[#bags+1]=reagent end
    local newCount=0
    local seen={}
    self._toyNegativeInventoryCache=self._toyNegativeInventoryCache or {}
    local rejected=self._toyNegativeInventoryCache
    local clock=type(GetTime)=='function' and GetTime() or Now()
    for _,bag in ipairs(bags) do
        local count=math.min(math.max(tonumber(Safe(getSlots,bag)) or 0,0),80)
        for slot=1,count do
            local itemID=tonumber(Safe(getID,bag,slot))
            if itemID and itemID>0 and not seen[itemID] then
                seen[itemID]=true
                local was=self:CollectionDiscovery('toys',itemID)
                if not was and (not rejected[itemID] or clock-rejected[itemID]>=30 or ToyOwned(itemID)) then
                    local ok=self:ObserveOwnedToyItem(itemID,'inventory')
                    if ok then newCount=newCount+1;rejected[itemID]=nil
                    else rejected[itemID]=clock end
                end
            end
        end
    end
    return newCount
end
function AF:CollectionModelPose(cat,id)
    local c=self:CollectionsStore()
    if not c then return {facing=45,scale=1,paused=true} end
    local key=K(cat,id)
    local p=c.modelPoses[key]
    if type(p)~='table' then p={facing=45,scale=1,paused=true};c.modelPoses[key]=p end
    p.facing=math.max(0,math.min(359,tonumber(p.facing) or 45))
    p.scale=math.max(0.35,math.min(2.5,tonumber(p.scale) or 1))
    p.iconOnly=(p.iconOnly==true) -- visual fallback, independent of discovery status
    return p
end

-- The native API catalog is volatile and filtered; we never persist an undiscovered
-- entry simply because the player used the Reveal All control.
function AF:GetCollectionCatalog(cat)
    local result,seen={},{}
    local function add(entry)
        if type(entry)~='table' or type(entry.id)~='number' or entry.id<=0 then return end
        if seen[entry.id] then
            if entry.owned then seen[entry.id].owned=true end
            return
        end
        entry.category=cat
        entry.owned=entry.owned and true or false
        entry.name=AnyStr(entry.name) or (cat..' #'..entry.id)
        result[#result+1]=entry;seen[entry.id]=entry
    end
    if cat=='mounts' and C_MountJournal then
        local ids=Safe(C_MountJournal.GetMountIDs)
        if type(ids)=='table' then
            for i=1,math.min(#ids,8000) do
                local id=tonumber(ids[i])
                if id then
                    local name,spell,icon,_,usable,sourceType,_,_,_,shouldHide,owned=Safe(C_MountJournal.GetMountInfoByID,id)
                    if name then
                        local display,description,source,_,_,scene,anim=Safe(C_MountJournal.GetMountInfoExtraByID,id)
                        -- A mount ID in the beta catalog is not proof of availability.
                        -- Preserve native metadata without treating it as a personal discovery.
                        if (type(icon)~='number' or icon<=0) and spell and type(GetSpellTexture)=='function' then
                            icon=Safe(GetSpellTexture,spell)
                        end
                        add({id=id,name=name,icon=icon,owned=owned,spellID=spell,
                            displayID=display,sceneID=scene,animationID=anim,source=source,description=description,
                            sourceType=sourceType,clientHidden=shouldHide and true or false,
                            availabilityStatus=(shouldHide and 'CLIENT_HIDDEN_SOURCE_UNVERIFIED')
                                or ((not source or source=='') and 'SOURCE_NOT_PROVIDED')
                                or 'CLIENT_REFERENCE_ONLY',
                            usable=usable and true or false})
                    end
                end
            end
        end
    elseif cat=='pets' and C_PetJournal then
        -- Forever starts with Collected, Not Collected, Battle Pets and
        -- Non-Combat Pets filters disabled. Reading GetNumPets in that state
        -- returns only the tiny filtered/owned subset. Reveal All must widen
        -- the *native* journal filters temporarily, not just Foundry's UI.
        -- Snapshot and restore every supported state; never persist an
        -- undiscovered journal reference as a personal discovery.
        local pj=C_PetJournal
        local settings=self:CollectionsStore() and self:CollectionsStore().settings
        local reveal=settings and settings.revealAll==true
        local originalCount=tonumber((Safe(pj.GetNumPets))) or 0
        local restorations={}
        local changed=0
        local function EnableTemporarily(getter,setter,index)
            if type(index)~='number' or type(getter)~='function' or type(setter)~='function' then return end
            local was=Safe(getter,index)
            if type(was)~='boolean' or was then return end
            if pcall(setter,index,true) then
                restorations[#restorations+1]={fn=setter,index=index,previous=was}
                changed=changed+1
            end
        end
        if reveal then
            -- Call separately so a missing constant in another beta build
            -- never truncates an ipairs list and skips later available flags.
            EnableTemporarily(pj.IsFilterChecked,pj.SetFilterChecked,LE_PET_JOURNAL_FILTER_COLLECTED)
            EnableTemporarily(pj.IsFilterChecked,pj.SetFilterChecked,LE_PET_JOURNAL_FILTER_NOT_COLLECTED)
            EnableTemporarily(pj.IsFilterChecked,pj.SetFilterChecked,LE_PET_JOURNAL_FILTER_TYPE_BATTLE_PETS)
            EnableTemporarily(pj.IsFilterChecked,pj.SetFilterChecked,LE_PET_JOURNAL_FILTER_TYPE_NON_COMBAT_PETS)
            -- Respect the user's Pet Journal source/type filters once our
            -- reference-only scan finishes. The non-combat flag above is
            -- separate from the per-family pet-type checkboxes.
            if type(pj.GetNumPetSources)=='function' and type(pj.IsPetSourceChecked)=='function'
                and type(pj.SetPetSourceChecked)=='function' then
                local n=math.min(tonumber((Safe(pj.GetNumPetSources))) or 0,64)
                for i=1,n do EnableTemporarily(pj.IsPetSourceChecked,pj.SetPetSourceChecked,i) end
            end
            if type(pj.GetNumPetTypes)=='function' and type(pj.IsPetTypeChecked)=='function'
                and type(pj.SetPetTypeFilter)=='function' then
                local n=math.min(tonumber((Safe(pj.GetNumPetTypes))) or 0,32)
                for i=1,n do EnableTemporarily(pj.IsPetTypeChecked,pj.SetPetTypeFilter,i) end
            end
        end
        local expandedCount=0
        -- Perform the entire query inside a protected call so filters are
        -- restored even if a particular beta API unexpectedly throws.
        local ok,err=pcall(function()
            local count=math.min(tonumber((Safe(pj.GetNumPets))) or 0,8000)
            for i=1,count do
                local petID,id,owned,_,_,_,_,name,icon,_,_,source,description=Safe(pj.GetPetInfoByIndex,i)
                id=tonumber(id)
                if id then
                    local speciesName,speciesIcon,displayID,creatureID,speciesSource,speciesDescription=PetFromSpecies(id)
                    add({id=id,name=AnyStr(name) or speciesName,icon=icon or speciesIcon,owned=owned,
                        source=source or speciesSource,description=description or speciesDescription,
                        displayID=displayID,creatureID=creatureID})
                    expandedCount=expandedCount+1
                end
            end
        end)
        for i=#restorations,1,-1 do
            local r=restorations[i]
            pcall(r.fn,r.index,r.previous)
        end
        self.collectionPetCatalogDiagnostics={
            before=originalCount,native=expandedCount,filtersExpanded=changed,
            reveal=reveal,error=not ok and tostring(err) or nil,
        }
    elseif cat=='toys' and C_ToyBox then
        -- GetToyFromIndex enumerates only the *filtered* Toy Box. The Forever
        -- client may initially exclude uncollected toys, source groups or
        -- expansions. Reveal All is reference-only: temporarily widen native
        -- filters, collect the available entries, then restore every setting.
        -- Do not change the native Toy Box at all in spoiler-free views.
        local tb=C_ToyBox
        local settings=self:CollectionsStore() and self:CollectionsStore().settings
        local reveal=settings and settings.revealAll==true
        local originalCount=tonumber(Safe(tb.GetNumFilteredToys)) or 0
        local originalTotal=tonumber(Safe(tb.GetNumToys))
        local restorations,changed={},0
        local function SetTemporarily(getter,setter,wanted,index)
            if type(getter)~='function' or type(setter)~='function' then return end
            local was
            if type(index)=='number' then was=Safe(getter,index) else was=Safe(getter) end
            if was==nil or type(was)~=type(wanted) or was==wanted then return end
            local ok
            if type(index)=='number' then ok=pcall(setter,index,wanted)
            else ok=pcall(setter,wanted) end
            if ok then
                restorations[#restorations+1]={fn=setter,index=index,previous=was}
                changed=changed+1
            end
        end
        if reveal then
            SetTemporarily(tb.GetCollectedShown,tb.SetCollectedShown,true)
            SetTemporarily(tb.GetUncollectedShown,tb.SetUncollectedShown,true)
            SetTemporarily(tb.GetUnusableShown,tb.SetUnusableShown,true)
            -- These setters may not exist in every Forever beta build. When
            -- supported, the matching getter ensures we can restore the state.
            local sourceCount=C_PetJournal and tonumber(Safe(C_PetJournal.GetNumPetSources)) or 0
            sourceCount=math.min(math.max(sourceCount or 0,0),64)
            local validSource=C_ToyBoxInfo and C_ToyBoxInfo.IsToySourceValid
            -- Some Forever builds omit GetNumPetSources but still expose the
            -- Toy Box's per-source validity check. Probe just those valid IDs.
            if sourceCount==0 and type(validSource)=='function' then sourceCount=64 end
            for i=1,sourceCount do
                if type(validSource)~='function' or Safe(validSource,i)==true then
                    SetTemporarily(tb.IsSourceTypeFilterChecked,tb.SetSourceTypeFilter,true,i)
                end
            end
            local expansionCount=tonumber(Safe(GetNumExpansions)) or 0
            expansionCount=math.min(math.max(expansionCount,0),32)
            for i=1,expansionCount do
                SetTemporarily(tb.IsExpansionTypeFilterChecked,tb.SetExpansionTypeFilter,true,i)
            end
            -- Avoid changing an unknown search filter unless both accessors
            -- exist, so no user preference is lost by an interrupted scan.
            SetTemporarily(tb.GetFilterString,tb.SetFilterString,'')
            Safe(tb.ForceToyRefilter)
        end
        local nativeCount=0
        local ok,err=pcall(function()
            local count=math.min(tonumber(Safe(tb.GetNumFilteredToys)) or 0,8000)
            for i=1,count do
                local id=tonumber(Safe(tb.GetToyFromIndex,i))
                if id and id>0 then
                    nativeToyIDs[id]=true -- verified by the native filtered Toy Box index
                    local _,name,icon=Safe(tb.GetToyInfo,id)
                    local owned=ToyOwned(id)
                    add({id=id,name=name,icon=icon,owned=owned})
                    nativeCount=nativeCount+1
                end
            end
        end)
        for i=#restorations,1,-1 do
            local r=restorations[i]
            if type(r.index)=='number' then pcall(r.fn,r.index,r.previous)
            else pcall(r.fn,r.previous) end
        end
        if reveal then Safe(tb.ForceToyRefilter) end
        self.collectionToyCatalogDiagnostics={
            before=originalCount,native=nativeCount,total=originalTotal,
            filtersExpanded=changed,reveal=reveal,error=not ok and tostring(err) or nil,
        }
    elseif cat=='transmog' and C_TransmogCollection then
        -- The wardrobe API enumerates one equipment category at a time.
        -- 0 = all categories, -1 = all armor categories, 1..29 = one slot.
        -- Use the native uiOrder for Game Order; names are resolved lazily in
        -- the UI so browsing never synchronously resolves thousands of items.
        local selection=tonumber(self.db.collections.settings.transmogCategory) or 1
        if selection~=-1 and (selection<0 or selection>29) then selection=1 end
        local categories={}
        if selection==0 or selection==-1 then
            for id=1,(selection==-1 and 11 or 29) do categories[#categories+1]=id end
        else
            categories[1]=selection
        end
        local chosen=self:GetCollectionTransmogClassChoice()
        -- A multi-slot view would otherwise re-enumerate every category on
        -- each search keystroke. Keep a session-only, time-limited base cache;
        -- never persist catalog references or treat them as discoveries.
        local cacheKey=tostring(selection)..':'..tostring(chosen)
        local now=type(GetTime)=='function' and GetTime() or 0
        self._transmogBaseCatalogCache=self._transmogBaseCatalogCache or {}
        local memo=self._transmogBaseCatalogCache[cacheKey]
        local fresh=memo and (now==0 or (now>=memo.time and now-memo.time<90))
        if fresh then
            for _,entry in ipairs(memo.entries) do
                add({id=entry.id,name=entry.name,owned=entry.owned,
                    categoryID=entry.categoryID,uiOrder=entry.uiOrder,icon=entry.icon})
            end
            self.collectionClassDiagnostics=memo.diagnostics
        else
            local getFilter=C_TransmogCollection.GetClassFilter
            local setFilter=C_TransmogCollection.SetClassFilter
            local listFn=C_TransmogCollection.GetCategoryAppearances
            local original=Safe(getFilter)
            local canSet=type(getFilter)=='function' and type(setFilter)=='function' and type(original)=='number'
            local classSourceFn=C_TransmogCollection.GetValidAppearanceSourcesForClass
            local explicitClass=(type(chosen)=='number' and chosen>0 and type(classSourceFn)=='function')
            local checked,matched=0,0
            self.collectionClassEligibilityCache=self.collectionClassEligibilityCache or {}
            local function ValidForChosenClass(visualID,category)
                if not explicitClass then return true end
                checked=checked+1
                local categoryCache=self.collectionClassEligibilityCache[category]
                if not categoryCache then categoryCache={};self.collectionClassEligibilityCache[category]=categoryCache end
                local classCache=categoryCache[chosen]
                if not classCache then classCache={};categoryCache[chosen]=classCache end
                local known=classCache[visualID]
                if known~=nil then
                    if known then matched=matched+1 end
                    return known
                end
                local ok,sources=pcall(classSourceFn,visualID,chosen,category)
                if not ok then ok,sources=pcall(classSourceFn,visualID,chosen) end
                if not ok then return true end -- Never hide on unsupported APIs.
                local valid=type(sources)=='table' and #sources>0
                classCache[visualID]=valid
                if valid then matched=matched+1 end
                return valid
            end
            local function accumulate(rows,category)
                if type(rows)~='table' then return end
                for i=1,math.min(#rows,3500) do
                    local v=rows[i]
                    if type(v)=='table' then
                        local id=tonumber(v.visualID)
                        if id and (chosen==0 or ValidForChosenClass(id,category)) then
                            add({id=id,name='Appearance #'..id,owned=v.isCollected,
                                categoryID=category,uiOrder=tonumber(v.uiOrder) or i,
                                icon='Interface\\Icons\\INV_Misc_QuestionMark'})
                        end
                    end
                end
            end
            local classIDs={}
            if canSet and chosen==0 then
                local known={}
                local function addClass(id)
                    id=tonumber(id)
                    if id and id>0 and not known[id] then known[id]=true;classIDs[#classIDs+1]=id end
                end
                local count=tonumber(Safe(GetNumClasses)) or 0
                if type(GetClassInfo)=='function' then
                    for i=1,math.min(20,count) do
                        local name,_,id=Safe(GetClassInfo,i)
                        if type(name)=='string' then addClass(id) end
                    end
                end
                if #classIDs==0 and C_CreatureInfo and type(C_CreatureInfo.GetClassInfo)=='function' then
                    for id=1,13 do
                        local info=Safe(C_CreatureInfo.GetClassInfo,id)
                        if type(info)=='table' and type(info.className)=='string' then addClass(id) end
                    end
                end
                if #classIDs==0 then for _,id in ipairs({1,2,3,4,5,7,8,9,11}) do addClass(id) end end
            end
            for _,category in ipairs(categories) do
                if canSet and chosen==0 then
                    accumulate(Safe(listFn,category),category)
                    for _,id in ipairs(classIDs) do
                        if pcall(setFilter,id) then accumulate(Safe(listFn,category),category) end
                    end
                elseif canSet and type(chosen)=='number' and chosen>0 then
                    pcall(setFilter,chosen)
                    accumulate(Safe(listFn,category),category)
                else
                    accumulate(Safe(listFn,category),category)
                end
            end
            if canSet then pcall(setFilter,original) end
            local diagnostics={selected=chosen,scanned=checked,valid=matched,
                method=explicitClass and 'GetValidAppearanceSourcesForClass' or
                    (chosen==0 and 'per-class catalog union' or 'native-only'),
                nativeClassFilter=canSet}
            self.collectionClassDiagnostics=diagnostics
            local entries={}
            for _,entry in ipairs(result) do
                entries[#entries+1]={id=entry.id,name=entry.name,owned=entry.owned,
                    categoryID=entry.categoryID,uiOrder=entry.uiOrder,icon=entry.icon}
            end
            -- Bound cache entries by active filter and expiration. A wardrobe
            -- change event invalidates these results through the UI listener.
            self._transmogBaseCatalogCache={[cacheKey]={entries=entries,time=now,diagnostics=diagnostics}}
        end
    end
    -- Saved observations may be browsed even if the client's current filters hide them.
    local c=self:CollectionsStore()
    for _,rec in pairs(c and c.discoveries or {}) do
        if type(rec)=='table' and rec.category==cat and tonumber(rec.id)
            and (cat~='toys' or IsVerifiedToy(rec.id)) then
            if cat=='pets' then KnownPetInfo(rec) end
            local native=seen[rec.id]
            if native then
                -- Metadata enrichment never changes native ownership or
                -- grants discovery: only an existing observation is consulted.
                if not AnyStr(native.name) or native.name == (cat..' #'..rec.id) then
                    native.name=rec.name or native.name
                end
                native.icon=native.icon or rec.icon
                native.displayID=native.displayID or rec.displayID
                native.creatureID=native.creatureID or rec.creatureID
                    native.source=AnyStr(native.source) or AnyStr(rec.source)
                native.description=AnyStr(native.description) or AnyStr(rec.description)
                if cat=='toys' then
                    native.owned=ToyOwned(rec.id) or native.owned
                end
            else
                add({id=rec.id,name=rec.name or (cat..' #'..rec.id),icon=rec.icon,
                    owned=(cat=='toys' and ToyOwned(rec.id)) or false,observedOnly=true,displayID=rec.displayID,
                    creatureID=rec.creatureID,source=rec.source,
                    description=rec.description})
            end
        end
    end
    if cat=='transmog' then
        -- Native wardrobe order is stable even while item names load.
        table.sort(result,function(a,b)
            local ac,bc=tonumber(a.categoryID) or 99,tonumber(b.categoryID) or 99
            if ac~=bc then return ac<bc end
            local ao,bo=tonumber(a.uiOrder) or 999999,tonumber(b.uiOrder) or 999999
            if ao~=bo then return ao<bo end
            return a.id<b.id
        end)
    else
        table.sort(result,function(a,b)
            local an,bn=string.lower(a.name or ''),string.lower(b.name or '')
            return an==bn and a.id<b.id or an<bn
        end)
    end
    return result
end

-- Merchant mount resolution must not depend on a single client item-to-mount
-- association. Forever can show a mount in the journal while omitting the
-- item mapping or delaying item-spell information until the cache fills.
-- Use native item -> mount, then spell -> mount, then a uniquely matching native
-- mount name. Name matching never uses substrings: e.g. Regal Galestrider must
-- not accidentally match Swift Regal Galestrider.
local function MerchantMountKey(name)
    name=AnyStr(name)
    if not name then return nil end
    name=name:match('^%s*(.-)%s*$'):lower()
    -- Strip only explicit mount-item prefixes. Do NOT broadly remove words
    -- such as Swift or Stormy; those distinguish different mount records.
    local stripped=false
    for _,prefix in ipairs({'reins of ','reins: ','bridle of ','harness of ',
                            'whistle of ','horn of ','idol of '}) do
        if name:sub(1,#prefix)==prefix then
            name=name:sub(#prefix+1)
            stripped=true
            break
        end
    end
    if stripped then name=name:gsub('^the ','') end
    name=name:gsub(' reins$',''):gsub(' bridle$','')
    return name~='' and name or nil
end
local merchantMountNameCache,merchantMountNameCacheAt
local function MountNameIndex()
    local clock=(type(GetTime)=='function' and GetTime()) or Now()
    if merchantMountNameCache and merchantMountNameCacheAt
        and clock-merchantMountNameCacheAt<30 and clock>=merchantMountNameCacheAt then
        return merchantMountNameCache
    end
    local ids=C_MountJournal and Safe(C_MountJournal.GetMountIDs)
    if type(ids)~='table' or #ids==0 then return {} end
    local names={}
    for i=1,math.min(#ids,8000) do
        local id=tonumber(ids[i])
        local name=id and Safe(C_MountJournal.GetMountInfoByID,id)
        local key=MerchantMountKey(name)
        if key then
            if names[key]==nil then names[key]=id
            elseif names[key]~=id then names[key]=false end -- ambiguous
        end
    end
    merchantMountNameCache=names
    merchantMountNameCacheAt=clock
    return names
end
local function MountIDFromMerchantItem(itemID,merchantName,merchantSpellID)
    local mj=C_MountJournal
    if not mj or not itemID then return nil end
    local id=tonumber(Safe(mj.GetMountFromItem,itemID))
    if id and id>0 then return id,'item' end
    local spell=tonumber(merchantSpellID)
    if not spell then
        local _,fromItem=Safe(C_Item and C_Item.GetItemSpell or GetItemSpell,itemID)
        spell=tonumber(fromItem)
    end
    if spell and spell>0 then
        id=tonumber(Safe(mj.GetMountFromSpell,spell))
        if id and id>0 then return id,'spell' end
    end
    -- Use only a unique, exact name from the actual live mount journal.
    -- This is intentionally not a general fuzzy item classifier.
    local key=MerchantMountKey(merchantName)
    id=key and MountNameIndex()[key]
    if type(id)=='number' and id>0 then return id,'exact-name' end
    return nil
end
function AF:CaptureMerchantCollections()
    local c=self:CollectionsStore()
    if not c or not (C_MerchantFrame or GetMerchantNumItems) then return 0,'Collection registry unavailable' end
    local getCount=GetMerchantNumItems or (C_MerchantFrame and C_MerchantFrame.GetNumItems)
    local getInfo=C_MerchantFrame and C_MerchantFrame.GetItemInfo or GetMerchantItemInfo
    local getLink=GetMerchantItemLink or (C_MerchantFrame and C_MerchantFrame.GetItemLink)
    local getID=GetMerchantItemID
    local count=tonumber(Safe(getCount)) or 0
    local guid=type(UnitGUID)=='function' and UnitGUID('npc') or nil
    local npc=type(UnitName)=='function' and UnitName('npc') or nil
    if count<1 or not npc then
        c.lastMerchantScan={name=npc or 'Unknown',at=Now(),slots=count,matched=0,
            newlyDiscovered=0,unresolved=math.max(0,count),reason='Inventory or NPC not ready'}
        return 0,'Merchant inventory or NPC not ready (will retry if open)'
    end
    local mapID,x,y
    if C_Map and type(C_Map.GetBestMapForUnit)=='function' then
        mapID=Safe(C_Map.GetBestMapForUnit,'player')
        local pos=mapID and Safe(C_Map.GetPlayerMapPosition,mapID,'player')
        if pos and type(pos.GetXY)=='function' then x,y=Safe(pos.GetXY,pos) end
    end
    local found,newFound,unresolved,unmatched=0,0,0,0
    local methods={item=0,spell=0,['exact-name']=0}
    for i=1,math.min(count,250) do
        local itemID=tonumber(Safe(getID,i))
        local link
        if not itemID or itemID<=0 then
            link=Safe(getLink,i)
            itemID=ItemID(link)
        end
        if not itemID or itemID<=0 then
            unresolved=unresolved+1
        else
            local price,quantity,merchantItemName,merchantTexture,merchantSpellID
            local info=Safe(getInfo,i)
            if type(info)=='table' then
                price=info.price;quantity=info.stackCount
                merchantItemName=info.name;merchantTexture=info.texture
                merchantSpellID=info.spellID
            else
                merchantItemName,merchantTexture,price,quantity=Safe(getInfo,i)
            end
            -- The link name is sometimes cached before MerchantItemInfo.name.
            if not AnyStr(merchantItemName) then
                link=link or Safe(getLink,i)
                if type(link)=='string' then merchantItemName=link:match('%[(.-)%]') end
            end
            local cat,id,method,petName,petIcon,petDisplayID,petCreatureID,petSource,petDescription
            id,method=MountIDFromMerchantItem(itemID,merchantItemName,merchantSpellID)
            if id then cat='mounts';methods[method]=(methods[method] or 0)+1 end
            if not id and C_PetJournal then
                id,petName,petIcon,petDisplayID,petCreatureID,petSource,petDescription=PetFromItem(itemID)
                if id and id>0 then cat='pets' end
            end
            if not id then
                -- Never classify arbitrary vendor inventory as a toy based
                -- on GetToyInfo's itemID echo or a generic toy tooltip.
                local _,_,_,isToy=ToyItemInfo(itemID)
                if isToy then cat='toys';id=itemID end
            end
            if cat and id and id>0 then
                if not self:CollectionDiscovery(cat,id) then newFound=newFound+1 end
                local rec=self:ObserveCollectible(cat,id,{kind='vendor',npcGUID=guid,npcName=npc,
                    itemID=itemID,mapID=mapID,x=x,y=y,price=price,quantity=quantity})
                if rec then
                    local name=type(GetItemInfo)=='function' and Safe(GetItemInfo,itemID) or nil
                    local icon=type(GetItemIcon)=='function' and Safe(GetItemIcon,itemID) or nil
                    if cat=='pets' then
                        rec.name=petName or rec.name or AnyStr(merchantItemName) or AnyStr(name)
                        rec.icon=petIcon or rec.icon or icon or merchantTexture
                        if petDisplayID and petDisplayID>0 then rec.displayID=petDisplayID end
                        if petCreatureID and petCreatureID>0 then rec.creatureID=petCreatureID end
                        rec.source=AnyStr(petSource) or rec.source
                        rec.description=AnyStr(petDescription) or rec.description
                        KnownPetInfo(rec)
                    else
                        if cat=='mounts' then
                            local nativeName,_,nativeIcon=Safe(C_MountJournal.GetMountInfoByID,id)
                            rec.name=AnyStr(nativeName) or rec.name or AnyStr(name) or AnyStr(merchantItemName)
                            rec.icon=nativeIcon or rec.icon or icon or merchantTexture
                        else
                            rec.name=rec.name or AnyStr(name) or AnyStr(merchantItemName)
                            rec.icon=rec.icon or icon or merchantTexture
                            if cat=='toys' then rec.source=NativeToySource(itemID) or rec.source end
                        end
                    end
                    found=found+1
                end
            else
                unmatched=unmatched+1
            end
        end
    end
    c.lastMerchantScan={name=npc,mapID=mapID,x=x,y=y,at=Now(),slots=count,
        matched=found,newlyDiscovered=newFound,unresolved=unresolved,unmatched=unmatched,
        mountMethods=methods}
    return found,'Scanned '..count..' merchant slots; recorded '..found..' recognizable collectibles ('..newFound..' new).',newFound
end

-- Discovery-only listeners. Nothing here purchases items or reveals unseen catalogs.
-- Merchant stock may not be ready on MERCHANT_SHOW; links may finish loading later.
-- Listen for updates and do two bounded catch-up passes, even if Foundry is closed.
local listener=CreateFrame('Frame')
for _,event in ipairs({'MERCHANT_SHOW','MERCHANT_UPDATE','MERCHANT_CLOSED',
    'NEW_MOUNT_ADDED','NEW_PET_ADDED','TOYS_UPDATED','TRANSMOG_COLLECTION_UPDATED',
    'PLAYER_ENTERING_WORLD','BAG_UPDATE_DELAYED'}) do
    pcall(listener.RegisterEvent,listener,event) -- Some clients omit individual events.
end
local merchantSession,merchantOpen,merchantUpdatePending=0,false,false
local function ScanCurrentMerchant()
    if not merchantOpen or not AF.db or not AF.db.collections then return end
    local ok,found,_,newCount=pcall(AF.CaptureMerchantCollections,AF)
    if not ok then
        if AF.Print then AF.Print('Collections merchant scan: '..tostring(found)) end
        return
    end
    -- UI refresh is only needed for actual new discoveries; saved data does
    -- not depend on the Foundry window being open.
    if (tonumber(newCount) or 0)>0 and AF.UI and AF.UI.currentPage=='Collections' then
        AF:RefreshUI()
    end
end
local function ScheduleMerchantScan(delay)
    if not C_Timer or type(C_Timer.After)~='function' then return end
    local session=merchantSession
    C_Timer.After(delay,function()
        if not merchantOpen or merchantSession~=session then return end
        -- Reject callbacks after the vendor window closes, including unusual
        -- clients which omit the MERCHANT_CLOSED event.
        if MerchantFrame and type(MerchantFrame.IsShown)=='function'
            and not MerchantFrame:IsShown() then return end
        ScanCurrentMerchant()
    end)
end
listener:SetScript('OnEvent',function(_,event)
    if event=='MERCHANT_CLOSED' then
        merchantOpen=false
        merchantSession=merchantSession+1
        merchantUpdatePending=false
        return
    end
    if not AF.db or not AF.db.collections then return end
    if event=='MERCHANT_SHOW' then
        merchantSession=merchantSession+1
        merchantOpen=true
        merchantUpdatePending=false
        ScanCurrentMerchant()
        ScheduleMerchantScan(0.25)
        ScheduleMerchantScan(1.0)
        ScheduleMerchantScan(2.5) -- final bounded retry for delayed Forever item cache
        return
    elseif event=='MERCHANT_UPDATE' and merchantOpen then
        -- Merchant updates sometimes burst while buying or loading stock.
        -- Coalesce each burst to one scan, with zero polling when no vendor is open.
        if not merchantUpdatePending then
            merchantUpdatePending=true
            local session=merchantSession
            if C_Timer and type(C_Timer.After)=='function' then
                C_Timer.After(0.12,function()
                    if merchantSession~=session then return end
                    merchantUpdatePending=false
                    if merchantOpen then ScanCurrentMerchant() end
                end)
            else
                merchantUpdatePending=false
                ScanCurrentMerchant()
            end
        end
        return
    end
    if event=='NEW_MOUNT_ADDED' then merchantMountNameCache=nil end
    if event=='TRANSMOG_COLLECTION_UPDATED' then AF.collectionClassEligibilityCache=nil end
    if event=='TOYS_UPDATED' then AF._toyNegativeInventoryCache=nil;verifiedToyIDs={} end
    if event=='PLAYER_ENTERING_WORLD' or event=='BAG_UPDATE_DELAYED' or event=='TOYS_UPDATED' then
        -- At most one pending scan across repeated BAG_UPDATE_DELAYED bursts.
        if not AF._toyBagScanPending then
            AF._toyBagScanPending=true
            local function scan()
                AF._toyBagScanPending=false
                if not AF.db or not AF.db.collections then return end
                local newToys=AF:ScanCarriedToys()
                if newToys>0 and AF.UI and AF.UI.currentPage=='Collections' then AF:RefreshUI() end
            end
            if C_Timer and type(C_Timer.After)=='function' then
                C_Timer.After(event=='PLAYER_ENTERING_WORLD' and 1 or .4,scan)
            else scan() end
        end
        if event~='TOYS_UPDATED' then return end
    end
    if AF.UI and AF.UI.currentPage=='Collections' then AF:RefreshUI() end
end)
