require('_system.enum.SQL_Globals')

local M = {}

local LOG = '.\\sirin-log\\raceKillProgress_db.log'
local function log(fmt, ...)
    local ok, msg = pcall(string.format, "[rk_db] " .. fmt, ...)
    msg = ok and msg or ("[rk_db] " .. tostring(fmt))
    Sirin.WriteA(LOG, msg .. "\n", true, true)
end

-- Cases:
-- 1: load personal by playerSerial -> returns set(int playerSerial, int personalKills)
-- 2: load race by raceCode -> returns set(int raceCode, int raceKills)
-- 3: load claimed by playerSerial -> returns set(int playerSerial, tinyint claimed)
-- 5: load ranking top5 by raceCode -> returns set(tinyint raceCode, varchar(16) name, int kills)
-- 101: inc personal by "serial|name|race"
-- 102: inc race by raceCode
-- 103: set claimed by playerSerial

local function execNoResult(pszQuery, binders)
    local sqlRet = SQL_SUCCESS
    local buf = Sirin.CBinaryData(128)
    repeat
        if binders then
            for _,b in ipairs(binders) do
                if b.t == 'i32' then buf:PushInt32(b.v); sqlRet = Sirin.worldDBThread.g_WorldDatabaseEx:SQLBindParam(b.p, SQL_PARAM_INPUT, SQL_C_SLONG, SQL_INTEGER, 0, 0, buf, 4)
                elseif b.t == 'i8' then buf:PushInt8(b.v); sqlRet = Sirin.worldDBThread.g_WorldDatabaseEx:SQLBindParam(b.p, SQL_PARAM_INPUT, SQL_C_UTINYINT, SQL_TINYINT, 0, 0, buf, 1)
                elseif b.t == 's16' then buf:PushString(b.v, 17); sqlRet = Sirin.worldDBThread.g_WorldDatabaseEx:SQLBindParam(b.p, SQL_PARAM_INPUT, SQL_C_CHAR, SQL_VARCHAR, 16, 0, buf, 17, SQL_NTS)
                else sqlRet = SQL_ERROR end
                if sqlRet ~= SQL_SUCCESS then break end
            end
            if sqlRet ~= SQL_SUCCESS then break end
        end
        log('execNoResult query=%s', pszQuery)
        sqlRet = Sirin.worldDBThread.g_WorldDatabaseEx:SQLExecDirect(pszQuery, SQL_NTS)
        log('execNoResult ret=%d', sqlRet)
    until true
    local fr = Sirin.worldDBThread.g_WorldDatabaseEx:SQLFreeStmt(SQL_CLOSE)
    if fr ~= SQL_SUCCESS and fr ~= SQL_SUCCESS_WITH_INFO then
        Sirin.worldDBThread.g_WorldDatabaseEx:ErrorAction(fr, 'SQLFreeStmt', 'raceKillProgress_db.execNoResult')
    end
    if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
        Sirin.worldDBThread.g_WorldDatabaseEx:ErrorAction(sqlRet, pszQuery, 'raceKillProgress_db.execNoResult')
    end
end

local function execSelect(pszQuery, binders, rowSize)
    local sqlRet = SQL_SUCCESS
    local set = nil
    local buf = Sirin.CBinaryData(128)
    repeat
        if binders then
            for _,b in ipairs(binders) do
                if b.t == 'i32' then buf:PushInt32(b.v); sqlRet = Sirin.worldDBThread.g_WorldDatabaseEx:SQLBindParam(b.p, SQL_PARAM_INPUT, SQL_C_SLONG, SQL_INTEGER, 0, 0, buf, 4)
                elseif b.t == 'i8' then buf:PushInt8(b.v); sqlRet = Sirin.worldDBThread.g_WorldDatabaseEx:SQLBindParam(b.p, SQL_PARAM_INPUT, SQL_C_UTINYINT, SQL_TINYINT, 0, 0, buf, 1)
                else sqlRet = SQL_ERROR end
                if sqlRet ~= SQL_SUCCESS then break end
            end
            if sqlRet ~= SQL_SUCCESS then break end
        end
        log('execSelect query=%s', pszQuery)
        sqlRet = Sirin.worldDBThread.g_WorldDatabaseEx:SQLExecDirect(pszQuery, SQL_NTS)
        log('execSelect ret=%d', sqlRet)
        if sqlRet == SQL_SUCCESS or sqlRet == SQL_SUCCESS_WITH_INFO then
            sqlRet, set = Sirin.worldDBThread.g_WorldDatabaseEx:FetchSelected(rowSize)
        elseif sqlRet == SQL_NO_DATA then
            sqlRet = SQL_SUCCESS
            set = Sirin.CSQLResultSet(rowSize)
        end
    until true
    local fr = Sirin.worldDBThread.g_WorldDatabaseEx:SQLFreeStmt(SQL_CLOSE)
    if fr ~= SQL_SUCCESS and fr ~= SQL_SUCCESS_WITH_INFO then
        Sirin.worldDBThread.g_WorldDatabaseEx:ErrorAction(fr, 'SQLFreeStmt', 'raceKillProgress_db.execSelect')
    end
    if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
        Sirin.worldDBThread.g_WorldDatabaseEx:ErrorAction(sqlRet, pszQuery, 'raceKillProgress_db.execSelect')
        set = nil
    end
    return set
