local projectName = 'sirin'
local moduleName = 'reloadCenter'

local script = {
    m_strUUID = projectName .. ".lua." .. moduleName,
    LOG = '.\\sirin-log\\reloadCenter.log',
}

local WINDOW_ID = 10
local IDX_INFO = 1
local IDX_RELOAD = 2

local function informPlayer(p, text)
    NetMgr.privateChatMsg(p, text)
    NetMgr.privateAnnounceMsg(p, text, 0xFFFF, ANN_TYPE.mid3, 0xFF00FF00)
end

local function logConsole(ok, msg)
    if ok then
        Sirin.console.LogEx(ConsoleForeground.GREEN, ConsoleBackground.BLACK, msg .. "\n")
    else
        Sirin.console.LogEx(ConsoleForeground.RED, ConsoleBackground.BLACK, msg .. "\n")
    end
end

local function openCustomWindow(p, windowId)
    local buf = Sirin.mainThread.CLuaSendBuffer.Instance()
    buf:Init()
    buf:PushUInt8(1)
    buf:PushUInt32(windowId)
    buf:PushUInt32(0)
    buf:PushUInt8(1)
    buf:SendBuffer(p, 80, 12)
end

local function sendWindowStatic(p)
    -- send ct=1 static for WINDOW_ID if available
    local langId = Sirin.CLanguageAsset.instance():getPlayerLanguage(p.m_id.wIndex)
    local defs = _G['SirinScript_CustomWindowsByLangID'] and SirinScript_CustomWindowsByLangID[langId]
    local def = defs and defs[WINDOW_ID]
    if not def then
        -- fallback static (simple two-lines window) if loader not ready yet
        def = {
            id = WINDOW_ID,
            name = { default = "Reload Center" },
            width = 420,
            height = 140,
            layout = { 0 },
            data = {
                { text = { default = "Reload scripts (main/custom & ReloadableScripts)" } },
                { text = { default = "Run Reload" } },
            },
        }
    end
    NetOP:new():SendData(p, 'sirin.proto.customWindows', { ct = 1, data = { def } }, true)
end

local function sendWindowState(p)
    local w = { id = WINDOW_ID, data = {} }
    table.insert(w.data, { id = IDX_INFO, stateFlags = tonumber('001', 2) })
    table.insert(w.data, { id = IDX_RELOAD, stateFlags = tonumber('1101', 2) })
    NetOP:new():SendData(p, 'sirin.proto.customWindows', { ct = 3, data = { w } }, true)
end

local function postReloadResync()
    -- Re-fetch DB-backed state for online players and races to avoid stale caches after reload
    local online = Sirin.mainThread.getActivePlayers()
    local raceSet = {}

    for _,p in ipairs(online) do
        local serial = p.m_id.dwSerial
        local race = p:GetObjRace()
        raceSet[race] = true
        Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 1, serial) -- personal
        Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 3, serial) -- claimed
    end

    for race,_ in pairs(raceSet) do
        Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 2, race) -- race totals
        Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 5, race) -- ranking
    end

    logConsole(true, "[Reload] Resync queued: personal, claimed, race totals, ranking")
end

