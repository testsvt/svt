-- place here your required files

--require('threads.main.custom.module_template')
local rkdb = require('threads.worldDB.custom.raceKillProgress_db')

-- worldDB async receiver
_G['SirinLua'] = _G['SirinLua'] or {}
_G['SirinLua'].asyncHandler = rkdb.asyncHandler