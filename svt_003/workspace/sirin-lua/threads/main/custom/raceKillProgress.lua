local projectName = 'sirin'
local moduleName = 'raceKillProgress'

local script = {
    m_strUUID = projectName .. ".lua." .. moduleName,
    LOG = '.\\sirin-log\\raceKillProgress.log',
}

local function log(fmt, ...)
    local ok, msg = pcall(string.format, "[raceKillProgress] " .. fmt, ...)
    msg = ok and msg or ("[raceKillProgress] " .. tostring(fmt))
    Sirin.WriteA(script.LOG, msg .. "\n", true, true)
end

local WINDOW_ID = 3
local WINDOW_ID_RANK = 4
local WINDOW_ID_REWARD = 5
local IDX_ICON = 1
local IDX_RACE_TEXT = 2
local IDX_PERSONAL_TEXT = 3
local IDX_RANK_BTN = 4
local IDX_CLAIM = 5
local RACE_TARGET = 10
local PERSONAL_TARGET = 5
local REWARD_ITEM_CODE = 'irtal01'
local REWARD_COUNT = 10

-- in-memory cache per race and per player
local raceKills = { [0] = 0, [1] = 0, [2] = 0 }
local personalKills = {}
local claimedReward = {}
local loadTracker = {}
local selectedRow = {}

-- ranking cache: per race top list of {name, kills}
local raceTop = { [0] = {}, [1] = {}, [2] = {} }
local sendWindowState

local function getPlayerKey(p)
    return p.m_id.dwSerial
end

local function getRaceKey(p)
    return p:GetObjRace()
end

local function getPlayerName(p)
    return p.m_Param.m_dbChar.m_wszCharID
end

local function getRankPosForPlayer(p)
    local entries = raceTop[getRaceKey(p)] or {}
    local name = getPlayerName(p)
    for i, row in ipairs(entries) do
        if row and row.name == name then
            return i
        end
    end
    return nil
end

local function trySendWindowForSerial(serial)
    local t = loadTracker[serial]
    if not t or not t.personalLoaded or not t.raceLoaded then
        return
    end
    local p = Sirin.mainThread.getPlayerBySerial(serial)
    if p and p.m_bOper then
        sendWindowState(p)
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

-- on-screen notification helper
local function showOnScreen(p, text, color)
    -- Use center-screen announce like Rift, green color, short-lived
    NetMgr.privateAnnounceMsg(p, text, 0xFFFF, ANN_TYPE.mid3, color or 0xFF00FF00)
end

local function informPlayer(p, text)
    NetMgr.privateChatMsg(p, text)
    showOnScreen(p, text)
end

-- track sent statics per player
script.sentStatics = script.sentStatics or {}

local scheduleAfter

local function initStaticsForPlayer(p)
    script.sentStatics[p.m_id.dwSerial] = script.sentStatics[p.m_id.dwSerial] or {}
    local langId = Sirin.CLanguageAsset.instance():getPlayerLanguage(p.m_id.wIndex)
    local defs = _G['SirinScript_CustomWindowsByLangID'] and SirinScript_CustomWindowsByLangID[langId]
    if not defs then return end

    local list = {
        { id = WINDOW_ID,      delay = 0 },
        { id = WINDOW_ID_RANK, delay = 250 },
        { id = WINDOW_ID_REWARD, delay = 500 },
    }

    for _, e in ipairs(list) do
        local def = defs[e.id]
        if def then
            local uid = string.format('%s.preload.%d.%d', script.m_strUUID, p.m_id.dwSerial, e.id)
            scheduleAfter(uid, e.delay, function()
                local bumped = bumpDef(def)
                NetOP:new():SendData(p, 'sirin.proto.customWindows', { ct = 1, data = { bumped } }, true)
            end)
        end
    end
end