end

local function withTx(fn)
    local db = Sirin.worldDBThread.g_WorldDatabaseEx
    db:SetAutoCommitMode(false)
    local ok = pcall(fn)
    if ok then db:CommitTransaction() else db:RollbackTransaction() end
    db:SetAutoCommitMode(true)
end

function M.asyncHandler(case, param)
    log('asyncHandler case=%s param=%s', tostring(case), tostring(param))
    if case == 1 then
        local playerSerial = param
        local set = execSelect('{ CALL dbo.Sirin_LoadRaceHunt_Personal(?) }', { {p=1,t='i32',v=playerSerial} }, 8)
        if set then
            local list = set:GetList()
            if #list == 0 then
                withTx(function()
                    execNoResult('INSERT INTO dbo.Sirin_RaceHunt_Personal (PlayerSerial, PlayerName, RaceCode, PersonalKills, Claimed) VALUES (?, ?, ?, 0, 0)', { {p=1,t='i32',v=playerSerial}, {p=2,t='s16',v=''}, {p=3,t='i8',v=0} })
                end)
                set = execSelect('{ CALL dbo.Sirin_LoadRaceHunt_Personal(?) }', { {p=1,t='i32',v=playerSerial} }, 8)
            end
        end
        Sirin.processAsyncCallback(0, 'sirin.guard.mainThread', 'SirinLua', 'asyncHandler', 1, set)
    elseif case == 2 then
        local raceCode = param
        withTx(function()
            execNoResult('IF NOT EXISTS (SELECT 1 FROM dbo.Sirin_RaceHunt_Race WHERE RaceCode = ?) INSERT INTO dbo.Sirin_RaceHunt_Race (RaceCode, RaceKills) VALUES (?,0)', { {p=1,t='i8',v=raceCode}, {p=2,t='i8',v=raceCode} })
        end)
        local set = execSelect('{ CALL dbo.Sirin_LoadRaceHunt_Race(?) }', { {p=1,t='i8',v=raceCode} }, 5)
        Sirin.processAsyncCallback(0, 'sirin.guard.mainThread', 'SirinLua', 'asyncHandler', 2, set)
    elseif case == 3 then
        local playerSerial = param
        local set = execSelect('{ CALL dbo.Sirin_LoadRaceHunt_Claimed(?) }', { {p=1,t='i32',v=playerSerial} }, 5)
        Sirin.processAsyncCallback(0, 'sirin.guard.mainThread', 'SirinLua', 'asyncHandler', 4, set)
    elseif case == 5 then
        local raceCode = param
        -- rowSize: tinyint(1) + varchar(16) + int(4) = 21
        local set = execSelect('{ CALL dbo.Sirin_LoadRaceHunt_Top5(?) }', { {p=1,t='i8',v=raceCode} }, 21)
        if not set then
            log('Top5 select failed for race=%d', raceCode)
        end
        Sirin.processAsyncCallback(0, 'sirin.guard.mainThread', 'SirinLua', 'asyncHandler', 5, set)
    elseif case == 101 then
        local serial, name, race = tostring(param):match('^(%d+)|([^|]+)|(%d+)$')
        serial = tonumber(serial or '0') or 0
        race = tonumber(race or '0') or 0
        name = name or ''
        withTx(function()
            execNoResult('{ CALL dbo.Sirin_IncRaceHunt_PersonalEx(?, ?, ?) }', { {p=1,t='i32',v=serial}, {p=2,t='s16',v=name}, {p=3,t='i8',v=race} })
        end)
        Sirin.processAsyncCallback(0, 'sirin.guard.mainThread', 'SirinLua', 'asyncHandler', 3, 0)
    elseif case == 102 then
        local raceCode = param
        withTx(function()
            execNoResult('{ CALL dbo.Sirin_IncRaceHunt_Race(?) }', { {p=1,t='i8',v=raceCode} })
        end)
        Sirin.processAsyncCallback(0, 'sirin.guard.mainThread', 'SirinLua', 'asyncHandler', 3, 0)
    elseif case == 103 then
        local playerSerial = param
        withTx(function()
            execNoResult('{ CALL dbo.Sirin_SetRaceHunt_Claimed(?) }', { {p=1,t='i32',v=playerSerial} })
        end)
        Sirin.processAsyncCallback(0, 'sirin.guard.mainThread', 'SirinLua', 'asyncHandler', 3, 0)
    elseif case == 201 then
        -- load personal by playerSerial and tab (param: "serial|tab") -> returns set(tab, serial, personal)
        local serial, tab = tostring(param):match('^(%d+)|(%d+)$')
        serial = tonumber(serial or '0') or 0
        tab = tonumber(tab or '1') or 1
        local set = execSelect('{ CALL dbo.Sirin_LoadRaceHunt_PersonalTab(?, ?) }', { {p=1,t='i32',v=serial}, {p=2,t='i8',v=tab} }, 9)
        Sirin.processAsyncCallback(0, 'sirin.guard.mainThread', 'SirinLua', 'asyncHandler', 201, set)
    elseif case == 202 then
        -- load race by raceCode and tab (param: "race|tab") -> returns set(tab, race, raceKills)
        local race, tab = tostring(param):match('^(%d+)|(%d+)$')
        race = tonumber(race or '0') or 0
        tab = tonumber(tab or '1') or 1
        local set = execSelect('{ CALL dbo.Sirin_LoadRaceHunt_RaceTab(?, ?) }', { {p=1,t='i8',v=race}, {p=2,t='i8',v=tab} }, 6)
        Sirin.processAsyncCallback(0, 'sirin.guard.mainThread', 'SirinLua', 'asyncHandler', 202, set)
    elseif case == 203 then
        -- load claimed by serial and tab (param: "serial|tab") -> returns set(tab, serial, claimed)
        local serial, tab = tostring(param):match('^(%d+)|(%d+)$')
        serial = tonumber(serial or '0') or 0
        tab = tonumber(tab or '1') or 1
        local set = execSelect('{ CALL dbo.Sirin_LoadRaceHunt_ClaimedTab(?, ?) }', { {p=1,t='i32',v=serial}, {p=2,t='i8',v=tab} }, 6)
        Sirin.processAsyncCallback(0, 'sirin.guard.mainThread', 'SirinLua', 'asyncHandler', 203, set)
    elseif case == 205 then
        -- load top5 by race and tab (param: "race|tab")
        local race, tab = tostring(param):match('^(%d+)|(%d+)$')
        race = tonumber(race or '0') or 0
        tab = tonumber(tab or '1') or 1
        local set = execSelect('{ CALL dbo.Sirin_LoadRaceHunt_Top5Tab(?, ?) }', { {p=1,t='i8',v=race}, {p=2,t='i8',v=tab} }, 22)
        Sirin.processAsyncCallback(0, 'sirin.guard.mainThread', 'SirinLua', 'asyncHandler', 205, set)
    elseif case == 301 then
        -- inc personal by serial|name|race|tab
        local serial, name, race, tab = tostring(param):match('^(%d+)|([^|]+)|(%d+)|(%d+)$')
        serial = tonumber(serial or '0') or 0
        race = tonumber(race or '0') or 0
        tab = tonumber(tab or '1') or 1
        name = name or ''
        withTx(function()
            execNoResult('{ CALL dbo.Sirin_IncRaceHunt_PersonalTab(?, ?, ?, ?) }', { {p=1,t='i32',v=serial}, {p=2,t='s16',v=name}, {p=3,t='i8',v=race}, {p=4,t='i8',v=tab} })
        end)
        Sirin.processAsyncCallback(0, 'sirin.guard.mainThread', 'SirinLua', 'asyncHandler', 3, 0)
    elseif case == 302 then
        -- inc race by race|tab
        local race, tab = tostring(param):match('^(%d+)|(%d+)$')
        race = tonumber(race or '0') or 0
        tab = tonumber(tab or '1') or 1
        withTx(function()
            execNoResult('{ CALL dbo.Sirin_IncRaceHunt_RaceTab(?, ?) }', { {p=1,t='i8',v=race}, {p=2,t='i8',v=tab} })
        end)
        Sirin.processAsyncCallback(0, 'sirin.guard.mainThread', 'SirinLua', 'asyncHandler', 3, 0)
    elseif case == 303 then
        -- set claimed by serial|tab
        local serial, tab = tostring(param):match('^(%d+)|(%d+)$')
        serial = tonumber(serial or '0') or 0
        tab = tonumber(tab or '1') or 1
        withTx(function()
            execNoResult('{ CALL dbo.Sirin_SetRaceHunt_ClaimedTab(?, ?) }', { {p=1,t='i32',v=serial}, {p=2,t='i8',v=tab} })
        end)
        Sirin.processAsyncCallback(0, 'sirin.guard.mainThread', 'SirinLua', 'asyncHandler', 3, 0)
    end
end

return M