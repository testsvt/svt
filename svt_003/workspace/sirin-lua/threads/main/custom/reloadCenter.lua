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
    if def then
        NetOP:new():SendData(p, 'sirin.proto.customWindows', { ct = 1, data = { def } }, true)
    end
end

local function sendWindowState(p)
    local w = { id = WINDOW_ID, data = {} }
    table.insert(w.data, { id = IDX_INFO, stateFlags = tonumber('001', 2) })
    table.insert(w.data, { id = IDX_RELOAD, stateFlags = tonumber('1101', 2) })
    NetOP:new():SendData(p, 'sirin.proto.customWindows', { ct = 3, data = { w } }, true)
end

local function reloadAll()
    local ok = true
    -- reload GMCommands, NPCButtons, PotionEffect, CustomWindows
    ok = SirinLua.GmCommMgr.loadScripts() and ok
    ok = SirinLua.ButtonMgr.loadScripts() and ok
    ok = SirinLua.PotionMgr.loadScripts() and ok
    ok = true and ok
    -- Custom windows reload is handled by raceKillProgress module loader normally; force language tables rebuild via demo approach
    local loaded = _G['SirinScript_CustomWindows'] ~= nil
    if loaded then
        -- emulate demo loader refresh by rebuilding language split, if available
        local lngAst = Sirin.CLanguageAsset.instance()
        local langs = lngAst and lngAst:getLanguageTable() or {}
        _G['SirinScript_CustomWindowsByLangID'] = {}
        for _,l in ipairs(langs) do
            -- fallback: pass through current defs unmodified per language
            _G['SirinScript_CustomWindowsByLangID'][l[1]] = _G['SirinScript_CustomWindows']
        end
    end
    return ok
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
            local ok = reloadAll()
            if ok then
                informPlayer(p, { default = "Reload completed successfully" })
            else
                informPlayer(p, { default = "Reload failed (see logs)" })
            end
            sendWindowState(p)
            return
        end
    end
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
end

autoInit()