local function sendFunctionMenuFlags(p)
    local langId = Sirin.CLanguageAsset.instance():getPlayerLanguage(p.m_id.wIndex)
    local defs = _G['SirinScript_CustomWindowsByLangID'] and SirinScript_CustomWindowsByLangID[langId]
    local fmDef = defs and defs[1]
    if fmDef and fmDef.data then
        local fm = { id = 1, data = {} }
        for i = 1, #fmDef.data do
            local it = fmDef.data[i]
            local flags = tonumber('101', 2)
            if it and it.customWindow == WINDOW_ID then
                flags = tonumber('1101', 2)
            end
            table.insert(fm.data, { id = i, stateFlags = flags })
        end
        NetOP:new():SendData(p, 'sirin.proto.customWindows', { ct = 3, data = { fm } }, true)
    end
end

local function ensureWindowStatic(p, windowId)
    local serial = p.m_id.dwSerial
    script.sentStatics[serial] = script.sentStatics[serial] or {}
    if script.sentStatics[serial][windowId] then return end
    local langId = Sirin.CLanguageAsset.instance():getPlayerLanguage(p.m_id.wIndex)
    local defs = _G['SirinScript_CustomWindowsByLangID'] and SirinScript_CustomWindowsByLangID[langId]
    local def = defs and defs[windowId]
    if def then
        NetOP:new():SendData(p, 'sirin.proto.customWindows', { ct = 1, data = { def } }, true)
        script.sentStatics[serial][windowId] = true
    end
end

local function shallowClone(t)
    local c = {}
    for k,v in pairs(t) do c[k]=v end
    return c
end

-- Redefine as a method on script and alias to globals to survive reload edges
function script.sendWindowState(p)
	local serial = p.m_id.dwSerial
	local currentRow = selectedRow[serial] or 1
	local rk = raceKills[getRaceKey(p)] or 0
	local pk = personalKills[getPlayerKey(p)] or 0
	local canClaim = (rk >= RACE_TARGET) and (pk >= PERSONAL_TARGET) and (not claimedReward[getPlayerKey(p)])

	local w = {}
	w.id = WINDOW_ID
	w.data = {}

	-- Toggler buttons (1 and 6) are always visible and clickable
	table.insert(w.data, { id = 1, stateFlags = tonumber('1101', 2) })
	table.insert(w.data, { id = 6, stateFlags = tonumber('1101', 2) })

	local showRow1 = (currentRow == 1)

	local rankPos = getRankPosForPlayer(p)
	local rankLabel = string.format('Место в рейтинге: %s', rankPos and tostring(rankPos) or '—')

	if showRow1 then
		-- Row1 visible, Row2 hidden
		table.insert(w.data, { id = IDX_RACE_TEXT, stateFlags = tonumber('001', 2), delay = { math.max(RACE_TARGET - math.min(rk, RACE_TARGET), 0), RACE_TARGET }, counter = { math.min(rk, RACE_TARGET), RACE_TARGET } })
		table.insert(w.data, { id = IDX_PERSONAL_TEXT, stateFlags = tonumber('001', 2), delay = { math.max(PERSONAL_TARGET - math.min(pk, PERSONAL_TARGET), 0), PERSONAL_TARGET }, counter = { math.min(pk, PERSONAL_TARGET), PERSONAL_TARGET } })
		table.insert(w.data, { id = IDX_RANK_BTN, stateFlags = tonumber('1101', 2), text = rankLabel, counter = { -1, -1 } })
		table.insert(w.data, { id = IDX_CLAIM, stateFlags = tonumber('1101', 2), counter = { -1, -1 } })
		for i = 7, 10 do table.insert(w.data, { id = i, stateFlags = tonumber('000', 2) }) end
	else
		-- Row2 visible in the SAME slots (2..5). Fully hide row1 placeholders (7..10)
		table.insert(w.data, { id = IDX_RACE_TEXT, stateFlags = tonumber('001', 2), delay = { math.max(RACE_TARGET - math.min(rk, RACE_TARGET), 0), RACE_TARGET }, counter = { math.min(rk, RACE_TARGET), RACE_TARGET } })
		table.insert(w.data, { id = IDX_PERSONAL_TEXT, stateFlags = tonumber('001', 2), delay = { math.max(PERSONAL_TARGET - math.min(pk, PERSONAL_TARGET), 0), PERSONAL_TARGET }, counter = { math.min(pk, PERSONAL_TARGET), PERSONAL_TARGET } })
		table.insert(w.data, { id = IDX_RANK_BTN, stateFlags = tonumber('1101', 2), text = rankLabel, counter = { -1, -1 } })
		table.insert(w.data, { id = IDX_CLAIM, stateFlags = tonumber('1101', 2), counter = { -1, -1 } })
		for i = 7, 10 do table.insert(w.data, { id = i, stateFlags = tonumber('000', 2) }) end
	end

	NetOP:new():SendData(p, 'sirin.proto.customWindows', { ct = 3, data = { w } }, true)
	-- Function menu flags keep as-is
	local langId = Sirin.CLanguageAsset.instance():getPlayerLanguage(p.m_id.wIndex)
	local windowsByLang = _G['SirinScript_CustomWindowsByLangID'] and SirinScript_CustomWindowsByLangID[langId]
	if windowsByLang and windowsByLang[1] and windowsByLang[1].data then
		local fm = { id = 1, data = {} }
		for i = 1, #windowsByLang[1].data do
			local it = windowsByLang[1].data[i]
			if it and it.customWindow == WINDOW_ID then
				table.insert(fm.data, { id = i, stateFlags = tonumber('1101', 2) })
			else
				table.insert(fm.data, { id = i, stateFlags = tonumber('101', 2) })
			end
		end
		NetOP:new():SendData(p, 'sirin.proto.customWindows', { ct = 3, data = { fm } }, true)
	end
