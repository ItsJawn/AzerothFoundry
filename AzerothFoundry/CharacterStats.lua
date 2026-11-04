-- Azeroth Foundry 0.5.11.4: robust read-only per-character currency and /played snapshots.
-- Only snapshots observed on the logged-in character are recorded; offline
-- character records are never refreshed from GetMoney().
local _, AF = ...
local watcher = CreateFrame("Frame")
local function now() return type(time)=="function" and time() or 0 end
local function current()
    if not AF.db or not AF.db.characters or not AF.GetCurrentKey then return end
    -- Use the login-time key when the client is transitioning between zones or
    -- logging out; UnitGUID/UnitName may be temporarily unavailable then.
    local key = watcher.afCharacterKey or AF:GetCurrentKey()
    return key and AF.db.characters[key]
end
local function refreshCharacters()
    if AF.UI and AF.UI.currentPage=="Characters" and AF.RefreshUI then AF:RefreshUI() end
end

-- reason: automatic (default), money-event, manual.
-- A zero in an automatic scan can mean bags/currency data have not populated.
-- It must NOT erase an older positive record. A real PLAYER_MONEY event after
-- initialization, or an explicit user rescan, may record an actual zero.
function AF:RecordCurrentCharacterMoney(reason)
    local c = current()
    if not c or type(GetMoney) ~= "function" then return false end
    local ok, value = pcall(GetMoney)
    if not ok or type(value)~="number" or value<0 or value~=value then return false end
    value = math.floor(value)
    reason = reason or "manual"
    if value==0 and type(c.afMoneyCopper)=="number" and c.afMoneyCopper>0 then
        if reason~="money-event" and not (reason=="manual" and watcher.afReady) then
            return false
        end
    end
    -- Before the first real post-login inventory update, a zero value cannot
    -- distinguish an empty purse from uninitialized client state.
    if value==0 and not watcher.afReady then return false end
    local changed = c.afMoneyCopper~=value
    c.afMoneyCopper = value
    c.afMoneySeenAt = now()
    if changed then refreshCharacters() end
    return true
end
function AF:RecordCurrentCharacterPlayed(seconds)
    local c = current()
    if not c or type(seconds)~="number" or seconds<0 or seconds~=seconds then return end
    -- /played is cumulative. An anomalous zero/older response must not reset
    -- a previously verified character's accumulated playtime.
    seconds=math.floor(seconds)
    if type(c.afPlayedSeconds)=="number" and seconds<c.afPlayedSeconds then return end
    c.afPlayedSeconds = seconds
    c.afPlayedSeenAt = now()
    refreshCharacters()
end
function AF:RequestCurrentCharacterPlayed()
    if type(RequestTimePlayed) ~= "function" then return false end
    local ok = pcall(RequestTimePlayed)
    return ok
end

watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("BAG_UPDATE_DELAYED")
watcher:RegisterEvent("PLAYER_MONEY")
watcher:RegisterEvent("TIME_PLAYED_MSG")
watcher:RegisterEvent("PLAYER_LOGOUT")
watcher:SetScript("OnEvent",function(_,event,...)
    if event=="PLAYER_LOGIN" then
        watcher.afCharacterKey = AF.GetCurrentKey and AF:GetCurrentKey() or nil
        watcher.afReady = false
        watcher.afRequested = false
    elseif event=="PLAYER_ENTERING_WORLD" then
        local function capture()
            if not AF.db then return end
            -- Delayed captures are deliberately non-authoritative for zero;
            -- a real money change can still record a legitimate zero later.
            watcher.afReady = true
            AF:RecordCurrentCharacterMoney("automatic")
            if not watcher.afRequested then
                watcher.afRequested = true
                AF:RequestCurrentCharacterPlayed()
            end
        end
        if C_Timer and type(C_Timer.After)=="function" then C_Timer.After(2,capture)
        else capture() end
    elseif event=="BAG_UPDATE_DELAYED" then
        if AF.db then
            watcher.afReady=true
            AF:RecordCurrentCharacterMoney("automatic")
        end
    elseif event=="PLAYER_MONEY" then
        if watcher.afReady then
            AF:RecordCurrentCharacterMoney("money-event")
        else
            -- An early PLAYER_MONEY notification can belong to login loading.
            -- Re-read it after initialization instead of trusting a zero now.
            if not watcher.afMoneyPending then
                watcher.afMoneyPending=true
                local function retry()
                    watcher.afMoneyPending=nil
                    if AF.db then AF:RecordCurrentCharacterMoney("automatic") end
                end
                if C_Timer and type(C_Timer.After)=="function" then
                    C_Timer.After(2,retry)
                end
            end
        end
    elseif event=="TIME_PLAYED_MSG" then
        AF:RecordCurrentCharacterPlayed((...))
    elseif event=="PLAYER_LOGOUT" then
        -- Do not query GetMoney during logout: some client builds briefly
        -- return zero while the player state is dismantling. Keep the last
        -- verified event/inventory snapshot, which SavedVariables will persist.
        watcher.afReady=false
    end
end)
