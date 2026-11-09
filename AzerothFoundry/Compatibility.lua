-- Azeroth Foundry 0.5.0: diagnostic-only Retail / Forever compatibility boundary.
-- This file deliberately does NOT monkeypatch WoW APIs, rewrite databases,
-- or cause a feature to pretend that optional historical data exists.
local _, AF = ...
AF.Compatibility = AF.Compatibility or {}
local compat = AF.Compatibility

local function GetInterface()
    if type(GetBuildInfo) ~= 'function' then return nil end
    local ok, value = pcall(function() return select(4, GetBuildInfo()) end)
    if ok then return tonumber(value) end
end

function compat.GetClient()
    local interface = GetInterface()
    local mainline = WOW_PROJECT_ID ~= nil and WOW_PROJECT_MAINLINE ~= nil
        and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
    -- Forever reports Interface 16001 but does not have to identify itself
    -- as WOW_PROJECT_MAINLINE. The interface is unambiguous; don't let a
    -- different project constant downgrade it to Unknown.
    if interface == 16001 then return 'Forever', interface end
    if mainline and interface and interface >= 100000 then return 'Retail', interface end
    return 'Unknown', interface
end

local function SafeLib(name)
    local stub = LibStub
    if type(stub) == 'table' and type(stub.GetLibrary) == 'function' then
        local ok, lib = pcall(stub.GetLibrary, stub, name, true)
        if ok and type(lib) == 'table' then return lib end
    elseif type(stub) == 'function' then
        local ok, lib = pcall(stub, name, true)
        if ok and type(lib) == 'table' then return lib end
    end
    return nil
end

local function AddOnLoaded(name)
    local fn = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if type(fn) ~= 'function' then return nil end
    local ok, isLoaded = pcall(fn, name)
    if ok then return not not isLoaded end
end

local function AddOnPresent(name)
    local fn = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
    if type(fn) ~= 'function' then return nil end
    local ok, info = pcall(fn, name)
    if not ok then return nil end
    if type(info) == 'table' then return type(info.name)=='string' and info.name ~= '' end
    if type(info) == 'string' then return info ~= '' end
    return false
end

local libs = {
    ProfessionDB = 'LibProfessionDB-1.0',
    ItemDB = 'LibItemDB-1.0',
    QuestDB = 'LibQuestDB-1.0',
}

function compat.GetDependency(name)
    local libname = libs[name]
    if not libname then return nil end
    local loaded = AddOnLoaded(name)
    local present = AddOnPresent(name)
    local lib = SafeLib(libname)
    if lib then
        if name == 'ProfessionDB' and AF.GetProfessionReferenceStatus then
            local ready, reason = AF:GetProfessionReferenceStatus()
            if not ready then
                return {state='unavailable', label=reason or 'reference unavailable', library=libname}
            end
        end
        if type(lib.IsReady) == 'function' then
            local ok, ready = pcall(lib.IsReady, lib)
            if not ok or not ready then
                return {state='unavailable', label='installed; reference still initializing', library=libname}
            end
        end
        return {state='connected', label='connected', library=libname}
    end
    if loaded then
        return {state='unavailable', label='loaded, but reference library unavailable', library=libname}
    end
    if present == false then
        return {state='missing', label='not installed (optional)', library=libname}
    end
    if present == true or loaded == false then
        return {state='unavailable', label='not loaded (optional)', library=libname}
    end
    return {state='unavailable', label='not detected (optional)', library=libname}
end

function compat.PrintReport()
    local family, interface = compat.GetClient()
    AF.Print('Client: '..family..' | Interface: '..tostring(interface or 'unknown'))
    for _, name in ipairs({'ProfessionDB','ItemDB','QuestDB'}) do
        local result=compat.GetDependency(name)
        AF.Print(name..': '..result.label)
    end
    AF.Print('Missing references reduce offline catalog/history detail; live game observations still use native APIs where available.')
end