end

-- Rebind aliases so any old references still resolve
sendWindowState = script.sendWindowState
_G['sendWindowState'] = script.sendWindowState

script.visualSeq = script.visualSeq or 0

local clearWindowStatic

local function clearWindowStatic(p, windowId)
    NetOP:new():SendData(p, 'sirin.proto.customWindows', { ct = 2, data = { { id = windowId } } }, true)
end

local function bumpDef(def)
    local c = {}
    for k,v in pairs(def) do c[k]=v end
    script.visualSeq = (script.visualSeq + 1) % 1000000
    c.visualVer = script.visualSeq
    return c
end

-- deprecated: setRowVisibility handled inside sendWindowState now
local function setRowVisibility(p, showRow)
    selectedRow[p.m_id.dwSerial] = (showRow == 1) and 1 or 2
    sendWindowState(p)
end

scheduleAfter = function(uid, delayMs, fn)
    local start = Sirin.mainThread.GetLoopTime()
    local executed = false
    SirinLua.LoopMgr.addMainLoopCallback(uid, function()
        local now = Sirin.mainThread.GetLoopTime()
        if (not executed) and (now - start >= delayMs) then
            executed = true
            pcall(fn)
            -- do not remove here to avoid mutating handlers during iteration
        end
    end, 0)
end

local function sendRewardWindow(p)
    -- Stable sequence: ct=1 (static with bumped visualVer) -> delayed ct=3 -> delayed open
    local langId = Sirin.CLanguageAsset.instance():getPlayerLanguage(p.m_id.wIndex)
    local defs = _G['SirinScript_CustomWindowsByLangID'] and SirinScript_CustomWindowsByLangID[langId]
    local def = defs and defs[WINDOW_ID_REWARD]

    if def then
        local defBumped = bumpDef(def)
        NetOP:new():SendData(p, 'sirin.proto.customWindows', { ct = 1, data = { defBumped } }, true)
    end

    local w = { id = WINDOW_ID_REWARD, data = {} }
    table.insert(w.data, { id = 1, stateFlags = tonumber('001', 2) })
    table.insert(w.data, { id = 2, stateFlags = tonumber('1101', 2) })
    NetOP:new():SendData(p, 'sirin.proto.customWindows', { ct = 3, data = { w } }, true)
    openCustomWindow(p, WINDOW_ID_REWARD)
