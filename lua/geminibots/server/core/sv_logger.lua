--[[
    GeminiBots - File Logger (Server)
    Подробный лог в файл garrysmod/data/geminibots/logs/debug.log:
    загрузка паков, выбор фраз, приветствия, дуэли.
    Включается конваром geminibots_file_log (1 = Вкл).
    Пишет только события (не каждый тик), файл не пухнет.
]]

GeminiBots = GeminiBots or {}

local LOG_DIR = "geminibots/logs"
local LOG_FILE = LOG_DIR .. "/debug.log"

-- Максимальный размер лога: дальше режем голову, файл не пухнет бесконечно
local MAX_LOG_SIZE = 512 * 1024

-- file.Append здесь не пишет, дописываем через Read+Write
local function AppendLine(path, line)
    local cur = file.Read(path, "DATA") or ""
    if #cur > MAX_LOG_SIZE then
        cur = "[...лог обрезан по лимиту...]\n"
    end
    file.Write(path, cur .. line)
end

local function FileLogEnabled()
    local cv = GetConVar("geminibots_file_log")
    if cv then return cv:GetBool() end
    return true
end

-- Все аргументы через tostring: concat падает на таблицах и энтити
local function SafeJoin(args)
    local parts = {}
    for i = 1, args.n or #args do
        parts[i] = tostring(args[i])
    end
    return table.concat(parts, " ")
end

-- Тег + формат: GeminiBots.FileLog("packs", "loaded %d files", n)
-- Лог никогда не кидает ошибок наружу: не должен ронять бой и чат.
function GeminiBots.FileLog(tag, fmt, ...)
    local args = { ... }
    local ok, err = xpcall(function()
        if not FileLogEnabled() then return end
        if not file.IsDir(LOG_DIR, "DATA") then
            file.CreateDir(LOG_DIR)
        end
        local msg = tostring(fmt or "")
        if msg:find("%%") and #args > 0 then
            local fok, fres = pcall(string.format, msg, unpack(args))
            if fok then msg = fres end
        elseif #args > 0 then
            msg = msg .. " " .. SafeJoin(args)
        end
        -- Одна строка, без переносов внутри сообщения
        msg = string.gsub(msg, "[\r\n]+", " | ")
        local line = string.format("[%s][T+%07.2f][%s] %s\n",
            os.date("%H:%M:%S"), CurTime(), tostring(tag or "?"), msg)
        AppendLine(LOG_FILE, line)
    end, function(e) return e end)
    if not ok then
        print("[GeminiBots] FileLog внутренняя ошибка (подавлена): " .. tostring(err))
    end
end

-- Шапка новой сессии при загрузке (только если лог включен)
if FileLogEnabled() then
    if not file.IsDir(LOG_DIR, "DATA") then
        file.CreateDir(LOG_DIR)
    end
    local header = string.format(
        "\n===== GeminiBots session start: %s | map: %s =====\n",
        os.date("%Y-%m-%d %H:%M:%S"), game.GetMap())
    AppendLine(LOG_FILE, header)
end

-- Очистка лога из консоли сервера
concommand.Add("geminibots_log_clear", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        print("[GeminiBots] geminibots_log_clear: нужен суперадмин.")
        return
    end
    file.Write(LOG_FILE, string.format(
        "===== Log cleared: %s | map: %s =====\n",
        os.date("%Y-%m-%d %H:%M:%S"), game.GetMap()))
    print("[GeminiBots] Файловый лог очищен: data/" .. LOG_FILE)
end, nil, "Очистить файловый лог GeminiBots (data/geminibots/logs/debug.log)")
