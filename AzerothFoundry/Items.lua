-- Azeroth Foundry v0.3.1.1: transient item display data, never saved to the account DB.
-- Item names/qualities are client-local; cache loading happens asynchronously.
local _, AF = ...

local qualityColors = {
    [0] = 'ff9d9d9d', [1] = 'ffffffff', [2] = 'ff1eff00',
    [3] = 'ff0070dd', [4] = 'ffa335ee', [5] = 'ffff8000',
    [6] = 'ffe6cc80', [7] = 'ff00ccff',
}

function AF:GetItemPresentation(itemID)
    if type(itemID) ~= 'number' or itemID < 1 then return nil end
    local info = { id = itemID, name = 'Loading item #'..itemID..'...',
        quality = nil, color = 'ff704718', pending = true }
    local api = C_Item
    local getInfo = api and api.GetItemInfo or GetItemInfo
    if type(getInfo) == 'function' then
        local ok, name, link, quality, itemLevel, minLevel, _, _, _, _, texture = pcall(getInfo, itemID)
        if ok and type(name) == 'string' and name ~= '' then
            info.name, info.link, info.quality = name, link, quality
            info.itemLevel, info.minLevel = itemLevel, minLevel
            info.icon, info.pending = texture, false
            info.color = qualityColors[quality] or 'ffffffff'
        end
    end
    if not info.icon then
        local getIcon = (api and api.GetItemIconByID) or GetItemIcon
        if type(getIcon) == 'function' then
            local ok, value = pcall(getIcon, itemID)
            if ok then info.icon = value end
        end
    end
    if info.pending and api and type(api.RequestLoadItemDataByID) == 'function' then
        -- WoW will emit GET_ITEM_INFO_RECEIVED after the cache is populated.
        pcall(api.RequestLoadItemDataByID, itemID)
    end
    info.icon = info.icon or 'Interface\\Icons\\INV_Misc_QuestionMark'
    return info
end

function AF:ItemColoredName(item)
    if not item then return 'Unknown item' end
    return '|c'..(item.color or 'ffffffff')..(item.name or ('Item #'..item.id))..'|r'
end