local function reloadAll()
    local overall = true
    local parts = {}

    -- GMCommands
    local ok_gm = SirinLua.GmCommMgr and SirinLua.GmCommMgr.loadScripts and SirinLua.GmCommMgr.loadScripts() or false
    logConsole(ok_gm, string.format("[Reload] GMCommands: %s", ok_gm and "OK" or "FAIL"))
    table.insert(parts, string.format("GMCommands:%s", ok_gm and "OK" or "FAIL"))
    overall = overall and ok_gm

    -- NPCButtons
    local ok_npc = SirinLua.ButtonMgr and SirinLua.ButtonMgr.loadScripts and SirinLua.ButtonMgr.loadScripts() or false
    logConsole(ok_npc, string.format("[Reload] NPCButtons: %s", ok_npc and "OK" or "FAIL"))
    table.insert(parts, string.format("NPCButtons:%s", ok_npc and "OK" or "FAIL"))
    overall = overall and ok_npc

    -- PotionEffect
    local ok_potion = SirinLua.PotionMgr and SirinLua.PotionMgr.loadScripts and SirinLua.PotionMgr.loadScripts() or false
    logConsole(ok_potion, string.format("[Reload] PotionEffect: %s", ok_potion and "OK" or "FAIL"))
    table.insert(parts, string.format("Potion:%s", ok_potion and "OK" or "FAIL"))
    overall = overall and ok_potion

    -- BoxOpen
    local ok_box = SirinLua.BoxOpenMgr and SirinLua.BoxOpenMgr.loadScripts and SirinLua.BoxOpenMgr.loadScripts() or false
    logConsole(ok_box, string.format("[Reload] BoxOpen: %s", ok_box and "OK" or "FAIL"))
    table.insert(parts, string.format("BoxOpen:%s", ok_box and "OK" or "FAIL"))
    overall = overall and ok_box

    -- CombineEx
    local ok_combine = _G['CombineExMgr'] and CombineExMgr.loadScripts and CombineExMgr.loadScripts() or false
    logConsole(ok_combine, string.format("[Reload] CombineEx: %s", ok_combine and "OK" or "FAIL"))
    table.insert(parts, string.format("CombineEx:%s", ok_combine and "OK" or "FAIL"))
    overall = overall and ok_combine

    -- Rifts
    local ok_rifts = _G['RiftMgr'] and RiftMgr.loadScripts and RiftMgr.loadScripts() or false
    logConsole(ok_rifts, string.format("[Reload] Rifts: %s", ok_rifts and "OK" or "FAIL"))
    table.insert(parts, string.format("Rifts:%s", ok_rifts and "OK" or "FAIL"))
    overall = overall and ok_rifts

    -- MonsterSchedule
    local ok_sched = _G['MonsterScheduleMgr'] and MonsterScheduleMgr.loadScripts and MonsterScheduleMgr.loadScripts() or false
    logConsole(ok_sched, string.format("[Reload] MonsterSchedule: %s", ok_sched and "OK" or "FAIL"))
    table.insert(parts, string.format("MonsterSchedule:%s", ok_sched and "OK" or "FAIL"))
    overall = overall and ok_sched

    -- Custom Windows (via modCustomWindows loader if present)
    local ok_cw = _G['modCustomWindows'] and _G['modCustomWindows'].loadScripts and _G['modCustomWindows'].loadScripts() or false
    logConsole(ok_cw, string.format("[Reload] CustomWindows: %s", ok_cw and "OK" or "FAIL"))
    table.insert(parts, string.format("CustomWindows:%s", ok_cw and "OK" or "FAIL"))
    overall = overall and ok_cw

    -- Custom modules (threads/main/custom/*.lua) safe reload, skip stateful raceKillProgress.lua
    local ok_custom = true
    local files = Sirin.getFileList('.\\sirin-lua\\threads\\main\\custom') or {}
    for _,f in ipairs(files) do
        local fl = f:lower()
        if fl:sub(-4) == ".lua" and fl ~= "init.lua" then
            if fl:find("racekillprogress.lua", 1, true) then
                logConsole(true, string.format("[Reload] CustomModule %s: SKIP (stateful)", f))
            else
                local ok = pcall(dofile, f)
                ok_custom = ok_custom and ok
                logConsole(ok, string.format("[Reload] CustomModule %s: %s", f, ok and "OK" or "FAIL"))
            end
        end
    end
    table.insert(parts, string.format("CustomModules:%s", ok_custom and "OK" or "FAIL"))
    overall = overall and ok_custom

    postReloadResync()

    local summary = table.concat(parts, ", ")
    return overall, summary
end

function script.onButtonPress(p, dwActWindowID, dwActDataID)
    if dwActWindowID == 1 then
        local langId = Sirin.CLanguageAsset.instance():getPlayerLanguage(p.m_id.wIndex)
        local fm = _G['SirinScript_CustomWindowsByLangID'] and SirinScript_CustomWindowsByLangID[langId] and SirinScript_CustomWindowsByLangID[langId][1]
        local target = fm and fm.data and fm.data[dwActDataID]
        if target and target.customWindow == WINDOW_ID then
            sendWindowStatic(p)
            sendWindowState(p)
            openCustomWindow(p, WINDOW_ID)
            return
        end
    elseif dwActWindowID == WINDOW_ID then
        if dwActDataID == IDX_RELOAD then
            local ok, summary = reloadAll()
            if ok then
                informPlayer(p, { default = "Reload OK: " .. summary .. "; Resync queued" })
            else
                informPlayer(p, { default = "Reload FAIL: " .. summary .. "; Resync queued" })
            end
            sendWindowState(p)
            return
        end
    end
end

function script.CPlayer__Load(pPlayer, pUserDB, bFirstStart)
    -- Preload static + state so client-side opening shows content immediately
    sendWindowStatic(pPlayer)
    sendWindowState(pPlayer)
end

local function autoInit()
    if not _G[moduleName] then
        _G[moduleName] = script
        table.insert(SirinLua.onThreadBegin, function() end)
        table.insert(SirinLua.onThreadEnd, function() end)
    else
        _G[moduleName] = script
    end
    SirinLua.HookMgr.releaseHookByUID(script.m_strUUID)
    SirinLua.HookMgr.addHook('onPressCustomWindowButton', HOOK_POS.after_event, script.m_strUUID, script.onButtonPress)
    SirinLua.HookMgr.addHook('CPlayer__Load', HOOK_POS.after_event, script.m_strUUID, script.CPlayer__Load)
end

autoInit()