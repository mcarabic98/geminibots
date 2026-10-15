-- Проверка синтаксиса аддона стоковым Lua 5.1 (lua.org).
-- GLua-отличия гасим предобработкой: continue -> do end (эквивалент
-- по структуре блоков; семантику continue не проверяем, только парсинг).
-- Запуск (Windows): lua tools/check_syntax.lua [путь/к/lua]
local function scriptDir()
    local s = tostring(arg and arg[0] or "")
    local d = s:match("^(.*)[/\\]")
    if d and d ~= "" then return d end
    return "."
end

local SRC = arg[1] or scriptDir() .. "/../lua"

local files = {}
local function scan(dir)
    local p = io.popen('cmd /c dir /s /b "' .. dir .. [[\*.lua"]])
    if not p then return end
    for line in p:lines() do
        files[#files + 1] = line
    end
    p:close()
end
scan(SRC)

local fails = 0
for _, f in ipairs(files) do
    local fh = io.open(f, "rb")
    if not fh then
        print("CANNOT OPEN: " .. f)
        fails = fails + 1
    else
        local src = fh:read("*a")
        fh:close()
        -- continue целым словом -> do end
        src = string.gsub(src, "%f[%w_]continue%f[^%w_]", "do end")
        local fn, err = loadstring(src, "@" .. f)
        if not fn then
            fails = fails + 1
            print("FAIL: " .. f)
            print("  " .. tostring(err))
        end
    end
end
if fails == 0 then print("ALL OK (" .. #files .. " files)") end
os.exit(fails == 0 and 0 or 1)