end

-- build and send only ranking state (without forcing window open)
local function sendRankingUpdate(p)
    local race = getRaceKey(p)
    local entries = raceTop[race] or {}
    local w = { id = WINDOW_ID_RANK, data = {} }
    -- ensure header is visible
    table.insert(w.data, { id = 1, stateFlags = tonumber('001', 2) })
    for i = 1, 5 do
        local row = entries[i]
        local txt = row and string.format('%d) %s %d', i, row.name, row.kills) or string.format('%d) --- 0', i)
        table.insert(w.data, { id = i + 1, stateFlags = tonumber('001', 2), text = txt })
    end
    NetOP:new():SendData(p, 'sirin.proto.customWindows', { ct = 3, data = { w } }, true)
end

-- build and send ranking window state
local function sendRankingWindow(p)
    local race = getRaceKey(p)
    local entries = raceTop[race] or {}

    local langId = Sirin.CLanguageAsset.instance():getPlayerLanguage(p.m_id.wIndex)
    local defs = _G['SirinScript_CustomWindowsByLangID'] and SirinScript_CustomWindowsByLangID[langId]
    local def = defs and defs[WINDOW_ID_RANK]

    if def then
        local defBumped = bumpDef(def)
        NetOP:new():SendData(p, 'sirin.proto.customWindows', { ct = 1, data = { defBumped } }, true)
    end

    local w = { id = WINDOW_ID_RANK, data = {} }
    table.insert(w.data, { id = 1, stateFlags = tonumber('001', 2) })
    for i = 1, 5 do
        local row = entries[i]
        local txt = row and string.format('%d) %s %d', i, row.name, row.kills) or string.format('%d) --- 0', i)
        table.insert(w.data, { id = i + 1, stateFlags = tonumber('001', 2), text = txt })
    end
    NetOP:new():SendData(p, 'sirin.proto.customWindows', { ct = 3, data = { w } }, true)
    openCustomWindow(p, WINDOW_ID_RANK)
end

-- periodic refresh of rank label
local function periodicRefresh()
    local online = Sirin.mainThread.getActivePlayers()
    for _,p in ipairs(online) do
        sendWindowState(p)
    end
end

-- periodic fetch of ranking for all races to keep label up-to-date
local function periodicFetchRanking()
    -- fetch for all 3 races; DB will be light with TOP 5
    Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 5, 0)
    Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 5, 1)
    Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 5, 2)
end

-- Async roundtrip handlers (worldDB thread <-> main)
function script.mainThreadAsyncCallback(case, param)
    if case == 1 then
        -- loaded personal progress
        if not param then return end
        local ret = param:GetList()
        for _,row in ipairs(ret) do
            local ok, serial = row:PopInt32(); if not ok then break end
            local ok2, val = row:PopInt32(); if not ok2 then break end
            personalKills[serial] = val
            loadTracker[serial] = loadTracker[serial] or {}
            loadTracker[serial].personalLoaded = true
            trySendWindowForSerial(serial)
        end
    elseif case == 2 then
        -- loaded race progress
        if not param then return end
        local ret = param:GetList()
        for _,row in ipairs(ret) do
            local ok, race = row:PopInt8(); if not ok then break end
            local ok2, val = row:PopInt32(); if not ok2 then break end
            raceKills[race] = val
            local online = Sirin.mainThread.getActivePlayers()
            for _,p in ipairs(online) do
                if p:GetObjRace() == race then
                    local serial = p.m_id.dwSerial
                    loadTracker[serial] = loadTracker[serial] or {}
                    loadTracker[serial].raceLoaded = true
                    loadTracker[serial].race = race
                    trySendWindowForSerial(serial)
                end
            end
        end
    elseif case == 3 then
        -- save ack
    elseif case == 4 then
        -- loaded claimed flags
        if not param then return end
        local ret = param:GetList()
        for _,row in ipairs(ret) do
            local ok, serial = row:PopInt32(); if not ok then break end
            local ok2, was = row:PopInt8(); if not ok2 then break end
            claimedReward[serial] = (was ~= 0)
        end
    elseif case == 5 then
        -- loaded ranking for player's race
        if not param then return end
        local ret = param:GetList()
        local parsedRace = nil
        local data = {}
        for _,row in ipairs(ret) do
            local okRace, rc = row:PopInt8(); if not okRace then break end
            parsedRace = parsedRace or rc
            local okName, name = row:PopString(16); if not okName then break end
            local okKills, kills = row:PopInt32(); if not okKills then break end
            table.insert(data, { name = name, kills = kills })
        end
        if parsedRace ~= nil then
            raceTop[parsedRace] = data
            periodicRefresh()
        end
    end
