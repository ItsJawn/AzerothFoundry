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
    return c and c.discoveries[K(cat,id)]
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
                    local _,name,icon=Safe(tb.GetToyInfo,id)
                    local owned=Safe(tb.HasToy,id)
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
        -- Avoid synchronously enumerating every source of every appearance.
        -- Category controls page through the currently selected 1..29 wardrobe family.
        local category=tonumber(self.db.collections.settings.transmogCategory) or 1
        category=math.max(1, math.min(29,category))
        -- Forever's SetClassFilter(0) can resolve to the current class instead of
        -- an all-class union. For All Classes, query each playable class and
        -- deduplicate visualIDs; leave Blizzard's original class filter intact.
        local chosen=self:GetCollectionTransmogClassChoice()
        local getFilter=C_TransmogCollection.GetClassFilter
        local setFilter=C_TransmogCollection.SetClassFilter
        local listFn=C_TransmogCollection.GetCategoryAppearances
        local original=Safe(getFilter)
        local canSet=type(getFilter)=='function' and type(setFilter)=='function' and type(original)=='number'
        local appearances={}
        local classSourceFn=C_TransmogCollection.GetValidAppearanceSourcesForClass
        local explicitClass=(type(chosen)=='number' and chosen>0 and type(classSourceFn)=='function')
        local checked,matched=0,0
        -- Cache class/source eligibility for the current UI session. This avoids
        -- repeating hundreds of native lookups on every gallery refresh.
        self.collectionClassEligibilityCache=self.collectionClassEligibilityCache or {}
        local categoryCache=self.collectionClassEligibilityCache[category]
        if not categoryCache then categoryCache={};self.collectionClassEligibilityCache[category]=categoryCache end
        local classCache=categoryCache[chosen]
        if not classCache then classCache={};categoryCache[chosen]=classCache end
        -- The class filter applied to the *catalog* is not necessarily applied
        -- to uncollected appearances by the Forever client. Validate every
        -- appearance against an actual source for the selected class instead.
        local function ValidForChosenClass(visualID)
            if not explicitClass then return true end
            checked=checked+1
            local known=classCache[visualID]
            if known~=nil then
                if known then matched=matched+1 end
                return known
            end
            local ok,sources=pcall(classSourceFn,visualID,chosen,category)
            if not ok then ok,sources=pcall(classSourceFn,visualID,chosen) end
            if not ok then
                -- Client rejected the API call; do not falsely hide its data.
                return true
            end
            local valid=type(sources)=='table' and #sources>0
            classCache[visualID]=valid
            if valid then matched=matched+1 end
            return valid
        end
        local function accumulate(rows)
            if type(rows)~='table' then return end
            for i=1,math.min(#rows,3500) do
                local v=rows[i]
                if type(v)=='table' then
                    local id=tonumber(v.visualID)
                    if id and (chosen==0 or ValidForChosenClass(id)) then
                        add({id=id,name='Appearance #'..id,owned=v.isCollected,categoryID=category,
                            icon='Interface\\Icons\\INV_Misc_QuestionMark'})
                    end
                end
            end
        end
        if canSet and type(chosen)=='number' then
            if chosen==0 then
                -- Enumerate playable class IDs instead of assuming the native
                -- filter recognizes 0 as an unfiltered view. Querying per class
                -- respects the client's category/proficiency rules.
                local ids,known={},{}
                local function addClass(id)
                    id=tonumber(id)
                    if id and id>0 and not known[id] then known[id]=true;ids[#ids+1]=id end
                end
                local count=tonumber(Safe(GetNumClasses)) or 0
                if type(GetClassInfo)=='function' then
                    for i=1,math.min(20,count) do
                        local name,_,id=Safe(GetClassInfo,i)
                        if type(name)=='string' then addClass(id) end
                    end
                end
                if #ids==0 and C_CreatureInfo and type(C_CreatureInfo.GetClassInfo)=='function' then
                    for id=1,13 do
                        local info=Safe(C_CreatureInfo.GetClassInfo,id)
                        if type(info)=='table' and type(info.className)=='string' then addClass(id) end
                    end
                end
                if #ids==0 then
                    -- Core vanilla class IDs; only used if no enumeration API
                    -- exists in a particular beta build.
                    for _,id in ipairs({1,2,3,4,5,7,8,9,11}) do addClass(id) end
                end
                -- Include the existing native view in case the current client
                -- exposes a nonstandard class or race-specific entry.
                accumulate(Safe(listFn,category))
                for _,id in ipairs(ids) do
                    if pcall(setFilter,id) then accumulate(Safe(listFn,category)) end
                end
            else
                if pcall(setFilter,chosen) then
                    accumulate(Safe(listFn,category))
                else
                    accumulate(Safe(listFn,category))
                end
            end
            -- Always restore, even when an individual lookup failed.
            pcall(setFilter,original)
        else
            accumulate(Safe(listFn,category))
        end
        self.collectionClassDiagnostics={
            selected=chosen, scanned=checked, valid=matched,
            method=explicitClass and 'GetValidAppearanceSourcesForClass' or (chosen==0 and 'per-class catalog union' or 'native-only'),
            nativeClassFilter=canSet,
        }
    end
    -- Saved observations may be browsed even if the client's current filters hide them.
    local c=self:CollectionsStore()
    for _,rec in pairs(c and c.discoveries or {}) do
        if type(rec)=='table' and rec.category==cat and tonumber(rec.id) then
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
                native.source=native.source or rec.source
                native.description=native.description or rec.description
            else
                add({id=rec.id,name=rec.name or (cat..' #'..rec.id),icon=rec.icon,
                    owned=false,observedOnly=true,displayID=rec.displayID,
                    creatureID=rec.creatureID,source=rec.source,description=rec.description})
            end
        end
    end
    table.sort(result,function(a,b)
        local an,bn=string.lower(a.name or ''),string.lower(b.name or '')
        return an==bn and a.id<b.id or an<bn
    end)
    return result
end

function AF:CaptureMerchantCollections()
    local c=self:CollectionsStore()
    if not c or not (C_MerchantFrame or GetMerchantNumItems) then return 0, 'Collection registry unavailable' end
    local getCount=GetMerchantNumItems or (C_MerchantFrame and C_MerchantFrame.GetNumItems)
    local getInfo=C_MerchantFrame and C_MerchantFrame.GetItemInfo or GetMerchantItemInfo
    local getLink=GetMerchantItemLink or (C_MerchantFrame and C_MerchantFrame.GetItemLink)
    local count=tonumber(Safe(getCount)) or 0
    local guid=type(UnitGUID)=='function' and UnitGUID('npc') or nil
    local npc=type(UnitName)=='function' and UnitName('npc') or nil
    if count<1 or not npc then return 0,'No readable merchant inventory/NPC' end
    local mapID, x,y
    if C_Map and type(C_Map.GetBestMapForUnit)=='function' then
        mapID=Safe(C_Map.GetBestMapForUnit,'player')
        local pos=mapID and Safe(C_Map.GetPlayerMapPosition,mapID,'player')
        if pos and type(pos.GetXY)=='function' then x,y=Safe(pos.GetXY,pos) end
    end
    local found=0
    for i=1,math.min(count,250) do
        local link=Safe(getLink,i)
        local itemID=ItemID(link)
        if itemID then
            local price,quantity,merchantItemName,merchantTexture
            local info=Safe(getInfo,i)
            if type(info)=='table' then
                price=info.price;quantity=info.stackCount
                merchantItemName=info.name;merchantTexture=info.texture
            else
                merchantItemName,merchantTexture,price,quantity=Safe(getInfo,i)
            end
            local cat,id,petName,petIcon,petDisplayID,petCreatureID,petSource,petDescription
            if C_MountJournal then id=tonumber(Safe(C_MountJournal.GetMountFromItem,itemID));if id then cat='mounts' end end
            if not id and C_PetJournal then
                id,petName,petIcon,petDisplayID,petCreatureID,petSource,petDescription=PetFromItem(itemID)
                if id then cat='pets' end
            end
            if not id and C_ToyBox then
                local toyID=Safe(C_ToyBox.GetToyInfo,itemID)
                if tonumber(toyID)==itemID then cat='toys';id=itemID end
            end
            if cat and id then
                local rec=self:ObserveCollectible(cat,id,{kind='vendor',npcGUID=guid,npcName=npc,
                    itemID=itemID,mapID=mapID,x=x,y=y,price=price,quantity=quantity})
                if rec then
                    local name=type(GetItemInfo)=='function' and Safe(GetItemInfo,itemID) or nil
                    local icon=type(GetItemIcon)=='function' and Safe(GetItemIcon,itemID) or nil
                    if cat=='pets' then
                        -- Species metadata takes precedence over the vendor's
                        -- 'Cat Carrier (...)' item name when the API provides it.
                        rec.name=petName or rec.name or AnyStr(merchantItemName) or AnyStr(name)
                        rec.icon=petIcon or rec.icon or icon or merchantTexture
                        if petDisplayID and petDisplayID>0 then rec.displayID=petDisplayID end
                        if petCreatureID and petCreatureID>0 then rec.creatureID=petCreatureID end
                        rec.source=AnyStr(petSource) or rec.source
                        rec.description=AnyStr(petDescription) or rec.description
                        KnownPetInfo(rec)
                    else
                        rec.name=rec.name or AnyStr(name)
                        rec.icon=rec.icon or icon
                    end
                    found=found+1
                end
            end
        end
    end
    c.lastMerchantScan={name=npc,mapID=mapID,x=x,y=y,at=Now(),slots=count,matched=found}
    return found, 'Scanned '..count..' merchant slots; cataloged '..found..' recognizable collectibles.'
end

-- Discovery-only listeners. Never purchase an item, move a character, or initiate a screenshot.
local listener=CreateFrame('Frame')
for _,event in ipairs({'MERCHANT_SHOW','NEW_MOUNT_ADDED','NEW_PET_ADDED','TOYS_UPDATED','TRANSMOG_COLLECTION_UPDATED'}) do
    pcall(listener.RegisterEvent,listener,event) -- Forever may omit individual events
end
listener:SetScript('OnEvent',function(_,event)
    if not AF.db or not AF.db.collections then return end
    if event=='TRANSMOG_COLLECTION_UPDATED' then AF.collectionClassEligibilityCache=nil end
    if event=='MERCHANT_SHOW' then
        local ok,err=pcall(AF.CaptureMerchantCollections,AF)
        if not ok and AF.Print then AF.Print('Collections merchant scan: '..tostring(err)) end
    end
    if AF.UI and AF.UI.currentPage=='Collections' then AF:RefreshUI() end
end)
