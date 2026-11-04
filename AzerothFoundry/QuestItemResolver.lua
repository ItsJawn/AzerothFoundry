-- v0.4.1.7: Best-effort, cache-safe reward item resolution for quest history.
-- Uses WoW client data first; LibItemDB is OPTIONAL and never required to load AF.
-- Requests item information only for displayed rewards and only once per session.
local _, AF = ...
local QUESTION = 'Interface\\Icons\\INV_Misc_QuestionMark'
local requested = {}
local pending = {}
local function ValidID(v)
    local n=tonumber(v)
    if n and n>0 and n==math.floor(n) then return n end
end
local function Call(f,...)
    if type(f)~='function' then return nil end
    local ok,a,b,c,d,e,f2,g=pcall(f,...)
    if ok then return a,b,c,d,e,f2,g end
end
local function OfflineItems()
    if not LibStub then return nil end
    local ok,lib=pcall(LibStub,'LibItemDB-1.0',true)
    if ok and type(lib)=='table' then return lib end
end
local function LibCall(lib,method,id)
    if lib and type(lib[method])=='function' then
        return Call(lib[method],lib,id)
    end
end
local function ClientItem(id)
    local name,link,quality=Call(GetItemInfo,id)
    if (not name or name=='') and C_Item then
        name=Call(C_Item.GetItemNameByID,id) or name
        if type(C_Item.GetItemInfo)=='function' then
            local n,l,q=Call(C_Item.GetItemInfo,id)
            name=name or n;link=link or l;quality=quality or q
        end
    end
    local icon
    if C_Item then
        icon=Call(C_Item.GetItemIconByID,id)
        if not icon and type(C_Item.GetItemInfoInstant)=='function' then
            local _,_,_,_,instantIcon=Call(C_Item.GetItemInfoInstant,id)
            icon=instantIcon
        end
    end
    if not icon then icon=Call(GetItemIcon,id) end
    if not icon and type(GetItemInfoInstant)=='function' then
        local _,_,_,_,instantIcon=Call(GetItemInfoInstant,id)
        icon=instantIcon
    end
    if icon==0 then icon=nil end
    return name,icon,quality,link
end
function AF:IsQuestItemLibraryConnected()
    return OfflineItems()~=nil
end
function AF:ResolveQuestRewardItem(id,count,kind,name,icon,quality)
    id=ValidID(id)
    if not id and not icon then return nil end
    local nativeName,nativeIcon,nativeQuality,link
    local lib
    if id then
        nativeName,nativeIcon,nativeQuality,link=ClientItem(id)
        lib=OfflineItems()
        if not nativeName or nativeName=='' then
            nativeName=LibCall(lib,'GetName',id)
        end
        if nativeQuality==nil then
            nativeQuality=LibCall(lib,'GetQuality',id)
        end
        if not link then link=LibCall(lib,'GetLink',id) end
        -- Request an uncached name/icon once. The GET_ITEM_INFO_RECEIVED
        -- event can refresh the visible journal after Blizzard supplies it.
        if (not nativeName or nativeName=='' or not nativeIcon) and not requested[id] then
            requested[id]=true
            if C_Item and type(C_Item.RequestLoadItemDataByID)=='function' then
                pending[id]=true
                local ok=pcall(C_Item.RequestLoadItemDataByID,id)
                if not ok then pending[id]=nil end
            end
        end
    end
    -- Prefer explicit quest reward information from the live client, followed
    -- by native item metadata and finally optional offline item names.
    if type(name)~='string' or name=='' then name=nativeName end
    if not icon or icon==QUESTION or icon==0 then icon=nativeIcon end
    if quality==nil then quality=nativeQuality end
    if type(name)~='string' or name=='' then name=id and ('Item #'..id) or 'Quest reward' end
    if not icon then icon=QUESTION end
    return {
        id=id,count=tonumber(count) or 1,kind=kind or 'Reward',
        name=name,icon=icon,quality=quality,link=link,
        missingName=id and name==('Item #'..id) or false,
        missingIcon=icon==QUESTION,
    }
end
-- Return whether an item-data event pertains to displayed quest rewards.
function AF:QuestRewardItemDataReceived(id)
    id=ValidID(id)
    if id and pending[id] then pending[id]=nil;return true end
    return false
end