end

-- Hook handlers
function script.onButtonPress(p, dwActWindowID, dwActDataID)
    if dwActWindowID == 1 then
        local langId = Sirin.CLanguageAsset.instance():getPlayerLanguage(p.m_id.wIndex)
        local fm = _G['SirinScript_CustomWindowsByLangID'] and SirinScript_CustomWindowsByLangID[langId] and SirinScript_CustomWindowsByLangID[langId][1]
        local target = fm and fm.data and fm.data[dwActDataID]
        		if target and target.customWindow == WINDOW_ID then
			Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 5, p:GetObjRace())
			selectedRow[p.m_id.dwSerial] = selectedRow[p.m_id.dwSerial] or 1
			sendWindowState(p)
			return
        elseif target and target.customWindow == WINDOW_ID_RANK then
            Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 5, p:GetObjRace())
            sendRankingWindow(p)
            return
        end
    end
    if dwActWindowID == WINDOW_ID then
        if dwActDataID == IDX_CLAIM then
            sendRewardWindow(p)
            return
        elseif dwActDataID == IDX_RANK_BTN then
            Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 5, p:GetObjRace())
            sendRankingWindow(p)
            return
        		elseif dwActDataID == 1 then
			selectedRow[p.m_id.dwSerial] = 1
			sendWindowState(p)
			return
        		elseif dwActDataID == 6 then
			selectedRow[p.m_id.dwSerial] = 2
			sendWindowState(p)
			return
		elseif dwActDataID == 9 then
			-- rank from row2
			Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 5, p:GetObjRace())
			sendRankingWindow(p)
			return
		elseif dwActDataID == 10 then
			-- claim from row2
			sendRewardWindow(p)
			return
        end
    elseif dwActWindowID == WINDOW_ID_REWARD then
        if dwActDataID == 2 then
            local rk = raceKills[getRaceKey(p)] or 0
            local pk = personalKills[getPlayerKey(p)] or 0
            local leftRace = math.max(0, RACE_TARGET - rk)
            local leftPersonal = math.max(0, PERSONAL_TARGET - pk)
            if claimedReward[getPlayerKey(p)] then
                informPlayer(p, "Вы уже получили данную награду.")
                return
            end
            if leftRace > 0 or leftPersonal > 0 then
                local chatMsg
                if leftRace > 0 and leftPersonal > 0 then
                    chatMsg = string.format("Для получения награды вашей расе необходимо убить ещё %d монстров, а вам лично — %d монстра.", leftRace, leftPersonal)
                elseif leftRace > 0 then
                    chatMsg = string.format("Для получения награды вашей расе необходимо убить ещё %d монстров.", leftRace)
                else
                    chatMsg = string.format("Для получения награды вам лично необходимо убить ещё %d монстра.", leftPersonal)
                end
                informPlayer(p, chatMsg)
                return
            end
            claimedReward[getPlayerKey(p)] = true
            Sirin.mainThread.modChargeItem.giveItemBySerial(p.m_id.dwSerial, REWARD_ITEM_CODE, REWARD_COUNT, 0, 0, true)
            Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 103, p.m_id.dwSerial)
            informPlayer(p, "Награда получена.")
            sendWindowState(p)
            sendRewardWindow(p)
            return
        end
    end
end

function script.onMonsterDestroy(pMonster, byDestroyCode, pAttObj)
    if byDestroyCode ~= 0 then return end
    if not pAttObj or pAttObj.m_ObjID.m_byID ~= ID_CHAR.player then return end
    local p = Sirin.mainThread.objectToPlayer(pAttObj)
    if not p or not p.m_bOper then return end
    local name = p.m_Param.m_dbChar.m_wszCharID
    local race = p:GetObjRace()
    personalKills[getPlayerKey(p)] = (personalKills[getPlayerKey(p)] or 0) + 1
    raceKills[race] = (raceKills[race] or 0) + 1
    Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 101, string.format('%d|%s|%d', p.m_id.dwSerial, name, race))
    Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 102, race)
    -- also fetch updated ranking for race to refresh label quickly
    Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 5, race)
    sendWindowState(p)
end

function script.CPlayer__Load(pPlayer, pUserDB, bFirstStart)
    script.sentStatics[pPlayer.m_id.dwSerial] = {}
    loadTracker[pPlayer.m_id.dwSerial] = { personalLoaded = false, raceLoaded = false, race = pPlayer:GetObjRace() }
    selectedRow[pPlayer.m_id.dwSerial] = 1
    Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 1, pPlayer.m_id.dwSerial)
    Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 2, pPlayer:GetObjRace())
    Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 3, pPlayer.m_id.dwSerial)
    Sirin.processAsyncCallback(0, 'sirin.guard.worldDBThread', 'SirinLua', 'asyncHandler', 5, pPlayer:GetObjRace())
    initStaticsForPlayer(pPlayer)
    sendFunctionMenuFlags(pPlayer)
    sendWindowState(pPlayer)
end

function script.onThreadBegin()
    -- periodic refresh every 5 seconds
    SirinLua.LoopMgr.addMainLoopCallback(script.m_strUUID, function() periodicRefresh() end, 5000)
    -- periodic ranking fetch every 10 seconds
    SirinLua.LoopMgr.addMainLoopCallback(script.m_strUUID .. '.fetch', function() periodicFetchRanking() end, 10000)
end

function script.onThreadEnd()
end

local function autoInit()
    if not _G[moduleName] then
        _G[moduleName] = script
        table.insert(SirinLua.onThreadBegin, function() _G[moduleName].onThreadBegin() end)
        table.insert(SirinLua.onThreadEnd, function() _G[moduleName].onThreadEnd() end)
    else
        _G[moduleName] = script
    end
    SirinLua.HookMgr.releaseHookByUID(script.m_strUUID)
    SirinLua.HookMgr.addHook('CPlayer__Load', HOOK_POS.after_event, script.m_strUUID, script.CPlayer__Load)
    SirinLua.HookMgr.addHook('onPressCustomWindowButton', HOOK_POS.after_event, script.m_strUUID, script.onButtonPress)
    SirinLua.HookMgr.addHook('CMonster__Destroy', HOOK_POS.pre_event, script.m_strUUID, script.onMonsterDestroy)
    _G['SirinLua'] = _G['SirinLua'] or {}
    _G['SirinLua'].asyncHandler = script.mainThreadAsyncCallback
end

autoInit()

function script.__exportState()
	return {
		raceKills = raceKills,
		personalKills = personalKills,
		claimedReward = claimedReward,
		raceTop = raceTop,
		loadTracker = loadTracker,
		selectedRow = selectedRow,
		sentStatics = script.sentStatics,
		visualSeq = script.visualSeq,
	}
end

function script.__importState(st)
	if type(st) ~= 'table' then return end
	raceKills = st.raceKills or raceKills
	personalKills = st.personalKills or personalKills
	claimedReward = st.claimedReward or claimedReward
	raceTop = st.raceTop or raceTop
	loadTracker = st.loadTracker or loadTracker
	selectedRow = st.selectedRow or selectedRow
	script.sentStatics = st.sentStatics or {}
	script.visualSeq = st.visualSeq or 0
end